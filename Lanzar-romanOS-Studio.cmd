@echo off
:: Lanzador desacoplado para romanOS Studio (WPF)
:: Inicia el proceso en segundo plano y cierra la consola inmediatamente
start "" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\GUI\romanOS-Studio.ps1"
exit
