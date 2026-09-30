@echo off
title romanOS - Conmutador Modo Juego y Desarrollo (Game ^& Dev Switch)
chcp 65001 >nul 2>&1

:: Comprobar privilegios de Administrador y auto-elevar (si no se solicito solo Status)
if /i "%~1"=="-Status" goto :skip_uac
if /i "%~1"=="Status" goto :skip_uac

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Solicitando elevacion de privilegios de Administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\" %*' -Verb RunAs"
    exit /b 0
)

:skip_uac
cd /d "%~dp0"

:: Localizar el script PowerShell
set "SCRIPT_PS1=%~dp0Switch-GameDevMode.ps1"
if not exist "%SCRIPT_PS1%" set "SCRIPT_PS1=%WINDIR%\Setup\Scripts\Modules\Switch-GameDevMode.ps1"
if not exist "%SCRIPT_PS1%" set "SCRIPT_PS1=%WINDIR%\Setup\Scripts\Switch-GameDevMode.ps1"
if not exist "%SCRIPT_PS1%" set "SCRIPT_PS1=C:\Windows\Setup\Scripts\Modules\Switch-GameDevMode.ps1"
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
echo    romanOS - CONMUTADOR MODO JUEGO Y DESARROLLO (GAME OPTIMIZER)
echo    Optimizador Bimodal de Recursos para Gaming y Pruebas de ISOs
echo  ======================================================================
echo.
echo    [1] Activar MODO JUEGO (Baja Latencia DPC ^& MMCSS Calibrado)
echo        - Desmonta conmutador virtual de Hyper-V (elimina latencia DPC ^< 500 us)
echo        - Pausa servicios no esenciales (WSearch, PcaSvc, DPS, DiagTrack, Update)
echo        - Calibra MMCSS (SystemResponsiveness = 10, NetworkThrottling = OFF)
echo        - Protege VRAM UMA (LargeSystemCache = 0) y fija kernel en RAM fisica
echo        - CONSERVA el 100%% de tus ventanas y aplicaciones abiertas
echo.
echo    [2] Activar MODO DEV / NORMAL (Restauracion Transaccional)
echo        - Restaura pila completa de Hyper-V (vmms, vmcompute, HNS, HvHost)
echo        - Reactiva adaptador vEthernet para pruebas de ISOs y VMs
echo        - Restaura todos los servicios pausados a su estado exacto previo
echo.
echo    [3] Ver Estado Actual y Metricas de Memoria RAM
echo.
echo    [4] Salir
echo.
echo  ======================================================================
set /p "choice= Seleccione una opcion [1-4]: "

if "%choice%"=="1" goto :run_game
if "%choice%"=="2" goto :run_dev
if "%choice%"=="3" goto :run_status
if "%choice%"=="4" exit /b 0

echo [!] Opcion invalida.
timeout /t 2 >nul
goto :menu

:run_game
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -Mode Game
goto :end

:run_game_light_cli
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -Mode Game -Unattended
goto :end

:run_game_aggressive
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -Mode Game
goto :end

:run_game_aggressive_cli
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -Mode Game -Unattended
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
