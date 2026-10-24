@echo off
title Lanzador: Build-ProductionPackage
echo.
echo ======================================================================
echo   romanOS - Empaquetador de Distribucion Oficial Portable y USB
echo   Ejecucion automatica con elevacion y Bypass de ExecutionPolicy
echo ======================================================================
echo.

:: Comprobar privilegios de Administrador y auto-elevar si es necesario
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Solicitando elevacion de privilegios de Administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b 0
)

cd /d "%~dp0"

if exist "%~dp0Build-ProductionPackage.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-ProductionPackage.ps1" %*
) else (
    echo [ERROR] No se encontro Build-ProductionPackage.ps1 en el directorio: %~dp0
    pause
    exit /b 1
)

echo.
echo ======================================================================
echo   Empaquetado finalizado. Presione cualquier tecla para cerrar...
echo ======================================================================
pause >nul
