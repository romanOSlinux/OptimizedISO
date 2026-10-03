# Guía Maestra de Lanzamiento, Comandos y Trazabilidad — romanOS / OptimizedISO

Esta guía documenta exhaustivamente todas las formas de ejecución, parámetros de línea de comandos (CLI), lanzadores por lotes (`.cmd`), menús interactivos y recetas prácticas de toda la suite de scripts del repositorio.

---

## 📑 Mapa General de Herramientas

| Script / Herramienta | Lanzador Rápido | Propósito Principal | Parámetros Clave |
| :--- | :--- | :--- | :--- |
| **`romanOS-Toolkit.ps1`** | `Lanzar-romanOS-Toolkit.cmd` | Orquestador y Hub Maestro interactivo on-demand | `-Module`, `-ShowDashboards`, `-GUI` |
| **`romanOS-ControlCenter.ps1`** | `Lanzar-romanOS-ControlCenter.cmd` | Interfaz gráfica moderna (WPF/XAML), telemetría en tiempo real y terminal asíncrona | `-WhatIf` |
| **`Win11-Debloat-v3-Adaptive.ps1`** | `Win11-Debloat-v3-Adaptive.cmd` | Debloat adaptativo por hardware, gaming y privacidad | `-BrowsersOnly`, `-Unattended` |
| **`Win11-Network-Diagnostics-Optimizer.ps1`** | `Win11-Network-Diagnostics-Optimizer.cmd` | Diagnóstico de latencia, DNS, MTU y TCP No-Delay | `-Unattended` |
| **`Invoke-WindowsMaintenance.ps1`** | `Invoke-WindowsMaintenance.cmd` | Limpieza profunda WinSxS, Shaders, TRIM y SFC | `-PostInstall`, `-DeepClean`, `-RepairOnly`, `-Full`, `-Unattended` |
| **`Invoke-WindowsSecurityHardening.ps1`** | `Invoke-WindowsSecurityHardening.cmd` | Auditoría de seguridad desacoplada y Hardening gaming-safe | `-AuditOnly`, `-ApplySafeHardening`, `-ShowReport` |
| **`PostInstall-Diagnostics.ps1`** | `Auditar-Instalacion.cmd` | Auditoría forense post-instalación y dashboard HTML | `-DesktopOutput`, `-ShowHtml`, `-OutputDir` |
| **`New-OptimizedWindowsISO-v2.ps1`** | *(Ejecutar en PS Admin)* | Compilador y optimizador de ISOs desatendidas | `-SourceISO`, `-ZeroTouch`, `-OptimizationProfile`, `-UpdatesPath` |
| **`Get-OfficialWindowsISO.ps1`** | *(Ejecutar en PS Admin)* | Descarga directa y segura de ISOs oficiales (Fido/MCT/CDN) | `-Version`, `-Edition`, `-Language`, `-Method` |
| **`Get-WindowsUpdates.ps1`** | `Get-WindowsUpdates.cmd` | Descarga de Windows Updates oficiales (MSU/CAB) para ISO | `-Version`, `-PackageType`, `-OutputDir`, `-Unattended` |
| **`Get-EssentialRuntimes.ps1`** | *(Ejecutar en PS Admin)* | Descarga de paquetes redistribuibles (VC++, DirectX, .NET) | `-DownloadDir`, `-SkipDirectX`, `-SkipDotNet` |
| **`New-TestVM-HyperV.ps1`** | *(Ejecutar en PS Admin)* | Despliegue automatizado de VM de prueba en Hyper-V (Gen 2) | `-ISOPath`, `-MemoryGB`, `-CPUCount`, `-DiskSizeGB` |
| **`Test-OptimizedISO-v2.ps1`** | *(Ejecutar en PS Admin)* | Suite de pruebas unitarias y validación del compilador | `-LogDir`, `-TargetScript` |
| **`Invoke-TestSuite.ps1`** | `Invoke-TestSuite.cmd` | Orquestador Maestro y Batería Integral de Pruebas (13 Fases) | `-Quick`, `-LogDir` |
| **`Manage-SystemSnapshots.ps1`** | `Manage-SystemSnapshots.cmd` | Motor de Instantáneas y Reversión Atómica (Snapshot & Rollback) | `-Action`, `-Name`, `-SnapshotId`, `-IncludeVSS`, `-Force` |
| **`Deploy-AppProfiles.ps1`** | `Deploy-AppProfiles.cmd` | Gestor de Perfiles de Software, Winget y Runtimes de IA por Hardware | `-Profile`, `-InstallRuntimesOnly`, `-AutoDetectHardware`, `-Unattended`, `-WhatIf` |
| **`Monitor-ThermalEnergy.ps1`** | `Monitor-ThermalEnergy.cmd` | Monitor de Throttling Térmico, Sensores y Calibración Energética | `-Action`, `-SampleDurationSec`, `-EnergyProfile`, `-Unattended`, `-WhatIf` |
| **`Invoke-LiveSandbox.ps1`** | `Invoke-LiveSandbox.cmd` | Orquestador de Entornos Sandbox Descartables (.wsb, Air-Gap, vGPU) | `-Action`, `-Preset`, `-SharedFolder`, `-Unattended`, `-WhatIf` |
| **`Watchdog-ServiceDrift.ps1`** | `Watchdog-ServiceDrift.cmd` | Guardián Anti-Drift: Auditoría y Remediación de Servicios y Tareas | `-Action`, `-Target`, `-LogDir`, `-Unattended`, `-WhatIf` |
| **`Setup-AntigravityWindows.ps1`** | `Setup-AntigravityWindows.cmd` | Inicializador de entorno, dependencias winget y skills de Antigravity | `-InstallPrerequisites`, `-EnableHyperV`, `-SetExecutionPolicy`, `-CheckOnly` |
| **`Limpiar-ResiduosWinISO.ps1`** | *(Ejecutar en PS Admin)* | Limpieza profunda de montajes DISM bloqueados, temporales y colmenas | `-ScanOnly`, `-Force`, `-Silent` |

