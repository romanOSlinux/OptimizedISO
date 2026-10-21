<#
.SYNOPSIS
    Test-StartupEcosystem.ps1 - Arnés de Pruebas Unitarias de Gobernanza de Inicio y Servicios a Demanda (PLAN-0159)
    Certificación de Introspección, Catálogos SSOT, Mocks Sintéticos y Windows PowerShell 5.1

.DESCRIPTION
    Ejecuta una batería de aserciones unitarias para verificar:
      1. Existencia física y codificación conforme a la Regla 4 (UTF-8 BOM en PS1, No-BOM en CMD).
      2. Parser AST de Windows PowerShell 5.1 sin errores sintácticos.
      3. Introspección de catálogos canónicos SSOT (Get-RomanOSDemandServices y Get-RomanOSStartupThirdPartyCatalog).
      4. Exportación en autounattend.xml (sc.exe config start= demand y MaintenanceDisabled).
      5. Ejecución simulada (-WhatIf) de Status y Optimize sin modificar el sistema host.
      6. Integración y paridad en Control Center GUI, Toolkit Maestro, Debloat y Builder v2.
#>

[CmdletBinding()]
param(
    [string]$LogDir = ""
)

$ErrorActionPreference = 'Continue'
$testStart = Get-Date

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $repoRoot "scripts\Core"))) {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
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
Write-Host " romanOS — BATERIA DE PRUEBAS: GOBERNANZA DE INICIO Y SERVICIOS A DEMANDA " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Runtime: Windows PowerShell $($PSVersionTable.PSVersion)`n" -ForegroundColor Gray

# -----------------------------------------------------------------------------
# BLOQUE 1: ARCHIVOS Y ENCODINGS (REGLA 4)
# -----------------------------------------------------------------------------
Write-Host ">>> [1/3] Verificando Archivos y Codificacion de Encodings (Regla 4)..." -ForegroundColor Cyan

$startupPs1 = Join-Path $repoRoot "scripts\Modules\Optimize-StartupEcosystem.ps1"
$startupCmd = Join-Path $repoRoot "scripts\Modules\Optimize-StartupEcosystem.cmd"

Assert-Test -Title "Existencia fisica de Optimize-StartupEcosystem.ps1" `
    -Condition (Test-Path $startupPs1) `
    -Details $startupPs1

Assert-Test -Title "Existencia fisica de Optimize-StartupEcosystem.cmd" `
    -Condition (Test-Path $startupCmd) `
    -Details $startupCmd

$ps1Bytes = if (Test-Path $startupPs1) { [System.IO.File]::ReadAllBytes($startupPs1) } else { @() }
$hasBOM = ($ps1Bytes.Length -ge 3 -and $ps1Bytes[0] -eq 0xEF -and $ps1Bytes[1] -eq 0xBB -and $ps1Bytes[2] -eq 0xBF)
Assert-Test -Title "Optimize-StartupEcosystem.ps1 codificado en UTF-8 con BOM (Regla 4)" `
    -Condition $hasBOM `
    -Details "Primeros bytes: 0x$([BitConverter]::ToString($ps1Bytes[0..2]))"

$cmdBytes = if (Test-Path $startupCmd) { [System.IO.File]::ReadAllBytes($startupCmd) } else { @() }
$cmdHasBOM = ($cmdBytes.Length -ge 3 -and $cmdBytes[0] -eq 0xEF -and $cmdBytes[1] -eq 0xBB -and $cmdBytes[2] -eq 0xBF)
Assert-Test -Title "Optimize-StartupEcosystem.cmd es estrictamente No-BOM (Regla 4)" `
    -Condition (-not $cmdHasBOM) `
    -Details "cmdHasBOM: $cmdHasBOM"

# Validación sintáctica AST con Windows PowerShell 5.1
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($startupPs1, [ref]$tokens, [ref]$errors) | Out-Null
Assert-Test -Title "Parser AST de Optimize-StartupEcosystem.ps1 sin errores sintacticos" `
    -Condition ($errors.Count -eq 0) `
    -Details "Errores detectados: $($errors.Count)"

# -----------------------------------------------------------------------------
# BLOQUE 2: CATÁLOGOS CANÓNICOS SSOT Y EXPORTACIÓN UNATTEND
# -----------------------------------------------------------------------------
Write-Host "`n>>> [2/3] Verificando Catalogos SSOT y Exportacion Unattend (Policy-Engine)..." -ForegroundColor Cyan

$policyEnginePath = Join-Path $repoRoot "scripts\Core\Policy-Engine.ps1"
. $policyEnginePath

$demandServices = Get-RomanOSDemandServices
Assert-Test -Title "Get-RomanOSDemandServices retorna catalogo canonico (>= 10 servicios)" `
    -Condition ($demandServices.Count -ge 10) `
    -Details "Servicios registrados: $($demandServices.Count)"

$hasWSAI = ($demandServices | Where-Object { $_.Name -eq "WSAIFabricSvc" -and $_.TargetStartup -eq "Manual" })
Assert-Test -Title "Catalogo incluye WSAIFabricSvc con TargetStartup Manual" `
    -Condition ($null -ne $hasWSAI) `
    -Details "WSAIFabricSvc SCCommand: $($hasWSAI.SCCommand)"

$thirdPartyCatalog = Get-RomanOSStartupThirdPartyCatalog
Assert-Test -Title "Get-RomanOSStartupThirdPartyCatalog retorna catalogo de terceros (>= 5 apps)" `
    -Condition ($thirdPartyCatalog.Count -ge 5) `
    -Details "Aplicaciones registradas: $($thirdPartyCatalog.Count)"

$hasAmd = ($thirdPartyCatalog | Where-Object { $_.Id -eq "STARTUP_AMD_ADRENALIN" })
Assert-Test -Title "Catalogo incluye AMD Radeon Software con CanDisableSafe = True" `
    -Condition ($null -ne $hasAmd -and $hasAmd.CanDisableSafe) `
    -Details "AMD TargetNames: $(($hasAmd.TargetNames) -join ', ')"

# Verificación de directivas en $global:RomanOS_Policies
$hasMaintPol = ($global:RomanOS_Policies | Where-Object { $_.Id -eq "POL_MAINTENANCE_DISABLE_LOGON_SPIKE" })
Assert-Test -Title "Directiva POL_MAINTENANCE_DISABLE_LOGON_SPIKE presente en SSOT" `
    -Condition ($null -ne $hasMaintPol -and $hasMaintPol.ExpectedValue -eq 1) `
    -Details "RegistryKey: $($hasMaintPol.RegistryKey)"

$hasBingPol = ($global:RomanOS_Policies | Where-Object { $_.Id -eq "POL_SEARCH_BING_ENABLED_HKCU" })
Assert-Test -Title "Directiva POL_SEARCH_BING_ENABLED_HKCU presente en SSOT" `
    -Condition ($null -ne $hasBingPol -and $hasBingPol.ExpectedValue -eq 0) `
    -Details "ValueName: $($hasBingPol.ValueName)"

# Verificación de Export-RomanOSUnattendCommands
$unattendExport = Export-RomanOSUnattendCommands -Profile 1
$xmlHasDemand = ($unattendExport.XmlContent -match "WSAIFabricSvc start= demand" -and $unattendExport.XmlContent -match "MaintenanceDisabled")
Assert-Test -Title "Export-RomanOSUnattendCommands exporta servicios a demanda y MaintenanceDisabled" `
    -Condition $xmlHasDemand `
    -Details "Unattend XML contiene comandos sc.exe y reg add"

# -----------------------------------------------------------------------------
# BLOQUE 3: EJECUCIÓN SIMULADA Y PARIDAD DEL ECOSISTEMA
# -----------------------------------------------------------------------------
Write-Host "`n>>> [3/3] Verificando Ejecucion Simulada (-WhatIf) y Ecosistema..." -ForegroundColor Cyan

# Status en frío
$statusResult = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $startupPs1 -Action Status 2>&1
$statusOk = ($LASTEXITCODE -eq 0 -and ($statusResult -match "RESUMEN" -or $statusResult -match "Ahorro Potencial"))
Assert-Test -Title "Ejecucion en frio -Action Status ejecuta limpiamente en PS 5.1" `
    -Condition $statusOk `
    -Details "Status exitoso"

# Optimize simulado (-WhatIf)
$whatIfResult = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $startupPs1 -Action Optimize -WhatIf -SkipSnapshot 2>&1
$whatIfOk = ($LASTEXITCODE -eq 0 -and ($whatIfResult -match "WhatIf" -or $whatIfResult -match "Se está realizando"))
Assert-Test -Title "Modo simulado -WhatIf en -Action Optimize ejecuta limpiamente sin modificar host" `
    -Condition $whatIfOk `
    -Details "Optimize WhatIf exitoso"

# Integración en Control Center GUI
$ccPath = Join-Path $repoRoot "scripts\GUI\romanOS-ControlCenter.ps1"
$ccContent = if (Test-Path $ccPath) { Get-Content $ccPath -Raw } else { "" }
$hasCC = ($ccContent -match "btnAuditStartupGUI" -and $ccContent -match "btnOptimizeStartupGUI" -and $ccContent -match "Optimize-StartupEcosystem\.ps1")
Assert-Test -Title "Integracion y paridad en romanOS-ControlCenter.ps1 (XAML y Event Handlers)" `
    -Condition $hasCC `
    -Details "Control Center Integration: $hasCC"

# Integración en Toolkit Maestro
$toolkitPath = Join-Path $repoRoot "scripts\Modules\romanOS-Toolkit.ps1"
$toolkitContent = if (Test-Path $toolkitPath) { Get-Content $toolkitPath -Raw } else { "" }
$hasToolkit = ($toolkitContent -match "Invoke-StartupEcosystemModule" -and $toolkitContent -match "Optimize-StartupEcosystem\.ps1")
Assert-Test -Title "Integracion y paridad en romanOS-Toolkit.ps1 (CLI y Menu Opcion 24)" `
    -Condition $hasToolkit `
    -Details "Toolkit Integration: $hasToolkit"

# Integración en Debloat Adaptativo
$debloatPath = Join-Path $repoRoot "scripts\Modules\Win11-Debloat-v3-Adaptive.ps1"
$debloatContent = if (Test-Path $debloatPath) { Get-Content $debloatPath -Raw } else { "" }
$hasDebloat = ($debloatContent -match "Get-RomanOSDemandServices" -and $debloatContent -match "MaintenanceDisabled")
Assert-Test -Title "Integracion y paridad en Win11-Debloat-v3-Adaptive.ps1" `
    -Condition $hasDebloat `
    -Details "Debloat Integration: $hasDebloat"

# Integración en Builder ISO (OEM y WIM)
$builderPath = Join-Path $repoRoot "scripts\Builder\New-OptimizedWindowsISO-v2.ps1"
$builderContent = if (Test-Path $builderPath) { Get-Content $builderPath -Raw } else { "" }
$hasBuilder = ($builderContent -match "Optimize-StartupEcosystem\.ps1" -and $builderContent -match "Optimize-StartupEcosystem\.cmd")
Assert-Test -Title "Integracion e inyeccion fisica en New-OptimizedWindowsISO-v2.ps1 (OEM y WIM)" `
    -Condition $hasBuilder `
    -Details "Builder Injection: $hasBuilder"

# -----------------------------------------------------------------------------
# RESUMEN DE PRUEBAS
# -----------------------------------------------------------------------------
$duration = [math]::Round(((Get-Date) - $testStart).TotalSeconds, 2)
$totalTests = $passCount + $failCount
$overallPass = ($failCount -eq 0)

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN: PRUEBAS DE GOBERNANZA DE INICIO Y SERVICIOS A DEMANDA          " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Total de Aserciones : $totalTests"
Write-Host " Aprobadas (PASS)    : $passCount" -ForegroundColor Green
Write-Host " Fallidas (FAIL)     : $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host " Duracion Total      : ${duration}s"
Write-Host " Estado Global       : $(if ($overallPass) { 'PASS (100% Exitoso)' } else { 'FAIL' })" -ForegroundColor $(if ($overallPass) { "Green" } else { "Red" })
Write-Host "==========================================================================`n" -ForegroundColor Cyan

exit $(if ($overallPass) { 0 } else { 1 })
