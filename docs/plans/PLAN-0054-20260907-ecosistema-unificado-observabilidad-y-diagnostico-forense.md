# PLAN-0054: Ecosistema Unificado de Observabilidad, Telemetría y Diagnóstico Forense para Toda la Suite de Scripts

- **ID del Plan:** PLAN-0054
- **Fecha:** 2026-09-07
- **Autor:** romanOS Engineering & Antigravity Agent
- **Estado:** PENDIENTE
- **Área:** Arquitectura Global (SSOT Observability), `Core\UI-Engine.ps1`, `Builder\`, `Modules\`, `Drivers\`, `Host-Tools\`, `Testing\`

---

## 1. Contexto y Diagnóstico del Problema

Tras la auditoría de los registros de compilación en `WinISO_Optimizado\Logs` y el análisis transversal de la suite de scripts de PowerShell del repositorio, se identificaron cuatro deficiencias graves en la observabilidad y depuración de errores:

1. **Falsa Sensación de Éxito e Inconsistencia entre Fases:**
   - En el Paso 0 (Preflight), el sistema detecta recursos válidos (ej. 3 paquetes de actualización MSU en `Updates/`).
   - En el Paso 5 (Ejecución), si una ruta secundaria o errónea no encuentra los archivos, el proceso omite la inyección sin generar una alarma visible, marcándolo en el resumen final como un simple `SKIP` (omisión opcional).
   - **Consecuencia:** El usuario cree que las actualizaciones o drivers se aplicaron porque en el Paso 0 se detectaron, cuando en realidad fueron omitidos silenciosamente.

2. **Falta de Trazabilidad Forense en Excepciones:**
   - Los bloques `catch` de la mayoría de scripts capturan únicamente `$_.Exception.Message` (ej. *"No se puede enlazar el argumento al parámetro 'Path' porque es nulo"*).
   - **No se registra el número de línea, ni el comando fallido, ni el script de origen, ni la pila de llamadas (`$_.ScriptStackTrace`)*.
   - **Consecuencia:** Ante un fallo en scripts de más de 7,000 líneas, es imposible conocer de inmediato qué variable o comando causó la excepción sin realizar ingeniería inversa forense.

3. **Uso de `Write-Host` Silencioso para Desvíos y Advertencias:**
   - Múltiples scripts imprimen advertencias o fallos usando `Write-Host ... -ForegroundColor DarkYellow` o `Red`.
   - Estos mensajes se pintan en la consola pero **no ingresan al buffer de `$script:LogWarns` / `$script:LogErrors`**, no se guardan en los archivos `.log`, no impactan el contador de incidencias (`WarnsCount` / `ErrorsCount`) ni se reflejan en el reporte ejecutivo `AI_SUMMARY.md`.

4. **Bloques `catch {}` Vacíos (Silenciamiento de Errores):**
   - Diversos scripts auxiliares contienen bloques de captura vacíos (`catch {}`) que tragan excepciones reales (fallos de registro, servicios inexistentes, errores de red o permisos) sin dejar rastro en los diagnósticos.

---

## 2. Objetivos Técnicos

1. **SSOT de Observabilidad en `scripts/Core/UI-Engine.ps1`:**
   - Extender el motor unificado para suministrar primitivas canónicas de diagnóstico forense a todo el ecosistema.
   - Función **`Write-ForensicException`**: Captura mensaje, número de línea (`$_.InvocationInfo.ScriptLineNumber`), instrucción exacta (`$_.InvocationInfo.Line.Trim()`), script y stack trace completo.
   - Función **`Assert-ResourceCommitment`**: Valida contratos de recursos entre fases. Si un recurso fue detectado en Preflight (`Found = $true`), pero en ejecución no se aplica o se marca como `SKIP`, detona una alarma ruidosa (`WARN CRÍTICO` / `ERROR`) explicando causa e impacto.
   - Funciones `Write-Warn` y `Write-ErrorMsg` unificadas: Garantizan salida en consola, escritura en archivo `.log` con timestamp `[YYYY-MM-DD HH:MM:SS]` y acumulación en listas de telemetría global.
   - Estándar de advertencia en 3 puntos: **[Qué sucedió / Por qué sucedió / Acción correctiva sugerida]**.

2. **Actualización en Cascada de Todos los Scripts `.ps1`:**
   - **Builder (`scripts/Builder/New-OptimizedWindowsISO-v2.ps1`):**
     - Sustituir `catch` planos por `Write-ForensicException` en WIM servicing, DISM, Registry hives, 7-Zip y oscdimg.
     - Implementar `Assert-ResourceCommitment` para Updates, Drivers, Runtimes y Motores Core.
     - Erradicar `Write-Host` amarillos y conectarlos a `Write-Warn`.
   - **Descargas (`scripts/Builder/Get-WindowsUpdates.ps1`, `Get-EssentialRuntimes.ps1`):**
     - Telemetría de fallos de red, códigos de estado HTTP, sumas SHA-256 e integridad de paquetes.
   - **Módulos de Optimización (`scripts/Modules/`):**
     - `Win11-Debloat-v3-Adaptive.ps1`, `Invoke-WindowsMaintenance.ps1`, `Invoke-WindowsSecurityHardening.ps1`, `Win11-Network-Diagnostics-Optimizer.ps1`, `Optimize-WebBrowsers.ps1`, `Add-OptimizedContextMenus.ps1`, `PostInstall-Diagnostics.ps1`, `Migrar-Usuario-W11.ps1`, `romanOS-Toolkit.ps1`:
     - Reemplazar salidas directas de consola por `Write-Warn` / `Write-ErrorMsg` / `Write-ForensicException`.
     - Erradicar `catch {}` vacíos mediante logging controlado de nivel `DEBUG` o `WARN`.
   - **Drivers (`scripts/Drivers/`):**
     - `Backup-HardwareDrivers.ps1`, `Clean-DriverStore.ps1`, `Get-CriticalDrivers.ps1`:
     - Trazabilidad de fallos de pnputil y DISM con códigos de error detallados.
   - **Host Tools (`scripts/Host-Tools/`):**
     - `Get-OfficialWindowsISO.ps1`, `Limpiar-ResiduosWinISO.ps1`, `Setup-AntigravityWindows.ps1`:
     - Diagnósticos forenses en descargas y desmontaje forzado de WIMs huérfanos.

3. **Blindaje en el Test Harness (`scripts/Testing/Test-OptimizedISO-v2.ps1` e `Invoke-TestSuite.ps1`):**
   - Incorporar pruebas estáticas que aseguren:
     a) Cero bloques `catch {}` vacíos en el código de producción.
     b) Disponibilidad de `Write-ForensicException` y `Assert-ResourceCommitment` en `UI-Engine.ps1`.
     c) Compatibilidad 100% con Windows PowerShell 5.1 y preservación estricta de `UTF-8 con BOM`.

---

## 3. Plan de Cambios Detallado

### Fase 1: Motor Canónico de Observabilidad (`scripts/Core/UI-Engine.ps1`)
- Agregar variables globales de telemetría: `$global:RomanOS_LogErrors`, `$global:RomanOS_LogWarns`, `$global:RomanOS_LogFile`.
- Implementar `Initialize-UnifiedLog`, `Write-LogEntry`, `Write-ForensicException`, `Assert-ResourceCommitment`.
- Actualizar `Write-Warn` y `Write-ErrorMsg` para que acumulen en telemetría global además de imprimir en consola.

### Fase 2: Implementación en el Builder (`scripts/Builder/New-OptimizedWindowsISO-v2.ps1`)
- Conectar los bloques `catch` de las 6 fases del Builder a `Write-ForensicException`.
- Insertar validaciones de compromiso de recursos entre Paso 0 y Paso 5.
- Reemplazar mensajes huérfanos de `Write-Host` amarillos por `Write-Warn`.

### Fase 3: Estandarización en Módulos y Herramientas
- Refactorizar los 9 scripts de `scripts/Modules/` para consumir `UI-Engine.ps1` de forma uniforme.
- Refactorizar los 3 scripts de `scripts/Drivers/`.
- Refactorizar los scripts de descarga en `scripts/Builder/`.
- Refactorizar los 3 scripts de `scripts/Host-Tools/`.

### Fase 4: Validación y Certificación en Test Harness
- Añadir sección de pruebas `PLAN-0054` en `Test-OptimizedISO-v2.ps1`.
- Ejecutar `Invoke-TestSuite.ps1` (auditoría estática de 36 scripts, BOM, AST).
- Ejecutar suite completa `Test-OptimizedISO-v2.ps1` asegurando 100% PASS (0 fallos).

---

## 4. Criterios de Aceptación

1. **Trazabilidad Inmediata:** Ante cualquier excepción no controlada, el log muestra: `[ERROR] Excepción en <script>:<línea> | Comando: [...] | Mensaje: [...] | StackTrace: [...]`.
2. **Cero Omisiones Ocultas:** Si un recurso fue detectado en Preflight pero omitido en el WIM, se emite obligatoriamente una advertencia crítica con causa raíz.
3. **Cero Regresiones:** Los 36 scripts mantienen 100% compatibilidad con Windows PowerShell 5.1, codificación UTF-8 BOM y superan todas las pruebas del arnés.
