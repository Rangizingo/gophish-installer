Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAll3 : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAll3
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$h = @{Authorization='Bearer 38154aafd6867378cb200f31661aa4ed524bb64aa8d91f6d1ad0d61fb8f695fa'}
$r = Invoke-RestMethod -Uri 'https://localhost:3333/api/campaigns/7/results' -Headers $h
$r.results | ForEach-Object { Write-Host "RID: $($_.id)  Email: $($_.email)  Status: $($_.status)" }
