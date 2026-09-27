<#
.SYNOPSIS
    Deploy-AppProfiles.ps1 - Gestor Modular de Perfiles de Software y Runtimes de IA
    Ecosistema romanOS / OptimizedISO (Windows 11 24H2 / 25H2).

.DESCRIPTION
    Orquesta la instalacion automatizada, desatendida y silenciosa de software curado,
    bibliotecas de tiempo de ejecucion (Visual C++, DirectX, .NET) y aceleradores de
    Inteligencia Artificial local (Ollama, DirectML, ONNX, Python).
    
    Integra deteccion adaptativa de hardware mediante Hardware-Engine.ps1 para instalar
    automaticamente componentes de GPU (NVIDIA / AMD / Intel Arc) y aceleradores NPU.

.PARAMETER Profile
    Perfil de software a desplegar: 'EsportsGamer', 'CreatorStreamer', 'AIAndDeveloper', 'Essential', 'All', 'None'.

.PARAMETER Categories
    Lista de nombres de categorías curadas a desplegar (ej. 'Browsers', 'Gaming', 'Development', 'Utilities').

.PARAMETER ListCatalog
    Muestra en consola las categorías y paquetes disponibles en el catálogo sin requerir elevación ni instalar nada.

.PARAMETER InstallRuntimesOnly
    Instala exclusivamente las bibliotecas de sistema base (Visual C++, DirectX, .NET).

.PARAMETER IncludeRuntimes
    Si esta activo ($true por defecto), instala los runtimes del sistema antes del perfil seleccionado.

.PARAMETER AutoDetectHardware
    Inspecciona la topologia de hardware (GPU y NPU) y anade automaticamente el software oficial del fabricante.

.PARAMETER CustomPackages
    Lista de IDs de paquetes de winget personalizados para instalar.

.PARAMETER CatalogPath
    Ruta fisica al archivo JSON del catalogo maestro (App-Profiles-Catalog.json).

.PARAMETER Unattended
    Omite confirmaciones interactivas e instala de forma completamente silenciosa.

.PARAMETER SkipElevation
    Omite la comprobacion obligatoria de privilegios de Administrador (para tests, simulaciones o sandbox).

.PARAMETER LogPath
    Ruta del archivo donde se registraran los eventos de instalacion.

.EXAMPLE
    .\Deploy-AppProfiles.ps1 -Profile EsportsGamer -AutoDetectHardware
    .\Deploy-AppProfiles.ps1 -Categories Browsers,Utilities -WhatIf
    .\Deploy-AppProfiles.ps1 -ListCatalog
    .\Deploy-AppProfiles.ps1 -InstallRuntimesOnly
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('EsportsGamer', 'CreatorStreamer', 'AIAndDeveloper', 'Essential', 'All', 'Custom', 'None')]
    [string]$Profile = 'None',

    [string[]]$Categories = @(),

    [switch]$ListCatalog,

    [switch]$InstallRuntimesOnly,

    [bool]$IncludeRuntimes = $true,

    [switch]$AutoDetectHardware,

    [string[]]$CustomPackages = @(),

    [string]$CatalogPath = '',

    [switch]$Unattended,

    [switch]$SkipElevation,

    [string]$LogPath = '',

    [switch]$Force,

    [switch]$PassThru
)

# -----------------------------------------------------------------------------
# 1. CONFIGURACION DE RUTAS BASE Y LOGGING
# -----------------------------------------------------------------------------
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

if (-not $CatalogPath) {
    $candidatePaths = @(
        (Join-Path -Path $scriptRoot -ChildPath "..\Core\App-Profiles-Catalog.json"),
        (Join-Path -Path $scriptRoot -ChildPath "Core\App-Profiles-Catalog.json"),
        (Join-Path -Path $scriptRoot -ChildPath "App-Profiles-Catalog.json"),
        "C:\OptimizedISO\scripts\Core\App-Profiles-Catalog.json",
        "C:\Windows\Setup\Scripts\Core\App-Profiles-Catalog.json"
    )
    foreach ($cand in $candidatePaths) {
        if (Test-Path -Path $cand) {
            $CatalogPath = (Resolve-Path -Path $cand).Path
            break
        }
    }
}

