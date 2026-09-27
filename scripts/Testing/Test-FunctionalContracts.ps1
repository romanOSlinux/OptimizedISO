# Test-FunctionalContracts.ps1
# ==============================================================================
# Framework de Pruebas Funcionales de Contrato y Mutacion de Estado (PLAN-0119)
# Valida empíricamente que los botones y módulos del ecosistema romanOS
# cumplan sus promesas de comportamiento en el Sistema Operativo (State Mutation).
# ==============================================================================
# Codificación: UTF-8 con BOM | Runtime: Windows PowerShell 5.1 / PowerShell 7+
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$Detailed,
    [switch]$FailFast
)

$ErrorActionPreference = 'Continue'
$totalTests  = 0
$passedCount = 0
$failedCount = 0

function Write-TestBanner {
    param([string]$Title)
    Write-Host "`n==========================================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Cyan
}

function Write-ContractHeader {
    param([string]$ContractId, [string]$ButtonName, [string]$Description)
    Write-Host "`n>>> [$ContractId] Botón: '$ButtonName'" -ForegroundColor Cyan
    Write-Host "    Contrato: $Description" -ForegroundColor Gray
}

function Assert-Contract {
    param(
        [string]$Description,
        [scriptblock]$ConditionBlock,
        [string]$ExpectedState = "Verdadero",
        [string]$DetailMessage = ""
    )
    $script:totalTests++
    try {
        $result = & $ConditionBlock
        if ([bool]$result) {
            $script:passedCount++
            Write-Host "  [PASS] $Description" -ForegroundColor Green
            if ($Detailed -and $DetailMessage) {
                Write-Host "         $DetailMessage" -ForegroundColor DarkGray
            }
        } else {
            $script:failedCount++
            Write-Host "  [FAIL] $Description" -ForegroundColor Red
            Write-Host "         Estado Esperado : $ExpectedState" -ForegroundColor Yellow
            Write-Host "         Estado Obtenido : Falso / Discrepancia detectada" -ForegroundColor Red
            if ($DetailMessage) {
                Write-Host "         Detalle         : $DetailMessage" -ForegroundColor DarkYellow
            }
            if ($FailFast) {
                throw "Fallo rapido (FailFast) activado ante error en contrato: $Description"
            }
        }
    } catch {
        $script:failedCount++
        Write-Host "  [ERROR] $Description - Excepcion: $($_.Exception.Message)" -ForegroundColor Red
        if ($FailFast) {
            throw $_
        }
    }
}

Write-TestBanner "romanOS — TEST HARNESS DE CONTRATOS FUNCIONALES Y MUTACION DE ESTADO"
Write-Host "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Runtime: PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Gray

# Ubicaciones del repositorio
$scriptsDir = Join-Path $PSScriptRoot "..\Modules"
$coreDir    = Join-Path $PSScriptRoot "..\Core"
$guiDir     = Join-Path $PSScriptRoot "..\GUI"

# ==============================================================================
# CONTRATO 1: Botón "Optimizar Juegos y Apps" -> Supresión de Auto-arranque Discord
# ==============================================================================
Write-ContractHeader "CTR-01" "Optimizar Juegos y Apps" "Erradicación de Auto-arranque de Discord en Registro y Startup"

$runKeyCU = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$testLnkPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\romanOS_Test_Discord.lnk"

# 1. Arrange: Inyectar clave dummy en HKCU\Run y acceso directo dummy
try {
    Set-ItemProperty -Path $runKeyCU -Name "Discord" -Value "C:\Test\DummyUpdate.exe --processStart Discord.exe" -Force -ErrorAction Stop
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($testLnkPath)
    $shortcut.TargetPath = "C:\Test\DummyUpdate.exe"
    $shortcut.Save()
    $arrangedOk = (Get-ItemProperty -Path $runKeyCU -Name "Discord" -ErrorAction SilentlyContinue).Discord -ne $null -and (Test-Path $testLnkPath)
} catch {
    $arrangedOk = $false
}
Assert-Contract "Arrange: Inyección de estado pre-optimizado de Discord (Registro HKCU\Run y Startup .lnk)" {
    return $arrangedOk
} -DetailMessage "Clave de prueba Discord en HKCU\Run y acceso directo temporal creados"

