<#
.SYNOPSIS
    Get-WindowsUpdates.ps1 - Descargador Automatizado de Actualizaciones Oficiales de Windows (MSU/CAB)
    Motor de Consulta en Tiempo Real al Microsoft Update Catalog

.DESCRIPTION
    Obtiene e integra paquetes de actualización oficiales directamente desde la red de distribución (CDN)
    de Microsoft Update. Diseñado específicamente para alimentar el flujo de inyección offline (slipstreaming)
    en imágenes WIM (install.wim / winre.wim / boot.wim) con DISM dentro de New-OptimizedWindowsISO-v2.ps1.

    Soporta descarga de:
      1. LCU (Latest Cumulative Update) - Parche mensual acumulativo de seguridad y calidad.
      2. SSU (Servicing Stack Update) - Motor de actualización de servicio de Windows.
      3. Cumulative Update for .NET Framework 3.5 & 4.8 / 4.8.1.
      4. SafeOS Dynamic Updates - Actualizaciones de compatibilidad para el entorno WinRE / Setup.

.PARAMETER Version
    Versión de destino de Windows:
    "11_25H2", "11_24H2", "11_23H2", "10_22H2", "11_LTSC_2024", "10_LTSC_2021".

.PARAMETER Architecture
    Arquitectura de destino: "amd64" (x64, por defecto), "arm64", "x86".

.PARAMETER PackageType
    Tipo de paquetes a descargar: "All" (LCU + .NET + SSU), "LCUOnly", "DotNetOnly", "SafeOSOnly".

.PARAMETER OutputDir
    Directorio de destino para guardar los archivos .msu y .cab.
    Si se omite en modo interactivo, se le solicita al usuario con la ruta estándar por defecto.

.PARAMETER IncludeSafeOS
    Incluye la descarga de la actualización dinámica SafeOS (.cab) para WinRE y Setup.

.PARAMETER SkipSignatureCheck
    Omite la validación de firma digital Authenticode de Microsoft en los paquetes descargados.

.PARAMETER Unattended
    Ejecución desatendida sin prompts ni menús interactivos.

.PARAMETER DownloadTimeoutSeconds
    Tiempo límite máximo en segundos para la descarga de cada paquete (por defecto: 1800s / 30 min).

.EXAMPLE
    .\Get-WindowsUpdates.ps1
    (Abre el asistente interactivo con menús unificados)

.EXAMPLE
    .\Get-WindowsUpdates.ps1 -Version "11_24H2" -PackageType "All" -OutputDir "C:\OptimizedISO\Updates" -Unattended
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [ValidateSet("11_25H2", "11_24H2", "11_23H2", "10_22H2", "11_LTSC_2024", "10_LTSC_2021")]
    [string]$Version = "",

    [Parameter()]
    [ValidateSet("amd64", "arm64", "x86")]
    [string]$Architecture = "amd64",

    [Parameter()]
    [ValidateSet("All", "LCUOnly", "DotNetOnly", "SafeOSOnly")]
    [string]$PackageType = "All",

    [Parameter()]
    [string]$OutputDir = "",

    [Parameter()]
    [switch]$IncludeSafeOS,

    [Parameter()]
    [switch]$SkipSignatureCheck,

    [Parameter()]
    [switch]$Unattended,

    [Parameter()]
    [int]$DownloadTimeoutSeconds = 1800
)

# -----------------------------------------------------------------------------
# 0. CONFIGURACIÓN DE ENTORNO Y AUTO-ELEVACIÓN UAC
# -----------------------------------------------------------------------------
$ErrorActionPreference = 'Continue'
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Auto-elevación si es requerida para manipulación de carpetas protegidas
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $Unattended) {
    Write-Host "  [!] Elevando privilegios de Administrador (UAC)..." -ForegroundColor Yellow
    $scriptPath = $MyInvocation.MyCommand.Definition
    if (-not $scriptPath) { $scriptPath = $PSCommandPath }
    
    $argList = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath)
    if ($Version) { $argList += @('-Version', $Version) }
    if ($Architecture) { $argList += @('-Architecture', $Architecture) }
    if ($PackageType) { $argList += @('-PackageType', $PackageType) }
    if ($OutputDir) { $argList += @('-OutputDir', $OutputDir) }
    if ($IncludeSafeOS) { $argList += '-IncludeSafeOS' }
    if ($SkipSignatureCheck) { $argList += '-SkipSignatureCheck' }
    
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
    } catch {
        Write-Error "Fallo al solicitar elevacion UAC: $($_.Exception.Message)"
    }
    exit
}

