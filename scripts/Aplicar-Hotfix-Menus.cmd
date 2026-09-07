@echo off
:: ============================================================
:: Aplicar-Hotfix-Menus.cmd
:: PLAN-0031: Lanzador de Hotfix para Menus Contextuales Nativos
::
:: Aplica las correcciones de SubCommands y cascada nativa de
:: Add-OptimizedContextMenus.ps1 sin recompilar la ISO.
:: Requiere privilegios de Administrador.
:: ============================================================

title romanOS - Aplicar Hotfix Menus Contextuales

:: Auto-elevacion UAC si no es administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Elevando privilegios de Administrador...
    powershell.exe -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

echo.
echo  [romanOS] Aplicando Hotfix de Menus Contextuales (PLAN-0031)
echo  ==============================================================
echo.

set "SCRIPT_DIR=%~dp0"
set "PS51=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

:: Buscar Add-OptimizedContextMenus.ps1 en rutas canonicas
set "TARGET_SCRIPT="
if exist "%SCRIPT_DIR%Modules\Add-OptimizedContextMenus.ps1" (
    set "TARGET_SCRIPT=%SCRIPT_DIR%Modules\Add-OptimizedContextMenus.ps1"
)
if not defined TARGET_SCRIPT (
    if exist "%SCRIPT_DIR%Add-OptimizedContextMenus.ps1" (
        set "TARGET_SCRIPT=%SCRIPT_DIR%Add-OptimizedContextMenus.ps1"
    )
)
if not defined TARGET_SCRIPT (
    if exist "C:\Windows\Setup\Scripts\Add-OptimizedContextMenus.ps1" (
        set "TARGET_SCRIPT=C:\Windows\Setup\Scripts\Add-OptimizedContextMenus.ps1"
    )
)

if not defined TARGET_SCRIPT (
    echo  [ERROR] No se encontro Add-OptimizedContextMenus.ps1
    echo  Rutas buscadas:
    echo    - %SCRIPT_DIR%Modules\
    echo    - %SCRIPT_DIR%
    echo    - C:\Windows\Setup\Scripts\
    echo.
    pause
    exit /b 1
)

echo  Script encontrado: %TARGET_SCRIPT%
echo.
echo  Aplicando menus contextuales y correcciones SubCommands...
echo.

"%PS51%" -STA -NoProfile -ExecutionPolicy Bypass ^
    -File "%TARGET_SCRIPT%" ^
    -Apply ^
    -EnableClassicMenu ^
    -FixSubCommands

if %errorlevel% equ 0 (
    echo.
    echo  [OK] Hotfix de menus contextuales aplicado exitosamente.
) else (
    echo.
    echo  [WARN] El script termino con codigo %errorlevel%.
    echo         Revise la salida anterior para detectar errores.
)

echo.
echo  Presione cualquier tecla para cerrar...
pause >nul
