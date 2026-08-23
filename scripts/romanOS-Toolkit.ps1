<#
.SYNOPSIS
    romanOS-Toolkit.ps1 - Hub Maestro de Optimizacion, Diagnostico, Mantenimiento y Seguridad
    Orquestador Central Desacoplado (Zero-Resident Footprint)

.DESCRIPTION
    Panel de control unificado y orquestador maestro para la suite de herramientas romanOS.
    Permite acceder de forma rapida e interactiva a todos los modulos de optimizacion extrema
    para gaming/streaming, analisis de red, mantenimiento profundo, auditoria forense post-instalacion
    y escaneo de seguridad desacoplado. Funciona bajo demanda sin sobrecargar el sistema con
    procesos residentes.

.PARAMETER Module
    Nombre del modulo a ejecutar directamente (Gaming, Network, Maintenance, Diagnostics, Security, Dashboards).

.PARAMETER ShowDashboards
    Genera y abre los dashboards HTML interactivos de salud y seguridad en el navegador.

.EXAMPLE
    .\romanOS-Toolkit.ps1

.EXAMPLE
    .\romanOS-Toolkit.ps1 -Module Maintenance
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("Gaming", "Network", "Maintenance", "Diagnostics", "Security", "Dashboards", "QuickActions")]
    [string]$Module,
    [switch]$ShowDashboards
)

# -----------------------------------------------------------------------------
# 0. CONFIGURACION DE ENTORNO Y AUTO-ELEVACION UAC
# -----------------------------------------------------------------------------
$ErrorActionPreference = 'Continue'
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue } catch {}

# Auto-elevacion de privilegios
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    if ($PSCmdlet.ShouldProcess("powershell.exe", "Auto-elevar privilegios de Administrador UAC")) {
        Write-Host "[!] Elevando privilegios de Administrador (UAC)..." -ForegroundColor Yellow
        $scriptPath = $MyInvocation.MyCommand.Definition
        if (-not $scriptPath) { $scriptPath = $PSCommandPath }
        
        $argList = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath)
        if ($Module) { $argList += @('-Module', $Module) }
        if ($ShowDashboards) { $argList += '-ShowDashboards' }
        
        try {
            Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
        } catch {
            Write-Error "Fallo al solicitar elevacion UAC: $($_.Exception.Message)"
        }
        exit
    }
}

# Resolucion de rutas de scripts hermanos
$searchDirs = @(
    $PSScriptRoot,
    (Join-Path $PSScriptRoot "scripts"),
    "$env:WINDIR\Setup\Scripts",
    "C:\Windows\Setup\Scripts",
    "C:\OptimizedISO\scripts"
)

function Resolve-ToolScript {
    param([string]$ScriptName)
    foreach ($dir in $script:searchDirs) {
        if ($dir -and (Test-Path $dir)) {
            $candidate = Join-Path $dir $ScriptName
            if (Test-Path $candidate) {
                return (Resolve-Path $candidate).Path
            }
        }
    }
    return $null
}

# -----------------------------------------------------------------------------
# 1. FUNCIONES AUXILIARES Y DASHBOARD DE ESTADO
# -----------------------------------------------------------------------------
function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ==========================================================================" -ForegroundColor Cyan
    Write-Host "   ____                               ____    _____             _ _    _ _  " -ForegroundColor Cyan
    Write-Host "  |  _ \ ___  _ __ ___   __ _ _ __   / __ \  |_   _|__   ___ | | | _(_) |_ " -ForegroundColor Cyan
    Write-Host "  | |_) / _ \| '_ ` _ \ / _` | '_ \ / / _` |   | |/ _ \ / _ \| | |/ / | __|" -ForegroundColor Cyan
    Write-Host "  |  _ < (_) | | | | | | (_| | | | | | (_| |   | | (_) | (_) | |   <| | |_ " -ForegroundColor Cyan
    Write-Host "  |_| \_\___/|_| |_| |_|\__,_|_| |_|\ \__,_|   |_|\___/ \___/|_|_|\_\_|\__|" -ForegroundColor Cyan
    Write-Host "                                     \____/                                " -ForegroundColor Cyan
    Write-Host "  Toolkit Maestro de Optimizacion, Gaming, Mantenimiento y Seguridad        " -ForegroundColor DarkCyan
    Write-Host "  ==========================================================================" -ForegroundColor Cyan
    
    # Telemetria rapida en encabezado
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $sysDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
        $freeGB = if ($sysDrive) { [math]::Round($sysDrive.FreeSpace / 1GB, 1) } else { "N/A" }
        $totalGB = if ($sysDrive) { [math]::Round($sysDrive.Size / 1GB, 1) } else { "N/A" }
        
        Write-Host "  Sistema   : $($os.Caption) ($($os.OSArchitecture))" -ForegroundColor Gray
        Write-Host "  Equipo    : $env:COMPUTERNAME | Usuario: $env:USERNAME" -ForegroundColor Gray
        Write-Host "  Disco C:  : $freeGB GB libres de $totalGB GB" -ForegroundColor Gray
    } catch {}
    Write-Host "  --------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}

