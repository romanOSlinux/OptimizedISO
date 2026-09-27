@echo off
setlocal
title romanOS - Supervision de VM Hyper-V (PLAN-0132)

echo ==========================================================================
echo  romanOS - Supervision en Vivo y Telemetria de VM (PLAN-0132)
echo ==========================================================================
echo.

if exist "%~dp0Watch-TestVMDeployment.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Watch-TestVMDeployment.ps1" %*
) else (
    echo [ERROR] No se encontro Watch-TestVMDeployment.ps1 en: %~dp0
    pause
    exit /b 1
)

echo.
pause
