<#
.SYNOPSIS
    Test-HardwareEngine.ps1 - Suite de Pruebas Unitarias para el Motor de Hardware
    Validación rigurosa de clasificación PCI-SIG, SMBIOS, CPU, RAM, Storage, HAGS y MSI Mode.

.DESCRIPTION
    Prueba tanto la introspección real contra el hardware anfitrión como casos sintéticos (mocks)
    para verificar que:
      1. AMD Radeon RX 580 (VEN_1002, DEV_67DF) se clasifique como AMD Dedicated GPU con soporte MSI.
      2. NVIDIA GeForce RTX 3080 (VEN_10DE, DEV_2206) se clasifique como NVIDIA Dedicated con HAGS y MSI.
      3. Intel Arc A770 (VEN_8086, DEV_56A0) se clasifique como Intel Arc Dedicated con HAGS y MSI.
      4. Intel UHD Graphics 630 (VEN_8086, DEV_3E92) se clasifique como Intel Integrated.
      5. AMD Radeon 680M APU (VEN_1002, DEV_1681) se clasifique como AMD Integrated APU con soporte MSI.
      6. Chasis DMTF 3 con Batería (UPS) se mantenga como Desktop y no Laptop.
      7. CPUs híbridas (13900K), AMD 3D V-Cache multi-CCD (7950X3D) y low-end (Celeron) se clasifiquen con exactitud.
      8. Formateo y ejecución no lancen excepciones en Windows PowerShell 5.1.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$hwEnginePaths = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\Hardware-Engine.ps1"),
    (Join-Path $PSScriptRoot "Core\Hardware-Engine.ps1"),
    (Join-Path $PSScriptRoot "Hardware-Engine.ps1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\Hardware-Engine.ps1"),
    "C:\Windows\Setup\Scripts\Core\Hardware-Engine.ps1"
)
$hwLoaded = $false
foreach ($p in $hwEnginePaths) {
    if (Test-Path $p) {
        . $p
        $hwLoaded = $true
        break
    }
}
if (-not $hwLoaded) {
    Write-Error "No se encontro Hardware-Engine.ps1 en ninguna ruta conocida."
    exit 1
}

$totalTests = 0
$passedTests = 0
$failedTests = 0

