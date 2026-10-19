<#
.SYNOPSIS
    Test-CpuSiliconTopologyMocks.ps1 - Suite de Mocks SintÃ©ticos Multi-Hardware (PLAN-0150)
    ValidaciÃ³n rigurosa de las 6 Familias de Silicio y Despacho PolimÃ³rfico de Kernel.

.DESCRIPTION
    Certifica conforme a la Regla 14 (Salvaguarda Multi-Hardware por Mocks SintÃ©ticos):
      1. Intel HeterogÃ©neo HÃ­brido (13700K / Thread Director / P+E Cores).
      2. AMD Dual-CCD AsimÃ©trico con 3D V-Cache (7950X3D / 50% Core Parking).
      3. AMD Zen 3/4/5 SimÃ©trico MonolÃ­tico (5600X / Preferred Cores / PROCTHROTTLEMIN 5%).
      4. AMD APU MonolÃ­tica con Memoria UMA (8600G / LargeSystemCache 0 / SpreadAcrossCPUs).
      5. AMD Multi-CCX Temprano con Latencia Inter-Die (Ryzen 1600 / Single CCX Containment).
      6. Intel MonolÃ­tico ClÃ¡sico Pre-HWP (Haswell i7-4770K / PROCTHROTTLEMIN 100%).
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $repoRoot "scripts\Core\Hardware-Engine.ps1"))) {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    if (-not (Test-Path (Join-Path $repoRoot "scripts\Core\Hardware-Engine.ps1"))) {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    }
}

$hwEnginePath = Join-Path $repoRoot "scripts\Core\Hardware-Engine.ps1"
if (-not (Test-Path $hwEnginePath)) {
    Write-Error "No se encontro Hardware-Engine.ps1 en: $hwEnginePath"
    exit 1
}

. $hwEnginePath

$totalTests = 0
$passedTests = 0
$failedTests = 0

function Assert-MockTest {
    param(
        [string]$Name,
        [bool]$Condition,
        [string]$Detail = ""
    )
    $script:totalTests++
    if ($Condition) {
        $script:passedTests++
        Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:failedTests++
        Write-Host "  [FAIL] $Name - $Detail" -ForegroundColor Red
    }
}

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS / OptimizedISO - BATERIA DE MOCKS SINTETICOS DE SILICIO (PLAN-0150) " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Runtime: $($PSVersionTable.PSVersion) | Arquitectura Multi-Hardware`n" -ForegroundColor DarkGray