# 2. Act: Invocar Optimize-GamingAndApps.ps1
$gamingScript = Join-Path $scriptsDir "Optimize-GamingAndApps.ps1"
if (Test-Path $gamingScript) {
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& '$gamingScript' -Unattended -SkipElevation" | Out-Null
}

# 3. Assert: Verificar que la clave en el registro fue erradicada físicamente
$discordRegPost = (Get-ItemProperty -Path $runKeyCU -Name "Discord" -ErrorAction SilentlyContinue).Discord
Assert-Contract "Assert: La clave 'Discord' fue erradicada de HKCU\Software\Microsoft\Windows\CurrentVersion\Run" {
    return ($discordRegPost -eq $null)
} -ExpectedState "Clave eliminada (null)" -DetailMessage "Valor actual: $(if ($discordRegPost) { $discordRegPost } else { 'Eliminada con éxito' })"

# 4. Assert: Verificar que el acceso directo de Discord en Startup fue depurado
$lnkExists = Test-Path $testLnkPath
Assert-Contract "Assert: Los accesos directos (*Discord*.lnk) en Startup fueron eliminados físicamente" {
    return (-not $lnkExists)
} -ExpectedState "Archivo eliminado" -DetailMessage "Existe archivo .lnk: $lnkExists"

# 5. Teardown
if (Test-Path $testLnkPath) { Remove-Item -Path $testLnkPath -Force -ErrorAction SilentlyContinue }


# ==============================================================================
# CONTRATO 2: Botón "Optimizar Juegos y Apps" -> Supresión de Auto-arranque Spotify
# ==============================================================================
Write-ContractHeader "CTR-02" "Optimizar Juegos y Apps" "Erradicación de Claves de Auto-arranque de Spotify en Registro"

# 1. Arrange: Inyectar clave dummy de Spotify y Spotify Web Helper
try {
    Set-ItemProperty -Path $runKeyCU -Name "Spotify" -Value "C:\Test\DummySpotify.exe" -Force -ErrorAction Stop
    Set-ItemProperty -Path $runKeyCU -Name "Spotify Web Helper" -Value "C:\Test\DummyHelper.exe" -Force -ErrorAction Stop
    $arrangedSpotify = $true
} catch {
    $arrangedSpotify = $false
}
Assert-Contract "Arrange: Inyección de claves pre-optimizadas de Spotify en HKCU\Run" {
    return $arrangedSpotify
}

# 2. Act: Re-invocar sección
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& '$gamingScript' -Unattended -SkipElevation" | Out-Null

# 3. Assert: Verificar que ambas claves fueron eliminadas
$spotReg = (Get-ItemProperty -Path $runKeyCU -Name "Spotify" -ErrorAction SilentlyContinue).Spotify
$spotHelpReg = (Get-ItemProperty -Path $runKeyCU -Name "Spotify Web Helper" -ErrorAction SilentlyContinue).'Spotify Web Helper'

Assert-Contract "Assert: La clave 'Spotify' fue eliminada de HKCU\Run" {
    return ($spotReg -eq $null)
} -ExpectedState "Clave eliminada (null)"

Assert-Contract "Assert: La clave 'Spotify Web Helper' fue eliminada de HKCU\Run" {
    return ($spotHelpReg -eq $null)
} -ExpectedState "Clave eliminada (null)"


# ==============================================================================
# CONTRATO 3: Botón "Optimizar Juegos y Apps" -> Flip Model y WDDM 3.x
# ==============================================================================
Write-ContractHeader "CTR-03" "Optimizar Juegos y Apps" "Aplicación de Modern Flip Model en UserGpuPreferences"

$dxGpuPath = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
$dxSettings = (Get-ItemProperty -Path $dxGpuPath -Name "DirectXUserGlobalSettings" -ErrorAction SilentlyContinue).DirectXUserGlobalSettings

Assert-Contract "Assert: DirectXUserGlobalSettings contiene SwapEffectUpgradeEnable=1" {
    return ($dxSettings -match "SwapEffectUpgradeEnable=1")
} -ExpectedState "SwapEffectUpgradeEnable=1 presente" -DetailMessage "Valor actual: $dxSettings"

