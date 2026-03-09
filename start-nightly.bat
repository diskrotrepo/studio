@echo off
:: studio///diskrot -- Start the stack using nightly (dev-channel) images
::
:: Pulls and runs images built from the main branch instead of stable.
:: Useful for testing the latest changes before they land in a release.
::
:: Usage:
::   start-nightly.bat              Pull nightly images and start the stack
::   start-nightly.bat --gpu        Include GPU compose overlay
::   start-nightly.bat --cpu        Skip GPU compose overlay even if .env enables it
::   start-nightly.bat --pull-only  Pull images without starting services

cls

:: Display banner
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\banner.ps1"
echo.
echo   [nightly] dev-channel images from main branch
echo.

setlocal enabledelayedexpansion

pushd "%~dp0"

:: ── Parse arguments ─────────────────────────────────────────────────
set "FORCE_GPU="
set "PULL_ONLY=0"

:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="--gpu"       (set "FORCE_GPU=yes" & shift & goto :parse_args)
if /i "%~1"=="--cpu"       (set "FORCE_GPU=no" & shift & goto :parse_args)
if /i "%~1"=="--pull-only" (set "PULL_ONLY=1" & shift & goto :parse_args)
if /i "%~1"=="-h"          (goto :show_help)
if /i "%~1"=="--help"      (goto :show_help)
echo [nightly] Unknown flag: %~1
popd
exit /b 1
:args_done

:: ── Compose file list ───────────────────────────────────────────────
set "COMPOSE_FILES=-f docker-compose.yml -f docker-compose.nightly.yml"

set "USE_GPU=0"
if "%FORCE_GPU%"=="yes" (
    set "USE_GPU=1"
) else if not "%FORCE_GPU%"=="no" (
    if exist .env (
        findstr /C:"docker-compose.gpu.yml" .env >nul 2>&1 && set "USE_GPU=1"
    )
)

if "%USE_GPU%"=="1" (
    if exist docker-compose.gpu.yml (
        set "COMPOSE_FILES=!COMPOSE_FILES! -f docker-compose.gpu.yml"
        echo [nightly] GPU overlay enabled
    )
)

:: ── Pull ────────────────────────────────────────────────────────────
echo [nightly] Pulling dev-channel images...
docker compose %COMPOSE_FILES% pull
if errorlevel 1 (
    echo [nightly] Pull failed.
    popd
    exit /b 1
)

if "%PULL_ONLY%"=="1" (
    echo [nightly] Pull complete.
    popd
    exit /b 0
)

:: ── Start ───────────────────────────────────────────────────────────
echo [nightly] Starting stack...
docker compose %COMPOSE_FILES% up -d
if errorlevel 1 (
    echo [nightly] Failed to start stack.
    popd
    exit /b 1
)

:: Read UI_PORT from .env (default 3000)
set "UI_PORT=3000"
if exist .env (
    for /f "tokens=1,2 delims==" %%a in (.env) do (
        if "%%a"=="UI_PORT" set "UI_PORT=%%b"
    )
)

echo [nightly] Stack is up.  UI: http://localhost:%UI_PORT%
popd
exit /b 0

:show_help
echo studio///diskrot -- Start the stack using nightly (dev-channel) images
echo.
echo Pulls and runs images built from the main branch instead of stable.
echo Useful for testing the latest changes before they land in a release.
echo.
echo Usage:
echo   start-nightly.bat              Pull nightly images and start the stack
echo   start-nightly.bat --gpu        Include GPU compose overlay
echo   start-nightly.bat --cpu        Skip GPU compose overlay
echo   start-nightly.bat --pull-only  Pull images without starting services
popd
exit /b 0
