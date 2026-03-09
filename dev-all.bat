@echo off
:: studio///diskrot -- Build ALL images from source (Windows)
::
:: Builds every custom Docker image from local source and starts the stack.
:: For backend + UI only, use dev.bat instead.
::
:: Usage:
::   dev-all.bat                        Build all images and start the stack
::   dev-all.bat --no-cache             Rebuild without Docker layer cache
::   dev-all.bat --build-only           Build images without starting services
::   dev-all.bat studio-backend         Build ^& start only named service(s)
::
:: Flags:
::   --no-cache      Pass --no-cache to docker compose build
::   --build-only    Build images and exit (don't start services)
::   --gpu           Force GPU compose overlay (auto-detected from .env)
::   --cpu           Skip GPU compose overlay even if .env enables it

setlocal enabledelayedexpansion

pushd "%~dp0"

:: ── Parse arguments ─────────────────────────────────────────────────
set "NO_CACHE="
set "BUILD_ONLY=0"
set "FORCE_GPU="
set "SERVICES="

:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="--no-cache"   (set "NO_CACHE=--no-cache" & shift & goto :parse_args)
if /i "%~1"=="--build-only" (set "BUILD_ONLY=1" & shift & goto :parse_args)
if /i "%~1"=="--gpu"        (set "FORCE_GPU=yes" & shift & goto :parse_args)
if /i "%~1"=="--cpu"        (set "FORCE_GPU=no" & shift & goto :parse_args)
if /i "%~1"=="-h"           (goto :show_help)
if /i "%~1"=="--help"       (goto :show_help)
:: Anything else is a service name
set "SERVICES=!SERVICES! %~1"
shift
goto :parse_args
:args_done

:: ── Compose file list ───────────────────────────────────────────────
set "COMPOSE_FILES=-f docker-compose.yml -f docker-compose.dev.yml"

set "USE_GPU=0"
if "%FORCE_GPU%"=="yes" (
    set "USE_GPU=1"
) else if not "%FORCE_GPU%"=="no" (
    :: Auto-detect from .env
    if exist .env (
        findstr /C:"docker-compose.gpu.yml" .env >nul 2>&1 && set "USE_GPU=1"
    )
)

if "%USE_GPU%"=="1" (
    if exist docker-compose.gpu.yml (
        set "COMPOSE_FILES=!COMPOSE_FILES! -f docker-compose.gpu.yml"
        echo [dev] GPU overlay enabled
    )
)

:: ── Export build metadata ──────────────────────────────────────────
:: PowerShell one-liner for UTC ISO-8601 timestamp
for /f "usebackq delims=" %%d in (`powershell -NoProfile -Command "[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')"`) do set "BUILD_DATE=%%d"
:: Current git branch
for /f "usebackq delims=" %%b in (`git rev-parse --abbrev-ref HEAD 2^>nul`) do set "BUILD_BRANCH=%%b"
if not defined BUILD_BRANCH set "BUILD_BRANCH=dev"

:: ── Build ───────────────────────────────────────────────────────────
echo [dev] Building images locally...
if not "%SERVICES%"=="" echo [dev] Services:%SERVICES%

docker compose %COMPOSE_FILES% build %NO_CACHE% %SERVICES%
if errorlevel 1 (
    echo [dev] Build failed.
    popd
    exit /b 1
)

if "%BUILD_ONLY%"=="1" (
    echo [dev] Build complete.
    popd
    exit /b 0
)

:: ── Start ───────────────────────────────────────────────────────────
echo [dev] Starting stack...
docker compose %COMPOSE_FILES% up -d %SERVICES%
if errorlevel 1 (
    echo [dev] Failed to start stack.
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

echo [dev] Stack is up.  UI: http://localhost:%UI_PORT%
popd
exit /b 0

:show_help
echo studio///diskrot -- Build ALL images from source (Windows)
echo For backend + UI only, use dev.bat instead.
echo.
echo Usage:
echo   dev-all.bat                        Build all images and start the stack
echo   dev-all.bat --no-cache             Rebuild without Docker layer cache
echo   dev-all.bat --build-only           Build images without starting services
echo   dev-all.bat studio-backend         Build ^& start only named service(s)
echo.
echo Flags:
echo   --no-cache      Pass --no-cache to docker compose build
echo   --build-only    Build images and exit (don't start services)
echo   --gpu           Force GPU compose overlay
echo   --cpu           Skip GPU compose overlay
popd
exit /b 0
