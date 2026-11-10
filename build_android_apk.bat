@echo off
title Build Clipwave Android APK
echo ===================================================
echo   Building Clipwave Mobile Native Android APK
echo ===================================================

cd /d "%~dp0"
echo Building APK (this may take a couple of minutes)...
flutter build apk --split-per-abi
echo.
echo ===================================================
echo APK build complete! Look in:
echo build\app\outputs\flutter-apk\
echo ===================================================
pause
