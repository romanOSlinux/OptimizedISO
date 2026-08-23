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
    Nombre del modulo a ejecutar directamente (Gaming, Network, Maintenance, Diagnostics, Security, Dashboards, Browsers, QuickActions).

.PARAMETER ShowDashboards
    Genera y abre los dashboards HTML interactivos de salud y seguridad en el navegador.

.EXAMPLE
    .\romanOS-Toolkit.ps1

.EXAMPLE
    .\romanOS-Toolkit.ps1 -Module Maintenance
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("Gaming", "Network", "Maintenance", "Diagnostics", "Security", "Dashboards", "QuickActions", "Browsers")]
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
        Write-Host "  [!] Elevando privilegios de Administrador (UAC)..." -ForegroundColor Yellow
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

# -----------------------------------------------------------------------------
# 1. CARGA DE MOTOR VISUAL UNIFICADO O MICRO-FALLBACK STANDALONE
# -----------------------------------------------------------------------------
$uiEnginePaths = @(
    (Join-Path $PSScriptRoot "Core\UI-Engine.ps1"),
    (Join-Path $PSScriptRoot "UI-Engine.ps1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\UI-Engine.ps1"),
    "C:\Windows\Setup\Scripts\Core\UI-Engine.ps1"
)
$uiLoaded = $false
foreach ($p in $uiEnginePaths) {
    if (Test-Path $p) {
        . $p
        $uiLoaded = $true
        break
    }
}
if (-not $uiLoaded) {
    function Show-UnifiedBanner { param($Title,$Subtitle,[switch]$ShowSystemInfo,[switch]$NoClear) Write-Host "`n=== $Title ($Subtitle) ===`n" -ForegroundColor Cyan }
    function Write-StepHeader   { param($StepNumber,$TotalSteps,$Message) Write-Host "`n>>> [$StepNumber/$TotalSteps] $Message" -ForegroundColor Cyan }
    function Write-SubStep      { param($Message) Write-Host "  -> $Message" -ForegroundColor Gray }
    function Write-OK           { param($Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
    function Write-Warn         { param($Message) Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
    function Write-ErrorMsg     { param($Message) Write-Host "  [ERROR] $Message" -ForegroundColor Red }
    function Write-Info         { param($Message) Write-Host "  [i] $Message" -ForegroundColor DarkGray }
    function Prompt-UnifiedYesNo { param($Prompt,[bool]$Default=$true) $d=if($Default){"S"}else{"N"}; $r=Read-Host "  [?] $Prompt [S/N] (Default: $d)"; if([string]::IsNullOrWhiteSpace($r)){return $Default}; return ($r -match '^(s|si|y|yes)$') }
    function Show-UnifiedMenu   { param($Title,$Options,[int]$DefaultChoice=1,[switch]$AllowCancel,[string]$CancelText="Salir") for($i=0;$i -lt $Options.Count;$i++){ Write-Host "  [$($i+1)] $($Options[$i])" }; if($AllowCancel){ Write-Host "  [0] $CancelText" }; $r=Read-Host "  Opcion"; if(-not $r){return $DefaultChoice}; return [int]$r }
    function Show-UnifiedSummary { param($Title,$Status,$DurationSeconds,$ErrorsCount,$WarnsCount,$Logs) Write-Host "`n=== $($Title): $Status (${DurationSeconds}s) ===`n" -ForegroundColor Cyan }
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
# 2. INVOCADORES DE MODULOS
# -----------------------------------------------------------------------------
function Invoke-GamingModule {
    $scriptFile = Resolve-ToolScript "Win11-Debloat-v3-Adaptive.ps1"
    if ($scriptFile) {
        Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Iniciando Modulo de Optimizacion y Debloat Adaptativo"
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile
    } else {
        Write-ErrorMsg "No se encontro Win11-Debloat-v3-Adaptive.ps1"
        pause
    }
}

function Invoke-NetworkModule {
    $scriptFile = Resolve-ToolScript "Win11-Network-Diagnostics-Optimizer.ps1"
    if ($scriptFile) {
        Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Iniciando Modulo de Diagnostico de Red y Latencia"
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile
    } else {
        Write-ErrorMsg "No se encontro Win11-Network-Diagnostics-Optimizer.ps1"
        pause
    }
}

function Invoke-MaintenanceModule {
    $scriptFile = Resolve-ToolScript "Invoke-WindowsMaintenance.ps1"
    if ($scriptFile) {
        Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Iniciando Modulo de Mantenimiento y Reparacion"
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile
    } else {
        Write-ErrorMsg "No se encontro Invoke-WindowsMaintenance.ps1"
        pause
    }
}

function Invoke-DiagnosticsModule {
    $scriptFile = Resolve-ToolScript "PostInstall-Diagnostics.ps1"
    if ($scriptFile) {
        Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Iniciando Modulo de Auditoria Post-Instalacion y Salud"
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile -DesktopOutput
    } else {
        Write-ErrorMsg "No se encontro PostInstall-Diagnostics.ps1"
        pause
    }
}

function Invoke-SecurityModule {
    $scriptFile = Resolve-ToolScript "Invoke-WindowsSecurityHardening.ps1"
    if ($scriptFile) {
        Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Iniciando Modulo de Auditoria de Seguridad Desacoplada"
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile -ShowReport
    } else {
        Write-ErrorMsg "No se encontro Invoke-WindowsSecurityHardening.ps1"
        pause
    }
}

function Invoke-BrowsersModule {
    $scriptFile = Resolve-ToolScript "Win11-Debloat-v3-Adaptive.ps1"
    if ($scriptFile) {
        Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Iniciando Optimizacion Oficial de Navegadores (Edge, Chrome, Firefox, Brave)"
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile -BrowsersOnly
    } else {
        Write-ErrorMsg "No se encontro Win11-Debloat-v3-Adaptive.ps1"
        pause
    }
}

function Invoke-OpenDashboards {
    Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Generando y abriendo Dashboards Visuales HTML"
    
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
    
    Write-OK "Dashboards HTML abiertos en el navegador web local."
    Start-Sleep -Seconds 2
}

function Show-QuickActionsMenu {
    Show-UnifiedBanner -Title "ACCIONES RAPIDAS DE SISTEMA" -Subtitle "Herramientas de Mantenimiento Express"
    
    $quickOpts = @(
        "Vaciar Cache DNS (ipconfig /flushdns)",
        "Reiniciar Explorador de Windows (explorer.exe)",
        "Abrir Panel de Control Maestro (God Mode)",
        "Reparacion Rapida de Imagen (DISM RestoreHealth + SFC)",
        "Limpieza Inmediata de Shaders GPU (DirectX, NVIDIA, AMD)",
        "Ejecutar SSD TRIM en todas las unidades compatibles",
        "Optimizar Navegadores Web (Video GPU, Menos RAM, Sin IA)"
    )
    
    $actChoice = Show-UnifiedMenu -Title "ACCIONES DISPONIBLES" -Options $quickOpts -DefaultChoice 1 -AllowCancel -CancelText "Volver al Menu Principal"
    
    switch ($actChoice) {
        1 {
            Write-SubStep "Vaciando cache DNS..."
            ipconfig /flushdns
            Write-OK "Cache DNS vaciada exitosamente."
            pause
        }
        2 {
            Write-SubStep "Reiniciando Explorador..."
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
            Start-Process "explorer.exe"
            Write-OK "Explorador de Windows reiniciado."
        }
        3 {
            Write-SubStep "Abriendo God Mode..."
            Start-Process "explorer.exe" -ArgumentList "shell:::{ED7BA470-8E54-465E-825C-99712043E01C}"
            Write-OK "God Mode abierto."
        }
        4 {
            Write-StepHeader -StepNumber 1 -TotalSteps 2 -Message "Ejecutando DISM RestoreHealth"
            DISM /Online /Cleanup-Image /RestoreHealth
            Write-StepHeader -StepNumber 2 -TotalSteps 2 -Message "Ejecutando SFC Scannow"
            sfc /scannow
            Write-OK "Proceso de reparacion completado."
            pause
        }
        5 {
            Write-SubStep "Limpiando shaders GPU..."
            $shaderDirs = @(
                "$env:LOCALAPPDATA\D3DSCache",
                "$env:LOCALAPPDATA\NVIDIA\DXCache",
                "$env:LOCALAPPDATA\AMD\DxCache"
            )
            foreach ($sd in $shaderDirs) {
                if (Test-Path $sd) {
                    Get-ChildItem -Path $sd -Recurse -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                    Write-Info "Limpiado: $sd"
                }
            }
            Write-OK "Cache de shaders GPU limpiada correctamente."
            pause
        }
        6 {
            Write-SubStep "Ejecutando ReTrim en volumenes SSD fijados..."
            try {
                Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' } | ForEach-Object {
                    Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -Verbose
                }
                Write-OK "SSD ReTrim finalizado."
            } catch {
                Write-ErrorMsg "Error ejecutando Optimize-Volume: $($_.Exception.Message)"
            }
            pause
        }
        7 {
            Invoke-BrowsersModule
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
        "Browsers"     { Invoke-BrowsersModule; exit }
        "QuickActions" { Show-QuickActionsMenu; exit }
    }
}

if ($ShowDashboards) {
    Invoke-OpenDashboards
    exit
}

# Si la entrada esta redirigida (sin terminal interactiva) y no se paso -Module, mostrar resumen y salir
try {
    if ([System.Console]::IsInputRedirected) {
        Show-UnifiedBanner -Title "romanOS TOOLKIT MAESTRO" -Subtitle "Hub de Optimizacion, Gaming, Mantenimiento y Seguridad" -ShowSystemInfo
        Write-Info "Ejecucion no interactiva detectada."
        Write-Info "Uso desatendido: .\romanOS-Toolkit.ps1 -Module <Gaming|Network|Maintenance|Diagnostics|Security|Browsers|Dashboards|QuickActions>"
        exit 0
    }
} catch {}

$mainMenuOpts = @(
    "Optimizacion Gaming & Hardware (HAGS, MSI Mode, Latencia, Debloat)",
    "Diagnostico de Red & Latencia (Benchmarks DNS, TCP/IP, Sockets)",
    "Mantenimiento & Limpieza Profunda (WinSxS DISM, Shaders, SSD TRIM)",
    "Auditoria Forense Post-Instalacion & Salud (Panther, CompactOS, PnP)",
    "Auditoria de Seguridad & Hardening (ASR, VBS, Protocolos On-Demand)",
    "Optimizar y Debloat de Navegadores (GPU, Menos RAM, Sin Copilot/IA)",
    "Generar y Abrir Dashboards HTML de Salud y Seguridad",
    "Acciones Rapidas Express (Flush DNS, Restart Explorer, GodMode, SFC)"
)

while ($true) {
    Show-UnifiedBanner -Title "romanOS TOOLKIT MAESTRO" -Subtitle "Hub de Optimizacion, Gaming, Mantenimiento y Seguridad" -ShowSystemInfo
    $choice = Show-UnifiedMenu -Title "MODULOS DEL TOOLKIT MAESTRO" -Options $mainMenuOpts -DefaultChoice 1 -AllowCancel -CancelText "Salir del Toolkit"
    
    switch ($choice) {
        1 { Invoke-GamingModule }
        2 { Invoke-NetworkModule }
        3 { Invoke-MaintenanceModule }
        4 { Invoke-DiagnosticsModule }
        5 { Invoke-SecurityModule }
        6 { Invoke-BrowsersModule; pause }
        7 { Invoke-OpenDashboards }
        8 { Show-QuickActionsMenu }
        0 {
            Write-Host "`n  Cerrando romanOS Toolkit Maestro...`n" -ForegroundColor Gray
            exit
        }
        default {
            Write-Warn "Opcion no valida."
            Start-Sleep -Seconds 1
        }
    }
}
