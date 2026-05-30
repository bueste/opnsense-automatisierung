#!/bin/sh
# Compile all .po locale files to .mo binaries.
# Run on the OPNsense firewall (or any FreeBSD/Linux host with gettext-tools):
#   sh scripts/compile_mo.sh
#
# On OPNsense, install gettext first if needed:
#   pkg install gettext-tools

LOCALE_DIR="$(cd "$(dirname "$0")/.." && pwd)/src/opnsense/mvc/app/locale"

if ! command -v msgfmt >/dev/null 2>&1; then
    echo "ERROR: msgfmt not found. Install with: pkg install gettext-tools"
    exit 1
fi

ok=0; fail=0
for po in "$LOCALE_DIR"/*/LC_MESSAGES/OPNsense.Automatisierung.po; do
    mo="${po%.po}.mo"
    lang=$(echo "$po" | sed 's|.*/locale/\([^/]*\)/.*|\1|')
    if msgfmt -o "$mo" "$po" 2>/dev/null; then
        echo "  OK  $lang"
        ok=$((ok + 1))
    else
        echo "  ERR $lang"
        fail=$((fail + 1))
    fi
done

echo ""
echo "Compiled: $ok OK, $fail failed"
