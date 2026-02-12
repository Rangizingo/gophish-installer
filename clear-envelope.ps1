Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$h = @{ Authorization = 'Bearer 38154aafd6867378cb200f31661aa4ed524bb64aa8d91f6d1ad0d61fb8f695fa'; 'Content-Type' = 'application/json' }
$t = Invoke-RestMethod -Uri 'https://localhost:3333/api/templates/1' -Headers $h
$t.envelope_sender = ''
$body = $t | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri 'https://localhost:3333/api/templates/1' -Method PUT -Headers $h -Body $body | Out-Null
Write-Host "Cleared envelope_sender"
