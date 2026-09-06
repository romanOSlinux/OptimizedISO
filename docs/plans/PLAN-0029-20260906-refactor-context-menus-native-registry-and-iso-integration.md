# PLAN-0029: Refactorización de Menús Contextuales con API Nativa de Registro e Integración Canónica en ISO

**Fecha:** 2026-09-06  
**Estado:** PENDIENTE  
**Rama:** `feature/offline-ui-tweaks`  
**Autor:** Agente Antigravity / Pair-Programming  
**Plan Previo Directo:** [PLAN-0024](PLAN-0024-20260905-gamer-poweruser-context-menus.md) / [PLAN-0027](PLAN-0027-20260906-ecosistema-integral-gestion-drivers.md)  
**Reglas Aplicables:** Regla 0 (Git como fuente de verdad), Regla 4 (UTF-8 con BOM, Windows PowerShell 5.1), Regla 5 (Trazabilidad de Planes), Regla 8 (Prohibición estricta de auto-ejecución) y Regla 9 (SSOT Policy-Engine).

---

## 1. Justificación y Diagnóstico del Problema en Vivo

Tras una auditoría forense del sistema operativo en vivo (instalado a partir de una ISO generada por el proyecto), se comprobó empíricamente que **el menú contextual no es 100% funcional ni accesible de forma inmediata**. Se aislaron cuatro fallas técnicas críticas:

1. **Bloqueo por el Menú Moderno de Windows 11:**
   * El sistema en vivo carece de la clave CLSID `{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}` en `HKCU:\Software\Classes\CLSID`.
   * En Windows 11, el Explorador de archivos oculta por diseño todos los verbos estáticos de shell de terceros tras el submenú *"Mostrar más opciones"* (Shift+F10), rompiendo la inmediatez de 1 solo clic (0 ms de latencia).

2. **Incompatibilidad de Escape en `reg.exe` dentro de PowerShell (`Set-ShellVerb`):**
   * El script `Add-OptimizedContextMenus.ps1` utilizaba llamadas al ejecutable externo `reg.exe add`.
   * Cuando PowerShell 5.1/7 invoca un binario externo pasando cadenas con comillas internas (como argumentos de PowerShell o comandos con comillas para rutas con espacios), el motor de procesos de Windows despoja las comillas exteriores y fragmenta los argumentos.
   * **Resultado empírico:** `reg.exe` arrojó `ERROR: sintaxis incorrecta` en comandos complejos (plan de energía, reparación DISM+SFC, PowerShell Admin), provocando que las cascadas `GamerTools`, `SystemTools` y `PowerOptions` **no se crearan en el registro**. Además, en *Take Ownership*, `reg.exe` despojó las comillas de `"%1"`, haciendo que falle ante rutas con espacios en blanco.

3. **Corrupción de Sintaxis en `SetupComplete.cmd`:**
   * En la plantilla de `SetupComplete.cmd` inyectada en la ISO, la línea de registro para `PSAdmin` contenía:
     `... -LiteralPath \"%V\"' ... >> "%LOG%"`
   * El intérprete de comandos `cmd.exe` confundió `%V` con `%LOG%`, truncando la cadena y grabando en el registro un comando corrupto terminado en `"LOG`, provocando un fallo de sintaxis inmediato al invocar "Terminal (Administrador)".

4. **Falta de Desacoplamiento e Inyección Canónica:**
   * `SetupComplete.cmd` mantenía 50 líneas hardcodeadas de `reg add` duplicadas en lugar de invocar de forma limpia y modular `Add-OptimizedContextMenus.ps1 -Apply -Quiet`.

---

## 2. Objetivos del Plan

1. **Refactorizar `Set-ShellVerb` y `Remove-ShellVerb` a la API Nativa de Registro de PowerShell:**
   * Reemplazar todas las invocaciones a `reg.exe` por cmdlets nativos del proveedor `Registry::` (`New-Item -Force`, `Set-ItemProperty`).
   * Cero despojo de comillas: preservación estricta de `"%1"`, `"%V"` y parámetros anidados.
2. **Robustecer las Cascadas para Windows 10 y Windows 11:**
   * Configurar `MUIVerb`, `SubCommands = ""` y el valor `(Default)` en cada nodo hijo de la cascada para garantizar renderizado inmediato.
3. **Garantizar el Menú Clásico de 1 Solo Clic (0 ms Latencia):**
   * Configurar el CLSID `{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32` con valor predeterminado vacío `""` tanto en `HKCU` como en `HKU\.DEFAULT` para que nuevos usuarios y el usuario actual lo tengan activo de fábrica.
4. **Unificación Canónica en la Generación de ISO (`New-OptimizedWindowsISO-v2.ps1` y `SetupComplete.cmd`):**
   * Reemplazar las líneas batch `reg add` de `SetupComplete.cmd` por la invocación directa a `Add-OptimizedContextMenus.ps1 -Apply -Quiet`.
5. **Validación y Aplicación en Vivo:**
   * Tras la aprobación del usuario, aplicar la suite refactorizada en el sistema en caliente con `-Apply -RestartExplorer` y auditar que cada opción funcione a la perfección.

---

## 3. Arquitectura y Archivos Involucrados

```
OptimizedISO/
├── scripts/
│   ├── Add-OptimizedContextMenus.ps1          [MODIFICAR] Migrar Set-ShellVerb a API nativa de registro
│   ├── New-OptimizedWindowsISO-v2.ps1         [MODIFICAR] Delegar SetupComplete.cmd en Add-OptimizedContextMenus.ps1
│   ├── romanOS-Toolkit.ps1                    [AUDITAR] Verificar opciones de menú contextual existentes
│   └── tests/
│       └── Test-ContextMenus.ps1              [NUEVO/EXPANDIR] Pruebas unitarias de sintaxis y registro
```

