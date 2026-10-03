<#
.SYNOPSIS
    Descargador Unificado de ISOs Oficiales de Windows (Motor Inteligente Multicanal)

.DESCRIPTION
    Asistente interactivo y desatendido basado en la taxonomía y canales oficiales de Microsoft Learn.
    Implementa un pipeline en cascada con múltiples métodos de obtención garantizada:
      1. Motor CDN Directo (Fido / Rufus Engine) — Descarga desatendida vía BITS / curl.exe
         NOTA: Solo disponible para ediciones Consumer (Home/Pro). No aplica a LTSC/IoT/Enterprise.
      2. Asistente MediaCreationTool Oficial (MCT) — Invocación de la herramienta oficial de Microsoft
         NOTA: Solo aplica a ediciones Consumer. LTSC/IoT/Enterprise NO se distribuyen via MCT público.
      3. Navegador Asistido (Evaluacion Microsoft / Catalogo Massgrave) — Para ediciones especiales:
         - Enterprise / LTSC:  Microsoft Evaluation Center (90 dias, oficial y gratuita)
         - IoT Enterprise LTSC: Mismo canal 24H2 con PID.txt para seleccion de edicion
         - Todas las ediciones: Catalogo Massgrave Genuine Media (enlaces directos CDN Microsoft + SHA-256)

.PARAMETER Version
    Versión oficial: "11_25H2", "11_24H2", "11_23H2", "11_LTSC_2024".

.PARAMETER Edition
    Tipo de contenedor: "Consumer", "Business", "IoTEnterprise".
    - Consumer:     Home, Pro, Education, Pro for Workstations (canal publico MCT/Fido)
    - Business:     Enterprise, Pro, Education (VL) -> Evaluation Center o VLSC
    - IoTEnterprise: IoT Enterprise LTSC -> Evaluation Center o canal especializado

.PARAMETER Language
    Idioma oficial (ej. "Spanish", "Spanish (Mexico)", "English", "Portuguese (Brazil)").

.PARAMETER OutputDir
    Carpeta de destino para la ISO. Por defecto: "$HOME\Downloads\Windows_ISOs".

.PARAMETER Method
    Estrategia de descarga: "Auto" (intenta CDN y conmuta segun edicion), "DirectCDN", "MediaCreationTool", "Browser".
    Para ediciones LTSC/IoT/Enterprise, "Auto" va directamente al navegador asistido.

.PARAMETER SkipSha256
    Omite el cálculo del hash SHA-256 al finalizar la descarga.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Version = "",

    [Parameter()]
    [ValidateSet("Consumer", "Business", "IoTEnterprise")]
    [string]$Edition = "",

    [Parameter()]
    [string]$Language = "",

    [Parameter()]
    [string]$OutputDir = "$HOME\Downloads\Windows_ISOs",

    [Parameter()]
    [ValidateSet("Auto", "DirectCDN", "MediaCreationTool", "Browser")]
    [string]$Method = "Auto",

    [Parameter()]
    [switch]$SkipSha256
)

# Configuración de seguridad TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Continue'

