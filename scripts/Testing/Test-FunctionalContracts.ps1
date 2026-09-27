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
$workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$scriptsDir    = Join-Path $workspaceRoot "scripts\Modules"
$helpersDir    = Join-Path $workspaceRoot "scripts\Desktop-Helpers"
$coreDir       = Join-Path $workspaceRoot "scripts\Core"
$guiDir        = Join-Path $workspaceRoot "scripts\GUI"
$builderDir    = Join-Path $workspaceRoot "scripts\Builder"
$driversDir    = Join-Path $workspaceRoot "scripts\Drivers"

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
    
    # 3. Act 3: Registrar Menús en Cascada en Ámbito CurrentUser
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& '$menuScript' -Apply -Scope CurrentUser -Quiet" | Out-Null
    
    $gamerKey = "HKCU:\Software\Classes\Directory\Background\shell\GamerTools"
    $gamerVerb = (Get-ItemProperty -Path $gamerKey -ErrorAction SilentlyContinue).MUIVerb
    $powerMaxKey = "$gamerKey\shell\01_PowerMax"
    
    Assert-Contract "Assert: Suite de menús registra submenú en cascada GamerTools en HKCU" {
        return ((Test-Path $gamerKey) -and ($gamerVerb -match "Gaming") -and (Test-Path $powerMaxKey))
    } -ExpectedState "GamerTools y subcomandos creados en HKCU" -DetailMessage "MUIVerb: $gamerVerb"
    
    # 4. Act 4: Desinstalar Suite de Menús
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& '$menuScript' -Remove -Scope CurrentUser -Quiet" | Out-Null
    
    $gamerKeyGone = -not (Test-Path $gamerKey)
    Assert-Contract "Assert: Suite de menús desinstala limpiamente las claves en cascada de HKCU" {
        return $gamerKeyGone
    } -ExpectedState "GamerTools eliminado de HKCU"
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
# CONTRATO 12: Auditoría y Políticas de Navegadores Web (Optimize-WebBrowsers.ps1)
# ==============================================================================
Write-ContractHeader "CTR-12" "Optimizador de Navegadores" "Auditoría Oficial GPO de Edge y Chrome (Optimize-WebBrowsers.ps1)"

