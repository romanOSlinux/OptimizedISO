# PLAN-0060: Estabilidad de Actualizaciones Acumulativas: Cuarentena de Calidad (Quality Update Deferral) y Bloqueo de Previews/CFR para Todos los Perfiles de la ISO

- **ID del Plan:** PLAN-0060
- **Fecha:** 2026-09-07
- **Estado:** PENDIENTE
- **Autor:** romanOS Engineering / Antigravity Agent
- **Rama:** `feature/offline-ui-tweaks`

---

## 1. Contexto y Justificación Técnica

Las actualizaciones de Windows presentan con frecuencia regresiones críticas, caídas de rendimiento, incompatibilidades con controladores y fallos de sistema en los días inmediatamente posteriores a su publicación. La investigación en documentación oficial de Microsoft (**Windows Update for Business - WUfB**, **Update Policy CSP**, **Known Issue Rollback - KIR**) revela dos causas primarias:

1. **Actualizaciones de Vista Previa (Semanas C y D — "Preview Releases" / CFR):**
   - Paquetes opcionales no consolidados que contienen código experimental y *Continuous Feature Releases* (CFR o "Moments").
   - Su instalación convierte al usuario en probador beta involuntario de Microsoft.
2. **Día Cero del "Patch Tuesday" (Semana B — Segundo martes del mes):**
   - Las actualizaciones acumulativas obligatorias (LCU) se publican simultáneamente en millones de equipos.
   - Microsoft tarda estadísticamente entre **3 y 7 días** en detectar fallos masivos mediante telemetría global y activar **Known Issue Rollback (KIR)** o publicar revisiones *Out-Of-Band* (OOB).
   - Instalar el parche en el Día 0 expone al equipo a problemas que son resueltos o mitigados pocos días después.

Para solucionar esto de manera oficial y robusta en **todos los perfiles de la ISO** (Conservador, Gaming y Hardcore), se implementará una estrategia de **Cuarentena de Maduración de 7 Días** y **Bloqueo Total de Previews**.

---

## 2. Objetivos del Plan

1. **Gobernanza Canónica en SSOT (`Policy-Engine.ps1`):**
   - Registrar en `$global:RomanOS_Policies` para **todos los perfiles** (`Profiles = @(1, 2, 3)`):
     - `POL_WU_ALLOW_OPTIONAL_CONTENT`: `AllowOptionalContent = 0` bajo `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` (bloquea previews de Semana C/D y código CFR beta).
     - `POL_WU_CONTINUOUS_INNOVATION`: `IsContinuousInnovationOptedIn = 0` bajo `HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings` (desactiva *"Obtener las últimas actualizaciones tan pronto como estén disponibles"*).
     - `POL_WU_DEFER_QUALITY`: `DeferQualityUpdates = 1` bajo `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` (activa la cuarentena de calidad).
     - `POL_WU_DEFER_QUALITY_DAYS`: `DeferQualityUpdatesPeriodInDays = 7` bajo `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` (ventana de maduración de 7 días que cubre el ciclo de KIR de Patch Tuesday).
2. **Inyección en Despliegue e ISO (`New-OptimizedWindowsISO-v2.ps1`):**
   - Exportación automática a `autounattend.xml` mediante `Export-RomanOSUnattendCommands` para todos los perfiles.
   - Inyección en el bloque de fallback de `autounattend.xml` en la fase `specialize`.
   - Inyección offline en la colmena `SOFTWARE` del WIM montado dentro del array base `$swTweaks` para paridad offline total.
3. **Auditoría Post-Instalación y Forense:**
   - Actualizar `PostInstall-Diagnostics.ps1` para verificar el estado del diferimiento de calidad y el bloqueo de previews.
   - Actualizar `Audit-FreshInstallFootprint.ps1` integrando `AllowOptionalContent` y `DeferQualityUpdatesPeriodInDays` en la matriz forense.
4. **Certificación en Test Harness:**
   - Añadir aserciones unitarias en `Test-OptimizedISO-v2.ps1` y validar con `Invoke-TestSuite.ps1`.

---

## 3. Matriz de Cambios por Archivo

| Archivo | Acción | Descripción |
| :--- | :---: | :--- |
| `scripts/Core/Policy-Engine.ps1` | MODIFICAR | Registrar `POL_WU_ALLOW_OPTIONAL_CONTENT`, `POL_WU_CONTINUOUS_INNOVATION`, `POL_WU_DEFER_QUALITY` y `POL_WU_DEFER_QUALITY_DAYS` para perfiles 1, 2 y 3. |
| `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` | MODIFICAR | Añadir inyección en bloque fallback base de unattend y en array base `$swTweaks` offline del WIM. |
| `scripts/Modules/PostInstall-Diagnostics.ps1` | MODIFICAR | Auditar estado de cuarentena (7 días) y bloqueo de previews en sección de Windows Update. |
| `scripts/Modules/Audit-FreshInstallFootprint.ps1` | MODIFICAR | Añadir directivas de cuarentena y bloqueo de previews a la tabla forense. |
| `scripts/Testing/Test-OptimizedISO-v2.ps1` | MODIFICAR | Incorporar bloque de pruebas unitarias para PLAN-0060. |
| `docs/plans/README.md` | MODIFICAR | Registrar PLAN-0060 en el índice oficial de planes. |

---

## 4. Plan de Verificación Empírica

1. **Inspección de Codificación UTF-8 con BOM y 0 Errores AST:**
   - Comprobación de cabecera `0xEF, 0xBB, 0xBF` en todos los archivos `.ps1` modificados.
   - Verificación con `[Parser]::ParseFile` en Windows PowerShell 5.1.
2. **Pruebas de Exportación Semántica:**
   - Validar que `Export-RomanOSUnattendCommands -Profile 1`, `-Profile 2` y `-Profile 3` exportan `AllowOptionalContent = 0`, `DeferQualityUpdates = 1` y `DeferQualityUpdatesPeriodInDays = 7`.
3. **Ejecución Completa de Pruebas:**
   - Ejecución de `Test-OptimizedISO-v2.ps1` (objetivo: 435+ PASS, 0 FAIL).
   - Ejecución de `Invoke-TestSuite.ps1` (100% PASS).
