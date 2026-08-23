#Requires -RunAsAdministrator

<#
.SYNOPSIS
Genera una ISO de Windows 10/11 con scripts de optimización integrados.

.DESCRIPTION
Toma una ISO original de Windows, extrae su contenido, inyecta scripts
post-instalación, crea autounattend.xml con opciones de instalación
desatendida y reconstruye la ISO.

Esta versión está reescrita para corregir errores críticos detectados en
la auditoría: sintaxis, rutas $OEM$, SetupComplete.cmd, detección de
versión, validación de índices WIM y generación de autounattend.xml.

.PARAMETER SourceISO
Ruta a la ISO original de Windows 10 u 11.

.PARAMETER OutputDir
Directorio donde se guardará la ISO resultante.

.PARAMETER WindowsVersion
Fuerza detección: "10" o "11".

.PARAMETER AutoInstallDeps
Instala automáticamente dependencias vía winget si están disponibles.

.PARAMETER InjectWin10Script
Fuerza intento de inyección de Windows10_PostInstall_Optimizer.ps1.

.PARAMETER InjectWin11Script
Fuerza intento de inyección de Windows11_PostInstall_Optimizer.ps1.

.PARAMETER SkipAutoUnattend
Omite la creación de autounattend.xml.

.PARAMETER SkipISOCreation
Solo prepara archivos, no reconstruye la ISO.

.PARAMETER LocalUser
Nombre del usuario local para autounattend.

.PARAMETER LocalPassword
Contraseña del usuario local. Advertencia: quedará reversible en autounattend.xml.

.PARAMETER AutoLogonCount
Cantidad de inicios de sesión automáticos.

.PARAMETER Language
Idioma UI de Windows. Ejemplos: es-ES, en-US, pt-BR.

.PARAMETER Locale
Locale regional independiente del idioma UI. Ejemplos: es-AR, es-MX, en-US.

.PARAMETER Timezone
Zona horaria de Windows. Ejemplo: Romance Standard Time.

.PARAMETER KeyboardOverride
Layout de teclado. Si se deja vacío, se usa Language.

.PARAMETER Win10ScriptPath
Ruta al script optimizador para Windows 10.

.PARAMETER Win11ScriptPath
Ruta al script optimizador para Windows 11.

.PARAMETER TargetWimIndex
Índice WIM a procesar. Puede ser un número, varios separados por coma, all o *.

.PARAMETER WimCompression
Compresión final del WIM: None, Fast o Max.

.PARAMETER InjectVisualTweaks
Inyecta tweaks visuales offline en el perfil default.

.PARAMETER OptimizationProfile
Perfil de optimización: 1 = Conservador, 2 = Gaming, 3 = Hardcore.
Si no se especifica, se pregunta interactivamente.

.PARAMETER NoBlockOneDrive
Evita el bloqueo automático de OneDrive. Por defecto OneDrive se bloquea.

.PARAMETER Architecture
Arquitectura de la imagen: amd64, arm64 o x86.

.PARAMETER ZeroTouch
Activa la instalación 100% desatendida (Zero-Touch): particiona automáticamente el disco 0 en UEFI/GPT, acepta el EULA e instala el índice seleccionado sin intervención del usuario. Solo aplica cuando se procesa un único índice WIM.

.PARAMETER ZeroTouchDisk
Índice del disco físico de destino para Zero-Touch (por defecto: 0).


.PARAMETER KeepExtractDir
Si se especifica, conserva la carpeta temporal de extracción ($ExtractDir) tras
finalizar. Útil para inspección manual. Por defecto se elimina automáticamente
para liberar el espacio en disco (5-12 GB por ejecución).

.PARAMETER RuntimesPath
Ruta a la carpeta Runtimes/ que contiene Visual C++ y DirectX redistribuibles.
Si se omite, se busca automáticamente en la carpeta del script.

.PARAMETER DriversPath
Ruta a la carpeta Drivers/ que contiene controladores (.inf) para inyección offline.
Si se omite, se busca automáticamente en la carpeta del script o en la raíz.

.EXAMPLE
.\New-OptimizedWindowsISO.Fixed.ps1 -SourceISO "C:\ISOs\Win11_23H2_ES.iso"

.EXAMPLE
.\New-OptimizedWindowsISO.Fixed.ps1 -SourceISO "C:\ISOs\Win10.iso" -Language es-MX -Locale es-MX

.EXAMPLE
# Conservar carpeta de extracción para inspección manual:
.\New-OptimizedWindowsISO.Fixed.ps1 -SourceISO "C:\ISOs\Win11.iso" -KeepExtractDir

.NOTES
Versión corregida basada en auditoría. No probada automáticamente.
Se recomienda validar en máquina virtual antes de usar en producción.
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
    [string]$Locale = "",

    [Parameter()]
    [string]$Timezone = "Romance Standard Time",

    [Parameter()]
    [string]$KeyboardOverride = "",

    [Parameter()]
    [string]$Win10ScriptPath = "",

    [Parameter()]
    [string]$Win11ScriptPath = "",

    [Parameter()]
    [string]$TargetWimIndex = "",

    [Parameter()]
    [ValidateSet("None", "Fast", "Max")]
    [string]$WimCompression = "Max",

    [Parameter()]
    [switch]$InjectVisualTweaks,

    [Parameter()]
    [ValidateSet("1", "2", "3")]
    [string]$OptimizationProfile = "",

    [Parameter()]
    [switch]$NoBlockOneDrive,

    [Parameter()]
    [ValidateSet("amd64", "arm64", "x86")]
    [string]$Architecture = "amd64",

    # Si se activa, NO se elimina la carpeta de extracción temporal al finalizar.
    # Útil para inspección manual post-creación. Por defecto = $false (limpia todo).
    [Parameter()]
    [switch]$KeepExtractDir,

    [Parameter()]
    [string]$RuntimesPath = "",

    [Parameter()]
    [string]$DriversPath = "",

    [Parameter()]
    [switch]$ZeroTouch,

    [Parameter()]
    [int]$ZeroTouchDisk = 0
)

#------------------------------------------------------------------------------
# CONFIGURACIÓN GENERAL
#------------------------------------------------------------------------------

$ErrorActionPreference = 'Continue'

# TLS 1.2 para posibles descargas HTTPS en PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#------------------------------------------------------------------------------
# RUTAS DE TRABAJO
#------------------------------------------------------------------------------

$ScriptsDir = if ($PSScriptRoot) {
    $PSScriptRoot
} else {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}

$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

$ExtractDir   = Join-Path $env:TEMP "WinISO_Extract_$Timestamp"
# Rutas de trabajo en la raíz del disco del sistema para evitar problemas con %TEMP%
# redirigido (perfiles de roaming) y restricciones de permisos en carpetas de usuario.
$WimMountDir  = Join-Path $env:SystemDrive "WimMount_$Timestamp"
$ScratchDir   = Join-Path $env:SystemDrive "WinISO_Scratch_$Timestamp"
$ISOFilesDir  = Join-Path $ExtractDir "ISO_Files"

# Corrección crítica: la carpeta especial debe ser exactamente:
# sources\$OEM$\$$\Setup\Scripts
$OEMScriptsDir = Join-Path $ISOFilesDir 'sources\$OEM$\$$\Setup\Scripts'

#------------------------------------------------------------------------------
# LOGGING ENGINE — Opción 3: Write-Log + Start-Transcript
# Genera dos archivos por ejecución en $OutputDir\Logs\
#   ISO_Build_<timestamp>.log            ← estructurado con niveles
#   ISO_Build_<timestamp>_transcript.log ← transcripción completa de consola
# Fuente: learn.microsoft.com/Start-Transcript + about_Redirection
#------------------------------------------------------------------------------

$script:LogFile         = $null
$script:TranscriptFile  = $null
$script:AiSummaryFile   = $null
$script:LogErrors       = [System.Collections.Generic.List[string]]::new()
$script:LogWarns        = [System.Collections.Generic.List[string]]::new()
$script:LogSteps        = [System.Collections.Generic.List[PSObject]]::new()
$script:CurrentStepObj  = $null
$script:BuildStartTime  = Get-Date

function Initialize-Log {
    param([string]$OutputDirectory)

    $logDir = Join-Path $OutputDirectory "Logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $ts                     = Get-Date -Format 'yyyyMMdd_HHmmss'
    $script:LogFile         = Join-Path $logDir "ISO_Build_$ts.log"
    $script:TranscriptFile  = Join-Path $logDir "ISO_Build_${ts}_transcript.log"
    $script:AiSummaryFile   = Join-Path $logDir "ISO_Build_${ts}_AI_SUMMARY.md"
    $script:BuildStartTime  = Get-Date

    # Abrir transcript de consola completo
    try {
        Start-Transcript -Path $script:TranscriptFile -Append -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "  [LOG] Start-Transcript no disponible en este host: $($_.Exception.Message)" -ForegroundColor DarkGray
    }

    # Cabecera del log estructurado
    Write-LogEntry -Level "INIT" -Message ("=" * 64)
    Write-LogEntry -Level "INIT" -Message "OptimizedISO Build Log"
    Write-LogEntry -Level "INIT" -Message "PowerShell $($PSVersionTable.PSVersion)  |  Host: $env:COMPUTERNAME  |  User: $env:USERNAME"
    Write-LogEntry -Level "INIT" -Message "Fuente ISO: $SourceISO"
    Write-LogEntry -Level "INIT" -Message ("=" * 64)
}

function Write-LogEntry {
    [CmdletBinding()]
    param(
        [ValidateSet("INIT","STEP","INFO","OK","WARN","ERROR","DEBUG")]
        [string]$Level = "INFO",
        [string]$Message,
        [switch]$NoAccumulate
    )

    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$($Level.PadRight(5))] $Message"

    # Escribir al archivo estructurado
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    }

    # Acumular errores y warnings para el resumen final
    if (-not $NoAccumulate) {
        if ($Level -eq "ERROR") { $script:LogErrors.Add($Message) }
        if ($Level -eq "WARN")  { $script:LogWarns.Add($Message)  }
    }
}

function Write-LogSummary {
    $totalDuration = [math]::Round(((Get-Date) - $script:BuildStartTime).TotalSeconds, 1)

    # Cerrar último paso si quedó abierto
    if ($script:CurrentStepObj) {
        $now = Get-Date
        $script:CurrentStepObj.ElapsedSec = [math]::Round(($now - $script:CurrentStepObj.StartTime).TotalSeconds, 1)
        if ($script:CurrentStepObj.Status -eq "IN_PROGRESS") {
            $script:CurrentStepObj.Status = if ($script:LogErrors.Count -gt 0) { "ERROR" } else { "OK" }
        }
    }

    Write-LogEntry -Level "INIT" -Message ("=" * 64)
    Write-LogEntry -Level "INIT" -Message "RESUMEN FINAL"
    Write-LogEntry -Level "INFO" -Message "Duración total       : ${totalDuration}s"
    Write-LogEntry -Level "INFO" -Message "Errores registrados : $($script:LogErrors.Count)"
    Write-LogEntry -Level "INFO" -Message "Advertencias        : $($script:LogWarns.Count)"

    if ($script:LogErrors.Count -gt 0) {
        Write-LogEntry -Level "INIT" -Message "--- ERRORES DETECTADOS ---" -NoAccumulate
        $errSnapshot = @($script:LogErrors)
        foreach ($e in $errSnapshot) {
            Write-LogEntry -Level "ERROR" -Message $e -NoAccumulate
        }
    }

    if ($script:LogWarns.Count -gt 0) {
        Write-LogEntry -Level "INIT" -Message "--- ADVERTENCIAS ---" -NoAccumulate
        $warnSnapshot = @($script:LogWarns)
        foreach ($w in $warnSnapshot) {
            Write-LogEntry -Level "WARN" -Message $w -NoAccumulate
        }
    }

    if ($script:LogErrors.Count -eq 0) {
        Write-LogEntry -Level "OK"   -Message "Build completado sin errores."
    }

    Write-LogEntry -Level "INIT" -Message "Log estructurado    : $script:LogFile"
    Write-LogEntry -Level "INIT" -Message "AI Summary (MD)     : $script:AiSummaryFile"
    Write-LogEntry -Level "INIT" -Message "Transcript          : $script:TranscriptFile"
    Write-LogEntry -Level "INIT" -Message ("=" * 64)

    # Detener transcript
    try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch {}

    # Generar Reporte Markdown optimizado para IA (Opción 1)
    try {
        $overallStatus = if ($script:LogErrors.Count -eq 0) { "SUCCESS" } else { "FAILED" }
        $statusBadge   = if ($overallStatus -eq "SUCCESS") { "SUCCESS ✅" } else { "FAILED ❌" }

        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("# AI Diagnostic Report: New-OptimizedWindowsISO")
        [void]$sb.AppendLine("- **Status:** $statusBadge")
        [void]$sb.AppendLine("- **Timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        [void]$sb.AppendLine("- **Total Duration:** ${totalDuration}s")
        [void]$sb.AppendLine("- **Host:** $env:COMPUTERNAME | **User:** $env:USERNAME | **PowerShell:** $($PSVersionTable.PSVersion)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Configuration & Parameters")
        [void]$sb.AppendLine("| Parameter | Value |")
        [void]$sb.AppendLine("|---|---|")
        [void]$sb.AppendLine("| Source ISO | ``$SourceISO`` |")
        [void]$sb.AppendLine("| Output Directory | ``$OutputDir`` |")
        [void]$sb.AppendLine("| Local User | ``$script:LocalUser`` |")
        [void]$sb.AppendLine("| Language / Timezone | ``$Language`` / ``$Timezone`` |")
        [void]$sb.AppendLine("| Optimization Profile | ``$script:OptProfile`` |")
        [void]$sb.AppendLine("| Block OneDrive | ``$script:BlockOneDrive`` |")
        [void]$sb.AppendLine("| Zero-Touch | ``$($script:EnableZeroTouch)`` (Disk: ``$ZeroTouchDisk``) |")
        [void]$sb.AppendLine("| WIM Compression | ``$WimCompression`` |")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Execution Timeline")
        [void]$sb.AppendLine("| Step | Status | Elapsed | Details |")
        [void]$sb.AppendLine("|---|---|---|---|")

        foreach ($st in $script:LogSteps) {
            $stBadge = switch ($st.Status) {
                "OK"    { "OK ✅" }
                "WARN"  { "WARN ⚠️" }
                "ERROR" { "FAIL ❌" }
                default { "$($st.Status) ⚪" }
            }
            $cleanName = ($st.Name -replace '\|', '-').Trim()
            $cleanNote = ($st.Note -replace '\|', '-').Trim()
            [void]$sb.AppendLine("| $cleanName | $stBadge | $($st.ElapsedSec)s | $cleanNote |")
        }

        if ($script:LogErrors.Count -gt 0) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("## ❌ Errors Detected")
            [void]$sb.AppendLine('```text')
            foreach ($err in $script:LogErrors) {
                [void]$sb.AppendLine($err)
            }
            [void]$sb.AppendLine('```')
        }

        if ($script:LogWarns.Count -gt 0) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("## ⚠️ Warnings Logged")
            [void]$sb.AppendLine('```text')
            foreach ($warn in $script:LogWarns) {
                [void]$sb.AppendLine($warn)
            }
            [void]$sb.AppendLine('```')
        }

        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Generated Artifacts")
        [void]$sb.AppendLine("- **Structured Log:** ``$script:LogFile``")
        [void]$sb.AppendLine("- **Raw Transcript:** ``$script:TranscriptFile``")
        [void]$sb.AppendLine("- **AI Diagnostic:** ``$script:AiSummaryFile``")

        if ($script:AiSummaryFile) {
            [System.IO.File]::WriteAllText($script:AiSummaryFile, $sb.ToString(), [System.Text.Encoding]::UTF8)
        }
    } catch {
        Write-Warn "Error generando reporte Markdown AI_SUMMARY: $($_.Exception.Message)"
    }

    # Mostrar rutas de log en consola
    Write-Host ""
    Write-Host "  ┌─ Logs generados (Listos para análisis por IA) ────────────────" -ForegroundColor DarkCyan
    if ($script:AiSummaryFile)  { Write-Host "  │  AI Diagnostic MD : $script:AiSummaryFile  <-- Pásame este archivo" -ForegroundColor Green }
    if ($script:LogFile)        { Write-Host "  │  Log estructurado : $script:LogFile" -ForegroundColor Cyan }
    if ($script:TranscriptFile) { Write-Host "  │  Transcript       : $script:TranscriptFile" -ForegroundColor Cyan }
    if ($script:LogErrors.Count -gt 0) {
        Write-Host "  │" -ForegroundColor DarkCyan
        Write-Host "  │  [$($script:LogErrors.Count) ERROR(S) detectados — revisa el reporte para detalles]" -ForegroundColor Red
    } else {
        Write-Host "  │  Sin errores registrados." -ForegroundColor Green
    }
    Write-Host "  └───────────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
}

#------------------------------------------------------------------------------
# FUNCIONES AUXILIARES DE SALIDA
# (Modificadas para alimentar el log y el timeline de IA automáticamente)
#------------------------------------------------------------------------------

function Write-Banner {
    try {
        Clear-Host -ErrorAction SilentlyContinue
    } catch {
        # Si la consola no soporta Clear-Host, continuar igualmente.
    }

    Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║        GENERADOR DE ISO OPTIMIZADA PARA WINDOWS              ║
║        Windows 10 y 11 - Versión corregida                   ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n>>> $Message" -ForegroundColor Cyan
    Write-Host "    $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
    Write-LogEntry -Level "STEP" -Message $Message

    # Cerrar paso anterior si estaba abierto
    if ($script:CurrentStepObj) {
        $now = Get-Date
        $script:CurrentStepObj.ElapsedSec = [math]::Round(($now - $script:CurrentStepObj.StartTime).TotalSeconds, 1)
        if ($script:CurrentStepObj.Status -eq "IN_PROGRESS") {
            $script:CurrentStepObj.Status = "OK"
        }
    }

    $script:CurrentStepObj = [PSCustomObject]@{
        Name       = $Message
        StartTime  = Get-Date
        ElapsedSec = 0
        Status     = "IN_PROGRESS"
        Note       = ""
    }
    $script:LogSteps.Add($script:CurrentStepObj)
}

function Write-OK {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
    Write-LogEntry -Level "OK"   -Message $Message
    if ($script:CurrentStepObj) {
        if ($script:CurrentStepObj.Status -eq "IN_PROGRESS") {
            $script:CurrentStepObj.Status = "OK"
        }
        if (-not $script:CurrentStepObj.Note) {
            $script:CurrentStepObj.Note = $Message
        }
    }
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [WARN] $Message" -ForegroundColor Yellow
    Write-LogEntry -Level "WARN" -Message $Message
    if ($script:CurrentStepObj -and $script:CurrentStepObj.Status -ne "ERROR") {
        $script:CurrentStepObj.Status = "WARN"
        $script:CurrentStepObj.Note = $Message
    }
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "  [ERROR] $Message" -ForegroundColor Red
    Write-LogEntry -Level "ERROR" -Message $Message
    if ($script:CurrentStepObj) {
        $script:CurrentStepObj.Status = "ERROR"
        $script:CurrentStepObj.Note = $Message
    }
}

#------------------------------------------------------------------------------
# VALIDACIÓN DE PRIVILEGIOS
#------------------------------------------------------------------------------

function Test-Admin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

#------------------------------------------------------------------------------
# DEPENDENCIAS: 7-ZIP
#------------------------------------------------------------------------------