---

## 4. Fases de Implementación Detalladas

### Fase 1: Refactorización de `scripts/Add-OptimizedContextMenus.ps1`
- Reescribir `Set-ShellVerb`:
  ```powershell
  function Set-ShellVerb {
      param(
          [Parameter(Mandatory=$true)][string]$Path,
          [string]$DisplayName = "",
          [string]$MUIVerb = "",
          [string]$Icon = "",
          [string]$Command = "",
          [string]$Position = "",
          [string]$AppliesTo = "",
          [string]$SubCommands = $null,
          [switch]$HasLUAShield,
          [switch]$NeverDefault,
          [switch]$SeparatorBefore,
          [switch]$SeparatorAfter
      )
      # Uso estricto de PSDrive Registry (HKLM:, HKCU:, etc.)
      if (-not (Test-Path $Path)) {
          New-Item -Path $Path -Force | Out-Null
      }
      if ($DisplayName) { Set-ItemProperty -Path $Path -Name "(default)" -Value $DisplayName -Force }
      if ($MUIVerb)     { Set-ItemProperty -Path $Path -Name "MUIVerb" -Value $MUIVerb -Force }
      if ($Icon)        { Set-ItemProperty -Path $Path -Name "Icon" -Value $Icon -Force }
      if ($Position)    { Set-ItemProperty -Path $Path -Name "Position" -Value $Position -Force }
      if ($AppliesTo)   { Set-ItemProperty -Path $Path -Name "AppliesTo" -Value $AppliesTo -Force }
      if ($null -ne $SubCommands) { Set-ItemProperty -Path $Path -Name "SubCommands" -Value $SubCommands -Force }
      if ($HasLUAShield) { Set-ItemProperty -Path $Path -Name "HasLUAShield" -Value "" -Force }
      if ($NeverDefault) { Set-ItemProperty -Path $Path -Name "NeverDefault" -Value "" -Force }
      if ($SeparatorBefore) { Set-ItemProperty -Path $Path -Name "SeparatorBefore" -Value "" -Force }
      if ($SeparatorAfter)  { Set-ItemProperty -Path $Path -Name "SeparatorAfter" -Value "" -Force }
      if ($Command) {
          $cmdPath = Join-Path $Path "command"
          if (-not (Test-Path $cmdPath)) { New-Item -Path $cmdPath -Force | Out-Null }
          Set-ItemProperty -Path $cmdPath -Name "(default)" -Value $Command -Force
      }
  }
  ```
- Corregir `Enable-ClassicContextMenu`:
  - Usar `Set-ItemProperty` nativo para escribir `(default) = ""` en `HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32`.
- Asegurar codificación UTF-8 con BOM y compatibilidad con Windows PowerShell 5.1.

### Fase 2: Unificación en `SetupComplete.cmd` y `New-OptimizedWindowsISO-v2.ps1`
- En el generador de `SetupComplete.cmd` dentro de `New-OptimizedWindowsISO-v2.ps1`:
  - Eliminar las llamadas propensas a errores `reg add` de menús contextuales.
  - Reemplazarlas por:
    ```cmd
    echo [%DATE% %TIME%] Registrando Suite de Menus Contextuales (Add-OptimizedContextMenus.ps1)... >> "%LOG%"
    if exist "%SCRIPTS_DIR%\Add-OptimizedContextMenus.ps1" (
        "%PS%" -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\Add-OptimizedContextMenus.ps1" -Apply -Quiet >> "%LOG%" 2>&1
    )
    ```

### Fase 3: Validación Empírica en el Sistema en Vivo
- Ejecutar en caliente:
  `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "C:\OptimizedISO\scripts\Add-OptimizedContextMenus.ps1" -Apply -RestartExplorer`
- Comprobar que en el Escritorio aparezcan:
  - Terminal (Administrador)
  - Reiniciar Explorador de Windows
  - Submenú *Gaming y Rendimiento ⚡* (Plan Máximo Rendimiento, Vaciar Caché DNS, HAGS, Modo de Juego)
  - Submenú *Herramientas del Sistema ⚙️* (Administrador de Tareas, Dispositivos, Red, Servicios, Limpieza, DISM+SFC, God Mode)
  - Submenú *Opciones de Energía ⚡* (Reiniciar en UEFI/BIOS, Opciones de Recuperación, Apagado Completo)
- Comprobar que al hacer clic derecho en cualquier archivo/carpeta aparezca:
  - *Tomar Posesión (Take Ownership)*
  - *Calcular Hash SHA-256*
  - *Bloquear / Permitir en Firewall* (en archivos `.exe`)

---

## 5. Plan de Pruebas y Criterios de Aceptación

1. **Prueba de Sintaxis en Windows PowerShell 5.1 (Regla 4):**
   `& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & '.\scripts\Add-OptimizedContextMenus.ps1' -WhatIf }"`
   - Cero `ParserError`, `ParseException` o fallos de comillas.
2. **Prueba de Verbos Registrados en `HKLM` y `HKCU`:**
   - Todas las subclaves `command` creadas con sus valores intactos (`"%1"`, `"%V"`, scripts PowerShell).
3. **Verificación Visual en Vivo:**
   - Clic derecho en escritorio abre inmediatamente el menú clásico con todas las opciones operativas.
