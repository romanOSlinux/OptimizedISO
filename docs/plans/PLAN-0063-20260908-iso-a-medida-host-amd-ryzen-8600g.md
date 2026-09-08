# PLAN-0063: Compilación de ISO romanOS a Medida del Host (AMD Ryzen 5 8600G) con Suite Modular de Despliegue Post-Instalación (Dev-IA & Gaming)

- **ID del Plan:** PLAN-0063
- **Fecha:** 2026-09-08
- **Estado:** EN PROGRESO
- **Autor:** romanOS Engineering / Antigravity Agent
- **Rama:** `feature/offline-ui-tweaks`

---

## 1. Contexto y Justificación Técnica

El usuario ha solicitado compilar una imagen ISO de Windows 11 personalizada específicamente para la máquina física de desarrollo actual, transformándola en una estación de trabajo de alto rendimiento "llave en mano" con capacidades duales:
1. **Desarrollo con Inteligencia Artificial & Virtualización:** Ecosistema completo para Antigravity IDE, Git, hipervisor Hyper-V/WSL2 y aceleración de IA local mediante la NPU AMD XDNA.
2. **Gaming de Alta Fidelidad:** Plataformas de juego (Steam, Wargaming Game Center / World of Tanks), runtimes gráficos preinstalados, optimizaciones de latencia de red y garantía de compatibilidad estricta con sistemas anti-cheat.

### Perfil de Hardware Auditado (Introspección en Vivo)
- **Plataforma:** PC de Escritorio (Desktop) / Socket AM5.
- **Procesador (CPU):** AMD Ryzen 5 8600G (6 Cores / 12 Threads @ 4.35 GHz base, Zen 4 con AVX-512).
- **Acelerador de IA (NPU):** AMD XDNA Neural Processing Unit (Certificado AI PC, 16 TOPS).
- **GPU / iGPU:** AMD Radeon 760M (RDNA3, 8 CUs, compatible con WDDM 3.1+, HAGS y Modo MSI).
- **Memoria RAM:** 16 GB DDR5 @ 5200 MHz en Dual-Channel (2 módulos de alta velocidad).
- **Almacenamiento:** NVMe SSD de alta velocidad con soporte UEFI GPT y DirectStorage.
- **Controladores Activos:** 45 paquetes de controladores OEM de terceros (`oem*.inf`) validados y operativos en el sistema en vivo.
- **Imagen Base:** `C:\OptimizedISO\Win11_25H2_Spanish_x64_v2.iso` presente y lista en el entorno de desarrollo.

---

## 2. Arquitectura de Despliegue en 2 Capas

Basado en la investigación profunda de estándares oficiales (*Microsoft Learn - Windows Deployment Lifecycle* y *AMD Ryzen AI Architecture*), el despliegue se desacopla en dos capas para evitar que la ISO pese 25 GB y garantizar que el software se instale siempre en sus versiones más recientes y estables:

### Capa 1: Integración Offline en la ISO / WIM (Cero Descargas, Cero Reinicios)
1. **Inyección Dual de Drivers OEM:**
   - 45 paquetes de controladores inyectados tanto en `boot.wim` (instalador) como en `install.wim` (sistema final).
2. **Virtualización Nativa Pre-activada:**
   - Habilitación offline con DISM de las características de hipervisor:
     - `Microsoft-Hyper-V-All` (Hipervisor Hyper-V para máquinas virtuales).
     - `VirtualMachinePlatform` y `Microsoft-Windows-Subsystem-Linux` (WSL2).
   - *Resultado:* Windows arranca con el hipervisor activo en la CPU Zen 4 sin requerir reinicios posteriores ni descargas de Windows Update.
