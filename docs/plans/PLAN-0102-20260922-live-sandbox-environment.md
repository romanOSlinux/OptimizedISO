# PLAN-0102: romanOS Live Sandbox Environment

**Fecha:** 2026-09-22  
**Estado:** COMPLETADO  
**Autor:** Antigravity / romanOS Software Engineering  
**Alcance:** Ecosistema Completo (Core, Modules, GUI Control Center, Toolkit Maestro, ISO Builder, $OEM$, Testing Harness)

---

## 1. Contexto y Justificación Técnica

En sistemas de alto rendimiento orientados a eSports, modding, creación digital e investigación de software, los usuarios instalan o prueban con frecuencia utilidades de terceros (ej. parches de juegos, configuradores de periféricos, scripts de GitHub, trainers, o binarios de procedencia dudosa).
Ejecutar estos elementos directamente en el sistema host expone al equipo a:
1. **Corrupción y Desvío de Registro:** Claves de directivas alteradas o desconfiguradas irreversiblemente.
2. **Infección y Telemetría Oculta:** Persistencia de malware o miners en segundo plano.
3. **Baneos por Anti-Cheats (Vanguard, EAC, BattlEye):** Detección de binarios residentes en memoria de procesos de fondo.

Si bien Windows 10/11 Pro/Enterprise cuenta con la tecnología nativa *Windows Sandbox* (`Containers-DisposableClientVM`), su adopción es deficiente debido a:
- La característica a menudo se encuentra deshabilitada o falla si la virtualización de CPU (SLAT / AMD-V / Intel VT-x) no está diagnosticada.
- Una instancia estándar de Windows Sandbox inicia un sistema "vainilla" desprovisto de herramientas, sin carpetas compartidas optimizadas, sin políticas de privacidad de navegador y sin la pila de herramientas de romanOS.

### Objetivo
Diseñar e implementar **romanOS Live Sandbox Environment**, un orquestador inteligente, nativo y desacoplado que diagnostica la virtualización de la CPU, automatiza el aprovisionamiento de la característica Windows Sandbox y genera en caliente perfiles `.wsb` (Windows Sandbox Configuration) parametrizados con inyección desatendida de utilidades y aislamiento de red/GPU según el caso de uso.

---

## 2. Arquitectura de romanOS Live Sandbox Environment

```
                          ┌────────────────────────────────────────┐
                          │    romanOS Live Sandbox Engine         │
                          │      (Invoke-LiveSandbox.ps1)          │
                          └───────────────────┬────────────────────┘
                                              │
                                ┌─────────────┴─────────────┐
                                ▼                           ▼
                  [Hardware-Engine.ps1]          [Windows Optional Features]
                  • SLAT / AMD-V / Intel VT-x    • Containers-DisposableClientVM
                  • vGPU Direct3D Acceleration   • Microsoft-Hyper-V Hypervisor
                                │                           │
        ┌───────────────────────┴───────────────────────────┴───────────────────────┐
        ▼                                   ▼                                       ▼
  [Preset: SafeAnalysis]              [Preset: GameModding]                  [Preset: DisposableBrowser]
  • Red: Deshabilitada (Air-Gap)      • Red: Habilitada                      • Red: Habilitada
  • vGPU: Deshabilitada               • vGPU: Habilitada                     • vGPU: Habilitada
  • Mapeo: Carpeta ReadOnly           • Mapeo: Carpeta ReadWrite             • Inyección: Políticas Chromium
  • Diagnóstico estático aislado      • Scripts romanOS inyectados           • Navegación efímera 100% privada
```

### Componentes Clave:
1. **Script Orquestador:**
   `scripts/Modules/Invoke-LiveSandbox.ps1` y `Invoke-LiveSandbox.cmd`
   - Parámetros CLI:
     - `-Action [Launch|GenerateConfig|EnableFeature|Status]`
     - `-Preset [SafeAnalysis|GameModding|DisposableBrowser|Custom]`
     - `-SharedFolder <Path>` (Carpeta del host a mapear)
     - `-ReadOnlySharedFolder` (Switch para forzar sólo lectura)
     - `-EnableNetworking` / `-DisableNetworking`
     - `-EnableGPU` / `-DisableGPU`
     - `-MemoryInMB <Int>`
     - `-Unattended`
     - `-WhatIf`
     - `-SkipElevation`
2. **Generador Dinámico de Configuración XML (`.wsb`):**
   - Creación en tiempo de ejecución en `$env:TEMP\romanOS_Sandbox_<ID>.wsb` con etiquetas oficiales de Microsoft:
     `<Configuration>`, `<VGpu>`, `<Networking>`, `<MappedFolders>`, `<LogonCommand>`.
3. **Integración con romanOS Control Center (WPF XAML):**
   - Nueva tarjeta en la pestaña "Seguridad & Navegadores" con selección de Presets, selector de carpeta compartida, switches de Red/GPU y botón de lanzamiento 1-clic.
4. **Integración con romanOS Toolkit Maestro:**
   - Opción 21 en el menú interactivo principal y soporte CLI `-Module Sandbox`.
5. **Inyección en Despliegue e ISO:**
   - `$OEM$\$$\Setup\Scripts\Modules` y WIM montado offline (`$wimModulesDest`).
6. **Suite de Pruebas Unitarias:**
   - `scripts/Testing/Test-LiveSandbox.ps1` y `.cmd` (Fase 12 permanente en `Invoke-TestSuite.ps1`).

---

## 3. Plan de Archivos y Modificaciones

### Nuevos Archivos
1. `scripts/Modules/Invoke-LiveSandbox.ps1`: Motor de diagnóstico, orquestación y generación de entornos `.wsb`.
2. `scripts/Modules/Invoke-LiveSandbox.cmd`: Lanzador Win32 (No-BOM, UAC, STA).
3. `scripts/Testing/Test-LiveSandbox.ps1` y `.cmd`: Arnés de pruebas unitarias.

### Modificaciones en el Ecosistema
1. `scripts/GUI/romanOS-ControlCenter.ps1`: Tarjeta interactiva de Sandbox en Seguridad & Navegadores.
2. `scripts/Modules/romanOS-Toolkit.ps1`: Opción interactiva 21 y soporte CLI `-Module Sandbox`.
3. `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`: Inyección física en $OEM$ y WIM offline.
4. `scripts/Testing/Invoke-TestSuite.ps1`: Integración de la Fase 12 permanente.
5. `README.md`, `docs/GUIA_DE_EJECUCION_Y_COMANDOS.md` y `MEMORY.md`: Documentación técnica integral.

---

## 4. Criterios de Aceptación y Validación

- [x] Sintaxis y codificación UTF-8 con BOM en todos los `.ps1` y ANSI No-BOM en `.cmd`.
- [x] Ejecución en frío verificada en Windows PowerShell 5.1 (`powershell.exe -STA -NoProfile`).
- [x] Generación de esquemas XML `.wsb` sintácticamente válidos validados contra `System.Xml.XmlDocument`.
- [x] Detección resiliente (CWE-390 / Fail-Visible) ante ediciones de Windows que no admiten Sandbox (ej. Windows Home) informando con claridad y ofreciendo alternativas.
- [x] 100% de aserciones aprobadas en `Test-LiveSandbox.ps1` (13/13 PASS en 4.25s).
- [x] 12/12 fases aprobadas en `Invoke-TestSuite.ps1` (67.3s, 0 errores, 0 advertencias).
