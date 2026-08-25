# PLAN-0010 — Integración y Estandarización de la Utilidad de Limpieza y Rescate de Residuos (`Limpiar-ResiduosWinISO.ps1`)

## Estado: PENDIENTE
## Fecha: 2026-08-24

---

## Descripción del Problema

Durante el proceso de compilación y optimización de imágenes de Windows con `New-OptimizedWindowsISO-v2.ps1`, el script interactúa con subsistemas de bajo nivel de Windows (DISM, 7-Zip, montajes de imágenes WIM, colmenas de registro offline y archivos temporales de gran volumen).

Si el proceso de compilación se interrumpe prematuramente debido a:
- Cancelación manual del usuario (`Ctrl+C` o cierre intempestivo de consola).
- Timeouts en comandos de DISM o errores no controlados.
- Cortes de energía o reinicio del host.

Se generan residuos masivos y bloqueos en el sistema:
1. **Espacio muerto en disco:** Carpetas `%TEMP%\WinISO_Extract_*` de entre **5 y 12 GB** por cada ejecución interrumpida.
2. **Puntos de montaje DISM bloqueados:** Carpetas `C:\WimMount_*` que quedan tomadas por el kernel de Windows, impidiendo su eliminación normal o re-montaje.
3. **Temporales de integración:** Carpetas `C:\WinISO_Scratch_*` abandonadas.
4. **Colmenas de registro retenidas:** Claves como `HKLM\OfflineDefaultUser` que impiden ejecuciones subsiguientes con error `Exit code: 1`.
5. **Descargadores temporales:** Scripts `%TEMP%\Fido_*.ps1` y carpetas `%TEMP%\MCT_*`.

### Situación del script `Limpiar-ResiduosWinISO.ps1`
El repositorio cuenta con un script inicial `scripts/Limpiar-ResiduosWinISO.ps1` que detecta y limpia con éxito estas huellas. Sin embargo, actualmente es un script aislado:
- No cuenta con codificación UTF-8 con BOM certificada.
- Carece de parámetros de línea de comandos (`-ScanOnly`, `-Force`, `-Silent`) para automatización o ejecución headless.
- No está integrado en el hub maestro `romanOS-Toolkit.ps1`.
- No está cubierto por la suite de pruebas unitarias ni el orquestador `Invoke-TestSuite.ps1`.

---

## Fuentes Oficiales de Respaldo

