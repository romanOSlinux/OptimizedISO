<#
    .SYNOPSIS
        Test-WinUtilIntegration.ps1 - Suite de Pruebas de Integración (Fase 2: Inspiración WinUtil - PLAN-0117)
    .DESCRIPTION
        Valida rigurosamente la Fuente Única de Verdad (SSOT) de DNS en Policy-Engine.ps1,
        las funciones de diagnóstico, conmutación y medición RTT de latencia en Win11-Network-Diagnostics-Optimizer.ps1,
        y la compatibilidad de ejecución en frío sobre Windows PowerShell 5.1 (Reglas 4, 13 y 14).
#>

[CmdletBinding()]
param(
    [switch]$Detailed
)

$script:TotalTests = 0
$script:PassTests  = 0
$script:FailTests  = 0

function Assert-Test {
    param(
        [string]$Description,
        [bool]$Condition,
        [string]$Details = ""
    )
    $script:TotalTests++
    if ($Condition) {
        $script:PassTests++
        Write-Host "  [PASS] $Description" -ForegroundColor Green
        if ($Details -and $Detailed) { Write-Host "         $Details" -ForegroundColor Gray }
    } else {
        $script:FailTests++
        Write-Host "  [FAIL] $Description" -ForegroundColor Red
        if ($Details) { Write-Host "         DETALLE: $Details" -ForegroundColor Yellow }
    }
}

Write-Host "==========================================================================" -ForegroundColor Magenta
Write-Host " romanOS — PRUEBAS DE INTEGRACIÓN: FASE 2 WINUTIL (PLAN-0117)             " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Magenta
Write-Host " Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Runtime: Windows PowerShell $($PSVersionTable.PSVersion)`n" -ForegroundColor Gray

# ----------------------------------------------------------------------
# 1. CODIFICACIÓN Y SINTAXIS AST (Regla 4)
# ----------------------------------------------------------------------
Write-Host ">>> [1/4] Verificando Encodings y Sintaxis AST..." -ForegroundColor Yellow

$peFile = "$PSScriptRoot\..\Core\Policy-Engine.ps1"
$netFile = "$PSScriptRoot\..\Modules\Win11-Network-Diagnostics-Optimizer.ps1"
$deployFile = "$PSScriptRoot\..\Modules\Deploy-AppProfiles.ps1"
$catFile = "$PSScriptRoot\..\Core\App-Profiles-Catalog.json"

Assert-Test -Description "Existencia de Policy-Engine.ps1" -Condition (Test-Path $peFile)
Assert-Test -Description "Existencia de Win11-Network-Diagnostics-Optimizer.ps1" -Condition (Test-Path $netFile)
Assert-Test -Description "Existencia de Deploy-AppProfiles.ps1" -Condition (Test-Path $deployFile)
Assert-Test -Description "Existencia de App-Profiles-Catalog.json" -Condition (Test-Path $catFile)

$peBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $peFile).Path)
$hasPeBOM = ($peBytes.Count -ge 3 -and $peBytes[0] -eq 0xEF -and $peBytes[1] -eq 0xBB -and $peBytes[2] -eq 0xBF)
Assert-Test -Description "Policy-Engine.ps1 codificado en UTF-8 con BOM (Regla 4)" -Condition $hasPeBOM

$netBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $netFile).Path)
$hasNetBOM = ($netBytes.Count -ge 3 -and $netBytes[0] -eq 0xEF -and $netBytes[1] -eq 0xBB -and $netBytes[2] -eq 0xBF)
Assert-Test -Description "Win11-Network-Diagnostics-Optimizer.ps1 codificado en UTF-8 con BOM (Regla 4)" -Condition $hasNetBOM

$deployBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $deployFile).Path)
$hasDeployBOM = ($deployBytes.Count -ge 3 -and $deployBytes[0] -eq 0xEF -and $deployBytes[1] -eq 0xBB -and $deployBytes[2] -eq 0xBF)
Assert-Test -Description "Deploy-AppProfiles.ps1 codificado en UTF-8 con BOM (Regla 4)" -Condition $hasDeployBOM

$tokens = $null; $errors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $peFile).Path, [ref]$tokens, [ref]$errors) | Out-Null
Assert-Test -Description "Parser AST de Policy-Engine.ps1 sin errores sintácticos" -Condition ($errors.Count -eq 0) -Details "Errores: $($errors.Count)"

