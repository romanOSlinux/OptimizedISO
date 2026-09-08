# PLAN-0063: Compilación de ISO romanOS Personalizada a Medida del Host (AMD Ryzen 5 8600G / Radeon 760M / NPU XDNA / DDR5)

- **ID del Plan:** PLAN-0063
- **Fecha:** 2026-09-08
- **Estado:** PENDIENTE
- **Autor:** romanOS Engineering / Antigravity Agent
- **Rama:** `feature/offline-ui-tweaks`

---

## 1. Contexto y Justificación Técnica

El usuario ha solicitado compilar una imagen ISO de Windows 11 preparada específicamente para la máquina física en la que se está ejecutando el proyecto en este momento.

Tras ejecutar la introspección con el motor oficial `Hardware-Engine.ps1`, se ha identificado el perfil exacto del host:
- **Plataforma:** PC de Escritorio (Desktop) / Socket AM5.
- **Procesador (CPU):** AMD Ryzen 5 8600G (6 Cores / 12 Threads @ 4.35 GHz base, arquitectura Zen 4 con AVX-512).
- **Acelerador de IA (NPU):** AMD XDNA Neural Processing Unit (Certificado AI PC, 16 TOPS).
- **GPU / iGPU:** AMD Radeon 760M (RDNA3, 8 CUs, compatible con WDDM 3.1+, HAGS y Modo MSI).
- **Memoria RAM:** 16 GB DDR5 @ 5200 MHz en Dual-Channel (2 módulos de alta velocidad).
- **Almacenamiento:** NVMe SSD de alta velocidad con soporte UEFI GPT y DirectStorage.
- **Controladores Activos:** 45 paquetes de controladores OEM de terceros (`oem*.inf`) instalados y validados en el sistema operativo actual (Chipset AMD AM5, GPU Radeon 760M, NPU XDNA, Realtek/AMD Audio, Ethernet y Wi-Fi).
- **Imagen Base:** `C:\OptimizedISO\Win11_25H2_Spanish_x64_v2.iso` presente y lista en el entorno de desarrollo.

### Objetivos de Ingeniería para una ISO "A Medida" (Tailored ISO)
1. **Experiencia Plug & Play Absoluta:**
   - La ISO no debe requerir descargas posteriores de controladores ni dejar dispositivos con signos de interrogación o exclamación en el Administrador de Dispositivos.
   - Inyección dual de los 45 drivers OEM: tanto en `boot.wim` (soporte de NVMe, ratón y red durante la instalación) como en `install.wim` (arranque del sistema final con GPU, Wi-Fi y NPU activos).
2. **Optimización de Arquitectura Zen 4 + RDNA3:**
   - Configuración de planificador de energía adaptado a núcleos homogéneos Zen 4 de alta frecuencia.
   - Activación nativa de **HAGS** (*Hardware Accelerated GPU Scheduling*) en registro para la iGPU RDNA3.
   - Configuración de **Modo MSI** (*Message Signaled Interrupts*) para la GPU y el bus NVMe.
   - Preservación explícita del runtime y driver de la NPU AMD XDNA (evitar neutralización accidental en el debloat).
3. **Persistencia de Directivas de Estabilidad y Windows Update:**
   - Integración de las 9 directivas canónicas de Windows Update acordadas (Modo Bajo Demanda `NoAutoUpdate=1`, Cuarentena de 7 días `DeferQualityUpdatesPeriodInDays=7`, bloqueo de previews `AllowOptionalContent=0`, exclusión de drivers `ExcludeWUDriversInQualityUpdate=1` para proteger Adrenalin).
4. **Preset Automatizado de Usuario y Región (Perfil 3 - Hardcore):**
   - **Perfil de Optimización Seleccionado:** **Perfil 3 (Hardcore)** — Máxima reducción de huella en reposo, latencias mínimas de audio/renderizado, desactivación exhaustiva de telemetría y servicios en segundo plano prescindibles, manteniendo la estabilidad del hardware.
   - Despliegue desatendido personalizado: Idioma `es-ES`, Región `es-AR`, Teclado `es-419`, Zona horaria `Argentina Standard Time`, Usuario local `Roman` con auto-logon sin contraseña.

---

## 2. Objetivos del Plan

1. **Fase 1: Respaldo y Extracción de Controladores del Host:**
   - Ejecutar la exportación de los controladores OEM activos hacia `scripts/Drivers/Host_Backup/` utilizando `pnputil.exe` / `Export-WindowsDriver`.
2. **Fase 2: Creación del Preset JSON Especializado (`Preset_Host_Ryzen8600G.json`):**
   - Generar el archivo de preset fijando `OptimizationProfile = "3"` (Hardcore), parámetros de hardware, drivers locales (`scripts\Drivers\Host_Backup`), e idioma.
3. **Fase 3: Calibración y Gobernanza SSOT:**
   - Verificar en `Policy-Engine.ps1` y `Hardware-Engine.ps1` que las directivas específicas de RDNA3, NPU y Ryzen 8600G sean inyectadas en la fase `specialize` y en el WIM montado.
4. **Fase 4: Compilación de la ISO:**
   - Invocación de `New-OptimizedWindowsISO-v2.ps1` utilizando el preset generado y la ISO fuente `Win11_25H2_Spanish_x64_v2.iso`.
5. **Fase 5: Validación y Certificación:**
   - Verificación de hash, arranque El Torito EFI/BIOS y estructura WIM resultante.

---

## 3. Matriz de Componentes y Acciones

| Archivo / Componente | Acción | Descripción |
| :--- | :---: | :--- |
| `scripts/Drivers/Host_Backup/` | NUEVO | Carpeta que albergará los 45 paquetes de drivers OEM exportados del host. |
| `Preset_Host_Ryzen8600G.json` | NUEVO | Preset JSON de configuración específico para este PC. |
| `Lanzar-Builder-Con-Preset.cmd` | UTILIZAR | Lanzador interactivo/desatendido oficial del Builder con el nuevo preset. |
| `docs/plans/PLAN-0063-20260908-iso-a-medida-host-amd-ryzen-8600g.md` | NUEVO | Documento oficial del plan de implementación. |
| `docs/plans/README.md` | MODIFICAR | Registro de PLAN-0063 en el índice oficial de planes. |

---

## 4. Plan de Verificación

1. **Inspección de Drivers Extraídos:**
   - Comprobar que los drivers de AMD Chipset, Radeon 760M, NPU XDNA, Audio y Red están presentes con sus archivos `.inf`, `.cat` y `.sys`.
2. **Validación Sintáctica del Preset JSON:**
   - Validar con `ConvertFrom-Json` en Windows PowerShell 5.1.
3. **Auditoría de Inyección en WIM:**
   - Verificar con `DISM /Get-Drivers` que la imagen final contiene los controladores inyectados.
