# PLAN-0056: Auditoría Forense Empírica de Huella en Segundo Plano (Footprint Audit), Integración en Toolkit Maestro e Inyección en la ISO

- **ID del Plan:** PLAN-0056
- **Fecha:** 2026-09-07
- **Autor:** romanOS Engineering & Antigravity Agent
- **Estado:** COMPLETADO
- **Área:** `scripts\Modules\Audit-FreshInstallFootprint.ps1`, `scripts\Modules\romanOS-Toolkit.ps1`, `scripts\Builder\New-OptimizedWindowsISO-v2.ps1`, `scripts\Testing\Test-OptimizedISO-v2.ps1`

---

## 1. Contexto y Justificación Técnica

### 1.1 Necesidad de Validación Empírica en Máquina Virtual
Para tomar decisiones técnicas fundamentadas respecto a qué optimizaciones quirúrgicas adicionales deben integrarse de fábrica en la ISO (tales como la neutralización del inicio automático de Microsoft Edge, OneDrive en Default User, Xbox GameDVR, etc.), es indispensable contar con un instrumento de medición forense objetivo y automatizado.

En lugar de realizar suposiciones estáticas, el sistema debe proveer una herramienta que pueda ejecutarse en una máquina virtual recién instalada (sin interacción previa del usuario) para auditar con exactitud matemática:
1. Qué procesos en segundo plano se encuentran activos y cuánta memoria RAM (Working Set) y ciclos de CPU devoran.
2. Si los procesos neutralizados en el PLAN-0055 (`msedgewebview2.exe` y `SearchHost.exe`) se mantienen en estado suspendido o con cero instancias de fondo.
3. Qué ejecutables están anclados en las claves de inicio automático (`HKCU`/`HKLM` `Run` y `RunOnce`) y en el Programador de Tareas.
4. Qué directivas de grupo (GPO/MDM CSP) están presentes o ausentes en el registro del sistema de destino.

### 1.2 Integración en el Ecosistema romanOS
Para garantizar paridad total y facilidad de uso:
1. El script debe residir en `scripts/Modules/Audit-FreshInstallFootprint.ps1` respetando la arquitectura canónica (UTF-8 con BOM, Windows PowerShell 5.1, `UI-Engine.ps1`).
2. Debe ser accesible de forma directa desde el lanzador maestro `romanOS-Toolkit.ps1` (menú interactivo y parámetro `-Module FootprintAudit`).
3. Debe ser inyectado físicamente en la ISO generada por `New-OptimizedWindowsISO-v2.ps1` (`$OEM$\$$\Setup\Scripts\Modules` y dentro de `install.wim`), apareciendo en el escritorio o dentro del toolkit instalado.
4. Se deben documentar métodos directos para transferir y ejecutar el script en máquinas virtuales activas de Hyper-V o VirtualBox.

---

## 2. Especificación de la Herramienta: `Audit-FreshInstallFootprint.ps1`

### 2.1 Procesos Clave Auditados
El script auditará individualmente los siguientes procesos y calculará métricas en tiempo real:
- **`SearchHost.exe`:** Estado del proceso (PLM Suspended vs Running), memoria Working Set en MB, CPU %.
- **`msedgewebview2.exe`:** Conteo de instancias activas y memoria total consumida.
- **`msedge.exe`:** Detección de procesos parásitos invocados por *Startup Boost* o *Background Mode*.
- **`OneDrive.exe` / `OneDriveSetup.exe`:** Detección de auto-arranque y memoria asignada.
- **`msteams.exe` / `Teams.exe`:** Detección de precarga del conector de Chat de la barra de tareas.
- **`Widgets.exe`:** Detección del subsistema de noticias y widgets.
- **`bcastdvr.exe` / `GameBar.exe` / `GameBarFTServer.exe`:** Detección del búfer de captura en segundo plano de Xbox.
- **`werfault.exe`:** Detección del servicio de informes de errores en espera o ejecución.

### 2.2 Auditoría de Auto-inicio y Tareas Programadas
- Inspección de `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`.
- Inspección de `HKLM:\Software\Microsoft\Windows\CurrentVersion\Run`.
- Detección de tareas programadas de telemetría de Edge, OneDrive y Spotlight.

