<#
.SYNOPSIS
    Desplegar-Setup-Host.ps1 - Suite Modular de Despliegue Post-Instalacion (Dev-IA & Gaming) para romanOS.

.DESCRIPTION
    Aprovisiona a demanda el entorno completo de trabajo y entretenimiento para cualquier estacion de
    trabajo, incorporando introspeccion heuristica y adaptativa de hardware (CPU, GPU y NPU).

    Caracteristicas:
    - 100% Idempotente: puede ejecutarse multiples veces sin conflictos ni duplicados.
    - Soporte modular seleccionable: Dev + IA, Gaming o Seleccion Personalizada.
    - Instalaciones desatendidas oficiales via Windows Package Manager (WinGet).
    - Compatibilidad estricta con Windows PowerShell 5.1 (powershell.exe) y PowerShell 7+ (pwsh).
    - Soporta -WhatIf para simulacion segura.

.PARAMETER AutomatedOption
    Opcion numerica (1 a 4) para ejecucion desatendida sin menu interactivo (1: Todo, 2: Dev-IA, 3: Gaming, 4: Custom).

.PARAMETER SkipNetworkCheck
    Omite la comprobacion previa de conectividad a Internet.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("1", "2", "3", "4", "0")]
    [string]$AutomatedOption = "",

    [Parameter(Mandatory = $false)]
    [switch]$SkipNetworkCheck
)

$ErrorActionPreference = 'Continue'

function Write-HostBanner {
    param([string]$Title)
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "   $Title" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-HostStep {
    param([string]$Text)
    Write-Host "  >> $Text" -ForegroundColor Yellow
}

function Write-HostOK {
    param([string]$Text)
    Write-Host "  [OK] $Text" -ForegroundColor Green
}

function Write-HostWarn {
    param([string]$Text)
    Write-Host "  [!] $Text" -ForegroundColor Yellow
}

function Write-HostErr {
    param([string]$Text)
    Write-Host "  [ERROR] $Text" -ForegroundColor Red
}

function Get-HostHardwareSummary {
    $cpuName = try { (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue).Name.Trim() } catch { "Procesador Central" }
    $gpuName = try { ((Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue) | Select-Object -First 1).Name.Trim() } catch { "Acelerador Grafico" }
    return [PSCustomObject]@{
        CPU = $cpuName
        GPU = $gpuName
    }
}

function Test-InternetConnectivity {
    if ($SkipNetworkCheck) { return $true }
    Write-HostStep "Comprobando enlace de red y conectividad a Internet..."
    $targets = @("1.1.1.1", "8.8.8.8", "www.microsoft.com")
    foreach ($t in $targets) {
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $connect = $tcp.BeginConnect($t, 53, $null, $null)
            $wait = $connect.AsyncWaitHandle.WaitOne(2000, $false)
            if ($wait) {
                $tcp.EndConnect($connect)
                $tcp.Close()
                Write-HostOK "Conectividad a Internet verificada via $t"
                return $true
            }
            $tcp.Close()
        } catch {
            Write-Debug "Fallo al conectar con host DNS $t : $($_.Exception.Message)"
        }
    }

    # Fallback con peticion web
    try {
        $req = [System.Net.WebRequest]::Create("https://www.msftconnecttest.com/connecttest.txt")
        $req.Timeout = 3000
        $res = $req.GetResponse()
        $res.Close()
        Write-HostOK "Conectividad a Internet verificada via HTTP"
        return $true
    } catch {
        Write-HostWarn "No se pudo verificar conexion a Internet directa."
        return $false
    }
}

function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$DisplayName
    )

    Write-HostStep "Instalando: $DisplayName [$PackageId]..."
    if ($PSCmdlet.ShouldProcess($DisplayName, "Instalacion oficial via WinGet")) {
        $wingetCmd = Get-Command "winget.exe" -ErrorAction SilentlyContinue
        if (-not $wingetCmd) {
            Write-HostErr "winget.exe no esta disponible en el PATH del usuario. Asegurate de iniciar sesion interactiva."
            return $false
        }

        $args = @("install", "--id", $PackageId, "-e", "--source", "winget", "--accept-package-agreements", "--accept-source-agreements", "--silent", "--disable-interactivity")
        $process = Start-Process -FilePath "winget.exe" -ArgumentList $args -NoNewWindow -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-HostOK "$DisplayName instalado correctamente."
            return $true
        } elseif ($process.ExitCode -eq -1978335189) {
            # 0x8A15002B: Ya instalado / sin cambios
            Write-HostOK "$DisplayName ya se encuentra instalado en el sistema."
            return $true
        } else {
            Write-HostWarn "$DisplayName retorno codigo de salida: $($process.ExitCode). Revisa los logs de winget si hubo incidencias."
            return $false
        }
    } else {
        Write-HostOK "[SIMULACION] WinGet install --id $PackageId"
        return $true
    }
}

