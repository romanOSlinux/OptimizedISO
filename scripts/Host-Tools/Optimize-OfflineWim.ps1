<#
.SYNOPSIS
    romanOS Host Tools - Optimizador y Purgado Offline de Imágenes WIM/ISO.

.DESCRIPTION
    Herramienta de ingeniería offline para purga profunda del almacén de componentes
    de Windows (WinSxS StartComponentCleanup con ResetBase) y reconstrucción multihilo
    del contenedor WIM mediante wimlib-imagex.
    Incluye diagnóstico pre-vuelo de dependencias y auto-aprovisionamiento vía winget.

.PARAMETER ImagePath
    Ruta a la imagen de entrada (.iso o .wim).

.PARAMETER OutputDir
    Carpeta de destino para el archivo procesado. Por defecto se genera en la misma carpeta o subdirectorio.

.PARAMETER OutputFormat
    Formato de salida deseado: "WIM" (estándar LZX), "ESD" (sólido LZMS), "ISO" (reconstrucción estándar WIM) o "ISO-ESD" (reconstrucción ultra-comprimida con ESD sólido).

.PARAMETER WorkDir
    Directorio temporal de trabajo (requiere al menos 35 GB libres).

.PARAMETER ImageIndex
    Índice de imagen dentro del WIM a procesar (predeterminado: 1).

.PARAMETER SkipComponentCleanup
    Omite DISM /ResetBase y realiza únicamente la reconstrucción física con wimlib.

.PARAMETER InstallMissingDependencies
    Si está presente, intenta instalar automáticamente herramientas faltantes (como oscdimg vía winget).

.PARAMETER CheckOnly
    Solo ejecuta el diagnóstico de dependencias y estado sin procesar ninguna imagen.

.PARAMETER Unattended
    Modo desatendido para automatización o ejecución desde romanOS Studio.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [string]$ImagePath = "",

    [Parameter()]
    [string]$OutputDir = "",

    [Parameter()]
    [ValidateSet("WIM", "ESD", "ISO", "ISO-ESD")]
    [string]$OutputFormat = "WIM",

    [Parameter()]
    [string]$WorkDir = "",

    [Parameter()]
    [int]$ImageIndex = 1,

    [Parameter()]
    [switch]$SkipComponentCleanup,

    [Parameter()]
    [switch]$InstallMissingDependencies,

    [Parameter()]
    [switch]$CheckOnly,

    [Parameter()]
    [switch]$Unattended
)

$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# CARGA DE MOTOR VISUAL UNIFICADO O FALLBACK STANDALONE
# -----------------------------------------------------------------------------
$uiEnginePaths = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\UI-Engine.ps1"),
    (Join-Path $PSScriptRoot "Core\UI-Engine.ps1"),
    (Join-Path $PSScriptRoot "..\Core\UI-Engine.ps1"),
    "C:\OptimizedISO\scripts\Core\UI-Engine.ps1",
    "C:\Windows\Setup\Scripts\Core\UI-Engine.ps1"
)
$uiLoaded = $false
foreach ($p in $uiEnginePaths) {
    if (Test-Path -LiteralPath $p) {
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
    function Show-UnifiedSummary { param($Title,$Status,$DurationSeconds,$ErrorsCount,$WarnsCount,$Logs) Write-Host "`n=== $($Title): $Status (${DurationSeconds}s) ===`n" -ForegroundColor Cyan }
}

# -----------------------------------------------------------------------------
# CARGA DE WIMLIB-HELPER
# -----------------------------------------------------------------------------
$wimLibHelperPaths = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\WimLib-Helper.ps1"),
    (Join-Path $PSScriptRoot "..\Core\WimLib-Helper.ps1"),
    "C:\OptimizedISO\scripts\Core\WimLib-Helper.ps1"
)
foreach ($wp in $wimLibHelperPaths) {
    if (Test-Path -LiteralPath $wp) {
        . $wp
        break
    }
}

