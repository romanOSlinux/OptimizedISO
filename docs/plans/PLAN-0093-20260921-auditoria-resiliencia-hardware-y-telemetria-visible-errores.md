# PLAN-0093: Auditoría Forense de Suposiciones de Hardware, Erradicación de Fallos Silenciosos y Telemetría Visible de Diagnóstico

**Fecha:** 2026-09-21  
**Estado:** PENDIENTE  
**Prioridad:** ALTA  
**Rama:** `feature/offline-ui-tweaks`  

---

## 1. Contexto y Justificación

Tras la resolución del [PLAN-0092](PLAN-0092-20260921-correccion-forense-multi-hardware-control-center-ecosistema.md), donde se detectó un fallo crítico en el que `Invoke-WindowsMaintenance.ps1` consultaba rígidamente `DeviceID = '0'` para ejecutar TRIM (asumiendo falsamente que el disco de arranque siempre reside en el puerto 0 y cancelando la optimización en unidades SSD NVMe instaladas en discos secundarios o terciarios), se determinó la necesidad imperativa de realizar una auditoría forense a todo el ecosistema.

Adicionalmente, se identificó un patrón de diseño subóptimo en diversos scripts: el **ocultamiento silencioso de fallos** mediante bloques `catch { }` vacíos, banderas `-ErrorAction SilentlyContinue` desprovistas de verificación posterior, o bifurcaciones `if ($tool)` que omiten avisar al usuario cuando un recurso, dispositivo o script no es localizado.

### Filosofía y Directriz Obligatoria
1. **Cero Suposiciones Topológicas:** Ningún script debe asumir que Windows está en `C:`, que el disco es `0`, que solo existe una tarjeta de red, que solo hay una GPU o que solo existe el fabricante NVIDIA.
2. **Telemetría y Aviso Visible Obligatorio:** Ningún script debe silenciar excepciones críticas ni fallos de búsqueda. Todo fallo o recurso no localizado debe emitir un mensaje visible (`Write-Warning`, `Write-Error`, o alerta en consola/terminal embebida) explicando:
   - Qué componente o recurso se estaba buscando.
   - Qué método o ruta falló.
   - Qué acción alternativa (fallback) se está adoptando.
   - El mensaje técnico de la excepción (`$_.Exception.Message`).

---

## 2. Hallazgos Forenses de la Auditoría Inicial

### A. Almacenamiento y Topología de Discos
1. **`scripts/Core/Hardware-Engine.ps1`:**
   - Líneas 374-377: Si la búsqueda de `PhysicalDisk` por `DeviceId -eq $bootDiskNumber` no retorna objeto, ejecuta `Get-PhysicalDisk | Select-Object -First 1`. Esto selecciona un disco físico arbitrario que puede ser un HDD SATA secundario en lugar del disco de arranque NVMe.
   - Líneas 394-409 (Fallback WMI): Si `Get-Disk` falla, ejecuta `Get-CimInstance Win32_DiskDrive | Sort-Object Index | Select-Object -First 1`, asumiendo que el disco de arranque siempre tiene índice 0.
   - Línea 414: `fsutil.exe bypassIO state C:\` hardcodea la unidad `C:\` en lugar de `$env:SystemDrive`.
   - Todo el bloque de detección de disco silencia excepciones en un `catch {}` sin advertir al usuario.
2. **`scripts/Modules/Invoke-WindowsMaintenance.ps1`:**
   - Líneas 199 y 646: Hardcodea `Get-DriveFreeBytes 'C'` para calcular el espacio inicial y final liberado, en lugar de consultar `$env:SystemDrive`.
   - Línea 627: `vssadmin.exe delete shadows /for=C: ...` con `catch {}` vacío, hardcodea `C:` y no verifica el código de salida de `vssadmin`.
3. **`scripts/Modules/Audit-SystemOptimization.ps1`:**
   - Línea 236: `$bootPart = Get-Partition -DriveLetter C -ErrorAction SilentlyContinue` hardcodea la letra `C`.
   - Línea 243: Bloque `catch {}` vacío que asume silenciosamente "Disco Mecanico HDD" si falla la consulta.
4. **`scripts/Core/UI-Engine.ps1`:**
   - Línea 88: `Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"` y bloque `catch {}` vacío en línea 95.
5. **`scripts/Modules/PostInstall-Diagnostics.ps1`:**
   - Línea 173: `Filter "DeviceID='C:'"` silencia y omite la sección si Windows no está en `C:`.

