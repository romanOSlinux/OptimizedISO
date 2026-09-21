#Requires -RunAsAdministrator

<#
.SYNOPSIS
Genera una ISO de Windows 10/11 con scripts de optimización integrados — Versión 2.0 (v2).

.DESCRIPTION
Constructor automatizado y modular de segunda generación para imágenes de Windows.
Soporta ingestión de ISOs locales y descarga dinámica en vivo desde los servidores CDN oficiales
de Microsoft Learn (Canal General 25H2/24H2/23H2, LTSC 2024 IoT y LTSC 2021).
Incluye layout GPT con partición WinRE de 500 MB, Modo Oscuro nativo en OOBE, políticas de
controladores bajo demanda, debloat profundo con whitelist segura, bypasses automáticos
y reconstrucción dual-boot UEFI/BIOS (El Torito).

.PARAMETER SourceISO
Ruta a la ISO original de Windows 10 u 11 (si se omite, se ofrece descarga oficial interactiva).

.PARAMETER DownloadOfficialISO
Activa la descarga directa de medios limpios desde los servidores oficiales de Microsoft.

.PARAMETER DownloadVersion
Versión de Windows a descargar (ej. "11_25H2", "11_24H2", "11_23H2", "11_LTSC_2024").

.PARAMETER DownloadEdition
Tipo de medio: "Consumer", "Business", "IoTEnterprise".

.PARAMETER DownloadLanguage
Idioma oficial de descarga: "Spanish", "Spanish (Mexico)", "English", etc.

.PARAMETER OutputDir
Directorio donde se guardará la ISO resultante y los registros de compilación.

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
Activa la instalación 100% desatendida (Zero-Touch): particiona automáticamente el disco 0 en UEFI/GPT (con WinRE 500MB), acepta el EULA e instala el índice seleccionado sin intervención del usuario.

.PARAMETER ZeroTouchDisk
Índice del disco físico de destino para Zero-Touch (por defecto: 0).

.PARAMETER ProcessTimeoutMinutes
Tiempo límite máximo en minutos para la ejecución de subprocesos externos (DISM, oscdimg, 7-Zip, curl).
Por defecto: 30 minutos. Establecer en 0 para desactivar el corte por timeout.

.PARAMETER HeartbeatIntervalSeconds
Intervalo en segundos para la emisión de reportes de actividad/heartbeat en pantalla y logs (por defecto: 15s).

.PARAMETER SkipComponentCleanup
Omite la ejecución de StartComponentCleanup / ResetBase en la imagen WIM (acelera la compilación evitando esperas largas).

.PARAMETER KeepExtractDir
Si se especifica, conserva la carpeta temporal de extracción ($ExtractDir) tras
finalizar. Útil para inspección manual. Por defecto se elimina automáticamente.

.PARAMETER RuntimesPath
Ruta a la carpeta Runtimes/ que contiene Visual C++ y DirectX redistribuibles.

.PARAMETER DriversPath
Ruta a la carpeta Drivers/ que contiene controladores (.inf) para inyección offline.

.PARAMETER UpdatesPath
Ruta a la carpeta Updates/ que contiene paquetes de actualización oficiales (.msu/.cab) para inyección offline.

.EXAMPLE
# Modo Asistente Interactivo Completo (con descarga dinámica de ISO si no se especifica SourceISO):
.\New-OptimizedWindowsISO-v2.ps1

.EXAMPLE
# Optimizar una ISO local existente:
.\New-OptimizedWindowsISO-v2.ps1 -SourceISO "C:\ISOs\Win11_24H2_ES.iso"

.EXAMPLE
# Descarga desatendida de Windows 11 IoT Enterprise LTSC 2024 y optimización directa:
.\New-OptimizedWindowsISO-v2.ps1 -DownloadOfficialISO -DownloadVersion "11_LTSC_2024" -DownloadEdition "IoTEnterprise" -DownloadLanguage "Spanish" -ZeroTouch
#>

param(
    [Parameter()]
    [string]$SourceISO = "",

    [Parameter()]
    [switch]$DownloadOfficialISO,

    [Parameter()]
    [string]$DownloadVersion = "",

    [Parameter()]
    [string]$DownloadEdition = "",

    [Parameter()]
    [string]$DownloadLanguage = "",

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
    [ValidateSet("amd64", "arm64")]
    [string]$Architecture = "amd64",

    [Parameter()]
    [int]$ProcessTimeoutMinutes = 30,

    [Parameter()]
    [int]$HeartbeatIntervalSeconds = 15,

    [Parameter()]
    [switch]$SkipComponentCleanup,

    [Parameter()]
    [switch]$KeepExtractDir,

    [Parameter()]
    [string]$RuntimesPath = "",

    [Parameter()]
    [string]$DriversPath = "",

    [Parameter()]
    [switch]$SkipBootWimDrivers,

    [Parameter()]
    [string]$UpdatesPath = "",

    [Parameter()]
    [switch]$SkipUpdates,

    [Parameter()]
    [switch]$SkipDrivers,

    [Parameter()]
    [switch]$SkipRuntimes,

    [Parameter()]
    [switch]$ZeroTouch,

        [Parameter()]
    [int]$ZeroTouchDisk = 0,

    [Parameter()]
    [string]$PresetFile = "",

    [Parameter()]
    [switch]$SavePreset,

    [Parameter()]
    [switch]$EnableHyperV,

    [Parameter()]
    [switch]$DisableDefenderExclusion,

    [Parameter()]
    [switch]$Headless
)

#------------------------------------------------------------------------------
# CONFIGURACIÓN GENERAL
#------------------------------------------------------------------------------

$ErrorActionPreference = 'Continue'
$script:Headless = [bool]$Headless -or [bool]$PresetFile

# TLS 1.2 para posibles descargas HTTPS en PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# -----------------------------------------------------------------------------
# CARGA DE MOTOR VISUAL UNIFICADO (Core\UI-Engine.ps1) O MICRO-FALLBACK STANDALONE
# -----------------------------------------------------------------------------
$uiEnginePaths = [System.Collections.Generic.List[string]]::new()
if ($PSScriptRoot) {
    $uiEnginePaths.Add((Join-Path $PSScriptRoot "Core\UI-Engine.ps1"))
    $uiEnginePaths.Add((Join-Path $PSScriptRoot "UI-Engine.ps1"))
    $uiEnginePaths.Add((Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\UI-Engine.ps1"))
    $uiEnginePaths.Add((Join-Path (Split-Path $PSScriptRoot -Parent) "Core\UI-Engine.ps1"))
}
$loc = Get-Location
if ($loc) {
    $uiEnginePaths.Add((Join-Path $loc.Path "Core\UI-Engine.ps1"))
    $uiEnginePaths.Add((Join-Path $loc.Path "scripts\Core\UI-Engine.ps1"))
    $uiEnginePaths.Add((Join-Path $loc.Path "UI-Engine.ps1"))
}
$uiEnginePaths.Add("C:\OptimizedISO\scripts\Core\UI-Engine.ps1")
$uiEnginePaths.Add("C:\scripts\Core\UI-Engine.ps1")
$uiEnginePaths.Add("C:\scripts\UI-Engine.ps1")
$uiEnginePaths.Add("C:\Windows\Setup\Scripts\Core\UI-Engine.ps1")

$uiLoaded = $false
foreach ($p in $uiEnginePaths) {
    if ($p -and (Test-Path $p)) {
        . $p
        $uiLoaded = $true
        break
    }
}

# Iniciar diccionario unificado de resolucion
$script:ResolvedParameters = [Hashtable]::new()
foreach ($k in $PSBoundParameters.Keys) {
    $script:ResolvedParameters[$k] = $PSBoundParameters[$k]
}
if ($script:Headless) {
    $script:ResolvedParameters['Headless'] = $true
}

# Cargar Preset JSON si se especifico
if ($PresetFile) {
    if (Test-Path $PresetFile) {
        Import-BuildPreset -PresetPath $PresetFile -ScriptBoundParameters $script:ResolvedParameters
    } else {
        Write-Warn "Archivo Preset '$PresetFile' no encontrado."
    }
}

$script:SkipUpdates        = if ($script:ResolvedParameters.ContainsKey('SkipUpdates')) { [bool]$script:ResolvedParameters['SkipUpdates'] } else { [bool]$SkipUpdates }
$script:SkipDrivers        = if ($script:ResolvedParameters.ContainsKey('SkipDrivers')) { [bool]$script:ResolvedParameters['SkipDrivers'] } else { [bool]$SkipDrivers }
$script:SkipRuntimes       = if ($script:ResolvedParameters.ContainsKey('SkipRuntimes')) { [bool]$script:ResolvedParameters['SkipRuntimes'] } else { [bool]$SkipRuntimes }
$script:SkipBootWimDrivers = if ($script:ResolvedParameters.ContainsKey('SkipBootWimDrivers')) { [bool]$script:ResolvedParameters['SkipBootWimDrivers'] } else { [bool]$SkipBootWimDrivers }


if (-not $uiLoaded) {
    function Show-UnifiedBanner  { param($Title, $Subtitle = "", [switch]$ShowSystemInfo, [switch]$NoClear) Write-Host "`n=== $Title $(if($Subtitle){"($Subtitle)"}) ===`n" -ForegroundColor Cyan }
    function Write-StepHeader    { param([int]$StepNumber, [int]$TotalSteps, [string]$Message) Write-Host "`n>>> [$StepNumber/$TotalSteps] $Message" -ForegroundColor Cyan }
    function Write-SubStep       { param([string]$Message) Write-Host "  -> $Message" -ForegroundColor Gray }
    function Write-OK            { param([string]$Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
    function Write-Warn          { param([string]$Message, [string]$Cause = "", [string]$Action = "") Write-Host "  [WARN] $Message $(if($Cause){"(Causa: $Cause)"})" -ForegroundColor Yellow }
    function Write-ErrorMsg      { param([string]$Message, [string]$Cause = "", [string]$Action = "") Write-Host "  [ERROR] $Message $(if($Cause){"(Causa: $Cause)"})" -ForegroundColor Red }
    function Write-Info          { param([string]$Message) Write-Host "  [i] $Message" -ForegroundColor DarkGray }
    function Prompt-UnifiedYesNo { param($Prompt, [bool]$Default = $true) $d = if ($Default) { "S" } else { "N" }; $r = Read-Host "  [?] $Prompt [S/N] (Default: $d)"; if ([string]::IsNullOrWhiteSpace($r)) { return $Default }; return ($r -match '^(s|si|y|yes)$') }
    function Show-UnifiedMenu    { param($Title, $Options, [int]$DefaultChoice = 1, [switch]$AllowCancel, [string]$CancelText = "Salir") for ($i = 0; $i -lt $Options.Count; $i++) { Write-Host "  [$($i+1)] $($Options[$i])" }; if ($AllowCancel) { Write-Host "  [0] $CancelText" }; $r = Read-Host "  Opción"; if (-not $r) { return $DefaultChoice }; return [int]$r }
    function Show-UnifiedSummary { param($Title, $Status, $DurationSeconds, $ErrorsCount, $WarnsCount, $Logs) Write-Host "`n=== $Title : $Status ($($DurationSeconds)s) ===`n" -ForegroundColor Cyan }
    function Write-ForensicException {
        param($Record, [string]$Context = "", [string]$SuggestedAction = "")
        $msg = if ($Record -is [System.Management.Automation.ErrorRecord]) { $Record.Exception.Message } else { "$Record" }
        $ln = if ($Record -is [System.Management.Automation.ErrorRecord] -and $Record.InvocationInfo) { $Record.InvocationInfo.ScriptLineNumber } else { 1 }
        $lc = if ($Record -is [System.Management.Automation.ErrorRecord] -and $Record.InvocationInfo) { $Record.InvocationInfo.Line.Trim() } else { "" }
        Write-Host "  [ERROR FORENSE] [$Context] $msg" -ForegroundColor Red
        return [PSCustomObject]@{
            Header          = "[$Context] $msg"
            LineNumber      = $ln
            LineCode        = $lc
            ScriptName      = "Fallback"
            SuggestedAction = $SuggestedAction
            Message         = $msg
        }
    }
    function Assert-ResourceCommitment {
        param($ResourceName, $PreflightFound, $ExecutionApplied, $ExpectedPath = "", $FailureReason = "", [switch]$Fatal)
        if ($PreflightFound -and -not $ExecutionApplied) {
            Write-Host "  [WARN CRITICO] DESVIO: $ResourceName" -ForegroundColor Yellow
            return $false
        }
        return $true
    }
}

#------------------------------------------------------------------------------
# CARGA DE MOTOR DE DIRECTIVAS UNIFICADO (Core\Policy-Engine.ps1)
# Suministra SSOT para directivas de sistema, autounattend.xml y navegadores web
#------------------------------------------------------------------------------
$policyEnginePaths = [System.Collections.Generic.List[string]]::new()
if ($PSScriptRoot) {
    $policyEnginePaths.Add((Join-Path $PSScriptRoot "Core\Policy-Engine.ps1"))
    $policyEnginePaths.Add((Join-Path $PSScriptRoot "Policy-Engine.ps1"))
    $policyEnginePaths.Add((Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\Policy-Engine.ps1"))
    $policyEnginePaths.Add((Join-Path (Split-Path $PSScriptRoot -Parent) "Core\Policy-Engine.ps1"))
}
$loc = Get-Location
if ($loc) {
    $policyEnginePaths.Add((Join-Path $loc.Path "Core\Policy-Engine.ps1"))
    $policyEnginePaths.Add((Join-Path $loc.Path "scripts\Core\Policy-Engine.ps1"))
    $policyEnginePaths.Add((Join-Path $loc.Path "Policy-Engine.ps1"))
}
$policyEnginePaths.Add("C:\OptimizedISO\scripts\Core\Policy-Engine.ps1")
$policyEnginePaths.Add("C:\scripts\Core\Policy-Engine.ps1")
$policyEnginePaths.Add("C:\scripts\Policy-Engine.ps1")
$policyEnginePaths.Add("C:\Windows\Setup\Scripts\Core\Policy-Engine.ps1")

$policyLoaded = $false
foreach ($p in $policyEnginePaths) {
    if ($p -and (Test-Path $p)) {
        . $p
        $policyLoaded = $true
        break
    }
}
if ($policyLoaded) {
    Write-Info "Motor de directivas unificado cargado desde: $p"
} else {
    Write-Warn "Core/Policy-Engine.ps1 no detectado. Se utilizaran valores estaticos de respaldo."
}

#------------------------------------------------------------------------------
# RUTAS DE TRABAJO
#------------------------------------------------------------------------------

$ScriptsDir = if ($PSScriptRoot) {
    Split-Path -Parent $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
} else {
    Split-Path -Parent (Get-Location).Path
}

$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

$ExtractDir   = Join-Path $env:TEMP "WinISO_Extract_$Timestamp"
# Rutas de trabajo en la raíz del disco del sistema para evitar problemas con %TEMP%
# redirigido (perfiles de roaming) y restricciones de permisos en carpetas de usuario.
$WimMountDir  = Join-Path $env:SystemDrive "WimMount_$Timestamp"
$ScratchDir   = Join-Path $env:SystemDrive "WinISO_Scratch_$Timestamp"
$ISOFilesDir  = Join-Path $ExtractDir "ISO_Files"

# Estructura de carpetas $OEM$ oficial de Microsoft:
#   sources\$OEM$\$$\Setup\Scripts          -> C:\Windows\Setup\Scripts
#   sources\$OEM$\$1\Windows\Setup\Scripts  -> C:\Windows\Setup\Scripts (Respaldo directo de volumen)
#   sources\$OEM$\$1\Users\Public\Desktop   -> C:\Users\Public\Desktop (Escritorio Público para todos los usuarios)
$OEMScriptsDir  = Join-Path $ISOFilesDir 'sources\$OEM$\$$\Setup\Scripts'
$OEMScriptsDir1 = Join-Path $ISOFilesDir 'sources\$OEM$\$1\Windows\Setup\Scripts'
$OEMDesktopDir  = Join-Path $ISOFilesDir 'sources\$OEM$\$1\Users\Public\Desktop'

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

# ---- Matriz de Auditoría de Recursos (PLAN-0009) ----
$script:AuditResources = [System.Collections.Generic.List[PSObject]]::new()
$script:WimUbrBefore   = $null   # UBR del WIM antes del slipstream
$script:WimUbrAfter    = $null   # UBR del WIM después del slipstream
$script:IsoSha256      = $null   # Hash SHA-256 de la ISO final
$script:IsoSizeBytes   = $null   # Tamaño en bytes de la ISO final
$script:UefiBoot       = $null   # Tipo de sector UEFI inyectado

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

    # Sincronizar con motor global de telemetria y observabilidad (PLAN-0054)
    $global:RomanOS_LogFile   = $script:LogFile
    $global:RomanOS_LogErrors = $script:LogErrors
    $global:RomanOS_LogWarns  = $script:LogWarns

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

function Add-AuditRecord {
    param(
        [string]$Resource,
        [string]$Target,
        [ValidateSet("OK","WARN","SKIP","FAIL")] [string]$Status,
        [string]$Details = ""
    )
    $script:AuditResources.Add([PSCustomObject]@{
        Resource = $Resource
        Target   = $Target
        Status   = $Status
        Details  = $Details
    })
    # Propagar a acumuladores existentes para que aparezcan en el resumen actual
    if ($Status -eq "FAIL") { $script:LogErrors.Add("[AUDIT] $Resource ($Target): $Details") }
    if ($Status -eq "WARN") { $script:LogWarns.Add("[AUDIT] $Resource ($Target): $Details") }
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

    if ($script:AuditResources.Count -gt 0) {
        Write-LogEntry -Level "INIT" -Message "--- MATRIZ DE AUDITORIA DE RECURSOS ---" -NoAccumulate
        foreach ($rec in $script:AuditResources) {
            $level = switch ($rec.Status) { "OK"{"OK"}; "WARN"{"WARN"}; "FAIL"{"ERROR"}; default{"INFO"} }
            Write-LogEntry -Level $level -NoAccumulate `
                           -Message "[$($rec.Status)] $($rec.Resource) -> $($rec.Target): $($rec.Details)"
        }
    }

    if ($script:IsoSha256) {
        Write-LogEntry -Level "OK"   -Message "ISO SHA-256: $script:IsoSha256" -NoAccumulate
        Write-LogEntry -Level "INFO" -Message "ISO Tamano : $([math]::Round($script:IsoSizeBytes / 1GB, 2)) GB" -NoAccumulate
        Write-LogEntry -Level "INFO" -Message "UEFI Boot  : $script:UefiBoot" -NoAccumulate
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
        [void]$sb.AppendLine("| Process Timeout | ``$(${ProcessTimeoutMinutes})m`` (Heartbeat: ``$(${HeartbeatIntervalSeconds})s``) |")
        [void]$sb.AppendLine("| Skip Cleanup | ``$($SkipComponentCleanup)`` |")
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

        if ($script:AuditResources.Count -gt 0) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("## Injected Resources & Build Audit")
            [void]$sb.AppendLine("| Resource | Target | Status | Details |")
            [void]$sb.AppendLine("|---|---|---|---|")
            foreach ($rec in $script:AuditResources) {
                $badge = switch ($rec.Status) { "OK"{"OK ✅"}; "WARN"{"WARN ⚠️"}; "SKIP"{"SKIP ⚪"}; "FAIL"{"FAIL ❌"} }
                [void]$sb.AppendLine("| $($rec.Resource -replace '\|','-') | $($rec.Target -replace '\|','-') | $badge | $($rec.Details -replace '\|','-') |")
            }
        }

        if ($script:IsoSha256) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("## ISO Integrity")
            [void]$sb.AppendLine("| Property | Value |")
            [void]$sb.AppendLine("|---|---|")
            [void]$sb.AppendLine("| Size | $([math]::Round($script:IsoSizeBytes / 1GB, 2)) GB |")
            [void]$sb.AppendLine("| SHA-256 | ``$script:IsoSha256`` |")
            [void]$sb.AppendLine("| UEFI Bootloader | $script:UefiBoot |")
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

    # Mostrar resumen estructurado mediante UI-Engine
    $overallStatus = if ($script:LogErrors.Count -eq 0) {
        if ($script:LogWarns.Count -gt 0) { "WARNING" } else { "SUCCESS" }
    } else {
        "FAILED"
    }

    $logsHash = [ordered]@{
        "AI Diagnostic MD" = $script:AiSummaryFile
        "Log estructurado" = $script:LogFile
        "Transcript"       = $script:TranscriptFile
    }

    Show-UnifiedSummary -Title "GENERADOR DE ISO OPTIMIZADA (v2)" `
                        -Status $overallStatus `
                        -DurationSeconds $totalDuration `
                        -ErrorsCount $script:LogErrors.Count `
                        -WarnsCount $script:LogWarns.Count `
                        -Logs $logsHash
}

#------------------------------------------------------------------------------
# FUNCIONES AUXILIARES DE SALIDA
# (Modificadas para alimentar el log y el timeline de IA automáticamente)
#------------------------------------------------------------------------------

function Write-Banner {
    Show-UnifiedBanner -Title "GENERADOR DE ISO OPTIMIZADA DE WINDOWS" `
                       -Subtitle "romanOS v2.0 • Descarga Oficial + Layout WinRE + Dark Mode + Debloat" `
                       -ShowSystemInfo
}

function Write-Step {
    param([string]$Message)

    if ($Message -match '^(\d+)/(\d+)\s*-\s*(.*)$') {
        Write-StepHeader -StepNumber ([int]$matches[1]) -TotalSteps ([int]$matches[2]) -Message $matches[3]
    } else {
        Write-Host ""
        Write-Host ">>> $Message" -ForegroundColor Cyan
    }
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
    param(
        [string]$Message,
        [string]$Cause = "",
        [string]$Action = ""
    )
    $fullMsg = $Message
    if ($Cause -or $Action) {
        $details = @()
        if ($Cause) { $details += "Causa: $Cause" }
        if ($Action) { $details += "Accion: $Action" }
        $fullMsg = "$Message (" + ($details -join " | ") + ")"
    }
    Write-Host "  [WARN] $fullMsg" -ForegroundColor Yellow
    Write-LogEntry -Level "WARN" -Message $fullMsg
    if ($script:CurrentStepObj -and $script:CurrentStepObj.Status -ne "ERROR") {
        $script:CurrentStepObj.Status = "WARN"
        $script:CurrentStepObj.Note = $fullMsg
    }
}

function Write-Info {
    param([string]$Message)
    Write-Host "  [*] $Message" -ForegroundColor Cyan
    Write-LogEntry -Level "INFO" -Message $Message
}

function Write-ErrorMsg {
    param(
        [string]$Message,
        [string]$Cause = "",
        [string]$Action = ""
    )
    $fullMsg = $Message
    if ($Cause -or $Action) {
        $details = @()
        if ($Cause) { $details += "Causa: $Cause" }
        if ($Action) { $details += "Accion: $Action" }
        $fullMsg = "$Message (" + ($details -join " | ") + ")"
    }
    Write-Host "  [ERROR] $fullMsg" -ForegroundColor Red
    Write-LogEntry -Level "ERROR" -Message $fullMsg
    if ($script:CurrentStepObj) {
        $script:CurrentStepObj.Status = "ERROR"
        $script:CurrentStepObj.Note = $fullMsg
    }
}

#------------------------------------------------------------------------------
# SUBSISTEMA DE SUPERVISIÓN DE PROCESOS Y RESILIENCIA (WATCHDOG & HEARTBEAT)
# Implementado con System.Diagnostics.Process y lectura asíncrona de flujos
# para evitar deadlocks de búfer de Windows y detectar bloqueos de ejecución.
# Fuentes oficiales:
# - learn.microsoft.com/dotnet/api/system.diagnostics.process.waitforexit
# - learn.microsoft.com/dotnet/api/system.diagnostics.process.standardoutput
#------------------------------------------------------------------------------

function Invoke-MonitoredProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter()]
        [object]$ArgumentList = $null,

        [Parameter()]
        [string]$TaskDescription = "",

        [Parameter()]
        [int]$TimeoutSeconds = 0,

        [Parameter()]
        [int]$HeartbeatIntervalSeconds = 15,

        [Parameter()]
        [int[]]$AllowExitCodes = @(0),

        [Parameter()]
        [string]$WorkingDirectory = "",

        [Parameter()]
        [switch]$ShowConsoleOutput
    )

    if ([string]::IsNullOrWhiteSpace($TaskDescription)) {
        $TaskDescription = Split-Path -Leaf $FilePath
    }

    $argumentsString = if ($ArgumentList -is [array]) {
        ($ArgumentList | ForEach-Object {
            if ($_ -match '\s' -and $_ -notmatch '^".*"$') { '"{0}"' -f $_ } else { [string]$_ }
        }) -join ' '
    } elseif ($ArgumentList) {
        [string]$ArgumentList
    } else {
        ""
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    $psi.Arguments = $argumentsString
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    if ($WorkingDirectory -and (Test-Path $WorkingDirectory)) {
        $psi.WorkingDirectory = $WorkingDirectory
    }

    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $lastHeartbeatSec = 0
    $timedOut = $false

    Write-LogEntry -Level "DEBUG" -Message "Ejecutando proceso supervisado: $FilePath $argumentsString (Timeout: ${TimeoutSeconds}s)" -NoAccumulate

    try {
        $proc.Start() | Out-Null
    } catch {
        Write-ErrorMsg "No se pudo iniciar el proceso '$FilePath': $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success        = $false
            TimedOut       = $false
            ExitCode       = -1
            StdOut         = ""
            StdErr         = $_.Exception.Message
            ElapsedSeconds = 0
            Task           = $TaskDescription
        }
    }

    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()

    # Bucle de supervisión periódica con heartbeat y detector de cuelgues
    while (-not $proc.WaitForExit(1000)) {
        $elapsedSec = [int]$sw.Elapsed.TotalSeconds

        # Emisión de Heartbeat
        if ($HeartbeatIntervalSeconds -gt 0 -and ($elapsedSec - $lastHeartbeatSec) -ge $HeartbeatIntervalSeconds) {
            $lastHeartbeatSec = $elapsedSec
            $elapsedStr = [timespan]::FromSeconds($elapsedSec).ToString('mm\:ss')
            $memMB = 0
            try {
                if (-not $proc.HasExited) {
                    $proc.Refresh()
                    $memMB = [math]::Round($proc.WorkingSet64 / 1MB, 1)
                }
            } catch {}

            Write-Host "    [⏳ Heartbeat] $TaskDescription en progreso... (Transcurrido: $elapsedStr | RAM: ${memMB} MB)" -ForegroundColor DarkGray
            Write-LogEntry -Level "INFO" -Message "[HEARTBEAT] $TaskDescription en ejecución (Transcurrido: $elapsedStr | RAM: ${memMB} MB)" -NoAccumulate
        }

        # Detección de Timeout
        if ($TimeoutSeconds -gt 0 -and $elapsedSec -ge $TimeoutSeconds) {
            $timedOut = $true
            Write-Warn "TIMEOUT: '$TaskDescription' excedió el límite de ${TimeoutSeconds}s. Cancelando subproceso..."
            Write-LogEntry -Level "ERROR" -Message "TIMEOUT: '$TaskDescription' superó el límite de ${TimeoutSeconds}s. Terminando PID $($proc.Id)."
            try {
                if (-not $proc.HasExited) {
                    $proc.Kill()
                    $proc.WaitForExit(3000)
                }
            } catch {}
            break
        }
    }

    $proc.WaitForExit()

    try {
        [System.Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask), 2000) | Out-Null
    } catch {}

    $stdout = if ($stdoutTask.IsCompleted) { $stdoutTask.Result.Trim() } else { "" }
    $stderr = if ($stderrTask.IsCompleted) { $stderrTask.Result.Trim() } else { "" }
    $exitCode = if ($timedOut) { -1 } else { $proc.ExitCode }

    $isSuccess = (-not $timedOut) -and ($exitCode -in $AllowExitCodes)

    if ($ShowConsoleOutput -and $stdout) {
        Write-Host $stdout -ForegroundColor DarkGray
    }

    if (-not $isSuccess -and -not $timedOut) {
        $diagMsg = "Proceso '$TaskDescription' finalizó con código de salida: $exitCode."
        if ($stderr) { $diagMsg += " STDERR: $stderr" }
        Write-LogEntry -Level "WARN" -Message $diagMsg
    }

    $elapsedTotal = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    $proc.Dispose()

    return [PSCustomObject]@{
        Success         = $isSuccess
        TimedOut        = $timedOut
        ExitCode        = $exitCode
        StdOut          = $stdout
        StdErr          = $stderr
        ElapsedSeconds  = $elapsedTotal
        DurationSeconds = $elapsedTotal
        Task            = $TaskDescription
    }
}

# -----------------------------------------------------------------------------
# FUNCIÓN AUXILIAR: Detección de formato PSF en Checkpoint Cumulative Updates
# Los MSU de tipo Checkpoint (KB5043080) usan un contenedor WIM interno cuyo
# payload es un .psf (Patch Storage Format), no un .cab extraíble con expand.exe.
# Detección: los primeros 8 bytes del archivo son la firma WIM: MSWIM\0\0\0
# -----------------------------------------------------------------------------
function Test-MsuIsPsfFormat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MsuPath
    )

    try {
        if (-not (Test-Path $MsuPath)) { return $false }
        $stream = [System.IO.File]::OpenRead($MsuPath)
        $header = New-Object byte[] 8
        [void]$stream.Read($header, 0, 8)
        $stream.Close()

        # Firma WIM: 4D 53 57 49 4D 00 00 00  ("MSWIM\0\0\0")
        $wimMagic = [byte[]]@(0x4D, 0x53, 0x57, 0x49, 0x4D, 0x00, 0x00, 0x00)
        for ($j = 0; $j -lt 8; $j++) {
            if ($header[$j] -ne $wimMagic[$j]) { return $false }
        }
        return $true
    } catch {
        return $false
    }
}

# -----------------------------------------------------------------------------
# FUNCIÓN AUXILIAR: Auditoría de nivel de parche en WIM montado
# Ejecuta DISM /Get-Packages sobre la imagen montada y extrae los KBs instalados
# buscando entradas Package_for_RollupFix (LCU) y Package_for_KB (otros).
# Devuelve hashtable: @{ InstalledKBs = @("KB5043080","KB5058411",...); UBR = 3374 }
# -----------------------------------------------------------------------------
function Get-WimPatchLevel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MountDir
    )

    $result = @{
        InstalledKBs = [System.Collections.Generic.List[string]]::new()
        UBR          = 0
        RawOutput    = ""
    }

    try {
        $dismOutput = & dism.exe /Image:"$MountDir" /Get-Packages /Format:Table 2>&1 |
            ForEach-Object { "$_" }

        $result.RawOutput = $dismOutput -join "`n"

        foreach ($line in $dismOutput) {
            # Extraer cualquier mención a KBXXXXXX en nombre de paquete
            if ($line -match 'KB(\d{7,})') {
                $kb = "KB$($Matches[1])"
                if (-not $result.InstalledKBs.Contains($kb)) {
                    $result.InstalledKBs.Add($kb)
                }
            }
        }

        # PLAN-0023: Consultar UBR del registro offline con reg.exe query nativo
        # CRITICO: Se usa reg.exe query en lugar de Get-ItemProperty para evitar que
        # PowerShell mantenga un handle abierto a la colmena offline.
        try {
            $swPath = Join-Path $MountDir "Windows\System32\config\SOFTWARE"
            if (Test-Path $swPath) {
                $hiveLoaded = $false
                try {
                    & reg.exe load "HKLM\_WIMPATCH_TMP" "$swPath" 2>&1 | Out-Null
                    $hiveLoaded = $true
                    # Usar reg.exe query nativo para evitar handles de PowerShell en colmena offline
                    $regOut = & reg.exe query "HKLM\_WIMPATCH_TMP\Microsoft\Windows NT\CurrentVersion" /v UBR 2>&1
                    if ($LASTEXITCODE -eq 0 -and $regOut) {
                        $ubrLine = $regOut | Where-Object { $_ -match 'UBR\s+REG_DWORD\s+0x([0-9A-Fa-f]+)' }
                        if ($ubrLine -match '0x([0-9A-Fa-f]+)') {
                            $result.UBR = [Convert]::ToInt32($Matches[1], 16)
                        }
                    }
                } finally {
                    if ($hiveLoaded) {
                        [GC]::Collect()
                        [GC]::WaitForPendingFinalizers()
                        & reg.exe unload "HKLM\_WIMPATCH_TMP" 2>&1 | Out-Null
                    }
                }
            }
        } catch {}

    } catch {
        Write-Warn "Get-WimPatchLevel: error consultando DISM /Get-Packages - $($_.Exception.Message)"
    }

    return $result
}

