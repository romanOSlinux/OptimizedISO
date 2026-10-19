@echo off
title romanOS - Descargador de Actualizaciones Oficiales de Windows (MSU/CAB)
echo.
echo ======================================================================
echo   romanOS - Descargador de Windows Updates Oficiales (MSU / CAB)
echo   Consulta directa a Microsoft Update Catalog y Descarga CDN
echo ======================================================================
echo.

:: Comprobar privilegios de Administrador y auto-elevar
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Solicitando elevacion de privilegios de Administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\" %*' -Verb RunAs"
    exit /b 0
)

cd /d "%~dp0"

if exist "%~dp0Get-WindowsUpdates.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Get-WindowsUpdates.ps1" %*
) else if exist "%~dp0..\Builder\Get-WindowsUpdates.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Builder\Get-WindowsUpdates.ps1" %*
) else if exist "%WINDIR%\Setup\Scripts\Builder\Get-WindowsUpdates.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%WINDIR%\Setup\Scripts\Builder\Get-WindowsUpdates.ps1" %*
) else if exist "%WINDIR%\Setup\Scripts\Get-WindowsUpdates.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%WINDIR%\Setup\Scripts\Get-WindowsUpdates.ps1" %*
) else if exist "C:\Windows\Setup\Scripts\Builder\Get-WindowsUpdates.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "C:\Windows\Setup\Scripts\Builder\Get-WindowsUpdates.ps1" %*
) else if exist "C:\Windows\Setup\Scripts\Get-WindowsUpdates.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "C:\Windows\Setup\Scripts\Get-WindowsUpdates.ps1" %*
) else (
    echo [ERROR] No se encontro Get-WindowsUpdates.ps1 en el directorio actual: %~dp0
    pause
    exit /b 1
)

echo.
