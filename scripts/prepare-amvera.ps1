# Prepare artifacts before Amvera deploy:
# 1) Flutter web (same-origin, /app/, icons)
# 2) Copy into backend/web
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$env:Path = "C:\flutter\flutter\bin;" + $env:Path

Set-Location "$root\mobile"
Write-Host "flutter pub get..."
flutter pub get
Write-Host "flutter build web (same-origin, base-href /app/)..."
flutter build web --release --base-href /app/ --no-tree-shake-icons --no-wasm-dry-run

$dest = "$root\backend\web"
if (-not (Test-Path $dest)) {
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
}
Copy-Item -Recurse -Force "$root\mobile\build\web\*" $dest

$fontOk = Test-Path "$dest\assets\fonts\MaterialIcons-Regular.otf"
$manifestOk = Test-Path "$dest\assets\FontManifest.json"
$index = Get-Content "$dest\index.html" -Raw
if ($index -notmatch 'base href="/app/"') {
  throw "index.html base href is not /app/"
}
if (-not $fontOk -or -not $manifestOk) {
  throw "Web assets incomplete (fonts/FontManifest missing)"
}

Write-Host ""
Write-Host "OK: backend/web ready for Docker/Amvera"
Write-Host "Next: fill .env.amvera (SMTP + CORS), see docs/amvera-deploy.md"
Write-Host "UI: https://<project>.amvera.ru/app/"
