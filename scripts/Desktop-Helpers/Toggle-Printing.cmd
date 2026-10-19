@echo off
setlocal
title romanOS Helper - Cola de Impresion

:: Verificacion y auto-elevacion de privilegios de Administrador UAC
fltmc >nul 2>&1 || (
    powershell.exe -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c """"""%~f0"""""" %*' -Verb RunAs"
    exit /b
)

echo ==========================================================================
echo          romanOS Helper - Conmutador de Cola de Impresion (Spooler)
echo ==========================================================================
echo.

set "TARGET_PS1="
if exist "%~dp0Toggle-Printing.ps1" (
    set "TARGET_PS1=%~dp0Toggle-Printing.ps1"
) else if exist "%SystemRoot%\Setup\Scripts\DesktopHelpers\Toggle-Printing.ps1" (
    set "TARGET_PS1=%SystemRoot%\Setup\Scripts\DesktopHelpers\Toggle-Printing.ps1"
) else if exist "%~dp0..\..\scripts\Desktop-Helpers\Toggle-Printing.ps1" (
    set "TARGET_PS1=%~dp0..\..\scripts\Desktop-Helpers\Toggle-Printing.ps1"
)

if not defined TARGET_PS1 (
    echo [ERROR CRITICO] No se pudo localizar el script de logica 'Toggle-Printing.ps1'.
    echo Se buscaron las siguientes rutas sin exito:
    echo   1. %~dp0Toggle-Printing.ps1
    echo   2. %SystemRoot%\Setup\Scripts\DesktopHelpers\Toggle-Printing.ps1
    echo   3. %~dp0..\..\scripts\Desktop-Helpers\Toggle-Printing.ps1
    echo.
    echo Asegurate de que la suite romanOS Helpers este instalada correctamente en el sistema.
    echo.
    pause
    exit /b 1
)

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%TARGET_PS1%" %*

echo.
if "%~1"=="" (
    echo Presiona cualquier tecla para cerrar esta ventana...
    pause >nul
)
exit /b %ERRORLEVEL%