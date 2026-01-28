# PROJECT_SCOPE.md - gophish-installer

## Overview
One-stop PowerShell script to deploy GoPhish phishing simulation platform on Windows machines for IT department security awareness testing.

## Current Work
**Active Task:** None
**Status:** All tasks complete
**Started:** -
**Notes:** Full implementation complete

---

## Completed

### 1.1 Admin Elevation Check
- [x] Detect if running as administrator
- [x] Auto-elevate or prompt user

### 1.2 Chocolatey Detection/Install
- [x] Check if choco command available
- [x] Install Chocolatey if missing
- [x] Verify installation success

### 1.3 WSL2 Detection/Install
- [x] Check WSL version
- [x] Enable WSL feature if needed
- [x] Install WSL2 kernel update
- [x] Set WSL2 as default

### 1.4 Docker Desktop Detection/Install
- [x] Check if Docker daemon running
- [x] Install Docker Desktop via Chocolatey if missing
- [x] Wait for Docker service to start
- [x] Verify docker commands work

### 2.1 Pull GoPhish Container
- [x] Pull gophish/gophish Docker image
- [x] Show download progress
- [x] Handle timeout/retry

### 2.2 Create Docker Compose Config
- [x] Generate docker-compose.yml for GoPhish
- [x] Configure default volumes for persistence
- [x] Map ports 3333 and 80
- [x] Set appropriate resource limits

### 2.3 Start GoPhish Container
- [x] Run docker-compose up -d
- [x] Wait for services to initialize
- [x] Check container health status

### 3.1 Retrieve Admin Credentials
- [x] Extract initial admin password from container logs
- [x] Display credentials to user
- [x] Remind user to change password

### 3.2 Display Access Information
- [x] Show admin UI URL
- [x] Show phishing server URL
- [x] Provide first-campaign quick start guide

### 3.3 Create Status Check Function
- [x] -CheckOnly parameter support
- [x] Show container status
- [x] Show ports and volume info

### 3.4 Create Uninstall Function
- [x] -Uninstall parameter support
- [x] Stop and remove containers
- [x] Optionally remove volumes with confirmation
- [x] Clean up compose file

### 4.1 Error Handling
- [x] Try/catch blocks for all operations
- [x] Clear error messages
- [x] Exit codes on failure

### 4.2 Logging
- [x] Timestamped log output
- [x] Optional -LogPath parameter
- [x] Verbose mode support

### 4.3 README Documentation
- [x] Installation instructions
- [x] Usage examples
- [x] First campaign walkthrough
- [x] Compliance notes

---

## Technical Notes

- **Image:** gophish/gophish (official GoPhish image)
- **Ports:** 3333 (admin UI - HTTPS), 80 (phishing server - HTTP)
- **Default admin:** admin / (random password in logs)
- **Database:** SQLite stored in Docker volume
- **Disk space:** ~500MB for container + campaign data
