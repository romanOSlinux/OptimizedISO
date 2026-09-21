# PLAN-0092: Corrección Forense de Compatibilidad Multi-Hardware Universal, Mapeo Topológico de Almacenamiento (TRIM) y Sincronización SSOT en romanOS Control Center

**Estado:** COMPLETADO  
**Fecha:** 2026-09-21  
**Autor:** romanOS Engineering Team  
**Área:** Interfaz Gráfica (Control Center), Mantenimiento de Almacenamiento, Subsistema Gráfico, Red y SSOT  
**Referencias Oficiales:**
- Microsoft Learn: *Optimize-Volume cmdlet (Storage Architecture & TRIM Re-trim)*
- Microsoft Learn: *MSFT_PhysicalDisk & MSFT_Disk WMI/CIM Class Reference*
- Microsoft Learn: *Get-NetRoute & Routing Table Architecture (NetTCPIP)*
- Intel Corporation: *Intel Graphics Driver Shader Cache Architecture & File Layout*
- NVIDIA Corporation: *NVIDIA Driver Shader Cache Layout (DXCache, GLCache, NV_Cache)*
- AMD Corporation: *AMD Radeon Software Shader Cache Infrastructure*
- Microsoft Learn: *EmptyWorkingSet Function (psapi.h) & Working Set Trimming Behavior*

---

## 1. Justificación Técnica y Diagnóstico Forense

Tras una inspección empírica en tiempo real sobre el host y la auditoría estricta de código, se detectaron 5 brechas técnicas que comprometen el rendimiento o la universalidad matemática del romanOS Control Center en sistemas multi-hardware de Windows 11:

### 1.1. Fallo Crítico en Detección de SSD y Comando TRIM Multi-Disco
- **Causa Raíz:** En `scripts/Modules/Invoke-WindowsMaintenance.ps1` (línea 580), el script asume erróneamente que la unidad C: (o cualquier volumen examinado) corresponde al `DeviceID = '0'`:
  ```powershell
  $diskType = (Get-PhysicalDisk | Where-Object { $_.DeviceID -eq '0' }).MediaType
  ```
- **Evidencia Empírica en Vivo:** En el equipo anfitrión actual, el Disco 0 es un HDD mecánico SATA (`WDC WD10EZEX-08WN4A0`), mientras que el sistema operativo C: reside en el Disco 2 (NVMe PCIe SSD `ADATA SWORDFISH`). Al ejecutar el mantenimiento, el script consulta el Disco 0, clasifica C: como "HDD mecánico" y **anula completamente el comando TRIM en el SSD NVMe C:**.
- **Solución Matemática:** Correlacionar cada letra de volumen con su partición y disco físico real mediante `Get-Partition -DriveLetter $dl | Get-Disk` y consultar `Get-PhysicalDisk` con el número de disco correspondiente.

### 1.2. Omisión de Rutas de Caché de Shaders en Intel Arc / Xe y APIs OpenGL
- **Causa Raíz:** Tanto en `Invoke-WindowsMaintenance.ps1` como en `Optimize-GamingAndApps.ps1`, la purga de shader cache solo busca carpetas de AMD y NVIDIA, ignorando por completo:
  - Intel Arc e Iris Xe: `%LOCALAPPDATA%\Intel\ShaderCache`, `%LOCALAPPDATA%\Intel\DXCache`, `%LOCALAPPDATA%\Intel\IGC`
  - NVIDIA: subcarpetas OpenGL `%LOCALAPPDATA%\NVIDIA\GLCache` y `%LOCALAPPDATA%\NVIDIA Corporation\NV_Cache`
  - AMD: `%LOCALAPPDATA%\AMD\GLCache` (ausente en el módulo de mantenimiento)
- **Solución:** Unificar el catálogo de rutas de sombreadores para cubrir el 100% del ecosistema GPU (NVIDIA, AMD e Intel).

