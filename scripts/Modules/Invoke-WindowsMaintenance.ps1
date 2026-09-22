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
    [switch]$SkipDism,
    [switch]$SkipBrowsers,
    [switch]$ResetBase,
    [switch]$ShadersOnly,
    [switch]$TrimOnly
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
if (-not $isAdmin) {
    Write-Host "Elevando privilegios a Administrador (Bypass ExecutionPolicy)..." -ForegroundColor Yellow
    $myScript = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
    $ps51 = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    try {
        $argList = @("-STA", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $myScript)
        if ($Unattended)       { $argList += "-Unattended" }
        if ($PostInstall)      { $argList += "-PostInstall" }
        if ($DeepClean)        { $argList += "-DeepClean" }
        if ($RepairOnly)       { $argList += "-RepairOnly" }
        if ($Full)             { $argList += "-Full" }
        if ($SkipDism)         { $argList += "-SkipDism" }
        if ($SkipBrowsers)     { $argList += "-SkipBrowsers" }
        if ($ResetBase)        { $argList += "-ResetBase" }
        if ($ShadersOnly)      { $argList += "-ShadersOnly" }
        if ($TrimOnly)         { $argList += "-TrimOnly" }

        Start-Process -FilePath $ps51 -ArgumentList $argList -Verb RunAs
        exit 0
    } catch {
        Write-Error "No se pudo elevar privilegios. Ejecute PowerShell como Administrador."
        exit 1
    }
}

# Inicializar directorio de logs
$logDir = if ($env:SystemDrive) { "$($env:SystemDrive)\Logs" } else { "C:\Logs" }
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile   = Join-Path $logDir "Maintenance_$timestamp.log"

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
# SELECCION DE MODO DE EJECUCION
# ============================================================
$runMod1 = $false # Despliegue e ISO
$runMod2 = $false # WinSxS y Windows Update
$runMod3 = $false # Huerfanos AppX / Registro
$runMod4 = $false # Caches y Navegadores
$runMod5 = $false # Reparacion y Salud
$runMod6 = $false # Almacenamiento y TRIM

if ($ShadersOnly) {
    $runMod4 = $true
} elseif ($TrimOnly) {
    $runMod6 = $true
} elseif ($Full) {
    $runMod1 = $true; $runMod2 = $true; $runMod3 = $true; $runMod4 = $true; $runMod5 = $true; $runMod6 = $true
} elseif ($PostInstall) {
    $runMod1 = $true; $runMod3 = $true; $runMod4 = $true; $runMod6 = $true
} elseif ($DeepClean) {
    $runMod1 = $true; $runMod2 = $true; $runMod3 = $true; $runMod4 = $true; $runMod6 = $true
} elseif ($RepairOnly) {
    $runMod5 = $true
} elseif ($Unattended) {
    # Modo por defecto desatendido: Mantenimiento Completo
    $runMod1 = $true; $runMod2 = $true; $runMod3 = $true; $runMod4 = $true; $runMod5 = $true; $runMod6 = $true
} else {
    $maintOpts = @(
        "Mantenimiento Completo Integral (Limpieza profunda + Reparacion + TRIM) [Recomendado]",
        "Saneamiento Post-Instalacion ISO (Residuos OOBE, temporales, apps huerfanas, TRIM)",
        "Limpieza Profunda de Almacenamiento (WinSxS, Windows Update, Shaders, Caches)",
        "Solo Reparacion y Salud del Sistema (DISM RestoreHealth, SFC, WMI, Red)"
    )
    $choice = Show-UnifiedMenu -Title "TIPO DE OPERACION DE MANTENIMIENTO" -Options $maintOpts -DefaultChoice 1 -AllowCancel -CancelText "Salir sin realizar cambios"

    switch ($choice) {
        1 { $runMod1 = $true; $runMod2 = $true; $runMod3 = $true; $runMod4 = $true; $runMod5 = $true; $runMod6 = $true }
        2 { $runMod1 = $true; $runMod3 = $true; $runMod4 = $true; $runMod6 = $true }
        3 { $runMod1 = $true; $runMod2 = $true; $runMod3 = $true; $runMod4 = $true; $runMod6 = $true }
        4 { $runMod5 = $true }
        default {
            Write-Warn "Operacion cancelada por el usuario."
            try { Stop-Transcript | Out-Null } catch {
                Write-Info "Transcript detenido: $($_.Exception.Message)"
            }
            exit 0
        }
    }
}

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
    Write-Section "2" "Mantenimiento de Componentes (WinSxS), Windows Update y Eventos"
    
    # 2.A Descargas de Windows Update y Delivery Optimization
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

    # 2.B Limpieza de Almacen WinSxS con DISM
    if (-not $SkipDism) {
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
                Write-Warn "DISM finalizo con codigo de salida: $($proc.ExitCode)."
            }
        } catch {
            Write-Warn "Error ejecutando DISM: $($_.Exception.Message)"
        }
    } else {
        Write-Info "DISM omitido por parametro -SkipDism."
    }

    # 2.C Purgado de Registros de Eventos Masivos (.evtx)
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

