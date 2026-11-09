#!/usr/bin/env python3
"""
Smart Cart AI - Hyperlocal Kirana Platform
Main execution script to run the Python FastAPI backend server.
100% Python-backed Tech Stack (No Java, No Spring Boot, No JVM).
"""

import sys
import os
import socket

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

import uvicorn

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

if __name__ == "__main__":
    current_dir = os.path.dirname(os.path.abspath(__file__))
    if current_dir not in sys.path:
        sys.path.insert(0, current_dir)

    local_ip = get_local_ip()

    print("=" * 68)
    print("  >> Starting Smart Cart AI Server (FastAPI + Android PWA + OpenCV)")
    print(f"  >> Local Computer:  http://127.0.0.1:8000")
    print(f"  >> On Phone (WiFi): http://{local_ip}:8000")
    print("  >> Dedicated Android App (Installable via Chrome / WebAPK on Android)")
    print("=" * 68)

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        log_level="info"
    )
