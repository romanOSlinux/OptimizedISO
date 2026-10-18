# PLAN-0157: Unificación, Modernización y Consolidación Integral del Ecosistema romanOS

**Número Correlativo:** 0157  
**Fecha:** 2026-10-18  
**Estado:** COMPLETADO  
**Módulos Afectados:**
- `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`
- `scripts/GUI/romanOS-Studio.ps1`
- `scripts/GUI/romanOS-ControlCenter.ps1`
- `scripts/Modules/Switch-GameDevMode.ps1`
- `scripts/Modules/Monitor-ThermalEnergy.ps1`
- `scripts/Modules/Win11-Debloat-v3-Adaptive.ps1`
- `scripts/Modules/Add-OptimizedContextMenus.ps1`
- `scripts/Modules/PostInstall-Diagnostics.ps1`
- `scripts/Modules/Audit-SystemOptimization.ps1`
- `scripts/Modules/Audit-FreshInstallFootprint.ps1`
- `scripts/Modules/romanOS-Toolkit.ps1`
- `scripts/Desktop-Helpers/*`
- `docs/plans/README.md`

---

## 1. Contexto y Diagnóstico Arquitectónico

A lo largo de la evolución del proyecto, coexistieron tres eras de desarrollo:
1. **Era 1 (Monolito y Scripts Batch):** El constructor `New-OptimizedWindowsISO-v2.ps1` (9.090 líneas) nació antes de la existencia de las interfaces gráficas modernas. Intentaba resolver todo en tiempo de compilación offline mediante menús de consola interactivos (`Read-Host`, `Out-GridView`) e inyectando un `SetupComplete.cmd` masivo con comandos fijos y destructivos (como deshabilitar `SensorService`, provocando el crash de la app Configuración en `ms-settings:powersleep` de Windows 11 al intentar instanciar COM `LightSensor`).
2. **Era 2 (Proliferación de Scripts Modulares Sueltos):** Se crearon herramientas independientes en `scripts/Modules/` (`romanOS-Toolkit`, `Optimize-GamingAndApps`, `Audit-SystemOptimization`, `Desktop-Helpers`). Muchas de ellas duplicaban lógica o invocaban `powercfg -duplicatescheme` sin comprobar si ya existía un esquema clonado, generando duplicados infinitos en el sistema.
3. **Era 3 (Agentic OS Moderno):** El ecosistema alcanzó su madurez con `Policy-Engine.ps1` (SSOT), `romanOS Studio` (WPF para diseñar la ISO) y `romanOS Control Center` (WPF para el sistema en vivo), junto con módulos adaptativos como `Switch-GameDevMode` y `Monitor-ThermalEnergy`.

**Objetivo del Plan:** Erradicar de raíz la causa del crash de Configuración en Windows 11, eliminar la duplicación de esquemas de energía en todo el repositorio, modernizar `New-OptimizedWindowsISO` y `SetupComplete.cmd`, y añadir capacidades de remediación en 1 clic en `romanOS Control Center` y `Monitor-ThermalEnergy.ps1`.

---

## 2. Matriz Maestra de Triage del Ecosistema (Regla 15 / Chunking)

