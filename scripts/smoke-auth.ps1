$ErrorActionPreference = "Stop"
$base = "http://127.0.0.1:8000"

python -c @"
import json, time, urllib.request, urllib.error

base = '$base'
email = f'smoke_{int(time.time())}@glow.ai'
password = 'secret12'

def call(method, path, data=None, token=None, expect_json=True):
    headers = {}
    body = None
    if data is not None:
        body = json.dumps(data).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    if token:
        headers['Authorization'] = f'Bearer {token}'
    req = urllib.request.Request(base + path, data=body, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=90) as resp:
        if not expect_json or resp.status == 204:
            return None
        raw = resp.read()
        if not raw:
            return None
        return json.loads(raw)

print('== register (terms) ==')
try:
    call('POST', '/api/v1/auth/register', {
        'email': email,
        'password': password,
        'display_name': 'Smoke',
        'accept_terms': False,
    })
    raise SystemExit('expected 400 without terms')
except urllib.error.HTTPError as e:
    assert e.code == 400, e.code

reg = call('POST', '/api/v1/auth/register', {
    'email': email,
    'password': password,
    'display_name': 'Smoke',
    'accept_terms': True,
})
assert reg.get('verification_required'), reg
code = reg.get('dev_verify_code')
assert code, reg
print('register OK', reg['email'], 'code', code)

print('== verify-email ==')
verified = call('POST', '/api/v1/auth/verify-email', {'email': email, 'code': code})
token = verified['access_token']
print('verify OK', verified['user']['email_verified'])

print('== analyze ==')
import subprocess, tempfile, os
an = os.path.join(tempfile.gettempdir(), 'glowai-analyze.json')
subprocess.check_call([
    'curl.exe', '-s', '-X', 'POST', f'{base}/api/v1/analyze',
    '-F', 'home_city=Moscow',
    '-F', 'destination_city=Antalya',
    '-F', 'skin_type=Нормальная',
    '-F', 'concerns=Сухость',
    '-F', 'mode=pre_trip',
    '-F', 'home_lat=55.75',
    '-F', 'home_lon=37.62',
    '-F', 'dest_lat=36.91',
    '-F', 'dest_lon=30.70',
    '-o', an,
])
payload = json.load(open(an, encoding='utf-8'))
assert payload.get('care_plan'), payload
print('analyze OK', payload.get('provider'), payload.get('skin', {}).get('engine'))

print('== save check + remind ==')
check = call('POST', '/api/v1/checks', {
    'payload': payload,
    'home_city': 'Moscow',
    'dest_city': 'Antalya',
    'mode': 'pre_trip',
    'remind_in_hours': 48,
}, token=token)
cid = check['id']
assert check.get('remind_at'), check
print('check OK', cid, 'remind', check['remind_at'])

print('== follow-up parent ==')
follow = call('POST', '/api/v1/checks', {
    'payload': payload,
    'home_city': 'Moscow',
    'dest_city': 'Antalya',
    'mode': 'sos',
    'parent_check_id': cid,
}, token=token)
assert follow['parent_check_id'] == cid, follow
print('follow-up OK', follow['id'])

print('== chat ==')
chat = call('POST', f'/api/v1/checks/{cid}/messages', {'text': 'Кожа стала суше'}, token=token)
assert chat.get('assistant_message', {}).get('text'), chat
print('chat OK', chat['assistant_message']['text'][:90].replace('\n', ' '))

print('== forgot / reset ==')
forgot = call('POST', '/api/v1/auth/forgot-password', {'email': email})
reset_code = forgot.get('dev_verify_code')
assert reset_code, forgot
reset = call('POST', '/api/v1/auth/reset-password', {
    'email': email,
    'code': reset_code,
    'new_password': 'secret99',
})
token2 = reset['access_token']
print('reset OK')

print('== delete account ==')
call('DELETE', '/api/v1/auth/me', token=token2, expect_json=False)
print('delete OK')
print('SMOKE AUTH OK')
"@