# Helper para construir perfil sintetico
function New-MockHardwareProfile {
    param(
        [string]$CpuName,
        [string]$CpuVendor,
        [int]$Cores,
        [int]$Threads,
        [int]$MaxClockMHz,
        [bool]$HasIntegratedGpu = $false
    )

    $isModernCPU = ($CpuName -match 'i[3579]-1[2-9][0-9]{3}|Core.*Ultra|Ryzen [3579] [5-9][0-9]{3}|Ryzen.*AI|1[2-9]th Gen Intel')
    $isIntelUltra = ($CpuVendor -eq 'Intel' -and $CpuName -match 'Core.*Ultra')
    $isIntelAlderRap = ($CpuVendor -eq 'Intel' -and ($CpuName -match 'i[579]-1[2-4][0-9]{3}') -and ($Threads -gt ($Cores * 1.2)) -and ($Cores -gt 4))
    $isHybridCPU = ($isIntelUltra -or $isIntelAlderRap)
    $isDualCcdX3D = ($CpuName -match 'Ryzen 9 (7900X3D|7950X3D|9900X3D|9950X3D)')
    $isRyzen5kPlus = ($CpuName -match 'Ryzen [3579] [5-9][0-9]{3}|Ryzen [3579] [1-9][0-9]{4}|Ryzen.*AI')
    $isLegacyIntel = ($CpuVendor -eq 'Intel' -and ($CpuName -match 'i[3579]-[1-9][0-9]{2,3}|[1-9]th Gen Intel') -and -not $isModernCPU)

    $archFamily = 'Generic_x86_Fallback'
    $archDisplayName = 'Generica x86/x64 Fallback'

    if ($isHybridCPU) {
        $archFamily = 'Intel_Hybrid_Heterogeneous'
        $archDisplayName = 'Intel Hibrido (P-Cores + E-Cores / Thread Director)'
    } elseif ($isDualCcdX3D) {
        $archFamily = 'AMD_DualCcd_Asymmetric_X3D'
        $archDisplayName = 'AMD Dual-CCD Asimetrico 3D V-Cache (96MB L3)'
    } elseif ($CpuVendor -eq 'AMD' -and ($HasIntegratedGpu -or $CpuName -match 'Ryzen.*[0-9]{4}G|Athlon.*[0-9]{3}G')) {
        $archFamily = 'AMD_Monolithic_APU_UMA'
        $archDisplayName = 'AMD APU Monolitica (Memoria Compartida UMA)'
    } elseif ($CpuVendor -eq 'AMD' -and ($isRyzen5kPlus -or $CpuName -match 'Ryzen 7 (5800X3D|7800X3D|9800X3D)')) {
        $archFamily = 'AMD_Zen_Modern_Symmetric'
        $archDisplayName = 'AMD Zen 3/4/5 Simetrico Monolitico (CPPC2 Preferred Cores)'
    } elseif ($CpuVendor -eq 'AMD' -and ($CpuName -match 'Ryzen [357] [12][0-9]{3}|Threadripper [12][0-9]{3}')) {
        $archFamily = 'AMD_MultiCcx_Early_Legacy'
        $archDisplayName = 'AMD Zen 1 / Zen+ Temprano (Multi-CCX con Latencia Inter-Die)'
    } elseif ($CpuVendor -eq 'Intel' -and ($CpuName -match 'i[3579]-[2-5][0-9]{3}|Core 2|Pentium [G|E]|Celeron [G|E]|Core.*[1-5]th Gen')) {
        $archFamily = 'Intel_Legacy_PreHwp'
        $archDisplayName = 'Intel Legacy Pre-HWP (Haswell/Ivy/Sandy Bridge sin Speed Shift)'
    } elseif ($CpuVendor -eq 'Intel' -and $isLegacyIntel) {
        $archFamily = 'Intel_Modern_Symmetric'
        $archDisplayName = 'Intel Skylake a Rocket Lake (HWP Speed Shift Simetrico)'
    }

    return [PSCustomObject]@{
        CPU = [PSCustomObject]@{
            Name                = $CpuName
            Vendor              = $CpuVendor
            Cores               = $Cores
            Threads             = $Threads
            MaxClockMHz         = $MaxClockMHz
            IsModern            = $isModernCPU
            IsHybrid            = $isHybridCPU
            IsDualCcdX3D        = $isDualCcdX3D
            ArchitectureFamily  = $archFamily
            ArchitectureDisplay = $archDisplayName
        }
        GPU = [PSCustomObject]@{
            HasIntegratedGpu = $HasIntegratedGpu
        }
    }
}

# -----------------------------------------------------------------------------
# CASO 1: Intel HÃ­brido HeterogÃ©neo (Core i7-13700K - Raptor Lake)
# -----------------------------------------------------------------------------
Write-Host ">>> [1/6] Evaluando Arquetipo: Intel Heterogeneo Hibrido (Core i7-13700K)..." -ForegroundColor Yellow
$mock13700K = New-MockHardwareProfile -CpuName "13th Gen Intel(R) Core(TM) i7-13700K" -CpuVendor "Intel" -Cores 16 -Threads 24 -MaxClockMHz 5400
$policy13700K = Get-RomanOSCpuArchitecturePolicy -HardwareInfo $mock13700K

