@echo off
setlocal
:: =====================================================================
:: romanOS Studio - Lanzador Oficial Win32 (JIT Compiler / Launcher)
:: Si el ejecutable nativo no existe, se compila al instante con csc.exe
:: =====================================================================

set "ROOT=%~dp0"
set "EXE=%ROOT%Lanzar-romanOS-Studio.exe"
set "SRC=%ROOT%scripts\GUI\romanOS-Studio-Launcher.cs"
set "CSC=%SystemRoot%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if not exist "%CSC%" set "CSC=%SystemRoot%\Microsoft.NET\Framework\v4.0.30319\csc.exe"

if not exist "%EXE%" (
    if exist "%CSC%" if exist "%SRC%" (
        "%CSC%" /nologo /target:winexe /platform:anycpu /optimize+ /out:"%EXE%" "%SRC%" >nul 2>&1
    )
)

if exist "%EXE%" (
    start "" "%EXE%"
    exit /b 0
)

:: Fallback directo si csc.exe no estuviera disponible
start "" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -STA -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\GUI\romanOS-Studio.ps1"
exit /b 0
