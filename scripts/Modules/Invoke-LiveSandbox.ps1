<#
.SYNOPSIS
    Invoke-LiveSandbox.ps1 - Orquestador y Generador Dinámico de Entornos romanOS Live Sandbox
    Aislamiento Efímero para Gaming Mods, Análisis de Binarios y Navegación Segura

.DESCRIPTION
    Proporciona una interfaz nativa y desacoplada para interactuar con Windows Sandbox
    (Containers-DisposableClientVM). Genera perfiles de configuración (.wsb) con
    aceleración vGPU, políticas de red (Air-Gap vs Acceso Pleno), carpetas compartidas
    y secuencias de comandos de inicio automatizadas sin alterar el sistema host.

.PARAMETER Action
    Acción a ejecutar: Status (diagnóstico), GenerateConfig (crear .wsb), Launch (iniciar Sandbox), EnableFeature (habilitar opcional).

.PARAMETER Preset
    Perfil preconfigurado:
      - SafeAnalysis: Aislado sin red (Air-Gap), sin vGPU, carpeta compartida de sólo lectura.
      - GameModding: Con vGPU (Direct3D), red habilitada y carpeta compartida de lectura/escritura.
      - DisposableBrowser: Navegación efímera y ultra-privada, vGPU activa, red habilitada.
      - Custom: Configuración personalizada mediante switches individuales.

.PARAMETER SharedFolder
    Ruta del host a mapear dentro del entorno Sandbox.

.PARAMETER ReadOnlySharedFolder
    Fuerza el mapeo de la carpeta compartida en modo estricto de sólo lectura.

.PARAMETER EnableNetworking
    Habilita el acceso a red en el Sandbox.

.PARAMETER DisableNetworking
    Deshabilita el acceso a red (Air-Gap) en el Sandbox.

.PARAMETER EnableGPU
    Habilita la aceleración gráfica virtualizada (vGPU / Direct3D).

.PARAMETER DisableGPU
    Deshabilita la aceleración gráfica virtualizada.

.PARAMETER MemoryInMB
    Límite de memoria RAM asignada al Sandbox (ej. 4096, 8192).

.PARAMETER LogonCommand
    Comando a ejecutar al iniciar sesión en el Sandbox.

.PARAMETER OutputPath
    Ruta opcional para guardar el archivo .wsb generado.

.PARAMETER Unattended
    Omite confirmaciones interactivas en consola.

.PARAMETER SkipElevation
    Omite la elevación forzada de privilegios cuando no se modifican características de Windows.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("Status", "GenerateConfig", "Launch", "EnableFeature")]
    [string]$Action = "Status",

    [ValidateSet("SafeAnalysis", "GameModding", "DisposableBrowser", "Custom")]
    [string]$Preset = "SafeAnalysis",

    [string]$SharedFolder,
    [switch]$ReadOnlySharedFolder,
    [switch]$EnableNetworking,
    [switch]$DisableNetworking,
    [switch]$EnableGPU,
    [switch]$DisableGPU,
    [int]$MemoryInMB = 0,
    [string]$LogonCommand,
    [string]$OutputPath,
    [switch]$Unattended,
    [switch]$SkipElevation
)

$ErrorActionPreference = 'Continue'

# -----------------------------------------------------------------------------
# 1. CARGA DE MOTORES CENTRALES (SSOT: UI-Engine y Hardware-Engine)
# -----------------------------------------------------------------------------
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$repoRootCandidates = @(
    (Split-Path (Split-Path $scriptDir -Parent) -Parent),
    (Split-Path $scriptDir -Parent),
    "C:\OptimizedISO"
)
$repoRoot = $repoRootCandidates | Where-Object { (Test-Path (Join-Path $_ ".agents")) -or (Test-Path (Join-Path $_ "scripts\Core")) } | Select-Object -First 1
if (-not $repoRoot) { $repoRoot = $repoRootCandidates[0] }

