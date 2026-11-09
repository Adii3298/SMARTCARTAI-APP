import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal
from app.models import Store, User

db = SessionLocal()

store2 = db.query(Store).filter(Store.id == 2).first()
if store2:
    store2.name = 'More Provision'
    store2.owner_name = 'More Retail (More Provision)'
    store2.address = '#12, More Provision Store, CMH Road, Indiranagar, Bengaluru'
    print(f"Updated Store 2: {store2.name}")

merchant2 = db.query(User).filter(User.user_id == 'MERC2002').first()
if merchant2:
    merchant2.name = 'More Provision Store Lead'
    merchant2.email = 'contact@moreprovision.com'
    merchant2.address = '#12, More Provision Store, CMH Road, Indiranagar, Bengaluru'
    merchant2.store_name = 'More Provision'
    merchant2.store_address = '#12, More Provision Store, CMH Road, Indiranagar, Bengaluru'
    merchant2.upi_id = 'moreprovision@okhdfcbank'
    print(f"Updated Merchant MERC2002: {merchant2.name}")

db.commit()

# Verify active stores
stores = db.query(Store).filter(Store.status == 'active').all()
print("\nACTIVE STORES IN DB:")
for s in stores:
    print(f"Store ID: {s.id}, Name: '{s.name}', Owner: '{s.owner_name}', Phone: '{s.phone}', UPI: '{s.merchant.upi_id if s.merchant else None}'")

db.close()