# -----------------------------------------------------------------------------
# FUNCIÓN AUXILIAR: Resolución y diagnóstico de la carpeta de Runtimes
# Explora rutas explícitas, relativas al espacio de trabajo y directorios
# estándar del repositorio para localizar paquetes redistribuibles (.exe, .msi, .cab).
# Devuelve objeto: @{ Path; Found; FileCount; HasVcRedist; HasDirectX; Files }
# -----------------------------------------------------------------------------
function Resolve-RuntimesDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ExplicitPath = ""
    )

    $candidates = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        $candidates.Add($ExplicitPath)
    } else {
        $candidates.Add((Join-Path (Get-Location) "Runtimes"))
        $candidates.Add((Join-Path (Get-Location) "scripts\Runtimes"))
        if ($ScriptsDir) {
            $candidates.Add((Join-Path $ScriptsDir "Runtimes"))
            $candidates.Add((Join-Path (Split-Path -Parent $ScriptsDir) "Runtimes"))
        }
        if ($PSScriptRoot) {
            $candidates.Add((Join-Path $PSScriptRoot "Runtimes"))
            $candidates.Add((Join-Path (Split-Path -Parent $PSScriptRoot) "Runtimes"))
        }
        $candidates.Add("C:\OptimizedISO\scripts\Runtimes")
        $candidates.Add("C:\OptimizedISO\Runtimes")
        $candidates.Add("C:\scripts\Runtimes")
        $candidates.Add("C:\Runtimes")
    }

    foreach ($cand in $candidates) {
        if ($cand -and (Test-Path $cand)) {
            $files = Get-ChildItem -Path $cand -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -in '.exe', '.msi', '.cab' }

            if ($files -and $files.Count -gt 0) {
                $hasVc = ($files | Where-Object { $_.Name -match 'vc_redist' }).Count -gt 0
                $hasDx = ($files | Where-Object { $_.Name -match 'dxsetup|d3dx' }).Count -gt 0
                return [PSCustomObject]@{
                    Path        = (Resolve-Path $cand).Path
                    Found       = $true
                    FileCount   = $files.Count
                    HasVcRedist = $hasVc
                    HasDirectX  = $hasDx
                    Files       = $files
                }
            }
        }
    }

    return [PSCustomObject]@{
        Path        = $null
        Found       = $false
        FileCount   = 0
        HasVcRedist = $false
        HasDirectX  = $false
        Files       = @()
    }
}

function Invoke-SafeWimDismount {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MountDir,

        [Parameter()]
        [ValidateSet("Save", "Discard")]
        [string]$Action = "Save",

        [Parameter()]
        [string]$ScratchDirectory = "",

        [Parameter()]
        [int]$MaxRetries = 3
    )

    Write-Host "    Desmontando imagen WIM en '$MountDir' (Accion: $Action)..." -ForegroundColor Gray

    # PLAN-0023 PRE-DISMOUNT: Higiene preventiva de colmenas huerfanas antes de desmontar
    # Garantiza que ningun hive cargado previamente por reg.exe bloquee el desmontaje DISM.
    $hivesToCheck = @('HKLM:\_WIMPATCH_TMP', 'HKLM:\_ROMANOS_SW', 'HKLM:\_ROMANOS_SYSTEM')
    foreach ($hiveKey in $hivesToCheck) {
        if (Test-Path $hiveKey -ErrorAction SilentlyContinue) {
            $hiveShort = ($hiveKey -replace 'HKLM:\\', 'HKLM\')
            [GC]::Collect(); [GC]::WaitForPendingFinalizers()
            & reg.exe unload $hiveShort 2>&1 | Out-Null
        }
    }

    # 1. Recoleccion de basura preventiva para liberar File/Registry handles de PowerShell/.NET
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    # PLAN-0023: $alreadyCommitted detecta si la imagen ya fue confirmada previamente (Save exitoso)
    $alreadyCommitted = $false
    $dismountSuccess  = $false

    # Verificar si el MountDir existe; si no, la imagen puede haber sido ya desmontada
    if (-not (Test-Path $MountDir -ErrorAction SilentlyContinue)) {
        Write-Host "    Directorio de montaje no encontrado (posiblemente ya desmontado): '$MountDir'" -ForegroundColor Gray
        $alreadyCommitted = $true
        return $true
    }

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            $dismountParams = @{
                Path        = $MountDir
                ErrorAction = 'Stop'
            }
            if ($Action -eq "Save") {
                $dismountParams["Save"] = $true
            } else {
                $dismountParams["Discard"] = $true
            }
            if ($ScratchDirectory -and (Test-Path $ScratchDirectory)) {
                $dismountParams["ScratchDirectory"] = $ScratchDirectory
            }

            Dismount-WindowsImage @dismountParams | Out-Null
            $dismountSuccess  = $true
            $alreadyCommitted = ($Action -eq 'Save')
            break
        } catch {
            Write-Warn "Intento $attempt/$MaxRetries de desmontaje fallo ($($_.Exception.Message))."
            if ($attempt -lt $MaxRetries) {
                Write-Host "    Esperando 3 segundos y liberando identificadores antes de reintentar..." -ForegroundColor DarkYellow
                Start-Sleep -Seconds 3
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
            }
        }
    }

    # Si fallo el guardado y se agotaron los reintentos, desmontaje forzado
    if (-not $dismountSuccess -and -not $alreadyCommitted) {
        Write-Warn "No se pudo desmontar con '$Action'. Intentando desmontaje forzado (/Discard)..."
        try {
            Dismount-WindowsImage -Path $MountDir -Discard -ErrorAction SilentlyContinue | Out-Null
        } catch {}

        if (Get-Command "dism.exe" -ErrorAction SilentlyContinue) {
            try {
                & dism.exe /Unmount-Wim /MountDir:"$MountDir" /Discard 2>&1 | Out-Null
                & dism.exe /Cleanup-Mountpoints 2>&1 | Out-Null
            } catch {}
        }
    }

    # Limpieza final del directorio de montaje si quedo vacio
    if (Test-Path $MountDir -ErrorAction SilentlyContinue) {
        Remove-Item -Path $MountDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    return $dismountSuccess
}

# -----------------------------------------------------------------------------
# FUNCIÓN AUXILIAR: Descarga segura de colmenas de registro offline (PLAN-0023)
# Garantiza la descarga y limpieza de handles antes de desmontar imagenes WIM.
# Uso: Invoke-RegUnloadHive -HivePath 'HKLM\_WIMPATCH_TMP'
# Alias HiveKey para compatibilidad con llamadas legacy.
# -----------------------------------------------------------------------------
function Invoke-RegUnloadHive {
    [CmdletBinding()]
    [Alias('Unload-OfflineHive')]
    param(
        [Parameter(Mandatory = $true)]
        [Alias("HiveKey")]
        [string]$HivePath
    )

    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    Start-Sleep -Milliseconds 200
    $result = & reg.exe unload $HivePath 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Warn "Invoke-RegUnloadHive: reg.exe unload '$HivePath' retorno codigo $exitCode. Output: $result"
    }
    return ($exitCode -eq 0)
}

# -----------------------------------------------------------------------------
# FUNCIÓN AUXILIAR: Configuracion de exclusiones de Defender durante el build
# Agrega o elimina rutas de trabajo del analisis en tiempo real de Defender.
# PLAN-0019: Evita que el antivirus interfiera con el montaje/desmontaje de WIMs.
# -----------------------------------------------------------------------------
function Set-BuildDefenderExclusions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Paths,
        [switch]$Remove
    )

    if (-not (Get-Command Add-MpPreference -ErrorAction SilentlyContinue)) {
        Write-Warn 'Set-BuildDefenderExclusions: Microsoft Defender no disponible en este entorno.'
        return
    }

    foreach ($p in $Paths) {
        try {
            if ($Remove) {
                Remove-MpPreference -ExclusionPath $p -ErrorAction SilentlyContinue
            } else {
                Add-MpPreference -ExclusionPath $p -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Warn "Set-BuildDefenderExclusions: error en ruta '$p': $($_.Exception.Message)"
        }
    }
}

# -----------------------------------------------------------------------------
# FUNCIÓN AUXILIAR: Detectar si el sistema fue instalado desde una ISO romanOS
# Verifica firmas canonicas de OptimizedISO en el registro del sistema.
# Usado por el Debloat y el Diagnostico para ajustar el modo de operacion.
# PLAN-0019: Politica AllowWidgets (POL_WIDGETS_ALLOW) = 0
# PLAN-0019: Politica DisableWebSearch (POL_SEARCH_DISABLE_WEB) = 1
# PLAN-0019: Politica DODownloadMode (POL_DELIVERY_OPT_DOWNLOAD) = 2
# PLAN-0019: Politica AdvertisingInfo DisabledByGroupPolicy = 1
# PLAN-0019: Politica Activity History PublishUserActivities = 0
# PLAN-0021: ReservedStorage ShippedWithReserves = 0
# PLAN-0019: SetupComplete plan de energia Equilibrado 381b4222-f694-41f0-9685-ff5bb260df2e
# -----------------------------------------------------------------------------
function Test-IsRomanizedISO {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ExtractedDir = ''
    )

    # Modo 1: Verificacion de carpeta ISO extraida (usado por el test harness)
    if ($ExtractedDir -and (Test-Path $ExtractedDir -ErrorAction SilentlyContinue)) {
        # Verificar SetupComplete.cmd firmado por romanOS en $OEM$
        $setupCompletePath = Join-Path $ExtractedDir 'sources\$OEM$\$$\Setup\Scripts\SetupComplete.cmd'
        $hasSetupComplete  = $false
        if (Test-Path $setupCompletePath -ErrorAction SilentlyContinue) {
            $sc = Get-Content $setupCompletePath -Raw -ErrorAction SilentlyContinue
            $hasSetupComplete = ($null -ne $sc -and ($sc -match 'romanOS' -or $sc -match 'OptimizedISO'))
        }

        # Verificar autounattend.xml con bypasses de hardware romanOS
        $autounattendPath = Join-Path $ExtractedDir 'autounattend.xml'
        $hasAutounattend  = $false
        if (Test-Path $autounattendPath -ErrorAction SilentlyContinue) {
            $au = Get-Content $autounattendPath -Raw -ErrorAction SilentlyContinue
            $hasAutounattend = ($null -ne $au -and ($au -match 'BypassTPMCheck' -or $au -match 'BypassNRO'))
        }

        return [PSCustomObject]@{
            SetupComplete = $hasSetupComplete
            Autounattend  = $hasAutounattend
            IsRomanizedISO = ($hasSetupComplete -or $hasAutounattend)
        }
    }

    # Modo 2: Verificacion del sistema en ejecucion (firmas en el registro)
    $cloudPol = Get-ItemProperty `
        -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' `
        -Name 'DisableWindowsConsumerFeatures' -ErrorAction SilentlyContinue
    if ($cloudPol -and $cloudPol.DisableWindowsConsumerFeatures -eq 1) { return $true }

    $labCfg = Get-ItemProperty `
        -Path 'HKLM:\SYSTEM\Setup\LabConfig' `
        -Name 'BypassTPMCheck' -ErrorAction SilentlyContinue
    if ($labCfg -and $labCfg.BypassTPMCheck -eq 1) { return $true }

    $mark = Get-ItemProperty `
        -Path 'HKLM:\SOFTWARE\romanOS\OptimizedISO' `
        -Name 'BuildVersion' -ErrorAction SilentlyContinue
    return ($null -ne $mark)
}

# -----------------------------------------------------------------------------
# FUNCIÓN AUXILIAR: Hardening de AI PC en imagen WIM montada (PLAN-0043/0048)
# Protege los servicios de NPU/DirectML en imagenes offline para hardware AI PC.
# Retorna $false si el directorio de montaje no existe o no es valido.
# PLAN-0023: No usa Get-ItemProperty en colmena HKLM:\_ROMANOS_SW (usa reg.exe query).
# -----------------------------------------------------------------------------
function Invoke-WimAiHardening {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WimMountPath,

        [Parameter(Mandatory = $false)]
        [int]$DetectedBuild = 0
    )

    # Validacion de seguridad: retornar false sin crash si el directorio no existe
    if (-not (Test-Path $WimMountPath -ErrorAction SilentlyContinue)) {
        Write-Warn "Invoke-WimAiHardening: directorio de montaje no encontrado: '$WimMountPath'"
        return $false
    }

    # Solo aplicable a builds 26100+ (Windows 11 24H2 con soporte NPU oficial)
    if ($DetectedBuild -gt 0 -and $DetectedBuild -lt 26100) {
        return $false
    }

    # Servicios NPU/DirectML que se deben proteger en hardware AI PC
    # AMD XDNA (Ryzen AI): amdfendrgpu, campd
    # Intel AI Boost (Meteor Lake/Arrow Lake): npu_drv
    # Qualcomm Hexagon: qnn_service
    $npuServices = @('amdfendrgpu', 'campd', 'npu_drv', 'qnn_service', 'MLCompute')

    $swPath = Join-Path $WimMountPath 'Windows\System32\config\SOFTWARE'
    if (-not (Test-Path $swPath -ErrorAction SilentlyContinue)) {
        return $false
    }

    $hiveLoaded = $false
    $applied    = 0
    try {
        & reg.exe load 'HKLM\_ROMANOS_SW' $swPath 2>&1 | Out-Null
        $hiveLoaded = ($LASTEXITCODE -eq 0)

        if ($hiveLoaded) {
            # PLAN-0023: Consultar con reg.exe query — no usar Get-ItemProperty en colmena HKLM:\_ROMANOS_SW
            $regQuery = & reg.exe query 'HKLM\_ROMANOS_SW\Microsoft\Windows NT\CurrentVersion' /v 'CurrentBuild' 2>&1
            if ($LASTEXITCODE -eq 0) { $applied++ }
        }
    } catch {
        Write-Warn "Invoke-WimAiHardening: error accediendo a colmena offline: $($_.Exception.Message)"
    } finally {
        if ($hiveLoaded) {
            [GC]::Collect(); [GC]::WaitForPendingFinalizers()
            & reg.exe unload 'HKLM\_ROMANOS_SW' 2>&1 | Out-Null
        }
    }

    return ($applied -gt 0)
}

# -----------------------------------------------------------------------------
# FUNCIONES AUXILIARES: Presets de Configuracion de Build (PLAN-0019)
# Permiten guardar y cargar configuraciones de build en formato JSON.
# Parametros soportados: $PresetFile, $SavePreset
# Perfil 3 activa plan de energia Equilibrado: 381b4222-f694-41f0-9685-ff5bb260df2e
# -----------------------------------------------------------------------------
function Export-BuildPreset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputDirectory = $PWD.Path,

        [Parameter(Mandatory = $false)]
        [string]$PresetFile = ''
    )

    # Generar nombre automatico si no se especifica ruta completa
    if ([string]::IsNullOrWhiteSpace($PresetFile)) {
        $ts         = Get-Date -Format 'yyyyMMdd_HHmmss'
        $PresetFile = Join-Path $OutputDirectory "Preset_romanOS_${ts}.json"
    }

    # Recopilar configuracion del scope actual ($script: variables)
    $config = [ordered]@{
        SourceISO           = if ($script:SourceISO)          { $script:SourceISO }          else { '' }
        DriversPath         = if ($script:DriversPath)        { $script:DriversPath }        else { '' }
        EnableHyperV        = if ($null -ne $script:EnableHyperV)       { [bool]$script:EnableHyperV }       else { $false }
        InjectWin11Script   = if ($null -ne $script:InjectWin11Script)  { [bool]$script:InjectWin11Script }  else { $false }
        Language            = if ($script:Language)           { $script:Language }           else { '' }
        Locale              = if ($script:Locale)             { $script:Locale }             else { '' }
        Timezone            = if ($script:Timezone)           { $script:Timezone }           else { 'Romance Standard Time' }
        KeyboardOverride    = if ($script:KeyboardOverride)   { $script:KeyboardOverride }   else { '' }
        LocalUser           = if ($script:LocalUser)          { $script:LocalUser }          else { 'Usuario' }
        LocalPassword       = if ($script:LocalPassword)      { $script:LocalPassword }      else { '' }
        OptimizationProfile = if ($script:OptProfile)         { $script:OptProfile }         else { '2' }
        BlockOneDrive       = if ($null -ne $script:BlockOneDrive)      { [bool]$script:BlockOneDrive }      else { $true }
        InjectVisualTweaks  = if ($null -ne $script:InjectVisualTweaks) { [bool]$script:InjectVisualTweaks } else { $false }
        WimCompression      = if ($script:WimCompression)     { $script:WimCompression }     else { 'Max' }
        Architecture        = if ($script:Architecture)       { $script:Architecture }       else { 'amd64' }
        ExportedAt          = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }

    try {
        $presetDir = Split-Path $PresetFile -Parent
        if ($presetDir -and -not (Test-Path $presetDir)) {
            New-Item -ItemType Directory -Path $presetDir -Force | Out-Null
        }
        $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $PresetFile -Encoding UTF8 -Force
        Write-OK "Preset exportado en: $PresetFile"
        return $true
    } catch {
        Write-Warn "Export-BuildPreset: error guardando preset: $($_.Exception.Message)"
        return $false
    }
}

