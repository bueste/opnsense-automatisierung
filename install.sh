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

# ---- Cache leeren ----
echo "[4/4] Phalcon View Cache leeren..."
if ls /var/cache/opnsense/views/*.php 2>/dev/null | head -1 > /dev/null; then
    rm -f /var/cache/opnsense/views/*.php
    echo "     Cache geleert."
else
    echo "     Cache bereits leer."
fi

# ---- Backup-Verzeichnis erstellen ----
mkdir -p /var/db/automatisierung/backups
chmod 750 /var/db/automatisierung/backups

echo ""
echo "=== Installation abgeschlossen ==="
echo "Plugin verfügbar unter: Dienste → Automatisierung"
echo ""
echo "Hinweis: Bei Erstinstallation OPNsense-UI neu laden (Ctrl+F5)."