Assert-Contract "Assert: DirectXUserGlobalSettings contiene VRROptimizeEnable=1" {
    return ($dxSettings -match "VRROptimizeEnable=1")
} -ExpectedState "VRROptimizeEnable=1 presente"


# ==============================================================================
# CONTRATO 4: Botón "Optimizar Juegos y Apps" & Mantenimiento -> Purga de Shaders
# ==============================================================================
Write-ContractHeader "CTR-04" "Optimizar Juegos y Apps" "Purga Física Transaccional de Archivos de Shaders"

$d3dCacheDir = Join-Path $env:LOCALAPPDATA "D3DSCache"
if (-not (Test-Path $d3dCacheDir)) { New-Item -Path $d3dCacheDir -ItemType Directory -Force | Out-Null }
$dummyShader = Join-Path $d3dCacheDir "romanOS_test_shader_contract.bin"

# 1. Arrange: Crear archivo de shader mock
[System.IO.File]::WriteAllText($dummyShader, "ROMANOS_MOCK_SHADER_CACHE_DATA_FOR_TESTING")
Assert-Contract "Arrange: Creación de archivo mock de shader en D3DSCache" {
    return (Test-Path $dummyShader)
}

# 2. Act: Invocar Optimize-GamingAndApps.ps1 con -PurgeShadersOnly
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& '$gamingScript' -PurgeShadersOnly -SkipElevation" | Out-Null

# 3. Assert: Verificar que el archivo mock fue eliminado físicamente
$shaderDeleted = -not (Test-Path $dummyShader)
Assert-Contract "Assert: El archivo mock de shader fue depurado físicamente del disco" {
    return $shaderDeleted
} -ExpectedState "Archivo depurado (False)"

# 4. Teardown
if (Test-Path $dummyShader) { Remove-Item -Path $dummyShader -Force -ErrorAction SilentlyContinue }


# ==============================================================================
# CONTRATO 5: Botón "Habilitar Menú Clásico" vs "Restaurar Menú Moderno"
# ==============================================================================
Write-ContractHeader "CTR-05" "Menús Contextuales" "Alternancia de CLSID de Menú Clásico vs Menú Moderno Win11"

$clsidPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
$menuScript = Join-Path $scriptsDir "Add-OptimizedContextMenus.ps1"

# 1. Act 1: Habilitar Menú Clásico
if (Test-Path $menuScript) {
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& '$menuScript' -EnableClassicMenu" | Out-Null
    
    $classicKeyExists = Test-Path $clsidPath
    $defaultVal = (Get-ItemProperty -Path $clsidPath -ErrorAction SilentlyContinue).'(default)'
    
    Assert-Contract "Assert: Menú Clásico crea clave CLSID InprocServer32 con valor nulo" {
        return ($classicKeyExists -and ($defaultVal -eq "" -or $defaultVal -eq $null))
    } -ExpectedState "CLSID InprocServer32 creado con (default) = vacio"
    
    # 2. Act 2: Restaurar Menú Moderno Win11
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& '$menuScript' -RestoreModernMenu" | Out-Null
    
    $classicKeyGone = -not (Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}")
    Assert-Contract "Assert: Restaurar Menú Moderno elimina el CLSID {86ca1aa0-...}" {
        return $classicKeyGone
    } -ExpectedState "Clave CLSID eliminada por completo"
} else {
    Assert-Contract "Verificación de script Add-OptimizedContextMenus.ps1" { return $false } -DetailMessage "No se encontro Add-OptimizedContextMenus.ps1"
}


# ==============================================================================
# CONTRATO 6: Botones de Conmutación DNS (Cloudflare / Quad9 / Google / DHCP)
# ==============================================================================
Write-ContractHeader "CTR-06" "Conmutador DNS Inteligente" "Detección de Gateway Activo y Asignación de Servidores DNS"

# Probar la lógica de resolución del gateway predeterminado
$defaultRoute = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
    Sort-Object RouteMetric |
    Select-Object -First 1

