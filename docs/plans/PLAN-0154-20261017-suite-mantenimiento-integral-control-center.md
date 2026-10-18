# PLAN-0154: Suite Integral de Mantenimiento, Limpieza Profunda del Sistema Operativo y Salud en romanOS Control Center

**Fecha:** 2026-10-17  
**Estado:** COMPLETADO  
**Rama:** `feature/offline-ui-tweaks`  
**Autor:** Antigravity / romanOS Systems Engineering  
**Alcance:** `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/Modules/Invoke-WindowsMaintenance.ps1`, `scripts/Drivers/Clean-DriverStore.ps1`, `scripts/Testing/`

---

## 1. Contexto y Diagnóstico del Problema

La pestaña de **Mantenimiento** en `romanOS-ControlCenter.ps1` presentaba dos limitaciones críticas:
1. **Defecto de integración funcional y bloqueo en cascada:** Al hacer clic en *"Iniciar Saneamiento Seleccionado"*, la interfaz construía una cadena combinada de argumentos (`-DeepClean -ResetBase -ShadersOnly -TrimOnly -Unattended`). Sin embargo, en el backend `Invoke-WindowsMaintenance.ps1`, los modos estaban codificados en una estructura mutuamente excluyente de `if/elseif`. Dado que `-ShadersOnly` se evaluaba primero, el script abortaba silenciosamente la ejecución de WinSxS, TRIM y SFC, ejecutando únicamente el vaciado de shaders gráficos y terminando en pocos segundos sin procesar los componentes seleccionados por el usuario.
2. **Desconexión arquitectónica y diseño excesivamente básico:** 
   - El saneamiento de Shaders GPU (DirectX, Vulkan, NVIDIA, AMD, Intel) estaba ubicado incorrectamente en Mantenimiento en lugar de la pestaña dedicada **`Gaming & Rendimiento`**.
   - Mantenimiento carecía de telemetría de almacenamiento en tiempo real (capacidad de disco `C:`, espacio libre/usado, estado TRIM).
   - Módulos de alto calibre del ecosistema no estaban conectados o estaban dispersos:
     - Depuración segura del DriverStore (`Clean-DriverStore.ps1`), capaz de recuperar de 5 GB a 25 GB de drivers obsoletos en `System32\DriverStore\FileRepository`.
     - Auditoría previa de WinSxS (`DISM /AnalyzeComponentStore`), para saber si la limpieza es recomendada antes de esperar una operación de 10-15 minutos.
     - Limpieza de logs gigantes de CBS (`C:\Windows\Logs\CBS` y CABs huérfanos en `Windows\Temp`), documentada por Microsoft como causa de pérdidas masivas de espacio en disco.
     - Cachés de revocación de certificados caducados (`CryptnetUrlCache`) y residuos de paquetes desinstalados en `AppData\Local\Packages`.
     - Descargas de Windows Update (`SoftwareDistribution\Download`) y Delivery Optimization.

---

## 2. Decisiones de Ingeniería y Matriz de Pruebas (Fuentes Oficiales vs Mitos)

Con base en la documentación oficial de Microsoft (Microsoft Learn, Sysinternals de Mark Russinovich, KB2563254) y los estándares de la comunidad (BleachBit, Winapp2.ini, DriverStore Explorer):

### A. Lo que SÍ se integra:
1. **DriverStore Cleanup:** Depuración de controladores no activos mediante `pnputil.exe` o `Clean-DriverStore.ps1` (5–25 GB recuperables).
2. **WinSxS DISM con Análisis Previo:** `/AnalyzeComponentStore` para consulta inmediata y `/StartComponentCleanup` con opción `/ResetBase`.
3. **CBS Servicing Logs & Temp CABs:** Detención segura de `TrustedInstaller`, purga de logs antiguos y reanudación del servicio.
4. **Residuos de Despliegue y Setup:** `$WINDOWS.~BT`, `$WINDOWS.~WS`, `$SysReset`, `$WinREAgent`, `Panther`, `setupapi.log`.
5. **Windows Update & Delivery Optimization:** `SoftwareDistribution\Download` y `DeliveryOptimization\Cache`.
6. **Temporales y Crash Dumps:** `%TEMP%`, `Windows\Temp`, `MEMORY.DMP`, `Minidump`, colas WER de reportes de error.
7. **Cachés Seguras:** `CryptnetUrlCache`, caché de miniaturas (*Thumbnails*), y caché volátil de navegadores preservando logins/cookies.
8. **Salud del SO:** DISM `/RestoreHealth`, `sfc /scannow`, `winmgmt /salvagerepository`, `Repair-Volume -Scan`, precompilación .NET `ngen.exe`.
9. **SSD TRIM:** `Optimize-Volume -ReTrim` en unidades NVMe/SATA detectadas.

