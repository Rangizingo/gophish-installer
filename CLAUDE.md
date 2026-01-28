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

## External Dependencies

- Docker Desktop
- WSL2 (Windows Subsystem for Linux)
- Chocolatey package manager
- GoPhish Docker image (gophish/gophish)
