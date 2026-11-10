@echo off
title Clipwave Flutter Mobile App (Preview)
echo ===================================================
echo   Starting Clipwave Flutter Mobile App in Chrome
echo ===================================================

cd /d "%~dp0"
flutter run -d chrome
pause
