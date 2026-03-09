@echo off
:: studio///diskrot -- Start (Remote)
:: Double-click this file to install or update studio///diskrot in remote mode.
:: First run: installs prerequisites (WSL, Docker, NVIDIA drivers) and launches.
:: Subsequent runs: pulls latest images and restarts the stack.
::
:: Only starts postgres, redis, studio-backend, and studio-ui -- the minimum
:: services required to communicate with a remote studio///diskrot instance.

chcp 65001 >nul 2>&1

:: Get ESC character for ANSI codes
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"

set "C=%ESC%[36m"
set "BC=%ESC%[96m"
set "M=%ESC%[35m"
set "BM=%ESC%[95m"
set "W=%ESC%[97m"
set "DK=%ESC%[90m"
set "N=%ESC%[0m"

cls

echo.
echo %DK%  ──────────────────────────────────────────────────────────%N%
echo.
echo %BC%    ██████╗ ██╗███████╗██╗  ██╗██████╗  ██████╗ ████████╗%N%
echo %C%    ██╔══██╗██║██╔════╝██║ ██╔╝██╔══██╗██╔═══██╗╚══██╔══╝%N%
echo %BM%    ██║  ██║██║███████╗█████╔╝ ██████╔╝██║   ██║   ██║   %N%
echo %M%    ██║  ██║██║╚════██║██╔═██╗ ██╔══██╗██║   ██║   ██║   %N%
echo %BC%    ██████╔╝██║███████║██║  ██╗██║  ██║╚██████╔╝   ██║   %N%
echo %C%    ╚═════╝ ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝    ╚═╝   %N%
echo.
echo %W%                      s t u d i o///diskrot%N%
echo %DK%                        [ remote ]%N%
echo.
echo %DK%  ──────────────────────────────────────────────────────────%N%
echo %DK%       diskrot.com · 2026%N%
echo %DK%  ──────────────────────────────────────────────────────────%N%
echo.

:: Loading bar
powershell -NoProfile -Command "$h=[char]0x2593;Write-Host -NoNewline '  ';1..50|%%{Write-Host -NoNewline -ForegroundColor DarkGray $h;Start-Sleep -Milliseconds 12};Write-Host"
echo.

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo   %BC%▸%N% requesting administrator privileges...
    echo.
    powershell -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
    exit /b
)

:: Set remote compose file and run the installer
set "COMPOSE_FILE=docker-compose.remote.yml"
echo   %BC%▸%N% initializing...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0installer\install.ps1"
pause
