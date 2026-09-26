@echo off
setlocal
title romanOS Helpers - Centro de Control de Servicios

fltmc >nul 2>&1 || (
    powershell.exe -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c """%~f0""" %*' -Verb RunAs"
    exit /b
)

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0romanOS-Helpers-Menu.ps1" %*

if "%~1"=="" (
    pause
)
exit /b %ERRORLEVEL%
