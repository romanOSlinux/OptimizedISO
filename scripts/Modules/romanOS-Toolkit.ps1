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
    [ValidateSet("Gaming", "Network", "Maintenance", "Diagnostics", "FootprintAudit", "Security", "Dashboards", "QuickActions", "Browsers", "Updates", "ContextMenu", "Drivers", "UserMigration", "MemoryTrim", "UniversalAudit", "SystemAudit", "GameDevSwitch", "GameSwitch", "GameAggressive", "DevSwitch", "GUI", "ControlCenter")]
    [string]$Module,
    [switch]$ShowDashboards,
    [switch]$GUI
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
        if ($GUI) { $argList += '-GUI' }
        
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
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\UI-Engine.ps1"),
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
if (-not $uiLoaded -or -not (Get-Command Show-UnifiedBanner -ErrorAction SilentlyContinue)) {
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

# -----------------------------------------------------------------------------
# 1.1 CARGA DE MOTOR DE HARDWARE UNIFICADO (Hardware-Engine.ps1)
# -----------------------------------------------------------------------------
$hwEnginePaths = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\Hardware-Engine.ps1"),
    (Join-Path $PSScriptRoot "Core\Hardware-Engine.ps1"),
    (Join-Path $PSScriptRoot "Hardware-Engine.ps1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\Hardware-Engine.ps1"),
    "C:\Windows\Setup\Scripts\Core\Hardware-Engine.ps1"
)
$hwLoaded = $false
foreach ($p in $hwEnginePaths) {
    if (Test-Path $p) {
        . $p
        $hwLoaded = $true
        break
    }
}

# -----------------------------------------------------------------------------
# 1.2 CARGA DE MOTOR DE POLITICAS UNIFICADO (Core\Policy-Engine.ps1)
# -----------------------------------------------------------------------------
$policyEnginePaths = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\Policy-Engine.ps1"),
    (Join-Path $PSScriptRoot "Core\Policy-Engine.ps1"),
    (Join-Path $PSScriptRoot "Policy-Engine.ps1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\Policy-Engine.ps1"),
    "C:\Windows\Setup\Scripts\Core\Policy-Engine.ps1"
)
$policyLoaded = $false
foreach ($p in $policyEnginePaths) {
    if (Test-Path $p) {
        . $p
        $policyLoaded = $true
        break
    }
}

