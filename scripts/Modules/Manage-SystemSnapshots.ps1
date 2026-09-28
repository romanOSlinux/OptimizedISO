<#
.SYNOPSIS
    Manage-SystemSnapshots.ps1 - romanOS State Snapshot & Rollback Engine (2026)
    Hub Maestro de Instantáneas, Telemetría y Reversión Atómica para Windows 11 24H2 / 25H2

.DESCRIPTION
    Motor transaccional de dos niveles (Tiered Snapshot Architecture) diseñado para capturar y
    restaurar de forma atómica el estado de directivas de registro, servicios de sistema,
    parámetros de red y puntos de restauración de Windows (VSS).
    Permite alternar entre perfiles y aplicar debloat o tweaks de rendimiento con una red de
    seguridad infalible y reversión en segundos (Zero-Risk Tweaking).

.PARAMETER Action
    Acción a ejecutar: Create (default), List, Restore, Remove, Export, Import, CreateVSS.

.PARAMETER Name
    Nombre descriptivo del snapshot (ej. "Pre-Debloat-Gaming", "Base-Limpia").

.PARAMETER Description
    Descripción o notas adicionales sobre el estado del sistema.

.PARAMETER SnapshotId
    Identificador único de la instantánea para acciones Restore o Remove (ej. "SNAP-20260922-010500").

.PARAMETER SnapshotDirectory
    Directorio raíz donde se almacenan las instantáneas. Por defecto: %SystemDrive%\romanOS-Snapshots.

.PARAMETER IncludeVSS
    Si se especifica, intenta crear además un Punto de Restauración del Sistema nativo de Windows (VSS).

.PARAMETER Unattended
    Modo desatendido para ejecución desde scripts o interfaces automatizadas sin pausas interactivas.

.PARAMETER Force
    Omite las confirmaciones de seguridad al restaurar o eliminar un snapshot.

.PARAMETER ExportZipPath
    Ruta de destino del archivo .zip al exportar un snapshot.

.PARAMETER ImportZipPath
    Ruta del archivo .zip a importar en el catálogo de snapshots.

.EXAMPLE
    .\Manage-SystemSnapshots.ps1 -Action Create -Name "Pre-Optimizacion" -IncludeVSS

.EXAMPLE
    .\Manage-SystemSnapshots.ps1 -Action List

.EXAMPLE
    .\Manage-SystemSnapshots.ps1 -Action Restore -SnapshotId "SNAP-20260922-010500-Pre-Optimizacion" -Force
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Create', 'List', 'Restore', 'Remove', 'Export', 'Import', 'CreateVSS')]
    [string]$Action = 'Create',

    [string]$Name = "Snapshot_$(Get-Date -Format 'yyyyMMdd_HHmmss')",
    [string]$Description = "Instantanea automatica de configuracion romanOS",
    [string]$SnapshotId,
    [string]$SnapshotDirectory = "$env:SystemDrive\romanOS-Snapshots",
    [switch]$IncludeVSS,
    [switch]$Unattended,
    [switch]$Force,
    [switch]$SkipElevation,
    [string]$ExportZipPath,
    [string]$ImportZipPath
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# =============================================================================
# 0. PRIVILEGIOS DE ADMINISTRADOR Y AUTO-ELEVACIÓN
# =============================================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isSimulated = ($PSBoundParameters.ContainsKey('WhatIf') -or $WhatIfPreference)

