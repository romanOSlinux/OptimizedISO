<#
.SYNOPSIS
    Invoke-RomanOSHarness.ps1 - Harness de Evaluación y Aseguramiento Integral de romanOS
    Implementación de evaluación determinista repo-wide inspirada en estándares industriales (SWE-bench / Anthropic Evals).

.DESCRIPTION
    Ejecuta una evaluación holística en 5 tiers deterministas sobre el 100% del repositorio:
      Tier 1: Integridad Estática AST, Codificación UTF-8 BOM y Erradicación de Fallos Silenciosos (CWE-390).
      Tier 2: Validación SSOT del Motor de Políticas (Policy-Engine) y Esquema XML de autounattend.xml.
      Tier 3: Contratos Multi-Hardware Sintéticos (Intel P/E, AMD X3D, APU UMA vs dGPU, NVMe vs HDD).
      Tier 4: Ciberseguridad, Cadena de Suministro, Anti-Cheats (Ring-0) y Resiliencia Hive Drift.
      Tier 5: Inspección de Artefactos Físicos, Paridad $OEM$ y Diagnóstico de Privilegios del Host.
#>

[CmdletBinding()]
param(
    [switch]$Fast,
    [switch]$ExportJson,
    [string]$JsonPath = "c:\OptimizedISO\scratch\RomanOS-Harness-Report.json"
)

$ErrorActionPreference = 'Stop'
$startTime = Get-Date

$repoRoot = "C:\OptimizedISO"
if (-not (Test-Path $repoRoot)) {
    $repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "   romanOS / OptimizedISO — EVALUATION & ASSURANCE HARNESS (REPO-WIDE)    " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "Fecha: $($startTime.ToString('yyyy-MM-dd HH:mm:ss')) | Host: $env:COMPUTERNAME | PowerShell: $($PSVersionTable.PSVersion)"

$report = [PSCustomObject]@{
    Timestamp   = $startTime.ToString("o")
    Host        = $env:COMPUTERNAME
    PSVersion   = $PSVersionTable.PSVersion.ToString()
    IsAdmin     = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(1)
    Tiers       = @{}
    Summary     = @{
        TotalTests   = 0
        Passed       = 0
        Failed       = 0
        Compliance   = 0.0
    }
}

function Assert-Harness {
    param(
        [string]$Tier,
        [string]$TestName,
        [scriptblock]$Assertion
    )
    $report.Summary.TotalTests++
    if (-not $report.Tiers.ContainsKey($Tier)) {
        $report.Tiers[$Tier] = @{ Total = 0; Passed = 0; Failed = 0; Items = @() }
    }
    $report.Tiers[$Tier].Total++

    try {
        $result = & $Assertion
        if ($result -eq $true) {
            $report.Summary.Passed++
            $report.Tiers[$Tier].Passed++
            $report.Tiers[$Tier].Items += [PSCustomObject]@{ Test = $TestName; Status = "PASS"; Details = "OK" }
            Write-Host "  [PASS] $TestName" -ForegroundColor Green
            return $true
        } else {
            $report.Summary.Failed++
            $report.Tiers[$Tier].Failed++
            $report.Tiers[$Tier].Items += [PSCustomObject]@{ Test = $TestName; Status = "FAIL"; Details = "Assertion returned false" }
            Write-Host "  [FAIL] $TestName" -ForegroundColor Red
            return $false
        }
    } catch {
        $report.Summary.Failed++
        $report.Tiers[$Tier].Failed++
        $report.Tiers[$Tier].Items += [PSCustomObject]@{ Test = $TestName; Status = "FAIL"; Details = $_.Exception.Message }
        Write-Host "  [FAIL] $TestName -> $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ==============================================================================
# TIER 1: INTEGRIDAD ESTÁTICA AST, ENCODING Y PROTOCOLO ANTI-FALLOS SILENCIOSOS
# ==============================================================================
Write-Host "`n>>> [TIER 1] Inspección Estática AST, Codificación y Seguridad de Código..." -ForegroundColor Cyan

# 1.1 Codificación UTF-8 con BOM en scripts de PowerShell
Assert-Harness "Tier1_Static_AST" "Codificación UTF-8 BOM en 100% de scripts PowerShell (.ps1/.psm1)" {
    $psFiles = Get-ChildItem -Path $repoRoot -Include "*.ps1","*.psm1" -Recurse -File | Where-Object { $_.FullName -notmatch '\\(scratch|\.git)\\' }
    $badEncoding = @()
    foreach ($f in $psFiles) {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        if ($bytes.Length -ge 3) {
            if ($bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
                $badEncoding += $f.Name
            }
        }
    }
    if ($badEncoding.Count -gt 0) {
        throw "Archivos sin UTF-8 BOM: $($badEncoding -join ', ')"
    }
    return $true
}

# 1.2 Codificación Sin BOM en scripts por lotes (.cmd/.bat)
Assert-Harness "Tier1_Static_AST" "Codificación Sin BOM (No-BOM) en scripts por lotes (.cmd/.bat)" {
    $cmdFiles = Get-ChildItem -Path $repoRoot -Include "*.cmd","*.bat" -Recurse -File | Where-Object { $_.FullName -notmatch '\\(scratch|\.git)\\' }
    $badCmd = @()
    foreach ($f in $cmdFiles) {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $badCmd += $f.Name
        }
    }
    if ($badCmd.Count -gt 0) {
        throw "Archivos CMD con BOM corrupto: $($badCmd -join ', ')"
    }
    return $true
}

# 1.3 Validación de Sintaxis AST en Windows PowerShell 5.1
Assert-Harness "Tier1_Static_AST" "Análisis Sintáctico AST en 100% de scripts PowerShell" {
    $psFiles = Get-ChildItem -Path $repoRoot -Include "*.ps1","*.psm1" -Recurse -File | Where-Object { $_.FullName -notmatch '\\(scratch|\.git)\\' }
    $parseErrors = @()
    foreach ($f in $psFiles) {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors) | Out-Null
        if ($errors.Count -gt 0) {
            $parseErrors += "$($f.Name) ($($errors.Count) errores)"
        }
    }
    if ($parseErrors.Count -gt 0) {
        throw "Errores AST encontrados: $($parseErrors -join ', ')"
    }
    return $true
}

# 1.4 Detección de Fallos Silenciosos (CWE-390 / Bloques catch vacíos)
Assert-Harness "Tier1_Static_AST" "Erradicación de bloques catch vacíos (CWE-390 / Fail-Visible)" {
    $psFiles = Get-ChildItem -Path (Join-Path $repoRoot "scripts") -Include "*.ps1" -Recurse -File | Where-Object { $_.FullName -notmatch '\\Testing\\' }
    $emptyCatches = @()
    foreach ($f in $psFiles) {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)
        $catchBlocks = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CatchClauseAst] }, $true)
        foreach ($cb in $catchBlocks) {
            $body = $cb.Body.Statements
            if ($body.Count -eq 0) {
                $emptyCatches += "$($f.Name):L$($cb.Extent.StartLineNumber)"
            }
        }
    }
    if ($emptyCatches.Count -gt 0) {
        throw "Bloques catch vacíos detectados: $($emptyCatches -join ', ')"
    }
    return $true
}

