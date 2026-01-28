# GoPhish Installer

One-stop PowerShell script to deploy GoPhish phishing simulation platform on Windows.

## Prerequisites

- Windows 10/11
- Internet connection
- Administrator privileges

The script will automatically install:
- Chocolatey (package manager)
- WSL2 (Windows Subsystem for Linux)
- Docker Desktop

## Installation

```powershell
# Download and run (requires admin)
.\install-gophish.ps1
```

The script will:
1. Check/install all prerequisites
2. Pull the GoPhish Docker image
3. Create and start the container
4. Display admin credentials

## Usage

### Install GoPhish
```powershell
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

## Access

After installation:

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
```powershell
docker run --rm -v gophish-data:/data -v ${PWD}:/backup alpine tar czf /backup/gophish-backup.tar.gz /data
```

## Compliance Notice

**AUTHORIZED USE ONLY**

This tool is for legitimate security awareness testing. Ensure you have:
- Written authorization from organization leadership
- Documented scope and rules of engagement
- Data handling procedures for campaign results
- Compliance with applicable regulations (PCI-DSS, SOC2, etc.)

Campaign data contains sensitive employee information. Handle with care.

## Troubleshooting

### Docker not starting
- Ensure virtualization is enabled in BIOS
- Restart after WSL2 installation
- Check Docker Desktop logs

### Port conflicts
- Port 80 or 3333 may be in use
- Edit `~/gophish/docker-compose.yml` to change ports

### Container not starting
```powershell
docker logs gophish
```

## License

GoPhish is licensed under MIT. This installer script is provided as-is for authorized use.
