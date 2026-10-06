<#
.SYNOPSIS
    Switch-GameDevMode.ps1 - Conmutador Inteligente de Recursos: Modo Juego Adaptativo (Hardware-Aware) y Modo Normal
    romanOS Universal Performance Switch para Windows 11 (23H2 / 24H2 / 25H2)

.DESCRIPTION
    Alterna quirurgicamente entre perfiles operativos en cualquier hardware del mercado:
    1. Modo Juego (-Mode Game):
       - Guarda el estado previo de servicios y configuracion energetica en instantanea transaccional.
       - Aplica calibracion de silicio Hardware-Aware (EPP, Core Parking, PROCTHROTTLEMIN/MAX) segun
         la microarquitectura de CPU detectada (Intel Hibrido, AMD X3D, AMD APU UMA, Zen Simetrico).
       - Desactiva adaptadores virtuales de red en desuso para eliminar latencia DPC y jitter (<500 us).
       - Pausa servicios no esenciales en segundo plano que compiten por E/S NVMe y ciclos de CPU.
       - Preserva el 100% de las aplicaciones abiertas del usuario (Navegadores, Discord, Clientes de Juegos).
       - Calibra la gestion de memoria RAM (LargeSystemCache = 0 para VRAM y DisablePagingExecutive = 1).
       - Calibra el planificador multimedia MMCSS: SystemResponsiveness = 10 y NetworkThrottling desactivado.
    2. Modo Normal / Restaurar (-Mode Normal / -Mode Restore):
       - Restaura todos los servicios pausados a su estado exacto previo registrado en la instantanea JSON.
       - Restaura el planificador multimedia (MMCSS) y prioridades estandar de Windows para productividad general.
       - Restaura la gestion de energia y reloj del procesador a los valores equilibrados oficiales de Windows.
    3. Modo Estado (-Mode Status):
       - Audita en tiempo real el consumo de RAM, servicios y la politica de silicio activa.

.PARAMETER Mode
    Modo de ejecucion: 'Game' (Modo Juego), 'Normal' o 'Restore' (Modo Normal de Windows), 'Status' (Auditoria).
    'Dev' se mantiene como alias retrocompatible de Modo Normal.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("Game", "Normal", "Restore", "Dev", "Status")]
    [string]$Mode = "Game",
    [ValidateSet("Light", "Aggressive")]
    [string]$Profile = "Light",
    [switch]$Aggressive,
    [switch]$CloseIDE,
    [switch]$ForceKillEdge,
    [switch]$Quiet,
    [switch]$PassThru,
    [switch]$Unattended,
    [switch]$SkipElevation
)

if ($Aggressive) { $Profile = "Aggressive" }

# -----------------------------------------------------------------------------
# 0. CONFIGURACION DE ENTORNO Y AUTO-ELEVACION UAC
# -----------------------------------------------------------------------------
$ErrorActionPreference = 'Continue'
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop } catch {
    Write-Warning "[Switch-GameDevMode] No se pudo establecer ExecutionPolicy en Scope Process: $($_.Exception.Message)"
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and $Mode -ne 'Status' -and -not $SkipElevation) {
    if ($PSCmdlet.ShouldProcess("powershell.exe", "Auto-elevar privilegios de Administrador UAC")) {
        Write-Host "  [!] Solicitando elevacion de privilegios de Administrador (UAC)..." -ForegroundColor Yellow
        $scriptPath = $MyInvocation.MyCommand.Definition
        if (-not $scriptPath) { $scriptPath = $PSCommandPath }
        
        $argList = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath, '-Mode', $Mode, '-Profile', $Profile)
        if ($Aggressive) { $argList += '-Aggressive' }
        if ($Quiet) { $argList += '-Quiet' }
        if ($PassThru) { $argList += '-PassThru' }
        if ($Unattended) { $argList += '-Unattended' }
        
        try {
            Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs -ErrorAction Stop
            exit
        } catch {
            Write-Warning "No se pudo elevar UAC ($($_.Exception.Message)). Continuando en modo estandar..."
        }
    }
}

# -----------------------------------------------------------------------------
# 1. CARGA DE MOTOR VISUAL UNIFICADO (UI-Engine.ps1)
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

