@echo off
setlocal EnableDelayedExpansion
title romanOS - Hotfix PLAN-0029 en Vivo
echo ======================================================================
echo   romanOS - Aplicar Correcciones en Vivo (PLAN-0029)
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
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "c:\OptimizedISO\scratch\apply_live_fixes.ps1"

echo.
echo ======================================================================
echo   Proceso finalizado. Presione cualquier tecla para cerrar.
echo ======================================================================
pause >nul
