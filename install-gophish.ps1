<#
.SYNOPSIS
    GoPhish Installer - Automated deployment for Windows
.DESCRIPTION
    One-stop PowerShell script to deploy GoPhish phishing simulation platform
.PARAMETER CheckOnly
    Show current status without making changes
.PARAMETER Uninstall
    Remove GoPhish and optionally clean up data
.PARAMETER LogPath
    Path to log file for verbose output
#>

[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [switch]$Uninstall,
    [string]$LogPath
)

#region Admin Elevation Check
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "This script requires administrator privileges." -ForegroundColor Yellow
    Write-Host "Attempting to restart as administrator..." -ForegroundColor Cyan

    $scriptPath = $MyInvocation.MyCommand.Path
    $arguments = @()
    if ($CheckOnly) { $arguments += "-CheckOnly" }
    if ($Uninstall) { $arguments += "-Uninstall" }
    if ($LogPath) { $arguments += "-LogPath `"$LogPath`"" }

    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`" $($arguments -join ' ')" -Verb RunAs
        exit 0
    }
    catch {
        Write-Host "ERROR: Failed to elevate. Please run this script as Administrator." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Running with administrator privileges." -ForegroundColor Green
#endregion

#region Logging
$script:LogFile = $LogPath
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $logEntry
    }

    if ($VerbosePreference -eq "Continue") {
        Write-Verbose $logEntry
    }
}

if ($LogPath) {
    $logDir = Split-Path $LogPath -Parent
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    Write-Log "GoPhish Installer started" -Level INFO
    Write-Log "Parameters: CheckOnly=$CheckOnly, Uninstall=$Uninstall" -Level INFO
}
#endregion

#region Chocolatey Detection/Install
function Install-ChocolateyIfNeeded {
    Write-Host "`nChecking for Chocolatey..." -ForegroundColor Cyan

    $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
    if ($chocoCmd) {
        Write-Host "Chocolatey is already installed." -ForegroundColor Green
        return $true
    }

    Write-Host "Chocolatey not found. Installing..." -ForegroundColor Yellow

    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

        # Refresh environment to pick up choco
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
        if ($chocoCmd) {
            Write-Host "Chocolatey installed successfully." -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "ERROR: Chocolatey installation completed but command not found." -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "ERROR: Failed to install Chocolatey: $_" -ForegroundColor Red
        return $false
    }
}
#endregion

#region WSL2 Detection/Install
function Install-WSL2IfNeeded {
    Write-Host "`nChecking for WSL2..." -ForegroundColor Cyan

    # Check if WSL is installed
    $wslOutput = $null
    try {
        $wslOutput = wsl --version 2>&1
    }
    catch {
        $wslOutput = $null
    }

    if ($wslOutput -and $wslOutput -match "WSL version") {
        Write-Host "WSL2 is already installed." -ForegroundColor Green
        return $true
    }

    Write-Host "WSL2 not found. Installing..." -ForegroundColor Yellow

    try {
        # Enable WSL feature
        Write-Host "Enabling WSL feature..." -ForegroundColor Cyan
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null

        # Enable Virtual Machine Platform
        Write-Host "Enabling Virtual Machine Platform..." -ForegroundColor Cyan
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null

        # Install WSL via wsl --install (modern method)
        Write-Host "Installing WSL2..." -ForegroundColor Cyan
        wsl --install --no-distribution 2>&1 | Out-Null

        # Set WSL2 as default
        wsl --set-default-version 2 2>&1 | Out-Null

        Write-Host "WSL2 installation complete." -ForegroundColor Green
        Write-Host "NOTE: A system restart may be required before Docker Desktop can use WSL2." -ForegroundColor Yellow
        return $true
    }
    catch {
        Write-Host "ERROR: Failed to install WSL2: $_" -ForegroundColor Red
        return $false
    }
}
#endregion

