# PLAN-0087: Auditoría Forense de Ingeniería, Validación Empírica y Modernización 1 a 1 de las Herramientas del romanOS Toolkit

**Estado:** `PENDIENTE`  
**Fecha:** 2026-09-20  
**Autor:** Antigravity AI Pair Programmer & romanOS Team  
**Rama:** `feature/offline-ui-tweaks`  

---

## 1. Resumen Ejecutivo y Marco Filosófico

El ecosistema **romanOS Toolkit Maestro** es la suite centralizada de administración, optimización extrema para gaming/streaming, mantenimiento profundo, observabilidad de hardware y ciberseguridad desacoplada (*Zero-Resident Footprint*) de la ISO optimizada y del sistema instalado.

Históricamente, muchas suites comunitarias de personalización y "optimización" de Windows arrastran directivas de registro, scripts y parámetros de línea de comandos heredados de Windows XP, Windows 7 o las primeras compilaciones de Windows 10. En el kernel moderno de **Windows 11 (24H2 / 25H2)**, muchas de estas prácticas:
1. Son **No-Op (Inoperantes):** El subsistema moderno las ignora por completo.
2. Son **Placebos:** Generan una percepción visual de mejora sin impacto medible.
3. Son **Contraproducentes:** Provocan picos de *Hard Page Faults*, degradan el programador de hilos (*Core Scheduling*) en arquitecturas híbridas (Intel P/E-cores y AMD Dual-CCD 3D V-Cache), o colisionan con directivas de seguridad modernas (VBS, HVCI, RunAsPPL).

### Propósito del Plan
Ejecutar una **auditoría forense de ingeniería de software, rigurosa y empírica, herramienta por herramienta (1 a 1)** de todo el Toolkit. Se evaluará cada función frente a la documentación oficial de Microsoft y estándares de la industria (WDDM, RFCs, DMTF, DirectStorage), respaldando cada hallazgo con datos medibles (RAM, latencia, DPC, tiempos de ejecución) y determinando si debe ser **mantenida**, **modernizada** o **purgada**.

---

## 2. Metodología de Auditoría Forense (Ficha Técnica por Herramienta)

Cada una de las 18 herramientas será sometida a una evaluación estandarizada bajo una **Ficha Técnica de Ingeniería de 5 Dimensiones**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MATRIZ DE AUDITORÍA FORENSE POR HERRAMIENTA              │
├─────────────────────────────────────────────────────────────────────────────┤
│  1. Desglose Anatómico de Código  ➔ Funciones, switches CLI, llamadas APIs │
│  2. Fundamento Oficial Microsoft  ➔ Documentación Learn, WDDM, APIs Win32  │
│  3. Diagnóstico de Obsolescencia  ➔ ¿Vigente, Deprecado, No-Op o Reemplazo?│
│  4. Validación Empírica & Métricas➔ MB RAM, ms Latencia, DPC, IOPS, Errores│
│  5. Dictamen Técnico Fundamentado ➔ MANTENER / MODERNIZAR / PURGAR         │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Dimensión 1: Desglose Anatómico y Funcional
- Mapeo exhaustivo de funciones internas, switches de línea de comandos (`param`) y dependencias de scripts hermanos.
- Evaluación de compatibilidad estricta con el runtime de destino: Windows PowerShell 5.1 (`powershell.exe -STA`) y PowerShell 7+ (`pwsh`).
- Verificación de codificación: UTF-8 con BOM en `.ps1` y ANSI / UTF-8 sin BOM en `.cmd`.

### Dimensión 2: Fundamento Oficial y Estándares de la Industria
- Cita textual y enlace a la documentación técnica de **Microsoft Learn**, **Windows Internals**, especificaciones **WDDM 3.x**, estándares de **DMTF SMBIOS** o RFCs de redes.
- Justificación técnica a nivel de kernel: ¿Por qué existe este parámetro? ¿Qué estructura interna de Windows modifica?

### Dimensión 3: Diagnóstico de Vigencia, Depreciación y Obsolescencia
- **Vigente:** Respaldado por el kernel actual y con efecto activo en Windows 11 24H2/25H2.
- **Deprecado / No-Op:** Claves de registro o comandos que Microsoft ha retirado o convertido en operaciones vacías.
- **Alternativa Superior:** Existencia de APIs modernas de Win32, cmdlets nativos de PowerShell o mecanismos del sistema operativo que realizan la misma función con menor sobrecarga o mayor seguridad.

