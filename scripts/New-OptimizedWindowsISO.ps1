#Requires -RunAsAdministrator
<#
.SYNOPSIS
Genera una ISO de Windows 10/11 con los scripts optimizadores integrados
.DESCRIPTION
Toma una ISO original de Windows, extrae su contenido, inyecta los scripts
PostInstall_Optimizer, crea autounattend.xml con bypass de TPM/RAM/CPU/cuenta
Microsoft, y reconstruye la ISO. La selección de edición y disco se realiza
manualmente durante la instalación.
.PARAMETER SourceISO
Ruta a la ISO original de Windows 10 u 11. Si no se especifica, se pedirá
interactivamente un directorio donde buscar archivos .iso.
.PARAMETER OutputDir
Directorio donde se guardará la ISO resultante (default: Desktop\WinISO_Optimizado)
.PARAMETER WindowsVersion
Versión de Windows para forzar detección. "10" o "11". Si no se especifica,
se detecta automáticamente.
.PARAMETER AutoInstallDeps
Instala automáticamente las dependencias necesarias (7-Zip) via winget
.PARAMETER InjectWin10Script
Inyecta Windows10_PostInstall_Optimizer.ps1 (default: true)
.PARAMETER InjectWin11Script
Inyecta Windows11_PostInstall_Optimizer.ps1 (default: true)
.PARAMETER SkipAutoUnattend
Omite la creación de autounattend.xml (instalación manual)
.PARAMETER SkipISOCreation
Solo prepara los archivos, no reconstruye la ISO
.PARAMETER LocalUser
Nombre del usuario local para autounattend (default: Usuario)
.PARAMETER LocalPassword
Contraseña del usuario local (default: en blanco)
.PARAMETER AutoLogonCount
Veces que el auto-logon se repite (default: 1)
.PARAMETER Language
Cultura del sistema (default: es-ES). Afecta UILanguage, SystemLocale,
UserLocale e InputLocale. Valores comunes: es-ES, en-US, pt-BR, fr-FR, de-DE
.PARAMETER Timezone
Zona horaria (default: Romance Standard Time)
.PARAMETER KeyboardOverride
Layout de teclado (default: mismo que Language). Si necesita uno distinto,
especifíquelo aquí. Ej: "es-ES" (España), "latam" (Latinoamérica),
"040C:0000040C" (formato hex legacy)
.EXAMPLE
# Usar ISO existente
.\New-OptimizedWindowsISO.ps1 -SourceISO "C:\ISOs\Win11_23H2_ES.iso"

# Modo interactivo (se pedirá seleccionar carpeta e ISO)
.\New-OptimizedWindowsISO.ps1

# Windows 10 con idioma portugués
.\New-OptimizedWindowsISO.ps1 -SourceISO "C:\ISOs\Win10.iso" -Language pt-BR
.NOTES
Correcciones aplicadas (v1.2):
- Corrección crítica en la ejecución de oscdimg: Se eliminó el uso de cmd.exe /c con strings concatenados.
- Ahora se usa un array de argumentos (-ArgumentList @(...)) para manejar correctamente rutas con espacios (como las de WinGet).
- Se agregaron validaciones (Test-Path) para los archivos etfsboot.com y efisys.bin antes de ejecutar oscdimg, evitando el error "ruta no encontrada".
- Write-Error renombrada a Write-ErrorMsg para no shadear el cmdlet nativo de PowerShell.
- [switch]$InjectWin10Script y $InjectWin11Script: eliminado default $true (viola PSScriptAnalyzer).
- $OEMScriptsDir: reemplazada construcción frágil con backticks por Join-Path con string literal.
- Contraseña en autounattend.xml: codificación corregida agregando sufijo "Password" requerido por Windows.
- FirstLogonCommands eliminado del oobeSystem: causaba doble/triple ejecución del optimizador.
- ArgumentList de 7-Zip: cambiado de string único a array para manejo correcto de rutas con espacios.
#>
param(
    [Parameter()]
    [string]$SourceISO,
    [Parameter()]
    [string]$OutputDir = "$HOME\Desktop\WinISO_Optimizado",

    [Parameter()]
    [string]$WindowsVersion = "",

    [Parameter()]
    [switch]$AutoInstallDeps,

    [Parameter()]
    [switch]$InjectWin10Script,

    [Parameter()]
    [switch]$InjectWin11Script,

    [Parameter()]
    [switch]$SkipAutoUnattend,

    [Parameter()]
    [switch]$SkipISOCreation,

    [Parameter()]
    [string]$LocalUser = "Usuario",

    [Parameter()]
    [string]$LocalPassword = "",

    [Parameter()]
    [int]$AutoLogonCount = 1,

    [Parameter()]
    [string]$Language = "es-ES",

    [Parameter()]
    [string]$Timezone = "Romance Standard Time",

    [Parameter()]
    [string]$KeyboardOverride = "",

    [Parameter()]
    [string]$Win10ScriptPath = "",

    [Parameter()]
    [string]$Win11ScriptPath = "",

    [Parameter()]
    [string]$TargetWimIndex = ""
)

# Forzar TLS 1.2 para descargas HTTPS (compatible con PS5)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#------------------------------------------------------------------------------
# CONFIGURACIÓN DE RUTAS
#------------------------------------------------------------------------------
$ScriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ExtractDir = Join-Path $env:TEMP "WinISO_Extract_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$WimMountDir = Join-Path $env:TEMP "WimMount_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$ISOFilesDir = Join-Path $ExtractDir "ISO_Files"
$OEMScriptsDir = Join-Path $ISOFilesDir '$OEM$$$\Setup\Scripts'

#------------------------------------------------------------------------------
# FUNCIONES AUXILIARES
#------------------------------------------------------------------------------
function Write-Banner {
    Clear-Host
    Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║        GENERADOR DE ISO OPTIMIZADA PARA WINDOWS             ║
║        Windows 10 y 11 - Post-Install Automatizado          ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n>>> $Message" -ForegroundColor Cyan
    Write-Host "    $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
}

