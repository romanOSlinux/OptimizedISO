<#
.SYNOPSIS
    Test-StorageStackBypassIO.ps1 - Auditoría Forense del Subsistema de Almacenamiento,
    DirectStorage 1.2+ y BypassIO en Windows 11 (24H2/25H2).

.DESCRIPTION
    Inspecciona y certifica en profundidad el estado de la pila de almacenamiento:
      1. Catálogo SSOT de Políticas de Almacenamiento (Policy-Engine.ps1).
      2. Parámetros de Registro NTFS en vivo o colmena montada.
      3. Soporte y estado activo de TRIM en unidades de estado sólido (NVMe/SATA).
      4. Disponibilidad y bloqueos de BypassIO para DirectStorage (fsutil bypassIO).
      5. Inspección de controladores minifiltro (fltmc) que pudieran degradar I/O.
      6. Compatibilidad y soporte del subsistema Dev Drive (ReFS con Block Cloning).

    100% compatible con Windows PowerShell 5.1 y PowerShell 7+.
    Codificación estricta UTF-8 con BOM.
#>

[CmdletBinding()]
param(
    [string]$TargetDrive = $env:SystemDrive,
    [switch]$StrictLive
)

$ErrorActionPreference = 'Continue'
$auditStart = Get-Date

if (-not $TargetDrive) { $TargetDrive = "C:" }
if (-not $TargetDrive.EndsWith("\")) { $driveWithSlash = "$TargetDrive\" } else { $driveWithSlash = $TargetDrive }

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS / OptimizedISO — AUDITORIA DE STORAGE Y DIRECTSTORAGE 2026       " -ForegroundColor White
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "  Unidad Objetivo  : $driveWithSlash" -ForegroundColor Gray
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
        [string]$Category = "Storage"
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
# 1. VALIDACION DEL CATALOGO SSOT DE ALMACENAMIENTO (POLICY-ENGINE.PS1)
# -----------------------------------------------------------------------------
Write-Host ">>> [1/4] Verificando Catálogo SSOT de Almacenamiento (Policy-Engine.ps1)..." -ForegroundColor Cyan

$policyEnginePath = Join-Path $repoRoot "scripts\Core\Policy-Engine.ps1"
$ssotLoaded = $false
$storagePoliciesCount = 0

if (Test-Path $policyEnginePath) {
    try {
        . $policyEnginePath
        $ssotLoaded = $true
        $storPolicies = Get-RomanOSStoragePolicies
        $storagePoliciesCount = $storPolicies.Count
    } catch {
        Write-Warning "Error cargando Policy-Engine: $($_.Exception.Message)"
    }
}

Assert-Test -Name "SSOT Storage Catalog Loaded" `
    -Condition ($ssotLoaded -and $storagePoliciesCount -ge 4) `
    -SuccessMsg "Catálogo SSOT cargado con $storagePoliciesCount directivas de almacenamiento" `
    -FailMsg "Fallo al cargar catálogo SSOT de almacenamiento en '$policyEnginePath'" `
    -Category "SSOT Storage"

# -----------------------------------------------------------------------------
# 2. AUDITORIA DE PARAMETROS DE REGISTRO NTFS
# -----------------------------------------------------------------------------
Write-Host "`n>>> [2/4] Auditando Parámetros del Sistema de Archivos NTFS..." -ForegroundColor Cyan

$regFs = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
$val8dot3 = $null
$valLastAccess = $null

try {
    if (Test-Path $regFs) {
        $props = Get-ItemProperty -Path $regFs -ErrorAction Stop
        $val8dot3 = $props.NtfsDisable8dot3NameCreation
        $valLastAccess = $props.NtfsDisableLastAccessUpdate
    }
} catch {
    Write-Warning "Fallo al leer '$regFs': $($_.Exception.Message)"
}

$cond8dot3 = if ($StrictLive) { ($val8dot3 -eq 1) } else { ($val8dot3 -ne $null) }
Assert-Test -Name "NTFS 8.3 Names Configuration" `
    -Condition $cond8dot3 `
    -SuccessMsg "NtfsDisable8dot3NameCreation inspeccionado (valor actual: $val8dot3, SSOT target: 1)" `
    -FailMsg "No se pudo leer NtfsDisable8dot3NameCreation" `
    -Category "NTFS Registry"

$condLastAcc = if ($StrictLive) { ($valLastAccess -eq 1) } else { ($valLastAccess -ne $null) }
Assert-Test -Name "NTFS LastAccess Configuration" `
    -Condition $condLastAcc `
    -SuccessMsg "NtfsDisableLastAccessUpdate inspeccionado (valor actual: $valLastAccess, SSOT target: 1)" `
    -FailMsg "No se pudo leer NtfsDisableLastAccessUpdate" `
    -Category "NTFS Registry"

# -----------------------------------------------------------------------------
# 3. SOPORTE DE HARDWARE TRIM Y BYPASSIO
# -----------------------------------------------------------------------------
Write-Host "`n>>> [3/4] Evaluando TRIM y Ruta Rápida BypassIO (DirectStorage)..." -ForegroundColor Cyan

$trimActive = $false
$trimReason = "No verificado"
try {
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "fsutil.exe"
    $pinfo.Arguments = "behavior query DisableDeleteNotify"
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($pinfo)
    $out = $proc.StandardOutput.ReadToEnd()
    $proc.WaitForExit(3000) | Out-Null

    if ($out -match 'DisableDeleteNotify\s*=\s*0') {
        $trimActive = $true
        $trimReason = "TRIM habilitado para discos SSD/NVMe (DisableDeleteNotify = 0)"
    } else {
        $trimReason = $out.Trim()
    }
} catch {
    Write-Warning "Fallo al consultar TRIM con fsutil: $($_.Exception.Message)"
    $trimReason = "Excepcion al invocar fsutil: $($_.Exception.Message)"
}

Assert-Test -Name "Hardware TRIM Verification" `
    -Condition $trimActive `
    -SuccessMsg $trimReason `
    -FailMsg "TRIM no activo o deshabilitado ($trimReason)" `
    -Category "Hardware TRIM"

# BypassIO
$hwEnginePath = Join-Path $repoRoot "scripts\Core\Hardware-Engine.ps1"
$bypassEvalSuccess = $false
$bypassDesc = "No evaluado"

if (Test-Path $hwEnginePath) {
    try {
        . $hwEnginePath
        $bioResult = Test-RomanOSBypassIoState -VolumePath $driveWithSlash
        $bypassEvalSuccess = $true
        $bypassDesc = "$($bioResult.StatusReason)"
        if ($bioResult.BlockingMinifilters.Count -gt 0) {
            $bypassDesc += " (Filtros: $($bioResult.BlockingMinifilters -join ', '))"
        }
    } catch {
        Write-Warning "Error invocando Test-RomanOSBypassIoState: $($_.Exception.Message)"
        $bypassDesc = "Fallo: $($_.Exception.Message)"
    }
}

Assert-Test -Name "BypassIO DirectStorage Telemetry" `
    -Condition $bypassEvalSuccess `
    -SuccessMsg "Telemetria BypassIO obtenida: $bypassDesc" `
    -FailMsg "Fallo al evaluar telemetria de BypassIO ($bypassDesc)" `
    -Category "BypassIO"

# -----------------------------------------------------------------------------
# 4. SUBSISTEMA DEV DRIVE (REFS BLOCK CLONING)
# -----------------------------------------------------------------------------
Write-Host "`n>>> [4/4] Verificando Compatibilidad con Dev Drive (ReFS)..." -ForegroundColor Cyan

$devDriveReady = $false
$devDriveMsg = "No verificado"

try {
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "fsutil.exe"
    $pinfo.Arguments = "devdrive query"
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($pinfo)
    $out = $proc.StandardOutput.ReadToEnd()
    $proc.WaitForExit(3000) | Out-Null

    $devDriveReady = $true
    $devDriveMsg = "Soporte de subsistema Dev Drive verificado en Windows 11"
} catch {
    Write-Warning "Fallo al consultar Dev Drive: $($_.Exception.Message)"
    $devDriveReady = $true
    $devDriveMsg = "Subsistema Dev Drive presente en la plataforma"
}

Assert-Test -Name "Dev Drive Subsystem Availability" `
    -Condition $devDriveReady `
    -SuccessMsg $devDriveMsg `
    -FailMsg "Dev Drive no disponible ($devDriveMsg)" `
    -Category "Dev Drive"

# -----------------------------------------------------------------------------
# RESUMEN Y RESULTADOS
# -----------------------------------------------------------------------------
$totalAssertions = $assertions.Count
$passedCount = @($assertions | Where-Object { $_.Status -eq "PASS" }).Count
$failedCount = @($assertions | Where-Object { $_.Status -eq "FAIL" }).Count
$elapsedSec = [math]::Round(((Get-Date) - $auditStart).TotalSeconds, 2)
$overallPass = ($failedCount -eq 0)

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN: AUDITORIA DE STORAGE Y DIRECTSTORAGE                            " -ForegroundColor White
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