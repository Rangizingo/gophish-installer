# GoPhish on Oracle Cloud - Setup Plan

## Goal
Deploy GoPhish on Oracle Cloud Always Free tier with a permanent public URL (`portal.blancoitsolutions.com`), eliminating the need for tunnels and office firewall workarounds.

## Prerequisites
- [ ] Oracle Cloud account (sign up at https://www.oracle.com/cloud/free/)
- [ ] SSH key pair for VM access
- [ ] Cloudflare access for `blancoitsolutions.com` DNS (already authenticated via wrangler)

## Phase 1: Oracle Cloud VM Setup

### 1.1 Create ARM VM Instance
- Image: Oracle Linux 8 or Ubuntu 22.04 (ARM/aarch64)
- Shape: VM.Standard.A1.Flex (1 OCPU, 6 GB RAM is plenty)
- Boot volume: 50 GB (default)
- VCN: Create new with public subnet

### 1.2 Configure Security List (Firewall Rules)
Open inbound ports:
| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH access |
| 80 | TCP | GoPhish landing page |
| 443 | TCP | GoPhish landing page (HTTPS) |
| 3333 | TCP | GoPhish admin UI |

Source CIDR: `0.0.0.0/0` for 80/443, restrict 22 and 3333 to your IPs:
- Home: `174.105.36.233/32`
- Office: `70.61.175.62/32`

### 1.3 Assign Reserved Public IP
- Create a reserved public IP in Oracle Cloud console
- Attach to the VM instance (survives reboots/stops)

## Phase 2: GoPhish Installation

### 2.1 SSH into VM and install GoPhish
```bash
ssh -i ~/.ssh/oci_key opc@<PUBLIC_IP>

# Download GoPhish (ARM64 build)
wget https://github.com/gophish/gophish/releases/latest/download/gophish-v0.12.1-linux-64bit.zip
unzip gophish-*.zip -d /opt/gophish
chmod +x /opt/gophish/gophish
```

### 2.2 Configure GoPhish (`config.json`)
```json
{
    "admin_server": {
        "listen_url": "0.0.0.0:3333",
        "use_tls": true,
        "cert_path": "/opt/gophish/ssl/admin.crt",
        "key_path": "/opt/gophish/ssl/admin.key"
    },
    "phish_server": {
        "listen_url": "0.0.0.0:80",
        "use_tls": false
    },
    "db_name": "sqlite3",
    "db_path": "/opt/gophish/gophish.db",
    "contact_address": ""
}
```

### 2.3 Create systemd service
```ini
[Unit]
Description=GoPhish Phishing Framework
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/gophish
ExecStart=/opt/gophish/gophish
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 2.4 Start and enable
```bash
sudo systemctl enable gophish
sudo systemctl start gophish
```

## Phase 3: DNS & SSL

### 3.1 Point DNS to Oracle Cloud IP
Update `portal.blancoitsolutions.com` in Cloudflare:
- Delete the existing CNAME (tunnel route)
- Add A record: `portal` → `<ORACLE_PUBLIC_IP>` (proxied or DNS-only)

If using Cloudflare proxy (orange cloud):
- Free SSL termination at Cloudflare edge
- GoPhish phish_server stays on port 80, Cloudflare handles HTTPS

If DNS-only (grey cloud):
- Use Let's Encrypt/certbot for SSL on the VM directly

### 3.2 Admin UI access
Access via `https://<ORACLE_PUBLIC_IP>:3333` (self-signed cert)
Or set up a second subdomain: `admin.blancoitsolutions.com:3333`

## Phase 4: Migration

### 4.1 Push templates to new instance
```bash
# From local machine, run update-gophish.py pointed at the new server
# Update BASE url in script: https://portal.blancoitsolutions.com:3333/api
python update-gophish.py
```

### 4.2 Update SMTP relay
- Add Oracle Cloud VM's public IP to Google Workspace SMTP Relay allowed senders
- Google Admin > Apps > Gmail > Routing > SMTP Relay > Add IP

### 4.3 Update API key
- First login to GoPhish admin UI, change default password
- Copy new API key
- Update in `email-admin-gui.ps1` and other scripts

### 4.4 Update campaign scripts
- Change `$gophishApi` from `https://localhost:3333/api` to `https://portal.blancoitsolutions.com:3333/api`
- No more tunnel management needed — URL is permanent

## Phase 5: Verification

- [ ] GoPhish admin UI accessible at `https://<IP>:3333`
- [ ] Landing page loads at `https://portal.blancoitsolutions.com`
- [ ] Send test email to `pblanco@equippers.com`
- [ ] Click link → landing page loads (no tunnel, no interstitial)
- [ ] Credential capture works
- [ ] Campaign results visible in admin UI

## What This Eliminates
- Cloudflare tunnel / ngrok dependency
- Port 7844 firewall issues
- Random URLs that change every session
- ngrok interstitial warning page
- Docker Desktop requirement on local machine
- "Tunnel died" problems

## Cost
$0/month (Oracle Cloud Always Free tier)

## Risks
- Oracle may reclaim idle Always Free instances (rare, mitigated by keeping the VM running)
- ARM architecture — must use `linux-arm64` GoPhish build
- Popular regions may have limited ARM availability during signup