### 1.3. Fragilidad en Selección de Adaptador de Red para Configuración DNS
- **Causa Raíz:** En `romanOS-ControlCenter.ps1`, los botones de cambio rápido de DNS seleccionan la tarjeta de red mediante `Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1`. En entornos con múltiples interfaces (ej. Ethernet secundaria sin salida WAN + Wi-Fi conectada a Internet, o adaptadores virtuales), esto reconfigura la interfaz errónea.
- **Solución:** Consultar la tabla de enrutamiento nativa (`Get-NetRoute -DestinationPrefix '0.0.0.0/0' | Sort-Object RouteMetric | Select-Object -First 1`) para aplicar los DNS inequívocamente sobre la tarjeta que proporciona la puerta de enlace hacia Internet.

### 1.4. Desacoplamiento SSOT en `Audit-SystemOptimization.ps1`
- **Causa Raíz:** El auditor universal del sistema reimplementa su propia lógica de detección de hardware (líneas 145 a 235) en lugar de dot-sourcer el motor maestro canónico `Hardware-Engine.ps1`. Además, audita almacenamiento buscando si *cualquier* disco es SSD, en vez de verificar específicamente el disco del sistema.
- **Solución:** Cargar `Hardware-Engine.ps1`, consumir `$hw = Get-SystemHardwareProfile` y usar sus propiedades validadas en todas las categorías de auditoría.

### 1.5. Desacoplamiento Semántico y Dinamismo de GPU en `Switch-GameDevMode.ps1` y GUI
- **Causa Raíz:** El conmutador de modos y las tarjetas XAML de la interfaz gráfica contienen cadenas de texto fijas como *"para la APU Radeon 760M"*, lo que genera desconfianza en usuarios con hardware Intel o NVIDIA.
- **Solución:** Parametrizar la descripción de liberación de memoria de forma dinámica según el hardware detectado por `Hardware-Engine.ps1` (distinguiendo entre VRAM compartida de iGPU/APU y buffer de texturas/proceso de dGPU).

---