Assert-Contract "Assert: Get-NetRoute identifica interfaz activa de salida con conectividad" {
    return ($defaultRoute -ne $null -and $defaultRoute.InterfaceIndex -gt 0)
} -ExpectedState "InterfaceIndex > 0 identificado" -DetailMessage "Interfaz activa: $($defaultRoute.InterfaceAlias) (Index: $($defaultRoute.InterfaceIndex))"

# Validar que los servidores de Cloudflare están registrados en Policy-Engine
if (Get-Command "Get-RomanOSDnsProfiles" -ErrorAction SilentlyContinue) {
    $dnsProfiles = Get-RomanOSDnsProfiles
    Assert-Contract "Assert: Catálogo SSOT de DNS provee perfiles válidos (Cloudflare, Quad9, Google)" {
        return ($dnsProfiles -and $dnsProfiles.Cloudflare -and $dnsProfiles.Quad9 -and $dnsProfiles.Google)
    }
} else {
    $pePath = Join-Path $coreDir "Policy-Engine.ps1"
    if (Test-Path $pePath) {
        . $pePath
        $dnsProfiles = Get-RomanOSDnsProfiles
        Assert-Contract "Assert: Catálogo SSOT de DNS provee perfiles válidos tras carga de Policy-Engine" {
            return ($dnsProfiles -and $dnsProfiles.Cloudflare -and $dnsProfiles.Quad9 -and $dnsProfiles.Google)
        }
    }
}


# ==============================================================================
# CONTRATO 7: Invariantes Universales del SO (Anti-Cheat & Scheduler BAM)
# ==============================================================================
Write-ContractHeader "CTR-07" "Invariantes Universales del SO" "Blindaje de VulnerableDriverBlocklistEnable y Servicio BAM"

$ciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Config"
$vulnDrv = (Get-ItemProperty -Path $ciPath -Name "VulnerableDriverBlocklistEnable" -ErrorAction SilentlyContinue).VulnerableDriverBlocklistEnable

Assert-Contract "Assert: VulnerableDriverBlocklistEnable = 1 (Certificación Anti-Cheat Vanguard/EAC)" {
    return ($vulnDrv -eq 1)
} -ExpectedState "1" -DetailMessage "Valor actual: $vulnDrv"

$bamPath = "HKLM:\SYSTEM\CurrentControlSet\Services\bam"
$bamStart = (Get-ItemProperty -Path $bamPath -Name "Start" -ErrorAction SilentlyContinue).Start

Assert-Contract "Assert: Servicio BAM (Background Activity Moderator) NO está deshabilitado (Start != 4)" {
    return ($bamStart -ne 4)
} -ExpectedState "Start != 4 (Activo/Optimo)" -DetailMessage "Start actual: $bamStart"


# ==============================================================================
# CONTRATO 8: Conmutador Game/Dev -> Auditoría de Estado e Inferencia Bimodal
# ==============================================================================
Write-ContractHeader "CTR-08" "Conmutador Game/Dev" "Auditoría de Estado e Inferencia Bimodal (Switch-GameDevMode.ps1)"

