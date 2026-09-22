<#
.SYNOPSIS
    Test-InterruptAffinity.ps1 - Arnés de Pruebas Unitarias del Optimizador de Afinidad PCIe e IRQ
    Certificación de Introspección, Máscaras de Bits, DPC Steering y PowerShell 5.1

.DESCRIPTION
    Ejecuta una batería de aserciones unitarias para verificar:
      1. Existencia física y codificación conforme a la Regla 4 (UTF-8 BOM en PS1, No-BOM en CMD).
      2. Parser AST de Windows PowerShell 5.1 sin errores sintácticos.
      3. Introspección de topología PCIe (GPU, NVMe, Adaptadores de Red).
      4. Validación de máscara de afinidad binaria (aislamiento de Núcleo 0, byte array inmutable).
      5. Ejecución simulada (-WhatIf) de auditoría (-Action Status) y calibración (-Action Optimize).
      6. Integración y paridad en Toolkit Maestro, Control Center GUI y New-OptimizedWindowsISO-v2.ps1.
#>

[CmdletBinding()]
param(
    [string]$LogDir = "C:\OptimizedISO\Log"
)

$ErrorActionPreference = 'Continue'
$testStart = Get-Date

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $repoRoot "scripts\Core"))) {
    $repoRoot = "C:\OptimizedISO"
}

$passCount = 0
$failCount = 0

function Assert-Test {
    param(
        [string]$Title,
        [bool]$Condition,
        [string]$Details = ""
    )
    if ($Condition) {
        $script:passCount++
        Write-Host "  [PASS] $Title" -ForegroundColor Green
        if ($Details) { Write-Host "         $Details" -ForegroundColor DarkGray }
    } else {
        $script:failCount++
        Write-Host "  [FAIL] $Title" -ForegroundColor Red
        if ($Details) { Write-Host "         $Details" -ForegroundColor DarkRed }
    }
}

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS — BATERIA DE PRUEBAS: AFINIDAD PCIE, IRQ Y DPC STEERING          " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Runtime: Windows PowerShell $($PSVersionTable.PSVersion)`n" -ForegroundColor Gray

# -----------------------------------------------------------------------------
# BLOQUE 1: ARCHIVOS Y ENCODING
# -----------------------------------------------------------------------------
Write-Host ">>> [1/3] Verificando Archivos y Codificacion de Encodings..." -ForegroundColor Cyan

$affinityPs1 = Join-Path $repoRoot "scripts\Modules\Optimize-InterruptAffinity.ps1"
$affinityCmd = Join-Path $repoRoot "scripts\Modules\Optimize-InterruptAffinity.cmd"

Assert-Test -Title "Existencia fisica de Optimize-InterruptAffinity.ps1" `
    -Condition (Test-Path $affinityPs1) `
    -Details $affinityPs1

Assert-Test -Title "Existencia fisica de Optimize-InterruptAffinity.cmd" `
    -Condition (Test-Path $affinityCmd) `
    -Details $affinityCmd

$ps1Bytes = if (Test-Path $affinityPs1) { [System.IO.File]::ReadAllBytes($affinityPs1) } else { @() }
$hasBOM = ($ps1Bytes.Count -ge 3 -and $ps1Bytes[0] -eq 0xEF -and $ps1Bytes[1] -eq 0xBB -and $ps1Bytes[2] -eq 0xBF)
Assert-Test -Title "Optimize-InterruptAffinity.ps1 codificado en UTF-8 con BOM (Regla 4)" `
    -Condition $hasBOM `
    -Details ("Primeros bytes: 0x{0:X2}-{1:X2}-{2:X2}" -f $ps1Bytes[0], $ps1Bytes[1], $ps1Bytes[2])

$cmdBytes = if (Test-Path $affinityCmd) { [System.IO.File]::ReadAllBytes($affinityCmd) } else { @() }
$cmdHasBOM = ($cmdBytes.Count -ge 3 -and $cmdBytes[0] -eq 0xEF -and $cmdBytes[1] -eq 0xBB -and $cmdBytes[2] -eq 0xBF)
Assert-Test -Title "Optimize-InterruptAffinity.cmd es estrictamente No-BOM (Regla 4)" `
    -Condition (-not $cmdHasBOM) `
    -Details "cmdHasBOM: $cmdHasBOM"

$astErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($affinityPs1, [ref]$null, [ref]$astErrors)
Assert-Test -Title "Parser AST de Windows PowerShell 5.1 sin errores sintacticos" `
    -Condition ($null -eq $astErrors -or $astErrors.Count -eq 0) `
    -Details "Errores detectados: $(if ($astErrors) { $astErrors.Count } else { 0 })"

# -----------------------------------------------------------------------------
# BLOQUE 2: INTROSPECCION DE TOPOLOGIA PCIE Y MASCARAS DE AFINIDAD
# -----------------------------------------------------------------------------
Write-Host "`n>>> [2/3] Verificando Introspeccion de Topologia PCIe y Mascaras..." -ForegroundColor Cyan

# Dot-sourcing del script para invocar funciones de introspección sin ejecutar la acción principal
. $affinityPs1 -Action None -SkipElevation -Unattended

$devices = Get-RomanOSPcieInterruptTopology
Assert-Test -Title "Topologia PCIe detectada y estructurada por Get-RomanOSPcieInterruptTopology" `
    -Condition ($devices -ne $null -and $devices.Count -gt 0) `
    -Details "Dispositivos detectados: $($devices.Count)"

