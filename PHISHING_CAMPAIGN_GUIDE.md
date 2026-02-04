# Restaurant Equippers Security Awareness Phishing Program

## Purpose

This document outlines the internal phishing simulation program designed to test employee security awareness and identify training opportunities. The program uses controlled phishing emails to measure how employees respond to social engineering attempts.

## Authorization

This program is authorized by the IT Department for internal security testing only. All simulations must be approved by management before execution.

## Program Overview

### Scenario: Microsoft 365 Password Expiration

The simulation sends employees an email claiming their Microsoft 365 password is expiring, prompting them to click a link and enter their credentials on a fake login page.

### Components

| Component | Description |
|-----------|-------------|
| **GoPhish Server** | Open-source phishing simulation platform running on Docker |
| **Email Template** | Password expiration notice branded with company styling |
| **Landing Page** | Fake Microsoft 365 login page with Restaurant Equippers branding |
| **Tracking** | Records email opens, link clicks, and credential submissions |

## Technical Details

### Infrastructure

- **Platform:** GoPhish (Docker container)
- **Admin URL:** https://localhost:3333
- **Phishing Server:** http://localhost:80
- **Database:** SQLite (gophish.db)

### Email Template

- **Subject:** Action Required: Your password expires in 3 business days
- **From:** IT Support <itsupport@equippers.com>
- **Theme:** Red/black/white Restaurant Equippers branding
- **Call to Action:** "Reset Password" button linking to landing page
- **Support Contact:** itsupport@equippers.com, Extension 199

### Landing Page Flow

1. User clicks link in email
2. Landing page displays with user's email pre-filled
3. User enters password
4. "Verifying credentials..." spinner appears (1.5 seconds)
5. "Connecting to server..." message (1.5 seconds)
6. "Session expired" error displayed (2 seconds)
7. User redirected to real Microsoft login (login.microsoftonline.com)

### Data Captured

- Email address (from campaign data)
- Password entered by user
- Timestamp of submission
- IP address and user agent

## Campaign Execution

### Prerequisites

1. GoPhish running (`docker ps` shows gophish container)
2. SMTP Sending Profile configured with valid credentials
3. Target user group created with employee emails
4. Landing page and email template imported

### Steps to Launch

1. Log into GoPhish: https://localhost:3333
2. Navigate to Campaigns > New Campaign
3. Configure:
   - Name: [descriptive campaign name]
   - Email Template: M365 Password Expiration - Equippers
   - Landing Page: M365 Password Reset - Equippers
   - URL: [your phishing server URL]
   - Sending Profile: [configured SMTP profile]
   - Groups: [target user group]
4. Set launch date/time
5. Click "Launch Campaign"

### Monitoring

- Dashboard shows real-time statistics
- Track: Emails sent, opened, clicked, credentials submitted
- Export results for reporting

## Security Considerations

### Data Handling

- Captured passwords are stored in plaintext in the database
- Delete campaign data promptly after analysis
- Do not share captured credentials
- Keep GoPhish server access restricted

### SMTP Security

- Use dedicated service account for sending
- Use app passwords instead of primary credentials
- Revoke credentials after testing period
- Audit SMTP account activity

### Network Security

- Run GoPhish on internal network only
- Do not expose admin interface to internet
- Use VPN for remote access
- Restrict firewall access to phishing server

## Reporting

### Metrics to Track

- Click rate: % of recipients who clicked the link
- Submission rate: % of clickers who entered credentials
- Time to click: How quickly users fell for the phish
- Department breakdown: Identify high-risk groups

### Report Template

```
Campaign: [Name]
Date: [Date Range]
Target Audience: [Department/Group]

Results:
- Emails Sent: X
- Emails Opened: X (X%)
- Links Clicked: X (X%)
- Credentials Submitted: X (X%)

High-Risk Users: [List for targeted training]

Recommendations:
- [Training suggestions]
- [Policy improvements]
```

## Follow-Up Actions

### For Users Who Submitted Credentials

1. Notify user of simulation participation
2. Provide security awareness training
3. Share educational resources on phishing detection
4. Document for compliance records

### Training Topics

- Identifying phishing emails
- Checking sender addresses and URLs
- Reporting suspicious emails
- Password security best practices

## Contact

For questions about this program:

- **IT Security:** itsupport@equippers.com
- **Phone:** Extension 199
- **Hours:** Monday-Friday, 8:00 AM - 5:00 PM EST

---

**Restaurant Equippers, Inc.**
635 West Broad Street, Columbus, OH 43215
Serving the food service industry since 1966

*This document is confidential and intended for authorized IT personnel only.*
