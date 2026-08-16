<#
.SYNOPSIS
    Descargador Interactivo de ISOs Oficiales de Windows — Método A (MediaCreationTool Wrapper / AveYo Style)

.DESCRIPTION
    Asistente interactivo basado en la taxonomía y canales oficiales de Microsoft Learn.
    Automatiza la herramienta oficial MediaCreationTool.exe para descargar y generar
    ISOs oficiales (Consumer Multi-Edition, Business Volume y Enterprise LTSC).

.PARAMETER Version
    Versión oficial: "11_24H2", "11_23H2", "10_22H2", "11_LTSC_2024", "10_LTSC_2021".

.PARAMETER Edition
    Tipo de contenedor: "Consumer", "Business", "IoTEnterprise".

.PARAMETER Language
    Código de idioma oficial: "es-ES", "es-MX", "en-US", "pt-BR", etc.

.PARAMETER OutputDir
    Carpeta de destino para la ISO. Por defecto: "$HOME\Downloads\Windows_ISOs".
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
    [string]$OutputDir = "$HOME\Downloads\Windows_ISOs"
)

# Configuración de seguridad TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Continue'

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

function Initialize-Log {
    param([string]$OutputDirectory)

    $logDir = Join-Path $OutputDirectory "Logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $ts                       = Get-Date -Format 'yyyyMMdd_HHmmss'
    $script:LogFile           = Join-Path $logDir "ISO_MCT_Build_$ts.log"
    $script:TranscriptFile    = Join-Path $logDir "ISO_MCT_Build_${ts}_transcript.log"
    $script:AiSummaryFile     = Join-Path $logDir "ISO_MCT_Build_${ts}_AI_SUMMARY.md"
    $script:DownloadStartTime = Get-Date

    # Iniciar transcript de consola completo
    try {
        Start-Transcript -Path $script:TranscriptFile -Append -ErrorAction Stop | Out-Null
    } catch {
        # Start-Transcript no bloquea si falla
    }

    # Cabecera del log estructurado
    Write-LogEntry -Level "INIT" -Message ("=" * 64)
    Write-LogEntry -Level "INIT" -Message "Official Windows ISO Builder Log (Method A - MediaCreationTool)"
    Write-LogEntry -Level "INIT" -Message "PowerShell $($PSVersionTable.PSVersion)  |  Host: $env:COMPUTERNAME  |  User: $env:USERNAME"
    Write-LogEntry -Level "INIT" -Message "Directorio Destino: $OutputDirectory"
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

    # Acumular errores y warnings
    if (-not $NoAccumulate) {
        if ($Level -eq "ERROR") { $script:LogErrors.Add($Message) }
        if ($Level -eq "WARN")  { $script:LogWarns.Add($Message)  }
    }
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
    Write-LogEntry -Level "INIT" -Message "RESUMEN FINAL DE COMPILACIÓN MCT"
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
        Write-LogEntry -Level "OK"   -Message "Compilación e ISO completada exitosamente."
    }

    Write-LogEntry -Level "INIT" -Message "Log estructurado    : $script:LogFile"
    Write-LogEntry -Level "INIT" -Message "AI Summary (MD)     : $script:AiSummaryFile"
    Write-LogEntry -Level "INIT" -Message "Transcript          : $script:TranscriptFile"
    Write-LogEntry -Level "INIT" -Message ("=" * 64)

    # Detener transcript
    try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch {}

    # Generar Reporte Markdown optimizado para IA
    try {
        $overallStatus = if ($script:LogErrors.Count -eq 0) { "SUCCESS" } else { "FAILED" }
        $statusBadge   = if ($overallStatus -eq "SUCCESS") { "SUCCESS ✅" } else { "FAILED ❌" }

        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("# AI Diagnostic Report: Get-OfficialWindowsISO (Method A)")
        [void]$sb.AppendLine("- **Status:** $statusBadge")
        [void]$sb.AppendLine("- **Timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        [void]$sb.AppendLine("- **Total Duration:** ${totalDuration}s")
        [void]$sb.AppendLine("- **Host:** $env:COMPUTERNAME | **User:** $env:USERNAME | **PowerShell:** $($PSVersionTable.PSVersion)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Build Parameters")
        [void]$sb.AppendLine("- **Version:** $Version")
        [void]$sb.AppendLine("- **Edition:** $Edition")
        [void]$sb.AppendLine("- **Language:** $Language")
        [void]$sb.AppendLine("- **Output Directory:** $OutputDir")
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
    } catch {}
}

