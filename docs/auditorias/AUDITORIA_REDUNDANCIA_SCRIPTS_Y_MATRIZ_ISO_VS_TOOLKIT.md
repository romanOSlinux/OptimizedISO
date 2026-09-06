# Auditoría Técnica Transversal de Redundancias y Matriz de Decisión ISO vs. Toolkit

**Fecha:** 2026-09-05  
**Autor:** Antigravity AI / Pair-Programming  
**Plan Asociado:** [PLAN-0025](../../docs/plans/PLAN-0025-20260905-deep-audit-script-redundancy-and-iso-vs-toolkit-matrix.md)  
**Estado:** AUDITORÍA COMPLETADA — ESPERANDO REVISIÓN DEL USUARIO (CERO CAMBIOS DE CÓDIGO)  
**Entorno de Referencia:** Windows 11 24H2 / 25H2 (Builds 26100+)  

---

## 1. Contexto y Fundamento Arquitectónico

### 1.1 El Paradigma Dual de Usuarios y Escenarios
El proyecto *OptimizedISO* / *romanOS* debe atender con excelencia dos perfiles de uso complementarios y deliberados:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             ECOSISTEMA romanOS                              │
├──────────────────────────────────────┬──────────────────────────────────────┤
│ ESCENARIO A: USUARIO DE LA ISO       │ ESCENARIO B: USUARIO DE WINDOWS      │
│ PERSONALIZADA                        │ GENÉRICO / STOCK (TOOLKIT)           │
│                                      │                                      │
│ • Genera o instala la ISO romanOS.   │ • Tiene Windows 11 preinstalado OEM  │
│ • Requiere una experiencia "Zero     │   o instalado desde el medio oficial.│
│   Touch": el sistema arranca listo,  │ • NO utilizó el generador de ISOs.   │
│   con bypasses, temas oscuros y      │ • Descarga el Toolkit y sus módulos  │
│   baseline universal ya inyectado.   │   para optimizar su sistema actual.  │
│                                      │                                      │
│ ➜ LA ISO DEBE SER AUTÓNOMA Y LISTA.  │ ➜ EL TOOLKIT DEBE TENER TODAS LAS    │
│                                      │   OPCIONES DISPONIBLES Y AUTÓNOMAS.  │
└──────────────────────────────────────┴──────────────────────────────────────┘
```

### 1.2 La Regla de Oro: Coexistencia Funcional vs. Redundancia Patológica
- **Coexistencia Funcional (Deseada y Necesaria):** Que una optimización exista en la ISO y **TAMBIÉN** exista en el Toolkit **no es un error**. El Toolkit no puede ser mutilado simplemente porque "la ISO ya lo hace", ya que dejaría al usuario del Escenario B sin esa herramienta.
- **Redundancia Patológica (Lo que debemos erradicar):**
  1. **Divergencia de Implementación:** La ISO aplica una variante obsoleta (ej. menú contextual plano y oculto tras `Shift+F10` en `SetupComplete.cmd`), mientras que el Toolkit aplica una versión moderna en cascada con menú clásico de 1 solo clic. Si un usuario de la ISO ejecuta el Toolkit, las claves colisionan o quedan huérfanas en el registro.
  2. **Falta de Idempotencia:** El Toolkit debe detectar si una optimización ya fue aplicada por la ISO (`SetupComplete` / WIM) y mostrarla como `[ACTIVO]` sin reescribir ni duplicar entradas innecesariamente.
  3. **Fragmentación de Código (*Copy-Paste*):** El mismo bloque de código (ej. limpiar shaders o vaciar DNS) escrito a mano en 3 scripts distintos en lugar de consumir un módulo compartido o una función centralizada.
  4. **Tweaks Placebo o Frágiles:** Ajustes sin sustento en Microsoft Learn que deben eliminarse tanto de la ISO como del Toolkit.

---

## 2. Inventario y Auditoría Script por Script (13 Componentes)

| # | Componente | Momento de Ejecución | Qué Aplica Realmente | Dónde Escribe / Modifica | Riesgos y Dependencias Críticas |
|---|---|---|---|---|---|
| **1** | `New-OptimizedWindowsISO-v2.ps1` | Tiempo de compilación (Host) | • Inyección offline en WIM (Modo Oscuro, LaunchTo, HideFileExt, TaskbarAl, ContentDeliveryManager).<br>• Genera `SetupComplete.cmd`.<br>• Genera `autounattend.xml`.<br>• Inyecta runtimes y scripts auxiliares en `$OEM$`. | • WIM `Users\Default\NTUSER.DAT`.<br>• `$OEM$\$$\Setup\Scripts`.<br>• Raíz ISO (`autounattend.xml`). | No tiene drivers de GPU ni monitor activos durante el montaje WIM. No puede aplicar tweaks dependientes de hardware en el WIM. |
| **2** | `SetupComplete.cmd` (Plantilla generada por el compilador ISO) | Primer arranque (Pre-logon, `NT AUTHORITY\SYSTEM`) | • Deshabilita 6 tareas de telemetría.<br>• Instala Runtimes VC++ y DirectX silenciosamente.<br>• Inyecta **6 menús contextuales planos**.<br>• Aplica directivas GPO de navegadores (Edge, Chrome, Firefox, Brave) y Copilot.<br>• Configura Plan de Energía (Ultimate Performance).<br>• Servicios (según Perfil 2 o 3).<br>• Ejecuta `PostInstall-Diagnostics.ps1`. | • `HKLM\SOFTWARE\Classes` (menús planos).<br>• `HKLM\SOFTWARE\Policies` (GPO navegadores).<br>• Servicios (`sc.exe config`).<br>• Tareas programadas (`schtasks`). | **Conflicto con Add-OptimizedContextMenus.ps1:** Escribe entradas planas sin `InprocServer32`, quedando ocultas tras Shift+F10. |
| **3** | `Win11-Debloat-v3-Adaptive.ps1` | Post-instalación interactiva o desatendida | • 17 secciones completas:<br>  0. Prerrequisitos y Winget.<br>  1. Eliminación AppX.<br>  2. Eliminación Win32 (OneDrive, Teams, Skype).<br>  3-5. Personalización visual, barra y explorador.<br>  6-8. Privacidad, background apps y servicios.<br>  11-12. Hardware adaptativo y Gaming (HAGS, SwapEffect, Nagle, MSI Mode).<br>  13-14. MMAgent y DISM cleanup.<br>  15. Menú contextual (invoca `Add-OptimizedContextMenus.ps1`).<br>  16. Navegadores GPO.<br>  17. Restart Explorer. | • `HKCU` y `HKLM`.<br>• Servicios de Windows.<br>• Paquetes Appx.<br>• Adaptadores de red (Nagle).<br>• GPU PCI Registry (MSI Mode). | Duplica la sección de navegadores (Sec. 16) y la de red/Nagle respecto a scripts dedicados. |
| **4** | `romanOS-Toolkit.ps1` | Hub On-Demand para usuario (Escenarios A y B) | • Orquestador interactivo.<br>• Lanzador de módulos: Gaming, Network, Maintenance, Diagnostics, Security, Dashboards, QuickActions, Browsers, Updates, ContextMenu.<br>• Menú `QuickActions` (11 acciones rápidas). | Delega en scripts hermanos o ejecuta comandos directos (`ipconfig`, `taskkill explorer`, `shell:::GodMode`, shaders, TRIM). | Las QuickActions 5 (Shaders) y 6 (TRIM) tienen código repetido inline en vez de llamar a `Invoke-WindowsMaintenance.ps1`. |
| **5** | `Core/Policy-Engine.ps1` | Catálogo Maestro Centralizado (SSOT) | • Define 33 directivas oficiales (Widgets, Bing, Copilot, Recall, ReservedStorage, DeliveryOptimization, Telemetry, DriverExclusion, WPBT, BitLocker, BypassNRO, MMCSS, HAGS).<br>• Exporta comandos a `autounattend.xml`.<br>• Valida cumplimiento en auditoría. | Fuente de verdad en memoria / exportación XML. | **Falta catalogar:** No contiene aún las políticas de navegadores ni los servicios ni el menú contextual. |
| **6** | `Core/Hardware-Engine.ps1` | Motor de Detección de Hardware en vivo | • Detección profunda de CPU, GPU, RAM (canales single/dual), Discos (NVMe vs SATA), Batería (Laptop vs Desktop).<br>• Verificación de soporte de HAGS (WDDM 2.7+).<br>• Habilitación segura de GPU MSI Mode. | Consulta WMI / CIM / PCI Bus. Modifica claves de driver GPU para MSI Mode. | Requiere sistema live con drivers cargados. Imposible de ejecutar en WIM offline. |
| **7** | `Core/UI-Engine.ps1` | Motor Visual Compartido | • Banners, menús unificados, prompts S/N, encabezados de pasos y resúmenes de auditoría. | Consola / PowerShell Host. | Desacoplado 100% limpio. Sin lógica de registro ni estado de sistema. |
| **8** | `Add-OptimizedContextMenus.ps1` | Especialista en Menús Contextuales | • 3 submenús en cascada: *Herramientas Gamer*, *Herramientas del Sistema*, *Opciones de Energía UEFI*.<br>• 3 accesos directos: *Tomar Propiedad*, *Bloquear en Firewall*, *Copiar Hash SHA-256*.<br>• Restauración de Menú Clásico de 1 solo clic (`InprocServer32`). | `HKLM\SOFTWARE\Classes` y `HKCU\Software\Classes\CLSID\{86ca1aa0...}`. | **Es la implementación superior y canónica.** No debe coexistir con las claves planas de `SetupComplete.cmd`. |
| **9** | `Invoke-WindowsMaintenance.ps1` | Mantenimiento Profundo y Reparación | • Saneamiento de residuos de despliegue (`$WINDOWS.~BT`, `Windows.old`, `Panther`).<br>• WinSxS `StartComponentCleanup` y purga de Windows Update.<br>• Residuos de debloat AppX.<br>• Limpieza de Caches GPU Shaders (DirectX, NVIDIA, AMD).<br>• Reparación DISM + SFC.<br>• SSD TRIM (`Optimize-Volume -ReTrim`). | Sistema de archivos, colmenas de componentes y volúmenes de disco. | Completo y autónomo. El Toolkit debe invocarlo en vez de duplicar comandos sueltos. |
| **10** | `Invoke-WindowsSecurityHardening.ps1` | Auditoría y Hardening de Seguridad | • Secure Boot, TPM 2.0, VBS / HVCI.<br>• Bloqueo WPBT (inyección bloatware OEM en BIOS).<br>• Desactivación de SMBv1 y LLMNR.<br>• NTLMv2 forzado.<br>• LSA Protection (`RunAsPPL`).<br>• Defender Attack Surface Reduction (ASR) amigables con gaming. | Registro de seguridad (`Lsa`, `Netlogon`, `Parameters`, `MpEngine`). | No altera anti-cheats ni rendimiento gráfico. Ideal para ejecución standalone o tras debloat. |
| **11** | `Win11-Network-Diagnostics-Optimizer.ps1` | Especialista en Red, Latencia y TCP | • Diagnóstico de interfaces de red.<br>• TCP Stack: AutoTuning Normal (MS Learn), Heuristics OFF, CUBIC, FastOpen, Timestamps OFF.<br>• Gaming: Network Throttling OFF, System Responsiveness 100%, QoS Uncap, Nagle Algorithm OFF.<br>• Drivers NIC (NDIS): RSS, EEE/Green Ethernet OFF, RSC OFF, Interrupt Moderation OFF.<br>• Reset de Winsock y FlushDNS. | `HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters` y adaptadores de red netsh/NDIS. | Debe ser el único script que maneje adaptadores de red. `Debloat` debe delegar en él. |
| **12** | `Get-EssentialRuntimes.ps1` | Gestor Oficial de Runtimes | • Descarga directa desde CDN oficial de Microsoft con verificación SHA-256 de VC++ (2008 a 2022) y DirectX 9.0c End-User Runtimes. | Almacena instaladores en `scripts\Runtimes\`. | Alimenta a la ISO para instalación offline en `SetupComplete.cmd`. |
| **13** | `Get-WindowsUpdates.ps1` | Servicing de Actualizaciones Oficiales | • Consulta en tiempo real y descarga de parches oficiales Microsoft (SSU, LCU, .NET, SafeOS) con validación Authenticode. | Almacena parches en `Updates\`. | Alimenta el slipstream offline de DISM en `New-OptimizedWindowsISO-v2.ps1`. |

---

## 3. Matriz de Solapamientos Transversales (Las 6 Áreas Críticas)

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                MAPA DE SOLAPAMIENTOS ENTRE COMPONENTES                                 │
├───────────────────┬──────────────────┬─────────────────┬───────────────────┬───────────────────────────┤
│ ÁREA FUNCIONAL    │ ISO (WIM / CMD)  │ DEBLOAT (V3)    │ TOOLKIT (HUB)     │ MÓDULO ESPECIALIZADO      │
├───────────────────┼──────────────────┼─────────────────┼───────────────────┼───────────────────────────┤
│ 1. Menú           │ SetupComplete:   │ Sección 15:     │ QuickAction 11 &  │ Add-OptimizedContextMenus │
│    Contextual     │ 6 claves planas  │ Invoca al       │ Módulo ContextMenu│ Suite completa en cascada │
│                   │ ocultas (Shift)  │ módulo          │ Invoca al módulo  │ + Menú clásico 1 clic     │
│                   │ ⚠️ DIVERGENCIA   │                 │                   │                           │
├───────────────────┼──────────────────┼─────────────────┼───────────────────┼───────────────────────────┤
│ 2. Navegadores    │ SetupComplete:   │ Sección 16:     │ QuickAction 7 &   │ NO EXISTE MÓDULO AISLADO  │
│    Web (GPO)      │ 60+ claves reg   │ 60+ claves reg  │ Módulo Browsers:  │ Código duplicado por      │
│                   │ hardcodeadas     │ duplicadas      │ Llama a Debloat   │ copy-paste en 2 scripts   │
├───────────────────┼──────────────────┼─────────────────┼───────────────────┼───────────────────────────┤
│ 3. Tareas y       │ SetupComplete:   │ Sección 8:      │ No duplica        │ Invoke-WindowsSecurity    │
│    Telemetría     │ 6 tareas schtasks│ Disable-Task    │                   │ Hardening (audita)        │
│                   │ ✅ Idempotente   │ ampliado        │                   │                           │
├───────────────────┼──────────────────┼─────────────────┼───────────────────┼───────────────────────────┤
│ 4. Red, DNS       │ SetupComplete:   │ Sección 11/12:  │ QuickAction 1:    │ Win11-Network-Diagnostics │
│    y Latencia     │ FlushDNS plano   │ Nagle + Throttl │ FlushDNS inline   │ Suite completa de TCP,    │
│                   │                  │ duplicado       │                   │ NDIS, DNS y adaptadores   │
├───────────────────┼──────────────────┼─────────────────┼───────────────────┼───────────────────────────┤
│ 5. GPU Shaders    │ No aplica        │ No aplica       │ QuickAction 5:    │ Invoke-WindowsMaintenance │
│    y SSD TRIM     │                  │                 │ Get-ChildItem     │ Sección 4 y 6 completas   │
│                   │                  │                 │ inline duplicado  │ con manejo y reportes     │
├───────────────────┼──────────────────┼─────────────────┼───────────────────┼───────────────────────────┤
│ 6. Diagnóstico y  │ SetupComplete:   │ No aplica       │ Módulo Diag /     │ PostInstall-Diagnostics   │
│    Auditoría      │ Corre Diag       │                 │ Dashboards        │ Genera HTML en Desktop    │
└───────────────────┴──────────────────┴─────────────────┴───────────────────┴───────────────────────────┘
```

