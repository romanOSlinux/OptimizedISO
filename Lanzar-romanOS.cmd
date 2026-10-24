@echo off
setlocal EnableDelayedExpansion
:: ======================================================================
:: romanOS - Lanzador Universal Win32 (Bootstrap Tri-Modal)
:: Regla 4: Estrictamente UTF-8 No-BOM / ANSI para cmd.exe
:: Auto-elevacion transparente de privilegios UAC y despacho STA
:: ======================================================================

title romanOS - Punto de Entrada Universal

:: 1. Comprobacion de elevacion y auto-elevacion UAC
if "%ROMANOS_DEV_TEST%"=="1" goto :Elevated
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo ======================================================================
    echo   romanOS: Solicitando privilegios de Administrador [UAC]...
    echo ======================================================================
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b 0
)

:Elevated
cd /d "%~dp0"

:: 2. Deteccion de Lanzar-romanOS.ps1 o Control Center local
if exist "%~dp0Lanzar-romanOS.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Lanzar-romanOS.ps1" %*
    exit /b %errorlevel%
)

if exist "%~dp0Lanzar-romanOS-ControlCenter.exe" (
    start "" "%~dp0Lanzar-romanOS-ControlCenter.exe" %*
    exit /b 0
)

if exist "%~dp0scripts\GUI\romanOS-ControlCenter.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\GUI\romanOS-ControlCenter.ps1" %*
    exit /b %errorlevel%
)

:: 3. Contingencia Web (si no existen archivos locales y no es prueba interna)
echo [!] Archivos locales no detectados. Intentando inicio Web 1-Liner...
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13; irm 'https://raw.githubusercontent.com/romanOSlinux/OptimizedISO/main/Lanzar-romanOS.ps1' | iex"
exit /b %errorlevel%