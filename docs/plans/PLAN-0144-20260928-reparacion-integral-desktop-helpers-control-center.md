# PLAN-0144: Reparación Integral de Desktop Helpers, Conmutadores del Control Center e Inyección en ISO

**Fecha:** 2026-09-28  
**Estado:** COMPLETADO  
**Tipo:** Bugfix Crítico / Arquitectura / Resiliencia Operativa  
**Subsistemas Afectados:** `scripts/Desktop-Helpers/`, `scripts/Core/Policy-Engine.ps1`, `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`, `scripts/Testing/Test-OptimizedISO-v2.ps1`.

---

## 1. Diagnóstico Forense y Causa Raíz

Una auditoría en frío y pruebas de ejecución empíricas revelaron una cadena de fallas arquitectónicas que convertían la suite de "Desktop Helpers" y sus botones correspondientes en `romanOS-ControlCenter.ps1` en cascarones inertes y placebos visuales:

1. **Inyección Incompleta en ISO ($OEM$ Public Desktop):**
   - En `New-OptimizedWindowsISO-v2.ps1` (línea 5469), solo se copiaban los archivos `*.cmd` a `C:\Users\Public\Desktop\romanOS Helpers`.
   - Los archivos de lógica `.ps1` no eran inyectados en la carpeta del escritorio.
   - Como los archivos `.cmd` delegan a `%~dp0Toggle-*.ps1`, al hacer doble clic en el escritorio instalado, PowerShell colapsa con error de archivo no encontrado y la ventana se cierra de inmediato sin ejecutar ninguna acción.

2. **Rutas Ciegas en `romanOS-ControlCenter.ps1`:**
   - La función `Resolve-ToolScript` busca exclusivamente en `$script:searchDirs`.
   - Ni `scripts\Desktop-Helpers` (repositorio) ni `C:\Windows\Setup\Scripts\DesktopHelpers` (sistema instalado) estaban presentes en `$script:searchDirs`.
   - Al pulsar cualquier botón de helper en la UI, `$tool` devolvía `$null`, y la guardia `if ($tool)` devoraba el clic en silencio (violación estricta de la Regla 13 / CWE-390).

3. **Lectura Circular Falsa en el Registro (Placebo State):**
   - `Get-RomanOSDesktopHelperState` en `Policy-Engine.ps1` leía ciegamente `HKLM:\SOFTWARE\RomanOS\DesktopHelpers\<Name>\State`.
   - Si existía un valor en esa clave, devolvía ese valor sin verificar jamás si los servicios o componentes de Windows estaban realmente activos o detenidos.

4. **Ausencia de Lógica Real de Conmutación para Defender:**
   - `Set-RomanOSDesktopHelperState` intentaba parar Defender mediante `sc.exe stop WinDefend 2>&1 | Out-Null`.
   - En Windows 11, Defender corre como Protected Process Light (PPL / ELAM) con Tamper Protection; `sc.exe` falla con Acceso Denegado (5) o error 1052. La excepción era suprimida con `Out-Null`, no existía código para `Set-MpPreference`, y el script procedía a escribir falsamente `State = 0` en el registro.
   - La GUI leía el registro falso y pintaba el botón en marrón como "Defender: Pausado", mientras la protección en tiempo real seguía 100% activa.

