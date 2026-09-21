# PLAN-0090: Revisión Exhaustiva del Ecosistema de Scripts y Ejecutables, Universalización Multi-Hardware y Desacoplamiento Definitivo de Windows 10

**Estado:** EN PROGRESO  
**Fecha:** 2026-09-20  
**Autor:** romanOS Engineering Team  
**Área:** Arquitectura Transversal, Servicing, Hardware Engine, Debloat, Toolkit & GUI  
**Referencias Oficiales:**
- Microsoft Learn: *Windows 11 Specifications, Features and Computer Requirements* (22H2 / 23H2 / 24H2 / 25H2)
- Microsoft Lifecycle Policy: *Windows 10 Home and Pro Lifecycle* (End of Servicing: October 14, 2025 - KB5001716)
- DMTF Specification: *DSP0134 SMBIOS System Enclosure / Chassis Types v3.7.0* (Sections 7.4.1 y 7.18.2)
- PCI-SIG: *PCI Special Interest Group Vendor & Device ID Specifications* (Vendors 10DE, 1002, 1022, 8086, 1AF4, 15AD)
- Intel Corporation: *Intel 64 and IA-32 Architectures Optimization Reference Manual* (Hybrid Architecture & Thread Director)
- AMD Corporation: *AMD Processor Power Management (PPM) & 3D V-Cache Asymmetric Dual-CCD Provisioning Guide*
- Microsoft Learn: *Windows on ARM Architecture & Prism Dynamic Binary Translation Engine*
- Microsoft Learn: *File System Redirector (Sysnative vs SysWOW64) & WDDM 3.0+ Architecture*

---

## 1. Justificación Técnica y Fundamento Oficial

### 1.1. Erradicación y Desacoplamiento Total de Windows 10
1. **Fin de Ciclo de Vida Oficial (EOL):** De acuerdo con la directiva oficial de soporte de Microsoft (*Microsoft Lifecycle Policy*), Windows 10 (todas las ediciones de consumo 22H2) llega a su fin definitivo de soporte y parches de seguridad el **14 de octubre de 2025**. Mantener catálogos, selectores y shims de compatibilidad para una plataforma obsoleta contamina el código, distorsiona el árbol de testing e incrementa la deuda técnica.
2. **Incompatibilidad Arquitectónica de Fondo:**
   - **Requisitos de Instrucciones:** Windows 11 24H2 (Build 26100+) introduce la exigencia mandatoria a nivel de kernel de la instrucción `POPCNT` (SSE4.2 en arquitecturas x64 y ARMv8.1 en ARM64). Cualquier intento de retrocompatibilidad con CPUs heredadas de la era Windows 10 (anteriores a 2008) colapsa con `ILLEGAL_INSTRUCTION` durante el booteo.
   - **Erradicación de Arquitectura x86 (32-bit):** Windows 11 no existe ni existirá en 32 bits. Mantener banderas `-Architecture x86` en constructores de ISO (`New-OptimizedWindowsISO-v2.ps1`) y descargadores de updates (`Get-WindowsUpdates.ps1`) es un anacronismo heredado de Windows 10.
   - **APIs de Shell y Registro Deprecadas:** Componentes clave de Windows 10 fueron física y arquitectónicamente eliminados en Windows 11:
     - *Timeline / ActivityFeed:* La directiva `EnableActivityFeed` en `HKLM\SOFTWARE\Policies\Microsoft\Windows\System` carece de binario subyacente en Windows 11 24H2.
     - *Cortana Clásica:* La clave `DisableCortana` en `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search` fue sustituida por el desacoplamiento de Windows Copilot y componentes de IA.
     - *Start Menu Legacy:* Las claves de `TileDataLayer` y layouts basados en mosaicos son inertes en el compositing moderno de `StartMenuExperienceHost.exe`.

### 1.2. Universalización Multi-Hardware (Datos Empíricos y Métricas)
El ecosistema romanOS debe garantizar estabilidad determinista, cero cuelgues y máximo rendimiento sobre cualquier plataforma moderna:

