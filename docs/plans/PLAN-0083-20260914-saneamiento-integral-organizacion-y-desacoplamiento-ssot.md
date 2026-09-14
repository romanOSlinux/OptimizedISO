# PLAN-0083: Saneamiento Integral, Organización de Raíz y Unificación Arquitectónica SSOT

**Fecha:** 2026-09-14  
**Estado:** COMPLETADO  
**Área:** Arquitectura Global, Higiene de Git, Organización de Raíz y Unificación de Motores

---

## 1. Contexto y Diagnóstico

Tras la auditoría completa del repositorio `c:\OptimizedISO`, se detectaron 4 áreas de deuda técnica y desorden:
1. **Archivos muertos, rotos o huérfanos:** Scripts de hotfixes pasados con rutas rotas (`Aplicar-Hotfix-PLAN0029.cmd`, `Aplicar-Hotfix-Menus.cmd` en raíz), paquetes obsoletos (`OptimizedISO-Package/`), carpetas vacías (`tests/`, `scripts/Extras/`), archivos sin extensión (`optimizediso`) y manifiestos antiguos.
2. **Duplicación de Runtimes y Binarios en Git:** Dos carpetas idénticas de Runtimes (`/Runtimes/` y `scripts/Runtimes/`, 162 MB c/u) y dos binarios DLL rastreados en Git (`DSETUP.dll`, `dsetup32.dll`) en violación de la Regla 6.
3. **Duplicación de Motores Satélite (`-GUI-Engine.ps1`):** Más de 850 KB de lógica clonada entre scripts CLI y GUI en `Builder`, `Drivers` y `Host-Tools`, creando riesgo constante de desvío de configuración (*configuration drift*).
4. **Desorden en la Raíz:** 9 archivos `.cmd` y `.vbs` en la raíz que dispersan los puntos de entrada para el usuario.

---

## 2. Objetivos y Fases de Implementación

### Fase 1: Saneamiento Inmediato de Residuos y Código Muerto (Cero Riesgo Funcional)
- Eliminar `Aplicar-Hotfix-PLAN0029.cmd` (apunta a archivo inexistente).
- Eliminar `Aplicar-Hotfix-Menus.cmd` (en la raíz, roto; se mantiene el de `scripts/`).
- Eliminar `optimizediso` (archivo sin extensión redundante con `README.md`).
- Eliminar `scratch/Drivers/Backup-HardwareDrivers.ps1` (0 bytes).
- Eliminar `OptimizedISO-Package/` (`.gitkeep` y `OptimizedISOHelpers.psm1`, nunca importado).
- Eliminar directorio vacío `tests/`.
- Eliminar directorio vacío `scripts/Extras/`.
- Eliminar `scripts/Updates/11_24H2_amd64/Updates_Manifest.json` (manifiesto obsoleto de versión vieja).
- Desvincular de Git (`git rm --cached`) `scripts/Runtimes/DirectX/DSETUP.dll` y `dsetup32.dll`.

### Fase 2: Consolidación de Espacio y Carpetas de Descargas
- Eliminar la carpeta duplicada `scripts/Runtimes/` (ahorrando 162 MB en disco; el script oficial ya descarga a `\Runtimes` en la raíz).
- Actualizar `.gitignore` para blindar cualquier subdirectorio de runtimes/drivers contra inclusiones accidentales.
- Eliminar `scripts/Modules/Auditar-Instalacion.cmd` (duplicado idéntico de `PostInstall-Diagnostics.cmd`).
- Mover `scripts/Auditar-Optimizacion-PC.cmd` -> `scripts/Modules/Auditar-Optimizacion-PC.cmd`.
- Eliminar `scripts/Host-Tools/get-essential-runtimes.sh` (obsoleto con rutas desalineadas).

### Fase 3: Desacoplamiento y Unificación de Motores (SSOT)
- Parametrizar y unificar los 6 scripts base:
  1. `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` (incorporar flags de streaming/no-interactivo y eliminar `New-OptimizedWindowsISO-GUI-Engine.ps1`).
  2. `scripts/Builder/Get-WindowsUpdates.ps1` (incorporar parámetros no interactivos y eliminar `-GUI-Engine.ps1`).
  3. `scripts/Builder/Get-EssentialRuntimes.ps1` (incorporar parámetros no interactivos y eliminar `-GUI-Engine.ps1`).
  4. `scripts/Drivers/Backup-HardwareDrivers.ps1` (unificar y eliminar `-GUI-Engine.ps1`).
  5. `scripts/Drivers/Get-CriticalDrivers.ps1` (unificar y eliminar `-GUI-Engine.ps1`).
  6. `scripts/Host-Tools/Limpiar-ResiduosWinISO.ps1` (unificar y eliminar `-GUI-Engine.ps1`).
- Actualizar `scripts/GUI/romanOS-Studio.ps1` para invocar directamente los scripts base unificados.
- Ejecutar la suite de pruebas `scripts/Testing/Test-OptimizedISO-v2.ps1` e inspeccionar con `grep_search` que no existan errores ni referencias rotas.

### Fase 4: Organización Limpia de la Raíz del Proyecto
- Mantener en la raíz exclusivamente:
  - `Lanzar-romanOS-Studio.cmd` y `Lanzar-romanOS-Studio.vbs` (Entrada GUI).
  - `Lanzar-Builder.cmd` (Entrada CLI).
  - `README.md`, `MEMORY.md`, `.gitignore`, `Preset_Host_Ryzen8600G.json`.
- Mover los lanzadores especializados (`Lanzar-Builder-Con-Preset.cmd`, `Lanzar-y-Guardar-Preset.cmd`, `Compilar-ISO-Host-Ryzen8600G.cmd`, `Migrar-Usuario.cmd`) a una carpeta organizada `scripts/Launchers/` o crear accesos limpios.

---

## 3. Plan de Verificación

1. **Validación de Sintaxis AST y UTF-8 BOM:**
   `powershell -ExecutionPolicy Bypass -File .agents/scripts/pre-commit-gateway.ps1`
2. **Suite de Integración y Regresiones:**
   `powershell -STA -NoProfile -ExecutionPolicy Bypass -File scripts/Testing/Test-OptimizedISO-v2.ps1`
3. **Auditoría Forense de Logs (Regla 12):**
   `grep_search` buscando `FAIL`, `ERROR` o `Exception` en los logs generados.
4. **Verificación de Invocación GUI:**
   Probar en frío el inicio de `romanOS-Studio.ps1` y verificar que las rutas a los scripts unificados existan y respondan correctamente.
