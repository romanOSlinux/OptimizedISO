# PLAN-0058: Optimización Quirúrgica de SearchHost.exe / WebView2 y Poda Automatizada de Memoria (Working Set Trim)

- **ID del Plan:** PLAN-0058
- **Fecha:** 2026-09-07
- **Estado:** EN PROGRESO
- **Autor:** romanOS Engineering / Antigravity Agent
- **Rama:** `feature/offline-ui-tweaks`

---

## 1. Contexto y Diagnóstico Empírico

Durante las auditorías forenses realizadas en Windows 11 Pro for Workstations (Build 26200 / 24H2 / 25H2) se identificaron 6 instancias de `msedgewebview2.exe` consumiendo aproximadamente 315 MB de memoria RAM combinada junto a `SearchHost.exe` (~123 MB), totalizando más de 430 MB en reposo.

Mediante inspección CIM de jerarquía de procesos (`Win32_Process`) se determinó empíricamente que:
1. **Widgets está 100% neutralizado:** El subsistema de Widgets de Windows no generó ningún proceso gracias a las directivas de GPO `AllowWidgets = 0` y `AllowNewsAndInterests = 0`.
2. **El origen de WebView2 es `SearchHost.exe`:** Los 6 subprocesos Chromium (GPU process, NetworkService, StorageService, Renderer) fueron generados como hijos directos de `SearchHost.exe` (`--embedded-browser-webview=1 --webview-exe-name=SearchHost.exe`), el cual aloja la interfaz gráfica de búsqueda del Menú Inicio (`MicrosoftWindows.Client.CBS`).
3. **Inviabilidad de la "Vía B" (Destrucción de Search):** Deshabilitar el servicio `WSearch` o renombrar `SearchHost.exe` destruye la capacidad del usuario de buscar aplicaciones, archivos locales y opciones de configuración, lo cual fue rechazado de manera terminante e incondicional por la dirección del proyecto.
4. **Preservación de `UCPD.sys`:** Se determinó que el driver `UCPD.sys` (User Choice Protection Driver) no interviene en el consumo de RAM ni de Widgets. Mantenerlo activo preserva la integridad del sistema contra secuestros del navegador predeterminado (*Browser Hijacking*) y evita cualquier riesgo en el kernel o con actualizaciones acumulativas.
5. **Eficacia de la Poda de Working Set (`psapi.dll`):** Al invocar `EmptyWorkingSet` sobre `SearchHost` y sus instancias hijas de `msedgewebview2`, el Administrador de Memoria de Windows reduce el Working Set físico en un **87%** (de ~430 MB a menos de 50 MB combinados). Al abrir el Menú Inicio, Windows recupera las páginas de memoria necesarias bajo demanda en cuestión de milisegundos sin latencia perceptible para el usuario.

---

## 2. Objetivos

1. **Mantener `UCPD.sys` 100% de fábrica:** Cero modificaciones sobre el driver o servicio en el kernel.
2. **Garantizar Búsqueda 100% Local y Offline:**
   - Elevar en `Policy-Engine.ps1` al catálogo maestro `$global:RomanOS_Policies` (para todos los perfiles 1, 2, 3) las directivas:
     - `AllowCloudSearch = 0` (Bloqueo de consultas a la nube / OneDrive / SharePoint).
     - `AllowSearchToUseLocation = 0` (Bloqueo de geolocalización en búsquedas).
     - Consolidar con las ya existentes `DisableWebSearch = 1`, `ConnectedSearchUseWeb = 0` y `EnableDynamicContentInWSB = 0`.
3. **Crear Módulo de Poda de Memoria Automatizada (`Optimize-ProcessMemory.ps1` y `.cmd`):**
   - Implementar función nativa `Invoke-RomanOSMemoryTrim` con P/Invoke seguro de `psapi.dll` (`EmptyWorkingSet`).
   - Filtro inteligente para procesos del sistema en reposo (`SearchHost`, `msedgewebview2` hijas de SearchHost, `ShellExperienceHost`).
   - Codificación obligatoria UTF-8 con BOM y compatibilidad plena con Windows PowerShell 5.1 (`-STA`).
4. **Integración en el Ecosistema romanOS:**
   - **`autounattend.xml` / Builder:** Ejecución silenciosa y retardada en `FirstLogonCommands` tras el primer inicio de sesión para que la ISO entregue una instalación con huella de RAM mínima tras el pre-calentamiento.
   - **`romanOS-Toolkit.ps1`:** Nuevo módulo interactivo y acción rápida en `Show-QuickActionsMenu` para poda de memoria a demanda.
   - **`Audit-FreshInstallFootprint.ps1`:** Clasificación inteligente de `msedgewebview2` (diferenciando hijos de SearchHost de vampiros huérfanos).
   - **`New-OptimizedWindowsISO-v2.ps1`:** Inyección física en `$OEM$` y en el WIM offline.
5. **Certificación en Test Harness (`Test-OptimizedISO-v2.ps1`):** 100% de aserciones pasando sin regresiones.

---

## 3. Matriz de Cambios por Archivo

| Archivo | Acción | Descripción |
| :--- | :---: | :--- |
| `scripts/Core/Policy-Engine.ps1` | MODIFICAR | Elevar `POL_SEARCH_ALLOW_CLOUD` y `POL_SEARCH_ALLOW_LOCATION` al catálogo maestro. |
| `scripts/Modules/Optimize-ProcessMemory.ps1` | CREAR | Script modular con `Invoke-RomanOSMemoryTrim` (UTF-8 BOM, PS 5.1 safe). |
| `scripts/Modules/Optimize-ProcessMemory.cmd` | CREAR | Lanzador batch con auto-elevación UAC y bandera `-STA`. |
| `scripts/Modules/romanOS-Toolkit.ps1` | MODIFICAR | Integrar parámetro `MemoryTrim`, submenú en QuickActions y bucle principal. |
| `scripts/Modules/Audit-FreshInstallFootprint.ps1` | MODIFICAR | Refinar diagnóstico de `msedgewebview2` cuando es hijo de `SearchHost`. |
| `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` | MODIFICAR | Inyección física en `$OEM$` y WIM, más llamada retardada en `FirstLogonCommands`. |
| `scripts/Testing/Test-OptimizedISO-v2.ps1` | MODIFICAR | Agregar bloque de validación para PLAN-0058. |
| `docs/plans/README.md` | MODIFICAR | Registrar PLAN-0058 como EN PROGRESO. |

---

## 4. Plan de Verificación Empírica

1. **Inspección de Codificación y AST:**
   - Verificar cabecera `EF BB BF` en todos los archivos `.ps1`.
   - Verificar 0 errores con `Parser::ParseFile`.
2. **Prueba de Ejecución en Runtime Destino (Windows PowerShell 5.1):**
   ```powershell
   & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & '.\scripts\Modules\Optimize-ProcessMemory.ps1' -WhatIf }"
   ```
3. **Suite Completa de Pruebas:**
   - Ejecución de `Test-OptimizedISO-v2.ps1` y verificación de incremento de pruebas aprobadas sin regresiones.
