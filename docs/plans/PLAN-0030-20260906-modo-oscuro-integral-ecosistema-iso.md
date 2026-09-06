# PLAN-0030: Integración Integral y Robusta del Modo Oscuro en la Arquitectura de la ISO

**Fecha:** 2026-09-06  
**Estado:** PENDIENTE  
**Rama:** `feature/offline-ui-tweaks`  
**Autor:** Agente Antigravity / Pair-Programming  
**Plan Previo Directo:** [PLAN-0029](PLAN-0029-20260906-refactor-context-menus-native-registry-and-iso-integration.md)  
**Reglas Aplicables:** Regla 0 (Git como fuente de verdad), Regla 4 (UTF-8 con BOM, Windows PowerShell 5.1), Regla 5 (Trazabilidad de Planes), Regla 8 (Prohibición estricta de auto-ejecución) y Regla 9 (SSOT Policy-Engine).

---

## 1. Justificación y Diagnóstico Técnico

En la auditoría del sistema operativo en vivo instalado desde la ISO generada por este proyecto, se constató que **Windows 11 arrancó en Modo Claro**, a pesar de que el script compilador reportó:
`[OK] Tweaks Visuales (Default User) -> WIM Idx 10: Modo Oscuro, Transparencia y optimizaciones inyectadas en NTUSER.DAT`.

### Causa Raíz Identificada
1. **Sobreescritura en OOBE por el Theme Setup Provider de Windows 11:**
   * En Windows 11 (24H2/25H2), al crearse el usuario interactivo (ej. `Thiago`), Windows clona `C:\Users\Default\NTUSER.DAT`, pero inmediatamente después el subsistema de personalización (`uxtheme.dll` / `themeservice`) lee la directiva de máquina:
     `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes` -> `InstallTheme`.
   * En la ISO, `InstallTheme` quedó en su valor de fábrica: `C:\Windows\resources\Themes\aero.theme`.
   * `aero.theme` tiene codificado `SystemMode=Light` y `AppMode=Light`, lo que sobrescribe en caliente `AppsUseLightTheme = 1` y `SystemUsesLightTheme = 1` en el perfil del usuario recién creado, anulando los valores de `NTUSER.DAT`.
2. **Ausencia de Directivas en `autounattend.xml` (`FirstLogonCommands`):**
   * El archivo de respuesta desatendida no contiene directivas en `<FirstLogonCommands>` (que es la fase que corre en el contexto de usuario al iniciar sesión por primera vez) para forzar las claves en `HKCU`.
3. **Ausencia de Directivas en `SetupComplete.cmd`:**
   * `SetupComplete.cmd` no reconfigura `InstallTheme` en `HKLM` hacia `dark.theme` ni programa claves en `Themes\Personalize`.
4. **Violación de SSOT (Regla 9) y Auditoría Defectuosa:**
   * `scripts/Core/Policy-Engine.ps1` no catalogaba ninguna directiva para el tema visual.
   * `scripts/PostInstall-Diagnostics.ps1` consultaba erróneamente `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize` (que no existe por defecto), reportando falsamente `Modo Claro o Estandar`.

---

## 2. Objetivos del Plan

1. **Centralización Canónica en `Policy-Engine.ps1` (Pilar SSOT - Regla 9):**
   * Registrar las directivas oficiales:
     - `POL_THEME_INSTALL_THEME`: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes` -> `InstallTheme = C:\Windows\resources\Themes\dark.theme` (REG_SZ).
     - `POL_THEME_APPS_DARK`: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize` -> `AppsUseLightTheme = 0` (REG_DWORD).
     - `POL_THEME_SYSTEM_DARK`: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize` -> `SystemUsesLightTheme = 0` (REG_DWORD).
     - `POL_THEME_TRANSPARENCY`: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize` -> `EnableTransparency = 1` (REG_DWORD).
2. **Inyección en `autounattend.xml` (`FirstLogonCommands`):**
   * Agregar comandos síncronos en `<FirstLogonCommands>` para escribir en `HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` (`AppsUseLightTheme=0`, `SystemUsesLightTheme=0`, `EnableTransparency=1`) en la primera sesión del usuario.
