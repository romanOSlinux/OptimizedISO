@echo off
setlocal
title romanOS Helper - Compartir Archivos (SMB)

:: Verificacion y auto-elevacion de privilegios de Administrador UAC
fltmc >nul 2>&1 || (
    powershell.exe -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c """"""%~f0"""""" %*' -Verb RunAs"
    exit /b
)

echo ==========================================================================
echo          romanOS Helper - Conmutador de Uso Compartido de Archivos (SMB)
echo ==========================================================================
echo.

set "TARGET_PS1="
if exist "%~dp0Toggle-FileSharing.ps1" (
    set "TARGET_PS1=%~dp0Toggle-FileSharing.ps1"
) else if exist "%SystemRoot%\Setup\Scripts\DesktopHelpers\Toggle-FileSharing.ps1" (
    set "TARGET_PS1=%SystemRoot%\Setup\Scripts\DesktopHelpers\Toggle-FileSharing.ps1"
) else if exist "C:\OptimizedISO\scripts\Desktop-Helpers\Toggle-FileSharing.ps1" (
    set "TARGET_PS1=C:\OptimizedISO\scripts\Desktop-Helpers\Toggle-FileSharing.ps1"
)

if not defined TARGET_PS1 (
    echo [ERROR CRITICO] No se pudo localizar el script de logica 'Toggle-FileSharing.ps1'.
    echo Se buscaron las siguientes rutas sin exito:
    echo   1. %~dp0Toggle-FileSharing.ps1
    echo   2. %SystemRoot%\Setup\Scripts\DesktopHelpers\Toggle-FileSharing.ps1
    echo   3. C:\OptimizedISO\scripts\Desktop-Helpers\Toggle-FileSharing.ps1
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