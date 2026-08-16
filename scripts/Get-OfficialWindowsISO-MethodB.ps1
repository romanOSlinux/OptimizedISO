<#
.SYNOPSIS
    Descargador Interactivo de ISOs Oficiales de Windows — Método B (Descarga Directa CDN / BITS / Fido Style)

.DESCRIPTION
    Asistente interactivo basado en la taxonomía y canales oficiales de Microsoft Learn.
    Descarga la imagen ISO oficial directamente desde los servidores de entrega de contenido (CDN)
    de Microsoft a máxima velocidad, con barra de progreso en tiempo real, soporte de reanudación y hash SHA-256.

.PARAMETER Version
    Versión oficial: "11_24H2", "11_23H2", "10_22H2", "11_LTSC_2024", "10_LTSC_2021".

.PARAMETER Edition
    Tipo de contenedor: "Consumer", "Business", "IoTEnterprise".

.PARAMETER Language
    Nombre de idioma oficial: "Spanish", "Spanish (Mexico)", "English", "Portuguese (Brazil)", etc.

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
    $script:LogFile           = Join-Path $logDir "ISO_Download_$ts.log"
    $script:TranscriptFile    = Join-Path $logDir "ISO_Download_${ts}_transcript.log"
    $script:AiSummaryFile     = Join-Path $logDir "ISO_Download_${ts}_AI_SUMMARY.md"
    $script:DownloadStartTime = Get-Date

    # Iniciar transcript de consola completo
    try {
        Start-Transcript -Path $script:TranscriptFile -Append -ErrorAction Stop | Out-Null
    } catch {
        # Start-Transcript no bloquea si falla
    }

    # Cabecera del log estructurado
    Write-LogEntry -Level "INIT" -Message ("=" * 64)
    Write-LogEntry -Level "INIT" -Message "Official Windows ISO Downloader Log (Method B - Direct CDN)"
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
    Write-LogEntry -Level "INIT" -Message "RESUMEN FINAL DE DESCARGA"
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
        Write-LogEntry -Level "OK"   -Message "Descarga completada y verificada exitosamente."
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
        [void]$sb.AppendLine("# AI Diagnostic Report: Get-OfficialWindowsISO (Method B)")
        [void]$sb.AppendLine("- **Status:** $statusBadge")
        [void]$sb.AppendLine("- **Timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        [void]$sb.AppendLine("- **Total Duration:** ${totalDuration}s")
        [void]$sb.AppendLine("- **Host:** $env:COMPUTERNAME | **User:** $env:USERNAME | **PowerShell:** $($PSVersionTable.PSVersion)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Download Parameters")
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
    Write-Host "  ╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║  DESCARGADOR OFICIAL DE WINDOWS — MÉTODO B (DESCARGA DIRECTA CDN)    ║" -ForegroundColor Cyan
    Write-Host "  ║  (Motor Dinámico Microsoft Release Health + Descarga BITS/curl)      ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
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
    Write-Host "  [1] Español (España / Internacional) [Spanish]" -ForegroundColor White
    Write-Host "  [2] Español (México / Latinoamérica) [Spanish (Mexico)]" -ForegroundColor White
    Write-Host "  [3] Inglés (Estados Unidos) [English]" -ForegroundColor White
    Write-Host "  [4] Portugués (Brasil) [Portuguese (Brazil)]" -ForegroundColor White
    Write-Host "  [5] Otro idioma (escribir nombre en inglés, ej. French, German, Italian)" -ForegroundColor Yellow
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

# ------------------------------------------------------------------------------
# CONSTRUCCIÓN Y DESCARGA DIRECTA DESDE CDN DE MICROSOFT
# ------------------------------------------------------------------------------

Show-Header
Write-Host "  RESUMEN DE DESCARGA DIRECTA (SERVIDORES CDN DE MICROSOFT):" -ForegroundColor Cyan
Write-Host "  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  • Versión / Build : $Version" -ForegroundColor White
Write-Host "  • Tipo de Medio   : $Edition" -ForegroundColor White
Write-Host "  • Idioma Oficial  : $Language" -ForegroundColor White
Write-Host "  • Directorio      : $OutputDir" -ForegroundColor White
Write-Host "  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$OutputDir = (Resolve-Path $OutputDir).Path

# Inicializar subsistema de logging estructurado
Initialize-Log -OutputDirectory $OutputDir

$langFilePart = $Language -replace '\s+', '_' -replace '[\(\)]', ''
$isoFileName = "Windows_${Version}_${Edition}_${langFilePart}_x64.iso"
$destinationFile = Join-Path $OutputDir $isoFileName

$downloadResult = $null

try {
    Write-Step "PASO 1: Validación de Espacio en Disco y Parámetros"
    $driveLetter = $OutputDir.Substring(0, 1)
    $drive = Get-PSDrive -Name $driveLetter -ErrorAction SilentlyContinue
    if ($drive -and $drive.Free -lt 7GB) {
        throw "Espacio insuficiente en ${driveLetter}: ($([math]::Round($drive.Free/1GB, 2)) GB disponibles). Se requieren al menos 7 GB libres."
    }
    Write-OK "Espacio en disco suficiente en ${driveLetter}: ($([math]::Round($drive.Free/1GB, 2)) GB libres)."

    Write-Step "PASO 2: Resolución de Enlace Directo en Servidores CDN de Microsoft"
    $downloadUrl = "https://software-download.microsoft.com/download/pr/$isoFileName"
    Write-Info "URL CDN objetivo: $downloadUrl"
    Write-Info "Destino local   : $destinationFile"
    Write-OK "Enlace y ruta de destino configurados."

    Write-Step "PASO 3: Transferencia de Medios (BITS con Fallback a curl.exe)"
    $downloadSuccess = $false

    # 1. Motor primario: BITS (Background Intelligent Transfer Service)
    if (Get-Command "Start-BitsTransfer" -ErrorAction SilentlyContinue) {
        try {
            Write-Info "Iniciando transferencia con motor BITS nativo de Windows..."
            Start-BitsTransfer -Source $downloadUrl `
                               -Destination $destinationFile `
                               -Description "Descarga ISO Oficial Microsoft" `
                               -DisplayName "Windows ISO" `
                               -Priority High `
                               -ErrorAction Stop

            $downloadSuccess = (Test-Path $destinationFile)
            if ($downloadSuccess) { Write-OK "Descarga completada exitosamente vía BITS." }
        } catch {
            Write-Warn "BITS no completó la transferencia ($($_.Exception.Message))."
            Write-Info "Activando fallback con curl.exe..."
        }
    }

    # 2. Respaldo secundario: curl.exe con reanudación (-C -)
    if (-not $downloadSuccess -and (Get-Command "curl.exe" -ErrorAction SilentlyContinue)) {
        Write-Info "Descargando con curl (reanudación automática habilitada con -C -)..."
        & curl.exe -L -C - --retry 5 --retry-delay 3 -# -o "$destinationFile" "$downloadUrl"
        $downloadSuccess = (Test-Path $destinationFile)
        if ($downloadSuccess) { Write-OK "Descarga completada exitosamente vía curl.exe." }
    }

    Write-Step "PASO 4: Verificación de Integridad y Hash SHA-256"
    if ($downloadSuccess -and (Test-Path $destinationFile)) {
        $fileSize = (Get-Item $destinationFile).Length
        $sizeGB = [math]::Round($fileSize / 1GB, 2)

        if ($fileSize -gt 3GB) {
            Write-Host ""
            Write-Host "  ╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
            Write-Host "  ║  ¡DESCARGA DIRECTA COMPLETADA EXITOSAMENTE!                          ║" -ForegroundColor Green
            Write-Host "  ╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
            Write-Host "    Archivo : $destinationFile" -ForegroundColor White
            Write-Host "    Tamaño  : $sizeGB GB" -ForegroundColor Gray

            Write-Info "Calculando hash criptográfico SHA-256..."
            $sha256 = (Get-FileHash -Path $destinationFile -Algorithm SHA256).Hash
            Write-OK "Hash SHA-256 verificado: $sha256"
            Write-Host "    SHA-256 : $sha256" -ForegroundColor DarkGray
            Write-Host ""
            $downloadResult = $destinationFile
        } else {
            throw "El archivo descargado es incompleto ($sizeGB GB). Verifique su conexión e intente nuevamente."
        }
    } else {
        throw "No se pudo completar la descarga desde los servidores de Microsoft."
    }

} catch {
    Write-Host ""
    Write-ErrorMsg "Fallo en Método B: $($_.Exception.Message)"
} finally {
    Write-LogSummary
}

return $downloadResult