# Resolucion de rutas de scripts hermanos
$repoScriptsRoot = Split-Path $PSScriptRoot -Parent
$searchDirs = @(
    $PSScriptRoot,
    (Join-Path $PSScriptRoot "scripts"),
    (Join-Path $PSScriptRoot "Drivers"),
    (Join-Path $PSScriptRoot "scripts\Drivers"),
    (Join-Path $PSScriptRoot "Modules"),
    (Join-Path $PSScriptRoot "scripts\Modules"),
    (Join-Path $PSScriptRoot "Builder"),
    (Join-Path $PSScriptRoot "scripts\Builder"),
    (Join-Path $repoScriptsRoot "Drivers"),
    (Join-Path $repoScriptsRoot "Modules"),
    (Join-Path $repoScriptsRoot "Builder"),
    "$env:WINDIR\Setup\Scripts",
    "$env:WINDIR\Setup\Scripts\Modules",
    "$env:WINDIR\Setup\Scripts\Drivers",
    "C:\Windows\Setup\Scripts",
    "C:\Windows\Setup\Scripts\Modules",
    "C:\Windows\Setup\Scripts\Drivers",
    "C:\OptimizedISO\scripts",
    "C:\OptimizedISO\scripts\Drivers",
    "C:\OptimizedISO\scripts\Modules",
    "C:\OptimizedISO\scripts\Builder"
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

function Invoke-FootprintAuditModule {
    $scriptFile = Resolve-ToolScript "Audit-FreshInstallFootprint.ps1"
    if ($scriptFile) {
        Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Iniciando Auditoria Forense de Huella en Reposo (Footprint Audit)"
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile
    } else {
        Write-ErrorMsg "No se encontro Audit-FreshInstallFootprint.ps1"
        pause
    }
}

function Invoke-MemoryTrimModule {
    $scriptFile = Resolve-ToolScript "Optimize-ProcessMemory.ps1"
    if ($scriptFile) {
        Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Iniciando Optimizacion y Poda de Memoria en Reposo (EmptyWorkingSet psapi.dll)"
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile
    } else {
        Write-ErrorMsg "No se encontro Optimize-ProcessMemory.ps1"
        pause
    }
}

function Invoke-UniversalAuditModule {
    $scriptFile = Resolve-ToolScript "Audit-SystemOptimization.ps1"
    if ($scriptFile) {
        Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Iniciando Auditor Universal de Optimizacion del Sistema (Multi-Hardware)"
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile
    } else {
        Write-ErrorMsg "No se encontro Audit-SystemOptimization.ps1"
        pause
    }
}

function Invoke-GameDevSwitchModule {
    param(
        [string]$TargetMode = "Status",
        [string]$TargetProfile = "Light"
    )
    $cmdLauncher = Resolve-ToolScript "Switch-GameDevMode.cmd"
    if ($TargetMode -eq "Status" -and $cmdLauncher) {
        # Si se invoca interactivamente desde el menu, abrir el lanzador bimodal .cmd con todas las opciones
        & cmd.exe /c "`"$cmdLauncher`""
        return
    }
    
    $scriptFile = Resolve-ToolScript "Switch-GameDevMode.ps1"
    if ($scriptFile) {
        Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Iniciando Conmutador Modo Juego / Modo Dev (romanOS GameDev Switch)"
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile -Mode $TargetMode -Profile $TargetProfile
    } else {
        Write-ErrorMsg "No se encontro Switch-GameDevMode.ps1"
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
    $scriptFile = Resolve-ToolScript "Optimize-WebBrowsers.ps1"
    if ($scriptFile) {
        Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Iniciando Optimizacion Oficial de Navegadores (Edge, Chrome, Firefox, Brave)"
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile
    } else {
        Write-ErrorMsg "No se encontro Optimize-WebBrowsers.ps1"
        pause
    }
}

function Invoke-UpdatesModule {
    $scriptFile = Resolve-ToolScript "Get-WindowsUpdates.ps1"
    if ($scriptFile) {
        Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Iniciando Descargador Oficial de Windows Updates (MSU/CAB)"
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile
    } else {
        Write-ErrorMsg "No se encontro Get-WindowsUpdates.ps1"
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

function Invoke-ContextMenuModule {
    $scriptFile = Resolve-ToolScript "Add-OptimizedContextMenus.ps1"
    if ($scriptFile) {
        Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Gestion de Menus Contextuales (Gamer & Power-User)"
        $opts = @(
            "Aplicar Suite Completa + Menu Clasico 1-Clic (Recomendado)",
            "Habilitar solo Menu Clasico (0 ms latencia, 1 solo clic)",
            "Restaurar Menu Moderno original de Windows 11",
            "Desinstalar todos los menus contextuales personalizados",
            "Reiniciar Explorador de Windows (explorer.exe)"
        )
        $subChoice = Show-UnifiedMenu -Title "OPCIONES DE MENU CONTEXTUAL" -Options $opts -DefaultChoice 1 -AllowCancel -CancelText "Volver"
        switch ($subChoice) {
            1 { & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile -Apply -RestartExplorer }
            2 { & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile -EnableClassicMenu -RestartExplorer }
            3 { & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile -RestoreModernMenu -RestartExplorer }
            4 { & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile -Remove -RestartExplorer }
            5 { & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $scriptFile -RestartExplorer }
        }
    } else {
        Write-ErrorMsg "No se encontro Add-OptimizedContextMenus.ps1"
        pause
    }
}

function Invoke-DriversModule {
    Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Ecosistema de Controladores (Drivers) - romanOS"
    $opts = @(
        "Respaldar Controladores Activos del Host (Export-WindowsDriver)",
        "Depuracion y Limpieza de DriverStore (Recuperar espacio en disco)",
        "Descarga Asistida de Drivers Criticos (Intel VMD / VirtIO)"
    )
    $subChoice = Show-UnifiedMenu -Title "GESTION DE CONTROLADORES" -Options $opts -DefaultChoice 1 -AllowCancel -CancelText "Volver"
    switch ($subChoice) {
        1 {
            $backupScript = Resolve-ToolScript "Backup-HardwareDrivers.ps1"
            if ($backupScript) {
                & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $backupScript
            } else {
                Write-ErrorMsg "No se encontro Backup-HardwareDrivers.ps1"
            }
            pause
        }
        2 {
            $cleanScript = Resolve-ToolScript "Clean-DriverStore.ps1"
            if ($cleanScript) {
                & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $cleanScript
            } else {
                Write-ErrorMsg "No se encontro Clean-DriverStore.ps1"
            }
            pause
        }
        3 {
            $getScript = Resolve-ToolScript "Get-CriticalDrivers.ps1"
            if ($getScript) {
                & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $getScript
            } else {
                Write-ErrorMsg "No se encontro Get-CriticalDrivers.ps1"
            }
            pause
        }
    }
}

function Invoke-ControlCenterGUI {
    [CmdletBinding()]
    param()
    
    Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Lanzando romanOS Control Center (WPF)"
    $ccScript = $null
    $candidates = @(
        (Join-Path (Split-Path $PSScriptRoot -Parent) "GUI\romanOS-ControlCenter.ps1"),
        (Join-Path $PSScriptRoot "..\GUI\romanOS-ControlCenter.ps1"),
        (Join-Path $PSScriptRoot "GUI\romanOS-ControlCenter.ps1"),
        (Join-Path $PSScriptRoot "romanOS-ControlCenter.ps1"),
        "$env:WINDIR\Setup\Scripts\GUI\romanOS-ControlCenter.ps1",
        "C:\Windows\Setup\Scripts\GUI\romanOS-ControlCenter.ps1"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $ccScript = (Resolve-Path $c).Path; break }
    }
    
    if ($ccScript) {
        Write-Info "Iniciando romanOS Control Center (Interfaz Grafica Moderna WPF)..."
        $psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        Start-Process -FilePath $psExe -ArgumentList "-WindowStyle Hidden -STA -NoProfile -ExecutionPolicy Bypass -File `"$ccScript`""
        Write-OK "romanOS Control Center lanzado en proceso desacoplado."
    } else {
        Write-ErrorMsg "No se encontro romanOS-ControlCenter.ps1 en las rutas del sistema ni del repositorio."
    }
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
        "Optimizar Navegadores Web (Video GPU, Menos RAM, Sin IA)",
        "Restaurar Servicios Hardcore (Wi-Fi, Bluetooth, Impresion, Busqueda)",
        "Alternar Hipervisor / VBS (Activar o Desactivar hypervisorlaunchtype)",
        "Auditoria e Introspeccion de Hardware (PCIe, GPU, RAM, MSI, SMBIOS)",
        "Gestionar Menus Contextuales (Gamer, Take Ownership, UEFI, Clasico)",
        "Respaldar Controladores del Host para la ISO (Export-WindowsDriver)",
        "Depuracion Segura del DriverStore (FileRepository)",
        "Poda Quirurgica de Memoria RAM en Reposo (psapi.dll EmptyWorkingSet)",
        "Auditor Universal de Optimizacion del Sistema (Multi-Hardware)",
        "Conmutador Modo Juego / Modo Dev (Cortar Devoradores de Recursos / Hyper-V)",
        "Abrir romanOS Control Center (Interfaz Grafica Moderna WPF & Telemetria)"
    )
    
    $actChoice = Show-UnifiedMenu -Title "ACCIONES DISPONIBLES" -Options $quickOpts -DefaultChoice 1 -AllowCancel -CancelText "Volver al Menu Principal"
    
    switch ($actChoice) {
        1 {
            Write-SubStep "Delegando vaciado de cache DNS a especialista..."
            $netScript = Resolve-ToolScript "Win11-Network-Diagnostics-Optimizer.ps1"
            if ($netScript) {
                & $netScript -FlushDNSOnly -Unattended
            } else {
                ipconfig /flushdns
                Write-OK "Cache DNS vaciada con exito (ipconfig /flushdns)."
            }
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
        }
        5 {
            Write-SubStep "Delegando purga de Shaders GPU a Invoke-WindowsMaintenance.ps1..."
            $maintScript = Resolve-ToolScript "Invoke-WindowsMaintenance.ps1"
            if ($maintScript) {
                & $maintScript -ShadersOnly -Unattended
            } else {
                Write-ErrorMsg "Modulo de mantenimiento no encontrado."
            }
            Write-OK "Caches de Shaders GPU procesadas."
        }
        6 {
            Write-SubStep "Delegando SSD TRIM a Invoke-WindowsMaintenance.ps1..."
            $maintScript = Resolve-ToolScript "Invoke-WindowsMaintenance.ps1"
            if ($maintScript) {
                & $maintScript -TrimOnly -Unattended
            } else {
                Write-ErrorMsg "Modulo de mantenimiento no encontrado."
            }
        }
        7 {
            Invoke-BrowsersModule
        }
        8 {
            Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Restaurando Servicios de Sistema"
            Write-SubStep "Habilitando e iniciando Wi-Fi (WlanSvc)..."
            sc.exe config WlanSvc start=auto | Out-Null
            Start-Service WlanSvc -ErrorAction SilentlyContinue

            Write-SubStep "Habilitando e iniciando Bluetooth (bthserv)..."
            sc.exe config bthserv start=auto | Out-Null
            Start-Service bthserv -ErrorAction SilentlyContinue

            Write-SubStep "Habilitando e iniciando Cola de Impresion (Spooler)..."
            sc.exe config Spooler start=auto | Out-Null
            Start-Service Spooler -ErrorAction SilentlyContinue

            Write-SubStep "Habilitando e iniciando Busqueda de Windows (WSearch)..."
            sc.exe config WSearch start=delayed-auto | Out-Null
            Start-Service WSearch -ErrorAction SilentlyContinue

            Write-OK "Servicios restaurados a inicio automatico."
        }
        9 {
            Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Alternar Estado del Hipervisor (VBS / Latencia)"
            try {
                $currentBcd = & bcdedit /enum "{current}" 2>&1
                $isOff = ($currentBcd -match 'hypervisorlaunchtype\s+off')

                if ($isOff) {
                    Write-Info "Estado actual: Hipervisor DESACTIVADO (Ring 0 / Latencia Minima)."
                    if (Prompt-UnifiedYesNo -Prompt "Desea ACTIVAR el hipervisor (para VBS / Credential Guard / WSL2)?" -Default $true) {
                        & bcdedit /set hypervisorlaunchtype auto
                        Write-OK "Hipervisor configurado en 'auto'. Se requiere reiniciar el equipo."
                    }
                } else {
                    Write-Info "Estado actual: Hipervisor ACTIVADO (Estandar)."
                    if (Prompt-UnifiedYesNo -Prompt "Desea DESACTIVAR el hipervisor (para latencia minima en e-sports)?" -Default $true) {
                        & bcdedit /set hypervisorlaunchtype off
                        Write-OK "Hipervisor configurado en 'off'. Se requiere reiniciar el equipo."
                    }
                }
            } catch {
                Write-ErrorMsg "Error al consultar o modificar bcdedit: $($_.Exception.Message)"
            }
        }
        10 {
            Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Auditoria e Introspeccion de Hardware"
            if ($hwLoaded -and (Get-Command Get-SystemHardwareProfile -ErrorAction SilentlyContinue)) {
                $hw = Get-SystemHardwareProfile -ForceRefresh
                Format-HardwareSummary -Profile $hw
                
                Write-Host "`n  --- Detalle de Adaptadores Graficos (PCI-SIG) ---" -ForegroundColor Cyan
                foreach ($g in $hw.GPU.Devices) {
                    $msiLabel = if ($g.MsiStatus -eq 1) { "Habilitado [1]" } elseif ($g.MsiStatus -eq 0) { "Deshabilitado [0]" } else { "No configurado" }
                    Write-Host "    * $($g.Name)" -ForegroundColor White
                    Write-Host "      - Fabricante   : $($g.VendorName) (VEN_$($g.VendorId) DEV_$($g.DeviceId))" -ForegroundColor Gray
                    Write-Host "      - Driver       : $($g.DriverVersion)" -ForegroundColor Gray
                    Write-Host "      - MSI / MSI-X  : $msiLabel (Soporte PCIe: $($g.SupportsMSI))" -ForegroundColor $(if($g.MsiStatus -eq 1){'Green'}else{'Gray'})
                    Write-Host "      - Soporte HAGS : $($g.SupportsHAGS)" -ForegroundColor $(if($g.SupportsHAGS){'Green'}else{'Gray'})
                }
            } else {
                Write-Warn "Modulo Hardware-Engine.ps1 no disponible."
            }
        }
        11 {
            Invoke-ContextMenuModule
        }
        12 {
            $backupScript = Resolve-ToolScript "Backup-HardwareDrivers.ps1"
            if ($backupScript) { & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $backupScript } else { Write-ErrorMsg "No se encontro Backup-HardwareDrivers.ps1" }
        }
        13 {
            $cleanScript = Resolve-ToolScript "Clean-DriverStore.ps1"
            if ($cleanScript) { & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $cleanScript } else { Write-ErrorMsg "No se encontro Clean-DriverStore.ps1" }
        }
        14 {
            Invoke-MemoryTrimModule
        }
        15 {
            Invoke-UniversalAuditModule
        }
        16 {
            Invoke-GameDevSwitchModule -TargetMode "Status"
        }
        17 {
            Invoke-ControlCenterGUI
        }
        default { return }
    }

}

