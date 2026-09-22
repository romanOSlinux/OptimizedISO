<#
.SYNOPSIS
    Invoke-TestSuite.ps1 - Orquestador Maestro y Batería Integral de Pruebas romanOS
    Ejecutor de Validación y Certificación para Windows PowerShell 5.1

.DESCRIPTION
    Ejecuta de forma secuencial y estructurada todas las suites de pruebas del proyecto:
      1. Auditoría AST y Codificación UTF-8 con BOM en todos los scripts
      2. Validación de Esquemas XML y Particionado UEFI GPT (autounattend.xml)
      3. Diagnóstico de Herramientas de Compilación (Windows ADK, DISM, Hyper-V)
      4. Auditoría de Higiene y Trazabilidad Git (Cero Binarios Pesados)
      5. Test Harness Integral del Generador de ISOs (140+ Aserciones Unitarias)
    Genera un reporte consolidado Markdown en Log/TestSuite_Consolidated.md.

.PARAMETER Quick
    Ejecuta únicamente las fases rápidas (AST/BOM, XML, Entorno e Higiene Git) en menos de 5 segundos.

.PARAMETER LogDir
    Directorio donde se almacenará el reporte consolidado. (Default: C:\OptimizedISO\Log)

.EXAMPLE
    .\Invoke-TestSuite.ps1

.EXAMPLE
    .\Invoke-TestSuite.ps1 -Quick
#>

[CmdletBinding()]
param(
    [switch]$Quick,
    [string]$LogDir
)

$ErrorActionPreference = 'Continue'
$testSuiteStart = Get-Date

# -----------------------------------------------------------------------------
# CARGA DE MOTOR VISUAL UNIFICADO
# -----------------------------------------------------------------------------
$uiEnginePaths = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\UI-Engine.ps1"),
    (Join-Path $PSScriptRoot "Core\UI-Engine.ps1"),
    (Join-Path $PSScriptRoot "UI-Engine.ps1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\UI-Engine.ps1"),
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

Show-UnifiedBanner -Title "ORQUESTADOR MAESTRO DE PRUEBAS" -Subtitle "romanOS / OptimizedISO" -ShowSystemInfo

$suiteResults = [System.Collections.Generic.List[PSCustomObject]]::new()
$totalSteps = if ($Quick) { 11 } else { 12 }
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $repoRoot ".agents"))) {
    $repoCandidate = Split-Path $PSScriptRoot -Parent
    if (Test-Path (Join-Path $repoCandidate ".agents")) {
        $repoRoot = $repoCandidate
    } else {
        $repoRoot = (Join-Path $env:SystemDrive "OptimizedISO")
    }
}
if (-not $LogDir) {
    $LogDir = Join-Path $repoRoot "Log"
}

# -----------------------------------------------------------------------------
# FASE 1: VALIDACION SINTACTICA AST Y UTF-8 BOM
# -----------------------------------------------------------------------------
Write-StepHeader -StepNumber 1 -TotalSteps $totalSteps -Message "Auditoría Sintáctica AST y Codificación UTF-8 BOM"
$astScript = Join-Path $repoRoot ".agents\skills\powershell-windows\scripts\Test-ScriptAstAndBom.ps1"
$phase1Pass = $false
if (Test-Path $astScript) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $astScript -Path $repoRoot
    if ($LASTEXITCODE -eq 0) {
        $phase1Pass = $true
        Write-OK "Fase 1 Aprobada: Todos los scripts tienen BOM y 0 errores AST."
    } else {
        Write-ErrorMsg "Fase 1 Fallida: Se detectaron scripts con fallos de sintaxis o codificación."
    }
} else {
    Write-Warn "Script helper AST/BOM no encontrado en '$astScript'."
}
$suiteResults.Add([PSCustomObject]@{ Phase = 1; Name = "Auditoría AST y Codificación UTF-8 BOM"; Status = if ($phase1Pass) { "PASS" } else { "FAIL" } })

