# PLAN-0112: Mejoras Arquitectónicas y de Experiencia de Usuario (UX) en romanOS Control Center y romanOS Studio

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0112 |
| **Fecha** | 2026-09-24 |
| **Componentes** | `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/GUI/romanOS-Studio.ps1`, `docs/plans/README.md` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Alta (Perfeccionamiento de Telemetría WPF, Salvaguardas Modales y Resiliencia Visual) |
| **Reglas Relevantes** | Regla 0 (Git), Regla 4 (Windows PowerShell 5.1 / UTF-8 BOM / STA), Regla 5 (Planes), Regla 7 (Aviso de Pruebas), Regla 8 (No Auto-Run), Regla 11 (Ingeniero Autónomo) |

---

## 1. Contexto y Objetivos

A partir de la auditoría forense formal de interfaces gráficas ([PLAN-0111](PLAN-0111-20260923-auditoria-forense-completa-de-guis-y-reporte-html.md) / [Auditoria-GUIs-romanOS.html](../../Auditoria-GUIs-romanOS.html)), se certificó que los 80 botones del ecosistema romanOS cuentan con manejadores de eventos activos y resuelven el 100% de sus llamadas de backend.

Sin embargo, se identificaron **4 oportunidades de mejora arquitectónica y de UX** para elevar la robustez técnica y la calidad de interacción de las dos aplicaciones cliente:
1. **Telemetría de Progreso Visual Dinámica:** Reemplazar el modo indeterminado continuo por un cálculo reactivo de porcentaje real en la barra de progreso WPF mediante análisis heurístico de flujos de salida (DISM, compresión, descargas).
2. **Salvaguardas Modales en Acciones de Shell y Kernel:** Incorporar cuadros de diálogo nativos de confirmación (`MessageBox Yes/No`) antes de reiniciar el explorador de Windows, alternar el hipervisor BCD o purgar temporales.
3. **Anillo Visual de Alerta ante Fallos (UI Error Feedback):** Proporcionar retroalimentación visual inmediata en la barra de estado y el marco de la consola cuando un comando devuelva código de salida distinto de cero (`ExitCode != 0`).
4. **Persistencia de Perfiles en Control Center:** Permitir la exportación a formato portable JSON del estado de optimización activo del sistema para replicación en otras máquinas.

---

## 2. Plan de Implementación por Fases

### Fase 1: Telemetría de Progreso Visual Dinámica (WPF Dynamic ProgressBar)
* **romanOS Control Center (`scripts/GUI/romanOS-ControlCenter.ps1`):**
  * Inyectar en el XAML de la barra inferior de estado (`Border Background="#282828"`) un control `ProgressBar x:Name="taskProgressBar"` estilizado en Cyan `#00E5FF`, altura 8px, ancho 180px, inicialmente colapsado (`Visibility="Collapsed"`).
  * En `Start-ControlCenterTask`, inicializar la barra en `Visibility = "Visible"` e `IsIndeterminate = $true`.
  * En el bucle de despacho del `DispatcherTimer`, analizar las líneas recibidas de la cola:
    * Si la línea contiene porcentajes (ej. `(\d{1,3}(?:\.\d+)?)\s*%` o `\[(\d{1,2})/(\d{1,2})\]`), conmutar a `IsIndeterminate = $false` y asignar `Value = $pct`.
  * Al finalizar la tarea con éxito, llevar la barra al 100% y colapsarla suavemente tras 3 segundos.
* **romanOS Studio (`scripts/GUI/romanOS-Studio.ps1`):**
  * Ampliar el ancho del control `progBar` existente de 100px a 180px.
  * En `Start-StudioSubProcess`, activar la misma lógica de captura reactiva de porcentajes para compilación WIM, compresión y descargas.

### Fase 2: Diálogos Modales de Salvaguarda (Safety Guards)
* **romanOS Control Center:**
  * Modificar `btnQuickRestartExplorer` para invocar un `[System.Windows.MessageBox]::Show` preguntando: *"Se cerrará y reiniciará el explorador de Windows (explorer.exe). Las ventanas abiertas y la barra de tareas se recargarán momentáneamente. ¿Deseas reiniciar explorer.exe ahora?"*.
  * Modificar `btnToggleHypervisor` para advertir: *"Esta acción modificará la directiva de arranque de Windows (BCD) para alternar el hipervisor de virtualización y requerirá reiniciar el equipo. ¿Deseas continuar?"*.
* **romanOS Studio:**
  * Modificar `btnCleanHost` para solicitar confirmación antes de vaciar las carpetas temporales de compilación de imágenes WIM.

### Fase 3: Retroalimentación Visual de Errores (UI Error Ring)
* **romanOS Control Center y Studio:**
  * En el evento de finalización del subproceso:
    * Si `$exitCode -eq 0`:
      * `statusIndicator.Fill = [System.Windows.Media.Brushes]::LightGreen`
      * `lblStatus.Text = "$TaskTitle completado con éxito"`
    * Si `$exitCode -ne 0`:
      * `statusIndicator.Fill = [System.Windows.Media.Brushes]::Red`
      * `txtConsole.BorderBrush = [System.Windows.Media.Brushes]::Red` (alerta perimetral)
      * `lblStatus.Text = "[ERROR $exitCode] $TaskTitle finalizó con incidencias"`
      * Colorear el texto de cierre en la consola con encabezado destacado `[FALLO DE SUBPROCESO]`.

### Fase 4: Exportación de Perfil de Optimización en Control Center
* Agregar un botón en la barra superior o en la pestaña de Acciones Rápidas: `btnExportProfile` ("💾 Exportar Perfil Activo").
* Al hacer clic, invocar `Audit-SystemOptimization.ps1` o recopilar la telemetría activa de `Hardware-Engine.ps1` y serializarla en un archivo `C:\OptimizedISO\romanOS-SystemProfile.json` con metadatos del hardware, fecha y directivas aplicadas.

---

## 3. Validación y Certificación Empírica
1. **Prueba Estática y Sintaxis (Regla 4 y 13):**
   * Verificar codificación UTF-8 con BOM en ambos scripts.
   * Ejecutar `Test-CodeQuality.ps1` garantizando 0 errores de sintaxis en Windows PowerShell 5.1 y 0 fallos silenciosos.
2. **Prueba de Interfaces (Cold Check):**
   * Lanzar `romanOS-ControlCenter.ps1` y `romanOS-Studio.ps1` en frío con `-WhatIf` / parseo XAML para certificar que el marcado XML sea 100% válido.
3. **Re-ejecución de la Auditoría Forense de GUIs:**
   * Ejecutar `scripts/Testing/Test-GuiIntegrityAndFunctionality.ps1` para asegurar que los 80 botones sigan estando perfectamente cableados y funcionales.
4. **Registro de Commit Atómico:**
   * Registrar commit atómico descriptivo tras superar la suite de validación.