# -----------------------------------------------------------------------------
# DIAGNÓSTICO PRE-VUELO (PRE-FLIGHT)
# -----------------------------------------------------------------------------
function Find-OscdimgPath {
    [CmdletBinding()]
    param()

    # 1. En PATH
    $cmd = Get-Command "oscdimg.exe" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    # 2. Rutas conocidas de Windows ADK
    $adkPaths = @(
        "${env:ProgramFiles}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
        "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
        "${env:ProgramFiles}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\arm64\Oscdimg\oscdimg.exe"
    )
    foreach ($p in $adkPaths) {
        if (Test-Path -LiteralPath $p) { return $p }
    }

    # 3. Paquetes winget locales
    $wingetPackages = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    if (Test-Path -LiteralPath $wingetPackages) {
        $found = Get-ChildItem -Path $wingetPackages -Recurse -Filter "oscdimg.exe" -ErrorAction SilentlyContinue |
                 Where-Object { $_.FullName -match 'Microsoft\.OSCDIMG' } |
                 Select-Object -First 1
        if ($found) { return $found.FullName }
    }

    return $null
}

function Test-WimOptimizationPrerequisites {
    [CmdletBinding()]
    param(
        [string]$TargetWorkDir = "",
        [string]$RequestedOutputFormat = "WIM"
    )

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    # DISM nativo
    $dismCmd = Get-Command "dism.exe" -ErrorAction SilentlyContinue
    $dismAvailable = ($null -ne $dismCmd)
    $dismPath = if ($dismAvailable) { $dismCmd.Source } else { "$env:SystemRoot\System32\dism.exe" }

    # WimLib
    $wimLibPath = if (Get-Command 'Get-WimLibPath' -ErrorAction SilentlyContinue) {
        Get-WimLibPath
    } else {
        $fixed = "C:\OptimizedISO\tools\wimlib\wimlib-imagex.exe"
        if (Test-Path -LiteralPath $fixed) { $fixed } else {
            $c = Get-Command "wimlib-imagex.exe" -ErrorAction SilentlyContinue
            if ($c) { $c.Source } else { $null }
        }
    }
    $wimLibAvailable = ($null -ne $wimLibPath -and (Test-Path -LiteralPath $wimLibPath))

    # Oscdimg
    $oscdimgPath = Find-OscdimgPath
    $oscdimgAvailable = ($null -ne $oscdimgPath -and (Test-Path -LiteralPath $oscdimgPath))

    # Espacio libre en disco
    $checkDrive = if ($TargetWorkDir) { (Split-Path -Qualifier $TargetWorkDir) } else { $env:SystemDrive }
    $freeSpaceGB = 0
    try {
        $driveObj = [System.IO.DriveInfo]::new($checkDrive)
        $freeSpaceGB = [math]::Round($driveObj.AvailableFreeSpace / 1GB, 1)
    } catch {
        $freeSpaceGB = 999
    }
    $sufficientSpace = ($freeSpaceGB -ge 30)

    # Determinar si todo lo indispensable está listo
    $requiresOscdimg = ($RequestedOutputFormat -in @("ISO", "ISO-ESD"))
    $allRequiredReady = ($isAdmin -and $dismAvailable -and $wimLibAvailable -and $sufficientSpace -and (-not $requiresOscdimg -or $oscdimgAvailable))

    return [PSCustomObject]@{
        IsAdmin           = $isAdmin
        DismAvailable     = $dismAvailable
        DismPath          = $dismPath
        WimLibAvailable   = $wimLibAvailable
        WimLibPath        = $wimLibPath
        OscdimgAvailable  = $oscdimgAvailable
        OscdimgPath       = $oscdimgPath
        RequiresOscdimg   = $requiresOscdimg
        FreeSpaceGB       = $freeSpaceGB
        SufficientSpace   = $sufficientSpace
        AllRequiredReady  = $allRequiredReady
    }
}