$cpuCores = [System.Environment]::ProcessorCount
Assert-Test -Title "Nucleos de CPU identificados correctamente (> 0)" `
    -Condition ($cpuCores -gt 0) `
    -Details "CPU Cores: $cpuCores"

$affinityBytes = Get-RomanOSAffinityMask -Strategy "ExcludeCoreZero"
$validMaskBytes = ($affinityBytes -ne $null -and $affinityBytes.Count -eq 8 -and $affinityBytes[0] -eq 0xFE)
Assert-Test -Title "Mascara binaria de afinidad aisla el Core 0 (Byte 0 = 0xFE, 8 bytes inmutables)" `
    -Condition $validMaskBytes `
    -Details "Bytes: $($affinityBytes -join ' ')"

$hasGpuOrNvme = ($devices | Where-Object { $_.Category -in @("GPU", "Storage", "Network") })
Assert-Test -Title "Identificacion de al menos un dispositivo de alto impacto (GPU, NVMe o NIC)" `
    -Condition ($hasGpuOrNvme.Count -gt 0) `
    -Details "Dispositivos categorizados: $($hasGpuOrNvme.Count)"

# -----------------------------------------------------------------------------
# BLOQUE 3: SIMULACION -WHATIF Y PARIDAD EN ECOSISTEMA (TOOLKIT, GUI, BUILDER)
# -----------------------------------------------------------------------------
Write-Host "`n>>> [3/3] Verificando Ejecucion Simulada (-WhatIf) y Ecosistema..." -ForegroundColor Cyan

$whatIfStatus = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $affinityPs1 -Action Status -WhatIf 2>&1
$statusOk = ($LASTEXITCODE -eq 0 -and ($whatIfStatus -match "Topología" -or $whatIfStatus -match "RESUMEN" -or $whatIfStatus -match "COMPLETADO"))
Assert-Test -Title "Modo simulado -WhatIf en -Action Status ejecuta limpiamente" `
    -Condition $statusOk `
    -Details "Status WhatIf exitoso"

$whatIfOptimize = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $affinityPs1 -Action Optimize -WhatIf 2>&1
$optimizeOk = ($LASTEXITCODE -eq 0 -and ($whatIfOptimize -match "WhatIf" -or $whatIfOptimize -match "simuló" -or $whatIfOptimize -match "Se está realizando"))
Assert-Test -Title "Modo simulado -WhatIf en -Action Optimize ejecuta limpiamente" `
    -Condition $optimizeOk `
    -Details "Optimize WhatIf exitoso"

# Integracion en Toolkit
$toolkitPath = Join-Path $repoRoot "scripts\Modules\romanOS-Toolkit.ps1"
$toolkitContent = if (Test-Path $toolkitPath) { Get-Content $toolkitPath -Raw } else { "" }
$hasToolkitAffinity = ($toolkitContent -match "Invoke-InterruptAffinityModule" -and $toolkitContent -match "Optimize-InterruptAffinity")
Assert-Test -Title "Integracion y paridad en romanOS-Toolkit.ps1 (CLI y QuickAction 23)" `
    -Condition $hasToolkitAffinity `
    -Details "Toolkit Integration: $hasToolkitAffinity"

# Integracion en Control Center
$ccPath = Join-Path $repoRoot "scripts\GUI\romanOS-ControlCenter.ps1"
$ccContent = if (Test-Path $ccPath) { Get-Content $ccPath -Raw } else { "" }
$hasCCAffinity = ($ccContent -match "btnAuditAffinityGUI" -and $ccContent -match "btnOptimizeAffinityGUI" -and $ccContent -match "Optimize-InterruptAffinity\.ps1")
Assert-Test -Title "Integracion y paridad en romanOS-ControlCenter.ps1 (XAML y Event Handlers)" `
    -Condition $hasCCAffinity `
    -Details "Control Center Integration: $hasCCAffinity"

# Integracion en Builder ISO
$builderPath = Join-Path $repoRoot "scripts\Builder\New-OptimizedWindowsISO-v2.ps1"
$builderContent = if (Test-Path $builderPath) { Get-Content $builderPath -Raw } else { "" }
$hasBuilderAffinity = ($builderContent -match "Optimize-InterruptAffinity\.ps1" -and $builderContent -match "Optimize-InterruptAffinity\.cmd")
Assert-Test -Title "Integracion e inyeccion fisica en New-OptimizedWindowsISO-v2.ps1 (OEM y WIM)" `
    -Condition $hasBuilderAffinity `
    -Details "Builder Injection: $hasBuilderAffinity"

# -----------------------------------------------------------------------------
# RESUMEN DE PRUEBAS
# -----------------------------------------------------------------------------
$duration = [math]::Round(((Get-Date) - $testStart).TotalSeconds, 2)
$totalTests = $passCount + $failCount
$overallPass = ($failCount -eq 0)

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN: PRUEBAS DE AFINIDAD PCIE, IRQ Y DPC STEERING                   " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Total de Aserciones : $totalTests"
Write-Host " Aprobadas (PASS)    : $passCount" -ForegroundColor Green
Write-Host " Fallidas (FAIL)     : $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host " Duracion Total      : ${duration}s"
Write-Host " Estado Global       : $(if ($overallPass) { 'PASS (100% Exitoso)' } else { 'FAIL' })" -ForegroundColor $(if ($overallPass) { "Green" } else { "Red" })
Write-Host "==========================================================================`n" -ForegroundColor Cyan

exit $(if ($overallPass) { 0 } else { 1 })
