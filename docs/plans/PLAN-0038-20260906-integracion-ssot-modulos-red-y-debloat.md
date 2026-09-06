# PLAN-0038-20260906-integracion-ssot-modulos-red-y-debloat

## 1. Objetivo y Fundamento (Regla 9 SSOT)

La Regla 9 del repositorio exige que toda política, tweak de registro o configuración resida canónicamente en `scripts/Core/Policy-Engine.ps1` (Fuente Única de Verdad).

Actualmente, los scripts `Win11-Network-Diagnostics-Optimizer.ps1` y `Win11-Debloat-v3-Adaptive.ps1` contienen políticas y rutas de registro "hardcodeadas", lo cual genera deuda técnica y desvío de configuración (Configuration Drift).

El objetivo de este plan es extraer todas esas lógicas y centralizarlas en el `Policy-Engine`, modificando los scripts consumidores para que lean dinámicamente desde el catálogo maestro.

## 2. Alcance de los Cambios

### Fase 1: Módulo de Diagnóstico y Optimización de Red (`Win11-Network-Diagnostics-Optimizer.ps1`)
Se trasladarán al `Policy-Engine.ps1` (bajo una nueva categoría o en las existentes de Sistema/Red) las siguientes políticas que actualmente están hardcodeadas en el script de red:
- **TCP Stack**: `AutoTuning`, `ScalingHeuristics`, `CongestionCubic`, `DisableTimestamps`, `FastOpen`, `SynRetries`, `EcnCapability`.
- **Sistema y Registro (Gaming)**: `NetworkThrottlingIndex` (0xffffffff), `SystemResponsiveness` (0), `NonBestEffortLimit` (0), `NagleAlgorithm` (TcpNoDelay, TcpAckFrequency).
- **Adaptadores de Hardware (NIC)**: Estos ajustes (RSS, GreenEthernet, RSC, Interrupt Moderation, Offloads, FlowControl) dependen de comandos `Enable-NetAdapter*` o `Set-NetAdapterAdvancedProperty`. Si bien son comandos dinámicos, su estado "deseado" puede definirse en el motor, o bien mantenerse en el script de red pero leyendo banderas o preferencias globales del Engine.

### Fase 2: Módulo de Debloat Adaptativo (`Win11-Debloat-v3-Adaptive.ps1`)
Se auditará el script `Win11-Debloat-v3-Adaptive.ps1` para extraer cualquier clave de registro huérfana (como telemetría, Cortana, Xbox, o desinstalación de paquetes) que aún no esté en el catálogo maestro y se integrará en el arreglo global `$global:RomanOS_Policies`.

### Fase 3: Refactorización de Scripts Consumidores
- Se modificará `Win11-Network-Diagnostics-Optimizer.ps1` para cargar `Policy-Engine.ps1` en la fase de inicialización.
- El menú interactivo de red extraerá dinámicamente los metadatos (Id, Name, Desc) desde `$global:RomanOS_Policies` o una matriz especializada de red.
- Se implementará un mecanismo en el que la aplicación de los ajustes se realice llamando a funciones transversales (ej. `Apply-RomanOSPolicy`) en vez de usar `Set-ItemProperty` directamente en el código de red.

## 3. Consideraciones de Arquitectura
- **Paridad y Retrocompatibilidad**: Asegurar que las descripciones y metadatos se ajusten a la estructura de la matriz `$global:RomanOS_Policies` (Id, Module, Category, RegistryKey, ExpectedValue, Profiles).
- **Validación**: Comprobar el código siempre con `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass` para asegurar cumplimiento con PowerShell 5.1.
- **UTF-8 con BOM**: Todos los archivos tocados se deben guardar estrictamente en `UTF-8-BOM`.

## 4. Criterios de Aceptación
1. `Policy-Engine.ps1` contiene todas las directivas que antes estaban en el script de red.
2. `Win11-Network-Diagnostics-Optimizer.ps1` ya no contiene strings hardcodeados de rutas de registro.
3. El menú visual y la aplicación de políticas funciona sin errores bajo PowerShell 5.1 en Windows.