#region Docker Desktop Detection/Install
function Install-DockerIfNeeded {
    Write-Host "`nChecking for Docker Desktop..." -ForegroundColor Cyan

    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    if ($dockerCmd) {
        # Docker command exists, check if daemon is running
        try {
            $dockerInfo = docker info 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Docker Desktop is installed and running." -ForegroundColor Green
                return $true
            }
        }
        catch { }
    }

    Write-Host "Docker Desktop not found or not running. Installing..." -ForegroundColor Yellow

    try {
        # Install via Chocolatey
        Write-Host "Installing Docker Desktop via Chocolatey..." -ForegroundColor Cyan
        choco install docker-desktop -y

        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        Write-Host "Docker Desktop installed." -ForegroundColor Green
        Write-Host "Starting Docker Desktop..." -ForegroundColor Cyan

        # Start Docker Desktop
        $dockerPath = "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $dockerPath) {
            Start-Process -FilePath $dockerPath
        }

        # Wait for Docker daemon to be ready (up to 120 seconds)
        Write-Host "Waiting for Docker daemon to start (this may take a minute)..." -ForegroundColor Cyan
        $maxWait = 120
        $waited = 0
        while ($waited -lt $maxWait) {
            Start-Sleep -Seconds 5
            $waited += 5
            try {
                docker info 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Docker Desktop is now running." -ForegroundColor Green
                    return $true
                }
            }
            catch { }
            Write-Host "  Still waiting... ($waited seconds)" -ForegroundColor Gray
        }

        Write-Host "WARNING: Docker daemon did not start within $maxWait seconds." -ForegroundColor Yellow
        Write-Host "Please start Docker Desktop manually and re-run this script." -ForegroundColor Yellow
        return $false
    }
    catch {
        Write-Host "ERROR: Failed to install Docker Desktop: $_" -ForegroundColor Red
        return $false
    }
}
#endregion

#region GoPhish Deployment
$script:GoPhishDir = Join-Path $env:USERPROFILE "gophish"
$script:ComposeFile = Join-Path $script:GoPhishDir "docker-compose.yml"

