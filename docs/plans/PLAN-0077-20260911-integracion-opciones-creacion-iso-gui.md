# PLAN-0077: Integración de Opciones Seleccionables en la Interfaz de Creación de ISO (romanOS Studio)

**Fecha:** 2026-09-11  
**Estado:** COMPLETADO  
**Módulos Afectados:** `scripts/GUI/romanOS-Studio.ps1`, `scripts/Builder/New-OptimizedWindowsISO-GUI-Engine.ps1`, `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`  
**Reglas Aplicables:** Regla 0 (Git y Trazabilidad), Regla 4 (UTF-8 BOM en PS1 / No-BOM en CMD), Regla 8 (No auto-run), Regla 9 (SSOT), Regla 10 (Docs-as-Code)

---

## 1. Contexto y Justificación del Problema

Actualmente, `romanOS-Studio.ps1` cuenta con una interfaz gráfica (WPF/XAML) funcional, pero varias opciones críticas de personalización de la ISO se encuentran **hardcodeadas** en el JSON temporal (`$config`) o no están expuestas al usuario:

1. **Modo Zero-Touch:** Se encuentra forzado en `$false` en el preset de la GUI (`ZeroTouch = $false`), imposibilitando que el usuario elija crear una ISO 100% desatendida o manual desde romanOS Studio, ni tampoco el disco de destino (`ZeroTouchDisk`).
2. **Integración Opcional de Updates, Drivers y Runtimes:** Actualmente no existen controles en la GUI para activar o desactivar la integración de Actualizaciones Acumulativas, Controladores de Hardware o Runtimes C++/DirectX. Además, en los motores de compilación (`New-OptimizedWindowsISO-GUI-Engine.ps1` y `New-OptimizedWindowsISO-v2.ps1`), si las carpetas `Updates/`, `Drivers/` o `Runtimes/` existen en el disco, el motor las inyecta forzosamente por auto-descubrimiento, sin respetar si el usuario desea omitirlas.
3. **Parámetros de Despliegue y Localización Hardcodeados:** Parámetros como el nombre de usuario local (`LocalUser = 'Roman'`), contraseña, inicio de sesión automático (`AutoLogonCount = 1`), omisión de limpieza WinSxS (`SkipComponentCleanup = $false`), y controladores en Boot.wim (`SkipBootWimDrivers`) no disponen de controles en la UI.
4. **Discrepancia en "Solo JSON":** El botón "Solo JSON" (`btnExportPreset`) exporta un subconjunto incompleto de campos en comparación con el generado al compilar (`btnBuild`).

---

## 2. Catálogo de Opciones Seleccionables para la Creación de la ISO

El nuevo diseño unificado de la interfaz y del motor integrará las siguientes opciones configurables:

### A. Despliegue e Instalación Desatendida (Unattend / OOBE)
- **Instalación Zero-Touch:** Checkbox para habilitar instalación 100% desatendida (particionado UEFI/GPT automático, EULA y omisión de pantallas).
- **Disco Destino Zero-Touch:** Selector numérico/combo (Disco 0 por defecto, Disco 1, etc.) con advertencia visual de formateo completo.
- **Cuenta de Usuario Local:** Nombre de usuario editable (Default: `Roman`).
- **Contraseña Local:** Campo de texto (opcional, vacía por defecto para despliegue sin contraseña).
- **AutoLogon:** Checkbox para iniciar sesión automáticamente al finalizar la instalación (`AutoLogonCount = 1`).
- **Localización y Regional:**
  - Idioma UI (`es-ES`, `es-MX`, `en-US`).
  - Formato Regional / Locale (`es-AR`, `es-MX`, `es-ES`, `en-US`).
  - Distribución de Teclado (`es-419`, `es-ES`, `us`).
  - Zona Horaria (`Argentina Standard Time`, `Romance Standard Time`, etc.).

### B. Integración Offline de Componentes (Slipstreaming)
- **Actualizaciones (Updates):** Checkbox `[X] Integrar Actualizaciones Acumulativas (Updates/ - .msu / .cab)`.
- **Controladores (Drivers):** Checkbox `[X] Integrar Controladores de Hardware (Drivers/ - .inf)`.
  - Sub-opción: `[X] Inyectar controladores de almacenamiento en Boot.wim (WinPE)`.
- **Runtimes Esenciales:** Checkbox `[X] Integrar Runtimes C++ y DirectX (Runtimes/ - VC++ 2005-2022 + DirectX 9.0c)`.

### C. Perfiles y Políticas del Sistema (SSOT Policy-Engine / Hardware-Engine)
- **Perfil de Optimización:** Selector de Perfil 1 (Conservador / Ofimática), Perfil 2 (Avanzado / Gaming - Recomendado), Perfil 3 (Hardcore / Extremo).
- **Tweaks y Políticas:**
  - `[X] Inyectar Menú Contextual Clásico / Moderno (Shift+F10 / Menú Completo)`.
  - `[X] Bloquear Telemetría e Integración de OneDrive`.
  - `[ ] Habilitar Subsistema Hyper-V en la Imagen WIM`.

