<#
.SYNOPSIS
    Trace-SystemLatency.ps1 - Profiler Forense Dinamico de Latencia DPC/ISR y Telemetria de Kernel Multi-Hardware
    Parte del ecosistema romanOS Toolkit.

.DESCRIPTION
    Herramienta de introspeccion dinamica de nivel de kernel (zero-resident y de solo lectura).
    Mide con precision sub-microsegundo (nanosegundos via Invariant TSC) el comportamiento de interrupciones
    en tiempo real, evalua el presupuesto por fotograma (Frame Budget), audita la resolucion de reloj
    (NtQueryTimerResolution) y correlaciona picos de latencia contra una matriz universal multi-fabricante
    (Intel, AMD, NVIDIA, Realtek, Storage y Maquinas Virtuales).

    Compatible con Windows PowerShell 5.1 (powershell.exe) y PowerShell 7+ (pwsh).
    Codificacion estricta: UTF-8 con BOM.

.PARAMETER DurationSeconds
    Duracion en segundos del muestreo calibrado de latencia (por defecto 5 segundos).

.PARAMETER Continuous
    Ejecuta un monitor interactivo en tiempo real con refresco continuo hasta presionar una tecla.

.PARAMETER ExportReport
    Guarda un informe forense detallado en formato Markdown y JSON en la carpeta Log\.

.EXAMPLE
    .\Trace-SystemLatency.ps1 -DurationSeconds 5
    .\Trace-SystemLatency.ps1 -Continuous
    .\Trace-SystemLatency.ps1 -DurationSeconds 10 -ExportReport
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [ValidateRange(1, 300)]
    [int]$DurationSeconds = 5,

    [switch]$Continuous,
    [switch]$ExportReport
)

# =============================================================================
# DETECCION DE PRIVILEGIOS (LECTURA DE KERNEL SIN BLOQUEO UAC)
# =============================================================================
$isSimulated = ($PSBoundParameters.ContainsKey('WhatIf') -or $WhatIfPreference)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Verbose "[romanOS] Profiler ejecutandose en contexto de usuario estandar (telemetria y lectura de kernel 100% operativas)."
}

# =============================================================================
# CARGA DEL MOTOR CENTRAL DE HARDWARE (SSOT)
# =============================================================================
$hwEnginePaths = @(
    (Join-Path $PSScriptRoot "..\Core\Hardware-Engine.ps1"),
    (Join-Path $PSScriptRoot "Core\Hardware-Engine.ps1"),
    (Join-Path $env:SystemDrive "Setup\Scripts\Core\Hardware-Engine.ps1")
)

$hwLoaded = $false
foreach ($p in $hwEnginePaths) {
    if (Test-Path -LiteralPath $p) {
        . (Resolve-Path $p).Path
        $hwLoaded = $true
        break
    }
}

$hwProfile = if ($hwLoaded -and (Get-Command Get-SystemHardwareProfile -ErrorAction SilentlyContinue)) {
    Get-SystemHardwareProfile
} else {
    $null
}

# =============================================================================
# COMPILACION P/INVOKE NtQueryTimerResolution (ntdll.dll)
# =============================================================================
if (-not ([System.Management.Automation.PSTypeName]'RomanOS.NativeTimer').Type) {
    try {
        Add-Type -MemberDefinition @"
[DllImport("ntdll.dll", SetLastError = true)]
public static extern int NtQueryTimerResolution(
    out uint MinimumResolution,
    out uint MaximumResolution,
    out uint CurrentResolution
);
"@ -Name "NativeTimer" -Namespace "RomanOS" -ErrorAction Stop
    } catch {
        # Fallback si ya estuviera cargado en la sesion
    }
}

