# PLAN-0052: Paridad de AutoLogon sin Contraseña en OOBE e Inyección Completa de Módulos en Builder y Test Harness

**Fecha:** 2026-09-07  
**Estado:** COMPLETADO  
**Objetivo:** Alinear y corregir los 10 puntos fallidos del Test Harness (`Test-OptimizedISO-v2.ps1`) restituyendo la arquitectura de AutoLogon sin contraseña con credenciales efímeras seguras en OOBE (PLAN-0049) y garantizando la doble inyección física de scripts (`Optimize-WebBrowsers.ps1`, `Migrar-Usuario-W11.ps1`, `Get-WindowsUpdates.ps1`) en la raíz de `$OEMScriptsDir` y WIM offline para alcanzar el 100% PASS (348/348).

---

## 1. Causa Raíz de los 10 Fallos

1. **AutoLogon sin contraseña (4 fallos en PLAN-0049):**
   - En el commit `c9a460a`, se retiró involuntariamente el bloque de credenciales efímeras (`RomanOS#Setup_<guid>!`) y su purga en `FirstLogonCommands`.
   - Windows 11 24H2 revoca `AutoAdminLogon` a `0` si la cuenta no tiene contraseña en `autounattend.xml`, deteniendo la instalación en OOBE.
   - La arquitectura canónica de PLAN-0049 resuelve esto usando una contraseña efímera para el primer logon desatendido y purgándola inmediatamente en `FirstLogonCommands` vía `net user` y borrando `DefaultPassword` del registro.
2. **Inyección de módulos complementarios (6 fallos en PLAN-0050):**
   - Los scripts `Optimize-WebBrowsers.ps1`, `Migrar-Usuario-W11.ps1` y `Get-WindowsUpdates.ps1` se estaban copiando únicamente dentro de `$destModulesDir` (`Modules/`), pero no en la raíz de scripts `$OEMScriptsDir` ni en el WIM montado `$wimScriptsDir`.
   - `SetupComplete.cmd` y el Test Harness esperan que existan tanto en la raíz de scripts como en sus subdirectorios para máxima resiliencia.

---

## 2. Plan de Modificaciones

### A. `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`
1. **Restituir bloque PLAN-0049:**
   - Si `$isPasswordless`: generar contraseña efímera `RomanOS#Setup_<guid>!`.
   - Inyectar en `FirstLogonCommands`:
     - `net user "$finalLocalUser" ""`
     - `reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /f`
     - `reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 0 /f`
2. **Doble inyección física en $OEM$ y WIM (PLAN-0050):**
   - Copiar `Optimize-WebBrowsers.ps1`, `Migrar-Usuario-W11.ps1` y `Get-WindowsUpdates.ps1` tanto a `$OEMScriptsDir` como a `$destModulesDir`.
   - Copiar los mismos scripts en el WIM montado tanto a `$wimScriptsDir` como a `$wimModulesDest`.

---

## 3. Plan de Verificación

1. Comprobación estática AST y UTF-8 BOM con `pre-commit-auditor`.
2. Ejecución completa de `Test-OptimizedISO-v2.ps1` en Windows PowerShell 5.1.
3. Certificar **100% PASS (348/348)** con 0 fallos.
