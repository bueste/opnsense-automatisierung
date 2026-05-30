#!/bin/sh
# OPNsense Automatisierung Plugin — Local Installer
# Run this script ON the OPNsense firewall (as root):
#   sh install.sh
#
# The script copies plugin files to the correct OPNsense MVC paths
# and clears the Phalcon view cache.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/src/opnsense/mvc/app"
TARGET="/usr/local/opnsense/mvc/app"

echo "=== OPNsense Automatisierung Plugin Installer ==="
echo "Source:  $SRC"
echo "Target:  $TARGET"
echo ""

# ---- Controllers ----
echo "[1/4] Kopiere Controllers..."
mkdir -p "$TARGET/controllers/OPNsense/Automatisierung/Api"
cp "$SRC/controllers/OPNsense/Automatisierung/IndexController.php" \
   "$TARGET/controllers/OPNsense/Automatisierung/IndexController.php"
cp "$SRC/controllers/OPNsense/Automatisierung/Api/SettingsController.php" \
   "$TARGET/controllers/OPNsense/Automatisierung/Api/SettingsController.php"
cp "$SRC/controllers/OPNsense/Automatisierung/Api/ServiceController.php" \
   "$TARGET/controllers/OPNsense/Automatisierung/Api/ServiceController.php"
cp "$SRC/controllers/OPNsense/Automatisierung/Api/BackupController.php" \
   "$TARGET/controllers/OPNsense/Automatisierung/Api/BackupController.php"

# ---- Models ----
echo "[2/4] Kopiere Models..."
mkdir -p "$TARGET/models/OPNsense/Automatisierung/Menu"
mkdir -p "$TARGET/models/OPNsense/Automatisierung/ACL"
cp "$SRC/models/OPNsense/Automatisierung/Automatisierung.php" \
   "$TARGET/models/OPNsense/Automatisierung/Automatisierung.php"
cp "$SRC/models/OPNsense/Automatisierung/Automatisierung.xml" \
   "$TARGET/models/OPNsense/Automatisierung/Automatisierung.xml"
cp "$SRC/models/OPNsense/Automatisierung/Menu/Menu.xml" \
   "$TARGET/models/OPNsense/Automatisierung/Menu/Menu.xml"
cp "$SRC/models/OPNsense/Automatisierung/ACL/ACL.xml" \
   "$TARGET/models/OPNsense/Automatisierung/ACL/ACL.xml"

# ---- Views ----
echo "[3/4] Kopiere Views..."
mkdir -p "$TARGET/views/OPNsense/Automatisierung"
cp "$SRC/views/OPNsense/Automatisierung/config.volt" \
   "$TARGET/views/OPNsense/Automatisierung/config.volt"
cp "$SRC/views/OPNsense/Automatisierung/status.volt" \
   "$TARGET/views/OPNsense/Automatisierung/status.volt"
cp "$SRC/views/OPNsense/Automatisierung/backup.volt" \
   "$TARGET/views/OPNsense/Automatisierung/backup.volt"

# ---- Scripts ----
echo "[4/6] Kopiere Scripts..."
mkdir -p /usr/local/opnsense/scripts/Automatisierung
cp "$SCRIPT_DIR/src/opnsense/scripts/Automatisierung/za_watchdog.py" \
   /usr/local/opnsense/scripts/Automatisierung/za_watchdog.py
cp "$SCRIPT_DIR/src/opnsense/scripts/Automatisierung/backup_job.py" \
   /usr/local/opnsense/scripts/Automatisierung/backup_job.py
chmod +x /usr/local/opnsense/scripts/Automatisierung/*.py

# ---- Cache leeren ----
echo "[5/6] Phalcon View Cache leeren..."
if ls /var/cache/opnsense/views/*.php 2>/dev/null | head -1 > /dev/null; then
    rm -f /var/cache/opnsense/views/*.php
    echo "     Cache geleert."
else
    echo "     Cache bereits leer."
fi

# ---- Backup-Verzeichnis erstellen ----
mkdir -p /var/db/automatisierung/backups
chmod 750 /var/db/automatisierung/backups

# ---- Cron-Jobs einrichten ----
echo "[6/6] Cron-Jobs einrichten..."
WATCHDOG_CMD="*/5 * * * * /usr/local/bin/flock -n -E 0 -o /tmp/za_watchdog.lock /usr/local/bin/python3 /usr/local/opnsense/scripts/Automatisierung/za_watchdog.py >> /var/log/automatisierung_watchdog.log 2>&1"
BACKUP_CMD="0 * * * * /usr/local/bin/flock -n -E 0 -o /tmp/automatisierung_backup.lock /usr/local/bin/python3 /usr/local/opnsense/scripts/Automatisierung/backup_job.py >> /var/log/automatisierung_backup.log 2>&1"

( crontab -l 2>/dev/null | grep -v 'Automatisierung/za_watchdog\|Automatisierung/backup_job'
  echo "$WATCHDOG_CMD"
  echo "$BACKUP_CMD"
) | crontab -
echo "     Cron-Jobs gesetzt (ZA Watchdog: alle 5 Min, Backup: stündlich)."

echo ""
echo "=== Installation abgeschlossen ==="
echo "Plugin verfügbar unter: Dienste → Automatisierung"
echo ""
echo "Hinweis: Bei Erstinstallation OPNsense-UI neu laden (Ctrl+F5)."