Assert-MockTest -Name "Familia de silicio clasificada como Intel_Hybrid_Heterogeneous" -Condition ($policy13700K.ArchitectureFamily -eq 'Intel_Hybrid_Heterogeneous')
Assert-MockTest -Name "Preserva Win32PrioritySeparation = 2 para Intel Thread Director" -Condition ($policy13700K.Win32PrioritySeparation -eq 2)
Assert-MockTest -Name "Core Parking en ThreadDirectorManaged (No forzar 100% ciego)" -Condition ($policy13700K.CoreParkingPolicy -eq 'ThreadDirectorManaged')
Assert-MockTest -Name "PROCTHROTTLEMIN en 5% para permitir CC6 en nÃºcleos inactivos" -Condition ($policy13700K.ProcThrottleMinPercent -eq 5)

# -----------------------------------------------------------------------------
# CASO 2: AMD Dual-CCD AsimÃ©trico con 3D V-Cache (Ryzen 9 7950X3D)
# -----------------------------------------------------------------------------
Write-Host "`n>>> [2/6] Evaluando Arquetipo: AMD Dual-CCD Asimetrico 3D V-Cache (Ryzen 9 7950X3D)..." -ForegroundColor Yellow
$mock7950X3D = New-MockHardwareProfile -CpuName "AMD Ryzen 9 7950X3D 16-Core Processor" -CpuVendor "AMD" -Cores 16 -Threads 32 -MaxClockMHz 5700
$policy7950X3D = Get-RomanOSCpuArchitecturePolicy -HardwareInfo $mock7950X3D

Assert-MockTest -Name "Familia de silicio clasificada como AMD_DualCcd_Asymmetric_X3D" -Condition ($policy7950X3D.ArchitectureFamily -eq 'AMD_DualCcd_Asymmetric_X3D')
Assert-MockTest -Name "Core Parking forzado a AsymmetricX3D_50Percent (PROHIBIDO UnparkAll)" -Condition ($policy7950X3D.CoreParkingPolicy -eq 'AsymmetricX3D_50Percent')
Assert-MockTest -Name "Preserva Win32PrioritySeparation = 2 para no desbalancear AMD PPM" -Condition ($policy7950X3D.Win32PrioritySeparation -eq 2)

# -----------------------------------------------------------------------------
# CASO 3: AMD MonolÃ­tico SimÃ©trico Moderno (Ryzen 5 5600X)
# -----------------------------------------------------------------------------
Write-Host "`n>>> [3/6] Evaluando Arquetipo: AMD Zen 3/4/5 Simetrico Monolitico (Ryzen 5 5600X)..." -ForegroundColor Yellow
$mock5600X = New-MockHardwareProfile -CpuName "AMD Ryzen 5 5600X 6-Core Processor" -CpuVendor "AMD" -Cores 6 -Threads 12 -MaxClockMHz 4650
$policy5600X = Get-RomanOSCpuArchitecturePolicy -HardwareInfo $mock5600X

Assert-MockTest -Name "Familia de silicio clasificada como AMD_Zen_Modern_Symmetric" -Condition ($policy5600X.ArchitectureFamily -eq 'AMD_Zen_Modern_Symmetric')
Assert-MockTest -Name "PROCTHROTTLEMIN = 5% para liberar margen termico PB2" -Condition ($policy5600X.ProcThrottleMinPercent -eq 5)
Assert-MockTest -Name "Win32PrioritySeparation = 38 (Simetrico puro optimizado)" -Condition ($policy5600X.Win32PrioritySeparation -eq 38)
Assert-MockTest -Name "Core Unparking al 100% seguro en silicio simetrico" -Condition ($policy5600X.CoreParkingPolicy -eq 'UnparkAll')

# -----------------------------------------------------------------------------
# CASO 4: AMD APU MonolÃ­tica con Memoria UMA (Ryzen 5 8600G)
# -----------------------------------------------------------------------------
Write-Host "`n>>> [4/6] Evaluando Arquetipo: AMD APU Monolitica con Memoria UMA (Ryzen 5 8600G)..." -ForegroundColor Yellow
$mock8600G = New-MockHardwareProfile -CpuName "AMD Ryzen 5 8600G w/ Radeon 760M Graphics" -CpuVendor "AMD" -Cores 6 -Threads 12 -MaxClockMHz 4350 -HasIntegratedGpu $true
$policy8600G = Get-RomanOSCpuArchitecturePolicy -HardwareInfo $mock8600G

