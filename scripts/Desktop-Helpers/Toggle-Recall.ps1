<#
.SYNOPSIS
    Toggle-Recall.ps1 - Conmutador de Windows Recall e IA Snapshotting
    Componente Oficial de romanOS Helpers (PLAN-0122).

.DESCRIPTION
    Conmuta la directiva de Windows Recall y captura continua de IA (WindowsAI).
    Permite activar o desactivar Recall y el análisis de datos de IA bajo demanda.
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
        . $cand -HelperName "Recall" -Action $Action -Quiet:$Quiet -PassThru:$PassThru
        $moduleLoaded = $true
        break
    }
}

if (-not $moduleLoaded) {
    Write-Error "CRITICAL: No se pudo localizar Desktop-Helpers.ps1."
    exit 1
}
