# PLAN-0089: Profiler Forense Dinámico de Latencia DPC, Interrupciones ISR y Telemetría de Kernel Multi-Hardware

**Estado:** `PENDIENTE`  
**Fecha:** 2026-09-20  
**Autor:** Antigravity AI Pair Programmer & romanOS Team  
**Rama:** `feature/offline-ui-tweaks`  

---

## 1. Resumen Ejecutivo y Marco Técnico Universal

El ecosistema **romanOS** cuenta con suites exhaustivas de auditoría estática ([`Audit-SystemOptimization.ps1`](file:///c:/OptimizedISO/scripts/Modules/Audit-SystemOptimization.ps1) y [`Audit-FreshInstallFootprint.ps1`](file:///c:/OptimizedISO/scripts/Modules/Audit-FreshInstallFootprint.ps1)) que evalúan el estado de claves de registro, directivas GPO y servicios del sistema. Sin embargo, en el ámbito de los sistemas en tiempo real suave (*Soft Real-Time Systems*) y el gaming competitivo, la optimización se define por el **comportamiento dinámico continuo**: la capacidad del hardware y del kernel de Windows de procesar interrupciones sin degradar el presupuesto de tiempo por fotograma (*Frame Budget*).

### Principio Fundamental: Universalidad Multi-Hardware (Agnóstico de Plataforma)
Este plan **NO** está diseñado de forma aislada para un procesador o arquitectura particular (el sistema host de prueba, basado en AMD Ryzen 5 8600G, se emplea exclusivamente como un caso de referencia empírico). El profiler está concebido desde su núcleo como un **motor universal, multi-fabricante y adaptable** a:
1. **Microarquitecturas Intel:** 12ª, 13ª y 14ª generación (Alder Lake, Raptor Lake) y **Intel Core Ultra** (Meteor Lake, Arrow Lake, Lunar Lake), contemplando topologías híbridas con núcleos de rendimiento (*P-cores*) y núcleos de eficiencia (*E-cores*), *Intel Thread Director*, *Intel Speed Shift (HWP)* y controladores gráficos Intel Arc / Iris Xe (`igdkmdn64.sys`).
2. **Microarquitecturas AMD:** Zen 2, Zen 3, Zen 4 y Zen 5, tanto en diseños monolíticos (APUs Phoenix, Hawk Point, Cezanne) como en topologías chiplet asimétricas con **AMD 3D V-Cache** (Ryzen 7 7800X3D, Ryzen 9 7900X3D, 7950X3D, 9800X3D, 9950X3D con driver CPPC), así como gráficos Radeon discretos e integrados (`amdkmdag.sys`).
3. **Ecosistema Gráfico NVIDIA:** GPUs discretas GeForce GTX y RTX (`nvlddmkm.sys`, `nvhda64v.sys`), correlacionando picos de latencia DPC producidos por transiciones de estados de energía PCIe (ASPM/P-states) o contención de interrupciones sin MSI-X.
4. **Controladores de Periféricos y Red Universales:** Realtek (`rt640x64.sys`, `RTKVHD64.sys`), Intel Wi-Fi/Killer (`Netwtw*.sys`), controladores NVMe estándar de Microsoft (`stornvme.sys`), Intel RST (`iaStorVD.sys`), NDIS (`ndis.sys`) y el framework KMDF (`wdf01000.sys`).
5. **Entornos Virtualizados (Hyper-V, VMware, KVM/QEMU):** Detección de hipervisores y mitigación de falsos positivos derivados del reparto de tiempo de CPU del host sobre el reloj sintético de la máquina virtual.

---

## 2. Fundamento Matemático y Fuentes Oficiales

### A. Presupuesto de Fotograma y Contención DPC
La estabilidad de frametime (*frametime pacing*) y la prevención del *micro-stuttering* vienen regidas por la relación matemática:

$$\text{Frame Budget} = \frac{1000\text{ ms}}{\text{Tasa de Refresco (Hz)}}$$

* A **144 Hz**, el presupuesto es de **6.94 ms** ($6,944\text{ \mu s}$).
* A **240 Hz**, el presupuesto es de **4.16 ms** ($4,166\text{ \mu s}$).
* A **360 Hz / 540 Hz**, el presupuesto desciende a **2.77 ms** ($2,777\text{ \mu s}$) y **1.85 ms** ($1,851\text{ \mu s}$).

Cuando un controlador (ej. driver de GPU, red o almacenamiento) genera una llamada a procedimiento diferido (*DPC*) prolongada (ej. $1,500\text{ \mu s}$ - $2,000\text{ \mu s}$):
- Acapara entre el **36% y el 108%** del tiempo total del fotograma.
- Bloquea el hilo del despachador del kernel en ese núcleo, impidiendo que el Desktop Window Manager (DWM) o el motor del juego procese el frame a tiempo, resultando en un fotograma descartado (*dropped frame*), tartamudeo (*stuttering*) o chasquidos de audio (*buffer underrun*).

**Meta de Calidad romanOS:**
- `Nivel ELITE (Gaming Tier 1)`: Latencia DPC máxima observada $\le 300\text{ \mu s}$ ($< 7.2\%$ del presupuesto a 240 Hz).
- `Nivel ESTÁNDAR (Aceptable)`: Latencia DPC máxima entre $300\text{ \mu s}$ y $800\text{ \mu s}$.
- `Nivel ALERTA (Degenerado)`: Latencia DPC máxima $> 800\text{ \mu s}$ (requiere remediación de drivers o MSI).

### B. Invariancia del TSC en x86_64 Moderno (Intel & AMD)
Tanto Intel (*Invariant TSC*, bit `CPUID 8000_0007h:EDX[8]`) como AMD (*Constant/Invariant TSC*) garantizan que el contador de marcas de tiempo (*Time Stamp Counter*) corre a una frecuencia constante idéntica en todos los núcleos lógicos, inmune a escalados de frecuencia (SpeedStep, Speed Shift, Precision Boost) o estados de bajo consumo (C-states).
Las APIs Win32 `QueryPerformanceCounter` y `QueryPerformanceFrequency` utilizan este hardware de forma transparente y determinista en cualquier CPU x86_64 moderna.

### C. Fuentes Técnicas Oficiales
* **Microsoft Learn:** *Interrupt Service Routines (ISRs) and Deferred Procedure Calls (DPCs)*.
* **Microsoft Learn:** *Windows Performance Toolkit (WPT / xperf / ETW Architecture)*.
* **Microsoft Learn:** *High-Resolution Timestamp Support in Windows*.
* **Intel 64 and IA-32 Architectures Software Developer’s Manual:** *Volume 3B, Chapter 17: Hardware Performance Monitoring and Invariant TSC*.
* **AMD64 Architecture Programmer’s Manual:** *Volume 2, Chapter 15: Invariant TSC and Interrupt Handling*.
* **Windows Internals (Russinovich, Solomon, Ionescu):** *Traps, Interrupts, DPCs and the Dispatcher*.

---

## 3. Arquitectura del Profiler Universal (`Trace-SystemLatency.ps1`)

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│             ARQUITECTURA DEL PROFILER FORENSE MULTI-HARDWARE (PLAN-0089)          │
├──────────────────────────────────────────────────────────────────────────────────┤
│ 1. Introspección Topológica ➔ Consumo de Hardware-Engine.ps1 (Intel/AMD/NVIDIA/VM)│
│ 2. Win32 / Kernel Engine    ➔ QueryPerformanceCounter + NtQueryTimerResolution   │
│ 3. Medición DPC & ISR       ➔ Muestreo nanosegundos, pico máximo, promedio, jitter│
│ 4. Matriz Multi-Driver      ➔ Atribución correlacionada a drivers activos        │
│ 5. Integración Hub CLI      ➔ romanOS-Toolkit.ps1 (Opción interactiva + switches)│
│ 6. Integración GUI WPF      ➔ romanOS-ControlCenter.ps1 (Widget DPC en tiempo real)│
│ 7. Inyección $OEM$ en ISO   ➔ New-OptimizedWindowsISO-v2.ps1 para paridad total  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### Matriz de Atribución Multi-Fabricante de Controladores:
El script identificará automáticamente qué controladores residen en el sistema según la topología detectada por `Hardware-Engine.ps1`:

| Fabricante / Subsistema | Controladores Clave en Kernel | Causa Típica de Picos DPC |
| :--- | :--- | :--- |
| **NVIDIA Graphics** | `nvlddmkm.sys`, `nvhda64v.sys` | Transiciones de P-States, PCIe ASPM, interrupciones tradicionales en lugar de MSI. |
| **AMD Graphics** | `amdkmdag.sys`, `atikmdag.sys` | ULPS (Ultra Low Power State), concurrencia de shader compilation o bus PCIe. |
| **Intel Graphics** | `igdkmdn64.sys`, `igfx*.sys` | Dynamic Frequency Switching en Intel Arc / Iris Xe. |
| **Red (Intel/Killer)** | `Netwtw*.sys`, `e1d*.sys`, `e2f*.sys` | Energy Efficient Ethernet (EEE), coalescencia de interrupciones o búferes de recepción. |
| **Red (Realtek)** | `rt640x64.sys` | Descarga de suma de comprobación (Checksum Offload), Green Ethernet o EEE. |
| **Almacenamiento** | `stornvme.sys`, `iaStorVD.sys` | Comandos de vaciado de caché (*cache flush*) o estados de ahorro APST en NVMe. |
| **Audio** | `RTKVHD64.sys`, `usbaudio.sys` | Desbordamiento de búfer, contención de puerto USB o frecuencia de muestreo. |
| **Kernel / Core OS** | `ndis.sys`, `tcpip.sys`, `dxgkrnl.sys`, `wdf01000.sys`, `acpi.sys` | Gestión de energía ACPI D-states o contención del scheduler DWM. |
| **Entornos Virtuales** | `vmbus.sys`, `vm3dmp.sys`, `virtio*.sys` | Sobresuscripción de vCPU o temporizadores sintéticos del hipervisor. |

---

## 4. Plan de Modificaciones en el Repositorio

### Componente 1: Nuevo Script Satélite Multi-Hardware
* Crear: [`scripts/Modules/Trace-SystemLatency.ps1`](file:///c:/OptimizedISO/scripts/Modules/Trace-SystemLatency.ps1)
  * Codificación: UTF-8 con BOM.
  * Compatibilidad: Windows PowerShell 5.1 y PowerShell 7+.
  * Detección dinámica: Carga `scripts/Core/Hardware-Engine.ps1` (`Get-SystemHardwareProfile`) para contextualizar la prueba según CPU (Intel P/E vs AMD Zen/X3D) y GPU (NVIDIA/AMD/Intel).
  * Métricas: Mínimo, Media, Percentil 95, Percentil 99, Máximo absoluto en microsegundos ($\mu s$).
  * Auditoría de temporizador: Consulta `NtQueryTimerResolution` vía P/Invoke (verifica si el sistema está a 1.000 ms, 0.500 ms o dinámico).
* Crear: [`scripts/Modules/Trace-SystemLatency.cmd`](file:///c:/OptimizedISO/scripts/Modules/Trace-SystemLatency.cmd)
  * Codificación: ANSI / UTF-8 puro sin BOM.
  * Auto-elevación UAC y ejecución con `-STA -NoProfile -ExecutionPolicy Bypass`.

### Componente 2: Orquestador Hub CLI (`romanOS-Toolkit.ps1`)
* Modificar: [`scripts/Modules/romanOS-Toolkit.ps1`](file:///c:/OptimizedISO/scripts/Modules/romanOS-Toolkit.ps1)
  * Añadir función invocadora `Invoke-LatencyTraceModule`.
  * Integrar opción interactiva en el menú principal del Toolkit.
  * Añadir switches `-Module LatencyProfiler` y `-TraceLatency` para automatización sin intervención humana.

### Componente 3: Interfaz Gráfica (`romanOS-ControlCenter.ps1`)
* Modificar: [`scripts/GUI/romanOS-ControlCenter.ps1`](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter.ps1)
  * Incorporar botón en el Dashboard / Gaming: `[Test de Latencia DPC en Vivo (Microsegundos)]`.
  * Ejecución no bloqueante vía hilo asíncrono, mostrando el reporte en la consola integrada de WPF.

### Componente 4: Generador de ISO en Cascada (`New-OptimizedWindowsISO-v2.ps1`)
* Modificar: [`scripts/Builder/New-OptimizedWindowsISO-v2.ps1`](file:///c:/OptimizedISO/scripts/Builder/New-OptimizedWindowsISO-v2.ps1)
  * Inyectar `Trace-SystemLatency.ps1` y `Trace-SystemLatency.cmd` en `$OEM$\$$\Setup\Scripts` y `$OEM$\$1\Windows\Setup\Scripts`.

---

## 5. Protocolo de Validación y Certificación

1. **Prueba en Frío AST en Windows PowerShell 5.1:**
   * `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'scripts/Modules/Trace-SystemLatency.ps1' -WhatIf }"`
2. **Ejecución Empírica de Muestreo:**
   * Muestra de 5 segundos para calibrar la recolección de microsegundos y la correlación de controladores en el entorno en vivo.
3. **Validación del Pre-Commit Hook:**
   * 100% PASS en la suite completa de pruebas unitarias (BOM, AST, Hardware Engine, Autounattend schema).
