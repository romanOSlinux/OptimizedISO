<#
.SYNOPSIS
    Watchdog-ServiceDrift.ps1 - Guardián Anti-Desvío de Servicios y Tareas de romanOS
    Auditoría en Tiempo Real y Remediación Atómica de Configuration Drift Post-Windows Update

.DESCRIPTION
    Detecta la reactivación involuntaria de servicios de telemetría, tareas invasivas
    de diagnóstico y telemetría de Windows tras actualizaciones acumulativas (LCUs),
    calcula el índice de paridad/salud del sistema y aplica remediación atómica en caliente.

.PARAMETER Action
    Acción a ejecutar:
      - Status: Resumen rápido de paridad y porcentaje de salud en pantalla.
      - Audit: Auditoría forense exhaustiva con exportación de reporte JSON/MD.
      - Remediate: Deshabilita y detiene en caliente servicios y tareas desviadas.
      - RegisterTask: Registra la tarea programada periódica del Watchdog.
      - UnregisterTask: Elimina la tarea programada periódica.

.PARAMETER Target
    Alcance de la auditoría: All (predeterminado), Services, ScheduledTasks.

.PARAMETER LogDir
    Directorio de salida para logs y reportes forenses.

.PARAMETER Unattended
    Omite pausas interactivas en consola.

.PARAMETER SkipElevation
    Omite la elevación de privilegios cuando no se modifican componentes del sistema.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("Status", "Audit", "Remediate", "RegisterTask", "InstallTask", "UnregisterTask")]
    [string]$Action = "Status",

    [ValidateSet("All", "Services", "ScheduledTasks")]
    [string]$Target = "All",

    [string]$LogDir = "",
    [switch]$Unattended,
    [switch]$SkipElevation,
    [switch]$Quiet,
    [switch]$PassThru
)

$ErrorActionPreference = 'Continue'

