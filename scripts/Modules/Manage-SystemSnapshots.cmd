@echo off
title romanOS State Snapshot & Rollback Engine (2026)
echo.
echo ======================================================================
echo   romanOS State Snapshot & Rollback Engine
echo   Motor de Instantaneas y Reversion Atomica de Configuracion
echo ======================================================================
echo.

:: Comprobar privilegios de Administrador y auto-elevar
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Solicitando elevacion de privilegios de Administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\" %*' -Verb RunAs"
    exit /b 0
)

cd /d "%~dp0"

if exist "%~dp0Manage-SystemSnapshots.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manage-SystemSnapshots.ps1" %*
) else if exist "%WINDIR%\Setup\Scripts\Modules\Manage-SystemSnapshots.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%WINDIR%\Setup\Scripts\Modules\Manage-SystemSnapshots.ps1" %*
) else if exist "%WINDIR%\Setup\Scripts\Manage-SystemSnapshots.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%WINDIR%\Setup\Scripts\Manage-SystemSnapshots.ps1" %*
) else if exist "C:\Windows\Setup\Scripts\Modules\Manage-SystemSnapshots.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "C:\Windows\Setup\Scripts\Modules\Manage-SystemSnapshots.ps1" %*
) else if exist "C:\Windows\Setup\Scripts\Manage-SystemSnapshots.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "C:\Windows\Setup\Scripts\Manage-SystemSnapshots.ps1" %*
) else (
    echo [ERROR] No se encontro Manage-SystemSnapshots.ps1 en %~dp0 ni en C:\Windows\Setup\Scripts\
    pause
    exit /b 1
)

echo.
echo ======================================================================
echo   Ejecucion finalizada. Presione cualquier tecla para cerrar...
echo ======================================================================
pause >nul
