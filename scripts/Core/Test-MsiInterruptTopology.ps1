<#
.SYNOPSIS
    Test-MsiInterruptTopology.ps1 - Auditor Forense de Topología de Interrupciones PCIe (MSI vs Line-Based)
    romanOS / OptimizedISO — Estado del Arte Windows 11 24H2 / 25H2

.DESCRIPTION
    Inspecciona exhaustivamente el subsistema de interrupciones de hardware de todos los dispositivos
    PCIe del sistema (GPU, almacenamiento NVMe, adaptadores de red, controladores USB y audio HD).
    Determina si cada dispositivo opera en modo Message Signaled Interrupts (MSI/MSI-X) o en el modo
    legado compartido (Line-Based IRQ).
    Detecta el fenómeno de saturación del Core 0 (CPU 0 Bottleneck) y evalúa la prioridad de interrupción.

.PARAMETER ExportJson
    Ruta opcional para guardar el informe estructurado en formato JSON.

.EXAMPLE
    .\Test-MsiInterruptTopology.ps1

.EXAMPLE
    .\Test-MsiInterruptTopology.ps1 -ExportJson "C:\OptimizedISO\Log\MsiTopology.json"
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ExportJson
)

$ErrorActionPreference = 'Continue'
$auditStartTime = Get-Date

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS / OptimizedISO — AUDITORIA DE TOPOLOGIA DE INTERRUPCIONES PCIe  " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
Write-Host ""

# -----------------------------------------------------------------------------
# 1. ENUMERACIÓN DE DISPOSITIVOS PCI
# -----------------------------------------------------------------------------
Write-Host ">>> Escaneando bus PCI y sub-claves de gestión de interrupciones..." -ForegroundColor Cyan

$pciRootPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI"
if (-not (Test-Path $pciRootPath)) {
    Write-Error "No se pudo acceder a la colmena de hardware PCI en '$pciRootPath'."
    return
}

# Obtener catálogo de dispositivos PnP para enriquecer con nombres legibles
$pnpMap = @{}
try {
    $pnpEntities = Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object { $_.DeviceID -like "PCI\*" }
    foreach ($ent in $pnpEntities) {
        $pnpMap[$ent.DeviceID] = $ent
    }
    Write-Host "  [OK] $($pnpMap.Count) entidades PCI detectadas en el subsistema PnP." -ForegroundColor Green
} catch {
    Write-Warning "No se pudo consultar Win32_PnPEntity ($($_.Exception.Message)). Se utilizarán datos del registro."
}

# -----------------------------------------------------------------------------
# 2. INSPECCIÓN DE CLAVES DE INTERRUPT MANAGEMENT
# -----------------------------------------------------------------------------
$auditResults = [System.Collections.Generic.List[PSCustomObject]]::new()
$pciDevices = Get-ChildItem -Path $pciRootPath -ErrorAction Stop

$totalPciDevices = 0
$msiEnabledCount = 0
$lineBasedCount = 0
$criticalMsiCount = 0
$criticalTotalCount = 0