if (-not $LogPath) {
    $logDir = if (Test-Path -Path "C:\OptimizedISO\Log") { "C:\OptimizedISO\Log" } else { $env:TEMP }
    $LogPath = Join-Path -Path $logDir -ChildPath "Deploy-AppProfiles-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
}

function Write-DeployLog {
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
        Write-Verbose "[ADVERTENCIA] Fallo al persistir evento en archivo de log ($LogPath): $($_.Exception.Message)"
    }
}

# -----------------------------------------------------------------------------
# 2. FUNCIONES MODULARES Y MOTOR DE CATALOGO
# -----------------------------------------------------------------------------
function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$identity
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-Warning "[ADVERTENCIA] No se pudo verificar el estado de elevacion: $($_.Exception.Message)"
        return $false
    }
}

function Find-WingetExecutable {
    # 1. Comprobar PATH
    $cmd = Get-Command -Name "winget.exe" -ErrorAction SilentlyContinue
    if ($cmd -and (Test-Path -Path $cmd.Source)) {
        return $cmd.Source
    }

    # 2. Comprobar ruta por usuario local
    $localAppWinget = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Microsoft\WindowsApps\winget.exe"
    if (Test-Path -Path $localAppWinget) {
        return $localAppWinget
    }

    # 3. Comprobar WindowsApps en Program Files
    $appxSearch = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" -Filter "winget.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($appxSearch -and (Test-Path -Path $appxSearch.FullName)) {
        return $appxSearch.FullName
    }

    return $null
}

function Get-RomanOSAppCatalog {
    <#
    .SYNOPSIS
        Carga y deserializa el catalogo canonico de software y perfiles JSON.
    #>
    [CmdletBinding()]
    param([string]$Path = '')

    $targetPath = if ($Path) { $Path } else { $script:CatalogPath }
    if (-not $targetPath -or -not (Test-Path -Path $targetPath)) {
        $candidatePaths = @(
            (Join-Path -Path (Split-Path -Parent $PSCommandPath) -ChildPath "..\Core\App-Profiles-Catalog.json"),
            "C:\OptimizedISO\scripts\Core\App-Profiles-Catalog.json",
            "C:\Windows\Setup\Scripts\Core\App-Profiles-Catalog.json"
        )
        foreach ($c in $candidatePaths) {
            if (Test-Path -Path $c) { $targetPath = (Resolve-Path -Path $c).Path; break }
        }
    }

    if ($targetPath -and (Test-Path -Path $targetPath)) {
        try {
            $raw = Get-Content -Path $targetPath -Raw -Encoding UTF8
            return (ConvertFrom-Json -InputObject $raw)
        } catch {
            Write-Warning "Fallo al deserializar App-Profiles-Catalog.json ($targetPath): $($_.Exception.Message)"
            return $null
        }
    }

    return $null
}

function Get-RomanOSAppsByCategory {
    <#
    .SYNOPSIS
        Obtiene los paquetes asociados a una categoria o perfil del catalogo.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CategoryName,
        [string]$Path = ''
    )

    $cat = Get-RomanOSAppCatalog -Path $Path
    if (-not $cat) { return @() }

    # 1. Categoria curada (Browsers, Gaming, Development, Utilities)
    if ($cat.categories -and $cat.categories.$CategoryName) {
        return @($cat.categories.$CategoryName)
    }

    # 2. Perfil de instalacion (EsportsGamer, CreatorStreamer, AIAndDeveloper, Essential)
    if ($cat.profiles -and $cat.profiles.$CategoryName) {
        return @($cat.profiles.$CategoryName.packages)
    }

    # 3. Runtimes de sistema
    if ($CategoryName -eq 'Runtimes' -and $cat.runtimes) {
        return @($cat.runtimes)
    }

    return @()
}