### B. Detección Gráfica y Trazado de Latencia DPC/ISR
1. **`scripts/Modules/Trace-SystemLatency.ps1`:**
   - Línea 367: `$gpuPdo = (Get-CimInstance Win32_PnPEntity | Where-Object { $_.Service -eq 'nvlddmkm' } | Select-Object -First 1).DeviceID`. Solo verifica GPUs NVIDIA. En sistemas AMD Radeon (`amdkmdag`) o Intel Arc/Xe (`igfxn`/`i915`), `$gpuPdo` queda nulo y el bloque `catch {}` en línea 373 silencia la auditoría MSI de la GPU.
   - Línea 349: Typo / corrupción de caracteres en el servicio AMD 3D V-Cache: `"AMD3DV互CachePerformanceOptimizer"`. El carácter `互` (`\u4E92`) impide que coincida con el servicio real (`AMD3DVCacheOptimizer`), silenciando la comprobación con `-ErrorAction SilentlyContinue`.

### C. Red, Interfaces y Lanzador Control Center
1. **`scripts/Modules/Win11-Network-Diagnostics-Optimizer.ps1`:**
   - Línea 542: Ante el fallo de un tweak, imprime `"Fallo al aplicar $($tweak.Name)"` pero no expone `$_.Exception.Message` en la consola.
   - Líneas 474-479: Modificación de claves TCP/IP en bucle con `-ErrorAction SilentlyContinue` sin verificar éxito.
2. **`scripts/GUI/romanOS-ControlCenter.ps1`:**
   - Asignación de DNS: Si `$w` es nulo (no hay interfaz UP o sin gateway), arroja excepción de argumento nulo sin explicación clara.
   - Líneas 758, 779, 897, 922, etc.: Si `Resolve-ToolScript` devuelve `$null`, el clic en el botón se ignora en silencio sin notificar al usuario en la terminal embebida.

### D. Controladores y Respaldo
1. **`scripts/Drivers/Backup-HardwareDrivers.ps1`:**
   - Línea 51: Comprueba `"C:\OptimizedISO\scripts\Drivers"` antes que `$PSScriptRoot`, lo cual puede provocar desvíos si el repositorio está en otra unidad.
2. **`scripts/Drivers/Get-CriticalDrivers.ps1`:**
   - Si la extracción de VirtIO no encuentra los controladores en la ISO montada, finaliza sin advertir al operador.

---

## 3. Plan de Cambios y Correcciones

### Fase 1: Arquitectura de Almacenamiento y Topología Canónica
- Modificar `scripts/Core/Hardware-Engine.ps1`:
  - Resolver el disco del sistema partiendo de `$sysLetter = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd(':') } else { 'C' }`.
  - Vincular `Get-Partition -DriveLetter $sysLetter` -> `Get-Disk` -> pipe relacional `Get-PhysicalDisk`.
  - En fallback WMI, utilizar asociaciones canónicas `Win32_LogicalDiskToPartition` -> `Win32_DiskDriveToDiskPartition` para identificar con exactitud matemática el índice del disco físico real de Windows.
  - Reemplazar `fsutil.exe bypassIO state C:\` por `fsutil.exe bypassIO state "$($env:SystemDrive)\"`.
  - Añadir avisos explícitos `Write-Warning` si la resolución de almacenamiento encuentra anomalías o recurre a heurísticas.
- Actualizar `scripts/Modules/Invoke-WindowsMaintenance.ps1`, `scripts/Modules/Audit-SystemOptimization.ps1`, `scripts/Core/UI-Engine.ps1` y `scripts/Modules/PostInstall-Diagnostics.ps1` para consumir `$env:SystemDrive` de forma universal y erradicar bloques `catch {}` mudos.

### Fase 2: Trazador Forense de Latencia y Drivers GPU
- Modificar `scripts/Modules/Trace-SystemLatency.ps1`:
  - Corregir el nombre corrupto de AMD 3D V-Cache (`AMD3DVCacheOptimizer` / `AMD 3D V-Cache Performance Optimizer Service`).
  - Generalizar la detección de GPU para modo MSI cubriendo NVIDIA (`nvlddmkm`), AMD (`amdkmdag`) e Intel Arc/Xe (`igfxn`, `i915`), registrando alertas visibles si el modo MSI no está activado o si ocurre un error en el registro.

### Fase 3: Red, Control Center y Alertas de Diagnóstico en GUI
- Modificar `scripts/GUI/romanOS-ControlCenter.ps1`:
  - En las tareas de configuración de DNS, validar la existencia de `$w`; si no existe interfaz con salida, emitir un mensaje de error claro y descriptivo.
  - En los invocadores de herramientas mediante `Resolve-ToolScript`, añadir bloque `else` que escriba en la terminal de la interfaz:
    `[ERROR] No se encontro el script requerido '<nombre>' en las rutas de busqueda del sistema.`
