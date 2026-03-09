@echo off
:: studio///diskrot -- Developer Environment Setup (Windows)
::
:: Installs development prerequisites, configures the environment, fetches
:: dependencies, runs code generation, and starts supporting Docker services.
::
:: Usage:
::   setup-dev.bat                Full setup
::   setup-dev.bat --skip-docker  Skip Docker install & service startup

setlocal

:: Map --skip-docker flag to PowerShell parameter
set "PS_ARGS="
:parse_args
if "%~1"=="" goto :run
if /i "%~1"=="--skip-docker" (set "PS_ARGS=-SkipDocker" & shift & goto :parse_args)
if /i "%~1"=="-h" (goto :show_help)
if /i "%~1"=="--help" (goto :show_help)
shift
goto :parse_args

:run
powershell -ExecutionPolicy Bypass -File "%~dp0setup-dev.ps1" %PS_ARGS%
exit /b %ERRORLEVEL%

:show_help
echo studio///diskrot -- Developer Environment Setup (Windows)
echo.
echo Usage:
echo   setup-dev.bat                Full setup
echo   setup-dev.bat --skip-docker  Skip Docker install ^& service startup
exit /b 0