3. **Inyección en `SetupComplete.cmd` y WIM Servicing Offline:**
   * En la fase offline de `install.wim`, redirigir `InstallTheme` a `dark.theme`.
   * En la plantilla de `SetupComplete.cmd`, asegurar que `InstallTheme` y las directivas de máquina se establezcan antes del primer inicio de sesión.
4. **Corrección de Diagnósticos y Pruebas Unitarias:**
   * En `PostInstall-Diagnostics.ps1`, auditar correctamente `HKCU` y `HKLM`.
   * En `Test-OptimizedISO-v2.ps1`, agregar asertos unitarios de contrato para verificar que las directivas y bloques de inyección existen.

---

## 3. Arquitectura y Archivos Involucrados

```
OptimizedISO/
├── scripts/
│   ├── Core/
│   │   └── Policy-Engine.ps1               [MODIFICAR] Registrar directivas POL_THEME_* en catálogo SSOT
│   ├── New-OptimizedWindowsISO-v2.ps1      [MODIFICAR] Inyectar dark.theme en WIM servicing, autounattend y SetupComplete
│   ├── PostInstall-Diagnostics.ps1         [MODIFICAR] Auditar correctamente el tema en HKCU y HKLM
│   └── Test-OptimizedISO-v2.ps1            [MODIFICAR] Asertos unitarios de verificación de tema
```

---

## 4. Fases de Implementación

### Fase 1: Catálogo SSOT en `Policy-Engine.ps1`
* Registrar en `$global:RomanOS_Policies`:
  * `POL_THEME_INSTALL_THEME`: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes` -> `InstallTheme = C:\Windows\resources\Themes\dark.theme`
  * `POL_THEME_APPS_DARK`: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize` -> `AppsUseLightTheme = 0`
  * `POL_THEME_SYSTEM_DARK`: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize` -> `SystemUsesLightTheme = 0`
  * `POL_THEME_TRANSPARENCY`: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize` -> `EnableTransparency = 1`

### Fase 2: Inyección Multi-Capa en `New-OptimizedWindowsISO-v2.ps1`
1. **WIM Servicing Offline (Default User + HKLM Software):**
   * Al montar `install.wim` e inyectar tweaks visuales:
     * Cargar colmena `Software` (`Windows\System32\config\SOFTWARE`) del WIM montado.
     * Cambiar `HKLM\OfflineSoftware\Microsoft\Windows\CurrentVersion\Themes` -> `InstallTheme = C:\Windows\resources\Themes\dark.theme`.
     * Crear `HKLM\OfflineSoftware\Microsoft\Windows\CurrentVersion\Themes\Personalize` con `AppsUseLightTheme = 0`, `SystemUsesLightTheme = 0`, `EnableTransparency = 1`.
2. **`autounattend.xml` (`FirstLogonCommands`):**
   * En el bloque `<FirstLogonCommands>` que corre en el primer inicio de sesión del usuario:
     * Agregar comandos síncronos para aplicar `AppsUseLightTheme = 0` y `SystemUsesLightTheme = 0` directamente en `HKCU`.
3. **`SetupComplete.cmd`:**
   * Agregar bloque explícito que configure `InstallTheme = C:\Windows\resources\Themes\dark.theme` y `Themes\Personalize` a nivel de máquina.

### Fase 3: Corrección en `PostInstall-Diagnostics.ps1`
* Auditar primero `HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`.
* Si no está presente, auditar `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize`.
* Reportar adecuadamente `Modo Oscuro Activo` o `Modo Claro`.

### Fase 4: Pruebas Unitarias Harness
* Agregar asertos unitarios en `scripts/Test-OptimizedISO-v2.ps1` validando la presencia de las directivas `POL_THEME_*` y su presencia en los bloques de exportación XML y scripts generados.
* Validación estricta con Windows PowerShell 5.1 y UTF-8 con BOM.

---

## 5. Criterios de Aceptación

1. **Cero regresiones en Windows PowerShell 5.1:** Validado con `-WhatIf` y comprobación AST (Regla 4).
2. **SSOT Conforme:** `Policy-Engine.ps1` exporta las directivas de tema en `Export-RomanOSUnattendCommands`.
3. **ISO Multi-Capa:** Una ISO instalada en limpio inicia inmediatamente con la barra de tareas, menú inicio y ventanas del explorador en Modo Oscuro nativo sin interacción del usuario.
4. **Harness Unitario:** 100% PASS en los asertos de PLAN-0030.
