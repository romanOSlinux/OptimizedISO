# PLAN-0031: Corrección de Menús Contextuales en Cascada y Erradicación de SubCommands en Ítems Hoja

**Fecha:** 2026-09-06  
**Autor:** romanOS / OptimizedISO Project Team  
**Estado:** COMPLETADO  
**Rama:** `feature/offline-ui-tweaks`  

---

## 1. Resumen Ejecutivo y Diagnóstico de Causa Raíz

### 1.1 El Problema Reportado
Al interactuar con los menús contextuales avanzados en el sistema instalado (por ejemplo, el submenú en cascada "Gaming y Rendimiento ⚡", "Herramientas del Sistema ⚙️", o acciones en archivos como "Calcular Hash SHA-256", "Tomar Posesión", etc.), las opciones aparecen listadas en la interfaz de usuario pero:
- No permiten su selección o ejecución.
- Al hacer clic sobre ellas no realizan ninguna acción.
- El usuario percibe que "solo están como presentación en el menú".

### 1.2 Análisis Técnico y Causa Raíz
Una auditoría minuciosa del registro del sistema y de la implementación de `scripts/Add-OptimizedContextMenus.ps1` reveló un comportamiento anómalo en la función `Set-ShellVerb`:

1. **Bug de Coerción de Tipos en PowerShell (`[string]$SubCommands = $null`)**:
   En la firma de la función `Set-ShellVerb`, el parámetro fue declarado como:
   ```powershell
   param(
       ...
       [string]$SubCommands = $null,
       ...
   )
   ```
   En PowerShell (tanto 5.1 como 7+), cuando un parámetro fuertemente tipado como `[string]` recibe o tiene como valor por defecto `$null`, PowerShell realiza una coerción inmediata a `[string]::Empty` (es decir, una cadena vacía `""` de longitud cero, de tipo `System.String`, y **no** un valor nulo `$null`).

2. **Falla en la Condición de Guarda**:
   En la línea 168 de `scripts/Add-OptimizedContextMenus.ps1`:
   ```powershell
   if ($null -ne $SubCommands) { Set-ItemProperty -Path $psPath -Name "SubCommands" -Value $SubCommands -Force }
   ```
   Como `$SubCommands` fue coaccionado a `""`, la expresión `$null -ne ""` se evaluaba siempre como `$true` en **absolutamente todas las invocaciones**, incluso cuando el parámetro `-SubCommands` no se pasaba.

3. **Inyección Universal de `SubCommands = ""`**:
   Todas y cada una de las entradas creadas (los comandos hijos como `01_PowerMax`, `02_FlushDNS`, `01_TaskMgr`, `01_UEFI`, y las acciones de archivo como `TakeOwnership`, `OpenWithNotepad`, `HashSHA256`) recibieron la propiedad de registro:
   ```reg
   "SubCommands"=""
   ```

4. **Comportamiento del Shell de Windows ante el Valor `SubCommands`**:
   Para el Explorador de Windows (`explorer.exe`), la presencia de un valor llamado `SubCommands` en una clave de menú define inequívocamente que el elemento es una **cabecera de submenú en cascada** (un contenedor) y no un comando ejecutable.
   - En consecuencia, Windows Explorer **ignora por completo la subclave `command`**.
   - Al estar `SubCommands` vacío y sin una subclave `shell` con nuevos hijos, Windows Explorer lo interpreta como un contenedor sin elementos válidos o inerte.
   - Visualmente aparece el texto (a veces deshabilitado o no reaccionando al evento de clic), imposibilitando cualquier ejecución.

---

## 2. Objetivos del Plan

1. **Corregir `Set-ShellVerb` en `scripts/Add-OptimizedContextMenus.ps1`**:
   - Reemplazar la evaluación ingenua `$null -ne $SubCommands` por verificación estricta de parámetros enlazados: `$PSBoundParameters.ContainsKey('SubCommands')`.
   - Si un elemento **no** especifica `-SubCommands`, asegurar explícitamente la eliminación de cualquier valor previo residual mediante `Remove-ItemProperty -LiteralPath $psPath -Name "SubCommands" -Force -ErrorAction SilentlyContinue` (mecanismo de auto-sanación).
   - Para los contenedores en cascada (donde sí se pasa `-SubCommands`), asegurar que `(default)` quede vacío (`""`) para que Windows Explorer use `MUIVerb` y no intente invocar una acción por defecto.

2. **Robustecer Comandos Ejecutables**:
   - En `01_PowerMax`, asegurar que si el GUID del plan de energía `e9a42b02-d5df-448d-aa00-03f14749eb61` no existe en el sistema donde se ejecuta, lo duplique de forma transparente antes de activarlo.
   - Revisar las rutas de comillas de todos los verbos para evitar truncamiento de argumentos.

3. **Crear Lanzador de Hotfix para el Sistema Instalado en Vivo**:
   - Proveer un ejecutable por lotes `Aplicar-Hotfix-Menus.cmd` que solicite elevación de Administrador UAC, invoque el script corregido en ámbitos `CurrentUser` y `AllUsers`, y reinicie `explorer.exe` para que los menús queden 100% operativos al instante.

4. **Pruebas Unitarias de Regresión en `scripts/Test-OptimizedISO-v2.ps1`**:
   - Incorporar pruebas que validen que ningún comando de acción contenga la propiedad `SubCommands`.
   - Validar que los contenedores en cascada mantengan su estructura canónica.

---

## 3. Matriz de Archivos Afectados

| Archivo | Acción | Descripción |
|---|---|---|
| `scripts/Add-OptimizedContextMenus.ps1` | MODIFICAR | Corregir `Set-ShellVerb` con `$PSBoundParameters`, auto-sanación de `SubCommands`, y saneamiento de contenedores. |
| `Aplicar-Hotfix-Menus.cmd` | NUEVO | Lanzador batch con elevación UAC para aplicar la corrección de inmediato en la máquina instalada. |
| `scripts/Test-OptimizedISO-v2.ps1` | MODIFICAR | Pruebas unitarias de regresión para validar la ausencia de `SubCommands` en comandos hijos. |
| `docs/plans/README.md` | MODIFICAR | Registrar PLAN-0031 en el índice de planes. |

---

## 4. Plan de Verificación

### 4.1 Verificación de Sintaxis y BOM
- Validar formato `UTF-8 con BOM` (`0xEF, 0xBB, 0xBF`) en todos los archivos `.ps1`.
- Validación en frío con Windows PowerShell 5.1 nativo:
  ```powershell
  & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'scripts\Add-OptimizedContextMenus.ps1' -WhatIf }"
  ```

### 4.2 Verificación de Registro (Auditoría Empírica)
- Comprobar que en `HKCU` y `HKLM`:
  - `Directory\Background\shell\GamerTools\shell\01_PowerMax` **NO** contenga `SubCommands`.
  - `Directory\Background\shell\SystemTools\shell\01_TaskMgr` **NO** contenga `SubCommands`.
  - `*\shell\TakeOwnership` **NO** contenga `SubCommands`.
  - Los contenedores padre (`GamerTools`, `SystemTools`, `PowerOptions`) sí contengan `SubCommands=""` y `(default)=""`.

### 4.3 Verificación con la Suite de Pruebas
- Ejecución completa de `scripts/Test-OptimizedISO-v2.ps1` reportando métricas de éxito.
