# PLAN-0101: romanOS Thermal Throttling Monitor & Energy Profiler

**Fecha:** 2026-09-22  
**Estado:** COMPLETADO  
**Autor:** Antigravity / romanOS Software Engineering  
**Alcance:** Ecosistema Completo (Core, Modules, GUI Control Center, Toolkit Maestro, ISO Builder, $OEM$, Testing Harness)

---

## 1. Contexto y Justificación Técnica

En sistemas optimizados de alto rendimiento orientados a eSports, creación audiovisual e inferencia de Inteligencia Artificial local, los problemas de estabilidad y caídas de fotogramas (1% Lows y Micro-stuttering) provienen en un 80% de dos factores invisibles para el usuario:
1. **Estrangulamiento Térmico (Thermal Throttling):** La CPU o GPU alcanza la temperatura de unión crítica (*Tjunction*) y el regulador interno reduce drásticamente las frecuencias de reloj y los voltajes para evitar daños físicos.
2. **Estrangulamiento de Potencia y Eficiencia (Power Limit / Current Throttling):** En ordenadores portátiles y formatos compactos (mini-PCs, APUs), límites energéticos (PL1/PL2 en Intel, STAPM/EDC/TDC en AMD) provocan que los núcleos pasen repentinamente a frecuencias base, destruyendo el presupuesto de fotogramas (*Frame Budget*).

La mayoría de los usuarios recurre a utilidades de terceros pesadas con controladores vulnerables a exploits de kernel (BYOVD - *Bring Your Own Vulnerable Driver*), arriesgando la seguridad y la compatibilidad con sistemas anti-cheat (como Riot Vanguard, Easy Anti-Cheat o BattlEye).

### Objetivo
Construir una herramienta nativa, ligera (< 15 KB), desacoplada y 100% libre de drivers vulnerables para auditar el estado térmico, detectar eventos de throttling en tiempo real, calibrar perfiles de energía (AC vs Batería) y gestionar el estacionamiento de núcleos (*Core Parking*).

---

## 2. Arquitectura de romanOS Thermal & Energy Profiler

```
                            ┌────────────────────────────────────────┐
                            │    romanOS Thermal & Energy Engine     │
                            │      (Monitor-ThermalEnergy.ps1)       │
                            └──────────────────┬─────────────────────┘
                                               │
                                 ┌─────────────┴─────────────┐
                                 ▼                           ▼
                   [Hardware-Engine.ps1]       [Subsistema de Energía Win32]
                   • Sensores WMI/CIM          • powercfg / AC vs DC
                   • DMTF SMBIOS Thermal       • Core Parking (Affinity)
                   • Clasificación CPU/GPU     • C-States & Processor Boost
                                 │                           │
         ┌───────────────────────┴───────────────────────────┴───────────────────────┐
         ▼                                   ▼                                       ▼
   [Muestreo Térmico en Vivo]       [Calibrador Energético RUPA]            [Detección de Throttling]
   • Temp CPU (°C) & Margen TjMax   • Ultimate Performance Profile          • Eventos PROCHOT / HTC
   • Temp GPU & Memory Junction     • Unpark Cores (baja latencia)          • Registro forense en Log
   • Sensores de Placa Base ACPI    • Desacople en modo Batería             • Alerta visual en Control Center
```

### Componentes Clave:
1. **Script Orquestador:**
   `scripts/Modules/Monitor-ThermalEnergy.ps1` y `Monitor-ThermalEnergy.cmd`
   - Parámetros CLI:
     - `-Action [Monitor|Audit|CalibrateEnergy|UnparkCores|Status]`
     - `-SampleDurationSec <Int>` (por defecto 10s para diagnóstico rápido)
     - `-EnergyProfile [Ultimate|Balanced|LowLatencyGaming]`
     - `-Unattended`
     - `-WhatIf`
     - `-SkipElevation`
2. **Integración con romanOS Control Center (WPF XAML):**
   - Telemetría en tiempo real en la tarjeta de Información de Sistema (Dashboard) y en la pestaña Gaming & Bimodal.
   - Indicador visual de salud térmica (Verde: Óptimo, Amarillo: Precaución, Rojo: Throttling Activo).
3. **Integración con romanOS Toolkit Maestro:**
   - Opción interactiva dedicada y soporte CLI `-Module Thermal`.
4. **Inyección en Despliegue e ISO:**
   - `$OEM$\$$\Setup\Scripts\Modules` y WIM montado offline (`$wimModulesDest`).
5. **Suite de Pruebas Unitarias:**
   - `scripts/Testing/Test-ThermalEnergyMonitor.ps1` y `.cmd` (Fase 11 permanente en `Invoke-TestSuite.ps1`).

---

## 3. Plan de Archivos y Modificaciones

### Nuevos Archivos
1. `scripts/Modules/Monitor-ThermalEnergy.ps1`: Motor de muestreo térmico, detección de throttling y calibración energética.
2. `scripts/Modules/Monitor-ThermalEnergy.cmd`: Lanzador Win32 (No-BOM, UAC, STA).
3. `scripts/Testing/Test-ThermalEnergyMonitor.ps1` y `.cmd`: Arnés de pruebas unitarias.

### Modificaciones en el Ecosistema
1. `scripts/GUI/romanOS-ControlCenter.ps1`: Indicador térmico y botón de diagnóstico en Gaming / Dashboard.
2. `scripts/Modules/romanOS-Toolkit.ps1`: Opción interactiva en menú principal y CLI `-Module Thermal`.
3. `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`: Inyección en $OEM$ y WIM offline.
4. `scripts/Testing/Invoke-TestSuite.ps1`: Integración de la Fase 11 permanente.
5. `README.md` y guías de usuario: Documentación técnica completa.

---

## 4. Criterios de Aceptación y Validación

- [x] Sintaxis y codificación UTF-8 con BOM en todos los `.ps1` y ANSI No-BOM en `.cmd`.
- [x] Ejecución en frío verificada en Windows PowerShell 5.1 (`powershell.exe -STA -NoProfile`).
- [x] Cero fallos silenciosos (CWE-390): Detección resiliente con telemetría visible si los sensores ACPI del fabricante no exponen temperaturas por WMI genérico.
- [x] 100% de compatibilidad anti-cheat (cero drivers no firmados o kernel hooks invasivos).
- [x] 100% de aserciones aprobadas en `Test-ThermalEnergyMonitor.ps1` (12/12 PASS en 8.94s).
- [x] 11/11 fases aprobadas en `Invoke-TestSuite.ps1` (47.7s, 0 errores, 0 advertencias).
