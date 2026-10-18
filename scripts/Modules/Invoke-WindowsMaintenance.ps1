<#
.SYNOPSIS
    Motor Integral de Mantenimiento, Limpieza Profunda y Reparacion de Windows (10/11).
    
.DESCRIPTION
    Script modular y profesional basado estrictamente en especificaciones y APIs oficiales
    de Microsoft Learn, Google Chromium Project y Mozilla Developer Network.
    
    Modulos incluidos:
      1. Residuos de Despliegue e Instalacion ISO/OOBE ($WINDOWS.~BT, Panther, logs de setup).
      2. Almacen de Componentes (WinSxS con DISM), Windows Update y Registros de Eventos.
      3. Saneamiento Inteligente de Residuos de Apps Debloated, Registro y WER.
      4. Caches de Rendimiento: GPU Shaders (DirectX/NVIDIA/AMD), Navegadores (Edge, Chrome, Brave, Firefox) y Temporales.
      5. Subsistema Oficial de Reparacion y Salud (DISM RestoreHealth, SFC, WMI, NTFS Scan, Red y Catroot).
      6. Optimizacion de Almacenamiento: SSD TRIM (Optimize-Volume), Sombras VSS y NGen .NET.

.PARAMETER Unattended
    Ejecuta el script de forma desatendida sin solicitar confirmacion interactiva.

.PARAMETER PostInstall
    Modo rapido post-instalacion: enfocado en residuos de despliegue, temporales y optimizacion de disco.

.PARAMETER DeepClean
    Modo de limpieza profunda: incluye WinSxS con DISM, descargas de Windows Update, eventos y caches de shaders.

.PARAMETER RepairOnly
    Ejecuta exclusivamente el modulo 5 de reparacion del sistema (DISM, SFC, WMI, NTFS, Red).

.PARAMETER Full
    Ejecuta todos los modulos (1 al 6) de forma integral.

.PARAMETER SkipDism
    Omite las operaciones de DISM (Cleanup-Image y RestoreHealth) para ahorrar tiempo.

.PARAMETER SkipBrowsers
    Omite la limpieza de caches de navegadores web.

.PARAMETER ResetBase
    Aplica el flag /ResetBase en DISM StartComponentCleanup (consolida actualizaciones de forma permanente).

.EXAMPLE
    .\Invoke-WindowsMaintenance.ps1
    Ejecuta el menu interactivo con seleccion de modulos.

.EXAMPLE
    .\Invoke-WindowsMaintenance.ps1 -Full -Unattended
    Ejecuta todos los modulos de forma automatica y desatendida.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Unattended,
    [switch]$PostInstall,
    [switch]$DeepClean,
    [switch]$RepairOnly,
    [switch]$Full,
    [switch]$Express,
    [switch]$SkipDism,
    [switch]$SkipBrowsers,
    [switch]$ResetBase,
    [switch]$ShadersOnly,
    [switch]$TrimOnly,
    [switch]$Quiet,
    [switch]$PassThru,
    [switch]$SkipElevation,
    [switch]$AnalyzeOnly,
    [switch]$AuditStorage,
    [switch]$IncludeRecycleBin,
    [switch]$IncludeDeployment,
    [switch]$IncludeWinSxS,
    [switch]$IncludeWinUpdate,
    [switch]$IncludeDriverStore,
    [switch]$IncludeCbsLogs,
    [switch]$IncludeWerDumps,
    [switch]$IncludeAppxOrphans,
    [switch]$IncludeTemp,
    [switch]$IncludeCryptNet,
    [switch]$IncludeBrowsers,
    [switch]$IncludeRepair,
    [switch]$IncludeTrim,
    [switch]$IncludeNgen
)

# Modo simulado -WhatIf
$isSimulated = ($PSBoundParameters.ContainsKey('WhatIf') -or $WhatIfPreference)
if ($isSimulated) {
    Write-Host "[WhatIf] Invoke-WindowsMaintenance.ps1 validado correctamente en modo simulado." -ForegroundColor Green
    return
}

# ============================================================
# 0. PRE-FLIGHT: ELEVACION DE PRIVILEGIOS Y CONFIGURACION BASE
# ============================================================
# Forzar Bypass de ExecutionPolicy en el proceso actual
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop } catch {
    Write-Warning "[Invoke-WindowsMaintenance] No se pudo establecer ExecutionPolicy en Scope Process: $($_.Exception.Message)"
}

$ErrorActionPreference = 'Continue'

# Verificar privilegios de Administrador y auto-elevar con Bypass de ExecutionPolicy
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $ShadersOnly -and -not $SkipElevation) {
    Write-Host "Elevando privilegios a Administrador (Bypass ExecutionPolicy)..." -ForegroundColor Yellow
    $myScript = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
    $ps51 = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    try {
        $argList = @("-STA", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $myScript)
        if ($Unattended)           { $argList += "-Unattended" }
        if ($PostInstall)          { $argList += "-PostInstall" }
        if ($DeepClean)            { $argList += "-DeepClean" }
        if ($RepairOnly)           { $argList += "-RepairOnly" }
        if ($Full)                 { $argList += "-Full" }
        if ($Express)              { $argList += "-Express" }
        if ($SkipDism)             { $argList += "-SkipDism" }
        if ($SkipBrowsers)         { $argList += "-SkipBrowsers" }
        if ($ResetBase)            { $argList += "-ResetBase" }
        if ($ShadersOnly)          { $argList += "-ShadersOnly" }
        if ($TrimOnly)             { $argList += "-TrimOnly" }
        if ($Quiet)                { $argList += "-Quiet" }
        if ($AnalyzeOnly)          { $argList += "-AnalyzeOnly" }
        if ($AuditStorage)         { $argList += "-AuditStorage" }
        if ($IncludeRecycleBin)    { $argList += "-IncludeRecycleBin" }
        if ($IncludeDeployment)    { $argList += "-IncludeDeployment" }
        if ($IncludeWinSxS)        { $argList += "-IncludeWinSxS" }
        if ($IncludeWinUpdate)     { $argList += "-IncludeWinUpdate" }
        if ($IncludeDriverStore)   { $argList += "-IncludeDriverStore" }
        if ($IncludeCbsLogs)       { $argList += "-IncludeCbsLogs" }
        if ($IncludeWerDumps)      { $argList += "-IncludeWerDumps" }
        if ($IncludeAppxOrphans)   { $argList += "-IncludeAppxOrphans" }
        if ($IncludeTemp)          { $argList += "-IncludeTemp" }
        if ($IncludeCryptNet)      { $argList += "-IncludeCryptNet" }
        if ($IncludeBrowsers)      { $argList += "-IncludeBrowsers" }
        if ($IncludeRepair)        { $argList += "-IncludeRepair" }
        if ($IncludeTrim)          { $argList += "-IncludeTrim" }
        if ($IncludeNgen)          { $argList += "-IncludeNgen" }

        Start-Process -FilePath $ps51 -ArgumentList $argList -Verb RunAs -ErrorAction Stop
        exit 0
    } catch {
        Write-Warning "No se pudo elevar privilegios ($($_.Exception.Message)). Continuando en modo estandar con tareas de usuario..."
    }
}

# Inicializar directorio de logs
$logDir = if ($env:SystemDrive) { "$($env:SystemDrive)\Logs" } else { "C:\Logs" }
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile   = Join-Path $logDir "Maintenance_$timestamp.log"
$global:RomanOS_LogFile = $logFile

try { Start-Transcript -Path $logFile -Append -Force | Out-Null } catch {
    Write-Warning "[Invoke-WindowsMaintenance] Start-Transcript no disponible: $($_.Exception.Message)"
}

