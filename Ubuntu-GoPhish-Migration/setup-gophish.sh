#!/bin/bash
# ============================================================================
# GoPhish + Cloudflare Tunnel Setup for Ubuntu
# ============================================================================
# Installs GoPhish, restores campaign data, sets up Cloudflare named tunnel.
# Idempotent — safe to run multiple times, skips what's already done.
#
# Usage:
#   sudo bash setup-gophish.sh                    # Run all phases
#   sudo bash setup-gophish.sh --install          # Phase 1 only (install)
#   sudo bash setup-gophish.sh --restore --api-key KEY  # Phase 2 only (restore)
#   sudo bash setup-gophish.sh --tunnel           # Phase 3 only (tunnel)
# ============================================================================

set -euo pipefail

# --- Config ---
GOPHISH_DIR="/opt/gophish"
LOGS_DIR="$GOPHISH_DIR/logs"
BACKUP_DIR="$GOPHISH_DIR/backup"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_BASE="https://127.0.0.1:3333/api"
TUNNEL_HOSTNAME="portal.expertimportersllc.com"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# --- Helpers ---
info()    { echo -e "${CYAN}$1${NC}"; }
ok()      { echo -e "  ${GREEN}OK: $1${NC}"; }
skip()    { echo -e "  ${GREEN}SKIP: $1${NC}"; }
warn()    { echo -e "  ${YELLOW}$1${NC}"; }
fail()    { echo -e "  ${RED}FAILED: $1${NC}"; }
header()  { echo -e "\n${CYAN}========================================${NC}"; echo -e "${CYAN} $1${NC}"; echo -e "${CYAN}========================================${NC}\n"; }
step()    { echo -e "${YELLOW}[$1] $2${NC}"; }

pause_for_user() {
    echo ""
    echo -e "${MAGENTA}${BOLD}--- ACTION REQUIRED ---${NC}"
    echo -e "${MAGENTA}$1${NC}"
    echo ""
    read -rp "Press Enter when done..."
    echo ""
}

# Check if a command exists
has_cmd() { command -v "$1" &>/dev/null; }

# POST JSON to GoPhish API, return HTTP status code
gophish_post() {
    local endpoint="$1"
    local data="$2"
    local label="$3"
    local result
    result=$(curl -sk -X POST "$API_BASE/$endpoint?api_key=$API_KEY" \
        -H "Content-Type: application/json" \
        -d "$data" -w "\n%{http_code}" 2>/dev/null)
    local code
    code=$(echo "$result" | tail -1)
    local body
    body=$(echo "$result" | sed '$d')
    if [ "$code" -ge 200 ] && [ "$code" -lt 300 ]; then
        ok "$label"
        return 0
    else
        fail "$label (HTTP $code)"
        echo "  $body" | head -3
        return 1
    fi
}

