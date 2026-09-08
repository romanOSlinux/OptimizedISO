# 🚗 Ecosistema Integral de Gestión de Controladores (Drivers) - romanOS

Este subsistema administra el ciclo de vida completo de los controladores en Windows: desde la integración dual offline (`boot.wim` + `install.wim`), aprovisionamiento desatendido en `autounattend.xml`, hasta el respaldo del host y la depuración del almacén `DriverStore`.

---

## 📂 1. Estructura Recomendada de Carpetas

Coloque aquí las carpetas descomprimidas con los controladores de su hardware. DISM buscará recursivamente (`/Recurse`) todos los archivos `.inf` compatibles.

```
scripts/Drivers/
├── Storage/                   # Controladores críticos de arranque (Intel VMD, AMD RAID, VirtIO)
│   ├── Intel-VMD/             # iaStorVD.inf (Intel Core 11va a 14va Gen)
│   └── VirtIO-Storage/        # viostor.inf (KVM / Proxmox / QEMU)
├── Network/                   # Adaptadores de Red (Ethernet / Wi-Fi)
│   ├── Realtek-LAN/           # Realtek PCIe GbE / 2.5GbE
│   └── Intel-WiFi/            # Intel Wi-Fi 6/6E/7
├── Input/                     # Teclados, Touchpads e interfaces I2C/HID
├── Backup-HardwareDrivers.ps1 # Herramienta de extracción y respaldo de drivers del host
├── Clean-DriverStore.ps1      # Herramienta de depuración segura de FileRepository
├── Get-CriticalDrivers.ps1    # Descargador asistido de paquetes universales
└── README.md                  # Esta documentación técnica
```

---

## 🚀 2. Capacidades y Herramientas del Ecosistema

### A. Dual-Servicing Oficial (`boot.wim` + `install.wim`)
Al compilar la ISO con `New-OptimizedWindowsISO-v2.ps1`:
1. **`boot.wim` (Índice 2: Windows Setup / WinPE):** Se inyectan los controladores críticos de almacenamiento e interfaces HID para garantizar que el instalador detecte las unidades NVMe/SSD y el teclado/touchpad inmediatamente.
2. **`install.wim`:** Se inyectan recursivamente todos los controladores con el flag `/ForceUnsigned` para garantizar la integración completa de los controladores de terceros antes de la configuración de OOBE.
3. **`autounattend.xml`:** Incorpora `Microsoft-Windows-PnpCustomizationsWinPE` para escanear controladores adicionales en medios extraíbles (`.\Drivers`).

### B. Respaldo Asistido del Host (`Backup-HardwareDrivers.ps1`)
Clona en 1 clic todos los controladores OEM de terceros activos en el equipo actual:
```powershell
# Respaldo automático en la carpeta Drivers lista para la ISO:
.\Backup-HardwareDrivers.ps1

# Respaldo en una ruta personalizada:
.\Backup-HardwareDrivers.ps1 -DestinationPath "D:\MisDrivers" -WhatIf
```
*Genera automáticamente un manifiesto `Drivers-Manifest.json` con proveedor, clase, versión y fecha de cada driver.*

### C. Depuración Segura de DriverStore (`Clean-DriverStore.ps1`)
Elimina versiones antiguas y duplicadas de controladores acumuladas en `C:\Windows\System32\DriverStore\FileRepository` (típico en drivers de GPU tras múltiples actualizaciones):
```powershell
# Simulación segura (muestra espacio y candidatos sin borrar nada):
.\Clean-DriverStore.ps1 -WhatIf

# Ejecución de limpieza con confirmación:
.\Clean-DriverStore.ps1 -Force
```
*Garantía de estabilidad:* Consulta `Win32_PnPSignedDriver` y bloquea la eliminación de cualquier controlador en uso activo por el hardware.

### D. Descargador Asistido de Controladores Críticos (`Get-CriticalDrivers.ps1`)
Descarga y descomprime automáticamente los controladores de almacenamiento más demandados:
```powershell
# Descarga Intel RST VMD y Red Hat VirtIO:
.\Get-CriticalDrivers.ps1 -Package All

# Descarga solo Intel VMD Floppy:
.\Get-CriticalDrivers.ps1 -Package IntelVMD
```

---

## 🛡️ 3. Políticas y Directivas Centralizadas (SSOT)

Todas las directivas de registro de controladores se encuentran unificadas canónicamente en `scripts/Core/Policy-Engine.ps1`:
* **`ExcludeWUDriversInQualityUpdate = 1`:** Evita que Windows Update sobreescriba controladores certificados de GPU o audio con versiones genéricas.
* **`SearchOrderConfig = 0` / `DontSearchWindowsUpdate = 1`:** Prioriza la búsqueda local de controladores en el DriverStore.
* **`AllowGenericDriverFallback = 0`:** Bloquea la instalación de controladores interinos genéricos que descargan bloatware OEM.
* **`PreventDeviceMetadataFromNetwork = 1`:** Evita la descarga de aplicaciones de soporte de hardware (HSAs como Armoury Crate o Dell SupportAssist).

---

## 💻 4. Integración en `romanOS-Toolkit.ps1`

El Toolkit Maestro incluye el módulo completo de controladores:
* Desde el menú principal: **Opción [8] Gestión Integral de Controladores**.
* Desde la consola de comandos:
  ```powershell
  .\romanOS-Toolkit.ps1 -Module Drivers
  ```