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
Automatisierung - Self-Healing for the LOCAL firewall.

Separate cron job (own interval). Every enabled check acts only on the local
Zenarmor engine and is OFF by default + individually opt-in with its own
threshold. A notification is always sent when an action is taken.

Checks:
  * RAM        – restart the engine if the eastpect processes exceed X% of RAM.
  * Disk       – run conservative cleanup if a filesystem exceeds X% usage.
  * Packetloss – restart the engine on 100% packet loss to a probe target
                 (Zenarmor in netmap/inline mode can wedge an interface).
"""

import sys
import os
import time
import logging
import subprocess
import xml.etree.ElementTree as ET
from logging.handlers import RotatingFileHandler

CONFIG_FILE = '/conf/config.xml'
LOG_FILE = '/var/log/automatisierung_selfheal.log'
STATE_FILE = '/tmp/automatisierung_selfheal_last'

_handlers = [RotatingFileHandler(LOG_FILE, maxBytes=1048576, backupCount=3)]
if sys.stdout.isatty():
    _handlers.append(logging.StreamHandler(sys.stdout))
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=_handlers,
)
log = logging.getLogger('automatisierung-selfheal')


def _notify(title, message, priority=0):
    try:
        import notify
        notify.send(title, message, priority)
    except Exception as e:
        log.debug("notify fehlgeschlagen: %s", e)


def _sh(cmd):
    try:
        p = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=120)
        return p.returncode, ((p.stdout or '') + (p.stderr or '')).strip()
    except Exception as e:
        return 1, str(e)


def _txt(node, tag, default=''):
    if node is None:
        return default
    return (node.findtext(tag, default) or default).strip()


def _int(node, tag, default):
    try:
        return int(_txt(node, tag, str(default)) or default)
    except ValueError:
        return default


# --------------------------------------------------------------------------- #
# Engine control (shared)
# --------------------------------------------------------------------------- #
def engine_running():
    rc, _ = _sh('pgrep -x eastpect')
    return rc == 0


def restart_engine():
    rc, out = _sh('/usr/local/sbin/pluginctl -s eastpect restart')
    if rc != 0:
        rc, out = _sh('/usr/sbin/service eastpect restart')
    time.sleep(5)
    return engine_running(), out


# --------------------------------------------------------------------------- #
# RAM check
# --------------------------------------------------------------------------- #
def eastpect_ram_percent():
    """Sum RSS of all eastpect processes as a percentage of physical RAM."""
    rc, pmem = _sh('sysctl -n hw.physmem')
    if rc != 0 or not pmem.isdigit():
        return None
    physmem_kb = int(pmem) / 1024.0
    rc, pids = _sh('pgrep -x eastpect')
    if rc != 0 or not pids:
        return 0.0
    total_rss = 0
    for pid in pids.split():
        rc, rss = _sh('ps -o rss= -p %s' % pid)
        if rc == 0 and rss.strip().isdigit():
            total_rss += int(rss.strip())
    if physmem_kb <= 0:
        return None
    return round(total_rss / physmem_kb * 100.0, 1)


def check_ram(g):
    if _txt(g, 'heal_ram_enabled') != '1':
        return
    threshold = _int(g, 'heal_ram_threshold', 85)
    pct = eastpect_ram_percent()
    if pct is None:
        log.warning("  RAM: konnte Verbrauch nicht ermitteln.")
        return
    log.info("  RAM: Zenarmor-Engine bei %.1f%% (Schwelle %d%%).", pct, threshold)
    if pct >= threshold:
        log.warning("  RAM über Schwelle – starte Engine sanft neu...")
        ok, out = restart_engine()
        if ok:
            log.info("  Engine neugestartet (RAM war %.1f%%).", pct)
            _notify("Self-Healing: Zenarmor neugestartet (RAM)",
                    "RAM-Verbrauch der Engine lag bei %.1f%% (Schwelle %d%%). "
                    "Die Engine wurde automatisch neugestartet." % (pct, threshold), 1)
        else:
            log.error("  Engine-Neustart fehlgeschlagen: %s", (out or '')[:200])
            _notify("Self-Healing FEHLER: Zenarmor-Neustart (RAM)",
                    "RAM bei %.1f%%, automatischer Neustart fehlgeschlagen. Bitte prüfen." % pct, 1)


# --------------------------------------------------------------------------- #
# Disk check
# --------------------------------------------------------------------------- #
def fs_usage_percent(path='/'):
    rc, out = _sh("df -k %s | tail -1 | awk '{print $5}'" % path)
    if rc != 0:
        return None
    out = out.replace('%', '').strip()
    return int(out) if out.isdigit() else None


def check_disk(g):
    if _txt(g, 'heal_disk_enabled') != '1':
        return
    threshold = _int(g, 'heal_disk_threshold', 90)
    pct = fs_usage_percent('/')
    if pct is None:
        log.warning("  Disk: Belegung nicht ermittelbar.")
        return
    log.info("  Disk: / bei %d%% (Schwelle %d%%).", pct, threshold)
    if pct < threshold:
        return

    log.warning("  Disk über Schwelle – starte Aufräum-Massnahmen...")
    actions = []
    # Conservative, non-destructive-first cleanup.
    if os.path.isdir('/usr/local/zenarmor'):
        rc, _ = _sh('/usr/local/sbin/configctl zenarmor log-delete')
        actions.append('ZA-Logs gelöscht' if rc == 0 else 'ZA log-delete fehlgeschlagen')
        rc, _ = _sh('/usr/local/sbin/configctl zenarmor datastore-retire')
        actions.append('ZA-Datastore retired' if rc == 0 else 'datastore-retire fehlgeschlagen')
    # Rotate/trim our own large logs as a last resort.
    _sh("find /var/log -name '*.log' -size +50M -exec sh -c ': > \"$1\"' _ {} \\;")
    after = fs_usage_percent('/')
    log.info("  Disk nach Aufräumen: %s%% (vorher %d%%). Aktionen: %s",
             after, pct, ', '.join(actions) or 'keine')
    _notify("Self-Healing: Disk-Bereinigung",
            "Filesystem / war bei %d%% (Schwelle %d%%). Nach Bereinigung: %s%%. "
            "Aktionen: %s" % (pct, threshold, after, ', '.join(actions) or 'Logs getrimmt'), 1)


# --------------------------------------------------------------------------- #
# Packet-loss check
# --------------------------------------------------------------------------- #
def packet_loss_percent(target, count=5):
    rc, out = _sh('ping -c %d -t 2 %s' % (count, target))
    for line in out.splitlines():
        if 'packet loss' in line:
            # e.g. "5 packets transmitted, 0 packets received, 100.0% packet loss"
            for tok in line.replace(',', ' ').split():
                if tok.endswith('%'):
                    try:
                        return float(tok[:-1])
                    except ValueError:
                        pass
    return None


def check_packetloss(g):
    if _txt(g, 'heal_ifreset_enabled') != '1':
        return
    target = _txt(g, 'heal_ifreset_target')
    if not target:
        log.info("  Paketverlust: kein Probe-Ziel konfiguriert – übersprungen.")
        return
    loss = packet_loss_percent(target)
    if loss is None:
        log.warning("  Paketverlust: Messung zu %s fehlgeschlagen.", target)
        return
    log.info("  Paketverlust zu %s: %.0f%%.", target, loss)
    if loss < 100.0:
        return

    log.warning("  100%% Paketverlust zu %s – starte Engine neu (netmap-Freigabe)...", target)
    ok, out = restart_engine()
    # Re-measure after the restart settles.
    time.sleep(3)
    loss2 = packet_loss_percent(target)
    if loss2 is not None and loss2 < 100.0:
        log.info("  Verbindung wiederhergestellt (Verlust nun %.0f%%).", loss2)
        _notify("Self-Healing: Verbindung wiederhergestellt",
                "100%% Paketverlust zu %s erkannt; Zenarmor-Engine neugestartet, "
                "Verbindung wieder da (Verlust nun %.0f%%)." % (target, loss2))
    else:
        log.error("  Paketverlust besteht weiter (Engine-Neustart ok=%s).", ok)
        _notify("Self-Healing FEHLER: anhaltender Paketverlust",
                "100%% Paketverlust zu %s; Engine-Neustart brachte keine Besserung. "
                "Bitte Schnittstelle/Zenarmor prüfen." % target, 1)


def interval_elapsed(interval_minutes):
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
    log.info("=== Self-Healing Start ===")
    try:
        root = ET.parse(CONFIG_FILE).getroot()
    except Exception as e:
        log.error("Config lesen fehlgeschlagen: %s", e)
        sys.exit(1)

    g = root.find('.//automatisierung/general')
    if g is None:
        log.info("Keine Konfiguration – Ende.")
        sys.exit(0)

    any_enabled = any(_txt(g, k) == '1' for k in
                      ('heal_ram_enabled', 'heal_disk_enabled', 'heal_ifreset_enabled'))
    if not any_enabled:
        log.info("Self-Healing global nicht aktiviert (alle Aktionen aus) – Ende.")
        sys.exit(0)

    interval = _int(g, 'heal_check_interval', 15)
    if not interval_elapsed(interval):
        log.info("Intervall (%d Min) noch nicht erreicht – Ende.", interval)
        sys.exit(0)

    if not os.path.isdir('/usr/local/zenarmor') and not os.path.isdir('/usr/local/sensei'):
        log.info("Zenarmor lokal nicht installiert – Ende.")
        sys.exit(0)

    for fn in (check_ram, check_disk, check_packetloss):
        try:
            fn(g)
        except Exception as e:
            log.error("Fehler in %s: %s", fn.__name__, e)

    log.info("=== Self-Healing Ende ===")


if __name__ == '__main__':
    main()
