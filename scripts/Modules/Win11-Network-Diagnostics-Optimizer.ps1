<#
    Win11-Network-Diagnostics-Optimizer.ps1
    Herramienta avanzada de Diagnostico, Pruebas y Optimizacion de Conectividad en Windows 11 (25H2 Ready).
    Ejecutar elevado (Admin). Guarda logs en C:\Logs\Network-Diagnostics.log
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Unattended,
    [switch]$NagleOnly,
    [switch]$FlushDNSOnly
)

# Precarga de ensamblados WPF para soporte garantizado de interfaz grafica (Out-GridView)
try {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction SilentlyContinue
} catch {}

# ============================================================
# Comprobar privilegios de Administrador y auto-elevar
# ============================================================
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue } catch {}

$isSimulated = ($PSBoundParameters.ContainsKey('WhatIf') -or $WhatIfPreference)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    if ($isSimulated) {
        Write-Warning "Ejecutando en modo simulado (-WhatIf) sin elevacion UAC."
    } else {
        Write-Warning "Este script requiere privilegios de Administrador. Reiniciando de forma elevada..."
        $ps51 = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $myScript = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
        $argList = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $myScript)
        if ($Unattended) { $argList += '-Unattended' }
        if ($NagleOnly) { $argList += '-NagleOnly' }
        if ($FlushDNSOnly) { $argList += '-FlushDNSOnly' }
        Start-Process -FilePath $ps51 -ArgumentList $argList -Verb RunAs
        Exit
    }
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
    if ($NagleOnly) {
        Write-Host "`n>>> [MODO ENFOCADO] Desactivando Algoritmo Nagle (TCP No-Delay)..." -ForegroundColor Cyan
        try {
            $ifPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
            $subKeys = Get-ChildItem -Path $ifPath -ErrorAction SilentlyContinue
            $count = 0
            foreach ($key in $subKeys) {
                Set-ItemProperty -Path $key.PSPath -Name "TcpNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $key.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $key.PSPath -Name "TcpDelAckTicks" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                $count++
            }
            Write-Host "  [OK] Algoritmo Nagle deshabilitado exitosamente en $count interfaces de red." -ForegroundColor Green
            Write-LogEntry -Level "OK" -Message "Nagle desactivado (TcpNoDelay=1, TcpAckFrequency=1) en $count interfaces."
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
        $selectedTweaks = $tweaksList
        Write-Host "  Modo desatendido: seleccionando todos los tweaks de red recomendados..." -ForegroundColor Gray
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
                            Set-ItemProperty -Path $key.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                            Set-ItemProperty -Path $key.PSPath -Name "TcpDelAckTicks" -Value 0 -Type DWord -ErrorAction SilentlyContinue
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
                                        Set-NetAdapterAdvancedProperty -Name $a.Name -DisplayName $prop.DisplayName -DisplayValue $tweak.DisplayValue -ErrorAction Stop | Out-Null
                                    } else { throw }
                                }
                            }
                        }
                    }
                    'Local_DoH' {
                        if ($tweak.ExpectedValue -eq 1) {
                            $pri = "1.1.1.1"
                            $sec = "1.0.0.1"
                            $tmpl = "https://cloudflare-dns.com/dns-query"
                        } else {
                            $pri = "9.9.9.9"
                            $sec = "149.112.112.112"
                            $tmpl = "https://dns.quad9.net/dns-query"
                        }
                        if ($adapters) {
                            foreach ($a in $adapters) {
                                try {
                                    Set-DnsClientServerAddress -InterfaceAlias $a.InterfaceAlias -ServerAddresses $pri, $sec -ErrorAction SilentlyContinue
                                    Add-DnsClientDohServerAddress -ServerAddress $pri -DohTemplate $tmpl -AllowFallbackToUdp $false -ErrorAction SilentlyContinue
                                    Add-DnsClientDohServerAddress -ServerAddress $sec -DohTemplate $tmpl -AllowFallbackToUdp $false -ErrorAction SilentlyContinue
                                    Set-DnsClientServerAddress -InterfaceAlias $a.InterfaceAlias -ServerAddresses $pri, $sec -ErrorAction SilentlyContinue
                                } catch { Write-Warning "No se pudo configurar DoH nativo en $($a.Name)" }
                            }
                        }
                    }
                    'Local_Reset' {
                        & netsh.exe winsock reset | Out-Null
                        & netsh.exe int ip reset | Out-Null
                        try { Clear-DnsClientCache -ErrorAction Stop } catch { & ipconfig.exe /flushdns | Out-Null }
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
    try { Stop-Transcript | Out-Null } catch {}
}
