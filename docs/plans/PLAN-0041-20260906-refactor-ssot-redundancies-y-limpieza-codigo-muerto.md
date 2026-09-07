# PLAN-0041: Refactorización SSOT de Redundancias y Limpieza de Código Muerto

**Fecha:** 2026-09-06  
**Autor:** romanOS / OptimizedISO Project Team  
**Estado:** COMPLETADO  
**Rama:** `feature/offline-ui-tweaks`  

---

Refactorización basada en el análisis real y empírico del repositorio, con el objetivo de erradicar código no utilizado (funciones con 0 llamadas) y consolidar las políticas SSOT eliminando escrituras directas al registro en scripts consumidores (como el Builder).

## User Review Required

> [!IMPORTANT]
> **Eliminación de Código Muerto**:
> Se eliminará la función `Out-LogWarn` en `Add-OptimizedContextMenus.ps1` ya que la auditoría empírica (`functions_audit.csv`) determinó que su `TotalCalls` es exactamente 0.
> *Nota: No asumo que otras funciones de uso bajo sean inútiles; el análisis confirma matemáticamente que solo `Out-LogWarn` no es invocada interna ni externamente en todo el repositorio.*

> [!CAUTION]
> **Refactorización SSOT en el Builder**:
> En `New-OptimizedWindowsISO-v2.ps1`, se detectaron más de 35 instancias de escrituras redundantes directas al registro (ej. `reg add HKLM\...\OOBE /v BypassNRO`, directivas de modo oscuro, `DisablePrivacyExperience`, etc.) que ya están gobernadas por `Policy-Engine.ps1`.
> Esto viola la regla de Fuente Única de Verdad (SSOT). Se refactorizarán estas líneas para que dependan exclusivamente de `Export-RomanOSUnattendCommands` o consulten dinámicamente las políticas del motor, evitando así la duplicidad.

## Open Questions

Ninguna. El análisis arrojó métricas concretas y la limpieza es segura y necesaria para el estricto cumplimiento arquitectónico (Reglas 9 y 10).

## Proposed Changes

### 1. Limpieza de Código Muerto

#### [MODIFY] [Add-OptimizedContextMenus.ps1](file:///C:/OptimizedISO/scripts/Modules/Add-OptimizedContextMenus.ps1)
- Eliminar de raíz la función huérfana `Out-LogWarn`.

### 2. Refactorización SSOT en el Builder

#### [MODIFY] [New-OptimizedWindowsISO-v2.ps1](file:///C:/OptimizedISO/scripts/Builder/New-OptimizedWindowsISO-v2.ps1)
- **Generación de `autounattend.xml` (Fase Offline)**:
  - Eliminar los bloques `<Path>` y `<CommandLine>` hardcodeados referentes a: `DisablePrivacyExperience`, `DisableWindowsConsumerFeatures`, `DisableSoftLanding`, `BypassNRO`, `AllowTelemetry`, Políticas de Windows Update y CloudContent.
  - Asegurar que estas políticas se inyectan a través del bloque `<RunSynchronousCommand>` delegado a `Export-RomanOSUnattendCommands -Target "Offline"`.
- **Plantilla `SetupComplete.cmd` (Fase Online)**:
  - Eliminar los comandos `reg add` directos referentes a: Modo Oscuro (`AppsUseLightTheme`), Políticas NTFS (`NtfsDisable8dot3NameCreation`, `LongPathsEnabled`), Prioridad Win32 (`Win32PrioritySeparation`), etc.
  - Delegar la ejecución de estas políticas en tiempo real al `Policy-Engine.ps1` ya inyectado en `$OEM$`.

## Verification Plan

### Automated Tests
- Ejecutar la suite completa para asegurar que no hay regresiones sintácticas ni fallos en la estructura del Builder:
  ```powershell
  & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'c:\OptimizedISO\scripts\Testing\Test-OptimizedISO-v2.ps1' }"
  ```

### Manual Verification
- Re-ejecutar `audit_ssot_redundancies.ps1` para validar con métricas comprobables que el conteo de redundancias baja a **0** en el Builder.
- Re-ejecutar `audit_dead_code.ps1` para comprobar que la matriz de funciones huérfanas queda totalmente saneada.