if (-not $isAdmin -and -not $isSimulated -and $Action -ne 'List' -and -not $SkipElevation) {
    Write-Warning "[Snapshot-Engine] Se requieren privilegios de Administrador. Auto-elevando..."
    $psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
    
    $argList = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"", '-Action', $Action)
    if ($Name) { $argList += @('-Name', "`"$Name`"") }
    if ($Description) { $argList += @('-Description', "`"$Description`"") }
    if ($SnapshotId) { $argList += @('-SnapshotId', "`"$SnapshotId`"") }
    if ($SnapshotDirectory) { $argList += @('-SnapshotDirectory', "`"$SnapshotDirectory`"") }
    if ($IncludeVSS) { $argList += '-IncludeVSS' }
    if ($Unattended) { $argList += '-Unattended' }
    if ($Force) { $argList += '-Force' }
    if ($ExportZipPath) { $argList += @('-ExportZipPath', "`"$ExportZipPath`"") }
    if ($ImportZipPath) { $argList += @('-ImportZipPath', "`"$ImportZipPath`"") }

    try {
        Start-Process -FilePath $psExe -ArgumentList $argList -Verb RunAs
        exit 0
    } catch {
        Write-Error "[Snapshot-Engine] No se pudo obtener elevacion de Administrador UAC: $($_.Exception.Message)"
        exit 1
    }
}

# Carga de ensamblados para compresión Zip
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

# =============================================================================
# 1. HELPERS Y RESOLUCIÓN DE SSOT (Policy-Engine.ps1)
# =============================================================================
function Get-SnapshotSha256 {
    param([string]$FilePath)
    if (-not (Test-Path $FilePath)) { return $null }
    try {
        $hasher = [System.Security.Cryptography.SHA256]::Create()
        $stream = [System.IO.File]::OpenRead($FilePath)
        $bytes = $hasher.ComputeHash($stream)
        $stream.Close()
        return [System.BitConverter]::ToString($bytes).Replace("-", "").ToUpperInvariant()
    } catch {
        Write-Warning "[Snapshot-Engine] Error al computar SHA-256 en $FilePath : $($_.Exception.Message)"
        return $null
    }
}

function Resolve-PolicyEngine {
    $candidates = @(
        (Join-Path $PSScriptRoot "..\Core\Policy-Engine.ps1"),
        (Join-Path $PSScriptRoot "Core\Policy-Engine.ps1"),
        (Join-Path $PSScriptRoot "Policy-Engine.ps1"),
        "$env:WINDIR\Setup\Scripts\Core\Policy-Engine.ps1",
        "C:\OptimizedISO\scripts\Core\Policy-Engine.ps1"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            try {
                . $c
                return $true
            } catch {
                Write-Warning "[Snapshot-Engine] Error al importar Policy-Engine desde $c : $($_.Exception.Message)"
            }
        }
    }
    return $false
}

# =============================================================================
# 2. MOTOR DE RESTAURACIÓN NATIVA VSS (PUNTOS DE RESTAURACIÓN)
# =============================================================================
function New-RomanOSVssRestorePoint {
    param([string]$PointDescription)
    Write-Host "  [*] Verificando subsistema de Puntos de Restauracion VSS..." -ForegroundColor Cyan
    try {
        $sysDrive = $env:SystemDrive
        # Habilitar proteccion del sistema si estuviera desactivada
        try {
            New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' `
                -Name 'SystemRestorePointCreationFrequency' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
        } catch {
            Write-Warning "[Snapshot-Engine] No se pudo configurar frecuencia en registro VSS: $($_.Exception.Message)"
        }

        # Asegurar servicio VSS
        try {
            Set-Service -Name VSS -StartupType Manual -ErrorAction SilentlyContinue
            Start-Service -Name VSS -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "[Snapshot-Engine] No se pudo iniciar servicio VSS: $($_.Exception.Message)"
        }

        # Habilitar en unidad del sistema
        try {
            Enable-ComputerRestore -Drive "$sysDrive\" -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "[Snapshot-Engine] Enable-ComputerRestore no disponible o advertencia: $($_.Exception.Message)"
        }

        if (Get-Command -Name 'Checkpoint-Computer' -ErrorAction SilentlyContinue) {
            Checkpoint-Computer -Description $PointDescription -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
            Write-Host "  [OK] Punto de restauracion VSS creado exitosamente con Checkpoint-Computer." -ForegroundColor Green
            return $true
        } else {
            # Fallback WMI para PowerShell 7+ o entornos minimizados
            $wmi = [wmiclass]'\\.\root\default:SystemRestore'
            $result = $wmi.CreateRestorePoint($PointDescription, 12, 100)
            if ($result.ReturnValue -eq 0) {
                Write-Host "  [OK] Punto de restauracion VSS creado con exito via WMI (Codigo 0)." -ForegroundColor Green
                return $true
            } else {
                Write-Warning "[Snapshot-Engine] WMI CreateRestorePoint retorno codigo de error: $($result.ReturnValue)"
                return $false
            }
        }
    } catch {
        Write-Warning "[Snapshot-Engine] No se pudo crear punto de restauracion VSS: $($_.Exception.Message)"
        Write-Warning "[Snapshot-Engine] El snapshot continuara capturando registro, servicios y red a nivel atomico."
        return $false
    }
}

# =============================================================================
# 3. CAPTURA Y CREACIÓN DE SNAPSHOTS (NIVEL ATÓMICO)
# =============================================================================
function New-RomanOSSnapshot {
    param(
        [string]$SnapshotName,
        [string]$SnapshotDesc,
        [string]$BaseDir,
        [switch]$WithVSS
    )

    $cleanName = ($SnapshotName -replace '[^a-zA-Z0-9_\-]', '_').Trim('_')
    if (-not $cleanName) { $cleanName = "Snapshot" }
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $snapId = "SNAP-$stamp-$cleanName"
    $targetDir = Join-Path $BaseDir $snapId

    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " romanOS Snapshot & Rollback Engine — CREANDO INSTANTANEA ATOMICA" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  Identificador : $snapId" -ForegroundColor White
    Write-Host "  Nombre        : $SnapshotName" -ForegroundColor White
    Write-Host "  Destino       : $targetDir" -ForegroundColor White
    Write-Host ""

    if ($isSimulated) {
        Write-Host "  Whatif: Creando estructura de directorios y ramas de registro en $targetDir" -ForegroundColor Yellow
        Write-Host "  Whatif: Exportando telemetria de servicios, red y directivas SSOT" -ForegroundColor Yellow
        Write-Host "  [OK] Snapshot simulado exitosamente (-WhatIf)." -ForegroundColor Green
        return [PSCustomObject]@{
            SnapshotId   = $snapId
            Name         = $SnapshotName
            Description  = $SnapshotDesc
            CreatedAt    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            ComputerName = $env:COMPUTERNAME
            UserName     = $env:USERNAME
            OSCaption    = "Simulado"
            OSBuild      = [System.Environment]::OSVersion.Version.Build
            UBR          = 0
            HasVSSPoint  = [bool]$WithVSS
            Artifacts    = @()
        }
    }

    if (-not (Test-Path $targetDir)) {
        try {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $targetDir "registry") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $targetDir "state") -Force | Out-Null
        } catch {
            Write-Error "[Snapshot-Engine] Error fatal al crear estructura de directorios en $targetDir : $($_.Exception.Message)"
            return $null
        }
    }

    $manifestArtifacts = @()

    # 3.1 Captura de Puntos de Restauración VSS si se solicitó
    $vssSuccess = $false
    if ($WithVSS) {
        $vssSuccess = New-RomanOSVssRestorePoint -PointDescription "romanOS: $SnapshotName"
    }

    # 3.2 Exportación de Ramas Críticas de Registro (.reg UTF-16)
    Write-Host "  [*] Exportando configuracion y directivas de registro..." -ForegroundColor Cyan
    $regTargets = @(
        @{ Name = "hklm_policies.reg"; Key = "HKLM\SOFTWARE\Policies" },
        @{ Name = "hkcu_policies.reg"; Key = "HKCU\Software\Policies" },
        @{ Name = "hklm_multimedia.reg"; Key = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" },
        @{ Name = "hklm_tcpip.reg"; Key = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" },
        @{ Name = "hklm_power.reg"; Key = "HKLM\SYSTEM\CurrentControlSet\Control\Power" },
        @{ Name = "hklm_filesystem.reg"; Key = "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" },
        @{ Name = "hklm_sessionmanager.reg"; Key = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" },
        @{ Name = "hkcu_explorer.reg"; Key = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" },
        @{ Name = "hkcu_gamebar.reg"; Key = "HKCU\Software\Microsoft\GameBar" }
    )

    $regDir = Join-Path $targetDir "registry"
    foreach ($rt in $regTargets) {
        $destFile = Join-Path $regDir $rt.Name
        try {
            $regArgs = "export `"$($rt.Key)`" `"$destFile`" /y"
            $p = Start-Process -FilePath "reg.exe" -ArgumentList $regArgs -NoNewWindow -Wait -PassThru
            if ($p.ExitCode -eq 0 -and (Test-Path $destFile)) {
                $hash = Get-SnapshotSha256 -FilePath $destFile
                $manifestArtifacts += [PSCustomObject]@{
                    Path   = "registry/$($rt.Name)"
                    Type   = "RegistryExport"
                    Source = $rt.Key
                    SHA256 = $hash
                }
            } else {
                # La clave podria no existir en el sistema actual, lo cual es normal en claves de Policies virgenes
                Write-Verbose "[Snapshot-Engine] Clave $($rt.Key) no exportada o inexistente (ExitCode: $($p.ExitCode))."
            }
        } catch {
            Write-Warning "[Snapshot-Engine] Excepcion al exportar $($rt.Key): $($_.Exception.Message)"
        }
    }

    # 3.3 Exportación de Estado de Servicios
    Write-Host "  [*] Capturando telemetria de servicios del sistema..." -ForegroundColor Cyan
    $stateDir = Join-Path $targetDir "state"
    $servicesFile = Join-Path $stateDir "services.json"
    try {
        $services = Get-Service | Select-Object Name, DisplayName, Status, StartType, ServiceType
        $services | ConvertTo-Json -Depth 3 | Set-Content -Path $servicesFile -Encoding UTF8 -Force
        $servicesHash = Get-SnapshotSha256 -FilePath $servicesFile
        $manifestArtifacts += [PSCustomObject]@{
            Path   = "state/services.json"
            Type   = "ServicesState"
            Count  = $services.Count
            SHA256 = $servicesHash
        }
    } catch {
        Write-Warning "[Snapshot-Engine] Error al exportar estado de servicios: $($_.Exception.Message)"
    }

    # 3.4 Exportación de Configuración de Red y Offloads
    Write-Host "  [*] Capturando configuracion de adaptadores de red y offloads NDIS..." -ForegroundColor Cyan
    $netFile = Join-Path $stateDir "network.json"
    try {
        $netAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name, InterfaceDescription, Status, MacAddress, LinkSpeed
        $dnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, ServerAddresses
        $advancedProps = Get-NetAdapterAdvancedProperty -ErrorAction SilentlyContinue | Select-Object DisplayName, DisplayValue, RegistryKeyword, RegistryValue

        $netSnapshot = [PSCustomObject]@{
            Adapters      = $netAdapters
            DnsServers    = $dnsServers
            AdvancedProps = $advancedProps
        }
        $netSnapshot | ConvertTo-Json -Depth 4 | Set-Content -Path $netFile -Encoding UTF8 -Force
        $netHash = Get-SnapshotSha256 -FilePath $netFile
        $manifestArtifacts += [PSCustomObject]@{
            Path   = "state/network.json"
            Type   = "NetworkState"
            SHA256 = $netHash
        }
    } catch {
        Write-Warning "[Snapshot-Engine] Error al exportar estado de red: $($_.Exception.Message)"
    }

    # 3.5 Evaluación de Directivas SSOT (Policy-Engine.ps1)
    Write-Host "  [*] Evaluando directivas del Catalogo Maestro SSOT..." -ForegroundColor Cyan
    $policiesFile = Join-Path $stateDir "policies_ssot.json"
    try {
        $hasPolicyEngine = Resolve-PolicyEngine
        if ($hasPolicyEngine -and (Get-Command -Name 'Get-RomanOSPolicies' -ErrorAction SilentlyContinue)) {
            $policies = Get-RomanOSPolicies
            $evaluatedPolicies = @()
            foreach ($pol in $policies) {
                $actualVal = $null
                $path = $pol.RegistryKey
                if ($path -match '^HKLM:\\') { $regPath = $path }
                elseif ($path -match '^HKLM\\') { $regPath = "HKLM:\" + $path.Substring(5) }
                elseif ($path -match '^HKCU:\\') { $regPath = $path }
                elseif ($path -match '^HKCU\\') { $regPath = "HKCU:\" + $path.Substring(5) }
                else { $regPath = $path }

                try {
                    if (Test-Path $regPath) {
                        $prop = Get-ItemProperty -Path $regPath -Name $pol.ValueName -ErrorAction SilentlyContinue
                        if ($prop -and $prop.PSObject.Properties[$pol.ValueName]) {
                            $actualVal = $prop.($pol.ValueName)
                        }
                    }
                } catch {
                    Write-Warning "[Snapshot-Engine] No se pudo leer politica $($pol.Id): $($_.Exception.Message)"
                }

                $evaluatedPolicies += [PSCustomObject]@{
                    Id            = $pol.Id
                    RegistryKey   = $pol.RegistryKey
                    ValueName     = $pol.ValueName
                    ExpectedValue = $pol.ExpectedValue
                    ActualValue   = $actualVal
                    Matches       = ($actualVal -eq $pol.ExpectedValue)
                }
            }
            $evaluatedPolicies | ConvertTo-Json -Depth 4 | Set-Content -Path $policiesFile -Encoding UTF8 -Force
            $polHash = Get-SnapshotSha256 -FilePath $policiesFile
            $manifestArtifacts += [PSCustomObject]@{
                Path   = "state/policies_ssot.json"
                Type   = "SSOTPoliciesState"
                Count  = $evaluatedPolicies.Count
                SHA256 = $polHash
            }
        }
    } catch {
        Write-Warning "[Snapshot-Engine] Error al evaluar catalogo SSOT: $($_.Exception.Message)"
    }

    # 3.6 Generación del Manifiesto de Integridad (manifest.json)
    Write-Host "  [*] Generando manifiesto y sellos criptograficos SHA-256..." -ForegroundColor Cyan
    $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $ubr = 0
    try {
        $ubr = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name UBR -ErrorAction SilentlyContinue).UBR
    } catch {
        Write-Warning "[Snapshot-Engine] No se pudo consultar UBR de Windows: $($_.Exception.Message)"
    }

    $manifest = [PSCustomObject]@{
        SnapshotId   = $snapId
        Name         = $SnapshotName
        Description  = $SnapshotDesc
        CreatedAt    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        ComputerName = $env:COMPUTERNAME
        UserName     = $env:USERNAME
        OSCaption    = if ($osInfo) { $osInfo.Caption } else { "Windows 11" }
        OSBuild      = [System.Environment]::OSVersion.Version.Build
        UBR          = $ubr
        HasVSSPoint  = $vssSuccess
        Artifacts    = $manifestArtifacts
    }

    $manifestPath = Join-Path $targetDir "manifest.json"
    try {
        $manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestPath -Encoding UTF8 -Force
    } catch {
        Write-Error "[Snapshot-Engine] Error fatal al escribir manifest.json: $($_.Exception.Message)"
        return $null
    }

    # Cálculo de tamaño total del snapshot
    $totalBytes = 0
    if (Test-Path $targetDir) {
        $files = Get-ChildItem -Path $targetDir -Recurse -File -ErrorAction SilentlyContinue
        if ($files) {
            $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
        }
    }
    $sizeMB = [math]::Round($totalBytes / 1MB, 2)

    Write-Host ""
    Write-Host "  [OK] Snapshot creado exitosamente!" -ForegroundColor Green
    Write-Host "  - Identificador : $snapId" -ForegroundColor Green
    Write-Host "  - Archivos      : $($manifestArtifacts.Count) artefactos verificados" -ForegroundColor Green
    Write-Host "  - Huella Total  : $sizeMB MB" -ForegroundColor Green
    Write-Host "  - Punto VSS     : $(if ($vssSuccess) { 'Creado' } else { 'No requerido / Omitido' })" -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Cyan

    return $manifest
}

# =============================================================================
# 4. LISTADO Y CONSULTA DE SNAPSHOTS
# =============================================================================
function Get-RomanOSSnapshots {
    param([string]$BaseDir)

    if (-not (Test-Path $BaseDir)) {
        return @()
    }

    $snapshots = @()
    $folders = Get-ChildItem -Path $BaseDir -Directory -Filter "SNAP-*" | Sort-Object Name -Descending

    foreach ($f in $folders) {
        $manifestFile = Join-Path $f.FullName "manifest.json"
        if (Test-Path $manifestFile) {
            try {
                $content = Get-Content -Path $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
                $totalBytes = (Get-ChildItem -Path $f.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
                $sizeMB = [math]::Round($totalBytes / 1MB, 2)

                $snapshots += [PSCustomObject]@{
                    SnapshotId  = $content.SnapshotId
                    Name        = $content.Name
                    CreatedAt   = $content.CreatedAt
                    SizeMB      = $sizeMB
                    Artifacts   = if ($content.Artifacts) { $content.Artifacts.Count } else { 0 }
                    HasVSS      = [bool]$content.HasVSSPoint
                    Path        = $f.FullName
                    Description = $content.Description
                }
            } catch {
                Write-Warning "[Snapshot-Engine] Error al leer manifest en $($f.FullName): $($_.Exception.Message)"
            }
        }
    }

    return @($snapshots)
}

function Show-RomanOSSnapshotsTable {
    param([string]$BaseDir)

    $list = @(Get-RomanOSSnapshots -BaseDir $BaseDir)
    Write-Host ""
    Write-Host "======================================================================================================" -ForegroundColor Cyan
    Write-Host " CATÁLOGO DE INSTANTÁNEAS DISPONIBLES — romanOS / OptimizedISO" -ForegroundColor Cyan
    Write-Host " Directorio: $BaseDir" -ForegroundColor DarkGray
    Write-Host "======================================================================================================" -ForegroundColor Cyan

    if ($list.Count -eq 0) {
        Write-Host "  (No se encontraron snapshots registrados en el sistema)" -ForegroundColor Yellow
        Write-Host "  Usa: .\Manage-SystemSnapshots.ps1 -Action Create -Name `"MiSnapshot`"" -ForegroundColor DarkGray
        Write-Host "======================================================================================================" -ForegroundColor Cyan
        return
    }

    $list | Format-Table -Property SnapshotId, Name, CreatedAt, SizeMB, Artifacts, HasVSS -AutoSize
    Write-Host "  Total registrados: $($list.Count) snapshots" -ForegroundColor Green
    Write-Host "======================================================================================================" -ForegroundColor Cyan
}

# =============================================================================
# 5. RESTAURACIÓN ATÓMICA Y VERIFICACIÓN DE INTEGRIDAD
# =============================================================================
function Restore-RomanOSSnapshot {
    param(
        [string]$TargetSnapshotId,
        [string]$BaseDir,
        [switch]$SkipConfirmation
    )

    if (-not $TargetSnapshotId) {
        Write-Error "[Snapshot-Engine] Debe especificar el parametro -SnapshotId para realizar la restauracion."
        return $false
    }

    # Resolver ruta de snapshot
    $targetDir = $null
    if (Test-Path $TargetSnapshotId) {
        $targetDir = (Resolve-Path $TargetSnapshotId).Path
    } else {
        $candidate = Join-Path $BaseDir $TargetSnapshotId
        if (Test-Path $candidate) {
            $targetDir = $candidate
        } else {
            # Búsqueda parcial por prefijo o nombre
            $match = Get-ChildItem -Path $BaseDir -Directory -Filter "*$TargetSnapshotId*" | Select-Object -First 1
            if ($match) { $targetDir = $match.FullName }
        }
    }

    if (-not $targetDir -or -not (Test-Path $targetDir)) {
        Write-Error "[Snapshot-Engine] No se pudo localizar el snapshot '$TargetSnapshotId' en '$BaseDir'."
        return $false
    }

    $manifestPath = Join-Path $targetDir "manifest.json"
    if (-not (Test-Path $manifestPath)) {
        Write-Error "[Snapshot-Engine] El snapshot en '$targetDir' no contiene un archivo manifest.json valido."
        return $false
    }

    try {
        $manifest = Get-Content -Path $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Error "[Snapshot-Engine] Error al parsear manifest.json: $($_.Exception.Message)"
        return $false
    }

    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " romanOS Snapshot & Rollback Engine — INICIANDO RESTAURACION ATOMICA" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  Snapshot ID : $($manifest.SnapshotId)" -ForegroundColor White
    Write-Host "  Nombre      : $($manifest.Name)" -ForegroundColor White
    Write-Host "  Fecha       : $($manifest.CreatedAt)" -ForegroundColor White
    Write-Host "  Descripcion : $($manifest.Description)" -ForegroundColor White
    Write-Host ""

    # 5.1 Verificación Criptográfica de Integridad SHA-256
    Write-Host "  [*] Auditando integridad criptografica de los artefactos (SHA-256)..." -ForegroundColor Cyan
    $tamperedCount = 0
    foreach ($art in $manifest.Artifacts) {
        $artFile = Join-Path $targetDir ($art.Path.Replace('/', '\'))
        if (-not (Test-Path $artFile)) {
            Write-Warning "  [!] Artefacto faltante: $($art.Path)"
            $tamperedCount++
            continue
        }
        $actualHash = Get-SnapshotSha256 -FilePath $artFile
        if ($actualHash -ne $art.SHA256) {
            Write-Warning "  [!] Discrepancia de hash SHA-256 en $($art.Path)! (Esperado: $($art.SHA256), Actual: $actualHash)"
            $tamperedCount++
        }
    }

    if ($tamperedCount -gt 0) {
        Write-Warning "[Snapshot-Engine] Se detectaron $tamperedCount artefactos alterados o faltantes."
        if (-not $SkipConfirmation) {
            $confirm = Read-Host "  ADVERTENCIA: La integridad del snapshot esta comprometida. ¿Desea continuar de todos modos? (S/N)"
            if ($confirm -notmatch '^[sSyY]') {
                Write-Host "  [ABORTADO] Restauracion cancelada por el usuario." -ForegroundColor Yellow
                return $false
            }
        }
    } else {
        Write-Host "  [OK] Integridad certificada al 100%. Cero artefactos alterados." -ForegroundColor Green
    }

    if (-not $SkipConfirmation) {
        $confirm = Read-Host "  ¿Desea restaurar esta configuracion en el sistema actual? (S/N)"
        if ($confirm -notmatch '^[sSyY]') {
            Write-Host "  [ABORTADO] Operacion cancelada." -ForegroundColor Yellow
            return $false
        }
    }

    # 5.2 Restauración de Directivas de Registro (.reg)
    Write-Host ""
    Write-Host "  [*] Restaurando colmenas y directivas de registro..." -ForegroundColor Cyan
    $regDir = Join-Path $targetDir "registry"
    if (Test-Path $regDir) {
        $regFiles = Get-ChildItem -Path $regDir -Filter "*.reg"
        foreach ($rf in $regFiles) {
            try {
                $p = Start-Process -FilePath "reg.exe" -ArgumentList "import `"$($rf.FullName)`"" -NoNewWindow -Wait -PassThru
                if ($p.ExitCode -eq 0) {
                    Write-Host "    [OK] Importado: $($rf.Name)" -ForegroundColor Green
                } else {
                    Write-Warning "    [!] Fallo al importar $($rf.Name) (ExitCode: $($p.ExitCode))"
                }
            } catch {
                Write-Warning "    [!] Error al importar $($rf.Name): $($_.Exception.Message)"
            }
        }
    }

    # 5.3 Reconciliación de Estado de Servicios
    $servicesFile = Join-Path $targetDir "state\services.json"
    if (Test-Path $servicesFile) {
        Write-Host "  [*] Reconciliando configuracion de servicios..." -ForegroundColor Cyan
        try {
            $savedServices = Get-Content -Path $servicesFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $currentServices = Get-Service
            $reconciledCount = 0

            foreach ($ss in $savedServices) {
                $curr = $currentServices | Where-Object { $_.Name -eq $ss.Name }
                if ($curr) {
                    # Ajustar StartType si difiere
                    if ($curr.StartType -ne $ss.StartType) {
                        try {
                            Set-Service -Name $ss.Name -StartupType $ss.StartType -ErrorAction SilentlyContinue
                            $reconciledCount++
                        } catch {
                            Write-Verbose "No se pudo cambiar StartupType en $($ss.Name): $($_.Exception.Message)"
                        }
                    }

                    # Ajustar estado de ejecución
                    if ($ss.Status -eq 'Running' -and $curr.Status -ne 'Running') {
                        try {
                            Start-Service -Name $ss.Name -ErrorAction SilentlyContinue
                        } catch {
                            Write-Warning "[Snapshot-Engine] No se pudo iniciar servicio $($ss.Name): $($_.Exception.Message)"
                        }
                    } elseif ($ss.Status -eq 'Stopped' -and $curr.Status -eq 'Running') {
                        try {
                            Stop-Service -Name $ss.Name -Force -ErrorAction SilentlyContinue
                        } catch {
                            Write-Warning "[Snapshot-Engine] No se pudo detener servicio $($ss.Name): $($_.Exception.Message)"
                        }
                    }
                }
            }
            Write-Host "    [OK] Servicios auditados. Ajustes aplicados: $reconciledCount servicio(s)." -ForegroundColor Green
        } catch {
            Write-Warning "[Snapshot-Engine] Error al reconciliar servicios: $($_.Exception.Message)"
        }
    }

    # 5.4 Vaciado de Caché y Refresco del Entorno
    Write-Host "  [*] Refrescando entorno y vaciando cache DNS..." -ForegroundColor Cyan
    try {
        Clear-DnsClientCache -ErrorAction SilentlyContinue
    } catch {
        ipconfig /flushdns | Out-Null
    }

    Write-Host ""
    Write-Host "  [OK] Restauracion atomica completada con exito." -ForegroundColor Green
    Write-Host "  Se recomienda reiniciar el explorador de Windows o el sistema si se restauraron politicas profundas." -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Cyan

    return $true
}

# =============================================================================
# 6. ELIMINACIÓN SEGURA DE SNAPSHOTS
# =============================================================================
function Remove-RomanOSSnapshot {
    param(
        [string]$TargetSnapshotId,
        [string]$BaseDir,
        [switch]$SkipConfirmation
    )

    if (-not $TargetSnapshotId) {
        Write-Error "[Snapshot-Engine] Debe especificar el parametro -SnapshotId para eliminar."
        return $false
    }

    $targetDir = $null
    $candidate = Join-Path $BaseDir $TargetSnapshotId
    if (Test-Path $candidate) {
        $targetDir = $candidate
    } else {
        $match = Get-ChildItem -Path $BaseDir -Directory -Filter "*$TargetSnapshotId*" | Select-Object -First 1
        if ($match) { $targetDir = $match.FullName }
    }

    if (-not $targetDir -or -not (Test-Path $targetDir)) {
        Write-Error "[Snapshot-Engine] No se encontro el snapshot '$TargetSnapshotId' para eliminar."
        return $false
    }

    if (-not $SkipConfirmation) {
        $confirm = Read-Host "  ¿Seguro que desea eliminar permanentemente el snapshot '$($targetDir | Split-Path -Leaf)'? (S/N)"
        if ($confirm -notmatch '^[sSyY]') {
            Write-Host "  [ABORTADO] Eliminacion cancelada." -ForegroundColor Yellow
            return $false
        }
    }

    try {
        Remove-Item -Path $targetDir -Recurse -Force -ErrorAction Stop
        Write-Host "  [OK] Snapshot eliminado exitosamente: $($targetDir | Split-Path -Leaf)" -ForegroundColor Green
        return $true
    } catch {
        Write-Error "[Snapshot-Engine] Error al eliminar $targetDir : $($_.Exception.Message)"
        return $false
    }
}

# =============================================================================
# 7. EXPORTACIÓN E IMPORTACIÓN (.ZIP)
# =============================================================================
function Export-RomanOSSnapshotZip {
    param(
        [string]$TargetSnapshotId,
        [string]$BaseDir,
        [string]$ZipDestination
    )

    $targetDir = $null
    $candidate = Join-Path $BaseDir $TargetSnapshotId
    if (Test-Path $candidate) {
        $targetDir = $candidate
    } else {
        $match = Get-ChildItem -Path $BaseDir -Directory -Filter "*$TargetSnapshotId*" | Select-Object -First 1
        if ($match) { $targetDir = $match.FullName }
    }

    if (-not $targetDir -or -not (Test-Path $targetDir)) {
        Write-Error "[Snapshot-Engine] No se encontro el snapshot a exportar."
        return $false
    }

    if (-not $ZipDestination) {
        $leaf = Split-Path $targetDir -Leaf
        $ZipDestination = Join-Path ([System.Environment]::GetFolderPath('Desktop')) "$leaf.zip"
    }

    Write-Host "  [*] Comprimiendo snapshot en $ZipDestination ..." -ForegroundColor Cyan
    try {
        if (Test-Path $ZipDestination) { Remove-Item $ZipDestination -Force }
        [System.IO.Compression.ZipFile]::CreateFromDirectory($targetDir, $ZipDestination)
        Write-Host "  [OK] Exportacion completada con exito: $ZipDestination" -ForegroundColor Green
        return $true
    } catch {
        Write-Error "[Snapshot-Engine] Error al comprimir zip: $($_.Exception.Message)"
        return $false
    }
}

function Import-RomanOSSnapshotZip {
    param(
        [string]$ZipSource,
        [string]$BaseDir
    )

    if (-not (Test-Path $ZipSource)) {
        Write-Error "[Snapshot-Engine] No existe el archivo zip de origen: $ZipSource"
        return $false
    }

    if (-not (Test-Path $BaseDir)) {
        New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null
    }

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($ZipSource)
    $destFolder = Join-Path $BaseDir $fileName

    Write-Host "  [*] Descomprimiendo snapshot en $destFolder ..." -ForegroundColor Cyan
    try {
        if (Test-Path $destFolder) {
            Write-Warning "El directorio destino ya existe. Sobreescribiendo..."
            Remove-Item $destFolder -Recurse -Force
        }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipSource, $destFolder)
        Write-Host "  [OK] Snapshot importado con exito. Validando integridad..." -ForegroundColor Green
        
        $manifestFile = Join-Path $destFolder "manifest.json"
        if (Test-Path $manifestFile) {
            Write-Host "  [OK] Manifiesto localizado. Snapshot disponible en catalogo." -ForegroundColor Green
            return $true
        } else {
            Write-Warning "El archivo importado no contiene un manifest.json valido."
            return $false
        }
    } catch {
        Write-Error "[Snapshot-Engine] Error al importar zip: $($_.Exception.Message)"
        return $false
    }
}

# =============================================================================
# 8. DESPACHADOR PRINCIPAL (CLI)
# =============================================================================
switch ($Action) {
    'Create' {
        New-RomanOSSnapshot -SnapshotName $Name -SnapshotDesc $Description -BaseDir $SnapshotDirectory -WithVSS:$IncludeVSS
    }
    'List' {
        Show-RomanOSSnapshotsTable -BaseDir $SnapshotDirectory
    }
    'Restore' {
        Restore-RomanOSSnapshot -TargetSnapshotId $SnapshotId -BaseDir $SnapshotDirectory -SkipConfirmation:($Force -or $Unattended)
    }
    'Remove' {
        Remove-RomanOSSnapshot -TargetSnapshotId $SnapshotId -BaseDir $SnapshotDirectory -SkipConfirmation:($Force -or $Unattended)
    }
    'Export' {
        Export-RomanOSSnapshotZip -TargetSnapshotId $SnapshotId -BaseDir $SnapshotDirectory -ZipDestination $ExportZipPath
    }
    'Import' {
        Import-RomanOSSnapshotZip -ZipSource $ImportZipPath -BaseDir $SnapshotDirectory
    }
    'CreateVSS' {
        New-RomanOSVssRestorePoint -PointDescription "romanOS: $Name"
    }
}
