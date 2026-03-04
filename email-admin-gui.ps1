Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Config ---
$sender = "support@expertimportersllc.com"
$domain = "expertimportersllc.com"
$gophishApi = "https://localhost:3333/api"
$gophishKey = "9067795398d2042fc817c61038a9b0b7e34ab57151b88de956864b7bf4fae301"
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
$form.MinimumSize = New-Object System.Drawing.Size(960, 820)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Consolas", 10)
$form.FormBorderStyle = "Sizable"
$form.MaximizeBox = $true
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi

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
$statusLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($statusLabel)

# --- Output TextBox ---
$output = New-Object System.Windows.Forms.TextBox
$output.Multiline = $true
$output.ScrollBars = "Vertical"
$output.ReadOnly = $true
$output.BackColor = [System.Drawing.Color]::FromArgb(15, 15, 15)
$output.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 0)
$output.Font = New-Object System.Drawing.Font("Consolas", 9)
$output.Location = New-Object System.Drawing.Point(20, 517)
$output.Size = New-Object System.Drawing.Size(910, 253)
$output.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($output)

$outputLabel = New-Object System.Windows.Forms.Label
$outputLabel.Text = "Terminal Output:"
$outputLabel.Location = New-Object System.Drawing.Point(20, 497)
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
$script:lastExportPath = $null
$script:lastExportGroup = $null

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
    $lbl.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
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

$btnReleaseSelected = New-StyledButton "Release Selected..." 315 112 165 35 @(0, 100, 0)
$btnReleaseSelected.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- LOADING QUARANTINED MESSAGES ---"
    try {
        $q = Get-QuarantineMessage -SenderAddress $sender -StartReceivedDate (Get-Date).AddDays(-7)
        if (-not $q) { Write-Output-Box "No quarantined messages from $sender"; return }
        $q = @($q | Sort-Object ReceivedTime -Descending)

        # Build selection dialog
        $dlg = New-Object System.Windows.Forms.Form
        $dlg.Text = "Select Messages to Release"
        $dlg.Size = New-Object System.Drawing.Size(700, 450)
        $dlg.MinimumSize = New-Object System.Drawing.Size(500, 300)
        $dlg.StartPosition = "CenterParent"
        $dlg.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
        $dlg.ForeColor = [System.Drawing.Color]::White
        $dlg.FormBorderStyle = "Sizable"
        $dlg.MaximizeBox = $true
        $dlg.MinimizeBox = $false

        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = "Check messages to release ($($q.Count) found):"
        $lbl.Location = New-Object System.Drawing.Point(10, 10)
        $lbl.Size = New-Object System.Drawing.Size(660, 20)
        $lbl.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
        $lbl.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
        $dlg.Controls.Add($lbl)

        $clb = New-Object System.Windows.Forms.CheckedListBox
        $clb.Location = New-Object System.Drawing.Point(10, 35)
        $clb.Size = New-Object System.Drawing.Size(660, 310)
        $clb.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
        $clb.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 0)
        $clb.Font = New-Object System.Drawing.Font("Consolas", 9)
        $clb.BorderStyle = "None"
        $clb.CheckOnClick = $true
        $clb.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

        foreach ($msg in $q) {
            $ts = $msg.ReceivedTime.ToString("MM/dd HH:mm")
            $subj = if ($msg.Subject.Length -gt 40) { $msg.Subject.Substring(0, 40) + "..." } else { $msg.Subject }
            $entry = "$ts | $($msg.RecipientAddress) | $subj"
            [void]$clb.Items.Add($entry, $false)
        }
        $dlg.Controls.Add($clb)

        $btnAll = New-Object System.Windows.Forms.Button
        $btnAll.Text = "Select All"
        $btnAll.Location = New-Object System.Drawing.Point(10, 355)
        $btnAll.Size = New-Object System.Drawing.Size(100, 30)
        $btnAll.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
        $btnAll.ForeColor = [System.Drawing.Color]::White
        $btnAll.FlatStyle = "Flat"
        $btnAll.Font = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Bold)
        $btnAll.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
        $btnAll.Add_Click({ for ($i = 0; $i -lt $clb.Items.Count; $i++) { $clb.SetItemChecked($i, $true) } })
        $dlg.Controls.Add($btnAll)

        $btnNone = New-Object System.Windows.Forms.Button
        $btnNone.Text = "Select None"
        $btnNone.Location = New-Object System.Drawing.Point(115, 355)
        $btnNone.Size = New-Object System.Drawing.Size(110, 30)
        $btnNone.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
        $btnNone.ForeColor = [System.Drawing.Color]::White
        $btnNone.FlatStyle = "Flat"
        $btnNone.Font = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Bold)
        $btnNone.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
        $btnNone.Add_Click({ for ($i = 0; $i -lt $clb.Items.Count; $i++) { $clb.SetItemChecked($i, $false) } })
        $dlg.Controls.Add($btnNone)

        $btnRelease = New-Object System.Windows.Forms.Button
        $btnRelease.Text = "Release Selected"
        $btnRelease.Location = New-Object System.Drawing.Point(470, 355)
        $btnRelease.Size = New-Object System.Drawing.Size(200, 30)
        $btnRelease.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 0)
        $btnRelease.ForeColor = [System.Drawing.Color]::White
        $btnRelease.FlatStyle = "Flat"
        $btnRelease.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
        $btnRelease.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $btnRelease.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
        $dlg.Controls.Add($btnRelease)
        $dlg.AcceptButton = $btnRelease

        $result = $dlg.ShowDialog($form)
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            $indices = $clb.CheckedIndices
            if ($indices.Count -eq 0) { Write-Output-Box "No messages selected"; return }
            Write-Output-Box "Releasing $($indices.Count) message(s)..."
            $released = 0
            foreach ($i in $indices) {
                try {
                    $q[$i] | Release-QuarantineMessage -ReleaseToAll -Force -ErrorAction Stop
                    $ts = $q[$i].ReceivedTime.ToString("MM/dd HH:mm")
                    Write-Output-Box "[OK] Released: $($q[$i].RecipientAddress) ($ts)"
                    $released++
                } catch {
                    Write-Output-Box "[WARN] $($q[$i].RecipientAddress): $($_.Exception.Message)"
                }
            }
            Write-Output-Box "Released $released of $($indices.Count) selected message(s)"
        } else { Write-Output-Box "Cancelled" }
        $dlg.Dispose()
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnReleaseSelected)

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
    } catch {
        Write-Output-Box "[ERROR] $($_.Exception.Message)"
        if ($_.Exception.InnerException) { Write-Output-Box "  Inner: $($_.Exception.InnerException.Message)" }
        Write-Output-Box "  Command: $($_.InvocationInfo.Line.Trim())"
        Write-Output-Box "  FullError: $($_ | Out-String)"
    }
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
# SECTION 8: M365 Groups & GoPhish Import
# =============================================
New-SectionLabel "--- M365 GROUPS & GOPHISH IMPORT ---" 20 437

