@echo off
setlocal EnableDelayedExpansion

REM ======================================================================
REM  Compilador 1-Clic de ISO romanOS Universal
REM  Preset: Preset_Gaming_Universal.json (Perfil 3 Hardcore, Universal)
REM
REM  Cumplimiento de Reglas:
REM    - Regla 1: Entorno nativo Windows y elevacion UAC transparente
REM    - Regla 4: Modo grafico STA obligatorio (-STA) en PowerShell 5.1
REM    - Regla 20: Principio de Producto Universal (Cero supuestos de hardware o usuario)
REM ======================================================================

title romanOS - Compilar ISO Universal

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
REM 2. Directorio de trabajo en la raiz del repositorio
REM ----------------------------------------------------------------------
cd /d "%~dp0"

echo.
echo ======================================================================
echo   romanOS ISO Builder - Compilacion Universal Automatizada
echo   Preset: Preset_Gaming_Universal.json
echo ======================================================================
echo.

set "PRESET_FILE=%~dp0Preset_Gaming_Universal.json"

if not exist "%PRESET_FILE%" (
    echo [ERROR] No se encontro el archivo de preset:
    echo         "%PRESET_FILE%"
    echo.
    if "%ROMANOS_DEV_TEST%"=="1" exit /b 1
    pause
    exit /b 1
)

set "BUILDER_SCRIPT=%~dp0scripts\Builder\New-OptimizedWindowsISO-v2.ps1"

if not exist "%BUILDER_SCRIPT%" (
    echo [ERROR] No se encontro el script de compilacion:
    echo         "%BUILDER_SCRIPT%"
    echo.
    if "%ROMANOS_DEV_TEST%"=="1" exit /b 1
    pause
    exit /b 1
)

REM ----------------------------------------------------------------------
REM 3. Invocacion del Builder con PresetFile y modo STA
REM ----------------------------------------------------------------------
if "%ROMANOS_DEV_TEST%"=="1" (
    echo [DEV-TEST] Verificacion de archivos completada exitosamente.
    echo [DEV-TEST] Builder: %BUILDER_SCRIPT%
    echo [DEV-TEST] Preset : %PRESET_FILE%
    exit /b 0
)

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%BUILDER_SCRIPT%" -PresetFile "%PRESET_FILE%"

echo.
echo ======================================================================
echo   Proceso de compilacion de romanOS finalizado.
echo ======================================================================
pause
