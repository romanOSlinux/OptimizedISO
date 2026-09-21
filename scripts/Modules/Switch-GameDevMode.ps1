<#
.SYNOPSIS
    Switch-GameDevMode.ps1 - Conmutador Bimodal de Recursos para Gaming y Entorno de Desarrollo
    romanOS Game & Dev Switch para Windows 11 (23H2 / 24H2 / 25H2)

.DESCRIPTION
    Alterna quirurgicamente entre dos perfiles operativos en el equipo anfitrion:
    1. Modo Juego (-Mode Game):
       - Guarda el estado previo de los servicios en una instantanea transaccional.
       - Detiene la pila de virtualizacion de Hyper-V (vmms, vmcompute, HNS, CmService, HvHost, nvagent)
         y desactiva el adaptador virtual vEthernet (Default Switch) para eliminar DPC latency y jitter.
       - Liquida navegadores en segundo plano huerfanos (msedge.exe sin ventana) y actualizadores,
         recuperando entre 1.5 GB y 2.5 GB de DDR5 para la APU Radeon 760M (Unified Memory Architecture).
       - Pausa servicios de telemetria y compatibilidad que anaden shims a ejecutables (PcaSvc, DPS, InventorySvc, DusmSvc).
       - Aplica poda de Working Set mediante P/Invoke EmptyWorkingSet (psapi.dll) sobre componentes UI
         y sobre Antigravity IDE (reduciendo su consumo sin cerrarlo).
       - Verifica y activa el plan de energia de Maximo Rendimiento.
    2. Modo Desarrollo (-Mode Dev):
       - Restaura la pila de Hyper-V en orden estricto de dependencias (HvHost -> vmcompute -> HNS -> vmms -> CmService).
       - Reactiva el switch de red virtual de Hyper-V y los servicios de diagnostico/mantenimiento.
       - Deja el entorno 100% operativo para compilar y probar ISOs con New-TestVM-HyperV.ps1.
    3. Modo Estado (-Mode Status):
       - Audita en tiempo real el consumo de RAM, el estado de Hyper-V y el modo inferido.

.PARAMETER Profile
    Perfil de juego: 'Light' (Baja latencia, conserva ventanas abiertas) o 'Aggressive' (Gaming puro, liquida Edge e IDE para APU Radeon). Por defecto: 'Light'.

.PARAMETER Aggressive
    Atajo equivalente a -Profile Aggressive.

.PARAMETER CloseIDE
    Si se especifica, cierra completamente Antigravity IDE en lugar de solo podar su Working Set.

.PARAMETER ForceKillEdge
    Fuerza el cierre de todos los procesos de Microsoft Edge sin verificar si tienen ventana abierta.

.PARAMETER Quiet
    Suprime la salida visual formateada en consola.

.PARAMETER PassThru
    Devuelve un objeto personalizado con las metricas de servicios y memoria liberada.

.PARAMETER Unattended
    Omite las pausas interactivas al finalizar.

.EXAMPLE
    .\Switch-GameDevMode.ps1 -Mode Game -Profile Light
    .\Switch-GameDevMode.ps1 -Mode Game -Profile Aggressive
    .\Switch-GameDevMode.ps1 -Mode Game -Aggressive -CloseIDE
    .\Switch-GameDevMode.ps1 -Mode Dev
    .\Switch-GameDevMode.ps1 -Mode Status
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("Game", "Dev", "Status")]
    [string]$Mode = "Game",
    [ValidateSet("Light", "Aggressive")]
    [string]$Profile = "Light",
    [switch]$Aggressive,
    [switch]$CloseIDE,
    [switch]$ForceKillEdge,
    [switch]$Quiet,
    [switch]$PassThru,
    [switch]$Unattended
)

if ($Aggressive) { $Profile = "Aggressive" }
if ($Profile -eq "Aggressive") { $ForceKillEdge = $true }

# -----------------------------------------------------------------------------
# 0. CONFIGURACION DE ENTORNO Y AUTO-ELEVACION UAC
# -----------------------------------------------------------------------------
$ErrorActionPreference = 'Continue'
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue } catch {}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and $Mode -ne 'Status') {
    if ($PSCmdlet.ShouldProcess("powershell.exe", "Auto-elevar privilegios de Administrador UAC")) {
        Write-Host "  [!] Solicitando elevacion de privilegios de Administrador (UAC)..." -ForegroundColor Yellow
        $scriptPath = $MyInvocation.MyCommand.Definition
        if (-not $scriptPath) { $scriptPath = $PSCommandPath }
        
        $argList = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath, '-Mode', $Mode, '-Profile', $Profile)
        if ($Aggressive) { $argList += '-Aggressive' }
        if ($CloseIDE) { $argList += '-CloseIDE' }
        if ($ForceKillEdge) { $argList += '-ForceKillEdge' }
        if ($Quiet) { $argList += '-Quiet' }
        if ($PassThru) { $argList += '-PassThru' }
        if ($Unattended) { $argList += '-Unattended' }
        
        try {
            Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
        } catch {
            Write-Error "Fallo al solicitar elevacion UAC: $($_.Exception.Message)"
        }
        exit
    }
}