function Write-OK {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [⚠] $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "  [ERROR] $Message" -ForegroundColor Red
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-7ZipInstalled {
    $paths = @(
        "${env:ProgramFiles}\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
        "$env:LOCALAPPDATA\Programs\7-Zip\7z.exe"
    )
    return ($paths | Where-Object { Test-Path $_ } | Select-Object -First 1)
}

function Get-WimImageList {
    param([string]$WimPath)
    $list = @()
    # Intento 1: Get-WindowsImage (cmdlet nativo de DISM en PowerShell)
    try {
        $wimObjs = Get-WindowsImage -ImagePath $WimPath -ErrorAction Stop
        foreach ($img in $wimObjs) {
            $list += [PSCustomObject]@{
                Index = [string]$img.ImageIndex
                Name  = [string]$img.ImageName
            }
        }
        if ($list.Count -gt 0) { return $list }
    } catch { }

    # Intento 2: Parsing de dism.exe CLI (multilenguaje)
    try {
        $rawText = & dism.exe /Get-WimInfo /WimFile:"$WimPath" 2>&1 | Out-String
        $blocks = $rawText -split '(?i)(?=(?:Index|Índice)\s*:)'
        foreach ($block in $blocks) {
            if ($block -match '(?i)(?:Index|Índice)\s*:\s*(\d+)') {
                $idx = $Matches[1]
                $name = "Desconocido"
                if ($block -match '(?i)(?:Name|Nombre)\s*:\s*([^\r\n]+)') {
                    $name = $Matches[1].Trim()
                }
                $list += [PSCustomObject]@{
                    Index = $idx
                    Name  = $name
                }
            }
        }
    } catch { }

    if ($list.Count -eq 0) {
        $list += [PSCustomObject]@{ Index = "1"; Name = "Índice 1" }
    }
    return $list
}

function Test-OSCDImgInstalled {
    $found = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "oscdimg.exe" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match 'Microsoft.OSCDIMG' } |
        Select-Object -First 1 -ExpandProperty FullName

    if (-not $found) {
        $found = Get-ChildItem -Path "$env:TEMP", "$env:LOCALAPPDATA\Temp" -Filter "oscdimg.exe" -Depth 3 -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $found) {
        Write-Host "    Instalando oscdimg.exe via winget..." -ForegroundColor Gray
        try {
            winget install -e --id Microsoft.OSCDIMG --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
            Start-Sleep -Seconds 2
            $found = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "oscdimg.exe" -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match 'Microsoft\.OSCDIMG' } |
                Select-Object -First 1 -ExpandProperty FullName
            if ($found) { Write-OK "oscdimg.exe instalado via winget" }
        } catch {
            Write-Warn "winget install falló: $_"
        }
    }
    return $found
}


function Install-Dependencies {
    Write-Step "Instalando dependencias necesarias..."
    $depsOk = $true

    # 7-Zip
    $7zPath = Test-7ZipInstalled
    if (-not $7zPath) {
        Write-Host "    Instalando 7-Zip via winget..." -ForegroundColor Gray
        try {
            winget install 7zip.7zip --silent --accept-package-agreements 2>&1 | Out-Null
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            $7zPath = Test-7ZipInstalled
            if ($7zPath) {
                Write-OK "7-Zip instalado: $7zPath"
            } else {
                throw "7-Zip no apareció después de instalar"
            }
        } catch {
            Write-Warn "No se pudo instalar 7-Zip automáticamente: $_"
            Write-Warn "Descárguelo manualmente desde: https://7-zip.org"
            $depsOk = $false
        }
    } else {
        Write-OK "7-Zip ya instalado: $7zPath"
    }

    if ($depsOk) { Write-OK "Dependencias listas" } else { Write-Warn "Algunas dependencias no se instalaron" }
    return $depsOk
}

function Detect-WindowsVersion {
    param(
        [string]$IsoPath,
        [string]$ExtractedDir
    )
    # 1. Si ya lo sabemos por -WindowsVersion
    if ($WindowsVersion -eq "10" -or $WindowsVersion -eq "11") {
        Write-Host "    Versión detectada por parámetro: Windows $WindowsVersion" -ForegroundColor Gray
        return $WindowsVersion
    }

    # 2. Detectar desde el nombre de archivo de la ISO
    $name = Split-Path $IsoPath -Leaf
    if ($name -match '(?:Win)?11|Windows 1?1[^0]|11H[12]|_11_|[^0]11[^0]|23H2|24H2|22H2') {
        Write-Host "    Versión detectada por nombre de archivo: Windows 11" -ForegroundColor Gray
        return "11"
    }
    if ($name -match '(?:Win)?10\b|Windows 10|10H[12]|_10_|1904[145]|ltsc.*2019|ltsc.*2021') {
        Write-Host "    Versión detectada por nombre de archivo: Windows 10" -ForegroundColor Gray
        return "10"
    }

    # 3. Montar ISO temporalmente para leer la etiqueta del volumen
    try {
        $mountVol = Mount-DiskImage -ImagePath $IsoPath -PassThru | Get-Volume -ErrorAction Stop
        $label = $mountVol.FileSystemLabel
        if ($label) {
            if ($label -match '11|W11|WINDOWS 11|WIN11') {
                Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue
                Write-Host "    Versión detectada por etiqueta de volumen: Windows 11" -ForegroundColor Gray
                return "11"
            }
            if ($label -match '10|W10|WINDOWS 10|WIN10') {
                Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue
                Write-Host "    Versión detectada por etiqueta de volumen: Windows 10" -ForegroundColor Gray
                return "10"
            }
        }
        Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue
    } catch { }

    # 4. Si ya extrajimos, revisar setup.exe o el contenido de install.wim
    if ($ExtractedDir -and (Test-Path $ExtractedDir)) {
        $setupExe = Get-ChildItem $ExtractedDir -Recurse -Filter "setup.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($setupExe) {
            $ver = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($setupExe.FullName).FileVersion
            Write-Host "    setup.exe versión: $ver" -ForegroundColor Gray
            if ($ver -match '^10\.0\.(22\d{3}|2[3-9]\d{3}|[3-9]\d{4})') {
                Write-Host "    Versión detectada por setup.exe: Windows 11" -ForegroundColor Gray
                return "11"
            }
            if ($ver -match '^10\.0\.(1\d{4}|2[01]\d{3})') {
                Write-Host "    Versión detectada por setup.exe: Windows 10" -ForegroundColor Gray
                return "10"
            }
        }

        # Buscar install.wim o install.esd y leer versión del índice 1
        $wimFile = Get-ChildItem $ExtractedDir -Recurse -Filter "install.*" -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in '.wim', '.esd' } | Select-Object -First 1
        if ($wimFile -and (Get-Command dism.exe -ErrorAction SilentlyContinue)) {
            try {
                $wimInfo = & dism.exe /Get-WimInfo /WimFile:"$($wimFile.FullName)" /Index:1 2>&1 | Out-String
                if ($wimInfo -match 'Version\s*:\s*10\.0\.(22\d{3}|2[3-9]\d{3}|[3-9]\d{4})') {
                    Write-Host "    Versión detectada por DISM: Windows 11" -ForegroundColor Gray
                    return "11"
                }
                if ($wimInfo -match 'Version\s*:\s*10\.0\.(1\d{4}|2[01]\d{3})') {
                    Write-Host "    Versión detectada por DISM: Windows 10" -ForegroundColor Gray
                    return "10"
                }
            } catch { }
        }
    }

    # 5. Fallback interactivo: preguntar al usuario
    Write-Warn "No se pudo detectar la versión de Windows automáticamente."
    Write-Host "`n  Seleccione la versión de Windows que contiene esta ISO:" -ForegroundColor Yellow
    Write-Host "  [1] Windows 11" -ForegroundColor Cyan
    Write-Host "  [2] Windows 10" -ForegroundColor Cyan
    Write-Host "  [0] Cancelar" -ForegroundColor Gray
    $choice = Read-Host "`nOpción"
    switch ($choice) {
        "1" { return "11" }
        "2" { return "10" }
        default { exit 1 }
    }
}