# UI Engine
$uiEnginePaths = @(
    (Join-Path $repoRoot "scripts\Core\UI-Engine.ps1"),
    (Join-Path $scriptDir "..\Core\UI-Engine.ps1"),
    (Join-Path $scriptDir "Core\UI-Engine.ps1"),
    (Join-Path $env:SystemRoot "Setup\Scripts\Core\UI-Engine.ps1")
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
    function Show-UnifiedSummary { param($Title,$Status,$DurationSeconds,$ErrorsCount,$WarnsCount,$Logs) Write-Host "`n=== $($Title): $Status (${DurationSeconds}s) ===`n" -ForegroundColor Cyan }
}

# Hardware Engine
$hwEnginePaths = @(
    (Join-Path $repoRoot "scripts\Core\Hardware-Engine.ps1"),
    (Join-Path $scriptDir "..\Core\Hardware-Engine.ps1"),
    (Join-Path $scriptDir "Hardware-Engine.ps1"),
    (Join-Path $env:SystemRoot "Setup\Scripts\Core\Hardware-Engine.ps1")
)
foreach ($p in $hwEnginePaths) {
    if (Test-Path $p) {
        . $p
        break
    }
}

# -----------------------------------------------------------------------------
# 2. FUNCIONES DE DIAGNOSTICO DE VIRTUALIZACION Y SANDBOX
# -----------------------------------------------------------------------------
function Get-RomanOSSandboxDiagnostic {
    [CmdletBinding()]
    param()

    $diag = [PSCustomObject]@{
        CPUName                   = "Desconocido"
        VirtualizationFirmware    = $false
        SLATSupported             = $false
        WindowsEdition            = "Desconocido"
        IsSandboxEditionSupported = $false
        SandboxBinaryExists       = $false
        SandboxBinaryPath         = ""
        OptionalFeatureState      = "Unknown"
        HyperVRunning             = $false
        OverallStatus             = "NotReady"
    }

    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cpu) {
            $diag.CPUName = $cpu.Name.Trim()
            if ($cpu.PSObject.Properties['VirtualizationFirmwareEnabled']) {
                $diag.VirtualizationFirmware = [bool]$cpu.VirtualizationFirmwareEnabled
            }
            if ($cpu.PSObject.Properties['SecondLevelAddressTranslationExtensions']) {
                $diag.SLATSupported = [bool]$cpu.SecondLevelAddressTranslationExtensions
            }
        }
    } catch {
        Write-Warn "No se pudo consultar telemetría de CPU para virtualización: $($_.Exception.Message)"
    }

    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($os) {
            $diag.WindowsEdition = $os.Caption
            # Windows Sandbox requiere Pro, Enterprise, Education o Server
            if ($os.Caption -match "Pro|Enterprise|Education|Server|Workstation") {
                $diag.IsSandboxEditionSupported = $true
            } else {
                $diag.IsSandboxEditionSupported = $false
            }
        }
    } catch {
        Write-Warn "No se pudo consultar edición de Windows: $($_.Exception.Message)"
    }

    $sandboxPath = Join-Path $env:SystemRoot "System32\WindowsSandbox.exe"
    if (Test-Path $sandboxPath) {
        $diag.SandboxBinaryExists = $true
        $diag.SandboxBinaryPath   = $sandboxPath
        $diag.OptionalFeatureState = "Enabled"
    } else {
        $diag.SandboxBinaryExists = $false
        $diag.OptionalFeatureState = "DisabledOrMissing"
    }

    # Verificar servicio de hipervisor Hyper-V
    try {
        $vmms = Get-Service -Name "vmms" -ErrorAction SilentlyContinue
        if ($vmms -and $vmms.Status -eq 'Running') {
            $diag.HyperVRunning = $true
        }
    } catch {
        Write-Verbose "[LiveSandbox] Servicio vmms no accesible para telemetría Hyper-V: $($_.Exception.Message)"
    }

    if ($diag.SandboxBinaryExists -and $diag.VirtualizationFirmware) {
        $diag.OverallStatus = "Ready"
    } elseif (-not $diag.VirtualizationFirmware) {
        $diag.OverallStatus = "VirtualizationDisabledInBIOS"
    } elseif (-not $diag.IsSandboxEditionSupported) {
        $diag.OverallStatus = "EditionNotSupported"
    } else {
        $diag.OverallStatus = "FeatureDisabled"
    }

    return $diag
}

