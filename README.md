# OptimizedISO

> Genera una ISO de Windows 11 completamente desatendida (Zero-Touch) con limpieza de bloatware y optimizaciones de gaming/rendimiento preintegradas.

[![Lint & Validate](https://github.com/romanOSlinux/OptimizedISO/actions/workflows/lint.yml/badge.svg)](https://github.com/romanOSlinux/OptimizedISO/actions/workflows/lint.yml)
[![Latest Release](https://img.shields.io/github/v/release/romanOSlinux/OptimizedISO)](https://github.com/romanOSlinux/OptimizedISO/releases/latest)

---

## ¿Qué hace esto?

Al arrancar un PC desde la ISO generada por este proyecto, ocurre lo siguiente **sin intervención del usuario**:

1. Omite las verificaciones de hardware de Windows 11 (TPM, CPU, RAM)
2. Borra y formatea el Disco 0 automáticamente (esquema UEFI)
3. Instala la edición de Windows seleccionada (Pro, Home, Education, Enterprise)
4. Salta la solicitud de clave de producto y el EULA
5. Salta la obligación de usar una cuenta Microsoft
6. Crea tu usuario local y arranca directo al escritorio
7. Prepara el sistema para ejecutar de forma opcional `Win11-Debloat-v3-Adaptive.ps1` tras finalizar la instalación.

> ⚠️ **Advertencia:** La ISO generada es **Zero-Touch** — formatea el Disco 0 sin preguntar. Úsala solo en equipos donde quieras una instalación limpia completa.

---

## Descarga rápida

👉 **[Descargar última versión](../../releases/latest)**

---

## Scripts y Herramientas Principales
 
| Script / Lanzador | Ubicación | Descripción |
|---|---|---|
| `Lanzar-romanOS-Studio.exe` | Raíz | Interfaz gráfica moderna (WPF) para configuración y compilación de ISOs |
| `Lanzar-romanOS-ControlCenter.cmd` | Raíz | Interfaz gráfica moderna (WPF) para el Hub Maestro (Telemetría en vivo, Gaming, Poda RAM, Red y Hardening) |
| `Lanzar-romanOS-Toolkit.cmd` | Raíz | Hub Maestro interactivo on-demand (Gaming, Red, Mantenimiento, Poda RAM, Auditoría) |
| `New-OptimizedWindowsISO-v2.ps1` | `scripts/Builder/` | Compilador principal: inyecta optimizaciones, updates, runtimes y genera ISO desatendida |
| `Win11-Debloat-v3-Adaptive.ps1` | `scripts/Modules/` | Debloat adaptativo: elimina bloatware, tweaks de gaming, políticas de navegador |
| `Switch-GameDevMode.cmd` | `scripts/Modules/` | Conmutador bimodal: alterna entre Modo Juego agresivo (libera RAM) y Modo Dev (Hyper-V/WSL2) |
| `Manage-SystemSnapshots.cmd` | `scripts/Modules/` | Motor de Instantáneas y Rollback atómico de configuración (registro, servicios, red y VSS) |
| `Deploy-AppProfiles.cmd` | `scripts/Modules/` | Gestor de Perfiles de Software, Winget desatendido y Runtimes de IA local por hardware |
| `Monitor-ThermalEnergy.cmd` | `scripts/Modules/` | Monitor de throttling térmico en tiempo real, calibración energética (Core Unparking) y salud de CPU/GPU |
| `Invoke-LiveSandbox.cmd` | `scripts/Modules/` | Orquestador de entornos Sandbox descartables (Air-Gap para análisis, vGPU para mods, navegación privada) |
| `Watchdog-ServiceDrift.cmd` | `scripts/Modules/` | Guardián Anti-Drift: audita y remedia desvíos de servicios invasivos y telemetría tras Windows Update |
| `Optimize-InterruptAffinity.cmd` | `scripts/Modules/` | Calibrador de Afinidad PCIe e Interrupciones IRQ: descongestiona Núcleo 0, eleva prioridad GPU/NVMe y DPC Steering |
| `Win11-Network-Diagnostics-Optimizer.ps1` | `scripts/Modules/` | Diagnóstico de latencia, benchmarks DNS y ajuste fino TCP/IP |

---

## Optimizaciones Offline (Novedad)

El script `New-OptimizedWindowsISO.ps1` ahora soporta optimizaciones avanzadas de imagen (DISM) de forma desatendida:
- **Slipstreaming de Actualizaciones:** Crea una carpeta llamada `Updates` junto al script y coloca allí tus parches de Windows (`.msu` o `.cab`). El script los integrará automáticamente en la ISO.
- **ResetBase Inteligente:** Si inyectas actualizaciones, el script limpiará automáticamente los archivos obsoletos de la imagen (WinSxS) ahorrando gigabytes de espacio.
- **Debloat Offline:** Purga automáticamente capacidades basura (FODs) como Hello Face y el motor de Internet Explorer desde la raíz del sistema operativo.

---

## Requisitos

- Windows 10/11 (para ejecutar los scripts)
- PowerShell 5.1+ como **Administrador**
- [7-Zip](https://7-zip.org) (el script puede instalarlo automáticamente)
- [oscdimg](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/oscdimg-command-line-options) — se instala automáticamente vía winget

---

## Uso

```powershell
# 1. Clona el repo o descarga el ZIP desde Releases
# 2. Abre PowerShell como Administrador
# 3. Ejecuta:

.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 -LocalUser "Usuario" -LocalPassword "MiClave"
```

**Consulta [docs/USAGE.md](docs/USAGE.md) para la guía de uso completo y [docs/AUTOUNATTEND.md](docs/AUTOUNATTEND.md) para entender cómo funciona la instalación desatendida.**

### Ejemplo completo

```powershell
# ISO existente + usuario personalizado + idioma
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Downloads\Win11_Spanish_x64.iso" `
  -LocalUser "Usuario" `
  -LocalPassword "Secreta123" `
  -WindowsEdition "Pro" `
  -Language "es-ES" `
  -Timezone "Argentina Standard Time"
```

---

## Desarrollo y contribución

Consulta [docs/CHANGELOG.md](docs/CHANGELOG.md) para el historial de versiones.

Para reportar bugs, usa el [template de issue](.github/ISSUE_TEMPLATE/bug_report.md).

---

## Licencia

MIT — libre uso personal. No usar para distribución comercial de Windows.