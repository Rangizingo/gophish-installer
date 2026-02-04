$apiKey = '37cb4c93eaec96c030a3d11dabcc7ac85595ba6ae9b5fb70e1c4a41f9a5a8f05'
$baseUrl = 'https://localhost:3333'

# Ignore SSL cert errors for localhost
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$headers = @{
    'Authorization' = $apiKey
    'Content-Type' = 'application/json'
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GoPhish Setup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Create Landing Page
Write-Host "`n[1/3] Creating Landing Page..." -ForegroundColor Yellow
$landingHtml = Get-Content 'C:/Users/Peter/Documents/AI/gophish-installer/templates/landing-page-final.html' -Raw
$landingPayload = @{
    name = 'M365 Password Reset - Equippers'
    html = $landingHtml
    capture_credentials = $true
    capture_passwords = $true
    redirect_url = 'https://login.microsoftonline.com'
} | ConvertTo-Json -Depth 10 -Compress

try {
    $landingResponse = Invoke-RestMethod -Uri "$baseUrl/api/pages/" -Method Post -Headers $headers -Body $landingPayload
    Write-Host "  SUCCESS: Landing page created (ID: $($landingResponse.id))" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Create Email Template
Write-Host "`n[2/3] Creating Email Template..." -ForegroundColor Yellow
$emailHtml = Get-Content 'C:/Users/Peter/Documents/AI/gophish-installer/templates/email-template-v2.html' -Raw
$emailPayload = @{
    name = 'M365 Password Expiration - Equippers'
    subject = 'Action Required: Your password expires in 3 business days'
    html = $emailHtml
    envelope_sender = ''
} | ConvertTo-Json -Depth 10 -Compress

try {
    $emailResponse = Invoke-RestMethod -Uri "$baseUrl/api/templates/" -Method Post -Headers $headers -Body $emailPayload
    Write-Host "  SUCCESS: Email template created (ID: $($emailResponse.id))" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Create Test User Group (placeholder - user adds their email)
Write-Host "`n[3/3] Creating Test User Group..." -ForegroundColor Yellow
$groupPayload = @{
    name = 'IT Dept Test Group'
    targets = @(
        @{
            first_name = 'Test'
            last_name = 'User'
            email = 'test@equippers.com'
            position = 'IT Test'
        }
    )
} | ConvertTo-Json -Depth 10 -Compress

try {
    $groupResponse = Invoke-RestMethod -Uri "$baseUrl/api/groups/" -Method Post -Headers $headers -Body $groupPayload
    Write-Host "  SUCCESS: User group created (ID: $($groupResponse.id))" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor White
Write-Host "  1. Go to https://localhost:3333" -ForegroundColor Gray
Write-Host "  2. Create Sending Profile (SMTP credentials)" -ForegroundColor Gray
Write-Host "  3. Edit 'IT Dept Test Group' to add real emails" -ForegroundColor Gray
Write-Host "  4. Create Campaign using these components" -ForegroundColor Gray
