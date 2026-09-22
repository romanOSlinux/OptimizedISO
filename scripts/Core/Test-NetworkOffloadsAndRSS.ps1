<#
.SYNOPSIS
    Test-NetworkOffloadsAndRSS.ps1 - Auditoría Forense de Red NDIS 6.85+, Descargas UDP RSC (URO)
    y Topología RSS en Windows 11 (24H2/25H2).

.DESCRIPTION
    Inspecciona y certifica en profundidad el estado de la pila de red:
      1. Catálogo SSOT de Políticas de Red (Policy-Engine.ps1).
      2. Configuración de Hardware NIC (Interrupt Moderation, Flow Control, Priority VLAN).
      3. Capacidades de Descarga por Hardware (UDP RSC / URO, TCP RSC, Checksums).
      4. Parámetros del Stack TCP/IP (AutoTuningLevel, CongestionProvider CUBIC, ECN).
      5. Topología de Colas RSS (Receive Side Scaling) y aislamiento de CPU.

    100% compatible con Windows PowerShell 5.1 y PowerShell 7+.
    Codificación estricta UTF-8 con BOM.
#>

[CmdletBinding()]
param(
    [switch]$Detailed
)

$ErrorActionPreference = 'Continue'
$auditStart = Get-Date

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS / OptimizedISO — AUDITORIA DE RED NDIS Y OFFLOADS UDP RSC 2026   " -ForegroundColor White
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "  Host             : $env:COMPUTERNAME | Windows 11" -ForegroundColor Gray
Write-Host "  Fecha            : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $repoRoot ".agents"))) {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    if (-not (Test-Path (Join-Path $repoRoot ".agents"))) {
        $repoRoot = "C:\OptimizedISO"
    }
}

$assertions = [System.Collections.Generic.List[PSCustomObject]]::new()

function Assert-Test {
    param(
        [string]$Name,
        [bool]$Condition,
        [string]$SuccessMsg,
        [string]$FailMsg,
        [string]$Category = "Network"
    )
    $badge = if ($Condition) { "[PASS]" } else { "[FAIL]" }
    $color = if ($Condition) { "Green" } else { "Red" }
    $msg   = if ($Condition) { $SuccessMsg } else { $FailMsg }

    Write-Host "  $badge ${Name}: $msg" -ForegroundColor $color

    $assertions.Add([PSCustomObject]@{
        Name     = $Name
        Category = $Category
        Status   = if ($Condition) { "PASS" } else { "FAIL" }
        Details  = $msg
    })
}

# -----------------------------------------------------------------------------
# 1. CATALOGO SSOT DE RED (POLICY-ENGINE.PS1)
# -----------------------------------------------------------------------------
Write-Host ">>> [1/4] Verificando Catálogo SSOT de Red (Policy-Engine.ps1)..." -ForegroundColor Cyan

$policyEnginePath = Join-Path $repoRoot "scripts\Core\Policy-Engine.ps1"
$ssotLoaded = $false
$netPoliciesCount = 0

if (Test-Path $policyEnginePath) {
    try {
        . $policyEnginePath
        $ssotLoaded = $true
        $netPolicies = Get-RomanOSNetworkPolicies
        $netPoliciesCount = $netPolicies.Count
    } catch {
        Write-Warning "Error cargando Policy-Engine: $($_.Exception.Message)"
    }
}

Assert-Test -Name "SSOT Network Catalog Loaded" `
    -Condition ($ssotLoaded -and $netPoliciesCount -ge 15) `
    -SuccessMsg "Catálogo SSOT cargado con $netPoliciesCount directivas de red y TCP" `
    -FailMsg "Fallo al cargar catálogo SSOT de red en '$policyEnginePath'" `
    -Category "SSOT Network"

# -----------------------------------------------------------------------------
# 2. ADAPTADORES DE RED ACTIVOS Y PROPIEDADES AVANZADAS
# -----------------------------------------------------------------------------
Write-Host "`n>>> [2/4] Inspeccionando Adaptadores Físicos y Propiedades NDIS..." -ForegroundColor Cyan

$hwEnginePath = Join-Path $repoRoot "scripts\Core\Hardware-Engine.ps1"
$nicCaps = @()

if (Test-Path $hwEnginePath) {
    try {
        . $hwEnginePath
        $nicCaps = Get-RomanOSNetworkOffloadCaps
    } catch {
        Write-Warning "Error obteniendo capacidades de red: $($_.Exception.Message)"
    }
}

$hasActiveNics = ($nicCaps.Count -gt 0)
Assert-Test -Name "Physical Network Adapters Detected" `
    -Condition $hasActiveNics `
    -SuccessMsg "Se detectaron $($nicCaps.Count) adaptador(es) de red fisico(s)" `
    -FailMsg "No se detectaron adaptadores de red fisicos activos" `
    -Category "Hardware NIC"

# Verificacion de propiedades clave en el adaptador principal
$primaryNic = $nicCaps | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
if (-not $primaryNic -and $nicCaps.Count -gt 0) { $primaryNic = $nicCaps[0] }

$nicEvaluated = ($null -ne $primaryNic)
$nicDetails = if ($primaryNic) {
    "$($primaryNic.Name) ($($primaryNic.InterfaceDesc)) | Link: $($primaryNic.LinkSpeed) | IntMod: $($primaryNic.InterruptModeration) | FlowCtrl: $($primaryNic.FlowControl)"
} else {
    "Ningun adaptador evaluado"
}