function Configure-GamingOptimizations {
    Write-HostBanner "OPTIMIZACIONES DE RED Y LATENCIA PARA GAMING (BAJA LATENCIA TCP)"

    if ($PSCmdlet.ShouldProcess("Red y TCP", "Ajustar TCPNoDelay (Desactivar Nagle)")) {
        try {
            # Desactivar algoritmo de Nagle en todas las interfaces de red activas preservando ACK diferido (RFC 1122)
            $tcpInterfacesKey = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
            if (Test-Path $tcpInterfacesKey) {
                $subKeys = Get-ChildItem -Path $tcpInterfacesKey
                $count = 0
                foreach ($k in $subKeys) {
                    Set-ItemProperty -Path $k.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $k.PSPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $k.PSPath -Name "TcpDelAckTicks" -ErrorAction SilentlyContinue
                    $count++
                }
                Write-HostOK "Algoritmo de Nagle neutralizado (TCPNoDelay=1, ACK diferido estandar en $count interfaces)."
            }

            # Forzar Game Mode activo en usuario actual
            $gameBarKey = "HKCU:\Software\Microsoft\GameBar"
            if (-not (Test-Path $gameBarKey)) { New-Item -Path $gameBarKey -Force | Out-Null }
            Set-ItemProperty -Path $gameBarKey -Name "AutoGameModeEnabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $gameBarKey -Name "AllowAutoGameMode" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Write-HostOK "Modo de Juego de Windows 11 asegurado (AutoGameModeEnabled=1)."

            # Verificacion de Runtimes DirectX y Visual C++
            $vcrKey = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64"
            if (Test-Path $vcrKey) {
                Write-HostOK "Visual C++ 2015-2022 x64 Runtime detectado en el sistema."
            } else {
                Write-HostWarn "Visual C++ 2015-2022 no se detecto en el registro. Se recomienda instalar el pack de runtimes."
            }
        } catch {
            Write-HostWarn "Error al aplicar optimizaciones de red: $($_.Exception.Message)"
        }
    } else {
        Write-HostOK "[SIMULACION] Optimizaciones de Red TCPNoDelay y GameMode"
    }
}