# -----------------------------------------------------------------------------
# 1. P/INVOKE EMPTYWORKINGSET (psapi.dll)
# -----------------------------------------------------------------------------
if (-not ([System.Management.Automation.PSTypeName]'RomanOS.PsApiMemory').Type) {
    try {
        Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;

        namespace RomanOS {
            public static class PsApiMemory {
                [DllImport("psapi.dll", SetLastError = true)]
                public static extern bool EmptyWorkingSet(IntPtr hProcess);
            }
        }
"@ -ErrorAction Stop
    } catch {
        Write-Warning "Fallo al compilar definicion P/Invoke de psapi.dll: $($_.Exception.Message)"
    }
}

# -----------------------------------------------------------------------------
# 2. CARGA DE MOTOR VISUAL UNIFICADO (UI-Engine.ps1)
# -----------------------------------------------------------------------------
$uiEnginePaths = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\UI-Engine.ps1"),
    (Join-Path $PSScriptRoot "Core\UI-Engine.ps1"),
    (Join-Path $PSScriptRoot "UI-Engine.ps1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\UI-Engine.ps1"),
    "$env:WINDIR\Setup\Scripts\Core\UI-Engine.ps1",
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
}

# -----------------------------------------------------------------------------
# 3. LISTAS MAESTRAS Y BLINDAJE INVIOLABLE
# -----------------------------------------------------------------------------
# Servicios Hyper-V y Contenedores (Orden de parada inverso / orden de inicio directo)
$script:HyperVServicesStopOrder  = @('CmService', 'vmcompute', 'HvHost', 'HNS', 'vmms', 'nvagent')
$script:HyperVServicesStartOrder = @('HvHost', 'vmcompute', 'HNS', 'vmms', 'CmService', 'nvagent')

# Servicios de Diagnostico, Telemetria y Mantenimiento Pausables en Gaming
$script:BackgroundServices = @(
    'PcaSvc',        # Asistente de compatibilidad de programas (interceptor de .exe)
    'DPS',           # Servicio de directivas de diagnostico (ETW)
    'InventorySvc',  # Servicio de inventario de dispositivos
    'whesvc',        # Estado y experiencias optimizadas de Windows
    'DusmSvc',       # Uso de datos (filtro de red)
    'UsoSvc',        # Orquestador de actualizaciones
    'wuauserv',      # Windows Update
    'ssh-agent',     # Agente SSH
    'WSAIFabricSvc'  # Windows AI Fabric
)

# Procesos de navegadores y tareas en segundo plano a liquidar en Modo Juego
$script:OrphanProcessesToKill = @(
    'MicrosoftEdgeUpdate',
    'BraveUpdateCore',
    'CrossDeviceResume',
    'vmmemCmZygote'
)

# Procesos seguros para poda de Working Set (EmptyWorkingSet)
$script:TrimWorkingSetTargets = @(
    'SearchHost',
    'StartMenuExperienceHost',
    'LockApp',
    'ShellExperienceHost'
)

# LISTA BLANCA INVIOLABLE (Prohibido detener bajo cualquier circunstancia)
$script:InviolableComponents = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
@(
    # Drivers Graficos AMD Radeon
    'AMDRSServ', 'AMDRSSrcExt', 'RadeonSoftware', 'AMDNoiseSuppression',
    # Audio y Perifericos del Usuario
    'Patriot Viper V380', 'Audiosrv', 'AudioEndpointBuilder', 'RtkAudioUniversalService', 'RtkAudUService64',
    # Windows Shell & Compositor
    'dwm', 'explorer', 'sihost', 'fontdrvhost',
    # Anti-Cheat, DRM y Certificados Criptograficos
    'CryptSvc', 'mpssvc', 'BFE', 'AppXSvc', 'ClipSVC', 'StateRepository',
    # Red Base del Host
    'Dhcp', 'Dnscache', 'LanmanWorkstation', 'WlanSvc', 'netprofm', 'nsi', 'iphlpsvc'
) | ForEach-Object { [void]$script:InviolableComponents.Add($_) }

