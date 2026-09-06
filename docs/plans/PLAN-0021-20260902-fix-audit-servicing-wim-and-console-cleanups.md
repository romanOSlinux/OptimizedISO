# PLAN-0021: Corrección de Incompatibilidades en WIMs Vírgenes, Bloqueo UCPD, Fugas de Consola y Nomenclaturas Oficiales

**Fecha:** 2026-09-02  
**Estado:** COMPLETADO  
**Rama:** `feature/offline-ui-tweaks`  
**Script afectado:** [`New-OptimizedWindowsISO-v2.ps1`](../../scripts/New-OptimizedWindowsISO-v2.ps1)  
**Auditoría previa:** [`docs/auditorias/AUDITORIA_NEW_OPTIMIZED_ISO_V2.md`](../auditorias/AUDITORIA_NEW_OPTIMIZED_ISO_V2.md)  

Implementación de las correcciones técnicas identificadas en la auditoría integral (`docs/auditorias/AUDITORIA_NEW_OPTIMIZED_ISO_V2.md`) sobre [`scripts/New-OptimizedWindowsISO-v2.ps1`](file:///c:/OptimizedISO/scripts/New-OptimizedWindowsISO-v2.ps1), garantizando una ejecución limpia, sin advertencias estériles y 100% compatible con imágenes WIM vírgenes oficiales de Microsoft.

## User Review Required

> [!IMPORTANT]
> **EliminaciÃ³n de la llamada offline DISM `/Set-ReservedStorageState`:**
> DISM offline devuelve cÃ³digo 50 (`ERROR_NOT_SUPPORTED`) en el 100% de los `install.wim` vÃ­rgenes de medios oficiales. La desactivaciÃ³n de Reserved Storage se trasladarÃ¡ formalmente a:
> 1. La directiva nativa en registro offline `ReserveManager\ShippedWithReserves = 0`.
> 2. El comando `DISM /Online /Set-ReservedStorageState /State:Disabled` en `SetupComplete.cmd` (donde sÃ­ es 100% vÃ¡lido y soportado).

> [!IMPORTANT]
> **RemociÃ³n de `TaskbarDa` de `NTUSER.DAT`:**
> Dado que el driver en kernel **UCPD** de Windows 11 bloquea las escrituras directas sobre este valor provocando `[WARN] Error aplicando tweak`, y considerando que `autounattend.xml` ya suprime los Widgets a nivel de mÃ¡quina con la directiva oficial GPO `AllowWidgets = 0`, se retira `TaskbarDa` para eliminar advertencias de build.

## Proposed Changes

### Generador de ISO: `scripts/New-OptimizedWindowsISO-v2.ps1`

#### [MODIFY] [`New-OptimizedWindowsISO-v2.ps1`](file:///c:/OptimizedISO/scripts/New-OptimizedWindowsISO-v2.ps1)

1. **Encapsulamiento Silencioso y Guardias en `Invoke-RegUnloadHive` (L3262â€“L3295):**
   - Comprobar con `reg.exe query $HiveName` si la colmena existe antes de invocar la descarga. Si no existe, retornar `$true` inmediatamente sin intentar descargar.
   - Redirigir stdout y stderr (`2>&1 | Out-Null`) al ejecutar `reg.exe unload` para que las descargas preventivas no filtren `ERROR: El parÃ¡metro no es correcto` ni `La operaciÃ³n se completÃ³ correctamente`.

2. **Silenciamiento de `reg.exe load` en Hardening y Tweaks (L3319â€“L3324 y L6320â€“L6336):**
   - Capturar la salida de `reg.exe load` en lugar de dejar que escriba `La operaciÃ³n se completÃ³ correctamente` directamente a la consola.

3. **InclusiÃ³n de `ReserveManager` en Hardening Offline y SupresiÃ³n de DISM Exit 50 (L3348â€“L3352 y L6264â€“L6291):**
   - AÃ±adir la clave oficial `ShippedWithReserves = 0` en `HKLM\_ROMANOS_SW\Microsoft\Windows\CurrentVersion\ReserveManager`.
   - Retirar la invocaciÃ³n offline estÃ©ril de `dism.exe /Image:$WimMountDir /Set-ReservedStorageState /State:Disabled` que siempre devuelve exit code 50.
   - Mantener el registro de auditorÃ­a documentando que se aplica vÃ­a registro nativo offline y online en `SetupComplete.cmd`.

4. **CorrecciÃ³n de Nomenclatura Copilot en `SetupComplete.cmd` (L4371):**
   - Reemplazar `"HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows AI"` por `"HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"` (sin espacio), cumpliendo con el Policy CSP oficial de Microsoft.

5. **CorrecciÃ³n Textual del MenÃº de Perfiles (L5280â€“L5286):**
   - Actualizar el banner interactivo para que el Perfil 3 diga *"Laptop / PortÃ¡til / VM: Equilibrado, Wi-Fi, Bluetooth y baterÃ­a"* en vez de la descripciÃ³n obsoleta de "Hardcore".

6. **DepuraciÃ³n de Redundancias y Bloqueo UCPD en Tweaks de `NTUSER.DAT` (L6340â€“L6508):**
   - Remover el objeto `TaskbarDa` del array `$tweaks` (evita bloqueo de kernel UCPD; cubierto por `AllowWidgets = 0` en unattend).
   - Remover la entrada duplicada `ApplyDarkMode` en `RunOnce` (ya inyectado directamente en `Themes\Personalize`).
   - Remover la clave obsoleta `BingSearchEnabled` (cubierto por `DisableWebSearch = 1` en unattend).

---

### DocumentaciÃ³n del Proyecto

#### [NEW] [`docs/plans/PLAN-0021-20260902-fix-audit-servicing-wim-and-console-cleanups.md`](file:///c:/OptimizedISO/docs/plans/PLAN-0021-20260902-fix-audit-servicing-wim-and-console-cleanups.md)
- Registro formal del plan en la carpeta de trazabilidad `docs/plans/`.

#### [MODIFY] [`docs/plans/README.md`](file:///c:/OptimizedISO/docs/plans/README.md)
- Registrar PLAN-0021 en la tabla de planes del repositorio con estado `PENDIENTE`.

---

## Verification Plan

### Automated Tests
1. **ValidaciÃ³n de Sintaxis y Parser en Windows PowerShell 5.1 (Regla 4, AGENTS.md):**
   ```powershell
   & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { [System.Management.Automation.Language.Parser]::ParseFile('c:\OptimizedISO\scripts\New-OptimizedWindowsISO-v2.ps1', [ref]`$null, [ref]`$null) | Out-Null; Write-Host 'Sintaxis PS 5.1: OK' }"
   ```

2. **EjecuciÃ³n de la Suite de Pruebas Unitaria (`Invoke-TestSuite.ps1`):**
   ```powershell
   & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -File "c:\OptimizedISO\scripts\Invoke-TestSuite.ps1"
   ```

3. **VerificaciÃ³n de CodificaciÃ³n UTF-8 con BOM (Regla 4):**
   ```powershell
   $bytes = [System.IO.File]::ReadAllBytes("c:\OptimizedISO\scripts\New-OptimizedWindowsISO-v2.ps1")
   if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { "UTF-8 BOM OK" } else { throw "Falta BOM" }
   ```

### Manual Verification
- Comprobar que en la simulaciÃ³n de montaje y desmontaje preventivo no se impriman mensajes `ERROR: El parÃ¡metro no es correcto` ni `La operaciÃ³n se completÃ³ correctamente`.
- Confirmar que la compilaciÃ³n offline ya no emita advertencias por DISM exit code 50 ni por fallo en `TaskbarDa`.