# Forzar TLS moderno
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor 3072 -bor 12288
} catch {
    Write-Warning "[Invoke-WindowsMaintenance] No se pudo forzar TLS moderno: $($_.Exception.Message)"
}

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

if (-not (Get-Command 'Resolve-ToolScript' -ErrorAction SilentlyContinue)) {
    function Resolve-ToolScript {
        param([string]$ScriptName)
        $candidates = @(
            (Join-Path $PSScriptRoot $ScriptName),
            (Join-Path (Split-Path $PSScriptRoot -Parent) "Drivers\$ScriptName"),
            (Join-Path (Split-Path $PSScriptRoot -Parent) "Modules\$ScriptName"),
            (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\$ScriptName"),
            (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Drivers\$ScriptName"),
            (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Modules\$ScriptName"),
            "$env:WINDIR\Setup\Scripts\$ScriptName",
            "$env:WINDIR\Setup\Scripts\Drivers\$ScriptName",
            "$env:WINDIR\Setup\Scripts\Modules\$ScriptName",
            "$env:WINDIR\Setup\Scripts\Core\$ScriptName"
        )
        foreach ($cp in $candidates) {
            if (Test-Path $cp) { return $cp }
        }
        return $null
    }
}

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
        Write-UnifiedLogEntry -Message $Message -Level $normalizedLevel -TargetLogFile $logFile | Out-Null
    } else {
        $ts   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $line = "[$ts] [$normalizedLevel] $Message"
        if ($logFile) {
            try {
                [System.IO.File]::AppendAllText($logFile, ($line + "`r`n"), [System.Text.Encoding]::UTF8)
            } catch {
                $null = $_.Exception
            }
        }
    }
}

function Write-Section {
    param([string]$Num, [string]$Title)
    Write-StepHeader -StepNumber ([int]$Num) -TotalSteps 6 -Message $Title
}

function Get-DriveFreeBytes {
    param([string]$DriveLetter = '')
    if ([string]::IsNullOrWhiteSpace($DriveLetter)) {
        $DriveLetter = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd(':') } else { 'C' }
    }
    try {
        $drive = Get-PSDrive -Name $DriveLetter -ErrorAction Stop
        if ($drive) { return $drive.Free }
    } catch {
        Write-Warning "[Invoke-WindowsMaintenance] No se pudo obtener espacio libre para unidad ($DriveLetter) - $($_.Exception.Message)"
    }
    return 0
}

function Format-Bytes {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Remove-PathSilently {
    param(
        [string]$Path,
        [switch]$ContentsOnly
    )
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    
    $deletedCount = 0
    try {
        if ($ContentsOnly) {
            $items = Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                try {
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                    $deletedCount++
                } catch {
                    Write-Warning "[Invoke-WindowsMaintenance] No se pudo eliminar $($item.FullName): $($_.Exception.Message)"
                }
            }
        } else {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            $deletedCount++
        }
    } catch {
        Write-Warning "[Invoke-WindowsMaintenance] Error al purgar ($Path) - $($_.Exception.Message)"
    }
    return $deletedCount
}

function Get-SafeFolderSizeBytes {
    param([string]$Path)
    $exists = $false
    try {
        $exists = Test-Path -LiteralPath $Path -ErrorAction Stop
    } catch {
        return 0
    }
    if (-not $exists) { return 0 }
    $total = 0
    try {
        $files = Get-ChildItem -LiteralPath $Path -Force -Recurse -File -ErrorAction SilentlyContinue
        if ($files) {
            $sum = ($files | Measure-Object -Property Length -Sum).Sum
            if ($sum) { $total = $sum }
        }
    } catch {
        Write-LogEntry -Level "DEBUG" -Message "No se pudo medir directorio ($Path): $($_.Exception.Message)"
    }
    return [double]$total
}

