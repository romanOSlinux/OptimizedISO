@echo off
:: ==========================================================================
:: Migrar Usuario Local
:: romanOS / OptimizedISO
:: ==========================================================================

:: --- Auto-Elevacion ---
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Solicitando permisos de administrador...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0"

:: --- Invocacion a PowerShell ---
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & '%~dp0scripts\Modules\Migrar-Usuario-W11.ps1' }"
