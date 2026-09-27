@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%romanOS-ControlCenter.ps1" %*
exit /b %errorlevel%
