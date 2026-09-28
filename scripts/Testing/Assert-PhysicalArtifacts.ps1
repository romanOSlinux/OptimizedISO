<#
.SYNOPSIS
    romanOS Testing — Verificador Mecánico de Artefactos Físicos y Entorno Real (Regla 16)
.DESCRIPTION
    Inspecciona físicamente en disco y en el hipervisor la existencia real de artefactos
    binarios (ISOs compiladas, discos VHDX y Máquinas Virtuales activas).
    Erradica cualquier suposición o afirmación complaciente de finalización.
#>

[CmdletBinding()]
param(
    [string]$ExpectedISOPath = "C:\OptimizedISO\Windows_11_Optimized_Test.iso",
    [string]$ExpectedVMName  = "Test_Optimized_Win11"
)

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " [romanOS] VERIFICADOR MECÁNICO DE ARTEFACTOS FÍSICOS (REGLA 16)" -ForegroundColor Cyan
Write-Host " Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Usuario: $env:USERNAME | IsAdmin: $isAdmin" -ForegroundColor Gray
Write-Host "==========================================================================" -ForegroundColor Cyan

$report = [ordered]@{
    IsElevatedAdmin       = $isAdmin
    ISOFileExists         = $false
    ISOSizeBytes          = 0
    ISOSizeGB             = 0
    HyperVModuleInstalled = $false
    HyperVServiceRunning  = $false
    HyperVVMExists        = $false
    HyperVVMState         = 'N/A'
    Verdict               = 'FAIL'
}

# 1. Comprobación Física de la Imagen ISO Compilada
$targetIso = $ExpectedISOPath
if (-not (Test-Path -LiteralPath $targetIso)) {
    $autoIso = Get-ChildItem -Path "C:\OptimizedISO", "$HOME\Desktop\WinISO_Optimizado" -Filter "Windows_11*.iso" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '^Win11_25H2_Spanish_x64_v2\.iso$' } |
        Select-Object -First 1
    if ($autoIso) {
        $targetIso = $autoIso.FullName
    }
}

if (Test-Path -LiteralPath $targetIso) {
    $item = Get-Item -LiteralPath $targetIso
    if ($item.Length -gt 100MB) {
        $report.ISOFileExists = $true
        $report.ISOSizeBytes  = $item.Length
        $report.ISOSizeGB     = [math]::Round($item.Length / 1GB, 2)
        Write-Host "  [+] ISO Física Detectada: $($item.FullName) ($($report.ISOSizeGB) GB)" -ForegroundColor Green
    } else {
        Write-Host "  [!] ISO Incompleta o Vacía: $($item.Length) bytes" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [-] ISO NO EXISTE EN DISCO: $targetIso" -ForegroundColor Red
}

# 2. Comprobación del Hipervisor y Máquina Virtual
$report.HyperVModuleInstalled = [bool](Get-Command "Get-VM" -ErrorAction SilentlyContinue)
$vmms = Get-Service -Name "vmms" -ErrorAction SilentlyContinue
$report.HyperVServiceRunning  = ($null -ne $vmms -and $vmms.Status -eq 'Running')

if ($report.HyperVModuleInstalled -and $report.HyperVServiceRunning) {
    if ($isAdmin) {
        try {
            $vm = Get-VM -Name $ExpectedVMName -ErrorAction Stop
            $report.HyperVVMExists = $true
            $report.HyperVVMState  = $vm.State.ToString()
            Write-Host "  [+] VM Hyper-V Localizada: '$ExpectedVMName' (Estado: $($vm.State))" -ForegroundColor Green
        } catch {
            Write-Host "  [-] VM Hyper-V '$ExpectedVMName' no existe en el hipervisor." -ForegroundColor Red
        }
    } else {
        Write-Host "  [!] Imposible consultar Hyper-V en vivo: Sesión no elevada (IsAdmin = False)." -ForegroundColor Yellow
    }
} else {
    Write-Host "  [-] Hyper-V no disponible o servicio vmms detenido." -ForegroundColor Red
}

Write-Host "==========================================================================" -ForegroundColor Cyan
if ($report.ISOFileExists -and $report.HyperVVMExists) {
    $report.Verdict = 'PASS_FISICO_COMPLETO'
    Write-Host " VEREDICTO: ARTEFACTOS FÍSICOS CONFIRMADOS EMPÍRICAMENTE EN EL HOST" -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Cyan
    exit 0
} else {
    $report.Verdict = 'PENDIENTE_EJECUCION_FISICA'
    Write-Host " VEREDICTO: FALTAN ARTEFACTOS FÍSICOS (NO SE PUEDE DECLARAR COMPLETADO)" -ForegroundColor Red
    Write-Host "==========================================================================" -ForegroundColor Cyan
    exit 1
}
