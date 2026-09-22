# PLAN-0105: Auditoría Integral de Paridad Funcional romanOS Toolkit vs romanOS Control Center

**Número de Plan:** PLAN-0105  
**Fecha:** 2026-09-22  
**Estado:** EN PROGRESO  
**Módulos Impactados:** `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/Modules/romanOS-Toolkit.ps1`, `docs/plans/README.md`  

---

## 1. Justificación y Contexto

Durante la inspección en vivo de `romanOS Control Center` (`scripts/GUI/romanOS-ControlCenter.ps1`), se detectó que al presionar el botón **"Lanzar Debloat Adaptativo (Win11)"**, el proceso muestra únicamente la telemetría inicial de hardware y salud, quedándose congelado en segundo plano sin ejecutar la desinstalación ni aplicar optimizaciones.

### Causa Raíz Técnica
1. El motor de ejecución asíncrona desacoplada del Control Center (`Start-ControlCenterTask`) lanza subprocesos mediante:
   ```powershell
   $pinfo.FileName = "cmd.exe"
   $pinfo.Arguments = "/c powershell.exe $cmdArgs 2>&1"
   $pinfo.CreateNoWindow = $true
   $pinfo.RedirectStandardOutput = $true
   ```
   **No existe redirección de `StandardInput` ni consola interactiva.**
2. `Win11-Debloat-v3-Adaptive.ps1` es un script interactivo por defecto. En la línea 979 ejecuta:
   ```powershell
   Read-Host "  Presiona ENTER para continuar con los menus de seleccion"
   ```
3. Al carecer de terminal interactiva o stream de entrada, `Read-Host` bloquea indefinidamente el hilo del subproceso en segundo plano. El debloat nunca se inicia.
4. Esta evidencia requirió auditar el **100% de las herramientas** de `romanOS-Toolkit.ps1` para determinar:
   - Qué acciones existentes en el Control Center sufren bloqueos idénticos por solicitudes de interacción (`Read-Host` / `pause`).
   - Qué módulos y capacidades funcionales del Toolkit están ausentes en la GUI y deben ser incorporados para alcanzar paridad 1:1 efectiva.

---

## 2. Matriz Exhaustiva de Auditoría Forense (Toolkit vs Control Center)

A continuación se detalla el análisis empírico de las 23 áreas funcionales del ecosistema:

