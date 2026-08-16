<#
.SYNOPSIS
    Descarga y organiza los Runtimes esenciales oficiales de Microsoft para su integración en la ISO.

.DESCRIPTION
    Este script descarga directamente desde los servidores oficiales de Microsoft (CDN):
      - Microsoft Visual C++ 2015-2022 Redistributable (x64 y x86)
      - Microsoft Visual C++ 2013 Redistributable (x64 y x86)
      - Microsoft Visual C++ 2012 Redistributable (x64 y x86)
      - Microsoft DirectX End-User Runtimes (Junio 2010) y lo extrae en la carpeta DirectX/
    
    Los archivos se guardan en la carpeta 'Runtimes' para que 'New-OptimizedWindowsISO.ps1'
    los empaquete automáticamente dentro de la ISO de Windows.

.PARAMETER DestinationPath
    Ruta de destino donde se guardarán los instaladores. Por defecto: scripts/Runtimes.

.PARAMETER Force
    Fuerza la sobreescritura de archivos si ya existen.

.EXAMPLE
    .\Get-EssentialRuntimes.ps1
    .\Get-EssentialRuntimes.ps1 -DestinationPath "D:\OptimizedISO\scripts\Runtimes" -Force
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$DestinationPath = "",

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Habilitar TLS 1.2 y TLS 1.3 para descargas seguras
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# Resolver carpeta de destino
if (-not $DestinationPath) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $DestinationPath = Join-Path $scriptDir "Runtimes"
}

if (-not (Test-Path $DestinationPath)) {
    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
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
        Write-LogEntry -Level "ERROR" -Message "--- ERRORES DETECTADOS ---"
        foreach ($e in $script:LogErrors) { Write-LogEntry -Level "ERROR" -Message $e }
    }
    if ($script:LogErrors.Count -eq 0) {
        Write-LogEntry -Level "OK" -Message "Descarga de runtimes completada con éxito."
    }
    Write-LogEntry -Level "INIT" -Message "Log estructurado    : $script:LogFile"
    Write-LogEntry -Level "INIT" -Message "AI Summary (MD)     : $script:AiSummaryFile"
    Write-LogEntry -Level "INIT" -Message "Transcript          : $script:TranscriptFile"
    Write-LogEntry -Level "INIT" -Message ("=" * 64)

    try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch {}

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
    } catch {}

    Write-Host ""
    Write-Host "  ┌─ Logs generados (Listos para análisis por IA) ────────────────" -ForegroundColor DarkCyan
    if ($script:AiSummaryFile)  { Write-Host "  │  AI Diagnostic MD : $script:AiSummaryFile  <-- Pásame este archivo" -ForegroundColor Green }
    Write-Host "  │  Log estructurado : $script:LogFile" -ForegroundColor Cyan
    Write-Host "  │  Transcript       : $script:TranscriptFile" -ForegroundColor Cyan
    if ($script:LogErrors.Count -gt 0) {
        Write-Host "  │" -ForegroundColor DarkCyan
        Write-Host "  │  [$($script:LogErrors.Count) ERROR(S) detectados — revisa el reporte]" -ForegroundColor Red
    } else {
        Write-Host "  │  Descargas completadas sin errores." -ForegroundColor Green
    }
    Write-Host "  └───────────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
}

try {
    Start-Transcript -Path $script:TranscriptFile -Append -ErrorAction Stop | Out-Null
} catch {}

Write-LogEntry -Level "INIT" -Message ("=" * 64)
Write-LogEntry -Level "INIT" -Message "Get-EssentialRuntimes Download Log"
Write-LogEntry -Level "INIT" -Message "PowerShell $($PSVersionTable.PSVersion) | Host: $env:COMPUTERNAME"
Write-LogEntry -Level "INIT" -Message ("=" * 64)

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        DESCARGADOR DE RUNTIMES ESENCIALES PARA WINDOWS ISO           ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "  Destino: $DestinationPath" -ForegroundColor Gray
Write-Host ""

# Lista oficial de descargas de Microsoft CDN
$runtimes = @(
    @{
        Name     = "Visual C++ 2015-2022 (x64)"
        FileName = "vc_redist.x64.exe"
        Url      = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    },
    @{
        Name     = "Visual C++ 2015-2022 (x86)"
        FileName = "vc_redist.x86.exe"
        Url      = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
    },
    @{
        Name     = "Visual C++ 2013 (x64)"
        FileName = "vcredist_2013_x64.exe"
        Url      = "https://download.microsoft.com/download/2/E/6/2E61C7AB-2E19-482F-B0F0-087940B04246/vcredist_x64.exe"
    },
    @{
        Name     = "Visual C++ 2013 (x86)"
        FileName = "vcredist_2013_x86.exe"
        Url      = "https://download.microsoft.com/download/2/E/6/2E61C7AB-2E19-482F-B0F0-087940B04246/vcredist_x86.exe"
    },
    @{
        Name     = "Visual C++ 2012 (x64)"
        FileName = "vcredist_2012_x64.exe"
        Url      = "https://download.microsoft.com/download/1/6/B/16B06F60-3CA2-4533-82F9-F016B074FAA4/vcredist_x64.exe"
    },
    @{
        Name     = "Visual C++ 2012 (x86)"
        FileName = "vcredist_2012_x86.exe"
        Url      = "https://download.microsoft.com/download/1/6/B/16B06F60-3CA2-4533-82F9-F016B074FAA4/vcredist_x86.exe"
    }
)

