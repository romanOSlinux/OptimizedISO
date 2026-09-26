# PLAN-0116: Auditoría Forense y Modernización Script por Script al Estado del Arte Mundial (Windows 11 24H2 / 25H2)

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0116 |
| **Fecha** | 2026-09-26 |
| **Componentes** | Totalidad de los 54 scripts del repositorio (`scripts/Core/`, `scripts/Builder/`, `scripts/Modules/`, `scripts/GUI/`, `scripts/Host-Tools/`, `scripts/Desktop-Helpers/`, `scripts/Drivers/`) |
| **Estado** | `EN PROGRESO` |
| **Prioridad** | Máxima / Constitucional (Erradicación Total de Deuda Técnica Legacy, Placebos y Mitos de Optimización; Elevación a Vanguardia Mundial) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM / PS 5.1), Regla 5 (Planes), Regla 7 (Watchdogs), Regla 8 (Modo Autónomo Continuo), Regla 9 (SSOT Policy-Engine), Regla 10 (Cascada Docs-as-Code), Regla 11 (Ingeniero Autónomo), Regla 13 (Auditoría Holística Whole-Repository), Regla 14 (Salvaguarda de Almacenamiento y Mocks Multi-Hardware), Regla 15 (Memoria Jerárquica y Map-Reduce) |

---

## 1. Justificación Técnica y Objetivos

La auditoría forense del PLAN-0115 demostró empíricamente que aun cuando los tests automatizados aprueban el 100% de la suite, existen residuos históricos procedentes de Windows 7, Windows 10 y mitos de internet (como `LargeSystemCache = 1`, `TcpAckFrequency = 1` forzado, y claves de servicios descontinuados como Cortana y Timeline) que deterioran el rendimiento en hardware moderno de 2026 (Zen 4/5, Intel Core Ultra, APUs con VRAM compartida UMA y fibra óptica gigabit).

El objetivo de este plan es someter los **54 scripts funcionales del proyecto** a una inspección microscópica individual, contrastándolos contra el estado del arte mundial (**AtlasOS v0.5**, **Sophia Script 24H2**, **Chris Titus Tech WinUtil** y documentación oficial de **Microsoft Learn** para Windows 11 24H2/25H2), modernizando el código y la interfaz gráfica al estándar más avanzado posible.

---

## 2. Metodología de Ejecución bajo la Regla 15 (Map-Reduce por Lotes)

Para evitar la saturación de contexto (*lost in the middle*) y la pérdida de atención del modelo, la auditoría se divide en 5 bloques de trabajo organizados en lotes acotados de **3 a 5 scripts**:

```
├── BLOQUE 1: Motores del Núcleo (scripts/Core/) - 12 scripts
│   ├── Lote 1: Hardware-Engine, Policy-Engine, Sysinternals-Helper, Test-AntiCheatCompatibility
│   ├── Lote 2: UI-Engine, WimLib-Helper, Test-KernelTimerResolution, Test-MsiInterruptTopology
│   └── Lote 3: Test-NetworkOffloadsAndRSS, Test-RegistryHiveDrift, Test-StorageStackBypassIO, Test-SupplyChainIntegrity
├── BLOQUE 2: Generador de ISO y Servicing (scripts/Builder/) - 3 scripts
│   └── Lote 4: New-OptimizedWindowsISO-v2, Get-WindowsUpdates, Get-EssentialRuntimes
├── BLOQUE 3: Módulos del Sistema y Optimización (scripts/Modules/) - 22 scripts
│   ├── Lote 5: Win11-Debloat-v3-Adaptive, Audit-FreshInstallFootprint, Audit-SystemOptimization
│   ├── Lote 6: Win11-Network-Diagnostics-Optimizer, Optimize-GamingAndApps, Optimize-ProcessMemory
│   ├── Lote 7: Invoke-WindowsSecurityHardening, Invoke-WindowsMaintenance, Desktop-Helpers
│   ├── Lote 8: Manage-SystemSnapshots, Switch-GameDevMode, Trace-SystemLatency, Watchdog-ServiceDrift
│   ├── Lote 9: Deploy-AppProfiles, Invoke-LiveSandbox, Optimize-InterruptAffinity, Optimize-WebBrowsers
│   └── Lote 10: Add-OptimizedContextMenus, Monitor-ThermalEnergy, PostInstall-Diagnostics, romanOS-Toolkit, Migrar-Usuario-W11
├── BLOQUE 4: Suite de Interfaz Gráfica (scripts/GUI/) - 2 scripts + C# Launchers
│   └── Lote 11: romanOS-ControlCenter.ps1 (Rediseño Fluent/Mica), romanOS-Studio.ps1 y lanzadores C#
└── BLOQUE 5: Herramientas Host, Helpers y Drivers (scripts/Host-Tools, Desktop-Helpers, Drivers) - 15 scripts
    ├── Lote 12: Desplegar-Setup-Host, Get-OfficialWindowsISO, Limpiar-ResiduosWinISO, Setup-AntigravityWindows, Test-CodeQuality
    ├── Lote 13: Backup-HardwareDrivers, Clean-DriverStore, Get-CriticalDrivers
    └── Lote 14: Suite Desktop-Helpers (Toggle-Defender, Toggle-WindowsUpdate, Toggle-VBS, etc.)
```

