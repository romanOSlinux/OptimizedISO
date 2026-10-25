<#
.SYNOPSIS
    Lanzador Universal Tri-Modal para el ecosistema romanOS (Windows 11).
.DESCRIPTION
    Punto de entrada universal y unificado para romanOS.
    Soporta 3 modalidades de arranque automatico:
      1. Local / USB Offline: Ejecuta el ecosistema completo desde la unidad local o USB sin conexion.
      2. Web 1-Liner: Descarga y orquesta en memoria o carpeta temporal para equipos remotos.
      3. Despliegue Post-Instalacion: Ejecucion directa en C:\Windows\Setup\Scripts o Escritorio Publico.

    Implementa:
      - Deteccion de permisos y auto-elevacion silenciosa UAC (verb RunAs).
      - Inicializacion segura en modo Single-Threaded Apartment (-STA) para WPF/XAML.
      - Enlace transparente con romanOS Control Center.
      - Modo simulado (-WhatIf / -Simulate) conforme a la Regla 14.

.PARAMETER Offline
    Fuerza la ejecucion en modo estrictamente offline/local sin intentar conexiones de red.
.PARAMETER SkipElevation
    Omite la solicitud automatica de elevacion UAC (util para auditorias de solo lectura).
.PARAMETER NoGui
    Ejecuta comprobaciones de diagnostico sin inicializar la interfaz grafica WPF.
.PARAMETER RepoUrl
    URL base para la descarga de componentes en modo Web 1-Liner.
.PARAMETER PassThru
    Devuelve un objeto de diagnostico con el estado del bootstrap.
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Offline,
    [switch]$SkipElevation,
    [switch]$NoGui,
    [string]$RepoUrl = "https://raw.githubusercontent.com/romanOSlinux/OptimizedISO/main",
    [switch]$PassThru
)

# ==============================================================================
#  romanOS - Lanzador Universal Tri-Modal (PLAN-0161)
# ==============================================================================

