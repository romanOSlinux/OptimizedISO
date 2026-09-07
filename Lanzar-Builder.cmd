@echo off
:: Lanzador con Elevaci?n Autom?tica de Privilegios para romanOS Builder
:: Regla 4: Soporte Gr?fico STA Obligatorio
echo.
echo =======================================================
echo   Solicitando privilegios de Administrador...
echo =======================================================
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :RunScript
) else (
    echo Elevando privilegios...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:RunScript
echo Privilegios obtenidos. Iniciando New-OptimizedWindowsISO-v2.ps1...
cd /d "%~dp0"
:: Lanzar con STA, ExecutionPolicy Bypass en una ventana visible
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Builder\New-OptimizedWindowsISO-v2.ps1"

echo.
echo =======================================================
echo   El proceso de creacion de ISO ha finalizado.
echo =======================================================
pause


