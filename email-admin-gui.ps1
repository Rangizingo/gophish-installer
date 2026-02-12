Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Config ---
$sender = "itsupport@blancoitservices.net"
$domain = "blancoitservices.net"
$gophishApi = "https://localhost:3333/api"
$gophishKey = "38154aafd6867378cb200f31661aa4ed524bb64aa8d91f6d1ad0d61fb8f695fa"
$targets = @(
    @{ email = "pblanco@equippers.com"; first_name = "Peter"; last_name = "Blanco"; position = "IT Manager" }
    @{ email = "kmarchese@equippers.com"; first_name = "Kevin"; last_name = "Marchese"; position = "CIO" }
    @{ email = "mfrank@equippers.com"; first_name = "Matt"; last_name = "Frank"; position = "Staff" }
)

# Trust self-signed certs for GoPhish
Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllGui : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllGui
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Create Form ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Email Admin - Phishing Campaign Manager"
$form.Size = New-Object System.Drawing.Size(960, 820)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Consolas", 10)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false

# Title
$title = New-Object System.Windows.Forms.Label
$title.Text = "PHISHING CAMPAIGN EMAIL ADMIN"
$title.Font = New-Object System.Drawing.Font("Consolas", 14, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(196, 18, 48)
$title.Location = New-Object System.Drawing.Point(20, 8)
$title.Size = New-Object System.Drawing.Size(500, 30)
$form.Controls.Add($title)

# Status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Exchange: Not Connected"
$statusLabel.ForeColor = [System.Drawing.Color]::Yellow
$statusLabel.Location = New-Object System.Drawing.Point(550, 12)
$statusLabel.Size = New-Object System.Drawing.Size(380, 20)
$form.Controls.Add($statusLabel)

# --- Output TextBox ---
$output = New-Object System.Windows.Forms.TextBox
$output.Multiline = $true
$output.ScrollBars = "Vertical"
$output.ReadOnly = $true
$output.BackColor = [System.Drawing.Color]::FromArgb(15, 15, 15)
$output.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 0)
$output.Font = New-Object System.Drawing.Font("Consolas", 9)
$output.Location = New-Object System.Drawing.Point(20, 460)
$output.Size = New-Object System.Drawing.Size(910, 310)
$form.Controls.Add($output)

$outputLabel = New-Object System.Windows.Forms.Label
$outputLabel.Text = "Terminal Output:"
$outputLabel.Location = New-Object System.Drawing.Point(20, 440)
$outputLabel.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($outputLabel)

# --- Helpers ---
function Write-Output-Box($text) {
    $output.AppendText("$text`r`n")
    $output.SelectionStart = $output.Text.Length
    $output.ScrollToCaret()
    $form.Refresh()
}

$script:connected = $false

function New-StyledButton($text, $x, $y, $width, $height, $color) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Size = New-Object System.Drawing.Size($width, $height)
    $btn.BackColor = [System.Drawing.Color]::FromArgb($color[0], $color[1], $color[2])
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.FlatStyle = "Flat"
    $btn.Font = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Bold)
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $btn
}

function New-SectionLabel($text, $x, $y) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $text
    $lbl.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(196, 18, 48)
    $lbl.Location = New-Object System.Drawing.Point($x, $y)
    $lbl.Size = New-Object System.Drawing.Size(910, 16)
    $form.Controls.Add($lbl)
}

function Invoke-GoPhish($method, $endpoint, $body) {
    $h = @{ Authorization = "Bearer $gophishKey"; 'Content-Type' = 'application/json' }
    $uri = "$gophishApi/$endpoint"
    $params = @{ Uri = $uri; Method = $method; Headers = $h }
    if ($body) { $params.Body = ($body | ConvertTo-Json -Depth 10) }
    return Invoke-RestMethod @params
}

# =============================================
# SECTION 1: EXCHANGE ONLINE CONNECTION
# =============================================
New-SectionLabel "--- EXCHANGE ONLINE ---" 20 38

