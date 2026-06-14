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
Automatisierung - Zenarmor Watchdog
Alle 5 Minuten via Cron aufgerufen.
Prüft pro Host (za_watchdog=1): läuft die Engine, ist ein Restart empfohlen?
Greift nur ein wenn nötig.
"""

import sys, os, json, ssl, urllib.request, urllib.error, base64, logging, time, subprocess
from logging.handlers import RotatingFileHandler
import xml.etree.ElementTree as ET

LOG_FILE   = '/var/log/automatisierung_watchdog.log'
STATE_FILE = '/tmp/za_watchdog_last_run'
# Rotate so the log (written every few minutes) can never grow without bound.
_handlers = [RotatingFileHandler(LOG_FILE, maxBytes=1048576, backupCount=3)]
if sys.stdout.isatty():
    _handlers.append(logging.StreamHandler(sys.stdout))
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=_handlers,
)
log = logging.getLogger('za-watchdog')

CONFIG_FILE = '/conf/config.xml'
ZA_STATUS_EP  = 'zenarmor/status/index'    # GET  → engine status
ZA_SERVICE_EP = 'zenarmor/status/service'  # PUT  → start / restart


def api_get(base_url, key, secret, endpoint, skip_verify=False):
    url = base_url.rstrip('/') + '/api/' + endpoint.lstrip('/')
    ctx = ssl.create_default_context()
    if skip_verify:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    auth = base64.b64encode(f"{key}:{secret}".encode()).decode()
    req = urllib.request.Request(url, headers={'Authorization': f'Basic {auth}'}, method='GET')
    try:
        with urllib.request.urlopen(req, timeout=15, context=ctx) as r:
            return r.status, json.loads(r.read() or b'{}')
    except urllib.error.HTTPError as e:
        return e.code, {}
    except Exception as e:
        log.debug("GET %s: %s", url, e)
        return 0, {}


def api_put(base_url, key, secret, endpoint, data, skip_verify=False):
    url = base_url.rstrip('/') + '/api/' + endpoint.lstrip('/')
    ctx = ssl.create_default_context()
    if skip_verify:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    auth = base64.b64encode(f"{key}:{secret}".encode()).decode()
    body = json.dumps(data).encode()
    req = urllib.request.Request(
        url, data=body, method='PUT',
        headers={'Authorization': f'Basic {auth}', 'Content-Type': 'application/json'},
    )
    try:
        with urllib.request.urlopen(req, timeout=20, context=ctx) as r:
            d = json.loads(r.read() or b'{}')
            return r.status, d
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:200] if e.fp else ''
        return e.code, {'Message': body}
    except Exception as e:
        log.debug("PUT %s: %s", url, e)
        return 0, {}


def za_service(base_url, key, secret, skip_verify, action):
    """Start or restart the ZA eastpect engine. Returns True on success."""
    code, data = api_put(base_url, key, secret, ZA_SERVICE_EP,
                         {'service': 'eastpect', 'action': action}, skip_verify)
    ok = code == 200 and int(data.get('Status', 1)) == 0
    if not ok:
        log.warning("  ZA %s fehlgeschlagen (HTTP %s): %s", action, code, data.get('Message', ''))
    return ok


def check_host(name, url, key, secret, skip_verify):
    log.info("--- %s (%s) ---", name, url)

    # Erreichbarkeit
    code, _ = api_get(url, key, secret, 'core/firmware/info', skip_verify)
    if code == 0:
        log.warning("  Host nicht erreichbar – überspringe.")
        return

    # ZA Status holen
    code, data = api_get(url, key, secret, ZA_STATUS_EP, skip_verify)
    if code != 200:
        log.warning("  ZA Status nicht abrufbar (HTTP %s).", code)
        return

    engine_running   = bool(data.get('eastpect', {}).get('status', False))
    update_in_prog   = bool(data.get('updateInProgress', False))
    agent_version    = data.get('agent_version', {})
    version_str      = agent_version.get('version', '?') if isinstance(agent_version, dict) else str(agent_version)

    log.info("  Engine läuft: %s | Version: %s | UpdateInProgress: %s",
             engine_running, version_str, update_in_prog)

    if not engine_running:
        log.warning("  Engine NICHT aktiv – starte...")
        ok = za_service(url, key, secret, skip_verify, 'start')
        if ok:
            time.sleep(5)
            # Nachprüfen
            _, d2 = api_get(url, key, secret, ZA_STATUS_EP, skip_verify)
            if bool(d2.get('eastpect', {}).get('status', False)):
                log.info("  Engine erfolgreich gestartet.")
            else:
                log.error("  Engine-Start verifiziert fehlgeschlagen – versuche restart...")
                za_service(url, key, secret, skip_verify, 'restart')
    elif update_in_prog:
        log.info("  Update abgeschlossen, Restart empfohlen – starte neu...")
        ok = za_service(url, key, secret, skip_verify, 'restart')
        if ok:
            log.info("  Engine neugestartet.")
    else:
        log.info("  Engine läuft einwandfrei – kein Eingriff nötig.")


def _sh(cmd):
    """Run a shell command, return (returncode, combined output)."""
    try:
        p = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=90)
        return p.returncode, ((p.stdout or '') + (p.stderr or '')).strip()
    except Exception as e:
        return 1, str(e)


def _local_za_installed():
    # Zenarmor ships as the os-sensei package; fall back to the install dir.
    rc, _ = _sh('pkg info -e os-sensei')
    return rc == 0 or os.path.isdir('/usr/local/zenarmor') or os.path.isdir('/usr/local/sensei')


def _local_engine_running():
    rc, _ = _sh('pgrep -x eastpect')
    return rc == 0


def check_local():
    """Monitor the Zenarmor engine on THIS firewall (no API, local commands).

    The remote host loop never covers the firewall the watchdog runs on, yet the
    status UI advertises the watchdog for it. Without this the local engine is
    never auto-restarted after a stop.
    """
    log.info("--- LOKAL (diese Firewall) ---")
    if not _local_za_installed():
        log.info("  Zenarmor lokal nicht installiert – überspringe.")
        return
    if _local_engine_running():
        log.info("  Lokale Engine läuft einwandfrei – kein Eingriff nötig.")
        return

    log.warning("  Lokale Engine NICHT aktiv – starte...")
    rc, out = _sh('/usr/local/sbin/pluginctl -s eastpect start')
    if rc != 0:
        rc, out = _sh('/usr/sbin/service eastpect onestart')
    time.sleep(5)
    if _local_engine_running():
        log.info("  Lokale Engine erfolgreich gestartet.")
    else:
        log.error("  Lokaler Engine-Start fehlgeschlagen: %s", (out or '')[:200])


def interval_elapsed(interval_minutes):
    """Return True if configured interval has passed since last successful run."""
    now = time.time()
    try:
        with open(STATE_FILE) as f:
            last = float(f.read().strip())
        if now - last < interval_minutes * 60 - 15:
            return False
    except Exception:
        pass
    with open(STATE_FILE, 'w') as f:
        f.write(str(now))
    return True


def main():
    log.info("=== ZA Watchdog Start ===")
    try:
        root = ET.parse(CONFIG_FILE).getroot()
    except Exception as e:
        log.error("Config lesen fehlgeschlagen: %s", e)
        sys.exit(1)

    general = root.find('.//automatisierung/general')
    if general is None or general.findtext('za_watchdog_enabled', '0').strip() != '1':
        log.info("ZA Watchdog global deaktiviert – Ende.")
        sys.exit(0)

    interval = int(general.findtext('za_check_interval', '5').strip() or '5')
    if not interval_elapsed(interval):
        log.info("Intervall (%d Min) noch nicht erreicht – Ende.", interval)
        sys.exit(0)

    # Lokale Firewall zuerst – der Host-Loop deckt sie nicht ab.
    try:
        check_local()
    except Exception as e:
        log.error("Fehler bei lokaler Prüfung: %s", e)

    processed = 0
    for h in root.findall('.//automatisierung/hosts/host'):
        if h.findtext('enabled', '0').strip() != '1':
            continue
        if h.findtext('za_watchdog', '0').strip() != '1':
            continue
        name   = h.findtext('name', '').strip()
        url    = h.findtext('url', '').strip()
        key    = h.findtext('api_key', '').strip()
        secret = h.findtext('api_secret', '').strip()
        skip   = h.findtext('skip_verify_tls', '0').strip() == '1'
        if not (url and key and secret):
            log.warning("Host '%s' unvollständig – überspringe.", name)
            continue
        try:
            check_host(name, url, key, secret, skip)
            processed += 1
        except Exception as e:
            log.error("Fehler bei '%s': %s", name, e)

    log.info("=== ZA Watchdog Ende: %d Host(s) geprüft ===", processed)


if __name__ == '__main__':
    main()
