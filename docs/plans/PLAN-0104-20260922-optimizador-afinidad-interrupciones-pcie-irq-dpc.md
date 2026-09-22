# PLAN-0104: Optimizador de Afinidad de Interrupciones PCIe, Prioridad IRQ y DPC Steering en Vivo

**Fecha:** 2026-09-22  
**Estado:** COMPLETADO  
**Autor:** Antigravity / romanOS Software Engineering  
**Alcance:** Ecosistema Completo (Core, Modules, GUI Control Center, Toolkit Maestro, ISO Builder, $OEM$, Testing Harness)

---

## 1. Contexto y Justificación Técnica

En sistemas Windows 10 y Windows 11 (incluyendo 24H2 y 25H2), la gestión de interrupciones de hardware PCIe por omisión adolece de un cuello de botella arquitectónico crítico:
1. **Saturación del Núcleo 0 (Core 0 Bottleneck):** Por defecto, la política de interrupciones de Windows (`IrqPolicyMachineDefault = 0x0`) canaliza la gran mayoría de interrupciones de hardware y rutinas de llamada diferida (DPCs - *Deferred Procedure Calls*) de la GPU y la tarjeta de red hacia el **Núcleo Lógico 0**. Dado que el Núcleo 0 ya gestiona las interrupciones del temporizador del sistema, llamadas a kernel y planificación de hilos de Windows, se producen picos de latencia DPC (*DPC latency spikes* > 1000 µs), lo que se traduce directamente en **micro-stuttering**, caídas repentinas de fotogramas mínimos (1% y 0.1% Lows) y retardo de entrada (*input lag*) en videojuegos competitivos y estaciones de trabajo de audio/video.
2. **Prioridad IRQ Indiscriminada:** Windows asigna prioridad `Normal` (`DevicePriority = 2`) de manera uniforme tanto a la GPU y a los discos NVMe como a periféricos secundarios (audio integrado, controladores USB lentos), provocando contención en las colas de despacho del subsistema HAL de interrupciones.
3. **Controladores en Modo Line-Based Compartido:** Con frecuencia, tras actualizaciones de controladores o parches mensuales de Windows Update, ciertos dispositivos PCIe capaces de operar en modo **MSI (Message Signaled Interrupts)** quedan relegados a interrupciones basadas en líneas compartidas (IRQ 16, 17, etc.), multiplicando las colisiones de interrupción.

