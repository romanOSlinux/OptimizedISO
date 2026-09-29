<#
.SYNOPSIS
    Toggle-WindowsUpdate.ps1 - Conmutador Seguro de Windows Update
    Componente Oficial de romanOS Helpers (PLAN-0114).

.DESCRIPTION
    Conmuta el servicio de Windows Update y sus tareas asociadas preservando
    estrictamente la Matriz de Invariantes (sin parches preview ni sobreescritura de drivers).
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
    (Join-Path $scriptRoot "Desktop-Helpers.ps1"),
    (Join-Path $env:SystemRoot "Setup\Scripts\DesktopHelpers\Desktop-Helpers.ps1"),
    (Join-Path $env:SystemRoot "Setup\Scripts\Modules\Desktop-Helpers.ps1"),
    "C:\OptimizedISO\scripts\Modules\Desktop-Helpers.ps1"
)

$moduleLoaded = $false
foreach ($cand in $moduleCandidates) {
    if (Test-Path -Path $cand) {
        . $cand -HelperName "WindowsUpdate" -Action $Action -Quiet:$Quiet -PassThru:$PassThru
        $moduleLoaded = $true
        break
    }
}

if (-not $moduleLoaded) {
    Write-Error "CRITICAL: No se pudo localizar Desktop-Helpers.ps1."
    exit 1
}