# -----------------------------------------------------------------------------
# 2. INVOCADORES DE MODULOS
# -----------------------------------------------------------------------------
function Invoke-GamingModule {
    $scriptFile = Resolve-ToolScript "Win11-Debloat-v3-Adaptive.ps1"
    if ($scriptFile) {
        Write-Host "`n[*] Iniciando Modulo de Optimizacion y Debloat Adaptativo...`n" -ForegroundColor Green
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile
    } else {
        Write-Host "[ERROR] No se encontro Win11-Debloat-v3-Adaptive.ps1" -ForegroundColor Red
        pause
    }
}

function Invoke-NetworkModule {
    $scriptFile = Resolve-ToolScript "Win11-Network-Diagnostics-Optimizer.ps1"
    if ($scriptFile) {
        Write-Host "`n[*] Iniciando Modulo de Diagnostico de Red y Latencia...`n" -ForegroundColor Green
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile
    } else {
        Write-Host "[ERROR] No se encontro Win11-Network-Diagnostics-Optimizer.ps1" -ForegroundColor Red
        pause
    }
}

function Invoke-MaintenanceModule {
    $scriptFile = Resolve-ToolScript "Invoke-WindowsMaintenance.ps1"
    if ($scriptFile) {
        Write-Host "`n[*] Iniciando Modulo de Mantenimiento y Reparacion...`n" -ForegroundColor Green
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile
    } else {
        Write-Host "[ERROR] No se encontro Invoke-WindowsMaintenance.ps1" -ForegroundColor Red
        pause
    }
}

function Invoke-DiagnosticsModule {
    $scriptFile = Resolve-ToolScript "PostInstall-Diagnostics.ps1"
    if ($scriptFile) {
        Write-Host "`n[*] Iniciando Modulo de Auditoria Post-Instalacion y Salud...`n" -ForegroundColor Green
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile -DesktopOutput
    } else {
        Write-Host "[ERROR] No se encontro PostInstall-Diagnostics.ps1" -ForegroundColor Red
        pause
    }
}

function Invoke-SecurityModule {
    $scriptFile = Resolve-ToolScript "Invoke-WindowsSecurityHardening.ps1"
    if ($scriptFile) {
        Write-Host "`n[*] Iniciando Modulo de Auditoria de Seguridad Desacoplada...`n" -ForegroundColor Green
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile -ShowReport
    } else {
        Write-Host "[ERROR] No se encontro Invoke-WindowsSecurityHardening.ps1" -ForegroundColor Red
        pause
    }
}

function Invoke-OpenDashboards {
    Write-Host "`n[*] Generando y abriendo Dashboards Visuales HTML...`n" -ForegroundColor Cyan
    
    $diagScript = Resolve-ToolScript "PostInstall-Diagnostics.ps1"
    $secScript  = Resolve-ToolScript "Invoke-WindowsSecurityHardening.ps1"
    
    if ($diagScript) {
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $diagScript -DesktopOutput
    }
    if ($secScript) {
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $secScript -AuditOnly
    }
    
    # Buscar HTMLs generados
    $desktopPath = [Environment]::GetFolderPath('CommonDesktopDirectory')
    if (-not $desktopPath -or -not (Test-Path $desktopPath)) {
        $desktopPath = if ($env:PUBLIC) { "$env:PUBLIC\Desktop" } else { "C:\Users\Public\Desktop" }
    }
    
    $diagHtml = Join-Path $desktopPath "INFORME_INSTALACION.html"
    $secHtml  = Join-Path $desktopPath "INFORME_SEGURIDAD.html"
    
    if (Test-Path $diagHtml) { Start-Process -FilePath $diagHtml }
    if (Test-Path $secHtml)  { Start-Process -FilePath $secHtml }
    
    Write-Host "`n[OK] Dashboards abiertos en el navegador web local." -ForegroundColor Green
    Start-Sleep -Seconds 2
}

