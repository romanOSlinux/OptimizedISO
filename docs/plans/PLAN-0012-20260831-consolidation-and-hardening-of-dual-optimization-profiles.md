# 📋 PLAN-0012: Consolidación y Fortalecimiento de Perfiles de Optimización Duales (Gaming & Hardcore)

- **ID del Plan:** `PLAN-0012-20260831-consolidation-and-hardening-of-dual-optimization-profiles`
- **Fecha de Creación:** 2026-08-31
- **Estado:** `COMPLETADO`
- **Autor / Agente:** Antigravity / romanOS Team
- **Prerrequisito:** `PLAN-0011-20260830-fast-build-zero-mount-and-wimlib-integration` (`COMPLETADO`)

---

## 🎯 1. Visión y Justificación Técnica

Actualmente, el generador de imágenes ISO cuenta con 3 perfiles de optimización:
1. **Perfil 1 (Conservador):** Casi idéntico a una instalación estándar de Windows (telemetría básica activa, sin prevención de BitLocker, sin bloqueo WPBT de BIOS, selector interactivo `Out-GridView` que complejiza el flujo desatendido).
2. **Perfil 2 (Gaming & Streaming):** Totalmente debloateado, sin telemetría, prevención de BitLocker para BypassIO/DirectStorage, pero con 100% de compatibilidad (Wi-Fi, Bluetooth, Impresión, Búsqueda, Anti-cheats).
3. **Perfil 3 (Hardcore / E-Sports):** Aplica Perfil 2 + desactiva servicios secundarios e hipervisor (`hypervisorlaunchtype off`).

### El Problema
Mantener el Perfil 1 añade deuda técnica innecesaria, ramificaciones condicionales complejas (`-ge 2`, `-le 2`, `-eq 1`) en `autounattend.xml`, `SetupComplete.cmd` y scripts de debloat, y contradice la misión del proyecto: proporcionar un sistema limpio y de alto rendimiento.

### La Solución
Consolidar el sistema en **2 perfiles definitivos y respaldados por documentación oficial de Microsoft**:

```text
┌───────────────────────────────────────────────────────────────────────────────────────┐
│                          ARQUITECTURA DE PERFILES romanOS v2                          │
├───────────────────────────────────────────────────────────────────────────────────────┤
│ [1] Gaming & Rendimiento (Equilibrado / 100% Compatible) [Recomendado]                │
│     • Cero Bloatware y Cero Telemetría.                                               │
│     • Prevención de Cifrado BitLocker (BypassIO para DirectStorage habilitado).       │
│     • MMCSS Tuning (NetworkThrottlingIndex=0xFFFFFFFF, SystemResponsiveness=10).      │
│     • Hardware-Accelerated GPU Scheduling (HAGS / HwSchMode=2).                       │
│     • Desactivación de LastAccess NTFS (disablelastaccess=1).                         │
│     • Bloqueo de Bloatware UEFI/BIOS (DisableWPBT=1) y exclusión de drivers en WU.    │
│     • 100% Compatible con Laptops, Wi-Fi, Bluetooth, Impresoras y Anti-cheats.        │
├───────────────────────────────────────────────────────────────────────────────────────┤
│ [2] Hardcore / Latencia Mínima (Torres LAN E-Sports)                                  │
│     • Todo lo del Perfil 1 + Operación en Ring 0 Puro (hypervisorlaunchtype off).     │
│     • Desactivación de servicios de background: WSearch, Spooler, SysMain,            │
│       WlanSvc (Wi-Fi), bthserv (Bluetooth), sensores y entrada táctil.                │
│     • Pila TCP Gigabit / 10G optimizada (autotuninglevel=normal, rss=enabled).        │
│     • Botonera de contingencia y rescate de 1-clic en romanOS-Toolkit.                │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔍 2. Respaldos Oficiales de Microsoft e Investigación de Mejoras

### A. Mejoras Aprobadas y Fundamentadas (Microsoft Learn)
1. **NTFS Timestamp de Último Acceso (`disablelastaccess = 1`):**
   * *Fuente:* [Microsoft Learn: `fsutil behavior set`](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil-behavior).
   * *Efecto:* Elimina micro-escrituras de metadatos continuas en SSDs NVMe al leer archivos.
2. **Infraestructura BypassIO / DirectStorage:**
   * *Fuente:* [Microsoft Learn: BypassIO Architecture](https://learn.microsoft.com/en-us/windows-hardware/drivers/ifs/bypassio).
   * *Efecto:* Permite transferencias directas NVMe → GPU. Se añade validación con `fsutil bypassio state C:` en el informe de post-instalación.
3. **Multimedia Class Scheduler Service (MMCSS):**
   * *Fuente:* [Microsoft Learn: MMCSS Registry Keys](https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service).
   * *Efecto:* `NetworkThrottlingIndex = 0xFFFFFFFF` elimina el throttling de paquetes de red durante sesiones multimedia/gaming; `SystemResponsiveness = 10` reserva 90% de ciclos a juegos sin asfixiar el OS.
4. **Hardware-Accelerated GPU Scheduling (HAGS):**
   * *Fuente:* [Microsoft Learn: HAGS Registry](https://learn.microsoft.com/en-us/windows-hardware/drivers/display/hardware-accelerated-gpu-scheduling).
   * *Efecto:* Inyección en `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\HwSchMode = 2`.
5. **Operación en Ring 0 Puro (Bare Metal):**
   * *Fuente:* [Microsoft Learn: BCDEdit Boot Options](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/bcdedit-command-line-options).
   * *Efecto:* `bcdedit /set hypervisorlaunchtype off` desactiva Hyper-V/VBS/HVCI para eliminar interrupciones de hipervisor (*VM Exits*) en e-sports.

### B. Mitos Descartados (No se implementarán)
* ❌ `useplatformclock true` (HPET forzado): Descartado porque fuerza lecturas lentas por bus ACPI (~20x más lento que TSC nativo), provocando caídas de FPS.
* ❌ `disabledynamictick yes` en general: Descartado porque rompe el kernel tickless en Windows 11 y causa jitter en CPUs modernas híbridas (P-cores / E-cores).
* ❌ `TcpAckFrequency / TCPNoDelay` global: Descartado porque fragmenta paquetes TCP en conexiones gigabit y los juegos competitivos modernos usan UDP.

---

## 🛠️ 3. Componentes y Archivos Afectados

### 1. `scripts/New-OptimizedWindowsISO-v2.ps1`
* **Menú Interactivo (Paso 3):** Reducir opciones de perfil a 2:
  * `[1] Gaming & Rendimiento [Recomendado]`
  * `[2] Hardcore / Latencia Mínima [Torres LAN]`
* **Generación de `autounattend.xml`:**
  * Inyectar políticas comunes de alto rendimiento (Bypass BitLocker, BypassIO, MMCSS, HAGS, DisableWPBT, aislamiento de drivers) en el bloque base.
  * Mantener secuencia matemática estricta `<Order>1..N</Order>`.
* **Generación de `SetupComplete.cmd`:**
  * Bloque de servicios Perfil 1 (Telemetría, diagnósticos, servicios obsoletos).
  * Bloque de servicios Perfil 2 (WSearch, Spooler, SysMain, Wi-Fi, Bluetooth, sensores + `bcdedit /set hypervisorlaunchtype off` + `fsutil behavior set disablelastaccess 1`).
* **Debloat Offline AppX:**
  * Eliminar la bifurcación manual de `Out-GridView` del viejo Perfil 1.
  * Aplicar debloat automatizado preservando paquetes esenciales según perfil 1 o 2.

### 2. `scripts/PostInstall-Diagnostics.ps1`
* Actualizar validación de perfiles esperados (1 y 2).
* Añadir auditoría de estado BypassIO (`fsutil bypassio state C:`).
* Añadir auditoría de claves MMCSS y HAGS en el reporte forense Markdown / HTML.

### 3. `scripts/romanOS-Toolkit.ps1` y `scripts/romanOS-Toolkit.cmd`
* Añadir menú/funciones de reversibilidad rápida de servicios para Perfil 2:
  * Botón 1: Reactivar Wi-Fi y Bluetooth (`WlanSvc`, `bthserv`).
  * Botón 2: Reactivar Impresoras (`Spooler`).
  * Botón 3: Reactivar Búsqueda de Windows (`WSearch`).
  * Botón 4: Reactivar Hipervisor / VBS (`bcdedit /set hypervisorlaunchtype auto`).

### 4. Suites de Pruebas y Validación
* Actualizar `scripts/Test-OptimizedISO-v2.ps1` y `.agents/skills/unattended-deployment/scripts/Test-UnattendXml.ps1` para validar la matriz de 2 perfiles.
* Verificar compatibilidad estricta con Windows PowerShell 5.1 y codificación UTF-8 con BOM.

### 5. Documentación
* Actualizar `docs/MANUAL_DE_USO.md`, `docs/USAGE.md`, `docs/AUTOUNATTEND.md` y `MEMORY.md`.

---

## 🧪 4. Plan de Verificación

1. **Validación AST y Codificación UTF-8 BOM:**
   * Ejecutar `.agents/skills/powershell-windows/scripts/Test-ScriptAstAndBom.ps1` sobre todos los scripts modificados.
2. **Validación en Frío en Windows PowerShell 5.1 (`powershell.exe`):**
   * Ejecutar pruebas de parseo y `-WhatIf` directamente contra Windows PowerShell 5.1.
3. **Validación de Esquema `autounattend.xml`:**
   * Ejecutar `.agents/skills/unattended-deployment/scripts/Test-UnattendXml.ps1` para Perfil 1 y Perfil 2 con todas las combinaciones de flags (OneDrive On/Off, AutoLogon On/Off).
4. **Validación del Suite de Pruebas:**
   * Ejecutar `scripts/Invoke-TestSuite.ps1` y verificar 100% PASS.

---

## 📦 5. Criterios de Aceptación (Definición de Terminado)

- [ ] Menú y parámetros de `New-OptimizedWindowsISO-v2.ps1` consolidados estrictamente en 2 perfiles.
- [ ] Tweaks oficiales (NTFS disablelastaccess, MMCSS, HAGS, BypassIO, WPBT) inyectados y verificados.
- [ ] Botonera de contingencia y rescate integrada en `romanOS-Toolkit`.
- [ ] `PostInstall-Diagnostics.ps1` auditando la nueva matriz sin falsos positivos.
- [ ] Cero regresiones en `Invoke-TestSuite.ps1` y esquema XML válido.
- [ ] Documentación sincronizada y commit atómico limpio registrado.
