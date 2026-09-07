# PLAN-0050: Integración Total de Módulos del Toolkit Maestro, Controladores y Scripts Faltantes en la ISO

**Fecha:** 2026-09-07  
**Autor:** romanOS / OptimizedISO Project Team (Advanced Agentic Coding)  
**Estado:** COMPLETADO  
**Rama:** `feature/offline-ui-tweaks`  

---

## 1. Resumen Ejecutivo y Diagnóstico Forense

### 1.1 El Problema Reportado
Al desplegar una máquina virtual o equipo físico desde una ISO generada por `New-OptimizedWindowsISO-v2.ps1` y ejecutar el Hub Central `romanOS-Toolkit.ps1` (o su lanzador `romanOS-Toolkit.cmd`), se producen fallos por ausencia física de scripts en el sistema operativo instalado:

1. **Opción 6 (Navegadores):** Arroja el error `[ERROR] No se encontro Optimize-WebBrowsers.ps1`.
2. **Opción 8 -> 2 (Limpieza de DriverStore):** Arroja el error `[ERROR] No se encontro Clean-DriverStore.ps1`.
3. **Opción 8 -> 1 y 3 (Gestión de Controladores):** No encuentra `Backup-HardwareDrivers.ps1` ni `Get-CriticalDrivers.ps1`.
4. **Opción 7 (Windows Updates):** No encuentra `Get-WindowsUpdates.ps1`.
5. **Opción 9 (Migración de Usuario):** No encuentra `Migrar-Usuario-W11.ps1`.
6. **Trampa de Selección de Opción 2 en el Menú del Builder:** Si durante la generación de la ISO el usuario elige `[2] romanOS-Toolkit.ps1 (Hub Maestro Orquestador Completo)`, el Builder inyectaba **únicamente** el archivo `romanOS-Toolkit.ps1` a la colección `$scriptsToInject` y omitía los 4 scripts orquestados (`Win11-Debloat-v3-Adaptive.ps1`, `Invoke-WindowsMaintenance.ps1`, `Win11-Network-Diagnostics-Optimizer.ps1`, `Invoke-WindowsSecurityHardening.ps1`), provocando que 8 de las 11 opciones del Toolkit quedaran completamente muertas.

