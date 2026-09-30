<#
.SYNOPSIS
    Purge-PendingWindowsUpdate.ps1 - Purga Segura de Actualizaciones Pendientes
    Componente Oficial de romanOS Host-Tools (PLAN-0148).

.DESCRIPTION
    Cancela y purga descargas de actualizaciones en cola de reinicio (como saltos
    no deseados de versiones mayores) y vacía la caché de SoftwareDistribution\Download,
    eliminando las banderas de RebootPending y RebootRequired de Windows Update.

    Requiere elevación de Administrador (auto-eleva vía UAC RunAs).
    Compatible con Windows PowerShell 5.1 y PowerShell 7+.
    Codificación estricta UTF-8 con BOM.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$NoRestartServices
)

# -----------------------------------------------------------------------------
# 1. AUTO-ELEVACIÓN ADMINISTRATIVA (UAC)
# -----------------------------------------------------------------------------
if (-not $PSCmdlet.ShouldProcess("Sistema", "Purgar descargas de actualizaciones en cola y limpiar banderas de reinicio")) {
    return
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[UAC] Solicitando elevacion administrativa para purgar actualizaciones pendientes..." -ForegroundColor Yellow
    $argList = @("-STA", "-NoProfile", "-ExecutionPolicy Bypass", "-File", "`"$PSCommandPath`"")
    if ($NoRestartServices) { $argList += "-NoRestartServices" }
    Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
    exit
}

# -----------------------------------------------------------------------------
# 2. DETENCIÓN TEMPORAL DE SERVICIOS
# -----------------------------------------------------------------------------
Write-Host "`n=== ROMANOS: PURGA SEGURA DE ACTUALIZACIONES EN COLA ===" -ForegroundColor Cyan
Write-Host "[1/5] Deteniendo servicios de Windows Update y Orquestacion..." -ForegroundColor Gray

$targetServices = @("wuauserv", "UsoSvc", "BITS", "dosvc")
foreach ($svcName in $targetServices) {
    try {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq "Running") {
            Write-Host "  - Deteniendo servicio '$svcName'..." -ForegroundColor DarkGray
            Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
        }
    } catch {
        Write-Warning "No se pudo detener el servicio '$svcName': $($_.Exception.Message)"
    }
}

# -----------------------------------------------------------------------------
# 3. LIMPIEZA DE BANDERAS DE REINICIO PENDIENTE EN REGISTRO
# -----------------------------------------------------------------------------
Write-Host "[2/5] Purgando banderas de reinicio pendiente..." -ForegroundColor Gray

$wuRebootPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
if (Test-Path $wuRebootPath) {
    try {
        Remove-Item -Path $wuRebootPath -Recurse -Force -ErrorAction Stop
        Write-Host "  [OK] Clave RebootRequired eliminada satisfactoriamente." -ForegroundColor Green
    } catch {
        Write-Warning "Fallo al remover RebootRequired: $($_.Exception.Message)"
    }
} else {
    Write-Host "  [INFO] No habia clave RebootRequired en WindowsUpdate." -ForegroundColor DarkGray
}

$cbsRebootPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
if (Test-Path $cbsRebootPath) {
    try {
        Remove-Item -Path $cbsRebootPath -Recurse -Force -ErrorAction Stop
        Write-Host "  [OK] Clave RebootPending de CBS eliminada satisfactoriamente." -ForegroundColor Green
    } catch {
        Write-Warning "Fallo al remover RebootPending de CBS: $($_.Exception.Message)"
    }
} else {
    Write-Host "  [INFO] No habia clave RebootPending en CBS." -ForegroundColor DarkGray
}

# -----------------------------------------------------------------------------
# 4. PURGA DE ARCHIVOS DE DESCARGA EN SOFTWAREDISTRIBUTION
# -----------------------------------------------------------------------------
Write-Host "[3/5] Purgando directorio de descargas SoftwareDistribution\Download..." -ForegroundColor Gray

$downloadPath = Join-Path $env:SystemRoot "SoftwareDistribution\Download"
if (Test-Path $downloadPath) {
    try {
        $items = Get-ChildItem -Path $downloadPath -Recurse -Force -ErrorAction SilentlyContinue
        $itemCount = ($items | Measure-Object).Count
        Remove-Item -Path "$downloadPath\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Descargas temporales purgadas ($itemCount elementos removidos)." -ForegroundColor Green
    } catch {
        Write-Warning "Aviso al limpiar archivos en SoftwareDistribution: $($_.Exception.Message)"
    }
}

# -----------------------------------------------------------------------------
# 5. REINICIO DE SERVICIOS
# -----------------------------------------------------------------------------
if (-not $NoRestartServices) {
    Write-Host "[4/5] Restaurando servicios de Windows Update a modo bajo demanda..." -ForegroundColor Gray
    try {
        & sc.exe config wuauserv start= demand 2>&1 | Out-Null
        & sc.exe config UsoSvc start= demand 2>&1 | Out-Null
        Start-Sleep -Milliseconds 500
    } catch {
        Write-Warning "Aviso al ajustar tipo de inicio de servicios: $($_.Exception.Message)"
    }
}

# -----------------------------------------------------------------------------
# 6. VERIFICACIÓN FINAL DE ESTADO
# -----------------------------------------------------------------------------
Write-Host "[5/5] Verificando estado final del sistema..." -ForegroundColor Gray
$stillWuReboot = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
$stillCbsReboot = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"

if (-not $stillWuReboot -and -not $stillCbsReboot) {
    Write-Host "`n>>> [EXITO TOTAL] La actualizacion pendiente ha sido purgada con exito." -ForegroundColor Green
    Write-Host ">>> El equipo puede reiniciarse de manera segura sin aplicar la version 26H2.`n" -ForegroundColor Green
} else {
    Write-Warning "Algunas banderas de reinicio persisten en el sistema (WU: $stillWuReboot, CBS: $stillCbsReboot)."
}

if ($Host.Name -notmatch "ServerRemoteHost") {
    Write-Host "Presione cualquier tecla para cerrar esta ventana..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
