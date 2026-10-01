# PLAN-0150: Motor Polimórfico de Optimización de CPU Multi-Hardware y Arquitecturas de Silicio en romanOS Control Center

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0150 |
| **Fecha** | 2026-09-30 |
| **Componentes** | `scripts/Core/Hardware-Engine.ps1`, `scripts/Core/Policy-Engine.ps1`, `scripts/Modules/Optimize-CpuSilicon.ps1`, `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/Testing/Test-CpuSiliconTopologyMocks.ps1` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Máxima / Arquitectura (Multi-Hardware Obligatorio, Cero Placebos, Modelado Científico de Silicio) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM y PS 5.1), Regla 7 (Watchdog y Transparencia), Regla 9 (SSOT), Regla 11 (Autonomía Técnica), Regla 13 (CWE-390 / Fail-Visible), Regla 14 (Multi-Hardware y Mocks Sintéticos), Regla 15 (Map-Reduce y Persistencia Externa) |

---

## 1. Tabla de Parámetros de Reanudación y Checkpoints de Contexto

> **OBJETIVO DE RESILIENCIA:** Esta sección permite pausar la ejecución en cualquier momento por límite de contexto o consulta al usuario, y reanudar con precisión matemática en la fase y paso exactos sin perder estado ni requerir análisis redundantes.

| Parámetro de Estado | Valor Actual | Notas de Transición |
|---|---|---|
| **Fase Activa** | `COMPLETADO` | Plan ejecutado y certificado íntegramente |
| **Sub-Paso Actual** | `Cierre de Hito y Certificación` | Todos los objetivos empíricos alcanzados |
| **Checkpoints Completados** | `Fases 1, 2, 3, 4, 5 y 6 Completadas al 100%` | 19/19 Mocks PASS, 15/15 Fases CI PASS |
| **Persistencia MCP Memory** | `Entidades Registradas` | 6 arquitecturas persistidas en Knowledge Graph |
| **Punto de Reanudación Seguro** | `N/A - Hito Finalizado` | Commit b2d629d registrado |

---

## 2. Definición del Problema y Principio de Ingeniería

Los optimizadores convencionales cometen el error crítico de aplicar recetas estáticas a ciegas:
* En procesadores modernos (Zen 4 / Phoenix o Intel 12th+), forzar `PROCTHROTTLEMIN = 100%` elimina el margen térmico (*thermal headroom*) para mononúcleo, incrementa el calor en reposo y degrada la latencia.
* En procesadores con AMD 3D V-Cache dual-CCD (7900X3D/7950X3D), forzar `Core Unparking` al 100% destruye hasta el 25% del rendimiento en juegos porque los hilos se desvían al CCD secundario sin caché 3D.
* En procesadores Intel híbridos (P-Cores + E-Cores), forzar afinidades estáticas o alterar la cuanta de `Win32PrioritySeparation` ciega a *Intel Thread Director*.
* En APUs con gráficos integrados (Radeon 760M / Vega), forzar `LargeSystemCache = 1` asfixia la memoria RAM compartida UMA provocando caídas del controlador.
* En procesadores antiguos (Intel Haswell 4ta Gen / AMD Zen 1), la falta de tecnologías autónomas (como HWP o CPPC2 de 1 ms) requiere estrategias opuestas (P-states fijos para evitar los 30 ms de latencia por software ACPI).

**Principio Rector:** **Cero código cáscara y cero suposiciones.** Cada silicio tiene una respuesta de kernel única dictada por sus límites físicos (latencia de bus, topología de caché, gestión de estados P y tecnología de fabricación).

---

## 3. Taxonomía Exhaustiva de las 6 Familias de Silicio

1. **Arquetipo 1: Intel Heterogéneo Híbrido (12va–14va Gen & Core Ultra / Arrow Lake)**
   - P-Cores con HT + E-Cores sin HT + Intel Thread Director (ITD) vía EHFI.
   - *Ajuste:* Preservar ITD, `PowerThrottlingOff = 0` (selectivo), MMCSS al 90%, cero cuanta estática.
2. **Arquetipo 2: AMD Dual-CCD Asimétrico con 3D V-Cache (7900X3D, 7950X3D, 9950X3D)**
   - CCD0 (96 MB 3D V-Cache) + CCD1 (Frecuencia alta sin 3D V-Cache).
   - *Ajuste:* Core Parking al 50% obligatorio en juegos, prioridad absoluta al CCD con caché 3D vía AMD PPM.