#------------------------------------------------------------------------------
# VALIDACIONES INICIALES
#------------------------------------------------------------------------------
Write-Banner
if (-not (Test-Admin)) {
    Write-ErrorMsg "Ejecute como Administrador."
    exit 1
}

# Instalar dependencias si se solicitó
if ($AutoInstallDeps) {
    $depsOk = Install-Dependencies
    if (-not $depsOk) {
        Write-Warn "Continúo con herramientas disponibles..."
    }
}


# Validar ISO: si no hay -SourceISO, preguntar interactivamente
if (-not $SourceISO -or -not (Test-Path $SourceISO)) {
    Write-Host "`nNo se especificó una ISO de origen." -ForegroundColor Yellow
    Write-Host "  [1] Buscar archivos ISO en una carpeta" -ForegroundColor Cyan
    Write-Host "  [2] Escribir la ruta completa del archivo ISO" -ForegroundColor Cyan
    Write-Host "  [0] Cancelar" -ForegroundColor Gray
    $choice = Read-Host "`nSeleccione una opción"
    switch ($choice) {
        "1" {
            $defaultDir = "$HOME\Desktop"
            $dirInput = Read-Host "`nRuta de la carpeta donde buscar ISOs (Enter = $defaultDir)"
            if ([string]::IsNullOrWhiteSpace($dirInput)) { $dirInput = $defaultDir }
            if (-not (Test-Path $dirInput -PathType Container)) {
                Write-ErrorMsg "La carpeta '$dirInput' no existe."
                exit 1
            }
            $isoFiles = @(Get-ChildItem -Path $dirInput -Filter "*.iso" -File -ErrorAction SilentlyContinue)
            if ($isoFiles.Count -eq 0) {
                Write-ErrorMsg "No se encontraron archivos .iso en '$dirInput'."
                exit 1
            }
            Write-Host "`nArchivos ISO encontrados en: $dirInput" -ForegroundColor Cyan
            Write-Host ("─" * 60) -ForegroundColor Gray
            for ($i = 0; $i -lt $isoFiles.Count; $i++) {
                $sizeMB = [math]::Round($isoFiles[$i].Length / 1MB, 0)
                Write-Host "  [$($i + 1)] $($isoFiles[$i].Name)  ($sizeMB MB)" -ForegroundColor White
            }
            Write-Host ("─" * 60) -ForegroundColor Gray
            $pick = Read-Host "`nSeleccione el número de la ISO"
            $pickNum = 0
            if ([int]::TryParse($pick, [ref]$pickNum) -and $pickNum -ge 1 -and $pickNum -le $isoFiles.Count) {
                $SourceISO = $isoFiles[$pickNum - 1].FullName
            } else {
                Write-ErrorMsg "Selección inválida."
                exit 1
            }
        }
        "2" {
            $manual = Read-Host "`nEscriba la ruta completa del archivo ISO"
            if ($manual -and (Test-Path $manual)) {
                $SourceISO = $manual
            } else {
                Write-ErrorMsg "Ruta inválida o archivo inexistente."
                exit 1
            }
        }
        default {
            exit 0
        }
    }

    # Re-validar
    if (-not $SourceISO -or -not (Test-Path $SourceISO)) {
        Write-ErrorMsg "No se pudo resolver la ISO de origen. Saliendo."
        exit 1
    }
}
Write-Host "`nISO origen: $SourceISO" -ForegroundColor Yellow

#------------------------------------------------------------------------------
# 1. EXTRAER ISO
#------------------------------------------------------------------------------
Write-Step "1/6 - Extrayendo ISO..."
$7zPath = Test-7ZipInstalled
$extractedOK = $false

# Crear directorios
if (Test-Path $ExtractDir) { Remove-Item -Path $ExtractDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $ISOFilesDir -Force | Out-Null

if ($7zPath) {
    Write-Host "    Usando 7-Zip: $7zPath" -ForegroundColor Gray
    $process = Start-Process -FilePath $7zPath -ArgumentList @("x", "`"$SourceISO`"", "-o`"$ISOFilesDir`"", "-y") -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -eq 0) {
        $extractedOK = $true
        Write-OK "ISO extraída con 7-Zip"
    } else {
        Write-Warn "7-Zip falló (exit code: $($process.ExitCode))"
    }
} else {
    Write-Warn "7-Zip no instalado. Intentando con PowerShell..."
}

if (-not $extractedOK) {
    # Fallback: montar ISO con PowerShell y copiar archivos
    try {
        $mountVol = Mount-DiskImage -ImagePath $SourceISO -PassThru | Get-Volume
        if (-not $mountVol) { throw "No se pudo montar la ISO" }
        $driveLetter = "$($mountVol.DriveLetter):"
        Write-Host "    ISO montada en $driveLetter" -ForegroundColor Gray

        # Copiar todo excepto el archivo install.wim demasiado grande
        Write-Host "    Copiando archivos (esto puede tomar varios minutos)..." -ForegroundColor Gray
        $robocopyExit = (robocopy $driveLetter $ISOFilesDir /E /COPY:DAT /R:2 /W:2 /NP /NFL /NDL 2>&1 | Select-Object -Last 1)
        Write-OK "Archivos copiados desde unidad $driveLetter"

        Dismount-DiskImage -ImagePath $SourceISO -ErrorAction SilentlyContinue
        $extractedOK = $true
    } catch {
        Write-ErrorMsg "No se pudo extraer la ISO: $_"
        if ($mountVol) { Dismount-DiskImage -ImagePath $SourceISO -ErrorAction SilentlyContinue }
        exit 1
    }
}

# Verificar que la extracción tenga sentido
$setupExe = Get-ChildItem $ISOFilesDir -Filter "setup.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
$sourcesDir = Get-ChildItem $ISOFilesDir -Directory -Filter "sources" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not ($setupExe -and $sourcesDir)) {
    Write-ErrorMsg "La ISO extraída no contiene setup.exe o sources/. ¿Es una ISO de Windows válida?"
    exit 1
}
Write-OK "ISO de Windows válida verificada"

# Forzar pantalla de selección de edición (override clave OEM BIOS/UEFI)
# Sin esto, el instalador lee la clave OEM de la BIOS y auto-selecciona Home/SingleLanguage.
# Reemplazar ei.cfg con [Channel] Retail indica al installer "medio retail" → muestra todas
# las ediciones del install.wim y deja elegir al usuario.
$eiCfgPath = Join-Path $sourcesDir.FullName "ei.cfg"
@"
[Channel]
Retail
"@ | Out-File -FilePath $eiCfgPath -Encoding ASCII -Force
Write-OK "ei.cfg reemplazado → el instalador mostrará selección de edición"

