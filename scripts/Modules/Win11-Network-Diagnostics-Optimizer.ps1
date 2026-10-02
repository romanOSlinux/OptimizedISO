<#
    Win11-Network-Diagnostics-Optimizer.ps1
    Herramienta avanzada de Diagnostico, Pruebas y Optimizacion de Conectividad en Windows 11 (25H2 Ready).
    Ejecutar elevado (Admin). Guarda logs en C:\Logs\Network-Diagnostics.log
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Unattended,
    [switch]$NagleOnly,
    [switch]$FlushDNSOnly,
    [string]$SetDNS,
    [switch]$TestDNS,
    [switch]$EnableDoH,
    [string]$InterfaceAlias,
    [switch]$Quiet,
    [switch]$PassThru,
    [switch]$SkipElevation
)

# Precarga de ensamblados WPF para soporte garantizado de interfaz grafica (Out-GridView)
try {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop
} catch {
    Write-Warning "[Network-Optimizer] No se pudieron precargar ensamblados WPF: $($_.Exception.Message)"
}

try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop } catch {
    Write-Warning "[Network-Optimizer] No se pudo establecer ExecutionPolicy: $($_.Exception.Message)"
}

$ErrorActionPreference = 'Continue'

# ============================================================
# CARGA DE MOTOR VISUAL UNIFICADO O MICRO-FALLBACK STANDALONE
# ============================================================
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
if (-not $uiLoaded) {
    function Show-UnifiedBanner { param($Title,$Subtitle,[switch]$ShowSystemInfo,[switch]$NoClear) Write-Host "`n=== $Title ($Subtitle) ===`n" -ForegroundColor Cyan }
    function Write-StepHeader   { param($StepNumber,$TotalSteps,$Message) Write-Host "`n>>> [$StepNumber/$TotalSteps] $Message" -ForegroundColor Cyan }
    function Write-SubStep      { param($Message) Write-Host "  -> $Message" -ForegroundColor Gray }
    function Write-OK           { param($Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
    function Write-Warn         { param($Message) Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
    function Write-ErrorMsg     { param($Message) Write-Host "  [ERROR] $Message" -ForegroundColor Red }
    function Write-Info         { param($Message) Write-Host "  [i] $Message" -ForegroundColor DarkGray }
    function Prompt-UnifiedYesNo { param([Alias("Title", "Question", "Message")]$Prompt, [Alias("DefaultYes")][bool]$Default=$true) $d=if($Default){"S"}else{"N"}; $r=Read-Host "  [?] $Prompt [S/N] (Default: $d)"; if([string]::IsNullOrWhiteSpace($r)){return $Default}; return ($r -match '^(s|si|y|yes)$') }
    function Show-UnifiedMenu   { param($Title,$Options,[int]$DefaultChoice=1,[switch]$AllowCancel,[string]$CancelText="Salir") for($i=0;$i -lt $Options.Count;$i++){ Write-Host "  [$($i+1)] $($Options[$i])" }; if($AllowCancel){ Write-Host "  [0] $CancelText" }; $r=Read-Host "  Opcion"; if(-not $r){return $DefaultChoice}; return [int]$r }
    function Show-UnifiedSummary { param($Title,$Status,$DurationSeconds,$ErrorsCount,$WarnsCount,$Logs) Write-Host "`n=== $($Title): $Status (${DurationSeconds}s) ===`n" -ForegroundColor Cyan }
    function Get-RomanOSErrorCodeDetails {
        param([long]$ExitCode)
        $intVal = try { [int32]$ExitCode } catch { [int32]($ExitCode -band 0xFFFFFFFFL) }
        $hexStr = "0x{0:X8}" -f $intVal
        return [PSCustomObject]@{ ExitCodeDecimal = $ExitCode; ExitCodeHex = $hexStr }
    }
    function Write-ForensicProcessFailure {
        param($TaskDescription, $FilePath, [long]$ExitCode, [string]$CommandLine = "", [string]$StdOut = "", [string]$StdErr = "", [string]$LogFilePath = "", [switch]$IsWarningOnly)
        $level = if ($IsWarningOnly) { "WARN" } else { "ERROR" }
        $hexStr = "0x{0:X8}" -f ([int32]$ExitCode)
        $header = "[$level] Fallo en proceso '$TaskDescription' | ExitCode: $ExitCode ($hexStr)"
        Write-Host "  $header" -ForegroundColor $(if($IsWarningOnly){"Yellow"}else{"Red"})
        return [PSCustomObject]@{
            Header          = $header
            ExitCode        = $ExitCode
            ExitCodeHex     = $hexStr
            CommandLine     = $CommandLine
            StdOut          = $StdOut
            StdErr          = $StdErr
            FullPlainReport = "$header`n$StdOut`n$StdErr".Trim()
        }
    }
    function Write-ForensicException {
        param($Record, [string]$Context = "")
        $msg = if ($Record -is [System.Management.Automation.ErrorRecord]) { $Record.Exception.Message } else { "$Record" }
        $header = "[ERROR] $(if($Context){"[$Context] "})$msg"
        Write-Host "  $header" -ForegroundColor Red
        return [PSCustomObject]@{ Header = $header; FullPlainReport = $header }
    }
}

# ============================================================
# CARGA DEL POLICY ENGINE (SSOT)
# ============================================================
$enginePaths = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\Policy-Engine.ps1"),
    (Join-Path $PSScriptRoot "Core\Policy-Engine.ps1"),
    (Join-Path $PSScriptRoot "Policy-Engine.ps1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\Policy-Engine.ps1"),
    "$env:WINDIR\Setup\Scripts\Core\Policy-Engine.ps1",
    "C:\Windows\Setup\Scripts\Core\Policy-Engine.ps1"
)
$engineLoaded = $false
foreach ($p in $enginePaths) {
    if (Test-Path $p) {
        . $p
        $engineLoaded = $true
        break
    }
}
if (-not $engineLoaded) {
    Write-Warning "No se pudo cargar Policy-Engine.ps1. El script no podra leer las directivas de red dinamicas."
}

# ============================================================
# FUNCIONES MODULARES DE DNS Y RED (INSPIRACIÓN WINUTIL / PLAN-0117)
# ============================================================

function Get-RomanOSActiveNetworkAdapters {
    <#
    .SYNOPSIS
        Detecta y retorna los adaptadores de red fisicos o activos del sistema de destino.
    #>
    [CmdletBinding()]
    param()

    try {
        $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
        if (-not $adapters) {
            $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Virtual|Hyper-V|Loopback|TAP|VPN' }
        }
        if (-not $adapters) {
            $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
        }
        if (-not $adapters) {
            $adapters = Get-NetAdapter -ErrorAction SilentlyContinue
        }
        return ,@($adapters)
    } catch {
        Write-Warning "Fallo al enumerar adaptadores de red: $($_.Exception.Message)"
        return @()
    }
}

function Test-RomanOSDnsLatency {
    <#
    .SYNOPSIS
        Mide la latencia RTT (Round-Trip Time) en milisegundos hacia los resolvers DNS canonicos.
    .DESCRIPTION
        Inspirado en el conmutador de DNS de Chris Titus Tech WinUtil, realiza sondeos en tiempo real
        (via Socket TCP en puerto 53 / Ping ICMP) para benchmark y recomendacion automatica.
    #>
    [CmdletBinding()]
    param(
        [string[]]$ProfileIds,
        [int]$Samples = 3,
        [int]$TimeoutMs = 800
    )

    $allProfiles = if (Get-Command "Get-RomanOSDnsProfiles" -ErrorAction SilentlyContinue) {
        Get-RomanOSDnsProfiles
    } else {
        @(
            [PSCustomObject]@{ Id = "Cloudflare"; Name = "Cloudflare DNS"; PrimaryIPv4 = "1.1.1.1"; SecondaryIPv4 = "1.0.0.1"; SupportsDoH = $true; DoHTemplate = "https://cloudflare-dns.com/dns-query" },
            [PSCustomObject]@{ Id = "Quad9"; Name = "Quad9 DNS"; PrimaryIPv4 = "9.9.9.9"; SecondaryIPv4 = "149.112.112.112"; SupportsDoH = $true; DoHTemplate = "https://dns.quad9.net/dns-query" },
            [PSCustomObject]@{ Id = "Google"; Name = "Google Public DNS"; PrimaryIPv4 = "8.8.8.8"; SecondaryIPv4 = "8.8.4.4"; SupportsDoH = $true; DoHTemplate = "https://dns.google/dns-query" },
            [PSCustomObject]@{ Id = "AdGuard"; Name = "AdGuard DNS"; PrimaryIPv4 = "94.140.14.14"; SecondaryIPv4 = "94.140.15.15"; SupportsDoH = $true; DoHTemplate = "https://dns.adguard-dns.com/dns-query" }
        )
    }

    $targets = if ($ProfileIds) {
        $allProfiles | Where-Object { $_.Id -in $ProfileIds -and $_.PrimaryIPv4 }
    } else {
        $allProfiles | Where-Object { $_.PrimaryIPv4 }
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($p in $targets) {
        $ip = $p.PrimaryIPv4
        $latencies = [System.Collections.Generic.List[double]]::new()
        $successCount = 0

        for ($i = 0; $i -lt $Samples; $i++) {
            $rtt = $null
            try {
                $ping = [System.Net.NetworkInformation.Ping]::new()
                $reply = $ping.Send($ip, $TimeoutMs)
                if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                    $rtt = [double]$reply.RoundtripTime
                }
            } catch {
                $rtt = $null
            }

            if ($null -eq $rtt) {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $client = $null
                try {
                    $client = [System.Net.Sockets.TcpClient]::new()
                    $iar = $client.BeginConnect($ip, 53, $null, $null)
                    $connected = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
                    if ($connected -and $client.Connected) {
                        $sw.Stop()
                        $rtt = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
                    }
                } catch {
                    $rtt = $null
                } finally {
                    if ($client) { $client.Close() }
                }
            }

            if ($null -ne $rtt) {
                $latencies.Add($rtt)
                $successCount++
            }
        }

        $avgLatency = if ($latencies.Count -gt 0) {
            [math]::Round(($latencies | Measure-Object -Average).Average, 1)
        } else {
            999.0
        }

        $minLatency = if ($latencies.Count -gt 0) {
            [math]::Round(($latencies | Measure-Object -Minimum).Minimum, 1)
        } else {
            999.0
        }

        $lossPct = [math]::Round((($Samples - $successCount) / $Samples) * 100, 0)
        $statusStr = if ($lossPct -eq 0) { "EXCELENTE" } elseif ($lossPct -lt 50) { "ACEPTABLE" } else { "INACCESIBLE" }

        $results.Add([PSCustomObject]@{
            Id             = $p.Id
            Name           = $p.Name
            PrimaryIPv4    = $p.PrimaryIPv4
            SecondaryIPv4  = $p.SecondaryIPv4
            DoHTemplate    = $p.DoHTemplate
            SupportsDoH    = $p.SupportsDoH
            AverageMs      = $avgLatency
            MinMs          = $minLatency
            PacketLoss     = "${lossPct}%"
            Status         = $statusStr
            Recommended    = $false
        })
    }

    $sorted = $results | Sort-Object AverageMs
    $firstValid = $sorted | Where-Object { $_.AverageMs -lt 999.0 } | Select-Object -First 1
    if ($firstValid) {
        $firstValid.Recommended = $true
    }

    return $sorted
}

function Set-RomanOSDnsServer {
    <#
    .SYNOPSIS
        Configura el servidor DNS y plantilla DoH en el adaptador activo o especificado.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfileId,

        [string]$InterfaceAlias,

        [switch]$EnableDoH,

        [switch]$Quiet
    )

    $profile = if (Get-Command "Get-RomanOSDnsProfileById" -ErrorAction SilentlyContinue) {
        Get-RomanOSDnsProfileById -Id $ProfileId
    } else {
        $all = if (Get-Command "Get-RomanOSDnsProfiles" -ErrorAction SilentlyContinue) { Get-RomanOSDnsProfiles } else { @() }
        $all | Where-Object { $_.Id -ieq $ProfileId }
    }

    if (-not $profile) {
        Write-Error "Perfil de DNS no reconocido: '$ProfileId'."
        return $false
    }

    $targetAdapters = if ($InterfaceAlias) {
        @(Get-NetAdapter -Name $InterfaceAlias -ErrorAction SilentlyContinue)
    } else {
        @(Get-RomanOSActiveNetworkAdapters)
    }

    if (-not $targetAdapters -or $targetAdapters.Count -eq 0) {
        Write-Warning "No se encontraron adaptadores de red activos para configurar DNS."
        return $false
    }

    $allSuccess = $true

    foreach ($adapter in $targetAdapters) {
        $alias = $adapter.InterfaceAlias
        $idx   = $adapter.InterfaceIndex

        if ($PSCmdlet.ShouldProcess("Adaptador '$alias' (Index: $idx)", "Aplicar configuración DNS '$($profile.Name)'")) {
            try {
                if ($profile.Id -ieq "DHCP") {
                    Set-DnsClientServerAddress -InterfaceIndex $idx -ResetServerAddresses -ErrorAction Stop
                    if (-not $Quiet) {
                        Write-Host "  [OK] Adaptador '$alias' configurado a DNS dinámico (DHCP)." -ForegroundColor Green
                    }
                } else {
                    $ips = @($profile.PrimaryIPv4)
                    if ($profile.SecondaryIPv4) { $ips += $profile.SecondaryIPv4 }

                    Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses $ips -ErrorAction Stop

                    if ($EnableDoH -and $profile.SupportsDoH -and $profile.DoHTemplate) {
                        try {
                            if (Get-Command "Add-DnsClientDohServerAddress" -ErrorAction SilentlyContinue) {
                                Add-DnsClientDohServerAddress -ServerAddress $profile.PrimaryIPv4 -DohTemplate $profile.DoHTemplate -AllowFallbackToUdp $true -AutoUpgrade $true -ErrorAction SilentlyContinue | Out-Null
                                if ($profile.SecondaryIPv4) {
                                    Add-DnsClientDohServerAddress -ServerAddress $profile.SecondaryIPv4 -DohTemplate $profile.DoHTemplate -AllowFallbackToUdp $true -AutoUpgrade $true -ErrorAction SilentlyContinue | Out-Null
                                }
                            }
                        } catch {
                            Write-Warning "No se pudo registrar plantilla DoH en el cliente DNS: $($_.Exception.Message)"
                        }
                    }

                    if (-not $Quiet) {
                        $dohMsg = if ($EnableDoH -and $profile.SupportsDoH) { " (+ DoH activado)" } else { "" }
                        Write-Host "  [OK] Adaptador '$alias' configurado con $($profile.Name) ($($ips -join ', '))$dohMsg." -ForegroundColor Green
                    }
                }

                try { Clear-DnsClientCache -ErrorAction Stop } catch { & ipconfig.exe /flushdns | Out-Null }
            } catch {
                Write-Warning "Fallo al configurar DNS en '$alias': $($_.Exception.Message)"
                $allSuccess = $false
            }
        }
    }

    return $allSuccess
}

function Reset-RomanOSDnsServer {
    <#
    .SYNOPSIS
        Restablece la configuracion DNS del adaptador activo a DHCP automatico.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$InterfaceAlias,
        [switch]$Quiet
    )

    return (Set-RomanOSDnsServer -ProfileId "DHCP" -InterfaceAlias $InterfaceAlias -Quiet:$Quiet)
}

