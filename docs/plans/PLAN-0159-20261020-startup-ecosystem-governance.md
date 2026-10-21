# PLAN-0159: Gobernanza Integral de Inicio, Optimización de Servicios a Demanda y Erradicación del Flagelo Post-Boot

**Estado:** COMPLETADO  
**Fecha:** 2026-10-20 (Completado: 2026-10-20)  
**Área:** Arquitectura Core, Servicios del Sistema, Autostart Governor, GUI Control Center, Pruebas  
**Autor:** Antigravity (Advanced Agentic Coding)

---

## 1. Contexto y Diagnóstico Forense (Cero Suposiciones)

Durante una sesión de usuario en un entorno Windows 11 24H2 recién iniciado, se detectó una actividad repentina no identificada que consumió aproximadamente 1 GB de RAM en el escritorio antes de cerrarse de forma abrupta.
La inspección forense matemática y no destructiva reveló la causa raíz y un conjunto de cuatro vectores concurrentes de sobrecarga:

1. **Tormenta de Mantenimiento Post-Boot de Componentes (CBS):**
   * El proceso `TiWorker.exe` y el servicio `TrustedInstaller` se ejecutaron desde las `22:05:49` hasta las `22:07:49` disparando `External EvaluateApplicability` sobre paquetes acumulativos de Windows (`Package_for_RollupFix`).
   * Durante dicha indexación, la carga del árbol de manifiestos WinSxS y la sección crítica `CSIInventoryCriticalSection` eleva la memoria entre 800 MB y 1.2 GB antes de finalizar con `SHUTDOWN_REASON_AUTOSTOP`.
2. **Servicios Nativos en Automático sin Clientes Activos:**
   * Servicios como `WSAIFabricSvc` (IA de Windows), `vmms` (Hyper-V VM Management), `CDPSvc` (Phone Link), `PcaSvc` (Asistente de Compatibilidad), `StiSvc` (WIA Escáneres), `DusmSvc` (Uso de Datos), `InventorySvc` (Telemetría de Aplicaciones), `DPS` y `LanmanServer` están en `Automatic (Start=2)`, consumiendo hilos y memoria sin justificación inmediata.
   * La auditoría empírica demostró que todos ellos cuentan con **0 dependientes activos** (`DependentServices = 0`).
3. **Contaminación de Inicio de Aplicaciones de Terceros (Autostart Bloat):**
   * Múltiples aplicaciones externas (`Steam` con `steamwebhelper.exe` [>850 MB], `ExitLag` [PID 844], software de periféricos `Patriot Viper V380` [~72 MB], hotkeys en segundo plano de `AMD Adrenalin` [`cncmd.exe`, `RSServCmd.exe`] y actualizadores de `Brave`) se cargan automáticamente en el arranque sin que el usuario esté jugando o usándolas.
4. **Instanciación Oculta de Chromium/WebView2 por Búsqueda Local:**
   * `SearchHost.exe` levantó 5 subprocesos de `msedgewebview2.exe` (~350 MB RAM) para renderizar feeds web de Bing dentro de la interfaz de búsqueda de Windows debido a directivas de búsqueda local incompletas.

---

## 2. Objetivos y Métricas Cuantificables

* **Ahorro de Memoria Inmediato:** Reducir entre **1.0 GB y 1.4 GB de RAM** en el escritorio en reposo tras el inicio de sesión.
* **Erradicación del Spike de CBS en Logon:** Reprogramar y diferir el mantenimiento automático de Windows para evitar picos de `TiWorker.exe` al iniciar sesión.
* **Preservación Incondicional de Funcionalidad:** Ninguna aplicación ni servicio pasará a `Disabled` de forma destructiva; se utilizará el modo **`Demand-Start` (`Manual`, Start=3)** para servicios y **desactivación de disparadores de autostart** para programas de terceros.
* **Reversibilidad Garantizada (1-Clic):** Integración nativa con `Manage-SystemSnapshots.ps1` para restauración previa y posterior.
* **Compatibilidad Estricta:** 100% compatible con Windows PowerShell 5.1 (`powershell.exe -STA`), codificación UTF-8 con BOM y sin fallos silenciosos (CWE-390).

---

## 3. Fundamentación Técnica y Fuentes Oficiales