---

## 1. Hub Maestro Desacoplado: `romanOS-Toolkit.ps1`

El Hub Maestro orquesta todas las herramientas bajo demanda con **cero procesos residentes en segundo plano** (*zero-resident footprint*).

### 🖥️ Ejecución Interactiva
```powershell
# Desde PowerShell como Administrador
& "C:\OptimizedISO\scripts\Modules\romanOS-Toolkit.ps1"
```
*O haz doble clic directamente en `C:\OptimizedISO\Lanzar-romanOS-Toolkit.cmd` en la raíz.*

**Opciones del Menú Principal:**
- `[1]`  ⚡ **Optimización Gaming & Hardware** (invoca debloat adaptativo, HAGS, MSI Mode).
- `[2]`  🌐 **Diagnóstico de Red & Latencia** (Benchmarks DNS, TCP/IP, Sockets).
- `[3]`  🧹 **Mantenimiento & Limpieza Profunda** (WinSxS DISM, Shaders GPU, SSD TRIM).
- `[4]`  📋 **Auditoría Forense Post-Instalación & Salud** (Panther, CompactOS, PnP).
- `[5]`  🔍 **Auditoría Forense de Huella en Reposo** (RAM en reposo, procesos residuales).
- `[6]`  🛡️ **Auditoría de Seguridad & Hardening** (ASR, VBS, Protocolos On-Demand).
- `[7]`  🌐 **Optimizar y Debloat de Navegadores** (Edge, Chrome, Brave, Firefox sin IA/bloatware).
- `[8]`  📦 **Descargar Windows Updates Oficiales** (MSU/CAB para Slipstream en ISO).
- `[9]`  💻 **Gestión Integral de Controladores** (Respaldo Host, DriverStore, Intel VMD).
- `[10]` 👤 **Migrar o Rescatar Perfil de Usuario Local** (Respaldos y Recreación).
- `[11]` 📊 **Generar y Abrir Dashboards HTML de Salud y Seguridad**.
- `[12]` 🧠 **Poda Quirúrgica de Memoria RAM en Reposo** (psapi.dll EmptyWorkingSet).
- `[13]` 🎯 **Auditor Universal de Optimización** (10 dominios, scoring y remediación).
- `[14]` 🎮 **Conmutador Modo Juego / Modo Dev** (Liberar RAM para APU y cortar devoradores).
- `[15]` ⚡ **Acciones Rápidas Express** (Flush DNS, Restart Explorer, GodMode, SFC).
- `[16]` 🖥️ **Abrir romanOS Control Center** (Interfaz Gráfica Moderna WPF & Telemetría).
- `[0]`  ❌ **Salir del Toolkit**.

### ⚙️ Modos CLI Directos
```powershell
# Lanzar Auditor Universal de Optimización del Sistema
& "C:\OptimizedISO\scripts\Modules\romanOS-Toolkit.ps1" -Module UniversalAudit

# Conmutar dinámicamente a Modo Juego (recorte agresivo de RAM)
& "C:\OptimizedISO\scripts\Modules\romanOS-Toolkit.ps1" -Module GameAggressive

# Conmutar dinámicamente a Modo Desarrollo (restaura Hyper-V, WSL2, Docker)
& "C:\OptimizedISO\scripts\Modules\romanOS-Toolkit.ps1" -Module DevSwitch

# Poda de Memoria RAM en reposo
& "C:\OptimizedISO\scripts\Modules\romanOS-Toolkit.ps1" -Module MemoryTrim

# Auditoría Forense de Huella en Reposo
& "C:\OptimizedISO\scripts\Modules\romanOS-Toolkit.ps1" -Module FootprintAudit

# Lanzar optimizador de Navegadores
& "C:\OptimizedISO\scripts\Modules\romanOS-Toolkit.ps1" -Module Browsers

# Lanzar módulo de Gaming y Debloat
& "C:\OptimizedISO\scripts\Modules\romanOS-Toolkit.ps1" -Module Gaming

# Lanzar módulo de Red y Latencia
& "C:\OptimizedISO\scripts\Modules\romanOS-Toolkit.ps1" -Module Network

# Lanzar módulo de Mantenimiento y Limpieza
& "C:\OptimizedISO\scripts\Modules\romanOS-Toolkit.ps1" -Module Maintenance

# Lanzar auditoría de Seguridad
& "C:\OptimizedISO\scripts\Modules\romanOS-Toolkit.ps1" -Module Security

# Generar y abrir ambos reportes HTML en el escritorio y navegador
& "C:\OptimizedISO\scripts\Modules\romanOS-Toolkit.ps1" -ShowDashboards

# Lanzar la Interfaz Grafica Moderna WPF (romanOS Control Center)
& "C:\OptimizedISO\scripts\Modules\romanOS-Toolkit.ps1" -GUI
```

