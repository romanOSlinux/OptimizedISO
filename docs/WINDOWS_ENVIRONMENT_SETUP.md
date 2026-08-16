# Guía Oficial: Configuración del Entorno de Desarrollo en Windows 11

Esta guía detalla paso a paso todo lo necesario para configurar una estación de trabajo en **Windows 11**, optimizada para el desarrollo, auditoría, compilación de imágenes de Windows (ISOs) y ejecución del agente de IA **Antigravity**.

---

## 1. Requisitos Previos del Sistema

* **Edición de Windows:** **Windows 11 Pro, Enterprise o Education** (64-bit).
  > [!NOTE]
  > Las ediciones *Home* no incluyen soporte nativo para **Hyper-V** ni **Windows Sandbox**. Se recomienda Windows 11 Pro para poder probar las ISOs en máquinas virtuales locales de forma automatizada.
* **Virtualización por Hardware:** Habilitar **Intel VT-x** o **AMD-V** (SVM) en la BIOS/UEFI de la placa base.
* **Espacio en Disco:** Mínimo **60 GB libres** (SSD/NVMe recomendado) para el espacio temporal de montaje DISM, descargas de ISOs y discos virtuales de Hyper-V.

---

## 2. Instalación Automatizada de Herramientas Base (vía `winget`)

