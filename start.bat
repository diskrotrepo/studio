@echo off
:: studio///diskrot -- Start
:: Double-click this file to install or update studio///diskrot.
:: First run: installs prerequisites (WSL, Docker, NVIDIA drivers) and launches.
:: Subsequent runs: pulls latest images and restarts the stack.

cls

:: Display banner
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\banner.ps1"
echo.

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo   requesting administrator privileges...
    echo.
    powershell -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
    exit /b
)

:: Run the installer (auto-detects install vs update)
echo   initializing...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0installer\install.ps1"
pause
