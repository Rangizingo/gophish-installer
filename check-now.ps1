Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAll7 : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAll7
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$h = @{ Authorization = 'Bearer 38154aafd6867378cb200f31661aa4ed524bb64aa8d91f6d1ad0d61fb8f695fa' }

$campaign = Invoke-RestMethod -Uri 'https://localhost:3333/api/campaigns/4' -Headers $h

Write-Host "=== Campaign: $($campaign.name) ===" -ForegroundColor Cyan
Write-Host "Status: $($campaign.status)" -ForegroundColor Yellow
Write-Host "Created: $($campaign.created_date)" -ForegroundColor Gray
Write-Host ""

foreach ($r in $campaign.results) {
    Write-Host "Target: $($r.email)" -ForegroundColor White
    Write-Host "  Status:     $($r.status)" -ForegroundColor $(if ($r.status -eq 'Email Sent') { 'Green' } elseif ($r.status -eq 'Clicked Link') { 'Yellow' } elseif ($r.status -eq 'Submitted Data') { 'Red' } else { 'Gray' })
    Write-Host "  First Name: $($r.first_name)"
    Write-Host "  IP:         $($r.ip)"
    Write-Host ""
}

Write-Host "=== Timeline ===" -ForegroundColor Cyan
foreach ($e in $campaign.timeline) {
    Write-Host "  [$($e.time)] $($e.email) - $($e.message)" -ForegroundColor Gray
}
