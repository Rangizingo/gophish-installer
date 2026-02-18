#!/usr/bin/env python3
"""
Email Admin GUI - Linux Version
Phishing Campaign Manager for GoPhish + M365
"""

import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox, simpledialog
import subprocess
import threading
import json
import ssl
import urllib.request
import urllib.error
import os
import re
from datetime import datetime

# --- Configuration ---
CONFIG = {
    "sender": "itsupport@blancoitservices.net",
    "domain": "blancoitservices.net",
    "gophish_api": "https://localhost:3333/api",
    "gophish_key": "7153200e91ffd8350832edda65ef5d261ce20c7a9de3e2147ea4cc87930a0919",
    "targets": [
        {"email": "pblanco@equippers.com", "first_name": "Peter", "last_name": "Blanco", "position": "IT Manager"},
        {"email": "kmarchese@equippers.com", "first_name": "Kevin", "last_name": "Marchese", "position": "CIO"},
        {"email": "mfrank@equippers.com", "first_name": "Matt", "last_name": "Frank", "position": "Staff"},
    ],
    "home_ip": "174.105.36.233",
}

# SSL context for GoPhish (self-signed cert)
SSL_CTX = ssl.create_default_context()
SSL_CTX.check_hostname = False
SSL_CTX.verify_mode = ssl.CERT_NONE


class EmailAdminGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Email Admin - Phishing Campaign Manager (Linux)")
        self.root.geometry("1000x900")
        self.root.configure(bg="#1e1e1e")
        self.root.resizable(True, True)

        self.exchange_connected = False
        self.tunnel_url = ""

        self.create_widgets()

    def create_widgets(self):
        # Main container with padding
        main_frame = tk.Frame(self.root, bg="#1e1e1e")
        main_frame.pack(fill="both", expand=True, padx=15, pady=10)

        # Title bar
        title_frame = tk.Frame(main_frame, bg="#1e1e1e")
        title_frame.pack(fill="x", pady=(0, 10))

        tk.Label(
            title_frame,
            text="PHISHING CAMPAIGN EMAIL ADMIN",
            bg="#1e1e1e",
            fg="#c41230",
            font=("Consolas", 16, "bold")
        ).pack(side="left")

        self.status_label = tk.Label(
            title_frame,
            text="Exchange: Not Connected",
            bg="#1e1e1e",
            fg="yellow",
            font=("Consolas", 11)
        )
        self.status_label.pack(side="right")

        # Buttons container
        buttons_frame = tk.Frame(main_frame, bg="#1e1e1e")
        buttons_frame.pack(fill="x", pady=(0, 10))

        # Create all sections
        row = 0
        row = self.create_exchange_section(buttons_frame, row)
        row = self.create_quarantine_section(buttons_frame, row)
        row = self.create_diagnostics_section(buttons_frame, row)
        row = self.create_policies_section(buttons_frame, row)
        row = self.create_overrides_section(buttons_frame, row)
        row = self.create_gophish_section(buttons_frame, row)
        row = self.create_group_export_section(buttons_frame, row)
        row = self.create_tunnel_section(buttons_frame, row)

        # Output area
        output_frame = tk.Frame(main_frame, bg="#1e1e1e")
        output_frame.pack(fill="both", expand=True, pady=(10, 0))

        tk.Label(
            output_frame,
            text="Terminal Output:",
            bg="#1e1e1e",
            fg="white",
            font=("Consolas", 10)
        ).pack(anchor="w")

        self.output = scrolledtext.ScrolledText(
            output_frame,
            height=18,
            bg="#0a0a0a",
            fg="#00ff00",
            font=("Consolas", 10),
            insertbackground="white"
        )
        self.output.pack(fill="both", expand=True)

    def create_section_label(self, parent, text, row):
        label = tk.Label(
            parent,
            text=text,
            bg="#1e1e1e",
            fg="#c41230",
            font=("Consolas", 10, "bold"),
            anchor="w"
        )
        label.grid(row=row, column=0, columnspan=6, sticky="w", pady=(12, 4))
        return row + 1

    def create_button(self, parent, text, command, row, col, color="#505050", width=16):
        btn = tk.Button(
            parent,
            text=text,
            command=command,
            bg=color,
            fg="white",
            font=("Consolas", 9, "bold"),
            width=width,
            height=2,
            relief="flat",
            cursor="hand2",
            activebackground="#666666",
            activeforeground="white"
        )
        btn.grid(row=row, column=col, padx=3, pady=2, sticky="w")
        return btn

    def create_exchange_section(self, parent, row):
        row = self.create_section_label(parent, "--- EXCHANGE ONLINE ---", row)
        self.create_button(parent, "Connect Exchange", self.connect_exchange, row, 0, "#0078d4")
        self.create_button(parent, "Disconnect", self.disconnect_exchange, row, 1, "#640000")
        self.create_button(parent, "Clear Output", self.clear_output, row, 2, "#3c3c3c")
        return row + 1

    def create_quarantine_section(self, parent, row):
        row = self.create_section_label(parent, "--- QUARANTINE ---", row)
        self.create_button(parent, "Check Quarantine", self.check_quarantine, row, 0, "#c41230")
        self.create_button(parent, "Release ALL", self.release_all, row, 1, "#009600")
        self.create_button(parent, "Release Kevin+Matt", self.release_kevin_matt, row, 2, "#006400", width=18)
        return row + 1

    def create_diagnostics_section(self, parent, row):
        row = self.create_section_label(parent, "--- DIAGNOSTICS ---", row)
        self.create_button(parent, "Msg Trace (4hr)", self.message_trace_4h, row, 0, "#505050")
        self.create_button(parent, "Msg Trace (24hr)", self.message_trace_24h, row, 1, "#505050")
        self.create_button(parent, "Check Safe Senders", self.check_safe_senders, row, 2, "#966400", width=18)
        self.create_button(parent, "Add Safe Sender", self.add_safe_sender, row, 3, "#0064b4")
        return row + 1

    def create_policies_section(self, parent, row):
        row = self.create_section_label(parent, "--- POLICIES & RULES ---", row)
        self.create_button(parent, "Transport Rules", self.check_transport_rules, row, 0, "#505050")
        self.create_button(parent, "Allow List", self.check_allow_list, row, 1, "#505050")
        self.create_button(parent, "Anti-Spam Policy", self.check_antispam, row, 2, "#505050")
        self.create_button(parent, "Anti-Phish Policy", self.check_antiphish, row, 3, "#505050")
        self.create_button(parent, "Compare Users", self.compare_users, row, 4, "#966400")
        return row + 1

    def create_overrides_section(self, parent, row):
        row = self.create_section_label(parent, "--- ALLOW LIST & OVERRIDES ---", row)
        self.create_button(parent, "Add to Allow List", self.add_to_allow_list, row, 0, "#0064b4")
        self.create_button(parent, "Allow Domain", self.allow_domain, row, 1, "#0064b4")
        self.create_button(parent, "Phish Sim Override", self.setup_phish_override, row, 2, "#0064b4")
        self.create_button(parent, "Check Override", self.check_override_status, row, 3, "#505050")
        self.create_button(parent, "Connection Filter", self.check_connection_filter, row, 4, "#505050")
        return row + 1

    def create_gophish_section(self, parent, row):
        row = self.create_section_label(parent, "--- GOPHISH CAMPAIGNS ---", row)
        self.create_button(parent, "Campaign Status", self.campaign_status, row, 0, "#643296")
        self.create_button(parent, "Latest Results", self.latest_results, row, 1, "#643296")
        self.create_button(parent, "New Campaign (All)", self.new_campaign_all, row, 2, "#009600", width=18)
        self.create_button(parent, "Test (Peter Only)", self.test_peter_only, row, 3, "#006400")
        self.create_button(parent, "View Templates", self.view_templates, row, 4, "#505050")
        self.create_button(parent, "SMTP Settings", self.smtp_settings, row, 5, "#505050")
        return row + 1

    def create_group_export_section(self, parent, row):
        row = self.create_section_label(parent, "--- M365 GROUP EXPORT (for GoPhish) ---", row)
        self.create_button(parent, "List M365 Groups", self.list_m365_groups, row, 0, "#0078d4")
        self.create_button(parent, "Export Group CSV", self.export_group_csv, row, 1, "#009600")
        self.create_button(parent, "Import to GoPhish", self.import_to_gophish, row, 2, "#643296", width=18)
        self.create_button(parent, "View GoPhish Groups", self.view_gophish_groups, row, 3, "#505050", width=18)
        return row + 1

    def create_tunnel_section(self, parent, row):
        row = self.create_section_label(parent, "--- TUNNEL & DNS ---", row)
        self.create_button(parent, "Start Tunnel", self.start_tunnel, row, 0, "#643296")
        self.create_button(parent, "Check Tunnel", self.check_tunnel, row, 1, "#505050")
        self.create_button(parent, "Check DNS", self.check_dns, row, 2, "#505050")
        self.create_button(parent, "Set Tunnel URL", self.set_tunnel_url, row, 3, "#505050")
        self.create_button(parent, "My Public IP", self.check_public_ip, row, 4, "#505050")
        return row + 1

    # --- Helper Methods ---

    def log(self, text):
        self.output.insert(tk.END, f"{text}\n")
        self.output.see(tk.END)
        self.root.update()

    def clear_output(self):
        self.output.delete(1.0, tk.END)

    def run_pwsh(self, script, callback=None):
        """Run PowerShell command in background thread"""
        def run():
            try:
                result = subprocess.run(
                    ["pwsh", "-NoProfile", "-Command", script],
                    capture_output=True,
                    text=True,
                    timeout=120
                )
                output = result.stdout + result.stderr
                # Filter out common warnings
                lines = [l for l in output.split('\n') if 'WARNING: The version' not in l]
                output = '\n'.join(lines)
                self.root.after(0, lambda: self.log(output.strip()))
                if callback:
                    self.root.after(0, callback)
            except subprocess.TimeoutExpired:
                self.root.after(0, lambda: self.log("[ERROR] Command timed out"))
            except Exception as e:
                self.root.after(0, lambda: self.log(f"[ERROR] {e}"))

        threading.Thread(target=run, daemon=True).start()

    def gophish_api(self, method, endpoint, data=None):
        """Call GoPhish API"""
        url = f"{CONFIG['gophish_api']}/{endpoint}"
        body = json.dumps(data).encode() if data else None

        req = urllib.request.Request(
            url,
            data=body,
            method=method,
            headers={
                "Authorization": f"Bearer {CONFIG['gophish_key']}",
                "Content-Type": "application/json",
            }
        )

        try:
            with urllib.request.urlopen(req, context=SSL_CTX, timeout=30) as resp:
                return json.loads(resp.read())
        except urllib.error.URLError as e:
            raise Exception(f"GoPhish API error: {e}")

    # --- Exchange Online Methods ---

    def connect_exchange(self):
        if self.exchange_connected:
            self.log("[!] Already connected")
            return

        self.log("\n--- CONNECTING TO EXCHANGE ONLINE ---")
        self.log("Browser will open for authentication...")

        script = """
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -ShowBanner:$false
Write-Host "[OK] Connected to Exchange Online"
"""
        def on_connected():
            self.exchange_connected = True
            self.status_label.configure(text="Exchange: Connected", fg="lime green")

        self.run_pwsh(script, on_connected)

    def disconnect_exchange(self):
        self.log("\n--- DISCONNECTING ---")
        script = "Disconnect-ExchangeOnline -Confirm:$false; Write-Host '[OK] Disconnected'"

        def on_disconnected():
            self.exchange_connected = False
            self.status_label.configure(text="Exchange: Not Connected", fg="yellow")

        self.run_pwsh(script, on_disconnected)

    def require_exchange(self):
        if not self.exchange_connected:
            self.log("[!] Connect to Exchange Online first")
            return False
        return True

    # --- Quarantine Methods ---

    def check_quarantine(self):
        if not self.require_exchange():
            return
        self.log("\n--- QUARANTINE CHECK ---")
        script = f"""
$q = Get-QuarantineMessage -SenderAddress '{CONFIG["sender"]}' -StartReceivedDate (Get-Date).AddDays(-7)
if ($q) {{
    Write-Host "Found $($q.Count) quarantined message(s):"
    foreach ($msg in $q) {{
        Write-Host "  To: $($msg.RecipientAddress) | Type: $($msg.Type) | $($msg.ReceivedTime)"
    }}
}} else {{ Write-Host "No quarantined messages from {CONFIG['sender']}" }}
"""
        self.run_pwsh(script)

    def release_all(self):
        if not self.require_exchange():
            return
        self.log("\n--- RELEASING ALL QUARANTINED MESSAGES ---")
        script = f"""
$q = Get-QuarantineMessage -SenderAddress '{CONFIG["sender"]}' -StartReceivedDate (Get-Date).AddDays(-7)
if ($q) {{
    foreach ($msg in $q) {{
        $msg | Release-QuarantineMessage -ReleaseToAll -Force -ErrorAction SilentlyContinue
    }}
    Write-Host "[OK] Released $($q.Count) message(s)"
}} else {{ Write-Host "No messages to release" }}
"""
        self.run_pwsh(script)

    def release_kevin_matt(self):
        if not self.require_exchange():
            return
        self.log("\n--- RELEASING FOR KEVIN + MATT ---")
        script = f"""
$q = Get-QuarantineMessage -SenderAddress '{CONFIG["sender"]}' -StartReceivedDate (Get-Date).AddDays(-7)
$tgt = @("kmarchese@equippers.com", "mfrank@equippers.com")
$released = 0
foreach ($msg in $q) {{
    if ($msg.RecipientAddress -in $tgt) {{
        $msg | Release-QuarantineMessage -ReleaseToAll -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] Released: $($msg.RecipientAddress)"
        $released++
    }}
}}
if ($released -eq 0) {{ Write-Host "No messages found for Kevin or Matt" }}
"""
        self.run_pwsh(script)

    # --- Diagnostics Methods ---

    def message_trace_4h(self):
        if not self.require_exchange():
            return
        self.log("\n--- MESSAGE TRACE (Last 4 hours) ---")
        script = f"""
$t = Get-MessageTrace -SenderAddress '{CONFIG["sender"]}' -StartDate (Get-Date).AddHours(-4) -EndDate (Get-Date) -ErrorAction SilentlyContinue
if ($t) {{
    Write-Host "Found $($t.Count) message(s):"
    foreach ($m in $t) {{ Write-Host "  $($m.RecipientAddress) | Status: $($m.Status) | $($m.Received)" }}
}} else {{ Write-Host "No messages found in trace" }}
"""
        self.run_pwsh(script)

    def message_trace_24h(self):
        if not self.require_exchange():
            return
        self.log("\n--- MESSAGE TRACE (Last 24 hours) ---")
        script = f"""
$t = Get-MessageTrace -SenderAddress '{CONFIG["sender"]}' -StartDate (Get-Date).AddHours(-24) -EndDate (Get-Date) -ErrorAction SilentlyContinue
if ($t) {{
    Write-Host "Found $($t.Count) message(s):"
    foreach ($m in $t) {{ Write-Host "  $($m.RecipientAddress) | Status: $($m.Status) | $($m.Received)" }}
}} else {{ Write-Host "No messages found in trace" }}
"""
        self.run_pwsh(script)

    def check_safe_senders(self):
        if not self.require_exchange():
            return
        self.log("\n--- JUNK EMAIL / SAFE SENDERS CONFIG ---")
        script = """
$users = @("pblanco@equippers.com", "kmarchese@equippers.com", "mfrank@equippers.com")
foreach ($u in $users) {
    try {
        $j = Get-MailboxJunkEmailConfiguration -Identity $u -ErrorAction Stop
        Write-Host "`n  $u"
        Write-Host "    Enabled: $($j.Enabled)"
        $trusted = $j.TrustedSendersAndDomains | Where-Object { $_ }
        if ($trusted) { Write-Host "    TrustedSenders: $($trusted -join ', ')" }
        else { Write-Host "    TrustedSenders: (none)" }
    } catch { Write-Host "  $u - [ERROR] $_" }
}
"""
        self.run_pwsh(script)

    def add_safe_sender(self):
        if not self.require_exchange():
            return
        self.log(f"\n--- ADDING {CONFIG['domain']} AS SAFE SENDER ---")
        script = f"""
$users = @("pblanco@equippers.com", "kmarchese@equippers.com", "mfrank@equippers.com")
foreach ($u in $users) {{
    try {{
        $j = Get-MailboxJunkEmailConfiguration -Identity $u
        $current = @($j.TrustedSendersAndDomains | Where-Object {{ $_ }})
        if ('{CONFIG["domain"]}' -notin $current) {{
            $current += '{CONFIG["domain"]}'
            Set-MailboxJunkEmailConfiguration -Identity $u -TrustedSendersAndDomains $current
            Write-Host "[OK] Added {CONFIG['domain']} for $u"
        }} else {{ Write-Host "[OK] {CONFIG['domain']} already trusted for $u" }}
    }} catch {{ Write-Host "[ERROR] $u - $_" }}
}}
"""
        self.run_pwsh(script)

    # --- Policies Methods ---

    def check_transport_rules(self):
        if not self.require_exchange():
            return
        self.log("\n--- TRANSPORT RULES ---")
        script = f"""
$rules = Get-TransportRule | Where-Object {{ $_.State -eq "Enabled" }}
$relevant = $rules | Where-Object {{ $_.SenderDomainIs -contains '{CONFIG["domain"]}' -or $_.Name -match "phish|blancoitservices|whitelist|bypass" }}
if ($relevant) {{
    foreach ($r in $relevant) {{
        Write-Host "  Rule: $($r.Name) | Priority: $($r.Priority) | SCL: $($r.SetSCL)"
    }}
}} else {{ Write-Host "No relevant transport rules found" }}
Write-Host "Total enabled rules: $($rules.Count)"
"""
        self.run_pwsh(script)

    def check_allow_list(self):
        if not self.require_exchange():
            return
        self.log("\n--- TENANT ALLOW/BLOCK LIST ---")
        script = """
$allows = Get-TenantAllowBlockListItems -ListType Sender -Allow -ErrorAction SilentlyContinue
if ($allows) {
    foreach ($a in $allows) { Write-Host "  ALLOW: $($a.Value) | Expires: $($a.ExpirationDate)" }
} else { Write-Host "  No allowed senders" }
"""
        self.run_pwsh(script)

    def check_antispam(self):
        if not self.require_exchange():
            return
        self.log("\n--- ANTI-SPAM POLICIES ---")
        script = """
$policies = Get-HostedContentFilterPolicy
foreach ($p in $policies) {
    Write-Host "  Policy: $($p.Name)"
    Write-Host "    HighConfPhish: $($p.HighConfidencePhishAction) | Phish: $($p.PhishSpamAction)"
    Write-Host "    AllowedDomains: $($p.AllowedSenderDomains -join ', ')"
}
"""
        self.run_pwsh(script)

    def check_antiphish(self):
        if not self.require_exchange():
            return
        self.log("\n--- ANTI-PHISHING POLICIES ---")
        script = """
$policies = Get-AntiPhishPolicy
foreach ($p in $policies) {
    Write-Host "  Policy: $($p.Name) | Enabled: $($p.Enabled)"
    Write-Host "    PhishThreshold: $($p.PhishThresholdLevel) | Spoof: $($p.EnableSpoofIntelligence)"
}
"""
        self.run_pwsh(script)

    def compare_users(self):
        if not self.require_exchange():
            return
        self.log("\n--- COMPARING USER POLICIES ---")
        script = """
$users = @("pblanco@equippers.com", "kmarchese@equippers.com", "mfrank@equippers.com")
foreach ($u in $users) {
    Write-Host "`n  $u"
    try {
        $rules = Get-HostedContentFilterRule -ErrorAction SilentlyContinue
        foreach ($r in $rules) {
            if ($r.SentTo -contains $u -or $r.RecipientDomainIs -contains "equippers.com") {
                Write-Host "    SpamRule: $($r.Name)"
            }
        }
    } catch {}
    Write-Host "    (Default policies apply if no rules shown)"
}
"""
        self.run_pwsh(script)

    # --- Override Methods ---

    def add_to_allow_list(self):
        if not self.require_exchange():
            return
        self.log("\n--- ADDING TO ALLOW LIST ---")
        script = f"""
try {{
    New-TenantAllowBlockListItems -ListType Sender -Entries '{CONFIG["sender"]}' -Allow -NoExpiration -ErrorAction Stop
    Write-Host "[OK] Added {CONFIG['sender']}"
}} catch {{
    if ($_.Exception.Message -match "already exists") {{ Write-Host "[OK] {CONFIG['sender']} already allowed" }}
    else {{ Write-Host "[ERROR] $_" }}
}}
"""
        self.run_pwsh(script)

    def allow_domain(self):
        if not self.require_exchange():
            return
        self.log("\n--- ADDING DOMAIN TO ALLOW LIST ---")
        script = f"""
try {{
    New-TenantAllowBlockListItems -ListType Sender -Entries '{CONFIG["domain"]}' -Allow -NoExpiration -ErrorAction Stop
    Write-Host "[OK] Added domain {CONFIG['domain']}"
}} catch {{
    if ($_.Exception.Message -match "already exists") {{ Write-Host "[OK] {CONFIG['domain']} already allowed" }}
    else {{ Write-Host "[ERROR] $_" }}
}}
"""
        self.run_pwsh(script)

    def setup_phish_override(self):
        if not self.require_exchange():
            return
        self.log("\n--- ADVANCED DELIVERY - PHISH SIM OVERRIDE ---")
        script = f"""
try {{
    $existing = Get-PhishSimOverridePolicy -ErrorAction SilentlyContinue
    if (-not $existing) {{
        New-PhishSimOverridePolicy -Name "PhishSimOverridePolicy" -ErrorAction Stop
        Write-Host "[OK] Created PhishSimOverridePolicy"
    }}
    $rule = Get-PhishSimOverrideRule -ErrorAction SilentlyContinue
    if ($rule) {{
        Set-PhishSimOverrideRule -Identity $rule.Name -SenderDomainIs '{CONFIG["domain"]}' -SenderIpRanges '{CONFIG["home_ip"]}'
        Write-Host "[OK] Updated override rule"
    }} else {{
        New-PhishSimOverrideRule -Name "PhishSimOverrideRule" -Policy "PhishSimOverridePolicy" -SenderDomainIs '{CONFIG["domain"]}' -SenderIpRanges '{CONFIG["home_ip"]}'
        Write-Host "[OK] Created override rule for {CONFIG['domain']} from {CONFIG['home_ip']}"
    }}
    Write-Host "[OK] Phish simulation override active"
}} catch {{ Write-Host "[ERROR] $_" }}
"""
        self.run_pwsh(script)

    def check_override_status(self):
        if not self.require_exchange():
            return
        self.log("\n--- PHISH SIM OVERRIDE STATUS ---")
        script = """
$p = Get-PhishSimOverridePolicy -ErrorAction SilentlyContinue
if ($p) {
    Write-Host "  Policy: $($p.Name) | Enabled: $($p.Enabled)"
    $r = Get-PhishSimOverrideRule -ErrorAction SilentlyContinue
    if ($r) {
        Write-Host "  Rule: $($r.Name)"
        Write-Host "  Domains: $($r.SenderDomainIs -join ', ')"
        Write-Host "  IPs: $($r.SenderIpRanges -join ', ')"
    } else { Write-Host "  No override rule found" }
} else { Write-Host "  No PhishSimOverridePolicy exists" }
"""
        self.run_pwsh(script)

    def check_connection_filter(self):
        if not self.require_exchange():
            return
        self.log("\n--- CONNECTION FILTER (IP Allow) ---")
        script = """
$cf = Get-HostedConnectionFilterPolicy
Write-Host "  Policy: $($cf.Name)"
Write-Host "  IP Allow List: $($cf.IPAllowList -join ', ')"
Write-Host "  IP Block List: $($cf.IPBlockList -join ', ')"
"""
        self.run_pwsh(script)

    # --- GoPhish Methods ---

    def campaign_status(self):
        self.log("\n--- GOPHISH CAMPAIGNS ---")
        try:
            campaigns = self.gophish_api("GET", "campaigns/")
            if campaigns:
                for c in campaigns[-5:]:
                    self.log(f"  #{c['id']}: {c['name']} | Status: {c['status']}")
                    results = c.get('results', [])
                    sent = len([r for r in results if r.get('status')])
                    clicked = len([r for r in results if r.get('status') in ['Clicked Link', 'Submitted Data']])
                    submitted = len([r for r in results if r.get('status') == 'Submitted Data'])
                    self.log(f"    Sent: {sent} | Clicked: {clicked} | Submitted: {submitted}")
            else:
                self.log("No campaigns found")
        except Exception as e:
            self.log(f"[ERROR] {e}")

    def latest_results(self):
        self.log("\n--- LATEST CAMPAIGN RESULTS ---")
        try:
            campaigns = self.gophish_api("GET", "campaigns/")
            if campaigns:
                latest = campaigns[-1]
                self.log(f"Campaign: {latest['name']} (#{latest['id']})")
                for r in latest.get('results', []):
                    self.log(f"  {r['email']} | Status: {r['status']} | IP: {r.get('ip', 'N/A')}")
                if not latest.get('results'):
                    self.log("  No results yet")
        except Exception as e:
            self.log(f"[ERROR] {e}")

    def new_campaign_all(self):
        self.log("\n--- LAUNCHING NEW CAMPAIGN (ALL TARGETS) ---")
        try:
            # Update group
            self.gophish_api("PUT", "groups/1", {
                "id": 1,
                "name": "Test Campaign",
                "targets": CONFIG["targets"]
            })
            self.log(f"Updated group with {len(CONFIG['targets'])} targets")

            url = self.tunnel_url or "https://example.trycloudflare.com"
            if url == "https://example.trycloudflare.com":
                self.log("[WARN] No tunnel URL set - use 'Set Tunnel URL' first")

            result = self.gophish_api("POST", "campaigns/", {
                "name": f"Campaign - {datetime.now().strftime('%m%d-%H%M')}",
                "template": {"name": "M365 Password Expiration"},
                "page": {"name": "M365 Password Reset"},
                "smtp": {"name": "Google SMTP Relay"},
                "url": url,
                "groups": [{"name": "Test Campaign"}]
            })
            self.log(f"[OK] Campaign #{result['id']} launched")
            self.log(f"URL: {url}")
        except Exception as e:
            self.log(f"[ERROR] {e}")

    def test_peter_only(self):
        self.log("\n--- TEST CAMPAIGN (PETER ONLY) ---")
        try:
            self.gophish_api("PUT", "groups/1", {
                "id": 1,
                "name": "Test Campaign",
                "targets": [CONFIG["targets"][0]]
            })

            url = self.tunnel_url or "https://example.trycloudflare.com"

            result = self.gophish_api("POST", "campaigns/", {
                "name": f"Peter Test - {datetime.now().strftime('%m%d-%H%M')}",
                "template": {"name": "M365 Password Expiration"},
                "page": {"name": "M365 Password Reset"},
                "smtp": {"name": "Google SMTP Relay"},
                "url": url,
                "groups": [{"name": "Test Campaign"}]
            })
            self.log(f"[OK] Test campaign #{result['id']} sent to pblanco@equippers.com")
        except Exception as e:
            self.log(f"[ERROR] {e}")

    def view_templates(self):
        self.log("\n--- GOPHISH TEMPLATES ---")
        try:
            templates = self.gophish_api("GET", "templates/")
            for t in templates:
                self.log(f"  {t['id']}: {t['name']}")

            self.log("\n--- LANDING PAGES ---")
            pages = self.gophish_api("GET", "pages/")
            for p in pages:
                self.log(f"  {p['id']}: {p['name']}")

            self.log("\n--- SENDING PROFILES ---")
            smtp = self.gophish_api("GET", "smtp/")
            for s in smtp:
                self.log(f"  {s['id']}: {s['name']} | From: {s['from_address']}")
        except Exception as e:
            self.log(f"[ERROR] {e}")

    def smtp_settings(self):
        self.log("\n--- GOPHISH SMTP PROFILES ---")
        try:
            smtp = self.gophish_api("GET", "smtp/")
            for s in smtp:
                self.log(f"  Profile: {s['name']} (#{s['id']})")
                self.log(f"    From: {s['from_address']}")
                self.log(f"    Host: {s['host']}")
                self.log(f"    IgnoreCert: {s['ignore_cert_errors']}")
        except Exception as e:
            self.log(f"[ERROR] {e}")

    # --- Group Export Methods ---

    def list_m365_groups(self):
        if not self.require_exchange():
            return
        self.log("\n--- M365 DISTRIBUTION GROUPS & MAIL-ENABLED GROUPS ---")
        self.log("Connecting and fetching groups...")
        script = """
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -ShowBanner:$false

# Get Distribution Groups
Write-Host "DISTRIBUTION GROUPS:"
$dgs = Get-DistributionGroup -ResultSize 50 -ErrorAction SilentlyContinue
foreach ($dg in $dgs) {
    $count = (Get-DistributionGroupMember -Identity $dg.Identity -ErrorAction SilentlyContinue).Count
    Write-Host "  $($dg.Name) | $($dg.PrimarySmtpAddress) | Members: $count"
}

# Get Microsoft 365 Groups (Unified Groups)
Write-Host "`nMICROSOFT 365 GROUPS:"
$m365 = Get-UnifiedGroup -ResultSize 50 -ErrorAction SilentlyContinue
foreach ($g in $m365) {
    Write-Host "  $($g.DisplayName) | $($g.PrimarySmtpAddress)"
}

Disconnect-ExchangeOnline -Confirm:$false
"""
        self.run_pwsh(script)

    def export_group_csv(self):
        if not self.require_exchange():
            return

        group_name = simpledialog.askstring("Export Group", "Enter the group name or email address:")
        if not group_name:
            return

        self.log(f"\n--- EXPORTING GROUP: {group_name} ---")
        self.log("Connecting and fetching members...")

        # Store group name for later use
        self.last_exported_group = group_name

        script = f"""
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -ShowBanner:$false

$groupName = '{group_name}'
$outputFile = '/tmp/gophish-group-export.csv'

# Try Distribution Group first
$members = $null
try {{
    $members = Get-DistributionGroupMember -Identity $groupName -ErrorAction Stop |
        Where-Object {{ $_.RecipientType -eq 'UserMailbox' -or $_.RecipientType -eq 'MailUser' }}
    Write-Host "Found Distribution Group"
}} catch {{
    # Try Unified Group (M365 Group)
    try {{
        $groupLinks = Get-UnifiedGroupLinks -Identity $groupName -LinkType Members -ErrorAction Stop
        $members = @()
        foreach ($link in $groupLinks) {{
            $user = Get-User -Identity $link.PrimarySmtpAddress -ErrorAction SilentlyContinue
            if ($user) {{ $members += $user }}
        }}
        Write-Host "Found Microsoft 365 Group"
    }} catch {{
        Write-Host "[ERROR] Could not find group: $groupName"
        Disconnect-ExchangeOnline -Confirm:$false
        exit
    }}
}}

if ($members -and $members.Count -gt 0) {{
    Write-Host "Found $($members.Count) members"
    Write-Host ""
    Write-Host "email,first_name,last_name,position"

    $csvContent = "email,first_name,last_name,position`n"
    foreach ($m in $members) {{
        $email = $m.PrimarySmtpAddress
        if (-not $email) {{ $email = $m.WindowsEmailAddress }}
        if (-not $email) {{ continue }}

        $firstName = if ($m.FirstName) {{ $m.FirstName }} else {{ "" }}
        $lastName = if ($m.LastName) {{ $m.LastName }} else {{ "" }}
        $title = if ($m.Title) {{ $m.Title }} else {{ "Staff" }}

        Write-Host "$email,$firstName,$lastName,$title"
        $csvContent += "$email,$firstName,$lastName,$title`n"
    }}

    # Save to file
    $csvContent | Out-File -FilePath $outputFile -Encoding UTF8 -NoNewline
    Write-Host ""
    Write-Host "[OK] Exported to: $outputFile"
    Write-Host "[OK] Ready to import to GoPhish"
}} else {{
    Write-Host "[ERROR] No members found in group"
}}

Disconnect-ExchangeOnline -Confirm:$false
"""
        self.run_pwsh(script)

    def import_to_gophish(self):
        csv_file = "/tmp/gophish-group-export.csv"

        # Check if export file exists
        if not os.path.exists(csv_file):
            self.log("[ERROR] No export file found. Run 'Export Group CSV' first.")
            return

        group_name = simpledialog.askstring("Import to GoPhish",
            "Enter name for the new GoPhish group:",
            initialvalue=getattr(self, 'last_exported_group', 'Imported Group'))
        if not group_name:
            return

        self.log(f"\n--- IMPORTING TO GOPHISH: {group_name} ---")

        try:
            # Read CSV
            targets = []
            with open(csv_file, 'r') as f:
                lines = f.readlines()

            # Skip header
            for line in lines[1:]:
                line = line.strip()
                if not line:
                    continue
                parts = line.split(',')
                if len(parts) >= 4:
                    targets.append({
                        "email": parts[0].strip(),
                        "first_name": parts[1].strip(),
                        "last_name": parts[2].strip(),
                        "position": parts[3].strip()
                    })

            if not targets:
                self.log("[ERROR] No valid targets found in CSV")
                return

            self.log(f"Found {len(targets)} targets")

            # Create group in GoPhish
            result = self.gophish_api("POST", "groups/", {
                "name": group_name,
                "targets": targets
            })

            self.log(f"[OK] Created GoPhish group: {group_name} (ID: {result['id']})")
            self.log(f"[OK] {len(targets)} members imported")

            # Show first few
            for t in targets[:5]:
                self.log(f"  - {t['email']} ({t['first_name']} {t['last_name']})")
            if len(targets) > 5:
                self.log(f"  ... and {len(targets) - 5} more")

        except Exception as e:
            self.log(f"[ERROR] {e}")

    def view_gophish_groups(self):
        self.log("\n--- GOPHISH GROUPS ---")
        try:
            groups = self.gophish_api("GET", "groups/")
            if groups:
                for g in groups:
                    self.log(f"\n  Group: {g['name']} (ID: {g['id']})")
                    self.log(f"  Members: {len(g.get('targets', []))}")
                    for t in g.get('targets', [])[:5]:
                        self.log(f"    - {t['email']} ({t.get('first_name', '')} {t.get('last_name', '')})")
                    if len(g.get('targets', [])) > 5:
                        self.log(f"    ... and {len(g['targets']) - 5} more")
            else:
                self.log("No groups found")
        except Exception as e:
            self.log(f"[ERROR] {e}")

    # --- Tunnel Methods ---

    def start_tunnel(self):
        self.log("\n--- STARTING CLOUDFLARE TUNNEL ---")

        def run_tunnel():
            try:
                process = subprocess.Popen(
                    ["cloudflared", "tunnel", "--url", "http://localhost:80"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True
                )

                for line in process.stdout:
                    self.root.after(0, lambda l=line: self.log(l.strip()))
                    match = re.search(r'https://[a-z0-9-]+\.trycloudflare\.com', line)
                    if match:
                        self.tunnel_url = match.group(0)
                        self.root.after(0, lambda: self.log(f"\n[OK] Tunnel URL captured: {self.tunnel_url}"))
                        break

            except Exception as e:
                self.root.after(0, lambda: self.log(f"[ERROR] {e}"))

        threading.Thread(target=run_tunnel, daemon=True).start()

    def check_tunnel(self):
        self.log("\n--- CHECKING TUNNEL STATUS ---")

        # Check cloudflared
        result = subprocess.run(["pgrep", "-f", "cloudflared"], capture_output=True)
        if result.returncode == 0:
            self.log("[OK] cloudflared is running")
        else:
            self.log("[!] cloudflared is NOT running")

        # Check Docker
        result = subprocess.run(["docker", "ps", "--filter", "name=gophish", "--format", "{{.Status}}"],
                              capture_output=True, text=True)
        if "Up" in result.stdout:
            self.log(f"[OK] GoPhish container: {result.stdout.strip()}")
        else:
            self.log("[!] GoPhish container is NOT running")

        if self.tunnel_url:
            self.log(f"Current tunnel URL: {self.tunnel_url}")
        else:
            self.log("No tunnel URL set")

    def check_dns(self):
        self.log(f"\n--- DNS CHECK FOR {CONFIG['domain']} ---")

        def run_dns():
            for record in ["TXT", "MX"]:
                try:
                    result = subprocess.run(
                        ["dig", "+short", record, CONFIG["domain"]],
                        capture_output=True, text=True, timeout=10
                    )
                    self.root.after(0, lambda r=record, o=result.stdout: self.log(f"{r}: {o.strip() or '(none)'}"))
                except Exception as e:
                    self.root.after(0, lambda: self.log(f"[ERROR] {e}"))

        threading.Thread(target=run_dns, daemon=True).start()

    def set_tunnel_url(self):
        url = simpledialog.askstring("Tunnel URL", "Enter Cloudflare tunnel URL:", initialvalue=self.tunnel_url)
        if url:
            self.tunnel_url = url
            self.log(f"[OK] Tunnel URL set to: {url}")

    def check_public_ip(self):
        self.log("\n--- PUBLIC IP CHECK ---")
        def run():
            try:
                result = subprocess.run(["curl", "-s", "ifconfig.me"], capture_output=True, text=True, timeout=10)
                ip = result.stdout.strip()
                self.root.after(0, lambda: self.log(f"Your public IP: {ip}"))
                self.root.after(0, lambda: self.log(f"Whitelisted IP: {CONFIG['home_ip']}"))
                if ip == CONFIG['home_ip']:
                    self.root.after(0, lambda: self.log("[OK] IP matches whitelist"))
                else:
                    self.root.after(0, lambda: self.log("[WARN] IP does NOT match whitelist - update Google SMTP Relay"))
            except Exception as e:
                self.root.after(0, lambda: self.log(f"[ERROR] {e}"))

        threading.Thread(target=run, daemon=True).start()


def main():
    root = tk.Tk()
    app = EmailAdminGUI(root)
    root.mainloop()


if __name__ == "__main__":
    main()