# -----------------------------------------------------------------------------
# 1. CARGA DE MOTOR VISUAL UNIFICADO O MICRO-FALLBACK STANDALONE
# -----------------------------------------------------------------------------
$uiEnginePaths = @(
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
}

# -----------------------------------------------------------------------------
# 2. RESOLUCIÓN DE CARPETA DE DESTINO (INTERACTIVA O CLI)
# -----------------------------------------------------------------------------
$defaultBaseDir = Join-Path (Split-Path $PSScriptRoot -Parent) "Updates"
if (-not (Test-Path (Split-Path $PSScriptRoot -Parent))) {
    $defaultBaseDir = "C:\OptimizedISO\Updates"
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    if (-not $Unattended) {
        Show-UnifiedBanner -Title "DESCARGADOR DE WINDOWS UPDATES" -Subtitle "Microsoft Update Catalog Engine" -ShowSystemInfo
        Write-Host "  Configuracion de Destino para Paquetes (.msu / .cab):" -ForegroundColor Cyan
        Write-Host "  Carpeta por defecto sugerida: $defaultBaseDir" -ForegroundColor DarkGray
        Write-Host ""
        $userPath = Read-Host "  [?] Ingrese carpeta de destino (Enter para usar la predeterminada)"
        if ([string]::IsNullOrWhiteSpace($userPath)) {
            $OutputDir = $defaultBaseDir
        } else {
            $OutputDir = $userPath.Trim('"', "'")
        }
    } else {
        $OutputDir = $defaultBaseDir
    }
}

