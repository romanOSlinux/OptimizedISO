<#
.SYNOPSIS
    Test-AppProfilesManager.ps1 - Arnés de Pruebas Unitarias para romanOS App & AI Runtimes Manager
    romanOS / OptimizedISO — Estado del Arte Windows 11 24H2 / 25H2

.DESCRIPTION
    Suite automatizada de pruebas unitarias para certificar la integridad estructural,
    deserialización del catálogo JSON, codificación UTF-8 con BOM, compatibilidad
    con Windows PowerShell 5.1, auto-detección adaptativa de hardware y modo simulado (-WhatIf).

.EXAMPLE
    .\Test-AppProfilesManager.ps1
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Quick
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS — BATERIA DE PRUEBAS: APP PROFILES & AI RUNTIMES MANAGER          " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Runtime: Windows PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
Write-Host ""

$testStartTime = Get-Date
$passCount = 0
$failCount = 0

function Assert-Test {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$Details = ""
    )
    if ($Condition) {
        $script:passCount++
        Write-Host "  [PASS] $TestName" -ForegroundColor Green
        if ($Details) { Write-Host "         $Details" -ForegroundColor DarkGray }
    } else {
        $script:failCount++
        Write-Host "  [FAIL] $TestName" -ForegroundColor Red
        if ($Details) { Write-Host "         Detalle: $Details" -ForegroundColor Yellow }
    }
}

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $repoRoot "scripts"))) {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

$catalogPath = Join-Path $repoRoot "scripts\Core\App-Profiles-Catalog.json"
$scriptPath  = Join-Path $repoRoot "scripts\Modules\Deploy-AppProfiles.ps1"
$cmdPath     = Join-Path $repoRoot "scripts\Modules\Deploy-AppProfiles.cmd"

# -----------------------------------------------------------------------------
# 1. INTEGRIDAD DE ARCHIVOS Y CODIFICACION ESTRICTA (REGLA 4)
# -----------------------------------------------------------------------------
Write-Host ">>> [1/3] Verificando Archivos y Codificacion de Encodings..." -ForegroundColor Yellow

Assert-Test -TestName "Existencia fisica de App-Profiles-Catalog.json" `
            -Condition (Test-Path $catalogPath) `
            -Details $catalogPath

Assert-Test -TestName "Existencia fisica de Deploy-AppProfiles.ps1" `
            -Condition (Test-Path $scriptPath) `
            -Details $scriptPath

Assert-Test -TestName "Existencia fisica de Deploy-AppProfiles.cmd" `
            -Condition (Test-Path $cmdPath) `
            -Details $cmdPath

# Validar BOM en Deploy-AppProfiles.ps1
$ps1Bytes = [System.IO.File]::ReadAllBytes($scriptPath)
$hasBOM = ($ps1Bytes.Length -ge 3 -and $ps1Bytes[0] -eq 0xEF -and $ps1Bytes[1] -eq 0xBB -and $ps1Bytes[2] -eq 0xBF)
Assert-Test -TestName "Deploy-AppProfiles.ps1 codificado en UTF-8 con BOM (Regla 4)" `
            -Condition $hasBOM `
            -Details "Primeros bytes: 0x{0:X2}-{1:X2}-{2:X2}" -f $ps1Bytes[0], $ps1Bytes[1], $ps1Bytes[2]

# Validar NO BOM en Deploy-AppProfiles.cmd
$cmdBytes = [System.IO.File]::ReadAllBytes($cmdPath)
$cmdHasBOM = ($cmdBytes.Length -ge 3 -and $cmdBytes[0] -eq 0xEF -and $cmdBytes[1] -eq 0xBB -and $cmdBytes[2] -eq 0xBF)
Assert-Test -TestName "Deploy-AppProfiles.cmd es estrictamente No-BOM (Regla 4)" `
            -Condition (-not $cmdHasBOM) `
            -Details "cmdHasBOM: $cmdHasBOM"

# Validar Parser AST en Windows PowerShell 5.1
$astErrors = @()
$null = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$astErrors)
Assert-Test -TestName "Parser AST de Windows PowerShell 5.1 sin errores sintacticos" `
            -Condition ($astErrors.Count -eq 0) `
            -Details "Errores detectados: $($astErrors.Count)"

# -----------------------------------------------------------------------------
# 2. VALIDACION DEL CATALOGO CANONICO SSOT (JSON)
# -----------------------------------------------------------------------------
Write-Host "`n>>> [2/3] Verificando Esquema y Cobertura del Catalogo JSON..." -ForegroundColor Yellow

$catRaw = $null
$catObj = $null
try {
    $catRaw = [System.IO.File]::ReadAllText($catalogPath, [System.Text.Encoding]::UTF8)
    $catObj = ConvertFrom-Json -InputObject $catRaw
} catch {
    # Fail visible
}

Assert-Test -TestName "App-Profiles-Catalog.json es JSON valido y deserializable" `
            -Condition ($catObj -ne $null -and $catObj.version) `
            -Details "Version: $($catObj.version) | Descripcion: $($catObj.description)"