$btnBrowseGroups = New-StyledButton "Browse & Export Groups" 20 454 200 35 @(100, 50, 150)
$btnBrowseGroups.Add_Click({
    if (-not $script:connected) { Write-Output-Box "[!] Connect to Exchange Online first"; return }
    Write-Output-Box "`r`n--- FETCHING M365 GROUPS ---"

    try {
        # Collect all groups into a list: @{ Name; Email; Type; Identity }
        $allGroups = @()

        Write-Output-Box "Fetching distribution groups..."
        $dgs = Get-DistributionGroup -ResultSize 100 -ErrorAction SilentlyContinue
        if ($dgs) {
            foreach ($dg in $dgs) {
                $count = (Get-DistributionGroupMember -Identity $dg.Identity -ErrorAction SilentlyContinue).Count
                $allGroups += @{ Name = $dg.Name; Email = $dg.PrimarySmtpAddress; Type = "Distribution"; Identity = $dg.Identity; Count = $count }
            }
        }

        Write-Output-Box "Fetching Microsoft 365 groups..."
        $m365 = Get-UnifiedGroup -ResultSize 100 -ErrorAction SilentlyContinue
        if ($m365) {
            foreach ($g in $m365) {
                $allGroups += @{ Name = $g.DisplayName; Email = $g.PrimarySmtpAddress; Type = "M365"; Identity = $g.Identity; Count = $null }
            }
        }

        if ($allGroups.Count -eq 0) {
            Write-Output-Box "[!] No groups found in tenant"
            return
        }

        Write-Output-Box "Found $($allGroups.Count) groups. Opening selector..."

        # Build checklist dialog
        $dlg = New-Object System.Windows.Forms.Form
        $dlg.Text = "Select Groups to Export as GoPhish CSV"
        $dlg.Size = New-Object System.Drawing.Size(750, 500)
        $dlg.MinimumSize = New-Object System.Drawing.Size(500, 300)
        $dlg.StartPosition = "CenterParent"
        $dlg.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
        $dlg.ForeColor = [System.Drawing.Color]::White
        $dlg.FormBorderStyle = "Sizable"
        $dlg.MaximizeBox = $true
        $dlg.MinimizeBox = $false

        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = "Check groups to export ($($allGroups.Count) found) - each exports as separate CSV:"
        $lbl.Location = New-Object System.Drawing.Point(10, 10)
        $lbl.Size = New-Object System.Drawing.Size(710, 20)
        $lbl.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
        $lbl.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
        $dlg.Controls.Add($lbl)

        $clb = New-Object System.Windows.Forms.CheckedListBox
        $clb.Location = New-Object System.Drawing.Point(10, 35)
        $clb.Size = New-Object System.Drawing.Size(710, 350)
        $clb.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
        $clb.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 0)
        $clb.Font = New-Object System.Drawing.Font("Consolas", 9)
        $clb.BorderStyle = "None"
        $clb.CheckOnClick = $true
        $clb.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

        foreach ($g in $allGroups) {
            $countStr = if ($g.Count -ne $null) { " | Members: $($g.Count)" } else { "" }
            $entry = "[$($g.Type)] $($g.Name) | $($g.Email)$countStr"
            [void]$clb.Items.Add($entry, $false)
        }
        $dlg.Controls.Add($clb)

        $btnAll = New-Object System.Windows.Forms.Button
        $btnAll.Text = "Select All"
        $btnAll.Location = New-Object System.Drawing.Point(10, 395)
        $btnAll.Size = New-Object System.Drawing.Size(100, 30)
        $btnAll.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
        $btnAll.ForeColor = [System.Drawing.Color]::White
        $btnAll.FlatStyle = "Flat"
        $btnAll.Font = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Bold)
        $btnAll.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
        $btnAll.Add_Click({ for ($i = 0; $i -lt $clb.Items.Count; $i++) { $clb.SetItemChecked($i, $true) } })
        $dlg.Controls.Add($btnAll)

        $btnNone = New-Object System.Windows.Forms.Button
        $btnNone.Text = "Select None"
        $btnNone.Location = New-Object System.Drawing.Point(115, 395)
        $btnNone.Size = New-Object System.Drawing.Size(110, 30)
        $btnNone.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
        $btnNone.ForeColor = [System.Drawing.Color]::White
        $btnNone.FlatStyle = "Flat"
        $btnNone.Font = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Bold)
        $btnNone.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
        $btnNone.Add_Click({ for ($i = 0; $i -lt $clb.Items.Count; $i++) { $clb.SetItemChecked($i, $false) } })
        $dlg.Controls.Add($btnNone)

        $btnExport = New-Object System.Windows.Forms.Button
        $btnExport.Text = "Export Selected"
        $btnExport.Location = New-Object System.Drawing.Point(530, 395)
        $btnExport.Size = New-Object System.Drawing.Size(190, 30)
        $btnExport.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 0)
        $btnExport.ForeColor = [System.Drawing.Color]::White
        $btnExport.FlatStyle = "Flat"
        $btnExport.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
        $btnExport.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $btnExport.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
        $dlg.Controls.Add($btnExport)
        $dlg.AcceptButton = $btnExport

        $result = $dlg.ShowDialog($form)
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            $indices = $clb.CheckedIndices
            if ($indices.Count -eq 0) { Write-Output-Box "No groups selected"; $dlg.Dispose(); return }

            # Pick folder to save CSVs
            $folderDlg = New-Object System.Windows.Forms.FolderBrowserDialog
            $folderDlg.Description = "Select folder to save GoPhish CSV files"
            $folderDlg.ShowNewFolderButton = $true
            if ($folderDlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { $dlg.Dispose(); return }
            $saveFolder = $folderDlg.SelectedPath

            Write-Output-Box "`r`nExporting $($indices.Count) group(s) to: $saveFolder"
            $exportedPaths = @()

            foreach ($i in $indices) {
                $g = $allGroups[$i]
                Write-Output-Box "`r`n--- EXPORTING: $($g.Name) ---"

                try {
                    $members = $null
                    if ($g.Type -eq "Distribution") {
                        $members = Get-DistributionGroupMember -Identity $g.Identity -ErrorAction Stop |
                            Where-Object { $_.RecipientType -eq 'UserMailbox' -or $_.RecipientType -eq 'MailUser' }
                    } else {
                        $groupLinks = Get-UnifiedGroupLinks -Identity $g.Identity -LinkType Members -ErrorAction Stop
                        $members = @()
                        foreach ($link in $groupLinks) {
                            $user = Get-User -Identity $link.PrimarySmtpAddress -ErrorAction SilentlyContinue
                            if ($user) { $members += $user }
                        }
                    }

                    if (-not $members -or $members.Count -eq 0) {
                        Write-Output-Box "[WARN] No members found in $($g.Name) - skipping"
                        continue
                    }

                    # Build CSV
                    $csvLines = @("email,first_name,last_name,position")
                    foreach ($m in $members) {
                        $email = $m.PrimarySmtpAddress
                        if (-not $email) { $email = $m.WindowsEmailAddress }
                        if (-not $email) { continue }

                        $firstName = if ($m.FirstName) { $m.FirstName } else { "" }
                        $lastName = if ($m.LastName) { $m.LastName } else { "" }
                        $title = if ($m.Title) { $m.Title } else { "Staff" }

                        $csvLines += "$email,$firstName,$lastName,$title"
                    }

                    $safeName = $g.Name -replace '[^a-zA-Z0-9 _-]', ''
                    $filePath = Join-Path $saveFolder "$safeName.csv"
                    $csvLines -join "`r`n" | Out-File -FilePath $filePath -Encoding UTF8
                    $exportedPaths += $filePath
                    Write-Output-Box "[OK] $($g.Name): $($members.Count) members -> $filePath"
                } catch {
                    Write-Output-Box "[ERROR] $($g.Name): $($_.Exception.Message)"
                }
            }

            if ($exportedPaths.Count -gt 0) {
                $script:lastExportPaths = $exportedPaths
                $script:lastExportGroup = $allGroups[$indices[0]].Name
                $script:lastExportPath = $exportedPaths[0]
                Write-Output-Box "`r`n[OK] Exported $($exportedPaths.Count) group CSV(s). Ready to import to GoPhish."
            }
        } else { Write-Output-Box "Cancelled" }
        $dlg.Dispose()
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnBrowseGroups)