3. **Optimizaciones de Hardware y Kernel (SSOT Policy-Engine / Hardware-Engine):**
   - **HAGS:** *Hardware Accelerated GPU Scheduling* forzado en registro para la GPU RDNA3.
   - **Modo MSI:** Prioridad alta de interrupciones señalizadas por mensaje para GPU y bus NVMe.
   - **Optimización de Red para Gaming (World of Tanks):** Desactivación del retardo de Nagle (`TcpAckFrequency = 1`, `TCPNoDelay = 1`) y calibración de búferes NDIS para eliminar *jitter* y pings inestables.
   - **Gaming-Safe Debloat:** Preservación de servicios criptográficos (`CryptSvc`), almacén de certificados y aislamiento de memoria del kernel para compatibilidad total con Easy Anti-Cheat, BattlEye y módulos de integridad de Wargaming.
   - **Protección de Drivers en Windows Update:** 9 directivas canónicas activas (bloqueo de previews, cuarentena de 7 días y exclusión de drivers para que WU no pise el controlador AMD Adrenalin).
4. **Despliegue Desatendido (OOBE):**
   - Usuario local `Roman` sin contraseña (passwordless / autologon).
   - Localización: `es-ES`, Región `es-AR`, Teclado `es-419`, Zona horaria `Argentina Standard Time`.

### Capa 2: Suite Modular Post-Instalación (A Demanda / Primer Inicio)
En el Escritorio del usuario `Roman` se inyecta un acceso directo:
**`Desplegar-Setup-Host.cmd`** (que invoca a `Desplegar-Setup-Host.ps1` en modo gráfico `-STA` y con elevación UAC).

Al ejecutarse, presenta un **menú interactivo seleccionable**:
```text
======================================================================
   romanOS Workstation Setup — Edición AMD Ryzen 5 8600G
======================================================================

  [1] Despliegue Completo (Dev + IA + Gaming)
      Instala todo el ecosistema de trabajo y entretenimiento.

  [2] Solo Entorno de Desarrollo con IA
      - Git for Windows (Git.Git) + PowerShell 7 (Microsoft.PowerShell)
      - Ecosistema, reglas y skills globales de Antigravity IDE
      - Stack AMD Ryzen AI (DirectML / ONNX Runtime para NPU XDNA)
      - 7-Zip (7zip.7zip)

  [3] Solo Entorno Gaming
      - Plataforma Steam (Valve.Steam)
      - Wargaming.net Game Center (Wargaming.GameCenter / World of Tanks)
      - Verificación de Runtimes DirectX / Visual C++
      - Calibración de latencia de red TCP NoDelay

  [4] Selección Personalizada (Elegir paquete por paquete)
      Permite marcar interactivamente qué aplicaciones instalar.

  [0] Salir (No realizar cambios por ahora)

======================================================================
Selecciona una opción [0-4]: 
```

#### Características del Menú:
- **100% Idempotente y Seguro:** Si el usuario elige hoy `[3] Gaming`, la máquina queda limpia para jugar. Si semanas después elige `[2] Dev`, se instala el ecosistema de programación sin tocar ni reinstalar los juegos.
- **Fuentes Oficiales:** Todas las instalaciones de software se realizan vía **WinGet** (`--accept-package-agreements --accept-source-agreements --silent`) en contexto de usuario interactivo.
- **Integración con Antigravity:** Reutiliza el script oficial del proyecto `scripts/Host-Tools/Setup-AntigravityWindows.ps1`.

---

## 3. Fases de Implementación

1. **Fase 1: Respaldo y Verificación de Drivers del Host:**
   - Validar que los 45 paquetes OEM activos en `scripts/Drivers/` (o exportados en `scripts/Drivers/Host_Backup/`) contengan sus archivos `.inf`, `.cat` y `.sys` correspondientes (Chipset AM5, Radeon 760M, NPU XDNA, Audio Realtek/AMD, Ethernet y Wi-Fi).