function Test-7ZipInstalled {
    $paths = @(
        "${env:ProgramFiles}\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
        "$env:LOCALAPPDATA\Programs\7-Zip\7z.exe"
    )

    return ($paths | Where-Object { Test-Path $_ } | Select-Object -First 1)
}

function Install-Dependencies {
    Write-Step "Instalando dependencias necesarias..."

    $depsOk = $true

    $7zPath = Test-7ZipInstalled

    if (-not $7zPath) {
        Write-Host "    Instalando 7-Zip vía winget..." -ForegroundColor Gray

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            try {
                winget install --id 7zip.7zip --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null

                # Refrescar PATH de la sesión actual
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                            [System.Environment]::GetEnvironmentVariable("Path", "User")

                $7zPath = Test-7ZipInstalled

                if ($7zPath) {
                    Write-OK "7-Zip instalado: $7zPath"
                } else {
                    throw "7-Zip no apareció después de instalar."
                }
            } catch {
                Write-Warn "No se pudo instalar 7-Zip automáticamente: $_"
                Write-Warn "Descárguelo manualmente desde: https://7-zip.org"
                $depsOk = $false
            }
        } else {
            Write-Warn "winget no está disponible. Instale 7-Zip manualmente."
            $depsOk = $false
        }
    } else {
        Write-OK "7-Zip ya instalado: $7zPath"
    }

    if ($depsOk) {
        Write-OK "Dependencias listas."
    } else {
        Write-Warn "Algunas dependencias no se instalaron."
    }

    return $depsOk
}

#------------------------------------------------------------------------------
# OSCDIMG
#------------------------------------------------------------------------------

function Test-OSCDImgInstalled {
    $found = $null

    # Buscar primero en paquetes Winget
    $wingetPackages = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'

    if (Test-Path $wingetPackages) {
        $found = Get-ChildItem -Path $wingetPackages -Recurse -Filter "oscdimg.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match 'Microsoft\.OSCDIMG' } |
            Select-Object -First 1 -ExpandProperty FullName
    }

    # Buscar en TEMP por si se descargó manualmente
    if (-not $found) {
        $found = Get-ChildItem -Path $env:TEMP, "$env:LOCALAPPDATA\Temp" -Filter "oscdimg.exe" -Depth 3 -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
    }

    # Buscar en rutas típicas del Windows ADK (x64 y ARM64)
    if (-not $found) {
        $adkPaths = @(
            "$env:ProgramFiles\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
            "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
            "$env:ProgramFiles\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\arm64\Oscdimg\oscdimg.exe"
        )

        foreach ($candidate in $adkPaths) {
            if (Test-Path $candidate) {
                $found = $candidate
                break
            }
        }
    }

    # Si no aparece, intentar instalar con Winget
    if (-not $found) {
        Write-Host "    Instalando oscdimg.exe vía winget..." -ForegroundColor Gray

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            try {
                winget install --id Microsoft.OSCDIMG --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
                Start-Sleep -Seconds 2

                if (Test-Path $wingetPackages) {
                    $found = Get-ChildItem -Path $wingetPackages -Recurse -Filter "oscdimg.exe" -ErrorAction SilentlyContinue |
                        Where-Object { $_.FullName -match 'Microsoft\.OSCDIMG' } |
                        Select-Object -First 1 -ExpandProperty FullName
                }

                if ($found) {
                    Write-OK "oscdimg.exe instalado vía winget."
                } else {
                    Write-Warn "winget install completó pero oscdimg.exe no apareció en las rutas esperadas."
                    Write-Warn "Ruta esperada: $env:LOCALAPPDATA\Microsoft\WinGet\Packages\Microsoft.OSCDIMG*\oscdimg.exe"
                    Write-Warn "Alternativamente, instale el Windows ADK desde: https://learn.microsoft.com/windows-hardware/get-started/adk-install"
                }
            } catch {
                Write-Warn "winget install falló: $_"
            }
        } else {
            Write-Warn "winget no está disponible. Instale oscdimg manualmente desde el Windows ADK."
        }
    }

    return $found
}

#------------------------------------------------------------------------------
# UTILIDAD: CONVERTIR NÚMERO DE BUILD A VERSIÓN DE WINDOWS
#------------------------------------------------------------------------------

function Convert-BuildToWindowsVersion {
    param([string]$VersionString)

    if ([string]::IsNullOrWhiteSpace($VersionString)) {
        return $null
    }

    if ($VersionString -match '(\d+)\.(\d+)\.(\d+)') {
        $build = 0

        if ([int]::TryParse($Matches[3], [ref]$build)) {
            if ($build -ge 22000) {
                return "11"
            }

            if ($build -ge 10240) {
                return "10"
            }
        }
    }

    return $null
}

#------------------------------------------------------------------------------
# LISTADO DE ÍNDICES WIM
#------------------------------------------------------------------------------

function Get-WimImageList {
    param([string]$WimPath)

    $list = @()

    # Intento 1: cmdlet DISM nativo
    try {
        $wimObjs = Get-WindowsImage -ImagePath $WimPath -ErrorAction Stop

        foreach ($img in $wimObjs) {
            $list += [PSCustomObject]@{
                Index = [string]$img.ImageIndex
                Name  = [string]$img.ImageName
            }
        }

        if ($list.Count -gt 0) {
            return $list
        }
    } catch {
        # Ignorar y probar fallback
    }

    # Intento 2: parsing de dism.exe
    try {
        $rawText = & dism.exe /Get-ImageInfo /ImageFile:"$WimPath" 2>&1 | Out-String
        $blocks  = $rawText -split '(?i)(?=(?:Index|Índice)\s*:)'

        foreach ($block in $blocks) {
            if ($block -match '(?i)(?:Index|Índice)\s*:\s*(\d+)') {
                $idx  = $Matches[1]
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
    } catch {
        # Ignorar fallback fallido
    }

    if ($list.Count -eq 0) {
        $list += [PSCustomObject]@{
            Index = "1"
            Name  = "Índice 1"
        }
    }

    return $list
}

#------------------------------------------------------------------------------
# DETECCIÓN DE VERSIÓN DE WINDOWS
#------------------------------------------------------------------------------

function Detect-WindowsVersion {
    param(
        [string]$IsoPath,
        [string]$ExtractedDir,
        [string]$ForcedVersion
    )

    # 1. Versión forzada por parámetro
    if ($ForcedVersion -eq "10" -or $ForcedVersion -eq "11") {
        Write-Host "    Versión forzada por parámetro: Windows $ForcedVersion" -ForegroundColor Gray
        return $ForcedVersion
    }

    # 2. Si ya está extraída, usar setup.exe como fuente más fiable
    if ($ExtractedDir -and (Test-Path $ExtractedDir)) {
        $setupExe = Get-ChildItem $ExtractedDir -Recurse -Filter "setup.exe" -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($setupExe) {
            try {
                $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($setupExe.FullName)
                $candidate   = $null

                if ($versionInfo.FileVersion) {
                    $candidate = Convert-BuildToWindowsVersion -VersionString $versionInfo.FileVersion
                }

                if (-not $candidate -and $versionInfo.ProductVersion) {
                    $candidate = Convert-BuildToWindowsVersion -VersionString $versionInfo.ProductVersion
                }

                if ($candidate) {
                    Write-Host "    Versión detectada por setup.exe: Windows $candidate" -ForegroundColor Gray
                    return $candidate
                }
            } catch {
                # Continuar con otros métodos
            }
        }

        # 3. Intentar detectar desde install.wim/install.esd vía DISM
        $wimFile = Get-ChildItem $ExtractedDir -Recurse -Filter "install.*" -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in '.wim', '.esd' } |
            Select-Object -First 1

        if ($wimFile -and (Get-Command dism.exe -ErrorAction SilentlyContinue)) {
            try {
                $wimInfo = & dism.exe /Get-ImageInfo /ImageFile:"$($wimFile.FullName)" /Index:1 2>&1 | Out-String

                if ($wimInfo -match '(?i)(?:Version|Versión)\s*:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
                    $candidate = Convert-BuildToWindowsVersion -VersionString $Matches[1]

                    if ($candidate) {
                        Write-Host "    Versión detectada por DISM: Windows $candidate" -ForegroundColor Gray
                        return $candidate
                    }
                }
            } catch {
                # Continuar con otros métodos
            }
        }
    }

    # 4. Intentar detectar por etiqueta de volumen
    if ($IsoPath -and (Test-Path $IsoPath)) {
        $mounted = $null

        try {
            $mounted = Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop
            $volume  = $mounted | Get-Volume -ErrorAction Stop

            if ($volume.FileSystemLabel) {
                $label = $volume.FileSystemLabel

                if ($label -match '(?i)WIN11|WINDOWS 11|W11') {
                    Write-Host "    Versión detectada por etiqueta de volumen: Windows 11" -ForegroundColor Gray
                    return "11"
                }

                if ($label -match '(?i)WIN10|WINDOWS 10|W10') {
                    Write-Host "    Versión detectada por etiqueta de volumen: Windows 10" -ForegroundColor Gray
                    return "10"
                }
            }
        } catch {
            # Ignorar y continuar
        } finally {
            if ($mounted) {
                Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }

    # 5. Detección por nombre de archivo, con Windows 10 primero
    if ($IsoPath) {
        $name = Split-Path $IsoPath -Leaf

        # Windows 10 primero para evitar falso positivo con 22H2
        if ($name -match '(?i)\bwin(?:dows)?[ _\-]?10\b|windows[ _\-]?10|10h[12]|1904[145]|ltsc.*2019|ltsc.*2021') {
            Write-Host "    Versión detectada por nombre de archivo: Windows 10" -ForegroundColor Gray
            return "10"
        }

        if ($name -match '(?i)\bwin(?:dows)?[ _\-]?11\b|windows[ _\-]?11|11h[12]|2[2-9]h2') {
            Write-Host "    Versión detectada por nombre de archivo: Windows 11" -ForegroundColor Gray
            return "11"
        }
    }

    # 6. Fallback interactivo
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
# MENÚ DE SELECCIÓN - FALLBACK TEXTO
#------------------------------------------------------------------------------

function Invoke-FallbackSelectionMenu {
    param(
        [string]$Title,
        [string[]]$Options,
        [string[]]$Descriptions,
        [int]$DefaultIndex = 0
    )

    if ($Options.Count -eq 0) {
        return -1
    }

    if ($DefaultIndex -lt 0 -or $DefaultIndex -ge $Options.Count) {
        $DefaultIndex = 0
    }

    Write-Host ""
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $Options.Count; $i++) {
        $desc = ""

        if ($Descriptions -and $i -lt $Descriptions.Count) {
            $desc = "  $($Descriptions[$i])"
        }

        Write-Host "  [$($i + 1)] $($Options[$i])$desc" -ForegroundColor White
    }

    Write-Host ""
    $defaultNumber = $DefaultIndex + 1
    $choice = Read-Host "  Seleccione una opción 1-$($Options.Count) (Enter = $defaultNumber)"

    if ([string]::IsNullOrWhiteSpace($choice)) {
        return $DefaultIndex
    }

    $choiceNumber = 0

    if ([int]::TryParse($choice, [ref]$choiceNumber) -and
        $choiceNumber -ge 1 -and
        $choiceNumber -le $Options.Count) {
        return ($choiceNumber - 1)
    }

    return $DefaultIndex
}

#------------------------------------------------------------------------------
# MENÚ DE SELECCIÓN - CONSOLA CON FLECHAS
#------------------------------------------------------------------------------

function Invoke-SelectionMenu {
    param(
        [string]$Title,
        [string[]]$Options,
        [string[]]$Descriptions,
        [int]$DefaultIndex = 0
    )

    if ($Options.Count -eq 0) {
        return -1
    }

    if ($DefaultIndex -lt 0 -or $DefaultIndex -ge $Options.Count) {
        $DefaultIndex = 0
    }

    # Si la entrada está redirigida, usar menú por texto simple.
    $interactive = $true

    try {
        if ([System.Console]::IsInputRedirected) {
            $interactive = $false
        }
    } catch {
        $interactive = $false
    }

    if (-not $interactive) {
        return Invoke-FallbackSelectionMenu -Title $Title -Options $Options -Descriptions $Descriptions -DefaultIndex $DefaultIndex
    }

    # Ancho seguro para consola
    $winWidth = 72

    try {
        $currentWidth = [System.Console]::WindowWidth - 4
        $winWidth = [Math]::Max(40, [Math]::Min($currentWidth, 72))
    } catch {
        $winWidth = 72
    }

    $border = "═" * $winWidth
    $cursor = $DefaultIndex

    # Reservar espacio en pantalla
    $linesNeeded = $Options.Count + 5
    $startRow = 0

    try {
        $startRow = [System.Console]::CursorTop

        for ($r = 0; $r -lt $linesNeeded; $r++) {
            Write-Host ""
        }

        [System.Console]::CursorVisible = $false
    } catch {
        return Invoke-FallbackSelectionMenu -Title $Title -Options $Options -Descriptions $Descriptions -DefaultIndex $DefaultIndex
    }

    while ($true) {
        try {
            [System.Console]::SetCursorPosition(0, $startRow)

            Write-Host "  ╔$border╗" -ForegroundColor DarkCyan

            $titleText = if ($Title.Length -gt $winWidth) {
                $Title.Substring(0, $winWidth)
            } else {
                $Title.PadRight($winWidth)
            }

            Write-Host "  ║ $titleText║" -ForegroundColor Cyan
            Write-Host "  ╠$border╣" -ForegroundColor DarkCyan

            for ($i = 0; $i -lt $Options.Count; $i++) {
                $desc = ""

                if ($Descriptions -and $i -lt $Descriptions.Count) {
                    $desc = "  $($Descriptions[$i])"
                }

                $marker = if ($i -eq $cursor) { "▶" } else { " " }
                $lineText = "$marker $($Options[$i])$desc"

                if ($lineText.Length -gt $winWidth) {
                    $lineText = $lineText.Substring(0, $winWidth)
                } else {
                    $lineText = $lineText.PadRight($winWidth)
                }

                if ($i -eq $cursor) {
                    Write-Host "  ║" -NoNewline -ForegroundColor DarkCyan
                    Write-Host " $lineText" -NoNewline -ForegroundColor Black -BackgroundColor Cyan
                    Write-Host "║" -ForegroundColor DarkCyan
                } else {
                    Write-Host "  ║ $lineText║" -ForegroundColor DarkGray
                }
            }

            Write-Host "  ╠$border╣" -ForegroundColor DarkCyan

            $hint = "  ↑↓ Mover   ENTER Confirmar"

            if ($hint.Length -gt $winWidth) {
                $hint = $hint.Substring(0, $winWidth)
            } else {
                $hint = $hint.PadRight($winWidth)
            }

            Write-Host "  ║ $hint║" -ForegroundColor DarkGray
            Write-Host "  ╚$border╝" -ForegroundColor DarkCyan

            $key = [System.Console]::ReadKey($true)

            switch ($key.Key) {
                'UpArrow' {
                    $cursor = ($cursor - 1 + $Options.Count) % $Options.Count
                }

                'DownArrow' {
                    $cursor = ($cursor + 1) % $Options.Count
                }

                'Enter' {
                    try {
                        [System.Console]::CursorVisible = $true
                    } catch {
                        # Ignorar si la consola no permite restaurar cursor
                    }

                    return $cursor
                }
            }
        } catch {
            try {
                [System.Console]::CursorVisible = $true
            } catch {
                # Ignorar
            }

            return Invoke-FallbackSelectionMenu -Title $Title -Options $Options -Descriptions $Descriptions -DefaultIndex $DefaultIndex
        }
    }
}

#------------------------------------------------------------------------------
# WIZARD DE CONFIGURACIÓN REGIONAL Y CUENTA
#------------------------------------------------------------------------------

function Invoke-WizardConfig {
    param(
        [System.Collections.IDictionary]$ScriptBoundParameters = @{},
        [switch]$SkipWizard
    )

    if ($SkipWizard) {
        Write-Host "`n  Wizard omitido por parámetro." -ForegroundColor DarkGray
        return
    }

    # Solo se activa si alguno de los parámetros clave NO fue pasado explícitamente.
    # Locale no dispara el wizard porque hereda de Language si queda vacío.
    $needsWizard = (-not $ScriptBoundParameters.ContainsKey('Language')) -or
                   (-not $ScriptBoundParameters.ContainsKey('Timezone')) -or
                   (-not $ScriptBoundParameters.ContainsKey('LocalUser')) -or
                   (-not $ScriptBoundParameters.ContainsKey('LocalPassword'))

    if (-not $needsWizard) {
        Write-Host "`n  Configuración por parámetros CLI detectada. Omitiendo wizard interactivo." -ForegroundColor DarkGray

        if ([string]::IsNullOrWhiteSpace($script:Locale)) {
            $script:Locale = $script:Language
        }

        return
    }

    $winWidth = 72

    try {
        $currentWidth = [System.Console]::WindowWidth - 4
        $winWidth = [Math]::Max(40, [Math]::Min($currentWidth, 72))
    } catch {
        $winWidth = 72
    }

    $border = "═" * $winWidth

    Write-Host ""
    Write-Host "  ╔$border╗" -ForegroundColor Magenta

    $h1 = "  ASISTENTE DE CONFIGURACIÓN"

    if ($h1.Length -gt $winWidth) {
        $h1 = $h1.Substring(0, $winWidth)
    } else {
        $h1 = $h1.PadRight($winWidth)
    }

    Write-Host "  ║ $h1║" -ForegroundColor Magenta

    $h2 = "  Configure idioma, zona horaria y cuenta de usuario."

    if ($h2.Length -gt $winWidth) {
        $h2 = $h2.Substring(0, $winWidth)
    } else {
        $h2 = $h2.PadRight($winWidth)
    }

    Write-Host "  ║ $h2║" -ForegroundColor DarkGray
    Write-Host "  ╚$border╝" -ForegroundColor Magenta
    Write-Host ""

    #==========================================================================
    # PASO 1: Idioma UI
    #==========================================================================

    if (-not $ScriptBoundParameters.ContainsKey('Language')) {
        Write-Host "  PASO 1/6 — Idioma de la interfaz del sistema (UILanguage)" -ForegroundColor Cyan
        Write-Host "  Controla el idioma de los menús y pantallas de Windows." -ForegroundColor DarkGray
        Write-Host ""

        $langOptions = @(
            'es-ES'
            'en-US'
            'pt-BR'
            'fr-FR'
            'de-DE'
            'it-IT'
            'nl-NL'
            'ja-JP'
            'zh-CN'
            'ko-KR'
        )

        $langDescs = @(
            '[Español]'
            '[English]'
            '[Português]'
            '[Français]'
            '[Deutsch]'
            '[Italiano]'
            '[Nederlands]'
            '[日本語]'
            '[中文]'
            '[한국어]'
        )

        $sysLang = (Get-Culture).Name
        $defLangIdx = [Array]::IndexOf($langOptions, $sysLang)

        if ($defLangIdx -lt 0) {
            $defLangIdx = 0
        }

        $idx = Invoke-SelectionMenu -Title "PASO 1/6 — Idioma de la interfaz (UILanguage)" `
                                    -Options $langOptions `
                                    -Descriptions $langDescs `
                                    -DefaultIndex $defLangIdx

        $script:Language = $langOptions[$idx]

        Write-Host ""
        Write-Host "  ✔ Idioma UI: $($script:Language)" -ForegroundColor Green
        Write-Host ""
    }

    #==========================================================================
    # PASO 2: Locale regional
    #==========================================================================

    if (-not $ScriptBoundParameters.ContainsKey('Locale')) {
        Write-Host "  PASO 2/6 — Región / Formato local (SystemLocale + UserLocale)" -ForegroundColor Cyan
        Write-Host "  Controla fechas, moneda y formatos numéricos." -ForegroundColor DarkGray
        Write-Host "  Puede ser distinto del idioma de la interfaz." -ForegroundColor DarkGray
        Write-Host ""

        $localeOptions = @(
            'es-AR'
            'es-BO'
            'es-CL'
            'es-CO'
            'es-CR'
            'es-CU'
            'es-DO'
            'es-EC'
            'es-ES'
            'es-GT'
            'es-HN'
            'es-MX'
            'es-NI'
            'es-PA'
            'es-PE'
            'es-PR'
            'es-PY'
            'es-SV'
            'es-US'
            'es-UY'
            'es-VE'
            'pt-BR'
            'pt-PT'
            'en-US'
            'en-GB'
            'en-AU'
            'en-CA'
            'fr-FR'
            'fr-CA'
            'de-DE'
            'it-IT'
            'nl-NL'
            'ja-JP'
            'zh-CN'
            'ko-KR'
        )

        $localeDescs = @(
            '[Argentina]'
            '[Bolivia]'
            '[Chile]'
            '[Colombia]'
            '[Costa Rica]'
            '[Cuba]'
            '[República Dominicana]'
            '[Ecuador]'
            '[España]'
            '[Guatemala]'
            '[Honduras]'
            '[México]'
            '[Nicaragua]'
            '[Panamá]'
            '[Perú]'
            '[Puerto Rico]'
            '[Paraguay]'
            '[El Salvador]'
            '[EE.UU. Español]'
            '[Uruguay]'
            '[Venezuela]'
            '[Brasil]'
            '[Portugal]'
            '[EE.UU.]'
            '[Reino Unido]'
            '[Australia]'
            '[Canadá Inglés]'
            '[Francia]'
            '[Canadá Francés]'
            '[Alemania]'
            '[Italia]'
            '[Países Bajos]'
            '[Japón]'
            '[China]'
            '[Corea del Sur]'
        )

        $sysCulture = (Get-Culture).Name
        $defLocIdx = [Array]::IndexOf($localeOptions, $sysCulture)

        if ($defLocIdx -lt 0) {
            $defLocIdx = [Array]::IndexOf($localeOptions, $script:Language)
        }

        if ($defLocIdx -lt 0) {
            $defLocIdx = 0
        }

        $idx = Invoke-SelectionMenu -Title "PASO 2/6 — Región / Formato local" `
                                    -Options $localeOptions `
                                    -Descriptions $localeDescs `
                                    -DefaultIndex $defLocIdx

        $script:Locale = $localeOptions[$idx]

        Write-Host ""
        Write-Host "  ✔ Región: $($script:Locale)" -ForegroundColor Green
        Write-Host ""
    }

    #==========================================================================
    # PASO 3: Zona horaria
    #==========================================================================

    if (-not $ScriptBoundParameters.ContainsKey('Timezone')) {
        Write-Host "  PASO 3/6 — Zona horaria" -ForegroundColor Cyan
        Write-Host "  Valores válidos según Windows Time Zone IDs." -ForegroundColor DarkGray
        Write-Host ""

        $tzOptions = @(
            'Romance Standard Time'
            'SA Pacific Standard Time'
            'Argentina Standard Time'
            'Montevideo Standard Time'
            'Chile Standard Time'
            'Venezuela Standard Time'
            'Central America Standard Time'
            'Mexico Standard Time'
            'Eastern Standard Time'
            'Central Standard Time'
            'Mountain Standard Time'
            'Pacific Standard Time'
            'UTC'
            'GMT Standard Time'
            'W. Europe Standard Time'
            'Central Europe Standard Time'
            'E. Europe Standard Time'
            'Russian Standard Time'
            'China Standard Time'
            'Tokyo Standard Time'
        )

        $tzDescs = @(
            '[Madrid, París, Bruselas]'
            '[Bogotá, Lima, Quito]'
            '[Buenos Aires]'
            '[Montevideo]'
            '[Santiago]'
            '[Caracas]'
            '[Centroamérica]'
            '[Ciudad de México]'
            '[Nueva York, Miami]'
            '[Chicago, Dallas]'
            '[Denver, Phoenix]'
            '[Los Ángeles, Seattle]'
            '[UTC]'
            '[Londres, Dublín]'
            '[Berlín, Roma, Ámsterdam]'
            '[Budapest, Varsovia]'
            '[Atenas, Helsinki]'
            '[Moscú]'
            '[Beijing, Shanghai]'
            '[Tokio, Osaka]'
        )

        $systz = try {
            (Get-TimeZone).Id
        } catch {
            ''
        }

        $defTzIdx = [Array]::IndexOf($tzOptions, $systz)

        if ($defTzIdx -lt 0) {
            $defTzIdx = 0
        }

        $idx = Invoke-SelectionMenu -Title "PASO 3/6 — Zona horaria" `
                                    -Options $tzOptions `
                                    -Descriptions $tzDescs `
                                    -DefaultIndex $defTzIdx

        $script:Timezone = $tzOptions[$idx]

        Write-Host ""
        Write-Host "  ✔ Zona horaria: $($script:Timezone)" -ForegroundColor Green
        Write-Host ""
    }

    #==========================================================================
    # PASO 4: Teclado
    #==========================================================================

    if (-not $ScriptBoundParameters.ContainsKey('KeyboardOverride')) {
        Write-Host "  PASO 4/6 — Layout de teclado" -ForegroundColor Cyan
        Write-Host ""

        $kbOptions = @(
            "(igual que idioma '$($script:Language)')"
            'es-ES'
            'es-419'
            'en-US'
            'pt-BR'
            'fr-FR'
            'de-DE'
            'it-IT'
        )

        $kbDescs = @(
            '[Recomendado]'
            '[Español España]'
            '[Español Latinoamérica]'
            '[English US]'
            '[Português Brasil]'
            '[Français AZERTY]'
            '[Deutsch QWERTZ]'
            '[Italiano QWERTY]'
        )

        $idx = Invoke-SelectionMenu -Title "PASO 4/6 — Layout de teclado" `
                                    -Options $kbOptions `
                                    -Descriptions $kbDescs `
                                    -DefaultIndex 0

        if ($idx -eq 0) {
            $script:KeyboardOverride = ''
        } else {
            $script:KeyboardOverride = $kbOptions[$idx]
        }

        Write-Host ""

        $kbDisplay = if ($script:KeyboardOverride) {
            $script:KeyboardOverride
        } else {
            "$($script:Language) (igual que idioma)"
        }

        Write-Host "  ✔ Teclado: $kbDisplay" -ForegroundColor Green
        Write-Host ""
    }

    #==========================================================================
    # PASO 5: Usuario y contraseña
    #==========================================================================

    if ((-not $ScriptBoundParameters.ContainsKey('LocalUser')) -or
        (-not $ScriptBoundParameters.ContainsKey('LocalPassword'))) {

        Write-Host "  PASO 5/6 — Cuenta de usuario local" -ForegroundColor Cyan
        Write-Host ""

        if (-not $ScriptBoundParameters.ContainsKey('LocalUser')) {
            do {
                $userInput = Read-Host "  Nombre de usuario (Enter = '$($script:LocalUser)')"

                if ([string]::IsNullOrWhiteSpace($userInput)) {
                    $userInput = $script:LocalUser
                }

                $validUser = $userInput -match '^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ0-9 _\-\.]{1,20}$'

                $reservedUsers = @(
                    'administrator'
                    'guest'
                    'defaultaccount'
                    'system'
                    'wdagutilityaccount'
                )

                if ($validUser -and ($reservedUsers -contains $userInput.ToLower())) {
                    $validUser = $false
                    Write-Host "  ✘ Ese nombre está reservado por Windows." -ForegroundColor Red
                }

                if (-not $validUser) {
                    Write-Host "  ✘ Nombre inválido. Usa letras, números, espacio, guion o punto (máx. 20)." -ForegroundColor Red
                }
            } while (-not $validUser)

            $script:LocalUser = $userInput

            Write-Host "  ✔ Usuario: $($script:LocalUser)" -ForegroundColor Green
            Write-Host ""
        }

        if (-not $ScriptBoundParameters.ContainsKey('LocalPassword')) {
            Write-Host "  Contraseña de la cuenta (Enter sin escribir nada = sin contraseña):" -ForegroundColor Gray

            do {
                $pass1 = Read-Host "  Contraseña" -AsSecureString
                $pass2 = Read-Host "  Confirmar" -AsSecureString

                $bstr1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass1)
                $bstr2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass2)

                $plain1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr1)
                $plain2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr2)

                $passMatch = ($plain1 -eq $plain2)

                if (-not $passMatch) {
                    Write-Host "  ✘ Las contraseñas no coinciden. Intenta de nuevo." -ForegroundColor Red
                    Write-Host ""
                }

                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr1)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2)
            } while (-not $passMatch)

            $script:LocalPassword = $plain1

            Remove-Variable plain1, plain2 -ErrorAction SilentlyContinue

            if ([string]::IsNullOrEmpty($script:LocalPassword)) {
                Write-Host "  ✔ Sin contraseña (cuenta abierta)" -ForegroundColor Yellow
            } else {
                Write-Host "  ✔ Contraseña configurada correctamente." -ForegroundColor Green
            }

            Write-Host ""
        }
    }

    #==========================================================================
    # PASO 6: Tweaks visuales offline
    #==========================================================================

    if (-not $ScriptBoundParameters.ContainsKey('InjectVisualTweaks')) {
        Write-Host "  PASO 6/6 — Tweaks Visuales Offline" -ForegroundColor Cyan
        Write-Host "  Inyecta modo oscuro y ajustes de explorador en el perfil default." -ForegroundColor DarkGray
        Write-Host ""

        $uiOptions = @(
            'Sí (Inyectar Modo Oscuro y ajustes visuales)'
            'No (Instalación estándar de Windows)'
        )

        $idx = Invoke-SelectionMenu -Title "Inyectar Tweaks Visuales" `
                                    -Options $uiOptions `
                                    -DefaultIndex 0

        if ($idx -eq 0) {
            $script:InjectVisualTweaks = $true
        } else {
            $script:InjectVisualTweaks = $false
        }

        Write-Host ""

        $uiStatus = if ($script:InjectVisualTweaks) {
            'Sí'
        } else {
            'No'
        }

        Write-Host "  ✔ Tweaks Visuales: $uiStatus" -ForegroundColor Green
        Write-Host ""
    }

    # Si Locale quedó vacío, heredar Language.
    if ([string]::IsNullOrWhiteSpace($script:Locale)) {
        $script:Locale = $script:Language
    }

    #==========================================================================
    # RESUMEN
    #==========================================================================

    Write-Host "  ╔$border╗" -ForegroundColor DarkGreen

    $rTitle = "  RESUMEN DE CONFIGURACIÓN"

    if ($rTitle.Length -gt $winWidth) {
        $rTitle = $rTitle.Substring(0, $winWidth)
    } else {
        $rTitle = $rTitle.PadRight($winWidth)
    }

    Write-Host "  ║ $rTitle║" -ForegroundColor Green
    Write-Host "  ╠$border╣" -ForegroundColor DarkGreen

    $kbFinal = if ($script:KeyboardOverride) {
        $script:KeyboardOverride
    } else {
        "$($script:Language) (igual que idioma)"
    }

    $locFinal = if ($script:Locale) {
        $script:Locale
    } else {
        "$($script:Language) (igual que idioma UI)"
    }

    $pwdMask = if ([string]::IsNullOrEmpty($script:LocalPassword)) {
        '(sin contraseña)'
    } else {
        '●●●●●●●●'
    }

    $uiTweakStatus = if ($script:InjectVisualTweaks) {
        'Sí'
    } else {
        'No'
    }

    $summaryLines = @(
        "  Idioma UI       : $($script:Language)"
        "  Región / Formato: $locFinal"
        "  Zona Horaria    : $($script:Timezone)"
        "  Teclado         : $kbFinal"
        "  Usuario         : $($script:LocalUser)"
        "  Contraseña      : $pwdMask"
        "  Tweaks Visuales : $uiTweakStatus"
    )

    foreach ($line in $summaryLines) {
        if ($line.Length -gt $winWidth) {
            $line = $line.Substring(0, $winWidth)
        } else {
            $line = $line.PadRight($winWidth)
        }

        Write-Host "  ║ $line║" -ForegroundColor White
    }

    Write-Host "  ╚$border╝" -ForegroundColor DarkGreen
    Write-Host ""

    Write-Host "  ¿Continuar con esta configuración? [S/N]: " -ForegroundColor Yellow -NoNewline
    $confirm = Read-Host

    if ($confirm -notmatch '^[Ss]$') {
        Write-Host "`n  Operación cancelada por el usuario." -ForegroundColor Red
        exit 0
    }

    Write-Host ""
}