- **DISM Cleanup Mountpoints:** [learn.microsoft.com — DISM Image Management Command-Line Options](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism-image-management-command-line-options-s14)
- **Desmontaje forzado y descarte de imágenes:** [learn.microsoft.com — Dismount-WindowsImage](https://learn.microsoft.com/en-us/powershell/module/dism/dismount-windowsimage)
- **Manejo de registros offline y garbage collection:** [learn.microsoft.com — reg unload](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/reg-unload)
- **PowerShell Advanced Functions y Parameter Sets:** [learn.microsoft.com — about_Functions_Advanced_Parameters](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters)

---

## Objetivo

Estandarizar e integrar formalmente `Limpiar-ResiduosWinISO.ps1` en la arquitectura de `romanOS / OptimizedISO`:
1. **Estandarización de Código:** Codificación UTF-8 con BOM, funciones avanzadas con `[CmdletBinding(SupportsShouldProcess)]`, parámetros `-ScanOnly`, `-Force` y `-Silent`.
2. **Integración en Hub Maestro (`romanOS-Toolkit.ps1`):** Agregar opción en el menú de mantenimiento para limpieza y rescate con un clic.
3. **Rescate Preventivo en `New-OptimizedWindowsISO-v2.ps1`:** Agregar parámetro opcional `-CleanRescue` para sanitizar residuos antes de compilar.
4. **Arnés de Pruebas Unitarias:** Incorporar fase de tests en `Test-OptimizedISO-v2.ps1` y certificar en `Invoke-TestSuite.ps1`.

---

## Proposed Changes

---

### Componente 1 — Estandarización y Parametrización de `Limpiar-ResiduosWinISO.ps1`

#### [MODIFY] [Limpiar-ResiduosWinISO.ps1](file:///c:/OptimizedISO/scripts/Limpiar-ResiduosWinISO.ps1)

- Transformar en función avanzada con soporte para parámetros CLI:
  ```powershell
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
      [switch]$ScanOnly,             # Solo detecta y muestra reporte sin borrar
      [switch]$Force,                # Limpia todos los residuos sin confirmación interactiva
      [switch]$Silent,               # Salida mínima para uso desde otros scripts
      [switch]$IncludeDependencies   # Incluye desinstalación interactiva de 7-Zip/OSCDIMG
  )
  ```
- Modularizar la lógica en funciones (`Find-IsoResiduals`, `Remove-IsoResidualItem`, `Invoke-CleanupMountpoints`).
- Guardar estrictamente en **UTF-8 con BOM** (`0xEF, 0xBB, 0xBF`).

---

### Componente 2 — Integración en `romanOS-Toolkit.ps1`

#### [MODIFY] [romanOS-Toolkit.ps1](file:///c:/OptimizedISO/scripts/romanOS-Toolkit.ps1)

- Añadir opción en la sección de mantenimiento:
  ```text
  [8] Rescatar / Limpiar residuos de compilación ISO (WIM, DISM, TEMP)
  ```
- Invocar `Limpiar-ResiduosWinISO.ps1` directamente desde el hub.

---

### Componente 3 — Parámetro de Rescate Preventivo en `New-OptimizedWindowsISO-v2.ps1`

#### [MODIFY] [New-OptimizedWindowsISO-v2.ps1](file:///c:/OptimizedISO/scripts/New-OptimizedWindowsISO-v2.ps1)

- Agregar parámetro `-CleanRescue`:
  ```powershell
  .PARAMETER CleanRescue
  Ejecuta una limpieza automática de residuos de compilaciones previas (WimMount, Scratch, Extract) antes de iniciar.
  ```
- Si está activo o si el diagnóstico pre-vuelo detecta residuos huérfanos, invocar la limpieza preventiva antes de comenzar.

---

### Componente 4 — Arnés de Pruebas Unitarias y Orquestador Maestro

#### [MODIFY] [Test-OptimizedISO-v2.ps1](file:///c:/OptimizedISO/scripts/Test-OptimizedISO-v2.ps1)

- Agregar fase de pruebas para la utilidad de limpieza:
  - Detección de carpetas mock `WinISO_Extract_*` y `WinISO_Scratch_*`.
  - Prueba de cálculo de tamaño y retorno estructurado de `Find-IsoResiduals`.
  - Verificación de ejecución con `-ScanOnly` y `-WhatIf`.

#### [MODIFY] [Invoke-TestSuite.ps1](file:///c:/OptimizedISO/scripts/Invoke-TestSuite.ps1)

- Añadir `Limpiar-ResiduosWinISO.ps1` a la lista de scripts certificados para auditoría AST y validación UTF-8 BOM en PowerShell 5.1.

---

## Plan de Ejecución

| Fase | Acción | Archivo |
|---|---|---|
| 1 | Parametrizar y guardar en UTF-8 BOM `Limpiar-ResiduosWinISO.ps1` | `scripts/Limpiar-ResiduosWinISO.ps1` |
| 2 | Integrar en menú de `romanOS-Toolkit.ps1` | `scripts/romanOS-Toolkit.ps1` |
| 3 | Agregar soporte `-CleanRescue` en `New-OptimizedWindowsISO-v2.ps1` | `scripts/New-OptimizedWindowsISO-v2.ps1` |
| 4 | Cobertura en `Test-OptimizedISO-v2.ps1` e `Invoke-TestSuite.ps1` | `scripts/Test-*.ps1` |
| 5 | Actualizar `docs/plans/README.md` a `COMPLETADO` | `docs/plans/` |
| 6 | Validación completa en Windows PowerShell 5.1 y commit atómico | Git |

---

## Verification Plan

### Automated Tests
```powershell
# 1. Validación en frío de sintaxis en PowerShell 5.1
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -STA -NoProfile -ExecutionPolicy Bypass `
    -Command "& { & 'scripts/Limpiar-ResiduosWinISO.ps1' -ScanOnly }"

# 2. Arnés de pruebas unitarias
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -STA -NoProfile -ExecutionPolicy Bypass `
    -Command "& { & 'scripts/Test-OptimizedISO-v2.ps1' }"

# 3. Orquestador maestro
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -STA -NoProfile -ExecutionPolicy Bypass `
    -Command "& { & 'scripts/Invoke-TestSuite.ps1' -Quick }"
```

### Manual Verification
- Ejecutar `Limpiar-ResiduosWinISO.ps1 -ScanOnly` y verificar que lista correctamente carpetas temporales sin borrarlas.
- Ejecutar `Limpiar-ResiduosWinISO.ps1` de forma interactiva y navegar el menú.
- Verificar que `romanOS-Toolkit.ps1` lanza la utilidad sin errores.

---

## Archivos Impactados

| Archivo | Operación |
|---|---|
| [`scripts/Limpiar-ResiduosWinISO.ps1`](file:///c:/OptimizedISO/scripts/Limpiar-ResiduosWinISO.ps1) | MODIFY — Estandarización UTF-8 BOM, parámetros CLI avanzados y modularización |
| [`scripts/romanOS-Toolkit.ps1`](file:///c:/OptimizedISO/scripts/romanOS-Toolkit.ps1) | MODIFY — Integración en menú de herramientas de mantenimiento |
| [`scripts/New-OptimizedWindowsISO-v2.ps1`](file:///c:/OptimizedISO/scripts/New-OptimizedWindowsISO-v2.ps1) | MODIFY — Soporte para parámetro `-CleanRescue` |
| [`scripts/Test-OptimizedISO-v2.ps1`](file:///c:/OptimizedISO/scripts/Test-OptimizedISO-v2.ps1) | MODIFY — Fase de pruebas unitarias para el subsistema de limpieza |
| [`scripts/Invoke-TestSuite.ps1`](file:///c:/OptimizedISO/scripts/Invoke-TestSuite.ps1) | MODIFY — Inclusión de `Limpiar-ResiduosWinISO.ps1` en suite certificada |
| `docs/plans/PLAN-0010-20260824-integrate-iso-cleanup-and-rescue-utility.md` | NEW — Este plan de implementación |
| [`docs/plans/README.md`](file:///c:/OptimizedISO/docs/plans/README.md) | MODIFY — Registro correlativo del PLAN-0010 |
