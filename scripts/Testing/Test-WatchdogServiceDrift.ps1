<#
.SYNOPSIS
    Test-WatchdogServiceDrift.ps1 - Arnés de Pruebas Unitarias del Guardián Anti-Drift
    Certificación de Auditoría, Remediación y Validación en PowerShell 5.1

.DESCRIPTION
    Ejecuta una batería de aserciones unitarias para verificar:
      1. Existencia física y codificación conforme a la Regla 4 (UTF-8 BOM en PS1, No-BOM en CMD).
      2. Parser AST de Windows PowerShell 5.1 sin errores sintácticos.
      3. Telemetría de 8 servicios críticos degradadores y su estado.
      4. Telemetría de 8 tareas programadas de telemetría de Windows.
      5. Cálculo de métricas cuantitativas y porcentaje de paridad anti-drift.
      6. Ejecución simulada (-WhatIf) para remediación y registro de tarea watchdog.
      7. Integración y sincronización en Toolkit, Control Center y New-OptimizedWindowsISO-v2.ps1.
#>

[CmdletBinding()]
param(
    [string]$LogDir = ""
)

$ErrorActionPreference = 'Continue'
$testStart = Get-Date

$repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
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
Write-Host " romanOS — BATERIA DE PRUEBAS: GUARDIAN ANTI-DRIFT Y WATCHDOG              " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Runtime: Windows PowerShell $($PSVersionTable.PSVersion)`n" -ForegroundColor Gray

# -----------------------------------------------------------------------------
# BLOQUE 1: ARCHIVOS Y ENCODING
# -----------------------------------------------------------------------------
Write-Host ">>> [1/3] Verificando Archivos y Codificacion de Encodings..." -ForegroundColor Cyan

$watchdogPs1 = Join-Path $repoRoot "scripts\Modules\Watchdog-ServiceDrift.ps1"
$watchdogCmd = Join-Path $repoRoot "scripts\Modules\Watchdog-ServiceDrift.cmd"

Assert-Test -Title "Existencia fisica de Watchdog-ServiceDrift.ps1" `
    -Condition (Test-Path $watchdogPs1) `
    -Details $watchdogPs1

Assert-Test -Title "Existencia fisica de Watchdog-ServiceDrift.cmd" `
    -Condition (Test-Path $watchdogCmd) `
    -Details $watchdogCmd

$ps1Bytes = if (Test-Path $watchdogPs1) { [System.IO.File]::ReadAllBytes($watchdogPs1) } else { @() }
$hasBOM = ($ps1Bytes.Count -ge 3 -and $ps1Bytes[0] -eq 0xEF -and $ps1Bytes[1] -eq 0xBB -and $ps1Bytes[2] -eq 0xBF)
Assert-Test -Title "Watchdog-ServiceDrift.ps1 codificado en UTF-8 con BOM (Regla 4)" `
    -Condition $hasBOM `
    -Details "Primeros bytes: 0x{0:X2}-{1:X2}-{2:X2}" -f $ps1Bytes[0], $ps1Bytes[1], $ps1Bytes[2]

$cmdBytes = if (Test-Path $watchdogCmd) { [System.IO.File]::ReadAllBytes($watchdogCmd) } else { @() }
$cmdHasBOM = ($cmdBytes.Count -ge 3 -and $cmdBytes[0] -eq 0xEF -and $cmdBytes[1] -eq 0xBB -and $cmdBytes[2] -eq 0xBF)
Assert-Test -Title "Watchdog-ServiceDrift.cmd es estrictamente No-BOM (Regla 4)" `
    -Condition (-not $cmdHasBOM) `
    -Details "cmdHasBOM: $cmdHasBOM"

$astErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($watchdogPs1, [ref]$null, [ref]$astErrors)
Assert-Test -Title "Parser AST de Windows PowerShell 5.1 sin errores sintacticos" `
    -Condition ($null -eq $astErrors -or $astErrors.Count -eq 0) `
    -Details "Errores detectados: $(if ($astErrors) { $astErrors.Count } else { 0 })"

# -----------------------------------------------------------------------------
# BLOQUE 2: TELEMETRIA DE SERVICIOS, TAREAS Y CALCULO DE PARIDAD
# -----------------------------------------------------------------------------
Write-Host "`n>>> [2/3] Verificando Telemetría de Servicios, Tareas y Paridad Anti-Drift..." -ForegroundColor Cyan

# Carga en frío del script para invocar funciones internas
. $watchdogPs1 -SkipElevation

$svcTelemetry = Get-RomanOSServiceDriftReport -Scope "Services"
Assert-Test -Title "Telemetria de Servicios evalua los 8 servicios criticos de directiva" `
    -Condition ($svcTelemetry -ne $null -and $svcTelemetry.TotalEvaluated -eq 8) `
    -Details "Servicios evaluados: $($svcTelemetry.TotalEvaluated) (DiagTrack, WerSvc, dmwappushservice...)"

$taskTelemetry = Get-RomanOSServiceDriftReport -Scope "ScheduledTasks"
Assert-Test -Title "Telemetria de Tareas evalua las 8 tareas programadas de telemetria" `
    -Condition ($taskTelemetry -ne $null -and $taskTelemetry.TotalEvaluated -eq 8) `
    -Details "Tareas evaluadas: $($taskTelemetry.TotalEvaluated) (Appraiser, CEIP, Consolidator...)"

