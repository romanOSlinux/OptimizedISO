<#
.SYNOPSIS
    Toggle-Printing.ps1 - Conmutador del Subsistema de Impresión (Spooler)
    Componente Oficial de romanOS Helpers (PLAN-0114).

.DESCRIPTION
    Conmuta el servicio Spooler de impresión según las necesidades del usuario.
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
    (Join-Path (Split-Path (Split-Path $scriptRoot -Parent) -Parent) "scripts\Modules\Desktop-Helpers.ps1")
)

$moduleLoaded = $false
foreach ($cand in $moduleCandidates) {
    if (Test-Path -Path $cand) {
        . $cand -HelperName "Printing" -Action $Action -Quiet:$Quiet -PassThru:$PassThru
        $moduleLoaded = $true
        break
    }
}

if (-not $moduleLoaded) {
    Write-Error "CRITICAL: No se pudo localizar Desktop-Helpers.ps1."
    exit 1
}