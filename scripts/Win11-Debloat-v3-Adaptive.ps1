<#
    Win11-Debloat-v3-Adaptive.ps1
    Fresh Windows 11 25H2 (build 26200) -- setup / debloat / privacy / gaming (adaptativo).
    Ejecutar elevado (Admin). Crea punto de restauracion antes de cualquier cambio.

    CORRECCIONES v3 (9 bugs fixeados) + MEJORAS v4 (7 mejoras de hardware intelligence):
      [FIX-1..9] Ver historial previo de correcciones de bugs.

      [NEW-1] 11.A: Disco ampliado -- distingue NVMe / SATA SSD / HDD via BusType.
               Variables $isNVMe y $diskBusType. Habilita sub-decisiones especificas por tipo.
      [NEW-2] 11.A: Detecta canales RAM (single vs dual). Advertencia en iGPU + single channel
               (hasta 40% menos ancho de banda de memoria).
      [NEW-3] 11.A/11.B: Lee temperatura CPU en idle (MSAcpi_ThermalZoneTemperature).
               Advertencia si laptop en idle > 70 C (posible throttling termico activo).
      [NEW-4] 11.C: Power Throttling OFF automatico en Desktop (no laptop).
               Clave PowerThrottlingOff=1. Documentado winaero, XDA-Developers, MS Q&A.
      [NEW-5] 11.C: SysMain forzado OFF si HDD con menos del 5% de espacio libre.
               (sin espacio, SysMain consume CPU sin poder guardar ReadyBoot).
      [NEW-6] 12.B: HAGS ahora verifica version de driver antes de activar.
               Evita BSOD en sistemas con drivers WDDM < 2.7.
      [NEW-7] 12.D: GlobalTimerResolutionRequests=1 agregado al bloque Timer fix.
               Solo para CPUs modernas (12th Gen+ / Ryzen 5000+).
      [NEW-8] 12.H: MSI Mode para GPU dedicada via PNPDeviceID (nuevo bloque).
               Reduce latencia DPC del driver de GPU. NVIDIA/AMD/Arc.
      [NEW-9] 12.I: Win32PrioritySeparation -- NO APLICADO (benchmarks negligibles).
               Solo informativo. El scheduler de Win11 ya prioriza foreground.
      [NEW-10] 11.C: Power Throttling OFF automatico en Desktop (no laptop).
               Clave PowerThrottlingOff=1. Ref: Microsoft Q&A, Winaero.
      [NEW-11] 11.D/12.J: Nagle Algorithm disable (TCP No-Delay) para gaming online.
               TcpNoDelay=1, TcpAckFrequency=1 en adaptador activo. Opcional.
      [NEW-12] 12.F: Windowed Games optimization (SwapEffectUpgradeEnable=1).
               Feature nativa de Windows 11 25H2 para latencia en borderless.
      [NEW-13] Pre-flight: Deteccion de build number y DisplayVersion de Windows.

    Sections:
      *. Check Admin privileges
      *. Create system restore point (pre-flight)
      *. Hardware Detection & System Dashboard (pre-flight, antes de menus)
      *. Winget verification (4-level fallback)
      *. Health Check: Prerrequisitos esenciales del sistema
      *. Pausa para revision del dashboard
    0.A. Install missing prerequisites (VC++, .NET, WebView2, DirectX, etc.)
    0.B. Install applications via winget
      1. Remove bloatware Appx apps (Interactive)
      2. Remove Win32 applications -- OneDrive, Teams, Skype (Interactive, protegido)
      3. Dark mode + dark wallpaper
      4. Taskbar: left align, hide Search/Task View/Widgets, pin only File Explorer
      5. File Explorer: open to This PC, show file extensions
      6. Privacy & telemetry hardening
      7. Disable background apps
      8. Disable Windows Services (Interactive) & Scheduled tasks
      9. Start menu: unpin all, All Apps = List view
     10. Extra system tweaks
     11. Hardware Adaptive Tweaks (acciones automaticas + menu interactivo)
     12. Gaming optimizations (Core) [ENHANCED v5]
     13. MMAgent tuning
     14. DISM component cleanup
     15. Restart Explorer
#>

param(
    [switch]$Unattended
)

# ============================================================
# FIX-PS51-1: Forzar TLS 1.2 y 1.3 de forma GLOBAL al inicio.
# PS 5.1 arranca con SSL3/TLS1.0 por defecto. GitHub, Microsoft CDN
# y PSGallery rechazan esas versiones con "Could not create SSL/TLS secure channel".
# Usamos valores numericos (3072 = Tls12, 12288 = Tls13) para evitar
# errores en builds donde la enum no incluye Tls13.
# ============================================================
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor 3072 -bor 12288
} catch {
    [Net.ServicePointManager]::SecurityProtocol = 3072  # Tls12 como minimo seguro
}

# ============================================================
# Comprobar privilegios de Administrador y auto-elevar
# ============================================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Este script debe ejecutarse como Administrador. Reiniciando con privilegios elevados..."
    $ps51 = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $myScript = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
    # FIX-PS51-2: Pasar argumentos como ARRAY en lugar de string plano.
    # En PS 5.1, un string con comillas anidadas en -ArgumentList provoca
    # que powershell.exe no encuentre el archivo si la ruta tiene espacios.
    $argArray = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $myScript)
    if ($Unattended) { $argArray += '-Unattended' }
    Start-Process -FilePath $ps51 -ArgumentList $argArray -Verb RunAs
    Exit
}

$ErrorActionPreference = 'Continue'

# Variables globales de rutas de registro (usadas en multiples secciones)
$adv    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$expPol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'

# ============================================================
# LOGGING ENGINE — Write-Log + Start-Transcript
# Genera dos archivos con timestamp en C:\Logs\
#   Setup-Windows_<ts>.log            ← log estructurado con niveles
#   Setup-Windows_<ts>_transcript.log ← transcripción completa de consola
# ============================================================
$logDir = "C:\Logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

$_logTs                = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:LogFile        = "$logDir\Setup-Windows_$_logTs.log"
$script:TranscriptFile = "$logDir\Setup-Windows_${_logTs}_transcript.log"
$script:AiSummaryFile  = "$logDir\Setup-Windows_${_logTs}_AI_SUMMARY.md"
$script:DebloatStart   = Get-Date
$log                   = $script:LogFile   # compatibilidad con Write-Host existentes

$script:LogErrors   = [System.Collections.Generic.List[string]]::new()
$script:LogWarns    = [System.Collections.Generic.List[string]]::new()

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
    $totalDuration = [math]::Round(((Get-Date) - $script:DebloatStart).TotalSeconds, 1)

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
        Write-LogEntry -Level "OK" -Message "Debloat completado sin errores críticos."
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
        [void]$sb.AppendLine("# AI Diagnostic Report: Win11-Debloat-v3-Adaptive")
        [void]$sb.AppendLine("- **Status:** $statusBadge")
        [void]$sb.AppendLine("- **Timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        [void]$sb.AppendLine("- **Total Duration:** ${totalDuration}s")
        [void]$sb.AppendLine("- **Host:** $env:COMPUTERNAME | **User:** $env:USERNAME | **PowerShell:** $($PSVersionTable.PSVersion)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## System Environment Detected")
        [void]$sb.AppendLine("| Property | Value |")
        [void]$sb.AppendLine("|---|---|")
        [void]$sb.AppendLine("| Hardware Profile | ``$hwProfile`` |")
        [void]$sb.AppendLine("| Windows Edition | ``$winEdition $osDisplayVersion`` |")
        [void]$sb.AppendLine("| Winget Available | ``$($script:HasWinget)`` |")
        [void]$sb.AppendLine("| Pre-optimized Flags | ``$script:PreOptimizedFlags`` |")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Tweaks & Optimization Status")
        [void]$sb.AppendLine("| Feature | Applied |")
        [void]$sb.AppendLine("|---|---|")
        [void]$sb.AppendLine("| GameBar / GameDVR | $(if($applyGameBar){'Applied ✅'}else{'Skipped ⚪'}) |")
        [void]$sb.AppendLine("| HAGS (Hardware GPU Scheduling) | $(if($applyHags){'Applied ✅'}else{'Skipped ⚪'}) |")
        [void]$sb.AppendLine("| VBS / Core Isolation | $(if($applyVbs){'Disabled ✅'}else{'Unchanged ⚪'}) |")
        [void]$sb.AppendLine("| Network / Nagle TCP | $(if($applyNagle){'Disabled ✅'}else{'Unchanged ⚪'}) |")
        [void]$sb.AppendLine("| Power Plan | $(if($applyUltimate){'Ultimate / High Performance ✅'}else{'Balanced ⚪'}) |")

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
    } catch {}

    Write-Host ""
    Write-Host "  ┌─ Logs generados (Listos para análisis por IA) ────────────────" -ForegroundColor DarkCyan
    if ($script:AiSummaryFile)  { Write-Host "  │  AI Diagnostic MD : $script:AiSummaryFile  <-- Pásame este archivo" -ForegroundColor Green }
    Write-Host "  │  Log estructurado : $script:LogFile" -ForegroundColor Cyan
    Write-Host "  │  Transcript       : $script:TranscriptFile" -ForegroundColor Cyan
    if ($script:LogErrors.Count -gt 0) {
        Write-Host "  │" -ForegroundColor DarkCyan
        Write-Host "  │  [$($script:LogErrors.Count) ERROR(S) detectados — revisa el reporte]" -ForegroundColor Red
    } else {
        Write-Host "  │  Sin errores críticos registrados." -ForegroundColor Green
    }
    Write-Host "  └───────────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
}

# Abrir transcript
try {
    Start-Transcript -Path $script:TranscriptFile -Append -ErrorAction Stop | Out-Null
} catch {
    Write-Host "  [LOG] Start-Transcript no disponible: $($_.Exception.Message)" -ForegroundColor DarkGray
}

# Cabecera del log estructurado
Write-LogEntry -Level "INIT" -Message ("=" * 64)
Write-LogEntry -Level "INIT" -Message "Win11-Debloat-v3-Adaptive Build Log"
Write-LogEntry -Level "INIT" -Message "PowerShell $($PSVersionTable.PSVersion) | Host: $env:COMPUTERNAME | User: $env:USERNAME"
Write-LogEntry -Level "INIT" -Message ("=" * 64)

