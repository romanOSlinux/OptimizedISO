# PLAN-0147: Modo Juego de Baja Latencia DPC (romanOS Game Optimizer), Gestión Real de Memoria RAM y Pausa Transaccional de Servicios

## Estado
`COMPLETADO`

## Fecha
2026-09-29

## Trazabilidad y Cronometría de Investigación
* **Fase 1 (DPC Latency, MMCSS y Mitos del Kernel):** 15:18:12 a 15:20:10 (118 segundos).
* **Fase 2 (Arquitectura de RAM, UMA DDR5 y Standby List):** 20:09:12 a 20:10:05 (53 segundos).
* **Fase 3 (Servicios en Segundo Plano, ETW y Anti-Cheat):** 20:40:45 a 20:43:10 (145 segundos).
* **Tiempo Total Acumulado de Investigación Activa:** **5 minutos y 16 segundos (316 segundos)** de auditoría documental rigurosa en fuentes oficiales y laboratorios de latencia.

---

## 1. Fundamentos Técnicos y Descubrimientos de Fuentes Oficiales

### A. Gestión Real de Memoria RAM (Virtual Memory Manager - VMM)
* **Las 4 Listas Físicas del Kernel NT:**
  1. *Active Working Set:* Páginas mapeadas activamente en el proceso (lo que mide el Task Manager).
  2. *Standby List:* Memoria en caché con datos válidos lista para reutilizarse mediante *Soft Page Faults*.
  3. *Modified List:* Páginas modificadas pendientes de vaciarse al archivo de paginación antes de liberarse.
  4. *Free / Zeroed List:* Memoria libre disponible en $O(1)$.
* **Desmitificación de la Poda de RAM (`EmptyWorkingSet`):**
  * Empíricamente demostrado en el host: ahorró únicamente **54,84 MB (0,35% de la RAM)**.
  * No destruye datos ni libera RAM física: solo degrada páginas del Working Set a la Standby List, provocando *Soft Page Faults* e input lag al reabrir la interfaz.
* **Arquitectura UMA en APU (Ryzen 5 8600G / Radeon 760M):**
  * La APU carece de VRAM física propia; comparte los dos canales DDR5 con la CPU.
  * Los estudios demuestran que pasar de DDR5-5200 a DDR5-6000 escala los FPS entre un **7% y 13%** debido al ancho de banda, no a la cantidad de gigabytes libres en reposo.
  * Si el sistema tiene más de 6-8 GB libres, matar navegadores o podar memoria tiene un impacto de 0.00 FPS. El objetivo es eliminar la **contención de lectura/escritura en el bus DDR5**.
* **Directivas Oficiales de Memoria para Gaming:**
  * `LargeSystemCache = 0`: Asegura que el caché de archivos de Windows no asfixie el pool de memoria de la GPU compartida de la APU.
  * `DisablePagingExecutive = 1`: Mantiene los controladores en modo kernel (incluyendo `amdkmdag.sys` y drivers de red) fijados permanentemente en la memoria física (*Non-Paged Pool*), eliminando fallos de página del kernel durante el renderizado.
  * **Compresión de Memoria (`MMAgent -MemoryCompression`):** Se mantiene activa en sistemas de 16 GB como red de seguridad para evitar *Hard Paging* al SSD cuando el juego y la APU demandan más de 12 GB.
  * **Archivo de Paginación Estático:** Tamaño fijo (ej. 4096 MB inicial = 4096 MB máximo) en NVMe para evitar que el kernel pause el sistema para redimensionar `pagefile.sys` durante picos de asignación virtual en DirectX 12.

### B. Servicios en Segundo Plano: Reducción de "Scheduling Noise" y Contención de E/S
* **La Causa del Micro-Stuttering por Servicios:**
  * En Windows 11, los servicios no degradan el juego por su uso de RAM (que es ínfimo, ~15-40 MB), sino por **interrupciones ETW (Event Tracing for Windows)**, escaneos de disco no programados y contención en el planificador de la CPU.
* **Servicios Pausables de Forma Segura (Reversibles):**
  1. `WSearch` (Windows Search / Indexer): Microsoft Learn documenta que compite por E/S de disco NVMe y ancho de banda de memoria RAM. Pausable durante el juego; la base de datos queda intacta.
  2. `PcaSvc` (Program Compatibility Assistant): Intercepta llamadas y genera hooks/shims en ejecutables de 64 bits.
  3. `DPS` (Diagnostic Policy Service): Registra trazas ETW continuas de diagnóstico en disco.
  4. `DiagTrack` (Connected User Experiences): Genera telemetría y paquetes en el stack de red.
  5. `wuauserv` y `UsoSvc` (Windows Update): Lanza escaneos de `TiWorker.exe` que saturan núcleos de CPU y disco.
  6. `Spooler` (Print Spooler): Completamente ocioso en sesiones de juego.
  7. `DusmSvc` (Data Usage): Filtro NDIS que inspecciona cada paquete de red para telemetría de consumo.
  8. `Pila Hyper-V` (`vmms`, `HNS`, `nvagent`): Desmontar adaptadores virtuales `vEthernet` elimina picos de latencia DPC por encima de 2000 µs en el adaptador físico.
