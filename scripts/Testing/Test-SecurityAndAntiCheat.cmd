@echo off
setlocal
title romanOS - Bateria de Seguridad y Anti-Cheat 2026
color 0b

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-SecurityAndAntiCheat.ps1"
set EXITCODE=%ERRORLEVEL%

echo.
if %EXITCODE% EQU 0 (
    color 0a
    echo [EXITO] Todas las pruebas de seguridad y anti-cheat pasaron exitosamente.
) else (
    color 0c
    echo [ERROR] Se detectaron aserciones fallidas en las pruebas de seguridad.
)

echo.
pause
exit /b %EXITCODE%
