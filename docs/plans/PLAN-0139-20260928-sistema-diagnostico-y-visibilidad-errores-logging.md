# PLAN-0139: Sistema de Diagnóstico Forense y Visibilidad Total de Errores en Logging (Erradicación de Advertencias Ciegas)

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0139 |
| **Fecha** | 2026-09-28 |
| **Componentes** | `scripts/Core/UI-Engine.ps1`, `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`, `scripts/Modules/`, reportes `AI_SUMMARY.md` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Máxima / Crítica (Erradicación de Fallos Silenciosos CWE-390 / Fail-Visible y Trazabilidad Operativa) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM y PS 5.1), Regla 7 (Watchdog y Transparencia), Regla 9 (SSOT), Regla 12 (Protocolo Anti-Sesgo de Logs), Regla 13 (CWE-390 / Fail-Visible Repo-Wide) |

---

## 1. Justificación y Causa Raíz

En la auditoría forense del último log de compilación de ISO (`ISO_Build_20260927_214748.log`), se evidenció una deficiencia crítica: cuando un subproceso nativo de Windows (`dism.exe`, `oscdimg.exe`, `expand.exe`, etc.) falla o devuelve un código no estándar, el sistema emite una advertencia ciega (`[WARN]`) con un código numérico opaco (`ExitCode: 87`, `ExitCode: 552`, `ExitCode: -2146498554`), sin indicar:
1. Qué devolvió realmente el comando en su salida estándar (`STDOUT` / `STDERR`).
2. Cuál es el significado técnico de dicho código en el subsistema Win32 o CBS de Microsoft.
3. Qué causa técnica motivó la omisión o el fallo de la acción.
4. Qué evidencia contenía el archivo de log temporal de DISM antes de ser purgado en la carpeta de scratch.

### Deficiencias Arquitectónicas Identificadas
1. **Filtro Erróneo de Canales en `Invoke-MonitoredProcess`:** `dism.exe` y la mayoría de utilidades de línea de comandos de Windows escriben sus mensajes de error en `STDOUT`, no en `STDERR`. El código actual evaluaba únicamente `if ($stderr) { ... }`, descartando por completo el mensaje explicativo del comando.
2. **Ausencia de Decodificador HRESULT / Win32:** Los enteros con signo (`-2146498554`) o códigos decimales (`87`, `552`) no eran transformados a hexadecimal (`0x800F0806`, `0x57`, `0x228`) ni mapeados a sus constantes canónicas de Microsoft (`CBS_E_PENDING`, `ERROR_INVALID_PARAMETER`, `ERROR_PACKAGE_ALREADY_EXISTS`).
3. **Pérdida de Logs Temporales:** La carpeta `C:\WinISO_Scratch_...` se elimina al terminar el proceso, borrando los logs generados con `/LogPath` antes de que el usuario o el desarrollador puedan consultarlos.
4. **Mensajería Reducida en Scripts Consumidores:** `Invoke-RomanOSDismComponentRemoval` e `Invoke-RomanOSComponentStoreCleanup` emitían cadenas mínimas como `Fallo al remover Capability '...' (ExitCode: 87)` en lugar de un diagnóstico accionable.

---

## 2. Objetivos de Implementación

1. **SSOT en `UI-Engine.ps1`:**
   - Crear la función canónica `Get-RomanOSErrorCodeDetails` para traducir códigos Win32 y HRESULT CBS/DISM.
   - Crear la función `Write-ForensicProcessFailure` para emitir diagnósticos visibles, estructurados y destacados en consola y archivos de log.
2. **Modernización de `Invoke-MonitoredProcess` en el Builder:**
   - Capturar y analizar tanto `STDOUT` como `STDERR`.
   - Extraer automáticamente las líneas de error reales (`Error:`, `Fallo`, `Exception`, `Advertencia` o las últimas líneas).
   - Si se pasó un `/LogPath` a DISM y el comando falló, extraer las últimas líneas del archivo `.log` antes de purgar la carpeta de trabajo.
   - Enriquecer el objeto de retorno (`DiagnosticMessage`, `ErrorCodeHex`, `ErrorMeaning`).
3. **Actualización de Consumidores Específicos:**
   - `Invoke-RomanOSDismComponentRemoval`: Explicar semánticamente el `ExitCode 87` (Capability inexistente o retirada en 24H2/25H2).
   - `Invoke-RomanOSComponentStoreCleanup`: Explicar semánticamente el `0x800F0806` (`CBS_E_PENDING`: /ResetBase diferido por transacciones de actualizaciones acumulativas previas).
   - Slipstreaming MSU: Explicar semánticamente el `ExitCode 552` (`ERROR_PACKAGE_ALREADY_EXISTS` / Checkpoint redundante).
4. **Modernización de Reportes Diagnósticos (`AI_SUMMARY.md`):**
   - Incorporar la decodificación semántica y causa técnica en la tabla de warnings y resumen final.
5. **Certificación y Pruebas Unitarias:**
   - Validar codificación UTF-8 con BOM en todos los archivos modificados.
   - Certificar compatibilidad en frío contra Windows PowerShell 5.1.
   - Pasar la batería completa de pruebas del test harness.

---

## 3. Matriz de Tareas

- [x] **Fase 1:** Implementación de `Get-RomanOSErrorCodeDetails` y `Write-ForensicProcessFailure` en `scripts/Core/UI-Engine.ps1`.
- [x] **Fase 2:** Refactorización de `Invoke-MonitoredProcess` en `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` con extracción de STDOUT/STDERR y rescate de `dism.log`.
- [x] **Fase 3:** Actualización de diagnósticos semánticos en `Invoke-RomanOSDismComponentRemoval`, `Invoke-RomanOSComponentStoreCleanup` e inyección de MSU.
- [x] **Fase 4:** Actualización de generación de reportes en `AI_SUMMARY.md` y consola.
- [x] **Fase 5:** Validación con `Invoke-RomanOSHarness.ps1` en PS 5.1 y commit atómico.
