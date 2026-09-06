# PLAN-0017: Motor de Introspección y Detección Robusta de Hardware Basado en Estándares Oficiales

**Fecha:** 2026-08-31  
**Autor:** Antigravity  
**Estado:** COMPLETADO  
**Área:** scripts / debloat / hardware-detection / architecture  
**Archivos Afectados:**
- `scripts/Core/Hardware-Engine.ps1` (Nuevo motor unificado de hardware basado en estándares)
- `scripts/Test-HardwareEngine.ps1` (Suite de pruebas unitarias con 20 aserciones sintéticas y en vivo)
- `scripts/Win11-Debloat-v3-Adaptive.ps1` (Integración del motor, pre-flight, HAGS y MSI Mode)
- `scripts/romanOS-Toolkit.ps1` (Integración de introspección detallada de hardware en QuickActions)
- `scripts/PostInstall-Diagnostics.ps1` (Enriquecimiento del reporte de diagnóstico con PCI-SIG y SMBIOS)
- `scripts/New-OptimizedWindowsISO-v2.ps1` (Inyección automática de `Core/` en `$OEM$`)
- `scripts/Invoke-TestSuite.ps1` (Orquestador actualizado con Fase 2 de Hardware Engine)
- `docs/plans/README.md` (Registro y trazabilidad del plan)

---

## 1. Contexto y Justificación del Problema

En la ejecución real del script `Win11-Debloat-v3-Adaptive.ps1` (documentada en `Log/Setup-Windows_20260831_204519_transcript.log`), se detectó un fallo crítico de clasificación de hardware:
1. El resumen visual reportó correctamente: `| GPU : Radeon RX 580 Series |` (leído directamente de `Win32_VideoController.Name`).
2. Sin embargo, en el paso `[12.H]` (MSI Mode) y en la clasificación del perfil de hardware (`$hwProfile`), el sistema determinó:
   `[12.H] MSI Mode: omitido (no hay GPU dedicada NVIDIA/AMD/Arc detectada).`
   `Perfil : PC ESCRITORIO (en lugar de PC GAMING con GPU dedicada)`

### Causa Raíz
El script evaluaba expresiones regulares basadas en texto comercial arbitrario (*Friendly Names*):
```powershell
# Código anterior defectuoso:
if ($g.Name -match 'NVIDIA|AMD Radeon [RX]|Intel Arc') { $isGaming = $true }
```
Este método falló por:
1. El driver oficial de AMD en Windows nombra a la tarjeta `"Radeon RX 580 Series"` (sin la palabra `"AMD"` al inicio).
2. La expresión regular contenía `[RX]`, que en sintaxis regex es una clase de un único caracter (`'R'` o `'X'`), requiriendo que existiera la palabra `"AMD Radeon R"` o `"AMD Radeon X"`.

### Necesidad de una Solución Basada en Estándares
El hardware no debe detectarse mediante heurísticas de cadenas de texto vulnerables a cambios de nombres de drivers, idiomas del SO o fabricantes OEM. La detección debe basarse en **estándares formales de la industria**:
- **PCI-SIG Vendor IDs** (`VEN_10DE`, `VEN_1002`, `VEN_8086`) mediante `PNPDeviceID`.
- **DMTF SMBIOS System Enclosure Specification** (`Win32_SystemEnclosure.ChassisTypes`).
- **Microsoft Storage Namespace** (`MSFT_PhysicalDisk` / `Get-PhysicalDisk`) para `MediaType` y `BusType`.
- **DMTF SMBIOS Physical Memory** (`Win32_PhysicalMemory`) para canales y frecuencias.
- **Topología de Procesador WMI/CIM** para arquitecturas heterogéneas (P/E cores) y 3D V-Cache.

---

## 2. Solución Arquitectural Implementada

