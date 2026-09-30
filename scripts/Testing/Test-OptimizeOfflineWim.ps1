<#
.SYNOPSIS
    romanOS Testing - Suite de Validación de Optimize-OfflineWim (PLAN-0149)
.DESCRIPTION
    Pruebas unitarias y de integración para el motor de optimización y purgado offline
    de imágenes WIM/ISO y su integración en romanOS Studio.
#>

[CmdletBinding()]
param(
    [switch]$Detailed
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
$scriptPath = Join-Path $repoRoot "scripts\Host-Tools\Optimize-OfflineWim.ps1"
$cmdPath = Join-Path $repoRoot "scripts\Host-Tools\Optimize-OfflineWim.cmd"
$studioPath = Join-Path $repoRoot "scripts\GUI\romanOS-Studio.ps1"

$testsRun = 0
$testsPassed = 0
$testsFailed = 0

function Assert-Condition {
    param(
        [string]$Description,
        [bool]$Condition,
        [string]$FailureMessage = ""
    )
    $script:testsRun++
    if ($Condition) {
        $script:testsPassed++
        Write-Host "  [PASS] $Description" -ForegroundColor Green
    } else {
        $script:testsFailed++
        Write-Host "  [FAIL] $Description" -ForegroundColor Red
        if ($FailureMessage) {
            Write-Host "         Detalle: $FailureMessage" -ForegroundColor Yellow
        }
    }
}

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "SUITE DE PRUEBAS: Optimize-OfflineWim Engine & Studio GUI (PLAN-0149) " -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan

# 1. Existencia física de archivos
Assert-Condition "El script Optimize-OfflineWim.ps1 existe en scripts/Host-Tools" (Test-Path -LiteralPath $scriptPath)
Assert-Condition "El lanzador Optimize-OfflineWim.cmd existe en scripts/Host-Tools" (Test-Path -LiteralPath $cmdPath)

# 2. Codificación estricta (Regla 4)
$psBytes = [System.IO.File]::ReadAllBytes($scriptPath)
$psHasBom = ($psBytes.Length -ge 3 -and $psBytes[0] -eq 0xEF -and $psBytes[1] -eq 0xBB -and $psBytes[2] -eq 0xBF)
Assert-Condition "Optimize-OfflineWim.ps1 está codificado en UTF-8 con BOM" $psHasBom

$cmdBytes = [System.IO.File]::ReadAllBytes($cmdPath)
$cmdHasBom = ($cmdBytes.Length -ge 3 -and $cmdBytes[0] -eq 0xEF -and $cmdBytes[1] -eq 0xBB -and $cmdBytes[2] -eq 0xBF)
Assert-Condition "Optimize-OfflineWim.cmd está codificado sin BOM (ANSI/No-BOM)" (-not $cmdHasBom)

# 3. Detección pre-vuelo (-CheckOnly)
$diag = & $scriptPath -CheckOnly -Unattended
Assert-Condition "El parámetro -CheckOnly retorna un objeto de diagnóstico" ($null -ne $diag)
Assert-Condition "Diagnóstico reporta disponibilidad de DISM" ($diag.PSObject.Properties['DismAvailable'] -ne $null)
Assert-Condition "Diagnóstico reporta disponibilidad de WimLib" ($diag.PSObject.Properties['WimLibAvailable'] -ne $null)
Assert-Condition "Diagnóstico reporta disponibilidad de Oscdimg" ($diag.PSObject.Properties['OscdimgAvailable'] -ne $null)
Assert-Condition "Diagnóstico reporta espacio libre en disco" ($diag.PSObject.Properties['FreeSpaceGB'] -ne $null)

$diagIsoEsd = & $scriptPath -CheckOnly -Unattended -OutputFormat "ISO-ESD"
Assert-Condition "Diagnóstico con -RequestedOutputFormat 'ISO-ESD' requiere oscdimg" ($diagIsoEsd.RequiresOscdimg -eq $true)

$optContent = Get-Content -LiteralPath $scriptPath -Raw
Assert-Condition "Optimize-OfflineWim.ps1 soporta formato ISO-ESD en ValidateSet" ($optContent -match '\[ValidateSet\([^)]*ISO-ESD[^)]*\)\]')

# 4. Integración en romanOS Studio
$studioContent = Get-Content -LiteralPath $studioPath -Raw
Assert-Condition "romanOS-Studio contiene txtWimOptPath" ($studioContent -match 'txtWimOptPath')
Assert-Condition "romanOS-Studio contiene btnBrowseWimOpt" ($studioContent -match 'btnBrowseWimOpt')
Assert-Condition "romanOS-Studio contiene btnUseSourceIso" ($studioContent -match 'btnUseSourceIso')
Assert-Condition "romanOS-Studio contiene cmbWimOptFormat" ($studioContent -match 'cmbWimOptFormat')
Assert-Condition "romanOS-Studio incluye opción de salida ISO-ESD (Ultra-Comprimida)" ($studioContent -match 'Tag="ISO-ESD"')
Assert-Condition "romanOS-Studio contiene btnCheckWimDeps" ($studioContent -match 'btnCheckWimDeps')
Assert-Condition "romanOS-Studio contiene btnInstallWimDeps" ($studioContent -match 'btnInstallWimDeps')
Assert-Condition "romanOS-Studio contiene btnStartWimOpt" ($studioContent -match 'btnStartWimOpt')
Assert-Condition "romanOS-Studio invoca a Optimize-OfflineWim.ps1" ($studioContent -match 'Optimize-OfflineWim\.ps1')

# 5. Auditoría de Higiene Catch (Regla 13 - Prohibición de fallos silenciosos)
$psLines = Get-Content -LiteralPath $scriptPath
$emptyCatches = 0
for ($i = 0; $i -lt $psLines.Count; $i++) {
    if ($psLines[$i] -match 'catch\s*\{\s*\}|catch\s*\{\s*\$null\s*\}') {
        $emptyCatches++
    }
}
Assert-Condition "Optimize-OfflineWim.ps1 no contiene bloques catch vacíos (Fail-Visible)" ($emptyCatches -eq 0)

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "RESULTADO: $testsPassed de $testsRun pruebas pasadas ($testsFailed fallos)" -ForegroundColor $(if($testsFailed -eq 0){"Green"}else{"Red"})
Write-Host "=====================================================================" -ForegroundColor Cyan

if ($testsFailed -gt 0) {
    exit 1
} else {
    exit 0
}