# -----------------------------------------------------------------------------
# FASE 2: MOTOR DE HARDWARE E INTROSPECCION (PCI-SIG, SMBIOS, MSI, HAGS)
# -----------------------------------------------------------------------------
Write-StepHeader -StepNumber 2 -TotalSteps $totalSteps -Message "Auditoría del Motor de Hardware y Clasificación Oficial"
$hwScript = Join-Path $repoRoot "scripts\Testing\Test-HardwareEngine.ps1"
$phase2Pass = $false
if (Test-Path $hwScript) {
    & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $hwScript
    if ($LASTEXITCODE -eq 0) {
        $phase2Pass = $true
        Write-OK "Fase 2 Aprobada: Motor de hardware y clasificación PCI-SIG / SMBIOS al 100%."
    } else {
        Write-ErrorMsg "Fase 2 Fallida: Se detectaron aserciones erróneas en el motor de hardware."
    }
} else {
    Write-Warn "Script de pruebas de hardware no encontrado en '$hwScript'."
}
$suiteResults.Add([PSCustomObject]@{ Phase = 2; Name = "Motor de Hardware y Clasificación PCI-SIG"; Status = if ($phase2Pass) { "PASS" } else { "FAIL" } })

# -----------------------------------------------------------------------------
# FASE 3: VALIDACION DE ESQUEMA XML AUTOUNATTEND
# -----------------------------------------------------------------------------
Write-StepHeader -StepNumber 3 -TotalSteps $totalSteps -Message "Validación de Esquema XML y Particionado UEFI GPT"
$xmlScript = Join-Path $repoRoot ".agents\skills\unattended-deployment\scripts\Test-UnattendXml.ps1"
$phase3Pass = $false
if (Test-Path $xmlScript) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $xmlScript
    if ($LASTEXITCODE -eq 0) {
        $phase3Pass = $true
        Write-OK "Fase 3 Aprobada: autounattend.xml cumple con el esquema oficial UEFI GPT."
    } else {
        Write-ErrorMsg "Fase 3 Fallida: Esquema XML inválido o con advertencias."
    }
} else {
    Write-Warn "Script helper XML no encontrado en '$xmlScript'."
}
$suiteResults.Add([PSCustomObject]@{ Phase = 3; Name = "Validación de Esquema autounattend.xml"; Status = if ($phase3Pass) { "PASS" } else { "FAIL" } })

# -----------------------------------------------------------------------------
# FASE 4: DIAGNOSTICO DE HERRAMIENTAS ADK Y ENTORNO
# -----------------------------------------------------------------------------
Write-StepHeader -StepNumber 4 -TotalSteps $totalSteps -Message "Diagnóstico de Herramientas ADK, DISM e Hyper-V"
$adkScript = Join-Path $repoRoot ".agents\skills\windows-adk-hyperv\scripts\Test-AdkEnvironment.ps1"
$phase4Pass = $false
if (Test-Path $adkScript) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $adkScript
    if ($LASTEXITCODE -eq 0) {
        $phase4Pass = $true
        Write-OK "Fase 4 Aprobada: Herramientas de compilación y entorno listas."
    } else {
        Write-ErrorMsg "Fase 4 Fallida: Faltan herramientas requeridas en el host."
    }
} else {
    Write-Warn "Script helper ADK no encontrado en '$adkScript'."
}
$suiteResults.Add([PSCustomObject]@{ Phase = 4; Name = "Diagnóstico de Entorno ADK y DISM"; Status = if ($phase4Pass) { "PASS" } else { "FAIL" } })

# -----------------------------------------------------------------------------
# FASE 5: HIGIENE Y CONTROL DE VERSIONES GIT
# -----------------------------------------------------------------------------
Write-StepHeader -StepNumber 5 -TotalSteps $totalSteps -Message "Auditoría de Higiene y Trazabilidad Git"
$gitScript = Join-Path $repoRoot ".agents\skills\git-workflow\scripts\Test-GitWorkspaceHygiene.ps1"
$phase5Pass = $false
if (Test-Path $gitScript) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $gitScript
    if ($LASTEXITCODE -eq 0) {
        $phase5Pass = $true
        Write-OK "Fase 5 Aprobada: Cero binarios pesados rastreados y árbol limpio."
    } else {
        Write-ErrorMsg "Fase 5 Fallida: Se detectaron binarios no permitidos en el historial."
    }
} else {
    Write-Warn "Script helper Git no encontrado en '$gitScript'."
}
$suiteResults.Add([PSCustomObject]@{ Phase = 5; Name = "Auditoría de Higiene Git"; Status = if ($phase5Pass) { "PASS" } else { "FAIL" } })