# ============================================================================
# PHASE 1: INSTALL
# ============================================================================
phase_install() {
    header "PHASE 1: Install GoPhish + cloudflared"

    # --- 1. Prerequisites ---
    step "1/7" "Installing prerequisites..."
    local pkgs=("curl" "unzip" "jq" "python3" "git")
    local to_install=()
    for pkg in "${pkgs[@]}"; do
        if has_cmd "$pkg"; then
            skip "$pkg already installed"
        else
            to_install+=("$pkg")
        fi
    done
    # netcat might be ncat or nc depending on distro
    if ! has_cmd "nc" && ! has_cmd "ncat"; then
        to_install+=("ncat")
    else
        skip "netcat already installed"
    fi
    if [ ${#to_install[@]} -gt 0 ]; then
        warn "Installing: ${to_install[*]}"
        apt-get update -qq
        apt-get install -y -qq "${to_install[@]}"
        ok "Prerequisites installed"
    fi

    # --- 2. Create directories ---
    step "2/7" "Creating directories..."
    for d in "$GOPHISH_DIR" "$LOGS_DIR" "$BACKUP_DIR"; do
        if [ -d "$d" ]; then
            skip "$d exists"
        else
            mkdir -p "$d"
            ok "Created $d"
        fi
    done

    # --- 3. Download GoPhish ---
    step "3/7" "Downloading GoPhish..."
    if [ -f "$GOPHISH_DIR/gophish" ]; then
        skip "GoPhish binary already exists"
    else
        local download_url
        download_url=$(curl -s https://api.github.com/repos/gophish/gophish/releases/latest \
            | grep -oP '"browser_download_url":\s*"\K[^"]*linux-64bit.zip')
        if [ -z "$download_url" ]; then
            fail "Could not find Linux 64-bit release URL"
            exit 1
        fi
        warn "Downloading from: $download_url"
        curl -L -o "$GOPHISH_DIR/gophish.zip" "$download_url"
        unzip -o "$GOPHISH_DIR/gophish.zip" -d "$GOPHISH_DIR"
        rm -f "$GOPHISH_DIR/gophish.zip"
        chmod +x "$GOPHISH_DIR/gophish"
        ok "GoPhish downloaded and extracted"
    fi

    # --- 4. Write config.json ---
    step "4/7" "Writing config.json..."
    cat > "$GOPHISH_DIR/config.json" << 'CONFIGEOF'
{
    "admin_server": {
        "listen_url": "0.0.0.0:3333",
        "use_tls": true,
        "cert_path": "gophish_admin.crt",
        "key_path": "gophish_admin.key"
    },
    "phish_server": {
        "listen_url": "0.0.0.0:80",
        "use_tls": false
    },
    "db_name": "sqlite3",
    "db_path": "gophish.db",
    "migrations_prefix": "db/db_",
    "contact_address": ""
}
CONFIGEOF
    ok "Admin on 0.0.0.0:3333 (TLS), Phish on 0.0.0.0:80 (HTTP)"

    # --- 5. Create systemd service ---
    step "5/7" "Creating systemd service..."
    if systemctl is-active --quiet gophish 2>/dev/null; then
        skip "GoPhish service already running"
    else
        # Stop if in failed/crash-looping state
        systemctl stop gophish 2>/dev/null || true
        cat > /etc/systemd/system/gophish.service << 'SVCEOF'
[Unit]
Description=GoPhish Phishing Framework
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/gophish
ExecStart=/opt/gophish/gophish
Restart=always
RestartSec=5
StandardOutput=append:/opt/gophish/logs/gophish.log
StandardError=append:/opt/gophish/logs/gophish-error.log

[Install]
WantedBy=multi-user.target
SVCEOF
        systemctl daemon-reload
        systemctl enable gophish
        # Clear old logs before first start
        rm -f "$LOGS_DIR/gophish.log" "$LOGS_DIR/gophish-error.log"
        systemctl start gophish
        ok "GoPhish service created and started"
    fi

    # --- 6. Extract temp password ---
    step "6/7" "Waiting for GoPhish to initialize..."
    local attempts=0
    local temp_pw=""
    while [ $attempts -lt 15 ] && [ -z "$temp_pw" ]; do
        attempts=$((attempts + 1))
        if [ -f "$LOGS_DIR/gophish.log" ]; then
            temp_pw=$(grep -oP "Please login with the username admin and the password \K\S+" "$LOGS_DIR/gophish.log" 2>/dev/null || true)
        fi
        if [ -z "$temp_pw" ]; then
            sleep 2
        fi
    done

    if [ -n "$temp_pw" ]; then
        echo ""
        echo -e "${MAGENTA}  ==============================================${NC}"
        echo -e "${MAGENTA}  TEMP ADMIN PASSWORD: $temp_pw${NC}"
        echo -e "${MAGENTA}  ==============================================${NC}"
        echo -e "${MAGENTA}  Login: https://localhost:3333${NC}"
        echo -e "${MAGENTA}  User:  admin${NC}"
    else
        # GoPhish was already initialized (password already changed)
        warn "No temp password found — GoPhish was likely already initialized."
        warn "If you forgot your password, delete $GOPHISH_DIR/gophish.db and restart the service."
    fi

    # --- 7. Install cloudflared ---
    step "7/7" "Installing cloudflared..."
    if has_cmd "cloudflared"; then
        local cf_ver
        cf_ver=$(cloudflared --version 2>&1 | head -1)
        skip "cloudflared already installed ($cf_ver)"
    else
        # Add Cloudflare apt repo
        mkdir -p --mode=0755 /usr/share/keyrings
        curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
            | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

        local codename
        codename=$(lsb_release -cs 2>/dev/null || echo "jammy")
        echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $codename main" \
            | tee /etc/apt/sources.list.d/cloudflared.list >/dev/null

        apt-get update -qq
        apt-get install -y -qq cloudflared
        if has_cmd "cloudflared"; then
            local cf_ver
            cf_ver=$(cloudflared --version 2>&1 | head -1)
            ok "cloudflared installed ($cf_ver)"
        else
            fail "cloudflared install failed"
        fi
    fi

    header "PHASE 1 COMPLETE"
    echo -e "${BOLD}Services:${NC}"
    systemctl status gophish --no-pager -l 2>/dev/null | head -5
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Open Firefox → https://localhost:3333"
    echo "  2. Accept the self-signed certificate warning"
    if [ -n "$temp_pw" ]; then
        echo "  3. Login: admin / $temp_pw"
    else
        echo "  3. Login with your admin credentials"
    fi
    echo "  4. Change password immediately"
    echo "  5. Go to Settings → copy the API key"
    echo "  6. Come back here and enter the API key"
}

# ============================================================================
# PHASE 2: RESTORE DATA
# ============================================================================
phase_restore() {
    header "PHASE 2: Restore GoPhish Data"

    if [ -z "${API_KEY:-}" ]; then
        echo -n "Enter GoPhish API key: "
        read -r API_KEY
        if [ -z "$API_KEY" ]; then
            fail "No API key provided. Exiting."
            exit 1
        fi
    fi

    # --- 1. Verify API ---
    step "1/6" "Verifying API connectivity..."
    local api_check
    api_check=$(curl -sk -o /dev/null -w "%{http_code}" "$API_BASE/templates/?api_key=$API_KEY" 2>/dev/null)
    if [ "$api_check" -ge 200 ] && [ "$api_check" -lt 300 ]; then
        ok "API reachable (HTTP $api_check)"
    else
        fail "Cannot reach GoPhish API at $API_BASE (HTTP $api_check)"
        echo "  Is the gophish service running? Try: sudo systemctl status gophish"
        exit 1
    fi

    # --- 2. Restore email template ---
    step "2/6" "Restoring email template..."
    local email_html_file="$SCRIPT_DIR/email-template.html"
    if [ ! -f "$email_html_file" ]; then
        fail "Missing: $email_html_file"
        echo "  Place email-template.html next to this script."
        exit 1
    fi
    local email_html
    email_html=$(cat "$email_html_file")
    local template_json
    template_json=$(jq -n \
        --arg name "Password Expiration Notice" \
        --arg subject "Action Required: Your password expires in 3 business days" \
        --arg html "$email_html" \
        --arg text "Hi {{.FirstName}},\n\nYour Microsoft 365 password expires in 3 business days. Reset it now: {{.URL}}\n\nThanks,\nIT Support Team" \
        '{name: $name, subject: $subject, text: $text, html: $html, envelope_sender: "", attachments: []}')
    gophish_post "templates/" "$template_json" "Password Expiration Notice" || true

    # --- 3. Restore landing page ---
    step "3/6" "Restoring landing page..."
    local landing_html_file="$SCRIPT_DIR/landing-page.html"
    if [ ! -f "$landing_html_file" ]; then
        fail "Missing: $landing_html_file"
        echo "  Place landing-page.html next to this script."
        exit 1
    fi
    local landing_html
    landing_html=$(cat "$landing_html_file")
    local page_json
    page_json=$(jq -n \
        --arg name "Microsoft 365 Login" \
        --arg html "$landing_html" \
        '{name: $name, html: $html, capture_credentials: true, capture_passwords: true, redirect_url: "https://restaurantequippers.sharepoint.com"}')
    gophish_post "pages/" "$page_json" "Microsoft 365 Login (with confirmation screen)" || true

    # --- 4. Restore target group ---
    step "4/6" "Restoring target group..."
    local group_json
    group_json=$(cat << 'GROUPEOF'
{
    "name": "IT Dept Test Group",
    "targets": [
        {"email": "pblanco@equippers.com", "first_name": "Peter", "last_name": "Blanco", "position": "IT Manager"},
        {"email": "kmarchese@equippers.com", "first_name": "Kevin", "last_name": "Marchese", "position": "IT"},
        {"email": "mfrank@equippers.com", "first_name": "Matt", "last_name": "Frank", "position": "IT"}
    ]
}
GROUPEOF
)
    gophish_post "groups/" "$group_json" "IT Dept Test Group (3 targets)" || true

    # --- 5. Restore SMTP profile ---
    step "5/6" "Restoring SMTP profile..."
    local smtp_json
    smtp_json=$(cat << 'SMTPEOF'
{
    "name": "support@expertimportersllc.com",
    "interface_type": "SMTP",
    "host": "mail.expertimportersllc.com:465",
    "from_address": "support@expertimportersllc.com",
    "username": "support@expertimportersllc.com",
    "password": "",
    "ignore_cert_errors": true,
    "headers": []
}
SMTPEOF
)
    gophish_post "smtp/" "$smtp_json" "support@expertimportersllc.com [PASSWORD BLANK]" || true

    # --- 6. Test SMTP connectivity ---
    step "6/6" "Testing SMTP connectivity..."
    if nc -zv -w 5 mail.expertimportersllc.com 465 2>&1 | grep -qi "succeeded\|connected\|open"; then
        ok "mail.expertimportersllc.com:465 reachable"
    else
        warn "Could not verify SMTP connectivity — check firewall/outbound rules"
    fi

    header "PHASE 2 COMPLETE"
    echo -e "${BOLD}Remaining manual steps:${NC}"
    echo "  1. GoPhish UI → Sending Profiles → edit → enter SMTP password"
    echo "  2. Send a test email to verify delivery"
    echo ""
}

# ============================================================================
# PHASE 3: CLOUDFLARE TUNNEL
# ============================================================================
phase_tunnel() {
    header "PHASE 3: Cloudflare Named Tunnel"

    if ! has_cmd "cloudflared"; then
        fail "cloudflared not installed. Run Phase 1 first."
        exit 1
    fi

    # --- 1. Authenticate ---
    step "1/7" "Cloudflare authentication..."
    local user_home
    user_home=$(eval echo ~"${SUDO_USER:-$USER}")
    local cert_path="$user_home/.cloudflared/cert.pem"

    if [ -f "$cert_path" ]; then
        skip "Already authenticated ($cert_path exists)"
    else
        echo ""
        echo -e "${YELLOW}  cloudflared tunnel login will open your browser.${NC}"
        echo -e "${YELLOW}  Log into Cloudflare and select a zone (e.g. blancoitsolutions.com).${NC}"
        echo -e "${YELLOW}  NOTE: expertimportersllc.com is on Epik, not Cloudflare — use any existing zone.${NC}"
        echo ""
        # Run as the actual user, not root
        if [ -n "${SUDO_USER:-}" ]; then
            sudo -u "$SUDO_USER" cloudflared tunnel login
        else
            cloudflared tunnel login
        fi
        if [ -f "$cert_path" ]; then
            ok "Authenticated"
        else
            fail "Authentication failed — cert.pem not found"
            exit 1
        fi
    fi

    # --- 2. Create tunnel ---
    step "2/7" "Creating named tunnel..."
    local tunnel_uuid=""
    local cf_dir="$user_home/.cloudflared"

    # Check if tunnel already exists
    local existing
    if [ -n "${SUDO_USER:-}" ]; then
        existing=$(sudo -u "$SUDO_USER" cloudflared tunnel list 2>/dev/null | grep "gophish-portal" || true)
    else
        existing=$(cloudflared tunnel list 2>/dev/null | grep "gophish-portal" || true)
    fi

    if [ -n "$existing" ]; then
        tunnel_uuid=$(echo "$existing" | awk '{print $1}')
        skip "Tunnel gophish-portal already exists (UUID: $tunnel_uuid)"
    else
        local create_output
        if [ -n "${SUDO_USER:-}" ]; then
            create_output=$(sudo -u "$SUDO_USER" cloudflared tunnel create gophish-portal 2>&1)
        else
            create_output=$(cloudflared tunnel create gophish-portal 2>&1)
        fi
        tunnel_uuid=$(echo "$create_output" | grep -oP 'id \K[a-f0-9-]+' | head -1)
        if [ -z "$tunnel_uuid" ]; then
            # Try alternate pattern
            tunnel_uuid=$(echo "$create_output" | grep -oP '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' | head -1)
        fi
        if [ -n "$tunnel_uuid" ]; then
            ok "Tunnel created (UUID: $tunnel_uuid)"
        else
            fail "Could not extract tunnel UUID from output:"
            echo "  $create_output"
            exit 1
        fi
    fi

    # --- 3. Write config.yml ---
    step "3/7" "Writing tunnel config..."
    local creds_file="$cf_dir/$tunnel_uuid.json"
    if [ ! -f "$creds_file" ]; then
        fail "Credentials file not found: $creds_file"
        exit 1
    fi

    cat > "$cf_dir/config.yml" << EOF
tunnel: $tunnel_uuid
credentials-file: $creds_file

ingress:
  - hostname: $TUNNEL_HOSTNAME
    service: http://localhost:80
  - service: http_status:404
EOF
    ok "Config written to $cf_dir/config.yml"
    echo -e "  Routing: ${BOLD}$TUNNEL_HOSTNAME${NC} → localhost:80"

    # --- 4. Epik DNS ---
    step "4/7" "DNS setup required..."
    echo ""
    echo -e "${MAGENTA}${BOLD}  ======================================================${NC}"
    echo -e "${MAGENTA}  ADD THIS DNS RECORD IN EPIK:${NC}"
    echo -e "${MAGENTA}  ${NC}"
    echo -e "${MAGENTA}  Log into Epik → Domain Manager → expertimportersllc.com${NC}"
    echo -e "${MAGENTA}  → DNS Zone Editor → CNAME tab → Add:${NC}"
    echo -e "${MAGENTA}  ${NC}"
    echo -e "${MAGENTA}    Host:      portal${NC}"
    echo -e "${MAGENTA}    Points to: ${tunnel_uuid}.cfargotunnel.com${NC}"
    echo -e "${MAGENTA}    TTL:       300${NC}"
    echo -e "${MAGENTA}  ======================================================${NC}"
    echo ""
    read -rp "Press Enter after adding the DNS record..."

    # --- 5. Verify DNS ---
    step "5/7" "Verifying DNS propagation..."
    local dns_result=""
    local dns_attempts=0
    while [ $dns_attempts -lt 6 ] && [ -z "$dns_result" ]; do
        dns_attempts=$((dns_attempts + 1))
        dns_result=$(dig +short "$TUNNEL_HOSTNAME" CNAME 2>/dev/null || true)
        if [ -z "$dns_result" ]; then
            if [ $dns_attempts -lt 6 ]; then
                warn "DNS not propagated yet, waiting 10s... (attempt $dns_attempts/6)"
                sleep 10
            fi
        fi
    done

    if [ -n "$dns_result" ]; then
        ok "DNS resolves: $TUNNEL_HOSTNAME → $dns_result"
    else
        warn "DNS not resolving yet. This can take a few minutes."
        warn "You can verify later with: dig $TUNNEL_HOSTNAME CNAME +short"
        warn "Continuing with service setup..."
    fi

    # --- 6. Install cloudflared service ---
    step "6/7" "Installing cloudflared as system service..."
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        skip "cloudflared service already running"
    else
        # Copy config and credentials to system location for the service
        mkdir -p /etc/cloudflared
        cp "$cf_dir/config.yml" /etc/cloudflared/config.yml
        cp "$creds_file" "/etc/cloudflared/$tunnel_uuid.json"
        # Update credentials path in system config
        sed -i "s|$creds_file|/etc/cloudflared/$tunnel_uuid.json|" /etc/cloudflared/config.yml

        cloudflared service install 2>/dev/null || true
        systemctl enable cloudflared 2>/dev/null || true
        systemctl start cloudflared
        ok "cloudflared service started"
    fi

    # --- 7. Set service dependency ---
    step "7/7" "Setting service dependency..."
    local override_dir="/etc/systemd/system/cloudflared.service.d"
    if [ -f "$override_dir/override.conf" ]; then
        skip "Service dependency already configured"
    else
        mkdir -p "$override_dir"
        cat > "$override_dir/override.conf" << 'DEPEOF'
[Unit]
After=gophish.service
Wants=gophish.service
DEPEOF
        systemctl daemon-reload
        ok "cloudflared starts after gophish"
    fi

    header "PHASE 3 COMPLETE"
    echo -e "${BOLD}Tunnel info:${NC}"
    echo "  UUID:     $tunnel_uuid"
    echo "  Hostname: $TUNNEL_HOSTNAME"
    echo "  Route:    $TUNNEL_HOSTNAME → localhost:80"
    echo ""
}

# ============================================================================
# PHASE 4: VERIFICATION
# ============================================================================
phase_verify() {
    header "VERIFICATION"

    local all_ok=true

    # GoPhish service
    echo -n "  GoPhish service:     "
    if systemctl is-active --quiet gophish 2>/dev/null; then
        echo -e "${GREEN}RUNNING${NC}"
    else
        echo -e "${RED}NOT RUNNING${NC}"
        all_ok=false
    fi

    # cloudflared service
    echo -n "  cloudflared service: "
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        echo -e "${GREEN}RUNNING${NC}"
    else
        echo -e "${RED}NOT RUNNING${NC}"
        all_ok=false
    fi

    # Admin API
    echo -n "  GoPhish admin API:   "
    local admin_code
    admin_code=$(curl -sk -o /dev/null -w "%{http_code}" "https://127.0.0.1:3333" 2>/dev/null || echo "000")
    if [ "$admin_code" != "000" ]; then
        echo -e "${GREEN}OK (HTTP $admin_code)${NC}"
    else
        echo -e "${RED}UNREACHABLE${NC}"
        all_ok=false
    fi

    # Phish server
    echo -n "  GoPhish phish server:"
    local phish_code
    phish_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:80" 2>/dev/null || echo "000")
    if [ "$phish_code" != "000" ]; then
        echo -e " ${GREEN}OK (HTTP $phish_code)${NC}"
    else
        echo -e " ${RED}UNREACHABLE${NC}"
        all_ok=false
    fi

    # SMTP
    echo -n "  SMTP server:         "
    if nc -zv -w 5 mail.expertimportersllc.com 465 2>&1 | grep -qi "succeeded\|connected\|open"; then
        echo -e "${GREEN}REACHABLE${NC}"
    else
        echo -e "${YELLOW}UNREACHABLE (check outbound firewall)${NC}"
    fi

    # Public URL
    echo -n "  Public URL:          "
    local pub_code
    pub_code=$(curl -s -o /dev/null -w "%{http_code}" "http://$TUNNEL_HOSTNAME" 2>/dev/null || echo "000")
    if [ "$pub_code" != "000" ]; then
        echo -e "${GREEN}OK (HTTP $pub_code)${NC}"
    else
        echo -e "${YELLOW}NOT YET (DNS may still be propagating)${NC}"
    fi

    echo ""
    if [ "$all_ok" = true ]; then
        echo -e "${GREEN}${BOLD}All core services running!${NC}"
    else
        echo -e "${RED}${BOLD}Some checks failed — review above.${NC}"
    fi
}

# ============================================================================
# FIREWALL (optional)
# ============================================================================
setup_firewall() {
    echo ""
    echo -e "${YELLOW}Would you like to configure ufw firewall rules?${NC}"
    echo "  This will:"
    echo "    - Allow SSH (port 22)"
    echo "    - Allow HTTP (port 80)"
    echo "    - Restrict RDP (3389) to office + home IPs"
    echo "    - Restrict GoPhish admin (3333) to office + home IPs"
    echo ""
    read -rp "Set up firewall? (y/N): " fw_choice
    if [[ ! "$fw_choice" =~ ^[Yy] ]]; then
        warn "Skipping firewall setup"
        return
    fi

    ufw allow OpenSSH
    ufw allow 80/tcp
    ufw allow from 174.105.36.233 to any port 3389 proto tcp
    ufw allow from 70.61.175.62 to any port 3389 proto tcp
    ufw allow from 174.105.36.233 to any port 3333 proto tcp
    ufw allow from 70.61.175.62 to any port 3333 proto tcp
    ufw --force enable
    ok "Firewall configured"
    ufw status verbose
}

# ============================================================================
# MAIN
# ============================================================================
# Must run as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root (sudo).${NC}"
    echo "  Usage: sudo bash $0"
    exit 1
fi

# Parse arguments
MODE=""
API_KEY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install)  MODE="install"; shift ;;
        --restore)  MODE="restore"; shift ;;
        --tunnel)   MODE="tunnel"; shift ;;
        --api-key)  API_KEY="$2"; shift 2 ;;
        --verify)   MODE="verify"; shift ;;
        --help|-h)
            echo "Usage: sudo bash $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --install          Phase 1: Install GoPhish + cloudflared"
            echo "  --restore          Phase 2: Restore campaign data (prompts for API key)"
            echo "  --tunnel           Phase 3: Set up Cloudflare named tunnel"
            echo "  --verify           Run verification checks only"
            echo "  --api-key KEY      GoPhish API key (used with --restore)"
            echo "  --help             Show this help"
            echo ""
            echo "No options: runs all phases with interactive pauses."
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

