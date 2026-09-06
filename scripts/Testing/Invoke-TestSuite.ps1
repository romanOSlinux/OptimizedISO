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
    [string]$LogDir = "C:\OptimizedISO\Log"
)

$ErrorActionPreference = 'Continue'
$testSuiteStart = Get-Date

# -----------------------------------------------------------------------------
# CARGA DE MOTOR VISUAL UNIFICADO
# -----------------------------------------------------------------------------
$uiEnginePath = Join-Path $PSScriptRoot "Core\UI-Engine.ps1"
if (Test-Path $uiEnginePath) {
    . $uiEnginePath
} else {
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
$totalSteps = if ($Quick) { 5 } else { 6 }
$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $repoRoot ".agents"))) { $repoRoot = "C:\OptimizedISO" }

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
# FASE 6: TEST HARNESS INTEGRAL (SI NO ES QUICK)
# -----------------------------------------------------------------------------
$phase6Pass = $true
if (-not $Quick) {
    Write-StepHeader -StepNumber 6 -TotalSteps $totalSteps -Message "Test Harness Integral del Generador de ISOs (140+ Tests)"
    $harnessCandidates = @(
        (Join-Path $repoRoot "scripts\Testing\Test-OptimizedISO-v2.ps1"),
        (Join-Path $repoRoot "scripts\Test-OptimizedISO-v2.ps1")
    )
    $harnessScript = $harnessCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($harnessScript) {
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $harnessScript -LogDir $LogDir
        if ($LASTEXITCODE -eq 0) {
            $phase6Pass = $true
            Write-OK "Fase 6 Aprobada: 140/140 pruebas del Test Harness superadas."
        } else {
            $phase6Pass = $false
            Write-ErrorMsg "Fase 6 Fallida: Se detectaron aserciones fallidas en el Test Harness."
        }
    } else {
        Write-Warn "Test Harness no encontrado en '$harnessScript'."
        $phase6Pass = $false
    }
    $suiteResults.Add([PSCustomObject]@{ Phase = 6; Name = "Test Harness Integral ISO v2"; Status = if ($phase6Pass) { "PASS" } else { "FAIL" } })
}

# -----------------------------------------------------------------------------
# REPORTE CONSOLIDADO Y EVALUACION FINAL
# -----------------------------------------------------------------------------
$totalDuration = [math]::Round(((Get-Date) - $testSuiteStart).TotalSeconds, 1)
$allSuccess = ($phase1Pass -and $phase2Pass -and $phase3Pass -and $phase4Pass -and $phase5Pass -and $phase6Pass)
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
} catch {}

$logMap = @{}
if ($reportPath) { $logMap["Reporte Consolidado"] = $reportPath }

Show-UnifiedSummary -Title "BATERIA DE PRUEBAS romanOS" -Status $overallStatus -DurationSeconds $totalDuration -ErrorsCount $(if ($allSuccess) { 0 } else { 1 }) -WarnsCount 0 -Logs $logMap

exit $(if ($allSuccess) { 0 } else { 1 })
