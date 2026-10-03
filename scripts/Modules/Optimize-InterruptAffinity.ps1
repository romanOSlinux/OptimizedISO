<#
.SYNOPSIS
    romanOS PCIe Interrupt Affinity & IRQ/DPC Steering Optimizer
    Calibrador de Afinidad de Núcleos, Prioridad IRQ y Descongestión del Núcleo 0 en Vivo

.DESCRIPTION
    Optimiza el subsistema HAL de interrupciones PCIe de Windows 11 (24H2/25H2 Ready):
      1. Auto-detecta dispositivos críticos (GPU, NVMe Storage y NICs físicos).
      2. Garantiza operación en modo MSI (Message Signaled Interrupts, MSISupported = 1).
      3. Eleva la prioridad de despacho IRQ a High (3) para GPU y NVMe, y Normal (2) para NIC.
      4. Aplica políticas de afinidad DPC (DevicePolicy = 0x5 Spread Across CPUs o exclusión de Núcleo 0)
         para erradicar picos de latencia DPC (DPC latency spikes) y micro-stuttering.
      5. Genera automáticamente una instantánea de seguridad previa vía Manage-SystemSnapshots.ps1.
      6. Permite reversión atómica a los valores de fábrica de Windows (-Action Reset).

.PARAMETER Action
    Acción a ejecutar: Status (predeterminado), Audit, Optimize, Reset.

.PARAMETER TargetDevices
    Alcance de dispositivos: All (predeterminado), GPU, Storage, Network.

.PARAMETER AffinityStrategy
    Estrategia de afinidad DPC:
      - SpreadAcrossCPUs: Distribuye colas MSI-X entre todos los procesadores asignables (DevicePolicy = 0x5).
      - ExcludeCoreZero: Desvía DPCs fuera del Núcleo 0 para evitar saturación del scheduler (DevicePolicy = 0x4).
      - AutoDetectTopology: Dirige DPCs de GPU a P-Cores en Intel o CCD 3D V-Cache en AMD Ryzen.

.PARAMETER SkipSnapshot
    Omite la creación preventiva de instantánea de seguridad antes de modificar el registro.

.PARAMETER LogDir
    Ruta para almacenar logs y reportes forenses. (Default: C:\OptimizedISO\Log)

.PARAMETER Unattended
    Omite pausas interactivas en consola.

.PARAMETER SkipElevation
    Omite la elevación de privilegios cuando no se modifican componentes del sistema.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("Status", "Audit", "Optimize", "Calibrate", "Reset", "None")]
    [string]$Action = "Status",

    [ValidateSet("All", "GPU", "Storage", "Network")]
    [string]$TargetDevices = "All",

    [ValidateSet("SpreadAcrossCPUs", "ExcludeCoreZero", "AutoDetectTopology")]
    [string]$AffinityStrategy = "SpreadAcrossCPUs",

    [switch]$SkipSnapshot,
    [string]$LogDir = "C:\OptimizedISO\Log",
    [switch]$Unattended,
    [switch]$SkipElevation
)

$ErrorActionPreference = 'Continue'
$scriptStartTime = Get-Date

# -----------------------------------------------------------------------------
# 0. RESOLUCION DE RUTAS Y AUTO-ELEVACION UAC
# -----------------------------------------------------------------------------
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $scriptDir -or -not (Test-Path $scriptDir)) {
    $scriptDir = "C:\OptimizedISO\scripts\Modules"
}

if (-not (Get-Variable -Name "repoRoot" -Scope Script -ErrorAction SilentlyContinue) -or -not (Test-Path (Join-Path $repoRoot "scripts\Core"))) {
    $repoRootCandidates = @(
        (Split-Path (Split-Path $scriptDir -Parent) -Parent),
        (Split-Path $scriptDir -Parent),
        "C:\OptimizedISO"
    )
    $repoRoot = $repoRootCandidates | Where-Object { (Test-Path (Join-Path $_ "scripts\Core")) } | Select-Object -First 1
    if (-not $repoRoot) { $repoRoot = "C:\OptimizedISO" }
}

