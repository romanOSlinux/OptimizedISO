# PLAN-0027: Ecosistema Integral de Gestión, Inyección y Mantenimiento de Controladores (Drivers)

**Fecha:** 2026-09-06  
**Estado:** COMPLETADO  
**Rama:** `feature/offline-ui-tweaks`  
**Autor:** Agente Antigravity / Pair-Programming  
**Plan Previo Directo:** [PLAN-0026](PLAN-0026-20260905-refactor-redundancy-decoupling-iso-toolkit.md)  
**Regla de Ejecución:** Cumplimiento estricto de Regla 8 (espera de confirmación del usuario), Regla 4 (UTF-8 con BOM, Windows PowerShell 5.1) y Regla 9 (SSOT Policy-Engine).

---

## 1. Justificación y Diagnóstico del Problema

El manejo de controladores (drivers) es el pilar de estabilidad más sensible en una instalación de Windows. Tras una auditoría exhaustiva del repositorio actual, se identificaron cuatro limitaciones críticas:

1. **Omisión de `boot.wim` (WinPE / Windows Setup):**  
   Actualmente, `New-OptimizedWindowsISO-v2.ps1` solo inyecta controladores en la imagen de destino (`install.wim`). En equipos modernos con controladoras Intel RST / VMD (Intel Core 11va a 14va generación), sistemas AMD RAID o hipervisores con discos VirtIO, el instalador de Windows corre desde `boot.wim` (Índice 2). Al no tener inyectados estos controladores en el entorno de instalación, el instalador no detecta los discos de estado sólido y arroja el error: *"No se encontró ninguna unidad"*, rompiendo la promesa de una ISO desatendida.
2. **Carencia de Herramienta de Respaldo (*Export*) para el Usuario:**  
   Los usuarios suelen carecer de instaladores `.inf` limpios para sus componentes (Wi-Fi, Bluetooth, Audio, Touchpad). Microsoft provee APIs nativas (`Export-WindowsDriver`, `pnputil.exe /export-driver *`) para clonar con 1 clic los drivers limpios del equipo antes de formatear, pero actualmente el Toolkit no expone esta capacidad.
3. **Degradación del Almacén de Controladores (`DriverStore`):**  
   Con el tiempo, las actualizaciones acumulativas y de GPU (NVIDIA / AMD) acumulan entre 10 GB y 30 GB de controladores obsoletos y duplicados en `C:\Windows\System32\DriverStore\FileRepository`. El sistema carece de un módulo de depuración seguro.
4. **Violación de la Regla 9 (SSOT):**  
   Las directivas de registro para evitar que Windows Update sobreescriba controladores (`ExcludeWUDriversInQualityUpdate`, `SearchOrderConfig`, `DontSearchWindowsUpdate`, `AllowGenericDriverFallback`) están hardcodeadas en `Win11-Debloat-v3-Adaptive.ps1` en lugar de residir canónicamente en `Policy-Engine.ps1`.

---

## 2. Objetivos Principales del Ecosistema

1. **Dual-Servicing Oficial en el Generador de ISOs:**
   - Inyección sincronizada en `boot.wim` (Índice 2: Windows Setup / WinPE) e `install.wim` mediante DISM.
   - Saneamiento y validación previa de archivos `.inf` (filtrado de arquitectura x64, verificación de payloads `.sys` y `.cat`).
   - Flag DISM `/PreventPending` para garantizar que los controladores no bloqueen el primer inicio en OOBE.
2. **Centralización Canónica de Políticas de Drivers en `Policy-Engine.ps1` (SSOT):**
   - Registrar las 6 directivas oficiales de Microsoft para aislamiento y control de drivers.
   - Desacoplar el Debloat y permitir exportación automática a `autounattend.xml`, `SetupComplete.cmd` y auditoría en `PostInstall-Diagnostics.ps1`.
3. **Módulo de Respaldo Asistido (`scripts/Drivers/Backup-HardwareDrivers.ps1`):**
   - Exportación de drivers OEM de terceros activos en el host hacia la carpeta `Drivers/` para integrarlos automáticamente en la ISO.
   - Integración directa en el menú interactivo de `RomanOS-Toolkit.ps1`.
4. **Módulo de Mantenimiento y Depuración (`scripts/Drivers/Clean-DriverStore.ps1`):**
   - Análisis y depuración de controladores huérfanos o no asociados a hardware con `pnputil.exe`.
   - Modo simulación (`-WhatIf`) con estimación de espacio recuperado.
   - Integración en el menú de mantenimiento de `RomanOS-Toolkit.ps1`.
5. **Aprovisionamiento Dinámico en `autounattend.xml`:**
   - Incorporar el componente `Microsoft-Windows-PnpCustomizationsWinPE` para soporte de carga de drivers desde la raíz de medios extraíbles.
6. **Descargador Automatizado de Drivers Críticos (`scripts/Drivers/Get-CriticalDrivers.ps1`):**
   - Descarga asistida de Intel RST / VMD Floppy Drivers y Red Hat VirtIO Drivers para almacenamiento masivo en entornos modernos y VMs.
