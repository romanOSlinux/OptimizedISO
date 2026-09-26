<#
.SYNOPSIS
    romanOS-Helpers-Menu.ps1 - Centro de Control de Desktop Helpers
    Componente Maestro de romanOS Helpers (PLAN-0114).

.DESCRIPTION
    Panel interactivo en consola para gestionar los 6 Desktop Helpers
    y verificar la integridad de la Matriz de Invariantes del Sistema.
#>

[CmdletBinding()]
param()

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleCandidates = @(
    (Join-Path $scriptRoot "..\Modules\Desktop-Helpers.ps1"),
    (Join-Path $env:SystemRoot "Setup\Scripts\DesktopHelpers\Desktop-Helpers.ps1"),
    "C:\OptimizedISO\scripts\Modules\Desktop-Helpers.ps1"
)

$moduleLoaded = $false
foreach ($cand in $moduleCandidates) {
    if (Test-Path -Path $cand) {
        . $cand
        $moduleLoaded = $true
        break
    }
}

if (-not $moduleLoaded) {
    Write-Error "CRITICAL: No se pudo localizar Desktop-Helpers.ps1."
    exit 1
}
