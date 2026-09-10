@echo off
:: Lanzador STA para romanOS Studio (WPF)
:: Protege el runtime exigiendo PowerShell 5.1 y Single-Threaded Apartment
echo Lanzando romanOS Studio GUI...
PowerShell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\GUI\romanOS-Studio.ps1"

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] romanOS Studio se cerro con codigo de error %ERRORLEVEL%.
    pause
)