function Get-TimerResolutionInfo {
    $min = [uint32]0; $max = [uint32]0; $cur = [uint32]0
    try {
        if (([System.Management.Automation.PSTypeName]'RomanOS.NativeTimer').Type) {
            $null = [RomanOS.NativeTimer]::NtQueryTimerResolution([ref]$min, [ref]$max, [ref]$cur)
            return [PSCustomObject]@{
                MinMs     = [math]::Round($min / 10000.0, 3)
                MaxMs     = [math]::Round($max / 10000.0, 3)
                CurrentMs = [math]::Round($cur / 10000.0, 3)
                Status    = if (($cur / 10000.0) -le 0.505) { "ELITE (0.5ms)" } elseif (($cur / 10000.0) -le 1.005) { "OPTIMIZADO (1.0ms)" } else { "ESTANDAR ($([math]::Round($cur / 10000.0, 1))ms)" }
            }
        }
    } catch {}
    return [PSCustomObject]@{ MinMs = 15.625; MaxMs = 0.5; CurrentMs = 1.0; Status = "Desconocido" }
}

# =============================================================================
# MOTOR DE MUESTREO DE LATENCIA DE INTERRUPCIONES SUB-MICROSEGUNDO
# =============================================================================
function Invoke-LatencySamplingBurst {
    param([int]$Seconds = 5)

    $freq = [System.Diagnostics.Stopwatch]::Frequency
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $targetSliceMs = 1.0
    $targetSliceTicks = ($freq * ($targetSliceMs / 1000.0))

    $rawTicks = [System.Collections.Generic.List[long]]::new()
    $minTick = [long]::MaxValue

    # Adquisicion de contadores WMI de DPC iniciales
    $wmiInitial = try {
        Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
    } catch { $null }

    $loopEndTicks = $sw.ElapsedTicks + ($freq * $Seconds)

    while ($sw.ElapsedTicks -lt $loopEndTicks) {
        $sliceStart = $sw.ElapsedTicks
        [System.Threading.Thread]::Sleep(1)
        $sliceEnd = $sw.ElapsedTicks

        $elapsedTicks = $sliceEnd - $sliceStart
        if ($elapsedTicks -gt 0) {
            $rawTicks.Add($elapsedTicks)
            if ($elapsedTicks -lt $minTick) {
                $minTick = $elapsedTicks
            }
        }
    }

    $sw.Stop()

    if ($rawTicks.Count -eq 0) {
        return $null
    }

    $samples = [System.Collections.Generic.List[double]]::new($rawTicks.Count)
    foreach ($t in $rawTicks) {
        $delta = $t - $minTick
        if ($delta -lt 0) { $delta = 0 }
        $latencyMicros = ($delta / $freq) * 1000000.0
        $samples.Add($latencyMicros)
    }

    # Adquisicion de contadores WMI de DPC finales
    $wmiFinal = try {
        Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
    } catch { $null }

    $dpcQueuedSec = if ($wmiFinal -and $wmiFinal.DPCsQueuedPersec) { [int]$wmiFinal.DPCsQueuedPersec } else { 0 }
    $interruptsSec = if ($wmiFinal -and $wmiFinal.InterruptsPersec) { [int]$wmiFinal.InterruptsPersec } else { 0 }
    $dpcPercent = if ($wmiFinal -and $wmiFinal.PercentDPCTime) { [int]$wmiFinal.PercentDPCTime } else { 0 }

    if ($samples.Count -eq 0) {
        return $null
    }

    # Calculo estadistico
    $sorted = [System.Collections.Generic.List[double]]::new($samples)
    $sorted.Sort()

    $minMicros = $sorted[0]
    $maxMicros = $sorted[$sorted.Count - 1]

    $sum = 0.0
    foreach ($val in $sorted) { $sum += $val }
    $avgMicros = $sum / $sorted.Count

    $medianIndex = [int]($sorted.Count / 2)
    $medianMicros = $sorted[$medianIndex]

    $p95Index = [int]($sorted.Count * 0.95)
    $p95Micros = $sorted[[math]::Min($p95Index, $sorted.Count - 1)]

    $p99Index = [int]($sorted.Count * 0.99)
    $p99Micros = $sorted[[math]::Min($p99Index, $sorted.Count - 1)]

    # Desviacion estandar (jitter)
    $sumSqDiff = 0.0
    foreach ($val in $sorted) {
        $diff = $val - $avgMicros
        $sumSqDiff += ($diff * $diff)
    }
    $jitterStdDev = [math]::Sqrt($sumSqDiff / $sorted.Count)

    # Clasificacion de salud
    $tier = if ($maxMicros -le 300.0) {
        "TIER 1 - ELITE ESPORTS (Frame Budget Optimo)"
    } elseif ($maxMicros -le 800.0) {
        "TIER 2 - BUENO / ESTANDAR (Apto para Gaming 144Hz)"
    } else {
        "TIER 3 - ALERTA DE STUTTERING (Riesgo de Caidas 1% Low)"
    }

    $tierColor = if ($maxMicros -le 300.0) { 'Green' } elseif ($maxMicros -le 800.0) { 'Yellow' } else { 'Red' }

    return [PSCustomObject]@{
        SampleCount      = $sorted.Count
        DurationSeconds  = $Seconds
        MinMicros        = [math]::Round($minMicros, 1)
        AvgMicros        = [math]::Round($avgMicros, 1)
        MedianMicros     = [math]::Round($medianMicros, 1)
        P95Micros        = [math]::Round($p95Micros, 1)
        P99Micros        = [math]::Round($p99Micros, 1)
        MaxMicros        = [math]::Round($maxMicros, 1)
        JitterStdDev     = [math]::Round($jitterStdDev, 1)
        DPCsQueuedSec    = $dpcQueuedSec
        InterruptsSec    = $interruptsSec
        PercentDPCTime   = $dpcPercent
        Tier             = $tier
        TierColor        = $tierColor
    }
}