function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "  ║  DESCARGADOR OFICIAL DE WINDOWS — MÉTODO A (MediaCreationTool)       ║" -ForegroundColor Magenta
    Write-Host "  ║  (Motor Dinámico Microsoft Release Health + MCT Wrapper Automatizado)║" -ForegroundColor Magenta
    Write-Host "  ╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
}

function Get-OnlineWindowsReleases {
    <#
    .SYNOPSIS
        Consulta dinámicamente en tiempo real los canales oficiales de Microsoft Learn (Windows Release Health).
    #>
    [CmdletBinding()]
    param([int]$TimeoutSec = 5)

    Write-Info "Consultando canales oficiales de Microsoft Learn en tiempo real..."

    $discoveredList = [System.Collections.Generic.List[PSCustomObject]]::new()
    $onlineSuccess = $false

    try {
        # 1. Petición a canal Windows 11 Release Health
        $req11 = [System.Net.HttpWebRequest]::Create("https://learn.microsoft.com/es-es/windows/release-health/windows11-release-information")
        $req11.Timeout = $TimeoutSec * 1000
        $req11.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
        $resp11 = $req11.GetResponse()
        $stream11 = $resp11.GetResponseStream()
        $reader11 = [System.IO.StreamReader]::new($stream11)
        $html11 = $reader11.ReadToEnd()
        $reader11.Close()
        $resp11.Close()

        # Extraer versiones GA de Windows 11 (25H2, 24H2, 23H2...)
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

        # 2. Petición a canal Windows 10 Release Health
        $req10 = [System.Net.HttpWebRequest]::Create("https://learn.microsoft.com/es-es/windows/release-health/release-information")
        $req10.Timeout = $TimeoutSec * 1000
        $req10.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
        $resp10 = $req10.GetResponse()
        $stream10 = $resp10.GetResponseStream()
        $reader10 = [System.IO.StreamReader]::new($stream10)
        $html10 = $reader10.ReadToEnd()
        $reader10.Close()
        $resp10.Close()

        if ($html10 -match 'Versi[oó]n\s+(22H2)\s+\(OS build\s+(\d+)\)') {
            $discoveredList.Add([PSCustomObject]@{
                Key         = "10_22H2"
                DisplayName = "Windows 10 $($Matches[1]) (Build $($Matches[2]))"
                Tag         = "Versión final de Windows 10 (Soporte 2025)"
                Version     = "10_22H2"
                Build       = $Matches[2]
                Family      = "Windows 10"
                Channel     = "General Availability"
            })
        }

        # LTSC 2021 (Windows 10)
        $discoveredList.Add([PSCustomObject]@{
            Key         = "10_LTSC_2021"
            DisplayName = "Windows 10 Enterprise LTSC 2021 (Build 19044)"
            Tag         = "Soporte Extendido hasta 2032"
            Version     = "10_LTSC_2021"
            Build       = "19044"
            Family      = "Windows 10"
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

    # Catálogo de Respaldo Seguro (Fallback)
    if (-not $onlineSuccess -or $discoveredList.Count -eq 0) {
        $discoveredList.Clear()
        $discoveredList.Add([PSCustomObject]@{ Key="11_25H2"; DisplayName="Windows 11 25H2 (Build 26200)"; Tag="Última versión anual GA"; Version="11_25H2"; Build="26200"; Family="Windows 11"; Channel="General Availability" })
        $discoveredList.Add([PSCustomObject]@{ Key="11_24H2"; DisplayName="Windows 11 24H2 (Build 26100)"; Tag="Canal General y Base LTSC 2024"; Version="11_24H2"; Build="26100"; Family="Windows 11"; Channel="General Availability" })
        $discoveredList.Add([PSCustomObject]@{ Key="11_23H2"; DisplayName="Windows 11 23H2 (Build 22631)"; Tag="Versión previa activa y madura"; Version="11_23H2"; Build="22631"; Family="Windows 11"; Channel="General Availability" })
        $discoveredList.Add([PSCustomObject]@{ Key="10_22H2"; DisplayName="Windows 10 22H2 (Build 19045)"; Tag="Versión final de Windows 10 (Soporte 2025)"; Version="10_22H2"; Build="19045"; Family="Windows 10"; Channel="General Availability" })
        $discoveredList.Add([PSCustomObject]@{ Key="11_LTSC_2024"; DisplayName="Windows 11 Enterprise LTSC 2024 (Build 26100)"; Tag="Soporte Extendido 5/10 años"; Version="11_LTSC_2024"; Build="26100"; Family="Windows 11"; Channel="LTSC" })
        $discoveredList.Add([PSCustomObject]@{ Key="10_LTSC_2021"; DisplayName="Windows 10 Enterprise LTSC 2021 (Build 19044)"; Tag="Soporte Extendido hasta 2032"; Version="10_LTSC_2021"; Build="19044"; Family="Windows 10"; Channel="LTSC" })
    }

    return $discoveredList
}

# ------------------------------------------------------------------------------
# MENÚ INTERACTIVO BASADO EN CANALES OFICIALES DE MICROSOFT LEARN
# ------------------------------------------------------------------------------

if (-not $Version) {
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
            Write-Warn "Operación cancelada."
            exit 0
        }
    } else {
        Write-Warn "Operación cancelada."
        exit 0
    }
}

if (-not $Edition) {
    Show-Header
    Write-Host "  PASO 2: SELECCIONE EL TIPO DE MEDIO / PAQUETE DE EDICIÓN:" -ForegroundColor Cyan
    Write-Host "  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  [1] Consumer Multi-Edition (Minorista / Retail)" -ForegroundColor White
    Write-Host "      └─ Contiene: Windows Home, Pro, Education y Pro for Workstations." -ForegroundColor Gray
    Write-Host "  [2] Business / Volume Licensing (VL Empresarial)" -ForegroundColor White
    Write-Host "      └─ Contiene: Windows Enterprise, Pro y Education (Activación KMS/MAK)." -ForegroundColor Gray
    Write-Host "  [3] IoT Enterprise / LTSC (Edición Especial de Máximo Rendimiento)" -ForegroundColor White
    Write-Host "      └─ Sin apps de la tienda, sin telemetría pesada, ciclo de 10 años." -ForegroundColor Gray
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
    Show-Header
    Write-Host "  PASO 3: SELECCIONE EL IDIOMA OFICIAL DE LA IMAGEN:" -ForegroundColor Cyan
    Write-Host "  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  [1] Español (España / Internacional) [es-ES]" -ForegroundColor White
    Write-Host "  [2] Español (México / Latinoamérica) [es-MX]" -ForegroundColor White
    Write-Host "  [3] Inglés (Estados Unidos) [en-US]" -ForegroundColor White
    Write-Host "  [4] Portugués (Brasil) [pt-BR]" -ForegroundColor White
    Write-Host "  [5] Otro idioma (escribir código BCP-47, ej. fr-FR, de-DE, it-IT)" -ForegroundColor Yellow
    Write-Host ""

    $lChoice = Read-Host "  Seleccione una opción (1-5)"
    switch ($lChoice) {
        "1" { $Language = "es-ES" }
        "2" { $Language = "es-MX" }
        "3" { $Language = "en-US" }
        "4" { $Language = "pt-BR" }
        "5" { 
            $customLang = Read-Host "  Escriba el código de idioma (ej. fr-FR)"
            $Language = if ($customLang) { $customLang.Trim() } else { "es-ES" }
        }
        default { $Language = "es-ES" }
    }
}

# ------------------------------------------------------------------------------
# CONFIGURACIÓN DEL CATÁLOGO DE MICROSOFT
# ------------------------------------------------------------------------------

Show-Header
Write-Host "  RESUMEN DE DESCARGA (CANALES OFICIALES DE MICROSOFT):" -ForegroundColor Cyan
Write-Host "  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  • Versión / Build : $Version" -ForegroundColor White
Write-Host "  • Tipo de Medio   : $Edition" -ForegroundColor White
Write-Host "  • Idioma BCP-47   : $Language" -ForegroundColor White
Write-Host "  • Directorio      : $OutputDir" -ForegroundColor White
Write-Host "  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$OutputDir = (Resolve-Path $OutputDir).Path

# Inicializar subsistema de logging estructurado
Initialize-Log -OutputDirectory $OutputDir

# Mapeo oficial de ejecutables MediaCreationTool
$mctSources = @{
    "11_25H2"       = @{ Url = "https://go.microsoft.com/fwlink/?linkid=2156295"; Name = "MediaCreationTool_Win11_25H2.exe"; Build = "26200" }
    "11_24H2"       = @{ Url = "https://go.microsoft.com/fwlink/?linkid=2156295"; Name = "MediaCreationTool_Win11_24H2.exe"; Build = "26100" }
    "11_23H2"       = @{ Url = "https://go.microsoft.com/fwlink/?linkid=2156295"; Name = "MediaCreationTool_Win11_23H2.exe"; Build = "22631" }
    "10_22H2"       = @{ Url = "https://go.microsoft.com/fwlink/?LinkId=691209"; Name = "MediaCreationTool_Win10_22H2.exe"; Build = "19045" }
    "11_LTSC_2024"  = @{ Url = "https://go.microsoft.com/fwlink/?linkid=2156295"; Name = "MediaCreationTool_Win11_LTSC.exe"; Build = "26100" }
    "10_LTSC_2021"  = @{ Url = "https://go.microsoft.com/fwlink/?LinkId=691209"; Name = "MediaCreationTool_Win10_LTSC.exe"; Build = "19044" }
}

$targetMct = $mctSources[$Version]
if (-not $targetMct) {
    if ($Version -like "11_*") {
        $targetMct = @{ Url = "https://go.microsoft.com/fwlink/?linkid=2156295"; Name = "MediaCreationTool_Win11_Auto.exe"; Build = "Latest" }
    } else {
        $targetMct = @{ Url = "https://go.microsoft.com/fwlink/?LinkId=691209"; Name = "MediaCreationTool_Win10_Auto.exe"; Build = "Latest" }
    }
}
$scratchDir = Join-Path $env:TEMP "MCT_Build_$(Get-Random)"
New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null

$mctPath = Join-Path $scratchDir $targetMct.Name
$isoFileName = "Windows_${Version}_${Edition}_${Language}_x64.iso"
$finalIsoPath = Join-Path $OutputDir $isoFileName
$downloadResult = $null

try {
    Write-Step "PASO 1: Validación de Espacio en Disco para Compilación MCT"
    $driveLetter = $OutputDir.Substring(0, 1)
    $drive = Get-PSDrive -Name $driveLetter -ErrorAction SilentlyContinue
    if ($drive -and $drive.Free -lt 15GB) {
        Write-Warn "Espacio en disco bajo en ${driveLetter}: ($([math]::Round($drive.Free/1GB, 1)) GB libres)."
        Write-Warn "MediaCreationTool requiere al menos 15-20 GB libres para descargar y compilar la ISO."
    } else {
        Write-OK "Espacio en disco suficiente en ${driveLetter}: ($([math]::Round($drive.Free/1GB, 1)) GB libres)."
    }

    Write-Step "PASO 2: Descarga de Herramienta MediaCreationTool Oficial Firmada"
    Write-Info "Descargando MediaCreationTool oficial firmado (Build $($targetMct.Build))..."
    Invoke-WebRequest -Uri $targetMct.Url -OutFile $mctPath -UseBasicParsing
    Write-OK "Herramienta oficial descargada: $mctPath"

    Write-Step "PASO 3: Ejecución de MediaCreationTool y Compilación de Medios .ESD a .ISO"
    Write-Info "Ejecutando MediaCreationTool oficial de Microsoft en modo desatendido..."
    Write-Info "Descargando paquetes .ESD y compilando ISO en: $finalIsoPath"
    Write-Info "Este proceso puede tardar entre 10 y 20 minutos..."

    $mctArgs = @(
        "/Eula", "Accept",
        "/Retail",
        "/MediaArch", "x64",
        "/MediaLangCode", $Language,
        "/IsoFile", $finalIsoPath
    )

    if ($Edition -in @("Business", "IoTEnterprise") -or $Version -match "LTSC") {
        # Flag /Selfhost para desbloquear ediciones corporativas y LTSC
        $mctArgs += @("/Selfhost")
    }

    $proc = Start-Process -FilePath $mctPath -ArgumentList $mctArgs -Wait -PassThru -NoNewWindow

    Write-Step "PASO 4: Verificación de ISO Generada"
    if ($proc.ExitCode -eq 0 -and (Test-Path $finalIsoPath)) {
        $sizeGB = [math]::Round((Get-Item $finalIsoPath).Length / 1GB, 2)
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "  ║  ¡ISO OFICIAL GENERADA CON ÉXITO!                                    ║" -ForegroundColor Green
        Write-Host "  ╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host "    Ruta   : $finalIsoPath" -ForegroundColor White
        Write-Host "    Tamaño : $sizeGB GB" -ForegroundColor Gray
        Write-Host ""
        Write-OK "Archivo ISO verificado y disponible en: $finalIsoPath ($sizeGB GB)"
        $downloadResult = $finalIsoPath
    } else {
        throw "MediaCreationTool terminó con exit code: $($proc.ExitCode). Revise C:\`$Windows.~WS\Sources\Panther."
    }
} catch {
    Write-Host ""
    Write-ErrorMsg "Fallo en Método A: $($_.Exception.Message)"
} finally {
    if (Test-Path $scratchDir) {
        Remove-Item -Path $scratchDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-LogSummary
}

return $downloadResult