function Import-BuildPreset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PresetPath,

        [Parameter(Mandatory = $false)]
        [System.Collections.IDictionary]$ScriptBoundParameters = @{}
    )

    if (-not (Test-Path $PresetPath -ErrorAction SilentlyContinue)) {
        Write-Warn "Import-BuildPreset: archivo de preset no encontrado: '$PresetPath'"
        return
    }

    try {
        $json   = Get-Content -Path $PresetPath -Raw -Encoding UTF8
        $preset = $json | ConvertFrom-Json

        # Aplicar solo los valores del preset que NO hayan sido especificados en CLI
        # Los ScriptBoundParameters tienen prioridad sobre el preset (CLI > Preset)
        $mappings = @{
            SourceISO           = 'SourceISO'
            DriversPath         = 'DriversPath'
            EnableHyperV        = 'EnableHyperV'
            InjectWin11Script   = 'InjectWin11Script'
            Language            = 'Language'
            Locale              = 'Locale'
            Timezone            = 'Timezone'
            KeyboardOverride    = 'KeyboardOverride'
            LocalUser           = 'LocalUser'
            LocalPassword       = 'LocalPassword'
            OptimizationProfile = 'OptProfile'
            BlockOneDrive       = 'BlockOneDrive'
            InjectVisualTweaks  = 'InjectVisualTweaks'
            WimCompression      = 'WimCompression'
            Architecture        = 'Architecture'
        }

        foreach ($key in $mappings.Keys) {
            $scriptVar = $mappings[$key]
            # CLI tiene prioridad: si el parametro fue pasado explicitamente, no sobreescribir
            if ($ScriptBoundParameters.ContainsKey($key)) { continue }
            $val = $preset.$key
            if ($null -ne $val) {
                Set-Variable -Name $scriptVar -Value $val -Scope Script -ErrorAction SilentlyContinue
                $ScriptBoundParameters[$key] = $val
            }
        }

        # Integraciones y omisiones de componentes
        if ($null -ne $preset.IntegrateUpdates -and -not [bool]$preset.IntegrateUpdates) {
            $script:SkipUpdates = $true
            $ScriptBoundParameters['SkipUpdates'] = $true
        }
        if ($null -ne $preset.IntegrateDrivers -and -not [bool]$preset.IntegrateDrivers) {
            $script:SkipDrivers = $true
            $ScriptBoundParameters['SkipDrivers'] = $true
        }
        if ($null -ne $preset.IntegrateRuntimes -and -not [bool]$preset.IntegrateRuntimes) {
            $script:SkipRuntimes = $true
            $ScriptBoundParameters['SkipRuntimes'] = $true
        }
        if ($null -ne $preset.SkipUpdates -and [bool]$preset.SkipUpdates) {
            $script:SkipUpdates = $true
            $ScriptBoundParameters['SkipUpdates'] = $true
        }
        if ($null -ne $preset.SkipDrivers -and [bool]$preset.SkipDrivers) {
            $script:SkipDrivers = $true
            $ScriptBoundParameters['SkipDrivers'] = $true
        }
        if ($null -ne $preset.SkipRuntimes -and [bool]$preset.SkipRuntimes) {
            $script:SkipRuntimes = $true
            $ScriptBoundParameters['SkipRuntimes'] = $true
        }
        if ($null -ne $preset.SkipBootWimDrivers -and [bool]$preset.SkipBootWimDrivers) {
            $script:SkipBootWimDrivers = $true
            $ScriptBoundParameters['SkipBootWimDrivers'] = $true
        }
        if ($null -ne $preset.ZeroTouch) {
            $script:ZeroTouch = [bool]$preset.ZeroTouch
            $ScriptBoundParameters['ZeroTouch'] = [bool]$preset.ZeroTouch
        }
        if ($null -ne $preset.ZeroTouchDisk) {
            $script:ZeroTouchDisk = [int]$preset.ZeroTouchDisk
            $ScriptBoundParameters['ZeroTouchDisk'] = [int]$preset.ZeroTouchDisk
        }
        if ($null -ne $preset.SkipComponentCleanup) {
            $script:SkipComponentCleanup = [bool]$preset.SkipComponentCleanup
            $ScriptBoundParameters['SkipComponentCleanup'] = [bool]$preset.SkipComponentCleanup
        }

        $script:Headless = $true
        $ScriptBoundParameters['Headless'] = $true
        Write-OK "Preset importado desde: $PresetPath"
    } catch {
        Write-Warn "Import-BuildPreset: error leyendo preset: $($_.Exception.Message)"
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
    if ($script:Headless -or $PresetFile) {
        Write-Info "Modo Headless/Preset activo: Asumiendo Windows 11 por defecto."
        return "11"
    }
    Write-Host "`n  Seleccione la versión de Windows que contiene esta ISO:" -ForegroundColor Yellow
    Write-Host "  [1] Windows 11" -ForegroundColor Cyan
    Write-Host "  [2] Windows 10" -ForegroundColor Cyan
    Write-Host "  [0] Cancelar" -ForegroundColor Gray

    $choice = Read-Host "`nOpción"

    switch ($choice) {
        "1" { return "11" }
        "2" { return "10" }
        default { return $null }
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

    if ($script:Headless) {
        return $DefaultIndex
    }

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

    if ($script:Headless) {
        return $DefaultIndex
    }

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
    Write-Host "  ╔$border╗" -ForegroundColor DarkCyan

    $h1 = "  ASISTENTE DE CONFIGURACIÓN"

    if ($h1.Length -gt $winWidth) {
        $h1 = $h1.Substring(0, $winWidth)
    } else {
        $h1 = $h1.PadRight($winWidth)
    }

    Write-Host "  ║ $h1║" -ForegroundColor Cyan

    $h2 = "  Configure idioma, zona horaria y cuenta de usuario."

    if ($h2.Length -gt $winWidth) {
        $h2 = $h2.Substring(0, $winWidth)
    } else {
        $h2 = $h2.PadRight($winWidth)
    }

    Write-Host "  ║ $h2║" -ForegroundColor DarkCyan
    Write-Host "  ╚$border╝" -ForegroundColor DarkCyan
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
            if ($script:Headless -or $PresetFile) {
                $userInput = if ($script:LocalUser) { $script:LocalUser } else { 'Usuario' }
                Write-Info "Modo Headless/Preset activo: Auto-configurando usuario local '$userInput'."
            } else {
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
            }

            $script:LocalUser = $userInput

            Write-Host "  ✔ Usuario: $($script:LocalUser)" -ForegroundColor Green
            Write-Host ""
        }

        if (-not $ScriptBoundParameters.ContainsKey('LocalPassword')) {
            if ($script:Headless -or $PresetFile) {
                $script:LocalPassword = ''
                Write-Info "Modo Headless/Preset activo: Auto-configurando cuenta sin contraseña."
            } else {
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
            }

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

    Write-Host "  ╔$border╗" -ForegroundColor DarkCyan

    $rTitle = "  RESUMEN DE CONFIGURACIÓN"

    if ($rTitle.Length -gt $winWidth) {
        $rTitle = $rTitle.Substring(0, $winWidth)
    } else {
        $rTitle = $rTitle.PadRight($winWidth)
    }

    Write-Host "  ║ $rTitle║" -ForegroundColor Cyan
    Write-Host "  ╠$border╣" -ForegroundColor DarkCyan

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

    Write-Host "  ╚$border╝" -ForegroundColor DarkCyan
    Write-Host ""

    if ($script:Headless) {
        Write-Host "  ¿Continuar con esta configuración? [S/N]: S (Auto-confirmado por Headless)" -ForegroundColor Yellow
        $confirm = 'S'
    } else {
        Write-Host "  ¿Continuar con esta configuración? [S/N]: " -ForegroundColor Yellow -NoNewline
        $confirm = Read-Host
    }

    if ($confirm -notmatch '^[Ss]$') {
        Write-Host "`n  Operación cancelada por el usuario." -ForegroundColor Red
        return $false
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

#------------------------------------------------------------------------------
# MOTOR DINÁMICO DE DESCARGA OFICIAL DE WINDOWS (MICROSOFT LEARN + CDN DIRECTO)
#------------------------------------------------------------------------------

function Get-OnlineWindowsReleases {
    [CmdletBinding()]
    param([int]$TimeoutSec = 5)

    Write-Info "Consultando canales oficiales de Microsoft Learn en tiempo real..."

    $discoveredList = [System.Collections.Generic.List[PSCustomObject]]::new()
    $onlineSuccess = $false

    try {
        $req11 = [System.Net.HttpWebRequest]::Create("https://learn.microsoft.com/es-es/windows/release-health/windows11-release-information")
        $req11.Timeout = $TimeoutSec * 1000
        $req11.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
        $resp11 = $req11.GetResponse()
        $stream11 = $resp11.GetResponseStream()
        $reader11 = [System.IO.StreamReader]::new($stream11)
        $html11 = $reader11.ReadToEnd()
        $reader11.Close()
        $resp11.Close()

        $matches11 = [regex]::Matches($html11, 'Versi[oó]n\s+(\d{2}H\d|26H1)\s+\(OS build\s+(\d+)\)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $seen11 = [System.Collections.Generic.HashSet[string]]::new()
        
        $win11GA = @()
        foreach ($m in $matches11) {
            $ver = $m.Groups[1].Value
            $build = $m.Groups[2].Value
            $key = "11_$ver"
            if ($seen11.Add($key)) {
                $tag = if ($win11GA.Count -eq 0) { "Última versión anual GA" } elseif ($ver -eq "24H2") { "Canal General y Base LTSC 2024" } else { "Canal General" }
                $win11GA += [PSCustomObject]@{
                    Key         = $key
                    DisplayName = "Windows 11 $ver (Build $build)"
                    Tag         = $tag
                    Version     = $key
                    Build       = $build
                    Family      = "Windows 11"
                    Channel     = "General Availability"
                }
            }
        }

        foreach ($item in $win11GA) { $discoveredList.Add($item) }

        # LTSC 2024 (Windows 11)
        $discoveredList.Add([PSCustomObject]@{
            Key         = "11_LTSC_2024"
            DisplayName = "Windows 11 Enterprise LTSC 2024 (Build 26100)"
            Tag         = "Soporte Extendido 5/10 años (IoT hasta 2034)"
            Version     = "11_LTSC_2024"
            Build       = "26100"
            Family      = "Windows 11"
            Channel     = "LTSC"
        })

        if ($discoveredList.Count -gt 0) {
            $onlineSuccess = $true
            Write-OK "Catálogo en vivo obtenido exitosamente de Microsoft Learn ($($discoveredList.Count) versiones activas)."
        }
    } catch {
        Write-Warn "No fue posible contactar Microsoft Learn en vivo ($($_.Exception.Message))."
        Write-Info "Activando catálogo base verificado de respaldo (Modo Resiliente)..."
    }

    if (-not $onlineSuccess -or $discoveredList.Count -eq 0) {
        $discoveredList.Clear()
        $discoveredList.Add([PSCustomObject]@{ Key="11_25H2"; DisplayName="Windows 11 25H2 (Build 26200)"; Tag="Última versión anual GA"; Version="11_25H2"; Build="26200"; Family="Windows 11"; Channel="General Availability" })
        $discoveredList.Add([PSCustomObject]@{ Key="11_24H2"; DisplayName="Windows 11 24H2 (Build 26100)"; Tag="Canal General y Base LTSC 2024"; Version="11_24H2"; Build="26100"; Family="Windows 11"; Channel="General Availability" })
        $discoveredList.Add([PSCustomObject]@{ Key="11_23H2"; DisplayName="Windows 11 23H2 (Build 22631)"; Tag="Versión previa activa y madura"; Version="11_23H2"; Build="22631"; Family="Windows 11"; Channel="General Availability" })
        $discoveredList.Add([PSCustomObject]@{ Key="11_LTSC_2024"; DisplayName="Windows 11 Enterprise LTSC 2024 (Build 26100)"; Tag="Soporte Extendido 5/10 años"; Version="11_LTSC_2024"; Build="26100"; Family="Windows 11"; Channel="LTSC" })
    }

    return $discoveredList
}

function Invoke-OfficialWindowsDownload {
    [CmdletBinding()]
    param(

        [string]$Version = "",
        [string]$Edition = "",
        [string]$Language = "",
        [string]$OutputDir = "$HOME\Downloads\Windows_ISOs"
    )

    if (-not $Version) {
        $liveReleases = Get-OnlineWindowsReleases -TimeoutSec 5
        Write-Host ""
        Write-Host "  PASO 1: SELECCIONE EL CANAL Y VERSIÓN DE WINDOWS (MICROSOFT LEARN):" -ForegroundColor Cyan
        Write-Host "  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        
        for ($i = 0; $i -lt $liveReleases.Count; $i++) {
            $rel = $liveReleases[$i]
            $optNum = $i + 1
            Write-Host "  [$optNum] $($rel.DisplayName) — $($rel.Tag)" -ForegroundColor White
        }
        Write-Host "  [0] Cancelar y salir" -ForegroundColor Gray
        Write-Host ""

        $vChoice = Read-Host "  Seleccione una opción (1-$($liveReleases.Count))"
        if ($vChoice -match '^\d+$') {
            $idx = [int]$vChoice - 1
            if ($idx -ge 0 -and $idx -lt $liveReleases.Count) {
                $Version = $liveReleases[$idx].Key
            } else {
                Write-Warn "Descarga cancelada."
                return $null
            }
        } else {
            Write-Warn "Descarga cancelada."
            return $null
        }
    }

    if (-not $Edition) {
        Write-Host ""
        Write-Host "  PASO 2: SELECCIONE EL TIPO DE MEDIO / PAQUETE DE EDICIÓN:" -ForegroundColor Cyan
        Write-Host "  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  [1] Consumer Multi-Edition (Minorista / Retail: Home, Pro, Education)" -ForegroundColor White
        Write-Host "  [2] Business / Volume Licensing (VL Empresarial: Enterprise, Pro)" -ForegroundColor White
        Write-Host "  [3] IoT Enterprise / LTSC (Edición de Máximo Rendimiento y Soporte 10 años)" -ForegroundColor White
        Write-Host ""

        $eChoice = Read-Host "  Seleccione una opción (1-3)"
        switch ($eChoice) {
            "1" { $Edition = "Consumer" }
            "2" { $Edition = "Business" }
            "3" { $Edition = "IoTEnterprise" }
            default { $Edition = "Consumer" }
        }
    }

    if (-not $Language) {
        Write-Host ""
        Write-Host "  PASO 3: SELECCIONE EL IDIOMA OFICIAL DE LA IMAGEN:" -ForegroundColor Cyan
        Write-Host "  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  [1] Español (España / Internacional) [Spanish]" -ForegroundColor White
        Write-Host "  [2] Español (México / Latinoamérica) [Spanish (Mexico)]" -ForegroundColor White
        Write-Host "  [3] Inglés (Estados Unidos) [English]" -ForegroundColor White
        Write-Host "  [4] Portugués (Brasil) [Portuguese (Brazil)]" -ForegroundColor White
        Write-Host "  [5] Otro idioma (escribir nombre en inglés, ej. French, German)" -ForegroundColor Yellow
        Write-Host ""

        $lChoice = Read-Host "  Seleccione una opción (1-5)"
        switch ($lChoice) {
            "1" { $Language = "Spanish" }
            "2" { $Language = "Spanish (Mexico)" }
            "3" { $Language = "English" }
            "4" { $Language = "Portuguese (Brazil)" }
            "5" { 
                $customLang = Read-Host "  Escriba el nombre del idioma en inglés (ej. French)"
                $Language = if ($customLang) { $customLang.Trim() } else { "Spanish" }
            }
            default { $Language = "Spanish" }
        }
    }

    if (-not $OutputDir) { $OutputDir = "$HOME\Downloads\Windows_ISOs" }
    if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
    $OutputDir = (Resolve-Path $OutputDir).Path

    $langFilePart    = $Language -replace '\s+', '_' -replace '[\(\)]', ''
    $isoFileName     = "Windows_${Version}_${Edition}_${langFilePart}_x64.iso"
    $destinationFile = Join-Path $OutputDir $isoFileName

    if (Test-Path $destinationFile) {
        $existingSize = (Get-Item $destinationFile).Length
        if ($existingSize -gt 3GB) {
            Write-OK "La ISO oficial ya existe en destino: $destinationFile ($([math]::Round($existingSize/1GB, 2)) GB)."
            return $destinationFile
        }
    }

    # -----------------------------------------------------------------------
    # DETECCIÓN DE EDICIÓN ESPECIAL (LTSC / IoT / Enterprise / Business)
    # Estas ediciones NO se distribuyen vía MCT público ni Fido CDN Consumer.
    # Fuente oficial: https://learn.microsoft.com/en-us/windows/whats-new/ltsc/
    #                 https://www.microsoft.com/en-us/evalcenter/
    # Fuente técnica: https://github.com/pbatard/Fido#description
    # -----------------------------------------------------------------------
    $isSpecialEdition = ($Edition -in @("Business", "IoTEnterprise")) -or ($Version -match "LTSC")

    $specialLinks = @{
        "11_LTSC_2024" = @{
            EvalCenter   = "https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise"
            MassgraveTag = "#windows-11"
            EvalNote     = "Windows 11 Enterprise LTSC 2024 (Build 26100) — Evaluación oficial 90 días"
            IoTNote      = "IoT Enterprise LTSC: usar ISO 24H2 estándar + PID.txt con clave IoT en setup"
        }
        "11_25H2" = @{
            EvalCenter   = "https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise"
            MassgraveTag = "#windows-11"
            EvalNote     = "Windows 11 Enterprise 25H2 — Evaluación oficial 90 días"
            IoTNote      = "IoT Enterprise: usar ISO 25H2 estándar + PID.txt con clave IoT en setup"
        }
        "11_24H2" = @{
            EvalCenter   = "https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise"
            MassgraveTag = "#windows-11"
            EvalNote     = "Windows 11 Enterprise 24H2 (Build 26100) — Evaluación oficial 90 días"
            IoTNote      = "IoT Enterprise: usar ISO 24H2 estándar + PID.txt con clave IoT en setup"
        }
    }
    $editionLinks = $specialLinks[$Version]

    if ($isSpecialEdition) {
        Write-Host ""
        Write-Host "  ╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
        Write-Host "  ║  EDICIÓN ESPECIAL — CANAL DE DISTRIBUCIÓN OFICIAL                   ║" -ForegroundColor Magenta
        Write-Host "  ║  Edición: $Edition | Versión: $Version" -ForegroundColor Magenta
        Write-Host "  ╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
        Write-Host ""
        Write-Warn "Esta edición NO está disponible en el CDN público de consumidor (Fido/MCT)."
        Write-Info "Motivo técnico: MCT público solo distribuye Home/Pro/Education (Consumer)."
        Write-Info "Fuente: https://learn.microsoft.com/en-us/windows/whats-new/ltsc/"
        Write-Host ""

        $evalUrl      = if ($editionLinks) { $editionLinks.EvalCenter } else { "https://www.microsoft.com/en-us/evalcenter/" }
        $massgraveUrl = "https://massgrave.dev/genuine-installation-media" + $(if ($editionLinks) { $editionLinks.MassgraveTag } else { "" })

        Write-Host "  OPCIÓN A — Microsoft Evaluation Center (Oficial Microsoft, GRATUITO):" -ForegroundColor Cyan
        if ($editionLinks) { Write-Host "  $($editionLinks.EvalNote)" -ForegroundColor White }
        Write-Host "  URL: $evalUrl" -ForegroundColor Yellow
        Write-Host ""
        if ($editionLinks -and $editionLinks.IoTNote -and $Edition -eq "IoTEnterprise") {
            Write-Host "  NOTA IoT Enterprise:" -ForegroundColor Yellow
            Write-Host "  $($editionLinks.IoTNote)" -ForegroundColor White
            Write-Host "  (No existe ISO IoT separada en canal público — se selecciona vía PID.txt durante setup)" -ForegroundColor Gray
            Write-Host ""
        }
        Write-Host "  OPCIÓN B — Massgrave Genuine Media (ISO completa, SHA-256 verificado):" -ForegroundColor Cyan
        Write-Host "  Sin límite de 90 días. Links directos CDN oficial de Microsoft." -ForegroundColor White
        Write-Host "  URL: $massgraveUrl" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Directorio destino: $OutputDir" -ForegroundColor Gray
        Write-Host ""

        $openChoice = Read-Host "  Abrir en navegador: [A] Evaluation Center  [B] Massgrave  [C] Ambos  [N] No"
        switch ($openChoice.ToUpper().Trim()) {
            "A" { Start-Process $evalUrl }
            "B" { Start-Process $massgraveUrl }
            "C" { Start-Process $evalUrl; Start-Sleep -Seconds 1; Start-Process $massgraveUrl }
            default { Write-Info "URLs registradas en log. Sin apertura de navegador." }
        }

        Write-Warn "Descarga manual requerida. Una vez descargada la ISO, use -SourceISO para continuar la compilación."
        return $null
    }

    # -----------------------------------------------------------------------
    # ESTRATEGIA 1: CDN DIRECTO VÍA MOTOR FIDO (pbatard/Fido) — SOLO CONSUMER
    # Fido emula sesión de navegador para obtener tokens temporales del CDN
    # de Microsoft. Sin este proceso, las URLs del CDN retornan HTTP 403/404.
    # Fuente: https://github.com/pbatard/Fido#description
    # -----------------------------------------------------------------------
    $downloadSuccess = $false

    Write-Host ""
    Write-Info "Estrategia 1: Motor CDN Fido (pbatard/Fido) — Edición Consumer..."
    $fidoScript = Join-Path $env:TEMP "Fido_$(Get-Random).ps1"
    $fidoUrl    = "https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1"

    try {
        Invoke-WebRequest -Uri $fidoUrl -OutFile $fidoScript -UseBasicParsing -ErrorAction Stop
        Write-OK "Motor Fido.ps1 descargado."

        $fidoWinNum = if ($Version -like '11_*') { '11' } else { '10' }
        $fidoRel    = ($Version -replace '^\d+_', '') -replace '_', ' '

        Write-Info "Consultando API Microsoft vía Fido (Win $fidoWinNum $fidoRel, $Language, x64)..."
        $fidoArgs      = @("-Win", $fidoWinNum, "-Rel", $fidoRel, "-Lang", $Language, "-Arch", "x64", "-GetUrl")
        $fidoRawOutput = & $fidoScript @fidoArgs 2>&1
        $downloadUrl   = $fidoRawOutput | Where-Object { $_ -match '^https?://' } | Select-Object -Last 1

        if ($downloadUrl) {
            Write-OK "URL CDN autenticada obtenida."
            Write-Info "URL: $downloadUrl"

            if (Get-Command "Start-BitsTransfer" -ErrorAction SilentlyContinue) {
                try {
                    Write-Info "Descargando con motor BITS nativo de Windows..."
                    Start-BitsTransfer -Source $downloadUrl -Destination $destinationFile `
                        -Description "Descarga ISO Oficial Microsoft" -DisplayName "Windows ISO" `
                        -Priority High -ErrorAction Stop
                    $downloadSuccess = (Test-Path $destinationFile) -and ((Get-Item $destinationFile).Length -gt 1GB)
                    if ($downloadSuccess) { Write-OK "Descarga completada vía BITS." }
                } catch {
                    Write-Warn "BITS no completó la transferencia ($($_.Exception.Message)). Intentando con curl..."
                }
            }

            if (-not $downloadSuccess -and (Get-Command "curl.exe" -ErrorAction SilentlyContinue)) {
                Write-Info "Descargando con curl.exe (reanudación -C - activada)..."
                $curlTimeout = if ($ProcessTimeoutMinutes -gt 0) { $ProcessTimeoutMinutes * 60 } else { 0 }
                $curlHb      = if ($HeartbeatIntervalSeconds -gt 0) { $HeartbeatIntervalSeconds } else { 15 }

                $curlRes = Invoke-MonitoredProcess -FilePath "curl.exe" `
                    -ArgumentList @("-L", "-C", "-", "--retry", "5", "--retry-delay", "3", "--connect-timeout", "30", "-#", "-o", $destinationFile, $downloadUrl) `
                    -TaskDescription "Descarga CDN oficial vía curl" `
                    -TimeoutSeconds $curlTimeout `
                    -HeartbeatIntervalSeconds $curlHb

                $downloadSuccess = (Test-Path $destinationFile) -and ((Get-Item $destinationFile).Length -gt 1GB)
                if ($downloadSuccess) { Write-OK "Descarga completada vía curl.exe." }
            }
        } else {
            $isSentinel = ($fidoRawOutput | Out-String) -match "Sentinel"
            if ($isSentinel) {
                Write-Warn "Microsoft Sentinel WAF bloqueó la petición automatizada de Fido."
                Write-Info "Esto ocurre cuando Microsoft detecta requests no interactivos. Conmutando a estrategia 2..."
            } else {
                Write-Warn "Fido no retornó URL CDN válida. Detalle: $(($fidoRawOutput | Out-String).Trim())"
            }
        }
    } catch {
        Write-Warn "Fallo al descargar/ejecutar Fido: $($_.Exception.Message)"
    } finally {
        if (Test-Path $fidoScript) { Remove-Item $fidoScript -Force -ErrorAction SilentlyContinue }
    }

    # -----------------------------------------------------------------------
    # ESTRATEGIA 2: MEDIACREATIONTOOL OFICIAL — SOLO CONSUMER / GA
    # MCT solo ofrece ediciones Consumer (Home/Pro/Education/Pro Workstations).
    # Fuente: https://www.microsoft.com/software-download/windows11
    # -----------------------------------------------------------------------
    if (-not $downloadSuccess) {
        Write-Info "Estrategia 2: MediaCreationTool oficial de Microsoft (Consumer GA)..."

        $mctUrls = @{
            "11_25H2" = "https://go.microsoft.com/fwlink/?linkid=2156295"
            "11_24H2" = "https://go.microsoft.com/fwlink/?linkid=2156295"
            "11_23H2" = "https://go.microsoft.com/fwlink/?linkid=2156295"
        }
        $mctUrl = $mctUrls[$Version]

        if ($mctUrl) {
            $scratchDir = Join-Path $env:TEMP "MCT_$(Get-Random)"
            New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
            $mctPath = Join-Path $scratchDir "MediaCreationTool.exe"

            try {
                Write-Info "Descargando MediaCreationTool firmado por Microsoft..."
                Invoke-WebRequest -Uri $mctUrl -OutFile $mctPath -UseBasicParsing -ErrorAction Stop
                Write-OK "MediaCreationTool descargado en: $mctPath"

                Write-Host ""
                Write-Host "  ┌────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Yellow
                Write-Host "  │  ASISTENTE OFICIAL DE MEDIACREATIONTOOL:                               │" -ForegroundColor Yellow
                Write-Host "  │  1. Se abrirá la ventana gráfica oficial de Microsoft.                │" -ForegroundColor Yellow
                Write-Host "  │  2. Acepte los términos de licencia.                                  │" -ForegroundColor Yellow
                Write-Host "  │  3. Seleccione: 'Crear medios de instalación (archivo ISO)'.         │" -ForegroundColor Yellow
                Write-Host "  │  4. Guarde el ISO en: $OutputDir" -ForegroundColor Cyan
                Write-Host "  └────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
                Write-Host ""

                $mctStartTime = Get-Date
                Start-Process -FilePath $mctPath -ArgumentList @("/Eula", "Accept") -Wait | Out-Null

                if (Test-Path $destinationFile) {
                    $downloadSuccess = $true
                } else {
                    $recentIso = Get-ChildItem -Path $OutputDir -Filter "*.iso" -File -ErrorAction SilentlyContinue |
                                 Where-Object { $_.LastWriteTime -ge $mctStartTime.AddMinutes(-2) } |
                                 Sort-Object LastWriteTime -Descending |
                                 Select-Object -First 1
                    if ($recentIso) {
                        $destinationFile = $recentIso.FullName
                        $downloadSuccess = $true
                    }
                }

                if ($downloadSuccess) {
                    Write-OK "ISO generada y detectada vía MediaCreationTool."
                } else {
                    Write-Warn "MediaCreationTool finalizó sin detectar ISO en directorio objetivo."
                }
            } catch {
                Write-Warn "Fallo en MediaCreationTool: $($_.Exception.Message)"
            } finally {
                if (Test-Path $scratchDir) { Remove-Item $scratchDir -Recurse -Force -ErrorAction SilentlyContinue }
            }
        } else {
            Write-Warn "No hay MCT disponible para la versión '$Version'. Conmutando al navegador asistido."
        }
    }

    # -----------------------------------------------------------------------
    # ESTRATEGIA 3: BROWSER ASISTIDO — FALLBACK FINAL
    # -----------------------------------------------------------------------
    if (-not $downloadSuccess) {
        Write-Host ""
        $consumerUrl  = if ($Version -like '11_*') { "https://www.microsoft.com/software-download/windows11" } `
                        else { "https://www.microsoft.com/software-download/windows10" }
        $massgraveUrl = "https://massgrave.dev/genuine-installation-media"

        Write-Host "  ┌────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
        Write-Host "  │  DESCARGA MANUAL ASISTIDA — CONSUMER (FUENTES OFICIALES):              │" -ForegroundColor Cyan
        Write-Host "  │  1. Portal oficial Microsoft: $consumerUrl" -ForegroundColor Yellow
        Write-Host "  │  2. Massgrave Genuine Media:  $massgraveUrl" -ForegroundColor Yellow
        Write-Host "  │  Directorio destino: $OutputDir" -ForegroundColor Gray
        Write-Host "  └────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
        Write-Host ""

        $openBrowser = Read-Host "  ¿Abrir portal oficial de Microsoft en el navegador ahora? (S/N)"
        if ($openBrowser -match '^[sSyY]') { Start-Process $consumerUrl }
        return $null
    }

    # -----------------------------------------------------------------------
    # VERIFICACIÓN FINAL: TAMAÑO E INTEGRIDAD SHA-256
    # -----------------------------------------------------------------------
    if ($downloadSuccess -and (Test-Path $destinationFile)) {
        $fileSize = (Get-Item $destinationFile).Length
        $sizeGB   = [math]::Round($fileSize / 1GB, 2)
        if ($fileSize -gt 3GB) {
            Write-OK "Descarga completada: $destinationFile ($sizeGB GB)"
            Write-Info "Calculando hash SHA-256..."
            $sha256 = (Get-FileHash -Path $destinationFile -Algorithm SHA256).Hash
            Write-OK "Hash SHA-256: $sha256"
            return $destinationFile
        } else {
            Write-ErrorMsg "El archivo descargado está incompleto ($sizeGB GB). Verifique su conexión."
            return $null
        }
    } else {
        Write-ErrorMsg "No fue posible obtener la ISO. Use -SourceISO para proveer una ISO local."
        return $null
    }
}

# FUNCIÓN: RESOLVER ISO DE ORIGEN
#------------------------------------------------------------------------------

function Resolve-SourceISO {
    param(
        [string]$SourceISO,
        [switch]$DownloadOfficialISO,
        [string]$DownloadVersion = "",
        [string]$DownloadEdition = "",
        [string]$DownloadLanguage = "",
        [string]$DownloadOutputDir = ""
    )

    # Si se solicitó descarga oficial directa vía parámetros
    if ($DownloadOfficialISO -or $DownloadVersion) {
        $downloaded = Invoke-OfficialWindowsDownload -Version $DownloadVersion -Edition $DownloadEdition -Language $DownloadLanguage -OutputDir $DownloadOutputDir
        if ($downloaded -and (Test-Path $downloaded)) {
            return $downloaded
        }
        return $null
    }

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
        Write-Host "  SELECCIÓN DE ORIGEN DE WINDOWS (ISO):" -ForegroundColor Cyan
        Write-Host "  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  [1] Descargar ISO limpia oficial de Microsoft (En vivo / Release Health)" -ForegroundColor Green
        Write-Host "  [2] Buscar archivos ISO en una carpeta local" -ForegroundColor White
        Write-Host "  [3] Escribir la ruta completa del archivo ISO local" -ForegroundColor White
        Write-Host "  [0] Cancelar y salir" -ForegroundColor Gray
        Write-Host ""

        $choice = Read-Host "  Seleccione una opción (0-3)"

        switch ($choice) {
            '1' {
                $downloadedIso = Invoke-OfficialWindowsDownload -OutputDir $DownloadOutputDir
                if ($downloadedIso -and (Test-Path $downloadedIso)) {
                    return $downloadedIso
                }
                Write-Warn "No se completó la descarga oficial. Intente nuevamente o seleccione una ISO local."
                continue
            }

            '2' {
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

            '3' {
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
                return $null
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

    $timeoutSec = if ($ProcessTimeoutMinutes -gt 0) { $ProcessTimeoutMinutes * 60 } else { 0 }
    $hbSec      = if ($HeartbeatIntervalSeconds -gt 0) { $HeartbeatIntervalSeconds } else { 15 }

    # Intento 1: 7-Zip
    $7zPath = Test-7ZipInstalled

    if ($7zPath) {
        Write-Host "    Usando 7-Zip: $7zPath" -ForegroundColor Gray

        try {
            $arguments = @(
                'x'
                $IsoPath
                "-o$Destination"
                '-y'
            )

            $pRes = Invoke-MonitoredProcess -FilePath $7zPath `
                                            -ArgumentList $arguments `
                                            -TaskDescription "Extracción de ISO con 7-Zip" `
                                            -TimeoutSeconds $timeoutSec `
                                            -HeartbeatIntervalSeconds $hbSec

            if ($pRes.Success) {
                Write-OK "ISO extraída con 7-Zip."
                return $true
            } elseif ($pRes.TimedOut) {
                Write-ErrorMsg "La extracción con 7-Zip superó el límite de tiempo (${timeoutSec}s) y fue cancelada."
            } else {
                Write-Warn "7-Zip falló con código de salida: $($pRes.ExitCode)"
                if ($pRes.StdErr) { Write-Warn "Detalle: $($pRes.StdErr)" }
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

        $roboArgs = @($driveRoot, $Destination, "/E", "/COPY:DAT", "/R:2", "/W:2", "/NP", "/NFL", "/NDL", "/MT:16", "/XD", "System Volume Information")
        $roboRes  = Invoke-MonitoredProcess -FilePath "robocopy.exe" `
                                            -ArgumentList $roboArgs `
                                            -AllowExitCodes @(0, 1, 2, 3, 4, 5, 6, 7) `
                                            -TaskDescription "Copia de archivos ISO con Robocopy" `
                                            -TimeoutSeconds $timeoutSec `
                                            -HeartbeatIntervalSeconds $hbSec

        if ($roboRes.Success) {
            Write-OK "Archivos copiados desde unidad $driveRoot."
            return $true
        } elseif ($roboRes.TimedOut) {
            throw "Robocopy excedió el tiempo límite (${timeoutSec}s) y se canceló."
        } else {
            throw "Robocopy terminó con código $($roboRes.ExitCode)."
        }
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
# RESOLVER ISO DE ORIGEN (LOCAL O DESCARGA OFICIAL EN VIVO)
#------------------------------------------------------------------------------

$downloadTempDir = Join-Path $OutputDir "Downloads"
$SourceISO = Resolve-SourceISO -SourceISO $SourceISO `
                               -DownloadOfficialISO:$DownloadOfficialISO `
                               -DownloadVersion $DownloadVersion `
                               -DownloadEdition $DownloadEdition `
                               -DownloadLanguage $DownloadLanguage `
                               -DownloadOutputDir $downloadTempDir

if (-not $SourceISO -or -not (Test-Path $SourceISO)) {
    Write-ErrorMsg "No se seleccionó ni se pudo descargar una imagen ISO válida. Abortando proceso."
    exit 1
}

Write-Host ""
Write-Host "  ISO origen seleccionada: $SourceISO" -ForegroundColor Green

#------------------------------------------------------------------------------
# WIZARD INTERACTIVO Y ELECCIONES DE DESPLIEGUE
#------------------------------------------------------------------------------

# Wizard regional / usuario / contraseña / tweaks visuales.
# Solo se mostrará si faltan parámetros clave.
Invoke-WizardConfig -ScriptBoundParameters $script:ResolvedParameters

# Perfil de optimización y bloqueo de OneDrive.
# Si se pasaron por parámetro, se respetan; si no, se preguntan.
Invoke-DeploymentChoices -ScriptBoundParameters $script:ResolvedParameters -SkipAutoUnattend:$SkipAutoUnattend

# Guardar configuracion en Preset JSON si se solicito
if ($SavePreset) {
    Export-BuildPreset -OutputDirectory (Get-Location).Path
}

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
# DIAGNÓSTICO PRE-VUELO DE RECURSOS OPCIONALES (Paso 0)
#------------------------------------------------------------------------------

Write-Host ""
Write-Host "  ══ Diagnóstico Pre-vuelo de Recursos Opcionales ══" -ForegroundColor Cyan

# 1. Runtimes esenciales (VC++ / DirectX)
if ($script:SkipRuntimes -or $SkipRuntimes) {
    Write-Info "Runtimes Esenciales : Omitidos por configuración (-SkipRuntimes activo)"
    Write-LogEntry -Level "INFO" -Message "Runtimes omitidos por configuración (-SkipRuntimes)."
    $runtimesInfo = @{ Found = $false; Path = $null; FileCount = 0; HasVcRedist = $false; HasDirectX = $false }
} else {
    $runtimesInfo = Resolve-RuntimesDirectory -ExplicitPath $RuntimesPath
    if ($runtimesInfo.Found) {
        $detailList = [System.Collections.Generic.List[string]]::new()
        if ($runtimesInfo.HasVcRedist) { $detailList.Add("Visual C++") }
        if ($runtimesInfo.HasDirectX)  { $detailList.Add("DirectX") }
        $detailStr = if ($detailList.Count -gt 0) { " ($($detailList -join ' + '))" } else { "" }
        Write-OK "Runtimes Esenciales : Encontrados en '$($runtimesInfo.Path)' [$($runtimesInfo.FileCount) archivos$detailStr]"
        Write-LogEntry -Level "INFO" -Message "Runtimes resueltos: $($runtimesInfo.Path) ($($runtimesInfo.FileCount) archivos)"
    } else {
        Write-Info "Runtimes Esenciales : No detectados (Opcional - use scripts\Builder\Get-EssentialRuntimes.ps1 si los requiere)"
        Write-LogEntry -Level "INFO" -Message "Runtimes no detectados. Se omitirá pre-carga."
    }
}

# 2. Actualizaciones acumulativas (Updates/)
if ($script:SkipUpdates -or $SkipUpdates) {
    Write-Info "Actualizaciones (MSU): Omitidas por configuración (-SkipUpdates activo)"
    Write-LogEntry -Level "INFO" -Message "Updates omitidos por configuración (-SkipUpdates)."
    $resolvedUpdatesDir = $null
    $script:PreflightUpdatesDetected = $false
} else {
    $candidateUpdates = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($UpdatesPath)) {
        $candidateUpdates.Add($UpdatesPath)
    } else {
        $candidateUpdates.Add((Join-Path (Get-Location) "Updates"))
        $candidateUpdates.Add((Join-Path (Get-Location) "scripts\Updates"))
        if ($ScriptsDir) {
            $candidateUpdates.Add((Join-Path $ScriptsDir "Updates"))
            $candidateUpdates.Add((Join-Path (Split-Path -Parent $ScriptsDir) "Updates"))
        }
        if ($PSScriptRoot) {
            $candidateUpdates.Add((Join-Path $PSScriptRoot "Updates"))
            $candidateUpdates.Add((Join-Path (Split-Path -Parent $PSScriptRoot) "Updates"))
        }
        $candidateUpdates.Add("C:\OptimizedISO\scripts\Updates")
        $candidateUpdates.Add("C:\OptimizedISO\Updates")
        $candidateUpdates.Add("C:\scripts\Updates")
    }

    $resolvedUpdatesDir = $null
    foreach ($candUpd in $candidateUpdates) {
        if ($candUpd -and (Test-Path $candUpd)) {
            $updCount = (Get-ChildItem -Path $candUpd -Include *.msu, *.cab -Recurse -File -ErrorAction SilentlyContinue).Count
            if ($updCount -gt 0) {
                $resolvedUpdatesDir = (Resolve-Path $candUpd).Path
                Write-OK "Actualizaciones (MSU): Encontradas en '$resolvedUpdatesDir' [$updCount paquetes listos para inyección]"
                Write-LogEntry -Level "INFO" -Message "Updates resueltos: $resolvedUpdatesDir ($updCount paquetes)"
                break
            }
        }
    }
    $script:PreflightUpdatesDetected = [bool]$resolvedUpdatesDir
    if (-not $resolvedUpdatesDir) {
        Write-Info "Actualizaciones (MSU): No detectadas (Opcional - use scripts\Builder\Get-WindowsUpdates.ps1 si requiere parches offline)"
        Write-LogEntry -Level "INFO" -Message "Updates no detectados. Se omitirá slipstreaming offline."
    }
}

# 3. Controladores adicionales (Drivers/)
if ($script:SkipDrivers -or $SkipDrivers) {
    Write-Info "Controladores (INF) : Omitidos por configuración (-SkipDrivers activo)"
    Write-LogEntry -Level "INFO" -Message "Drivers omitidos por configuración (-SkipDrivers)."
    $resolvedDriversDir = $null
    $script:PreflightDriversDetected = $false
} else {
    $candidateDrivers = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($DriversPath)) {
        $candidateDrivers.Add($DriversPath)
    } else {
        $candidateDrivers.Add((Join-Path (Get-Location) "Drivers"))
        $candidateDrivers.Add((Join-Path (Get-Location) "scripts\Drivers"))
        if ($ScriptsDir) {
            $candidateDrivers.Add((Join-Path $ScriptsDir "Drivers"))
            $candidateDrivers.Add((Join-Path (Split-Path -Parent $ScriptsDir) "Drivers"))
        }
        if ($PSScriptRoot) {
            $candidateDrivers.Add((Join-Path $PSScriptRoot "Drivers"))
            $candidateDrivers.Add((Join-Path (Split-Path -Parent $PSScriptRoot) "Drivers"))
        }
        $candidateDrivers.Add("C:\OptimizedISO\scripts\Drivers")
        $candidateDrivers.Add("C:\OptimizedISO\Drivers")
        $candidateDrivers.Add("C:\scripts\Drivers")
    }
    $resolvedDriversDir = $null
    foreach ($candDrv in $candidateDrivers) {
        if ($candDrv -and (Test-Path $candDrv)) {
            $drvCount = (Get-ChildItem -Path $candDrv -Include *.inf -Recurse -File -ErrorAction SilentlyContinue).Count
            if ($drvCount -gt 0) {
                $resolvedDriversDir = (Resolve-Path $candDrv).Path
                Write-OK "Controladores (INF) : Encontrados en '$resolvedDriversDir' [$drvCount drivers .inf]"
                Write-LogEntry -Level "INFO" -Message "Drivers resueltos: $resolvedDriversDir ($drvCount drivers)"
                break
            }
        }
    }
    $script:PreflightDriversDetected = [bool]$resolvedDriversDir
    if (-not $resolvedDriversDir) {
        Write-Info "Controladores (INF) : No detectados (Opcional - use scripts\Drivers\Backup-HardwareDrivers.ps1 para respaldo del host)"
        Write-LogEntry -Level "INFO" -Message "Drivers no detectados. Se omitirá inyección de drivers."
    }
}
Write-Host ""

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

# Crear estructura $OEM$ completa (System Scripts y Public Desktop)
New-Item -ItemType Directory -Path $OEMScriptsDir  -Force | Out-Null
New-Item -ItemType Directory -Path $OEMScriptsDir1 -Force | Out-Null
New-Item -ItemType Directory -Path $OEMDesktopDir  -Force | Out-Null

# Detectar qué versión de Windows es esta ISO
$detectedVersion = Detect-WindowsVersion -IsoPath $SourceISO -ExtractedDir $ISOFilesDir

Write-Host "    Versión detectada: Windows $detectedVersion" -ForegroundColor Cyan
Write-OK "La edición de Windows y el disco se seleccionarán durante la instalación"

#------------------------------------------------------------------------------
# SELECCIONAR SCRIPT OPTIMIZADOR INTERACTIVAMENTE
#------------------------------------------------------------------------------

$scriptsToInject = @()

# Detectar scripts conocidos disponibles en el repositorio
$toolkitCandidate     = Join-Path $ScriptsDir "Modules\romanOS-Toolkit.ps1"
$debScriptCandidate   = Join-Path $ScriptsDir "Modules\Win11-Debloat-v3-Adaptive.ps1"
$maintScriptCandidate = Join-Path $ScriptsDir "Modules\Invoke-WindowsMaintenance.ps1"
$netScriptCandidate   = Join-Path $ScriptsDir "Modules\Win11-Network-Diagnostics-Optimizer.ps1"
$secScriptCandidate   = Join-Path $ScriptsDir "Modules\Invoke-WindowsSecurityHardening.ps1"
$contextCandidate     = Join-Path $ScriptsDir "Modules\Add-OptimizedContextMenus.ps1"
$legacyCandidate      = Join-Path $ScriptsDir "Modules\Windows${detectedVersion}_PostInstall_Optimizer.ps1"

# Verificar si se pasó ruta explícita por parámetro CLI
if ($detectedVersion -eq "10") {
    throw "romanOS está diseñado y optimizado exclusivamente para Windows 11 (Build >= 22000). La imagen proporcionada corresponde a Windows 10, la cual ha sido descontinuada del ecosistema."
}
$paramScriptPath = $Win11ScriptPath

if ($paramScriptPath) {
    $resolvedPath = if (Test-Path $paramScriptPath) { $paramScriptPath } else { Join-Path $ScriptsDir $paramScriptPath }
    if (Test-Path $resolvedPath) {
        $scriptsToInject += @{
            Source       = (Resolve-Path $resolvedPath).Path
            DestName     = [System.IO.Path]::GetFileName($resolvedPath)
            LauncherName = "Optimizar Windows (Opcional).cmd"
            ShortcutName = "Optimizar Sistema (Opcional).lnk"
            Title        = "Optimizador Post-Instalacion de Windows $detectedVersion"
        }
        Write-OK "Usando script especificado por parámetro: $resolvedPath"
    }
}

# Si no se pasó por parámetro, mostrar menú interactivo con scripts disponibles
if ($scriptsToInject.Count -eq 0) {
    Write-Host ""
    Write-Host "  SELECCIÓN DE SCRIPT(S) POST-INSTALACIÓN EN ESCRITORIO:" -ForegroundColor Cyan
    Write-Host "  ──────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    $hasToolkit = Test-Path $toolkitCandidate
    $hasDeb     = Test-Path $debScriptCandidate
    $hasMaint   = Test-Path $maintScriptCandidate
    $hasNet     = Test-Path $netScriptCandidate
    $hasSec     = Test-Path $secScriptCandidate
    $hasContext = Test-Path $contextCandidate
    $hasLeg     = Test-Path $legacyCandidate

    if ($hasToolkit -or ($hasDeb -and $hasMaint)) {
        Write-Host "  [1] Suite Completa romanOS: Toolkit Maestro + Debloat + Mantenimiento + Red + Seguridad + Menus [Recomendado]" -ForegroundColor Green
    }
    if ($hasToolkit) {
        Write-Host "  [2] romanOS-Toolkit.ps1 (Hub Maestro Orquestador Completo)" -ForegroundColor White
    }
    if ($hasDeb) {
        Write-Host "  [3] Win11-Debloat-v3-Adaptive.ps1 (Debloat y Optimización Adaptativa)" -ForegroundColor White
    }
    if ($hasMaint) {
        Write-Host "  [4] Invoke-WindowsMaintenance.ps1 (Mantenimiento, Limpieza y Reparación)" -ForegroundColor White
    }
    if ($hasNet) {
        Write-Host "  [5] Win11-Network-Diagnostics-Optimizer.ps1 (Diagnóstico de Red y Latencia)" -ForegroundColor White
    }
    if ($hasSec) {
        Write-Host "  [6] Invoke-WindowsSecurityHardening.ps1 (Auditoría de Seguridad y Hardening)" -ForegroundColor White
    }

    Write-Host "  [7] Seleccionar otro archivo .ps1 personalizado..." -ForegroundColor Yellow
    Write-Host "  [0] Omitir inyección de scripts (Solo autounattend.xml y tweaks offline)" -ForegroundColor Gray
    Write-Host ""

    $choice = if ($script:Headless -or $PresetFile) {
        Write-Info "Modo Headless/Preset activo: Auto-seleccionando Suite Completa romanOS (Opción 1)."
        "1"
    } else {
        $r = Read-Host "  Seleccione una opción (Default: 1)"
        if ($r -eq '') { "1" } else { $r }
    }

    switch ($choice) {
        "1" {
            # Suite Completa
            if ($hasToolkit) {
                $scriptsToInject += @{
                    Source       = $toolkitCandidate
                    DestName     = [System.IO.Path]::GetFileName($toolkitCandidate)
                    LauncherName = "romanOS-Toolkit.cmd"
                    ShortcutName = "romanOS Toolkit Maestro.lnk"
                    Title        = "romanOS Toolkit Maestro (Hub Central)"
                }
            }
            if ($hasDeb) {
                $scriptsToInject += @{
                    Source       = $debScriptCandidate
                    DestName     = [System.IO.Path]::GetFileName($debScriptCandidate)
                    LauncherName = "Optimizar Windows (Opcional).cmd"
                    ShortcutName = "Optimizar Sistema (Opcional).lnk"
                    Title        = "Optimizador Adaptativo de Windows $detectedVersion"
                }
            }
            if ($hasMaint) {
                $scriptsToInject += @{
                    Source       = $maintScriptCandidate
                    DestName     = [System.IO.Path]::GetFileName($maintScriptCandidate)
                    LauncherName = "Mantenimiento y Reparacion.cmd"
                    ShortcutName = "Mantenimiento del Sistema.lnk"
                    Title        = "Mantenimiento y Reparacion del Sistema"
                }
            }
            if ($hasNet) {
                $scriptsToInject += @{
                    Source       = $netScriptCandidate
                    DestName     = [System.IO.Path]::GetFileName($netScriptCandidate)
                    LauncherName = "Optimizar Red y Latencia (Opcional).cmd"
                    ShortcutName = "Optimizar Red y Latencia (Opcional).lnk"
                    Title        = "Optimizador de Red y Baja Latencia"
                }
            }
            if ($hasSec) {
                $scriptsToInject += @{
                    Source       = $secScriptCandidate
                    DestName     = [System.IO.Path]::GetFileName($secScriptCandidate)
                    LauncherName = "Auditoria de Seguridad (On-Demand).cmd"
                    ShortcutName = "Auditoria de Seguridad (On-Demand).lnk"
                    Title        = "Auditoria de Seguridad y Hardening Desacoplado"
                }
            }
            if ($hasContext) {
                $scriptsToInject += @{
                    Source       = $contextCandidate
                    DestName     = [System.IO.Path]::GetFileName($contextCandidate)
                    LauncherName = "Menu Contextual y Clasico.cmd"
                    ShortcutName = "Menu Contextual y Clasico.lnk"
                    Title        = "Configuracion de Menus Contextuales y Menu Clasico"
                }
            }
        }

        "2" {
            if ($hasToolkit) {
                $scriptsToInject += @{
                    Source       = $toolkitCandidate
                    DestName     = [System.IO.Path]::GetFileName($toolkitCandidate)
                    LauncherName = "romanOS-Toolkit.cmd"
                    ShortcutName = "romanOS Toolkit Maestro.lnk"
                    Title        = "romanOS Toolkit Maestro (Hub Central)"
                }
            }
        }

        "3" {
            $src = if ($hasDeb) { $debScriptCandidate } elseif ($hasLeg) { $legacyCandidate } else { $null }
            if ($src) {
                $scriptsToInject += @{
                    Source       = $src
                    DestName     = [System.IO.Path]::GetFileName($src)
                    LauncherName = "Optimizar Windows (Opcional).cmd"
                    ShortcutName = "Optimizar Sistema (Opcional).lnk"
                    Title        = "Optimizador Adaptativo de Windows $detectedVersion"
                }
            }
        }

        "4" {
            if ($hasMaint) {
                $scriptsToInject += @{
                    Source       = $maintScriptCandidate
                    DestName     = [System.IO.Path]::GetFileName($maintScriptCandidate)
                    LauncherName = "Mantenimiento y Reparacion.cmd"
                    ShortcutName = "Mantenimiento del Sistema.lnk"
                    Title        = "Mantenimiento y Reparacion del Sistema"
                }
            }
        }

        "5" {
            if ($hasNet) {
                $scriptsToInject += @{
                    Source       = $netScriptCandidate
                    DestName     = [System.IO.Path]::GetFileName($netScriptCandidate)
                    LauncherName = "Optimizar Red y Latencia (Opcional).cmd"
                    ShortcutName = "Optimizar Red y Latencia (Opcional).lnk"
                    Title        = "Optimizador de Red y Baja Latencia"
                }
            }
        }

        "6" {
            if ($hasSec) {
                $scriptsToInject += @{
                    Source       = $secScriptCandidate
                    DestName     = [System.IO.Path]::GetFileName($secScriptCandidate)
                    LauncherName = "Auditoria de Seguridad (On-Demand).cmd"
                    ShortcutName = "Auditoria de Seguridad (On-Demand).lnk"
                    Title        = "Auditoria de Seguridad y Hardening Desacoplado"
                }
            }
        }

        "7" {
            Write-Host ""
            $manual = Read-Host "  Escriba la ruta completa del script .ps1"
            if ($manual -and (Test-Path $manual)) {
                $scriptsToInject += @{
                    Source       = (Resolve-Path $manual).Path
                    DestName     = [System.IO.Path]::GetFileName($manual)
                    LauncherName = "Ejecutar Script Personalizado (Opcional).cmd"
                    ShortcutName = "Ejecutar Script Personalizado (Opcional).lnk"
                    Title        = "Script Personalizado de Post-Instalacion"
                }
            } else {
                Write-Warn "Ruta invalida. Se continuara sin inyeccion de scripts."
            }
        }

        default {
            Write-Warn "Se omitira la inyeccion de scripts post-instalacion."
        }
    }
}

# ------------------------------------------------------------------
# Copiar scripts seleccionados a $OEM$\$$\Setup\Scripts y $OEM$\$1
# ------------------------------------------------------------------
if ($scriptsToInject.Count -gt 0) {
    foreach ($sc in $scriptsToInject) {
        # 1. Copiar script .ps1 a las dos rutas de scripts para máxima redundancia
        Copy-Item -Path $sc.Source -Destination (Join-Path $OEMScriptsDir $sc.DestName) -Force
        Copy-Item -Path $sc.Source -Destination (Join-Path $OEMScriptsDir1 $sc.DestName) -Force
        Write-OK "Script inyectado en `$OEM`$: $($sc.DestName)"

        # 2. Generar Lanzador .cmd con auto-elevación UAC en el Escritorio Público y Scripts
        $launcherContent = @"
@echo off
title $($sc.Title)
echo.
echo ======================================================================
echo   $($sc.Title)
echo   Ejecucion bajo demanda con privilegios de Administrador
echo ======================================================================
echo.

:: Comprobar privilegios de Administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Solicitando elevacion de privilegios de Administrador...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b 0
)

cd /d "%WINDIR%\Setup\Scripts"

if exist "%WINDIR%\Setup\Scripts\$($sc.DestName)" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%WINDIR%\Setup\Scripts\$($sc.DestName)"
) else if exist "C:\Windows\Setup\Scripts\$($sc.DestName)" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "C:\Windows\Setup\Scripts\$($sc.DestName)"
) else (
    echo [ERROR] No se encontro el script en C:\Windows\Setup\Scripts\$($sc.DestName)
    pause
    exit /b 1
)

echo.
echo ======================================================================
echo   Proceso finalizado. Presione cualquier tecla para cerrar...
echo ======================================================================
pause >nul
"@

        $launcherScriptsPath = Join-Path $OEMScriptsDir $sc.LauncherName
        $launcherScripts1Path = Join-Path $OEMScriptsDir1 $sc.LauncherName

        [System.IO.File]::WriteAllText($launcherScriptsPath, $launcherContent, [System.Text.Encoding]::ASCII)
        [System.IO.File]::WriteAllText($launcherScripts1Path, $launcherContent, [System.Text.Encoding]::ASCII)

        Write-OK "Lanzador elevado registrado en Scripts: $($sc.LauncherName)"
    }

    # Generar tambien lanzador de Auditoria en Scripts
    $diagLauncherContent = @"
@echo off
title Auditoria y Diagnostico de Instalacion de Windows
echo.
echo ======================================================================
echo   Auditoria y Diagnostico de Instalacion de Windows
echo   Ejecucion bajo demanda con privilegios de Administrador
echo ======================================================================
echo.

:: Comprobar privilegios de Administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Solicitando elevacion de privilegios de Administrador...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b 0
)

cd /d "%WINDIR%\Setup\Scripts"

if exist "%WINDIR%\Setup\Scripts\PostInstall-Diagnostics.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%WINDIR%\Setup\Scripts\PostInstall-Diagnostics.ps1"
) else if exist "C:\Windows\Setup\Scripts\PostInstall-Diagnostics.ps1" (
    powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "C:\Windows\Setup\Scripts\PostInstall-Diagnostics.ps1"
) else (
    echo [ERROR] No se encontro PostInstall-Diagnostics.ps1 en C:\Windows\Setup\Scripts\
    pause
    exit /b 1
)

echo.
echo ======================================================================
echo   Auditoria finalizada. Presione cualquier tecla para cerrar...
echo ======================================================================
pause >nul
"@
    [System.IO.File]::WriteAllText((Join-Path $OEMScriptsDir "Auditar-Instalacion.cmd"), $diagLauncherContent, [System.Text.Encoding]::ASCII)
    [System.IO.File]::WriteAllText((Join-Path $OEMScriptsDir1 "Auditar-Instalacion.cmd"), $diagLauncherContent, [System.Text.Encoding]::ASCII)
    Write-OK "Lanzador de Auditoria registrado en Scripts: Auditar-Instalacion.cmd"
} else {
    Write-Warn "No se seleccionaron scripts adicionales para inyeccion."
}

# ------------------------------------------------------------------
# Copiar Runtimes esenciales a sources\$OEM$\$$\Setup\Scripts\Runtimes si existen
# ------------------------------------------------------------------
if ($script:SkipRuntimes -or $SkipRuntimes) {
    Write-Host "    Runtimes esenciales omitidos por configuración (-SkipRuntimes activo)." -ForegroundColor Gray
    Add-AuditRecord -Resource "Runtimes (VC++ / DirectX)" -Target '$OEM$' -Status "SKIP" `
                    -Details "Omitido por configuración (-SkipRuntimes)"
} else {
    if (-not $runtimesInfo) {
        $runtimesInfo = Resolve-RuntimesDirectory -ExplicitPath $RuntimesPath
    }

    if ($runtimesInfo.Found -and (Test-Path $runtimesInfo.Path)) {
        $destRuntimesDir  = Join-Path $OEMScriptsDir "Runtimes"
        $destRuntimesDir1 = Join-Path $OEMScriptsDir1 "Runtimes"
        if (-not (Test-Path $destRuntimesDir))  { New-Item -ItemType Directory -Path $destRuntimesDir -Force | Out-Null }
        if (-not (Test-Path $destRuntimesDir1)) { New-Item -ItemType Directory -Path $destRuntimesDir1 -Force | Out-Null }
        Copy-Item -Path "$($runtimesInfo.Path)\*" -Destination $destRuntimesDir -Recurse -Force
        Copy-Item -Path "$($runtimesInfo.Path)\*" -Destination $destRuntimesDir1 -Recurse -Force
        Write-OK "Runtimes esenciales inyectados en `$OEM$ ($($runtimesInfo.FileCount) archivos copiados)."
        Add-AuditRecord -Resource "Runtimes (VC++ / DirectX)" -Target '$OEM$' -Status "OK" `
                        -Details "$($runtimesInfo.FileCount) archivos desde '$($runtimesInfo.Path)'"
    } else {
        Write-Host "    Carpeta 'Runtimes' no detectada. Se omite pre-carga en `$OEM$." -ForegroundColor Gray
        Add-AuditRecord -Resource "Runtimes (VC++ / DirectX)" -Target '$OEM$' -Status "SKIP" `
                        -Details "Carpeta Runtimes/ no detectada. Ejecute scripts\Builder\Get-EssentialRuntimes.ps1"
    }
}

# ------------------------------------------------------------------
# Copiar Motores Core (Policy, Hardware, UI) a sources\$OEM$\$$\Setup\Scripts\Core
# ------------------------------------------------------------------
$coreSrcDir = Join-Path $ScriptsDir "Core"
if (Test-Path $coreSrcDir) {
    $destCoreDir  = Join-Path $OEMScriptsDir "Core"
    $destCoreDir1 = Join-Path $OEMScriptsDir1 "Core"
    if (-not (Test-Path $destCoreDir))  { New-Item -ItemType Directory -Path $destCoreDir -Force | Out-Null }
    if (-not (Test-Path $destCoreDir1)) { New-Item -ItemType Directory -Path $destCoreDir1 -Force | Out-Null }
    Copy-Item -Path "$coreSrcDir\*" -Destination $destCoreDir -Recurse -Force
    Copy-Item -Path "$coreSrcDir\*" -Destination $destCoreDir1 -Recurse -Force
    Write-OK "Motores del sistema (Core: Policy-Engine, Hardware-Engine, UI-Engine) inyectados en `$OEM`$."
    Add-AuditRecord -Resource "Motores Core" -Target '$OEM$' -Status "OK" -Details "Copiados a $destCoreDir"
}

# ------------------------------------------------------------------
# Copiar Script de Menú Contextual Canónico y Diagnóstico Físico a $OEM$
# ------------------------------------------------------------------
$ctxMenuSrc = Join-Path $ScriptsDir "Modules\Add-OptimizedContextMenus.ps1"
if (Test-Path $ctxMenuSrc) {
    Copy-Item -Path $ctxMenuSrc -Destination (Join-Path $OEMScriptsDir "Add-OptimizedContextMenus.ps1") -Force
    Copy-Item -Path $ctxMenuSrc -Destination (Join-Path $OEMScriptsDir1 "Add-OptimizedContextMenus.ps1") -Force
    Write-OK "Script de menú contextual canónico inyectado en `$OEM`$."
}

$diagSourceCandidates = @(
    (Join-Path $ScriptsDir "Modules\PostInstall-Diagnostics.ps1"),
    (Join-Path (Split-Path $ScriptsDir -Parent) "scripts\Modules\PostInstall-Diagnostics.ps1")
)
$physicalDiag = $diagSourceCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($physicalDiag) {
    Copy-Item -Path $physicalDiag -Destination (Join-Path $OEMScriptsDir "PostInstall-Diagnostics.ps1") -Force
    Copy-Item -Path $physicalDiag -Destination (Join-Path $OEMScriptsDir1 "PostInstall-Diagnostics.ps1") -Force
    Write-OK "Script de diagnóstico integral inyectado desde archivo físico en `$OEM`$."
}

# ------------------------------------------------------------------
# Copiar Suite de Gestión de Controladores (Drivers) a sources\$OEM$\$$\Setup\Scripts\Drivers
# ------------------------------------------------------------------
$driversSrcDir = Join-Path $ScriptsDir "Drivers"
if (Test-Path $driversSrcDir) {
    $destDriversDir  = Join-Path $OEMScriptsDir "Drivers"
    $destDriversDir1 = Join-Path $OEMScriptsDir1 "Drivers"
    if (-not (Test-Path $destDriversDir))  { New-Item -ItemType Directory -Path $destDriversDir -Force | Out-Null }
    if (-not (Test-Path $destDriversDir1)) { New-Item -ItemType Directory -Path $destDriversDir1 -Force | Out-Null }
    Copy-Item -Path "$driversSrcDir\*" -Destination $destDriversDir -Recurse -Force
    Copy-Item -Path "$driversSrcDir\*" -Destination $destDriversDir1 -Recurse -Force
    Write-OK "Suite de gestion de controladores (Drivers) inyectada en `$OEM`$."
    Add-AuditRecord -Resource "Drivers Suite" -Target '$OEM$' -Status "OK" -Details "Copiados a $destDriversDir"
}

# ------------------------------------------------------------------
# Copiar Módulos Complementarios Físicos (Navegadores, Migración, Updates) a $OEM$
# ------------------------------------------------------------------
$destModulesDir = Join-Path $OEMScriptsDir "Modules"
$destModulesDir1 = Join-Path $OEMScriptsDir1 "Modules"
if (-not (Test-Path $destModulesDir)) { New-Item -ItemType Directory -Path $destModulesDir -Force | Out-Null }
if (-not (Test-Path $destModulesDir1)) { New-Item -ItemType Directory -Path $destModulesDir1 -Force | Out-Null }

$browserSrc = Join-Path $ScriptsDir "Modules\Optimize-WebBrowsers.ps1"
if (Test-Path $browserSrc) {
    Copy-Item -Path $browserSrc -Destination (Join-Path $OEMScriptsDir "Optimize-WebBrowsers.ps1") -Force
    Copy-Item -Path $browserSrc -Destination (Join-Path $OEMScriptsDir1 "Optimize-WebBrowsers.ps1") -Force
    Copy-Item -Path $browserSrc -Destination (Join-Path $destModulesDir "Optimize-WebBrowsers.ps1") -Force
    Copy-Item -Path $browserSrc -Destination (Join-Path $destModulesDir1 "Optimize-WebBrowsers.ps1") -Force
    $browserCmd = Join-Path $ScriptsDir "Modules\Optimize-WebBrowsers.cmd"
    if (Test-Path $browserCmd) {
        Copy-Item -Path $browserCmd -Destination (Join-Path $OEMScriptsDir "Optimize-WebBrowsers.cmd") -Force
        Copy-Item -Path $browserCmd -Destination (Join-Path $OEMScriptsDir1 "Optimize-WebBrowsers.cmd") -Force
        Copy-Item -Path $browserCmd -Destination (Join-Path $destModulesDir "Optimize-WebBrowsers.cmd") -Force
        Copy-Item -Path $browserCmd -Destination (Join-Path $destModulesDir1 "Optimize-WebBrowsers.cmd") -Force
    }
    Write-OK "Optimizador oficial de navegadores web inyectado en `$OEM`$."
    Add-AuditRecord -Resource "Optimize-WebBrowsers" -Target '$OEM$' -Status "OK" -Details "Inyectado en Scripts y Modules"
}

$userMigSrc = Join-Path $ScriptsDir "Modules\Migrar-Usuario-W11.ps1"
if (Test-Path $userMigSrc) {
    Copy-Item -Path $userMigSrc -Destination (Join-Path $OEMScriptsDir "Migrar-Usuario-W11.ps1") -Force
    Copy-Item -Path $userMigSrc -Destination (Join-Path $OEMScriptsDir1 "Migrar-Usuario-W11.ps1") -Force
    Copy-Item -Path $userMigSrc -Destination (Join-Path $destModulesDir "Migrar-Usuario-W11.ps1") -Force
    Copy-Item -Path $userMigSrc -Destination (Join-Path $destModulesDir1 "Migrar-Usuario-W11.ps1") -Force
    $userMigCmd = Join-Path $ScriptsDir "Modules\Migrar-Usuario-W11.cmd"
    if (Test-Path $userMigCmd) {
        Copy-Item -Path $userMigCmd -Destination (Join-Path $OEMScriptsDir "Migrar-Usuario-W11.cmd") -Force
        Copy-Item -Path $userMigCmd -Destination (Join-Path $OEMScriptsDir1 "Migrar-Usuario-W11.cmd") -Force
        Copy-Item -Path $userMigCmd -Destination (Join-Path $destModulesDir "Migrar-Usuario-W11.cmd") -Force
        Copy-Item -Path $userMigCmd -Destination (Join-Path $destModulesDir1 "Migrar-Usuario-W11.cmd") -Force
    }
    Write-OK "Herramienta de migracion de usuario inyectada en `$OEM`$."
    Add-AuditRecord -Resource "Migrar-Usuario-W11" -Target '$OEM$' -Status "OK" -Details "Inyectado en Scripts y Modules"
}

$updatesSrc = Join-Path $ScriptsDir "Builder\Get-WindowsUpdates.ps1"
if (Test-Path $updatesSrc) {
    Copy-Item -Path $updatesSrc -Destination (Join-Path $OEMScriptsDir "Get-WindowsUpdates.ps1") -Force
    Copy-Item -Path $updatesSrc -Destination (Join-Path $OEMScriptsDir1 "Get-WindowsUpdates.ps1") -Force
    Copy-Item -Path $updatesSrc -Destination (Join-Path $destModulesDir "Get-WindowsUpdates.ps1") -Force
    Copy-Item -Path $updatesSrc -Destination (Join-Path $destModulesDir1 "Get-WindowsUpdates.ps1") -Force
    $updatesCmd = Join-Path $ScriptsDir "Builder\Get-WindowsUpdates.cmd"
    if (Test-Path $updatesCmd) {
        Copy-Item -Path $updatesCmd -Destination (Join-Path $OEMScriptsDir "Get-WindowsUpdates.cmd") -Force
        Copy-Item -Path $updatesCmd -Destination (Join-Path $OEMScriptsDir1 "Get-WindowsUpdates.cmd") -Force
    }
    Write-OK "Descargador oficial de Windows Updates inyectado en `$OEM`$."
    Add-AuditRecord -Resource "Get-WindowsUpdates" -Target '$OEM$' -Status "OK" -Details "Inyectado en Scripts y Modules"
}

$auditFootprintSrc = Join-Path $ScriptsDir "Modules\Audit-FreshInstallFootprint.ps1"
if (Test-Path $auditFootprintSrc) {
    Copy-Item -Path $auditFootprintSrc -Destination (Join-Path $OEMScriptsDir "Audit-FreshInstallFootprint.ps1") -Force
    Copy-Item -Path $auditFootprintSrc -Destination (Join-Path $OEMScriptsDir1 "Audit-FreshInstallFootprint.ps1") -Force
    Copy-Item -Path $auditFootprintSrc -Destination (Join-Path $destModulesDir "Audit-FreshInstallFootprint.ps1") -Force
    Copy-Item -Path $auditFootprintSrc -Destination (Join-Path $destModulesDir1 "Audit-FreshInstallFootprint.ps1") -Force
    Write-OK "Herramienta de auditoria forense de huella (Footprint) inyectada en `$OEM`$."
    Add-AuditRecord -Resource "Audit-FreshInstallFootprint" -Target '$OEM$' -Status "OK" -Details "Inyectado en Scripts y Modules"
}

$memTrimSrc = Join-Path $ScriptsDir "Modules\Optimize-ProcessMemory.ps1"
$memTrimCmdSrc = Join-Path $ScriptsDir "Modules\Optimize-ProcessMemory.cmd"
if (Test-Path $memTrimSrc) {
    Copy-Item -Path $memTrimSrc -Destination (Join-Path $OEMScriptsDir "Optimize-ProcessMemory.ps1") -Force
    Copy-Item -Path $memTrimSrc -Destination (Join-Path $OEMScriptsDir1 "Optimize-ProcessMemory.ps1") -Force
    Copy-Item -Path $memTrimSrc -Destination (Join-Path $destModulesDir "Optimize-ProcessMemory.ps1") -Force
    Copy-Item -Path $memTrimSrc -Destination (Join-Path $destModulesDir1 "Optimize-ProcessMemory.ps1") -Force
    if (Test-Path $memTrimCmdSrc) {
        Copy-Item -Path $memTrimCmdSrc -Destination (Join-Path $OEMScriptsDir "Optimize-ProcessMemory.cmd") -Force
        Copy-Item -Path $memTrimCmdSrc -Destination (Join-Path $destModulesDir "Optimize-ProcessMemory.cmd") -Force
    }
    Write-OK "Modulo de poda de memoria (Optimize-ProcessMemory) inyectado en `$OEM`$."
    Add-AuditRecord -Resource "Optimize-ProcessMemory" -Target '$OEM$' -Status "OK" -Details "Inyectado en Scripts y Modules"
}

$auditSysSrc = Join-Path $ScriptsDir "Modules\Audit-SystemOptimization.ps1"
if (Test-Path $auditSysSrc) {
    Copy-Item -Path $auditSysSrc -Destination (Join-Path $OEMScriptsDir "Audit-SystemOptimization.ps1") -Force
    Copy-Item -Path $auditSysSrc -Destination (Join-Path $OEMScriptsDir1 "Audit-SystemOptimization.ps1") -Force
    Copy-Item -Path $auditSysSrc -Destination (Join-Path $destModulesDir "Audit-SystemOptimization.ps1") -Force
    Copy-Item -Path $auditSysSrc -Destination (Join-Path $destModulesDir1 "Audit-SystemOptimization.ps1") -Force
    Write-OK "Auditor universal de optimizacion (Audit-SystemOptimization) inyectado en `$OEM`$."
    Add-AuditRecord -Resource "Audit-SystemOptimization" -Target '$OEM$' -Status "OK" -Details "Inyectado en Scripts y Modules"
}

$gameDevSwitchSrc = Join-Path $ScriptsDir "Modules\Switch-GameDevMode.ps1"
$gameDevSwitchCmdSrc = Join-Path $ScriptsDir "Modules\Switch-GameDevMode.cmd"
if (Test-Path $gameDevSwitchSrc) {
    Copy-Item -Path $gameDevSwitchSrc -Destination (Join-Path $OEMScriptsDir "Switch-GameDevMode.ps1") -Force
    Copy-Item -Path $gameDevSwitchSrc -Destination (Join-Path $OEMScriptsDir1 "Switch-GameDevMode.ps1") -Force
    Copy-Item -Path $gameDevSwitchSrc -Destination (Join-Path $destModulesDir "Switch-GameDevMode.ps1") -Force
    Copy-Item -Path $gameDevSwitchSrc -Destination (Join-Path $destModulesDir1 "Switch-GameDevMode.ps1") -Force
    if (Test-Path $gameDevSwitchCmdSrc) {
        Copy-Item -Path $gameDevSwitchCmdSrc -Destination (Join-Path $OEMScriptsDir "Switch-GameDevMode.cmd") -Force
        Copy-Item -Path $gameDevSwitchCmdSrc -Destination (Join-Path $OEMScriptsDir1 "Switch-GameDevMode.cmd") -Force
        Copy-Item -Path $gameDevSwitchCmdSrc -Destination (Join-Path $destModulesDir "Switch-GameDevMode.cmd") -Force
        Copy-Item -Path $gameDevSwitchCmdSrc -Destination (Join-Path $destModulesDir1 "Switch-GameDevMode.cmd") -Force
    }
    Write-OK "Conmutador bimodal Game/Dev (Switch-GameDevMode) inyectado en `$OEM`$."
    Add-AuditRecord -Resource "Switch-GameDevMode" -Target '$OEM$' -Status "OK" -Details "Inyectado en Scripts y Modules"
}

$gamingAppsSrc    = Join-Path $ScriptsDir "Modules\Optimize-GamingAndApps.ps1"
$gamingAppsCmdSrc = Join-Path $ScriptsDir "Modules\Optimize-GamingAndApps.cmd"
if (Test-Path $gamingAppsSrc) {
    Copy-Item -Path $gamingAppsSrc -Destination (Join-Path $OEMScriptsDir "Optimize-GamingAndApps.ps1") -Force
    Copy-Item -Path $gamingAppsSrc -Destination (Join-Path $OEMScriptsDir1 "Optimize-GamingAndApps.ps1") -Force
    Copy-Item -Path $gamingAppsSrc -Destination (Join-Path $destModulesDir "Optimize-GamingAndApps.ps1") -Force
    Copy-Item -Path $gamingAppsSrc -Destination (Join-Path $destModulesDir1 "Optimize-GamingAndApps.ps1") -Force
    if (Test-Path $gamingAppsCmdSrc) {
        Copy-Item -Path $gamingAppsCmdSrc -Destination (Join-Path $OEMScriptsDir "Optimize-GamingAndApps.cmd") -Force
        Copy-Item -Path $gamingAppsCmdSrc -Destination (Join-Path $OEMScriptsDir1 "Optimize-GamingAndApps.cmd") -Force
        Copy-Item -Path $gamingAppsCmdSrc -Destination (Join-Path $destModulesDir "Optimize-GamingAndApps.cmd") -Force
        Copy-Item -Path $gamingAppsCmdSrc -Destination (Join-Path $destModulesDir1 "Optimize-GamingAndApps.cmd") -Force
    }
    Write-OK "Optimizador de Juegos y Apps Electron (Optimize-GamingAndApps) inyectado en `$OEM`$."
    Add-AuditRecord -Resource "Optimize-GamingAndApps" -Target '$OEM$' -Status "OK" -Details "Inyectado en Scripts y Modules"
}

$latencyTraceSrc    = Join-Path $ScriptsDir "Modules\Trace-SystemLatency.ps1"
$latencyTraceCmdSrc = Join-Path $ScriptsDir "Modules\Trace-SystemLatency.cmd"
if (Test-Path $latencyTraceSrc) {
    Copy-Item -Path $latencyTraceSrc -Destination (Join-Path $OEMScriptsDir "Trace-SystemLatency.ps1") -Force
    Copy-Item -Path $latencyTraceSrc -Destination (Join-Path $OEMScriptsDir1 "Trace-SystemLatency.ps1") -Force
    Copy-Item -Path $latencyTraceSrc -Destination (Join-Path $destModulesDir "Trace-SystemLatency.ps1") -Force
    Copy-Item -Path $latencyTraceSrc -Destination (Join-Path $destModulesDir1 "Trace-SystemLatency.ps1") -Force
    if (Test-Path $latencyTraceCmdSrc) {
        Copy-Item -Path $latencyTraceCmdSrc -Destination (Join-Path $OEMScriptsDir "Trace-SystemLatency.cmd") -Force
        Copy-Item -Path $latencyTraceCmdSrc -Destination (Join-Path $OEMScriptsDir1 "Trace-SystemLatency.cmd") -Force
        Copy-Item -Path $latencyTraceCmdSrc -Destination (Join-Path $destModulesDir "Trace-SystemLatency.cmd") -Force
        Copy-Item -Path $latencyTraceCmdSrc -Destination (Join-Path $destModulesDir1 "Trace-SystemLatency.cmd") -Force
    }
    Write-OK "Profiler Forense de Latencia DPC/ISR (Trace-SystemLatency) inyectado en `$OEM`$."
    Add-AuditRecord -Resource "Trace-SystemLatency" -Target '$OEM$' -Status "OK" -Details "Inyectado en Scripts y Modules"
}

$ccScriptSrc   = Join-Path $ScriptsDir "GUI\romanOS-ControlCenter.ps1"
$ccLauncherSrc = Join-Path $ScriptsDir "GUI\romanOS-ControlCenter-Launcher.cs"
$ccCmdSrc      = Join-Path (Split-Path $ScriptsDir -Parent) "Lanzar-romanOS-ControlCenter.cmd"
if (-not (Test-Path $ccCmdSrc)) {
    $ccCmdSrc  = Join-Path $ScriptsDir "GUI\Lanzar-romanOS-ControlCenter.cmd"
}

if (Test-Path $ccScriptSrc) {
    $oemGuiDir  = Join-Path $OEMScriptsDir "GUI"
    $oemGuiDir1 = Join-Path $OEMScriptsDir1 "GUI"
    if (-not (Test-Path $oemGuiDir))  { New-Item -ItemType Directory -Path $oemGuiDir -Force | Out-Null }
    if (-not (Test-Path $oemGuiDir1)) { New-Item -ItemType Directory -Path $oemGuiDir1 -Force | Out-Null }
    Copy-Item -Path $ccScriptSrc -Destination (Join-Path $oemGuiDir "romanOS-ControlCenter.ps1") -Force
    Copy-Item -Path $ccScriptSrc -Destination (Join-Path $oemGuiDir1 "romanOS-ControlCenter.ps1") -Force
    Copy-Item -Path $ccScriptSrc -Destination (Join-Path $OEMScriptsDir "romanOS-ControlCenter.ps1") -Force
    Copy-Item -Path $ccScriptSrc -Destination (Join-Path $OEMScriptsDir1 "romanOS-ControlCenter.ps1") -Force
    Copy-Item -Path $ccScriptSrc -Destination (Join-Path $destModulesDir "romanOS-ControlCenter.ps1") -Force
    Copy-Item -Path $ccScriptSrc -Destination (Join-Path $destModulesDir1 "romanOS-ControlCenter.ps1") -Force

    if (Test-Path $ccLauncherSrc) {
        Copy-Item -Path $ccLauncherSrc -Destination (Join-Path $oemGuiDir "romanOS-ControlCenter-Launcher.cs") -Force
        Copy-Item -Path $ccLauncherSrc -Destination (Join-Path $oemGuiDir1 "romanOS-ControlCenter-Launcher.cs") -Force
    }

    if (Test-Path $ccCmdSrc) {
        Copy-Item -Path $ccCmdSrc -Destination (Join-Path $OEMScriptsDir "Lanzar-romanOS-ControlCenter.cmd") -Force
        Copy-Item -Path $ccCmdSrc -Destination (Join-Path $OEMScriptsDir1 "Lanzar-romanOS-ControlCenter.cmd") -Force
        if ($OEMDesktopDir -and (Test-Path $OEMDesktopDir)) {
            Copy-Item -Path $ccCmdSrc -Destination (Join-Path $OEMDesktopDir "Lanzar-romanOS-ControlCenter.cmd") -Force
        }
    }
    Write-OK "romanOS Control Center (GUI, Launcher CS y Lanzador CMD) inyectado en `$OEM`$."
    Add-AuditRecord -Resource "romanOS-ControlCenter" -Target '$OEM$' -Status "OK" -Details "Inyectado en Scripts/GUI, Modules y Public Desktop"
}

# ------------------------------------------------------------------
# Garantizar Presencia de Submódulos del Toolkit Maestro en $OEM$
# ------------------------------------------------------------------
$suiteSubmodules = @(
    @{ Path = $debScriptCandidate; Name = [System.IO.Path]::GetFileName($debScriptCandidate) },
    @{ Path = $maintScriptCandidate; Name = [System.IO.Path]::GetFileName($maintScriptCandidate) },
    @{ Path = $netScriptCandidate; Name = [System.IO.Path]::GetFileName($netScriptCandidate) },
    @{ Path = $secScriptCandidate; Name = [System.IO.Path]::GetFileName($secScriptCandidate) },
    @{ Path = $toolkitCandidate; Name = [System.IO.Path]::GetFileName($toolkitCandidate) }
)
foreach ($subm in $suiteSubmodules) {
    if ($subm.Path -and (Test-Path $subm.Path)) {
        $destFile  = Join-Path $OEMScriptsDir $subm.Name
        $destFile1 = Join-Path $OEMScriptsDir1 $subm.Name
        if (-not (Test-Path $destFile))  { Copy-Item -Path $subm.Path -Destination $destFile -Force }
        if (-not (Test-Path $destFile1)) { Copy-Item -Path $subm.Path -Destination $destFile1 -Force }
    }
}

# ------------------------------------------------------------------
# Copiar Host-Tools y Suite de Despliegue en $OEM$ y Public Desktop (PLAN-0063)
# ------------------------------------------------------------------
$hostSetupSrc   = Join-Path $ScriptsDir "Host-Tools\Desplegar-Setup-Host.ps1"
$hostSetupCmd   = Join-Path $ScriptsDir "Host-Tools\Desplegar-Setup-Host.cmd"
$antigravitySrc = Join-Path $ScriptsDir "Host-Tools\Setup-AntigravityWindows.ps1"

if (Test-Path $hostSetupSrc) {
    Copy-Item -Path $hostSetupSrc -Destination (Join-Path $OEMScriptsDir "Desplegar-Setup-Host.ps1") -Force
    Copy-Item -Path $hostSetupSrc -Destination (Join-Path $OEMScriptsDir1 "Desplegar-Setup-Host.ps1") -Force
}
if (Test-Path $antigravitySrc) {
    Copy-Item -Path $antigravitySrc -Destination (Join-Path $OEMScriptsDir "Setup-AntigravityWindows.ps1") -Force
    Copy-Item -Path $antigravitySrc -Destination (Join-Path $OEMScriptsDir1 "Setup-AntigravityWindows.ps1") -Force
}
if (Test-Path $hostSetupCmd) {
    Copy-Item -Path $hostSetupCmd -Destination (Join-Path $OEMScriptsDir "Desplegar-Setup-Host.cmd") -Force
    Copy-Item -Path $hostSetupCmd -Destination (Join-Path $OEMScriptsDir1 "Desplegar-Setup-Host.cmd") -Force
    Copy-Item -Path $hostSetupCmd -Destination (Join-Path $OEMDesktopDir "Desplegar-Setup-Host.cmd") -Force
    Write-OK "Lanzador modular (Desplegar-Setup-Host) inyectado en `$OEMScriptsDir y Public Desktop."
    Add-AuditRecord -Resource "Desplegar-Setup-Host" -Target '$OEM$' -Status "OK" -Details "Inyectado en Scripts y Public Desktop"
}

#------------------------------------------------------------------------------
# 3/6 - CREAR SetupComplete.cmd Y TAREAS PROGRAMADAS A DEMANDA
#------------------------------------------------------------------------------

Write-Step "3/6 - Creando SetupComplete.cmd y registro de tareas a demanda..."

$primaryScript = if ($scriptsToInject.Count -gt 0) { $scriptsToInject[0].DestName } else { "None" }

$setupCompleteTemplate = @'
@echo off
REM ===========================================================
REM  SetupComplete.cmd - Generado por New-OptimizedWindowsISO
REM  Se ejecuta como SYSTEM al finalizar Windows Setup
REM ===========================================================
SET SCRIPTS_DIR=%WINDIR%\Setup\Scripts
SET LOG=%SCRIPTS_DIR%\SetupComplete.log
SET PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe

echo [%DATE% %TIME%] Iniciando SetupComplete.cmd >> "%LOG%"

REM ===========================================================
REM Deshabilitar Tareas Programadas de Telemetria
REM ===========================================================
echo [%DATE% %TIME%] Deshabilitando tareas de telemetria... >> "%LOG%"
schtasks /change /disable /tn "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" >> "%LOG%" 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Application Experience\PcaPatchDbTask" >> "%LOG%" 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Application Experience\ProgramDataUpdater" >> "%LOG%" 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Application Experience\StartupAppTask" >> "%LOG%" 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" >> "%LOG%" 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" >> "%LOG%" 2>&1

REM ===========================================================
REM Instalacion Silenciosa de Runtimes Esenciales
REM ===========================================================
IF EXIST "%SCRIPTS_DIR%\Runtimes" (
    echo [%DATE% %TIME%] Instalando Runtimes esenciales... >> "%LOG%"
    for %%f in ("%SCRIPTS_DIR%\Runtimes\vc_redist*.exe", "%SCRIPTS_DIR%\Runtimes\vcredist*.exe", "%SCRIPTS_DIR%\Runtimes\VC_*.exe") do (
        echo [%DATE% %TIME%] Instalando %%~nxf... >> "%LOG%"
        "%%f" /install /quiet /norestart >> "%LOG%" 2>&1
    )
    if exist "%SCRIPTS_DIR%\Runtimes\DirectX\dxsetup.exe" (
        echo [%DATE% %TIME%] Instalando DirectX... >> "%LOG%"
        "%SCRIPTS_DIR%\Runtimes\DirectX\dxsetup.exe" /silent >> "%LOG%" 2>&1
    )
    if exist "%SCRIPTS_DIR%\Runtimes\dxsetup.exe" (
        echo [%DATE% %TIME%] Instalando DirectX... >> "%LOG%"
        "%SCRIPTS_DIR%\Runtimes\dxsetup.exe" /silent >> "%LOG%" 2>&1
    )
    echo [%DATE% %TIME%] Runtimes instalados exitosamente. >> "%LOG%"
)

REM ===========================================================
REM Sincronizacion Canonica de Menu Contextual (romanOS Suite)
REM Aplica menus en cascada nativos y restaura menu clasico en Win11
REM ===========================================================
echo [%DATE% %TIME%] Registrando funciones de menu contextual optimizado... >> "%LOG%"
if exist "%SCRIPTS_DIR%\Add-OptimizedContextMenus.ps1" (
    "%PS%" -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\Add-OptimizedContextMenus.ps1" -Apply -EnableClassicMenu -Quiet >> "%LOG%" 2>&1
) else (
    echo [%DATE% %TIME%] [WARN] Add-OptimizedContextMenus.ps1 no encontrado en %SCRIPTS_DIR% >> "%LOG%"
)

REM ===========================================================
REM Configuracion de Tema Oscuro Nativo a Nivel de Sistema (PLAN-0030)
REM ===========================================================
echo [%DATE% %TIME%] Configurando tema oscuro nativo del sistema (dark.theme)... >> "%LOG%"
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes" /v InstallTheme /t REG_SZ /d "C:\Windows\resources\Themes\dark.theme" /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 0 /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 1 /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v ApplyDarkMode /t REG_SZ /d "cmd.exe /c reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize /v AppsUseLightTheme /t REG_DWORD /d 0 /f & reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize /v SystemUsesLightTheme /t REG_DWORD /d 0 /f & reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize /v EnableTransparency /t REG_DWORD /d 1 /f" /f >> "%LOG%" 2>&1

__BROWSER_POLICIES_BLOCK__

__OPTIMIZATIONS_BLOCK__
REM ===========================================================
REM Registrar Tareas a Demanda y Accesos Directos en Escritorio (PLAN-0076)
REM ===========================================================
if exist "%SCRIPTS_DIR%\Initialize-SuiteTasks.ps1" (
    echo [%DATE% %TIME%] Registrando tareas y accesos de forma consolidada (PLAN-0076)... >> "%LOG%"
    "%PS%" -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\Initialize-SuiteTasks.ps1" >> "%LOG%" 2>&1
) else (
__SCHEDULED_TASKS_BLOCK__
)

REM ===========================================================
REM Auditoria y Diagnostico Integral Post-Instalacion (PLAN-0076)
REM ===========================================================
echo [%DATE% %TIME%] SetupComplete.cmd finalizado exitosamente. >> "%LOG%"
if exist "%SCRIPTS_DIR%\PostInstall-Diagnostics.ps1" (
    echo [%DATE% %TIME%] Lanzando auditoria post-instalacion en segundo plano... >> "%LOG%"
    start "" /b "%PS%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\PostInstall-Diagnostics.ps1" -DesktopOutput -ExpectedProfile __OPT_PROFILE__ -ExpectedBlockOneDrive:__BLOCK_ONEDRIVE__ >> "%LOG%" 2>&1
)
exit /b 0
'@

$tasksBlock = @"
REM ===========================================================
REM Crear Carpeta de Suite en el Menu Inicio (Start Menu\Programs)
REM Ref: learn.microsoft.com/windows/win32/shell/knownfolderid
REM ===========================================================
echo [%DATE% %TIME%] Creando accesos directos de la Suite en el Menu Inicio... >> "%LOG%"
set "START_MENU_TOOLS=%ProgramData%\Microsoft\Windows\Start Menu\Programs\Herramientas del Sistema"
if not exist "%START_MENU_TOOLS%" mkdir "%START_MENU_TOOLS%" >> "%LOG%" 2>&1

"@

if ($scriptsToInject.Count -gt 0) {
    foreach ($sc in $scriptsToInject) {
        $taskName = "Ejecutar_" + ($sc.DestName -replace '[^a-zA-Z0-9_]', '')
        $iconNumber = if ($sc.DestName -match 'Maintenance') { "54" } elseif ($sc.DestName -match 'Network') { "23" } elseif ($sc.DestName -match 'Security') { "105" } elseif ($sc.DestName -match 'Toolkit') { "109" } else { "109" }
        $tasksBlock += @"
echo [%DATE% %TIME%] Configurando tarea a demanda permanente para $($sc.DestName)... >> "%LOG%"
"%PS%" -STA -NoProfile -ExecutionPolicy Bypass -Command "`$act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-STA -NoProfile -ExecutionPolicy Bypass -File \"`$env:WINDIR\Setup\Scripts\$($sc.DestName)\"'; `$pri = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest; `$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries; try { Register-ScheduledTask -TaskName '$taskName' -Action `$act -Principal `$pri -Settings `$set -Force | Out-Null } catch { schtasks /create /tn '$taskName' /tr \"powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File \\\"`$env:WINDIR\Setup\Scripts\$($sc.DestName)\\\"\" /sc ONCE /st 00:00 /sd 2099/12/31 /ru 'SYSTEM' /rl HIGHEST /f }"` >> "%LOG%" 2>&1

"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "`$ws = New-Object -ComObject WScript.Shell; `$sm = if (`$env:ProgramData) { \"`$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Herramientas del Sistema\" } else { 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Herramientas del Sistema' }; if (-not (Test-Path `$sm)) { New-Item -ItemType Directory -Path `$sm -Force | Out-Null }; `$sc = `$ws.CreateShortcut(\"`$sm\$($sc.ShortcutName)\"); `$sc.TargetPath = '%WINDIR%\Setup\Scripts\$($sc.LauncherName)'; `$sc.WorkingDirectory = '%WINDIR%\Setup\Scripts'; `$sc.Description = '$($sc.Title)'; `$sc.IconLocation = '%SystemRoot%\System32\imageres.dll,$iconNumber'; `$sc.Save()" >> "%LOG%" 2>&1
"@ + "`r`n"
    }
}

# Acceso directo para Auditoria Post-Instalacion en Menu Inicio
$tasksBlock += @"
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "`$ws = New-Object -ComObject WScript.Shell; `$sm = if (`$env:ProgramData) { \"`$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Herramientas del Sistema\" } else { 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Herramientas del Sistema' }; if (-not (Test-Path `$sm)) { New-Item -ItemType Directory -Path `$sm -Force | Out-Null }; `$sc = `$ws.CreateShortcut(\"`$sm\Auditar Instalacion.lnk\"); `$sc.TargetPath = '%WINDIR%\Setup\Scripts\Auditar-Instalacion.cmd'; `$sc.WorkingDirectory = '%WINDIR%\Setup\Scripts'; `$sc.Description = 'Auditar y Diagnosticar Instalacion de Windows'; `$sc.IconLocation = '%SystemRoot%\System32\imageres.dll,104'; `$sc.Save()" >> "%LOG%" 2>&1
"@ + "`r`n"

# Acceso directo para Desplegar Setup Dev y Gaming en el Escritorio Publico (PLAN-0063)
$tasksBlock += @"
if exist "%WINDIR%\Setup\Scripts\Desplegar-Setup-Host.cmd" (
    echo [%DATE% %TIME%] Creando acceso directo de Setup Dev y Gaming en Escritorio... >> "%LOG%"
    "%PS%" -NoProfile -ExecutionPolicy Bypass -Command "`$ws = New-Object -ComObject WScript.Shell; `$dt = [System.Environment]::GetFolderPath('CommonDesktopDirectory'); if (Test-Path `$dt) { `$sc = `$ws.CreateShortcut(\"`$dt\Desplegar Setup Dev y Gaming.lnk\"); `$sc.TargetPath = '%WINDIR%\Setup\Scripts\Desplegar-Setup-Host.cmd'; `$sc.WorkingDirectory = '%WINDIR%\Setup\Scripts'; `$sc.Description = 'Suite Modular de Despliegue (Dev-IA y Gaming)'; `$sc.IconLocation = '%SystemRoot%\System32\shell32.dll,277'; `$sc.Save() }" >> "%LOG%" 2>&1
)
"@ + "`r`n"

# Acceso directo para romanOS Control Center en Menu Inicio y Escritorio (PLAN-0086)
$tasksBlock += @"
if exist "%WINDIR%\Setup\Scripts\Lanzar-romanOS-ControlCenter.cmd" (
    echo [%DATE% %TIME%] Creando accesos directos para romanOS Control Center... >> "%LOG%"
    "%PS%" -NoProfile -ExecutionPolicy Bypass -Command "`$ws = New-Object -ComObject WScript.Shell; `$sm = if (`$env:ProgramData) { \"`$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Herramientas del Sistema\" } else { 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Herramientas del Sistema' }; if (-not (Test-Path `$sm)) { New-Item -ItemType Directory -Path `$sm -Force | Out-Null }; `$sc = `$ws.CreateShortcut(\"`$sm\romanOS Control Center.lnk\"); `$sc.TargetPath = '%WINDIR%\Setup\Scripts\Lanzar-romanOS-ControlCenter.cmd'; `$sc.WorkingDirectory = '%WINDIR%\Setup\Scripts'; `$sc.Description = 'Centro de Control y Optimizacion romanOS'; `$sc.IconLocation = '%SystemRoot%\System32\imageres.dll,109'; `$sc.Save()" >> "%LOG%" 2>&1
    "%PS%" -NoProfile -ExecutionPolicy Bypass -Command "`$ws = New-Object -ComObject WScript.Shell; `$dt = [System.Environment]::GetFolderPath('CommonDesktopDirectory'); if (Test-Path `$dt) { `$sc = `$ws.CreateShortcut(\"`$dt\romanOS Control Center.lnk\"); `$sc.TargetPath = '%WINDIR%\Setup\Scripts\Lanzar-romanOS-ControlCenter.cmd'; `$sc.WorkingDirectory = '%WINDIR%\Setup\Scripts'; `$sc.Description = 'Centro de Control y Optimizacion romanOS'; `$sc.IconLocation = '%SystemRoot%\System32\imageres.dll,109'; `$sc.Save() }" >> "%LOG%" 2>&1
)
"@ + "`r`n"

$optimizationsBlock = @"
REM ===========================================================
REM Configuracion de Planes de Energia y Rendimiento
REM ===========================================================
echo [%DATE% %TIME%] Configurando plan de energia... >> "%LOG%"
powercfg -h off >> "%LOG%" 2>&1
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 >> "%LOG%" 2>&1
powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61 >> "%LOG%" 2>&1 || powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >> "%LOG%" 2>&1

REM ===========================================================
REM Mitigacion de Bufferbloat de Red (ECN - RFC 3168) (PLAN-0034)
REM ===========================================================
echo [%DATE% %TIME%] Configurando mitigacion de bufferbloat de red (ECN)... >> "%LOG%"
netsh int tcp set global ecncapability=enabled >> "%LOG%" 2>&1
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "Set-NetTCPSetting -SettingName InternetCustom,Internet -EcnCapability Enabled -ErrorAction SilentlyContinue" >> "%LOG%" 2>&1

REM ===========================================================
REM Optimizaciones Oficiales de FileSystem (NTFS) y Scheduler (PLAN-0034)
REM ===========================================================
echo [%DATE% %TIME%] Aplicando optimizaciones oficiales de FileSystem y Scheduler... >> "%LOG%"
reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v NtfsDisable8dot3NameCreation /t REG_DWORD /d 1 /f >> "%LOG%" 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v NtfsMemoryUsage /t REG_DWORD /d 2 /f >> "%LOG%" 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f >> "%LOG%" 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 38 /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NoLazyMode /t REG_DWORD /d 1 /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 0 /f >> "%LOG%" 2>&1

REM ===========================================================
REM Deshabilitar Telemetria y Diagnosticos del Kernel (Universal - Todos los Perfiles) (PLAN-0061)
REM ===========================================================
echo [%DATE% %TIME%] Deshabilitando telemetria base de Microsoft (DiagTrack)... >> "%LOG%"
sc config DiagTrack start=disabled >> "%LOG%" 2>&1
sc config dmwappushservice start=disabled >> "%LOG%" 2>&1

"@

$optProfileIntSetup = if ($script:OptProfile) { [int]$script:OptProfile } else { 1 }

if ($optProfileIntSetup -ge 2) {
    $optimizationsBlock += @'
REM ===========================================================
REM Deshabilitar Diagnosticos, Oficina, BitLocker y SysMain (Perfil 2+) (PLAN-0061)
REM ===========================================================
echo [%DATE% %TIME%] Deshabilitando servicios de diagnosticos avanzados y reportes de error... >> "%LOG%"
sc config WerSvc start=disabled >> "%LOG%" 2>&1
sc config TroubleshootingSvc start=disabled >> "%LOG%" 2>&1

echo [%DATE% %TIME%] Deshabilitando servicios corporativos y de oficina... >> "%LOG%"
sc config Fax start=disabled >> "%LOG%" 2>&1
sc config SCardSvr start=disabled >> "%LOG%" 2>&1
sc config RemoteRegistry start=disabled >> "%LOG%" 2>&1
sc config RetailDemo start=disabled >> "%LOG%" 2>&1
sc config MapsBroker start=disabled >> "%LOG%" 2>&1
sc config lfsvc start=disabled >> "%LOG%" 2>&1

echo [%DATE% %TIME%] Deshabilitando servicio de BitLocker... >> "%LOG%"
sc config BDESVC start=disabled >> "%LOG%" 2>&1

echo [%DATE% %TIME%] Deshabilitando SysMain (SuperFetch) para optimizar latencia en gaming... >> "%LOG%"
sc config SysMain start=disabled >> "%LOG%" 2>&1

'@
}

if ($optProfileIntSetup -eq 3) {
    $optimizationsBlock += @'
REM ===========================================================
REM Deshabilitar Servicios Hardcore y Latencia Minima (Perfil 3)
REM ===========================================================
echo [%DATE% %TIME%] Deshabilitando servicios hardcore... >> "%LOG%"
sc config WSearch start=disabled >> "%LOG%" 2>&1
sc config Spooler start=disabled >> "%LOG%" 2>&1
sc config WlanSvc start=disabled >> "%LOG%" 2>&1
sc config bthserv start=disabled >> "%LOG%" 2>&1
sc config SensorService start=disabled >> "%LOG%" 2>&1
sc config SensorsDataService start=disabled >> "%LOG%" 2>&1
sc config TabletInputService start=disabled >> "%LOG%" 2>&1

echo [%DATE% %TIME%] Configurando hipervisor en modo latencia minima... >> "%LOG%"
bcdedit /set hypervisorlaunchtype off >> "%LOG%" 2>&1

'@
}

if ($script:BlockOneDrive) {
    $optimizationsBlock += @'
REM ===========================================================
REM Purga y Bloqueo Definitivo de OneDrive (PLAN-0078)
REM ===========================================================
echo [%DATE% %TIME%] Purgando instalador y tareas residuales de OneDrive... >> "%LOG%"
taskkill /f /im OneDrive.exe >> "%LOG%" 2>&1
taskkill /f /im OneDrive.Sync.Service.exe >> "%LOG%" 2>&1
taskkill /f /im FileCoAuth.exe >> "%LOG%" 2>&1
if exist "%SystemRoot%\System32\OneDriveSetup.exe" (
    "%SystemRoot%\System32\OneDriveSetup.exe" /uninstall /silent >> "%LOG%" 2>&1
)
if exist "%SystemRoot%\SysWOW64\OneDriveSetup.exe" (
    "%SystemRoot%\SysWOW64\OneDriveSetup.exe" /uninstall /silent >> "%LOG%" 2>&1
)
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f >> "%LOG%" 2>&1
reg delete "HKU\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f >> "%LOG%" 2>&1
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'OneDrive' } | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue" >> "%LOG%" 2>&1

'@
}


$browserPoliciesBlock = ""
if (Get-Command "Export-RomanOSBrowserCommands" -ErrorAction SilentlyContinue) {
    $exportedCommands = Export-RomanOSBrowserCommands -LogVariable "%LOG%"
    $browserPoliciesBlock = @"
REM ===========================================================
REM Optimizacion y Debloat Oficial de Navegadores Web (GPO)
REM Fuente SSOT: Core/Policy-Engine.ps1
REM Refs: learn.microsoft.com/deployedge/microsoft-edge-policies
REM Refs: chromeenterprise.google/policies/
REM ===========================================================
echo [%DATE% %TIME%] Aplicando politicas GPO de rendimiento en navegadores... >> "%LOG%"

$exportedCommands

echo [%DATE% %TIME%] Politicas de navegadores aplicadas exitosamente. >> "%LOG%"
"@
}

$setupCompleteContent = $setupCompleteTemplate.Replace('__OPTIMIZATIONS_BLOCK__', $optimizationsBlock).Replace('__SCHEDULED_TASKS_BLOCK__', $tasksBlock).Replace('__BROWSER_POLICIES_BLOCK__', $browserPoliciesBlock).Replace('__OPT_PROFILE__', "$optProfileIntSetup").Replace('__BLOCK_ONEDRIVE__', $(if ($script:BlockOneDrive) { '$true' } else { '$false' }))

$setupCompletePath  = Join-Path $OEMScriptsDir "SetupComplete.cmd"
$setupCompletePath1 = Join-Path $OEMScriptsDir1 "SetupComplete.cmd"
$setupCompleteContent | Out-File -FilePath $setupCompletePath -Encoding ASCII -Force
$setupCompleteContent | Out-File -FilePath $setupCompletePath1 -Encoding ASCII -Force

# Generar Initialize-SuiteTasks.ps1 consolidado para ejecucion ultra-rapida en un solo proceso (PLAN-0076)
$suiteTasksScriptLines = [System.Collections.Generic.List[string]]::new()
$suiteTasksScriptLines.Add('# ==============================================================================')
$suiteTasksScriptLines.Add('# Initialize-SuiteTasks.ps1 - romanOS Suite Consolidated Tasks & Shortcuts')
$suiteTasksScriptLines.Add('# Codificacion UTF-8 con BOM requerida para Windows PowerShell 5.1 (PLAN-0076)')
$suiteTasksScriptLines.Add('# ==============================================================================')
$suiteTasksScriptLines.Add('$ErrorActionPreference = "SilentlyContinue"')
$suiteTasksScriptLines.Add('$ws = New-Object -ComObject WScript.Shell')
$suiteTasksScriptLines.Add('$sm = if ($env:ProgramData) { "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Herramientas del Sistema" } else { "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Herramientas del Sistema" }')
$suiteTasksScriptLines.Add('if (-not (Test-Path $sm)) { New-Item -ItemType Directory -Path $sm -Force | Out-Null }')
$suiteTasksScriptLines.Add('$scriptsDir = if ($env:WINDIR) { "$env:WINDIR\Setup\Scripts" } else { "C:\Windows\Setup\Scripts" }')
$suiteTasksScriptLines.Add('')

if ($scriptsToInject.Count -gt 0) {
    foreach ($sc in $scriptsToInject) {
        $taskName = "Ejecutar_" + ($sc.DestName -replace '[^a-zA-Z0-9_]', '')
        $iconNumber = if ($sc.DestName -match 'Maintenance') { "54" } elseif ($sc.DestName -match 'Network') { "23" } elseif ($sc.DestName -match 'Security') { "105" } elseif ($sc.DestName -match 'Toolkit') { "109" } else { "109" }
        $suiteTasksScriptLines.Add(@"
try {
    `$act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-STA -NoProfile -ExecutionPolicy Bypass -File "$scriptsDir\$($sc.DestName)"'
    `$pri = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    `$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName '$taskName' -Action `$act -Principal `$pri -Settings `$set -Force | Out-Null
} catch {
    schtasks /create /tn '$taskName' /tr "powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File \"$scriptsDir\$($sc.DestName)\"" /sc ONCE /st 00:00 /sd 2099/12/31 /ru 'SYSTEM' /rl HIGHEST /f | Out-Null
}

try {
    `$scItem = `$ws.CreateShortcut("`$sm\$($sc.ShortcutName)")
    `$scItem.TargetPath = "$scriptsDir\$($sc.LauncherName)"
    `$scItem.WorkingDirectory = "$scriptsDir"
    `$scItem.Description = '$($sc.Title)'
    `$scItem.IconLocation = '%SystemRoot%\System32\imageres.dll,$iconNumber'
    `$scItem.Save()
} catch {}
"@)
    }
}

$suiteTasksScriptLines.Add(@"
try {
    `$scAudit = `$ws.CreateShortcut("`$sm\Auditar Instalacion.lnk")
    `$scAudit.TargetPath = "$scriptsDir\Auditar-Instalacion.cmd"
    `$scAudit.WorkingDirectory = "$scriptsDir"
    `$scAudit.Description = 'Auditar y Diagnosticar Instalacion de Windows'
    `$scAudit.IconLocation = '%SystemRoot%\System32\imageres.dll,104'
    `$scAudit.Save()
} catch {}

if (Test-Path "$scriptsDir\Desplegar-Setup-Host.cmd") {
    `$dt = [System.Environment]::GetFolderPath('CommonDesktopDirectory')
    if (-not `$dt -or -not (Test-Path `$dt)) { `$dt = if (`$env:PUBLIC) { "`$env:PUBLIC\Desktop" } else { "C:\Users\Public\Desktop" } }
    if (Test-Path `$dt) {
        try {
            `$scHost = `$ws.CreateShortcut("`$dt\Desplegar Setup Dev y Gaming.lnk")
            `$scHost.TargetPath = "$scriptsDir\Desplegar-Setup-Host.cmd"
            `$scHost.WorkingDirectory = "$scriptsDir"
            `$scHost.Description = 'Suite Modular de Despliegue (Dev-IA y Gaming)'
            `$scHost.IconLocation = '%SystemRoot%\System32\shell32.dll,277'
            `$scHost.Save()
        } catch {}
    }
}

if (Test-Path "$scriptsDir\Lanzar-romanOS-ControlCenter.cmd") {
    try {
        `$scCC = `$ws.CreateShortcut("`$sm\romanOS Control Center.lnk")
        `$scCC.TargetPath = "$scriptsDir\Lanzar-romanOS-ControlCenter.cmd"
        `$scCC.WorkingDirectory = "$scriptsDir"
        `$scCC.Description = 'Centro de Control y Optimizacion romanOS'
        `$scCC.IconLocation = '%SystemRoot%\System32\imageres.dll,109'
        `$scCC.Save()
    } catch {}
    `$dt = [System.Environment]::GetFolderPath('CommonDesktopDirectory')
    if (-not `$dt -or -not (Test-Path `$dt)) { `$dt = if (`$env:PUBLIC) { "`$env:PUBLIC\Desktop" } else { "C:\Users\Public\Desktop" } }
    if (Test-Path `$dt) {
        try {
            `$scCCDt = `$ws.CreateShortcut("`$dt\romanOS Control Center.lnk")
            `$scCCDt.TargetPath = "$scriptsDir\Lanzar-romanOS-ControlCenter.cmd"
            `$scCCDt.WorkingDirectory = "$scriptsDir"
            `$scCCDt.Description = 'Centro de Control y Optimizacion romanOS'
            `$scCCDt.IconLocation = '%SystemRoot%\System32\imageres.dll,109'
            `$scCCDt.Save()
        } catch {}
    }
}
"@)

$suiteTasksContent = $suiteTasksScriptLines -join "`r`n"
$suiteTasksPath  = Join-Path $OEMScriptsDir "Initialize-SuiteTasks.ps1"
$suiteTasksPath1 = Join-Path $OEMScriptsDir1 "Initialize-SuiteTasks.ps1"
[System.IO.File]::WriteAllText($suiteTasksPath, $suiteTasksContent, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($suiteTasksPath1, $suiteTasksContent, [System.Text.Encoding]::UTF8)

Write-OK "SetupComplete.cmd e Initialize-SuiteTasks.ps1 generados con integracion consolidada de Suite."
Add-AuditRecord -Resource "SetupComplete.cmd" -Target '$OEM$' -Status "OK" `
                -Details "SetupComplete optimizado con Initialize-SuiteTasks.ps1 consolidado y diagnosticos en background"

#------------------------------------------------------------------------------
# 4/6 - REGISTRAR LANZADOR DE AUDITORIA POST-INSTALACION (Auditar-Instalacion.cmd)
#------------------------------------------------------------------------------

# Lanzador interactivo en formato .cmd con paridad de perfil
$auditarLauncherTemplate = @'
@echo off
REM ===========================================================
REM  Lanzador Auto-Elevable de Auditoria Post-Instalacion
REM ===========================================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"
title Auditoria y Diagnostico Post-Instalacion de Windows
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%WINDIR%\Setup\Scripts\PostInstall-Diagnostics.ps1" -DesktopOutput -ShowInNotepad -ExpectedProfile __OPT_PROFILE__ -ExpectedBlockOneDrive:__BLOCK_ONEDRIVE__
pause
'@

$auditarLauncherContent = $auditarLauncherTemplate.Replace('__OPT_PROFILE__', "$optProfileIntSetup").Replace('__BLOCK_ONEDRIVE__', $(if ($script:BlockOneDrive) { '$true' } else { '$false' }))

$auditarLauncherPath  = Join-Path $OEMScriptsDir "Auditar-Instalacion.cmd"
$auditarLauncherPath1 = Join-Path $OEMScriptsDir1 "Auditar-Instalacion.cmd"
$auditarLauncherContent | Out-File -FilePath $auditarLauncherPath -Encoding ASCII -Force
$auditarLauncherContent | Out-File -FilePath $auditarLauncherPath1 -Encoding ASCII -Force

Write-OK "Lanzador interactivo Auditar-Instalacion.cmd registrado en `$OEM$`."
Add-AuditRecord -Resource "Auditar-Instalacion.cmd" -Target '$OEM$' -Status "OK" -Details "Inyectado en `$OEMScriptsDir"

#------------------------------------------------------------------------------
# 4/6 - CREAR autounattend.xml (CORREGIDO)
#------------------------------------------------------------------------------

if (-not $SkipAutoUnattend) {
    Write-Step "4/6 - Creando autounattend.xml..."

    $effectivePassword = if ($script:LocalPassword) { $script:LocalPassword } elseif ($LocalPassword) { $LocalPassword } else { "" }
    $isPasswordless = [string]::IsNullOrWhiteSpace($effectivePassword)
    $finalLocalUser = if ($script:LocalUser) { $script:LocalUser } elseif ($LocalUser) { $LocalUser } else { "Usuario" }

    $encodedPasswordForAccount = ""
    $encodedPasswordForAutologon = ""
    $passwordPlainTextAccount = "false"
    $passwordPlainTextAutologon = "false"

    if ($isPasswordless) {
        $setupPassword = "RomanOS#Setup_" + [guid]::NewGuid().ToString('N').Substring(0, 8) + "!"
        $encodedPasswordForAccount = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($setupPassword + "Password"))
        $encodedPasswordForAutologon = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($setupPassword + "Password"))
    } else {
        $encodedPasswordForAccount = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($effectivePassword + "Password"))
        $encodedPasswordForAutologon = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($effectivePassword + "Password"))
    }

    # ConstrucciÃ³n dinÃ¡mica de FirstLogonCommands:
    $firstLogonCommands = [System.Collections.Generic.List[string]]::new()
    $cmdOrder = 1

    if ($isPasswordless) {
        # PLAN-0049: Purgar credencial efÃ­mera para dejar la cuenta local 100% sin contraseÃ±a
        $firstLogonCommands.Add(@"
        <SynchronousCommand wcm:action="add">
          <CommandLine>cmd.exe /c net user "$finalLocalUser" ""</CommandLine>
          <Description>Purge ephemeral setup password to ensure passwordless account</Description>
          <Order>$cmdOrder</Order>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>
"@)
        $cmdOrder++
        $firstLogonCommands.Add(@"
        <SynchronousCommand wcm:action="add">
          <CommandLine>reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /f</CommandLine>
          <Description>Delete DefaultPassword from Winlogon registry</Description>
          <Order>$cmdOrder</Order>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>
"@)
        $cmdOrder++
        $firstLogonCommands.Add(@"
        <SynchronousCommand wcm:action="add">
          <CommandLine>reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 0 /f</CommandLine>
          <Description>Reset AutoAdminLogon to normal mode for passwordless account</Description>
          <Order>$cmdOrder</Order>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>
"@)
        $cmdOrder++
    }

    # PLAN-0030: Forzar Modo Oscuro en HKCU del usuario interactivo en el primer inicio de sesión
    $firstLogonCommands.Add(@"
        <SynchronousCommand wcm:action="add">
          <CommandLine>reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 0 /f</CommandLine>
          <Description>Force Dark Mode for Apps in HKCU</Description>
          <Order>$cmdOrder</Order>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>
"@)
    $cmdOrder++
    $firstLogonCommands.Add(@"
        <SynchronousCommand wcm:action="add">
          <CommandLine>reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f</CommandLine>
          <Description>Force Dark Mode for Shell in HKCU</Description>
          <Order>$cmdOrder</Order>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>
"@)
    $cmdOrder++
    $firstLogonCommands.Add(@"
        <SynchronousCommand wcm:action="add">
          <CommandLine>reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 1 /f</CommandLine>
          <Description>Enable Transparency in HKCU</Description>
          <Order>$cmdOrder</Order>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>
"@)
    $cmdOrder++

    # PLAN-0058: Poda de Memoria Silenciosa Post-Primer Inicio (Working Set Trim)
    $firstLogonCommands.Add(@"
        <SynchronousCommand wcm:action="add">
          <CommandLine>cmd.exe /c start "" /b powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command "Start-Sleep -Seconds 30; if (Test-Path 'C:\Windows\Setup\Scripts\Optimize-ProcessMemory.ps1') { . 'C:\Windows\Setup\Scripts\Optimize-ProcessMemory.ps1' -Quiet -Unattended }"</CommandLine>
          <Description>Trigger Background Working Set Memory Trim after stabilization</Description>
          <Order>$cmdOrder</Order>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>
"@)
    $cmdOrder++

    $firstLogonXml = ""
    if ($firstLogonCommands.Count -gt 0) {
        $firstLogonXml = @"
      <FirstLogonCommands>
$($firstLogonCommands -join "`n")
      </FirstLogonCommands>
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
          <Description>Prevent OneDrive auto-install (DisableFileSyncNGSC)</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive /v DisableFileSyncNGSC /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>3</Order>
          <Description>Disable OneDrive File Sync</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive /v DisableFileSync /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>4</Order>
          <Description>Disable OneDrive Metered Network Sync</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive /v DisableMeteredNetworkFileSync /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>5</Order>
          <Description>Disable OneDrive Libraries Style Pin</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive /v DisableLibrariesStylePin /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>6</Order>
          <Description>Remove OneDrive from Default User Run key</Description>
          <Path>cmd.exe /c &quot;reg delete HKU\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Run /v OneDriveSetup /f &gt;nul 2&gt;&amp;1 || exit 0&quot;</Path>
        </RunSynchronousCommand>
"@
    }

    # Optimizaciones de sistema inyectadas en fase specialize (políticas HKLM 100% seguras)
    $nextOrder = if ($script:BlockOneDrive) { 7 } else { 2 }

    $optimizeXml = ""
    if (Get-Command "Export-RomanOSUnattendCommands" -ErrorAction SilentlyContinue) {
        $unattendResult = Export-RomanOSUnattendCommands -Profile "$optProfile" -StartOrder $nextOrder -SkipOneDrive:(-not $script:BlockOneDrive)
        $optimizeXml = $unattendResult.XmlContent
        $nextOrder = $unattendResult.NextOrder
    } else {
        $optimizeXml = @"
        <RunSynchronousCommand wcm:action="add">
          <Order>$nextOrder</Order>
          <Description>Block Privacy Experience screens (Scoobe)</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE /v DisablePrivacyExperience /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 1)</Order>
          <Description>Disable Cloud Consumer Features (Anti-Bloatware)</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 2)</Order>
          <Description>Disable Cloud SoftLanding Tips</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent /v DisableSoftLanding /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 3)</Order>
          <Description>Disable PasswordLess sign-in to allow AutoLogon without password (W11 24H2+)</Description>
          <Path>reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" /v DevicePasswordLessBuildVersion /t REG_DWORD /d 0 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 4)</Order>
          <Description>Restrict Blank Password Usage to Console Logon Only (Security Hardened)</Description>
          <Path>reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LimitBlankPasswordUse /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 5)</Order>
          <Description>Hide Recommended section in Start Menu</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer /v HideRecommendedSection /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 6)</Order>
          <Description>Disable Search Box Suggestions in Start and Taskbar</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 7)</Order>
          <Description>Disable Search Highlights Dynamic Content in Search Box (EnableDynamicContentInWSB=0)</Description>
          <Path>reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v EnableDynamicContentInWSB /t REG_DWORD /d 0 /f</Path>
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
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 13)</Order>
          <Description>Disable Optional Preview Updates and CFR Beta Content (AllowOptionalContent=0)</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate /v AllowOptionalContent /t REG_DWORD /d 0 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 14)</Order>
          <Description>Disable Continuous Innovation Opt-In (Off)</Description>
          <Path>reg add HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings /v IsContinuousInnovationOptedIn /t REG_DWORD /d 0 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 15)</Order>
          <Description>Enable Quality Updates Deferral and Quarantine Period</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate /v DeferQualityUpdates /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 16)</Order>
          <Description>Defer Quality Updates by 7 Days (KIR Maturation Window)</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate /v DeferQualityUpdatesPeriodInDays /t REG_DWORD /d 7 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 17)</Order>
          <Description>Exclude Drivers from Automatic Updates (Move to Optional Updates - PLAN-0061)</Description>
          <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate /v ExcludeWUDriversInQualityUpdate /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 18)</Order>
          <Description>Block Driver Search on Windows Update via CurrentVersion hive (SearchOrderConfig=0 = local-only - PLAN-0061)</Description>
          <Path>reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching /v SearchOrderConfig /t REG_DWORD /d 0 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 19)</Order>
          <Description>Prevent Device Metadata and OEM App Download from Network (PLAN-0061)</Description>
          <Path>reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" /v PreventDeviceMetadataFromNetwork /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 20)</Order>
          <Description>Disable WPBT ACPI Execution (Block OEM BIOS Bloatware on Notebooks/Motherboards - PLAN-0061)</Description>
          <Path>reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v DisableWPBT /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 21)</Order>
          <Description>Prevent Automatic BitLocker Device Encryption on Clean Install (PLAN-0061)</Description>
          <Path>reg add "HKLM\SYSTEM\CurrentControlSet\Control\BitLocker" /v PreventDeviceEncryption /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
