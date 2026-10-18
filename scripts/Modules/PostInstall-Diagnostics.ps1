<#
.SYNOPSIS
    Auditoria y Diagnostico Integral Post-Instalacion de Windows
    Generado por New-OptimizedWindowsISO / romanOS Toolkit Maestro
#>
param(
    [string]$OutputDir = "$env:WINDIR\Setup\Logs",
    [switch]$DesktopOutput,
    [switch]$ShowInNotepad,
    [switch]$ShowReport,
    [switch]$ShowHtml,
    [string]$ExpectedProfile = "1",
    [object]$ExpectedBlockOneDrive = $false,
    [switch]$Quiet,
    [switch]$PassThru,
    [switch]$SkipElevation
)

# Normalizacion tolerante a invocaciones CLI (string 'false'/'true' o int 0/1)
$ExpectedBlockOneDrive = if ($ExpectedBlockOneDrive -is [bool]) { $ExpectedBlockOneDrive } else { ($ExpectedBlockOneDrive -as [string]) -match '^(true|1)$' }

$ErrorActionPreference = 'Continue'

# -----------------------------------------------------------------------------
# CARGA DE MOTOR VISUAL UNIFICADO O MICRO-FALLBACK STANDALONE
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
    function Prompt-UnifiedYesNo { param($Prompt,[bool]$Default=$true) $d=if($Default){"S"}else{"N"}; $r=Read-Host "  [?] $Prompt [S/N] (Default: $d)"; if([string]::IsNullOrWhiteSpace($r)){return $Default}; return ($r -match '^(s|si|y|yes)$') }
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

# -----------------------------------------------------------------------------
# CARGA DE MOTOR DE HARDWARE UNIFICADO (Hardware-Engine.ps1)
# -----------------------------------------------------------------------------
$hwEnginePaths = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\Hardware-Engine.ps1"),
    (Join-Path $PSScriptRoot "Core\Hardware-Engine.ps1"),
    (Join-Path $PSScriptRoot "Hardware-Engine.ps1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\Hardware-Engine.ps1"),
    "$env:WINDIR\Setup\Scripts\Core\Hardware-Engine.ps1",
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
# CARGA DE MOTOR DE POLITICAS UNIFICADO (Core\Policy-Engine.ps1)
# -----------------------------------------------------------------------------
$policyEnginePaths = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\Policy-Engine.ps1"),
    (Join-Path $PSScriptRoot "Core\Policy-Engine.ps1"),
    (Join-Path $PSScriptRoot "Policy-Engine.ps1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\Policy-Engine.ps1"),
    "$env:WINDIR\Setup\Scripts\Core\Policy-Engine.ps1",
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

