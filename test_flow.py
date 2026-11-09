"""
Direct route test for Smart Cart AI.
Directly tests Python route logic with active DB session.
"""

import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

from app.database import SessionLocal
from app.auth import generate_captcha, verify_captcha, CAPTCHA_CACHE
from app.schemas import (
    UserRegister, UserLogin, StoreAvailabilityRequest,
    StoreInventoryCheckItem, CreateOrderRequest,
    ExtractedGroceryItem, MerchantConfirmRequest,
    MerchantPackItem, CustomerAcceptRequest,
    DeliveryAcceptRequest, DeliveryVerifyRequest
)
from app.main import (
    register_user, login_user, ocr_upload,
    get_stores, check_store_availability,
    create_customer_order, get_merchant_orders,
    merchant_pack_and_confirm, customer_accept_order,
    get_available_deliveries, delivery_accept_order,
    delivery_verify_and_complete, get_admin_analytics
)

def run_tests():
    db = SessionLocal()
    print("=" * 60)
    print("  🧪 SMART CART AI - END-TO-END VERIFICATION")
    print("=" * 60)

    # 1. CAPTCHA test
    print("\n[Step 1] Testing CAPTCHA Generation & Validation...")
    cid, img = generate_captcha()
    assert cid in CAPTCHA_CACHE
    c_text = CAPTCHA_CACHE[cid][0]
    assert verify_captcha(cid, c_text) is True
    print(f"  ✓ CAPTCHA generated & verified successfully: {c_text}")

    # 2. Registration & Dummy Credentials test
    print("\n[Step 2] Testing 4-Role Registration & Dummy Credential Dispatch...")
    import random
    test_mobile = f"9822{random.randint(100000, 999999)}"
    reg_data = UserRegister(
        role="customer",
        name="Sunita Rao",
        mobile=test_mobile,
        email="sunita@example.com",
        address="House 42, 6th Cross, Indiranagar",
        area="Indiranagar",
        pincode="560038"
    )
    reg_out = register_user(reg_data, db=db)
    assert reg_out["status"] == "success"
    cust_uid = reg_out["credentials"]["user_id"]
    cust_pwd = reg_out["credentials"]["password"]
    cust_id = reg_out["user"]["id"]
    print(f"  ✓ Registered customer: {cust_uid} | Password: {cust_pwd}")
    print(f"  ✓ Simulated SMS Modal Payload generated: {reg_out['sms_notification'][:75]}...")

    # 3. Login Portal test with CAPTCHA
    print("\n[Step 3] Testing Login Portal with Interactive CAPTCHA...")
    cid2, _ = generate_captcha()
    c_text2 = CAPTCHA_CACHE[cid2][0]
    login_data = UserLogin(
        login_id=cust_uid,
        password=cust_pwd,
        captcha_id=cid2,
        captcha_text=c_text2
    )
    login_out = login_user(login_data, db=db)
    assert login_out["status"] == "success"
    print(f"  ✓ Login verified for {login_out['user']['name']} ({login_out['user']['role'].upper()})")

    # 4. OCR & NLP Extraction (Customer Flow Steps 1-3)
    print("\n[Step 4] Testing OCR & NLP Handwritten List Processing (Steps 1-3)...")
    ocr_out = ocr_upload(preset_key="weekly_ration")
    extracted_items = ocr_out["data"]["items"]
    assert len(extracted_items) >= 6
    print(f"  ✓ Successfully extracted {len(extracted_items)} grocery items from handwriting:")
    for it in extracted_items[:3]:
        print(f"    - {it['name']} ({it['brand']}): {it['quantity']} {it['unit']} [{it['category']}]")

    # 5. Store Selection & Availability Check (Customer Flow Steps 4-5)
    print("\n[Step 5] Testing Store Selection & Availability (Steps 4-5)...")
    stores_out = get_stores(db=db)
    assert len(stores_out["stores"]) >= 2
    store1 = stores_out["stores"][0]
    print(f"  ✓ Store 1: {store1['name']} (Rating: {store1['rating']} • {store1['total_products']} products)")

    check_req = StoreAvailabilityRequest(
        store_id=store1["id"],
        items=[StoreInventoryCheckItem(name=it["name"], quantity=it["quantity"], unit=it["unit"]) for it in extracted_items]
    )
    avail_out = check_store_availability(check_req, db=db)
    assert avail_out["status"] == "success"
    print(f"  ✓ Real-time Inventory Check: {avail_out['available_count']} In-Stock, {avail_out['missing_count']} Missing. Total: ₹{avail_out['total_bill']}")

    # 6. Order Submission & Packing (Customer Flow Steps 6-8)
    print("\n[Step 6] Testing Order Submission to Kirana Merchant (Steps 6-8)...")
    create_req = CreateOrderRequest(
        store_id=store1["id"],
        delivery_address="House 42, 6th Cross, Indiranagar",
        notes="Please pack fresh items",
        items=[ExtractedGroceryItem(**it) for it in extracted_items]
    )
    order_out = create_customer_order(create_req, customer_id=cust_id, db=db)
    assert order_out["status"] == "success"
    order_id = order_out["order"]["id"]
    order_num = order_out["order"]["order_number"]
    print(f"  ✓ Created Order {order_num} (Status: {order_out['order']['status']})")

    # Merchant views and packs order
    merc_out = get_merchant_orders(merchant_id=3, db=db)
    matched_order = next((o for o in merc_out["orders"] if o["id"] == order_id), None)
    assert matched_order is not None

    pack_req = MerchantConfirmRequest(
        order_id=order_id,
        items=[
            MerchantPackItem(
                item_id=it["id"],
                packed_quantity=it["requested_quantity"],
                unit_price=it["unit_price"],
                is_available=True
            ) for it in matched_order["items"]
        ],
        total_amount=540.0,
        notes="All items packed fresh"
    )
    pack_res = merchant_pack_and_confirm(pack_req, merchant_id=3, db=db)
    print("pack_res received:", pack_res)
    assert pack_res["status"] == "success"
    print(f"  ✓ Merchant packed items and sent bill (₹{pack_res['total_amount']}) to customer")

    # 7. Customer Accepts & 6-Digit Delivery Code Trigger (Steps 9-10)
    print("\n[Step 7] Testing Customer Acceptance & Delivery Code Generation (Steps 9-10)...")
    accept_req = CustomerAcceptRequest(order_id=order_id, payment_mode="COD")
    cust_accept_out = customer_accept_order(accept_req, customer_id=cust_id, db=db)
    assert cust_accept_out["status"] == "success"
    delv_code = cust_accept_out["delivery_code"]
    assert len(delv_code) == 6
    print(f"  ✓ Customer accepted order via COD!")
    print(f"  ✓ Generated 6-Digit OTP Delivery Code: {delv_code}")

    # 8. Delivery Partner Pickup & Code Verification (Steps 11-15)
    print("\n[Step 8] Testing Delivery Partner Pickup & 6-Digit Verification (Steps 11-15)...")
    delivery_user_id = 5  # Vikram Singh
    gigs_out = get_available_deliveries(delivery_id=delivery_user_id, db=db)
    gig = next((g for g in gigs_out["available_gigs"] if g["id"] == order_id), None)
    assert gig is not None
    print(f"  ✓ Delivery Partner saw pickup gig {gig['order_number']} (+₹{gig['delivery_fee']} fee)")

    accept_gig_out = delivery_accept_order(DeliveryAcceptRequest(order_id=order_id), delivery_id=delivery_user_id, db=db)
    assert accept_gig_out["status"] == "success"
    print(f"  ✓ Delivery Partner accepted gig: Order is now OUT_FOR_DELIVERY")

    # Verify 6-digit OTP code on arrival
    verify_out = delivery_verify_and_complete(
        DeliveryVerifyRequest(order_id=order_id, delivery_code=delv_code),
        delivery_id=delivery_user_id,
        db=db
    )
    assert verify_out["status"] == "success"
    print(f"  ✓ 6-Digit OTP Code verified successfully!")
    print(f"  ✓ Order marked as DELIVERED at {verify_out['delivered_at']}")

    # 9. Admin Analytics
    print("\n[Step 9] Testing Admin Dashboard Analytics...")
    admin_out = get_admin_analytics(db=db)
    an = admin_out["analytics"]
    assert an["total_orders"] >= 2
    assert an["delivered_orders"] >= 2
    assert an["total_gmv"] > 0
    print(f"  ✓ Total GMV: ₹{an['total_gmv']}")
    print(f"  ✓ Delivered Orders: {an['delivered_orders']}")
    print(f"  ✓ Stores: {an['stores_count']} | Delivery Fleet: {an['delivery_count']}")

    print("\n" + "=" * 60)
    print("  🎉 ALL 15 CORE WORKFLOW STEPS PASSED WITH 100% SUCCESS!")
    print("=" * 60)
    db.close()

if __name__ == "__main__":
    run_tests()
