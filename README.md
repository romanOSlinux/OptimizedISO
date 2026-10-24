# romanOS v3.0 Universal

> **El ecosistema unificado definitivo de optimización, debloat adaptativo, afinamiento de hardware y compilación de ISOs desatendidas para Windows 11 y Windows 10.**

[![Lint & Validate](https://github.com/romanOSlinux/OptimizedISO/actions/workflows/lint.yml/badge.svg)](https://github.com/romanOSlinux/OptimizedISO/actions/workflows/lint.yml)
[![Latest Release](https://img.shields.io/github/v/release/romanOSlinux/OptimizedISO?color=blue&label=Release)](https://github.com/romanOSlinux/OptimizedISO/releases/latest)
[![PowerShell 5.1 & 7+](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg)](https://microsoft.com/powershell)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Zero-Damage Principle](https://img.shields.io/badge/Safety-Zero--Damage%20Guarantee-success.svg)](docs/plans/PLAN-0161-20261024-transicion-produccion-universal-y-sincronizacion-git.md)

---

## 🚀 Inicio Rápido en 1 Clic (Modo Universal)

romanOS v3.0 incorpora un **despachador tri-modal** que detecta automáticamente si estás ejecutando desde la web, un pendrive USB o un clon de Git.

### Opción A: Web 1-Liner (Sin Descarga Previa)
Abre PowerShell como Administrador o como usuario estándar y ejecuta:

```powershell
irm https://raw.githubusercontent.com/romanOSlinux/OptimizedISO/main/Lanzar-romanOS.ps1 | iex
```

### Opción B: USB / Pendrive Offline (Portabilidad Total)
1. Descarga el paquete oficial portátil [**`romanOS-Universal-v3.0.0.zip`**](../../releases/latest) y descomprímelo en tu memoria USB.
2. Haz doble clic en **`Lanzar-romanOS.cmd`**.
3. El lanzador solicitará permisos de Administrador de forma nativa e iniciará el **Centro de Control Gráfico** sin necesidad de conexión a Internet.

---

## 🛡️ Principio de Cero Daño y Reversibilidad en 1 Clic

A diferencia de scripts de optimización destructivos o irreversibles, romanOS opera bajo **estricta gobernanza transaccional**:

- **Snapshots Preventivos Automáticos:** Antes de aplicar cualquier modificación profunda, el motor genera una instantánea criptográfica SHA-256 de las directivas de registro, servicios del sistema y puntos de restauración (`VSS`).
- **Botón Canónico "↩ Revertir al Estado Inicial en 1 Clic":** Integrado de forma permanente en la cabecera de la interfaz gráfica oficial. Permite deshacer el 100% de los cambios y regresar al estado original en segundos sin conocimientos técnicos.
- **Topología Dinámica Hardware-Aware:** Protege arquitecturas híbridas Intel 12th-14th Gen (Thread Director P/E-Cores), procesadores AMD con 3D V-Cache (Dual-CCD CPPC), y correlaciona de forma adaptativa APUs con memoria compartida UMA frente a GPUs discretas con VRAM dedicada.

---

## 🖥️ Módulos y Herramientas Principales

| Herramienta / Módulo | Acceso Oficial | Descripción |
|---|---|---|
| **Punto de Entrada Universal** | `Lanzar-romanOS.cmd` / `.ps1` | Lanzador inteligente tri-modal con auto-elevación UAC y soporte `-STA`. |
| **romanOS Control Center** | `scripts/GUI/romanOS-ControlCenter.ps1` | Hub Maestro gráfico WPF (60 FPS) con telemetría en vivo, RAM, Red Gaming y Reversión en 1 Clic. |
| **romanOS Studio** | `scripts/GUI/romanOS-Studio.ps1` | Suite gráfica para diseño visual y configuración de presets de compilación de ISOs. |
| **Debloat v3 Adaptativo** | `scripts/Modules/Win11-Debloat-v3-Adaptive.ps1` | Eliminación inteligente de bloatware, telemetry tracking y políticas GPO de navegadores. |
| **Motor de Snapshots** | `scripts/Modules/Manage-SystemSnapshots.ps1` | Respaldo y restauración transaccional atómica con hashes SHA-256. |
| **Afinidad PCIe e IRQ** | `scripts/Drivers/Optimize-InterruptAffinity.ps1` | Descongestiona el Núcleo 0, eleva prioridad de GPU/NVMe y calibra DPC Steering. |
| **Depuración DriverStore** | `scripts/Drivers/Clean-DriverStore.ps1` | Análisis y purga segura de controladores duplicados/obsoletos sin riesgo de pantalla azul. |
| **Gobernanza de Inicio** | `scripts/Modules/Optimize-StartupEcosystem.ps1` | Afinamiento de servicios a demanda y mitigación de picos de logon (Maintenance Spike). |
| **Empaquetador Portable** | `scripts/Builder/Build-ProductionPackage.ps1` | Ensambla paquetes portables para USB y genera archivos ZIP con manifiesto SHA-256. |
| **Compilador de ISOs** | `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` | Generador Zero-Touch de imágenes ISO desatendidas con slipstreaming de parches y runtimes. |

---

## 💿 Compilación de ISOs Desatendidas (Zero-Touch)

Si deseas crear un medio de instalación limpio de Windows 11 o Windows 10 con todas las optimizaciones preintegradas:

```powershell
# Clona el repositorio y abre PowerShell como Administrador:
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Downloads\Win11_Spanish_x64.iso" `
  -LocalUser "TuUsuario" `
  -LocalPassword "TuClaveSegura" `
  -WindowsEdition "Pro"
```

### Características de la ISO Generada:
1. **Zero-Touch:** Omite pantallas de bienvenida, contratos de licencia y requisitos de cuenta Microsoft en línea.
2. **Bypass de Hardware Oficial:** Supera restricciones de TPM 2.0, SecureBoot, RAM y procesadores no soportados.
3. **Optimización WinSxS (ResetBase):** Purga gigabytes de archivos obsoletos tras slipstreaming de parches oficiales.
4. **Debloat Offline:** Remueve componentes innecesarios (IE Engine, FODs) directamente desde la imagen WIM montada.

---

## 🔧 Requisitos del Sistema

- **Sistema Operativo:** Windows 10 o Windows 11 (ediciones Home, Pro, Enterprise, Education, IoT Enterprise).
- **Runtime:** Windows PowerShell 5.1 (incluido por defecto en Windows) o PowerShell 7+.
- **Herramientas de Compilación (solo para crear ISOs):** Windows ADK / `oscdimg.exe` y `7-Zip` (se configuran automáticamente si no están instalados).

---

## 📖 Documentación y Soporte

- **Guía de Uso Exhaustiva:** [`docs/USAGE.md`](docs/USAGE.md)
- **Especificación de Despliegue Desatendido:** [`docs/AUTOUNATTEND.md`](docs/AUTOUNATTEND.md)
- **Historial de Cambios y Versiones:** [`docs/CHANGELOG.md`](docs/CHANGELOG.md)
- **Planes de Arquitectura y Gobernanza:** [`docs/plans/`](docs/plans/)

---

## 📜 Licencia

Distribuido bajo la **Licencia MIT**. Consulte [`LICENSE`](LICENSE) para más información.  
*Nota: Este proyecto no distribuye binarios propietarios de Microsoft Windows ni vulnera licencias de terceros.*