$btnConnect = New-StyledButton "Connect Exchange" 20 55 160 35 @(0, 120, 215)
$btnConnect.Add_Click({
    Write-Output-Box "Loading Exchange Online module..."
    try {
        Import-Module ExchangeOnlineManagement -ErrorAction Stop
        Write-Output-Box "Browser will open for authentication..."
        Connect-ExchangeOnline -ShowBanner:$false
        $script:connected = $true
        $statusLabel.Text = "Exchange: Connected"
        $statusLabel.ForeColor = [System.Drawing.Color]::LimeGreen
        Write-Output-Box "[OK] Connected to Exchange Online"
    } catch {
        Write-Output-Box "[ERROR] $($_.Exception.Message)"
    }
})
$form.Controls.Add($btnConnect)

$btnDisconnect = New-StyledButton "Disconnect" 185 55 120 35 @(100, 0, 0)
$btnDisconnect.Add_Click({
    try {
        Disconnect-ExchangeOnline -Confirm:$false
        $script:connected = $false
        $statusLabel.Text = "Exchange: Disconnected"
        $statusLabel.ForeColor = [System.Drawing.Color]::Yellow
        Write-Output-Box "[OK] Disconnected"
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnDisconnect)

$btnClearOutput = New-StyledButton "Clear Output" 820 55 110 35 @(60, 60, 60)
$btnClearOutput.Add_Click({ $output.Clear() })
$form.Controls.Add($btnClearOutput)

# =============================================
# SECTION 2: QUARANTINE MANAGEMENT
# =============================================
New-SectionLabel "--- QUARANTINE ---" 20 95

$btnCheckQ = New-StyledButton "Check Quarantine" 20 112 155 35 @(196, 18, 48)
$btnCheckQ.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- QUARANTINE CHECK ---"
    try {
        $q = Get-QuarantineMessage -SenderAddress $sender -StartReceivedDate (Get-Date).AddDays(-7) -EndReceivedDate (Get-Date)
        if ($q) {
            Write-Output-Box "Found $($q.Count) quarantined message(s):"
            foreach ($msg in $q) {
                Write-Output-Box "  To: $($msg.RecipientAddress) | Type: $($msg.Type) | $($msg.ReceivedTime) | Policy: $($msg.PolicyName)"
            }
        } else { Write-Output-Box "No quarantined messages from $sender" }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnCheckQ)

$btnReleaseAll = New-StyledButton "Release ALL" 180 112 130 35 @(0, 150, 0)
$btnReleaseAll.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- RELEASING ALL ---"
    try {
        $q = Get-QuarantineMessage -SenderAddress $sender -StartReceivedDate (Get-Date).AddDays(-7)
        if ($q) {
            foreach ($msg in $q) {
                $msg | Release-QuarantineMessage -ReleaseToAll -Force -ErrorAction SilentlyContinue
            }
            Write-Output-Box "[OK] Released $($q.Count) message(s)"
        } else { Write-Output-Box "No messages to release" }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnReleaseAll)

$btnReleaseKM = New-StyledButton "Release Kevin+Matt" 315 112 165 35 @(0, 100, 0)
$btnReleaseKM.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- RELEASING FOR KEVIN + MATT ---"
    try {
        $q = Get-QuarantineMessage -SenderAddress $sender -StartReceivedDate (Get-Date).AddDays(-7)
        $tgt = @("kmarchese@equippers.com", "mfrank@equippers.com")
        $released = 0
        foreach ($msg in $q) {
            if ($msg.RecipientAddress -in $tgt) {
                $msg | Release-QuarantineMessage -ReleaseToAll -Force -ErrorAction SilentlyContinue
                Write-Output-Box "[OK] Released: $($msg.RecipientAddress)"
                $released++
            }
        }
        if ($released -eq 0) { Write-Output-Box "No messages found for Kevin or Matt" }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnReleaseKM)

# =============================================
# SECTION 3: MESSAGE TRACE & DIAGNOSTICS
# =============================================
New-SectionLabel "--- DIAGNOSTICS ---" 20 152

$btnTrace = New-StyledButton "Message Trace (4hr)" 20 169 160 35 @(80, 80, 80)
$btnTrace.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- MESSAGE TRACE (Last 4 hours) ---"
    try {
        $t = Get-MessageTrace -SenderAddress $sender -StartDate (Get-Date).AddHours(-4) -EndDate (Get-Date) -ErrorAction SilentlyContinue
        if (-not $t) { $t = Get-MessageTraceV2 -SenderAddress $sender -StartDate (Get-Date).AddHours(-4) -EndDate (Get-Date) -ErrorAction SilentlyContinue }
        if ($t) {
            Write-Output-Box "Found $($t.Count) message(s):"
            foreach ($m in $t) { Write-Output-Box "  $($m.RecipientAddress) | Status: $($m.Status) | $($m.Received)" }
        } else { Write-Output-Box "No messages found" }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnTrace)

$btnTrace24 = New-StyledButton "Message Trace (24hr)" 185 169 165 35 @(80, 80, 80)
$btnTrace24.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- MESSAGE TRACE (Last 24 hours) ---"
    try {
        $t = Get-MessageTrace -SenderAddress $sender -StartDate (Get-Date).AddHours(-24) -EndDate (Get-Date) -ErrorAction SilentlyContinue
        if (-not $t) { $t = Get-MessageTraceV2 -SenderAddress $sender -StartDate (Get-Date).AddHours(-24) -EndDate (Get-Date) -ErrorAction SilentlyContinue }
        if ($t) {
            Write-Output-Box "Found $($t.Count) message(s):"
            foreach ($m in $t) { Write-Output-Box "  $($m.RecipientAddress) | Status: $($m.Status) | $($m.Received)" }
        } else { Write-Output-Box "No messages found" }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnTrace24)

$btnSafeSenders = New-StyledButton "Check Safe Senders" 355 169 160 35 @(150, 100, 0)
$btnSafeSenders.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- JUNK EMAIL / SAFE SENDERS CONFIG ---"
    $users = @("pblanco@equippers.com", "kmarchese@equippers.com", "mfrank@equippers.com")
    foreach ($u in $users) {
        try {
            $j = Get-MailboxJunkEmailConfiguration -Identity $u -ErrorAction Stop
            Write-Output-Box "`r`n  $u"
            Write-Output-Box "    Enabled: $($j.Enabled)"
            Write-Output-Box "    ContactsTrusted: $($j.ContactsTrusted)"
            $trusted = $j.TrustedSendersAndDomains | Where-Object { $_ }
            if ($trusted) {
                Write-Output-Box "    TrustedSenders: $($trusted -join ', ')"
            } else {
                Write-Output-Box "    TrustedSenders: (none)"
            }
            $blocked = $j.BlockedSendersAndDomains | Where-Object { $_ }
            if ($blocked) {
                Write-Output-Box "    BlockedSenders: $($blocked -join ', ')"
            }
        } catch { Write-Output-Box "  $u - [ERROR] $($_.Exception.Message)" }
    }
})
$form.Controls.Add($btnSafeSenders)

