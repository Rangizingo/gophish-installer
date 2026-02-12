Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy2 : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$h = @{ Authorization = 'Bearer 38154aafd6867378cb200f31661aa4ed524bb64aa8d91f6d1ad0d61fb8f695fa'; 'Content-Type' = 'application/json' }

$body = @{
    name = "Password Reset - Live Campaign"
    template = @{ name = "M365 Password Expiration - Equippers" }
    page = @{ name = "M365 Password Reset - Equippers" }
    smtp = @{ name = "Google SMTP Relay" }
    url = "https://ships-parking-defines-outreach.trycloudflare.com"
    groups = @( @{ name = "IT Dept Test Group" } )
} | ConvertTo-Json -Depth 5

$result = Invoke-RestMethod -Uri 'https://localhost:3333/api/campaigns/' -Method POST -Headers $h -Body $body
Write-Host "Campaign ID: $($result.id)"
Write-Host "Status: $($result.status)"