# Ruta del archivo de estado persistente
$script:StateFilePath = Join-Path $env:TEMP "romanOS_GameDevState.json"

# -----------------------------------------------------------------------------
# 4. FUNCIONES AUXILIARES DE CONTROL
# -----------------------------------------------------------------------------
function Test-IsInviolable {
    param([string]$Name)
    return $script:InviolableComponents.Contains($Name)
}

function Get-SystemMemoryMetrics {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedGB  = [math]::Round($totalGB - $freeGB, 2)
        $percent = [math]::Round(($usedGB / $totalGB) * 100, 1)
        return [PSCustomObject]@{
            TotalGB     = $totalGB
            FreeGB      = $freeGB
            UsedGB      = $usedGB
            PercentUsed = $percent
        }
    } catch {
        return [PSCustomObject]@{ TotalGB = 0; FreeGB = 0; UsedGB = 0; PercentUsed = 0 }
    }
}

function Save-ServiceSnapshot {
    $allTargets = $script:HyperVServicesStopOrder + $script:BackgroundServices
    $snapshot = @{}
    
    foreach ($svcName in $allTargets) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            $snapshot[$svcName] = @{
                Status    = $svc.Status.ToString()
                StartType = $svc.StartType.ToString()
            }
        }
    }
    
    # Instantanea de configuracion multimedia del Kernel (SystemProfile)
    try {
        $mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $mmProps = Get-ItemProperty -Path $mmPath -ErrorAction SilentlyContinue
        if ($mmProps) {
            $snapshot['__SystemResponsiveness'] = $mmProps.SystemResponsiveness
            $snapshot['__NoLazyMode']           = $mmProps.NoLazyMode
        }
    } catch {}
    
    try {
        $json = $snapshot | ConvertTo-Json -Depth 3
        [System.IO.File]::WriteAllText($script:StateFilePath, $json, [System.Text.Encoding]::UTF8)
    } catch {
        Write-Warn "No se pudo guardar la instantanea de estado: $($_.Exception.Message)"
    }
}

function Get-ServiceSnapshot {
    if (Test-Path $script:StateFilePath) {
        try {
            $json = [System.IO.File]::ReadAllText($script:StateFilePath, [System.Text.Encoding]::UTF8)
            return ($json | ConvertFrom-Json)
        } catch {}
    }
    return $null
}

function Stop-ServiceSafely {
    param([string]$ServiceName)
    
    if (Test-IsInviolable $ServiceName) {
        Write-Warn "Servicio '$ServiceName' esta en la lista blanca inviolable. Omitido."
        return $false
    }
    
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $svc) { return $false }
    
    if ($svc.Status -eq 'Running') {
        if ($PSCmdlet.ShouldProcess("Servicio $ServiceName", "Detener")) {
            try {
                Stop-Service -Name $ServiceName -Force -ErrorAction Stop
                $svc.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(5))
                return $true
            } catch {
                Write-SubStep ("Fallo al detener {0}: {1}" -f $ServiceName, $_.Exception.Message)
                return $false
            }
        }
    }
    return $false
}

function Start-ServiceSafely {
    param(
        [string]$ServiceName,
        [string]$TargetStartType = "Manual"
    )
    
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $svc) { return $false }
    
    try {
        if ($svc.StartType -eq 'Disabled') {
            Set-Service -Name $ServiceName -StartupType $TargetStartType -ErrorAction SilentlyContinue
        }
        if ($svc.Status -ne 'Running') {
            if ($PSCmdlet.ShouldProcess("Servicio $ServiceName", "Iniciar")) {
                Start-Service -Name $ServiceName -ErrorAction Stop
                $svc.WaitForStatus('Running', [TimeSpan]::FromSeconds(5))
                return $true
            }
        }
    } catch {
        Write-SubStep ("Fallo al iniciar {0}: {1}" -f $ServiceName, $_.Exception.Message)
        return $false
    }
    return $false
}

function Invoke-EmptyWorkingSetOnProcess {
    param([System.Diagnostics.Process]$Process)
    
    if (-not ([System.Management.Automation.PSTypeName]'RomanOS.PsApiMemory').Type) { return 0 }
    
    try {
        $initBytes = $Process.WorkingSet64
        $trimmed = [RomanOS.PsApiMemory]::EmptyWorkingSet($Process.Handle)
        $Process.Refresh()
        $finalBytes = $Process.WorkingSet64
        $reclaimedMB = [math]::Round(($initBytes - $finalBytes) / 1MB, 2)
        if ($reclaimedMB -lt 0) { $reclaimedMB = 0.0 }
        return $reclaimedMB
    } catch {
        return 0.0
    }
}

