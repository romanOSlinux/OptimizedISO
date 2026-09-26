<#
.SYNOPSIS
    Test-DesktopHelpers.ps1 - Suite de Pruebas Unitarias para Desktop Helpers e Invariantes
    romanOS / OptimizedISO — Ecosistema Unificado (2026)

.DESCRIPTION
    Suite automatizada para certificar la integridad de los 6 Asistentes de Escritorio
    (Desktop Helpers), paridad SSOT con Policy-Engine.ps1, validación de codificación estricta
    (UTF-8 BOM en .ps1, No-BOM en .cmd) y pruebas de simulación -WhatIf en Windows PowerShell 5.1.

.EXAMPLE
    .\Test-DesktopHelpers.ps1
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Quick
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS — BATERÍA DE PRUEBAS UNITARIAS: DESKTOP HELPERS & INVARIANTES    " -ForegroundColor Cyan
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

$corePolicyEngine = Join-Path $repoRoot "scripts\Core\Policy-Engine.ps1"
$moduleHelpers    = Join-Path $repoRoot "scripts\Modules\Desktop-Helpers.ps1"
$helpersDir       = Join-Path $repoRoot "scripts\Desktop-Helpers"

# -----------------------------------------------------------------------------
# 1. INTEGRIDAD DE ARCHIVOS Y CODIFICACIÓN ESTRICTA (REGLA 4)
# -----------------------------------------------------------------------------
Write-Host ">>> [1/4] Verificando Archivos, Codificación de Encodings y AST..." -ForegroundColor Cyan

Assert-Test -TestName "Existencia física de scripts/Modules/Desktop-Helpers.ps1" `
            -Condition (Test-Path $moduleHelpers) `
            -Details $moduleHelpers

Assert-Test -TestName "Existencia del directorio scripts/Desktop-Helpers/" `
            -Condition (Test-Path $helpersDir) `
            -Details $helpersDir

$helperNames = @(
    "Toggle-WindowsUpdate",
    "Toggle-Defender",
    "Toggle-Bluetooth",
    "Toggle-Printing",
    "Toggle-FileSharing",
    "Toggle-VBS-CoreIsolation",
    "romanOS-Helpers-Menu"
)

foreach ($name in $helperNames) {
    $ps1File = Join-Path $helpersDir "$name.ps1"
    $cmdFile = Join-Path $helpersDir "$name.cmd"

    Assert-Test -TestName "Existencia de $name.ps1" `
                -Condition (Test-Path $ps1File) `
                -Details $ps1File

    Assert-Test -TestName "Existencia de $name.cmd" `
                -Condition (Test-Path $cmdFile) `
                -Details $cmdFile

    # Verificación UTF-8 con BOM en .ps1
    if (Test-Path $ps1File) {
        $bytes = [System.IO.File]::ReadAllBytes($ps1File)
        $hasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        Assert-Test -TestName "$name.ps1 codificado en UTF-8 con BOM (Regla 4)" `
                    -Condition $hasBOM `
                    -Details "Bytes: 0x$([System.BitConverter]::ToString($bytes[0..2]))"

        # AST Parse
        $astErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($ps1File, [ref]$null, [ref]$astErrors) | Out-Null
        Assert-Test -TestName "Parser AST de $name.ps1 sin errores sintácticos" `
                    -Condition ($astErrors.Count -eq 0) `
                    -Details "Errores: $($astErrors.Count)"
    }

    # Verificación No-BOM en .cmd
    if (Test-Path $cmdFile) {
        $cmdBytes = [System.IO.File]::ReadAllBytes($cmdFile)
        $cmdBOM = ($cmdBytes.Length -ge 3 -and $cmdBytes[0] -eq 0xEF -and $cmdBytes[1] -eq 0xBB -and $cmdBytes[2] -eq 0xBF)
        Assert-Test -TestName "$name.cmd es estrictamente No-BOM / ANSI (Regla 4)" `
                    -Condition (-not $cmdBOM) `
                    -Details "cmdBOM: $cmdBOM"
    }
}

# -----------------------------------------------------------------------------
# 2. PARIDAD SSOT EN POLICY-ENGINE.PS1
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> [2/4] Verificando Paridad SSOT e Invariantes en Policy-Engine..." -ForegroundColor Cyan

Assert-Test -TestName "Existencia física de Policy-Engine.ps1" `
            -Condition (Test-Path $corePolicyEngine) `
            -Details $corePolicyEngine

