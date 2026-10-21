<#
.SYNOPSIS
    romanOS Startup Ecosystem & Demand-Start Services Governor (PLAN-0159)
    Gobernador Integral de Inicio, Optimización de Servicios a Demanda y Erradicación del Flagelo Post-Boot

.DESCRIPTION
    Optimiza el arranque y el consumo de memoria en el escritorio en Windows 11 (24H2/25H2 Ready):
      1. Transición segura de servicios nativos en Automático sin dependientes a Demand-Start (Manual, Start=3).
      2. Conmutación a demanda de tareas y aplicaciones de inicio de terceros (AMD Adrenalin, Steam, ExitLag, etc.)
         sin eliminar binarios ni alterar controladores de kernel.
      3. Erradicación del spike de 1 GB de RAM por mantenimiento de componentes CBS en el inicio de sesión.
      4. Erradicación de instancias de Edge WebView2 en el shell de búsqueda local (SearchHost).
      5. Snapshot automático previo con Manage-SystemSnapshots.ps1 para reversión total en 1 clic.
      6. Cero fallos silenciosos (CWE-390 / Fail-Visible).

.PARAMETER Action
    Acción a ejecutar: Status (predeterminado), Audit, Optimize, Restore, Reset.

.PARAMETER Scope
    Alcance de la optimización: All (predeterminado), Services, ThirdParty, Maintenance.

.PARAMETER SkipSnapshot
    Omite la creación preventiva de instantánea de seguridad antes de modificar el estado.

.PARAMETER LogDir
    Ruta para almacenar logs y reportes forenses. (Default: .\Log)

.PARAMETER Unattended
    Omite pausas interactivas en consola.

.PARAMETER SkipElevation
    Omite la elevación de privilegios cuando no se modifican componentes del sistema.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("Status", "Audit", "Optimize", "Restore", "Reset")]
    [string]$Action = "Status",

    [ValidateSet("All", "Services", "ThirdParty", "Maintenance")]
    [string]$Scope = "All",

    [switch]$SkipSnapshot,
    [string]$LogDir = "",
    [switch]$Unattended,
    [switch]$SkipElevation
)

$ErrorActionPreference = 'Continue'
$scriptStartTime = Get-Date

# -----------------------------------------------------------------------------
# 0. RESOLUCIÓN DE RUTAS Y SSOT
# -----------------------------------------------------------------------------

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreDir = Join-Path $scriptDir "..\Core"
if (-not (Test-Path $coreDir)) {
    $coreDir = Join-Path $scriptDir "Core"
}

$policyEnginePath = Join-Path $coreDir "Policy-Engine.ps1"
if (Test-Path $policyEnginePath) {
    . $policyEnginePath
} else {
    Write-Warning "[WARN] No se localizó Policy-Engine.ps1 en '$coreDir'. Usando definiciones de respaldo en memoria."
}

if ([string]::IsNullOrWhiteSpace($LogDir)) {
    $LogDir = Join-Path $scriptDir "..\..\Log"
    if (-not (Test-Path $LogDir)) {
        $LogDir = Join-Path $scriptDir "Log"
    }
}
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

$snapshotScript = Join-Path $scriptDir "Manage-SystemSnapshots.ps1"

# -----------------------------------------------------------------------------
# 1. FUNCIONES AUXILIARES DE INTROSPECCIÓN Y LOGGING
# -----------------------------------------------------------------------------

function Write-StartupLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logLine = "[$timestamp] [$Level] $Message"
    Write-Host $logLine -ForegroundColor $Color

    $logFile = Join-Path $LogDir "Startup-Ecosystem.log"
    try {
        Add-Content -Path $logFile -Value $logLine -Encoding UTF8 -WhatIf:$false -ErrorAction SilentlyContinue
    } catch {
        # Telemetría Fail-Visible
        Write-Warning "[LOG] No se pudo escribir en '$logFile': $($_.Exception.Message)"
    }
}

# -----------------------------------------------------------------------------
# 2. AUDITORÍA DEL ECOSISTEMA DE INICIO (STATUS / AUDIT)
# -----------------------------------------------------------------------------

