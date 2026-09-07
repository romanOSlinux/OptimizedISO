# PLAN-0048: Hardware Intelligence para AI PC (NPU, RDNA3/Arc), Saneamiento SSOT en el Builder y Certificación 100% del Test Harness

**Fecha:** 2026-09-07  
**Autor:** romanOS / OptimizedISO Project Team (Advanced Agentic Coding)  
**Estado:** COMPLETADO  
**Rama:** `feature/offline-ui-tweaks`  

---

## 1. Resumen Ejecutivo y Diagnóstico

### 1.1 El Problema
1. **Desfase en Plataformas Modernas "AI PC" (NPU e iGPUs RDNA3 / Arc):**
   - Windows 11 24H2 y 25H2 introducen soporte nativo para arquitecturas de computación neuronal (NPU) en silicios modernos (AMD Ryzen AI / XDNA, Intel Core Ultra / NPU, Qualcomm Snapdragon X Elite).
   - `Win11-Debloat-v3-Adaptive.ps1` cuenta con filtros legacy basados en strings genéricos (`AMD Radeon RX` y `NVIDIA`), omitiendo APUs potentes de última generación como la **AMD Radeon 760M/780M/890M (RDNA3/3.5)** e **Intel Arc**, impidiendo que se les active HAGS (*Hardware-Accelerated GPU Scheduling*) y modo MSI (*Message Signaled Interrupts*).
   - Además, al carecer de detección de NPU (`ComputeAccelerator`), las plantillas de debloat corren el riesgo de inhabilitar componentes de runtime de IA requeridos por los controladores del fabricante y por DirectML.
2. **Violación de SSOT en el Builder (`New-OptimizedWindowsISO-v2.ps1`):**
   - En la generación de `autounattend.xml` y en la plantilla de `SetupComplete.cmd`, existen más de 30 líneas de comandos `reg add` hardcodeados (BypassNRO, Modo Oscuro, políticas de privacidad, telemetría) que ya están catalogadas canónicamente en `Policy-Engine.ps1`. Si una directiva se actualiza en el motor, el Builder no se entera y produce *configuration drift*.
3. **29 Aserciones Desfasadas en `Test-OptimizedISO-v2.ps1`:**
   - La suite de pruebas de regresión reporta 251 PASS y 29 FAIL debido a cambios de rutas históricas (módulos de drivers movidos a la raíz `Drivers/`), cambios de nombres de funciones o aserciones que comparan arrays de objetos con booleanos en PowerShell 5.1.

---

## 2. Objetivos del Plan

1. **Modernización de `Hardware-Engine.ps1`:**
   - Detección oficial de NPUs mediante PnP Class `ComputeAccelerator` y filtrado por identificadores compatibles (AMD XDNA, Intel AI Boost, Qualcomm).
   - Ampliación de la heurística de GPUs para soportar iGPUs de alto rendimiento (RDNA3 `[6-8][0-9]{2}M` e Intel Arc).
   - Detección de soporte para **BypassIO** (DirectStorage 1.2) mediante `fltmc.exe`.
2. **Convergencia en `Win11-Debloat-v3-Adaptive.ps1`:**
   - Consumir el objeto estructurado de `Hardware-Engine.ps1` eliminando consultas WMI redundantes.
   - Si se detecta NPU, proteger los servicios neuronales del sistema.
   - Extender las optimizaciones gaming (HAGS, MSI Mode) a iGPUs RDNA3 y Arc.
3. **Erradicación de Redundancias SSOT en `New-OptimizedWindowsISO-v2.ps1`:**
   - Delegar la generación de comandos offline en `Export-RomanOSUnattendCommands`.
   - Delegar las directivas online de `SetupComplete.cmd` en la invocación de `Policy-Engine.ps1`.
4. **Saneamiento del Test Harness (`Test-OptimizedISO-v2.ps1`):**
   - Actualizar rutas de drivers a `Drivers\*.ps1`.
   - Corregir las aserciones de transformación booleana en PowerShell 5.1 (`$debloatContent -match ...`).
   - Retornar a una tasa del **100% PASS** en todas las aserciones.

---

## 3. Matriz de Archivos Afectados

| Archivo | Acción | Descripción |
|---|---|---|
| `scripts/Core/Hardware-Engine.ps1` | MODIFICAR | Añadir detección de NPU (`ComputeAccelerator`), regex de iGPUs RDNA3/Arc y BypassIO. |
| `scripts/Modules/Win11-Debloat-v3-Adaptive.ps1` | MODIFICAR | Integrar perfil de Hardware-Engine, proteger NPU y activar HAGS/MSI en APUs modernas. |
| `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` | MODIFICAR | Delegar directivas de autounattend y SetupComplete en Policy-Engine (SSOT). |
| `scripts/Testing/Test-OptimizedISO-v2.ps1` | MODIFICAR | Corregir rutas de drivers, firmas de funciones y aserciones en PS 5.1 para lograr 100% PASS. |
| `docs/plans/README.md` | MODIFICAR | Registrar PLAN-0048. |

---

## 4. Plan de Verificación

1. **Pruebas Unitarias de Hardware Engine (Regla 4):**
   `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File scripts\Testing\Test-HardwareEngine.ps1`
2. **Auditoría AST y UTF-8 BOM en todo el árbol:**
   `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File scripts\Testing\Invoke-TestSuite.ps1 -Quick`
3. **Validación del Test Harness Completo:**
   `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File scripts\Testing\Test-OptimizedISO-v2.ps1`
   - Meta estricta: **0 fallos (100% PASS)**.
