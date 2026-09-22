<#
.SYNOPSIS
    Test-ThermalEnergyMonitor.ps1 - Arnés de Pruebas Unitarias para romanOS Thermal & Energy Profiler
    romanOS / OptimizedISO — Estado del Arte Windows 11 24H2 / 25H2

.DESCRIPTION
    Suite automatizada de pruebas unitarias para certificar la integridad estructural,
    codificación UTF-8 con BOM, parser en Windows PowerShell 5.1, introspección
    térmica y de frecuencia de CPU, y modo simulado (-WhatIf) de calibración energética.

.EXAMPLE
    .\Test-ThermalEnergyMonitor.ps1
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Quick
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS — BATERIA DE PRUEBAS: THERMAL & ENERGY PROFILER                   " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Runtime: Windows PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
Write-Host ""

$testStartTime = Get-Date
$passCount = 0
$failCount = 0

function Assert-Test {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$Details = ""
    )
    if ($Condition) {
        $script:passCount++
        Write-Host "  [PASS] $TestName" -ForegroundColor Green
        if ($Details) { Write-Host "         $Details" -ForegroundColor DarkGray }
    } else {
        $script:failCount++
        Write-Host "  [FAIL] $TestName" -ForegroundColor Red
        if ($Details) { Write-Host "         Detalle: $Details" -ForegroundColor Yellow }
    }
}

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $repoRoot "scripts"))) {
    $repoRoot = "C:\OptimizedISO"
}

$scriptPath = Join-Path $repoRoot "scripts\Modules\Monitor-ThermalEnergy.ps1"
$cmdPath    = Join-Path $repoRoot "scripts\Modules\Monitor-ThermalEnergy.cmd"

# -----------------------------------------------------------------------------
# 1. INTEGRIDAD DE ARCHIVOS Y CODIFICACION ESTRICTA (REGLA 4)
# -----------------------------------------------------------------------------
Write-Host ">>> [1/3] Verificando Archivos y Codificacion de Encodings..." -ForegroundColor Yellow

Assert-Test -TestName "Existencia fisica de Monitor-ThermalEnergy.ps1" `
            -Condition (Test-Path $scriptPath) `
            -Details $scriptPath

Assert-Test -TestName "Existencia fisica de Monitor-ThermalEnergy.cmd" `
            -Condition (Test-Path $cmdPath) `
            -Details $cmdPath

# Validar BOM en Monitor-ThermalEnergy.ps1
$ps1Bytes = [System.IO.File]::ReadAllBytes($scriptPath)
$hasBOM = ($ps1Bytes.Length -ge 3 -and $ps1Bytes[0] -eq 0xEF -and $ps1Bytes[1] -eq 0xBB -and $ps1Bytes[2] -eq 0xBF)
Assert-Test -TestName "Monitor-ThermalEnergy.ps1 codificado en UTF-8 con BOM (Regla 4)" `
            -Condition $hasBOM `
            -Details "Primeros bytes: 0x{0:X2}-{1:X2}-{2:X2}" -f $ps1Bytes[0], $ps1Bytes[1], $ps1Bytes[2]

# Validar NO BOM en Monitor-ThermalEnergy.cmd
$cmdBytes = [System.IO.File]::ReadAllBytes($cmdPath)
$cmdHasBOM = ($cmdBytes.Length -ge 3 -and $cmdBytes[0] -eq 0xEF -and $cmdBytes[1] -eq 0xBB -and $cmdBytes[2] -eq 0xBF)
Assert-Test -TestName "Monitor-ThermalEnergy.cmd es estrictamente No-BOM (Regla 4)" `
            -Condition (-not $cmdHasBOM) `
            -Details "cmdHasBOM: $cmdHasBOM"

# Validar Parser AST en Windows PowerShell 5.1
$astErrors = @()
$null = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$astErrors)
Assert-Test -TestName "Parser AST de Windows PowerShell 5.1 sin errores sintacticos" `
            -Condition ($astErrors.Count -eq 0) `
            -Details "Errores detectados: $($astErrors.Count)"

# -----------------------------------------------------------------------------
# 2. INTROSPECCION TERMICA, CPU Y PLAN DE ENERGIA
# -----------------------------------------------------------------------------
Write-Host "`n>>> [2/3] Verificando Telemetria de CPU, Rendimiento y Sensores..." -ForegroundColor Yellow

$cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
$hasCpuInfo = ($cpu -and $cpu.CurrentClockSpeed -gt 0 -and $cpu.MaxClockSpeed -gt 0)
Assert-Test -TestName "Introspeccion de frecuencia de CPU (CurrentClockSpeed / MaxClockSpeed) exitosa" `
            -Condition ([bool]$hasCpuInfo) `
            -Details "CPU: $($cpu.Name) | Reloj: $($cpu.CurrentClockSpeed) MHz / $($cpu.MaxClockSpeed) MHz"

