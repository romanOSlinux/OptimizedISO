<#
.SYNOPSIS
    Toggle-VBS-CoreIsolation.ps1 - Conmutador de Virtualization-Based Security (VBS / HVCI)
    Componente Oficial de romanOS Helpers (PLAN-0114).

.DESCRIPTION
    Conmuta la integridad de memoria del hipervisor (HVCI / VBS).
    Permite alternar entre máxima tasa de cuadros (Esports) o máxima seguridad de virtualización.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("Toggle", "Enable", "Disable", "Status")]
    [string]$Action = "Toggle",
    [switch]$Quiet,
    [switch]$PassThru
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleCandidates = @(
    (Join-Path $scriptRoot "..\Modules\Desktop-Helpers.ps1"),
    (Join-Path $env:SystemRoot "Setup\Scripts\DesktopHelpers\Desktop-Helpers.ps1"),
    "C:\OptimizedISO\scripts\Modules\Desktop-Helpers.ps1"
)

$moduleLoaded = $false
foreach ($cand in $moduleCandidates) {
    if (Test-Path -Path $cand) {
        . $cand -HelperName "VBS" -Action $Action -Quiet:$Quiet -PassThru:$PassThru
        $moduleLoaded = $true
        break
    }
}

if (-not $moduleLoaded) {
    Write-Error "CRITICAL: No se pudo localizar Desktop-Helpers.ps1."
    exit 1
}