#------------------------------------------------------------------------------
# ELECCIONES DE DESPLIEGUE: PERFIL Y ONEDRIVE
#------------------------------------------------------------------------------

function Invoke-DeploymentChoices {
    param(
        [System.Collections.IDictionary]$ScriptBoundParameters = @{},
        [switch]$SkipAutoUnattend
    )

    #==========================================================================
    # PERFIL DE OPTIMIZACIÓN
    #==========================================================================

    if ($ScriptBoundParameters.ContainsKey('OptimizationProfile')) {
        if ($script:OptProfile -in @('1', '2', '3')) {
            Write-Host "  Perfil de optimización forzado por parámetro: $script:OptProfile" -ForegroundColor DarkGray
        } else {
            Write-Warn "Perfil de optimización inválido. Usando perfil 1."
            $script:OptProfile = '1'
        }
    } else {
        if (-not $SkipAutoUnattend) {
            Write-Host ""
            Write-Host "  PERFILES DE OPTIMIZACIÓN (DEBLOAT)" -ForegroundColor Cyan
            Write-Host ""

            $profileOptions = @(
                '1 - Conservador (Laptops/General)'
                '2 - Gaming (Elimina bloatware agresivo)'
                '3 - Hardcore Barebones (SOLO TORRES LAN)'
            )

            $profileDescs = @(
                '[Mantiene Wi-Fi, Bluetooth y apps básicas]'
                '[Elimina bloatware y telemetría; mantiene Wi-Fi/Bluetooth]'
                '[Extremo: puede deshabilitar Wi-Fi, Bluetooth, impresión y búsqueda]'
            )

            $idx = Invoke-SelectionMenu -Title "Seleccione perfil de optimización" `
                                        -Options $profileOptions `
                                        -Descriptions $profileDescs `
                                        -DefaultIndex ([int]$script:OptProfile - 1)

            $script:OptProfile = [string]($idx + 1)

            Write-Host ""
            Write-Host "  ✔ Perfil seleccionado: $script:OptProfile" -ForegroundColor Green
        }
    }

    #==========================================================================
    # ONEDRIVE
    #==========================================================================

    if ($ScriptBoundParameters.ContainsKey('NoBlockOneDrive')) {
        $script:BlockOneDrive = -not $NoBlockOneDrive.IsPresent
        Write-Host "  Bloqueo de OneDrive definido por parámetro." -ForegroundColor DarkGray
    } else {
        if (-not $SkipAutoUnattend) {
            Write-Host ""
            Write-Host "  ¿Desea bloquear la instalación automática de OneDrive?" -ForegroundColor Cyan

            $odOptions = @(
                'Sí (bloquear OneDrive)'
                'No (conservar OneDrive)'
            )

            $defaultIndex = 0

            if (-not $script:BlockOneDrive) {
                $defaultIndex = 1
            }

            $idx = Invoke-SelectionMenu -Title "Bloqueo de OneDrive" `
                                        -Options $odOptions `
                                        -DefaultIndex $defaultIndex

            if ($idx -eq 0) {
                $script:BlockOneDrive = $true
            } else {
                $script:BlockOneDrive = $false
            }

            Write-Host ""

            $odStatus = if ($script:BlockOneDrive) {
                'Sí'
            } else {
                'No'
            }

            Write-Host "  ✔ Bloquear OneDrive: $odStatus" -ForegroundColor Green
        }
    }
}

# FUNCIÓN: COMPROBAR ESPACIO LIBRE APROXIMADO
#------------------------------------------------------------------------------

function Test-MinimumFreeSpace {
    param(
        [string]$Path,
        [long]$RequiredBytes
    )

    try {
        $driveQualifier = Split-Path -Qualifier $Path -ErrorAction SilentlyContinue

        if (-not $driveQualifier) {
            return $true
        }

        $driveLetter = $driveQualifier.TrimEnd(':')

        if (-not $driveLetter) {
            return $true
        }

        $volume = Get-Volume -DriveLetter $driveLetter -ErrorAction Stop

        if ($null -eq $volume.SizeRemaining) {
            return $true
        }

        return ($volume.SizeRemaining -ge $RequiredBytes)
    } catch {
        # Si no se puede comprobar, no bloqueamos el proceso.
        return $true
    }
}

# FUNCIÓN: RESOLVER ISO DE ORIGEN
#------------------------------------------------------------------------------

function Resolve-SourceISO {
    param(
        [string]$SourceISO
    )

    # Si ya viene por parámetro y existe, usarla directamente.
    if ($SourceISO -and (Test-Path $SourceISO -PathType Leaf)) {
        $resolved = (Resolve-Path $SourceISO).Path

        if ((Get-Item $resolved).Extension -ne '.iso') {
            Write-Warn "El archivo seleccionado no tiene extensión .iso."
        }

        return $resolved
    }

    while ($true) {
        Write-Host ""
        Write-Host "  No se especificó una ISO de origen válida." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  [1] Buscar archivos ISO en una carpeta" -ForegroundColor Cyan
        Write-Host "  [2] Escribir la ruta completa del archivo ISO" -ForegroundColor Cyan
        Write-Host "  [0] Cancelar" -ForegroundColor Gray
        Write-Host ""

        $choice = Read-Host "  Seleccione una opción"

        switch ($choice) {
            '1' {
                $defaultDir = Join-Path $HOME "Desktop"

                Write-Host ""
                $dirInput = Read-Host "  Ruta de la carpeta donde buscar ISOs (Enter = $defaultDir)"

                if ([string]::IsNullOrWhiteSpace($dirInput)) {
                    $dirInput = $defaultDir
                }

                if (-not (Test-Path $dirInput -PathType Container)) {
                    Write-ErrorMsg "La carpeta '$dirInput' no existe."
                    continue
                }

                $isoFiles = @(
                    Get-ChildItem -Path $dirInput -Filter "*.iso" -File -ErrorAction SilentlyContinue |
                        Sort-Object Name
                )

                if ($isoFiles.Count -eq 0) {
                    Write-ErrorMsg "No se encontraron archivos .iso en '$dirInput'."
                    continue
                }

                Write-Host ""
                Write-Host "  Archivos ISO encontrados en: $dirInput" -ForegroundColor Cyan
                Write-Host ("  " + ("-" * 60)) -ForegroundColor Gray

                for ($i = 0; $i -lt $isoFiles.Count; $i++) {
                    $sizeMB = [math]::Round($isoFiles[$i].Length / 1MB, 0)
                    Write-Host "  [$($i + 1)] $($isoFiles[$i].Name)  ($sizeMB MB)" -ForegroundColor White
                }

                Write-Host ("  " + ("-" * 60)) -ForegroundColor Gray
                Write-Host ""

                $pick = Read-Host "  Seleccione el número de la ISO"
                $pickNumber = 0

                if ([int]::TryParse($pick, [ref]$pickNumber) -and
                    $pickNumber -ge 1 -and
                    $pickNumber -le $isoFiles.Count) {
                    return $isoFiles[$pickNumber - 1].FullName
                }

                Write-ErrorMsg "Selección inválida."
                continue
            }

            '2' {
                Write-Host ""
                $manual = Read-Host "  Escriba la ruta completa del archivo ISO"

                if ($manual -and (Test-Path $manual -PathType Leaf)) {
                    return (Resolve-Path $manual).Path
                }

                Write-ErrorMsg "Ruta inválida o archivo inexistente."
                continue
            }

            '0' {
                Write-Host ""
                Write-Host "  Operación cancelada por el usuario." -ForegroundColor Red
                exit 0
            }

            default {
                Write-Warn "Opción no reconocida."
                continue
            }
        }
    }
}

# FUNCIÓN: EXTRAER ISO
#------------------------------------------------------------------------------

function Expand-WindowsIso {
    param(
        [string]$IsoPath,
        [string]$Destination
    )

    # Intento 1: 7-Zip
    $7zPath = Test-7ZipInstalled

    if ($7zPath) {
        Write-Host "    Usando 7-Zip: $7zPath" -ForegroundColor Gray

        try {
            # Argumentos corregidos, sin espacios internos ni comillas manuales.
            $arguments = @(
                'x'
                $IsoPath
                "-o$Destination"
                '-y'
            )

            $process = Start-Process -FilePath $7zPath `
                                     -ArgumentList $arguments `
                                     -NoNewWindow `
                                     -Wait `
                                     -PassThru

            if ($process.ExitCode -eq 0) {
                Write-OK "ISO extraída con 7-Zip."
                return $true
            } else {
                Write-Warn "7-Zip falló con código de salida: $($process.ExitCode)"
            }
        } catch {
            Write-Warn "Error ejecutando 7-Zip: $($_.Exception.Message)"
        }
    } else {
        Write-Warn "7-Zip no está disponible. Intentando con montaje nativo de PowerShell..."
    }

    # Intento 2: Mount-DiskImage + Robocopy
    $mounted = $null

    try {
        $mounted = Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop

        $driveLetter = $null
        for ($retry = 1; $retry -le 6; $retry++) {
            $volume = $mounted | Get-Volume -ErrorAction SilentlyContinue
            if ($volume -and $volume.DriveLetter) {
                $driveLetter = $volume.DriveLetter
                break
            }
            Start-Sleep -Milliseconds 500
        }

        if (-not $driveLetter) {
            throw "La ISO se montó, pero no se pudo obtener una letra de unidad tras varios reintentos."
        }

        $driveRoot = "$($driveLetter):"

        Write-Host "    ISO montada en $driveRoot" -ForegroundColor Gray
        Write-Host "    Copiando archivos. Esto puede tardar varios minutos..." -ForegroundColor Gray

        # Robocopy:
        # Exit codes < 8 suelen indicar éxito o advertencias no fatales.
        & robocopy $driveRoot $Destination /E /COPY:DAT /R:2 /W:2 /NP /NFL /NDL /MT:32 /XD "System Volume Information" | Out-Null

        if ($LASTEXITCODE -ge 8) {
            throw "Robocopy terminó con código $LASTEXITCODE."
        }

        Write-OK "Archivos copiados desde unidad $driveRoot."
        return $true
    } catch {
        Write-ErrorMsg "No se pudo extraer la ISO mediante montaje nativo: $($_.Exception.Message)"
        return $false
    } finally {
        if ($mounted) {
            Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

# FUNCIÓN: DESCARGAR COLMENA DE REGISTRO CON REINTENTOS
#------------------------------------------------------------------------------

function Invoke-RegUnloadHive {
    param(
        [string]$HiveName,
        [int]$RetryCount = 5,
        [int]$RetryDelaySeconds = 2
    )

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            # Forzar recolección de basura para liberar cualquier handle de archivo retenido por .NET / COM
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            Start-Sleep -Milliseconds 300

            $proc = Start-Process -FilePath "reg.exe" `
                                  -ArgumentList @("unload", $HiveName) `
                                  -Wait `
                                  -PassThru `
                                  -NoNewWindow

            if ($proc.ExitCode -eq 0) {
                return $true
            }
        } catch {
            # Reintentar
        }

        if ($attempt -lt $RetryCount) {
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }

    return $false
}

# FUNCIÓN: INYECTAR ImageInstall / Zero-Touch EN autounattend.xml
#------------------------------------------------------------------------------

function Add-ImageInstallToAutounattend {
    param(
        [string]$AutounattendPath,
        [int]$ImageIndex,
        [bool]$EnableZeroTouch = $false,
        [int]$ZeroTouchDisk = 0
    )

    if (-not (Test-Path $AutounattendPath)) {
        return $false
    }

    try {
        [xml]$xmlDoc = Get-Content -Path $AutounattendPath -Raw -Encoding UTF8

        $nsManager  = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
        $nsUnattend = 'urn:schemas-microsoft-com:unattend'
        $nsWcm      = 'http://schemas.microsoft.com/WMIConfig/2002/State'

        $nsManager.AddNamespace('u', $nsUnattend)
        $nsManager.AddNamespace('wcm', $nsWcm)

        $setupComponent = $xmlDoc.SelectSingleNode(
            '//u:unattend/u:settings[@pass="windowsPE"]/u:component[@name="Microsoft-Windows-Setup"]',
            $nsManager
        )

        if (-not $setupComponent) {
            Write-Warn "No se encontró el componente Microsoft-Windows-Setup en windowsPE."
            return $false
        }

        #----------------------------------------------------------------------
        # MODO ZERO-TOUCH: Particionado automático UEFI/GPT y Aceptación de EULA
        #----------------------------------------------------------------------
        if ($EnableZeroTouch) {
            # 1. Eliminar DiskConfiguration previo si existe
            $existingDiskConfig = $setupComponent.SelectSingleNode('u:DiskConfiguration', $nsManager)
            if ($existingDiskConfig) {
                $setupComponent.RemoveChild($existingDiskConfig) | Out-Null
            }

            # 2. Construir DiskConfiguration óptimo según Microsoft Learn
            $diskConfig = $xmlDoc.CreateElement('DiskConfiguration', $nsUnattend)
            $diskElem   = $xmlDoc.CreateElement('Disk', $nsUnattend)

            $wcmAttrDisk = $xmlDoc.CreateAttribute('wcm', 'action', $nsWcm)
            $wcmAttrDisk.Value = 'add'
            $diskElem.Attributes.Append($wcmAttrDisk) | Out-Null

            $diskIdElem = $xmlDoc.CreateElement('DiskID', $nsUnattend)
            $diskIdElem.InnerText = [string]$ZeroTouchDisk
            $diskElem.AppendChild($diskIdElem) | Out-Null

            $willWipeElem = $xmlDoc.CreateElement('WillWipeDisk', $nsUnattend)
            $willWipeElem.InnerText = 'true'
            $diskElem.AppendChild($willWipeElem) | Out-Null

            # CreatePartitions: EFI 300MB + MSR 16MB + Recovery 500MB (WinRE) + Windows Primary (Extend)
            # Layout recomendado por Microsoft: EFI | MSR | Recovery | Windows
            # Recovery antes de Windows permite usar Extend=true en la particion OS.
            # Fuente: https://learn.microsoft.com/windows-hardware/manufacture/desktop/configure-uefigpt-based-hard-drive-partitions
            $createParts = $xmlDoc.CreateElement('CreatePartitions', $nsUnattend)

            # Partición 1: EFI System Partition (300 MB para compatibilidad universal 4Kn)
            $cp1 = $xmlDoc.CreateElement('CreatePartition', $nsUnattend)
            $cp1Attr = $xmlDoc.CreateAttribute('wcm', 'action', $nsWcm); $cp1Attr.Value = 'add'; $cp1.Attributes.Append($cp1Attr) | Out-Null
            $cp1Order = $xmlDoc.CreateElement('Order', $nsUnattend); $cp1Order.InnerText = '1'; $cp1.AppendChild($cp1Order) | Out-Null
            $cp1Type = $xmlDoc.CreateElement('Type', $nsUnattend); $cp1Type.InnerText = 'EFI'; $cp1.AppendChild($cp1Type) | Out-Null
            $cp1Size = $xmlDoc.CreateElement('Size', $nsUnattend); $cp1Size.InnerText = '300'; $cp1.AppendChild($cp1Size) | Out-Null
            $createParts.AppendChild($cp1) | Out-Null

            # Partición 2: Microsoft Reserved Partition (16 MB estándar GPT)
            $cp2 = $xmlDoc.CreateElement('CreatePartition', $nsUnattend)
            $cp2Attr = $xmlDoc.CreateAttribute('wcm', 'action', $nsWcm); $cp2Attr.Value = 'add'; $cp2.Attributes.Append($cp2Attr) | Out-Null
            $cp2Order = $xmlDoc.CreateElement('Order', $nsUnattend); $cp2Order.InnerText = '2'; $cp2.AppendChild($cp2Order) | Out-Null
            $cp2Type = $xmlDoc.CreateElement('Type', $nsUnattend); $cp2Type.InnerText = 'MSR'; $cp2.AppendChild($cp2Type) | Out-Null
            $cp2Size = $xmlDoc.CreateElement('Size', $nsUnattend); $cp2Size.InnerText = '16'; $cp2.AppendChild($cp2Size) | Out-Null
            $createParts.AppendChild($cp2) | Out-Null

            # Partición 3: Windows Recovery Environment (500 MB, Primary NTFS)
            # Colocada ANTES de Windows para permitir Extend=true en la OS partition.
            $cp3 = $xmlDoc.CreateElement('CreatePartition', $nsUnattend)
            $cp3Attr = $xmlDoc.CreateAttribute('wcm', 'action', $nsWcm); $cp3Attr.Value = 'add'; $cp3.Attributes.Append($cp3Attr) | Out-Null
            $cp3Order = $xmlDoc.CreateElement('Order', $nsUnattend); $cp3Order.InnerText = '3'; $cp3.AppendChild($cp3Order) | Out-Null
            $cp3Type = $xmlDoc.CreateElement('Type', $nsUnattend); $cp3Type.InnerText = 'Primary'; $cp3.AppendChild($cp3Type) | Out-Null
            $cp3Size = $xmlDoc.CreateElement('Size', $nsUnattend); $cp3Size.InnerText = '500'; $cp3.AppendChild($cp3Size) | Out-Null
            $createParts.AppendChild($cp3) | Out-Null

            # Partición 4: Windows OS (Todo el resto del disco con Extend=true)
            $cp4 = $xmlDoc.CreateElement('CreatePartition', $nsUnattend)
            $cp4Attr = $xmlDoc.CreateAttribute('wcm', 'action', $nsWcm); $cp4Attr.Value = 'add'; $cp4.Attributes.Append($cp4Attr) | Out-Null
            $cp4Order = $xmlDoc.CreateElement('Order', $nsUnattend); $cp4Order.InnerText = '4'; $cp4.AppendChild($cp4Order) | Out-Null
            $cp4Type = $xmlDoc.CreateElement('Type', $nsUnattend); $cp4Type.InnerText = 'Primary'; $cp4.AppendChild($cp4Type) | Out-Null
            $cp4Ext = $xmlDoc.CreateElement('Extend', $nsUnattend); $cp4Ext.InnerText = 'true'; $cp4.AppendChild($cp4Ext) | Out-Null
            $createParts.AppendChild($cp4) | Out-Null

            $diskElem.AppendChild($createParts) | Out-Null

            # ModifyPartitions: FAT32 para EFI, NTFS para Recovery y Windows (C:)
            $modParts = $xmlDoc.CreateElement('ModifyPartitions', $nsUnattend)

            # Modificar Partición 1 (EFI) → FAT32, Etiqueta "System"
            $mp1 = $xmlDoc.CreateElement('ModifyPartition', $nsUnattend)
            $mp1Attr = $xmlDoc.CreateAttribute('wcm', 'action', $nsWcm); $mp1Attr.Value = 'add'; $mp1.Attributes.Append($mp1Attr) | Out-Null
            $mp1Order = $xmlDoc.CreateElement('Order', $nsUnattend); $mp1Order.InnerText = '1'; $mp1.AppendChild($mp1Order) | Out-Null
            $mp1PartId = $xmlDoc.CreateElement('PartitionID', $nsUnattend); $mp1PartId.InnerText = '1'; $mp1.AppendChild($mp1PartId) | Out-Null
            $mp1Format = $xmlDoc.CreateElement('Format', $nsUnattend); $mp1Format.InnerText = 'FAT32'; $mp1.AppendChild($mp1Format) | Out-Null
            $mp1Label = $xmlDoc.CreateElement('Label', $nsUnattend); $mp1Label.InnerText = 'System'; $mp1.AppendChild($mp1Label) | Out-Null
            $modParts.AppendChild($mp1) | Out-Null

            # Modificar Partición 3 (WinRE Recovery) → NTFS, Etiqueta "Recovery", sin letra de unidad
            $mp2 = $xmlDoc.CreateElement('ModifyPartition', $nsUnattend)
            $mp2Attr = $xmlDoc.CreateAttribute('wcm', 'action', $nsWcm); $mp2Attr.Value = 'add'; $mp2.Attributes.Append($mp2Attr) | Out-Null
            $mp2Order = $xmlDoc.CreateElement('Order', $nsUnattend); $mp2Order.InnerText = '2'; $mp2.AppendChild($mp2Order) | Out-Null
            $mp2PartId = $xmlDoc.CreateElement('PartitionID', $nsUnattend); $mp2PartId.InnerText = '3'; $mp2.AppendChild($mp2PartId) | Out-Null
            $mp2Format = $xmlDoc.CreateElement('Format', $nsUnattend); $mp2Format.InnerText = 'NTFS'; $mp2.AppendChild($mp2Format) | Out-Null
            $mp2Label = $xmlDoc.CreateElement('Label', $nsUnattend); $mp2Label.InnerText = 'Recovery'; $mp2.AppendChild($mp2Label) | Out-Null
            $mp2TypeId = $xmlDoc.CreateElement('TypeID', $nsUnattend); $mp2TypeId.InnerText = 'de94bba4-06d1-4d40-a16a-bfd50179d6ac'; $mp2.AppendChild($mp2TypeId) | Out-Null
            $modParts.AppendChild($mp2) | Out-Null

            # Modificar Partición 4 (Windows OS) → NTFS, Etiqueta "Windows", Letra C
            $mp3 = $xmlDoc.CreateElement('ModifyPartition', $nsUnattend)
            $mp3Attr = $xmlDoc.CreateAttribute('wcm', 'action', $nsWcm); $mp3Attr.Value = 'add'; $mp3.Attributes.Append($mp3Attr) | Out-Null
            $mp3Order = $xmlDoc.CreateElement('Order', $nsUnattend); $mp3Order.InnerText = '3'; $mp3.AppendChild($mp3Order) | Out-Null
            $mp3PartId = $xmlDoc.CreateElement('PartitionID', $nsUnattend); $mp3PartId.InnerText = '4'; $mp3.AppendChild($mp3PartId) | Out-Null
            $mp3Format = $xmlDoc.CreateElement('Format', $nsUnattend); $mp3Format.InnerText = 'NTFS'; $mp3.AppendChild($mp3Format) | Out-Null
            $mp3Label = $xmlDoc.CreateElement('Label', $nsUnattend); $mp3Label.InnerText = 'Windows'; $mp3.AppendChild($mp3Label) | Out-Null
            $mp3Letter = $xmlDoc.CreateElement('Letter', $nsUnattend); $mp3Letter.InnerText = 'C'; $mp3.AppendChild($mp3Letter) | Out-Null
            $modParts.AppendChild($mp3) | Out-Null

            $diskElem.AppendChild($modParts) | Out-Null
            $diskConfig.AppendChild($diskElem) | Out-Null

            # Insertar DiskConfiguration al principio de Microsoft-Windows-Setup
            $firstSetupChild = $setupComponent.FirstChild
            if ($firstSetupChild) {
                $setupComponent.InsertBefore($diskConfig, $firstSetupChild) | Out-Null
            } else {
                $setupComponent.AppendChild($diskConfig) | Out-Null
            }

            # 3. Inyectar UserData con AcceptEula
            $existingUserData = $setupComponent.SelectSingleNode('u:UserData', $nsManager)
            if ($existingUserData) {
                $setupComponent.RemoveChild($existingUserData) | Out-Null
            }

            $userDataElem = $xmlDoc.CreateElement('UserData', $nsUnattend)
            $acceptEulaElem = $xmlDoc.CreateElement('AcceptEula', $nsUnattend)
            $acceptEulaElem.InnerText = 'true'
            $userDataElem.AppendChild($acceptEulaElem) | Out-Null
            $setupComponent.AppendChild($userDataElem) | Out-Null
        }

        #----------------------------------------------------------------------
        # ImageInstall (Selección de índice WIM)
        #----------------------------------------------------------------------
        $existingImageInstall = $setupComponent.SelectSingleNode('u:ImageInstall', $nsManager)
        if ($existingImageInstall) {
            $setupComponent.RemoveChild($existingImageInstall) | Out-Null
        }

        $imageInstall = $xmlDoc.CreateElement('ImageInstall', $nsUnattend)
        $osImage      = $xmlDoc.CreateElement('OSImage', $nsUnattend)

        # En Zero-Touch, especificar el destino de instalación exacto (Disco N, Partición 4)
        # La partición 4 es Windows OS; la partición 3 es Recovery (WinRE).
        if ($EnableZeroTouch) {
            $installTo   = $xmlDoc.CreateElement('InstallTo', $nsUnattend)
            $diskIdNode  = $xmlDoc.CreateElement('DiskID', $nsUnattend)
            $diskIdNode.InnerText = [string]$ZeroTouchDisk
            $partIdNode  = $xmlDoc.CreateElement('PartitionID', $nsUnattend)
            $partIdNode.InnerText = '4'
            $installTo.AppendChild($diskIdNode) | Out-Null
            $installTo.AppendChild($partIdNode) | Out-Null
            $osImage.AppendChild($installTo)    | Out-Null
        }

        $installFrom  = $xmlDoc.CreateElement('InstallFrom', $nsUnattend)
        $metaData     = $xmlDoc.CreateElement('MetaData', $nsUnattend)

        $wcmAttr = $xmlDoc.CreateAttribute('wcm', 'action', $nsWcm)
        $wcmAttr.Value = 'add'
        $metaData.Attributes.Append($wcmAttr) | Out-Null

        $keyNode   = $xmlDoc.CreateElement('Key', $nsUnattend)
        $keyNode.InnerText = '/IMAGE/INDEX'

        $valueNode = $xmlDoc.CreateElement('Value', $nsUnattend)
        $valueNode.InnerText = [string]$ImageIndex

        $metaData.AppendChild($keyNode)   | Out-Null
        $metaData.AppendChild($valueNode) | Out-Null

        $installFrom.AppendChild($metaData) | Out-Null
        $osImage.AppendChild($installFrom)  | Out-Null
        $imageInstall.AppendChild($osImage) | Out-Null

        # Insertar antes de RunSynchronous si existe
        $runSync = $setupComponent.SelectSingleNode('u:RunSynchronous', $nsManager)
        if ($runSync) {
            $setupComponent.InsertBefore($imageInstall, $runSync) | Out-Null
        } else {
            $setupComponent.AppendChild($imageInstall) | Out-Null
        }

        # Guardar como UTF-8 sin BOM.
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $writer    = New-Object System.IO.StreamWriter($AutounattendPath, $false, $utf8NoBom)

        $xmlDoc.Save($writer)
        $writer.Close()

        return $true
    } catch {
        Write-Warn "Error inyectando configuración en autounattend.xml: $($_.Exception.Message)"
        return $false
    }
}

#===============================================================================
# FLUJO PRINCIPAL DE EJECUCIÓN
#===============================================================================

Write-Banner

if (-not (Test-Admin)) {
    Write-ErrorMsg "Ejecute este script como Administrador."
    exit 1
}

#------------------------------------------------------------------------------
# DEPENDENCIAS OPCIONALES
#------------------------------------------------------------------------------

if ($AutoInstallDeps) {
    $depsOk = Install-Dependencies

    if (-not $depsOk) {
        Write-Warn "Continuando con herramientas disponibles..."
    }
}

#------------------------------------------------------------------------------
# RESOLVER ISO DE ORIGEN
#------------------------------------------------------------------------------

$SourceISO = Resolve-SourceISO -SourceISO $SourceISO

Write-Host ""
Write-Host "  ISO origen: $SourceISO" -ForegroundColor Yellow

#------------------------------------------------------------------------------
# WIZARD INTERACTIVO Y ELECCIONES DE DESPLIEGUE
#------------------------------------------------------------------------------

# Wizard regional / usuario / contraseña / tweaks visuales.
# Solo se mostrará si faltan parámetros clave.
Invoke-WizardConfig -ScriptBoundParameters $PSBoundParameters

# Perfil de optimización y bloqueo de OneDrive.
# Si se pasaron por parámetro, se respetan; si no, se preguntan.
Invoke-DeploymentChoices -ScriptBoundParameters $PSBoundParameters -SkipAutoUnattend:$SkipAutoUnattend

#------------------------------------------------------------------------------
# INICIALIZAR LOGGING (antes del paso 1/6)
#------------------------------------------------------------------------------

# Asegurar que OutputDir existe antes de abrir logs
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
Initialize-Log -OutputDirectory $OutputDir
Write-LogEntry -Level "INFO" -Message "OutputDir: $OutputDir"
Write-LogEntry -Level "INFO" -Message "Timestamp build: $Timestamp"

#------------------------------------------------------------------------------
# 1/6 - EXTRAER ISO
#------------------------------------------------------------------------------

Write-Step "1/6 - Extrayendo ISO..."

# Comprobación orientativa de espacio libre.
try {
    $isoItem = Get-Item $SourceISO -ErrorAction Stop

    # Requerimiento aproximado:
    # Tamaño ISO + 15 GB para extracción, montaje WIM, exportación y scratch.
    $requiredBytes = $isoItem.Length + 15GB

    if (-not (Test-MinimumFreeSpace -Path $env:TEMP -RequiredBytes $requiredBytes)) {
        Write-Warn "Puede haber poco espacio libre en $($env:TEMP)."
        Write-Warn "Se recomienda tener al menos 15-25 GB libres para imágenes Windows."
    }
} catch {
    # No bloquear por no poder estimar espacio.
}

# Limpiar directorio temporal previo si existe.
if (Test-Path $ExtractDir) {
    Remove-Item -Path $ExtractDir -Recurse -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path $ISOFilesDir -Force | Out-Null

$extractedOK = Expand-WindowsIso -IsoPath $SourceISO -Destination $ISOFilesDir

if (-not $extractedOK) {
    Write-ErrorMsg "No se pudo extraer la ISO."
    exit 1
}

#------------------------------------------------------------------------------
# VERIFICAR ESTRUCTURA DE ISO DE WINDOWS
#------------------------------------------------------------------------------

$setupExe = Get-ChildItem $ISOFilesDir -Filter "setup.exe" -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1

$sourcesDir = Get-ChildItem $ISOFilesDir -Directory -Filter "sources" -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1

if (-not ($setupExe -and $sourcesDir)) {
    Write-ErrorMsg "La ISO extraída no contiene setup.exe o sources/. ¿Es una ISO de Windows válida?"
    exit 1
}

Write-OK "ISO de Windows válida verificada."

#------------------------------------------------------------------------------
# FORZAR SELECCIÓN DE EDICIÓN MEDIANTE ei.cfg
#------------------------------------------------------------------------------

# [EditionID] vacío fuerza selección de edición en muchos escenarios.
# [Channel] Retail puede no ser adecuado para medios OEM/Volume, pero es el
# comportamiento buscado en esta versión para evitar auto-selección OEM.
$eiCfgPath = Join-Path $sourcesDir.FullName "ei.cfg"

$eiCfgContent = @"
[EditionID]

[Channel]
Retail
[VL]
0
"@

$eiCfgContent | Out-File -FilePath $eiCfgPath -Encoding ASCII -Force

Write-OK "ei.cfg creado/actualizado: selección de edición forzada."

#------------------------------------------------------------------------------
# 2/6 - CREAR ESTRUCTURA $OEM$ Y DETECTAR VERSIÓN
#------------------------------------------------------------------------------

Write-Step "2/6 - Detectando versión de Windows e inyectando scripts..."

# Crear directorio sources\$OEM$\$$\Setup\Scripts (ruta corregida según auditoría)
New-Item -ItemType Directory -Path $OEMScriptsDir -Force | Out-Null

# Detectar qué versión de Windows es esta ISO
$detectedVersion = Detect-WindowsVersion -IsoPath $SourceISO -ExtractedDir $ISOFilesDir

Write-Host "    Versión detectada: Windows $detectedVersion" -ForegroundColor Cyan
Write-OK "La edición de Windows y el disco se seleccionarán durante la instalación"

#------------------------------------------------------------------------------
# SELECCIONAR SCRIPT OPTIMIZADOR
#------------------------------------------------------------------------------

$scriptsToInject = @()
$scriptName = "Windows${detectedVersion}_PostInstall_Optimizer.ps1"

# Verificar si ya se proporcionó vía parámetro
$paramScriptPath = if ($detectedVersion -eq "10") { $Win10ScriptPath } else { $Win11ScriptPath }
$scriptPath = $null

# Resolver ruta relativa respecto al script actual
if ($paramScriptPath) {
    $resolvedPath = if (Test-Path $paramScriptPath) { $paramScriptPath } else { Join-Path $ScriptsDir $paramScriptPath }

    if (Test-Path $resolvedPath) {
        $scriptPath = $resolvedPath
        Write-OK "Usando script especificado: $scriptPath"
    }
}

# Si no se proporcionó, preguntar interactivamente
if (-not $scriptPath) {
    Write-Host ""
    Write-Host "  Seleccione el archivo del script optimizador para Windows $detectedVersion" -ForegroundColor Cyan
    Write-Host "  ($scriptName)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [1] Seleccionar con diálogo de archivos" -ForegroundColor Cyan
    Write-Host "  [2] Escribir la ruta manualmente" -ForegroundColor Cyan
    Write-Host "  [3] Omitir script (solo autounattend.xml)" -ForegroundColor Yellow
    Write-Host "  [0] Cancelar" -ForegroundColor Gray
    Write-Host ""

    $choice = Read-Host "  Opción"

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
            $manual = Read-Host "  Ruta completa del script .ps1"

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
    $scriptsToInject += @{ Source = $scriptPath; DestName = $scriptName }
    Write-OK "Inyectando script para Windows ${detectedVersion}: $scriptPath"
} else {
    Write-Warn "No se seleccionó script optimizador. La ISO se creará sin scripts en `$OEM$."
}

# Copiar scripts a sources\$OEM$\$$\Setup\Scripts
foreach ($script in $scriptsToInject) {
    Copy-Item -Path $script.Source -Destination (Join-Path $OEMScriptsDir $script.DestName) -Force
    Write-OK "Copiado: $($script.DestName)"
}

# ------------------------------------------------------------------
# Copiar Runtimes esenciales a sources\$OEM$\$$\Setup\Scripts\Runtimes si existen
# ------------------------------------------------------------------
$resolvedRuntimesDir = $null
$candidateRuntimes = @(
    $RuntimesPath,
    (Join-Path $ScriptsDir "Runtimes"),
    (Join-Path (Split-Path -Parent $ScriptsDir) "Runtimes")
)

foreach ($cand in $candidateRuntimes) {
    if ($cand -and (Test-Path $cand)) {
        $resolvedRuntimesDir = $cand
        break
    }
}

if ($resolvedRuntimesDir) {
    $runtimeFiles = Get-ChildItem -Path $resolvedRuntimesDir -Include *.exe, *.msi -Recurse -ErrorAction SilentlyContinue
    if ($runtimeFiles.Count -gt 0) {
        $destRuntimesDir = Join-Path $OEMScriptsDir "Runtimes"
        if (-not (Test-Path $destRuntimesDir)) {
            New-Item -ItemType Directory -Path $destRuntimesDir -Force | Out-Null
        }
        Copy-Item -Path "$resolvedRuntimesDir\*" -Destination $destRuntimesDir -Recurse -Force
        Write-OK "Runtimes esenciales inyectados en `$OEM$ ($($runtimeFiles.Count) archivos encontrados)."
    } else {
        Write-Host "    Carpeta Runtimes encontrada pero sin instaladores .exe/.msi." -ForegroundColor DarkYellow
    }
} else {
    Write-Host "    Carpeta 'Runtimes' no encontrada. Se omite pre-carga de VC++/DirectX en `$OEM$." -ForegroundColor Gray
}

#------------------------------------------------------------------------------
# 3/6 - CREAR SetupComplete.cmd (CORREGIDO)
#------------------------------------------------------------------------------

Write-Step "3/6 - Creando SetupComplete.cmd..."

# Correcciones aplicadas:
# - Rutas con barras correctas: %SCRIPTS_DIR%\%SCRIPT_NAME%
# - Template literal para evitar problemas de escaping
# - Eliminación de 'pause' en el fallback (puede colgar tareas programadas)
# - Uso correcto de ^ para escapar caracteres especiales en CMD

$setupCompleteTemplate = @'
@echo off
REM ===========================================================
REM  SetupComplete.cmd - Generado por New-OptimizedWindowsISO
REM  Se ejecuta como SYSTEM al finalizar Windows Setup
REM ===========================================================
SET SCRIPTS_DIR=%WINDIR%\Setup\Scripts
SET SCRIPT_NAME=__SCRIPT_NAME__
SET LOG=%SCRIPTS_DIR%\SetupComplete.log
SET PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe

echo [%DATE% %TIME%] Iniciando SetupComplete.cmd >> "%LOG%"

REM ===========================================================
REM Deshabilitar Tareas Programadas de Telemetria
REM Se ejecutan aqui (post-OOBE) porque las crea el propio OOBE.
REM ===========================================================
echo [%DATE% %TIME%] Deshabilitando tareas programadas de telemetria... >> "%LOG%"
schtasks /change /disable /tn "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" >> "%LOG%" 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Application Experience\PcaPatchDbTask" >> "%LOG%" 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Application Experience\ProgramDataUpdater" >> "%LOG%" 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Application Experience\StartupAppTask" >> "%LOG%" 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" >> "%LOG%" 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" >> "%LOG%" 2>&1
echo [%DATE% %TIME%] Tareas de telemetria deshabilitadas. >> "%LOG%"

REM ===========================================================
REM Instalacion Silenciosa de Runtimes Esenciales
REM (Visual C++ Redistributables y DirectX End-User)
REM ===========================================================
IF EXIST "%SCRIPTS_DIR%\Runtimes" (
    echo [%DATE% %TIME%] Instalando Runtimes esenciales... >> "%LOG%"

    REM --- Visual C++ Redistributables (2012, 2013, 2015-2022) ---
    for %%f in ("%SCRIPTS_DIR%\Runtimes\vc_redist*.exe", "%SCRIPTS_DIR%\Runtimes\vcredist*.exe", "%SCRIPTS_DIR%\Runtimes\VC_*.exe") do (
        echo [%DATE% %TIME%] Instalando %%~nxf... >> "%LOG%"
        "%%f" /install /quiet /norestart >> "%LOG%" 2>&1
    )

    REM --- DirectX End-User Runtimes (Junio 2010) ---
    if exist "%SCRIPTS_DIR%\Runtimes\DirectX\dxsetup.exe" (
        echo [%DATE% %TIME%] Instalando DirectX End-User Runtimes... >> "%LOG%"
        "%SCRIPTS_DIR%\Runtimes\DirectX\dxsetup.exe" /silent >> "%LOG%" 2>&1
    )
    if exist "%SCRIPTS_DIR%\Runtimes\dxsetup.exe" (
        echo [%DATE% %TIME%] Instalando DirectX End-User Runtimes... >> "%LOG%"
        "%SCRIPTS_DIR%\Runtimes\dxsetup.exe" /silent >> "%LOG%" 2>&1
    )

    echo [%DATE% %TIME%] Runtimes instalados exitosamente. >> "%LOG%"
)

REM ===========================================================
REM Integrar Optimizador Bajo Demanda en el Escritorio Publico
REM No se auto-ejecuta en silencio; el usuario decide cuando iniciarlo.
REM ===========================================================
IF EXIST "%SCRIPTS_DIR%\%SCRIPT_NAME%" (
    echo [%DATE% %TIME%] Creando lanzador y acceso directo en Escritorio publico... >> "%LOG%"

    (
        echo @echo off
        echo title Optimizador de Windows 11
        echo echo ===================================================
        echo echo  Iniciando Optimizador Adaptativo de Windows 11...
        echo echo ===================================================
        echo "%PS%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\%SCRIPT_NAME%"
        echo pause
    ) > "%SCRIPTS_DIR%\EjecutarOptimizador.cmd"

    "%PS%" -NoProfile -ExecutionPolicy Bypass -Command "$ws = New-Object -ComObject WScript.Shell; $desk = if ($env:PUBLIC) { \"$env:PUBLIC\Desktop\" } else { 'C:\Users\Public\Desktop' }; if (-not (Test-Path $desk)) { New-Item -ItemType Directory -Path $desk -Force | Out-Null }; $sc = $ws.CreateShortcut(\"$desk\Optimizar Sistema (Opcional).lnk\"); $sc.TargetPath = '%SCRIPTS_DIR%\EjecutarOptimizador.cmd'; $sc.WorkingDirectory = '%SCRIPTS_DIR%'; $sc.Description = 'Ejecutar optimizaciones adicionales y calibracion de hardware'; $sc.IconLocation = '%SystemRoot%\System32\imageres.dll,109'; $sc.Save()" >> "%LOG%" 2>&1
    
    echo [%DATE% %TIME%] Acceso directo creado en Escritorio publico. >> "%LOG%"
) ELSE (
    echo [%DATE% %TIME%] NOTA: No se encontro script optimizador en %SCRIPTS_DIR% >> "%LOG%"
)

echo [%DATE% %TIME%] SetupComplete.cmd finalizado exitosamente. >> "%LOG%"
exit /b 0
'@

$setupCompleteContent = $setupCompleteTemplate.Replace('__SCRIPT_NAME__', $scriptName)

$setupCompletePath = Join-Path $OEMScriptsDir "SetupComplete.cmd"
$setupCompleteContent | Out-File -FilePath $setupCompletePath -Encoding ASCII -Force

Write-OK "SetupComplete.cmd creado"

#------------------------------------------------------------------------------
# 4/6 - CREAR autounattend.xml (CORREGIDO)
#------------------------------------------------------------------------------

if (-not $SkipAutoUnattend) {
    Write-Step "4/6 - Creando autounattend.xml..."

    # Codificación de contraseña según documentación oficial de Microsoft:
    # Windows requiere concatenar el sufijo "Password" al texto plano ANTES
    # de codificar en Base64 UTF-16LE cuando PlainText=false.
    # Si la contraseña está vacía, PlainText debe ser 'true'.

    $encodedPasswordForAccount = ""
    $encodedPasswordForAutologon = ""
    $passwordPlainTextAccount = "true"
    $passwordPlainTextAutologon = "true"

    if ($LocalPassword) {
        $encodedPasswordForAccount = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($LocalPassword + "Password"))
        $encodedPasswordForAutologon = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($LocalPassword + "Password"))
        $passwordPlainTextAccount = "false"
        $passwordPlainTextAutologon = "false"
    }

    # SOLUCIÓN 2: FirstLogonCommands para forzar AutoLogon en Winlogon cuando no hay contraseña.
    # Windows 11 24H2+ ignora <AutoLogon><Value></Value> vacío en la fase oobeSystem.
    # Este bloque escribe directamente las claves de Winlogon en el primer inicio de sesión
    # como respaldo para garantizar AutoLogon sin contraseña en todas las builds de W11.
    $firstLogonXml = ""
    if (-not $LocalPassword) {
        $firstLogonXml = @"
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Force AutoAdminLogon in Winlogon for passwordless account (W11 24H2+ fix)</Description>
          <CommandLine>reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 1 /f</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>2</Order>
          <Description>Set DefaultUserName for AutoLogon</Description>
          <CommandLine>reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /t REG_SZ /d "$($script:LocalUser)" /f</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>3</Order>
          <Description>Set DefaultPassword empty for passwordless AutoLogon</Description>
          <CommandLine>reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /t REG_SZ /d "" /f</CommandLine>
        </SynchronousCommand>
      </FirstLogonCommands>
"@
    }

    # Inyección nativa de Modo Oscuro en autounattend.xml (Microsoft-Windows-Shell-Setup\Themes)
    # Permite que Windows 11 aplique dark.theme directamente en el primer inicio de sesión sin requerir reinicio.
    $themesXml = ""
    if ($script:InjectVisualTweaks) {
        $themesXml = @"
      <Themes>
        <ThemeName>C:\Windows\Resources\Themes\dark.theme</ThemeName>
        <DefaultThemesOff>false</DefaultThemesOff>
      </Themes>
"@
    }

    # Si no se especificó KeyboardOverride, usar el mismo valor que Language
    $finalKeyboard = if ($KeyboardOverride) { $KeyboardOverride } else { $Language }

    # Si no se especificó Locale, heredar el valor de Language
    $finalLocale = if ($Locale) { $Locale } else { $Language }

    # Preguntar sobre el Perfil de Optimización
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║ PERFILES DE OPTIMIZACIÓN (DEBLOAT)                           ║" -ForegroundColor Cyan
    Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "  ║ [1] Conservador: Mantiene Wi-Fi, Bluetooth y apps básicas    ║" -ForegroundColor Cyan
    Write-Host "  ║ [2] Gaming: Elimina bloatware agresivo y telemetría          ║" -ForegroundColor Cyan
    Write-Host "  ║ [3] Hardcore: EXTREMO. Destruye Wi-Fi, Bluetooth, impresión  ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # ------------------------------------------------------------------
    # PERFIL Y ONEDRIVE:
    # Usar los valores ya resueltos por Invoke-DeploymentChoices.
    # Así la Parte 4 y la Parte 5 usan exactamente la misma configuración.
    # ------------------------------------------------------------------

    if ([string]$script:OptProfile -notin @('1', '2', '3')) {
        $script:OptProfile = '1'
    }

    $optProfile = [int]$script:OptProfile
    $script:BlockOneDrive = [bool]$script:BlockOneDrive

    Write-Host ""
    Write-Host "  Perfil de optimización seleccionado: $script:OptProfile" -ForegroundColor Cyan
    Write-Host "  Bloquear OneDrive: $(if ($script:BlockOneDrive) { 'Sí' } else { 'No' })" -ForegroundColor Cyan
    Write-Host ""

    # Construir XML de bloqueo de OneDrive si está habilitado
    $oneDriveXml = ""

    if ($script:BlockOneDrive) {
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
    $nextOrder = if ($script:BlockOneDrive) { 4 } else { 2 }

    $optimizeXml = @"
        <RunSynchronousCommand wcm:action="add">
          <Order>$nextOrder</Order>
          <Description>Disable Hibernation (recover SSD space)</Description>
          <Path>powercfg -h off</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 1)</Order>
          <Description>Activate Ultimate Performance power plan (with High Performance fallback)</Description>
          <Path>cmd.exe /c powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&amp;1 &amp;&amp; powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61 || powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 2)</Order>
          <Description>Block Privacy Experience screens (Scoobe)</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE /v DisablePrivacyExperience /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 3)</Order>
          <Description>Disable Cloud Consumer Features (Anti-Bloatware)</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 4)</Order>
          <Description>Disable Cloud SoftLanding Tips</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent /v DisableSoftLanding /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 5)</Order>
          <Description>Disable PasswordLess sign-in to allow AutoLogon without password (W11 24H2+)</Description>
          <Path>reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" /v DevicePasswordLessBuildVersion /t REG_DWORD /d 0 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 6)</Order>
          <Description>Hide Recommended section in Start Menu</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer /v HideRecommendedSection /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 7)</Order>
          <Description>Disable Search Box Suggestions in Start and Taskbar</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 8)</Order>
          <Description>Disable Cloud Optimized Content (W11 24H2+)</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent /v DisableCloudOptimizedContent /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 9)</Order>
          <Description>Disable Consumer Account State Content</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent /v DisableConsumerAccountStateContent /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 10)</Order>
          <Description>Disable Automatic Microsoft Store App Downloads</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\WindowsStore /v AutoDownload /t REG_DWORD /d 2 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 11)</Order>
          <Description>Block Silent App Installation System-Wide (CDM)</Description>
          <Path>reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 12)</Order>
          <Description>Block Pre-Installed Apps System-Wide (CDM)</Description>
          <Path>reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager /v PreInstalledAppsEnabled /t REG_DWORD /d 0 /f</Path>
        </RunSynchronousCommand>
