# PLAN-0028: Expansión del Catálogo de Controladores Críticos: Soporte para AMD RAID (RAIDXpert2) e Intel RST Legacy (SATA / Optane)

**Fecha:** 2026-09-06  
**Estado:** PENDIENTE  
**Rama:** `feature/offline-ui-tweaks`  
**Autor:** Agente Antigravity / Pair-Programming  
**Plan Previo Directo:** [PLAN-0027](PLAN-0027-20260906-ecosistema-integral-gestion-drivers.md)  
**Reglas Aplicables:** Regla 4 (UTF-8 con BOM, Windows PowerShell 5.1), Regla 5 (Trazabilidad de Planes), Regla 8 (Prohibición de auto-ejecución) y Regla 9 (SSOT Policy-Engine).

---

## 1. Justificación y Diagnóstico Técnico

En el [PLAN-0027](PLAN-0027-20260906-ecosistema-integral-gestion-drivers.md) se estableció el ecosistema de controladores y se creó el descargador automatizado `scripts/Drivers/Get-CriticalDrivers.ps1`, el cual actualmente ofrece soporte para:
1. **Intel RST VMD Floppy Driver** (`iaStorVD.inf`): Controladora de almacenamiento PCIe para procesadores Intel Core de 11.ª a 14.ª Gen y Core Ultra.
2. **Red Hat VirtIO Storage Driver** (`viostor.inf`) y de red (`NetKVM.inf`): Almacenamiento paravirtualizado SCSI/Block para hipervisores KVM, Proxmox VE y QEMU.

Sin embargo, tras analizar los escenarios de instalación de hardware físico en PC de escritorio y equipos legacy, se identificaron **dos brechas de compatibilidad** donde el instalador de Windows (`boot.wim`) continúa sin detectar discos si el usuario posee configuraciones específicas:

1. **Plataformas AMD con Arreglos RAID (AM4 / AM5 / Threadripper):**
   * Mientras que los discos NVMe y SATA individuales en AMD funcionan de forma nativa con los controladores estándar de Microsoft (`stornvme.sys` y `storahci.sys`), cuando el usuario configura un arreglo RAID de discos NVMe o SATA en la BIOS de placas AMD (utilizando tecnología *AMD Promontory* o controladora integrada en SoC Ryzen), el subsistema requiere una pila triple de controladores propietarios:
     * `rcbottom.inf`: Controlador de bus raíz de AMD RAID.
     * `rcraid.inf`: Controlador de miniporte de almacenamiento AMD RAID.
     * `rccfg.inf`: Controlador de configuración y topología.
   * Sin estos controladores inyectados en `boot.wim` e `install.wim`, el instalador no reconoce el volumen RAID configurado en la BIOS.

2. **Equipos Intel Legacy en modo RAID / Optane (6.ª a 10.ª Generación):**
   * En sistemas Intel anteriores a la 11.ª Gen (arquitecturas Skylake, Kaby Lake, Coffee Lake, Comet Lake) que vienen configurados de fábrica con la BIOS en modo *"RAID on"* (o utilizando aceleración Intel Optane Memory con discos SATA), el controlador moderno `iaStorVD.inf` (VMD) no es compatible.
   * Estos sistemas requieren la versión tradicional de Intel Rapid Storage Technology (`iaStorAC.inf` / `iaStorHsa_Ext.inf`), típicamente en su última versión estable para arquitecturas legacy (v17.11.x o v18.0.x).

---

## 2. Objetivos del Plan

1. **Extensión del Catálogo en `Get-CriticalDrivers.ps1`:**
   * Incorporar al parámetro `[ValidateSet()]` las opciones: `"AmdRAID"`, `"IntelLegacy"` y mantener `"All"`, `"IntelVMD"`, `"VirtIO"`.
   * Proveer URLs oficiales directas de descarga para los paquetes F6 floppy de ambos fabricantes.