foreach ($venKey in $pciDevices) {
    $instances = Get-ChildItem -Path $venKey.PSPath -ErrorAction SilentlyContinue
    foreach ($inst in $instances) {
        $totalPciDevices++
        $devId = "PCI\" + $venKey.PSChildName + "\" + $inst.PSChildName
        
        # Consultar metadatos del dispositivo
        $instProps = Get-ItemProperty -Path $inst.PSPath -ErrorAction SilentlyContinue
        $rawDesc = $instProps.DeviceDesc
        $friendlyName = $instProps.FriendlyName
        $devClass = $instProps.Class
        $service = $instProps.Service
        $location = $instProps.LocationInformation

        # Limpiar nombre legible
        $cleanName = ""
        if ($friendlyName) {
            $cleanName = $friendlyName
        } elseif ($rawDesc -match ';(.*)$') {
            $cleanName = $Matches[1]
        } elseif ($rawDesc) {
            $cleanName = $rawDesc
        } elseif ($pnpMap.ContainsKey($devId)) {
            $cleanName = $pnpMap[$devId].Name
        } else {
            $cleanName = $venKey.PSChildName
        }

        # Clasificación por categoría de hardware
        $category = "Chipset / Puente PCI"
        $isCritical = $false

        if ($devClass -eq "Display" -or $cleanName -match "(Radeon|GeForce|RTX|GTX|Intel Arc|Graphics|VGA)") {
            $category = "GPU / Display"
            $isCritical = $true
        } elseif ($devClass -eq "SCSIAdapter" -or $devClass -eq "DiskDrive" -or $cleanName -match "(NVM Express|NVMe|AHCI|SATA Controller)") {
            $category = "Almacenamiento (NVMe/SATA)"
            $isCritical = $true
        } elseif ($devClass -eq "Net" -or $cleanName -match "(Ethernet|Wi-Fi|Wireless|Gigabit|Network Connection)") {
            $category = "Adaptador de Red (NIC)"
            $isCritical = $true
        } elseif ($devClass -eq "USB" -or $cleanName -match "(xHCI|Host Controller|USB 3)") {
            $category = "Controlador USB (xHCI)"
            $isCritical = $true
        } elseif ($devClass -eq "MEDIA" -or $cleanName -match "(High Definition Audio|Realtek|Sound)") {
            $category = "Audio / Multimedia"
            $isCritical = $true
        }

        if ($isCritical) {
            $criticalTotalCount++
        }

        # Inspección de MessageSignaledInterruptProperties
        $msiKeyPath = Join-Path $inst.PSPath "Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        $affinityKeyPath = Join-Path $inst.PSPath "Device Parameters\Interrupt Management\Affinity Policy"

        $isMsiSupported = $false
        $msiVal = $null
        $msgLimit = $null

        if (Test-Path $msiKeyPath) {
            try {
                $msiProps = Get-ItemProperty -Path $msiKeyPath -ErrorAction Stop
                $msiVal = $msiProps.MSISupported
                $msgLimit = $msiProps.MessageNumberLimit
                if ($msiVal -eq 1) {
                    $isMsiSupported = $true
                    $msiEnabledCount++
                    if ($isCritical) {
                        $criticalMsiCount++
                    }
                } else {
                    $lineBasedCount++
                }
            } catch {
                $lineBasedCount++
            }
        } else {
            # No tiene subclave MSI: funciona en modo compartido Line-Based por omisión
            $lineBasedCount++
        }

        # Inspección de Affinity Policy / Prioridad
        $devicePriority = "Normal (Default)"
        $devicePolicy = "Default"
        if (Test-Path $affinityKeyPath) {
            try {
                $affProps = Get-ItemProperty -Path $affinityKeyPath -ErrorAction Stop
                if ($affProps.DevicePriority) {
                    $prioVal = $affProps.DevicePriority
                    $devicePriority = switch ($prioVal) {
                        3 { "High" }
                        2 { "Normal" }
                        1 { "Low" }
                        default { "Custom ($prioVal)" }
                    }
                }
                if ($affProps.DevicePolicy) {
                    $devicePolicy = switch ($affProps.DevicePolicy) {
                        0 { "IrqPolicyMachineDefault" }
                        1 { "IrqPolicyAllCloseProcessors" }
                        2 { "IrqPolicyOneCloseProcessor" }
                        3 { "IrqPolicyAllProcessorsInMachine" }
                        4 { "IrqPolicySpecifiedProcessors" }
                        5 { "IrqPolicySpreadMessagesAcrossAllProcessors" }
                        default { "Policy-$($affProps.DevicePolicy)" }
                    }
                }
            } catch {
                Write-Debug "Afinidad de interrupción no disponible para $cleanName : $($_.Exception.Message)"
            }
        }

        $auditResults.Add([PSCustomObject]@{
            DeviceID          = $devId
            DeviceName        = $cleanName
            Category          = $category
            IsCritical        = $isCritical
            MsiMode           = if ($isMsiSupported) { "MSI / MSI-X (Activo)" } else { "Line-Based IRQ (Compartido)" }
            MSISupported      = $isMsiSupported
            MessageLimit      = if ($msgLimit) { $msgLimit } else { "N/A" }
            DevicePriority    = $devicePriority
            DevicePolicy      = $devicePolicy
            Service           = if ($service) { $service } else { "N/A" }
            Location          = if ($location) { $location } else { "N/A" }
        })
    }
}