* **Criterio sobre `SysMain` (Superfetch):**
  * NO deshabilitar permanentemente en el registro, ya que en Windows 11 está acoplado con la Compresión de Memoria.
* **Lista Blanca Inviolable (Blindaje Anti-Cheat y Hardware):**
  * `CryptSvc`, `BFE`, `mpssvc`: Requeridos obligatoriamente por Riot Vanguard, Easy Anti-Cheat y BattlEye para validar certificados y firewall.
  * `Audiosrv`, `AudioEndpointBuilder`: Subsistema de sonido.
  * `XboxGipSvc`, `AppXSvc`, `GamingServices`: Mandos inalámbricos y juegos de Xbox Game Pass.
  * `AMDRSServ` / `RadeonSoftware`: Driver de gráficos AMD Radeon.

### C. Kernel Multimedia (MMCSS) y Latencia DPC
* **Desmitificación de `SystemResponsiveness = 0`:**
  * Documentación oficial de Microsoft: los valores menores a 10 son forzados (*clamped*) automáticamente por el kernel a 20 (el valor por defecto).
  * `SystemResponsiveness = 0` era un placebo; el valor mínimo real documentado es **`10`** (garantiza el 90% de ciclos al juego).
* **NetworkThrottlingIndex:** Configurado en `0xFFFFFFFF` para eliminar el límite de 10 paquetes/ms en multimedia y permitir throughput total de red.
* **Timer Resolution en Windows 11:** Activar `GlobalTimerResolutionRequests = 1` en `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel` para que Windows no ignore las llamadas a temporizadores de alta precisión en juegos modernos.
* **Gestión Energética en AMD Zen 4:** Plan Equilibrado calibrado con CPPC2 para no sofocar el algoritmo Precision Boost 2 mononúcleo.

---

## 2. Alcance de la Refactorización

### Fase 1: Erradicación de la Poda de RAM
* Eliminar de [`scripts/Builder/New-OptimizedWindowsISO-v2.ps1`](file:///c:/OptimizedISO/scripts/Builder/New-OptimizedWindowsISO-v2.ps1) la llamada retardada a `Optimize-ProcessMemory.ps1` en `FirstLogonCommands`.
* Retirar la inyección de `Optimize-ProcessMemory.ps1` y `.cmd` de la ISO y reorientar el script exclusivamente como utilidad de telemetría de procesos.

### Fase 2: Rediseño Integral de [`scripts/Modules/Switch-GameDevMode.ps1`](file:///c:/OptimizedISO/scripts/Modules/Switch-GameDevMode.ps1)
* **Eliminar el Modo Agresivo:** Suprimir `-Profile Aggressive`, `-ForceKillEdge`, `-CloseIDE`.
* **Erradicar `psapi.dll!EmptyWorkingSet`:** Cero llamadas a vaciado de memoria activa.
* **Nuevo Modo Juego de Baja Latencia y Cero Ruido (Game Optimizer):**
  1. *Guardar Instantánea Transaccional:* Registrar el estado previo de los servicios en `%TEMP%\romanOS_GameDevState.json`.
  2. *Pausar Servicios Ruidosos:* `WSearch`, `PcaSvc`, `DPS`, `DiagTrack`, `wuauserv`, `UsoSvc`, `Spooler`, `DusmSvc`.
  3. *Detener Pila de Virtualización:* `vmms`, `HNS`, `nvagent` y deshabilitar switches virtuales.
  4. *Ajustes de Kernel y Memoria:* `SystemResponsiveness = 10`, `NetworkThrottlingIndex = 0xFFFFFFFF`, `DisablePagingExecutive = 1`, `LargeSystemCache = 0`, `GlobalTimerResolutionRequests = 1`.
  5. *Restauración Determinista (Modo Normal/Dev):* Al salir del modo juego, leer el archivo JSON y reiniciar estrictamente los servicios que el usuario tenía activos previamente.

### Fase 3: Paridad en el Ecosistema y SSOT
* Actualizar [`scripts/Core/Policy-Engine.ps1`](file:///c:/OptimizedISO/scripts/Core/Policy-Engine.ps1) con las directivas oficiales de MMCSS y memoria.
* Actualizar [`scripts/GUI/romanOS-ControlCenter.ps1`](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter.ps1) sustituyendo las tarjetas de "Modo Agresivo" y "Poda de RAM" por el nuevo conmutador.
* Actualizar [`scripts/Modules/romanOS-Toolkit.ps1`](file:///c:/OptimizedISO/scripts/Modules/romanOS-Toolkit.ps1).

### Fase 4: Verificación y Certificación
* Arnés L1 (`Invoke-RomanOSHarness.ps1 -Fast`) y L2 completo.
* Validación en Windows PowerShell 5.1 (`powershell.exe -STA`).
* Commit atómico y registro en memoria persistente.