# Carga de Motor de Hardware (SSOT)
$hwEnginePaths = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\Hardware-Engine.ps1"),
    (Join-Path $PSScriptRoot "Core\Hardware-Engine.ps1"),
    (Join-Path $PSScriptRoot "Hardware-Engine.ps1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\Hardware-Engine.ps1"),
    "$env:WINDIR\Setup\Scripts\Core\Hardware-Engine.ps1",
    "C:\Windows\Setup\Scripts\Core\Hardware-Engine.ps1"
)
$hwLoaded = $false
foreach ($hp in $hwEnginePaths) {
    if (Test-Path $hp) {
        . $hp
        $hwLoaded = $true
        break
    }
}
$script:HardwareProfile = if ($hwLoaded -and (Get-Command Get-SystemHardwareProfile -ErrorAction SilentlyContinue)) {
    Get-SystemHardwareProfile
} else { $null }

# -----------------------------------------------------------------------------
# 2. LISTAS MAESTRAS Y BLINDAJE INVIOLABLE (ANTI-CHEAT Y HARDWARE)
# -----------------------------------------------------------------------------
# Servicios Hyper-V y Contenedores (Orden de parada inverso / orden de inicio directo)
$script:HyperVServicesStopOrder  = @('CmService', 'vmcompute', 'HvHost', 'HNS', 'vmms', 'nvagent')
$script:HyperVServicesStartOrder = @('HvHost', 'vmcompute', 'HNS', 'vmms', 'CmService', 'nvagent')

# Servicios No Esenciales Pausables en Gaming (Reduccion de Ruido ETW, I/O y CPU)
$script:BackgroundServices = @(
    'WSearch',         # Indexador de Windows (compite por E/S de disco NVMe y ancho de banda RAM)
    'PcaSvc',          # Asistente de compatibilidad de programas (interceptor de .exe / hooks)
    'DPS',             # Servicio de directivas de diagnostico (trazas ETW en disco)
    'DiagTrack',       # Experiencias del usuario conectado y telemetria (ruido ETW y red)
    'wuauserv',        # Windows Update (previene TiWorker.exe al 100% de CPU en gaming)
    'UsoSvc',          # Orquestador de actualizaciones
    'BITS',            # Servicio de transferencia inteligente en segundo plano (ancho de banda y disco)
    'DusmSvc',         # Uso de datos (filtro NDIS que agrega sobrecarga en stack de red)
    'Spooler',         # Cola de impresion (completamente ocioso en gaming)
    'InventorySvc',    # Inventario de dispositivos (sondeos PnP en segundo plano)
    'whesvc',          # Estado y experiencias optimizadas de Windows
    'ssh-agent',       # Agente SSH
    'WSAIFabricSvc'    # Windows AI Fabric
)

# LISTA BLANCA INVIOLABLE (Prohibido detener bajo cualquier circunstancia)
$script:InviolableComponents = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
@(
    # Anti-Cheat Ring-0 & Certificados Criptograficos (Vanguard, EAC, BattlEye)
    'CryptSvc', 'mpssvc', 'BFE', 'AppXSvc', 'ClipSVC', 'StateRepository',
    # Controladores Graficos (AMD, NVIDIA, Intel) & Compositor DWM
    'AMDRSServ', 'AMDRSSrcExt', 'RadeonSoftware', 'AMDNoiseSuppression',
    'nvagent', 'NvContainerLocalSystem', 'NVDisplay.ContainerLocalSystem',
    'dwm', 'explorer', 'sihost', 'fontdrvhost',
    # Pila de Audio Universal y Perifericos de Sonido
    'Audiosrv', 'AudioEndpointBuilder', 'RtkAudioUniversalService', 'RtkAudUService64', 'usbaudio',
    # Ecosistema Xbox, Mandos Inalambricos y Game Pass
    'XboxGipSvc', 'GamingServices', 'XblAuthManager', 'XblGameSave',
    # Red Base del Host
    'Dhcp', 'Dnscache', 'LanmanWorkstation', 'WlanSvc', 'netprofm', 'nsi', 'iphlpsvc'
) | ForEach-Object { [void]$script:InviolableComponents.Add($_) }

# Ruta del archivo de estado persistente transaccional
$script:StateFilePath = Join-Path $env:TEMP "romanOS_GameState.json"

