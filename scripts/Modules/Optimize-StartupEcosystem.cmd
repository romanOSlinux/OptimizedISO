@echo off
setlocal
cd /d "%~dp0"
title romanOS - Gobernanza de Inicio y Servicios a Demanda
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Optimize-StartupEcosystem.ps1" %*
endlocal
