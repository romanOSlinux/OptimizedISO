<#
    Win11-Network-Diagnostics-Optimizer.ps1
    Herramienta avanzada de Diagnostico, Pruebas y Optimizacion de Conectividad en Windows 11 (25H2 Ready).
    Ejecutar elevado (Admin). Guarda logs en C:\Logs\Network-Diagnostics.log
#>

param(
    [switch]$Unattended
)

# Precarga de ensamblados WPF para soporte garantizado de interfaz grafica (Out-GridView)
try {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction SilentlyContinue
} catch {}

# ============================================================
# Comprobar privilegios de Administrador y auto-elevar
# ============================================================
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue } catch {}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Este script requiere privilegios de Administrador. Reiniciando de forma elevada..."
    $ps51 = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $myScript = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
    $argList = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $myScript)
    if ($Unattended) { $argList += '-Unattended' }
    Start-Process -FilePath $ps51 -ArgumentList $argList -Verb RunAs
    Exit
}

$ErrorActionPreference = 'Continue'

# ============================================================
# CARGA DE MOTOR VISUAL UNIFICADO O MICRO-FALLBACK STANDALONE
# ============================================================
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

# ============================================================
# LOGGING ENGINE — Write-Log + Start-Transcript
# Genera dos archivos con timestamp en C:\Logs\
#   Network-Diagnostics_<ts>.log            ← log estructurado
#   Network-Diagnostics_<ts>_transcript.log ← transcripción completa
# ============================================================
$logDir = "C:\Logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

$_logTs                = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:LogFile        = "$logDir\Network-Diagnostics_$_logTs.log"
$script:TranscriptFile = "$logDir\Network-Diagnostics_${_logTs}_transcript.log"
$script:AiSummaryFile  = "$logDir\Network-Diagnostics_${_logTs}_AI_SUMMARY.md"
$script:DiagStart      = Get-Date
$log                   = $script:LogFile

$script:LogErrors  = [System.Collections.Generic.List[string]]::new()
$script:LogWarns   = [System.Collections.Generic.List[string]]::new()

function Write-LogEntry {
    [CmdletBinding()]
    param(
        [ValidateSet("INIT","STEP","INFO","OK","WARN","ERROR","DEBUG")]
        [string]$Level = "INFO",
        [string]$Message
    )
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$($Level.PadRight(5))] $Message"
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    if ($Level -eq "ERROR") { $script:LogErrors.Add($line) }
    if ($Level -eq "WARN")  { $script:LogWarns.Add($line) }
}

