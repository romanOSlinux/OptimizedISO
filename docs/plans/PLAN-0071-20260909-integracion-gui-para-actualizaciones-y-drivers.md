# PLAN-0071: Integración de Módulos Satélite (Actualizaciones, Drivers, Runtimes) a la GUI

**Fecha:** 2026-09-09  
**Estado:** PENDIENTE  
**Área:** Arquitectura de Software, Interfaz Gráfica (WPF), Herramientas Satélite  
**Fuente de Verdad (SSOT):** `docs/plans/PLAN-0071-20260909-integracion-gui-para-actualizaciones-y-drivers.md`  

---

## 1. El Problema Observado

Actualmente, `romanOS Studio` orquesta la construcción de la ISO mediante `New-OptimizedWindowsISO-GUI-Engine.ps1`. Sin embargo, las tareas previas de preparación del entorno siguen dependiendo fuertemente de la línea de comandos interactiva. 

Scripts como:
- `Get-WindowsUpdates.ps1`
- `Get-CriticalDrivers.ps1`
- `Backup-HardwareDrivers.ps1`
- `Get-EssentialRuntimes.ps1`

Poseen menús (`Show-UnifiedMenu`), prompts de confirmación (`Prompt-UnifiedYesNo`) y lecturas de teclado (`Read-Host`). Si la GUI los invoca tal como están, el proceso de PowerShell entrará en *deadlock* (se congelará esperando una entrada que nunca llegará desde la interfaz gráfica).

---

## 2. Decisión Técnica de Arquitectura (Ingeniería de Software)

Para mantener el principio DRY (Don't Repeat Yourself) y evitar clonar 4 scripts adicionales (lo cual generaría deuda técnica de mantenimiento), se adoptará la **Estrategia de Parámetros Inteligentes (Headless Bypass)**.

A diferencia del constructor de ISO, que justificaba un Engine separado por su inmensa complejidad y el peso de su refactorización, estos scripts de descarga son lineales. 

### Arquitectura de Solución:
1. **Parámetro Mandatorio:** Añadir `[switch]$Headless` a todos los scripts satélite.
2. **Bypass de Lógica Interactiva:** Cuando `$Headless` sea verdadero, los scripts no mostrarán menús. En su lugar, requerirán que parámetros como `$TargetVersion`, `$Package` o `$DestinationPath` se pasen explícitamente desde la línea de comandos de la GUI.
3. **Flujo de Ejecución:** La GUI (`romanOS-Studio.ps1`) usará el mismo motor asíncrono `.NET` (`add_OutputDataReceived`) que recién validamos para el proceso principal, garantizando que el usuario vea la descarga de paquetes (MB/s) en tiempo real en una consola WPF sin congelar la ventana.

---

## 3. Plan de Implementación por Fases

### Fase 1: Adaptación Headless de `Get-WindowsUpdates.ps1`
- Agregar `[switch]$Headless` y `[string]$TargetVersion` (ej: `24H2-x64`).
- Modificar el bloque de selección de menú para que tome `$TargetVersion` directamente si `$Headless` está activo.

### Fase 2: Adaptación Headless de Controladores y Runtimes
- `Get-CriticalDrivers.ps1`: Asegurar que descargue el paquete `$Package` en el `$DestinationPath` sin preguntar si existe `$Headless`.
- `Backup-HardwareDrivers.ps1`: Forzar la extracción silenciosa.
- `Get-EssentialRuntimes.ps1`: Automatizar la descarga silenciosa.

### Fase 3: Ampliación de la GUI (`romanOS-Studio.ps1`)
- Diseñar la distribución visual (XAML). Se proponen nuevas pestañas o integración en las existentes.
- Conectar botones a nuevas funciones `Start-DownloadProcess` reutilizando la arquitectura de hilos `.NET` del `workerProcess`.

### Fase 4: Auditoría y Pruebas Unitarias
- Validar BOM UTF-8 y sintaxis en PS 5.1 (Regla 4).
- Confirmar que las descargas progresan y reflejan stdout en la UI sin pausas.
