@echo off
setlocal EnableDelayedExpansion
title romanOS - Hotfix Menus Contextuales (PLAN-0031)
echo ======================================================================
echo   romanOS - Aplicar Correccion de Menus Contextuales (PLAN-0031)
echo ======================================================================
echo.

:: Comprobar privilegios de Administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Solicitando elevacion de Administrador (UAC)...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b 0
)

echo [*] Privilegios de Administrador confirmados.
echo [*] Aplicando correccion en ambito Global (AllUsers / HKLM)...
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Add-OptimizedContextMenus.ps1" -Apply -EnableClassicMenu -Scope AllUsers -Quiet

echo [*] Aplicando correccion y saneamiento en ambito Usuario Actual (CurrentUser / HKCU)...
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Add-OptimizedContextMenus.ps1" -Apply -EnableClassicMenu -Scope CurrentUser -Quiet

echo [*] Reiniciando Explorador de Windows...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1; if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }"

echo.
echo ======================================================================
echo   [OK] Menus contextuales corregidos y 100% operativos.
echo   Presione cualquier tecla para cerrar.
echo ======================================================================
pause >nul