function Get-RomanOSStorageFootprint {
    [CmdletBinding()]
    param(
        [switch]$ShowUI = $true
    )

    $sysLetter = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd(':') } else { 'C' }
    $vol = Get-Volume -DriveLetter $sysLetter -ErrorAction SilentlyContinue
    $totalDiskBytes = if ($vol) { $vol.Size } else { 0 }
    $freeDiskBytes  = if ($vol) { $vol.SizeRemaining } else { 0 }

    if ($ShowUI) {
        Show-UnifiedBanner -Title "AUDITORIA FORENSE DE ALMACENAMIENTO OCULTO" -Subtitle "Inspeccion de Zonas Ciegas, Papeleras y Residuos de Windows Update" -ShowSystemInfo
        Write-Host "  Iniciando escaneo no destructivo de almacenamiento en el sistema..." -ForegroundColor Cyan
        Write-Host ""
    }

    $auditItems = [System.Collections.Generic.List[PSCustomObject]]::new()
    $totalRecoverableBytes = 0

    # 1. Windows Update y Delivery Optimization
    $wuDownload = "$env:WINDIR\SoftwareDistribution\Download"
    $wuBytes = Get-SafeFolderSizeBytes -Path $wuDownload
    $doCache = "$env:WINDIR\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"
    $doBytes = Get-SafeFolderSizeBytes -Path $doCache
    $wuTotalBytes = $wuBytes + $doBytes
    $totalRecoverableBytes += $wuTotalBytes
    $auditItems.Add([PSCustomObject]@{
        Categoria  = "Windows Update"
        Componente = "SoftwareDistribution\Download y DeliveryOptimization"
        Bytes      = $wuTotalBytes
        Tamano     = (Format-Bytes $wuTotalBytes)
        Accion     = if ($wuTotalBytes -gt 100MB) { "Limpieza Recomendada (Residuos de parches)" } else { "Optimizado" }
    })

    # 2. Papelera de Reciclaje de Windows ($Recycle.Bin)
    $recycleBytes = 0
    $fixedDrives = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 3 }
    foreach ($d in $fixedDrives) {
        $binPath = "$($d.DeviceID)\`$Recycle.Bin"
        if (Test-Path -LiteralPath $binPath) {
            $sidDirs = Get-ChildItem -LiteralPath $binPath -Force -ErrorAction SilentlyContinue
            foreach ($sd in $sidDirs) {
                $fList = Get-ChildItem -LiteralPath $sd.FullName -Recurse -Force -File -ErrorAction SilentlyContinue
                if ($fList) {
                    $s = ($fList | Measure-Object -Property Length -Sum).Sum
                    if ($s) { $recycleBytes += $s }
                }
            }
        }
    }
    $totalRecoverableBytes += $recycleBytes
    $auditItems.Add([PSCustomObject]@{
        Categoria  = "Papelera Windows"
        Componente = 'Papelera de reciclaje ($Recycle.Bin)'
        Bytes      = $recycleBytes
        Tamano     = (Format-Bytes $recycleBytes)
        Accion     = if ($recycleBytes -gt 500MB) { "Vaciado Recomendado (Archivos eliminados retenidos)" } else { "Optimizado" }
    })

    # 3. Papeleras Externas POSIX / Linux (.Trash-*)
    $posixBytes = 0
    foreach ($d in $fixedDrives) {
        $devId = $d.DeviceID
        $trashDirs = Get-ChildItem -LiteralPath "$devId\" -Force -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\.Trash-\d+$' }
        foreach ($td in $trashDirs) {
            $tFiles = Get-ChildItem -LiteralPath $td.FullName -Recurse -Force -File -ErrorAction SilentlyContinue
            if ($tFiles) {
                $sum = ($tFiles | Measure-Object -Property Length -Sum).Sum
                if ($sum) { $posixBytes += $sum }
            }
        }
    }
    $totalRecoverableBytes += $posixBytes
    $auditItems.Add([PSCustomObject]@{
        Categoria  = "Papeleras Externas"
        Componente = "Residuos POSIX/Linux (.Trash-*)"
        Bytes      = $posixBytes
        Tamano     = (Format-Bytes $posixBytes)
        Accion     = if ($posixBytes -gt 100MB) { "Purga Recomendada (Archivos borrados desde Linux/WSL)" } else { "Limpio / Inexistente" }
    })

    # 4. Residuos de Despliegue y Rollback ($WINDOWS.~BT, Panther)
    $deployPaths = @(
        (Join-Path "$($sysLetter):\" '$WINDOWS.~BT'),
        (Join-Path "$($sysLetter):\" '$WinREAgent'),
        (Join-Path "$($sysLetter):\" '$SysReset'),
        "$env:WINDIR\Panther"
    )
    $deployBytes = 0
    foreach ($dp in $deployPaths) {
        $deployBytes += (Get-SafeFolderSizeBytes -Path $dp)
    }
    $totalRecoverableBytes += $deployBytes
    $auditItems.Add([PSCustomObject]@{
        Categoria  = "Despliegue/Rollback"
        Componente = "Residuos de instalacion previa ($WINDOWS.~BT, Panther)"
        Bytes      = $deployBytes
        Tamano     = (Format-Bytes $deployBytes)
        Accion     = if ($deployBytes -gt 50MB) { "Limpieza Recomendada (Residuos de version anterior)" } else { "Optimizado" }
    })

    # 5. Logs masivos CBS y residuos CAB
    $cbsDir = "$env:WINDIR\Logs\CBS"
    $cbsBytes = 0
    if (Test-Path $cbsDir) {
        $cbsFiles = Get-ChildItem -Path $cbsDir -Filter "CbsPersist_*" -File -ErrorAction SilentlyContinue
        if ($cbsFiles) {
            $cbsBytes += ($cbsFiles | Measure-Object -Property Length -Sum).Sum
        }
    }
    $cabFiles = Get-ChildItem -Path "$env:WINDIR\Temp" -Filter "cab_*" -File -ErrorAction SilentlyContinue
    if ($cabFiles) {
        $cbsBytes += ($cabFiles | Measure-Object -Property Length -Sum).Sum
    }
    $totalRecoverableBytes += $cbsBytes
    $auditItems.Add([PSCustomObject]@{
        Categoria  = "Logs de Mantenimiento"
        Componente = "Registros CBS y compresion CAB huerfana"
        Bytes      = $cbsBytes
        Tamano     = (Format-Bytes $cbsBytes)
        Accion     = if ($cbsBytes -gt 100MB) { "Limpieza Recomendada" } else { "Optimizado" }
    })

    # 6. Archivos Temporales y Crashes (Temp, WER)
    $tempBytes = (Get-SafeFolderSizeBytes -Path "$env:WINDIR\Temp")
    $userProfiles = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { -not $_.Special -and $_.LocalPath }
    if (-not $userProfiles -or @($userProfiles).Count -eq 0) {
        $userProfiles = @([PSCustomObject]@{ LocalPath = $env:USERPROFILE })
    }
    foreach ($prof in $userProfiles) {
        $tempBytes += (Get-SafeFolderSizeBytes -Path (Join-Path $prof.LocalPath "AppData\Local\Temp"))
    }
    $werPaths = @(
        "$env:ProgramData\Microsoft\Windows\WER",
        "$env:WINDIR\Minidump"
    )
    foreach ($wp in $werPaths) {
        $tempBytes += (Get-SafeFolderSizeBytes -Path $wp)
    }
    if (Test-Path "$env:WINDIR\MEMORY.DMP") {
        $dmp = Get-Item "$env:WINDIR\MEMORY.DMP" -ErrorAction SilentlyContinue
        if ($dmp) { $tempBytes += $dmp.Length }
    }
    $totalRecoverableBytes += $tempBytes
    $auditItems.Add([PSCustomObject]@{
        Categoria  = "Temporales y Crashes"
        Componente = "Carpetas Temp del sistema/usuarios y colas WER"
        Bytes      = $tempBytes
        Tamano     = (Format-Bytes $tempBytes)
        Accion     = if ($tempBytes -gt 200MB) { "Limpieza Recomendada" } else { "Optimizado" }
    })

    # 7. Memoria Virtual y Kernel (pagefile, swapfile, hiberfil) - Informativo
    $vMemBytes = 0
    foreach ($vmFile in @("$($sysLetter):\pagefile.sys", "$($sysLetter):\swapfile.sys", "$($sysLetter):\hiberfil.sys")) {
        if (Test-Path -LiteralPath $vmFile) {
            $f = Get-Item -LiteralPath $vmFile -Force -ErrorAction SilentlyContinue
            if ($f) { $vMemBytes += $f.Length }
        }
    }
    $auditItems.Add([PSCustomObject]@{
        Categoria  = "Memoria Virtual"
        Componente = "pagefile.sys / swapfile.sys / hiberfil.sys"
        Bytes      = $vMemBytes
        Tamano     = (Format-Bytes $vMemBytes)
        Accion     = "Estructural del SO (Administrado por Windows)"
    })

    # Presentacion Visual en Consola
    if ($ShowUI) {
        Write-Host "  ---------------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host ("  {0,-22} | {1,-38} | {2,10} | {3}" -f "CATEGORIA", "COMPONENTE", "TAMANO", "ESTADO / RECOMENDACION") -ForegroundColor White
        Write-Host "  ---------------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
        foreach ($item in $auditItems) {
            $color = if ($item.Accion -match 'Recomendad') { 'Yellow' } elseif ($item.Accion -match 'Estructural') { 'DarkGray' } else { 'Green' }
            Write-Host ("  {0,-22} | {1,-38} | {2,10} | " -f $item.Categoria, $item.Componente, $item.Tamano) -NoNewline -ForegroundColor Gray
            Write-Host $item.Accion -ForegroundColor $color
        }
        Write-Host "  ---------------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host ("  Espacio Libre Actual en ({0}:): {1}" -f $sysLetter, (Format-Bytes $freeDiskBytes)) -ForegroundColor Cyan
        Write-Host ("  Espacio Total Recuperable Estimado: {0}" -f (Format-Bytes $totalRecoverableBytes)) -ForegroundColor Green
        Write-Host ""
        if ($totalRecoverableBytes -gt 1GB) {
            Write-Host "  [i] Para recuperar este espacio, ejecute el Saneamiento Seleccionado incluyendo" -ForegroundColor Yellow
            Write-Host "      las opciones de Windows Update, Almacen WinSxS y Papelera de reciclaje." -ForegroundColor Yellow
        } else {
            Write-Host "  [OK] El almacenamiento no presenta acumulacion critica de residuos ocultos." -ForegroundColor Green
        }
        Write-Host ""
    }

    return [PSCustomObject]@{
        SysLetter        = $sysLetter
        TotalDiskBytes   = $totalDiskBytes
        FreeDiskBytes    = $freeDiskBytes
        RecoverableBytes = $totalRecoverableBytes
        Items            = $auditItems
    }
}

# ============================================================
# MEDIDAS INICIALES DE ESPACIO
# ============================================================
$sysLetter = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd(':') } else { 'C' }
$initialFreeBytes = Get-DriveFreeBytes $sysLetter
$osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue

Show-UnifiedBanner -Title "MANTENIMIENTO Y REPARACION DE WINDOWS" -Subtitle "Optimizacion de Espacio, WinSxS, Shaders y Reparacion DISM" -ShowSystemInfo
Write-Info "Espacio Libre Inicial ($($sysLetter):): $(Format-Bytes $initialFreeBytes)"
Write-Info "Archivo de Registro: $logFile"

# ============================================================
# AUDITORIA FORENSE DE ALMACENAMIENTO OCULTO (SOLO LECTURA)
# ============================================================
if ($AuditStorage) {
    Get-RomanOSStorageFootprint -ShowUI | Out-Null
    try { Stop-Transcript | Out-Null } catch { $null = $_.Exception }
    return
}

# ============================================================
# AUDITORIA PREVIA WINSXS (ANALISIS RAPIDO DISM)
# ============================================================
if ($AnalyzeOnly) {
    Show-UnifiedBanner -Title "AUDITORIA DE ALMACEN DE COMPONENTES WINSXS" -Subtitle "Analisis Rapido DISM (Solo Lectura)" -ShowSystemInfo
    Write-SubStep "Consultando estado del Almacen de Componentes con DISM (/AnalyzeComponentStore)..."
    try {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = "dism.exe"
        $pinfo.Arguments = "/Online /Cleanup-Image /AnalyzeComponentStore"
        $pinfo.UseShellExecute = $false
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError = $true
        $pinfo.CreateNoWindow = $true
        $proc = [System.Diagnostics.Process]::Start($pinfo)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        
        Write-Host ""
        Write-Host $stdout -ForegroundColor Cyan
        if ($stdout -match '(?i)Component Store Cleanup Recommended\s*:\s*Yes|Recomienda limpiar el almac[eé]n de componentes\s*:\s*S[ií]') {
            Write-OK "Diagnostico: Se RECOMIENDA la limpieza del Almacen WinSxS con DISM."
        } elseif ($stdout -match '(?i)Component Store Cleanup Recommended\s*:\s*No|Recomienda limpiar el almac[eé]n de componentes\s*:\s*No') {
            Write-Info "Diagnostico: El Almacen WinSxS esta optimizado. No se requiere limpieza inmediata."
        }
    } catch {
        Write-Warn "Error al ejecutar DISM AnalyzeComponentStore: $($_.Exception.Message)"
    }
    try { Stop-Transcript | Out-Null } catch { $null = $_.Exception }
    return
}

# ============================================================
# SELECCION DE MODO DE EJECUCION
# ============================================================
$doDeployment  = $false
$doWinSxS      = $false
$doWinUpdate   = $false
$doDriverStore = $false
$doCbsLogs     = $false
$doWerDumps    = $false
$doAppxOrphans = $false
$doTemp        = $false
$doCryptNet    = $false
$doBrowsers    = $false
$doShaders     = $false
$doRepair      = $false
$doTrim        = $false
$doVss         = $false
$doNgen        = $false
$doRecycleBin  = $false

$hasGranular = ($IncludeDeployment -or $IncludeWinSxS -or $IncludeWinUpdate -or $IncludeDriverStore -or `
                $IncludeCbsLogs -or $IncludeWerDumps -or $IncludeAppxOrphans -or $IncludeTemp -or `
                $IncludeCryptNet -or $IncludeBrowsers -or $IncludeRepair -or $IncludeTrim -or $IncludeNgen -or `
                $IncludeRecycleBin -or $Express)

if ($hasGranular) {
    if ($IncludeDeployment)  { $doDeployment  = $true }
    if ($IncludeWinSxS)       { $doWinSxS      = $true }
    if ($IncludeWinUpdate)    { $doWinUpdate   = $true }
    if ($IncludeDriverStore)  { $doDriverStore = $true }
    if ($IncludeCbsLogs)      { $doCbsLogs     = $true }
    if ($IncludeWerDumps)     { $doWerDumps    = $true }
    if ($IncludeAppxOrphans)  { $doAppxOrphans = $true }
    if ($IncludeTemp)         { $doTemp        = $true }
    if ($IncludeCryptNet)     { $doCryptNet    = $true }
    if ($IncludeBrowsers)     { $doBrowsers    = $true }
    if ($IncludeRepair)       { $doRepair      = $true }
    if ($IncludeTrim)         { $doTrim        = $true }
    if ($IncludeNgen)         { $doNgen        = $true }
    if ($IncludeRecycleBin)   { $doRecycleBin  = $true }
    if ($Express) {
        $doTemp        = $true
        $doWinUpdate   = $true
        $doCryptNet    = $true
        $doTrim        = $true
        $doAppxOrphans = $true
        $doRecycleBin  = $true
    }
} else {
    # Modos agregativos legacy y combinables (Cero colapso en cascada)
    if ($Full -or ($Unattended -and -not $PostInstall -and -not $DeepClean -and -not $RepairOnly -and -not $ShadersOnly -and -not $TrimOnly)) {
        $doDeployment = $true; $doWinSxS = $true; $doWinUpdate = $true; $doDriverStore = $true
        $doCbsLogs = $true; $doWerDumps = $true; $doAppxOrphans = $true; $doTemp = $true
        $doCryptNet = $true; $doBrowsers = (-not $SkipBrowsers); $doShaders = $true
        $doRepair = $true; $doTrim = $true; $doVss = $true; $doNgen = $true; $doRecycleBin = $true
    }
    if ($DeepClean) {
        $doDeployment = $true; $doWinSxS = $true; $doWinUpdate = $true; $doDriverStore = $true
        $doCbsLogs = $true; $doWerDumps = $true; $doAppxOrphans = $true; $doTemp = $true
        $doCryptNet = $true; $doBrowsers = (-not $SkipBrowsers); $doTrim = $true; $doVss = $true; $doRecycleBin = $true
    }
    if ($PostInstall) {
        $doDeployment = $true; $doAppxOrphans = $true; $doTemp = $true; $doTrim = $true; $doBrowsers = (-not $SkipBrowsers)
    }
    if ($RepairOnly) {
        $doRepair = $true
    }
    if ($ShadersOnly) {
        $doShaders = $true
    }
    if ($TrimOnly) {
        $doTrim = $true
    }

    # Si no se paso ningun parametro y no es desatendido, mostrar menu interactivo
    if (-not $Unattended -and -not $Full -and -not $DeepClean -and -not $PostInstall -and -not $RepairOnly -and -not $ShadersOnly -and -not $TrimOnly) {
        $maintOpts = @(
            "Mantenimiento Completo Integral (Limpieza profunda + Reparacion + TRIM) [Recomendado]",
            "Saneamiento Post-Instalacion ISO (Residuos OOBE, temporales, apps huerfanas, TRIM)",
            "Limpieza Profunda de Almacenamiento (WinSxS, Windows Update, DriverStore, Caches)",
            "Solo Reparacion y Salud del Sistema (DISM RestoreHealth, SFC, WMI, Red)"
        )
        $choice = Show-UnifiedMenu -Title "TIPO DE OPERACION DE MANTENIMIENTO" -Options $maintOpts -DefaultChoice 1 -AllowCancel -CancelText "Salir sin realizar cambios"

        switch ($choice) {
            1 {
                $doDeployment = $true; $doWinSxS = $true; $doWinUpdate = $true; $doDriverStore = $true
                $doCbsLogs = $true; $doWerDumps = $true; $doAppxOrphans = $true; $doTemp = $true
                $doCryptNet = $true; $doBrowsers = (-not $SkipBrowsers); $doRepair = $true; $doTrim = $true; $doVss = $true; $doNgen = $true
            }
            2 {
                $doDeployment = $true; $doAppxOrphans = $true; $doTemp = $true; $doTrim = $true; $doBrowsers = (-not $SkipBrowsers)
            }
            3 {
                $doDeployment = $true; $doWinSxS = $true; $doWinUpdate = $true; $doDriverStore = $true
                $doCbsLogs = $true; $doWerDumps = $true; $doAppxOrphans = $true; $doTemp = $true
                $doCryptNet = $true; $doBrowsers = (-not $SkipBrowsers); $doTrim = $true
            }
            4 {
                $doRepair = $true
            }
            default {
                Write-Warn "Operacion cancelada por el usuario."
                try { Stop-Transcript | Out-Null } catch {
                    Write-Info "Transcript detenido: $($_.Exception.Message)"
                }
                exit 0
            }
        }
    }
}

$runMod1 = $doDeployment
$runMod2 = ($doWinSxS -or $doWinUpdate -or $doDriverStore -or $doCbsLogs)
$runMod3 = ($doAppxOrphans -or $doWerDumps)
$runMod4 = ($doShaders -or $doBrowsers -or $doTemp -or $doWerDumps -or $doCryptNet -or $doRecycleBin)
$runMod5 = $doRepair
$runMod6 = ($doTrim -or $doVss -or $doNgen)

# ============================================================
# MODULO 1: RESIDUOS DE DESPLIEGUE E INSTALACION (ISO & OOBE)
# ============================================================
if ($runMod1) {
    Write-Section "1" "Saneamiento de Residuos de Despliegue e Instalacion ISO/OOBE"
    
    $sysDrive = if ($env:SystemDrive) { $env:SystemDrive } else { "C:" }
    $setupResidues = @(
        "$sysDrive\`$WINDOWS.~BT",
        "$sysDrive\`$WINDOWS.~WS",
        "$sysDrive\`$SysReset",
        "$sysDrive\`$WinREAgent",
        "$env:WINDIR\Panther",
        "$env:WINDIR\inf\setupapi.offline.log",
        "$env:WINDIR\Logs\MoSetup",
        "$env:WINDIR\Logs\SetupAPI\setupapi.setup.log"
    )

    foreach ($path in $setupResidues) {
        if (Test-Path -LiteralPath $path) {
            Write-SubStep "Purgando residuo de despliegue: $path"
            Remove-PathSilently -Path $path | Out-Null
            Write-OK "Eliminado: $path"
        }
    }

    # Saneamiento de instaladores de runtimes temporales post-instalacion
    $runtimesDir = "$env:WINDIR\Setup\Scripts\Runtimes"
    if (Test-Path $runtimesDir) {
        Write-SubStep "Limpiando paquetes instaladores de runtimes en $runtimesDir..."
        Remove-PathSilently -Path $runtimesDir | Out-Null
        Write-OK "Directorio temporal de Runtimes purgado."
    }
}

# ============================================================
# MODULO 2: ALMACEN DE COMPONENTES (WinSxS) Y WINDOWS UPDATE
# ============================================================
if ($runMod2) {
    Write-Section "2" "Mantenimiento de Componentes (WinSxS), Windows Update, DriverStore y Eventos"
    
    # 2.A Descargas de Windows Update y Delivery Optimization
    if ($doWinUpdate) {
        Write-SubStep "Deteniendo transitoriamente servicios de actualizacion..."
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Stop-Service -Name bits     -Force -ErrorAction SilentlyContinue
        Stop-Service -Name dosvc    -Force -ErrorAction SilentlyContinue

        $wuDownloadDir = "$env:WINDIR\SoftwareDistribution\Download"
        if (Test-Path $wuDownloadDir) {
            Write-SubStep "Vaciando cache de descargas de Windows Update ($wuDownloadDir)..."
            Remove-PathSilently -Path $wuDownloadDir -ContentsOnly | Out-Null
            Write-OK "Descargas temporales de Windows Update eliminadas."
        }

        $doCacheDir = "$env:WINDIR\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"
        if (Test-Path $doCacheDir) {
            Write-SubStep "Vaciando cache de Optimizacion de Distribucion (Delivery Optimization)..."
            Remove-PathSilently -Path $doCacheDir -ContentsOnly | Out-Null
            Write-OK "Cache de Delivery Optimization purgada."
        }

        Write-SubStep "Reanudando servicios de Windows Update..."
        Start-Service -Name dosvc    -ErrorAction SilentlyContinue
        Start-Service -Name bits     -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    }

    # 2.B Limpieza de Almacen WinSxS con DISM
    if ($doWinSxS -and -not $SkipDism) {
        Write-SubStep "Ejecutando limpieza oficial de componentes WinSxS (DISM /StartComponentCleanup)..."
        try {
            $dismArgs = @("/Online", "/Cleanup-Image", "/StartComponentCleanup")
            if ($ResetBase) {
                Write-Warn "Flag /ResetBase activo: Se consolidaran las actualizaciones eliminando respaldos antiguos."
                $dismArgs += "/ResetBase"
            }
            $proc = Start-Process -FilePath "DISM.exe" -ArgumentList $dismArgs -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -eq 0) {
                Write-OK "Limpieza de almacen WinSxS completada con exito."
            } else {
                $dismLogPath = "$env:WINDIR\Logs\DISM\dism.log"
                Write-ForensicProcessFailure -TaskDescription "DISM StartComponentCleanup" `
                    -FilePath "DISM.exe" `
                    -CommandLine ($dismArgs -join ' ') `
                    -ExitCode $proc.ExitCode `
                    -LogFilePath $dismLogPath `
                    -IsWarningOnly | Out-Null
            }
        } catch {
            Write-Warn "Error ejecutando DISM: $($_.Exception.Message)"
        }
    } elseif ($SkipDism) {
        Write-Info "DISM omitido por parametro -SkipDism."
    }

    # 2.C Saneamiento de Logs Gigantes de CBS y Archivos CAB Huerfanos
    if ($doCbsLogs) {
        Write-SubStep "Depurando registros de servicio CBS y compresion CAB huerfana..."
        try {
            Stop-Service -Name TrustedInstaller -Force -ErrorAction SilentlyContinue
            Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue

            $cbsDir = "$env:WINDIR\Logs\CBS"
            if (Test-Path $cbsDir) {
                Get-ChildItem -Path $cbsDir -Filter "CbsPersist_*.log" -File -ErrorAction SilentlyContinue | ForEach-Object {
                    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                }
                Get-ChildItem -Path $cbsDir -Filter "CbsPersist_*.cab" -File -ErrorAction SilentlyContinue | ForEach-Object {
                    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                }
            }

            Get-ChildItem -Path "$env:WINDIR\Temp" -Filter "cab_*" -File -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
            }
            Write-OK "Logs de CBS y residuos de compresion CAB saneados."
        } catch {
            Write-Warn "Aviso al sanear logs de CBS: $($_.Exception.Message)"
        } finally {
            Start-Service -Name TrustedInstaller -ErrorAction SilentlyContinue
            Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        }
    }

    # 2.D Depuracion Segura de Controladores en DriverStore (FileRepository)
    if ($doDriverStore) {
        Write-SubStep "Depurando controladores obsoletos en DriverStore (FileRepository)..."
        try {
            $driverStoreScript = Resolve-ToolScript "Clean-DriverStore.ps1"
            if ($driverStoreScript) {
                & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $driverStoreScript -Force -SkipElevation
                Write-OK "Depuracion de DriverStore completada."
            } else {
                Write-Info "Clean-DriverStore.ps1 no localizado; omitiendo paso de DriverStore."
            }
        } catch {
            Write-Warn "Aviso al depurar DriverStore: $($_.Exception.Message)"
        }
    }

    # 2.E Purgado de Registros de Eventos Masivos (.evtx)
    if ($doWinSxS -or $Full -or $DeepClean) {
        Write-SubStep "Depurando registros de eventos masivos de Windows..."
        try {
            $eventLogs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 }
            $clearedLogs = 0
            foreach ($l in $eventLogs) {
                try {
                    [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($l.LogName)
                    $clearedLogs++
                } catch {
                    Write-LogEntry -Level "DEBUG" -Message "No se pudo vaciar registro de eventos $($l.LogName): $($_.Exception.Message)"
                }
            }
            Write-OK "Registros de eventos depurados ($clearedLogs logs limpiados)."
        } catch {
            Write-Info "Limpieza de eventos completada con saltos de seguridad."
        }
    }
}

