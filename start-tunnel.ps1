$process = Start-Process -FilePath "C:\Program Files (x86)\cloudflared\cloudflared.exe" -ArgumentList "tunnel","--url","http://localhost:80" -RedirectStandardError "C:\Users\Peter\Documents\AI\gophish-installer\tunnel.log" -PassThru -NoNewWindow
Start-Sleep -Seconds 15
Get-Content "C:\Users\Peter\Documents\AI\gophish-installer\tunnel.log" | Select-String "trycloudflare"
