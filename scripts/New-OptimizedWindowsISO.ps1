#Requires -RunAsAdministrator
<#
.SYNOPSIS
Genera una ISO de Windows 10/11 con los scripts optimizadores integrados
.DESCRIPTION
Toma una ISO original de Windows (o la descarga automáticamente), extrae
su contenido, inyecta los scripts PostInstall_Optimizer, crea autounattend.xml
con bypass de TPM/RAM/CPU/cuenta Microsoft, y reconstruye la ISO.
.PARAMETER SourceISO
Ruta a la ISO original de Windows 10 u 11. Si no se especifica y se usa
-DownloadISO, se descarga automáticamente.
.PARAMETER OutputDir
Directorio donde se guardará la ISO resultante (default: Desktop\WinISO_Optimizado)
.PARAMETER DownloadISO
Descarga la ISO de Windows automáticamente desde Microsoft
.PARAMETER WindowsVersion
Versión a descargar (si -DownloadISO está activo). "10" o "11" (default: 11)
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
# Descargar ISO automáticamente + instalar dependencias
.\New-OptimizedWindowsISO.ps1 -DownloadISO -WindowsVersion 11 -AutoInstallDeps

# Windows 10 con idioma portugués
.\New-OptimizedWindowsISO.ps1 -DownloadISO -WindowsVersion 10 -Language pt-BR
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
    [switch]$DownloadISO,

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
    [string]$Win11ScriptPath = "Win11-Debloat-v3-Adaptive.ps1",

    [Parameter()]
    [string]$WindowsEdition = ""
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

    # Fido (para descargar ISOs de Windows)
    $fidoPath = Join-Path $env:TEMP "Fido.ps1"
    if (-not (Test-Path $fidoPath)) {
        Write-Host "    Descargando Fido (gestor de descarga de ISOs)..." -ForegroundColor Gray
        try {
            $fidoUrl = "https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1"
            Invoke-WebRequest -Uri $fidoUrl -OutFile $fidoPath -UseBasicParsing -ErrorAction Stop
            if (Test-Path $fidoPath) {
                Write-OK "Fido descargado: $fidoPath"
            } else {
                throw "Fido no se descargó"
            }
        } catch {
            Write-Warn "No se pudo descargar Fido: $_"
            Write-Warn "Puede descargarlo manualmente desde: https://github.com/pbatard/Fido"
            $depsOk = $false
        }
    } else {
        Write-OK "Fido ya disponible: $fidoPath"
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

function Download-WindowsISO {
    param([string]$Version)
    $fidoPath = Join-Path $env:TEMP "Fido.ps1"
    if (-not (Test-Path $fidoPath)) {
        Write-ErrorMsg "Fido no está disponible. Use -AutoInstallDeps para descargarlo o descárguelo manualmente."
        return $null
    }

    Write-Host "    Consultando Microsoft para la última ISO de Windows $Version..." -ForegroundColor Gray

    try {
        $winName = if ($Version -eq "10") { "Windows 10" } else { "Windows 11" }

        $fidoLang = switch ($Language) {
            "es-ES"  { "Spanish" }
            "en-US"  { "English International" }
            "pt-BR"  { "Portuguese (Brazil)" }
            "fr-FR"  { "French" }
            "de-DE"  { "German" }
            "it-IT"  { "Italian" }
            default  { "Spanish" }
        }

        Write-Host "    Versión: $winName | Idioma: $fidoLang" -ForegroundColor Cyan
        Write-Host "    Descargando ISO (esto puede tomar varios minutos)..." -ForegroundColor Gray
        Write-Host "    La ISO se guardará en: Desktop" -ForegroundColor Gray
        Write-Host "`n    Se abrirá una ventana de PowerShell para Fido. Espere a que termine..." -ForegroundColor Yellow

        # Fido llama a exit al terminar, lo que mata el script padre si se invoca directo.
        # Lo ejecutamos en una ventana nueva de PowerShell y esperamos.
        $fidoScript = @"
Set-Location '$HOME\Desktop'
& '$fidoPath' -Win '$winName' -Rel 'Latest' -Ed 'Pro/Home' -Lang '$fidoLang' -Arch 'x64'
Write-Host '`nFido terminó. Presione Enter para cerrar...' -ForegroundColor Green
Read-Host
"@
        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($fidoScript))

        Write-Host "    Iniciando Fido..." -ForegroundColor Gray
        $proc = Start-Process -FilePath powershell.exe -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", $encodedCommand
        ) -Wait -PassThru

        if ($proc.ExitCode -ne 0) {
            Write-Warn "Fido terminó con código: $($proc.ExitCode)"
        }

        # Buscar la ISO descargada en el escritorio
        $foundIso = Get-ChildItem $HOME\Desktop -Filter "*.iso" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($foundIso) {
            Write-OK "ISO descargada: $($foundIso.FullName)"
            return $foundIso.FullName
        }

        Write-Warn "Fido no descargó la ISO automáticamente. Puede necesitar interacción."
        Write-Warn "Ejecute Fido manualmente: PowerShell.exe -File `"$fidoPath`""
        return $null
    } catch {
        Write-ErrorMsg "Error descargando ISO: $_"
        return $null
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

# Descargar ISO si se solicitó
if ($DownloadISO) {
    if ($WindowsVersion -ne "10" -and $WindowsVersion -ne "11") {
        Write-ErrorMsg "Debe especificar -WindowsVersion 10 o 11 al usar -DownloadISO"
        exit 1
    }
    Write-Step "Descargando ISO de Windows $WindowsVersion..."
    $downloadedIso = Download-WindowsISO -Version $WindowsVersion
    if ($downloadedIso) {
        $SourceISO = $downloadedIso
    } else {
        if (-not $SourceISO -or -not (Test-Path $SourceISO)) {
            Write-ErrorMsg "No se pudo descargar la ISO y no se especificó una ISO existente."
            exit 1
        }
        Write-Warn "Usando ISO proporcionada: $SourceISO"
    }
}

# Validar ISO: si no hay -SourceISO ni -DownloadISO, preguntar interactivamente
if (-not $SourceISO -or -not (Test-Path $SourceISO)) {
    Write-Host "`nNo se especificó una ISO de origen." -ForegroundColor Yellow
    Write-Host "  [1] Seleccionar archivo ISO con diálogo de archivos" -ForegroundColor Cyan
    Write-Host "  [2] Escribir la ruta manualmente" -ForegroundColor Cyan
    Write-Host "  [0] Cancelar" -ForegroundColor Gray
    $choice = Read-Host "`nSeleccione una opción"
    switch ($choice) {
        "1" {
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Filter = "Archivos ISO (*.iso)|*.iso"
            $dialog.Title = "Seleccione la ISO de Windows"
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $SourceISO = $dialog.FileName
            }
            break
        }
        "2" {
            $manual = Read-Host "`nEscriba la ruta completa del archivo ISO"
            if ($manual -and (Test-Path $manual)) {
                $SourceISO = $manual
            } else {
                Write-Warn "Ruta inválida o archivo inexistente."
            }
            break
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

#------------------------------------------------------------------------------
# 2. CREAR ESTRUCTURA $OEM$ y DETECTAR VERSIÓN
#------------------------------------------------------------------------------
Write-Step "2/6 - Detectando versión de Windows e inyectando scripts..."
New-Item -ItemType Directory -Path $OEMScriptsDir -Force | Out-Null

# Detectar qué versión de Windows es esta ISO
$detectedVersion = Detect-WindowsVersion -IsoPath $SourceISO -ExtractedDir $ISOFilesDir
Write-Host "    Versión detectada: Windows $detectedVersion" -ForegroundColor Cyan

# Seleccionar la edición a instalar
$editions = @{
    "1" = @{ Name = "Pro"; Key = "VK7JG-NPHTM-C97JM-9MPGT-3V66T" }
    "2" = @{ Name = "Home"; Key = "YTMG3-N6DKC-DKB77-7M9GH-8HVX7" }
    "3" = @{ Name = "Education"; Key = "YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY" }
    "4" = @{ Name = "Enterprise"; Key = "XGVPP-NMH47-7TTHJ-W3FW7-8HV2C" }
    "5" = @{ Name = "Pro Education"; Key = "8PTT6-RNW4C-6V7J2-C2D3X-MHBPB" }
    "6" = @{ Name = "Pro for Workstations"; Key = "NRG8B-VKK3Q-CXVCJ-9G2XF-VKQIG" }
}

$targetEditionName = "Windows $detectedVersion Pro"
$targetEditionKey = "VK7JG-NPHTM-C97JM-9MPGT-3V66T"

if (-not [string]::IsNullOrWhiteSpace($WindowsEdition)) {
    # Buscar por nombre
    $found = $editions.Values | Where-Object { $_.Name -like "*$WindowsEdition*" } | Select-Object -First 1
    if ($found) {
        $targetEditionName = "Windows $detectedVersion $($found.Name)"
        $targetEditionKey = $found.Key
        Write-OK "Usando edición preseleccionada: $targetEditionName"
    } else {
        Write-Warn "Edición especificada no reconocida, usando Pro por defecto."
    }
} else {
    Write-Host "`nSeleccione la Edición de Windows que desea automatizar:" -ForegroundColor Cyan
    Write-Host "  [1] Pro (Recomendado)" -ForegroundColor Cyan
    Write-Host "  [2] Home" -ForegroundColor Cyan
    Write-Host "  [3] Education" -ForegroundColor Cyan
    Write-Host "  [4] Enterprise" -ForegroundColor Cyan
    Write-Host "  [5] Pro Education" -ForegroundColor Cyan
    Write-Host "  [6] Pro for Workstations" -ForegroundColor Cyan
    Write-Host "  [Enter] Por defecto (Pro)" -ForegroundColor Gray
    $choice = Read-Host "`nOpción"
    
    if ($editions.ContainsKey($choice)) {
        $targetEditionName = "Windows $detectedVersion $($editions[$choice].Name)"
        $targetEditionKey = $editions[$choice].Key
    }
}
Write-Host "    Edición configurada: $targetEditionName" -ForegroundColor Cyan


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
$setupCompleteContent = @'
@echo off
REM ===========================================================
REM  SetupComplete.cmd — Generado por New-OptimizedWindowsISO
REM  Se ejecuta como SYSTEM al finalizar Windows Setup
REM ===========================================================
REM Ejecutar el script optimizador correspondiente a esta version
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"$scriptDir = [System.IO.Path]::Combine($env:WINDIR, 'Setup', 'Scripts'); ^
$target = Get-ChildItem -Path $scriptDir -Filter '*.ps1' | Where-Object { $_.Name -like '*Optimizer.ps1' -or $_.Name -like '*Debloat*.ps1' -or $_.Name -like '*Adaptive*.ps1' } | Select-Object -First 1; ^
if ($target) { ^
& PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File $target.FullName -Unattended ^
>> (Join-Path $scriptDir 'PostInstall.log') 2>&1; ^
}" 2>> "C:\Windows\Setup\Scripts\SetupComplete.log"
exit /b 0
'@
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
    $encodedPasswordForAccount = ""  # Usado en <LocalAccount><Password>
    $encodedPasswordForAutologon = "" # Usado en <AutoLogon><Password>
    if ($LocalPassword) {
        $encodedPasswordForAccount  = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($LocalPassword + "Password"))
        $encodedPasswordForAutologon = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($LocalPassword + "Password"))
    }

    # Si no se especificó KeyboardOverride, usar el mismo valor que Language
    $finalKeyboard = if ($KeyboardOverride) { $KeyboardOverride } else { $Language }

    $autounattendContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
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
        <RunSynchronousCommand wcm:action="add">
          <Order>8</Order>
          <Description>Switch to legacy setup for 24H2+ compatibility</Description>
          <Path>reg add "HKLM\SYSTEM\Setup" /v CmdLine /t REG_SZ /d "X:\sources\setup.exe" /f</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
      <DiskConfiguration>
        <Disk wcm:action="add">
          <CreatePartitions>
            <CreatePartition wcm:action="add">
              <Order>1</Order>
              <Size>1024</Size>
              <Type>Primary</Type>
            </CreatePartition>
            <CreatePartition wcm:action="add">
              <Order>2</Order>
              <Size>500</Size>
              <Type>EFI</Type>
            </CreatePartition>
            <CreatePartition wcm:action="add">
              <Order>3</Order>
              <Size>128</Size>
              <Type>MSR</Type>
            </CreatePartition>
            <CreatePartition wcm:action="add">
              <Order>4</Order>
              <Extend>true</Extend>
              <Type>Primary</Type>
            </CreatePartition>
          </CreatePartitions>
          <ModifyPartitions>
            <ModifyPartition wcm:action="add">
              <Format>NTFS</Format>
              <Label>WinRE</Label>
              <Order>1</Order>
              <PartitionID>1</PartitionID>
              <TypeID>de94bba4-06d1-4d40-a16a-bfd50179d6ac</TypeID>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
              <Format>FAT32</Format>
              <Label>System</Label>
              <Order>2</Order>
              <PartitionID>2</PartitionID>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
              <Order>3</Order>
              <PartitionID>3</PartitionID>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
              <Format>NTFS</Format>
              <Label>Windows</Label>
              <Order>4</Order>
              <PartitionID>4</PartitionID>
            </ModifyPartition>
          </ModifyPartitions>
          <DiskID>0</DiskID>
          <WillWipeDisk>true</WillWipeDisk>
        </Disk>
        <WillShowUI>OnError</WillShowUI>
      </DiskConfiguration>
      <ImageInstall>
        <OSImage>
          <InstallTo>
            <DiskID>0</DiskID>
            <PartitionID>4</PartitionID>
          </InstallTo>
          <InstallFrom>
            <MetaData wcm:action="add">
              <Key>/IMAGE/NAME</Key>
              <Value>$targetEditionName</Value>
            </MetaData>
          </InstallFrom>
        </OSImage>
      </ImageInstall>
      <UserData>
        <ProductKey>
          <Key>$targetEditionKey</Key>
        </ProductKey>
        <AcceptEula>true</AcceptEula>
      </UserData>
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
        <RunSynchronousCommand wcm:action="add">
          <Order>2</Order>
          <Description>Forzar SetupComplete.cmd (PostOobe)</Description>
          <Path>reg add "HKLM\SYSTEM\Setup\FirstBoot\PostOobe" /v "00" /t REG_SZ /d "cmd /c C:\Windows\Setup\Scripts\SetupComplete.cmd &amp; exit /b 0" /f</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ComputerName>*</ComputerName>
      <RegisteredOrganization>Optimized</RegisteredOrganization>
      <RegisteredOwner>User</RegisteredOwner>
      <ShowWindowsLive>false</ShowWindowsLive>
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
          <PlainText>false</PlainText>
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
              <PlainText>false</PlainText>
            </Password>
            <DisplayName>$LocalUser</DisplayName>
            <Group>*S-1-5-32-544</Group>
            <Name>$LocalUser</Name>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideLocalAccountScreen>false</HideLocalAccountScreen>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>3</ProtectYourPC>
        <SkipMachineOOBE>true</SkipMachineOOBE>
        <SkipUserOOBE>true</SkipUserOOBE>
      </OOBE>
      <RegisteredOrganization>Optimized</RegisteredOrganization>
      <RegisteredOwner>User</RegisteredOwner>
      <ShowWindowsLive>false</ShowWindowsLive>
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
        $wimIndexes = & dism.exe /Get-WimInfo /WimFile:"$($wimFile.FullName)" 2>&1 | Out-String
        $indexMatches = [regex]::Matches($wimIndexes, 'Index\s*:\s*(\d+)')
        $indexesToProcess = if ($indexMatches.Count -gt 0) { $indexMatches | ForEach-Object { $_.Groups[1].Value } } else { @("1") }
        Write-Host "    Índices detectados: $($indexesToProcess -join ', ')" -ForegroundColor Gray

        foreach ($wimIndex in $indexesToProcess) {
            Write-Host "    Procesando índice $wimIndex..." -ForegroundColor Gray
            try {
                if (Test-Path $WimMountDir) { Remove-Item -Path $WimMountDir -Recurse -Force -ErrorAction SilentlyContinue }
                New-Item -ItemType Directory -Path $WimMountDir -Force | Out-Null

                Mount-WindowsImage -ImagePath $wimFile.FullName -Index $wimIndex -Path $WimMountDir -ErrorAction Stop
                Write-OK "WIM índice $wimIndex montado"

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

                if (-not $SkipAutoUnattend -and (Test-Path $autounattendPath)) {
                    $unattendDest = Join-Path $WimMountDir "Windows\Panther\Unattend\Unattend.xml"
                    $unattendDir = Split-Path $unattendDest -Parent
                    if (-not (Test-Path $unattendDir)) { New-Item -ItemType Directory -Path $unattendDir -Force | Out-Null }
                    Copy-Item -Path $autounattendPath -Destination $unattendDest -Force
                    Write-OK "Inyectado en WIM índice ${wimIndex}: Unattend.xml (Panther)"
                }

                Dismount-WindowsImage -Path $WimMountDir -Save -ErrorAction Stop
                Write-OK "WIM índice $wimIndex desmontado con cambios guardados"
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

    try {
        # Construcción CORRECTA del argumento de boot (sin espacios extra ni comillas mal ubicadas)
        $bootArg = "-bootdata:2#p0,e,b`"$biosBootFile`"#pEF,e,b`"$uefiBootFile`""

        # Usar un array de argumentos es mucho más seguro que cmd.exe /c con rutas con espacios
        $oscdimgArgs = @(
            "-m", "-o", "-u2", "-udfver102", "-l$isoLabel",
            $bootArg,
            $ISOFilesDir,
            $outputISO
        )

        Write-Host "    Ejecutando comando..." -ForegroundColor Gray

        $proc = Start-Process -FilePath $oscdimg -ArgumentList $oscdimgArgs -NoNewWindow -Wait -PassThru

        if ($proc.ExitCode -eq 0 -and (Test-Path $outputISO)) {
            $isoCreated = $true
            Write-OK "ISO creada exitosamente: $outputISO"
        } else {
            Write-Warn "oscdimg falló (exit code: $($proc.ExitCode))"
            Write-Warn "Revisa que tengas espacio en disco suficiente y permisos de escritura en: $OutputDir"
        }
    } catch {
        Write-Warn "Error ejecutando oscdimg: $_"
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
Write-Host "  │   - Instalación desatendida" -ForegroundColor Gray
Write-Host "  │   - Usuario: $LocalUser" -ForegroundColor Gray
Write-Host "  │   - Idioma:  $Language" -ForegroundColor Gray
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
3. La instalación será automática
4. Al llegar al escritorio, los scripts ya se habrán ejecutado

Nota: Si la instalación es en una máquina con licencia OEM,
SetupComplete.cmd se ejecuta igual gracias al PostOobe reg key.
"@ -ForegroundColor Yellow
