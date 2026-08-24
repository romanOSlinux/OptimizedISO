<#
.SYNOPSIS
    Verificador de herramientas de compilacion Windows ADK (oscdimg.exe), DISM y estado de Hyper-V
    Helper para skill windows-adk-hyperv
#>

Write-Host ""
Write-Host "=== DIAGNOSTICO DE ENTORNO WINDOWS ADK Y HYPER-V ===" -ForegroundColor Cyan

# 1. Deteccion de oscdimg.exe
$adkPaths = @(
    "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
    "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\arm64\Oscdimg\oscdimg.exe",
    "C:\Program Files\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
)
$oscdimg = $null
foreach ($p in $adkPaths) {
    if (Test-Path $p) { $oscdimg = $p; break }
}
if (-not $oscdimg) {
    $cmdOscd = Get-Command oscdimg.exe -ErrorAction SilentlyContinue
    if ($cmdOscd) { $oscdimg = $cmdOscd.Source }
}

if ($oscdimg) {
    Write-Host "oscdimg.exe : [OK] $oscdimg" -ForegroundColor Green
} else {
    Write-Host "oscdimg.exe : [WARN] No encontrado en rutas estandar de ADK" -ForegroundColor Yellow
}

# 2. Deteccion de DISM
$dism = Get-Command dism.exe -ErrorAction SilentlyContinue
if ($dism) {
    Write-Host "dism.exe    : [OK] $($dism.Source)" -ForegroundColor Green
} else {
    Write-Host "dism.exe    : [FAIL] dism.exe no disponible en PATH" -ForegroundColor Red
}

# 3. Estado de Modulo Hyper-V
$hypervModule = Get-Module -ListAvailable -Name Hyper-V
if ($hypervModule) {
    Write-Host "Hyper-V Mod : [OK] Modulo Hyper-V disponible" -ForegroundColor Green
} else {
    Write-Host "Hyper-V Mod : [INFO] Hyper-V no instalado o deshabilitado" -ForegroundColor DarkGray
}

# 4. Espacio Libre en Disco C:
$cDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
if ($cDrive) {
    $freeGB = [math]::Round($cDrive.FreeSpace / 1GB, 2)
    if ($freeGB -ge 15) {
        Write-Host "Espacio en C: $freeGB GB libres [OK]" -ForegroundColor Green
    } else {
        Write-Host "Espacio en C: $freeGB GB libres [WARN] Se recomiendan >= 15 GB" -ForegroundColor Yellow
    }
}

Write-Host ""