function Get-RomanOSCurrentDns {
    <#
    .SYNOPSIS
        Consulta la configuracion DNS activa de los adaptadores de red y detecta el proveedor.
    #>
    [CmdletBinding()]
    param()

    $adapters = @(Get-RomanOSActiveNetworkAdapters)
    $profiles = if (Get-Command "Get-RomanOSDnsProfiles" -ErrorAction SilentlyContinue) { Get-RomanOSDnsProfiles } else { @() }
    $output = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($a in $adapters) {
        try {
            $dns = Get-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -AddressFamily IPv4 -ErrorAction Stop
            $servers = $dns.ServerAddresses
            $matchedProfile = "Personalizado / Desconocido"
            if (-not $servers -or $servers.Count -eq 0) {
                $matchedProfile = "DHCP Automatico"
            } else {
                foreach ($p in $profiles) {
                    if ($p.PrimaryIPv4 -and ($servers -contains $p.PrimaryIPv4)) {
                        $matchedProfile = $p.Name
                        break
                    }
                }
            }

            $output.Add([PSCustomObject]@{
                InterfaceAlias  = $a.InterfaceAlias
                InterfaceIndex  = $a.InterfaceIndex
                Description     = $a.InterfaceDescription
                Status          = $a.Status
                DnsServers      = ($servers -join ', ')
                DetectedProfile = $matchedProfile
            })
        } catch {
            Write-Warning "Fallo al consultar DNS en $($a.InterfaceAlias): $($_.Exception.Message)"
        }
    }

    return ,$output.ToArray()
}

