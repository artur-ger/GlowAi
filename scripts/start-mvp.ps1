$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path "$root\.env")) {
  Copy-Item "$root\.env.example" "$root\.env"
  Write-Host "Created .env from .env.example (rule_based mode)"
}

Write-Host "1) Building Flutter web..."
& "$PSScriptRoot\build-web.ps1"

Write-Host "2) Freeing port 8000 if a stale local uvicorn is bound..."
Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue |
  ForEach-Object {
    try {
      $p = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
      if ($p -and $p.ProcessName -match 'python|uvicorn') {
        Write-Host "Stopping $($p.ProcessName) PID $($p.Id)"
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
      }
    } catch {}
  }

Write-Host "3) Starting Docker backend..."
docker compose up -d --build --force-recreate

Write-Host "4) Waiting for health..."
$ok = $false
for ($i = 0; $i -lt 30; $i++) {
  Start-Sleep -Seconds 2
  try {
    $code = curl.exe -s -o NUL -w "%{http_code}" "http://127.0.0.1:8000/healthz"
    if ($code -eq "200") { $ok = $true; break }
  } catch {}
}
if (-not $ok) { throw "Backend did not become healthy on :8000" }

Write-Host "5) Smoke..."
& "$PSScriptRoot\smoke-mvp.ps1"

Write-Host ""
Write-Host "MVP READY"
Write-Host "Open UI:    http://localhost:8000/app/"
Write-Host "Open API:   http://localhost:8000/docs"
Write-Host "LLM mode:   see GET http://localhost:8000/api  (llm_configured)"
