@echo off
title Auditoria de Seguridad y Hardening On-Demand
echo.
echo ======================================================================
echo   Auditoria de Seguridad y Hardening Desacoplado (romanOS)
echo   Ejecucion automatica con elevacion y Bypass de ExecutionPolicy
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

if exist "%~dp0Invoke-WindowsSecurityHardening.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Invoke-WindowsSecurityHardening.ps1" %*
) else if exist "%WINDIR%\Setup\Scripts\Invoke-WindowsSecurityHardening.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%WINDIR%\Setup\Scripts\Invoke-WindowsSecurityHardening.ps1" %*
) else if exist "C:\Windows\Setup\Scripts\Invoke-WindowsSecurityHardening.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "C:\Windows\Setup\Scripts\Invoke-WindowsSecurityHardening.ps1" %*
) else (
    echo [ERROR] No se encontro Invoke-WindowsSecurityHardening.ps1 en el directorio actual: %~dp0
    pause
    exit /b 1
)

echo.
echo ======================================================================
echo   Auditoria de seguridad finalizada. Presione cualquier tecla...
echo ======================================================================
pause >nul
