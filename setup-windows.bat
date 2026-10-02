@echo off
cd /d "%~dp0"
py -3 -m venv .venv
if errorlevel 1 goto fail
type nul > .venv\.gdignore
.venv\Scripts\python.exe register_native_host.py
if errorlevel 1 goto fail
echo Setup complete. Load the extension folder in chrome://extensions or edge://extensions.
echo Then run start-windows.bat. Requires Godot 4.4+ for source builds.
pause
exit /b 0
:fail
echo Setup failed. Install Python 3.10+ and check your network.
pause
exit /b 1