$perf = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor | Where-Object { $_.Name -eq '_Total' } | Select-Object -First 1
Assert-Test -TestName "Telemetria de carga de procesador (PerfOS_Processor) disponible" `
            -Condition ($perf -ne $null -and $perf.PercentProcessorTime -ge 0) `
            -Details "Carga CPU Total: $($perf.PercentProcessorTime)%"

$activeScheme = & powercfg /getactivescheme
$hasActiveScheme = ($LASTEXITCODE -eq 0 -and $activeScheme -match '[a-f0-9]{8}-[a-f0-9]{4}')
Assert-Test -TestName "Subsistema de energia Win32 (powercfg) accesible y devuelve esquema activo" `
            -Condition $hasActiveScheme `
            -Details "Salida: $($activeScheme -join ' ')"

# -----------------------------------------------------------------------------
# 3. EJECUCION DE ACCIONES, SIMULACION Y MUESTREO EN VIVO
# -----------------------------------------------------------------------------
Write-Host "`n>>> [3/3] Verificando Ejecucion de Acciones (-Action Status, Audit, Monitor, WhatIf)..." -ForegroundColor Yellow

$psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

# Prueba 1: Action Status
$statusOut = & $psExe -STA -NoProfile -ExecutionPolicy Bypass -Command "& '$scriptPath' -Action Status -SkipElevation" 2>&1
$statusText = $statusOut | Out-String
$isStatusPass = ($LASTEXITCODE -eq 0 -and $statusText -match "ESTADO THROTTLING")
Assert-Test -TestName "Accion -Action Status ejecuta limpiamente y reporta estado de estrangulamiento" `
            -Condition $isStatusPass `
            -Details "Salida detecto encabezado de diagnostico"

# Prueba 2: Action Audit
$auditOut = & $psExe -STA -NoProfile -ExecutionPolicy Bypass -Command "& '$scriptPath' -Action Audit -SkipElevation" 2>&1
$auditText = $auditOut | Out-String
$isAuditPass = ($LASTEXITCODE -eq 0 -and $auditText -match "\[AUDITORIA\]")
Assert-Test -TestName "Accion -Action Audit emite resumen forense en una sola linea" `
            -Condition $isAuditPass `
            -Details "Reporte forense detectado en salida"

# Prueba 3: Action CalibrateEnergy en modo -WhatIf
$whatIfOut = & $psExe -STA -NoProfile -ExecutionPolicy Bypass -Command "& '$scriptPath' -Action CalibrateEnergy -EnergyProfile Ultimate -WhatIf -SkipElevation" 2>&1
$whatIfText = $whatIfOut | Out-String
$isWhatIfPass = ($LASTEXITCODE -eq 0 -and $whatIfText -match "Whatif:")
Assert-Test -TestName "Accion -Action CalibrateEnergy con -WhatIf simula la asignacion de plan" `
            -Condition $isWhatIfPass `
            -Details "Operacion simulada confirmada por ShouldProcess"

# Prueba 4: Action Monitor en vivo (muestreo a 1 Hz durante 2 segundos)
$monOut = & $psExe -STA -NoProfile -ExecutionPolicy Bypass -Command "& '$scriptPath' -Action Monitor -SampleDurationSec 2 -SkipElevation" 2>&1
$monText = $monOut | Out-String
$isMonPass = ($LASTEXITCODE -eq 0 -and $monText -match "Monitorizacion en vivo finalizada")
Assert-Test -TestName "Accion -Action Monitor completa ciclo de muestreo dinamico en tiempo real" `
            -Condition $isMonPass `
            -Details "Muestreo en vivo completado satisfactoriamente"

# -----------------------------------------------------------------------------
# RESUMEN DE RESULTADOS
# -----------------------------------------------------------------------------
$testDuration = [math]::Round(((Get-Date) - $testStartTime).TotalSeconds, 2)

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN: PRUEBAS DE THERMAL & ENERGY PROFILER                            " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Total de Aserciones : $($passCount + $failCount)" -ForegroundColor Gray
Write-Host " Aprobadas (PASS)    : $passCount" -ForegroundColor Green
Write-Host " Fallidas (FAIL)     : $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
Write-Host " Duracion Total      : ${testDuration}s" -ForegroundColor Gray
Write-Host " Estado Global       : $(if ($failCount -eq 0) { 'PASS (100% Exitoso)' } else { 'FAIL' })" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host "==========================================================================" -ForegroundColor Cyan

if ($failCount -gt 0) {
    exit 1
}
exit 0