1. **Arquitectura de Servicios Windows NT (Microsoft Learn):**
   * El estado `Manual` (`Demand-Start`, `Start=3`) instruye al Service Control Manager (SCM) a **no** instanciar el proceso al arranque del sistema. El servicio permanece en 0 bytes y 0 hilos hasta que una API o usuario lo invoque (`StartService`), eliminando la degradación del boot sin provocar excepciones de "Servicio Deshabilitado".
2. **Arquitectura de Mantenimiento Automático (Microsoft Learn):**
   * La directiva `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance: MaintenanceDisabled = 1` o la gestión de la ventana de mantenimiento evita la ejecución concurrente de `Maintenance Configurator` y `SvcRestartTaskLogon` en el inicio de sesión del usuario.
3. **Aislamiento WDDM de Controladores Gráficos (Microsoft Learn):**
   * Los drivers de kernel de GPU (`amdkmdag.sys`) y la API de DirectX/Vulkan operan de forma completamente autónoma respecto a la capa de usuario `cncmd.exe` / `RSServCmd.exe` (AMD Adrenalin). Desactivar su inicio automático preserva el 100% del rendimiento gráfico.

---

## 4. Fases de Implementación

### Fase 1: Expansión de la Fuente Única de Verdad (`scripts/Core/Policy-Engine.ps1`)
- [x] Registrar directivas de supresión de mantenimiento automático en logon (`POL_MAINTENANCE_DISABLE_LOGON_SPIKE`).
- [x] Completar directivas de supresión de Bing en `SearchHost` (`BingSearchEnabled = 0`, `AllowSearchToUseLocation = 0`, `CortanaConsent = 0`).
- [x] Definir el catálogo canónico de servicios para transición segura a `Demand-Start` (`Get-RomanOSDemandServices`).
- [x] Definir catálogo de tareas y claves de autostart de terceros reconocidas (`Get-RomanOSStartupThirdPartyCatalog`).

### Fase 2: Módulo Canónico de Gobernanza de Inicio (`scripts/Modules/Optimize-StartupEcosystem.ps1`)
- [x] Crear el módulo con codificación estricta UTF-8 con BOM.
- [x] Integrar guardas Fail-Visible (CWE-390) con telemetría clara en consola.
- [x] Implementar captura automática de instantánea con `Manage-SystemSnapshots.ps1` antes de aplicar cambios.
- [x] Implementar función `Set-StartupEcosystemDemandServices` con parámetro `-WhatIf` / `-Simulate`.
- [x] Implementar función `Set-StartupThirdPartyGovernor` para alternar autostart de terceros (AMD, Steam, ExitLag, Brave, etc.) sin eliminar ejecutables ni tocar drivers de kernel.
- [x] Implementar función de restauración/reversión `Restore-StartupEcosystemDefaults`.

### Fase 3: Integración en el Generador de ISO y Debloater Adaptativo
- [x] Sincronizar `scripts/Modules/Win11-Debloat-v3-Adaptive.ps1` para consumir el nuevo catálogo de servicios a demanda.
- [x] Sincronizar `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` y exportación de comandos `autounattend.xml` para aplicar `sc.exe config <svc> start= demand` offline.

### Fase 4: Integración Visual en `romanOS-ControlCenter.ps1`
- [x] Añadir sección/control de "Gobernanza de Inicio y Servicios a Demanda" en el Control Center.
- [x] Incorporar feedback visual del estado actual (Servicios en Auto vs Manual, Apps en Autostart detectadas).
- [x] Vincular acciones seguras de Optimizar / Restaurar bajo el hilo STA.

### Fase 5: Arnés de Pruebas y Certificación Multi-Hardware
- [x] Crear suite de pruebas unitarias `scripts/Testing/Test-StartupEcosystem.ps1` (18 aserciones).
- [x] Validar compatibilidad en Windows PowerShell 5.1 (`powershell.exe -STA`) (18/18 PASS).
- [x] Probar contra Mocks CIM/WMI sin requerir elevación de Hyper-V.
- [x] Ejecutar auditoría holística de cero fallos silenciosos y verificar en `Invoke-TestSuite.ps1` (16 Fases PASS).

### Fase 6: Cierre, Documentación y Commit Atómico
- [x] Actualizar `docs/plans/README.md`.
- [x] Realizar commit atómico descriptivo y sincronizar.