---

## 1.1. Interfaz Gráfica Nativa: `romanOS-ControlCenter.ps1`

El Panel de Control gráfico **romanOS Control Center** proporciona telemetría en tiempo real, conmutación de perfiles y ejecución asíncrona de herramientas sin bloquear la interfaz de usuario:

### 🚀 Formas de Invocación
```bat
:: 1. Lanzador Win32 nativo JIT (cero parpadeo de consola) desde CMD o doble clic en la raíz
C:\OptimizedISO\Lanzar-romanOS-ControlCenter.cmd

:: 2. Ejecución directa en PowerShell 5.1 (modo gráfico STA obligatorio)
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "C:\OptimizedISO\scripts\GUI\romanOS-ControlCenter.ps1"

:: 3. Validación en frío sin abrir interfaz gráfica (-WhatIf)
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "C:\OptimizedISO\scripts\GUI\romanOS-ControlCenter.ps1" -WhatIf
```

---

## 2. Optimizador y Debloat Adaptativo: `Win11-Debloat-v3-Adaptive.ps1`

### 🚀 Modo Exclusivo para Navegadores (`-BrowsersOnly`)
Aplica de forma instantánea (**en menos de 2 segundos**) las políticas oficiales GPO para aceleración por GPU en reproducción de video, ahorro agresivo de memoria RAM, eliminación completa de Copilot/Gemini/Leo y supresión de contenido patrocinado/noticias para **Microsoft Edge, Google Chrome, Mozilla Firefox, Brave Browser y Windows Copilot**:

```powershell
& "C:\OptimizedISO\scripts\Win11-Debloat-v3-Adaptive.ps1" -BrowsersOnly
```

> **Ventajas del modo `-BrowsersOnly`:**
> - No modifica configuraciones del sistema operativo, barra de tareas, servicios ni temas.
> - No desinstala aplicaciones Appx ni programas Win32.
> - No requiere crear punto de restauración previo.
> - Habilita `HardwareAccelerationModeEnabled = 1` para delegar la decodificación de video a la GPU.
> - Aplica `IntensiveWakeUpThrottlingEnabled = 1` y `SleepingTabs = 5 min` para liberar hasta un 85% de RAM en segundo plano.
> - Limita la caché en disco a 256 MB.

### 🎮 Modo Completo Interactivo
```powershell
& "C:\OptimizedISO\scripts\Win11-Debloat-v3-Adaptive.ps1"
```
*Muestra diagnóstico del hardware en tiempo real (CPU, RAM, Discos NVMe/SATA, GPU MSI Mode) y menús visuales (`Out-GridView`) para seleccionar qué componentes eliminar o personalizar.*

### 🤖 Modo Desatendido Total (`-Unattended`)
```powershell
& "C:\OptimizedISO\scripts\Win11-Debloat-v3-Adaptive.ps1" -Unattended
```
*Aplica automáticamente todas las optimizaciones recomendadas sin solicitar confirmaciones.*

---

## 3. Diagnóstico y Optimización de Red: `Win11-Network-Diagnostics-Optimizer.ps1`

### 🌐 Ejecución Interactiva
```powershell
& "C:\OptimizedISO\scripts\Win11-Network-Diagnostics-Optimizer.ps1"
```
*O doble clic en `Win11-Network-Diagnostics-Optimizer.cmd`.*

**Capacidades:**
- Benchmark comparativo de latencia en servidores DNS (Cloudflare, Google, Quad9, OpenDNS).
- Detección y ajuste óptimo de MTU/MSS por interfaz activa.
- Desactivación del algoritmo de Nagle (`TcpNoDelay=1`, `TcpAckFrequency=1`) para gaming competitivo.
- Ajuste de TCP Window Auto-Tuning y congestión.
- Purga completa de caché DNS y reinicio del stack TCP/IP.

### ⚡ Modo Desatendido
```powershell
& "C:\OptimizedISO\scripts\Win11-Network-Diagnostics-Optimizer.ps1" -Unattended
```

---

## 4. Mantenimiento Profundo y Reparación: `Invoke-WindowsMaintenance.ps1`

### 🧹 Menú Interactivo de Mantenimiento
```powershell
& "C:\OptimizedISO\scripts\Invoke-WindowsMaintenance.ps1"
```

