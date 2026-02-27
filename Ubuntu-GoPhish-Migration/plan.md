# GoPhish Deployment — Ubuntu VM

## Current Status (2026-02-27)

**Completed:**
- [x] Created Ubuntu 24.04 Desktop VM on ESXi host
- [x] Ubuntu installed, local account created
- [x] Static IP configured (set DHCP-assigned IP as manual)
- [x] `sudo apt update && sudo apt upgrade -y`
- [x] TeamViewer installed for remote access (xrdp had black screen issues)
- [x] Phase 1: GoPhish installed and running as systemd service
- [x] Phase 2: Campaign data restored (templates, landing page, groups, SMTP profile)
- [x] GoPhish admin UI accessible at https://localhost:3333
- [x] Phish server running on port 80
- [x] Cloudflared installed
- [x] Sleep/suspend disabled on VM

**Not Started:**
- [ ] Phase 3: Firewall (ufw)
- [ ] Phase 4: Cloudflare Named Tunnel (portal.expertimportersllc.com)
- [ ] Phase 5: SSL/TLS
- [ ] Phase 6: Verification
- [ ] Enter SMTP password in GoPhish UI (Sending Profiles)
- [ ] Send test campaign to pblanco@equippers.com
- [ ] Domain join (optional)
- [ ] Sophos agent install (add `/opt/gophish/` exclusion first)
- [ ] Patch manager agent install

**Troubleshooting Notes:**
- GoPhish exit code 1 on first start: missing `migrations_prefix` in config.json — fixed by adding `"migrations_prefix": "db/db_"`
- xrdp black screen: Wayland/X11 issues on Ubuntu 24.04 — use TeamViewer instead
- Line ending errors running .sh scripts cloned on Windows: run `sed -i 's/\r$//' script.sh` or use `.gitattributes` with `*.sh text eol=lf`

## Scripts

This folder contains two scripts for deploying GoPhish on any fresh Ubuntu VM:

### `setup-gophish.sh` — Full Setup (Fresh VM)
Installs GoPhish from scratch on a clean Ubuntu VM. Handles everything:
- Installs prerequisites (curl, unzip, jq, python3, git, cloudflared)
- Downloads latest GoPhish Linux binary from GitHub
- Writes config.json with correct `migrations_prefix`
- Creates systemd service, extracts temp admin password
- Restores email template, landing page, target group, and SMTP profile via API
- Sets up Cloudflare named tunnel with interactive browser auth
- Optionally configures ufw firewall

```bash
sudo bash setup-gophish.sh              # Run all phases (interactive)
sudo bash setup-gophish.sh --install    # Phase 1 only: install GoPhish + cloudflared
sudo bash setup-gophish.sh --restore --api-key KEY  # Phase 2 only: restore data
sudo bash setup-gophish.sh --tunnel     # Phase 3 only: Cloudflare tunnel
sudo bash setup-gophish.sh --verify     # Check all services
```

### `restore-gophish.sh` — Restore from Backup (Existing Data)
Restores GoPhish from a backup tarball onto a VM that already has the binary installed.
Use this when migrating to a new VM or recovering from a failure — it preserves all
campaigns, credentials, templates, and admin settings from the database backup.

```bash
# First, create a backup on the current server:
sudo tar czf /tmp/gophish-backup-$(date +%Y%m%d).tar.gz \
    /opt/gophish/gophish.db \
    /opt/gophish/config.json \
    /opt/gophish/gophish_admin.crt \
    /opt/gophish/gophish_admin.key \
    /etc/systemd/system/gophish.service

# On the new VM (after running setup-gophish.sh --install):
sudo bash restore-gophish.sh /path/to/gophish-backup-YYYYMMDD.tar.gz
```

What it does:
- Stops GoPhish and cloudflared services
- Extracts backup tarball (database, config, certs, service files)
- Disables sleep/suspend on the VM
- Restarts services and verifies they're running
- All campaigns, templates, landing pages, groups, SMTP profiles, and admin
  credentials are restored from the database