### 1.2 Causa Raíz Identificada
- **Inyección física incompleta en el Builder (`New-OptimizedWindowsISO-v2.ps1`):**
  El Builder inyecta `Core\` (`Hardware-Engine.ps1`, `Policy-Engine.ps1`, `UI-Engine.ps1`), `Runtimes\` y `PostInstall-Diagnostics.ps1`, pero **nunca** copia la carpeta `scripts\Drivers\` ni los módulos complementarios `Optimize-WebBrowsers.ps1`, `Migrar-Usuario-W11.ps1` o `Get-WindowsUpdates.ps1` ni a `$OEM$` ni al WIM montado.
- **Acoplamiento erróneo del menú interactivo del Builder:**
  El Builder asumía que el Toolkit era una herramienta autónoma autocontenida, ignorando que el Toolkit es un orquestador que invoca scripts hermanos en `C:\Windows\Setup\Scripts\`.
- **Rutas hardcodeadas con `$PSScriptRoot` en `Show-QuickActionsMenu`:**
  En `romanOS-Toolkit.ps1` (líneas 350, 379, 389), el menú de acciones rápidas concatena rígidamente `$PSScriptRoot` en lugar de usar la función dinámica `Resolve-ToolScript`.

---

## 2. Objetivos Técnicos y Arquitectura de la Solución

1. **Inyección Física Incondicional de la Suite Completa (SSOT - Regla 10):**
   - En `New-OptimizedWindowsISO-v2.ps1`, incorporar bloques de copia automática (tanto en `$OEM$` como en el WIM montado) para:
     - `scripts\Drivers\*` -> `C:\Windows\Setup\Scripts\Drivers\` (`Clean-DriverStore.ps1`, `Backup-HardwareDrivers.ps1`, `Get-CriticalDrivers.ps1` y sus correspondientes `.cmd`).
     - `scripts\Modules\Optimize-WebBrowsers.ps1` (y su `.cmd`) -> `C:\Windows\Setup\Scripts\`.
     - `scripts\Modules\Migrar-Usuario-W11.ps1` -> `C:\Windows\Setup\Scripts\`.
     - `scripts\Builder\Get-WindowsUpdates.ps1` (y su `.cmd`) -> `C:\Windows\Setup\Scripts\`.
2. **Garantizar la Presencia de Submódulos al Seleccionar el Toolkit Maestro:**
   - Si en el menú interactivo o presets se selecciona la opción `[2] romanOS-Toolkit.ps1`, el Builder asegurará que todos los scripts auxiliares (`Win11-Debloat-v3-Adaptive.ps1`, `Invoke-WindowsMaintenance.ps1`, `Win11-Network-Diagnostics-Optimizer.ps1`, `Invoke-WindowsSecurityHardening.ps1`) queden físicamente inyectados en `C:\Windows\Setup\Scripts`, manteniendo un único acceso directo principal en el Escritorio / Menú Inicio ("romanOS Toolkit Maestro").
3. **Resiliencia de Resolución en `Resolve-ToolScript`:**
   - Expandir las rutas de búsqueda en `romanOS-Toolkit.ps1` para incluir carpetas `Modules`, `Builder` y rutas absolutas canónicas.
   - En `Show-QuickActionsMenu`, reemplazar concatenaciones directas con `$PSScriptRoot` por llamadas a `Resolve-ToolScript`.
4. **Cumplimiento Estricto de Reglas del Proyecto:**
   - Codificación UTF-8 con BOM (`0xEF, 0xBB, 0xBF`) en todos los archivos modificados.
   - Validación en frío con Windows PowerShell 5.1 (`powershell.exe`).
   - Auditoría y verificación en el Test Harness (`Test-OptimizedISO-v2.ps1`) con meta de 100% PASS.

---

## 3. Matriz de Archivos Afectados

| Archivo | Acción | Descripción |
|---|---|---|
| `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` | MODIFICAR | Inyectar incondicionalmente carpeta `Drivers\`, `Optimize-WebBrowsers.ps1`, `Migrar-Usuario-W11.ps1` y `Get-WindowsUpdates.ps1` en `$OEM$` y en el WIM montado. Garantizar submódulos al seleccionar Toolkit. |
| `scripts/Modules/romanOS-Toolkit.ps1` | AUDITAR / MODIFICAR | Expandir `$searchDirs` en `Resolve-ToolScript` y reemplazar `$PSScriptRoot` por `Resolve-ToolScript` en `Show-QuickActionsMenu`. |
| `scripts/Testing/Test-OptimizedISO-v2.ps1` | MODIFICAR | Añadir suite de aserciones unitarias e integración para PLAN-0050. |
| `docs/plans/README.md` | MODIFICAR | Registrar PLAN-0050 en el índice de planes (actualizar a COMPLETADO tras verificar). |
| `docs/plans/PLAN-0050-20260907-integracion-total-toolkit-maestro-drivers-y-modulos-en-iso.md` | MODIFICAR | Actualizar estado y reporte de ejecución tras verificar. |

---

## 4. Plan de Verificación

1. **Auditoría Estática AST y Codificación UTF-8 con BOM (Windows PowerShell 5.1):**
   - Ejecutar validador AST sobre los archivos modificados.
   - Confirmar presencia estricta de UTF-8 BOM (`0xEF, 0xBB, 0xBF`).
2. **Prueba de Inyección Simulada del Builder:**
   - Comprobar que en la fase de inyección de archivos se auditen y copien los 15 scripts del ecosistema.
3. **Ejecución del Test Harness:**
   - Ejecutar `Test-OptimizedISO-v2.ps1` mediante `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass` y verificar 100% PASS (0 fallos).

---

## 5. Resultados de Verificación y Cierre

- **Auditoría AST y UTF-8 BOM:** Evaluados 25 scripts de PowerShell del repositorio. Resultado: **25 PASS (100%), 0 FAIL**. Todos con UTF-8 BOM intacto (`0xEF, 0xBB, 0xBF`) y 0 errores sintácticos en Windows PowerShell 5.1 (`powershell.exe`).
- **Test Harness (`Test-OptimizedISO-v2.ps1`):**
  - Total de Pruebas: 348
  - PASS: 347 (99.7%)
  - FAIL: 0
  - SKIP: 1 (ADK opcional)
  - Resultado Global: **TODOS LOS TESTS PASARON EXITOSAMENTE. Script verificado para producción.**
