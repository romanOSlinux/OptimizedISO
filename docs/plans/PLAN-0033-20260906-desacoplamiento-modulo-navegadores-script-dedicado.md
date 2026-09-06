# PLAN-0033: Desacoplamiento del Módulo de Navegadores hacia Script Dedicado (Optimize-WebBrowsers.ps1) y Saneamiento en Debloat y Toolkit

**Fecha:** 2026-09-06  
**Autor:** romanOS / OptimizedISO Project Team  
**Estado:** PENDIENTE  
**Rama:** `feature/offline-ui-tweaks`  

---

## 1. Resumen Ejecutivo y Diagnóstico

### 1.1 El Problema
1. **Sobrecarga de Responsabilidades en `Win11-Debloat-v3-Adaptive.ps1`:** El script de Debloat contenía más de 170 líneas de código embebido (`function Invoke-BrowserDebloat`, líneas 355-521) y el parámetro `[switch]$BrowsersOnly`.
2. **Pregunta Redundante en el Flujo Principal (Sección 16):** Al ejecutar el debloat general, la Sección 16 detenía el flujo interactivo preguntando:
   `[16] ¿Desea aplicar la optimizacion oficial de Navegadores (GPU, Sleeping Tabs, Limite de Cache, Cero Procesos de Fondo, Debloat) para Edge, Chrome, Firefox y Brave? [Y/N] (Default: Y)`
   Esto es redundante porque:
   - En una máquina instalada con la ISO romanOS, `SetupComplete.cmd` ya ejecutó `Export-RomanOSBrowserCommands` aplicando más de 80 directivas GPO antes del primer inicio de sesión.
   - Si el usuario desea gestionar o re-aplicar navegadores individualmente, debe existir una herramienta modular dedicada y no incrustada dentro del debloat de Windows.
3. **Acoplamiento en el Toolkit Maestro (`romanOS-Toolkit.ps1`):** El Módulo 6 del Toolkit ("Optimizacion Oficial de Navegadores") llamaba a `Win11-Debloat-v3-Adaptive.ps1 -BrowsersOnly`, forzando la carga de todo el script de debloat para una tarea puntual de navegadores.

---

## 2. Objetivos del Plan

1. **Crear Script Modular Dedicado `scripts/Optimize-WebBrowsers.ps1`**:
   - Soporte para parámetros: `-Browser <All|Edge|Chrome|Firefox|Brave>`, `-Audit`, `-Apply`, `-Quiet`.
   - Integración nativa con `Core/Policy-Engine.ps1` (`Apply-RomanOSBrowserPolicies`, `Get-RomanOSBrowserPolicies`).
   - Integración con `Core/UI-Engine.ps1` para formato visual unificado.
   - Compatibilidad total con Windows PowerShell 5.1 y codificación UTF-8 con BOM.

2. **Sanear `scripts/Win11-Debloat-v3-Adaptive.ps1`**:
   - Eliminar el parámetro `[switch]$BrowsersOnly` y la función embebida redundante `Invoke-BrowserDebloat`.
   - Modificar la Sección 16:
     - Detectar si las directivas de navegadores ya están aplicadas (`$isIsoOptimized` o presencia de claves en `HKLM:\SOFTWARE\Policies\Microsoft\Edge`).
     - Si ya están aplicadas, reportar estado activo con `[OK]` sin abrir preguntas interactivas.
     - Si no están aplicadas, delegar la ejecución a `Optimize-WebBrowsers.ps1`.

3. **Actualizar `scripts/romanOS-Toolkit.ps1`**:
   - Actualizar `Invoke-BrowsersModule` para invocar directamente `Optimize-WebBrowsers.ps1`.

4. **Validación y Suite de Pruebas**:
   - Incorporar pruebas unitarias en `scripts/Test-OptimizedISO-v2.ps1` para `Optimize-WebBrowsers.ps1`.
   - Validar con `Invoke-TestSuite.ps1 -Quick` y AST en PowerShell 5.1.

---

## 3. Matriz de Archivos Afectados

| Archivo | Acción | Descripción |
|---|---|---|
| `scripts/Optimize-WebBrowsers.ps1` | **CREAR** | Nuevo script dedicado para optimización y debloat oficial de navegadores (Edge, Chrome, Firefox, Brave) basado en SSOT. |
| `scripts/Win11-Debloat-v3-Adaptive.ps1` | **MODIFICAR** | Eliminar `-BrowsersOnly`, purgar `Invoke-BrowserDebloat` embebido y convertir Sección 16 en verificación idempotente no intrusiva. |
| `scripts/romanOS-Toolkit.ps1` | **MODIFICAR** | Redirigir `Invoke-BrowsersModule` hacia `Optimize-WebBrowsers.ps1`. |
| `scripts/Test-OptimizedISO-v2.ps1` | **MODIFICAR** | Agregar asertos de validación para `Optimize-WebBrowsers.ps1` y desacoplamiento en Debloat. |
| `docs/plans/README.md` | **MODIFICAR** | Registrar PLAN-0033. |

---

## 4. Plan de Verificación

### Pruebas Automatizadas
1. **Auditoría AST y UTF-8 BOM:**
   `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .agents\skills\powershell-windows\scripts\Test-ScriptAstAndBom.ps1 -Path C:\OptimizedISO`
2. **Ejecución de Suite Rápida:**
   `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-TestSuite.ps1 -Quick`
3. **Prueba de Invocación Modular:**
   `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File scripts\Optimize-WebBrowsers.ps1 -Audit`
