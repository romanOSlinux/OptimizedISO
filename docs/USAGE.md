# Guía de Uso: Creador de ISO Optimizada (Zero-Touch)

Este documento explica cómo utilizar el script `New-OptimizedWindowsISO.ps1` para generar una imagen de Windows 10 u 11 completamente desatendida, con los scripts de optimización y limpieza (Debloat) preintegrados.

> **Advertencia Importante:** La ISO generada con este script está configurada como **Zero-Touch**. Esto significa que al bootear desde el USB, **formateará automáticamente el Disco 0** e instalará Windows sin hacer preguntas. Úsala solo en equipos donde desees una instalación limpia completa.
>
> 💡 **Compatibilidad:** Probado y ajustado según las especificaciones oficiales de Microsoft ADK y Microsoft Learn para **Windows 10 y Windows 11 (23H2 / 24H2 / 25H2)**.

---

## 🚀 Requisitos Previos

1. **Abrir PowerShell como Administrador**
2. **Dependencias:** El script necesita `7-Zip` para extraer ISOs y `oscdimg` para reempaquetarlas. Si no los tienes, el script puede instalarlos automáticamente con el parámetro `-AutoInstallDeps`.

---

## 🛠️ Ejemplos de Uso

### 1. El método más rápido (Todo por defecto)

```powershell
.\scripts\New-OptimizedWindowsISO.ps1
```
Preguntará dónde está tu ISO original y creará un usuario local llamado "Usuario" sin contraseña.

### 2. Crear un usuario personalizado (Recomendado)

```powershell
.\scripts\New-OptimizedWindowsISO.ps1 -LocalUser "Roman" -LocalPassword "Secreta123"
```

### 3. Descargar la ISO oficial de Windows 11 automáticamente

```powershell
.\scripts\New-OptimizedWindowsISO.ps1 -DownloadISO -WindowsVersion 11 -AutoInstallDeps -LocalUser "Roman"
```

### 4. Usar una ISO existente en tu disco

```powershell
.\scripts\New-OptimizedWindowsISO.ps1 -SourceISO "C:\Users\Roman\Downloads\Win11_Spanish_x64.iso" -LocalUser "Roman"
```

### 5. Cambiar idioma y zona horaria

```powershell
.\scripts\New-OptimizedWindowsISO.ps1 -Language "es-ES" -Timezone "Argentina Standard Time"
```

### 6. Guardar la ISO en otra carpeta o pendrive

```powershell
.\scripts\New-OptimizedWindowsISO.ps1 -OutputDir "D:\ISOs_Modificadas" -LocalUser "Roman"
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
.\scripts\Win11-Debloat-v3-Adaptive.ps1

# Modo desatendido (aplica todo automáticamente, sin preguntas)
.\scripts\Win11-Debloat-v3-Adaptive.ps1 -Unattended
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