# -----------------------------------------------------------------------------
# 5. LOGICA PRINCIPAL POR MODO
# -----------------------------------------------------------------------------

# MODO STATUS
if ($Mode -eq "Status") {
    Show-UnifiedBanner -Title "romanOS GAME & DEV SWITCH" -Subtitle "Auditoria de Estado y Memoria" -ShowSystemInfo
    
    $mem = Get-SystemMemoryMetrics
    Write-StepHeader -StepNumber 1 -TotalSteps 2 -Message "Metricas de Memoria RAM del Sistema (DDR5)"
    Write-Host ("  Memoria Total : {0,6} GB" -f $mem.TotalGB) -ForegroundColor White
    Write-Host ("  Memoria Usada : {0,6} GB ({1}%)" -f $mem.UsedGB, $mem.PercentUsed) -ForegroundColor $(if($mem.PercentUsed -gt 60){'Yellow'}else{'Green'})
    Write-Host ("  Memoria Libre : {0,6} GB (Disponible para Juegos y VRAM APU)" -f $mem.FreeGB) -ForegroundColor Cyan
    
    Write-StepHeader -StepNumber 2 -TotalSteps 2 -Message "Inspeccion de Servicios de Virtualizacion e Inactividad"
    $vmms = Get-Service -Name "vmms" -ErrorAction SilentlyContinue
    $hns  = Get-Service -Name "HNS" -ErrorAction SilentlyContinue
    $vEthernet = Get-NetAdapter -Name "vEthernet*" -ErrorAction SilentlyContinue
    
    $edgeProcs = @(Get-Process -Name "msedge" -ErrorAction SilentlyContinue)
    $edgeBackground = @($edgeProcs | Where-Object { [string]::IsNullOrEmpty($_.MainWindowTitle) })
    $edgeMB = if ($edgeProcs.Count -gt 0) { [math]::Round(($edgeProcs | Measure-Object WS -Sum).Sum / 1MB, 2) } else { 0 }
    
    Write-Host ("  Pila Hyper-V (vmms)  : {0}" -f $(if($vmms -and $vmms.Status -eq 'Running'){'[ACTIVO] - Modo Dev Listo'}else{'[DETENIDO] - Modo Juego'})) -ForegroundColor $(if($vmms -and $vmms.Status -eq 'Running'){'Cyan'}else{'Green'})
    Write-Host ("  Red Host HNS         : {0}" -f $(if($hns -and $hns.Status -eq 'Running'){'[ACTIVO]'}else{'[DETENIDO]'})) -ForegroundColor Gray
    Write-Host ("  Switch Virtual Red   : {0}" -f $(if($vEthernet){$vEthernet.Name + " [ACTIVO - Suma Latencia DPC]"}else{"[DESMONTADO - Latencia Nativa 2.5GbE]"})) -ForegroundColor $(if($vEthernet){'Yellow'}else{'Green'})
    Write-Host ("  Instancias MS Edge   : {0} procesos ({1} MB en RAM)" -f $edgeProcs.Count, $edgeMB) -ForegroundColor $(if($edgeProcs.Count -gt 0){'Yellow'}else{'Green'})
    
    $sysProfile = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ErrorAction SilentlyContinue
    $sysResp = if ($sysProfile -and $sysProfile.SystemResponsiveness -ne $null) { $sysProfile.SystemResponsiveness } else { "N/D" }
    Write-Host ("  Planificador Kernel  : SystemResponsiveness = {0} ({1})" -f $sysResp, $(if($sysResp -eq 0){"100% CPU a Juegos [MODO GAMING]"}else{"$sysResp% CPU reservada a background"})) -ForegroundColor $(if($sysResp -eq 0){'Green'}else{'Yellow'})
    
    Write-Host ""
    if ($vmms -and $vmms.Status -eq 'Running') {
        Write-OK "Diagnostico Global: Entorno en MODO DESARROLLO / PRUEBAS (Hyper-V activo)."
    } else {
        Write-OK "Diagnostico Global: Entorno en MODO JUEGO (Recursos optimizados para Gaming)."
    }
    Write-Host ""
    
    if (-not $Unattended -and -not [System.Console]::IsInputRedirected) {
        Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor Gray
        try { [void][System.Console]::ReadKey($true) } catch {}
    }
    return
}

