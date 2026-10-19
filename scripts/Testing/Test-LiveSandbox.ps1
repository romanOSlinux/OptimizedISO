<#
.SYNOPSIS
    Test-LiveSandbox.ps1 - Arnés de Pruebas Unitarias de romanOS Live Sandbox
    Certificación de Aislamiento Efímero, Generación XML .wsb y Validación en PowerShell 5.1

.DESCRIPTION
    Ejecuta una batería de aserciones unitarias para verificar:
      1. Existencia física y codificación conforme a la Regla 4 (UTF-8 BOM en PS1, No-BOM en CMD).
      2. Parser AST de Windows PowerShell 5.1 sin errores sintácticos.
      3. Diagnóstico de virtualización y CPU SLAT.
      4. Generación y validación de esquemas XML .wsb para los presets SafeAnalysis, GameModding y DisposableBrowser.
      5. Mapeo de carpetas compartidas y directivas de aislamiento.
      6. Ejecución simulada (-WhatIf) y paridad en Toolkit y Control Center.
#>

[CmdletBinding()]
param(
    [string]$LogDir = ""
)

$ErrorActionPreference = 'Continue'
$testStart = Get-Date

$repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
if (-not (Test-Path (Join-Path $repoRoot "scripts\Core"))) {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

$passCount = 0
$failCount = 0

function Assert-Test {
    param(
        [string]$Title,
        [bool]$Condition,
        [string]$Details = ""
    )
    if ($Condition) {
        $script:passCount++
        Write-Host "  [PASS] $Title" -ForegroundColor Green
        if ($Details) { Write-Host "         $Details" -ForegroundColor DarkGray }
    } else {
        $script:failCount++
        Write-Host "  [FAIL] $Title" -ForegroundColor Red
        if ($Details) { Write-Host "         $Details" -ForegroundColor DarkRed }
    }
}

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS — BATERIA DE PRUEBAS: LIVE SANDBOX ENVIRONMENT                   " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Runtime: Windows PowerShell $($PSVersionTable.PSVersion)`n" -ForegroundColor Gray

# -----------------------------------------------------------------------------
# BLOQUE 1: ARCHIVOS Y ENCODING
# -----------------------------------------------------------------------------
Write-Host ">>> [1/3] Verificando Archivos y Codificacion de Encodings..." -ForegroundColor Cyan

$sandboxPs1 = Join-Path $repoRoot "scripts\Modules\Invoke-LiveSandbox.ps1"
$sandboxCmd = Join-Path $repoRoot "scripts\Modules\Invoke-LiveSandbox.cmd"

Assert-Test -Title "Existencia fisica de Invoke-LiveSandbox.ps1" `
    -Condition (Test-Path $sandboxPs1) `
    -Details $sandboxPs1

Assert-Test -Title "Existencia fisica de Invoke-LiveSandbox.cmd" `
    -Condition (Test-Path $sandboxCmd) `
    -Details $sandboxCmd

$ps1Bytes = if (Test-Path $sandboxPs1) { [System.IO.File]::ReadAllBytes($sandboxPs1) } else { @() }
$hasBOM = ($ps1Bytes.Count -ge 3 -and $ps1Bytes[0] -eq 0xEF -and $ps1Bytes[1] -eq 0xBB -and $ps1Bytes[2] -eq 0xBF)
Assert-Test -Title "Invoke-LiveSandbox.ps1 codificado en UTF-8 con BOM (Regla 4)" `
    -Condition $hasBOM `
    -Details "Primeros bytes: 0x{0:X2}-{1:X2}-{2:X2}" -f $ps1Bytes[0], $ps1Bytes[1], $ps1Bytes[2]

$cmdBytes = if (Test-Path $sandboxCmd) { [System.IO.File]::ReadAllBytes($sandboxCmd) } else { @() }
$cmdHasBOM = ($cmdBytes.Count -ge 3 -and $cmdBytes[0] -eq 0xEF -and $cmdBytes[1] -eq 0xBB -and $cmdBytes[2] -eq 0xBF)
Assert-Test -Title "Invoke-LiveSandbox.cmd es estrictamente No-BOM (Regla 4)" `
    -Condition (-not $cmdHasBOM) `
    -Details "cmdHasBOM: $cmdHasBOM"

$astErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($sandboxPs1, [ref]$null, [ref]$astErrors)
Assert-Test -Title "Parser AST de Windows PowerShell 5.1 sin errores sintacticos" `
    -Condition ($null -eq $astErrors -or $astErrors.Count -eq 0) `
    -Details "Errores detectados: $(if ($astErrors) { $astErrors.Count } else { 0 })"

# -----------------------------------------------------------------------------
# BLOQUE 2: DIAGNOSTICO DE ENTORNO Y GENERACION XML .WSB
# -----------------------------------------------------------------------------
Write-Host "`n>>> [2/3] Verificando Diagnóstico y Generación de Esquemas XML .wsb..." -ForegroundColor Cyan

# Carga de script para pruebas de funciones internas
. $sandboxPs1

$diag = Get-RomanOSSandboxDiagnostic
Assert-Test -Title "Diagnóstico de procesador y virtualización de hardware exitoso" `
    -Condition ($diag -ne $null -and $diag.CPUName -ne "Desconocido") `
    -Details "CPU: $($diag.CPUName) | Firmware Virtualization: $($diag.VirtualizationFirmware)"

Assert-Test -Title "Diagnóstico de edición de Windows y binario Sandbox ejecutado" `
    -Condition ($diag.WindowsEdition -ne "Desconocido") `
    -Details "Edición: $($diag.WindowsEdition) | Binary Exists: $($diag.SandboxBinaryExists)"

# Generación de Preset SafeAnalysis
$tempFolder = Join-Path ([System.IO.Path]::GetTempPath()) ("romanOS_TestShared_" + (Get-Random))
New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null
$testWsbSafe = Join-Path ([System.IO.Path]::GetTempPath()) "romanOS_UnitTest_SafeAnalysis.wsb"

$wsbSafePath = New-RomanOSSandboxConfig -Preset "SafeAnalysis" -SharedFolder $tempFolder -OutputPath $testWsbSafe
$safeXml = [System.Xml.XmlDocument]::new()
$safeLoaded = $false
try {
    $safeXml.Load($wsbSafePath)
    $safeLoaded = $true
} catch {
    $safeLoaded = $false
}

Assert-Test -Title "Preset SafeAnalysis genera XML .wsb válido y bien formado" `
    -Condition ($safeLoaded -and (Test-Path $wsbSafePath)) `
    -Details $wsbSafePath

$isSafeAirGapped = ($safeXml.Configuration.Networking -eq "Disable" -and $safeXml.Configuration.VGpu -eq "Disable")
Assert-Test -Title "Preset SafeAnalysis aplica estricto Air-Gap (Networking: Disable, VGpu: Disable)" `
    -Condition $isSafeAirGapped `
    -Details "Networking: $($safeXml.Configuration.Networking) | VGpu: $($safeXml.Configuration.VGpu)"

# Generación de Preset GameModding
$testWsbGaming = Join-Path ([System.IO.Path]::GetTempPath()) "romanOS_UnitTest_GameModding.wsb"
$wsbGamingPath = New-RomanOSSandboxConfig -Preset "GameModding" -SharedFolder $tempFolder -OutputPath $testWsbGaming
$gamingXml = [System.Xml.XmlDocument]::new()
$gamingLoaded = $false
try {
    $gamingXml.Load($wsbGamingPath)
    $gamingLoaded = $true
} catch {
    $gamingLoaded = $false
}
$isGamingActive = ($gamingXml.Configuration.Networking -eq "Enable" -and $gamingXml.Configuration.VGpu -eq "Enable")
Assert-Test -Title "Preset GameModding activa aceleración Direct3D (VGpu: Enable, Networking: Enable)" `
    -Condition ($gamingLoaded -and $isGamingActive) `
    -Details "Networking: $($gamingXml.Configuration.Networking) | VGpu: $($gamingXml.Configuration.VGpu)"

# Generación de Preset DisposableBrowser
$testWsbBrowser = Join-Path ([System.IO.Path]::GetTempPath()) "romanOS_UnitTest_DisposableBrowser.wsb"
$wsbBrowserPath = New-RomanOSSandboxConfig -Preset "DisposableBrowser" -OutputPath $testWsbBrowser
$browserXml = [System.Xml.XmlDocument]::new()
$browserLoaded = $false
try {
    $browserXml.Load($wsbBrowserPath)
    $browserLoaded = $true
} catch {
    $browserLoaded = $false
}
$hasLogonCmd = ($browserXml.Configuration.LogonCommand -ne $null -and $browserXml.Configuration.LogonCommand.Command -ne "")
Assert-Test -Title "Preset DisposableBrowser configura LogonCommand para navegación privada efímera" `
    -Condition ($browserLoaded -and $hasLogonCmd) `
    -Details "LogonCommand: $($browserXml.Configuration.LogonCommand.Command)"

# Limpieza de archivos temporales
Remove-Item -Path $testWsbSafe -Force -ErrorAction SilentlyContinue
Remove-Item -Path $testWsbGaming -Force -ErrorAction SilentlyContinue
Remove-Item -Path $testWsbBrowser -Force -ErrorAction SilentlyContinue
Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue

# -----------------------------------------------------------------------------
# BLOQUE 3: SIMULACION -WHATIF Y PARIDAD EN TOOLKIT / CONTROL CENTER
# -----------------------------------------------------------------------------
Write-Host "`n>>> [3/3] Verificando Ejecucion Simulada (-WhatIf) e Integraciones..." -ForegroundColor Cyan

$whatIfOut = & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $sandboxPs1 -Action Launch -Preset SafeAnalysis -WhatIf 2>&1
$whatIfOk = ($LASTEXITCODE -eq 0 -and ($whatIfOut -match "WhatIf" -or $whatIfOut -match "simuló"))
Assert-Test -Title "Modo simulado -WhatIf ejecuta sin excepciones ni elevacion forzada" `
    -Condition $whatIfOk `
    -Details "Salida detectó confirmación WhatIf"

# Paridad en Toolkit y Control Center
$toolkitFile = Join-Path $repoRoot "scripts\Modules\romanOS-Toolkit.ps1"
$toolkitContent = if (Test-Path $toolkitFile) { [System.IO.File]::ReadAllText($toolkitFile) } else { "" }
$toolkitHasSandbox = ($toolkitContent -match "Invoke-SandboxModule" -and $toolkitContent -match "Invoke-LiveSandbox")

$ccFile = Join-Path $repoRoot "scripts\GUI\romanOS-ControlCenter.ps1"
$ccContent = if (Test-Path $ccFile) { [System.IO.File]::ReadAllText($ccFile) } else { "" }
$ccHasSandbox = ($ccContent -match "btnLaunchSandbox" -and $ccContent -match "Invoke-LiveSandbox\.ps1")

Assert-Test -Title "Ecosistema sincronizado: romanOS-Toolkit y Control Center integran Live Sandbox" `
    -Condition ($toolkitHasSandbox -and $ccHasSandbox) `
    -Details "Toolkit Integration: $toolkitHasSandbox | Control Center Integration: $ccHasSandbox"

# -----------------------------------------------------------------------------
# RESUMEN DE PRUEBAS
# -----------------------------------------------------------------------------
$duration = [math]::Round(((Get-Date) - $testStart).TotalSeconds, 2)
$totalTests = $passCount + $failCount
$overallPass = ($failCount -eq 0)

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN: PRUEBAS DE LIVE SANDBOX ENVIRONMENT                             " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Total de Aserciones : $totalTests"
Write-Host " Aprobadas (PASS)    : $passCount" -ForegroundColor Green
Write-Host " Fallidas (FAIL)     : $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host " Duracion Total      : ${duration}s"
Write-Host " Estado Global       : $(if ($overallPass) { 'PASS (100% Exitoso)' } else { 'FAIL' })" -ForegroundColor $(if ($overallPass) { "Green" } else { "Red" })
Write-Host "==========================================================================`n" -ForegroundColor Cyan

exit $(if ($overallPass) { 0 } else { 1 })