$btnImportGoPhish = New-StyledButton "Import to GoPhish" 230 454 170 35 @(0, 150, 0)
$btnImportGoPhish.Add_Click({
    # Determine CSV file to import
    $csvFile = $script:lastExportPath
    if (-not $csvFile -or -not (Test-Path $csvFile)) {
        $openDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openDialog.Filter = "CSV Files (*.csv)|*.csv"
        $openDialog.Title = "Select GoPhish Group CSV"
        if ($openDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $csvFile = $openDialog.FileName
        } else { return }
    }

    try { Add-Type -AssemblyName Microsoft.VisualBasic } catch {}
    $defaultName = if ($script:lastExportGroup) { $script:lastExportGroup } else { "Imported Group" }
    $gpGroupName = [Microsoft.VisualBasic.Interaction]::InputBox("Enter name for the new GoPhish group:", "Import to GoPhish", $defaultName)
    if (-not $gpGroupName) { return }

    Write-Output-Box "`r`n--- IMPORTING TO GOPHISH: $gpGroupName ---"

    try {
        $lines = Get-Content -Path $csvFile -Encoding UTF8
        $targets = @()
        # Skip header
        foreach ($line in $lines[1..($lines.Count - 1)]) {
            $line = $line.Trim()
            if (-not $line) { continue }
            $parts = $line.Split(',')
            if ($parts.Count -ge 4) {
                $targets += @{
                    email = $parts[0].Trim()
                    first_name = $parts[1].Trim()
                    last_name = $parts[2].Trim()
                    position = $parts[3].Trim()
                }
            }
        }

        if ($targets.Count -eq 0) {
            Write-Output-Box "[ERROR] No valid targets found in CSV"
            return
        }

        Write-Output-Box "Found $($targets.Count) targets"

        $result = Invoke-GoPhish "POST" "groups/" @{ name = $gpGroupName; targets = $targets }
        Write-Output-Box "[OK] Created GoPhish group: $gpGroupName (ID: $($result.id))"
        Write-Output-Box "[OK] $($targets.Count) members imported"
        foreach ($t in $targets | Select-Object -First 5) {
            Write-Output-Box "  - $($t.email) ($($t.first_name) $($t.last_name))"
        }
        if ($targets.Count -gt 5) { Write-Output-Box "  ... and $($targets.Count - 5) more" }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnImportGoPhish)

$btnViewGroups = New-StyledButton "View GoPhish Groups" 410 454 170 35 @(150, 100, 0)
$btnViewGroups.Add_Click({
    Write-Output-Box "`r`n--- GOPHISH GROUPS ---"
    try {
        $groups = Invoke-GoPhish "GET" "groups/"
        if ($groups) {
            foreach ($g in $groups) {
                Write-Output-Box "`r`n  Group: $($g.name) (ID: $($g.id))"
                Write-Output-Box "  Members: $($g.targets.Count)"
                foreach ($t in $g.targets | Select-Object -First 5) {
                    Write-Output-Box "    - $($t.email) ($($t.first_name) $($t.last_name))"
                }
                if ($g.targets.Count -gt 5) { Write-Output-Box "    ... and $($g.targets.Count - 5) more" }
            }
        } else {
            Write-Output-Box "No groups found"
        }
    } catch { Write-Output-Box "[ERROR] $($_.Exception.Message)" }
})
$form.Controls.Add($btnViewGroups)

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