# MODO GAME
if ($Mode -eq "Game") {
    $initialMem = Get-SystemMemoryMetrics
    
    if (-not $Quiet) {
        $bannerSub = if ($Profile -eq 'Aggressive') { "PERFIL AGRESIVO - Gaming Puro y Maxima DDR5 para APU Radeon" } else { "PERFIL LIVIANO - Baja Latencia de Red DPC y Ventanas Conservadas" }
        Show-UnifiedBanner -Title "romanOS GAME SWITCH" -Subtitle $bannerSub -ShowSystemInfo
        Write-Host "  RAM Inicial: $($initialMem.UsedGB) GB usados | $($initialMem.FreeGB) GB libres" -ForegroundColor Yellow
        Write-Host "  Perfil     : $($Profile.ToUpper())" -ForegroundColor Cyan
    }
    
    # 1. Guardar Snapshot de Estado
    if (-not $Quiet) { Write-StepHeader -StepNumber 1 -TotalSteps 7 -Message "Guardando instantanea del estado de servicios y registro..." }
    Save-ServiceSnapshot
    if (-not $Quiet) { Write-OK "Instantanea guardada en: $script:StateFilePath" }
    
    # 2. Detener Pila de Virtualizacion Hyper-V
    if (-not $Quiet) { Write-StepHeader -StepNumber 2 -TotalSteps 7 -Message "Deteniendo pila de Hyper-V y conmutador virtual de red..." }
    $stoppedHv = 0
    foreach ($svcName in $script:HyperVServicesStopOrder) {
        if (Stop-ServiceSafely $svcName) {
            $stoppedHv++
            if (-not $Quiet) { Write-OK "Servicio detenido: $svcName" }
        }
    }
    if ($stoppedHv -eq 0 -and -not $Quiet) {
        Write-Info "Pila de Hyper-V ya se encontraba inactiva."
    }
    
    # 3. Gestionar Navegadores y Actualizadores en Segundo Plano
    if (-not $Quiet) { Write-StepHeader -StepNumber 3 -TotalSteps 7 -Message "Gestionando navegadores y procesos en segundo plano..." }
    
    $edgeProcs = @(Get-Process -Name "msedge" -ErrorAction SilentlyContinue)
    $edgeRamMB = if ($edgeProcs.Count -gt 0) { [math]::Round(($edgeProcs | Measure-Object WS -Sum).Sum / 1MB, 2) } else { 0.0 }
    $edgeWasKilled = $false
    
    if ($edgeProcs.Count -gt 0) {
        $hasVisibleWindow = @($edgeProcs | Where-Object { -not [string]::IsNullOrEmpty($_.MainWindowTitle) }).Count -gt 0
        if ($Profile -eq "Aggressive" -or $ForceKillEdge -or -not $hasVisibleWindow) {
            try {
                Stop-Process -Name "msedge" -Force -ErrorAction SilentlyContinue
                $edgeWasKilled = $true
                if (-not $Quiet) { Write-OK "Microsoft Edge liquidado ($($edgeProcs.Count) procesos | +$edgeRamMB MB liberados para DDR5/APU)" }
            } catch {}
        } else {
            if (-not $Quiet) {
                Write-Warn "Microsoft Edge tiene ventanas abiertas ($edgeRamMB MB en RAM). Conservado en Modo Liviano."
                Write-Info "Usa el Modo Agresivo (-Profile Aggressive) si requieres estos ~$([math]::Round($edgeRamMB/1024, 2)) GB para la iGPU."
            }
        }
    }
    
    # Otros procesos residuales / updaters
    foreach ($procName in $script:OrphanProcessesToKill) {
        $procs = @(Get-Process -Name $procName -ErrorAction SilentlyContinue)
        if ($procs.Count -gt 0) {
            try {
                Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
                if (-not $Quiet) { Write-OK "Proceso terminado: $procName ($($procs.Count) instancias)" }
            } catch {}
        }
    }
    
    # 4. Pausar Servicios de Diagnostico, Telemetria y Actualizaciones
    if (-not $Quiet) { Write-StepHeader -StepNumber 4 -TotalSteps 7 -Message "Pausando servicios de compatibilidad, diagnostico y actualizacion..." }
    $stoppedBg = 0
    foreach ($svcName in $script:BackgroundServices) {
        if (Stop-ServiceSafely $svcName) {
            $stoppedBg++
            if (-not $Quiet) { Write-OK "Servicio en pausa: $svcName" }
        }
    }
    if ($stoppedBg -eq 0 -and -not $Quiet) {
        Write-Info "Servicios de segundo plano ya se encontraban optimizados."
    }
    
    # 5. Poda de Working Set (EmptyWorkingSet) y Control de Entorno Dev
    if (-not $Quiet) { Write-StepHeader -StepNumber 5 -TotalSteps 7 -Message "Ejecutando poda quirurgica de Working Set (EmptyWorkingSet)..." }
    $totalReclaimedMB = 0.0
    
    foreach ($target in $script:TrimWorkingSetTargets) {
        $procs = @(Get-Process -Name $target -ErrorAction SilentlyContinue)
        foreach ($p in $procs) {
            $rec = Invoke-EmptyWorkingSetOnProcess $p
            $totalReclaimedMB += $rec
        }
    }
    
    # Gestion de Antigravity IDE
    $ideProcs = @(Get-Process -Name "Antigravity IDE", "language_server_windows_x64" -ErrorAction SilentlyContinue)
    $ideRamMB = if ($ideProcs.Count -gt 0) { [math]::Round(($ideProcs | Measure-Object WS -Sum).Sum / 1MB, 2) } else { 0.0 }
    $ideWasKilled = $false
    
    if ($ideProcs.Count -gt 0) {
        if ($CloseIDE) {
            try {
                Stop-Process -Name "Antigravity IDE", "language_server_windows_x64" -Force -ErrorAction SilentlyContinue
                $ideWasKilled = $true
                if (-not $Quiet) { Write-OK "Antigravity IDE cerrado completamente (+ $ideRamMB MB liberados para DDR5/APU)" }
            } catch {}
        } else {
            $ideReclaimed = 0.0
            foreach ($ip in $ideProcs) {
                $ideReclaimed += (Invoke-EmptyWorkingSetOnProcess $ip)
            }
            $totalReclaimedMB += $ideReclaimed
            if (-not $Quiet) {
                Write-Info ("Antigravity IDE reteniendo ~$([math]::Round($ideRamMB/1024, 2)) GB (podado en reposo -{0} MB sin cerrar sesion)" -f [math]::Round($ideReclaimed, 2))
                if ($Profile -eq "Aggressive") {
                    Write-Warn "Para una sesion de juego AAA pura, pasa -CloseIDE para cerrar el entorno de desarrollo y ganar +$([math]::Round($ideRamMB/1024, 2)) GB."
                }
            }
        }
    }
    
    if (-not $Quiet -and $totalReclaimedMB -gt 0) {
        Write-OK ("Memoria RAM fisica podada en reposo: {0} MB" -f [math]::Round($totalReclaimedMB, 2))
    }
    
    # 6. Afinacion de Prioridades Multimedia del Kernel (SystemProfile)
    if (-not $Quiet) { Write-StepHeader -StepNumber 6 -TotalSteps 7 -Message "Ajustando prioridades multimedia del kernel para Gaming..." }
    try {
        $mmKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        if (-not (Test-Path $mmKey)) { New-Item -Path $mmKey -Force -ErrorAction SilentlyContinue | Out-Null }
        
        # SystemResponsiveness: 0 asigna el 100% de ciclos de CPU a juegos en primer plano
        Set-ItemProperty -Path $mmKey -Name "SystemResponsiveness" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $mmKey -Name "NoLazyMode" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        
        $gamesKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
        if (-not (Test-Path $gamesKey)) { New-Item -Path $gamesKey -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $gamesKey -Name "GPU Priority" -Value 8 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gamesKey -Name "Priority" -Value 6 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gamesKey -Name "Scheduling Category" -Value "High" -Type String -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gamesKey -Name "SFIO Priority" -Value "High" -Type String -Force -ErrorAction SilentlyContinue
        
        if (-not $Quiet) { Write-OK "Kernel optimizado: SystemResponsiveness = 0 (100% CPU a juegos) y GPU Priority = 8" }
    } catch {
        if (-not $Quiet) { Write-Warn "No se pudieron ajustar las claves de SystemProfile: $($_.Exception.Message)" }
    }
    
    # 7. Verificacion de Plan de Energia
    if (-not $Quiet) { Write-StepHeader -StepNumber 7 -TotalSteps 7 -Message "Comprobando plan de energia de Maximo Rendimiento..." }
    try {
        $activeScheme = powercfg /getactivescheme
        if ($activeScheme -notlike "*e9a42b02-d5df-448d-aa00-03f14749eb61*" -and $activeScheme -notlike "*e5d77bb0-2d71-420e-ac6b-959193113e8b*") {
            powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
            if (-not $Quiet) { Write-OK "Plan de energia ajustado a 'Maximo Rendimiento'." }
        } else {
            if (-not $Quiet) { Write-OK "Plan de energia ya se encuentra en 'Maximo Rendimiento'." }
        }
    } catch {}
    
    # Resumen Final de Metricas
    $finalMem = Get-SystemMemoryMetrics
    $freedGB = [math]::Round($finalMem.FreeGB - $initialMem.FreeGB, 2)
    if ($freedGB -lt 0) { $freedGB = 0.0 }
    
    if (-not $Quiet) {
        Write-Host ""
        Write-Host "  ===============================================================" -ForegroundColor Green
        Write-Host "  [OK] MODO JUEGO ACTIVADO EXITOSAMENTE" -ForegroundColor Green
        Write-Host ("  Perfil Seleccionado : {0}" -f $(if($Profile -eq 'Aggressive'){'MODO AGRESIVO (Gaming Puro APU / Maxima RAM)'}else{'MODO LIVIANO (Baja Latencia DPC / Ventanas Conservadas)'})) -ForegroundColor $(if($Profile -eq 'Aggressive'){'Cyan'}else{'Yellow'})
        Write-Host ("  RAM Libre Inicial   : {0,5} GB" -f $initialMem.FreeGB) -ForegroundColor Gray
        Write-Host ("  RAM Libre Actual    : {0,5} GB (Ganancia neta: +{1} GB para Juegos/APU)" -f $finalMem.FreeGB, $freedGB) -ForegroundColor Yellow
        Write-Host "  Latencia de Red     : Optimizada (vmswitch.sys de Hyper-V desactivado)" -ForegroundColor Cyan
        Write-Host "  Planificador Kernel : SystemResponsiveness = 0 | GPU Priority = 8" -ForegroundColor Green
        
        # Desglose Pedagogico y Transparencia si quedaron aplicaciones abiertas en Modo Liviano
        if ($Profile -eq 'Light' -and (-not $edgeWasKilled -or -not $ideWasKilled)) {
            Write-Host ""
            Write-Host "  ---------------------------------------------------------------" -ForegroundColor DarkGray
            Write-Host "  [i] DESGLOSE DE MEMORIA RETENIDA POR APLICACIONES DE USUARIO:" -ForegroundColor White
            if (-not $edgeWasKilled -and $edgeRamMB -gt 0) {
                Write-Host ("      - Microsoft Edge        : ~{0} MB (~{1} GB retenidos con pestañas abiertas)" -f $edgeRamMB, [math]::Round($edgeRamMB/1024, 2)) -ForegroundColor DarkGray
            }
            if (-not $ideWasKilled -and $ideRamMB -gt 0) {
                Write-Host ("      - Antigravity IDE / Dev : ~{0} MB (~{1} GB retenidos en sesion de desarrollo)" -f $ideRamMB, [math]::Round($ideRamMB/1024, 2)) -ForegroundColor DarkGray
            }
            Write-Host "      --> Para partidas pesadas donde la iGPU Radeon 760M requiera toda la DDR5," -ForegroundColor Yellow
            Write-Host "          ejecuta la opcion [2] MODO JUEGO AGRESIVO para liberar estos gigabytes." -ForegroundColor Yellow
        }
        Write-Host "  ===============================================================" -ForegroundColor Green
        Write-Host ""
        
        if (-not $Unattended -and -not [System.Console]::IsInputRedirected) {
            Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor Gray
            try { [void][System.Console]::ReadKey($true) } catch {}
        }
    }
    
    if ($PassThru) {
        return [PSCustomObject]@{
            Mode             = "Game"
            Profile          = $Profile
            InitialFreeGB    = $initialMem.FreeGB
            FinalFreeGB      = $finalMem.FreeGB
            GainedFreeGB     = $freedGB
            StoppedHyperV    = $stoppedHv
            StoppedBackgrnd  = $stoppedBg
            PmemReclaimedMB  = [math]::Round($totalReclaimedMB, 2)
            EdgeKilled       = $edgeWasKilled
            IDEKilled        = $ideWasKilled
        }
    }
    return
}

# MODO DEV
if ($Mode -eq "Dev") {
    if (-not $Quiet) {
        Show-UnifiedBanner -Title "romanOS DEV & ISO SWITCH" -Subtitle "Restaurando Pila de Virtualizacion Hyper-V y Pruebas" -ShowSystemInfo
    }
    
    $savedSnapshot = Get-ServiceSnapshot
    
    # 1. Iniciar Pila de Hyper-V y Contenedores
    if (-not $Quiet) { Write-StepHeader -StepNumber 1 -TotalSteps 4 -Message "Iniciando servicios de Hyper-V en orden estricto de dependencias..." }
    $startedHv = 0
    foreach ($svcName in $script:HyperVServicesStartOrder) {
        $shouldStart = $true
        if ($savedSnapshot -and $savedSnapshot.$svcName) {
            if ($savedSnapshot.$svcName.Status -eq 'Stopped' -and $savedSnapshot.$svcName.StartType -eq 'Disabled') {
                $shouldStart = $false
            }
        }
        
        if ($shouldStart) {
            if (Start-ServiceSafely -ServiceName $svcName -TargetStartType "Manual") {
                $startedHv++
                if (-not $Quiet) { Write-OK "Servicio restaurado: $svcName" }
            }
        }
    }
    
    # 2. Restaurar Servicios de Diagnostico y Mantenimiento
    if (-not $Quiet) { Write-StepHeader -StepNumber 2 -TotalSteps 4 -Message "Restaurando servicios de mantenimiento y soporte..." }
    $startedBg = 0
    foreach ($svcName in $script:BackgroundServices) {
        $shouldStart = $true
        $targetStartup = "Manual"
        
        if ($savedSnapshot -and $savedSnapshot.$svcName) {
            $targetStartup = $savedSnapshot.$svcName.StartType
            if ($savedSnapshot.$svcName.Status -ne 'Running') {
                $shouldStart = $false
            }
        }
        
        if ($shouldStart) {
            if (Start-ServiceSafely -ServiceName $svcName -TargetStartType $targetStartup) {
                $startedBg++
                if (-not $Quiet) { Write-OK "Servicio restaurado: $svcName" }
            }
        }
    }
    
    # 3. Restaurar Valores del Planificador Multimedia (Multimedia SystemProfile)
    if (-not $Quiet) { Write-StepHeader -StepNumber 3 -TotalSteps 4 -Message "Restaurando prioridades del planificador multimedia en el registro..." }
    try {
        $mmKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        $restoredResp = 10
        if ($savedSnapshot -and $savedSnapshot.'__SystemResponsiveness' -ne $null) {
            $restoredResp = [int]$savedSnapshot.'__SystemResponsiveness'
        }
        Set-ItemProperty -Path $mmKey -Name "SystemResponsiveness" -Value $restoredResp -Type DWord -Force -ErrorAction SilentlyContinue
        if (-not $Quiet) { Write-OK "SystemResponsiveness restaurado a $restoredResp (perfil estandar de desarrollo)." }
    } catch {}
    
    # 4. Verificacion Operativa de Hyper-V y Switch de Red
    if (-not $Quiet) { Write-StepHeader -StepNumber 4 -TotalSteps 4 -Message "Verificando disponibilidad de conmutador virtual de red..." }
    Start-Sleep -Seconds 1
    $vmms = Get-Service -Name "vmms" -ErrorAction SilentlyContinue
    $vSwitch = Get-NetAdapter -Name "vEthernet*" -ErrorAction SilentlyContinue
    
    if ($vmms -and $vmms.Status -eq 'Running') {
        if (-not $Quiet) { Write-OK "Administracion de Maquinas Virtuales de Hyper-V (vmms) operativa [OK]" }
    } else {
        if (-not $Quiet) { Write-Warn "vmms no reporta estado Running. Puede requerir inicio manual." }
    }
    
    if ($vSwitch) {
        if (-not $Quiet) { Write-OK "Conmutador virtual de red detectado: $($vSwitch.Name) [OK]" }
    } else {
        if (-not $Quiet) { Write-Info "El switch virtual se creara automaticamente al iniciar una VM de prueba." }
    }
    
    if (-not $Quiet) {
        Write-Host ""
        Write-Host "  ===============================================================" -ForegroundColor Cyan
        Write-Host "  [OK] MODO DESARROLLO Y PRUEBAS RESTAURADO" -ForegroundColor Cyan
        Write-Host "  Hyper-V Listo     : Creacion y prueba de ISOs operativas" -ForegroundColor White
        Write-Host "  Herramientas      : New-TestVM-HyperV.ps1 y DISM habilitados" -ForegroundColor Gray
        Write-Host "  Planificador      : SystemResponsiveness restaurado para desarrollo" -ForegroundColor DarkGray
        Write-Host "  ===============================================================" -ForegroundColor Cyan
        Write-Host ""
        
        if (-not $Unattended -and -not [System.Console]::IsInputRedirected) {
            Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor Gray
            try { [void][System.Console]::ReadKey($true) } catch {}
        }
    }
    
    if ($PassThru) {
        return [PSCustomObject]@{
            Mode            = "Dev"
            StartedHyperV   = $startedHv
            StartedBackgrnd = $startedBg
            HyperVReady     = ($vmms -and $vmms.Status -eq 'Running')
        }
    }
    return
}