# ============================================================
# ACCIONES RÁPIDAS NO ELEVADAS O TEMPRANAS
# ============================================================

if ($TestDNS) {
    if (-not $Quiet) {
        Write-Host "`n==========================================================" -ForegroundColor Magenta
        Write-Host "   romanOS: BENCHMARK DE LATENCIA DNS (RTT Engine)        " -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Magenta
    }
    $latencies = Test-RomanOSDnsLatency
    if (-not $Quiet) {
        $latencies | Format-Table -Property Name, PrimaryIPv4, AverageMs, MinMs, PacketLoss, Status, Recommended -AutoSize
    }
    if ($PassThru) { return ,$latencies }
    Exit 0
}

if ($FlushDNSOnly) {
    try {
        Clear-DnsClientCache -ErrorAction Stop
        Write-Host "  [OK] Cache DNS vaciada con exito (Clear-DnsClientCache)." -ForegroundColor Green
    } catch {
        ipconfig /flushdns | Out-Null
        Write-Host "  [OK] Cache DNS vaciada con exito (ipconfig /flushdns)." -ForegroundColor Green
    }
    Exit 0
}

# Si fue invocado mediante dot-sourcing (como modulo de funciones), finalizar aqui exportando las funciones
if ($MyInvocation.InvocationName -eq '.') {
    return
}

