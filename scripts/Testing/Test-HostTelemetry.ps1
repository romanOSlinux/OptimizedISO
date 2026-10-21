# Test-HostTelemetry.ps1
# ==============================================================================
# Suite de Pruebas Unitarias para Get-HostTelemetry.ps1 (Regla 21)
# ==============================================================================
# Codificación: UTF-8 con BOM | Runtime: Windows PowerShell 5.1 / PowerShell 7+
# ==============================================================================

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$testScript = Join-Path $PSScriptRoot "..\Core\Get-HostTelemetry.ps1"
$totalTests = 0
$passedTests = 0

function Assert-Test {
    param(
        [string]$Description,
        [scriptblock]$Condition
    )
    $script:totalTests++
    try {
        $result = & $Condition
        if ($result) {
            $script:passedTests++
            Write-Host "  [PASS] $Description" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] $Description" -ForegroundColor Red
        }
    } catch {
        Write-Host "  [FAIL] $Description - Exception: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   TEST SUITE: Get-HostTelemetry.ps1 (SSOT Host Identity)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Existencia y Sintaxis
Assert-Test "Get-HostTelemetry.ps1 existe en scripts/Core/" {
    Test-Path $testScript
}

Assert-Test "Codificacion es UTF-8 con BOM" {
    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $testScript))
    return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
}

# 2. Ejecución y Propiedades Obligatorias (Regla 21.3)
$telemetry = & $testScript -Quiet

Assert-Test "Retorna objeto tipado no nulo" {
    $null -ne $telemetry
}

Assert-Test "Caption esta presente y no esta vacio" {
    -not [string]::IsNullOrWhiteSpace($telemetry.Caption)
}

Assert-Test "EditionID esta presente y no esta vacio" {
    -not [string]::IsNullOrWhiteSpace($telemetry.EditionID)
}

Assert-Test "DisplayVersion esta presente (ej. 24H2, 26H2)" {
    -not [string]::IsNullOrWhiteSpace($telemetry.DisplayVersion)
}

Assert-Test "CurrentBuild es numerico entero mayor a 10000" {
    $telemetry.CurrentBuild -is [int] -and $telemetry.CurrentBuild -gt 10000
}

Assert-Test "UBR es numerico entero no negativo" {
    $telemetry.UBR -is [int] -and $telemetry.UBR -ge 0
}

Assert-Test "FullBuild tiene formato <Build>.<UBR>" {
    $telemetry.FullBuild -match '^\d+\.\d+$'
}

Assert-Test "Architecture esta definida (64 bits / 32 bits / ARM64)" {
    -not [string]::IsNullOrWhiteSpace($telemetry.Architecture)
}

Assert-Test "TotalVisibleRAM y FreePhysicalRAM son valores positivos" {
    $telemetry.TotalVisibleRAM -gt 0 -and $telemetry.FreePhysicalRAM -gt 0
}

# 3. Formato JSON
$jsonOut = & $testScript -AsJson
Assert-Test "Parametro -AsJson retorna string JSON valido convertible" {
    $parsed = $jsonOut | ConvertFrom-Json
    return ($null -ne $parsed -and $parsed.CurrentBuild -gt 10000)
}

Write-Host "`nResultado: $passedTests / $totalTests aserciones aprobadas." -ForegroundColor Yellow
if ($passedTests -ne $totalTests) {
    exit 1
}
exit 0
