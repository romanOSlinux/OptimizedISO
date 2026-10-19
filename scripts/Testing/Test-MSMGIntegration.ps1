# =============================================================================
# romanOS Testing Harness - MSMG Toolkit & DISM Servicing Integration Tests
# PLAN-0118: Catálogo Canónico de Componentes DISM, Remoción Offline y ResetBase
# =============================================================================

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:TotalTests = 0
$script:PassCount  = 0
$script:FailCount  = 0
$script:Results    = [System.Collections.Generic.List[PSCustomObject]]::new()

function Assert-Condition {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$FailureMessage = ""
    )
    $script:TotalTests++
    if ($Condition) {
        $script:PassCount++
        Write-Host "  [PASS] $TestName" -ForegroundColor Green
        $script:Results.Add([PSCustomObject]@{ Name = $TestName; Status = "PASS"; Details = "" })
    } else {
        $script:FailCount++
        Write-Host "  [FAIL] $TestName" -ForegroundColor Red
        if ($FailureMessage) { Write-Host "         $FailureMessage" -ForegroundColor DarkRed }
        $script:Results.Add([PSCustomObject]@{ Name = $TestName; Status = "FAIL"; Details = $FailureMessage })
    }
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " [romanOS] Test Suite: Integracion MSMG Toolkit y Servicing DISM (PLAN-0118)" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if (-not (Test-Path $projectRoot)) {
    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$policyEnginePath = Join-Path $projectRoot "scripts\Core\Policy-Engine.ps1"
$builderPath      = Join-Path $projectRoot "scripts\Builder\New-OptimizedWindowsISO-v2.ps1"
$toolkitPath      = Join-Path $projectRoot "scripts\Modules\romanOS-Toolkit.ps1"
$controlCenterPath = Join-Path $projectRoot "scripts\GUI\romanOS-ControlCenter.ps1"

# -----------------------------------------------------------------------------
# 1. VALIDACIÓN DE CODIFICACIÓN Y AST EN SCRIPTS DE IMPACTO
# -----------------------------------------------------------------------------
Write-Host "`n--- 1. Auditoria de Codificacion (UTF-8 con BOM) y AST (PS 5.1) ---" -ForegroundColor Cyan

$filesToCheck = @($policyEnginePath, $builderPath, $toolkitPath, $controlCenterPath)
foreach ($f in $filesToCheck) {
    $leaf = Split-Path $f -Leaf
    Assert-Condition "Archivo existe: $leaf" (Test-Path $f) "Ruta no encontrada: $f"
    if (Test-Path $f) {
        $bytes = [System.IO.File]::ReadAllBytes($f)
        $hasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        Assert-Condition "Regla 4: $leaf tiene codificacion UTF-8 con BOM" $hasBOM "BOM ausente en $leaf"

        $tokens = $null; $errs = @()
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tokens, [ref]$errs)
        Assert-Condition "Regla 4: $leaf libre de errores sintacticos AST (0 errores)" ($errs.Count -eq 0) "Errores: $($errs -join '; ')"
    }
}

# -----------------------------------------------------------------------------
# 2. VALIDACIÓN DEL CATÁLOGO CANÓNICO DE COMPONENTES DISM (SSOT)
# -----------------------------------------------------------------------------
Write-Host "`n--- 2. Validacion de Catalogo Canónico DISM (Policy-Engine.ps1) ---" -ForegroundColor Cyan

