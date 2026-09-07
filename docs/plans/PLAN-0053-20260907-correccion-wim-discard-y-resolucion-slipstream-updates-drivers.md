# PLAN-0053: Corrección de Descarte de WIM (WIM Discard) y Resolución de Slipstreaming de Actualizaciones y Controladores

- **ID del Plan:** PLAN-0053
- **Fecha:** 2026-09-07
- **Autor:** romanOS Engineering & Antigravity Agent
- **Estado:** COMPLETADO
- **Área:** Builder (`New-OptimizedWindowsISO-v2.ps1`), Servicing WIM Offline, Slipstreaming de MSU y Drivers

---

## 1. Contexto y Diagnóstico Empírico

Durante la ejecución real del Builder utilizando el perfil automatizado `Preset_romanOS_20260907_142156.json`, la auditoría forense de los logs generados en `WinISO_Optimizado\Logs\` (`ISO_Build_20260907_142156.log`, `..._AI_SUMMARY.md` y `..._transcript.log`) reveló tres defectos críticos encadenados:

1. **Fallo Crítico de WIM Servicing (WIM Discard):**
   - En el Paso 5/6, al inyectar los módulos complementarios en el WIM montado, la variable `$wimModulesDest` no estaba inicializada (`$null`).
   - La llamada `Join-Path $wimModulesDest "Optimize-WebBrowsers.ps1"` provocó la excepción terminante:
     `"No se puede enlazar el argumento al parámetro 'Path' porque es nulo."`
   - El bloque `catch` de seguridad de DISM actuó desmontando la imagen WIM con la acción `Discard` (`DismMount-Image /Discard`).
   - **Consecuencia:** Se descartaron todas las optimizaciones offline (Debloat de 41 paquetes AppX, .NET Framework 3.5, eliminación de FOD, temas oscuros y tweaks de registro en NTUSER, SOFTWARE y SYSTEM). La ISO final empaquetó el WIM original sin modificaciones.

2. **Enmascaramiento de Windows Updates (Slipstreaming Omitido):**
   - En el Paso 0 (preflight), el builder detectó correctamente 3 paquetes MSU en `C:\OptimizedISO\Updates` (5.7 GB en total: Checkpoint KB5043080, LCU KB5121003 y .NET KB5122385).
   - En el Paso 5, el script sobreescribió `$resolvedUpdatesDir = $null` y evaluó `$candidateUpdates` comprobando únicamente `Test-Path $cand` sin verificar si contenía archivos `.msu` o `.cab`.
   - Al encontrar `(Join-Path $ScriptsDir "Updates")` (`C:\OptimizedISO\scripts\Updates`), que existe físicamente pero contiene únicamente un manifiesto JSON, detuvo la búsqueda y emitió:
     `Carpeta 'C:\OptimizedISO\scripts\Updates' encontrada pero sin archivos .msu/.cab.`
   - **Consecuencia:** Se omitió por completo el slipstreaming de los parches oficiales de Windows Update.

3. **Enmascaramiento de Drivers (Directorio Confuso):**
   - En el Paso 5, `$candidateDrivers` priorizó `(Join-Path $ScriptsDir "Drivers")` (`scripts\Drivers`) mediante un simple `Test-Path`.
   - Esa carpeta contiene las herramientas de gestión en PowerShell (`Backup-HardwareDrivers.ps1`, `Clean-DriverStore.ps1`, `Get-CriticalDrivers.ps1`), no controladores `.inf`.
   - El script emitió: `Carpeta 'C:\OptimizedISO\scripts\Drivers' encontrada pero sin archivos .inf.`
   - **Consecuencia:** Si existieran controladores en `C:\OptimizedISO\Drivers`, se omitirían; y al no existir, se genera un mensaje de diagnóstico engañoso.

---

## 2. Objetivos Técnicos

1. **Garantizar la Persistencia del WIM (Cero Discards):**
   - Inicializar canónicamente `$wimModulesDest = Join-Path $wimScriptsDir "Modules"` en el Paso 5/6.
   - Asegurar la creación física del directorio si no existe con `New-Item -ItemType Directory -Force`.
   - Eliminar las referencias cruzadas residuales de variables `$OEM$` (`$destModulesDir`, `$destModulesDir1`) dentro del ámbito de servicio WIM.
   - Copiar de forma segura todos los scripts y submódulos a `$wimScriptsDir` y `$wimModulesDest`.

2. **Reutilizar y Fortalecer la Resolución Canónica de Updates:**
   - En el Paso 5/6, aprovechar la resolución realizada en el Paso 0 (`$resolvedUpdatesDir`).
   - En caso de reevaluación, comprobar obligatoriamente `(Get-ChildItem -Path $cand -Include *.msu, *.cab -Recurse -File).Count -gt 0` antes de seleccionar el directorio.
   - Priorizar la carpeta raíz de descargas `Updates/` sobre las carpetas de scripts en `scripts/Updates/`.

3. **Resolver Canónicamente la Inyección de Drivers:**
   - En el Paso 5/6, aprovechar `$resolvedDriversDir` del Paso 0 o comprobar `(Get-ChildItem -Path $cand -Include *.inf -Recurse -File).Count -gt 0`.
   - Si no hay archivos `.inf`, mantener `$resolvedDriversDir = $null` y omitir limpiamente sin emitir falsas advertencias sobre carpetas de scripts.

4. **Blindar el Test Harness (`Test-OptimizedISO-v2.ps1`):**
   - Agregar aserciones estáticas y semánticas que verifiquen:
     a) Definición e inicialización explícita de `$wimModulesDest` en Paso 5.
     b) Ausencia de variables `$OEM$` residuales en el bloque WIM.
     c) Verificación de archivos binarios (.msu/.inf) en la resolución de Paso 5.

---

## 3. Plan de Cambios Detallado

### Componente 1: `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`

#### Cambio A: Resolución Robusta de Updates en Paso 5 (Líneas ~5341-5355)
- Reutilizar `$resolvedUpdatesDir` si ya fue validado en Paso 0 y contiene archivos `.msu` o `.cab`.
- Si no está definido, buscar en `$candidateUpdates` comprobando `(Get-ChildItem -Path $cand -Include *.msu, *.cab -Recurse -File).Count -gt 0`.

#### Cambio B: Resolución Robusta de Drivers en Paso 5 (Líneas ~5531-5545)
- Reutilizar `$resolvedDriversDir` si ya fue validado en Paso 0 y contiene archivos `.inf`.
- Si no está definido, verificar que `(Get-ChildItem -Path $cand -Include *.inf -Recurse -File).Count -gt 0`.

#### Cambio C: Inicialización de `$wimModulesDest` y Limpieza de Variables Residuales (Líneas ~6280-6315)
- Reemplazar `$destModulesDir` y `$destModulesDir1` por:
  ```powershell
  $wimModulesDest = Join-Path $wimScriptsDir "Modules"
  if (-not (Test-Path $wimModulesDest)) {
      New-Item -ItemType Directory -Path $wimModulesDest -Force | Out-Null
  }
  ```
- Corregir strings con codificación rota (`Ã­ndice` -> `índice`).
- Asegurar que `$suiteSubmodules` inyecte tanto en `$wimScriptsDir` como en `$wimModulesDest`.

### Componente 2: `scripts/Testing/Test-OptimizedISO-v2.ps1`

- Añadir sección de pruebas `PLAN-0053`:
  - `Assert-True` para inicialización de `$wimModulesDest`.
  - `Assert-False` para `$destModulesDir` dentro del bloque WIM.
  - `Assert-True` para comprobación de archivos `.msu`/`.cab` en Paso 5.
  - `Assert-True` para comprobación de archivos `.inf` en Paso 5.

---

## 4. Plan de Verificación

1. **Auditoría Estática:**
   - Verificación de codificación UTF-8 con BOM en scripts modificados.
   - Parseo AST en Windows PowerShell 5.1 con 0 errores de sintaxis.
2. **Ejecución de la Suite de Pruebas:**
   - Ejecutar `Test-OptimizedISO-v2.ps1` y confirmar 100% PASS (0 fallos).
3. **Simulación de Resolución:**
   - Ejecutar un script de prueba que verifique que con la estructura actual del repositorio:
     - Updates resuelve a `C:\OptimizedISO\Updates` (con 3 paquetes MSU).
     - Drivers resuelve a `$null` (omisión limpia sin falso positivo).
     - `$wimModulesDest` no genera excepciones de parámetro nulo.
