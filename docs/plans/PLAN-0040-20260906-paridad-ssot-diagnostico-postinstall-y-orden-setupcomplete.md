# PLAN-0040: Paridad SSOT en Diagnóstico Post-Instalación y Orden Determinista en SetupComplete.cmd

Saneamiento arquitectónico del subsistema de diagnóstico post-instalación en el compilador de ISO, eliminando la duplicación de código (plantilla embebida de 550 líneas), garantizando la paridad con `Policy-Engine.ps1` (30+ directivas) y resolviendo la condición de carrera de logs en `SetupComplete.cmd`.

## User Review Required

> [!IMPORTANT]
> **Eliminación Definitiva de Plantilla Embebida (DRY / SSOT - Regla 9)**:
> Se eliminará la variable de texto `$postInstallDiagTemplate` (~550 líneas) de `New-OptimizedWindowsISO-v2.ps1`. A partir de ahora, la ISO inyectará exclusivamente el archivo físico canónico `scripts/Modules/PostInstall-Diagnostics.ps1`.
> Los parámetros dinámicos (`ExpectedProfile` y `ExpectedBlockOneDrive`) ya no se hardcodearán reemplazando texto en una plantilla, sino que se pasarán como argumentos de línea de comandos en `SetupComplete.cmd` (ej. `-ExpectedProfile 3 -ExpectedBlockOneDrive:$false`).

> [!NOTE]
> **Resolución de la Condición de Carrera en `SetupComplete.cmd`**:
> Se reordenará la secuencia en la plantilla de `SetupComplete.cmd` para que la marca de éxito `SetupComplete.cmd finalizado exitosamente.` se registre en el log **antes** de invocar a `PostInstall-Diagnostics.ps1`. De este modo, la auditoría constatará la finalización con éxito (`[OK]`), eliminando la advertencia falsa alarma (`[WARN]`).

## Open Questions

Ninguna. La solución implementa las reglas obligatorias de SSOT (Regla 9) y mantenimiento en cascada (Regla 10) de `.agents/AGENTS.md`.

## Proposed Changes

### 1. Compilador de Imágenes ISO (`New-OptimizedWindowsISO-v2.ps1`)

#### [MODIFY] [New-OptimizedWindowsISO-v2.ps1](file:///c:/OptimizedISO/scripts/Builder/New-OptimizedWindowsISO-v2.ps1)

- **Reordenamiento en `SetupComplete.cmd`**:
  En la plantilla `$setupCompleteTemplate`, mover el registro del log de éxito:
  ```cmd
  echo [%DATE% %TIME%] SetupComplete.cmd finalizado exitosamente. >> "%LOG%"
  
  REM Auditoria y Diagnostico Integral Post-Instalacion
  if exist "%SCRIPTS_DIR%\PostInstall-Diagnostics.ps1" (
      "%PS%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\PostInstall-Diagnostics.ps1" -DesktopOutput -ExpectedProfile __OPT_PROFILE__ -ExpectedBlockOneDrive:__BLOCK_ONEDRIVE__ >> "%LOG%" 2>&1
  )
  exit /b 0
  ```
- **Eliminar `$postInstallDiagTemplate`**:
  Remover por completo el bloque de texto `postInstallDiagTemplate = @' ... '@` (~550 líneas).
- **Inyección Canónica en `$OEM$`**:
  Asegurar que la copia física de `$physicalDiag` (que ya se realiza en líneas 3978-3982) no sea sobreescrita.
  En líneas 4774-4780, eliminar la sobreescritura de `$postInstallDiagPath` con el contenido de la plantilla.
- **Inyección Canónica en el WIM montado**:
  En líneas 6439-6446, simplificar para copiar siempre `$physicalDiag` al WIM sin recurrir a plantillas de texto.
- **Actualizar `Auditar-Instalacion.cmd`**:
  Asegurar que invoque `-ExpectedProfile __OPT_PROFILE__` y enlace correctamente con el diagnóstico.

---

### 2. Arnés de Pruebas Unitarias (`Test-OptimizedISO-v2.ps1`)

#### [MODIFY] [Test-OptimizedISO-v2.ps1](file:///c:/OptimizedISO/scripts/Testing/Test-OptimizedISO-v2.ps1)

- Actualizar la FASE 2K (líneas 580-610):
  - Reemplazar la aserción obsoleta `Assert-True "PostInstall: Plantilla PostInstall-Diagnostics.ps1 presente en v2"` por la verificación de que `New-OptimizedWindowsISO-v2.ps1` inyecta `PostInstall-Diagnostics.ps1` desde el archivo físico canónico (`$physicalDiag` / `$diagSourceCandidates`).
  - Probar sintaxis y ejecución en sandbox del archivo físico `scripts/Modules/PostInstall-Diagnostics.ps1` directamente.

---

## Verification Plan

### Automated Tests
- Ejecutar en frío contra Windows PowerShell 5.1:
  ```powershell
  & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'c:\OptimizedISO\scripts\Testing\Test-OptimizedISO-v2.ps1' }"
  ```
- Validar que todos los tests pasen (100% PASS) sin errores de AST ni colapso de codificación.

### Manual Verification
- Comprobar que en `New-OptimizedWindowsISO-v2.ps1` ya no exista código muerto duplicado (`$postInstallDiagTemplate`).
- Simular la ejecución de `PostInstall-Diagnostics.ps1` validando que reconozca la marca de `SetupComplete.cmd` como `[OK]`.
- Verificar codificación estricta UTF-8 con BOM (`0xEF, 0xBB, 0xBF`) en todos los archivos modificados según Regla 4.

---

## Resultados de Ejecución y Validación

- **Estado:** `COMPLETADO`
- **Fecha:** 2026-09-06
- **Resultados:**
  - `New-OptimizedWindowsISO-v2.ps1`: 580 líneas de código duplicado eliminadas. Se inyecta exclusivamente el script físico `PostInstall-Diagnostics.ps1` y se eliminó la sobreescritura con plantilla embebida.
  - `SetupComplete.cmd`: La marca de éxito se registra antes de la llamada a diagnósticos, resolviendo la condición de carrera y el falso positivo `[WARN]`.
  - `Test-OptimizedISO-v2.ps1`: 12/12 pruebas del subsistema PostInstall pasaron con 100% PASS.
  - Codificación UTF-8 con BOM validada en todos los scripts modificados.