# -----------------------------------------------------------------------------
# FASE 6: CIBERSEGURIDAD, ANTI-CHEATS Y CADENA DE SUMINISTRO (PLAN-0096)
# -----------------------------------------------------------------------------
Write-StepHeader -StepNumber 6 -TotalSteps $totalSteps -Message "Auditoría de Ciberseguridad, Anti-Cheats y Cadena de Suministro"
$secScript = Join-Path $repoRoot "scripts\Testing\Test-SecurityAndAntiCheat.ps1"
$phase6Pass = $false
if (Test-Path $secScript) {
    & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $secScript
    if ($LASTEXITCODE -eq 0) {
        $phase6Pass = $true
        Write-OK "Fase 6 Aprobada: 100% Compatibilidad con Anti-Cheats y Cadena de Suministro Íntegra."
    } else {
        Write-ErrorMsg "Fase 6 Fallida: Se detectaron fallas de seguridad o incompatibilidades."
    }
} else {
    Write-Warn "Script de pruebas de seguridad no encontrado en '$secScript'."
}
$suiteResults.Add([PSCustomObject]@{ Phase = 6; Name = "Ciberseguridad y Compatibilidad Anti-Cheat"; Status = if ($phase6Pass) { "PASS" } else { "FAIL" } })

# -----------------------------------------------------------------------------
# FASE 7: LATENCIA DE KERNEL Y TOPOLOGÍA MSI (PLAN-0097)
# -----------------------------------------------------------------------------
Write-StepHeader -StepNumber 7 -TotalSteps $totalSteps -Message "Auditoría de Latencia de Kernel, Topología MSI y Temporización"
$latencyScript = Join-Path $repoRoot "scripts\Testing\Test-KernelLatencyAndTopology.ps1"
$phase7Pass = $false
if (Test-Path $latencyScript) {
    & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $latencyScript -Quick
    if ($LASTEXITCODE -eq 0) {
        $phase7Pass = $true
        Write-OK "Fase 7 Aprobada: Latencia DPC/ISR y Topología MSI certificadas."
    } else {
        Write-ErrorMsg "Fase 7 Fallida: Se detectaron anomalías en la latencia o topología de interrupciones."
    }
} else {
    Write-Warn "Script de pruebas de latencia no encontrado en '$latencyScript'."
}
$suiteResults.Add([PSCustomObject]@{ Phase = 7; Name = "Latencia de Kernel y Topología MSI"; Status = if ($phase7Pass) { "PASS" } else { "FAIL" } })

# -----------------------------------------------------------------------------
# FASE 8: ARQUITECTURA DE ALMACENAMIENTO, RED NDIS Y MEMORIA (PLAN-0098)
# -----------------------------------------------------------------------------
Write-StepHeader -StepNumber 8 -TotalSteps $totalSteps -Message "Auditoría de Almacenamiento DirectStorage, Red NDIS y Memoria (RUPA)"
$storageNetScript = Join-Path $repoRoot "scripts\Testing\Test-StorageAndNetworkArchitecture.ps1"
$phase8Pass = $false
if (Test-Path $storageNetScript) {
    & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $storageNetScript -Quick
    if ($LASTEXITCODE -eq 0) {
        $phase8Pass = $true
        Write-OK "Fase 8 Aprobada: Almacenamiento, Red NDIS y Memoria Escalonada certificadas."
    } else {
        Write-ErrorMsg "Fase 8 Fallida: Se detectaron anomalías en la arquitectura de almacenamiento, red o memoria."
    }
} else {
    Write-Warn "Script de pruebas de almacenamiento y red no encontrado en '$storageNetScript'."
}
$suiteResults.Add([PSCustomObject]@{ Phase = 8; Name = "Almacenamiento DirectStorage, Red NDIS y Memoria"; Status = if ($phase8Pass) { "PASS" } else { "FAIL" } })

