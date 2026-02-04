#Requires -Version 5.1
param(
    [string]$SenderDomain = "blancoitservices.net",
    [string]$SenderEmail = "itsupport@blancoitservices.net",
    [string]$RecipientEmail = "pblanco@equippers.com",
    [int]$Hours = 4
)

$ErrorActionPreference = "Continue"
$startDate = (Get-Date).AddHours(-$Hours)
$endDate = Get-Date

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "         EMAIL DELIVERY DIAGNOSTIC TOOL                        " -ForegroundColor Cyan
Write-Host "   Checking: Google Workspace -> Microsoft 365                 " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Sender:    $SenderEmail"
Write-Host "  Recipient: $RecipientEmail"
Write-Host "  Time:      Last $Hours hours"
Write-Host ""

$findings = @()

function Write-Section($title) {
    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " $title" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
}

function Write-Finding($status, $message) {
    switch ($status) {
        "OK"    { Write-Host "  [OK] " -ForegroundColor Green -NoNewline }
        "WARN"  { Write-Host "  [!!] " -ForegroundColor Yellow -NoNewline }
        "ERROR" { Write-Host "  [XX] " -ForegroundColor Red -NoNewline }
        "INFO"  { Write-Host "  [ii] " -ForegroundColor Cyan -NoNewline }
        default { Write-Host "  [--] " -ForegroundColor White -NoNewline }
    }
    Write-Host $message
}

Write-Section "MICROSOFT 365 DIAGNOSTICS"

Write-Host "`n  Checking Exchange Online PowerShell module..." -ForegroundColor Gray
$exoModule = Get-Module -ListAvailable -Name ExchangeOnlineManagement | Select-Object -First 1

if (-not $exoModule) {
    Write-Host "  Installing ExchangeOnlineManagement module..." -ForegroundColor Yellow
    try {
        Install-Module -Name ExchangeOnlineManagement -Force -Scope CurrentUser -AllowClobber
        $exoModule = Get-Module -ListAvailable -Name ExchangeOnlineManagement | Select-Object -First 1
    }
    catch {
        Write-Finding "ERROR" "Failed to install module: $_"
        $findings += "BLOCKER: Cannot install ExchangeOnlineManagement module"
    }
}