### 🛠️ Modos Especializados por Parámetros

```powershell
# 1. Modo Post-Instalacion Rapido (residuos OOBE/Panther + temporales + SSD TRIM)
& "C:\OptimizedISO\scripts\Invoke-WindowsMaintenance.ps1" -PostInstall -Unattended

# 2. Modo Limpieza Profunda (WinSxS DISM + Shaders GPU + Caches de navegadores + Logs)
& "C:\OptimizedISO\scripts\Invoke-WindowsMaintenance.ps1" -DeepClean -Unattended

# 3. Limpieza Profunda con Consolidacion Permanente de Actualizaciones (/ResetBase)
& "C:\OptimizedISO\scripts\Invoke-WindowsMaintenance.ps1" -DeepClean -ResetBase -Unattended

# 4. Modo Reparacion Exclusiva del Sistema (DISM RestoreHealth + SFC + WMI + NTFS + Red)
& "C:\OptimizedISO\scripts\Invoke-WindowsMaintenance.ps1" -RepairOnly -Unattended

# 5. Mantenimiento Total Integral (Modulos 1 al 6)
& "C:\OptimizedISO\scripts\Invoke-WindowsMaintenance.ps1" -Full -Unattended

# 6. Mantenimiento Total omitiendo operaciones lentas de DISM
& "C:\OptimizedISO\scripts\Invoke-WindowsMaintenance.ps1" -Full -SkipDism -Unattended
```

---

## 5. Auditoría de Seguridad y Hardening: `Invoke-WindowsSecurityHardening.ps1`

Audita y endurece la seguridad del sistema **sin procesos residentes** ni incompatibilidades con juegos o sistemas anti-cheat (Riot Vanguard, Easy Anti-Cheat, BattlEye).

### 🔍 Auditoría Solo Lectura con Reporte HTML en Pantalla
```powershell
& "C:\OptimizedISO\scripts\Invoke-WindowsSecurityHardening.ps1" -AuditOnly -ShowReport
```
*Genera `INFORME_SEGURIDAD.html` y `INFORME_SEGURIDAD.md` con semáforo visual (Aprobado, Advertencia, Crítico).*

### 🛡️ Aplicar Hardening Seguro para Gaming (Recomendado)
```powershell
& "C:\OptimizedISO\scripts\Invoke-WindowsSecurityHardening.ps1" -ApplySafeHardening -ShowReport
```
*Desactiva SMBv1 y LLMNR, habilita LSA Protection (RunAsPPL), bloquea WPBT en BIOS/ACPI y restringe cuentas sin contraseña, sin degradar el rendimiento en juegos.*

### 🔒 Aplicar Hardening Corporativo Estricto
```powershell
& "C:\OptimizedISO\scripts\Invoke-WindowsSecurityHardening.ps1" -ApplyStrictHardening -ShowReport
```

---

## 6. Auditoría Forense Post-Instalación: `PostInstall-Diagnostics.ps1`

Evalúa el estado de una instalación limpia de Windows o de una imagen optimizada.

### 📋 Generar Reporte y Dashboard HTML en el Escritorio
```powershell
& "C:\OptimizedISO\scripts\PostInstall-Diagnostics.ps1" -DesktopOutput -ShowHtml
```
*O ejecuta `Auditar-Instalacion.cmd`.*

**Aspectos que audita:**
- Errores en logs de instalación (`setupact.log`, `setuperr.log`).
- Estado de CompactOS (`compact.exe /compactos:query`).
- Dispositivos PnP con problemas de controlador (`Win32_PnPEntity`).
- Servicios detenidos o deshabilitados.
- Estado de políticas GPO aplicadas en Edge y Chrome.

---

## 7. Compilación de ISOs Optimizadas: `New-OptimizedWindowsISO-v2.ps1`

### 🧙 Modo Asistente Guiado (Recomendado para nuevos usuarios)
```powershell
& "C:\OptimizedISO\scripts\New-OptimizedWindowsISO-v2.ps1"
```
*Detecta herramientas instaladas (DISM, oscdimg, 7-Zip, curl), busca ISOs locales o permite descargarlas en vivo, ofrece selector de índices WIM, selector de scripts optimizadores e inyección de drivers y runtimes.*

### ⚡ Compilaciones Desatendidas vía CLI