5. **Fragilidad de los Lanzadores `.cmd`:**
   - No contaban con rutas de búsqueda de contingencia (fallback a `%SystemRoot%\Setup\Scripts\DesktopHelpers\` o ruta de repo) ni emitían advertencias legibles al usuario en caso de ausencia del script subordinado.

---

## 2. Objetivos de Ingeniería y Solución Arquitectónica

### Fase 1: Motor Canónico SSOT (`Policy-Engine.ps1`)
- **Consulta de Estado en Vivo (Live State):**
  - Defender: Consultar `Get-MpComputerStatus` (`RealTimeProtectionEnabled`, `AntivirusEnabled`) o estado del servicio `WinDefend`.
  - Windows Update: Consultar estado de `wuauserv` y directivas `AU\NoAutoUpdate`.
  - Bluetooth: Consultar estado de `bthserv`.
  - Printing: Consultar estado de `Spooler`.
  - File Sharing: Consultar estado de `LanmanServer` y reglas de firewall.
  - VBS/HVCI: Consultar `Win32_DeviceGuard` y valor BCD / DeviceGuard registry.
  - Recall: Consultar directivas de `WindowsAI`.
- **Conmutación Real y Detección de Tamper Protection:**
  - Defender: Utilizar `Set-MpPreference` con verificación de `IsTamperProtected`. Si Tamper Protection está activo, alertar visiblemente al usuario en lugar de registrar un falso éxito.
  - Windows Update: Configurar directivas GPO (`NoAutoUpdate`) y servicios `wuauserv`/`UsoSvc`.
  - File Sharing: Sincronizar servicios y reglas de firewall de Windows.
  - VBS/HVCI: Notificar explícitamente que se requiere un reinicio del sistema (reboot pending).

### Fase 2: Robustecimiento de Lanzadores `.cmd` y `.ps1` (`scripts/Desktop-Helpers/`)
- Modificar los `.cmd` para que tengan búsqueda en cascada:
  1. `%~dp0<ScriptName>.ps1` (carpeta local).
  2. `%SystemRoot%\Setup\Scripts\DesktopHelpers\<ScriptName>.ps1` (instalación ISO).
  3. `C:\OptimizedISO\scripts\Desktop-Helpers\<ScriptName>.ps1` (entorno de desarrollo).
- Si no se encuentra el script, pausar y mostrar un mensaje de diagnóstico claro.
- Modificar los `.ps1` para resolver `Desktop-Helpers.ps1` de forma resiliente.

### Fase 3: Paridad en `romanOS-ControlCenter.ps1`
- Agregar `Desktop-Helpers` y `DesktopHelpers` a `$script:searchDirs`.
- Agregar notificación Fail-Visible si `Resolve-ToolScript` no encuentra el script subordinado.
- Refrescar automáticamente la UI tras la ejecución de las tareas de conmutación.

### Fase 4: Inyección Completa en Builder (`New-OptimizedWindowsISO-v2.ps1`)
- Inyectar la suite completa (`*.cmd`, `*.ps1`, `Desktop-Helpers.ps1`) en `$desktopHelpersTarget` (`C:\Users\Public\Desktop\romanOS Helpers`).
- Garantizar que la suite en `$OEM$\$$\Setup\Scripts\DesktopHelpers` cuente con todos los archivos necesarios.

### Fase 5: Validación y Certificación en Test Harness
- Implementar la suite `FASE 2Z` en `scripts/Testing/Test-OptimizedISO-v2.ps1`.
- Ejecutar pruebas en frío contra Windows PowerShell 5.1 (`powershell.exe`) y certificar 100% pass rate.

---

## 3. Matriz de Componentes y Estado

| Componente | Archivo | Acción | Estado |
|---|---|---|---|
| SSOT Helpers State & Logic | `scripts/Core/Policy-Engine.ps1` | Refactorizar `Get/Set-RomanOSDesktopHelperState` | COMPLETADO |
| Lanzadores Batch | `scripts/Desktop-Helpers/*.cmd` | Implementar cascada de rutas y fail-visible | COMPLETADO |
| Conmutadores PS1 | `scripts/Desktop-Helpers/*.ps1` | Robustecer búsqueda de módulos subordinados | COMPLETADO |
| Control Center GUI | `scripts/GUI/romanOS-ControlCenter.ps1` | Registrar searchDirs y fail-visible en botones | COMPLETADO |
| ISO Builder Injection | `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` | Inyección íntegra (*.cmd + *.ps1) en Public Desktop | COMPLETADO |
| Test Harness | `scripts/Testing/Test-OptimizedISO-v2.ps1` | Agregar suite FASE 2Z y certificar 100% | COMPLETADO |

---

## 4. Certificación Empírica
- **Test Harness:** `scripts/Testing/Test-OptimizedISO-v2.ps1` ejecutado en frío en Windows PowerShell 5.1 (`powershell.exe`).
- **Métricas:** 651/651 pruebas superadas (100.0% PASS, 0 FAIL, 0 SKIP).
- **Reporte:** `Log/TestHarness_20260928_232859.md`.

