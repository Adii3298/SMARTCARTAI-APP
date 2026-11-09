# 🛒 Smart Cart AI — Hyperlocal Kirana Platform

Smart Cart AI is a mobile-responsive web application designed to empower and promote local Kirana store sales by seamlessly connecting **Customers**, **Local Kirana Merchants**, **Delivery Partners**, and **Platform Admins**.

> **STRICT TECH STACK COMPLIANCE:**
> - **100% Python-Backed:** FastAPI + Uvicorn + SQLAlchemy ORM + SQLite
> - **Computer Vision & NLP:** OpenCV, Pillow, and intelligent grocery NLP parser
> - **Frontend:** Responsive HTML5, Tailwind CSS, Vanilla JavaScript (Mobile-First with togglable phone frame)
> - **ZERO JVM:** Strictly NO Java, NO Spring Boot, and NO JVM technologies.

---

## 🌟 Key Modules & Features

### 1. 4-Role Authentication & Registration System
- **4 Distinct Roles:** Customer, Merchant (Kirana Owner), Delivery Partner, and Platform Admin.
- **Step 1 (Registration):** Register with contact details and role-specific fields (Store name & UPI for Merchant; Vehicle plate for Delivery Partner). Upon registration, the system auto-generates credentials (`CUST1001`, `MERC2001`, etc.) and displays a simulated SMS modal on screen.
- **Step 2 & 3 (Login & Interactive CAPTCHA):** Dynamic alphanumeric CAPTCHA with noise and wave distortion generated using Pillow. Verifies CAPTCHA before authenticating.
- **1-Click Demo Switcher:** Top bar lets evaluators instantaneously switch between all 4 roles to test without retyping credentials every time!

### 2. Complete Customer Order Flow (15-Step Main Process)
1. **Steps 1–3 (Upload & AI Extraction):** 
   - Customer captures photo, uploads image, or picks a 1-click realistic sample handwritten list (*Weekly Kirana Ration* or *Daily Essentials*).
   - Computer vision identifies text lines using OpenCV adaptive thresholding and contours.
   - Smart Kirana NLP extracts Product Name, Brand, Quantity (numbers, fractions like `1/2`), and Units (`kg`, `g`, `l`, `packet`, `piece`).
   - Customer can review and edit extracted items in a clean table before proceeding.
2. **Steps 4–5 (Store Selection & Pricing):**
   - Customer selects a registered local kirana store in their area (e.g. *Gupta Kirana Store* vs. *Shree Laxmi Daily Mart*).
   - Real-time inventory check compares products against the store's catalog.
   - Shows unit prices, subtotals, unavailable items, and total bill.
   - If an item is missing (e.g. *Fortune Mustard Oil* out of stock at Store 2), a 1-click store switcher prompt lets the customer change stores!
3. **Steps 6–8 (Order Submission & Packing):**
   - Customer sends order to Merchant.
   - Merchant receives order in their dashboard, checks and packs items, adjusts quantities if needed, and confirms the final bill.
4. **Steps 9–10 (Customer Acceptance & Delivery Trigger):**
   - Customer receives merchant's packed bill, selects payment (`COD` or `UPI`), and accepts.
   - System generates a unique 6-digit delivery verification OTP code (e.g., `482910`).
   - Simultaneously broadcasts a pickup request to nearby delivery partners.
5. **Steps 11–15 (Delivery & 6-Digit Code Verification):**
   - Delivery partner accepts gig and sees store pickup location and customer address.
   - Customer tracks live ETA countdown (15 mins) and views their unique 6-digit delivery code.
   - Upon arrival, customer shares their 6-digit code with the delivery partner.
   - Delivery partner enters the code to verify. Once verified, order is marked `DELIVERED`!

### 3. Role-Specific Dashboards
- **Customer Dashboard:** OCR upload, interactive list review, store picker, live active order tracker with 6-digit OTP code, and past order history.
- **Merchant Dashboard:** Real-time orders board (New, Packing, Delivered), interactive packing interface, and a **Real-Time Product & Brand Inventory Manager** (search, category filter, unit price editor, stock quantity editor, and instant In-Stock / Out-of-Stock toggle switch).
- **Delivery Partner Dashboard:** Online/Offline toggle, available delivery gigs with route details & fees (+₹45), active gig routing screen with customer call button, 6-digit OTP code verification modal, and completed deliveries earnings.
- **Admin Dashboard:** Platform KPI metrics (Total GMV, Orders, Stores, Fleet, Customers), Smart Cart Nodes manager, Users Directory with active/deactive toggle, and real-time Activity Logs stream.

