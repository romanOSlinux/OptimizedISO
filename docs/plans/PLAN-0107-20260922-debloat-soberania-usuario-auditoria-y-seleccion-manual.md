# PLAN-0107: Soberanía del Usuario en Debloat — Erradicación de Acciones Automáticas, Auditoría de Solo Lectura y Selección Manual Guiada

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0107 |
| **Fecha** | 2026-09-22 |
| **Componente** | `scripts/Modules/Win11-Debloat-v3-Adaptive.ps1`, `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/Drivers/Clean-DriverStore.ps1` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Alta (Principio Fundamental de Arquitectura y Confianza de Usuario) |
| **Reglas Relevantes** | Regla 0 (Git), Regla 4 (Windows PowerShell 5.1 / UTF-8 BOM), Regla 5 (Planes), Regla 8 (No Auto-Run), Regla 11 (Ingeniero Autónomo), Regla 13 (No Silent Failures) |

---

## 1. Contexto y Principio de Diseño

El usuario ha señalado un principio crítico de diseño y experiencia de usuario:
> *"El debloat win 11 en el GUI lo hace de forma automática, eso es incorrecto, no deben realizar acciones automáticas, algo que cambie o desinstale no debe tener acción automática, hay que buscar otras opciones."*

### Diagnóstico Técnico:
En la implementación previa de `romanOS-ControlCenter.ps1`, el botón de debloat ejecutaba `Win11-Debloat-v3-Adaptive.ps1 -Unattended` en un proceso secundario oculto. Esto desinstalaba aplicaciones AppX (incluso apps que el usuario podría desear como Xbox App, Paint, etc.), deshabilitaba servicios y modificaba políticas de forma masiva sin consultar al usuario.

---

## 2. Objetivos del Plan

1. **Erradicar de raíz la ejecución desatendida automática (`-Unattended`) en los botones del GUI de Control Center.**
2. **Implementar el Modo Auditoría (Solo Lectura - Cero Modificaciones):**
   - Incorporar el parámetro `-AuditOnly` a `Win11-Debloat-v3-Adaptive.ps1`.
   - Escanear e inventariar paquetes AppX, aplicaciones Win32 (OneDrive/Teams) y servicios de telemetría sin modificar nada ni crear puntos de restauración innecesarios.
   - Mostrar el inventario en tiempo real en la consola de Control Center mediante el botón `🔍 Auditar Bloatware (Solo Lectura)`.
3. **Implementar el Asistente Interactivo Guiado con Selección Visual:**
   - Botón `🛠️ Debloat Asistido (Selección Manual)`.
   - Mostrar un diálogo previo (`MessageBox`) advirtiendo que se abrirán ventanas de selección visual (`Out-GridView`) y que ningún componente se eliminará sin selección explícita del usuario.
   - Ejecutar en consola visible con soporte `-STA` para que el usuario marque y desmarque individualmente los paquetes a desinstalar.
   - Creación de punto de restauración del sistema previo antes de aplicar cualquier cambio.
4. **Paridad de Soberanía en DriverStore:**
   - Botón `🔍 Auditar DriverStore (WhatIf)`: Muestra en la consola de la UI qué controladores antiguos o duplicados existen sin eliminarlos.
   - Botón `🗑️ Depurar DriverStore (Interactivo)`: Abre la consola con solicitud de confirmación explícita `[S/N]` y listado previo antes de borrar ningún controlador.

---

## 3. Plan de Modificaciones Propuesto

### A. `scripts/Modules/Win11-Debloat-v3-Adaptive.ps1`
1. Agregar `[switch]$AuditOnly` al bloque `param(...)`.
2. Propagar `$AuditOnly` en la comprobación de elevación UAC (`$argArray += '-AuditOnly'`).
3. Omitir la creación del punto de restauración (`Checkpoint-Computer`) si `$AuditOnly` está activo.
4. Antes de los menús interactivos o desatendidos, si `$AuditOnly` es `$true`:
   - Escanear AppX instalados y provisionados comparando contra `$bloatwareList`.
   - Escanear aplicaciones Win32 típicas (Teams, OneDrive, Skype).
   - Escanear servicios de telemetría activos (`DiagTrack`, `dmwappushservice`, etc.).
   - Imprimir el informe detallado de hallazgos en consola.
   - Emitir mensaje de certificación: `[AUDIT OK] NINGÚN CAMBIO NI DESINSTALACIÓN HA SIDO EFECTUADO.`
   - Retornar inmediatamente (`return`) con código 0.

### B. `scripts/GUI/romanOS-ControlCenter.ps1`
1. **XAML - Pestaña Mantenimiento y Gaming:**
   - Reemplazar los botones de Debloat automático por:
     - `btnAuditDebloat`: `🔍 Auditar Bloatware (Solo Lectura)`.
     - `btnRunDebloatInteractive`: `🛠️ Debloat Asistido (Selección Manual)`.
2. **XAML - Pestaña Controladores:**
   - Reemplazar la llamada directa forzada por:
     - `btnAuditDriverStore`: `🔍 Auditar DriverStore (WhatIf)`.
     - `btnCleanDriverStore`: `🗑️ Depurar DriverStore (Interactivo)`.
3. **Event Handlers en PowerShell:**
   - Conectar `btnAuditDebloat` a `Start-ControlCenterTask` con `-AuditOnly`.
   - Conectar `btnRunDebloatInteractive` con diálogo `MessageBox` previo y lanzamiento de ventana externa interactiva.
   - Conectar `btnAuditDriverStore` con `-WhatIf` en consola de Control Center.
   - Conectar `btnCleanDriverStore` con confirmación previa y consola interactiva.

---

## 4. Plan de Verificación y Testing

1. **Pruebas de Codificación UTF-8 con BOM (Regla 4):**
   - Verificar `0xEF, 0xBB, 0xBF` en ambos scripts.
2. **Validación de Runtime en Windows PowerShell 5.1:**
   - `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'scripts\Modules\Win11-Debloat-v3-Adaptive.ps1' -AuditOnly }"`
   - `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'scripts\GUI\romanOS-ControlCenter.ps1' -WhatIf }"`
3. **Test Suite:**
   - Ejecutar `Test-OptimizedISO-v2.ps1` e `Invoke-TestSuite.ps1`.