---

## Context

GoPhish currently runs in Docker on a local Windows 10 PC. This setup requires Cloudflare quick tunnels for external access, but port 7844 is blocked at the office, making tunnels unreliable. Deploying to an Ubuntu VM with a Cloudflare **named tunnel** gives a permanent, stable URL with no inbound port forwarding needed.

Previously attempted Windows Server 2019 at the datacenter — hit multiple issues (GoPhish binary "no valid version" bug, CGO/GCC build requirements). Ubuntu is the native GoPhish platform and avoids all of that.

## Target Server

| Spec | Value |
|------|-------|
| OS | Ubuntu 22.04+ LTS **Desktop** |
| Desktop | GNOME (default Ubuntu Desktop) |
| Remote access | RDP via xrdp (manage everything on-box) |
| Port 7844 outbound | Must be open (Cloudflare tunnel) |
| Port 80 | Not in use (GoPhish phish server) |
| Port 3333 | Not in use (GoPhish admin) |
| Port 3389 | RDP access (restrict to your IPs) |

## Approach

This server is the **single workstation** for all GoPhish work. You RDP in and do everything locally:
- Browse GoPhish admin UI at `https://localhost:3333`
- Edit HTML templates in a text editor (VS Code, gedit, etc.)
- Run `python3 update-gophish.py` to push template changes
- View campaign metrics in the browser
- Run restore/diagnostic scripts in the terminal

No SSH tunnels, no remote API calls from your Windows PC.

## Architecture

```
Internet → portal.expertimportersllc.com (CNAME → Cloudflare Tunnel)
         → Cloudflare Edge (TLS on tunnel transport)
         → Cloudflare Tunnel (outbound from server, port 7844)
         → localhost:80 (GoPhish phish server)

You → RDP (port 3389) → Ubuntu Desktop
   → Firefox/Chrome → https://localhost:3333 (GoPhish admin)
   → Terminal → scripts, template editing, diagnostics
```

---

## Phase 1: Install GoPhish

### 1.1 Download GoPhish

```bash
# Create directory
sudo mkdir -p /opt/gophish
sudo chown $USER:$USER /opt/gophish
mkdir -p /opt/gophish/{logs,backup}

# Download latest Linux 64-bit release
cd /opt/gophish
LATEST=$(curl -s https://api.github.com/repos/gophish/gophish/releases/latest \
  | grep -oP '"browser_download_url":\s*"\K[^"]*linux-64bit.zip')
curl -L -o gophish.zip "$LATEST"
unzip gophish.zip
rm gophish.zip
chmod +x gophish
```

### 1.2 Configure GoPhish (`/opt/gophish/config.json`)

```json
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
    "contact_address": ""
}
```

Key decisions:
- Admin binds to `0.0.0.0:3333` — accessible remotely, but ufw-restricted to your IPs only (Phase 3)
- Phish server binds to `0.0.0.0:80` — cloudflared forwards tunnel traffic here
- Port 80 requires root or `setcap` — we use setcap (see 1.3)

### 1.3 Allow GoPhish to Bind Port 80 Without Root

```bash
# Grant the binary the ability to bind privileged ports
sudo setcap 'cap_net_bind_service=+ep' /opt/gophish/gophish
```

### 1.4 Create systemd Service

```bash
sudo tee /etc/systemd/system/gophish.service > /dev/null << 'EOF'
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
EOF

sudo systemctl daemon-reload
sudo systemctl enable gophish
sudo systemctl start gophish
```

> **Note:** Running as root for simplicity (port 80 binding). For hardened production, create a dedicated `gophish` user with `setcap` and `AmbientCapabilities=CAP_NET_BIND_SERVICE`.

### 1.5 Install Desktop + RDP (if Ubuntu Server)