# -----------------------------------------------------------------------------
# 3. BUCLE PRINCIPAL INTERACTIVO
# -----------------------------------------------------------------------------
if ($Module) {
    switch ($Module) {
        "Gaming"        { Invoke-GamingModule; exit }
        "Network"       { Invoke-NetworkModule; exit }
        "Maintenance"   { Invoke-MaintenanceModule; exit }
        "Diagnostics"   { Invoke-DiagnosticsModule; exit }
        "FootprintAudit"{ Invoke-FootprintAuditModule; exit }
        "Security"      { Invoke-SecurityModule; exit }
        "Dashboards"    { Invoke-OpenDashboards; exit }
        "Browsers"      { Invoke-BrowsersModule; exit }
        "Updates"       { Invoke-UpdatesModule; exit }
        "ContextMenu"   { Invoke-ContextMenuModule; exit }
        "Drivers"       { Invoke-DriversModule; exit }
        "UserMigration" { $ms = Resolve-ToolScript "Migrar-Usuario-W11.ps1"; if ($ms) { & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $ms } else { Write-ErrorMsg "No se encontro Migrar-Usuario-W11.ps1" }; exit }
        "MemoryTrim"    { Invoke-MemoryTrimModule; exit }
        "UniversalAudit"{ Invoke-UniversalAuditModule; exit }
        "SystemAudit"   { Invoke-UniversalAuditModule; exit }
        "GameDevSwitch" { Invoke-GameDevSwitchModule -TargetMode "Game" -TargetProfile "Light"; exit }
        "GameSwitch"    { Invoke-GameDevSwitchModule -TargetMode "Game" -TargetProfile "Light"; exit }
        "GameAggressive"{ Invoke-GameDevSwitchModule -TargetMode "Game" -TargetProfile "Aggressive"; exit }
        "DevSwitch"     { Invoke-GameDevSwitchModule -TargetMode "Dev"; exit }
        "GUI"           { Invoke-ControlCenterGUI; exit }
        "ControlCenter" { Invoke-ControlCenterGUI; exit }
        "QuickActions"  { Show-QuickActionsMenu; exit }
    }
}