### B. Lo que ESTRICTAMENTE NO se integra (Mitos y Placebos):
1. **Limpiadores de Registro (KB2563254):** Descartado. Riesgo severo de corrupción de extensiones COM y fallos de arranque sin beneficio de rendimiento.
2. **Borrado de Prefetch (`C:\Windows\Prefetch`):** Descartado. Mark Russinovich demostró que ralentiza el arranque de apps y no ahorra espacio.
3. **Borrado de Cookies/Sesiones de Navegadores:** Descartado. Se protege la sesión del usuario.
4. **Shaders GPU en Mantenimiento:** Reubicado en la pestaña `Gaming & Rendimiento`.

---

## 3. Plan de Acción y Fases de Ejecución

### Fase 1: Refactorización y Ampliación Modular de `Invoke-WindowsMaintenance.ps1`
- Eliminar la cadena excluyente de `if/elseif`.
- Implementar parámetros aditivos y concurrentes:
  - `-IncludeDeployment`
  - `-IncludeWinSxS`
  - `-IncludeDriverStore`
  - `-IncludeCbsLogs`
  - `-IncludeWinUpdate`
  - `-IncludeWerDumps`
  - `-IncludeAppxOrphans`
  - `-IncludeTemp`
  - `-IncludeCryptNet`
  - `-IncludeBrowsers`
  - `-IncludeRepair`
  - `-IncludeTrim`
  - `-IncludeNgen`
  - `-AnalyzeWinSxS` (ejecuta `/AnalyzeComponentStore` y retorna diagnóstico)
- Preservar compatibilidad total con switches legacy (`-Full`, `-DeepClean`, `-ResetBase`, `-TrimOnly`, `-ShadersOnly`, `-RepairOnly`).

### Fase 2: Reubicación de Shaders de GPU a `Gaming & Rendimiento`
- En `romanOS-ControlCenter.ps1`:
  - Agregar botón o integrar la purga de Shaders de GPU (DirectX, NVIDIA, AMD, Intel) en la tarjeta de Gaming.
  - Desacoplar la limpieza de shaders de la rutina de mantenimiento del SO.

### Fase 3: Rediseño XAML y Lógica en `romanOS-ControlCenter.ps1` (Pestaña Mantenimiento)
- **Tarjeta 1: Dashboard de Capacidad y Estado en Vivo:**
  - Medidor de espacio libre/total en `C:` con barra de porcentaje.
  - Botón: `🔍 Analizar Almacén WinSxS (DISM)` (auditoría rápida sin modificar nada).
  - Botón: `⚡ Optimizar Disco (SSD TRIM)` (ejecución directa de recortado NAND).
- **Tarjeta 2: Higiene y Limpieza Profunda de Basura del SO:**
  - Casillas organizadas por categorías de basura real (Despliegue, WinSxS, Updates, DriverStore, CBS Logs, Dumps, Temporales, Navegadores).
  - Botón: `🧹 Iniciar Saneamiento Seleccionado`.
  - Botón: `⚡ Saneamiento Rápido Express`.
- **Tarjeta 3: Salud, Integridad y Autorreparación del SO:**
  - Botón: `🛠️ Reparar Archivos e Imagen (DISM RestoreHealth + SFC)`.
  - Botón: `🩺 Autochequeo WMI y Sistema de Archivos (winmgmt + Repair-Volume)`.
  - Botón: `⚙️ Precompilar Ensamblados .NET Pendientes (ngen.exe)`.
- **Tarjeta 4: romanOS Snapshot Engine & Anti-Drift Watchdog:**
  - Preservar y conectar de forma coherente el motor de instantáneas y el guardián anti-drift.

### Fase 4: Certificación, Pruebas Unitarias y Paridad en Windows PowerShell 5.1
- Validar formato estricto UTF-8 con BOM en todos los `.ps1` modificados.
- Validar AST en frío con `powershell.exe -STA -NoProfile`.
- Ejecutar la suite de pruebas del repositorio:
  - `scripts/Testing/Test-MSMGIntegration.ps1`
  - `scripts/Testing/Test-FunctionalContracts.ps1`
  - `scripts/Testing/Test-OptimizedISO-v2.ps1`
- Confirmar cero regresiones y registrar commit atómico.
