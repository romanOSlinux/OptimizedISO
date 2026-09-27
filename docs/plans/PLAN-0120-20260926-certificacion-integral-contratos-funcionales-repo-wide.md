# PLAN-0120: Certificación Integral de Contratos Funcionales y Mutación de Estado Repo-Wide (Behavioral & State Mutation Testing)

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0120 |
| **Fecha** | 2026-09-26 |
| **Componentes** | `scripts/Testing/Test-FunctionalContracts.ps1`, `scripts/Modules/*`, `scripts/Desktop-Helpers/*`, `scripts/Core/*`, `scripts/GUI/*`, `scripts/Builder/*`, `scripts/Drivers/*`, `Auditoria-Ecosistema.html`, `docs/plans/README.md` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Máxima (Erradicación Integral del Efecto Placebo en la UI y Validación de Mutación Física en SO) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM / PS 5.1), Regla 5 (Planes), Regla 7 (Watchdogs), Regla 8 (Modo Autónomo Continuo), Regla 9 (SSOT Policy-Engine), Regla 10 (Cascada Docs-as-Code), Regla 11 (Ingeniero Autónomo), Regla 13 (Auditoría Holística / CWE-390), Regla 14 (Salvaguarda de Almacenamiento y Mocks Aislados), Regla 15 (Memoria Jerárquica Map-Reduce) |

---

## 1. Visión y Justificación Técnica

### A. La Necesidad de Pruebas de Comportamiento Repo-Wide
Tras el éxito de **PLAN-0119** (que detectó omisiones reales de registro en Discord/Spotify y problemas de elevación UAC en `Optimize-GamingAndApps.ps1`), se establece como mandato de ingeniería extender este modelo de **Pruebas de Contrato Funcional (Arrange-Act-Assert)** a los componentes operacionales del repositorio `OptimizedISO`.