$btnAddSafeSender = New-StyledButton "Add Safe Sender (All)" 520 169 170 35 @(0, 100, 180)
$btnAddSafeSender.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- ADDING $domain AS SAFE SENDER FOR ALL USERS ---"
    $users = @("pblanco@equippers.com", "kmarchese@equippers.com", "mfrank@equippers.com")
    foreach ($u in $users) {
        try {
            $j = Get-MailboxJunkEmailConfiguration -Identity $u
            $current = @($j.TrustedSendersAndDomains | Where-Object { $_ })
            if ($domain -notin $current) {
                $current += $domain
                Set-MailboxJunkEmailConfiguration -Identity $u -TrustedSendersAndDomains $current -ErrorAction Stop
                Write-Output-Box "[OK] Added $domain to safe senders for $u"
            } else {
                Write-Output-Box "[OK] $domain already trusted for $u"
            }
        } catch { Write-Output-Box "[ERROR] $u - $($_.Exception.Message)" }
    }
})
$form.Controls.Add($btnAddSafeSender)

# =============================================
# SECTION 4: POLICIES & RULES
# =============================================
New-SectionLabel "--- POLICIES & RULES ---" 20 209

$btnTransport = New-StyledButton "Transport Rules" 20 226 140 35 @(80, 80, 80)
$btnTransport.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- TRANSPORT RULES ---"
    try {
        $rules = Get-TransportRule | Where-Object { $_.State -eq "Enabled" }
        $relevant = $rules | Where-Object {
            $_.SenderDomainIs -contains $domain -or $_.Name -match "phish|blancoitservices|whitelist|bypass"
        }
        if ($relevant) {
            foreach ($r in $relevant) {
                Write-Output-Box "  Rule: $($r.Name) | Priority: $($r.Priority) | SCL: $($r.SetSCL)"
                Write-Output-Box "    SenderDomainIs: $($r.SenderDomainIs -join ', ')"
            }
        } else { Write-Output-Box "No relevant transport rules found" }
        Write-Output-Box "Total enabled rules: $($rules.Count)"
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnTransport)

