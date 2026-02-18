# GoPhish Phishing Simulation Setup Guide

A simple guide to running phishing awareness tests for your organization.

---

## What This Does

This tool lets you send fake phishing emails to test if employees click suspicious links. When someone clicks the link and enters their password, you'll see it in a report. **No actual harm is done** - it's for training purposes.

**The flow:**
1. Employee receives a fake "password expiring" email
2. If they click the link, they see a fake login page
3. If they enter their password, it's captured for the report
4. They're redirected to your real SharePoint (looks like normal login)

---

## What You Need

| Item | Why |
|------|-----|
| A computer (Windows or Linux) | Runs the phishing server |
| Internet connection | Sends emails and hosts the fake login page |
| Admin access to your M365 tenant | To whitelist the test emails |
| Google Workspace SMTP Relay | To send emails (already configured) |

---

## Part 1: Installation

### Option A: Windows

1. **Open PowerShell as Administrator**
   - Press `Windows + X`
   - Click "Windows PowerShell (Admin)"

2. **Run the installer**
   ```powershell
   cd C:\path\to\gophish-installer
   .\install-gophish.ps1
   ```

3. **Wait for it to complete**
   - It will install Docker automatically
   - It will download GoPhish
   - It will show you the admin password

4. **Save the admin password** shown at the end

5. **Optional: Set up Cloudflare Tunnel** when prompted
   - This gives you a permanent URL like `https://phish.yourdomain.com`
   - Without it, you'll get random URLs that change each time

---

### Option B: Linux (Ubuntu/Pop!_OS)

1. **Open Terminal**

2. **Go to the installer folder**
   ```bash
   cd ~/Documents/AI/gophish-installer
   ```

3. **Run the installer**
   ```bash
   chmod +x install-gophish.sh
   ./install-gophish.sh
   ```

4. **If asked about Docker permissions**, run:
   ```bash
   sudo usermod -aG docker $USER
   ```
   Then log out and back in.

5. **Save the admin password** shown at the end

6. **Optional: Set up Cloudflare Tunnel** when prompted
   - This gives you a permanent URL like `https://phish.yourdomain.com`
   - Without it, you'll get random URLs that change each time

---

## Part 2: First-Time Login

1. **Open your web browser**

2. **Go to:** `https://localhost:3333`

3. **You'll see a security warning** - this is normal
   - Chrome: Click "Advanced" → "Proceed to localhost"
   - Firefox: Click "Advanced" → "Accept the Risk"

4. **Log in:**
   - Username: `admin`
   - Password: (the one from installation)

5. **Change your password** when prompted

---

## Part 3: Running the Admin Tool

The admin tool lets you manage everything from one window.

### Windows
```powershell
cd C:\path\to\gophish-installer
.\email-admin-gui.ps1
```

### Linux
```bash
cd ~/Documents/AI/gophish-installer
python3 email-admin-gui-linux.py
```

---

## Part 4: Understanding the Admin Tool

The tool has several sections:

### Exchange Online
| Button | What it does |
|--------|--------------|
| Connect Exchange | Connects to your M365 admin account |
| Disconnect | Disconnects when you're done |

### Quarantine
| Button | What it does |
|--------|--------------|
| Check Quarantine | See if test emails got blocked |
| Release ALL | Unblock all stuck test emails |

### M365 Group Export
| Button | What it does |
|--------|--------------|
| List M365 Groups | Shows all email groups in your organization |
| Export Group CSV | Saves group members to a file |
| Import to GoPhish | Creates a target list from the file |

### GoPhish Campaigns
| Button | What it does |
|--------|--------------|
| Campaign Status | See how many people clicked |
| Latest Results | See who clicked and entered passwords |
| New Campaign | Send test to everyone in a group |
| Test (Peter Only) | Send a test to yourself first |

### Tunnel & DNS
| Button | What it does |
|--------|--------------|
| Start Tunnel | Creates the link for the fake login page |
| Check Tunnel | Verify everything is running |

---

## Part 5: Running Your First Test

### Step 1: Connect to Exchange
1. Click **"Connect Exchange"**
2. A browser window opens - sign in with your M365 admin account
3. Wait for "Connected" to appear

### Step 2: Create a Target Group
1. Click **"List M365 Groups"** to see available groups
2. Click **"Export Group CSV"**
3. Type the group name (e.g., `IT Department`)
4. Click **"Import to GoPhish"**
5. Give it a name (e.g., `IT Team Test`)

### Step 3: Start the Tunnel
1. Click **"Start Tunnel"**
2. Wait for the URL to appear (looks like `https://random-words.trycloudflare.com`)
3. **Keep this window open** - closing it breaks the links

