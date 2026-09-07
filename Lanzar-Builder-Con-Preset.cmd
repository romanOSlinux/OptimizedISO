@echo off
setlocal EnableDelayedExpansion

REM ======================================================================
REM  Lanzador con Preset Automatizado (JSON) para romanOS ISO Builder
REM
REM  Modos de uso admitidos:
REM    1. Drag and Drop: Arrastrar y soltar un archivo .json sobre este .cmd
REM    2. Linea de comandos: Lanzar-Builder-Con-Preset.cmd "ruta\al\preset.json"
REM    3. Doble clic: Menu interactivo que detecta presets en la carpeta
REM
REM  Cumplimiento de Reglas:
REM    - Regla 1: Entorno nativo Windows y elevacion UAC transparente
REM    - Regla 4: Modo grafico STA obligatorio (-STA) en PowerShell 5.1
REM ======================================================================

set "PRESET_FILE="
if not "%~1"=="" set "PRESET_FILE=%~f1"

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
    if defined PRESET_FILE (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -ArgumentList '\"%PRESET_FILE%\"' -Verb RunAs"
    ) else (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs"
    )
    exit /b
)
:Elevated

REM ----------------------------------------------------------------------
REM 2. Fijar directorio de trabajo en la raiz del repositorio
REM ----------------------------------------------------------------------
cd /d "%~dp0"
title romanOS ISO Builder - Modo Preset Automatizado

echo.
echo ======================================================================
echo   romanOS ISO Builder - Compilacion con Preset Automatizado (JSON)
echo ======================================================================
echo.

REM ----------------------------------------------------------------------
REM 3. Resolucion del Preset (Argumento vs Menu Interactivo Lineal)
REM ----------------------------------------------------------------------
if defined PRESET_FILE goto :ValidatePreset

echo [i] No se proporciono la ruta del Preset como argumento.
echo [*] Buscando archivos Preset_*.json en el repositorio...
echo.

set "count=0"
for /f "delims=" %%f in ('dir /b /a-d /o-d "Preset_*.json" 2^>nul') do (
    set /a count+=1
    set "preset_!count!=%%~ff"
    set "preset_name_!count!=%%f"
    echo   [!count!] %%f
)

if %count% leq 0 goto :NoPresetsFound

echo.
set /p "choice=Seleccione el numero de preset [Default: 1 - mas reciente] o pegue la ruta: "
if not defined choice set "choice=1"
set "choice=%choice:"=%"

set "NON_NUM="
for /f "delims=0123456789" %%a in ("%choice%") do set "NON_NUM=1"

if not defined NON_NUM (
    call set "PRESET_FILE=%%preset_%choice%%%"
    if not defined PRESET_FILE set "PRESET_FILE=%choice%"
) else (
    set "PRESET_FILE=%choice%"
)
goto :ValidatePreset

:NoPresetsFound
echo [!] No se encontraron archivos Preset_*.json en la carpeta raiz.
echo.
set /p "choice=Arrastre aqui un archivo JSON de preset o escriba su ruta: "
set "choice=%choice:"=%"
set "PRESET_FILE=%choice%"

:ValidatePreset
REM ----------------------------------------------------------------------
REM 4. Validacion estricta de la existencia fisica del archivo JSON
REM ----------------------------------------------------------------------
if not defined PRESET_FILE (
    echo.
    echo [ERROR] No se especifico ningun archivo de preset.
    echo Operacion cancelada.
    echo.
    if "%ROMANOS_DEV_TEST%"=="1" exit /b 1
    pause
    exit /b 1
)

if not exist "%PRESET_FILE%" (
    echo.
    echo [ERROR] No se pudo encontrar el archivo de preset especificado:
    echo         "%PRESET_FILE%"
    echo.
    echo Verifique que la ruta sea correcta o que el archivo no haya sido movido.
    echo.
    if "%ROMANOS_DEV_TEST%"=="1" exit /b 1
    pause
    exit /b 1
)

echo.
echo [OK] Preset validado: "%PRESET_FILE%"
echo [*] Iniciando New-OptimizedWindowsISO-v2.ps1 con el preset...
echo.

REM ----------------------------------------------------------------------
REM 5. Invocacion del Builder (STA + Bypass + PresetFile)
REM ----------------------------------------------------------------------
if "%ROMANOS_DEV_TEST%"=="1" (
    echo [DEV-TEST] Invocando PowerShell con -WhatIf / simulacion...
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "Write-Host 'Invocando Builder con PresetFile: %PRESET_FILE%'"
) else (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Builder\New-OptimizedWindowsISO-v2.ps1" -PresetFile "%PRESET_FILE%"
)

echo.
echo ======================================================================
echo   Proceso de romanOS ISO Builder finalizado.
echo ======================================================================
if "%ROMANOS_DEV_TEST%"=="1" exit /b 0
pause

