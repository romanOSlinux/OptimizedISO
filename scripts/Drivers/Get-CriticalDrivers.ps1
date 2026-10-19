<#
.SYNOPSIS
    Get-CriticalDrivers.ps1 - Descarga asistida de controladores críticos para romanOS.

.DESCRIPTION
    Descarga y extrae automáticamente los controladores de almacenamiento y virtualización
    más críticos para garantizar detección de discos durante la instalación de Windows:
    1. Intel Rapid Storage Technology (RST) / VMD Driver (Intel 11va-14va Gen).
    2. Red Hat / Fedora VirtIO Storage Drivers (viostor) para entornos virtuales (KVM/Proxmox).

    100% compatible con Windows PowerShell 5.1 (powershell.exe) y PowerShell 7+ (pwsh).
    Codificación estricta UTF-8 con BOM.

.PARAMETER Package
    Paquete a descargar: 'All', 'IntelVMD', 'VirtIO'. (Por defecto: 'All').

.PARAMETER DestinationPath
    Ruta de destino. Por defecto se descargan y extraen en 'scripts\Drivers\Storage\'.

.EXAMPLE
    .\Get-CriticalDrivers.ps1 -Package All
    .\Get-CriticalDrivers.ps1 -Package IntelVMD
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("All", "IntelVMD", "VirtIO")]
    [string]$Package = "All",

    [Parameter()]
    [string]$DestinationPath = "",

    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'

# Forzar TLS 1.2 para conexiones HTTPS seguras
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║       DESCARGA DE CONTROLADORES CRÍTICOS - romanOS           ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Determinar ruta base
if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
    if ($PSScriptRoot -and (Test-Path $PSScriptRoot)) {
        $DestinationPath = $PSScriptRoot
    } else {
        $DestinationPath = Join-Path (Get-Location) "Drivers"
    }
}

$DestinationPath = [System.IO.Path]::GetFullPath($DestinationPath)
$storageDir = Join-Path $DestinationPath "Storage"
if (-not (Test-Path $storageDir)) {
    if ($PSCmdlet.ShouldProcess($storageDir, "Crear directorio de almacenamiento de controladores")) {
        New-Item -ItemType Directory -Path $storageDir -Force | Out-Null
    }
}

$catalog = @(
    @{
        Id          = "IntelVMD"
        Name        = "Intel RST VMD Floppy Driver (v19.5 / v20.0 Gen 11-14)"
        TargetDir   = (Join-Path $storageDir "Intel-VMD")
        # URL oficial del paquete de controladores de almacenamiento masivo Intel RST F6 Floppy
        DownloadUrl = "https://downloadmirror.intel.com/784365/f6vmdflpy-x64.zip"
        ZipName     = "f6vmdflpy-x64.zip"
        TestInf     = "iaStorVD.inf"
    },
    @{
        Id          = "VirtIO"
        Name        = "Red Hat VirtIO SCSI Storage Driver (KVM / Proxmox / QEMU)"
        TargetDir   = (Join-Path $storageDir "VirtIO-Storage")
        # URL oficial del repositorio upstream de Fedora VirtIO (paquete de drivers de almacenamiento viostor)
        DownloadUrl = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso"
        ZipName     = "virtio-win.iso"
        TestInf     = "viostor.inf"
    }
)

$packagesToProcess = if ($Package -eq "All") {
    $catalog
} else {
    @($catalog | Where-Object { $_.Id -eq $Package })
}

foreach ($pkg in $packagesToProcess) {
    Write-Host "  [+] Procesando: $($pkg.Name)" -ForegroundColor Cyan

    if (-not (Test-Path $pkg.TargetDir)) {
        New-Item -ItemType Directory -Path $pkg.TargetDir -Force | Out-Null
    }

    $existingInfs = @(Get-ChildItem -Path $pkg.TargetDir -Filter "*.inf" -Recurse -File -ErrorAction SilentlyContinue)
    if ($existingInfs.Count -gt 0) {
        Write-Host "      Controladores ya presentes en: $($pkg.TargetDir) ($($existingInfs.Count) .inf)" -ForegroundColor Green
        continue
    }

    if ($PSCmdlet.ShouldProcess($pkg.Name, "Descargar y descomprimir controladores")) {
        $tempFile = Join-Path $env:TEMP $pkg.ZipName
        try {
            Write-Host "      Descargando desde: $($pkg.DownloadUrl)..." -ForegroundColor Gray
            
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "romanOS-Driver-Downloader/1.0")
            $wc.DownloadFile($pkg.DownloadUrl, $tempFile)

            Write-Host "      Descarga completada. Extrayendo archivos..." -ForegroundColor Gray

            if ($pkg.ZipName.EndsWith(".zip")) {
                Expand-Archive -Path $tempFile -DestinationPath $pkg.TargetDir -Force
            } elseif ($pkg.ZipName.EndsWith(".iso")) {
                # Para ISO virtio, extraer mediante montaje temporal con PowerShell
                try {
                    $mountResult = Mount-DiskImage -ImagePath $tempFile -StorageType ISO -PassThru -ErrorAction Stop
                    $driveLetter = ($mountResult | Get-Volume).DriveLetter
                    if ($driveLetter) {
                        $viostorSrc = "$($driveLetter):\viostor\w11\amd64"
                        $netkvmSrc  = "$($driveLetter):\NetKVM\w11\amd64"
                        if (Test-Path $viostorSrc) {
                            Copy-Item -Path "$viostorSrc\*" -Destination $pkg.TargetDir -Recurse -Force
                        }
                        if (Test-Path $netkvmSrc) {
                            $netDir = Join-Path $DestinationPath "Network\VirtIO-Net"
                            if (-not (Test-Path $netDir)) { New-Item -ItemType Directory -Path $netDir -Force | Out-Null }
                            Copy-Item -Path "$netkvmSrc\*" -Destination $netDir -Recurse -Force
                        }
                    }
                } catch {
                    Write-Host "      No se pudo montar la ISO de VirtIO para extracción directa: $($_.Exception.Message)" -ForegroundColor Yellow
                } finally {
                    Dismount-DiskImage -ImagePath $tempFile -ErrorAction SilentlyContinue | Out-Null
                }
            }

            $extractedInfs = @(Get-ChildItem -Path $pkg.TargetDir -Filter "*.inf" -Recurse -File -ErrorAction SilentlyContinue)
            Write-Host "      [OK] Extraídos $($extractedInfs.Count) archivo(s) .inf en: $($pkg.TargetDir)" -ForegroundColor Green
        } catch {
            Write-Host "      [!] Error descargando $($pkg.Name): $($_.Exception.Message)" -ForegroundColor Yellow
        } finally {
            if (Test-Path $tempFile) {
                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Write-Host ""
Write-Host "  Operación de controladores finalizada. Carpeta lista: $storageDir" -ForegroundColor Cyan
Write-Host ""

if ($PassThru) {
    return $packagesToProcess
}
