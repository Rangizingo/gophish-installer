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

## Email Admin GUI

**`email-admin-gui.ps1`** - Comprehensive WinForms GUI for managing phishing campaigns and M365 email delivery.

### Launch

```powershell
# From cmd.exe (required - not PowerShell ISE):
powershell -STA -ExecutionPolicy Bypass -File .\email-admin-gui.ps1
```

### GUI Sections & Buttons

#### Exchange Online Connection
| Button | Description |
|--------|-------------|
| Connect Exchange | OAuth browser auth to Exchange Online (required for email management buttons) |
| Disconnect | Close Exchange Online session |
| Clear Output | Clear terminal output panel |

#### Quarantine Management
| Button | Description |
|--------|-------------|
| Check Quarantine | List all quarantined emails from sender (last 7 days) with recipient, type, time, policy |
| Release ALL | Release all quarantined phishing sim emails to all recipients |
| Release Kevin+Matt | Release only kmarchese@ and mfrank@ quarantined emails |

#### Diagnostics
| Button | Description |
|--------|-------------|
| Message Trace (4hr) | Trace emails from sender in last 4 hours - shows delivery status per recipient |
| Message Trace (24hr) | Same but last 24 hours |
| Check Safe Senders | Compare TrustedSendersAndDomains across all 3 target mailboxes - identifies why some users get emails without quarantine |
| Add Safe Sender (All) | Add blancoitservices.net to TrustedSendersAndDomains for all 3 users |

#### Policies & Rules
| Button | Description |
|--------|-------------|
| Transport Rules | Show enabled transport rules matching sender domain or phish-related names |
| Allow List | Show Tenant Allow/Block List entries (senders) |
| Anti-Spam Policy | Show HighConfidencePhishAction, PhishSpamAction, AllowedDomains, AllowedSenders |
| Anti-Phish Policy | Show phishing threshold, spoof intelligence, mailbox intelligence settings |
| Compare Users | Compare spam/phish rule assignments across pblanco, kmarchese, mfrank |
| Safe Links | Show Safe Links policies with URL rewrite and click tracking settings |

#### Allow List & Overrides
| Button | Description |
|--------|-------------|
| Add to Allow List | Add sender address to Tenant Allow List (no expiration) |
| Allow Domain | Add sender domain to Tenant Allow List |
| Setup Phish Sim Override | Create Advanced Delivery PhishSimOverridePolicy - bypasses ALL filtering including High Confidence Phish |
| Check Override Status | Show current PhishSimOverridePolicy and rule configuration |
| Connection Filter | Show IP Allow/Block lists in connection filter policy |

#### GoPhish Campaign Management
| Button | Description |
|--------|-------------|
| Campaign Status | Show last 5 campaigns with sent/clicked/submitted counts |
| Latest Results | Show per-recipient results (email, status, IP) for most recent campaign |
| New Campaign (All) | Launch campaign to all 3 targets (Peter, Kevin, Matt) using current tunnel URL |
| Test (Peter Only) | Launch test campaign to pblanco@equippers.com only |
| View Templates | List all email templates, landing pages, and sending profiles in GoPhish |
| SMTP Settings | Show sending profile details (from address, host, envelope sender) |

#### Tunnel & DNS
| Button | Description |
|--------|-------------|
| Start Tunnel | Launch cloudflared tunnel to localhost:80, auto-capture public URL |
| Check Tunnel | Verify cloudflared, Docker Desktop, and GoPhish container are running |
| Check DNS (SPF/DMARC) | Query SPF, DMARC, and MX records for sender domain |
| Set Tunnel URL | Manually enter/update the Cloudflare tunnel URL for campaigns |
| Change Sender | Update GoPhish sending profile from address via input dialog |

### GUI Config (hardcoded at top of script)
- **Sender:** itsupport@blancoitservices.net
- **GoPhish API:** https://localhost:3333/api
- **Targets:** pblanco@equippers.com, kmarchese@equippers.com, mfrank@equippers.com
- Dark theme with red (#c41230) section headers, green terminal output

## Campaign Tooling Scripts

```
email-admin-gui.ps1        # All-in-one GUI for campaign & email management
setup-gophish.ps1          # Initial GoPhish API automation (templates, groups, SMTP)
launch-campaign.ps1        # CLI campaign launcher with Cloudflare tunnel URL
send-peter-only.ps1        # Single-target campaign launcher (Peter only)
send-gmail-test.ps1        # Gmail test campaign launcher
check-campaign.ps1         # Campaign results checker
update-template.ps1        # GoPhish template management via API
clear-envelope.ps1         # Clear envelope sender on SMTP profile
start-tunnel.ps1           # Start Cloudflare tunnel and capture URL
full-diagnose.ps1          # M365 8-point delivery diagnostic (run after Connect-ExchangeOnline)
diagnose-email-delivery.ps1 # Combined Google + M365 delivery trace with DNS checks
check-email-delivery.ps1   # OAuth device flow email checker via Graph API
run-diagnose.ps1           # Wrapper to connect Exchange and run diagnostics
gui-test.ps1               # Minimal WinForms test (debugging)
templates/                 # Email & landing page HTML templates
```

## GoPhish Access

- **Admin UI:** https://localhost:3333
- **API Key:** Stored in email-admin-gui.ps1 config section
- **Landing page:** http://localhost:80 (use Cloudflare Tunnel for remote access)
- **SMTP:** Google Workspace SMTP Relay (smtp-relay.gmail.com:587, IP-based auth)
- **Sender domain:** blancoitservices.net
- **Sender address:** itsupport@blancoitservices.net
- **M365 Note:** High Confidence Phish content gets quarantined - use "Release" buttons in GUI or Setup Phish Sim Override

## Email Delivery Notes

- M365 assigns SCL 8 (High Confidence Phish) to phishing template content regardless of transport rules
- Transport rules with SCL -1 do NOT override High Confidence Phish action
- Tenant Allow/Block List alone does not override HPHISH quarantine
- **Working solutions:** Manual quarantine release via GUI, or Advanced Delivery PhishSimOverridePolicy
- Per-user Safe Senders (TrustedSendersAndDomains) can bypass quarantine for individual mailboxes
- Envelope sender with display name causes delivery failures - leave envelope_sender empty in GoPhish
- Google SMTP Relay rejects sending from domains you don't own (no equippers.com spoofing)

## External Dependencies

- Docker Desktop
- WSL2 (Windows Subsystem for Linux)
- Chocolatey package manager
- GoPhish Docker image (gophish/gophish)
- Cloudflare Tunnel (cloudflared) for remote access
- Exchange Online PowerShell module (ExchangeOnlineManagement)
- Google Workspace (SMTP relay, IP-based auth)
- Microsoft.VisualBasic assembly (for GUI input dialogs)
