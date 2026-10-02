@echo off
cd /d "%~dp0"
py -3 -m venv .venv
if errorlevel 1 goto fail
type nul > .venv\.gdignore
.venv\Scripts\python.exe -m pip install -r requirements.txt
if errorlevel 1 goto fail
.venv\Scripts\python.exe -m playwright install chromium
if errorlevel 1 goto fail
echo Setup complete. Run start-windows.bat. Requires Godot 4.4+.
pause
exit /b 0
:fail
echo Setup failed. Install Python 3.10+ and check your network.
pause
exit /b 1