3. **Arquetipo 3: AMD Monolítico Simétrico Moderno (Zen 3 / Zen 4 / Zen 5 estándar: 5600X, 5800X, 7600X, etc.)**
   - Single-CCX (8 núcleos), 32 MB L3 directa, CPPC v2 (*Preferred Cores*) autónomo cada 1 ms.
   - *Ajuste:* `PROCTHROTTLEMIN = 5%`, `EPP = 0–33`, C6 deep sleep habilitado para boost mononúcleo máximo (PB2).
4. **Arquetipo 4: AMD APU Monolítica con Memoria UMA (Phoenix 8000G, Renoir 4000G, Cezanne 5000G)**
   - CPU + iGPU compartiendo bus DDR4/DDR5.
   - *Ajuste:* `LargeSystemCache = 0` estricto, GPU MSI-X `SpreadAcrossCPUs (0x5)`, asignación de framebuffer fijo.
5. **Arquetipo 5: AMD Multi-CCX Temprano con Latencia Inter-Die (Zen 1 / Zen+: Ryzen 1600, 2600)**
   - 2 CCX separados por Infinity Fabric (140 ns de salto). Sin CPPC2 autónomo.
   - *Ajuste:* Contención de afinidad a un solo CCX para el proceso en primer plano, mitigación de latencia C6.
6. **Arquetipo 6: Intel Monolítico Clásico Pre-HWP (Intel 2da a 5ta Gen: Haswell i7-4770K, Sandy Bridge)**
   - Ring Bus monolítico sin Speed Shift (P-states por software ACPI con 30 ms de retardo).
   - *Ajuste:* `PROCTHROTTLEMIN = 100%` (Ultimate Performance clásico justificado para evitar caída de 1% lows), balanceo de mitigaciones Spectre/Meltdown.

---

## 4. Mapa Operacional de Implementación y Certificación

- [x] **Fase 1: Estudio de Silicio y Modelado Formal en Grafo de Conocimiento (MCP Memory):**
  - Registradas en MCP `memory` las 6 entidades de arquitectura de silicio con sus directivas de kernel asociadas.
  - Formalizados los vectores de configuración matemática por cada silicio.
- [x] **Fase 2: Arnés de Mocks Sintéticos Multi-Hardware (`Test-CpuSiliconTopologyMocks.ps1`):**
  - Diseñada la suite de pruebas unitarias que simula las 6 firmas WMI/CIM/CPUID en memoria (sin requerir hardware físico ajeno).
  - Certificadas aserciones de detección estricta (19/19 PASS) para: Haswell 4770K, Ryzen 1600, Ryzen 5600X, Phoenix 8600G, Ryzen 7950X3D e i7-13700K.
- [x] **Fase 3: Módulo Canónico de Despacho (`scripts/Modules/Optimize-CpuSilicon.ps1`):**
  - Implementada la función `Get-RomanOSCpuArchitecturePolicy` en `Hardware-Engine.ps1` y el módulo canónico `Optimize-CpuSilicon.ps1` con resolución polimórfica en 3 capas (Regla 14: Invariantes, Topología, Fallback).
  - Estandarización de logging y manejo Fail-Visible (Regla 13).
- [x] **Fase 4: Integración en Interfaz Gráfica (`scripts/GUI/romanOS-ControlCenter.ps1`):**
  - Añadido el botón `btnAdaptiveCpuOptimizer` en la sección *Thermal & Energy Profiler*.
  - Cableado el despachador en segundo plano con diálogo de telemetría y resultados específicos de la arquitectura detectada.
- [x] **Fase 5: Certificación Empírica Integral y Pruebas en Windows PowerShell 5.1:**
  - Ejecutada prueba en vivo en el host físico (AMD Ryzen 5 8600G) detectando `AMD_Monolithic_APU_UMA`.
  - Ejecutado el arnés sintético completo en `powershell.exe -STA -NoProfile` verificando 19/19 PASS, 0 errores AST y codificación UTF-8 con BOM.
- [x] **Fase 6: Registro en Git y Cierre de Hito:**
  - Commit atómico registrado con éxito (`b2d629d`) tras superar las 15 fases de pre-commit y certificar paridad total.