$btnAllowList = New-StyledButton "Allow List" 165 226 120 35 @(80, 80, 80)
$btnAllowList.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- TENANT ALLOW/BLOCK LIST ---"
    try {
        $allows = Get-TenantAllowBlockListItems -ListType Sender -Allow
        if ($allows) {
            foreach ($a in $allows) { Write-Output-Box "  ALLOW: $($a.Value) | Expires: $($a.ExpirationDate)" }
        } else { Write-Output-Box "  No allowed senders" }
        $blocks = Get-TenantAllowBlockListItems -ListType Sender -Block -ErrorAction SilentlyContinue
        if ($blocks) {
            foreach ($b in $blocks) { Write-Output-Box "  BLOCK: $($b.Value) | Expires: $($b.ExpirationDate)" }
        }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnAllowList)

$btnAntiSpam = New-StyledButton "Anti-Spam Policy" 290 226 145 35 @(80, 80, 80)
$btnAntiSpam.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- ANTI-SPAM POLICIES ---"
    try {
        $policies = Get-HostedContentFilterPolicy
        foreach ($p in $policies) {
            Write-Output-Box "  Policy: $($p.Name)"
            Write-Output-Box "    HighConfPhish: $($p.HighConfidencePhishAction) | Phish: $($p.PhishSpamAction)"
            Write-Output-Box "    HighConfSpam: $($p.HighConfidenceSpamAction) | Spam: $($p.SpamAction)"
            Write-Output-Box "    AllowedDomains: $($p.AllowedSenderDomains -join ', ')"
            Write-Output-Box "    AllowedSenders: $($p.AllowedSenders -join ', ')"
        }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnAntiSpam)

$btnAntiPhish = New-StyledButton "Anti-Phish Policy" 440 226 145 35 @(80, 80, 80)
$btnAntiPhish.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- ANTI-PHISHING POLICIES ---"
    try {
        $policies = Get-AntiPhishPolicy
        foreach ($p in $policies) {
            Write-Output-Box "  Policy: $($p.Name) | Enabled: $($p.Enabled)"
            Write-Output-Box "    PhishThreshold: $($p.PhishThresholdLevel) | Spoof: $($p.EnableSpoofIntelligence)"
            Write-Output-Box "    MailboxIntel: $($p.EnableMailboxIntelligenceProtection)"
        }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnAntiPhish)

$btnCompare = New-StyledButton "Compare Users" 590 226 135 35 @(150, 100, 0)
$btnCompare.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- COMPARING: pblanco vs kmarchese vs mfrank ---"
    $users = @("pblanco@equippers.com", "kmarchese@equippers.com", "mfrank@equippers.com")
    foreach ($u in $users) {
        Write-Output-Box "`r`n  $u"
        try {
            $rules = Get-HostedContentFilterRule -ErrorAction SilentlyContinue
            foreach ($r in $rules) {
                if ($r.SentTo -contains $u -or $r.RecipientDomainIs -contains "equippers.com") {
                    Write-Output-Box "    SpamRule: $($r.Name) -> $($r.HostedContentFilterPolicy)"
                }
            }
            $phish = Get-AntiPhishRule -ErrorAction SilentlyContinue
            foreach ($r in $phish) {
                if ($r.SentTo -contains $u -or $r.RecipientDomainIs -contains "equippers.com") {
                    Write-Output-Box "    PhishRule: $($r.Name) -> $($r.AntiPhishPolicy)"
                }
            }
        } catch { Write-Output-Box "    [WARN] $($_.Exception.Message)" }
        Write-Output-Box "    (Default policies apply if no rules shown)"
    }
})
$form.Controls.Add($btnCompare)

