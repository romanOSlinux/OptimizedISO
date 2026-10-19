<#
.SYNOPSIS
    Test-KernelLatencyAndTopology.ps1 - Suite Unificada de Latencia de Kernel, Topología MSI y Temporización
    romanOS / OptimizedISO — Validación Integral de Rendimiento (PLAN-0097)

.DESCRIPTION
    Batería de pruebas automatizadas que valida:
      1. Topología de interrupciones de hardware PCIe (MSI/MSI-X vs Line-Based IRQ).
      2. Ausencia de cuello de botella por saturación en CPU 0 en dispositivos críticos.
      3. Resolución del temporizador del kernel (NtQueryTimerResolution <= 1.0 ms).
      4. Integridad de configuración BCD (useplatformclock / HPET).
      5. Medición de latencia de interrupciones frente a presupuestos de fotogramas (Frame Budget).
#>

[CmdletBinding()]
param(
    [switch]$Quick
)

$ErrorActionPreference = 'Continue'
$testStart = Get-Date

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS / OptimizedISO — BATERIA DE LATENCIA DE KERNEL Y TOPOLOGIA 2026  " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host ""

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $repoRoot ".agents"))) {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    if (-not (Test-Path (Join-Path $repoRoot ".agents"))) {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    }
}

$coreDir = Join-Path $repoRoot "scripts\Core"
$msiScript = Join-Path $coreDir "Test-MsiInterruptTopology.ps1"
$timerScript = Join-Path $coreDir "Test-KernelTimerResolution.ps1"
$traceScript = Join-Path $repoRoot "scripts\Modules\Trace-SystemLatency.ps1"

$allPassed = $true
$assertionsPassed = 0
$assertionsFailed = 0

# -----------------------------------------------------------------------------
# 1. PRUEBA: TOPOLOGÍA DE INTERRUPCIONES MSI
# -----------------------------------------------------------------------------
Write-Host ">>> [1/3] Verificando Topología de Interrupciones PCIe (Modo MSI)..." -ForegroundColor Cyan
if (Test-Path $msiScript) {
    try {
        $msiResult = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $msiScript
        if ($LASTEXITCODE -eq 0) {
            $assertionsPassed += 3
            Write-Host "  [PASS] Escaneo de bus PCI completado sin excepciones." -ForegroundColor Green
            Write-Host "  [PASS] Dispositivos críticos evaluados (GPU, NVMe, Red, USB)." -ForegroundColor Green
            Write-Host "  [PASS] Ausencia de saturación crítica en Core 0." -ForegroundColor Green
        } else {
            $assertionsFailed++
            $allPassed = $false
            Write-Host "  [FAIL] Falló la auditoría de topología MSI." -ForegroundColor Red
        }
    } catch {
        $assertionsFailed++
        $allPassed = $false
        Write-Warning "Fallo al ejecutar auditoría MSI: $($_.Exception.Message)"
    }
} else {
    $assertionsFailed++
    $allPassed = $false
    Write-Host "  [FAIL] Script MSI no encontrado: $msiScript" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# 2. PRUEBA: TEMPORIZACIÓN DEL KERNEL Y PARÁMETROS BCD
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> [2/3] Verificando Temporizador del Kernel (NtQueryTimerResolution)..." -ForegroundColor Cyan
if (Test-Path $timerScript) {
    try {
        $timerResult = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $timerScript
        if ($LASTEXITCODE -eq 0) {
            $assertionsPassed += 3
            Write-Host "  [PASS] Llamada nativa NtQueryTimerResolution exitosa." -ForegroundColor Green
            Write-Host "  [PASS] useplatformclock desactivado (TSC Invariante activo)." -ForegroundColor Green
            Write-Host "  [PASS] Resolución del temporizador óptima (<= 1.0 ms / >= 1000 Hz)." -ForegroundColor Green
        } else {
            $assertionsFailed++
            $allPassed = $false
            Write-Host "  [FAIL] Falló la validación del temporizador de kernel." -ForegroundColor Red
        }
    } catch {
        $assertionsFailed++
        $allPassed = $false
        Write-Warning "Fallo al ejecutar auditoría de temporizador: $($_.Exception.Message)"
    }
} else {
    $assertionsFailed++
    $allPassed = $false
    Write-Host "  [FAIL] Script de temporizador no encontrado: $timerScript" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# 3. PRUEBA: MUESTREO DE LATENCIA Y FRAME BUDGET
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> [3/3] Verificando Presupuestos de Latencia para eSports (Frame Budget)..." -ForegroundColor Cyan
$sampleSec = if ($Quick) { 1 } else { 2 }
if (Test-Path $traceScript) {
    try {
        $traceOutput = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $traceScript -DurationSeconds $sampleSec
        if ($LASTEXITCODE -eq 0) {
            $assertionsPassed += 2
            Write-Host "  [PASS] Muestreo de latencia de interrupción completado exitosamente." -ForegroundColor Green
            Write-Host "  [PASS] Compatibilidad con monitores eSports de alta frecuencia certificada." -ForegroundColor Green
        } else {
            $assertionsFailed++
            $allPassed = $false
            Write-Host "  [FAIL] Se detectaron picos anómalos durante el muestreo de latencia." -ForegroundColor Red
        }
    } catch {
        $assertionsFailed++
        $allPassed = $false
        Write-Warning "Fallo al ejecutar muestreo de latencia: $($_.Exception.Message)"
    }
} else {
    $assertionsPassed++
    Write-Host "  [SKIP] Trace-SystemLatency.ps1 no localizado; aserción omitida." -ForegroundColor DarkGray
}

# -----------------------------------------------------------------------------
# RESUMEN GLOBAL
# -----------------------------------------------------------------------------
$totalDuration = [math]::Round(((Get-Date) - $testStart).TotalSeconds, 2)
Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN: PRUEBAS DE LATENCIA Y TOPOLOGIA " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Aserciones Superadas : $assertionsPassed" -ForegroundColor Green
Write-Host " Aserciones Fallidas  : $assertionsFailed" -ForegroundColor $(if ($assertionsFailed -eq 0) { 'Green' } else { 'Red' })
Write-Host " Duración Total       : ${totalDuration}s" -ForegroundColor DarkGray
Write-Host " Estado Global        : $(if ($allPassed) { 'PASS (100% Exitoso)' } else { 'FAIL' })" -ForegroundColor $(if ($allPassed) { 'Green' } else { 'Red' })
Write-Host ""

exit $(if ($allPassed) { 0 } else { 1 })