Windows 11 incluye nativamente el administrador oficial de paquetes **Windows Package Manager (`winget`)** ([Microsoft Learn: winget tool](https://learn.microsoft.com/es-es/windows/package-manager/winget/)).

Abre **PowerShell como Administrador** y ejecuta el siguiente bloque consolidado para instalar todas las herramientas esenciales:

```powershell
# 1. Configurar política de ejecución de scripts de PowerShell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# 2. Instalar herramientas de desarrollo y utilidades con winget
winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.PowerShell -e --source winget --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.WindowsTerminal -e --source winget --accept-package-agreements --accept-source-agreements
winget install --id 7zip.7zip -e --source winget --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.VisualStudioCode -e --source winget --accept-package-agreements --accept-source-agreements
```

---

## 3. Instalación de Windows Deployment Tools (Windows ADK)

El **Windows Assessment and Deployment Kit (Windows ADK)** es el paquete oficial de Microsoft que contiene **`oscdimg.exe`** (necesario para compilar ISOs con arranque dual UEFI/BIOS) y las herramientas avanzadas de servicio DISM.

* **Fuente Oficial:** [Microsoft Learn: Descargar e instalar Windows ADK](https://learn.microsoft.com/es-es/windows-hardware/get-started/adk-install)

### Opción A: Instalación Automatizada con PowerShell (Recomendada)
Ejecuta en PowerShell como Administrador:

```powershell
$adkUrl = "https://go.microsoft.com/fwlink/?linkid=2271337" # ADK para Windows 11 24H2/25H2
$adkInstaller = "$env:TEMP\adksetup.exe"

Invoke-WebRequest -Uri $adkUrl -OutFile $adkInstaller
Start-Process -FilePath $adkInstaller -ArgumentList "/quiet /installpath `"C:\Program Files (x86)\Windows Kits\10`" /features OptionId.DeploymentTools" -Wait

# Validar que oscdimg.exe quedó disponible
$oscdimgPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
if (Test-Path $oscdimgPath) {
    Write-Host ">>> Windows ADK y oscdimg.exe instalados correctamente." -ForegroundColor Green
}
```

### Opción B: Instalación Manual con Interfaz Gráfica
1. Descarga el instalador desde la página oficial de [Windows ADK](https://learn.microsoft.com/es-es/windows-hardware/get-started/adk-install).
2. Ejecuta `adksetup.exe`.
3. Selecciona únicamente la casilla: **"Herramientas de implementación" (Deployment Tools)**.
4. Completa la instalación.

---

## 4. Habilitación de Hyper-V y Windows Sandbox

Para realizar pruebas de arranque y validación de las ISOs generadas sin reiniciar el equipo físico, habilita **Hyper-V** y **Windows Sandbox** ([Microsoft Learn: Habilitar Hyper-V](https://learn.microsoft.com/es-es/virtualization/hyper-v-on-windows/quick-start/enable-hyper-v)).

Ejecuta en PowerShell como Administrador:

```powershell
# Habilitar Hyper-V completo (Administrador de Hyper-V y Módulo PowerShell)
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart

# Habilitar Plataforma de Máquina Virtual y Windows Sandbox
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -All -NoRestart

Write-Host ">>> Componentes habilitados. Reinicia tu equipo para aplicar los cambios." -ForegroundColor Yellow
```
*(Es obligatorio reiniciar el ordenador tras este paso).*

---

## 5. Instalación y Configuración de Antigravity en Windows

1. **Descarga / Instalación:**
   - Instala la aplicación oficial de **Antigravity IDE** para Windows (o la extensión correspondiente de Antigravity en VS Code).
2. **Configuración de Git en Windows:**
   Abre una terminal y configura tu identidad de Git:
   ```bash
   git config --global user.name "Tu Nombre"
   git config --global user.email "tu-email@dominio.com"
   git config --global core.autocrlf true
   ```
3. **Clonar el Proyecto:**
   ```powershell
   cd C:\
   git clone https://github.com/romanOSlinux/OptimizedISO.git C:\OptimizedISO
   ```
4. **Abrir en Antigravity:**
   Inicia Antigravity y abre la carpeta `C:\OptimizedISO`.

---

## 6. Flujo de Compilación y Prueba Rápida

### A. Construir la ISO Optimizada con el Script v2
Abre PowerShell **como Administrador** dentro del directorio del proyecto:

```powershell
cd C:\OptimizedISO
.\scripts\New-OptimizedWindowsISO-v2.ps1
```

* El script ofrecerá descargar en vivo la última ISO oficial de Microsoft Learn o utilizar una que ya tengas descargada.
* Te permitirá seleccionar qué optimizadores integrar (Win11-Debloat-v3-Adaptive.ps1, de red, o ambos).
* Generará la ISO final en `$HOME\Desktop\WinISO_Optimizado\`.

### B. Probar la ISO Generada en Hyper-V (Script de 1 Línea)

Para probar la ISO creada en una Máquina Virtual con UEFI y TPM en Hyper-V, ejecuta:

```powershell
$isoPath = "$HOME\Desktop\WinISO_Optimizado\Windows_11_Optimizado.iso"
$vmName  = "Test_Optimized_Win11"

# Crear VM Gen2 (UEFI) con 4GB RAM y disco de 60GB
New-VM -Name $vmName -MemoryStartupBytes 4GB -Generation 2 -NewVHDPath "$HOME\Virtual Machines\$vmName.vhdx" -NewVHDSizeBytes 60GB -SwitchName (Get-VMSwitch | Select-Object -First 1 -ExpandProperty Name)
Set-VMProcessor -VMName $vmName -Count 4
Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $false
Set-VMKeyProtector -VMName $vmName -NewLocalKeyProtector
Enable-VMTPM -VMName $vmName

# Asignar ISO y configurar arranque
Add-VMDvdDrive -VMName $vmName -Path $isoPath
$dvd = Get-VMDvdDrive -VMName $vmName
Set-VMFirmware -VMName $vmName -FirstBootDevice $dvd

# Iniciar la Máquina Virtual
Start-VM -Name $vmName
vmconnect.exe localhost $vmName
```

---

## 7. Matriz de Comprobación y Diagnóstico

| Herramienta | Comando de Verificación | Resultado Esperado |
| :--- | :--- | :--- |
| **Git** | `git --version` | `git version 2.4x.x.windows.1` |
| **PowerShell 7** | `pwsh --version` | `PowerShell 7.x.x` |
| **Windows ADK (oscdimg)** | `& "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe" -?` | Versión y menú de ayuda de oscdimg |
| **DISM Nativo** | `dism.exe /?` | Herramienta de mantenimiento de imágenes |
| **Hyper-V** | `Get-Service vmms` | `Status: Running` |