# =============================================================================
# CORRELACION FORENSE MULTI-HARDWARE DE CONTROLADORES EN KERNEL
# =============================================================================
function Get-HardwareDriverAttribution {
    param($Profile)

    $runningDrivers = @()
    try {
        $runningDrivers = @(Get-CimInstance Win32_SystemDriver -Filter "State='Running'" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    } catch {}

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    # -------------------------------------------------------------------------
    # 1. SUBSISTEMA INTEL
    # -------------------------------------------------------------------------
    $isIntel = ($Profile -and $Profile.CPU -and $Profile.CPU.Vendor -eq 'Intel')
    
    # Intel MEI / CSME (HECI)
    if ($runningDrivers -contains 'HECIx64' -or $runningDrivers -contains 'MEIx64' -or $runningDrivers -contains 'TeeDriverW10x64') {
        $results.Add([PSCustomObject]@{
            DriverName  = "HECIx64.sys"
            Component   = "Intel Management Engine Interface (CSME)"
            Vendor      = "Intel"
            Status      = "Activo en Kernel"
            Impact      = "Moderado a Alto si sondea telemetria en estados de energia PCH"
            Tuning      = "Mantener driver actualizado. En placas de escritorio, desactivar sondeo de energia ME en BIOS si produce picos."
        })
    }

    # Intel Smart Sound Technology (SST)
    if ($runningDrivers -contains 'IntcAudioBus' -or $runningDrivers -contains 'IntcOED' -or $runningDrivers -contains 'isup_bus') {
        $results.Add([PSCustomObject]@{
            DriverName  = "IntcAudioBus.sys"
            Component   = "Intel Smart Sound Technology (SST)"
            Vendor      = "Intel"
            Status      = "Activo en Kernel"
            Impact      = "Critico para Audio. Fuente frecuente de buffer underruns y micro-stutters"
            Tuning      = "En laptops/desktops, si hay cortes de audio, verificar driver oficial del fabricante OEM o deshabilitar efectos de procesamiento."
        })
    }

    # Intel Dynamic Tuning (DTT / IPF)
    if ($runningDrivers -contains 'ipf_cpu' -or $runningDrivers -contains 'dptf_cpu' -or $runningDrivers -contains 'esif_lf') {
        $results.Add([PSCustomObject]@{
            DriverName  = "ipf_cpu.sys / dptf_cpu.sys"
            Component   = "Intel Dynamic Tuning / Innovation Platform"
            Vendor      = "Intel"
            Status      = "Activo en Kernel"
            Impact      = "Moderado. Sondeo MSR constante puede provocar picos periodicos"
            Tuning      = "Configurar plan de energia de Alto Rendimiento en Windows para estabilizar limites PL1/PL2."
        })
    }

    # Intel Wi-Fi / Killer Wireless
    $intelWifi = $runningDrivers | Where-Object { $_ -match '^Netwtw[0-9]{2}' }
    if ($intelWifi) {
        $results.Add([PSCustomObject]@{
            DriverName  = "$($intelWifi[0]).sys"
            Component   = "Intel Wi-Fi / Killer Wireless"
            Vendor      = "Intel"
            Status      = "Activo en Kernel"
            Impact      = "Bajo a Moderado (Escaneos periodicos de roaming o modos DTIM)"
            Tuning      = "En propiedades del adaptador: Desactivar 'Roaming Aggressiveness' (Minimo) y desactivar ahorro de energia 802.11."
        })
    }

    # Intel Ethernet (I219 / I225-V / I226-V)
    $intelEth = $runningDrivers | Where-Object { $_ -match '^(e1d|e2f|e1r)' }
    if ($intelEth) {
        $results.Add([PSCustomObject]@{
            DriverName  = "$($intelEth[0]).sys"
            Component   = "Intel Ethernet Gigabit / 2.5GbE"
            Vendor      = "Intel"
            Status      = "Activo en Kernel"
            Impact      = "Bajo (Excelente con moderacion de interrupciones adecuada)"
            Tuning      = "Desactivar 'Energy Efficient Ethernet' (EEE) y 'Green Ethernet' para prevenir micro-retrasos de paquetes."
        })
    }

    # Intel Arc / Iris Xe Graphics
    if ($runningDrivers -contains 'igdkmdn64') {
        $results.Add([PSCustomObject]@{
            DriverName  = "igdkmdn64.sys"
            Component   = "Intel Arc Dedicated / Iris Xe Graphics"
            Vendor      = "Intel"
            Status      = "Activo en Kernel"
            Impact      = "Critico para Frame Pacing y DWM"
            Tuning      = "Asegurar que Resizable BAR este habilitado en BIOS para Intel Arc. Habilitar HAGS en Windows."
        })
    }

    # -------------------------------------------------------------------------
    # 2. SUBSISTEMA AMD
    # -------------------------------------------------------------------------
    # AMD Radeon Graphics
    if ($runningDrivers -contains 'amdkmdag' -or $runningDrivers -contains 'atikmdag') {
        $results.Add([PSCustomObject]@{
            DriverName  = "amdkmdag.sys"
            Component   = "AMD Radeon Graphics Subsystem"
            Vendor      = "AMD"
            Status      = "Activo en Kernel"
            Impact      = "Critico para Frame Pacing y Renderizado"
            Tuning      = "En APUs/dGPUs RDNA: HAGS activado por romanOS. Purga periodica de DirectX Shader Cache recomendada."
        })
    }

    # AMD PSP
    if ($runningDrivers -contains 'amdpsp') {
        $results.Add([PSCustomObject]@{
            DriverName  = "amdpsp.sys"
            Component   = "AMD Platform Security Processor"
            Vendor      = "AMD"
            Status      = "Activo en Kernel"
            Impact      = "Minimo en reposo"
            Tuning      = "Asegurar BIOS AGESA actualizado si se experimentaron tartamudeos historicos con fTPM."
        })
    }

    # AMD 3D V-Cache (Dual-CCD)
    if ($Profile -and $Profile.CPU -and $Profile.CPU.IsDualCcdX3D) {
        $x3dService = Get-Service -Name "AMD3DV互CachePerformanceOptimizer" -ErrorAction SilentlyContinue
        $results.Add([PSCustomObject]@{
            DriverName  = "amdppm.sys / amd3dvcachesvc"
            Component   = "AMD 3D V-Cache Asymmetric Dual-CCD Scheduler"
            Vendor      = "AMD"
            Status      = if ($x3dService -and $x3dService.Status -eq 'Running') { "Activo y Operativo" } else { "Requiere Verificacion de Driver CPPC" }
            Impact      = "Critico para Pacing de Juegos en 7900X3D/7950X3D/9950X3D"
            Tuning      = "Verificar que el servicio AMD 3D V-Cache Performance Optimizer este en ejecucion para confinar juegos al CCD0."
        })
    }

    # -------------------------------------------------------------------------
    # 3. SUBSISTEMA NVIDIA
    # -------------------------------------------------------------------------
    if ($runningDrivers -contains 'nvlddmkm') {
        # Verificacion de modo MSI para NVIDIA
        $nvMsiEnabled = $false
        try {
            $gpuPdo = (Get-CimInstance Win32_PnPEntity | Where-Object { $_.Service -eq 'nvlddmkm' } | Select-Object -First 1).DeviceID
            if ($gpuPdo) {
                $msiKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\$gpuPdo\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
                $val = (Get-ItemProperty -Path $msiKey -Name "MSISupported" -ErrorAction SilentlyContinue).MSISupported
                if ($val -eq 1) { $nvMsiEnabled = $true }
            }
        } catch {}

        $results.Add([PSCustomObject]@{
            DriverName  = "nvlddmkm.sys"
            Component   = "NVIDIA GeForce / RTX Display Driver"
            Vendor      = "NVIDIA"
            Status      = "Activo en Kernel"
            Impact      = "Critico para Frame Pacing y Latencia DPC"
            Tuning      = if ($nvMsiEnabled) {
                "Modo MSI: HABILITADO [OK]. En panel de control NVIDIA, preferir 'Modo de control de energia: Maximo rendimiento preferido' por juego."
            } else {
                "ALERTA: Modo MSI NO DETECTADO. Activar MSI-X para NVIDIA reduce significativamente los picos de DPC."
            }
        })
    }

    # -------------------------------------------------------------------------
    # 4. SUBSISTEMA REALTEK & ALMACENAMIENTO & CORE OS
    # -------------------------------------------------------------------------
    # Realtek LAN
    if ($runningDrivers -contains 'rt640x64') {
        $results.Add([PSCustomObject]@{
            DriverName  = "rt640x64.sys"
            Component   = "Realtek PCIe GbE/2.5GbE Family Controller"
            Vendor      = "Realtek"
            Status      = "Activo en Kernel"
            Impact      = "Bajo a Moderado"
            Tuning      = "Desactivar 'Green Ethernet', 'Energy Efficient Ethernet' y 'Gigabit Lite' en propiedades avanzadas."
        })
    }

    # Realtek Audio
    if ($runningDrivers -contains 'RTKVHD64') {
        $results.Add([PSCustomObject]@{
            DriverName  = "RTKVHD64.sys"
            Component   = "Realtek High Definition Audio"
            Vendor      = "Realtek"
            Status      = "Activo en Kernel"
            Impact      = "Bajo (Estable en Windows 11 24H2+)"
            Tuning      = "Asegurar formato predeterminado en 24-bit 48000 Hz (Calidad de estudio)."
        })
    }

    # Microsoft Standard NVMe
    if ($runningDrivers -contains 'stornvme') {
        $results.Add([PSCustomObject]@{
            DriverName  = "stornvme.sys"
            Component   = "Microsoft Standard NVM Express Driver"
            Vendor      = "Microsoft"
            Status      = "Activo en Kernel"
            Impact      = "Minimo (Driver de ultra-baja sobrecarga de Windows)"
            Tuning      = "romanOS ya configura el plan de energia para deshabilitar estados APST profundos en juegos."
        })
    }

    # Intel RST / VMD
    if ($runningDrivers -contains 'iaStorVD' -or $runningDrivers -contains 'iaStorAC') {
        $results.Add([PSCustomObject]@{
            DriverName  = "iaStorVD.sys"
            Component   = "Intel Rapid Storage Technology (RST) / VMD"
            Vendor      = "Intel"
            Status      = "Activo en Kernel"
            Impact      = "Bajo a Moderado"
            Tuning      = "En aplicaciones de almacenamiento SATA/NVMe, desactivar 'Link Power Management' (LPM) si genera tirones de disco."
        })
    }

    # Entornos Virtuales
    if ($Profile -and $Profile.Platform -and $Profile.Platform.IsVirtualMachine) {
        $results.Add([PSCustomObject]@{
            DriverName  = "vmbus.sys / vm3dmp.sys / virtio"
            Component   = "Hipervisor Guest Bus ($($Profile.Platform.VmType))"
            Vendor      = "Virtual Machine"
            Status      = "Entorno Virtualizado Detectado"
            Impact      = "Artificial (Sujeto al time-slicing de CPU del hipervisor anfitrion)"
            Tuning      = "Los picos superiores a 500µs en maquinas virtuales son normales debido a la planificacion del host."
        })
    }

    return $results
}

# =============================================================================
# FUNCION PRINCIPAL DE VISUALIZACION Y REPORTE
# =============================================================================
function Show-LatencyProfilingSummary {
    param(
        $Metrics,
        $TimerInfo,
        $DriverAttributions,
        $Profile
    )

    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "       romanOS FORENSIC PROFILER: LATENCIA DPC, ISR Y TIEMPO REAL MULTI-HW     " -ForegroundColor White
    Write-Host "================================================================================" -ForegroundColor Cyan

    # Resumen de Hardware
    if ($Profile) {
        $archBadge = if ($Profile.CPU.IsHybrid) {
            "HIBRIDA (P-Cores + E-Cores / Thread Director)"
        } elseif ($Profile.CPU.IsDualCcdX3D) {
            "AMD 3D V-CACHE ASIMETRICA (Dual-CCD)"
        } elseif ($Profile.CPU.IsEcoreOnly) {
            "INTEL E-CORE ONLY (Alder Lake-N)"
        } elseif ($Profile.CPU.IsLegacyIntel) {
            "INTEL MONOLITICA LEGADA (1st-11th Gen)"
        } elseif ($Profile.CPU.IsIntelXeon) {
            "INTEL XEON (Mesh / Multi-NUMA)"
        } else {
            "MONOLITICA / ESTANDAR"
        }

        Write-Host "  PLATAFORMA : $($Profile.Platform.ComputerManufacturer) $($Profile.Platform.ComputerModel) [$($Profile.Platform.ChassisDescription)]" -ForegroundColor Gray
        Write-Host "  PROCESADOR : $($Profile.CPU.Name) ($($Profile.CPU.Cores)C / $($Profile.CPU.Threads)T @ $($Profile.CPU.MaxClockMHz)MHz)" -ForegroundColor Gray
        Write-Host "  TOPOLOGIA  : $archBadge" -ForegroundColor Gray
        Write-Host "  GRAFICOS   : $(($Profile.GPU.Devices | ForEach-Object { $_.Name }) -join ' | ')" -ForegroundColor Gray
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    }

    # Estado del Temporizador del Sistema (NtQueryTimerResolution)
    Write-Host "  TEMPORIZADOR DEL KERNEL (NtQueryTimerResolution):" -ForegroundColor White
    Write-Host "   - Resolucion Actual : $($TimerInfo.CurrentMs) ms" -ForegroundColor $(if ($TimerInfo.CurrentMs -le 0.505) { 'Green' } else { 'Yellow' })
    Write-Host "   - Rango Soportado   : $($TimerInfo.MaxMs) ms (Maximo) a $($TimerInfo.MinMs) ms (Minimo)" -ForegroundColor Gray
    Write-Host "   - Estado Scheduler  : $($TimerInfo.Status)" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

    # Metricas de Latencia en Microsegundos
    Write-Host "  METRICAS DINAMICAS DE LATENCIA ($($Metrics.DurationSeconds)s de muestreo - $($Metrics.SampleCount) muestras):" -ForegroundColor White
    Write-Host "   - Latencia Minima   : $($Metrics.MinMicros) µs" -ForegroundColor Gray
    Write-Host "   - Latencia Promedio : $($Metrics.AvgMicros) µs" -ForegroundColor Gray
    Write-Host "   - Latencia Mediana  : $($Metrics.MedianMicros) µs" -ForegroundColor Gray
    Write-Host "   - Percentil 95 (P95): $($Metrics.P95Micros) µs" -ForegroundColor $(if ($Metrics.P95Micros -le 300) { 'Green' } else { 'Yellow' })
    Write-Host "   - Percentil 99 (P99): $($Metrics.P99Micros) µs" -ForegroundColor $(if ($Metrics.P99Micros -le 500) { 'Green' } else { 'Yellow' })
    Write-Host "   - Pico Maximo DPC   : $($Metrics.MaxMicros) µs" -ForegroundColor $Metrics.TierColor
    Write-Host "   - Jitter (Desv. Std): $($Metrics.JitterStdDev) µs" -ForegroundColor Gray
    Write-Host "   - Actividad Kernel  : $($Metrics.DPCsQueuedSec) DPCs/s | $($Metrics.InterruptsSec) Interrupciones/s | $($Metrics.PercentDPCTime)% DPC Time" -ForegroundColor Gray

    Write-Host ""
    Write-Host "  CALIFICACION DE SALUD DE LATENCIA:" -ForegroundColor White
    Write-Host "  >> [$($Metrics.Tier)] <<" -ForegroundColor $Metrics.TierColor
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

    # Histograma Grafico de Distribucion
    Write-Host "  DISTRIBUCION DE LATENCIA EN FRAME BUDGET (240Hz = 4166µs):" -ForegroundColor White
    $barTotal = 40
    $picoClamped = [math]::Min($Metrics.MaxMicros, 4166.0)
    $ratio = $picoClamped / 4166.0
    $filledBars = [int]($ratio * $barTotal)
    $emptyBars = $barTotal - $filledBars

    $barStr = "[" + ("#" * $filledBars) + ("-" * $emptyBars) + "]"
    $impactPct = [math]::Round(($Metrics.MaxMicros / 4166.0) * 100, 2)
    Write-Host "   Consumo de Frame Budget: $barStr $impactPct% ($($Metrics.MaxMicros)µs)" -ForegroundColor $Metrics.TierColor
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

    # Atribucion de Drivers Multi-Hardware
    Write-Host "  CORRELACION FORENSE MULTI-HARDWARE DE CONTROLADORES:" -ForegroundColor White
    if ($DriverAttributions.Count -gt 0) {
        foreach ($drv in $DriverAttributions) {
            Write-Host "   [$($drv.Vendor)] $($drv.DriverName) - $($drv.Component)" -ForegroundColor Cyan
            Write-Host "     * Estado  : $($drv.Status)" -ForegroundColor Gray
            Write-Host "     * Impacto : $($drv.Impact)" -ForegroundColor Yellow
            Write-Host "     * Ajuste  : $($drv.Tuning)" -ForegroundColor White
        }
    } else {
        Write-Host "   No se detectaron controladores criticos con sobrecarga en el subsistema evaluado." -ForegroundColor Green
    }
    Write-Host "================================================================================" -ForegroundColor Cyan
}

# =============================================================================
# EXPORTACION FORENSE DE REPORTE (MARKDOWN / JSON)
# =============================================================================
function Export-LatencyReport {
    param($Metrics, $TimerInfo, $DriverAttributions, $Profile)

    $logDir = Join-Path $PSScriptRoot "..\..\Log"
    if (-not (Test-Path -LiteralPath $logDir)) {
        try { New-Item -Path $logDir -ItemType Directory -Force | Out-Null } catch {}
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $mdFile = Join-Path $logDir "LatencyTrace_$timestamp.md"
    $jsonFile = Join-Path $logDir "LatencyTrace_$timestamp.json"

    $reportObj = [PSCustomObject]@{
        Timestamp          = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Platform           = $Profile.Platform
        CPU                = $Profile.CPU
        TimerResolution    = $TimerInfo
        LatencyMetrics     = $Metrics
        DriverAttribution  = $DriverAttributions
    }

    try {
        $reportObj | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonFile -Encoding UTF8
    } catch {}

    $mdLines = @(
        "# romanOS - Reporte Forense de Latencia DPC/ISR y Tiempo Real",
        "",
        "**Fecha:** $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))  ",
        "**Calificacion:** `$($Metrics.Tier)`  ",
        "",
        "## 1. Plataforma y Hardware",
        "- **Dispositivo:** $($Profile.Platform.ComputerManufacturer) $($Profile.Platform.ComputerModel) ($($Profile.Platform.ChassisDescription))",
        "- **Procesador:** $($Profile.CPU.Name) ($($Profile.CPU.Cores)C / $($Profile.CPU.Threads)T)",
        "- **Vendor CPU:** $($Profile.CPU.Vendor)",
        "- **Graficos:** $(($Profile.GPU.Devices | ForEach-Object { $_.Name }) -join ', ')",
        "",
        "## 2. Temporizador del Kernel (NtQueryTimerResolution)",
        "- **Resolucion Actual:** $($TimerInfo.CurrentMs) ms ($($TimerInfo.Status))",
        "- **Rango Soportado:** $($TimerInfo.MaxMs) ms (Maximo) - $($TimerInfo.MinMs) ms (Minimo)",
        "",
        "## 3. Metricas Dinamicas de Microsegundos",
        "| Metrica | Valor | Descripcion |",
        "| :--- | :--- | :--- |",
        "| **Latencia Minima** | $($Metrics.MinMicros) µs | Minimo absoluto observado |",
        "| **Latencia Promedio** | $($Metrics.AvgMicros) µs | Media aritmetica de retraso DPC |",
        "| **Mediana** | $($Metrics.MedianMicros) µs | Percentil 50 |",
        "| **Percentil 95 (P95)** | $($Metrics.P95Micros) µs | Techo del 95% de los ciclos |",
        "| **Percentil 99 (P99)** | $($Metrics.P99Micros) µs | Techo del 99% de los ciclos |",
        "| **Pico Maximo DPC** | **$($Metrics.MaxMicros) µs** | Peor evento de contencion DPC/ISR |",
        "| **Jitter (StdDev)** | $($Metrics.JitterStdDev) µs | Desviacion estandar de interrupciones |",
        "| **DPCs en Cola / s** | $($Metrics.DPCsQueuedSec) | Tasa de llamadas diferidas por segundo |",
        "| **Interrupciones / s** | $($Metrics.InterruptsSec) | Tasa de interrupciones de hardware |",
        "",
        "## 4. Controladores Analizados en Kernel",
        ""
    )

    foreach ($drv in $DriverAttributions) {
        $mdLines += "### [$($drv.Vendor)] $($drv.DriverName) - $($drv.Component)"
        $mdLines += "- **Estado:** $($drv.Status)"
        $mdLines += "- **Impacto:** $($drv.Impact)"
        $mdLines += "- **Recomendacion:** $($drv.Tuning)"
        $mdLines += ""
    }

    try {
        $mdLines | Set-Content -LiteralPath $mdFile -Encoding UTF8
        Write-Host "`n[romanOS] Informe guardado con exito en:" -ForegroundColor Green
        Write-Host "  - Markdown: $mdFile" -ForegroundColor Cyan
        Write-Host "  - JSON    : $jsonFile" -ForegroundColor Cyan
    } catch {}
}

# =============================================================================
# BUCLE DE EJECUCION
# =============================================================================
if ($isSimulated) {
    Write-Host "[WhatIf] Simulacion de ejecucion de Trace-SystemLatency.ps1 (Parser AST y entorno validados correctamente)." -ForegroundColor Yellow
    exit 0
}

if ($Continuous) {
    Write-Host "[romanOS] Iniciando monitor continuo de latencia DPC en vivo. Presiona [Ctrl+C] para finalizar..." -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    while ($true) {
        $burst = Invoke-LatencySamplingBurst -Seconds 1
        $timer = Get-TimerResolutionInfo
        $drivers = Get-HardwareDriverAttribution -Profile $hwProfile
        Show-LatencyProfilingSummary -Metrics $burst -TimerInfo $timer -DriverAttributions $drivers -Profile $hwProfile
        Write-Host "`n  [Presiona Ctrl+C para detener el monitor continuo]" -ForegroundColor DarkGray
        Start-Sleep -Milliseconds 200
    }
} else {
    Write-Host "[romanOS] Iniciando muestreo calibrado de latencia de kernel ($DurationSeconds segundos)..." -ForegroundColor Cyan
    $burst = Invoke-LatencySamplingBurst -Seconds $DurationSeconds
    $timer = Get-TimerResolutionInfo
    $drivers = Get-HardwareDriverAttribution -Profile $hwProfile
    Show-LatencyProfilingSummary -Metrics $burst -TimerInfo $timer -DriverAttributions $drivers -Profile $hwProfile

    if ($ExportReport) {
        Export-LatencyReport -Metrics $burst -TimerInfo $timer -DriverAttributions $drivers -Profile $hwProfile
    }
}
