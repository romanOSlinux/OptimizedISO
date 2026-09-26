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
    .\Deploy-AppProfiles.ps1 -InstallRuntimesOnly
    .\Deploy-AppProfiles.ps1 -Profile AIAndDeveloper -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('EsportsGamer', 'CreatorStreamer', 'AIAndDeveloper', 'Essential', 'All', 'Custom', 'None')]
    [string]$Profile = 'None',

    [switch]$InstallRuntimesOnly,

    [bool]$IncludeRuntimes = $true,

    [switch]$AutoDetectHardware,

    [string[]]$CustomPackages = @(),

    [string]$CatalogPath = '',

    [switch]$Unattended,

    [switch]$SkipElevation,

    [string]$LogPath = '',

    [switch]$Force
)

# -----------------------------------------------------------------------------
# 1. VERIFICACION DE PRIVILEGIOS DE ADMINISTRADOR
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

if (-not $SkipElevation -and -not (Test-IsAdministrator) -and -not $WhatIfPreference) {
    Write-Host "[INFO] Se requieren privilegios de Administrador. Elevando proceso..." -ForegroundColor Yellow
    try {
        $argList = "-STA -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        if ($Profile -ne 'None') { $argList += " -Profile $Profile" }
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
# 2. CONFIGURACION DE RUTAS Y LOGGING
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
# 3. LOCALIZACION DE WINGET (WINDOWS PACKAGE MANAGER)
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# 4. CARGA DE CATALOGO Y TOPOLOGIA DE HARDWARE
# -----------------------------------------------------------------------------
Write-DeployLog "==========================================================================" 'TITLE'
Write-DeployLog " romanOS App & AI Runtimes Manager (v1.0 - 2026)" 'TITLE'
Write-DeployLog "==========================================================================" 'TITLE'

if (-not (Test-Path -Path $CatalogPath)) {
    Write-DeployLog "[ERROR] No se localizo el catalogo canónico de paquetes en: $CatalogPath" 'ERROR'
    exit 1
}

try {
    $catalogRaw = Get-Content -Path $CatalogPath -Raw -Encoding UTF8
    $catalog = ConvertFrom-Json -InputObject $catalogRaw
    Write-DeployLog "[OK] Catalogo cargado exitosamente: $($catalog.description) (v$($catalog.version))" 'OK'
}
catch {
    Write-DeployLog "[ERROR] Error critico al deserializar el archivo JSON del catalogo: $($_.Exception.Message)" 'ERROR'
    exit 1
}

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

# C) Deteccion Adaptativa de Hardware (NVIDIA / AMD / Intel Arc / NPU)
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

# D) Paquetes Personalizados
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
    Write-DeployLog "[INFO] No se seleccionaron paquetes para instalar. Especifique -Profile, -InstallRuntimesOnly o -AutoDetectHardware." 'INFO'
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

$successCount = 0
$failCount = 0
$alreadyInstalledCount = 0

Write-DeployLog "`nIniciando despliegue de paquetes..." 'TITLE'

$i = 1
$total = $installQueue.Count

foreach ($item in $installQueue) {
    Write-Host "`n--------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-DeployLog ">>> [$i/$total] Instalando: $($item.Name) (ID: $($item.Id))..." 'TITLE'

    $wingetArgs = "install --exact --id `"$($item.Id)`" --silent --accept-package-agreements --accept-source-agreements --disable-interactivity"
    
    try {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $wingetPath
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

        # Códigos de salida de Winget:
        # 0 = Éxito
        # -1978335189 (0x8A15002B) = Ya instalado / No updates found
        # -1978335216 (0x8A150010) = Cancelado por usuario
        # -1978335215 (0x8A150011) = No se encontró paquete
        
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

    $i++
}

Write-DeployLog "==========================================================================" 'TITLE'
Write-DeployLog " RESUMEN DE DESPLIEGUE DE PAQUETES" 'TITLE'
Write-DeployLog "==========================================================================" 'TITLE'
Write-DeployLog " Paquetes Instalados con Éxito : $successCount" 'OK'
Write-DeployLog " Paquetes Ya Existentes         : $alreadyInstalledCount" 'INFO'
Write-DeployLog " Paquetes con Incidencias       : $failCount" $(if ($failCount -gt 0) { 'WARN' } else { 'OK' })
Write-DeployLog " Registro detallado guardado en : $LogPath" 'INFO'
Write-DeployLog "==========================================================================" 'TITLE'

if ($failCount -gt 0) {
    exit 1
}
exit 0
