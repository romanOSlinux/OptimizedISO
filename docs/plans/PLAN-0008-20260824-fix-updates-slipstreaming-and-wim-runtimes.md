# PLAN-0008 — Corrección de Slipstreaming de Updates (Dependencias / Timeouts) e Inyección Offline Estructural de Runtimes en WIM

**Fecha:** 2026-08-24  
**Estado:** COMPLETADO  
**Autor:** Antigravity (par de programación IA)  
**Rama objetivo:** `feature/offline-ui-tweaks`

---

## 1. Descripción del Problema y Causa Raíz

Tras analizar los logs de la ejecución `ISO_Build_20260824_130739.log` y el transcript, se identificaron dos fallos críticos interconectados:

### A. Fallo en Slipstreaming de Actualizaciones (Windows Updates)
1. **Error de Dependencias (Exit Code 552 en KB5043080):**
   `KB5043080` es el Checkpoint Cumulative Update (PSF) de Windows 11 24H2. DISM arrojó `552` (`DISM_E_MULTIPLE_UNSATISFIED_DEPENDENCIES`) porque requiere que la pila de servicio (SSU) esté en un nivel compatible antes de inyectarse.
2. **Timeout de 900s (15 min) en LCU (`KB5121003` de 4.8 GB):**
   El paquete acumulativo pesado de 4.8 GB fue abortado por el watchdog al superar los 900s. El kill forzado del PID dejó locks abiertos en el scratch directory y corrompió el estado de servicing de DISM.
3. **Fallo en ResetBase (`-2146498554` = `0x80096006`):**
   Debido a los errores de inyección previa y el estado inconsistente de la imagen, `StartComponentCleanup /ResetBase` colapsó con error de catálogo dañado.

### B. Fallo Estructural en Inyección Offline de Runtimes y Colapso de Desmontaje
1. **Lógica de Inyección de Runtimes en Lugar Incorrecto:**
   En `New-OptimizedWindowsISO-v2.ps1` (líneas 5951-5965), la inyección de Runtimes offline se ubicó de manera anómala dentro del bloque `finally` de descarga del registro (`$hiveLoaded`), intentando desmontar (`Invoke-SafeWimDismount`) antes de tiempo.
2. **Variable `$wimScriptsDir` Nula (`Path is null`):**
   Se llamó a `Join-Path $wimScriptsDir "Runtimes"` **antes** de inicializar `$wimScriptsDir = Join-Path $WimMountDir "Windows\Setup\Scripts"`.
3. **Excepción Fatal no Capturada e Imposibilidad de Desmontar:**
   El error `Cannot bind argument to parameter 'Path' because it is null` interrumpió el bloque de inyección del índice WIM, saltó al manejador `catch`, impidió la inyección de `SetupComplete.cmd`, dejó el colmenar `HKLM\OfflineDefaultUser` abierto y forzó un desmontaje con `/Discard` que descartó todos los cambios realizados.

---

## 2. Objetivos de la Corrección

1. **Reestructurar el Paso 5/6:**
   - Ubicar la inyección offline de Runtimes en su propia sección independiente y visible dentro del WIM (`$wimScriptsDir\Runtimes`), garantizando que `$wimScriptsDir` esté siempre inicializado.
   - Aislar el ciclo de vida del hive del registro (`reg load` -> aplicar tweaks -> `reg unload`) asegurando que el registro **siempre** se descargue de forma limpia antes de cualquier otra operación o desmontaje.
2. **Robustecer el Motor de Slipstreaming de Actualizaciones:**
   - Aumentar el timeout configurable para paquetes LCU pesados (>2 GB) a 1800s (30 min) para evitar kills prematuros de DISM.
   - Ordenar y manejar dependencias SSU -> Checkpoint -> LCU -> .NET con validación de pre-requisitos.
   - Si un paquete acumulativo o checkpoint falla, registrar advertencia detallada pero garantizar que el estado de DISM no contamine el resto del script ni bloquee el desmontaje con `/Commit`.
   - Limpieza preventiva de colmenas y handles huérfanos antes de desmontar el WIM.
3. **Validación y Arnés de Pruebas:**
   - Comprobar compatibilidad en Windows PowerShell 5.1 y validar con `Invoke-TestSuite.ps1` y `Test-OptimizedISO-v2.ps1`.

---

## 3. Plan de Cambios Detallado

### Componente 1: Corrección de Flujo en `New-OptimizedWindowsISO-v2.ps1` (Paso 5/6)

1. **Ajuste de Timeouts para LCU en `Invoke-MonitoredProcess`:**
   - Detectar si el tamaño del `.msu` supera 1 GB y ajustar dinámicamente el timeout a 1800s (o permitir timeout adaptativo según tamaño).
2. **Separación Limpia de Bloques:**
   - Bloque 1: `Get-WimPatchLevel` y `.NET Framework 3.5`
   - Bloque 2: Slipstreaming de Actualizaciones (.msu/.cab)
   - Bloque 3: Inyección de Drivers (.inf)
   - Bloque 4: Features on Demand (FOD)
   - Bloque 5: Debloat AppX
   - Bloque 6: StartComponentCleanup / ResetBase (con manejo de excepciones seguro)
   - Bloque 7: Tweaks Visuales en NTUSER.DAT (Load -> Tweaks -> Unload en bloque `try/finally` estricto sin dependencias externas)
   - Bloque 8: Inyección de Scripts, SetupComplete.cmd, Herramientas y **Runtimes Offline en WIM** (`$wimScriptsDir\Runtimes`) con logs explícitos `Write-OK` / `Write-Info`
   - Bloque 9: Desmontaje seguro y guardado (`Invoke-SafeWimDismount -Action Save`)

---

## 4. Plan de Verificación

```powershell
# 1. Verificar sintaxis AST y compatibilidad con PowerShell 5.1
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "scripts/Invoke-TestSuite.ps1" -Quick

# 2. Ejecutar arnés de pruebas unitarias
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "scripts/Test-OptimizedISO-v2.ps1"
```
