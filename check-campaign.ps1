Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAll3 : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAll3
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$h = @{Authorization='Bearer 37cb4c93eaec96c030a3d11dabcc7ac85595ba6ae9b5fb70e1c4a41f9a5a8f05'}
$r = Invoke-RestMethod -Uri 'https://localhost:3333/api/campaigns/7/results' -Headers $h
$r.results | ForEach-Object { Write-Host "RID: $($_.id)  Email: $($_.email)  Status: $($_.status)" }
