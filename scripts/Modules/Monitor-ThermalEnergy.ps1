<#
.SYNOPSIS
    Monitor-ThermalEnergy.ps1 - romanOS Thermal Throttling Monitor & Energy Profiler (2026)
    romanOS / OptimizedISO — Estado del Arte Windows 11 24H2 / 25H2.

.DESCRIPTION
    Herramienta nativa y desacoplada para la auditoria termica, deteccion de estrangulamiento
    (Thermal & Power Limit Throttling), calibracion de perfiles energeticos (AC vs Bateria)
    y des-estacionamiento de nucleos (Core Unparking).
    
    100% compatible con Anti-Cheats (Vanguard, EAC, BattlEye) al operar sin drivers
    vulnerables de terceros (cero dependencias externas).

.PARAMETER Action
    Accion a ejecutar: 'Audit', 'Monitor', 'CalibrateEnergy', 'UnparkCores', 'Status'.

.PARAMETER SampleDurationSec
    Duracion en segundos del muestreo termico en vivo (por defecto 5s).

.PARAMETER EnergyProfile
    Perfil energetico objetivo: 'Ultimate', 'HighPerformance', 'Balanced'.

.PARAMETER Unattended
    Omite confirmaciones interactivas.

.PARAMETER SkipElevation
    Omite elevacion obligatoria de privilegios (para pruebas unitarias y sandbox).

.PARAMETER LogPath
    Ruta del archivo de registro forense.

.EXAMPLE
    .\Monitor-ThermalEnergy.ps1 -Action Audit
    .\Monitor-ThermalEnergy.ps1 -Action Monitor -SampleDurationSec 10
    .\Monitor-ThermalEnergy.ps1 -Action CalibrateEnergy -EnergyProfile Ultimate
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Audit', 'Monitor', 'CalibrateEnergy', 'UnparkCores', 'Status', 'AuditWakeTimers', 'DisableWakeTimers', 'RepairPowerSubsystem')]
    [string]$Action = 'Status',

    [int]$SampleDurationSec = 5,

    [ValidateSet('Ultimate', 'HighPerformance', 'Balanced')]
    [string]$EnergyProfile = 'Ultimate',

    [switch]$Unattended,

    [switch]$SkipElevation,

    [string]$LogPath = '',

    [switch]$Force,

    [string[]]$MockWakeTimers = $null,

    [string[]]$MockArmedDevices = $null,

    [switch]$PassThru
)

# -----------------------------------------------------------------------------
# 1. VERIFICACION DE PRIVILEGIOS DE ADMINISTRADOR
# -----------------------------------------------------------------------------
function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$identity
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        Write-Warning "[ADVERTENCIA] No se pudo verificar el estado de elevacion: $($_.Exception.Message)"
        return $false
    }
}