if ($GUI) {
    Invoke-ControlCenterGUI
    exit
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
        Write-Info "Uso desatendido: .\romanOS-Toolkit.ps1 -Module <Gaming|Network|Maintenance|Diagnostics|Security|Browsers|Updates|Drivers|UserMigration|UniversalAudit|Dashboards|QuickActions>"
        exit 0
    }
} catch {}

$mainMenuOpts = @(
    "Optimizacion Gaming & Hardware (HAGS, MSI Mode, Latencia, Debloat)",
    "Diagnostico de Red & Latencia (Benchmarks DNS, TCP/IP, Sockets)",
    "Mantenimiento & Limpieza Profunda (WinSxS DISM, Shaders, SSD TRIM)",
    "Auditoria Forense Post-Instalacion & Salud (Panther, CompactOS, PnP)",
    "Auditoria Forense de Huella en Reposo (Procesos en Segundo Plano, RAM y Directivas)",
    "Auditoria de Seguridad & Hardening (ASR, VBS, Protocolos On-Demand)",
    "Optimizar y Debloat de Navegadores (GPU, Menos RAM, Sin Copilot/IA)",
    "Descargar Windows Updates Oficiales (MSU/CAB para Slipstream en ISO)",
    "Gestion Integral de Controladores (Respaldo Host, DriverStore, Intel VMD)",
    "Migrar o Rescatar Perfil de Usuario Local (Respaldos y Recreacion)",
    "Generar y Abrir Dashboards HTML de Salud y Seguridad",
    "Poda Quirurgica de Memoria RAM en Reposo (SearchHost, WebView2, Shell)",
    "Auditor Universal de Optimizacion (Multi-Hardware, Latencia, Scoring y Remediacion)",
    "Conmutador Modo Juego / Modo Dev (Liberar RAM para APU y Cortar Devoradores)",
    "Acciones Rapidas Express (Flush DNS, Restart Explorer, GodMode, SFC)",
    "Abrir romanOS Control Center (Interfaz Grafica Moderna WPF & Telemetria)"
)