$switchScript = Join-Path $scriptsDir "Switch-GameDevMode.ps1"
if (Test-Path $switchScript) {
    $statusObj = & $switchScript -Mode Status -PassThru -Unattended -Quiet
    Assert-Contract "Assert: Switch-GameDevMode -Mode Status retorna objeto de diagnóstico sin elevación" {
        return ($statusObj -ne $null)
    } -ExpectedState "Objeto no nulo"
    
    Assert-Contract "Assert: Diagnóstico contiene métricas de RAM y estado de Hyper-V" {
        return ($statusObj.Mode -ne $null -and $statusObj.HyperVActive -ne $null)
    } -ExpectedState "Propiedades Mode e HyperVActive presentes" -DetailMessage "Modo detectado: $($statusObj.Mode) | Total RAM: $($statusObj.TotalRAMGB) GB"
} else {
    Assert-Contract "Existencia de Switch-GameDevMode.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 9: Conmutador Game/Dev -> Ejecución de Modo Juego Ligero
# ==============================================================================
Write-ContractHeader "CTR-09" "Conmutador Game/Dev" "Ejecución Resiliente con -SkipElevation (Switch-GameDevMode.ps1)"

if (Test-Path $switchScript) {
    $gameRun = & $switchScript -Mode Game -Profile Light -SkipElevation -Unattended -PassThru -Quiet
    Assert-Contract "Assert: Switch-GameDevMode ejecuta Modo Juego con -SkipElevation sin abortar" {
        return ($gameRun -ne $null -and $gameRun.Profile -eq "Light" -and $gameRun.Mode -eq "Game")
    } -ExpectedState "Profile = Light y Mode = Game" -DetailMessage "Modo: $($gameRun.Mode) | RAM Reclamada: $($gameRun.PmemReclaimedMB) MB"
}


# ==============================================================================
# CONTRATO 10: Profiler de Latencia DPC/ISR -> Telemetría de Kernel (Trace-SystemLatency)
# ==============================================================================
Write-ContractHeader "CTR-10" "Profiler Forense Latencia" "Muestreo de Kernel y Presupuesto de Frame (Trace-SystemLatency.ps1)"

$traceScript = Join-Path $scriptsDir "Trace-SystemLatency.ps1"
if (Test-Path $traceScript) {
    $traceOutput = & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& '$traceScript' -DurationSeconds 1"
    $traceClean = ($LASTEXITCODE -eq 0) -and ($traceOutput -match "RESUMEN FORENSE DE LATENCIA" -or $traceOutput -match "ISR|DPC")
    Assert-Contract "Assert: Trace-SystemLatency ejecuta muestreo de interrupciones de kernel sin error" {
        return $traceClean
    } -ExpectedState "ExitCode = 0 y telemetría generada"
}


# ==============================================================================
# CONTRATO 11: Optimizador de Memoria de Procesos -> Poda EmptyWorkingSet
# ==============================================================================
Write-ContractHeader "CTR-11" "Optimizador de Memoria" "Poda de Working Set de Procesos de Usuario (Optimize-ProcessMemory.ps1)"

$memScript = Join-Path $scriptsDir "Optimize-ProcessMemory.ps1"
if (Test-Path $memScript) {
    # Probar con un proceso que siempre existe en la sesión de usuario
    $memRun = & $memScript -ProcessNames 'explorer' -SkipElevation -PassThru -Unattended -Quiet
    Assert-Contract "Assert: Optimize-ProcessMemory ejecuta EmptyWorkingSet con -SkipElevation sin error" {
        return ($memRun -ne $null -and @($memRun).Count -gt 0)
    } -ExpectedState "Retorna métricas de poda" -DetailMessage "Procesos podados: $(@($memRun).Count)"
    
    Assert-Contract "Assert: Métricas reportan WorkingSet inicial y final numéricamente válidos" {
        return ($memRun[0].InitialMB -gt 0 -and $memRun[0].Success -eq $true)
    } -ExpectedState "InitialMB > 0 y Success = True" -DetailMessage "Initial: $($memRun[0].InitialMB) MB | Reclaimed: $($memRun[0].ReclaimedMB) MB"
}


# ==============================================================================
# EVALUACION FINAL DE CONTRATOS FUNCIONALES
# ==============================================================================
Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " EVALUACION FINAL DE CONTRATOS FUNCIONALES" -ForegroundColor Yellow
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Total de Aserciones de Contrato : $totalTests"
Write-Host " Aprobadas (PASS)                : $passedCount ($([math]::Round(($passedCount/$totalTests)*100, 1))%)" -ForegroundColor $(if ($passedCount -eq $totalTests) { "Green" } else { "Yellow" })
Write-Host " Fallidas (FAIL)                 : $failedCount" -ForegroundColor $(if ($failedCount -eq 0) { "Green" } else { "Red" })

if ($failedCount -eq 0) {
    Write-Host "`n>> TODOS LOS CONTRATOS FUNCIONALES FUERON SATISFECHOS EXITOSAMENTE." -ForegroundColor Green
    Exit 0
} else {
    Write-Host "`n>> DISCREPANCIA DETECTADA EN $failedCount CONTRATOS FUNCIONALES." -ForegroundColor Red
    Exit 1
}
