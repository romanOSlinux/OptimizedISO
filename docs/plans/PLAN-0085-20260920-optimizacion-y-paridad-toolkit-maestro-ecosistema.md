# PLAN-0085: Sincronización Total de romanOS Toolkit Maestro: Inyección en ISO (OEM/WIM), Lanzador Raíz, Actualización Documental y Pruebas Unitarias

**Fecha:** 2026-09-20  
**Estado:** PENDIENTE  
**Autor:** romanOS Engineering / Antigravity  

---

## 1. Contexto y Diagnóstico Forense

`romanOS-Toolkit.ps1` constituye el Hub Maestro CLI/TUI interactivo desacoplado (*Zero-Resident Footprint*) para tareas de administración, soporte, mantenimiento, debloat y auditoría en el ecosistema romanOS.

En hitos arquitectónicos recientes se diseñaron e implementaron dos componentes de alto impacto:
1. **Auditor Universal de Optimización del Sistema (`Audit-SystemOptimization.ps1`, PLAN-0079):** Herramienta multi-hardware y portátil que evalúa 10 dominios de rendimiento, latencia y observabilidad bajo estándares oficiales de Microsoft Learn, AMD, Intel y WDDM.
2. **Conmutador Bimodal Gaming vs. Dev (`Switch-GameDevMode.ps1` y `.cmd`, PLAN-0080 y PLAN-0081):** Solución para alternar dinámicamente entre un perfil ultraligero de juegos (liberación agresiva de RAM para iGPU/APU Ryzen y recorte de devoradores) y un perfil de trabajo/desarrollo (restauración de Hyper-V, WSL2, Docker y servicios dev).

Ambos componentes fueron enlazados localmente en `romanOS-Toolkit.ps1` (opciones 13 y 14 del menú principal, y parámetros de línea de comandos `-Module UniversalAudit` y `-Module GameDevSwitch`).

### Brechas y Discrepancias Detectadas en la Auditoría:
1. **Desfase de Inyección en la ISO (`New-OptimizedWindowsISO-v2.ps1`):**
   * El generador de la ISO inyecta scripts post-instalación en `$OEM$\$$\Setup\Scripts\Modules` y en el WIM montado (`$wimScriptsDir\Modules`).
   * Sin embargo, `Audit-SystemOptimization.ps1` y `Switch-GameDevMode.ps1` / `Switch-GameDevMode.cmd` **no están registrados en los bloques de inyección `$OEM$` ni en la rutina de servicing del WIM**.
   * **Consecuencia:** En un sistema desplegado limpiamente desde la ISO generada, al ejecutar `romanOS-Toolkit.cmd` en el escritorio, las opciones 13 y 14 fallan con error de archivo no encontrado.
