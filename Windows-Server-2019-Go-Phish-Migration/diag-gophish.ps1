# Diagnose GoPhish "no valid version found" error
$dir = "C:\scripts\gophish"

Write-Host "=== GoPhish Diagnostic ===" -ForegroundColor Cyan

# Check VERSION file bytes
Write-Host "`n[1] VERSION file:" -ForegroundColor Yellow
$vBytes = [System.IO.File]::ReadAllBytes("$dir\VERSION")
$vHex = ($vBytes | ForEach-Object { "{0:X2}" -f $_ }) -join " "
$vText = [System.Text.Encoding]::UTF8.GetString($vBytes)
Write-Host "  Hex:  $vHex"
Write-Host "  Text: [$vText]"
Write-Host "  Len:  $($vBytes.Length) bytes"

# Check config.json
Write-Host "`n[2] config.json:" -ForegroundColor Yellow
Get-Content "$dir\config.json" -Raw

# Check if gophish.db exists (corrupt db from failed start)
Write-Host "`n[3] gophish.db:" -ForegroundColor Yellow
if (Test-Path "$dir\gophish.db") {
    $dbSize = (Get-Item "$dir\gophish.db").Length
    Write-Host "  EXISTS - Size: $dbSize bytes"
    Write-Host "  Deleting corrupt db from failed start..."
    Remove-Item "$dir\gophish.db" -Force
    Write-Host "  Deleted." -ForegroundColor Green
} else {
    Write-Host "  Does not exist (clean)" -ForegroundColor Green
}

# Check db folder contents
Write-Host "`n[4] db\ folder:" -ForegroundColor Yellow
if (Test-Path "$dir\db") {
    Get-ChildItem "$dir\db" -Recurse | ForEach-Object { Write-Host "  $($_.FullName)" }
} else {
    Write-Host "  Not found"
}

# Check gophish.exe details
Write-Host "`n[5] gophish.exe:" -ForegroundColor Yellow
$exe = Get-Item "$dir\gophish.exe"
Write-Host "  Size: $($exe.Length) bytes"
Write-Host "  Date: $($exe.LastWriteTime)"

# Try running with output capture
Write-Host "`n[6] Running gophish.exe..." -ForegroundColor Yellow
Stop-Service gophish -Force -ErrorAction SilentlyContinue
Start-Sleep 1
$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = "$dir\gophish.exe"
$pinfo.WorkingDirectory = $dir
$pinfo.RedirectStandardOutput = $true
$pinfo.RedirectStandardError = $true
$pinfo.UseShellExecute = $false
$p = [System.Diagnostics.Process]::Start($pinfo)
$p.WaitForExit(10000)
$stdout = $p.StandardOutput.ReadToEnd()
$stderr = $p.StandardError.ReadToEnd()
Write-Host "  STDOUT: $stdout"
Write-Host "  STDERR: $stderr"
Write-Host "  ExitCode: $($p.ExitCode)"