### Dimensión 4: Validación Empírica y Métricas Cuantitativas
- **Memoria:** Medición de Working Set privado vs. Working Set compartido, impacto en *Page Faults* tras podas con `psapi.dll`.
- **Red y Latencia:** Mediciones reales de Round Trip Time (RTT), jitter y resolución DNS en milisegundos.
- **Almacenamiento y Sistema:** Verificación de bloques descartados mediante SSD TRIM, espacio en disco recuperado en `WinSxS` y `DriverStore\FileRepository`.
- **Estabilidad y Anti-Cheats:** Verificación de cero conflictos con sistemas anti-cheat a nivel de kernel (Riot Vanguard, Easy Anti-Cheat, BattlEye, FACEIT).

### Dimensión 5: Dictamen Técnico de Ingeniería
- **`MANTENER`:** Funcionalidad sólida, demostrada empíricamente y alineada con la SSOT (`Policy-Engine.ps1` / `Hardware-Engine.ps1`).
- **`MODERNIZAR / REFACTORIZAR`:** La funcionalidad es útil pero requiere migrar a APIs modernas, mejorar el manejo de errores o desacoplar código redundante.
- **`PURGAR`:** Parámetro placebo, mito desmentido, función inoperante o contraproducente en Windows 11 moderno.

---

## 3. Inventario Secuencial de Auditoría (1 a 1)

La auditoría se ejecutará secuencialmente respetando 5 bloques temáticos estructurados:

### Bloque 1: Orquestación, GUI y Accesibilidad
| Orden | Herramienta | Archivos Evaluados | Foco del Análisis Forense |
| :---: | :--- | :--- | :--- |
| **01** | **Hub Orquestador CLI**<br>`[AUDITADO - PASS]` | `scripts/Modules/romanOS-Toolkit.ps1`<br>`Lanzar-romanOS-Toolkit.cmd` | Blindaje de `$script:searchDirs` y corrección de sintaxis `sc.exe`/`Set-Service` en restauración de servicios. |
| **02** | **romanOS Control Center**<br>`[AUDITADO - PASS]` | `scripts/GUI/romanOS-ControlCenter.ps1`<br>`Lanzar-romanOS-ControlCenter.cmd`<br>`scripts/GUI/romanOS-ControlCenter-Launcher.cs` | WPF Dark Mode, telemetría de hardware, streaming a 60 FPS y blindaje de selección de adaptador de red físico. |
| **03** | **Menús Contextuales Optimizados**<br>`[AUDITADO - PASS]` | `scripts/Modules/Add-OptimizedContextMenus.ps1`<br>`scripts/Modules/Add-OptimizedContextMenus.cmd` | Verbos estáticos nativos (0 DLLs residentes), CLSID clásico y Take Ownership blindado con SID BUILTIN\Administradores. |
| **04** | **Acciones Rápidas Express**<br>`[AUDITADO - PASS]` | Función `Show-QuickActionsMenu` en `romanOS-Toolkit.ps1` | Atajos exprés: God Mode, flushdns, SSD TRIM, toggle hipervisor y reinicio de Explorer protegido contra doble proceso. |

### Bloque 2: Optimización de Rendimiento, Gaming y Navegadores
| Orden | Herramienta | Archivos Evaluados | Foco del Análisis Forense |
| :---: | :--- | :--- | :--- |
| **05** | **Optimización Gaming & Debloat**<br>`[AUDITADO - PASS]` | `scripts/Modules/Win11-Debloat-v3-Adaptive.ps1`<br>`scripts/Modules/Win11-Debloat-v3-Adaptive.cmd` | HAGS seguro en WDDM 3.x (bloqueado en UMA), MMCSS tuning, blindaje de rutas modulares y display de salvaguardas NPU/MUX. |
| **06** | **Optimización de Navegadores** | `scripts/Modules/Optimize-WebBrowsers.ps1`<br>`scripts/Modules/Optimize-WebBrowsers.cmd` | Directivas Edge/Chrome/Firefox: aceleración por hardware GPU real, sleeping tabs, límite de caché vs degradación de rendimiento. |
| **07** | **Poda Quirúrgica de Memoria RAM** | `scripts/Modules/Optimize-ProcessMemory.ps1`<br>`scripts/Modules/Optimize-ProcessMemory.cmd` | `psapi.dll EmptyWorkingSet`: impacto real en RAM vs coste de Hard Page Faults al volver a acceder a memoria. |
| **08** | **Conmutador Modo Juego / Dev** | `scripts/Modules/Switch-GameDevMode.ps1`<br>`scripts/Modules/Switch-GameDevMode.cmd` | Congelación de servicios pesados (Docker, WSL2, Hyper-V, SQL) para maximizar VRAM en APUs y RAM en gaming. |