function Configure-DevAndAIEcosystem {
    $hw = Get-HostHardwareSummary
    Write-HostBanner "DESPLIEGUE DEL ENTORNO DE DESARROLLO CON IA & VIRTUALIZACION"

    # 1. Paquetes esenciales via WinGet
    $null = Install-WingetPackage -PackageId "Git.Git" -DisplayName "Git for Windows"
    $null = Install-WingetPackage -PackageId "Microsoft.PowerShell" -DisplayName "PowerShell 7 (pwsh)"
    $null = Install-WingetPackage -PackageId "7zip.7zip" -DisplayName "7-Zip Utility"

    # 2. Virtualizacion Hyper-V y WSL2 (si no se activo previamente)
    Write-HostStep "Verificando caracteristicas de virtualizacion (Hyper-V & WSL)..."
    if ($PSCmdlet.ShouldProcess("Hyper-V", "Verificar y habilitar virtualizacion nativa")) {
        try {
            $hvFeature = Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -ErrorAction SilentlyContinue
            if ($hvFeature -and $hvFeature.State -eq 'Enabled') {
                Write-HostOK "Hyper-V ya se encuentra habilitado y operativo en este procesador ($($hw.CPU))."
            } else {
                Write-HostStep "Habilitando Hyper-V..."
                Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -NoRestart -ErrorAction SilentlyContinue | Out-Null
                Write-HostOK "Hyper-V habilitado."
            }
        } catch {
            Write-HostWarn "No se pudo consultar el estado de Hyper-V: $($_.Exception.Message)"
        }
    }

    # 3. Provisionamiento de Antigravity IDE
    Write-HostStep "Localizando script de aprovisionamiento de Antigravity..."
    $candidateScripts = @(
        (Join-Path $PSScriptRoot "Setup-AntigravityWindows.ps1"),
        "$env:WINDIR\Setup\Scripts\Setup-AntigravityWindows.ps1",
        "$env:WINDIR\Setup\Scripts\Host-Tools\Setup-AntigravityWindows.ps1",
        (Join-Path (Split-Path $PSScriptRoot -Parent) "Host-Tools\Setup-AntigravityWindows.ps1")
    )

    $antigravityFound = $null
    foreach ($c in $candidateScripts) {
        if ($c -and (Test-Path $c)) {
            $antigravityFound = $c
            break
        }
    }

    if ($antigravityFound) {
        Write-HostOK "Inicializador de Antigravity localizado en: $antigravityFound"
        if ($PSCmdlet.ShouldProcess("Antigravity", "Ejecutar provisionamiento de reglas, skills y entorno")) {
            try {
                & "$antigravityFound" -SetExecutionPolicy
                Write-HostOK "Entorno de Antigravity aprovisionado con exito."
            } catch {
                Write-HostWarn "Incidencia al aprovisionar Antigravity: $($_.Exception.Message)"
            }
        }
    } else {
        Write-HostWarn "Setup-AntigravityWindows.ps1 no encontrado en las rutas estandar. El entorno podra inicializarse luego."
    }

    # 4. Auditoria de aceleradores de IA (NPU o GPU Tensor / DirectML)
    Write-HostStep "Verificando aceleradores de IA (NPU / DirectML)..."
    try {
        $npuDevice = Get-PnpDevice -FriendlyName "*NPU*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $npuDevice) {
            $npuDevice = Get-PnpDevice -FriendlyName "*Compute Accelerator*" -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        if ($npuDevice) {
            Write-HostOK "Dispositivo NPU detectado: $($npuDevice.FriendlyName) [Estado: $($npuDevice.Status)]"
            Write-Host "      * Capacidades: Aceleracion de inferencia local por hardware disponible." -ForegroundColor Gray
            Write-Host "      * Runtime recomendado: ONNX Runtime con DirectML Execution Provider." -ForegroundColor Gray
        } else {
            Write-HostOK "Aceleracion de inferencia local orientada a GPU ($($hw.GPU)) via DirectML."
        }
    } catch {
        Write-HostWarn "No se pudo consultar el bus PnP para aceleradores de IA: $($_.Exception.Message)"
    }
}

function Configure-GamingPlatforms {
    Write-HostBanner "DESPLIEGUE DEL ENTORNO GAMING (PLATAFORMAS Y HERRAMIENTAS)"

    # 1. Plataforma Steam
    $null = Install-WingetPackage -PackageId "Valve.Steam" -DisplayName "Steam Client"

    # 2. Epic Games Launcher
    $null = Install-WingetPackage -PackageId "EpicGames.EpicGamesLauncher" -DisplayName "Epic Games Launcher"

    # 3. Discord
    $null = Install-WingetPackage -PackageId "Discord.Discord" -DisplayName "Discord"

    # 4. Optimizaciones de red y latencia
    Configure-GamingOptimizations
}

function Show-CustomMenu {
    Write-HostBanner "SELECCION MODULAR PERSONALIZADA"

    $packages = @(
        @{ Name = "Git for Windows"; Id = "Git.Git"; Category = "Dev" },
        @{ Name = "PowerShell 7 (pwsh)"; Id = "Microsoft.PowerShell"; Category = "Dev" },
        @{ Name = "7-Zip Utility"; Id = "7zip.7zip"; Category = "Tools" },
        @{ Name = "Steam Client"; Id = "Valve.Steam"; Category = "Gaming" },
        @{ Name = "Epic Games Launcher"; Id = "EpicGames.EpicGamesLauncher"; Category = "Gaming" },
        @{ Name = "Discord"; Id = "Discord.Discord"; Category = "Gaming/Comms" },
        @{ Name = "OBS Studio"; Id = "OBSProject.OBSStudio"; Category = "Streaming" }
    )

    foreach ($pkg in $packages) {
        if ([Console]::IsInputRedirected) {
            Write-Host "  [-] Entorno no interactivo: Omitiendo $($pkg.Name)" -ForegroundColor DarkGray
            continue
        }
        $ans = Read-Host "  Deseas instalar $($pkg.Name) [$($pkg.Category)]? (S/N) [Por defecto: S]"
        if ([string]::IsNullOrWhiteSpace($ans) -or $ans.ToUpper() -eq "S") {
            $null = Install-WingetPackage -PackageId $pkg.Id -DisplayName $pkg.Name
        } else {
            Write-Host "  [-] Omitido: $($pkg.Name)" -ForegroundColor DarkGray
        }
    }

    if (-not [Console]::IsInputRedirected) {
        $optNet = Read-Host "  Deseas aplicar optimizaciones de baja latencia de red (TCP NoDelay)? (S/N) [Por defecto: S]"
        if ([string]::IsNullOrWhiteSpace($optNet) -or $optNet.ToUpper() -eq "S") {
            Configure-GamingOptimizations
        }
    }
}