while ($true) {
    Show-UnifiedBanner -Title "romanOS TOOLKIT MAESTRO" -Subtitle "Hub de Optimizacion, Gaming, Mantenimiento y Seguridad" -ShowSystemInfo
    $choice = Show-UnifiedMenu -Title "MODULOS DEL TOOLKIT MAESTRO" -Options $mainMenuOpts -DefaultChoice 1 -AllowCancel -CancelText "Salir del Toolkit"
    
    switch ($choice) {
        1  { Invoke-GamingModule; pause }
        2  { Invoke-NetworkModule; pause }
        3  { Invoke-MaintenanceModule; pause }
        4  { Invoke-DiagnosticsModule; pause }
        5  { Invoke-FootprintAuditModule; pause }
        6  { Invoke-SecurityModule; pause }
        7  { Invoke-BrowsersModule; pause }
        8  { Invoke-UpdatesModule; pause }
        9  { Invoke-DriversModule; pause }
        10 { $ms = Resolve-ToolScript "Migrar-Usuario-W11.ps1"; if ($ms) { & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $ms } else { Write-ErrorMsg "No se encontro Migrar-Usuario-W11.ps1" }; pause }
        11 { Invoke-OpenDashboards; pause }
        12 { Invoke-MemoryTrimModule; pause }
        13 { Invoke-UniversalAuditModule; pause }
        14 { Invoke-GameDevSwitchModule -TargetMode "Status"; pause }
        15 { Show-QuickActionsMenu; pause }
        16 { Invoke-ControlCenterGUI; pause }
        0  {
            Write-Host "`n  Cerrando romanOS Toolkit Maestro...`n" -ForegroundColor Gray
            exit
        }
        default {
            Write-Warn "Opcion no valida."
            Start-Sleep -Seconds 1
        }
    }
}