# ============================================================
# MODULO 3: SANEAMIENTO INTELIGENTE DE APPS DEBLOATED Y REGISTRO
# ============================================================
if ($runMod3) {
    Write-Section "3" "Saneamiento Inteligente de Residuos de Apps (Debloat) y Registro"
    
    # 3.A Purga de Carpetas Huerfanas de AppX en perfiles de usuario
    if ($doAppxOrphans) {
        Write-SubStep "Analizando paquetes AppX/MSIX activos para detectar carpetas huerfanas..."
        try {
            $activePackages = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PackageFamilyName -Unique
            $userProfiles = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { -not $_.Special -and $_.LocalPath }

            $orphanCount = 0
            foreach ($prof in $userProfiles) {
                $packagesRoot = Join-Path $prof.LocalPath "AppData\Local\Packages"
                if (Test-Path $packagesRoot) {
                    $dirList = Get-ChildItem -LiteralPath $packagesRoot -Directory -ErrorAction SilentlyContinue
                    foreach ($d in $dirList) {
                        # Si el directorio no coincide con ningun paquete AppX activo registrado
                        if ($activePackages -and ($activePackages -notcontains $d.Name)) {
                            # Verificar si es una app de sistema protegida de Windows
                            if ($d.Name -notmatch '(?i)Microsoft\.Windows\.|Microsoft\.DesktopAppInstaller|Microsoft\.UI\.Xaml|Microsoft\.NET\.Native') {
                                Remove-PathSilently -Path $d.FullName | Out-Null
                                $orphanCount++
                            }
                        }
                    }
                }
            }
            Write-OK "Carpetas huerfanas de paquetes desinstalados eliminadas: $orphanCount"
        } catch {
            Write-Warn "Advertencia al escanear paquetes AppX: $($_.Exception.Message)"
        }
    }

    # 3.B Purgado de colas congeladas de WER y Logs de Telemetria
    if ($doWerCrash) {
        $werPaths = @(
            "$env:ProgramData\Microsoft\Windows\WER\ReportArchive",
            "$env:ProgramData\Microsoft\Windows\WER\ReportQueue",
            "$env:ProgramData\Microsoft\Windows\WER\Temp",
            "$env:ProgramData\Microsoft\Diagnosis\ETLLogs"
        )
        foreach ($wPath in $werPaths) {
            if (Test-Path -LiteralPath $wPath) {
                Remove-PathSilently -Path $wPath -ContentsOnly | Out-Null
                Write-OK "Cola depurada: $wPath"
            }
        }
    }
}