"@

    $nextOrder += 13

    if ($optProfile -ge 2) {
        # Perfil 2+ (Gaming / Hardcore): Telemetría completa y Bloqueo de Drivers / Apps OEM automáticas
        $optimizeXml += @"

        <RunSynchronousCommand wcm:action="add">
          <Order>$nextOrder</Order>
          <Description>Disable Telemetry service (DiagTrack)</Description>
          <Path>reg add HKLM\SYSTEM\CurrentControlSet\Services\DiagTrack /v Start /t REG_DWORD /d 4 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 1)</Order>
          <Description>Disable Telemetry relay service (dmwappushservice)</Description>
          <Path>reg add HKLM\SYSTEM\CurrentControlSet\Services\dmwappushservice /v Start /t REG_DWORD /d 4 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 2)</Order>
          <Description>Set AllowTelemetry policy to Security level</Description>
          <Path>reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 3)</Order>
          <Description>Exclude Drivers from Automatic Updates (Move to Optional Updates)</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate /v ExcludeWUDriversInQualityUpdate /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 4)</Order>
          <Description>Enable On-Demand Driver Catalog Search for Optional Updates</Description>
          <Path>reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching /v SearchOrderConfig /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 5)</Order>
          <Description>Prevent Device Metadata and OEM App Download from Network (Profile 2+)</Description>
          <Path>reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" /v PreventDeviceMetadataFromNetwork /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