function Show-QuickActionsMenu {
    Show-Header
    Write-Host "  ACCIONES RAPIDAS DE SISTEMA (SISTEMA & RED):" -ForegroundColor Yellow
    Write-Host "  --------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  [1] Vaciar Cache DNS (ipconfig /flushdns)" -ForegroundColor White
    Write-Host "  [2] Reiniciar Explorador de Windows (explorer.exe)" -ForegroundColor White
    Write-Host "  [3] Abrir Panel de Control Maestro (God Mode)" -ForegroundColor White
    Write-Host "  [4] Reparacion Rapida de Imagen (DISM RestoreHealth + SFC Scannow)" -ForegroundColor White
    Write-Host "  [5] Limpieza Inmediata de Shaders GPU (DirectX, NVIDIA, AMD)" -ForegroundColor White
    Write-Host "  [6] Ejecutar SSD TRIM en todas las unidades compatibles" -ForegroundColor White
    Write-Host "  [0] Volver al Menu Principal" -ForegroundColor Gray
    Write-Host ""
    
    $actChoice = Read-Host "  Seleccione una accion"
    switch ($actChoice) {
        "1" {
            Write-Host "`n[+] Vaciando cache DNS..." -ForegroundColor Cyan
            ipconfig /flushdns
            pause
        }
        "2" {
            Write-Host "`n[+] Reiniciando Explorador..." -ForegroundColor Cyan
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
            Start-Process "explorer.exe"
        }
        "3" {
            Write-Host "`n[+] Abriendo God Mode..." -ForegroundColor Cyan
            Start-Process "explorer.exe" -ArgumentList "shell:::{ED7BA470-8E54-465E-825C-99712043E01C}"
        }
        "4" {
            Write-Host "`n[+] Ejecutando DISM y SFC..." -ForegroundColor Cyan
            DISM /Online /Cleanup-Image /RestoreHealth
            sfc /scannow
            pause
        }
        "5" {
            Write-Host "`n[+] Limpiando shaders GPU..." -ForegroundColor Cyan
            $shaderDirs = @(
                "$env:LOCALAPPDATA\D3DSCache",
                "$env:LOCALAPPDATA\NVIDIA\DXCache",
                "$env:LOCALAPPDATA\AMD\DxCache"
            )
            foreach ($sd in $shaderDirs) {
                if (Test-Path $sd) {
                    Get-ChildItem -Path $sd -Recurse -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                    Write-Host "    - Limpiado: $sd" -ForegroundColor Gray
                }
            }
            Write-Host "[OK] Caché de shaders limpiada." -ForegroundColor Green
            pause
        }
        "6" {
            Write-Host "`n[+] Ejecutando ReTrim en volumenes SSD..." -ForegroundColor Cyan
            try {
                Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' } | ForEach-Object {
                    Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -Verbose
                }
            } catch {
                Write-Host "Error ejecutando Optimize-Volume: $($_.Exception.Message)" -ForegroundColor Red
            }
            pause
        }
        default { return }
    }
}

# -----------------------------------------------------------------------------
# 3. BUCLE PRINCIPAL INTERACTIVO
# -----------------------------------------------------------------------------
if ($Module) {
    switch ($Module) {
        "Gaming"       { Invoke-GamingModule; exit }
        "Network"      { Invoke-NetworkModule; exit }
        "Maintenance"  { Invoke-MaintenanceModule; exit }
        "Diagnostics"  { Invoke-DiagnosticsModule; exit }
        "Security"     { Invoke-SecurityModule; exit }
        "Dashboards"   { Invoke-OpenDashboards; exit }
        "QuickActions" { Show-QuickActionsMenu; exit }
    }
}

if ($ShowDashboards) {
    Invoke-OpenDashboards
    exit
}

while ($true) {
    Show-Header
    Write-Host "  MODULOS DEL TOOLKIT MAESTRO:" -ForegroundColor Cyan
    Write-Host "  --------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  [1] ⚡ Optimizacion Gaming & Hardware (HAGS, MSI Mode, Latencia, Debloat)" -ForegroundColor Green
    Write-Host "  [2] 🌐 Diagnostico de Red & Latencia (Benchmarks DNS, TCP/IP, Sockets)" -ForegroundColor White
    Write-Host "  [3] 🧹 Mantenimiento & Limpieza Profunda (WinSxS DISM, Shaders, SSD TRIM)" -ForegroundColor White
    Write-Host "  [4] 📋 Auditoria Forense Post-Instalacion & Salud (Panther, CompactOS, PnP)" -ForegroundColor White
    Write-Host "  [5] 🛡️  Auditoria de Seguridad & Hardening (ASR, VBS, Protocolos On-Demand)" -ForegroundColor White
    Write-Host "  [6] 📊 Generar y Abrir Dashboards HTML de Salud y Seguridad" -ForegroundColor Cyan
    Write-Host "  [7] 🔧 Acciones Rapidas (Flush DNS, Restart Explorer, GodMode, Reparacion)" -ForegroundColor Yellow
    Write-Host "  [0] ❌ Salir del Toolkit" -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "  Seleccione una opcion [0-7]"
    
    switch ($choice) {
        "1" { Invoke-GamingModule }
        "2" { Invoke-NetworkModule }
        "3" { Invoke-MaintenanceModule }
        "4" { Invoke-DiagnosticsModule }
        "5" { Invoke-SecurityModule }
        "6" { Invoke-OpenDashboards }
        "7" { Show-QuickActionsMenu }
        "0" {
            Write-Host "`n  Cerrando romanOS Toolkit Maestro...`n" -ForegroundColor Gray
            exit
        }
        default {
            Write-Host "  Opcion invalida." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