function Install-GoPhishImage {
    Write-Host "`nPulling GoPhish Docker image..." -ForegroundColor Cyan

    try {
        docker pull gophish/gophish
        if ($LASTEXITCODE -eq 0) {
            Write-Host "GoPhish image pulled successfully." -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "ERROR: Failed to pull GoPhish image." -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "ERROR: Failed to pull GoPhish image: $_" -ForegroundColor Red
        return $false
    }
}

function New-GoPhishComposeFile {
    Write-Host "`nCreating Docker Compose configuration..." -ForegroundColor Cyan

    # Create directory if needed
    if (-not (Test-Path $script:GoPhishDir)) {
        New-Item -ItemType Directory -Path $script:GoPhishDir -Force | Out-Null
    }

    $composeContent = @"
version: '3.8'
services:
  gophish:
    image: gophish/gophish
    container_name: gophish
    restart: unless-stopped
    ports:
      - "3333:3333"   # Admin UI (HTTPS)
      - "80:80"       # Phishing server (HTTP)
    volumes:
      - gophish-data:/opt/gophish/data
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 128M

volumes:
  gophish-data:
    name: gophish-data
"@

    try {
        Set-Content -Path $script:ComposeFile -Value $composeContent -Force
        Write-Host "Docker Compose file created at: $($script:ComposeFile)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "ERROR: Failed to create Docker Compose file: $_" -ForegroundColor Red
        return $false
    }
}

function Start-GoPhishContainer {
    Write-Host "`nStarting GoPhish container..." -ForegroundColor Cyan

    try {
        Push-Location $script:GoPhishDir
        docker compose up -d
        $exitCode = $LASTEXITCODE
        Pop-Location

        if ($exitCode -ne 0) {
            Write-Host "ERROR: Failed to start GoPhish container." -ForegroundColor Red
            return $false
        }

        # Wait for container to be healthy
        Write-Host "Waiting for GoPhish to initialize..." -ForegroundColor Cyan
        Start-Sleep -Seconds 10

        $containerStatus = docker ps --filter "name=gophish" --format "{{.Status}}"
        if ($containerStatus -match "Up") {
            Write-Host "GoPhish container is running." -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "ERROR: GoPhish container is not running." -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "ERROR: Failed to start GoPhish: $_" -ForegroundColor Red
        return $false
    }
}

function Get-GoPhishCredentials {
    Write-Host "`nRetrieving GoPhish admin credentials..." -ForegroundColor Cyan

    try {
        # Wait a moment for logs to be available
        Start-Sleep -Seconds 3

        $logs = docker logs gophish 2>&1
        $passwordLine = $logs | Select-String -Pattern "Please login with the username admin and the password"

        if ($passwordLine) {
            $password = ($passwordLine -split "password ")[1]
            return @{
                Username = "admin"
                Password = $password.Trim()
            }
        }
        else {
            Write-Host "WARNING: Could not extract password from logs." -ForegroundColor Yellow
            Write-Host "Run 'docker logs gophish' to find the initial password." -ForegroundColor Yellow
            return $null
        }
    }
    catch {
        Write-Host "WARNING: Could not retrieve credentials: $_" -ForegroundColor Yellow
        return $null
    }
}

function Show-GoPhishAccessInfo {
    param([hashtable]$Credentials)

    Write-Host "`n" -NoNewline
    Write-Host "===============================================" -ForegroundColor Green
    Write-Host "        GoPhish Installation Complete!         " -ForegroundColor Green
    Write-Host "===============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Admin Interface:" -ForegroundColor Cyan
    Write-Host "  URL:      https://localhost:3333" -ForegroundColor White
    if ($Credentials) {
        Write-Host "  Username: $($Credentials.Username)" -ForegroundColor White
        Write-Host "  Password: $($Credentials.Password)" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Phishing Server:" -ForegroundColor Cyan
    Write-Host "  URL:      http://localhost:80" -ForegroundColor White
    Write-Host ""
    Write-Host "IMPORTANT:" -ForegroundColor Yellow
    Write-Host "  - Change the admin password immediately after first login" -ForegroundColor Yellow
    Write-Host "  - Only use for authorized security awareness testing" -ForegroundColor Yellow
    Write-Host "  - Campaign data contains sensitive employee info" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Quick Commands:" -ForegroundColor Cyan
    Write-Host "  Status:    .\install-gophish.ps1 -CheckOnly" -ForegroundColor Gray
    Write-Host "  Uninstall: .\install-gophish.ps1 -Uninstall" -ForegroundColor Gray
    Write-Host "===============================================" -ForegroundColor Green
}
#endregion

#region Status Check
function Show-GoPhishStatus {
    Write-Host "`nGoPhish Status" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor Cyan

    # Check Docker
    $dockerRunning = $false
    try {
        docker info 2>&1 | Out-Null
        $dockerRunning = ($LASTEXITCODE -eq 0)
    }
    catch { }

    if (-not $dockerRunning) {
        Write-Host "Docker: NOT RUNNING" -ForegroundColor Red
        return
    }
    Write-Host "Docker: Running" -ForegroundColor Green

    # Check container
    $containerStatus = docker ps --filter "name=gophish" --format "{{.Status}}" 2>&1
    if ($containerStatus -match "Up") {
        Write-Host "Container: $containerStatus" -ForegroundColor Green
    }
    elseif ($containerStatus) {
        Write-Host "Container: $containerStatus" -ForegroundColor Yellow
    }
    else {
        Write-Host "Container: Not found" -ForegroundColor Red
        return
    }

    # Check volume size
    $volumeInfo = docker volume inspect gophish-data 2>&1
    if ($LASTEXITCODE -eq 0) {
        $volumePath = ($volumeInfo | ConvertFrom-Json).Mountpoint
        Write-Host "Data Volume: gophish-data" -ForegroundColor Green
    }

    # Check ports
    $ports = docker port gophish 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Ports:" -ForegroundColor Cyan
        $ports | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    }

    Write-Host ""
    Write-Host "Admin UI:     https://localhost:3333" -ForegroundColor Cyan
    Write-Host "Phish Server: http://localhost:80" -ForegroundColor Cyan
}
#endregion

#region Uninstall
function Uninstall-GoPhish {
    Write-Host "`nUninstalling GoPhish..." -ForegroundColor Cyan

    # Check if container exists
    $containerExists = docker ps -a --filter "name=gophish" --format "{{.Names}}" 2>&1
    if ($containerExists -eq "gophish") {
        Write-Host "Stopping and removing GoPhish container..." -ForegroundColor Yellow
        docker stop gophish 2>&1 | Out-Null
        docker rm gophish 2>&1 | Out-Null
        Write-Host "Container removed." -ForegroundColor Green
    }
    else {
        Write-Host "No GoPhish container found." -ForegroundColor Gray
    }

    # Ask about volumes
    $volumeExists = docker volume ls --filter "name=gophish-data" --format "{{.Name}}" 2>&1
    if ($volumeExists -eq "gophish-data") {
        Write-Host ""
        Write-Host "WARNING: The data volume contains campaign data and database." -ForegroundColor Yellow
        $response = Read-Host "Remove data volume? This will DELETE ALL DATA (y/N)"
        if ($response -eq "y" -or $response -eq "Y") {
            docker volume rm gophish-data 2>&1 | Out-Null
            Write-Host "Data volume removed." -ForegroundColor Green
        }
        else {
            Write-Host "Data volume preserved." -ForegroundColor Cyan
        }
    }

    # Remove compose file
    if (Test-Path $script:ComposeFile) {
        Remove-Item $script:ComposeFile -Force
        Write-Host "Compose file removed." -ForegroundColor Green
    }

    # Remove directory if empty
    if ((Test-Path $script:GoPhishDir) -and ((Get-ChildItem $script:GoPhishDir | Measure-Object).Count -eq 0)) {
        Remove-Item $script:GoPhishDir -Force
    }

    Write-Host "`nGoPhish uninstalled." -ForegroundColor Green
}
#endregion

#region Main Execution
if ($CheckOnly) {
    Show-GoPhishStatus
    exit 0
}

if ($Uninstall) {
    Uninstall-GoPhish
    exit 0
}

# Main installation flow
Write-Host ""
Write-Host "GoPhish Installer" -ForegroundColor Cyan
Write-Host "=================" -ForegroundColor Cyan

# Step 1: Chocolatey
if (-not (Install-ChocolateyIfNeeded)) {
    Write-Host "`nERROR: Chocolatey installation failed. Cannot continue." -ForegroundColor Red
    exit 1
}

# Step 2: WSL2
if (-not (Install-WSL2IfNeeded)) {
    Write-Host "`nERROR: WSL2 installation failed. Cannot continue." -ForegroundColor Red
    exit 1
}

# Step 3: Docker Desktop
if (-not (Install-DockerIfNeeded)) {
    Write-Host "`nERROR: Docker Desktop installation failed. Cannot continue." -ForegroundColor Red
    exit 1
}

# Step 4: Pull GoPhish image
if (-not (Install-GoPhishImage)) {
    Write-Host "`nERROR: Failed to pull GoPhish image. Cannot continue." -ForegroundColor Red
    exit 1
}

# Step 5: Create compose file
if (-not (New-GoPhishComposeFile)) {
    Write-Host "`nERROR: Failed to create Docker Compose file. Cannot continue." -ForegroundColor Red
    exit 1
}

# Step 6: Start container
if (-not (Start-GoPhishContainer)) {
    Write-Host "`nERROR: Failed to start GoPhish container. Cannot continue." -ForegroundColor Red
    exit 1
}

# Step 7: Get credentials and show info
$credentials = Get-GoPhishCredentials
Show-GoPhishAccessInfo -Credentials $credentials
#endregion