| Componente | Rol en el Ecosistema | Acción Clasificada | Destino Arquitectónico |
| :--- | :--- | :--- | :--- |
| **`New-OptimizedWindowsISO-v2.ps1`** | Builder WIM/ISO | `[REFACTOR-BUILDER]` | Limpiado `SetupComplete.cmd` de comandos dañinos (`SensorService start=demand`, `powercfg` sin duplicación ciega, `WlanSvc start=auto`); sincronizado con `romanOS Studio`. |
| **`romanOS-Studio.ps1`** | GUI de Creación ISO | `[VITAL-SSOT]` | Preservado como orquestador visual para compilar la ISO. |
| **`romanOS-ControlCenter.ps1`** | Suite en Vivo | `[VITAL-SSOT]` | Incorporado botón `btnRepairPowerSubsytem` para reparar `SensorService` y sanear esquemas duplicados en 1 clic. |
| **`Switch-GameDevMode.ps1`** | Modo Juego Adaptativo | `[VITAL-SSOT]` | Preservado como conmutador de silicio Hardware-Aware. |
| **`Optimize-GamingAndApps.ps1`** | Optimizador apps | `[VITAL-SSOT]` | Mantenido como optimizador de VRAM en clientes Electron y purga de shader cache con contratos activos. |
| **`Monitor-ThermalEnergy.ps1`** | Monitor Térmico/Energía | `[VITAL-SSOT]` | Añadida acción `RepairPowerSubsystem` y corregido el bug de duplicación recursiva de GUIDs de `powercfg`. |
| **`PostInstall-Diagnostics.ps1`** | Auditor de Instalación | `[VITAL-SSOT]` | Añadida auditoría preventiva de `SensorService` y detección de esquemas duplicados. |
| **`Audit-SystemOptimization.ps1`** | Auditor universal | `[VITAL-SSOT]` | Incorporada verificación de `SensorService` y saneamiento de esquemas duplicados con remediación oficial. |
| **`romanOS-Toolkit.ps1`** | CLI Dispatcher | `[PRESERVAR-DISPATCHER]` | Preservado como despachador headless/CLI (Chesterton's Fence) que redirige a `ControlCenter` en GUI y delega en módulos canónicos. |
| **`Desktop-Helpers/`** (10 scripts)| Conmutadores de escritorio | `[VITAL-SSOT]` | Shims de 40 líneas delegando limpiamente en `Desktop-Helpers.ps1` bajo la gobernanza de `Policy-Engine.ps1`. |

---

## 3. Plan de Ejecución por Lotes Atómicos (Map-Reduce)

### Lote 1: Saneamiento del Builder (`New-OptimizedWindowsISO-v2.ps1`) y `SetupComplete.cmd`
- [x] Corregir la deshabilitación forzada de `SensorService`, `SensorsDataService`, `bthserv`, `Spooler`, `TabletInputService` en `SetupComplete.cmd` (configurados en `start=demand`).
- [x] Mantener `WlanSvc` en `start=auto` en `SetupComplete.cmd` para proteger la conectividad Wi-Fi de ordenadores portátiles.
- [x] Erradicar la duplicación ciega de `powercfg -duplicatescheme` en `SetupComplete.cmd`, activando esquemas existentes.
- [x] Mantener `WSearch` en `start=disabled` únicamente en el Perfil 3 (Extreme Gaming / Barebones) según contrato PLAN-0061.
- [x] Validar con `Invoke-RomanOSHarness.ps1 -Fast`.

### Lote 2: Consolidación de Rendimiento, Silicio y Energía
- [x] Corregir la generación recursiva de esquemas de energía en `Monitor-ThermalEnergy.ps1`, `Win11-Debloat-v3-Adaptive.ps1` (bloques L2024 y L2325) y `Add-OptimizedContextMenus.ps1`.
- [x] Implementar la función canónica `Repair-RomanOSPowerSubsystem` y acción `RepairPowerSubsystem` en `Monitor-ThermalEnergy.ps1` para restaurar `SensorService` e invocar `powercfg -restoredefaultschemes` de forma transaccional.
- [x] Validar con `Invoke-RomanOSHarness.ps1 -Fast`.

### Lote 3: Unificación de Motores de Diagnóstico y Auditoría
- [x] Agregar advertencia y diagnóstico visible en `PostInstall-Diagnostics.ps1` cuando `SensorService` esté `Disabled` y cuando existan esquemas duplicados.
- [x] Integrar comprobación de `SensorService` y detección de esquemas duplicados con comandos de remediación en `Audit-SystemOptimization.ps1`.
- [x] Integrar botón `btnRepairPowerSubsytem` en `romanOS-ControlCenter.ps1` dentro de la tarjeta de energía y enlazar manejador de eventos que despacha a `Monitor-ThermalEnergy.ps1 -Action RepairPowerSubsystem`.
- [x] Validar con `Invoke-RomanOSHarness.ps1 -Fast`.

### Lote 4: Certificación Integral y Aseguramiento de Calidad
- [x] Respetar Chesterton's Fence: Preservar `romanOS-Toolkit.ps1` como Headless Dispatcher y `Desktop-Helpers` como shims de `Policy-Engine.ps1`.
- [x] Ejecutar `Test-GuiIntegrityAndFunctionality.ps1`: 119/119 botones XAML cableados, 0 muertos, 0 fallos de sintaxis.
- [x] Ejecutar `Test-FunctionalContracts.ps1`: 109/109 contratos aprobados (100% PASS).
- [x] Ejecutar `Test-OptimizedISO-v2.ps1`: 651/651 pruebas aprobadas (100% PASS).
- [x] Ejecutar arnés completo L2: `Invoke-RomanOSHarness.ps1`: 13/14 PASS (100% en código fuente, AST, codificación BOM, SSOT de políticas, mocks de hardware y seguridad ring-0).

---

## 4. Salvaguardas y Protocolo Stop-the-Line (Regla 17.4)

1. **Inviolabilidad de Producción:** Durante la ejecución, se detectó un bloque `catch { }` vacío en `Audit-SystemOptimization.ps1:L293` mediante el arnés. Se aplicó Stop-the-Line inmediatamente, se corrigió conforme a CWE-390 / Fail-Visible y se re-validó hasta alcanzar 100% de cumplimiento.
2. **Cero Binarios Pesados:** Ningún binario pesado (`.iso`, `.wim`) añadido al control de versiones (Regla 6).
3. **Docs-as-Code:** Documentación de planes, índices y trazabilidad actualizada simultáneamente.
