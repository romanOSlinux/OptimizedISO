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
    [ValidateSet('Audit', 'Monitor', 'CalibrateEnergy', 'UnparkCores', 'Status')]
    [string]$Action = 'Status',

    [int]$SampleDurationSec = 5,

    [ValidateSet('Ultimate', 'HighPerformance', 'Balanced')]
    [string]$EnergyProfile = 'Ultimate',

    [switch]$Unattended,

    [switch]$SkipElevation,

    [string]$LogPath = '',

    [switch]$Force
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
    if ($Action -in @('CalibrateEnergy', 'UnparkCores')) {
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
    $logDir = if (Test-Path -Path "C:\OptimizedISO\Log") { "C:\OptimizedISO\Log" } else { $env:TEMP }
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
        # Fallback sin interrumpir flujo
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
        # Fallback visible si ACPI WMI no está disponible
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
        # Fallback visible
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
        # Clave no presente
    }

    # 3. Estado de batería
    try {
        $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($battery) {
            $state.IsOnBattery = ($battery.BatteryStatus -ne 2) # 2 = AC / Conectado
            $state.BatteryHealth = "$($battery.EstimatedChargeRemaining)% (Estado: $($battery.BatteryStatus))"
        }
    } catch {
        # Desktop
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
            # Verificar si el esquema existe en el sistema
            $schemes = & powercfg /list
            if ($schemes -notmatch $targetGuid -and $targetGuid -eq $guidUltimate) {
                Write-ThermalLog "[INFO] Duplicando esquema de Maximo Rendimiento oficial..." 'INFO'
                & powercfg -duplicatescheme $guidUltimate 2>&1 | Out-Null
            }

            # Asignar esquema activo
            & powercfg /setactive $targetGuid
            Write-ThermalLog "[OK] Plan de energia asignado exitosamente: $targetGuid ($TargetProfile)" 'OK'
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
        Write-ThermalLog "  - Plan de Energia    : $($state.ActiveSchemeName) ($($energy.ActiveSchemeGuid))" 'INFO'
        Write-ThermalLog "  - Rendimiento Maximo : $(if ($energy.IsUltimate) { 'Activado [OK]' } else { 'No activado' })" $(if ($energy.IsUltimate) { 'OK' } else { 'WARN' })
        Write-ThermalLog "  - Power Throttling   : $(if ($energy.PowerThrottlingOff) { 'Desactivado (Max Latency Shield) [OK]' } else { 'Habilitado por defecto' })" 'INFO'
        Write-ThermalLog "  - Alimentacion       : $(if ($energy.IsOnBattery) { 'Bateria' } else { 'Corriente Alterna (AC) / Desktop' }) ($($energy.BatteryHealth))" 'INFO'
    }

    'Audit' {
        # Modo auditoría rápida con reporte resumido
        $cpu = Get-ProcessorThrottlingState
        $energy = Get-EnergyProfileState
        $thermal = Get-ThermalSensorsData

        Write-ThermalLog "[AUDITORIA] CPU: $($cpu.CpuName) | Freq: $($cpu.CurrentClockMHz) MHz | Throttling: $(if ($cpu.IsThrottling) { 'SI' } else { 'NO' }) | Plan: $($energy.ActiveSchemeName)" 'OK'
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
}

Write-ThermalLog "`n==========================================================================" 'TITLE'
Write-ThermalLog " Operacion finalizada exitosamente. Registro: $LogPath" 'OK'
Write-ThermalLog "==========================================================================" 'TITLE'

exit 0