$allTelemetry = Get-RomanOSServiceDriftReport -Scope "All"
$parityPct = if ($allTelemetry) { $allTelemetry.ParityPercent } else { -1 }

Assert-Test -Title "Calculo cuantitativo de paridad anti-drift valido (0-100%)" `
    -Condition ($parityPct -ge 0 -and $parityPct -le 100) `
    -Details "Paridad calculada: $parityPct% (Total evaluados: $($allTelemetry.TotalEvaluated), Desviados: $($allTelemetry.DriftedCount))"

# -----------------------------------------------------------------------------
# BLOQUE 3: SIMULACION -WHATIF Y PARIDAD EN ECOSISTEMA (TOOLKIT, GUI, BUILDER)
# -----------------------------------------------------------------------------
Write-Host "`n>>> [3/3] Verificando Ejecucion Simulada (-WhatIf) y Ecosistema..." -ForegroundColor Cyan

$whatIfRemediate = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $watchdogPs1 -Action Remediate -WhatIf 2>&1
$remediateOk = ($LASTEXITCODE -eq 0 -and ($whatIfRemediate -match "WhatIf" -or $whatIfRemediate -match "simuló" -or $whatIfRemediate -match "Se está realizando"))
Assert-Test -Title "Modo simulado -WhatIf en -Action Remediate ejecuta limpiamente" `
    -Condition $remediateOk `
    -Details "Remediate WhatIf exitoso"

$whatIfInstall = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $watchdogPs1 -Action InstallTask -WhatIf 2>&1
$installOk = ($LASTEXITCODE -eq 0 -and ($whatIfInstall -match "WhatIf" -or $whatIfInstall -match "simuló" -or $whatIfInstall -match "Se está realizando"))
Assert-Test -Title "Modo simulado -WhatIf en -Action InstallTask ejecuta limpiamente" `
    -Condition $installOk `
    -Details "InstallTask WhatIf exitoso"

# Integracion en Toolkit
$toolkitPath = Join-Path $repoRoot "scripts\Modules\romanOS-Toolkit.ps1"
$toolkitContent = if (Test-Path $toolkitPath) { [System.IO.File]::ReadAllText($toolkitPath) } else { "" }
$hasToolkitWatchdog = ($toolkitContent -match "Invoke-WatchdogModule" -and $toolkitContent -match "Watchdog-ServiceDrift")
Assert-Test -Title "Integracion y paridad en romanOS-Toolkit.ps1 (CLI y QuickAction 22)" `
    -Condition $hasToolkitWatchdog `
    -Details "Toolkit Integration: $hasToolkitWatchdog"

# Integracion en Control Center
$ccPath = Join-Path $repoRoot "scripts\GUI\romanOS-ControlCenter.ps1"
$ccContent = if (Test-Path $ccPath) { [System.IO.File]::ReadAllText($ccPath) } else { "" }
$hasCCWatchdog = ($ccContent -match "btnAuditDriftGUI" -and $ccContent -match "btnRemediateDriftGUI" -and $ccContent -match "Watchdog-ServiceDrift\.ps1")
Assert-Test -Title "Integracion y paridad en romanOS-ControlCenter.ps1 (XAML y Event Handlers)" `
    -Condition $hasCCWatchdog `
    -Details "Control Center Integration: $hasCCWatchdog"

# Integracion en Builder ISO
$builderPath = Join-Path $repoRoot "scripts\Builder\New-OptimizedWindowsISO-v2.ps1"
$builderContent = if (Test-Path $builderPath) { [System.IO.File]::ReadAllText($builderPath) } else { "" }
$hasBuilderWatchdog = ($builderContent -match "Watchdog-ServiceDrift\.ps1" -and $builderContent -match "Watchdog-ServiceDrift\.cmd")
Assert-Test -Title "Integracion e inyeccion fisica en New-OptimizedWindowsISO-v2.ps1 (OEM y WIM)" `
    -Condition $hasBuilderWatchdog `
    -Details "Builder Injection: $hasBuilderWatchdog"

# -----------------------------------------------------------------------------
# RESUMEN DE PRUEBAS
# -----------------------------------------------------------------------------
$duration = [math]::Round(((Get-Date) - $testStart).TotalSeconds, 2)
$totalTests = $passCount + $failCount
$overallPass = ($failCount -eq 0)

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN: PRUEBAS DE GUARDIAN ANTI-DRIFT Y WATCHDOG                       " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Total de Aserciones : $totalTests"
Write-Host " Aprobadas (PASS)    : $passCount" -ForegroundColor Green
Write-Host " Fallidas (FAIL)     : $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host " Duracion Total      : ${duration}s"
Write-Host " Estado Global       : $(if ($overallPass) { 'PASS (100% Exitoso)' } else { 'FAIL' })" -ForegroundColor $(if ($overallPass) { "Green" } else { "Red" })
Write-Host "==========================================================================`n" -ForegroundColor Cyan

exit $(if ($overallPass) { 0 } else { 1 })
