@echo off
title romanOS - Conmutador Modo Juego y Desarrollo (Game ^& Dev Switch)
chcp 65001 >nul 2>&1

:: Comprobar privilegios de Administrador y auto-elevar (si no se solicito solo Status)
if /i "%~1"=="-Status" goto :skip_uac
if /i "%~1"=="Status" goto :skip_uac

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Solicitando elevacion de privilegios de Administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\" %*\"' -Verb RunAs"
    exit /b 0
)

:skip_uac
cd /d "%~dp0"

:: Localizar el script PowerShell
set "SCRIPT_PS1=%~dp0Switch-GameDevMode.ps1"
if not exist "%SCRIPT_PS1%" set "SCRIPT_PS1=%WINDIR%\Setup\Scripts\Switch-GameDevMode.ps1"
if not exist "%SCRIPT_PS1%" set "SCRIPT_PS1=C:\Windows\Setup\Scripts\Switch-GameDevMode.ps1"

if not exist "%SCRIPT_PS1%" (
    echo [ERROR] No se encontro Switch-GameDevMode.ps1 en %~dp0 ni en C:\Windows\Setup\Scripts\
    pause
    exit /b 1
)

:: Si se pasaron argumentos por linea de comandos, procesar directamente
if /i "%~1"=="-Aggressive" goto :run_game_aggressive_cli
if /i "%~1"=="Aggressive"  goto :run_game_aggressive_cli
if /i "%~1"=="-Light"      goto :run_game_light_cli
if /i "%~1"=="Light"       goto :run_game_light_cli
if /i "%~1"=="-Game"       goto :run_game_light_cli
if /i "%~1"=="Game"        goto :run_game_light_cli
if /i "%~1"=="-Dev"        goto :run_dev
if /i "%~1"=="Dev"         goto :run_dev
if /i "%~1"=="-Status"     goto :run_status_cli
if /i "%~1"=="Status"      goto :run_status_cli
if not "%~1"=="" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" %*
    goto :end
)

:menu
cls
echo.
echo  ======================================================================
echo    romanOS - CONMUTADOR MODO JUEGO Y DESARROLLO (GAME ^& DEV SWITCH)
echo    Optimizador Bimodal de Recursos para Gaming y Pruebas de ISOs
echo  ======================================================================
echo.
echo    [1] Activar MODO JUEGO LIVIANO
echo        - Desmonta conmutador virtual de Hyper-V (elimina latencia DPC)
echo        - Pausa telemetria y compatibilidad (PcaSvc, DPS, DusmSvc)
echo        - Plan de energia Maximo Rendimiento y SystemResponsiveness = 0
echo        - CONSERVA tus navegadores y aplicaciones abiertas
echo.
echo    [2] Activar MODO JUEGO AGRESIVO (Gaming Puro / APU Max)
echo        - Todo lo del Modo Liviano + prioridades de kernel para GPU/CPU
echo        - Cierra forzosamente instancias de Microsoft Edge (+1.4 GB RAM)
echo        - Opcion de cerrar Antigravity IDE (+2.4 GB RAM)
echo        - Maxima memoria DDR5 disponible para la iGPU Radeon 760M
echo.
echo    [3] Activar MODO DEV / PRUEBAS ISO
echo        - Restaura pila completa de Hyper-V (vmms, vmcompute, HNS, HvHost)
echo        - Reactiva adaptador vEthernet (Default Switch) para pruebas
echo        - Restaura servicios de diagnostico, mantenimiento y registro
echo.
echo    [4] Ver Estado Actual y Metricas de Memoria RAM
echo.
echo    [5] Salir
echo.
echo  ======================================================================
set /p "choice= Seleccione una opcion [1-5]: "

if "%choice%"=="1" goto :run_game_light
if "%choice%"=="2" goto :run_game_aggressive
if "%choice%"=="3" goto :run_dev
if "%choice%"=="4" goto :run_status
if "%choice%"=="5" exit /b 0

echo [!] Opcion invalida.
timeout /t 2 >nul
goto :menu

:run_game_light
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -Mode Game -Profile Light
goto :end

:run_game_light_cli
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -Mode Game -Profile Light -Unattended
goto :end

:run_game_aggressive
echo.
echo  [!] MODO JUEGO AGRESIVO PARA GAMING PURO Y APU RADEON
echo      - Se cerrara forzosamente Microsoft Edge (+1.4 GB RAM)
echo      - Se ajustaran prioridades multimedia del kernel (100%% CPU a juegos)
echo.
set /p "close_ide= Desea cerrar tambien el entorno de desarrollo Antigravity IDE para liberar +2.4 GB? [S/N] (Por defecto: N): "
if /i "%close_ide%"=="s" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -Mode Game -Profile Aggressive -CloseIDE
) else (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -Mode Game -Profile Aggressive
)
goto :end

:run_game_aggressive_cli
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -Mode Game -Profile Aggressive -Unattended
goto :end

:run_dev
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -Mode Dev
goto :end

:run_status
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -Mode Status
pause
goto :menu

:run_status_cli
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -Mode Status -Unattended
goto :end

:end
echo.
exit /b 0
