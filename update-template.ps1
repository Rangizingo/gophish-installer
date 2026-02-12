# Disable SSL certificate validation
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$apiKey = "38154aafd6867378cb200f31661aa4ed524bb64aa8d91f6d1ad0d61fb8f695fa"
$headers = @{
    Authorization = "Bearer $apiKey"
    "Content-Type" = "application/json"
}

# Get current template
$template = Invoke-RestMethod -Uri "https://localhost:3333/api/templates/1" -Headers $headers

# Update envelope sender
$template | Add-Member -NotePropertyName "envelope_sender" -NotePropertyValue "IT Support <itsupport@equippers.com>" -Force

# Convert to JSON
$body = $template | ConvertTo-Json -Depth 10

# Update template
$result = Invoke-RestMethod -Uri "https://localhost:3333/api/templates/1" -Method PUT -Headers $headers -Body $body

Write-Host "Updated! New envelope_sender: $($result.envelope_sender)"
