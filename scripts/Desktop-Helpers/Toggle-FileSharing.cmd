@echo off
setlocal
title romanOS Helper - Red Local y SMB

fltmc >nul 2>&1 || (
    powershell.exe -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c """%~f0""" %*' -Verb RunAs"
    exit /b
)

echo ==========================================================================
echo        romanOS Helper - Conmutador de Uso Compartido en Red (SMB)
echo ==========================================================================
echo.

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Toggle-FileSharing.ps1" %*

echo.
if "%~1"=="" (
    echo Presiona cualquier tecla para cerrar esta ventana...
    pause >nul
)
exit /b %ERRORLEVEL%