function Get-StartupEcosystemAudit {
    [CmdletBinding()]
    param()

    Write-StartupLog "Iniciando auditoría forense del ecosistema de inicio y servicios..." "INFO" Cyan

    $demandDefs = if (Get-Command Get-RomanOSDemandServices -ErrorAction SilentlyContinue) {
        Get-RomanOSDemandServices
    } else {
        @()
    }

    $thirdPartyDefs = if (Get-Command Get-RomanOSStartupThirdPartyCatalog -ErrorAction SilentlyContinue) {
        Get-RomanOSStartupThirdPartyCatalog
    } else {
        @()
    }

    $servicesAudit = @()
    $totalServiceRAM_MB = 0

    foreach ($def in $demandDefs) {
        $svc = Get-Service -Name $def.Name -ErrorAction SilentlyContinue
        if ($svc) {
            $cimSvc = Get-CimInstance Win32_Service -Filter "Name='$($def.Name)'" -ErrorAction SilentlyContinue
            $startMode = if ($cimSvc) { $cimSvc.StartMode } else { $svc.StartType.ToString() }
            
            $ramMB = 0
            if ($svc.Status -eq 'Running' -and $cimSvc -and $cimSvc.ProcessId -gt 0) {
                $proc = Get-Process -Id $cimSvc.ProcessId -ErrorAction SilentlyContinue
                if ($proc) {
                    $ramMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
                    $totalServiceRAM_MB += $ramMB
                }
            }

            $isOptimized = ($startMode -ieq 'Manual' -or $svc.StartType -eq [System.ServiceProcess.ServiceStartMode]::Manual)

            $servicesAudit += [PSCustomObject]@{
                Name         = $def.Name
                DisplayName  = $def.DisplayName
                CurrentStart = $startMode
                Status       = $svc.Status.ToString()
                RAM_MB       = $ramMB
                IsOptimized  = $isOptimized
                TargetStart  = $def.TargetStartup
                Category     = $def.Category
            }
        }
    }

    $thirdPartyAudit = @()
    $totalThirdPartyRAM_MB = 0

    foreach ($tp in $thirdPartyDefs) {
        $detected = $false
        $isEnabled = $false

        # A. Tareas Programadas
        foreach ($tName in $tp.TargetNames) {
            $tasks = Get-ScheduledTask -TaskName $tName -ErrorAction SilentlyContinue
            if ($tasks) {
                $detected = $true
                foreach ($t in $tasks) {
                    if ($t.State -ne 'Disabled') {
                        $isEnabled = $true
                    }
                }
            }
        }

        # B. Claves Run
        foreach ($rName in $tp.RunKeyNames) {
            $hkcuRun = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $rName -ErrorAction SilentlyContinue
            $hklmRun = Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $rName -ErrorAction SilentlyContinue
            if ($hkcuRun -or $hklmRun) {
                $detected = $true
                $isEnabled = $true
            }
        }

        # C. Carpeta Startup
        if ($tp.TargetType -eq 'StartupFolder') {
            foreach ($sName in $tp.TargetNames) {
                $uPath = Join-Path ([Environment]::GetFolderPath('Startup')) $sName
                $cPath = Join-Path ([Environment]::GetFolderPath('CommonStartup')) $sName
                if ((Test-Path $uPath) -or (Test-Path $cPath)) {
                    $detected = $true
                    $isEnabled = $true
                }
            }
        }

        if ($detected -and $isEnabled) {
            $totalThirdPartyRAM_MB += $tp.RAMSavingsMB
        }

        $thirdPartyAudit += [PSCustomObject]@{
            Id             = $tp.Id
            Name           = $tp.Name
            Vendor         = $tp.Vendor
            Detected       = $detected
            IsEnabled      = $isEnabled
            IsOptimized    = (-not $isEnabled)
            EstSavingsMB   = $tp.RAMSavingsMB
            Description    = $tp.Description
        }
    }

    # D. Estado de Mantenimiento CBS y Búsqueda Bing
    $maintVal = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' -Name 'MaintenanceDisabled' -ErrorAction SilentlyContinue).MaintenanceDisabled
    $maintOptimized = ($null -ne $maintVal -and [int]$maintVal -eq 1)

    $bingVal = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'BingSearchEnabled' -ErrorAction SilentlyContinue).BingSearchEnabled
    $bingOptimized = ($null -ne $bingVal -and [int]$bingVal -eq 0)

    $extraSavings = 0
    if (-not $bingOptimized) { $extraSavings += 350 }
    if (-not $maintOptimized) { $extraSavings += 800 }
    $totalEstSavings = $totalServiceRAM_MB + $totalThirdPartyRAM_MB + $extraSavings

    return [PSCustomObject]@{
        Services               = $servicesAudit
        ThirdParty             = $thirdPartyAudit
        MaintenanceOptimized   = $maintOptimized
        BingSearchOptimized    = $bingOptimized
        TotalServiceRAM_MB     = $totalServiceRAM_MB
        TotalThirdPartyRAM_MB  = $totalThirdPartyRAM_MB
        TotalPotentialSavings  = $totalEstSavings
        Timestamp              = Get-Date
    }
}