if (Test-Path $policyEnginePath) {
    . $policyEnginePath

    Assert-Condition "Funcion Get-RomanOSDismComponentsCatalog exportada" ($null -ne (Get-Command 'Get-RomanOSDismComponentsCatalog' -ErrorAction SilentlyContinue))

    $catalog = Get-RomanOSDismComponentsCatalog
    Assert-Condition "Catalogo DISM retorna lista no nula" ($null -ne $catalog)
    Assert-Condition "Catalogo DISM contiene al menos 14 componentes" (@($catalog).Count -ge 14) "Conteo actual: $(@($catalog).Count)"

    $validTypes = @("Capability", "OptionalFeature", "PackagePattern")
    $validCategories = @("Telemetria", "Legacy", "Accesorios", "Red", "Empresarial", "Impresion", "Inteligencia Artificial")

    $allWellFormed = $true
    $allSafeUpdate = $true
    $allValidTypes = $true
    $allValidCats  = $true

    foreach ($comp in $catalog) {
        if (-not ($comp.Id -and $comp.Name -and $comp.Category -and $comp.Type -and $comp.TargetName)) {
            $allWellFormed = $false
        }
        if ($comp.BreaksWindowsUpdate -ne $false) {
            $allSafeUpdate = $false
        }
        if ($validTypes -notcontains $comp.Type) {
            $allValidTypes = $false
        }
        if ($validCategories -notcontains $comp.Category) {
            $allValidCats = $false
        }
    }

    Assert-Condition "Todos los componentes poseen Id, Name, Category, Type y TargetName" $allWellFormed
    Assert-Condition "Todos los componentes preservan compatibilidad con Windows Update (BreaksWindowsUpdate = False)" $allSafeUpdate
    Assert-Condition "Todos los componentes utilizan tipos DISM oficiales (Capability, OptionalFeature, PackagePattern)" $allValidTypes
    Assert-Condition "Todos los componentes pertenecen a categorias validas" $allValidCats

    # Comprobación de componentes específicos clave inspirados en MSMG
    $ceip = $catalog | Where-Object { $_.Id -eq "DISM_COMP_CEIP" }
    Assert-Condition "Componente CEIP presente en el catalogo" ($null -ne $ceip -and $ceip.Category -eq "Telemetria")

    $vbscript = $catalog | Where-Object { $_.Id -eq "DISM_COMP_VBSCRIPT" }
    Assert-Condition "Componente VBScript FOD presente en el catalogo" ($null -ne $vbscript -and $vbscript.Type -eq "Capability")

    $telnet = $catalog | Where-Object { $_.Id -eq "DISM_FEAT_TELNET_CLIENT" }
    Assert-Condition "Caracteristica TelnetClient presente en el catalogo" ($null -ne $telnet -and $telnet.Type -eq "OptionalFeature")

    $recall = $catalog | Where-Object { $_.Id -eq "DISM_FEAT_RECALL" }
    Assert-Condition "Caracteristica Windows Recall presente en el catalogo DISM (PLAN-0122)" ($null -ne $recall -and $recall.Type -eq "OptionalFeature" -and $recall.TargetName -eq "Recall")
}

# -----------------------------------------------------------------------------
# 3. VALIDACIÓN DE FUNCIONES DE SERVICING EN EL BUILDER
# -----------------------------------------------------------------------------
Write-Host "`n--- 3. Validacion de Funciones de Servicing en Builder (New-OptimizedWindowsISO-v2.ps1) ---" -ForegroundColor Cyan

