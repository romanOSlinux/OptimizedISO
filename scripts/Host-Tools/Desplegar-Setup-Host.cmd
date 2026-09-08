@echo off
setlocal EnableDelayedExpansion

REM ======================================================================
REM  Lanzador de Suite de Despliegue Post-Instalacion (Dev-IA & Gaming)
REM  romanOS Workstation Setup - Edicion AMD Ryzen 5 8600G
REM
REM  Cumplimiento de Reglas:
REM    - Regla 1: Entorno nativo Windows y elevacion UAC transparente
REM    - Regla 4: Modo grafico STA obligatorio (-STA) en PowerShell 5.1
REM ======================================================================

title romanOS Workstation Setup - Despliegue Host

REM ----------------------------------------------------------------------
REM 1. Verificacion y Auto-elevacion de privilegios de Administrador [UAC]
REM ----------------------------------------------------------------------
if "%ROMANOS_DEV_TEST%"=="1" goto :Elevated
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo ======================================================================
    echo   Solicitando privilegios de Administrador [UAC]...
    echo ======================================================================
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
:Elevated

REM ----------------------------------------------------------------------
REM 2. Resolucion dinamica de la ruta del script PowerShell
REM ----------------------------------------------------------------------
set "PS_SCRIPT="

if exist "%~dp0Desplegar-Setup-Host.ps1" (
    set "PS_SCRIPT=%~dp0Desplegar-Setup-Host.ps1"
) else if exist "%WINDIR%\Setup\Scripts\Desplegar-Setup-Host.ps1" (
    set "PS_SCRIPT=%WINDIR%\Setup\Scripts\Desplegar-Setup-Host.ps1"
) else if exist "C:\Windows\Setup\Scripts\Desplegar-Setup-Host.ps1" (
    set "PS_SCRIPT=C:\Windows\Setup\Scripts\Desplegar-Setup-Host.ps1"
) else if exist "%WINDIR%\Setup\Scripts\Host-Tools\Desplegar-Setup-Host.ps1" (
    set "PS_SCRIPT=%WINDIR%\Setup\Scripts\Host-Tools\Desplegar-Setup-Host.ps1"
) else if exist "C:\OptimizedISO\scripts\Host-Tools\Desplegar-Setup-Host.ps1" (
    set "PS_SCRIPT=C:\OptimizedISO\scripts\Host-Tools\Desplegar-Setup-Host.ps1"
)

if not defined PS_SCRIPT (
    echo.
    echo [ERROR] No se encontro el archivo Desplegar-Setup-Host.ps1.
    echo Verifique que el script se encuentre en la misma carpeta o en %%WINDIR%%\Setup\Scripts.
    echo.
    if "%ROMANOS_DEV_TEST%"=="1" exit /b 1
    pause
    exit /b 1
)

REM ----------------------------------------------------------------------
REM 3. Invocacion de PowerShell con soporte STA y ExecutionPolicy Bypass
REM ----------------------------------------------------------------------
if "%ROMANOS_DEV_TEST%"=="1" (
    echo [DEV-TEST] Verificacion de existencia de script completada: %PS_SCRIPT%
    exit /b 0
)

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"

echo.
echo ======================================================================
echo   Asistente de configuracion de romanOS finalizado.
echo ======================================================================
pause
