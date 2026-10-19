<#
.SYNOPSIS
    Test-StorageAndNetworkArchitecture.ps1 - Suite Unificada de Arquitectura de Almacenamiento,
    Red NDIS y Memoria Escalonada (PLAN-0098).
    romanOS / OptimizedISO — Validación Integral de Rendimiento 2026.

.DESCRIPTION
    Batería de pruebas automatizadas que valida:
      1. Subsistema de Almacenamiento, DirectStorage 1.2+, BypassIO y TRIM.
      2. Pila de Red NDIS 6.85+, Descargas UDP RSC (URO), TCP AutoTuning y RSS.
      3. Arquitectura de Memoria Escalonada (RAM Tiering, DisablePagingExecutive y MMAgent).
#>

[CmdletBinding()]
param(
    [switch]$Quick
)

$ErrorActionPreference = 'Continue'
$testStart = Get-Date

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS / OptimizedISO — BATERIA DE STORAGE, RED Y MEMORIA 2026 (RUPA)   " -ForegroundColor Cyan
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
$storageScript = Join-Path $coreDir "Test-StorageStackBypassIO.ps1"
$networkScript = Join-Path $coreDir "Test-NetworkOffloadsAndRSS.ps1"
$policyEnginePath = Join-Path $coreDir "Policy-Engine.ps1"
$hardwareEnginePath = Join-Path $coreDir "Hardware-Engine.ps1"

$allPassed = $true
$assertionsPassed = 0
$assertionsFailed = 0

# -----------------------------------------------------------------------------
# 1. PRUEBA: SUBSISTEMA DE ALMACENAMIENTO Y DIRECTSTORAGE
# -----------------------------------------------------------------------------
Write-Host ">>> [1/3] Verificando Subsistema de Almacenamiento, DirectStorage y BypassIO..." -ForegroundColor Cyan
if (Test-Path $storageScript) {
    try {
        $res = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $storageScript
        if ($LASTEXITCODE -eq 0) {
            $assertionsPassed += 3
            Write-Host "  [PASS] Catálogo SSOT de almacenamiento y registro NTFS certificados." -ForegroundColor Green
            Write-Host "  [PASS] Estado de TRIM en unidades de estado solido verificado." -ForegroundColor Green
            Write-Host "  [PASS] Telemetria de BypassIO y subsistema Dev Drive conformes." -ForegroundColor Green
        } else {
            $assertionsFailed++
            $allPassed = $false
            Write-Host "  [FAIL] Falló la auditoría del subsistema de almacenamiento." -ForegroundColor Red
        }
    } catch {
        $assertionsFailed++
        $allPassed = $false
        Write-Warning "Fallo al ejecutar auditoría de almacenamiento: $($_.Exception.Message)"
    }
} else {
    $assertionsFailed++
    $allPassed = $false
    Write-Host "  [FAIL] Script de almacenamiento no encontrado: $storageScript" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# 2. PRUEBA: RED NDIS Y DESCARGAS DE HARDWARE UDP RSC
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> [2/3] Verificando Pila de Red NDIS 6.85+, Descargas UDP RSC y Topología RSS..." -ForegroundColor Cyan
if (Test-Path $networkScript) {
    try {
        $res = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $networkScript
        if ($LASTEXITCODE -eq 0) {
            $assertionsPassed += 3
            Write-Host "  [PASS] Catálogo SSOT de directivas de red y TCP validado." -ForegroundColor Green
            Write-Host "  [PASS] Adaptadores de red físicos y propiedades NDIS inspeccionados." -ForegroundColor Green
            Write-Host "  [PASS] Descargas por hardware (UDP RSC/URO) y topología RSS certificadas." -ForegroundColor Green
        } else {
            $assertionsFailed++
            $allPassed = $false
            Write-Host "  [FAIL] Falló la auditoría de red NDIS." -ForegroundColor Red
        }
    } catch {
        $assertionsFailed++
        $allPassed = $false
        Write-Warning "Fallo al ejecutar auditoría de red: $($_.Exception.Message)"
    }
} else {
    $assertionsFailed++
    $allPassed = $false
    Write-Host "  [FAIL] Script de red no encontrado: $networkScript" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# 3. PRUEBA: ARQUITECTURA DE MEMORIA ESCALONADA (RAM TIERING)
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> [3/3] Verificando Arquitectura de Memoria Escalonada (RAM Tiering & MMAgent)..." -ForegroundColor Cyan
try {
    . $policyEnginePath
    . $hardwareEnginePath

    $tier = Get-RomanOSMemoryTier
    if ($tier -and $tier.Tier -in @('Low', 'Balanced', 'Enthusiast')) {
        $assertionsPassed++
        Write-Host "  [PASS] Clasificacion de nivel de RAM fisica: $($tier.Tier) ($($tier.TotalGiB) GiB)" -ForegroundColor Green
    } else {
        $assertionsFailed++
        $allPassed = $false
        Write-Host "  [FAIL] No se pudo clasificar el nivel de memoria RAM" -ForegroundColor Red
    }

    $memPolicies = Get-RomanOSMemoryPolicies
    if ($memPolicies.Count -ge 2) {
        $assertionsPassed++
        Write-Host "  [PASS] Directivas de memoria de kernel registradas en SSOT ($($memPolicies.Count) directivas)" -ForegroundColor Green
    } else {
        $assertionsFailed++
        $allPassed = $false
        Write-Host "  [FAIL] Menos de 2 directivas de memoria en SSOT" -ForegroundColor Red
    }

    # Validacion analitica de Apply-RomanOSTieredMemoryPolicy
    $testTierLow = Apply-RomanOSTieredMemoryPolicy -RamGigabytes 4.0 -WhatIf
    $testTierHigh = Apply-RomanOSTieredMemoryPolicy -RamGigabytes 32.0 -WhatIf
    if ($testTierLow.Tier -eq "Low" -and $testTierHigh.Tier -eq "Enthusiast") {
        $assertionsPassed++
        Write-Host "  [PASS] Escalonamiento adaptativo verificado analiticamente (Low vs Enthusiast)" -ForegroundColor Green
    } else {
        $assertionsFailed++
        $allPassed = $false
        Write-Host "  [FAIL] Falla en la lógica de escalonamiento de memoria" -ForegroundColor Red
    }
} catch {
    $assertionsFailed++
    $allPassed = $false
    Write-Warning "Fallo al validar arquitectura de memoria: $($_.Exception.Message)"
}

# -----------------------------------------------------------------------------
# RESUMEN FINAL
# -----------------------------------------------------------------------------
$elapsed = [math]::Round(((Get-Date) - $testStart).TotalSeconds, 2)
Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN: PRUEBAS DE STORAGE, RED Y MEMORIA (RUPA 2026)                   " -ForegroundColor White
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Aserciones Superadas : $assertionsPassed" -ForegroundColor Green
Write-Host " Aserciones Fallidas  : $assertionsFailed" -ForegroundColor $(if($assertionsFailed -gt 0){'Red'}else{'Gray'})
Write-Host " Duración Total       : ${elapsed}s" -ForegroundColor Gray
Write-Host " Estado Global        : $(if($allPassed){'PASS (100% Exitoso)'}else{'FAIL'})" -ForegroundColor $(if($allPassed){'Green'}else{'Red'})
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host ""

if ($allPassed) { exit 0 } else { exit 1 }