# PLAN-0089: Profiler Forense Dinámico de Latencia DPC, Interrupciones ISR y Telemetría de Kernel en Tiempo Real

**Estado:** `PENDIENTE`  
**Fecha:** 2026-09-20  
**Autor:** Antigravity AI Pair Programmer & romanOS Team  
**Rama:** `feature/offline-ui-tweaks`  

---

## 1. Resumen Ejecutivo y Marco Técnico

El ecosistema **romanOS** cuenta con suites exhaustivas de auditoría estática ([`Audit-SystemOptimization.ps1`](file:///c:/OptimizedISO/scripts/Modules/Audit-SystemOptimization.ps1) y [`Audit-FreshInstallFootprint.ps1`](file:///c:/OptimizedISO/scripts/Modules/Audit-FreshInstallFootprint.ps1)) que evalúan el estado de claves de registro, directivas GPO y servicios detenidos. Sin embargo, en el ámbito de los sistemas en tiempo real suave (*Soft Real-Time Systems*) y el gaming competitivo, la optimización se define por el **comportamiento dinámico continuo**: la capacidad del hardware y del kernel de Windows de procesar interrupciones sin degradar el presupuesto de tiempo por fotograma (*Frame Budget*).

El propósito de este plan es diseñar e implementar un **Profiler Forense de Latencia DPC/ISR de nivel de kernel nativo (zero-resident)**, sin dependencias de software externo invasivo, respaldado por las APIs de alta resolución de Windows (`QueryPerformanceCounter`, `QueryPerformanceFrequency` y `NtQueryTimerResolution`).

---

## 2. Fundamento Matemático y Fuentes Oficiales

### A. Presupuesto de Fotograma y Contención DPC
La estabilidad de frametime (*frametime pacing*) viene regida por la relación matemática:

$$\text{Frame Budget} = \frac{1000\text{ ms}}{\text{Tasa de Refresco (Hz)}}$$

* A **240 Hz**, el presupuesto por fotograma es de **4.16 ms** ($4,166\text{ \mu s}$).
* Cuando un controlador (ej. red `ndis.sys`, almacenamiento `stornvme.sys` o GPU `dxgkrnl.sys`) genera una llamada a procedimiento diferido (*DPC*) prolongada (ej. $1,800\text{ \mu s}$), acapara más del **43% del tiempo disponible**, forzando al Desktop Window Manager (DWM) a retrasar la presentación del frame.
* **Meta de romanOS:** Garantizar un techo de latencia DPC $\le 300\text{ \mu s}$, reduciendo el impacto de las interrupciones a menos del **7.2% del frame budget**.

### B. Fuentes Técnicas Oficiales
* **Microsoft Learn:** *Windows Performance Toolkit (WPT / xperf / ETW Architecture)*.
* **Microsoft Learn:** *Interrupt Service Routines (ISRs) and Deferred Procedure Calls (DPCs)*.
* **Windows Internals (Russinovich et al.):** *Chapter 3: System Mechanisms - Traps, Interrupts, and DPCs*.
* **AMD / Intel Architecture Manuals:** *Time Stamp Counter (TSC) Invariant Synchronization*.

---

## 3. Arquitectura del Profiler (`Trace-SystemLatency.ps1`)

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│              ARQUITECTURA DEL PROFILER FORENSE DPC/ISR (PLAN-0089)               │
├──────────────────────────────────────────────────────────────────────────────────┤
│ 1. Engine Win32 / Kernel ➔ QueryPerformanceCounter, NtQueryTimerResolution (TSC) │
│ 2. Medición DPC & ISR    ➔ Techo máximo (µs), promedio, jitter y desviación std  │
│ 3. Identificación Driver ➔ Rastreo de controladores con alta actividad diferida  │
│ 4. Integración Hub CLI   ➔ romanOS-Toolkit.ps1 (Opción interactiva + switches)   │
│ 5. Integración GUI WPF   ➔ romanOS-ControlCenter.ps1 (Widget de Latencia en Vivo)│
│ 6. Inyección $OEM$       ➔ New-OptimizedWindowsISO-v2.ps1 para paridad en la ISO │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### Capacidades del Profiler:
1. **Resolución Temporal Sub-Microsegundo:** Utiliza el reloj TSC nativo de la CPU (en el Ryzen 5 8600G operando a > 4.3 GHz) para medir intervalos de ejecución con precisión de nanosegundos.
2. **Medición de Timer Resolution:** Consulta la API `NtQueryTimerResolution` de `ntdll.dll` para confirmar la frecuencia exacta del temporizador (1.0 ms vs 0.5 ms).
3. **Muestreo Estadístico:** Calcula valor mínimo, promedio, mediana, percentil 99 y máximo absoluto de latencia DPC observada durante ráfagas de 5s, 10s o continuo.
4. **Correlación de Controladores:** Identifica controladores del sistema con mayor consumo de tiempo de kernel (`ndis.sys`, `tcpip.sys`, `dxgkrnl.sys`, `amdkmdag.sys`, `stornvme.sys`, `wdf01000.sys`).

---

## 4. Plan de Modificaciones en el Repositorio

### Componente 1: Nuevo Script Satélite
* Crear: [`scripts/Modules/Trace-SystemLatency.ps1`](file:///c:/OptimizedISO/scripts/Modules/Trace-SystemLatency.ps1) (UTF-8 con BOM, compatible con PS 5.1).
* Crear: [`scripts/Modules/Trace-SystemLatency.cmd`](file:///c:/OptimizedISO/scripts/Modules/Trace-SystemLatency.cmd) (ANSI / No-BOM con auto-elevación UAC).

### Componente 2: Orquestador Hub CLI (`romanOS-Toolkit.ps1`)
* Modificar: [`scripts/Modules/romanOS-Toolkit.ps1`](file:///c:/OptimizedISO/scripts/Modules/romanOS-Toolkit.ps1)
  * Añadir función `Invoke-LatencyTraceModule`.
  * Incorporar opción interactiva en el menú principal.
  * Añadir switch `-Module LatencyProfiler` / `TraceLatency`.

### Componente 3: Interfaz Gráfica (`romanOS-ControlCenter.ps1`)
* Modificar: [`scripts/GUI/romanOS-ControlCenter.ps1`](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter.ps1)
  * Añadir botón en Dashboard/Gaming: `[Test de Latencia DPC en Vivo (Microsegundos)]`.
  * Ejecución asíncrona no bloqueante con telemetría en la consola integrada.

### Componente 4: Generador de ISO (`New-OptimizedWindowsISO-v2.ps1`)
* Modificar: [`scripts/Builder/New-OptimizedWindowsISO-v2.ps1`](file:///c:/OptimizedISO/scripts/Builder/New-OptimizedWindowsISO-v2.ps1)
  * Inyección automática en cascada de `Trace-SystemLatency.ps1` y su lanzador `.cmd` en `$OEM$\$$\Setup\Scripts` y `$OEM$\$1\Windows\Setup\Scripts`.

---

## 5. Protocolo de Validación y Certificación

1. **Prueba en Frío AST en PS 5.1:**
   * `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'scripts/Modules/Trace-SystemLatency.ps1' -WhatIf }"`
2. **Ejecución Empírica de Muestreo:**
   * Muestreo de 5 segundos en el sistema host para calibrar la latencia real.
3. **Validación del Pre-Commit Hook:**
   * 100% PASS en los 42 scripts del repositorio y 20/20 aserciones del Hardware Engine.
