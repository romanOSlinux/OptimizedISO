@echo off
setlocal EnableDelayedExpansion
title romanOS Test App Profiles ^& AI Runtimes Manager

:: Invocacion en frio con Windows PowerShell 5.1
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-AppProfilesManager.ps1" %*

set "EXIT_CODE=%errorlevel%"
if %EXIT_CODE% neq 0 (
    echo.
    echo [FALLO] La suite de pruebas de App Profiles fallo con codigo: %EXIT_CODE%
    pause
)

exit /b %EXIT_CODE%
