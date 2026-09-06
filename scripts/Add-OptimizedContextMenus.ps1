<#
.SYNOPSIS
    Add-OptimizedContextMenus.ps1 - Suite Modular de Menús Contextuales para Gaming y Power-Users
    romanOS / OptimizedISO Project (Windows 11 24H2 / 25H2)

.DESCRIPTION
    Registra y gestiona extensiones del menú contextual del Explorador de Windows mediante
    verbos estáticos oficiales del Shell de Windows. Optimizado para baja latencia, cero
    procesos en segundo plano, soporte para gaming, modding de archivos, reparación de sistema
    y opciones avanzadas de energía (UEFI / Recuperación).
    
    Admite habilitar el Menú Clásico de 1 solo clic (0 ms de latencia) o mantener el menú
    moderno nativo de Windows 11.

.PARAMETER Apply
    Aplica el conjunto completo de menús contextuales y activa el menú clásico por defecto.

.PARAMETER Remove
    Desinstala limpiamente todas las claves del registro agregadas por esta utilidad.

.PARAMETER EnableClassicMenu
    Fuerza la activación del menú contextual clásico de Windows (1 solo clic).

.PARAMETER RestoreModernMenu
    Restaura el menú contextual moderno original de Windows 11.

.PARAMETER Quiet
    Ejecución desatendida sin pausas ni interacción (ideal para $OEM$ / SetupComplete.cmd).

.PARAMETER RestartExplorer
    Reinicia el proceso explorer.exe para que los cambios visuales se apliquen de inmediato.

.EXAMPLE
    .\Add-OptimizedContextMenus.ps1 -Apply -RestartExplorer

.EXAMPLE
    .\Add-OptimizedContextMenus.ps1 -Remove -RestoreModernMenu
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Apply,
    [switch]$Remove,
    [switch]$EnableClassicMenu,
    [switch]$RestoreModernMenu,
    [ValidateSet("Auto", "AllUsers", "CurrentUser")]
    [string]$Scope = "Auto",
    [switch]$Quiet,
    [switch]$RestartExplorer
)

# -----------------------------------------------------------------------------
# 0. CONFIGURACIÓN DE ENTORNO Y ELEVACIÓN UAC
# -----------------------------------------------------------------------------
$ErrorActionPreference = 'Continue'
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue } catch {}

$isSimulated = ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf') -or $WhatIfPreference)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$script:EffectiveScope = if ($Scope -eq "CurrentUser") {
    "CurrentUser"
} elseif ($Scope -eq "AllUsers") {
    "AllUsers"
} else {
    if ($isAdmin) { "AllUsers" } else { "CurrentUser" }
}

if ($script:EffectiveScope -eq "AllUsers" -and -not $isAdmin) {
    if ($isSimulated) {
        if (-not $Quiet) { Write-Host "  [WhatIf] Ejecución simulada con -WhatIf (ámbito AllUsers requiere Administrador)." -ForegroundColor Yellow }
    } else {
        if ($PSCmdlet.ShouldProcess("powershell.exe", "Auto-elevar privilegios de Administrador UAC")) {
            if (-not $Quiet) { Write-Host "  [!] Solicitando elevación de Administrador para ámbito AllUsers..." -ForegroundColor Yellow }
            $scriptPath = $MyInvocation.MyCommand.Definition
            if (-not $scriptPath) { $scriptPath = $PSCommandPath }
            
            $argList = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"")
            if ($Apply)             { $argList += '-Apply' }
            if ($Remove)            { $argList += '-Remove' }
            if ($EnableClassicMenu) { $argList += '-EnableClassicMenu' }
            if ($RestoreModernMenu) { $argList += '-RestoreModernMenu' }
            if ($Quiet)             { $argList += '-Quiet' }
            if ($RestartExplorer)   { $argList += '-RestartExplorer' }
            $argList += ('-Scope', 'AllUsers')
            
            try {
                $p = Start-Process -FilePath "powershell.exe" -ArgumentList ($argList -join ' ') -Verb RunAs -PassThru -ErrorAction Stop
                if ($p) { exit }
            } catch {
                if (-not $Quiet) { Write-Host "  [i] Elevación no disponible en esta sesión. Aplicando en ámbito de Usuario Actual (HKCU)..." -ForegroundColor Yellow }
                $script:EffectiveScope = "CurrentUser"
            }
        }
    }
}