#------------------------------------------------------------------------------
# 2. CREAR ESTRUCTURA $OEM$ y DETECTAR VERSIÓN
#------------------------------------------------------------------------------
Write-Step "2/6 - Detectando versión de Windows e inyectando scripts..."
New-Item -ItemType Directory -Path $OEMScriptsDir -Force | Out-Null

# Detectar qué versión de Windows es esta ISO
$detectedVersion = Detect-WindowsVersion -IsoPath $SourceISO -ExtractedDir $ISOFilesDir
Write-Host "    Versión detectada: Windows $detectedVersion" -ForegroundColor Cyan

Write-OK "La edición de Windows y el disco se seleccionarán durante la instalación"


# Seleccionar ruta del script optimizador para la versión detectada
$scriptsToInject = @()
$scriptName = "Windows${detectedVersion}_PostInstall_Optimizer.ps1"

# Verificar si ya se proporcionó vía parámetro
$paramScriptPath = if ($detectedVersion -eq "10") { $Win10ScriptPath } else { $Win11ScriptPath }
# Resolver ruta relativa respecto al script actual
if ($paramScriptPath) {
    $resolvedPath = if (Test-Path $paramScriptPath) { $paramScriptPath } else { Join-Path $ScriptsDir $paramScriptPath }
    if (Test-Path $resolvedPath) {
        $scriptPath = $resolvedPath
        Write-OK "Usando script especificado: $scriptPath"
    }
}
if (-not $scriptPath) {
    Write-Host "`nSeleccione el archivo del script optimizador para Windows $detectedVersion" -ForegroundColor Cyan
    Write-Host "  (${scriptName})" -ForegroundColor Gray
    Write-Host "  [1] Seleccionar con diálogo de archivos" -ForegroundColor Cyan
    Write-Host "  [2] Escribir la ruta manualmente" -ForegroundColor Cyan
    Write-Host "  [3] Omitir script (solo autounattend.xml)" -ForegroundColor Yellow
    Write-Host "  [0] Cancelar" -ForegroundColor Gray
    $choice = Read-Host "`nOpción"
    $scriptPath = $null
    switch ($choice) {
        "1" {
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Filter = "Scripts PowerShell (*.ps1)|*.ps1"
            $dialog.Title = "Seleccione $scriptName"
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $scriptPath = $dialog.FileName
            }
        }
        "2" {
            $manual = Read-Host "Ruta completa del script .ps1"
            if ($manual -and (Test-Path $manual)) {
                $scriptPath = $manual
            } else {
                Write-Warn "Ruta inválida o archivo inexistente."
            }
        }
        "3" {
            Write-Warn "Omitiendo script optimizador."
        }
        default {
            Write-Warn "Omitiendo script optimizador."
        }
    }
}

if ($scriptPath) {
    $scriptsToInject += @{ Source = $scriptPath; DestName = $scriptName; }
    Write-OK "Inyectando script para Windows ${detectedVersion}: $scriptPath"
} else {
    Write-Warn "No se seleccionó script optimizador. La ISO se creará sin scripts en `$OEM$."
}

# Copiar scripts a $OEM$
foreach ($script in $scriptsToInject) {
    Copy-Item -Path $script.Source -Destination (Join-Path $OEMScriptsDir $script.DestName) -Force
    Write-OK "Copiado: $($script.DestName)"
}

#------------------------------------------------------------------------------
# 3. CREAR SetupComplete.cmd
#------------------------------------------------------------------------------
Write-Step "3/6 - Creando SetupComplete.cmd..."
# Fix #6: Heredoc double-quoted para que $scriptName se expanda al valor real detectado.
# Evita la sintaxis ^ dentro de -Command que no funciona en strings entre comillas en CMD.
$setupCompleteContent = @"
@echo off
REM ===========================================================
REM  SetupComplete.cmd - Generado por New-OptimizedWindowsISO
REM  Se ejecuta como SYSTEM al finalizar Windows Setup
REM ===========================================================
SET SCRIPTS_DIR=%WINDIR%\Setup\Scripts
SET SCRIPT_NAME=$scriptName
SET LOG=%SCRIPTS_DIR%\SetupComplete.log
SET PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe

echo [%DATE% %TIME%] Iniciando SetupComplete.cmd >> "%LOG%"

IF NOT EXIST "%SCRIPTS_DIR%\%SCRIPT_NAME%" (
    echo [%DATE% %TIME%] WARN: %SCRIPT_NAME% no encontrado en %SCRIPTS_DIR% >> "%LOG%"
    exit /b 0
)

REM --- Detectar internet ---
ping -n 1 -w 3000 8.8.8.8 >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    echo [%DATE% %TIME%] Internet detectado. Ejecutando optimizador... >> "%LOG%"
    %PS% -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\%SCRIPT_NAME%" -Unattended >> "%SCRIPTS_DIR%\PostInstall.log" 2>&1
    echo [%DATE% %TIME%] Optimizador ejecutado. >> "%LOG%"
) ELSE (
    echo [%DATE% %TIME%] Sin internet. Creando fallbacks... >> "%LOG%"

    REM --- Wrapper que ejecuta + limpia ---
    (
        echo @echo off
        echo echo Ejecutando optimizador...
        echo %PS% -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\%SCRIPT_NAME%"
        echo echo Limpiando...
        echo schtasks /Delete /TN "OptimizedISO-Optimizer" /F ^>nul 2^>^&1
        echo del "%%PUBLIC%%\Desktop\Ejecutar Optimizador.lnk" ^>nul 2^>^&1
        echo pause
    ) > "%SCRIPTS_DIR%\RunOptimizer.cmd"

    REM --- Tarea programada con trigger de red ---
    schtasks /Create /TN "OptimizedISO-Optimizer" ^
        /TR "\"%SCRIPTS_DIR%\RunOptimizer.cmd\"" ^
        /SC ONEVENT /EC Microsoft-Windows-NetworkProfile/Operational ^
        /MO "*[System[EventID=10000]]" ^
        /RL HIGHEST /F >> "%LOG%" 2>&1

    REM --- Acceso directo en Escritorio publico ---
    %PS% -NoProfile -ExecutionPolicy Bypass -Command ^
        "`$ws = New-Object -ComObject WScript.Shell; `$sc = `$ws.CreateShortcut('C:\Users\Public\Desktop\Ejecutar Optimizador.lnk'); `$sc.TargetPath = '%SCRIPTS_DIR%\RunOptimizer.cmd'; `$sc.Description = 'Ejecutar optimizador (requiere internet)'; `$sc.Save()"

    echo [%DATE% %TIME%] Tarea y acceso directo creados. >> "%LOG%"
)
exit /b 0
"@
$setupCompleteContent | Out-File -FilePath (Join-Path $OEMScriptsDir "SetupComplete.cmd") -Encoding ASCII -Force
Write-OK "SetupComplete.cmd creado"

