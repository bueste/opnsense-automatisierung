#!/usr/local/bin/python3
"""
Automatisierung - Backup Job Script
Fetches current OPNsense configuration from all hosts where backup is enabled,
stores them locally, and applies retention policy.

Storage: /var/db/automatisierung/backups/{host_uuid}/YYYY-MM-DD_HHmmss.xml
"""

import sys
import json
import ssl
import urllib.request
import urllib.error
import base64
import logging
import os
import glob
import time
import hashlib
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta

LOG_FILE    = '/var/log/automatisierung_backup.log'
BACKUP_ROOT = '/var/db/automatisierung/backups'

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout),
    ]
)
log = logging.getLogger('automatisierung-backup')

CONFIG_FILE = '/conf/config.xml'


def load_config():
    try:
        tree = ET.parse(CONFIG_FILE)
        root = tree.getroot()
        node = root.find('.//automatisierung')
        if node is None:
            log.warning("No 'automatisierung' section found in config.xml.")
            return None
        return node
    except Exception as e:
        log.error("Configuration error: %s", e)
        return None


def api_call(base_url, api_key, api_secret, endpoint,
             method='GET', data=None, skip_verify=False, raw=False):
    url = base_url.rstrip('/') + '/api/' + endpoint.lstrip('/')
    ctx = ssl.create_default_context()
    if skip_verify:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

    creds = base64.b64encode(f"{api_key}:{api_secret}".encode()).decode()
    headers = {
        'Authorization': f'Basic {creds}',
        'Content-Type': 'application/json',
    }
    body = json.dumps(data or {}).encode() if method == 'POST' else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req, timeout=30, context=ctx) as resp:
            content = resp.read()
            if raw:
                return resp.status, content
            return resp.status, json.loads(content.decode()) if content else {}
    except urllib.error.HTTPError as e:
        body_err = e.read()
        log.debug("HTTP %s from %s: %s", e.code, url, body_err[:200])
        return e.code, {}
    except Exception as e:
        log.warning("  Verbindungsfehler %s: %s", url, e)
        return 0, None


def ensure_dir(uuid):
    path = os.path.join(BACKUP_ROOT, uuid)
    os.makedirs(path, mode=0o750, exist_ok=True)
    return path


def fetch_backup(url, api_key, api_secret, skip_verify):
    """Try multiple methods to get the current running config XML."""

    # Method 1: download 'this' (current running config)
    code, raw = api_call(url, api_key, api_secret, 'core/backup/download/this',
                          skip_verify=skip_verify, raw=True)
    if code == 200 and raw and raw.startswith(b'<?xml'):
        log.info("  ✓ Backup received via /api/core/backup/download/this.")
        return raw

    # Method 2: list remote backups and download latest
    code2, data2 = api_call(url, api_key, api_secret, 'core/backup/list',
                             skip_verify=skip_verify)
    if code2 == 200 and data2:
        files = data2 if isinstance(data2, list) else list(data2.keys())
        if files:
            files.sort()
            latest = files[-1]
            log.info("  Trying download of remote backup: %s", latest)
            code3, raw3 = api_call(url, api_key, api_secret,
                                    f'core/backup/download/{latest}',
                                    skip_verify=skip_verify, raw=True)
            if code3 == 200 and raw3 and raw3.startswith(b'<?xml'):
                log.info("  ✓ Remote backup downloaded: %s", latest)
                return raw3

    log.warning("  ✗ No backup available (tried: /download/this, /list+download).")
    return None


def apply_retention(host_dir, retention_days):
    """Delete backups older than retention_days."""
    cutoff = time.time() - (retention_days * 86400)
    deleted = 0
    for fpath in glob.glob(os.path.join(host_dir, '*.xml')):
        if os.path.getmtime(fpath) < cutoff:
            try:
                os.unlink(fpath)
                deleted += 1
                log.info("  Retention: Deleted: %s", os.path.basename(fpath))
            except Exception as e:
                log.warning("  Retention: Error deleting %s: %s", fpath, e)
    if deleted:
        log.info("  Retention: %d old backup(s) deleted.", deleted)
    return deleted


def skip_if_identical(host_dir, new_content):
    """Return True if the latest backup is identical to new_content."""
    files = sorted(glob.glob(os.path.join(host_dir, '*.xml')))
    if not files:
        return False
    try:
        with open(files[-1], 'rb') as f:
            existing = f.read()
        return existing == new_content
    except Exception:
        return False


def main():
    log.info("=== Automatisierung backup job started ===")
    config = load_config()
    if config is None:
        sys.exit(1)

    # Global backup switch
    general = config.find('general')
    if general is not None:
        global_enabled = general.findtext('backup_enabled', '0').strip() == '1'
        if not global_enabled:
            log.info("Backup globally disabled - exiting.")
            sys.exit(0)
        retention_days = int(general.findtext('backup_retention_days', '30').strip() or 30)
    else:
        log.warning("No 'general' settings found - using defaults.")
        retention_days = 30

    hosts_node = config.find('hosts')
    if hosts_node is None:
        log.info("No hosts configured.")
        sys.exit(0)

    backed_up = 0
    for host in hosts_node.findall('host'):
        if host.findtext('enabled', '0').strip() != '1':
            continue
        if host.findtext('backup_enabled', '0').strip() != '1':
            continue

        name       = host.findtext('name', '').strip()
        url        = host.findtext('url', '').strip()
        api_key    = host.findtext('api_key', '').strip()
        api_secret = host.findtext('api_secret', '').strip()
        skip_tls   = host.findtext('skip_verify_tls', '0').strip() == '1'

        # UUID is stored as an XML attribute on the <host> element in OPNsense config.xml
        uuid = host.attrib.get('uuid', '').strip()

        # Fallback: derive from URL (e.g. non-pkg / manual installations)
        if not uuid:
            uuid = hashlib.md5(url.encode()).hexdigest()

        if not url or not api_key or not api_secret:
            log.warning("Host '%s' incompletely configured - skipping.", name)
            continue

        log.info("=== Backup: %s (%s) ===", name, url)

        xml_content = fetch_backup(url, api_key, api_secret, skip_tls)
        if xml_content is None:
            log.warning("  ✗ No backup received for %s.", name)
            continue

        host_dir = ensure_dir(uuid)

        # Skip if unchanged
        if skip_if_identical(host_dir, xml_content):
            log.info("  Configuration unchanged - no new backup needed.")
        else:
            filename = datetime.now().strftime('%Y-%m-%d_%H%M%S') + '.xml'
            fpath    = os.path.join(host_dir, filename)
            try:
                with open(fpath, 'wb') as f:
                    f.write(xml_content)
                # Write sidecar metadata
                with open(fpath + '.meta.json', 'w') as mf:
                    mf.write(json.dumps({
                        'comment': 'Automatic backup',
                        'source': 'auto',
                        'created': datetime.now().isoformat(),
                    }))
                log.info("  ✓ Backup saved: %s (%d bytes)", filename, len(xml_content))
                backed_up += 1
            except Exception as e:
                log.error("  ✗ Error saving backup: %s", e)

        # Apply retention
        apply_retention(host_dir, retention_days)

    log.info("=== Done: %d host(s) backed up, retention: %d days ===", backed_up, retention_days)


if __name__ == '__main__':
    main()