---

## 🚀 Quick Start Guide

### Prerequisites
- Python 3.10+ (tested and running on Python 3.14)
- Pip

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Run the Application
```bash
python run.py
```
Open your browser at:
👉 **`http://127.0.0.1:8000`**

---

## 🔑 Pre-Seeded Demo Accounts (1-Click Switch Available)

| Role | User ID / Mobile | Password | Name / Details |
| :--- | :--- | :--- | :--- |
| **Customer** | `CUST1001` or `9876543210` | `cust123` | Pooja Sharma (Indiranagar) |
| **Merchant** | `MERC2001` or `9845012345` | `merc123` | Ramesh Gupta (Gupta Kirana Store) |
| **Merchant 2** | `MERC2002` or `9845098765` | `merc123` | Suresh Patel (Shree Laxmi Daily Mart) |
| **Delivery** | `DELV3001` or `9731011223` | `delv123` | Vikram Singh (Bike KA-04-EK-9821) |
| **Admin** | `ADMN1000` or `9999900000` | `admin123` | Smart Cart Platform Administrator |

> **Pro-Tip:** Use the top bar **"QUICK SWITCH"** pills (`🛒 Customer`, `🏪 Merchant`, `🛵 Delivery`, `⚡ Admin`) to instantly jump between dashboards with one click!

---

## 📁 Project Directory Structure
```
smart-cart-ai/
├── app/
│   ├── __init__.py
│   ├── database.py           # SQLite connection & SQLAlchemy Base
│   ├── models.py             # User, Store, ProductInventory, SmartCartNode, Order, OrderItem
│   ├── schemas.py            # Pydantic models for validation
│   ├── auth.py               # CAPTCHA generator, password hashing, OTP & ID generator
│   ├── ocr_engine.py         # OpenCV image preprocessing & NLP Kirana parser
│   ├── seed_data.py          # Initial demo data (stores, items, users, nodes)
│   ├── main.py               # FastAPI application & REST endpoints
│   ├── static/
│   │   ├── css/custom.css    # Phone bezel, animations, OTP styling
│   │   ├── js/
│   │   │   ├── app.js        # Global app state, sync loop, toasts, role switcher
│   │   │   ├── auth.js       # Register, login, CAPTCHA, SMS modal
│   │   │   ├── customer.js   # OCR upload, item table, store pricing, active tracker
│   │   │   ├── merchant.js   # Order packing board, inventory & brand manager
│   │   │   ├── delivery.js   # Delivery gigs, routing, 6-digit OTP verification
│   │   │   └── admin.js      # Analytics cards, node manager, users directory
│   │   └── samples/          # Sample handwritten grocery notebook images
│   └── templates/
│       └── index.html        # Responsive Single Page Application
├── run.py                    # Entry point runner script
├── test_flow.py              # Automated 15-step integration test suite
├── requirements.txt          # Python dependencies
└── README.md                 # Documentation & user manual
```

---

## 🧪 Running the Verification Suite
To verify all 15 workflow steps end-to-end:
```bash
python -u test_flow.py
```
Outputs:
```
============================================================
  🧪 SMART CART AI - END-TO-END VERIFICATION
============================================================
[Step 1] Testing CAPTCHA Generation & Validation...  ✓
[Step 2] Testing 4-Role Registration & Dummy Credential Dispatch... ✓
[Step 3] Testing Login Portal with Interactive CAPTCHA... ✓
[Step 4] Testing OCR & NLP Handwritten List Processing (Steps 1-3)... ✓
[Step 5] Testing Store Selection & Availability (Steps 4-5)... ✓
[Step 6] Testing Order Submission to Kirana Merchant (Steps 6-8)... ✓
[Step 7] Testing Customer Acceptance & Delivery Code Generation (Steps 9-10)... ✓
[Step 8] Testing Delivery Partner Pickup & 6-Digit Verification (Steps 11-15)... ✓
[Step 9] Testing Admin Dashboard Analytics... ✓
============================================================
  🎉 ALL 15 CORE WORKFLOW STEPS PASSED WITH 100% SUCCESS!
============================================================
```
