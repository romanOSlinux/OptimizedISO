# PLAN-0074: Corrección de Cierre Inesperado de romanOS Studio (Código de Error 5) y Streaming Asíncrono Robusto

**Estado:** COMPLETADO  
**Fecha:** 2026-09-10  
**Autor:** Antigravity AI  
**Componente:** `scripts/GUI/romanOS-Studio.ps1`

---

## 1. Contexto y Diagnóstico Causa Raíz

Al presionar los botones **"📥 Descargar Updates"** o **"⚙️ Runtimes C++/DirectX"** (o cualquier tarea delegada a `Start-StudioSubProcess`), la interfaz gráfica `romanOS-Studio.ps1` se cerraba abruptamente y el lanzador batch reportaba:
```text
[ERROR] romanOS Studio se cerro con codigo de error 5.
Presione una tecla para continuar .
```

### Análisis Forense del Fallo:
1. `Start-StudioSubProcess` empleaba eventos .NET directos sobre `System.Diagnostics.Process`:
   - `$script:workerProcess.add_OutputDataReceived({ ... })`
   - `$script:workerProcess.add_ErrorDataReceived({ ... })`
   - `$script:workerProcess.add_Exited({ ... })`
   - Seguido de `.BeginOutputReadLine()` y `.BeginErrorReadLine()`.
2. En el runtime de destino **Windows PowerShell 5.1 (`powershell.exe` bajo CLR 4.0)**, los eventos asíncronos de procesos del sistema operativo son disparados por el runtime en hilos del ThreadPool de .NET I/O.
3. Estos hilos del ThreadPool carecen de un `PowerShell Runspace` asignado (`[System.Management.Automation.Runspaces.Runspace]::DefaultRunspace`). Al intentar ejecutar el delegado `ScriptBlock` en el hilo de fondo sin Runspace, el motor de PowerShell arroja de forma fulminante:
   `System.Management.Automation.PSInvalidOperationException: There is no Runspace available to run scripts in this thread.`
4. Dado que esta excepción ocurre fuera de cualquier pipeline de PowerShell o bloque try/catch en un callback no administrado/ThreadPool, el runtime .NET fuerza la terminación inmediata del proceso anfitrión (`powershell.exe`) con código de error de terminación por excepción fatal (Access Violation / Fail-Fast Win32 Exit Code 5).
5. Defecto secundario: `Start-StudioSubProcess` conmutaba a `$tabControl.SelectedIndex = 3` ("Módulos Avanzados") en lugar de la pestaña 4 ("Consola de Logs").

---

## 2. Solución Arquitectónica: Modelo ConcurrentQueue + Runspace + DispatcherTimer

Se sustituye el modelo frágil de `add_OutputDataReceived` por la misma arquitectura asíncrona probada y de alta fidelidad ya implementada en `Invoke-WimDiscoveryAsync`:

1. **Cola Concurrente Thread-Safe:**
   Se utiliza `[System.Collections.Concurrent.ConcurrentQueue[string]]` para que el hilo de trabajo encole las líneas de salida sin bloquearse ni requerir locks pesados.
2. **Runspace de Fondo Aislado:**
   Se instancia un `[System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()` dedicado con su propia sesión de PowerShell. Esto garantiza que la lectura del stream de salida cuente con su propio Runspace válido y nunca interfiera con el hilo UI.
3. **Consolidación de Canales (Stdout + Stderr):**
   Se invoca el subproceso consolidando Standard Error en Standard Output (`cmd.exe /c ... 2>&1`), evitando bloqueos por desbordamiento de búfer de tuberías (pipe buffer deadlock).
4. **DispatcherTimer en el Hilo WPF:**
   Un temporizador en el hilo de la UI (`DispatcherTimer`, intervalo 100ms) drena la cola concurrente mediante `TryDequeue`, actualiza `$txtConsole.AppendText()`, hace auto-scroll con `ScrollToEnd()` y persiste en `Write-StudioLog`.
5. **Detección de Finalización Limpia y Liberación:**
   Cuando `$state.IsRunning` pasa a `$false`, el `DispatcherTimer` se detiene a sí mismo (`$This.Stop()`), reporta el código de salida final en la consola y la barra de estado (`Set-StudioUIState`), cierra el Runspace y libera los recursos.
6. **Cancelación Concurrente Segura (`btnCancel`):**
   Se actualiza la lógica de cancelación para terminar limpiamente el árbol de procesos completo utilizando `taskkill.exe /F /T /PID $($state.Process.Id)` antes de desmontar o cerrar.
7. **Corrección de Índice de Pestaña:**
   Se conmuta explícitamente a `$tabControl.SelectedIndex = 4` ("Consola de Logs").

---

## 3. Plan de Verificación

1. **Validación de Sintaxis AST en Windows PowerShell 5.1:**
   Verificar 0 errores de parsing mediante `[System.Management.Automation.Language.Parser]::ParseFile`.
2. **Validación de Codificación UTF-8 con BOM:**
   Verificar que `scripts/GUI/romanOS-Studio.ps1` mantenga estrictamente los bytes `0xEF 0xBB 0xBF`.
3. **Prueba en Frío de Lanzamiento y Ejecución:**
   Simular el clic en el botón de Descarga de Runtimes/Updates y verificar que la consola transmita los datos en vivo sin cerrar el proceso GUI.
