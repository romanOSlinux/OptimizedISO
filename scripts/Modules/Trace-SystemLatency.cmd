@echo off
title romanOS - Profiler Forense de Latencia DPC/ISR en Vivo
echo.
echo ======================================================================
echo   romanOS - Profiler Forense de Latencia DPC/ISR (Multi-Hardware)
echo   Precision Sub-Microsegundo, Invariant TSC y Correlacion de Drivers
echo ======================================================================
echo.

:: Comprobar privilegios de Administrador y auto-elevar si es necesario
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Solicitando elevacion de privilegios de Administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\" %*' -Verb RunAs"
    exit /b 0
)

cd /d "%~dp0"

if exist "%~dp0Trace-SystemLatency.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Trace-SystemLatency.ps1" %*
) else (
    echo [ERROR] No se encontro Trace-SystemLatency.ps1 en el directorio actual: %~dp0
    pause
    exit /b 1
)

exit /b %errorlevel%
