# Reparación Integral de romanOS Studio: Lanzador CMD, Parser XAML, Eventos de Satélites y Streaming de Logs

Este plan detalla la resolución exhaustiva de la cascada de fallas detectadas en el ecosistema de la interfaz gráfica (`romanOS-Studio.ps1`), el lanzador por lotes (`Lanzar-romanOS-Studio.cmd`) y los motores satélite en segundo plano.

## Diagnóstico Forense y Causa Raíz

Tras una auditoría en frío utilizando el motor AST de PowerShell 5.1, el parser XML de .NET, el motor XamlReader de WPF y ejecución controlada, se identificaron 8 defectos estructurales:

1. **Codificación de Lanzador (`Lanzar-romanOS-Studio.cmd`)**: Guardado con UTF-8 con BOM (`0xEF 0xBB 0xBF`). El procesador `cmd.exe` no soporta marcas de orden de bytes en archivos batch e intenta ejecutar `ï»¿@echo`, arrojando un error de comando no reconocido.
2. **Malformación de Documento XML (`romanOS-Studio.ps1`)**: La etiqueta `<TabItem Header="Consola de Logs">` no cuenta con etiqueta de cierre `</TabItem>` antes de `<TabItem Header="Herramientas del Host">`. Esto rompe la jerarquía XML y hace que `[xml]$xaml` lance una excepción fatal al cargar.
3. **Falla de Recurso Estático XAML (`RoundedButton`)**: Los botones `btnTestVM` y `btnCleanHost` invocan `Style="{StaticResource RoundedButton}"`, pero dicho recurso no existe en `<Window.Resources>`, provocando un `XamlParseException` en `[Windows.Markup.XamlReader]::Load()`.
4. **Función Inexistente `Set-UIState`**: Cuatro bloques llaman a `Set-UIState -IsRunning $true/$false`, función que nunca fue declarada en el script.
5. **Silenciamiento de Logs y Salida Desconectada de la UI**:
   - `btnTestVM` y `btnCleanHost` escriben a `Write-StudioLog` (archivo de disco), pero no inyectan texto a `$txtConsole` en la interfaz.
   - Invocan PowerShell sin el redireccionador `*>&1` o con `-File`, provocando que los mensajes emitidos por `Write-Host` (Stream 6 de Información) no sean capturados por `BeginOutputReadLine()` (Stream 1 StdOut).
6. **Desconexión Total de Botones de Descarga (PLAN-0071)**:
   - `btnDownloadUpdates`, `btnBackupDrivers`, `btnDownloadCritical` y `btnDownloadRuntimes` existen en el XAML pero carecen de eventos `.Add_Click(...)`.
7. **Bloqueo Interactivo en Motor Satélite (`Get-WindowsUpdates-GUI-Engine.ps1`)**:
   - Línea 158 ejecuta `Read-Host` si no recibe `-Unattended` ni `-OutputDir`, lo que colgaría el proceso en segundo plano.
8. **Falta de Trampa de Errores en Lanzador CMD**:
   - El archivo batch no retiene la consola (`pause`) si PowerShell sale con código de error, cerrando la ventana en milisegundos.

---

## User Review Required

> [!IMPORTANT]
> **Estandarización de Codificación en Archivos Batch (`.cmd`)**:
> La Regla 4 de `.agents/AGENTS.md` exige UTF-8 con BOM para scripts de PowerShell (`.ps1`, `.psm1`, `.psd1`). Los archivos batch (`.cmd`, `.bat`) procesados por `cmd.exe` NO deben llevar BOM para evitar la corrupción de la primera línea.

---

## Proposed Changes

### 1. Lanzador por Lotes
#### [MODIFY] [Lanzar-romanOS-Studio.cmd](file:///c:/OptimizedISO/Lanzar-romanOS-Studio.cmd)
- Guardar estrictamente en formato **ANSI / UTF-8 sin BOM**.
- Agregar trampa de código de salida (`if %ERRORLEVEL% neq 0 pause`) para visibilidad de diagnósticos.