### 2.3 Auditoría de Directivas de Registro
- `LimitBlankPasswordUse` (Verificar valor 1).
- `EnableDynamicContentInWSB` (Verificar valor 0).
- `StartupBoostEnabled`, `BackgroundModeEnabled` (Estado de Edge).
- `AllowGameDVR`, `AppCaptureEnabled` (Estado de GameDVR).
- `TaskbarMn`, `TaskbarDa`, `ShowCopilotButton` (Estado de la barra de tareas).

### 2.4 Métricas Globales del Sistema Operativo
- Memoria RAM Física Total, RAM en Uso (GB y %), RAM Disponible.
- Conteo total de Procesos y Conteo total de Hilos en ejecución.
- Tiempo de encendido del sistema (Uptime).

### 2.5 Salida y Exportación Forense
- Interfaz gráfica enriquecida en consola vía `UI-Engine.ps1` con indicadores de estado:
  - `[OK - SUSPENDIDO / ZERO-OVERHEAD]`
  - `[VAMPIRO DETECTADO - EN EJECUCION]`
  - `[LIMPIO / AUSENTE]`
- Generación y guardado automático de un reporte estructurado en formato Markdown en:
  - `C:\romanOS_Footprint_Audit.md`
  - Copia automática en el Escritorio del usuario activo.

---

## 3. Integración en el Generador de la ISO y Toolkit

### 3.1 `scripts/Modules/romanOS-Toolkit.ps1`
- Registro de `Audit-FreshInstallFootprint.ps1` en el catálogo de herramientas.
- Agregar opción en el menú interactivo principal:
  `[6] Auditoría Forense de Huella en Reposo (Fresh Footprint Audit)`.
- Soporte para invocación por parámetro CLI:
  `.\romanOS-Toolkit.ps1 -Module FootprintAudit`.

### 3.2 `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`
- Inyección del script en la carpeta de scripts `$OEMScriptsDir\Modules\Audit-FreshInstallFootprint.ps1`.
- Inyección del script en la imagen WIM montada `wimModulesDest\Audit-FreshInstallFootprint.ps1`.
- Inclusión del script en el menú interactivo de selección de utilitarios del Builder (Paso 2/6).

---

## 4. Métodos para Ejecución en Máquina Virtual Activa

Se proporcionarán instrucciones claras y comandos listos para usar según el entorno de virtualización:

### Método A: PowerShell Direct (Hyper-V Nativo sin red requerida)
```powershell
# Ejecución remota directa dentro de la VM usando credenciales de administrador o autologon
Invoke-Command -VMName "NombreVM" -ScriptBlock { & "C:\Windows\Setup\Scripts\Modules\Audit-FreshInstallFootprint.ps1" }

# O copiar el script desde el host a la VM:
Copy-VMFile -VMName "NombreVM" -SourcePath "C:\OptimizedISO\scripts\Modules\Audit-FreshInstallFootprint.ps1" -DestinationPath "C:\Users\Public\Desktop\Audit-FreshInstallFootprint.ps1" -CreateFullPath -FileSource Host
```

### Método B: Ejecución desde el Toolkit Integrado en la ISO
En la VM recién instalada con la ISO generada:
```cmd
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "C:\Windows\Setup\Scripts\Modules\Audit-FreshInstallFootprint.ps1"
```

### Método C: Portapapeles / Enhanced Session Mode
Copiar y pegar el archivo directamente en el escritorio de la VM mediante la Sesión Mejorada de Hyper-V o las Guest Additions de VirtualBox.

---

## 5. Plan de Validación y Verificación

1. **Codificación y Sintaxis en Windows PowerShell 5.1:**
   - Garantizar codificación estricta UTF-8 con BOM (`0xEF, 0xBB, 0xBF`).
   - Verificar 0 errores de análisis AST con `[System.Management.Automation.Language.Parser]::ParseFile`.
2. **Pruebas en el Test Harness (`scripts/Testing/Test-OptimizedISO-v2.ps1`):**
   - Incorporar bloque de pruebas unitarias PLAN-0056 para certificar la existencia de `Audit-FreshInstallFootprint.ps1`, su integración en el Toolkit y su inyección en el Builder.
3. **Ejecución de la Suite Global (`scripts/Testing/Invoke-TestSuite.ps1`):**
   - Confirmar 100% PASS en toda la suite del repositorio.
