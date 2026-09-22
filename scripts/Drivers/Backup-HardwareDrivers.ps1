<#
.SYNOPSIS
    Backup-HardwareDrivers.ps1 - Respaldo Nativo de Controladores del Host para romanOS.

.DESCRIPTION
    Exporta todos los controladores de terceros (oem*.inf) activos en la máquina local
    hacia una carpeta de destino lista para ser inyectada en una imagen ISO de Windows.
    Utiliza de forma primaria el cmdlet oficial Export-WindowsDriver y fallback a pnputil.exe.

    100% compatible con Windows PowerShell 5.1 (powershell.exe) y PowerShell 7+ (pwsh).
    Codificación estricta UTF-8 con BOM.

.PARAMETER DestinationPath
    Ruta donde se guardarán los controladores exportados.
    Por defecto: carpeta 'Drivers' relativa o 'C:\OptimizedISO\scripts\Drivers'.

.PARAMETER IncludeInbox
    Si se especifica, incluye también controladores que vienen por defecto con Windows (inbox).
    Por defecto es $false (solo exporta drivers OEM de terceros).

.PARAMETER Quiet
    Suprime los mensajes informativos en consola para ejecución desatendida.

.EXAMPLE
    .\Backup-HardwareDrivers.ps1 -DestinationPath "C:\OptimizedISO\scripts\Drivers"
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [string]$DestinationPath = "",

    [Parameter()]
    [switch]$IncludeInbox,

    [Parameter()]
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Write-DriverLog {
    param([string]$Message, [string]$Color = "Gray")
    if (-not $Quiet) {
        Write-Host "  $Message" -ForegroundColor $Color
    }
}

# 1. Determinar ruta de destino
if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
    if (Test-Path "C:\OptimizedISO\scripts\Drivers") {
        $DestinationPath = "C:\OptimizedISO\scripts\Drivers"
    } elseif ($PSScriptRoot) {
        $DestinationPath = $PSScriptRoot
    } else {
        $DestinationPath = Join-Path (Get-Location) "Drivers"
    }
}

if (-not (Test-Path $DestinationPath)) {
    if ($PSCmdlet.ShouldProcess($DestinationPath, "Crear directorio de destino para controladores")) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }
}

$DestinationPath = (Resolve-Path $DestinationPath).Path

if (-not $Quiet) {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║        RESPALDO OFICIAL DE CONTROLADORES - romanOS           ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-DriverLog "Destino: $DestinationPath" "White"
}

if ($PSCmdlet.ShouldProcess($DestinationPath, "Exportar controladores de terceros activos")) {
    $exportedCount = 0
    $exportMethod = "Export-WindowsDriver"
    $manifestData = [System.Collections.Generic.List[PSCustomObject]]::new()

    try {
        Write-DriverLog "Iniciando exportación mediante Export-WindowsDriver..." "Cyan"
        
        $drivers = Export-WindowsDriver -Online -Destination $DestinationPath -ErrorAction Stop
        
        if ($drivers) {
            $exportedCount = $drivers.Count
            foreach ($drv in $drivers) {
                $manifestData.Add([PSCustomObject]@{
                    Driver            = $drv.Driver
                    OriginalFileName  = $drv.OriginalFileName
                    ProviderName      = $drv.ProviderName
                    ClassName         = $drv.ClassName
                    Version           = $drv.Version
                    Date              = $drv.Date
                })
            }
        }
    } catch {
        Write-DriverLog "Export-WindowsDriver no disponible o arrojó advertencia: $($_.Exception.Message)" "Yellow"
        Write-DriverLog "Activando fallback oficial nativo con pnputil.exe..." "Cyan"
        $exportMethod = "pnputil.exe /export-driver"

        $pnpArgs = @("/export-driver", "*", "$DestinationPath")
        $pnpProcess = Start-Process -FilePath "pnputil.exe" -ArgumentList $pnpArgs -Wait -NoNewWindow -PassThru

        if ($pnpProcess.ExitCode -eq 0) {
            $infFiles = Get-ChildItem -Path $DestinationPath -Filter "*.inf" -Recurse -File -ErrorAction SilentlyContinue
            $exportedCount = $infFiles.Count
        } else {
            Write-DriverLog "pnputil devolvió código de salida: $($pnpProcess.ExitCode)" "Red"
        }
    }

    # Crear Manifiesto JSON para trazabilidad y auditoría
    if ($exportedCount -gt 0) {
        $manifestPath = Join-Path $DestinationPath "Drivers-Manifest.json"
        try {
            $manifestOutput = [PSCustomObject]@{
                Timestamp       = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                ComputerName    = $env:COMPUTERNAME
                ExportMethod    = $exportMethod
                TotalDrivers    = $exportedCount
                Drivers         = $manifestData
            }
            $manifestOutput | ConvertTo-Json -Depth 4 | Out-File -FilePath $manifestPath -Encoding UTF8 -Force
        } catch {
            Write-DriverLog "No se pudo guardar manifiesto JSON en ($manifestPath) - $($_.Exception.Message)" "Yellow"
        }

        Write-Host ""
        Write-Host "  [OK] Exportación exitosa: $exportedCount controlador(es) exportados en '$DestinationPath'." -ForegroundColor Green
        Write-Host "       Listos para integrarse automáticamente en la ISO." -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "  [!] No se pudieron exportar controladores o no se detectaron controladores OEM de terceros." -ForegroundColor Yellow
    }

    return [PSCustomObject]@{
        Success       = ($exportedCount -gt 0)
        TotalExported = $exportedCount
        Destination   = $DestinationPath
        Method        = $exportMethod
    }
}
