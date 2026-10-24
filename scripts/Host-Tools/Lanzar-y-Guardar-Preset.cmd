@echo off
:: Lanzador para grabar opciones interactivas en un archivo JSON (Preset)
:: Regla 4: Soporte Grafico STA Obligatorio
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
echo Privilegios obtenidos. Iniciando Builder en modo Grabacion de Preset...
cd /d "%~dp0..\.."
:: Lanzar con STA, ExecutionPolicy Bypass en una ventana visible y con el parametro -SavePreset
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Builder\New-OptimizedWindowsISO-v2.ps1" -SavePreset

echo.
echo =======================================================
echo   Proceso finalizado. Revisa la carpeta en busqueda del JSON.
echo =======================================================
pause


