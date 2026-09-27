@echo off
setlocal
title romanOS Helper - Windows Recall e IA

fltmc >nul 2>&1 || (
    powershell.exe -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c """%~f0""" %*' -Verb RunAs"
    exit /b
)

echo ==========================================================================
echo        romanOS Helper - Conmutador de Windows Recall e IA (24H2+)
echo ==========================================================================
echo.

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Toggle-Recall.ps1" %*

echo.
if "%~1"=="" (
    echo Presiona cualquier tecla para cerrar esta ventana...
    pause >nul
)
exit /b %ERRORLEVEL%
