@echo off
setlocal
title romanOS Helpers - Centro de Control de Servicios

:: Verificacion y auto-elevacion de privilegios de Administrador UAC
fltmc >nul 2>&1 || (
    powershell.exe -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c """"""%~f0"""""" %*' -Verb RunAs"
    exit /b
)

set "TARGET_PS1="
if exist "%~dp0romanOS-Helpers-Menu.ps1" (
    set "TARGET_PS1=%~dp0romanOS-Helpers-Menu.ps1"
) else if exist "%SystemRoot%\Setup\Scripts\DesktopHelpers\romanOS-Helpers-Menu.ps1" (
    set "TARGET_PS1=%SystemRoot%\Setup\Scripts\DesktopHelpers\romanOS-Helpers-Menu.ps1"
) else if exist "C:\OptimizedISO\scripts\Desktop-Helpers\romanOS-Helpers-Menu.ps1" (
    set "TARGET_PS1=C:\OptimizedISO\scripts\Desktop-Helpers\romanOS-Helpers-Menu.ps1"
)

if not defined TARGET_PS1 (
    echo [ERROR CRITICO] No se pudo localizar 'romanOS-Helpers-Menu.ps1'.
    echo Se buscaron las siguientes rutas sin exito:
    echo   1. %~dp0romanOS-Helpers-Menu.ps1
    echo   2. %SystemRoot%\Setup\Scripts\DesktopHelpers\romanOS-Helpers-Menu.ps1
    echo   3. C:\OptimizedISO\scripts\Desktop-Helpers\romanOS-Helpers-Menu.ps1
    echo.
    echo Asegurate de que la suite romanOS Helpers este instalada correctamente en el sistema.
    echo.
    pause
    exit /b 1
)

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%TARGET_PS1%" %*

if "%~1"=="" (
    pause
)
exit /b %ERRORLEVEL%