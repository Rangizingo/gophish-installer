# PROJECT_SCOPE.md - gophish-installer

## Overview
One-stop PowerShell script to deploy GoPhish phishing simulation platform on Windows machines for IT department security awareness testing.

## Current Work
**Active Task:** None
**Status:** Ready to start
**Started:** -
**Notes:** Project discovery complete, ready for implementation

---

## Phase 1: Core Prerequisites

### 1.1 Admin Elevation Check
- [ ] Detect if running as administrator
- [ ] Auto-elevate or prompt user
- **Location:** `install-gophish.ps1:1-20`
- **Verify:** Run without admin, confirm elevation prompt
- **Acceptance:** Script re-launches elevated or exits with clear message

### 1.2 Chocolatey Detection/Install
- [ ] Check if choco command available
- [ ] Install Chocolatey if missing
- [ ] Verify installation success
- **Location:** `install-gophish.ps1:25-60`
- **Verify:** Run on machine without Chocolatey
- **Acceptance:** Chocolatey installed and functional

### 1.3 WSL2 Detection/Install
- [ ] Check WSL version (`wsl --version`)
- [ ] Enable WSL feature if needed
- [ ] Install WSL2 kernel update
- [ ] Set WSL2 as default
- **Location:** `install-gophish.ps1:65-120`
- **Blocked by:** 1.2
- **Verify:** `wsl --version` shows version 2
- **Acceptance:** WSL2 enabled and default

### 1.4 Docker Desktop Detection/Install
- [ ] Check if Docker daemon running
- [ ] Install Docker Desktop via Chocolatey if missing
- [ ] Wait for Docker service to start
- [ ] Verify docker commands work
- **Location:** `install-gophish.ps1:125-180`
- **Blocked by:** 1.2, 1.3
- **Verify:** `docker ps` succeeds
- **Acceptance:** Docker Desktop running and responsive

---

## Phase 2: GoPhish Deployment

### 2.1 Pull GoPhish Container
- [ ] Pull gophish/gophish Docker image
- [ ] Show download progress
- [ ] Handle timeout/retry
- **Location:** `install-gophish.ps1:185-220`
- **Blocked by:** 1.4
- **Verify:** `docker images` shows gophish image
- **Acceptance:** Image pulled successfully

### 2.2 Create Docker Compose Config
- [ ] Generate docker-compose.yml for GoPhish
- [ ] Configure default volumes for persistence (database, attachments)
- [ ] Map ports 3333 (admin) and 80 (phishing server)
- [ ] Set appropriate resource limits
- **Location:** `install-gophish.ps1:225-280`
- **Blocked by:** 2.1
- **Verify:** docker-compose.yml exists and valid
- **Acceptance:** Compose file generated with correct structure

### 2.3 Start GoPhish Container
- [ ] Run docker-compose up -d
- [ ] Wait for services to initialize
- [ ] Check container health status
- **Location:** `install-gophish.ps1:285-340`
- **Blocked by:** 2.2
- **Verify:** `docker ps` shows running container
- **Acceptance:** Container running and healthy

---

## Phase 3: Configuration & Output

### 3.1 Retrieve Admin Credentials
- [ ] Extract initial admin password from container logs
- [ ] Display credentials to user
- [ ] Remind user to change password on first login
- **Location:** `install-gophish.ps1:345-380`
- **Blocked by:** 2.3
- **Verify:** Can login with displayed credentials
- **Acceptance:** Admin credentials shown and functional

### 3.2 Display Access Information
- [ ] Show admin UI URL (https://localhost:3333)
- [ ] Show phishing server URL (http://localhost:80)
- [ ] Provide first-campaign quick start guide
- **Location:** `install-gophish.ps1:385-420`
- **Blocked by:** 3.1
- **Verify:** URLs accessible in browser
- **Acceptance:** User can access GoPhish admin interface

### 3.3 Create Status Check Function
- [ ] `-CheckOnly` parameter support
- [ ] Show container status
- [ ] Show database size
- [ ] Show active campaigns count
- **Location:** `install-gophish.ps1:425-480`
- **Verify:** `.\install-gophish.ps1 -CheckOnly` shows status
- **Acceptance:** Status output accurate and readable

### 3.4 Create Uninstall Function
- [ ] `-Uninstall` parameter support
- [ ] Stop and remove containers
- [ ] Optionally remove volumes (with confirmation - data loss!)
- [ ] Clean up compose file
- **Location:** `install-gophish.ps1:485-540`
- **Verify:** `.\install-gophish.ps1 -Uninstall` cleans up
- **Acceptance:** All GoPhish components removed

---

## Phase 4: Polish & Documentation

### 4.1 Error Handling
- [ ] Try/catch blocks for all operations
- [ ] Clear error messages
- [ ] Rollback on failure where possible
- **Location:** Throughout script
- **Blocked by:** Phase 3 complete
- **Verify:** Deliberately break steps, confirm graceful handling
- **Acceptance:** No cryptic errors, actionable messages

### 4.2 Logging
- [ ] Timestamped log output
- [ ] Optional log file (`-LogPath` parameter)
- [ ] Verbose mode for troubleshooting
- **Location:** Throughout script
- **Blocked by:** 4.1
- **Verify:** Run with `-LogPath`, check log file
- **Acceptance:** Complete operation log available

### 4.3 README Documentation
- [ ] Installation instructions
- [ ] Usage examples
- [ ] First campaign walkthrough
- [ ] Compliance notes (authorized use only)
- **Location:** `README.md`
- **Blocked by:** Phase 3 complete
- **Verify:** Follow README on fresh machine
- **Acceptance:** New user can install using only README

---

## Completed
<!-- Move completed task blocks here -->

---

## Technical Notes

- **Image:** gophish/gophish (official GoPhish image)
- **Ports:** 3333 (admin UI - HTTPS), 80 (phishing server - HTTP)
- **Default admin:** admin / (random password in logs)
- **Database:** SQLite stored in Docker volume
- **Disk space:** ~500MB for container + campaign data
