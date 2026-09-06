@echo off
setlocal EnableDelayedExpansion
title romanOS - Bateria Integral de Pruebas

:: Auto-elevacion si es posible (no estrictamente requerida para pruebas no destructivas)
net session >nul 2>&1

:: Lanzador directo con soporte STA y UTF-8
chcp 65001 >nul
cls

echo ==========================================================================
echo   Iniciando Bateria Integral de Pruebas romanOS...
echo ==========================================================================
echo.

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Invoke-TestSuite.ps1" %*

echo.
pause