function Install-RomanOSAppsBatch {
    <#
    .SYNOPSIS
        Instala una coleccion de paquetes de forma desatendida mediante winget.exe.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject[]]$Packages,

        [string]$WingetPath = '',

        [string]$LogPath = '',

        [switch]$Unattended,

        [switch]$Force
    )

    if (-not $WingetPath) {
        $WingetPath = Find-WingetExecutable
    }

    if (-not $WingetPath) {
        Write-Warning "[WARN] winget.exe no disponible. No es posible ejecutar instalaciones fisicas."
        return @{ SuccessCount = 0; FailCount = @($Packages).Count; AlreadyInstalledCount = 0; Success = $false }
    }

    $successCount = 0
    $failCount = 0
    $alreadyInstalledCount = 0
    $total = @($Packages).Count
    $i = 1

    foreach ($item in $Packages) {
        if ($PSCmdlet.ShouldProcess($item.Name, "Instalar paquete winget con ID '$($item.Id)'")) {
            Write-Host "`n--------------------------------------------------------------------------" -ForegroundColor DarkGray
            Write-DeployLog ">>> [$i/$total] Instalando: $($item.Name) (ID: $($item.Id))..." 'TITLE'

            $wingetArgs = "install --exact --id `"$($item.Id)`" --silent --accept-package-agreements --accept-source-agreements --disable-interactivity"
            
            try {
                $pinfo = New-Object System.Diagnostics.ProcessStartInfo
                $pinfo.FileName = $WingetPath
                $pinfo.Arguments = $wingetArgs
                $pinfo.UseShellExecute = $false
                $pinfo.RedirectStandardOutput = $true
                $pinfo.RedirectStandardError = $true
                $pinfo.CreateNoWindow = $true

                $process = [System.Diagnostics.Process]::Start($pinfo)
                $stdout = $process.StandardOutput.ReadToEnd()
                $stderr = $process.StandardError.ReadToEnd()
                $process.WaitForExit()
                $exitCode = $process.ExitCode

                if ($exitCode -eq 0) {
                    Write-DeployLog "  [OK] $($item.Name) instalado correctamente." 'OK'
                    $successCount++
                }
                elseif ($exitCode -eq -1978335189 -or $stdout -match "ya está instalada|already installed|No applicable update found") {
                    Write-DeployLog "  [INFO] $($item.Name) ya se encuentra instalado o actualizado en el sistema." 'INFO'
                    $alreadyInstalledCount++
                }
                else {
                    Write-DeployLog "  [WARN] Fallo al instalar $($item.Name) (ExitCode: $exitCode)." 'WARN'
                    if ($stderr) { Write-DeployLog "         Detalle: $stderr" 'WARN' }
                    $failCount++
                }
            }
            catch {
                Write-DeployLog "  [ERROR] Excepcion al invocar proceso de instalacion para $($item.Name): $($_.Exception.Message)" 'ERROR'
                $failCount++
            }
        }
        $i++
    }

    return @{
        SuccessCount          = $successCount
        FailCount             = $failCount
        AlreadyInstalledCount = $alreadyInstalledCount
        Success               = ($failCount -eq 0)
    }
}

# -----------------------------------------------------------------------------
# 3. ACCIONES NO ELEVADAS TEMPRANAS Y GUARDIA DE IMPORTACION
# -----------------------------------------------------------------------------

# Listado del catalogo en consola sin requerir elevacion de privilegios
if ($ListCatalog) {
    $cat = Get-RomanOSAppCatalog -Path $CatalogPath
    if (-not $cat) {
        Write-Error "No se pudo localizar o cargar el catalogo de software."
        exit 1
    }

    Write-Host "`n==========================================================================" -ForegroundColor Magenta
    Write-Host "   romanOS: CATALOGO DE SOFTWARE CURADO (WinGet Engine)                   " -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Magenta

    if ($cat.categories) {
        Write-Host "`n[CATEGORIAS DE SOFTWARE DISPONIBLES]:" -ForegroundColor Yellow
        foreach ($prop in $cat.categories.psobject.properties) {
            Write-Host "`n--- Categoria: $($prop.Name) ---" -ForegroundColor Green
            foreach ($pkg in $prop.Value) {
                Write-Host ("  [{0,-28}] {1,-26} | {2}" -f $pkg.id, $pkg.name, $pkg.description) -ForegroundColor Gray
            }
        }
    }

    if ($cat.profiles) {
        Write-Host "`n[PERFILES DE INSTALACION RAPIDA]:" -ForegroundColor Yellow
        foreach ($prop in $cat.profiles.psobject.properties) {
            Write-Host ("  - {0,-20} : {1}" -f $prop.Name, $prop.Value.name) -ForegroundColor Cyan
        }
    }

    if ($PassThru) {
        return $cat
    }

    exit 0
}

# Si fue invocado mediante dot-sourcing (como modulo de funciones), finalizar aqui exportando las funciones
if ($MyInvocation.InvocationName -eq '.') {
    return
}

# -----------------------------------------------------------------------------
# 4. VERIFICACION DE PRIVILEGIOS DE ADMINISTRADOR Y AUTO-ELEVACION
# -----------------------------------------------------------------------------
if (-not $SkipElevation -and -not (Test-IsAdministrator) -and -not $WhatIfPreference) {
    Write-Host "[INFO] Se requieren privilegios de Administrador. Elevando proceso..." -ForegroundColor Yellow
    try {
        $argList = "-STA -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        if ($Profile -ne 'None') { $argList += " -Profile $Profile" }
        if ($Categories -and $Categories.Count -gt 0) { $argList += " -Categories $($Categories -join ',')" }
        if ($InstallRuntimesOnly) { $argList += " -InstallRuntimesOnly" }
        if ($AutoDetectHardware) { $argList += " -AutoDetectHardware" }
        if ($Unattended) { $argList += " -Unattended" }
        if ($CatalogPath) { $argList += " -CatalogPath `"$CatalogPath`"" }
        if ($LogPath) { $argList += " -LogPath `"$LogPath`"" }
        if ($Force) { $argList += " -Force" }
        
        Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
        exit 0
    }
    catch {
        Write-Error "[ERROR] Fallo critico al intentar elevar privilegios: $($_.Exception.Message)"
        exit 1
    }
}

# -----------------------------------------------------------------------------
# 5. CARGA DE CATALOGO Y TOPOLOGIA DE HARDWARE
# -----------------------------------------------------------------------------
Write-DeployLog "==========================================================================" 'TITLE'
Write-DeployLog " romanOS App & AI Runtimes Manager (v1.0 - 2026)" 'TITLE'
Write-DeployLog "==========================================================================" 'TITLE'

$catalog = Get-RomanOSAppCatalog -Path $CatalogPath
if (-not $catalog) {
    Write-DeployLog "[ERROR] No se localizo o no se pudo cargar el catalogo canónico de paquetes en: $CatalogPath" 'ERROR'
    exit 1
}
Write-DeployLog "[OK] Catalogo cargado exitosamente: $($catalog.description) (v$($catalog.version))" 'OK'

# Introspeccion de hardware mediante Hardware-Engine.ps1 si esta solicitado
$hwProfile = $null
if ($AutoDetectHardware) {
    Write-DeployLog "[INFO] Analizando topologia de hardware mediante Hardware-Engine.ps1..." 'INFO'
    $hwEnginePath = Join-Path -Path $scriptRoot -ChildPath "..\Core\Hardware-Engine.ps1"
    if (-not (Test-Path -Path $hwEnginePath)) {
        $hwEnginePath = "C:\OptimizedISO\scripts\Core\Hardware-Engine.ps1"
    }
    
    if (Test-Path -Path $hwEnginePath) {
        try {
            . $hwEnginePath
            if (Get-Command -Name "Get-SystemHardwareProfile" -ErrorAction SilentlyContinue) {
                $hwProfile = Get-SystemHardwareProfile
                Write-DeployLog "[OK] Topologia de Hardware Detectada:" 'OK'
                Write-DeployLog "     - CPU : $($hwProfile.Cpu.Name)" 'INFO'
                Write-DeployLog "     - GPU : $($hwProfile.Gpu.GpuSummary)" 'INFO'
                Write-DeployLog "     - Nivel de RAM: $($hwProfile.Memory.TotalPhysicalGB) GB" 'INFO'
            }
        }
        catch {
            Write-DeployLog "[WARN] No se pudo cargar Hardware-Engine.ps1: $($_.Exception.Message). Se usara deteccion estandar WMI." 'WARN'
        }
    }
    else {
        Write-DeployLog "[WARN] Hardware-Engine.ps1 no encontrado en rutas conocidas. Continuando sin introspeccion profunda." 'WARN'
    }
}

# -----------------------------------------------------------------------------
# 5. CONSTRUCCION DE LA COLA DE INSTALACION
# -----------------------------------------------------------------------------
$installQueue = [System.Collections.Generic.List[PSObject]]::new()

# A) Runtimes Base
if ($InstallRuntimesOnly -or $IncludeRuntimes) {
    if ($catalog.runtimes) {
        foreach ($rt in $catalog.runtimes) {
            $installQueue.Add([PSCustomObject]@{
                Id          = $rt.id
                Name        = $rt.name
                Category    = $rt.category
                Description = $rt.description
                SilentArgs  = $rt.silentArgs
                Source      = "Runtimes"
            })
        }
    }
}

# B) Perfiles de Usuario
if (-not $InstallRuntimesOnly -and $Profile -ne 'None') {
    $selectedProfiles = @()
    if ($Profile -eq 'All') {
        $selectedProfiles = $catalog.profiles.psobject.properties.Name
    }
    elseif ($catalog.profiles.$Profile) {
        $selectedProfiles = @($Profile)
    }
    elseif ($Profile -eq 'Custom') {
        # Sera alimentado por CustomPackages
    }
    else {
        Write-DeployLog "[WARN] Perfil '$Profile' no reconocido en el catalogo." 'WARN'
    }

    foreach ($pName in $selectedProfiles) {
        $pObj = $catalog.profiles.$pName
        Write-DeployLog "[INFO] Agregando perfil: $($pObj.name) ($($pObj.description))" 'INFO'
        foreach ($pkg in $pObj.packages) {
            # Evitar duplicados por ID
            if (-not ($installQueue | Where-Object { $_.Id -eq $pkg.id })) {
                $installQueue.Add([PSCustomObject]@{
                    Id          = $pkg.id
                    Name        = $pkg.name
                    Category    = $pkg.category
                    Description = $pkg.description
                    SilentArgs  = $pkg.silentArgs
                    Source      = "Profile:$pName"
                })
            }
        }
    }
}

# C) Categorias de Software Curado (Inspirado en WinUtil)
if ($Categories -and $Categories.Count -gt 0) {
    foreach ($catName in $Categories) {
        $catPkgs = Get-RomanOSAppsByCategory -CategoryName $catName -Path $CatalogPath
        if ($catPkgs -and @($catPkgs).Count -gt 0) {
            Write-DeployLog "[INFO] Agregando categoria '$catName' ($(@($catPkgs).Count) paquetes)..." 'INFO'
            foreach ($pkg in $catPkgs) {
                if (-not ($installQueue | Where-Object { $_.Id -eq $pkg.id })) {
                    $installQueue.Add([PSCustomObject]@{
                        Id          = $pkg.id
                        Name        = $pkg.name
                        Category    = $pkg.category
                        Description = $pkg.description
                        SilentArgs  = $pkg.silentArgs
                        Source      = "Category:$catName"
                    })
                }
            }
        } else {
            Write-DeployLog "[WARN] Categoria o perfil '$catName' no contiene paquetes o no existe en el catalogo." 'WARN'
        }
    }
}

# D) Deteccion Adaptativa de Hardware (NVIDIA / AMD / Intel Arc / NPU)
if ($AutoDetectHardware -and $catalog.hardwareAddons) {
    # 1. NVIDIA
    $isNvidia = $false
    if ($hwProfile -and $hwProfile.Gpu.HasNvidia) { $isNvidia = $true }
    elseif (Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "NVIDIA" -or $_.PNPDeviceID -match "VEN_10DE" }) { $isNvidia = $true }

    if ($isNvidia -and $catalog.hardwareAddons.Nvidia) {
        Write-DeployLog "[INFO] Silicio NVIDIA detectado. Agregando paquetes de aceleracion NVIDIA..." 'INFO'
        foreach ($addon in $catalog.hardwareAddons.Nvidia) {
            if (-not ($installQueue | Where-Object { $_.Id -eq $addon.id })) {
                $installQueue.Add([PSCustomObject]@{
                    Id          = $addon.id
                    Name        = $addon.name
                    Category    = $addon.category
                    Description = $addon.description
                    SilentArgs  = $addon.silentArgs
                    Source      = "Hardware:NVIDIA"
                })
            }
        }
    }

    # 2. AMD
    $isAmd = $false
    if ($hwProfile -and $hwProfile.Gpu.HasAmd) { $isAmd = $true }
    elseif (Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "AMD|Radeon" -or $_.PNPDeviceID -match "VEN_1002" }) { $isAmd = $true }

    if ($isAmd -and $catalog.hardwareAddons.Amd) {
        Write-DeployLog "[INFO] Silicio AMD Radeon detectado. Agregando paquetes de aceleracion AMD..." 'INFO'
        foreach ($addon in $catalog.hardwareAddons.Amd) {
            if (-not ($installQueue | Where-Object { $_.Id -eq $addon.id })) {
                $installQueue.Add([PSCustomObject]@{
                    Id          = $addon.id
                    Name        = $addon.name
                    Category    = $addon.category
                    Description = $addon.description
                    SilentArgs  = $addon.silentArgs
                    Source      = "Hardware:AMD"
                })
            }
        }
    }

    # 3. Intel Arc
    $isIntelArc = $false
    if ($hwProfile -and $hwProfile.Gpu.HasIntelArc) { $isIntelArc = $true }
    elseif (Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Intel.*Arc" }) { $isIntelArc = $true }

    if ($isIntelArc -and $catalog.hardwareAddons.Intel) {
        Write-DeployLog "[INFO] Silicio Intel Arc detectado. Agregando paquetes de aceleracion Intel..." 'INFO'
        foreach ($addon in $catalog.hardwareAddons.Intel) {
            if (-not ($installQueue | Where-Object { $_.Id -eq $addon.id })) {
                $installQueue.Add([PSCustomObject]@{
                    Id          = $addon.id
                    Name        = $addon.name
                    Category    = $addon.category
                    Description = $addon.description
                    SilentArgs  = $addon.silentArgs
                    Source      = "Hardware:Intel"
                })
            }
        }
    }

    # 4. NPU (Neural Processing Unit)
    $hasNpu = $false
    try {
        $pnpDevices = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match "NPU|Neural|AI Boost|XDNA|IPU|Compute Accelerator" -or
            $_.CompatibleID -match "NPU" -or
            $_.DeviceID -match "VEN_1022&DEV_1502|VEN_8086&DEV_7D1D"
        }
        if ($pnpDevices) { $hasNpu = $true }
    } catch {
        Write-Verbose "[Deploy-AppProfiles] Telemetría de hardware NPU no accesible vía Win32_PnPEntity: $($_.Exception.Message)"
    }

    if ($hasNpu -and $catalog.hardwareAddons.Npu) {
        Write-DeployLog "[INFO] Acelerador NPU de Inteligencia Artificial detectado. Agregando DirectML / ONNX..." 'INFO'
        foreach ($addon in $catalog.hardwareAddons.Npu) {
            if (-not ($installQueue | Where-Object { $_.Id -eq $addon.id })) {
                $installQueue.Add([PSCustomObject]@{
                    Id          = $addon.id
                    Name        = $addon.name
                    Category    = $addon.category
                    Description = $addon.description
                    SilentArgs  = $addon.silentArgs
                    Source      = "Hardware:NPU"
                })
            }
        }
    }
}

