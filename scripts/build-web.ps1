$ErrorActionPreference = "Stop"
$env:Path = "C:\flutter\flutter\bin;" + $env:Path

Set-Location "c:\Glow_Ai\mobile"
Write-Host "flutter pub get..."
flutter pub get
Write-Host "flutter build web..."
# same-origin API when UI served from FastAPI on :8000
# --no-tree-shake-icons: keep Material/Cupertino icon fonts for /app static serve
flutter build web --release --base-href /app/ --no-tree-shake-icons --no-wasm-dry-run

$dest = "c:\Glow_Ai\backend\web"
if (Test-Path $dest) {
  Get-ChildItem $dest -Force | Where-Object { $_.Name -ne ".gitkeep" } | Remove-Item -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Recurse -Force "c:\Glow_Ai\mobile\build\web\*" $dest
Write-Host "Web UI copied to backend/web"
