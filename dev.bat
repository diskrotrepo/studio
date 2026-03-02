@echo off
:: studio///diskrot — Rebuild backend + UI from source (Windows)
::
:: Builds only studio-backend and studio-ui, then starts the full stack.
:: For all images (including acestep + yulan), use dev-all.bat instead.
::
:: Usage:
::   dev.bat              Build backend + UI and start the stack
::   dev.bat --no-cache   Rebuild without Docker layer cache
::
:: All flags from dev-all.bat are supported (--no-cache, --build-only, --gpu, --cpu).

call "%~dp0dev-all.bat" %* studio-backend studio-ui
