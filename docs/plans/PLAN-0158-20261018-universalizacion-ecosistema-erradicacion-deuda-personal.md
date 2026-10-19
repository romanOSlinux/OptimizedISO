# PLAN-0158: Universalización Integral del Ecosistema romanOS y Erradicación Total de Deuda Personal y Rutas Hardcodeadas

## Metadatos
- **ID:** PLAN-0158
- **Fecha:** 2026-10-18
- **Estado:** COMPLETADO
- **Autor:** romanOS Core Engineering & Antigravity AI
- **Regla Asociada:** Regla 20 (.agents/AGENTS.md - Principio de Producto Universal y Prohibición Taxativa de Parches Ad-Hoc / Single-User)

---

## 1. Contexto y Objetivos

### 1.1 Contexto
Durante la evolución histórica del proyecto (en particular en PLAN-0063), se crearon artefactos diseñados específicamente para la estación de trabajo local del operador (AMD Ryzen 5 8600G, usuario "Roman", región "es-AR", juego World of Tanks). Adicionalmente, decenas de scripts asumieron que el repositorio siempre reside en `C:\OptimizedISO`.

Siguiendo la **Regla 20** promulgada en el repositorio, `romanOS` es un producto operativo de grado producción orientado al **público en general**. Por tanto, ninguna interfaz, script inyectado en la ISO, preset o documentación debe asumir un usuario, hardware, juego o ruta específica.

### 1.2 Objetivos
1. **Universalizar la suite de aprovisionamiento post-instalación:**
   - Transformar `Desplegar-Setup-Host.ps1` en un orquestador universal hardware-aware (`Deploy-Workstation-Environment.ps1`), desvinculado de "AMD Ryzen 5 8600G" y de juegos específicos como "World of Tanks".
   - Ofrecer selección abierta de software de gaming y desarrollo desde el catálogo canónico SSOT (`App-Profiles-Catalog.json`).
2. **Universalizar presets y desmantelar lanzadores de hardware único:**
   - Retirar `Compilar-ISO-Host-Ryzen8600G.cmd` y `Preset_Host_Ryzen8600G.json`.
   - Proveer presets universales arquetípicos (`Preset_Gaming_Universal.json` y `Preset_Workstation_Universal.json`) con usuario neutral `"Usuario"`.
   - Saneamiento de `Preset_romanOS_Studio.json`.
   - Actualizar la Fase 2.15 del arnés de pruebas (`Test-OptimizedISO-v2.ps1`) para certificar presets universales.
3. **Estandarizar valores por defecto en GUIs:**
   - En `romanOS-Studio.ps1`, cambiar el usuario por defecto de `"Roman"` a `"Usuario"` y la preselección regional a un valor neutral/automático.
4. **Erradicar `C:\OptimizedISO` repo-wide (~52 archivos):**
   - Reemplazar rutas fijas por resolución jerárquica: `$PSScriptRoot` (repositorio) -> `%SystemRoot%\Setup\Scripts\` (sistema instalado) -> `$env:TEMP\romanOS\` (fallback seguro).
5. **Sanear documentación y ejemplos:**
   - Reemplazar ejemplos de usuario `"Roman"` y rutas personales por `"Usuario"` y `C:\ISOs\`.
6. **Certificación de arnés 100%:**
   - Validar sintaxis, contratos, 0 dead buttons en GUI y aprobar pre-commit hooks.

---

## 2. Fases de Implementación

### Fase 1: Universalización de la Suite de Aprovisionamiento Post-Instalación
- [x] Refactorizar `scripts/Host-Tools/Desplegar-Setup-Host.ps1` hacia una arquitectura agnóstica universal:
  - Eliminar textos fijados a "AMD Ryzen 5 8600G" y detección fija de NPU/Zen 4.
  - Emplear `Hardware-Engine.ps1` para introspección dinámica de CPU/GPU.
  - En la sección Gaming, ofrecer los lanzadores universales (`Steam`, `Epic Games`, `Discord`, `OBS Studio`) erradicando la imposición de World of Tanks / Wargaming.
- [x] Actualizar `scripts/Host-Tools/Desplegar-Setup-Host.cmd` eliminando rutas absolutas y títulos de hardware específico.
- [x] Verificar y actualizar referencias en `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` (inyección en OEM y Public Desktop).

### Fase 2: Desmantelamiento de Presets de Hardware Fijo y Universalización
- [x] Retirar `Compilar-ISO-Host-Ryzen8600G.cmd` y `Preset_Host_Ryzen8600G.json` de la raíz del proyecto.
- [x] Crear `Preset_Gaming_Universal.json` y `Preset_Workstation_Universal.json` con `"LocalUser": "Usuario"`.
- [x] Limpiar `Preset_romanOS_Studio.json` (fijar `"LocalUser": "Usuario"`).
- [x] Actualizar Fase 2.15 en `scripts/Testing/Test-OptimizedISO-v2.ps1` para validar la existencia y estructura de los presets universales.

### Fase 3: Neutralización de Valores por Defecto en romanOS Studio
- [x] En `scripts/GUI/romanOS-Studio.ps1`:
  - Modificar XAML `txtLocalUser`: Text="Usuario".
  - Modificar código de respaldo `$localUser`: fallback a `'Usuario'`.
  - Ajustar selector de locale a estándar neutral.

### Fase 4: Erradicación de `C:\OptimizedISO` en el Ecosistema
- [x] Actualizar los 10 scripts `.cmd` en `scripts/Desktop-Helpers/`:
  - Eliminar la comprobación rígida `C:\OptimizedISO\scripts\Desktop-Helpers\...`.
- [x] Actualizar scripts de módulos (`Deploy-AppProfiles.ps1`, `Optimize-InterruptAffinity.ps1`, `Watchdog-ServiceDrift.ps1`, `Monitor-ThermalEnergy.ps1`, `Audit-SystemOptimization.ps1`, `Manage-SystemSnapshots.ps1`, `Optimize-CpuSilicon.ps1`, `romanOS-Toolkit.ps1`, `Win11-Debloat-v3-Adaptive.ps1`).
- [x] Actualizar `scripts/GUI/romanOS-ControlCenter.ps1` erradicando fallbacks a `C:\OptimizedISO`.
- [x] Actualizar `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` (rutas fijas en Runtimes, Updates, Drivers y Core).
- [x] Actualizar helpers de `scripts/Core/` y `scripts/Drivers/`.

### Fase 5: Saneamiento Documental, Verificación y Certificación Final
- [x] Actualizar guías y comandos en `docs/` (`COMMANDS.md`, `USAGE.md`, `GUIA_DE_EJECUCION_Y_COMANDOS.md`, `README.md`).
- [x] Eliminar o limpiar scripts obsoletos en `scratch/`.
- [x] Ejecutar arneses de certificación:
  - `Test-GuiIntegrityAndFunctionality.ps1` (118/118 PASS)
  - `Test-FunctionalContracts.ps1` (109/109 PASS)
  - `Test-OptimizedISO-v2.ps1` (652/652 PASS)
  - `Invoke-RomanOSHarness.ps1 -Fast` (5/5 PASS, 100% compliance)
- [x] Registrar commit atómico y actualizar `MEMORY.md`.
