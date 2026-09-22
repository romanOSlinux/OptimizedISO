@echo off
setlocal
title romanOS - Bateria de Latencia de Kernel y Topologia 2026
color 0b

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-KernelLatencyAndTopology.ps1"
set EXITCODE=%ERRORLEVEL%

echo.
if %EXITCODE% EQU 0 (
    color 0a
    echo [EXITO] Todas las pruebas de latencia y topologia pasaron exitosamente.
) else (
    color 0c
    echo [ERROR] Se detectaron anomalias en las pruebas de latencia o topologia.
)

echo.
pause
exit /b %EXITCODE%