case "$MODE" in
    install)
        phase_install
        ;;
    restore)
        phase_restore
        ;;
    tunnel)
        phase_tunnel
        ;;
    verify)
        phase_verify
        ;;
    *)
        # Run everything
        phase_install

        pause_for_user "Complete these steps:
  1. Open Firefox → https://localhost:3333
  2. Accept the self-signed certificate warning
  3. Login with the admin credentials shown above
  4. Change your password
  5. Go to Settings → copy the API key
  6. Come back here and enter the API key"

        phase_restore

        pause_for_user "Enter the SMTP password in GoPhish UI:
  1. GoPhish UI → Sending Profiles
  2. Edit 'support@expertimportersllc.com'
  3. Enter the SMTP password
  4. Save"

        phase_tunnel

        setup_firewall

        phase_verify

        header "SETUP COMPLETE"
        echo -e "${GREEN}${BOLD}GoPhish is ready for campaigns!${NC}"
        echo ""
        echo "  Admin UI:    https://localhost:3333"
        echo "  Public URL:  http://$TUNNEL_HOSTNAME"
        echo ""
        echo "  To send a test campaign:"
        echo "    1. GoPhish UI → Campaigns → New Campaign"
        echo "    2. Template: Password Expiration Notice"
        echo "    3. Landing Page: Microsoft 365 Login"
        echo "    4. URL: http://$TUNNEL_HOSTNAME"
        echo "    5. Sending Profile: support@expertimportersllc.com"
        echo "    6. Group: IT Dept Test Group"
        echo "    7. Launch!"
        echo ""
        ;;
esac
