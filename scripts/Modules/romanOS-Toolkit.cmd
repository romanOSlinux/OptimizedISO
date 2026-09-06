@echo off
title romanOS Toolkit Maestro - Panel de Optimizacion y SysAdmin
echo.
echo ======================================================================
echo   romanOS Toolkit Maestro - Hub Central de SysAdmin y Rendimiento
echo   Ejecucion automatica con elevacion y Bypass de ExecutionPolicy
echo ======================================================================
echo.

:: Comprobar privilegios de Administrador y auto-elevar
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Solicitando elevacion de privilegios de Administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b 0
)

cd /d "%~dp0"

if exist "%~dp0romanOS-Toolkit.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0romanOS-Toolkit.ps1" %*
) else if exist "%WINDIR%\Setup\Scripts\romanOS-Toolkit.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%WINDIR%\Setup\Scripts\romanOS-Toolkit.ps1" %*
) else if exist "C:\Windows\Setup\Scripts\romanOS-Toolkit.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "C:\Windows\Setup\Scripts\romanOS-Toolkit.ps1" %*
) else (
    echo [ERROR] No se encontro romanOS-Toolkit.ps1 en el directorio actual: %~dp0
    pause
    exit /b 1
)

echo.
