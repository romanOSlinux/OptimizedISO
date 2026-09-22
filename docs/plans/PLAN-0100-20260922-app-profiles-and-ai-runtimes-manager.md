# PLAN-0100: romanOS App & AI Runtimes Manager

**Fecha:** 2026-09-22  
**Estado:** COMPLETADO  
**Autor:** Antigravity / romanOS Software Engineering  
**Alcance:** Ecosistema Completo (Core, Modules, GUI Control Center, Toolkit Maestro, ISO Builder, $OEM$, Testing Harness)

---

## 1. Contexto y Justificación Técnica

Tras completar la instalación de un sistema operativo optimizado como Windows 11 24H2 / 25H2 mediante romanOS / OptimizedISO, el usuario se encuentra con un entorno depurado de latencia cero, pero requiere configurar sus herramientas de trabajo, juegos y aceleradores de hardware.

Actualmente, el repositorio cuenta con `Get-EssentialRuntimes.ps1` (limitado a Visual C++ y DirectX 9.0c heredado), pero **carece de un gestor modular post-instalación de aplicaciones y librerías modernas de IA local por hardware (DirectML, ONNX, Agility SDK)**.

### Retos y Oportunidades
1. **Despliegue Desatendido Confiable:** Windows 11 integra nativamente `winget.exe` (Windows Package Manager). Utilizar un catálogo curado y versionado en JSON previene la descarga manual propensa a adware o instaladores con bloatware.
2. **Revolución AI PC (2026):** Procesadores modernos (como AMD Ryzen 8000/9000 con NPU XDNA, Intel Core Ultra con Intel AI Boost, o GPUs RTX con Tensor Cores) requieren librerías específicas (DirectML, ONNX Runtime Execution Providers) para ejecutar modelos locales (Ollama, Whisper, Stable Diffusion) sin saturar la CPU ni depender de la nube.
3. **Perfiles de 1-Clic Especializados:** Los usuarios tienen flujos de trabajo divergentes (Esports Gamer vs. Creador/Streamer vs. Desarrollador de Software & IA). Un gestor por perfiles permite instalar exactamente lo necesario en minutos de forma desatendida.

---

## 2. Arquitectura de romanOS App & AI Runtimes Manager

```
                            ┌────────────────────────────────────────┐
                            │      romanOS App & AI Manager          │
                            │        (Deploy-AppProfiles)            │
                            └──────────────────┬─────────────────────┘
                                               │
                                 ┌─────────────┴─────────────┐
                                 ▼                           ▼
                   [Hardware-Engine.ps1]       [App-Profiles-Catalog.json]
                   • Detección NPU / iGPU      • IDs canónicos de Winget
                   • Detección AMD/Intel/NV    • Hashes SHA-256 de Runtimes
                                 │                           │
         ┌───────────────────────┴───────────────────────────┴───────────────────────┐
         ▼                                   ▼                                       ▼
  [Perfil 1: Esports Gamer]       [Perfil 2: Creador & Streamer]          [Perfil 3: AI & Developer]
  • Steam / Discord               • OBS Studio (AV1/NVENC/AMF)            • Ollama (LLMs Locales)
  • 7-Zip / MSI Afterburner       • HandBrake / VLC                       • Git / VS Code / Python 3.12
  • Vulkan & Agility SDK          • DaVinci Resolve Runtime Deps          • DirectML / ONNX Runtimes
```

### Componentes Clave:
1. **Catálogo Canónico SSOT:**
   `scripts/Core/App-Profiles-Catalog.json`
   Define las aplicaciones, fuentes oficiales, IDs de winget, argumentos silenciosos y dependencias de hardware.
2. **Script Orquestador:**
   `scripts/Modules/Deploy-AppProfiles.ps1` y su lanzador `Deploy-AppProfiles.cmd`
   - Parámetros CLI:
     - `-Profile [Gaming|Creator|AI|Essential|Custom]`
     - `-InstallRuntimesOnly`
     - `-AutoDetectHardware` (adapta paquetes según GPU/NPU detectados por `Hardware-Engine.ps1`)
     - `-Unattended`
     - `-WhatIf`
3. **Integración con romanOS Control Center (WPF XAML):**
   - Nueva tarjeta en la pestaña "Drivers & Herramientas" para selección visual de perfil y barra de progreso.
4. **Integración con romanOS Toolkit Maestro:**
   - Opción en el menú principal y parámetro CLI `-Module AppProfiles`.
5. **Inyección en Despliegue e ISO:**
   - Inyección en `$OEM$\$$\Setup\Scripts\Modules` y WIM offline para acceso directo post-instalación.

---

## 3. Plan de Archivos y Modificaciones

### Nuevos Archivos
1. `scripts/Core/App-Profiles-Catalog.json`: Catálogo maestro de perfiles, IDs y librerías.
2. `scripts/Modules/Deploy-AppProfiles.ps1`: Motor de instalación y aprovisionamiento.
3. `scripts/Modules/Deploy-AppProfiles.cmd`: Lanzador ergonómico Win32 (No-BOM, UAC, STA).
4. `scripts/Testing/Test-AppProfilesManager.ps1` y `Test-AppProfilesManager.cmd`: Arnés de pruebas unitarias.

### Modificaciones en el Ecosistema
1. `scripts/GUI/romanOS-ControlCenter.ps1`: Interfaz visual en Drivers & Herramientas.
2. `scripts/Modules/romanOS-Toolkit.ps1`: Opción interactiva y soporte CLI.
3. `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`: Inyección en $OEM$ y WIM offline.
4. `scripts/Testing/Invoke-TestSuite.ps1`: Integración de la Fase 10 de certificación.
5. `README.md` y guías de usuario: Documentación técnica completa.

---

## 4. Criterios de Aceptación y Validación

- [x] Sintaxis y codificación UTF-8 con BOM en todos los `.ps1` y ANSI No-BOM en `.cmd`.
- [x] Ejecución en frío verificada en Windows PowerShell 5.1 (`powershell.exe -STA -NoProfile`).
- [x] Detección y fallback seguro en caso de que `winget.exe` requiera inicialización de fuentes.
- [x] Cero fallos silenciosos (CWE-390): Telemetría visible ante errores de descarga o red.
- [x] 100% de aserciones aprobadas en `Test-AppProfilesManager.ps1` (13/13 PASS).
- [x] 10/10 fases aprobadas en `Invoke-TestSuite.ps1` (0 errores, 0 advertencias).