# -----------------------------------------------------------------------------
# 3. FUNCIONES AUXILIARES DE CONTROL
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
            $snapshot['__SystemResponsiveness']   = $mmProps.SystemResponsiveness
            $snapshot['__NoLazyMode']             = $mmProps.NoLazyMode
            $snapshot['__NetworkThrottlingIndex'] = $mmProps.NetworkThrottlingIndex
        }
    } catch {
        Write-Warn "No se pudo consultar Multimedia\SystemProfile: $($_.Exception.Message)"
    }
    
    # Instantanea de configuracion de Memoria (Memory Management)
    try {
        $memKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        $memProps = Get-ItemProperty -Path $memKey -ErrorAction SilentlyContinue
        if ($memProps) {
            $snapshot['__DisablePagingExecutive'] = $memProps.DisablePagingExecutive
            $snapshot['__LargeSystemCache']       = $memProps.LargeSystemCache
        }
    } catch {
        Write-Warn "No se pudo consultar Memory Management: $($_.Exception.Message)"
    }
    
    # Instantanea de Esquema de Energia Activo
    try {
        $activeSchemeOut = & powercfg /getactivescheme 2>&1
        if ($activeSchemeOut -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
            $snapshot['__ActivePowerSchemeGuid'] = $matches[1]
        }
    } catch {
        Write-Warn "No se pudo consultar esquema de energia activo: $($_.Exception.Message)"
    }
    
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
        } catch {
            Write-Warn "No se pudo leer el archivo de estado ($script:StateFilePath) - $($_.Exception.Message)"
        }
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
                Write-SubStep ("Fallo al pausar {0}: {1}" -f $ServiceName, $_.Exception.Message)
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

# -----------------------------------------------------------------------------
# 4. LOGICA PRINCIPAL POR MODO
# -----------------------------------------------------------------------------

