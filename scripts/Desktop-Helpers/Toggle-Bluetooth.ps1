<#
.SYNOPSIS
    Toggle-Bluetooth.ps1 - Conmutador de Servicios y Conectividad Bluetooth
    Componente Oficial de romanOS Helpers (PLAN-0114).

.DESCRIPTION
    Conmuta la pila de servicios Bluetooth para mandos inalámbricos y dispositivos de audio.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("Toggle", "Enable", "Disable", "Status")]
    [string]$Action = "Toggle",
    [switch]$Quiet
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
        . $cand -HelperName "Bluetooth" -Action $Action -Quiet:$Quiet
        $moduleLoaded = $true
        break
    }
}

if (-not $moduleLoaded) {
    Write-Error "CRITICAL: No se pudo localizar Desktop-Helpers.ps1."
    exit 1
}
