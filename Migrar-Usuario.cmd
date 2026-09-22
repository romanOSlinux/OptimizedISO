@echo off
:: ==========================================================================
:: Migrar Usuario Local
:: romanOS / OptimizedISO
:: ==========================================================================

:: --- Auto-Elevacion de Privilegios UAC ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Solicitando permisos de Administrador [UAC]...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b 0
)

pushd "%CD%"
cd /d "%~dp0"

:: --- Invocacion a PowerShell ---
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Modules\Migrar-Usuario-W11.ps1"

