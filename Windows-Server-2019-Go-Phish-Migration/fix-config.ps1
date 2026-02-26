# Fix config.json and VERSION encoding, then test GoPhish directly
$gophishDir = "C:\scripts\gophish"

$config = '{"admin_server":{"listen_url":"0.0.0.0:3333","use_tls":true,"cert_path":"gophish_admin.crt","key_path":"gophish_admin.key"},"phish_server":{"listen_url":"0.0.0.0:80","use_tls":false},"db_name":"sqlite3","db_path":"gophish.db","contact_address":""}'
[System.IO.File]::WriteAllText("$gophishDir\config.json", $config, [System.Text.UTF8Encoding]::new($false))
Write-Host "config.json written (UTF8 no BOM)" -ForegroundColor Green

[System.IO.File]::WriteAllText("$gophishDir\VERSION", "0.12.1", [System.Text.UTF8Encoding]::new($false))
Write-Host "VERSION written (UTF8 no BOM)" -ForegroundColor Green

Stop-Service gophish -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "`nStarting gophish.exe directly (Ctrl+C to stop)..." -ForegroundColor Yellow
Set-Location $gophishDir
& "$gophishDir\gophish.exe"