if (Test-Path $builderPath) {
    $builderContent = [System.IO.File]::ReadAllText($builderPath)

    Assert-Condition "Builder declara funcion Invoke-RomanOSDismComponentRemoval" ($builderContent -match 'function\s+Invoke-RomanOSDismComponentRemoval')
    Assert-Condition "Builder declara funcion Invoke-RomanOSComponentStoreCleanup" ($builderContent -match 'function\s+Invoke-RomanOSComponentStoreCleanup')
    Assert-Condition "Builder incluye parametro RemoveDismComponents" ($builderContent -match '\[switch\]\$RemoveDismComponents')
    Assert-Condition "Builder integra remoción DISM en el flujo de servicing WIM" ($builderContent -match 'Invoke-RomanOSDismComponentRemoval -MountDir')
    Assert-Condition "Builder integra consolidación WinSxS en el flujo de servicing WIM" ($builderContent -match 'Invoke-RomanOSComponentStoreCleanup -MountDir')

    # Proveer fallbacks globales de logging para ejecucion aislada
    if (-not (Get-Command 'Write-Warn' -ErrorAction SilentlyContinue)) { function global:Write-Warn { param($m) Write-Warning $m } }
    if (-not (Get-Command 'Write-OK' -ErrorAction SilentlyContinue))   { function global:Write-OK   { param($m) Write-Host "  [OK] $m" -ForegroundColor Green } }
    if (-not (Get-Command 'Write-Info' -ErrorAction SilentlyContinue)) { function global:Write-Info { param($m) Write-Host "  [i] $m" -ForegroundColor DarkGray } }

    # Cargar funciones con AST de forma segura para prueba unitaria directa
    $funcAsts = @{}
    $astRoot = [System.Management.Automation.Language.Parser]::ParseInput($builderContent, [ref]$tokens, [ref]$errs)
    $funcDefList = $astRoot.FindAll({ param($ast) $ast -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fAst in $funcDefList) {
        $funcAsts[$fAst.Name] = $fAst.Extent.Text
    }

    if ($funcAsts.ContainsKey("Invoke-RomanOSDismComponentRemoval")) {
        . ([scriptblock]::Create($funcAsts["Invoke-RomanOSDismComponentRemoval"]))
        Assert-Condition "Invoke-RomanOSDismComponentRemoval compilada en memoria" ($null -ne (Get-Command 'Invoke-RomanOSDismComponentRemoval' -ErrorAction SilentlyContinue))

        $resNonExistent = Invoke-RomanOSDismComponentRemoval -MountDir "C:\NonExistent_Mount_Dir_Mock"
        Assert-Condition "Invoke-RomanOSDismComponentRemoval maneja directorios inexistentes controladamente" ($resNonExistent.Success -eq $false)
        Assert-Condition "Invoke-RomanOSDismComponentRemoval provee detalle de error visible (CWE-390)" ($resNonExistent.Details.Count -gt 0)
    }

    if ($funcAsts.ContainsKey("Invoke-RomanOSComponentStoreCleanup")) {
        . ([scriptblock]::Create($funcAsts["Invoke-RomanOSComponentStoreCleanup"]))
        Assert-Condition "Invoke-RomanOSComponentStoreCleanup compilada en memoria" ($null -ne (Get-Command 'Invoke-RomanOSComponentStoreCleanup' -ErrorAction SilentlyContinue))

        $resCleanupNonExistent = Invoke-RomanOSComponentStoreCleanup -MountDir "C:\NonExistent_Mount_Dir_Mock"
        Assert-Condition "Invoke-RomanOSComponentStoreCleanup maneja directorios inexistentes controladamente" ($resCleanupNonExistent.Success -eq $false)
        Assert-Condition "Invoke-RomanOSComponentStoreCleanup inicializa estructura de metricas (SizeBeforeMB, SizeAfterMB, SavedMB)" ($null -ne $resCleanupNonExistent.SavedMB)
    }
}

# -----------------------------------------------------------------------------
# 4. VALIDACIÓN DE PARIDAD EN TOOLKIT Y CONTROL CENTER
# -----------------------------------------------------------------------------
Write-Host "`n--- 4. Validacion de Paridad en romanOS-Toolkit y romanOS-ControlCenter ---" -ForegroundColor Cyan

if (Test-Path $toolkitPath) {
    $toolkitContent = [System.IO.File]::ReadAllText($toolkitPath)
    Assert-Condition "Toolkit Maestro incluye Catalogo DISM en opciones de menu" ($toolkitContent -match 'Catalogo Canonico de Componentes Opcionales DISM')
    Assert-Condition "Toolkit Maestro incluye Consolidacion ResetBase en opciones de menu" ($toolkitContent -match 'Consolidacion Profunda de WinSxS')
}

if (Test-Path $controlCenterPath) {
    $ccContent = [System.IO.File]::ReadAllText($controlCenterPath)
    Assert-Condition "Control Center incluye boton de inspeccion de componentes DISM en XAML" ($ccContent -match 'x:Name="btnInspectDismCatalog"')
    Assert-Condition "Control Center enlaza manejador de clic para catalogo DISM" ($ccContent -match 'btnInspectDismCatalog.*Add_Click')
    Assert-Condition "Control Center incluye switch -ResetBase en mantenimiento profundo" ($ccContent -match '-DeepClean -ResetBase')
}

# -----------------------------------------------------------------------------
# EVALUACIÓN FINAL
# -----------------------------------------------------------------------------
Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " EVALUACION FINAL DE SUITE MSMG DISM INTEGRATION" -ForegroundColor Cyan
Write-Host " Total de Pruebas : $($script:TotalTests)" -ForegroundColor White
Write-Host " PASS             : $($script:PassCount)" -ForegroundColor Green
Write-Host " FAIL             : $($script:FailCount)" -ForegroundColor $(if ($script:FailCount -gt 0) { "Red" } else { "Green" })
Write-Host "==========================================================================" -ForegroundColor Cyan

if ($script:FailCount -gt 0) {
    exit 1
} else {
    exit 0
}
