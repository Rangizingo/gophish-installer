Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAll5 : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAll5
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$h = @{ Authorization = 'Bearer 38154aafd6867378cb200f31661aa4ed524bb64aa8d91f6d1ad0d61fb8f695fa' }

Write-Host "=== TEMPLATES ===" -ForegroundColor Cyan
$t = Invoke-RestMethod -Uri 'https://localhost:3333/api/templates/' -Headers $h
$t | ForEach-Object { Write-Host "  $($_.name) (ID: $($_.id))" }

Write-Host "`n=== LANDING PAGES ===" -ForegroundColor Cyan
$p = Invoke-RestMethod -Uri 'https://localhost:3333/api/pages/' -Headers $h
$p | ForEach-Object { Write-Host "  $($_.name) (ID: $($_.id))" }

Write-Host "`n=== SMTP PROFILES ===" -ForegroundColor Cyan
$s = Invoke-RestMethod -Uri 'https://localhost:3333/api/smtp/' -Headers $h
$s | ForEach-Object { Write-Host "  $($_.name) (ID: $($_.id)) - From: $($_.from_address) Host: $($_.host)" }

Write-Host "`n=== GROUPS ===" -ForegroundColor Cyan
$g = Invoke-RestMethod -Uri 'https://localhost:3333/api/groups/' -Headers $h
$g | ForEach-Object { Write-Host "  $($_.name) (ID: $($_.id)) - Targets: $($_.targets.Count)" }