### B. Principio Fundamental: Validación por Mutación de Estado
A ningún script se le otorgará el veredicto de "Funcional" únicamente por compilar o tener código sintácticamente correcto. Para cada módulo se definirá:
1. **Promesa Funcional:** Qué dice el script o botón que hace.
2. **Arrange (Inyección de Estado Previo):** Configuración de un entorno donde el sistema está pre-optimizado, desconfigurado o sucio.
3. **Act (Ejecución Real/Simulada):** Invocación del script con los parámetros de producción (`-Unattended`, `-SkipElevation`, etc.).
4. **Assert (Comprobación de Mutación):** Verificación estricta de que el Registro (`HKCU`/`HKLM`), Sistema de Archivos, Políticas o Servicios mutaron al estado exacto prometido.
5. **Teardown (Limpieza):** Restauración de fixtures para garantizar cero daño al host ([Regla 14](file:///c:/OptimizedISO/.agents/AGENTS.md#L14)).

---

## 2. Plan de Ejecución por Lotes (Patrón Map-Reduce - Regla 15)

Para prevenir la saturación de contexto y garantizar rigor empírico, la certificación se divide en **7 Lotes Metodológicos (3 a 5 scripts por iteración)**:

- [x] **Lote 1: Modules — Gaming, Latencia y CPU (5 scripts) [COMPLETADO]**
  * `Optimize-GamingAndApps.ps1` (Ratificación completa VRAM/Electron/Shaders/WDDM — CTR-01..04).
  * `Switch-GameDevMode.ps1` (Conmutación de servicios y perfiles energéticos — CTR-08..09).
  * `Optimize-InterruptAffinity.ps1` (Aislamiento de Core 0 y prioridad IRQ — CTR-07).
  * `Trace-SystemLatency.ps1` (Recolección de telemetría DPC/ISR — CTR-10).
  * `Optimize-ProcessMemory.ps1` (Afinamiento y vaciado de WorkingSet — CTR-11).

- [x] **Lote 2: Modules — Navegadores, Menús y Seguridad (5 scripts) [COMPLETADO]**
  * `Optimize-WebBrowsers.ps1` (Políticas de navegadores Chromium/Firefox — CTR-12).
  * `Add-OptimizedContextMenus.ps1` (Inyección de CLSID clásico y menús en cascada con -LiteralPath — CTR-05).
  * `Invoke-WindowsSecurityHardening.ps1` (Reglas ASR, LSA PPL y Defender sin elevación — CTR-13).
  * `Manage-SystemSnapshots.ps1` (Creación de instantáneas y manifiesto SHA-256 — CTR-14).
  * `Invoke-WindowsMaintenance.ps1` (Saneamiento transaccional de shaders sin elevación — CTR-15).

- [x] **Lote 3: Modules — Red, Debloat y Supervisión (5 scripts) [COMPLETADO]**
  * `Win11-Network-Diagnostics-Optimizer.ps1` (Sondeo RTT y selección DNS — CTR-16).
  * `Win11-Debloat-v3-Adaptive.ps1` (Inventario solo-lectura y resiliencia sin UAC — CTR-17).
  * `Audit-SystemOptimization.ps1` (Auditoría universal de 10 dominios en Medium IL — CTR-18).
  * `Watchdog-ServiceDrift.ps1` (Cálculo de paridad SSOT anti-drift — CTR-19).
  * `PostInstall-Diagnostics.ps1` (Generación resiliente de informes sin elevación forzada — CTR-20).

- [x] **Lote 4: Desktop-Helpers — Conmutadores de Servicio (6 scripts) [COMPLETADO]**
  * `Toggle-Defender.ps1` (Activación / desactivación de servicios y directivas de Defender — CTR-22).
  * `Toggle-WindowsUpdate.ps1` (Pausa / restauración de Windows Update — CTR-21).
  * `Toggle-VBS-CoreIsolation.ps1` (Aislamiento del núcleo y VBS — CTR-23).
  * `Toggle-Bluetooth.ps1` (Gestión de servicios bthserv — CTR-24).
  * `Toggle-Printing.ps1` (Servicio Spooler y dependencias — CTR-25).
  * `Toggle-FileSharing.ps1` (SMBv1/LanmanServer — CTR-26).

- [x] **Lote 5: Core Engines & Orquestación (5 scripts) [COMPLETADO]**
  * `Policy-Engine.ps1` (Invariantes, exportación Unattend y catálogo SSOT — CTR-27).
  * `Hardware-Engine.ps1` (Detección dinámica de topología CPU/GPU/Almacenamiento y Mocks — CTR-28).
  * `Deploy-AppProfiles.ps1` (Instalador Winget desatendido y catálogo curado — CTR-29).
  * `Invoke-LiveSandbox.ps1` (Generación de configuraciones .wsb con aislamiento estricto — CTR-30).
  * `Migrar-Usuario-W11.ps1` (Migración y auditoría de cuentas locales sin bloqueo interactivo — CTR-31).

- [x] **Lote 6: Builder Pipeline & Drivers (5 scripts) [COMPLETADO]**
  * `New-OptimizedWindowsISO-v2.ps1` (Estructura de montaje, $OEM$, funciones AST y WIM — CTR-32).
  * `Get-WindowsUpdates.ps1` (Descarga y validación de SSUs/LCUs/SafeOS — CTR-33).
  * `Get-EssentialRuntimes.ps1` (Librerías C++ y DirectX para inyección offline — CTR-34).
  * `Get-CriticalDrivers.ps1` (Controladores de almacenamiento Intel VMD y VirtIO — CTR-35).
  * `Clean-DriverStore.ps1` (Depuración segura y simulación de DriverStore — CTR-36).

- [x] **Lote 7: GUIs, Conectores y Dashboard (3 componentes) [COMPLETADO]**
  * `romanOS-ControlCenter.ps1` (Integración de botones y paso de parámetros `-SkipElevation` / `-Unattended` — CTR-37, CTR-38).
  * `romanOS-Toolkit.ps1` (Paridad de opciones de menú CLI y soporte de pipeline — CTR-39).
  * Actualización de `Auditoria-Ecosistema.html` y matriz consolidada (866 aserciones al 100% PASS — CTR-40).

---

## 3. Criterios de Aceptación Cuantitativos

1. **Cero Placebos:** Cada contrato debe verificar que la acción produce un cambio observable en el estado del SO.
2. **Cero Fugas UAC:** Los scripts de usuario no deben bloquearse si se invocan en contextos estándar o desatendidos.
3. **Validación en PowerShell 5.1:** Todo nuevo fixture y prueba debe ejecutarse limpiamente en `powershell.exe`.
4. **100% PASS en Test-FunctionalContracts.ps1:** Registro incremental de aserciones en el harness consolidado.
