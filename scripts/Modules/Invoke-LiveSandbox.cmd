@echo off
setlocal EnableDelayedExpansion
title romanOS Live Sandbox Environment Launcher

:: Comprobacion de privilegios de Administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Solicitando privilegios de Administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c `"%~f0`" %*' -Verb RunAs"
    exit /b %errorlevel%
)

:: Localizacion del script de PowerShell complementario
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%Invoke-LiveSandbox.ps1"

if not exist "%PS_SCRIPT%" (
    echo [ERROR] No se encontro el archivo Invoke-LiveSandbox.ps1 en:
    echo         "%PS_SCRIPT%"
    pause
    exit /b 1
)

:: Invocacion con Windows PowerShell 5.1 y soporte STA
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*

set "EXIT_CODE=%errorlevel%"
if %EXIT_CODE% neq 0 (
    echo.
    echo [AVISO] La ejecucion finalizo con codigo de salida: %EXIT_CODE%
    pause
)

exit /b %EXIT_CODE%
