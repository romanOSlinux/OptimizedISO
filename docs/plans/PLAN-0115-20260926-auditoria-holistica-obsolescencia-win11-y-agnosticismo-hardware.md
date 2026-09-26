# PLAN-0115: Auditoría Holística de Obsolescencia Windows 7/10 vs. Windows 11: Depuración de Claves Zombi, Blindaje de Reinicios, Erradicación de Mitos y Validación Multi-Hardware por Mocks

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0115 |
| **Fecha** | 2026-09-26 |
| **Componentes** | `scripts/Core/Policy-Engine.ps1`, `scripts/Core/Hardware-Engine.ps1`, `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`, `scripts/Modules/Win11-Debloat-v3-Adaptive.ps1`, `scripts/Modules/Win11-Network-Diagnostics-Optimizer.ps1`, `scripts/Modules/Audit-SystemOptimization.ps1`, `scripts/Modules/Audit-FreshInstallFootprint.ps1`, `scripts/Testing/Test-HardwareTopologyMocks.ps1`, `scripts/Testing/Test-OptimizedISO-v2.ps1` |
| **Estado** | `PENDIENTE` |
| **Prioridad** | Crítica (Saneamiento de Base Arquitectónica, Resiliencia en Destino, Agnosticismo Hardware y Blindaje contra Reinicios) |
| **Reglas Relevantes** | Regla 0 (Git), Regla 1 (Windows Host), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM / PS 5.1), Regla 5 (Planes), Regla 7 (Watchdog de Tareas), Regla 8 (Modo Autónomo de Avance Continuo), Regla 9 (SSOT Policy-Engine), Regla 10 (Mantenimiento en Cascada), Regla 11 (Ingeniero Autónomo), Regla 13 (Auditoría Holística Whole-Repository), Regla 14 (Salvaguarda de Almacenamiento, Agnosticismo Multi-Hardware y Mocks Sintéticos) |

---

## 1. Justificación Técnica y Diagnóstico de Causa Raíz

El reinicio no solicitado de Windows Update en el host de desarrollo reveló una **deuda técnica sistémica** que atraviesa transversalmente el repositorio: el arrastre de directivas, scripts y mitos de optimización procedentes de Windows 7 y Windows 10 que en **Windows 11 moderno (24H2 / Build 26200)** resultan inútiles, contraproducentes o son directamente eludidos por la nueva arquitectura del sistema operativo.

### A. Diagnóstico de Obsolescencia y Defectos Específicos
1. **Windows Update Bypasseado por Arquitectura de Microservicios:**
   * La combinación clásica `NoAutoRebootWithLoggedOnUsers = 1` y `AUOptions = 2` es ignorada por `MoUsoCoreWorker.exe` (Update Session Orchestrator) ante sesiones desatendidas/bloqueadas de madrugada.
   * *Solución requerida:* Implementar las directivas modernas de Windows 11 (`AlwaysAutoRebootAtScheduledTime = 0`, `AUPowerManagement = 0`, `SetAutoRestartNotificationConfig = 1`).