$btnSafeLinks = New-StyledButton "Safe Links" 730 226 110 35 @(80, 80, 80)
$btnSafeLinks.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- SAFE LINKS POLICIES ---"
    try {
        $policies = Get-SafeLinksPolicy -ErrorAction SilentlyContinue
        if ($policies) {
            foreach ($p in $policies) {
                Write-Output-Box "  Policy: $($p.Name) | Enabled: $($p.IsEnabled)"
                Write-Output-Box "    TrackClicks: $($p.TrackClicks) | ScanUrls: $($p.ScanUrls)"
                Write-Output-Box "    DoNotRewrite: $($p.DoNotRewriteUrls -join ', ')"
            }
        } else { Write-Output-Box "No Safe Links policies found" }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnSafeLinks)

# =============================================
# SECTION 5: ALLOW LIST & OVERRIDE ACTIONS
# =============================================
New-SectionLabel "--- ALLOW LIST & OVERRIDES ---" 20 266

$btnAddAllow = New-StyledButton "Add to Allow List" 20 283 150 35 @(0, 100, 180)
$btnAddAllow.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- ADDING TO ALLOW LIST ---"
    try {
        New-TenantAllowBlockListItems -ListType Sender -Entries $sender -Allow -NoExpiration -ErrorAction Stop
        Write-Output-Box "[OK] Added $sender"
    } catch {
        if ($_.Exception.Message -match "already exists") { Write-Output-Box "[OK] $sender already allowed" }
        else { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
    }
})
$form.Controls.Add($btnAddAllow)

$btnAddDomainAllow = New-StyledButton "Allow Domain" 175 283 130 35 @(0, 100, 180)
$btnAddDomainAllow.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- ADDING DOMAIN TO ALLOW LIST ---"
    try {
        New-TenantAllowBlockListItems -ListType Sender -Entries $domain -Allow -NoExpiration -ErrorAction Stop
        Write-Output-Box "[OK] Added domain $domain"
    } catch {
        if ($_.Exception.Message -match "already exists") { Write-Output-Box "[OK] $domain already allowed" }
        else { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
    }
})
$form.Controls.Add($btnAddDomainAllow)

$btnPhishSimOverride = New-StyledButton "Setup Phish Sim Override" 310 283 190 35 @(0, 100, 180)
$btnPhishSimOverride.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- ADVANCED DELIVERY - PHISH SIM OVERRIDE ---"
    Write-Output-Box "This bypasses ALL filtering including High Confidence Phish"
    try {
        $existing = Get-PhishSimOverridePolicy -ErrorAction SilentlyContinue
        if (-not $existing) {
            New-PhishSimOverridePolicy -Name "PhishSimOverridePolicy" -ErrorAction Stop
            Write-Output-Box "[OK] Created PhishSimOverridePolicy"
        }
        $rule = Get-PhishSimOverrideRule -ErrorAction SilentlyContinue
        if ($rule) {
            Set-PhishSimOverrideRule -Identity $rule.Name -SenderDomainIs $domain -SenderIpRanges "174.105.36.233" -ErrorAction Stop
            Write-Output-Box "[OK] Updated override rule with $domain"
        } else {
            New-PhishSimOverrideRule -Name "PhishSimOverrideRule" -Policy "PhishSimOverridePolicy" -SenderDomainIs $domain -SenderIpRanges "174.105.36.233" -ErrorAction Stop
            Write-Output-Box "[OK] Created override rule for $domain from 174.105.36.233"
        }
        Write-Output-Box "[OK] Phish simulation override active - emails should bypass quarantine"
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnPhishSimOverride)

$btnCheckOverride = New-StyledButton "Check Override Status" 505 283 165 35 @(80, 80, 80)
$btnCheckOverride.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- PHISH SIM OVERRIDE STATUS ---"
    try {
        $p = Get-PhishSimOverridePolicy -ErrorAction SilentlyContinue
        if ($p) {
            Write-Output-Box "  Policy: $($p.Name) | Enabled: $($p.Enabled)"
            $r = Get-PhishSimOverrideRule -ErrorAction SilentlyContinue
            if ($r) {
                Write-Output-Box "  Rule: $($r.Name) | Domains: $($r.SenderDomainIs -join ', ')"
                Write-Output-Box "  IPs: $($r.SenderIpRanges -join ', ')"
            } else { Write-Output-Box "  No override rule found" }
        } else { Write-Output-Box "  No PhishSimOverridePolicy exists (not configured)" }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnCheckOverride)