function Install-WimOptimizationDependencies {
    [CmdletBinding()]
    param(
        [switch]$InstallOscdimg,
        [switch]$InstallWimLib
    )

    $results = @{}

    if ($InstallOscdimg) {
        Write-StepHeader 1 1 "Instalando Microsoft OSCDIMG (Windows ADK) vía winget..."
        $winget = Get-Command "winget.exe" -ErrorAction SilentlyContinue
        if (-not $winget) {
            Write-ErrorMsg "winget.exe no está disponible en el sistema. Instale Windows ADK manualmente."
            $results["Oscdimg"] = $false
        } else {
            try {
                $p = Start-Process -FilePath "winget.exe" -ArgumentList "install --id Microsoft.OSCDIMG --silent --accept-package-agreements --accept-source-agreements" -NoNewWindow -Wait -PassThru
                $found = Find-OscdimgPath
                if ($found) {
                    Write-OK "oscdimg.exe instalado y detectado en: $found"
                    $results["Oscdimg"] = $true
                } else {
                    Write-Warn "winget finalizó pero oscdimg.exe aún no se detecta en las rutas estándar."
                    $results["Oscdimg"] = $false
                }
            } catch {
                Write-ErrorMsg "Error al ejecutar winget: $($_.Exception.Message)"
                $results["Oscdimg"] = $false
            }
        }
    }

    return $results
}

# -----------------------------------------------------------------------------
# EJECUCIÓN DEL MODO CHECK-ONLY
# -----------------------------------------------------------------------------
if ($CheckOnly) {
    $diag = Test-WimOptimizationPrerequisites -TargetWorkDir $WorkDir -RequestedOutputFormat $OutputFormat
    if (-not $Unattended) {
        Show-UnifiedBanner -Title "romanOS Wim Optimizer" -Subtitle "Diagnostico Pre-Vuelo" -ShowSystemInfo
        Write-Host "Diagnóstico de Dependencias y Requisitos:" -ForegroundColor Cyan
        Write-Host ("  Permisos de Administrador: " + $(if($diag.IsAdmin){"[OK]"}else{"[FALTA] (Requiere RunAs)"})) -ForegroundColor $(if($diag.IsAdmin){"Green"}else{"Red"})
        Write-Host ("  DISM Engine:              " + $(if($diag.DismAvailable){"[OK] $($diag.DismPath)"}else{"[FALTA]"})) -ForegroundColor $(if($diag.DismAvailable){"Green"}else{"Red"})
        Write-Host ("  wimlib-imagex:            " + $(if($diag.WimLibAvailable){"[OK] $($diag.WimLibPath)"}else{"[FALTA]"})) -ForegroundColor $(if($diag.WimLibAvailable){"Green"}else{"Red"})
        Write-Host ("  oscdimg.exe (Para ISO):   " + $(if($diag.OscdimgAvailable){"[OK] $($diag.OscdimgPath)"}else{"[NO DETECTADO] (Opcional si salida es WIM/ESD)"})) -ForegroundColor $(if($diag.OscdimgAvailable){"Green"}else{"Yellow"})
        Write-Host ("  Espacio Libre en Disco:   " + $(if($diag.SufficientSpace){"[OK] $($diag.FreeSpaceGB) GB disponibles"}else{"[ALERTA] $($diag.FreeSpaceGB) GB (Recomendado >= 35 GB)"})) -ForegroundColor $(if($diag.SufficientSpace){"Green"}else{"Yellow"})
        Write-Host ("`nEstado Global: " + $(if($diag.AllRequiredReady){"LISTO PARA OPTIMIZAR"}else{"REQUIERE ATENCION"})) -ForegroundColor $(if($diag.AllRequiredReady){"Green"}else{"Yellow"})
    }
    return $diag
}

# Si se solicitó instalar dependencias faltantes
if ($InstallMissingDependencies) {
    $diag = Test-WimOptimizationPrerequisites -RequestedOutputFormat $OutputFormat
    if (-not $diag.OscdimgAvailable -and ($OutputFormat -in @("ISO", "ISO-ESD"))) {
        Install-WimOptimizationDependencies -InstallOscdimg | Out-Null
    }
}

# -----------------------------------------------------------------------------
# VALIDACIÓN DE ENTRADA Y AMBIENTE
# -----------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($ImagePath)) {
    if (-not $Unattended) {
        Show-UnifiedBanner -Title "romanOS Wim Optimizer" -Subtitle "Purga WinSxS y Reconstruccion" -ShowSystemInfo
        $ImagePath = Read-Host "  Ingrese la ruta de la ISO o archivo WIM a optimizar"
    } else {
        throw "Debe especificar el parámetro -ImagePath."
    }
}

