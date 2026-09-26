# PLAN-0114: Fase 1 - Inspiración AtlasOS / ReviOS: Suite de Reversibilidad "Desktop Helpers", Latencia Gaming Quirúrgica e Integración en Cascada

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0114 |
| **Fecha** | 2026-09-25 |
| **Componentes** | `scripts/Core/Policy-Engine.ps1`, `scripts/Modules/Desktop-Helpers.ps1`, `$OEM$\$$\Setup\Scripts\DesktopHelpers\`, `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`, `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/GUI/romanOS-Studio.ps1`, `scripts/Testing/Test-DesktopHelpers.ps1`, `scripts/Modules/Optimize-GamingAndApps.ps1` |
| **Estado** | `PENDIENTE` |
| **Prioridad** | Alta (UX de Reversibilidad para Usuario Final, Estabilidad Anti-Cheat y Reducción de Latencia de Kernel) |
| **Reglas Relevantes** | Regla 0 (Git), Regla 4 (Windows PowerShell 5.1 / UTF-8 BOM), Regla 5 (Planes), Regla 7 (Aviso de Pruebas), Regla 8 (No Auto-Run / Espera de Confirmación), Regla 9 (SSOT Policy-Engine), Regla 10 (Mantenimiento en Cascada), Regla 11 (Ingeniero Autónomo), Regla 12 (Log Forensics), Regla 13 (No Silent Failures) |

---

## 1. Justificación Técnica y Hallazgos de los Repositorios Oficiales

Tras clonar y auditar en profundidad los repositorios fuente de **AtlasOS** (`Atlas-OS/Atlas`) y **ReviOS** (`meetrevision/playbook` y `meetrevision/revision-tool`), se extrajeron los siguientes fundamentos empíricos de ingeniería que gobernarán esta implementación:

### A. Lecciones de Diseño de AtlasOS: Suite "Desktop Helpers"
1. **Acceso Inmediato sin Fricción:** AtlasOS coloca una carpeta en el escritorio (`Atlas` / `AtlasDesktop`) con subcarpetas limpias y lanzadores `.cmd` que ejecutan conmutadores modales (`Toggle Windows Updates.cmd`, `Toggle Defender.cmd`, `Bluetooth`, `Printing`, `VBS/Core Isolation`).
2. **Persistencia y Trazabilidad de Estado en Registro:** Cada helper registra en `HKLM\SOFTWARE\...\Services\<Nombre>` su estado (`state`: 0=Disabled, 1=Enabled) y la ruta del script ejecutado.
3. **Manejo de Advertencias y Elevación:** Antes de ejecutar acciones de parada de servicios, presentan advertencias modales breves para confirmar la intención del usuario.

### B. Lecciones Críticas de Estabilidad y Anti-Cheat de ReviOS (`revert.yml`)
1. **Compatibilidad con Anti-Cheat (Vanguard, EasyAntiCheat, THE FINALS):**
   * **Hallazgo:** Poner `VulnerableDriverBlocklistEnable = 0` rompe juegos modernos con anti-cheat a nivel de kernel. DEBE permanecer estrictamente en `1`.
2. **Eficiencia del Administrador de Tareas (Efficiency Mode):**
   * **Hallazgo:** Deshabilitar el servicio `bam` (Background Activity Moderator) rompe el *Efficiency Mode* en Windows 11. DEBE permanecer activo (`startup = 1`).
3. **Controladores de Xbox y Auriculares:**
   * **Hallazgo:** Alterar `SvcHostSplitThresholdInKB` con valores arbitrarios rompe `XboxGipSvc` y el emparejamiento de mandos inalámbricos. DEBE configurarse con el límite seguro oficial de memoria.
4. **Microsoft Store y Certificados:**
   * **Hallazgo:** Desactivar `DisableRootAutoUpdate` en `AuthRoot` bloquea la descarga de licencias y dependencias de la Microsoft Store. DEBE preservarse habilitado.
5. **Red TCP:**
   * **Hallazgo:** Forzar `congestionprovider = bbr2` rompe la estabilidad de conexiones WebSocket en Windows. Se debe mantener el proveedor de congestión nativo `default`.

---

## 2. Objetivos de la Fase 1 en OptimizedISO

1. **Suite Nativa de Desktop Helpers (`romanOS Helpers`):**
   * Crear la suite de conmutadores modales ejecutables desde el escritorio post-instalación:
     * `Toggle-WindowsUpdate` (Conmutador On/Off de Windows Update + tareas `sih/sihboot`).
     * `Toggle-Defender` (Conmutador On/Off de Microsoft Defender + SmartScreen).
     * `Toggle-Bluetooth` (Conmutador On/Off de la pila Bluetooth y drivers).
     * `Toggle-Printing` (Conmutador On/Off del servicio Spooler de impresión).
     * `Toggle-FileSharing` (Conmutador On/Off de SMB / LanmanWorkstation y Network Discovery).
     * `Toggle-VBS-CoreIsolation` (Conmutador On/Off de Hypervisor Enforced Code Integrity / VBS).
2. **Centralización SSOT en `Policy-Engine.ps1` (Regla 9):**
   * Mapear en `HKLM\SOFTWARE\RomanOS\DesktopHelpers\<HelperName>` el estado oficial y las directivas canónicas.
   * Prohibir código duplicado entre los helpers de escritorio, el debloat y el Control Center.
3. **Inyección en Cascada en el Build de la ISO (Regla 10):**
   * Integrar la suite en `$OEM$\$$\Setup\Scripts\DesktopHelpers\`.
   * Crear el acceso directo de la carpeta `romanOS Helpers` en el escritorio del usuario por defecto (`Default User\Desktop`) durante `SetupComplete.cmd` o `FirstLogonCommands`.
4. **Paridad Total en la GUI (romanOS Control Center & Studio):**
   * Reflejar los mismos conmutadores de los Desktop Helpers en la interfaz gráfica del Control Center, compartiendo el mismo estado de registro en tiempo real.
5. **Refinamiento de Latencia Gaming Quirúrgica:**
   * Calibrar afinidad DPC/ISR en `Hardware-Optimizer.ps1` respetando los cores de cómputo del juego (aislando el Core 0 con auxilio de `Coreinfo64`).
   * Aplicar las salvaguardas anti-cheat certificadas en `revert.yml`.
6. **Validación y Testing Automatizado:**
   * Crear `scripts/Testing/Test-DesktopHelpers.ps1` que valide cada helper con `autorunsc64` para certificar que el cambio de estado de servicios y tareas programadas se realiza sin residuos.
   * Validar en frío contra Windows PowerShell 5.1 (`powershell.exe -STA`).

---

## 3. Plan de Implementación por Fases Detalladas

### Fase 1: Centralización SSOT en `Policy-Engine.ps1`
* Agregar las definiciones canónicas de helpers a `Policy-Engine.ps1`:
  * `Get-RomanOSDesktopHelperDef`: Retorna metadatos, servicios asociados, tareas programadas, claves de registro y estado por defecto de cada helper.
  * `Set-RomanOSDesktopHelperState`: Función canónica para aplicar o revertir el estado de un helper con telemetría visible (Fail-Visible).
  * `Get-RomanOSDesktopHelperState`: Consulta el estado actual en `HKLM\SOFTWARE\RomanOS\DesktopHelpers`.

### Fase 2: Construcción del Módulo y Lanzadores de Desktop Helpers
* Crear `scripts/Modules/Desktop-Helpers.ps1` (UTF-8 con BOM):
  * Implementación modular de `Invoke-ToggleWindowsUpdate`, `Invoke-ToggleDefender`, `Invoke-ToggleBluetooth`, `Invoke-TogglePrinting`, `Invoke-ToggleFileSharing` e `Invoke-ToggleVBS`.
* Crear carpeta de scripts ejecutables en `scripts/Desktop-Helpers/`:
  * Lanzadores dobles `.cmd` y `.ps1` (ej. `Toggle-WindowsUpdate.cmd` invocando el PS1 en `-STA -NoProfile -ExecutionPolicy Bypass` sin pausas congeladas).
  * Menús interactivos rápidos y limpios con estado actual `[Activo]` / `[Desactivado]`.

### Fase 3: Inyección Física en ISO y Despliegue en Escritorio (`$OEM$`)
* Modificar `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`:
  * Asegurar que `scripts/Desktop-Helpers/` se copie a `$targetOEM\Setup\Scripts\DesktopHelpers`.
  * Inyectar rutina en `SetupComplete.cmd` / `autounattend.xml` para generar la carpeta de accesos directos `romanOS Helpers` en el escritorio de todos los usuarios (`C:\Users\Public\Desktop` o `Default\Desktop`).
* Verificar con `Test-UnattendXml.ps1` que no haya desajustes en el XML de instalación.

### Fase 4: Paridad en GUIs (romanOS Control Center & romanOS Studio)
* Actualizar [romanOS-ControlCenter.ps1](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter.ps1):
  * Conectar la pestaña de herramientas y conmutadores para que consuman `Get-RomanOSDesktopHelperState` y `Set-RomanOSDesktopHelperState`.
  * Sincronizar el estado visual de los botones con el estado real del registro.

### Fase 5: Ajustes de Latencia y Blindaje Anti-Cheat
* Actualizar [Optimize-GamingAndApps.ps1](file:///c:/OptimizedISO/scripts/Modules/Optimize-GamingAndApps.ps1) y [Hardware-Optimizer.ps1](file:///c:/OptimizedISO/scripts/Modules/Hardware-Optimizer.ps1):
  * Blindar la directiva `VulnerableDriverBlocklistEnable = 1` y la persistencia del servicio `bam`.
  * Afinar la descongestión del Núcleo 0 delegando DPC/ISR de red y almacenamiento a núcleos auxiliares.

### Fase 6: Batería de Pruebas y Certificación de Calidad
1. **Prueba de Calidad de Código:** Ejecutar `Test-CodeQuality.ps1` (cero errores AST, cero `catch` vacíos, UTF-8 BOM estricto).
2. **Prueba en Frío en PS 5.1:** Ejecutar `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "& 'scripts/Testing/Test-DesktopHelpers.ps1'"`.
3. **Auditoría Forense con Sysinternals:** Usar `autorunsc64` para certificar que el toggle de servicios modifica los autoinicios de forma verificable.
4. **Actualización Documental y Commit Atómico:** Registrar plan en `README.md`, actualizar `docs/` y realizar commit limpio.

---

## 4. Criterios de Éxito Cuantificables
* [ ] 6 Helpers creados, funcionales y reversibles con 1 clic.
* [ ] 100% de paridad SSOT entre `Policy-Engine.ps1`, Desktop Helpers y Control Center GUI.
* [ ] Preservación del 100% de compatibilidad con anti-cheats (Vanguard / EAC) y Windows Store.
* [ ] Cero fallos silenciosos (CWE-390 erradicado en todos los nuevos scripts).
* [ ] Validación exitosa en frío en Windows PowerShell 5.1.