try {
    if ([string]::IsNullOrWhiteSpace($OutputDir) -or -not (Test-Path $OutputDir)) {
        try {
            if ([string]::IsNullOrWhiteSpace($OutputDir)) { $OutputDir = Join-Path $env:TEMP "romanOS-Diagnostics" }
            New-Item -ItemType Directory -Path $OutputDir -Force -ErrorAction Stop | Out-Null
        } catch {
            $OutputDir = Join-Path $env:TEMP "romanOS-Diagnostics"
            New-Item -ItemType Directory -Path $OutputDir -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }

    $desktopPath = [Environment]::GetFolderPath('Desktop')
    if (-not $desktopPath -or -not (Test-Path $desktopPath)) {
        $desktopPath = [Environment]::GetFolderPath('CommonDesktopDirectory')
        if (-not $desktopPath -or -not (Test-Path $desktopPath)) {
            $desktopPath = if ($env:PUBLIC) { "$env:PUBLIC\Desktop" } else { "C:\Users\Public\Desktop" }
        }
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $reportLines = [System.Collections.Generic.List[string]]::new()
    $criticalErrors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $passedChecks = [System.Collections.Generic.List[string]]::new()

    # Encabezado
    $reportLines.Add("# Reporte de Auditoria y Diagnostico Post-Instalacion")
    $reportLines.Add("")
    $reportLines.Add("- **Fecha de Analisis:** $timestamp")

    # 1. Informacion del Sistema
    $sysInfoData = @{}
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1

        $hwProfile = if ($hwLoaded -and (Get-Command Get-SystemHardwareProfile -ErrorAction SilentlyContinue)) {
            Get-SystemHardwareProfile
        } else { $null }

        $isVM = if ($hwProfile) {
            if ($hwProfile.Platform.IsVirtualMachine) { "Maquina Virtual ($($hwProfile.Platform.VmType))" } else { "Equipo Fisico ($($hwProfile.Platform.ComputerManufacturer) $($hwProfile.Platform.ComputerModel))" }
        } else {
            if ($cs.Model -match 'Virtual|Hyper-V|VMware|KVM|QEMU|VirtualBox') { "Maquina Virtual ($($cs.Model))" } else { "Equipo Fisico ($($cs.Manufacturer) $($cs.Model))" }
        }

        $ramGB = if ($hwProfile) { "$($hwProfile.RAM.TotalGiB) GB $($hwProfile.RAM.MemoryType) ($($hwProfile.RAM.ChannelMode))" } elseif ($cs.TotalPhysicalMemory) { "$([math]::Round($cs.TotalPhysicalMemory / 1GB, 1)) GB" } else { "N/A" }
        $ubr = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name UBR -ErrorAction SilentlyContinue).UBR
        $fullBuild = if ($ubr) { "$($os.Version).$ubr" } else { "$($os.Version)" }

        $sysInfoData['Edicion'] = "$($os.Caption)"
        $sysInfoData['Compilacion'] = "$fullBuild ($($os.OSArchitecture))"
        $sysInfoData['Entorno'] = "$isVM"
        $sysInfoData['CPU'] = "$($cpu.Name)"
        $sysInfoData['RAM'] = "$ramGB"
        $sysInfoData['Equipo'] = "$env:COMPUTERNAME"
        $sysInfoData['Usuario'] = "$env:USERNAME"
        $sysInfoData['Perfil'] = "Perfil $ExpectedProfile"
        if ($hwProfile -and $hwProfile.GPU.PrimaryGpu) {
            $msiTag = if ($hwProfile.GPU.PrimaryGpu.MsiStatus -eq 1) { " [MSI ON]" } else { "" }
            $sysInfoData['GPU'] = "$($hwProfile.GPU.PrimaryGpu.Name) ($($hwProfile.GPU.PrimaryGpu.VendorName))$msiTag"
        }

        $reportLines.Add("- **Edicion:** $($os.Caption)")
        $reportLines.Add("- **Compilacion:** $fullBuild ($($os.OSArchitecture))")
        $reportLines.Add("- **Entorno:** $isVM")
        $reportLines.Add("- **Procesador:** $($cpu.Name)")
        $reportLines.Add("- **Memoria RAM:** $ramGB")
        if ($hwProfile -and $hwProfile.GPU.PrimaryGpu) {
            $msiTag = if ($hwProfile.GPU.PrimaryGpu.MsiStatus -eq 1) { " (MSI Mode Activo)" } else { "" }
            $reportLines.Add("- **Graficos (GPU):** $($hwProfile.GPU.PrimaryGpu.Name) [Vendor: $($hwProfile.GPU.PrimaryGpu.VendorName)]$msiTag")
        }
        if ($hwProfile -and $hwProfile.Disk) {
            $reportLines.Add("- **Disco de Arranque:** $($hwProfile.Disk.DiskLabel) [$($hwProfile.Disk.BootBusType)] - $($hwProfile.Disk.DirectStorageStatus)")
        }
        $reportLines.Add("- **Nombre de Equipo:** $env:COMPUTERNAME")
        $reportLines.Add("- **Usuario Actual:** $env:USERNAME")
        $reportLines.Add("- **Perfil Esperado:** Perfil $ExpectedProfile")
    } catch {
        $reportLines.Add("- **Informacion del Sistema:** Error obteniendo telemetria ($($_.Exception.Message))")
    }

    $reportLines.Add("")

    # 2. Almacenamiento y Huella del Sistema
    $reportLines.Add("## 1. Almacenamiento y Huella del Sistema")
    $reportLines.Add("")
    try {
        $sysDrive = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue)
        if ($sysDrive) {
            $totalGB = [math]::Round($sysDrive.Size / 1GB, 2)
            $freeGB  = [math]::Round($sysDrive.FreeSpace / 1GB, 2)
            $usedGB  = [math]::Round(($sysDrive.Size - $sysDrive.FreeSpace) / 1GB, 2)
            $pctUsed = [math]::Round(($usedGB / $totalGB) * 100, 1)

            $compactStatus = & compact.exe /CompactOS:query 2>&1
            $isCompact = if ($compactStatus -match 'is in the Compact state|est[aá] en el estado Compact') { "Habilitado (CompactOS Activo)" } else { "Deshabilitado (Estandar)" }

            $passedChecks.Add("Almacenamiento C: auditado ($usedGB GB usados de $totalGB GB, $freeGB GB libres).")
            $reportLines.Add("- **Particion C:** $usedGB GB usados / $totalGB GB totales ($pctUsed% ocupado, $freeGB GB libres)")
            $reportLines.Add("- **Compresion CompactOS:** $isCompact")
        }
    } catch {
        $reportLines.Add("- **Almacenamiento:** Error al consultar Win32_LogicalDisk ($($_.Exception.Message))")
    }

    $reportLines.Add("")

    # 3. Auditoria de Windows Setup (Panther y UnattendGC)
    $reportLines.Add("## 2. Auditoria de Logs Oficiales de Windows Setup")
    $reportLines.Add("")

    # Panther\setuperr.log
    $pantherErr = "$env:WINDIR\Panther\setuperr.log"
    if (Test-Path $pantherErr) {
        $errLines = @(Get-Content -Path $pantherErr -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne "" })
        if ($errLines.Count -gt 0) {
            $warnings.Add("Panther\setuperr.log contiene $($errLines.Count) linea(s) de error/advertencia.")
            $reportLines.Add("### [WARN] Windows Setup Base: Panther\setuperr.log ($($errLines.Count) eventos)")
            $reportLines.Add('```text')
            foreach ($l in ($errLines | Select-Object -Last 10)) { $reportLines.Add($l) }
            $reportLines.Add('```')
        } else {
            $passedChecks.Add("Windows Setup Base: Panther\setuperr.log limpio (0 errores).")
            $reportLines.Add("- **Panther\setuperr.log:** Limpio (0 errores detectados) [OK]")
        }
    } else {
        $passedChecks.Add("Windows Setup Base: Panther\setuperr.log sin errores.")
        $reportLines.Add("- **Panther\setuperr.log:** Limpio / Sin errores registrados [OK]")
    }

    # Panther\UnattendGC\setuperr.log
    $unattendErr = "$env:WINDIR\Panther\UnattendGC\setuperr.log"
    if (Test-Path $unattendErr) {
        $uErrLines = @(Get-Content -Path $unattendErr -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne "" })
        if ($uErrLines.Count -gt 0) {
            $criticalErrors.Add("UnattendGC\setuperr.log contiene $($uErrLines.Count) error(es) en autounattend.xml.")
            $reportLines.Add("### [ERROR] OOBE / Unattend: UnattendGC\setuperr.log ($($uErrLines.Count) eventos)")
            $reportLines.Add('```text')
            foreach ($l in ($uErrLines | Select-Object -Last 10)) { $reportLines.Add($l) }
            $reportLines.Add('```')
        } else {
            $passedChecks.Add("Unattend / OOBE: UnattendGC\setuperr.log limpio (0 errores).")
            $reportLines.Add("- **UnattendGC\setuperr.log:** Limpio (0 errores en autounattend.xml) [OK]")
        }
    } else {
        $passedChecks.Add("Unattend / OOBE: UnattendGC\setuperr.log sin errores.")
        $reportLines.Add("- **UnattendGC\setuperr.log:** Limpio / Sin errores registrados [OK]")
    }

    $reportLines.Add("")

    # 4. Auditoria de SetupComplete.cmd y Runtimes
    $reportLines.Add("## 3. Auditoria de SetupComplete.cmd y Runtimes")
    $reportLines.Add("")

    $setupCompleteLog = "$env:WINDIR\Setup\Scripts\SetupComplete.log"
    if (Test-Path $setupCompleteLog) {
        $scContent = Get-Content -Path $setupCompleteLog -Raw -ErrorAction SilentlyContinue
        if ($scContent -match 'SetupComplete\.cmd finalizado exitosamente') {
            $passedChecks.Add("SetupComplete.cmd ejecuto y finalizo exitosamente.")
            $reportLines.Add("- **Estado de SetupComplete.cmd:** Finalizado Exitosamente [OK]")
        } else {
            $warnings.Add("SetupComplete.cmd no registro la marca de finalizacion exitosa.")
            $reportLines.Add("- **Estado de SetupComplete.cmd:** Incompleto o no finalizado [WARN]")
        }
    } else {
        $reportLines.Add("- **Estado de SetupComplete.cmd:** Log no encontrado en $setupCompleteLog")
    }

    # Verificacion de Visual C++ Redistributables
    $vcKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $installedVC = @(Get-ItemProperty $vcKeys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Visual C\+\+' } | Select-Object -ExpandProperty DisplayName -Unique)
    if ($installedVC.Count -gt 0) {
        $passedChecks.Add("Visual C++ Redistributables detectados ($($installedVC.Count) paquetes).")
        $reportLines.Add("- **Visual C++ Runtimes:** $($installedVC.Count) paquete(s) detectado(s) [OK]")
    } else {
        $reportLines.Add("- **Visual C++ Runtimes:** No detectados o no instalados en el paso base.")
    }

    # Plan de energia activo
    $activeScheme = & powercfg -getactivescheme 2>&1
    $reportLines.Add("- **Plan de Energia:** $activeScheme")

    # Auditoria de Esquemas de Energia y Deteccion de Duplicados
    try {
        $allSchemes = & powercfg /list 2>&1
        $schemeLines = @($allSchemes | Where-Object { $_ -match 'GUID' })
        $reportLines.Add("- **Esquemas de Energia Detectados:** $($schemeLines.Count)")
        $ultimateSchemes = @($schemeLines | Where-Object { $_ -match 'M[aá]ximo rendimiento|Ultimate Performance' })
        if ($ultimateSchemes.Count -gt 1) {
            $warnings.Add("Se detectaron $($ultimateSchemes.Count) esquemas duplicados de Maximo Rendimiento. Se recomienda sanear con 'powercfg -restoredefaultschemes'.")
            $reportLines.Add("  -> [WARN] Duplicados de Maximo Rendimiento detectados ($($ultimateSchemes.Count)). Limpieza recomendada.")
        } else {
            $passedChecks.Add("Esquemas de energia limpios (sin duplicados redundantes).")
        }
    } catch {
        Write-Warn -Message "Error al auditar esquemas de energia (powercfg /list)" -Cause $_.Exception.Message -Action "Continuando"
    }

    $reportLines.Add("")

    # 5. Auditoria de Optimizaciones y Bypasses
    $reportLines.Add("## 4. Estado de Tweaks, Registro y Bypasses")
    $reportLines.Add("")

    # BypassNRO
    $bypassNRO = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name BypassNRO -ErrorAction SilentlyContinue).BypassNRO
    if ($bypassNRO -eq 1) {
        $passedChecks.Add("Bypass de Cuenta Microsoft (BypassNRO) verificado.")
        $reportLines.Add("- **Bypass Cuenta Microsoft (BypassNRO):** Habilitado (1) [OK]")
    } else {
        $reportLines.Add("- **Bypass Cuenta Microsoft (BypassNRO):** No configurado o 0")
    }

    # Bloqueo OneDrive
    $odDisable = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name DisableFileSyncNGSC -ErrorAction SilentlyContinue).DisableFileSyncNGSC
    if ($odDisable -eq 1) {
        $passedChecks.Add("Bloqueo de OneDrive verificado.")
        $reportLines.Add("- **Bloqueo de OneDrive (DisableFileSyncNGSC):** Activo (1) [OK]")
    } else {
        if ($ExpectedBlockOneDrive) {
            $warnings.Add("Bloqueo de OneDrive esperado pero no activo en registro.")
            $reportLines.Add("- **Bloqueo de OneDrive:** Deshabilitado / No activo [WARN]")
        } else {
            $reportLines.Add("- **Bloqueo de OneDrive:** Deshabilitado / OneDrive Permitido")
        }
    }

    # Prevencion de Cifrado de Dispositivos BitLocker
    $prevBitLocker = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker" -Name PreventDeviceEncryption -ErrorAction SilentlyContinue).PreventDeviceEncryption
    if ($prevBitLocker -eq 1) {
        $passedChecks.Add("Prevencion de Cifrado BitLocker automatica verificada.")
        $reportLines.Add("- **Prevencion de Cifrado BitLocker:** Activo (PreventDeviceEncryption=1) [OK]")
    } else {
        $reportLines.Add("- **Prevencion de Cifrado BitLocker:** Estandar (Cifrado automatico no restringido)")
    }

    # Optimizacion de Rendimiento NTFS (disablelastaccess)
    try {
        $lastAccessQuery = & fsutil behavior query disablelastaccess 2>&1
        if ($lastAccessQuery -match 'DisableLastAccess\s*=\s*[13]|actualizaciones de la hora de [uú]ltimo acceso DESHABILITADAS|User Managed, Last Access Updates Disabled|System Managed, Last Access Updates Disabled') {
            $passedChecks.Add("Desactivacion de registro de ultimo acceso NTFS verificada.")
            $reportLines.Add("- **Optimizacion NTFS (disablelastaccess):** Activa [OK]")
        } else {
            $reportLines.Add("- **Optimizacion NTFS (disablelastaccess):** Estandar")
        }
    } catch {
        Write-Warn -Message "Error al auditar optimizaciones NTFS (fsutil behavior query disablelastaccess)" -Cause $_.Exception.Message -Action "Continuando con las siguientes comprobaciones"
    }




    # Auditoria HAGS (Hardware-Accelerated GPU Scheduling)
    $hagsVal = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name HwSchMode -ErrorAction SilentlyContinue).HwSchMode
    if ($hagsVal -eq 2) {
        $passedChecks.Add("Hardware-Accelerated GPU Scheduling (HAGS) habilitado.")
        $reportLines.Add("- **GPU Scheduling (HAGS):** Habilitado (HwSchMode=2) [OK]")
    } else {
        $reportLines.Add("- **GPU Scheduling (HAGS):** No forzado o estandar ($hagsVal)")
    }

    # Auditoria BypassIO / DirectStorage en particion del sistema
    try {
        $sysDrive = if ($env:SystemDrive) { $env:SystemDrive } else { "C:" }
        $bypassIoQuery = & fsutil bypassio state $sysDrive 2>&1
        if ($bypassIoQuery -match 'is supported|est[aá] admitido|OK|compatible') {
            $passedChecks.Add("BypassIO / DirectStorage verificado y compatible en particion $sysDrive.")
            $reportLines.Add("- **BypassIO (DirectStorage NVMe):** Soportado y Activo [OK]")
        } else {
            $reportLines.Add("- **BypassIO (DirectStorage NVMe):** No disponible o vetado en este entorno ($sysDrive)")
        }
    } catch {
        Write-Warn -Message "Error al consultar estado de BypassIO en $sysDrive" -Cause $_.Exception.Message -Action "Registrando estado no disponible"
    }


    # Tema Oscuro del Sistema y Apps (PLAN-0030: HKCU prioritario, con fallback a HKLM)
    $cuPersonalize = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ErrorAction SilentlyContinue
    $lmPersonalize = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ErrorAction SilentlyContinue
    $sysTheme = if ($null -ne $cuPersonalize.SystemUsesLightTheme) { $cuPersonalize.SystemUsesLightTheme } else { $lmPersonalize.SystemUsesLightTheme }
    $appTheme = if ($null -ne $cuPersonalize.AppsUseLightTheme) { $cuPersonalize.AppsUseLightTheme } else { $lmPersonalize.AppsUseLightTheme }
    if ($sysTheme -eq 0 -and $appTheme -eq 0) {
        $passedChecks.Add("Tema Oscuro del Sistema y Apps verificado.")
        $reportLines.Add("- **Tema del Sistema y Aplicaciones:** Modo Oscuro Activo (System=0, Apps=0) [OK]")
    } else {
        $reportLines.Add("- **Tema del Sistema y Aplicaciones:** Modo Claro o Estandar")
    }



    # Auditoria de Pila de Red TCP (ECN Capability - PLAN-0034)
    try {
        $tcpGlobal = & netsh.exe int tcp show global 2>&1
        if ($tcpGlobal -match 'ECN Capability\s*:\s*enabled|Capacidad(?: de)? ECN\s*:\s*(?:enabled|habilitado)|Funcionalidad de ECN\s*:\s*(?:enabled|habilitado)') {
            $passedChecks.Add("Notificacion Explicita de Congestion TCP (ECN) verificada y activa.")
            $reportLines.Add("- **TCP ECN Capability:** Habilitado (RFC 3168 - Mitigacion de Bufferbloat) [OK]")
        } else {
            $reportLines.Add("- **TCP ECN Capability:** Deshabilitado o estandar")
        }
    } catch {
        Write-Warn -Message "Error consultando estado TCP ECN Capability" -Cause $_.Exception.Message -Action "Continuando con las siguientes auditorías"
    }

    $reportLines.Add("")

    # 6. Auditoria de Politicas de Controladores y Bloqueo WPBT
    $reportLines.Add("## 5. Auditoria de Politicas de Controladores y Bloqueo WPBT")
    $reportLines.Add("")

    # Excluir drivers en Windows Update
    $excludeDrivers = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name ExcludeWUDriversInQualityUpdate -ErrorAction SilentlyContinue).ExcludeWUDriversInQualityUpdate
    if ($excludeDrivers -eq 1) {
        $passedChecks.Add("Exclusion de controladores en Windows Update verificada.")
        $reportLines.Add("- **Excluir Drivers en Windows Update:** Habilitado (ExcludeWUDriversInQualityUpdate=1) [OK]")
    } else {
        $reportLines.Add("- **Excluir Drivers en Windows Update:** No configurado o conductores automaticos permitidos")
    }

    # Modo de operacion de Windows Update (Manual On-Demand vs Automatico) (PLAN-0059)
    $noAutoUpdate = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name NoAutoUpdate -ErrorAction SilentlyContinue).NoAutoUpdate
    if ($noAutoUpdate -eq 1) {
        $passedChecks.Add("Modo Bajo Demanda (On-Demand) de Windows Update verificado.")
        $reportLines.Add("- **Modo Windows Update:** Bajo Demanda (Manual On-Demand: NoAutoUpdate=1, AUOptions=2) [OK]")
    } else {
        $reportLines.Add("- **Modo Windows Update:** Automatico Estandar (NoAutoUpdate=0 o ausente) [OK]")
    }

    # Estabilidad de Actualizaciones Acumulativas y Bloqueo de Previews (PLAN-0060)
    $allowOpt = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name AllowOptionalContent -ErrorAction SilentlyContinue).AllowOptionalContent
    $deferDays = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name DeferQualityUpdatesPeriodInDays -ErrorAction SilentlyContinue).DeferQualityUpdatesPeriodInDays
    if ($allowOpt -eq 0) {
        $passedChecks.Add("Bloqueo de previews acumulativas y contenido CFR verificado (AllowOptionalContent=0).")
        $reportLines.Add("- **Bloqueo Previews / CFR Beta:** Activo (AllowOptionalContent=0) [OK]")
    } else {
        $reportLines.Add("- **Bloqueo Previews / CFR Beta:** No configurado (Previews permitidas)")
    }
    if ($deferDays -gt 0) {
        $passedChecks.Add("Cuarentena de actualizaciones acumulativas activa ($deferDays dias).")
        $reportLines.Add("- **Cuarentena de Calidad (KIR Window):** Activa ($deferDays dias de maduracion) [OK]")
    } else {
        $reportLines.Add("- **Cuarentena de Calidad (KIR Window):** Sin diferimiento (0 dias)")
    }

    # Busqueda local de drivers (SearchOrderConfig = 0)
    $searchOrder = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name SearchOrderConfig -ErrorAction SilentlyContinue).SearchOrderConfig
    if ($searchOrder -eq 0) {
        $passedChecks.Add("Politica de busqueda de controladores local-only verificada.")
        $reportLines.Add("- **Busqueda de Controladores:** Local-Only (SearchOrderConfig=0) [OK]")
    } else {
        $reportLines.Add("- **Busqueda de Controladores:** En linea y local (SearchOrderConfig=$searchOrder)")
    }

    # Bloqueo de inyeccion OEM WPBT
    $wpbtVal = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name DisableWPBT -ErrorAction SilentlyContinue).DisableWPBT
    if ($wpbtVal -eq 1) {
        $passedChecks.Add("Bloqueo de binarios OEM WPBT verificado.")
        $reportLines.Add("- **Bloqueo Inyeccion OEM WPBT:** Activo (DisableWPBT=1) [OK]")
    } else {
        $reportLines.Add("- **Bloqueo Inyeccion OEM WPBT:** No configurado (0)")
    }

    # Auditoria Dinamica del Catalogo Maestro de Politicas (Policy-Engine)
    $policyResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    if ($policyLoaded -and (Get-Command Get-RomanOSPolicies -ErrorAction SilentlyContinue)) {
        $reportLines.Add("")
        $reportLines.Add("### Directivas Oficiales de Optimizacion (Policy-Engine)")
        $reportLines.Add("")
        $activePolicies = Get-RomanOSPolicies -Profile $ExpectedProfile
        $polPassed = 0

        foreach ($pol in $activePolicies) {
            $tRes = Test-RomanOSPolicy -Policy $pol
            $policyResults.Add([PSCustomObject]@{
                Id          = $pol.Id
                Module      = $pol.Module
                Name        = $pol.ValueName
                Expected    = $pol.ExpectedValue
                Actual      = $tRes.ActualValue
                IsApplied   = $tRes.IsApplied
                StatusText  = $tRes.StatusText
                Description = $pol.Description
            })

            if ($tRes.IsApplied) {
                $polPassed++
                $passedChecks.Add("Directiva [$($pol.Module)]: $($pol.ValueName) = $($pol.ExpectedValue) [OK]")
                $reportLines.Add("- **$($pol.Module) [$($pol.ValueName)]:** $($tRes.StatusText) [OK]")
            } else {
                if ($pol.Id -eq "POL_ONEDRIVE_BLOCK" -and -not $ExpectedBlockOneDrive) {
                    $reportLines.Add("- **$($pol.Module) [$($pol.ValueName)]:** Omitido (OneDrive permitido en perfil)")
                } else {
                    $reportLines.Add("- **$($pol.Module) [$($pol.ValueName)]:** $($tRes.StatusText)")
                }
            }
        }
        $passedChecks.Add("Catalogo de Politicas GPO auditado ($polPassed/$($activePolicies.Count) activas).")
    }

    $reportLines.Add("")

    # 7. Auditoria de Debloat AppX / UWP
    $reportLines.Add("## 6. Auditoria de Paquetes Aprovisionados (AppX / UWP)")
    $reportLines.Add("")
    try {
        $appxList = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue)
        $passedChecks.Add("Paquetes AppX aprovisionados auditados ($($appxList.Count) paquetes detectados).")
        $reportLines.Add("- **Total Paquetes Aprovisionados:** $($appxList.Count)")
        
        $bloatKeywords = @('WebExperience', 'ZuneVideo', 'ZuneMusic', 'BingNews', 'BingWeather', 'GetHelp', 'Getstarted', 'Solitaire', 'People', 'Todos', 'FeedbackHub', 'XboxApp', 'Clipchamp', 'QuickAssist')
        if ($policyLoaded -and $global:RomanOS_KnownBloatAppx) {
            $extraKeywords = @($global:RomanOS_KnownBloatAppx | ForEach-Object { ($_ -split '\.')[-1] })
            $bloatKeywords = @($bloatKeywords + $extraKeywords | Select-Object -Unique)
        }
        $residualBloat = @($appxList | Where-Object { $name = $_.DisplayName; foreach ($k in $bloatKeywords) { if ($name -match $k) { return $true } } $false })
        if ($residualBloat.Count -gt 0) {
            $reportLines.Add("- **Paquetes residuales promocionales detectados ($($residualBloat.Count)):**")
            foreach ($rb in $residualBloat) {
                $reportLines.Add("  - $($rb.DisplayName)")
            }
        } else {
            $passedChecks.Add("Debloat AppX: Cero paquetes promocionales detectados.")
            $reportLines.Add("- **Estado de Debloat:** Limpio / Sin bloatware promocional residual detectado [OK]")
        }

        # Auditoria especifica de Widgets (WebExperience)
        $webExp = @($appxList | Where-Object { $_.DisplayName -like "*WebExperience*" })
        if ($webExp.Count -eq 0) {
            $passedChecks.Add("Debloat Widgets: Paquete MicrosoftWindows.Client.WebExperience eliminado exitosamente [OK].")
            $reportLines.Add("- **Widgets Backend (WebExperience):** Eliminado / 0 paquetes residuales [OK]")
        } else {
            $warnings.Add("Paquete de Widgets WebExperience detectado en la instalacion.")
            $reportLines.Add("- **Widgets Backend (WebExperience):** Detectado ($($webExp.Count) instancias) [WARN]")
        }
    } catch {
        $reportLines.Add("- **Auditoria AppX:** Error al consultar paquetes ($($_.Exception.Message))")
    }

    $reportLines.Add("")

    # 8. Seguridad del Kernel y VBS
    $reportLines.Add("## 7. Seguridad del Kernel y Virtualization-Based Security (VBS)")
    $reportLines.Add("")
    try {
        $dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
        if ($dg) {
            $vbsStatus = switch ($dg.VirtualizationBasedSecurityStatus) {
                0 { "Deshabilitado (0)" }
                1 { "Habilitado pero no en ejecucion (1)" }
                2 { "Habilitado y en ejecucion (2)" }
                default { "Estado ($($dg.VirtualizationBasedSecurityStatus))" }
            }
            $reportLines.Add("- **Virtualization-Based Security (VBS):** $vbsStatus")
            
            $secServices = @()
            if ($dg.SecurityServicesRunning -contains 1) { $secServices += "HVCI (Integridad de Memoria)" }
            if ($dg.SecurityServicesRunning -contains 2) { $secServices += "Credential Guard" }
            if ($secServices.Count -gt 0) {
                $reportLines.Add("- **Servicios de Seguridad Activos:** $($secServices -join ', ')")
            } else {
                $reportLines.Add("- **Servicios de Seguridad Activos:** Ninguno (Maximo rendimiento)")
            }
            $passedChecks.Add("Seguridad del Kernel / DeviceGuard auditado ($vbsStatus).")
        } else {
            $reportLines.Add("- **Win32_DeviceGuard:** No disponible en esta edicion o entorno VM sin virtualizacion anidada.")
        }
    } catch {
        $reportLines.Add("- **DeviceGuard / VBS:** Consulta no disponible ($($_.Exception.Message))")
    }

    $reportLines.Add("")

    # 9. Auditoria de Servicios de Rendimiento
    $reportLines.Add("## 8. Estado de Servicios de Rendimiento")
    $reportLines.Add("")

    $servicesToCheck = @("DiagTrack", "dmwappushservice", "WerSvc", "TroubleshootingSvc", "BDESVC", "Fax", "SCardSvr", "RemoteRegistry", "RetailDemo", "MapsBroker", "lfsvc", "WSearch", "Spooler", "WlanSvc", "bthserv", "SensorService", "SysMain")
    $servicesData = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($sName in $servicesToCheck) {
        $svc = Get-Service -Name $sName -ErrorAction SilentlyContinue
        if ($svc) {
            $startMode = (Get-CimInstance Win32_Service -Filter "Name='$sName'" -ErrorAction SilentlyContinue).StartMode
            $reportLines.Add("- **Servicio $($sName):** Estado: $($svc.Status) | Inicio: $startMode")
            $servicesData.Add([PSCustomObject]@{ Name = $sName; Status = "$($svc.Status)"; StartMode = "$startMode" })
            if ($sName -eq 'SensorService' -and $startMode -eq 'Disabled') {
                $warnings.Add("SensorService esta deshabilitado. En Windows 11 esto provoca el cierre inesperado (crash) de la app Configuracion en 'Energia y bateria' (ms-settings:powersleep). Se debe restaurar a inicio Manual.")
                $reportLines.Add("  -> [WARN] SensorService deshabilitado colapsa la app Configuracion en Windows 11 (ms-settings:powersleep). Se recomienda inicio Manual.")
            }
        } else {
            $reportLines.Add("- **Servicio $($sName):** No instalado en esta edicion.")
            $servicesData.Add([PSCustomObject]@{ Name = $sName; Status = "No instalado"; StartMode = "N/A" })
        }
    }

    $reportLines.Add("")

    # 10. Auditoria de Hardware y Controladores PnP
    $reportLines.Add("## 9. Auditoria de Hardware y Controladores (PnP)")
    $reportLines.Add("")

    try {
        $problemDevices = @(Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'OK' -and $_.Class -ne 'System' -and $_.Problem -ne 'CM_PROB_PHANTOM' })
        if ($problemDevices.Count -gt 0) {
            $warnings.Add("Se detectaron $($problemDevices.Count) dispositivo(s) con advertencia o falta de driver.")
            $reportLines.Add("### [WARN] Dispositivos con problemas detectados ($($problemDevices.Count)):")
            $reportLines.Add("| Dispositivo | Clase | Estado | Codigo de Problema |")
            $reportLines.Add("|---|---|---|---|")
            foreach ($d in $problemDevices) {
                $reportLines.Add("| $($d.FriendlyName) | $($d.Class) | $($d.Status) | $($d.Problem) |")
            }
        } else {
            $passedChecks.Add("Hardware: 0 dispositivos con problemas de controladores.")
            $reportLines.Add("- **Estado de Dispositivos:** Todos los dispositivos PnP inicializados correctamente (0 errores) [OK]")
        }
    } catch {
        $reportLines.Add("- **Auditoria PnP:** Consulta no disponible en este entorno.")
    }

    $reportLines.Add("")

    # 11. Evaluacion Final y Resumen Ejecutivo
    $finalStatus = if ($criticalErrors.Count -gt 0) {
        "FAILED / CON ERRORES"
    } elseif ($warnings.Count -gt 0) {
        "SUCCESS WITH WARNINGS"
    } else {
        "SUCCESS (100% LIMPIO)"
    }

    $summaryLines = @(
        "## Resumen Ejecutivo de Instalacion"
        ""
        "- **Estado General:** **$finalStatus**"
        "- **Verificaciones Aprobadas:** $($passedChecks.Count)"
        "- **Advertencias:** $($warnings.Count)"
        "- **Errores Criticos:** $($criticalErrors.Count)"
        ""
    )

    $finalReport = ($reportLines[0..3] + $summaryLines + $reportLines[4..($reportLines.Count - 1)]) -join "`r`n"

    # Guardar reportes en disco (Markdown)
    $systemReportPath = Join-Path $OutputDir "PostInstall_Report.md"
    $desktopReportPath = Join-Path $desktopPath "INFORME_INSTALACION.md"
    $finalReportPath = $systemReportPath
    try {
        [System.IO.File]::WriteAllText($systemReportPath, $finalReport, [System.Text.Encoding]::UTF8)
    } catch {
        $systemReportPath = Join-Path $env:TEMP "PostInstall_Report.md"
        $finalReportPath = $systemReportPath
        try {
            [System.IO.File]::WriteAllText($systemReportPath, $finalReport, [System.Text.Encoding]::UTF8)
        } catch {
            Write-Warn -Message "No se pudo escribir el informe Markdown en la ruta temporal $systemReportPath" -Cause $_.Exception.Message -Action "El informe no pudo guardarse en disco"
        }
    }
    if ($DesktopOutput) {
        try {
            [System.IO.File]::WriteAllText($desktopReportPath, $finalReport, [System.Text.Encoding]::UTF8)
            $finalReportPath = $desktopReportPath
        } catch {
            Write-Warn -Message "No se pudo copiar el informe al escritorio del usuario." -Cause $_.Exception.Message -Action "El informe permanece disponible en $systemReportPath"
        }
    }

    # Generar Dashboard HTML Offline
    $badgeClassFinal = if ($criticalErrors.Count -gt 0) { 'badge-danger' } elseif ($warnings.Count -gt 0) { 'badge-warn' } else { 'badge-ok' }
    
    $svcRows = [System.Collections.Generic.List[string]]::new()
    foreach ($s in $servicesData) {
        $svcBadge = if ($s.Status -eq 'Stopped' -or $s.StartMode -eq 'Disabled') { 'badge-ok' } elseif ($s.Status -eq 'Running') { 'badge-info' } else { 'badge-warn' }
        $svcRows.Add("<tr><td><strong>$($s.Name)</strong></td><td>$($s.Status)</td><td>$($s.StartMode)</td><td><span class='badge $svcBadge'>$($s.Status)</span></td></tr>")
    }

    $policyRows = [System.Collections.Generic.List[string]]::new()
    if ($policyResults) {
        foreach ($p in $policyResults) {
            $pBadge = if ($p.IsApplied) { 'badge-ok' } else { 'badge-warn' }
            $policyRows.Add("<tr><td><strong>$($p.Module)</strong><br><small style='color:var(--text-muted);'>$($p.Description)</small></td><td><code>$($p.Name)</code></td><td>$($p.Expected)</td><td><span class='badge $pBadge'>$($p.StatusText)</span></td></tr>")
        }
    }

    $htmlContent = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>romanOS - Diagnostico y Auditoria de Instalacion</title>
    <style>
        :root {
            --bg-dark: #0b1329;
            --card-bg: #152238;
            --border-color: #243b55;
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --accent: #38bdf8;
            --ok: #22c55e;
            --warn: #eab308;
            --danger: #ef4444;
            --info: #06b6d4;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif; }
        body { background-color: var(--bg-dark); color: var(--text-main); line-height: 1.6; padding: 30px 20px; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border-color); padding-bottom: 20px; margin-bottom: 25px; flex-wrap: wrap; gap: 15px; }
        .header h1 { font-size: 1.8rem; color: var(--text-main); }
        .header h1 span { color: var(--accent); }
        .header .meta { color: var(--text-muted); font-size: 0.9rem; text-align: right; }
        .score-cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 15px; margin-bottom: 30px; }
        .card { background-color: var(--card-bg); border: 1px solid var(--border-color); border-radius: 10px; padding: 20px; text-align: center; }
        .card-number { font-size: 1.8rem; font-weight: 700; margin-bottom: 5px; }
        .card-label { color: var(--text-muted); font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.5px; }
        .status-val { color: $(if ($criticalErrors.Count -gt 0) { 'var(--danger)' } elseif ($warnings.Count -gt 0) { 'var(--warn)' } else { 'var(--ok)' }); }
        .ok-val { color: var(--ok); }
        .warn-val { color: var(--warn); }
        .danger-val { color: var(--danger); }
        .grid-2 { display: grid; grid-template-columns: repeat(auto-fit, minmax(450px, 1fr)); gap: 20px; margin-bottom: 25px; }
        .section-card { background-color: var(--card-bg); border: 1px solid var(--border-color); border-radius: 10px; padding: 20px; }
        .section-title { font-size: 1.15rem; color: var(--accent); margin-bottom: 15px; border-bottom: 1px solid var(--border-color); padding-bottom: 8px; display: flex; align-items: center; gap: 8px; }
        .info-list { list-style: none; }
        .info-list li { padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.05); font-size: 0.92rem; display: flex; justify-content: space-between; }
        .info-list li:last-child { border-bottom: none; }
        .info-label { color: var(--text-muted); }
        .info-value { font-weight: 600; text-align: right; }
        table { width: 100%; border-collapse: collapse; text-align: left; font-size: 0.9rem; margin-top: 10px; }
        th { background-color: #1a2a44; color: var(--text-muted); font-weight: 600; padding: 10px 12px; border-bottom: 1px solid var(--border-color); text-transform: uppercase; font-size: 0.75rem; }
        td { padding: 10px 12px; border-bottom: 1px solid var(--border-color); }
        tr:hover { background-color: #1d3050; }
        .badge { display: inline-block; padding: 3px 6px; border-radius: 4px; font-size: 0.7rem; font-weight: 700; text-transform: uppercase; }
        .badge-ok { background-color: rgba(34, 197, 94, 0.15); color: var(--ok); border: 1px solid var(--ok); }
        .badge-warn { background-color: rgba(234, 179, 8, 0.15); color: var(--warn); border: 1px solid var(--warn); }
        .badge-danger { background-color: rgba(239, 68, 68, 0.15); color: var(--danger); border: 1px solid var(--danger); }
        .badge-info { background-color: rgba(6, 182, 212, 0.15); color: var(--info); border: 1px solid var(--info); }
        .footer { margin-top: 30px; text-align: center; color: var(--text-muted); font-size: 0.85rem; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div>
                <h1><span>📋 romanOS</span> Informe Post-Instalacion & Diagnostico</h1>
                <div style="color: var(--text-muted);">Auditoria Forense de Despliegue y Salud del Sistema</div>
            </div>
            <div class="meta">
                <div><strong>Equipo:</strong> $env:COMPUTERNAME</div>
                <div><strong>Fecha:</strong> $timestamp</div>
            </div>
        </div>

        <div class="score-cards">
            <div class="card">
                <div class="card-number status-val">$finalStatus</div>
                <div class="card-label">Estado General</div>
            </div>
            <div class="card">
                <div class="card-number ok-val">$($passedChecks.Count)</div>
                <div class="card-label">Verificaciones Aprobadas</div>
            </div>
            <div class="card">
                <div class="card-number warn-val">$($warnings.Count)</div>
                <div class="card-label">Advertencias</div>
            </div>
            <div class="card">
                <div class="card-number danger-val">$($criticalErrors.Count)</div>
                <div class="card-label">Errores Criticos</div>
            </div>
        </div>

        <div class="grid-2">
            <div class="section-card">
                <div class="section-title">💻 Telemetria de Sistema y Entorno</div>
                <ul class="info-list">
                    <li><span class="info-label">Edicion:</span> <span class="info-value">$($sysInfoData['Edicion'])</span></li>
                    <li><span class="info-label">Compilacion:</span> <span class="info-value">$($sysInfoData['Compilacion'])</span></li>
                    <li><span class="info-label">Tipo de Entorno:</span> <span class="info-value">$($sysInfoData['Entorno'])</span></li>
                    <li><span class="info-label">Procesador:</span> <span class="info-value">$($sysInfoData['CPU'])</span></li>
                    <li><span class="info-label">Memoria RAM:</span> <span class="info-value">$($sysInfoData['RAM'])</span></li>
                    <li><span class="info-label">Perfil de Optimizacion:</span> <span class="info-value">$($sysInfoData['Perfil'])</span></li>
                </ul>
            </div>

            <div class="section-card">
                <div class="section-title">💾 Almacenamiento & Logs de Instalacion</div>
                <ul class="info-list">
                    <li><span class="info-label">Particion C:</span> <span class="info-value">$(if ($sysDrive) { "$usedGB GB usados / $freeGB GB libres" } else { "N/A" })</span></li>
                    <li><span class="info-label">Compresion CompactOS:</span> <span class="info-value">$isCompact</span></li>
                    <li><span class="info-label">Panther Setup Base:</span> <span class="info-value">$(if (Test-Path $pantherErr) { "Auditado" } else { "Limpio [OK]" })</span></li>
                    <li><span class="info-label">UnattendGC / OOBE:</span> <span class="info-value">$(if (Test-Path $unattendErr) { "Auditado" } else { "Limpio [OK]" })</span></li>
                    <li><span class="info-label">SetupComplete.cmd:</span> <span class="info-value">$(if ($scContent -match 'SetupComplete\.cmd finalizado exitosamente') { "Finalizado [OK]" } else { "Revisar logs" })</span></li>
                </ul>
            </div>
        </div>

        <div class="section-card" style="margin-bottom: 25px;">
            <div class="section-title">🛡️ Directivas Oficiales de Optimizacion (Policy-Engine)</div>
            <table>
                <thead>
                    <tr>
                        <th>Modulo / Descripcion</th>
                        <th>Parametro (Registro)</th>
                        <th>Valor Esperado</th>
                        <th>Resultado</th>
                    </tr>
                </thead>
                <tbody>
                    $($policyRows -join "`r`n")
                </tbody>
            </table>
        </div>

        <div class="section-card" style="margin-bottom: 25px;">
            <div class="section-title">⚡ Estado de Servicios de Rendimiento y Telemetria</div>
            <table>
                <thead>
                    <tr>
                        <th>Servicio</th>
                        <th>Estado Actual</th>
                        <th>Tipo de Inicio</th>
                        <th>Indicador</th>
                    </tr>
                </thead>
                <tbody>
                    $($svcRows -join "`r`n")
                </tbody>
            </table>
        </div>

        <div class="footer">
            Generado por <strong>romanOS PostInstall Diagnostics</strong> &bull; Auditoria 100% Offline y Desacoplada.
        </div>
    </div>
</body>
</html>
"@

    $systemReportHtmlPath = Join-Path $OutputDir "PostInstall_Report.html"
    $desktopReportHtmlPath = Join-Path $desktopPath "INFORME_INSTALACION.html"
    $finalReportHtmlPath = $systemReportHtmlPath
    try {
        [System.IO.File]::WriteAllText($systemReportHtmlPath, $htmlContent, [System.Text.Encoding]::UTF8)
    } catch {
        $systemReportHtmlPath = Join-Path $env:TEMP "PostInstall_Report.html"
        $finalReportHtmlPath = $systemReportHtmlPath
        try {
            [System.IO.File]::WriteAllText($systemReportHtmlPath, $htmlContent, [System.Text.Encoding]::UTF8)
        } catch {
            Write-Warn -Message "No se pudo escribir el dashboard HTML en la ruta temporal $systemReportHtmlPath" -Cause $_.Exception.Message -Action "El informe HTML no pudo guardarse en disco"
        }
    }
    if ($DesktopOutput) {
        try {
            [System.IO.File]::WriteAllText($desktopReportHtmlPath, $htmlContent, [System.Text.Encoding]::UTF8)
            $finalReportHtmlPath = $desktopReportHtmlPath
        } catch {
            Write-Warn -Message "No se pudo copiar el dashboard HTML al escritorio del usuario." -Cause $_.Exception.Message -Action "El dashboard permanece disponible en $systemReportHtmlPath"
        }
    }

    # Salida en consola
    $logMap = @{
        "Informe Markdown"       = $finalReportPath
        "Dashboard HTML"         = $finalReportHtmlPath
    }
    $diagStatus = if ($criticalErrors.Count -gt 0) { "FAILED" } elseif ($warnings.Count -gt 0) { "WARNING" } else { "SUCCESS" }
    Show-UnifiedSummary -Title "AUDITORIA POST-INSTALACION" -Status $diagStatus -DurationSeconds 0 -ErrorsCount $criticalErrors.Count -WarnsCount $warnings.Count -Logs $logMap

    if ($ShowInNotepad) {
        Start-Process -FilePath "notepad.exe" -ArgumentList $finalReportPath
    }
    if ($ShowHtml -or $ShowReport) {
        Start-Process -FilePath $finalReportHtmlPath
    }

    if ($PassThru) {
        return [PSCustomObject]@{
            Status         = $diagStatus
            CriticalErrors = $criticalErrors.Count
            Warnings       = $warnings.Count
            PassedChecks   = $passedChecks.Count
            MarkdownReport = $finalReportPath
            HtmlReport     = $finalReportHtmlPath
            Success        = ($criticalErrors.Count -eq 0)
        }
    }
} catch {
    Write-Host "[ERROR] Excepcion durante la auditoria post-instalacion: $($_.Exception.Message)" -ForegroundColor Red
}