Assert-MockTest -Name "Familia de silicio clasificada como AMD_Monolithic_APU_UMA" -Condition ($policy8600G.ArchitectureFamily -eq 'AMD_Monolithic_APU_UMA')
Assert-MockTest -Name "LargeSystemCache = 0 estricto (Blindaje contra TDRs en VRAM compartida)" -Condition ($policy8600G.LargeSystemCache -eq 0)
Assert-MockTest -Name "Afinidad DPC en SpreadAcrossCPUs para no congestionar bus interno APU" -Condition ($policy8600G.AffinityDpcStrategy -eq 'SpreadAcrossCPUs')

# -----------------------------------------------------------------------------
# CASO 5: AMD Multi-CCX Temprano con Latencia Inter-Die (Ryzen 5 1600)
# -----------------------------------------------------------------------------
Write-Host "`n>>> [5/6] Evaluando Arquetipo: AMD Zen 1 Temprano Multi-CCX (Ryzen 5 1600)..." -ForegroundColor Yellow
$mock1600 = New-MockHardwareProfile -CpuName "AMD Ryzen 5 1600 Six-Core Processor" -CpuVendor "AMD" -Cores 6 -Threads 12 -MaxClockMHz 3600
$policy1600 = Get-RomanOSCpuArchitecturePolicy -HardwareInfo $mock1600

Assert-MockTest -Name "Familia de silicio clasificada como AMD_MultiCcx_Early_Legacy" -Condition ($policy1600.ArchitectureFamily -eq 'AMD_MultiCcx_Early_Legacy')
Assert-MockTest -Name "Afinidad DPC configurada en SingleCcxContainment (Evitar salto de 140ns)" -Condition ($policy1600.AffinityDpcStrategy -eq 'SingleCcxContainment')

# -----------------------------------------------------------------------------
# CASO 6: Intel MonolÃ­tico ClÃ¡sico Pre-HWP (Core i7-4770K Haswell 4ta Gen)
# -----------------------------------------------------------------------------
Write-Host "`n>>> [6/6] Evaluando Arquetipo: Intel Legacy Pre-HWP (Core i7-4770K)..." -ForegroundColor Yellow
$mock4770K = New-MockHardwareProfile -CpuName "Intel(R) Core(TM) i7-4770K CPU @ 3.50GHz" -CpuVendor "Intel" -Cores 4 -Threads 8 -MaxClockMHz 3900
$policy4770K = Get-RomanOSCpuArchitecturePolicy -HardwareInfo $mock4770K

Assert-MockTest -Name "Familia de silicio clasificada como Intel_Legacy_PreHwp" -Condition ($policy4770K.ArchitectureFamily -eq 'Intel_Legacy_PreHwp')
Assert-MockTest -Name "PROCTHROTTLEMIN fijado en 100% (Justificado por latencia de 30ms en P-states ACPI)" -Condition ($policy4770K.ProcThrottleMinPercent -eq 100)
Assert-MockTest -Name "Win32PrioritySeparation = 38 (Ring Bus monolÃ­tico sin Thread Director)" -Condition ($policy4770K.Win32PrioritySeparation -eq 38)

# -----------------------------------------------------------------------------
# RESUMEN GLOBAL DE RESULTADOS
# -----------------------------------------------------------------------------
Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN: CERTIFICACION SINTETICA MULTI-HARDWARE DE SILICIO (PLAN-0150)  " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Total de Aserciones : $totalTests" -ForegroundColor White
Write-Host " Aprobadas (PASS)    : $passedTests" -ForegroundColor Green
Write-Host " Fallidas  (FAIL)    : $failedTests" -ForegroundColor $(if($failedTests -gt 0){'Red'}else{'Gray'})
Write-Host "==========================================================================`n" -ForegroundColor Cyan

if ($failedTests -gt 0) { exit 1 } else { exit 0 }
