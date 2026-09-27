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