if (Test-Path $corePolicyEngine) {
    . $corePolicyEngine

    # Invariantes del Sistema
    $invariants = Get-RomanOSSystemInvariants
    Assert-Test -TestName "Get-RomanOSSystemInvariants retorna al menos 7 invariantes" `
                -Condition ($invariants -and $invariants.Count -ge 7) `
                -Details "Invariantes registradas: $($invariants.Count)"

    $requiredInvariants = @(
        "INV_DRIVERS_NO_WU_OVERWRITE",
        "INV_WU_NO_PREVIEWS",
        "INV_WU_NO_CONTINUOUS_INNOVATION",
        "INV_WU_QUALITY_DEFERRAL_7D",
        "INV_ANTI_BLOAT_CONTENT_DELIVERY",
        "INV_SECURITY_DRIVER_BLOCKLIST",
        "INV_STORE_AUTH_ROOT"
    )
    foreach ($rInv in $requiredInvariants) {
        $found = ($invariants | Where-Object { $_.Id -eq $rInv })
        Assert-Test -TestName "Invariante crítica registrada: $rInv" `
                    -Condition ($null -ne $found) `
                    -Details "Path: $($found.RegistryPath)"
    }

    # Desktop Helpers en Policy-Engine
    $helperIds = @("WindowsUpdate", "Defender", "Bluetooth", "Printing", "FileSharing", "VBS")
    foreach ($hId in $helperIds) {
        $def = Get-RomanOSDesktopHelperDef -HelperId $hId
        Assert-Test -TestName "Definición canónica de Helper: $hId" `
                    -Condition ($null -ne $def -and $def.Name) `
                    -Details "Nombre: $($def.Name)"

        $st = Get-RomanOSDesktopHelperState -HelperId $hId
        Assert-Test -TestName "Estado consultable de Helper: $hId ($($st.Status))" `
                    -Condition ($st -and ($st.Status -eq "Enabled" -or $st.Status -eq "Disabled")) `
                    -Details "Status: $($st.Status)"
    }
}

# -----------------------------------------------------------------------------
# 3. EJECUCIÓN SIMULADA (-WHATIF) EN WINDOWS POWERSHELL 5.1
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> [3/4] Validando Ejecución en Frío (-WhatIf) en Windows PowerShell 5.1..." -ForegroundColor Cyan

$ps51 = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path $ps51)) { $ps51 = "powershell.exe" }

foreach ($name in $helperNames) {
    if ($name -eq "romanOS-Helpers-Menu") { continue }
    $targetPs1 = Join-Path $helpersDir "$name.ps1"
    
    $proc = Start-Process -FilePath $ps51 -ArgumentList "-STA -NoProfile -ExecutionPolicy Bypass -Command `"& '$targetPs1' -Action Enable -WhatIf`"" -Wait -PassThru -NoNewWindow
    Assert-Test -TestName "Ejecución -WhatIf Enable de $name.ps1 (Código de salida: $($proc.ExitCode))" `
                -Condition ($proc.ExitCode -eq 0) `
                -Details "ExitCode: $($proc.ExitCode)"

    $procDis = Start-Process -FilePath $ps51 -ArgumentList "-STA -NoProfile -ExecutionPolicy Bypass -Command `"& '$targetPs1' -Action Disable -WhatIf`"" -Wait -PassThru -NoNewWindow
    Assert-Test -TestName "Ejecución -WhatIf Disable de $name.ps1 (Código de salida: $($procDis.ExitCode))" `
                -Condition ($procDis.ExitCode -eq 0) `
                -Details "ExitCode: $($procDis.ExitCode)"
}

# -----------------------------------------------------------------------------
# 4. AUDITORÍA TRANSVERSAL DE INVARIANTES (MUTATION GATEWAY)
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> [4/4] Validando Blindaje de Mutation Gateway e Invariantes..." -ForegroundColor Cyan

if (Get-Command "Assert-RomanOSInvariants" -ErrorAction SilentlyContinue) {
    $evalResults = Assert-RomanOSInvariants -WhatIf
    Assert-Test -TestName "Assert-RomanOSInvariants evalúa sin excepciones" `
                -Condition ($evalResults -and $evalResults.TotalInvariants -ge 7) `
                -Details "Reglas evaluadas: $($evalResults.TotalInvariants)"
}

# -----------------------------------------------------------------------------
# RESUMEN EJECUTIVO
# -----------------------------------------------------------------------------
$elapsed = [math]::Round(((Get-Date) - $testStartTime).TotalSeconds, 2)
Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "               RESUMEN FINAL DE LA SUITE DE PRUEBAS                       " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "  Pruebas Superadas (PASS) : $passCount" -ForegroundColor Green
Write-Host "  Pruebas Fallidas  (FAIL) : $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-Host "  Tiempo Transcurrido      : $elapsed segundos" -ForegroundColor DarkGray
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host ""

if ($failCount -gt 0) {
    Exit 1
} else {
    Exit 0
}