### Bloque 3: Red, Latencia y Mantenimiento del Sistema
| Orden | Herramienta | Archivos Evaluados | Foco del Análisis Forense |
| :---: | :--- | :--- | :--- |
| **09** | **Diagnóstico de Red & Latencia** | `scripts/Modules/Win11-Network-Diagnostics-Optimizer.ps1`<br>`scripts/Modules/Win11-Network-Diagnostics-Optimizer.cmd` | Parámetros TCP/IP (CTCP vs CUBIC/BBR en Windows 11), TCP No-Delay/Nagle en juegos modernos, cálculo de MTU. |
| **10** | **Mantenimiento & Limpieza Profunda** | `scripts/Modules/Invoke-WindowsMaintenance.ps1`<br>`scripts/Modules/Invoke-WindowsMaintenance.cmd` | DISM ResetBase en WinSxS, purga de Shaders (DirectX/NV/AMD) vs regeneración con stuttering, TRIM forzado en SSDs. |

### Bloque 4: Seguridad, Auditoría y Observabilidad Forense
| Orden | Herramienta | Archivos Evaluados | Foco del Análisis Forense |
| :---: | :--- | :--- | :--- |
| **11** | **Auditoría Forense Post-Instalación** | `scripts/Modules/PostInstall-Diagnostics.ps1`<br>`scripts/Modules/Auditar-Instalacion.cmd` | Panther logs, CompactOS, dispositivos PnP con error, generación de reportes HTML/Markdown interactivos. |
| **12** | **Auditoría Forense de Huella (Footprint)**| `scripts/Modules/Audit-FreshInstallFootprint.ps1` | Medición empírica de huella en reposo: procesos activos, RAM física consumida vs asignada, trazabilidad de servicios. |
| **13** | **Auditoría de Seguridad & Hardening** | `scripts/Modules/Invoke-WindowsSecurityHardening.ps1`<br>`scripts/Modules/Invoke-WindowsSecurityHardening.cmd` | Reglas ASR, LSA RunAsPPL, VBS/HVCI, mitigaciones Spectre/Meltdown: evaluación gaming-safe sin romper compatibilidad. |
| **14** | **Generador de Dashboards Visuales** | Función `Invoke-OpenDashboards` en `romanOS-Toolkit.ps1` | Sincronización de diagnósticos de instalación y seguridad y apertura unificada en navegadores locales. |
| **15** | **Auditor Universal de Optimización** | `scripts/Modules/Audit-SystemOptimization.ps1` | Evaluación de 10 dominios técnicos, heurística de scoring 0-100 y remediación asistida con validación multi-hardware. |

### Bloque 5: Ecosistema de Drivers, Actualizaciones y Migración
| Orden | Herramienta | Archivos Evaluados | Foco del Análisis Forense |
| :---: | :--- | :--- | :--- |
| **16** | **Descargador de Windows Updates** | `scripts/Builder/Get-WindowsUpdates.ps1`<br>`scripts/Builder/Get-WindowsUpdates.cmd` | Catálogo oficial Microsoft Update, resolución de SSU/LCU y Checkpoints KB5043080 para Windows 11 24H2/25H2. |
| **17** | **Gestión Integral de Drivers** | `scripts/Drivers/Backup-HardwareDrivers.ps1`<br>`scripts/Drivers/Clean-DriverStore.ps1`<br>`scripts/Drivers/Get-CriticalDrivers.ps1` | `Export-WindowsDriver`, depuración de FileRepository mediante `pnputil.exe` y obtención de Intel VMD / VirtIO. |
| **18** | **Migración de Perfil de Usuario** | `scripts/Modules/Migrar-Usuario-W11.ps1` | Exportación e importación segura de AppData Local/Roaming, colmena de registro `NTUSER.DAT` y privilegios ACLs. |

---

## 4. Protocolo de Ejecución Interactiva y Espera de Órdenes

En estricto cumplimiento de la **Regla 8 (Prohibición de Auto-Run)**:
1. **Un Paso a la Vez:** Cada herramienta se someterá al análisis forense de forma individual.
2. **Entrega de la Ficha Técnica:** Se presentará la ficha completa de 5 dimensiones con sus hallazgos, fuentes oficiales y métricas.
3. **Parada Obligatoria:** Tras presentar el análisis de la herramienta actual, el agente se detendrá inmediatamente y esperará la confirmación u observaciones del usuario antes de pasar a la siguiente.
4. **Cero Ediciones Prematuras:** Si se detecta que una función requiere modernización o purga, se registrará el hallazgo técnico en el plan y solo se aplicará la corrección si el usuario así lo autoriza expresamente.
