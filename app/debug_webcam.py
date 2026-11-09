import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import cv2
import numpy as np
from app.ocr_engine import get_ocr_engine

img = cv2.imread('app/debug_uploads/latest_scan.jpg')
print(f"Image shape: {img.shape}")

t0 = time.time()
engine = get_ocr_engine()
t_init = time.time() - t0
print(f"Engine get time: {t_init:.3f}s")

t1 = time.time()
res, _ = engine(img)
t_infer = time.time() - t1
print(f"Direct inference time on full image: {t_infer:.3f}s")
print(f"Total detections: {len(res) if res else 0}")
if res:
    for i, r in enumerate(res):
        print(f"[{i+1}] '{r[1]}' (conf: {float(r[2]):.2f}) at box: {r[0]}")
