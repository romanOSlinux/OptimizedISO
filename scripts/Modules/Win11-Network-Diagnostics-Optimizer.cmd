@echo off
title Diagnostico y Optimizador de Red y Baja Latencia
echo.
echo ======================================================================
echo   Diagnostico y Optimizador de Red y Baja Latencia
echo   Ejecucion automatica con elevacion y Bypass de ExecutionPolicy
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

if exist "%~dp0Win11-Network-Diagnostics-Optimizer.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Win11-Network-Diagnostics-Optimizer.ps1" %*
) else if exist "%WINDIR%\Setup\Scripts\Modules\Win11-Network-Diagnostics-Optimizer.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%WINDIR%\Setup\Scripts\Modules\Win11-Network-Diagnostics-Optimizer.ps1" %*
) else if exist "%WINDIR%\Setup\Scripts\Win11-Network-Diagnostics-Optimizer.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%WINDIR%\Setup\Scripts\Win11-Network-Diagnostics-Optimizer.ps1" %*
) else if exist "C:\Windows\Setup\Scripts\Modules\Win11-Network-Diagnostics-Optimizer.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "C:\Windows\Setup\Scripts\Modules\Win11-Network-Diagnostics-Optimizer.ps1" %*
) else if exist "C:\Windows\Setup\Scripts\Win11-Network-Diagnostics-Optimizer.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "C:\Windows\Setup\Scripts\Win11-Network-Diagnostics-Optimizer.ps1" %*
) else (
    echo [ERROR] No se encontro Win11-Network-Diagnostics-Optimizer.ps1 en %~dp0 ni en C:\Windows\Setup\Scripts\
    pause
    exit /b 1
)

echo.
echo ======================================================================
echo   Ejecucion finalizada. Presione cualquier tecla para cerrar...
echo ======================================================================
pause >nul