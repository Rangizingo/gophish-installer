Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$h = @{ Authorization = 'Bearer 37cb4c93eaec96c030a3d11dabcc7ac85595ba6ae9b5fb70e1c4a41f9a5a8f05'; 'Content-Type' = 'application/json' }
$t = Invoke-RestMethod -Uri 'https://localhost:3333/api/templates/1' -Headers $h
$t.envelope_sender = ''
$body = $t | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri 'https://localhost:3333/api/templates/1' -Method PUT -Headers $h -Body $body | Out-Null
Write-Host "Cleared envelope_sender"
