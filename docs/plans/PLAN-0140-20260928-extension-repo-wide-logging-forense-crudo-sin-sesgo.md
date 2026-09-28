# PLAN-0140: Extensión Repo-Wide de Logging Forense Crudo en Texto Plano (Sin Sesgo ni Parámetros Basura)

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0140 |
| **Fecha** | 2026-09-28 |
| **Componentes** | `scripts/Core/UI-Engine.ps1`, `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`, `scripts/Modules/Win11-Debloat-v3-Adaptive.ps1`, `scripts/Modules/Win11-Network-Diagnostics-Optimizer.ps1`, `scripts/Host-Tools/Get-OfficialWindowsISO.ps1`, `scripts/Builder/Get-WindowsUpdates.ps1`, `scripts/Builder/Get-EssentialRuntimes.ps1`, `scripts/Modules/Invoke-WindowsMaintenance.ps1`, `scripts/Testing/Test-OptimizedISO-v2.ps1` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Máxima / Crítica (Erradicación de Sesgos, Estandarización Universal de Logging y Trazabilidad Forense) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM y PS 5.1), Regla 7 (Watchdog y Transparencia), Regla 9 (SSOT), Regla 12 (Protocolo Anti-Sesgo de Logs), Regla 13 (CWE-390 / Fail-Visible Repo-Wide) |

---

## 1. Principio Rector: Cero Encapsulamiento en "Posibles" y Cero Código Basura

El usuario ha ordenado explícitamente erradicar cualquier lista o diccionario estático preconcebido de errores ("posibles errores"), así como cualquier parámetro basura o coexistencia de formatos duplicados de log.

### Principios Fundamentales
1. **Neutralidad de la Caja Negra:** El sistema de log no debe prejuzgar, filtrar con expresiones regulares sesgadas ni intentar clasificar el error en categorías preconcebidas.
2. **Volcado Crudo en Texto Plano (Raw Plain-Text):** Ante cualquier fallo de proceso o excepción, se captura y registra el 100% de la salida textual literal devuelta por el sistema operativo o herramienta:
   - Línea de comando y argumentos exactos ejecutados.
   - Código de salida crudo (`ExitCode` decimal y hexadecimal `0x{0:X8}`).
   - Flujo de salida estándar (`STDOUT`) completo en texto plano.
   - Flujo de error estándar (`STDERR`) completo en texto plano.
   - Contenido final del archivo de log físico asociado (ej. `dism.log`), si aplica.
   - En excepciones de PowerShell: mensaje completo, línea de script y stack trace en plano.
3. **Análisis Individual Posterior:** Toda la evidencia queda íntegra en el log para su posterior análisis forense caso por caso con datos objetivos, sin truncamientos artificiales ni suposiciones.
4. **Unificación y Limpieza Estricta:** Un único formato universal de logging para todo el repositorio (`Write-UnifiedLogEntry`). Eliminados todos los parámetros basura (`SuggestedAction`, `SymbolicName`, `Meaning`, `DiagnosticText`, `DiagnosticLines`) y funciones duplicadas.

---

## 2. Mapa Operacional de Implementación y Certificación

- [x] **Fase 1: Saneamiento y Universalización en `scripts/Core/UI-Engine.ps1`:**
  - Depurados y eliminados diccionarios estáticos de error en `Get-RomanOSErrorCodeDetails` (devuelve únicamente `ExitCodeDecimal` y `ExitCodeHex`).
  - Refactorizado `Write-ForensicProcessFailure` para emitir y registrar el bloque crudo en texto plano íntegro (STDOUT, STDERR y log físico asociado) sin filtros ni sesgos.
  - Refactorizado `Write-ForensicException` para registrar volcado completo crudo (Tipo, HResult, Línea, StackTrace e InnerException) sin parámetros basura (`SuggestedAction`).
  - Codificación UTF-8 con BOM y 0 errores AST en Windows PowerShell 5.1 certificada.
