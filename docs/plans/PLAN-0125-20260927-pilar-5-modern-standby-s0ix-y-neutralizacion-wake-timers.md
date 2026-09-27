# PLAN-0125: Pilar 5 - Calibración de Modern Standby (S0ix) y Neutralización de Wake Timers Parásitos de Telemetría

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0125 |
| **Fecha** | 2026-09-27 |
| **Componentes** | `scripts/Modules/Monitor-ThermalEnergy.ps1`, `scripts/Core/Policy-Engine.ps1`, `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/Testing/Test-FunctionalContracts.ps1` |
| **Estado** | `PENDIENTE` |
| **Prioridad** | Media (Autonomía de Batería en Laptops y Prevención de Encendido No Deseado) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM / PS 5.1), Regla 5 (Planes), Regla 7 (Watchdogs), Regla 8 (Modo Autónomo Continuo), Regla 9 (SSOT), Regla 14 (Salvaguarda de Almacenamiento) |

---

## 1. Visión y Justificación Técnica

### A. El Problema de Modern Standby en Windows 11
En equipos portátiles modernos con soporte S0ix (Connected/Modern Standby), tareas programadas de mantenimiento y telemetría configuran temporizadores de activación (`Wake Timers`) que encienden el procesador con la tapa cerrada, drenando la batería en transporte y generando calor excesivo.

### B. Solución de Ingeniería
1. **Auditoría de Activadores:** Inspeccionar `powercfg /waketimers` y `powercfg /devicequery wake_armed` desde `Monitor-ThermalEnergy.ps1`.
2. **Neutralización de Temporizadores Parásitos:** Aplicar directivas en `Policy-Engine.ps1` para deshabilitar los wake timers automáticos de telemetría de Windows Update, preservando únicamente eventos físicos de usuario.
3. **Control Center:** Proveer botón de auditoría y remediación energética en la pestaña Térmica/Energía.

---

## 2. Fases de Implementación

- [ ] **Fase 1:** Añadir módulo de auditoría de Wake Timers en `Monitor-ThermalEnergy.ps1`.
- [ ] **Fase 2:** Registrar directivas de deshabilitación de wake timers de telemetría en `Policy-Engine.ps1`.
- [ ] **Fase 3:** Integrar controles en `romanOS-ControlCenter.ps1`.
- [ ] **Fase 4:** Certificar contratos en `Test-FunctionalContracts.ps1` en PowerShell 5.1.