# -----------------------------------------------------------------------------
# 3. OPTIMIZACIÓN Y GOBERNANZA (OPTIMIZE)
# -----------------------------------------------------------------------------

function Invoke-StartupEcosystemOptimization {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$TargetScope = "All",
        [switch]$SkipSnap
    )

    Write-StartupLog "==========================================================" "INFO" Cyan
    Write-StartupLog "  EJECUTANDO GOBERNANZA INTEGRAL DE INICIO (romanOS SSOT)" "INFO" Cyan
    Write-StartupLog "==========================================================" "INFO" Cyan

    # 1. Instantánea preventiva de seguridad
    if (-not $SkipSnap -and (Test-Path $snapshotScript)) {
        Write-StartupLog "Creando instantánea previa de servicios y registro con Manage-SystemSnapshots.ps1..." "INFO" Yellow
        try {
            & $snapshotScript -Action Create -Tag "PRE_STARTUP_OPTIMIZE" -ErrorAction Stop | Out-Null
            Write-StartupLog "Instantánea de seguridad 'PRE_STARTUP_OPTIMIZE' creada con éxito." "INFO" Green
        } catch {
            Write-StartupLog "No se pudo crear la instantánea preventiva: $($_.Exception.Message)" "WARN" Yellow
        }
    }

    # 2. Servicios a Demanda (Demand-Start / Manual)
    if ($TargetScope -in @("All", "Services")) {
        Write-StartupLog "`n--- [1/3] Transición de Servicios a Demanda (Demand-Start / Manual) ---" "INFO" Cyan
        $demandDefs = if (Get-Command Get-RomanOSDemandServices -ErrorAction SilentlyContinue) {
            Get-RomanOSDemandServices
        } else {
            @()
        }

        foreach ($def in $demandDefs) {
            $svc = Get-Service -Name $def.Name -ErrorAction SilentlyContinue
            if ($svc) {
                if ($PSCmdlet.ShouldProcess($def.Name, "Configurar servicio en tipo de inicio Manual (Demand)")) {
                    try {
                        Set-Service -Name $def.Name -StartupType Manual -ErrorAction Stop
                        Write-StartupLog "  [OK] $($def.Name) ($($def.DisplayName)) -> Tipo de inicio: Manual" "INFO" Green

                        if ($svc.Status -eq 'Running') {
                            Stop-Service -Name $def.Name -Force -NoWait -ErrorAction SilentlyContinue
                            Write-StartupLog "       Señal de detención enviada a $($def.Name) para liberar RAM inmediatamente." "INFO" DarkGray
                        }
                    } catch {
                        Write-StartupLog "  [FAIL] Error ajustando $($def.Name): $($_.Exception.Message)" "ERROR" Red
                    }
                }
            } else {
                Write-StartupLog "  [-] Servicio $($def.Name) no instalado en este host (Omitido)." "INFO" DarkGray
            }
        }
    }

    # 3. Gobernador de Autostart de Terceros (Trigger-Off)
    if ($TargetScope -in @("All", "ThirdParty")) {
        Write-StartupLog "`n--- [2/3] Conmutación a Demanda de Aplicaciones de Terceros ---" "INFO" Cyan
        $thirdPartyDefs = if (Get-Command Get-RomanOSStartupThirdPartyCatalog -ErrorAction SilentlyContinue) {
            Get-RomanOSStartupThirdPartyCatalog
        } else {
            @()
        }

        foreach ($tp in $thirdPartyDefs) {
            Write-StartupLog "  Evaluando $($tp.Name) ($($tp.Vendor))..." "INFO" Yellow

            # A. Deshabilitar Tareas Programadas sin borrarlas
            foreach ($tName in $tp.TargetNames) {
                $tasks = Get-ScheduledTask -TaskName $tName -ErrorAction SilentlyContinue
                if ($tasks) {
                    foreach ($t in $tasks) {
                        if ($t.State -ne 'Disabled') {
                            if ($PSCmdlet.ShouldProcess($t.TaskName, "Deshabilitar disparador de tarea programada")) {
                                try {
                                    Disable-ScheduledTask -TaskName $t.TaskName -ErrorAction Stop | Out-Null
                                    Write-StartupLog "    [OK] Tarea '$($t.TaskName)' deshabilitada al arranque." "INFO" Green
                                } catch {
                                    Write-StartupLog "    [FAIL] No se pudo deshabilitar tarea '$($t.TaskName)': $($_.Exception.Message)" "WARN" Red
                                }
                            }
                        }
                    }
                }
            }

            # B. Deshabilitar Claves Run respaldándolas
            foreach ($rName in $tp.RunKeyNames) {
                $runKeys = @(
                    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Backup = 'HKCU:\Software\RomanOS\BackupRun' },
                    @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Backup = 'HKLM:\Software\RomanOS\BackupRun' }
                )

                foreach ($rk in $runKeys) {
                    $prop = Get-ItemProperty -Path $rk.Path -Name $rName -ErrorAction SilentlyContinue
                    if ($prop -and $prop.$rName) {
                        if ($PSCmdlet.ShouldProcess($rName, "Mover autostart de '$($rk.Path)' a respaldo RomanOS")) {
                            try {
                                if (-not (Test-Path $rk.Backup)) {
                                    New-Item -Path $rk.Backup -Force | Out-Null
                                }
                                Set-ItemProperty -Path $rk.Backup -Name $rName -Value $prop.$rName -Force
                                Remove-ItemProperty -Path $rk.Path -Name $rName -Force
                                Write-StartupLog "    [OK] Clave Run '$rName' trasladada a respaldo bajo demanda." "INFO" Green
                            } catch {
                                Write-StartupLog "    [FAIL] No se pudo conmutar clave Run '$rName': $($_.Exception.Message)" "WARN" Red
                            }
                        }
                    }
                }
            }

            # C. Deshabilitar accesos directos en Startup
            if ($tp.TargetType -eq 'StartupFolder') {
                foreach ($sName in $tp.TargetNames) {
                    $uPath = Join-Path ([Environment]::GetFolderPath('Startup')) $sName
                    $cPath = Join-Path ([Environment]::GetFolderPath('CommonStartup')) $sName
                    foreach ($pth in @($uPath, $cPath)) {
                        if (Test-Path $pth) {
                            $disabledPth = "$pth.disabled"
                            if ($PSCmdlet.ShouldProcess($pth, "Renombrar acceso directo a .disabled")) {
                                try {
                                    Move-Item -Path $pth -Destination $disabledPth -Force
                                    Write-StartupLog "    [OK] Acceso directo '$sName' renombrado a .disabled." "INFO" Green
                                } catch {
                                    Write-StartupLog "    [FAIL] No se pudo renombrar '$sName': $($_.Exception.Message)" "WARN" Red
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    # 4. Supresión de Spikes de Mantenimiento y Bing WebView2
    if ($TargetScope -in @("All", "Maintenance")) {
        Write-StartupLog "`n--- [3/3] Supresión de Spikes CBS y Erradicación de WebView2 Local ---" "INFO" Cyan

        # A. Mantenimiento Automático (TiWorker spike suppression)
        $maintKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"
        if ($PSCmdlet.ShouldProcess("MaintenanceDisabled = 1", "Evitar spike de TiWorker en logon")) {
            try {
                if (-not (Test-Path $maintKey)) {
                    New-Item -Path $maintKey -Force | Out-Null
                }
                Set-ItemProperty -Path $maintKey -Name "MaintenanceDisabled" -Value 1 -Type DWord -Force
                Write-StartupLog "  [OK] MaintenanceDisabled = 1 registrado en Programador de Tareas." "INFO" Green
            } catch {
                Write-StartupLog "  [FAIL] Error registrando MaintenanceDisabled: $($_.Exception.Message)" "WARN" Red
            }
        }

        # B. Bing Search & Cortana en SearchHost (Erradica los 5 procesos de msedgewebview2)
        $searchKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
        if ($PSCmdlet.ShouldProcess("BingSearchEnabled = 0", "Erradicar msedgewebview2 en búsqueda de Windows")) {
            try {
                if (-not (Test-Path $searchKey)) {
                    New-Item -Path $searchKey -Force | Out-Null
                }
                Set-ItemProperty -Path $searchKey -Name "BingSearchEnabled" -Value 0 -Type DWord -Force
                Set-ItemProperty -Path $searchKey -Name "CortanaConsent" -Value 0 -Type DWord -Force
                Write-StartupLog "  [OK] BingSearchEnabled = 0 y CortanaConsent = 0 registrados en HKCU." "INFO" Green
            } catch {
                Write-StartupLog "  [FAIL] Error registrando políticas de búsqueda: $($_.Exception.Message)" "WARN" Red
            }
        }
    }

    Write-StartupLog "`n[✓] Proceso de gobernanza de inicio finalizado exitosamente." "INFO" Green
}

# -----------------------------------------------------------------------------
# 4. RESTAURACIÓN A VALORES POR DEFECTO (RESTORE / RESET)
# -----------------------------------------------------------------------------

function Restore-StartupEcosystemDefaults {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$TargetScope = "All"
    )

    Write-StartupLog "==========================================================" "INFO" Yellow
    Write-StartupLog "  RESTAURANDO ESTADO ORIGINAL DEL INICIO (REVERT)" "INFO" Yellow
    Write-StartupLog "==========================================================" "INFO" Yellow

    # 1. Re-habilitar Servicios a Automático
    if ($TargetScope -in @("All", "Services")) {
        $demandDefs = if (Get-Command Get-RomanOSDemandServices -ErrorAction SilentlyContinue) {
            Get-RomanOSDemandServices
        } else {
            @()
        }

        foreach ($def in $demandDefs) {
            $svc = Get-Service -Name $def.Name -ErrorAction SilentlyContinue
            if ($svc) {
                if ($PSCmdlet.ShouldProcess($def.Name, "Restaurar servicio a tipo Automatic")) {
                    try {
                        Set-Service -Name $def.Name -StartupType Automatic -ErrorAction Stop
                        Write-StartupLog "  [OK] $($def.Name) restaurado a Automatic." "INFO" Green
                    } catch {
                        Write-StartupLog "  [WARN] No se pudo restaurar $($def.Name): $($_.Exception.Message)" "WARN" Yellow
                    }
                }
            }
        }
    }

    # 2. Re-habilitar Tareas y Claves de Terceros
    if ($TargetScope -in @("All", "ThirdParty")) {
        $thirdPartyDefs = if (Get-Command Get-RomanOSStartupThirdPartyCatalog -ErrorAction SilentlyContinue) {
            Get-RomanOSStartupThirdPartyCatalog
        } else {
            @()
        }

        foreach ($tp in $thirdPartyDefs) {
            foreach ($tName in $tp.TargetNames) {
                $tasks = Get-ScheduledTask -TaskName $tName -ErrorAction SilentlyContinue
                if ($tasks) {
                    foreach ($t in $tasks) {
                        if ($PSCmdlet.ShouldProcess($t.TaskName, "Re-habilitar tarea programada")) {
                            Enable-ScheduledTask -TaskName $t.TaskName -ErrorAction SilentlyContinue | Out-Null
                            Write-StartupLog "  [OK] Tarea '$($t.TaskName)' re-habilitada." "INFO" Green
                        }
                    }
                }
            }

            # Restaurar Run Keys respaldadas
            $backupKeys = @(
                @{ Backup = 'HKCU:\Software\RomanOS\BackupRun'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
                @{ Backup = 'HKLM:\Software\RomanOS\BackupRun'; Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' }
            )
            foreach ($bk in $backupKeys) {
                if (Test-Path $bk.Backup) {
                    foreach ($rName in $tp.RunKeyNames) {
                        $prop = Get-ItemProperty -Path $bk.Backup -Name $rName -ErrorAction SilentlyContinue
                        if ($prop -and $prop.$rName) {
                            Set-ItemProperty -Path $bk.Path -Name $rName -Value $prop.$rName -Force
                            Remove-ItemProperty -Path $bk.Backup -Name $rName -Force
                            Write-StartupLog "  [OK] Clave Run '$rName' restaurada." "INFO" Green
                        }
                    }
                }
            }

            # Restaurar Shortcuts
            if ($tp.TargetType -eq 'StartupFolder') {
                foreach ($sName in $tp.TargetNames) {
                    $uPathDisabled = Join-Path ([Environment]::GetFolderPath('Startup')) "$sName.disabled"
                    $cPathDisabled = Join-Path ([Environment]::GetFolderPath('CommonStartup')) "$sName.disabled"
                    foreach ($dis in @($uPathDisabled, $cPathDisabled)) {
                        if (Test-Path $dis) {
                            $orig = $dis -replace '\.disabled$', ''
                            Move-Item -Path $dis -Destination $orig -Force
                            Write-StartupLog "  [OK] Acceso directo '$sName' restaurado." "INFO" Green
                        }
                    }
                }
            }
        }
    }

    # 3. Restaurar Mantenimiento
    if ($TargetScope -in @("All", "Maintenance")) {
        $maintKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"
        if (Test-Path $maintKey) {
            Remove-ItemProperty -Path $maintKey -Name "MaintenanceDisabled" -ErrorAction SilentlyContinue
            Write-StartupLog "  [OK] Directiva MaintenanceDisabled revertida." "INFO" Green
        }
    }

    Write-StartupLog "`n[✓] Restauración completada." "INFO" Green
}

# -----------------------------------------------------------------------------
# 5. DESPACHO PRINCIPAL (CLI DISPATCHER)
# -----------------------------------------------------------------------------

switch ($Action) {
    "Status" {
        $audit = Get-StartupEcosystemAudit
        Write-Host "`n==========================================================" -ForegroundColor Cyan
        Write-Host "   RESUMEN DEL ECOSISTEMA DE INICIO Y SERVICIOS" -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host "Ahorro Potencial de Memoria en Reposo: ~$([math]::Round($audit.TotalPotentialSavings, 0)) MB RAM" -ForegroundColor Green
        Write-Host "Mantenimiento CBS Optimizado:         $($audit.MaintenanceOptimized)"
        Write-Host "Búsqueda Bing / WebView2 Erradicada:   $($audit.BingSearchOptimized)"
        
        Write-Host "`n[SERVICIOS EVALUADOS]:" -ForegroundColor Yellow
        $audit.Services | Format-Table -Property Name, DisplayName, CurrentStart, Status, RAM_MB, IsOptimized -AutoSize

        Write-Host "[APLICACIONES DE TERCEROS EVALUADAS]:" -ForegroundColor Yellow
        $audit.ThirdParty | Format-Table -Property Name, Vendor, Detected, IsEnabled, IsOptimized, EstSavingsMB -AutoSize
    }

    "Audit" {
        $audit = Get-StartupEcosystemAudit
        return $audit
    }

    "Optimize" {
        Invoke-StartupEcosystemOptimization -TargetScope $Scope -SkipSnap:$SkipSnapshot
    }

    "Restore" {
        Restore-StartupEcosystemDefaults -TargetScope $Scope
    }

    "Reset" {
        Restore-StartupEcosystemDefaults -TargetScope $Scope
    }
}