# Crear carpeta de destino si no existe
if (-not (Test-Path $OutputDir)) {
    try {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        Write-OK "Carpeta de destino creada: $OutputDir"
    } catch {
        Write-ErrorMsg "No se pudo crear la carpeta de destino '$OutputDir': $($_.Exception.Message)"
        $OutputDir = $defaultBaseDir
        New-Item -ItemType Directory -Path $OutputDir -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

# -----------------------------------------------------------------------------
# 3. SUBSISTEMA DE LOGGING Y DIAGNÓSTICO
# -----------------------------------------------------------------------------
$logDir = Join-Path $OutputDir "Logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

$_logTs                = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:LogFile        = Join-Path $logDir "Get-Updates_$_logTs.log"
$script:TranscriptFile = Join-Path $logDir "Get-Updates_${_logTs}_transcript.log"
$script:AiSummaryFile  = Join-Path $logDir "Get-Updates_${_logTs}_AI_SUMMARY.md"
$script:StartTime      = Get-Date

$script:LogErrors  = [System.Collections.Generic.List[string]]::new()
$script:LogWarns   = [System.Collections.Generic.List[string]]::new()
$script:Downloaded = [System.Collections.Generic.List[PSObject]]::new()

function Write-LogEntry {
    [CmdletBinding()]
    param(
        [ValidateSet("INIT","STEP","INFO","OK","WARN","ERROR","DEBUG")]
        [string]$Level = "INFO",
        [string]$Message
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$($Level.PadRight(5))] $Message"
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    if ($Level -eq "ERROR") { $script:LogErrors.Add($Message) }
    if ($Level -eq "WARN")  { $script:LogWarns.Add($Message)  }
}

function Write-LogSummary {
    $totalDuration = [math]::Round(((Get-Date) - $script:StartTime).TotalSeconds, 1)

    try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch {}

    try {
        $overallStatus = if ($script:LogErrors.Count -eq 0) { "SUCCESS" } else { "FAILED" }
        $statusBadge   = if ($overallStatus -eq "SUCCESS") { "SUCCESS ✅" } else { "FAILED ❌" }

        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("# AI Diagnostic Report: Get-WindowsUpdates")
        [void]$sb.AppendLine("- **Status:** $statusBadge")
        [void]$sb.AppendLine("- **Timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        [void]$sb.AppendLine("- **Total Duration:** ${totalDuration}s")
        [void]$sb.AppendLine("- **Host:** $env:COMPUTERNAME | **User:** $env:USERNAME | **PowerShell:** $($PSVersionTable.PSVersion)")
        [void]$sb.AppendLine("- **Target Version:** $script:SelectedVersion ($script:SelectedArch)")
        [void]$sb.AppendLine("- **Output Directory:** ``$OutputDir``")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Downloaded Update Packages")
        [void]$sb.AppendLine("| Package | KB | Type | Size | Status | Signature | File |")
        [void]$sb.AppendLine("|---|---|---|---|---|---|---|")

        foreach ($pkg in $script:Downloaded) {
            $stBadge = if ($pkg.Status -eq "OK") { "OK ✅" } else { "FAIL ❌" }
            $sigBadge = if ($pkg.Signature -eq "Valid") { "Valid 🛡️" } else { "$($pkg.Signature)" }
            [void]$sb.AppendLine("| $($pkg.Title) | $($pkg.KB) | $($pkg.Type) | $($pkg.Size) | $stBadge | $sigBadge | ``$($pkg.FileName)`` |")
        }

        if ($script:LogErrors.Count -gt 0) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("## ❌ Errors Detected")
            [void]$sb.AppendLine('```text')
            foreach ($err in $script:LogErrors) { [void]$sb.AppendLine($err) }
            [void]$sb.AppendLine('```')
        }

        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Slipstreaming Integration")
        [void]$sb.AppendLine("Los paquetes descargados son detectados automáticamente por ``New-OptimizedWindowsISO-v2.ps1``")
        [void]$sb.AppendLine("en la carpeta ``$OutputDir`` para ser inyectados con DISM /Add-Package.")

        if ($script:AiSummaryFile) {
            [System.IO.File]::WriteAllText($script:AiSummaryFile, $sb.ToString(), [System.Text.Encoding]::UTF8)
        }
    } catch {}

    $logMap = @{}
    if ($script:AiSummaryFile)  { $logMap["AI Diagnostic MD"] = $script:AiSummaryFile }
    if ($script:LogFile)        { $logMap["Log Estructurado"] = $script:LogFile }
    if ($script:TranscriptFile) { $logMap["Transcript"]       = $script:TranscriptFile }

    $st = if ($script:LogErrors.Count -eq 0) { "SUCCESS" } else { "FAILED" }
    Show-UnifiedSummary -Title "DESCARGA DE WINDOWS UPDATES" -Status $st -DurationSeconds $totalDuration -ErrorsCount $script:LogErrors.Count -WarnsCount $script:LogWarns.Count -Logs $logMap
}

# -----------------------------------------------------------------------------
# 4. MOTOR DE CONSULTA AL MICROSOFT UPDATE CATALOG
# -----------------------------------------------------------------------------

function Search-MicrosoftUpdateCatalog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query
    )

    $encodedQuery = [uri]::EscapeDataString($Query)
    $catalogUrl = "https://www.catalog.update.microsoft.com/Search.aspx?q=$encodedQuery"
    
    Write-LogEntry -Level "DEBUG" -Message "Consultando Catalog: $catalogUrl"

    $req = [System.Net.HttpWebRequest]::Create($catalogUrl)
    $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36'
    $req.Timeout = 20000
    
    $resp = $null
    $html = ""
    try {
        $resp = $req.GetResponse()
        $reader = [System.IO.StreamReader]::new($resp.GetResponseStream())
        $html = $reader.ReadToEnd()
        $reader.Close()
    } catch {
        Write-LogEntry -Level "ERROR" -Message "Fallo de conexion con Microsoft Update Catalog: $($_.Exception.Message)"
        return @()
    } finally {
        if ($resp) { $resp.Close() }
    }

    $results = @()
    $rowMatches = [regex]::Matches($html, '(?s)<tr\s+id=["'']([0-9a-fA-F\-]{36})_R\d+["''][^>]*>(.*?)</tr>')

    foreach ($rm in $rowMatches) {
        $id = $rm.Groups[1].Value
        $content = $rm.Groups[2].Value

        $title = if ($content -match '(?s)<a[^>]*id=["''][^"'']*_link["''][^>]*>(.*?)</a>') {
            ($matches[1] -replace '\s+', ' ').Trim()
        } else {
            "Update ($id)"
        }

        $size = if ($content -match '<span[^>]*id=["''][^"'']*_size["''][^>]*>(.*?)</span>') {
            $matches[1].Trim()
        } else { "" }

        $date = if ($content -match '(?s)<td[^>]*id=["''][^"'']*_C4_R\d+["''][^>]*>(.*?)</td>') {
            ($matches[1] -replace '\s+', ' ').Trim()
        } else { "" }

        $kb = if ($title -match 'KB(\d+)') { "KB$($matches[1])" } else { "" }

        $results += [PSCustomObject]@{
            Id    = $id
            KB    = $kb
            Title = $title
            Date  = $date
            Size  = $size
        }
    }

    return $results
}

