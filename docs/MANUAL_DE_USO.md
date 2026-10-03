# 📖 Manual de Uso Oficial: romanOS Toolkit & ISO Optimizada v2

Guía integral de uso y referencia técnica para la creación de imágenes ISO desatendidas de Windows 11 y la suite de herramientas **romanOS Toolkit Maestro** (Optimización Extrema para Gaming/Streaming, Mantenimiento, Red y Seguridad Desacoplada).

---

## 🎯 1. Filosofía y Principio Rector de Diseño

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                    NÚCLEO DEL SISTEMA: MÁXIMO RENDIMIENTO & 0 BLOAT                     │
│               Windows 11 Limpio, Ultra-Optimizado (Perfiles 2 y 3 Gaming/Stream)        │
│          • Cero servicios residentes pesados   • Máximos FPS y Frametimes estables      │
│          • Latencia DPC y TCP ultra-bajas      • Memoria RAM y CPU liberadas al 100%    │
└────────────────────────────────────────────┬────────────────────────────────────────────┘
                                             │
                       Invocación bajo demanda (On-Demand)
                                             │
┌────────────────────────────────────────────▼────────────────────────────────────────────┐
│                    CAJA DE HERRAMIENTAS DESACOPLADA (ZERO-FOOTPRINT)                    │
│                                                                                         │
│  [1] Hub Maestro Orquestador: romanOS-Toolkit.cmd / .ps1                                │
│  [2] Optimización Gaming & Debloat: Win11-Debloat-v3-Adaptive.cmd / .ps1                │
│  [3] Diagnóstico de Red & Latencia: Win11-Network-Diagnostics-Optimizer.cmd / .ps1     │
│  [4] Mantenimiento y Reparación: Invoke-WindowsMaintenance.cmd / .ps1                   │
│  [5] Auditoría Forense de Despliegue: Auditar-Instalacion.cmd / PostInstall-Diagnostics │
│  [6] Auditoría de Seguridad & Hardening: Invoke-WindowsSecurityHardening.cmd / .ps1     │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