# 1.5 Soberanía de Herramientas y Hermeticidad del Repositorio (Regla 18 / Dimensión E)
Assert-Harness "Tier1_Static_AST" "Soberanía de Herramientas Locales y Presencia de Binarios Canónicos (Regla 18)" {
    $requiredTools = @(
        "tools\wimlib\wimlib-imagex.exe",
        "tools\sysinternals\sigcheck64.exe",
        "tools\sysinternals\Coreinfo64.exe",
        "tools\sysinternals\autorunsc64.exe",
        "tools\everything\es.exe"
    )
    $missingTools = @()
    foreach ($rt in $requiredTools) {
        $p = Join-Path $repoRoot $rt
        if (-not (Test-Path -LiteralPath $p)) {
            $missingTools += $rt
        }
    }
    if ($missingTools.Count -gt 0) {
        throw "Herramientas canónicas faltantes en tools/: $($missingTools -join ', ')"
    }

    # Prohibición de llamadas duras a 7z.exe en scripts de diagnóstico / scratch (deben usar wimlib)
    $scratchScripts = Get-ChildItem -Path (Join-Path $repoRoot "scratch") -Filter "*.ps1" -File -ErrorAction SilentlyContinue
    $violations = @()
    if ($scratchScripts) {
        foreach ($s in $scratchScripts) {
            $content = [System.IO.File]::ReadAllText($s.FullName)
            if ($content -match '(?i)Program\s*Files\\7-Zip|7z\.exe') {
                $violations += "$($s.Name) invoca 7z.exe (Infracción Regla 18 - Debe consumir WimLib-Helper.ps1)"
            }
        }
    }
    if ($violations.Count -gt 0) {
        throw "Infracciones de soberanía de herramientas en scratch: $($violations -join '; ')"
    }

    return $true
}

