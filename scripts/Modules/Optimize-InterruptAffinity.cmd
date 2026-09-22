@echo off
setlocal EnableDelayedExpansion
title romanOS PCIe Interrupt Affinity and DPC Steering

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%Optimize-InterruptAffinity.ps1"

if not exist "%PS_SCRIPT%" (
    echo [ERROR] No se encontro Optimize-InterruptAffinity.ps1 en:
    echo         "%PS_SCRIPT%"
    pause
    exit /b 1
)

:: Comprobar privilegios de administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [AVISO] Solicitando elevacion de privilegios de Administrador (UAC)...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\" %*\"' -Verb RunAs"
    exit /b %errorlevel%
)

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*

set "EXIT_CODE=%errorlevel%"
if %EXIT_CODE% neq 0 (
    echo.
    echo [AVISO] El proceso finalizo con codigo: %EXIT_CODE%
    pause
)

exit /b %EXIT_CODE%