7. **Suite de Pruebas y Auditoría:**
   - Tests de sanidad, AST y codificación UTF-8 con BOM en Windows PowerShell 5.1 para todos los nuevos módulos.

---

## 3. Arquitectura y Componentes a Desarrollar

```
OptimizedISO/
├── scripts/
│   ├── Core/
│   │   └── Policy-Engine.ps1                   [MODIFICAR] Registrar políticas SSOT de Drivers
│   ├── Drivers/
│   │   ├── README.md                           [MODIFICAR] Guía integral y estructura de carpetas
│   │   ├── Backup-HardwareDrivers.ps1          [NUEVO] Respaldo nativo de drivers del host
│   │   ├── Clean-DriverStore.ps1               [NUEVO] Limpieza segura de FileRepository
│   │   └── Get-CriticalDrivers.ps1             [NUEVO] Descargador asistido de Intel VMD / VirtIO
│   ├── New-OptimizedWindowsISO-v2.ps1          [MODIFICAR] Dual-servicing (boot.wim + install.wim) y PnpCustomizations
│   ├── RomanOS-Toolkit.ps1                     [MODIFICAR] Conectar opciones de Backup y Limpieza de DriverStore
│   ├── Win11-Debloat-v3-Adaptive.ps1           [MODIFICAR] Delegar directivas de drivers en Policy-Engine.ps1
│   └── Test-OptimizedISO-v2.ps1                [MODIFICAR] Harness con tests unitarios del ecosistema de drivers
```

---

## 4. Fases de Implementación Detalladas