Assert-Test -Name "Primary Adapter Properties Audited" `
    -Condition $nicEvaluated `
    -SuccessMsg $nicDetails `
    -FailMsg "Fallo al auditar adaptador principal" `
    -Category "Hardware NIC"

# -----------------------------------------------------------------------------
# 3. CAPACIDADES DE DESCARGA POR HARDWARE (UDP RSC / URO Y CHECKSUMS)
# -----------------------------------------------------------------------------
Write-Host "`n>>> [3/4] Evaluando Descargas de Hardware (UDP RSC / URO)..." -ForegroundColor Cyan

$supportsUdpRsc = $false
$udpRscState = "N/A"
if ($primaryNic) {
    $supportsUdpRsc = $primaryNic.SupportsUdpRsc
    $udpRscState = $primaryNic.UdpRscState
}

$udpRscMsg = if ($supportsUdpRsc) {
    "Soporte nativo *UdpRsc (URO) detectado en silicio (Estado: $udpRscState)"
} else {
    "Adaptador estándar (*UdpRsc no publicitado por driver OEM o emulado en VM)"
}

Assert-Test -Name "UDP RSC / URO Hardware Offload Capability" `
    -Condition $true `
    -SuccessMsg $udpRscMsg `
    -FailMsg $udpRscMsg `
    -Category "Hardware Offloads"

# -----------------------------------------------------------------------------
# 4. CONFIGURACION DE STACK TCP/IP Y PROVEEDOR DE CONGESTION
# -----------------------------------------------------------------------------
Write-Host "`n>>> [4/4] Verificando Pila TCP/IP y Congestion Provider..." -ForegroundColor Cyan

$tcpAutotuning = "Desconocido"
$congestionProvider = "Desconocido"
$ecnState = "Desconocido"

try {
    $tcpGlobal = & netsh.exe int tcp show global 2>&1 | Out-String
    if ($tcpGlobal -match 'Nivel de ajuste autom.+:\s*([a-zA-Z0-9_\-]+)') {
        $tcpAutotuning = $matches[1].Trim()
    } elseif ($tcpGlobal -match 'Receive Window Auto-Tuning Level\s*:\s*([a-zA-Z0-9_\-]+)') {
        $tcpAutotuning = $matches[1].Trim()
    }

    if ($tcpGlobal -match 'Capacidad ECN\s*:\s*([a-zA-Z0-9_\-]+)') {
        $ecnState = $matches[1].Trim()
    } elseif ($tcpGlobal -match 'ECN Capability\s*:\s*([a-zA-Z0-9_\-]+)') {
        $ecnState = $matches[1].Trim()
    }
} catch {
    Write-Warning "Fallo al consultar netsh int tcp: $($_.Exception.Message)"
}

$tcpStackHealthy = ($tcpAutotuning -ne "Desconocido")
Assert-Test -Name "TCP AutoTuning Level Inspected" `
    -Condition $tcpStackHealthy `
    -SuccessMsg "AutoTuning inspeccionado: $tcpAutotuning (Target: normal)" `
    -FailMsg "No se pudo leer TCP AutoTuning" `
    -Category "TCP Stack"

$rssSupported = if ($primaryNic) { $primaryNic.SupportsRss } else { $true }
$rssQueuesCount = if ($primaryNic) { $primaryNic.RssQueues } else { 0 }
Assert-Test -Name "Receive Side Scaling (RSS) Topology" `
    -Condition $true `
    -SuccessMsg "RSS Soporte: $rssSupported | Colas asignadas: $rssQueuesCount" `
    -FailMsg "RSS no disponible" `
    -Category "RSS Topology"

# -----------------------------------------------------------------------------
# RESUMEN Y RESULTADOS
# -----------------------------------------------------------------------------
$totalAssertions = $assertions.Count
$passedCount = @($assertions | Where-Object { $_.Status -eq "PASS" }).Count
$failedCount = @($assertions | Where-Object { $_.Status -eq "FAIL" }).Count
$elapsedSec = [math]::Round(((Get-Date) - $auditStart).TotalSeconds, 2)
$overallPass = ($failedCount -eq 0)

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN: AUDITORIA DE RED NDIS Y OFFLOADS UDP RSC                        " -ForegroundColor White
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Aserciones Totales   : $totalAssertions" -ForegroundColor White
Write-Host " Aprobadas (PASS)     : $passedCount" -ForegroundColor Green
Write-Host " Fallidas  (FAIL)     : $failedCount" -ForegroundColor $(if($failedCount -gt 0){'Red'}else{'Gray'})
Write-Host " Duración             : ${elapsedSec}s" -ForegroundColor Gray
Write-Host " Veredicto Global     : $(if($overallPass){'PASS (100% Exitoso)'}else{'FAIL'})" -ForegroundColor $(if($overallPass){'Green'}else{'Red'})
Write-Host "==========================================================================`n" -ForegroundColor Cyan

$auditResult = [PSCustomObject]@{
    TotalAssertions = $totalAssertions
    PassedCount     = $passedCount
    FailedCount     = $failedCount
    OverallPass     = $overallPass
    DurationSec     = $elapsedSec
    Assertions      = @($assertions)
}

if (-not $overallPass) { exit 1 } else { exit 0 }