### D. Ajustes de Imagen y Compresión WIM
- **Compresión WIM:** Selector `Max` (menor tamaño ISO), `Fast` (compilación rápida), `None`.
- **Limpieza WinSxS:** Checkbox `[ ] Omitir Limpieza de Componentes WinSxS (Build Rápido sin ResetBase)`.
- **Ediciones WIM:** Lista interactiva (`lbxWimEditions`) con checkboxes por cada edición detectada en la ISO fuente.

---

## 3. Arquitectura y Plan de Implementación

### 3.1. Reorganización y Modernización de Pestañas en `romanOS-Studio.ps1`
1. **Pestaña 1: Construcción Base:**
   - Selección de ISO fuente (`txtSourceISO`, `btnBrowseISO`).
   - Perfil de Optimización (`cmbProfile`).
   - Ediciones del WIM a procesar (`lblEditionsStatus`, `lbxWimEditions`).
2. **Pestaña 2: Instalación y Despliegue (Unattend):**
   - Grupo Zero-Touch: Checkbox `chkZeroTouch` y Selector `cmbZeroTouchDisk` (con toggle dinámico de habilitación y advertencia visual).
   - Grupo Usuario y Sesión: `txtLocalUser`, `txtLocalPassword`, `chkAutoLogon`.
   - Grupo Localización: `cmbLanguage`, `cmbLocale`, `cmbKeyboard`, `cmbTimezone`.
3. **Pestaña 3: Componentes e Integraciones:**
   - Grupo Inyección Offline: `chkIntegrateUpdates`, `chkIntegrateDrivers`, `chkBootWimDrivers`, `chkIntegrateRuntimes`.
   - Grupo Tweaks y Políticas: `chkVisualTweaks`, `chkBlockOneDrive`, `chkHyperV`.
   - Grupo Compresión y Rendimiento: `cmbCompression`, `chkSkipCleanup`.
4. **Pestaña 4: Descargas Satélite:**
   - Descarga de Updates, Respaldo de Drivers del Host, Descarga de Drivers Críticos, Descarga de Runtimes.
5. **Pestaña 5: Herramientas del Host:**
   - Despliegue de VM Hyper-V y Limpieza de Residuos.
6. **Pestaña 6: Consola de Logs:**
   - Monitoreo en tiempo real del proceso.

### 3.2. Unificación Canónica del Generador de Preset (`Get-StudioBuildConfig`)
- Crear una función auxiliar `Get-StudioBuildConfig` en `romanOS-Studio.ps1` que centralice la lectura de todos los controles de la UI y devuelva la estructura `[ordered]@{ ... }`.
- Usar `Get-StudioBuildConfig` de forma idéntica en `btnBuild` y `btnExportPreset` (eliminando cualquier desvío de configuración).

### 3.3. Saneamiento en Motores (`New-OptimizedWindowsISO-GUI-Engine.ps1` y `New-OptimizedWindowsISO-v2.ps1`)
1. **Soporte de Banderas de Omisión:**
   - Agregar switches `SkipUpdates`, `SkipDrivers`, `SkipRuntimes` (o mapeo desde `IntegrateUpdates`, `IntegrateDrivers`, `IntegrateRuntimes`).
2. **Respeto Estricto de Banderas:**
   - En Paso 0 (Diagnóstico pre-vuelo) y Paso 5 (Slipstreaming): Si `SkipUpdates` está activo, no buscar en carpetas candidatas ni slipstreamear parches, emitiendo log informativo.
   - Si `SkipDrivers` está activo, no buscar ni inyectar drivers offline.
   - Si `SkipRuntimes` está activo, no copiar Runtimes a `$OEM$\$$\Setup\Scripts\Runtimes`.
   - Si `SkipBootWimDrivers` está activo, no inyectar drivers en `Boot.wim`.
3. **Mapeo en `Import-GUIPreset`:**
   - Mapear `ZeroTouch`, `ZeroTouchDisk`, `LocalUser`, `LocalPassword`, `AutoLogonCount`, `Locale`, `KeyboardOverride`, `Timezone`, `SkipComponentCleanup`, `SkipUpdates`, `SkipDrivers`, `SkipRuntimes`, `SkipBootWimDrivers`.

---

## 4. Plan de Verificación

1. **Verificación Estática y Codificación UTF-8 BOM:**
   - Comprobar que `romanOS-Studio.ps1`, `New-OptimizedWindowsISO-GUI-Engine.ps1` y `New-OptimizedWindowsISO-v2.ps1` mantengan estricto formato UTF-8 con BOM (`0xEF, 0xBB, 0xBF`).
2. **Validación en Windows PowerShell 5.1:**
   - Probar en frío contra el runtime de destino:
     `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'scripts\GUI\romanOS-Studio.ps1' -WhatIf }"` (o validación sintáctica AST).
3. **Validación de Generación de Preset JSON:**
   - Generar preset con combinaciones de flags (Zero-Touch activado/desactivado, Updates desactivadas, etc.) y verificar que el JSON contenga todas las propiedades y que `Import-GUIPreset` las procese adecuadamente.