# -----------------------------------------------------------------------------
# 1. CARGA DE MOTORES CENTRALES (SSOT: UI-Engine y Policy-Engine)
# -----------------------------------------------------------------------------
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$repoRootCandidates = @(
    (Split-Path (Split-Path $scriptDir -Parent) -Parent),
    (Split-Path $scriptDir -Parent)
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

# -----------------------------------------------------------------------------
# 2. DEFINICION CANONICA DE ELEMENTOS A MONITOREAR (CATALOGO SSOT)
# -----------------------------------------------------------------------------
$script:MonitoredServices = @(
    [PSCustomObject]@{ Name = "DiagTrack";          ExpectedStart = "Disabled"; Impact = "High";   Description = "Telemetría principal de Microsoft (Connected User Experiences)" },
    [PSCustomObject]@{ Name = "dmwappushservice";   ExpectedStart = "Disabled"; Impact = "High";   Description = "Enrutamiento de mensajes WAP y telemetría secundaria" },
    [PSCustomObject]@{ Name = "WerSvc";             ExpectedStart = "Disabled"; Impact = "Medium"; Description = "Informe de errores de Windows (evita congelamientos tras crash)" },
    [PSCustomObject]@{ Name = "RetailDemo";         ExpectedStart = "Disabled"; Impact = "Medium"; Description = "Servicio de demostración en tienda minorista" },
    [PSCustomObject]@{ Name = "MapsBroker";         ExpectedStart = "Disabled"; Impact = "Medium"; Description = "Gestor de mapas descargados sin conexión" },
    [PSCustomObject]@{ Name = "lfsvc";              ExpectedStart = "Disabled"; Impact = "Low";    Description = "Servicio de geolocalización constante" },
    [PSCustomObject]@{ Name = "TroubleshootingSvc"; ExpectedStart = "Disabled"; Impact = "Medium"; Description = "Diagnósticos no solicitados en segundo plano" },
    [PSCustomObject]@{ Name = "RemoteRegistry";     ExpectedStart = "Disabled"; Impact = "Medium"; Description = "Modificación remota corporativa del registro" }
)

$script:MonitoredTasks = @(
    [PSCustomObject]@{ Path = "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"; Impact = "High";   Description = "Evaluador de telemetría de aplicaciones (alta I/O en reposo)" },
    [PSCustomObject]@{ Path = "\Microsoft\Windows\Application Experience\ProgramDataUpdater";               Impact = "High";   Description = "Actualizador de telemetría de programas" },
    [PSCustomObject]@{ Path = "\Microsoft\Windows\Application Experience\StartupAppTask";                   Impact = "Medium"; Description = "Escaneo de aplicaciones al arranque" },
    [PSCustomObject]@{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator";    Impact = "High";   Description = "Consolidador del programa de experiencia de usuario" },
    [PSCustomObject]@{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip";         Impact = "Medium"; Description = "Telemetría de periféricos USB" },
    [PSCustomObject]@{ Path = "\Microsoft\Windows\Feedback\Siuf\DmClient";                                  Impact = "Medium"; Description = "Cliente de sondeo de comentarios" },
    [PSCustomObject]@{ Path = "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload";               Impact = "Medium"; Description = "Descarga de escenarios de telemetría SIUF" },
    [PSCustomObject]@{ Path = "\Microsoft\Windows\Windows Error Reporting\QueueReporting";                 Impact = "Medium"; Description = "Cola de envío de informes de errores" }
)

# -----------------------------------------------------------------------------
# 3. FUNCIONES DE EVALUACION Y REMEDIACION
# -----------------------------------------------------------------------------
function Get-RomanOSServiceDriftReport {
    [CmdletBinding()]
    param(
        [string]$Scope = "All"
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ($Scope -eq "All" -or $Scope -eq "Services") {
        foreach ($s in $script:MonitoredServices) {
            $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
            if ($null -eq $svc) {
                # Servicio no instalado en esta versión o eliminado limpiamente
                $results.Add([PSCustomObject]@{
                    Category      = "Service"
                    Name          = $s.Name
                    Description   = $s.Description
                    Impact        = $s.Impact
                    CurrentState  = "NotInstalled"
                    ExpectedState = $s.ExpectedStart
                    HasDrift      = $false
                    StatusNote    = "No instalado / Purged"
                })
            } else {
                $isDrifted = ($svc.StartType -ne 'Disabled')
                $results.Add([PSCustomObject]@{
                    Category      = "Service"
                    Name          = $s.Name
                    Description   = $s.Description
                    Impact        = $s.Impact
                    CurrentState  = "$($svc.StartType) ($($svc.Status))"
                    ExpectedState = $s.ExpectedStart
                    HasDrift      = $isDrifted
                    StatusNote    = if ($isDrifted) { "Desviado (Reactivado por Windows)" } else { "Cumple estándar romanOS" }
                })
            }
        }
    }

    if ($Scope -eq "All" -or $Scope -eq "ScheduledTasks") {
        foreach ($t in $script:MonitoredTasks) {
            $tName = Split-Path $t.Path -Leaf
            $tPath = (Split-Path $t.Path -Parent) + '\'
            
            $taskObj = $null
            try {
                $taskObj = Get-ScheduledTask -TaskName $tName -TaskPath $tPath -ErrorAction SilentlyContinue
            } catch {
                Write-Debug "Tarea programada $tPath$tName no encontrada o sin permisos: $($_.Exception.Message)"
            }

            if ($null -eq $taskObj) {
                $results.Add([PSCustomObject]@{
                    Category      = "ScheduledTask"
                    Name          = $tName
                    Description   = $t.Description
                    Impact        = $t.Impact
                    CurrentState  = "NotFound"
                    ExpectedState = "Disabled"
                    HasDrift      = $false
                    StatusNote    = "No existe / Eliminada"
                })
            } else {
                $isDrifted = ($taskObj.State -ne 'Disabled')
                $results.Add([PSCustomObject]@{
                    Category      = "ScheduledTask"
                    Name          = $tName
                    Description   = $t.Description
                    Impact        = $t.Impact
                    CurrentState  = [string]$taskObj.State
                    ExpectedState = "Disabled"
                    HasDrift      = $isDrifted
                    StatusNote    = if ($isDrifted) { "Desviada (Reactivada por Windows)" } else { "Cumple estándar romanOS" }
                })
            }
        }
    }

    $totalEvaluated = $results.Count
    $driftedCount   = @($results | Where-Object { $_.HasDrift }).Count
    $compliantCount = $totalEvaluated - $driftedCount
    $parityPercent  = if ($totalEvaluated -gt 0) { [math]::Round(($compliantCount / $totalEvaluated) * 100, 1) } else { 100 }

    return [PSCustomObject]@{
        TotalEvaluated = $totalEvaluated
        CompliantCount = $compliantCount
        DriftedCount   = $driftedCount
        ParityPercent  = $parityPercent
        Items          = $results
    }
}

function Invoke-RomanOSServiceDriftRemediation {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [PSCustomObject]$DriftReport
    )

    $remediatedServices = 0
    $remediatedTasks    = 0
    $remediationErrors  = 0

    $driftedItems = $DriftReport.Items | Where-Object { $_.HasDrift }
    if ($driftedItems.Count -eq 0) {
        Write-OK "No se detectaron desvíos. El sistema ya cuenta con 100% de paridad con romanOS."
        return [PSCustomObject]@{ RemediatedServices = 0; RemediatedTasks = 0; Errors = 0 }
    }

    foreach ($item in $driftedItems) {
        if ($item.Category -eq "Service") {
            if ($PSCmdlet.ShouldProcess("Servicio: $($item.Name)", "Detener y Deshabilitar")) {
                try {
                    $svc = Get-Service -Name $item.Name -ErrorAction SilentlyContinue
                    if ($svc -and $svc.Status -eq 'Running') {
                        Stop-Service -Name $item.Name -Force -ErrorAction Stop
                    }
                    Set-Service -Name $item.Name -StartupType Disabled -ErrorAction Stop
                    Write-OK "Servicio remediado: $($item.Name) -> Disabled / Stopped"
                    $remediatedServices++
                } catch {
                    Write-Warn "Fallo al remediar vía Set-Service '$($item.Name)': $($_.Exception.Message). Intentando sc.exe..."
                    try {
                        & sc.exe stop $item.Name 2>&1 | Out-Null
                        & sc.exe config $item.Name start= disabled 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-OK "Servicio remediado vía sc.exe: $($item.Name)"
                            $remediatedServices++
                        } else {
                            Write-ErrorMsg "No se pudo deshabilitar $($item.Name) (ExitCode: $LASTEXITCODE)"
                            $remediationErrors++
                        }
                    } catch {
                        Write-ErrorMsg "Error crítico en sc.exe para $($item.Name): $($_.Exception.Message)"
                        $remediationErrors++
                    }
                }
            }
        } elseif ($item.Category -eq "ScheduledTask") {
            if ($PSCmdlet.ShouldProcess("Tarea Programada: $($item.Name)", "Deshabilitar")) {
                try {
                    $matchTask = $script:MonitoredTasks | Where-Object { (Split-Path $_.Path -Leaf) -eq $item.Name } | Select-Object -First 1
                    if ($matchTask) {
                        $tPath = (Split-Path $matchTask.Path -Parent) + '\'
                        Disable-ScheduledTask -TaskName $item.Name -TaskPath $tPath -ErrorAction Stop | Out-Null
                        Write-OK "Tarea remediada: $($item.Name) -> Disabled"
                        $remediatedTasks++
                    }
                } catch {
                    Write-Warn "Fallo al deshabilitar tarea '$($item.Name)': $($_.Exception.Message)"
                    $remediationErrors++
                }
            }
        }
    }

    return [PSCustomObject]@{
        RemediatedServices = $remediatedServices
        RemediatedTasks    = $remediatedTasks
        Errors             = $remediationErrors
    }
}

# -----------------------------------------------------------------------------
# 4. EJECUCION DE ACCIONES PRINCIPALES
# -----------------------------------------------------------------------------
$startTime = Get-Date

switch ($Action) {
    "Status" {
        Show-UnifiedBanner -Title "romanOS ANTI-DRIFT GUARDIAN" -Subtitle "Diagnóstico en Caliente de Paridad de Servicios y Tareas" -ShowSystemInfo

        Write-StepHeader -StepNumber 1 -TotalSteps 2 -Message "Evaluando Servicios y Tareas Críticas..."
        $rep = Get-RomanOSServiceDriftReport -Scope $Target

        Write-StepHeader -StepNumber 2 -TotalSteps 2 -Message "Resultado de Paridad y Salud Anti-Drift"
        Write-SubStep "Total Elementos Evaluados : $($rep.TotalEvaluated)"
        Write-SubStep "Elementos Cumpliendo SSOT : $($rep.CompliantCount)"
        Write-SubStep "Elementos con Desvío      : $($rep.DriftedCount)"

        $color = if ($rep.ParityPercent -ge 90) { "Green" } elseif ($rep.ParityPercent -ge 70) { "Yellow" } else { "Red" }
        Write-Host "`n  Índice de Paridad romanOS : $($rep.ParityPercent)%`n" -ForegroundColor $color

        if ($rep.DriftedCount -gt 0) {
            Write-Warn "Se detectaron $($rep.DriftedCount) desvíos de configuración causados por Windows Update o apps de terceros."
            Write-Info "Usa: Watchdog-ServiceDrift.ps1 -Action Remediate para restaurar el sistema en 1-clic."
        } else {
            Write-OK "El sistema se encuentra en 100% de paridad con la optimización canónica de romanOS."
        }

        $dur = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
        Show-UnifiedSummary -Title "DIAGNÓSTICO ANTI-DRIFT" -Status $(if ($rep.DriftedCount -eq 0) { "SUCCESS" } else { "ATTENTION_REQUIRED" }) -DurationSeconds $dur -ErrorsCount 0 -WarnsCount $(if ($rep.DriftedCount -gt 0) { 1 } else { 0 }) -Logs @{}
        if ($PassThru) { return $rep }
    }

    "Audit" {
        Show-UnifiedBanner -Title "romanOS ANTI-DRIFT GUARDIAN" -Subtitle "Auditoría Forense y Generación de Reporte" -ShowSystemInfo

        Write-StepHeader -StepNumber 1 -TotalSteps 2 -Message "Ejecutando Auditoría Exhaustiva..."
        $rep = Get-RomanOSServiceDriftReport -Scope $Target

        Write-StepHeader -StepNumber 2 -TotalSteps 2 -Message "Exportando Reporte Forense..."
        if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
        $reportPath = Join-Path $LogDir ("Watchdog_ServiceDrift_Report_{0}.md" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("# Informe Forense romanOS Anti-Drift Guardian")
        [void]$sb.AppendLine("- **Fecha:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        [void]$sb.AppendLine("- **Paridad Global:** $($rep.ParityPercent)%")
        [void]$sb.AppendLine("- **Elementos Auditados:** $($rep.TotalEvaluated) | **Desvíos Detectados:** $($rep.DriftedCount)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Matriz Detallada de Auditoría")
        [void]$sb.AppendLine("| Categoría | Elemento | Estado Actual | Estado Esperado | Desvío | Nota |")
        [void]$sb.AppendLine("|---|---|---|---|---|---|")
        foreach ($it in $rep.Items) {
            $badge = if ($it.HasDrift) { "SI ⚠️" } else { "NO ✅" }
            [void]$sb.AppendLine("| $($it.Category) | $($it.Name) | $($it.CurrentState) | $($it.ExpectedState) | $badge | $($it.StatusNote) |")
        }

        [System.IO.File]::WriteAllText($reportPath, $sb.ToString(), [System.Text.Encoding]::UTF8)
        Write-OK "Reporte exportado exitosamente en: '$reportPath'"

        $dur = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
        Show-UnifiedSummary -Title "AUDITORÍA FORENSE ANTI-DRIFT" -Status "SUCCESS" -DurationSeconds $dur -ErrorsCount 0 -WarnsCount $(if ($rep.DriftedCount -gt 0) { 1 } else { 0 }) -Logs @{ "Reporte" = $reportPath }
        if ($PassThru) { return $rep }
    }

    "Remediate" {
        Show-UnifiedBanner -Title "romanOS ANTI-DRIFT GUARDIAN" -Subtitle "Remediación Atómica de Desvíos" -ShowSystemInfo

        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin -and -not $WhatIfPreference -and -not $PSBoundParameters.ContainsKey('WhatIf')) {
            Write-ErrorMsg "La remediación de servicios del sistema requiere elevación administrativa."
            Write-Info "Ejecuta PowerShell como Administrador o usa: Watchdog-ServiceDrift.cmd"
            return
        }

        Write-StepHeader -StepNumber 1 -TotalSteps 2 -Message "Escaneando Desvíos Actuales..."
        $rep = Get-RomanOSServiceDriftReport -Scope $Target

        Write-StepHeader -StepNumber 2 -TotalSteps 2 -Message "Aplicando Remediación Atómica..."
        $remRes = Invoke-RomanOSServiceDriftRemediation -DriftReport $rep

        Write-OK "Servicios Remediados : $($remRes.RemediatedServices)"
        Write-OK "Tareas Remediadas    : $($remRes.RemediatedTasks)"
        if ($remRes.Errors -gt 0) {
            Write-Warn "Incidencias de remediación : $($remRes.Errors)"
        }

        $dur = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
        Show-UnifiedSummary -Title "REMEDIACIÓN ANTI-DRIFT" -Status $(if ($remRes.Errors -eq 0) { "SUCCESS" } else { "WARNING" }) -DurationSeconds $dur -ErrorsCount $remRes.Errors -WarnsCount 0 -Logs @{}
    }

    { $_ -in @("RegisterTask", "InstallTask") } {
        Show-UnifiedBanner -Title "romanOS ANTI-DRIFT GUARDIAN" -Subtitle "Registro de Tarea Programada Periodica" -ShowSystemInfo

        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin -and -not $WhatIfPreference) {
            Write-ErrorMsg "Registrar tareas programadas requiere privilegios de Administrador."
            return
        }

        $taskName = "romanOS-AntiDriftWatchdog"
        $scriptPath = (Resolve-Path (Join-Path $scriptDir "Watchdog-ServiceDrift.ps1")).Path

        if ($PSCmdlet.ShouldProcess("Tarea Programada: $taskName", "Register-ScheduledTask")) {
            try {
                $actionCmd = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-STA -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Action Remediate -Unattended"
                $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 10am
                $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
                $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

                Register-ScheduledTask -TaskName $taskName -Action $actionCmd -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
                Write-OK "Tarea programada '$taskName' registrada semanalmente (Lunes 10:00 AM) bajo cuenta SYSTEM."
            } catch {
                Write-ErrorMsg "Fallo al registrar tarea programada: $($_.Exception.Message)"
            }
        } else {
            Write-Info "[WhatIf] Se simuló el registro de la tarea programada '$taskName'."
        }
    }

    "UnregisterTask" {
        Show-UnifiedBanner -Title "romanOS ANTI-DRIFT GUARDIAN" -Subtitle "Desinstalación de Tarea Programada" -ShowSystemInfo

        $taskName = "romanOS-AntiDriftWatchdog"
        if ($PSCmdlet.ShouldProcess("Tarea Programada: $taskName", "Unregister-ScheduledTask")) {
            try {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop | Out-Null
                Write-OK "Tarea programada '$taskName' eliminada exitosamente."
            } catch {
                Write-Warn "No se encontró la tarea programada '$taskName' o ya fue removida."
            }
        } else {
            Write-Info "[WhatIf] Se simuló la eliminación de la tarea programada '$taskName'."
        }
    }
}