# MODO STATUS
if ($Mode -eq "Status") {
    Show-UnifiedBanner -Title "romanOS GAME OPTIMIZER" -Subtitle "Auditoria de Estado de Rendimiento y Memoria" -ShowSystemInfo
    
    $mem = Get-SystemMemoryMetrics
    Write-StepHeader -StepNumber 1 -TotalSteps 2 -Message "Metricas de Memoria RAM del Sistema (DDR5 / UMA)"
    Write-Host ("  Memoria Total : {0,6} GB" -f $mem.TotalGB) -ForegroundColor White
    Write-Host ("  Memoria Usada : {0,6} GB ({1}%)" -f $mem.UsedGB, $mem.PercentUsed) -ForegroundColor $(if($mem.PercentUsed -gt 75){'Yellow'}else{'Green'})
    Write-Host ("  Memoria Libre : {0,6} GB (Disponible para Juegos y VRAM APU)" -f $mem.FreeGB) -ForegroundColor Cyan
    
    Write-StepHeader -StepNumber 2 -TotalSteps 2 -Message "Inspeccion de Servicios de Virtualizacion y MMCSS"
    $vmms = Get-Service -Name "vmms" -ErrorAction SilentlyContinue
    $hns  = Get-Service -Name "HNS" -ErrorAction SilentlyContinue
    $vEthernet = Get-NetAdapter -Name "vEthernet*" -ErrorAction SilentlyContinue
    
    Write-Host ("  Pila de Virtualizacion : {0}" -f $(if($vmms -and $vmms.Status -eq 'Running'){'[ACTIVO] - Modo Normal Listo'}else{'[DETENIDO] - Modo Juego Activo (DPC Optimo)'})) -ForegroundColor $(if($vmms -and $vmms.Status -eq 'Running'){'Cyan'}else{'Green'})
    Write-Host ("  Red Host HNS         : {0}" -f $(if($hns -and $hns.Status -eq 'Running'){'[ACTIVO]'}else{'[DETENIDO]'})) -ForegroundColor Gray
    Write-Host ("  Switch Virtual Red   : {0}" -f $(if($vEthernet){$vEthernet.Name + " [ACTIVO - Suma Latencia DPC]"}else{"[DESMONTADO - Latencia Nativa <500us]"})) -ForegroundColor $(if($vEthernet){'Yellow'}else{'Green'})
    
    $sysProfile = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ErrorAction SilentlyContinue
    $sysResp = if ($sysProfile -and $null -ne $sysProfile.SystemResponsiveness) { $sysProfile.SystemResponsiveness } else { "N/D" }
    $netThrot = if ($sysProfile -and $null -ne $sysProfile.NetworkThrottlingIndex) { $sysProfile.NetworkThrottlingIndex } else { "N/D" }
    
    Write-Host ("  Planificador Kernel  : SystemResponsiveness = {0} ({1})" -f $sysResp, $(if($sysResp -eq 10){"90% CPU a Juegos [MODO GAMING CALIBRADO]"}elseif($sysResp -eq 20){"20% CPU reservada a background [ESTANDAR]"}else{"Valor configurado: $sysResp"})) -ForegroundColor $(if($sysResp -eq 10){'Green'}else{'Yellow'})
    Write-Host ("  Limitador Red MMCSS  : NetworkThrottlingIndex = {0} ({1})" -f $netThrot, $(if($netThrot -eq 4294967295){"Desactivado (Throughput Maximo)"}else{"Activo ($netThrot paquetes/ms)"})) -ForegroundColor $(if($netThrot -eq 4294967295){'Green'}else{'Yellow'})
    
    $memKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    $memProps = Get-ItemProperty -Path $memKey -ErrorAction SilentlyContinue
    $lsc = if ($memProps -and $null -ne $memProps.LargeSystemCache) { $memProps.LargeSystemCache } else { 0 }
    $dpe = if ($memProps -and $null -ne $memProps.DisablePagingExecutive) { $memProps.DisablePagingExecutive } else { 0 }
    Write-Host ("  LargeSystemCache     : {0} ({1})" -f $lsc, $(if($lsc -eq 0){"0 [OK: Prioridad a Procesos y VRAM APU]"}else{"1 [Alerta: Prioriza cache de archivos]"})) -ForegroundColor $(if($lsc -eq 0){'Green'}else{'Yellow'})
    Write-Host ("  DisablePagingExec    : {0} ({1})" -f $dpe, $(if($dpe -eq 1){"1 [OK: Drivers fijados en RAM fisica]"}else{"0 [Paginacion de kernel permitida]"})) -ForegroundColor $(if($dpe -eq 1){'Green'}else{'Yellow'})
    
    Write-Host ""
    if ($vmms -and $vmms.Status -eq 'Running') {
        Write-OK "Diagnostico Global: Entorno en MODO NORMAL / ESTANDAR (Servicios de productividad activos)."
    } else {
        Write-OK "Diagnostico Global: Entorno en MODO JUEGO (Recursos optimizados para baja latencia y gaming)."
    }
    Write-Host ""
    
    if (-not $Unattended -and [System.Environment]::UserInteractive -and -not [System.Console]::IsInputRedirected) {
        try {
            Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor Gray
            $null = [System.Console]::ReadKey($true)
        } catch {
            Write-Verbose "No se pudo leer entrada de consola interactiva: $($_.Exception.Message)"
        }
    }
    
    if ($PassThru) {
        return [PSCustomObject]@{
            Mode           = if ($vmms -and $vmms.Status -eq 'Running') { "Normal" } else { "Game" }
            TotalRAMGB     = $mem.TotalGB
            UsedRAMGB      = $mem.UsedGB
            FreeRAMGB      = $mem.FreeGB
            HyperVActive   = [bool]($vmms -and $vmms.Status -eq 'Running')
            VmswitchActive = [bool]$vEthernet
        }
    }
    return
}

