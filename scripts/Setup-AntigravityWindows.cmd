@echo off
setlocal EnableDelayedExpansion
title romanOS - Inicializador de Entorno Antigravity y Herramientas

:: Elevacion automatica para poder auditar caracteristicas de Hyper-V y variables
net session >nul 2>&1

chcp 65001 >nul
cls

echo ==========================================================================
echo   Iniciando Preparador de Entorno Antigravity ^& OptimizedISO (Windows)...
echo ==========================================================================
echo.

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-AntigravityWindows.ps1" %*

echo.
pause