$tokens = $null; $errors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $netFile).Path, [ref]$tokens, [ref]$errors) | Out-Null
Assert-Test -Description "Parser AST de Win11-Network-Diagnostics-Optimizer.ps1 sin errores sintácticos" -Condition ($errors.Count -eq 0) -Details "Errores: $($errors.Count)"

$tokens = $null; $errors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $deployFile).Path, [ref]$tokens, [ref]$errors) | Out-Null
Assert-Test -Description "Parser AST de Deploy-AppProfiles.ps1 sin errores sintácticos" -Condition ($errors.Count -eq 0) -Details "Errores: $($errors.Count)"

# ----------------------------------------------------------------------
# 2. MOTOR CANÓNICO DE DNS EN POLICY-ENGINE (SSOT)
# ----------------------------------------------------------------------
Write-Host "`n>>> [2/4] Verificando SSOT de Perfiles DNS (Policy-Engine.ps1)..." -ForegroundColor Yellow

. (Resolve-Path $peFile).Path

$profiles = Get-RomanOSDnsProfiles
Assert-Test -Description "Get-RomanOSDnsProfiles retorna colección de perfiles canónicos" -Condition ($profiles -and $profiles.Count -ge 5) -Details "Total perfiles: $($profiles.Count)"

$expectedIds = @("Cloudflare", "Quad9", "Google", "AdGuard", "DHCP")
$idsInProfiles = $profiles | ForEach-Object { $_.Id }
$hasAllExpected = ($expectedIds | Where-Object { $_ -notin $idsInProfiles }).Count -eq 0
Assert-Test -Description "Contiene los 5 proveedores clave (Cloudflare, Quad9, Google, AdGuard, DHCP)" -Condition $hasAllExpected

$cf = Get-RomanOSDnsProfileById -Id "Cloudflare"
Assert-Test -Description "Lookup por ID de Cloudflare retorna datos IPv4 y DoH válidos" -Condition ($cf -and $cf.PrimaryIPv4 -eq "1.1.1.1" -and $cf.SupportsDoH -and $cf.DoHTemplate -like "*cloudflare*")

$q9 = Get-RomanOSDnsProfileById -Id "Quad9"
Assert-Test -Description "Lookup por ID de Quad9 retorna datos IPv4 y DoH de seguridad válidos" -Condition ($q9 -and $q9.PrimaryIPv4 -eq "9.9.9.9" -and $q9.SupportsDoH -and $q9.DoHTemplate -like "*quad9*")

# ----------------------------------------------------------------------
# 3. CONMUTACIÓN, LATENCIA RTT Y MOCKS EN MÓDULO DE RED
# ----------------------------------------------------------------------
Write-Host "`n>>> [3/4] Verificando Diagnóstico y Conmutación de DNS..." -ForegroundColor Yellow

. (Resolve-Path $netFile).Path

$adapters = @(Get-RomanOSActiveNetworkAdapters)
Assert-Test -Description "Get-RomanOSActiveNetworkAdapters detecta adaptadores de red" -Condition ($adapters.Count -gt 0) -Details "Adaptadores: $($adapters.Count)"

$currentDns = @(Get-RomanOSCurrentDns)
Assert-Test -Description "Get-RomanOSCurrentDns consulta configuración y asocia perfil" -Condition ($currentDns.Count -gt 0)

# Medición RTT rápida (1 muestra, timeout 500ms)
$rttBenchmark = @(Test-RomanOSDnsLatency -ProfileIds @("Google", "Cloudflare") -Samples 1 -TimeoutMs 500)
Assert-Test -Description "Test-RomanOSDnsLatency ejecuta sondeos y reporta latencias numéricas" -Condition ($rttBenchmark.Count -eq 2)

$hasRecommended = (@($rttBenchmark | Where-Object { $_.Recommended -eq $true })).Count -ge 1
Assert-Test -Description "Test-RomanOSDnsLatency asigna automáticamente recomendación por menor latencia" -Condition $hasRecommended

# Validación en modo simulado (-WhatIf) de Set-RomanOSDnsServer
$setWhatIf = Set-RomanOSDnsServer -ProfileId "Cloudflare" -Quiet -WhatIf
Assert-Test -Description "Set-RomanOSDnsServer ejecuta limpiamente en modo simulado (-WhatIf)" -Condition ($setWhatIf -eq $true)

$resetWhatIf = Reset-RomanOSDnsServer -Quiet -WhatIf
Assert-Test -Description "Reset-RomanOSDnsServer ejecuta limpiamente en modo simulado (-WhatIf)" -Condition ($resetWhatIf -eq $true)