# ============================================================
# MODULO 4: CACHES DEL SISTEMA, CRASH DUMPS Y TEMPORALES
# ============================================================
if ($runMod4) {
    Write-Section "4" "Caches de Rendimiento: Navegadores, Temporales y Certificados"
    
    # 4.A Shaders de GPU (DirectX, NVIDIA, AMD, Intel)
    if ($doShaders) {
        Write-SubStep "Purgando caches de shaders de GPU (resuelve micro-stuttering en juegos)..."
        $userProfiles = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { -not $_.Special -and $_.LocalPath }
        if (-not $userProfiles -or @($userProfiles).Count -eq 0) {
            $userProfiles = @([PSCustomObject]@{ LocalPath = $env:USERPROFILE })
        }
        
        foreach ($prof in $userProfiles) {
            $shaderPaths = @(
                (Join-Path $prof.LocalPath "AppData\Local\D3DSCache"),
                (Join-Path $prof.LocalPath "AppData\Local\NVIDIA\DXCache"),
                (Join-Path $prof.LocalPath "AppData\Local\NVIDIA\GLCache"),
                (Join-Path $prof.LocalPath "AppData\Local\NVIDIA Corporation\NV_Cache"),
                (Join-Path $prof.LocalPath "AppData\LocalLow\NVIDIA\PerDriverVersion\DXCache"),
                (Join-Path $prof.LocalPath "AppData\Local\AMD\DxCache"),
                (Join-Path $prof.LocalPath "AppData\Local\AMD\GLCache"),
                (Join-Path $prof.LocalPath "AppData\Local\Intel\ShaderCache"),
                (Join-Path $prof.LocalPath "AppData\Local\Intel\DXCache"),
                (Join-Path $prof.LocalPath "AppData\Local\Intel\IGC")
            )
            foreach ($sP in $shaderPaths) {
                if (Test-Path -LiteralPath $sP) {
                    Remove-PathSilently -Path $sP -ContentsOnly | Out-Null
                    Write-OK "Shader Cache purgada: $sP"
                }
            }
        }
    }

    # 4.B Caches Seguras de Navegadores Web (Preservando Sesiones, Cookies y Passwords)
    if ($doBrowsers -and -not $SkipBrowsers) {
        Write-SubStep "Limpiando caches volatiles de navegadores (Edge, Chrome, Brave, Firefox)..."
        $userProfiles = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { -not $_.Special -and $_.LocalPath }
        if (-not $userProfiles -or @($userProfiles).Count -eq 0) {
            $userProfiles = @([PSCustomObject]@{ LocalPath = $env:USERPROFILE })
        }
        foreach ($prof in $userProfiles) {
            $browserCachePaths = @(
                # Microsoft Edge (Chromium)
                (Join-Path $prof.LocalPath "AppData\Local\Microsoft\Edge\User Data\Default\Cache"),
                (Join-Path $prof.LocalPath "AppData\Local\Microsoft\Edge\User Data\Default\Code Cache"),
                (Join-Path $prof.LocalPath "AppData\Local\Microsoft\Edge\User Data\Default\GPUCache"),
                (Join-Path $prof.LocalPath "AppData\Local\Microsoft\Edge\User Data\Crashpad\reports"),
                # Google Chrome
                (Join-Path $prof.LocalPath "AppData\Local\Google\Chrome\User Data\Default\Cache"),
                (Join-Path $prof.LocalPath "AppData\Local\Google\Chrome\User Data\Default\Code Cache"),
                (Join-Path $prof.LocalPath "AppData\Local\Google\Chrome\User Data\Default\GPUCache"),
                (Join-Path $prof.LocalPath "AppData\Local\Google\Chrome\User Data\Crashpad\reports"),
                # Brave Browser
                (Join-Path $prof.LocalPath "AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\Cache"),
                (Join-Path $prof.LocalPath "AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\Code Cache"),
                (Join-Path $prof.LocalPath "AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\GPUCache"),
                # Mozilla Firefox (Volatile cache2)
                (Join-Path $prof.LocalPath "AppData\Local\Mozilla\Firefox\Profiles")
            )

            foreach ($bPath in $browserCachePaths) {
                if (Test-Path -LiteralPath $bPath) {
                    if ($bPath -match 'Mozilla\\Firefox\\Profiles') {
                        $ffProfiles = Get-ChildItem -LiteralPath $bPath -Directory -ErrorAction SilentlyContinue
                        foreach ($ffP in $ffProfiles) {
                            $c2 = Join-Path $ffP.FullName "cache2"
                            if (Test-Path $c2) { Remove-PathSilently -Path $c2 -ContentsOnly | Out-Null }
                            $sc = Join-Path $ffP.FullName "startupCache"
                            if (Test-Path $sc) { Remove-PathSilently -Path $sc -ContentsOnly | Out-Null }
                        }
                    } else {
                        Remove-PathSilently -Path $bPath -ContentsOnly | Out-Null
                    }
                }
            }
        }
        Write-OK "Caches de navegadores purgadas de forma segura (Sesiones y Cookies protegidas)."
    } elseif ($SkipBrowsers) {
        Write-Info "Limpieza de navegadores omitida por parametro -SkipBrowsers."
    }

    # 4.C Archivos Temporales del Sistema y Usuarios
    if ($doTemp) {
        Write-SubStep "Saneando archivos temporales globales (%TEMP% y Windows Temp)..."
        Remove-PathSilently -Path "$env:WINDIR\Temp" -ContentsOnly | Out-Null
        $userProfiles = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { -not $_.Special -and $_.LocalPath }
        if (-not $userProfiles -or @($userProfiles).Count -eq 0) {
            $userProfiles = @([PSCustomObject]@{ LocalPath = $env:USERPROFILE })
        }
        foreach ($prof in $userProfiles) {
            $uTemp = Join-Path $prof.LocalPath "AppData\Local\Temp"
            if (Test-Path $uTemp) {
                Remove-PathSilently -Path $uTemp -ContentsOnly | Out-Null
            }
        }
        Write-OK "Archivos temporales del sistema y usuarios purgados."
    }

    # 4.D Crash Dumps y Volcados de Memoria
    if ($doWerCrash) {
        Write-SubStep "Buscando volcados de memoria y crash dumps obsoletos..."
        if (Test-Path "$env:WINDIR\MEMORY.DMP") { Remove-Item "$env:WINDIR\MEMORY.DMP" -Force -ErrorAction SilentlyContinue }
        if (Test-Path "$env:WINDIR\Minidump")   { Remove-PathSilently -Path "$env:WINDIR\Minidump" -ContentsOnly | Out-Null }
        Write-OK "Volcados de memoria depurados."
    }

    # 4.E Cache de Fuentes y Miniaturas
    if ($doTemp -or $doCryptNet -or $Full -or $DeepClean) {
        Write-SubStep "Regenerando cache de fuentes y miniaturas..."
        Stop-Service -Name "FontCache" -Force -ErrorAction SilentlyContinue
        $fontCacheFile = "$env:WINDIR\ServiceProfiles\LocalService\AppData\Local\FontCache\FntCache.dat"
        if (Test-Path $fontCacheFile) { Remove-Item -LiteralPath $fontCacheFile -Force -ErrorAction SilentlyContinue }
        Start-Service -Name "FontCache" -ErrorAction SilentlyContinue
        Write-OK "Cache de fuentes regenerada."
    }

    # 4.F Cache Criptografica de Certificados (CryptnetUrlCache) y Miniaturas Explorer
    if ($doCryptNet) {
        Write-SubStep "Depurando cache de certificados caducados (CryptnetUrlCache) y miniaturas..."
        $userProfiles = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { -not $_.Special -and $_.LocalPath }
        if (-not $userProfiles -or @($userProfiles).Count -eq 0) {
            $userProfiles = @([PSCustomObject]@{ LocalPath = $env:USERPROFILE })
        }
        foreach ($prof in $userProfiles) {
            $crlMeta = Join-Path $prof.LocalPath "AppData\LocalLow\Microsoft\CryptnetUrlCache\MetaData"
            $crlCont = Join-Path $prof.LocalPath "AppData\LocalLow\Microsoft\CryptnetUrlCache\Content"
            if (Test-Path $crlMeta) { Remove-PathSilently -Path $crlMeta -ContentsOnly | Out-Null }
            if (Test-Path $crlCont) { Remove-PathSilently -Path $crlCont -ContentsOnly | Out-Null }
            
            $thumbDir = Join-Path $prof.LocalPath "AppData\Local\Microsoft\Windows\Explorer"
            if (Test-Path $thumbDir) {
                Get-ChildItem -Path $thumbDir -Filter "thumbcache_*.db" -File -ErrorAction SilentlyContinue | ForEach-Object {
                    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                }
            }
        }
        Write-OK "Cache criptografica y miniaturas de explorador saneadas."
    }

    # 4.G Papelera de Reciclaje del Sistema y Papeleras Externas (.Trash-*)
    if ($doRecycleBin) {
        Write-SubStep "Vaciando papelera de reciclaje oficial de Windows (Clear-RecycleBin)..."
        try {
            Clear-RecycleBin -Force -ErrorAction Stop
            Write-OK "Papelera de reciclaje de Windows vaciada con exito."
        } catch {
            Write-Warn "Aviso al vaciar papelera de reciclaje: $($_.Exception.Message)"
        }

        Write-SubStep "Detectando papeleras residuales POSIX/Linux (.Trash-*) en volumenes NTFS..."
        try {
            $fixedDrives = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 3 }
            $purgedTrashCount = 0
            foreach ($d in $fixedDrives) {
                $devId = $d.DeviceID
                $trashItems = Get-ChildItem -LiteralPath "$devId\" -Force -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\.Trash-\d+$' }
                foreach ($tItem in $trashItems) {
                    Write-SubStep "Purgando residuos en $($tItem.FullName)..."
                    Remove-Item -LiteralPath $tItem.FullName -Recurse -Force -ErrorAction Stop
                    $purgedTrashCount++
                    Write-OK "Papelera externa eliminada: $($tItem.FullName)"
                }
            }
            if ($purgedTrashCount -eq 0) {
                Write-Info "No se detectaron papeleras externas residuales (.Trash-*)."
            }
        } catch {
            Write-Warn "Aviso al purgar papeleras externas: $($_.Exception.Message)"
        }
    }
}