Se diseñó e implementó un nuevo subsistema modular `scripts/Core/Hardware-Engine.ps1` con las siguientes capacidades estándar:
1. **Detección PCI-SIG de GPUs:**
   - Tabla oficial de Vendor IDs: `10DE` (NVIDIA), `1002`/`1022` (AMD), `8086` (Intel), `1AF4` (Red Hat VirtIO), `15AD` (VMware), `1414` (Microsoft Basic Render), `80EE` (VirtualBox).
   - Extracción directa del bus PCIe desde `PNPDeviceID` (`PCI\VEN_xxxx&DEV_yyyy...`).
   - Detección de soporte MSI Mode (Message Signaled Interrupts) y HAGS (Hardware Accelerated GPU Scheduling).
2. **Detección DMTF SMBIOS de Plataforma / Chasis:**
   - Clasificación por especificación DMTF DSP0134: Laptops (8, 9, 10, 11, 12, 14, 30, 31, 32), Desktops/Torres (3, 4, 6, 7, 15, 16, 24, 33, 34), Servidores (17, 23, 28).
   - Desambiguación para SAIs/UPS USB conectados a torres de escritorio (evita falsos positivos de laptop cuando existe `Win32_Battery`).
3. **Detección de Topología de Memoria RAM:**
   - Canales reales (`BankLabel` / `DeviceLocator`), conteo de módulos, frecuencia en MHz y generación DDR (DDR4/DDR5).
