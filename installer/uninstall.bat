@echo off
:: studio///diskrot — Uninstaller
:: Double-click to stop the stack and optionally remove data.

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
    exit /b
)

:: Run the PowerShell installer in uninstall mode
powershell -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall
pause