| Familia de Hardware | Desafío Técnico Crítico | Métrica Empírica / Impacto | Solución Determinista en romanOS |
|---|---|---|---|
| **Intel Hybrid (12ª a 14ª Gen, Core Ultra 1/2)** | Gestión asimétrica de P-cores y E-cores vía Intel Thread Director. | Bloqueo o afinidad estática de cores degrada FPS en juegos entre **15% y 28%**; parkear E-cores satura los P-cores con tareas de fondo. | Delegar la afinidad al scheduler nativo CPPC v2 (`HeteroProcessSchedulingPolicy=0`, `HeteroThreadSchedulingPolicy=2`) sin forzar Core Parking destructivo. |
| **AMD 3D V-Cache Dual-CCD (7900X3D, 7950X3D, 9900X3D, 9950X3D)** | CCD0 cuenta con 96MB V-Cache; CCD1 opera a mayor frecuencia estándar sin V-Cache. | Desactivar `AmdPpmProvisioningService` o desparkear todos los cores hace que los juegos caigan en CCD1, perdiendo hasta **35% de FPS mínimos (1% low)**. | Detección estricta de `$isDualCcdX3D` en `Hardware-Engine.ps1` y blindaje absoluto contra la desactivación de servicios PPM/Provisioning de AMD. |
| **AMD APUs (Phoenix / Hawk Point / Strix Point)** | Gráficos integrados RDNA 3/3.5 comparten ancho de banda de memoria del sistema (UMA). | En configuración Single-Channel RAM, el ancho de banda cae **~42%**, cortando los FPS de la iGPU a la mitad. | Introspección DMTF Type 17 para auditar canales de memoria y sintonización bimodal de VRAM dinámica. |
| **ARM64 (Qualcomm Snapdragon X Elite / Plus)** | Emulación de binarios x64 mediante el motor Microsoft Prism en Windows 11 24H2. | Desactivar `SysMain` o forzar parches de Timer HPET causa desincronización de reloj y caída de hasta **30%** en la traducción dinámica de binarios. | Detección `$isARM64`, preservación de `SysMain` activo en ARM64, omisión de tweaks de timer x86 y resolución dinámica de ejecutables. |
| **Laptops y Portátiles (SMBIOS Chassis 8..14, 30..32)** | Modos de energía AC vs DC, Modern Standby (S0ix) y periféricos I2C/HID. | Desactivar servicios de Bluetooth o sensores rompe el touchpad gestual (`hid.inf`), audio inalámbrico A2DP (`BthAvctpSvc`) y causa drenaje de batería en suspensión. | Detección determinista con discriminación de SAIs/UPS por USB. Conservación de servicios esenciales de movilidad y reposo S0ix. |
| **Handheld PCs (ROG Ally, Legion Go, Claw)** | Dispositivos táctiles compactos de factor de forma Handheld (DMTF 11). | Matar `TabletInputService` o `TabTip.exe` inutiliza el teclado en pantalla y la interacción táctil en juegos portátiles. | Salvaguarda condicional de servicios táctiles cuando se detecta factor Handheld o Touchscreen. |
| **Máquinas Virtuales (Hyper-V, KVM, Proxmox, VMware)** | Entornos virtuales de desarrollo, CI/CD y pruebas. | Desactivar servicios de integración (`vmic*`, VirtIO) rompe el sincronismo de reloj, portapapeles bidireccional y backups VSS. | Detección de hipervisor y preservación íntegra de la suite de integración de la VM. |
| **Almacenamiento (NVMe PCIe vs SATA SSD vs HDD)** | Diferencias radicales en latencia aleatoria vs secuencial. | Desactivar `SysMain` en un disco HDD mecánico causa colapso por paginación excesiva; mantener Prefetcher agresivo en NVMe Gen4/5 añade escrituras inútiles. | Detección precisa de `MediaType` y `BusType` mediante la API de almacenamiento (`Get-PhysicalDisk`). |

### 1.3. Auditoría y Resiliencia de Ejecutables (`.exe`)
1. **Lanzadores Nativos Win32 (`Lanzar-romanOS-Studio.exe`, `Lanzar-romanOS-ControlCenter.exe`):**
   - Compilados mediante `csc.exe` de .NET Framework 4.8 con bandera `/target:winexe`.
   - Deben compilarse obligatoriamente con `/platform:anycpu` para garantizar que en Windows 11 ARM64 se ejecuten de forma nativa o bajo emulación transparente sin fallos de imagen errónea (`BadImageFormatException`).
   - Deben incorporar manifiesto embebido para delegar elevación UAC limpia y soportar rutas con espacios en blanco sin rotura de argumentos.