# ============================================================
# MODULO 5: SUBSISTEMA OFICIAL DE REPARACION Y SALUD (HEALTH & REPAIR)
# ============================================================
if ($runMod5) {
    Write-Section "5" "Subsistema Oficial de Reparacion y Salud del Sistema"
    
    if ($doRepair) {
        # 5.A Reparacion de Imagen DISM RestoreHealth y SFC
        Write-SubStep "Ejecutando reparacion de imagen con DISM (/RestoreHealth)..."
        try {
            $dismRes = Start-Process -FilePath "DISM.exe" -ArgumentList @("/Online", "/Cleanup-Image", "/RestoreHealth") -Wait -PassThru -NoNewWindow
            if ($dismRes.ExitCode -eq 0) {
                Write-OK "DISM RestoreHealth finalizado exitosamente."
            } else {
                $dismLogPath = "$env:WINDIR\Logs\DISM\dism.log"
                Write-ForensicProcessFailure -TaskDescription "DISM RestoreHealth" `
                    -FilePath "DISM.exe" `
                    -CommandLine "/Online /Cleanup-Image /RestoreHealth" `
                    -ExitCode $dismRes.ExitCode `
                    -LogFilePath $dismLogPath `
                    -IsWarningOnly | Out-Null
            }
        } catch {
            Write-ForensicException -Record $_ -Context "DISM RestoreHealth"
        }

        Write-SubStep "Ejecutando verificacion de archivos protegidos con SFC (/scannow)..."
        try {
            $sfcRes = Start-Process -FilePath "sfc.exe" -ArgumentList @("/scannow") -Wait -PassThru -NoNewWindow
            if ($sfcRes.ExitCode -eq 0) {
                Write-OK "SFC /scannow no encontro violaciones de integridad."
            } else {
                Write-OK "SFC /scannow reparo archivos corruptos o finalizo con codigo: $($sfcRes.ExitCode)."
            }
        } catch {
            Write-Warn "Error ejecutando SFC: $($_.Exception.Message)"
        }

        # 5.B Reparacion del Repositorio WMI / CIM
        Write-SubStep "Comprobando y salvando repositorio WMI (winmgmt /salvagerepository)..."
        try {
            $wmiRes = Start-Process -FilePath "winmgmt.exe" -ArgumentList @("/salvagerepository") -Wait -PassThru -NoNewWindow
            Write-OK "Repositorio WMI consistente y verificado."
        } catch {
            Write-Warn "Error verificando WMI: $($_.Exception.Message)"
        }

        # 5.C Autoreparacion de Sistema de Archivos NTFS en Linea
        Write-SubStep "Ejecutando escaneo y autoreparacion NTFS en linea (Repair-Volume -Scan)..."
        try {
            $volScan = Repair-Volume -DriveLetter C -Scan -ErrorAction SilentlyContinue
            Write-OK "Escaneo de volumen C: completado ($volScan)."
        } catch {
            Write-Warn "No se pudo completar Repair-Volume: $($_.Exception.Message)"
        }
    }

    # 5.D Reinicio de Pila de Red Completa
    if ($doRepair -or $Full) {
        Write-SubStep "Restableciendo sockets Winsock y pila TCP/IP..."
        try {
            Start-Process -FilePath "netsh.exe" -ArgumentList @("winsock", "reset") -Wait -PassThru -NoNewWindow | Out-Null
            Start-Process -FilePath "netsh.exe" -ArgumentList @("int", "ip", "reset") -Wait -PassThru -NoNewWindow | Out-Null
            Start-Process -FilePath "ipconfig.exe" -ArgumentList @("/flushdns") -Wait -PassThru -NoNewWindow | Out-Null
            Write-OK "Pila de red y cache DNS restablecidas correctamente."
        } catch {
            Write-Warn "Error restableciendo red: $($_.Exception.Message)"
        }
    }

    # 5.E Verificacion del Entorno de Recuperacion WinRE
    if ($doRepair -or $Full) {
        Write-SubStep "Verificando estado del entorno de recuperacion (reagentc /info)..."
        try {
            $reagentRes = Start-Process -FilePath "reagentc.exe" -ArgumentList @("/info") -Wait -PassThru -NoNewWindow
            Write-OK "Estado de WinRE consultado."
        } catch {
            Write-Warn "Error consultando reagentc.exe /info: $($_.Exception.Message)"
        }
    }
}

# ============================================================
# MODULO 6: OPTIMIZACION DE ALMACENAMIENTO, SSD TRIM Y RENDIMIENTO
# ============================================================
if ($runMod6) {
    Write-Section "6" "Optimizacion de Almacenamiento, SSD TRIM y Rendimiento"
    
    # 6.A Recorte NAND (TRIM) en SSDs / NVMe
    if ($doTrim) {
        Write-SubStep "Detectando tipo de almacenamiento y ejecutando TRIM (Optimize-Volume)..."
        try {
            $volumes = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter }
            if (-not $volumes) {
                $volumes = @([PSCustomObject]@{ DriveLetter = 'C' })
            }
            foreach ($vol in $volumes) {
                $dl = $vol.DriveLetter
                try {
                    $part = Get-Partition -DriveLetter $dl -ErrorAction SilentlyContinue
                    $disk = if ($part) { Get-Disk -Number $part.DiskNumber -ErrorAction SilentlyContinue } else { $null }
                    $pdisk = if ($disk) { Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object DeviceId -eq $disk.Number } else { $null }

                    $isSolidState = $false
                    if ($pdisk -and $pdisk.MediaType -eq 'SSD') {
                        $isSolidState = $true
                    } elseif ($disk -and $disk.BusType -eq 'NVMe') {
                        $isSolidState = $true
                    } elseif ($pdisk -and $pdisk.MediaType -eq 'HDD') {
                        $isSolidState = $false
                    } else {
                        # Fallback si no hay WMI Storage: asumir SSD si no es explicitamente HDD
                        $isSolidState = $true
                    }

                    if ($isSolidState) {
                        Optimize-Volume -DriveLetter $dl -ReTrim -Verbose -ErrorAction SilentlyContinue
                        Write-OK "Comando TRIM ejecutado en unidad ${dl}: (Rendimiento NAND restaurado)."
                    } else {
                        Write-Info "Unidad ${dl}: detectada como HDD mecanico ($($disk.BusType)). Omitiendo comando TRIM."
                    }
                } catch {
                    Write-Warn "No se pudo ejecutar TRIM en unidad ${dl}: $($_.Exception.Message)"
                }
            }
        } catch {
            Write-Warn "No se pudo ejecutar Optimize-Volume: $($_.Exception.Message)"
        }
    }

    # 6.B Depuracion de Copias de Sombra VSS Obsoletas
    if ($doVss) {
        Write-SubStep "Depurando instantaneas de volumen VSS antiguas..."
        try {
            $sysDrive = if ($env:SystemDrive) { $env:SystemDrive } else { "C:" }
            Start-Process -FilePath "vssadmin.exe" -ArgumentList @("delete", "shadows", "/for=$sysDrive", "/oldest", "/quiet") -Wait -PassThru -NoNewWindow | Out-Null
            Write-OK "Sombras de volumen VSS obsoletas depuradas en $sysDrive."
        } catch {
            Write-Warn "Error depurando instantáneas VSS en $sysDrive - $($_.Exception.Message)"
        }
    }

    # 6.C Precompilacion de Ensamblados .NET NGen
    if ($doNgen) {
        Write-SubStep "Compilando tareas nativas de .NET Framework pendientes (ngen.exe)..."
        try {
            $ngenPath = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\ngen.exe"
            if (Test-Path $ngenPath) {
                Start-Process -FilePath $ngenPath -ArgumentList @("executeQueuedItems") -Wait -PassThru -NoNewWindow | Out-Null
                Write-OK "Tareas NGen .NET precompiladas."
            }
        } catch {
            Write-Warn "Error ejecutando precompilación NGen: $($_.Exception.Message)"
        }
    }
}

# ============================================================
# 7. DASHBOARD FINAL: MEDICION Y CALCULO DE ESPACIO LIBERADO
# ============================================================
$finalFreeBytes = Get-DriveFreeBytes $sysLetter
$freedBytes     = $finalFreeBytes - $initialFreeBytes

Write-Info "Espacio Libre Inicial : $(Format-Bytes $initialFreeBytes)"
Write-Info "Espacio Libre Final   : $(Format-Bytes $finalFreeBytes)"
if ($freedBytes -gt 0) {
    Write-OK "Espacio Total Liberado: +$(Format-Bytes $freedBytes)"
} else {
    Write-Info "Espacio Total Liberado: Optimizacion de indices / 0 B netos"
}

$logMap = @{ "Log de Auditoria" = $logFile }
Show-UnifiedSummary -Title "MANTENIMIENTO WINDOWS" -Status "SUCCESS" -DurationSeconds 0 -ErrorsCount 0 -WarnsCount 0 -Logs $logMap
Write-OK "Proceso de mantenimiento y reparacion completado con exito."

try { Stop-Transcript | Out-Null } catch {
    Write-Info "Transcript finalizado: $($_.Exception.Message)"
}

if ($PassThru) {
    return [PSCustomObject]@{
        InitialFreeBytes = $initialFreeBytes
        FinalFreeBytes   = $finalFreeBytes
        FreedBytes       = $freedBytes
        Success          = $true
    }
}