2. **Incoherencias Internas Críticas entre Scripts del Proyecto (Violación SSOT):**
   * [New-OptimizedWindowsISO-v2.ps1](file:///c:/OptimizedISO/scripts/Builder/New-OptimizedWindowsISO-v2.ps1#L5015) y [Policy-Engine.ps1](file:///c:/OptimizedISO/scripts/Core/Policy-Engine.ps1#L894) inyectan `LargeSystemCache = 1`.
   * En contraste directo, [Audit-SystemOptimization.ps1](file:///c:/OptimizedISO/scripts/Modules/Audit-SystemOptimization.ps1#L344) marca `LargeSystemCache = 1` como un `WARN / ERROR` crítico que roba memoria de trabajo a juegos y aplicaciones.
   * `LargeSystemCache = 1` es un tweak de la era **Windows NT 4.0 Server**. En estaciones de trabajo y particularmente en **APUs con arquitectura de memoria compartida (UMA)**, infla el caché del sistema de archivos y despoja de RAM física a la tarjeta gráfica integrada, provocando micro-stuttering y fallos de asignación en controladores de vídeo.
   * Discrepancia en `SystemResponsiveness`: Debloat lo fija en `10`, mientras Builder y Policy-Engine lo fijan en `0`.
3. **Claves Zombi de Componentes Inexistentes en Windows 11:**
   * `AllowCortana = 0` (Cortana fue descontinuada en 2023 y removida del sistema operativo).
   * `EnableActivityFeed = 0` (Timeline de Windows 10 fue eliminado en Windows 10 21H2).
   * `AllowNewsAndInterests = 0` en `HKLM\SOFTWARE\Policies\Microsoft\Dsh` (sustituido íntegramente por `AllowWidgets`).
4. **Mito de Red de 2005 Aplicado Ciegamente a Fibra Óptica:**
   * `TcpAckFrequency = 1` y `TcpNoDelay = 1` forzados globalmente en adaptadores de red ([Win11-Network-Diagnostics-Optimizer.ps1](file:///c:/OptimizedISO/scripts/Modules/Win11-Network-Diagnostics-Optimizer.ps1#L280)).
   * En redes modernas de banda ancha y fibra simétrica, desactivar el algoritmo de Nagle para cada paquete TCP entrante desencadena una tormenta masiva de interrupciones ACK, saturando la cola de la CPU y reduciendo el ancho de banda efectivo de 1 Gbps a 300 Mbps. Los juegos competitivos actuales utilizan UDP, por lo que este flag no reduce su latencia y en cambio degrada descargas masivas de Steam y streaming.
5. **Arquitectura No Adaptativa y Riesgo Multi-Hardware:**
   * La existencia de hardcodings que asumen hardware homogéneo pone en riesgo equipos con configuraciones mixtas (ej. máquinas con 2 NVMe y 1 HDD mecánico SATA, como el host de desarrollo, o procesadores Intel híbridos 12th-14th Gen P/E cores y AMD X3D).

---

## 2. Objetivos Principales de PLAN-0115

1. **Saneamiento Holístico de Claves Zombi e Incoherencias (Regla 13):**
   * Purgar del 100% de los scripts del repositorio las claves de componentes descontinuados (`AllowCortana`, `EnableActivityFeed`, `AllowNewsAndInterests` en Dsh).
   * Alinear canónicamente `LargeSystemCache = 0` en todo el proyecto (Workstation/Gaming seguro y protector de memoria en APU/UMA).
   * Alinear canónicamente `SystemResponsiveness = 0` como estándar del Policy-Engine para gaming.
   * Desactivar la imposición ciega de `TcpAckFrequency = 1` global y sustituirla por negociación basada en capacidades de hardware de la NIC (RSS, Checksum Offload, TCP Window Auto-Tuning).
2. **Blindaje Integral contra Reinicios en Windows 11:**
   * Incorporar al catálogo de [Policy-Engine.ps1](file:///c:/OptimizedISO/scripts/Core/Policy-Engine.ps1) y replicar en cascada a `New-OptimizedWindowsISO-v2.ps1`, `autounattend.xml`, `SetupComplete.cmd` y `PostInstall-Diagnostics.ps1` las directivas modernas de Windows Update.
3. **Estructuración en 3 Capas del Motor de Topología ([Hardware-Engine.ps1](file:///c:/OptimizedISO/scripts/Core/Hardware-Engine.ps1)) (Regla 14):**
   * *Capa 1 (Invariantes Universales):* Blindaje anti-cheat (`VulnerableDriverBlocklistEnable = 1`, `bam = 1`), blindaje de reinicios y bypasses OOBE.
   * *Capa 2 (Topología Dinámica):* Detección en caliente de CPU (heterogénea P/E vs simétrica vs X3D), GPU (APU/UMA vs dGPU discreta), Almacenamiento (volumen por volumen: NVMe vs HDD) y Red.
   * *Capa 3 (Fallback Seguro):* Repliegue a estándares seguros oficiales de Microsoft ante topologías desconocidas.
4. **Garantía Inviolable de Datos y Certificación por Mocks Sintéticos (Regla 14):**
   * Cero operaciones destructivas sobre medios físicos del host.
   * Creación de `scripts/Testing/Test-HardwareTopologyMocks.ps1` que valide en memoria el comportamiento del motor ante 4 topologías de laboratorio (Intel Híbrido, AMD X3D, dGPU vs APU, NVMe + HDD) con ejecución 100% exitosa en Windows PowerShell 5.1.

---

## 3. Plan de Implementación por Fases Detalladas

### Fase 1: Purgado de Claves Zombi y Saneamiento Transversal (Whole-Repository Scope)
* **Acción:**
  * Remover o depreciar formalmente en `Policy-Engine.ps1`, `New-OptimizedWindowsISO-v2.ps1`, `Win11-Debloat-v3-Adaptive.ps1`, `Audit-FreshInstallFootprint.ps1` y `Test-OptimizedISO-v2.ps1`:
    * `POL_SEARCH_CORTANA_ALLOW` / `AllowCortana`
    * `DEBLOAT_EnableActivityFeed` / `EnableActivityFeed`
    * `POL_WIDGETS_DSH` / `AllowNewsAndInterests` en `HKLM\SOFTWARE\Policies\Microsoft\Dsh` (preservando `AllowWidgets` en `HKLM\SOFTWARE\Policies\Microsoft\Widgets`).
* **Verificación:** `grep_search` en todo el repositorio para certificar cero residuos activos de las claves obsoletas.

### Fase 2: Corrección de Contradicciones Internas y Erradicación de Mitos de Rendimiento
* **Acción:**
  * **LargeSystemCache:**
    * Actualizar `Policy-Engine.ps1` ([L896](file:///c:/OptimizedISO/scripts/Core/Policy-Engine.ps1#L896)) para que `ExpectedValue = 0` (Workstation / Gaming / APU Safe).
    * Actualizar `New-OptimizedWindowsISO-v2.ps1` ([L5015](file:///c:/OptimizedISO/scripts/Builder/New-OptimizedWindowsISO-v2.ps1#L5015)) cambiando `/d 1` por `/d 0`.
    * Actualizar `Hardware-Engine.ps1` ([L1237](file:///c:/OptimizedISO/scripts/Core/Hardware-Engine.ps1#L1237)) garantizando que `LargeSystemCache = 0` se aplique transversalmente.
  * **SystemResponsiveness:**
    * Alinear `Win11-Debloat-v3-Adaptive.ps1` para que coincida con `Policy-Engine.ps1` (`ExpectedValue = 0`).
  * **Pila de Red TCP (TcpAckFrequency):**
    * Modificar `Win11-Network-Diagnostics-Optimizer.ps1` y `Win11-Debloat-v3-Adaptive.ps1` para eliminar la imposición forzada de `TcpAckFrequency = 1` y `TcpNoDelay = 1`.
    * Establecer la política de optimización en habilitar *TCP Window Auto-Tuning = normal*, *Receive Side Scaling (RSS) = enabled* y *Checksum Offload* en la NIC activa.

### Fase 3: Modernización y Blindaje Integral de Windows Update (USO Modern Stack)
* **Acción:**
  * Incorporar en [Policy-Engine.ps1](file:///c:/OptimizedISO/scripts/Core/Policy-Engine.ps1) las nuevas directivas de Windows 11:
    * `POL_WU_ALWAYS_AUTO_REBOOT` (`HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU` -> `AlwaysAutoRebootAtScheduledTime = 0`, REG_DWORD).
    * `POL_WU_POWER_MANAGEMENT` (`HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU` -> `AUPowerManagement = 0`, REG_DWORD).
    * `POL_WU_RESTART_NOTIF` (`HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` -> `SetAutoRestartNotificationConfig = 1`, REG_DWORD).
    * `POL_WU_RESTART_DISMISSAL` (`HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` -> `SetAutoRestartRequiredNotificationDismissal = 1`, REG_DWORD).
    * `POL_WU_ENGAGED_TRANSITION` (`HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` -> `SetEngagedRestartTransitionSchedule = 0`, REG_DWORD).
  * Replicar en cascada estas claves en `New-OptimizedWindowsISO-v2.ps1` (rutinas de registro WIM y SetupComplete) y en el validador `PostInstall-Diagnostics.ps1`.
  * Aplicar inmediatamente estas claves en el sistema host para blindarlo de futuros reinicios no autorizados.

### Fase 4: Refactorización en 3 Capas de Hardware-Engine.ps1 (Regla 14)
* **Acción:**
  * Estructurar el flujo de `Hardware-Engine.ps1` en:
    * **Capa 1 (Invariantes Universales):** Ratificación estricta de `VulnerableDriverBlocklistEnable = 1`, servicio `bam = 1`, bypasses OOBE y blindaje de Windows Update.
    * **Capa 2 (Topología Dinámica):**
      * Detección de CPU híbrida (Intel big.LITTLE) y AMD 3D V-Cache -> Protección de `Win32PrioritySeparation` (no forzar valores estáticos).
      * Detección de GPU APU/UMA vs dGPU dedicada -> Salvaguarda de RAM en APU (`LargeSystemCache = 0`).
      * Detección de Almacenamiento por unidad (`NVMe` vs `HDD SATA`) -> Preservar indexación y lectura secuencial en discos mecánicos.
    * **Capa 3 (Fallback Seguro):** Repliegue a valores por defecto de Microsoft ante fallos WMI o hardware desconocido.

### Fase 5: Arnés de Pruebas Unitarias de Topología mediante Mocks en Memoria
* **Acción:**
  * Crear `scripts/Testing/Test-HardwareTopologyMocks.ps1` (UTF-8 con BOM):
    * Test 1: Simulación de Intel Core i7-13700K (16C/24T, arquitectura híbrida). Verifica que el script detecte núcleos asimétricos y preserve `Win32PrioritySeparation`.
    * Test 2: Simulación de AMD Ryzen 9 7900X3D (Dual-CCD con 3D V-Cache). Verifica que el script respete el driver de AMD.
    * Test 3: Simulación de APU AMD Radeon 760M (UMA compartida) vs dGPU RTX 4080 (16GB VRAM dedicada). Verifica que en APU se fuerce `LargeSystemCache = 0`.
    * Test 4: Simulación de almacenamiento mixto (NVMe + HDD mecánico WD Blue). Verifica que las políticas de I/O se apliquen volumen por volumen.
  * Certificar ejecución limpia en frío contra `powershell.exe -STA`.

### Fase 6: Verificación de Cero Regresiones, Actualización Documental y Commit Atómico
* **Acción:**
  * Ejecutar suite de calidad de código `Test-CodeQuality.ps1`.
  * Ejecutar arnés de pruebas de la ISO `Test-OptimizedISO-v2.ps1`.
  * Actualizar `docs/plans/README.md` marcando PLAN-0115 como `COMPLETADO`.
  * Actualizar `MEMORY.md` y sincronizar observaciones en el servidor MCP `memory`.
  * Registrar commit atómico de cierre.

---

## 4. Criterios de Éxito Cuantificables

* [ ] Cero referencias a claves zombi (`AllowCortana`, `EnableActivityFeed`, `AllowNewsAndInterests` en Dsh) en todo el repositorio.
* [ ] 100% de coherencia en `LargeSystemCache = 0` entre Builder, Policy-Engine, Debloat y Auditoría.
* [ ] Pila de red liberada del mito destructivo de `TcpAckFrequency = 1` global.
* [ ] Set moderno de Windows 11 para Windows Update inyectado y activo en el host.
* [ ] `Hardware-Engine.ps1` modularizado en 3 capas (Invariantes, Dinámica, Fallback).
* [ ] Suite `Test-HardwareTopologyMocks.ps1` superada con 100% PASS en Windows PowerShell 5.1 sin requerir elevación de Hyper-V.
* [ ] Cero comandos destructivos sobre los discos del host físico (Regla 14.1 cumplida estrictamente).