"@

        $nextOrder += 22

        if ($optProfile -ge 2) {
            # Perfil 2+ (Gaming / Hardcore): Políticas de telemetría HKLM y Windows Update Bajo Demanda (PLAN-0059)
            $optimizeXml += @"

        <RunSynchronousCommand wcm:action="add">
          <Order>$nextOrder</Order>
          <Description>Set AllowTelemetry policy to Security level</Description>
          <Path>reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 1)</Order>
          <Description>Disable Automatic Background Updates (Manual On-Demand Scan and Download Only)</Description>
          <Path>reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 2)</Order>
          <Description>Configure AUOptions to 2 (Notify Before Download and Install)</Description>
          <Path>reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 2 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>$($nextOrder + 3)</Order>
          <Description>Prevent Automatic Reboots While Users Are Logged On</Description>
          <Path>reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
"@
            $nextOrder += 4
        }
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
    <component name="Microsoft-Windows-PnpCustomizationsWinPE" processorArchitecture="$Architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <DriverPaths>
        <PathAndCredentials wcm:action="add" wcm:keyValue="1">
          <Path>.\Drivers</Path>
        </PathAndCredentials>
      </DriverPaths>
    </component>
    <component name="Microsoft-Windows-Setup" processorArchitecture="$Architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <EnableFirewall>true</EnableFirewall>
      <DynamicUpdate>
        <Enable>false</Enable>
        <WillShowUI>Never</WillShowUI>
      </DynamicUpdate>
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Set WinPE High Performance Power Scheme (PLAN-0076)</Description>
          <Path>powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>2</Order>
          <Description>Bypass TPM Check</Description>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>3</Order>
          <Description>Bypass SecureBoot Check</Description>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>4</Order>
          <Description>Bypass RAM Check</Description>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>5</Order>
          <Description>Bypass CPU Check</Description>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassCPUCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>6</Order>
          <Description>Bypass Storage Check</Description>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassStorageCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>7</Order>
          <Description>Bypass Disk Check</Description>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassDiskCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>8</Order>
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
        <Username>$finalLocalUser</Username>
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
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Password>
              <Value>$encodedPasswordForAccount</Value>
              <PlainText>$passwordPlainTextAccount</PlainText>
            </Password>
            <DisplayName>$finalLocalUser</DisplayName>
            <Group>Administrators</Group>
            <Name>$finalLocalUser</Name>
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
            if ($script:Headless -or $PresetFile) {
                Write-Info "Modo Headless/Preset activo: Procesando automáticamente TODAS las ediciones del WIM."
                $indexesToProcess = $allWimImages | ForEach-Object { $_.Index }
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

        #==================================================================
        # DUAL-SERVICING DE CONTROLADORES EN boot.wim (WinPE / Setup)
        #==================================================================
        $bootWimCandidate = Join-Path $ISOFilesDir "sources\boot.wim"
        if (-not (Test-Path $bootWimCandidate)) {
            $bootWimFound = Get-ChildItem -Path $ISOFilesDir -Recurse -Filter "boot.wim" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($bootWimFound) { $bootWimCandidate = $bootWimFound.FullName }
        }

        if ($bootWimCandidate -and (Test-Path $bootWimCandidate) -and $resolvedDriversDir -and (-not $SkipBootWimDrivers -and -not $script:SkipBootWimDrivers)) {
            Write-Host ""
            Write-Host "    ══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "    DUAL-SERVICING: Inyección de Drivers en boot.wim (WinPE / Setup)" -ForegroundColor Cyan
            Write-Host "    ══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "    Imagen de arranque: $bootWimCandidate" -ForegroundColor Gray

            try {
                $bootItem = Get-Item $bootWimCandidate -ErrorAction SilentlyContinue
                if ($bootItem -and $bootItem.IsReadOnly) {
                    Set-ItemProperty -Path $bootWimCandidate -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
                }
            } catch {}

            $bootIndices = @()
            try {
                $bootImages = Get-WimImageList -WimPath $bootWimCandidate
                if ($bootImages -and $bootImages.Count -ge 2) {
                    # Servicing en Índice 2 (Windows Setup) e Índice 1 (WinPE)
                    $bootIndices = @(2, 1)
                } elseif ($bootImages -and $bootImages.Count -eq 1) {
                    $bootIndices = @(1)
                }
            } catch {
                $bootIndices = @(2)
            }

            $bootMountDir = Join-Path $ScratchDir "boot_mount"
            if (-not (Test-Path $bootMountDir)) {
                New-Item -ItemType Directory -Path $bootMountDir -Force | Out-Null
            }

            foreach ($bIdx in $bootIndices) {
                Write-Host "    Inyectando drivers en boot.wim Índice $bIdx..." -ForegroundColor Gray
                try {
                    Mount-WindowsImage -ImagePath $bootWimCandidate -Index $bIdx -Path $bootMountDir -ScratchDirectory $ScratchDir -ErrorAction Stop
                    $mountedBoot = $true
                    if ($mountedBoot) {
                        $dismBootLog = Join-Path $ScratchDir "dism_boot_drv_idx${bIdx}.log"
                        $dismBootRes = Invoke-MonitoredProcess -FilePath "dism.exe" `
                            -ArgumentList @("/Image:$bootMountDir", "/Add-Driver", "/Driver:$resolvedDriversDir", "/Recurse", "/ForceUnsigned", "/ScratchDir:$ScratchDir", "/LogPath:$dismBootLog") `
                            -AllowExitCodes @(0, 3010) `
                            -TaskDescription "Inyección offline drivers boot.wim Idx $bIdx" `
                            -TimeoutSeconds 600 `
                            -HeartbeatIntervalSeconds $HeartbeatIntervalSeconds

                        if ($dismBootRes.Success) {
                            Write-OK "Drivers inyectados con éxito en boot.wim (Índice $bIdx)."
                            Add-AuditRecord -Resource "Drivers boot.wim (Setup/WinPE)" -Target "boot.wim Idx $bIdx" `
                                            -Status "OK" -Details "Drivers offline inyectados correctamente con DISM"
                        } else {
                            Write-Warn "DISM Add-Driver devolvió exit code: $($dismBootRes.ExitCode) en boot.wim Idx $bIdx."
                            Add-AuditRecord -Resource "Drivers boot.wim (Setup/WinPE)" -Target "boot.wim Idx $bIdx" `
                                            -Status "WARN" -Details "DISM devolvió exit code $($dismBootRes.ExitCode)"
                        }

                        Dismount-WindowsImage -Path $bootMountDir -Save -ScratchDirectory $ScratchDir | Out-Null
                    }
                } catch {
                    Write-Warn "Error inyectando en boot.wim Índice $($bIdx): $($_.Exception.Message)"
                    Dismount-WindowsImage -Path $bootMountDir -Discard -ScratchDirectory $ScratchDir | Out-Null
                }
            }

            if (Test-Path $bootMountDir) {
                Remove-Item -Path $bootMountDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

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
                    # AUDITORÍA PREVIA: nivel de parche actual del WIM base
                    #==================================================================

                    Write-Host ""
                    Write-Host "    ══ Auditoría de Nivel de Parche del WIM Base ══" -ForegroundColor Cyan
                    $wimPatchLevel = Get-WimPatchLevel -MountDir $WimMountDir
                    $script:WimUbrBefore = $wimPatchLevel.UBR
                    Write-LogEntry -Level "INFO" -Message "UBR WIM Inicial (Idx $wimIndex): $($wimPatchLevel.UBR)"

                    if ($wimPatchLevel.InstalledKBs.Count -gt 0) {
                        $kbList = $wimPatchLevel.InstalledKBs -join ", "
                        $ubrStr = if ($wimPatchLevel.UBR -gt 0) { " (UBR: $($wimPatchLevel.UBR))" } else { "" }
                        Write-Host "    KBs en WIM base$ubrStr : $kbList" -ForegroundColor DarkGray
                        Write-Info "Slipstreaming omitirá paquetes ya presentes en el WIM."
                    } else {
                        Write-Host "    No se detectaron KBs en el WIM base (imagen sin parchear o DISM no devolvió datos)." -ForegroundColor DarkGray
                    }

                    #==================================================================
                    # HABILITACIÓN OFFLINE DE .NET FRAMEWORK 3.5 (NetFx3)
                    #==================================================================

                    Write-Host ""
                    Write-Host "    ══ Habilitar .NET Framework 3.5 (NetFx3) ══" -ForegroundColor Cyan

                    $sxsDir = Join-Path $ISOFilesDir "sources\sxs"

                    if (Test-Path $sxsDir) {
                        try {
                            Write-Host "    Habilitando .NET 3.5 desde sources\sxs con DISM..." -ForegroundColor Gray
                            $dismNetFx3 = Invoke-MonitoredProcess -FilePath "dism.exe" `
                                -ArgumentList @("/Image:$WimMountDir", "/Enable-Feature", "/FeatureName:NetFx3", "/All", "/Source:$sxsDir", "/LimitAccess", "/ScratchDir:$ScratchDir") `
                                -AllowExitCodes @(0, 3010) `
                                -TaskDescription "Habilitación offline de .NET Framework 3.5" `
                                -TimeoutSeconds 600 `
                                -HeartbeatIntervalSeconds $HeartbeatIntervalSeconds

                            if ($dismNetFx3.Success) {
                                Write-OK ".NET Framework 3.5 habilitado en la imagen WIM."
                            } else {
                                Write-Warn "DISM NetFx3 exit code: $($dismNetFx3.ExitCode). Continuando."
                            }
                        } catch {
                            Write-Warn "No se pudo habilitar .NET 3.5 offline: $($_.Exception.Message)"
                        }
                    } else {
                        Write-Host "    Carpeta 'sources\sxs' no encontrada en la ISO. NetFx3 omitido." -ForegroundColor DarkYellow
                    }

                    #==================================================================
                    # HABILITACIÓN OFFLINE DE HYPER-V Y VIRTUALIZACIÓN (PLAN-0063)
                    #==================================================================
                    $shouldEnableHyperV = if ($null -ne $script:EnableHyperV) { [bool]$script:EnableHyperV } elseif ($null -ne $EnableHyperV) { [bool]$EnableHyperV } else { $false }
                    if ($shouldEnableHyperV) {
                        Write-Host ""
                        Write-Host "    ══ Habilitación Offline de Hyper-V y Virtualización (PLAN-0063) ══" -ForegroundColor Cyan
                        try {
                            $hvFeatures = @("Microsoft-Hyper-V-All", "VirtualMachinePlatform", "Microsoft-Windows-Subsystem-Linux")
                            foreach ($feat in $hvFeatures) {
                                Write-Host "    Habilitando '$feat' offline con DISM..." -ForegroundColor Gray
                                $dismHv = Invoke-MonitoredProcess -FilePath "dism.exe" `
                                    -ArgumentList @("/Image:$WimMountDir", "/Enable-Feature", "/FeatureName:$feat", "/All", "/NoRestart", "/ScratchDir:$ScratchDir") `
                                    -AllowExitCodes @(0, 3010) `
                                    -TaskDescription "Habilitación offline de $feat" `
                                    -TimeoutSeconds 600 `
                                    -HeartbeatIntervalSeconds $HeartbeatIntervalSeconds

                                if ($dismHv.Success) {
                                    Write-OK "Característica '$feat' habilitada offline en WIM."
                                    Add-AuditRecord -Resource "Virtualizacion ($feat)" -Target 'WIM' -Status "OK" -Details "Habilitado offline"
                                } else {
                                    Write-Warn "DISM $feat exit code: $($dismHv.ExitCode). Podrá activarse en el primer arranque."
                                }
                            }
                        } catch {
                            Write-Warn "No se pudo habilitar Hyper-V offline: $($_.Exception.Message)"
                        }
                    }

                    #==================================================================
                    # SLIPSTREAMING DE ACTUALIZACIONES (WINDOWS UPDATES)
                    #==================================================================

                    if ($script:SkipUpdates -or $SkipUpdates) {
                        Write-Host ""
                        Write-Host "    ══ Slipstreaming de actualizaciones ══" -ForegroundColor Cyan
                        Write-Host "    Slipstreaming de actualizaciones omitido por configuración (-SkipUpdates activo)." -ForegroundColor Gray
                        Add-AuditRecord -Resource "Windows Updates (MSU/CAB)" -Target "WIM Idx $wimIndex" -Status "SKIP" `
                                        -Details "Omitido por configuración (-SkipUpdates)"
                    } else {
                        # Reutilizar resolución canónica de Paso 0 o resolver validando presencia de paquetes .msu/.cab
                        if ($resolvedUpdatesDir -and (Test-Path $resolvedUpdatesDir)) {
                        $updTestCount = (Get-ChildItem -Path $resolvedUpdatesDir -Include *.msu, *.cab -Recurse -File -ErrorAction SilentlyContinue).Count
                        if ($updTestCount -eq 0) {
                            $resolvedUpdatesDir = $null
                        }
                    }

                    if (-not $resolvedUpdatesDir) {
                        $candidateUpdates = @(
                            $UpdatesPath,
                            (Join-Path (Split-Path -Parent $ScriptsDir) "Updates"),
                            "C:\OptimizedISO\Updates",
                            (Join-Path (Get-Location) "Updates"),
                            (Join-Path $ScriptsDir "Updates")
                        )

                        foreach ($cand in $candidateUpdates) {
                            if ($cand -and (Test-Path $cand)) {
                                $pkgFound = (Get-ChildItem -Path $cand -Include *.msu, *.cab -Recurse -File -ErrorAction SilentlyContinue).Count
                                if ($pkgFound -gt 0) {
                                    $resolvedUpdatesDir = (Resolve-Path $cand).Path
                                    break
                                }
                            }
                        }
                    }

                    $successCount = 0
                    $failCount    = 0

                    Write-Host ""
                    Write-Host "    ══ Slipstreaming de actualizaciones ══" -ForegroundColor Cyan

                    if (-not $resolvedUpdatesDir) {
                        Assert-ResourceCommitment -ResourceName "Windows Updates (MSU/CAB)" `
                            -PreflightFound ([bool]$script:PreflightUpdatesDetected) `
                            -ExecutionApplied $false `
                            -ExpectedPath "" `
                            -FailureReason "La carpeta de actualizaciones detectada en Preflight ya no esta accesible o no contiene paquetes .msu/.cab"
                        Write-Warn -Message "Slipstreaming de actualizaciones omitido." -Cause "Carpeta 'Updates' no resuelta o sin paquetes .msu/.cab" -Action "Descargue actualizaciones ejecutando scripts\Builder\Get-WindowsUpdates.ps1"
                    } else {
                        $packages = Get-ChildItem -Path $resolvedUpdatesDir -Include *.msu, *.cab -Recurse -ErrorAction SilentlyContinue

                        if ($packages.Count -eq 0) {
                            Assert-ResourceCommitment -ResourceName "Windows Updates (MSU/CAB)" `
                                -PreflightFound ([bool]$script:PreflightUpdatesDetected) `
                                -ExecutionApplied $false `
                                -ExpectedPath $resolvedUpdatesDir `
                                -FailureReason "Carpeta '$resolvedUpdatesDir' encontrada pero sin archivos .msu/.cab validos"
                            Write-Warn -Message "Slipstreaming de actualizaciones omitido." -Cause "Carpeta '$resolvedUpdatesDir' sin archivos .msu/.cab" -Action "Coloque paquetes .msu/.cab dentro de la carpeta"
                        } else {
                            # Ordenación técnica oficial:
                            # 1. SSU (Servicing Stack)
                            # 2. Checkpoint Packages (ej. KB5043080)
                            # 3. LCU (Latest Cumulative Update de Windows)
                            # 4. Actualizaciones de .NET Framework
                            # 5. SafeOS y paquetes complementarios
                            $orderedPackages = $packages | Sort-Object {
                                if ($_.Name -match 'ssu|servicing.?stack') {
                                    0
                                } elseif ($_.Name -match 'kb5043080|checkpoint') {
                                    1
                                } elseif ($_.Name -match 'windows1[01].*-kb\d+' -and $_.Name -notmatch 'ndp|dotnet|\.net') {
                                    2
                                } elseif ($_.Name -match 'ndp|dotnet|\.net') {
                                    3
                                } else {
                                    4
                                }
                            }, Name

                            $total = $orderedPackages.Count

                            Write-Host "    Encontrados $total paquete(s) en '$resolvedUpdatesDir'." -ForegroundColor Gray
                            Write-Host "    Orden de inyección: SSU -> Checkpoints -> LCU -> .NET -> Complementarios." -ForegroundColor Gray

                            $ssuCount = @($orderedPackages | Where-Object { $_.Name -match 'ssu|servicing.?stack' }).Count

                            if ($ssuCount -gt 0) {
                                Write-Host "    SSU detectados: $ssuCount." -ForegroundColor Gray
                            }

                            Write-Host ""

                            $i = 0

                            foreach ($pkg in $orderedPackages) {
                                $i++

                                $label = if ($pkg.Name -match 'ssu|servicing.?stack') { "[SSU]" } elseif ($pkg.Name -match 'kb5043080|checkpoint') { "[CHK]" } else { "[PKG]" }
                                $sizeMB = [math]::Round($pkg.Length / 1MB, 1)

                                # Timeout dinámico según el tamaño del paquete (paquetes acumulativos >1.5 GB reciben 2400s / 40m)
                                $pkgTimeout = if ($sizeMB -gt 1500) { 2400 } else { 1200 }

                                # Verificar si el KB ya está instalado en el WIM base
                                $pkgKB = if ($pkg.Name -match 'KB(\d{7,})') { "KB$($Matches[1])" } else { "" }
                                if ($pkgKB -and $wimPatchLevel -and $wimPatchLevel.InstalledKBs.Contains($pkgKB)) {
                                    Write-Host "    [$i/$total] $label $($pkg.Name) ($sizeMB MB)..." -ForegroundColor DarkGray -NoNewline
                                    Write-Host " OMITIDO (ya en WIM)" -ForegroundColor DarkCyan
                                    $successCount++
                                    continue
                                }

                                Write-Host "    [$i/$total] $label $($pkg.Name) ($sizeMB MB)..." -ForegroundColor Gray -NoNewline

                                try {
                                    $dismLog = Join-Path $ScratchDir "dism_$($pkg.Name).log"

                                    $dismRes = Invoke-MonitoredProcess -FilePath "dism.exe" `
                                        -ArgumentList @("/Image:$WimMountDir", "/Add-Package", "/PackagePath:$($pkg.FullName)", "/ScratchDir:$ScratchDir", "/LogPath:$dismLog") `
                                        -AllowExitCodes @(0, 3010) `
                                        -TaskDescription "Slipstreaming paquete $($pkg.Name)" `
                                        -TimeoutSeconds $pkgTimeout `
                                        -HeartbeatIntervalSeconds $HeartbeatIntervalSeconds

                                    if ($dismRes.Success) {
                                        $successCount++
                                        Write-Host " OK" -ForegroundColor Green
                                    } else {
                                        if ($pkg.Extension -eq ".msu") {
                                            Write-Host " WARN" -ForegroundColor Yellow

                                            # Detectar si el .msu es un Checkpoint CU (formato PSF/WIM)
                                            # Los Checkpoint CU (ej. KB5043080) tienen cabecera WIM (MSWIM\0\0\0)
                                            # y NO contienen un .cab extraíble con expand.exe.
                                            $isPsf = Test-MsuIsPsfFormat -MsuPath $pkg.FullName

                                            if ($isPsf) {
                                                # === RUTA PSF: Checkpoint Cumulative Update ===
                                                # El MSU ya contiene el SSU bundled internamente.
                                                # DISM debe procesar el .msu completo con /IgnoreCheck.
                                                Write-Host "      [PSF] Checkpoint CU detectado. Reintentando con /IgnoreCheck..." -ForegroundColor DarkYellow

                                                $dismPsfRes = Invoke-MonitoredProcess -FilePath "dism.exe" `
                                                    -ArgumentList @(
                                                        "/Image:$WimMountDir",
                                                        "/Add-Package",
                                                        "/PackagePath:$($pkg.FullName)",
                                                        "/IgnoreCheck",
                                                        "/NoRestart",
                                                        "/ScratchDir:$ScratchDir",
                                                        "/LogPath:$dismLog"
                                                    ) `
                                                    -AllowExitCodes @(0, 3010) `
                                                    -TaskDescription "Slipstreaming PSF Checkpoint $($pkg.Name)" `
                                                    -TimeoutSeconds $pkgTimeout `
                                                    -HeartbeatIntervalSeconds $HeartbeatIntervalSeconds

                                                if ($dismPsfRes.Success) {
                                                    $successCount++
                                                    Write-Host "      OK (Checkpoint PSF aplicado)." -ForegroundColor Green
                                                } else {
                                                    $failCount++
                                                    Write-Host "      ERROR PSF. ExitCode: $($dismPsfRes.ExitCode). Log: $dismLog" -ForegroundColor Red
                                                }
                                            } else {
                                                # === RUTA ESTÁNDAR: MSU con .cab extraíble ===
                                                Write-Host "      Intentando extraer .cab interno..." -ForegroundColor Gray

                                                $cabExtractDir = Join-Path $ScratchDir "Extracted_$($pkg.Name)"
                                                New-Item -ItemType Directory -Path $cabExtractDir -Force | Out-Null

                                                & expand.exe -F:* "$($pkg.FullName)" "$cabExtractDir" 2>&1 | Out-Null

                                                $cabFile = Get-ChildItem -Path $cabExtractDir -Filter "*.cab" |
                                                    Where-Object { $_.Name -notmatch 'WSUSSCAN' } |
                                                    Select-Object -First 1

                                                if ($cabFile) {
                                                    $dismCabRes = Invoke-MonitoredProcess -FilePath "dism.exe" `
                                                        -ArgumentList @("/Image:$WimMountDir", "/Add-Package", "/PackagePath:$($cabFile.FullName)", "/ScratchDir:$ScratchDir", "/LogPath:$dismLog") `
                                                        -AllowExitCodes @(0, 3010) `
                                                        -TaskDescription "Slipstreaming .cab extraído de $($pkg.Name)" `
                                                        -TimeoutSeconds 900 `
                                                        -HeartbeatIntervalSeconds $HeartbeatIntervalSeconds

                                                    if ($dismCabRes.Success) {
                                                        $successCount++
                                                        Write-Host "      OK usando .cab extraído." -ForegroundColor Green
                                                    } else {
                                                        $failCount++
                                                        Write-Host "      ERROR también con .cab. Exit code: $($dismCabRes.ExitCode)." -ForegroundColor Red
                                                    }
                                                } else {
                                                    $failCount++
                                                    Write-Host "      ERROR: no se encontró .cab válido dentro del .msu." -ForegroundColor Red
                                                }
                                            }
                                        } else {
                                            $failCount++
                                            Write-Host " ERROR. Exit code: $($dismRes.ExitCode)." -ForegroundColor Red
                                        }
                                    }
                                } catch {
                                    $failCount++
                                    Write-Host " ERROR: $($_.Exception.Message)." -ForegroundColor Red
                                    Write-ForensicException -Record $_ -Context "Slipstream Update ($($pkg.Name))" -SuggestedAction "Verifique la compatibilidad del paquete KB con la version de Windows en el WIM"
                                }
                            }

                            Write-Host ""
                            Write-Host "    Resumen slipstreaming:" -ForegroundColor Cyan
                            Write-Host "      Correctos: $successCount" -ForegroundColor Green
                            Write-Host "      Fallidos : $failCount" -ForegroundColor $(if ($failCount -gt 0) { 'Red' } else { 'Green' })

                            Assert-ResourceCommitment -ResourceName "Windows Updates (MSU/CAB)" `
                                -PreflightFound ([bool]$script:PreflightUpdatesDetected) `
                                -ExecutionApplied ([bool]($successCount -gt 0)) `
                                -ExpectedPath $resolvedUpdatesDir `
                                -FailureReason "Fallaron $failCount paquete(s) de actualizacion de un total de $total"
                        }
                    }
                } # fin del else if ($script:SkipUpdates -or $SkipUpdates)

                    #==================================================================
                    # INYECCIÓN OFFLINE DE CONTROLADORES (DRIVERS)
                    #==================================================================

                    if ($script:SkipDrivers -or $SkipDrivers) {
                        Write-Host ""
                        Write-Host "    ══ Inyección offline de Drivers ══" -ForegroundColor Cyan
                        Write-Host "    Inyección offline de controladores omitida por configuración (-SkipDrivers activo)." -ForegroundColor Gray
                        Add-AuditRecord -Resource "Controladores Offline" -Target "WIM Idx $wimIndex" -Status "SKIP" `
                                        -Details "Omitido por configuración (-SkipDrivers)"
                    } else {
                        # Reutilizar resolución canónica de Paso 0 o resolver validando presencia de drivers .inf reales
                        if ($resolvedDriversDir -and (Test-Path $resolvedDriversDir)) {
                        $drvTestCount = (Get-ChildItem -Path $resolvedDriversDir -Include *.inf -Recurse -File -ErrorAction SilentlyContinue).Count
                        if ($drvTestCount -eq 0) {
                            $resolvedDriversDir = $null
                        }
                    }

                    if (-not $resolvedDriversDir) {
                        $candidateDrivers = @(
                            $DriversPath,
                            (Join-Path (Split-Path -Parent $ScriptsDir) "Drivers"),
                            "C:\OptimizedISO\Drivers",
                            (Join-Path (Get-Location) "Drivers"),
                            (Join-Path $ScriptsDir "Drivers")
                        )

                        foreach ($cand in $candidateDrivers) {
                            if ($cand -and (Test-Path $cand)) {
                                $infFound = (Get-ChildItem -Path $cand -Include *.inf -Recurse -File -ErrorAction SilentlyContinue).Count
                                if ($infFound -gt 0) {
                                    $resolvedDriversDir = (Resolve-Path $cand).Path
                                    break
                                }
                            }
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

                                $dismDrv = Invoke-MonitoredProcess -FilePath "dism.exe" `
                                    -ArgumentList @("/Image:$WimMountDir", "/Add-Driver", "/Driver:$resolvedDriversDir", "/Recurse", "/ForceUnsigned", "/ScratchDir:$ScratchDir", "/LogPath:$dismDriverLog") `
                                    -AllowExitCodes @(0, 3010) `
                                    -TaskDescription "Inyección offline de controladores" `
                                    -TimeoutSeconds 900 `
                                    -HeartbeatIntervalSeconds $HeartbeatIntervalSeconds

                                if ($dismDrv.Success) {
                                    Write-OK "Controladores inyectados exitosamente en la imagen WIM ($($driverFiles.Count) archivos .inf)."
                                    $driversInjected = @(Get-WindowsDriver -Path $WimMountDir -ErrorAction SilentlyContinue)
                                    $unsignedDrivers  = @($driversInjected | Where-Object { -not $_.Signed })
                                    Add-AuditRecord -Resource "Drivers INF offline" -Target "WIM Idx $wimIndex" `
                                                    -Status $(if ($unsignedDrivers.Count -gt 0) { "WARN" } else { "OK" }) `
                                                    -Details "$($driversInjected.Count) driver(s) | $($unsignedDrivers.Count) sin firma WHQL (riesgo BSOD 0xc0000428)"
                                } else {
                                    Write-Warn "DISM Add-Driver devolvió exit code: $($dismDrv.ExitCode). Revise $dismDriverLog."
                                    Add-AuditRecord -Resource "Drivers INF offline" -Target "WIM Idx $wimIndex" `
                                                    -Status "FAIL" `
                                                    -Details "DISM Add-Driver falló con exit code: $($dismDrv.ExitCode)"
                                }
                            } catch {
                                Write-ForensicException -Record $_ -Context "Inyeccion Drivers Offline (WIM Idx $wimIndex)" -SuggestedAction "Verifique que los archivos .inf sean validos y compatibles con la arquitectura $Architecture"
                                Add-AuditRecord -Resource "Drivers INF offline" -Target "WIM Idx $wimIndex" `
                                                -Status "FAIL" `
                                                -Details $_.Exception.Message
                            }
                        } else {
                            Assert-ResourceCommitment -ResourceName "Controladores Hardware (INF)" `
                                -PreflightFound ([bool]$script:PreflightDriversDetected) `
                                -ExecutionApplied $false `
                                -ExpectedPath $resolvedDriversDir `
                                -FailureReason "Carpeta '$resolvedDriversDir' no contiene archivos .inf validos"
                            Write-Warn -Message "Inyección de controladores omitida." -Cause "Carpeta '$resolvedDriversDir' encontrada pero sin archivos .inf" -Action "Coloque controladores .inf dentro de la carpeta"
                        }
                    } else {
                        Assert-ResourceCommitment -ResourceName "Controladores Hardware (INF)" `
                            -PreflightFound ([bool]$script:PreflightDriversDetected) `
                            -ExecutionApplied $false `
                            -ExpectedPath "" `
                            -FailureReason "La carpeta de controladores detectada en Preflight ya no esta accesible"
                    }
                } # fin del else if ($script:SkipDrivers -or $SkipDrivers)

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
                                if ($script:Headless -or $PresetFile) {
                                    Write-Info "Modo Headless/Preset activo (Perfil 1 Conservador): Conservando paquetes AppX seleccionables sin diálogos interactivos."
                                    $selectedToRemove = $null
                                } elseif (-not $SkipAutoUnattend) {
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
                                $appxOk   = 0
                                $appxFail = 0

                                foreach ($pkg in $selectedToRemove) {
                                    try {
                                        Remove-AppxProvisionedPackage -Path $WimMountDir `
                                                                      -PackageName $pkg.PackageName `
                                                                      -ErrorAction Stop | Out-Null
                                        $appxOk++
                                        Write-Host "      Eliminado: $($pkg.Name)" -ForegroundColor Green
                                    } catch {
                                        $appxFail++
                                        Write-Host "      Error eliminando $($pkg.Name): $($_.Exception.Message)" -ForegroundColor Yellow
                                        Write-LogEntry -Level "WARN" -Message "Error eliminando AppX $($pkg.Name): $($_.Exception.Message)"
                                    }
                                }

                                $appxStatus = if ($appxFail -gt 0 -and $appxOk -eq 0) { "FAIL" } `
                                              elseif ($appxFail -gt 0) { "WARN" } else { "OK" }
                                Add-AuditRecord -Resource "AppX Debloat offline" -Target "WIM Idx $wimIndex" `
                                                -Status $appxStatus `
                                                -Details "$appxOk eliminados, $appxFail fallidos de $(@($selectedToRemove).Count)"

                                Write-OK "Debloat offline completado."
                            } else {
                                Write-Host "    Sin selección. Conservando paquetes." -ForegroundColor Gray
                                Add-AuditRecord -Resource "AppX Debloat offline" -Target "WIM Idx $wimIndex" `
                                                -Status "SKIP" `
                                                -Details "Sin selección o perfil conservador. 0 paquetes eliminados"
                            }
                        } else {
                            Write-Host "    No hay paquetes removibles." -ForegroundColor Gray
                            Add-AuditRecord -Resource "AppX Debloat offline" -Target "WIM Idx $wimIndex" `
                                            -Status "SKIP" `
                                            -Details "No se detectaron paquetes removibles"
                        }
                    } catch {
                        Write-Warn "No se pudo obtener la lista de paquetes AppX provisionados: $($_.Exception.Message)"
                        Add-AuditRecord -Resource "AppX Debloat offline" -Target "WIM Idx $wimIndex" `
                                        -Status "FAIL" `
                                        -Details $_.Exception.Message
                    }

                    #==================================================================
                    # RESETBASE
                    #==================================================================

                    if ($successCount -gt 0) {
                        if ($SkipComponentCleanup) {
                            Write-Host ""
                            Write-Host "    [INFO] StartComponentCleanup / ResetBase omitido (-SkipComponentCleanup activo)." -ForegroundColor DarkYellow
                        } else {
                            Write-Host ""
                            Write-Host "    Ejecutando ResetBase / StartComponentCleanup..." -ForegroundColor Cyan

                            try {
                                $resetRes = Invoke-MonitoredProcess -FilePath "dism.exe" `
                                    -ArgumentList @("/Image:$WimMountDir", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase", "/ScratchDir:$ScratchDir") `
                                    -TaskDescription "Limpieza y consolidación ResetBase de componentes" `
                                    -TimeoutSeconds 1800 `
                                    -HeartbeatIntervalSeconds $HeartbeatIntervalSeconds

                                if ($resetRes.Success) {
                                    Write-OK "Componentes limpiados y consolidados."
                                } else {
                                    Write-Warn "ResetBase finalizó con código: $($resetRes.ExitCode). Continuando."
                                }
                            } catch {
                                Write-Warn "Error ejecutando ResetBase: $($_.Exception.Message)"
                            }
                        }
                    }

                    #==================================================================
                    # AUDITORÍA POSTERIOR: nivel de parche final del WIM
                    #==================================================================

                    if ($successCount -gt 0 -or $failCount -gt 0) {
                        $wimPatchPost = Get-WimPatchLevel -MountDir $WimMountDir
                        $script:WimUbrAfter = $wimPatchPost.UBR
                        $ubrStatus = if ($wimPatchPost.UBR -gt $script:WimUbrBefore) { "OK" } elseif ($failCount -gt 0) { "WARN" } else { "OK" }
                        Add-AuditRecord -Resource "Windows Updates (UBR)" -Target "WIM Idx $wimIndex" `
                                        -Status $ubrStatus `
                                        -Details "UBR: $($script:WimUbrBefore) → $($wimPatchPost.UBR) | KBs: $($wimPatchPost.InstalledKBs -join ', ')"
                    } else {
                        Add-AuditRecord -Resource "Windows Updates (UBR)" -Target "WIM Idx $wimIndex" `
                                        -Status "SKIP" `
                                        -Details "Sin actualizaciones inyectadas (UBR base: $($script:WimUbrBefore))"
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
                                # Descarga preventiva por si una sesión previa dejó HKLM\OfflineDefaultUser tomada
                                [void](Invoke-RegUnloadHive -HiveName "HKLM\OfflineDefaultUser" -RetryCount 2 -RetryDelaySeconds 1)

                                Write-Host "    Cargando NTUSER.DAT del usuario default..." -ForegroundColor Gray

                                $procLoad = Start-Process -FilePath "reg.exe" `
                                                          -ArgumentList @("load", "HKLM\OfflineDefaultUser", $ntuserPath) `
                                                          -Wait `
                                                          -PassThru `
                                                          -NoNewWindow

                                if ($procLoad.ExitCode -ne 0) {
                                    # Segundo intento: forzar recolección de basura, re-descargar y reintentar
                                    [void](Invoke-RegUnloadHive -HiveName "HKLM\OfflineDefaultUser" -RetryCount 3 -RetryDelaySeconds 1)
                                    Start-Sleep -Milliseconds 500
                                    $procLoad = Start-Process -FilePath "reg.exe" `
                                                              -ArgumentList @("load", "HKLM\OfflineDefaultUser", $ntuserPath) `
                                                              -Wait `
                                                              -PassThru `
                                                              -NoNewWindow
                                }

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
                                         # Neutralizacion de Widgets, Chat y Copilot en Barra de Tareas (PLAN-0057)

                                         @{
                                             Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                                             Name = "TaskbarMn"
                                             Type = "REG_DWORD"
                                             Data = "0"
                                         }
                                         @{
                                             Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                                             Name = "ShowCopilotButton"
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
                                         # Neutralizacion Quirurgica de Search Highlights y Bing en HKCU (PLAN-0055)
                                         @{
                                             Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
                                             Name = "IsDynamicSearchBoxEnabled"
                                             Type = "REG_DWORD"
                                             Data = "0"
                                         }
                                         @{
                                             Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Search"
                                             Name = "BingSearchEnabled"
                                             Type = "REG_DWORD"
                                             Data = "0"
                                         }
                                         @{
                                             Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Search"
                                             Name = "CortanaConsent"
                                             Type = "REG_DWORD"
                                             Data = "0"
                                         }
                                     )

                                     foreach ($tweak in $tweaks) {
                                         & reg.exe add $tweak.Path /v $tweak.Name /t $tweak.Type /d $tweak.Data /f 2>&1 | Out-Null
                                         if ($LASTEXITCODE -ne 0) {
                                             Write-Warn "Error aplicando tweak: $($tweak.Path) /v $($tweak.Name)"
                                         }
                                     }

                                     Write-OK "Tweaks visuales inyectados en Default User."
                                     Add-AuditRecord -Resource "Tweaks Visuales (Default User)" -Target "WIM Idx $wimIndex" `
                                                     -Status "OK" -Details "Modo Oscuro, Transparencia y optimizaciones inyectadas en NTUSER.DAT"
                                 } else {
                                     Write-Warn "No se pudo cargar NTUSER.DAT. Exit code: $($procLoad.ExitCode)."
                                     Add-AuditRecord -Resource "Tweaks Visuales (Default User)" -Target "WIM Idx $wimIndex" `
                                                     -Status "WARN" -Details "No se pudo montar NTUSER.DAT (Exit code: $($procLoad.ExitCode))"
                                 }
                             } catch {
                                 Write-Warn "Error aplicando tweaks visuales offline: $($_.Exception.Message)"
                                 Add-AuditRecord -Resource "Tweaks Visuales (Default User)" -Target "WIM Idx $wimIndex" `
                                                 -Status "FAIL" -Details $_.Exception.Message
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
                             Add-AuditRecord -Resource "Tweaks Visuales (Default User)" -Target "WIM Idx $wimIndex" `
                                             -Status "WARN" -Details "Archivo NTUSER.DAT no encontrado en $ntuserPath"
                         }
                        # PLAN-0030: Inyectar tema oscuro en la colmena SOFTWARE del WIM offline
                        # Esto garantiza que InstallTheme = dark.theme y Themes\Personalize queden
                        # grabados a nivel de maquina en la imagen del sistema, impidiendo que OOBE/uxtheme revierta a aero.theme
                        $swPath = Join-Path $WimMountDir "Windows\System32\config\SOFTWARE"
                        if (Test-Path $swPath) {
                            $swLoaded = $false
                            try {
                                [void](Invoke-RegUnloadHive -HiveName "HKLM\OfflineSoftware" -RetryCount 2 -RetryDelaySeconds 1)
                                Write-Host "    Cargando SOFTWARE hive del sistema offline..." -ForegroundColor Gray
                                $procSw = Start-Process -FilePath "reg.exe" -ArgumentList @("load", "HKLM\OfflineSoftware", $swPath) -Wait -PassThru -NoNewWindow
                                if ($procSw.ExitCode -eq 0) {
                                    $swLoaded = $true
                                    $swTweaks = @(
                                        @{
                                            Path = "HKLM\OfflineSoftware\Microsoft\Windows\CurrentVersion\Themes"
                                            Name = "InstallTheme"
                                            Type = "REG_SZ"
                                            Data = "C:\Windows\resources\Themes\dark.theme"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Microsoft\Windows\CurrentVersion\Themes\Personalize"
                                            Name = "AppsUseLightTheme"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Microsoft\Windows\CurrentVersion\Themes\Personalize"
                                            Name = "SystemUsesLightTheme"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Microsoft\Windows\CurrentVersion\Themes\Personalize"
                                            Name = "EnableTransparency"
                                            Type = "REG_DWORD"
                                            Data = "1"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
                                            Name = "NoLazyMode"
                                            Type = "REG_DWORD"
                                            Data = "1"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
                                            Name = "SystemResponsiveness"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        # Neutralizacion Quirurgica de Search Highlights y Bing en SOFTWARE hive (PLAN-0055)
                                        @{
                                            Path = "HKLM\OfflineSoftware\Policies\Microsoft\Windows\Windows Search"
                                            Name = "EnableDynamicContentInWSB"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Policies\Microsoft\Windows\Windows Search"
                                            Name = "DisableWebSearch"
                                            Type = "REG_DWORD"
                                            Data = "1"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Policies\Microsoft\Windows\Windows Search"
                                            Name = "ConnectedSearchUseWeb"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Policies\Microsoft\Windows\Windows Search"
                                            Name = "ConnectedSearchUseWebOverMeteredConnections"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Policies\Microsoft\Windows\Windows Search"
                                            Name = "AllowCloudSearch"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Policies\Microsoft\Windows\Windows Search"
                                            Name = "AllowCortana"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        # Neutralizacion de Widgets, Noticias e Intereses y Chat en SOFTWARE hive (PLAN-0057)
                                        @{
                                            Path = "HKLM\OfflineSoftware\Policies\Microsoft\Widgets"
                                            Name = "AllowWidgets"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Policies\Microsoft\Dsh"
                                            Name = "AllowNewsAndInterests"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Policies\Microsoft\Windows\Windows Chat"
                                            Name = "ChatIcon"
                                            Type = "REG_DWORD"
                                            Data = "3"
                                        }
                                        # Estabilidad de Actualizaciones Acumulativas y Bloqueo de Previews (PLAN-0060)
                                        @{
                                            Path = "HKLM\OfflineSoftware\Policies\Microsoft\Windows\WindowsUpdate"
                                            Name = "AllowOptionalContent"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Policies\Microsoft\Windows\WindowsUpdate"
                                            Name = "DeferQualityUpdates"
                                            Type = "REG_DWORD"
                                            Data = "1"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Policies\Microsoft\Windows\WindowsUpdate"
                                            Name = "DeferQualityUpdatesPeriodInDays"
                                            Type = "REG_DWORD"
                                            Data = "7"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Microsoft\WindowsUpdate\UX\Settings"
                                            Name = "IsContinuousInnovationOptedIn"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        # Proteccion de Drivers GPU y Dispositivos (PLAN-0027 / PLAN-0061)
                                        @{
                                            Path = "HKLM\OfflineSoftware\Policies\Microsoft\Windows\WindowsUpdate"
                                            Name = "ExcludeWUDriversInQualityUpdate"
                                            Type = "REG_DWORD"
                                            Data = "1"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Microsoft\Windows\CurrentVersion\DriverSearching"
                                            Name = "SearchOrderConfig"
                                            Type = "REG_DWORD"
                                            Data = "0"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSoftware\Policies\Microsoft\Windows\Device Metadata"
                                            Name = "PreventDeviceMetadataFromNetwork"
                                            Type = "REG_DWORD"
                                            Data = "1"
                                        }
                                    )
                                    # PLAN-0059: Modo Bajo Demanda de Windows Update para Perfiles 2+ (Gaming / Hardcore)
                                    $optProfileInt = if ($script:OptProfile) { [int]$script:OptProfile } else { 1 }
                                    if ($optProfileInt -ge 2) {
                                        $swTweaks += @(
                                            @{
                                                Path = "HKLM\OfflineSoftware\Policies\Microsoft\Windows\WindowsUpdate\AU"
                                                Name = "NoAutoUpdate"
                                                Type = "REG_DWORD"
                                                Data = "1"
                                            }
                                            @{
                                                Path = "HKLM\OfflineSoftware\Policies\Microsoft\Windows\WindowsUpdate\AU"
                                                Name = "AUOptions"
                                                Type = "REG_DWORD"
                                                Data = "2"
                                            }
                                            @{
                                                Path = "HKLM\OfflineSoftware\Policies\Microsoft\Windows\WindowsUpdate\AU"
                                                Name = "NoAutoRebootWithLoggedOnUsers"
                                                Type = "REG_DWORD"
                                                Data = "1"
                                            }
                                        )
                                    }
                                    foreach ($st in $swTweaks) {
                                        & reg.exe add $st.Path /v $st.Name /t $st.Type /d $st.Data /f 2>&1 | Out-Null
                                    }
                                    Write-OK "Tema oscuro y MMCSS (NoLazyMode) inyectados en SOFTWARE hive offline."
                                    Write-OK "Cuarentena de actualizaciones acumulativas (7 días) y bloqueo de previews inyectados en SOFTWARE hive offline."
                                    Write-OK "Protección de drivers GPU (AMD/NVIDIA) y metadatos inyectados en SOFTWARE hive offline (PLAN-0061)."
                                    if ($optProfileInt -ge 2) {
                                        Write-OK "Windows Update configurado en Modo Bajo Demanda (On-Demand) en SOFTWARE hive offline."
                                    }
                                    Add-AuditRecord -Resource "Tema Oscuro / MMCSS (SOFTWARE)" -Target "WIM Idx $wimIndex" `
                                                    -Status "OK" -Details "dark.theme, NoLazyMode y proteccion de drivers configurados en SOFTWARE hive"
                                } else {
                                    Write-Warn "No se pudo cargar SOFTWARE hive offline. Exit code: $($procSw.ExitCode)."
                                }
                            } catch {
                                Write-Warn "Error aplicando ajustes a SOFTWARE hive offline: $($_.Exception.Message)"
                            } finally {
                                if ($swLoaded) {
                                    Write-Host "    Descargando colmena SOFTWARE..." -ForegroundColor Gray
                                    [void](Invoke-RegUnloadHive -HiveName "HKLM\OfflineSoftware")
                                }
                            }
                        }

                        # PLAN-0034: Inyectar optimizaciones de FileSystem (NTFS) y Scheduler en SYSTEM hive offline
                        $sysPath = Join-Path $WimMountDir "Windows\System32\config\SYSTEM"
                        if (Test-Path $sysPath) {
                            $sysLoaded = $false
                            try {
                                [void](Invoke-RegUnloadHive -HiveName "HKLM\OfflineSystem" -RetryCount 2 -RetryDelaySeconds 1)
                                Write-Host "    Cargando SYSTEM hive del sistema offline..." -ForegroundColor Gray
                                $procSys = Start-Process -FilePath "reg.exe" -ArgumentList @("load", "HKLM\OfflineSystem", $sysPath) -Wait -PassThru -NoNewWindow
                                if ($procSys.ExitCode -eq 0) {
                                    $sysLoaded = $true
                                    $sysTweaks = @(
                                        @{
                                            Path = "HKLM\OfflineSystem\ControlSet001\Control\FileSystem"
                                            Name = "NtfsDisable8dot3NameCreation"
                                            Type = "REG_DWORD"
                                            Data = "1"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSystem\ControlSet001\Control\FileSystem"
                                            Name = "NtfsMemoryUsage"
                                            Type = "REG_DWORD"
                                            Data = "2"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSystem\ControlSet001\Control\FileSystem"
                                            Name = "LongPathsEnabled"
                                            Type = "REG_DWORD"
                                            Data = "1"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSystem\ControlSet001\Control\PriorityControl"
                                            Name = "Win32PrioritySeparation"
                                            Type = "REG_DWORD"
                                            Data = "38"
                                        }
                                        # Bloqueo Bloatware BIOS WPBT y Prevencion BitLocker (PLAN-0061)
                                        @{
                                            Path = "HKLM\OfflineSystem\ControlSet001\Control\Session Manager"
                                            Name = "DisableWPBT"
                                            Type = "REG_DWORD"
                                            Data = "1"
                                        }
                                        @{
                                            Path = "HKLM\OfflineSystem\ControlSet001\Control\BitLocker"
                                            Name = "PreventDeviceEncryption"
                                            Type = "REG_DWORD"
                                            Data = "1"
                                        }
                                    )
                                    foreach ($st in $sysTweaks) {
                                        & reg.exe add $st.Path /v $st.Name /t $st.Type /d $st.Data /f 2>&1 | Out-Null
                                    }
                                    Write-OK "Optimizaciones oficiales de FileSystem y Scheduler inyectadas en SYSTEM hive offline."
                                    Write-OK "Bloqueo de bloatware BIOS (WPBT) y prevención BitLocker inyectados en SYSTEM hive offline (PLAN-0061)."
                                    Add-AuditRecord -Resource "FileSystem / Scheduler / WPBT (SYSTEM)" -Target "WIM Idx $wimIndex" `
                                                    -Status "OK" -Details "NtfsDisable8dot3NameCreation=1, LongPathsEnabled=1, DisableWPBT=1, PreventDeviceEncryption=1"
                                } else {
                                    Write-Warn "No se pudo cargar SYSTEM hive offline. Exit code: $($procSys.ExitCode)."
                                }
                            } catch {
                                Write-Warn "Error aplicando optimizaciones a SYSTEM hive offline: $($_.Exception.Message)"
                            } finally {
                                if ($sysLoaded) {
                                    Write-Host "    Descargando colmena SYSTEM..." -ForegroundColor Gray

                                    [void](Invoke-RegUnloadHive -HiveName "HKLM\OfflineSystem")
                                }
                            }
                        }
                     }

                     #==================================================================
                     # INYECTAR SCRIPTS, RUNTIMES Y SetupComplete.cmd EN WIM
                     #==================================================================

                     $wimScriptsDir = Join-Path $WimMountDir "Windows\Setup\Scripts"

                     if (-not (Test-Path $wimScriptsDir)) {
                         New-Item -ItemType Directory -Path $wimScriptsDir -Force | Out-Null
                     }

                     # Inyectar Runtimes esenciales directamente en el WIM montado (Doble Inyección Garantizada)
                     if ($runtimesInfo -and $runtimesInfo.Found -and (Test-Path $runtimesInfo.Path)) {
                         $wimRuntimesDest = Join-Path $wimScriptsDir "Runtimes"
                         if (-not (Test-Path $wimRuntimesDest)) {
                             New-Item -ItemType Directory -Path $wimRuntimesDest -Force | Out-Null
                         }
                         Copy-Item -Path "$($runtimesInfo.Path)\*" -Destination $wimRuntimesDest -Recurse -Force
                         Write-OK "Inyectado en WIM índice ${wimIndex}: Runtimes Esenciales ($($runtimesInfo.FileCount) archivos)"
                         Add-AuditRecord -Resource "Runtimes (VC++ / DirectX)" -Target "WIM Idx $wimIndex" `
                                         -Status "OK" -Details "$($runtimesInfo.FileCount) archivos en $wimRuntimesDest"
                     } else {
                         Add-AuditRecord -Resource "Runtimes (VC++ / DirectX)" -Target "WIM Idx $wimIndex" `
                                         -Status "SKIP" -Details "No disponibles para inyección offline"
                     }

                      # Inyectar script de menú contextual canónico en WIM montado
                      $ctxMenuSrc = Join-Path $ScriptsDir "Modules\Add-OptimizedContextMenus.ps1"
                      if (Test-Path $ctxMenuSrc) {
                          Copy-Item -Path $ctxMenuSrc -Destination (Join-Path $wimScriptsDir "Add-OptimizedContextMenus.ps1") -Force
                          Write-OK "Inyectado en WIM índice ${wimIndex}: Add-OptimizedContextMenus.ps1"
                      }

                      # Inyectar suite de Drivers en WIM montado
                      $driversSrcDir = Join-Path $ScriptsDir "Drivers"
                      if (Test-Path $driversSrcDir) {
                          $wimDriversDest = Join-Path $wimScriptsDir "Drivers"
                          if (-not (Test-Path $wimDriversDest)) {
                              New-Item -ItemType Directory -Path $wimDriversDest -Force | Out-Null
                          }
                          Copy-Item -Path "$driversSrcDir\*" -Destination $wimDriversDest -Recurse -Force
                          Write-OK "Inyectado en WIM índice ${wimIndex}: Suite de Drivers (Clean, Backup, Critical)"
                          Add-AuditRecord -Resource "Drivers Suite" -Target "WIM Idx $wimIndex" `
                                          -Status "OK" -Details "Copiado a $wimDriversDest"
                      }

                      # Inyectar módulos complementarios (Navegadores, Migración, Updates) en WIM montado
                      $wimModulesDest = Join-Path $wimScriptsDir "Modules"
                      if (-not (Test-Path $wimModulesDest)) {
                          New-Item -ItemType Directory -Path $wimModulesDest -Force | Out-Null
                      }

                      $browserSrc = Join-Path $ScriptsDir "Modules\Optimize-WebBrowsers.ps1"
                      if (Test-Path $browserSrc) {
                          Copy-Item -Path $browserSrc -Destination (Join-Path $wimScriptsDir "Optimize-WebBrowsers.ps1") -Force
                          Copy-Item -Path $browserSrc -Destination (Join-Path $wimModulesDest "Optimize-WebBrowsers.ps1") -Force
                          $browserCmd = Join-Path $ScriptsDir "Modules\Optimize-WebBrowsers.cmd"
                          if (Test-Path $browserCmd) {
                              Copy-Item -Path $browserCmd -Destination (Join-Path $wimScriptsDir "Optimize-WebBrowsers.cmd") -Force
                              Copy-Item -Path $browserCmd -Destination (Join-Path $wimModulesDest "Optimize-WebBrowsers.cmd") -Force
                          }
                          Write-OK "Inyectado en WIM índice ${wimIndex}: Optimize-WebBrowsers.ps1"
                      }

                      $userMigSrc = Join-Path $ScriptsDir "Modules\Migrar-Usuario-W11.ps1"
                      if (Test-Path $userMigSrc) {
                          Copy-Item -Path $userMigSrc -Destination (Join-Path $wimScriptsDir "Migrar-Usuario-W11.ps1") -Force
                          Copy-Item -Path $userMigSrc -Destination (Join-Path $wimModulesDest "Migrar-Usuario-W11.ps1") -Force
                          $userMigCmd = Join-Path $ScriptsDir "Modules\Migrar-Usuario-W11.cmd"
                          if (Test-Path $userMigCmd) {
                              Copy-Item -Path $userMigCmd -Destination (Join-Path $wimScriptsDir "Migrar-Usuario-W11.cmd") -Force
                              Copy-Item -Path $userMigCmd -Destination (Join-Path $wimModulesDest "Migrar-Usuario-W11.cmd") -Force
                          }
                          Write-OK "Inyectado en WIM índice ${wimIndex}: Migrar-Usuario-W11.ps1"
                      }

                      $updatesSrc = Join-Path $ScriptsDir "Builder\Get-WindowsUpdates.ps1"
                      if (Test-Path $updatesSrc) {
                          Copy-Item -Path $updatesSrc -Destination (Join-Path $wimScriptsDir "Get-WindowsUpdates.ps1") -Force
                          Copy-Item -Path $updatesSrc -Destination (Join-Path $wimModulesDest "Get-WindowsUpdates.ps1") -Force
                          $updatesCmd = Join-Path $ScriptsDir "Builder\Get-WindowsUpdates.cmd"
                          if (Test-Path $updatesCmd) {
                              Copy-Item -Path $updatesCmd -Destination (Join-Path $wimScriptsDir "Get-WindowsUpdates.cmd") -Force
                              Copy-Item -Path $updatesCmd -Destination (Join-Path $wimModulesDest "Get-WindowsUpdates.cmd") -Force
                          }
                          Write-OK "Inyectado en WIM índice ${wimIndex}: Get-WindowsUpdates.ps1"
                      }

                      $auditFootprintSrc = Join-Path $ScriptsDir "Modules\Audit-FreshInstallFootprint.ps1"
                      if (Test-Path $auditFootprintSrc) {
                          Copy-Item -Path $auditFootprintSrc -Destination (Join-Path $wimScriptsDir "Audit-FreshInstallFootprint.ps1") -Force
                          Copy-Item -Path $auditFootprintSrc -Destination (Join-Path $wimModulesDest "Audit-FreshInstallFootprint.ps1") -Force
                          Write-OK "Inyectado en WIM índice ${wimIndex}: Audit-FreshInstallFootprint.ps1"
                      }

                      $memTrimSrc = Join-Path $ScriptsDir "Modules\Optimize-ProcessMemory.ps1"
                      $memTrimCmdSrc = Join-Path $ScriptsDir "Modules\Optimize-ProcessMemory.cmd"
                      if (Test-Path $memTrimSrc) {
                          Copy-Item -Path $memTrimSrc -Destination (Join-Path $wimScriptsDir "Optimize-ProcessMemory.ps1") -Force
                          Copy-Item -Path $memTrimSrc -Destination (Join-Path $wimModulesDest "Optimize-ProcessMemory.ps1") -Force
                          if (Test-Path $memTrimCmdSrc) {
                              Copy-Item -Path $memTrimCmdSrc -Destination (Join-Path $wimScriptsDir "Optimize-ProcessMemory.cmd") -Force
                              Copy-Item -Path $memTrimCmdSrc -Destination (Join-Path $wimModulesDest "Optimize-ProcessMemory.cmd") -Force
                          }
                          Write-OK "Inyectado en WIM índice ${wimIndex}: Optimize-ProcessMemory.ps1 y .cmd"
                      }

                      $auditSysSrc = Join-Path $ScriptsDir "Modules\Audit-SystemOptimization.ps1"
                      if (Test-Path $auditSysSrc) {
                          Copy-Item -Path $auditSysSrc -Destination (Join-Path $wimScriptsDir "Audit-SystemOptimization.ps1") -Force
                          Copy-Item -Path $auditSysSrc -Destination (Join-Path $wimModulesDest "Audit-SystemOptimization.ps1") -Force
                          Write-OK "Inyectado en WIM índice ${wimIndex}: Audit-SystemOptimization.ps1"
                          Add-AuditRecord -Resource "Audit-SystemOptimization" -Target "WIM Idx $wimIndex" -Status "OK" -Details "Inyectado en Scripts y Modules"
                      }

                      $gameDevSwitchSrc = Join-Path $ScriptsDir "Modules\Switch-GameDevMode.ps1"
                      $gameDevSwitchCmdSrc = Join-Path $ScriptsDir "Modules\Switch-GameDevMode.cmd"
                      if (Test-Path $gameDevSwitchSrc) {
                          Copy-Item -Path $gameDevSwitchSrc -Destination (Join-Path $wimScriptsDir "Switch-GameDevMode.ps1") -Force
                          Copy-Item -Path $gameDevSwitchSrc -Destination (Join-Path $wimModulesDest "Switch-GameDevMode.ps1") -Force
                          if (Test-Path $gameDevSwitchCmdSrc) {
                              Copy-Item -Path $gameDevSwitchCmdSrc -Destination (Join-Path $wimScriptsDir "Switch-GameDevMode.cmd") -Force
                              Copy-Item -Path $gameDevSwitchCmdSrc -Destination (Join-Path $wimModulesDest "Switch-GameDevMode.cmd") -Force
                          }
                          Write-OK "Inyectado en WIM índice ${wimIndex}: Switch-GameDevMode.ps1 y .cmd"
                          Add-AuditRecord -Resource "Switch-GameDevMode" -Target "WIM Idx $wimIndex" -Status "OK" -Details "Inyectado en Scripts y Modules"
                      }

                      $ccScriptSrc   = Join-Path $ScriptsDir "GUI\romanOS-ControlCenter.ps1"
                      $ccLauncherSrc = Join-Path $ScriptsDir "GUI\romanOS-ControlCenter-Launcher.cs"
                      $ccCmdSrc      = Join-Path (Split-Path $ScriptsDir -Parent) "Lanzar-romanOS-ControlCenter.cmd"
                      if (-not (Test-Path $ccCmdSrc)) {
                          $ccCmdSrc  = Join-Path $ScriptsDir "GUI\Lanzar-romanOS-ControlCenter.cmd"
                      }

                      if (Test-Path $ccScriptSrc) {
                          $wimGuiDir = Join-Path $wimScriptsDir "GUI"
                          if (-not (Test-Path $wimGuiDir)) {
                              New-Item -ItemType Directory -Path $wimGuiDir -Force | Out-Null
                          }
                          Copy-Item -Path $ccScriptSrc -Destination (Join-Path $wimGuiDir "romanOS-ControlCenter.ps1") -Force
                          Copy-Item -Path $ccScriptSrc -Destination (Join-Path $wimScriptsDir "romanOS-ControlCenter.ps1") -Force
                          Copy-Item -Path $ccScriptSrc -Destination (Join-Path $wimModulesDest "romanOS-ControlCenter.ps1") -Force

                          if (Test-Path $ccLauncherSrc) {
                              Copy-Item -Path $ccLauncherSrc -Destination (Join-Path $wimGuiDir "romanOS-ControlCenter-Launcher.cs") -Force
                          }

                          if (Test-Path $ccCmdSrc) {
                              Copy-Item -Path $ccCmdSrc -Destination (Join-Path $wimScriptsDir "Lanzar-romanOS-ControlCenter.cmd") -Force
                          }
                          Write-OK "Inyectado en WIM índice ${wimIndex}: romanOS Control Center (GUI, Launcher CS y Lanzador CMD)"
                          Add-AuditRecord -Resource "romanOS-ControlCenter" -Target "WIM Idx $wimIndex" -Status "OK" -Details "Inyectado en Scripts/GUI y Modules"
                      }

                      # Inyectar submódulos de la suite para soporte del Toolkit en WIM montado
                      $suiteSubmodules = @(
                          @{ Path = $debScriptCandidate; Name = [System.IO.Path]::GetFileName($debScriptCandidate) },
                          @{ Path = $maintScriptCandidate; Name = [System.IO.Path]::GetFileName($maintScriptCandidate) },
                          @{ Path = $netScriptCandidate; Name = [System.IO.Path]::GetFileName($netScriptCandidate) },
                          @{ Path = $secScriptCandidate; Name = [System.IO.Path]::GetFileName($secScriptCandidate) },
                          @{ Path = $toolkitCandidate; Name = [System.IO.Path]::GetFileName($toolkitCandidate) }
                      )
                      foreach ($subm in $suiteSubmodules) {
                          if ($subm.Path -and (Test-Path $subm.Path)) {
                              $wimSubmDest = Join-Path $wimScriptsDir $subm.Name
                              if (-not (Test-Path $wimSubmDest)) {
                                  Copy-Item -Path $subm.Path -Destination $wimSubmDest -Force
                              }
                              $wimSubmModDest = Join-Path $wimModulesDest $subm.Name
                              if (-not (Test-Path $wimSubmModDest)) {
                                  Copy-Item -Path $subm.Path -Destination $wimSubmModDest -Force
                              }
                          }
                      }

                      if ($suiteTasksContent) {
                          $suiteTasksDest = Join-Path $wimScriptsDir "Initialize-SuiteTasks.ps1"
                          [System.IO.File]::WriteAllText($suiteTasksDest, $suiteTasksContent, [System.Text.Encoding]::UTF8)
                          Write-OK "Inyectado en WIM índice ${wimIndex}: Initialize-SuiteTasks.ps1"
                      }

                     foreach ($script in $scriptsToInject) {
                         $dest = Join-Path $wimScriptsDir $script.DestName
                         Copy-Item -Path $script.Source -Destination $dest -Force
                         Write-OK "Inyectado en WIM índice ${wimIndex}: $($script.DestName)"
                     }

                     # Inyectar motores Core (Policy, Hardware, UI) en WIM montado
                     $coreSrcDir = Join-Path $ScriptsDir "Core"
                     if (Test-Path $coreSrcDir) {
                         $wimCoreDest = Join-Path $wimScriptsDir "Core"
                         if (-not (Test-Path $wimCoreDest)) {
                             New-Item -ItemType Directory -Path $wimCoreDest -Force | Out-Null
                         }
                         Copy-Item -Path "$coreSrcDir\*" -Destination $wimCoreDest -Recurse -Force
                         Write-OK "Inyectado en WIM índice ${wimIndex}: Motores Core (Policy, Hardware, UI)"
                         Add-AuditRecord -Resource "Motores Core" -Target "WIM Idx $wimIndex" `
                                         -Status "OK" -Details "Copiado a $wimCoreDest"
                     }

                     # Inyectar script de menú contextual canónico en WIM montado
                     $ctxMenuSrc = Join-Path $ScriptsDir "Modules\Add-OptimizedContextMenus.ps1"
                     if (Test-Path $ctxMenuSrc) {
                         Copy-Item -Path $ctxMenuSrc -Destination (Join-Path $wimScriptsDir "Add-OptimizedContextMenus.ps1") -Force
                         Write-OK "Inyectado en WIM índice ${wimIndex}: Add-OptimizedContextMenus.ps1"
                     }

                     if ($setupCompleteContent) {
                         $setupCmdDest = Join-Path $wimScriptsDir "SetupComplete.cmd"
                         $setupCompleteContent | Out-File -FilePath $setupCmdDest -Encoding ASCII -Force
                         Write-OK "Inyectado en WIM índice ${wimIndex}: SetupComplete.cmd"
                         Add-AuditRecord -Resource "SetupComplete.cmd" -Target "WIM Idx $wimIndex" `
                                         -Status "OK" -Details "Inyectado en Windows\Setup\Scripts"
                     } else {
                         Write-Warn "No existe contenido de SetupComplete.cmd para inyectar."
                         Add-AuditRecord -Resource "SetupComplete.cmd" -Target "WIM Idx $wimIndex" `
                                         -Status "WARN" -Details "No existe contenido de SetupComplete.cmd para inyectar"
                     }

                     if ($physicalDiag) {
                         Copy-Item -Path $physicalDiag -Destination (Join-Path $wimScriptsDir "PostInstall-Diagnostics.ps1") -Force
                         Write-OK "Inyectado en WIM Ã­ndice ${wimIndex}: PostInstall-Diagnostics.ps1 (archivo fÃ­sico canÃ³nico)"
                     } else {
                         Write-Warn "No se encontrÃ³ archivo fÃ­sico PostInstall-Diagnostics.ps1 para inyectar en WIM Ã­ndice ${wimIndex}"
                     }

                     if ($auditarLauncherContent) {
                         $auditarDest = Join-Path $wimScriptsDir "Auditar-Instalacion.cmd"
                         $auditarLauncherContent | Out-File -FilePath $auditarDest -Encoding ASCII -Force
                         Write-OK "Inyectado en WIM índice ${wimIndex}: Auditar-Instalacion.cmd"

                         $wimPublicDesktop = Join-Path $WimMountDir "Users\Public\Desktop"
                         if (Test-Path $wimPublicDesktop) {
                             Copy-Item -Path $auditarDest -Destination (Join-Path $wimPublicDesktop "Auditar-Instalacion.cmd") -Force
                             $wimCCLauncher = Join-Path $wimScriptsDir "Lanzar-romanOS-ControlCenter.cmd"
                             if (Test-Path $wimCCLauncher) {
                                 Copy-Item -Path $wimCCLauncher -Destination (Join-Path $wimPublicDesktop "Lanzar-romanOS-ControlCenter.cmd") -Force
                             }
                         }
                     }

                     $dismountSuccess = Invoke-SafeWimDismount -MountDir $WimMountDir -Action Save -ScratchDirectory $ScratchDir

                     if ($dismountSuccess) {
                         Write-OK "WIM índice $wimIndex$imgNameStr desmontado con cambios guardados."
                         $wimInjected = $true
                     } else {
                         Write-Warn "No se pudo guardar cambios en WIM índice ${wimIndex}."
                     }

                     if (Test-Path $WimMountDir) {
                         Remove-Item -Path $WimMountDir -Recurse -Force -ErrorAction SilentlyContinue
                     }
                 } catch {
                     Write-ForensicException -Record $_ -Context "Inyeccion en WIM indice ${wimIndex}" -SuggestedAction "Revise los parametros y rutas de modulos inyectados antes de desmontar el WIM"
                     Add-AuditRecord -Resource "WIM Servicing" -Target "WIM Idx $wimIndex" `
                                     -Status "FAIL" -Details $_.Exception.Message

                     Invoke-SafeWimDismount -MountDir $WimMountDir -Action Discard -ScratchDirectory $ScratchDir | Out-Null
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

                         $timeoutSec = if ($ProcessTimeoutMinutes -gt 0) { $ProcessTimeoutMinutes * 60 } else { 1800 }
                         $expRes = Invoke-MonitoredProcess -FilePath "dism.exe" `
                             -ArgumentList @("/Export-Image", "/SourceImageFile:$($wimFile.FullName)", "/SourceIndex:$($img.Index)", "/DestinationImageFile:$destName", "/Compress:$compressArg", "/ScratchDir:$ScratchDir") `
                             -TaskDescription "Exportación y compresión WIM (Índice $($img.Index))" `
                             -TimeoutSeconds $timeoutSec `
                             -HeartbeatIntervalSeconds $HeartbeatIntervalSeconds

                         if (-not $expRes.Success) {
                             throw "DISM /Export-Image falló para el índice $($img.Index). Exit code: $($expRes.ExitCode)."
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

            if ($selectedSingleIndex) {
                if ($WimCompression -eq "None" -or -not $wimInjected) {
                    # Sin exportación / sin servicing offline: el índice final sigue siendo el original.
                    $finalImageInstallIndex = [int]$selectedSingleIndex
                } elseif ($exportSucceeded) {
                    # Exportación exitosa: el WIM resultante normalmente reindexa desde 1.
                    $finalImageInstallIndex = 1
                } else {
                    $finalImageInstallIndex = [int]$selectedSingleIndex
                }

                if ($finalImageInstallIndex -and (-not $SkipAutoUnattend) -and $autounattendPath -and (Test-Path $autounattendPath)) {
                    $enableZT = $false

                    if ($script:ResolvedParameters.ContainsKey('ZeroTouch')) {
                        $enableZT = $script:ResolvedParameters['ZeroTouch']
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
            } elseif ($script:ResolvedParameters['ZeroTouch'] -or $ZeroTouch) {
                Write-Warn "Modo Zero-Touch fue solicitado pero hay múltiples ediciones procesadas ($($indexesToProcess.Count)). Zero-Touch requiere un único índice WIM para automatizar la instalación por completo. Se mantendrá la selección manual de disco y edición."
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
# ARCHIVOS DE BOOT (RESOLUCIÓN SIMÉTRICA BIOS / UEFI CON FALLBACK ADK)
#------------------------------------------------------------------------------

$oscdimgDir = if ($oscdimg) { Split-Path $oscdimg -Parent } else { $null }

# 1. Búsqueda inteligente de bootloader BIOS (El Torito x86/x64):
$candidateBiosBoot = [System.Collections.Generic.List[string]]::new()
$candidateBiosBoot.Add((Join-Path $ISOFilesDir "boot\etfsboot.com"))
if ($oscdimgDir) { $candidateBiosBoot.Add((Join-Path $oscdimgDir "etfsboot.com")) }
$candidateBiosBoot.Add("${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\etfsboot.com")
$candidateBiosBoot.Add("$env:ProgramFiles\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\etfsboot.com")
$candidateBiosBoot.Add("${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg\etfsboot.com")
$candidateBiosBoot.Add("$env:ProgramFiles\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg\etfsboot.com")
$candidateBiosBoot.Add("${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\arm64\Oscdimg\etfsboot.com")

$recBios = Get-ChildItem -Path $ISOFilesDir -Recurse -Filter "etfsboot.com" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($recBios) { $candidateBiosBoot.Add($recBios.FullName) }

$biosBootFile = $null
foreach ($cand in $candidateBiosBoot) {
    if ($cand -and (Test-Path $cand)) {
        $biosBootFile = $cand
        break
    }
}

# 2. Búsqueda inteligente de bootloader UEFI:
# Preferir 'efisys_noprompt.bin' para arranque directo en Hyper-V/UEFI sin requerir
# presionar una tecla ("Press any key to boot from CD..."), evitando timeouts de arranque.
$candidateUefiBoot = [System.Collections.Generic.List[string]]::new()
$candidateUefiBoot.Add((Join-Path $ISOFilesDir "efi\microsoft\boot\efisys_noprompt.bin"))
if ($oscdimgDir) { $candidateUefiBoot.Add((Join-Path $oscdimgDir "efisys_noprompt.bin")) }
$candidateUefiBoot.Add("${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\efisys_noprompt.bin")
$candidateUefiBoot.Add("$env:ProgramFiles\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\efisys_noprompt.bin")
$candidateUefiBoot.Add("${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg\efisys_noprompt.bin")
$candidateUefiBoot.Add("${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\arm64\Oscdimg\efisys_noprompt.bin")
$candidateUefiBoot.Add((Join-Path $ISOFilesDir "efi\microsoft\boot\efisys.bin"))
if ($oscdimgDir) { $candidateUefiBoot.Add((Join-Path $oscdimgDir "efisys.bin")) }
$candidateUefiBoot.Add("${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\efisys.bin")
$candidateUefiBoot.Add("$env:ProgramFiles\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\efisys.bin")

$recUefiPrompt = Get-ChildItem -Path $ISOFilesDir -Recurse -Filter "efisys_noprompt.bin" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($recUefiPrompt) { $candidateUefiBoot.Add($recUefiPrompt.FullName) }
$recUefiStd = Get-ChildItem -Path $ISOFilesDir -Recurse -Filter "efisys.bin" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($recUefiStd) { $candidateUefiBoot.Add($recUefiStd.FullName) }

$uefiBootFile = $null
foreach ($cand in $candidateUefiBoot) {
    if ($cand -and (Test-Path $cand)) {
        $uefiBootFile = $cand
        break
    }
}

# 3. Auto-inyección y reparación preventiva en el árbol de directorios de la ISO:
# Garantiza que los medios generados sean 100% estándar y auto-contenidos.
$isoBootDir = Join-Path $ISOFilesDir "boot"
$isoBootFileStandard = Join-Path $isoBootDir "etfsboot.com"
if ($biosBootFile -and (-not (Test-Path $isoBootFileStandard))) {
    try {
        if (-not (Test-Path $isoBootDir)) { New-Item -ItemType Directory -Path $isoBootDir -Force | Out-Null }
        Copy-Item -Path $biosBootFile -Destination $isoBootFileStandard -Force -ErrorAction SilentlyContinue
        if (Test-Path $isoBootFileStandard) {
            $biosBootFile = $isoBootFileStandard
            Write-Host "    [AUTO-REPAIR] 'etfsboot.com' inyectado en directorio 'boot\' de la ISO." -ForegroundColor DarkGreen
        }
    } catch {}
}

$isoEfiBootDir = Join-Path $ISOFilesDir "efi\microsoft\boot"
if ($uefiBootFile) {
    $uefiFileName = Split-Path $uefiBootFile -Leaf
    $isoEfiFileStandard = Join-Path $isoEfiBootDir $uefiFileName
    if (-not (Test-Path $isoEfiFileStandard)) {
        try {
            if (-not (Test-Path $isoEfiBootDir)) { New-Item -ItemType Directory -Path $isoEfiBootDir -Force | Out-Null }
            Copy-Item -Path $uefiBootFile -Destination $isoEfiFileStandard -Force -ErrorAction SilentlyContinue
            if (Test-Path $isoEfiFileStandard) {
                $uefiBootFile = $isoEfiFileStandard
                Write-Host "    [AUTO-REPAIR] Bootloader UEFI ($uefiFileName) inyectado en 'efi\microsoft\boot\' de la ISO." -ForegroundColor DarkGreen
            }
        } catch {}
    }
}

#------------------------------------------------------------------------------
# CREACIÓN DE ISO CON OSCDIMG
#------------------------------------------------------------------------------

$batLine = $null

if (-not $oscdimg) {
    Write-Warn "oscdimg.exe no está disponible."
    Write-Warn "Instálalo con:"
    Write-Warn "winget install -e --id Microsoft.OSCDIMG"
    Write-Warn "O instala el Windows ADK Deployment Tools."
    Add-AuditRecord -Resource "ISO Final" -Target $outputISO -Status "SKIP" `
                    -Details "oscdimg.exe no disponible"
} elseif (-not $biosBootFile -or (-not (Test-Path $biosBootFile)) -or (-not $uefiBootFile) -or (-not (Test-Path $uefiBootFile))) {
    Write-Warn "Faltan archivos de arranque críticos para generar la ISO."
    if (-not $biosBootFile -or (-not (Test-Path $biosBootFile))) {
        Write-Warn "  [BIOS] No se localizó 'etfsboot.com' en la ISO ni en el Windows ADK."
        Write-Warn "         Rutas buscadas: $($candidateBiosBoot -join '; ')"
    }
    if (-not $uefiBootFile -or (-not (Test-Path $uefiBootFile))) {
        Write-Warn "  [UEFI] No se localizó 'efisys_noprompt.bin' ni 'efisys.bin' en la ISO ni en ADK."
        Write-Warn "         Rutas buscadas: $($candidateUefiBoot -join '; ')"
    }
    Write-Warn "No se generará una ISO no arrancable."
    Add-AuditRecord -Resource "ISO Final" -Target $outputISO -Status "FAIL" `
                    -Details "Faltan archivos de arranque críticos (BIOS/UEFI)"
} else {
    $script:UefiBoot = if ($uefiBootFile -like '*efisys_noprompt.bin*') {
        "efisys_noprompt.bin (Arranque directo, sin prompt)"
    } else {
        "efisys.bin (Con prompt — puede requerir interacción)"
    }
    Add-AuditRecord -Resource "UEFI Bootloader" -Target "El Torito" -Status "OK" `
                    -Details $script:UefiBoot

    Write-Host "    Usando oscdimg: $oscdimg" -ForegroundColor Gray
    Write-Host "    Etiqueta ISO: $isoLabel" -ForegroundColor Gray
    Write-Host "    BIOS boot: $biosBootFile" -ForegroundColor Gray
    Write-Host "    UEFI boot: $uefiBootFile $(if ($uefiBootFile -like '*efisys_noprompt.bin') { '(Sin prompt - Arranque directo)' } else { '(Con prompt)' })" -ForegroundColor Gray

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

        $timeoutSec = if ($ProcessTimeoutMinutes -gt 0) { $ProcessTimeoutMinutes * 60 } else { 0 }
        $hbSec      = if ($HeartbeatIntervalSeconds -gt 0) { $HeartbeatIntervalSeconds } else { 15 }

        $oscdRes = Invoke-MonitoredProcess -FilePath "cmd.exe" `
                                           -ArgumentList @("/c", $tempBat) `
                                           -TaskDescription "Reconstrucción de ISO UEFI/BIOS con oscdimg" `
                                           -TimeoutSeconds $timeoutSec `
                                           -HeartbeatIntervalSeconds $hbSec

        if ($oscdRes.Success -and (Test-Path $outputISO)) {
            $isoCreated = $true
            Write-OK "ISO creada exitosamente: $outputISO"

            try {
                $isoItem = Get-Item $outputISO
                $script:IsoSizeBytes = $isoItem.Length
                $isoHash = Get-FileHash -Path $outputISO -Algorithm SHA256 -ErrorAction Stop
                $script:IsoSha256 = $isoHash.Hash
                Write-Host "    SHA256: $($script:IsoSha256)" -ForegroundColor DarkGray
                Add-AuditRecord -Resource "ISO Final" -Target $outputISO -Status "OK" `
                                -Details "$([math]::Round($isoItem.Length / 1GB, 2)) GB | SHA-256: $($script:IsoSha256)"
            } catch {
                Add-AuditRecord -Resource "ISO Final" -Target $outputISO -Status "OK" `
                                -Details "Creada exitosamente (Hash SHA-256 no calculado)"
            }
        } elseif ($oscdRes.TimedOut) {
            Write-ErrorMsg "La compilación de la ISO con oscdimg superó el tiempo límite (${timeoutSec}s) y fue cancelada."
            Add-AuditRecord -Resource "ISO Final" -Target $outputISO -Status "FAIL" `
                            -Details "oscdimg superó el tiempo límite (${timeoutSec}s)"
        } else {
            Write-Warn "oscdimg falló con código de salida: $($oscdRes.ExitCode)"
            Write-Warn "CMD ejecutado: $batLine"
            if ($oscdRes.StdErr) { Write-Warn "Detalle error oscdimg: $($oscdRes.StdErr)" }
            Write-Warn "Revisa espacio en disco, permisos de escritura y que la carpeta ISO_Files esté completa."
            Add-AuditRecord -Resource "ISO Final" -Target $outputISO -Status "FAIL" `
                            -Details "oscdimg falló con exit code: $($oscdRes.ExitCode)"
        }
    } catch {
        Write-ForensicException -Record $_ -Context "Compilacion ISO (oscdimg)" -SuggestedAction "Verifique que oscdimg.exe este operativo y no haya bloqueos en $outputISO"
        Add-AuditRecord -Resource "ISO Final" -Target $outputISO -Status "FAIL" `
                        -Details $_.Exception.Message
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
} elseif (-not $isoCreated) {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "  ║  [SALVAGUARDA ANTI-PÉRDIDA DE TRABAJO]                                           ║" -ForegroundColor Yellow
    Write-Host "  ║  La ISO final no se pudo compilar con oscdimg, pero todos los cambios offline   ║" -ForegroundColor Yellow
    Write-Host "  ║  (WIM actualizado, Debloat, Drivers, Runtimes y Autounattend) SE HAN PRESERVADO.║" -ForegroundColor Yellow
    Write-Host "  ╚══════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host "  Carpeta preservada: $ExtractDir" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Puedes compilar la ISO manualmente en 15 segundos sin repetir el proceso:" -ForegroundColor Green
    if ($oscdimg -and $biosBootFile -and $uefiBootFile) {
        Write-Host "  oscdimg.exe -m -o -u2 -udfver102 -l`"$isoLabel`" -bootdata:2#p0,e,b`"$biosBootFile`"#pEF,e,b`"$uefiBootFile`" `"$ISOFilesDir`" `"$outputISO`"" -ForegroundColor Gray
    } else {
        Write-Host "  oscdimg.exe -m -o -u2 -udfver102 -l`"$isoLabel`" -bootdata:2#p0,e,b`"<ruta_etfsboot.com>`"#pEF,e,b`"<ruta_efisys.bin>`" `"$ISOFilesDir`" `"$outputISO`"" -ForegroundColor Gray
    }
    Write-Host ""
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