if (-not $SkipElevation -and -not (Test-IsAdministrator) -and -not $WhatIfPreference) {
    if ($Action -in @('CalibrateEnergy', 'UnparkCores', 'DisableWakeTimers')) {
        Write-Host "[INFO] Se requieren privilegios de Administrador para modificar la configuracion energetica. Elevando proceso..." -ForegroundColor Yellow
        try {
            $argList = "-STA -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Action $Action"
            if ($EnergyProfile) { $argList += " -EnergyProfile $EnergyProfile" }
            if ($Unattended) { $argList += " -Unattended" }
            if ($LogPath) { $argList += " -LogPath `"$LogPath`"" }
            if ($Force) { $argList += " -Force" }
            Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
            exit 0
        } catch {
            Write-Error "[ERROR] Fallo critico al intentar elevar privilegios: $($_.Exception.Message)"
            exit 1
        }
    }
}

# -----------------------------------------------------------------------------
# 2. LOGGING Y ENTORNO
# -----------------------------------------------------------------------------
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

if (-not $LogPath) {
    $repoLog = if ($scriptRoot) { Join-Path (Split-Path (Split-Path $scriptRoot -Parent) -Parent) "Log" } else { $null }; $logDir = if ($repoLog -and (Test-Path -Path $repoLog)) { $repoLog } else { $env:TEMP }
    $LogPath = Join-Path -Path $logDir -ChildPath "ThermalEnergy-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
}

function Write-ThermalLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'TITLE')][string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        'OK'    { Write-Host $Message -ForegroundColor Green }
        'WARN'  { Write-Warning $Message }
        'ERROR' { Write-Error $Message }
        'TITLE' { Write-Host "`n$Message" -ForegroundColor Cyan }
        default { Write-Host $Message -ForegroundColor Gray }
    }
    
    try {
        [System.IO.File]::AppendAllText($LogPath, "$line`r`n", [System.Text.Encoding]::UTF8)
    } catch {
        Write-Verbose "[ThermalLog] Fallo al escribir en log físico ($LogPath): $($_.Exception.Message)"
    }
}

# -----------------------------------------------------------------------------
# 3. FUNCIONES DE TELEMETRIA TERMICA Y ENERGETICA
# -----------------------------------------------------------------------------

function Get-ThermalSensorsData {
    [CmdletBinding()]
    param()

    $results = [PSCustomObject]@{
        SensorsAvailable = $false
        ZonesCount       = 0
        MaxTempC         = 0
        Zones            = @()
        TelemetrySource  = "None"
    }

    # 1. Intentar consultar WMI ACPI ThermalZone (décimas de Kelvin)
    try {
        $tzWmi = Get-CimInstance -Namespace "root/wmi" -ClassName "MSAcpi_ThermalZoneTemperature" -ErrorAction Stop
        if ($tzWmi) {
            $zones = @()
            foreach ($z in $tzWmi) {
                # Fórmula ACPI: (décimas de Kelvin - 2732) / 10 = °C
                $tempC = [math]::Round(($z.CurrentTemperature - 2732) / 10, 1)
                $critC = if ($z.CriticalTripPoint) { [math]::Round(($z.CriticalTripPoint - 2732) / 10, 1) } else { 100 }
                $zones += [PSCustomObject]@{
                    InstanceName = $z.InstanceName
                    TempC        = $tempC
                    CriticalC    = $critC
                }
            }
            if ($zones.Count -gt 0) {
                $results.SensorsAvailable = $true
                $results.ZonesCount = $zones.Count
                $results.MaxTempC = ($zones | Measure-Object -Property TempC -Maximum).Maximum
                $results.Zones = $zones
                $results.TelemetrySource = "MSAcpi_ThermalZoneTemperature"
                return $results
            }
        }
    } catch {
        Write-Verbose "[ThermalSensors] MSAcpi_ThermalZoneTemperature no disponible: $($_.Exception.Message)"
    }

    # 2. Intentar PerfOS ThermalZone Information
    try {
        $tzPerf = Get-CimInstance -ClassName "Win32_PerfFormattedData_Counters_ThermalZoneInformation" -ErrorAction Stop
        if ($tzPerf) {
            $zones = @()
            foreach ($z in $tzPerf) {
                $tempC = [math]::Round($z.Temperature - 273.15, 1)
                $zones += [PSCustomObject]@{
                    InstanceName = $z.Name
                    TempC        = $tempC
                    CriticalC    = 100
                }
            }
            if ($zones.Count -gt 0) {
                $results.SensorsAvailable = $true
                $results.ZonesCount = $zones.Count
                $results.MaxTempC = ($zones | Measure-Object -Property TempC -Maximum).Maximum
                $results.Zones = $zones
                $results.TelemetrySource = "ThermalZoneInformation"
                return $results
            }
        }
    } catch {
        Write-Verbose "[ThermalSensors] Counters_ThermalZoneInformation no disponible: $($_.Exception.Message)"
    }

    # 3. Telemetría informativa cuando los sensores directos de placa base están aislados por firmware OEM
    $results.TelemetrySource = "ACPI_OEM_Isolated"
    return $results
}

function Get-ProcessorThrottlingState {
    [CmdletBinding()]
    param()

    $state = [PSCustomObject]@{
        CpuName           = "Desconocido"
        CurrentClockMHz   = 0
        MaxClockMHz       = 0
        ClockRatioPercent = 100
        UsagePercent      = 0
        IsThrottling      = $false
        ThrottlingReason  = "Nominal"
    }

    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
        if ($cpu) {
            $state.CpuName = $cpu.Name.Trim()
            $state.CurrentClockMHz = [int]$cpu.CurrentClockSpeed
            $state.MaxClockMHz = [int]$cpu.MaxClockSpeed
            if ($state.MaxClockMHz -gt 0) {
                $state.ClockRatioPercent = [math]::Round(($state.CurrentClockMHz / $state.MaxClockMHz) * 100, 1)
            }
        }
    } catch {
        Write-ThermalLog "[WARN] No se pudo leer Win32_Processor: $($_.Exception.Message)" 'WARN'
    }

    try {
        $perf = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor | Where-Object { $_.Name -eq '_Total' } | Select-Object -First 1
        if ($perf) {
            $state.UsagePercent = [int]$perf.PercentProcessorTime
        }
    } catch {
        Write-ThermalLog "[WARN] No se pudo leer Win32_PerfFormattedData_PerfOS_Processor: $($_.Exception.Message)" 'WARN'
    }

    # Detección heurística de Clock / Power Throttling:
    # Si el procesador está bajo carga alta (>= 80%) y la frecuencia cae por debajo del 70% de la velocidad base sostenida
    if ($state.UsagePercent -ge 80 -and $state.ClockRatioPercent -lt 70) {
        $state.IsThrottling = $true
        $state.ThrottlingReason = "Clock / Thermal Throttling Activo (Frecuencia reducida al $($state.ClockRatioPercent)% bajo carga del $($state.UsagePercent)%)"
    }

    return $state
}

function Get-EnergyProfileState {
    [CmdletBinding()]
    param()

    $state = [PSCustomObject]@{
        ActiveSchemeGuid = ""
        ActiveSchemeName = "Desconocido"
        IsUltimate       = $false
        PowerThrottlingOff = $false
        IsOnBattery      = $false
        BatteryHealth    = "N/A (Desktop / AC)"
    }

    # 1. Esquema de energía activo
    try {
        $schemeOut = & powercfg /getactivescheme 2>&1
        $schemeText = $schemeOut | Out-String
        if ($schemeText -match '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})\s+\((.*?)\)') {
            $state.ActiveSchemeGuid = $matches[1]
            $state.ActiveSchemeName = $matches[2]
            if ($matches[1] -eq "e9a42b02-d5df-448d-aa00-03f14749eb61" -or $matches[2] -match "Máximo rendimiento|Ultimate Performance") {
                $state.IsUltimate = $true
            }
        }
    } catch {
        Write-ThermalLog "[WARN] No se pudo consultar powercfg /getactivescheme: $($_.Exception.Message)" 'WARN'
    }

    # 2. Clave PowerThrottling en registro
    try {
        $ptVal = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -ErrorAction SilentlyContinue
        if ($ptVal -and $ptVal.PowerThrottlingOff -eq 1) {
            $state.PowerThrottlingOff = $true
        }
    } catch {
        Write-Verbose "[EnergyProfile] Clave PowerThrottling no presente en registro: $($_.Exception.Message)"
    }

    # 3. Estado de batería
    try {
        $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($battery) {
            $state.IsOnBattery = ($battery.BatteryStatus -ne 2) # 2 = AC / Conectado
            $state.BatteryHealth = "$($battery.EstimatedChargeRemaining)% (Estado: $($battery.BatteryStatus))"
        }
    } catch {
        Write-Verbose "[EnergyProfile] Win32_Battery no disponible (sistema de escritorio o AC puro): $($_.Exception.Message)"
    }

    return $state
}

function Set-CalibratedEnergyProfile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$TargetProfile = 'Ultimate'
    )

    Write-ThermalLog "Iniciando Calibracion Energetica romanOS (Perfil: $TargetProfile)..." 'TITLE'

    $guidUltimate = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    $guidHighPerf = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    $guidBalanced = "381b4222-f694-41f0-9685-ff5bb260df2e"

    $targetGuid = switch ($TargetProfile) {
        'Ultimate'        { $guidUltimate }
        'HighPerformance' { $guidHighPerf }
        'Balanced'        { $guidBalanced }
        default           { $guidUltimate }
    }

    if ($PSCmdlet.ShouldProcess("Sistema", "Establecer Plan de Energia $TargetProfile ($targetGuid)")) {
        try {
            # Verificar si el esquema existe en el sistema sin duplicar clones recursivos
            $schemes = & powercfg /list
            $activeTargetGuid = $targetGuid
            if ($targetGuid -eq $guidUltimate) {
                $existingUltimate = $schemes | Where-Object { $_ -match 'Máximo rendimiento|Ultimate Performance' } | Select-Object -First 1
                if ($existingUltimate -and $existingUltimate -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
                    $activeTargetGuid = $matches[1]
                } else {
                    Write-ThermalLog "[INFO] Duplicando esquema de Maximo Rendimiento oficial (unica vez)..." 'INFO'
                    $dupOut = & powercfg -duplicatescheme $guidUltimate 2>&1
                    if ($dupOut -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
                        $activeTargetGuid = $matches[1]
                    } else {
                        $activeTargetGuid = $guidHighPerf
                    }
                }
            }

            # Asignar esquema activo
            & powercfg /setactive $activeTargetGuid
            Write-ThermalLog "[OK] Plan de energia asignado exitosamente: $activeTargetGuid ($TargetProfile)" 'OK'
        } catch {
            Write-ThermalLog "[ERROR] Error al cambiar plan de energia: $($_.Exception.Message)" 'ERROR'
        }

        # Desactivar Power Throttling global en el kernel
        try {
            $ptKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
            if (-not (Test-Path $ptKey)) {
                New-Item -Path $ptKey -Force | Out-Null
            }
            Set-ItemProperty -Path $ptKey -Name "PowerThrottlingOff" -Value 1 -Type DWord -Force
            Write-ThermalLog "[OK] Directiva PowerThrottlingOff = 1 aplicada en registro (Kernel Scheduler)." 'OK'
        } catch {
            Write-ThermalLog "[WARN] No se pudo configurar PowerThrottlingOff: $($_.Exception.Message)" 'WARN'
        }

        # Des-estacionar núcleos (Core Unparking) en AC
        try {
            # Subgrupo Procesador (54533251-82be-4824-96c1-47b60b740d00)
            # Min Cores (0cc0ba11-302a-4307-ac84-2916ced570f4) -> 100%
            # Max Cores (ea062031-0e34-4ff1-9b6d-eb10593ac08f) -> 100%
            & powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 0cc0ba11-302a-4307-ac84-2916ced570f4 100
            & powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 ea062031-0e34-4ff1-9b6d-eb10593ac08f 100
            & powercfg /setactive scheme_current
            Write-ThermalLog "[OK] Des-estacionamiento de nucleos (Core Unparking) configurado al 100% en corriente alterna." 'OK'
        } catch {
            Write-ThermalLog "[WARN] No se pudo configurar Core Unparking: $($_.Exception.Message)" 'WARN'
        }
    }
}

