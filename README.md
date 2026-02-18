# GoPhish Installer

Cross-platform scripts to deploy GoPhish phishing simulation platform.

## Supported Platforms

| Platform | Script | Status |
|----------|--------|--------|
| Windows 10/11 | `install-gophish.ps1` | Full support (GUI tools included) |
| Linux (Ubuntu/Pop!_OS/Debian) | `install-gophish.sh` | Core installer |

---

## Linux Installation

### Prerequisites
- Ubuntu, Pop!_OS, Debian, Fedora, or Arch-based distro
- Internet connection
- sudo privileges

The script will automatically install Docker if needed.

### Install GoPhish
```bash
chmod +x install-gophish.sh
./install-gophish.sh
```

### Check Status
```bash
./install-gophish.sh --check
```

### Uninstall
```bash
./install-gophish.sh --uninstall
```

### Post-install (if Docker permission issues)
```bash
sudo usermod -aG docker $USER
# Log out and back in, then:
docker ps  # should work without sudo
```

---

## Windows Installation

### Prerequisites
- Windows 10/11
- Internet connection
- Administrator privileges

The script will automatically install:
- Chocolatey (package manager)
- WSL2 (Windows Subsystem for Linux)
- Docker Desktop

### Install GoPhish
```powershell
# Requires admin
.\install-gophish.ps1
```

### Check Status
```powershell
.\install-gophish.ps1 -CheckOnly
```

### Uninstall
```powershell
.\install-gophish.ps1 -Uninstall
```

### With Logging
```powershell
.\install-gophish.ps1 -LogPath "C:\logs\gophish-install.log" -Verbose
```

---

## Access

After installation (both platforms):

| Service | URL |
|---------|-----|
| Admin UI | https://localhost:3333 |
| Phishing Server | http://localhost:80 |

Default credentials are displayed after installation. **Change the password immediately.**

## First Campaign Quick Start

1. Login to https://localhost:3333
2. Change admin password (Account Settings)
3. Create a Sending Profile (SMTP server config)
4. Create an Email Template
5. Create a Landing Page
6. Import or create User Groups
7. Create and launch Campaign

## Data Persistence

Campaign data is stored in Docker volume `gophish-data`. This persists across container restarts.

To backup:
```bash
docker run --rm -v gophish-data:/data -v $(pwd):/backup alpine tar czf /backup/gophish-backup.tar.gz /data
```

## Platform-Specific Tools

### Windows Only
- `email-admin-gui.ps1` - WinForms GUI for M365 email management and campaign control
- Exchange Online integration scripts
- Various PowerShell diagnostic tools

### Cross-Platform
- `update-gophish.py` - Update templates via API (Python)
- `oci-retry-launch.py` - OCI cloud deployment helper (Python)
- `templates/` - HTML email and landing page templates

## Compliance Notice

**AUTHORIZED USE ONLY**

This tool is for legitimate security awareness testing. Ensure you have:
- Written authorization from organization leadership
- Documented scope and rules of engagement
- Data handling procedures for campaign results
- Compliance with applicable regulations (PCI-DSS, SOC2, etc.)

Campaign data contains sensitive employee information. Handle with care.

## Troubleshooting

### Docker not starting (Linux)
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### Docker permission denied (Linux)
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

### Docker not starting (Windows)
- Ensure virtualization is enabled in BIOS
- Restart after WSL2 installation
- Check Docker Desktop logs

### Port conflicts
- Port 80 or 3333 may be in use
- Edit `~/gophish/docker-compose.yml` to change ports

### Container not starting
```bash
docker logs gophish
```

## License

GoPhish is licensed under MIT. This installer script is provided as-is for authorized use.