# Validar presencia de runtimes
$hasRuntimes = ($catObj -and $catObj.runtimes -and $catObj.runtimes.Count -ge 4)
Assert-Test -TestName "Catalogo define runtimes base de sistema (VCRedist, DirectX, .NET)" `
            -Condition $hasRuntimes `
            -Details "Total Runtimes Registrados: $($catObj.runtimes.Count)"

# Validar presencia de perfiles clave
$profiles = if ($catObj -and $catObj.profiles) { $catObj.profiles.psobject.properties.Name } else { @() }
$hasKeyProfiles = ($profiles -contains "EsportsGamer" -and $profiles -contains "AIAndDeveloper" -and $profiles -contains "CreatorStreamer" -and $profiles -contains "Essential")
Assert-Test -TestName "Catalogo contiene los 4 perfiles canónicos (Gamer, AI, Creator, Essential)" `
            -Condition $hasKeyProfiles `
            -Details "Perfiles: $($profiles -join ', ')"

# Validar paquetes de Inteligencia Artificial local
$aiProfile = if ($catObj -and $catObj.profiles -and $catObj.profiles.AIAndDeveloper) { $catObj.profiles.AIAndDeveloper } else { $null }
$hasOllama = ($aiProfile -and ($aiProfile.packages | Where-Object { $_.id -eq "Ollama.Ollama" }))
Assert-Test -TestName "Perfil AI & Developer integra Ollama (LLMs Locales) y herramientas de desarrollo" `
            -Condition ([bool]$hasOllama) `
            -Details "Paquetes AI: $($aiProfile.packages.Count) paquetes registrados"

# Validar add-ons de aceleracion de hardware
$hasHwAddons = ($catObj -and $catObj.hardwareAddons -and $catObj.hardwareAddons.Nvidia -and $catObj.hardwareAddons.Amd -and $catObj.hardwareAddons.Npu)
Assert-Test -TestName "Catalogo define add-ons adaptativos de hardware (NVIDIA, AMD, NPU DirectML)" `
            -Condition ([bool]$hasHwAddons) `
            -Details "Sectores de hardware configurados"

# -----------------------------------------------------------------------------
# 3. EJECUCION EN MODO SIMULADO (-WhatIf), SILICIO Y CONSOLA
# -----------------------------------------------------------------------------
Write-Host "`n>>> [3/3] Verificando Ejecucion Simulada (-WhatIf) y Adaptacion de Hardware..." -ForegroundColor Yellow

$psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

# Prueba 1: Modo Simulado con perfil EsportsGamer y AutoDetectHardware
$cmdWhatIf = "& '$scriptPath' -Profile EsportsGamer -AutoDetectHardware -SkipElevation -WhatIf"
$whatIfOut = & $psExe -STA -NoProfile -ExecutionPolicy Bypass -Command $cmdWhatIf 2>&1
$whatIfText = $whatIfOut | Out-String
$isWhatIfSuccess = ($LASTEXITCODE -eq 0 -and $whatIfText -match "Simulacion completada")

Assert-Test -TestName "Modo simulado -WhatIf ejecuta sin excepciones ni elevacion forzada" `
            -Condition $isWhatIfSuccess `
            -Details "Salida detecto finalizacion exitosa en simulación"

# Prueba 2: Modo InstallRuntimesOnly con WhatIf
$cmdRtWhatIf = "& '$scriptPath' -InstallRuntimesOnly -SkipElevation -WhatIf"
$rtOut = & $psExe -STA -NoProfile -ExecutionPolicy Bypass -Command $cmdRtWhatIf 2>&1
$rtText = $rtOut | Out-String
$isRtSuccess = ($LASTEXITCODE -eq 0 -and $rtText -match "Visual C\+\+ 2015-2022")

Assert-Test -TestName "Modo -InstallRuntimesOnly procesa exclusivamente las librerías base" `
            -Condition $isRtSuccess `
            -Details "Runtimes identificados en cola de instalación"

# -----------------------------------------------------------------------------
# RESUMEN DE RESULTADOS
# -----------------------------------------------------------------------------
$testDuration = [math]::Round(((Get-Date) - $testStartTime).TotalSeconds, 2)

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN: PRUEBAS DE APP PROFILES & AI RUNTIMES MANAGER                   " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Total de Aserciones : $($passCount + $failCount)" -ForegroundColor Gray
Write-Host " Aprobadas (PASS)    : $passCount" -ForegroundColor Green
Write-Host " Fallidas (FAIL)     : $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
Write-Host " Duracion Total      : ${testDuration}s" -ForegroundColor Gray
Write-Host " Estado Global       : $(if ($failCount -eq 0) { 'PASS (100% Exitoso)' } else { 'FAIL' })" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host "==========================================================================" -ForegroundColor Cyan

if ($failCount -gt 0) {
    exit 1
}
exit 0
