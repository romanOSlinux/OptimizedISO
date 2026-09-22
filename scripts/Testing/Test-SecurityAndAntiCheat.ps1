<#
.SYNOPSIS
    Test-SecurityAndAntiCheat.ps1 - Suite Unificada de Seguridad, Anti-Cheats y Cadena de Suministro
    romanOS / OptimizedISO — Validación Integral de Ciberseguridad (PLAN-0096)

.DESCRIPTION
    Ejecuta las pruebas de certificación de:
      1. Compatibilidad con motores anti-cheat a nivel Ring-0 (Vanguard, EAC, BattlEye, Ricochet, FACEIT).
      2. Integridad de la cadena de suministro de binarios y firmas Authenticode SHA-256.
      3. Resiliencia arquitectónica de registro contra sobreescrituras OOBE (Hive Drift).
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$testStart = Get-Date

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS / OptimizedISO — BATERIA DE CIBERSEGURIDAD Y COMPATIBILIDAD 2026 " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host ""

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $repoRoot ".agents"))) {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    if (-not (Test-Path (Join-Path $repoRoot ".agents"))) {
        $repoRoot = "C:\OptimizedISO"
    }
}

$coreDir = Join-Path $repoRoot "scripts\Core"
$antiCheatScript = Join-Path $coreDir "Test-AntiCheatCompatibility.ps1"
$supplyChainScript = Join-Path $coreDir "Test-SupplyChainIntegrity.ps1"
$hiveDriftScript = Join-Path $coreDir "Test-RegistryHiveDrift.ps1"

$allPassed = $true
$assertionsPassed = 0
$assertionsFailed = 0

# -----------------------------------------------------------------------------
# 1. PRUEBA: COMPATIBILIDAD CON ANTI-CHEATS
# -----------------------------------------------------------------------------
Write-Host ">>> [1/3] Verificando Compatibilidad con Anti-Cheats de Kernel..." -ForegroundColor Cyan
if (Test-Path $antiCheatScript) {
    try {
        $acResult = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $antiCheatScript -AuditMode Comprehensive
        if ($LASTEXITCODE -eq 0) {
            $assertionsPassed += 5
            Write-Host "  [PASS] 5/5 Motores Anti-Cheat son 100% compatibles." -ForegroundColor Green
        } else {
            $assertionsFailed++
            $allPassed = $false
            Write-Host "  [FAIL] Se detectaron incompatibilidades en motores anti-cheat." -ForegroundColor Red
        }
    } catch {
        $assertionsFailed++
        $allPassed = $false
        Write-Warning "Fallo al ejecutar auditoría anti-cheat: $($_.Exception.Message)"
    }
} else {
    $assertionsFailed++
    $allPassed = $false
    Write-Host "  [FAIL] Script anti-cheat no encontrado: $antiCheatScript" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# 2. PRUEBA: CADENA DE SUMINISTRO Y CATÁLOGO DE INTEGRIDAD
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> [2/3] Verificando Cadena de Suministro y Catálogo SHA-256..." -ForegroundColor Cyan
if (Test-Path $supplyChainScript) {
    try {
        $scResult = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $supplyChainScript -VerifyCatalog
        if ($LASTEXITCODE -eq 0) {
            $assertionsPassed += 2
            Write-Host "  [PASS] Catálogo de integridad verificado: Cero binarios alterados." -ForegroundColor Green
            Write-Host "  [PASS] Firmas Authenticode auditadas y conformes." -ForegroundColor Green
        } else {
            $assertionsFailed++
            $allPassed = $false
            Write-Host "  [FAIL] Se detectaron discrepancias en la cadena de suministro." -ForegroundColor Red
        }
    } catch {
        $assertionsFailed++
        $allPassed = $false
        Write-Warning "Fallo al ejecutar auditoría de cadena de suministro: $($_.Exception.Message)"
    }
} else {
    $assertionsFailed++
    $allPassed = $false
    Write-Host "  [FAIL] Script de cadena de suministro no encontrado: $supplyChainScript" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# 3. PRUEBA: RESILIENCIA DE REGISTRO (HIVE DRIFT)
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> [3/3] Verificando Resiliencia Arquitectónica de Registro (Drift)..." -ForegroundColor Cyan
if (Test-Path $hiveDriftScript) {
    try {
        $driftResult = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $hiveDriftScript -ProfileId 1
        if ($LASTEXITCODE -eq 0) {
            $assertionsPassed += 2
            Write-Host "  [PASS] Más del 80% de directivas blindadas bajo ramas GPO / Kernel." -ForegroundColor Green
            Write-Host "  [PASS] Directivas volátiles mapeadas para doble inyección en Default User." -ForegroundColor Green
        } else {
            $assertionsFailed++
            $allPassed = $false
            Write-Host "  [FAIL] Falló el análisis de resiliencia de registro." -ForegroundColor Red
        }
    } catch {
        $assertionsFailed++
        $allPassed = $false
        Write-Warning "Fallo al ejecutar auditoría de drift: $($_.Exception.Message)"
    }
} else {
    $assertionsFailed++
    $allPassed = $false
    Write-Host "  [FAIL] Script de drift no encontrado: $hiveDriftScript" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# EVALUACIÓN FINAL
# -----------------------------------------------------------------------------
$totalDuration = [math]::Round(((Get-Date) - $testStart).TotalSeconds, 2)
Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN: PRUEBAS DE SEGURIDAD Y ANTI-CHEAT " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Aserciones Superadas : $assertionsPassed" -ForegroundColor Green
Write-Host " Aserciones Fallidas  : $assertionsFailed" -ForegroundColor $(if ($assertionsFailed -eq 0) { 'Green' } else { 'Red' })
Write-Host " Duración Total       : ${totalDuration}s" -ForegroundColor DarkGray
Write-Host " Estado Global        : $(if ($allPassed) { 'PASS (100% Exitoso)' } else { 'FAIL' })" -ForegroundColor $(if ($allPassed) { 'Green' } else { 'Red' })
Write-Host ""

exit $(if ($allPassed) { 0 } else { 1 })