```powershell
# 1. Compilar ISO de Windows 11 con usuario local "Roman", perfil Gaming y Zero-Touch
& "C:\OptimizedISO\scripts\New-OptimizedWindowsISO-v2.ps1" `
  -SourceISO "C:\ISOs\Win11_24H2_Spanish_x64.iso" `
  -LocalUser "Roman" `
  -OptimizationProfile "1" `
  -ZeroTouch `
  -Language "es-ES" `
  -Timezone "Romance Standard Time"

# 2. Compilar ISO para Laptop o Máquina Virtual (Perfil 3 - Eficiencia Energética / Plan Equilibrado)
& "C:\OptimizedISO\scripts\New-OptimizedWindowsISO-v2.ps1" `
  -SourceISO "C:\ISOs\Win11_24H2.iso" `
  -LocalUser "Roman" `
  -OptimizationProfile "3" `
  -ZeroTouch

# 3. Guardar la configuración actual como Preset JSON reutilizable (-SavePreset)
& "C:\OptimizedISO\scripts\New-OptimizedWindowsISO-v2.ps1" `
  -SourceISO "C:\ISOs\Win11_24H2.iso" `
  -LocalUser "Roman" `
  -OptimizationProfile "3" `
  -SavePreset

# 4. Cargar un Preset JSON previamente guardado para compilación 100% automatizada (-PresetFile)
& "C:\OptimizedISO\scripts\New-OptimizedWindowsISO-v2.ps1" `
  -SourceISO "C:\ISOs\Win11_24H2.iso" `
  -PresetFile "C:\OptimizedISO\MiPreset.json"

# 5. Descarga automática de Windows 11 IoT Enterprise LTSC 2024 + Optimización
& "C:\OptimizedISO\scripts\New-OptimizedWindowsISO-v2.ps1" `
  -DownloadOfficialISO `
  -DownloadVersion "11_LTSC_2024" `
  -DownloadEdition "IoTEnterprise" `
  -DownloadLanguage "Spanish" `
  -LocalUser "Admin" `
  -ZeroTouch

# 6. Compilación rápida omitiendo limpieza lenta de componentes WinSxS
& "C:\OptimizedISO\scripts\New-OptimizedWindowsISO-v2.ps1" `
  -SourceISO "C:\ISOs\Win11.iso" `
  -LocalUser "Gamer" `
  -SkipComponentCleanup `
  -WimCompression "Fast"
```

### 📋 Perfiles de Optimización Disponibles (`-OptimizationProfile`)
| Perfil | Nombre | Descripción y Target |
|---|---|---|
| `1` | **Gaming & Rendimiento** | Debloat completo, telemetría off, MMCSS, HAGS, BypassIO. Mantiene Wi-Fi, Bluetooth, impresoras y anti-cheats. *(Recomendado para PCs de escritorio)*. |
| `2` | **Hardcore E-Sports** | Latencia mínima extrema. Desactiva hipervisor (`hypervisorlaunchtype off`), Wi-Fi, Bluetooth, Spooler y búsqueda. *(Para torres dedicadas a e-sports)*. |
| `3` | **Laptop / VM Silencioso** | Debloat completo + **Plan Equilibrado (`SCHEME_BALANCED`)**. Mantiene `SysMain`, `WSearch`, Wi-Fi, Bluetooth e impresoras. *(Optimiza autonomía de batería en portátiles y estabilidad en VMs)*. |

### 💾 Presets JSON Reutilizables (`-PresetFile` / `-SavePreset`)
- **`-SavePreset`**: Exporta un archivo `Preset_romanOS_YYYYMMDD_HHMMSS.json` en `$OutputDir` con toda la configuración regional, usuario, contraseñas, perfil de optimización y compresión WIM.
- **`-PresetFile <Ruta>`**: Carga la configuración desde un archivo JSON. Si pasas parámetros por consola adicionales, el CLI tendrá prioridad sobre los valores del JSON.


---

## 8. Descarga Oficial de ISOs: `Get-OfficialWindowsISO.ps1`

Descargador multicanal con verificación criptográfica SHA-256:

```powershell
# Descargar Windows 11 24H2 Consumer en Español
& "C:\OptimizedISO\scripts\Get-OfficialWindowsISO.ps1" `
  -Version "11_24H2" `
  -Edition "Consumer" `
  -Language "Spanish"

# Descargar Windows 11 LTSC 2024 IoT Enterprise en Inglés
& "C:\OptimizedISO\scripts\Host-Tools\Get-OfficialWindowsISO.ps1" `
  -Version "11_LTSC_2024" `
  -Edition "IoTEnterprise" `
  -Language "English"
```

---

## 9. Descargador Oficial de Windows Updates: `Get-WindowsUpdates.ps1`

Descarga paquetes oficiales `.msu` y `.cab` (LCU, SSU, .NET Framework Cumulative Updates y SafeOS Dynamic Updates) directamente desde el Catálogo de Microsoft Update para inyección offline (*slipstreaming*) en la ISO:

```powershell
# 1. Modo Interactivo con selección asistida y prompt de carpeta de destino:
& "C:\OptimizedISO\scripts\Builder\Get-WindowsUpdates.ps1"
# O doble clic en: C:\OptimizedISO\scripts\Builder\Get-WindowsUpdates.cmd

# 2. Descarga desatendida de parches para Windows 11 24H2 en una carpeta específica:
& "C:\OptimizedISO\scripts\Builder\Get-WindowsUpdates.ps1" `
  -Version "11_24H2" `
  -PackageType "All" `
  -OutputDir "C:\OptimizedISO\Updates" `
  -Unattended

# 3. Descargar solo parches LCU y .NET para Windows 11 25H2:
& "C:\OptimizedISO\scripts\Builder\Get-WindowsUpdates.ps1" `
  -Version "11_25H2" `
  -PackageType "All" `
  -OutputDir "C:\OptimizedISO\Updates"

