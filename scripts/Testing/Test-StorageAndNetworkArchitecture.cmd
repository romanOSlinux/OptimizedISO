@echo off
setlocal
cd /d "%~dp0\..\.."
echo ==========================================================================
echo  Iniciando Bateria de Almacenamiento, Red NDIS y Memoria (PLAN-0098)
echo ==========================================================================
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "scripts\Testing\Test-StorageAndNetworkArchitecture.ps1" %*
set EXITCODE=%ERRORLEVEL%
if %EXITCODE% neq 0 (
    echo [ERROR] La suite de pruebas de Almacenamiento y Red fallo con codigo %EXITCODE%.
)
exit /b %EXITCODE%