#!/usr/local/bin/python3
# -*- coding: utf-8 -*-
"""
Copyright (C) 2024 Automatisierung Plugin Contributors
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
"""
"""
Automatisierung - notification dispatcher.

Sends short alerts to the channels enabled in config.xml:
  * Telegram (bot token + chat id)
  * Pushover  (app token + user key)
  * Matrix    (homeserver + access token + room id)

Importable (`import notify; notify.send(title, message)`) and runnable as a CLI
(`notify.py --test` or `notify.py --title X --message Y`). Every channel is
independent; one failing channel never blocks the others.
"""

import sys
import json
import ssl
import time
import logging
import argparse
import urllib.parse
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from logging.handlers import RotatingFileHandler

CONFIG_FILE = '/conf/config.xml'
LOG_FILE = '/var/log/automatisierung_notify.log'

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[RotatingFileHandler(LOG_FILE, maxBytes=524288, backupCount=2)],
)
log = logging.getLogger('automatisierung-notify')


def _cfg():
    """Return the <general> element of the automatisierung config, or None."""
    try:
        root = ET.parse(CONFIG_FILE).getroot()
        return root.find('.//automatisierung/general')
    except Exception as e:
        log.error("Config lesen fehlgeschlagen: %s", e)
        return None


def _txt(node, tag, default=''):
    if node is None:
        return default
    return (node.findtext(tag, default) or default).strip()


def _http(url, data=None, headers=None, method='POST'):
    ctx = ssl.create_default_context()
    body = None
    if data is not None:
        body = data if isinstance(data, bytes) else data.encode()
    req = urllib.request.Request(url, data=body, headers=headers or {}, method=method)
    with urllib.request.urlopen(req, timeout=15, context=ctx) as r:
        return r.status, r.read()


def send_telegram(token, chat_id, title, message):
    text = f"*{title}*\n{message}" if title else message
    data = urllib.parse.urlencode({
        'chat_id': chat_id, 'text': text, 'parse_mode': 'Markdown',
    })
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    code, _ = _http(url, data, {'Content-Type': 'application/x-www-form-urlencoded'})
    return code == 200


def send_pushover(token, user, title, message, priority=0):
    data = urllib.parse.urlencode({
        'token': token, 'user': user, 'title': title or 'Automatisierung',
        'message': message, 'priority': priority,
    })
    code, _ = _http('https://api.pushover.net/1/messages.json', data,
                    {'Content-Type': 'application/x-www-form-urlencoded'})
    return code == 200


def send_matrix(homeserver, mtoken, room, title, message):
    body = (f"{title}\n{message}" if title else message)
    txn = str(int(time.time() * 1000))
    room_enc = urllib.parse.quote(room, safe='')
    url = (homeserver.rstrip('/') +
           f"/_matrix/client/v3/rooms/{room_enc}/send/m.room.message/{txn}"
           f"?access_token={urllib.parse.quote(mtoken)}")
    payload = json.dumps({'msgtype': 'm.text', 'body': body})
    code, _ = _http(url, payload, {'Content-Type': 'application/json'}, method='PUT')
    return code == 200


def send(title, message, priority=0):
    """Send to every enabled channel. Returns dict {channel: bool|None}."""
    g = _cfg()
    results = {}
    if g is None or _txt(g, 'notify_enabled', '0') != '1':
        log.info("Benachrichtigungen global deaktiviert – nichts gesendet.")
        return results

    if _txt(g, 'notify_telegram_enabled') == '1':
        tok, cid = _txt(g, 'notify_telegram_token'), _txt(g, 'notify_telegram_chatid')
        if tok and cid:
            try:
                results['telegram'] = send_telegram(tok, cid, title, message)
            except Exception as e:
                results['telegram'] = False
                log.warning("Telegram fehlgeschlagen: %s", e)

    if _txt(g, 'notify_pushover_enabled') == '1':
        tok, usr = _txt(g, 'notify_pushover_token'), _txt(g, 'notify_pushover_user')
        if tok and usr:
            try:
                results['pushover'] = send_pushover(tok, usr, title, message, priority)
            except Exception as e:
                results['pushover'] = False
                log.warning("Pushover fehlgeschlagen: %s", e)

    if _txt(g, 'notify_matrix_enabled') == '1':
        hs, tok, room = (_txt(g, 'notify_matrix_homeserver'),
                         _txt(g, 'notify_matrix_token'), _txt(g, 'notify_matrix_room'))
        if hs and tok and room:
            try:
                results['matrix'] = send_matrix(hs, tok, room, title, message)
            except Exception as e:
                results['matrix'] = False
                log.warning("Matrix fehlgeschlagen: %s", e)

    for ch, ok in results.items():
        log.info("%s: %s", ch, 'OK' if ok else 'FEHLGESCHLAGEN')
    if not results:
        log.info("Kein Kanal aktiv/vollständig konfiguriert.")
    return results


def main():
    ap = argparse.ArgumentParser(description='Automatisierung notification dispatcher')
    ap.add_argument('--title', default='Automatisierung')
    ap.add_argument('--message', default='')
    ap.add_argument('--priority', type=int, default=0)
    ap.add_argument('--test', action='store_true', help='send a test notification')
    args = ap.parse_args()

    if args.test:
        args.title = 'Automatisierung – Test'
        args.message = ('Testbenachrichtigung erfolgreich. '
                        'Wenn du das liest, funktioniert der Kanal.')
    results = send(args.title, args.message, args.priority)
    # Always print the per-channel result as JSON and exit 0. The success/failure
    # of individual channels is conveyed in the JSON, NOT the exit code — a
    # non-zero exit makes configd report "Execute error" and swallow the output.
    print(json.dumps(results))
    sys.exit(0)


if __name__ == '__main__':
    main()