try {

Write-Host "==== Windows setup started $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====" -ForegroundColor Cyan

# ============================================================
# Helper: escribir un valor de registro creando la clave si no existe
# ============================================================
function Set-Reg {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    try {
        # Copia de seguridad si la clave existe
        if (Test-Path $Path) {
            $backupFile = "C:\Logs\RegistryBackup_BeforeChanges.reg"
            if (-not (Test-Path $backupFile)) {
                # Convertir ruta PowerShell a ruta nativa de registro para reg.exe
                $nativePath = $Path -replace '(?i)^HKLM:\\', 'HKLM\' -replace '(?i)^HKCU:\\', 'HKCU\'
                # Ejecutar reg export de manera segura
                try {
                    & reg.exe export $nativePath $backupFile /y *>$null
                } catch {}
            }
        }
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
    } catch {
        Write-Host "  ! Set-Reg failed: $Path\$Name -> $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ============================================================
#region Pre-flight: System Restore point
# ============================================================
Write-Host "`n[*] Creating a system restore point..." -ForegroundColor Cyan
try {
    New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' `
        -Name 'SystemRestorePointCreationFrequency' -Value 0 -PropertyType DWord -Force | Out-Null
    Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue
    Set-Service -Name VSS -StartupType Manual  -ErrorAction SilentlyContinue
    Start-Service -Name VSS -ErrorAction SilentlyContinue

    if (Get-Command -Name 'Checkpoint-Computer' -ErrorAction SilentlyContinue) {
        Checkpoint-Computer -Description 'Before Windows setup script' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
    } else {
        # Fallback WMI para PS7 donde Checkpoint-Computer fue removido
        $wmi    = [wmiclass]'\\.\root\default:SystemRestore'
        $result = $wmi.CreateRestorePoint('Before Windows setup script', 12, 100)
        if ($result.ReturnValue -ne 0) { throw "WMI CreateRestorePoint returned $($result.ReturnValue)" }
    }
    Write-Host "  - Restore point created." -ForegroundColor Green
} catch {
    Write-Host "  ! Could not create restore point: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "    Continuando. Crealo manualmente en Proteccion del Sistema si lo necesitas." -ForegroundColor Yellow
}
#endregion

# ============================================================
# Pre-flight: Detección básica de Edición y Hardware
# ============================================================
$winOS = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$winEdition = if ($winOS) { $winOS.Caption } else { 'Desconocido' }
$isHomeEdition = $winEdition -match 'Home'
$isEnterpriseEdition = $winEdition -match 'Enterprise|Education'

# [NEW-13] Build number y version de Windows (para decidir features disponibles)
$osBuild = [System.Environment]::OSVersion.Version.Build
try {
    $ntVer = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    $osDisplayVersion = $ntVer.DisplayVersion   # '25H2', '24H2', etc.
    $osUBR = $ntVer.UBR                         # Update Build Revision
} catch {
    $osDisplayVersion = 'Desconocido'
    $osUBR = 0
}
$osBuildFull = "$osBuild.$osUBR"
$is25H2 = ($osDisplayVersion -eq '25H2')

# ============================================================
#region Pre-flight: Hardware Detection & System Dashboard
# ============================================================
Write-Host "`n[*] Analizando hardware del sistema..." -ForegroundColor Cyan
Write-Host "" -ForegroundColor Gray

# ================================================================
# DETECCION COMPLETA DE HARDWARE
# Cada dato se usa para tomar decisiones automaticas en secciones posteriores
# ================================================================

# --- Detección de Sistema Pre-Optimizado por ISO ---
$isIsoOptimized = $false
try {
    $cloudPol = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -ErrorAction SilentlyContinue
    $tpmBypass = Get-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassTPMCheck" -ErrorAction SilentlyContinue
    if (($cloudPol -and $cloudPol.DisableWindowsConsumerFeatures -eq 1) -or ($tpmBypass -and $tpmBypass.BypassTPMCheck -eq 1)) {
        $isIsoOptimized = $true
    }
} catch {}

# --- Plataforma: Laptop vs Desktop ---
# Metodo dual: PCSystemType (fuente primaria, Microsoft Learn) +
# Win32_Battery (confirmacion). Una UPS por USB puede reportarse
# como bateria, por eso PCSystemType prevalece en caso de conflicto.
$csys    = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$battery = Get-CimInstance Win32_Battery        -ErrorAction SilentlyContinue
$pcType  = if ($csys) { [int]$csys.PCSystemType } else { 0 }
$isLaptopByType    = ($pcType -eq 2)
$isLaptopByBattery = ($null -ne $battery)
if ($isLaptopByType -and -not $isLaptopByBattery) {
    $isLaptop = $true
    $laptopSrc = 'PCSystemType=2'
} elseif ($isLaptopByType -and $isLaptopByBattery) {
    $isLaptop = $true
    $laptopSrc = 'PCSystemType=2 + bateria'
} elseif (-not $isLaptopByType -and $isLaptopByBattery) {
    # Conflicto: probablemente UPS o AIO. PCSystemType prevalece.
    $isLaptop = $false
    $laptopSrc = 'PCSystemType=Desktop (bateria detectada, posible UPS -- tratado como Desktop)'
} else {
    $isLaptop = $false
    $laptopSrc = 'PCSystemType=Desktop'
}

# --- Modern Standby (S0ix) en Laptops ---
$hasModernStandby = $false
if ($isLaptop) {
    try {
        $powerPlatform = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlatform -ErrorAction SilentlyContinue
        if ($powerPlatform -and ($powerPlatform.AoAc -or $powerPlatform.ModernStandby)) {
            $hasModernStandby = $true
        } else {
            $aoacReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "PlatformAoAcOverride" -ErrorAction SilentlyContinue
            if ($aoacReg) { $hasModernStandby = $true }
        }
    } catch {}
}

# --- RAM total ---
$ramBytes = if ($csys) { [long]$csys.TotalPhysicalMemory } else { 0 }
$ramGiB   = [math]::Round($ramBytes / 1GB, 1)
$isLowRAM = ($ramGiB -le 4)   # <= 4 GiB = recursos limitados

# --- Disco: NVMe / SATA SSD / HDD ---
# [NEW-1] Detectamos el disco de arranque real usando IsBoot de Get-Disk
# Ref: https://learn.microsoft.com/powershell/module/storage/get-disk
$isHDD   = $false
$isNVMe  = $false
$diskBusType = 'Desconocido'
try {
    # Obtener el número de disco del boot drive de forma lógica y segura
    $bootDiskNumber = (Get-Disk -ErrorAction Stop | Where-Object IsBoot -eq $true | Select-Object -First 1).Number
    # Enlazar con PhysicalDisk para obtener MediaType y BusType
    $sysDisk = Get-PhysicalDisk -ErrorAction Stop | Where-Object DeviceId -eq $bootDiskNumber | Select-Object -First 1
    if (-not $sysDisk) {
        # Si fallase la asociación exacta por DeviceId, caer al primer disco físico como fallback
        $sysDisk = Get-PhysicalDisk -ErrorAction Stop | Sort-Object DeviceId | Select-Object -First 1
    }
    $diskBusType  = $sysDisk.BusType     # NVMe, SATA, USB, SAS, etc.
    $diskMediaRaw = $sysDisk.MediaType   # HDD, SSD, Unspecified
    $isHDD  = ($diskMediaRaw -eq 'HDD')
    $isNVMe = ($diskBusType  -eq 'NVMe')
    # Label descriptivo para el reporte
    if     ($isNVMe)              { $diskLabel = 'NVMe SSD' }
    elseif ($diskBusType -eq 'SATA' -and -not $isHDD) { $diskLabel = 'SATA SSD' }
    elseif ($isHDD)               { $diskLabel = 'HDD' }
    else                          { $diskLabel = "$diskBusType / $diskMediaRaw" }
} catch {
    # Fallback: Win32_DiskDrive (menos preciso, sin BusType confiable)
    try {
        $wmiDisk = Get-CimInstance Win32_DiskDrive -ErrorAction Stop |
                   Sort-Object Index | Select-Object -First 1
        if ($wmiDisk.Model -match 'HDD|WD[^C]|Seagate|Toshiba|Hitachi|HGST|ST[0-9]') {
            $isHDD = $true; $diskLabel = 'HDD (heuristica)'
        } elseif ($wmiDisk.Model -match 'NVMe|PCIe') {
            $isNVMe = $true; $diskLabel = 'NVMe SSD (heuristica)'
        } else {
            $diskLabel = 'SSD/Desconocido (heuristica)'
        }
    } catch {
        $diskLabel = 'Desconocido'
    }
}

# --- RAM: total y canales (single vs dual channel) ---
# [NEW-2] Contar slots de RAM ocupados para detectar single-channel.
# En iGPU + single channel, el ancho de banda de memoria se reduce hasta 40%.
# Ref: Win32_PhysicalMemory BankLabel / DeviceLocator
$ramChannels   = 0
$isSingleChannel = $false
try {
    $ramModules = Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop
    # BankLabel distingue los canales fisicos (BANK 0, BANK 1, etc.)
    $ramChannels = ($ramModules | Select-Object -ExpandProperty BankLabel -Unique).Count
    $isSingleChannel = ($ramChannels -eq 1 -and $ramModules.Count -eq 1)
} catch {
    $ramChannels = 0
}

# --- CPU: nombre, generacion, TDP estimado ---
$cpuObj   = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
$cpuName  = if ($cpuObj) { $cpuObj.Name.Trim() } else { 'Desconocido' }
$cpuCores = if ($cpuObj) { [int]$cpuObj.NumberOfCores } else { 0 }
$cpuMHz   = if ($cpuObj) { [int]$cpuObj.MaxClockSpeed } else { 0 }

# CPU moderna (timer fix SOLO beneficia a estas):
# - Intel 12th Gen+ (Alder Lake, Raptor Lake, Meteor Lake, Arrow Lake, Lunar Lake)
# - AMD Ryzen 5000+ (Zen 3, Zen 4, Zen 5)
# - Intel Core Ultra (cualquier generacion)
$isIntel12thPlus = ($cpuName -match 'Core i[0-9]-1[2-9][0-9]{3}') -or
                   ($cpuName -match 'Core i[0-9]-[2-9][0-9]{4}') -or
                   ($cpuName -match 'Core Ultra')
$isRyzen5kPlus   = ($cpuName -match 'Ryzen [0-9] [5-9][0-9]{3}') -or
                   ($cpuName -match 'Ryzen [0-9] [1-9][0-9]{4}')
$isModernCPU     = $isIntel12thPlus -or $isRyzen5kPlus

# CPU de bajos recursos (Celeron, Pentium, Atom, Ryzen 3 1xxx-3xxx, i3 1xxx-6xxx)
$isLowEndCPU = ($cpuName -match 'Celeron|Pentium|Atom|J[0-9]{4}|N[0-9]{4}') -or
               ($cpuName -match 'Ryzen 3 [1-4][0-9]{3}') -or
               ($cpuName -match 'Core i3-[1-6][0-9]{3}[^0-9]') -or
               ($cpuCores -le 2 -and $cpuMHz -le 2400)

# --- Temperatura CPU en idle (solo lectura, sin decision automatica) ---
# [NEW-3] MSAcpi_ThermalZoneTemperature en decimas de Kelvin.
# Formula: (CurrentTemperature - 2732) / 10 = Celsius.
# Solo se usa como ADVERTENCIA en laptops: temp en idle > 70 C sugiere
# throttling termico activo o pasta termica deteriorada.
# NO se usa como gate automatico (temp en idle != temp bajo carga).
# Ref: https://learn.microsoft.com/windows/win32/wmisdk/wmi-architecture
$cpuTempC    = $null
$cpuTempWarn = $false
try {
    $thermalZones = Get-CimInstance -Namespace 'root/WMI' `
                    -ClassName 'MSAcpi_ThermalZoneTemperature' -ErrorAction Stop
    if ($thermalZones) {
        # Tomar la zona primaria (primera en el array)
        $rawTemp  = ($thermalZones | Select-Object -First 1).CurrentTemperature
        $cpuTempC = [math]::Round(($rawTemp - 2732) / 10, 1)
        # Advertir si laptop en idle supera 70 C (umbral conservador)
        $cpuTempWarn = ($isLaptop -and $cpuTempC -gt 70)
    }
} catch {
    # MSAcpi no disponible en todas las plataformas (VMs, algunos OEMs) -- silencioso
    $cpuTempC = $null
}

# --- GPU: dedicada vs integrada, nombre ---
$gpuObjs  = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
$isGaming = $false
$gpuNames = @()
foreach ($g in $gpuObjs) {
    $gpuNames += $g.Name
    if ($g.Name -match 'NVIDIA|AMD Radeon [RX]|Intel Arc') { $isGaming = $true }
}
$gpuLabel = if ($gpuNames.Count -gt 0) { $gpuNames -join ' | ' } else { 'No detectada' }

# --- Perfil de equipo consolidado ---
# Usamos una etiqueta de perfil para mostrar al usuario y para tomar decisiones
if     ($isLaptop -and $isLowRAM -and $isHDD) { $hwProfile = 'NOTEBOOK LIMITADA  (HDD + <=4GB RAM)' }
elseif ($isLaptop -and $isLowRAM)             { $hwProfile = 'NOTEBOOK LIMITADA  (SSD + <=4GB RAM)' }
elseif ($isLaptop -and $isHDD)                { $hwProfile = 'NOTEBOOK HDD' }
elseif ($isLaptop -and $isGaming)             { $hwProfile = 'NOTEBOOK GAMING' }
elseif ($isLaptop)                            { $hwProfile = 'NOTEBOOK' }
elseif ($isLowRAM -and $isHDD)                { $hwProfile = 'PC ESCRITORIO LIMITADA  (HDD + <=4GB RAM)' }
elseif ($isLowRAM)                            { $hwProfile = 'PC ESCRITORIO CON POCA RAM  (<=4GB)' }
elseif ($isHDD)                               { $hwProfile = 'PC ESCRITORIO HDD' }
elseif ($isGaming)                            { $hwProfile = 'PC GAMING  (GPU dedicada)' }
else                                          { $hwProfile = 'PC ESCRITORIO' }

# ================================================================
# REPORTE DE HARDWARE DETECTADO
# ================================================================
Write-Host "  +---------------------------------------------------------+" -ForegroundColor DarkCyan
Write-Host "  |           RESUMEN DE HARDWARE DETECTADO                 |" -ForegroundColor Cyan
Write-Host "  +---------------------------------------------------------+" -ForegroundColor DarkCyan
Write-Host ("  | Perfil    : {0,-39} |" -f $hwProfile)     -ForegroundColor White
Write-Host ("  | Windows   : {0,-39} |" -f "$osDisplayVersion (Build $osBuildFull)") -ForegroundColor Gray
Write-Host ("  | Edicion   : {0,-39} |" -f ($winEdition.Substring(0,[Math]::Min($winEdition.Length,39)))) -ForegroundColor Gray
Write-Host ("  | CPU       : {0,-39} |" -f ($cpuName -replace '.{40}$','...')) -ForegroundColor Gray
Write-Host ("  | Nucleos   : {0,-39} |" -f "$cpuCores nucleos @ $cpuMHz MHz")  -ForegroundColor Gray
Write-Host ("  | RAM       : {0,-39} |" -f "$ramGiB GiB$(if($isLowRAM){' -- LIMITADA (<= 4 GiB)'})")  -ForegroundColor $(if($isLowRAM){'Yellow'} else {'Gray'})
# Construir label de disco con detalle de bus
$diskDisplayLabel = $diskLabel
if ($isHDD)  { $diskDisplayLabel += ' -- I/O lento, mantener SysMain' }
if ($isNVMe) { $diskDisplayLabel += ' -- Acceso instantaneo' }
Write-Host ("  | Disco     : {0,-39} |" -f $diskDisplayLabel.Substring(0,[Math]::Min($diskDisplayLabel.Length,39))) -ForegroundColor $(if($isHDD){'Yellow'} else {'Gray'})
Write-Host ("  | Bus Disco : {0,-39} |" -f $diskBusType) -ForegroundColor Gray
Write-Host ("  | GPU       : {0,-39} |" -f ($gpuLabel.Substring(0, [Math]::Min($gpuLabel.Length,39)))) -ForegroundColor Gray
Write-Host ("  | CPU Gen   : {0,-39} |" -f $(if($isModernCPU){'MODERNA (12th+/Ryzen5k+)'}elseif($isLowEndCPU){'LOW-END'}else{'GENERACION MEDIA'})) -ForegroundColor Gray
# Temperatura CPU (si disponible)
if ($null -ne $cpuTempC) {
    $tempLabel = "$cpuTempC C$(if($cpuTempWarn){' -- ADVERTENCIA: ALTA EN IDLE'})"
    Write-Host ("  | Temp CPU  : {0,-39} |" -f $tempLabel) -ForegroundColor $(if($cpuTempWarn){'Red'} else {'Gray'})
}
# Canal de RAM
if ($ramChannels -gt 0) {
    $chanLabel = if ($isSingleChannel) { 'SINGLE CHANNEL -- hasta 40% menos ancho de banda' } else { "$ramChannels canales (dual/multi)" }
    Write-Host ("  | RAM Canal : {0,-39} |" -f $chanLabel) -ForegroundColor $(if($isSingleChannel){'Yellow'} else {'Gray'})
}
Write-Host ("  | Tipo      : {0,-39} |" -f $laptopSrc) -ForegroundColor Gray
if ($isLaptop -and $hasModernStandby) {
    Write-Host ("  | Power Arch: {0,-39} |" -f "Modern Standby (S0 Low Power Idle)") -ForegroundColor Cyan
}
if ($isIsoOptimized) {
    Write-Host ("  | Base ISO  : {0,-39} |" -f "Pre-optimizada por OptimizedISO [OK]") -ForegroundColor Green
}
Write-Host "  +---------------------------------------------------------+" -ForegroundColor DarkCyan
Write-Host "" -ForegroundColor Gray

# Advertencias automaticas segun perfil
if ($isLowRAM) {
    Write-Host "  [AVISO] RAM <= 4 GiB detectada." -ForegroundColor Yellow
    Write-Host "    -> SysMain sera deshabilitado automaticamente (SSD) o mantenido (HDD)." -ForegroundColor Yellow
    Write-Host "    -> El script ajustara el pagefile y compresion de memoria." -ForegroundColor Yellow
}
if ($isHDD) {
    Write-Host "  [AVISO] Disco HDD detectado." -ForegroundColor Yellow
    Write-Host "    -> SysMain se MANTENDRA activo (beneficia tiempos de carga en HDD)." -ForegroundColor Yellow
    Write-Host "    -> NTFS Last Access Time y 8dot3 seran deshabilitados automaticamente." -ForegroundColor Yellow
}
if ($isNVMe) {
    Write-Host "  [INFO] NVMe detectado -- Prefetch desactivado, SysMain solo si RAM > 4 GiB." -ForegroundColor Cyan
}
if ($isLowEndCPU) {
    Write-Host "  [AVISO] CPU de bajos recursos detectada." -ForegroundColor Yellow
    Write-Host "    -> Plan Balanced activado (Ultimate Performance sobrecalienta CPUs de bajo TDP)." -ForegroundColor Yellow
    Write-Host "    -> Timer fix NO sera ofrecido (no aplica a esta CPU)." -ForegroundColor Yellow
}
if ($isModernCPU -and -not $isLaptop) {
    Write-Host "  [INFO] CPU moderna en Desktop -- Timer fix + GlobalTimerResolution disponibles." -ForegroundColor Cyan
}
if ($cpuTempWarn) {
    Write-Host "  [ADVERTENCIA] Temperatura CPU alta en idle ($cpuTempC C)." -ForegroundColor Red
    Write-Host "    -> Posible throttling termico activo o pasta termica deteriorada." -ForegroundColor Red
    Write-Host "    -> Se recomienda revisar el sistema de enfriamiento antes de aplicar tweaks." -ForegroundColor Red
}
if ($isSingleChannel -and -not $isGaming) {
    Write-Host "  [AVISO] RAM en Single Channel detectada." -ForegroundColor Yellow
    Write-Host "    -> La GPU integrada pierde hasta 40% de ancho de banda de memoria." -ForegroundColor Yellow
    Write-Host "    -> Agregar un segundo modulo de RAM al slot libre mejoraria el rendimiento grafico." -ForegroundColor Yellow
}
Write-Host "" -ForegroundColor Gray
#endregion

# ============================================================
#region Pre-flight: Winget verification (4-level fallback)
# ============================================================
Write-Host "[*] Verificando disponibilidad de Winget..." -ForegroundColor Cyan

function Install-WingetIfNeeded {
    # --- Deteccion: Ya existe winget en PATH o en ubicaciones conocidas? ---
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetCmd) {
        $searchPaths = @(
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
            "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe"
        )
        foreach ($pattern in $searchPaths) {
            $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Select-Object -Last 1
            if ($found) {
                $env:PATH += ";$($found.DirectoryName)"
                $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
                if ($wingetCmd) { break }
            }
        }
    }
    if ($wingetCmd) { return $true }

    # --- Nivel 0: RegisterByFamilyName (MS Learn oficial) ---
    Write-Host "  [!] Winget no detectado. Nivel 0: Intentando registro de App Installer..." -ForegroundColor Yellow
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
        Start-Sleep -Seconds 2
        $found = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1
        if ($found) { $env:PATH += ";$($found.DirectoryName)" }
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "  - Winget registrado con exito (RegisterByFamilyName)." -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "    Registro no disponible: $($_.Exception.Message)" -ForegroundColor DarkGray
    }

    # --- Nivel 1: Repair-WinGetPackageManager (MS Learn - PSGallery) ---
    Write-Host "  [!] Nivel 1: Intentando reparacion via Microsoft.WinGet.Client (PSGallery)..." -ForegroundColor Yellow
    try {
        Install-PackageProvider -Name NuGet -Force -ErrorAction Stop | Out-Null
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -ErrorAction Stop | Out-Null
        Repair-WinGetPackageManager -AllUsers -ErrorAction Stop
        Start-Sleep -Seconds 2
        $found = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1
        if ($found) { $env:PATH += ";$($found.DirectoryName)" }
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "  - Winget reparado con exito (Repair-WinGetPackageManager)." -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "    PSGallery no disponible: $($_.Exception.Message)" -ForegroundColor DarkGray
    }

    # --- Nivel 2: Descarga directa + Add-AppxProvisionedPackage (funciona SIN Microsoft Store) ---
    # PROBLEMA: Add-AppxPackage necesita la infraestructura de la Store para resolver licencias.
    # SOLUCION: Descargar License1.xml de GitHub y usar Add-AppxProvisionedPackage que
    # instala el paquete a nivel de sistema operativo, sin depender de la Store.
    # Ref: https://github.com/microsoft/winget-cli/releases (cada release incluye License1.xml)
    Write-Host "  [!] Nivel 2: Descargando desde fuentes oficiales de Microsoft..." -ForegroundColor Yellow
    try {
        # TLS ya forzado globalmente al inicio del script (FIX-PS51-1)
        $tempDir = Join-Path $env:TEMP "WingetInstall"
        if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }

        $bundlePath  = Join-Path $tempDir "DesktopAppInstaller.msixbundle"
        $licensePath = Join-Path $tempDir "License1.xml"

        # Siempre usar GitHub API para obtener bundle + licencia (aka.ms no provee License1.xml)
        $downloadOk  = $false
        $licenseOk   = $false
        $ghRelease   = $null

        # Intentar GitHub API primero (necesitamos License1.xml que aka.ms no provee)
        try {
            $apiUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
            $ghRelease = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "PowerShell-SetupScript" } -ErrorAction Stop

            # Descargar msixbundle
            $bundleAsset = $ghRelease.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1
            if ($bundleAsset) {
                # FIX-PS51-3: -UseBasicParsing evita el error "IE engine not available" en PS 5.1
                Invoke-WebRequest -Uri $bundleAsset.browser_download_url -OutFile $bundlePath -UseBasicParsing -ErrorAction Stop
                $downloadOk = $true
                Write-Host "    Bundle descargado via GitHub API" -ForegroundColor Gray
            }

            # Descargar License1.xml (asset del release, requerido para Add-AppxProvisionedPackage)
            $licenseAsset = $ghRelease.assets | Where-Object { $_.name -like "*License*.xml" } | Select-Object -First 1
            if ($licenseAsset) {
                Invoke-WebRequest -Uri $licenseAsset.browser_download_url -OutFile $licensePath -UseBasicParsing -ErrorAction Stop
                $licenseOk = $true
                Write-Host "    License1.xml descargado via GitHub API" -ForegroundColor Gray
            }
        } catch {
            Write-Host "    GitHub API fallo: $($_.Exception.Message)" -ForegroundColor DarkGray
        }

        # Fallback: aka.ms para el bundle si GitHub fallo (licencia no disponible por esta via)
        if (-not $downloadOk) {
            try {
                Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile $bundlePath -UseBasicParsing -ErrorAction Stop
                $downloadOk = $true
                Write-Host "    Bundle descargado via aka.ms/getwinget" -ForegroundColor Gray
            } catch {
                Write-Host "    aka.ms tampoco disponible: $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        }

        if ($downloadOk) {
            # Descargar dependencias
            Write-Host "    Descargando dependencias (VCLibs y UI.Xaml)..." -ForegroundColor Gray
            $vcLibsPath = Join-Path $tempDir "VCLibs.appx"
            Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile $vcLibsPath -UseBasicParsing -ErrorAction SilentlyContinue
            $uiXamlPath = Join-Path $tempDir "UIXaml.appx"
            Invoke-WebRequest -Uri "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx" -OutFile $uiXamlPath -UseBasicParsing -ErrorAction SilentlyContinue

            # Instalar dependencias primero (ambos metodos las necesitan)
            Write-Host "    Instalando dependencias..." -ForegroundColor Gray
            if (Test-Path $vcLibsPath) { Add-AppxPackage -Path $vcLibsPath -ErrorAction SilentlyContinue }
            if (Test-Path $uiXamlPath) { Add-AppxPackage -Path $uiXamlPath -ErrorAction SilentlyContinue }

            $installed = $false

            # METODO A: Add-AppxProvisionedPackage (NO necesita Microsoft Store)
            # Instala el paquete a nivel de imagen del SO, funciona en LTSC, debloated, sin Store.
            if ($licenseOk -and (Test-Path $licensePath)) {
                Write-Host "    Metodo A: Add-AppxProvisionedPackage (sin necesidad de Store)..." -ForegroundColor Gray
                try {
                    # Construir lista de dependencias para el parametro -DependencyPackagePath
                    $depPaths = @()
                    if (Test-Path $vcLibsPath) { $depPaths += $vcLibsPath }
                    if (Test-Path $uiXamlPath) { $depPaths += $uiXamlPath }

                    $provParams = @{
                        Online      = $true
                        PackagePath = $bundlePath
                        LicensePath = $licensePath
                    }
                    if ($depPaths.Count -gt 0) { $provParams['DependencyPackagePath'] = $depPaths }

                    Add-AppxProvisionedPackage @provParams -ErrorAction Stop | Out-Null
                    Write-Host "    Provisionado OK. Registrando para el usuario actual..." -ForegroundColor Gray

                    # Despues de provisionar, registrar para el usuario actual
                    Start-Sleep -Seconds 3
                    $manifest = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\AppxManifest.xml" -ErrorAction SilentlyContinue | Select-Object -Last 1
                    if ($manifest) {
                        Add-AppxPackage -DisableDevelopmentMode -Register $manifest.FullName -ErrorAction SilentlyContinue
                    }
                    $installed = $true
                } catch {
                    Write-Host "    Metodo A fallo: $($_.Exception.Message)" -ForegroundColor DarkGray
                }
            }

            # METODO B: Add-AppxPackage directo (fallback, requiere infraestructura de Store)
            if (-not $installed) {
                Write-Host "    Metodo B: Add-AppxPackage directo (fallback)..." -ForegroundColor Gray
                try {
                    Add-AppxPackage -Path $bundlePath -ErrorAction Stop
                    $installed = $true
                } catch {
                    Write-Host "    Metodo B fallo: $($_.Exception.Message)" -ForegroundColor DarkGray
                }
            }

            # METODO C: ForceApplicationShutdown + Add-AppxPackage (si hay version vieja corrupta)
            if (-not $installed) {
                Write-Host "    Metodo C: Add-AppxPackage con ForceApplicationShutdown..." -ForegroundColor Gray
                try {
                    Add-AppxPackage -Path $bundlePath -ForceApplicationShutdown -ErrorAction Stop
                    $installed = $true
                } catch {
                    Write-Host "    Metodo C fallo: $($_.Exception.Message)" -ForegroundColor DarkGray
                }
            }

            if ($installed) {
                # Actualizar PATH
                Start-Sleep -Seconds 2
                $newWinget = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1
                if ($newWinget) { $env:PATH += ";$($newWinget.DirectoryName)" }
                # Tambien agregar WindowsApps al PATH (a veces winget queda registrado ahi)
                $winAppsPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
                if ($env:PATH -notmatch [regex]::Escape($winAppsPath)) { $env:PATH += ";$winAppsPath" }

                if (Get-Command winget -ErrorAction SilentlyContinue) {
                    Write-Host "  - Winget instalado con exito (descarga directa)." -ForegroundColor Green
                    return $true
                }
            }
        }
    } catch {
        Write-Host "    Nivel 2 fallido: $($_.Exception.Message)" -ForegroundColor DarkGray
    }

    # --- Nivel 3: Degradacion graciosa ---
    Write-Host "  [X] No se pudo obtener Winget. Las secciones que lo requieren seran omitidas." -ForegroundColor Red
    Write-Host "      Instala 'App Installer' desde la Microsoft Store o manualmente." -ForegroundColor Yellow
    return $false
}

$script:HasWinget = Install-WingetIfNeeded

# Mostrar estado de Winget en el dashboard
$wingetStatus = if ($script:HasWinget) {
    $wVer = try { (winget --version 2>$null) } catch { '?' }
    "Disponible ($wVer)"
} else { 'NO DISPONIBLE -- Secciones 0 y 2 seran limitadas' }
Write-Host ("  | Winget    : {0,-39} |" -f $wingetStatus) -ForegroundColor $(if($script:HasWinget){'Green'}else{'Red'})
Write-Host "" -ForegroundColor Gray
#endregion

# ============================================================
#region Pre-flight: Health Check - Prerrequisitos esenciales
# ============================================================
Write-Host "[*] Verificando prerrequisitos esenciales del sistema..." -ForegroundColor Cyan

$prerequisites = @()

# 1. Visual C++ 2015-2022 x64
$vcx64 = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64' -ErrorAction SilentlyContinue
$vcx64Installed = ($null -ne $vcx64 -and $vcx64.Installed -eq 1)
$vcx64Ver = if ($vcx64Installed) { "$($vcx64.Major).$($vcx64.Minor).$($vcx64.Bld)" } else { 'NO INSTALADO' }
$prerequisites += [PSCustomObject]@{
    Componente = 'Visual C++ 2015-2022 (x64)'
    Estado     = if ($vcx64Installed) { "OK ($vcx64Ver)" } else { 'FALTA' }
    Instalado  = $vcx64Installed
    WingetId   = 'Microsoft.VCRedist.2015+.x64'
    Critico    = $true
    Nota       = 'Requerido por el 95% de juegos y apps nativas (MSVCP140.dll)'
}

# 2. Visual C++ 2015-2022 x86
$vcx86 = Get-ItemProperty 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86' -ErrorAction SilentlyContinue
$vcx86Installed = ($null -ne $vcx86 -and $vcx86.Installed -eq 1)
$vcx86Ver = if ($vcx86Installed) { "$($vcx86.Major).$($vcx86.Minor).$($vcx86.Bld)" } else { 'NO INSTALADO' }
$prerequisites += [PSCustomObject]@{
    Componente = 'Visual C++ 2015-2022 (x86)'
    Estado     = if ($vcx86Installed) { "OK ($vcx86Ver)" } else { 'FALTA' }
    Instalado  = $vcx86Installed
    WingetId   = 'Microsoft.VCRedist.2015+.x86'
    Critico    = $true
    Nota       = 'Necesario para juegos de 32 bits (Steam tiene muchos)'
}

# 3. .NET Desktop Runtime 8.0
$dotnetRuntimes = try { & dotnet --list-runtimes 2>$null } catch { @() }
$hasNet8 = $dotnetRuntimes | Where-Object { $_ -match 'Microsoft\.WindowsDesktop\.App 8\.' }
$prerequisites += [PSCustomObject]@{
    Componente = '.NET Desktop Runtime 8.0'
    Estado     = if ($hasNet8) { 'OK' } else { 'FALTA' }
    Instalado  = [bool]$hasNet8
    WingetId   = 'Microsoft.DotNet.DesktopRuntime.8'
    Critico    = $false
    Nota       = 'Launchers y herramientas modernas (recomendado)'
}

# 4. .NET Desktop Runtime 9.0
$hasNet9 = $dotnetRuntimes | Where-Object { $_ -match 'Microsoft\.WindowsDesktop\.App 9\.' }
$prerequisites += [PSCustomObject]@{
    Componente = '.NET Desktop Runtime 9.0'
    Estado     = if ($hasNet9) { 'OK' } else { 'FALTA' }
    Instalado  = [bool]$hasNet9
    WingetId   = 'Microsoft.DotNet.DesktopRuntime.9'
    Critico    = $false
    Nota       = 'Apps recientes que requieren .NET 9'
}

# 5. WebView2
$wv2 = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' -ErrorAction SilentlyContinue
$wv2Installed = ($null -ne $wv2 -and $wv2.pv)
$prerequisites += [PSCustomObject]@{
    Componente = 'Microsoft Edge WebView2 Runtime'
    Estado     = if ($wv2Installed) { "OK ($($wv2.pv))" } else { 'FALTA' }
    Instalado  = [bool]$wv2Installed
    WingetId   = 'Microsoft.EdgeWebView2Runtime'
    Critico    = $false
    Nota       = 'Discord, Spotify, Epic Launcher y apps Electron lo necesitan'
}

# 6. DirectX Legacy (d3dx9_43.dll)
$dxLegacy = Test-Path "$env:SystemRoot\System32\d3dx9_43.dll"
$prerequisites += [PSCustomObject]@{
    Componente = 'DirectX 9 End-User Runtime (Legacy)'
    Estado     = if ($dxLegacy) { 'OK' } else { 'FALTA' }
    Instalado  = $dxLegacy
    WingetId   = $null  # No disponible en winget, descarga directa
    Critico    = $false
    Nota       = 'Juegos legacy con DirectX 9 (CS 1.6, Half-Life 2, etc.)'
}

# 7. .NET Framework 3.5
# [FIX-PS7] Get-WindowsOptionalFeature falla en PS7 con "Clase no registrada" (COMException).
#   Fallback a DISM.exe si el cmdlet no funciona. Ref: GitHub PowerShell #17232
$netfx3 = try {
    Get-WindowsOptionalFeature -Online -FeatureName NetFx3 -ErrorAction Stop
} catch {
    $dismOut = & DISM.exe /Online /Get-FeatureInfo /FeatureName:NetFx3 2>&1
    if ($dismOut -match 'State\s*:\s*Enabled|Estado\s*:\s*Habilitad') {
        [PSCustomObject]@{ State = 'Enabled' }
    } else {
        [PSCustomObject]@{ State = 'Disabled' }
    }
}
$netfx3Installed = ($netfx3 -and $netfx3.State -eq 'Enabled')
$prerequisites += [PSCustomObject]@{
    Componente = '.NET Framework 3.5 (Feature)'
    Estado     = if ($netfx3Installed) { 'OK' } else { 'FALTA' }
    Instalado  = $netfx3Installed
    WingetId   = $null  # Se instala via DISM
    Critico    = $false
    Nota       = 'Apps legacy, herramientas de modding, juegos indie clasicos'
}

# Mostrar tabla de salud
Write-Host "  +---------------------------------------------------------+" -ForegroundColor DarkCyan
Write-Host "  |           PRERREQUISITOS DEL SISTEMA                    |" -ForegroundColor Cyan
Write-Host "  +---------------------------------------------------------+" -ForegroundColor DarkCyan
foreach ($p in $prerequisites) {
    $statusText = $p.Estado
    $color = if ($p.Instalado) { 'Gray' } elseif ($p.Critico) { 'Red' } else { 'Yellow' }
    $label = $p.Componente
    Write-Host ("  | {0,-24}: {1,-27} |" -f $label.Substring(0,[Math]::Min($label.Length,24)), $statusText.Substring(0,[Math]::Min($statusText.Length,27))) -ForegroundColor $color
}
$critOk = ($prerequisites | Where-Object { $_.Critico -and $_.Instalado }).Count
$critTotal = ($prerequisites | Where-Object { $_.Critico }).Count
$missingCount = ($prerequisites | Where-Object { -not $_.Instalado }).Count
Write-Host ("  | {0,-52} |" -f "$critOk/$critTotal criticos OK | $missingCount faltante(s)") -ForegroundColor $(if($missingCount -gt 0){'Yellow'}else{'Green'})
Write-Host "  +---------------------------------------------------------+" -ForegroundColor DarkCyan
Write-Host "" -ForegroundColor Gray
#endregion

# ============================================================
#region Pre-flight: Pausa para revision del dashboard
# ============================================================
if (-not $Unattended) {
    Write-Host "  Revisa la informacion de hardware y prerrequisitos arriba." -ForegroundColor Yellow
    Write-Host "  Perfil detectado: $hwProfile" -ForegroundColor Yellow
    if (-not $script:HasWinget) {
        Write-Host "  [!] Winget NO disponible: secciones de instalacion/desinstalacion seran limitadas." -ForegroundColor Red
    }
    if ($missingCount -gt 0) {
        Write-Host "  [!] $missingCount prerrequisito(s) faltante(s). Se ofreceran para instalar a continuacion." -ForegroundColor Yellow
    }
    Read-Host "  Presiona ENTER para continuar con los menus de seleccion"
}
#endregion

# ============================================================
#region 0.A Prerequisites installation
# ============================================================
$missingPrereqs = $prerequisites | Where-Object { -not $_.Instalado }

if ($missingPrereqs.Count -gt 0) {
    Write-Host "`n[0.A] Prerrequisitos esenciales faltantes detectados..." -ForegroundColor Cyan

    $selectedPrereqs = $null
    if ($Unattended) {
        # Modo desatendido: instalar todos los faltantes automaticamente
        $selectedPrereqs = $missingPrereqs
        Write-Host "  Modo desatendido: instalando todos los prerrequisitos faltantes..." -ForegroundColor Gray
    } else {
        # FIX-PS51-4: Out-GridView requiere el modulo Microsoft.PowerShell.Utility con WPF disponible.
        # Puede fallar si la sesion es remota o el entorno grafico no esta listo. Fallback a consola.
        $ogvAvailable = $null -ne (Get-Command Out-GridView -ErrorAction SilentlyContinue)
        if ($ogvAvailable) {
            try {
                $selectedPrereqs = $missingPrereqs |
                    Select-Object Componente, Estado, Nota, Critico, WingetId |
                    Out-GridView -Title "Prerrequisitos FALTANTES -- Selecciona los que deseas instalar (recomendado: todos)" -PassThru
            } catch {
                Write-Host "  [!] Out-GridView no disponible ($($_.Exception.Message)). Instalando todos los faltantes..." -ForegroundColor Yellow
                $selectedPrereqs = $missingPrereqs
            }
        } else {
            Write-Host "  [!] Out-GridView no disponible en esta sesion. Instalando todos los prerrequisitos faltantes automaticamente..." -ForegroundColor Yellow
            $selectedPrereqs = $missingPrereqs
        }
    }

    if ($selectedPrereqs) {
        foreach ($prereq in $selectedPrereqs) {
            Write-Host "  Instalando $($prereq.Componente)..." -ForegroundColor Gray

            if ($prereq.WingetId -and $script:HasWinget) {
                # Instalar via winget
                winget install --id $prereq.WingetId --exact --silent `
                    --accept-package-agreements --accept-source-agreements --disable-interactivity
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    OK: $($prereq.Componente)" -ForegroundColor Green
                } else {
                    Write-Host "    ! Exit $LASTEXITCODE para $($prereq.Componente) (puede que ya este instalado)" -ForegroundColor Yellow
                }
            } elseif ($prereq.WingetId -and -not $script:HasWinget) {
                Write-Host "    ! Requiere Winget (no disponible): $($prereq.Componente)" -ForegroundColor Red
            } elseif ($prereq.Componente -match 'DirectX.*Legacy') {
                # DirectX Legacy: descarga directa desde Microsoft
                try {
                    $dxUrl = "https://download.microsoft.com/download/1/7/1/1718CCC4-6315-4D8E-9543-8E28A4E18C4C/dxwebsetup.exe"
                    $dxPath = Join-Path $env:TEMP "dxwebsetup.exe"
                    Invoke-WebRequest -Uri $dxUrl -OutFile $dxPath -UseBasicParsing -ErrorAction Stop
                    Start-Process -FilePath $dxPath -ArgumentList '/Q' -Wait
                    Write-Host "    OK: DirectX Legacy Runtime" -ForegroundColor Green
                } catch {
                    Write-Host "    ! DirectX Legacy: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            } elseif ($prereq.Componente -match '\.NET Framework 3\.5') {
                # .NET 3.5: via DISM (no necesita winget)
                # [FIX-PS7] Enable-WindowsOptionalFeature falla en PS7. Fallback a DISM.exe
                try {
                    Enable-WindowsOptionalFeature -Online -FeatureName NetFx3 -All -NoRestart -ErrorAction Stop
                    Write-Host "    OK: .NET Framework 3.5 habilitado" -ForegroundColor Green
                } catch {
                    Write-Host "    Cmdlet fallo (PS7?). Intentando via DISM.exe..." -ForegroundColor DarkGray
                    $dismResult = & DISM.exe /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "    OK: .NET Framework 3.5 habilitado (via DISM.exe)" -ForegroundColor Green
                    } else {
                        Write-Host "    ! .NET 3.5: DISM exit $LASTEXITCODE" -ForegroundColor Yellow
                    }
                }
            }
        }
    } else {
        Write-Host "  - Sin seleccion. Omitiendo prerrequisitos." -ForegroundColor Gray
    }
} else {
    Write-Host "`n[0.A] Todos los prerrequisitos esenciales estan instalados." -ForegroundColor Green
}
#endregion

# ============================================================
#region 0.B Install applications (winget)
# ============================================================
Write-Host "`n[0.B] Installing applications via winget..." -ForegroundColor Cyan

$appsList = @(
    [PSCustomObject]@{ Id='Brave.Brave';        Name='Brave Browser';       Note='Navegador rapido enfocado en privacidad' },
    [PSCustomObject]@{ Id='Nilesoft.Shell';     Name='Nilesoft Shell';      Note='Personalizador avanzado del menu contextual de Windows' },
    [PSCustomObject]@{ Id='Notepad++.Notepad++';Name='Notepad++';           Note='Editor de texto y codigo ligero y potente' },
    [PSCustomObject]@{ Id='FastStone.Viewer';   Name='FastStone Image Viewer'; Note='Visualizador de imagenes rapido y completo' },
    [PSCustomObject]@{ Id='MPC-BE.MPC-BE';      Name='MPC-BE Player';       Note='Reproductor de video ultra-ligero y rapido' }
)

$selectedApps = $null
if ($Unattended) {
    # Modo desatendido: instalar todas las aplicaciones por defecto
    $selectedApps = $appsList
    Write-Host "  Modo desatendido activo: instalando todas las aplicaciones por defecto..." -ForegroundColor Gray
} else {
    $ogvAvailable = $null -ne (Get-Command Out-GridView -ErrorAction SilentlyContinue)
    if ($ogvAvailable) {
        try {
            $selectedApps = $appsList | Out-GridView -Title "Selecciona las aplicaciones a INSTALAR (Ctrl para varios) -- Cancelar para no instalar ninguna" -PassThru
        } catch {
            Write-Host "  [!] Out-GridView no disponible. Usa el parametro -Unattended para instalar todas, o edita \$appsList." -ForegroundColor Yellow
            $selectedApps = $null
        }
    } else {
        Write-Host "  [!] Out-GridView no disponible en esta sesion. Omitiendo instalacion de apps. Usa -Unattended para auto-instalar." -ForegroundColor Yellow
        $selectedApps = $null
    }
}

if ($selectedApps) {
    if ($script:HasWinget) {
        Write-Host "  Actualizando fuentes de winget..." -ForegroundColor Gray
        winget source update --silent
        Write-Host "  Procesando $($selectedApps.Count) aplicaciones..." -ForegroundColor Cyan
        foreach ($app in $selectedApps) {
            Write-Host "  Instalando $($app.Name) ($($app.Id))..." -ForegroundColor Gray
            winget install --id $app.Id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
            if ($LASTEXITCODE -eq 0) { Write-Host "  - Instalado: $($app.Name)" -ForegroundColor Green }
            else { Write-Host "  ! winget exit $LASTEXITCODE para $($app.Id) (puede que ya este instalado)" -ForegroundColor Yellow }
        }
    } else {
        Write-Host "  ! Omitiendo instalacion de aplicaciones debido a que Winget no esta disponible." -ForegroundColor Red
    }
} else {
    Write-Host "  - Omitiendo instalacion de aplicaciones." -ForegroundColor Gray
}
#endregion

# ============================================================
#region 1. Remove bloatware Appx apps (Interactive)
# ============================================================
Write-Host "`n[1] Analizando aplicaciones AppX / Bloatware..." -ForegroundColor Cyan

$bloatwareList = @(
    [PSCustomObject]@{ Name='Clipchamp.Clipchamp';                    Note='Editor de video de Microsoft' },
    [PSCustomObject]@{ Name='Microsoft.BingNews';                     Note='Noticias Bing' },
    [PSCustomObject]@{ Name='Microsoft.BingSearch';                   Note='Busqueda Bing integrada' },
    [PSCustomObject]@{ Name='Microsoft.BingWeather';                  Note='Widget del tiempo Bing' },
    [PSCustomObject]@{ Name='Microsoft.GamingApp';                    Note='Xbox Game Pass / Gaming overlay' },
    [PSCustomObject]@{ Name='Microsoft.GetHelp';                      Note='App de soporte de Microsoft' },
    [PSCustomObject]@{ Name='Microsoft.MicrosoftOfficeHub';           Note='Hub de Office / publicidad' },
    [PSCustomObject]@{ Name='Microsoft.MicrosoftSolitaireCollection'; Note='Solitario y juegos de cartas' },
    [PSCustomObject]@{ Name='Microsoft.MicrosoftStickyNotes';         Note='Notas adhesivas' },
    [PSCustomObject]@{ Name='Microsoft.Paint';                        Note='Paint clasico [omitir si lo usas]' },
    [PSCustomObject]@{ Name='Microsoft.PowerAutomateDesktop';         Note='Automatizacion de flujos de trabajo' },
    [PSCustomObject]@{ Name='Microsoft.ScreenSketch';                 Note='Recorte y anotacion (Snip & Sketch)' },
    [PSCustomObject]@{ Name='Microsoft.StorePurchaseApp';             Note='Componente de compras de la Store' },
    [PSCustomObject]@{ Name='Microsoft.Todos';                        Note='Microsoft To Do' },
    [PSCustomObject]@{ Name='Microsoft.Windows.DevHome';              Note='Dev Home dashboard' },
    [PSCustomObject]@{ Name='Microsoft.Windows.Photos';               Note='Visor de fotos moderno' },
    [PSCustomObject]@{ Name='Microsoft.WindowsAlarms';                Note='Alarmas y reloj' },
    [PSCustomObject]@{ Name='Microsoft.WindowsCamera';                Note='App de camara' },
    [PSCustomObject]@{ Name='Microsoft.WindowsFeedbackHub';           Note='Hub de comentarios a Microsoft' },
    [PSCustomObject]@{ Name='Microsoft.WindowsSoundRecorder';         Note='Grabadora de sonidos' },
    [PSCustomObject]@{ Name='Microsoft.WindowsStore';                 Note='[!] Store -- rompe actualizacion de drivers si la eliminas' },
    [PSCustomObject]@{ Name='Microsoft.Xbox.TCUI';                    Note='UI de Xbox Live' },
    [PSCustomObject]@{ Name='Microsoft.XboxGameOverlay';              Note='Game overlay de Xbox' },
    [PSCustomObject]@{ Name='Microsoft.XboxGamingOverlay';            Note='Xbox Game Bar' },
    [PSCustomObject]@{ Name='Microsoft.XboxIdentityProvider';         Note='Proveedor de identidad Xbox' },
    [PSCustomObject]@{ Name='Microsoft.XboxSpeechToTextOverlay';      Note='Reconocimiento de voz Xbox' },
    [PSCustomObject]@{ Name='Microsoft.YourPhone';                    Note='Phone Link (antes Your Phone)' },
    [PSCustomObject]@{ Name='Microsoft.ZuneMusic';                    Note='Groove Music / Media Player moderno' },
    [PSCustomObject]@{ Name='Microsoft.ZuneVideo';                    Note='Movies & TV' },
    [PSCustomObject]@{ Name='MicrosoftCorporationII.QuickAssist';     Note='Asistencia remota de Microsoft' },
    [PSCustomObject]@{ Name='MicrosoftWindows.CrossDevice';           Note='Continuidad entre dispositivos' },
    [PSCustomObject]@{ Name='Microsoft.549981C3F5F10';                Note='Cortana' },
    [PSCustomObject]@{ Name='Microsoft.People';                       Note='App Contactos' },
    [PSCustomObject]@{ Name='Microsoft.WindowsMaps';                  Note='Mapas de Windows' },
    [PSCustomObject]@{ Name='microsoft.windowscommunicationsapps';    Note='Correo y Calendario clasicos' },
    [PSCustomObject]@{ Name='Microsoft.OutlookForWindows';            Note='Nuevo Outlook (app)' },
    [PSCustomObject]@{ Name='Microsoft.MicrosoftJournal';             Note='Journal (notas con lapiz)' },
    [PSCustomObject]@{ Name='MSTeams';                                Note='Microsoft Teams (version moderna)' },
    [PSCustomObject]@{ Name='MicrosoftTeams';                         Note='Microsoft Teams (version clasica)' },
    [PSCustomObject]@{ Name='Microsoft.Copilot';                      Note='Copilot (asistente IA)' },
    [PSCustomObject]@{ Name='Microsoft.Windows.Ai.Copilot.Provider';   Note='Copilot AI backend provider (25H2)' },
    [PSCustomObject]@{ Name='MicrosoftWindows.Client.WebExperience';   Note='Widgets backend (consume RAM en background)' }
)

# -----------------------------------------------------------------------
# Verificación Rápida y Diferencial en Memoria:
# Si la ISO ya eliminó los paquetes offline, evitamos 42 llamadas secuenciales.
# -----------------------------------------------------------------------
Write-Host "  Consultando paquetes instalados y provisionados en el sistema..." -ForegroundColor Gray

$installedPkgs = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue)
$installedNames = $installedPkgs | ForEach-Object { $_.Name }

$dismProvOutput = & DISM.exe /Online /Get-ProvisionedAppxPackages 2>&1
$provisionedPackages = @($dismProvOutput |
    Where-Object { $_ -match '^\s*PackageName\s*:' } |
    ForEach-Object { ($_ -split ':', 2)[1].Trim() })

# Filtrar solo las apps de la lista que realmente sigan presentes en el sistema
$presentBloatware = $bloatwareList | Where-Object {
    $appName = $_.Name
    ($installedNames -like "*$appName*") -or ($provisionedPackages -like "*$appName*")
}

if ($presentBloatware.Count -eq 0) {
    Write-Host "  [✓] Sistema limpio: No se detectaron paquetes bloatware activos (ya eliminados por la ISO o desinstalados previamente)." -ForegroundColor Green
} else {
    Write-Host "  Detectadas $($presentBloatware.Count) aplicaciones residuales para evaluar." -ForegroundColor Yellow

    if (-not $Unattended) {
        Write-Host "  Abriendo ventana de seleccion para Bloatware..." -ForegroundColor Yellow
        $ogvAvailable = $null -ne (Get-Command Out-GridView -ErrorAction SilentlyContinue)
        if ($ogvAvailable) {
            try {
                $selectedApps = $presentBloatware | Out-GridView -Title "Selecciona las apps Appx a eliminar (Ctrl para elegir varias) -- Lee Note antes de marcar [!]" -PassThru
            } catch {
                Write-Host "  [!] Out-GridView no disponible. Eliminar TODO el bloatware detectado automaticamente..." -ForegroundColor Yellow
                $selectedApps = $presentBloatware
            }
        } else {
            Write-Host "  [!] Out-GridView no disponible. Eliminando TODO el bloatware detectado..." -ForegroundColor Yellow
            $selectedApps = $presentBloatware
        }
    } else {
        Write-Host "  Modo desatendido: seleccionando todo el bloatware residual excepto aplicaciones criticas (!)..." -ForegroundColor Gray
        $selectedApps = $presentBloatware | Where-Object { $_.Note -notmatch '\[!\]' }
    }

    if ($selectedApps) {
        Write-Host "  $($selectedApps.Count) aplicaciones seleccionadas para eliminar." -ForegroundColor Cyan

        foreach ($entry in $selectedApps) {
            $appName = $entry.Name

            # --- Paso 1: Eliminar para todos los usuarios ya instalados ---
            $pkgs = $installedPkgs | Where-Object { $_.Name -like "*$appName*" }
            if ($pkgs) {
                foreach ($pkg in $pkgs) {
                    try {
                        $pkg | Remove-AppxPackage -AllUsers -ErrorAction Stop
                        Write-Host "  - Removed (installed): $appName" -ForegroundColor Green
                    } catch {
                        Write-Host "  ! Could not remove $appName : $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
            }

            # --- Paso 2: Eliminar el paquete provisionado via DISM.exe ---
            $matchedProvPackages = $provisionedPackages | Where-Object { $_ -like "*$appName*" }
            if ($matchedProvPackages) {
                foreach ($pkgFullName in $matchedProvPackages) {
                    Write-Host "  - Removing provisioned: $pkgFullName" -ForegroundColor Gray
                    $dismRemove = & DISM.exe /Online /Remove-ProvisionedAppxPackage /PackageName:$pkgFullName 2>&1
                    if ($LASTEXITCODE -in @(0, 1641, 3010)) {
                        Write-Host "  - Removed (provisioned): $appName" -ForegroundColor DarkGreen
                    } else {
                        Write-Host "  ! DISM /Remove-ProvisionedAppxPackage exit $LASTEXITCODE para: $pkgFullName" -ForegroundColor Yellow
                    }
                }
            }
        }
    } else {
        Write-Host "  - Sin seleccion. Omitiendo." -ForegroundColor Gray
    }
}
#endregion

# ============================================================
#region 2. Remove Win32 applications (Interactive)
# ============================================================
Write-Host "`n[2] Removing Win32 applications..." -ForegroundColor Cyan
$win32List = @(
    [PSCustomObject]@{ Id='Microsoft.OneDrive'; Name='Microsoft OneDrive';             Reason='Sync en background -- consume RAM, CPU e I/O constante' },
    [PSCustomObject]@{ Id='Microsoft.Teams';    Name='Microsoft Teams (Machine-Wide)'; Reason='~300-400 MB RAM minimo, proceso siempre activo' },
    [PSCustomObject]@{ Id='Microsoft.Skype';    Name='Skype';                          Reason='App de videollamadas clasica -- innecesaria si no la usas' }
)

if (-not $Unattended) {
    $ogvAvailable = $null -ne (Get-Command Out-GridView -ErrorAction SilentlyContinue)
    if ($ogvAvailable) {
        try {
            $selectedWin32 = $win32List | Out-GridView -Title "Selecciona las apps Win32 a DESINSTALAR (Ctrl para elegir varias)" -PassThru
        } catch {
            Write-Host "  [!] Out-GridView no disponible. Omitiendo desinstalacion de Win32 (ejecuta con -Unattended para auto-desinstalar)." -ForegroundColor Yellow
            $selectedWin32 = $null
        }
    } else {
        Write-Host "  [!] Out-GridView no disponible en esta sesion. Omitiendo Apps Win32 (usa -Unattended)." -ForegroundColor Yellow
        $selectedWin32 = $null
    }
} else {
    Write-Host "  Modo desatendido: seleccionando todas las apps Win32 (OneDrive, Teams, Skype)..." -ForegroundColor Gray
    $selectedWin32 = $win32List
}

if ($selectedWin32) {
    if (-not $script:HasWinget) {
        Write-Host "  [!] Winget no disponible. No se pueden desinstalar apps Win32 via winget." -ForegroundColor Red
        Write-Host "      Desinstalalas manualmente desde Configuracion > Aplicaciones." -ForegroundColor Yellow
    } else {
        foreach ($app in $selectedWin32) {
            Write-Host "  - Intentando desinstalar $($app.Name)..." -ForegroundColor Gray
            if ($app.Id -eq 'Microsoft.OneDrive') {
                Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
            winget uninstall --id $($app.Id) --silent --accept-source-agreements --disable-interactivity | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Host "    Desinstalado: $($app.Name)" -ForegroundColor Green }
            else { Write-Host "    ! Exit $LASTEXITCODE para $($app.Name) (puede ya estar desinstalado)" -ForegroundColor Yellow }
        }
    }
} else {
    Write-Host "  - Sin seleccion. Omitiendo." -ForegroundColor Gray
}
#endregion

# ============================================================
#region 3. Dark mode + dark wallpaper
# ============================================================
$applyDark = $true
if (-not $Unattended) {
    $choice = Read-Host "`n[3] ¿Desea aplicar el Tema Oscuro y el fondo de pantalla oscuro? [Y/N] (Default: Y)"
    if ($choice -ne '' -and $choice -notmatch '^[yYsS]') {
        $applyDark = $false
    }
}

if ($applyDark) {
    Write-Host "`n[3] Enabling dark mode + dark wallpaper..." -ForegroundColor Cyan
    $theme = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-Reg $theme 'AppsUseLightTheme'   0
    Set-Reg $theme 'SystemUsesLightTheme' 0
    Set-Reg $theme 'EnableTransparency'   1

    $darkWall = 'C:\Windows\Web\Wallpaper\Windows\img19.jpg'
    if (Test-Path $darkWall) {
        Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallPaper      -Value $darkWall
        Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value 10
        Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name TileWallpaper  -Value 0
        if (-not ('WpApply' -as [type])) {
            Add-Type @"
using System.Runtime.InteropServices;
public class WpApply { [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)] public static extern bool SystemParametersInfo(int a,int b,string c,int d); }
"@
        }
        [WpApply]::SystemParametersInfo(20, 0, $darkWall, 3) | Out-Null
        Write-Host "  - Dark wallpaper applied." -ForegroundColor Green
    } else {
        Write-Host "  ! Wallpaper no encontrado en $darkWall" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n[3] Omitiendo configuracion estetica de Tema Oscuro / Fondo." -ForegroundColor Gray
}
#endregion

# ============================================================
#region 4. Taskbar
# ============================================================
$applyTaskbar = $true
if (-not $Unattended) {
    $choice = Read-Host "`n[4] ¿Desea optimizar la Barra de Tareas? (Alinear a la izquierda, ocultar widgets y pin del Explorador) [Y/N] (Default: Y)"
    if ($choice -ne '' -and $choice -notmatch '^[yYsS]') {
        $applyTaskbar = $false
    }
}

if ($applyTaskbar) {
    Write-Host "`n[4] Configuring taskbar..." -ForegroundColor Cyan
    # $adv definido globalmente al inicio del script
    Set-Reg $adv 'TaskbarAl'          0   # alinear izquierda
    Set-Reg $adv 'ShowTaskViewButton' 0   # ocultar Task View
    Set-Reg $adv 'TaskbarMn'          0   # ocultar Chat/Copilot
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 0

    $cfgDir = 'C:\ProgramData\WindowsSetupTuning'
    if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }
} else {
    Write-Host "`n[4] Omitiendo configuracion personalizada de la Barra de Tareas." -ForegroundColor Gray
}
#endregion

# ============================================================
#region 5. File Explorer
# ============================================================
Write-Host "`n[5] Configuring File Explorer..." -ForegroundColor Cyan
Set-Reg $adv 'LaunchTo'    1   # abrir en Este Equipo
Set-Reg $adv 'HideFileExt' 0   # mostrar extensiones
#endregion



# ============================================================
#region 6. Privacy & telemetry
# ============================================================
Write-Host "`n[6] Hardening privacy / disabling telemetry..." -ForegroundColor Cyan
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'                 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowDeviceNameInTelemetry'     0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'LimitDiagnosticLogCollection'   1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'LimitDumpCollection'            1
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry'  0
# ADVERTENCIA OFICIAL: AllowTelemetry=0 solo funciona completamente en Enterprise/Education.
# En Home/Pro, Microsoft ignora el valor 0 y lo fuerza a 1 (Required).
# El bloqueo real de telemetría en Consumer Editions se logra desactivando el servicio 'DiagTrack' en la sección de servicios.
if ($isHomeEdition) {
    Write-Host "  [!] Edicion Home detectada: AllowTelemetry=0 reduce a 'Required' pero NO desactiva." -ForegroundColor Yellow
    Write-Host "      Algunas GPOs de privacidad pueden ser ignoradas en esta edicion." -ForegroundColor Yellow
}
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
Set-Reg 'HKCU:\Control Panel\International\User Profile' 'HttpAcceptLanguageOptOut' 1
Set-Reg $adv 'Start_TrackProgs' 0
Set-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
Set-Reg 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' 'HasAccepted' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization' 'AllowInputPersonalization' 0
Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection'  1
Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 1
Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore' 'HarvestContacts' 0
Set-Reg 'HKCU:\Software\Microsoft\Personalization\Settings' 'AcceptedPrivacyPolicy' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed'    0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities'  0
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'Deny' 'String'
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocation' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice' 'AllowFindMyDevice' 0

$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
foreach ($v in @(
    'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-338393Enabled',
    'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled', 'SubscribedContent-310093Enabled',
    'SubscribedContent-88000326Enabled', 'SubscribedContent-338387Enabled', 'SystemPaneSuggestionsEnabled',
    'SilentInstalledAppsEnabled', 'PreInstalledAppsEnabled', 'OemPreInstalledAppsEnabled', 'ContentDeliveryAllowed',
    'FeatureManagementEnabled', 'RotatingLockScreenOverlayEnabled', 'SubscribedContentEnabled', 'SoftLandingEnabled'
)) { Set-Reg $cdm $v 0 }

Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures'     1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableCloudOptimizedContent'       1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding'                 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableConsumerAccountStateContent' 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsAADCloudSearchEnabled'      0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsMSACloudSearchEnabled'      0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsDeviceSearchHistoryEnabled' 0
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'ConnectedSearchUseWeb'  0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch'       1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowSearchToUseLocation' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCloudSearch'       0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'Disabled' 1
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
# Bloqueo de inyeccion de binarios OEM desde BIOS/UEFI en notebooks y placas base
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' 'DisableWPBT' 1

# --- Bloqueo completo de drivers y apps OEM automaticas ---
# Fuente: learn.microsoft.com/windows-client-management/mdm/policy-csp-update (ExcludeWUDriversInQualityUpdate)
#         learn.microsoft.com/windows-client-management/mdm/policy-csp-deviceinstallation (AllowGenericDriverFallback)
Write-Host "  [+] Bloqueando instalacion automatica de drivers y apps OEM..." -ForegroundColor Gray

# Excluir drivers de las actualizaciones de calidad de Windows Update (solo opcional)
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'ExcludeWUDriversInQualityUpdate' 1

# Bloquear descarga de metadata de dispositivo y apps OEM asociadas al hardware desde servidores MS
# (dmd.metaservices.microsoft.com) - previene HP Support Assistant, Dell SupportAssist, etc.
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata' 'PreventDeviceMetadataFromNetwork' 1

# Bloquear busqueda de drivers en Windows Update en hive CurrentVersion
# NOTA: SearchOrderConfig=0 = solo local. SearchOrderConfig=1 = buscar en WU (valor erroneo comun)
# Ref: learn.microsoft.com/windows/win32/setupapi/driver-store  
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' 'SearchOrderConfig'    0

# Bloquear busqueda en WU tambien via hive Policies (tiene precedencia sobre CurrentVersion)
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching' 'DontSearchWindowsUpdate'   1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching' 'SearchOrderConfig'         0

# Deshabilitar la instalacion de drivers genericos como interino mientras espera drivers especificos
# Evita que Windows instale un driver HID generico de HP, Dell, etc. que luego arrastra bloatware
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings' 'AllowGenericDriverFallback' 0

# Bloquear descarga automatica de apps OEM asociadas al hardware desde el Windows Store
# (Device Support Apps: HP Support Assistant, Dell SupportAssist, ASUS Armoury Crate, etc.)
# Ref: learn.microsoft.com/windows/client-management/mdm/policy-csp-applicationmanagement#allowautomaticapparchiving
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' 'AutoDownload' 2

# Bloquear cifrado automatico de BitLocker por software y habilitar BypassIO para DirectStorage
# Ref: learn.microsoft.com/windows/security/operating-system-hardware/data-protection/bitlocker/device-encryption-overview
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker' 'PreventDeviceEncryption' 1

Write-Host "  [OK] Politicas de drivers, apps OEM y BitLocker configuradas." -ForegroundColor Green
#endregion


# ============================================================
#region 7. Background apps
# ============================================================
Write-Host "`n[7] Disabling background apps..." -ForegroundColor Cyan
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' 2
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BackgroundAppGlobalToggle' 0
#endregion

# ============================================================
#region 8. Windows Services (Interactive) & Scheduled tasks
# ============================================================
Write-Host "`n[8] Disabling Windows Services and Tasks..." -ForegroundColor Cyan

$servicesList = @(
    [PSCustomObject]@{ Name='DiagTrack';        DisplayName='Connected User Experiences and Telemetry'; Reason='Privacidad y rendimiento: telemetria principal de Microsoft.' },
    [PSCustomObject]@{ Name='dmwappushservice'; DisplayName='WAP Push Message Routing';                 Reason='Privacidad: telemetria secundaria.' },
    [PSCustomObject]@{ Name='WerSvc';           DisplayName='Windows Error Reporting Service';          Reason='Evita congelamientos de 30s tras crash inesperado de juegos/apps.' },
    [PSCustomObject]@{ Name='TroubleshootingSvc'; DisplayName='Recommended Troubleshooting Service';   Reason='Diagnosticos no solicitados en segundo plano.' },
    [PSCustomObject]@{ Name='BDESVC';           DisplayName='BitLocker Drive Encryption Service';       Reason='Cifrado por software de disco (libera I/O en SSDs NVMe).' },
    [PSCustomObject]@{ Name='Fax';              DisplayName='Fax Service';                              Reason='Servicio legado de oficina. Inutil en PCs personales/gaming.' },
    [PSCustomObject]@{ Name='SCardSvr';         DisplayName='Smart Card Service';                       Reason='Tarjetas inteligentes corporativas / DNIe en empresas.' },
    [PSCustomObject]@{ Name='RemoteRegistry';   DisplayName='Remote Registry';                          Reason='Modificacion remota corporativa del registro.' },
    [PSCustomObject]@{ Name='RetailDemo';       DisplayName='Retail Demo Service';                      Reason='Modo demo de tienda. Sin utilidad personal.' },
    [PSCustomObject]@{ Name='MapsBroker';       DisplayName='Downloaded Maps Manager';                  Reason='Mapas sin conexion. Innecesario en escritorio.' },
    [PSCustomObject]@{ Name='lfsvc';            DisplayName='Geolocation Service';                      Reason='Sondeo constante de ubicacion geografica.' },
    [PSCustomObject]@{ Name='XblAuthManager';   DisplayName='Xbox Live Auth Manager';                   Reason='Innecesario sin Xbox Live / Game Pass.' },
    [PSCustomObject]@{ Name='WbioSrvc';         DisplayName='Windows Biometric Service';                Reason='Solo deshabilitar si NO usas Windows Hello / huella / facial.' },
    [PSCustomObject]@{ Name='TrkWks';           DisplayName='Distributed Link Tracking Client';         Reason='Innecesario en redes domesticas.' },
    [PSCustomObject]@{ Name='SysMain';          DisplayName='SysMain (SuperFetch)';                     Reason='Gaming/SSD: libera RAM. En HDD o <16 GB puede empeorar el arranque.' },
    [PSCustomObject]@{ Name='WSearch';          DisplayName='Windows Search (Indexer)';                 Reason='Reduce I/O constante. Las busquedas sin indice seran mas lentas.' },
    [PSCustomObject]@{ Name='Spooler';          DisplayName='Print Spooler [!]';                        Reason='[!] ADVERTENCIA: rompe impresoras fisicas Y virtuales (PDF, Adobe).' }
)

if (-not $Unattended) {
    Write-Host "  Abriendo ventana de seleccion para Servicios..." -ForegroundColor Yellow
    $ogvAvailable = $null -ne (Get-Command Out-GridView -ErrorAction SilentlyContinue)
    if ($ogvAvailable) {
        try {
            $selectedServices = $servicesList | Out-GridView -Title "Selecciona los servicios a DESHABILITAR (Ctrl para varios) -- respeta los [!]" -PassThru
        } catch {
            Write-Host "  [!] Out-GridView no disponible. Omitiendo gestion de servicios (usa -Unattended)." -ForegroundColor Yellow
            $selectedServices = $null
        }
    } else {
        Write-Host "  [!] Out-GridView no disponible en esta sesion. Omitiendo gestion de servicios (usa -Unattended)." -ForegroundColor Yellow
        $selectedServices = $null
    }
} else {
    Write-Host "  Modo desatendido: deshabilitando servicios seguros (excepto críticos [!] y SysMain que es dinámico)..." -ForegroundColor Gray
    $selectedServices = $servicesList | Where-Object { $_.DisplayName -notmatch '\[!\]' -and $_.Name -notmatch 'SysMain' }
}

if ($selectedServices) {
    Write-Host "  Procesando $($selectedServices.Count) servicios..." -ForegroundColor Cyan
    foreach ($svcInfo in $selectedServices) {
        $svc = Get-Service -Name $svcInfo.Name -ErrorAction SilentlyContinue
        if ($svc) {
            try { Stop-Service -Name $svcInfo.Name -Force -ErrorAction SilentlyContinue } catch {}
            try {
                Set-Service -Name $svcInfo.Name -StartupType Disabled -ErrorAction Stop
                Write-Host "  - Deshabilitado: $($svcInfo.DisplayName)" -ForegroundColor Green
            } catch {
                Write-Host "  ! Error al deshabilitar $($svcInfo.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "  - No existe: $($svcInfo.Name)" -ForegroundColor DarkGray
        }
    }
} else {
    Write-Host "  - Sin seleccion de servicios." -ForegroundColor Gray
}

Write-Host "  Deshabilitando tareas programadas de telemetria..." -ForegroundColor Cyan
$tasks = @(
    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
    '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
    '\Microsoft\Windows\Application Experience\StartupAppTask',
    '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
    '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
    '\Microsoft\Windows\Autochk\Proxy',
    '\Microsoft\Windows\Feedback\Siuf\DmClient',
    '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
    '\Microsoft\Windows\Windows Error Reporting\QueueReporting',
    '\Microsoft\Windows\CloudExperienceHost\CreateObjectTask'
)
foreach ($t in $tasks) {
    $tName = Split-Path $t -Leaf
    $tPath = (Split-Path $t -Parent) + '\'
    try {
        Disable-ScheduledTask -TaskName $tName -TaskPath $tPath -ErrorAction Stop | Out-Null
        Write-Host "  - Disabled task: $t" -ForegroundColor Green
    } catch {
        Write-Host "  - Task not found (OK): $tName" -ForegroundColor DarkGray
    }
}
#endregion

# ============================================================
#region 9. Start menu (unpin all + All Apps = List)
# ============================================================
$applyStartMenu = $true
if (-not $Unattended) {
    $choice = Read-Host "`n[9] ¿Desea desanclar todas las aplicaciones predeterminadas del Menú de Inicio? [Y/N] (Default: Y)"
    if ($choice -ne '' -and $choice -notmatch '^[yYsS]') {
        $applyStartMenu = $false
    }
}

if ($applyStartMenu) {
    Write-Host "`n[9] Configuring Start menu..." -ForegroundColor Cyan
    $startJson = '{ "applyOnce": true, "pinnedList": [] }'
    Set-Reg $expPol 'ConfigureStartPins' $startJson 'String'
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start' 'AllAppsViewMode' 2
    Set-Reg $adv 'Start_IrisRecommendations' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'HideRecommendedSection' 1
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_Layout' 1
} else {
    Write-Host "`n[9] Omitiendo la limpieza del Menú de Inicio (se mantendrán los pins de fábrica)." -ForegroundColor Gray
}
#endregion

# ============================================================
#region 10. Extra tweaks de sistema
# ============================================================
Write-Host "`n[10] Applying extra system tweaks..." -ForegroundColor Cyan
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask' 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'RotatingLockScreenEnabled' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers' 'DisableAutoplay' 1
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'VerboseStatus' 1
# Fast Startup se mueve a #11 para decision adaptativa segun tipo de equipo
#endregion

# ============================================================
#region 11. Hardware Adaptive Tweaks [INTELLIGENT v4]
# ============================================================
# NOTA: La deteccion de hardware (11.A) y el reporte (11.B) fueron movidos
# al bloque Pre-flight al inicio del script. Las variables $isLaptop, $isHDD,
# $isNVMe, $ramGiB, $isLowRAM, $cpuName, $isModernCPU, $isLowEndCPU,
# $isGaming, $hwProfile, etc. ya estan calculadas y disponibles.
Write-Host "`n[11] Aplicando optimizaciones adaptivas segun hardware detectado..." -ForegroundColor Cyan
Write-Host "  Perfil detectado: $hwProfile" -ForegroundColor White
Write-Host "" -ForegroundColor Gray

# ================================================================
# 11.C ACCIONES AUTOMATICAS (sin pregunta al usuario)
# Cambios cuya conveniencia es determinista segun el hardware.
# ================================================================
Write-Host "  [11.C] Aplicando optimizaciones automaticas segun hardware..." -ForegroundColor Cyan

# -- NTFS Last Access Time: siempre OFF en HDD (reduce escrituras I/O) --
if ($isHDD) {
    try {
        fsutil behavior set disablelastaccess 1 | Out-Null
        Write-Host "    - NTFS LastAccessTime deshabilitado (HDD: reduce I/O)." -ForegroundColor Green
    } catch {
        Write-Host "    ! fsutil disablelastaccess: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    # NTFS 8dot3 names: OFF en HDD con muchos archivos (acelera listado de dirs)
    try {
        fsutil behavior set disable8dot3 1 | Out-Null
        Write-Host "    - NTFS 8dot3 filename generation deshabilitado (HDD)." -ForegroundColor Green
    } catch {
        Write-Host "    ! fsutil disable8dot3: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# -- Prefetch / Superfetch segun disco --
$prefetchKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'
if ($isHDD) {
    # HDD: mantener Prefetch activo (pre-carga apps en RAM, acelera apertura)
    Set-Reg $prefetchKey 'EnablePrefetcher'  3   # 3 = Apps + boot
    Set-Reg $prefetchKey 'EnableSuperfetch'  1
    Write-Host "    - Prefetch/Superfetch ACTIVO (HDD: mejora tiempos de carga)." -ForegroundColor Green
} else {
    # SSD/NVMe: desactivar (acceso aleatorio rapido, no necesita pre-carga)
    Set-Reg $prefetchKey 'EnablePrefetcher'  0
    Set-Reg $prefetchKey 'EnableSuperfetch'  0
    Write-Host "    - Prefetch/Superfetch DESACTIVADO (SSD/NVMe: no necesario, reduce escrituras)." -ForegroundColor Green
}

# -- SysMain segun RAM y disco --
$sysMainSvc = Get-Service -Name SysMain -ErrorAction SilentlyContinue
if ($isLowRAM -and -not $isHDD) {
    # RAM escasa + SSD: deshabilitar SysMain (libera RAM real, SSD no necesita pre-carga)
    if ($sysMainSvc) {
        try {
            Stop-Service SysMain -Force -ErrorAction SilentlyContinue
            Set-Service  SysMain -StartupType Disabled -ErrorAction Stop
            Write-Host "    - SysMain DESHABILITADO (<=4GB RAM + SSD: libera RAM real)." -ForegroundColor Green
        } catch { Write-Host "    ! SysMain disable: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
} elseif ($isLowRAM -and $isHDD) {
    # RAM escasa + HDD: mantener SysMain igualmente (paginar a HDD es peor que SysMain)
    Write-Host "    - SysMain MANTENIDO activo (HDD + poca RAM: paginar a HDD seria peor)." -ForegroundColor Green
} elseif ($isHDD) {
    # HDD (cualquier RAM): mantener SysMain -- pre-carga en HDD mejora experiencia
    Write-Host "    - SysMain MANTENIDO activo (HDD: el prefetch reduce tiempos de carga)." -ForegroundColor Green
}

# -- MMAgent: compresion de memoria segun perfil --
$sysMainNowDisabled = ($null -ne (Get-Service SysMain -EA SilentlyContinue)) -and
                      ((Get-Service SysMain -EA SilentlyContinue).StartType -eq 'Disabled')
if ($sysMainNowDisabled -and -not $isHDD) {
    # SysMain off + SSD: sin compresion (CPU libre mas valioso que RAM comprimida en SSD rapido)
    try { Disable-MMAgent -MemoryCompression -ErrorAction Stop; Write-Host "    - MemoryCompression DESACTIVADO (SysMain off + SSD)." -ForegroundColor Green } catch {}
    try { Disable-MMAgent -PageCombining    -ErrorAction Stop; Write-Host "    - PageCombining DESACTIVADO." -ForegroundColor Green } catch {}
} elseif ($isLowRAM -and $isHDD) {
    # Poca RAM + HDD: MANTENER compresion (comprimir es mas rapido que paginar al HDD)
    try { Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue; Write-Host "    - MemoryCompression ACTIVO (HDD + poca RAM: mejor comprimir que paginar)." -ForegroundColor Green } catch {}
}

# -- Pagefile: ajuste para RAM escasa --
if ($isLowRAM) {
    # Con <= 4 GiB, el pagefile es critico. Configurar size automatico del sistema.
    # No usamos tamanio fijo para evitar problemas con discos pequenos.
    $pagefilePath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    # PagingFiles vacio = administrado por Windows (automatico, adaptativo)
    try {
        $cs = Get-CimInstance Win32_ComputerSystem
        if (-not $cs.AutomaticManagedPagefile) {
            $cs | Set-CimInstance -Property @{AutomaticManagedPagefile=$true} -ErrorAction Stop
            Write-Host "    - Pagefile configurado como ADMINISTRADO por Windows (RAM escasa)." -ForegroundColor Green
        } else {
            Write-Host "    - Pagefile ya esta en modo automatico." -ForegroundColor Gray
        }
    } catch {
        Write-Host "    ! Pagefile config: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    # DisablePagingExecutive = 0: permite que el kernel paguine modulos no usados
    # liberando RAM real (critico con 4 GiB)
    Set-Reg $pagefilePath 'DisablePagingExecutive' 0
    Write-Host "    - DisablePagingExecutive=0 (kernel puede paginar, libera RAM real)." -ForegroundColor Green
}

# -- Hibernate: ajuste segun laptop/desktop y RAM --
if (-not $isLaptop) {
    # Desktop: deshabilitar hibernacion (libera hiberfil.sys = ~RAM GiB en disco)
    try {
        powercfg /hibernate off 2>&1 | Out-Null
        Write-Host "    - Hibernacion DESHABILITADA en Desktop (libera $('{0:N1}' -f $ramGiB) GiB en disco)." -ForegroundColor Green
    } catch {}
} else {
    Write-Host "    - Hibernacion MANTENIDA en Laptop (necesaria para S4/fast resume)." -ForegroundColor Gray
}

# -- Fast Startup automatico para Desktop --
if (-not $isLaptop) {
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0
    Write-Host "    - Fast Startup DESHABILITADO (Desktop: shutdown limpio, evita conflictos de drivers)." -ForegroundColor Green
} else {
    Write-Host "    - Fast Startup MANTENIDO en Laptop (puede afectar reanudacion S4)." -ForegroundColor Gray
}

if (-not $isLaptop) {
    # Desktop: Activar e importar Ultimate Performance (con fallback a High Performance)
    $upGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
    $hpGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    try {
        $existing = powercfg /list | Select-String $upGuid
        if (-not $existing) {
            powercfg /duplicatescheme $upGuid 2>&1 | Out-Null
        }
        powercfg /setactive $upGuid 2>&1 | Out-Null
        Write-Host "    - Plan de energia configurado a Ultimate Performance (Desktop)." -ForegroundColor Green
    } catch {
        try {
            powercfg /setactive $hpGuid 2>&1 | Out-Null
            Write-Host "    - Plan de energia configurado a High Performance (Desktop fallback)." -ForegroundColor Green
        } catch {
            Write-Host "    ! Error al establecer plan de energia: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "    - Power Mode MANTENIDO en Balanced (Laptop: necesario para gestion de bateria y Modern Standby)." -ForegroundColor Gray
}

# -- SysMain: forzar OFF si HDD con menos del 5% de espacio libre --
# [NEW-5] Con poco espacio, SysMain no puede escribir ReadyBoot y consume
# CPU sin beneficio. Chequear espacio libre del volumen C:.
if ($isHDD) {
    try {
        $cDrive   = Get-PSDrive -Name C -ErrorAction Stop
        $freeGB   = [math]::Round($cDrive.Free / 1GB, 2)
        $totalGB  = [math]::Round(($cDrive.Free + $cDrive.Used) / 1GB, 2)
        $freePct  = if ($totalGB -gt 0) { [math]::Round($cDrive.Free / ($cDrive.Free + $cDrive.Used) * 100, 1) } else { 100 }
        Write-Host "    Disco C: $freeGB GB libres de $totalGB GB ($freePct% libre)." -ForegroundColor Gray
        if ($freePct -lt 5) {
            # HDD lleno: SysMain no puede funcionar correctamente, deshabilitar
            $sysMainSvcCheck = Get-Service -Name SysMain -ErrorAction SilentlyContinue
            if ($sysMainSvcCheck -and $sysMainSvcCheck.StartType -ne 'Disabled') {
                try {
                    Stop-Service SysMain -Force -ErrorAction SilentlyContinue
                    Set-Service  SysMain -StartupType Disabled -ErrorAction Stop
                    Write-Host "    - SysMain DESHABILITADO (HDD con < 5% libre: ReadyBoot imposible, CPU overhead inutil)." -ForegroundColor Yellow
                } catch { Write-Host "    ! SysMain disable (disco lleno): $($_.Exception.Message)" -ForegroundColor Yellow }
            }
        }
    } catch {
        Write-Host "    ! Check espacio disco: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# -- Power plan automatico --
if ($isLaptop -or $isLowEndCPU) {
    # Laptop o CPU debil: plan Balanced con ajustes (no forzar Turbo constante)
    $balancedGuid = '381b4222-f694-41f0-9685-ff5bb260df2e'
    try {
        powercfg /setactive $balancedGuid 2>&1 | Out-Null
        if ($isLowEndCPU) {
            # CPUs de bajo TDP: limitar al 99% del maximo para evitar sobrecalentamiento
            powercfg /setacvalueindex $balancedGuid SUB_PROCESSOR PROCTHROTTLEMAX 99 2>&1 | Out-Null
            powercfg /setacvalueindex $balancedGuid SUB_PROCESSOR PROCTHROTTLEMIN 5  2>&1 | Out-Null
            powercfg /setactive $balancedGuid 2>&1 | Out-Null
            Write-Host "    - Plan BALANCED activado con CPU max=99% (CPU low-end: evita sobrecalentamiento)." -ForegroundColor Green
        } else {
            Write-Host "    - Plan BALANCED activado (Laptop: conserva bateria y temperatura)." -ForegroundColor Green
        }
    } catch { Write-Host "    ! powercfg Balanced: $($_.Exception.Message)" -ForegroundColor Yellow }
}
# (Desktop con CPU normal/gaming: el plan se ofrece en el menu interactivo de 11.D)

# -- [NEW-10] Power Throttling OFF en Desktop --
# Deshabilita el throttling de background para TODOS los procesos.
# En Desktop no hay bateria, asi que no tiene sentido limitar potencia de background.
# Ref: https://learn.microsoft.com/answers/questions/ (Power Throttling registry)
#      https://winaero.com/disable-power-throttling-in-windows-11/
if (-not $isLaptop) {
    $ptKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling'
    Set-Reg $ptKey 'PowerThrottlingOff' 1
    Write-Host "    - Power Throttling DESHABILITADO (Desktop: sin restriccion de potencia en background)." -ForegroundColor Green
} else {
    Write-Host "    - Power Throttling MANTENIDO (Laptop: necesario para conservar bateria)." -ForegroundColor Gray
}

Write-Host "" -ForegroundColor Gray

# ================================================================
# 11.D MENU INTERACTIVO: Optimizaciones opcionales
# Solo se ofrecen las que tienen sentido para ESTE hardware.
# Columna 'Recomendado' ya tiene la sugerencia calculada.
# ================================================================
Write-Host "  [11.D] Menu de optimizaciones opcionales..." -ForegroundColor Cyan

# Construir lista de tweaks filtrada segun hardware
$adaptiveTweaks = @()

# Ultimate Performance: solo para Desktop con CPU normal o gaming
if (-not $isLaptop -and -not $isLowEndCPU) {
    $adaptiveTweaks += [PSCustomObject]@{
        Id='UltimatePlan'
        Name='Activar Plan Ultimate Performance'
        Recomendado = if ($isGaming) { 'SI -- Gaming Desktop: maxima responsividad' } else { 'SI -- Desktop con CPU normal' }
        Desc='Elimina micro-latencias del planificador de CPU. NO usar en laptops ni CPUs de bajo TDP.'
    }
}

# Timer HPET/TSC: solo para CPU moderna en Desktop (en laptop puede afectar gestion de bateria)
if ($isModernCPU -and -not $isLaptop -and -not $isLowEndCPU) {
    $adaptiveTweaks += [PSCustomObject]@{
        Id='FixTimer'
        Name='Optimizar Timer HPET/TSC (CPUs modernas)'
        Recomendado='SI -- CPU 12th Gen+ / Ryzen 5000+: reduce stutters y FPS drops'
        Desc='Elimina useplatformclock, activa disabledynamictick y tscsyncpolicy=enhanced.'
    }
} elseif (-not $isModernCPU -and -not $isLowEndCPU) {
    $adaptiveTweaks += [PSCustomObject]@{
        Id='FixTimer'
        Name='Optimizar Timer HPET/TSC'
        Recomendado='NO recomendado -- CPU no es 12th Gen+ ni Ryzen 5000+. Puede causar stutters.'
        Desc='Solo beneficia CPUs modernas. En hardware legacy puede empeorar la experiencia.'
    }
}

# GameBar / DVR: ofrecido siempre, recomendacion segun GPU
$adaptiveTweaks += [PSCustomObject]@{
    Id='GameBar'
    Name='Deshabilitar Xbox GameBar / GameDVR'
    Recomendado = if ($isGaming) { 'SI -- GPU dedicada: libera overhead de captura de pantalla' } else { 'Opcional -- GPU integrada: impacto bajo pero positivo' }
    Desc='Desactiva overlay y captura en background. No afecta juego sin Xbox Live.'
}

# HAGS: solo si hay GPU dedicada (en GPU integrada no tiene efecto positivo)
if ($isGaming) {
    $adaptiveTweaks += [PSCustomObject]@{
        Id='HAGS'
        Name='Habilitar HAGS (Hardware GPU Scheduling)'
        Recomendado='SI -- GPU dedicada: reduce latencia GPU. Req. WDDM 2.7+ (NVIDIA 451.48+ / AMD 20.5.1+)'
        Desc='Delega el scheduler de GPU al driver. Beneficio real en gaming con framerate alto.'
    }
} else {
    $adaptiveTweaks += [PSCustomObject]@{
        Id='HAGS'
        Name='Habilitar HAGS (Hardware GPU Scheduling)'
        Recomendado='NO recomendado -- GPU integrada: HAGS no tiene beneficio medible en iGPU'
        Desc='Solo util con GPU dedicada NVIDIA/AMD/Arc. En GPU integrada puede causar inestabilidad.'
    }
}

# Virtualization-Based Security (VBS): toggle opcional (alto impacto en FPS)
$adaptiveTweaks += [PSCustomObject]@{
    Id='DisableVBS'
    Name='Deshabilitar VBS y Memory Integrity'
    Recomendado='SI -- Gaming: mejora 1% lows (15-25% menos micro-stutters). Remueve un escudo de seguridad del kernel.'
    Desc='Desactiva Hypervisor-protected Code Integrity (HVCI) y Virtualization-Based Security.'
}

# Nagle Algorithm (TCP No-Delay): opcion para gaming online competitivo
$adaptiveTweaks += [PSCustomObject]@{
    Id='NagleOff'
    Name='Deshabilitar Nagle Algorithm (TCP No-Delay)'
    Recomendado = if ($isGaming) { 'SI -- Gaming online: reduce micro-latencia TCP en juegos competitivos' } else { 'Opcional -- Solo util si juegas online competitivo' }
    Desc='Deshabilita el buffering TCP (TcpNoDelay=1, TcpAckFrequency=1) en el adaptador de red activo.'
}

if (-not $Unattended) {
    Write-Host "  Abriendo ventana de optimizaciones opcionales..." -ForegroundColor Yellow
    Write-Host "  (Las automaticas ya fueron aplicadas arriba. Estas son adicionales.)" -ForegroundColor DarkGray
    $ogvAvailable = $null -ne (Get-Command Out-GridView -ErrorAction SilentlyContinue)
    if ($ogvAvailable) {
        try {
            $selectedTweaks = $adaptiveTweaks | Out-GridView -Title "Optimizaciones opcionales -- guiate por la columna Recomendado" -PassThru
        } catch {
            Write-Host "  [!] Out-GridView no disponible. Aplicando tweaks recomendados automaticamente..." -ForegroundColor Yellow
            $selectedTweaks = $adaptiveTweaks | Where-Object { $_.Recomendado -match '^SI' }
        }
    } else {
        Write-Host "  [!] Out-GridView no disponible. Aplicando tweaks recomendados automaticamente..." -ForegroundColor Yellow
        $selectedTweaks = $adaptiveTweaks | Where-Object { $_.Recomendado -match '^SI' }
    }
} else {
    Write-Host "  Modo desatendido: aplicando optimizaciones recomendadas segun el hardware..." -ForegroundColor Gray
    $selectedTweaks = $adaptiveTweaks | Where-Object { $_.Recomendado -match '^SI' }
}

$applyUltimate = $false
$applyFixTimer = $false
$applyGameBar  = $false
$applyHags     = $false
$applyVbs      = $false
$applyNagle    = $false

if ($selectedTweaks) {
    foreach ($tweak in $selectedTweaks) {
        switch ($tweak.Id) {
            'UltimatePlan' { $applyUltimate = $true; Write-Host "  - Ultimate Performance marcado." -ForegroundColor Gray }
            'FixTimer'     { $applyFixTimer  = $true; Write-Host "  - Timer fix marcado." -ForegroundColor Gray }
            'GameBar'      { $applyGameBar   = $true; Write-Host "  - GameBar/DVR marcado." -ForegroundColor Gray }
            'HAGS'         { $applyHags      = $true; Write-Host "  - HAGS marcado." -ForegroundColor Gray }
            'DisableVBS'   { $applyVbs       = $true; Write-Host "  - Deshabilitar VBS/HVCI marcado." -ForegroundColor Gray }
            'NagleOff'     { $applyNagle     = $true; Write-Host "  - Nagle Algorithm disable marcado." -ForegroundColor Gray }
        }
    }
} else {
    Write-Host "  - Sin seleccion en el menu opcional." -ForegroundColor Gray
}
#endregion

# ============================================================
#region 12. Gaming optimizations (Core) [FIXED]
# ============================================================
Write-Host "`n[12] Applying Core Gaming optimizations..." -ForegroundColor Cyan

# --- 12.A Condicional: GameBar / GameDVR ---
if ($applyGameBar) {
    Write-Host "  [12.A] Disabling Xbox GameBar / GameDVR..." -ForegroundColor Gray

    # Game Mode ON (prioriza CPU/GPU para el proceso en primer plano)
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode'         1
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled'       1
    # Game Bar / DVR OFF
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'UseNexusForGameBarEnabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'ShowStartupPanel'          0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0

    # GameConfigStore -- NOTA DE AUDITORIA (DX12 vs DX11):
    # Estos tweaks de FSE (Exclusive Fullscreen) son efectivos unicamente en juegos DirectX 11 / DX9.
    # En DirectX 12 y Vulkan, Microsoft implemento el 'Independent Flip Model' (MPO) que bypassa el compositor (DWM)
    # sin necesidad de modo exclusivo. Se aplican por compatibilidad legacy, pero no tienen efecto en juegos AAA modernos.
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled'                    0
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_FSEBehaviorMode'             2   # 2 = prefer FSO desactivado
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_HonorUserFSEBehaviorMode'    1   # 1 = respetar flag FSE del juego
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_DXGIHonorFSEWindowsCompatible' 1
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_FSEBehavior'                 2
    # [FIX-6] EFSEFeatureFlags faltaba -- valor 0 = EFSE deshabilitado (por defecto/seguro)
    # Ref: https://learn.microsoft.com/en-us/answers/questions/3741077/fullscreen-optimizations-windows-registry
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_EFSEFeatureFlags'            0

    Write-Host "    - GameBar/DVR deshabilitado. GameConfigStore actualizado." -ForegroundColor Green
}
# [FIX-7] FSO/GameConfigStore ahora SOLO se aplica cuando el usuario selecciono GameBar.

# --- 12.B Condicional: HAGS con verificacion de driver ---
# [NEW-6] Activar HAGS sin verificar el driver puede causar BSOD en sistemas
# con drivers antiguos (pre-WDDM 2.7). Se verifica la version antes de activar.
# NVIDIA: DriverVersion "xx.xx.14.xxxx" -- el campo "14" indica WDDM 2.x+.
#         Driver 451.48 = DriverVersion "27.21.14.5148". Primer segmento >= 27 = WDDM 2.7+.
# AMD:    DriverVersion "27.20.xx.xxxx" o superior para WDDM 2.7+.
# Intel:  Cualquier DCH driver moderno soporta HAGS.
# Ref: https://learn.microsoft.com/windows-hardware/drivers/display/hardware-accelerated-gpu-scheduling
if ($applyHags) {
    Write-Host "  [12.B] Enabling Hardware-Accelerated GPU Scheduling (HAGS)..." -ForegroundColor Gray
    $gpuDriverOk = $false
    $gpuForHags  = $null
    
    # Identificar GPU dedicada para el mensaje
    foreach ($g in $gpuObjs) {
        if ($g.Name -match 'NVIDIA|AMD Radeon|Intel Arc') { $gpuForHags = $g; break }
    }

    # Verificar soporte de HAGS: si el driver/SO soporta HAGS de forma nativa
    $hwSchKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
    $currentHwSch = (Get-ItemProperty -Path $hwSchKey -Name 'HwSchMode' -ErrorAction SilentlyContinue).HwSchMode
    
    if ($null -ne $currentHwSch) {
        # La clave existe = el driver/SO soporta la interfaz de HAGS
        $gpuDriverOk = $true
    } else {
        # Fallback analítico: comprobar si hay un driver moderno compatible con WDDM 2.7+ (NVIDIA versión >= 27.x, AMD >= 27.x)
        if ($null -ne $gpuForHags -and $gpuForHags.DriverVersion) {
            if ($gpuForHags.DriverVersion -match '^([2-9][7-9]|[3-9][0-9])\.') {
                $gpuDriverOk = $true
            }
        }
    }

    if ($gpuDriverOk) {
        Set-Reg $hwSchKey 'HwSchMode' 2
        $versionStr = if ($null -ne $gpuForHags) { $gpuForHags.DriverVersion } else { "SO Nativo" }
        Write-Host "    - HAGS habilitado (HwSchMode=2). Driver: $versionStr. Requiere reinicio." -ForegroundColor Green
    } elseif ($null -ne $gpuForHags) {
        Write-Host "    ! HAGS NO activado: driver $($gpuForHags.DriverVersion) puede ser pre-WDDM 2.7." -ForegroundColor Yellow
        Write-Host "      Actualiza el driver a NVIDIA 451.48+ / AMD 20.5.1+ y vuelve a ejecutar." -ForegroundColor Yellow
    } else {
        Write-Host "    ! HAGS: no se encontro GPU dedicada compatible para verificar driver." -ForegroundColor Yellow
    }
}

# --- 12.C Condicional: Ultimate Performance ---
if ($applyUltimate) {
    Write-Host "  [12.C] Activating Ultimate Performance power plan..." -ForegroundColor Gray
    try {
        $upGuid   = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
        $existing = powercfg /list | Select-String $upGuid
        if (-not $existing) {
            powercfg /duplicatescheme $upGuid | Out-Null
            Write-Host "    - Plan Ultimate Performance duplicado." -ForegroundColor Green
        }
        powercfg /setactive $upGuid | Out-Null
        Write-Host "    - Plan Ultimate Performance activado." -ForegroundColor Green
    } catch {
        Write-Host "    ! No se pudo activar Ultimate Performance: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --- 12.D Condicional: Timer fix (HPET/TSC para CPUs modernas) ---
if ($applyFixTimer) {
    Write-Host "  [12.D] Applying timer optimizations (Modern CPU)..." -ForegroundColor Gray
    Write-Host "  [!] AVISO: bcdedit tweaks NO son oficialmente soportados por Microsoft para gaming." -ForegroundColor Red
    Write-Host "      Pueden causar regresiones en algunos sistemas. Revertir con:" -ForegroundColor Red
    Write-Host "      bcdedit /deletevalue disabledynamictick && bcdedit /deletevalue tscsyncpolicy" -ForegroundColor DarkYellow

    # [FIX-1] SINTAXIS CORREGIDA:
    #   PROBLEMA ORIGINAL: 'bcdedit /deletevalue useplatformclock -ErrorAction SilentlyContinue | Out-Null'
    #   -ErrorAction NO es un parametro de bcdedit.exe. Si la clave no existe, bcdedit
    #   devuelve exit code 1 con "Element not found" -- eso NO es un error critico, es
    #   normal cuando useplatformclock nunca fue configurado. Se captura con try/catch y
    #   se evalua $LASTEXITCODE separadamente.
    #
    #   PASOS ADICIONALES AGREGADOS segun documentacion:
    #   - 'bcdedit /set disabledynamictick yes': desactiva los timer ticks sinteticos.
    #     Documentado en Blur Busters, XDA Developers (2026).
    #   - 'bcdedit /set tscsyncpolicy enhanced': sincronizacion TSC mejorada en multi-core.
    #     Documentado en Blur Busters forums.
    #   Refs: https://forums.blurbusters.com/viewtopic.php?t=11951
    #         https://www.xda-developers.com/your-bios-has-a-setting-that-makes-windows-feel-faster (2026)
    #         https://learn.microsoft.com/windows-hardware/drivers/devtest/bcdedit--set

    # Paso 1: Eliminar useplatformclock (si estaba forzado previamente)
    try {
        $out = & bcdedit.exe /deletevalue useplatformclock 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    - useplatformclock eliminado (clave existia)." -ForegroundColor Green
        } else {
            # Exit code 1 con "Element not found" es normal -- no es un error del script
            Write-Host "    - useplatformclock no estaba configurado (OK, era el valor por defecto)." -ForegroundColor Gray
        }
    } catch {
        Write-Host "    ! bcdedit deletevalue: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Paso 2: Deshabilitar Dynamic Tick (reduce interrupciones del timer en CPUs modernas)
    try {
        & bcdedit.exe /set disabledynamictick yes | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Host "    - disabledynamictick = yes." -ForegroundColor Green }
        else { Write-Host "    ! disabledynamictick: exit code $LASTEXITCODE" -ForegroundColor Yellow }
    } catch {
        Write-Host "    ! bcdedit disabledynamictick: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Paso 3: TSC sync policy enhanced (mejor sincronizacion de timestamp counter en multi-core)
    try {
        & bcdedit.exe /set tscsyncpolicy enhanced | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Host "    - tscsyncpolicy = enhanced." -ForegroundColor Green }
        else { Write-Host "    ! tscsyncpolicy: exit code $LASTEXITCODE" -ForegroundColor Yellow }
    } catch {
        Write-Host "    ! bcdedit tscsyncpolicy: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    # Paso 4: GlobalTimerResolutionRequests=1
    # [NEW-7] Permite que apps soliciten alta resolucion de timer (0.5ms) sin afectar
    # al sistema entero. Solo beneficioso en CPUs modernas donde el timer dinamico
    # ya esta optimizado. En CPUs legacy puede generar interrupciones innecesarias.
    # Ref: https://forums.blurbusters.com/viewtopic.php?t=7046
    if ($isModernCPU) {
        $kernelKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel'
        Set-Reg $kernelKey 'GlobalTimerResolutionRequests' 1
        Write-Host "    - GlobalTimerResolutionRequests=1 (CPU moderna: apps pueden pedir 0.5ms timer)." -ForegroundColor Green
    } else {
        Write-Host "    - GlobalTimerResolutionRequests no aplicado (CPU no moderna)." -ForegroundColor Gray
    }
    Write-Host "    - Timer optimizations applied. Requiere reinicio." -ForegroundColor Green
}

# --- 12.D2 Condicional: VBS / Memory Integrity ---
if ($applyVbs) {
    Write-Host "  [12.D2] Disabling VBS and Memory Integrity (HVCI)..." -ForegroundColor Gray
    try {
        # Deshabilitar seguridad basada en virtualización (VBS)
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity' 0
        # Deshabilitar protección de integridad de código del hipervisor (HVCI)
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' 0
        Write-Host "    - VBS y Memory Integrity deshabilitados en el registro. Requiere reinicio." -ForegroundColor Green
    } catch {
        Write-Host "    ! Error al desactivar VBS/HVCI: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --- 12.E Estatico: Prioridades multimedia / GPU (siempre se aplican) ---
Write-Host "  [12.E] Multimedia & GPU scheduling priorities (static)..." -ForegroundColor Gray

# Tasks\Games: prioridades del MMCSS scheduler para procesos de gaming
# Ref: https://djdallmann.github.io/GamingPCSetup/ (investigacion reproducible)
#      https://learn.microsoft.com/answers/questions/3221643/borked-my-reg (MS Q&A)
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'GPU Priority'         8
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'Priority'             6
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'Scheduling Category' 'High' 'String'
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'SFIO Priority'       'High' 'String'

# [FIX-5] NetworkThrottlingIndex: 0xffffffff desborda Int32 en New-ItemProperty.
#   Fix: cast explicito a [uint32] para que PowerShell lo interprete correctamente
#   como DWORD sin signo de 32 bits. Valor 0xFFFFFFFF = deshabilitar throttling de red.
#   Ref: https://djdallmann.github.io/GamingPCSetup/CONTENT/RESEARCH/NETWORK/
#        https://www.makeuseof.com (marzo 2026)
#        https://windowsforum.com/threads/tuning-networkthrottlingindex (2026)
# NetworkThrottlingIndex = 0xFFFFFFFF = throttling de red deshabilitado.
# PS5.1 FIX: NO usar [uint32]0xFFFFFFFF -- el parser de PS5.1 interpreta
# 0xFFFFFFFF como Int32 (-1) antes del cast, y [uint32]-1 lanza excepcion.
# Solucion: pasar -1 directamente como Int32. El registro REG_DWORD
# almacena 32 bits raw; -1 en Int32 = 0xFFFFFFFF en el registro.
# Verificado en Microsoft Docs y regedit: ambos producen el mismo DWORD.
$mmProfileKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
Set-Reg $mmProfileKey 'NetworkThrottlingIndex' -1

# SystemResponsiveness = 10 (Default de Windows para mantener background services sanos)
Set-Reg $mmProfileKey 'SystemResponsiveness' 10

# --- 12.F Estatico: VRR + Windowed Games Optimization (DirectX Settings) ---
# [NEW-12] Combinamos VRR y SwapEffectUpgradeEnable en un solo bloque ya que comparten
# la misma clave DirectXUserGlobalSettings. SwapEffectUpgradeEnable=1 es la feature
# "Optimizations for windowed games" nativa de Windows 11 25H2.
# Ref: https://devblogs.microsoft.com/directx/windowed-games-optimizations/
Write-Host "  [12.F] VRR + Windowed Games Optimization (DirectX)..." -ForegroundColor Gray
try {
    $vrrKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    $existingSettings = (Get-ItemProperty -Path $vrrKey -Name 'DirectXUserGlobalSettings' -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
    $newSettings = if ($existingSettings) { $existingSettings } else { '' }
    $changed = $false

    # VRR (Variable Refresh Rate / Adaptive Sync)
    if ($newSettings -notlike '*VRROptimizeEnable=1;*') {
        $newSettings += 'VRROptimizeEnable=1;'
        $changed = $true
        Write-Host "    - VRR habilitado." -ForegroundColor Green
    } else {
        Write-Host "    - VRR ya estaba habilitado." -ForegroundColor Gray
    }

    # [NEW-12] Windowed Games Optimization (SwapEffectUpgradeEnable)
    # Reduce latencia en juegos en modo ventana/borderless. Nativo en Win11.
    if ($newSettings -notlike '*SwapEffectUpgradeEnable=1;*') {
        $newSettings += 'SwapEffectUpgradeEnable=1;'
        $changed = $true
        Write-Host "    - Windowed Games Optimization habilitado (reduce latencia en borderless)." -ForegroundColor Green
    } else {
        Write-Host "    - Windowed Games Optimization ya estaba habilitado." -ForegroundColor Gray
    }

    if ($changed) {
        if (-not (Test-Path $vrrKey)) { New-Item -Path $vrrKey -Force | Out-Null }
        Set-ItemProperty -Path $vrrKey -Name 'DirectXUserGlobalSettings' -Value $newSettings -Force | Out-Null
    }
} catch {
    Write-Host "    ! No se pudo configurar DirectX settings: $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- 12.G Estatico: Deshabilitar aceleracion de mouse (Pointer Precision) ---
Write-Host "  [12.G] Disabling mouse pointer precision (acceleration)..." -ForegroundColor Gray
# MouseSpeed=0, Threshold1=0, Threshold2=0 desactiva el algoritmo de aceleracion
Set-ItemProperty 'HKCU:\Control Panel\Mouse' -Name MouseSpeed      -Value 0
Set-ItemProperty 'HKCU:\Control Panel\Mouse' -Name MouseThreshold1 -Value 0
Set-ItemProperty 'HKCU:\Control Panel\Mouse' -Name MouseThreshold2 -Value 0
Write-Host "    - Pointer precision (aceleracion) deshabilitada." -ForegroundColor Green

# --- 12.H Condicional: MSI Mode para GPU dedicada ---
# [NEW-8] Message Signaled Interrupts reemplazan interrupciones legacy por linea,
# reduciendo latencia DPC del driver de GPU. Impacto real medible en frame time.
# La ruta del registro usa el PNPDeviceID de la GPU, obtenido de Win32_VideoController.
# Ref: https://learn.microsoft.com/windows-hardware/drivers/kernel/enabling-message-signaled-interrupts-in-the-registry
#      https://www.hackingpc.com/how-to-enable-msi-mode-for-gpu-in-windows-11/
if ($isGaming) {
    Write-Host "  [12.H] Enabling MSI Mode for dedicated GPU..." -ForegroundColor Gray
    $msiApplied = $false
    foreach ($g in $gpuObjs) {
        if ($g.Name -match 'NVIDIA|AMD Radeon|Intel Arc') {
            $pnpId = $g.PNPDeviceID
            if ($pnpId) {
                # Convertir PNPDeviceID a ruta de registro
                $baseRegPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters"
                $regPath = "$baseRegPath\Interrupt Management\MessageSignaledInterruptProperties"
                
                # Validar que exista la clave Device Parameters del driver antes de proceder
                if (Test-Path $baseRegPath) {
                    try {
                        $existingMSI = $null
                        if (Test-Path $regPath) {
                            $existingMSI = (Get-ItemProperty -Path $regPath -Name 'MSISupported' -ErrorAction SilentlyContinue).MSISupported
                        }
                        if ($null -ne $existingMSI -and $existingMSI -eq 1) {
                            Write-Host "    - MSI Mode ya estaba habilitado para: $($g.Name) (sin cambios)." -ForegroundColor Gray
                        } else {
                            if (-not (Test-Path $regPath)) {
                                New-Item -Path "$baseRegPath\Interrupt Management" -ErrorAction SilentlyContinue | Out-Null
                                New-Item -Path $regPath -Force | Out-Null
                            }
                            New-ItemProperty -Path $regPath -Name 'MSISupported' -Value 1 -PropertyType DWord -Force | Out-Null
                            Write-Host "    - MSI Mode habilitado con exito para: $($g.Name)" -ForegroundColor Green
                            Write-Host "      PNPDeviceID: $pnpId" -ForegroundColor DarkGray
                            $msiApplied = $true
                        }
                    } catch {
                        Write-Host "    ! MSI Mode para $($g.Name): $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "    ! MSI Mode omitido: No se encontro subclave 'Device Parameters' para $($g.Name)." -ForegroundColor Yellow
                }
            } else {
                Write-Host "    ! PNPDeviceID no disponible para $($g.Name)." -ForegroundColor Yellow
            }
        }
    }
    if ($msiApplied) {
        Write-Host "    MSI Mode requiere reinicio para activarse." -ForegroundColor Green
    }
} else {
    Write-Host "  [12.H] MSI Mode: omitido (no hay GPU dedicada NVIDIA/AMD/Arc detectada)." -ForegroundColor Gray
}

# --- 12.I INFORMATIVO: Win32PrioritySeparation ---
# NOTA: Este tweak fue eliminado de la aplicacion automatica.
# Benchmarks reproducibles (fpsheaven.com, windowsforum.com 2025-2026) muestran
# efecto negligible en FPS reales al cambiar valores 38/40.
# El scheduler moderno de Windows 11 ya prioriza el foreground adecuadamente.
# Riesgo: puede causar comportamiento erratico en apps de background (audio, grabacion).
# Si deseas experimentar manualmente:
#   reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 38 /f
Write-Host "  [12.I] Win32PrioritySeparation: NO modificado (benchmarks muestran impacto negligible)." -ForegroundColor Gray
Write-Host "         El scheduler de Windows 11 ya prioriza el proceso en foreground." -ForegroundColor DarkGray

Write-Host "  [12] Gaming optimizations applied." -ForegroundColor Green

# --- 12.J Condicional: Nagle Algorithm disable (TCP No-Delay) ---
# [NEW-11] Deshabilitar Nagle's Algorithm reduce la micro-latencia TCP al enviar
# paquetes inmediatamente en vez de bufferearlos. Beneficio en gaming competitivo online.
# Ref: https://learn.microsoft.com/troubleshoot/windows-server/networking/tcpip-performance-known-issues
if ($applyNagle) {
    Write-Host "  [12.J] Disabling Nagle Algorithm (TCP No-Delay)..." -ForegroundColor Gray
    try {
        # Detectar adaptador de red fisico activo (excluir VPN/virtual)
        $activeAdapter = Get-NetAdapter -ErrorAction Stop |
            Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Virtual|VPN|Hyper-V|WSL|Loopback' } |
            Select-Object -First 1

        if ($activeAdapter) {
            $ifGuid = $activeAdapter.InterfaceGuid
            $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$ifGuid"
            if (Test-Path $tcpPath) {
                Set-Reg $tcpPath 'TcpNoDelay'       1
                Set-Reg $tcpPath 'TcpAckFrequency'  1
                Write-Host "    - Nagle Algorithm DESHABILITADO para: $($activeAdapter.Name) ($($activeAdapter.InterfaceDescription))" -ForegroundColor Green
                Write-Host "      GUID: $ifGuid" -ForegroundColor DarkGray
            } else {
                Write-Host "    ! Ruta TCP no encontrada para GUID $ifGuid" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    ! No se encontro adaptador de red fisico activo." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    ! Nagle disable: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
#endregion

# ============================================================
#region 13. Seccion consolidada en 11.C (MMAgent segun hardware)
# ============================================================
# MMAgent (MemoryCompression, PageCombining) se gestiona automaticamente
# en la seccion 11.C segun el perfil de hardware detectado.
#endregion

# ============================================================
#region 14. DISM component store cleanup
# ============================================================
Write-Host "`n[14] DISM component store cleanup..." -ForegroundColor Cyan
Write-Host "  Libera espacio del WinSxS post-instalacion. Puede tardar varios minutos." -ForegroundColor Gray
Write-Host "  Nota: sin /ResetBase para conservar la capacidad de desinstalar actualizaciones." -ForegroundColor Gray
try {
    $dismResult = & DISM.exe /Online /Cleanup-Image /StartComponentCleanup 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  - DISM cleanup completed." -ForegroundColor Green
    } else {
        Write-Host "  ! DISM exit $LASTEXITCODE" -ForegroundColor Yellow
        Write-Host "    $dismResult" -ForegroundColor DarkGray
    }
} catch {
    Write-Host "  ! DISM failed: $($_.Exception.Message)" -ForegroundColor Yellow
}
#endregion

# ============================================================
#region 15. Restart Explorer
# ============================================================
Write-Host "`n[15] Restarting Explorer to apply visual changes..." -ForegroundColor Cyan
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
#endregion

Write-Host "`n==== Windows setup finished $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====" -ForegroundColor Cyan
Write-Host "  Log guardado en: $log" -ForegroundColor Gray

# ============================================================
#region Resumen de ejecucion
# ============================================================
Write-Host "`n  +---------------------------------------------------------+" -ForegroundColor DarkCyan
Write-Host "  |              RESUMEN DE EJECUCION                       |" -ForegroundColor Cyan
Write-Host "  +---------------------------------------------------------+" -ForegroundColor DarkCyan
Write-Host ("  | Perfil HW   : {0,-37} |" -f $hwProfile)                    -ForegroundColor White
Write-Host ("  | Windows     : {0,-37} |" -f "$winEdition $osDisplayVersion")  -ForegroundColor Gray
Write-Host ("  | Winget      : {0,-37} |" -f $(if($script:HasWinget){'Disponible'}else{'NO disponible (sec 0/2 omitidas)'})) -ForegroundColor $(if($script:HasWinget){'Gray'}else{'Red'})
$missingFinal = ($prerequisites | Where-Object { -not $_.Instalado }).Count
$prereqLabel = if ($missingFinal -eq 0) { 'Todos OK' } else { "$missingFinal faltante(s) al inicio" }
Write-Host ("  | Prereqs     : {0,-37} |" -f $prereqLabel) -ForegroundColor $(if($missingFinal -eq 0){'Gray'}else{'Yellow'})
Write-Host ("  | GameBar/DVR : {0,-37} |" -f $(if($applyGameBar){'Aplicado'}else{'Omitido'}))  -ForegroundColor Gray
Write-Host ("  | HAGS        : {0,-37} |" -f $(if($applyHags){'Aplicado'}else{'Omitido'}))     -ForegroundColor Gray
Write-Host ("  | VBS/HVCI    : {0,-37} |" -f $(if($applyVbs){'Deshabilitado'}else{'Sin cambio'})) -ForegroundColor Gray
Write-Host ("  | Timer fix   : {0,-37} |" -f $(if($applyFixTimer){'Aplicado (bcdedit)'}else{'Omitido'})) -ForegroundColor $(if($applyFixTimer){'Yellow'}else{'Gray'})
Write-Host ("  | Nagle TCP   : {0,-37} |" -f $(if($applyNagle){'Deshabilitado'}else{'Sin cambio'})) -ForegroundColor Gray
Write-Host ("  | Ultimate PP : {0,-37} |" -f $(if($applyUltimate){'Activado'}else{'Omitido'}))  -ForegroundColor Gray
Write-Host "  +---------------------------------------------------------+" -ForegroundColor DarkCyan
#endregion

Write-Host "`n  REINICIA el equipo para que bcdedit, HAGS y servicios tomen efecto." -ForegroundColor Yellow

} finally {
    # Escribir resumen de errores al log antes de cerrar transcript
    Write-LogSummary
    # Stop-Transcript en finally: se ejecuta SIEMPRE, incluso si el script falla a mitad
    try { Stop-Transcript | Out-Null } catch {}
}