# ============================================================
# COMPROBAR PRIVILEGIOS DE ADMINISTRADOR Y AUTO-ELEVACIÓN
# ============================================================
$isSimulated = ($PSBoundParameters.ContainsKey('WhatIf') -or $WhatIfPreference)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and -not $SkipElevation) {
    if ($isSimulated) {
        Write-Warning "Ejecutando en modo simulado (-WhatIf) sin elevacion UAC."
    } else {
        Write-Warning "Este script requiere privilegios de Administrador. Intentando elevar..."
        $ps51 = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $myScript = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
        $argList = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $myScript)
        if ($Unattended)     { $argList += '-Unattended' }
        if ($NagleOnly)      { $argList += '-NagleOnly' }
        if ($SetDNS)         { $argList += @('-SetDNS', $SetDNS) }
        if ($EnableDoH)      { $argList += '-EnableDoH' }
        if ($InterfaceAlias) { $argList += @('-InterfaceAlias', $InterfaceAlias) }
        if ($Quiet)          { $argList += '-Quiet' }
        if ($PassThru)       { $argList += '-PassThru' }
        try {
            Start-Process -FilePath $ps51 -ArgumentList $argList -Verb RunAs -ErrorAction Stop
            Exit 0
        } catch {
            Write-Warning "No se pudo elevar UAC ($($_.Exception.Message)). Continuando en modo estandar..."
        }
    }
}