### Fase 1: Centralización Canónica de Políticas de Drivers en `Policy-Engine.ps1`
* **Directivas a Registrar:**
  1. `POL_DRV_EXCLUDE_WU`: `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` -> `ExcludeWUDriversInQualityUpdate = 1` (REG_DWORD).
  2. `POL_DRV_SEARCH_ORDER`: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching` -> `SearchOrderConfig = 0` (REG_DWORD).
  3. `POL_DRV_DONT_SEARCH_WU`: `HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching` -> `DontSearchWindowsUpdate = 1` (REG_DWORD).
  4. `POL_DRV_POL_SEARCH_ORDER`: `HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching` -> `SearchOrderConfig = 0` (REG_DWORD).
  5. `POL_DRV_ALLOW_GENERIC_FALLBACK`: `HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings` -> `AllowGenericDriverFallback = 0` (REG_DWORD).
  6. `POL_DRV_PREVENT_DEVICE_METADATA`: `HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings` -> `PreventDeviceMetadataFromNetwork = 1` (REG_DWORD).
* **Funciones Auxiliares:**
  * `Get-RomanOSDriverPolicies`: Retorna la lista de políticas de controladores.
  * `Export-RomanOSDriverCommands`: Exporta bloques `RunSynchronousCommand` para `autounattend.xml` o líneas `reg add` para `SetupComplete.cmd`.
  * `Apply-RomanOSDriverPolicies`: Aplicación en vivo en el sistema instalado.
* **Desacoplamiento en `Win11-Debloat-v3-Adaptive.ps1`:**
  * Reemplazar las asignaciones hardcodeadas de las líneas 1650–1675 por la invocación canónica a `Apply-RomanOSDriverPolicies` o lectura desde `Policy-Engine.ps1`.

---

### Fase 2: Dual-Servicing en el Generador de ISO (`New-OptimizedWindowsISO-v2.ps1`)
* **Saneamiento Previo de Controladores:**
  * Función `Test-DriverInfSanity`: Analiza los `.inf` encontrados en `$resolvedDriversDir`.
  * Ignora arquitecturas no compatibles (`x86`, `arm64`) para evitar errores en imágenes `amd64`.
  * Comprueba la presencia de los binarios mínimos (`.sys`, `.cat`).
* **Inyección en `boot.wim` (WinPE / Setup):**
  * Montar `sources\boot.wim` (Índice 2: Windows Setup).
  * Ejecutar DISM:
    ```powershell
    dism.exe /Image:$bootMountDir /Add-Driver /Driver:$resolvedDriversDir /Recurse /ForceUnsigned /ScratchDir:$ScratchDir
    ```
  * Desmontar con guardado seguro (`Invoke-SafeWimDismount`).
  * Registro de auditoría `Add-AuditRecord` correspondiente.
* **Robustecimiento en `install.wim`:**
  * Incorporar el flag `/PreventPending` para asegurar que ningún controlador requiera reboot previo a OOBE.
  * Mantener auditoría WHQL existente.
* **Aprovisionamiento Dinámico en `autounattend.xml`:**
  * Agregar nodo `Microsoft-Windows-PnpCustomizationsWinPE` en el pase `<settings pass="windowsPE">` apuntando a la carpeta de drivers de la unidad de instalación.

---

### Fase 3: Módulo de Respaldo `scripts/Drivers/Backup-HardwareDrivers.ps1`
* **Especificaciones:**
  * Parámetros:
    - `-DestinationPath`: Carpeta de destino (por defecto: `C:\OptimizedISO\scripts\Drivers`).
    - `-IncludeInbox`: Switch opcional (por defecto `$false`, solo exporta controladores de terceros `oem*.inf`).
    - `-Quiet`: Ejecución silenciosa para automatización.
  * Lógica técnica:
    1. Intenta exportación mediante el cmdlet nativo `Export-WindowsDriver -Online -Destination $DestinationPath`.
    2. En caso de no disponibilidad o error, fallback robusto a `pnputil.exe /export-driver * "$DestinationPath"`.
    3. Genera un manifiesto estructurado `Drivers-Manifest.json` con metadatos:
       - Proveedor (`ProviderName`)
       - Clase de dispositivo (`ClassName`)
       - Versión y Fecha del controlador (`DriverVersion`, `DriverDate`)
       - Nombre de archivo original (`OriginalFileName`)
  * Compatible con Windows PowerShell 5.1 y guardado en UTF-8 con BOM.

---

### Fase 4: Módulo de Limpieza `scripts/Drivers/Clean-DriverStore.ps1`
* **Especificaciones:**
  * Parámetros:
    - `-WhatIf`: Simulación que lista los controladores a eliminar y estima el espacio recuperable.
    - `-Force`: Confirmación automática sin prompts interactivos.
  * Lógica técnica:
    1. Enumera controladores de terceros con `pnputil.exe /enum-drivers`.
    2. Identifica versiones duplicadas y obsoletas (especialmente drivers antiguos de GPU NVIDIA / AMD / Intel donde se instalaron múltiples revisiones).
    3. Para cada controlador obsoleto no asociado a hardware activo:
       `pnputil.exe /delete-driver <oemN.inf> /uninstall`
    4. Muestra un resumen claro con el número de paquetes eliminados y carpetas liberadas en `FileRepository`.

---

### Fase 5: Descargador Asistido de Drivers Críticos `scripts/Drivers/Get-CriticalDrivers.ps1`
* **Especificaciones:**
  * Descarga asistida de paquetes de controladores de almacenamiento masivo y virtualización de fuentes oficiales:
    - **Intel RST / VMD Floppy Driver (v19.x / v20.x):** Indispensable para portátiles Intel 11va-14va Gen.
    - **VirtIO Drivers (Red Hat / Fedora):** Indispensable para VMs en KVM, Proxmox y QEMU.
  * Descompresión automática directamente en subcarpetas organizadas:
    - `scripts/Drivers/Storage/Intel-VMD/`
    - `scripts/Drivers/Storage/VirtIO/`
  * Detección de integridad de archivos y logging estructurado.

---

### Fase 6: Integración en `RomanOS-Toolkit.ps1`
* Conectar las nuevas capacidades al menú interactivo:
  * En **Mantenimiento y Limpieza**:
    * Opción: *"Depurar DriverStore (Eliminar drivers obsoletos y recuperar espacio)"* -> Invoca `Clean-DriverStore.ps1`.
  * En **Hardware y Optimización**:
    * Opción: *"Respaldar controladores activos de este equipo (para la ISO)"* -> Invoca `Backup-HardwareDrivers.ps1`.
    * Opción: *"Descargar controladores críticos universales (Intel VMD / VirtIO)"* -> Invoca `Get-CriticalDrivers.ps1`.

---

### Fase 7: Harness de Validación y Documentación
* **Pruebas en `Test-OptimizedISO-v2.ps1`:**
  * FASE NUEVA: Validación del Ecosistema de Drivers.
  * Test de compatibilidad de sintaxis AST y UTF-8 con BOM en Windows PowerShell 5.1 para todos los nuevos scripts.
  * Test de exportación de políticas de drivers desde `Policy-Engine.ps1`.
  * Test del nodo `PnpCustomizations` en `autounattend.xml`.
* **Documentación:**
  * Actualizar completamente `scripts/Drivers/README.md` con arquitectura, árboles de carpetas, comandos de PowerShell y buenas prácticas.

---

## 5. Plan de Verificación y Criterios de Aceptación

1. **Prueba Sintáctica y de Codificación (Regla 4):**
   ```powershell
   & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & '.\scripts\Drivers\Backup-HardwareDrivers.ps1' -WhatIf }"
   & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & '.\scripts\Drivers\Clean-DriverStore.ps1' -WhatIf }"
   & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & '.\scripts\Drivers\Get-CriticalDrivers.ps1' -WhatIf }"
   ```
   *Criterio:* 0 errores de sintaxis, 0 errores de codificación BOM, ejecución limpia en PS 5.1.
2. **Prueba del Test Harness:**
   ```powershell
   & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Test-OptimizedISO-v2.ps1"
   ```
   *Criterio:* 100% tests aprobados sin regresiones en las suites existentes.
3. **Verificación SSOT:**
   Comprobar que `Export-RomanOSUnattendCommands` y `Apply-RomanOSDriverPolicies` reflejen exactamente las mismas claves de registro y valores.