# E) Paquetes Personalizados
if ($CustomPackages -and $CustomPackages.Count -gt 0) {
    foreach ($customId in $CustomPackages) {
        if (-not ($installQueue | Where-Object { $_.Id -eq $customId })) {
            $installQueue.Add([PSCustomObject]@{
                Id          = $customId
                Name        = $customId
                Category    = "Custom"
                Description = "Paquete especificado por el usuario"
                SilentArgs  = "--silent --accept-package-agreements --accept-source-agreements"
                Source      = "CLI:Custom"
            })
        }
    }
}

# -----------------------------------------------------------------------------
# 6. MOSTRAR RESUMEN Y VALIDAR HERRAMIENTAS
# -----------------------------------------------------------------------------
Write-DeployLog "Cola de Instalacion Preparada ($($installQueue.Count) paquetes seleccionados):" 'TITLE'
$idx = 1
foreach ($item in $installQueue) {
    Write-DeployLog ((" [{0,2}] {1,-35} | {2,-15} | Origen: {3}" -f $idx, $item.Name, $item.Category, $item.Source)) 'INFO'
    $idx++
}

if ($installQueue.Count -eq 0) {
    Write-DeployLog "[INFO] No se seleccionaron paquetes para instalar. Especifique -Profile, -Categories, -InstallRuntimesOnly o -AutoDetectHardware." 'INFO'
    exit 0
}

