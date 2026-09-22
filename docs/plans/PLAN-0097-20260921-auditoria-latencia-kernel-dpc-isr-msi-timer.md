# PLAN-0097: Auditoría Forense de Latencia de Kernel (DPC/ISR), Topología de Interrupciones MSI y Timer Resolution (Micro-Stuttering Elimination 2026)

**Fecha:** 2026-09-21  
**Estado:** COMPLETADO  
**Autor:** Antigravity (Google DeepMind)  
**Rama:** `feature/offline-ui-tweaks`  
**Prerrequisitos:** PLAN-0094 (Auditoría Técnica Exhaustiva), PLAN-0095 (Resolución Integral de Hallazgos), PLAN-0096 (Auditoría de Ciberseguridad, Anti-Cheats y Persistencia de Registro)

---

## 1. Contexto y Justificación de Ingeniería

El ecosistema **romanOS / OptimizedISO** cuenta con certificación estática de código (PLAN-0094/0095) y certificación de ciberseguridad, cadena de suministro y compatibilidad anti-cheat Ring-0 (PLAN-0096).

Habiendo garantizado la confiabilidad y seguridad del sistema, la frontera definitiva de rendimiento para gaming competitivo, eSports y aplicaciones de audio/video en tiempo real radica en la **eliminación matemática del micro-stuttering (tirones y congelamientos de fotogramas)** y la **minimización de la latencia de respuesta del kernel de Windows 11 (24H2/25H2)**:
1. **Picos de Latencia DPC e ISR (Deferred Procedure Calls / Interrupt Service Routines)**:
   Aunque un juego marque 200 FPS promedio, picos esporádicos de DPC superiores a 1000 µs (generados por controladores gráficos como `amdkmdag.sys`/`nvlddmkm.sys`, de red `ndis.sys` o de almacenamiento `stornvme.sys`) congelan el pipeline de renderizado provocando caídas severas en el percentil 1% Low y 0.1% Low.
2. **Topología de Interrupciones de Hardware (Modo MSI vs. Line-Based IRQ)**:
   Los dispositivos PCIe modernos soportan *Message Signaled Interrupts* (MSI / MSI-X). Sin embargo, Windows por defecto mantiene ciertos dispositivos en modo compartido heredado (*Line-Based IRQ*), concentrando todas las interrupciones en el **Core 0 (CPU 0 Bottleneck)** y provocando contención de caché L1/L2 y cambios de contexto innecesarios.
3. **Resolución del Temporizador del Kernel (Kernel Timer Resolution)**:
   El temporizador por defecto de Windows corre a 15.625 ms (64 Hz). En entornos competitivos, esto añade jitter de sincronización en la entrega de paquetes de red y en la presentación de fotogramas (*Flip Model Presentation*). Se requiere certificar la estabilidad de resolución a submilisegundo (0.5 ms / 1.0 ms) sin desbordamiento de búfer.

---

## 2. Objetivos Principales

1. **Desarrollar el Auditor de Topología de Interrupciones PCIe (`scripts/Core/Test-MsiInterruptTopology.ps1`)**:
   - Inspeccionar el 100% de dispositivos PCIe del sistema (`HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\...`).
   - Identificar modo de interrupción (MSI habilitado vs Line-Based compartido) y prioridad de interrupción (`DevicePriority`).
   - Auditar la distribución de afinidad de CPU para evitar saturación del Core 0.
2. **Desarrollar el Validador Forense de Temporización y Tick del Kernel (`scripts/Core/Test-KernelTimerResolution.ps1`)**:
   - Medición directa mediante P/Invoke de `NtQueryTimerResolution` en `ntdll.dll`.
   - Inspección de flags BCD de reloj (`useplatformclock`, `disabledynamictick`, `syntheticclock`).
   - Auditoría de deriva de reloj (*Clock Drift*) y estabilidad del TSC invariante (*Invariant TSC*).
3. **Auditar y Correlacionar Latencias DPC/ISR frente al Presupuesto de Fotogramas (Frame Budget)**:
   - Contrastar los tiempos de servicio frente a las tasas de refresco de monitores eSports:
     - 144 Hz ➔ Presupuesto total: 6.94 ms (Límite DPC: < 500 µs)
     - 240 Hz ➔ Presupuesto total: 4.16 ms (Límite DPC: < 300 µs)
     - 360 Hz ➔ Presupuesto total: 2.77 ms (Límite DPC: < 200 µs)
     - 500 Hz ➔ Presupuesto total: 2.00 ms (Límite DPC: < 150 µs)
4. **Construir el Tablero Visual Interactivo (`AUDITORIA_LATENCIA_KERNEL_2026.html`)**:
   - Dashboard Dark Mode con KPIs de latencia, gráfico de topología MSI por dispositivo PCIe, mapa de afinidad de núcleos y recomendaciones de ingeniería.
5. **Integración en el Test Harness (`scripts/Testing/Invoke-TestSuite.ps1`)**:
   - Orquestar la validación de latencia y topología dentro del pipeline de pruebas maestro.

