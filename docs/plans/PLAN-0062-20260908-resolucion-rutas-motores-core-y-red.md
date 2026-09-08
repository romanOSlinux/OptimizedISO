# PLAN-0062: Corrección de Resolución de Rutas de Motores Core (Policy, UI, Hardware) y Restauración de Catálogo de Red en Toda la Suite

**Fecha:** 2026-09-08  
**Estado:** COMPLETADO  
**Rama:** `feature/offline-ui-tweaks`  
**Objetivo:** Eliminar de raíz el fallo de carga del motor de directivas (`Policy-Engine.ps1`), motor de interfaz (`UI-Engine.ps1`) y motor de hardware (`Hardware-Engine.ps1`) en todos los módulos de `scripts/Modules/`, `scripts/Host-Tools/` y `scripts/Testing/`, garantizando que `$global:RomanOS_NetworkPolicies` y demás catálogos dinámicos se carguen con paridad total tanto en entorno de desarrollo como en producción OEM.

---

## 1. Diagnóstico de Causa Raíz y Evidencia Empírica

Al ejecutar `Win11-Network-Diagnostics-Optimizer.ps1`, el usuario observó:
```text
ADVERTENCIA: El catalogo global RomanOS_NetworkPolicies no esta disponible. Verifica la carga de Policy-Engine.ps1.
Abriendo menu interactivo de optimizaciones de red.
```

### 1.1 Análisis Técnico del Fallo
1. **Ruta Relativa Rota en Subcarpetas:**
   En `Win11-Network-Diagnostics-Optimizer.ps1` (y varios otros scripts de `scripts/Modules/`), la lista de candidatos de resolución para los motores Core estaba configurada como:
   ```powershell
   $enginePaths = @(
       (Join-Path $PSScriptRoot "Core\Policy-Engine.ps1"),
       (Join-Path $PSScriptRoot "Policy-Engine.ps1"),
       (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\Policy-Engine.ps1"),
       "C:\Windows\Setup\Scripts\Core\Policy-Engine.ps1"
   )
   ```
   Al ejecutarse el script dentro de `C:\OptimizedISO\scripts\Modules`:
   - `$PSScriptRoot` es `C:\OptimizedISO\scripts\Modules`.
   - `Split-Path $PSScriptRoot -Parent` es `C:\OptimizedISO\scripts`.
   - `Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\Policy-Engine.ps1"` evaluaba a `C:\OptimizedISO\scripts\scripts\Core\Policy-Engine.ps1` (**duplicación de `scripts`**, inexistente).
   - Faltaba la ruta canónica para scripts ubicados en subcarpetas de primer nivel: `(Join-Path (Split-Path $PSScriptRoot -Parent) "Core\Policy-Engine.ps1")`.

2. **Caída Silenciosa a Fallback Obsoleto en Host Local:**
   - Como ninguna ruta del repositorio coincidía, el bucle caía en `"C:\Windows\Setup\Scripts\Core\Policy-Engine.ps1"`.
   - En el sistema del desarrollador existía un archivo residual en dicha ruta con fecha **03/09/2026** (tamaño: 30.967 bytes) procedente de una versión anterior.
   - El catálogo `$global:RomanOS_NetworkPolicies` fue introducido posteriormente en el plan **PLAN-0039 el 06/09/2026** (el `Policy-Engine.ps1` actual mide 122.724 bytes).
   - Como consecuencia, el script cargaba el archivo viejo de Windows, no encontraba `$global:RomanOS_NetworkPolicies` (definido únicamente en la versión actual), emitía la advertencia y abría el menú interactivo con las directivas de red vacías.
   - En máquinas donde `C:\Windows\Setup\Scripts\` no existe, fallaba completamente sin cargar motor alguno.

3. **Afectación en Cascada (Deuda Arquitectónica):**
   El mismo patrón deficiente afectaba a:
   - `scripts/Modules/romanOS-Toolkit.ps1` (UI, HW, Policy)
   - `scripts/Modules/Win11-Debloat-v3-Adaptive.ps1` (UI, Policy)
   - `scripts/Modules/PostInstall-Diagnostics.ps1` (UI, HW, Policy)
   - `scripts/Modules/Optimize-ProcessMemory.ps1` (UI)
   - `scripts/Modules/Invoke-WindowsSecurityHardening.ps1` (UI)
   - `scripts/Modules/Invoke-WindowsMaintenance.ps1` (UI)
   - `scripts/Modules/Add-OptimizedContextMenus.ps1` (UI)
   - `scripts/Host-Tools/Get-OfficialWindowsISO.ps1` (UI)
   - `scripts/Testing/Invoke-TestSuite.ps1` (UI)
   - `scripts/Testing/Test-HardwareEngine.ps1` (HW)

---

## 2. Solución de Ingeniería y Paridad Arquitectónica (SSOT)

### 2.1 Estandarización de Rutas de Motores Core
Colocar como **primera prioridad** la resolución del directorio padre respecto a la subcarpeta del script (`Join-Path (Split-Path $PSScriptRoot -Parent) "Core\<Engine>.ps1"`), asegurando que siempre se consuma el motor del repositorio activo:
```powershell
$enginePaths = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\Policy-Engine.ps1"),
    (Join-Path $PSScriptRoot "Core\Policy-Engine.ps1"),
    (Join-Path $PSScriptRoot "Policy-Engine.ps1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\Policy-Engine.ps1"),
    "C:\Windows\Setup\Scripts\Core\Policy-Engine.ps1"
)
```

Esta lista jerárquica cubre al 100%:
1. Invocación desde subcarpetas del repositorio (`scripts/Modules/`, `scripts/Host-Tools/`, `scripts/Testing/`, `scripts/Builder/`).
2. Invocación desde `C:\Windows\Setup\Scripts\Modules\` en sistema instalado.
3. Invocación directa desde la raíz de `scripts/`.
4. Invocación directa desde la raíz del repositorio (`C:\OptimizedISO\`).
5. Fallback OEM en `C:\Windows\Setup\Scripts\Core\`.

### 2.2 Sincronización del Directorio Local en Windows
Copiar los motores actualizados desde `c:\OptimizedISO\scripts\Core\*` a `C:\Windows\Setup\Scripts\Core\` en la máquina local para garantizar que la copia residual en disco C: coincida con la última versión de la fuente de verdad (SSOT).

### 2.3 Validación Automatizada contra Regresiones
Agregar aserciones en `scripts/Testing/Test-OptimizedISO-v2.ps1` que certifiquen:
- Que cada script consumidor resuelva y cargue efectivamente el motor Core sin fallbacks fallidos.
- Que `$global:RomanOS_NetworkPolicies` esté disponible y contenga todas las directivas de red requeridas.

---

## 3. Plan de Pruebas y Validación
1. Validación estática de codificación `UTF-8 con BOM` en todos los archivos modificados.
2. Prueba de compilación/sintaxis en Windows PowerShell 5.1 (`powershell.exe`).
3. Ejecución de prueba unitaria de carga de `Policy-Engine.ps1` desde `Win11-Network-Diagnostics-Optimizer.ps1`.
4. Ejecución de la suite completa de pruebas `Test-OptimizedISO-v2.ps1`.
