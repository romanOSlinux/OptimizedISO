# PLAN-0103: Guardián Anti-Drift y Watchdog de Servicios de romanOS

**Fecha:** 2026-09-22  
**Estado:** COMPLETADO  
**Autor:** Antigravity / romanOS Software Engineering  
**Alcance:** Ecosistema Completo (Core, Modules, GUI Control Center, Toolkit Maestro, ISO Builder, $OEM$, Testing Harness)

---

## 1. Contexto y Justificación Técnica

En Windows 10 y Windows 11 (24H2 / 25H2), tras la instalación de actualizaciones acumulativas mensuales (LCUs), parches de seguridad, actualizaciones de drivers o reinstalación de aplicaciones, el sistema operativo sufre de forma inevitable el fenómeno conocido como **Configuration Drift** (Desvío de Configuración):
1. **Reactivación de Servicios Invasivos:** Servicios previamente deshabilitados por el usuario para maximizar el rendimiento y la privacidad (ej. `DiagTrack` / Telemetría conectada, `WSearch` / Indizador de búsqueda que satura discos NVMe, `dmwappushservice`, `MapsBroker`, `RetailDemo`) son restaurados silenciosamente por Windows Update a tipo de inicio `Automatic` o `Manual`.
2. **Reactivación de Tareas Programadas de Telemetría:** Tareas de *Customer Experience Improvement Program* (CEIP), Application Experience (`Microsoft Compatibility Appraiser`) y actualizadores de Edge son rehabilitadas automáticamente en el Programador de Tareas.
3. **Pérdida Silenciosa de Rendimiento:** El usuario experimenta micro-stuttering, mayor latencia de kernel (DPC/ISR) y degradación de fotogramas (1% Lows) sin comprender la causa raíz.

Si bien el proyecto cuenta con el auditor estático de colmenas offline (`Test-RegistryHiveDrift.ps1`) y el motor SSOT (`Policy-Engine.ps1`), **carece de un Guardián Activo y Watchdog en vivo** que opere sobre el sistema en caliente.

### Objetivo
Construir el **romanOS Anti-Drift Guardian & Service Watchdog**, un módulo nativo, desacoplado y ultra-ligero (< 20 KB) que audita en segundos el estado real de los servicios y tareas programadas críticas frente al estándar SSOT de romanOS, reporta el porcentaje de salud/paridad del sistema y permite una **remediación atómica en 1-clic (`-Remediate`)** sin necesidad de reiniciar ni alterar archivos personales.

---

## 2. Arquitectura de romanOS Anti-Drift Guardian

```
                         ┌────────────────────────────────────────┐
                         │   romanOS Anti-Drift Guardian Watchdog │
                         │       (Watchdog-ServiceDrift.ps1)      │
                         └───────────────────┬────────────────────┘
                                             │
                               ┌─────────────┴─────────────┐
                               ▼                           ▼
                    [Policy-Engine.ps1 (SSOT)]   [Subsistema de Servicios Win32]
                    • Catálogo de Directivas     • Get-Service / sc.exe config
                    • Servicios de Telemetría    • Programador de Tareas (schtasks)
                    • Tareas Programadas CEIP    • Claves Start de Servicios HKLM
                               │                           │
       ┌───────────────────────┴───────────────────────────┴───────────────────────┐
       ▼                                   ▼                                       ▼
 [Modo Status / Auditoría]           [Modo Remediación Atómica]              [Watchdog Tarea Programada]
 • Telemetría de Servicios           • sc.exe config <Svc> start=disabled    • Auditoría periódica silenciosa
 • Detección de Desvíos (Drift)      • Disable-ScheduledTask preventiva      • Alerta visible si Drift > 10%
 • Cálculo de Paridad (% Salud)      • Restauración instantánea de paridad   • Registro forense en Log\
```

### Componentes Clave:
1. **Script Orquestador:**
   `scripts/Modules/Watchdog-ServiceDrift.ps1` y `Watchdog-ServiceDrift.cmd`
   - Parámetros CLI:
     - `-Action [Audit|Remediate|RegisterTask|UnregisterTask|Status]`
     - `-Target [Services|ScheduledTasks|Policies|All]`
     - `-LogDir <Path>`
     - `-Unattended`
     - `-WhatIf`
     - `-SkipElevation`
2. **Métricas Evaluadas por el Guardián:**
   - Servicios de Telemetría y Bloatware (`DiagTrack`, `dmwappushservice`, `RetailDemo`, `MapsBroker`, etc.).
   - Tareas programadas invasivas (`\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser`, `ProgramDataUpdater`, etc.).
   - Paridad de directivas de privacidad de navegador y telemetría de Windows.
3. **Integración con romanOS Control Center (WPF XAML):**
   - Nueva tarjeta en la pestaña "Mantenimiento" con indicador de Paridad del Sistema (% de Salud Anti-Drift), botón "Auditar Desvío" y botón "Remediar Desvío (1-Clic)" con streaming asíncrono en vivo a 60 FPS.
4. **Integración con romanOS Toolkit Maestro:**
   - Opción 22 en el menú interactivo principal y soporte CLI `-Module Watchdog` / `-AntiDrift`.
5. **Inyección en Despliegue e ISO:**
   - `$OEM$\$$\Setup\Scripts\Modules` y WIM montado offline (`$wimModulesDest`).
6. **Suite de Pruebas Unitarias:**
   - `scripts/Testing/Test-WatchdogServiceDrift.ps1` y `.cmd` (Fase 13 permanente en `Invoke-TestSuite.ps1`).

---

## 3. Plan de Archivos y Modificaciones

### Nuevos Archivos
1. `scripts/Modules/Watchdog-ServiceDrift.ps1`: Motor de auditoría y remediación de desvíos.
2. `scripts/Modules/Watchdog-ServiceDrift.cmd`: Lanzador Win32 nativo (No-BOM, UAC, STA).
3. `scripts/Testing/Test-WatchdogServiceDrift.ps1` y `.cmd`: Arnés de pruebas unitarias.

### Modificaciones en el Ecosistema
1. `scripts/GUI/romanOS-ControlCenter.ps1`: Tarjeta interactiva de Watchdog en Mantenimiento.
2. `scripts/Modules/romanOS-Toolkit.ps1`: Opción interactiva 22 y soporte CLI `-Module Watchdog`.
3. `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`: Inyección física en $OEM$ y WIM offline.
4. `scripts/Testing/Invoke-TestSuite.ps1`: Integración de la Fase 13 permanente.
5. `README.md`, `docs/GUIA_DE_EJECUCION_Y_COMANDOS.md` y `MEMORY.md`: Documentación técnica integral.

---

## 4. Criterios de Aceptación y Validación

- [x] Sintaxis y codificación UTF-8 con BOM en todos los `.ps1` y ANSI No-BOM en `.cmd`.
- [x] Ejecución en frío verificada en Windows PowerShell 5.1 (`powershell.exe -STA -NoProfile`).
- [x] Cero fallos silenciosos (CWE-390 / Fail-Visible): Telemetría visible ante servicios no encontrados o permisos insuficientes.
- [x] Remediación atómica con soporte estricto de `-WhatIf`.
- [x] 100% de aserciones aprobadas en `Test-WatchdogServiceDrift.ps1`.
- [x] 13/13 fases aprobadas en `Invoke-TestSuite.ps1`.
