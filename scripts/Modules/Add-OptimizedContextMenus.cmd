@echo off
title Suite de Menus Contextuales Optimizados - romanOS
echo.
echo ======================================================================
echo   Suite de Menus Contextuales Optimizados (Gaming y Power-Users)
echo   Ejecucion con elevacion UAC y flag STA
echo ======================================================================
echo.

:: Comprobar privilegios de Administrador y auto-elevar
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Solicitando elevacion de privilegios de Administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b 0
)

cd /d "%~dp0"

if exist "%~dp0Add-OptimizedContextMenus.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Add-OptimizedContextMenus.ps1" %*
) else (
    echo [ERROR] No se encontro Add-OptimizedContextMenus.ps1 en el directorio actual: %~dp0
    pause
    exit /b 1
)

echo.
echo ======================================================================
echo   Ejecucion finalizada. Presione cualquier tecla para cerrar...
echo ======================================================================
pause >nul
