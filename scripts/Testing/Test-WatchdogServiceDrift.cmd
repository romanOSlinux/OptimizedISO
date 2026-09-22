@echo off
setlocal EnableDelayedExpansion
title romanOS Service Drift Watchdog Unit Tests

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%Test-WatchdogServiceDrift.ps1"

if not exist "%PS_SCRIPT%" (
    echo [ERROR] No se encontro Test-WatchdogServiceDrift.ps1 en:
    echo         "%PS_SCRIPT%"
    pause
    exit /b 1
)

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*

set "EXIT_CODE=%errorlevel%"
if %EXIT_CODE% neq 0 (
    echo.
    echo [AVISO] La bateria de pruebas finalizo con fallos. Codigo: %EXIT_CODE%
    pause
)

exit /b %EXIT_CODE%