$btnConnFilter = New-StyledButton "Connection Filter" 675 283 130 35 @(80, 80, 80)
$btnConnFilter.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- CONNECTION FILTER (IP Allow) ---"
    try {
        $cf = Get-HostedConnectionFilterPolicy
        Write-Output-Box "  Policy: $($cf.Name)"
        Write-Output-Box "  IP Allow List: $($cf.IPAllowList -join ', ')"
        Write-Output-Box "  IP Block List: $($cf.IPBlockList -join ', ')"
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnConnFilter)

# =============================================
# SECTION 6: GOPHISH CAMPAIGN MANAGEMENT
# =============================================
New-SectionLabel "--- GOPHISH CAMPAIGNS ---" 20 323

$btnGpStatus = New-StyledButton "Campaign Status" 20 340 140 35 @(100, 50, 150)
$btnGpStatus.Add_Click({
    Write-Output-Box "`r`n--- GOPHISH CAMPAIGNS ---"
    try {
        $campaigns = Invoke-GoPhish "GET" "campaigns/"
        if ($campaigns) {
            foreach ($c in ($campaigns | Select-Object -Last 5)) {
                Write-Output-Box "  #$($c.id): $($c.name) | Status: $($c.status) | Created: $($c.created_date)"
                $sent = ($c.results | Where-Object { $_.status -ne "" }).Count
                $clicked = ($c.results | Where-Object { $_.status -eq "Clicked Link" -or $_.status -eq "Submitted Data" }).Count
                $submitted = ($c.results | Where-Object { $_.status -eq "Submitted Data" }).Count
                Write-Output-Box "    Sent: $sent | Clicked: $clicked | Submitted: $submitted"
            }
        } else { Write-Output-Box "No campaigns found" }
    } catch { Write-Output-Box "[ERROR] GoPhish may not be running: $($_.Exception.Message)" }
})
$form.Controls.Add($btnGpStatus)

