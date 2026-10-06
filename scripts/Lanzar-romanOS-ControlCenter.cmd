@echo off
rem ==============================================================================
rem romanOS Control Center - Lanzador Principal GUI
rem ==============================================================================
chcp 65001 >nul
setlocal

set "GUI_CMD=%~dp0GUI\Lanzar-romanOS-ControlCenter.cmd"
if not exist "%GUI_CMD%" set "GUI_CMD=%WINDIR%\Setup\Scripts\GUI\Lanzar-romanOS-ControlCenter.cmd"
if not exist "%GUI_CMD%" set "GUI_CMD=C:\Windows\Setup\Scripts\GUI\Lanzar-romanOS-ControlCenter.cmd"

if exist "%GUI_CMD%" (
    call "%GUI_CMD%" %*
    exit /b %errorlevel%
)

set "GUI_PS1=%~dp0GUI\romanOS-ControlCenter.ps1"
if not exist "%GUI_PS1%" set "GUI_PS1=%WINDIR%\Setup\Scripts\GUI\romanOS-ControlCenter.ps1"
if not exist "%GUI_PS1%" set "GUI_PS1=C:\Windows\Setup\Scripts\GUI\romanOS-ControlCenter.ps1"

if exist "%GUI_PS1%" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%GUI_PS1%" %*
    exit /b %errorlevel%
)

echo [ERROR] No se encontro romanOS-ControlCenter.ps1 ni su lanzador.
pause
exit /b 1
