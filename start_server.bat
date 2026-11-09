@echo off
title Smart Cart AI - Kirana Platform Server
color 0A
cls
echo ======================================================================
echo           SMART CART AI - HYPERLOCAL GROCERY PLATFORM
echo ======================================================================
echo.

:: Detect current Wi-Fi IPv4 address
for /f "tokens=4" %%a in ('route print ^| findstr 0.0.0.0 ^| findstr /v "0.0.0.0.*0.0.0.0"') do (
    set LOCAL_IP=%%a
)

echo [INFO] Detected Local Network IP: %LOCAL_IP%
echo [INFO] Starting FastAPI Backend + Web App Server on port 8000...
echo.
echo ----------------------------------------------------------------------
echo  * On This Computer (Browser):  http://127.0.0.1:8000
echo  * On Android Mobile (Wi-Fi):   http://%LOCAL_IP%:8000
echo  * Interactive Swagger Docs:    http://127.0.0.1:8000/docs
echo  * Download Mobile APK:         http://%LOCAL_IP%:8000/static/SmartCart-Release.apk
echo ----------------------------------------------------------------------
echo.

:: Open the browser automatically after 2 seconds
start "" cmd /c "timeout /t 2 /nobreak >nul & start http://127.0.0.1:8000"

:: Start the Python backend server
python run.py

pause