if (-not (Test-Path -LiteralPath $ImagePath)) {
    throw "El archivo especificado no existe: $ImagePath"
}

$diag = Test-WimOptimizationPrerequisites -TargetWorkDir $WorkDir -RequestedOutputFormat $OutputFormat
if (-not $diag.IsAdmin) {
    throw "romanOS Wim Optimizer requiere ejecutarse con privilegios de Administrador (DISM mount / servicing)."
}
if (-not $diag.WimLibAvailable) {
    throw "wimlib-imagex.exe no está disponible en el entorno. Verifique la carpeta tools/wimlib."
}
if (($OutputFormat -in @("ISO", "ISO-ESD")) -and -not $diag.OscdimgAvailable) {
    Write-Warn "oscdimg.exe no está instalado. Intentando auto-instalación vía winget..."
    Install-WimOptimizationDependencies -InstallOscdimg | Out-Null
    $diag = Test-WimOptimizationPrerequisites -RequestedOutputFormat $OutputFormat
    if (-not $diag.OscdimgAvailable) {
        throw "oscdimg.exe es obligatorio para generar una ISO booteable pero no pudo ser instalado automáticamente."
    }
}

# Definir carpetas de trabajo y salida
$imageItem = Get-Item -LiteralPath $ImagePath
$isIsoInput = ($imageItem.Extension -match '\.iso$')

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = $imageItem.DirectoryName
}
if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Saneamiento preventivo de montajes huérfanos previos en romanOS_Scratch
try {
    $staleMounted = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*romanOS_Scratch*" }
    foreach ($sm in $staleMounted) {
        Write-Warn "Desmontando imagen residual de ejecucion previa en $($sm.Path)..."
        & $diag.DismPath /Unmount-Wim /MountDir:"$($sm.Path)" /Discard 2>&1 | Out-Null
    }
} catch {
    & $diag.DismPath /Cleanup-Wim 2>&1 | Out-Null
}

if ([string]::IsNullOrWhiteSpace($WorkDir)) {
    $WorkDir = Join-Path $env:SystemDrive "romanOS_Scratch\WimOpt_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
}
$mountDir   = Join-Path $WorkDir "Mount"
$isoTreeDir = Join-Path $WorkDir "ISO_Tree"

New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
New-Item -ItemType Directory -Path $mountDir -Force | Out-Null

$initialFileBytes = $imageItem.Length
$initialSizeGB    = [math]::Round($initialFileBytes / 1GB, 3)
$startTime        = [System.Diagnostics.Stopwatch]::StartNew()

Show-UnifiedBanner -Title "romanOS Wim Optimizer" -Subtitle "Purga WinSxS y Reconstruccion" -ShowSystemInfo
Write-Host "Archivo de entrada:   $($imageItem.FullName) ($initialSizeGB GB)" -ForegroundColor Cyan
Write-Host "Formato de salida:    $OutputFormat" -ForegroundColor Cyan
Write-Host "Directorio de salida: $OutputDir" -ForegroundColor Cyan
Write-Host "Carpeta de trabajo:   $WorkDir`n" -ForegroundColor DarkGray

$mountedIsoDisk = $null
$workingWimPath = Join-Path $WorkDir "install_source.wim"