### Estado Actual en el Proyecto
El repositorio cuenta con [`scripts/Core/Test-MsiInterruptTopology.ps1`](file:///c:/OptimizedISO/scripts/Core/Test-MsiInterruptTopology.ps1) y [`scripts/Modules/Trace-SystemLatency.ps1`](file:///c:/OptimizedISO/scripts/Modules/Trace-SystemLatency.ps1), pero **ambos operan exclusivamente en modo de lectura/diagnóstico estático**. No existe en el ecosistema una herramienta ni opción de Toolkit que permita **calibrar, aplicar o balancear en caliente la afinidad de interrupciones ni la prioridad IRQ** de los dispositivos PCIe.

### Objetivo
Desarrollar el **romanOS PCIe Interrupt Affinity & IRQ/DPC Steering Optimizer** (`scripts/Modules/Optimize-InterruptAffinity.ps1` y `.cmd`), un módulo nativo, desacoplado y 100% seguro (Anti-Cheat Safe, sin controladores vulnerables BYOVD ni reinicios obligatorios) que auto-detecta la GPU, unidades NVMe y adaptadores de red físicos para:
* Garantizar modo MSI (`MSISupported = 1`).
* Asignar prioridad `High` (`DevicePriority = 3`) a GPU y almacenamiento NVMe.
* Aplicar directivas de afinidad DPC (`DevicePolicy = 0x5` / `SpreadMessagesAcrossAllProcessors` o exclusión del Núcleo 0) para balancear el procesamiento en núcleos de alto rendimiento (P-Cores en Intel o CCD 3D V-Cache en AMD Ryzen).
* Permitir reversión atómica a valores de fábrica (`-Action Reset`) e integración directa en el Toolkit Maestro y Control Center.

---

## 2. Arquitectura de Interrupt & DPC Steering

```
                       ┌────────────────────────────────────────────────────────┐
                       │   romanOS PCIe Interrupt Affinity & Steering Optimizer │
                       │           (Optimize-InterruptAffinity.ps1)             │
                       └───────────────────────────┬────────────────────────────┘
                                                   │
                            ┌──────────────────────┴──────────────────────┐
                            ▼                                             ▼
                 [Hardware-Engine.ps1]                         [Manage-SystemSnapshots.ps1]
                 • Introspección CPU (P/E Cores)               • Snapshot Transaccional Previo
                 • Detección GPU / NVMe / NIC                  • Integridad Criptográfica SHA-256
                 • Lectura de Claves Enum\PCI                  • Reversión Determinista 1-Clic
                            │                                             │
      ┌─────────────────────┴─────────────────────────────────────────────┴─────────────────────┐
      ▼                                             ▼                                           ▼
[Modo Status / Auditoría]                [Modo Calibración Gaming / Pro]              [Modo Reset / Rollback]
• Inspección MSI (MSISupported)          • GPU & NVMe: DevicePriority = High (3)      • Restaurar DevicePriority = 2
• Inspección DevicePriority              • NIC: DevicePriority = Normal (2)           • Restaurar DevicePolicy = 0
• Inspección DevicePolicy                • DevicePolicy = 0x5 (Spread Across CPUs)    • Eliminar AssignmentSetOverride
• Lectura de AssignmentSetOverride       • DPC Steering: Excluir Núcleo 0             • Limpieza de subclave Affinity
```

### Especificación de Claves de Registro (Microsoft Windows Hardware Dev Center)
Para cada dispositivo crítico en `HKLM\SYSTEM\CurrentControlSet\Enum\PCI\<DeviceInstanceID>\Device Parameters\Interrupt Management`:
1. **Subclave `MessageSignaledInterruptProperties`:**
   - `MSISupported` (REG_DWORD): `1` (Habilitado).
   - `MessageNumberLimit` (REG_DWORD): Límite seguro según capacidad del dispositivo.
2. **Subclave `Affinity Policy`:**
   - `DevicePriority` (REG_DWORD):
     - `3` = High (GPU primaria y controladoras de almacenamiento NVMe).
     - `2` = Normal (Adaptadores de red Ethernet/Wi-Fi).
     - `1` = Low (Controladores auxiliares).
   - `DevicePolicy` (REG_DWORD):
     - `0x0` = `IrqPolicyMachineDefault` (Predeterminado de Windows).
     - `0x4` = `IrqPolicySpecifiedProcessors` (Afinidad manual a máscara de núcleos específicos).
     - `0x5` = `IrqPolicySpreadMessagesAcrossAllProcessors` (Distribución balanceada de colas MSI-X entre todos los procesadores asignables, descongestionando el Núcleo 0).
   - `AssignmentSetOverride` (REG_BINARY): Máscara de afinidad de CPU para aislar DPCs de la GPU fuera del Núcleo 0 (ej. bits `0xFFFFFFFE` en sistema de 32 hilos, o máscara específica de P-Cores / CCD 3D V-Cache).

---

## 3. Plan de Archivos y Modificaciones

### Nuevos Archivos
1. **Script Orquestador:**
   `scripts/Modules/Optimize-InterruptAffinity.ps1`
   - Parámetros CLI:
     - `-Action [Status|Audit|Optimize|Reset]`
     - `-TargetDevices [All|GPU|Storage|Network]`
     - `-AffinityStrategy [SpreadAcrossCPUs|ExcludeCoreZero|AutoDetectTopology]`
     - `-SkipSnapshot` (omite la creación preventiva de snapshot)
     - `-LogDir <Path>`
     - `-Unattended`
     - `-WhatIf`
     - `-SkipElevation`
2. **Lanzador Win32:**
   `scripts/Modules/Optimize-InterruptAffinity.cmd` (Codificación estricta ANSI / No-BOM, elevación UAC, flag `-STA`).
3. **Arnés de Pruebas Unitarias:**
   `scripts/Testing/Test-InterruptAffinity.ps1` y `Test-InterruptAffinity.cmd` (13+ aserciones unitarias: archivos, BOM UTF-8, AST PS 5.1, introspección de hardware, cálculo de máscaras binarias, simulación `-WhatIf` y sincronización).

### Modificaciones en el Ecosistema (*Cascading SSOT*)
1. **romanOS Toolkit Maestro (`scripts/Modules/romanOS-Toolkit.ps1`):**
   - Incorporar opción 23 en el menú interactivo principal y en Acciones Rápidas:
     `[23] Calibrador de Afinidad PCIe e Interrupciones IRQ (DPC Steering & MSI Tuning)`
   - Desplazar opción de Control Center a la 24.
   - Añadir soporte CLI: `-Module InterruptAffinity`, `-OptimizeAffinity`, `-AffinityAction`.
2. **romanOS Control Center (`scripts/GUI/romanOS-ControlCenter.ps1`):**
   - Incorporar tarjeta XAML en la pestaña *Drivers & Herramientas* (o *Gaming & Bimodal*):
     - Indicador de Estado de Interrupciones (MSI Status, GPU Priority, Affinity Policy).
     - Botón `btnAuditAffinityGUI` ("Auditar Afinidad e Interrupciones PCIe").
     - Botón `btnOptimizeAffinityGUI` ("Optimizar Afinidad PCIe e IRQ (1-Clic)").
     - Botón `btnResetAffinityGUI` ("Restaurar Valores de Fábrica").
   - Conectar event handlers con streaming asíncrono en consola a 60 FPS.
3. **Compilador de ISOs (`scripts/Builder/New-OptimizedWindowsISO-v2.ps1`):**
   - Inyección física en `$OEM$\$$\Setup\Scripts\Modules` y en el WIM montado offline (`$wimModulesDest`).
4. **Orquestador Maestro de Pruebas (`scripts/Testing/Invoke-TestSuite.ps1`):**
   - Incorporar como **Fase 14 permanente**:
     `Fase 14: Auditoría de Afinidad de Interrupciones PCIe y DPC Steering (PLAN-0104)`.
   - Desplazar Test Harness a Fase 15 (cuando no sea Quick).
   - Actualizar contador total de pasos a 14/15.
5. **Documentación Técnica (*Docs-as-Code*):**
   - Actualizar `docs/plans/README.md`.
   - Actualizar `README.md` (añadir fila en tabla de herramientas).
   - Actualizar `docs/GUIA_DE_EJECUCION_Y_COMANDOS.md` (Sección 19).
   - Actualizar `MEMORY.md` y `walkthrough.md`.

---

## 4. Criterios de Aceptación y Validación Rigurosa

- [x] Codificación UTF-8 con BOM obligatoria en todos los archivos `.ps1` y ANSI No-BOM en `.cmd` (Regla 4).
- [x] Ejecución en frío verificada en Windows PowerShell 5.1 (`powershell.exe -STA -NoProfile`).
- [x] Cero fallos silenciosos (CWE-390 / Fail-Visible): Telemetría clara si un dispositivo no soporta MSI o si el acceso al registro requiere elevación.
- [x] Soporte estricto de `-WhatIf` en todas las acciones modificatorias (`Optimize`, `Reset`).
- [x] Generación automática de instantánea de seguridad previa vía `Manage-SystemSnapshots.ps1`.
- [x] 100% de aserciones aprobadas en `Test-InterruptAffinity.ps1` (14/14 PASS).
- [x] 14/14 fases aprobadas en `Invoke-TestSuite.ps1 -Quick`.
- [x] Parada obligatoria tras la redacción del plan en espera de confirmación explícita del usuario (Regla 8 - Plan aprobado por el usuario).