function Write-LogSummary {
    $totalDuration = [math]::Round(((Get-Date) - $script:DiagStart).TotalSeconds, 1)

    Write-LogEntry -Level "INIT" -Message ("=" * 64)
    Write-LogEntry -Level "INIT" -Message "RESUMEN FINAL"
    Write-LogEntry -Level "INFO" -Message "Duración total       : ${totalDuration}s"
    Write-LogEntry -Level "INFO" -Message "Errores registrados : $($script:LogErrors.Count)"
    Write-LogEntry -Level "INFO" -Message "Advertencias        : $($script:LogWarns.Count)"
    if ($script:LogErrors.Count -gt 0) {
        Write-LogEntry -Level "ERROR" -Message "--- ERRORES DETECTADOS ---"
        foreach ($e in $script:LogErrors) { Write-LogEntry -Level "ERROR" -Message $e }
    }
    if ($script:LogWarns.Count -gt 0) {
        Write-LogEntry -Level "WARN" -Message "--- ADVERTENCIAS ---"
        foreach ($w in $script:LogWarns) { Write-LogEntry -Level "WARN" -Message $w }
    }
    if ($script:LogErrors.Count -eq 0) {
        Write-LogEntry -Level "OK" -Message "Diagnóstico de red completado sin errores."
    }
    Write-LogEntry -Level "INIT" -Message "Log estructurado    : $script:LogFile"
    Write-LogEntry -Level "INIT" -Message "AI Summary (MD)     : $script:AiSummaryFile"
    Write-LogEntry -Level "INIT" -Message "Transcript          : $script:TranscriptFile"
    Write-LogEntry -Level "INIT" -Message ("=" * 64)

    # Detener transcript
    try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch {}

    # Generar Reporte Markdown optimizado para IA
    try {
        $overallStatus = if ($script:LogErrors.Count -eq 0) { "SUCCESS" } else { "FAILED" }
        $statusBadge   = if ($overallStatus -eq "SUCCESS") { "SUCCESS ✅" } else { "FAILED ❌" }

        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("# AI Diagnostic Report: Win11-Network-Diagnostics-Optimizer")
        [void]$sb.AppendLine("- **Status:** $statusBadge")
        [void]$sb.AppendLine("- **Timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        [void]$sb.AppendLine("- **Total Duration:** ${totalDuration}s")
        [void]$sb.AppendLine("- **Host:** $env:COMPUTERNAME | **User:** $env:USERNAME | **PowerShell:** $($PSVersionTable.PSVersion)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Network Tweaks Summary")
        [void]$sb.AppendLine("| ID | Tweak Name | Category | Status | Details |")
        [void]$sb.AppendLine("|---|---|---|---|---|")

        if ($executionSummary -and $executionSummary.Count -gt 0) {
            foreach ($rec in $executionSummary) {
                $stIcon = switch ($rec.Result) {
                    "OK"      { "OK ✅" }
                    "APPLIED" { "APPLIED ✅" }
                    "WARN"    { "WARN ⚠️" }
                    "ERROR"   { "ERROR ❌" }
                    "SKIPPED" { "SKIPPED ⚪" }
                    default   { "$($rec.Result)" }
                }
                [void]$sb.AppendLine("| $($rec.Id) | $($rec.Name) | $($rec.Category) | $stIcon | $($rec.Details) |")
            }
        }

        if ($script:LogErrors.Count -gt 0) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("## ❌ Errors Detected")
            [void]$sb.AppendLine('```text')
            foreach ($err in $script:LogErrors) { [void]$sb.AppendLine($err) }
            [void]$sb.AppendLine('```')
        }

        if ($script:LogWarns.Count -gt 0) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("## ⚠️ Warnings Logged")
            [void]$sb.AppendLine('```text')
            foreach ($warn in $script:LogWarns) { [void]$sb.AppendLine($warn) }
            [void]$sb.AppendLine('```')
        }

        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Generated Artifacts")
        [void]$sb.AppendLine("- **Structured Log:** ``$script:LogFile``")
        [void]$sb.AppendLine("- **Raw Transcript:** ``$script:TranscriptFile``")
        [void]$sb.AppendLine("- **AI Diagnostic:** ``$script:AiSummaryFile``")

        if ($script:AiSummaryFile) {
            [System.IO.File]::WriteAllText($script:AiSummaryFile, $sb.ToString(), [System.Text.Encoding]::UTF8)
        }
    } catch {
        Write-LogEntry -Level "WARN" -Message "No se pudo generar el reporte AI Summary: $($_.Exception.Message)"
    }
    $logMap = @{}
    if ($script:AiSummaryFile)  { $logMap["AI Diagnostic MD"] = $script:AiSummaryFile }
    if ($script:LogFile)        { $logMap["Log Estructurado"] = $script:LogFile }
    if ($script:TranscriptFile) { $logMap["Transcript"]       = $script:TranscriptFile }

    $st = if ($script:LogErrors.Count -eq 0) { "SUCCESS" } else { "FAILED" }
    Show-UnifiedSummary -Title "DIAGNOSTICO DE RED" -Status $st -DurationSeconds $totalDuration -ErrorsCount $script:LogErrors.Count -WarnsCount $script:LogWarns.Count -Logs $logMap
}

try {
    Start-Transcript -Path $script:TranscriptFile -Append -ErrorAction Stop | Out-Null
} catch {
    Write-Info "Start-Transcript no disponible: $($_.Exception.Message)"
}

Write-LogEntry -Level "INIT" -Message ("=" * 64)
Write-LogEntry -Level "INIT" -Message "Win11-Network-Diagnostics-Optimizer Log"
Write-LogEntry -Level "INIT" -Message "PowerShell $($PSVersionTable.PSVersion) | Host: $env:COMPUTERNAME | User: $env:USERNAME"
Write-LogEntry -Level "INIT" -Message ("=" * 64)

# Lista global para el reporte final
$executionSummary = [System.Collections.Generic.List[PSCustomObject]]::new()

function Add-SummaryRecord {
    param([string]$TweakId, [string]$Name, [string]$Category, [string]$Result, [string]$Details)
    $executionSummary.Add([PSCustomObject]@{
        Id        = $TweakId
        Name      = $Name
        Category  = $Category
        Result    = $Result
        Details   = $Details
    })
}

