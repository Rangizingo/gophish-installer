#!/usr/bin/env python3
"""Send GoPhish campaign report via email."""

import json
import smtplib
import ssl
import urllib.request
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from datetime import datetime

# Config
API_KEY = "7153200e91ffd8350832edda65ef5d261ce20c7a9de3e2147ea4cc87930a0919"
GOPHISH_URL = "https://localhost:3333/api"
SMTP_HOST = "smtp-relay.gmail.com"
SMTP_PORT = 587
FROM_EMAIL = "itsupport@blancoitservices.net"
TO_EMAIL = "pblanco@equippers.com"

# Disable SSL verification for localhost
ssl_context = ssl.create_default_context()
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_NONE

def api_get(endpoint):
    """Make GET request to GoPhish API."""
    req = urllib.request.Request(
        f"{GOPHISH_URL}/{endpoint}",
        headers={"Authorization": f"Bearer {API_KEY}"}
    )
    with urllib.request.urlopen(req, context=ssl_context) as resp:
        return json.loads(resp.read().decode())

def get_latest_campaign():
    """Get the most recent campaign with results."""
    summary = api_get("campaigns/summary")
    campaigns = summary.get("campaigns", summary)
    if not campaigns:
        return None
    latest = max(campaigns, key=lambda x: x.get("id", 0))
    return api_get(f"campaigns/{latest['id']}/results")

def format_report(campaign):
    """Format campaign data as HTML report."""
    results = campaign.get("results", [])
    timeline = campaign.get("timeline", [])

    # Count stats
    stats = {"sent": 0, "opened": 0, "clicked": 0, "submitted": 0}
    for r in results:
        status = r.get("status", "").lower()
        stats["sent"] += 1
        if "opened" in status or "clicked" in status or "submitted" in status:
            stats["opened"] += 1
        if "clicked" in status or "submitted" in status:
            stats["clicked"] += 1
        if "submitted" in status:
            stats["submitted"] += 1

    # Build HTML
    html = f"""
    <html>
    <head>
        <style>
            body {{ font-family: 'Segoe UI', Arial, sans-serif; background: #1a1a1a; color: #e0e0e0; padding: 20px; }}
            .container {{ max-width: 700px; margin: 0 auto; background: #2d2d2d; border-radius: 8px; padding: 25px; }}
            h1 {{ color: #c41230; margin-bottom: 5px; }}
            h2 {{ color: #c41230; border-bottom: 1px solid #444; padding-bottom: 8px; }}
            .subtitle {{ color: #888; margin-bottom: 20px; }}
            .stats {{ display: flex; gap: 15px; margin: 20px 0; }}
            .stat {{ background: #3d3d3d; padding: 15px 20px; border-radius: 6px; text-align: center; flex: 1; }}
            .stat-value {{ font-size: 28px; font-weight: bold; color: #fff; }}
            .stat-label {{ font-size: 12px; color: #888; text-transform: uppercase; }}
            table {{ width: 100%; border-collapse: collapse; margin: 15px 0; }}
            th {{ background: #3d3d3d; color: #c41230; text-align: left; padding: 10px; }}
            td {{ padding: 10px; border-bottom: 1px solid #444; }}
            tr:hover {{ background: #353535; }}
            .success {{ color: #4caf50; }}
            .warning {{ color: #ff9800; }}
            .danger {{ color: #c41230; }}
            .footer {{ margin-top: 25px; padding-top: 15px; border-top: 1px solid #444; color: #666; font-size: 12px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Phishing Campaign Report</h1>
            <div class="subtitle">{campaign.get('name', 'Unknown Campaign')}</div>

            <div class="stats">
                <div class="stat">
                    <div class="stat-value">{stats['sent']}</div>
                    <div class="stat-label">Sent</div>
                </div>
                <div class="stat">
                    <div class="stat-value">{stats['opened']}</div>
                    <div class="stat-label">Opened</div>
                </div>
                <div class="stat">
                    <div class="stat-value">{stats['clicked']}</div>
                    <div class="stat-label">Clicked</div>
                </div>
                <div class="stat">
                    <div class="stat-value danger">{stats['submitted']}</div>
                    <div class="stat-label">Credentials</div>
                </div>
            </div>

            <h2>Results by Recipient</h2>
            <table>
                <tr><th>Email</th><th>Status</th><th>IP Address</th></tr>
    """

    for r in results:
        status = r.get("status", "N/A")
        status_class = "danger" if "submitted" in status.lower() else ("warning" if "clicked" in status.lower() else "")
        html += f"""
                <tr>
                    <td>{r.get('email', 'N/A')}</td>
                    <td class="{status_class}">{status}</td>
                    <td>{r.get('ip', '-') or '-'}</td>
                </tr>
        """

    html += """
            </table>

            <h2>Event Timeline</h2>
            <table>
                <tr><th>Time</th><th>Event</th><th>Target</th></tr>
    """

    for e in timeline[-15:]:
        time_str = e.get("time", "")[:19].replace("T", " ")
        html += f"""
                <tr>
                    <td>{time_str}</td>
                    <td>{e.get('message', '')}</td>
                    <td>{e.get('email', '')}</td>
                </tr>
        """

    html += f"""
            </table>

            <div class="footer">
                Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}<br>
                Blanco IT Solutions - Security Awareness Program
            </div>
        </div>
    </body>
    </html>
    """
    return html

def send_email(subject, html_body):
    """Send email via Google SMTP relay."""
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = FROM_EMAIL
    msg["To"] = TO_EMAIL

    # Plain text fallback
    text = "View this email in HTML format for the full report."
    msg.attach(MIMEText(text, "plain"))
    msg.attach(MIMEText(html_body, "html"))

    # Send via SMTP relay (IP-based auth, no credentials needed)
    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
        server.starttls()
        server.sendmail(FROM_EMAIL, TO_EMAIL, msg.as_string())

    print(f"Report sent to {TO_EMAIL}")

def main():
    print("Fetching latest campaign data...")
    campaign = get_latest_campaign()
    if not campaign:
        print("No campaigns found!")
        return

    print(f"Generating report for: {campaign.get('name')}")
    html = format_report(campaign)

    subject = f"GoPhish Report: {campaign.get('name', 'Campaign Results')}"
    print(f"Sending to {TO_EMAIL}...")
    send_email(subject, html)

if __name__ == "__main__":
    main()