try {
    # -------------------------------------------------------------------------
    # PASO 1: EXTRACCIÓN U OBTENCIÓN DEL WIM FUENTE
    # -------------------------------------------------------------------------
    Write-StepHeader 1 4 "Obteniendo imagen de instalacion fuente..."
    if ($isIsoInput) {
        Write-SubStep "Montando ISO con Mount-DiskImage..."
        $mountedIsoDisk = Mount-DiskImage -ImagePath $imageItem.FullName -PassThru -ErrorAction Stop
        Start-Sleep -Milliseconds 1200
        $isoVol = $mountedIsoDisk | Get-Volume -ErrorAction Stop
        $isoDrive = "$($isoVol.DriveLetter):\"

        # Si el formato final es ISO (estándar o ESD sólido), copiamos la estructura base
        if ($OutputFormat -in @("ISO", "ISO-ESD")) {
            Write-SubStep "Copiando estructura base de la ISO a $isoTreeDir..."
            New-Item -ItemType Directory -Path $isoTreeDir -Force | Out-Null
            & robocopy $isoDrive $isoTreeDir /E /XF "install.wim" "install.esd" "install.swm" /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
        }

        # Localizar install.wim o install.esd
        $sourcesPath = Join-Path $isoDrive "sources"
        $srcWim = Join-Path $sourcesPath "install.wim"
        $srcEsd = Join-Path $sourcesPath "install.esd"

        if (Test-Path -LiteralPath $srcWim) {
            Write-SubStep "Copiando install.wim fuente para su modificacion..."
            Copy-Item -LiteralPath $srcWim -Destination $workingWimPath -Force
        } elseif (Test-Path -LiteralPath $srcEsd) {
            Write-SubStep "install.esd detectado. Exportando indice $ImageIndex a WIM para permitir servicing de DISM..."
            $exportCmd = "& `"$($diag.WimLibPath)`" export `"$srcEsd`" $ImageIndex `"$workingWimPath`" --compress=LZX"
            Invoke-Expression $exportCmd | Out-Null
            $ImageIndex = 1 # Tras la exportación a WIM nuevo, el índice queda en 1
        } else {
            throw "No se encontró install.wim ni install.esd dentro de la ISO."
        }

        Dismount-DiskImage -ImagePath $imageItem.FullName -ErrorAction SilentlyContinue | Out-Null
        $mountedIsoDisk = $null
    } else {
        Write-SubStep "Copiando WIM a carpeta de trabajo..."
        Copy-Item -LiteralPath $imageItem.FullName -Destination $workingWimPath -Force
    }

    # Quitar atributo de solo lectura (ReadOnly) heredado del medio ISO
    try {
        $wimItem = Get-Item -LiteralPath $workingWimPath
        if ($wimItem.IsReadOnly) {
            $wimItem.IsReadOnly = $false
        }
        Set-ItemProperty -LiteralPath $workingWimPath -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
        & cmd.exe /c "attrib -R `"$workingWimPath`"" 2>&1 | Out-Null
    } catch {
        Write-Warn "Aviso al remover atributo ReadOnly en ($workingWimPath): $($_.Exception.Message)"
    }

    if (Test-Path -LiteralPath $isoTreeDir) {
        & cmd.exe /c "attrib -R `"$isoTreeDir\*`" /S /D" 2>&1 | Out-Null
    }

    # Asegurar que el directorio de montaje exista, no sea ReadOnly y esté libre de residuos
    if (-not (Test-Path -LiteralPath $mountDir)) {
        New-Item -ItemType Directory -Path $mountDir -Force | Out-Null
    } else {
        $mountChildren = Get-ChildItem -LiteralPath $mountDir -Force -ErrorAction SilentlyContinue
        if ($mountChildren.Count -gt 0) {
            Write-Warn "El directorio de montaje contenía archivos residuales. Ejecutando Cleanup-Wim..."
            & $diag.DismPath /Cleanup-Wim 2>&1 | Out-Null
            Remove-Item -LiteralPath $mountDir -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -ItemType Directory -Path $mountDir -Force | Out-Null
        }
    }
    & cmd.exe /c "attrib -R `"$mountDir`"" 2>&1 | Out-Null

    $wimPreSizeGB = [math]::Round((Get-Item $workingWimPath).Length / 1GB, 3)
    Write-OK "Imagen de trabajo lista ($wimPreSizeGB GB - Atributos R/W garantizados)."

    # -------------------------------------------------------------------------
    # PASO 2: CIRUGÍA CBS CON DISM (/StartComponentCleanup /ResetBase)
    # -------------------------------------------------------------------------
    Write-StepHeader 2 4 "Fase 1: Saneamiento logico de WinSxS con DISM..."
    if ($PSCmdlet.ShouldProcess($workingWimPath, "Montar WIM y ejecutar StartComponentCleanup /ResetBase")) {
        Write-SubStep "Montando indice $ImageIndex en $mountDir..."
        & $diag.DismPath /Mount-Wim /WimFile:"$workingWimPath" /Index:$ImageIndex /MountDir:"$mountDir"
        $mountExit = $LASTEXITCODE
        if ($mountExit -ne 0) {
            throw "Error al montar WIM con DISM. Código de salida: $mountExit"
        }

        if (-not $SkipComponentCleanup) {
            Write-SubStep "Ejecutando DISM /Cleanup-Image /StartComponentCleanup /ResetBase (puede demorar varios minutos)..."
            & $diag.DismPath /Image:"$mountDir" /Cleanup-Image /StartComponentCleanup /ResetBase
            $dismCleanExit = $LASTEXITCODE
            if ($dismCleanExit -eq 0) {
                Write-OK "Almacén WinSxS purgado y consolidado exitosamente."
            } elseif ($dismCleanExit -eq -2146498554 -or $dismCleanExit -eq 0x800F0806) {
                Write-Warn "DISM detectó transacciones pendientes tras slipstream (0x800F0806)."
                Write-Warn "La consolidación profunda de WinSxS se completará automáticamente en el primer arranque del SO."
                if ($OutputFormat -eq "ISO-ESD") {
                    Write-Info "Se aplicará compresión sólida LZMS en la ISO para deduplicar las versiones acumuladas en WinSxS."
                }
            } else {
                Write-Warn "DISM StartComponentCleanup finalizó con código: $dismCleanExit."
            }
        } else {
            Write-Info "StartComponentCleanup /ResetBase omitido por switch -SkipComponentCleanup."
        }

        Write-SubStep "Guardando cambios y desmontando WIM (/Commit)..."
        & $diag.DismPath /Unmount-Wim /MountDir:"$mountDir" /Commit
        $unmountExit = $LASTEXITCODE
        if ($unmountExit -ne 0) {
            throw "Error al desmontar WIM con commit. Código de salida: $unmountExit"
        }
    }

    # -------------------------------------------------------------------------
    # PASO 3: RECONSTRUCCIÓN FÍSICA Y RECOMPRESIÓN CON WIMLIB
    # -------------------------------------------------------------------------
    Write-StepHeader 3 4 "Fase 2: Reconstruccion fisica y compactacion con wimlib-imagex..."
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($imageItem.Name)
    $finalArtifactPath = ""

    if ($OutputFormat -eq "WIM") {
        $finalArtifactPath = Join-Path $OutputDir "${baseName}_Optimized.wim"
        Write-SubStep "Exportando contenedor limpio a $finalArtifactPath con compresión LZX..."
        & $diag.WimLibPath export $workingWimPath $ImageIndex $finalArtifactPath --compress=LZX | Out-Null
    } elseif ($OutputFormat -eq "ESD") {
        $finalArtifactPath = Join-Path $OutputDir "${baseName}_Optimized.esd"
        Write-SubStep "Exportando contenedor ultra-compacto a $finalArtifactPath con compresión sólida LZMS..."
        & $diag.WimLibPath export $workingWimPath $ImageIndex $finalArtifactPath --solid | Out-Null
    } elseif ($OutputFormat -eq "ISO") {
        $wimInIso = Join-Path $isoTreeDir "sources\install.wim"
        Write-SubStep "Inyectando WIM purgado en la estructura de la ISO ($wimInIso)..."
        & $diag.WimLibPath export $workingWimPath $ImageIndex $wimInIso --compress=LZX | Out-Null
    } elseif ($OutputFormat -eq "ISO-ESD") {
        $wimInIso = Join-Path $isoTreeDir "sources\install.wim"
        if (Test-Path -LiteralPath $wimInIso) {
            Remove-Item -LiteralPath $wimInIso -Force -ErrorAction SilentlyContinue
        }
        $esdInIso = Join-Path $isoTreeDir "sources\install.esd"
        Write-SubStep "Inyectando imagen ultra-compacta (ESD Sólido) en la estructura de la ISO ($esdInIso)..."
        & $diag.WimLibPath export $workingWimPath $ImageIndex $esdInIso --solid | Out-Null
    }

    # -------------------------------------------------------------------------
    # PASO 4: REEMPAQUETADO ISO (SI APLICA)
    # -------------------------------------------------------------------------
    if ($OutputFormat -in @("ISO", "ISO-ESD")) {
        Write-StepHeader 4 4 "Fase 3: Reempaquetando imagen ISO booteable con oscdimg..."
        $suffix = if ($OutputFormat -eq "ISO-ESD") { "_ESD_Optimized.iso" } else { "_Optimized.iso" }
        $finalArtifactPath = Join-Path $OutputDir "${baseName}${suffix}"
        
        $etfsboot = Join-Path $isoTreeDir "boot\etfsboot.com"
        $efisys   = Join-Path $isoTreeDir "efi\microsoft\boot\efisys.bin"

        $bootData = "2#p0,e,b$etfsboot#pEF,e,b$efisys"
        $oscdimgArgs = @("-m", "-o", "-u2", "-udfver102", "-bootdata:$bootData", "$isoTreeDir", "$finalArtifactPath")

        Write-SubStep "Compilando ISO dual-boot UEFI/BIOS en $finalArtifactPath..."
        & $diag.OscdimgPath @oscdimgArgs
        $oscdExit = $LASTEXITCODE
        if ($oscdExit -ne 0) {
            throw "Error al compilar la ISO con oscdimg. Código: $oscdExit"
        }
        Write-OK "ISO generada y lista para bootear."
    } else {
        Write-StepHeader 4 4 "Finalizando exportacion..."
    }

    # -------------------------------------------------------------------------
    # CÁLCULO DE MÉTRICAS Y RESUMEN
    # -------------------------------------------------------------------------
    $startTime.Stop()
    $finalItem = Get-Item -LiteralPath $finalArtifactPath
    $finalBytes = $finalItem.Length
    $finalSizeGB = [math]::Round($finalBytes / 1GB, 3)
    $savedBytes = ($initialFileBytes - $finalBytes)
    $savedGB = [math]::Round($savedBytes / 1GB, 3)
    $reductionPercent = if ($initialFileBytes -gt 0) { [math]::Round(($savedBytes / $initialFileBytes) * 100, 1) } else { 0 }

    Write-Host "`n=======================================================" -ForegroundColor Green
    Write-Host "       OPTIMIZACION COMPLETADA EXITOSAMENTE            " -ForegroundColor Green
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host "  Archivo generado:     $($finalItem.FullName)" -ForegroundColor White
    Write-Host "  Tamaño original:      $initialSizeGB GB ($initialFileBytes bytes)"
    Write-Host "  Tamaño optimizado:    $finalSizeGB GB ($finalBytes bytes)" -ForegroundColor Green
    Write-Host "  Espacio ahorrado:     $savedGB GB ($reductionPercent % de reducción)" -ForegroundColor Cyan
    Write-Host "  Tiempo transcurrido:  $([math]::Round($startTime.Elapsed.TotalMinutes, 1)) minutos"
    Write-Host "=======================================================`n" -ForegroundColor Green

    return [PSCustomObject]@{
        Success          = $true
        InputPath        = $imageItem.FullName
        OutputPath       = $finalItem.FullName
        InitialSizeGB    = $initialSizeGB
        FinalSizeGB      = $finalSizeGB
        SavedGB          = $savedGB
        ReductionPercent = $reductionPercent
        DurationSeconds  = [math]::Round($startTime.Elapsed.TotalSeconds, 1)
    }

} catch {
    Write-ErrorMsg "Fallo crítico durante la optimización: $($_.Exception.Message)"
    throw
} finally {
    Write-Host "Limpiando recursos y desmontajes temporales..." -ForegroundColor Gray

    # Desmontar WIM si quedó huérfano
    try {
        $mounted = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*$WorkDir*" }
        foreach ($m in $mounted) {
            Write-Warn "Desmontando imagen residual en $($m.Path)..."
            & $diag.DismPath /Unmount-Wim /MountDir:"$($m.Path)" /Discard 2>&1 | Out-Null
        }
    } catch {
        & $diag.DismPath /Cleanup-Wim 2>&1 | Out-Null
    }

    # Desmontar ISO si seguía montada
    if ($mountedIsoDisk) {
        Dismount-DiskImage -ImagePath $imageItem.FullName -ErrorAction SilentlyContinue | Out-Null
    }

    # Recolección de basura para liberar identificadores de archivos antes de eliminar
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    # Eliminar temporales
    Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
}