# -----------------------------------------------------------------------------
# FASE 9: MOTOR DE INSTANTÁNEAS Y ROLLBACK (Manage-SystemSnapshots)
# -----------------------------------------------------------------------------
Write-StepHeader -StepNumber 9 -TotalSteps $totalSteps -Message "Auditoría de Instantáneas Criptográficas y Rollback Engine"
$snapshotTestScript = Join-Path $repoRoot "scripts\Testing\Test-SnapshotEngine.ps1"
$phase9Pass = $false
if (Test-Path $snapshotTestScript) {
    & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $snapshotTestScript
    if ($LASTEXITCODE -eq 0) {
        $phase9Pass = $true
        Write-OK "Fase 9 Aprobada: Motor de Instantáneas, SHA-256 y Rollback certificados."
    } else {
        $phase9Pass = $false
        Write-ErrorMsg "Fase 9 Fallida: Se detectaron fallos en la batería de Snapshot Engine."
    }
} else {
    Write-Warn "Script de pruebas de Snapshot Engine no encontrado en '$snapshotTestScript'."
}
$suiteResults.Add([PSCustomObject]@{ Phase = 9; Name = "Instantáneas y Rollback Engine"; Status = if ($phase9Pass) { "PASS" } else { "FAIL" } })

# -----------------------------------------------------------------------------
# FASE 10: GESTOR DE PERFILES DE SOFTWARE Y RUNTIMES DE IA (PLAN-0100)
# -----------------------------------------------------------------------------
Write-StepHeader -StepNumber 10 -TotalSteps $totalSteps -Message "Auditoría de Perfiles de Software y Runtimes de IA"
$appProfilesTestScript = Join-Path $repoRoot "scripts\Testing\Test-AppProfilesManager.ps1"
$phase10Pass = $false
if (Test-Path $appProfilesTestScript) {
    & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $appProfilesTestScript
    if ($LASTEXITCODE -eq 0) {
        $phase10Pass = $true
        Write-OK "Fase 10 Aprobada: Catálogo SSOT, Runtimes de IA y Perfiles de Software certificados."
    } else {
        $phase10Pass = $false
        Write-ErrorMsg "Fase 10 Fallida: Se detectaron fallos en la batería de App & AI Profiles Manager."
    }
} else {
    Write-Warn "Script de pruebas de App Profiles no encontrado en '$appProfilesTestScript'."
}
$suiteResults.Add([PSCustomObject]@{ Phase = 10; Name = "Perfiles de Software y Runtimes de IA"; Status = if ($phase10Pass) { "PASS" } else { "FAIL" } })

# -----------------------------------------------------------------------------
# FASE 11: MONITOR DE THROTTLING TERMICO Y CALIBRADOR ENERGETICO (PLAN-0101)
# -----------------------------------------------------------------------------
Write-StepHeader -StepNumber 11 -TotalSteps $totalSteps -Message "Auditoría de Throttling Térmico y Calibración Energética"
$thermalTestScript = Join-Path $repoRoot "scripts\Testing\Test-ThermalEnergyMonitor.ps1"
$phase11Pass = $false
if (Test-Path $thermalTestScript) {
    & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $thermalTestScript
    if ($LASTEXITCODE -eq 0) {
        $phase11Pass = $true
        Write-OK "Fase 11 Aprobada: Sensores térmicos, Core Unparking y telemetría certificados."
    } else {
        $phase11Pass = $false
        Write-ErrorMsg "Fase 11 Fallida: Se detectaron fallos en la batería de Thermal & Energy Monitor."
    }
} else {
    Write-Warn "Script de pruebas de Thermal Monitor no encontrado en '$thermalTestScript'."
}
$suiteResults.Add([PSCustomObject]@{ Phase = 11; Name = "Throttling Térmico y Calibración Energética"; Status = if ($phase11Pass) { "PASS" } else { "FAIL" } })