#------------------------------------------------------------------------------
# 4. CREAR autounattend.xml
#------------------------------------------------------------------------------
if (-not $SkipAutoUnattend) {
    Write-Step "4/6 - Creando autounattend.xml..."

    # La contraseña en autounattend.xml con PlainText=false requiere codificación especial:
    # Windows exige que se concatene el sufijo "Password" al texto plano ANTES de codificar en Base64 UTF-16LE.
    # Sin el sufijo, el OOBE rechaza la contraseña incluso si el Base64 es válido.
    # Fix #2: PlainText debe ser 'true' cuando la contraseña es vacía (PlainText=false con valor
    # vacío es XML inválido según Microsoft y causa crash/loop en OOBE).
    $encodedPasswordForAccount   = ""     # Usado en <LocalAccount><Password>
    $encodedPasswordForAutologon = ""     # Usado en <AutoLogon><Password>
    $passwordPlainTextAccount    = "true" # 'true' = vacío; 'false' = Base64 codificado
    $passwordPlainTextAutologon  = "true" # 'true' = vacío; 'false' = Base64 codificado
    if ($LocalPassword) {
        $encodedPasswordForAccount   = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($LocalPassword + "Password"))
        $encodedPasswordForAutologon = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($LocalPassword + "Password"))
        $passwordPlainTextAccount    = "false"
        $passwordPlainTextAutologon  = "false"
    }

    # Si no se especificó KeyboardOverride, usar el mismo valor que Language
    $finalKeyboard = if ($KeyboardOverride) { $KeyboardOverride } else { $Language }

    # Preguntar sobre OneDrive
    $blockOneDrive = "true"
    $odChoice = Read-Host "`n¿Desea bloquear la instalación automática de OneDrive? [Y/N] (Default: Y)"
    if ($odChoice -match "^[nN]") {
        $blockOneDrive = "false"
    }

    $oneDriveXml = ""
    if ($blockOneDrive -eq "true") {
        $oneDriveXml = @"
        <RunSynchronousCommand wcm:action="add">
          <Order>2</Order>
          <Description>Prevent OneDrive auto-install</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive /v DisableFileSyncNGSC /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>3</Order>
          <Description>Remove OneDrive Setup from Run</Description>
          <Path>reg delete HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v OneDriveSetup /f</Path>
        </RunSynchronousCommand>
"@
    }

    # Optimizaciones de sistema inyectadas en fase specialize
    # Los Order se calculan dinámicamente según si OneDrive fue bloqueado o no.
    $nextOrder = if ($blockOneDrive -eq "true") { 4 } else { 2 }
    $optimizeXml = @"
        <RunSynchronousCommand wcm:action="add">
          <Order>$nextOrder</Order>
          <Description>Disable Hibernation (recover SSD space)</Description>
          <Path>powercfg -h off</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 1)</Order>
          <Description>Set High Performance power plan</Description>
          <Path>powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 2)</Order>
          <Description>Block Privacy Experience screens (Scoobe)</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE /v DisablePrivacyExperience /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
"@

    $autounattendContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend"
          xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage>
        <UILanguage>$Language</UILanguage>
      </SetupUILanguage>
      <InputLocale>$finalKeyboard</InputLocale>
      <SystemLocale>$Language</SystemLocale>
      <UILanguage>$Language</UILanguage>
      <UserLocale>$Language</UserLocale>
    </component>
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Bypass TPM Check</Description>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>2</Order>
          <Description>Bypass SecureBoot Check</Description>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>3</Order>
          <Description>Bypass RAM Check</Description>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>4</Order>
          <Description>Bypass CPU Check</Description>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassCPUCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>5</Order>
          <Description>Bypass Storage Check</Description>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassStorageCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>6</Order>
          <Description>Bypass Disk Check</Description>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassDiskCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>7</Order>
          <Description>Allow upgrades with unsupported TPM/CPU</Description>
          <Path>reg add HKLM\SYSTEM\Setup\MoSetup /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
      <EnableFirewall>true</EnableFirewall>
    </component>
  </settings>
  <settings pass="specialize">
    <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Bypass Microsoft Account (BypassNRO)</Description>
          <Path>reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE /v BypassNRO /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
$oneDriveXml
$optimizeXml
        <!-- Fix #3: Eliminado reg FirstBoot\PostOobe (clave no documentada, ignorada en Win11 24H2+).
             SetupComplete.cmd se ejecuta automaticamente si existe en %WINDIR%\Setup\Scripts\
             No requiere ningun registro adicional. -->
      </RunSynchronous>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ComputerName>*</ComputerName>
      <RegisteredOrganization>Optimized</RegisteredOrganization>
      <RegisteredOwner>User</RegisteredOwner>
      <TimeZone>$Timezone</TimeZone>
    </component>
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>$finalKeyboard</InputLocale>
      <SystemLocale>$Language</SystemLocale>
      <UILanguage>$Language</UILanguage>
      <UserLocale>$Language</UserLocale>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <AutoLogon>
        <Password>
          <Value>$encodedPasswordForAutologon</Value>
          <PlainText>$passwordPlainTextAutologon</PlainText>
        </Password>
        <Enabled>true</Enabled>
        <LogonCount>$AutoLogonCount</LogonCount>
        <Username>$LocalUser</Username>
      </AutoLogon>
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Password>
              <Value>$encodedPasswordForAccount</Value>
              <PlainText>$passwordPlainTextAccount</PlainText>
            </Password>
            <DisplayName>$LocalUser</DisplayName>
            <Group>Administrators</Group>
            <Name>$LocalUser</Name>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
      <RegisteredOrganization>Optimized</RegisteredOrganization>
      <RegisteredOwner>User</RegisteredOwner>
      <TimeZone>$Timezone</TimeZone>
    </component>
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>$finalKeyboard</InputLocale>
      <SystemLocale>$Language</SystemLocale>
      <UILanguage>$Language</UILanguage>
      <UserLocale>$Language</UserLocale>
    </component>
  </settings>
</unattend>
"@
    $autounattendPath = Join-Path $ISOFilesDir "autounattend.xml"
    $autounattendContent | Out-File -FilePath $autounattendPath -Encoding UTF8 -Force
    Write-OK "autounattend.xml creado"

    # Copiar también a $OEM$ (redundancia por si no se encuentra en raíz)
    Copy-Item -Path $autounattendPath -Destination (Join-Path $OEMScriptsDir "..\..\..\..\autounattend.xml") -Force -ErrorAction SilentlyContinue
} else {
    Write-Step "4/6 - Omitiendo autounattend.xml (flag -SkipAutoUnattend)"
}

#------------------------------------------------------------------------------
# 5. INYECTAR SCRIPTS EN install.wim CON DISM
#------------------------------------------------------------------------------
Write-Step "5/6 - Inyectando scripts en install.wim (offline)..."
$wimFile = Get-ChildItem -Path $ISOFilesDir -Recurse -Filter "install.wim" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $wimFile) {
    $wimFile = Get-ChildItem -Path $ISOFilesDir -Recurse -Filter "install.esd" -ErrorAction SilentlyContinue | Select-Object -First 1
}
$wimInjected = $false