Skip this if you installed Ubuntu Desktop — it already has GNOME.

```bash
# Install minimal desktop + RDP
sudo apt install -y ubuntu-desktop-minimal xrdp
sudo systemctl enable xrdp
sudo systemctl start xrdp

# Add your user to the ssl-cert group (xrdp needs this)
sudo adduser $USER ssl-cert

# Reboot to start the desktop environment
sudo reboot
```

After reboot, RDP in from your Windows PC:
- Open **Remote Desktop Connection** (`mstsc.exe`)
- Connect to `<server-ip>`
- Login with your Ubuntu username/password

### 1.6 Install Dev Tools

```bash
# Text editor, Python (for update-gophish.py), jq (for restore script)
sudo apt install -y python3 python3-pip jq curl unzip
sudo snap install code --classic  # VS Code (optional, gedit works fine too)
```

### 1.7 First Login to GoPhish

```bash
# Get temporary admin password from log
grep "Please login with" /opt/gophish/logs/gophish.log
```

- Open Firefox on the Ubuntu desktop → `https://localhost:3333`
- Accept self-signed cert warning
- Login with `admin` / `<temp password from log>`
- Change password immediately
- Copy the new API key from Settings

---

## Phase 2: Restore GoPhish Data

### 2.1 Run Backup on Local PC First

On your local PC (where GoPhish Docker is running), run the backup script:
```powershell
cd C:\Users\pblanco\Documents\AI\gophish-installer
powershell -ExecutionPolicy Bypass -File .\_backup_gophish.ps1
```

This saves `templates.json`, `pages.json`, `smtp.json`, `groups.json`, `campaigns.json` to the `backup\` folder.

### 2.2 Clone Repo on Server

Since you're working directly on the server, just clone the repo:
```bash
sudo apt install -y git
cd ~
git clone https://github.com/pblanco-equippers/gophish-installer.git