2. **Estructuración de Carpetas de Destino:**
   * `scripts/Drivers/Storage/AMD-RAID/` (`rcbottom.inf`, `rcraid.inf`, `rccfg.inf`).
   * `scripts/Drivers/Storage/Intel-RST-Legacy/` (`iaStorAC.inf`, `iaStorAC.sys`).
3. **Consistencia con el Flujo de Inyección de la ISO:**
   * Mantener compatibilidad total con la lógica recursiva (`/Recurse`) de DISM `/Add-Driver` implementada en `New-OptimizedWindowsISO-v2.ps1`, de modo que cualquier carpeta contenida dentro de `scripts/Drivers/Storage/` sea absorbida automáticamente tanto en `boot.wim` como en `install.wim`.
4. **Integración con el Toolkit Maestro:**
   * Actualizar el menú interactivo de `romanOS-Toolkit.ps1` (Opción 8: Gestión de Controladores) para permitir la descarga selectiva de estos nuevos paquetes.
5. **Aserciones en el Arnés de Pruebas:**
   * Actualizar `Test-OptimizedISO-v2.ps1` para validar la sintaxis de las nuevas opciones del catálogo.

---

## 3. Especificación de Paquetes y Fuentes Oficiales

### A. AMD RAID (RAIDXpert2)
* **Proveedor:** Advanced Micro Devices, Inc. (AMD).
* **Componentes clave:** `rcbottom.inf`, `rcraid.inf`, `rccfg.inf`.
* **Mecanismo de obtención:** Descarga del paquete oficial de controladores de almacenamiento NVMe/SATA RAID de AMD (disponible en el portal de soporte de AMD para chipsets AM4/AM5).
* **Destino:** `scripts/Drivers/Storage/AMD-RAID`.

### B. Intel RST Legacy (SATA / AHCI / Optane v17.11.x)
* **Proveedor:** Intel Corporation.
* **Componentes clave:** `iaStorAC.inf`, `iaStorAC.sys`.
* **Mecanismo de obtención:** Descarga del archivo oficial `f6flpy-x64.zip` (v17.11.3.1010 o última v18.x compatible pre-VMD) alojado en `downloadmirror.intel.com`.
* **Destino:** `scripts/Drivers/Storage/Intel-RST-Legacy`.

---

## 4. Archivos Afectados

| Archivo | Acción | Propósito |
| :--- | :--- | :--- |
| `scripts/Drivers/Get-CriticalDrivers.ps1` | MODIFICAR | Incorporar definiciones de `AmdRAID` e `IntelLegacy` en el catálogo y switches de descarga. |
| `scripts/Drivers/README.md` | MODIFICAR | Documentar la adición de los nuevos perfiles de almacenamiento y su propósito. |
| `scripts/romanOS-Toolkit.ps1` | MODIFICAR | Añadir sub-opciones para la descarga selectiva de AMD RAID e Intel Legacy. |
| `scripts/Test-OptimizedISO-v2.ps1` | MODIFICAR | Registrar aserciones de validación para los nuevos perfiles. |
| `docs/plans/README.md` | MODIFICAR | Registrar `PLAN-0028` en el índice de planes. |

---

## 5. Plan de Verificación

### A. Verificación en Windows PowerShell 5.1
* Validación de sintaxis en frío con parser AST nativo de Windows PowerShell 5.1:
  ```powershell
  & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & '.\scripts\Drivers\Get-CriticalDrivers.ps1' -WhatIf }"
  ```
* Verificación de cabecera UTF-8 con BOM en todos los scripts modificados.

### B. Ejecución Asistida y Comprobación de Extracción
* Ejecución con `-Package AmdRAID` y `-Package IntelLegacy`.
* Comprobación de que la carpeta de destino contenga archivos `.inf`, `.cat` y `.sys` válidos.

### C. Suite Completa
* Ejecución de `Invoke-TestSuite.ps1 -Quick` garantizando 100% PASS sin advertencias.

---

## 6. Estado Actual
* **Estado:** `PENDIENTE` (Plan redactado y documentado para ejecución futura por indicación expresa del usuario).