* **Prioridad #1: Rendimiento Extremo:** El sistema no incluye tareas programadas residentes ni servicios demonio en segundo plano que compitan por ciclos de CPU o generen micro-stuttering en juegos.
* **Seguridad Inteligente Desacoplada (*Out-of-Band*):** La auditoría de seguridad y escaneo de vulnerabilidades se ejecuta **bajo demanda y en modo de solo lectura** cuando el usuario lo decide, sin penalizar el framerate.
* **Escritorio 100% Limpio:** Tras la instalación, todas las herramientas se alojan en el Menú Inicio oficial (`Start Menu\Programs\Herramientas del Sistema\`).

---

## 💿 2. Generación de la ISO Optimizada (`New-OptimizedWindowsISO-v2.ps1`)

El script [`scripts/New-OptimizedWindowsISO-v2.ps1`](file:///c:/OptimizedISO/scripts/New-OptimizedWindowsISO-v2.ps1) automatiza todo el proceso de descarga, inyección desatendida (`autounattend.xml`), integración de drivers/runtimes y compilación de la imagen ISO final.

### 🚀 Modo Rápido Asistido (Asistente Interactivo)
Abre PowerShell como Administrador y ejecuta:

```powershell
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1
```

El asistente te guiará en 6 sencillos pasos:
1. **Origen de la ISO:** Seleccionar una ISO local en tu disco o descargar automáticamente la versión oficial más reciente (Windows 11 25H2 / 24H2 / LTSC).
2. **Selección de Scripts Post-Instalación:** Elegir `[1] Suite Completa romanOS [Recomendado]`.
3. **Perfil de Optimización:**
   * **Perfil 1 (Gaming & Rendimiento - Recomendado):** Sin bloatware ni telemetría. Bypass BitLocker (BypassIO NVMe para DirectStorage), MMCSS tuning, HAGS, optimización de navegadores y bloqueo WPBT de BIOS. Preserva 100% de compatibilidad con Laptops, Wi-Fi, Bluetooth, impresoras y anti-cheats (Vanguard, EAC, BattlEye, FACEIT).
   * **Perfil 2 (Hardcore E-Sports / Latencia Mínima):** Todo lo del Perfil 1 + operación en Ring 0 puro (hipervisor/VBS desactivado con `hypervisorlaunchtype off`) y desactiva servicios secundarios (`WSearch`, `Spooler`, `SysMain`, `WlanSvc`, `bthserv`, sensores) para latencia DPC ultrabaja en torres LAN.

4. **Idioma, Región y Teclado:** Configuración de locale (ej. `es-AR`, `es-ES`, `en-US`).
5. **Cuenta de Usuario Local:** Creación de usuario local con o sin contraseña (omitiendo la cuenta Microsoft).
6. **Compilación Supervisada:** Proceso protegido contra bloqueos con watchdog automático, heartbeat en tiempo real y desmontaje WIM seguro.

---

## 🖥️ 3. Experiencia Post-Instalación (Dónde están las Herramientas)

Una vez completada la instalación desatendida de Windows:
1. **Escritorio Limpio:** Encontrarás el informe inicial de instalación (`INFORME_INSTALACION.md` e `INFORME_INSTALACION.html`).
2. **Menú Inicio Oficial:** Al presionar la tecla **Windows** o abrir el Menú Inicio en **Todas las Aplicaciones**, tendrás la carpeta **Herramientas del Sistema**:
   * 🎛️ **`romanOS Toolkit Maestro`:** Panel de control unificado.
   * ⚡ **`Optimizar Sistema (Opcional)`:** Optimizador adaptativo de hardware y debloat.
   * 🧹 **`Mantenimiento del Sistema`:** Limpieza profunda WinSxS, temporales y reparación.
   * 🌐 **`Optimizar Red y Latencia (Opcional)`:** Benchmarks y tuning de red.
   * 🛡️ **`Auditoria de Seguridad (On-Demand)`:** Escaneo de postura de seguridad y hardening.
   * 🔍 **`Auditar Instalacion`:** Re-auditoría forense de la instalación bajo demanda.
3. **Búsqueda Instantánea:** Puedes escribir en la barra de tareas cualquiera de estos nombres para lanzarlos directamente.

---

## 🎛️ 4. Uso del Hub Maestro (`Lanzar-romanOS-Toolkit.cmd` / `.ps1`)

El Hub Maestro [Lanzar-romanOS-Toolkit.cmd](file:///c:/OptimizedISO/Lanzar-romanOS-Toolkit.cmd) (o [scripts/Modules/romanOS-Toolkit.cmd](file:///c:/OptimizedISO/scripts/Modules/romanOS-Toolkit.cmd)) permite gestionar todo el equipo desde un solo menú centralizado con cero procesos residentes en segundo plano (*Zero-Resident Footprint*).

### 🖱️ Cómo Abrirlo
* Haz doble clic en **`Lanzar-romanOS-Toolkit.cmd`** en la raíz del repositorio,
* O haz doble clic en el acceso directo del Menú Inicio **`romanOS Toolkit Maestro`** (en el sistema instalado), o
* Ejecuta desde consola:
  ```powershell
  .\Lanzar-romanOS-Toolkit.cmd
  ```

### 📋 Menú Principal del Hub
```text
  [1]  ⚡ Optimización Gaming & Hardware (HAGS, MSI Mode, Latencia, Debloat)
  [2]  🌐 Diagnóstico de Red & Latencia (Benchmarks DNS, TCP/IP, Sockets)
  [3]  🧹 Mantenimiento & Limpieza Profunda (WinSxS DISM, Shaders, SSD TRIM)
  [4]  📋 Auditoría Forense Post-Instalación & Salud (Panther, CompactOS, PnP)
  [5]  🔍 Auditoría Forense de Huella en Reposo (Procesos en Segundo Plano, RAM y Directivas)
  [6]  🛡️ Auditoría de Seguridad & Hardening (ASR, VBS, Protocolos On-Demand)
  [7]  🌐 Optimizar y Debloat de Navegadores (GPU, Menos RAM, Sin Copilot/IA)
  [8]  📦 Descargar Windows Updates Oficiales (MSU/CAB para Slipstream en ISO)
  [9]  💻 Gestión Integral de Controladores (Respaldo Host, DriverStore, Intel VMD)
  [10] 👤 Migrar o Rescatar Perfil de Usuario Local (Respaldos y Recreacion)
  [11] 📊 Generar y Abrir Dashboards HTML de Salud y Seguridad
  [12] 🧠 Poda Quirurgica de Memoria RAM en Reposo (SearchHost, WebView2, Shell)
  [13] 🎯 Auditor Universal de Optimizacion (Multi-Hardware, Latencia, Scoring y Remediacion)
  [14] 🎮 Conmutador Modo Juego / Modo Dev (Liberar RAM para APU y Cortar Devoradores)
  [15] ⚡ Acciones Rapidas Express (Flush DNS, Restart Explorer, GodMode, SFC)
  [16] 🖥️ Abrir romanOS Control Center (Interfaz Grafica Moderna WPF & Telemetria)
  [0]  ❌ Salir del Toolkit
```

---

## 🖥️ 4.1. romanOS Control Center: Interfaz Gráfica Nativa (WPF / XAML)

**romanOS Control Center** (`scripts/GUI/romanOS-ControlCenter.ps1`) proporciona una experiencia visual rica y moderna basada en Windows Presentation Foundation (WPF XAML) con estética Dark Mode (`#202020` / `#0A84FF`), diseñada para operar con **cero procesos residentes** (*Zero-Resident Footprint*).

### 🚀 Formas de Lanzamiento
1. **Lanzador Win32 JIT Directo (Raíz):** Haz doble clic en `Lanzar-romanOS-ControlCenter.cmd` en la raíz. Si el ejecutable no existe, se compila silenciosamente con `csc.exe` (`/target:winexe`), eliminando el parpadeo negro de consola.
2. **Desde el Toolkit Maestro:**
   ```powershell
   # Vía parámetro CLI
   .\scripts\Modules\romanOS-Toolkit.ps1 -GUI
   
   # O seleccionando la opción [16] en el menú interactivo
   ```
3. **Desde el Menú Inicio:** Acceso directo `romanOS Control Center` en el sistema instalado por la ISO.

### 📑 Pestañas y Capacidades Modulares
* **⚡ 1. Gaming & Hardware:** Conmutador rápido Game vs. Dev (Light / Aggressive / Dev), auditoría de Hardware-Engine (GPU, CPU, RAM, SMBIOS), estado de HAGS y modo MSI PCIe.
* **🧠 2. RAM & Procesos:** Indicadores de telemetría de memoria física en tiempo real (RAM total, usada, libre y porcentaje con barra de progreso reactiva), poda quirúrgica instantánea de procesos devoradores (`psapi.dll EmptyWorkingSet`) y top de procesos consumidores.
* **🧹 3. Mantenimiento & DISM:** Reparación rápida de imagen (`DISM /Online /Cleanup-Image /RestoreHealth` + `sfc /scannow`), purga profunda de WinSxS (`StartComponentCleanup /ResetBase`), limpieza de cachés de Shaders GPU (DirectX, NVIDIA, AMD) y ejecución de SSD TRIM.
* **🌐 4. Red & Latencia:** Benchmark en tiempo real de latencia de resolución DNS (Cloudflare, Google, Quad9, OpenDNS), conmutación de servidores DNS en 1 clic y vaciado instantáneo de caché DNS (`ipconfig /flushdns`).
* **🛡️ 5. Seguridad & Navegadores:** Optimización y debloat oficial de navegadores (Edge, Chrome, Brave, Firefox sin IA ni telemetría), auditoría de seguridad y hardening gaming-safe, y acceso directo a Dashboards HTML de instalación y seguridad.
* **💻 6. Drivers & Utilidades:** Respaldo completo de controladores activos del Host (`Export-WindowsDriver`), limpieza y depuración del DriverStore (`FileRepository`) y asistente de migración de perfiles de usuario.
* **📺 Consola de Telemetría Asíncrona:** Visor de terminal integrado a 60 FPS con streaming de salida en vivo (`ConcurrentQueue` + `RunspaceFactory`), botón de cancelación forzada segura (`taskkill /F /T`) y barra de estado reactiva.

---

## 🛠️ 5. Detalle de los Módulos Individuales

### ⚡ Módulo 1: Optimización Gaming & Debloat (`Win11-Debloat-v3-Adaptive.ps1`)
* **Propósito:** Desinstalar bloatware AppX residual, aplicar directivas de alto rendimiento en GPU/CPU y configurar políticas de navegador.
* **Directivas de Navegadores (Edge, Chrome, Brave, Firefox):**
  * Aceleración por hardware GPU activada.
  * *Sleeping Tabs* y *Memory Saver* activados (ahorro de hasta 50% de RAM en pestañas inactivas).
  * *Startup Boost* y procesos en segundo plano desactivados (0 procesos residuales al cerrar).
  * Caché de disco limitada a 256 MB.
* **Menú Contextual NATIVO:** Integra opciones de Clic Derecho (PowerShell Admin, Reiniciar Explorer, Vaciar DNS, God Mode, Abrir con Notepad, Reparar Sistema).

---

### 🌐 Módulo 2: Diagnóstico y Optimización de Red (`Win11-Network-Diagnostics-Optimizer.ps1`)
* **Propósito:** Medición de latencia de red en tiempo real y ajuste fino de la pila TCP/IP.
* **Funciones:**
  * **Benchmark DNS en Vivo:** Compara latencias contra Cloudflare (1.1.1.1), Google (8.8.8.8), Quad9 (9.9.9.9) y OpenDNS.
  * **Ajuste TCP/IP:** Habilita *CTCP* / *BBR*, desactiva algoritmos de espera innecesarios (*Nagle* en juegos compatibles) y mitiga jitter.
  * **Reparación de Sockets:** Restablecimiento automático de catálogo Winsock y vaciado de caché DNS.

---

### 🧹 Módulo 3: Mantenimiento y Recuperación (`Invoke-WindowsMaintenance.ps1`)
* **Propósito:** Saneamiento profundo periódico del sistema operativo sin borrar datos personales.
* **Capacidades:**
  * **Limpieza WinSxS con DISM:** Ejecuta `/StartComponentCleanup /ResetBase` para recuperar gigabytes de actualizaciones antiguas.
  * **Purga de Shaders GPU:** Limpia cachés de shaders DirectX (`D3DSCache`), NVIDIA (`DXCache`) y AMD (`DxCache`) para resolver tirones de frametime.
  * **Saneamiento de Temporales & Descargas de Windows Update:** Purga segura de `SoftwareDistribution\Download` y `%TEMP%`.
  * **SSD TRIM:** Ejecuta optimización `Optimize-Volume -ReTrim` en todas las unidades de estado sólido.
  * **Reparación Oficial:** Ejecuta DISM `/RestoreHealth`, SFC `/scannow` y reparación de consistencia WMI/NTFS.

---

### 📋 Módulo 4: Auditoría Forense Post-Instalación (`PostInstall-Diagnostics.ps1`)
* **Propósito:** Verificar que Windows se instaló correctamente y que ninguna política o driver falló durante el despliegue.
* **Audita:**
  * Logs de Windows Setup (`Panther\setuperr.log` y `UnattendGC\setuperr.log`).
  * Estado de ejecución de `SetupComplete.cmd` y Runtimes de Visual C++.
  * Huella de almacenamiento y estado de compresión **CompactOS**.
  * Dispositivos PnP con errores o falta de controlador.
* **Reportes Generados:**
  * `INFORME_INSTALACION.md` (Markdown en el Escritorio).
  * `INFORME_INSTALACION.html` (**Dashboard Visual Offline** con métricas interactivas).

---

### 🛡️ Módulo 5: Auditoría de Seguridad & Hardening Desacoplado (`Invoke-WindowsSecurityHardening.ps1`)
* **Propósito:** Inspeccionar la postura de seguridad del equipo bajo demanda sin degradar el rendimiento diario.
* **Audita:**
  * **Reglas ASR (Attack Surface Reduction):** 13 reglas de Microsoft Defender (bloqueo de robo de credenciales LSASS, scripts ofuscados, inyección de procesos).
  * **Kernel & Firmware:** Secure Boot, TPM 2.0, Virtualization-Based Security (VBS/HVCI), Bloqueo de binarios OEM WPBT.
  * **Protocolos Inseguros:** Estado de SMBv1 (vector WannaCry), LLMNR (envenenamiento de red local) y NetBIOS.
  * **Credenciales:** Protección LSA (`RunAsPPL`), NTLMv2 forzado, UAC y restricción de cuentas sin contraseña.
* **Reportes Generados:**
  * `INFORME_SEGURIDAD.md` (Puntuación de seguridad sobre 100 y recomendaciones).
  * `INFORME_SEGURIDAD.html` (**Dashboard Visual Offline** con badges de estado e impacto en gaming).

---

## 📊 6. Visualización de Dashboards HTML Offline

Ambos módulos de diagnóstico generan interfaces visuales estilizadas en modo oscuro diseñadas para funcionar **100% sin conexión a internet** (cero dependencias externas):

```powershell
# Abrir directamente el Dashboard de Salud de Instalación
Start-Process "C:\Users\Public\Desktop\INFORME_INSTALACION.html"

# Abrir directamente el Dashboard de Seguridad
Start-Process "C:\Users\Public\Desktop\INFORME_SEGURIDAD.html"
```

O desde el menú interactivo del Toolkit Maestro seleccionando la opción **`[6] Generar y Abrir Dashboards HTML`**.

---

## 🧪 7. Pruebas Automatizadas y Entorno de Desarrollo

### 🤖 Pruebas en Hyper-V (`New-TestVM-HyperV.ps1`)
Para probar una ISO recién compilada en una Máquina Virtual Gen2 (UEFI + TPM 2.0 + SecureBoot) con un solo clic:

```powershell
.\scripts\New-TestVM-HyperV.ps1
```
* Detecta automáticamente la ISO más reciente generada en el proyecto.
* Crea la VM en Hyper-V con 4 vCPUs, 4GB RAM y TPM virtual activado.
* Abre la consola de conexión (`vmconnect.exe`) antes del arranque para sincronización inmediata.

### 🧪 Test Harness Unitario (`Test-OptimizedISO-v2.ps1`)
Para verificar la integridad sintáctica, funciones aisladas y compatibilidad de todo el proyecto:

```powershell
.\scripts\Test-OptimizedISO-v2.ps1
```
* Ejecuta **136 pruebas automatizadas** en el runtime de destino (**Windows PowerShell 5.1**).
* Verifica la codificación `UTF-8-BOM` en todos los scripts.
* Genera un reporte formal en `Log/TestHarness_*.md`.