"@
        $nextOrder += 6
    }

    if ($optProfile -eq 3) {
        # Perfil 3 Hardcore: servicios adicionales deshabilitados
        $optimizeXml += @"

        <RunSynchronousCommand wcm:action="add">
          <Order>$nextOrder</Order>
          <Description>Disable Search Indexer (WSearch) — Hardcore only</Description>
          <Path>reg add HKLM\SYSTEM\CurrentControlSet\Services\WSearch /v Start /t REG_DWORD /d 4 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 1)</Order>
          <Description>Disable Print Spooler</Description>
          <Path>reg add HKLM\SYSTEM\CurrentControlSet\Services\Spooler /v Start /t REG_DWORD /d 4 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 2)</Order>
          <Description>Disable WLAN (WlanSvc)</Description>
          <Path>reg add HKLM\SYSTEM\CurrentControlSet\Services\WlanSvc /v Start /t REG_DWORD /d 4 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 3)</Order>
          <Description>Disable Bluetooth (bthserv)</Description>
          <Path>reg add HKLM\SYSTEM\CurrentControlSet\Services\bthserv /v Start /t REG_DWORD /d 4 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 4)</Order>
          <Description>Disable Sensor Service</Description>
          <Path>reg add HKLM\SYSTEM\CurrentControlSet\Services\SensorService /v Start /t REG_DWORD /d 4 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 5)</Order>
          <Description>Disable Superfetch (SysMain)</Description>
          <Path>reg add HKLM\SYSTEM\CurrentControlSet\Services\SysMain /v Start /t REG_DWORD /d 4 /f</Path>
        </RunSynchronousCommand>
