# PLAN-0161: Transición hacia Producción Universal, Saneamiento de Residuos y Sincronización en Git

**Número Correlativo:** 0161  
**Fecha:** 2026-10-24  
**Estado:** EN PROGRESO  
**Tipo:** Plan Maestro de Ingeniería / Release a Producción  
**Área:** Repo-Wide (Core, Modules, GUI, Drivers, Builder, Git, Testing)  
**Documento Fuente de Verdad:** [`AUDITORIA_INTEGRAL_PRODUCCION_UNIVERSAL_2026.html`](file:///c:/OptimizedISO/AUDITORIA_INTEGRAL_PRODUCCION_UNIVERSAL_2026.html)

---

## 1. Contexto y Diagnóstico Forense

El repositorio ha alcanzado la madurez de su Era 3 (Agentic OS), con un motor SSOT centralizado ([`scripts/Core/Policy-Engine.ps1`](file:///c:/OptimizedISO/scripts/Core/Policy-Engine.ps1)), motor de hardware adaptativo ([`scripts/Core/Hardware-Engine.ps1`](file:///c:/OptimizedISO/scripts/Core/Hardware-Engine.ps1)) y suites de usuario final ([`romanOS-ControlCenter.ps1`](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter.ps1) y [`romanOS-Studio.ps1`](file:///c:/OptimizedISO/scripts/GUI/romanOS-Studio.ps1)).

Sin embargo, para dar el salto formal a **distribución pública de producción comercial**, la auditoría de 187 scripts reveló los siguientes desafíos:
1. **Brecha en Git:** La rama pública `main` en GitHub (`origin/main`) está congelada en el commit legacy `39ce7f0` (367 commits por detrás del estándar actual).
2. **Residuos y Anomalías Identificadas:**
   - `scripts/Modules/Migrar-Usuario-W11.ps1`: Contiene 1 bloque `catch { $null }` (CWE-390) en la línea 50 y prompts interactivos `Read-Host`.
   - Dispersión de lanzadores en la raíz (`Lanzar-Builder.cmd`, `Migrar-Usuario.cmd`, `Lanzar-y-Guardar-Preset.cmd`) que deben consolidarse en un único despachador central `Lanzar-romanOS.cmd` / `Lanzar-romanOS.ps1`.
3. **Falta del Empaquetador de Distribución:** No existía un script que ensamble la distribución USB portátil (incluyendo `tools/` con hashes Authenticode verificados) sin contaminar Git.

---

## 2. Inventario Cuantitativo de Scripts

Auditados los 187 scripts del repositorio contra las 22 reglas de gobernanza:
* **Total Scripts:** 187
* **Codificación Certificada:** 187 / 187 (100% PASS - UTF-8 BOM en PS / No-BOM en CMD)
* **Errores AST de Sintaxis:** 0
* **Sesgo Personal / Operador Único:** 0 / 187 (100% neutralizado a `"Usuario"`)
* **Sesgo de Hardware Fijo:** 0 / 187 (100% dinámico con Hardware-Engine)
* **Destino para Producción:**
  - `PRODUCCION-CORE`: 13 scripts
  - `PRODUCCION-MODULE`: 45 scripts
  - `PRODUCCION-GUI`: 7 scripts
  - `PRODUCCION-DRIVER`: 6 scripts
  - `PRODUCCION-BUILDER`: 6 scripts
  - `PRODUCCION-HELPER`: 17 scripts
  - `PRODUCCION-TOOL`: 13 scripts
  - `PRODUCCION-LAUNCHER`: 4 scripts
  - `SOLO-DESARROLLO-TEST` (Excluidos de paquete USB): 44 scripts
  - `SOLO-DESARROLLO-AGENT` (Excluidos de paquete USB): 9 scripts
  - `RESIDUOS A SANEAR / UNIFICAR`: 5 scripts

---

## 3. Fases de Implementación Detalladas

```
  ┌───────────────────┐     ┌───────────────────┐     ┌───────────────────┐     ┌───────────────────┐     ┌───────────────────┐
  │ FASE 1: SANEAMIENTO│ ──▶ │ FASE 2: LANZADOR  │ ──▶ │ FASE 3: SNAPSHOT  │ ──▶ │ FASE 4: EMPAQUETADO│ ──▶ │ FASE 5: GIT MAIN  │
  │   DE RESIDUOS     │     │   TRI-MODAL       │     │   OBLIGATORIO     │     │   DE DISTRIBUCIÓN │     │   Y TAG V3.0      │
  │ (CWE-390 / Raíz)  │     │ (Lanzar-romanOS)  │     │ (Control Center)  │     │ (ZIP USB Offline) │     │ (Release Oficial) │
  └───────────────────┘     └───────────────────┘     └───────────────────┘     └───────────────────┘     └───────────────────┘
```

### Fase 1: Saneamiento de Residuos (CWE-390 y Desacople Interactivo) [COMPLETADA]
* **Objetivo:** Garantizar que ningún script viole la Regla 13 (CWE-390) ni quede bloqueado por prompts interactivos en terminal.
* **Tareas Específicas:**
  - [x] Refactorizar `scripts/Modules/Migrar-Usuario-W11.ps1`:
    - Erradicar el bloque `catch { $null }` en L50; sustituir por emisión de `Write-Warning` y telemetría de fallback seguro hacia `$env:SystemDrive\Users`.
    - Dotar de soporte `-Unattended` / `-NonInteractive` para ejecución no interactiva desde Control Center o subprocesos sin pausas de `Read-Host`.
    - Robustecer manejo de errores y mitigaciones fail-visible sin excepciones silenciosas.
    - Certificado en UTF-8 con BOM y probado en Windows PowerShell 5.1.
  - [x] Decomisionar de la raíz `Migrar-Usuario.cmd` (preservando el acceso oficial en `romanOS-ControlCenter.ps1` y `scripts/Modules/Migrar-Usuario-W11.cmd`).
  - [x] Decomisionar `Lanzar-Builder.cmd` de la raíz pública y trasladar `Lanzar-y-Guardar-Preset.cmd` a `scripts/Host-Tools/` con ruta de repositorio corregida.
* **Criterio de Aceptación:** `audit-inventory.ps1` reporta 0 capturas vacías (CWE-390) y 0 errores AST en todo el repo. 109/109 contratos funcionales PASS. 652/652 pruebas del Builder PASS.

### Fase 2: Implementación del Punto de Entrada Universal Tri-Modal [COMPLETADA]
* **Objetivo:** Unificar el acceso en un único despachador universal que soporte ejecución Web 1-Liner, USB Offline y Local.
* **Tareas Específicas:**
  - [x] Implementar `Lanzar-romanOS.ps1` en la raíz (UTF-8 con BOM):
    - Detección de medio de ejecución (Local-USB-Offline vs Web-Remote-Bootstrap vs System Scripts).
    - Auto-elevación UAC silenciosa mediante `System.Diagnostics.ProcessStartInfo` con verb `runas` si no corre como Administrador.
    - Enlace transparente con `scripts/GUI/romanOS-ControlCenter.ps1` en modo `-STA` obligatorio.
    - Soporte completo para `-WhatIf`, `-PassThru`, `-NoGui`, `-Offline`.
    - Certificado en UTF-8 con BOM y 0 errores AST.
  - [x] Implementar `Lanzar-romanOS.cmd` en la raíz (Win32 No-BOM bootstrap):
    - Lanzador doble-clic para el usuario de Windows común que no sabe abrir PowerShell.
    - Auto-elevación UAC nativa, fijación de directorio y despacho a `Lanzar-romanOS.ps1` con `-STA`.
  - [x] Integrar y validar aserciones de regresión en `Test-FunctionalContracts.ps1` (CTR-49).
* **Criterio de Aceptación:** Ejecución exitosa de `Lanzar-romanOS.cmd` y `Lanzar-romanOS.ps1 -WhatIf` con ExitCode 0 en Windows PowerShell 5.1. 112/112 aserciones PASS (100%).

### Fase 3: Snapshot de Seguridad Obligatorio en la GUI
* **Objetivo:** Cumplir el principio de Cero Daño garantizando reversibilidad en 1 clic antes de cualquier modificación.
* **Tareas Específicas:**
  - [ ] Integrar en `scripts/GUI/romanOS-ControlCenter.ps1`:
    - Disparo automático o confirmación de snapshot preventivo (`Manage-SystemSnapshots.ps1 -Action Create -Name "Pre-Optimizacion-romanOS" -IncludeVSS`) antes de ejecutar optimizaciones masivas.
    - Botón canónico permanente en cabecera: **"↩ Revertir al Estado Inicial en 1 Clic"** que invoca `Manage-SystemSnapshots.ps1 -Action Restore`.
* **Criterio de Aceptación:** `Test-GuiIntegrityAndFunctionality.ps1` certifica 121/121 botones cableados y 0 dead buttons.

### Fase 4: Script Empaquetador de Distribución (`Build-ProductionPackage.ps1`)
* **Objetivo:** Ensamblar el producto final portátil para USB y GitHub Releases sin contaminar el repositorio Git (Regla 6).
* **Tareas Específicas:**
  - [ ] Crear `scripts/Builder/Build-ProductionPackage.ps1`:
    - Ensambla la carpeta `dist/romanOS-USB-Portable/` incluyendo:
      * `Lanzar-romanOS.cmd` y `Lanzar-romanOS.ps1`
      * `scripts/Core/`, `scripts/GUI/`, `scripts/Modules/`, `scripts/Drivers/`, `scripts/Desktop-Helpers/`, `scripts/Host-Tools/`
      * Presets universales (`Preset_Gaming_Universal.json`, `Preset_Workstation_Universal.json`)
      * Copia verificada de `tools/` (`wimlib-imagex.exe`, `Coreinfo64.exe`, `sigcheck64.exe`, `es.exe`)
    - Exclusión estricta de `scripts/Testing/`, `.agents/`, `.git/`, logs y basuras.
    - Genera el archivo comprimido `dist/romanOS-Universal-v3.0.0.zip`.
* **Criterio de Aceptación:** El ZIP generado se descomprime y ejecuta de forma autónoma en modo simulado sin fallos de dependencias.

### Fase 5: Certificación Repo-Wide y Salida Oficial a Git
* **Objetivo:** Promover el ecosistema validado hacia la rama `main` y publicar la versión oficial.
* **Tareas Específicas:**
  - [ ] Ejecutar arnés completo: `Invoke-RomanOSHarness.ps1` (16 Fases PASS, 100% cumplimiento).
  - [ ] Crear rama de respaldo del legacy histórico: `git branch archive/legacy-main-initial main`.
  - [ ] Checkout a `main` y merge formal de `feature/offline-ui-tweaks`.
  - [ ] Reescritura del `README.md` principal con badges de build, comando Web 1-Liner e instrucciones USB.
  - [ ] Generar tag SemVer `v3.0.0-universal` y push al remoto (`git push origin main --tags`).
* **Criterio de Aceptación:** GitHub Actions ejecuta `release.yml` y publica el Release oficial con el ZIP descargable.

---

## 4. Fuentes Oficiales de Respaldo Epistémico

1. **Microsoft Learn:** Group Policy CSPs, Task Scheduler Automatic Maintenance (`MaintenanceDisabled`).
2. **Intel Corporation:** Intel 64 and IA-32 Architectures Optimization Reference Manual (Hybrid P/E Cores).
3. **Advanced Micro Devices:** AMD Processor Programming Reference (PPR / CPPC Zen 4 / Zen 5).
4. **Microsoft Hardware Dev:** WDDM 2.7+ Hardware-Accelerated GPU Scheduling (HAGS).
5. **Microsoft Learn:** BypassIO for Storage & DirectStorage Architecture.
6. **Microsoft Learn:** Recommended Driver Block Rules (Anti-Cheat Ring-0 safe).

---

## 5. Protocolo de Reanudación Post-Reinicio de la PC

Cuando la PC se reinicie y abras una nueva sesión:
1. El agente leerá este plan (`PLAN-0161`) y el dashboard [`AUDITORIA_INTEGRAL_PRODUCCION_UNIVERSAL_2026.html`](file:///c:/OptimizedISO/AUDITORIA_INTEGRAL_PRODUCCION_UNIVERSAL_2026.html).
2. Comenzará inmediatamente con la **Fase 1 (Saneamiento de Residuos en Migrar-Usuario-W11.ps1 y lanzadores de raíz)**.
3. Avanzará continuamente de forma autónoma (Regla 8) reportando cada hito verificado.