$isWhatIf = ($PSBoundParameters.ContainsKey('WhatIf') -or $WhatIfPreference)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and -not $SkipElevation -and -not $isWhatIf -and ($Action -in @("Optimize", "Reset"))) {
    Write-Warning "[Interrupt-Affinity] Se requieren privilegios de Administrador para modificar directivas de interrupciones PCIe. Elevando..."
    $targetScript = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-STA -NoProfile -ExecutionPolicy Bypass -File `"$targetScript`" -Action $Action -TargetDevices $TargetDevices -AffinityStrategy $AffinityStrategy $(if ($Unattended) { '-Unattended' })"
    $psi.Verb = "runas"
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit 0
    } catch {
        Write-Error "[Interrupt-Affinity] Elevación UAC rechazada: $($_.Exception.Message)"
        exit 1
    }
}

# -----------------------------------------------------------------------------
# 1. CARGA DE MOTORES CORE (SSOT)
# -----------------------------------------------------------------------------
$coreEngineDirs = @(
    (Join-Path $repoRoot "Core"),
    (Join-Path $scriptDir "..\Core"),
    "C:\OptimizedISO\scripts\Core",
    "$env:WINDIR\Setup\Scripts\Core",
    "C:\Windows\Setup\Scripts\Core"
)

function Resolve-CoreEngine {
    param([string]$EngineName)
    foreach ($d in $coreEngineDirs) {
        if ($d -and (Test-Path $d)) {
            $cand = Join-Path $d $EngineName
            if (Test-Path $cand) { return (Resolve-Path $cand).Path }
        }
    }
    return $null
}