"@
        $nextOrder += 6
    }

    # Generar XML completo sin espacios en namespaces (corrección crítica)
    $autounattendContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="$Architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage>
        <UILanguage>$Language</UILanguage>
      </SetupUILanguage>
      <InputLocale>$finalKeyboard</InputLocale>
      <SystemLocale>$finalLocale</SystemLocale>
      <UILanguage>$Language</UILanguage>
      <UserLocale>$finalLocale</UserLocale>
    </component>
    <component name="Microsoft-Windows-Setup" processorArchitecture="$Architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <EnableFirewall>true</EnableFirewall>
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
    </component>
  </settings>
  <settings pass="specialize">
    <component name="Microsoft-Windows-Deployment" processorArchitecture="$Architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Bypass Microsoft Account (BypassNRO)</Description>
          <Path>reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE /v BypassNRO /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
$oneDriveXml
$optimizeXml
      </RunSynchronous>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="$Architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ComputerName>*</ComputerName>
      <RegisteredOrganization>Optimized</RegisteredOrganization>
      <RegisteredOwner>User</RegisteredOwner>
      <TimeZone>$Timezone</TimeZone>
$themesXml
    </component>
    <component name="Microsoft-Windows-International-Core" processorArchitecture="$Architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>$finalKeyboard</InputLocale>
      <SystemLocale>$finalLocale</SystemLocale>
      <UILanguage>$Language</UILanguage>
      <UserLocale>$finalLocale</UserLocale>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="$Architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <AutoLogon>
        <Password>
          <Value>$encodedPasswordForAutologon</Value>
          <PlainText>$passwordPlainTextAutologon</PlainText>
        </Password>
        <Enabled>true</Enabled>
        <LogonCount>$AutoLogonCount</LogonCount>
        <Username>$LocalUser</Username>
      </AutoLogon>
$firstLogonXml
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <!-- NetworkLocation deprecated since Windows 10, ignored in Windows 11 -->
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
      <RegisteredOrganization>Optimized</RegisteredOrganization>
      <RegisteredOwner>User</RegisteredOwner>
      <TimeZone>$Timezone</TimeZone>
$themesXml
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
    </component>
    <component name="Microsoft-Windows-International-Core" processorArchitecture="$Architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>$finalKeyboard</InputLocale>
      <SystemLocale>$finalLocale</SystemLocale>
      <UILanguage>$Language</UILanguage>
      <UserLocale>$finalLocale</UserLocale>
    </component>
  </settings>
</unattend>
"@

    $autounattendPath = Join-Path $ISOFilesDir "autounattend.xml"

    # Guardar como UTF-8 SIN BOM (crítico para Windows Setup)
    $utf8NoBomEnc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($autounattendPath, $autounattendContent, $utf8NoBomEnc)

    Write-OK "autounattend.xml creado"

    # No es necesario copiar a $OEM$ porque ya está en la raíz de la ISO
    # y Windows Setup lo buscará ahí automáticamente
} else {
    Write-Step "4/6 - Omitiendo autounattend.xml (flag -SkipAutoUnattend)"
}

#------------------------------------------------------------------------------
# FUNCIÓN: DESCARGAR COLMENA DE REGISTRO CON REINTENTOS

#------------------------------------------------------------------------------
# FUNCIÓN: INYECTAR ImageInstall EN autounattend.xml

#------------------------------------------------------------------------------
# 5/6 - INYECTAR SCRIPTS EN install.wim
#------------------------------------------------------------------------------

Write-Step "5/6 - Inyectando scripts en install.wim (offline)..."

$wimFile = Get-ChildItem -Path $ISOFilesDir -Recurse -Filter "install.wim" -ErrorAction SilentlyContinue |
    Select-Object -First 1

if (-not $wimFile) {
    $wimFile = Get-ChildItem -Path $ISOFilesDir -Recurse -Filter "install.esd" -ErrorAction SilentlyContinue |
        Select-Object -First 1
}

$wimInjected           = $false
$exportSucceeded       = $false
$selectedSingleIndex   = $null
$finalImageInstallIndex = $null