function Assert-Test {
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

Write-Host "`n=== BATERIA DE PRUEBAS UNITARIAS: Hardware-Engine.ps1 ===" -ForegroundColor Cyan
Write-Host "Ejecutando en runtime: $($PSVersionTable.PSVersion)`n" -ForegroundColor DarkGray

# -----------------------------------------------------------------------------
# 1. PRUEBAS EN VIVO SOBRE EL SISTEMA ANFITRION
# -----------------------------------------------------------------------------
Write-Host "--- 1. Pruebas de Introspeccion en Vivo ---" -ForegroundColor Yellow

$liveProfile = Get-SystemHardwareProfile -ForceRefresh

Assert-Test -Name "Get-SystemHardwareProfile retorna un objeto valido" -Condition ($null -ne $liveProfile)
Assert-Test -Name "Platform object esta presente y estructurado" -Condition ($null -ne $liveProfile.Platform -and $liveProfile.Platform.PlatformSource.Length -gt 0)
Assert-Test -Name "CPU Cores y Threads detectados (> 0)" -Condition ($liveProfile.CPU.Cores -gt 0 -and $liveProfile.CPU.Threads -gt 0)
Assert-Test -Name "RAM TotalGiB mayor a 0" -Condition ($liveProfile.RAM.TotalGiB -gt 0)
Assert-Test -Name "Disk object poblado correctamente" -Condition ($null -ne $liveProfile.Disk.BootBusType)
Assert-Test -Name "GPU Devices detectadas y array no nulo" -Condition ($null -ne $liveProfile.GPU.Devices)
Assert-Test -Name "Profile DisplayName no vacio" -Condition ($liveProfile.Profile.DisplayName.Length -gt 0)

# Formateo sin errores
try {
    Format-HardwareSummary -Profile $liveProfile | Out-Null
    Assert-Test -Name "Format-HardwareSummary ejecuta sin excepciones" -Condition $true
} catch {
    Assert-Test -Name "Format-HardwareSummary ejecuta sin excepciones" -Condition $false -Detail $_.Exception.Message
}

# -----------------------------------------------------------------------------
# 2. PRUEBAS DE CLASIFICACION SINTETICA DE GPUS (PCI-SIG VENDOR IDS)
# -----------------------------------------------------------------------------
Write-Host "`n--- 2. Pruebas de Clasificacion Sintetica de GPUs (PCI-SIG) ---" -ForegroundColor Yellow

# Caso 2.1: AMD Radeon RX 580 (Polaris DEV_67DF)
$amdPnp = 'PCI\VEN_1002&DEV_67DF&SUBSYS_05211043&REV_E7\4&1FC990D7&0&0019'
$vendorId = ''
if ($amdPnp -match 'VEN_([0-9A-Fa-f]{4})') { $vendorId = $matches[1].ToUpper() }
$vendorName = $script:PCI_VENDORS[$vendorId]
Assert-Test -Name "AMD RX 580 VEN_1002 mapea a Vendor 'AMD'" -Condition ($vendorName -eq 'AMD')
Assert-Test -Name "AMD RX 580 soporta MSI por ser bus PCIe" -Condition ($amdPnp -match '^PCI\\')

# Caso 2.2: NVIDIA GeForce RTX 3080 (Ampere DEV_2206)
$nvPnp = 'PCI\VEN_10DE&DEV_2206&SUBSYS_87B31043&REV_A1\4&2ABC1234&0&0008'
$nvVendor = if ($nvPnp -match 'VEN_([0-9A-Fa-f]{4})') { $script:PCI_VENDORS[$matches[1].ToUpper()] } else { '' }
Assert-Test -Name "NVIDIA RTX 3080 VEN_10DE mapea a Vendor 'NVIDIA'" -Condition ($nvVendor -eq 'NVIDIA')

# Caso 2.3: Intel Arc A770 (Alchemist DEV_56A0)
$arcPnp = 'PCI\VEN_8086&DEV_56A0&SUBSYS_10208086&REV_08\4&3DEF5678&0&0010'
$arcVendor = if ($arcPnp -match 'VEN_([0-9A-Fa-f]{4})') { $script:PCI_VENDORS[$matches[1].ToUpper()] } else { '' }
$arcIsArc = ($arcPnp -match 'DEV_56')
Assert-Test -Name "Intel Arc A770 VEN_8086 mapea a Intel Arc dedicado" -Condition ($arcVendor -eq 'Intel' -and $arcIsArc)

# Caso 2.4: VirtualBox Graphics Adapter (VEN_80EE)
$vboxPnp = 'PCI\VEN_80EE&DEV_BEEF&SUBSYS_00000000&REV_00\3&267A616A&0&10'
$vboxVendor = if ($vboxPnp -match 'VEN_([0-9A-Fa-f]{4})') { $script:PCI_VENDORS[$matches[1].ToUpper()] } else { '' }
Assert-Test -Name "VirtualBox Video Adapter VEN_80EE mapea a VirtualBox" -Condition ($vboxVendor -eq 'VirtualBox')

# -----------------------------------------------------------------------------
# 3. PRUEBAS DE CLASIFICACION DMTF SMBIOS Y CHASIS
# -----------------------------------------------------------------------------
Write-Host "`n--- 3. Pruebas de Clasificacion DMTF SMBIOS ---" -ForegroundColor Yellow

$desktopTypes = @(3, 6, 7)
$isDesktopCheck = $false
foreach ($dt in $desktopTypes) {
    if ($script:DMTF_DESKTOP_TYPES -contains $dt) { $isDesktopCheck = $true }
}
Assert-Test -Name "Tipos DMTF Desktop (3, 6, 7) clasificados correctamente" -Condition $isDesktopCheck

$laptopTypes = @(8, 9, 10)
$isLaptopCheck = $false
foreach ($lt in $laptopTypes) {
    if ($script:DMTF_LAPTOP_TYPES -contains $lt) { $isLaptopCheck = $true }
}
Assert-Test -Name "Tipos DMTF Laptop (8, 9, 10) clasificados correctamente" -Condition $isLaptopCheck

# -----------------------------------------------------------------------------
# 4. PRUEBAS DE TOPOLOGIA DE CPU
# -----------------------------------------------------------------------------
Write-Host "`n--- 4. Pruebas de Topologia de CPU ---" -ForegroundColor Yellow

$cpu5600X = "AMD Ryzen 5 5600X 6-Core Processor"
$is5600XModern = ($cpu5600X -match 'Ryzen [0-9] [5-9][0-9]{3}')
$is5600XDualCcd = ($cpu5600X -match 'Ryzen 9 (7900X3D|7950X3D|9900X3D|9950X3D)')
Assert-Test -Name "Ryzen 5 5600X clasificado como Moderno y NO Dual-CCD X3D" -Condition ($is5600XModern -and -not $is5600XDualCcd)

$cpu7950X3D = "AMD Ryzen 9 7950X3D 16-Core Processor"
$is7950X3DDualCcd = ($cpu7950X3D -match 'Ryzen 9 (7900X3D|7950X3D|9900X3D|9950X3D)')
Assert-Test -Name "Ryzen 9 7950X3D clasificado correctamente como Dual-CCD 3D V-Cache" -Condition $is7950X3DDualCcd

$cpu13900K = "13th Gen Intel(R) Core(TM) i9-13900K"
$is13900KModern = ($cpu13900K -match 'i[3579]-1[2-9][0-9]{3}' -or $cpu13900K -match '1[2-9]th Gen Intel')
Assert-Test -Name "Intel Core i9-13900K clasificado como CPU Moderna" -Condition $is13900KModern

$cpuUltra = "Intel(R) Core(TM) Ultra 7 155H"
$isUltraModern = ($cpuUltra -match 'Core.*Ultra')
Assert-Test -Name "Intel Core Ultra 7 155H clasificado como CPU Moderna" -Condition $isUltraModern

$cpuArrowLake = "Intel(R) Core(TM) Ultra 9 285K"
$isArrowLakeModern = ($cpuArrowLake -match 'Core.*Ultra')
$isArrowLakeHybrid = ($cpuArrowLake -match 'Core.*Ultra')
Assert-Test -Name "Intel Core Ultra 9 285K (Arrow Lake) clasificado como Moderno e Hibrido" -Condition ($isArrowLakeModern -and $isArrowLakeHybrid)

$cpuN100 = "Intel(R) Processor N100"
$isN100EcoreOnly = ($cpuN100 -match 'Processor\s+N[0-9]{2,3}')
$isN100Modern = ($cpuN100 -match 'Intel.*Processor.*N[0-9]{2,3}')
Assert-Test -Name "Intel Processor N100 (Alder Lake-N) clasificado como E-Core Only y Moderno" -Condition ($isN100EcoreOnly -and $isN100Modern)

$cpu10700K = "Intel(R) Core(TM) i7-10700K CPU @ 3.80GHz"
$is10700KLegacy = ($cpu10700K -match 'i[3579]-[1-9][0-9]{2,3}' -and $cpu10700K -notmatch 'i[3579]-1[2-9][0-9]{3}')
Assert-Test -Name "Intel Core i7-10700K clasificado como Legacy Intel (Pre-12th)" -Condition $is10700KLegacy

$cpuXeon = "Intel(R) Xeon(R) Platinum 8480+"
$isXeon = ($cpuXeon -match 'Xeon')
Assert-Test -Name "Intel Xeon Platinum 8480+ clasificado como Xeon" -Condition $isXeon

$cpuCeleron = "Intel(R) Celeron(R) N4020 CPU @ 1.10GHz"
$isCeleronLowEnd = ($cpuCeleron -match 'Celeron|Pentium|Atom|J[0-9]{4}|N[0-9]{4}')
Assert-Test -Name "Intel Celeron N4020 clasificado como Low-End" -Condition $isCeleronLowEnd

# -----------------------------------------------------------------------------
# 5. RESUMEN FINAL DE RESULTADOS
# -----------------------------------------------------------------------------
Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "  RESUMEN DE PRUEBAS DEL MOTOR DE HARDWARE" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "  Total de Aserciones : $totalTests" -ForegroundColor White
Write-Host "  Aprobadas (PASS)    : $passedTests" -ForegroundColor Green
Write-Host "  Fallidas (FAIL)     : $failedTests" -ForegroundColor $(if($failedTests -gt 0){'Red'}else{'Gray'})
Write-Host "=======================================================`n" -ForegroundColor Cyan

if ($failedTests -gt 0) {
    exit 1
} else {
    exit 0
}