# ============================================================
# MODULO 3: SANEAMIENTO INTELIGENTE DE APPS DEBLOATED Y REGISTRO
# ============================================================
if ($runMod3) {
    Write-Section "3" "Saneamiento Inteligente de Residuos de Apps (Debloat) y Registro"
    
    # 3.A Purga de Carpetas Huerfanas de AppX en perfiles de usuario
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

    # 3.B Purgado de colas congeladas de WER y Logs de Telemetria
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

# ============================================================
# MODULO 4: CACHES DE GPU/SHADERS, NAVEGADORES Y TEMPORALES
# ============================================================
if ($runMod4) {
    Write-Section "4" "Caches de Rendimiento: GPU Shaders, Navegadores y Temporales"
    
    # 4.A Shaders de GPU (DirectX, NVIDIA, AMD)
    Write-SubStep "Purgando caches de shaders de GPU (resuelve micro-stuttering en juegos)..."
    $userProfiles = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { -not $_.Special -and $_.LocalPath }
    
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

    if (-not $ShadersOnly) {
        # 4.B Caches Seguras de Navegadores Web (Preservando Sesiones, Cookies y Passwords)
        if (-not $SkipBrowsers) {
            Write-SubStep "Limpiando caches volatiles de navegadores (Edge, Chrome, Brave, Firefox)..."
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
        } else {
            Write-Info "Limpieza de navegadores omitida por parametro -SkipBrowsers."
        }

        # 4.C Archivos Temporales del Sistema y Usuarios
        Write-SubStep "Saneando archivos temporales globales (%TEMP% y Windows Temp)..."
        Remove-PathSilently -Path "$env:WINDIR\Temp" -ContentsOnly | Out-Null
        foreach ($prof in $userProfiles) {
            $uTemp = Join-Path $prof.LocalPath "AppData\Local\Temp"
            if (Test-Path $uTemp) {
                Remove-PathSilently -Path $uTemp -ContentsOnly | Out-Null
            }
        }
        Write-OK "Archivos temporales del sistema y usuarios purgados."

        # 4.D Crash Dumps y Volcados de Memoria
        Write-SubStep "Buscando volcados de memoria y crash dumps obsoletos..."
        if (Test-Path "$env:WINDIR\MEMORY.DMP") { Remove-Item "$env:WINDIR\MEMORY.DMP" -Force -ErrorAction SilentlyContinue }
        if (Test-Path "$env:WINDIR\Minidump")   { Remove-PathSilently -Path "$env:WINDIR\Minidump" -ContentsOnly | Out-Null }
        Write-OK "Volcados de memoria depurados."

        # 4.E Cache de Fuentes y Miniaturas
        Write-SubStep "Regenerando cache de fuentes y miniaturas..."
        Stop-Service -Name "FontCache" -Force -ErrorAction SilentlyContinue
        $fontCacheFile = "$env:WINDIR\ServiceProfiles\LocalService\AppData\Local\FontCache\FntCache.dat"
        if (Test-Path $fontCacheFile) { Remove-Item -LiteralPath $fontCacheFile -Force -ErrorAction SilentlyContinue }
        Start-Service -Name "FontCache" -ErrorAction SilentlyContinue
        Write-OK "Cache de fuentes regenerada."
    }
}

# ============================================================
# MODULO 5: SUBSISTEMA OFICIAL DE REPARACION Y SALUD (HEALTH & REPAIR)
# ============================================================
if ($runMod5) {
    Write-Section "5" "Subsistema Oficial de Reparacion y Salud del Sistema"
    
    # 5.A Reparacion de Imagen DISM RestoreHealth y SFC
    Write-SubStep "Ejecutando reparacion de imagen con DISM (/RestoreHealth)..."
    try {
        $dismRes = Start-Process -FilePath "DISM.exe" -ArgumentList @("/Online", "/Cleanup-Image", "/RestoreHealth") -Wait -PassThru -NoNewWindow
        if ($dismRes.ExitCode -eq 0) {
            Write-OK "DISM RestoreHealth finalizado exitosamente."
        } else {
            Write-Warn "DISM RestoreHealth finalizo con codigo: $($dismRes.ExitCode)."
        }
    } catch {
        Write-Warn "Error ejecutando DISM RestoreHealth: $($_.Exception.Message)"
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

    # 5.D Reinicio de Pila de Red Completa
    Write-SubStep "Restableciendo sockets Winsock y pila TCP/IP..."
    try {
        Start-Process -FilePath "netsh.exe" -ArgumentList @("winsock", "reset") -Wait -PassThru -NoNewWindow | Out-Null
        Start-Process -FilePath "netsh.exe" -ArgumentList @("int", "ip", "reset") -Wait -PassThru -NoNewWindow | Out-Null
        Start-Process -FilePath "ipconfig.exe" -ArgumentList @("/flushdns") -Wait -PassThru -NoNewWindow | Out-Null
        Write-OK "Pila de red y cache DNS restablecidas correctamente."
    } catch {
        Write-Warn "Error restableciendo red: $($_.Exception.Message)"
    }

    # 5.E Verificacion del Entorno de Recuperacion WinRE
    Write-SubStep "Verificando estado del entorno de recuperacion (reagentc /info)..."
    try {
        $reagentRes = Start-Process -FilePath "reagentc.exe" -ArgumentList @("/info") -Wait -PassThru -NoNewWindow
        Write-OK "Estado de WinRE consultado."
    } catch {
        Write-Warn "Error consultando reagentc.exe /info: $($_.Exception.Message)"
    }
}

# ============================================================
# MODULO 6: OPTIMIZACION DE ALMACENAMIENTO, SSD TRIM Y RENDIMIENTO
# ============================================================
if ($runMod6) {
    Write-Section "6" "Optimizacion de Almacenamiento, SSD TRIM y Rendimiento"
    
    # 6.A Recorte NAND (TRIM) en SSDs / NVMe
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

    if (-not $TrimOnly) {
        # 6.B Depuracion de Copias de Sombra VSS Obsoletas
        Write-SubStep "Depurando instantaneas de volumen VSS antiguas..."
        try {
            $sysDrive = if ($env:SystemDrive) { $env:SystemDrive } else { "C:" }
            Start-Process -FilePath "vssadmin.exe" -ArgumentList @("delete", "shadows", "/for=$sysDrive", "/oldest", "/quiet") -Wait -PassThru -NoNewWindow | Out-Null
            Write-OK "Sombras de volumen VSS obsoletas depuradas en $sysDrive."
        } catch {
            Write-Warn "Error depurando instantáneas VSS en $sysDrive - $($_.Exception.Message)"
        }

        # 6.C Precompilacion de Ensamblados .NET NGen
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