2. **Ausencia de Lanzador Raíz del Toolkit:**
   * La raíz del repositorio (`C:\OptimizedISO\`) cuenta con accesos directos de 1 clic para `Lanzar-romanOS-Studio.exe`, `Lanzar-Builder.cmd`, `Compilar-ISO-Host-Ryzen8600G.cmd`, etc., pero carece de un `Lanzar-romanOS-Toolkit.cmd` directo para ejecutar el Hub Maestro en el Host sin tener que navegar a `scripts\Modules\`.
3. **Desvío de Documentación (*Configuration Drift*, Regla 10):**
   * En `docs/MANUAL_DE_USO.md` y `docs/GUIA_DE_EJECUCION_Y_COMANDOS.md` persisten referencias rotas hacia `scripts/romanOS-Toolkit.cmd` (ubicación anterior a la reorganización modular de la raíz).
4. **Carencia de Pruebas Unitarias Específicas:**
   * `scripts/Testing/Test-OptimizedISO-v2.ps1` no cuenta aún con aserciones que certifiquen que `romanOS-Toolkit.ps1` soporte formalmente los nuevos parámetros y opciones de menú, ni que el Builder garantice su presencia física en los destinos de inyección.

---

## 2. Objetivos Técnicos de la Implementación

1. **Garantizar Paridad de Inyección en la ISO (SSOT y WIM Servicing):**
   * Incorporar `Audit-SystemOptimization.ps1`, `Switch-GameDevMode.ps1` y `Switch-GameDevMode.cmd` a las rutinas de copia `$OEM$` (`$OEMScriptsDir\Modules` y `$OEMScriptsDir1\Modules`) dentro de [scripts/Builder/New-OptimizedWindowsISO-v2.ps1](file:///c:/OptimizedISO/scripts/Builder/New-OptimizedWindowsISO-v2.ps1).
   * Incorporar dichos scripts al servicing offline del WIM montado (`$wimModulesDest` y `$wimScriptsDir`).
2. **Crear Lanzador de Raíz Ergonómico (`Lanzar-romanOS-Toolkit.cmd`):**
   * Proveer un archivo batch en la raíz del repositorio con auto-elevación UAC (`RunAs`), flag `-STA` y redirección de argumentos `%*` hacia `scripts\Modules\romanOS-Toolkit.ps1`.
   * Asegurar codificación estricta UTF-8 No-BOM / ANSI en cumplimiento de la **Regla 4**.
3. **Mantenimiento en Cascada Documental (*Docs-as-Code*, Regla 10):**
   * Actualizar rutas en [docs/MANUAL_DE_USO.md](file:///c:/OptimizedISO/docs/MANUAL_DE_USO.md) y [docs/GUIA_DE_EJECUCION_Y_COMANDOS.md](file:///c:/OptimizedISO/docs/GUIA_DE_EJECUCION_Y_COMANDOS.md).
   * Documentar el lanzador raíz en [README.md](file:///c:/OptimizedISO/README.md).
4. **Certificación Mediante Arnés de Pruebas Unitarias:**
   * Agregar aserciones unitarias en [scripts/Testing/Test-OptimizedISO-v2.ps1](file:///c:/OptimizedISO/scripts/Testing/Test-OptimizedISO-v2.ps1) validando el soporte CLI y la inyección garantizada en el Builder.

---

## 3. Plan de Cambios Detallado

### Componente 1: Generador de ISOs ([scripts/Builder/New-OptimizedWindowsISO-v2.ps1](file:///c:/OptimizedISO/scripts/Builder/New-OptimizedWindowsISO-v2.ps1))
* **Inyección `$OEM$`:**
  * Añadir copia de `Audit-SystemOptimization.ps1` a `$destModulesDir` y `$destModulesDir1`.
  * Añadir copia de `Switch-GameDevMode.ps1` y `Switch-GameDevMode.cmd` a `$destModulesDir` y `$destModulesDir1`.
* **Inyección WIM Servicing:**
  * Añadir copia de `Audit-SystemOptimization.ps1` a `$wimModulesDest`.
  * Añadir copia de `Switch-GameDevMode.ps1` y `Switch-GameDevMode.cmd` a `$wimModulesDest` y `$wimScriptsDir`.
* **Registro en Auditoría de Compilación:**
  * Invocar `Add-AuditRecord` para registrar la inyección exitosa de ambos módulos.

### Componente 2: Lanzador Raíz ([Lanzar-romanOS-Toolkit.cmd](file:///c:/OptimizedISO/Lanzar-romanOS-Toolkit.cmd))
* **[NUEVO] `Lanzar-romanOS-Toolkit.cmd`:**
  * Script de ejecución inmediata en la raíz del proyecto.
  * Auto-elevación UAC mediante `net session` y re-invocación con `RunAs`.
  * Verificación de existencia de `scripts\Modules\romanOS-Toolkit.ps1`.
  * Invocación con `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Modules\romanOS-Toolkit.ps1" %*`.
  * Codificación: UTF-8 No-BOM / ANSI puro.

### Componente 3: Documentación y Guías de Uso (*Docs-as-Code*)
* **[MODIFICAR] [docs/MANUAL_DE_USO.md](file:///c:/OptimizedISO/docs/MANUAL_DE_USO.md):**
  * Corregir referencias a `scripts/romanOS-Toolkit.cmd` reemplazándolas por `Lanzar-romanOS-Toolkit.cmd` y `scripts/Modules/romanOS-Toolkit.cmd`.
* **[MODIFICAR] [docs/GUIA_DE_EJECUCION_Y_COMANDOS.md](file:///c:/OptimizedISO/docs/GUIA_DE_EJECUCION_Y_COMANDOS.md):**
  * Corregir referencias obsoletas al lanzador del Toolkit.
* **[MODIFICAR] [README.md](file:///c:/OptimizedISO/README.md):**
  * Incluir `Lanzar-romanOS-Toolkit.cmd` en la tabla de lanzadores principales de la raíz.

### Componente 4: Batería de Pruebas Unitarias ([scripts/Testing/Test-OptimizedISO-v2.ps1](file:///c:/OptimizedISO/scripts/Testing/Test-OptimizedISO-v2.ps1))
* **[MODIFICAR] `scripts/Testing/Test-OptimizedISO-v2.ps1`:**
  * Añadir sección de pruebas de regresión para el **PLAN-0085**:
    * Validar que `Lanzar-romanOS-Toolkit.cmd` exista en la raíz y sea UTF-8 No-BOM.
    * Validar que `romanOS-Toolkit.ps1` contemple los ValidateSet `UniversalAudit`, `SystemAudit`, `GameDevSwitch`, `GameSwitch`, `GameAggressive`, `DevSwitch`.
    * Validar que `romanOS-Toolkit.ps1` contenga las opciones del menú interactivo para Auditor Universal y Conmutador Bimodal.
    * Validar que `New-OptimizedWindowsISO-v2.ps1` inyecte `Audit-SystemOptimization.ps1` y `Switch-GameDevMode` tanto en `$OEM$` como en el WIM montado.

---

## 4. Plan de Verificación Empírica

1. **Auditoría de Codificación y Sintaxis (Fase Rápida):**
   ```powershell
   & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -File "C:\OptimizedISO\scripts\Testing\Invoke-TestSuite.ps1" -Quick
   ```
   * Criterio: 100% PASS en scripts evaluados (BOM correcto y 0 errores AST).
2. **Validación del Arnés Completo de Pruebas:**
   ```powershell
   & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -File "C:\OptimizedISO\scripts\Testing\Test-OptimizedISO-v2.ps1"
   ```
   * Criterio: Cero fallos (`FAIL : 0`) en las más de 535 aserciones.
3. **Prueba de Invocación en Frío del Nuevo Lanzador:**
   ```powershell
   & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'C:\OptimizedISO\scripts\Modules\romanOS-Toolkit.ps1' -WhatIf }"
   ```
   * Criterio: Ejecución sin errores y salida con código de retorno 0.
