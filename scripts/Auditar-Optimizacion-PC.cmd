@echo off
rem ==============================================================================
rem romanOS - Lanzador Inteligente de Auditoria y Optimizacion de PC
rem ==============================================================================
chcp 65001 >nul
setlocal enabledelayedexpansion

title romanOS - Auditor Universal de Optimizacion

set "SCRIPT_PS1="
if exist "%~dp0Modules\Audit-SystemOptimization.ps1" (
    set "SCRIPT_PS1=%~dp0Modules\Audit-SystemOptimization.ps1"
) else if exist "%~dp0Audit-SystemOptimization.ps1" (
    set "SCRIPT_PS1=%~dp0Audit-SystemOptimization.ps1"
) else if exist "%WINDIR%\Setup\Scripts\Modules\Audit-SystemOptimization.ps1" (
    set "SCRIPT_PS1=%WINDIR%\Setup\Scripts\Modules\Audit-SystemOptimization.ps1"
) else if exist "%WINDIR%\Setup\Scripts\Audit-SystemOptimization.ps1" (
    set "SCRIPT_PS1=%WINDIR%\Setup\Scripts\Audit-SystemOptimization.ps1"
) else if exist "C:\Windows\Setup\Scripts\Modules\Audit-SystemOptimization.ps1" (
    set "SCRIPT_PS1=C:\Windows\Setup\Scripts\Modules\Audit-SystemOptimization.ps1"
) else if exist "C:\Windows\Setup\Scripts\Audit-SystemOptimization.ps1" (
    set "SCRIPT_PS1=C:\Windows\Setup\Scripts\Audit-SystemOptimization.ps1"
)

net session >nul 2>&1
if %errorlevel% equ 0 (
    echo.
    echo ==============================================================================
    echo   romanOS AUDITOR UNIVERSAL - MODO ELEVADO (ADMINISTRADOR)
    echo ==============================================================================
    echo.
    if defined SCRIPT_PS1 (
        powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "!SCRIPT_PS1!" %*
    ) else (
        echo [ERROR] No se encontro Audit-SystemOptimization.ps1
    )
    goto :fin
)

echo.
echo ==============================================================================
echo   romanOS AUDITOR UNIVERSAL DE OPTIMIZACION
echo ==============================================================================
echo   [i] Privilegios Actuales: Usuario Estandar (Medium Integrity Level)
echo.
echo   Para una auditoria completa del 100%% (incluyendo arranque BCD, DirectStorage
echo   BypassIO en NVMe y memoria avanzada), se recomienda ejecutar como Administrador.
echo ==============================================================================
echo.
echo   [1] Elevar Privilegios Automaticamente (Recomendado - Dialogo UAC)
echo   [2] Continuar en Modo Estandar (Auditoria rapida de permisos legibles)
echo   [0] Salir
echo.
set /p "modo=  Seleccione una opcion [1/2/0] (Default: 1): "
if not defined modo set modo=1

if "%modo%"=="1" (
    echo.
    echo   Solicitando elevacion UAC...
    powershell.exe -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\" %*' -Verb RunAs"
    exit /b 0
)

if "%modo%"=="2" (
    echo.
    if defined SCRIPT_PS1 (
        powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "!SCRIPT_PS1!" %*
    ) else (
        echo [ERROR] No se encontro Audit-SystemOptimization.ps1
    )
    goto :fin
)

if "%modo%"=="0" (
    exit /b 0
)

if defined SCRIPT_PS1 (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "!SCRIPT_PS1!" %*
) else (
    echo [ERROR] No se encontro Audit-SystemOptimization.ps1
)

:fin
echo.
pause