if ($SetDNS) {
    $res = Set-RomanOSDnsServer -ProfileId $SetDNS -InterfaceAlias $InterfaceAlias -EnableDoH:$EnableDoH -Quiet:$Quiet
    if ($res) { Exit 0 } else { Exit 1 }
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
$global:RomanOS_LogFile = $script:LogFile

$script:LogErrors  = [System.Collections.Generic.List[string]]::new()
$script:LogWarns   = [System.Collections.Generic.List[string]]::new()

function Write-LogEntry {
    [CmdletBinding()]
    param(
        [ValidateSet("INIT","STEP","INFO","OK","WARN","ERROR","DEBUG","TRACE")]
        [string]$Level = "INFO",
        [string]$Message
    )
    $normalizedLevel = switch ($Level) {
        "INIT" { "INFO" }
        "STEP" { "INFO" }
        default { $Level }
    }
    if (Get-Command "Write-UnifiedLogEntry" -ErrorAction SilentlyContinue) {
        Write-UnifiedLogEntry -Message $Message -Level $normalizedLevel -TargetLogFile $script:LogFile | Out-Null
    } else {
        $ts   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $line = "[$ts] [$normalizedLevel] $Message"
        if ($script:LogFile) {
            try {
                [System.IO.File]::AppendAllText($script:LogFile, ($line + "`r`n"), [System.Text.Encoding]::UTF8)
            } catch {
                $null = $_.Exception
            }
        }
    }
    if ($Level -eq "ERROR") { $script:LogErrors.Add($Message) }
    if ($Level -eq "WARN")  { $script:LogWarns.Add($Message)  }
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
    try { Stop-Transcript -ErrorAction Stop | Out-Null } catch {
        Write-LogEntry -Level "INFO" -Message "Transcript previo detenido o no activo: $($_.Exception.Message)"
    }

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
    if ($NagleOnly) {
        Write-Host "`n>>> [MODO ENFOCADO] Desactivando Algoritmo Nagle (TCP No-Delay)..." -ForegroundColor Cyan
        try {
            $ifPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
            $subKeys = Get-ChildItem -Path $ifPath -ErrorAction SilentlyContinue
            $count = 0
            foreach ($key in $subKeys) {
                Set-ItemProperty -Path $key.PSPath -Name "TcpNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                # PLAN-0115: Preservar ACK diferido estandar (RFC 1122) para no colapsar throughput en fibra/gigabit ni causar tormenta DPC
                Remove-ItemProperty -Path $key.PSPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $key.PSPath -Name "TcpDelAckTicks" -ErrorAction SilentlyContinue
                $count++
            }
            Write-Host "  [OK] Algoritmo Nagle deshabilitado exitosamente en $count interfaces de red (TcpNoDelay=1, ACK diferido estandar)." -ForegroundColor Green
            Write-LogEntry -Level "OK" -Message "Nagle desactivado (TcpNoDelay=1, RFC 1122 Delayed ACK preservado) en $count interfaces."
        } catch {
            Write-Host "  ! Error configurando Nagle: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-LogEntry -Level "WARN" -Message "Fallo al desactivar Nagle: $($_.Exception.Message)"
        }
        return
    }

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
    $cfDns = "1.1.1.1"
    $t1 = Test-NetConnection -ComputerName $cfDns -ErrorAction SilentlyContinue
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

    # PRE-PROMPTS PARA AJUSTES PARAMETRIZADOS (PLAN-0039)
    $gigabit = $false
    $dohChoice = 0
    if (-not $Unattended) {
        Write-Host "
  [+] Parametrizacion Inteligente" -ForegroundColor Cyan
        $ans = Prompt-UnifiedYesNo -Prompt "¿Tu conexion de internet supera 1 Gbps (Fibra Optica)?" -Default $false
        if ($ans) { $gigabit = $true; Write-Host "      > Se aplicara AutoTuning Experimental." -ForegroundColor Gray }
        
        $dohChoice = Show-UnifiedMenu -Title "Selecciona un proveedor nativo DNS over HTTPS (DoH)" -Options @("Cloudflare (Recomendado - Baja latencia)", "Quad9 (Alta Privacidad)") -AllowCancel -CancelText "Omitir (Mantener DNS actual)"
    } else {
        $gigabit = $false # Default conservador
    }

    $selectedTweaks = $null
    $tweaksList = @()

    if ($global:RomanOS_NetworkPolicies) {
        foreach ($p in $global:RomanOS_NetworkPolicies) {
            $tweaksList += [PSCustomObject]@{
                Id              = $p.Id
                Category        = $p.Category
                Name            = if ($p.Name) { $p.Name } else { $p.Id.Replace('NET_TCP_', '').Replace('NET_SYS_', '').Replace('NET_NIC_', '').Replace('_', ' ') }
                Description     = $p.Description
                ActionType      = $p.ActionType
                Commands        = $p.Commands
                Command         = $p.Command
                RegistryKey     = $p.RegistryKey
                PSPath          = $p.PSPath
                ValueName       = $p.ValueName
                Type            = if ($p.PSType) { $p.PSType } elseif ($p.Type -eq 'REG_DWORD') { 'DWord' } elseif ($p.Type -eq 'REG_SZ') { 'String' } elseif ($p.Type -eq 'REG_QWORD') { 'QWord' } else { if ($p.Type) { $p.Type } else { 'DWord' } }
                ExpectedValue   = $p.ExpectedValue
                RegistryKeyword = $p.RegistryKeyword
                RegistryValue   = $p.RegistryValue
                DisplayMatch    = $p.DisplayMatch
                DisplayValue    = $p.DisplayValue
            }
        }
    } else {
        Write-Warning "El catalogo global RomanOS_NetworkPolicies no esta disponible. Verifica la carga de Policy-Engine.ps1."
    }

    # Modificar AutoTuning si es Gigabit
    if ($gigabit) {
        $atTweak = $tweaksList | Where-Object { $_.Id -eq 'NET_TCP_AUTOTUNING' }
        if ($atTweak) {
            $atTweak.Commands = @(
                "netsh.exe int tcp set global autotuninglevel=experimental",
                "Set-NetTCPSetting -SettingName InternetCustom -AutoTuningLevelLocal Experimental"
            )
            $atTweak.Description = "Ventana dinamica TCP establecida en Experimental (Conexion > 1 Gbps)."
        }
    }

    # Agregar opcion DoH si se selecciono
    if ($dohChoice -gt 0) {
        $dohName = if ($dohChoice -eq 1) { "Cloudflare DoH" } else { "Quad9 DoH" }
        $tweaksList += [PSCustomObject]@{ 
            Id = 'NET_DNS_DOH'
            Category = 'Sistema / Registry'
            Name = "Aplicar $dohName Nativo"
            Description = "Cifra el trafico DNS a traves de HTTPS (Windows 11)."
            ActionType = 'Local_DoH'
            ExpectedValue = $dohChoice 
        }
    }

    # --- Troubleshooting y Reset (Estático para red) ---
    $tweaksList += [PSCustomObject]@{ Id='NetReset'; Category='Troubleshooting'; Name='Reset Completo de Red'; Description='Restablece Winsock, TCP/IP y DNS (Recomendado ante fallos de conexion).'; ActionType='Local_Reset' }

    if ($Unattended) {
        $selectedTweaks = $tweaksList | Where-Object { $_.ActionType -ne 'Local_Reset' }
        Write-Host "  Modo desatendido: seleccionando todos los tweaks de red recomendados (excluyendo reinicio completo de red)..." -ForegroundColor Gray
    } else {
        Write-Host "  Abriendo menu interactivo de optimizaciones de red..." -ForegroundColor Yellow
        Write-Host "  (Usa Ctrl/Shift para seleccionar multiples items. Presiona OK para aplicar o Cancelar para omitir)." -ForegroundColor Gray
        $gridData = $tweaksList | Select-Object Id, Category, Name, Description
        $selectedGrid = $gridData | Out-GridView -Title "Selecciona las optimizaciones de red a aplicar -- Cancelar para omitir todas" -PassThru
        if ($selectedGrid) {
            $selectedIds = $selectedGrid.Id
            $selectedTweaks = $tweaksList | Where-Object { $_.Id -in $selectedIds }
        }
    }

    if ($selectedTweaks -and $selectedTweaks.Count -gt 0) {
        $selectedIds = $selectedTweaks.Id

        foreach ($tweak in $selectedTweaks) {
            Write-Host "  - Procesando $($tweak.Name)..." -ForegroundColor Gray
            try {
                switch ($tweak.ActionType) {
                    'Netsh' {
                        foreach ($cmd in $tweak.Commands) { Invoke-Expression "& $cmd | Out-Null" }
                    }
                    'NetTCPSetting' {
                        foreach ($cmd in $tweak.Commands) { Invoke-Expression "$cmd -ErrorAction Stop | Out-Null" }
                    }
                    'Netsh_NetTCPSetting' {
                        foreach ($cmd in $tweak.Commands) { Invoke-Expression "& $cmd -ErrorAction SilentlyContinue | Out-Null" }
                    }
                    'Registry' {
                        if (-not (Test-Path $tweak.PSPath)) { New-Item -Path $tweak.PSPath -Force | Out-Null }
                        $regType = if ($tweak.Type -eq 'REG_DWORD' -or $tweak.Type -eq 'DWord') { 'DWord' } elseif ($tweak.Type -eq 'REG_SZ' -or $tweak.Type -eq 'String') { 'String' } elseif ($tweak.Type) { $tweak.Type } else { 'DWord' }
                        Set-ItemProperty -Path $tweak.PSPath -Name $tweak.ValueName -Value $tweak.ExpectedValue -Type $regType -ErrorAction Stop
                    }
                    'DynamicRegistry_Interfaces' {
                        $ifPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
                        $subKeys = Get-ChildItem -Path $ifPath -ErrorAction SilentlyContinue
                        foreach ($key in $subKeys) {
                            Set-ItemProperty -Path $key.PSPath -Name "TcpNoDelay" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                            # PLAN-0115: Preservar ACK diferido estandar (RFC 1122) para proteger conexiones de alto rendimiento
                            Remove-ItemProperty -Path $key.PSPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
                            Remove-ItemProperty -Path $key.PSPath -Name "TcpDelAckTicks" -ErrorAction SilentlyContinue
                        }
                    }
                    'NetAdapter_Enable' {
                        if ($adapters) { foreach ($a in $adapters) { Invoke-Expression "$($tweak.Command) -Name '$($a.Name)' -ErrorAction SilentlyContinue" } }
                    }
                    'NetAdapter_Disable' {
                        if ($adapters) { foreach ($a in $adapters) { Invoke-Expression "$($tweak.Command) -Name '$($a.Name)' -ErrorAction Stop" } }
                    }
                    'NetAdapter_AdvancedProp' {
                        if ($adapters) {
                            foreach ($a in $adapters) {
                                try {
                                    Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword $tweak.RegistryKeyword -RegistryValue $tweak.RegistryValue -ErrorAction Stop | Out-Null
                                } catch {
                                    $prop = Get-NetAdapterAdvancedProperty -Name $a.Name -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match $tweak.DisplayMatch }
                                    if ($prop) {
                                        $applied = $false
                                        $isEnabling = ($tweak.DisplayValue -match '^(Enabled|Activado|Habilitado|1)$' -or $tweak.RegistryValue -eq '1')
                                        $candidateValues = if ($isEnabling) {
                                            @($tweak.DisplayValue, 'Habilitado', 'Activado', 'Enabled', '1')
                                        } else {
                                            @($tweak.DisplayValue, 'Desactivado', 'Deshabilitado', 'Disabled', '0')
                                        }
                                        foreach ($cv in $candidateValues) {
                                            try {
                                                Set-NetAdapterAdvancedProperty -Name $a.Name -DisplayName $prop.DisplayName -DisplayValue $cv -ErrorAction Stop | Out-Null
                                                $applied = $true
                                                break
                                            } catch {
                                                Write-LogEntry -Level "DEBUG" -Message "Valor '$cv' no aceptado por $($prop.DisplayName) en $($a.Name): $($_.Exception.Message)"
                                            }
                                        }
                                        if (-not $applied) { throw }
                                    } else { throw }
                                }
                            }
                        }
                    }
                    'Local_DoH' {
                        $profileId = if ($tweak.ExpectedValue -eq 1) { "Cloudflare" } else { "Quad9" }
                        Set-RomanOSDnsServer -ProfileId $profileId -EnableDoH -Quiet
                    }
                    'Local_Reset' {
                        Reset-RomanOSDnsServer -Quiet
                        & netsh.exe winsock reset | Out-Null
                        & netsh.exe int ip reset | Out-Null
                    }
                }
                
                Add-SummaryRecord -TweakId $tweak.Id -Name $tweak.Name -Category $tweak.Category -Result 'Aplicado' -Details $tweak.Description
                Write-Host "    $($tweak.Name) aplicado correctamente." -ForegroundColor Green
            } catch {
                Add-SummaryRecord -TweakId $tweak.Id -Name $tweak.Name -Category $tweak.Category -Result 'Fallo' -Details $_.Exception.Message
                Write-Host "    ! Fallo al aplicar $($tweak.Name)." -ForegroundColor Yellow
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
    try { Stop-Transcript | Out-Null } catch {
        Write-LogEntry -Level "INFO" -Message "Transcript finalizado: $($_.Exception.Message)"
    }
}