if ($exoModule) {
    Write-Finding "OK" "ExchangeOnlineManagement v$($exoModule.Version) available"

    Import-Module ExchangeOnlineManagement -ErrorAction SilentlyContinue

    Write-Host "`n  Connecting to Exchange Online..." -ForegroundColor Yellow
    Write-Host "  (Browser will open for authentication)`n" -ForegroundColor Gray

    try {
        try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue } catch {}

        Connect-ExchangeOnline -ShowBanner:$false

        Write-Finding "OK" "Connected to Exchange Online"

        # Message Trace
        Write-Host "`n  [1/4] Running Message Trace..." -ForegroundColor Yellow

        $trace = Get-MessageTrace -SenderAddress $SenderEmail -StartDate $startDate -EndDate $endDate -ErrorAction SilentlyContinue

        if ($trace) {
            Write-Finding "INFO" "Found $($trace.Count) message(s) in trace"

            Write-Host "`n  Message Trace Results:" -ForegroundColor White

            foreach ($msg in $trace) {
                $statusColor = switch ($msg.Status) {
                    "Delivered" { "Green" }
                    "Quarantined" { "Red" }
                    "FilteredAsSpam" { "Red" }
                    "Failed" { "Red" }
                    default { "Yellow" }
                }

                Write-Host "    Subject:  $($msg.Subject)" -ForegroundColor White
                Write-Host "    Received: $($msg.Received)"
                Write-Host "    Status:   " -NoNewline
                Write-Host "$($msg.Status)" -ForegroundColor $statusColor
                Write-Host "    To:       $($msg.RecipientAddress)"
                Write-Host ""

                if ($msg.Status -eq "Quarantined") {
                    $findings += "ISSUE: Email quarantined - Subject: $($msg.Subject)"
                }
                elseif ($msg.Status -eq "FilteredAsSpam") {
                    $findings += "ISSUE: Email filtered as spam - Subject: $($msg.Subject)"
                }
                elseif ($msg.Status -eq "Failed") {
                    $findings += "ISSUE: Email delivery failed - Subject: $($msg.Subject)"
                }
            }
        }
        else {
            Write-Finding "WARN" "No messages found in trace from $SenderEmail"
            $findings += "WARNING: No messages from $SenderEmail found in M365 message trace"
        }

        # Detailed Trace
        Write-Host "`n  [2/4] Getting Detailed Trace..." -ForegroundColor Yellow

        if ($trace) {
            foreach ($msg in $trace | Select-Object -First 3) {
                try {
                    $detail = Get-MessageTraceDetail -MessageTraceId $msg.MessageTraceId -RecipientAddress $msg.RecipientAddress -ErrorAction SilentlyContinue

                    if ($detail) {
                        Write-Host "`n    Trace for: $($msg.Subject)" -ForegroundColor White
                        foreach ($event in $detail | Sort-Object Date) {
                            $eventColor = if ($event.Event -match "Fail|Quarantine|Spam|Drop") { "Red" } else { "Gray" }
                            Write-Host "      $($event.Date.ToString('HH:mm:ss')) - " -NoNewline
                            Write-Host "$($event.Event)" -ForegroundColor $eventColor
                        }
                    }
                }
                catch {
                    Write-Finding "WARN" "Could not get detailed trace"
                }
            }
        }

        # Quarantine Check
        Write-Host "`n  [3/4] Checking Quarantine..." -ForegroundColor Yellow

        try {
            $quarantine = Get-QuarantineMessage -SenderAddress $SenderEmail -StartReceivedDate $startDate -EndReceivedDate $endDate -ErrorAction SilentlyContinue

            if ($quarantine) {
                Write-Finding "ERROR" "Found $($quarantine.Count) message(s) in QUARANTINE!"
                $findings += "ISSUE: $($quarantine.Count) email(s) in quarantine from $SenderEmail"

                Write-Host "`n  Quarantined Messages:" -ForegroundColor Red

                foreach ($q in $quarantine) {
                    Write-Host "    Subject:    $($q.Subject)" -ForegroundColor White
                    Write-Host "    Received:   $($q.ReceivedTime)"
                    Write-Host "    Type:       $($q.Type)"
                    Write-Host "    Reason:     $($q.QuarantineReason)" -ForegroundColor Yellow
                    Write-Host "    Policy:     $($q.PolicyName)"
                    Write-Host ""

                    $findings += "  - Quarantine reason: $($q.QuarantineReason)"
                }
            }
            else {
                Write-Finding "OK" "No messages in quarantine from this sender"
            }
        }
        catch {
            Write-Finding "WARN" "Could not check quarantine: $_"
        }

        # Transport Rules
        Write-Host "`n  [4/4] Checking Transport Rules..." -ForegroundColor Yellow

        try {
            $rules = Get-TransportRule -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Enabled" }

            $relevantRules = $rules | Where-Object {
                $_.SenderDomainIs -contains $SenderDomain -or
                $_.Name -match "phish|whitelist|blancoitservices"
            }

            if ($relevantRules) {
                Write-Finding "INFO" "Found $($relevantRules.Count) relevant transport rule(s)"

                foreach ($rule in $relevantRules) {
                    Write-Host "    Rule: $($rule.Name)" -ForegroundColor White
                    Write-Host "    Priority: $($rule.Priority)"
                    Write-Host ""
                }
            }
            else {
                Write-Finding "WARN" "No transport rules found for $SenderDomain"
                $findings += "WARNING: No transport rules whitelisting $SenderDomain"
            }
        }
        catch {
            Write-Finding "WARN" "Could not check transport rules: $_"
        }

        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    }
    catch {
        Write-Finding "ERROR" "Failed to connect: $_"
        $findings += "BLOCKER: Cannot connect to Exchange Online"
    }
}

