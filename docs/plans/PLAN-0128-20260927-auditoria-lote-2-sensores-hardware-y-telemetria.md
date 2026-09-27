# PLAN-0128: Auditoría y Validación en Vivo del Lote 2 - Sensores de Hardware y Telemetría

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0128 |
| **Fecha** | 2026-09-27 |
| **Componentes** | `scripts/Modules/Monitor-ThermalEnergy.ps1`, `scripts/Modules/Trace-SystemLatency.ps1`, `scripts/Modules/PostInstall-Diagnostics.ps1`, `scripts/Modules/Audit-SystemOptimization.ps1` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Alta (Observabilidad en Caliente y Diagnóstico Forense de Rendimiento) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM), Regla 12 (Log Forensics), Regla 13 (CWE-390 Fail-Visible), Regla 14 (Salvaguarda Host), Regla 15 (Map-Reduce Lote 2) |

---

## 1. Visión y Justificación Técnica

Los módulos de telemetría y diagnóstico operan directamente sobre los sensores del sistema operativo y del kernel:
- [`Monitor-ThermalEnergy.ps1`](file:///c:/OptimizedISO/scripts/Modules/Monitor-ThermalEnergy.ps1): Audita los estados de suspensión Modern Standby (S0ix), detecta temporizadores de reactivación activos (`powercfg /waketimers`) y clasifica dispositivos armados que drenan batería.
- [`Trace-SystemLatency.ps1`](file:///c:/OptimizedISO/scripts/Modules/Trace-SystemLatency.ps1): Toma muestras de latencia de kernel DPC/ISR mediante sesiones ETW o contadores de alto rendimiento multimedia para verificar presupuestos de frame (< 500 µs para gaming de 144Hz+).
- [`PostInstall-Diagnostics.ps1`](file:///c:/OptimizedISO/scripts/Modules/PostInstall-Diagnostics.ps1): Diagnóstico forense integral post-instalación generando reportes Markdown y HTML con paridad SSOT.
- [`Audit-SystemOptimization.ps1`](file:///c:/OptimizedISO/scripts/Modules/Audit-SystemOptimization.ps1): Auditoría repo-wide de servicios zombi, tareas programadas de telemetría y claves zombi de Windows 10 en Windows 11.

### Respaldo de Fuentes Oficiales
- **Microsoft Learn:** *Modern Standby Wake Sources and Power Management (`powercfg /devicequery wake_armed`).*
- **Microsoft Learn:** *Windows Performance Toolkit & Event Tracing for Windows (ETW) DPC/ISR Architecture.*
- **Microsoft Learn:** *Kernel Interrupt Handling & Deferred Procedure Calls (DPC).*

---

## 2. Fases de Implementación

- [x] **Fase 1: Auditoría Estática AST y BOM (Regla 4):**
  - Certificar codificación UTF-8 con BOM en los 4 scripts `.ps1` y formato No-BOM en sus lanzadores `.cmd`. (Creado `Audit-SystemOptimization.cmd` No-BOM estricto; 4/4 scripts .ps1 con BOM OK y 0 errores AST).
  - Auditar que ningún bloque `catch` silencie excepciones (CWE-390). (0 bloques catch vacíos en 22 scripts de `scripts/Modules/`).
- [x] **Fase 2: Validación en Vivo de S0ix y Wake Timers en el Host:**
  - Ejecutar `Get-RomanOSWakeTimerStatus` sin privilegios elevados (5 dispositivos armados clasificados, adaptador de red Realtek 2.5GbE alertado).
  - Probar `Disable-RomanOSParasiticWakeTimers -WhatIf` garantizando cero modificaciones al host (0 mutaciones, ActionsCount=0).
- [x] **Fase 3: Muestreo de Latencia de Kernel (DPC/ISR Profiling):**
  - Ejecutar `Trace-SystemLatency -SamplingSeconds 3 -SkipElevation` (1510 muestras recolectadas, resolución NtQueryTimerResolution 1.0ms, correlación con amdpsp.sys y stornvme.sys con código 0).
- [x] **Fase 4: Generación de Diagnósticos Resilientes:**
  - Ejecutar `PostInstall-Diagnostics.ps1 -OutputDir 'C:\OptimizedISO\Log' -PassThru -SkipElevation` (85 verificaciones aprobadas, 0 errores, reportes MD y HTML creados).
  - Ejecutar `Audit-SystemOptimization.ps1 -OutputDir 'C:\OptimizedISO\Log' -PassThru -SkipElevation` (94.4% de optimización, 29 directivas óptimas, 0 cuellos de botella).
- [x] **Fase 5: Certificación y Reporte de Métricas del Lote 2:**
  - Registrar CTR-47 en `Test-FunctionalContracts.ps1` y certificar suite completa (98/98 PASS, 100%, 0 errores y 0 excepciones en log físico). Estado: `COMPLETADO`.
