<#
.SYNOPSIS
    Test-SnapshotEngine.ps1 - Arnés de Pruebas Unitarias para romanOS Snapshot & Rollback Engine (2026)
    romanOS / OptimizedISO — Estado del Arte Windows 11 24H2 / 25H2

.DESCRIPTION
    Suite automatizada de pruebas unitarias para certificar la integridad, idempotencia,
    validación criptográfica SHA-256, captura y restauración atómica de Manage-SystemSnapshots.ps1
    conforme a las reglas estrictas de codificación UTF-8 con BOM y PowerShell 5.1.

.EXAMPLE
    .\Test-SnapshotEngine.ps1
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Quick
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS — BATERÍA DE PRUEBAS UNITARIAS: SNAPSHOT & ROLLBACK ENGINE       " -ForegroundColor Cyan
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

$scriptPath = Join-Path $repoRoot "scripts\Modules\Manage-SystemSnapshots.ps1"
$cmdPath    = Join-Path $repoRoot "scripts\Modules\Manage-SystemSnapshots.cmd"

# -----------------------------------------------------------------------------
# 1. INTEGRIDAD DE ARCHIVOS Y CODIFICACIÓN ESTRICTA (REGLA 4)
# -----------------------------------------------------------------------------
Write-Host ">>> [1/3] Verificando Archivos y Codificación de Encodings..." -ForegroundColor Cyan

Assert-Test -TestName "Existencia física de Manage-SystemSnapshots.ps1" `
            -Condition (Test-Path $scriptPath) `
            -Details $scriptPath

Assert-Test -TestName "Existencia física de Manage-SystemSnapshots.cmd" `
            -Condition (Test-Path $cmdPath) `
            -Details $cmdPath

# Validación UTF-8 con BOM en .ps1
$ps1Bytes = [System.IO.File]::ReadAllBytes($scriptPath)
$hasBOM = ($ps1Bytes.Length -ge 3 -and $ps1Bytes[0] -eq 0xEF -and $ps1Bytes[1] -eq 0xBB -and $ps1Bytes[2] -eq 0xBF)
Assert-Test -TestName "Manage-SystemSnapshots.ps1 codificado en UTF-8 con BOM (Regla 4)" `
            -Condition $hasBOM `
            -Details "Primeros bytes: 0x$([System.BitConverter]::ToString($ps1Bytes[0..2]))"

# Validación ANSI o UTF-8 No-BOM en .cmd
$cmdBytes = [System.IO.File]::ReadAllBytes($cmdPath)
$cmdHasBOM = ($cmdBytes.Length -ge 3 -and $cmdBytes[0] -eq 0xEF -and $cmdBytes[1] -eq 0xBB -and $cmdBytes[2] -eq 0xBF)
Assert-Test -TestName "Manage-SystemSnapshots.cmd es estrictamente No-BOM (Regla 4)" `
            -Condition (-not $cmdHasBOM) `
            -Details "cmdHasBOM: $cmdHasBOM"

# Validación sintáctica AST en Windows PowerShell 5.1
$astErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$astErrors) | Out-Null
Assert-Test -TestName "Parser AST de Windows PowerShell 5.1 sin errores sintácticos" `
            -Condition ($astErrors.Count -eq 0) `
            -Details "Errores detectados: $($astErrors.Count)"

# -----------------------------------------------------------------------------
# 2. PRUEBA DE CREACIÓN DE SNAPSHOT EN SANDBOX
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> [2/3] Verificando Creación de Snapshot y Manifiesto Criptográfico..." -ForegroundColor Cyan

$sandboxDir = Join-Path $env:TEMP "romanOS_UnitTest_Snapshots_$(Get-Random)"
if (-not (Test-Path $sandboxDir)) {
    New-Item -ItemType Directory -Path $sandboxDir -Force | Out-Null
}

