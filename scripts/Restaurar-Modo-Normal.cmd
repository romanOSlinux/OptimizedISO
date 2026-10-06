@echo off
rem ==============================================================================
rem romanOS - Lanzador de Restauracion de Modo Normal (Estandar Windows)
rem ==============================================================================
chcp 65001 >nul
setlocal enabledelayedexpansion

title romanOS - Restaurar Modo Normal

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [!] Solicitando elevacion de privilegios de Administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\" %*' -Verb RunAs"
    exit /b 0
)

cd /d "%~dp0"
echo.
echo ==============================================================================
echo   romanOS - RESTAURANDO MODO NORMAL / ESTANDAR DE WINDOWS
echo ==============================================================================
echo.

set "GAME_PS1=%~dp0Modules\Switch-GameDevMode.ps1"
if not exist "%GAME_PS1%" set "GAME_PS1=%WINDIR%\Setup\Scripts\Modules\Switch-GameDevMode.ps1"
if not exist "%GAME_PS1%" set "GAME_PS1=C:\Windows\Setup\Scripts\Modules\Switch-GameDevMode.ps1"

if exist "%GAME_PS1%" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%GAME_PS1%" -Mode Normal -Unattended
) else (
    echo [ERROR] No se encontro Switch-GameDevMode.ps1
)

echo.
echo ==============================================================================
echo   [OK] Entorno restaurado al modo normal.
echo   Presione cualquier tecla para cerrar esta ventana...
echo ==============================================================================
pause >nul
exit /b 0
