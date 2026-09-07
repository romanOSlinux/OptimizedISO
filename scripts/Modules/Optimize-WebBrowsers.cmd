@echo off
title Optimizacion y Debloat Oficial de Navegadores Web
echo.
echo ======================================================================
echo   Optimizacion y Debloat Oficial de Navegadores (GPO)
echo   Ejecucion automatica con elevacion y Bypass de ExecutionPolicy
echo ======================================================================
echo.

:: Comprobar privilegios de Administrador y auto-elevar si es necesario
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Solicitando elevacion de privilegios de Administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\" %*' -Verb RunAs"
    exit /b 0
)

cd /d "%~dp0"

if exist "%~dp0Optimize-WebBrowsers.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Optimize-WebBrowsers.ps1" %*
) else (
    echo [ERROR] No se encontro Optimize-WebBrowsers.ps1 en el directorio actual: %~dp0
    pause
    exit /b 1
)

exit /b %errorlevel%