# -----------------------------------------------------------------------------
# 3. GENERADOR DE ARCHIVOS .WSB (Windows Sandbox Configuration)
# -----------------------------------------------------------------------------
function New-RomanOSSandboxConfig {
    [CmdletBinding()]
    param(
        [string]$Preset = "SafeAnalysis",
        [string]$SharedFolder,
        [switch]$ReadOnlySharedFolder,
        [switch]$EnableNetworking,
        [switch]$DisableNetworking,
        [switch]$EnableGPU,
        [switch]$DisableGPU,
        [int]$MemoryInMB = 0,
        [string]$LogonCommand,
        [string]$OutputPath
    )

    # Configuración base según Preset
    $vGpuVal        = "Default"
    $networkingVal  = "Default"
    $protectedVal   = "Default"
    $clipboardVal   = "Default"
    $audioVal       = "Default"
    $folderReadOnly = "true"
    $finalMemory    = 0
    $finalCmd       = ""

    switch ($Preset) {
        "SafeAnalysis" {
            $vGpuVal        = "Disable"
            $networkingVal  = "Disable"
            $protectedVal   = "Enable"
            $clipboardVal   = "Disable"
            $audioVal       = "Disable"
            $folderReadOnly = "true"
            $finalMemory    = if ($MemoryInMB -gt 0) { $MemoryInMB } else { 4096 }
            $finalCmd       = if ($LogonCommand) { $LogonCommand } else { "" }
        }
        "GameModding" {
            $vGpuVal        = "Enable"
            $networkingVal  = "Enable"
            $protectedVal   = "Default"
            $clipboardVal   = "Enable"
            $audioVal       = "Enable"
            $folderReadOnly = if ($ReadOnlySharedFolder) { "true" } else { "false" }
            $finalMemory    = if ($MemoryInMB -gt 0) { $MemoryInMB } else { 8192 }
            $finalCmd       = if ($LogonCommand) { $LogonCommand } else { "" }
        }
        "DisposableBrowser" {
            $vGpuVal        = "Enable"
            $networkingVal  = "Enable"
            $protectedVal   = "Enable"
            $clipboardVal   = "Enable"
            $audioVal       = "Enable"
            $folderReadOnly = "true"
            $finalMemory    = if ($MemoryInMB -gt 0) { $MemoryInMB } else { 4096 }
            # Abrir navegador desatendido
            $finalCmd       = if ($LogonCommand) { $LogonCommand } else { "cmd.exe /c start msedge.exe --inprivate https://duckduckgo.com" }
        }
        "Custom" {
            $vGpuVal        = if ($EnableGPU) { "Enable" } elseif ($DisableGPU) { "Disable" } else { "Default" }
            $networkingVal  = if ($EnableNetworking) { "Enable" } elseif ($DisableNetworking) { "Disable" } else { "Default" }
            $folderReadOnly = if ($ReadOnlySharedFolder) { "true" } else { "false" }
            $finalMemory    = $MemoryInMB
            $finalCmd       = $LogonCommand
        }
    }

    # Sobrescrituras explícitas de parámetros CLI
    if ($EnableGPU)        { $vGpuVal = "Enable" }
    if ($DisableGPU)       { $vGpuVal = "Disable" }
    if ($EnableNetworking) { $networkingVal = "Enable" }
    if ($DisableNetworking){ $networkingVal = "Disable" }
    if ($ReadOnlySharedFolder) { $folderReadOnly = "true" }
    if ($MemoryInMB -gt 0) { $finalMemory = $MemoryInMB }
    if ($LogonCommand)     { $finalCmd = $LogonCommand }

    # Construir documento XML oficial
    $xmlDoc = [System.Xml.XmlDocument]::new()
    $dec = $xmlDoc.CreateXmlDeclaration("1.0", "utf-8", $null)
    [void]$xmlDoc.AppendChild($dec)

    $root = $xmlDoc.CreateElement("Configuration")
    [void]$xmlDoc.AppendChild($root)

    # VGpu
    $nodeVgpu = $xmlDoc.CreateElement("VGpu")
    $nodeVgpu.InnerText = $vGpuVal
    [void]$root.AppendChild($nodeVgpu)

    # Networking
    $nodeNet = $xmlDoc.CreateElement("Networking")
    $nodeNet.InnerText = $networkingVal
    [void]$root.AppendChild($nodeNet)

    # ProtectedClient
    if ($protectedVal -ne "Default") {
        $nodeProt = $xmlDoc.CreateElement("ProtectedClient")
        $nodeProt.InnerText = $protectedVal
        [void]$root.AppendChild($nodeProt)
    }

    # ClipboardRedirection
    if ($clipboardVal -ne "Default") {
        $nodeClip = $xmlDoc.CreateElement("ClipboardRedirection")
        $nodeClip.InnerText = $clipboardVal
        [void]$root.AppendChild($nodeClip)
    }

    # AudioInput
    if ($audioVal -ne "Default") {
        $nodeAudio = $xmlDoc.CreateElement("AudioInput")
        $nodeAudio.InnerText = $audioVal
        [void]$root.AppendChild($nodeAudio)
    }

    # MemoryInMB
    if ($finalMemory -gt 0) {
        $nodeMem = $xmlDoc.CreateElement("MemoryInMB")
        $nodeMem.InnerText = $finalMemory.ToString()
        [void]$root.AppendChild($nodeMem)
    }

    # MappedFolders
    if ($SharedFolder -and (Test-Path $SharedFolder)) {
        $resolvedFolder = (Resolve-Path $SharedFolder).Path
        $nodeMapped = $xmlDoc.CreateElement("MappedFolders")
        [void]$root.AppendChild($nodeMapped)

        $nodeFolder = $xmlDoc.CreateElement("MappedFolder")
        [void]$nodeMapped.AppendChild($nodeFolder)

        $nodeHost = $xmlDoc.CreateElement("HostFolder")
        $nodeHost.InnerText = $resolvedFolder
        [void]$nodeFolder.AppendChild($nodeHost)

        $nodeRO = $xmlDoc.CreateElement("ReadOnly")
        $nodeRO.InnerText = $folderReadOnly
        [void]$nodeFolder.AppendChild($nodeRO)
    }

    # LogonCommand
    if ($finalCmd) {
        $nodeLogon = $xmlDoc.CreateElement("LogonCommand")
        [void]$root.AppendChild($nodeLogon)

        $nodeCmd = $xmlDoc.CreateElement("Command")
        $nodeCmd.InnerText = $finalCmd
        [void]$nodeLogon.AppendChild($nodeCmd)
    }

    # Determinar ruta de salida
    if (-not $OutputPath) {
        $tempDir = [System.IO.Path]::GetTempPath()
        $OutputPath = Join-Path $tempDir ("romanOS_Sandbox_{0}_{1}.wsb" -f $Preset, (Get-Date -Format "yyyyMMdd_HHmmss"))
    }

    # Guardar archivo con formato legible
    $xmlWriterSettings = [System.Xml.XmlWriterSettings]::new()
    $xmlWriterSettings.Indent = $true
    $xmlWriterSettings.Encoding = [System.Text.Encoding]::UTF8

    $writer = [System.Xml.XmlWriter]::Create($OutputPath, $xmlWriterSettings)
    try {
        $xmlDoc.Save($writer)
    } finally {
        $writer.Dispose()
    }

    return $OutputPath
}

