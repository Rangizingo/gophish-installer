Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy2 : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$h = @{ Authorization = 'Bearer 37cb4c93eaec96c030a3d11dabcc7ac85595ba6ae9b5fb70e1c4a41f9a5a8f05'; 'Content-Type' = 'application/json' }

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