# 4. Incluir SafeOS Dynamic Update para entorno WinRE:
& "C:\OptimizedISO\scripts\Get-WindowsUpdates.ps1" `
  -Version "11_LTSC_2024" `
  -IncludeSafeOS `
  -OutputDir "C:\OptimizedISO\Updates"
```

> **Integración con la ISO:**
> `New-OptimizedWindowsISO-v2.ps1` busca automáticamente en `C:\OptimizedISO\Updates\` e inyecta los paquetes con DISM en orden técnico estricto (SSU -> Checkpoint -> LCU -> .NET -> SafeOS). Si guardaste los parches en otra carpeta, usa el parámetro `-UpdatesPath "D:\MisParches"`.

---

## 10. Paquetes Redistribuibles Offline: `Get-EssentialRuntimes.ps1`

Descarga todos los prerrequisitos para que la ISO los instale sin conexión a Internet:

```powershell
& "C:\OptimizedISO\scripts\Get-EssentialRuntimes.ps1" -DownloadDir "C:\OptimizedISO\scripts\Runtimes"
```
*Obtiene Visual C++ All-in-One (2005 a 2022 x86/x64), DirectX End-User Runtimes (June 2010), WebView2 Evergreen Runtime y .NET Desktop Runtimes.*

---

## 11. Pruebas Automatizadas en Hyper-V: `New-TestVM-HyperV.ps1`

Crea y arranca una máquina virtual UEFI Gen 2 con TPM 2.0 y Secure Boot para validar la ISO:

```powershell
# Deteccion automatica de la ISO mas reciente
& "C:\OptimizedISO\scripts\New-TestVM-HyperV.ps1"

# Especificando parametros personalizados
& "C:\OptimizedISO\scripts\New-TestVM-HyperV.ps1" `
  -ISOPath "C:\OptimizedISO\Win11_Optimized.iso" `
  -VMName "VM_Prueba_Win11" `
  -MemoryGB 8 `
  -CPUCount 6 `
  -DiskSizeGB 80
```

---

## 12. Suite de Validación Unitaria: `Test-OptimizedISO-v2.ps1`

Ejecuta el arnés de pruebas de regresión para validar la sintaxis, módulos y templates:

```powershell
# Ejecutar todas las fases de prueba (Fases 1 a 4)
& "C:\OptimizedISO\scripts\Test-OptimizedISO-v2.ps1" -Verbose

# Probar solo la Fase 1 (Sintaxis y Prerrequisitos)
& "C:\OptimizedISO\scripts\Test-OptimizedISO-v2.ps1" -Phase1
```

---

## 13. Orquestador Maestro de Pruebas: `Invoke-TestSuite.ps1`

Ejecuta la suite integral de pruebas del proyecto en un solo paso, consolidando la validación sintáctica AST, codificación UTF-8 BOM, esquema XML de despliegue desatendido, entorno de compilación ADK/DISM, higiene de Git y el Test Harness completo de la ISO:

```powershell
# 1. Ejecución completa con reporte Markdown consolidado:
& "C:\OptimizedISO\scripts\Testing\Invoke-TestSuite.ps1"
# O doble clic en: C:\OptimizedISO\scripts\Testing\Invoke-TestSuite.cmd

# 2. Modo Rápido (9 Fases de pruebas en ~30 segundos):
& "C:\OptimizedISO\scripts\Testing\Invoke-TestSuite.ps1" -Quick
```

---

## 14. Motor de Instantáneas y Reversión Atómica: `Manage-SystemSnapshots.ps1`

Permite capturar estados íntegros de la configuración del sistema operativo (directivas de registro, telemetría de servicios, configuración de red y puntos VSS) con verificación criptográfica SHA-256 y reversión en caliente:

```powershell
# 1. Crear snapshot rápido antes de aplicar optimizaciones o debloat
& "C:\OptimizedISO\scripts\Modules\Manage-SystemSnapshots.ps1" -Action Create -Name "Pre-Optimizacion" -IncludeVSS

# 2. Listar todas las instantáneas disponibles
& "C:\OptimizedISO\scripts\Modules\Manage-SystemSnapshots.ps1" -Action List

# 3. Restaurar una instantánea atómicamente
& "C:\OptimizedISO\scripts\Modules\Manage-SystemSnapshots.ps1" -Action Restore -SnapshotId "SNAP-20260922-001744-UnitTestSnapshot" -Force

# 4. Exportar snapshot a archivo ZIP para respaldo externo
& "C:\OptimizedISO\scripts\Modules\Manage-SystemSnapshots.ps1" -Action Export -SnapshotId "SNAP-20260922-001744"

# 5. Crear solo Punto de Restauración VSS nativo
& "C:\OptimizedISO\scripts\Modules\Manage-SystemSnapshots.ps1" -Action CreateVSS -Name "Punto-Seguro"
```

---

## 15. Gestor de Perfiles de Software y Runtimes de IA: `Deploy-AppProfiles.ps1`

