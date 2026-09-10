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

## 2. Decisión Técnica de Arquitectura (Motores Dedicados GUI)

De acuerdo al lineamiento estricto, **NO se modificarán los scripts interactivos existentes** (para no romper su funcionalidad CLI actual). En su lugar, se creará una nueva familia de motores esclavos dedicados exclusivamente a la GUI.

### Arquitectura de Solución:
1. **Clonación y Limpieza (GUI-Engines):**
   - `Get-WindowsUpdates.ps1` → `Get-WindowsUpdates-GUI-Engine.ps1`
   - `Get-CriticalDrivers.ps1` → `Get-CriticalDrivers-GUI-Engine.ps1`
   - `Backup-HardwareDrivers.ps1` → `Backup-HardwareDrivers-GUI-Engine.ps1`
   - Se erradicará completamente cualquier uso de `Read-Host`, `Show-UnifiedMenu` o pausas de estos nuevos archivos.
2. **Entrada de Datos Estricta:** Estos motores requerirán parámetros fijos de entrada pasados directamente por la GUI (ej. `-TargetVersion`, `-DestinationPath`).
3. **Flujo de Ejecución:** La GUI (`romanOS-Studio.ps1`) usará el motor asíncrono `.NET` (`add_OutputDataReceived`) para ejecutar los nuevos `-GUI-Engine.ps1` en segundo plano, canalizando su output a la consola visual sin congelar la ventana.

---

## 3. Plan de Implementación por Fases

### Fase 1: Creación de `Get-WindowsUpdates-GUI-Engine.ps1`
- Clonar código fuente.
- Reemplazar menú interactivo por un parámetro obligatorio `[string]$TargetVersion`.
- Limpiar prompts de confirmación.

### Fase 2: Creación de Motores de Controladores
- Generar `Get-CriticalDrivers-GUI-Engine.ps1` parametrizado.
- Generar `Backup-HardwareDrivers-GUI-Engine.ps1` automatizado.

### Fase 3: Ampliación de la GUI (`romanOS-Studio.ps1`)
- Agregar nueva Pestaña o Botones de Acción para invocar estos sub-procesos.
- Conectar cada botón a `Start-BackgroundProcess` (o lógica similar a la de ISO) apuntando a los nuevos motores `*-GUI-Engine.ps1`.


### Fase 4: Auditoría y Pruebas Unitarias
- Validar BOM UTF-8 y sintaxis en PS 5.1 (Regla 4).
- Confirmar que las descargas progresan y reflejan stdout en la UI sin pausas.
