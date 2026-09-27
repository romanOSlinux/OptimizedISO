# PLAN-0128: Auditoría y Validación en Vivo del Lote 2 - Sensores de Hardware y Telemetría

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0128 |
| **Fecha** | 2026-09-27 |
| **Componentes** | `scripts/Modules/Monitor-ThermalEnergy.ps1`, `scripts/Modules/Trace-SystemLatency.ps1`, `scripts/Modules/PostInstall-Diagnostics.ps1`, `scripts/Modules/Audit-SystemOptimization.ps1` |
| **Estado** | `PENDIENTE` |
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

- [ ] **Fase 1: Auditoría Estática AST y BOM (Regla 4):**
  - Certificar codificación UTF-8 con BOM en los 4 scripts `.ps1` y formato No-BOM en sus lanzadores `.cmd`.
  - Auditar que ningún bloque `catch` silencie excepciones (CWE-390).
- [ ] **Fase 2: Validación en Vivo de S0ix y Wake Timers en el Host:**
  - Ejecutar `Get-RomanOSWakeTimerStatus` sin privilegios elevados.
  - Verificar que detecte los dispositivos de red armados (Realtek PCIe 2.5GbE) y emita advertencia sin colapsar.
  - Probar `Disable-RomanOSParasiticWakeTimers -WhatIf` garantizando cero modificaciones al host.
- [ ] **Fase 3: Muestreo de Latencia de Kernel (DPC/ISR Profiling):**
  - Ejecutar `Trace-SystemLatency -SamplingSeconds 3 -SkipElevation`.
  - Validar el fallback seguro a contadores de rendimiento en espacio de usuario cuando la sesión ETW requiera permisos de administrador.
- [ ] **Fase 4: Generación de Diagnósticos Resilientes:**
  - Ejecutar `PostInstall-Diagnostics.ps1 -SkipElevation -WhatIf` y comprobar la creación de registros forenses en `Log/`.
- [ ] **Fase 5: Certificación y Reporte de Métricas del Lote 2:**
  - Actualizar estado a `COMPLETADO`.