### 2. Interfaz Gráfica Principal
#### [MODIFY] [romanOS-Studio.ps1](file:///c:/OptimizedISO/scripts/GUI/romanOS-Studio.ps1)
- Cerrar la etiqueta `</TabItem>` de `Consola de Logs`.
- Eliminar el atributo inexistente `Style="{StaticResource RoundedButton}"` o estandarizar el estilo de los botones de herramientas del host con el diseño general.
- Implementar la función auxiliar canónica `Set-StudioUIState -IsRunning $bool -TaskName $str` que desactive/active botones, muestre u oculte el ProgressBar y actualice la barra de estado de manera consistente en toda la ventana.
- Conectar los eventos de salida `add_OutputDataReceived` y `add_ErrorDataReceived` en todos los procesos secundarios directamente hacia `$txtConsole.AppendText(...)` y desplazar el scroll al final.
- Asegurar que al presionar cualquier botón de ejecución larga, la GUI cambie automáticamente a la pestaña de `Consola de Logs` (`tabControlMain.SelectedIndex = 3`).
- Implementar los manejadores de eventos `.Add_Click(...)` para los 4 botones de Descargas (`btnDownloadUpdates`, `btnBackupDrivers`, `btnDownloadCritical`, `btnDownloadRuntimes`) invocando sus respectivos scripts GUI-Engine con `-Command "& { ... *>&1 }"`.

### 3. Motor Satélite de Descargas
#### [MODIFY] [Get-WindowsUpdates-GUI-Engine.ps1](file:///c:/OptimizedISO/scripts/Builder/Get-WindowsUpdates-GUI-Engine.ps1)
- Erradicar `Read-Host` en la resolución de carpetas cuando opera en modo GUI/Headless, utilizando de forma determinista la carpeta por defecto si `-OutputDir` está vacío.

### 4. Registro y Gobernanza
#### [MODIFY] [docs/plans/README.md](file:///c:/OptimizedISO/docs/plans/README.md)
- Registrar `PLAN-0072` y `PLAN-0073`.

---

## Fuentes Oficiales de Referencia

1. **Microsoft Learn: Excepciones de Recursos en XAML (`XamlParseException`)**
   - URL: `https://learn.microsoft.com/en-us/dotnet/desktop/wpf/advanced/staticresource-markup-extension`
   - Documenta que las referencias `StaticResource` se resuelven en tiempo de análisis sintáctico y generan `XamlParseException` cuando la clave no existe en el diccionario.
2. **Microsoft Learn: Redirección de Flujos en PowerShell (`about_Redirection`)**
   - URL: `https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_redirection`
   - Explica el uso de `*>&1` para combinar todos los flujos de salida (incluyendo Stream 6 de Información generado por `Write-Host`) en el flujo de salida estándar (Stream 1).
3. **Microsoft Learn: Modelo de Hilos y Apartamento de Subproceso Único (STA) en WPF**
   - URL: `https://learn.microsoft.com/en-us/dotnet/desktop/wpf/advanced/threading-model`
   - Detalla el requerimiento de que cualquier interfaz gráfica construida con `PresentationFramework` se ejecute en un hilo con `Thread.ApartmentState = ApartmentState.STA`.
4. **Microsoft Command-Line Shell (`cmd.exe`) y Manejo de Codificación**
   - URL: `https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/chcp`
   - Documenta el comportamiento de páginas de código de `cmd.exe` y la incompatibilidad con marcas de orden de bytes (BOM) en la cabecera de scripts `.cmd`.

---

## Verification Plan

### Automated Tests
- Auditoría AST de PowerShell 5.1 en frío:
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { [System.Management.Automation.Language.Parser]::ParseFile('C:\OptimizedISO\scripts\GUI\romanOS-Studio.ps1', [ref]$null, [ref]$errors); $errors }"`
- Verificación de carga en memoria de XAML con `[System.Windows.Markup.XamlReader]::Load()`.
- Verificación de bytes de cabecera de `Lanzar-romanOS-Studio.cmd` (sin BOM: los primeros dos bytes deben ser `0x40 0x65` -> `@e`).

### Manual Verification
- Ejecutar `Lanzar-romanOS-Studio.cmd` directamente en Windows y constatar apertura fluida de la ventana WPF.
- Probar navegación entre pestañas, selección de ISO y botones satélites.