## 2. Plan de Acción por Fases

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       PLAN DE ACCIÓN - 5 FASES                              │
├─────────┬───────────────────────────────┬───────────────────────────────────┤
│ Fase 1  │ Registro y Formalización      │ PLAN-0092 en docs/ y README.md    │
├─────────┼───────────────────────────────┼───────────────────────────────────┤
│ Fase 2  │ Corrección Mapeo Almacenamiento│ Topología Partition->Disk->TRIM   │
│         │ y Purga Universal de Shaders  │ en Maintenance y GamingAndApps    │
├─────────┼───────────────────────────────┼───────────────────────────────────┤
│ Fase 3  │ Resiliencia de Red y DNS      │ Get-NetRoute en Control Center    │
├─────────┼───────────────────────────────┼───────────────────────────────────┤
│ Fase 4  │ Consolidación SSOT y Dinamismo│ Hardware-Engine en Audit-System   │
│         │ de Mensajería                 │ y desacople de strings en Switch  │
├─────────┼───────────────────────────────┼───────────────────────────────────┤
│ Fase 5  │ Testing y Certificación       │ Validación en PS 5.1 nativo       │
│         │                               │ Suite completa Invoke-TestSuite   │
└─────────┴───────────────────────────────┴───────────────────────────────────┘
```

### Fase 1: Formalización Documental
- [x] Crear `docs/plans/PLAN-0092-20260921-correccion-forense-multi-hardware-control-center-ecosistema.md`.
- [x] Registrar la entrada en `docs/plans/README.md`.
- [x] Crear el artefacto `implementation_plan.md` y esperar la confirmación expresa del usuario (Regla 8).

### Fase 2: Almacenamiento y Shaders
- **`scripts/Modules/Invoke-WindowsMaintenance.ps1`:**
  - Sustituir la comprobación rígida `DeviceID -eq '0'` por la resolución de disco físico por volumen:
    ```powershell
    $part = Get-Partition -DriveLetter $dl -ErrorAction SilentlyContinue
    $disk = if ($part) { Get-Disk -Number $part.DiskNumber -ErrorAction SilentlyContinue } else { $null }
    $pdisk = if ($disk) { Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object DeviceId -eq $disk.Number } else { $null }
    $isSolidState = ($pdisk.MediaType -eq 'SSD' -or $disk.BusType -eq 'NVMe')
    ```
  - Ampliar `$shaderPaths` en el Módulo 4 incorporando rutas de Intel Arc/Xe (`Intel\ShaderCache`, `Intel\DXCache`), NVIDIA (`NVIDIA\GLCache`, `NVIDIA Corporation\NV_Cache`) y AMD (`AMD\GLCache`).
- **`scripts/Modules/Optimize-GamingAndApps.ps1`:**
  - Ampliar `$shaderDirs` con paridad total al catálogo extendido de sombreadores.

### Fase 3: Red y Configuración DNS en romanOS Control Center
- **`scripts/GUI/romanOS-ControlCenter.ps1`:**
  - Actualizar los bloques de script de `btnSetCloudflareDns`, `btnSetGoogleDns`, `btnSetQuad9Dns` y `btnResetDnsDhcp`:
    ```powershell
    $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1
    $w = if ($route) { Get-NetAdapter -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue } else { $null }
    if (-not $w) { $w = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and $_.HardwareInterface -eq $true } | Select-Object -First 1 }
    ```
  - Actualizar el texto descriptivo de la tarjeta de Modo Juego Agresivo en el XAML para generalizar la liberación de VRAM/RAM a cualquier GPU/APU.

### Fase 4: Sincronización Canónica SSOT y Desacople Semántico
- **`scripts/Modules/Audit-SystemOptimization.ps1`:**
  - Resolver y cargar `Hardware-Engine.ps1` mediante `Resolve-CoreModule` o búsqueda canónica.
  - Invocar `$hw = Get-SystemHardwareProfile` y sustituir la introspección ad-hoc de CPU, RAM, Disk y GPU.
  - En la auditoría de almacenamiento (Dominio 4), evaluar si la partición C: es NVMe/SSD usando las propiedades canónicas `$hw.Disk`.
- **`scripts/Modules/Switch-GameDevMode.ps1`:**
  - Sustituir menciones estáticas a `"APU Radeon 760M"` por la descripción dinámica de la GPU primaria detectada en el sistema.

### Fase 5: Verificación y Certificación
- Ejecutar pruebas en frío bajo Windows PowerShell 5.1 (`powershell.exe -STA`).
- Validar codificación UTF-8 con BOM en todos los scripts modificados.
- Ejecutar `Test-OptimizedISO-v2.ps1` e `Invoke-TestSuite.ps1 -Quick`.
- Inspección forense de logs físicos con `grep_search` conforme a la Regla 12.

---

## 3. Matriz de Archivos Afectados

| Archivo | Acción | Motivo Técnico |
|---|---|---|
| `docs/plans/PLAN-0092-20260921-correccion-forense-multi-hardware-control-center-ecosistema.md` | `[NEW]` | Plan de implementación formal (Regla 5). |
| `docs/plans/README.md` | `[MODIFY]` | Registro del plan en el índice maestro. |
| `scripts/Modules/Invoke-WindowsMaintenance.ps1` | `[MODIFY]` | Mapeo dinámico volumen->disco físico para TRIM y expansión de shaders Intel/NVIDIA/AMD. |
| `scripts/Modules/Optimize-GamingAndApps.ps1` | `[MODIFY]` | Expansión de catálogo de rutas de shaders multi-vendor. |
| `scripts/GUI/romanOS-ControlCenter.ps1` | `[MODIFY]` | Selección de tarjeta de red por gateway predeterminado y textos universales en XAML. |
| `scripts/Modules/Audit-SystemOptimization.ps1` | `[MODIFY]` | Integración canónica de `Hardware-Engine.ps1` (SSOT) y corrección de auditoría de disco C:. |
| `scripts/Modules/Switch-GameDevMode.ps1` | `[MODIFY]` | Dinamismo de nombres de GPU y generalización de mensajes. |
| `scripts/Testing/Test-OptimizedISO-v2.ps1` | `[MODIFY]` | Nuevas aserciones unitarias para TRIM multi-disco y rutas de shaders Intel. |