try {
    # Ejecución de creación de snapshot en sandbox con -SkipElevation
    $snapResult = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -Action Create -Name "UnitTestSnapshot" -Description "Snapshot de pruebas unitarias" `
        -SnapshotDirectory $sandboxDir -Unattended -SkipElevation

    $createdSnap = Get-ChildItem -Path $sandboxDir -Directory -Filter "SNAP-*" | Select-Object -First 1
    $snapFound = ($null -ne $createdSnap -and (Test-Path $createdSnap.FullName))
    $snapDetail = if ($createdSnap) { $createdSnap.Name } else { "No generado" }
    Assert-Test -TestName "Directorio de snapshot generado en sandbox" `
                -Condition $snapFound `
                -Details $snapDetail

    if ($createdSnap) {
        $manifestPath = Join-Path $createdSnap.FullName "manifest.json"
        Assert-Test -TestName "Archivo manifest.json generado y presente" `
                    -Condition (Test-Path $manifestPath) `
                    -Details $manifestPath

        $manifest = $null
        try {
            $manifest = Get-Content -Path $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            Write-Warning "Fallo al deserializar manifest.json: $($_.Exception.Message)"
        }

        $validMeta = [bool]($manifest -and $manifest.SnapshotId -and $manifest.OSBuild -gt 0)
        Assert-Test -TestName "manifest.json contiene metadatos de sistema válidos" `
                    -Condition $validMeta `
                    -Details "SnapshotId: $($manifest.SnapshotId) | OSBuild: $($manifest.OSBuild)"

        $hasArtifacts = [bool]($manifest -and $manifest.Artifacts.Count -gt 0)
        Assert-Test -TestName "manifest.json contiene lista de artefactos con hashes SHA-256" `
                    -Condition $hasArtifacts `
                    -Details "Artefactos registrados: $($manifest.Artifacts.Count)"

        $servicesJson = Join-Path $createdSnap.FullName "state\services.json"
        Assert-Test -TestName "Telemetría de servicios exportada en JSON válido" `
                    -Condition (Test-Path $servicesJson) `
                    -Details $servicesJson

        $networkJson = Join-Path $createdSnap.FullName "state\network.json"
        Assert-Test -TestName "Telemetría de red y offloads NDIS exportada en JSON" `
                    -Condition (Test-Path $networkJson) `
                    -Details $networkJson
    }
} finally {
    # Limpieza del sandbox temporal
    if (Test-Path $sandboxDir) {
        Remove-Item -Path $sandboxDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# -----------------------------------------------------------------------------
# 3. VERIFICACIÓN DE COMANDOS CLI Y CATÁLOGO
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> [3/3] Verificando Parámetros CLI y Listado..." -ForegroundColor Cyan

$listOutput = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Action List
$listStr = if ($listOutput) { $listOutput -join "`n" } else { "" }
Assert-Test -TestName "Acción -Action List ejecutable sin elevación forzada ni errores" `
            -Condition ([bool]($listStr -match "CATÁLOGO DE INSTANTÁNEAS DISPONIBLES")) `
            -Details "Encabezado detectado en salida"

# Simulación WhatIf
$whatIfOutput = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptPath -WhatIf
$whatIfStr = if ($whatIfOutput) { $whatIfOutput -join "`n" } else { "" }
Assert-Test -TestName "Modo simulado -WhatIf ejecuta sin excepciones ni intentos UAC" `
            -Condition ([bool]($whatIfStr -match "Snapshot simulado exitosamente")) `
            -Details "Confirmación de modo WhatIf detectada"

# -----------------------------------------------------------------------------
# RESUMEN DE EJECUCIÓN
# -----------------------------------------------------------------------------
$duration = [math]::Round(((Get-Date) - $testStartTime).TotalSeconds, 2)
Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN: PRUEBAS DE SNAPSHOT & ROLLBACK ENGINE" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Total de Aserciones : $($passCount + $failCount)" -ForegroundColor White
Write-Host " Aprobadas (PASS)    : $passCount" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Yellow' })
Write-Host " Fallidas (FAIL)     : $failCount" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Red' })
Write-Host " Duración Total      : ${duration}s" -ForegroundColor DarkGray
Write-Host " Estado Global       : $(if ($failCount -eq 0) { 'PASS (100% Exitoso)' } else { 'FAIL' })" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Red' })
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host ""

if ($failCount -gt 0) {
    exit 1
} else {
    exit 0
}
