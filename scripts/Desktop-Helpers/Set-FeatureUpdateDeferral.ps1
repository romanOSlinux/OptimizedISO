<#
.SYNOPSIS
    Set-FeatureUpdateDeferral.ps1 - Gestor de Cuarentena y Versiones Mayores
    Componente Oficial de romanOS Desktop Helpers (PLAN-0148).

.DESCRIPTION
    Aplica o consulta las directivas oficiales de aplazamiento (15 a 180 dias)
    y anclaje de version mayor (TargetReleaseVersion) bajo la gobernanza del Policy-Engine (SSOT).
    Auto-eleva via UAC si se ejecuta una accion de modificacion sin privilegios.

    Compatible con Windows PowerShell 5.1 y PowerShell 7+.
    Codificación estricta UTF-8 con BOM.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("Immediate", "Defer15", "Defer30", "Defer60", "Defer90", "Defer180", "LockCurrentVersion", "Status")]
    [string]$Action = "Status",
    [switch]$Quiet,
    [switch]$PassThru
)

# -----------------------------------------------------------------------------
# 1. CARGA DEL POLICY-ENGINE (SSOT)
# -----------------------------------------------------------------------------
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$policyEngineCandidates = @(
    (Join-Path $scriptRoot "..\Core\Policy-Engine.ps1"),
    (Join-Path $scriptRoot "Policy-Engine.ps1"),
    (Join-Path $scriptRoot "Core\Policy-Engine.ps1"),
    (Join-Path $env:SystemRoot "Setup\Scripts\Core\Policy-Engine.ps1"),
    "C:\OptimizedISO\scripts\Core\Policy-Engine.ps1"
)

$policyEngineLoaded = $false
foreach ($cand in $policyEngineCandidates) {
    if (Test-Path -Path $cand) {
        . $cand
        $policyEngineLoaded = $true
        break
    }
}

if (-not $policyEngineLoaded) {
    Write-Error "CRITICAL: No se pudo localizar Policy-Engine.ps1."
    exit 1
}

# -----------------------------------------------------------------------------
# 2. EVALUACIÓN Y EJECUCIÓN
# -----------------------------------------------------------------------------
if ($Action -eq "Status") {
    $currentPolicy = Get-RomanOSFeatureUpdatePolicy
    if (-not $Quiet) {
        Write-Host "=== ROMANOS: POLÍTICA DE VERSIONES MAYORES ===" -ForegroundColor Cyan
        Write-Host "  Modo Activo:       $($currentPolicy.Mode)" -ForegroundColor Yellow
        Write-Host "  Aplazamiento:      $(if ($currentPolicy.DeferEnabled) { "$($currentPolicy.DeferDays) días" } else { "Desactivado (0 días)" })" -ForegroundColor White
        Write-Host "  Anclaje de Versión: $(if ($currentPolicy.IsVersionLocked) { "BLOQUEADO en $($currentPolicy.TargetVersion)" } else { "Sin anclaje" })" -ForegroundColor White
        Write-Host "  Versión SO Actual: $($currentPolicy.CurrentOSVersion)" -ForegroundColor DarkGray
    }
    if ($PassThru) { return $currentPolicy }
    return
}

# Comprobación de elevación para mutación
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    if (-not $Quiet) {
        Write-Host "[UAC] Solicitando elevacion de Administrador para aplicar directiva '$Action'..." -ForegroundColor Yellow
    }
    $argList = @("-STA", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"", "-Action", $Action)
    if ($Quiet) { $argList += "-Quiet" }
    Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
    exit
}

# Aplicación mediante SSOT
Set-RomanOSFeatureUpdatePolicy -Mode $Action -Quiet:$Quiet
$result = Get-RomanOSFeatureUpdatePolicy
if ($PassThru) { return $result }
