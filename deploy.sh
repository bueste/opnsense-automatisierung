#!/bin/bash
# OPNsense Automatisierung Plugin — Remote Deploy Script
# Deploys the plugin to a remote OPNsense firewall via SSH/SCP.
#
# Usage:
#   ./deploy.sh root@192.168.1.1
#   ./deploy.sh root@192.168.1.1 -i ~/.ssh/id_ed25519
#
# Options:
#   -i <keyfile>   SSH identity file (optional)
#   -p <port>      SSH port (default: 22)

set -e

usage() {
    echo "Usage: $0 <user@host> [-i keyfile] [-p port]"
    echo "Example: $0 root@192.168.1.1 -i ~/.ssh/id_ed25519"
    exit 1
}

TARGET_HOST=""
SSH_OPTS="-o StrictHostKeyChecking=accept-new"

# Parse arguments
TARGET_HOST="$1"
shift || usage

while [ "$#" -gt 0 ]; do
    case "$1" in
        -i) SSH_OPTS="$SSH_OPTS -i $2"; shift 2 ;;
        -p) SSH_OPTS="$SSH_OPTS -p $2"; shift 2 ;;
        *)  usage ;;
    esac
done

[ -z "$TARGET_HOST" ] && usage

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REMOTE_TMP="/tmp/automatisierung_deploy"

echo "=== Deploy OPNsense Automatisierung Plugin ==="
echo "Target: $TARGET_HOST"
echo ""

# ---- Verzeichnis auf Firewall erstellen ----
echo "[1/3] Remote-Verzeichnis vorbereiten..."
# shellcheck disable=SC2086
ssh $SSH_OPTS "$TARGET_HOST" "rm -rf $REMOTE_TMP && mkdir -p $REMOTE_TMP"

# ---- Plugin-Dateien hochladen ----
echo "[2/3] Dateien hochladen..."
# shellcheck disable=SC2086
scp $SSH_OPTS -r \
    "$SCRIPT_DIR/src" \
    "$SCRIPT_DIR/install.sh" \
    "$TARGET_HOST:$REMOTE_TMP/"

# ---- Installer auf Firewall ausführen ----
echo "[3/3] Installer ausführen..."
# shellcheck disable=SC2086
ssh $SSH_OPTS "$TARGET_HOST" "cd $REMOTE_TMP && sh install.sh"

# ---- Aufräumen ----
# shellcheck disable=SC2086
ssh $SSH_OPTS "$TARGET_HOST" "rm -rf $REMOTE_TMP"

echo ""
echo "=== Deploy abgeschlossen ==="
echo "Plugin verfügbar unter: Dienste → Automatisierung"
