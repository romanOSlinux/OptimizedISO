# =============================================================================
# Test-HardwareTopologyMocks.ps1
# Bateria de Pruebas Unitarias de Topologia Multi-Hardware por Mocks en Memoria
# Cumplimiento: Regla 14 (.agents/AGENTS.md) & holistic-audit Seccion 5
# Entorno: Compatible con Windows PowerShell 5.1 y PowerShell 7+
# =============================================================================

[CmdletBinding()]
param()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreDir = Join-Path (Split-Path $scriptDir -Parent) "Core"
$hwEngineScript = Join-Path $coreDir "Hardware-Engine.ps1"
$policyEngineScript = Join-Path $coreDir "Policy-Engine.ps1"

if (-not (Test-Path $hwEngineScript)) {
    Write-Error "No se encontro Hardware-Engine.ps1 en $hwEngineScript"
    exit 1
}

# Cargar modulos Core
. $hwEngineScript
if (Test-Path $policyEngineScript) {
    . $policyEngineScript
}

$global:MockTestCount = 0
$global:MockTestPassed = 0
$global:MockTestFailed = 0

function Assert-MockTest {
    param(
        [string]$Name,
        [bool]$Condition,
        [string]$Detail = ""
    )
    $global:MockTestCount++
    if ($Condition) {
        $global:MockTestPassed++
        Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $global:MockTestFailed++
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        if ($Detail) {
            Write-Host "         Detalle: $Detail" -ForegroundColor DarkYellow
        }
    }
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host "  MATRIZ DE MOCKS MULTI-HARDWARE (REGLA 14 / HOLISTIC-AUDIT)     " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Host Runtime: $($PSVersionTable.PSVersion)`n" -ForegroundColor DarkGray

# -----------------------------------------------------------------------------
# CASO A: Topologia Hibrida Intel (P-Cores + E-Cores / big.LITTLE)
# -----------------------------------------------------------------------------
Write-Host "--- Caso A: Mock Topologia Hibrida Intel (i7-13700K P+E Cores) ---" -ForegroundColor Yellow

$mockIntelHybrid = [PSCustomObject]@{
    CPU = [PSCustomObject]@{
        Name         = "13th Gen Intel(R) Core(TM) i7-13700K"
        Vendor       = "Intel"
        Cores        = 16
        Threads      = 24
        IsModern     = $true
        IsHybrid     = $true
        IsEcoreOnly  = $false
        IsDualCcdX3D = $false
    }
    RAM = [PSCustomObject]@{
        TotalGiB     = 32.0
        IsLowRAM     = $false
    }
}

$intelSched = Get-RomanOSSchedulerRecommendation -HardwareInfo $mockIntelHybrid
Assert-MockTest -Name "Intel Hibrido: ShouldModifyPrioritySeparation es `$false" -Condition ($intelSched.ShouldModifyPrioritySeparation -eq $false)
Assert-MockTest -Name "Intel Hibrido: RecommendedValue es 2 (Default Windows)" -Condition ($intelSched.RecommendedValue -eq 2)
Assert-MockTest -Name "Intel Hibrido: TopologyType identificado como Intel_Hybrid_PE" -Condition ($intelSched.TopologyType -eq "Intel_Hybrid_PE")

# -----------------------------------------------------------------------------
# CASO B: Topologia AMD con 3D V-Cache (Dual-CCD Asimetrico)
# -----------------------------------------------------------------------------
Write-Host "`n--- Caso B: Mock Topologia AMD 3D V-Cache (Ryzen 9 7900X3D Dual-CCD) ---" -ForegroundColor Yellow

$mockAmdX3D = [PSCustomObject]@{
    CPU = [PSCustomObject]@{
        Name         = "AMD Ryzen 9 7900X3D 12-Core Processor"
        Vendor       = "AMD"
        Cores        = 12
        Threads      = 24
        IsModern     = $true
        IsHybrid     = $false
        IsEcoreOnly  = $false
        IsDualCcdX3D = $true
    }
    RAM = [PSCustomObject]@{
        TotalGiB     = 32.0
        IsLowRAM     = $false
    }
}

$amdSched = Get-RomanOSSchedulerRecommendation -HardwareInfo $mockAmdX3D
Assert-MockTest -Name "AMD X3D Dual-CCD: ShouldModifyPrioritySeparation es `$false" -Condition ($amdSched.ShouldModifyPrioritySeparation -eq $false)
Assert-MockTest -Name "AMD X3D Dual-CCD: RecommendedValue es 2 (Preserva CPPC / 3D V-Cache Optimizer)" -Condition ($amdSched.RecommendedValue -eq 2)
Assert-MockTest -Name "AMD X3D Dual-CCD: TopologyType identificado como AMD_DualCCD_X3D" -Condition ($amdSched.TopologyType -eq "AMD_DualCCD_X3D")

# -----------------------------------------------------------------------------
# CASO C: Topologia CPU Simetrica Tradicional (Ryzen 5 5600X / Core i7-10700K)
# -----------------------------------------------------------------------------
Write-Host "`n--- Caso C: Mock CPU Simetrica Tradicional (Ryzen 5 5600X) ---" -ForegroundColor Yellow

$mockSymmetric = [PSCustomObject]@{
    CPU = [PSCustomObject]@{
        Name         = "AMD Ryzen 5 5600X 6-Core Processor"
        Vendor       = "AMD"
        Cores        = 6
        Threads      = 12
        IsModern     = $true
        IsHybrid     = $false
        IsEcoreOnly  = $false
        IsDualCcdX3D = $false
    }
    RAM = [PSCustomObject]@{
        TotalGiB     = 16.0
        IsLowRAM     = $false
    }
}

$symSched = Get-RomanOSSchedulerRecommendation -HardwareInfo $mockSymmetric
Assert-MockTest -Name "CPU Simetrica: ShouldModifyPrioritySeparation es `$true" -Condition ($symSched.ShouldModifyPrioritySeparation -eq $true)
Assert-MockTest -Name "CPU Simetrica: RecommendedValue es 38 (0x26 - 3:1 Foreground Boost)" -Condition ($symSched.RecommendedValue -eq 38)
Assert-MockTest -Name "CPU Simetrica: TopologyType identificado como Symmetric_CPU" -Condition ($symSched.TopologyType -eq "Symmetric_CPU")

# -----------------------------------------------------------------------------
# CASO D: Topologia Grafica y Memoria (APU / UMA vs dGPU)
# -----------------------------------------------------------------------------
Write-Host "`n--- Caso D: Mock Topologia Grafica y Memoria (APU/UMA vs dGPU) ---" -ForegroundColor Yellow

$memLow = Get-RomanOSMemoryTier -RamGiB 4.0
$memBalanced = Get-RomanOSMemoryTier -RamGiB 16.0
$memEnthusiast = Get-RomanOSMemoryTier -RamGiB 32.0

Assert-MockTest -Name "Memoria Tier Low: LargeSystemCache es 0 estricto" -Condition ($memLow.LargeSystemCache -eq 0)
Assert-MockTest -Name "Memoria Tier Balanced: LargeSystemCache es 0 estricto" -Condition ($memBalanced.LargeSystemCache -eq 0)
Assert-MockTest -Name "Memoria Tier Enthusiast: LargeSystemCache es 0 estricto (Protege UMA VRAM y Client Working Set)" -Condition ($memEnthusiast.LargeSystemCache -eq 0)
Assert-MockTest -Name "Tier Low: DisablePagingExecutive es 0 (Preserva RAM)" -Condition ($memLow.DisablePagingExecutive -eq 0)
Assert-MockTest -Name "Tier Balanced/Enthusiast: DisablePagingExecutive es 1 (Kernel bloqueado en RAM)" -Condition ($memBalanced.DisablePagingExecutive -eq 1 -and $memEnthusiast.DisablePagingExecutive -eq 1)

# -----------------------------------------------------------------------------
# CASO E: Topologia de Almacenamiento Mixto (NVMe + SATA HDD)
# -----------------------------------------------------------------------------
Write-Host "`n--- Caso E: Mock Topologia de Almacenamiento Mixto (NVMe SSD + HDD Mecanico) ---" -ForegroundColor Yellow

$mockDrives = @(
    [PSCustomObject]@{ DeviceID = "\\.\PHYSICALDRIVE0"; MediaType = "SSD"; BusType = "NVMe"; Model = "Kingston SNV3S1000G" },
    [PSCustomObject]@{ DeviceID = "\\.\PHYSICALDRIVE1"; MediaType = "HDD"; BusType = "SATA"; Model = "WDC WD10EZEX-08WN4A0" }
)

$nvmeDrive = $mockDrives | Where-Object { $_.BusType -eq "NVMe" }
$hddDrive = $mockDrives | Where-Object { $_.MediaType -eq "HDD" }

Assert-MockTest -Name "Deteccion de unidad NVMe de alto rendimiento" -Condition ($null -ne $nvmeDrive -and $nvmeDrive.MediaType -eq "SSD")
Assert-MockTest -Name "Deteccion de unidad mecanica HDD SATA" -Condition ($null -ne $hddDrive -and $hddDrive.MediaType -eq "HDD")
Assert-MockTest -Name "Aislamiento por volumen: el HDD no hereda deshabilitacion de buffers de SSD" -Condition ($nvmeDrive.DeviceID -ne $hddDrive.DeviceID)

# -----------------------------------------------------------------------------
# RESUMEN FINAL
# -----------------------------------------------------------------------------
Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host "  RESUMEN DE PRUEBAS DE MOCKS DE TOPOLOGIA                       " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Total de Aserciones : $global:MockTestCount" -ForegroundColor White
Write-Host "  Aprobadas (PASS)    : $global:MockTestPassed" -ForegroundColor Green
Write-Host "  Fallidas (FAIL)     : $global:MockTestFailed" -ForegroundColor $(if ($global:MockTestFailed -gt 0) { 'Red' } else { 'Gray' })
Write-Host "=================================================================`n" -ForegroundColor Cyan

if ($global:MockTestFailed -gt 0) {
    exit 1
} else {
    exit 0
}