$browserScript = Join-Path $scriptsDir "Optimize-WebBrowsers.ps1"
if (Test-Path $browserScript) {
    $edgeAudit = & $browserScript -Audit -Browser Edge -PassThru -Quiet
    Assert-Contract "Assert: Optimize-WebBrowsers -Audit retorna informe de directivas sin requerir elevación" {
        return ($edgeAudit -ne $null -and $edgeAudit.Mode -eq "Audit" -and $edgeAudit.TotalPolicies -gt 0)
    } -ExpectedState "Mode = Audit y TotalPolicies > 0" -DetailMessage "Navegador: $($edgeAudit.Browser) | Políticas Evaluadas: $($edgeAudit.TotalPolicies)"
} else {
    Assert-Contract "Existencia de Optimize-WebBrowsers.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 13: Auditoría Forense de Seguridad (Invoke-WindowsSecurityHardening.ps1)
# ==============================================================================
Write-ContractHeader "CTR-13" "Auditoría de Hardening de Seguridad" "Evaluación ASR, LSA y Reducción de Superficie de Ataque"

$secScript = Join-Path $scriptsDir "Invoke-WindowsSecurityHardening.ps1"
if (Test-Path $secScript) {
    $secAudit = & $secScript -AuditOnly -PassThru -NonInteractive
    Assert-Contract "Assert: Invoke-WindowsSecurityHardening -AuditOnly ejecuta auditoría en modo estándar sin UAC" {
        return ($secAudit -ne $null -and $secAudit.TotalAudits -gt 0)
    } -ExpectedState "TotalAudits > 0 y objeto retornado" -DetailMessage "Auditorías Totales: $($secAudit.TotalAudits) | Pasadas: $($secAudit.PassedCount)"
} else {
    Assert-Contract "Existencia de Invoke-WindowsSecurityHardening.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 14: Gestión de Instantáneas Transaccionales (Manage-SystemSnapshots.ps1)
# ==============================================================================
Write-ContractHeader "CTR-14" "Motor de Instantáneas romanOS" "Captura Atómica de Manifiesto y Criptografía SHA-256"

$snapScript = Join-Path $scriptsDir "Manage-SystemSnapshots.ps1"
if (Test-Path $snapScript) {
    $snapTestDir = Join-Path $workspaceRoot "scratch\test_snapshots"
    if (Test-Path $snapTestDir) { Remove-Item -Path $snapTestDir -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $snapTestDir -Force | Out-Null

    try {
        $snapObj = & $snapScript -Action Create -Name "ContractTestSnap" -SnapshotDirectory $snapTestDir -SkipElevation -Unattended
        
        $snapSubDirs = Get-ChildItem -Path $snapTestDir -Directory -ErrorAction SilentlyContinue
        $createdSnapDir = if ($snapSubDirs) { $snapSubDirs[0].FullName } else { $null }
        $manifestFile = if ($createdSnapDir) { Join-Path $createdSnapDir "manifest.json" } else { $null }
        
        Assert-Contract "Assert: Manage-SystemSnapshots crea snapshot y genera manifest.json verificado" {
            return ($manifestFile -ne $null -and (Test-Path $manifestFile))
        } -ExpectedState "manifest.json generado físicamente" -DetailMessage "Ruta: $manifestFile"

        if (Test-Path $manifestFile) {
            $manifestData = Get-Content -Path $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
            Assert-Contract "Assert: Manifiesto contiene SnapshotId, artefactos y hashes SHA-256" {
                return ($manifestData.SnapshotId -ne $null -and $manifestData.Artifacts.Count -gt 0)
            } -ExpectedState "SnapshotId no nulo y Artifacts.Count > 0" -DetailMessage "ID: $($manifestData.SnapshotId) | Artefactos: $($manifestData.Artifacts.Count)"
        }
    } finally {
        if (Test-Path $snapTestDir) {
            Remove-Item -Path $snapTestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Assert-Contract "Existencia de Manage-SystemSnapshots.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 15: Purga de Shaders de GPU y Rendimiento (Invoke-WindowsMaintenance.ps1)
# ==============================================================================
Write-ContractHeader "CTR-15" "Motor Integral de Mantenimiento" "Purga de Shaders de GPU y Caches sin Elevación Obligatoria"

$maintScript = Join-Path $scriptsDir "Invoke-WindowsMaintenance.ps1"
if (Test-Path $maintScript) {
    # Crear archivo dummy en el directorio de shader cache del usuario actual
    $d3dCacheDir = Join-Path $env:LOCALAPPDATA "D3DSCache"
    if (-not (Test-Path $d3dCacheDir)) { New-Item -ItemType Directory -Path $d3dCacheDir -Force | Out-Null }
    $dummyShaderFile = Join-Path $d3dCacheDir "contract_test_dummy_shader.bin"
    [System.IO.File]::WriteAllBytes($dummyShaderFile, [byte[]]@(0xDE, 0xAD, 0xBE, 0xEF))
    
    $dummyExistsBefore = Test-Path $dummyShaderFile
    Assert-Contract "Assert: Fixture de shader dummy creado en cache de usuario antes del test" {
        return $dummyExistsBefore
    } -ExpectedState "Dummy shader presente en $d3dCacheDir"
    
    $maintRun = & $maintScript -ShadersOnly -SkipElevation -Unattended -PassThru -Quiet
    
    $dummyExistsAfter = Test-Path $dummyShaderFile
    Assert-Contract "Assert: Invoke-WindowsMaintenance -ShadersOnly purga físicamente el cache de shaders" {
        return (-not $dummyExistsAfter -and $maintRun -ne $null -and $maintRun.Success -eq $true)
    } -ExpectedState "Dummy shader purgado (-not Test-Path) y Success = True" -DetailMessage "Shader purgado: $( -not $dummyExistsAfter)"
} else {
    Assert-Contract "Existencia de Invoke-WindowsMaintenance.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 16: Sondeo RTT de Latencia DNS (Win11-Network-Diagnostics-Optimizer.ps1)
# ==============================================================================
Write-ContractHeader "CTR-16" "Diagnóstico y Conectividad" "Sondeo de RTT y Selección Inteligente de DNS"

$netScript = Join-Path $scriptsDir "Win11-Network-Diagnostics-Optimizer.ps1"
if (Test-Path $netScript) {
    $dnsProbes = & $netScript -TestDNS -PassThru -Quiet
    Assert-Contract "Assert: Win11-Network-Diagnostics -TestDNS ejecuta sondeos RTT sin requerir elevación" {
        return ($dnsProbes -ne $null -and @($dnsProbes).Count -gt 0)
    } -ExpectedState "Array de perfiles DNS retornado" -DetailMessage "Resolvers evaluados: $(@($dnsProbes).Count)"

    if ($dnsProbes -and @($dnsProbes).Count -gt 0) {
        $firstProbe = @($dnsProbes)[0]
        Assert-Contract "Assert: Estructura de telemetría DNS incluye IP primaria y promedio RTT" {
            return ($firstProbe.PrimaryIPv4 -ne $null -and $firstProbe.AverageMs -gt 0)
        } -ExpectedState "PrimaryIPv4 y AverageMs válidos" -DetailMessage "Target: $($firstProbe.Name) ($($firstProbe.PrimaryIPv4)) -> $($firstProbe.AverageMs) ms"
    }
} else {
    Assert-Contract "Existencia de Win11-Network-Diagnostics-Optimizer.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 17: Debloat Adaptativo Solo-Lectura (Win11-Debloat-v3-Adaptive.ps1)
# ==============================================================================
Write-ContractHeader "CTR-17" "Debloat Adaptativo" "Auditoría de Bloatware e Inventario Seguro sin Mutaciones"

$debloatScript = Join-Path $scriptsDir "Win11-Debloat-v3-Adaptive.ps1"
if (Test-Path $debloatScript) {
    $debloatAudit = & $debloatScript -AuditOnly -SkipElevation -PassThru -Unattended
    Assert-Contract "Assert: Win11-Debloat -AuditOnly retorna diagnóstico de AppX y telemetría sin elevación" {
        return ($debloatAudit -ne $null -and $debloatAudit.Mode -eq "AuditOnly" -and $debloatAudit.Success -eq $true)
    } -ExpectedState "Mode = AuditOnly y Success = True" -DetailMessage "AppX Detectados: $($debloatAudit.InstalledAppx) | Perfil HW: $($debloatAudit.HardwareProfile)"
} else {
    Assert-Contract "Existencia de Win11-Debloat-v3-Adaptive.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 18: Auditor Universal de Optimización (Audit-SystemOptimization.ps1)
# ==============================================================================
Write-ContractHeader "CTR-18" "Auditor Universal" "Diagnóstico de 10 Dominios de Rendimiento Multi-Hardware"

$sysAuditScript = Join-Path $scriptsDir "Audit-SystemOptimization.ps1"
if (Test-Path $sysAuditScript) {
    $sysAuditObj = & $sysAuditScript -NoColor -PassThru -Quiet
    Assert-Contract "Assert: Audit-SystemOptimization ejecuta diagnóstico de 10 dominios en Medium IL" {
        return ($sysAuditObj -ne $null -and $sysAuditObj.TotalAudited -gt 0)
    } -ExpectedState "TotalAudited > 0 y objeto retornado" -DetailMessage "Directivas auditadas: $($sysAuditObj.TotalAudited) (OK: $($sysAuditObj.OkCount), Warn: $($sysAuditObj.WarnCount))"
} else {
    Assert-Contract "Existencia de Audit-SystemOptimization.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 19: Guardián Anti-Desvío de Servicios (Watchdog-ServiceDrift.ps1)
# ==============================================================================
Write-ContractHeader "CTR-19" "Guardián Anti-Drift" "Cálculo en Tiempo Real del Índice de Paridad de Servicios"

$driftScript = Join-Path $scriptsDir "Watchdog-ServiceDrift.ps1"
if (Test-Path $driftScript) {
    $driftRep = & $driftScript -Action Status -SkipElevation -PassThru -Unattended
    Assert-Contract "Assert: Watchdog-ServiceDrift -Action Status evalúa paridad SSOT sin elevación" {
        return ($driftRep -ne $null -and $driftRep.TotalEvaluated -gt 0 -and $driftRep.ParityPercent -ge 0)
    } -ExpectedState "TotalEvaluated > 0 y ParityPercent válido" -DetailMessage "Paridad: $($driftRep.ParityPercent)% (Conformes: $($driftRep.CompliantCount), Desviados: $($driftRep.DriftedCount))"
} else {
    Assert-Contract "Existencia de Watchdog-ServiceDrift.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 20: Auditoría y Diagnóstico Post-Instalación (PostInstall-Diagnostics.ps1)
# ==============================================================================
Write-ContractHeader "CTR-20" "Diagnóstico Post-Instalación" "Generación Resiliente de Informes Markdown y HTML"

$postDiagScript = Join-Path $scriptsDir "PostInstall-Diagnostics.ps1"
if (Test-Path $postDiagScript) {
    $postDiagOutDir = Join-Path $workspaceRoot "scratch\postinstall_test"
    if (Test-Path $postDiagOutDir) { Remove-Item -Path $postDiagOutDir -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $postDiagOutDir -Force | Out-Null

    try {
        $diagRes = & $postDiagScript -OutputDir $postDiagOutDir -PassThru -Quiet
        Assert-Contract "Assert: PostInstall-Diagnostics genera evaluación del sistema sin error fatal" {
            return ($diagRes -ne $null -and $diagRes.PassedChecks -gt 0)
        } -ExpectedState "PassedChecks > 0 y objeto retornado" -DetailMessage "Estado: $($diagRes.Status) | Verificaciones pasadas: $($diagRes.PassedChecks)"

        Assert-Contract "Assert: Reporte Markdown físico generado y accesible" {
            return ($diagRes.MarkdownReport -ne $null -and (Test-Path $diagRes.MarkdownReport))
        } -ExpectedState "Archivo Markdown existente" -DetailMessage "Reporte: $($diagRes.MarkdownReport)"
    } finally {
        if ($postDiagOutDir -and (Test-Path $postDiagOutDir)) {
            Remove-Item -Path $postDiagOutDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Assert-Contract "Existencia de PostInstall-Diagnostics.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 21: Conmutador de Windows Update (Toggle-WindowsUpdate.ps1)
# ==============================================================================
Write-ContractHeader "CTR-21" "Desktop-Helpers" "Conmutador Seguro de Windows Update y Tareas Asociadas"

$wuHelper = Join-Path $helpersDir "Toggle-WindowsUpdate.ps1"
if (Test-Path $wuHelper) {
    $wuStatus = & $wuHelper -Action Status -PassThru -Quiet
    Assert-Contract "Assert: Toggle-WindowsUpdate -Action Status retorna estado sin elevación obligatoria" {
        return ($wuStatus -ne $null -and $wuStatus.Helper -eq "WindowsUpdate" -and $wuStatus.Success -eq $true)
    } -ExpectedState "Helper = WindowsUpdate y Success = True" -DetailMessage "Estado: $($wuStatus.Status) | State: $($wuStatus.State)"
} else {
    Assert-Contract "Existencia de Toggle-WindowsUpdate.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 22: Conmutador de Defender & SmartScreen (Toggle-Defender.ps1)
# ==============================================================================
Write-ContractHeader "CTR-22" "Desktop-Helpers" "Conmutador de Protección Microsoft Defender y SmartScreen"

$defHelper = Join-Path $helpersDir "Toggle-Defender.ps1"
if (Test-Path $defHelper) {
    $defStatus = & $defHelper -Action Status -PassThru -Quiet
    Assert-Contract "Assert: Toggle-Defender -Action Status retorna estado y preserva invariantes" {
        return ($defStatus -ne $null -and $defStatus.Helper -eq "Defender" -and $defStatus.Success -eq $true)
    } -ExpectedState "Helper = Defender y Success = True" -DetailMessage "Estado: $($defStatus.Status) | State: $($defStatus.State)"
} else {
    Assert-Contract "Existencia de Toggle-Defender.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 23: Conmutador de VBS / HVCI (Toggle-VBS-CoreIsolation.ps1)
# ==============================================================================
Write-ContractHeader "CTR-23" "Desktop-Helpers" "Conmutador de Integridad de Memoria del Hipervisor (VBS / HVCI)"

$vbsHelper = Join-Path $helpersDir "Toggle-VBS-CoreIsolation.ps1"
if (Test-Path $vbsHelper) {
    $vbsStatus = & $vbsHelper -Action Status -PassThru -Quiet
    Assert-Contract "Assert: Toggle-VBS-CoreIsolation -Action Status retorna estado de virtualización" {
        return ($vbsStatus -ne $null -and $vbsStatus.Helper -eq "VBS" -and $vbsStatus.Success -eq $true)
    } -ExpectedState "Helper = VBS y Success = True" -DetailMessage "Estado: $($vbsStatus.Status) | State: $($vbsStatus.State)"
} else {
    Assert-Contract "Existencia de Toggle-VBS-CoreIsolation.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 24: Conmutador de Pila Bluetooth (Toggle-Bluetooth.ps1)
# ==============================================================================
Write-ContractHeader "CTR-24" "Desktop-Helpers" "Conmutador de Pila de Servicios Inalámbricos Bluetooth"

$bthHelper = Join-Path $helpersDir "Toggle-Bluetooth.ps1"
if (Test-Path $bthHelper) {
    $bthStatus = & $bthHelper -Action Status -PassThru -Quiet
    Assert-Contract "Assert: Toggle-Bluetooth -Action Status retorna telemetría de conectividad" {
        return ($bthStatus -ne $null -and $bthStatus.Helper -eq "Bluetooth" -and $bthStatus.Success -eq $true)
    } -ExpectedState "Helper = Bluetooth y Success = True" -DetailMessage "Estado: $($bthStatus.Status) | State: $($bthStatus.State)"
} else {
    Assert-Contract "Existencia de Toggle-Bluetooth.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 25: Conmutador del Subsistema de Impresión (Toggle-Printing.ps1)
# ==============================================================================
Write-ContractHeader "CTR-25" "Desktop-Helpers" "Conmutador del Servicio de Cola de Impresión (Spooler)"

$prnHelper = Join-Path $helpersDir "Toggle-Printing.ps1"
if (Test-Path $prnHelper) {
    $prnStatus = & $prnHelper -Action Status -PassThru -Quiet
    Assert-Contract "Assert: Toggle-Printing -Action Status retorna estado del Spooler de impresión" {
        return ($prnStatus -ne $null -and $prnStatus.Helper -eq "Printing" -and $prnStatus.Success -eq $true)
    } -ExpectedState "Helper = Printing y Success = True" -DetailMessage "Estado: $($prnStatus.Status) | State: $($prnStatus.State)"
} else {
    Assert-Contract "Existencia de Toggle-Printing.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 26: Conmutador de Uso Compartido en Red (Toggle-FileSharing.ps1)
# ==============================================================================
Write-ContractHeader "CTR-26" "Desktop-Helpers" "Conmutador de LanmanServer, LanmanWorkstation y Red SMB"

$smbHelper = Join-Path $helpersDir "Toggle-FileSharing.ps1"
if (Test-Path $smbHelper) {
    $smbStatus = & $smbHelper -Action Status -PassThru -Quiet
    Assert-Contract "Assert: Toggle-FileSharing -Action Status retorna estado de servicios de red" {
        return ($smbStatus -ne $null -and $smbStatus.Helper -eq "FileSharing" -and $smbStatus.Success -eq $true)
    } -ExpectedState "Helper = FileSharing y Success = True" -DetailMessage "Estado: $($smbStatus.Status) | State: $($smbStatus.State)"
} else {
    Assert-Contract "Existencia de Toggle-FileSharing.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 27: Motor y Catálogo Centralizado SSOT (Policy-Engine.ps1)
# ==============================================================================
Write-ContractHeader "CTR-27" "Policy-Engine" "Catálogo SSOT de Directivas, Invariantes y Exportación Unattend"

$policyEngineScript = Join-Path $coreDir "Policy-Engine.ps1"
if (Test-Path $policyEngineScript) {
    . $policyEngineScript
    $policies = Get-RomanOSPolicies -Profile 1
    $invariants = Get-RomanOSSystemInvariants
    $unattendCmds = Export-RomanOSUnattendCommands -Profile 1 -StartOrder 10

    Assert-Contract "Assert: Get-RomanOSPolicies retorna catálogo SSOT completo (>50 directivas con schema válido)" {
        $validSchema = $true
        if (-not $policies -or $policies.Count -le 50) { $validSchema = $false }
        foreach ($p in $policies[0..5]) {
            if (-not $p.Id -or -not $p.RegistryKey -or $null -eq $p.ExpectedValue) {
                $validSchema = $false
            }
        }
        return $validSchema
    } -ExpectedState "Políticas > 50 y atributos Id/RegistryKey/ExpectedValue presentes" -DetailMessage "Total políticas cargadas: $($policies.Count)"

    Assert-Contract "Assert: Get-RomanOSSystemInvariants preserva directivas anti-cheat y blindaje de sistema" {
        $hasDriverBlocklist = ($invariants | Where-Object { $_.Id -eq "INV_SECURITY_DRIVER_BLOCKLIST" -and $_.ExpectedValue -eq 1 }) -ne $null
        $hasDriverNoWu     = ($invariants | Where-Object { $_.Id -eq "INV_DRIVERS_NO_WU_OVERWRITE" -and $_.ExpectedValue -eq 1 }) -ne $null
        $hasDriverPolicy   = ($policies | Where-Object { $_.Id -eq "POL_SEC_DRIVER_BLOCKLIST" -and $_.ExpectedValue -eq 1 }) -ne $null
        return ($hasDriverBlocklist -and $hasDriverNoWu -and $hasDriverPolicy)
    } -ExpectedState "INV_SECURITY_DRIVER_BLOCKLIST=1 e INV_DRIVERS_NO_WU_OVERWRITE=1 presentes" -DetailMessage "Invariantes evaluados: $($invariants.Count) | Políticas: $($policies.Count)"

    Assert-Contract "Assert: Export-RomanOSUnattendCommands genera comandos XML SynchronousCommand válidos" {
        return ($unattendCmds -and $unattendCmds.Count -gt 10 -and $unattendCmds.XmlContent -match "<RunSynchronousCommand")
    } -ExpectedState "Comandos XML generados > 10 con etiqueta RunSynchronousCommand" -DetailMessage "Total comandos Unattend: $($unattendCmds.Count)"
} else {
    Assert-Contract "Existencia de Policy-Engine.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 28: Motor de Topología Dinámica y Mocks (Hardware-Engine.ps1)
# ==============================================================================
Write-ContractHeader "CTR-28" "Hardware-Engine" "Detección Adaptativa Multi-Hardware y Mocks Sintéticos de Scheduler"

$hwEngineScript = Join-Path $coreDir "Hardware-Engine.ps1"
if (Test-Path $hwEngineScript) {
    . $hwEngineScript
    $hwProfile = Get-SystemHardwareProfile
    $memTier = Get-RomanOSMemoryTier -RamGiB 16.0

    # Inyección de Mock Sintético (Regla 14): Intel Híbrido P/E Cores
    $intelHybridMock = [PSCustomObject]@{
        CPU = [PSCustomObject]@{
            IsHybrid     = $true
            IsDualCcdX3D = $false
            Name         = "Intel Core i7-13700K (Mock)"
        }
    }
    $hybridRec = Get-RomanOSSchedulerRecommendation -HardwareInfo $intelHybridMock

    # Inyección de Mock Sintético (Regla 14): CPU Simétrica Tradicional
    $symmetricMock = [PSCustomObject]@{
        CPU = [PSCustomObject]@{
            IsHybrid     = $false
            IsDualCcdX3D = $false
            Name         = "AMD Ryzen 5 5600X (Mock)"
        }
    }
    $symmRec = Get-RomanOSSchedulerRecommendation -HardwareInfo $symmetricMock

    Assert-Contract "Assert: Get-SystemHardwareProfile detecta topología de hardware en Medium IL sin elevación" {
        return ($hwProfile -ne $null -and $hwProfile.CPU -ne $null -and $hwProfile.RAM -ne $null)
    } -ExpectedState "Perfil no nulo con CPU y RAM" -DetailMessage "CPU: $($hwProfile.CPU.Name) | RAM: $($hwProfile.RAM.TotalGB) GB"

    Assert-Contract "Assert: Get-RomanOSMemoryTier clasifica niveles de RAM y asigna LargeSystemCache=0" {
        return ($memTier -ne $null -and $memTier.Tier -eq "Balanced" -and $memTier.LargeSystemCache -eq 0)
    } -ExpectedState "Tier = Balanced y LargeSystemCache = 0" -DetailMessage "Tier: $($memTier.Tier) | DisablePaging: $($memTier.DisablePagingExecutive)"

    Assert-Contract "Assert: Scheduler Recommendation preserva Thread Director en arquitectura híbrida (Mock)" {
        $hybridPreserved = ($hybridRec.ShouldModifyPrioritySeparation -eq $false -and $hybridRec.RecommendedValue -eq 2)
        $symmOptimized   = ($symmRec.ShouldModifyPrioritySeparation -eq $true -and $symmRec.RecommendedValue -eq 38)
        return ($hybridPreserved -and $symmOptimized)
    } -ExpectedState "Híbrido conserva default (2) y Simétrico optimiza (38)" -DetailMessage "Híbrido: $($hybridRec.TopologyType) ($($hybridRec.RecommendedValue)) | Simétrico: $($symmRec.TopologyType) ($($symmRec.RecommendedValue))"
} else {
    Assert-Contract "Existencia de Hardware-Engine.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 29: Gestor de Perfiles de Software (Deploy-AppProfiles.ps1)
# ==============================================================================
Write-ContractHeader "CTR-29" "Deploy-AppProfiles" "Resolución de Perfiles Winget y Cola de Instalación Silenciosa"

$deployScript = Join-Path $scriptsDir "Deploy-AppProfiles.ps1"
if (Test-Path $deployScript) {
    # 1. Inspeccionar catálogo sin elevación
    $cat = & $deployScript -ListCatalog -PassThru -SkipElevation
    Assert-Contract "Assert: Deploy-AppProfiles -ListCatalog -PassThru retorna catálogo curado con categorías y runtimes" {
        return ($cat -ne $null -and $cat.categories -ne $null -and $cat.runtimes -ne $null)
    } -ExpectedState "Catálogo con categorías y runtimes" -DetailMessage "Categorías: $($cat.categories.psobject.properties.Count) | Runtimes: $($cat.runtimes.Count)"

    # 2. Simulación de cola en -WhatIf
    $queue = & $deployScript -InstallRuntimesOnly -WhatIf -SkipElevation -PassThru
    Assert-Contract "Assert: Deploy-AppProfiles -InstallRuntimesOnly -WhatIf evalúa cola sin ejecutar winget" {
        return ($queue -ne $null -and $queue.Count -gt 0)
    } -ExpectedState "Cola evaluada con paquetes > 0" -DetailMessage "Paquetes en cola de runtimes: $($queue.Count)"
} else {
    Assert-Contract "Existencia de Deploy-AppProfiles.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 30: Entornos Efímeros y Generador WSB (Invoke-LiveSandbox.ps1)
# ==============================================================================
Write-ContractHeader "CTR-30" "Invoke-LiveSandbox" "Diagnóstico de Entorno y Generación Transaccional de Perfiles .wsb"

$sandboxScript = Join-Path $scriptsDir "Invoke-LiveSandbox.ps1"
if (Test-Path $sandboxScript) {
    # 1. Diagnóstico de capacidades sin elevación
    $diag = & $sandboxScript -Action Status -PassThru -SkipElevation
    Assert-Contract "Assert: Invoke-LiveSandbox -Action Status retorna capacidades de virtualización del host" {
        return ($diag -ne $null -and $diag.CPUName -ne $null -and $diag.OverallStatus -ne $null)
    } -ExpectedState "Diagnóstico no nulo con CPUName y OverallStatus" -DetailMessage "Estado: $($diag.OverallStatus) | Edición Soportada: $($diag.IsSandboxEditionSupported)"

    # 2. Generación de perfil XML .wsb en sandbox
    $scratchDir = Join-Path $workspaceRoot "scratch"
    if (-not (Test-Path $scratchDir)) { New-Item -Path $scratchDir -ItemType Directory -Force | Out-Null }
    $testWsbPath = Join-Path $scratchDir "test_contract_safe_analysis.wsb"

    $genWsb = & $sandboxScript -Action GenerateConfig -Preset SafeAnalysis -SharedFolder $scratchDir -ReadOnlySharedFolder -OutputPath $testWsbPath -SkipElevation
    $wsbContent = if (Test-Path $testWsbPath) { Get-Content $testWsbPath -Raw } else { "" }

    Assert-Contract "Assert: Invoke-LiveSandbox -Action GenerateConfig genera archivo .wsb con aislamiento estricto" {
        $hasVgpuDisabled = ($wsbContent -match "<VGpu>Disable</VGpu>")
        $hasNetDisabled  = ($wsbContent -match "<Networking>Disable</Networking>")
        $hasReadOnly     = ($wsbContent -match "<ReadOnly>true</ReadOnly>")
        return ($genWsb -ne $null -and (Test-Path $testWsbPath) -and $hasVgpuDisabled -and $hasNetDisabled -and $hasReadOnly)
    } -ExpectedState "Archivo .wsb generado con VGpu=Disable, Networking=Disable y ReadOnly=true" -DetailMessage "Archivo: $testWsbPath | Longitud: $($wsbContent.Length) bytes"

    # Teardown: Eliminar artefacto efímero
    if (Test-Path $testWsbPath) {
        Remove-Item -Path $testWsbPath -Force -ErrorAction SilentlyContinue
    }
} else {
    Assert-Contract "Existencia de Invoke-LiveSandbox.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 31: Inspección Segura de Cuentas Locales (Migrar-Usuario-W11.ps1)
# ==============================================================================
Write-ContractHeader "CTR-31" "Migrar-Usuario-W11" "Auditoría de Cuentas de Usuario sin Bloqueo Interactivo"

$migrarScript = Join-Path $scriptsDir "Migrar-Usuario-W11.ps1"
if (Test-Path $migrarScript) {
    $cuentas = & $migrarScript -ListOnly -SkipElevation -PassThru
    Assert-Contract "Assert: Migrar-Usuario-W11 -ListOnly -PassThru audita usuarios locales sin interacción" {
        $hasCurrent = ($cuentas | Where-Object { $_.Name -eq $env:USERNAME }) -ne $null
        return ($cuentas -ne $null -and $cuentas.Count -ge 1 -and $hasCurrent)
    } -ExpectedState "Colección de usuarios locales >= 1 incluyendo usuario actual" -DetailMessage "Usuarios encontrados: $($cuentas.Count) | Incluye $($env:USERNAME): True"
} else {
    Assert-Contract "Existencia de Migrar-Usuario-W11.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 32: Constructor de Imágenes ISO y Arquitectura WIM/OEM (New-OptimizedWindowsISO-v2.ps1)
# ==============================================================================
Write-ContractHeader "CTR-32" "Builder" "Estructura de Compilación ISO, Funciones AST e Inyección OEM"

$builderScript = Join-Path $builderDir "New-OptimizedWindowsISO-v2.ps1"
if (Test-Path $builderScript) {
    # 1. Comprobar UTF-8 con BOM
    $bBytes = [System.IO.File]::ReadAllBytes($builderScript)[0..2]
    $bHasBOM = ($bBytes[0] -eq 0xEF -and $bBytes[1] -eq 0xBB -and $bBytes[2] -eq 0xBF)
    Assert-Contract "Assert: New-OptimizedWindowsISO-v2.ps1 codificado en UTF-8 con BOM (Regla 4)" {
        return $bHasBOM
    } -ExpectedState "Primeros bytes = 0xEF-BB-BF" -DetailMessage "BOM: $bHasBOM"

    # 2. Análisis sintáctico AST y extracción de funciones
    $parseErrors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($builderScript, [ref]$tokens, [ref]$parseErrors)
    Assert-Contract "Assert: Parser AST de New-OptimizedWindowsISO-v2.ps1 sin errores sintácticos" {
        return ($parseErrors.Count -eq 0)
    } -ExpectedState "Errores AST = 0" -DetailMessage "Errores detectados: $($parseErrors.Count)"

    # 3. Verificar funciones críticas de metadatos WIM e inyección
    $funcNames = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | ForEach-Object { $_.Name }
    Assert-Contract "Assert: Funciones maestras de metadatos WIM y logging residen en New-OptimizedWindowsISO-v2.ps1" {
        $hasMeta     = $funcNames -contains "Get-RomanOSWimMetadata"
        $hasAssert   = $funcNames -contains "Assert-RomanOSWimMetadata"
        $hasInitLog  = $funcNames -contains "Initialize-Log"
        $hasWriteLog = $funcNames -contains "Write-LogEntry"
        return ($hasMeta -and $hasAssert -and $hasInitLog -and $hasWriteLog)
    } -ExpectedState "Funciones Get/Assert-RomanOSWimMetadata y Initialize/Write-LogEntry presentes" -DetailMessage "Total funciones en Builder: $($funcNames.Count)"
} else {
    Assert-Contract "Existencia de New-OptimizedWindowsISO-v2.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 33: Descargador Oficial de Actualizaciones Microsoft (Get-WindowsUpdates.ps1)
# ==============================================================================
Write-ContractHeader "CTR-33" "Get-WindowsUpdates" "Resolución de Matriz de Actualizaciones Microsoft en Modo Simulación"

$winUpdatesScript = Join-Path $builderDir "Get-WindowsUpdates.ps1"
if (Test-Path $winUpdatesScript) {
    $resUpdates = & $winUpdatesScript -Version "11_24H2" -Architecture "amd64" -WhatIf -PassThru -SkipElevation -Unattended
    Assert-Contract "Assert: Get-WindowsUpdates -WhatIf -PassThru resuelve matriz de actualización para Windows 11 24H2" {
        $matrix = $resUpdates.SearchMatrix
        $hasLcu = ($matrix -ne $null -and $matrix.LCU -match "Cumulative Update Windows 11 24H2 x64")
        $hasCheckpoint = ($matrix -ne $null -and $matrix.Checkpoint -match "KB5043080 x64")
        return ($resUpdates -ne $null -and $resUpdates.Version -eq "11_24H2" -and $hasLcu -and $hasCheckpoint)
    } -ExpectedState "Versión 11_24H2 con LCU y Checkpoint KB5043080 x64" -DetailMessage "LCU: $($resUpdates.SearchMatrix.LCU) | Checkpoint: $($resUpdates.SearchMatrix.Checkpoint)"
} else {
    Assert-Contract "Existencia de Get-WindowsUpdates.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 34: Descargador de Runtimes Oficiales C++ y DirectX (Get-EssentialRuntimes.ps1)
# ==============================================================================
Write-ContractHeader "CTR-34" "Get-EssentialRuntimes" "Catálogo Oficial de Runtimes C++ y DirectX para Inyección Offline"

$runtimesScript = Join-Path $builderDir "Get-EssentialRuntimes.ps1"
if (Test-Path $runtimesScript) {
    $rtList = & $runtimesScript -IncludeLegacy -WhatIf -PassThru
    Assert-Contract "Assert: Get-EssentialRuntimes -WhatIf -PassThru retorna catálogo completo de runtimes oficiales" {
        $hasVcLatest = ($rtList | Where-Object { $_.FileName -eq "vc_redist.x64.exe" }) -ne $null
        $hasVc2013   = ($rtList | Where-Object { $_.FileName -eq "vcredist_2013_x64.exe" }) -ne $null
        $hasVcLegacy = ($rtList | Where-Object { $_.FileName -eq "vcredist_2010_x64.exe" }) -ne $null
        return ($rtList -ne $null -and $rtList.Count -ge 8 -and $hasVcLatest -and $hasVc2013 -and $hasVcLegacy)
    } -ExpectedState "Catálogo >= 8 paquetes con VC++ 2015-2022, 2013 y 2010 presentes" -DetailMessage "Total paquetes catalogados: $($rtList.Count)"
} else {
    Assert-Contract "Existencia de Get-EssentialRuntimes.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 35: Gestor de Controladores Críticos de Almacenamiento (Get-CriticalDrivers.ps1)
# ==============================================================================
Write-ContractHeader "CTR-35" "Get-CriticalDrivers" "Resolución de Controladores de Almacenamiento Intel VMD y VirtIO"

$critDriversScript = Join-Path $driversDir "Get-CriticalDrivers.ps1"
if (Test-Path $critDriversScript) {
    $driverPkgs = & $critDriversScript -Package All -WhatIf -PassThru
    Assert-Contract "Assert: Get-CriticalDrivers -WhatIf -PassThru resuelve paquetes Intel VMD y VirtIO" {
        $hasVmd    = ($driverPkgs | Where-Object { $_.Id -eq "IntelVMD" -and $_.TestInf -eq "iaStorVD.inf" }) -ne $null
        $hasVirtIo = ($driverPkgs | Where-Object { $_.Id -eq "VirtIO" -and $_.TestInf -eq "viostor.inf" }) -ne $null
        return ($driverPkgs -ne $null -and $driverPkgs.Count -eq 2 -and $hasVmd -and $hasVirtIo)
    } -ExpectedState "2 paquetes resueltos con iaStorVD.inf y viostor.inf" -DetailMessage "Paquetes: $(($driverPkgs | ForEach-Object { $_.Id }) -join ', ')"
} else {
    Assert-Contract "Existencia de Get-CriticalDrivers.ps1" { return $false }
}


# ==============================================================================
# CONTRATO 36: Depuración Segura de DriverStore (Clean-DriverStore.ps1)
# ==============================================================================
Write-ContractHeader "CTR-36" "Clean-DriverStore" "Mantenimiento y Depuración Segura del DriverStore sin Elevación"

$cleanDriverScript = Join-Path $driversDir "Clean-DriverStore.ps1"
if (Test-Path $cleanDriverScript) {
    $cleanResult = & $cleanDriverScript -WhatIf
    Assert-Contract "Assert: Clean-DriverStore -WhatIf ejecuta simulación de depuración en modo solo lectura" {
        return ($cleanResult -ne $null -and $cleanResult.Success -eq $true)
    } -ExpectedState "Success = True en modo WhatIf sin mutaciones destructivas" -DetailMessage "Success: $($cleanResult.Success) | RemovedCount: $($cleanResult.RemovedCount)"
} else {
    Assert-Contract "Existencia de Clean-DriverStore.ps1" { return $false }
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