Orquesta la instalación silenciosa de paquetes curados mediante `winget.exe`, runtimes base del sistema (Visual C++ 2015-2022, DirectX, .NET 8/9 LTS) y aceleradores de IA local adaptados por hardware (Ollama, DirectML, NVIDIA App, AMD Adrenalin):

```powershell
# 1. Instalar perfil de eSports & Competitive Gamer con detección automática de GPU/NPU
& "C:\OptimizedISO\scripts\Modules\Deploy-AppProfiles.ps1" -Profile EsportsGamer -AutoDetectHardware -Unattended

# 2. Instalar perfil de Ingeniero de IA & Desarrollador (Ollama, VS Code, Git, Python 3.12, Terminal)
& "C:\OptimizedISO\scripts\Modules\Deploy-AppProfiles.ps1" -Profile AIAndDeveloper -AutoDetectHardware -Unattended

# 3. Instalar exclusivamente los runtimes base de Windows (.NET, Visual C++, DirectX)
& "C:\OptimizedISO\scripts\Modules\Deploy-AppProfiles.ps1" -InstallRuntimesOnly -Unattended

# 4. Simular instalación para auditoría previa (-WhatIf)
& "C:\OptimizedISO\scripts\Modules\Deploy-AppProfiles.ps1" -Profile EsportsGamer -AutoDetectHardware -WhatIf
```

---

## 16. Monitor Térmico, Detección de Throttling y Calibrador Energético: `Monitor-ThermalEnergy.ps1`

Herramienta nativa y 100% segura contra anti-cheats (cero drivers invasivos) para auditar el estado térmico, detectar caídas de frecuencia por estrangulamiento térmico o límites de potencia, y calibrar el plan de energía *Ultimate Performance* con *Core Unparking* (des-estacionamiento de núcleos) para eliminar micro-stuttering.

```powershell
# 1. Auditoría forense rápida en una sola línea (ideal para scripts y telemetría)
& "C:\OptimizedISO\scripts\Modules\Monitor-ThermalEnergy.ps1" -Action Audit

# 2. Diagnóstico integral en pantalla (frecuencias CPU, sensores ACPI, plan activo)
& "C:\OptimizedISO\scripts\Modules\Monitor-ThermalEnergy.ps1" -Action Status

# 3. Muestreo dinámico en vivo durante 15 segundos con detección de Throttling
& "C:\OptimizedISO\scripts\Modules\Monitor-ThermalEnergy.ps1" -Action Monitor -SampleDurationSec 15

# 4. Calibrar energía a 'Ultimate Performance' y des-estacionar núcleos (Core Unparking)
& "C:\OptimizedISO\scripts\Modules\Monitor-ThermalEnergy.ps1" -Action CalibrateEnergy -EnergyProfile Ultimate -Unattended

# 5. Des-estacionar núcleos exclusivamente para reducir latencia de hilos de juego
& "C:\OptimizedISO\scripts\Modules\Monitor-ThermalEnergy.ps1" -Action UnparkCores -Unattended
```

---

## 17. Entorno Sandbox Descartable en Vivo: `Invoke-LiveSandbox.ps1`

Orquestador nativo y desacoplado para ejecutar utilidades de terceros, mods de juegos, parches no oficiales o navegación de máxima privacidad en un contenedor efímero aislado (*Windows Sandbox*), sin riesgo de contaminar el registro ni disparar alertas en sistemas anti-cheat.

```powershell
# 1. Diagnosticar soporte de virtualización CPU (SLAT / AMD-V / VT-x) y estado de Sandbox
& "C:\OptimizedISO\scripts\Modules\Invoke-LiveSandbox.ps1" -Action Status

# 2. Lanzar Sandbox en modo Air-Gap estricto (sin red, sin vGPU, carpeta sólo lectura)
& "C:\OptimizedISO\scripts\Modules\Invoke-LiveSandbox.ps1" -Action Launch -Preset SafeAnalysis -SharedFolder "C:\DescargasSospechosas"

# 3. Lanzar Sandbox para pruebas de Mods y Juegos (vGPU Direct3D activa, red y lectura/escritura)
& "C:\OptimizedISO\scripts\Modules\Invoke-LiveSandbox.ps1" -Action Launch -Preset GameModding -SharedFolder "C:\Juegos\Mods"

# 4. Lanzar Sandbox de Navegación Privada Efímera (destruye cualquier rastro al cerrar)
& "C:\OptimizedISO\scripts\Modules\Invoke-LiveSandbox.ps1" -Action Launch -Preset DisposableBrowser

# 5. Generar archivo de configuración XML (.wsb) para inspección previa o uso manual
& "C:\OptimizedISO\scripts\Modules\Invoke-LiveSandbox.ps1" -Action GenerateConfig -Preset SafeAnalysis

# 6. Simular el lanzamiento (-WhatIf) para auditoría sin invocar el proceso
& "C:\OptimizedISO\scripts\Modules\Invoke-LiveSandbox.ps1" -Action Launch -Preset SafeAnalysis -WhatIf
```