# Validacion de winget
$wingetPath = Find-WingetExecutable

if (-not $wingetPath) {
    Write-DeployLog "[WARN] winget.exe (Windows Package Manager) no fue localizado en las rutas del sistema." 'WARN'
    Write-DeployLog "       Para instalar winget, descargue el paquete msixbundle oficial de:" 'WARN'
    Write-DeployLog "       https://github.com/microsoft/winget-cli/releases" 'WARN'
    
    if (-not $WhatIfPreference) {
        Write-DeployLog "[ERROR] No es posible continuar la instalacion sin winget.exe disponible." 'ERROR'
        exit 2
    }
} else {
    Write-DeployLog "[OK] Windows Package Manager detectado: $wingetPath" 'OK'
}

# -----------------------------------------------------------------------------
# 7. EJECUCION DE LA INSTALACION
# -----------------------------------------------------------------------------
if ($WhatIfPreference) {
    Write-DeployLog "`n>>> MODO DE SIMULACION ACTIVADO (-WhatIf). No se realizaran modificaciones fisicas:" 'TITLE'
    foreach ($item in $installQueue) {
        if ($PSCmdlet.ShouldProcess($item.Name, "Instalar paquete winget con ID '$($item.Id)'")) {
            # ShouldProcess en WhatIf imprime la accion simulada
        }
    }
    Write-DeployLog "[OK] Simulacion completada. $($installQueue.Count) paquetes evaluados satisfactoriamente." 'OK'
    if ($PassThru) {
        return $installQueue
    }
    exit 0
}