# -----------------------------------------------------------------------------
# 1. CARGA DE MOTOR VISUAL UNIFICADO O FALLBACK NATIVO
# -----------------------------------------------------------------------------
$uiLoaded = $false
$uiEnginePaths = @(
    (Join-Path $PSScriptRoot "Core\UI-Engine.ps1"),
    (Join-Path $PSScriptRoot "UI-Engine.ps1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\UI-Engine.ps1"),
    "C:\Windows\Setup\Scripts\Core\UI-Engine.ps1"
)
foreach ($p in $uiEnginePaths) {
    if (Test-Path $p) {
        try { . $p; $uiLoaded = $true; break } catch {}
    }
}

function Out-LogInfo    { param($msg) if (-not $Quiet) { if ($uiLoaded -and (Get-Command Write-Info -ErrorAction SilentlyContinue)) { Write-Info $msg } else { Write-Host "  [i] $msg" -ForegroundColor DarkGray } } }
function Out-LogOK      { param($msg) if (-not $Quiet) { if ($uiLoaded -and (Get-Command Write-OK -ErrorAction SilentlyContinue)) { Write-OK $msg } else { Write-Host "  [OK] $msg" -ForegroundColor Green } } }
function Out-LogWarn    { param($msg) if (-not $Quiet) { if ($uiLoaded -and (Get-Command Write-Warn -ErrorAction SilentlyContinue)) { Write-Warn $msg } else { Write-Host "  [WARN] $msg" -ForegroundColor Yellow } } }
function Out-LogError   { param($msg) if (-not $Quiet) { if ($uiLoaded -and (Get-Command Write-ErrorMsg -ErrorAction SilentlyContinue)) { Write-ErrorMsg $msg } else { Write-Host "  [ERROR] $msg" -ForegroundColor Red } } }
function Out-LogHeader  { param($title) if (-not $Quiet) { if ($uiLoaded -and (Get-Command Show-UnifiedBanner -ErrorAction SilentlyContinue)) { Show-UnifiedBanner -Title $title -Subtitle "Suite de Menús Contextuales romanOS" -NoClear } else { Write-Host "`n=== $title ===`n" -ForegroundColor Cyan } } }

# Si no se pasó ninguna acción, el comportamiento predeterminado es -Apply
if (-not $Apply -and -not $Remove -and -not $EnableClassicMenu -and -not $RestoreModernMenu) {
    $Apply = $true
}

# -----------------------------------------------------------------------------
# 2. AYUDANTES DE REGISTRO
# -----------------------------------------------------------------------------
function Set-ShellVerb {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [string]$DisplayName = "",
        [string]$MUIVerb = "",
        [string]$Icon = "",
        [string]$Command = "",
        [string]$Position = "",
        [string]$AppliesTo = "",
        [string]$SubCommands,
        [switch]$HasLUAShield,
        [switch]$NeverDefault,
        [switch]$SeparatorBefore,
        [switch]$SeparatorAfter
    )

    if ($PSCmdlet.ShouldProcess($Path, "Registrar verbo de menú")) {
        $psPath = $Path
        if ($psPath -notmatch '^[a-zA-Z]+:' -and $psPath -notmatch '^Registry::') {
            $psPath = $psPath -replace '^HKLM\\', 'HKLM:\' -replace '^HKCU\\', 'HKCU:\' -replace '^HKU\\', 'Registry::HKEY_USERS\'
        }
        if ($script:EffectiveScope -eq "CurrentUser") {
            $psPath = $psPath -replace '^HKLM:\\SOFTWARE\\Classes', 'HKCU:\Software\Classes'
        }

        if (-not (Test-Path -LiteralPath $psPath)) {
            New-Item -Path $psPath -Force | Out-Null
        }

        if ($PSBoundParameters.ContainsKey('SubCommands')) {
            # Es un contenedor de submenú en cascada
            Set-ItemProperty -LiteralPath $psPath -Name "SubCommands" -Value $SubCommands -Force
            # En contenedores en cascada, el valor (default) debe estar vacío para que Windows no intente ejecutarlo como acción simple
            Set-ItemProperty -LiteralPath $psPath -Name "(default)" -Value "" -Force
        } else {
            # Es un comando de acción ejecutable: auto-sanar eliminando cualquier valor SubCommands previo residual
            Remove-ItemProperty -LiteralPath $psPath -Name "SubCommands" -Force -ErrorAction SilentlyContinue

            if ($DisplayName) {
                Set-ItemProperty -LiteralPath $psPath -Name "(default)" -Value $DisplayName -Force
            } elseif ($MUIVerb) {
                Set-ItemProperty -LiteralPath $psPath -Name "(default)" -Value $MUIVerb -Force
            }
        }

        if ($MUIVerb)     { Set-ItemProperty -LiteralPath $psPath -Name "MUIVerb" -Value $MUIVerb -Force }
        if ($Icon)        { Set-ItemProperty -LiteralPath $psPath -Name "Icon" -Value $Icon -Force }
        if ($Position)    { Set-ItemProperty -LiteralPath $psPath -Name "Position" -Value $Position -Force }
        if ($AppliesTo)   { Set-ItemProperty -LiteralPath $psPath -Name "AppliesTo" -Value $AppliesTo -Force }
        if ($HasLUAShield) { Set-ItemProperty -LiteralPath $psPath -Name "HasLUAShield" -Value "" -Force }
        if ($NeverDefault) { Set-ItemProperty -LiteralPath $psPath -Name "NeverDefault" -Value "" -Force }
        if ($SeparatorBefore) { Set-ItemProperty -LiteralPath $psPath -Name "SeparatorBefore" -Value "" -Force }
        if ($SeparatorAfter)  { Set-ItemProperty -LiteralPath $psPath -Name "SeparatorAfter" -Value "" -Force }

        if ($Command) {
            $cmdPath = Join-Path $psPath "command"
            if (-not (Test-Path -LiteralPath $cmdPath)) {
                New-Item -Path $cmdPath -Force | Out-Null
            }
            Set-ItemProperty -LiteralPath $cmdPath -Name "(default)" -Value $Command -Force
        }
    }
}

function Remove-ShellVerb {
    param([Parameter(Mandatory=$true)][string]$Path)
    if ($PSCmdlet.ShouldProcess($Path, "Eliminar verbo de menú")) {
        $psPath = $Path
        if ($psPath -notmatch '^[a-zA-Z]+:' -and $psPath -notmatch '^Registry::') {
            $psPath = $psPath -replace '^HKLM\\', 'HKLM:\' -replace '^HKCU\\', 'HKCU:\' -replace '^HKU\\', 'Registry::HKEY_USERS\'
        }
        if (Test-Path $psPath) {
            Remove-Item -Path $psPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        $cuPath = $psPath -replace '^HKLM:\\SOFTWARE\\Classes', 'HKCU:\Software\Classes'
        if ($cuPath -ne $psPath -and (Test-Path $cuPath)) {
            Remove-Item -Path $cuPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# -----------------------------------------------------------------------------
# 3. CONTROL DEL MENÚ CONTEXTUAL CLÁSICO VS MODERNO (WINDOWS 11)
# -----------------------------------------------------------------------------
function Enable-ClassicContextMenu {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    $clsidPath = "Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    Out-LogInfo "Habilitando Menú Contextual Clásico de Windows (0 ms latencia, 1 solo clic)..."
    if ($PSCmdlet.ShouldProcess("HKCU e HKU\.DEFAULT", "Habilitar menú clásico CLSID")) {
        try {
            $targetHives = @("HKCU:\$clsidPath")
            if ($isAdmin) {
                $targetHives += "Registry::HKEY_USERS\.DEFAULT\$clsidPath"
            }
            foreach ($k in $targetHives) {
                if (-not (Test-Path $k)) {
                    New-Item -Path $k -Force | Out-Null
                }
                Set-ItemProperty -Path $k -Name "(default)" -Value "" -Force
            }
            Out-LogOK "Menú Contextual Clásico activado como predeterminado."
        } catch {
            Out-LogError "Fallo al habilitar menú clásico: $($_.Exception.Message)"
        }
    }
}

function Disable-ClassicContextMenu {
    Out-LogInfo "Restaurando Menú Contextual Moderno de Windows 11..."
    if ($PSCmdlet.ShouldProcess("HKCU e HKU\.DEFAULT", "Restaurar menú moderno CLSID")) {
        try {
            $targetHives = @(
                "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}",
                "Registry::HKEY_USERS\.DEFAULT\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
            )
            foreach ($k in $targetHives) {
                if (Test-Path $k) {
                    Remove-Item -Path $k -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            Out-LogOK "Menú Contextual Moderno restaurado."
        } catch {
            Out-LogError "Fallo al restaurar menú moderno: $($_.Exception.Message)"
        }
    }
}

# -----------------------------------------------------------------------------
# 4. INSTALACIÓN DE LA SUITE DE MENÚS CONTEXTUALES
# -----------------------------------------------------------------------------
function Install-OptimizedContextMenus {
    Out-LogHeader "Instalando Menús Contextuales Optimizados (Gamer & Power-User)"

    # --- A. Terminal (Administrador) en Fondo y Carpetas ---
    Out-LogInfo "Registrando: Terminal (Administrador) en fondo y carpetas..."
    $cmdPsAdminBg = "powershell.exe -Command `"Start-Process powershell.exe -ArgumentList '-NoExit','-Command','Set-Location -LiteralPath \`"%V\`"' -Verb RunAs`""
    $cmdPsAdminDir = "powershell.exe -Command `"Start-Process powershell.exe -ArgumentList '-NoExit','-Command','Set-Location -LiteralPath \`"%1\`"' -Verb RunAs`""
    
    Set-ShellVerb -Path "HKLM:\SOFTWARE\Classes\Directory\Background\shell\PSAdmin" `
        -DisplayName "Terminal (Administrador)" -Icon "%SystemRoot%\System32\imageres.dll,109" `
        -Position "Top" -HasLUAShield -Command $cmdPsAdminBg

    Set-ShellVerb -Path "HKLM:\SOFTWARE\Classes\Directory\shell\PSAdmin" `
        -DisplayName "Terminal (Administrador)" -Icon "%SystemRoot%\System32\imageres.dll,109" `
        -Position "Top" -HasLUAShield -Command $cmdPsAdminDir

    # --- B. Reiniciar Explorador (Solo Escritorio) ---
    Out-LogInfo "Registrando: Reiniciar Explorador..."
    Set-ShellVerb -Path "HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\RestartExplorer" `
        -DisplayName "Reiniciar Explorador de Windows" -Icon "%SystemRoot%\System32\imageres.dll,178" `
        -Position "Top" -Command "cmd.exe /c taskkill /f /im explorer.exe & start explorer.exe"

    # --- C. Submenú en Cascada: Gaming y Rendimiento ---
    Out-LogInfo "Registrando cascada: Gaming y Rendimiento..."
    $gamerBase = "HKLM:\SOFTWARE\Classes\Directory\Background\shell\GamerTools"
    Set-ShellVerb -Path $gamerBase -MUIVerb "Gaming y Rendimiento ⚡" `
        -Icon "%SystemRoot%\System32\imageres.dll,264" -SubCommands ""

    $cmdPowerMax = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"try { `$l = powercfg /l; if (`$l -notmatch 'e9a42b02-d5df-448d-aa00-03f14749eb61') { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null }; powercfg /s e9a42b02-d5df-448d-aa00-03f14749eb61; Write-Host 'Plan de Maximo Rendimiento Activado' -ForegroundColor Green; Start-Sleep -Seconds 2 } catch { Write-Host 'Error activando plan de energia' -ForegroundColor Red; Start-Sleep -Seconds 3 }`""
    Set-ShellVerb -Path "$gamerBase\shell\01_PowerMax" -MUIVerb "Activar Plan Máximo Rendimiento" `
        -Icon "%SystemRoot%\System32\shell32.dll,238" `
        -Command $cmdPowerMax

    Set-ShellVerb -Path "$gamerBase\shell\02_FlushDNS" -MUIVerb "Vaciar Caché DNS (Flush DNS)" `
        -Icon "%SystemRoot%\System32\imageres.dll,23" `
        -Command "cmd.exe /c ipconfig /flushdns & timeout /t 2"

    Set-ShellVerb -Path "$gamerBase\shell\03_HAGS" -MUIVerb "Configuración de Gráficos y HAGS" `
        -Icon "%SystemRoot%\System32\shell32.dll,16" `
        -Command "cmd.exe /c start ms-settings:display-advancedgraphics"

    Set-ShellVerb -Path "$gamerBase\shell\04_GameMode" -MUIVerb "Modo de Juego de Windows" `
        -Icon "%SystemRoot%\System32\imageres.dll,100" `
        -Command "cmd.exe /c start ms-settings:gaming-gamemode"

    # --- D. Submenú en Cascada: Herramientas del Sistema ---
    Out-LogInfo "Registrando cascada: Herramientas del Sistema..."
    $sysBase = "HKLM:\SOFTWARE\Classes\Directory\Background\shell\SystemTools"
    Set-ShellVerb -Path $sysBase -MUIVerb "Herramientas del Sistema ⚙️" `
        -Icon "%SystemRoot%\System32\imageres.dll,104" -SubCommands ""

    Set-ShellVerb -Path "$sysBase\shell\01_TaskMgr" -MUIVerb "Administrador de Tareas" `
        -Icon "taskmgr.exe" -Command "taskmgr.exe"

    Set-ShellVerb -Path "$sysBase\shell\02_DevMgmt" -MUIVerb "Administrador de Dispositivos" `
        -Icon "%SystemRoot%\System32\devmgmt.msc" -Command "mmc.exe devmgmt.msc"

    Set-ShellVerb -Path "$sysBase\shell\03_Network" -MUIVerb "Conexiones de Red" `
        -Icon "%SystemRoot%\System32\ncpa.cpl" -Command "control.exe ncpa.cpl"

    Set-ShellVerb -Path "$sysBase\shell\04_Services" -MUIVerb "Servicios de Windows" `
        -Icon "%SystemRoot%\System32\services.msc" -Command "mmc.exe services.msc"

    Set-ShellVerb -Path "$sysBase\shell\05_CleanMgr" -MUIVerb "Limpieza de Disco" `
        -Icon "cleanmgr.exe" -Command "cleanmgr.exe /lowdisk"

    Set-ShellVerb -Path "$sysBase\shell\06_Repair" -MUIVerb "Reparar Sistema (DISM + SFC)" `
        -Icon "%SystemRoot%\System32\imageres.dll,54" -HasLUAShield `
        -Command "powershell.exe -Command `"Start-Process cmd.exe -ArgumentList '/k DISM /Online /Cleanup-Image /RestoreHealth && sfc /scannow' -Verb RunAs`""

    Set-ShellVerb -Path "$sysBase\shell\07_GodMode" -MUIVerb "Panel Maestro (God Mode)" `
        -Icon "%SystemRoot%\System32\imageres.dll,104" `
        -Command "explorer.exe shell:::{ED7BA470-8E54-465E-825C-99712043E01C}"

    # --- E. Submenú en Cascada: Opciones de Energía (Solo Escritorio) ---
    Out-LogInfo "Registrando cascada: Opciones de Energía Avanzadas..."
    $pwrBase = "HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\PowerOptions"
    Set-ShellVerb -Path $pwrBase -MUIVerb "Opciones de Energía ⚡" `
        -Icon "%SystemRoot%\System32\shell32.dll,27" -Position "Bottom" -SubCommands ""

    Set-ShellVerb -Path "$pwrBase\shell\01_UEFI" -MUIVerb "Reiniciar en Firmware UEFI / BIOS" `
        -Icon "%SystemRoot%\System32\shell32.dll,220" -HasLUAShield `
        -Command "shutdown.exe /r /fw /t 0"

    Set-ShellVerb -Path "$pwrBase\shell\02_Recovery" -MUIVerb "Reiniciar en Opciones de Recuperación" `
        -Icon "%SystemRoot%\System32\shell32.dll,27" `
        -Command "shutdown.exe /r /o /t 0"

    Set-ShellVerb -Path "$pwrBase\shell\03_ColdShutdown" -MUIVerb "Apagado Completo (Cero Fast Startup)" `
        -Icon "%SystemRoot%\System32\shell32.dll,27" `
        -Command "shutdown.exe /s /f /t 0"

    # --- F. Tomar Posesión (Take Ownership) en Archivos y Carpetas ---
    Out-LogInfo "Registrando: Tomar Posesión (Take Ownership)..."
    $cmdTakeownFile = "cmd.exe /c takeown /f `"%1`" && icacls `"%1`" /grant *S-1-3-0:(F) /c /l /q"
    $cmdTakeownDir  = "cmd.exe /c takeown /f `"%1`" /r /d y && icacls `"%1`" /grant *S-1-3-0:(OI)(CI)F /t /c /l /q"

    Set-ShellVerb -Path "HKLM:\SOFTWARE\Classes\*\shell\TakeOwnership" `
        -DisplayName "Tomar Posesión (Take Ownership)" -Icon "%SystemRoot%\System32\imageres.dll,73" `
        -Position "Top" -HasLUAShield -Command $cmdTakeownFile

    Set-ShellVerb -Path "HKLM:\SOFTWARE\Classes\Directory\shell\TakeOwnership" `
        -DisplayName "Tomar Posesión (Take Ownership)" -Icon "%SystemRoot%\System32\imageres.dll,73" `
        -Position "Top" -HasLUAShield -Command $cmdTakeownDir

    # --- G. Abrir con Bloc de Notas (Cualquier archivo) ---
    Out-LogInfo "Registrando: Abrir con Bloc de Notas..."
    Set-ShellVerb -Path "HKLM:\SOFTWARE\Classes\*\shell\OpenWithNotepad" `
        -DisplayName "Abrir con Bloc de Notas" -Icon "%SystemRoot%\System32\notepad.exe,0" `
        -Command "notepad.exe `"%1`""

    # --- H. Calcular Hash SHA-256 (Cualquier archivo) ---
    Out-LogInfo "Registrando: Calcular Hash SHA-256..."
    Set-ShellVerb -Path "HKLM:\SOFTWARE\Classes\*\shell\HashSHA256" `
        -DisplayName "Calcular Hash SHA-256" -Icon "%SystemRoot%\System32\imageres.dll,102" `
        -Command "cmd.exe /c certutil -hashfile `"%1`" SHA256 & pause"

    # --- I. Bloquear / Desbloquear en Firewall (Archivos .exe) ---
    Out-LogInfo "Registrando: Bloquear / Permitir en Firewall..."
    Set-ShellVerb -Path "HKLM:\SOFTWARE\Classes\exefile\shell\BlockInFirewall" `
        -DisplayName "Bloquear en Firewall de Windows" -Icon "%SystemRoot%\System32\imageres.dll,207" `
        -AppliesTo "System.FileExtension:=.exe" -HasLUAShield `
        -Command "cmd.exe /c netsh advfirewall firewall add rule name=`"Block_%~nx1`" dir=out program=`"%1`" action=block & pause"

    Set-ShellVerb -Path "HKLM:\SOFTWARE\Classes\exefile\shell\UnblockInFirewall" `
        -DisplayName "Permitir / Quitar Regla en Firewall" -Icon "%SystemRoot%\System32\imageres.dll,208" `
        -AppliesTo "System.FileExtension:=.exe" -HasLUAShield `
        -Command "cmd.exe /c netsh advfirewall firewall delete rule name=`"Block_%~nx1`" & pause"

    # Por defecto en -Apply, activar menú clásico para inmediatez
    Enable-ClassicContextMenu

    Out-LogOK "Suite de menús contextuales instalada correctamente."
}

# -----------------------------------------------------------------------------
# 5. DESINSTALACIÓN LIMPIA DE LA SUITE
# -----------------------------------------------------------------------------
function Uninstall-OptimizedContextMenus {
    Out-LogHeader "Desinstalando Menús Contextuales Optimizados"

    $pathsToRemove = @(
        "HKLM:\SOFTWARE\Classes\Directory\Background\shell\PSAdmin",
        "HKLM:\SOFTWARE\Classes\Directory\shell\PSAdmin",
        "HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\RestartExplorer",
        "HKLM:\SOFTWARE\Classes\Directory\Background\shell\GamerTools",
        "HKLM:\SOFTWARE\Classes\Directory\Background\shell\SystemTools",
        "HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\PowerOptions",
        "HKLM:\SOFTWARE\Classes\*\shell\TakeOwnership",
        "HKLM:\SOFTWARE\Classes\Directory\shell\TakeOwnership",
        "HKLM:\SOFTWARE\Classes\*\shell\OpenWithNotepad",
        "HKLM:\SOFTWARE\Classes\*\shell\HashSHA256",
        "HKLM:\SOFTWARE\Classes\exefile\shell\BlockInFirewall",
        "HKLM:\SOFTWARE\Classes\exefile\shell\UnblockInFirewall",
        # Claves legacy de versiones previas
        "HKLM:\SOFTWARE\Classes\Directory\Background\shell\FlushDNS",
        "HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\GodMode",
        "HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\RepairSystem"
    )

    foreach ($p in $pathsToRemove) {
        Remove-ShellVerb -Path $p
    }

    Out-LogOK "Todas las entradas de registro personalizadas fueron eliminadas."
}

# -----------------------------------------------------------------------------
# 6. FLUJO DE EJECUCIÓN PRINCIPAL
# -----------------------------------------------------------------------------
try {
    if ($Remove) {
        Uninstall-OptimizedContextMenus
    } elseif ($Apply) {
        Install-OptimizedContextMenus
    }

    if ($EnableClassicMenu) {
        Enable-ClassicContextMenu
    } elseif ($RestoreModernMenu) {
        Disable-ClassicContextMenu
    }

    if ($RestartExplorer) {
        Out-LogInfo "Reiniciando Explorador de Windows..."
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
            Start-Process explorer.exe
        }
        Out-LogOK "Explorador de Windows reiniciado."
    }

    if (-not $Quiet) {
        Write-Host "`n  Operación completada exitosamente." -ForegroundColor Cyan
    }
} catch {
    Out-LogError "Error durante la ejecución: $($_.Exception.Message)"
    exit 1
}