2. **Fase 2: Construcción de la Suite de Despliegue Post-Instalación:**
   - Crear el script maestro `scripts/Host-Tools/Desplegar-Setup-Host.ps1` con codificación UTF-8 con BOM y lógica modular.
   - Crear el lanzador batch `scripts/Host-Tools/Desplegar-Setup-Host.cmd` con auto-elevación UAC y soporte `-STA`.
   - Inyectar ambos archivos en la ruta OEM `$OEM$\$1\Users\Public\Desktop` o `$OEM$\$$\Setup\Scripts` para que aparezcan en el Escritorio del usuario final.
3. **Fase 3: Creación del Preset JSON y Lanzador de Compilación:**
   - Generar `Preset_Host_Ryzen8600G.json` con todos los parámetros fijados (`OptimizationProfile = "3"`, `LocalUser = "Roman"`, `LocalPassword = ""`, `DriversPath = "scripts\Drivers"`).
   - Crear el script lanzador de 1 clic `Compilar-ISO-Host-Ryzen8600G.cmd` en la raíz del proyecto.
4. **Fase 4: Configuración de Habilitación Offline de Hyper-V y SSOT:**
   - Asegurar que `New-OptimizedWindowsISO-v2.ps1` habilite offline las características `Microsoft-Hyper-V-All`, `VirtualMachinePlatform` y `Microsoft-Windows-Subsystem-Linux` cuando el preset del host lo solicite.
   - Verificar en `Policy-Engine.ps1` la calibración de latencia de red (`TCPNoDelay`) y compatibilidad anti-cheat en el Perfil 3.
5. **Fase 5: Compilación de la ISO:**
   - Ejecutar la compilación desatendida mediante el lanzador `Compilar-ISO-Host-Ryzen8600G.cmd`.
6. **Fase 6: Verificación y Certificación:**
   - Comprobación de integridad de la ISO final (`romanOS_Win11_25H2_x64_HostEdition_Ryzen8600G.iso`), firmas, drivers inyectados con `DISM /Get-Drivers` y prueba de arranque El Torito EFI/BIOS.

---

## 4. Matriz de Componentes y Acciones

| Archivo / Componente | Acción | Descripción |
| :--- | :---: | :--- |
| `scripts/Drivers/` | VALIDAR | Contenedor de los 45 paquetes de drivers OEM extraídos del host. |
| `scripts/Host-Tools/Desplegar-Setup-Host.ps1` | NUEVO | Script interactivo con menú para despliegue de Dev-IA y Gaming. |
| `scripts/Host-Tools/Desplegar-Setup-Host.cmd` | NUEVO | Lanzador con elevación UAC y modo `-STA` para el Escritorio. |
| `Preset_Host_Ryzen8600G.json` | NUEVO | Preset JSON de configuración específico para este equipo. |
| `Compilar-ISO-Host-Ryzen8600G.cmd` | NUEVO | Lanzador directo de 1 clic para compilar la ISO del host. |
| `docs/plans/PLAN-0063-20260908-iso-a-medida-host-amd-ryzen-8600g.md` | MODIFICAR | Documento oficial del plan de implementación actualizado. |
| `docs/plans/README.md` | MODIFICAR | Actualización del título del plan en el índice oficial. |

---

## 5. Plan de Verificación

1. **Auditoría de Codificación y Sintaxis PowerShell 5.1:**
   - Validar que `Desplegar-Setup-Host.ps1` esté en UTF-8 con BOM y ejecute sin errores de parseo con:
     `& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'scripts\Host-Tools\Desplegar-Setup-Host.ps1' -WhatIf }"`
2. **Validación Sintáctica del Preset JSON:**
   - Validar con `ConvertFrom-Json` que `Preset_Host_Ryzen8600G.json` sea un JSON válido y contenga todas las claves requeridas.
3. **Validación de Paquetes WinGet:**
   - Comprobar que los IDs `Git.Git`, `Valve.Steam`, `Wargaming.GameCenter`, `Microsoft.PowerShell` y `7zip.7zip` resuelvan en el catálogo de winget.
4. **Verificación de Inyección WIM:**
   - Confirmar que la ISO compile exitosamente y que DISM reporte los 45 drivers OEM inyectados y las características Hyper-V activadas.
