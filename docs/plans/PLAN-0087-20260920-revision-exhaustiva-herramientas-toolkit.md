# PLAN-0087: Auditoría y Revisión Exhaustiva 1 a 1 de las Herramientas del Toolkit Maestro romanOS

**Estado:** `PENDIENTE`  
**Fecha:** 2026-09-20  
**Autor:** Antigravity AI Pair Programmer & romanOS Team  
**Rama:** `feature/offline-ui-tweaks`  

---

## 1. Resumen Ejecutivo y Objetivo

El ecosistema **romanOS Toolkit** es el centro neurálgico de administración, optimización extrema para gaming/streaming, mantenimiento profundo, auditoría de seguridad y observabilidad de hardware de la ISO optimizada y del sistema instalado. Opera bajo la filosofía innegociable de **Zero-Resident Footprint** (cero servicios en segundo plano ni tareas residentes que penalicen los frametimes o ciclos de CPU).

El presente plan establece la **metodología y hoja de ruta estructurada para revisar y auditar 1 por 1 cada herramienta del Toolkit**, evaluando:
1. **Integridad sintáctica y runtime:** Compatibilidad estricta con Windows PowerShell 5.1 (`powershell.exe`) y PowerShell 7+ (`pwsh`), codificación UTF-8 con BOM en scripts `.ps1` y ausencia de BOM en archivos `.cmd`.
2. **Alineación con SSOT (`Core\Policy-Engine.ps1` y `Core\Hardware-Engine.ps1`):** Erradicación de directivas duplicadas o cadenas quemadas (*hardcoded*).
3. **Manejo de errores y resiliencia:** Elevación UAC transparente, ejecución no interactiva/desatendida (`-Unattended`), soporte gráfico STA y retorno de códigos de salida (`exit /b`, `$LASTEXITCODE`).
4. **Paridad con la GUI:** Verificación de que cada herramienta esté correctamente cableada y accesible tanto desde la interfaz gráfica nativa WPF (`romanOS Control Center` / `romanOS Studio`) como desde la CLI y el menú interactivo del Hub Maestro.
5. **Calidad y Trazabilidad:** Ausencia de dependencias fantasma, preservación de compatibilidad con anti-cheats (Vanguard, EAC, BattlEye, FACEIT) y estabilidad de componentes críticos del sistema operativo.

---

## 2. Inventario Completo de Herramientas a Auditar (1 a 1)

| Orden | Módulo / Herramienta | Archivos Principales | Propósito Clave |
| :---: | :--- | :--- | :--- |
| **01** | **Hub Orquestador CLI** | `scripts/Modules/romanOS-Toolkit.ps1`<br>`Lanzar-romanOS-Toolkit.cmd`<br>`scripts/Modules/romanOS-Toolkit.cmd` | Orquestador unificado bajo demanda, menú interactivo y despachador de parámetros CLI. |
| **02** | **romanOS Control Center (GUI WPF)** | `scripts/GUI/romanOS-ControlCenter.ps1`<br>`Lanzar-romanOS-ControlCenter.cmd`<br>`scripts/GUI/romanOS-ControlCenter-Launcher.cs` | Interfaz gráfica nativa Dark Mode, telemetría CPU/RAM en vivo y streaming de consola a 60 FPS. |
| **03** | **Optimización Gaming & Debloat** | `scripts/Modules/Win11-Debloat-v3-Adaptive.ps1`<br>`scripts/Modules/Win11-Debloat-v3-Adaptive.cmd` | Debloat adaptativo por hardware, HAGS, Game Mode, MMCSS, DirectStorage y políticas de rendimiento. |
| **04** | **Diagnóstico de Red & Latencia** | `scripts/Modules/Win11-Network-Diagnostics-Optimizer.ps1`<br>`scripts/Modules/Win11-Network-Diagnostics-Optimizer.cmd` | Benchmarks DNS en vivo, tuning TCP/IP (CTCP/BBR, No-Delay), MTU, sockets Winsock y vaciado DNS. |
| **05** | **Mantenimiento & Limpieza Profunda** | `scripts/Modules/Invoke-WindowsMaintenance.ps1`<br>`scripts/Modules/Invoke-WindowsMaintenance.cmd` | Limpieza WinSxS ResetBase, purga de cachés Shaders (DirectX, NVIDIA, AMD), SSD TRIM y SFC/DISM. |
| **06** | **Auditoría Forense Post-Instalación** | `scripts/Modules/PostInstall-Diagnostics.ps1`<br>`scripts/Modules/Auditar-Instalacion.cmd` | Diagnóstico de salud post-despliegue, Panther logs, CompactOS, PnP y dashboards HTML/Markdown. |
| **07** | **Auditoría Forense de Huella (Footprint)** | `scripts/Modules/Audit-FreshInstallFootprint.ps1` | Medición científica de memoria en reposo, servicios activos y recuento de procesos en segundo plano. |
| **08** | **Auditoría de Seguridad & Hardening** | `scripts/Modules/Invoke-WindowsSecurityHardening.ps1`<br>`scripts/Modules/Invoke-WindowsSecurityHardening.cmd` | Auditoría desacoplada de ASR, VBS, RunAsPPL, mitigaciones de CPU y generación de dashboard HTML. |
| **09** | **Optimización de Navegadores Web** | `scripts/Modules/Optimize-WebBrowsers.ps1`<br>`scripts/Modules/Optimize-WebBrowsers.cmd` | Políticas para Edge, Chrome, Brave y Firefox: aceleración GPU, sleeping tabs, límite de caché y 0 bloat IA. |
| **10** | **Descargador de Windows Updates** | `scripts/Builder/Get-WindowsUpdates.ps1`<br>`scripts/Builder/Get-WindowsUpdates.cmd` | Consulta y descarga de parches oficiales Microsoft (SSU, LCU, Checkpoints) para slipstream offline. |
| **11** | **Gestión Integral de Drivers** | `scripts/Drivers/Backup-HardwareDrivers.ps1`<br>`scripts/Drivers/Clean-DriverStore.ps1`<br>`scripts/Drivers/Get-CriticalDrivers.ps1` | Respaldo de drivers del host (`Export-WindowsDriver`), limpieza del DriverStore y descarga de drivers críticos. |
| **12** | **Migración de Perfil de Usuario** | `scripts/Modules/Migrar-Usuario-W11.ps1` | Rescate, respaldo e importación de perfiles de usuario local (carpetas de datos y colmenas de usuario). |
| **13** | **Generador de Dashboards Visuales** | Función `Invoke-OpenDashboards` en `romanOS-Toolkit.ps1` | Generación y apertura sincronizada de tableros interactivos HTML de instalación y seguridad en el navegador. |
| **14** | **Poda Quirúrgica de Memoria RAM** | `scripts/Modules/Optimize-ProcessMemory.ps1`<br>`scripts/Modules/Optimize-ProcessMemory.cmd` | Poda inmediata de working sets (`psapi.dll EmptyWorkingSet`) de procesos pesados en reposo. |
| **15** | **Auditor Universal de Optimización** | `scripts/Modules/Audit-SystemOptimization.ps1` | Evaluación multi-hardware en 10 dominios técnicos, scoring 0-100 y motor de remediación asistida. |
| **16** | **Conmutador Modo Juego / Modo Dev** | `scripts/Modules/Switch-GameDevMode.ps1`<br>`scripts/Modules/Switch-GameDevMode.cmd` | Conmutador bimodal: congelación de WSL/Docker/Hyper-V para máxima VRAM/RAM en gaming o restauración para trabajo. |
| **17** | **Menús Contextuales Optimizados** | `scripts/Modules/Add-OptimizedContextMenus.ps1`<br>`scripts/Modules/Add-OptimizedContextMenus.cmd` | Gestión del menú contextual de 1 solo clic (0 ms), PowerShell Admin, God Mode, Take Ownership y reinicio a UEFI. |
| **18** | **Acciones Rápidas Express (Quick Actions)** | Función `Show-QuickActionsMenu` en `romanOS-Toolkit.ps1` | Atajos inmediatos: Flush DNS, Explorer restart, SFC + DISM, toggle Hipervisor bcdedit e introspección PCI-SIG. |

