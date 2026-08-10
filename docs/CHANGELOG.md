# Changelog — OptimizedISO

Todas las versiones notables se documentan aquí.
El formato sigue [Keep a Changelog](https://keepachangelog.com/es/1.0.0/).

---

## [Unreleased]

---

## [2.4.0] — 2026-08-09

### Añadido
- **Visualización de Ediciones WIM:** Mapeo de índices de `install.wim` a nombres de edición reales (ej: `[Índice 1] Windows 11 Home`, `[Índice 2] Windows 11 Pro`).
- **Menú de Selección de Índice:** Menú interactivo que permite elegir si inyectar en todas las ediciones o solo en una edición específica para ahorrar tiempo.
- **Parámetro `-TargetWimIndex`:** Permite especificar por CLI el índice a modificar (ej: `-TargetWimIndex "2"` o `-TargetWimIndex "all"`).

### Corregido
- **Parsing XML Crítico:** Agregados namespaces requeridos `xmlns:wcm` y `xmlns:xsi` al nodo raíz `<unattend>` en `autounattend.xml` para evitar crash del instalador de Windows.
- **Manejo de Contraseña Válido:** `PlainText` asigna `"true"` cuando la contraseña es vacía, evitando errores de validación XML en OOBE.
- **Bootdata de oscdimg Preservado:** Invocación de `oscdimg.exe` refactorizada mediante archivo batch `.cmd` temporal para evitar corrupción de comillas en `-bootdata` por parte de PowerShell.
- **Eliminación de Claves Obsoletas:** Removida inyección de `FirstBoot\PostOobe` (no documentada e ignorada en Win11 24H2+). `SetupComplete.cmd` corre de forma nativa desde `%WINDIR%\Setup\Scripts\`.
- **Limpieza de conflicto de Fases:** Eliminada la copia redundante de `autounattend.xml` dentro del WIM (`Windows\Panther\Unattend\`) que provocaba choques de fases en WinPE.
- **Depreciaciones según Microsoft Learn:** Eliminadas las etiquetas desaconsejadas `<SkipMachineOOBE>`, `<SkipUserOOBE>` y `<ShowWindowsLive>` del XML.
- **Heredoc de SetupComplete:** Cambio a sintaxis heredoc expandida `@"..."@` para resolver `$scriptName` correctamente en tiempo de generación.

---

## [2.3.0] — 2026-08-09

### Añadido
- CI workflow (`lint.yml`) con validación de sintaxis PowerShell + PSScriptAnalyzer + XML
- Release workflow (`release.yml`) con empaquetado automático de ZIP al hacer `git tag`
- Documentación completa: `README.md`, `docs/USAGE.md`, `docs/CHANGELOG.md`
- Template de issue para reporte de bugs

### Cambiado
- Estructura del repositorio reorganizada: `scripts/`, `docs/`, `tests/`

---

## [2.2.0] — 2026-08-09

### Añadido
- **Zero-Touch completo:** Particionado de disco UEFI automático en `autounattend.xml` (EFI 500MB + MSR 128MB + Windows extendido)
- **Selección de edición:** `<InstallFrom><MetaData>` para evitar la pausa de selección de edición
- **Clave KMS genérica:** `<ProductKey>` con clave KMS para saltear pantalla de activación
- **Parámetro `-WindowsEdition`:** Menú interactivo con 6 ediciones (Pro, Home, Education, Enterprise, Pro Education, Pro for Workstations)
- **Manejo seguro de ESD:** Omite `Mount-WindowsImage` si detecta `install.esd` (DISM no soporta ESD)
- **Fix Zero-Touch crítico:** Se corrigió congelamiento infinito de la instalación pasando correctamente `-Unattended` a `Win11-Debloat-v3-Adaptive.ps1`

### Corregido
- Grupo de usuarios cambiado de `Administrators` a SID universal `*S-1-5-32-544` (evita cuelgues en instalaciones en español)

---

## [2.1.0] — 2026-08-02

### Añadido
- **Winget sin Microsoft Store:** `Add-AppxProvisionedPackage` + `License1.xml` descargado desde GitHub API
- **Dashboard de hardware pre-menú:** CPU, RAM, GPU, disco y advertencias visibles ANTES de los menús interactivos
- **Health Check de prerrequisitos:** Detección de VC++ x64/x86, .NET 8/9, WebView2, DirectX 9 Legacy, .NET Framework 3.5
- **Sección 0.A:** Menú interactivo para instalar prerrequisitos faltantes (winget, descarga directa, DISM)
- **Winget 4 niveles de fallback:** RegisterByFamilyName → Repair-WinGetPackageManager → Descarga directa → Degradación graciosa

### Corregido
- Protección en Sección 2: `winget uninstall` protegido con guard `$script:HasWinget`
- Detección de build number y `DisplayVersion` de Windows en pre-flight

---

## [2.0.0] — 2026-08-02

### Añadido
- **Win11-Network-Diagnostics-Optimizer.ps1:** Script independiente de optimización de red
  - TCP tuning para Windows 11 25H2 (`ScalingHeuristics`, `CongestionProvider`, `FastOpen`)
  - `NetworkThrottlingIndex`, `SystemResponsiveness`, `NonBestEffortLimit` (QoS 0%)
  - Desactivación de Nagle Algorithm por adaptador
  - Soporte multilenguaje de hardware via `Set-NetAdapterAdvancedProperty -RegistryKeyword`
- **Gaming 25H2 (Win11-Debloat):**
  - `PowerThrottlingOff=1` automático en Desktop
  - Nagle Algorithm disable (`TcpNoDelay=1`, `TcpAckFrequency=1`)
  - `SwapEffectUpgradeEnable=1` (Windowed Games Optimization) con VRR
  - `GlobalTimerResolutionRequests=1` para CPUs modernas (12th Gen+ / Ryzen 5000+)
  - MSI Mode para GPU dedicada via PNPDeviceID (NVIDIA/AMD/Arc)
  - Bloatware 25H2: `Microsoft.Windows.Ai.Copilot.Provider`, `MicrosoftWindows.Client.WebExperience`

### Corregido
- Fix scope `$adv` y `$expPol` (variables definidas dentro de `if` usadas fuera)
- HAGS verifica versión de driver antes de activar (evita BSOD en WDDM < 2.7)
- Resumen de ejecución tabulado al final del script

---

## [1.0.0] — 2026-07-20

### Añadido
- Script inicial `New-OptimizedWindowsISO.ps1`
- Inyección de `autounattend.xml` con bypass TPM/RAM/CPU/SecureBoot
- Soporte de `$OEM$` + `SetupComplete.cmd` para ejecución post-instalación
- Detección automática de versión de Windows (5 niveles de fallback)
- Inyección offline en `install.wim` via DISM
- Reconstrucción de ISO con `oscdimg`
- `Win11-Debloat-v3-Adaptive.ps1` con parámetro `-Unattended`