- [x] **Fase 2: Unificación del Builder (`scripts/Builder/New-OptimizedWindowsISO-v2.ps1`):**
  - Eliminada definición duplicada de `Write-ForensicException` y parámetros basura (`SuggestedAction`).
  - `Invoke-MonitoredProcess` entrega `CommandLine`, `ExitCode`, `ExitCodeHex`, `StdOut`, `StdErr` y `FullPlainReport`.
  - Limpiadas llamadas a `Invoke-RomanOSDismComponentRemoval`, `Invoke-RomanOSComponentStoreCleanup` y slipstreaming MSU (.psf y .cab).
  - Sincronizados micro-fallbacks en `if (-not $uiLoaded)`.
- [x] **Fase 3: Extensión a Scripts de Módulos y Descargas:**
  - `Win11-Debloat-v3-Adaptive.ps1`: Vinculado a `$global:RomanOS_LogFile = $script:LogFile`, delegación en `Write-UnifiedLogEntry`, fallback forense sincronizado y logging estructurado en AppX y servicios.
  - `Win11-Network-Diagnostics-Optimizer.ps1`: Vinculado a `$global:RomanOS_LogFile = $script:LogFile`, delegación en `Write-UnifiedLogEntry`, fallback forense sincronizado.
  - `Get-OfficialWindowsISO.ps1`: Vinculado a `$global:RomanOS_LogFile = $script:LogFile`, delegación en `Write-UnifiedLogEntry`, fallback forense sincronizado.
  - `Get-WindowsUpdates.ps1`: Vinculado a `$global:RomanOS_LogFile = $script:LogFile`, delegación en `Write-UnifiedLogEntry`, eliminados parámetros obsoletos `SuggestedAction`.
  - `Get-EssentialRuntimes.ps1`: Vinculado a `$global:RomanOS_LogFile = $script:LogFile`, delegación en `Write-UnifiedLogEntry`, capturada salida cruda de 7-Zip e IExpress en vez de `*>$null`, eliminados parámetros `SuggestedAction`.
  - `Invoke-WindowsMaintenance.ps1`: Vinculado a `$global:RomanOS_LogFile = $logFile`, agregada función `Write-LogEntry`, fallback forense sincronizado y normalización de ExitCode con `Get-RomanOSErrorCodeDetails`.
  - `PostInstall-Diagnostics.ps1`: Fallback forense sincronizado.
- [x] **Fase 4: Certificación de Test Harness y Pruebas Unitarias:**
  - `scripts/Testing/Test-OptimizedISO-v2.ps1`: Agregadas aserciones de normalización de errores y volcado crudo sin campos basura.
  - Ejecución en Windows PowerShell 5.1 (`powershell.exe`): **610/610 PASS (100%)**, 0 fallos.
  - Ejecución de arnés maestro `Invoke-RomanOSHarness.ps1 -Fast`: **5/5 PASS (100%)**, 0 errores AST, 100% UTF-8 BOM, 0 bloques catch vacíos.
  - Búsqueda repo-wide de residuos: CERO residuos de `SymbolicName`, `SuggestedAction`, `DiagnosticText`, `DiagnosticLines`.
- [x] **Fase 5: Erradicación del Segundo Tipo de Log (PadRight) y Estandarización AppendAllText:**
  - Identificada y eliminada la discrepancia donde `New-OptimizedWindowsISO-v2.ps1` y los fallbacks utilizaban `PadRight(5)` produciendo líneas heterogéneas (`[INFO ]` vs `[INFO]`).
  - `Write-LogEntry` en `New-OptimizedWindowsISO-v2.ps1` unificado para delegar en `Write-UnifiedLogEntry`.
  - Reemplazado `[System.IO.File]::AppendAllLines` por `[System.IO.File]::AppendAllText($file, ($line + "`r`n"), [System.Text.Encoding]::UTF8)` en todos los módulos, solucionando la incompatibilidad de sobrecarga de métodos en Windows PowerShell 5.1 (.NET Framework).
  - DISM en `Invoke-WindowsMaintenance.ps1` actualizado para emitir `Write-ForensicProcessFailure` conectando el log físico `dism.log`.
  - Micro-fallback en `Invoke-WindowsSecurityHardening.ps1` actualizado con soporte forense integral.
- [x] **Fase 6: Registro Atómico en Git y Sincronización:**
  - Certificación con 610/610 pruebas pasadas (100% PASS) y 5/5 en el arnés maestro.
  - Commit atómico `2e3c859` registrado tras superar 14 fases de pre-commit hooks.
