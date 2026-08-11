# OptimizedISO

> Genera una ISO de Windows 10/11 completamente desatendida (Zero-Touch) con limpieza de bloatware y optimizaciones de gaming/rendimiento preintegradas.

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
7. Ejecuta automáticamente `Win11-Debloat-v3-Adaptive.ps1` para limpiar y optimizar

> ⚠️ **Advertencia:** La ISO generada es **Zero-Touch** — formatea el Disco 0 sin preguntar. Úsala solo en equipos donde quieras una instalación limpia completa.

---

## Descarga rápida

👉 **[Descargar última versión](../../releases/latest)**

---

## Scripts incluidos

| Script | Descripción |
|--------|-------------|
| `New-OptimizedWindowsISO.ps1` | Script principal: toma una ISO de Windows, inyecta los optimizadores y genera una ISO desatendida |
| `Win11-Debloat-v3-Adaptive.ps1` | Post-instalación: elimina bloatware, aplica tweaks de gaming, instala winget y apps |
| `Win11-Network-Diagnostics-Optimizer.ps1` | Optimizador independiente de red para baja latencia y gaming |

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

.\scripts\New-OptimizedWindowsISO.ps1 -LocalUser "Roman" -LocalPassword "MiClave"
```

**Consulta [docs/USAGE.md](docs/USAGE.md) para la guía completa y todos los parámetros.**

### Ejemplo completo

```powershell
# ISO existente + usuario personalizado + idioma
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Downloads\Win11_Spanish_x64.iso" `
  -LocalUser "Roman" `
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