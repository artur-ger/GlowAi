$ErrorActionPreference = "Stop"
$base = "http://127.0.0.1:8000"

Write-Host "== health =="
curl.exe -s "$base/healthz"
Write-Host ""

Write-Host "== api =="
curl.exe -s "$base/api"
Write-Host ""

Write-Host "== geo =="
curl.exe -s "$base/api/v1/geo/places?q=Moscow&country_code=RU&limit=1"
Write-Host ""
Write-Host "== geo antalya alias =="
curl.exe -s "$base/api/v1/geo/places?q=%D0%90%D0%BD%D1%82%D0%B0%D0%BB%D1%8C%D1%8F&country_code=TR&limit=1"
Write-Host ""
Write-Host "== geo cross-country =="
curl.exe -s "$base/api/v1/geo/places?q=%D0%90%D0%BD%D1%82%D0%B0%D0%BB%D1%8C%D1%8F&country_code=AE&limit=1"
Write-Host ""
Write-Host "== geo popular AE =="
curl.exe -s "$base/api/v1/geo/popular?country_code=AE&limit=3"
Write-Host ""

Write-Host "== analyze (with coords) =="
$out = Join-Path $env:TEMP "glowai-analyze.json"
curl.exe -s -X POST "$base/api/v1/analyze" `
  -F "home_city=Moscow" `
  -F "destination_city=Antalya" `
  -F "skin_type=Комбинированная" `
  -F "concerns=Сухость" `
  -F "mode=pre_trip" `
  -F "trip_start=2026-12-01" `
  -F "trip_end=2026-12-08" `
  -F "home_lat=55.75204" `
  -F "home_lon=37.61781" `
  -F "dest_lat=36.90812" `
  -F "dest_lon=30.69556" `
  -o $out

python -c @"
import json
d=json.load(open(r'$($out.Replace('\','\\'))', encoding='utf-8'))
assert d.get('provider'), 'no provider'
assert d.get('care_plan'), 'no care_plan'
assert d.get('forecast_summary'), 'no forecast_summary'
assert d.get('packing_kit'), 'no packing_kit'
assert d.get('why_reasons'), 'no why_reasons'
assert d.get('skin', {}).get('engine'), 'no skin.engine'
src = (d.get('climate') or {}).get('source') or ''
assert 'client-coords' in src or 'open-meteo' in src, src
print('analyze OK', 'provider=', d.get('provider'), 'engine=', d['skin']['engine'], 'steps=', len(d['care_plan']), 'kit=', len(d['packing_kit']), 'source=', src)
"@

Write-Host "== ui =="
$code = curl.exe -s -o NUL -w "%{http_code}" "$base/app/"
if ($code -ne "200") { throw "UI /app/ returned $code" }
Write-Host "ui OK $code"
Write-Host "SMOKE OK"