# ----------------------------------------------------------------------
# 4. GESTOR DE SOFTWARE Y CATÁLOGO CURADO (WINGET ENGINE)
# ----------------------------------------------------------------------
Write-Host "`n>>> [4/4] Verificando Gestor de Software y Catálogo Curado..." -ForegroundColor Yellow

. (Resolve-Path $deployFile).Path

$cat = Get-RomanOSAppCatalog -Path (Resolve-Path $catFile).Path
Assert-Test -Description "Get-RomanOSAppCatalog deserializa exitosamente el catálogo JSON" -Condition ($null -ne $cat -and $cat.version -ne $null)

Assert-Test -Description "Catálogo contiene categorías estructuradas (Browsers, Gaming, Development, Utilities)" -Condition ($null -ne $cat.categories -and $cat.categories.Browsers -and $cat.categories.Gaming -and $cat.categories.Development -and $cat.categories.Utilities)

$browsers = @(Get-RomanOSAppsByCategory -CategoryName "Browsers" -Path (Resolve-Path $catFile).Path)
Assert-Test -Description "Get-RomanOSAppsByCategory retorna navegadores curados (Brave, Firefox, Chrome, LibreWolf)" -Condition ($browsers.Count -ge 4 -and ($browsers | Where-Object { $_.id -eq "Brave.Brave" }))

$gaming = @(Get-RomanOSAppsByCategory -CategoryName "Gaming" -Path (Resolve-Path $catFile).Path)
Assert-Test -Description "Get-RomanOSAppsByCategory retorna suite gamer curada (Steam, Epic, Discord, OBS)" -Condition ($gaming.Count -ge 4 -and ($gaming | Where-Object { $_.id -eq "Valve.Steam" }))

$dev = @(Get-RomanOSAppsByCategory -CategoryName "Development" -Path (Resolve-Path $catFile).Path)
Assert-Test -Description "Get-RomanOSAppsByCategory retorna suite dev curada (Git, VS Code, Node, Python)" -Condition ($dev.Count -ge 4 -and ($dev | Where-Object { $_.id -eq "Git.Git" }))

$utils = @(Get-RomanOSAppsByCategory -CategoryName "Utilities" -Path (Resolve-Path $catFile).Path)
Assert-Test -Description "Get-RomanOSAppsByCategory retorna utilidades esenciales (7-Zip, Notepad++, Everything, CPU-Z)" -Condition ($utils.Count -ge 4 -and ($utils | Where-Object { $_.id -eq "7zip.7zip" }))

# Simulación de despliegue por categoría con -WhatIf
$simDeploy = & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & '$((Resolve-Path $deployFile).Path)' -Categories Browsers -WhatIf -SkipElevation }"
$simSuccess = ($LASTEXITCODE -eq 0 -and $simDeploy -match "Simulacion completada")
Assert-Test -Description "Deploy-AppProfiles.ps1 ejecuta simulación por categoría exitosamente (-WhatIf)" -Condition $simSuccess

# Listado de catálogo interactivo sin privilegios
$listCatalogOutput = & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & '$((Resolve-Path $deployFile).Path)' -ListCatalog }"
$listSuccess = ($LASTEXITCODE -eq 0 -and $listCatalogOutput -match "CATEGORIAS DE SOFTWARE DISPONIBLES")
Assert-Test -Description "Deploy-AppProfiles.ps1 -ListCatalog lista catálogo sin elevación" -Condition $listSuccess

# ----------------------------------------------------------------------
# RESUMEN DE PRUEBAS
# ----------------------------------------------------------------------
Write-Host "`n==========================================================================" -ForegroundColor Magenta
Write-Host " RESUMEN: PRUEBAS DE INTEGRACIÓN WINUTIL (PLAN-0117)                       " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Magenta
Write-Host " Total de Aserciones : $script:TotalTests"
Write-Host " Aprobadas (PASS)    : $script:PassTests" -ForegroundColor Green
Write-Host " Fallidas (FAIL)     : $script:FailTests" -ForegroundColor $(if ($script:FailTests -eq 0) { "Green" } else { "Red" })

if ($script:FailTests -eq 0) {
    Write-Host " Estado Global       : PASS (100% Exitoso)`n" -ForegroundColor Green
    exit 0
} else {
    Write-Host " Estado Global       : FAIL ($script:FailTests fallos)`n" -ForegroundColor Red
    exit 1
}