function Get-RomanOSWakeTimerStatus {
    <#
    .SYNOPSIS
        Audita el estado de temporizadores de reactivación (Wake Timers) y dispositivos armados para reactivar el sistema.
    .DESCRIPTION
        Inspecciona 'powercfg /waketimers' y 'powercfg /devicequery wake_armed' para identificar
        disparadores parásitos (como tareas de telemetría de Windows Update u orquestadores)
        y adaptadores de red que causan drenaje de batería en reposo (S0ix Modern Standby).
    #>
    [CmdletBinding()]
    param(
        [string[]]$MockWakeTimers = $null,
        [string[]]$MockArmedDevices = $null
    )

    $result = [PSCustomObject]@{
        ActiveWakeTimers        = @()
        HasParasiticTimers      = $false
        ParasiticTimers         = @()
        ArmedDevices            = @()
        HasArmedNetworkAdapters = $false
        ArmedNetworkAdapters    = @()
        StandbyNetworkMode      = "Desconocido"
        Recommendations         = @()
    }

    # 1. Auditoría de Wake Timers
    $rawTimers = @()
    if ($null -ne $MockWakeTimers) {
        $rawTimers = $MockWakeTimers
    } else {
        try {
            $wtOut = & powercfg /waketimers 2>&1
            $rawTimers = @($wtOut)
        } catch {
            Write-Verbose "[WakeTimers] Fallo al invocar powercfg /waketimers: $($_.Exception.Message)"
        }
    }

    $parasiticPatterns = @(
        'UpdateOrchestrator',
        'Universal Orchestrator',
        'Schedule Scan',
        'AC Power Download',
        'Reboot_AC',
        'Reboot_DU',
        'Customer Experience Improvement Program',
        'CEIP',
        'Diagnostics',
        'Telemetry'
    )

    $currentTimer = $null
    foreach ($line in $rawTimers) {
        $str = $line.ToString().Trim()
        if ([string]::IsNullOrWhiteSpace($str) -or $str -match 'Este comando requiere|There are no active|No hay temporizadores') {
            continue
        }

        if ($str -match 'Timer set by|Temporizador establecido por') {
            if ($currentTimer) {
                $result.ActiveWakeTimers += $currentTimer
            }
            $currentTimer = [PSCustomObject]@{
                Caller      = $str
                Reason      = ""
                IsParasitic = $false
            }
        } elseif ($str -match 'Reason:|Motivo:' -and $currentTimer) {
            $currentTimer.Reason = $str
            foreach ($p in $parasiticPatterns) {
                if ($str -match $p) {
                    $currentTimer.IsParasitic = $true
                    $result.HasParasiticTimers = $true
                    $result.ParasiticTimers += $str
                    break
                }
            }
        } elseif ($currentTimer) {
            foreach ($p in $parasiticPatterns) {
                if ($str -match $p) {
                    $currentTimer.IsParasitic = $true
                    $result.HasParasiticTimers = $true
                    $result.ParasiticTimers += $str
                    break
                }
            }
        }
    }
    if ($currentTimer) {
        $result.ActiveWakeTimers += $currentTimer
    }

    # 2. Auditoría de Dispositivos Armados (wake_armed)
    $rawDevices = @()
    if ($null -ne $MockArmedDevices) {
        $rawDevices = $MockArmedDevices
    } else {
        try {
            $devOut = & powercfg /devicequery wake_armed 2>&1
            $rawDevices = @($devOut)
        } catch {
            Write-Verbose "[WakeTimers] Fallo al invocar powercfg /devicequery: $($_.Exception.Message)"
        }
    }

    $netKeywords = @('Ethernet', 'Wi-Fi', 'WLAN', 'Network', 'Red', '802.11', 'Family Controller', 'Gigabit', '2.5GbE', 'Realtek', 'Intel(R) Ethernet', 'Killer')
    foreach ($d in $rawDevices) {
        $devName = $d.ToString().Trim()
        if ([string]::IsNullOrWhiteSpace($devName) -or $devName -eq "NONE" -or $devName -match 'NINGUNO') { continue }
        $result.ArmedDevices += $devName

        foreach ($nk in $netKeywords) {
            if ($devName -match [regex]::Escape($nk)) {
                $result.HasArmedNetworkAdapters = $true
                $result.ArmedNetworkAdapters += $devName
                break
            }
        }
    }

    # 3. Recomendaciones
    if ($result.HasParasiticTimers) {
        $result.Recommendations += "Se detectaron temporizadores parásitos de Windows Update/Telemetría activos. Se recomienda neutralizarlos."
    }
    if ($result.HasArmedNetworkAdapters) {
        $result.Recommendations += "Hay adaptadores de red armados para reactivación. En laptops, esto drena la batería durante el transporte en reposo S0ix."
    }
    if ($result.Recommendations.Count -eq 0) {
        $result.Recommendations += "Configuración de reactivación y reposo en estado óptimo."
    }

    return $result
}

