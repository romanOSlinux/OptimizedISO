# PLAN-0141: Correcciones de Ingeniería de Servicing (25H2 Checkpoint, Capabilities Error 87 y WinSxS CBS_E_PENDING)

**Fecha:** 2026-09-28  
**Estado:** COMPLETADO  
**Severidad:** ALTA / REFINAMIENTO DE INGENIERÍA  
**Rama:** `feature/offline-ui-tweaks`  
**Referencia:** Auditoría Forense Cero-Confianza de Logs de Compilación (`ISO_Build_20260928_142550.log`)

---

## 1. Contexto y Diagnóstico Forense

Durante la auditoría forense del registro de compilación real de una ISO Windows 11 25H2 (`ISO_Build_20260928_142550.log`), el sistema de logging forense en texto plano (implantado en PLAN-0139 y PLAN-0140) expuso con exactitud matemática tres anomalías operativas:

1. **Fallo en Inyección de Checkpoint KB5043080 en 25H2:**
   - *Evidencia:* `Fallo al integrar KB5043080-x64.msu (ExitCode: 552 [0x00000228]) // Mensaje: ERROR_DEPRECATION_OR_INCOMPATIBLE`.
   - *Causa Raíz:* En `scripts/Builder/Get-WindowsUpdates.ps1`, la matriz de búsqueda para `11_25H2` tenía asignado `Checkpoint = "KB5043080 $archTag"`. El paquete `KB5043080` fue diseñado exclusivamente para Windows 11 24H2 (Build 26100.1). Windows 11 25H2 (Build 26200+) posee su propia base RTM acumulativa y rechaza el manifiesto de 24H2 con error Win32 552.

2. **Falsos Positivos en Remoción de Capabilities en 25H2 (Error 87):**
   - *Evidencia:* 6 advertencias en DISM removiendo `Microsoft.Windows.WordPad`, `VBScript`, `StepsRecorder`, `InternetExplorer.OptionalComponents`, etc., con `ExitCode: 87 [0x00000057] // STDERR: No se reconoció el nombre de una funcionalidad de Windows.`
   - *Causa Raíz:* En Windows 11 25H2, estas funcionalidades obsoletas fueron eliminadas de raíz de la imagen. Al invocar `dism.exe /Remove-Capability`, DISM retorna `ExitCode: 87`. La función `Invoke-RomanOSDismComponentRemoval` solo reconocía `0x800f080c`, `not found` o `no se encuentra`, clasificando erróneamente el código 87 como `FAIL` y emitiendo `Write-Warn`.

3. **Falsa Advertencia en Consolidación WinSxS `/ResetBase` (`0x800F0806` / `CBS_E_PENDING`):**
   - *Evidencia:* `[WARN] ComponentStoreCleanup finalizo con ExitCode: -2146498554 [0x800F0806]`.
   - *Causa Raíz:* Tras la integración offline de actualizaciones acumulativas (como KB5054156), DISM registra transacciones pendientes que requieren el primer reinicio en vivo del SO antes de poder consolidar el almacén (`CBS_E_PENDING`). No es un error ni un fallo de la imagen; es el comportamiento estándar de la arquitectura CBS de Microsoft. Reportarlo como advertencia genera alarma innecesaria.

---

## 2. Objetivos de Ingeniería

1. **Eliminar Checkpoint KB5043080 de `11_25H2` en `Get-WindowsUpdates.ps1`:**
   - Preservar `Checkpoint` en `11_24H2` y `11_LTSC_2024` (donde sí es obligatorio).
   - Documentar explícitamente en el código la independencia acumulativa de 25H2.

2. **Reconocer Error 87 / "No se reconoció" como `SKIP` en `Invoke-RomanOSDismComponentRemoval`:**
   - Ampliar la detección de códigos y patrones en `Capability` y `OptionalFeature` para incluir `ExitCode 87`, `0x57`, `0x00000057` y textos como `No se reconoció` / `not recognized`.
   - Incrementar `$result.SkippedCount` y clasificar como `SKIP` sin generar alertas `[WARN]`.

3. **Reconocer `0x800F0806` (`CBS_E_PENDING`) como Consolidación Aplazada en `Invoke-RomanOSComponentStoreCleanup`:**
   - Detectar `ExitCode -2146498554` / `0x800F0806`.
   - Marcar `$result.IsDeferred = $true` y reportar mediante `Write-Info` indicando que la consolidación se completará automáticamente en el primer inicio.
   - En el llamador del Builder, asignar estado `SKIP` en `Add-AuditRecord` para no ensuciar el resumen de advertencias.

4. **Blindaje de Calidad y Pruebas Unitarias:**
   - Agregar aserciones en `scripts/Testing/Test-OptimizedISO-v2.ps1` que certifiquen el comportamiento ante estos 3 escenarios.
   - Validar codificación UTF-8 con BOM y compatibilidad en Windows PowerShell 5.1 (`powershell.exe`).
   - Ejecutar la suite de pruebas completa y verificar 610+ tests PASS, 0 FAIL.

---

## 3. Matriz de Cambios

| Componente | Archivo | Acción |
|---|---|---|
| Actualizaciones | `scripts/Builder/Get-WindowsUpdates.ps1` | Remover `Checkpoint` de `11_25H2` y actualizar comentarios |
| Remoción DISM | `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` | Incorporar Error 87 y "No se reconoció" a `SKIP` en Capabilities/Features |
| Consolidación WinSxS | `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` | Gestionar `0x800F0806` (`CBS_E_PENDING`) como consolidación aplazada limpia |
| Test Harness | `scripts/Testing/Test-OptimizedISO-v2.ps1` | Aserciones unitarias para matriz 25H2, skip error 87 y `0x800F0806` |
| Documentación | `docs/plans/README.md` | Registrar PLAN-0141 |

---

## 4. Criterios de Aceptación

- [x] `Get-WindowsUpdates.ps1 -Version "11_25H2"` no intenta buscar ni descargar `KB5043080`.
- [x] `11_24H2` y `11_LTSC_2024` mantienen `KB5043080` intacto.
- [x] Componentes DISM inexistentes en 25H2 son reportados como `SKIP` y no elevan `FailedCount` ni generan `[WARN]`.
- [x] `0x800F0806` en WinSxS es tratado como `[INFO] Consolidacion aplazada` y no genera `[WARN]`.
- [x] 100% scripts con UTF-8 BOM y 0 errores de sintaxis en `powershell.exe`.
- [x] Suite de pruebas unitarias supera 617/617 tests (100% PASS) con 0 regresiones.
