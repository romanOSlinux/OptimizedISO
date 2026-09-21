@echo off
setlocal
:: =====================================================================
:: romanOS Control Center - Lanzador Oficial Win32 (JIT Compiler / Launcher)
:: Si el ejecutable nativo no existe, se compila al instante con csc.exe
:: Compatible con entorno de desarrollo, C:\Windows\Setup\Scripts y Desktop
:: =====================================================================

set "ROOT=%~dp0"
set "CSC=%SystemRoot%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%SystemRoot%\Microsoft.NET\Framework\v4.0.30319\csc.exe"

:: 1. Localizar codigo fuente C# para compilacion JIT
set "SRC="
set "EXE="
if exist "%ROOT%scripts\GUI\romanOS-ControlCenter-Launcher.cs" (
    set "SRC=%ROOT%scripts\GUI\romanOS-ControlCenter-Launcher.cs"
    set "EXE=%ROOT%Lanzar-romanOS-ControlCenter.exe"
) else if exist "%ROOT%GUI\romanOS-ControlCenter-Launcher.cs" (
    set "SRC=%ROOT%GUI\romanOS-ControlCenter-Launcher.cs"
    set "EXE=%ROOT%Lanzar-romanOS-ControlCenter.exe"
) else if exist "%ROOT%romanOS-ControlCenter-Launcher.cs" (
    set "SRC=%ROOT%romanOS-ControlCenter-Launcher.cs"
    set "EXE=%ROOT%Lanzar-romanOS-ControlCenter.exe"
) else if exist "%WINDIR%\Setup\Scripts\GUI\romanOS-ControlCenter-Launcher.cs" (
    set "SRC=%WINDIR%\Setup\Scripts\GUI\romanOS-ControlCenter-Launcher.cs"
    set "EXE=%WINDIR%\Setup\Scripts\Lanzar-romanOS-ControlCenter.exe"
) else if exist "C:\Windows\Setup\Scripts\GUI\romanOS-ControlCenter-Launcher.cs" (
    set "SRC=C:\Windows\Setup\Scripts\GUI\romanOS-ControlCenter-Launcher.cs"
    set "EXE=C:\Windows\Setup\Scripts\Lanzar-romanOS-ControlCenter.exe"
)

:: 2. Compilar ejecutable nativo si no existe
if defined SRC if defined EXE (
    if not exist "%EXE%" (
        if exist "%CSC%" (
            "%CSC%" /nologo /target:winexe /platform:anycpu /optimize+ /out:"%EXE%" "%SRC%" >nul 2>&1
        )
    )
    if exist "%EXE%" (
        start "" "%EXE%" %*
        exit /b 0
    )
)

:: 3. Localizar script PowerShell para fallback directo
set "PS1="
if exist "%ROOT%scripts\GUI\romanOS-ControlCenter.ps1" (
    set "PS1=%ROOT%scripts\GUI\romanOS-ControlCenter.ps1"
) else if exist "%ROOT%GUI\romanOS-ControlCenter.ps1" (
    set "PS1=%ROOT%GUI\romanOS-ControlCenter.ps1"
) else if exist "%ROOT%romanOS-ControlCenter.ps1" (
    set "PS1=%ROOT%romanOS-ControlCenter.ps1"
) else if exist "%WINDIR%\Setup\Scripts\GUI\romanOS-ControlCenter.ps1" (
    set "PS1=%WINDIR%\Setup\Scripts\GUI\romanOS-ControlCenter.ps1"
) else if exist "%WINDIR%\Setup\Scripts\romanOS-ControlCenter.ps1" (
    set "PS1=%WINDIR%\Setup\Scripts\romanOS-ControlCenter.ps1"
) else if exist "C:\Windows\Setup\Scripts\GUI\romanOS-ControlCenter.ps1" (
    set "PS1=C:\Windows\Setup\Scripts\GUI\romanOS-ControlCenter.ps1"
) else if exist "C:\Windows\Setup\Scripts\romanOS-ControlCenter.ps1" (
    set "PS1=C:\Windows\Setup\Scripts\romanOS-ControlCenter.ps1"
)

if defined PS1 (
    start "" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -STA -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
    exit /b 0
)

echo [ERROR] No se pudo encontrar romanOS-ControlCenter.ps1 ni el compilador nativo.
pause
exit /b 1
