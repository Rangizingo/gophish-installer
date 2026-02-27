#!/bin/bash
# ============================================================================
# GoPhish Restore Script
# ============================================================================
# Restores GoPhish from a backup tarball created by the backup process.
# Run after setup-gophish.sh --install on a fresh VM.
#
# Usage: sudo bash restore-gophish.sh /path/to/gophish-backup-YYYYMMDD.tar.gz
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}OK: $1${NC}"; }
fail() { echo -e "  ${RED}FAILED: $1${NC}"; }
step() { echo -e "${YELLOW}[$1] $2${NC}"; }

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Run as root: sudo bash $0 <backup.tar.gz>${NC}"
    exit 1
fi

BACKUP="${1:-}"
if [ -z "$BACKUP" ] || [ ! -f "$BACKUP" ]; then
    echo -e "${RED}Usage: sudo bash $0 /path/to/gophish-backup-YYYYMMDD.tar.gz${NC}"
    exit 1
fi

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN} GoPhish Restore${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# 1. Stop services
step "1/6" "Stopping services..."
systemctl stop gophish 2>/dev/null || true
systemctl stop cloudflared-quick 2>/dev/null || true
ok "Services stopped"

# 2. Extract backup
step "2/6" "Extracting backup..."
tar xzf "$BACKUP" -C /
ok "Files extracted"

# 3. Ensure binary exists and is executable
step "3/6" "Checking GoPhish binary..."
if [ ! -x /opt/gophish/gophish ]; then
    fail "GoPhish binary not found — run setup-gophish.sh --install first"
    exit 1
fi
ok "Binary present"

# 4. Reload and enable services
step "4/6" "Configuring services..."
systemctl daemon-reload
systemctl enable gophish 2>/dev/null || true
systemctl enable cloudflared-quick 2>/dev/null || true
ok "Services enabled"

# 5. Disable sleep/suspend
step "5/6" "Disabling sleep/suspend..."
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true
SUDO_USER_HOME=$(eval echo ~"${SUDO_USER:-$USER}")
if command -v gsettings &>/dev/null; then
    if [ -n "${SUDO_USER:-}" ]; then
        sudo -u "$SUDO_USER" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' 2>/dev/null || true
        sudo -u "$SUDO_USER" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' 2>/dev/null || true
    else
        gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' 2>/dev/null || true
        gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' 2>/dev/null || true
    fi
fi
ok "Sleep/suspend disabled"

# 6. Start services and verify
step "6/6" "Starting services..."
systemctl start gophish
sleep 2
if systemctl is-active --quiet gophish; then
    ok "GoPhish running"
else
    fail "GoPhish failed to start — check: journalctl -u gophish"
    exit 1
fi
systemctl start cloudflared-quick 2>/dev/null || true
sleep 3
if systemctl is-active --quiet cloudflared-quick; then
    TUNNEL_URL=$(grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' /opt/gophish/logs/cloudflared.log 2>/dev/null | tail -1)
    ok "Cloudflare tunnel running"
else
    TUNNEL_URL=""
    echo -e "  ${YELLOW}Cloudflare tunnel not started (set up manually if needed)${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} RESTORE COMPLETE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "  Admin UI:    https://localhost:3333"
echo "  Phish server: http://localhost:80"
if [ -n "$TUNNEL_URL" ]; then
    echo "  Tunnel URL:  $TUNNEL_URL (new URL — update campaign if needed)"
fi
echo ""
echo "  All campaigns, templates, landing pages, groups,"
echo "  SMTP profiles, and admin credentials are restored."
echo ""