---

## 18. Guardián Anti-Drift y Watchdog de Servicios: `Watchdog-ServiceDrift.ps1`

Auditor en caliente y remediador de desvío de configuración (*Configuration Drift*) tras la instalación de parches mensuales de Windows Update (LCUs) o software que reactiva telemetría (`DiagTrack`, `dmwappushservice`, `WerSvc`, tareas programadas CEIP).

```powershell
# 1. Auditar en caliente la paridad de servicios y tareas frente al estándar SSOT de romanOS
& "C:\OptimizedISO\scripts\Modules\Watchdog-ServiceDrift.ps1" -Action Audit

# 2. Remediar atómicamente todos los desvíos detectados (detener y deshabilitar en 1-clic)
& "C:\OptimizedISO\scripts\Modules\Watchdog-ServiceDrift.ps1" -Action Remediate -Unattended

# 3. Simular remediación (-WhatIf) para inspección sin alterar el sistema
& "C:\OptimizedISO\scripts\Modules\Watchdog-ServiceDrift.ps1" -Action Remediate -WhatIf

# 4. Registrar tarea programada periódica para auditoría automática y silenciosa
& "C:\OptimizedISO\scripts\Modules\Watchdog-ServiceDrift.ps1" -Action RegisterTask

# 5. Desinstalar la tarea programada periódica
& "C:\OptimizedISO\scripts\Modules\Watchdog-ServiceDrift.ps1" -Action UnregisterTask
```

---

## 19. Calibrador de Afinidad PCIe, Prioridad IRQ y DPC Steering: `Optimize-InterruptAffinity.ps1`

Módulo nativo, desacoplado y seguro contra sistemas anti-cheat (cero drivers vulnerables) para balancear la carga de interrupciones de hardware en la topología PCIe: descongestiona el Núcleo Lógico 0, eleva la prioridad IRQ de la GPU y unidades NVMe a `High (3)` y balancea las rutinas DPC (`DevicePolicy = 5 / SpreadAcrossCPUs` o `DevicePolicy = 4 / ExcludeCoreZero`):

```powershell
# 1. Diagnóstico e introspección en vivo de topología PCIe (GPU, NVMe, adaptadores de red)
& "C:\OptimizedISO\scripts\Modules\Optimize-InterruptAffinity.ps1" -Action Status

# 2. Auditoría forense rápida de métricas de interrupciones (resumen en terminal)
& "C:\OptimizedISO\scripts\Modules\Optimize-InterruptAffinity.ps1" -Action Audit

# 3. Calibrar afinidad y prioridad IRQ en 1-clic (aislar Core 0 y optimizar GPU/NVMe)
& "C:\OptimizedISO\scripts\Modules\Optimize-InterruptAffinity.ps1" -Action Optimize -Unattended

# 4. Calibrar aplicando estrategia específica de distribución
& "C:\OptimizedISO\scripts\Modules\Optimize-InterruptAffinity.ps1" -Action Optimize -AffinityStrategy SpreadAcrossCPUs -Unattended

# 5. Simular la optimización (-WhatIf) para inspección sin alterar el registro
& "C:\OptimizedISO\scripts\Modules\Optimize-InterruptAffinity.ps1" -Action Optimize -WhatIf

# 6. Revertir todas las directivas de hardware a valores de fábrica de Windows (Rollback HAL)
& "C:\OptimizedISO\scripts\Modules\Optimize-InterruptAffinity.ps1" -Action Reset -Unattended
```

---

## 💡 Recetario de Casos de Uso Frecuentes (Cheatsheet)

### ¿Siento micro-stuttering o caídas de 1% Low FPS en juegos por saturación de CPU?
```powershell
& "C:\OptimizedISO\scripts\Modules\Optimize-InterruptAffinity.ps1" -Action Optimize -Unattended
```

### ¿Solo quiero acelerar videos y bajar la RAM de Chrome/Edge/Firefox sin tocar nada más?
```powershell
& "C:\OptimizedISO\scripts\Win11-Debloat-v3-Adaptive.ps1" -BrowsersOnly
```

### ¿Quiero limpiar temporales, WinSxS y shaders tras jugar o actualizar Windows?
```powershell
& "C:\OptimizedISO\scripts\Invoke-WindowsMaintenance.ps1" -DeepClean -Unattended
```

### ¿Quiero revisar si mi Windows está seguro sin instalar ningún antivirus pesado?
```powershell
& "C:\OptimizedISO\scripts\Invoke-WindowsSecurityHardening.ps1" -AuditOnly -ShowReport
```

### ¿Tengo problemas de lag o pérdida de paquetes en juegos online?
```powershell
& "C:\OptimizedISO\scripts\Win11-Network-Diagnostics-Optimizer.ps1"
```

### ¿Quiero abrir el panel de control unificado y elegir con calma?
```powershell
& "C:\OptimizedISO\scripts\romanOS-Toolkit.ps1"
```

---

*Documento mantenido y actualizado activamente como parte del estándar de trazabilidad del proyecto romanOS.*
