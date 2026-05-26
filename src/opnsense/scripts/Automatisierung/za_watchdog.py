#!/usr/local/bin/python3
"""
Automatisierung - Zenarmor Watchdog
Alle 5 Minuten via Cron aufgerufen.
Prüft pro Host (za_watchdog=1): läuft die Engine, ist ein Restart empfohlen?
Greift nur ein wenn nötig.
"""

import sys, json, ssl, urllib.request, urllib.error, base64, logging, time
import xml.etree.ElementTree as ET

LOG_FILE = '/var/log/automatisierung_watchdog.log'
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler(sys.stdout)],
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