# Copy backup files and latest templates to GoPhish backup dir
cp ~/gophish-installer/backup/*.json /opt/gophish/backup/
cp ~/gophish-installer/templates/email-template.html /opt/gophish/backup/
cp ~/gophish-installer/templates/landing-page.html /opt/gophish/backup/

# Also copy the Python updater for future template changes
cp ~/gophish-installer/update-gophish.py /opt/gophish/
```

> **Alternative:** If the repo is private, use SCP from your Windows PC or copy via USB/shared folder.

### 2.3 Run Restore Script

Create `/opt/gophish/restore.sh` on the server. Replace `<YOUR_NEW_API_KEY>` with the API key from step 1.5:

```bash
#!/bin/bash
set -e

API_KEY="<YOUR_NEW_API_KEY>"
BASE="https://127.0.0.1:3333/api"
BACKUP="/opt/gophish/backup"

# Helper: POST JSON to GoPhish API
post() {
    local endpoint="$1"
    local data="$2"
    local label="$3"
    local result
    result=$(curl -sk -X POST "$BASE/$endpoint?api_key=$API_KEY" \
        -H "Content-Type: application/json" \
        -d "$data" -w "\n%{http_code}")
    local code=$(echo "$result" | tail -1)
    if [ "$code" -ge 200 ] && [ "$code" -lt 300 ]; then
        echo "  OK: $label"
    else
        echo "  FAILED ($code): $label"
        echo "$result" | head -1
    fi
}

echo "=== Restoring Email Template ==="
# Use the LATEST template from repo (not the backup - backup is outdated)
EMAIL_HTML=$(cat "$BACKUP/email-template.html")
# Build JSON with jq
TEMPLATE_JSON=$(jq -n \
    --arg name "Password Expiration Notice" \
    --arg subject "Action Required: Your password expires in 24 hours" \
    --arg html "$EMAIL_HTML" \
    '{name: $name, subject: $subject, text: "", html: $html, envelope_sender: "", attachments: []}')
post "templates/" "$TEMPLATE_JSON" "Password Expiration Notice"

echo ""
echo "=== Restoring Landing Page ==="
# Use the LATEST landing page (has AJAX submit + confirmation screen)
LANDING_HTML=$(cat "$BACKUP/landing-page.html")
PAGE_JSON=$(jq -n \
    --arg name "M365 Login" \
    --arg html "$LANDING_HTML" \
    '{name: $name, html: $html, capture_credentials: true, capture_passwords: true, redirect_url: "https://restaurantequippers.sharepoint.com"}')
post "pages/" "$PAGE_JSON" "M365 Login"

echo ""
echo "=== Restoring Target Group ==="
GROUP_JSON=$(cat << 'GROUPEOF'
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
post "groups/" "$GROUP_JSON" "IT Dept Test Group"

echo ""
echo "=== Restoring SMTP Profile ==="
SMTP_JSON=$(cat << 'SMTPEOF'
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
post "smtp/" "$SMTP_JSON" "support@expertimportersllc.com [PASSWORD BLANK - update in UI]"

echo ""
echo "=== Restore Complete ==="
echo "ACTION REQUIRED: Go to GoPhish UI → Sending Profiles → update SMTP password"
```

Run it:
```bash
sudo apt install -y jq  # needed for JSON building
chmod +x /opt/gophish/restore.sh
bash /opt/gophish/restore.sh
```

### 2.4 Configure SMTP Sending Profile

After restore, open GoPhish UI → Sending Profiles → edit the profile:
- **Name:** `support@expertimportersllc.com`
- **Host:** `mail.expertimportersllc.com:465`
- **From:** `support@expertimportersllc.com`
- **Username:** `support@expertimportersllc.com`
- **Password:** (enter manually — not stored in backup)
- **Ignore cert errors:** checked
- **Envelope sender:** leave empty (display name in envelope causes delivery failures)

### 2.5 Verify SMTP Connectivity

```bash
# Test outbound to SMTP server
nc -zv mail.expertimportersllc.com 465
# OR
curl -v --connect-timeout 5 smtps://mail.expertimportersllc.com:465 2>&1 | head -5
```

Expected: Connection succeeded

---

## Phase 3: Firewall (ufw)

### 3.1 Enable ufw and Allow SSH

```bash
sudo ufw allow OpenSSH
sudo ufw enable
```

### 3.2 Allow GoPhish Phish Server (Port 80)

```bash
# cloudflared connects locally, but allow port 80 in case of direct access
sudo ufw allow 80/tcp
```

### 3.3 Restrict RDP to Your IPs Only

```bash
# Allow RDP from your office and home IPs only
sudo ufw allow from 174.105.36.233 to any port 3389 proto tcp
sudo ufw allow from 70.61.175.62 to any port 3389 proto tcp
```

### 3.4 Restrict Admin UI to Your IPs Only (Optional)

Since you'll mostly use the admin UI locally via RDP (`https://localhost:3333`), you may not need remote access to 3333 at all. But if you want it:

```bash
# Allow 3333 from your office and home IPs only
sudo ufw allow from 174.105.36.233 to any port 3333 proto tcp
sudo ufw allow from 70.61.175.62 to any port 3333 proto tcp
```

### 3.5 Allow Cloudflare Tunnel Outbound

Port 7844 outbound is allowed by default (ufw only blocks inbound). No rule needed.

### 3.6 Verify

```bash
sudo ufw status verbose
```

---

## Phase 4: Cloudflare Named Tunnel

### 4.1 Install cloudflared

```bash
# Add Cloudflare's apt repo
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/cloudflared.list

sudo apt update
sudo apt install -y cloudflared
cloudflared --version
```

### 4.2 Authenticate with Cloudflare

**Important:** `cloudflared tunnel login` requires selecting a Cloudflare zone (domain). Since `expertimportersllc.com` is NOT on Cloudflare (DNS is at Epik), you have two choices:

1. **Add `expertimportersllc.com` to your Cloudflare account** (free plan — doesn't require changing nameservers for tunnel auth, just needs to exist as a zone). Then select it during login.
2. **Use any existing Cloudflare zone** you have (e.g. `blancoitsolutions.com`) — the tunnel itself works with any domain via CNAME. The auth cert just needs to be tied to *a* Cloudflare account.

```bash
cloudflared tunnel login
# Opens Firefox on the desktop → log into Cloudflare → select any zone you own
# Saves cert to: ~/.cloudflared/cert.pem
```

### 4.3 Create Named Tunnel

```bash
cloudflared tunnel create gophish-portal
# Output: Created tunnel gophish-portal with id <TUNNEL_UUID>
# Also creates: ~/.cloudflared/<TUNNEL_UUID>.json
```

Save the `<TUNNEL_UUID>` — you need it for the next steps.

### 4.4 Create Tunnel Config

```bash
TUNNEL_UUID="<paste-tunnel-uuid-here>"

cat > ~/.cloudflared/config.yml << EOF
tunnel: $TUNNEL_UUID
credentials-file: /root/.cloudflared/$TUNNEL_UUID.json

ingress:
  - hostname: portal.expertimportersllc.com
    service: http://localhost:80
  - service: http_status:404
EOF
```

The ingress routes **only** `portal.expertimportersllc.com` to GoPhish port 80. Admin port 3333 is deliberately excluded — never exposed through the tunnel.

> **Note:** If running cloudflared as non-root, adjust `credentials-file` path to match the user's home directory.

### 4.5 Create DNS Route (Epik DNS Console)

Since `expertimportersllc.com` DNS is managed at Epik (not Cloudflare), you add the CNAME manually:

1. Log into **Epik** → Domain Manager → `expertimportersllc.com` → DNS Zone Editor
2. Go to the **CNAME** tab
3. Add a new record:
   - **Host:** `portal`
   - **Points to:** `<TUNNEL_UUID>.cfargotunnel.com`
   - **TTL:** 300 (or default)
4. Save

This routes `portal.expertimportersllc.com` through Cloudflare's tunnel infrastructure without moving the domain to Cloudflare.

**Verify DNS propagation:**
```bash
dig portal.expertimportersllc.com CNAME +short
# Should return: <TUNNEL_UUID>.cfargotunnel.com.
```

### 4.6 Install as systemd Service

```bash
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
sudo systemctl status cloudflared
```

### 4.7 Set Service Dependency

```bash
# Edit the cloudflared service to start after gophish
sudo systemctl edit cloudflared --force
```

Add:
```ini
[Unit]
After=gophish.service
Requires=gophish.service
```

Then:
```bash
sudo systemctl daemon-reload
```

---

## Phase 5: SSL/TLS

Since the domain is on Epik (not Cloudflare), Cloudflare's edge TLS termination doesn't apply automatically. Two options:

**Option A — HTTP only (recommended for phishing sim):**
- Campaign URL: `http://portal.expertimportersllc.com`
- No SSL cert needed on the server
- GoPhish phish server already listens on HTTP port 80
- Cloudflare Tunnel encrypts the transport between Cloudflare's edge and your server regardless
- The CNAME to `cfargotunnel.com` means traffic flows through Cloudflare's network with TLS on the tunnel layer

**Option B — HTTPS with Let's Encrypt (more realistic phishing URL):**
- Install Caddy as a reverse proxy:
  ```bash
  sudo apt install -y caddy
  # Edit /etc/caddy/Caddyfile:
  # portal.expertimportersllc.com {
  #     reverse_proxy localhost:8080
  # }
  ```
- Change GoPhish phish_server to port 8080 (Caddy takes 80/443)
- Caddy auto-provisions Let's Encrypt certs
- Adds complexity but gives `https://` in the URL

**Recommendation: Start with Option A.** You can always add HTTPS later if needed. The actual tunnel transport is encrypted either way.

---

## Phase 6: Verification Checklist

Run from the server:
```bash
# 1. Both services running
sudo systemctl status gophish cloudflared

# 2. GoPhish admin reachable locally
curl -sk https://127.0.0.1:3333/api/campaigns/?api_key=<YOUR_KEY> | head -20

# 3. GoPhish phish server reachable locally
curl -s http://127.0.0.1:80 | head -5

# 4. SMTP server reachable
nc -zv mail.expertimportersllc.com 465

# 5. Tunnel healthy
cloudflared tunnel info gophish-portal

# 6. Firewall status
sudo ufw status
```

Run from your local PC (or any external machine):
```powershell
# 7. Public URL works
Invoke-WebRequest -Uri "http://portal.expertimportersllc.com" -UseBasicParsing

# 8. Admin port NOT reachable externally (should timeout/fail)
Test-NetConnection -ComputerName <server-public-ip> -Port 3333
```

Final test:
- Launch a test campaign with URL `http://portal.expertimportersllc.com`
- Send to `pblanco@equippers.com`
- Click link → landing page loads
- Submit creds → confirmation screen → redirect to SharePoint
- Check campaign results in admin UI

---

## Phase 7: Set Up Working Environment on Server

Since everything runs on this box, set up your tools:

### 7.1 Clone the Repo (if not done in Phase 2)

```bash
cd ~
git clone https://github.com/pblanco-equippers/gophish-installer.git
```

### 7.2 Update Scripts to Use localhost

All scripts point at `localhost` since you're running them on the same box:

| Script | Config |
|--------|--------|
| `update-gophish.py` | `BASE = "https://localhost:3333/api"`, update API key |
| Campaign URL | Always use `http://portal.expertimportersllc.com` |
| `CLAUDE.md` | Update GoPhish access section, remove Docker/tunnel references |

### 7.3 Template Editing Workflow

1. Edit HTML in VS Code or gedit: `/opt/gophish/backup/email-template.html`
2. Push to GoPhish: `cd ~/gophish-installer && python3 update-gophish.py`
3. Or paste directly in GoPhish UI → Email Templates / Landing Pages

### 7.4 Daily Workflow

- RDP into the server
- Open Firefox → `https://localhost:3333` → manage campaigns, view metrics
- Open terminal → run scripts, edit templates
- Everything stays on-box — no remote API calls needed

---

## What This Eliminates

- Docker Desktop dependency
- Cloudflare quick tunnels (random URLs, dying processes)
- Port 7844 office firewall issues
- LAN IP workarounds
- Manual tunnel restarts
- Windows Server GoPhish binary bugs
- CGO/GCC build complexity

## What's Permanent

- `portal.expertimportersllc.com` — stable URL, never changes
- GoPhish runs as a systemd service — auto-start, auto-restart
- Cloudflare Tunnel as a systemd service — auto-reconnect, survives reboots
- RDP for full desktop access — edit templates, view metrics, run scripts, all on-box
- No inbound ports needed (except SSH + RDP for management)

## Key Paths on Server

```
/opt/gophish/
  gophish                  # Binary
  config.json              # Admin on 0.0.0.0:3333, phish on 0.0.0.0:80
  gophish.db               # SQLite database (all campaign data)
  gophish_admin.crt/key    # Auto-generated self-signed cert
  restore.sh               # Data restore script
  update-gophish.py        # Template pusher script
  logs/                    # systemd-captured stdout/stderr
  backup/                  # Restore files (templates, pages, smtp, groups)

~/gophish-installer/       # Cloned repo (scripts, templates, docs)

~/.cloudflared/
  cert.pem                 # Cloudflare account auth
  config.yml               # Tunnel routing config
  <tunnel-uuid>.json       # Tunnel credentials

/etc/systemd/system/
  gophish.service          # GoPhish systemd unit
```