if (-not $Unattended -and -not $Force) {
    Write-Host "`n¿Desea proceder con la instalacion silenciosa de los $($installQueue.Count) paquetes listados? (S/N): " -ForegroundColor Yellow -NoNewline
    $ans = Read-Host
    if ($ans -notmatch '^[sSyY]') {
        Write-DeployLog "[INFO] Operacion cancelada por el usuario." 'INFO'
        exit 0
    }
}

Write-DeployLog "`nIniciando despliegue de paquetes..." 'TITLE'
$deployResult = Install-RomanOSAppsBatch -Packages $installQueue -WingetPath $wingetPath -LogPath $LogPath -Unattended:$Unattended -Force:$Force

Write-DeployLog "==========================================================================" 'TITLE'
Write-DeployLog " RESUMEN DE DESPLIEGUE DE PAQUETES" 'TITLE'
Write-DeployLog "==========================================================================" 'TITLE'
Write-DeployLog " Paquetes Instalados con Éxito : $($deployResult.SuccessCount)" 'OK'
Write-DeployLog " Paquetes Ya Existentes         : $($deployResult.AlreadyInstalledCount)" 'INFO'
Write-DeployLog " Paquetes con Incidencias       : $($deployResult.FailCount)" $(if ($deployResult.FailCount -gt 0) { 'WARN' } else { 'OK' })
Write-DeployLog " Registro detallado guardado en : $LogPath" 'INFO'
Write-DeployLog "==========================================================================" 'TITLE'

if ($deployResult.FailCount -gt 0) {
    exit 1
}
exit 0