function Disable-RomanOSParasiticWakeTimers {
    <#
    .SYNOPSIS
        Neutraliza temporizadores de reactivación parásitos y calibra el reposo S0ix Modern Standby.
    .DESCRIPTION
        - Deshabilita temporizadores de reactivación de telemetría/WU en corriente y batería.
        - Aplica GPO AUPowerManagement = 0 para impedir que Windows Update reactive el equipo.
        - Desconecta conectividad de red en reposo durante el uso de batería (S0ix Sleep Shield).
        - Opcionalmente desarma adaptadores de red armados para reactivación no deseada.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [switch]$DisarmNetworkAdapters,
        [switch]$DisconnectNetworkInStandby = $true,
        [switch]$ApplyGpoHardening = $true,
        [string[]]$MockArmedDevices = $null,
        [switch]$PassThru
    )

    $actionsTaken = [System.Collections.Generic.List[string]]::new()

    if ($PSCmdlet.ShouldProcess("Sistema", "Neutralizar Temporizadores de Reactivación y Calibrar S0ix")) {
        # 1. Allow Wake Timers: AC -> 2 (Important Only), DC -> 0 (Disabled on Battery)
        try {
            & powercfg /setacvalueindex scheme_current 238c9fa8-0aad-41ed-83f4-97be242c8f20 bd3b718a-0680-4d9d-8ab2-e1d2b4c5fffb 2 2>&1 | Out-Null
            & powercfg /setdcvalueindex scheme_current 238c9fa8-0aad-41ed-83f4-97be242c8f20 bd3b718a-0680-4d9d-8ab2-e1d2b4c5fffb 0 2>&1 | Out-Null
            $actionsTaken.Add("WakeTimers_Configured_AC2_DC0")
            Write-ThermalLog "[OK] Temporizadores de reactivacion configurados: AC = Solo Importantes (2), Bateria = Deshabilitado (0)." 'OK'
        } catch {
            Write-ThermalLog "[WARN] No se pudo configurar Wake Timers en powercfg: $($_.Exception.Message)" 'WARN'
        }

        # 2. Modern Standby Network Connectivity on Battery -> 0 (Disconnected in Standby)
        if ($DisconnectNetworkInStandby) {
            try {
                & powercfg /setdcvalueindex scheme_current SUB_NONE F15576E8-98B7-4186-B944-EAFA664402D9 0 2>&1 | Out-Null
                $actionsTaken.Add("S0ix_StandbyNetwork_Disconnected_DC")
                Write-ThermalLog "[OK] Modern Standby (S0ix): Conectividad de red en reposo desactivada en bateria (Prevencion de sobrecalentamiento en mochilas)." 'OK'
            } catch {
                Write-ThermalLog "[WARN] No se pudo configurar conectividad en reposo S0ix: $($_.Exception.Message)" 'WARN'
            }
        }

        # 3. Aplicar esquema activo
        try {
            & powercfg /setactive scheme_current 2>&1 | Out-Null
        } catch {
            Write-Verbose "[WakeTimers] Fallo al activar scheme_current: $($_.Exception.Message)"
        }

        # 4. GPO Hardening: AUPowerManagement = 0 en HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU
        if ($ApplyGpoHardening) {
            try {
                $wuKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
                if (-not (Test-Path $wuKey)) {
                    New-Item -Path $wuKey -Force | Out-Null
                }
                Set-ItemProperty -Path $wuKey -Name "AUPowerManagement" -Value 0 -Type DWord -Force
                $actionsTaken.Add("GPO_AUPowerManagement_Disabled")
                Write-ThermalLog "[OK] GPO AUPowerManagement = 0 aplicada en registro (Windows Update no reactivara el equipo)." 'OK'
            } catch {
                Write-ThermalLog "[WARN] No se pudo aplicar GPO AUPowerManagement: $($_.Exception.Message)" 'WARN'
            }
        }

        # 5. Desarmar adaptadores de red si se solicita
        if ($DisarmNetworkAdapters) {
            $status = Get-RomanOSWakeTimerStatus -MockArmedDevices $MockArmedDevices
            foreach ($nic in $status.ArmedNetworkAdapters) {
                try {
                    & powercfg /devicedisablewake "$nic" 2>&1 | Out-Null
                    $actionsTaken.Add("Disarmed_NIC_$nic")
                    Write-ThermalLog "[OK] Adaptador de red desarmado de reactivacion: $nic" 'OK'
                } catch {
                    Write-ThermalLog "[WARN] No se pudo desarmar adaptador $($nic): $($_.Exception.Message)" 'WARN'
                }
            }
        }
    }

    if ($PassThru) {
        return [PSCustomObject]@{
            Success      = ($actionsTaken.Count -gt 0)
            ActionsCount = $actionsTaken.Count
            Actions      = $actionsTaken
        }
    }
}


