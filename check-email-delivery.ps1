# Check Email Delivery via Microsoft Graph API
# Uses device code flow for OAuth authentication

param(
    [string]$SenderEmail = "itsupport@blancoitservices.net",
    [string]$Hours = 4
)

$ErrorActionPreference = "Stop"

# Microsoft Graph App Registration (use well-known PowerShell client ID for device flow)
$clientId = "14d82eec-204b-4c2f-b7e8-296a70dab67e"  # Microsoft Graph PowerShell
$tenantId = "common"
$scope = "https://graph.microsoft.com/Mail.Read https://graph.microsoft.com/Mail.ReadBasic"

Write-Host "`n=== Office 365 Email Delivery Checker ===" -ForegroundColor Cyan
Write-Host "Looking for emails from: $SenderEmail" -ForegroundColor Yellow
Write-Host "Time range: Last $Hours hours`n"

# Step 1: Device Code Authentication
Write-Host "[1/4] Starting OAuth authentication..." -ForegroundColor Green

$deviceCodeUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/devicecode"
$tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

$deviceCodeBody = @{
    client_id = $clientId
    scope     = $scope
}

try {
    $deviceCodeResponse = Invoke-RestMethod -Method POST -Uri $deviceCodeUrl -Body $deviceCodeBody

    Write-Host "`n$($deviceCodeResponse.message)" -ForegroundColor Yellow
    Write-Host "`nWaiting for authentication..." -ForegroundColor Gray

    # Poll for token
    $tokenBody = @{
        grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
        client_id   = $clientId
        device_code = $deviceCodeResponse.device_code
    }

    $token = $null
    $timeout = [DateTime]::Now.AddSeconds($deviceCodeResponse.expires_in)

    while ([DateTime]::Now -lt $timeout -and $null -eq $token) {
        Start-Sleep -Seconds 3
        try {
            $token = Invoke-RestMethod -Method POST -Uri $tokenUrl -Body $tokenBody
        }
        catch {
            $err = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($err.error -eq "authorization_pending") {
                Write-Host "." -NoNewline -ForegroundColor Gray
            }
            elseif ($err.error -eq "authorization_declined") {
                throw "Authentication declined by user"
            }
            elseif ($err.error -eq "expired_token") {
                throw "Authentication timed out"
            }
        }
    }

    if ($null -eq $token) {
        throw "Authentication timed out"
    }

    Write-Host "`n`n[2/4] Authentication successful!" -ForegroundColor Green
}
catch {
    Write-Host "Authentication failed: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Set up Graph API headers
$headers = @{
    Authorization = "Bearer $($token.access_token)"
    "Content-Type" = "application/json"
}

# Step 3: Search all mail folders
Write-Host "[3/4] Searching mailbox folders..." -ForegroundColor Green

$folders = @(
    @{ name = "Inbox"; id = "inbox" },
    @{ name = "Junk Email"; id = "junkemail" },
    @{ name = "Deleted Items"; id = "deleteditems" },
    @{ name = "Archive"; id = "archive" }
)

$cutoffTime = (Get-Date).AddHours(-$Hours).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$foundEmails = @()

foreach ($folder in $folders) {
    try {
        $filter = "from/emailAddress/address eq '$SenderEmail' and receivedDateTime ge $cutoffTime"
        $url = "https://graph.microsoft.com/v1.0/me/mailFolders/$($folder.id)/messages?`$filter=$filter&`$select=subject,receivedDateTime,from,isRead&`$top=50"

        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method GET

        if ($response.value.Count -gt 0) {
            Write-Host "  Found $($response.value.Count) email(s) in $($folder.name)" -ForegroundColor Yellow
            foreach ($msg in $response.value) {
                $foundEmails += [PSCustomObject]@{
                    Folder   = $folder.name
                    Subject  = $msg.subject
                    Received = $msg.receivedDateTime
                    Read     = $msg.isRead
                }
            }
        }
        else {
            Write-Host "  $($folder.name): No emails found" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  $($folder.name): Could not access - $_" -ForegroundColor DarkGray
    }
}

# Step 4: Check for messages via search (catches more)
Write-Host "[4/4] Running broad search..." -ForegroundColor Green

try {
    $searchUrl = "https://graph.microsoft.com/v1.0/me/messages?`$search=`"from:$SenderEmail`"&`$select=subject,receivedDateTime,parentFolderId,from&`$top=50"
    $searchResponse = Invoke-RestMethod -Uri $searchUrl -Headers $headers -Method GET

    if ($searchResponse.value.Count -gt 0) {
        Write-Host "  Search found $($searchResponse.value.Count) total email(s)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  Search failed: $_" -ForegroundColor DarkGray
}

# Results
Write-Host "`n=== RESULTS ===" -ForegroundColor Cyan

if ($foundEmails.Count -gt 0) {
    Write-Host "`nFound $($foundEmails.Count) email(s) from $SenderEmail`:" -ForegroundColor Green
    $foundEmails | Format-Table -AutoSize
}
else {
    Write-Host "`nNO EMAILS FOUND from $SenderEmail in the last $Hours hours" -ForegroundColor Red
    Write-Host "`nPossible causes:" -ForegroundColor Yellow
    Write-Host "  1. Email blocked at SMTP relay (check Google Admin > Email Log Search)"
    Write-Host "  2. Email quarantined by M365 Defender (check security.microsoft.com > Quarantine)"
    Write-Host "  3. Email rejected by M365 (check Exchange Admin > Message Trace)"
    Write-Host "  4. SPF/DKIM/DMARC failure causing silent drop"

    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "  - Run message trace: admin.exchange.microsoft.com > Mail flow > Message trace"
    Write-Host "  - Check quarantine: security.microsoft.com > Email & collaboration > Review > Quarantine"
    Write-Host "  - Check Google logs: admin.google.com > Reporting > Email Log Search"
}

Write-Host "`nDone.`n" -ForegroundColor Gray