---

## 3. Arquitectura y Metodología de las Fases

### Fase 1: Auditoría de Topología de Interrupciones PCIe (MSI vs Line-Based)
- Escaneo del bus PCI en el registro:
  - Ruta: `HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties`
  - Comprobar `MSISupported = 1` y `MessageNumberLimit` en:
    - GPU (NVIDIA, AMD Radeon, Intel Arc)
    - Controladores de Almacenamiento NVMe / AHCI SATA
    - Controladores de Red Ethernet / Wi-Fi (Realtek, Intel, MediaTek)
    - Controladores de Bus USB (xHCI Host Controller)
    - Controladores de Audio HD / USB Audio

### Fase 2: Auditoría de Temporización de Kernel y BCD
- Lectura de `NtQueryTimerResolution`:
  - `MinimumResolution` (típicamente 156,250 unidades de 100ns = 15.625 ms)
  - `MaximumResolution` (típicamente 5,000 unidades de 100ns = 0.5 ms)
  - `CurrentResolution` (estado actual)
- Inspección de directivas BCD:
  - Comprobación de que no se fuerce `useplatformclock = Yes` (HPET lento en bus de placa base, causante de micro-stuttering en CPUs modernas).
  - Verificación de que el procesador utilice el TSC invariante de hardware (RDTSC con frecuencia fija independiente de P-states).

### Fase 3: Muestreo de Latencia DPC/ISR y Telemetría de Controladores
- Muestreo calibrado de latencia de interrupción utilizando la base de `Trace-SystemLatency.ps1`.
- Identificación de los 5 controladores de kernel con mayor tiempo acumulado de procesamiento.
- Clasificación de estado de latencia:
  - **EXCELENTE**: Picos < 300 µs (Apto para 240Hz+ / Audio Pro ASIO < 64 samples).
  - **BUENO / SEGURO**: Picos entre 300 µs y 500 µs (Apto para 144Hz - 165Hz).
  - **ADVERTENCIA**: Picos entre 500 µs y 1000 µs (Riesgo de micro-stuttering en cargas pesadas).
  - **CRÍTICO / DEFICIENTE**: Picos > 1000 µs (Desincronización de audio / caídas de cuadros).

### Fase 4: Generación del Dashboard Visual Interactivo
- Crear `AUDITORIA_LATENCIA_KERNEL_2026.html`:
  - Diseño Dark Mode premium con sistema de diseño unificado.
  - KPIs: Latencia DPC Máxima, Resolución de Timer Actual, % Dispositivos en Modo MSI, Dispositivos en Core 0.
  - Tabla interactiva de dispositivos PCIe auditados con estado MSI, IRQ asignada y recomendación de prioridad.
  - Matriz de compatibilidad por tasa de refresco (144Hz, 240Hz, 360Hz, 500Hz).

### Fase 5: Integración Ecosistémica y Pruebas
- Crear `scripts/Testing/Test-KernelLatencyAndTopology.ps1` y su lanzador `.cmd` sin BOM.
- Integración en `Invoke-TestSuite.ps1`.
- Validación estricta en Windows PowerShell 5.1 con UTF-8 BOM y cero fallos silenciosos (CWE-390).

---

## 4. Archivos Afectados / Creados

| Tipo | Archivo | Propósito |
| :--- | :--- | :--- |
| **Nuevo** | `scripts/Core/Test-MsiInterruptTopology.ps1` | Auditor de interrupciones PCIe MSI vs Line-Based y saturación de CPU 0 |
| **Nuevo** | `scripts/Core/Test-KernelTimerResolution.ps1` | Auditor de resolución de temporizador del kernel y parámetros BCD |
| **Nuevo** | `scripts/Testing/Test-KernelLatencyAndTopology.ps1` | Batería unificada de pruebas de latencia de kernel y topología |
| **Nuevo** | `scripts/Testing/Test-KernelLatencyAndTopology.cmd` | Lanzador batch sin BOM para pruebas de latencia |
| **Nuevo** | `AUDITORIA_LATENCIA_KERNEL_2026.html` | Tablero visual interactivo de certificación de latencia y micro-stuttering |
| **Modificación** | `scripts/Testing/Invoke-TestSuite.ps1` | Incorporación de fase de auditoría de latencia de kernel |
| **Modificación** | `docs/plans/README.md` | Registro de PLAN-0097 en el índice canónico |

---

## 5. Criterios de Aceptación y Validación

1. **Topología MSI**: Detección y reporte del 100% de dispositivos PCIe críticos (GPU, NVMe, Red, USB, Audio).
2. **Resolución de Timer**: Comprobación con precisión sub-microsegundo mediante `NtQueryTimerResolution` sin dependencias externas.
3. **Resiliencia de Código**: 100% de scripts con codificación UTF-8 BOM, cero bloques catch vacíos (CWE-390) y 0 errores AST en Windows PowerShell 5.1.
4. **Test Harness**: 100% PASS en la suite completa de `Invoke-TestSuite.ps1`, certificado mediante `grep_search` en el log físico.