---

## 3. Protocolo de Ejecución de la Revisión (Paso a Paso)

Para cada una de las 18 herramientas, la revisión se ejecutará siguiendo este protocolo riguroso en 4 fases:

```
┌───────────────────────────┐
│ 1. Inspección Estática    │ ➔ Lectura de código, parámetros, encoding (BOM), sintaxis PS 5.1
└─────────────┬─────────────┘
              │
┌─────────────▼─────────────┐
│ 2. Prueba en Frío (WhatIf)│ ➔ & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass (Runtime real)
└─────────────┬─────────────┘
              │
┌─────────────▼─────────────┐
│ 3. Auditoría SSOT & GUI   │ ➔ Enlace con Core\Policy-Engine.ps1 y romanOS-ControlCenter.ps1
└─────────────┬─────────────┘
              │
┌─────────────▼─────────────┐
│ 4. Veredicto y Dictamen   │ ➔ Registro de hallazgos, estado (PASS / AJUSTES) y espera de orden
└───────────────────────────┘
```

1. **Fase 1 — Inspección Estática de Código:**
   - Análisis de parámetros CmdletBinding y validación de tipos.
   - Detección de rutas relativas frágiles o falta de búsqueda en fallback (`$searchDirs`).
   - Verificación de codificación UTF-8 con BOM en scripts de PowerShell y UTF-8 sin BOM en scripts `.cmd`.
2. **Fase 2 — Prueba en Frío en el Runtime de Destino (PowerShell 5.1):**
   - Ejecución de prueba con `-WhatIf`, `-CheckOnly`, o análisis AST en `powershell.exe` nativo de Windows.
   - Certificación de cero excepciones de parser o degradación de caracteres acentuados.
3. **Fase 3 — Auditoría de Integración SSOT y Paridad:**
   - Confirmar si la herramienta consume funciones canónicas de `Core\Hardware-Engine.ps1`, `Core\Policy-Engine.ps1` o `Core\UI-Engine.ps1`.
   - Verificar que esté correctamente expuesta tanto en el Menú CLI (`romanOS-Toolkit.ps1`) como en la interfaz gráfica (`romanOS-ControlCenter.ps1`).
4. **Fase 4 — Veredicto y Documentación:**
   - Emitir el dictamen técnico de la herramienta actual.
   - Si se detecta alguna discrepancia o mejora requerida, proponer la solución atómica.
   - **Esperar la confirmación del usuario para proceder a la siguiente herramienta.**

---

## 4. Criterios de Aceptación y Finalización

- [ ] Las 18 herramientas del Toolkit auditadas minuciosamente de forma secuencial.
- [ ] 100% de compatibilidad certificada con Windows PowerShell 5.1 (`powershell.exe`).
- [ ] Paridad total entre los lanzadores `.cmd`, los parámetros CLI y la GUI WPF (`romanOS Control Center`).
- [ ] Cero dependencias rotas, rutas huérfanas o directivas duplicadas fuera de la SSOT (`Policy-Engine.ps1`).
- [ ] Trazabilidad completa y actualización de documentación si se introducen mejoras.
