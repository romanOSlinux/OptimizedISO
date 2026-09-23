# PLAN-0106: Refinamiento Asíncrono de WIM Discovery y Enlace Inteligente de ISO en VM Test (romanOS Studio)

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0106 |
| **Fecha** | 2026-09-22 |
| **Componente** | `scripts/GUI/romanOS-Studio.ps1` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Media |
| **Reglas Relevantes** | Regla 0 (Git), Regla 4 (Windows PowerShell 5.1 / UTF-8 BOM), Regla 5 (Planes), Regla 8 (No Auto-Run), Regla 13 (No Silent Failures) |

---

## 1. Contexto y Diagnóstico Forense

Durante la auditoría técnica de los 10 botones de `romanOS-Studio.exe` (y su script fuente `romanOS-Studio.ps1`), se verificó empíricamente que todos los botones son completamente funcionales y que ninguno sufre el problema de congelamiento por `Read-Host` o menús interactivos que afectaba a Control Center.

Sin embargo, se detectaron 2 oportunidades puntuales de robustecimiento en `scripts/GUI/romanOS-Studio.ps1`:

1. **Llamada a función inexistente en RunSpace aislado de WIM Discovery (`Invoke-WimDiscoveryAsync`, L407):**
   - El bloque `catch` del scriptblock ejecutado en el RunSpace secundario intenta invocar `Write-StudioLog`.
   - Como `Write-StudioLog` fue declarada en la sesión principal y los RunSpaces creados con `RunspaceFactory::CreateRunspace()` no heredan funciones ni variables de usuario, si `Mount-DiskImage` o `Get-WindowsImage` lanzan una excepción, el `catch` arroja un error interno de comando no reconocido (`CommandNotFoundException`).
   - Al llamar a `$d.PS.EndInvoke()`, dicha excepción interrumpe la recolección limpia en lugar de devolver la lista vacía de imágenes.
2. **Desacoplamiento de la ISO en `btnTestVM` (`New-TestVM-HyperV.ps1`, L890-L897):**
   - El botón *Levantar Máquina Virtual de Prueba* invoca `New-TestVM-HyperV.ps1` sin ningún argumento.
   - Si el usuario tiene una ISO base especificada en la caja de texto `txtSourceISO` o construyó una ISO en una ruta personalizada, `New-TestVM-HyperV.ps1` depende exclusivamente de buscar en rutas predeterminadas fijas (`Desktop\WinISO_Optimizado`). Si esa carpeta no existe aún o la ISO está en otra ruta seleccionada por el usuario, el script falla informando que no encontró ninguna ISO.

---

## 2. Plan de Modificaciones Propuesto

### A. Refactorización de `Invoke-WimDiscoveryAsync`
1. Pasar la ruta del log oficial `$script:StudioLogPath` como parámetro `$LogPath` al scriptblock del RunSpace.
2. Reemplazar la llamada a `Write-StudioLog` dentro del RunSpace por escritura directa y resiliente mediante `[System.IO.File]::AppendAllText` con timestamp y formateo UTF-8.
3. En el despachador de la interfaz de usuario (`$timer.Add_Tick`), registrar cualquier fallo de invocación mediante `Write-StudioLog` en el hilo de la UI donde la función sí existe y está garantizada.

### B. Enlace Inteligente de ISO en `btnTestVM`
1. Consultar la existencia de la carpeta de salida optimizada (`$desktopPath\WinISO_Optimizado`). Si contiene archivos `.iso`, tomar la más reciente (comportamiento natural post-build).
2. Si no hay ISOs compiladas en esa carpeta, verificar si el control `txtSourceISO` contiene una ruta válida y existente a un archivo `.iso`.
3. Si se localiza una ISO válida (ya sea la optimizada más reciente o la de origen cargada en pantalla), inyectar el parámetro `-ISOPath '<ruta>'` en la línea de comando.
4. Si no hay ninguna ISO identificada, invocar `New-TestVM-HyperV.ps1` sin parámetros para permitir que su motor de búsqueda secundario actúe e informe al usuario en consola.

---

## 3. Plan de Verificación y Testing

1. **Inspección de Sintaxis y Codificación:**
   - Comprobar que `scripts/GUI/romanOS-Studio.ps1` conserve la codificación obligatoria **UTF-8 con BOM** (`EF BB BF`).
2. **Validación en Windows PowerShell 5.1 (Destino Oficial):**
   - Ejecutar en frío contra `System32\WindowsPowerShell\v1.0\powershell.exe`:
     `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'scripts\GUI\romanOS-Studio.ps1' -WhatIf }"`
   - Verificar código de salida 0 y ausencia de `ParserError`.
3. **Validación de la Suite de Pruebas:**
   - Ejecutar el test harness `Invoke-TestSuite.ps1` para asegurar cero regresiones en el ecosistema.
