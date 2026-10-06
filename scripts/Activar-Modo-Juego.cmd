@echo off
rem ==============================================================================
rem romanOS - Lanzador Inteligente de Modo Juego Adaptativo (Hardware-Aware)
rem ==============================================================================
chcp 65001 >nul
setlocal enabledelayedexpansion

title romanOS - Activar Modo Juego

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
echo   romanOS - ACTIVANDO MODO JUEGO ADAPTATIVO (HARDWARE-AWARE & LATENCIA DPC)
echo ==============================================================================
echo.

set "GAME_PS1=%~dp0Modules\Switch-GameDevMode.ps1"
if not exist "%GAME_PS1%" set "GAME_PS1=%WINDIR%\Setup\Scripts\Modules\Switch-GameDevMode.ps1"
if not exist "%GAME_PS1%" set "GAME_PS1=C:\Windows\Setup\Scripts\Modules\Switch-GameDevMode.ps1"

if exist "%GAME_PS1%" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%GAME_PS1%" -Mode Game -Unattended
) else (
    echo [ERROR] No se encontro Switch-GameDevMode.ps1
)

echo.
echo ------------------------------------------------------------------------------
echo   Ejecutando Poda Quirurgica de Memoria Working Set (psapi.dll)
echo ------------------------------------------------------------------------------
echo.

set "MEM_PS1=%~dp0Modules\Optimize-ProcessMemory.ps1"
if not exist "%MEM_PS1%" set "MEM_PS1=%WINDIR%\Setup\Scripts\Modules\Optimize-ProcessMemory.ps1"
if not exist "%MEM_PS1%" set "MEM_PS1=C:\Windows\Setup\Scripts\Modules\Optimize-ProcessMemory.ps1"

if exist "%MEM_PS1%" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & '%MEM_PS1%' -ProcessNames 'steamwebhelper','TextInputHost','CrossDeviceResume','ShellHost','SearchHost' -Unattended }"
)

echo.
echo ==============================================================================
echo   [OK] Modo Juego activo y memoria optimizada para jugar.
echo   Presione cualquier tecla para cerrar esta ventana...
echo ==============================================================================
pause >nul
exit /b 0
