<#
.SYNOPSIS
    Desktop-Helpers.ps1 - Módulo de Gestión y Conmutación de Desktop Helpers
    Componente Oficial de romanOS / OptimizedISO (PLAN-0114).

.DESCRIPTION
    Provee las funciones operativas para conmutar servicios del sistema (Windows Update,
    Defender, Bluetooth, Impresión, File Sharing, VBS) bajo la gobernanza del
    Policy-Engine (SSOT) y la protección inmutable de la Matriz de Invariantes.

    100% compatible con Windows PowerShell 5.1 (powershell.exe) y PowerShell 7+ (pwsh).
    Codificación estricta UTF-8 con BOM.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$HelperName,
    [ValidateSet("Toggle", "Enable", "Disable", "Status")]
    [string]$Action = "Toggle",
    [switch]$Quiet,
    [switch]$PassThru
)

# -----------------------------------------------------------------------------
# 1. RESOLUCIÓN DE RUTAS Y CARGA DEL SSOT
# -----------------------------------------------------------------------------
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Búsqueda dinámica de Policy-Engine.ps1 en Core (Entorno de desarrollo vs Sistema instalado)
$policyEngineCandidates = @(
    (Join-Path $scriptRoot "..\Core\Policy-Engine.ps1"),
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
    Write-Error "CRITICAL: No se pudo localizar Policy-Engine.ps1 en ninguna ruta candidata."
    exit 1
}

# -----------------------------------------------------------------------------
# 2. FUNCIONES DE CONMUTACIÓN POR HELPER
# -----------------------------------------------------------------------------

function Invoke-DesktopHelperToggle {
    <#
    .SYNOPSIS
        Conmuta o establece el estado de un Desktop Helper específico.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [ValidateSet("Toggle", "Enable", "Disable", "Status")]
        [string]$HelperAction = "Toggle",

        [switch]$QuietOutput,
        [switch]$PassThruOutput
    )

    $helper = Get-RomanOSDesktopHelperDef -Name $Name
    if (-not $helper) {
        Write-Warning "El helper '$Name' no existe en el catálogo canónico de romanOS."
        return $false
    }

    $stateObj = Get-RomanOSDesktopHelperState -Name $Name
    $currentState = if ($stateObj -is [int]) { $stateObj } elseif ($stateObj -and $null -ne $stateObj.State) { $stateObj.State } else { 0 }

    if ($HelperAction -eq "Status") {
        $stateText = if ($currentState -eq 1) { "ACTIVADO" } else { "DESACTIVADO" }
        if (-not $QuietOutput) {
            Write-Host "[$Name] $($helper.Title): $stateText (Valor: $currentState)" -ForegroundColor Cyan
        }
        if ($PassThruOutput) {
            return [PSCustomObject]@{
                Helper   = $Name
                Title    = $helper.Title
                State    = $currentState
                IsActive = ($currentState -eq 1)
                Status   = if ($currentState -eq 1) { "Enabled" } else { "Disabled" }
                Success  = $true
            }
        }
        return ($currentState -eq 1)
    }

    $targetState = switch ($HelperAction) {
        "Enable"  { 1 }
        "Disable" { 0 }
        "Toggle"  { if ($currentState -eq 1) { 0 } else { 1 } }
    }

    if ($PSCmdlet.ShouldProcess("$($helper.Title) (Nuevo Estado: $targetState)", "Conmutar Helper")) {
        Set-RomanOSDesktopHelperState -Name $Name -State $targetState -Quiet:$QuietOutput
        return $true
    }

    return $false
}

function Show-RomanOSHelpersMenu {
    <#
    .SYNOPSIS
        Muestra un menú interactivo en consola para gestionar los 6 Desktop Helpers.
    #>
    [CmdletBinding()]
    param()

    $helpers = Get-RomanOSDesktopHelperDef

    while ($true) {
        Clear-Host
        Write-Host "==========================================================================" -ForegroundColor Cyan
        Write-Host "             romanOS HELPERS — CENTRO DE CONTROL DE SERVICIOS             " -ForegroundColor White
        Write-Host "==========================================================================" -ForegroundColor Cyan
        Write-Host "  Conmutadores rápidos modales con protección de Invariantes del Sistema  " -ForegroundColor Gray
        Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkGray

        $i = 1
        foreach ($h in $helpers) {
            $state = Get-RomanOSDesktopHelperState -Name $h.Name
            $badge = if ($state -eq 1) { "[ ACTIVADO ]" } else { "[DESACTIVADO]" }
            $color = if ($state -eq 1) { "Green" } else { "Yellow" }

            Write-Host "  $i. " -NoNewline -ForegroundColor White
            Write-Host "$badge " -NoNewline -ForegroundColor $color
            Write-Host "$($h.Title)" -ForegroundColor White
            Write-Host "     -> $($h.Description)" -ForegroundColor DarkGray
            $i++
        }

        Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  A. Auditar Invariantes del Sistema (Assert-RomanOSInvariants)" -ForegroundColor Cyan
        Write-Host "  Q. Salir" -ForegroundColor Red
        Write-Host "==========================================================================" -ForegroundColor Cyan
        Write-Host ""

        $choice = Read-Host "  Selecciona una opción [1-$($helpers.Count), A, Q]"
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $helpers.Count) {
            $idx = [int]$choice - 1
            $selected = $helpers[$idx]
            Write-Host "`n  Conmutando $($selected.Title)..." -ForegroundColor Yellow
            Invoke-DesktopHelperToggle -Name $selected.Name -HelperAction "Toggle"
            Start-Sleep -Seconds 2
        } elseif ($choice -ieq 'A') {
            Write-Host "`n  Auditando Matriz de Invariantes del Sistema..." -ForegroundColor Cyan
            $audit = Assert-RomanOSInvariants -AutoRemediate
            if ($audit.Passed) {
                Write-Host "  [OK] Todos los $($audit.TotalInvariants) invariantes del sistema están 100% conformes." -ForegroundColor Green
            } else {
                Write-Host "  [ALERTA] Se detectaron $($audit.ViolationsCount) violaciones. Se aplicó auto-remediación." -ForegroundColor Yellow
            }
            Write-Host "`nPresiona cualquier tecla para volver al menú..." -ForegroundColor Gray
            $null = [Console]::ReadKey($true)
        } elseif ($choice -ieq 'Q') {
            break
        }
    }
}

# -----------------------------------------------------------------------------
# 3. PUNTO DE ENTRADA CLI
# -----------------------------------------------------------------------------
if (-not [string]::IsNullOrWhiteSpace($HelperName)) {
    Invoke-DesktopHelperToggle -Name $HelperName -HelperAction $Action -QuietOutput:$Quiet -PassThruOutput:$PassThru
} elseif (-not $Quiet -and $Host.Name -notmatch "ServerRemoteHost" -and -not [Console]::IsInputRedirected -and $MyInvocation.InvocationName -ne '.') {
    Show-RomanOSHelpersMenu
}