---

## 3. Ficha Técnica Forense Obligatoria por Cada Script

Por mandato constitucional de la Regla 15, cada script debe generar una ficha técnica detallada:
1. **Ruta y Versión:** Inspección del código físico actual.
2. **Reliquias / Mitos Detectados:** Identificación de directivas zombi, flags deprecados oplacebos (ej. `NtfsMemoryUsage = 2`, `LargeSystemCache = 1`, `TcpAckFrequency = 1`).
3. **Contraste contra Vanguardia Mundial:** Comparativa contra AtlasOS v0.5, Sophia Script y Microsoft Learn.
4. **Impacto en Hardware Moderno:** Evaluación en CPUs asimétricas (big.LITTLE, 3D V-Cache), APU UMA vs dGPU y SSD NVMe.
5. **Acciones de Refactorización:** Modificaciones aplicadas al código fuente.
6. **Validación Empírica:** Ejecución en frío en Windows PowerShell 5.1 (`powershell.exe -STA`), codificación UTF-8 con BOM y cero errores sintácticos AST.

---

## 4. Estado de Avance por Lotes

* [x] **Lote 1: Core 1** (`Hardware-Engine.ps1`, `Policy-Engine.ps1`, `Sysinternals-Helper.ps1`, `Test-AntiCheatCompatibility.ps1`) — COMPLETADO 2026-09-26
* [x] **Lote 2: Core 2** (`UI-Engine.ps1`, `WimLib-Helper.ps1`, `Test-KernelTimerResolution.ps1`, `Test-MsiInterruptTopology.ps1`) — COMPLETADO 2026-09-26
* [x] **Lote 3: Core 3** (`Test-NetworkOffloadsAndRSS.ps1`, `Test-RegistryHiveDrift.ps1`, `Test-StorageStackBypassIO.ps1`, `Test-SupplyChainIntegrity.ps1`) — COMPLETADO 2026-09-26
* [x] **Lote 4: Builder** (`New-OptimizedWindowsISO-v2.ps1`, `Get-WindowsUpdates.ps1`, `Get-EssentialRuntimes.ps1`) — COMPLETADO 2026-09-26
* [x] **Lote 5: Modules 1** (`Win11-Debloat-v3-Adaptive.ps1`, `Audit-FreshInstallFootprint.ps1`, `Audit-SystemOptimization.ps1`) — COMPLETADO 2026-09-26
* [x] **Lote 6: Modules 2** (`Win11-Network-Diagnostics-Optimizer.ps1`, `Optimize-GamingAndApps.ps1`, `Optimize-ProcessMemory.ps1`) — COMPLETADO 2026-09-26
* [x] **Lote 7: Modules 3** (`Invoke-WindowsSecurityHardening.ps1`, `Invoke-WindowsMaintenance.ps1`, `Desktop-Helpers.ps1`) — COMPLETADO 2026-09-26
* [x] **Lote 8: Modules 4** (`Manage-SystemSnapshots.ps1`, `Switch-GameDevMode.ps1`, `Trace-SystemLatency.ps1`, `Watchdog-ServiceDrift.ps1`) — COMPLETADO 2026-09-26
* [x] **Lote 9: Modules 5** (`Deploy-AppProfiles.ps1`, `Invoke-LiveSandbox.ps1`, `Optimize-InterruptAffinity.ps1`, `Optimize-WebBrowsers.ps1`) — COMPLETADO 2026-09-26
* [x] **Lote 10: Modules 6** (`Add-OptimizedContextMenus.ps1`, `Monitor-ThermalEnergy.ps1`, `PostInstall-Diagnostics.ps1`, `romanOS-Toolkit.ps1`, `Migrar-Usuario-W11.ps1`) — COMPLETADO 2026-09-26
* [x] **Lote 11: GUI Suite** (`romanOS-ControlCenter.ps1`, `romanOS-Studio.ps1`) — COMPLETADO 2026-09-26
* [x] **Lote 12: Host-Tools** (`Desplegar-Setup-Host.ps1`, `Get-OfficialWindowsISO.ps1`, `Limpiar-ResiduosWinISO.ps1`, `Setup-AntigravityWindows.ps1`, `Test-CodeQuality.ps1`) — COMPLETADO 2026-09-26
* [ ] **Lote 13: Drivers** (`Backup-HardwareDrivers.ps1`, `Clean-DriverStore.ps1`, `Get-CriticalDrivers.ps1`)
* [ ] **Lote 14: Desktop-Helpers** (`romanOS-Helpers-Menu.ps1`, `Toggle-Defender.ps1`, `Toggle-WindowsUpdate.ps1`, `Toggle-VBS-CoreIsolation.ps1`, `Toggle-Bluetooth.ps1`, `Toggle-FileSharing.ps1`, `Toggle-PowerPlan.ps1`)