Write-Section "GOOGLE WORKSPACE DIAGNOSTICS"

Write-Host "`n  Google email logs require Admin Console access." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Manual Check Steps:" -ForegroundColor Cyan
Write-Host "    1. Go to: https://admin.google.com"
Write-Host "    2. Navigate to: Reporting > Email log search"
Write-Host "    3. Set sender: $SenderEmail"
Write-Host "    4. Check Message status column:"
Write-Host "       - Delivered = Email left Google successfully"
Write-Host "       - Bounced = Recipient server rejected"
Write-Host ""

Write-Host "  SMTP Relay Config Check:" -ForegroundColor Cyan
Write-Host "    Location: Apps > Google Workspace > Gmail > Routing > SMTP relay"
Write-Host "    Your public IP: " -NoNewline

try {
    $publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5)
    Write-Host "$publicIP" -ForegroundColor Yellow
    Write-Host "    Ensure this IP is whitelisted in SMTP relay settings"
}
catch {
    Write-Host "(could not determine)" -ForegroundColor Red
}

Write-Section "NETWORK DIAGNOSTICS"

Write-Host "`n  Testing SMTP connectivity..." -ForegroundColor Yellow

$smtpTests = @(
    @{ Host = "smtp-relay.gmail.com"; Port = 587; Name = "Google SMTP Relay" },
    @{ Host = "smtp.gmail.com"; Port = 587; Name = "Gmail SMTP" }
)

foreach ($test in $smtpTests) {
    try {
        $result = Test-NetConnection -ComputerName $test.Host -Port $test.Port -WarningAction SilentlyContinue
        if ($result.TcpTestSucceeded) {
            Write-Finding "OK" "$($test.Name) - $($test.Host):$($test.Port) reachable"
        }
        else {
            Write-Finding "ERROR" "$($test.Name) - NOT reachable"
            $findings += "ISSUE: Cannot reach $($test.Host):$($test.Port)"
        }
    }
    catch {
        Write-Finding "WARN" "$($test.Name) - Could not test"
    }
}

Write-Host "`n  Checking DNS for $SenderDomain..." -ForegroundColor Yellow

try {
    $spf = Resolve-DnsName -Name $SenderDomain -Type TXT -ErrorAction SilentlyContinue | Where-Object { $_.Strings -match "v=spf1" }
    if ($spf) {
        Write-Finding "OK" "SPF record found"
        Write-Host "         $($spf.Strings)" -ForegroundColor Gray
    }
    else {
        Write-Finding "WARN" "No SPF record - emails may fail auth"
        $findings += "WARNING: No SPF record for $SenderDomain"
    }

    $dmarc = Resolve-DnsName -Name "_dmarc.$SenderDomain" -Type TXT -ErrorAction SilentlyContinue
    if ($dmarc) {
        Write-Finding "OK" "DMARC record found"
    }
    else {
        Write-Finding "WARN" "No DMARC record"
    }
}
catch {
    Write-Finding "WARN" "DNS check failed"
}

Write-Section "DIAGNOSIS SUMMARY"

if ($findings.Count -eq 0) {
    Write-Host "`n  No specific issues identified." -ForegroundColor Green
    Write-Host "  Check Google Admin logs for send status." -ForegroundColor Yellow
}
else {
    Write-Host "`n  Issues Found:" -ForegroundColor Red
    foreach ($finding in $findings) {
        Write-Host "    * $finding"
    }
}

Write-Host ""
Write-Host "  Quick Fix Commands:" -ForegroundColor Cyan
Write-Host "  ------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  # Release quarantined messages:" -ForegroundColor Gray
Write-Host "  Get-QuarantineMessage -SenderAddress $SenderEmail | Release-QuarantineMessage -ReleaseToAll"
Write-Host ""
Write-Host "  # Create bypass rule:" -ForegroundColor Gray
Write-Host "  New-TransportRule -Name 'Allow $SenderDomain' -SenderDomainIs '$SenderDomain' -SetSCL -1"
Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "Diagnostic complete." -ForegroundColor Green
Write-Host ""