try {
    Show-UnifiedBanner -Title "DIAGNOSTICO, PRUEBAS Y OPTIMIZACION DE RED" -Subtitle "Inspeccion de Adaptadores, Latencia, DNS y Tweaks TCP/IP (Win 11 25H2)" -ShowSystemInfo

    # ================================================================
    # FASE 1: DIAGNOSTICO COMPLETO DE ADAPTADORES (LECTURA)
    # ================================================================
    Write-StepHeader -StepNumber 1 -TotalSteps 4 -Message "Diagnostico e inspeccion de adaptadores de red"
    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue

    if (-not $adapters) {
        Write-Host "  ! No se encontraron adaptadores de red fisicos." -ForegroundColor Red
    } else {
        foreach ($a in $adapters) {
            $statusColor = if ($a.Status -eq 'Up') { 'Green' } else { 'Yellow' }
            Write-Host "  * Adapter: $($a.Name)" -ForegroundColor Cyan
            Write-Host "    - Tipo: $($a.InterfaceDescription)" -ForegroundColor Gray
            Write-Host "    - Estado: $($a.Status)" -ForegroundColor $statusColor
            Write-Host "    - Velocidad actual / Enlace: $($a.LinkSpeed)" -ForegroundColor Green
            Write-Host "    - Direccion MAC: $($a.MacAddress)" -ForegroundColor Gray
            
            # Comprobar si hay paquetes descartados o errores
            $stats = Get-NetAdapterStatistics -Name $a.Name -ErrorAction SilentlyContinue
            if ($stats) {
                if ($stats.ReceivedDiscardedPackets -gt 0 -or $stats.ReceivedParameterErrors -gt 0) {
                    Write-Host "    ! Paquetes Recibidos Descartados: $($stats.ReceivedDiscardedPackets)" -ForegroundColor Yellow
                    Write-Host "    ! Errores de Parametros en Recepcion: $($stats.ReceivedParameterErrors)" -ForegroundColor Yellow
                } else {
                    Write-Host "    - Estadisticas: Sin paquetes descartados ni errores en buffers." -ForegroundColor Green
                }
            }
        }
    }

    # Configuracion de IP y DNS
    Write-StepHeader -StepNumber 2 -TotalSteps 4 -Message "Analizando configuracion logica de red (IP/DNS)"
    $ipConfigs = Get-NetIPConfiguration -ErrorAction SilentlyContinue
    foreach ($cfg in $ipConfigs) {
        if ($cfg.NetProfile.IPv4Connectivity -eq 'Internet' -or $cfg.IPv4DefaultGateway) {
            Write-Host "  * Interfaz Activa: $($cfg.InterfaceAlias)" -ForegroundColor Cyan
            Write-Host "    - IP Address: $($cfg.IPv4Address.IPAddress)" -ForegroundColor Gray
            Write-Host "    - Puerta de Enlace: $($cfg.IPv4DefaultGateway.NextHop)" -ForegroundColor Gray
            $dnsServers = if ($cfg.DNSServer) {
                $cfg.DNSServer | ForEach-Object { 
                    if ($_.ServerAddress) { $_.ServerAddress } else { $_.ToString() } 
                }
            } else { @() }
            Write-Host "    - Servidores DNS: $($dnsServers -join ', ')" -ForegroundColor Gray
        }
    }

    # ================================================================
    # FASE 2: PRUEBAS ACTIVAS DE CONECTIVIDAD (TESTS)
    # ================================================================
    Write-StepHeader -StepNumber 3 -TotalSteps 4 -Message "Realizando pruebas activas de latencia y DNS"
    
    # 1. Test contra Cloudflare DNS
    Write-SubStep "Probando conexion hacia Cloudflare DNS (1.1.1.1)..."
    $t1 = Test-NetConnection -ComputerName 1.1.1.1 -ErrorAction SilentlyContinue
    if ($t1.PingSucceeded) {
        Write-OK "Ping exitoso. Latencia promedio: $($t1.PingReplyDetails.RoundTripTime) ms."
    } else {
        Write-Warn "Fallo el ping a 1.1.1.1 (posible bloqueo ICMP o caida de red)."
    }

    # 2. Test de resolucion DNS
    Write-SubStep "Midiendo velocidad de respuesta resolviendo 'google.com'..."
    $dnsTime = Measure-Command {
        $dnsTest = [System.Net.Dns]::GetHostAddresses("google.com")
    }
    if ($dnsTest) {
        Write-OK "DNS resuelto con exito en $([math]::Round($dnsTime.TotalMilliseconds, 2)) ms."
    } else {
        Write-ErrorMsg "Error al resolver google.com."
    }

    # ================================================================
    # FASE 3: MENU DE OPTIMIZACIONES (GRANULAR E INTERACTIVO)
    # ================================================================
    Write-StepHeader -StepNumber 4 -TotalSteps 4 -Message "Optimizaciones avanzadas de rendimiento de red"

    $selectedTweaks = $null
    $tweaksList = @(
        # --- Pila TCP (Oficial MS Learn Win11 25H2) ---
        [PSCustomObject]@{ Id='AutoTuning';         Category='TCP Stack (Oficial)'; Name='TCP AutoTuning a Normal';            Desc='Optimiza la ventana dinamica de recepcion TCP para descargas de alta velocidad.' },
        [PSCustomObject]@{ Id='ScalingHeuristics';  Category='TCP Stack (Oficial)'; Name='Desactivar Scaling Heuristics';      Desc='Previene que Windows degrade automaticamente la ventana de AutoTuning.' },
        [PSCustomObject]@{ Id='CongestionCubic';    Category='TCP Stack (Oficial)'; Name='Algoritmo de Congestion CUBIC';      Desc='Establece CUBIC como proveedor TCP prioritario para alta velocidad/fibra.' },
        [PSCustomObject]@{ Id='DisableTimestamps';  Category='TCP Stack (Oficial)'; Name='Desactivar TCP Timestamps';          Desc='Reduce overhead de 12 bytes por paquete TCP para menor latencia en Gigabit.' },
        [PSCustomObject]@{ Id='FastOpen';           Category='TCP Stack (Oficial)'; Name='Habilitar TCP Fast Open (TFO)';      Desc='Agiliza apretones de manos TCP en conexiones web compatibles.' },
        [PSCustomObject]@{ Id='SynRetries';         Category='TCP Stack (Oficial)'; Name='Optimizar SYN Retransmissions (=2)'; Desc='Reduce tiempo de espera (timeout) en conexiones no respondidas.' },

        # --- Sistema y Registro (Latencia / Gaming Comunitario) ---
        [PSCustomObject]@{ Id='NetThrottling';      Category='Sistema / Gaming';    Name='Desactivar Network Throttling';       Desc='Elimina el limite de paquetes de red cuando hay multimedia/juegos activos.' },
        [PSCustomObject]@{ Id='SystemResponsiveness';Category='Sistema / Gaming';   Name='100% CPU a Juegos/Apps (Resp=0)';    Desc='Asigna el 100% de recursos de CPU a aplicaciones activas en vez del 80%.' },
        [PSCustomObject]@{ Id='QoSUncap';           Category='Sistema / Gaming';    Name='Quitar Reserva Ancho de Banda QoS';  Desc='Establece NonBestEffortLimit en 0 (elimina reserva del 20% de ancho de banda).' },
        [PSCustomObject]@{ Id='NagleAlgorithm';     Category='Sistema / Gaming';    Name='Desactivar Algoritmo Nagle';         Desc='Fuerza envio inmediato de paquetes TCP sin esperar acks (TcpNoDelay/AckFreq).' },

        # --- Adaptadores de Red (Hardware / Driver NDIS) ---
        [PSCustomObject]@{ Id='RSS';                Category='Hardware NIC';        Name='Habilitar RSS (Receive Side)';       Desc='Distribuye la carga de procesamiento de red en multiples nucleos de CPU.' },
        [PSCustomObject]@{ Id='GreenEthernet';      Category='Hardware NIC';        Name='Desactivar Ahorro de Energia (EEE)'; Desc='Desactiva Green Ethernet/EEE para evitar micro-cortes y latencia de wake-up.' },
        [PSCustomObject]@{ Id='DisableRSC';         Category='Hardware NIC';        Name='Desactivar RSC (Low Latency)';       Desc='Baja latencia/jitter para gaming y streaming. Puede aumentar uso de CPU.' },
        [PSCustomObject]@{ Id='DisableIntMod';      Category='Hardware NIC';        Name='Desactivar Moderacion Interrupciones';Desc='Procesa paquetes instantaneamente por paquete (Baja latencia / Uso CPU alto).' },
        [PSCustomObject]@{ Id='DisableOffloads';    Category='Hardware NIC';        Name='Desactivar Offloads de NIC (LSO)';   Desc='Troubleshooting: Previene micro-cortes si la tarjeta tiene drivers inestables.' },
        [PSCustomObject]@{ Id='DisableFlowCtrl';    Category='Hardware NIC';        Name='Desactivar Control de Flujo';        Desc='Evita pausas del adaptador bajo carga (previene bufferbloat local).' },

        # --- Troubleshooting y Reset ---
        [PSCustomObject]@{ Id='NetReset';           Category='Troubleshooting';     Name='Reset Completo de Red';               Desc='Restablece Winsock, TCP/IP y DNS (Recomendado ante fallos de conexion).' }
    )

    if ($Unattended) {
        $selectedTweaks = $tweaksList
        Write-Host "  Modo desatendido: seleccionando todos los tweaks de red recomendados..." -ForegroundColor Gray
    } else {
        Write-Host "  Abriendo menu interactivo de optimizaciones de red..." -ForegroundColor Yellow
        Write-Host "  (Usa Ctrl/Shift para seleccionar multiples items. Presiona OK para aplicar o Cancelar para omitir)." -ForegroundColor Gray
        $selectedTweaks = $tweaksList | Out-GridView -Title "Selecciona las optimizaciones de red a aplicar -- Cancelar para omitir todas" -PassThru
    }

    if ($selectedTweaks -and $selectedTweaks.Count -gt 0) {
        $selectedIds = $selectedTweaks.Id

        # --- OPTIMIZACIONES TCP STACK ---
        if ('AutoTuning' -in $selectedIds) {
            Write-Host "  - Ajustando TCP AutoTuning a 'Normal'..." -ForegroundColor Gray
            # NOTA DE AUDITORIA (Microsoft Learn):
            # Jamas permitir que esto se cambie a "Disabled". Los mitos de internet afirman que "Disabled" baja el ping,
            # pero matematicamente paraliza la ventana de recepcion a 64KB estrangulando todo el ancho de banda moderno.
            # "Normal" es el valor oficial soportado.
            try {
                & netsh.exe int tcp set global autotuninglevel=normal | Out-Null
                Set-NetTCPSetting -SettingName InternetCustom -AutoTuningLevelLocal Normal -ErrorAction SilentlyContinue | Out-Null
                Add-SummaryRecord -TweakId 'AutoTuning' -Name 'TCP AutoTuning Normal' -Category 'TCP Stack' -Result 'Aplicado' -Details 'Ventana dinamica establecida en Normal.'
                Write-Host "    TCP AutoTuning establecido en Normal." -ForegroundColor Green
            } catch {
                Add-SummaryRecord -TweakId 'AutoTuning' -Name 'TCP AutoTuning Normal' -Category 'TCP Stack' -Result 'Fallo' -Details $_.Exception.Message
                Write-Host "    ! Fallo al configurar TCP AutoTuning." -ForegroundColor Yellow
            }
        }

        if ('ScalingHeuristics' -in $selectedIds) {
            Write-Host "  - Desactivando Scaling Heuristics..." -ForegroundColor Gray
            try {
                & netsh.exe int tcp set global scalingheuristics=disabled | Out-Null
                Add-SummaryRecord -TweakId 'ScalingHeuristics' -Name 'Scaling Heuristics Disabled' -Category 'TCP Stack' -Result 'Aplicado' -Details 'Windows no degradara la ventana de AutoTuning.'
                Write-Host "    Scaling Heuristics deshabilitado." -ForegroundColor Green
            } catch {
                Add-SummaryRecord -TweakId 'ScalingHeuristics' -Name 'Scaling Heuristics Disabled' -Category 'TCP Stack' -Result 'Fallo' -Details $_.Exception.Message
                Write-Host "    ! Fallo al deshabilitar Scaling Heuristics." -ForegroundColor Yellow
            }
        }

        if ('CongestionCubic' -in $selectedIds) {
            Write-Host "  - Configurando Proveedor de Congestion TCP a CUBIC..." -ForegroundColor Gray
            try {
                Set-NetTCPSetting -SettingName InternetCustom -CongestionProvider CUBIC -ErrorAction Stop | Out-Null
                Add-SummaryRecord -TweakId 'CongestionCubic' -Name 'TCP Congestion CUBIC' -Category 'TCP Stack' -Result 'Aplicado' -Details 'Algoritmo CUBIC activado.'
                Write-Host "    Proveedor de congestión CUBIC activado." -ForegroundColor Green
            } catch {
                Add-SummaryRecord -TweakId 'CongestionCubic' -Name 'TCP Congestion CUBIC' -Category 'TCP Stack' -Result 'Omitido/Fallo' -Details 'No soportado o ya administrado por el sistema.'
                Write-Host "    ! No se pudo cambiar el proveedor a CUBIC." -ForegroundColor Yellow
            }
        }

        if ('DisableTimestamps' -in $selectedIds) {
            Write-Host "  - Desactivando TCP Timestamps (Reduccion de overhead)..." -ForegroundColor Gray
            try {
                & netsh.exe int tcp set global timestamps=disabled | Out-Null
                Add-SummaryRecord -TweakId 'DisableTimestamps' -Name 'TCP Timestamps Disabled' -Category 'TCP Stack' -Result 'Aplicado' -Details 'Overhead de 12 bytes por paquete removido.'
                Write-Host "    TCP Timestamps deshabilitado." -ForegroundColor Green
            } catch {
                Add-SummaryRecord -TweakId 'DisableTimestamps' -Name 'TCP Timestamps Disabled' -Category 'TCP Stack' -Result 'Fallo' -Details $_.Exception.Message
                Write-Host "    ! Fallo al deshabilitar TCP Timestamps." -ForegroundColor Yellow
            }
        }

        if ('FastOpen' -in $selectedIds) {
            Write-Host "  - Habilitando TCP Fast Open (TFO)..." -ForegroundColor Gray
            try {
                & netsh.exe int tcp set global fastopen=enabled | Out-Null
                & netsh.exe int tcp set global fastopenfallback=enabled | Out-Null
                Add-SummaryRecord -TweakId 'FastOpen' -Name 'TCP Fast Open Enabled' -Category 'TCP Stack' -Result 'Aplicado' -Details 'Handshake TCP optimizado.'
                Write-Host "    TCP Fast Open habilitado." -ForegroundColor Green
            } catch {
                Add-SummaryRecord -TweakId 'FastOpen' -Name 'TCP Fast Open Enabled' -Category 'TCP Stack' -Result 'Fallo' -Details $_.Exception.Message
                Write-Host "    ! Fallo al configurar TCP Fast Open." -ForegroundColor Yellow
            }
        }

        if ('SynRetries' -in $selectedIds) {
            Write-Host "  - Configurando Max SYN Retransmissions a 2..." -ForegroundColor Gray
            try {
                & netsh.exe int tcp set global maxsynretransmissions=2 | Out-Null
                Add-SummaryRecord -TweakId 'SynRetries' -Name 'Max SYN Retries = 2' -Category 'TCP Stack' -Result 'Aplicado' -Details 'Timeouts de reconexion acelerados.'
                Write-Host "    Max SYN Retransmissions ajustado a 2." -ForegroundColor Green
            } catch {
                Add-SummaryRecord -TweakId 'SynRetries' -Name 'Max SYN Retries = 2' -Category 'TCP Stack' -Result 'Fallo' -Details $_.Exception.Message
                Write-Host "    ! Fallo al ajustar Max SYN Retransmissions." -ForegroundColor Yellow
            }
        }

        # --- OPTIMIZACIONES DE SISTEMA Y REGISTRO ---
        if ('NetThrottling' -in $selectedIds) {
            Write-Host "  - Desactivando NetworkThrottlingIndex en Registro..." -ForegroundColor Gray
            try {
                $sysPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
                if (-not (Test-Path $sysPath)) { New-Item -Path $sysPath -Force | Out-Null }
                Set-ItemProperty -Path $sysPath -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -ErrorAction Stop
                Add-SummaryRecord -TweakId 'NetThrottling' -Name 'Disable Network Throttling' -Category 'Sistema / Registry' -Result 'Aplicado' -Details 'NetworkThrottlingIndex = 0xFFFFFFFF'
                Write-Host "    Network Throttling deshabilitado." -ForegroundColor Green
            } catch {
                Add-SummaryRecord -TweakId 'NetThrottling' -Name 'Disable Network Throttling' -Category 'Sistema / Registry' -Result 'Fallo' -Details $_.Exception.Message
                Write-Host "    ! No se pudo modificar NetworkThrottlingIndex." -ForegroundColor Yellow
            }
        }

        if ('SystemResponsiveness' -in $selectedIds) {
            Write-Host "  - Ajustando SystemResponsiveness a 0 (100% CPU a Apps/Juegos)..." -ForegroundColor Gray
            try {
                $sysPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
                if (-not (Test-Path $sysPath)) { New-Item -Path $sysPath -Force | Out-Null }
                Set-ItemProperty -Path $sysPath -Name "SystemResponsiveness" -Value 0 -Type DWord -ErrorAction Stop
                Add-SummaryRecord -TweakId 'SystemResponsiveness' -Name 'SystemResponsiveness = 0' -Category 'Sistema / Registry' -Result 'Aplicado' -Details 'Prioridad maxima de CPU a aplicaciones activas.'
                Write-Host "    SystemResponsiveness establecido en 0." -ForegroundColor Green
            } catch {
                Add-SummaryRecord -TweakId 'SystemResponsiveness' -Name 'SystemResponsiveness = 0' -Category 'Sistema / Registry' -Result 'Fallo' -Details $_.Exception.Message
                Write-Host "    ! No se pudo modificar SystemResponsiveness." -ForegroundColor Yellow
            }
        }

        if ('QoSUncap' -in $selectedIds) {
            Write-Host "  - Desactivando reserva de ancho de banda QoS (NonBestEffortLimit = 0)..." -ForegroundColor Gray
            try {
                $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
                if (-not (Test-Path $qosPath)) { New-Item -Path $qosPath -Force | Out-Null }
                Set-ItemProperty -Path $qosPath -Name "NonBestEffortLimit" -Value 0 -Type DWord -ErrorAction Stop
                Add-SummaryRecord -TweakId 'QoSUncap' -Name 'QoS NonBestEffortLimit = 0' -Category 'Sistema / Registry' -Result 'Aplicado' -Details 'Reserva del 20% de ancho de banda eliminada.'
                Write-Host "    Reserva de ancho de banda QoS eliminada." -ForegroundColor Green
            } catch {
                Add-SummaryRecord -TweakId 'QoSUncap' -Name 'QoS NonBestEffortLimit = 0' -Category 'Sistema / Registry' -Result 'Fallo' -Details $_.Exception.Message
                Write-Host "    ! No se pudo configurar NonBestEffortLimit." -ForegroundColor Yellow
            }
        }

        if ('NagleAlgorithm' -in $selectedIds) {
            Write-Host "  - Desactivando Algoritmo Nagle en adaptadores activos..." -ForegroundColor Gray
            try {
                $ifPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
                $subKeys = Get-ChildItem -Path $ifPath -ErrorAction SilentlyContinue
                $count = 0
                foreach ($key in $subKeys) {
                    Set-ItemProperty -Path $key.PSPath -Name "TcpNoDelay" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $key.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $key.PSPath -Name "TcpDelAckTicks" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                    $count++
                }
                Add-SummaryRecord -TweakId 'NagleAlgorithm' -Name 'Disable Nagle Algorithm' -Category 'Sistema / Registry' -Result 'Aplicado' -Details "TcpNoDelay/AckFreq configurado en $count interfaces."
                Write-Host "    Algoritmo de Nagle deshabilitado en interfaces de red." -ForegroundColor Green
            } catch {
                Add-SummaryRecord -TweakId 'NagleAlgorithm' -Name 'Disable Nagle Algorithm' -Category 'Sistema / Registry' -Result 'Fallo' -Details $_.Exception.Message
                Write-Host "    ! Fallo al deshabilitar el Algoritmo de Nagle." -ForegroundColor Yellow
            }
        }

        # --- OPTIMIZACIONES DE ADAPTADORES DE HARDWARE ---
        $hardwareTweaks = @('RSS', 'GreenEthernet', 'DisableRSC', 'DisableIntMod', 'DisableOffloads', 'DisableFlowCtrl')
        $hasHardwareSelected = ($selectedIds | Where-Object { $_ -in $hardwareTweaks }).Count -gt 0

        if ($hasHardwareSelected -and $adapters) {
            foreach ($a in $adapters) {
                Write-Host "  - Procesando adaptador de hardware: $($a.Name)..." -ForegroundColor Gray

                if ('RSS' -in $selectedIds) {
                    try {
                        Enable-NetAdapterRss -Name $a.Name -ErrorAction SilentlyContinue
                        Add-SummaryRecord -TweakId 'RSS' -Name 'Enable RSS' -Category 'Hardware NIC' -Result 'Aplicado' -Details "RSS habilitado en $($a.Name)."
                        Write-Host "    RSS habilitado en $($a.Name)." -ForegroundColor Green
                    } catch {}
                }

                if ('GreenEthernet' -in $selectedIds) {
                    try {
                        # Intentar via RegistryKeyword *EEE
                        Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword "*EEE" -RegistryValue "0" -ErrorAction SilentlyContinue | Out-Null
                        
                        # Fallback por DisplayName
                        $eeeProps = Get-NetAdapterAdvancedProperty -Name $a.Name -ErrorAction SilentlyContinue | 
                                    Where-Object { $_.DisplayName -match 'Energy Efficient Ethernet|Green|Ahorro de energia' }
                        foreach ($prop in $eeeProps) {
                            Set-NetAdapterAdvancedProperty -Name $a.Name -DisplayName $prop.DisplayName -DisplayValue "Disabled" -ErrorAction SilentlyContinue | Out-Null
                        }
                        Add-SummaryRecord -TweakId 'GreenEthernet' -Name 'Disable Green Ethernet/EEE' -Category 'Hardware NIC' -Result 'Aplicado' -Details "EEE deshabilitado en $($a.Name)."
                        Write-Host "    EEE / Green Ethernet deshabilitado en $($a.Name)." -ForegroundColor Green
                    } catch {
                        Add-SummaryRecord -TweakId 'GreenEthernet' -Name 'Disable Green Ethernet/EEE' -Category 'Hardware NIC' -Result 'Fallo' -Details $_.Exception.Message
                    }
                }

                if ('DisableRSC' -in $selectedIds) {
                    try {
                        Disable-NetAdapterRsc -Name $a.Name -ErrorAction Stop
                        Add-SummaryRecord -TweakId 'DisableRSC' -Name 'Disable RSC' -Category 'Hardware NIC' -Result 'Aplicado' -Details "RSC deshabilitado en $($a.Name)."
                        Write-Host "    RSC deshabilitado en $($a.Name)." -ForegroundColor Green
                    } catch {
                        Add-SummaryRecord -TweakId 'DisableRSC' -Name 'Disable RSC' -Category 'Hardware NIC' -Result 'Omitido' -Details "No soportado o no aplicable en $($a.Name)."
                        Write-Host "    ! RSC no disponible o no soportado en $($a.Name)." -ForegroundColor Yellow
                    }
                }

                if ('DisableIntMod' -in $selectedIds) {
                    try {
                        Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword "*InterruptModeration" -RegistryValue "0" -ErrorAction Stop | Out-Null
                        Add-SummaryRecord -TweakId 'DisableIntMod' -Name 'Disable Interrupt Moderation' -Category 'Hardware NIC' -Result 'Aplicado' -Details "Moderacion de Interrupciones desactivada en $($a.Name)."
                        Write-Host "    Moderacion de Interrupciones desactivada en $($a.Name)." -ForegroundColor Green
                    } catch {
                        # Fallback por DisplayName
                        try {
                            $imProp = Get-NetAdapterAdvancedProperty -Name $a.Name -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Moderation|Moderacion' }
                            if ($imProp) {
                                Set-NetAdapterAdvancedProperty -Name $a.Name -DisplayName $imProp.DisplayName -DisplayValue "Disabled" -ErrorAction Stop | Out-Null
                                Add-SummaryRecord -TweakId 'DisableIntMod' -Name 'Disable Interrupt Moderation' -Category 'Hardware NIC' -Result 'Aplicado' -Details "Moderacion desactivada en $($a.Name)."
                                Write-Host "    Moderacion de Interrupciones desactivada en $($a.Name)." -ForegroundColor Green
                            } else { throw }
                        } catch {
                            Add-SummaryRecord -TweakId 'DisableIntMod' -Name 'Disable Interrupt Moderation' -Category 'Hardware NIC' -Result 'Fallo' -Details "No se pudo cambiar en $($a.Name)."
                            Write-Host "    ! No se pudo cambiar Interrupt Moderation en $($a.Name)." -ForegroundColor Yellow
                        }
                    }
                }

                if ('DisableOffloads' -in $selectedIds) {
                    try {
                        Disable-NetAdapterLso -Name $a.Name -ErrorAction Stop
                        Add-SummaryRecord -TweakId 'DisableOffloads' -Name 'Disable LSO' -Category 'Hardware NIC' -Result 'Aplicado' -Details "LSO deshabilitado en $($a.Name)."
                        Write-Host "    LSO Offload deshabilitado en $($a.Name)." -ForegroundColor Green
                    } catch {
                        Add-SummaryRecord -TweakId 'DisableOffloads' -Name 'Disable LSO' -Category 'Hardware NIC' -Result 'Omitido' -Details "No soportado en $($a.Name)."
                        Write-Host "    ! LSO no soportado en $($a.Name)." -ForegroundColor Yellow
                    }
                }

                if ('DisableFlowCtrl' -in $selectedIds) {
                    try {
                        Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword "*FlowControl" -RegistryValue "0" -ErrorAction Stop | Out-Null
                        Add-SummaryRecord -TweakId 'DisableFlowCtrl' -Name 'Disable Flow Control' -Category 'Hardware NIC' -Result 'Aplicado' -Details "Control de flujo desactivado en $($a.Name)."
                        Write-Host "    Control de flujo desactivado en $($a.Name)." -ForegroundColor Green
                    } catch {
                        try {
                            $fcProp = Get-NetAdapterAdvancedProperty -Name $a.Name -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Flow Control|Control de flujo' }
                            if ($fcProp) {
                                Set-NetAdapterAdvancedProperty -Name $a.Name -DisplayName $fcProp.DisplayName -DisplayValue "Disabled" -ErrorAction Stop | Out-Null
                                Add-SummaryRecord -TweakId 'DisableFlowCtrl' -Name 'Disable Flow Control' -Category 'Hardware NIC' -Result 'Aplicado' -Details "Control de flujo desactivado en $($a.Name)."
                                Write-Host "    Control de flujo desactivado en $($a.Name)." -ForegroundColor Green
                            } else { throw }
                        } catch {
                            Add-SummaryRecord -TweakId 'DisableFlowCtrl' -Name 'Disable Flow Control' -Category 'Hardware NIC' -Result 'Fallo' -Details "No detectado en $($a.Name)."
                            Write-Host "    ! Control de Flujo no detectado en $($a.Name)." -ForegroundColor Yellow
                        }
                    }
                }
            }
        }

        # --- TROUBLESHOOTING Y RESET ---
        if ('NetReset' -in $selectedIds) {
            Write-Host "  - Ejecutando Reset Completo de Red (Winsock, TCP/IP, DNS)..." -ForegroundColor Gray
            try {
                & netsh.exe winsock reset | Out-Null
                & netsh.exe int ip reset | Out-Null
                
                # Cmdlet nativo de PS para flush DNS con fallback a ipconfig
                try { Clear-DnsClientCache -ErrorAction Stop } catch { & ipconfig.exe /flushdns | Out-Null }
                
                Add-SummaryRecord -TweakId 'NetReset' -Name 'Reset Completo de Red' -Category 'Troubleshooting' -Result 'Aplicado' -Details 'Winsock, TCP/IP y DNS restablecidos con exito.'
                Write-Host "    Winsock, TCP/IP y DNS restablecidos. (Puede requerir reinicio)." -ForegroundColor Green
            } catch {
                Add-SummaryRecord -TweakId 'NetReset' -Name 'Reset Completo de Red' -Category 'Troubleshooting' -Result 'Fallo' -Details $_.Exception.Message
                Write-Host "    ! Hubo un problema al restablecer las configuraciones de red." -ForegroundColor Yellow
            }
        }

        # Registrar ítems no seleccionados en el resumen
        foreach ($tweak in $tweaksList) {
            if ($tweak.Id -notin $selectedIds) {
                Add-SummaryRecord -TweakId $tweak.Id -Name $tweak.Name -Category $tweak.Category -Result 'Omitido' -Details 'No fue seleccionado por el usuario.'
            }
        }

    } else {
        Write-Host "  No se selecciono ninguna optimizacion. Omitiendo cambios." -ForegroundColor Gray
        foreach ($tweak in $tweaksList) {
            Add-SummaryRecord -TweakId $tweak.Id -Name $tweak.Name -Category $tweak.Category -Result 'Omitido' -Details 'Seleccion omitida/cancelada.'
        }
    }

    # ================================================================
    # FASE 4: RESUMEN FINAL DE EJECUCION
    # ================================================================
    Write-Host "`n==========================================================" -ForegroundColor Magenta
    Write-Host "               RESUMEN DE OPTIMIZACIONES DE RED" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Magenta
    
    if ($executionSummary.Count -gt 0) {
        $executionSummary | Format-Table -Property Name, Category, Result, Details -AutoSize | Out-String | Write-Host -ForegroundColor White
    }

    Write-Host "==== Proceso de red finalizado con exito. Log guardado en: $log ====" -ForegroundColor Cyan

} finally {
    Write-LogSummary
    try { Stop-Transcript | Out-Null } catch {}
}
