import os
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import qrcode

def get_font(name="segoeui.ttf", size=18, bold=False):
    font_name = "segoeuib.ttf" if bold else "segoeui.ttf"
    candidates = [
        os.path.join(r"C:\Windows\Fonts", font_name),
        os.path.join(r"C:\Windows\Fonts", "arialbd.ttf" if bold else "arial.ttf"),
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for p in candidates:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()

def draw_rounded_rect(draw, bbox, radius, fill, outline=None, width=1):
    x1, y1, x2, y2 = bbox
    draw.rounded_rectangle([x1, y1, x2, y2], radius=radius, fill=fill, outline=outline, width=width)

# ==============================================================================
# SCREENSHOT 1: INPUT / UI (Customer App Scanning Paper Note)
# ==============================================================================
def create_input_screenshot(out_path="ppt_screenshots/screenshot_1_input_ui.png"):
    width, height = 960, 600
    img = Image.new("RGB", (width, height), color=(248, 250, 252))
    draw = ImageDraw.Draw(img)

    # Top App Bar
    draw.rectangle([(0, 0), (width, 64)], fill=(5, 150, 105)) # Emerald Green
    draw.text((24, 18), "Smart Cart AI  |  Customer Portal", font=get_font(size=20, bold=True), fill=(255, 255, 255))
    draw.text((width - 240, 22), "📍 Indiranagar, Bengaluru", font=get_font(size=14, bold=True), fill=(209, 250, 229))

    # Banner Card
    draw_rounded_rect(draw, (24, 76, width - 24, 136), 14, fill=(236, 253, 245), outline=(167, 243, 208), width=1)
    draw.text((40, 88), "📸 STEP 1: INPUT — SCAN HANDWRITTEN GROCERY NOTE", font=get_font(size=14, bold=True), fill=(4, 120, 87))
    draw.text((40, 108), "Take a photo of your paper list, pick a saved image, or select a sample ration note to check nearby stores.", font=get_font(size=12), fill=(51, 65, 85))

    # Viewfinder / Camera Frame
    frame_x, frame_y, frame_w, frame_h = 24, 148, 520, 428
    draw_rounded_rect(draw, (frame_x, frame_y, frame_x + frame_w, frame_y + frame_h), 16, fill=(15, 23, 42))

    # Place the actual handwritten note inside camera frame
    note_path = "app/static/samples/sample_weekly_ration.jpg"
    if os.path.exists(note_path):
        note_img = Image.open(note_path)
        # Resize to fit neatly inside viewfinder with margins
        note_img = note_img.resize((frame_w - 40, frame_h - 40), Image.Resampling.LANCZOS)
        img.paste(note_img, (frame_x + 20, frame_y + 20))

    # Camera viewfinder green targeting corners
    k_len, k_col, k_thick = 28, (52, 211, 153), 4
    for cx, cy in [(frame_x + 10, frame_y + 10), (frame_x + frame_w - 10, frame_y + 10),
                   (frame_x + 10, frame_y + frame_h - 10), (frame_x + frame_w - 10, frame_y + frame_h - 10)]:
        # Draw target brackets
        sx = 1 if cx == frame_x + 10 else -1
        sy = 1 if cy == frame_y + 10 else -1
        draw.line([(cx, cy), (cx + (sx * k_len), cy)], fill=k_col, width=k_thick)
        draw.line([(cx, cy), (cx, cy + (sy * k_len))], fill=k_col, width=k_thick)

    # Right Side: Input Controls & Instructions Card
    rc_x = 560
    draw_rounded_rect(draw, (rc_x, 148, width - 24, 576), 16, fill=(255, 255, 255), outline=(226, 232, 240), width=1)

    draw.text((rc_x + 16, 166), "Capture Modes Available:", font=get_font(size=15, bold=True), fill=(15, 23, 42))

    # Button 1: Live Camera
    draw_rounded_rect(draw, (rc_x + 16, 200, width - 40, 246), 12, fill=(5, 150, 105))
    draw.text((rc_x + 60, 213), "📸  Live Web/Mobile Camera", font=get_font(size=14, bold=True), fill=(255, 255, 255))

    # Button 2: Saved Photo
    draw_rounded_rect(draw, (rc_x + 16, 256, width - 40, 302), 12, fill=(241, 245, 249), outline=(203, 213, 225))
    draw.text((rc_x + 60, 269), "🖼️  Pick Saved Photo / Gallery", font=get_font(size=14, bold=True), fill=(51, 65, 85))

    # Button 3: Type List
    draw_rounded_rect(draw, (rc_x + 16, 312, width - 40, 358), 12, fill=(241, 245, 249), outline=(203, 213, 225))
    draw.text((rc_x + 60, 325), "✍️  Type / Paste Grocery List", font=get_font(size=14, bold=True), fill=(51, 65, 85))

    # 1-Click Samples Box
    draw.text((rc_x + 16, 380), "OR 1-CLICK SAMPLE PRESETS:", font=get_font(size=11, bold=True), fill=(100, 116, 139))
    draw_rounded_rect(draw, (rc_x + 16, 404, width - 40, 442), 10, fill=(254, 243, 199), outline=(252, 211, 77))
    draw.text((rc_x + 28, 416), "⚡ Weekly Ration Note (8 items selected)", font=get_font(size=12, bold=True), fill=(146, 64, 14))

    draw_rounded_rect(draw, (rc_x + 16, 452, width - 40, 490), 10, fill=(241, 245, 249), outline=(226, 232, 240))
    draw.text((rc_x + 28, 464), "⚡ Daily Essentials (6 items)", font=get_font(size=12), fill=(71, 85, 105))

    # Status Pill
    draw_rounded_rect(draw, (rc_x + 16, 516, width - 40, 556), 10, fill=(236, 253, 245), outline=(52, 211, 153))
    draw.text((rc_x + 28, 528), "● Camera Sensor Ready • 1280x720 HD", font=get_font(size=12, bold=True), fill=(4, 120, 87))

    img.save(out_path, quality=95)
    print(f"Created {out_path} ({os.path.getsize(out_path)} bytes)")

# ==============================================================================
# SCREENSHOT 2: PROCESSING (OpenCV Bounding Boxes & Store Comparison)
# ==============================================================================
def create_processing_screenshot(out_path="ppt_screenshots/screenshot_2_processing.png"):
    width, height = 960, 600
    img = Image.new("RGB", (width, height), color=(248, 250, 252))
    draw = ImageDraw.Draw(img)

    # Top App Bar
    draw.rectangle([(0, 0), (width, 64)], fill=(30, 58, 138)) # Deep Blue for processing
    draw.text((24, 18), "Smart Cart AI  |  Computer Vision & Kirana NLP Engine", font=get_font(size=19, bold=True), fill=(255, 255, 255))
    draw.text((width - 230, 22), "⚡ Latency: 1.48s (CPU)", font=get_font(size=14, bold=True), fill=(147, 197, 253))

    # Banner Card
    draw_rounded_rect(draw, (24, 76, width - 24, 136), 14, fill=(239, 246, 255), outline=(191, 219, 254), width=1)
    draw.text((40, 88), "⚙️ STEP 2: PROCESSING — OPENCV BOUNDING BOXES & STORE AVAILABILITY", font=get_font(size=14, bold=True), fill=(30, 64, 175))
    draw.text((40, 108), "RapidOCR extracts handwritten items -> NLP normalizes units -> Checks stock & prices at Navjeevan vs More Provision.", font=get_font(size=12), fill=(51, 65, 85))

    # Left: OpenCV detection with bounding boxes
    left_x, left_y, left_w, left_h = 24, 148, 440, 428
    draw_rounded_rect(draw, (left_x, left_y, left_x + left_w, left_y + left_h), 16, fill=(255, 255, 255), outline=(226, 232, 240), width=1)
    draw.text((left_x + 16, 160), "OpenCV AI Detection Bounding Boxes:", font=get_font(size=13, bold=True), fill=(15, 23, 42))

    cv_sample_path = "app/debug_uploads/cv_annotated_sample.jpg"
    if os.path.exists(cv_sample_path):
        cv_img = Image.open(cv_sample_path)
        cv_img = cv_img.resize((left_w - 32, left_h - 60), Image.Resampling.LANCZOS)
        img.paste(cv_img, (left_x + 16, left_y + 44))

    # Right: Extracted Checklist & Dual Store Comparison
    right_x = 480
    right_w = width - right_x - 24
    draw_rounded_rect(draw, (right_x, 148, right_x + right_w, 576), 16, fill=(255, 255, 255), outline=(226, 232, 240), width=1)

    draw.text((right_x + 16, 160), "Store Stock & Price Comparison (2 Stores):", font=get_font(size=14, bold=True), fill=(15, 23, 42))

    # Store 1 Card (Navjeevan Supermart - Best Match)
    s1_y = 190
    draw_rounded_rect(draw, (right_x + 14, s1_y, right_x + right_w - 14, s1_y + 165), 14, fill=(236, 253, 245), outline=(5, 150, 105), width=2)
    draw.text((right_x + 28, s1_y + 12), "🏪 Navjeevan Supermart (⭐ 4.9)", font=get_font(size=15, bold=True), fill=(4, 120, 87))

    # Recommended Badge
    draw_rounded_rect(draw, (right_x + right_w - 145, s1_y + 10, right_x + right_w - 24, s1_y + 32), 10, fill=(5, 150, 105))
    draw.text((right_x + right_w - 138, s1_y + 14), "★ RECOMMENDED", font=get_font(size=9, bold=True), fill=(255, 255, 255))

    draw.text((right_x + 28, s1_y + 40), "#45, 100 Feet Road, Indiranagar • 0.5 km away", font=get_font(size=11), fill=(71, 85, 105))

    # Availability pill
    draw_rounded_rect(draw, (right_x + 28, s1_y + 68, right_x + 240, s1_y + 94), 8, fill=(209, 250, 229))
    draw.text((right_x + 36, s1_y + 74), "✓ 8 of 8 items in stock (100%)", font=get_font(size=11, bold=True), fill=(4, 120, 87))

    draw.text((right_x + 28, s1_y + 110), "⚡ 15-min doorstep delivery", font=get_font(size=11), fill=(71, 85, 105))
    draw.text((right_x + right_w - 130, s1_y + 105), "Bill: ₹2,263.00", font=get_font(size=16, bold=True), fill=(4, 120, 87))

    # Select Button
    draw_rounded_rect(draw, (right_x + 28, s1_y + 130, right_x + right_w - 28, s1_y + 155), 8, fill=(5, 150, 105))
    draw.text((right_x + 140, s1_y + 134), "✓ Selected Store for Order", font=get_font(size=11, bold=True), fill=(255, 255, 255))

    # Store 2 Card (More Provision)
    s2_y = 370
    draw_rounded_rect(draw, (right_x + 14, s2_y, right_x + right_w - 14, s2_y + 135), 14, fill=(248, 250, 252), outline=(226, 232, 240), width=1)
    draw.text((right_x + 28, s2_y + 12), "🏪 More Provision (⭐ 4.8)", font=get_font(size=14, bold=True), fill=(30, 41, 59))
    draw.text((right_x + 28, s2_y + 36), "#12, CMH Road, Indiranagar • 1.2 km away", font=get_font(size=11), fill=(100, 116, 139))

    # Availability pill
    draw_rounded_rect(draw, (right_x + 28, s2_y + 60, right_x + 240, s2_y + 86), 8, fill=(254, 243, 199))
    draw.text((right_x + 36, s2_y + 66), "⚠️ 7 of 8 items in stock (88%)", font=get_font(size=11, bold=True), fill=(146, 64, 14))

    draw.text((right_x + 28, s2_y + 98), "⚡ 20-min delivery", font=get_font(size=11), fill=(100, 116, 139))
    draw.text((right_x + right_w - 130, s2_y + 94), "Bill: ₹1,532.00", font=get_font(size=14, bold=True), fill=(51, 65, 85))

    # Summary metrics footer
    draw_rounded_rect(draw, (right_x + 14, 520, right_x + right_w - 14, 562), 10, fill=(241, 245, 249))
    draw.text((right_x + 24, 532), "✓ 8 items extracted • Atta, Oil, Dal, Milk, Salt, Sugar, Rice, Haldi", font=get_font(size=11, bold=True), fill=(30, 41, 59))

    img.save(out_path, quality=95)
    print(f"Created {out_path} ({os.path.getsize(out_path)} bytes)")

# ==============================================================================
# SCREENSHOT 3: OUTPUT (Confirmed Bill + Dynamic UPI QR + Delivery OTP)
# ==============================================================================
def create_output_screenshot(out_path="ppt_screenshots/screenshot_3_output.png"):
    width, height = 960, 600
    img = Image.new("RGB", (width, height), color=(248, 250, 252))
    draw = ImageDraw.Draw(img)

    # Top App Bar
    draw.rectangle([(0, 0), (width, 64)], fill=(15, 23, 42)) # Slate Dark
    draw.text((24, 18), "Smart Cart AI  |  Checkout & Delivery Dispatch", font=get_font(size=19, bold=True), fill=(255, 255, 255))
    draw.text((width - 240, 22), "Order # ORD-33082", font=get_font(size=14, bold=True), fill=(52, 211, 153))

    # Banner Card
    draw_rounded_rect(draw, (24, 76, width - 24, 136), 14, fill=(236, 253, 245), outline=(167, 243, 208), width=1)
    draw.text((40, 88), "🎉 STEP 3: OUTPUT — CONFIRMED BILL, DYNAMIC UPI QR & 6-DIGIT OTP", font=get_font(size=14, bold=True), fill=(4, 120, 87))
    draw.text((40, 108), "Merchant packed order -> Customer pays via UPI / COD -> Cryptographic 6-digit delivery code verifies rider.", font=get_font(size=12), fill=(51, 65, 85))

    # Left Panel: UPI QR Payment Modal
    left_x, left_y, left_w, left_h = 24, 148, 440, 428
    draw_rounded_rect(draw, (left_x, left_y, left_x + left_w, left_y + left_h), 16, fill=(255, 255, 255), outline=(226, 232, 240), width=1)

    draw.text((left_x + 16, 162), "Pay via UPI (Navjeevan Supermart)", font=get_font(size=15, bold=True), fill=(15, 23, 42))
    draw_rounded_rect(draw, (left_x + left_w - 110, 158, left_x + left_w - 16, 186), 8, fill=(209, 250, 229))
    draw.text((left_x + left_w - 100, 164), "₹2,263.00", font=get_font(size=14, bold=True), fill=(4, 120, 87))

    # Generate real QR code image
    upi_uri = "upi://pay?pa=navjeevan@okaxis&pn=Navjeevan%20Supermart&am=2263.00&cu=INR&tn=SmartCart%20ORD-33082"
    qr = qrcode.QRCode(box_size=4, border=1)
    qr.add_data(upi_uri)
    qr.make(fit=True)
    qr_img = qr.make_image(fill_color="#0F172A", back_color="white")
    qr_img = qr_img.resize((170, 170))

    # QR background card
    draw_rounded_rect(draw, (left_x + 130, 200, left_x + 310, 380), 12, fill=(255, 255, 255), outline=(226, 232, 240), width=1)
    img.paste(qr_img, (left_x + 135, 205))

    draw.text((left_x + 105, 386), "Scan with GPay / PhonePe / Paytm / BHIM", font=get_font(size=11, bold=True), fill=(71, 85, 105))

    # VPA Box
    draw_rounded_rect(draw, (left_x + 20, 412, left_x + left_w - 20, 452), 10, fill=(248, 250, 252), outline=(226, 232, 240))
    draw.text((left_x + 32, 424), "STORE UPI ID: navjeevan@okaxis", font=get_font(size=12, bold=True), fill=(15, 23, 42))

    # Direct UPI Intent Button
    draw_rounded_rect(draw, (left_x + 20, 464, left_x + left_w - 20, 508), 12, fill=(29, 78, 216))
    draw.text((left_x + 55, 478), "🚀  Pay via UPI App (GPay / PhonePe)", font=get_font(size=13, bold=True), fill=(255, 255, 255))

    # 1-Tap Instant Simulator Button
    draw_rounded_rect(draw, (left_x + 20, 518, left_x + left_w - 20, 558), 12, fill=(5, 150, 105))
    draw.text((left_x + 60, 532), "⚡  1-Tap Instant Payment Verified", font=get_font(size=13, bold=True), fill=(255, 255, 255))

    # Right Panel: 6-Digit Delivery OTP Handshake Code
    right_x = 480
    right_w = width - right_x - 24
    draw_rounded_rect(draw, (right_x, 148, right_x + right_w, 576), 16, fill=(255, 255, 255), outline=(226, 232, 240), width=1)

    draw.text((right_x + 16, 162), "Doorstep Verification & Fleet Tracking:", font=get_font(size=14, bold=True), fill=(15, 23, 42))

    # 6-Digit Delivery OTP Card (Vibrant Green Gradient Banner)
    otp_y = 194
    draw_rounded_rect(draw, (right_x + 16, otp_y, right_x + right_w - 16, otp_y + 150), 16, fill=(5, 150, 105))
    draw.text((right_x + 100, otp_y + 14), "YOUR 6-DIGIT DELIVERY CODE", font=get_font(size=11, bold=True), fill=(167, 243, 208))

    # Big OTP Numbers
    draw.text((right_x + 95, otp_y + 42), "4 6 0 6 9 9", font=get_font(size=42, bold=True), fill=(255, 255, 255))

    draw.text((right_x + 36, otp_y + 110), "🔒 Share code with delivery partner to complete order", font=get_font(size=11, bold=True), fill=(255, 255, 255))

    # Rider Info Card
    r_y = 360
    draw_rounded_rect(draw, (right_x + 16, r_y, right_x + right_w - 16, r_y + 80), 12, fill=(241, 245, 249), outline=(226, 232, 240))
    draw.text((right_x + 28, r_y + 14), "🛵  Delivery Partner Assigned:", font=get_font(size=11, bold=True), fill=(100, 116, 139))
    draw.text((right_x + 28, r_y + 34), "Vikram Singh (Rider)", font=get_font(size=15, bold=True), fill=(15, 23, 42))
    draw.text((right_x + 28, r_y + 54), "Vehicle: KA-04-EK-9821 • Arriving in ~12 mins", font=get_font(size=11), fill=(71, 85, 105))

    # Delivery Success Banner
    s_y = 456
    draw_rounded_rect(draw, (right_x + 16, s_y, right_x + right_w - 16, s_y + 102), 12, fill=(236, 253, 245), outline=(52, 211, 153), width=1)
    draw.text((right_x + 40, s_y + 16), "✓ Order Delivered Successfully!", font=get_font(size=14, bold=True), fill=(4, 120, 87))
    draw.text((right_x + 40, s_y + 40), "OTP Handshake verified at doorstep.", font=get_font(size=11), fill=(71, 85, 105))
    draw.text((right_x + 40, s_y + 64), "Payment received by Navjeevan Supermart via UPI.", font=get_font(size=11), fill=(71, 85, 105))

    img.save(out_path, quality=95)
    print(f"Created {out_path} ({os.path.getsize(out_path)} bytes)")

if __name__ == "__main__":
    create_input_screenshot()
    create_processing_screenshot()
    create_output_screenshot()