$webClient = New-Object System.Net.WebClient

# 1. Descarga de Visual C++ Redistributables
$totalItems = $runtimes.Count + 1
$current = 0

foreach ($item in $runtimes) {
    $current++
    $targetFile = Join-Path $DestinationPath $item.FileName

    if ((Test-Path $targetFile) -and (-not $Force)) {
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
        $webClient.DownloadFile($item.Url, $targetFile)
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
        $script:Downloads.Add([PSCustomObject]@{
            Name     = $item.Name
            FileName = $item.FileName
            SizeMB   = 0
            Status   = "ERROR"
        })
    }
}

# 2. Descarga y extracción de DirectX End-User Runtimes (Junio 2010)
$current++
$directxExtractDir = Join-Path $DestinationPath "DirectX"
$directxSetupExe = Join-Path $directxExtractDir "dxsetup.exe"

if ((Test-Path $directxSetupExe) -and (-not $Force)) {
    Write-Host "  [$current/$totalItems] DirectX End-User (Junio 2010): Ya extraído en DirectX/. Omitiendo." -ForegroundColor DarkGreen
    Write-LogEntry -Level "INFO" -Message "DirectX End-User: ya extraído en DirectX/."
    $script:Downloads.Add([PSCustomObject]@{
        Name     = "DirectX End-User (Junio 2010)"
        FileName = "DirectX/dxsetup.exe"
        SizeMB   = 96.0
        Status   = "OK"
    })
} else {
    $dxInstallerPath = Join-Path $DestinationPath "directx_Jun2010_redist.exe"
    $dxUrl = "https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe"

    Write-Host "  [$current/$totalItems] Descargando DirectX End-User Runtimes (96 MB)..." -ForegroundColor Yellow -NoNewline
    Write-LogEntry -Level "INFO" -Message "Iniciando descarga: DirectX End-User Runtimes"
    try {
        $webClient.DownloadFile($dxUrl, $dxInstallerPath)
        $dxSizeMB = [math]::Round((Get-Item $dxInstallerPath).Length / 1MB, 2)
        Write-Host " [OK] ($dxSizeMB MB)" -ForegroundColor Green
        Write-LogEntry -Level "OK" -Message "DirectX contenedor descargado ($dxSizeMB MB)."

        Write-Host "    Extrayendo archivos de DirectX en '$directxExtractDir'..." -ForegroundColor Gray -NoNewline
        if (-not (Test-Path $directxExtractDir)) {
            New-Item -ItemType Directory -Path $directxExtractDir -Force | Out-Null
        }

        $extracted = $false

        # Intento 1: Si estamos en Windows, el propio instalador puede auto-extraerse
        if ($env:OS -eq "Windows_NT") {
            $proc = Start-Process -FilePath $dxInstallerPath -ArgumentList @("/Q", "/T:$directxExtractDir") -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -eq 0) { $extracted = $true }
        }

        # Intento 2: Usar 7-Zip si está disponible (Windows o Linux)
        if (-not $extracted) {
            $sevenZip = Get-Command "7z" -ErrorAction SilentlyContinue
            if ($sevenZip) {
                & 7z x "$dxInstallerPath" -o"$directxExtractDir" -y *>$null
                if (Test-Path $directxSetupExe) { $extracted = $true }
            }
        }

        if ($extracted -or (Test-Path $directxSetupExe)) {
            Write-Host " [OK]" -ForegroundColor Green
            Write-LogEntry -Level "OK" -Message "DirectX extraído correctamente en DirectX/."
            # Eliminar el archivo .exe contenedor para ahorrar espacio en la ISO
            Remove-Item -Path $dxInstallerPath -Force -ErrorAction SilentlyContinue
            $script:Downloads.Add([PSCustomObject]@{
                Name     = "DirectX End-User (Junio 2010)"
                FileName = "DirectX/dxsetup.exe"
                SizeMB   = 96.0
                Status   = "OK"
            })
        } else {
            Write-Host " [AVISO: Extrae $dxInstallerPath manualmente en la carpeta DirectX/]" -ForegroundColor DarkYellow
            Write-LogEntry -Level "WARN" -Message "DirectX descargado pero no se pudo auto-extraer."
        }
    } catch {
        Write-Host " [ERROR: $($_.Exception.Message)]" -ForegroundColor Red
        Write-LogEntry -Level "ERROR" -Message "DirectX fallo: $($_.Exception.Message)"
        $script:Downloads.Add([PSCustomObject]@{
            Name     = "DirectX End-User (Junio 2010)"
            FileName = "DirectX/dxsetup.exe"
            SizeMB   = 0
            Status   = "ERROR"
        })
    }
}

# Resumen final
Write-Host ""
Write-Host "══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
$allFiles = Get-ChildItem -Path $DestinationPath -Recurse -File
$totalSizeMB = [math]::Round(($allFiles | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
Write-Host "  Descargas finalizadas con éxito." -ForegroundColor Green
Write-Host "  Archivos totales en Runtimes: $($allFiles.Count)" -ForegroundColor Gray
Write-Host "  Espacio total en disco:       $totalSizeMB MB" -ForegroundColor Gray
Write-Host "══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  La próxima vez que ejecutes 'New-OptimizedWindowsISO.ps1', estos" -ForegroundColor White
Write-Host "  runtimes se inyectarán automáticamente dentro de la ISO." -ForegroundColor White
Write-Host ""

Write-LogSummary
