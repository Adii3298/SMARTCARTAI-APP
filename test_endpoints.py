import requests

BASE = 'http://127.0.0.1:8000'

# Test 1: Frontend Web App Root
r1 = requests.get(BASE + '/')
assert r1.status_code == 200, f"Frontend returned {r1.status_code}"
print(f'1. [OK] Frontend Web App: HTTP {r1.status_code} (HTML size: {len(r1.text)} bytes)')

# Test 2: API Health / Swagger Docs
r2 = requests.get(BASE + '/docs')
assert r2.status_code == 200, f"Docs returned {r2.status_code}"
print(f'2. [OK] Backend Swagger Docs: HTTP {r2.status_code}')

# Test 3: Stores API
r3 = requests.get(BASE + '/api/stores')
assert r3.status_code == 200, f"Stores returned {r3.status_code}"
stores = r3.json().get('stores', [])
print(f'3. [OK] Stores API: HTTP {r3.status_code}, Active Stores ({len(stores)}): {[s["name"] for s in stores]}')

# Test 4: Auth Quick Switch / Login API
r4 = requests.post(BASE + '/api/auth/quick_switch?role=customer')
assert r4.status_code == 200, f"Auth returned {r4.status_code}"
user_data = r4.json().get('user', {})
print(f'4. [OK] Auth API: HTTP {r4.status_code}, Authenticated as: {user_data.get("name")} ({user_data.get("role")})')

# Test 5: OCR Presets API
r5 = requests.get(BASE + '/api/customer/ocr/presets')
assert r5.status_code == 200, f"OCR returned {r5.status_code}"
presets = r5.json().get('presets', [])
print(f'5. [OK] OCR Engine API: HTTP {r5.status_code}, Available Presets count: {len(presets)}')

# Test 6: Merchant Orders API
r6 = requests.get(BASE + '/api/merchant/orders?merchant_id=4')
assert r6.status_code == 200, f"Merchant orders returned {r6.status_code}"
orders = r6.json().get('orders', [])
print(f'6. [OK] Merchant Orders API: HTTP {r6.status_code}, Active Orders for More Provision: {len(orders)}')

print('\n============================================================')
print('  RESULT: 100% OF FRONTEND & BACKEND SERVICES ARE OPERATIONAL!')
print('============================================================')
