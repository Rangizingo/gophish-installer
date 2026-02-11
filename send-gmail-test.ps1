Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAll5 : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAll5
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$h = @{ Authorization = 'Bearer 37cb4c93eaec96c030a3d11dabcc7ac85595ba6ae9b5fb70e1c4a41f9a5a8f05'; 'Content-Type' = 'application/json' }

# Update group to Gmail only
$groupBody = @{
    id = 1
    name = "IT Dept Test Group"
    targets = @( @{ email = "Blancorunning@gmail.com"; first_name = "Peter"; last_name = "Blanco"; position = "IT Manager" } )
} | ConvertTo-Json -Depth 5
Invoke-RestMethod -Uri 'https://localhost:3333/api/groups/1' -Method PUT -Headers $h -Body $groupBody | Out-Null

# Launch campaign
$body = @{
    name = "Gmail Test - $(Get-Date -Format 'MMdd-HHmm')"
    template = @{ name = "M365 Password Expiration - Equippers" }
    page = @{ name = "M365 Password Reset - Equippers" }
    smtp = @{ name = "Google SMTP Relay" }
    url = "https://ships-parking-defines-outreach.trycloudflare.com"
    groups = @( @{ name = "IT Dept Test Group" } )
} | ConvertTo-Json -Depth 5

$result = Invoke-RestMethod -Uri 'https://localhost:3333/api/campaigns/' -Method POST -Headers $h -Body $body
Write-Host "Campaign ID: $($result.id) - Sent to Blancorunning@gmail.com"