if ($wimFile) {
    Write-Host "    Imagen encontrada: $($wimFile.FullName)" -ForegroundColor Gray

    # Si el archivo está en solo lectura, intentar quitar atributo.
    try {
        if ($wimFile.IsReadOnly) {
            Set-ItemProperty -Path $wimFile.FullName -Name IsReadOnly -Value $false -ErrorAction Stop
            Write-Host "    Atributo de solo lectura eliminado." -ForegroundColor Gray
        }
    } catch {
        Write-Warn "No se pudo quitar el atributo de solo lectura del WIM."
    }

    if ($wimFile.Extension -eq ".esd") {
        Write-Warn "El archivo es install.esd."
        Write-Warn "DISM normalmente no puede modificar ESD sólidos directamente."
        Write-Warn "Se omitirá la inyección offline. La ISO dependerá de autounattend.xml y `$OEM$."
        Write-Warn "Para inyección completa, convierta previamente install.esd a install.wim."
    } else {
        $allWimImages = Get-WimImageList -WimPath $wimFile.FullName

        Write-Host ""
        Write-Host "    Ediciones detectadas en install.wim:" -ForegroundColor Cyan
        Write-Host ("    " + ("-" * 60)) -ForegroundColor Gray

        foreach ($img in $allWimImages) {
            Write-Host "    [Índice $($img.Index)] $($img.Name)" -ForegroundColor White
        }

        Write-Host ("    " + ("-" * 60)) -ForegroundColor Gray

        $indexesToProcess = @()

        if ($TargetWimIndex) {
            if ($TargetWimIndex -eq "all" -or $TargetWimIndex -eq "*") {
                $indexesToProcess = $allWimImages | ForEach-Object { $_.Index }
                Write-Host "    Procesando TODAS las ediciones por parámetro (-TargetWimIndex all)." -ForegroundColor Gray
            } else {
                $indexesToProcess = $TargetWimIndex -split ',' | ForEach-Object { $_.Trim() }
                Write-Host "    Procesando índice(s) especificado(s): $($indexesToProcess -join ', ')." -ForegroundColor Gray
            }
        } elseif ($allWimImages.Count -eq 1) {
            $indexesToProcess = @($allWimImages[0].Index)
            Write-Host "    Solo se detectó 1 edición. Procesando índice $($allWimImages[0].Index)." -ForegroundColor Gray
        } else {
            Write-Host ""
            Write-Host "    Seleccione qué edición(es) desea modificar offline:" -ForegroundColor Yellow
            Write-Host "    [A] Procesar TODAS las ediciones" -ForegroundColor Cyan

            for ($i = 0; $i -lt $allWimImages.Count; $i++) {
                Write-Host "    [$($i + 1)] Solo Índice $($allWimImages[$i].Index): $($allWimImages[$i].Name)" -ForegroundColor White
            }

            Write-Host ""
            $choice = Read-Host "    Seleccione una opción (ENTER = TODAS)"

            if ([string]::IsNullOrWhiteSpace($choice) -or $choice -match '(?i)^a$') {
                $indexesToProcess = $allWimImages | ForEach-Object { $_.Index }
            } else {
                $pickNum = 0

                if ([int]::TryParse($choice, [ref]$pickNum) -and
                    $pickNum -ge 1 -and
                    $pickNum -le $allWimImages.Count) {
                    $indexesToProcess = @($allWimImages[$pickNum - 1].Index)
                } else {
                    Write-Warn "Opción no válida. Se procesarán TODAS las ediciones."
                    $indexesToProcess = $allWimImages | ForEach-Object { $_.Index }
                }
            }
        }

        # Validar índices solicitados contra índices reales del WIM.
        $invalidIndexes = @($indexesToProcess | Where-Object { $_ -notin $allWimImages.Index })

        if ($invalidIndexes.Count -gt 0) {
            Write-ErrorMsg "Índices WIM inválidos: $($invalidIndexes -join ', ')."
            Write-ErrorMsg "Índices disponibles: $(($allWimImages.Index -join ', '))."
            exit 1
        }

        if ($indexesToProcess.Count -eq 1) {
            $selectedSingleIndex = $indexesToProcess[0]
        }

        # Preparar directorio scratch.
        if (Test-Path $ScratchDir) {
            Remove-Item -Path $ScratchDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null

        try {
            foreach ($wimIndex in $indexesToProcess) {
                $currentImg = $allWimImages | Where-Object { $_.Index -eq $wimIndex } | Select-Object -First 1
                $imgNameStr = if ($currentImg) { " ($($currentImg.Name))" } else { "" }

                Write-Host ""
                Write-Host "    Procesando índice $wimIndex$imgNameStr..." -ForegroundColor Gray

                try {
                    # Limpieza preventiva por iteración: elimina puntos huérfanos del ciclo anterior
                    if (Get-Command "dism.exe" -ErrorAction SilentlyContinue) {
                        try { & dism.exe /Cleanup-Mountpoints 2>&1 | Out-Null } catch {}
                    }

                    if (Test-Path $WimMountDir) {
                        Remove-Item -Path $WimMountDir -Recurse -Force -ErrorAction SilentlyContinue
                    }

                    New-Item -ItemType Directory -Path $WimMountDir -Force | Out-Null

                    Mount-WindowsImage -ImagePath $wimFile.FullName `
                                       -Index ([int]$wimIndex) `
                                       -Path $WimMountDir `
                                       -ScratchDirectory $ScratchDir `
                                       -ErrorAction Stop

                    Write-OK "WIM índice $wimIndex$imgNameStr montado."

                    #==================================================================
                    # HABILITACIÓN OFFLINE DE .NET FRAMEWORK 3.5 (NetFx3)
                    #==================================================================

                    Write-Host ""
                    Write-Host "    ══ Habilitar .NET Framework 3.5 (NetFx3) ══" -ForegroundColor Cyan

                    $sxsDir = Join-Path $ISOFilesDir "sources\sxs"

                    if (Test-Path $sxsDir) {
                        try {
                            Write-Host "    Habilitando .NET 3.5 desde sources\sxs con DISM..." -ForegroundColor Gray
                            $dismNetFx3 = & dism.exe /Image:"$WimMountDir" `
                                                    /Enable-Feature `
                                                    /FeatureName:NetFx3 `
                                                    /All `
                                                    /Source:"$sxsDir" `
                                                    /LimitAccess `
                                                    /ScratchDir:"$ScratchDir" 2>&1

                            if ($LASTEXITCODE -in @(0, 3010)) {
                                Write-OK ".NET Framework 3.5 habilitado en la imagen WIM."
                            } else {
                                Write-Warn "DISM NetFx3 exit code: $LASTEXITCODE. Continuando."
                            }
                        } catch {
                            Write-Warn "No se pudo habilitar .NET 3.5 offline: $($_.Exception.Message)"
                        }
                    } else {
                        Write-Host "    Carpeta 'sources\sxs' no encontrada en la ISO. NetFx3 omitido." -ForegroundColor DarkYellow
                    }

                    #==================================================================
                    # SLIPSTREAMING DE ACTUALIZACIONES
                    #==================================================================

                    $UpdatesDir   = Join-Path $ScriptsDir "Updates"
                    $successCount = 0
                    $failCount    = 0

                    Write-Host ""
                    Write-Host "    ══ Slipstreaming de actualizaciones ══" -ForegroundColor Cyan

                    if (-not (Test-Path $UpdatesDir)) {
                        Write-Host "    Carpeta 'Updates' no encontrada. Slipstreaming omitido." -ForegroundColor DarkYellow
                        Write-Host "    Para inyectar parches, cree la carpeta y coloque archivos .msu/.cab." -ForegroundColor Gray
                    } else {
                        $packages = Get-ChildItem -Path $UpdatesDir -Include *.msu, *.cab -Recurse -ErrorAction SilentlyContinue

                        if ($packages.Count -eq 0) {
                            Write-Host "    Carpeta 'Updates' encontrada pero sin archivos .msu/.cab." -ForegroundColor DarkYellow
                        } else {
                            # Ordenación simple: SSU primero, luego resto.
                            # Nota: esto es una heurística por nombre de archivo.
                            $orderedPackages = $packages | Sort-Object {
                                if ($_.Name -match 'ssu|servicing.?stack') { 0 } else { 1 }
                            }, Name

                            $total = $orderedPackages.Count

                            Write-Host "    Encontrados $total paquete(s)." -ForegroundColor Gray
                            Write-Host "    Orden: SSU primero, luego LCU/otros." -ForegroundColor Gray

                            $ssuCount = @($orderedPackages | Where-Object { $_.Name -match 'ssu|servicing.?stack' }).Count

                            if ($ssuCount -gt 0) {
                                Write-Host "    SSU detectados: $ssuCount." -ForegroundColor Gray
                            }

                            Write-Host ""

                            $i = 0

                            foreach ($pkg in $orderedPackages) {
                                $i++

                                $label = if ($pkg.Name -match 'ssu|servicing.?stack') { "[SSU]" } else { "[PKG]" }
                                $sizeMB = [math]::Round($pkg.Length / 1MB, 1)

                                Write-Host "    [$i/$total] $label $($pkg.Name) ($sizeMB MB)..." -ForegroundColor Gray -NoNewline

                                try {
                                    $dismLog = Join-Path $ScratchDir "dism_$($pkg.Name).log"

                                    & dism.exe /Image:"$WimMountDir" `
                                               /Add-Package `
                                               /PackagePath:"$($pkg.FullName)" `
                                               /ScratchDir:"$ScratchDir" `
                                               /LogPath:"$dismLog" 2>&1 | Out-Null

                                    if ($LASTEXITCODE -in @(0, 3010)) {
                                        $successCount++
                                        Write-Host " OK" -ForegroundColor Green
                                    } else {
                                        if ($pkg.Extension -eq ".msu") {
                                            Write-Host " WARN" -ForegroundColor Yellow
                                            Write-Host "      Intentando extraer .cab interno..." -ForegroundColor Gray

                                            $cabExtractDir = Join-Path $ScratchDir "Extracted_$($pkg.Name)"
                                            New-Item -ItemType Directory -Path $cabExtractDir -Force | Out-Null

                                            & expand.exe -F:* "$($pkg.FullName)" "$cabExtractDir" 2>&1 | Out-Null

                                            $cabFile = Get-ChildItem -Path $cabExtractDir -Filter "*.cab" |
                                                Where-Object { $_.Name -notmatch 'WSUSSCAN' } |
                                                Select-Object -First 1

                                            if ($cabFile) {
                                                & dism.exe /Image:"$WimMountDir" `
                                                           /Add-Package `
                                                           /PackagePath:"$($cabFile.FullName)" `
                                                           /ScratchDir:"$ScratchDir" `
                                                           /LogPath:"$dismLog" 2>&1 | Out-Null

                                                if ($LASTEXITCODE -in @(0, 3010)) {
                                                    $successCount++
                                                    Write-Host "      OK usando .cab extraído." -ForegroundColor Green
                                                } else {
                                                    $failCount++
                                                    Write-Host "      ERROR también con .cab. Exit code: $LASTEXITCODE." -ForegroundColor Red
                                                }
                                            } else {
                                                $failCount++
                                                Write-Host "      ERROR: no se encontró .cab válido dentro del .msu." -ForegroundColor Red
                                            }
                                        } else {
                                            $failCount++
                                            Write-Host " ERROR. Exit code: $LASTEXITCODE." -ForegroundColor Red
                                        }
                                    }
                                } catch {
                                    $failCount++
                                    Write-Host " ERROR: $($_.Exception.Message)." -ForegroundColor Red
                                }
                            }

                            Write-Host ""
                            Write-Host "    Resumen slipstreaming:" -ForegroundColor Cyan
                            Write-Host "      Correctos: $successCount" -ForegroundColor Green
                            Write-Host "      Fallidos : $failCount" -ForegroundColor $(if ($failCount -gt 0) { 'Red' } else { 'Green' })
                        }
                    }

                    #==================================================================
                    # INYECCIÓN OFFLINE DE CONTROLADORES (DRIVERS)
                    #==================================================================

                    $resolvedDriversDir = $null
                    $candidateDrivers = @(
                        $DriversPath,
                        (Join-Path $ScriptsDir "Drivers"),
                        (Join-Path (Split-Path -Parent $ScriptsDir) "Drivers")
                    )

                    foreach ($cand in $candidateDrivers) {
                        if ($cand -and (Test-Path $cand)) {
                            $resolvedDriversDir = $cand
                            break
                        }
                    }

                    if ($resolvedDriversDir) {
                        $driverFiles = Get-ChildItem -Path $resolvedDriversDir -Include *.inf -Recurse -ErrorAction SilentlyContinue

                        Write-Host ""
                        Write-Host "    ══ Inyección offline de Drivers ══" -ForegroundColor Cyan

                        if ($driverFiles.Count -gt 0) {
                            Write-Host "    Encontrados $($driverFiles.Count) archivo(s) .inf en '$resolvedDriversDir'." -ForegroundColor Gray
                            Write-Host "    Inyectando controladores con DISM /Add-Driver /Recurse..." -ForegroundColor Gray

                            try {
                                $dismDriverLog = Join-Path $ScratchDir "dism_drivers.log"

                                & dism.exe /Image:"$WimMountDir" `
                                           /Add-Driver `
                                           /Driver:"$resolvedDriversDir" `
                                           /Recurse `
                                           /ForceUnsigned `
                                           /ScratchDir:"$ScratchDir" `
                                           /LogPath:"$dismDriverLog" 2>&1 | Out-Null

                                if ($LASTEXITCODE -in @(0, 3010)) {
                                    Write-OK "Controladores inyectados exitosamente en la imagen WIM ($($driverFiles.Count) archivos .inf)."
                                } else {
                                    Write-Warn "DISM Add-Driver devolvió exit code: $LASTEXITCODE. Revise $dismDriverLog."
                                }
                            } catch {
                                Write-Warn "Error inyectando controladores offline: $($_.Exception.Message)"
                            }
                        } else {
                            Write-Host "    Carpeta 'Drivers' encontrada pero sin archivos .inf." -ForegroundColor DarkYellow
                        }
                    }

                    #==================================================================
                    # FEATURES ON DEMAND
                    #==================================================================

                    Write-Host ""
                    Write-Host "    ══ Eliminar Features on Demand ══" -ForegroundColor Cyan

                    $optProfileInt = [int]$script:OptProfile

                    $fodsToRemove = @(
                        "Hello.Face*"
                        "MathRecognizer*"
                        "Browser.InternetExplorer*"
                    )

                    if ($optProfileInt -ge 2) {
                        $fodsToRemove += @(
                            "Media.WindowsMediaPlayer*"
                            "App.Support.QuickAssist*"
                            "App.StepsRecorder*"
                        )
                    }

                    if ($optProfileInt -eq 3) {
                        $fodsToRemove += @(
                            "Print.Management.Console*"
                            "WMI-SNMP-Provider*"
                        )
                    }

                    try {
                        $installedFods = Get-WindowsCapability -Path $WimMountDir -ErrorAction Stop |
                            Where-Object {
                                $capName = $_.Name
                                $_.State -eq "Installed" -and
                                $(
                                    $match = $false
                                    foreach ($pattern in $fodsToRemove) {
                                        if ($capName -like $pattern) {
                                            $match = $true
                                            break
                                        }
                                    }
                                    $match
                                )
                            }

                        if ($installedFods) {
                            foreach ($fod in $installedFods) {
                                Write-Host "    Eliminando FOD: $($fod.Name)" -ForegroundColor Gray
                                Remove-WindowsCapability -Path $WimMountDir -Name $fod.Name -ErrorAction SilentlyContinue | Out-Null
                            }

                            Write-OK "Features on Demand eliminados."
                        } else {
                            Write-Host "    No se detectaron FODs coincidentes instalados." -ForegroundColor Gray
                        }
                    } catch {
                        Write-Warn "Error eliminando Features on Demand: $($_.Exception.Message)"
                    }

                    #==================================================================
                    # DEBLOAT OFFLINE APPX
                    #==================================================================

                    Write-Host ""
                    Write-Host "    ══ Debloat offline AppX ══" -ForegroundColor Cyan

                    $protectedPatterns = @(
                        'Microsoft.WindowsStore'
                        'Microsoft.StorePurchaseApp'
                        'Microsoft.DesktopAppInstaller'
                        'Microsoft.SecHealthUI'
                        'Microsoft.XboxIdentityProvider'
                        'Microsoft.Xbox.TCUI'
                        'Microsoft.VCLibs'
                        'Microsoft.UI.Xaml'
                        'Microsoft.NET.Native'
                    )

                    if ($optProfileInt -le 2) {
                        $protectedPatterns += @(
                            'Microsoft.XboxGamingOverlay'
                            'Microsoft.WindowsNotepad'
                            'Microsoft.WindowsTerminal'
                            'Microsoft.ScreenSketch'
                            'Microsoft.HEIFImageExtension'
                            'Microsoft.HEVCVideoExtension'
                            'Microsoft.WebMediaExtensions'
                            'Microsoft.VP9VideoExtensions'
                            'Microsoft.WebpImageExtension'
                            'Microsoft.RawImageExtension'
                            'Microsoft.WindowsCalculator'
                        )
                    }

                    if ($optProfileInt -eq 1) {
                        $protectedPatterns += @(
                            'Microsoft.Paint'
                            'Microsoft.WindowsSoundRecorder'
                            'Microsoft.WindowsCamera'
                            'Microsoft.WindowsAlarms'
                            'Microsoft.Windows.Photos'
                            'Microsoft.GamingApp'
                        )
                    }

                    try {
                        $allProvPkgs = Get-AppxProvisionedPackage -Path $WimMountDir -ErrorAction Stop

                        $removablePkgs = $allProvPkgs | Where-Object {
                            $pkgName = $_.DisplayName
                            $isProtected = $false

                            foreach ($pattern in $protectedPatterns) {
                                if ($pkgName -like "*$pattern*") {
                                    $isProtected = $true
                                    break
                                }
                            }

                            -not $isProtected
                        }

                        $protectedCount = $allProvPkgs.Count - $removablePkgs.Count

                        Write-Host "    Paquetes provisionados: $($allProvPkgs.Count)." -ForegroundColor Gray
                        Write-Host "    Protegidos: $protectedCount." -ForegroundColor Gray
                        Write-Host "    Seleccionables: $($removablePkgs.Count)." -ForegroundColor Gray

                        if ($removablePkgs.Count -gt 0) {
                            $debloatList = $removablePkgs | ForEach-Object {
                                [PSCustomObject]@{
                                    Name        = $_.DisplayName
                                    PackageName = $_.PackageName
                                    Version     = $_.Version
                                }
                            } | Sort-Object Name

                            $selectedToRemove = $null

                            if ($optProfileInt -eq 1) {
                                if (-not $SkipAutoUnattend) {
                                    $hasGridView = Get-Command -Name Out-GridView -ErrorAction SilentlyContinue

                                    if ($hasGridView) {
                                        Write-Host "    Abriendo selector gráfico de bloatware..." -ForegroundColor Gray

                                        $selectedToRemove = $debloatList | Out-GridView `
                                            -Title "DEBLOAT OFFLINE: seleccione apps a eliminar" `
                                            -PassThru

                                        $selectedToRemove = @($selectedToRemove)
                                    } else {
                                        Write-Host "    Out-GridView no disponible. Selección por consola:" -ForegroundColor Yellow

                                        for ($j = 0; $j -lt $debloatList.Count; $j++) {
                                            Write-Host "    [$($j + 1)] $($debloatList[$j].Name)" -ForegroundColor White
                                        }

                                        Write-Host ""
                                        Write-Host "    Opciones: números separados por coma | [A] Todas | [N] Ninguna" -ForegroundColor Cyan
                                        $consoleChoice = Read-Host "    Selección"

                                        if ($consoleChoice -match '^[Aa]$') {
                                            $selectedToRemove = $debloatList
                                        } elseif ($consoleChoice -match '^[Nn]$') {
                                            $selectedToRemove = $null
                                        } else {
                                            $indices = $consoleChoice -split ',' |
                                                ForEach-Object {
                                                    $n = 0
                                                    if ([int]::TryParse($_.Trim(), [ref]$n)) { $n - 1 } else { -1 }
                                                } |
                                                Where-Object { $_ -ge 0 -and $_ -lt $debloatList.Count }

                                            if ($indices) {
                                                $selectedToRemove = @($debloatList)[$indices]
                                            } else {
                                                $selectedToRemove = $null
                                            }
                                        }
                                    }
                                } else {
                                    # Perfil conservador desatendido: por seguridad, no eliminar nada.
                                    Write-Host "    Perfil conservador desatendido: se conservan las apps seleccionables." -ForegroundColor Gray
                                    $selectedToRemove = $null
                                }
                            } else {
                                # Perfil 2 o 3: eliminación automática de todo lo no protegido.
                                Write-Host "    Perfil $optProfileInt eliminando automáticamente bloatware no protegido." -ForegroundColor Gray
                                $selectedToRemove = $debloatList
                            }

                            if ($selectedToRemove -and @($selectedToRemove).Count -gt 0) {
                                Write-Host "    Eliminando $(@($selectedToRemove).Count) paquetes..." -ForegroundColor Cyan

                                foreach ($pkg in $selectedToRemove) {
                                    try {
                                        Remove-AppxProvisionedPackage -Path $WimMountDir `
                                                                      -PackageName $pkg.PackageName `
                                                                      -ErrorAction Stop | Out-Null

                                        Write-Host "      Eliminado: $($pkg.Name)" -ForegroundColor Green
                                    } catch {
                                        Write-Host "      Error eliminando $($pkg.Name): $($_.Exception.Message)" -ForegroundColor Yellow
                                    }
                                }

                                Write-OK "Debloat offline completado."
                            } else {
                                Write-Host "    Sin selección. Conservando paquetes." -ForegroundColor Gray
                            }
                        } else {
                            Write-Host "    No hay paquetes removibles." -ForegroundColor Gray
                        }
                    } catch {
                        Write-Warn "No se pudo obtener la lista de paquetes AppX provisionados: $($_.Exception.Message)"
                    }

                    #==================================================================
                    # RESETBASE
                    #==================================================================

                    if ($successCount -gt 0) {
                        Write-Host ""
                        Write-Host "    Ejecutando ResetBase / StartComponentCleanup..." -ForegroundColor Cyan

                        try {
                            Repair-WindowsImage -Path $WimMountDir `
                                                -StartComponentCleanup `
                                                -ResetBase `
                                                -ScratchDirectory $ScratchDir `
                                                -ErrorAction Stop

                            Write-OK "Componentes limpiados y consolidados."
                        } catch {
                            Write-Warn "Error ejecutando ResetBase: $($_.Exception.Message)"
                        }
                    }

                    #==================================================================
                    # TWEAKS VISUALES OFFLINE
                    #==================================================================

                    if ($script:InjectVisualTweaks) {
                        Write-Host ""
                        Write-Host "    ══ Tweaks visuales offline ══" -ForegroundColor Cyan

                        $ntuserPath = Join-Path $WimMountDir "Users\Default\NTUSER.DAT"

                        if (Test-Path $ntuserPath) {
                            $hiveLoaded = $false

                            try {
                                Write-Host "    Cargando NTUSER.DAT del usuario default..." -ForegroundColor Gray

                                $procLoad = Start-Process -FilePath "reg.exe" `
                                                          -ArgumentList @("load", "HKLM\OfflineDefaultUser", $ntuserPath) `
                                                          -Wait `
                                                          -PassThru `
                                                          -NoNewWindow

                                if ($procLoad.ExitCode -eq 0) {
                                    $hiveLoaded = $true

                                    $darkModeCommand = "cmd.exe /c reg add HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize /v AppsUseLightTheme /t REG_DWORD /d 0 /f && reg add HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize /v SystemUsesLightTheme /t REG_DWORD /d 0 /f"

                                    $tweaks = @(
                                        # Modo Oscuro Nativo directo en Themes\Personalize
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
                                            Name = "AppsUseLightTheme"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
                                            Name = "SystemUsesLightTheme"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
                                            Name = "EnableTransparency"
                                            Type = "REG_DWORD"
                                            Data = "1"
                                        }
                                        # Fallback RunOnce
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\RunOnce"
                                            Name = "ApplyDarkMode"
                                            Type = "REG_SZ"
                                            Data = $darkModeCommand
                                        }
                                        # Bloqueo ContentDeliveryManager (Anti-Reinstalación Bloatware en la Nube)
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                                            Name = "SilentInstalledAppsEnabled"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                                            Name = "OemPreInstalledAppsEnabled"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                                            Name = "PreInstalledAppsEnabled"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                                            Name = "ContentDeliveryAllowed"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                                            Name = "SubscribedContent-338388Enabled"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                                            Name = "SubscribedContent-310093Enabled"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                                            Name = "SubscribedContent-338389Enabled"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                                            Name = "SubscribedContent-353696Enabled"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                                            Name = "SubscribedContent-353694Enabled"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                                            Name = "SubscribedContent-353698Enabled"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                                            Name = "SubscribedContent-338387Enabled"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                                            Name = "SubscribedContent-338393Enabled"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                                            Name = "SoftLandingEnabled"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                                            Name = "RotatingLockScreenOverlayEnabled"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                                            Name = "SystemPanelEnabled"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        # Ajustes de Explorador y Barra de Tareas
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                                            Name = "LaunchTo"
                                            Type = "REG_DWORD"
                                            Data = "1"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                                            Name = "HideFileExt"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                                            Name = "TaskbarAl"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                                            Name = "ShowTaskViewButton"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Search"
                                            Name = "SearchboxTaskbarMode"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Search"
                                            Name = "SearchboxTaskbarModeCache"
                                            Type = "REG_DWORD"
                                            Data = "1"
                                        }
                                    )

                                    foreach ($tweak in $tweaks) {
                                        & reg.exe add $tweak.Path /v $tweak.Name /t $tweak.Type /d $tweak.Data /f 2>&1 | Out-Null
                                        if ($LASTEXITCODE -ne 0) {
                                            Write-Warn "Error aplicando tweak: $($tweak.Path) /v $($tweak.Name)"
                                        }
                                    }

                                    Write-OK "Tweaks visuales inyectados en Default User."
                                } else {
                                    Write-Warn "No se pudo cargar NTUSER.DAT. Exit code: $($procLoad.ExitCode)."
                                }
                            } catch {
                                Write-Warn "Error aplicando tweaks visuales offline: $($_.Exception.Message)"
                            } finally {
                                if ($hiveLoaded) {
                                    Write-Host "    Descargando colmena NTUSER.DAT..." -ForegroundColor Gray

                                    $unloaded = Invoke-RegUnloadHive -HiveName "HKLM\OfflineDefaultUser"

                                    if ($unloaded) {
                                        Write-OK "Colmena descargada correctamente."
                                    } else {
                                        Write-Warn "No se pudo descargar la colmena. Puede quedar cargada hasta reiniciar."
                                    }
                                }
                            }
                        } else {
                            Write-Warn "No se encontró NTUSER.DAT en: $ntuserPath"
                        }
                    }

                    #==================================================================
                    # INYECTAR SCRIPTS Y SetupComplete.cmd EN WIM
                    #==================================================================

                    $wimScriptsDir = Join-Path $WimMountDir "Windows\Setup\Scripts"

                    if (-not (Test-Path $wimScriptsDir)) {
                        New-Item -ItemType Directory -Path $wimScriptsDir -Force | Out-Null
                    }

                    foreach ($script in $scriptsToInject) {
                        $dest = Join-Path $wimScriptsDir $script.DestName
                        Copy-Item -Path $script.Source -Destination $dest -Force
                        Write-OK "Inyectado en WIM índice ${wimIndex}: $($script.DestName)"
                    }

                    if ($setupCompleteContent) {
                        $setupCmdDest = Join-Path $wimScriptsDir "SetupComplete.cmd"
                        $setupCompleteContent | Out-File -FilePath $setupCmdDest -Encoding ASCII -Force
                        Write-OK "Inyectado en WIM índice ${wimIndex}: SetupComplete.cmd"
                    } else {
                        Write-Warn "No existe contenido de SetupComplete.cmd para inyectar."
                    }

                    Dismount-WindowsImage -Path $WimMountDir -Save -ScratchDirectory $ScratchDir -ErrorAction Stop

                    Write-OK "WIM índice $wimIndex$imgNameStr desmontado con cambios guardados."

                    $wimInjected = $true

                    if (Test-Path $WimMountDir) {
                        Remove-Item -Path $WimMountDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                } catch {
                    Write-Warn "Error inyectando en WIM índice ${wimIndex}: $($_.Exception.Message)"

                    try {
                        Dismount-WindowsImage -Path $WimMountDir -Discard -ScratchDirectory $ScratchDir -ErrorAction SilentlyContinue
                    } catch {
                        # Ignorar error de desmontaje
                    }
                }
            }

            #==================================================================
            # EXPORTAR / CONSOLIDAR WIM
            #==================================================================

            if ($wimInjected -and $WimCompression -ne "None") {
                Write-Host ""
                Write-Host "    ══ Consolidación final del WIM ══" -ForegroundColor Cyan
                Write-Host "    Exportando WIM para eliminar espacio muerto y aplicar compresión $WimCompression..." -ForegroundColor Gray

                $destName = $wimFile.FullName + ".tmp"

                if (Test-Path $destName) {
                    Remove-Item -Path $destName -Force -ErrorAction SilentlyContinue
                }

                try {
                    $exportTargets = $allWimImages | Where-Object { $indexesToProcess -contains $_.Index }
                    $compressArg = $WimCompression.ToLower()

                    foreach ($img in $exportTargets) {
                        Write-Host "    Exportando índice $($img.Index): $($img.Name)..." -ForegroundColor Gray

                        & dism.exe /Export-Image `
                                   /SourceImageFile:"$($wimFile.FullName)" `
                                   /SourceIndex:$($img.Index) `
                                   /DestinationImageFile:"$destName" `
                                   /Compress:$compressArg `
                                   /ScratchDir:"$ScratchDir" 2>&1 | Out-Null

                        if ($LASTEXITCODE -ne 0) {
                            throw "DISM /Export-Image falló para el índice $($img.Index). Exit code: $LASTEXITCODE."
                        }
                    }

                    if (Test-Path $destName) {
                        $originalSize = (Get-Item $wimFile.FullName).Length
                        $bakName = $wimFile.FullName + ".bak"

                        if (Test-Path $bakName) {
                            Remove-Item -Path $bakName -Force -ErrorAction SilentlyContinue
                        }

                        # 1. Respaldo atómico seguro antes de reemplazar
                        Rename-Item -Path $wimFile.FullName -NewName (Split-Path $bakName -Leaf) -Force

                        try {
                            # 2. Renombrar archivo consolidado al nombre definitivo
                            Rename-Item -Path $destName -NewName $wimFile.Name -Force

                            # 3. Validar existencia del WIM final
                            if (Test-Path $wimFile.FullName) {
                                # Éxito: eliminar respaldo .bak
                                Remove-Item -Path $bakName -Force -ErrorAction SilentlyContinue

                                $newSize = (Get-Item $wimFile.FullName).Length
                                $savedMB = [math]::Round(($originalSize - $newSize) / 1MB, 1)
                                $exportSucceeded = $true

                                Write-OK "WIM consolidado correctamente. Ahorro aproximado: $savedMB MB."
                            } else {
                                throw "El archivo final WIM no se encontró tras el renombrado."
                            }
                        } catch {
                            # Si falló renombrar el nuevo, restaurar el original desde el .bak
                            if (Test-Path $bakName) {
                                Rename-Item -Path $bakName -NewName $wimFile.Name -Force -ErrorAction SilentlyContinue
                            }
                            throw $_
                        }
                    } else {
                        throw "El archivo WIM exportado no existe después de DISM /Export-Image."
                    }
                } catch {
                    Write-Warn "Error durante la exportación final: $($_.Exception.Message)"

                    if (Test-Path $destName) {
                        Remove-Item -Path $destName -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            #==================================================================
            # DECIDIR ÍNDICE FINAL PARA ImageInstall
            #==================================================================

            if ($selectedSingleIndex -and $wimInjected) {
                if ($WimCompression -eq "None") {
                    # Sin exportación: el índice final sigue siendo el original.
                    $finalImageInstallIndex = [int]$selectedSingleIndex
                } elseif ($exportSucceeded) {
                    # Exportación exitosa: el WIM resultante normalmente reindexa desde 1.
                    $finalImageInstallIndex = 1
                } else {
                    # Exportación intentada pero fallida: no inyectar ImageInstall.
                    $finalImageInstallIndex = $null
                }

                if ($finalImageInstallIndex -and (-not $SkipAutoUnattend) -and $autounattendPath -and (Test-Path $autounattendPath)) {
                    $enableZT = $false

                    if ($PSBoundParameters.ContainsKey('ZeroTouch')) {
                        $enableZT = $ZeroTouch.IsPresent
                        Write-Host "    Modo Zero-Touch definido por parámetro: $(if ($enableZT) { 'Sí' } else { 'No' })" -ForegroundColor DarkGray
                    } else {
                        Write-Host ""
                        Write-Host "    ══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                        Write-Host "    MODALIDAD DE INSTALACIÓN (Índice único seleccionado: $finalImageInstallIndex)" -ForegroundColor Cyan
                        Write-Host "    ══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                        Write-Host ""

                        $ztOptions = @(
                            '1 - Semi-Desatendida (Recomendado: Tú eliges el disco y partición)'
                            '2 - Zero-Touch 100% Automática (Formatea Disco 0 e instala sin intervención)'
                        )

                        $ztDescs = @(
                            '[Seguro: Omite OOBE, bypass TPM/RAM, pero te permite elegir disco manualmente]'
                            '[ATENCIÓN: Borra Disco 0 en UEFI/GPT y completa la instalación entera sin tocar nada]'
                        )

                        $ztIdx = Invoke-SelectionMenu -Title "¿Desea habilitar instalación 100% Zero-Touch?" `
                                                      -Options $ztOptions `
                                                      -Descriptions $ztDescs `
                                                      -DefaultIndex 0

                        $enableZT = ($ztIdx -eq 1)

                        if ($enableZT) {
                            Write-Host ""
                            Write-Host "    [!] ATENCIÓN: Zero-Touch formateará automáticamente el Disco $ZeroTouchDisk (UEFI/GPT) en la instalación." -ForegroundColor Yellow
                        }
                    }

                    Write-Host ""
                    if ($enableZT) {
                        Write-Host "    Configurando autounattend.xml en modo Zero-Touch (Índice $finalImageInstallIndex, Disco $ZeroTouchDisk)..." -ForegroundColor Cyan
                    } else {
                        Write-Host "    Configurando autounattend.xml para pre-seleccionar índice $finalImageInstallIndex (selección manual de disco)..." -ForegroundColor Cyan
                    }

                    $imageInstallOk = Add-ImageInstallToAutounattend -AutounattendPath $autounattendPath `
                                                                     -ImageIndex $finalImageInstallIndex `
                                                                     -EnableZeroTouch $enableZT `
                                                                     -ZeroTouchDisk $ZeroTouchDisk

                    if ($imageInstallOk) {
                        if ($enableZT) {
                            Write-OK "Zero-Touch configurado en autounattend.xml (Disco $ZeroTouchDisk, Índice $finalImageInstallIndex)."
                        } else {
                            Write-OK "Pre-selección de índice inyectada en autounattend.xml (Índice: $finalImageInstallIndex)."
                        }
                    } else {
                        Write-Warn "No se pudo inyectar configuración en autounattend.xml."
                    }
                }
            }
        } finally {
            # Garantizar desmontaje y limpieza si el punto de montaje sigue activo
            try {
                if (Get-Command "Get-WindowsImage" -ErrorAction SilentlyContinue) {
                    $mountedWim = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $WimMountDir }
                    if ($mountedWim) {
                        Dismount-WindowsImage -Path $WimMountDir -Discard -ErrorAction SilentlyContinue | Out-Null
                    }
                }
            } catch {}

            if (Get-Command "dism.exe" -ErrorAction SilentlyContinue) {
                try { & dism.exe /Cleanup-Mountpoints 2>&1 | Out-Null } catch {}
            }

            if (Test-Path $ScratchDir) {
                Remove-Item -Path $ScratchDir -Recurse -Force -ErrorAction SilentlyContinue
            }

            if (Test-Path $WimMountDir) {
                Remove-Item -Path $WimMountDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
} else {
    Write-Warn "No se encontró install.wim ni install.esd."
    Write-Warn "La ISO dependerá solo de autounattend.xml y `$OEM$."
}

#------------------------------------------------------------------------------
# SI SE SOLICITÓ NO CREAR ISO, TERMINAR AQUÍ
#------------------------------------------------------------------------------

if ($SkipISOCreation) {
    Write-Step "6/6 - Omitiendo reconstrucción de ISO (flag -SkipISOCreation)"

    Write-Host ""
    Write-Host "  ARCHIVOS PREPARADOS EN:" -ForegroundColor Green
    Write-Host "  $ISOFilesDir" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Para crear la ISO manualmente, usa oscdimg:" -ForegroundColor Green
    Write-Host "  winget install -e --id Microsoft.OSCDIMG" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Ejemplo:" -ForegroundColor Gray
    Write-Host "  oscdimg.exe -m -o -u2 -udfver102 -lWINDOWS_OPTIMIZED -bootdata:2#p0,e,b`"$ISOFilesDir\boot\etfsboot.com`"#pEF,e,b`"$ISOFilesDir\efi\microsoft\boot\efisys.bin`" `"$ISOFilesDir`" `"C:\Salida\Windows_Optimized.iso`"" -ForegroundColor Gray
    Write-Host ""

    exit 0
}

#------------------------------------------------------------------------------
# 6/6 - RECONSTRUIR ISO
#------------------------------------------------------------------------------

Write-Step "6/6 - Reconstruyendo ISO..."

# Crear directorio de salida si no existe.
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Nombre de ISO final.
$versionTag = if ($detectedVersion) {
    $detectedVersion
} else {
    "Windows"
}

$isoName = "Windows_${versionTag}_Optimized_$(Get-Date -Format 'yyyyMMdd_HHmmss').iso"
$outputISO = Join-Path $OutputDir $isoName

# Si ya existe un archivo destino con ese nombre, eliminarlo para evitar fallos.
if (Test-Path $outputISO) {
    Remove-Item -Path $outputISO -Force -ErrorAction SilentlyContinue
}

$oscdimg    = Test-OSCDImgInstalled
$isoCreated = $false

#------------------------------------------------------------------------------
# ETIQUETA ISO
#------------------------------------------------------------------------------

$isoLabel = "WIN${versionTag}_OPT"

# Sanitizar etiqueta: solo caracteres seguros, mayúsculas, longitud controlada.
$isoLabel = ($isoLabel -replace '[^A-Za-z0-9_-]', '').ToUpper()

if ([string]::IsNullOrWhiteSpace($isoLabel)) {
    $isoLabel = "WIN_OPT"
}

if ($isoLabel.Length -gt 32) {
    $isoLabel = $isoLabel.Substring(0, 32)
}

#------------------------------------------------------------------------------
# ARCHIVOS DE BOOT
#------------------------------------------------------------------------------

$biosBootFile = Join-Path $ISOFilesDir "boot\etfsboot.com"
$uefiBootFile = Join-Path $ISOFilesDir "efi\microsoft\boot\efisys.bin"

#------------------------------------------------------------------------------
# CREACIÓN DE ISO CON OSCDIMG
#------------------------------------------------------------------------------

$batLine = $null

if (-not $oscdimg) {
    Write-Warn "oscdimg.exe no está disponible."
    Write-Warn "Instálalo con:"
    Write-Warn "winget install -e --id Microsoft.OSCDIMG"
    Write-Warn "O instala el Windows ADK Deployment Tools."
} elseif (-not (Test-Path $biosBootFile) -or -not (Test-Path $uefiBootFile)) {
    Write-Warn "Faltan archivos de arranque críticos en la ISO extraída."
    Write-Warn "Ruta BIOS esperada: $biosBootFile"
    Write-Warn "Ruta UEFI esperada: $uefiBootFile"
    Write-Warn "No se generará una ISO no arrancable."
} else {
    Write-Host "    Usando oscdimg: $oscdimg" -ForegroundColor Gray
    Write-Host "    Etiqueta ISO: $isoLabel" -ForegroundColor Gray
    Write-Host "    BIOS boot: $biosBootFile" -ForegroundColor Gray
    Write-Host "    UEFI boot: $uefiBootFile" -ForegroundColor Gray

    $tempBat = $null

    try {
        # Construir línea de comandos de forma segura.
        # Se usa un archivo batch temporal para evitar problemas de quoting
        # con el argumento -bootdata de oscdimg.
        $tempBat = Join-Path ([System.IO.Path]::GetTempPath()) "oscdimg_$(Get-Random).cmd"

        $batLine = '"{0}" -m -o -u2 -udfver102 -l"{1}" -bootdata:2#p0,e,b"{2}"#pEF,e,b"{3}" "{4}" "{5}"' -f `
            $oscdimg,
            $isoLabel,
            $biosBootFile,
            $uefiBootFile,
            $ISOFilesDir,
            $outputISO

        $batContent = "@echo off`r`n$batLine"

        $batContent | Out-File -FilePath $tempBat -Encoding ASCII -Force

        Write-Host "    Ejecutando oscdimg..." -ForegroundColor Gray
        Write-Host "    CMD: $batLine" -ForegroundColor DarkGray

        $proc = Start-Process -FilePath "cmd.exe" `
                              -ArgumentList @("/c", $tempBat) `
                              -NoNewWindow `
                              -Wait `
                              -PassThru

        if ($proc.ExitCode -eq 0 -and (Test-Path $outputISO)) {
            $isoCreated = $true
            Write-OK "ISO creada exitosamente: $outputISO"

            try {
                $isoHash = Get-FileHash -Path $outputISO -Algorithm SHA256 -ErrorAction Stop
                Write-Host "    SHA256: $($isoHash.Hash)" -ForegroundColor DarkGray
            } catch {
                # Hash opcional; no bloquear si falla.
            }
        } else {
            Write-Warn "oscdimg falló con código de salida: $($proc.ExitCode)"
            Write-Warn "CMD ejecutado: $batLine"
            Write-Warn "Revisa espacio en disco, permisos de escritura y que la carpeta ISO_Files esté completa."
        }
    } catch {
        Write-Warn "Error ejecutando oscdimg: $($_.Exception.Message)"
    } finally {
        if ($tempBat -and (Test-Path $tempBat)) {
            Remove-Item -Path $tempBat -Force -ErrorAction SilentlyContinue
        }
    }
}

#------------------------------------------------------------------------------
# LIMPIEZA FINAL DE DIRECTORIOS TEMPORALES
# Se limpian TODOS los residuos: ScratchDir, WimMountDir y ExtractDir.
# ExtractDir puede pesar 5-12 GB por ejecución; si no se limpia, cada corrida
# acumula ese espacio en %TEMP% indefinidamente.
# Usar -KeepExtractDir para conservarlo cuando se necesite inspección manual.
#------------------------------------------------------------------------------

foreach ($temporaryDir in @($ScratchDir, $WimMountDir)) {
    if (Test-Path $temporaryDir) {
        Remove-Item -Path $temporaryDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($KeepExtractDir) {
    Write-Host ""
    Write-Host "  [INFO] -KeepExtractDir activo. Carpeta de extracción conservada en:" -ForegroundColor DarkYellow
    Write-Host "  $ExtractDir" -ForegroundColor DarkYellow
    Write-Host "  Recuerda eliminarla manualmente cuando ya no la necesites." -ForegroundColor DarkYellow
} else {
    Write-Host ""
    Write-Host "  Limpiando carpeta temporal de extracción..." -ForegroundColor DarkGray
    if (Test-Path $ExtractDir) {
        try {
            Remove-Item -Path $ExtractDir -Recurse -Force -ErrorAction Stop
            Write-Host "  Carpeta temporal eliminada: $ExtractDir" -ForegroundColor DarkGray
        } catch {
            Write-Host "  [AVISO] No se pudo eliminar $ExtractDir automaticamente." -ForegroundColor Yellow
            Write-Host "  Elimínala manualmente para recuperar el espacio en disco." -ForegroundColor Yellow
            Write-Host "  Ruta: $ExtractDir" -ForegroundColor Yellow
        }
    }
}

#------------------------------------------------------------------------------
# RESUMEN DE LOGGING — cierra log y transcript antes del resumen visual
#------------------------------------------------------------------------------

Write-LogSummary

#------------------------------------------------------------------------------
# RESUMEN FINAL
#------------------------------------------------------------------------------

$profileNames = @{
    "1" = "Conservador"
    "2" = "Gaming"
    "3" = "Hardcore Barebones"
}

$profileDisplayName = if ($profileNames.ContainsKey([string]$script:OptProfile)) {
    $profileNames[[string]$script:OptProfile]
} else {
    [string]$script:OptProfile
}

$oneDriveDisplayName = if ($script:BlockOneDrive) {
    "Bloqueado"
} else {
    "Conservado"
}

$tweaksStatus = if ($script:InjectVisualTweaks) {
    "Sí"
} else {
    "No"
}

$autounattendStatus = if ((-not $SkipAutoUnattend) -and $autounattendPath -and (Test-Path $autounattendPath)) {
    $autounattendPath
} else {
    "Omitido"
}

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "  ║                    OPERACIÓN COMPLETADA                    ║" -ForegroundColor Magenta
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

Write-Host "  ISO original:              $SourceISO" -ForegroundColor Gray
Write-Host "  Versión detectada:         Windows $versionTag" -ForegroundColor Gray
Write-Host "  Carpeta extraída:          $ISOFilesDir" -ForegroundColor Cyan
Write-Host "  autounattend.xml:          $autounattendStatus" -ForegroundColor Gray
Write-Host "  Usuario local:             $LocalUser" -ForegroundColor Gray
Write-Host "  Idioma UI:                 $Language" -ForegroundColor Gray
Write-Host "  Región:                    $(if ($Locale) { $Locale } else { $Language })" -ForegroundColor Gray
Write-Host "  Zona horaria:              $Timezone" -ForegroundColor Gray
Write-Host "  Teclado:                   $(if ($KeyboardOverride) { $KeyboardOverride } else { "$Language (igual que idioma)" })" -ForegroundColor Gray
Write-Host "  Perfil de optimización:    $profileDisplayName" -ForegroundColor Gray
Write-Host "  OneDrive:                  $oneDriveDisplayName" -ForegroundColor Gray
Write-Host "  Tweaks visuales offline:   $tweaksStatus" -ForegroundColor Gray
Write-Host "  Inyección WIM:             $(if ($wimInjected) { 'Sí' } else { 'No' })" -ForegroundColor Gray

Write-Host ""
Write-Host "  Contenido inyectado:" -ForegroundColor White
Write-Host "  ├── autounattend.xml" -ForegroundColor Gray
Write-Host "  │   - Instalación semi-desatendida" -ForegroundColor Gray
Write-Host "  │   - Usuario: $LocalUser" -ForegroundColor Gray
Write-Host "  │   - Idioma: $Language" -ForegroundColor Gray
Write-Host "  │   - Edición/Disco: selección manual durante instalación" -ForegroundColor Gray
Write-Host "  │"
Write-Host '  ├── sources\$OEM$\$$\Setup\Scripts' -ForegroundColor Gray
Write-Host "  │   ├── SetupComplete.cmd" -ForegroundColor Gray

if ($scriptsToInject -and $scriptsToInject.Count -gt 0) {
    foreach ($script in $scriptsToInject) {
        Write-Host "  │   ├── $($script.DestName)" -ForegroundColor Gray
    }
} else {
    Write-Host "  │   ├── (sin script optimizador)" -ForegroundColor DarkYellow
}

Write-Host "  │"
Write-Host "  └── install.wim scripts inyectados offline: $(if ($wimInjected) { 'Sí' } else { 'No' })" -ForegroundColor Gray

Write-Host ""

if ($isoCreated) {
    try {
        $isoSizeGB = [math]::Round((Get-Item $outputISO).Length / 1GB, 2)
        Write-Host "  ISO generada: $outputISO" -ForegroundColor Green
        Write-Host "  Tamaño: $isoSizeGB GB" -ForegroundColor Green
    } catch {
        Write-Host "  ISO generada: $outputISO" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "  Para usar:" -ForegroundColor Yellow
    Write-Host "  1. Graba la ISO en un USB con Rufus." -ForegroundColor Yellow
    Write-Host "  2. Inicia desde el USB." -ForegroundColor Yellow
    Write-Host "  3. Selecciona edición y disco si se solicita." -ForegroundColor Yellow
    Write-Host "  4. El resto de la instalación debería ser automático." -ForegroundColor Yellow
    Write-Host "  5. Al llegar al escritorio, SetupComplete.cmd ejecutará el optimizador si existe." -ForegroundColor Yellow
} else {
    Write-Host "  ISO no generada automáticamente." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Los archivos listos para crear la ISO están en:" -ForegroundColor Cyan
    Write-Host "  $ISOFilesDir" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Puedes crearla manualmente con oscdimg." -ForegroundColor Yellow

    if ($batLine) {
        Write-Host ""
        Write-Host "  Comando usado/intentado:" -ForegroundColor DarkGray
        Write-Host "  $batLine" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "  Nota: Si conservas la carpeta extraída, puedes inspeccionar" -ForegroundColor DarkGray
Write-Host "  autounattend.xml, ei.cfg, `$OEM$ y sources antes de quemar la ISO." -ForegroundColor DarkGray
Write-Host ""

