#Requires -RunAsAdministrator
<#
.SYNOPSIS
    GoPhish + cloudflared deployment for Windows Server 2019.
.DESCRIPTION
    Checks/installs prerequisites (Go, Git, NSSM, cloudflared).
    Builds GoPhish from source (avoids "no valid version" bug in release binary).
    Registers GoPhish as a Windows service.
    Restores email template, landing page, groups, and SMTP profile via API.
    Does NOT touch firewall rules.
    Idempotent - safe to run multiple times, skips what's already done.
.PARAMETER Install
    Run Phase 1 only (prerequisites + build + service).
.PARAMETER Restore
    Run Phase 2 only (restore data via API). Requires -ApiKey.
.PARAMETER ApiKey
    GoPhish API key (from Settings page after first login).
.NOTES
    Prerequisites handled automatically: Go, Git, NSSM, cloudflared
    Place email-template.html and landing-page.html next to this script.
    Copy this folder to the server and run:
      .\setup-gophish-server.ps1
#>

param(
    [switch]$Install,
    [switch]$Restore,
    [string]$ApiKey
)

$ErrorActionPreference = "Continue"
$gophishDir  = "C:\scripts\gophish"
$logsDir     = "$gophishDir\logs"
$backupDir   = "$gophishDir\backup"
$srcDir      = "$gophishDir\src"
$scriptDir   = $PSScriptRoot
$base        = "https://127.0.0.1:3333/api"