- Modificar `scripts/Modules/Win11-Network-Diagnostics-Optimizer.ps1`:
  - Exponer `$_.Exception.Message` en consola ante fallos de aplicación de tweaks de red.

### Fase 4: Respaldo y Extracción de Controladores
- Modificar `scripts/Drivers/Backup-HardwareDrivers.ps1`:
  - Priorizar la carpeta relativa a `$PSScriptRoot` antes del fallback estático `"C:\OptimizedISO\scripts\Drivers"`.
- Modificar `scripts/Drivers/Get-CriticalDrivers.ps1`:
  - Emitir `Write-Warning` si no se detectan los controladores VirtIO en la ISO montada.

### Fase 5: Suite de Pruebas Unitarias y Certificación CI
- Incorporar en `scripts/Testing/Test-OptimizedISO-v2.ps1` la **Fase 2.19: Auditoría de Resiliencia de Hardware y Cero Suposiciones**:
  - Aserciones que verifiquen que ningún script del sistema use `DeviceID='C:'` hardcodeado.
  - Aserciones que verifiquen que `Hardware-Engine.ps1` resuelva el almacenamiento a través de la partición del sistema y asociaciones WMI.
  - Aserciones que verifiquen la ausencia del carácter corrupto `互` en `Trace-SystemLatency.ps1` y soporte multi-GPU.
  - Aserciones que certifiquen que Control Center emita alertas visibles ante scripts no encontrados.
- Validar con `Invoke-TestSuite.ps1 -Quick` (100% PASS, UTF-8 con BOM y 0 errores AST en Windows PowerShell 5.1).

---

## 4. Matriz de Archivos Afectados

| Archivo | Acción | Descripción |
| :--- | :--- | :--- |
| `scripts/Core/Hardware-Engine.ps1` | Modificar | Topología de almacenamiento resiliente, asociadores WMI, avisos visibles de advertencia |
| `scripts/Core/UI-Engine.ps1` | Modificar | Desacople de `C:` a `$env:SystemDrive` y aviso en captura de excepciones |
| `scripts/Modules/Invoke-WindowsMaintenance.ps1` | Modificar | `$env:SystemDrive` en métricas de espacio libre y validación de `vssadmin` |
| `scripts/Modules/Audit-SystemOptimization.ps1` | Modificar | `$env:SystemDrive` en auditoría de partición y aviso en catch |
| `scripts/Modules/PostInstall-Diagnostics.ps1` | Modificar | `$env:SystemDrive` en auditoría de almacenamiento y alertas visibles |
| `scripts/Modules/Trace-SystemLatency.ps1` | Modificar | Corrección AMD 3D V-Cache (`互`), soporte MSI multi-vendor (AMD/Intel/NVIDIA) |
| `scripts/Modules/Win11-Network-Diagnostics-Optimizer.ps1` | Modificar | Detalle explícito de excepción en consola y verificación de claves TCP/IP |
| `scripts/GUI/romanOS-ControlCenter.ps1` | Modificar | Alerta visible en terminal si falta script y validación de adaptador DNS |
| `scripts/Drivers/Backup-HardwareDrivers.ps1` | Modificar | Prioridad a `$PSScriptRoot` sobre ruta absoluta `C:\` |
| `scripts/Drivers/Get-CriticalDrivers.ps1` | Modificar | Alerta visible si no se hallan drivers VirtIO en ISO montada |
| `scripts/Testing/Test-OptimizedISO-v2.ps1` | Modificar | Incorporación de Fase 2.19 con pruebas de resiliencia y telemetría de errores |
| `docs/plans/README.md` | Modificar | Registro de PLAN-0093 en el índice oficial |
| `MEMORY.md` | Modificar | Registro de hito tras completar la implementación |

---

## 5. Protocolo de Verificación Empírica
1. Validación en frío de codificación UTF-8 con BOM y parser AST en Windows PowerShell 5.1 (`powershell.exe -STA`).
2. Ejecución del arnés de pruebas unitarias (`Test-OptimizedISO-v2.ps1`).
3. Ejecución de la batería de pruebas de CI (`Invoke-TestSuite.ps1 -Quick`).
4. Auditoría forense de logs (`grep_search`) buscando `FAIL`, `ERROR` o `Exception` en los reportes físicos generados.