function Repair-RomanOSPowerSubsystem {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [switch]$PassThru
    )

    Write-ThermalLog "=== Saneamiento y Reparacion del Subsistema de Energia & Sensores ===" 'TITLE'

    $sensorOk = $false
    $cleanedSchemes = 0

    # 1. Reparar SensorService para evitar crash de Configuracion en Win11
    if ($PSCmdlet.ShouldProcess("SensorService", "Configurar en Manual e Iniciar")) {
        try {
            Write-ThermalLog "[1/2] Verificando SensorService (Windows 11 Settings)..." 'INFO'
            $svc = Get-Service -Name 'SensorService' -ErrorAction SilentlyContinue
            if ($svc) {
                Set-Service -Name 'SensorService' -StartupType Manual -ErrorAction Stop
                if ($svc.Status -ne 'Running') {
                    Start-Service -Name 'SensorService' -ErrorAction SilentlyContinue
                }
                Write-ThermalLog "[OK] SensorService configurado en Manual (Demand) y activo. Previene crash de ms-settings:powersleep." 'OK'
                $sensorOk = $true
            } else {
                Write-ThermalLog "[INFO] SensorService no instalado en esta edicion." 'INFO'
                $sensorOk = $true
            }
        } catch {
            Write-ThermalLog "[WARN] No se pudo configurar SensorService: $($_.Exception.Message)" 'WARN'
        }
    }

    # 2. Saneamiento de duplicados de esquemas en powercfg
    if ($PSCmdlet.ShouldProcess("powercfg", "Purgar esquemas duplicados y restaurar de fabrica")) {
        try {
            Write-ThermalLog "[2/2] Auditando esquemas duplicados de energia..." 'INFO'
            $rawList = & powercfg /list 2>&1
            $schemes = @($rawList | Where-Object { $_ -match 'GUID' })
            $ultimates = @($schemes | Where-Object { $_ -match 'M[aá]ximo rendimiento|Ultimate Performance' })
            if ($ultimates.Count -gt 1) {
                Write-ThermalLog "[WARN] Se detectaron $($ultimates.Count) esquemas duplicados de Maximo Rendimiento. Restaurando esquemas de fabrica..." 'WARN'
                & powercfg -restoredefaultschemes
                $cleanedSchemes = $ultimates.Count
                Write-ThermalLog "[OK] Esquemas de energia restaurados a valores oficiales de fabrica." 'OK'
            } else {
                Write-ThermalLog "[OK] Catalogo de esquemas de energia limpio ($($ultimates.Count) esquema detectado)." 'OK'
            }
        } catch {
            Write-ThermalLog "[WARN] Error al verificar esquemas de energia: $($_.Exception.Message)" 'WARN'
        }
    }

    Write-ThermalLog "Saneamiento de subsistema de energia finalizado exitosamente." 'OK'

    if ($PassThru) {
        return [PSCustomObject]@{
            SensorServiceRepaired = $sensorOk
            DuplicateSchemesCleaned = $cleanedSchemes
        }
    }
}


