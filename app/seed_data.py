import datetime
from sqlalchemy.orm import Session
try:
    from .database import engine, Base, SessionLocal
    from .models import User, Store, ProductInventory, SmartCartNode, Order, OrderItem, ActivityLog
    from .auth import hash_password, generate_delivery_code
except ImportError:
    from database import engine, Base, SessionLocal
    from models import User, Store, ProductInventory, SmartCartNode, Order, OrderItem, ActivityLog
    from auth import hash_password, generate_delivery_code

def seed_database(db: Session):
    # Check if database is already seeded
    if db.query(User).first():
        return

    print("Seeding initial Smart Cart AI database...")

    # 1. Smart Cart Nodes
    node1 = SmartCartNode(node_code="NODE-BLR-01", name="Indiranagar Smart Hub", area="Indiranagar", city="Bengaluru", pincode="560038", status="operational")
    node2 = SmartCartNode(node_code="NODE-BLR-02", name="Koramangala Node", area="Koramangala", city="Bengaluru", pincode="560034", status="operational")
    node3 = SmartCartNode(node_code="NODE-BLR-03", name="HSR Layout Node", area="HSR Layout", city="Bengaluru", pincode="560102", status="operational")
    db.add_all([node1, node2, node3])
    db.commit()

    # 2. Users (Admin, Customer, Merchants, Delivery Partners)
    admin = User(
        user_id="ADMN1000",
        name="Platform Administrator",
        mobile="9999900000",
        email="admin@smartcart.ai",
        password_hash=hash_password("admin123"),
        role="admin",
        address="Smart Cart HQ, Indiranagar",
        area="Indiranagar",
        pincode="560038"
    )

    customer = User(
        user_id="CUST1001",
        name="Pooja Sharma",
        mobile="9876543210",
        email="pooja.sharma@gmail.com",
        password_hash=hash_password("cust123"),
        role="customer",
        address="Flat 304, Palm Grove Apts, 12th Main Road, Indiranagar",
        area="Indiranagar",
        pincode="560038"
    )

    merchant1 = User(
        user_id="MERC2001",
        name="Navjeevan Manager",
        mobile="9845012345",
        email="support@navjeevan.in",
        password_hash=hash_password("merc123"),
        role="merchant",
        address="#45, Navjeevan Complex, 100 Feet Road, Indiranagar, Bengaluru",
        area="Indiranagar",
        pincode="560038",
        store_name="Navjeevan Supermart",
        store_address="#45, Navjeevan Complex, 100 Feet Road, Indiranagar, Bengaluru",
        upi_id="navjeevan@okaxis"
    )

    merchant2 = User(
        user_id="MERC2002",
        name="More Provision Store Lead",
        mobile="9845098765",
        email="contact@moreprovision.com",
        password_hash=hash_password("merc123"),
        role="merchant",
        address="#12, More Provision Store, CMH Road, Indiranagar, Bengaluru",
        area="Indiranagar",
        pincode="560038",
        store_name="More Provision",
        store_address="#12, More Provision Store, CMH Road, Indiranagar, Bengaluru",
        upi_id="moreprovision@okhdfcbank"
    )

    delivery1 = User(
        user_id="DELV3001",
        name="Vikram Singh",
        mobile="9731011223",
        email="vikram.singh@smartcart.ai",
        password_hash=hash_password("delv123"),
        role="delivery",
        address="Old Madras Road, Bengaluru",
        area="Indiranagar",
        pincode="560038",
        vehicle_type="Motorbike",
        vehicle_number="KA-04-EK-9821",
        is_online=True
    )

    delivery2 = User(
        user_id="DELV3002",
        name="Arjun Kumar",
        mobile="9731055667",
        email="arjun.kumar@smartcart.ai",
        password_hash=hash_password("delv123"),
        role="delivery",
        address="Domlur Layout, Bengaluru",
        area="Indiranagar",
        pincode="560038",
        vehicle_type="Scooter",
        vehicle_number="KA-03-HF-4312",
        is_online=True
    )

    db.add_all([admin, customer, merchant1, merchant2, delivery1, delivery2])
    db.commit()

    # 3. Stores (Only Navjeevan and More Provision)
    store1 = Store(
        merchant_id=merchant1.id,
        name="Navjeevan Supermart",
        owner_name="Navjeevan Retail Ltd",
        phone="9845012345",
        address="#45, Navjeevan Complex, 100 Feet Road, Indiranagar, Bengaluru",
        area="Indiranagar",
        pincode="560038",
        status="active",
        rating=4.9,
        node_id=node1.id
    )

    store2 = Store(
        merchant_id=merchant2.id,
        name="More Provision",
        owner_name="More Retail (More Provision)",
        phone="9845098765",
        address="#12, More Provision Store, CMH Road, Indiranagar, Bengaluru",
        area="Indiranagar",
        pincode="560038",
        status="active",
        rating=4.8,
        node_id=node1.id
    )

    db.add_all([store1, store2])
    db.commit()

    # 4. 75+ Grocery Items
    from scratch.seed_50_groceries import GROCERY_CATALOG
    for it in GROCERY_CATALOG:
        db.add(ProductInventory(
            store_id=store1.id,
            name=it["name"],
            brand=it["brand"],
            category=it["category"],
            unit=it["unit"],
            price=it["price_navjeevan"],
            stock_quantity=float(it["stock"]),
            is_in_stock=True
        ))
        db.add(ProductInventory(
            store_id=store2.id,
            name=it["name"],
            brand=it["brand"],
            category=it["category"],
            unit=it["unit"],
            price=it["price_more"],
            stock_quantity=float(it["stock"]),
            is_in_stock=True
        ))

    db.commit()
    print("Database seeding complete with 75+ products per store!")
