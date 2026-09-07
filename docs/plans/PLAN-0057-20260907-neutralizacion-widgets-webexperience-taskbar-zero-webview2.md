# PLAN-0057: Neutralización de Widgets (Web Experience Pack) y Depuración de Barra de Tareas en la ISO para Lograr Zero-Overhead Total en WebView2

- **ID del Plan:** PLAN-0057
- **Fecha:** 2026-09-07
- **Autor:** romanOS Engineering & Antigravity Agent
- **Estado:** COMPLETADO
- **Área:** `scripts\Builder\New-OptimizedWindowsISO-v2.ps1`, `scripts\Core\Policy-Engine.ps1`, `scripts\Modules\Audit-FreshInstallFootprint.ps1`, `scripts\Testing\Test-OptimizedISO-v2.ps1`

---

## 1. Contexto y Diagnóstico Empírico

### 1.1 El Hallazgo en la Máquina Virtual (Auditoría PLAN-0056)
En la prueba empírica realizada en una máquina virtual limpia con Windows 11 Build 26200 (reporte [romanOS_Footprint_Audit.md](file:///C:/OptimizedISO/romanOS_Footprint_Audit.md)), se constató el éxito absoluto de la neutralización de Microsoft Edge (`0.0 MB`), OneDrive (`0.0 MB`), Teams (`0.0 MB`), GameDVR (`0.0 MB`), WER (`0.0 MB`) y el saneamiento de `LimitBlankPasswordUse = 1`.

Sin embargo, se identificaron **2 procesos vampiro activos** consumiendo **443.49 MB de RAM**:
1. **`msedgewebview2.exe`:** 6 instancias en segundo plano consumiendo **317.25 MB de RAM** (PIDs: 3980, 6388, 6612, 6624, 6872, 6976).
2. **`SearchHost.exe`:** 1 instancia consumiendo **126.24 MB de RAM** (PID: 5924).

### 1.2 Causa Raíz Identificada
- **El culpable:** El *Windows Web Experience Pack* (`MicrosoftWindows.Client.WebExperience`).
- **El mecanismo:** En Windows 11, si el icono de Widgets en la barra de tareas no está explícitamente desactivado en el perfil de usuario (`TaskbarDa = 0`), el shell de Windows inicializa de inmediato el widget del clima y noticias. Debido a que los widgets son una aplicación web híbrida, instancian el motor Chromium de WebView2 (Manager, GPU, Network y Renderers), levantando 6 procesos hijos con más de 300 MB de consumo.
- **La solución:** Neutralizar Widgets a nivel de usuario (`TaskbarDa = 0`) y a nivel de directivas de máquina (`AllowWidgets = 0`, `AllowNewsAndInterests = 0`), además de depurar los botones de Chat (`TaskbarMn = 0`) y Copilot (`ShowCopilotButton = 0`) en la colmena `NTUSER.DAT` de la ISO de fábrica.

---

## 2. Cambios Arquitectónicos Propuestos

### 2.1 En el Generador de la ISO: `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`
1. **Inyección en colmena de Usuario Predeterminado (`NTUSER.DAT` -> `HKLM\OfflineDefaultUser`):**
   - Ruta: `Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
     - `TaskbarDa = 0` (REG_DWORD) -> Oculta el icono de Widgets y clima.
     - `TaskbarMn = 0` (REG_DWORD) -> Oculta el icono de Chat/Teams.
     - `ShowCopilotButton = 0` (REG_DWORD) -> Oculta el botón de Copilot.
2. **Inyección en colmena de Máquina (`SOFTWARE` -> `HKLM\OfflineSoftware`):**
   - Ruta: `Policies\Microsoft\Widgets`
     - `AllowWidgets = 0` (REG_DWORD) -> Deshabilita el subsistema de widgets y detiene la precarga del Web Experience Pack.
   - Ruta: `Policies\Microsoft\Dsh`
     - `AllowNewsAndInterests = 0` (REG_DWORD) -> Deshabilita noticias e intereses.
   - Ruta: `Policies\Microsoft\Windows\Windows Chat`
     - `ChatIcon = 3` (REG_DWORD) -> Deshabilita Chat consumidor a nivel de directiva.
3. **Sincronización en Comandos Síncronos de `autounattend.xml`:**
   - Asegurar que `AllowWidgets = 0` y `AllowNewsAndInterests = 0` se refuercen durante el despliegue desatendido en el perfil base.

### 2.2 En el Catálogo Central de Políticas: `scripts/Core/Policy-Engine.ps1`
- Verificar que las directivas `POL_WIDGETS_ALLOW` (`AllowWidgets = 0`) y `POL_WIDGETS_DSH` (`AllowNewsAndInterests = 0`) estén asignadas al Perfil 1 (Base) para que formen parte de la exportación desatendida.
- Agregar `POL_CHAT_ICON` (`ChatIcon = 3` en `Policies\Microsoft\Windows\Windows Chat`).

### 2.3 Corrección Cosmética en: `scripts/Modules/Audit-FreshInstallFootprint.ps1`
- Corregir el formato de interpolación de cadenas en las tablas Markdown para evitar que aparezca `$(System.Collections.Hashtable.Name)` y `$(System.Collections.Hashtable.Path)`.
- Mejorar el reporte para incluir el diagnóstico específico de `TaskbarDa` y `AllowWidgets`.

---

## 3. Plan de Verificación y Validación

1. **Auditoría de Codificación y Sintaxis en Windows PowerShell 5.1:**
   - UTF-8 con BOM (`0xEF, 0xBB, 0xBF`) en todos los scripts editados.
   - Cero errores de sintaxis AST en `Test-OptimizedISO-v2.ps1` e `Invoke-TestSuite.ps1`.
2. **Test Harness Unitario:**
   - Agregar aserciones específicas del PLAN-0057 en `scripts/Testing/Test-OptimizedISO-v2.ps1`:
     - Validar que el Builder inyecte `TaskbarDa = 0`, `TaskbarMn = 0` y `ShowCopilotButton = 0` en `NTUSER.DAT`.
     - Validar que el Builder inyecte `AllowWidgets = 0` en `SOFTWARE hive`.
     - Validar que `Audit-FreshInstallFootprint.ps1` no contenga errores de interpolación.
3. **Validación en Máquina Virtual:**
   - Ejecutar la auditoría en la VM y contrastar contra el log anterior ([romanOS_Footprint_Audit.md](file:///C:/OptimizedISO/romanOS_Footprint_Audit.md)):
     - Las 6 instancias de `msedgewebview2.exe` deben reducirse a **0 instancias (0.0 MB)**.
     - Ahorro inmediato de **~317 MB de RAM** en reposo.