# --- Trust self-signed certs (PS 5.1 and PS 7+) ---
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSDefaultParameterValues['Invoke-RestMethod:SkipCertificateCheck'] = $true
    $PSDefaultParameterValues['Invoke-WebRequest:SkipCertificateCheck'] = $true
} else {
    Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllSetup : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; }
}
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllSetup
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# =============================================================================
# HELPERS
# =============================================================================
function Test-CommandExists($cmd) {
    $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Get-ToolVersion($cmd, $versionFlag) {
    if ($versionFlag) {
        & $cmd $versionFlag 2>&1 | Select-Object -First 1
    } else {
        & $cmd --version 2>&1 | Select-Object -First 1
    }
}

function Install-Prerequisite {
    param([string]$Name, [string]$TestCmd, [string]$Url, [string]$InstallerArgs, [string]$InstallerType, [string]$VersionFlag)

    Write-Host "  Checking $Name..." -NoNewline
    if (Test-CommandExists $TestCmd) {
        $ver = Get-ToolVersion $TestCmd $VersionFlag
        Write-Host " INSTALLED ($ver)" -ForegroundColor Green
        return
    }
    Write-Host " NOT FOUND - installing..." -ForegroundColor Yellow

    $ext = if ($InstallerType -eq "msi") { ".msi" } else { ".exe" }
    $installer = "$env:TEMP\$Name-setup$ext"
    Invoke-WebRequest -Uri $Url -OutFile $installer

    if ($InstallerType -eq "msi") {
        Start-Process msiexec -ArgumentList "/i `"$installer`" $InstallerArgs" -Wait
    } else {
        Start-Process -FilePath $installer -ArgumentList $InstallerArgs -Wait
    }
    Remove-Item $installer -Force -ErrorAction SilentlyContinue

    # Refresh PATH for this session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    if (Test-CommandExists $TestCmd) {
        $ver = Get-ToolVersion $TestCmd $VersionFlag
        Write-Host "  OK: $Name installed ($ver)" -ForegroundColor Green
    } else {
        throw "$Name installed but '$TestCmd' not found in PATH. Restart PowerShell and re-run."
    }
}

# =============================================================================
# PHASE 1: INSTALL
# =============================================================================
function Install-GoPhishServer {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " PHASE 1: Install GoPhish + cloudflared" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # --- 1.1 Create directories ---
    Write-Host "[1/8] Creating directories..." -ForegroundColor Yellow
    foreach ($d in @($gophishDir, $logsDir, $backupDir, $srcDir)) {
        if (-not (Test-Path $d)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
            Write-Host "  Created: $d" -ForegroundColor Green
        } else {
            Write-Host "  Exists:  $d" -ForegroundColor Gray
        }
    }

    # --- 1.2 Install prerequisites ---
    Write-Host "[2/8] Checking prerequisites..." -ForegroundColor Yellow

    # Git
    Install-Prerequisite -Name "Git" -TestCmd "git" `
        -Url "https://github.com/git-for-windows/git/releases/download/v2.44.0.windows.1/Git-2.44.0-64-bit.exe" `
        -InstallerArgs "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS=`"icons,ext\reg\shellhere,assoc,assoc_sh`"" `
        -InstallerType "exe"

    # Go (uses "go version" not "go --version")
    Install-Prerequisite -Name "Go" -TestCmd "go" `
        -Url "https://go.dev/dl/go1.22.5.windows-amd64.msi" `
        -InstallerArgs "/quiet /norestart" `
        -InstallerType "msi" `
        -VersionFlag "version"

    # GCC (required for go-sqlite3 CGO build) — install via Chocolatey
    Write-Host "  Checking GCC..." -NoNewline
    if (Test-CommandExists "gcc") {
        $gccVer = & gcc --version 2>&1 | Select-Object -First 1
        Write-Host " INSTALLED ($gccVer)" -ForegroundColor Green
    } else {
        Write-Host " NOT FOUND - installing via Chocolatey..." -ForegroundColor Yellow
        # Install Chocolatey if not present
        if (-not (Test-CommandExists "choco")) {
            Write-Host "  Installing Chocolatey..."
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        }
        & choco install mingw -y 2>&1 | Out-Null
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        if (Test-CommandExists "gcc") {
            $gccVer = & gcc --version 2>&1 | Select-Object -First 1
            Write-Host "  OK: GCC installed ($gccVer)" -ForegroundColor Green
        } else {
            throw "GCC installed but not found in PATH. Restart PowerShell and re-run."
        }
    }

    # --- 1.3 Build GoPhish from source ---
    Write-Host "[3/8] Building GoPhish from source..." -ForegroundColor Yellow
    if (Test-Path "$gophishDir\gophish.exe") {
        # Check if it's a working build (not the broken release binary)
        $testProc = Start-Process -FilePath "$gophishDir\gophish.exe" -WorkingDirectory $gophishDir `
            -RedirectStandardError "$env:TEMP\gophish-test.log" -PassThru -WindowStyle Hidden
        Start-Sleep -Seconds 3
        $testErr = Get-Content "$env:TEMP\gophish-test.log" -Raw -ErrorAction SilentlyContinue
        if (-not $testProc.HasExited) {
            Stop-Process $testProc -Force -ErrorAction SilentlyContinue
        }
        Remove-Item "$env:TEMP\gophish-test.log" -Force -ErrorAction SilentlyContinue

        if ($testErr -notmatch "no valid version") {
            Write-Host "  SKIP: Working gophish.exe already exists" -ForegroundColor Gray
        } else {
            Write-Host "  Existing binary has version bug, rebuilding..." -ForegroundColor Yellow
            Remove-Item "$gophishDir\gophish.exe" -Force
        }
    }

    if (-not (Test-Path "$gophishDir\gophish.exe")) {
        if (-not (Test-Path "$srcDir\.git")) {
            Write-Host "  Cloning gophish repository..."
            $cloneOutput = & git clone https://github.com/gophish/gophish.git $srcDir 2>&1
            if ($LASTEXITCODE -ne 0) { throw "Git clone failed: $cloneOutput" }
        } else {
            Write-Host "  Source already cloned, pulling latest..."
            Push-Location $srcDir
            $pullOutput = & git pull 2>&1
            Pop-Location
        }

        Write-Host "  Building (this may take a few minutes)..."
        Push-Location $srcDir
        $env:CGO_ENABLED = "1"
        $buildVersion = "0.12.1"
        $ldflags = "-X github.com/gophish/gophish/config.Version=$buildVersion"
        $buildOutput = & go build -ldflags $ldflags -o "$gophishDir\gophish.exe" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Go build failed: $buildOutput" }
        Pop-Location

        # Copy required assets from source to gophish dir
        foreach ($asset in @("static", "templates", "db")) {
            $assetSrc = Join-Path $srcDir $asset
            $assetDst = Join-Path $gophishDir $asset
            if ((Test-Path $assetSrc) -and -not (Test-Path $assetDst)) {
                Copy-Item $assetSrc $assetDst -Recurse -Force
            }
        }

        Write-Host "  OK: gophish.exe built (v$buildVersion)" -ForegroundColor Green
    }

    # --- 1.4 Write config.json ---
    Write-Host "[4/8] Writing config.json..." -ForegroundColor Yellow
    $configJson = @'
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
'@
    [System.IO.File]::WriteAllText("$gophishDir\config.json", $configJson, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  OK: Admin on 0.0.0.0:3333, Phish on 0.0.0.0:80" -ForegroundColor Green

    # --- 1.5 Download NSSM ---
    Write-Host "[5/8] Installing NSSM..." -ForegroundColor Yellow
    if (Test-Path "$gophishDir\nssm.exe") {
        Write-Host "  SKIP: nssm.exe already exists" -ForegroundColor Gray
    } else {
        Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" -OutFile "$gophishDir\nssm.zip"
        Expand-Archive -Path "$gophishDir\nssm.zip" -DestinationPath $gophishDir -Force
        Copy-Item "$gophishDir\nssm-2.24\win64\nssm.exe" "$gophishDir\nssm.exe" -Force
        Remove-Item "$gophishDir\nssm.zip"
        Remove-Item "$gophishDir\nssm-2.24" -Recurse -Force
        Write-Host "  OK: nssm.exe" -ForegroundColor Green
    }

    # --- 1.6 Register GoPhish as Windows service ---
    Write-Host "[6/8] Registering GoPhish service..." -ForegroundColor Yellow
    $existingSvc = Get-Service -Name gophish -ErrorAction SilentlyContinue
    if ($existingSvc) {
        Write-Host "  Removing existing gophish service..."
        Stop-Service gophish -Force -ErrorAction SilentlyContinue
        & "$gophishDir\nssm.exe" remove gophish confirm 2>&1 | Out-Null
        Start-Sleep -Seconds 2
    }
    & "$gophishDir\nssm.exe" install gophish "$gophishDir\gophish.exe"
    & "$gophishDir\nssm.exe" set gophish AppDirectory "$gophishDir"
    & "$gophishDir\nssm.exe" set gophish AppStdout "$logsDir\gophish-stdout.log"
    & "$gophishDir\nssm.exe" set gophish AppStderr "$logsDir\gophish-stderr.log"
    & "$gophishDir\nssm.exe" set gophish AppRotateFiles 1
    & "$gophishDir\nssm.exe" set gophish AppRotateBytes 10485760
    & "$gophishDir\nssm.exe" set gophish Start SERVICE_AUTO_START

    # Clear old logs before starting
    Remove-Item "$logsDir\gophish-stdout.log" -Force -ErrorAction SilentlyContinue
    Remove-Item "$logsDir\gophish-stderr.log" -Force -ErrorAction SilentlyContinue

    Start-Service gophish
    Write-Host "  OK: gophish service started" -ForegroundColor Green

    # --- 1.7 Get temp admin password ---
    Write-Host "[7/8] Waiting for GoPhish to initialize..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    $attempts = 0
    $tempPw = $null
    while ($attempts -lt 15 -and -not $tempPw) {
        $attempts++
        if (Test-Path "$logsDir\gophish-stdout.log") {
            $match = Select-String -Path "$logsDir\gophish-stdout.log" -Pattern "Please login with the username admin and the password (\S+)"
            if ($match) {
                $tempPw = $match.Matches[0].Groups[1].Value
            }
        }
        if (-not $tempPw) { Start-Sleep -Seconds 2 }
    }
    if ($tempPw) {
        Write-Host "`n  ==============================================" -ForegroundColor Magenta
        Write-Host "  TEMP ADMIN PASSWORD: $tempPw" -ForegroundColor Magenta
        Write-Host "  ==============================================" -ForegroundColor Magenta
        Write-Host "  Login: https://127.0.0.1:3333" -ForegroundColor Magenta
        Write-Host "  User:  admin" -ForegroundColor Magenta
    } else {
        Write-Host "  Could not extract temp password. Check logs:" -ForegroundColor Red
        Write-Host "  Get-Content $logsDir\gophish-stdout.log" -ForegroundColor Red
        Write-Host "  Get-Content $logsDir\gophish-stderr.log" -ForegroundColor Red
    }

    # --- 1.8 Install cloudflared ---
    Write-Host "`n[8/8] Installing cloudflared..." -ForegroundColor Yellow
    $cfExe = "C:\Program Files (x86)\cloudflared\cloudflared.exe"
    if (Test-Path $cfExe) {
        $ver = & $cfExe --version 2>&1 | Select-Object -First 1
        Write-Host "  SKIP: Already installed ($ver)" -ForegroundColor Gray
    } else {
        $cfUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.msi"
        Invoke-WebRequest -Uri $cfUrl -OutFile "$env:TEMP\cloudflared-setup.msi"
        Start-Process msiexec -ArgumentList "/i `"$env:TEMP\cloudflared-setup.msi`" /quiet /norestart" -Wait
        Remove-Item "$env:TEMP\cloudflared-setup.msi" -Force -ErrorAction SilentlyContinue
        if (Test-Path $cfExe) {
            $ver = & $cfExe --version 2>&1 | Select-Object -First 1
            Write-Host "  OK: $ver" -ForegroundColor Green
        } else {
            Write-Host "  WARNING: cloudflared not found after install" -ForegroundColor Red
        }
    }

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " PHASE 1 COMPLETE" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "`nServices:" -ForegroundColor White
    Get-Service gophish | Format-Table Name, Status -AutoSize
    Write-Host "Next steps:" -ForegroundColor White
    Write-Host "  1. Open browser to https://127.0.0.1:3333"
    Write-Host "  2. Accept self-signed cert warning"
    Write-Host "  3. Login: admin / $tempPw"
    Write-Host "  4. Change password immediately"
    Write-Host "  5. Go to Settings → copy API key"
    Write-Host "  6. Come back here and enter the API key`n"
}

# =============================================================================
# PHASE 2: RESTORE DATA
# =============================================================================
function Restore-GoPhishData {
    param([string]$Key)

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " PHASE 2: Restore GoPhish Data" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # --- Check for template files ---
    $emailTemplatePath = Join-Path $scriptDir "email-template.html"
    $landingPagePath   = Join-Path $scriptDir "landing-page.html"

    if (-not (Test-Path $emailTemplatePath)) {
        throw "Missing: $emailTemplatePath`nCopy email-template.html next to this script."
    }
    if (-not (Test-Path $landingPagePath)) {
        throw "Missing: $landingPagePath`nCopy landing-page.html next to this script."
    }

    # --- Verify API connectivity ---
    Write-Host "[1/4] Verifying API connectivity..." -ForegroundColor Yellow
    try {
        Invoke-RestMethod -Uri "$base/templates/?api_key=$Key" -Method Get | Out-Null
        Write-Host "  OK: API reachable" -ForegroundColor Green
    } catch {
        throw "Cannot reach GoPhish API at $base. Is the service running?`n$($_.Exception.Message)"
    }

    # --- Restore email template ---
    Write-Host "[2/4] Restoring email template..." -ForegroundColor Yellow
    $emailHtml = Get-Content $emailTemplatePath -Raw -Encoding UTF8
    $emailBody = @{
        name            = "Password Expiration Notice"
        subject         = "Action Required: Your password expires in 3 business days"
        text            = "Hi {{.FirstName}},`n`nYour Microsoft 365 password expires in 3 business days. Reset it now: {{.URL}}`n`nThanks,`nIT Support Team"
        html            = $emailHtml
        envelope_sender = ""
        attachments     = @()
    } | ConvertTo-Json -Depth 5
    try {
        Invoke-RestMethod -Uri "$base/templates/?api_key=$Key" -Method Post -Body $emailBody -ContentType "application/json; charset=utf-8" | Out-Null
        Write-Host "  OK: Password Expiration Notice" -ForegroundColor Green
    } catch {
        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }

    # --- Restore landing page ---
    Write-Host "[3/4] Restoring landing page..." -ForegroundColor Yellow
    $landingHtml = Get-Content $landingPagePath -Raw -Encoding UTF8
    $pageBody = @{
        name                = "Microsoft 365 Login"
        html                = $landingHtml
        capture_credentials = $true
        capture_passwords   = $true
        redirect_url        = "https://restaurantequippers.sharepoint.com/"
    } | ConvertTo-Json -Depth 5
    try {
        Invoke-RestMethod -Uri "$base/pages/?api_key=$Key" -Method Post -Body $pageBody -ContentType "application/json; charset=utf-8" | Out-Null
        Write-Host "  OK: Microsoft 365 Login (with confirmation screen)" -ForegroundColor Green
    } catch {
        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }

    # --- Restore target group + SMTP ---
    Write-Host "[4/4] Restoring target group and SMTP profile..." -ForegroundColor Yellow
    $groupBody = @{
        name    = "IT Dept Test Group"
        targets = @(
            @{ email = "pblanco@equippers.com";   first_name = "Peter"; last_name = "Blanco";   position = "IT Manager" }
            @{ email = "kmarchese@equippers.com";  first_name = "Kevin"; last_name = "Marchese"; position = "CIO" }
            @{ email = "mfrank@equippers.com";     first_name = "Matt";  last_name = "Frank";    position = "Staff" }
        )
    } | ConvertTo-Json -Depth 5
    try {
        Invoke-RestMethod -Uri "$base/groups/?api_key=$Key" -Method Post -Body $groupBody -ContentType "application/json; charset=utf-8" | Out-Null
        Write-Host "  OK: IT Dept Test Group (3 targets)" -ForegroundColor Green
    } catch {
        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }

    $smtpBody = @{
        name               = "Expert Importers (Epik)"
        interface_type     = "SMTP"
        host               = "mail.expertimportersllc.com:465"
        from_address       = "IT Support <support@expertimportersllc.com>"
        username           = "support@expertimportersllc.com"
        password           = ""
        ignore_cert_errors = $true
        headers            = @()
    } | ConvertTo-Json -Depth 5
    try {
        Invoke-RestMethod -Uri "$base/smtp/?api_key=$Key" -Method Post -Body $smtpBody -ContentType "application/json; charset=utf-8" | Out-Null
        Write-Host "  OK: SMTP profile created [PASSWORD BLANK - update in UI]" -ForegroundColor Green
    } catch {
        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " PHASE 2 COMPLETE" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "`nRemaining manual steps:" -ForegroundColor White
    Write-Host "  1. GoPhish UI -> Sending Profiles -> edit -> enter SMTP password"
    Write-Host "  2. Send a test email to verify SMTP connectivity"
    Write-Host "  3. Configure firewall rules (see plan.md Phase 3)"
    Write-Host "  4. Set up Cloudflare tunnel (see plan.md Phase 4)`n"
}

# =============================================================================
# MAIN
# =============================================================================
if ($Install -and -not $Restore) {
    Install-GoPhishServer
}
elseif ($Restore -and -not $Install) {
    if (-not $ApiKey) { $ApiKey = Read-Host "Enter GoPhish API key" }
    Restore-GoPhishData -Key $ApiKey
}
else {
    # Default: run both phases with a pause in between
    Install-GoPhishServer

    Write-Host "`n--- MANUAL STEPS REQUIRED ---" -ForegroundColor Yellow
    Write-Host "Complete steps 1-5 above, then enter the API key below." -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to exit and run Phase 2 later with:" -ForegroundColor Gray
    Write-Host "  .\setup-gophish-server.ps1 -Restore -ApiKey `"your-key`"`n" -ForegroundColor Gray

    $ApiKey = Read-Host "Enter new GoPhish API key"
    if (-not $ApiKey) { Write-Host "No API key entered. Exiting." -ForegroundColor Red; exit 1 }

    Restore-GoPhishData -Key $ApiKey
}
