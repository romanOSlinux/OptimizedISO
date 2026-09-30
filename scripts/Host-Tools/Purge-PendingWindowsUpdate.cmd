@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-STA -NoProfile -ExecutionPolicy Bypass -File \"\"%SCRIPT_DIR%Purge-PendingWindowsUpdate.ps1\"\"' -Verb RunAs"
exit /b 0