| ID | Módulo / Herramienta | Script Subyacente | Estado en Toolkit CLI | Estado en Control Center GUI | Diagnóstico Técnico y Nivel de Riesgo | Solución de Ingeniería Requerida |
|---|---|---|---|---|---|---|
| **01** | **Debloat Adaptativo Win11** | `Win11-Debloat-v3-Adaptive.ps1` | Funcional (Interactivo) | Presente (`btnRunDebloat`) | 🚨 **CRÍTICO: BLOQUEADO.** Se congela en L979 en `Read-Host` sin `-Unattended`. | Invocar con `-Unattended` para streaming directo en Consola en Vivo, y ofrecer botón de terminal externa interactiva. |
| **02** | **Limpieza de DriverStore** | `Clean-DriverStore.ps1` | Funcional (Interactivo) | Presente (`btnCleanDriverStore`) | 🚨 **CRÍTICO: BLOQUEADO.** L151 ejecuta `Read-Host "¿Desea proceder...?"`. Sin `-Force` se bloquea en background. | Añadir flag `-Force` a la invocación en `romanOS-ControlCenter.ps1`. |
| **03** | **Migración de Usuario** | `Migrar-Usuario-W11.ps1` | Funcional (Interactivo) | Presente (`btnMigrateUser`) | 🚨 **CRÍTICO: BLOQUEADO.** Asistente 100% interactivo (pide contraseñas y nombres). No puede correr en `Start-ControlCenterTask`. | Desacoplar a ventana de terminal externa visible (`Start-Process powershell.exe -ArgumentList "... -File $tool"`). |
| **04** | **Poda de Memoria RAM** | `Optimize-ProcessMemory.ps1` | Funcional | Presente (`btnQuickTrim`) | ✅ **OK.** Ejecución limpia en background. | Mantener. |
| **05** | **Optimización de Red & Nagle** | `Win11-Network-Diagnostics-Optimizer.ps1` | Funcional | ⚠️ **PARCIAL.** Solo benchmark DNS y DNS estático inline en la UI. | No existe botón para ejecutar la optimización de latencia TCP / Nagle o diagnóstico integral de red. | Agregar botón en pestaña "Red & Latencia" que invoque el script con `-NagleOnly -Unattended`. |
| **06** | **Mantenimiento & WinSxS** | `Invoke-WindowsMaintenance.ps1` | Funcional | Presente (`btnRunMaintenanceBatch`) | ✅ **OK.** Pasa flags específicos y `-Unattended`. | Mantener. |
| **07** | **Diagnóstico Post-Instalación** | `PostInstall-Diagnostics.ps1` | Funcional | ⚠️ **PARCIAL.** Hay botón para ABRIR HTML, pero no para GENERARLO. | Si el reporte HTML no existe en el disco, `btnOpenHtmlDashboards` falla silenciosamente o advierte ausencia. | Agregar botón en la UI: "Generar Informe Post-Instalación (HTML)" ejecutando `-DesktopOutput`. |
| **08** | **Huella en Reposo (Footprint)** | `Audit-FreshInstallFootprint.ps1` | Funcional | ❌ **FALTA EN GUI.** | Módulo de telemetría de memoria, procesos PLM y políticas no expuesto en la interfaz gráfica. | Agregar botón en pestaña "Dashboard" o "Mantenimiento": "Auditar Huella en Reposo (Footprint)". |
| **09** | **Hardening de Seguridad** | `Invoke-WindowsSecurityHardening.ps1` | Funcional | ⚠️ **PARCIAL.** Solo tiene `btnSecurityAudit` (`-ShowReport`). | Falta botón para APLICAR el hardening gaming-safe (LSA, ASR, bloqueo SMBv1/WPBT). | Agregar botón en pestaña "Seguridad": "Aplicar Hardening Seguro (Gaming-Safe)". |
| **10** | **Menús Contextuales** | `Add-OptimizedContextMenus.ps1` | Funcional (5 opciones) | ❌ **FALTA EN GUI.** | La suite de menús contextuales Gamer/PowerUser y el menú clásico 1-clic están ausentes de la GUI. | Agregar sección en "Drivers & Herramientas" o "Gaming" para alternar Menú Clásico 1-clic y Suite Completa. |
| **11** | **Drivers Críticos (VMD/VirtIO)** | `Get-CriticalDrivers.ps1` | Funcional | ❌ **FALTA EN GUI.** | Descarga automatizada de drivers de almacenamiento masivo ausente en la interfaz gráfica. | Agregar botón en "Drivers & Herramientas": "Descargar Drivers Críticos (Intel VMD / VirtIO)". |
| **12** | **Descarga de Windows Updates** | `Get-WindowsUpdates.ps1` | Funcional | ❌ **FALTA EN GUI.** | Descargador oficial de parches MSU/CAB para slipstream no disponible en el Control Center. | Agregar botón/asistente en "Drivers & Herramientas" para descargar actualizaciones acumulativas. |
| **13** | **Restauración de Servicios** | Nativo (WlanSvc, bthserv, etc.) | Funcional (QuickActions #8) | ❌ **FALTA EN GUI.** | No hay botón para reactivar servicios estándar en caso de haber aplicado perfiles agresivos. | Agregar botón rápido: "Restaurar Servicios Básicos (Wi-Fi, Bluetooth, Impresión)". |
| **14** | **Optimizador de Navegadores** | `Optimize-WebBrowsers.ps1` | Funcional | Presente (5 botones) | ✅ **OK.** Soporte completo para Edge, Chrome, Brave, Firefox y All. | Mantener. |
| **15** | **Profiler Latencia DPC/ISR** | `Trace-SystemLatency.ps1` | Funcional | Presente (`btnRunLatencyProfiler`) | ✅ **OK.** Ejecuta con `-DurationSeconds 5`. | Mantener. |
| **16** | **Gaming & Apps (VRAM/Electron)** | `Optimize-GamingAndApps.ps1` | Funcional | Presente (`btnRunGamingApps`) | ✅ **OK.** Pasa `-Unattended`. | Mantener. |
| **17** | **Conmutador Game / Dev Mode** | `Switch-GameDevMode.ps1` | Funcional | Presente (3 cards de modo) | ✅ **OK.** Modos Agresivo, Ligero y Dev operativos. | Mantener. |
| **18** | **Thermal & Energy Profiler** | `Monitor-ThermalEnergy.ps1` | Funcional | Presente (3 botones) | ✅ **OK.** Status, Monitor en vivo y Calibración energética. | Mantener. |
| **19** | **Afinidad PCIe & IRQ Steering** | `Optimize-InterruptAffinity.ps1` | Funcional | Presente (4 botones) | ✅ **OK.** Status, Optimize, Reset e integración en Dashboard. | Mantener. |
| **20** | **Snapshot & Rollback Engine** | `Manage-SystemSnapshots.ps1` | Funcional | Presente (Selector + 4 botones) | ✅ **OK.** Crear, VSS, Restaurar y Listar operativos. | Mantener. |
| **21** | **Service Drift Watchdog** | `Watchdog-ServiceDrift.ps1` | Funcional | Presente (3 botones) | ✅ **OK.** Audit, Remediate e InstallTask operativos. | Mantener. |
| **22** | **Live Sandbox Environment** | `Invoke-LiveSandbox.ps1` | Funcional | Presente (Presets + 3 botones) | ✅ **OK.** Status, Launch y GenerateConfig operativos. | Mantener. |
| **23** | **App & AI Runtimes Manager** | `Deploy-AppProfiles.ps1` | Funcional | Presente (Perfiles + 3 botones) | ✅ **OK.** Despliegue desatendido, Simulación e Instalación de runtimes. | Mantener. |

---

## 3. Plan de Acción y Correcciones de Ingeniería

Para subsanar las deficiencias detectadas y lograr una paridad del 100% funcional y robusta, se establecen 3 fases de implementación:

### Fase 1: Corrección Inmediata de los 3 Bloqueos Críticos
1. **`btnRunDebloat`:**
   - Actualizar el comando para pasar `-Unattended`:
     ```powershell
     Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Unattended" -TaskTitle "Debloat Adaptativo de Windows 11"
     ```
   - Añadir botón secundario visible `btnRunDebloatInteractive` ("Asistente Interactivo en Terminal Externa") que ejecute `Start-Process powershell.exe` para usuarios que deseen seleccionar componentes manualmente mediante `Out-GridView`.
2. **`btnCleanDriverStore`:**
   - Añadir el parámetro `-Force` para evitar la detención en el prompt `Read-Host` de la línea 151:
     ```powershell
     Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Force" -TaskTitle "Limpieza de DriverStore"
     ```
3. **`btnMigrateUser`:**
   - Desacoplar de `Start-ControlCenterTask` e invocar en ventana visible nativa:
     ```powershell
     Start-Process powershell.exe -ArgumentList "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`""
     ```

### Fase 2: Integración de Acciones Faltantes en la UI (XAML + Handlers)
1. **Pestaña "Red & Latencia":**
   - Incorporar botón para optimización de latencia TCP y desactivación de Nagle:
     `btnOptimizeNetwork`: invoca `Win11-Network-Diagnostics-Optimizer.ps1 -NagleOnly -Unattended`.
2. **Pestaña "Seguridad & Navegadores":**
   - Incorporar botón para aplicar hardening seguro gaming-safe:
     `btnApplySafeHardening`: invoca `Invoke-WindowsSecurityHardening.ps1 -ApplySafeHardening -NonInteractive`.
   - Incorporar botón para generar el reporte de diagnóstico post-instalación:
     `btnGenerateDiagReport`: invoca `PostInstall-Diagnostics.ps1 -DesktopOutput`.
3. **Pestaña "Drivers & Herramientas":**
   - Incorporar bloque de Menús Contextuales:
     - Botón "Habilitar Menú Clásico 1-Clic" (`Add-OptimizedContextMenus.ps1 -EnableClassicMenu -RestartExplorer`).
     - Botón "Aplicar Suite Completa Gamer & PowerUser" (`Add-OptimizedContextMenus.ps1 -Apply -RestartExplorer`).
     - Botón "Restaurar Menú Moderno Win11" (`Add-OptimizedContextMenus.ps1 -RestoreModernMenu -RestartExplorer`).
   - Incorporar botón para descarga de drivers críticos Intel VMD / VirtIO (`Get-CriticalDrivers.ps1`).
4. **Pestaña "Dashboard" / "Mantenimiento":**
   - Incorporar botón para auditoría forense de huella en reposo (`Audit-FreshInstallFootprint.ps1`).
   - Incorporar botón para restaurar servicios esenciales (Wi-Fi, Bluetooth, Spooler).

### Fase 3: Validación y Certificación en Windows PowerShell 5.1
- Inspección estricta de codificación UTF-8 con BOM (`0xEF, 0xBB, 0xBF`).
- Ejecución en frío con el motor de destino:
  ```powershell
  & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'scripts\GUI\romanOS-ControlCenter.ps1' -WhatIf }"
  ```
- Verificación de ausencia de `ParserError` o bloqueos residuales de hilo STA.

---

## 4. Estado de Verificación

- [x] Auditoría comparativa del 100% de las herramientas realizada y cuantificada.
- [x] 3 bloqueos críticos aislados a nivel de línea de código (`Read-Host` y falta de flags).
- [x] Mapeo de módulos faltantes e inconsistencias de UX documentado.
- [ ] Implementación de cambios en `romanOS-ControlCenter.ps1` (Pendiente de aprobación del usuario).
- [ ] Pruebas empíricas de ejecución desatendida y de ventanas interactivas.