$isSimulated = ($null -ne $PSCmdlet -and $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf')) -or [bool]$WhatIfPreference
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ------------------------------------------------------------------------------
# 1. Verificacion y Auto-Elevacion UAC
# ------------------------------------------------------------------------------
if (-not $isAdmin -and -not $SkipElevation -and -not $isSimulated) {
    Write-Host "[romanOS] Se requieren privilegios de Administrador. Elevando proceso..." -ForegroundColor Yellow
    try {
        if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
            $argList = "-STA -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            if ($Offline) { $argList += " -Offline" }
            if ($NoGui) { $argList += " -NoGui" }
            Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $argList -Verb RunAs
            exit 0
        } else {
            # Modo Web en memoria (iex)
            $webCmd = "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13; `$r = irm '$RepoUrl/Lanzar-romanOS.ps1'; iex (`$r.TrimStart([char]0xFEFF))"
            Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList "-STA -NoProfile -ExecutionPolicy Bypass -Command `"$webCmd`"" -Verb RunAs
            exit 0
        }
    } catch {
        Write-Warning "[romanOS] No se pudo elevar automaticamente los privilegios: $($_.Exception.Message)"
    }
}

# ------------------------------------------------------------------------------
# 2. Resolucion de Modalidad de Ejecucion (Local/USB vs Web)
# ------------------------------------------------------------------------------
$baseDirs = @()
if ($PSScriptRoot) {
    $baseDirs += $PSScriptRoot
    $baseDirs += (Join-Path $PSScriptRoot "scripts")
    $baseDirs += (Join-Path $PSScriptRoot "..\scripts")
}
if ($env:WINDIR) {
    $baseDirs += (Join-Path $env:WINDIR "Setup\Scripts")
    $baseDirs += (Join-Path $env:WINDIR "Setup\Scripts\GUI")
}
$baseDirs += "C:\Windows\Setup\Scripts"
$baseDirs += (Get-Location).Path
$baseDirs += "C:\OptimizedISO"
$baseDirs += "D:\OptimizedISO"
if ($env:SystemDrive) {
    $baseDirs += (Join-Path $env:SystemDrive "OptimizedISO")
}

$controlCenterScript = $null
$policyEngineScript = $null
$hardwareEngineScript = $null

foreach ($dir in $baseDirs) {
    if (-not $dir -or -not (Test-Path $dir)) { continue }

    $ccCandidate = Join-Path $dir "romanOS-ControlCenter.ps1"
    if (-not (Test-Path $ccCandidate)) { $ccCandidate = Join-Path $dir "scripts\GUI\romanOS-ControlCenter.ps1" }
    if (-not (Test-Path $ccCandidate)) { $ccCandidate = Join-Path $dir "GUI\romanOS-ControlCenter.ps1" }

    if ((Test-Path $ccCandidate) -and -not $controlCenterScript) {
        $controlCenterScript = (Resolve-Path $ccCandidate).Path
    }

    $peCandidate = Join-Path $dir "Policy-Engine.ps1"
    if (-not (Test-Path $peCandidate)) { $peCandidate = Join-Path $dir "scripts\Core\Policy-Engine.ps1" }
    if (-not (Test-Path $peCandidate)) { $peCandidate = Join-Path $dir "Core\Policy-Engine.ps1" }
    if ((Test-Path $peCandidate) -and -not $policyEngineScript) {
        $policyEngineScript = (Resolve-Path $peCandidate).Path
    }

    $heCandidate = Join-Path $dir "Hardware-Engine.ps1"
    if (-not (Test-Path $heCandidate)) { $heCandidate = Join-Path $dir "scripts\Core\Hardware-Engine.ps1" }
    if (-not (Test-Path $heCandidate)) { $heCandidate = Join-Path $dir "Core\Hardware-Engine.ps1" }
    if ((Test-Path $heCandidate) -and -not $hardwareEngineScript) {
        $hardwareEngineScript = (Resolve-Path $heCandidate).Path
    }
}

$executionMode = "Desconocido"

if ($controlCenterScript -and (Test-Path $controlCenterScript)) {
    $executionMode = "Local-USB-Offline"
} else {
    if ($Offline) {
        Write-Error "[romanOS] Error: No se encontraron los archivos locales del producto y se especifico el switch -Offline."
        exit 1
    }
    $executionMode = "Web-Remote-Bootstrap"
}

# ------------------------------------------------------------------------------
# 3. Tratamiento para Modo Web 1-Liner (Descarga en Memoria / Cache Efimera)
# ------------------------------------------------------------------------------
if ($executionMode -eq "Web-Remote-Bootstrap") {
    Write-Host "[romanOS] Detectado modo Web 1-Liner. Descargando componentes esenciales..." -ForegroundColor Cyan
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
        $tempDir = Join-Path $env:TEMP "romanOS_Universal"
        if (-not (Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory -Force | Out-Null }
        $coreDir = Join-Path $tempDir "Core"
        if (-not (Test-Path $coreDir)) { New-Item -Path $coreDir -ItemType Directory -Force | Out-Null }
        $modulesDir = Join-Path $tempDir "Modules"
        if (-not (Test-Path $modulesDir)) { New-Item -Path $modulesDir -ItemType Directory -Force | Out-Null }

        $filesToFetch = @(
            @{ Remote = "$RepoUrl/scripts/Core/Policy-Engine.ps1"; Local = (Join-Path $tempDir "Policy-Engine.ps1") },
            @{ Remote = "$RepoUrl/scripts/Core/Policy-Engine.ps1"; Local = (Join-Path $coreDir "Policy-Engine.ps1") },
            @{ Remote = "$RepoUrl/scripts/Core/Hardware-Engine.ps1"; Local = (Join-Path $tempDir "Hardware-Engine.ps1") },
            @{ Remote = "$RepoUrl/scripts/Core/Hardware-Engine.ps1"; Local = (Join-Path $coreDir "Hardware-Engine.ps1") },
            @{ Remote = "$RepoUrl/scripts/Core/UI-Engine.ps1"; Local = (Join-Path $tempDir "UI-Engine.ps1") },
            @{ Remote = "$RepoUrl/scripts/Core/UI-Engine.ps1"; Local = (Join-Path $coreDir "UI-Engine.ps1") },
            @{ Remote = "$RepoUrl/scripts/GUI/romanOS-ControlCenter.ps1"; Local = (Join-Path $tempDir "romanOS-ControlCenter.ps1") },
            @{ Remote = "$RepoUrl/scripts/Modules/Desktop-Helpers.ps1"; Local = (Join-Path $modulesDir "Desktop-Helpers.ps1") },
            @{ Remote = "$RepoUrl/scripts/Modules/Win11-Network-Diagnostics-Optimizer.ps1"; Local = (Join-Path $modulesDir "Win11-Network-Diagnostics-Optimizer.ps1") },
            @{ Remote = "$RepoUrl/scripts/Modules/Deploy-AppProfiles.ps1"; Local = (Join-Path $modulesDir "Deploy-AppProfiles.ps1") }
        )

        foreach ($item in $filesToFetch) {
            if (-not (Test-Path $item.Local) -or (Get-Item $item.Local).Length -eq 0) {
                Invoke-WebRequest -Uri $item.Remote -OutFile $item.Local -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
            }
        }
        $controlCenterScript = Join-Path $tempDir "romanOS-ControlCenter.ps1"
        $executionMode = "Web-Cached-Local"
    } catch {
        Write-Error "[romanOS] Error al descargar componentes esenciales desde la Web: $($_.Exception.Message)"
        exit 1
    }
}

# ------------------------------------------------------------------------------
# 4. Modo Simulado (-WhatIf) / Validacion Pre-Vuelo
# ------------------------------------------------------------------------------
if ($isSimulated) {
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "  romanOS - Diagnostico Pre-Vuelo del Punto de Entrada Tri-Modal          " -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "  Modalidad Detectada : $executionMode" -ForegroundColor Cyan
    Write-Host "  Nivel de Elevacion  : $(if ($isAdmin) { 'Administrador (Elevado)' } else { 'Usuario Estandar' })" -ForegroundColor Cyan
    Write-Host "  Control Center PS1  : $controlCenterScript" -ForegroundColor Cyan
    Write-Host "  Policy-Engine SSOT  : $policyEngineScript" -ForegroundColor Cyan
    Write-Host "  Hardware-Engine HAL : $hardwareEngineScript" -ForegroundColor Cyan
    Write-Host "  Modo Simulado       : Activo (WhatIf) - Cero mutaciones en el sistema" -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "[WhatIf] romanOS Launcher validado exitosamente en modo simulado." -ForegroundColor Green

    if ($PassThru) {
        return [PSCustomObject]@{
            Mode              = $executionMode
            IsElevated        = $isAdmin
            ControlCenterPath = $controlCenterScript
            PolicyEnginePath  = $policyEngineScript
            HardwareEnginePath= $hardwareEngineScript
            Status            = "PASS"
        }
    }
    exit 0
}

if ($PassThru) {
    return [PSCustomObject]@{
        Mode              = $executionMode
        IsElevated        = $isAdmin
        ControlCenterPath = $controlCenterScript
        PolicyEnginePath  = $policyEngineScript
        HardwareEnginePath= $hardwareEngineScript
        Status            = "READY"
    }
}

if ($NoGui) {
    Write-Host "[romanOS] Punto de entrada verificado. Modo NoGui seleccionado. Finalizando con exito." -ForegroundColor Green
    exit 0
}

# ------------------------------------------------------------------------------
# 5. Invocacion de romanOS Control Center (-STA Obligatorio)
# ------------------------------------------------------------------------------
if ($controlCenterScript -and (Test-Path $controlCenterScript)) {
    if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq [System.Threading.ApartmentState]::STA) {
        & "$controlCenterScript"
    } else {
        Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList "-STA -NoProfile -ExecutionPolicy Bypass -File `"$controlCenterScript`""
    }
    exit 0
} else {
    Write-Error "[romanOS] Error critico: No se pudo resolver la ruta de romanOS-ControlCenter.ps1."
    exit 1
}