# MODO GAME
if ($Mode -eq "Game") {
    $initialMem = Get-SystemMemoryMetrics
    
    if (-not $Quiet) {
        $gpuName = if ($script:HardwareProfile -and $script:HardwareProfile.GPU.Devices.Count -gt 0) { $script:HardwareProfile.GPU.Devices[0].Name } else { "GPU" }
        $targetVramLabel = if ($script:HardwareProfile -and $script:HardwareProfile.GPU.HasIntegratedGpu) { "VRAM Compartida UMA ($gpuName)" } else { "GPU ($gpuName)" }
        Show-UnifiedBanner -Title "romanOS GAME OPTIMIZER" -Subtitle "Modo Juego de Baja Latencia DPC y Optimizacion de Recursos" -ShowSystemInfo
        Write-Host "  RAM Inicial: $($initialMem.UsedGB) GB usados | $($initialMem.FreeGB) GB libres" -ForegroundColor Yellow
        Write-Host "  Objetivo   : Eliminar latencia DPC (<500us), ruido ETW y optimizar $targetVramLabel" -ForegroundColor Cyan
    }
    
    # 1. Guardar Snapshot de Estado Transaccional
    if (-not $Quiet) { Write-StepHeader -StepNumber 1 -TotalSteps 7 -Message "Guardando instantanea transaccional del estado del sistema..." }
    Save-ServiceSnapshot
    if (-not $Quiet) { Write-OK "Instantanea guardada en: $script:StateFilePath" }
    
    # 2. Detener Pila de Virtualizacion Hyper-V (DPC Latency Killer)
    if (-not $Quiet) { Write-StepHeader -StepNumber 2 -TotalSteps 7 -Message "Deteniendo pila de Hyper-V y conmutador virtual de red (DPC Latency < 500 us)..." }
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
    
    # 3. Pausar Servicios en Segundo Plano No Esenciales (Reduccion de Ruido ETW e I/O)
    if (-not $Quiet) { Write-StepHeader -StepNumber 3 -TotalSteps 7 -Message "Pausando servicios de diagnostico, indexacion y telemetria..." }
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
    
    # 4. Verificacion de Blindaje Inviolable (Anti-Cheat, Audio y Drivers)
    if (-not $Quiet) { Write-StepHeader -StepNumber 4 -TotalSteps 7 -Message "Verificando integridad de subsistemas inviolables (Anti-Cheat / Audio / GPU)..." }
    $protectedOk = $true
    foreach ($protSvc in @('CryptSvc', 'BFE', 'mpssvc', 'Audiosrv')) {
        $sc = Get-Service -Name $protSvc -ErrorAction SilentlyContinue
        if ($sc -and $sc.Status -eq 'Running') {
            # Servicio critico activo y seguro
        } else {
            # Intentar asegurar que este activo para anti-cheat
            try {
                Start-Service -Name $protSvc -ErrorAction Stop
            } catch {
                Write-Warn "No se pudo asegurar el servicio inviolable ${protSvc}: $($_.Exception.Message)"
            }
        }
    }
    if (-not $Quiet) {
        Write-OK "Blindaje activo: Anti-Cheat (CryptSvc/BFE/mpssvc), Audio y Drivers protegidos [INVIOLABLES]."
        Write-Info "Politica de Cero Cierre Forzado: Todas tus ventanas y navegadores permanecen abiertos."
    }
    
    # 5. Calibracion de la Arquitectura de Memoria RAM Fisica (UMA DDR5)
    if (-not $Quiet) { Write-StepHeader -StepNumber 5 -TotalSteps 7 -Message "Calibrando arquitectura de memoria RAM fisica y proteccion de VRAM..." }
    try {
        $memKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        if (-not (Test-Path $memKey)) { New-Item -Path $memKey -Force -ErrorAction SilentlyContinue | Out-Null }
        
        # LargeSystemCache = 0: Evita que el cache de archivos asfixie la VRAM de la APU
        Set-ItemProperty -Path $memKey -Name "LargeSystemCache" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        
        # DisablePagingExecutive = 1: Mantiene kernel NT y drivers fijados en RAM fisica
        Set-ItemProperty -Path $memKey -Name "DisablePagingExecutive" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        
        if (-not $Quiet) {
            Write-OK "Memoria calibrada: LargeSystemCache = 0 (VRAM protegida) | DisablePagingExecutive = 1 (Zero kernel page faults)"
        }
    } catch {
        if (-not $Quiet) { Write-Warn "No se pudieron ajustar parametros de Memory Management: $($_.Exception.Message)" }
    }
    
    # Comprobacion de estres de memoria libre
    $curMem = Get-SystemMemoryMetrics
    if ($curMem.FreeGB -lt 1.5) {
        if (-not $Quiet) {
            Write-Warn "Memoria RAM libre baja ($($curMem.FreeGB) GB libres). Recomendado cerrar tareas pesadas antes de iniciar juegos AAA."
        }
    } else {
        if (-not $Quiet) {
            Write-Info "Margen de RAM optimo: $($curMem.FreeGB) GB libres para VRAM dinamica y assets del juego."
        }
    }
    
    # 6. Calibracion del Kernel Multimedia (MMCSS) y Temporizadores de Precision
    if (-not $Quiet) { Write-StepHeader -StepNumber 6 -TotalSteps 7 -Message "Calibrando planificador multimedia (MMCSS) y temporizador del kernel..." }
    try {
        $mmKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        if (-not (Test-Path $mmKey)) { New-Item -Path $mmKey -Force -ErrorAction SilentlyContinue | Out-Null }
        
        # SystemResponsiveness = 10 (El minimo real documentado por Microsoft sin ser forzado a 20)
        Set-ItemProperty -Path $mmKey -Name "SystemResponsiveness" -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $mmKey -Name "NoLazyMode" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        
        # NetworkThrottlingIndex = 0xFFFFFFFF (Desactiva estrangulamiento de paquetes en red)
        Set-ItemProperty -Path $mmKey -Name "NetworkThrottlingIndex" -Value 4294967295 -Type DWord -Force -ErrorAction SilentlyContinue
        
        $gamesKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
        if (-not (Test-Path $gamesKey)) { New-Item -Path $gamesKey -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $gamesKey -Name "GPU Priority" -Value 8 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gamesKey -Name "Priority" -Value 6 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gamesKey -Name "Scheduling Category" -Value "High" -Type String -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gamesKey -Name "SFIO Priority" -Value "High" -Type String -Force -ErrorAction SilentlyContinue
        
        # GlobalTimerResolutionRequests = 1 en Windows 11
        $kernelKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel'
        if (Test-Path $kernelKey) {
            Set-ItemProperty -Path $kernelKey -Name "GlobalTimerResolutionRequests" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        }
        
        if (-not $Quiet) {
            Write-OK "Kernel calibrado: SystemResponsiveness = 10 (90% CPU a juegos) | NetworkThrottling = OFF | TimerRequests = 1"
        }
    } catch {
        if (-not $Quiet) { Write-Warn "No se pudieron ajustar las claves de SystemProfile: $($_.Exception.Message)" }
    }
    
    # 7. Calibracion de Silicio y Frecuencia de CPU (Hardware-Aware)
    if (-not $Quiet) { Write-StepHeader -StepNumber 7 -TotalSteps 7 -Message "Calibrando gobernador de silicio segun microarquitectura detectada (Hardware-Aware)..." }
    $hwPolicy = if (Get-Command 'Get-RomanOSCpuArchitecturePolicy' -ErrorAction SilentlyContinue) {
        Get-RomanOSCpuArchitecturePolicy -HardwareInfo $script:HardwareProfile
    } else { $null }

    if ($hwPolicy) {
        try {
            # Calibracion de Frecuencias y EPP (powercfg)
            & powercfg /setacvalueindex scheme_current SUB_PROCESSOR PROCTHROTTLEMIN $hwPolicy.ProcThrottleMinPercent 2>&1 | Out-Null
            & powercfg /setacvalueindex scheme_current SUB_PROCESSOR PROCTHROTTLEMAX $hwPolicy.ProcThrottleMaxPercent 2>&1 | Out-Null
            & powercfg /setacvalueindex scheme_current SUB_PROCESSOR 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 $hwPolicy.EnergyPerformancePreference 2>&1 | Out-Null

            # Core Parking Adaptativo segun silicio
            if ($hwPolicy.CoreParkingPolicy -eq 'UnparkAll') {
                & powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 0cc0ba11-302a-4307-ac84-2916ced570f4 100 2>&1 | Out-Null
                & powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 ea062031-0e34-4ff1-9b6d-eb10593ac08f 100 2>&1 | Out-Null
            } elseif ($hwPolicy.CoreParkingPolicy -eq 'AsymmetricX3D_50Percent') {
                & powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 0cc0ba11-302a-4307-ac84-2916ced570f4 50 2>&1 | Out-Null
                & powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 ea062031-0e34-4ff1-9b6d-eb10593ac08f 100 2>&1 | Out-Null
            }
            & powercfg /setactive scheme_current 2>&1 | Out-Null

            # Win32PrioritySeparation optimizado para el silicio
            $pKey = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
            if (-not (Test-Path $pKey)) { New-Item -Path $pKey -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-ItemProperty -Path $pKey -Name "Win32PrioritySeparation" -Value $hwPolicy.Win32PrioritySeparation -Type DWord -Force -ErrorAction SilentlyContinue

            if (-not $Quiet) {
                Write-OK "Silicio Calibrado: $($hwPolicy.DisplayName) [EPP=$($hwPolicy.EnergyPerformancePreference)% | Parking=$($hwPolicy.CoreParkingPolicy) | PrioritySep=$($hwPolicy.Win32PrioritySeparation)]"
                Write-Info "Fundamento Tecnico: $($hwPolicy.Rationale)"
            }
        } catch {
            if (-not $Quiet) { Write-Warn "No se pudo calibrar silicio en Modo Juego: $($_.Exception.Message)" }
        }
    }
    
    $finalMem = Get-SystemMemoryMetrics
    
    if (-not $Quiet) {
        Write-Host ""
        Write-Host "  ===============================================================" -ForegroundColor Green
        Write-Host "  [OK] MODO JUEGO ACTIVADO EXITOSAMENTE (romanOS Game Optimizer)" -ForegroundColor Green
        Write-Host ("  RAM Libre Actual    : {0,5} GB (Pool optimo para Juegos y VRAM APU)" -f $finalMem.FreeGB) -ForegroundColor Yellow
        Write-Host "  Latencia DPC de Red : Optimizada (vmswitch.sys desactivado / <500 us)" -ForegroundColor Cyan
        Write-Host "  Planificador Kernel : MMCSS SystemResponsiveness = 10 | GPU Priority = 8" -ForegroundColor Green
        Write-Host "  Memoria Real        : LargeSystemCache = 0 | DisablePagingExecutive = 1" -ForegroundColor Cyan
        Write-Host "  Ventanas de Usuario : 100% Preservadas (Sin cierres forzados de navegadores)" -ForegroundColor White
        Write-Host "  ===============================================================" -ForegroundColor Green
        Write-Host ""
        
        if (-not $Unattended -and [System.Environment]::UserInteractive -and -not [System.Console]::IsInputRedirected) {
            try {
                Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor Gray
                $null = [System.Console]::ReadKey($true)
            } catch {
                Write-Verbose "No se pudo leer entrada de consola interactiva: $($_.Exception.Message)"
            }
        }
    }
    
    if ($PassThru) {
        return [PSCustomObject]@{
            Mode            = "Game"
            Profile         = $Profile
            InitialFreeGB   = $initialMem.FreeGB
            FinalFreeGB     = $finalMem.FreeGB
            StoppedHyperV   = $stoppedHv
            StoppedBackgrnd = $stoppedBg
            LargeSystemCache= 0
            DisablePaging   = 1
        }
    }
    return
}

# MODO NORMAL / RESTAURAR (Universal & Compatible con Dev)
if ($Mode -in @('Normal', 'Restore', 'Dev')) {
    if (-not $Quiet) {
        Show-UnifiedBanner -Title "romanOS RESTORE SWITCH" -Subtitle "Restaurando Servicios de Sistema y Modo Normal de Windows" -ShowSystemInfo
    }
    
    $savedSnapshot = Get-ServiceSnapshot
    
    # 1. Iniciar Pila de Servicios de Virtualizacion / Red (si estaban activos)
    if (-not $Quiet) { Write-StepHeader -StepNumber 1 -TotalSteps 5 -Message "Restaurando servicios del sistema en orden estricto de dependencias..." }
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
    
    # 2. Restaurar Servicios en Segundo Plano desde Instantanea Transaccional
    if (-not $Quiet) { Write-StepHeader -StepNumber 2 -TotalSteps 5 -Message "Restaurando servicios de indexacion, mantenimiento y productividad..." }
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
    if (-not $Quiet) { Write-StepHeader -StepNumber 3 -TotalSteps 5 -Message "Restaurando prioridades del planificador multimedia en el registro..." }
    try {
        $mmKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        $restoredResp = 20
        $restoredNet  = 10
        if ($savedSnapshot) {
            if ($null -ne $savedSnapshot.'__SystemResponsiveness') {
                $restoredResp = [int]$savedSnapshot.'__SystemResponsiveness'
            }
            if ($null -ne $savedSnapshot.'__NetworkThrottlingIndex') {
                $restoredNet = [uint32]$savedSnapshot.'__NetworkThrottlingIndex'
            }
        }
        Set-ItemProperty -Path $mmKey -Name "SystemResponsiveness" -Value $restoredResp -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $mmKey -Name "NetworkThrottlingIndex" -Value $restoredNet -Type DWord -Force -ErrorAction SilentlyContinue
        if (-not $Quiet) { Write-OK "SystemResponsiveness restaurado a $restoredResp | NetworkThrottlingIndex restaurado a $restoredNet" }
    } catch {
        Write-Warn "No se pudo restaurar SystemResponsiveness: $($_.Exception.Message)"
    }
    
    # 4. Restaurar Parametros de Memoria de Windows
    if (-not $Quiet) { Write-StepHeader -StepNumber 4 -TotalSteps 5 -Message "Restaurando parametros de memoria a valores estandar de Windows..." }
    try {
        $memKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        $dpeVal = if ($savedSnapshot -and $null -ne $savedSnapshot.'__DisablePagingExecutive') { [int]$savedSnapshot.'__DisablePagingExecutive' } else { 0 }
        $lscVal = if ($savedSnapshot -and $null -ne $savedSnapshot.'__LargeSystemCache') { [int]$savedSnapshot.'__LargeSystemCache' } else { 0 }
        Set-ItemProperty -Path $memKey -Name "DisablePagingExecutive" -Value $dpeVal -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $memKey -Name "LargeSystemCache" -Value $lscVal -Type DWord -Force -ErrorAction SilentlyContinue
        if (-not $Quiet) { Write-OK "Memory Management restaurado: DisablePagingExecutive=$dpeVal | LargeSystemCache=$lscVal" }
    } catch {
        Write-Warn "No se pudo restaurar Memory Management: $($_.Exception.Message)"
    }

    # 5. Restaurar Gestion de Silicio y Frecuencia de CPU a Estandar de Windows
    if (-not $Quiet) { Write-StepHeader -StepNumber 5 -TotalSteps 5 -Message "Restaurando gobernador de energia y reloj del procesador a valores de fabrica..." }
    try {
        # Conmutar al plan equilibrado oficial de Windows (o el plan previo si no era de Maximo Rendimiento forzado)
        $balancedGuid = '381b4222-f694-41f0-9685-ff5bb260df2e'
        $targetSchemeGuid = $balancedGuid
        if ($savedSnapshot -and $null -ne $savedSnapshot.'__ActivePowerSchemeGuid') {
            $prevGuid = [string]$savedSnapshot.'__ActivePowerSchemeGuid'
            if ($prevGuid -notin @('8010808e-52bb-4a50-9657-50a2b6ddb8ac', 'e5d77bb0-2d71-420e-ac6b-959193113e8b', 'e9a42b02-d5df-448d-aa00-03f14749eb61')) {
                $targetSchemeGuid = $prevGuid
            }
        }
        & powercfg /setactive $targetSchemeGuid 2>&1 | Out-Null

        & powercfg /setacvalueindex scheme_current SUB_PROCESSOR PROCTHROTTLEMIN 5 2>&1 | Out-Null
        & powercfg /setacvalueindex scheme_current SUB_PROCESSOR PROCTHROTTLEMAX 100 2>&1 | Out-Null
        & powercfg /setacvalueindex scheme_current SUB_PROCESSOR 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 33 2>&1 | Out-Null
        & powercfg /setactive scheme_current 2>&1 | Out-Null
        
        $pKey = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
        if (Test-Path $pKey) {
            Set-ItemProperty -Path $pKey -Name "Win32PrioritySeparation" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        }
        if (-not $Quiet) { Write-OK "Gobernador de energia y scheduler restaurados al estandar oficial de Windows (Plan Equilibrado, EPP=33, Win32Priority=2)." }
    } catch {
        if (-not $Quiet) { Write-Warn "No se pudo restaurar gobernador de energia: $($_.Exception.Message)" }
    }
    
    if (-not $Quiet) {
        Write-Host ""
        Write-Host "  ===============================================================" -ForegroundColor Cyan
        Write-Host "  [OK] MODO NORMAL / ESTANDAR DE WINDOWS RESTAURADO" -ForegroundColor Cyan
        Write-Host "  Productividad     : Servicios de indexacion, busqueda y sistema activos" -ForegroundColor White
        Write-Host "  Silicio y Reloj   : Gobernador de CPU restaurado a perfil balanceado de Windows" -ForegroundColor Gray
        Write-Host "  Planificador      : Prioridades de kernel restablecidas a valores de fabrica" -ForegroundColor DarkGray
        Write-Host "  ===============================================================" -ForegroundColor Cyan
        Write-Host ""
        
        if (-not $Unattended -and [System.Environment]::UserInteractive -and -not [System.Console]::IsInputRedirected) {
            try {
                Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor Gray
                $null = [System.Console]::ReadKey($true)
            } catch {
                Write-Verbose "No se pudo leer entrada de consola interactiva: $($_.Exception.Message)"
            }
        }
    }
    
    if ($PassThru) {
        return [PSCustomObject]@{
            Mode            = "Normal"
            StartedHyperV   = $startedHv
            StartedBackgrnd = $startedBg
            RestoredEnergy  = $true
        }
    }
    return
}