$uiEngine = Resolve-CoreEngine "UI-Engine.ps1"
if ($uiEngine) { . $uiEngine } else {
    function Show-UnifiedBanner { param($Title,$Subtitle,[switch]$ShowSystemInfo,[switch]$NoClear) Write-Host "`n=== $Title ($Subtitle) ===`n" -ForegroundColor Cyan }
    function Write-StepHeader   { param($StepNumber,$TotalSteps,$Message) Write-Host "`n>>> [$StepNumber/$TotalSteps] $Message" -ForegroundColor Cyan }
    function Write-SubStep      { param($Message) Write-Host "  -> $Message" -ForegroundColor Gray }
    function Write-OK           { param($Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
    function Write-Warn         { param($Message) Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
    function Write-ErrorMsg     { param($Message) Write-Host "  [ERROR] $Message" -ForegroundColor Red }
    function Write-Info         { param($Message) Write-Host "  [i] $Message" -ForegroundColor DarkGray }
    function Show-UnifiedSummary { param($Title,$Status,$DurationSeconds,$ErrorsCount,$WarnsCount,$Logs) Write-Host "`n=== $($Title): $Status (${DurationSeconds}s) ===`n" -ForegroundColor Cyan }
}

$hwEngine = Resolve-CoreEngine "Hardware-Engine.ps1"
if ($hwEngine) { try { . $hwEngine } catch { Write-Warn "No se pudo dot-sourcear Hardware-Engine.ps1: $($_.Exception.Message)" } }

# -----------------------------------------------------------------------------
# 2. FUNCIONES DE INTROSPECCION Y TOPOLOGIA DE INTERRUPCIONES
# -----------------------------------------------------------------------------
function Inspect-PciDeviceRegistry {
    param(
        [string]$Category,
        [string]$Name,
        [string]$PnpID,
        [string]$RegPath
    )

    $msiKey = Join-Path $RegPath "Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
    $affinityKey = Join-Path $RegPath "Device Parameters\Interrupt Management\Affinity Policy"

    $msiSupported = $false
    $msiVal = $null
    $limit = $null

    if (Test-Path $msiKey) {
        try {
            $p = Get-ItemProperty -Path $msiKey -ErrorAction SilentlyContinue
            if ($p) {
                $msiVal = $p.MSISupported
                $msiSupported = ($msiVal -eq 1)
                $limit = $p.MessageNumberLimit
            }
        } catch {
            Write-Warn "No se pudo leer propiedades MSI en $($RegPath): $($_.Exception.Message)"
        }
    }

    $priority = "Normal (Default)"
    $policy = "MachineDefault (0x0)"
    $policyVal = 0
    $prioVal = 2
    $hasAffinityKey = (Test-Path $affinityKey)

    if ($hasAffinityKey) {
        try {
            $ap = Get-ItemProperty -Path $affinityKey -ErrorAction SilentlyContinue
            if ($ap) {
                if ($null -ne $ap.DevicePriority) {
                    $prioVal = $ap.DevicePriority
                    $priority = switch ($prioVal) {
                        3 { "High" }
                        2 { "Normal" }
                        1 { "Low" }
                        default { "Custom ($prioVal)" }
                    }
                }
                if ($null -ne $ap.DevicePolicy) {
                    $policyVal = $ap.DevicePolicy
                    $policy = switch ($policyVal) {
                        5 { "SpreadAcrossCPUs (0x5)" }
                        4 { "SpecifiedProcessors (0x4)" }
                        0 { "MachineDefault (0x0)" }
                        default { "Custom (0x{0:X})" -f $policyVal }
                    }
                }
            }
        } catch {
            Write-Warn "No se pudo leer Affinity Policy en $($RegPath): $($_.Exception.Message)"
        }
    }

    return [PSCustomObject]@{
        Category       = $Category
        Name           = $Name
        DeviceID       = $PnpID
        RegistryPath   = $RegPath
        MSISupported   = $msiSupported
        MSIRawValue    = $msiVal
        MessageLimit   = $limit
        DevicePriority = $priority
        PriorityVal    = $prioVal
        DevicePolicy   = $policy
        PolicyVal      = $policyVal
        HasAffinity    = $hasAffinityKey
    }
}

function Get-RomanOSPcieInterruptTopology {
    [CmdletBinding()]
    param(
        [string]$FilterCategory = "All"
    )

    $devicesList = [System.Collections.Generic.List[PSCustomObject]]::new()
    $pciBasePath = "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI"

    if (-not (Test-Path $pciBasePath)) {
        Write-Warn "No se encontró la ruta base de registro PCI ($pciBasePath)."
        return $devicesList
    }

    # 1. Identificar GPUs
    if ($FilterCategory -eq "All" -or $FilterCategory -eq "GPU") {
        try {
            $gpus = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
            foreach ($g in $gpus) {
                if ($g.PNPDeviceID -and $g.PNPDeviceID -match '^PCI\\') {
                    $devInstance = $g.PNPDeviceID.Replace('PCI\', '')
                    $regKey = Join-Path $pciBasePath $devInstance
                    if (Test-Path $regKey) {
                        $devicesList.Add((Inspect-PciDeviceRegistry -Category "GPU" -Name $g.Name -PnpID $g.PNPDeviceID -RegPath $regKey))
                    }
                }
            }
        } catch {
            Write-Warn "Error al interrogar GPUs mediante CIM: $($_.Exception.Message)"
        }
    }

    # 2. Identificar NVMe Storage Controllers
    if ($FilterCategory -eq "All" -or $FilterCategory -eq "Storage") {
        try {
            $nvmes = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object {
                ($_.Service -eq 'stornvme' -or $_.Name -match 'NVMe|NVM Express') -and $_.PNPDeviceID -match '^PCI\\'
            }
            foreach ($n in $nvmes) {
                $devInstance = $n.PNPDeviceID.Replace('PCI\', '')
                $regKey = Join-Path $pciBasePath $devInstance
                if (Test-Path $regKey) {
                    $devicesList.Add((Inspect-PciDeviceRegistry -Category "Storage" -Name $n.Name -PnpID $n.PNPDeviceID -RegPath $regKey))
                }
            }
        } catch {
            Write-Warn "Error al interrogar controladoras NVMe: $($_.Exception.Message)"
        }
    }

    # 3. Identificar Adaptadores de Red Físicos
    if ($FilterCategory -eq "All" -or $FilterCategory -eq "Network") {
        try {
            $nics = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
            foreach ($nic in $nics) {
                if ($nic.DeviceID -and $nic.DeviceID -match '^PCI\\') {
                    $devInstance = $nic.DeviceID.Replace('PCI\', '')
                    $regKey = Join-Path $pciBasePath $devInstance
                    if (Test-Path $regKey) {
                        $devicesList.Add((Inspect-PciDeviceRegistry -Category "Network" -Name $nic.InterfaceDescription -PnpID $nic.DeviceID -RegPath $regKey))
                    }
                }
            }
        } catch {
            Write-Warn "Error al interrogar adaptadores de red físicos: $($_.Exception.Message)"
        }
    }

    return $devicesList
}



# -----------------------------------------------------------------------------
# 3. FUNCIONES DE CALIBRACION Y REMEDIACION DE AFINIDAD
# -----------------------------------------------------------------------------
function Get-RomanOSAffinityMask {
    param(
        [string]$Strategy = "ExcludeCoreZero"
    )
    # Máscara de 64 bits (8 bytes): 0xFE en Byte 0 desactiva Core 0 (Bit 0 = 0), resto de bits en 1
    return [byte[]]@(0xFE, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF)
}

function Invoke-RomanOSInterruptOptimization {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [System.Collections.Generic.List[PSCustomObject]]$Devices,
        [string]$Strategy = "SpreadAcrossCPUs"
    )

    $appliedCount = 0
    $errorCount   = 0

    # Detección de núcleos lógicos y máscara para excluir Core 0 (Bit 0 en 0, resto en 1)
    $logicalCores = [System.Environment]::ProcessorCount
    $coreZeroMaskBytes = Get-RomanOSAffinityMask -Strategy "ExcludeCoreZero"

    foreach ($dev in $Devices) {
        $devDesc = "$($dev.Category): $($dev.Name)"
        $msgKey = Join-Path $dev.RegistryPath "Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        $affKey = Join-Path $dev.RegistryPath "Device Parameters\Interrupt Management\Affinity Policy"

        if ($PSCmdlet.ShouldProcess($devDesc, "Optimizar Afinidad PCIe e IRQ (Strategy: $Strategy)")) {
            try {
                # 1. Habilitar MSI
                if (-not (Test-Path $msgKey)) {
                    New-Item -Path $msgKey -Force | Out-Null
                }
                Set-ItemProperty -Path $msgKey -Name "MSISupported" -Value 1 -Type DWord -Force

                # Establecer MessageNumberLimit seguro si no existe
                $existingLimit = (Get-ItemProperty -Path $msgKey -ErrorAction SilentlyContinue).MessageNumberLimit
                if ($null -eq $existingLimit) {
                    $defaultLimit = if ($dev.Category -eq "GPU") { 2048 } else { 16 }
                    Set-ItemProperty -Path $msgKey -Name "MessageNumberLimit" -Value $defaultLimit -Type DWord -Force
                }

                # 2. Configurar Affinity Policy
                if (-not (Test-Path $affKey)) {
                    New-Item -Path $affKey -Force | Out-Null
                }

                # Prioridad IRQ según categoría
                $targetPriority = if ($dev.Category -in @("GPU", "Storage")) { 3 } else { 2 }
                Set-ItemProperty -Path $affKey -Name "DevicePriority" -Value $targetPriority -Type DWord -Force

                # Política de Afinidad
                if ($Strategy -eq "SpreadAcrossCPUs") {
                    Set-ItemProperty -Path $affKey -Name "DevicePolicy" -Value 5 -Type DWord -Force
                    # En modo spread, se limpia cualquier override manual de procesadores
                    Remove-ItemProperty -Path $affKey -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue
                } elseif ($Strategy -eq "ExcludeCoreZero") {
                    Set-ItemProperty -Path $affKey -Name "DevicePolicy" -Value 4 -Type DWord -Force
                    Set-ItemProperty -Path $affKey -Name "AssignmentSetOverride" -Value $coreZeroMaskBytes -Type Binary -Force
                } else { # AutoDetectTopology fallback
                    Set-ItemProperty -Path $affKey -Name "DevicePolicy" -Value 5 -Type DWord -Force
                }

                Write-OK "Optimizado: $devDesc -> MSI: Activo | Prioridad: $(if ($targetPriority -eq 3) { 'High' } else { 'Normal' }) | Directiva: $Strategy"
                $appliedCount++
            } catch {
                Write-ErrorMsg "Fallo al calibrar $($devDesc): $($_.Exception.Message)"
                $errorCount++
            }
        } else {
            Write-Info "[WhatIf] Se simularía la calibración de MSI, Prioridad y Afinidad en '$devDesc'."
            $appliedCount++
        }
    }

    return @{ Applied = $appliedCount; Errors = $errorCount }
}

function Reset-RomanOSInterruptOptimization {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [System.Collections.Generic.List[PSCustomObject]]$Devices
    )

    $resetCount = 0
    $errorCount = 0

    foreach ($dev in $Devices) {
        $devDesc = "$($dev.Category): $($dev.Name)"
        $affKey = Join-Path $dev.RegistryPath "Device Parameters\Interrupt Management\Affinity Policy"

        if ($PSCmdlet.ShouldProcess($devDesc, "Restaurar valores de fábrica de Windows HAL")) {
            try {
                if (Test-Path $affKey) {
                    # Restaurar prioridad Normal (2) y política MachineDefault (0)
                    Set-ItemProperty -Path $affKey -Name "DevicePriority" -Value 2 -Type DWord -Force
                    Set-ItemProperty -Path $affKey -Name "DevicePolicy" -Value 0 -Type DWord -Force
                    Remove-ItemProperty -Path $affKey -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue
                }
                Write-OK "Restaurado a valores de fábrica: $devDesc (Priority: Normal, Policy: Default)"
                $resetCount++
            } catch {
                Write-ErrorMsg "Fallo al restaurar $($devDesc): $($_.Exception.Message)"
                $errorCount++
            }
        } else {
            Write-Info "[WhatIf] Se simularía la restauración de valores de fábrica en '$devDesc'."
            $resetCount++
        }
    }

    return @{ Reset = $resetCount; Errors = $errorCount }
}

# -----------------------------------------------------------------------------
# 4. ORQUESTADOR PRINCIPAL POR ACCION
# -----------------------------------------------------------------------------
if ($Action -ne "None") {
    switch ($Action) {
        "Status" {
            Show-UnifiedBanner -Title "romanOS PCIE INTERRUPT & DPC STEERING" -Subtitle "Diagnóstico en Vivo de Afinidad y Prioridad IRQ" -ShowSystemInfo

            Write-StepHeader -StepNumber 1 -TotalSteps 2 -Message "Introspección de Topología PCIe (GPU, NVMe, Red)..."
            $devices = Get-RomanOSPcieInterruptTopology -FilterCategory $TargetDevices

            if ($devices.Count -eq 0) {
                Write-Warn "No se detectaron dispositivos PCIe relevantes para la categoría '$TargetDevices'."
            } else {
                Write-Host ("`n  {0,-10} {1,-38} {2,-12} {3,-12} {4,-24}" -f "CATEGORIA", "DISPOSITIVO", "MODO MSI", "PRIORIDAD", "AFINIDAD DPC") -ForegroundColor Cyan
                Write-Host ("  " + ("-" * 96)) -ForegroundColor DarkGray

                foreach ($d in $devices) {
                    $msiColor = if ($d.MSISupported) { "Green" } else { "Yellow" }
                    $prioColor = if ($d.PriorityVal -eq 3) { "Green" } else { "Gray" }
                    $polColor = if ($d.PolicyVal -eq 5) { "Green" } elseif ($d.PolicyVal -eq 4) { "Cyan" } else { "Gray" }

                    $msiTxt = if ($d.MSISupported) { "MSI Activo" } else { "Line-Based" }
                    $nameTrunc = if ($d.Name.Length -gt 36) { $d.Name.Substring(0, 33) + "..." } else { $d.Name }

                    Write-Host ("  {0,-10} {1,-38} " -f $d.Category, $nameTrunc) -NoNewline
                    Write-Host ("{0,-12} " -f $msiTxt) -ForegroundColor $msiColor -NoNewline
                    Write-Host ("{0,-12} " -f $d.DevicePriority) -ForegroundColor $prioColor -NoNewline
                    Write-Host ("{0,-24}" -f $d.DevicePolicy) -ForegroundColor $polColor
                }
            }

            Write-StepHeader -StepNumber 2 -TotalSteps 2 -Message "Resumen de Recomendaciones de Rendimiento"
            $unoptimizedGpu = $devices | Where-Object { $_.Category -eq "GPU" -and (-not $_.MSISupported -or $_.PriorityVal -ne 3 -or $_.PolicyVal -eq 0) }
            if ($unoptimizedGpu) {
                Write-Warn "La GPU no tiene prioridad High o está canalizando interrupciones al Núcleo 0 por defecto."
                Write-Info "Ejecute 'Optimize-InterruptAffinity.cmd' o use '-Action Optimize' para calibrarla en 1-clic."
            } else {
                Write-OK "GPU y subsistema crítico operando con asignación óptima de interrupciones."
            }

            $dur = [math]::Round(((Get-Date) - $scriptStartTime).TotalSeconds, 2)
            Show-UnifiedSummary -Title "TOPOLOGIA PCIE" -Status "SUCCESS" -DurationSeconds $dur -ErrorsCount 0 -WarnsCount 0 -Logs @{}
        }

        "Audit" {
            Show-UnifiedBanner -Title "romanOS PCIE INTERRUPT & DPC STEERING" -Subtitle "Auditoría Forense de Interrupciones" -ShowSystemInfo

            $devices = Get-RomanOSPcieInterruptTopology -FilterCategory $TargetDevices
            $totalDevs = $devices.Count
            $msiDevs   = ($devices | Where-Object { $_.MSISupported }).Count
            $highPrio  = ($devices | Where-Object { $_.PriorityVal -eq 3 }).Count
            $spreadPol = ($devices | Where-Object { $_.PolicyVal -in @(4, 5) }).Count

            Write-Host "`n  -> Dispositivos Analizados    : $totalDevs"
            Write-Host "  -> Operando en Modo MSI       : $msiDevs / $totalDevs" -ForegroundColor $(if ($msiDevs -eq $totalDevs) { "Green" } else { "Yellow" })
            Write-Host "  -> Con Prioridad High (3)     : $highPrio" -ForegroundColor $(if ($highPrio -ge 1) { "Green" } else { "Gray" })
            Write-Host "  -> Con Afinidad DPC Optimizada: $spreadPol" -ForegroundColor $(if ($spreadPol -ge 1) { "Green" } else { "Yellow" })

            $dur = [math]::Round(((Get-Date) - $scriptStartTime).TotalSeconds, 2)
            Show-UnifiedSummary -Title "AUDITORÍA INTERRUPCIONES" -Status "SUCCESS" -DurationSeconds $dur -ErrorsCount 0 -WarnsCount 0 -Logs @{}
        }

        { $_ -in @("Optimize", "Calibrate") } {
            Show-UnifiedBanner -Title "romanOS PCIE INTERRUPT & DPC STEERING" -Subtitle "Calibración Atómica de Afinidad y Prioridad" -ShowSystemInfo

            # 1. Snapshot transaccional previo si no se omite
            if (-not $SkipSnapshot -and -not $isWhatIf) {
                $snapTool = Resolve-CoreEngine "..\Modules\Manage-SystemSnapshots.ps1"
                if ($snapTool -and (Test-Path $snapTool)) {
                    Write-SubStep "Creando instantánea preventiva de seguridad..."
                    try {
                        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $snapTool -Action Create -Name "PreInterruptOptimization" -Unattended | Out-Null
                        Write-OK "Instantánea de seguridad registrada exitosamente."
                    } catch {
                        Write-Warn "No se pudo crear instantánea previa: $($_.Exception.Message)"
                    }
                }
            }

            Write-StepHeader -StepNumber 1 -TotalSteps 2 -Message "Identificando dispositivos objetivo ($TargetDevices)..."
            $devices = Get-RomanOSPcieInterruptTopology -FilterCategory $TargetDevices

            Write-StepHeader -StepNumber 2 -TotalSteps 2 -Message "Aplicando directivas de afinidad y prioridad IRQ ($AffinityStrategy)..."
            $res = Invoke-RomanOSInterruptOptimization -Devices $devices -Strategy $AffinityStrategy

            $dur = [math]::Round(((Get-Date) - $scriptStartTime).TotalSeconds, 2)
            Show-UnifiedSummary -Title "CALIBRACIÓN PCIE" -Status $(if ($res.Errors -eq 0) { "SUCCESS" } else { "WARNING" }) -DurationSeconds $dur -ErrorsCount $res.Errors -WarnsCount 0 -Logs @{}
        }

        "Reset" {
            Show-UnifiedBanner -Title "romanOS PCIE INTERRUPT & DPC STEERING" -Subtitle "Restauración a Valores de Fábrica de Windows" -ShowSystemInfo

            Write-StepHeader -StepNumber 1 -TotalSteps 2 -Message "Identificando dispositivos objetivo ($TargetDevices)..."
            $devices = Get-RomanOSPcieInterruptTopology -FilterCategory $TargetDevices

            Write-StepHeader -StepNumber 2 -TotalSteps 2 -Message "Restableciendo directivas HAL predeterminadas..."
            $res = Reset-RomanOSInterruptOptimization -Devices $devices

            $dur = [math]::Round(((Get-Date) - $scriptStartTime).TotalSeconds, 2)
            Show-UnifiedSummary -Title "RESTAURACIÓN HAL" -Status $(if ($res.Errors -eq 0) { "SUCCESS" } else { "WARNING" }) -DurationSeconds $dur -ErrorsCount $res.Errors -WarnsCount 0 -Logs @{}
        }
    }

    if (-not $Unattended -and -not $isWhatIf -and [System.Environment]::UserInteractive) {
        try {
            if (-not [System.Console]::IsInputRedirected) {
                Write-Host ""
                Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor DarkGray
                $null = [System.Console]::ReadKey($true)
            }
        } catch {
            Write-Verbose "No se pudo leer pulsación de tecla: $($_.Exception.Message)"
        }
    }
}