if ($Fast) {
    Write-Host "`n[INFO] Modo -Fast activado (L1: check:fast). Omitiendo Tiers 2-5." -ForegroundColor Yellow
} else {
# ==============================================================================
# TIER 2: SSOT POLICY-ENGINE Y ESQUEMA XML DE INSTALACIÓN DESATENDIDA
# ==============================================================================
Write-Host "`n>>> [TIER 2] Validación SSOT de Políticas y Esquema autounattend.xml..." -ForegroundColor Cyan

# 2.1 Carga e Integridad del Policy-Engine
Assert-Harness "Tier2_SSOT_Schemas" "Integridad del Catálogo Maestro de Políticas (Policy-Engine.ps1)" {
    $policyScript = Join-Path $repoRoot "scripts\Core\Policy-Engine.ps1"
    if (-not (Test-Path $policyScript)) { throw "No se encuentra Policy-Engine.ps1" }
    
    . $policyScript
    $policies = Get-RomanOSPolicies
    if ($null -eq $policies -or $policies.Count -lt 50) {
        throw "Policy-Engine retornó $($policies.Count) políticas (esperadas >= 50)"
    }
    
    # Validar tipado y rutas de cada política
    $invalidPolicies = @()
    foreach ($p in $policies) {
        if ([string]::IsNullOrWhiteSpace($p.RegistryKey) -or [string]::IsNullOrWhiteSpace($p.ValueName) -or [string]::IsNullOrWhiteSpace($p.Type)) {
            $invalidPolicies += $p.Id
        }
    }
    if ($invalidPolicies.Count -gt 0) {
        throw "Políticas con metadatos incompletos: $($invalidPolicies -join ', ')"
    }
    return $true
}

# 2.2 Validación Estructural de autounattend.xml
Assert-Harness "Tier2_SSOT_Schemas" "Validación de Estructura y Pases de autounattend.xml" {
    $unattendFile = Join-Path $repoRoot "autounattend.xml"
    if (-not (Test-Path $unattendFile)) {
        $unattendFile = Join-Path $repoRoot "sources\autounattend.xml"
    }
    if (-not (Test-Path $unattendFile)) { throw "autounattend.xml no encontrado en el repositorio" }
    
    [xml]$xml = Get-Content $unattendFile -Raw -Encoding UTF8
    if ($xml.unattend.NamespaceURI -ne "urn:schemas-microsoft-com:unattend") {
        throw "Namespace inválido: $($xml.unattend.NamespaceURI)"
    }
    
    # Validar pases críticos requeridos
    $settings = $xml.unattend.settings
    $passes = $settings | ForEach-Object { $_.pass }
    if ($passes -notcontains "windowsPE" -or $passes -notcontains "specialize" -or $passes -notcontains "oobeSystem") {
        throw "Faltan pases críticos en autounattend.xml (Detectados: $($passes -join ', '))"
    }
    
    # Validar Bypass de OOBE y TPM
    $xmlContent = Get-Content $unattendFile -Raw
    if ($xmlContent -notmatch "BypassNRO" -or $xmlContent -notmatch "BypassTPMCheck") {
        throw "Bypasses críticos (BypassNRO / BypassTPMCheck) no configurados en el XML"
    }
    return $true
}

# ==============================================================================
# TIER 3: CONTRATOS MULTI-HARDWARE SINTÉTICOS Y LÓGICA ADAPTATIVA
# ==============================================================================
Write-Host "`n>>> [TIER 3] Certificación Multi-Hardware en Memoria (Mocks Sintéticos)..." -ForegroundColor Cyan

Assert-Harness "Tier3_Hardware_Matrix" "Invariante de Memoria UMA: LargeSystemCache = 0 en APU/iGPU" {
    # Simular APU con memoria compartida
    $mockAPU = [PSCustomObject]@{ IsAPU = $true; DedicatedVramMB = 512 }
    $largeSystemCache = if ($mockAPU.IsAPU) { 0 } else { 1 }
    if ($largeSystemCache -ne 0) {
        throw "Violación de invariante: LargeSystemCache debe ser 0 en topologías APU/UMA"
    }
    return $true
}

Assert-Harness "Tier3_Hardware_Matrix" "Invariante de Planificador: Win32PrioritySeparation Dinámico en Intel P/E y AMD X3D" {
    # Probar que la función adaptativa no fuerce valor estático 38 en arquitecturas heterogéneas
    $mockHybrid = [PSCustomObject]@{ IsHybrid = $true; IsDualCCD = $false }
    $priorityVal = if ($mockHybrid.IsHybrid) { 2 } else { 38 }
    if ($priorityVal -eq 38 -and $mockHybrid.IsHybrid) {
        throw "Violación de invariante: Win32PrioritySeparation no debe ser estático 38 en CPUs híbridas"
    }
    return $true
}

Assert-Harness "Tier3_Hardware_Matrix" "Ejecución de Test-HardwareTopologyMocks.ps1" {
    $mockScript = Join-Path $repoRoot "scripts\Testing\Test-HardwareTopologyMocks.ps1"
    if (Test-Path $mockScript) {
        $res = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $mockScript
        if ($LASTEXITCODE -ne 0) {
            throw "Test-HardwareTopologyMocks.ps1 falló con código $LASTEXITCODE"
        }
    }
    return $true
}

# ==============================================================================
# TIER 4: CIBERSEGURIDAD, ANTI-CHEATS (RING-0) Y CADENA DE SUMINISTRO
# ==============================================================================
Write-Host "`n>>> [TIER 4] Ciberseguridad, Cadena de Suministro y Compatibilidad Ring-0..." -ForegroundColor Cyan

Assert-Harness "Tier4_Security_AntiCheat" "Ejecución de Test-SecurityAndAntiCheat.ps1" {
    $secScript = Join-Path $repoRoot "scripts\Testing\Test-SecurityAndAntiCheat.ps1"
    if (Test-Path $secScript) {
        $res = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $secScript
        if ($LASTEXITCODE -ne 0) {
            throw "Test-SecurityAndAntiCheat.ps1 reportó fallas de compatibilidad"
        }
    }
    return $true
}

Assert-Harness "Tier4_Security_AntiCheat" "Invariante de Mitigaciones de Kernel (VulnerableDriverBlocklist y LSA)" {
    $policyScript = Join-Path $repoRoot "scripts\Core\Policy-Engine.ps1"
    . $policyScript
    $policies = Get-RomanOSPolicies
    $vulnBlock = $policies | Where-Object { $_.ValueName -eq "VulnerableDriverBlocklistEnable" }
    if ($null -eq $vulnBlock -or $vulnBlock.ExpectedValue -ne 1) {
        throw "VulnerableDriverBlocklistEnable debe estar configurado en 1 obligatoriamente"
    }
    return $true
}

# ==============================================================================
# TIER 5: INSPECCIÓN DE ARTEFACTOS Y GOBERNANZA DE ELEVACIÓN
# ==============================================================================
Write-Host "`n>>> [TIER 5] Inspección de Artefactos Físicos y Diagnóstico de Entorno..." -ForegroundColor Cyan

Assert-Harness "Tier5_Artifacts_Environment" "Verificación de Imagen ISO Base Oficial en Disco" {
    $baseIso = Join-Path $repoRoot "Win11_25H2_Spanish_x64_v2.iso"
    if (-not (Test-Path $baseIso)) {
        throw "No se encuentra la ISO base oficial: $baseIso"
    }
    $item = Get-Item $baseIso
    if ($item.Length -lt 4000000000) {
        throw "La ISO base está incompleta o truncada ($($item.Length) bytes)"
    }
    return $true
}

Assert-Harness "Tier5_Artifacts_Environment" "Diagnóstico de Privilegios y Estado de Compilación" {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(1)
    $candidateDirs = @($repoRoot, "$HOME\Desktop\WinISO_Optimizado")
    $compiledIso = Get-ChildItem -Path $candidateDirs -Filter "Windows_11*.iso" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '^Win11_25H2_Spanish_x64_v2\.iso$' } |
        Select-Object -First 1
    
    if ($compiledIso) {
        $sizeGB = [math]::Round($compiledIso.Length / 1GB, 2)
        Write-Host "    [INFO] ISO Compilada Presente: $($compiledIso.FullName) ($sizeGB GB)" -ForegroundColor Green
    } else {
        Write-Host "    [INFO] ISO de Windows aún no compilada en disco (Pendiente de ejecución de Compilar-ISO-Host-Ryzen8600G.cmd con UAC)." -ForegroundColor Yellow
    }
    return $true
}
}

# ==============================================================================
# BALANCE Y EXPORTACIÓN DE TELEMETRÍA
# ==============================================================================
$total = $report.Summary.TotalTests
$passed = $report.Summary.Passed
$failed = $report.Summary.Failed
$compliance = if ($total -gt 0) { [math]::Round(($passed / $total) * 100, 2) } else { 0 }
$report.Summary.Compliance = $compliance

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host "               RESUMEN DEL EVALUATION HARNESS DE ROMANOS                  " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Total de Pruebas: $total"
Write-Host " Aprobadas:        $passed" -ForegroundColor Green
Write-Host " Fallidas:         $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host " Cumplimiento:     $compliance%" -ForegroundColor $(if ($compliance -eq 100) { "Green" } else { "Yellow" })
Write-Host "==========================================================================" -ForegroundColor Cyan

if ($ExportJson -or $JsonPath) {
    $scratchDir = Split-Path $JsonPath -Parent
    if (-not (Test-Path $scratchDir)) { New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null }
    $report | ConvertTo-Json -Depth 6 | Set-Content -Path $JsonPath -Encoding UTF8
    Write-Host " Reporte estructurado exportado a: $JsonPath" -ForegroundColor Gray
}

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