$btnGpResults = New-StyledButton "Latest Results" 165 340 130 35 @(100, 50, 150)
$btnGpResults.Add_Click({
    Write-Output-Box "`r`n--- LATEST CAMPAIGN RESULTS ---"
    try {
        $campaigns = Invoke-GoPhish "GET" "campaigns/"
        $latest = $campaigns | Select-Object -Last 1
        if ($latest) {
            Write-Output-Box "Campaign: $($latest.name) (#$($latest.id))"
            foreach ($r in $latest.results) {
                Write-Output-Box "  $($r.email) | Status: $($r.status) | IP: $($r.ip)"
            }
            if ($latest.results.Count -eq 0) { Write-Output-Box "  No results yet" }
        }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnGpResults)

$btnGpSendCampaign = New-StyledButton "New Campaign (All)" 300 340 155 35 @(0, 150, 0)
$btnGpSendCampaign.Add_Click({
    Write-Output-Box "`r`n--- LAUNCHING NEW CAMPAIGN ---"
    try {
        # Update group with all targets
        $groupBody = @{
            id = 1; name = "IT Dept Test Group"
            targets = $targets
        }
        Invoke-GoPhish "PUT" "groups/1" $groupBody | Out-Null
        Write-Output-Box "Updated group with $($targets.Count) targets"

        # Get tunnel URL from input or use default
        $url = $script:tunnelUrl
        if (-not $url) { $url = "https://ships-parking-defines-outreach.trycloudflare.com" }

        $body = @{
            name = "Campaign - $(Get-Date -Format 'MMdd-HHmm')"
            template = @{ name = "M365 Password Expiration - Equippers" }
            page = @{ name = "M365 Password Reset - Equippers" }
            smtp = @{ name = "Google SMTP Relay" }
            url = $url
            groups = @( @{ name = "IT Dept Test Group" } )
        }
        $result = Invoke-GoPhish "POST" "campaigns/" $body
        Write-Output-Box "[OK] Campaign #$($result.id) launched to all targets"
        Write-Output-Box "URL: $url"
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnGpSendCampaign)

$btnGpSendPeter = New-StyledButton "Test (Peter Only)" 460 340 145 35 @(0, 100, 0)
$btnGpSendPeter.Add_Click({
    Write-Output-Box "`r`n--- TEST CAMPAIGN (PETER ONLY) ---"
    try {
        $groupBody = @{
            id = 1; name = "IT Dept Test Group"
            targets = @( $targets[0] )
        }
        Invoke-GoPhish "PUT" "groups/1" $groupBody | Out-Null

        $url = $script:tunnelUrl
        if (-not $url) { $url = "https://ships-parking-defines-outreach.trycloudflare.com" }

        $body = @{
            name = "Peter Test - $(Get-Date -Format 'MMdd-HHmm')"
            template = @{ name = "M365 Password Expiration - Equippers" }
            page = @{ name = "M365 Password Reset - Equippers" }
            smtp = @{ name = "Google SMTP Relay" }
            url = $url
            groups = @( @{ name = "IT Dept Test Group" } )
        }
        $result = Invoke-GoPhish "POST" "campaigns/" $body
        Write-Output-Box "[OK] Test campaign #$($result.id) sent to pblanco@equippers.com"
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnGpSendPeter)

$btnGpTemplates = New-StyledButton "View Templates" 610 340 130 35 @(80, 80, 80)
$btnGpTemplates.Add_Click({
    Write-Output-Box "`r`n--- GOPHISH TEMPLATES ---"
    try {
        $templates = Invoke-GoPhish "GET" "templates/"
        foreach ($t in $templates) { Write-Output-Box "  $($t.id): $($t.name)" }
        Write-Output-Box ""
        $pages = Invoke-GoPhish "GET" "pages/"
        Write-Output-Box "--- LANDING PAGES ---"
        foreach ($p in $pages) { Write-Output-Box "  $($p.id): $($p.name)" }
        Write-Output-Box ""
        $smtp = Invoke-GoPhish "GET" "smtp/"
        Write-Output-Box "--- SENDING PROFILES ---"
        foreach ($s in $smtp) { Write-Output-Box "  $($s.id): $($s.name) | From: $($s.from_address)" }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnGpTemplates)

$btnGpSMTP = New-StyledButton "SMTP Settings" 745 340 95 35 @(80, 80, 80)
$btnGpSMTP.Add_Click({
    Write-Output-Box "`r`n--- GOPHISH SMTP PROFILES ---"
    try {
        $smtp = Invoke-GoPhish "GET" "smtp/"
        foreach ($s in $smtp) {
            Write-Output-Box "  Profile: $($s.name) (#$($s.id))"
            Write-Output-Box "    From: $($s.from_address)"
            Write-Output-Box "    Host: $($s.host)"
            Write-Output-Box "    Envelope: $($s.envelope_sender)"
            Write-Output-Box "    IgnoreCert: $($s.ignore_cert_errors)"
        }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnGpSMTP)

# =============================================
# SECTION 7: TUNNEL & DNS
# =============================================
New-SectionLabel "--- TUNNEL & DNS ---" 20 380

$script:tunnelUrl = ""

$btnTunnelStart = New-StyledButton "Start Tunnel" 20 397 130 35 @(100, 50, 150)
$btnTunnelStart.Add_Click({
    Write-Output-Box "`r`n--- STARTING CLOUDFLARE TUNNEL ---"
    try {
        $logFile = "$env:TEMP\cloudflared-gui.log"
        Start-Process -FilePath "cloudflared" -ArgumentList "tunnel","--url","http://localhost:80","--logfile",$logFile -WindowStyle Hidden
        Write-Output-Box "Tunnel starting... waiting 8 seconds for URL..."
        Start-Sleep -Seconds 8
        $log = Get-Content $logFile -ErrorAction SilentlyContinue
        $urlLine = $log | Select-String "https://.*trycloudflare.com" | Select-Object -Last 1
        if ($urlLine -and $urlLine.Matches) {
            $script:tunnelUrl = $urlLine.Matches[0].Value
            Write-Output-Box "[OK] Tunnel URL: $($script:tunnelUrl)"
        } else {
            Write-Output-Box "[WARN] Tunnel started but URL not captured. Check manually."
        }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnTunnelStart)

$btnTunnelCheck = New-StyledButton "Check Tunnel" 155 397 125 35 @(80, 80, 80)
$btnTunnelCheck.Add_Click({
    Write-Output-Box "`r`n--- TUNNEL STATUS ---"
    $procs = Get-Process cloudflared -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Output-Box "[OK] cloudflared running (PID: $($procs.Id -join ', '))"
        if ($script:tunnelUrl) { Write-Output-Box "  URL: $($script:tunnelUrl)" }
        else { Write-Output-Box "  URL: (not captured - check log)" }
    } else {
        Write-Output-Box "[!!] cloudflared NOT running"
    }
    $docker = Get-Process "com.docker*" -ErrorAction SilentlyContinue
    if ($docker) { Write-Output-Box "[OK] Docker Desktop running" }
    else { Write-Output-Box "[!!] Docker Desktop NOT running" }
    $gophish = docker ps --filter "ancestor=gophish/gophish" --format "{{.Status}}" 2>$null
    if ($gophish) { Write-Output-Box "[OK] GoPhish container: $gophish" }
    else { Write-Output-Box "[!!] GoPhish container not running" }
})
$form.Controls.Add($btnTunnelCheck)

$btnDNS = New-StyledButton "Check DNS (SPF/DMARC)" 285 397 175 35 @(80, 80, 80)
$btnDNS.Add_Click({
    Write-Output-Box "`r`n--- DNS CHECKS for $domain ---"
    try {
        $spf = Resolve-DnsName -Name $domain -Type TXT -ErrorAction SilentlyContinue | Where-Object { $_.Strings -match "spf" }
        if ($spf) { Write-Output-Box "  SPF: $($spf.Strings -join ' ')" }
        else { Write-Output-Box "  SPF: NOT FOUND (emails may fail authentication)" }

        $dmarc = Resolve-DnsName -Name "_dmarc.$domain" -Type TXT -ErrorAction SilentlyContinue
        if ($dmarc) { Write-Output-Box "  DMARC: $($dmarc.Strings -join ' ')" }
        else { Write-Output-Box "  DMARC: NOT FOUND" }

        $mx = Resolve-DnsName -Name $domain -Type MX -ErrorAction SilentlyContinue
        if ($mx) { Write-Output-Box "  MX: $(($mx | ForEach-Object { $_.NameExchange }) -join ', ')" }
        else { Write-Output-Box "  MX: NOT FOUND" }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnDNS)

$btnSetUrl = New-StyledButton "Set Tunnel URL" 465 397 135 35 @(80, 80, 80)
$btnSetUrl.Add_Click({
    $input = [Microsoft.VisualBasic.Interaction]::InputBox("Enter the Cloudflare tunnel URL:", "Tunnel URL", $script:tunnelUrl)
    if ($input) {
        $script:tunnelUrl = $input
        Write-Output-Box "[OK] Tunnel URL set to: $input"
    }
})
# Need VB for InputBox
try { Add-Type -AssemblyName Microsoft.VisualBasic } catch {}
$form.Controls.Add($btnSetUrl)

$btnUpdateSMTPFrom = New-StyledButton "Change Sender" 605 397 130 35 @(150, 100, 0)
$btnUpdateSMTPFrom.Add_Click({
    $newFrom = [Microsoft.VisualBasic.Interaction]::InputBox("Enter new From address (e.g. IT Support <itsupport@domain.com>):", "Change Sender", "IT Support <$sender>")
    if ($newFrom) {
        Write-Output-Box "`r`n--- UPDATING SENDER ---"
        try {
            $smtp = Invoke-GoPhish "GET" "smtp/"
            $profile = $smtp | Select-Object -First 1
            $profile.from_address = $newFrom
            Invoke-GoPhish "PUT" "smtp/$($profile.id)" $profile | Out-Null
            Write-Output-Box "[OK] Sender updated to: $newFrom"
        } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
    }
})
$form.Controls.Add($btnUpdateSMTPFrom)

# =============================================
# STARTUP
# =============================================
Write-Output-Box "============================================"
Write-Output-Box "  PHISHING CAMPAIGN EMAIL ADMIN"
Write-Output-Box "  Sender: $sender"
Write-Output-Box "  Targets: $($targets.Count) users"
Write-Output-Box "============================================"
Write-Output-Box ""
Write-Output-Box "1. Click 'Connect Exchange' for email management"
Write-Output-Box "2. GoPhish buttons work without Exchange connection"
Write-Output-Box "3. Start tunnel before launching campaigns"
Write-Output-Box ""

$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