### Step 4: Test Yourself First
1. Click **"Test (Peter Only)"**
2. Check your email
3. Click the link to see the fake login page
4. Enter a fake password to test
5. Verify it redirects to SharePoint

### Step 5: Send to Everyone
1. Click **"New Campaign (All)"**
2. Emails are sent immediately
3. Watch the results come in

---

## Part 6: Viewing Results

### In the Admin Tool
- Click **"Campaign Status"** - shows click counts
- Click **"Latest Results"** - shows who did what

### In the Web Interface
1. Go to `https://localhost:3333`
2. Click **"Campaigns"** on the left
3. Click your campaign name
4. See the timeline of events

### What the statuses mean
| Status | Meaning |
|--------|---------|
| Email Sent | Email delivered successfully |
| Email Opened | They opened the email (not always accurate) |
| Clicked Link | They clicked the link |
| Submitted Data | **They entered their password** |

---

## Part 7: If Emails Get Blocked

Microsoft 365 may block test emails. Here's how to fix it:

### Quick Fix
1. Click **"Connect Exchange"** (if not connected)
2. Click **"Check Quarantine"**
3. If emails are stuck, click **"Release ALL"**

### Permanent Fix
1. Click **"Phish Sim Override"** - this tells M365 to allow test emails
2. Click **"Add to Allow List"** - adds the sender to safe list

---

## Part 8: Shutting Down

When you're done testing:

1. **Close the Admin Tool** window

2. **Stop the tunnel** (it stops when you close the tool)

3. **Stop GoPhish** (optional - it can keep running):
   ```bash
   # Linux
   docker stop gophish

   # Windows (PowerShell)
   docker stop gophish
   ```

4. **Disconnect from Exchange** (click the button or close the tool)

---

## Troubleshooting

### "Can't connect to localhost:3333"
**GoPhish isn't running.** Start it:
```bash
cd ~/gophish
docker compose up -d
```

### "Emails not arriving"
1. Check quarantine (click "Check Quarantine")
2. If stuck, click "Release ALL"
3. Wait 5-10 minutes - email can be slow

### "Link doesn't work"
The tunnel stopped. Click **"Start Tunnel"** again.
Note: This creates a NEW link - old emails won't work.

### "Can't connect to Exchange"
1. Make sure you're using an admin account
2. Check your internet connection
3. Try clicking "Connect Exchange" again

### "Docker not running" (Linux)
```bash
sudo systemctl start docker
```

### "Permission denied" (Linux)
```bash
sudo usermod -aG docker $USER
# Then log out and back in
```

---

## Quick Reference

### Start Everything (Linux)
```bash
cd ~/Documents/AI/gophish-installer

# 1. Make sure GoPhish is running
docker ps | grep gophish || cd ~/gophish && docker compose up -d && cd -

# 2. Open the admin tool
python3 email-admin-gui-linux.py
```

### Start Everything (Windows)
```powershell
cd C:\path\to\gophish-installer

# 1. Make sure Docker Desktop is running (check system tray)

# 2. Open the admin tool
.\email-admin-gui.ps1
```

### Key URLs
| What | URL |
|------|-----|
| GoPhish Admin | https://localhost:3333 |
| Landing Page | (shown when you start tunnel) |

### Key Files
| File | Purpose |
|------|---------|
| `install-gophish.sh` | Linux installer |
| `install-gophish.ps1` | Windows installer |
| `email-admin-gui-linux.py` | Linux admin tool |
| `email-admin-gui.ps1` | Windows admin tool |

### Cloudflare Tunnel Commands
```bash
# Set up tunnel later (if skipped during install)
./install-gophish.sh --tunnel     # Linux
.\install-gophish.ps1 -TunnelOnly # Windows

# Start your permanent tunnel
cloudflared tunnel run gophish

# Run tunnel in background (Linux)
cloudflared tunnel run gophish &
```

---

## Important Notes

1. **Always test yourself first** before sending to others

2. **Keep your computer on** while campaigns are active - the tunnel needs it

3. **Old links break** when you restart the tunnel (unless using a permanent Cloudflare Tunnel)

4. **Get permission** before testing - this should be approved by management

5. **Don't use for actual phishing** - this is for authorized security testing only

---

## Need Help?

- Check the [README.md](README.md) for more details
- Look at [PHISHING_CAMPAIGN_GUIDE.md](PHISHING_CAMPAIGN_GUIDE.md) for campaign tips
- Open the GoPhish web interface for detailed logs