function Get-CatalogDownloadLinks {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UpdateId
    )

    $dialogPayload = "[{""size"":0,""languages"":"""",""uidInfo"":""$UpdateId"",""updateID"":""$UpdateId""}]"
    $dialogUrl = "https://www.catalog.update.microsoft.com/DownloadDialog.aspx?updateIDs=" + [uri]::EscapeDataString($dialogPayload)

    $req = [System.Net.HttpWebRequest]::Create($dialogUrl)
    $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36'
    $req.Timeout = 15000

    $resp = $null
    $html = ""
    try {
        $resp = $req.GetResponse()
        $reader = [System.IO.StreamReader]::new($resp.GetResponseStream())
        $html = $reader.ReadToEnd()
        $reader.Close()
    } catch {
        Write-LogEntry -Level "ERROR" -Message "Error al obtener enlaces de descarga para UpdateID ${UpdateId}: $($_.Exception.Message)"
        return @()
    } finally {
        if ($resp) { $resp.Close() }
    }

    $urls = @()
    $matches = [regex]::Matches($html, 'downloadInformation\[\d+\]\.files\[\d+\]\.url\s*=\s*''([^'']+)''')
    foreach ($m in $matches) {
        $urls += $m.Groups[1].Value
    }
    return $urls
}

# -----------------------------------------------------------------------------
# 5. MOTOR DE DESCARGA CON PROGRESO Y VERIFICACIÓN AUTHENTICODE
# -----------------------------------------------------------------------------

function Invoke-UpdateDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$DestinationFile,

        [Parameter()]
        [string]$Description = "",

        [Parameter()]
        [int]$TimeoutSeconds = 1800
    )

    $tempFile = "$DestinationFile.tmp"
    if (Test-Path $tempFile) { Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue }

    # Verificar si el archivo ya existe y es válido
    if (Test-Path $DestinationFile) {
        $existingLength = (Get-Item $DestinationFile).Length
        if ($existingLength -gt 10240) {
            $isGenuine = $true
            if (-not $SkipSignatureCheck -and ($DestinationFile -match '\.(msu|cab|exe)$')) {
                try {
                    $sig = Get-AuthenticodeSignature -FilePath $DestinationFile -ErrorAction SilentlyContinue
                    if ($sig.Status -ne "Valid") { $isGenuine = $false }
                } catch { $isGenuine = $false }
            }
            if ($isGenuine) {
                Write-OK "Paquete ya existente y validado: $(Split-Path -Leaf $DestinationFile) ($([math]::Round($existingLength/1MB, 1)) MB)"
                Write-LogEntry -Level "OK" -Message "Archivo ya presente y valido: $DestinationFile"
                return $true
            }
        }
    }

    Write-SubStep "Conectando con CDN de Microsoft..."
    Write-LogEntry -Level "INFO" -Message "Iniciando descarga: $Url -> $DestinationFile"

    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.Method = "GET"
    $request.Timeout = $TimeoutSeconds * 1000
    $request.ReadWriteTimeout = $TimeoutSeconds * 1000
    $request.AllowAutoRedirect = $true
    $request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"

    $response = $null
    $responseStream = $null
    $fileStream = $null

    try {
        $response = $request.GetResponse()
        $totalBytes = $response.ContentLength
        $responseStream = $response.GetResponseStream()
        $fileStream = [System.IO.File]::Create($tempFile)

        $buffer = New-Object byte[] 65536
        $downloadedBytes = 0
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $lastReportSec = 0

        $totalMB = if ($totalBytes -gt 0) { [math]::Round($totalBytes / 1MB, 1) } else { 0 }

        while (($bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fileStream.Write($buffer, 0, $bytesRead)
            $downloadedBytes += $bytesRead

            $elapsedSec = [math]::Max(1, [int]$sw.Elapsed.TotalSeconds)
            if (($elapsedSec - $lastReportSec) -ge 2) {
                $lastReportSec = $elapsedSec
                $speedMBs = [math]::Round(($downloadedBytes / 1MB) / $elapsedSec, 2)
                $curMB = [math]::Round($downloadedBytes / 1MB, 1)

                if ($totalBytes -gt 0) {
                    $pct = [math]::Round(($downloadedBytes / $totalBytes) * 100, 0)
                    Write-Host "    [⏳ Descargando] $curMB MB / $totalMB MB ($pct%) - $speedMBs MB/s`r" -NoNewline -ForegroundColor Cyan
                } else {
                    Write-Host "    [⏳ Descargando] $curMB MB descargados - $speedMBs MB/s`r" -NoNewline -ForegroundColor Cyan
                }
            }
        }
        Write-Host "                                                                                `r" -NoNewline
    } catch {
        Write-ErrorMsg "Error durante la descarga de '$Description': $($_.Exception.Message)"
        Write-LogEntry -Level "ERROR" -Message "Descarga fallida: $($_.Exception.Message)"
        if (Test-Path $tempFile) { Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue }
        return $false
    } finally {
        if ($fileStream)     { $fileStream.Flush(); $fileStream.Close() }
        if ($responseStream) { $responseStream.Close() }
        if ($response)       { $response.Close() }
    }

    # Validar integridad y tamaño
    if ((Test-Path $tempFile) -and ((Get-Item $tempFile).Length -gt 10240)) {
        if (Test-Path $DestinationFile) { Remove-Item -Path $DestinationFile -Force -ErrorAction SilentlyContinue }
        Move-Item -Path $tempFile -Destination $DestinationFile -Force

        # Verificación Authenticode
        $sigStatus = "Skipped"
        if (-not $SkipSignatureCheck) {
            try {
                $sig = Get-AuthenticodeSignature -FilePath $DestinationFile -ErrorAction SilentlyContinue
                $sigStatus = $sig.Status.ToString()
                if ($sig.Status -eq "Valid") {
                    Write-OK "Firma digital oficial de Microsoft verificada: $(Split-Path -Leaf $DestinationFile)"
                } else {
                    Write-Warn "Advertencia de firma Authenticode ($sigStatus): $(Split-Path -Leaf $DestinationFile)"
                }
            } catch {
                $sigStatus = "Unknown"
            }
        }

        Write-LogEntry -Level "OK" -Message "Descarga completada y verificada ($sigStatus): $DestinationFile"
        return $true
    } else {
        if (Test-Path $tempFile) { Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue }
        Write-ErrorMsg "El archivo descargado está vacío o corrupto."
        return $false
    }
}

# -----------------------------------------------------------------------------
# 6. MENÚ INTERACTIVO Y SELECCIÓN DE VERSIÓN
# -----------------------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($Version) -and -not $Unattended) {
    Show-UnifiedBanner -Title "DESCARGADOR DE WINDOWS UPDATES" -Subtitle "Selección de Versión de Windows" -ShowSystemInfo

    $versionOpts = @(
        "Windows 11 24H2 / 25H2 (Compilación 26100+)",
        "Windows 11 23H2 (Compilación 22631)",
        "Windows 11 IoT Enterprise LTSC 2024 (Compilación 26100)",
        "Windows 10 22H2 (Compilación 19045)",
        "Windows 10 Enterprise LTSC 2021 (Compilación 19044)"
    )

    $vChoice = Show-UnifiedMenu -Title "VERSIONES OFICIALES DISPONIBLES" -Options $versionOpts -DefaultChoice 1 -AllowCancel -CancelText "Cancelar y Salir"
    
    switch ($vChoice) {
        1 { $Version = "11_24H2" }
        2 { $Version = "11_23H2" }
        3 { $Version = "11_LTSC_2024" }
        4 { $Version = "10_22H2" }
        5 { $Version = "10_LTSC_2021" }
        default {
            Write-Host "`n  Operacion cancelada por el usuario.`n" -ForegroundColor Yellow
            exit 0
        }
    }
} elseif ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = "11_24H2"
}

$script:SelectedVersion = $Version
$script:SelectedArch    = $Architecture

# Subcarpeta específica para mantener orden por versión
$targetFolder = Join-Path $OutputDir "$($Version)_$($Architecture)"
if (-not (Test-Path $targetFolder)) {
    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
}

try { Start-Transcript -Path $script:TranscriptFile -Append -ErrorAction Stop | Out-Null } catch {}

Write-LogEntry -Level "INIT" -Message ("=" * 64)
Write-LogEntry -Level "INIT" -Message "Iniciando Descarga de Windows Updates"
Write-LogEntry -Level "INIT" -Message "Versión: $Version | Arch: $Architecture | Tipo: $PackageType | Destino: $targetFolder"
Write-LogEntry -Level "INIT" -Message ("=" * 64)

# -----------------------------------------------------------------------------
# 7. DEFINICIÓN DE CONSULTAS AL CATALOG POR VERSIÓN
# -----------------------------------------------------------------------------

$archTag = switch ($Architecture) {
    "arm64" { "arm64" }
    "x86"   { "x86" }
    default { "x64" }
}

$searchMatrix = switch ($Version) {
    "11_25H2" {
        @{
            LCU    = "Cumulative Update Windows 11 25H2 $archTag"
            DotNet = "Cumulative Update .NET Framework Windows 11 25H2 $archTag"
            SafeOS = "Safe OS Dynamic Update Windows 11 25H2 $archTag"
        }
    }
    "11_24H2" {
        @{
            LCU    = "Cumulative Update Windows 11 24H2 $archTag"
            DotNet = "Cumulative Update for .NET Framework 3.5 and 4.8.1 for Windows 11, version 24H2 for $archTag"
            SafeOS = "Safe OS Dynamic Update for Windows 11, version 24H2 for $archTag"
        }
    }
    "11_LTSC_2024" {
        @{
            LCU    = "Cumulative Update Windows 11 24H2 $archTag"
            DotNet = "Cumulative Update for .NET Framework 3.5 and 4.8.1 for Windows 11, version 24H2 for $archTag"
            SafeOS = "Safe OS Dynamic Update for Windows 11, version 24H2 for $archTag"
        }
    }
    "11_23H2" {
        @{
            LCU    = "Cumulative Update Windows 11 23H2 $archTag"
            DotNet = "Cumulative Update for .NET Framework 3.5 and 4.8.1 for Windows 11, version 23H2 for $archTag"
            SafeOS = "Safe OS Dynamic Update for Windows 11, version 23H2 for $archTag"
        }
    }
    "10_22H2" {
        @{
            LCU    = "Cumulative Update Windows 10 22H2 $archTag"
            DotNet = "Cumulative Update for .NET Framework 3.5 and 4.8.1 for Windows 10 Version 22H2 for $archTag"
            SafeOS = "Safe OS Dynamic Update for Windows 10 Version 22H2 for $archTag"
        }
    }
    "10_LTSC_2021" {
        @{
            LCU    = "Cumulative Update Windows 10 21H2 $archTag"
            DotNet = "Cumulative Update for .NET Framework 3.5 and 4.8.1 for Windows 10 Version 21H2 for $archTag"
            SafeOS = "Safe OS Dynamic Update for Windows 10 Version 21H2 for $archTag"
        }
    }
}

# -----------------------------------------------------------------------------
# 8. EJECUCIÓN DEL PIPELINE DE BÚSQUEDA Y DESCARGA
# -----------------------------------------------------------------------------

Show-UnifiedBanner -Title "romanOS - WINDOWS UPDATES ENGINE" -Subtitle "Obtención de Actualizaciones Oficiales ($Version - $Architecture)"

Write-StepHeader -StepNumber 1 -TotalSteps 3 -Message "Consultando Catálogo Oficial de Microsoft Update"

$packagesToDownload = [System.Collections.Generic.List[PSObject]]::new()

# 1. Búsqueda de LCU (Latest Cumulative Update)
if ($PackageType -in @("All", "LCUOnly")) {
    Write-SubStep "Buscando Parche Acumulativo de Sistema Operativo (LCU)..."
    $lcuItems = Search-MicrosoftUpdateCatalog -Query $searchMatrix.LCU
    
    # Filtrar el parche acumulativo del SO (excluyendo .NET y SafeOS)
    $lcuMatch = $lcuItems | Where-Object {
        $_.Title -match 'Cumulative Update for (Windows 10|Windows 11)' -and
        $_.Title -notmatch '\.NET' -and
        $_.Title -notmatch 'Dynamic'
    } | Select-Object -First 1

    if ($lcuMatch) {
        Write-OK "LCU Identificado: $($lcuMatch.KB) - $($lcuMatch.Title) ($($lcuMatch.Size))"
        $packagesToDownload.Add([PSCustomObject]@{
            Type  = "LCU"
            Id    = $lcuMatch.Id
            KB    = $lcuMatch.KB
            Title = $lcuMatch.Title
            Size  = $lcuMatch.Size
        })
    } else {
        Write-Warn "No se pudo identificar un LCU específico en la consulta inicial. Probando consulta genérica..."
        $lcuAlt = Search-MicrosoftUpdateCatalog -Query "Cumulative Update for Windows 11 for $archTag" | Select-Object -First 1
        if ($lcuAlt) {
            Write-OK "LCU Alternativo Identificado: $($lcuAlt.KB) - $($lcuAlt.Title) ($($lcuAlt.Size))"
            $packagesToDownload.Add([PSCustomObject]@{
                Type  = "LCU"
                Id    = $lcuAlt.Id
                KB    = $lcuAlt.KB
                Title = $lcuAlt.Title
                Size  = $lcuAlt.Size
            })
        } else {
            Write-ErrorMsg "No se encontraron paquetes LCU en el catálogo de Microsoft para esta versión."
        }
    }
}

# 2. Búsqueda de .NET Framework Cumulative Update
if ($PackageType -in @("All", "DotNetOnly")) {
    Write-SubStep "Buscando Actualización Acumulativa de .NET Framework (3.5 / 4.8.1)..."
    $dotNetItems = Search-MicrosoftUpdateCatalog -Query $searchMatrix.DotNet
    
    $dotNetMatch = $dotNetItems | Where-Object { $_.Title -match '\.NET Framework' } | Select-Object -First 1
    if ($dotNetMatch) {
        Write-OK ".NET Update Identificado: $($dotNetMatch.KB) - $($dotNetMatch.Title) ($($dotNetMatch.Size))"
        $packagesToDownload.Add([PSCustomObject]@{
            Type  = "DotNet"
            Id    = $dotNetMatch.Id
            KB    = $dotNetMatch.KB
            Title = $dotNetMatch.Title
            Size  = $dotNetMatch.Size
        })
    } else {
        Write-Warn "No se encontró actualización acumulativa de .NET Framework específica en el catálogo."
    }
}

# 3. Búsqueda de SafeOS Dynamic Update (Opcional)
if ($IncludeSafeOS -or $PackageType -eq "SafeOSOnly") {
    Write-SubStep "Buscando SafeOS Dynamic Update (WinRE / Setup)..."
    $safeOsItems = Search-MicrosoftUpdateCatalog -Query $searchMatrix.SafeOS
    $safeOsMatch = $safeOsItems | Where-Object { $_.Title -match 'Safe OS Dynamic' } | Select-Object -First 1
    if ($safeOsMatch) {
        Write-OK "SafeOS Identificado: $($safeOsMatch.KB) - $($safeOsMatch.Title) ($($safeOsMatch.Size))"
        $packagesToDownload.Add([PSCustomObject]@{
            Type  = "SafeOS"
            Id    = $safeOsMatch.Id
            KB    = $safeOsMatch.KB
            Title = $safeOsMatch.Title
            Size  = $safeOsMatch.Size
        })
    }
}

if ($packagesToDownload.Count -eq 0) {
    Write-ErrorMsg "No se seleccionaron paquetes para descargar o la consulta al catálogo no arrojó resultados."
    Write-LogSummary
    exit 1
}

# -----------------------------------------------------------------------------
# 9. RESOLUCIÓN DE ENLACES CDN DIRECTOS
# -----------------------------------------------------------------------------

Write-StepHeader -StepNumber 2 -TotalSteps 3 -Message "Resolviendo Enlaces CDN de Microsoft"

$downloadTasks = [System.Collections.Generic.List[PSObject]]::new()

foreach ($pkg in $packagesToDownload) {
    Write-SubStep "Obteniendo URLs de descarga para $($pkg.KB) ($($pkg.Type))..."
    $urls = Get-CatalogDownloadLinks -UpdateId $pkg.Id
    
    if ($urls.Count -gt 0) {
        Write-OK "Enlaces resueltos para $($pkg.KB): $($urls.Count) archivo(s) CDN disponible(s)."
        foreach ($u in $urls) {
            $fileName = [System.IO.Path]::GetFileName(([uri]$u).LocalPath)
            $downloadTasks.Add([PSCustomObject]@{
                Type     = $pkg.Type
                KB       = $pkg.KB
                Title    = $pkg.Title
                Url      = $u
                FileName = $fileName
                SizeEst  = $pkg.Size
            })
        }
    } else {
        Write-ErrorMsg "No se pudieron obtener URLs CDN para $($pkg.KB)."
    }
}

# -----------------------------------------------------------------------------
# 10. DESCARGA E INTEGRACIÓN FÍSICA
# -----------------------------------------------------------------------------

Write-StepHeader -StepNumber 3 -TotalSteps 3 -Message "Descargando e Integrando Paquetes en $targetFolder"

$successCount = 0
$failCount    = 0

foreach ($task in $downloadTasks) {
    Write-Host ""
    Write-Host "  ══ Paquete: $($task.KB) [$($task.Type)] ══" -ForegroundColor Cyan
    Write-Host "  Archivo : $($task.FileName)" -ForegroundColor Gray
    Write-Host "  Tamaño  : $($task.SizeEst)" -ForegroundColor DarkGray
    
    $destFile = Join-Path $targetFolder $task.FileName
    $dlSuccess = Invoke-UpdateDownload -Url $task.Url -DestinationFile $destFile -Description "$($task.KB) - $($task.FileName)" -TimeoutSeconds $DownloadTimeoutSeconds

    $sigStatus = "N/A"
    if ($dlSuccess -and (Test-Path $destFile)) {
        if (-not $SkipSignatureCheck) {
            try {
                $sig = Get-AuthenticodeSignature -FilePath $destFile -ErrorAction SilentlyContinue
                $sigStatus = $sig.Status.ToString()
            } catch { $sigStatus = "Unknown" }
        } else {
            $sigStatus = "Skipped"
        }
        $successCount++
    } else {
        $failCount++
    }

    $script:Downloaded.Add([PSCustomObject]@{
        Title     = $task.Title
        KB        = $task.KB
        Type      = $task.Type
        Size      = $task.SizeEst
        FileName  = $task.FileName
        Status    = if ($dlSuccess) { "OK" } else { "ERROR" }
        Signature = $sigStatus
        Path      = $destFile
    })
}

# -----------------------------------------------------------------------------
# 11. GENERACIÓN DE MANIFIESTO Y RESUMEN FINAL
# -----------------------------------------------------------------------------

$manifestPath = Join-Path $targetFolder "Updates_Manifest.json"
try {
    $manifestData = [PSCustomObject]@{
        GeneratedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        Version     = $Version
        Arch        = $Architecture
        TotalFiles  = $script:Downloaded.Count
        Packages    = $script:Downloaded
    }
    $manifestJson = $manifestData | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($manifestPath, $manifestJson, [System.Text.Encoding]::UTF8)
    Write-OK "Manifiesto de actualizaciones guardado: $manifestPath"
} catch {}

Write-LogSummary

Write-Host ""
Write-Host "  💡 Integración Automática con la ISO:" -ForegroundColor Green
Write-Host "     Al ejecutar 'New-OptimizedWindowsISO-v2.ps1', los parches ubicados en" -ForegroundColor Gray
Write-Host "     '$OutputDir' o '$targetFolder' serán inyectados automáticamente con DISM." -ForegroundColor Gray
Write-Host ""
