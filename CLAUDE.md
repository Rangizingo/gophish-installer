# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

**gophish-installer** - One-stop PowerShell script to deploy GoPhish phishing simulation platform on Windows machines.

## Purpose

Automate complete GoPhish setup:
- Check/install prerequisites (Docker Desktop, WSL2, etc.)
- Deploy GoPhish via Docker container
- Configure for first use
- Provide ready-to-campaign environment
- Deploy and manage phishing simulation campaigns
- Email delivery diagnostics for M365/Google Workspace

## Target Environment

- **OS:** Windows 10/11 only
- **Users:** IT department (1-5 machines)
- **Compliance:** PCI-DSS, SOC2

## Architecture

```
install-gophish.ps1
├── Prerequisites check (Docker, WSL2, Chocolatey)
├── Install missing components via Chocolatey
├── Pull GoPhish Docker image
├── Configure container with default volumes
├── Start services
└── Display access credentials
```

## Commands

```powershell
# Run installer (requires admin)
.\install-gophish.ps1

# Check status
.\install-gophish.ps1 -CheckOnly

# Uninstall
.\install-gophish.ps1 -Uninstall
```

## Key Design Decisions

- **Chocolatey** for package management (not winget)
- **Default Docker volumes** for data persistence
- **Idempotent** - safe to run multiple times
- **Verbose logging** for IT troubleshooting

## Security Considerations

- Script requires admin elevation
- No hardcoded credentials
- Generated passwords stored securely
- Campaign data contains sensitive employee info - handle with care
- Only use for authorized security awareness testing

## Campaign Tooling

```
setup-gophish.ps1          # API automation
launch-campaign.ps1        # Campaign launcher
update-template.ps1        # Template management
full-diagnose.ps1          # M365 8-point delivery check
diagnose-email-delivery.ps1 # Delivery trace
check-email-delivery.ps1   # Graph API checker
templates/                 # Email & landing page HTML
```

## GoPhish Access

- **Admin UI:** https://localhost:3333
- **Landing page:** http://localhost:80 (use Cloudflare Tunnel for remote)
- **SMTP:** Google Workspace SMTP Relay (smtp-relay.gmail.com:587)
- **Sender domain:** blancoitservices.net
- **M365 Note:** High Confidence Phish content gets quarantined - requires manual release or Advanced Delivery policy

## External Dependencies

- Docker Desktop
- WSL2 (Windows Subsystem for Linux)
- Chocolatey package manager
- GoPhish Docker image (gophish/gophish)
- Cloudflare Tunnel (cloudflared) for remote access
- Exchange Online PowerShell module
- Google Workspace (SMTP relay)
