# Full Email Delivery Diagnosis
# Run AFTER Connect-ExchangeOnline

$sender = "itsupport@blancoitservices.net"
$domain = "blancoitservices.net"
$recipient = "pblanco@equippers.com"
$start = (Get-Date).AddHours(-3)
$end = Get-Date

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host " FULL EMAIL DELIVERY DIAGNOSIS" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

# 1. Message Trace
Write-Host "[1/8] MESSAGE TRACE" -ForegroundColor Yellow
Write-Host "--------------------------------------------"
try {
    $trace = Get-MessageTraceV2 -SenderAddress $sender -StartDate $start -EndDate $end
    if ($trace) {
        $trace | Format-Table Received, Subject, Status, RecipientAddress -AutoSize
        foreach ($t in $trace) {
            Write-Host "  Detail for: $($t.Subject) ($($t.Status))" -ForegroundColor Gray
            try {
                $detail = Get-MessageTraceDetailV2 -MessageTraceId $t.MessageTraceId -RecipientAddress $t.RecipientAddress
                $detail | Format-Table Date, Event, Detail -AutoSize
            } catch {
                Write-Host "  Could not get detail: $_" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Host "  No messages found in trace" -ForegroundColor Red
    }
} catch {
    Write-Host "  Error: $_" -ForegroundColor Red
}

# 2. Quarantine
Write-Host "`n[2/8] QUARANTINE" -ForegroundColor Yellow
Write-Host "--------------------------------------------"
try {
    $q = Get-QuarantineMessage -SenderAddress $sender -StartReceivedDate $start -EndReceivedDate $end
    if ($q) {
        Write-Host "  FOUND $($q.Count) quarantined message(s):" -ForegroundColor Red
        $q | Format-Table ReceivedTime, Subject, QuarantineReason, PolicyName, Type -AutoSize
    } else {
        Write-Host "  No quarantined messages" -ForegroundColor Green
    }
} catch {
    Write-Host "  Error: $_" -ForegroundColor Red
}

# 3. Transport Rules
Write-Host "`n[3/8] TRANSPORT RULES" -ForegroundColor Yellow
Write-Host "--------------------------------------------"
try {
    $rules = Get-TransportRule | Where-Object { $_.State -eq "Enabled" }
    foreach ($r in $rules) {
        $relevant = $false
        if ($r.SenderDomainIs -contains $domain) { $relevant = $true }
        if ($r.Name -match "phish|blancoitservices|whitelist|bypass") { $relevant = $true }
        if ($relevant) {
            Write-Host "  Rule: $($r.Name)" -ForegroundColor White
            Write-Host "    State: $($r.State) | Priority: $($r.Priority)"
            Write-Host "    SenderDomainIs: $($r.SenderDomainIs -join ', ')"
            Write-Host "    SetSCL: $($r.SetSCL)"
            Write-Host "    SetHeaderName: $($r.SetHeaderName)"
            Write-Host "    SetHeaderValue: $($r.SetHeaderValue)"
            Write-Host "    Actions: $($r.Actions -join ', ')"
            Write-Host ""
        }
    }
    Write-Host "  Total enabled rules: $($rules.Count)" -ForegroundColor Gray
} catch {
    Write-Host "  Error: $_" -ForegroundColor Red
}

# 4. Anti-Phishing Policies
Write-Host "`n[4/8] ANTI-PHISHING POLICIES" -ForegroundColor Yellow
Write-Host "--------------------------------------------"
try {
    $policies = Get-AntiPhishPolicy
    foreach ($p in $policies) {
        Write-Host "  Policy: $($p.Name)" -ForegroundColor White
        Write-Host "    Enabled: $($p.Enabled)"
        Write-Host "    PhishThresholdLevel: $($p.PhishThresholdLevel)"
        Write-Host "    EnableMailboxIntelligenceProtection: $($p.EnableMailboxIntelligenceProtection)"
        Write-Host "    EnableSpoofIntelligence: $($p.EnableSpoofIntelligence)"
        Write-Host "    MailboxIntelligenceProtectionAction: $($p.MailboxIntelligenceProtectionAction)"
        Write-Host ""
    }
} catch {
    Write-Host "  Error: $_" -ForegroundColor Red
}

# 5. Anti-Spam Policies
Write-Host "`n[5/8] ANTI-SPAM POLICIES" -ForegroundColor Yellow
Write-Host "--------------------------------------------"
try {
    $spam = Get-HostedContentFilterPolicy
    foreach ($s in $spam) {
        Write-Host "  Policy: $($s.Name)" -ForegroundColor White
        Write-Host "    HighConfidencePhishAction: $($s.HighConfidencePhishAction)"
        Write-Host "    PhishSpamAction: $($s.PhishSpamAction)"
        Write-Host "    HighConfidenceSpamAction: $($s.HighConfidenceSpamAction)"
        Write-Host "    SpamAction: $($s.SpamAction)"
        Write-Host "    AllowedSenderDomains: $($s.AllowedSenderDomains -join ', ')"
        Write-Host "    AllowedSenders: $($s.AllowedSenders -join ', ')"
        Write-Host ""
    }
} catch {
    Write-Host "  Error: $_" -ForegroundColor Red
}

# 6. Safe Links Policies
Write-Host "`n[6/8] SAFE LINKS POLICIES" -ForegroundColor Yellow
Write-Host "--------------------------------------------"
try {
    $sl = Get-SafeLinksPolicy
    foreach ($s in $sl) {
        Write-Host "  Policy: $($s.Name)" -ForegroundColor White
        Write-Host "    IsEnabled: $($s.IsEnabled)"
        Write-Host "    DoNotRewriteUrls: $($s.DoNotRewriteUrls -join ', ')"
        Write-Host "    EnableForInternalSenders: $($s.EnableForInternalSenders)"
        Write-Host ""
    }
} catch {
    Write-Host "  Error: $_" -ForegroundColor Red
}

# 7. Tenant Allow/Block List
Write-Host "`n[7/8] TENANT ALLOW/BLOCK LIST" -ForegroundColor Yellow
Write-Host "--------------------------------------------"
try {
    $allows = Get-TenantAllowBlockListItems -ListType Sender -Allow
    if ($allows) {
        Write-Host "  Allowed senders:" -ForegroundColor Green
        $allows | Format-Table Value, Action, ExpirationDate, LastUsedDate -AutoSize
    } else {
        Write-Host "  No allowed senders" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Error: $_" -ForegroundColor Red
}

# 8. Connection Filter
Write-Host "`n[8/8] CONNECTION FILTER" -ForegroundColor Yellow
Write-Host "--------------------------------------------"
try {
    $cf = Get-HostedConnectionFilterPolicy
    foreach ($c in $cf) {
        Write-Host "  Policy: $($c.Name)" -ForegroundColor White
        Write-Host "    IPAllowList: $($c.IPAllowList -join ', ')"
        Write-Host "    IPBlockList: $($c.IPBlockList -join ', ')"
        Write-Host ""
    }
} catch {
    Write-Host "  Error: $_" -ForegroundColor Red
}

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host " DIAGNOSIS COMPLETE" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan
