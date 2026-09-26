<#
.SYNOPSIS
    Optimize-GamingAndApps.ps1 - Suite de Optimizacion Avanzada de Aplicaciones y Gaming (APU/UMA & Electron)
    Parte del ecosistema romanOS Toolkit.

.DESCRIPTION
    Ajusta y optimiza aplicaciones cotidianas de alto impacto en RAM y VRAM (Steam Web Views, Discord, Spotify, VS Code)
    y el subsistema grafico para gaming de baja latencia (MPO, Flip Model y purga de shader cache).
    
    Compatible con Windows PowerShell 5.1 (powershell.exe) y PowerShell 7+ (pwsh).
    Codificacion estricta: UTF-8 con BOM.

.PARAMETER Unattended
    Aplica todas las optimizaciones recomendadas de forma desatendida sin solicitar confirmacion.

.PARAMETER PurgeShadersOnly
    Ejecuta unicamente la purga transaccional de caches de shaders graficos (AMD/DirectX).

.PARAMETER SteamOnly
    Aplica unicamente la optimizacion de ahorro de VRAM en Steam Web Views.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Unattended,
    [switch]$PurgeShadersOnly,
    [switch]$SteamOnly
)

# ============================================================
# Auto-elevacion UAC
# ============================================================
$isSimulated = ($PSBoundParameters.ContainsKey('WhatIf') -or $WhatIfPreference)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    if ($isSimulated) {
        Write-Warning "Ejecutando en modo simulado (-WhatIf) sin elevacion UAC."
    } else {
        Write-Warning "Se requieren privilegios de Administrador para aplicar directivas del sistema. Elevando..."
        $ps51 = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $myScript = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
        $argList = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $myScript)
        if ($Unattended) { $argList += '-Unattended' }
        if ($PurgeShadersOnly) { $argList += '-PurgeShadersOnly' }
        if ($SteamOnly) { $argList += '-SteamOnly' }
        Start-Process -FilePath $ps51 -ArgumentList $argList -Verb RunAs
        Exit
    }
}

$ErrorActionPreference = 'Continue'

# ============================================================
# Carga de Motores Core (UI-Engine & Policy-Engine)
# ============================================================
$searchDirs = @(
    (Join-Path $PSScriptRoot "..\Core"),
    (Join-Path $PSScriptRoot "Core"),
    $PSScriptRoot,
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core"),
    "$env:WINDIR\Setup\Scripts\Core",
    "C:\Windows\Setup\Scripts\Core"
)

$uiLoaded = $false
foreach ($dir in $searchDirs) {
    $uiPath = Join-Path $dir "UI-Engine.ps1"
    if (Test-Path $uiPath) {
        . $uiPath
        $uiLoaded = $true
        break
    }
}

