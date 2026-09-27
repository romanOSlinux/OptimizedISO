<#
.SYNOPSIS
    Descarga y organiza los Runtimes esenciales oficiales de Microsoft para su integración en la ISO.

.DESCRIPTION
    Este script descarga directamente desde los servidores oficiales de Microsoft (CDN / aka.ms):
      - Microsoft Visual C++ 2015-2022 Redistributable (x64 y x86) [v14.4x - Latest]
      - Microsoft Visual C++ 2013 Redistributable (x64 y x86) [v12.0.40664.0]
      - Microsoft Visual C++ 2012 Update 4 Redistributable (x64 y x86) [v11.0.61030.0]
      - Microsoft Visual C++ 2010 SP1 Redistributable (x64 y x86) [Opcional / -IncludeLegacy]
      - Microsoft Visual C++ 2008 SP1 Redistributable (x64 y x86) [Opcional / -IncludeLegacy]
      - Microsoft DirectX End-User Runtimes (Junio 2010) y lo extrae en la carpeta DirectX/

    Los archivos se guardan en la carpeta 'Runtimes' para que 'New-OptimizedWindowsISO-v2.ps1'
    los empaquete automáticamente dentro de la ISO de Windows y se instalen silenciosamente vía SetupComplete.cmd.

.PARAMETER DestinationPath
    Ruta de destino donde se guardarán los instaladores. Alias: -DownloadDir, -Path, -OutDir. Por defecto: scripts/Runtimes.

.PARAMETER Force
    Fuerza la sobreescritura de archivos si ya existen.

.PARAMETER IncludeLegacy
    Descarga también los runtimes antiguos Visual C++ 2010 SP1 y 2008 SP1 para máxima compatibilidad con juegos clásicos.

.PARAMETER SkipDirectX
    Omite la descarga y extracción del paquete DirectX End-User Runtimes (Junio 2010).

.EXAMPLE
    .\Get-EssentialRuntimes.ps1
    .\Get-EssentialRuntimes.ps1 -DownloadDir "D:\OptimizedISO\scripts\Runtimes" -IncludeLegacy
    .\Get-EssentialRuntimes.ps1 -Force -SkipDirectX
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [Alias("DownloadDir", "Path", "OutDir")]
    [string]$DestinationPath = "",

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$IncludeLegacy,

    [Parameter()]
    [switch]$SkipDirectX,

    [Parameter()]
    [switch]$Unattended,

    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'

# Habilitar TLS 1.2 y TLS 1.3 de forma segura y compatible con PowerShell 5.1 y 7+
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor 12288
} catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# Resolver carpeta de destino (alineado con la raíz del proyecto SSOT)
if (-not $DestinationPath) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    # Retroceder dos niveles desde scripts\Builder -> raíz
    $projectRoot = Split-Path (Split-Path $scriptDir -Parent) -Parent
    $DestinationPath = Join-Path $projectRoot "Runtimes"
}

if (-not (Test-Path $DestinationPath)) {
    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
}

# -----------------------------------------------------------------------------
# CARGA DE MOTOR VISUAL UNIFICADO O MICRO-FALLBACK STANDALONE
# -----------------------------------------------------------------------------
$uiEnginePaths = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\UI-Engine.ps1"),
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
    function Show-UnifiedSummary { param($Title,$Status,$DurationSeconds,$ErrorsCount,$WarnsCount,$Logs) Write-Host "`n=== $($Title): $Status (${DurationSeconds}s) ===`n" -ForegroundColor Cyan }
}

# ============================================================
# LOGGING ENGINE — AI-Ready Diagnostic Report
# ============================================================
$logDir = Join-Path $DestinationPath "Logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

$_logTs                = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:LogFile        = Join-Path $logDir "Get-Runtimes_$_logTs.log"
$script:TranscriptFile = Join-Path $logDir "Get-Runtimes_${_logTs}_transcript.log"
$script:AiSummaryFile  = Join-Path $logDir "Get-Runtimes_${_logTs}_AI_SUMMARY.md"
$script:StartTime      = Get-Date

$script:LogErrors = [System.Collections.Generic.List[string]]::new()
$script:LogWarns  = [System.Collections.Generic.List[string]]::new()
$script:Downloads = [System.Collections.Generic.List[PSObject]]::new()

