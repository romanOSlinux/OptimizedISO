@echo off
setlocal
title romanOS Helper - Aislamiento del Nucleo (VBS / HVCI)

fltmc >nul 2>&1 || (
    powershell.exe -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c """%~f0""" %*' -Verb RunAs"
    exit /b
)

echo ==========================================================================
echo        romanOS Helper - Conmutador de Aislamiento del Nucleo (VBS/HVCI)
echo ==========================================================================
echo.

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Toggle-VBS-CoreIsolation.ps1" %*

echo.
if "%~1"=="" (
    echo Presiona cualquier tecla para cerrar esta ventana...
    pause >nul
)
exit /b %ERRORLEVEL%