# -----------------------------------------------------------------------------
# 3. ANÁLISIS DE IMPACTO EN LATENCIA Y CUELLOS DE BOTELLA
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN FORENSE DE DISPOSITIVOS CRITICOS PARA GAMING " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

$criticalDevices = @($auditResults | Where-Object { $_.IsCritical })

foreach ($cdev in $criticalDevices) {
    $statusColor = if ($cdev.MSISupported) { "Green" } else { "Yellow" }
    $badge = if ($cdev.MSISupported) { "[MSI OK]" } else { "[LINE IRQ]" }
    Write-Host "  $badge $($cdev.Category): $($cdev.DeviceName)" -ForegroundColor $statusColor
    Write-Host "     Modo: $($cdev.MsiMode) | Prioridad: $($cdev.DevicePriority) | Servicio: $($cdev.Service)" -ForegroundColor DarkGray
}

$msiOverallPercentage = if ($totalPciDevices -gt 0) { [math]::Round(($msiEnabledCount / $totalPciDevices) * 100, 1) } else { 0 }
$criticalMsiPercentage = if ($criticalTotalCount -gt 0) { [math]::Round(($criticalMsiCount / $criticalTotalCount) * 100, 1) } else { 0 }

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " METRICAS DE SALUD DE INTERRUPCIONES PCIe " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Dispositivos PCI Totales Escaneados   : $totalPciDevices" -ForegroundColor White
Write-Host " Dispositivos en Modo MSI / MSI-X     : $msiEnabledCount ($msiOverallPercentage%)" -ForegroundColor Green
Write-Host " Dispositivos en Line-Based IRQ        : $lineBasedCount" -ForegroundColor DarkGray
Write-Host " Dispositivos Críticos en Modo MSI    : $criticalMsiCount / $criticalTotalCount ($criticalMsiPercentage%)" -ForegroundColor $(if ($criticalMsiPercentage -ge 75) { 'Green' } else { 'Yellow' })

$bottleneckRisk = if ($criticalMsiPercentage -ge 80) { "BAJO (Óptimo para eSports)" } elseif ($criticalMsiPercentage -ge 50) { "MODERADO" } else { "ALTO (Saturación de CPU 0)" }
Write-Host " Riesgo de Cuello de Botella en CPU 0  : $bottleneckRisk" -ForegroundColor $(if ($criticalMsiPercentage -ge 80) { 'Green' } else { 'Yellow' })

if ($ExportJson) {
    try {
        $jsonDir = Split-Path $ExportJson -Parent
        if ($jsonDir -and -not (Test-Path $jsonDir)) {
            New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null
        }
        $auditResults | ConvertTo-Json -Depth 4 | Set-Content -Path $ExportJson -Encoding UTF8
        Write-Host " Reporte exportado a JSON: $ExportJson" -ForegroundColor DarkGray
    } catch {
        Write-Warning "No se pudo exportar JSON a '$ExportJson': $($_.Exception.Message)"
    }
}

Write-Host " Duración del Análisis: $([math]::Round(((Get-Date) - $auditStartTime).TotalSeconds, 2))s" -ForegroundColor DarkGray
Write-Host ""

return [PSCustomObject]@{
    TotalPciDevices       = $totalPciDevices
    MsiEnabledCount       = $msiEnabledCount
    LineBasedCount        = $lineBasedCount
    CriticalTotalCount    = $criticalTotalCount
    CriticalMsiCount      = $criticalMsiCount
    CriticalMsiPercentage = $criticalMsiPercentage
    BottleneckRisk        = $bottleneckRisk
    DevicesReport         = $auditResults
}