function Write-LogEntry {
    [CmdletBinding()]
    param(
        [ValidateSet("INIT","STEP","INFO","OK","WARN","ERROR","DEBUG")]
        [string]$Level = "INFO",
        [string]$Message
    )
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$($Level.PadRight(5))] $Message"
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    if ($Level -eq "ERROR") { $script:LogErrors.Add($line) }
    if ($Level -eq "WARN")  { $script:LogWarns.Add($line) }
}

function Write-LogSummary {
    $totalDuration = [math]::Round(((Get-Date) - $script:StartTime).TotalSeconds, 1)

    Write-LogEntry -Level "INIT" -Message ("=" * 64)
    Write-LogEntry -Level "INIT" -Message "RESUMEN FINAL"
    Write-LogEntry -Level "INFO" -Message "Duración total       : ${totalDuration}s"
    Write-LogEntry -Level "INFO" -Message "Errores registrados : $($script:LogErrors.Count)"
    Write-LogEntry -Level "INFO" -Message "Advertencias        : $($script:LogWarns.Count)"
    if ($script:LogErrors.Count -gt 0) {
        Write-LogEntry -Level "INIT" -Message "--- ERRORES DETECTADOS ---"
        $errorSnapshot = @($script:LogErrors)
        foreach ($e in $errorSnapshot) {
            Write-LogEntry -Level "INFO" -Message "  $e"
        }
    }
    if ($script:LogErrors.Count -eq 0) {
        Write-LogEntry -Level "OK" -Message "Descarga de runtimes completada con éxito."
    }
    Write-LogEntry -Level "INIT" -Message "Log estructurado    : $script:LogFile"
    Write-LogEntry -Level "INIT" -Message "AI Summary (MD)     : $script:AiSummaryFile"
    Write-LogEntry -Level "INIT" -Message "Transcript          : $script:TranscriptFile"
    Write-LogEntry -Level "INIT" -Message ("=" * 64)

    try { Stop-Transcript -ErrorAction Stop | Out-Null } catch {
        Write-LogEntry -Level "INFO" -Message "Transcript finalizado: $($_.Exception.Message)"
    }

    try {
        $overallStatus = if ($script:LogErrors.Count -eq 0) { "SUCCESS" } else { "FAILED" }
        $statusBadge   = if ($overallStatus -eq "SUCCESS") { "SUCCESS ✅" } else { "FAILED ❌" }

        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("# AI Diagnostic Report: Get-EssentialRuntimes")
        [void]$sb.AppendLine("- **Status:** $statusBadge")
        [void]$sb.AppendLine("- **Timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        [void]$sb.AppendLine("- **Total Duration:** ${totalDuration}s")
        [void]$sb.AppendLine("- **Destination:** ``$DestinationPath``")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Downloaded Packages")
        [void]$sb.AppendLine("| Package | Status | Size | File |")
        [void]$sb.AppendLine("|---|---|---|---|")

        foreach ($pkg in $script:Downloads) {
            $stBadge = if ($pkg.Status -eq "OK") { "OK ✅" } else { "FAIL ❌" }
            [void]$sb.AppendLine("| $($pkg.Name) | $stBadge | $($pkg.SizeMB) MB | ``$($pkg.FileName)`` |")
        }

        if ($script:LogErrors.Count -gt 0) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("## ❌ Errors Detected")
            [void]$sb.AppendLine('```text')
            foreach ($err in $script:LogErrors) { [void]$sb.AppendLine($err) }
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
        Write-ForensicException -Record $_ -Context "Generacion AI_SUMMARY.md" -SuggestedAction "Verifique permisos de escritura en la carpeta de Logs"
    }

    $logMap = @{}
    if ($script:AiSummaryFile)  { $logMap["AI Diagnostic MD"] = $script:AiSummaryFile }
    if ($script:LogFile)        { $logMap["Log Estructurado"] = $script:LogFile }
    if ($script:TranscriptFile) { $logMap["Transcript"]       = $script:TranscriptFile }

    $st = if ($script:LogErrors.Count -eq 0) { "SUCCESS" } else { "FAILED" }
    Show-UnifiedSummary -Title "DESCARGA DE RUNTIMES" -Status $st -DurationSeconds $totalDuration -ErrorsCount $script:LogErrors.Count -WarnsCount $script:LogWarns.Count -Logs $logMap
}

function Invoke-SafeDownload {
    [CmdletBinding()]
    param(
        [string]$Url,
        [string]$DestinationFile,
        [int]$TimeoutSeconds = 60
    )

    $tempFile = "$DestinationFile.tmp"
    if (Test-Path $tempFile) { Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue }

    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.Method = "GET"
    $request.Timeout = $TimeoutSeconds * 1000
    $request.ReadWriteTimeout = $TimeoutSeconds * 1000
    $request.AllowAutoRedirect = $true
    $request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"

    $response = $request.GetResponse()
    $responseStream = $response.GetResponseStream()
    $fileStream = [System.IO.File]::Create($tempFile)

    try {
        $buffer = New-Object byte[] 65536
        while (($bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fileStream.Write($buffer, 0, $bytesRead)
        }
    } finally {
        $fileStream.Flush()
        $fileStream.Close()
        $responseStream.Close()
        $response.Close()
    }

    # Validar que el archivo descargado no esté vacío
    if ((Test-Path $tempFile) -and ((Get-Item $tempFile).Length -gt 1024)) {
        if (Test-Path $DestinationFile) { Remove-Item -Path $DestinationFile -Force -ErrorAction SilentlyContinue }
        Move-Item -Path $tempFile -Destination $DestinationFile -Force
    } else {
        if (Test-Path $tempFile) { Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue }
        throw "La descarga resultó en un archivo vacío o corrupto."
    }
}

try {
    Start-Transcript -Path $script:TranscriptFile -Append -ErrorAction Stop | Out-Null
} catch {
    Write-LogEntry -Level "WARN" -Message "No se pudo iniciar transcript en ($script:TranscriptFile) - $($_.Exception.Message)"
}

Write-LogEntry -Level "INIT" -Message ("=" * 64)
Write-LogEntry -Level "INIT" -Message "Get-EssentialRuntimes Download Log"
Write-LogEntry -Level "INIT" -Message "PowerShell $($PSVersionTable.PSVersion) | Host: $env:COMPUTERNAME"
Write-LogEntry -Level "INIT" -Message ("=" * 64)

Show-UnifiedBanner -Title "DESCARGADOR DE RUNTIMES ESENCIALES" -Subtitle "Integracion Oficial Microsoft CDN para Windows ISO" -ShowSystemInfo
Write-Info "Carpeta de destino: $DestinationPath"
Write-Host ""

# Lista oficial de descargas de Microsoft CDN / aka.ms
# Fuente Oficial: https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist
$runtimes = [System.Collections.Generic.List[hashtable]]::new()

# Visual C++ 2015-2022 (Latest v14.4x)
$runtimes.Add(@{
    Name     = "Visual C++ 2015-2022 (x64)"
    FileName = "vc_redist.x64.exe"
    Url      = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
})
$runtimes.Add(@{
    Name     = "Visual C++ 2015-2022 (x86)"
    FileName = "vc_redist.x86.exe"
    Url      = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
})

# Visual C++ 2013 (v12.0.40664.0)
$runtimes.Add(@{
    Name     = "Visual C++ 2013 (x64)"
    FileName = "vcredist_2013_x64.exe"
    Url      = "https://aka.ms/highdpimfc2013x64enu"
})
$runtimes.Add(@{
    Name     = "Visual C++ 2013 (x86)"
    FileName = "vcredist_2013_x86.exe"
    Url      = "https://aka.ms/highdpimfc2013x86enu"
})

# Visual C++ 2012 Update 4 (v11.0.61030.0)
$runtimes.Add(@{
    Name     = "Visual C++ 2012 (x64)"
    FileName = "vcredist_2012_x64.exe"
    Url      = "https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe"
})
$runtimes.Add(@{
    Name     = "Visual C++ 2012 (x86)"
    FileName = "vcredist_2012_x86.exe"
    Url      = "https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe"
})

# Legacy: Visual C++ 2010 SP1 & 2008 SP1 (Opcional con -IncludeLegacy)
if ($IncludeLegacy) {
    $runtimes.Add(@{
        Name     = "Visual C++ 2010 SP1 (x64)"
        FileName = "vcredist_2010_x64.exe"
        Url      = "https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe"
    })
    $runtimes.Add(@{
        Name     = "Visual C++ 2010 SP1 (x86)"
        FileName = "vcredist_2010_x86.exe"
        Url      = "https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x86.exe"
    })
    $runtimes.Add(@{
        Name     = "Visual C++ 2008 SP1 (x64)"
        FileName = "vcredist_2008_x64.exe"
        Url      = "https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x64.exe"
    })
    $runtimes.Add(@{
        Name     = "Visual C++ 2008 SP1 (x86)"
        FileName = "vcredist_2008_x86.exe"
        Url      = "https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe"
    })
}

# Retorno temprano de catálogo para pruebas funcionales y simulación
if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf') -or $WhatIfPreference -or $PassThru) {
    if ($PassThru) {
        return $runtimes
    }
}

# 1. Descarga de Visual C++ Redistributables
$directXAdd = if ($SkipDirectX) { 0 } else { 1 }
$totalItems = $runtimes.Count + $directXAdd
$current = 0

foreach ($item in $runtimes) {
    $current++
    $targetFile = Join-Path $DestinationPath $item.FileName

    # Comprobar si ya existe y tiene un tamaño válido (> 100 KB)
    $isValidExisting = (Test-Path $targetFile) -and ((Get-Item $targetFile).Length -gt 102400)

    if ($isValidExisting -and (-not $Force)) {
        $sizeMB = [math]::Round((Get-Item $targetFile).Length / 1MB, 2)
        Write-Host "  [$current/$totalItems] $($item.Name): Ya existe ($sizeMB MB). Omitiendo." -ForegroundColor DarkGreen
        Write-LogEntry -Level "INFO" -Message "$($item.Name): ya existe ($sizeMB MB)."
        $script:Downloads.Add([PSCustomObject]@{
            Name     = $item.Name
            FileName = $item.FileName
            SizeMB   = $sizeMB
            Status   = "OK"
        })
        continue
    }

    Write-Host "  [$current/$totalItems] Descargando $($item.Name)..." -ForegroundColor Yellow -NoNewline
    Write-LogEntry -Level "INFO" -Message "Iniciando descarga: $($item.Name)"
    try {
        Invoke-SafeDownload -Url $item.Url -DestinationFile $targetFile
        $sizeMB = [math]::Round((Get-Item $targetFile).Length / 1MB, 2)
        Write-Host " [OK] ($sizeMB MB)" -ForegroundColor Green
        Write-LogEntry -Level "OK" -Message "$($item.Name) descargado correctamente ($sizeMB MB)."
        $script:Downloads.Add([PSCustomObject]@{
            Name     = $item.Name
            FileName = $item.FileName
            SizeMB   = $sizeMB
            Status   = "OK"
        })
    } catch {
        Write-Host " [ERROR: $($_.Exception.Message)]" -ForegroundColor Red
        Write-LogEntry -Level "ERROR" -Message "$($item.Name) fallo: $($_.Exception.Message)"
        # Limpieza de archivo parcial corrupto si quedó huérfano
        if (Test-Path $targetFile) { Remove-Item -Path $targetFile -Force -ErrorAction SilentlyContinue }
        $script:Downloads.Add([PSCustomObject]@{
            Name     = $item.Name
            FileName = $item.FileName
            SizeMB   = 0
            Status   = "ERROR"
        })
    }
}

# 2. Descarga y extracción de DirectX End-User Runtimes (Junio 2010)
if (-not $SkipDirectX) {
    $current++
    $directxExtractDir = Join-Path $DestinationPath "DirectX"
    $directxSetupExe = Join-Path $directxExtractDir "dxsetup.exe"

    if ((Test-Path $directxSetupExe) -and (-not $Force)) {
        Write-Host "  [$current/$totalItems] DirectX End-User (Junio 2010): Ya extraído en DirectX/. Omitiendo." -ForegroundColor DarkGreen
        Write-LogEntry -Level "INFO" -Message "DirectX End-User: ya extraído en DirectX/."
        $script:Downloads.Add([PSCustomObject]@{
            Name     = "DirectX End-User (Junio 2010)"
            FileName = "DirectX/dxsetup.exe"
            SizeMB   = 95.63
            Status   = "OK"
        })
    } else {
        $dxInstallerPath = Join-Path $DestinationPath "directx_Jun2010_redist.exe"
        $dxUrl = "https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe"

        Write-Host "  [$current/$totalItems] Descargando DirectX End-User Runtimes (96 MB)..." -ForegroundColor Yellow -NoNewline
        Write-LogEntry -Level "INFO" -Message "Iniciando descarga: DirectX End-User Runtimes"
        try {
            Invoke-SafeDownload -Url $dxUrl -DestinationFile $dxInstallerPath -TimeoutSeconds 180
            $dxSizeMB = [math]::Round((Get-Item $dxInstallerPath).Length / 1MB, 2)
            Write-Host " [OK] ($dxSizeMB MB)" -ForegroundColor Green
            Write-LogEntry -Level "OK" -Message "DirectX contenedor descargado ($dxSizeMB MB)."

            Write-Host "    Extrayendo archivos de DirectX en '$directxExtractDir'..." -ForegroundColor Gray -NoNewline
            if (-not (Test-Path $directxExtractDir)) {
                New-Item -ItemType Directory -Path $directxExtractDir -Force | Out-Null
            }

            $extracted = $false

            # Intento 1: Usar 7-Zip si está disponible en PATH o rutas conocidas
            $sevenZipExe = $null
            $candidate7z = @(
                (Get-Command "7z", "7za" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1),
                (Join-Path $env:ProgramFiles "7-Zip\7z.exe"),
                (Join-Path ${env:ProgramFiles(x86)} "7-Zip\7z.exe")
            )
            foreach ($c7 in $candidate7z) {
                if ($c7 -and (Test-Path $c7)) {
                    $sevenZipExe = $c7
                    break
                }
            }

            if ($sevenZipExe) {
                & $sevenZipExe x "$dxInstallerPath" -o"$directxExtractDir" -y *>$null
                if (Test-Path $directxSetupExe) { $extracted = $true }
            }

            # Intento 2: Auto-extracción nativa IExpress de Windows si 7-Zip no está instalado
            if (-not $extracted -and ($env:OS -eq "Windows_NT")) {
                $proc = Start-Process -FilePath $dxInstallerPath -ArgumentList @("/Q", "/T:$directxExtractDir") -Wait -PassThru -NoNewWindow
                if ($proc.ExitCode -eq 0 -and (Test-Path $directxSetupExe)) { $extracted = $true }
            }

            if ($extracted -or (Test-Path $directxSetupExe)) {
                Write-Host " [OK]" -ForegroundColor Green
                Write-LogEntry -Level "OK" -Message "DirectX extraído correctamente en DirectX/."
                # Eliminar el archivo .exe contenedor para ahorrar espacio en la ISO
                Remove-Item -Path $dxInstallerPath -Force -ErrorAction SilentlyContinue
                $script:Downloads.Add([PSCustomObject]@{
                    Name     = "DirectX End-User (Junio 2010)"
                    FileName = "DirectX/dxsetup.exe"
                    SizeMB   = 95.63
                    Status   = "OK"
                })
            } else {
                Write-Host " [AVISO: Extrae $dxInstallerPath manualmente en la carpeta DirectX/]" -ForegroundColor DarkYellow
                Write-LogEntry -Level "WARN" -Message "DirectX descargado pero no se pudo auto-extraer."
            }
        } catch {
            Write-Host " [ERROR: $($_.Exception.Message)]" -ForegroundColor Red
            Write-ForensicException -Record $_ -Context "Descarga/Extraccion DirectX" -SuggestedAction "Compruebe la conectividad o ejecute manualmente $dxInstallerPath"
            Write-LogEntry -Level "ERROR" -Message "DirectX fallo: $($_.Exception.Message)"
            if (Test-Path $dxInstallerPath) { Remove-Item -Path $dxInstallerPath -Force -ErrorAction SilentlyContinue }
            $script:Downloads.Add([PSCustomObject]@{
                Name     = "DirectX End-User (Junio 2010)"
                FileName = "DirectX/dxsetup.exe"
                SizeMB   = 0
                Status   = "ERROR"
            })
        }
    }
}

# Resumen final de archivos y espacio
$allFiles = Get-ChildItem -Path $DestinationPath -Recurse -File
$totalSizeMB = [math]::Round(($allFiles | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
Write-Info "Archivos totales en Runtimes: $($allFiles.Count) | Espacio total: $totalSizeMB MB"
Write-Info "La proxima vez que ejecutes 'New-OptimizedWindowsISO-v2.ps1', se integraran automaticamente."

Write-LogSummary