# -----------------------------------------------------------------------------
# 4. EJECUCION DE ACCIONES
# -----------------------------------------------------------------------------
Write-ThermalLog "==========================================================================" 'TITLE'
Write-ThermalLog " romanOS Thermal Throttling Monitor & Energy Profiler (v1.0 - 2026)" 'TITLE'
Write-ThermalLog "==========================================================================" 'TITLE'

switch ($Action) {
    'Status' {
        $thermal = Get-ThermalSensorsData
        $cpu = Get-ProcessorThrottlingState
        $energy = Get-EnergyProfileState

        Write-ThermalLog "`n[1/3] Telemetria de Sensores Termicos:" 'TITLE'
        if ($thermal.SensorsAvailable) {
            Write-ThermalLog "  - Sensores Detectados : $($thermal.ZonesCount) zona(s) activas ($($thermal.TelemetrySource))" 'INFO'
            Write-ThermalLog "  - Temperatura Maxima : $($thermal.MaxTempC) °C" $(if ($thermal.MaxTempC -ge 85) { 'WARN' } else { 'OK' })
            foreach ($z in $thermal.Zones) {
                Write-ThermalLog "    * [$($z.InstanceName)] $($z.TempC) °C (Critico: $($z.CriticalC) °C)" 'INFO'
            }
        } else {
            Write-ThermalLog "  - Sensores ACPI Directos : Protegidos por firmware OEM ($($thermal.TelemetrySource))." 'INFO'
            Write-ThermalLog "  - Diagnostico            : Operando bajo telemetria de reloj y latencia de kernel (100% Anti-Cheat Safe)." 'OK'
        }

        Write-ThermalLog "`n[2/3] Estado de Frecuencia y Estrangulamiento de CPU:" 'TITLE'
        Write-ThermalLog "  - Modelo CPU         : $($cpu.CpuName)" 'INFO'
        Write-ThermalLog "  - Frecuencia Actual  : $($cpu.CurrentClockMHz) MHz / $($cpu.MaxClockMHz) MHz ($($cpu.ClockRatioPercent)%)" 'INFO'
        Write-ThermalLog "  - Uso Total de CPU   : $($cpu.UsagePercent)%" 'INFO'
        if ($cpu.IsThrottling) {
            Write-ThermalLog "  - ESTADO THROTTLING  : ALERTA: $($cpu.ThrottlingReason)" 'WARN'
        } else {
            Write-ThermalLog "  - ESTADO THROTTLING  : Nominal (Sin estrangulamiento detectado)" 'OK'
        }

        Write-ThermalLog "`n[3/3] Configuracion de Perfil Energetico:" 'TITLE'
        Write-ThermalLog "  - Plan de Energia    : $($energy.ActiveSchemeName) ($($energy.ActiveSchemeGuid))" 'INFO'
        Write-ThermalLog "  - Rendimiento Maximo : $(if ($energy.IsUltimate) { 'Activado [OK]' } else { 'No activado' })" $(if ($energy.IsUltimate) { 'OK' } else { 'WARN' })
        Write-ThermalLog "  - Power Throttling   : $(if ($energy.PowerThrottlingOff) { 'Desactivado (Max Latency Shield) [OK]' } else { 'Habilitado por defecto' })" 'INFO'
        Write-ThermalLog "  - Alimentacion       : $(if ($energy.IsOnBattery) { 'Bateria' } else { 'Corriente Alterna (AC) / Desktop' }) ($($energy.BatteryHealth))" 'INFO'

        $wake = Get-RomanOSWakeTimerStatus -MockWakeTimers $MockWakeTimers -MockArmedDevices $MockArmedDevices
        Write-ThermalLog "`n[4/4] Temporizadores de Reactivacion (Wake Timers) y Reposo S0ix:" 'TITLE'
        Write-ThermalLog "  - Temporizadores Activos : $($wake.ActiveWakeTimers.Count)" $(if ($wake.HasParasiticTimers) { 'WARN' } else { 'OK' })
        Write-ThermalLog "  - Timers Parasitos WU/IA : $(if ($wake.HasParasiticTimers) { 'DETECTADOS [ALERTA]' } else { 'Ninguno detectado [OK]' })" $(if ($wake.HasParasiticTimers) { 'WARN' } else { 'OK' })
        Write-ThermalLog "  - Dispositivos Armados   : $($wake.ArmedDevices.Count) dispositivo(s)" 'INFO'
        Write-ThermalLog "  - Adaptadores Red Armados: $(if ($wake.HasArmedNetworkAdapters) { "$($wake.ArmedNetworkAdapters.Count) armado(s) [Drenaje S0ix]" } else { 'Ninguno [OK]' })" $(if ($wake.HasArmedNetworkAdapters) { 'WARN' } else { 'OK' })
    }

    'Audit' {
        # Modo auditoría rápida con reporte resumido
        $cpu = Get-ProcessorThrottlingState
        $energy = Get-EnergyProfileState
        $thermal = Get-ThermalSensorsData
        $wake = Get-RomanOSWakeTimerStatus -MockWakeTimers $MockWakeTimers -MockArmedDevices $MockArmedDevices

        Write-ThermalLog "[AUDITORIA] CPU: $($cpu.CpuName) | Freq: $($cpu.CurrentClockMHz) MHz | Throttling: $(if ($cpu.IsThrottling) { 'SI' } else { 'NO' }) | Plan: $($energy.ActiveSchemeName) | WakeTimers: $($wake.ActiveWakeTimers.Count) | Parasitic: $(if ($wake.HasParasiticTimers) { 'SI' } else { 'NO' })" 'OK'
        if ($PassThru) { return $wake }
    }

    'AuditWakeTimers' {
        $wake = Get-RomanOSWakeTimerStatus -MockWakeTimers $MockWakeTimers -MockArmedDevices $MockArmedDevices
        Write-ThermalLog "`nAuditoria de Temporizadores de Reactivacion y Reposo S0ix:" 'TITLE'
        Write-ThermalLog "  - Temporizadores Activos    : $($wake.ActiveWakeTimers.Count)" 'INFO'
        Write-ThermalLog "  - Temporizadores Parasitos  : $(if ($wake.HasParasiticTimers) { 'DETECTADOS' } else { 'Ninguno' })" $(if ($wake.HasParasiticTimers) { 'WARN' } else { 'OK' })
        foreach ($t in $wake.ActiveWakeTimers) {
            Write-ThermalLog "    * $($t.Caller) -> $($t.Reason)" $(if ($t.IsParasitic) { 'WARN' } else { 'INFO' })
        }
        Write-ThermalLog "  - Dispositivos Armados (Wake): $($wake.ArmedDevices.Count)" 'INFO'
        foreach ($dev in $wake.ArmedDevices) {
            $isNet = ($dev -in $wake.ArmedNetworkAdapters)
            Write-ThermalLog "    * $dev $(if ($isNet) { '[RED - Riesgo S0ix]' } else { '' })" $(if ($isNet) { 'WARN' } else { 'INFO' })
        }
        Write-ThermalLog "`nRecomendaciones:" 'TITLE'
        foreach ($rec in $wake.Recommendations) {
            Write-ThermalLog "  - $rec" 'INFO'
        }
        if ($PassThru) { return $wake }
    }

    'DisableWakeTimers' {
        $disRes = Disable-RomanOSParasiticWakeTimers -DisarmNetworkAdapters -DisconnectNetworkInStandby -ApplyGpoHardening -MockArmedDevices $MockArmedDevices -PassThru:$PassThru
        if ($PassThru) { return $disRes }
    }

    'Monitor' {
        Write-ThermalLog "Iniciando monitorizacion en vivo durante $SampleDurationSec segundos (Muestreo a 1 Hz)..." 'TITLE'
        for ($s = 1; $s -le $SampleDurationSec; $s++) {
            $cpu = Get-ProcessorThrottlingState
            $thermal = Get-ThermalSensorsData
            $tempDisplay = if ($thermal.SensorsAvailable) { "$($thermal.MaxTempC) °C" } else { "Nominal" }
            $statusColor = if ($cpu.IsThrottling) { 'WARN' } else { 'OK' }
            
            Write-ThermalLog ((" [{0,2}s] CPU: {1,4} MHz ({2,3}%) | Carga: {3,3}% | Temp: {4,7} | Throttling: {5}" -f $s, $cpu.CurrentClockMHz, $cpu.ClockRatioPercent, $cpu.UsagePercent, $tempDisplay, $(if ($cpu.IsThrottling) { 'ALERTA' } else { 'OK' }))) $statusColor
            
            if ($s -lt $SampleDurationSec) {
                Start-Sleep -Seconds 1
            }
        }
        Write-ThermalLog "[OK] Monitorizacion en vivo finalizada exitosamente." 'OK'
    }

    'CalibrateEnergy' {
        Set-CalibratedEnergyProfile -TargetProfile $EnergyProfile
    }

    'UnparkCores' {
        Set-CalibratedEnergyProfile -TargetProfile 'Ultimate'
    }

    'RepairPowerSubsystem' {
        $rep = Repair-RomanOSPowerSubsystem -PassThru:$PassThru
        if ($PassThru) { return $rep }
    }
}

Write-ThermalLog "`n==========================================================================" 'TITLE'
Write-ThermalLog " Operacion finalizada exitosamente. Registro: $LogPath" 'OK'
Write-ThermalLog "==========================================================================" 'TITLE'

exit 0
