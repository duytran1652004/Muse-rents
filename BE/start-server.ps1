$port = 3001
Write-Host "Checking port $port..." -ForegroundColor Cyan
$conns = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
if ($conns) {
    $conns | ForEach-Object {
        Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 800
    Write-Host "Port $port freed." -ForegroundColor Green
} else {
    Write-Host "Port $port is already free." -ForegroundColor Green
}
Write-Host "Starting MUSE Rents Backend..." -ForegroundColor Cyan
npm run dev