4. **Detección de Almacenamiento y DirectStorage:**
   - `Get-Disk | Where-Object IsBoot -eq $true` correlacionado con `Get-PhysicalDisk` para identificar `BusType` (NVMe, SATA) y `MediaType` (SSD, HDD).
   - Diagnóstico nativo de BypassIO vía `fsutil bypassIO state C:\`.
5. **Funciones Exportadas:**
   - `Get-SystemHardwareProfile` (Objeto estructurado normalizado).
   - `Format-HardwareSummary` (Renderizado estandarizado en consola).
   - `Enable-GpuMsiMode` (Activación segura e idempotente de MSI Mode para GPUs PCIe).
   - `Test-HagsSupport` (Verificación de compatibilidad con WDDM 2.7+ y GPU scheduling).

---

## 3. Verificación y Resultados Empíricos

- **Pruebas Unitarias (`scripts/Test-HardwareEngine.ps1`):** 20/20 Aprobadas (100% PASS) en Windows PowerShell 5.1 (`powershell.exe -STA -NoProfile`).
- **Pruebas en Vivo sobre Sistema Real:**
  - CPU: `AMD Ryzen 5 5600X` (6C/12T @ 3701MHz) -> Clasificado como `MODERNA (12th+/Ryzen5k+)`.
  - RAM: `15.9 GiB DDR4 @ 3600MHz Dual-Channel (2 módulos)`.
  - GPU: `Radeon RX 580 Series` (VEN_1002, DEV_67DF) -> Clasificado como `AMD Dedicated GPU` con `MSI Mode = Habilitado [1]`.
  - Perfil del Sistema: `PC GAMING (GPU dedicada)`.
- **Orquestador Maestro (`scripts/Invoke-TestSuite.ps1`):** 5/5 Fases Aprobadas en modo Quick, 6/6 fases integradas.
- **Test Harness (`scripts/Test-OptimizedISO-v2.ps1`):** 173/173 Pruebas Aprobadas (100% PASS, 0 errores, 0 regresiones).
- **Codificación y Sintaxis:** Todos los scripts verificados con UTF-8 BOM (`0xEF, 0xBB, 0xBF`) y 0 errores AST en Windows PowerShell 5.1.

---

## 2. Especificación Técnica de los Componentes a Detectar

### A. Adaptadores Gráficos (GPU Engine)
* **Identificación por PCI Vendor ID (PCI-SIG Standard):**
  A partir del `PNPDeviceID` del dispositivo (`PCI\VEN_xxxx&DEV_yyyy...`):
  - `VEN_10DE`: **NVIDIA Corporation** (GeForce, RTX, GTX, Quadro, TITAN, Tesla).
  - `VEN_1002` / `VEN_1022`: **Advanced Micro Devices, Inc. [AMD/ATI]** (Radeon RX, R9/R7, Vega, Navi).
  - `VEN_8086`: **Intel Corporation** (Diferenciando Intel Arc dedicado `DEV_56xx`, `DEV_E2xx` de iGPUs UHD/Iris).
  - `VEN_1AF4`: Red Hat / VirtIO (Máquinas virtuales KVM/QEMU).
  - `VEN_15AD`: VMware SVGA.
  - `VEN_1414`: Microsoft Basic Render / Hyper-V Video.
* **Clasificación Dedicada vs. Integrada:**
  - Si el fabricante es NVIDIA: GPU Dedicada.
  - Si el fabricante es AMD: Verificar si es APU iGPU (ej. `AMD Radeon(TM) Graphics` / `VideoProcessor` de APU) vs. GPU Dedicada PCIe (Radeon RX, etc.). Para propósitos de MSI Mode, tanto APUs como GPUs dedicadas son dispositivos PCIe que soportan MSI/MSI-X.
  - Si el fabricante es Intel: Detectar GPUs dedicadas Intel Arc mediante Device ID (`DEV_56..`, `DEV_E2..`) o nombre que contenga `Arc`.
* **Capacidades Específicas:**
  - **MSI Mode:** Soportado en toda GPU PCI Express (NVIDIA, AMD dGPU/APU, Intel Arc).
  - **HAGS (Hardware Accelerated GPU Scheduling):**
    - NVIDIA: WDDM 2.7+ (Driver >= 451.48) y arquitectura Pascal (GTX 10xx) o superior.
    - AMD: WDDM 2.7+ (Driver >= 20.5.1 / 27.20.1017+) y arquitectura RDNA1+ (RX 5000+). Polaris (RX 400/500) no soporta HAGS oficial.
    - Intel: Arc Alchemist / Battlemage con driver WDDM 3.0+.
    - Validación contra el registro: `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers` (`HwSchMode`).

### B. Factor de Forma y Plataforma (Chassis & Platform Engine)
* **Estándar DMTF SMBIOS (`Win32_SystemEnclosure.ChassisTypes`):**
  - **Portátil / Laptop:** Tipos `8` (Portable), `9` (Laptop), `10` (Notebook), `11` (Hand Held), `12` (Docking Station), `14` (Sub Notebook), `30` (Tablet), `31` (Convertible), `32` (Detachable).
  - **Escritorio / Torre:** Tipos `3` (Desktop), `4` (Low Profile Desktop), `5` (Pizza Box), `6` (Mini Tower), `7` (Tower), `15` (Space-saving), `16` (Lunch Box), `24` (Sealed-case PC), `34` (Stick PC), `35` (Mini PC / NUC), `36` (All in One).
  - **Servidor:** Tipos `17` (Main Server Chassis), `23` (Rack Mount Chassis), `28` (Blade), `29` (Blade Enclosure).
* **Confirmación por Subsistema de Batería:**
  - Consulta a `Win32_Battery`. Si existe batería interna y el chasis es portátil -> Confirmado Laptop.
  - Si existe batería pero el chasis es Desktop -> Manejo seguro de SAI/UPS USB (tratado como Desktop).

### C. Almacenamiento (Storage Engine)
* **Identificación Oficial de Disco de Arranque:**
  - Consulta a `Get-Disk | Where-Object IsBoot -eq $true`.
  - Asociación con `Get-PhysicalDisk` mediante `DeviceId` / `UniqueId`.
  - Lectura nativa de `MediaType` (`SSD`, `HDD`, `SCM`) y `BusType` (`NVMe`, `SATA`, `SAS`, `USB`).
* **DirectStorage / BypassIO:**
  - Verificación oficial vía `fsutil bypassIO state C:\` en discos NVMe.

### D. Memoria RAM (Memory Engine)
* **Topología y Módulos (`Win32_PhysicalMemory`):**
  - Módulos poblados, `DeviceLocator` y `BankLabel` para conteo de canales (Single, Dual, Quad-channel).
  - Tipo SMBIOS (`SMBIOSMemoryType`: 26 = DDR4, 34 = DDR5, etc.).
  - Frecuencia efectiva (`ConfiguredClockSpeed`) vs frecuencia nominal (`Speed`).

### E. Procesador y Topología (CPU Engine)
* **Topología (`Win32_Processor`):**
  - Número de núcleos físicos (`NumberOfCores`) y lógicos (`NumberOfLogicalProcessors`).
  - Detección de arquitecturas híbridas Intel P-core / E-core (12th Gen Alder Lake, 13th/14th Raptor Lake, Core Ultra) para no alterar el Core Parking gestionado por Intel Thread Director.
  - Detección precisa de AMD 3D V-Cache multi-CCD (Ryzen 9 7900X3D, 7950X3D, 9900X3D, 9950X3D) para preservar el estacionamiento del CCD de alta frecuencia según AMD PPM Provisioning.
  - Detección de CPUs modernas para el saneamiento de timers (`GlobalTimerResolutionRequests`).

---

## 3. Plan de Implementación por Fases

### Fase 1: Creación del Módulo / Función Helper de Introspección
- Desarrollar una función modular y pura `Get-SystemHardwareProfile` que devuelva un objeto estructurado `[PSCustomObject]` con todas las propiedades normalizadas:
  - `Platform`: IsLaptop, IsDesktop, IsServer, ChassisType, ChassisName.
  - `CPU`: Name, Vendor, Cores, Threads, IsModern, IsHybrid, IsDualCcdX3D, IsLowEnd.
  - `RAM`: TotalGiB, IsLowRAM, ModuleCount, ChannelMode, MemoryType, SpeedMHz.
  - `Disk`: BootBusType, BootMediaType, IsNVMe, IsSATA, IsHDD, IsDirectStorageReady.
  - `GPU`: Devices (array de GPUs), PrimaryGpu, HasDedicatedGpu, HasNvidia, HasAmd, HasIntelArc, HasHagsSupport, HasMsiSupport.

### Fase 2: Refactorización de `scripts/Win11-Debloat-v3-Adaptive.ps1`
- Reemplazar las heurísticas dispersas en las líneas 540-750 por la llamada al motor de introspección unificado.
- Actualizar las condiciones de los bloques:
  - `11.C` (PCIe ASPM, Core Unparking, SysMain, PageCombining, Hibernación).
  - `12.A` (HAGS: soporte oficial verificado).
  - `12.H` (MSI Mode: iteración sobre todas las GPUs dedicadas/PCIe mediante `PNPDeviceID` y Vendor IDs).
  - `12.J` (NDIS/NIC Tuning).

### Fase 3: Pruebas y Validación Empírica
- Validar el motor en frío con Windows PowerShell 5.1 (`powershell.exe -STA -NoProfile`).
- Verificar que en el sistema actual (AMD Ryzen 5 5600X + Radeon RX 580 + SATA SSD + NVMe SSD + 16GB Dual Channel) identifique:
  - Perfil: `PC GAMING (GPU dedicada)`
  - GPU: `AMD Radeon (RX 580 Series)` con `HasDedicatedGpu = $true` y `HasMsiSupport = $true`.
  - MSI Mode aplicado exitosamente.

---

## 4. Criterios de Aceptación

1. **Cero Dependencia de Cadenas Frágiles:** La detección de GPU debe operar por PCI Vendor ID (`VEN_10DE`, `VEN_1002`, `VEN_8086`) en `PNPDeviceID`.
2. **Compatibilidad Estricta:** Funcionamiento 100% libre de errores en Windows PowerShell 5.1 (`powershell.exe`) y PowerShell 7+ (`pwsh`).
3. **Codificación:** Guardado estricto en UTF-8 con BOM (`0xEF, 0xBB, 0xBF`).
4. **Idempotencia:** Ejecutable de forma repetida sin alterar configuraciones manuales previas ni corromper claves del registro.