2. **Redirección de Sistema WOW64 (`Sysnative` vs `System32`):**
   - En sistemas de 64 bits, si un proceso de 32 bits invoca `%windir%\System32\dism.exe` o `reg.exe`, el kernel redirige a `SysWOW64`. Esto causa que DISM falle con error `0x800700c1` al intentar manipular imágenes de 64 bits o que `reg.exe` acceda a la vista virtualizada de 32 bits del registro.
   - Todo script del ecosistema debe implementar resolución canónica: comprobar si el proceso es de 32 bits sobre un SO de 64 bits y utilizar `$env:SystemRoot\Sysnative\` en lugar de `System32`.
3. **Control Estricto de Códigos de Salida y Timeouts:**
   - Erradicar llamadas directas desatendidas que asumen éxito silencioso. Envolver comandos críticos en `Invoke-MonitoredProcess` con comprobación de `$LASTEXITCODE`, captura de `stderr` y temporizador de interrupción (watchdog).

---

## 2. Plan de Acción por Fases

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       PLAN DE ACCIÓN - 5 FASES                              │
├─────────┬───────────────────────────────┬───────────────────────────────────┤
│ Fase 1  │ Registro y Formalización      │ PLAN-0090 en docs/ y README.md    │
├─────────┼───────────────────────────────┼───────────────────────────────────┤
│ Fase 2  │ Desacople y Purga Win10       │ Purgar 10_22H2, 10_LTSC, x86      │
│         │                               │ de Builders, Updaters y GUI       │
├─────────┼───────────────────────────────┼───────────────────────────────────┤
│ Fase 3  │ Unificación SSOT de Hardware  │ Debloat v3 -> Hardware-Engine.ps1 │
│         │                               │ Winget dinámico amd64/arm64       │
├─────────┼───────────────────────────────┼───────────────────────────────────┤
│ Fase 4  │ Resiliencia de Binarios .exe  │ AnyCPU en Lanzadores C#           │
│         │                               │ Resolución Sysnative 64-bit       │
├─────────┼───────────────────────────────┼───────────────────────────────────┤
│ Fase 5  │ Testing y Certificación       │ Validación en PS 5.1 nativo       │
│         │                               │ Suite completa Invoke-TestSuite   │
└─────────┴───────────────────────────────┴───────────────────────────────────┘
```

### Fase 1: Registro y Formalización del Plan Maestro
- [x] Registrar `PLAN-0090-20260920-revision-universal-hardware-ecosistema-y-desacople-win10.md` en `docs/plans/`.
- [x] Actualizar `docs/plans/README.md` incorporando la entrada correlativa 0090.
- [x] Detenerse para confirmación expresa del usuario (Regla 8).

### Fase 2: Purgado y Desacoplamiento de Windows 10
- **`scripts/Host-Tools/Get-OfficialWindowsISO.ps1`:**
  - Retirar `10_22H2` y `10_LTSC_2021` de los parámetros de validación `[ValidateSet()]` y tablas de catálogos CDN/MCT.
  - El descargador pasa a ser exclusivo de Windows 11 (`11_25H2`, `11_24H2`, `11_23H2`, `11_LTSC_2024`).
- **`scripts/Builder/Get-WindowsUpdates.ps1`:**
  - Purgar bloques de búsqueda y validación de actualizaciones para `10_22H2` y `10_LTSC_2021`.
  - Retirar arquitectura `x86` de los parámetros permitidos.
- **`scripts/Builder/New-OptimizedWindowsISO-v2.ps1`:**
  - Eliminar referencias a `10_22H2` en parámetros y descargas automáticas.
  - Eliminar soporte de arquitectura `x86` (permitir exclusivamente `amd64` y `arm64`).
  - Fijar validación obligatoria de build mínima: `$buildNumber -ge 22000`.
- **`scripts/GUI/romanOS-Studio.ps1`:**
  - Purgar `10_22H2` del ComboBox XAML de selección de versión de Windows.
- **`scripts/Testing/Test-OptimizedISO-v2.ps1`:**
  - Actualizar tests unitarios que invocaban mocks de `10_22H2` para validar que el sistema rechaza o no lista versiones deprecadas de Windows 10.

### Fase 3: Unificación SSOT de Hardware e Introspección Robusta
- **Refactorización de `scripts/Modules/Win11-Debloat-v3-Adaptive.ps1`:**
  - Eliminar la lógica de detección de hardware duplicada (líneas 400 a 620).
  - Cargar canónicamente `Hardware-Engine.ps1` e invocar `Get-SystemHardwareProfile`.
  - Consumir directamente las banderas estandarizadas: `$hw.IsLaptop`, `$hw.IsVM`, `$hw.IsHybridCPU`, `$hw.IsDualCcdX3D`, `$hw.IsLowRAM`, `$hw.IsARM64`, `$hw.IsNVMe`, `$hw.IsHDD`, etc.
- **Búsqueda Dinámica y Agnóstica de `winget.exe`:**
  - Sustituir la ruta rígida `*x64*` por una resolución multi-arquitectura:
    ```powershell
    $wingetCandidates = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue
    ```
- **Sincronización con `Policy-Engine.ps1`:**
  - Verificar que las políticas de gaming y sistema mantengan consistencia total con los hallazgos de hardware de `Hardware-Engine.ps1`.