# -----------------------------------------------------------------------------
# FASE 12: TEST HARNESS INTEGRAL (SI NO ES QUICK)
# -----------------------------------------------------------------------------
$phase12Pass = $true
if (-not $Quick) {
    Write-StepHeader -StepNumber 12 -TotalSteps $totalSteps -Message "Test Harness Integral del Generador de ISOs (140+ Tests)"
    $harnessCandidates = @(
        (Join-Path $repoRoot "scripts\Testing\Test-OptimizedISO-v2.ps1"),
        (Join-Path $repoRoot "scripts\Test-OptimizedISO-v2.ps1")
    )
    $harnessScript = $harnessCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($harnessScript) {
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $harnessScript -LogDir $LogDir
        if ($LASTEXITCODE -eq 0) {
            $phase12Pass = $true
            Write-OK "Fase 12 Aprobada: 140/140 pruebas del Test Harness superadas."
        } else {
            $phase12Pass = $false
            Write-ErrorMsg "Fase 12 Fallida: Se detectaron aserciones fallidas en el Test Harness."
        }
    } else {
        Write-Warn "Test Harness no encontrado en '$harnessScript'."
        $phase12Pass = $false
    }
    $suiteResults.Add([PSCustomObject]@{ Phase = 12; Name = "Test Harness Integral ISO v2"; Status = if ($phase12Pass) { "PASS" } else { "FAIL" } })
}

# -----------------------------------------------------------------------------
# REPORTE CONSOLIDADO Y EVALUACION FINAL
# -----------------------------------------------------------------------------
$totalDuration = [math]::Round(((Get-Date) - $testSuiteStart).TotalSeconds, 1)
$allSuccess = ($phase1Pass -and $phase2Pass -and $phase3Pass -and $phase4Pass -and $phase5Pass -and $phase6Pass -and $phase7Pass -and $phase8Pass -and $phase9Pass -and $phase10Pass -and $phase11Pass)
if (-not $Quick) {
    $allSuccess = ($allSuccess -and $phase12Pass)
}
$overallStatus = if ($allSuccess) { "SUCCESS" } else { "FAILED" }

try {
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    $reportPath = Join-Path $LogDir "TestSuite_Consolidated_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
    
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Informe Consolidado de Batería de Pruebas — romanOS")
    [void]$sb.AppendLine("- **Estado:** $(if ($allSuccess) { 'SUCCESS ✅' } else { 'FAILED ❌' })")
    [void]$sb.AppendLine("- **Fecha:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("- **Duración:** ${totalDuration}s")
    [void]$sb.AppendLine("- **Host:** $env:COMPUTERNAME | **PowerShell:** $($PSVersionTable.PSVersion)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Resumen de Fases de Auditoría")
    [void]$sb.AppendLine("| Fase | Suite de Prueba | Resultado |")
    [void]$sb.AppendLine("|---|---|---|")
    foreach ($r in $suiteResults) {
        $badge = if ($r.Status -eq "PASS") { "PASS ✅" } else { "FAIL ❌" }
        [void]$sb.AppendLine("| $($r.Phase) | $($r.Name) | $badge |")
    }
    [System.IO.File]::WriteAllText($reportPath, $sb.ToString(), [System.Text.Encoding]::UTF8)
} catch {
    Write-Warning "No se pudo escribir el reporte consolidado en '$reportPath': $($_.Exception.Message)"
}

$logMap = @{}
if ($reportPath) { $logMap["Reporte Consolidado"] = $reportPath }

Show-UnifiedSummary -Title "BATERIA DE PRUEBAS romanOS" -Status $overallStatus -DurationSeconds $totalDuration -ErrorsCount $(if ($allSuccess) { 0 } else { 1 }) -WarnsCount 0 -Logs $logMap

exit $(if ($allSuccess) { 0 } else { 1 })
