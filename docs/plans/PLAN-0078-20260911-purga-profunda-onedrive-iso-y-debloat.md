# PLAN-0078: Purga Profunda y Bloqueo Definitivo de OneDrive en Creación de ISO y Debloat

**Fecha:** 2026-09-11  
**Estado:** COMPLETADO  
**Módulos Afectados:** `scripts/Core/Policy-Engine.ps1`, `scripts/Modules/Win11-Debloat-v3-Adaptive.ps1`, `scripts/Builder/New-OptimizedWindowsISO-GUI-Engine.ps1`, `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`, `sources/autounattend.xml`  
**Reglas Aplicables:** Regla 0 (Git y Trazabilidad), Regla 4 (UTF-8 BOM en PS1 / No-BOM en CMD), Regla 5 (Planes en docs/plans), Regla 8 (No auto-run sin confirmación), Regla 9 (SSOT Policy-Engine), Regla 10 (Docs-as-Code)

---

## 1. Contexto y Diagnóstico del Problema

Tras realizar una auditoría forense en un entorno Windows 11 en vivo, se constató que a pesar de existir la política `DisableFileSyncNGSC = 1` inyectada por la ISO:
1. El proceso `OneDrive.Sync.Service.exe` seguía activo en memoria RAM consumiendo CPU y ~21 MB de memoria.
2. Existían 3 tareas programadas activas en el Programador de Tareas (`OneDrive Startup Task`, `OneDrive Standalone Update Task`, `OneDrive Reporting Task`) que reactivaban ejecutables en cada inicio de sesión o descargaban telemetría.
3. El script de debloat (`Win11-Debloat-v3-Adaptive.ps1`) dependía únicamente de `winget uninstall --id Microsoft.OneDrive`, el cual falla con frecuencia ante instalaciones de usuario preexistentes o configuradas con cuentas Microsoft, y **no elimina las tareas programadas residuales**.
4. La ISO actual solo inyectaba una directiva de registro básica sin ejecutar el desinstalador nativo del sistema (`OneDriveSetup.exe /uninstall`) ni eliminar el gancho de autoinstalación que Windows aloja en el perfil de usuario por defecto (`C:\Users\Default\NTUSER.DAT\...\Run\OneDriveSetup`).

La directiva del usuario es categórica: **OneDrive no debe ejecutarse, sincronizarse ni residir en segundo plano bajo ninguna circunstancia, excepto si el usuario decide explícitamente instalarlo por su cuenta**.

---

## 2. Objetivos Técnicos

1. **SSOT en `Policy-Engine.ps1`:** Incorporar directivas canónicas para el bloqueo completo de OneDrive:
   - `DisableFileSyncNGSC = 1` y `DisableFileSync = 1` (bloqueo integral de sincronización).
   - `DisableMeteredNetworkFileSync = 1` y `DisableLibrariesStylePin = 1`.
   - Ocultar la carpeta del panel de navegación del Explorador (`System.IsPinnedToNameSpaceTree = 0` en CLSID `{018D5C66-4533-4307-9B53-224DE2ED1FE6}`).
2. **Purga Nativa en `Win11-Debloat-v3-Adaptive.ps1`:**
   - Crear una rutina especializada de purga profunda (`Invoke-OneDriveDeepPurge`):
     - Detención forzada de procesos (`OneDrive.exe`, `OneDrive.Sync.Service.exe`, `FileCoAuth.exe`).
     - Invocación de desinstaladores nativos oficiales en cascada:
       - `%localappdata%\Microsoft\OneDrive\OneDrive.exe /uninstall /silent`
       - `%SystemRoot%\System32\OneDriveSetup.exe /uninstall /silent`
       - `%SystemRoot%\SysWOW64\OneDriveSetup.exe /uninstall /silent`
       - `winget uninstall --id Microsoft.OneDrive --silent ...`
     - Eliminación de todas las tareas programadas de OneDrive (`Unregister-ScheduledTask`).
     - Eliminación de entradas en claves `Run` (`HKCU` y `HKLM`).
     - Eliminación del gancho en el perfil `Default User` para evitar que usuarios futuros lo hereden.
     - Aplicación de políticas GPO y eliminación del icono en el Explorador.
3. **Inyección en la Creación de la ISO (`SetupComplete.cmd` y `autounattend.xml`):**
   - En `SetupComplete.cmd`: Ejecutar la desinstalación silenciosa nativa y limpieza de tareas antes del primer inicio de sesión del usuario.
   - En `autounattend.xml`: Suprimir la clave `OneDriveSetup` en el perfil predeterminado (`HKU\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Run`) y aplicar directivas GPO de bloqueo en fase `specialize`.

---

## 3. Plan de Cambios Detallado

### Módulo 1: `scripts/Core/Policy-Engine.ps1` (SSOT)
- Registrar las políticas de bloqueo integral de OneDrive y desvinculación del Explorador bajo una categoría canónica en `$script:RomanOSPolicies`.

### Módulo 2: `scripts/Modules/Win11-Debloat-v3-Adaptive.ps1`
- Reemplazar la simple llamada a `winget` por la función `Invoke-OneDriveDeepPurge` con:
  - Cierre forzado de procesos.
  - Desinstalación nativa (/uninstall).
  - Purgado de tareas programadas (`OneDrive*`).
  - Limpieza de registro `Run` en usuario actual y en máquina local.
  - Ocultación del icono del Explorador.

### Módulo 3: Motores de ISO (`New-OptimizedWindowsISO-GUI-Engine.ps1` y `v2.ps1`)
- Actualizar el bloque de generación de `SetupComplete.cmd`: si `BlockOneDrive` está habilitado (por defecto), incluir comandos cmd/PowerShell para ejecutar `OneDriveSetup.exe /uninstall /silent`, purgar tareas y eliminar el registro de autoinstalación en `Default User`.
- Actualizar `autounattend.xml` para limpiar `Run\OneDriveSetup` de `HKU\.DEFAULT`.

---

## 4. Plan de Verificación

1. **Validación de Sintaxis y Codificación:**
   - Verificar UTF-8 BOM (`0xEF, 0xBB, 0xBF`) en todos los `.ps1`.
   - Comprobación AST en frío con `powershell.exe`: 0 errores de sintaxis.
2. **Prueba en Vivo:**
   - Ejecutar la rutina de purga profunda en una prueba unitaria o simulación controlada y constatar que:
     - 0 procesos activos.
     - 0 tareas programadas en Programador de Tareas.
     - Directivas GPO activas.
3. **Batería de Pruebas Global:**
   - Ejecutar `Invoke-TestSuite.ps1` (44/44 scripts aprobados).