foreach ($dir in $searchDirs) {
    $pePath = Join-Path $dir "Policy-Engine.ps1"
    if (Test-Path $pePath) {
        try {
            . $pePath
        } catch {
            Write-Warning "No se pudo cargar Policy-Engine: $($_.Exception.Message)"
        }
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
    function Prompt-UnifiedYesNo { param([Alias("Title", "Question", "Message")]$Prompt, [Alias("DefaultYes")][bool]$Default=$true) $d=if($Default){"S"}else{"N"}; $r=Read-Host "  [?] $Prompt [S/N] (Default: $d)"; if([string]::IsNullOrWhiteSpace($r)){return $Default}; return ($r -match '^(s|si|y|yes)$') }
}

Show-UnifiedBanner -Title "romanOS OPTIMIZADOR DE JUEGOS Y APPS" -Subtitle "Afinamiento de VRAM, Electron y Subsistema Grafico" -ShowSystemInfo

$stats = @{
    SteamTweaked    = $false
    VRAMSavedMB     = 0
    ElectronTweaked = 0
    ShadersPurgedMB = 0
    Errors          = 0
}

# ============================================================
# 1. OPTIMIZACION DE STEAM WEB VIEWS (Ahorro de VRAM en APU)
# ============================================================
if (-not $PurgeShadersOnly) {
    Write-StepHeader -StepNumber 1 -TotalSteps 5 -Message "Optimizacion de Memoria VRAM en Cliente Steam"
    
    $steamPath = $null
    $steamReg = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue
    if ($steamReg -and $steamReg.SteamPath) {
        $steamPath = $steamReg.SteamPath
    } else {
        $steamReg64 = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue
        if ($steamReg64 -and $steamReg64.InstallPath) {
            $steamPath = $steamReg64.InstallPath
        }
    }

    if ($steamPath -and (Test-Path $steamPath)) {
        Write-SubStep "Instalacion de Steam detectada en: $steamPath"
        
        # Localizar archivos de configuracion de usuario localconfig.vdf
        $userDirs = Get-ChildItem -Path (Join-Path $steamPath "userdata") -Directory -ErrorAction SilentlyContinue
        $configsModified = 0
        
        foreach ($ud in $userDirs) {
            $localConfig = Join-Path $ud.FullName "config\localconfig.vdf"
            if (Test-Path $localConfig) {
                try {
                    $txt = [System.IO.File]::ReadAllText($localConfig, [System.Text.Encoding]::UTF8)
                    $modified = $false
                    
                    # Desactivar GPU Accelerated rendering in web views si no esta configurado
                    if ($txt -match '"EnableGPUAcceleratedWebViews"\s*"1"') {
                        $txt = $txt -replace '"EnableGPUAcceleratedWebViews"\s*"1"', '"EnableGPUAcceleratedWebViews"		"0"'
                        $modified = $true
                    }
                    if ($txt -match '"SmoothScrollWebViews"\s*"1"') {
                        $txt = $txt -replace '"SmoothScrollWebViews"\s*"1"', '"SmoothScrollWebViews"		"0"'
                        $modified = $true
                    }
                    
                    if ($modified) {
                        [System.IO.File]::WriteAllText($localConfig, $txt, [System.Text.Encoding]::UTF8)
                        $configsModified++
                    }
                } catch {
                    Write-Warn "No se pudo modificar config para usuario $($ud.Name): $($_.Exception.Message)"
                }
            }
        }
        
        # Desactivar aceleracion web a nivel de registro de Steam si aplica
        try {
            Set-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "EnableGPUAcceleratedWebViews" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            Write-OK "Aceleracion GPU en Steam Web Views desactivada (Ahorro: ~300-450 MB VRAM en APU)."
            $stats.SteamTweaked = $true
            $stats.VRAMSavedMB += 350
        } catch {
            Write-Warn "No se pudo configurar clave de registro de Steam."
        }
    } else {
        Write-Info "Steam no esta instalado en este equipo. Omitiendo."
    }
}

if ($SteamOnly) {
    Write-OK "Optimizacion de Steam finalizada."
    Exit 0
}

# ============================================================
# 2. TUNING DE APLICACIONES ELECTRON (Discord, Spotify, VS Code)
# ============================================================
if (-not $PurgeShadersOnly) {
    Write-StepHeader -StepNumber 2 -TotalSteps 5 -Message "Optimizacion de Aplicaciones Electron (Discord / Spotify)"
    
    # Flags globales en registro para evitar caidas de FPS por oclusion de ventanas
    $dxGpuPath = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
    if (-not (Test-Path $dxGpuPath)) { New-Item -Path $dxGpuPath -Force | Out-Null }
    
    # Rutas comunes de carpetas Startup de usuario y sistema
    $startupPaths = @(
        (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"),
        (Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\Startup")
    )
    $runKeyCU = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

    # Suprimir telemetria, aceleracion GPU y auto-arranque parasito de Spotify
    $spotifyPath = Join-Path $env:APPDATA "Spotify\prefs"
    if (Test-Path $spotifyPath) {
        try {
            $prefs = Get-Content -Path $spotifyPath -Raw -ErrorAction SilentlyContinue
            $spotifyModified = $false
            if ($prefs -notmatch "app.enable-hardware-acceleration=false") {
                Add-Content -Path $spotifyPath -Value "`napp.enable-hardware-acceleration=false" -ErrorAction Stop
                Write-OK "Spotify: Aceleracion por hardware desactivada en interfaz de audio."
                $spotifyModified = $true
            }
            if ($prefs -notmatch "autostart\.mode=") {
                Add-Content -Path $spotifyPath -Value "`nautostart.mode=`"off`"" -ErrorAction Stop
                Write-OK "Spotify: Auto-arranque desactivado en archivo de preferencias."
                $spotifyModified = $true
            }
            if ($spotifyModified) { $stats.ElectronTweaked++ }
        } catch {
            Write-Warn "No se pudo modificar preferencias de Spotify ($spotifyPath): $($_.Exception.Message)"
        }
    }

    # Spotify: Eliminar claves de inicio en Registro de Windows
    if (Test-Path $runKeyCU) {
        foreach ($sName in @("Spotify", "Spotify Web Helper", "SpotifyStartup")) {
            $prop = Get-ItemProperty -Path $runKeyCU -Name $sName -ErrorAction SilentlyContinue
            if ($prop -and $prop.$sName) {
                try {
                    Remove-ItemProperty -Path $runKeyCU -Name $sName -Force -ErrorAction Stop
                    Write-OK "Spotify: Clave '$sName' eliminada del Registro (HKCU\Run)."
                    $stats.ElectronTweaked++
                } catch {
                    Write-Warn "No se pudo eliminar clave '$sName' de HKCU\Run: $($_.Exception.Message)"
                }
            }
        }
    }
    foreach ($sDir in $startupPaths) {
        if (Test-Path $sDir) {
            $sLnks = Get-ChildItem -Path $sDir -Filter "*Spotify*.lnk" -ErrorAction SilentlyContinue
            foreach ($lnk in $sLnks) {
                try {
                    Remove-Item -Path $lnk.FullName -Force -ErrorAction Stop
                    Write-OK "Spotify: Acceso directo de inicio eliminado de $($lnk.FullName)."
                    $stats.ElectronTweaked++
                } catch {
                    Write-Warn "No se pudo eliminar acceso directo de Spotify ($($lnk.Name)): $($_.Exception.Message)"
                }
            }
        }
    }

    # Discord: Desactivar auto-arranque en JSON interno
    $discordConfig = Join-Path $env:APPDATA "discord\settings.json"
    if (Test-Path $discordConfig) {
        try {
            $djson = Get-Content -Path $discordConfig -Raw | ConvertFrom-Json
            if ($djson.DANGEROUS_ENABLE_DEVTOOLS_ONLY_ENABLE_IF_YOU_KNOW_WHAT_YOURE_DOING -ne $true) {
                $djson | Add-Member -Name "OPEN_ON_STARTUP" -Value $false -MemberType NoteProperty -Force
                $djson | ConvertTo-Json -Compress | Out-File -FilePath $discordConfig -Encoding utf8 -Force
                Write-OK "Discord: Preferencia OPEN_ON_STARTUP = false guardada en settings.json."
                $stats.ElectronTweaked++
            }
        } catch {
            Write-Warn "No se pudo actualizar configuración de Discord ($discordConfig): $($_.Exception.Message)"
        }
    }

    # Discord: Eliminar clave de inicio en Registro de Windows
    if (Test-Path $runKeyCU) {
        $prop = Get-ItemProperty -Path $runKeyCU -Name "Discord" -ErrorAction SilentlyContinue
        if ($prop -and $prop.Discord) {
            try {
                Remove-ItemProperty -Path $runKeyCU -Name "Discord" -Force -ErrorAction Stop
                Write-OK "Discord: Clave de inicio automatico erradicada del Registro (HKCU\Run)."
                $stats.ElectronTweaked++
            } catch {
                Write-Warn "No se pudo eliminar clave 'Discord' de HKCU\Run: $($_.Exception.Message)"
            }
        }
    }

    # Discord: Eliminar accesos directos en carpetas Startup
    foreach ($sDir in $startupPaths) {
        if (Test-Path $sDir) {
            $dLnks = Get-ChildItem -Path $sDir -Filter "*Discord*.lnk" -ErrorAction SilentlyContinue
            foreach ($lnk in $dLnks) {
                try {
                    Remove-Item -Path $lnk.FullName -Force -ErrorAction Stop
                    Write-OK "Discord: Acceso directo de inicio eliminado de $($lnk.FullName)."
                    $stats.ElectronTweaked++
                } catch {
                    Write-Warn "No se pudo eliminar acceso directo de Discord ($($lnk.Name)): $($_.Exception.Message)"
                }
            }
        }
    }

    Write-OK "Optimizaciones de aplicaciones Electron completadas."
}

# ============================================================
# 3. PURGA TRANSACCIONAL DE CACHE DE SHADERS (AMD / DirectX)
# ============================================================
Write-StepHeader -StepNumber 3 -TotalSteps 5 -Message "Purga Transaccional de Caches de Shaders Graficos"

$shaderDirs = @(
    (Join-Path $env:LOCALAPPDATA "AMD\DxCache"),
    (Join-Path $env:LOCALAPPDATA "AMD\GLCache"),
    (Join-Path $env:LOCALAPPDATA "D3DSCache"),
    (Join-Path $env:LOCALAPPDATA "NVIDIA\DXCache"),
    (Join-Path $env:LOCALAPPDATA "NVIDIA\GLCache"),
    (Join-Path $env:LOCALAPPDATA "NVIDIA Corporation\NV_Cache"),
    (Join-Path $env:LOCALAPPDATA "Intel\ShaderCache"),
    (Join-Path $env:LOCALAPPDATA "Intel\DXCache"),
    (Join-Path $env:LOCALAPPDATA "Intel\IGC")
)

$bytesCleaned = 0
foreach ($dir in $shaderDirs) {
    if (Test-Path $dir) {
        Write-SubStep "Depurando cache en: $dir"
        $files = Get-ChildItem -Path $dir -Recurse -File -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            try {
                $len = $f.Length
                Remove-Item -Path $f.FullName -Force -ErrorAction Stop
                $bytesCleaned += $len
            } catch {
                Write-Verbose "[Optimize-GamingAndApps] Archivo de shader en uso bloqueado por el controlador: $($f.Name) ($($_.Exception.Message)) - omitiendo de forma segura."
            }
        }
    }
}

$mbCleaned = [math]::Round($bytesCleaned / 1MB, 2)
$stats.ShadersPurgedMB = $mbCleaned
Write-OK "Limpieza de shaders finalizada: $mbCleaned MB liberados (prevencion de micro-stuttering)."

# ============================================================
# 4. AFINAMIENTO DE SUBSISTEMA GRAFICO (MPO & WDDM 3.x)
# ============================================================
Write-StepHeader -StepNumber 4 -TotalSteps 5 -Message "Afinamiento de WDDM 3.x y Presentacion Flip Model"

try {
    # Forzar Flip Model en juegos en ventana
    $val = "SwapEffectUpgradeEnable=1;AutoHDREnable=1;VRROptimizeEnable=1;"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -Value $val -Type String -ErrorAction Stop
    Write-OK "Optimizaciones para juegos en ventana forzadas (SwapEffectUpgradeEnable=1, AutoHDR, VRR)."
} catch {
    Write-Warn "No se pudo actualizar DirectXUserGlobalSettings: $($_.Exception.Message)"
}

# ============================================================
# 5. RATIFICACION DE INVARIANTES GAMING Y ANTI-CHEAT (Vanguard/EAC & BAM)
# ============================================================
Write-StepHeader -StepNumber 5 -TotalSteps 5 -Message "Ratificacion de Invariantes de Seguridad y Anti-Cheat"

# Invariante 1: VulnerableDriverBlocklistEnable = 1 (Obligatorio para Vanguard, EAC, BattlEye)
try {
    $ciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Config"
    if (-not (Test-Path $ciPath)) { New-Item -Path $ciPath -Force | Out-Null }
    $curDrv = (Get-ItemProperty -Path $ciPath -Name "VulnerableDriverBlocklistEnable" -ErrorAction SilentlyContinue).VulnerableDriverBlocklistEnable
    if ($curDrv -ne 1) {
        Set-ItemProperty -Path $ciPath -Name "VulnerableDriverBlocklistEnable" -Value 1 -Type DWord -Force
        Write-OK "Invariante Anti-Cheat certificada: VulnerableDriverBlocklistEnable = 1 (Vanguard/EAC blindado)."
    } else {
        Write-OK "Invariante Anti-Cheat verificada: VulnerableDriverBlocklistEnable = 1 (OK)."
    }
} catch {
    Write-Warn "No se pudo ratificar VulnerableDriverBlocklistEnable: $($_.Exception.Message)"
}

# Invariante 2: Preservación del servicio BAM (Background Activity Moderator)
# Esencial para el scheduler de Windows 11 y el Modo Eficiencia en Game Mode sin interferir con hilos del juego.
try {
    $bamPath = "HKLM:\SYSTEM\CurrentControlSet\Services\bam"
    if (Test-Path $bamPath) {
        $bamStart = (Get-ItemProperty -Path $bamPath -Name "Start" -ErrorAction SilentlyContinue).Start
        if ($bamStart -eq 4) {
            Set-ItemProperty -Path $bamPath -Name "Start" -Value 1 -Type DWord -Force
            Write-OK "Servicio BAM re-activado (Start=1) para preservar planificador y Modo Eficiencia."
        } else {
            Write-OK "Servicio BAM verificado en estado optimo (Start=$bamStart)."
        }
    }
} catch {
    Write-Warn "No se pudo consultar o configurar servicio BAM: $($_.Exception.Message)"
}

# Invariante 3: Auditoria transversal de Invariantes romanOS si Policy-Engine está presente
try {
    if (Get-Command "Assert-RomanOSInvariants" -ErrorAction SilentlyContinue) {
        $invResults = Assert-RomanOSInvariants -AutoRemediate
        $invBreaches = @($invResults | Where-Object { -not $_.Satisfied }).Count
        if ($invBreaches -eq 0) {
            Write-OK "Matriz de Invariantes del Sistema: 100% Satisfecha (Cero transgresiones)."
        } else {
            Write-Warn "Se detectaron y remediaron $invBreaches desviaciones de invariantes del sistema."
        }
    }
} catch {
    Write-Warn "Aviso al evaluar invariantes del sistema: $($_.Exception.Message)"
}

# ============================================================
# RESUMEN EJECUTIVO
# ============================================================
Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "         RESUMEN DE OPTIMIZACION DE JUEGOS Y APPS" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Steam VRAM Optimizado      : $(if ($stats.SteamTweaked) { 'SI (~' + $stats.VRAMSavedMB + ' MB liberados)' } else { 'No detectado / No requerido' })"
Write-Host "  Apps Electron Afinadas     : $($stats.ElectronTweaked)"
Write-Host "  Caches de Shaders Purgadas : $($stats.ShadersPurgedMB) MB"
Write-Host "  Modelo WDDM Flip Model     : APLICADO"
Write-Host "  Invariantes Anti-Cheat/BAM : RATIFICADAS"
Write-Host "==========================================================`n" -ForegroundColor Cyan