---

## 4. Matriz de Decisión Técnica: ¿ISO vs. Toolkit? (Ganancias vs. Pérdidas)

Respaldada en fuentes oficiales de Microsoft:
- **Microsoft Learn:** [Windows Deployment Architecture & Passes](https://learn.microsoft.com/windows-hardware/manufacture/desktop/windows-setup-configuration-passes)
- **Microsoft Learn:** [Edge Enterprise Policy Reference](https://learn.microsoft.com/deployedge/microsoft-edge-policies)
- **Microsoft Learn:** [TCP/IP Tuning & Netsh Technical Reference](https://learn.microsoft.com/windows-server/networking/technologies/network-subsystem/net-sub-performance-tuning)
- **Windows Hardware Dev Center:** [Hardware-Accelerated GPU Scheduling (WDDM 2.7+)](https://learn.microsoft.com/windows-hardware/drivers/display/hardware-accelerated-gpu-scheduling)

---

### Categoría 1: Tweaks Universales del Shell y Apariencia (Modo Oscuro, Extensiones, Taskbar)
* **Ajustes:** `AppsUseLightTheme=0`, `SystemUsesLightTheme=0`, `HideFileExt=0`, `LaunchTo=1`, `TaskbarAl=0`.
* **Fuentes Oficiales:** Microsoft Learn (Shell CSP & Personalization Policy).
* **¿Qué ganas en la ISO (WIM Offline NTUSER.DAT)?**
  - **Experiencia 100% Nativa:** El usuario entra al escritorio con el fondo oscuro, extensiones visibles y explorador configurado sin parpadeos, sin reiniciar el explorador y sin scripts post-instalación.
* **¿Qué pierdes en la ISO?**
  - Nada. Son configuraciones universales de registro que no dependen de la GPU, monitor ni hardware.
* **¿Qué ganas en el Toolkit?**
  - El usuario de Windows Stock (Escenario B) puede aplicarlas con un clic.
* **¿Qué pierdes en el Toolkit?**
  - Requiere reiniciar el proceso `explorer.exe` en vivo para que surtan efecto.
* **Veredicto:** **NIVEL 1 (ISO WIM Offline) Y NIVEL 3 (Toolkit Standalone).** Mantener en ambos con garantía de idempotencia.

---

### Categoría 2: Menús Contextuales Avanzados (Gamer, Take Ownership, Herramientas)
* **Ajustes:** Cascadas `GamerTools`, `SystemTools`, `PowerOptions UEFI`, `TakeOwnership`, `BlockInFirewall`, Menú clásico (`{86ca1aa0...}`).
* **Fuentes Oficiales:** Microsoft Learn: [Extending Shortcut Menus](https://learn.microsoft.com/windows/win32/shell/context-menu-handlers).
* **¿Qué ganas en la ISO (`SetupComplete.cmd`)?**
  - Si se aplica correctamente, el usuario tiene la suite lista al primer encendido.
  - **PROBLEMA ACTUAL:** `SetupComplete.cmd` hoy inyecta 6 comandos planos y obsoletos (`PSAdmin`, `RestartExplorer`, etc.) que quedan ocultos tras *Shift+F10* y colisionan con el Toolkit.
* **¿Qué pierdes en la ISO?**
  - Si el usuario prefiere el menú moderno original de Windows 11, queda forzado al clásico desde el inicio a menos que use el Toolkit para revertirlo.
* **¿Qué ganas en el Toolkit (`Add-OptimizedContextMenus.ps1`)?**
  - Control granular absoluto: menú interactivo para alternar entre clásico (1 clic, 0 ms) o moderno, desinstalar limpiamente o elegir solo ciertas cascadas.
  - 100% útil para usuarios de Windows genérico.
* **Veredicto Técnico:**
  - **ELIMINAR las 6 claves planas obsoletas de `SetupComplete.cmd`.**
  - En la ISO, invocar directamente `Add-OptimizedContextMenus.ps1 -Apply` (o mediante un RunOnce de primer usuario) para que la ISO tenga **exactamente la misma suite** que el Toolkit, sin discrepancias.

---

### Categoría 3: Políticas GPO de Navegadores Web (Edge, Chrome, Firefox, Brave)
* **Ajustes:** Aceleración por hardware forzada, límite de memoria RAM (Sleeping Tabs / Memory Saver), eliminación de telemetría, desactivación de compras/bloatware, desactivación de asistentes IA innecesarios, límite de caché de disco a 256 MB.
* **Fuentes Oficiales:** Microsoft Edge Enterprise Policy Reference, Chrome Enterprise Policy List, Mozilla Policy Templates.
* **¿Qué ganas en la ISO (`SetupComplete.cmd`)?**
  - **Inmunidad Preventiva:** Cuando el usuario descargue o abra Edge, Chrome o Firefox por primera vez, el navegador ya respetará los límites de RAM y GPU sin consumir recursos en segundo plano (`StartupBoost=0`, `BackgroundMode=0`).
* **¿Qué pierdes en la ISO?**
  - Requiere mantener sincronizadas las claves de directiva con las versiones actuales de los navegadores.
* **¿Qué ganas en el Toolkit?**
  - Un usuario de Windows común que sufre ralentizaciones en Chrome o Edge puede ejecutar el módulo `Browsers` y solucionar el consumo de RAM de inmediato.
* **Veredicto Técnico:**
  - **NIVEL 2 (SetupComplete.cmd) Y NIVEL 3 (Toolkit On-Demand).**
  - **ACCIÓN DE INGENIERÍA REQUERIDA:** Centralizar el catálogo de directivas de navegadores en `Core/Policy-Engine.ps1` (crear `$global:RomanOS_BrowserPolicies`). Eliminar el código hardcodeado por duplicación en `Debloat` y `SetupComplete.cmd`. Ambos deben consumir el motor central.

---

### Categoría 4: Tweaks de Red y Pila TCP
* **Ajustes:** TCP AutoTuning Normal, Heuristics Disabled, Congestion CUBIC, Nagle Algorithm (`TcpNoDelay=1`, `TcpAckFrequency=1`), NetworkThrottlingIndex `0xFFFFFFFF`, SystemResponsiveness `0`.
* **Fuentes Oficiales:** Microsoft Learn: TCP/IP Subsystem Performance Tuning.
* **¿Qué ganas en la ISO?**
  - Los ajustes globales de sistema (`NetworkThrottlingIndex`, `SystemResponsiveness`, TCP Global AutoTuning) se aplican limpiamente en `specialize` o `SetupComplete.cmd`.
* **¿Qué pierdes si intentas configurar adaptadores en la ISO (WIM Offline)?**
  - **RIESGO DE FALLO / IMPOSIBLE:** En una imagen offline WIM, los adaptadores de red reales de la máquina (Intel Wi-Fi, Realtek Ethernet, etc.) **no existen**. Sus GUIDs en el registro no han sido generados. Intentar aplicar Nagle o ajustes NDIS en offline es estéril o generará claves erróneas.
* **¿Qué ganas en el Toolkit (`Win11-Network-Diagnostics-Optimizer.ps1`)?**
  - Detección en vivo de la tarjeta de red activa por hardware. Aplica Nagle en el GUID exacto conectado a internet. Permite calibrar MTU y desactivar ahorro de energía en el chip Ethernet real.
* **Veredicto Técnico:**
  - **Ajustes Globales de Registro:** En la ISO vía `Policy-Engine.ps1` / `SetupComplete.cmd`.
  - **Ajustes por Adaptador (Nagle, NDIS, MTU, DNS):** Exclusivamente en **NIVEL 3 (Toolkit On-Demand / Win11-Network-Diagnostics-Optimizer.ps1)**.
  - En `Win11-Debloat-v3-Adaptive.ps1`: Eliminar la lógica duplicada de búsqueda de adaptadores de red y hacer que invoque a `Win11-Network-Diagnostics-Optimizer.ps1`.

---

### Categoría 5: Optimizaciones de GPU, Pantalla y Latencia (HAGS, MSI Mode, SwapEffect)
* **Ajustes:** HAGS (`HwSchMode=2`), SwapEffectUpgradeEnable=1 (Ventana sin bordes), GPU MSI Mode (`MSISupported=1`).
* **Fuentes Oficiales:** Windows Hardware Dev Center (WDDM 2.7 Specification, Message Signaled-Based Interrupts).
* **¿Qué ganas en la ISO (Offline)?**
  - Nada. Es **peligroso e inviable**.
* **¿Qué pierdes si fuerzas HAGS o MSI Mode en la ISO?**
  - **RIESGO CRÍTICO DE BSOD / PANTALLA NEGRA:** Si compilas la ISO forzando HAGS o MSI Mode y la máquina de destino tiene una GPU antigua (driver WDDM < 2.7) o una controladora que no soporta MSI, Windows puede fallar al inicializar el driver gráfico durante OOBE.
* **¿Qué ganas en el Toolkit (`Hardware-Engine.ps1` / `Debloat`)?**
  - **Inteligencia y Seguridad:** El script consulta el driver activo de la GPU real. Si detecta WDDM >= 2.7 y GPU compatible (NVIDIA Pascal+, AMD RDNA+, Intel Arc), habilita HAGS con total seguridad. Lo mismo para MSI Mode mediante el PNPDeviceID real.
* **Veredicto Técnico:**
  - **NIVEL 3 EXCLUSIVO (Toolkit On-Demand / Hardware-Engine).** PROHIBIDO en WIM offline.

---

### Categoría 6: Mantenimiento, Limpieza de Shaders y SSD TRIM
* **Ajustes:** Purga de `$env:LOCALAPPDATA\D3DSCache`, `NVIDIA\DXCache`, `AMD\DxCache`, `Optimize-Volume -ReTrim`, WinSxS Cleanup.
* **Fuentes Oficiales:** Microsoft Learn: Storage Management Cmdlets (`Optimize-Volume`), Component Store Servicing (`DISM /Cleanup-Image`).
* **¿Qué ganas en la ISO?**
  - En el WIM offline ya se ejecuta `DISM /StartComponentCleanup /ResetBase` durante la compilación, dejando la imagen ultra reducida.
* **¿Qué ganas en el Toolkit?**
  - Es una herramienta de mantenimiento continuo (semanal o mensual) vital para gamers que actualizan drivers gráficos (evita corrupción de shaders tras update de NVIDIA/AMD).
* **Veredicto Técnico:**
  - **NIVEL 3 (Toolkit On-Demand / Invoke-WindowsMaintenance.ps1).**
  - **ACCIÓN DE INGENIERÍA:** En `romanOS-Toolkit.ps1`, las opciones 5 y 6 de `QuickActions` no deben tener scripts inline con `Get-ChildItem`; deben invocar directamente a `Invoke-WindowsMaintenance.ps1 -ShadersOnly` y `-TrimOnly`.

---

## 5. Taxonomía Definitiva de Clasificación Cuádruple

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    TAXONOMÍA DE ASIGNACIÓN ARQUITECTÓNICA                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│ NIVEL 1: ISO / WIM OFFLINE (Universales, Sin Riesgo OOBE, Independientes de HW) │
│ • Layout UEFI GPT y Bypasses de Setup (autounattend.xml / LabConfig).           │
│ • Modo Oscuro nativo y personalización de explorador (Default NTUSER.DAT).      │
│ • Bloqueo de ContentDeliveryManager (anti bloatware en la nube).                │
│ • Directivas de privacidad y telemetría globales (Policy-Engine.ps1).           │
│ • Integración de actualizaciones oficiales DISM (Get-WindowsUpdates.ps1).       │
├─────────────────────────────────────────────────────────────────────────────────┤
│ NIVEL 2: SETUPCOMPLETE.CMD (Configuraciones de Máquina Pre-Logon)               │
│ • Deshabilitar tareas programadas de telemetría pesada (Appraiser).             │
│ • Instalación silenciosa de Runtimes offline (VC++ y DirectX).                  │
│ • Aplicación de directivas GPO de navegadores (Edge, Chrome, Firefox, Brave).   │
│ • Invocación de Add-OptimizedContextMenus.ps1 (Suite moderna en cascada).       │
│ • Configuración de Plan de Energía (Powercfg).                                  │
│ • Invocación de PostInstall-Diagnostics.ps1 para reporte inicial.               │
├─────────────────────────────────────────────────────────────────────────────────┤
│ NIVEL 3: TOOLKIT STANDALONE / ON-DEMAND (Adaptable a HW, Reversible, Portable) │
│ • Introspección y detección inteligente de hardware (Hardware-Engine.ps1).     │
│ • HAGS adaptativo por versión WDDM y GPU MSI Mode por PNPDeviceID.              │
│ • Optimización de interfaces de red y Nagle por adaptador activo.               │
│ • Mantenimiento periódico (Shaders GPU, SSD TRIM, WinSxS vivo).                 │
│ • Suite interactiva de Menú Contextual (alternar entre clásico y moderno).      │
│ • Eliminación de Bloatware AppX y Win32 (OneDrive, Teams) interactiva.          │
│ • Auditoría y Hardening de Seguridad (ASR, Defender, VBS toggle).               │
├─────────────────────────────────────────────────────────────────────────────────┤
│ NIVEL 4: ELIMINACIÓN / DEPURACIÓN (Duplicidades, Inconsistencias y Placebos)   │
│ ❌ ELIMINAR: 6 claves planas obsoletas en SetupComplete.cmd (L3956-3985).       │
│ ❌ ELIMINAR: Código inline de shaders y TRIM en QuickActions de romanOS-Toolkit.│
│ ❌ ELIMINAR: Código duplicado de red/Nagle en Win11-Debloat-v3-Adaptive.ps1.   │
│ ❌ ELIMINAR: Definición hardcodeada de directivas de navegadores en 2 archivos. │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Hoja de Ruta de Refactorización Recomendada (Propuesta para Debate)

Una vez que revises y apruebes este informe, los pasos de código propuestos son:

1. **Paso 1: Sincronización Canónica del Menú Contextual:**
   - Retirar las 6 claves planas de `SetupComplete.cmd` en `New-OptimizedWindowsISO-v2.ps1`.
   - Reemplazarlas por la invocación directa a `Add-OptimizedContextMenus.ps1 -Apply -EnableClassicMenu` dentro de `SetupComplete.cmd` o durante el primer logon del usuario.
2. **Paso 2: Centralización de Navegadores en `Policy-Engine.ps1`:**
   - Incorporar el catálogo de directivas de Edge, Chrome, Firefox y Brave en `Core/Policy-Engine.ps1`.
   - Hacer que `SetupComplete.cmd` y `Win11-Debloat-v3-Adaptive.ps1` consuman este catálogo sin duplicar strings.
3. **Paso 3: Limpieza de QuickActions en `romanOS-Toolkit.ps1`:**
   - Hacer que las acciones de shaders y TRIM deleguen en `Invoke-WindowsMaintenance.ps1`.
   - Hacer que la acción de DNS y red delegue limpiamente en `Win11-Network-Diagnostics-Optimizer.ps1`.
4. **Paso 4: Garantía de Idempotencia:**
   - Asegurar que al ejecutar el Toolkit en un sistema romanOS (instalado desde la ISO), el Toolkit detecte automáticamente que el menú contextual, las políticas de navegadores y el debloat base ya están activos, mostrando etiquetas de estado verde `[APLICADO DE FÁBRICA]`.

---

**Fin del Informe Técnico de Auditoría.**  
*Queda prohibida cualquier modificación de código hasta la instrucción expresa del usuario.*