# -----------------------------------------------------------------------------
# 4. EJECUCION DE ACCIONES PRINCIPALES
# -----------------------------------------------------------------------------
$startTime = Get-Date

switch ($Action) {
    "Status" {
        Show-UnifiedBanner -Title "romanOS LIVE SANDBOX" -Subtitle "Diagnóstico de Entorno y Virtualización" -ShowSystemInfo

        $diag = Get-RomanOSSandboxDiagnostic

        Write-StepHeader -StepNumber 1 -TotalSteps 3 -Message "Evaluación de Soporte de Virtualización CPU"
        Write-SubStep "Procesador : $($diag.CPUName)"
        if ($diag.VirtualizationFirmware) {
            Write-OK "Virtualización de Hardware habilitada en firmware (SVM / VT-x) [OK]"
        } else {
            Write-Warn "Virtualización de Hardware DESHABILITADA en BIOS/UEFI. Windows Sandbox no podrá iniciar."
        }

        Write-StepHeader -StepNumber 2 -TotalSteps 3 -Message "Evaluación de Edición de Windows y Ejecutable"
        Write-SubStep "Edición de Windows : $($diag.WindowsEdition)"
        if ($diag.IsSandboxEditionSupported) {
            Write-OK "Edición compatible con Windows Sandbox (Pro / Enterprise / Education) [OK]"
        } else {
            Write-Warn "La edición detectada podría no soportar Windows Sandbox nativo por omisión de paquetes."
        }

        if ($diag.SandboxBinaryExists) {
            Write-OK "Binario WindowsSandbox.exe localizado en '$($diag.SandboxBinaryPath)' [OK]"
        } else {
            Write-Warn "WindowsSandbox.exe no encontrado en System32. La característica podría estar deshabilitada."
        }

        Write-StepHeader -StepNumber 3 -TotalSteps 3 -Message "Veredicto del Entorno Sandbox"
        switch ($diag.OverallStatus) {
            "Ready" {
                Write-OK "El sistema está 100% LISTO para ejecutar romanOS Live Sandbox."
            }
            "VirtualizationDisabledInBIOS" {
                Write-ErrorMsg "ESTADO: BLOQUEADO POR FIRMWARE. Debes habilitar 'AMD-V / SVM' o 'Intel VT-x' en la BIOS de tu placa base."
            }
            "EditionNotSupported" {
                Write-Warn "ESTADO: EDICIÓN LIMITADA. Windows Home requiere inyección de paquetes de contenedor o actualizar a Pro."
            }
            "FeatureDisabled" {
                Write-Warn "ESTADO: CARACTERÍSTICA NO HABILITADA. Ejecuta: Invoke-LiveSandbox.ps1 -Action EnableFeature"
            }
        }

        $dur = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
        Show-UnifiedSummary -Title "DIAGNÓSTICO LIVE SANDBOX" -Status $(if ($diag.OverallStatus -eq "Ready") { "SUCCESS" } else { "ATTENTION_REQUIRED" }) -DurationSeconds $dur -ErrorsCount $(if ($diag.OverallStatus -eq "VirtualizationDisabledInBIOS") { 1 } else { 0 }) -WarnsCount $(if ($diag.OverallStatus -ne "Ready" -and $diag.OverallStatus -ne "VirtualizationDisabledInBIOS") { 1 } else { 0 }) -Logs @{}
    }

    "GenerateConfig" {
        Write-StepHeader -StepNumber 1 -TotalSteps 2 -Message "Generando Perfil de Configuración XML (.wsb) [Preset: $Preset]"
        
        $wsbPath = New-RomanOSSandboxConfig -Preset $Preset `
            -SharedFolder $SharedFolder `
            -ReadOnlySharedFolder:$ReadOnlySharedFolder `
            -EnableNetworking:$EnableNetworking `
            -DisableNetworking:$DisableNetworking `
            -EnableGPU:$EnableGPU `
            -DisableGPU:$DisableGPU `
            -MemoryInMB $MemoryInMB `
            -LogonCommand $LogonCommand `
            -OutputPath $OutputPath

        Write-StepHeader -StepNumber 2 -TotalSteps 2 -Message "Validando Archivo Generado"
        if (Test-Path $wsbPath) {
            Write-OK "Archivo .wsb generado con éxito en: '$wsbPath'"
            Write-Info "Contenido de configuración:"
            Get-Content $wsbPath | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        } else {
            Write-ErrorMsg "Error fatal: No se pudo generar el archivo .wsb."
        }

        return $wsbPath
    }

    "Launch" {
        Show-UnifiedBanner -Title "romanOS LIVE SANDBOX" -Subtitle "Lanzador de Entorno Efímero [$Preset]" -ShowSystemInfo

        $diag = Get-RomanOSSandboxDiagnostic
        if ($diag.OverallStatus -eq "VirtualizationDisabledInBIOS") {
            Write-ErrorMsg "No se puede lanzar Windows Sandbox: La virtualización de hardware está desactivada en BIOS."
            return
        }

        Write-StepHeader -StepNumber 1 -TotalSteps 2 -Message "Generando Configuración Temporal para Preset '$Preset'"
        $wsbFile = New-RomanOSSandboxConfig -Preset $Preset `
            -SharedFolder $SharedFolder `
            -ReadOnlySharedFolder:$ReadOnlySharedFolder `
            -EnableNetworking:$EnableNetworking `
            -DisableNetworking:$DisableNetworking `
            -EnableGPU:$EnableGPU `
            -DisableGPU:$DisableGPU `
            -MemoryInMB $MemoryInMB `
            -LogonCommand $LogonCommand `
            -OutputPath $OutputPath

        Write-OK "Configuración .wsb preparada en: '$wsbFile'"

        Write-StepHeader -StepNumber 2 -TotalSteps 2 -Message "Invocando Instancia de Windows Sandbox"
        if ($PSCmdlet.ShouldProcess("WindowsSandbox.exe con archivo '$wsbFile'", "Iniciar Entorno")) {
            if ($diag.SandboxBinaryExists) {
                Write-SubStep "Iniciando proceso: WindowsSandbox.exe `"$wsbFile`""
                Start-Process -FilePath $diag.SandboxBinaryPath -ArgumentList "`"$wsbFile`""
                Write-OK "Instancia de Sandbox lanzada en segundo plano. El entorno se destruirá automáticamente al cerrarse."
            } else {
                Write-Warn "WindowsSandbox.exe no está disponible en este momento. Archivo de configuración listo para uso manual."
            }
        } else {
            Write-Info "[WhatIf] Se simuló el lanzamiento de Windows Sandbox con el perfil '$Preset'."
        }

        $dur = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
        Show-UnifiedSummary -Title "LANZAMIENTO LIVE SANDBOX" -Status "SUCCESS" -DurationSeconds $dur -ErrorsCount 0 -WarnsCount 0 -Logs @{ "Config" = $wsbFile }
    }

    "EnableFeature" {
        Show-UnifiedBanner -Title "romanOS LIVE SANDBOX" -Subtitle "Aprovisionamiento de Característica Opcional" -ShowSystemInfo

        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            Write-ErrorMsg "Habilitar características de Windows requiere elevación administrativa."
            Write-Info "Ejecuta PowerShell como Administrador y vuelve a intentar, o lanza: Invoke-LiveSandbox.cmd"
            return
        }

        Write-StepHeader -StepNumber 1 -TotalSteps 2 -Message "Habilitando Containers-DisposableClientVM"
        if ($PSCmdlet.ShouldProcess("Windows Feature: Containers-DisposableClientVM", "Enable-WindowsOptionalFeature")) {
            try {
                $res = Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -All -NoRestart -ErrorAction Stop
                Write-OK "Característica Containers-DisposableClientVM habilitada exitosamente."
                if ($res.RestartNeeded) {
                    Write-Warn "Se requiere un reinicio de Windows para completar la instalación de Sandbox."
                }
            } catch {
                Write-ErrorMsg "Fallo al habilitar característica: $($_.Exception.Message)"
                Write-Info "Intentando vía DISM.exe nativo..."
                try {
                    & dism.exe /online /enable-feature /featurename:Containers-DisposableClientVM /all /norestart
                    if ($LASTEXITCODE -eq 0) {
                        Write-OK "DISM.exe completó la operación satisfactoriamente."
                    } else {
                        Write-ErrorMsg "DISM.exe finalizó con código de error $LASTEXITCODE."
                    }
                } catch {
                    Write-ErrorMsg "Fallo al invocar DISM: $($_.Exception.Message)"
                }
            }
        } else {
            Write-Info "[WhatIf] Se simuló la habilitación de Containers-DisposableClientVM."
        }
    }
}