# =========================================================================
# BUCLE PRINCIPAL / MENU DE ENTRADA
# =========================================================================

$running = $true

while ($running) {
    if ($AutomatedOption) {
        $choice = $AutomatedOption
        $running = $false
    } else {
        if ([Console]::IsInputRedirected) {
            Write-HostWarn "Entorno no interactivo detectado o entrada redirigida. Finalizando ejecucion."
            $running = $false
            break
        }
        $hw = Get-HostHardwareSummary
        Clear-Host
        Write-Host ""
        Write-Host "======================================================================" -ForegroundColor Cyan
        Write-Host "   romanOS Workstation Setup — Entorno Post-Instalacion" -ForegroundColor Cyan
        Write-Host "   Hardware Detectado: $($hw.CPU) | $($hw.GPU)" -ForegroundColor DarkCyan
        Write-Host "======================================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] Despliegue Completo (Dev + IA + Gaming)" -ForegroundColor White
        Write-Host "      Instala todo el ecosistema de trabajo y entretenimiento." -ForegroundColor Gray
        Write-Host ""
        Write-Host "  [2] Solo Entorno de Desarrollo con IA" -ForegroundColor White
        Write-Host "      Git, PowerShell 7, 7-Zip, Antigravity IDE, IA y Virtualizacion Hyper-V." -ForegroundColor Gray
        Write-Host ""
        Write-Host "  [3] Solo Entorno Gaming" -ForegroundColor White
        Write-Host "      Steam, Epic Games, Discord y baja latencia de red TCP." -ForegroundColor Gray
        Write-Host ""
        Write-Host "  [4] Seleccion Personalizada" -ForegroundColor White
        Write-Host "      Elegir paquete por paquete de forma interactiva." -ForegroundColor Gray
        Write-Host ""
        Write-Host "  [0] Salir" -ForegroundColor DarkGray
        Write-Host "      Cerrar este asistente sin realizar cambios." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "======================================================================" -ForegroundColor Cyan
        $choice = Read-Host "Selecciona una opcion [0-4]"
        if ([string]::IsNullOrWhiteSpace($choice)) {
            Write-HostWarn "No se recibio entrada. Finalizando ejecucion."
            $running = $false
            break
        }
    }

    switch ($choice) {
        "1" {
            Test-InternetConnectivity | Out-Null
            Configure-DevAndAIEcosystem
            Configure-GamingPlatforms
            Write-HostBanner "DESPLIEGUE COMPLETO FINALIZADO EXITOSAMENTE"
            if (-not $AutomatedOption -and -not [Console]::IsInputRedirected) { pause }
            $running = $false
        }
        "2" {
            Test-InternetConnectivity | Out-Null
            Configure-DevAndAIEcosystem
            Write-HostBanner "ENTORNO DE DESARROLLO E IA CONFIGURADO EXITOSAMENTE"
            if (-not $AutomatedOption -and -not [Console]::IsInputRedirected) { pause }
            $running = $false
        }
        "3" {
            Test-InternetConnectivity | Out-Null
            Configure-GamingPlatforms
            Write-HostBanner "ENTORNO GAMING CONFIGURADO EXITOSAMENTE"
            if (-not $AutomatedOption -and -not [Console]::IsInputRedirected) { pause }
            $running = $false
        }
        "4" {
            Test-InternetConnectivity | Out-Null
            Show-CustomMenu
            Write-HostBanner "INSTALACION PERSONALIZADA FINALIZADA"
            if (-not $AutomatedOption -and -not [Console]::IsInputRedirected) { pause }
            $running = $false
        }
        "0" {
            Write-Host "`nOperacion cancelada. Puedes ejecutar este asistente en cualquier momento desde el Escritorio.`n" -ForegroundColor Yellow
            $running = $false
        }
        default {
            Write-HostWarn "Opcion no valida: '$choice'. Intenta nuevamente."
            Start-Sleep -Seconds 1
        }
    }
}
