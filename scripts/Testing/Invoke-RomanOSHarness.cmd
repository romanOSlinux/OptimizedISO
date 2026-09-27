@echo off
setlocal
title romanOS - Evaluation and Assurance Harness Launcher
cd /d "%~dp0\..\.."

echo ==========================================================================
echo  romanOS / OptimizedISO - Ejecutando Harness de Evaluacion Repo-Wide
echo ==========================================================================

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Invoke-RomanOSHarness.ps1" -ExportJson

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [-] El Evaluation Harness detecto violaciones o pruebas fallidas.
    exit /b %ERRORLEVEL%
)

echo.
echo [+] Todas las invariantes y pruebas del Harness pasaron satisfactoriamente.
exit /b 0
