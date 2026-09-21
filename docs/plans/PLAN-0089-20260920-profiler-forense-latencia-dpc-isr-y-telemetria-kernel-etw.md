# PLAN-0089: Profiler Forense Dinámico de Latencia DPC, Interrupciones ISR y Telemetría de Kernel Exhaustiva Multi-Hardware (Intel / AMD / NVIDIA / ARM / VMs)

**Estado:** `PENDIENTE`  
**Fecha:** 2026-09-20  
**Autor:** Antigravity AI Pair Programmer & romanOS Team  
**Rama:** `feature/offline-ui-tweaks`  

---

## 1. Resumen Ejecutivo y Marco Técnico Universal Sin Límites de Hardware

El ecosistema **romanOS** cuenta con suites exhaustivas de auditoría estática ([`Audit-SystemOptimization.ps1`](file:///c:/OptimizedISO/scripts/Modules/Audit-SystemOptimization.ps1) y [`Audit-FreshInstallFootprint.ps1`](file:///c:/OptimizedISO/scripts/Modules/Audit-FreshInstallFootprint.ps1)) que evalúan el estado de claves de registro, directivas GPO y servicios del sistema. Sin embargo, en el ámbito de los sistemas en tiempo real suave (*Soft Real-Time Systems*) y el gaming competitivo, la optimización se define por el **comportamiento dinámico continuo**: la capacidad del hardware y del kernel de Windows de procesar interrupciones sin degradar el presupuesto de tiempo por fotograma (*Frame Budget*).

### Mandato Arquitectónico: Cobertura Hardware Exhaustiva y Sin Concesiones
El profiler de latencia dinámico está diseñado desde su núcleo sin límites de hardware, abarcando de forma nativa todo el espectro de procesadores, gráficos, controladoras de bus y entornos del mercado:

### A. Pilar Intel Integral (1ª a 15ª Generación, Core Ultra, Xeon y Atom/N-Series)
1. **Intel Legacy & Monolítico (1ª a 11ª Generación: Nehalem a Rocket Lake):**
   - Arquitectura de núcleo monolítico unificado sobre bus en anillo (*Ring Bus*).
   - Reloj de marcas de tiempo invariable (*Invariant TSC*, presente desde Nehalem) que previene el desvío temporal durante el escalado de frecuencias SpeedStep (EIST) o Speed Shift (HWP).
   - Detección y evaluación del coste de latencia en context switches y llamadas al sistema (*syscalls*) provocado por las mitigaciones de hardware/microcódigo contra vulnerabilidades de ejecución especulativa (*Spectre v2, Meltdown v3, L1TF, MDS/Zombieload, Downfall*).
2. **Intel Hybrid Architecture (12ª, 13ª y 14ª Generación: Alder Lake, Raptor Lake, Raptor Lake Refresh):**
   - Topología heterogénea: Cores de Rendimiento (*P-cores* Golden Cove / Raptor Cove con Hyper-Threading) y Cores de Eficiencia (*E-cores* Gracemont sin Hyper-Threading).
   - Integración profunda con **Intel Thread Director (ITD)** y la interfaz **EHFI (Enhanced Hardware Feedback Interface)** del kernel de Windows 11 para la asignación prioritaria de DPCs, ISRs y subprocesos de renderizado a P-cores, evitando que hilos de tiempo crítico queden degradados en E-cores.
3. **Intel Core Ultra Series 1 y 2 (Meteor Lake, Arrow Lake, Lunar Lake):**
   - Desagregación modular en empaquetado 3D Foveros (Compute Tile, Graphics Tile, SoC Tile, IO Tile).
   - Topología de tres niveles: P-cores (Lion Cove / Redwood Cove) + E-cores (Skymont / Crestmont) + **Low Power Island LP E-cores** ubicados físicamente en el SoC Tile.
   - **Soporte Arrow Lake / Lunar Lake:** Reconocimiento arquitectónico de la eliminación total de Hyper-Threading en P-cores (número de hilos igual al número de núcleos), garantizando que no se confundan con procesadores monolíticos antiguos.
   - Integración con NPU dedicada (*Intel AI Boost*).
4. **Intel Alder Lake-N y N-Series (Processor N95, N100, N200, N300, Core i3-N305):**
   - Detección de procesadores puros de E-cores (arquitectura Gracemont exclusiva sin P-cores), adaptando los umbrales de jitter y latencia DPC al rendimiento IPC de baja potencia.
5. **Intel Xeon Workstation & Server (Xeon W, Xeon Scalable, Core X-Series HEDT):**
   - Interconexión en malla (*Mesh Architecture*), múltiples zócalos NUMA, Sub-NUMA Clustering (SNC) y balanceo de interrupciones DPC entre nodos de memoria local.
6. **Matriz de Controladores Kernel Intel Críticos para Latencia:**
   - `HECIx64.sys` / `TeeDriverW10x64.sys` (*Intel Management Engine Interface - CSME*): Picos severos (>1,500 µs) por telemetría de firmware y sondeo de estados de energía en el PCH.
   - `IntcAudioBus.sys` / `IntcOED.sys` / `isup_bus.sys` (*Intel Smart Sound Technology*): Causa primaria de micro-cortes (*stuttering*) y chasquidos de audio por desbordamiento del búfer DSP.
   - `ipf_cpu.sys` / `dptf_cpu.sys` / `esif_lf.sys` (*Intel Dynamic Tuning / Innovation Platform Framework*): Tirones periódicos causados por sondeo agresivo de registros MSR y tablas ACPI.
   - `Netwtw*.sys` (`Netwtw10.sys`, `Netwtw12.sys`, `Netwtw14.sys`) (*Intel Wi-Fi 6/6E/7 y Killer Wireless*): Ráfagas de interrupción por sondeos de itinerancia (*roaming*) y ahorro de energía DTIM.
   - `e1d*.sys` / `e2f*.sys` (*Intel Gigabit y 2.5GbE Ethernet I225-V/I226-V*): Problemas de moderación de interrupciones y Energy Efficient Ethernet (EEE).
   - `iaStorVD.sys` / `iaStorAC.sys` (*Intel RST / VMD*): Picos por vaciado de búfer y transiciones de Link Power Management (LPM).
   - `igdkmdn64.sys` / `igfx*.sys` (*Intel Arc dGPU y UHD/Iris Xe iGPU*): Latencia de presentación de fotogramas WDDM y colas de compilación XeSS.
   - `iaLPSS2_I2C.sys` / `iaLPSS2_GPIO2.sys` (*Intel Serial IO*): Latencia de bus I2C en paneles táctiles y sensores.

---

### B. Pilar AMD Integral (Zen 1 a Zen 5, X3D, APUs y Radeon)
1. **Zen 1, Zen+, Zen 2, Zen 3, Zen 4 y Zen 5:**
   - Detección de topologías monolíticas (Cezanne, Rembrandt, Phoenix, Hawk Point, Strix Point) vs. diseños modulares multi-chiplet (CCD + IOD).
2. **AMD 3D V-Cache Asimétrico (Ryzen 7900X3D, 7950X3D, 9900X3D, 9950X3D):**
   - Evaluación del estado del controlador *AMD CPPC* y el servicio *AMD 3D V-Cache Performance Optimizer* para verificar que los hilos de juegos se confinan al CCD con memoria apilada 3D V-Cache y los procesos secundarios al CCD de alta frecuencia.
3. **Controladores AMD:**
   - `amdkmdag.sys` / `atikmdag.sys` (*AMD Radeon Graphics*): Transiciones ULPS y compilación de shader caches.
   - `amdpsp.sys` (*AMD Platform Security Processor*).
   - `amdi2c.sys` / `amdgpio2.sys` (*AMD Chipset Drivers*).

---

### C. Pilar NVIDIA Graphics (GeForce GTX / RTX)
1. **Familias Pascal, Turing, Ampere, Ada Lovelace y Blackwell:**
   - Atribución forense a `nvlddmkm.sys` y `nvhda64v.sys`.
   - Diagnóstico del modo de interrupción: verificación de Message Signaled Interrupts (MSI / MSI-X) frente a líneas IRQ compartidas legadas.
   - Análisis de latencia por transiciones de energía PCIe ASPM y estados P (P8 vs P0).

---

### D. Pilar Qualcomm Snapdragon / ARM64
- Soporte para plataformas Windows on ARM (Snapdragon X Elite, Snapdragon X Plus, 8cx Gen 3) con temporizadores virtuales de ARM y controladores de bus Adreno/Hexagon.

---

### E. Pilar Almacenamiento, Periféricos y Core OS
- **Red:** Realtek PCIe GbE/2.5GbE (`rt640x64.sys`), Microsoft NDIS (`ndis.sys`), TCP/IP (`tcpip.sys`).
- **Audio:** Realtek High Definition Audio (`RTKVHD64.sys`), USB Audio (`usbaudio.sys`).
- **Almacenamiento:** Microsoft Standard NVM Express (`stornvme.sys`), StorPort (`storport.sys`).
- **Kernel:** DirectX Graphics Kernel (`dxgkrnl.sys`), Kernel Mode Driver Framework (`wdf01000.sys`), ACPI (`acpi.sys`).

---

### F. Pilar Virtualización e Hipervisores (VMs)
- **Hipervisores:** Hyper-V (`vmbus.sys`, `vmswitch.sys`), VMware (`vm3dmp.sys`, `vmci.sys`), KVM/QEMU (`virtio*.sys`), VirtualBox (`VBoxGuest.sys`).
- **Mitigación de Drift Sintético:** Compensación del reparto de tiempo del hipervisor host para prevenir falsas alarmas de latencia en máquinas virtuales de prueba.

---

## 2. Fundamento Matemático y Fuentes Técnicas Oficiales

### A. Presupuesto de Fotograma y Contención DPC
La estabilidad de frametime (*frametime pacing*) y la prevención del *micro-stuttering* vienen regidas por la relación matemática:

$$\text{Frame Budget} = \frac{1000\text{ ms}}{\text{Tasa de Refresco (Hz)}}$$

* A **144 Hz**, el presupuesto es de **6.94 ms** ($6,944\text{ \mu s}$).
* A **240 Hz**, el presupuesto es de **4.16 ms** ($4,166\text{ \mu s}$).
* A **360 Hz / 540 Hz**, el presupuesto desciende a **2.77 ms** ($2,777\text{ \mu s}$) y **1.85 ms** ($1,851\text{ \mu s}$).

Cuando un controlador (ej. `nvlddmkm.sys`, `HECIx64.sys`, `IntcAudioBus.sys` o `ndis.sys`) genera una llamada a procedimiento diferido (*DPC*) prolongada (ej. $1,500\text{ \mu s}$ - $2,500\text{ \mu s}$):
- Acapara entre el **36% y el 135%** del tiempo total del fotograma.
- Bloquea el hilo del despachador del kernel en ese núcleo, impidiendo que el Desktop Window Manager (DWM) o el motor del juego procese el frame a tiempo, resultando en un fotograma descartado (*dropped frame*), tartamudeo (*stuttering*) o chasquidos de audio (*buffer underrun*).

**Escala de Calidad romanOS:**
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
* **Intel 64 and IA-32 Architectures Software Developer’s Manual:**
  - *Volume 3A, Chapter 10: Advanced Programmable Interrupt Controller (APIC)*.
  - *Volume 3B, Chapter 17: Hardware Performance Monitoring and Invariant TSC*.
  - *Volume 3B, Chapter 18: Intel Thread Director and Enhanced Hardware Feedback Interface (EHFI)*.
* **AMD64 Architecture Programmer’s Manual:**
  - *Volume 2, Chapter 15: Invariant TSC and Interrupt Handling*.
  - *Volume 2, Chapter 16: Core Performance Boost and CPPC*.
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

---

## 4. Plan de Modificaciones en el Repositorio

### Componente 0: Actualización del Motor de Introspección (`Hardware-Engine.ps1`)
* Modificar: [`scripts/Core/Hardware-Engine.ps1`](file:///c:/OptimizedISO/scripts/Core/Hardware-Engine.ps1)
  * Ampliar la detección de arquitecturas Intel:
    - Reconocimiento de **Intel Core Ultra Series 2 (Arrow Lake y Lunar Lake)** donde no hay Hyper-Threading en P-cores (`cpuThreads == cpuCores`), evitando que se descarte la clasificación de CPU híbrida.
    - Detección de procesadores **Intel Alder Lake-N / N-Series** (`Processor N100`, `N200`, `N95`, `i3-N305`) como sistemas puros de E-cores (`IsEcoreOnly = $true`).
    - Detección de **Intel Legacy Core (1ª a 11ª Gen)** para advertir sobre el impacto de mitigaciones de vulnerabilidades especulativas (`IsLegacyIntel = $true`).
    - Detección de **Intel Xeon** (`IsIntelXeon = $true`) con topología Mesh.
* Modificar: [`scripts/Testing/Test-HardwareEngine.ps1`](file:///c:/OptimizedISO/scripts/Testing/Test-HardwareEngine.ps1)
  * Agregar aserciones sintéticas para Arrow Lake (Core Ultra 9 285K sin HT), Alder Lake-N (Processor N100) e Intel Legacy Core (Core i7-10700K).

### Componente 1: Nuevo Script Satélite Multi-Hardware
* Crear: [`scripts/Modules/Trace-SystemLatency.ps1`](file:///c:/OptimizedISO/scripts/Modules/Trace-SystemLatency.ps1)
  * Codificación: UTF-8 con BOM.
  * Compatibilidad: Windows PowerShell 5.1 y PowerShell 7+.
  * Detección dinámica: Carga `scripts/Core/Hardware-Engine.ps1` (`Get-SystemHardwareProfile`) para contextualizar la prueba según la CPU (Intel Core Ultra / Hybrid / Legacy / Xeon vs AMD Zen / X3D) y la GPU (NVIDIA / AMD / Intel Arc).
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
   * 100% PASS en la suite completa de pruebas unitarias (BOM, AST, Hardware Engine 23/23 aserciones, Autounattend schema).