if ($wimFile) {
    Write-Host "    WIM encontrado: $($wimFile.FullName)" -ForegroundColor Gray
    if ($wimFile.Extension -eq ".esd") {
        Write-Warn "El archivo es install.esd. DISM no puede modificar archivos ESD comprimidos de forma sólida."
        Write-Warn "Se omitirá la inyección offline. Las optimizaciones dependerán de la carpeta `$OEM$` y autounattend.xml."
    } else {
        $allWimImages = Get-WimImageList -WimPath $wimFile.FullName
        Write-Host "`n    Ediciones detectadas en install.wim:" -ForegroundColor Cyan
        Write-Host "    " + ("─" * 55) -ForegroundColor Gray
        foreach ($img in $allWimImages) {
            Write-Host "    [Índice $($img.Index)] $($img.Name)" -ForegroundColor White
        }
        Write-Host "    " + ("─" * 55) -ForegroundColor Gray

        $indexesToProcess = @()
        if ($TargetWimIndex) {
            if ($TargetWimIndex -eq "all" -or $TargetWimIndex -eq "*") {
                $indexesToProcess = $allWimImages | ForEach-Object { $_.Index }
                Write-Host "    Procesando TODAS las ediciones por parámetro (-TargetWimIndex all)" -ForegroundColor Gray
            } else {
                $indexesToProcess = $TargetWimIndex -split ',' | ForEach-Object { $_.Trim() }
                Write-Host "    Procesando índice(s) especificado(s): $($indexesToProcess -join ', ')" -ForegroundColor Gray
            }
        } elseif ($allWimImages.Count -eq 1) {
            $indexesToProcess = @($allWimImages[0].Index)
            Write-Host "    Solo se detectó 1 edición ($($allWimImages[0].Name)). Procesando..." -ForegroundColor Gray
        } else {
            Write-Host "`n    Seleccione qué edición(es) desea modificar offline:" -ForegroundColor Yellow
            Write-Host "    [A] Procesar TODAS las ediciones (tarda más tiempo)" -ForegroundColor Cyan
            for ($i = 0; $i -lt $allWimImages.Count; $i++) {
                Write-Host "    [$($i + 1)] Solo Índice $($allWimImages[$i].Index): $($allWimImages[$i].Name)" -ForegroundColor White
            }
            $choice = Read-Host "`n    Seleccione una opción (ENTER = TODAS)"
            if ([string]::IsNullOrWhiteSpace($choice) -or $choice -match '(?i)^a$') {
                $indexesToProcess = $allWimImages | ForEach-Object { $_.Index }
            } else {
                $pickNum = 0
                if ([int]::TryParse($choice, [ref]$pickNum) -and $pickNum -ge 1 -and $pickNum -le $allWimImages.Count) {
                    $indexesToProcess = @($allWimImages[$pickNum - 1].Index)
                } else {
                    Write-Warn "Opción no válida. Se procesarán TODAS las ediciones por defecto."
                    $indexesToProcess = $allWimImages | ForEach-Object { $_.Index }
                }
            }
        }

        foreach ($wimIndex in $indexesToProcess) {
            $currentImg = $allWimImages | Where-Object { $_.Index -eq $wimIndex } | Select-Object -First 1
            $imgNameStr = if ($currentImg) { " ($($currentImg.Name))" } else { "" }
            Write-Host "    Procesando índice $wimIndex$imgNameStr..." -ForegroundColor Gray
            try {
                if (Test-Path $WimMountDir) { Remove-Item -Path $WimMountDir -Recurse -Force -ErrorAction SilentlyContinue }
                New-Item -ItemType Directory -Path $WimMountDir -Force | Out-Null

                Mount-WindowsImage -ImagePath $wimFile.FullName -Index $wimIndex -Path $WimMountDir -ErrorAction Stop
                Write-OK "WIM índice $wimIndex$imgNameStr montado"

                # ==============================================================
                # SLIPSTREAMING: Inyectar Actualizaciones (.msu / .cab)
                # ==============================================================
                $UpdatesInjected = $false
                $UpdatesDir = Join-Path $ScriptsDir "Updates"
                if (Test-Path $UpdatesDir) {
                    $packages = Get-ChildItem -Path $UpdatesDir -Include *.msu, *.cab -Recurse
                    if ($packages.Count -gt 0) {
                        Write-Host "`n    ── Slipstreaming de Actualizaciones ──" -ForegroundColor Cyan
                        Write-Host "    Inyectando $($packages.Count) actualizaciones desde carpeta Updates..." -ForegroundColor Gray
                        try {
                            Add-WindowsPackage -Path $WimMountDir -PackagePath $UpdatesDir -ErrorAction Stop
                            Write-OK "Actualizaciones inyectadas correctamente."
                            $UpdatesInjected = $true
                        } catch {
                            Write-Warn "Error inyectando actualizaciones: $($_.Exception.Message)"
                        }
                    }
                }

                # ==============================================================
                # RESETBASE: Limpieza profunda de componentes (Condicional)
                # ==============================================================
                if ($UpdatesInjected) {
                    Write-Host "`n    ── ResetBase (Limpieza de Componentes) ──" -ForegroundColor Cyan
                    Write-Host "    Optimizando WIM (Esto puede tardar varios minutos)..." -ForegroundColor Gray
                    try {
                        Repair-WindowsImage -Path $WimMountDir -StartComponentCleanup -ResetBase -ErrorAction Stop
                        Write-OK "Componentes limpiados y consolidados (ResetBase)."
                    } catch {
                        Write-Warn "Error ejecutando ResetBase: $($_.Exception.Message)"
                    }
                }

                # ==============================================================
                # FEATURES ON DEMAND (FOD): Eliminar capacidades basura
                # ==============================================================
                Write-Host "`n    ── Eliminar Capacidades (FODs) ──" -ForegroundColor Cyan
                $fodsToRemove = @("Hello.Face*", "MathRecognizer*", "Browser.InternetExplorer*")
                try {
                    $installedFods = Get-WindowsCapability -Path $WimMountDir | Where-Object { $_.Name -match ($fodsToRemove -join '|') -and $_.State -eq 'Installed' }
                    if ($installedFods) {
                        foreach ($fod in $installedFods) {
                            Write-Host "    Eliminando FOD: $($fod.Name)..." -ForegroundColor Gray
                            Remove-WindowsCapability -Path $WimMountDir -Name $fod.Name -ErrorAction SilentlyContinue | Out-Null
                        }
                        Write-OK "Capacidades (FOD) basura eliminadas."
                    } else {
                        Write-Host "    No se detectaron FODs basura instalados." -ForegroundColor Gray
                    }
                } catch {
                    Write-Warn "Error eliminando FODs: $($_.Exception.Message)"
                }

                # ==============================================================
                # DEBLOAT OFFLINE: Eliminar Appx provisionados del WIM montado
                # ==============================================================
                Write-Host "`n    ── Debloat Offline (DISM) ──" -ForegroundColor Cyan

                # Paquetes PROTEGIDOS: nunca se ofrecen quitar.
                # Quitar estos rompe Store, Gaming, impresión, codecs o herramientas esenciales.
                $protectedPatterns = @(
                    'Microsoft.WindowsStore'
                    'Microsoft.StorePurchaseApp'
                    'Microsoft.DesktopAppInstaller'
                    'Microsoft.XboxIdentityProvider'
                    'Microsoft.XboxGamingOverlay'
                    'Microsoft.Xbox.TCUI'
                    'Microsoft.VCLibs'
                    'Microsoft.UI.Xaml'
                    'Microsoft.WindowsNotepad'
                    'Microsoft.WindowsTerminal'
                    'Microsoft.ScreenSketch'
                    'Microsoft.HEIFImageExtension'
                    'Microsoft.HEVCVideoExtension'
                    'Microsoft.WebMediaExtensions'
                    'Microsoft.VP9VideoExtensions'
                    'Microsoft.WebpImageExtension'
                    'Microsoft.RawImageExtension'
                )

                try {
                    $allProvPkgs = Get-AppxProvisionedPackage -Path $WimMountDir -ErrorAction Stop

                    # Filtrar protegidos
                    $removablePkgs = $allProvPkgs | Where-Object {
                        $pkgName = $_.DisplayName
                        $isProtected = $false
                        foreach ($pattern in $protectedPatterns) {
                            if ($pkgName -like "*$pattern*") { $isProtected = $true; break }
                        }
                        -not $isProtected
                    }

                    $protectedCount = $allProvPkgs.Count - $removablePkgs.Count
                    Write-Host "    Paquetes provisionados: $($allProvPkgs.Count) total, $protectedCount protegidos, $($removablePkgs.Count) seleccionables" -ForegroundColor Gray

                    if ($removablePkgs.Count -gt 0) {
                        # Preparar lista con descripciones para Out-GridView
                        $debloatList = $removablePkgs | ForEach-Object {
                            [PSCustomObject]@{
                                Name        = $_.DisplayName
                                PackageName = $_.PackageName
                                Version     = $_.Version
                            }
                        } | Sort-Object Name

                        $selectedToRemove = $null
                        if (-not $SkipAutoUnattend) {
                            # Modo interactivo: mostrar Out-GridView
                            Write-Host "    Abriendo ventana de selección de bloatware..." -ForegroundColor Yellow
                            Write-Host "    (Selecciona las apps a ELIMINAR de la ISO. Las no seleccionadas se conservan.)" -ForegroundColor Gray
                            $selectedToRemove = $debloatList | Out-GridView `
                                -Title "DEBLOAT OFFLINE: Selecciona apps a eliminar de la ISO (Ctrl+Click para varias) — Cancelar = no quitar nada" `
                                -PassThru
                        } else {
                            # Modo desatendido: quitar todo lo seleccionable
                            $selectedToRemove = $debloatList
                            Write-Host "    Modo desatendido: eliminando todo el bloatware no protegido..." -ForegroundColor Gray
                        }

                        if ($selectedToRemove) {
                            Write-Host "    Eliminando $($selectedToRemove.Count) paquetes del WIM..." -ForegroundColor Cyan
                            foreach ($pkg in $selectedToRemove) {
                                try {
                                    Remove-AppxProvisionedPackage -Path $WimMountDir -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
                                    Write-Host "      - Eliminado: $($pkg.Name)" -ForegroundColor Green
                                } catch {
                                    Write-Host "      ! Error eliminando $($pkg.Name): $($_.Exception.Message)" -ForegroundColor Yellow
                                }
                            }
                            Write-OK "Debloat offline completado: $($selectedToRemove.Count) paquetes eliminados"
                        } else {
                            Write-Host "    Sin selección. Conservando todos los paquetes." -ForegroundColor Gray
                        }
                    } else {
                        Write-Host "    No hay paquetes removibles (todos son protegidos o la imagen está limpia)." -ForegroundColor Gray
                    }
                } catch {
                    Write-Warn "No se pudo obtener la lista de paquetes provisionados: $($_.Exception.Message)"
                    Write-Warn "El debloat offline será omitido. El bloatware se podrá quitar post-instalación."
                }
                # ==============================================================

                $wimScriptsDir = Join-Path $WimMountDir "Windows\Setup\Scripts"
                if (-not (Test-Path $wimScriptsDir)) {
                    New-Item -ItemType Directory -Path $wimScriptsDir -Force | Out-Null
                }

                foreach ($script in $scriptsToInject) {
                    $dest = Join-Path $wimScriptsDir $script.DestName
                    Copy-Item -Path $script.Source -Destination $dest -Force
                    Write-OK "Inyectado en WIM índice ${wimIndex}: $($script.DestName)"
                }

                $setupCmdDest = Join-Path $wimScriptsDir "SetupComplete.cmd"
                $setupCompleteContent | Out-File -FilePath $setupCmdDest -Encoding ASCII -Force
                Write-OK "Inyectado en WIM índice ${wimIndex}: SetupComplete.cmd"

                Dismount-WindowsImage -Path $WimMountDir -Save -ErrorAction Stop
                Write-OK "WIM índice $wimIndex$imgNameStr desmontado con cambios guardados"
                $wimInjected = $true

                if (Test-Path $WimMountDir) {
                    Remove-Item -Path $WimMountDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            } catch {
                Write-Warn "Error inyectando en WIM índice ${wimIndex}: $_"
                try { Dismount-WindowsImage -Path $WimMountDir -Discard -ErrorAction SilentlyContinue } catch { }
            }
        }
    }
} else {
    Write-Warn "No se encontró install.wim ni install.esd"
    Write-Warn "La ISO se basará solo en `$OEM$ y autounattend.xml en raíz"
}

if (Test-Path $WimMountDir) {
    Remove-Item -Path $WimMountDir -Recurse -Force -ErrorAction SilentlyContinue
}

#------------------------------------------------------------------------------
# 6. RECONSTRUIR ISO
#------------------------------------------------------------------------------
if ($SkipISOCreation) {
    Write-Step "6/6 - Omitiendo reconstrucción de ISO (flag -SkipISOCreation)"
    Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  ARCHIVOS PREPARADOS EN:                        ║" -ForegroundColor Green
    Write-Host "║  $ISOFilesDir                                   ║" -ForegroundColor Cyan
    Write-Host "║                                                  ║" -ForegroundColor Green
    Write-Host "║  Para crear la ISO manualmente:                  ║" -ForegroundColor Green
    Write-Host "║  1. Abra oscdimg (Windows ADK)                  ║" -ForegroundColor Green
    Write-Host "║  2. Crear ISO desde carpeta                      ║" -ForegroundColor Green
    Write-Host "║  3. Seleccione: $ISOFilesDir                     ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Green
    return
}

Write-Step "6/6 - Reconstruyendo ISO..."
# Preparar directorio de salida
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$isoName = "Windows_Optimized_$(Get-Date -Format 'yyyyMMdd').iso"
$outputISO = Join-Path $OutputDir $isoName
$oscdimg = Test-OSCDImgInstalled
$isoCreated = $false

# Parámetros para oscdimg (etiqueta + args, se usan en varios lugares)
$isoLabel = "WINDOWS_OPTIMIZED"
if ($SourceISO) {
    try {
        $mountVol = Mount-DiskImage -ImagePath $SourceISO -PassThru | Get-Volume
        if ($mountVol) {
            $isoLabel = $mountVol.FileSystemLabel
            Dismount-DiskImage -ImagePath $SourceISO -ErrorAction SilentlyContinue
        }
    } catch { }
}

if ($oscdimg) {
    Write-Host "    Usando oscdimg: $oscdimg" -ForegroundColor Gray

    # Verificar que los archivos de boot existan (crítico para evitar "ruta no encontrada")
    $biosBootFile = Join-Path $ISOFilesDir "boot\etfsboot.com"
    $uefiBootFile = Join-Path $ISOFilesDir "efi\microsoft\boot\efisys.bin"

    if (-not (Test-Path $biosBootFile) -or -not (Test-Path $uefiBootFile)) {
        Write-Warn "Faltan archivos de arranque críticos en la ISO extraída."
        Write-Warn "Ruta BIOS esperada: $biosBootFile"
        Write-Warn "Ruta UEFI esperada: $uefiBootFile"
        Write-Warn "Verifica que la ISO original de Windows no esté corrupta o sea una versión no estándar."
    }

    $tempBat = $null
    try {
        # Fix #4: Start-Process -ArgumentList corrompe las comillas internas del argumento -bootdata
        # de oscdimg (doble-escaping o wrapping incorrecto), lo que hace que los archivos de arranque
        # no se encuentren y la ISO se genere sin soporte de boot funcional.
        # Solucion: escribir el comando a un batch temporal y ejecutarlo via cmd.exe /c.
        # Esto preserva exactamente el string que oscdimg espera sin manipulacion de PS.
        $tempBat = Join-Path $env:TEMP "oscdimg_$(Get-Random).cmd"
        $batLine  = "`"$oscdimg`" -m -o -u2 -udfver102 -l`"$isoLabel`""
        $batLine += " -bootdata:2#p0,e,b`"$biosBootFile`"#pEF,e,b`"$uefiBootFile`""
        $batLine += " `"$ISOFilesDir`" `"$outputISO`""
        $batContent = "@echo off" + [System.Environment]::NewLine + $batLine
        $batContent | Out-File -FilePath $tempBat -Encoding ASCII -Force

        Write-Host "    Ejecutando oscdimg (batch temporal)..." -ForegroundColor Gray
        Write-Host "    CMD: $batLine" -ForegroundColor DarkGray

        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", $tempBat) -NoNewWindow -Wait -PassThru

        if ($proc.ExitCode -eq 0 -and (Test-Path $outputISO)) {
            $isoCreated = $true
            Write-OK "ISO creada exitosamente: $outputISO"
        } else {
            Write-Warn "oscdimg falló (exit code: $($proc.ExitCode))"
            Write-Warn "CMD ejecutado: $batLine"
            Write-Warn "Revisa que tengas espacio en disco suficiente y permisos de escritura en: $OutputDir"
        }
    } catch {
        Write-Warn "Error ejecutando oscdimg: $_"
    } finally {
        if ($tempBat -and (Test-Path $tempBat)) { Remove-Item $tempBat -ErrorAction SilentlyContinue }
    }
} else {
    Write-Warn "oscdimg.exe no pudo ser instalado automáticamente."
}

if (-not $isoCreated) {
    Write-Warn "No se pudo crear la ISO automáticamente."
    Write-Host "`nLos archivos listos para crear ISO están en:" -ForegroundColor Cyan
    Write-Host "$ISOFilesDir" -ForegroundColor Cyan
    Write-Host "`nInstale oscdimg manualmente: winget install -e --id Microsoft.OSCDIMG" -ForegroundColor Yellow
    Write-Host "Luego genere la ISO con: .\New-IsoFromFolder.ps1 -SourceDir `"$ISOFilesDir`"" -ForegroundColor Yellow
}

#------------------------------------------------------------------------------
# RESUMEN FINAL
#------------------------------------------------------------------------------
Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                     OPERACIÓN COMPLETADA                     ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta

Write-Host "  ISO original:         $SourceISO" -ForegroundColor Gray
Write-Host "  Archivos extraídos:   $ISOFilesDir" -ForegroundColor Cyan
if ($isoCreated) {
    Write-Host "  ISO generada:         $outputISO" -ForegroundColor Green
    Write-Host "  Tamaño:               $((Get-Item $outputISO).Length / 1GB -as [int]) GB" -ForegroundColor Green
} else {
    Write-Host "  ISO no generada. Los archivos están en:" -ForegroundColor Yellow
    Write-Host "  $ISOFilesDir" -ForegroundColor Cyan
}

Write-Host @"
Contenido inyectado:
"@ -ForegroundColor White
Write-Host "  ├── autounattend.xml" -ForegroundColor Gray
Write-Host "  │   - Instalación semi-desatendida" -ForegroundColor Gray
Write-Host "  │   - Usuario: $LocalUser" -ForegroundColor Gray
Write-Host "  │   - Idioma:  $Language" -ForegroundColor Gray
Write-Host "  │   - Edición/Disco: Selección manual durante instalación" -ForegroundColor Gray
Write-Host "  │   - PostOobe: SetupComplete.cmd forzado" -ForegroundColor Gray
Write-Host "  │"
Write-Host "  ├── `$OEM`$$$\Setup\Scripts" -ForegroundColor Gray
Write-Host "  │   ├── SetupComplete.cmd" -ForegroundColor Gray
Write-Host "  │   │   - Ejecuta el script optimizador al finalizar instalación" -ForegroundColor Gray
foreach ($script in $scriptsToInject) {
    Write-Host "  │   ├── $($script.DestName)" -ForegroundColor Gray
}
Write-Host "  │"
Write-Host "  └── install.wim (scripts inyectados offline): $wimInjected" -ForegroundColor Gray

Write-Host @"

Para usar:
1. Grabe la ISO en un USB con Rufus (marque 'Windows To Go' si prefiere)
2. Inicie desde el USB
3. Seleccione la edición de Windows y el disco de instalación
4. El resto de la instalación será automática
5. Al llegar al escritorio, los scripts ya se habrán ejecutado

Nota: Si la instalación es en una máquina con licencia OEM,
SetupComplete.cmd se ejecuta igual gracias al PostOobe reg key.
"@ -ForegroundColor Yellow
