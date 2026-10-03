# Guía Rápida de Uso: Creador de ISO Optimizada (Zero-Touch v2)

> 💡 **Manual Completo y Detallado:** Para consultar la guía paso a paso de toda la suite (Toolkit Maestro, Mantenimiento, Red y Seguridad), consulta [`docs/MANUAL_DE_USO.md`](file:///c:/OptimizedISO/docs/MANUAL_DE_USO.md).

Este documento resume cómo utilizar el script maestro [`scripts/Builder/New-OptimizedWindowsISO-v2.ps1`](file:///c:/OptimizedISO/scripts/Builder/New-OptimizedWindowsISO-v2.ps1) para generar imágenes de Windows 11 completamente desatendidas con la suite de herramientas **romanOS Toolkit Maestro** preintegrada en el Menú Inicio.

> **Advertencia Importante:** La ISO generada con este script está configurada como **Zero-Touch**. Al bootear desde el USB, **formateará automáticamente el Disco 0** e instalará Windows sin intervención humana. Úsala solo en equipos donde desees una instalación limpia completa.
>
> 💡 **Compatibilidad:** Probado y certificado exclusivamente para **Windows 11 (25H2 / 24H2 / 23H2 / 22H2 / LTSC 2024)**.

---

## 🚀 Requisitos Previos

1. **Abrir PowerShell como Administrador**
2. **Dependencias:** El script necesita `7-Zip` para extraer ISOs y `oscdimg` (Windows ADK) para reempaquetar. Si no los tienes, el script los detecta e instala automáticamente.

---

## 🛠️ Ejemplos de Uso

### 1. El método interactivo (Recomendado)

```powershell
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1
```
Inicia el asistente en 6 pasos para seleccionar origen de ISO, suite de scripts, perfil de debloat (1, 2 o 3) y credenciales.

### 2. Descarga oficial automática y compilación directa

```powershell
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 -DownloadOfficialISO -LocalUser "Roman" -OptProfile 2
```

### 3. Usar una ISO local existente

```powershell
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 -SourceISO "C:\Users\Roman\Downloads\Win11_Spanish_x64.iso" -LocalUser "Roman"
```

### 5. Cambiar idioma y zona horaria

```powershell
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 -Language "es-ES" -Timezone "Argentina Standard Time"
```

### 6. Guardar la ISO en otra carpeta o pendrive

```powershell
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 -OutputDir "D:\ISOs_Modificadas" -LocalUser "Roman"
```

---

## ⚙️ Lista Completa de Parámetros

| Parámetro | Descripción | Ejemplo |
| :--- | :--- | :--- |
| `-SourceISO` | Ruta al archivo ISO original de Windows | `-SourceISO "C:\Win11.iso"` |
| `-OutputDir` | Carpeta donde se guardará la ISO terminada | `-OutputDir "D:\Salida"` |
| `-DownloadISO` | Descarga la ISO original automáticamente de Microsoft | `-DownloadISO` |
| `-WindowsVersion` | Indica qué versión descargar (requiere `-DownloadISO`) | `-WindowsVersion 11` |
| `-WindowsEdition` | Preselecciona la edición (Pro, Home, Education, Enterprise). Sin este parámetro, muestra un menú interactivo | `-WindowsEdition "Pro"` |
| `-AutoInstallDeps` | Instala `7-Zip` y `oscdimg` automáticamente via winget | `-AutoInstallDeps` |
| `-LocalUser` | Nombre de la cuenta local que se creará (Por defecto: "Usuario") | `-LocalUser "Admin"` |
| `-LocalPassword` | Contraseña de la cuenta local (Por defecto: en blanco) | `-LocalPassword "1234"` |
| `-Language` | Idioma de la instalación (Por defecto: "es-ES") | `-Language "en-US"` |
| `-Timezone` | Zona horaria para el reloj de Windows | `-Timezone "SA Western Standard Time"` |
| `-KeyboardOverride` | Layout de teclado si difiere del idioma (ej: teclado latinoamericano) | `-KeyboardOverride "latam"` |
| `-TargetWimIndex` | Especifica qué índice(s) del `install.wim` modificar (`"1"`, `"2"`, `"1,2"`, `"all"`). Si no se especifica, muestra menú interactivo | `-TargetWimIndex "2"` |
| `-SkipAutoUnattend` | **CUIDADO:** No genera el XML de instalación automática | `-SkipAutoUnattend` |
| `-SkipISOCreation` | Solo extrae e inyecta, sin crear el archivo `.iso` final | `-SkipISOCreation` |

---

## 📝 ¿Qué hace exactamente la ISO generada?

Al arrancar una PC con la ISO creada por este script, ocurrirá lo siguiente sin que tengas que presionar ninguna tecla:

1. Omite las comprobaciones de hardware de Windows 11 (TPM, CPU, RAM, SecureBoot)
2. Borra y formatea automáticamente el Disco principal (Disco 0) con esquema UEFI (EFI 500MB + MSR 128MB + Windows extendido)
3. Instala la edición de Windows seleccionada (Pro, Home, Education, etc.)
4. Salta la solicitud de clave de producto y los términos de licencia (EULA)
5. Salta la obligación de usar una cuenta de Microsoft conectada a internet
6. Crea tu usuario local y arranca directamente al escritorio
7. Al llegar al escritorio por primera vez, ejecuta `Win11-Debloat-v3-Adaptive.ps1` en segundo plano para limpiar y optimizar el sistema

---

## 🎮 Script de Debloat: Win11-Debloat-v3-Adaptive.ps1

Este script se ejecuta automáticamente al terminar la instalación, pero también puedes ejecutarlo manualmente en cualquier momento:

```powershell
# Modo interactivo (muestra menús para seleccionar qué aplicar)
.\scripts\Modules\Win11-Debloat-v3-Adaptive.ps1

# Modo desatendido (aplica todo automáticamente, sin preguntas)
.\scripts\Modules\Win11-Debloat-v3-Adaptive.ps1 -Unattended
```

### ¿Qué hace el script de debloat?

- **Sección 0:** Instala apps vía winget (configurable) + prerrequisitos (VC++, .NET, WebView2)
- **Sección 1:** Elimina apps de bloatware (Candy Crush, TikTok, Xbox, Copilot, etc.)
- **Sección 2:** Desinstala OneDrive, Teams legacy, Skype
- **Sección 3-5:** Tema oscuro, taskbar limpia, extensiones de archivo visibles
- **Sección 6-7:** Privacy hardening + desactiva apps en segundo plano
- **Sección 8:** Optimización de servicios de Windows (interactivo)
- **Sección 11:** Tweaks adaptativos por hardware (NVMe vs SATA, canal RAM, temp CPU)
- **Sección 12:** Optimizaciones de gaming (HAGS, MSI Mode GPU, Timer Resolution, VRR)

---

## 🌐 Script de Red: Win11-Network-Diagnostics-Optimizer.ps1

Optimizador independiente enfocado en baja latencia y gaming online:

```powershell
.\scripts\Win11-Network-Diagnostics-Optimizer.ps1
```

Incluye: TCP tuning (25H2), desactivar EEE, desactivar Nagle, RSS, Flow Control, diagnóstico de adaptadores.

---

## 🔧 Grabado en USB

Para grabar la ISO generada en un USB y bootear desde él:

1. Descarga [Rufus](https://rufus.ie) o [Ventoy](https://ventoy.net)
2. Selecciona la ISO generada (`Windows_Optimized_YYYYMMDD.iso`)
3. Grábala en el USB
4. Bootea desde el USB (F12/Del en el BIOS)
5. La instalación procederá automáticamente sin necesidad de interacción
