#!/bin/sh
# OPNsense Automatisierung Plugin — Development Installer
# Run this script ON the OPNsense firewall (as root) from the cloned repo:
#   sh install.sh
#
# For production use, build a proper package with: make package

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/src/opnsense/mvc/app"
TARGET="/usr/local/opnsense/mvc/app"

echo "=== OPNsense Automation Plugin Installer ==="
echo "Source:  $SRC"
echo "Target:  $TARGET"
echo ""

# ---- [1/7] Controllers ----
echo "[1/7] Copying controllers..."
mkdir -p "$TARGET/controllers/OPNsense/Automatisierung/Api"
cp "$SRC/controllers/OPNsense/Automatisierung/IndexController.php" \
   "$TARGET/controllers/OPNsense/Automatisierung/IndexController.php"
cp "$SRC/controllers/OPNsense/Automatisierung/Api/SettingsController.php" \
   "$TARGET/controllers/OPNsense/Automatisierung/Api/SettingsController.php"
cp "$SRC/controllers/OPNsense/Automatisierung/Api/ServiceController.php" \
   "$TARGET/controllers/OPNsense/Automatisierung/Api/ServiceController.php"
cp "$SRC/controllers/OPNsense/Automatisierung/Api/BackupController.php" \
   "$TARGET/controllers/OPNsense/Automatisierung/Api/BackupController.php"

# ---- [2/7] Models ----
echo "[2/7] Copying models..."
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

# ---- [3/7] Views ----
echo "[3/7] Copying views..."
mkdir -p "$TARGET/views/OPNsense/Automatisierung"
cp "$SRC/views/OPNsense/Automatisierung/config.volt" \
   "$TARGET/views/OPNsense/Automatisierung/config.volt"
cp "$SRC/views/OPNsense/Automatisierung/status.volt" \
   "$TARGET/views/OPNsense/Automatisierung/status.volt"
cp "$SRC/views/OPNsense/Automatisierung/backup.volt" \
   "$TARGET/views/OPNsense/Automatisierung/backup.volt"

# ---- [4/7] Scripts ----
echo "[4/7] Copying scripts..."
mkdir -p /usr/local/opnsense/scripts/Automatisierung
cp "$SCRIPT_DIR/src/opnsense/scripts/Automatisierung/za_watchdog.py" \
   /usr/local/opnsense/scripts/Automatisierung/za_watchdog.py
cp "$SCRIPT_DIR/src/opnsense/scripts/Automatisierung/backup_job.py" \
   /usr/local/opnsense/scripts/Automatisierung/backup_job.py
chmod +x /usr/local/opnsense/scripts/Automatisierung/*.py

# ---- [5/7] Configd action file ----
echo "[5/7] Registering configd actions..."
mkdir -p /usr/local/opnsense/service/conf/actions.d
cp "$SCRIPT_DIR/src/opnsense/service/conf/actions.d/actions_automatisierung.conf" \
   /usr/local/opnsense/service/conf/actions.d/actions_automatisierung.conf
# Reload configd so it picks up the new actions
service configd restart 2>/dev/null || true
echo "     Configd actions registered (automatisierung backup, automatisierung watchdog)."

# ---- [6/7] Locale / .mo files ----
echo "[6/7] Compiling locale files..."
LOCALE_DIR="$TARGET/locale"
mkdir -p "$LOCALE_DIR"
# Copy .po files from repo
for lang_dir in "$SRC/locale"/*/LC_MESSAGES; do
    lang=$(basename "$(dirname "$lang_dir")")
    mkdir -p "$LOCALE_DIR/$lang/LC_MESSAGES"
    po="$lang_dir/OPNsense.Automatisierung.po"
    mo="$LOCALE_DIR/$lang/LC_MESSAGES/OPNsense.Automatisierung.mo"
    if [ -f "$po" ]; then
        cp "$po" "$LOCALE_DIR/$lang/LC_MESSAGES/OPNsense.Automatisierung.po"
        if command -v msgfmt >/dev/null 2>&1; then
            msgfmt -o "$mo" "$po" && echo "     Compiled: $lang" || echo "     Warning: msgfmt failed for $lang"
        else
            echo "     Warning: msgfmt not found, skipping .mo compile for $lang"
            echo "     Install gettext: pkg install gettext-tools"
        fi
    fi
done

# ---- [6/7 cont.] Backup directory ----
mkdir -p /var/db/automatisierung/backups
chmod 750 /var/db/automatisierung/backups

# ---- [7/7] Cron jobs via cron.d ----
echo "[7/7] Setting up scheduled jobs..."
# Use /etc/cron.d for cleaner cron management (avoids crontab -l manipulation)
cat > /etc/cron.d/automatisierung << 'CRONEOF'
# OPNsense Automatisierung Plugin — scheduled jobs
# Edit via: Services → Automation → Configuration (schedule settings)
# Or remove this file and configure via OPNsense Cron UI (Services → Cron)
*/5 * * * * root /usr/local/bin/flock -n -E 0 -o /tmp/za_watchdog.lock /usr/local/sbin/configctl automatisierung watchdog >> /var/log/automatisierung_watchdog.log 2>&1
0 * * * * root /usr/local/bin/flock -n -E 0 -o /tmp/automatisierung_backup.lock /usr/local/sbin/configctl automatisierung backup >> /var/log/automatisierung_backup.log 2>&1
CRONEOF
chmod 644 /etc/cron.d/automatisierung
echo "     Cron jobs written to /etc/cron.d/automatisierung"
echo "     (ZA watchdog: every 5 min, Backup: hourly)"

# ---- Clear Phalcon view cache ----
echo "     Clearing Phalcon view cache..."
rm -f /var/cache/opnsense/views/*.php 2>/dev/null || true

echo ""
echo "=== Installation complete ==="
echo "Plugin available at: Services → Automation"
echo ""
echo "Note: On first install, reload the OPNsense UI (Ctrl+F5)."
