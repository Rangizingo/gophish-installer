Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAll6 : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAll6
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$h = @{ Authorization = 'Bearer 38154aafd6867378cb200f31661aa4ed524bb64aa8d91f6d1ad0d61fb8f695fa'; 'Content-Type' = 'application/json' }

# Update group to just Peter
$groupBody = @{
    id = 1
    name = "IT Dept Test Group"
    targets = @(
        @{ email = "pblanco@equippers.com"; first_name = "Peter"; last_name = "Blanco"; position = "IT Manager" }
    )
} | ConvertTo-Json -Depth 5

Write-Host "Updating group to Peter only..." -ForegroundColor Yellow
Invoke-RestMethod -Uri 'https://localhost:3333/api/groups/1' -Method PUT -Headers $h -Body $groupBody | Out-Null
Write-Host "  Done." -ForegroundColor Green

# Launch campaign
$body = @{
    name = "Peter Test - $(Get-Date -Format 'MMdd-HHmm')"
    template = @{ name = "Password Expiration Notice" }
    page = @{ name = "Microsoft 365 Login" }
    smtp = @{ name = "Gmail - Demo" }
    url = "https://mazda-savings-advisory-glasses.trycloudflare.com"
    groups = @( @{ name = "IT Dept Test Group" } )
} | ConvertTo-Json -Depth 5

Write-Host "Launching campaign..." -ForegroundColor Yellow
$result = Invoke-RestMethod -Uri 'https://localhost:3333/api/campaigns/' -Method POST -Headers $h -Body $body
Write-Host "Campaign ID: $($result.id) - Status: $($result.status)" -ForegroundColor Green
Write-Host "Sent to: pblanco@equippers.com" -ForegroundColor Green
Write-Host "Tunnel URL: https://mazda-savings-advisory-glasses.trycloudflare.com" -ForegroundColor Cyan
