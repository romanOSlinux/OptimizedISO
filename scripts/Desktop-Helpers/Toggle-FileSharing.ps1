<#
.SYNOPSIS
    Toggle-FileSharing.ps1 - Conmutador de Uso Compartido en Red (SMB)
    Componente Oficial de romanOS Helpers (PLAN-0114).

.DESCRIPTION
    Conmuta los servicios de uso compartido en red local (LanmanServer, LanmanWorkstation)
    y detección de redes para máxima privacidad o intercambio de archivos.
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
        . $cand -HelperName "FileSharing" -Action $Action -Quiet:$Quiet -PassThru:$PassThru
        $moduleLoaded = $true
        break
    }
}

if (-not $moduleLoaded) {
    Write-Error "CRITICAL: No se pudo localizar Desktop-Helpers.ps1."
    exit 1
}
