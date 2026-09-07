# PLAN-0047: Corrección de Bloqueo, Auto-Elevación y Experiencia de Usuario en Optimize-WebBrowsers.ps1

**Fecha:** 2026-09-07  
**Autor:** romanOS / OptimizedISO Project Team (Advanced Agentic Coding)  
**Estado:** COMPLETADO  
**Rama:** `feature/offline-ui-tweaks`  

---

## 1. Diagnóstico de Causa Raíz

### 1.1 Síntoma Reportado por el Usuario
> *"el script: Optimize-WebBrowsers.ps1 se ejecuta, y queda titilando sin finalizar, ejecuta unas opcines da ok pero no finaliza"*

### 1.2 Análisis Técnico del Fallo
1. **Falta de Auto-Elevación UAC en `Optimize-WebBrowsers.ps1`:**
   A diferencia de todos los demás módulos del proyecto (`Win11-Network-Diagnostics-Optimizer.ps1`, `romanOS-Toolkit.ps1`, `Win11-Debloat-v3-Adaptive.ps1`), `Optimize-WebBrowsers.ps1` no implementa el bloque canónico de introspección de privilegios y auto-elevación con `Start-Process -Verb RunAs`. Al ejecutarse en contextos normales o desde scripts no elevados, intenta escribir en `HKLM:\SOFTWARE\Policies\...`, fallando en la directiva de Windows AI / Copilot con error de acceso denegado o produciendo comportamiento anómalo.

2. **Bloqueo Silencioso por `pause >nul` en `Optimize-WebBrowsers.cmd`:**
   En `Optimize-WebBrowsers.cmd`, la línea 32 contiene `pause >nul` tras un mensaje estático. En terminales cmd/powershell, `pause >nul` suprime la instrucción nativa del sistema (`Presione una tecla para continuar . . .`), dejando el cursor titilando en negro indefinidamente. El usuario percibe que el proceso no finalizó ni retornó el control.

3. **Sobrecarga de Procesos Hijos `reg.exe` y Riesgo de Espera en STDIN:**
   En `Policy-Engine.ps1` (`Apply-RomanOSBrowserPolicies`), se invocan 93 procesos externos síncronos `& reg.exe add ... 2>&1 | Out-Null`.
   - Spawning de 93 procesos separados añade una latencia innecesaria y bloqueos de buffer ante software de seguridad (Defender/SmartScreen).
   - Redirigir `2>&1 | Out-Null` oculta cualquier solicitud interactiva de confirmación (ej. ante flags no interpretados), dejando el subproceso bloqueado en STDIN con el cursor parpadeando.

4. **Ausencia de Interfaz Unificada (`UI-Engine.ps1`) y Cierre Determinista:**
   `Optimize-WebBrowsers.ps1` no cargaba `UI-Engine.ps1` ni ofrecía menú interactivo ni el bloque de resumen estándar (`Show-UnifiedSummary`), careciendo de un flujo de salida claro en ejecuciones interactivas directas.

---

## 2. Objetivos y Cambios Propuestos

### 2.1 `scripts/Modules/Optimize-WebBrowsers.ps1`
1. **Auto-Elevación UAC Canónica:**
   Incorporar verificación `WindowsBuiltInRole::Administrator` y auto-elevación con `Start-Process -Verb RunAs` bajo Windows PowerShell 5.1 (`-STA -NoProfile -ExecutionPolicy Bypass`).
2. **Integración con `UI-Engine.ps1`:**
   Carga mediante resolución multi-ruta SSOT de `UI-Engine.ps1`.
3. **Modo Interactivo Intuitivo:**
   Si se ejecuta sin parámetros en una terminal interactiva, presentar menú unificado con `Show-UnifiedMenu`:
   - `[1]` Todos los navegadores (Edge, Chrome, Firefox, Brave) [Recomendado]
   - `[2]` Solo Microsoft Edge
   - `[3]` Solo Google Chrome
   - `[4]` Solo Mozilla Firefox
   - `[5]` Solo Brave Browser
   - `[6]` Auditar directivas actuales (solo lectura)
   - `[0]` Salir
4. **Resumen Visual y Cierre Limpio:**
   Uso de `Show-UnifiedSummary` y finalización determinista con prompt claro `[i] Presione ENTER para salir...` únicamente en sesiones interactivas que requieran confirmación.

### 2.2 `scripts/Core/Policy-Engine.ps1` (`Apply-RomanOSBrowserPolicies`)
1. **Aplicación Nativa In-Process con `Set-ItemProperty`:**
   Reemplazar las 93 invocaciones externas de `reg.exe` por `Set-ItemProperty` nativo de PowerShell (`-Force -ErrorAction Stop`).
2. **Fallback Resiliente:**
   En caso de excepción en `Set-ItemProperty`, fallback inmediato a `reg.exe add` con parámetros estrictamente protegidos (`/f`).
3. **Rendimiento:** Reducción del tiempo de ejecución de ~10s a ~0.15s, con cero riesgo de bloqueos en STDIN.

### 2.3 `scripts/Modules/Optimize-WebBrowsers.cmd` y `scripts/Modules/romanOS-Toolkit.ps1`
1. Saneamiento del lanzador batch: reemplazar `pause >nul` por un mensaje interactivo explícito o delegar el control de cierre al propio script de PowerShell.
2. Evitar pausas dobles redundantes en la opción 6 del Toolkit.

---

## 3. Matriz de Archivos Afectados

| Archivo | Acción | Motivo |
|---|---|---|
| `scripts/Modules/Optimize-WebBrowsers.ps1` | MODIFICAR | Auto-elevación UAC, integración con UI-Engine, menú interactivo y resumen visual. |
| `scripts/Core/Policy-Engine.ps1` | MODIFICAR | Optimización in-process de `Apply-RomanOSBrowserPolicies` con `Set-ItemProperty`. |
| `scripts/Modules/Optimize-WebBrowsers.cmd` | MODIFICAR | Saneamiento de `pause >nul` para evitar cursores parpadeantes huérfanos. |
| `docs/plans/README.md` | MODIFICAR | Registro oficial de PLAN-0047. |

---

## 4. Plan de Verificación

1. **Prueba de Codificación y AST (Regla 4):**
   Verificar UTF-8 con BOM y 0 errores de parsing en `powershell.exe` (Windows PowerShell 5.1).
2. **Prueba en Frío de `Apply-RomanOSBrowserPolicies`:**
   Ejecutar en PowerShell 5.1 verificando que procese las 93 directivas en milisegundos sin bloqueos.
3. **Prueba del Modo Interactivo y Desatendido:**
   - Probar `-Browser Edge -Audit` (no interactivo).
   - Probar ejecución interactiva con menú.
4. **Ejecución de la Suite de Pruebas:**
   `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File scripts\Testing\Invoke-TestSuite.ps1 -Quick`