### Fase 4: Blindaje y Resiliencia de Ejecutables (`.exe`)
- **Lanzadores C# Win32 (`scripts/GUI/*-Launcher.cs`):**
  - Auditar que los scripts de autocompilación (`Lanzar-romanOS-Studio.cmd` y `Lanzar-romanOS-ControlCenter.cmd`) pasen explícitamente `/platform:anycpu` al compilador `csc.exe`.
  - Probar ejecución tanto en procesos nativos como emulados.
- **Resolución de Redirección `Sysnative` en Invocaciones de Sistema:**
  - Crear o estandarizar en `scripts/Core/` una función auxiliar de resolución de ejecutables de sistema (`Resolve-SystemBinary`):
    ```powershell
    function Resolve-SystemBinary {
        param([string]$BinaryName)
        $sysDir = if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
            "$env:SystemRoot\Sysnative"
        } else {
            "$env:SystemRoot\System32"
        }
        return (Join-Path $sysDir $BinaryName)
    }
    ```
  - Proteger llamadas críticas a `dism.exe`, `reg.exe`, `powercfg.exe`, `bcdedit.exe`, `sc.exe`, `netsh.exe`.

### Fase 5: Verificación Empírica y Certificación del Ecosistema
- **Auditoría de Codificación:**
  - Asegurar codificación estricta UTF-8 con BOM en todos los `.ps1` modificados.
  - Asegurar codificación ANSI o UTF-8 sin BOM en los `.cmd`.
- **Ejecución de Suites de Prueba:**
  - Ejecutar `Test-HardwareEngine.ps1` en frío con Windows PowerShell 5.1 (`powershell.exe -STA`).
  - Ejecutar `Test-OptimizedISO-v2.ps1` para verificar que la suite pasa al 100% sin regresiones.
  - Ejecutar `Invoke-TestSuite.ps1` para validación holística.
- **Análisis Forense de Logs:**
  - Aplicar `grep_search` sobre el log generado buscando palabras clave de fallo (`FAIL`, `ERROR`, `Exception`) conforme a la Regla 12.

---

## 3. Matriz de Impacto en Archivos

| Archivo | Acción | Motivo Técnico |
|---|---|---|
| `docs/plans/PLAN-0090-20260920-revision-universal-hardware-ecosistema-y-desacople-win10.md` | `[NEW]` | Plan de implementación formal en el repositorio (Regla 5). |
| `docs/plans/README.md` | `[MODIFY]` | Registro de nuevo hito 0090. |
| `scripts/Host-Tools/Get-OfficialWindowsISO.ps1` | `[MODIFY]` | Purgado de catálogos y selectores `10_22H2` y `10_LTSC_2021`. |
| `scripts/Builder/Get-WindowsUpdates.ps1` | `[MODIFY]` | Purgado de catálogos de actualizaciones Win10 y arquitectura x86. |
| `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` | `[MODIFY]` | Enforzamiento de baseline Windows 11 ($build >= 22000), purga de x86. |
| `scripts/GUI/romanOS-Studio.ps1` | `[MODIFY]` | Purgado de opciones Win10 del selector gráfico ComboBox. |
| `scripts/Modules/Win11-Debloat-v3-Adaptive.ps1` | `[MODIFY]` | Erradicación de código duplicado de hardware -> Integración SSOT con `Hardware-Engine.ps1`; fix winget ARM64. |
| `scripts/Testing/Test-OptimizedISO-v2.ps1` | `[MODIFY]` | Actualización de aserciones de prueba a línea base pura de Windows 11. |
| `scripts/GUI/Lanzar-romanOS-Studio.cmd` | `[MODIFY]` | Verificación de compilación AnyCPU y manifest UAC. |
| `scripts/GUI/Lanzar-romanOS-ControlCenter.cmd` | `[MODIFY]` | Verificación de compilación AnyCPU y manifest UAC. |

---

## 4. Criterios de Aceptación (Definición de Terminado)

1. **Zero Referencias a Windows 10 en Flujos Activos:** Ningún descargador, builder o menú de interfaz gráfica ofrece compilaciones de Windows 10 ni arquitecturas x86 de 32 bits.
2. **Paridad SSOT de Hardware:** `Win11-Debloat-v3-Adaptive.ps1` no contiene código redundante de introspección de hardware y depende 100% de `Hardware-Engine.ps1`.
3. **Compatibilidad Multi-Arquitectura:** `winget.exe` y los lanzadores Win32 son plenamente funcionales en `amd64` y `arm64`.
4. **Protección Sysnative:** Ninguna llamada crítica a DISM o registro falla por redirección de arquitectura en procesos de 32 bits.
5. **Certificación al 100% en Tests:** Toda la suite `Invoke-TestSuite.ps1` finaliza en estado `PASS` bajo Windows PowerShell 5.1.