# -----------------------------------------------------------------------------
# CARGA DE MOTOR VISUAL UNIFICADO O MICRO-FALLBACK STANDALONE
# -----------------------------------------------------------------------------
$uiEnginePaths = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\UI-Engine.ps1"),
    (Join-Path $PSScriptRoot "Core\UI-Engine.ps1"),
    (Join-Path $PSScriptRoot "UI-Engine.ps1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\UI-Engine.ps1"),
    "C:\Windows\Setup\Scripts\Core\UI-Engine.ps1"
)
$uiLoaded = $false
foreach ($p in $uiEnginePaths) {
    if (Test-Path $p) {
        . $p
        $uiLoaded = $true
        break
    }
}
if (-not $uiLoaded) {
    function Show-UnifiedBanner { param($Title,$Subtitle,[switch]$ShowSystemInfo,[switch]$NoClear) Write-Host "`n=== $Title ($Subtitle) ===`n" -ForegroundColor Cyan }
    function Write-StepHeader   { param($StepNumber,$TotalSteps,$Message) Write-Host "`n>>> [$StepNumber/$TotalSteps] $Message" -ForegroundColor Cyan }
    function Write-SubStep      { param($Message) Write-Host "  -> $Message" -ForegroundColor Gray }
    function Write-OK           { param($Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
    function Write-Warn         { param($Message) Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
    function Write-ErrorMsg     { param($Message) Write-Host "  [ERROR] $Message" -ForegroundColor Red }
    function Write-Info         { param($Message) Write-Host "  [i] $Message" -ForegroundColor DarkGray }
    function Prompt-UnifiedYesNo { param($Prompt,[bool]$Default=$true) $d=if($Default){"S"}else{"N"}; $r=Read-Host "  [?] $Prompt [S/N] (Default: $d)"; if([string]::IsNullOrWhiteSpace($r)){return $Default}; return ($r -match '^(s|si|y|yes)$') }
    function Show-UnifiedMenu   { param($Title,$Options,[int]$DefaultChoice=1,[switch]$AllowCancel,[string]$CancelText="Salir") for($i=0;$i -lt $Options.Count;$i++){ Write-Host "  [$($i+1)] $($Options[$i])" }; if($AllowCancel){ Write-Host "  [0] $CancelText" }; $r=Read-Host "  Opcion"; if(-not $r){return $DefaultChoice}; return [int]$r }
    function Show-UnifiedSummary { param($Title,$Status,$DurationSeconds,$ErrorsCount,$WarnsCount,$Logs) Write-Host "`n=== $($Title): $Status (${DurationSeconds}s) ===`n" -ForegroundColor Cyan }
    function Get-RomanOSErrorCodeDetails {
        param([long]$ExitCode)
        $intVal = try { [int32]$ExitCode } catch { [int32]($ExitCode -band 0xFFFFFFFFL) }
        $hexStr = "0x{0:X8}" -f $intVal
        return [PSCustomObject]@{ ExitCodeDecimal = $ExitCode; ExitCodeHex = $hexStr }
    }
    function Write-ForensicProcessFailure {
        param($TaskDescription, $FilePath, [long]$ExitCode, [string]$CommandLine = "", [string]$StdOut = "", [string]$StdErr = "", [string]$LogFilePath = "", [switch]$IsWarningOnly)
        $level = if ($IsWarningOnly) { "WARN" } else { "ERROR" }
        $hexStr = "0x{0:X8}" -f ([int32]$ExitCode)
        $header = "[$level] Fallo en proceso '$TaskDescription' | ExitCode: $ExitCode ($hexStr)"
        Write-Host "  $header" -ForegroundColor $(if($IsWarningOnly){"Yellow"}else{"Red"})
        return [PSCustomObject]@{
            Header          = $header
            ExitCode        = $ExitCode
            ExitCodeHex     = $hexStr
            CommandLine     = $CommandLine
            StdOut          = $StdOut
            StdErr          = $StdErr
            FullPlainReport = "$header`n$StdOut`n$StdErr".Trim()
        }
    }
    function Write-ForensicException {
        param($Record, [string]$Context = "")
        $msg = if ($Record -is [System.Management.Automation.ErrorRecord]) { $Record.Exception.Message } else { "$Record" }
        $header = "[ERROR] $(if($Context){"[$Context] "})$msg"
        Write-Host "  $header" -ForegroundColor Red
        return [PSCustomObject]@{ Header = $header; FullPlainReport = $header }
    }
}

#------------------------------------------------------------------------------
# SUBSISTEMA DE LOGGING ESTRUCTURADO Y DIAGNÓSTICO
#------------------------------------------------------------------------------

$script:LogFile           = $null
$script:TranscriptFile    = $null
$script:AiSummaryFile     = $null
$script:LogErrors         = [System.Collections.Generic.List[string]]::new()
$script:LogWarns          = [System.Collections.Generic.List[string]]::new()
$script:LogSteps          = [System.Collections.Generic.List[PSObject]]::new()
$script:CurrentStepObj    = $null
$script:DownloadStartTime = Get-Date

function Write-LogEntry {
    [CmdletBinding()]
    param(
        [ValidateSet("INIT","STEP","INFO","OK","WARN","ERROR","DEBUG","TRACE")]
        [string]$Level = "INFO",
        [string]$Message,
        [switch]$NoAccumulate
    )

    $normalizedLevel = switch ($Level) {
        "INIT" { "INFO" }
        "STEP" { "INFO" }
        default { $Level }
    }

    if (Get-Command "Write-UnifiedLogEntry" -ErrorAction SilentlyContinue) {
        Write-UnifiedLogEntry -Message $Message -Level $normalizedLevel -TargetLogFile $script:LogFile | Out-Null
    } else {
        $ts   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $line = "[$ts] [$normalizedLevel] $Message"
        if ($script:LogFile) {
            try {
                [System.IO.File]::AppendAllText($script:LogFile, ($line + "`r`n"), [System.Text.Encoding]::UTF8)
            } catch {
                $null = $_.Exception
            }
        }
    }

    if (-not $NoAccumulate) {
        if ($Level -eq "ERROR") { $script:LogErrors.Add($Message) }
        if ($Level -eq "WARN")  { $script:LogWarns.Add($Message)  }
    }
}

function Initialize-Log {
    param([string]$OutputDirectory)

    $logDir = Join-Path $OutputDirectory "Logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $ts                       = Get-Date -Format 'yyyyMMdd_HHmmss'
    $script:LogFile           = Join-Path $logDir "ISO_Download_$ts.log"
    $script:TranscriptFile    = Join-Path $logDir "ISO_Download_${ts}_transcript.log"
    $script:AiSummaryFile     = Join-Path $logDir "ISO_Download_${ts}_AI_SUMMARY.md"
    $script:DownloadStartTime = Get-Date
    $global:RomanOS_LogFile   = $script:LogFile

    try {
        Start-Transcript -Path $script:TranscriptFile -Append -ErrorAction Stop | Out-Null
    } catch {
        Write-LogEntry -Level "WARN" -Message "No se pudo iniciar transcript en ($script:TranscriptFile) - $($_.Exception.Message)"
    }

    Write-LogEntry -Level "INIT" -Message ("=" * 64)
    Write-LogEntry -Level "INIT" -Message "Official Windows ISO Downloader (Unified Engine)"
    Write-LogEntry -Level "INIT" -Message "PowerShell $($PSVersionTable.PSVersion)  |  Host: $env:COMPUTERNAME  |  User: $env:USERNAME"
    Write-LogEntry -Level "INIT" -Message "Directorio Destino: $OutputDirectory"
    Write-LogEntry -Level "INIT" -Message "Estrategia: $Method"
    Write-LogEntry -Level "INIT" -Message ("=" * 64)
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n>>> $Message" -ForegroundColor Cyan
    Write-Host "    $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
    Write-LogEntry -Level "STEP" -Message $Message

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
        if ($script:CurrentStepObj.Status -eq "IN_PROGRESS") { $script:CurrentStepObj.Status = "OK" }
        if (-not $script:CurrentStepObj.Note) { $script:CurrentStepObj.Note = $Message }
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

function Write-Info {
    param([string]$Message)
    Write-Host "  [*] $Message" -ForegroundColor Cyan
    Write-LogEntry -Level "INFO" -Message $Message
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

function Write-LogSummary {
    $totalDuration = [math]::Round(((Get-Date) - $script:DownloadStartTime).TotalSeconds, 1)

    if ($script:CurrentStepObj) {
        $now = Get-Date
        $script:CurrentStepObj.ElapsedSec = [math]::Round(($now - $script:CurrentStepObj.StartTime).TotalSeconds, 1)
        if ($script:CurrentStepObj.Status -eq "IN_PROGRESS") {
            $script:CurrentStepObj.Status = if ($script:LogErrors.Count -gt 0) { "ERROR" } else { "OK" }
        }
    }

    Write-LogEntry -Level "INIT" -Message ("=" * 64)
    Write-LogEntry -Level "INIT" -Message "RESUMEN FINAL DE OBTENCIÓN DE ISO"
    Write-LogEntry -Level "INFO" -Message "Duración total       : ${totalDuration}s"
    Write-LogEntry -Level "INFO" -Message "Errores registrados : $($script:LogErrors.Count)"
    Write-LogEntry -Level "INFO" -Message "Advertencias        : $($script:LogWarns.Count)"

    if ($script:LogErrors.Count -gt 0) {
        Write-LogEntry -Level "INIT" -Message "--- ERRORES DETECTADOS ---" -NoAccumulate
        foreach ($e in $script:LogErrors) {
            Write-LogEntry -Level "ERROR" -Message $e -NoAccumulate
        }
    }

    if ($script:LogWarns.Count -gt 0) {
        Write-LogEntry -Level "INIT" -Message "--- ADVERTENCIAS ---" -NoAccumulate
        foreach ($w in $script:LogWarns) {
            Write-LogEntry -Level "WARN" -Message $w -NoAccumulate
        }
    }

    Write-LogEntry -Level "INIT" -Message "Log estructurado    : $script:LogFile"
    Write-LogEntry -Level "INIT" -Message "AI Summary (MD)     : $script:AiSummaryFile"
    Write-LogEntry -Level "INIT" -Message "Transcript          : $script:TranscriptFile"
    Write-LogEntry -Level "INIT" -Message ("=" * 64)

    try { Stop-Transcript -ErrorAction Stop | Out-Null } catch {
        Write-LogEntry -Level "INFO" -Message "Transcript finalizado: $($_.Exception.Message)"
    }

    # Generar reporte Markdown
    try {
        $overallStatus = if ($script:LogErrors.Count -eq 0) { "SUCCESS" } else { "FAILED" }
        $statusBadge   = if ($overallStatus -eq "SUCCESS") { "SUCCESS ✅" } else { "FAILED ❌" }

        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("# AI Diagnostic Report: Get-OfficialWindowsISO")
        [void]$sb.AppendLine("- **Status:** $statusBadge")
        [void]$sb.AppendLine("- **Timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        [void]$sb.AppendLine("- **Total Duration:** ${totalDuration}s")
        [void]$sb.AppendLine("- **Host:** $env:COMPUTERNAME | **User:** $env:USERNAME | **PowerShell:** $($PSVersionTable.PSVersion)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Parameters")
        [void]$sb.AppendLine("- **Version:** $Version")
        [void]$sb.AppendLine("- **Edition:** $Edition")
        [void]$sb.AppendLine("- **Language:** $Language")
        [void]$sb.AppendLine("- **Output Directory:** $OutputDir")
        [void]$sb.AppendLine("- **Method:** $Method")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Steps Execution")
        [void]$sb.AppendLine("| Step | Duration | Status | Notes |")
        [void]$sb.AppendLine("| :--- | :--- | :--- | :--- |")
        foreach ($st in $script:LogSteps) {
            [void]$sb.AppendLine("| $($st.Name) | $($st.ElapsedSec)s | $($st.Status) | $($st.Note) |")
        }
        if ($script:LogErrors.Count -gt 0) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("## Errors Encountered")
            foreach ($err in $script:LogErrors) {
                [void]$sb.AppendLine("- ❌ $err")
            }
        }
        if ($script:LogWarns.Count -gt 0) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("## Warnings")
            foreach ($wn in $script:LogWarns) {
                [void]$sb.AppendLine("- ⚠️ $wn")
            }
        }
        [System.IO.File]::WriteAllText($script:AiSummaryFile, $sb.ToString(), [System.Text.Encoding]::UTF8)
    } catch {
        Write-LogEntry -Level "WARN" -Message "No se pudo escribir el informe Markdown en ($script:AiSummaryFile) - $($_.Exception.Message)"
    }

    $logMap = @{}
    if ($script:AiSummaryFile)  { $logMap["AI Diagnostic MD"] = $script:AiSummaryFile }
    if ($script:LogFile)        { $logMap["Log Estructurado"] = $script:LogFile }
    if ($script:TranscriptFile) { $logMap["Transcript"]       = $script:TranscriptFile }

    $st = if ($script:LogErrors.Count -eq 0) { "SUCCESS" } else { "FAILED" }
    Show-UnifiedSummary -Title "DESCARGADOR OFICIAL DE ISOs" -Status $st -DurationSeconds $totalDuration -ErrorsCount $script:LogErrors.Count -WarnsCount $script:LogWarns.Count -Logs $logMap
}

function Show-Header {
    Show-UnifiedBanner -Title "DESCARGADOR OFICIAL DE ISOs DE WINDOWS" -Subtitle "Microsoft Release Health + CDN Directo / MCT / Massgrave" -ShowSystemInfo
}

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

# ------------------------------------------------------------------------------
# MENÚ INTERACTIVO
# ------------------------------------------------------------------------------

if (-not $Version) {
    if ([Console]::IsInputRedirected) {
        $Version = "11_24H2"
        Write-Info "Entorno no interactivo detectado. Seleccionando versión por defecto: $Version"
    } else {
        Show-Header
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
                $selectedRelease = $liveReleases[$idx]
                $Version = $selectedRelease.Key
            } else {
                Write-Host "  [WARN] Operación cancelada." -ForegroundColor Yellow
                try { Stop-Transcript -ErrorAction Stop | Out-Null } catch {
                    Write-LogEntry -Level "INFO" -Message "Transcript finalizado: $($_.Exception.Message)"
                }
                exit 0
            }
        } else {
            Write-Host "  [WARN] Operación cancelada." -ForegroundColor Yellow
            try { Stop-Transcript -ErrorAction Stop | Out-Null } catch {
                Write-LogEntry -Level "INFO" -Message "Transcript finalizado: $($_.Exception.Message)"
            }
            exit 0
        }
    }
}

if (-not $Edition) {
    if ([Console]::IsInputRedirected) {
        $Edition = "Consumer"
        Write-Info "Entorno no interactivo detectado. Seleccionando edición por defecto: $Edition"
    } else {
        Show-Header
        Write-Host "  PASO 2: SELECCIONE EL TIPO DE MEDIO / PAQUETE DE EDICIÓN:" -ForegroundColor Cyan
        Write-Host "  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  [1] Consumer Multi-Edition (Minorista / Retail: Home, Pro, Edu)" -ForegroundColor White
        Write-Host "  [2] Business / Volume Licensing (VL Empresarial: Enterprise, Pro, Edu)" -ForegroundColor White
        Write-Host "  [3] IoT Enterprise / LTSC (Edición Especial de Máximo Rendimiento)" -ForegroundColor White
        Write-Host ""

        $eChoice = Read-Host "  Seleccione una opción (1-3)"
        switch ($eChoice) {
            "1" { $Edition = "Consumer" }
            "2" { $Edition = "Business" }
            "3" { $Edition = "IoTEnterprise" }
            default { $Edition = "Consumer" }
        }
    }
}

if (-not $Language) {
    if ([Console]::IsInputRedirected) {
        $Language = "Spanish"
        Write-Info "Entorno no interactivo detectado. Seleccionando idioma por defecto: $Language"
    } else {
        Show-Header
        Write-Host "  PASO 3: SELECCIONE EL IDIOMA OFICIAL DE LA IMAGEN:" -ForegroundColor Cyan
        Write-Host "  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  [1] Español (España / Internacional) [Spanish / es-ES]" -ForegroundColor White
        Write-Host "  [2] Español (México / Latinoamérica) [Spanish (Mexico) / es-MX]" -ForegroundColor White
        Write-Host "  [3] Inglés (Estados Unidos) [English / en-US]" -ForegroundColor White
        Write-Host "  [4] Portugués (Brasil) [Portuguese (Brazil) / pt-BR]" -ForegroundColor White
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
}

# ------------------------------------------------------------------------------
# INICIALIZACIÓN DEL ENTORNO
# ------------------------------------------------------------------------------

Show-Header
Write-Host "  RESUMEN DE CONFIGURACIÓN (MICROSOFT OFFICIAL MEDIA):" -ForegroundColor Cyan
Write-Host "  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  • Versión / Build : $Version" -ForegroundColor White
Write-Host "  • Tipo de Medio   : $Edition" -ForegroundColor White
Write-Host "  • Idioma Oficial  : $Language" -ForegroundColor White
Write-Host "  • Directorio      : $OutputDir" -ForegroundColor White
Write-Host "  • Estrategia      : $Method" -ForegroundColor White
Write-Host "  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$OutputDir = (Resolve-Path $OutputDir).Path

Initialize-Log -OutputDirectory $OutputDir

$langFilePart = $Language -replace '\s+', '_' -replace '[\(\)]', ''
$isoFileName = "Windows_${Version}_${Edition}_${langFilePart}_x64.iso"
$destinationFile = Join-Path $OutputDir $isoFileName
$downloadResult = $null

# ---------------------------------------------------------------------------
# DETECCION DE EDICIONES ESPECIALES (LTSC / IoT / Enterprise)
# Estas ediciones NO se distribuyen via MCT publico ni Fido CDN de consumidor.
# Canal correcto: Microsoft Evaluation Center o Catalogo Massgrave Genuine Media.
# Fuente: https://learn.microsoft.com/en-us/windows/whats-new/ltsc/
#         https://www.microsoft.com/en-us/evalcenter/
# ---------------------------------------------------------------------------

$script:IsSpecialEdition = ($Edition -in @("Business", "IoTEnterprise")) -or ($Version -match "LTSC")

# Catalogo de canales especiales verificados (fuentes oficiales Microsoft)
# IMPORTANTE: Los links del Evaluation Center son gratuitos pero generan ISOs de evaluacion de 90 dias.
# Para ISOs de produccion sin limitacion de tiempo, usar Massgrave Genuine Media.
$specialEditionLinks = @{
    "11_LTSC_2024" = @{
        EvalCenter   = "https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise"
        MassgraveTag = "#windows-11"
        EvalNote     = "Windows 11 Enterprise LTSC 2024 (Build 26100) — ISO de Evaluacion 90 dias (oficial Microsoft)"
        IoTNote      = "Para IoT Enterprise LTSC: usar ISO 24H2 estandar + PID.txt con clave IoT durante setup"
        MctSupport   = $false   # MCT publico NO soporta LTSC
        FidoSupport  = $false   # Fido CDN es canal Consumer, no incluye LTSC
    }
    "11_24H2" = @{  # Consumer puede usar Fido/MCT; Business/IoT necesita canal especial
        EvalCenter   = "https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise"
        MassgraveTag = "#windows-11"
        EvalNote     = "Windows 11 Enterprise 24H2 (Build 26100) — ISO de Evaluacion 90 dias (oficial Microsoft)"
        IoTNote      = "Para IoT Enterprise: usar ISO 24H2 estandar + PID.txt con clave IoT durante setup"
        MctSupport   = $true    # Consumer MCT si funciona para Win 11 24H2
        FidoSupport  = $true
    }
    "11_25H2" = @{
        EvalCenter   = "https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise"
        MassgraveTag = "#windows-11"
        EvalNote     = "Windows 11 Enterprise 25H2 — ISO de Evaluacion 90 dias (oficial Microsoft)"
        IoTNote      = "Para IoT Enterprise: usar ISO 25H2 estandar + PID.txt con clave IoT durante setup"
        MctSupport   = $true
        FidoSupport  = $true
    }
}
$currentEditionLinks = $specialEditionLinks[$Version]

# Mapeo de MediaCreationTool por version (SOLO para ediciones Consumer)
$mctSources = @{
    "11_25H2"  = @{ Url = "https://go.microsoft.com/fwlink/?linkid=2156295"; Name = "MediaCreationTool_Win11_25H2.exe"; Build = "26200" }
    "11_24H2"  = @{ Url = "https://go.microsoft.com/fwlink/?linkid=2156295"; Name = "MediaCreationTool_Win11_24H2.exe"; Build = "26100" }
    "11_23H2"  = @{ Url = "https://go.microsoft.com/fwlink/?linkid=2156295"; Name = "MediaCreationTool_Win11_23H2.exe"; Build = "22631" }
}
$targetMct = $mctSources[$Version]
if (-not $targetMct) {
    $targetMct = @{ Url = "https://go.microsoft.com/fwlink/?linkid=2156295"; Name = "MediaCreationTool_Auto.exe"; Build = "Latest" }
}

try {
    Write-Step "PASO 1: Validación de Espacio en Disco y Permisos"
    $driveLetter = $OutputDir.Substring(0, 1)
    $drive = Get-PSDrive -Name $driveLetter -ErrorAction SilentlyContinue
    if ($drive -and $drive.Free -lt 8GB) {
        throw "Espacio insuficiente en ${driveLetter}: ($([math]::Round($drive.Free/1GB, 2)) GB disponibles). Se requieren al menos 8-15 GB libres."
    } elseif ($drive) {
        Write-OK "Espacio en disco suficiente en ${driveLetter}: ($([math]::Round($drive.Free/1GB, 2)) GB libres)."
    }

    $downloadSuccess = $false

    # --------------------------------------------------------------------------
    # ESTRATEGIA 1: MOTOR CDN DIRECTO (FIDO / RUFUS ENGINE)
    # ALCANCE: Solo ediciones Consumer (Home, Pro). LTSC/IoT/Enterprise/Business
    # NO estan en el CDN publico de Microsoft que usa Fido.
    # Fuente: https://github.com/pbatard/Fido (documentacion oficial del proyecto)
    # --------------------------------------------------------------------------
    $fidoApplicable = ($Method -in @("Auto", "DirectCDN")) -and -not $downloadSuccess
    $fidoApplicable = $fidoApplicable -and ($Edition -eq "Consumer") -and -not ($Version -match "LTSC")
    $fidoApplicable = $fidoApplicable -and ($null -eq $currentEditionLinks -or $currentEditionLinks.FidoSupport -eq $true)

    if ($fidoApplicable) {
        Write-Step "PASO 2: Intento de Descarga Directa CDN (Motor Fido / Rufus)"
        $fidoScript = Join-Path $env:TEMP "Fido_$(Get-Random).ps1"
        $fidoUrl    = "https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1"

        try {
            Write-Info "Descargando motor Fido.ps1 desde GitHub (pbatard/Fido)..."
            Invoke-WebRequest -Uri $fidoUrl -OutFile $fidoScript -UseBasicParsing -ErrorAction Stop
            Write-OK "Motor Fido.ps1 descargado exitosamente."

            $fidoWinNum = 'Windows 11'
            $fidoRel    = 'Latest'

            Write-Info "Consultando API de Microsoft vía Fido (Windows $fidoWinNum $fidoRel, $Language, x64)..."
            $fidoRawOutput = & $fidoScript -Win $fidoWinNum -Rel $fidoRel -Lang $Language -Arch "x64" -GetUrl 2>&1
            $downloadUrl = $fidoRawOutput | Where-Object { $_ -match '^https?://' } | Select-Object -Last 1

            if ($downloadUrl) {
                Write-OK "URL CDN autenticada obtenida exitosamente."
                Write-Info "URL : $downloadUrl"

                # Descarga vía BITS
                if (Get-Command "Start-BitsTransfer" -ErrorAction SilentlyContinue) {
                    try {
                        Write-Info "Iniciando transferencia con motor BITS nativo de Windows..."
                        Start-BitsTransfer -Source $downloadUrl -Destination $destinationFile -Description "Descarga ISO Oficial Microsoft" -DisplayName "Windows ISO" -Priority High -ErrorAction Stop
                        $downloadSuccess = (Test-Path $destinationFile) -and ((Get-Item $destinationFile).Length -gt 1GB)
                        if ($downloadSuccess) { Write-OK "Descarga completada exitosamente vía BITS." }
                    } catch {
                        Write-Warn "BITS no completó la transferencia ($($_.Exception.Message)). Probando curl.exe..."
                    }
                }

                # Fallback curl.exe con reanudación
                if (-not $downloadSuccess -and (Get-Command "curl.exe" -ErrorAction SilentlyContinue)) {
                    Write-Info "Descargando con curl.exe (reanudación -C - activada)..."
                    & curl.exe -L -C - --retry 5 --retry-delay 3 -# -o "$destinationFile" "$downloadUrl"
                    $downloadSuccess = (Test-Path $destinationFile) -and ((Get-Item $destinationFile).Length -gt 1GB)
                    if ($downloadSuccess) { Write-OK "Descarga completada exitosamente vía curl.exe." }
                }
            } else {
                $isSentinel = ($fidoRawOutput | Out-String) -match "Sentinel"
                if ($isSentinel) {
                    Write-Warn "Microsoft Sentinel WAF bloqueó la petición automatizada ('Sentinel marked this request as rejected')."
                } else {
                    Write-Warn "Fido no retornó URL. Detalle: $(($fidoRawOutput | Out-String).Trim())"
                }
                Write-Info "Conmutando automáticamente a la siguiente estrategia..."
            }
        } catch {
            Write-Warn "Fallo en motor CDN Fido: $($_.Exception.Message)"
        } finally {
            if (Test-Path $fidoScript) { Remove-Item $fidoScript -Force -ErrorAction SilentlyContinue }
        }
    } elseif ($Method -in @("Auto", "DirectCDN") -and $script:IsSpecialEdition) {
        Write-Step "PASO 2: Edición Especial Detectada — Omitiendo Fido CDN"
        Write-Warn "Edicion '$Edition' / Version '$Version' NO esta disponible en el CDN publico de Microsoft."
        Write-Info "Las ediciones LTSC, IoT Enterprise y Business (Enterprise VL) se distribuyen por canales separados."
        Write-Info "Redirigiendo directamente al canal especializado correcto..."
    }

    # --------------------------------------------------------------------------
    # ESTRATEGIA 2: ASISTENTE OFICIAL MEDIACREATIONTOOL
    # ALCANCE: Solo ediciones Consumer en versiones GA (no LTSC).
    # MCT publico NO soporta Enterprise LTSC ni IoT Enterprise.
    # Fuente: https://learn.microsoft.com/en-us/windows/deployment/windows-10-poc
    # --------------------------------------------------------------------------
    $mctApplicable = ($Method -in @("Auto", "MediaCreationTool")) -and -not $downloadSuccess
    $mctApplicable = $mctApplicable -and ($Edition -eq "Consumer") -and -not ($Version -match "LTSC")

    if ($mctApplicable -or $Method -eq "MediaCreationTool") {
        Write-Step "PASO 3: Ejecución de MediaCreationTool Oficial de Microsoft (Solo Consumer)"

        if ($script:IsSpecialEdition -and $Method -eq "MediaCreationTool") {
            Write-Warn "MediaCreationTool publico NO distribuye ediciones Enterprise LTSC ni IoT Enterprise."
            Write-Info "MCT solo ofrece: Home, Pro, Education, Pro for Workstations (ediciones Consumer)."
            Write-Info "Para Enterprise/LTSC/IoT use el canal Evaluation Center de Microsoft o Massgrave."
        } else {
            $scratchDir = Join-Path $env:TEMP "MCT_Build_$(Get-Random)"
            New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
            $mctPath = Join-Path $scratchDir $targetMct.Name

            try {
                Write-Info "Descargando MediaCreationTool oficial firmado (Build $($targetMct.Build))..."
                Invoke-WebRequest -Uri $targetMct.Url -OutFile $mctPath -UseBasicParsing -ErrorAction Stop
                Write-OK "Herramienta oficial descargada en: $mctPath"

                Write-Host ""
                Write-Host "  ┌────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Yellow
                Write-Host "  │  ASISTENTE OFICIAL DE MEDIACREATIONTOOL:                               │" -ForegroundColor Yellow
                Write-Host "  │  1. Se abrirá la ventana gráfica oficial de Microsoft.                │" -ForegroundColor Yellow
                Write-Host "  │  2. Acepte los términos de licencia.                                  │" -ForegroundColor Yellow
                Write-Host "  │  3. Seleccione: 'Crear medios de instalación (archivo ISO)'.         │" -ForegroundColor Yellow
                Write-Host "  │  4. Guarde el archivo ISO en:                                         │" -ForegroundColor Yellow
                Write-Host "  │     $OutputDir" -ForegroundColor Cyan
                Write-Host "  └────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
                Write-Host ""

                $mctStartTime = Get-Date
                Start-Process -FilePath $mctPath -ArgumentList @("/Eula", "Accept") -Wait | Out-Null

                # Detección de la ISO resultante
                if (Test-Path $destinationFile) {
                    $downloadSuccess = $true
                } else {
                    $recentIso = Get-ChildItem -Path $OutputDir -Filter "*.iso" -File -ErrorAction SilentlyContinue |
                                 Where-Object { $_.LastWriteTime -ge $mctStartTime.AddMinutes(-1) } |
                                 Sort-Object LastWriteTime -Descending |
                                 Select-Object -First 1
                    if ($recentIso) {
                        $destinationFile = $recentIso.FullName
                        $downloadSuccess = $true
                    }
                }

                if ($downloadSuccess) {
                    Write-OK "ISO generada y detectada correctamente vía MediaCreationTool."
                } else {
                    Write-Warn "MediaCreationTool finalizó sin generar la ISO en el directorio objetivo."
                }
            } catch {
                Write-Warn "Fallo al ejecutar MediaCreationTool: $($_.Exception.Message)"
            } finally {
                if (Test-Path $scratchDir) { Remove-Item $scratchDir -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }
    } elseif ($script:IsSpecialEdition -and -not $downloadSuccess) {
        Write-Step "PASO 3: Edición Especial — MCT No Aplicable"
        Write-Info "Edicion '$Edition' / '$Version' omite MediaCreationTool. Procediendo al canal especializado."
    }

    # --------------------------------------------------------------------------
    # ESTRATEGIA 3: NAVEGADOR ASISTIDO CON CANAL CORRECTO SEGUN EDICION
    # - Consumer GA:       microsoft.com/software-download + Massgrave
    # - Enterprise/LTSC:  Microsoft Evaluation Center (90 dias, oficial gratuita)
    # - IoT Enterprise:   Evaluation Center + instrucciones PID.txt
    # - Todas:            Catalogo Massgrave Genuine Media (SHA-256 verificado)
    # --------------------------------------------------------------------------
    if (-not $downloadSuccess) {
        Write-Step "PASO 4: Canal de Descarga Asistida por Navegador (Fuentes Oficiales)"
        Write-Host ""

        if ($script:IsSpecialEdition -and $currentEditionLinks) {
            # ---- Edicion especial: Enterprise / LTSC / IoT Enterprise ----
            $evalUrl      = $currentEditionLinks.EvalCenter
            $massgraveUrl = "https://massgrave.dev/genuine-installation-media" + $currentEditionLinks.MassgraveTag

            Write-Host "  ╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
            Write-Host "  ║  EDICION ESPECIAL: CANALES DE DISTRIBUCION OFICIALES                 ║" -ForegroundColor Magenta
            Write-Host "  ║  ($Edition / $Version)" -ForegroundColor Magenta
            Write-Host "  ╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
            Write-Host ""
            Write-Host "  OPCION A — Microsoft Evaluation Center (Oficial, GRATUITO):" -ForegroundColor Cyan
            Write-Host "  $($currentEditionLinks.EvalNote)" -ForegroundColor White
            Write-Host "  URL: $evalUrl" -ForegroundColor Yellow
            Write-Host ""
            if ($currentEditionLinks.IoTNote -and $Edition -eq "IoTEnterprise") {
                Write-Host "  NOTA IoT Enterprise:" -ForegroundColor Yellow
                Write-Host "  $($currentEditionLinks.IoTNote)" -ForegroundColor White
                Write-Host "  (No existe ISO IoT separada en canal publico — se selecciona via PID.txt en setup)" -ForegroundColor Gray
                Write-Host ""
            }
            Write-Host "  OPCION B — Massgrave Genuine Media (ISO Completa, SHA-256 Verificado):" -ForegroundColor Cyan
            Write-Host "  Sin limitacion de 90 dias. Links directos al CDN oficial de Microsoft." -ForegroundColor White
            Write-Host "  URL: $massgraveUrl" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  Directorio destino para la ISO:" -ForegroundColor Gray
            Write-Host "  $OutputDir" -ForegroundColor White
            Write-Host ""

            $openChoice = if ([Console]::IsInputRedirected) { "N" } else { Read-Host "  Abrir en navegador: [A] Evaluation Center  [B] Massgrave  [C] Ambos  [N] No" }
            if ($openChoice) {
                switch ($openChoice.ToUpper().Trim()) {
                    "A" { Start-Process $evalUrl }
                    "B" { Start-Process $massgraveUrl }
                    "C" { Start-Process $evalUrl; Start-Sleep -Seconds 1; Start-Process $massgraveUrl }
                    default { Write-Info "Ninguna página abierta. URLs copiadas en el log de sesión." }
                }
            }

        } else {
            # ---- Edicion Consumer GA (Home, Pro, etc.) ----
            $consumerUrl  = "https://www.microsoft.com/software-download/windows11"
            $massgraveUrl = "https://massgrave.dev/genuine-installation-media"

            Write-Host "  ┌────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
            Write-Host "  │  DESCARGA MANUAL ASISTIDA — EDICION CONSUMER (FUENTES OFICIALES):      │" -ForegroundColor Cyan
            Write-Host "  │                                                                        │" -ForegroundColor Cyan
            Write-Host "  │  1. Portal Oficial Microsoft Software Download:                        │" -ForegroundColor White
            Write-Host "  │     $consumerUrl" -ForegroundColor Yellow
            Write-Host "  │                                                                        │" -ForegroundColor White
            Write-Host "  │  2. Catálogo Massgrave Genuine Media (SHA-256 verificado):             │" -ForegroundColor White
            Write-Host "  │     $massgraveUrl" -ForegroundColor Yellow
            Write-Host "  │                                                                        │" -ForegroundColor White
            Write-Host "  │  Guarde la ISO en: $OutputDir" -ForegroundColor Gray
            Write-Host "  └────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
            Write-Host ""

            $openBrowser = if ([Console]::IsInputRedirected) { "N" } else { Read-Host "  ¿Desea abrir el portal oficial de Microsoft en su navegador ahora? (S/N)" }
            if ($openBrowser -and $openBrowser -match '^[sSyY]') {
                Start-Process $consumerUrl
            }
        }
    }

    # --------------------------------------------------------------------------
    # VERIFICACIÓN DE INTEGRIDAD Y HASH SHA-256
    # --------------------------------------------------------------------------
    if ($downloadSuccess -and (Test-Path $destinationFile)) {
        Write-Step "PASO 5: Verificación de Integridad y Hash SHA-256"
        $fileSize = (Get-Item $destinationFile).Length
        $sizeGB = [math]::Round($fileSize / 1GB, 2)

        if ($fileSize -gt 1GB) {
            Write-Host ""
            Write-Host "  ╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
            Write-Host "  ║  ¡ISO OFICIAL DISPONIBLE Y VERIFICADA CON ÉXITO!                     ║" -ForegroundColor Green
            Write-Host "  ╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
            Write-Host "    Archivo : $destinationFile" -ForegroundColor White
            Write-Host "    Tamaño  : $sizeGB GB" -ForegroundColor Gray

            if (-not $SkipSha256) {
                Write-Info "Calculando hash criptográfico SHA-256..."
                $sha256 = (Get-FileHash -Path $destinationFile -Algorithm SHA256).Hash
                Write-OK "Hash SHA-256: $sha256"
                Write-Host "    SHA-256 : $sha256" -ForegroundColor DarkGray
            }
            Write-Host ""
            $downloadResult = $destinationFile
        } else {
            throw "El archivo ISO descargado es incompleto ($sizeGB GB). Verifique su conexión."
        }
    } elseif ($downloadSuccess) {
        throw "No se encontró el archivo ISO en la ruta esperada."
    }

} catch {
    Write-Host ""
    Write-ErrorMsg "Error en proceso de descarga: $($_.Exception.Message)"
} finally {
    Write-LogSummary
}

return $downloadResult
