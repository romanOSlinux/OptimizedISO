<#
.SYNOPSIS
    romanOS Control Center - Interfaz Gráfica Nativa (WPF / XAML)
    Hub Maestro de Optimización, Gaming, Mantenimiento, Red y Seguridad

.DESCRIPTION
    Panel de control unificado y desacoplado (Zero-Resident Footprint) para la suite romanOS.
    Proporciona telemetría de hardware en tiempo real, conmutador bimodal Gaming vs Dev,
    limpieza profunda DISM/WinSxS, poda de memoria RAM, optimización de red con benchmark DNS,
    hardening de seguridad y gestión de controladores, con streaming asíncrono a 60 FPS.

.EXAMPLE
    .\romanOS-ControlCenter.ps1

.EXAMPLE
    .\romanOS-ControlCenter.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$SkipElevation,
    [switch]$Unattended
)


# -----------------------------------------------------------------------------
# 0. CONFIGURACIÓN DE ENTORNO Y AUTO-ELEVACIÓN UAC
# -----------------------------------------------------------------------------
$ErrorActionPreference = 'Continue'
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop } catch {
    Write-Warning "[romanOS-ControlCenter] No se pudo establecer ExecutionPolicy: $($_.Exception.Message)"
}

$isSimulated = ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf') -or $WhatIfPreference)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $SkipElevation -and -not $isSimulated) {
    $shouldElevate = if ($PSCmdlet) { $PSCmdlet.ShouldProcess("powershell.exe", "Auto-elevar privilegios de Administrador UAC") } else { $true }
    if ($shouldElevate) {
        $targetScript = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-WindowStyle Hidden -STA -NoProfile -ExecutionPolicy Bypass -File `"$targetScript`""
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $psi.Verb = "runas"
        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
            exit 0
        } catch {
            Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
            [System.Windows.MessageBox]::Show(
                "romanOS Control Center requiere privilegios de Administrador para aplicar optimizaciones de sistema.`n`nPor favor autorice la elevación UAC.",
                "romanOS Control Center - Elevación Requerida",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning
            )
            exit 1
        }
    }
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Resolucion robusta de rutas base
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $scriptRoot -or -not (Test-Path $scriptRoot)) {
    $scriptRoot = "C:\OptimizedISO\scripts\GUI"
}

# Inicializacion de logs locales
$logDir = Join-Path $scriptRoot "..\..\Log"
if (-not (Test-Path $logDir)) {
    try { New-Item -ItemType Directory -Path $logDir -Force | Out-Null } catch {
        Write-Warning "[romanOS-ControlCenter] No se pudo crear directorio de logs ($logDir) - $($_.Exception.Message)"
    }
}
$script:ControlCenterLogPath = if (Test-Path $logDir) {
    Join-Path $logDir "romanOS-ControlCenter_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
} else {
    Join-Path $env:TEMP "romanOS-ControlCenter_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
}

function Write-CCLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    try { Out-File -FilePath $script:ControlCenterLogPath -InputObject $line -Append -Encoding UTF8 -ErrorAction Stop } catch {
        Write-Warning "[romanOS-ControlCenter] No se pudo escribir en log: $($_.Exception.Message)"
    }
}

Write-CCLog "Iniciando sesion de romanOS Control Center GUI"

# -----------------------------------------------------------------------------
# 1. CARGA DE MOTORES CORE (SSOT)
# -----------------------------------------------------------------------------
$repoScriptsRoot = if ($scriptRoot) { Split-Path $scriptRoot -Parent } else { "C:\OptimizedISO\scripts" }

$script:coreEngineDirs = @()
if ($repoScriptsRoot -and (Test-Path $repoScriptsRoot)) {
    $script:coreEngineDirs += (Join-Path $repoScriptsRoot "Core")
    $parentOfScripts = Split-Path $repoScriptsRoot -Parent
    if ($parentOfScripts -and (Test-Path $parentOfScripts)) {
        $script:coreEngineDirs += (Join-Path $parentOfScripts "scripts\Core")
    }
}
if ($scriptRoot -and (Test-Path $scriptRoot)) {
    $script:coreEngineDirs += (Join-Path $scriptRoot "Core")
    $script:coreEngineDirs += (Join-Path $scriptRoot "..\Core")
}
$script:coreEngineDirs += @(
    "C:\Windows\Setup\Scripts\Core",
    "$env:WINDIR\Setup\Scripts\Core",
    "C:\OptimizedISO\scripts\Core"
)

function Resolve-CoreModule {
    param([string]$ModuleName)
    foreach ($d in $script:coreEngineDirs) {
        if ($d -and (Test-Path $d)) {
            $candidate = Join-Path $d $ModuleName
            if (Test-Path $candidate) {
                return (Resolve-Path $candidate).Path
            }
        }
    }
    return $null
}

# Carga de Motores Core en el scope del script (dot-sourcing directo)
$uiEnginePath = Resolve-CoreModule "UI-Engine.ps1"
if ($uiEnginePath) {
    try {
        . $uiEnginePath
        Write-CCLog "Cargado modulo Core: $uiEnginePath"
    } catch {
        Write-CCLog "Error al cargar UI-Engine ($uiEnginePath): $($_.Exception.Message)" -Level "WARN"
    }
}

$hwEnginePath = Resolve-CoreModule "Hardware-Engine.ps1"
if ($hwEnginePath) {
    try {
        . $hwEnginePath
        Write-CCLog "Cargado modulo Core: $hwEnginePath"
    } catch {
        Write-CCLog "Error al cargar Hardware-Engine ($hwEnginePath): $($_.Exception.Message)" -Level "WARN"
    }
}

$policyEnginePath = Resolve-CoreModule "Policy-Engine.ps1"
if ($policyEnginePath) {
    try {
        . $policyEnginePath
        Write-CCLog "Cargado modulo Core: $policyEnginePath"
    } catch {
        Write-CCLog "Error al cargar Policy-Engine ($policyEnginePath): $($_.Exception.Message)" -Level "WARN"
    }
}

# Resolutor de scripts dependientes
$script:searchDirs = @()
if ($repoScriptsRoot -and (Test-Path $repoScriptsRoot)) {
    $script:searchDirs += @(
        (Join-Path $repoScriptsRoot "Modules"),
        (Join-Path $repoScriptsRoot "Desktop-Helpers"),
        (Join-Path $repoScriptsRoot "Drivers"),
        (Join-Path $repoScriptsRoot "Builder"),
        (Join-Path $repoScriptsRoot "Host-Tools")
    )
    $parentOfScripts = Split-Path $repoScriptsRoot -Parent
    if ($parentOfScripts -and (Test-Path $parentOfScripts)) {
        $script:searchDirs += @(
            (Join-Path $parentOfScripts "scripts\Modules"),
            (Join-Path $parentOfScripts "scripts\Desktop-Helpers"),
            (Join-Path $parentOfScripts "scripts\Drivers"),
            (Join-Path $parentOfScripts "scripts\Builder"),
            (Join-Path $parentOfScripts "scripts\Core"),
            (Join-Path $parentOfScripts "scripts\Testing")
        )
    }
}
$desktopHelpersModule = Resolve-CoreModule "..\Modules\Desktop-Helpers.ps1"
if (-not $desktopHelpersModule -and $repoScriptsRoot) {
    $cand = Join-Path $repoScriptsRoot "Modules\Desktop-Helpers.ps1"
    if (Test-Path $cand) { $desktopHelpersModule = (Resolve-Path $cand).Path }
}
if ($desktopHelpersModule -and (Test-Path $desktopHelpersModule)) {
    try {
        . $desktopHelpersModule -Quiet
        Write-CCLog "Cargado modulo Desktop-Helpers: $desktopHelpersModule"
    } catch {
        Write-CCLog "Error al cargar Desktop-Helpers: $($_.Exception.Message)" -Level "WARN"
    }
}
if ($scriptRoot -and (Test-Path $scriptRoot)) {
    $script:searchDirs += $scriptRoot
}
$script:searchDirs += @(
    "$env:WINDIR\Setup\Scripts",
    "$env:WINDIR\Setup\Scripts\Modules",
    "$env:WINDIR\Setup\Scripts\Core",
    "$env:WINDIR\Setup\Scripts\Drivers",
    "$env:WINDIR\Setup\Scripts\Builder",
    "$env:WINDIR\Setup\Scripts\DesktopHelpers",
    "C:\Windows\Setup\Scripts",
    "C:\Windows\Setup\Scripts\Modules",
    "C:\Windows\Setup\Scripts\Core",
    "C:\Windows\Setup\Scripts\Drivers",
    "C:\Windows\Setup\Scripts\Builder",
    "C:\Windows\Setup\Scripts\DesktopHelpers",
    "C:\Users\Public\Desktop\romanOS Helpers",
    "C:\OptimizedISO\scripts\Modules",
    "C:\OptimizedISO\scripts\Drivers",
    "C:\OptimizedISO\scripts\Core",
    "C:\OptimizedISO\scripts\Testing",
    "C:\OptimizedISO\scripts\Builder",
    "C:\OptimizedISO\scripts\Desktop-Helpers"
)

function Resolve-ToolScript {
    param([string]$ScriptName)
    foreach ($dir in $script:searchDirs) {
        if ($dir -and (Test-Path $dir)) {
            $candidate = Join-Path $dir $ScriptName
            if (Test-Path $candidate) {
                return (Resolve-Path $candidate).Path
            }
        }
    }
    return $null
}

# Precarga de módulos de funciones (dot-sourcing temprano con guardias de retorno)
$netOptimizerModule = Resolve-ToolScript "Win11-Network-Diagnostics-Optimizer.ps1"
if ($netOptimizerModule -and (Test-Path $netOptimizerModule)) {
    try {
        . $netOptimizerModule -Quiet
        Write-CCLog "Cargado modulo Network-Diagnostics-Optimizer: $netOptimizerModule"
    } catch {
        Write-CCLog "Error al precargar Network-Diagnostics-Optimizer: $($_.Exception.Message)" -Level "WARN"
    }
}

$deployAppsModule = Resolve-ToolScript "Deploy-AppProfiles.ps1"
if ($deployAppsModule -and (Test-Path $deployAppsModule)) {
    try {
        . $deployAppsModule -SkipElevation
        Write-CCLog "Cargado modulo Deploy-AppProfiles: $deployAppsModule"
    } catch {
        Write-CCLog "Error al precargar Deploy-AppProfiles: $($_.Exception.Message)" -Level "WARN"
    }
}

# -----------------------------------------------------------------------------
# 2. DEFINICION XAML DE LA INTERFAZ (WPF)
# -----------------------------------------------------------------------------
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="romanOS Control Center" Height="720" Width="940"
        Background="{DynamicResource WindowBgBrush}" WindowStartupLocation="CenterScreen"
        FontFamily="Segoe UI" MinHeight="640" MinWidth="860">
    <Window.Resources>
        <SolidColorBrush x:Key="WindowBgBrush" Color="#0D1117"/>
        <SolidColorBrush x:Key="HeaderBgBrush" Color="#161B22"/>
        <SolidColorBrush x:Key="HeaderBorderBrush" Color="#21262D"/>
        <SolidColorBrush x:Key="CardBgBrush" Color="#161B22"/>
        <SolidColorBrush x:Key="CardBorderBrush" Color="#30363D"/>
        <SolidColorBrush x:Key="ButtonBgBrush" Color="#21262D"/>
        <SolidColorBrush x:Key="ButtonBorderBrush" Color="#363D47"/>
        <SolidColorBrush x:Key="ButtonFgBrush" Color="#F0F6FC"/>
        <SolidColorBrush x:Key="ButtonHoverBgBrush" Color="#30363D"/>
        <SolidColorBrush x:Key="TextPrimaryBrush" Color="#F0F6FC"/>
        <SolidColorBrush x:Key="TextSecondaryBrush" Color="#8B949E"/>
        <SolidColorBrush x:Key="TabBgBrush" Color="#161B22"/>
        <SolidColorBrush x:Key="TabBorderBrush" Color="#21262D"/>
        <SolidColorBrush x:Key="TabSelectedBgBrush" Color="#21262D"/>
        <SolidColorBrush x:Key="TabSelectedFgBrush" Color="#00E5FF"/>
        <SolidColorBrush x:Key="ConsoleBgBrush" Color="#0A0D12"/>
        <SolidColorBrush x:Key="ConsoleBorderBrush" Color="#21262D"/>
        <SolidColorBrush x:Key="AccentPrimaryBrush" Color="#00E5FF"/>
        <SolidColorBrush x:Key="AccentSecondaryBrush" Color="#00E676"/>
        <SolidColorBrush x:Key="AccentWarningBrush" Color="#F59E0B"/>
        <SolidColorBrush x:Key="AccentDevBrush" Color="#A855F7"/>
        <SolidColorBrush x:Key="AccentDangerBrush" Color="#FF4444"/>
        <SolidColorBrush x:Key="AccentAuditBgBrush" Color="#102A38"/>
        <SolidColorBrush x:Key="AccentSuccessBgBrush" Color="#102B1E"/>
        <SolidColorBrush x:Key="AccentWarningBgBrush" Color="#33220A"/>

        <Style TargetType="Button">
            <Setter Property="Background" Value="{DynamicResource ButtonBgBrush}"/>
            <Setter Property="Foreground" Value="{DynamicResource ButtonFgBrush}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource ButtonBorderBrush}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,6"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}" 
                                CornerRadius="4">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.35" />
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="{DynamicResource ButtonHoverBgBrush}" />
                                <Setter Property="BorderBrush" Value="{DynamicResource AccentPrimaryBrush}" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    
    <Grid>
        <!-- Header Superior -->
        <Border Background="{DynamicResource HeaderBgBrush}" Height="65" VerticalAlignment="Top" BorderBrush="{DynamicResource HeaderBorderBrush}" BorderThickness="0,0,0,1">
            <Grid Margin="20,0">
                <StackPanel VerticalAlignment="Center" HorizontalAlignment="Left">
                    <TextBlock Text="romanOS Control Center" Foreground="{DynamicResource TextPrimaryBrush}" FontSize="20" FontWeight="Bold"/>
                    <TextBlock Text="Hub Maestro de Optimizacion, Gaming, Red y SysAdmin" Foreground="{DynamicResource AccentPrimaryBrush}" FontSize="11"/>
                </StackPanel>
                <StackPanel VerticalAlignment="Center" HorizontalAlignment="Right" Orientation="Horizontal">
                    <Border Background="{DynamicResource WindowBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="6,3" Margin="0,0,10,0">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock Text="ðŸŽ¨ " FontSize="11" VerticalAlignment="Center"/>
                            <TextBlock Text="Tema: " Foreground="{DynamicResource TextSecondaryBrush}" FontSize="11" VerticalAlignment="Center" Margin="0,0,4,0"/>
                            <ComboBox x:Name="cmbThemeSelector" Width="180" Height="22" Background="{DynamicResource CardBgBrush}" Foreground="{DynamicResource TextPrimaryBrush}" BorderBrush="{DynamicResource CardBorderBrush}" FontSize="11" VerticalAlignment="Center">
                                <ComboBoxItem Content="Cyber-Stealth (OpciÃ³n 1)" Tag="CyberStealth" IsSelected="True"/>
                                <ComboBoxItem Content="Imperial Crimson (OpciÃ³n 2)" Tag="ImperialCrimson"/>
                                <ComboBoxItem Content="OLED Midnight (OpciÃ³n 3)" Tag="OLEDMidnight"/>
                                <ComboBoxItem Content="Classic Charcoal (Original)" Tag="ClassicCharcoal"/>
                            </ComboBox>
                        </StackPanel>
                    </Border>
                    <Border Background="{DynamicResource WindowBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="10,5">
                        <TextBlock x:Name="lblHwBadge" Text="Cargando telemetria..." Foreground="{DynamicResource AccentSecondaryBrush}" FontSize="11" FontWeight="SemiBold"/>
                    </Border>
                </StackPanel>
            </Grid>
        </Border>

        <!-- Contenido Central / TabControl -->
        <TabControl x:Name="tabControlMain" Margin="10,75,10,55" Background="{DynamicResource WindowBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" Foreground="{DynamicResource TextPrimaryBrush}">
            <TabControl.Resources>
                <Style TargetType="TabItem">
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="TabItem">
                                <Border Name="Border" BorderThickness="1,1,1,0" BorderBrush="{DynamicResource CardBorderBrush}" Margin="2,0" Background="{DynamicResource HeaderBgBrush}">
                                    <ContentPresenter x:Name="ContentSite" VerticalAlignment="Center" HorizontalAlignment="Center" ContentSource="Header" Margin="14,8"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsSelected" Value="True">
                                        <Setter TargetName="Border" Property="Background" Value="{DynamicResource ButtonBgBrush}" />
                                        <Setter Property="Foreground" Value="{DynamicResource AccentPrimaryBrush}"/>
                                    </Trigger>
                                    <Trigger Property="IsSelected" Value="False">
                                        <Setter TargetName="Border" Property="Background" Value="{DynamicResource WindowBgBrush}" />
                                        <Setter Property="Foreground" Value="{DynamicResource TextSecondaryBrush}"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                    <Setter Property="FontSize" Value="12"/>
                    <Setter Property="FontWeight" Value="SemiBold"/>
                </Style>
            </TabControl.Resources>

            <!-- Pestaña 1: Dashboard -->
            <TabItem Header="Dashboard">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="5">
                    <StackPanel Margin="10">
                        <!-- Tarjeta Telemetría de Hardware -->
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="Telemetria de Hardware en Vivo" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="160"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="160"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="24"/>
                                        <RowDefinition Height="24"/>
                                        <RowDefinition Height="24"/>
                                        <RowDefinition Height="24"/>
                                        <RowDefinition Height="24"/>
                                    </Grid.RowDefinitions>

                                    <TextBlock Grid.Row="0" Grid.Column="0" Text="Procesador (CPU):" Foreground="#A0A0A0"/>
                                    <TextBlock Grid.Row="0" Grid.Column="1" x:Name="lblCpuInfo" Text="Detectando..." Foreground="#FFFFFF" FontWeight="SemiBold"/>

                                    <TextBlock Grid.Row="0" Grid.Column="2" Text="Nucleos / Hilos:" Foreground="#A0A0A0"/>
                                    <TextBlock Grid.Row="0" Grid.Column="3" x:Name="lblCoresInfo" Text="Detectando..." Foreground="#FFFFFF" FontWeight="SemiBold"/>

                                    <TextBlock Grid.Row="1" Grid.Column="0" Text="Memoria RAM:" Foreground="#A0A0A0"/>
                                    <TextBlock Grid.Row="1" Grid.Column="1" x:Name="lblRamInfo" Text="Detectando..." Foreground="#FFFFFF" FontWeight="SemiBold"/>

                                    <TextBlock Grid.Row="1" Grid.Column="2" Text="Almacenamiento C: :" Foreground="#A0A0A0"/>
                                    <TextBlock Grid.Row="1" Grid.Column="3" x:Name="lblDiskInfo" Text="Detectando..." Foreground="#FFFFFF" FontWeight="SemiBold"/>

                                    <TextBlock Grid.Row="2" Grid.Column="0" Text="Graficos (GPU):" Foreground="#A0A0A0"/>
                                    <TextBlock Grid.Row="2" Grid.Column="1" x:Name="lblGpuInfo" Text="Detectando..." Foreground="#FFFFFF" FontWeight="SemiBold"/>

                                    <TextBlock Grid.Row="2" Grid.Column="2" Text="Plataforma AI PC:" Foreground="#A0A0A0"/>
                                    <TextBlock Grid.Row="2" Grid.Column="3" x:Name="lblAiPcInfo" Text="Detectando..." Foreground="#FFFFFF" FontWeight="SemiBold"/>

                                    <TextBlock Grid.Row="3" Grid.Column="0" Text="Modo MSI en GPU:" Foreground="#A0A0A0"/>
                                    <TextBlock Grid.Row="3" Grid.Column="1" x:Name="lblMsiInfo" Text="Detectando..." Foreground="#00E676" FontWeight="SemiBold"/>

                                    <TextBlock Grid.Row="3" Grid.Column="2" Text="Soporte HAGS:" Foreground="#A0A0A0"/>
                                    <TextBlock Grid.Row="3" Grid.Column="3" x:Name="lblHagsInfo" Text="Detectando..." Foreground="#00E676" FontWeight="SemiBold"/>

                                    <TextBlock Grid.Row="4" Grid.Column="0" Text="DirectStorage / BypassIO:" Foreground="#A0A0A0"/>
                                    <TextBlock Grid.Row="4" Grid.Column="1" x:Name="lblBypassIoInfo" Text="Detectando..." Foreground="#00E676" FontWeight="SemiBold"/>

                                    <TextBlock Grid.Row="4" Grid.Column="2" Text="Red NDIS / UDP RSC:" Foreground="#A0A0A0"/>
                                    <TextBlock Grid.Row="4" Grid.Column="3" x:Name="lblNetOffloadInfo" Text="Detectando..." Foreground="#00E676" FontWeight="SemiBold"/>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <!-- Tarjeta Acciones Rapidas -->
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14">
                            <StackPanel>
                                <TextBlock Text="Acciones Rapidas de Sistema (1-Clic)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,12"/>
                                <WrapPanel Margin="0,0,0,6">
                                    <Button x:Name="btnQuickTrim" Content="Podar RAM (EmptyWorkingSet)" Width="230" Margin="0,0,10,10" Background="{DynamicResource AccentSuccessBgBrush}" BorderBrush="{DynamicResource AccentSecondaryBrush}"/>
                                    <Button x:Name="btnQuickFlushDns" Content="Vaciar Cache DNS" Width="180" Margin="0,0,10,10"/>
                                    <Button x:Name="btnQuickRestartExplorer" Content="Reiniciar Explorador" Width="180" Margin="0,0,10,10"/>
                                    <Button x:Name="btnQuickGodMode" Content="Abrir God Mode" Width="150" Margin="0,0,10,10"/>
                                    <Button x:Name="btnQuickSfc" Content="Reparar Imagen (DISM / SFC)" Width="210" Margin="0,0,10,10"/>
                                    <Button x:Name="btnQuickShaders" Content="Purgar Shaders GPU" Width="180" Margin="0,0,10,10"/>
                                    <Button x:Name="btnQuickTrimSSD" Content="Ejecutar SSD TRIM" Width="160" Margin="0,0,10,10"/>
                                    <Button x:Name="btnQuickAudit" Content="Auditar Salud Completa" Width="200" Margin="0,0,10,10" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}"/>
                                    <Button x:Name="btnQuickLatency" Content="Test Latencia DPC (µs)" Width="190" Margin="0,0,10,10" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}"/>
                                    <Button x:Name="btnQuickStorageAudit" Content="Auditar BypassIO &amp; Storage" Width="200" Margin="0,0,10,10" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}"/>
                                    <Button x:Name="btnQuickNetAudit" Content="Auditar Red NDIS &amp; UDP RSC" Width="210" Margin="0,0,10,10" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}"/>
                                    <Button x:Name="btnQuickSnapshot" Content="Crear Snapshot de Seguridad" Width="220" Margin="0,0,10,10" Background="{DynamicResource AccentSuccessBgBrush}" BorderBrush="{DynamicResource AccentSecondaryBrush}"/>
                                    <Button x:Name="btnQuickAffinity" Content="Auditar Afinidad IRQ / PCIe" Width="210" Margin="0,0,10,10" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}"/>
                                    <Button x:Name="btnQuickFootprint" Content="Auditar Huella RAM / Procesos" Width="230" Margin="0,0,10,10" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}"/>
                                    <Button x:Name="btnQuickRestoreServices" Content="Restaurar Servicios (Wi-Fi/BT)" Width="230" Margin="0,0,10,10"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>

                        <!-- Asistentes de Escritorio romanOS (Inspiracion Atlas/ReviOS) -->
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="Asistentes Modulares de Escritorio (Desktop Helpers)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,6"/>
                                <TextBlock Text="Conmutadores rapidos para activar o pausar servicios bajo demanda sin alterar las invariantes criticas del sistema." Foreground="#A0A0A0" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,12"/>
                                <WrapPanel Margin="0,0,0,6">
                                    <Button x:Name="btnHelperWU" Content="Windows Update: ..." Width="220" Margin="0,0,10,10"/>
                                    <Button x:Name="btnHelperDefender" Content="Microsoft Defender: ..." Width="220" Margin="0,0,10,10"/>
                                    <Button x:Name="btnHelperBluetooth" Content="Bluetooth: ..." Width="190" Margin="0,0,10,10"/>
                                    <Button x:Name="btnHelperPrinting" Content="Impresion / Spooler: ..." Width="200" Margin="0,0,10,10"/>
                                    <Button x:Name="btnHelperSharing" Content="Compartir Archivos: ..." Width="210" Margin="0,0,10,10"/>
                                    <Button x:Name="btnHelperVBS" Content="VBS / Aislamiento: ..." Width="210" Margin="0,0,10,10"/>
                                    <Button x:Name="btnHelperRecall" Content="Windows Recall: ..." Width="210" Margin="0,0,10,10"/>
                                    <Button x:Name="btnAuditInvariants" Content="Auditar Invariantes romanOS" Width="230" Margin="0,0,10,10" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}"/>
                                    <Button x:Name="btnOpenHelpersFolder" Content="Abrir Carpeta Helpers" Width="180" Margin="0,0,10,10"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- Pestaña 2: Gaming & Bimodal -->
            <TabItem Header="Gaming &amp; Bimodal">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="5">
                    <StackPanel Margin="10">
                        <!-- Conmutador Bimodal -->
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="Conmutador de Recursos romanOS (Switch Game / Dev)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,6"/>
                                <TextBlock Text="Permite alternar dinamicamente entre maxima liberacion de memoria para gaming (APU/GPU) y un entorno de trabajo con virtualizacion activa." Foreground="#A0A0A0" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,12"/>
                                
                                <Grid Margin="0,0,0,10">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="15"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="15"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <!-- Card Modo Juego Agresivo -->
                                    <Border Grid.Column="0" Background="#1E2822" BorderBrush="#00E676" BorderThickness="1" CornerRadius="4" Padding="10">
                                        <StackPanel>
                                            <TextBlock Text="MODO JUEGO AGRESIVO" Foreground="#00E676" FontWeight="Bold" FontSize="12" Margin="0,0,0,4"/>
                                            <TextBlock Text="Corta devoradores de RAM, suspende Hyper-V/WSL2/Docker y realiza poda de memoria profunda para GPU/VRAM." Foreground="#A0A0A0" FontSize="10" TextWrapping="Wrap" Margin="0,0,0,10" Height="45"/>
                                            <Button x:Name="btnGameAggressive" Content="Activar Modo Agresivo" Background="#1B4D3E" BorderBrush="#00E676" FontWeight="SemiBold"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Card Modo Juego Ligero -->
                                    <Border Grid.Column="2" Background="#1E2530" BorderBrush="#00E5FF" BorderThickness="1" CornerRadius="4" Padding="10">
                                        <StackPanel>
                                            <TextBlock Text="MODO JUEGO LIGERO" Foreground="#00E5FF" FontWeight="Bold" FontSize="12" Margin="0,0,0,4"/>
                                            <TextBlock Text="Optimizacion de latencia estandar. Mantiene servicios activos sin apagar Hyper-V ni entornos de desarrollo." Foreground="#A0A0A0" FontSize="10" TextWrapping="Wrap" Margin="0,0,0,10" Height="45"/>
                                            <Button x:Name="btnGameLight" Content="Activar Modo Ligero" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}" FontWeight="SemiBold"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Card Modo Dev -->
                                    <Border Grid.Column="4" Background="#2D2230" BorderBrush="#E040FB" BorderThickness="1" CornerRadius="4" Padding="10">
                                        <StackPanel>
                                            <TextBlock Text="MODO DEV / TRABAJO" Foreground="#E040FB" FontWeight="Bold" FontSize="12" Margin="0,0,0,4"/>
                                            <TextBlock Text="Restaura instantaneamente hipervisor, WSL2, Docker, colas de impresion, busqueda y servicios para desarrollo de software." Foreground="#A0A0A0" FontSize="10" TextWrapping="Wrap" Margin="0,0,0,10" Height="45"/>
                                            <Button x:Name="btnDevMode" Content="Activar Modo Dev" Background="#4A1E4D" BorderBrush="#E040FB" FontWeight="SemiBold"/>
                                        </StackPanel>
                                    </Border>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <!-- Thermal & Energy Profiler -->
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="romanOS Thermal &amp; Energy Profiler (Throttling Shield &amp; Core Unparking)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,6"/>
                                <TextBlock Text="Diagnostico forense de estrangulamiento termico/energetico (PROCHOT / Clock Stretching), calibracion de energia y des-estacionamiento de nucleos." Foreground="#A0A0A0" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,10"/>
                                <WrapPanel>
                                    <Button x:Name="btnAuditThermal" Content="Auditar Estado Termico &amp; Throttling" Width="260" Margin="0,0,10,10"/>
                                    <Button x:Name="btnLiveThermalMonitor" Content="Monitoreo en Vivo (5s)" Width="190" Margin="0,0,10,10"/>
                                    <Button x:Name="btnCalibrateUltimateEnergy" Content="Calibrar Maximo Rendimiento (Core Unpark)" Width="290" Margin="0,0,10,10" Background="#1B4D3E" BorderBrush="#00E676" FontWeight="SemiBold"/>
                                    <Button x:Name="btnAuditWakeTimers" Content="Auditar Wake Timers &amp; S0ix" Width="220" Margin="0,0,10,10" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}"/>
                                    <Button x:Name="btnDisableWakeTimers" Content="Neutralizar Wake Timers Parásitos" Width="240" Margin="0,0,10,10" Background="#3D2D1B" BorderBrush="#FFB300" FontWeight="SemiBold"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>

                        <!-- Tarjeta romanOS PCIe Interrupt Affinity & IRQ Priority (DPC Steering) -->
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="Calibrador de Afinidad PCIe e Interrupciones IRQ (DPC Steering &amp; MSI Tuning)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,6"/>
                                <TextBlock Text="Optimiza la distribucion de interrupciones de hardware en la topologia PCIe: eleva la prioridad IRQ de GPU/NVMe a Alta, aisla la GPU del Core 0 y mitiga DPC latency/micro-stuttering." Foreground="#A0A0A0" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,10"/>
                                <WrapPanel>
                                    <Button x:Name="btnAuditAffinityGUI" Content="Auditar Topologia &amp; Afinidad IRQ" Width="260" Margin="0,0,10,10"/>
                                    <Button x:Name="btnOptimizeAffinityGUI" Content="Calibrar Afinidad y DPC Steering (1-Clic)" Width="290" Margin="0,0,10,10" Background="#1B4D3E" BorderBrush="#00E676" FontWeight="SemiBold"/>
                                    <Button x:Name="btnResetAffinityGUI" Content="Restaurar Politicas IRQ por Defecto" Width="260" Margin="0,0,10,10" Background="#3E2723" BorderBrush="#FF5252"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>

                        <!-- Optimizaciones Gaming Adicionales -->
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="Ajustes de Latencia y Debloat Adaptativo" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                                <WrapPanel>
                                    <Button x:Name="btnToggleHypervisor" Content="Alternar Hipervisor (VBS / Ring 0)" Width="250" Margin="0,0,10,10"/>
                                    <Button x:Name="btnAuditDebloat" Content="🔍 Auditar Bloatware (Solo Lectura)" Width="260" Margin="0,0,10,10" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}" FontWeight="SemiBold" ToolTip="Analiza e inventaria paquetes AppX, Win32 y servicios de telemetria sin modificar ni desinstalar nada."/>
                                    <Button x:Name="btnRunDebloatInteractive" Content="🛠️ Debloat Asistido (Selección Manual)" Width="270" Margin="0,0,10,10" Background="#1B4D3E" BorderBrush="#00E676" FontWeight="SemiBold" ToolTip="Abre el asistente interactivo con seleccion visual (Out-GridView) para elegir manualmente que eliminar."/>
                                    <Button x:Name="btnRunGamingApps" Content="Optimizar Juegos y Apps (VRAM / Electron)" Width="280" Margin="0,0,10,10"/>
                                    <Button x:Name="btnRunLatencyProfiler" Content="Profiler Forense Latencia DPC (Microsegundos)" Width="310" Margin="0,0,10,10" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}" FontWeight="SemiBold"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>

                        <!-- Menus Contextuales Optimizados -->
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14">
                            <StackPanel>
                                <TextBlock Text="Menus Contextuales (Gamer &amp; Power-User)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                                <WrapPanel>
                                    <Button x:Name="btnEnableClassicMenu" Content="Habilitar Menu Clasico (1-Clic)" Width="240" Margin="0,0,10,10"/>
                                    <Button x:Name="btnApplyFullContextMenu" Content="Suite Completa Gamer &amp; Power-User" Width="280" Margin="0,0,10,10" Background="#1B4D3E" BorderBrush="#00E676" FontWeight="SemiBold"/>
                                    <Button x:Name="btnRestoreModernMenu" Content="Restaurar Menu Moderno Win11" Width="240" Margin="0,0,10,10"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- Pestaña 3: Mantenimiento -->
            <TabItem Header="Mantenimiento">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="5">
                    <StackPanel Margin="10">
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="Saneamiento Profundo y Reparacion de Imagen" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                                <CheckBox x:Name="chkMaintWinSxS" Content="Limpieza profunda de WinSxS con DISM (/StartComponentCleanup /ResetBase)" Foreground="#E3E3E3" IsChecked="True" FontSize="12" Margin="0,0,0,8"/>
                                <CheckBox x:Name="chkMaintShaders" Content="Purga de Shaders GPU (DirectX, AMD Radeon Cache, NVIDIA)" Foreground="#E3E3E3" IsChecked="True" FontSize="12" Margin="0,0,0,8"/>
                                <CheckBox x:Name="chkMaintTrim" Content="Ejecutar SSD TRIM en todas las unidades NVMe/SATA" Foreground="#E3E3E3" IsChecked="True" FontSize="12" Margin="0,0,0,8"/>
                                <CheckBox x:Name="chkMaintSfc" Content="Verificacion y reparacion de archivos corruptos (SFC /scannow + RestoreHealth)" Foreground="#E3E3E3" IsChecked="False" FontSize="12" Margin="0,0,0,14"/>

                                <WrapPanel Margin="0,5,0,0">
                                    <Button x:Name="btnRunMaintenanceBatch" Content="Iniciar Saneamiento Seleccionado" Width="260" HorizontalAlignment="Left" Background="#1B4D3E" BorderBrush="#00E676" FontWeight="SemiBold" Margin="0,0,10,0"/>
                                    <Button x:Name="btnInspectDismCatalog" Content="Catalogo Componentes DISM (SSOT)" Width="250" HorizontalAlignment="Left" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}" FontWeight="SemiBold"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>

                        <!-- Tarjeta romanOS Snapshot & Rollback Engine -->
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14">
                            <StackPanel>
                                <TextBlock Text="Instantaneas de Configuracion y Rollback (romanOS Snapshot Engine)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,6"/>
                                <TextBlock Text="Captura el estado integro de directivas de registro, servicios y red antes de aplicar modificaciones, permitiendo una reversion atomica en segundos." Foreground="#A0A0A0" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,10"/>
                                
                                <Grid Margin="0,0,0,10">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="130"/>
                                    </Grid.ColumnDefinitions>
                                    <ComboBox x:Name="cbxSnapshotsList" Grid.Column="0" Height="28" Background="#1E1E1E" Foreground="#FFFFFF" BorderBrush="#454545" VerticalContentAlignment="Center" Margin="0,0,10,0"/>
                                    <Button x:Name="btnRefreshSnapshots" Grid.Column="1" Content="Actualizar Lista" Height="28"/>
                                </Grid>

                                <WrapPanel>
                                    <Button x:Name="btnCreateSnapshotGUI" Content="Crear Instantanea (1-Clic)" Width="210" Margin="0,0,10,10" Background="#1B4D3E" BorderBrush="#00E676" FontWeight="SemiBold"/>
                                    <Button x:Name="btnCreateVssPoint" Content="Crear Punto VSS (Windows)" Width="200" Margin="0,0,10,10"/>
                                    <Button x:Name="btnRestoreSnapshotGUI" Content="Restaurar Instantanea Seleccionada" Width="250" Margin="0,0,10,10" Background="#3E2723" BorderBrush="#FF5252" FontWeight="SemiBold"/>
                                    <Button x:Name="btnListSnapshotsCLI" Content="Ver Catalogo Completo" Width="180" Margin="0,0,10,10"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>

                        <!-- Tarjeta romanOS Service Drift Watchdog -->
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,12,0,0">
                            <StackPanel>
                                <TextBlock Text="Guardian Anti-Drift y Watchdog de Servicios (romanOS Anti-Drift)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,6"/>
                                <TextBlock Text="Monitorea y previene que Windows Update o procesos en segundo plano reactiven telemetria, diagnostic tracking y servicios degradadores de rendimiento." Foreground="#A0A0A0" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,10"/>
                                
                                <WrapPanel>
                                    <Button x:Name="btnAuditDriftGUI" Content="Auditar Desvio de Servicios" Width="210" Margin="0,0,10,10" Background="#1B4D3E" BorderBrush="#00E676" FontWeight="SemiBold"/>
                                    <Button x:Name="btnRemediateDriftGUI" Content="Remediar Desvio (1-Clic)" Width="200" Margin="0,0,10,10" Background="#3E2723" BorderBrush="#FF5252" FontWeight="SemiBold"/>
                                    <Button x:Name="btnInstallDriftTaskGUI" Content="Instalar Tarea Watchdog" Width="180" Margin="0,0,10,10"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- Pestaña 4: Red -->
            <TabItem Header="Red &amp; Latencia">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="5">
                    <StackPanel Margin="10">
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="Conmutador y Benchmark de Servidores DNS (DoH + RTT)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,6"/>
                                <TextBlock Text="Compara la latencia real en milisegundos (RTT) hacia los resolvers globales líderes y conmuta perfiles con cifrado DoH en Windows 11." Foreground="#A0A0A0" FontSize="11" Margin="0,0,0,12"/>

                                <!-- Estado DNS Actual en Vivo -->
                                <Border Background="#1E2822" BorderBrush="#00E676" BorderThickness="1" CornerRadius="4" Padding="10" Margin="0,0,0,12">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Grid.Column="0" Text="DNS Actual en Uso: " Foreground="#FFFFFF" FontWeight="Bold" VerticalAlignment="Center"/>
                                        <TextBlock Grid.Column="1" x:Name="lblCurrentDns" Text="Detectando..." Foreground="#00E5FF" FontWeight="SemiBold" VerticalAlignment="Center" Margin="5,0,0,0"/>
                                        <Button Grid.Column="2" x:Name="btnRefreshDns" Content="Actualizar Estado" Width="130" Height="24" FontSize="11"/>
                                    </Grid>
                                </Border>

                                <WrapPanel Margin="0,0,0,12">
                                    <Button x:Name="btnRunDnsBench" Content="Ejecutar Benchmark DNS en Vivo (RTT)" Width="250" Margin="0,0,12,0" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}" FontWeight="SemiBold"/>
                                    <CheckBox x:Name="chkEnableDoH" Content="Activar Cifrado DoH (DNS-over-HTTPS en Windows 11)" IsChecked="True" Foreground="#E0E0E0" VerticalAlignment="Center"/>
                                </WrapPanel>

                                <Border Background="#1E1E1E" BorderBrush="#333333" BorderThickness="1" CornerRadius="4" Padding="10" Margin="0,0,0,12">
                                    <TextBlock x:Name="txtDnsResults" Text="Haga clic en 'Ejecutar Benchmark DNS en Vivo (RTT)' para evaluar Cloudflare, Quad9, Google y AdGuard." Foreground="#A0A0A0" FontFamily="Consolas" FontSize="12" TextWrapping="Wrap"/>
                                </Border>

                                <TextBlock Text="Conmutación Rápida de Perfiles DNS (1-Clic):" Foreground="#E0E0E0" FontWeight="SemiBold" FontSize="12" Margin="0,0,0,8"/>
                                <WrapPanel>
                                    <Button x:Name="btnSetCloudflareDns" Content="Cloudflare (1.1.1.1)" Width="170" Margin="0,0,10,10"/>
                                    <Button x:Name="btnSetQuad9Dns" Content="Quad9 Seguro (9.9.9.9)" Width="180" Margin="0,0,10,10"/>
                                    <Button x:Name="btnSetGoogleDns" Content="Google (8.8.8.8)" Width="160" Margin="0,0,10,10"/>
                                    <Button x:Name="btnSetAdGuardDns" Content="AdGuard AdBlock (94.140.14.14)" Width="210" Margin="0,0,10,10"/>
                                    <Button x:Name="btnResetDnsDhcp" Content="Restaurar DNS (DHCP)" Width="170" Margin="0,0,10,10"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>

                        <!-- Optimizacion de Pila TCP / Latencia de Red -->
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14">
                            <StackPanel>
                                <TextBlock Text="Optimizacion de Pila de Red y Latencia TCP" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,6"/>
                                <TextBlock Text="Desactiva el algoritmo de Nagle (TcpNoDelay) para reducir latencia en partidas online y audita sockets." Foreground="#A0A0A0" FontSize="11" Margin="0,0,0,10"/>
                                <WrapPanel>
                                    <Button x:Name="btnOptimizeNetworkNagle" Content="Optimizar Latencia TCP / Nagle (1-Clic)" Width="280" Margin="0,0,10,10" Background="#1B4D3E" BorderBrush="#00E676" FontWeight="SemiBold"/>
                                    <Button x:Name="btnFullNetworkDiag" Content="Diagnostico Completo de Red &amp; Sockets" Width="280" Margin="0,0,10,10"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- Pestaña 5: Seguridad & Navegadores -->
            <TabItem Header="Seguridad &amp; Navegadores">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="5">
                    <StackPanel Margin="10">
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="Optimizacion de Navegadores Web (Oficial)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,6"/>
                                <TextBlock Text="Aplica aceleracion por hardware GPU, Sleeping Tabs (50% menos RAM) y purga Copilot/telemetria." Foreground="#A0A0A0" FontSize="11" Margin="0,0,0,10"/>
                                <WrapPanel Margin="0,0,0,10">
                                    <Button x:Name="btnOptAllBrowsers" Content="Optimizar Todos los Navegadores" Width="240" Margin="0,0,10,10" Background="#1B4D3E" BorderBrush="#00E676"/>
                                    <Button x:Name="btnOptEdge" Content="Solo Microsoft Edge" Width="160" Margin="0,0,10,10"/>
                                    <Button x:Name="btnOptChrome" Content="Solo Google Chrome" Width="160" Margin="0,0,10,10"/>
                                    <Button x:Name="btnOptBrave" Content="Solo Brave Browser" Width="160" Margin="0,0,10,10"/>
                                    <Button x:Name="btnOptFirefox" Content="Solo Mozilla Firefox" Width="160" Margin="0,0,10,10"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>

                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="Entorno Sandbox Descartable en Vivo (romanOS Live Sandbox)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,6"/>
                                <TextBlock Text="Ejecuta mods, parches no oficiales o navegacion privada en un contenedor efimero aislado sin tocar el sistema principal." Foreground="#A0A0A0" FontSize="11" Margin="0,0,0,10"/>
                                <Grid Margin="0,0,0,10">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text="Perfil de Aislamiento:" Foreground="#E0E0E0" FontSize="11" VerticalAlignment="Center" Margin="0,0,10,0"/>
                                    <ComboBox x:Name="cmbSandboxPreset" Grid.Column="1" Height="26" SelectedIndex="0" Background="#1E1E1E" Foreground="#FFFFFF" BorderBrush="#3D3D3D">
                                        <ComboBoxItem Content="SafeAnalysis (Air-Gap aislado, sin red, solo lectura)"/>
                                        <ComboBoxItem Content="GameModding (vGPU Direct3D, red activa, lectura/escritura)"/>
                                        <ComboBoxItem Content="DisposableBrowser (Navegacion efimera privada)"/>
                                    </ComboBox>
                                </Grid>
                                <WrapPanel>
                                    <Button x:Name="btnCheckSandbox" Content="Verificar Diagnostico Sandbox" Width="210" Margin="0,0,10,10"/>
                                    <Button x:Name="btnLaunchSandbox" Content="Lanzar Sandbox 1-Clic" Width="180" Margin="0,0,10,10" Background="#1B4D3E" BorderBrush="#00E676"/>
                                    <Button x:Name="btnGenerateSandboxWsb" Content="Generar Archivo .wsb" Width="170" Margin="0,0,10,10"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>

                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14">
                            <StackPanel>
                                <TextBlock Text="Auditoria de Seguridad y Dashboards Visuales" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                                <WrapPanel>
                                    <Button x:Name="btnSecurityAudit" Content="Ejecutar Auditoria de Seguridad (ASR / VBS)" Width="270" Margin="0,0,10,10"/>
                                    <Button x:Name="btnApplySafeHardening" Content="Aplicar Hardening Seguro (Gaming-Safe)" Width="280" Margin="0,0,10,10" Background="#1B4D3E" BorderBrush="#00E676" FontWeight="SemiBold"/>
                                    <Button x:Name="btnGenerateDiagReport" Content="Generar Informe Post-Instalacion (HTML)" Width="270" Margin="0,0,10,10"/>
                                    <Button x:Name="btnOpenHtmlDashboards" Content="Abrir Dashboards HTML en Navegador" Width="260" Margin="0,0,10,10" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- Pestaña 6: Drivers & Herramientas -->
            <TabItem Header="Drivers &amp; Herramientas">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="5">
                    <StackPanel Margin="10">
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="Ecosistema de Controladores (Drivers)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                                <WrapPanel>
                                    <Button x:Name="btnBackupDrivers" Content="Respaldar Controladores del Host" Width="240" Margin="0,0,10,10"/>
                                    <Button x:Name="btnAuditDriverStore" Content="🔍 Auditar DriverStore (WhatIf)" Width="230" Margin="0,0,10,10" ToolTip="Muestra que controladores obsoletos/duplicados existen sin eliminarlos."/>
                                    <Button x:Name="btnCleanDriverStore" Content="🗑️ Depurar DriverStore (Interactivo)" Width="250" Margin="0,0,10,10" ToolTip="Abre el asistente con confirmacion explicita [S/N] antes de eliminar controladores."/>
                                    <Button x:Name="btnGetCriticalDrivers" Content="Descargar Drivers Criticos (VMD / VirtIO)" Width="280" Margin="0,0,10,10"/>
                                    <Button x:Name="btnMigrateUser" Content="Asistente de Migracion de Usuario" Width="250" Margin="0,0,10,10"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>
                        <!-- Tarjeta romanOS App & AI Runtimes Manager -->
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="romanOS App &amp; AI Runtimes Manager (Winget &amp; IA 2026)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,4"/>
                                <TextBlock Text="Instalacion automatizada y silenciosa de perfiles de software curados, aceleradores de IA local (Ollama, DirectML) y runtimes de sistema." Foreground="#AAAAAA" FontSize="11" Margin="0,0,0,10"/>
                                
                                <Grid Margin="0,0,0,8">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="180"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text="Perfil de Software:" Foreground="#FFFFFF" VerticalAlignment="Center"/>
                                    <ComboBox x:Name="cbxAppProfiles" Grid.Column="1" Height="26" SelectedIndex="0" Background="#1E1E1E" Foreground="#FFFFFF">
                                        <ComboBoxItem Content="eSports &amp; Competitive Gamer (Steam, Discord, RTSS, Vulkan, OBS)" Tag="EsportsGamer"/>
                                        <ComboBoxItem Content="AI Engineer &amp; Developer (Ollama, VS Code, Git, Python 3.12, Terminal)" Tag="AIAndDeveloper"/>
                                        <ComboBoxItem Content="Content Creator &amp; Streamer (OBS, HandBrake, VLC, Audacity, Codecs)" Tag="CreatorStreamer"/>
                                        <ComboBoxItem Content="Essential Daily Utilities (7-Zip, Firefox, SumatraPDF, Notepad++)" Tag="Essential"/>
                                        <ComboBoxItem Content="Todos los Perfiles Completos" Tag="All"/>
                                    </ComboBox>
                                </Grid>

                                <Grid Margin="0,0,0,10">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="180"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text="Categoría Curada (WinGet):" Foreground="#00E676" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    <ComboBox x:Name="cbxAppCategories" Grid.Column="1" Height="26" SelectedIndex="0" Background="#1E1E1E" Foreground="#FFFFFF">
                                        <ComboBoxItem Content="Navegadores Web (Brave, Firefox, Chrome, LibreWolf)" Tag="Browsers"/>
                                        <ComboBoxItem Content="Gaming &amp; Plataformas (Steam, Epic, Discord, OBS, Prism Launcher)" Tag="Gaming"/>
                                        <ComboBoxItem Content="Desarrollo &amp; Terminal (VS Code, Git, Python 3.12, Windows Terminal, Notepad++)" Tag="Development"/>
                                        <ComboBoxItem Content="Utilidades Esenciales (7-Zip, PowerToys, FastStone, Everything, VLC, Revo)" Tag="Utilities"/>
                                        <ComboBoxItem Content="Todas las Categorías Curadas (Suite Completa)" Tag="All"/>
                                    </ComboBox>
                                </Grid>

                                <WrapPanel Margin="0,0,0,10">
                                    <CheckBox x:Name="chkAutoDetectHw" Content="Auto-detectar GPU/NPU y anadir suite oficial de fabricante" IsChecked="True" Foreground="#E0E0E0" Margin="0,0,15,5"/>
                                    <CheckBox x:Name="chkIncludeRuntimes" Content="Incluir Runtimes Base (.NET 8/9, Visual C++ 2015-2022, DirectX)" IsChecked="True" Foreground="#E0E0E0" Margin="0,0,15,5"/>
                                </WrapPanel>

                                <WrapPanel>
                                    <Button x:Name="btnDeployProfileGUI" Content="Instalar Perfil Seleccionado" Width="210" Margin="0,0,10,10" Background="#1B4D3E" BorderBrush="#00E676" FontWeight="SemiBold"/>
                                    <Button x:Name="btnDeployCategoryGUI" Content="Instalar Categoría (WinGet)" Width="200" Margin="0,0,10,10" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}" FontWeight="SemiBold"/>
                                    <Button x:Name="btnSimulateProfileGUI" Content="Simular Selección (-WhatIf)" Width="190" Margin="0,0,10,10"/>
                                    <Button x:Name="btnListCatalogGUI" Content="Explorar Catálogo Curado" Width="180" Margin="0,0,10,10"/>
                                    <Button x:Name="btnInstallRuntimesGUI" Content="Instalar Solo Runtimes Base" Width="200" Margin="0,0,10,10"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- Pestaña 7: Constructor Desatendido (Builder Mode) -->
            <TabItem x:Name="tabItemBuilder" Header="Constructor Desatendido">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="5">
                    <StackPanel Margin="10">
                        <!-- Tarjeta Header -->
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="Generador Visual de Perfiles Desatendidos (Builder Mode)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,4"/>
                                <TextBlock Text="Cree, valide y exporte archivos autounattend.xml a medida para memorias USB de instalación o despliegues físicos sin compilar la ISO completa." Foreground="#A0A0A0" FontSize="11" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>

                        <!-- Tarjeta Bypasses de Windows 11 -->
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="Bypasses de Requisitos y Restricciones (windowsPE &amp; OOBE)" Foreground="#00E676" FontWeight="SemiBold" FontSize="13" Margin="0,0,0,8"/>
                                <WrapPanel Margin="0,0,0,5">
                                    <CheckBox x:Name="chkUnattendBypassTPM" Content="Bypass TPM 2.0" IsChecked="True" Foreground="#E0E0E0" Margin="0,0,15,6"/>
                                    <CheckBox x:Name="chkUnattendBypassSecureBoot" Content="Bypass Secure Boot" IsChecked="True" Foreground="#E0E0E0" Margin="0,0,15,6"/>
                                    <CheckBox x:Name="chkUnattendBypassRAM" Content="Bypass RAM (4GB)" IsChecked="True" Foreground="#E0E0E0" Margin="0,0,15,6"/>
                                    <CheckBox x:Name="chkUnattendBypassCPU" Content="Bypass Generación CPU" IsChecked="True" Foreground="#E0E0E0" Margin="0,0,15,6"/>
                                    <CheckBox x:Name="chkUnattendBypassStorage" Content="Bypass Espacio / Disco" IsChecked="True" Foreground="#E0E0E0" Margin="0,0,15,6"/>
                                    <CheckBox x:Name="chkUnattendBypassNRO" Content="Bypass Cuenta MS (OOBE Offline)" IsChecked="True" Foreground="#E0E0E0" Margin="0,0,15,6"/>
                                    <CheckBox x:Name="chkUnattendMoSetup" Content="Permitir In-Place Upgrade" IsChecked="True" Foreground="#E0E0E0" Margin="0,0,15,6"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>

                        <!-- Tarjeta Cuenta de Usuario y Preferencias -->
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="Configuración de Cuenta Local y Sesión" Foreground="#00E5FF" FontWeight="SemiBold" FontSize="13" Margin="0,0,0,8"/>
                                <Grid Margin="0,0,0,8">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="180"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="180"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>
                                    <TextBlock Grid.Row="0" Grid.Column="0" Text="Usuario Local:" Foreground="#B0B0B0" VerticalAlignment="Center" Margin="0,4"/>
                                    <TextBox Grid.Row="0" Grid.Column="1" x:Name="txtUnattendUser" Text="Usuario" Background="#1E1E1E" Foreground="#FFFFFF" BorderBrush="#454545" Padding="4,2" Margin="0,4,10,4"/>
                                    <TextBlock Grid.Row="0" Grid.Column="2" Text="Contraseña (opcional):" Foreground="#B0B0B0" VerticalAlignment="Center" Margin="0,4"/>
                                    <TextBox Grid.Row="0" Grid.Column="3" x:Name="txtUnattendPassword" Text="" Background="#1E1E1E" Foreground="#FFFFFF" BorderBrush="#454545" Padding="4,2" Margin="0,4,0,4"/>
                                </Grid>
                                <WrapPanel Margin="0,4,0,0">
                                    <CheckBox x:Name="chkUnattendAutoLogon" Content="Auto-Logon en Primer Inicio" IsChecked="True" Foreground="#E0E0E0" Margin="0,0,15,6"/>
                                    <CheckBox x:Name="chkUnattendDarkMode" Content="Forzar Modo Oscuro en HKCU" IsChecked="True" Foreground="#E0E0E0" Margin="0,0,15,6"/>
                                    <CheckBox x:Name="chkUnattendBlockOneDrive" Content="Bloquear OneDrive y Telemetría Sync" IsChecked="True" Foreground="#E0E0E0" Margin="0,0,15,6"/>
                                </WrapPanel>
                            </StackPanel>
                        </Border>

                        <!-- Tarjeta Perfil de Optimización y Esquema de Disco -->
                        <Border Background="{DynamicResource CardBgBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="14" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="Perfil SSOT de Optimización y Particionado" Foreground="#00E5FF" FontWeight="SemiBold" FontSize="13" Margin="0,0,0,8"/>
                                <Grid Margin="0,0,0,8">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="180"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="180"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="Perfil SSOT (Policy-Engine):" Foreground="#B0B0B0" VerticalAlignment="Center" Margin="0,4"/>
                                    <ComboBox Grid.Column="1" x:Name="cbxUnattendProfile" SelectedIndex="0" Background="#1E1E1E" Foreground="#FFFFFF" Margin="0,4,10,4">
                                        <ComboBoxItem Content="1 - Máximo Rendimiento / Gaming (Default)" Tag="1"/>
                                        <ComboBoxItem Content="2 - Equilibrado / Oficina y Estudio" Tag="2"/>
                                        <ComboBoxItem Content="3 - Ultra-Seguro / Enterprise" Tag="3"/>
                                    </ComboBox>
                                    <TextBlock Grid.Column="2" Text="Esquema de Particionado:" Foreground="#B0B0B0" VerticalAlignment="Center" Margin="0,4"/>
                                    <ComboBox Grid.Column="3" x:Name="cbxUnattendDiskLayout" SelectedIndex="0" Background="#1E1E1E" Foreground="#FFFFFF" Margin="0,4,0,4">
                                        <ComboBoxItem Content="Manual (Seleccionar en Setup - Seguro)" Tag="Manual"/>
                                        <ComboBoxItem Content="Zero-Touch GPT (Auto-formato Disco 0)" Tag="ZeroTouchGpt"/>
                                    </ComboBox>
                                </Grid>
                                <Grid Margin="0,0,0,4">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="180"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="Idioma y Región:" Foreground="#B0B0B0" VerticalAlignment="Center" Margin="0,4"/>
                                    <ComboBox Grid.Column="1" x:Name="cbxUnattendLocale" SelectedIndex="0" Background="#1E1E1E" Foreground="#FFFFFF" Margin="0,4,0,4">
                                        <ComboBoxItem Content="es-ES (Español España)" Tag="es-ES"/>
                                        <ComboBoxItem Content="es-MX (Español Latinoamérica / México)" Tag="es-MX"/>
                                        <ComboBoxItem Content="en-US (English United States)" Tag="en-US"/>
                                    </ComboBox>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <!-- Botones de Operación -->
                        <WrapPanel Margin="0,0,0,12">
                            <Button x:Name="btnGenerateUnattendPreview" Content="Generar y Previsualizar XML" Width="210" Margin="0,0,10,10" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}" FontWeight="SemiBold"/>
                            <Button x:Name="btnExportUnattendFile" Content="Exportar autounattend.xml..." Width="220" Margin="0,0,10,10" Background="#1B4D3E" BorderBrush="#00E676" FontWeight="SemiBold"/>
                            <Button x:Name="btnValidateUnattendGUI" Content="Certificar Sintaxis y Bypasses" Width="210" Margin="0,0,10,10"/>
                            <Button x:Name="btnResetUnattendDefaults" Content="Restablecer Valores Recomendados" Width="230" Margin="0,0,10,10"/>
                        </WrapPanel>

                        <!-- Visor de Previsualización XML -->
                        <Border Background="#181818" BorderBrush="#333333" BorderThickness="1" CornerRadius="4" Padding="8">
                            <StackPanel>
                                <TextBlock Text="Previsualización de autounattend.xml:" Foreground="#A0A0A0" FontSize="11" Margin="0,0,0,4"/>
                                <TextBox x:Name="txtUnattendPreview" Height="180" Background="#121212" Foreground="#81D4FA" FontFamily="Consolas" FontSize="11"
                                         IsReadOnly="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                                         BorderBrush="#252525" BorderThickness="1" Padding="6" Text="Haga clic en 'Generar y Previsualizar XML' para renderizar el archivo de respuesta."/>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- Pestaña 8: Terminal / Logs -->
            <TabItem x:Name="tabItemLogs" Header="Consola en Vivo">
                <Grid Margin="10">
                    <TextBox x:Name="txtConsole" Background="#151515" Foreground="#00E5FF" FontFamily="Consolas" FontSize="12"
                             IsReadOnly="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                             BorderBrush="#333333" BorderThickness="1" Padding="8" AcceptsReturn="True"/>
                </Grid>
            </TabItem>
        </TabControl>

        <!-- Barra Inferior de Estado -->
        <Border Background="#282828" Height="50" VerticalAlignment="Bottom" BorderBrush="#1C1C1C" BorderThickness="0,1,0,0">
            <Grid Margin="15,0">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Left">
                    <Ellipse x:Name="statusIndicator" Width="10" Height="10" Fill="#00E676" Margin="0,0,8,0"/>
                    <TextBlock x:Name="lblStatus" Text="Listo para operar" Foreground="#E3E3E3" FontSize="12" VerticalAlignment="Center"/>
                    <ProgressBar x:Name="taskProgressBar" Height="8" Width="180" Margin="15,0,0,0" VerticalAlignment="Center" Background="#1E1E1E" Foreground="#00E5FF" BorderThickness="0" Visibility="Collapsed" Minimum="0" Maximum="100"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Right">
                    <Button x:Name="btnExportProfile" Content="💾 Exportar Perfil JSON" Margin="0,0,10,0" Height="30" Padding="8,2" Background="{DynamicResource AccentAuditBgBrush}" BorderBrush="{DynamicResource AccentPrimaryBrush}" FontWeight="SemiBold" ToolTip="Exporta el inventario de telemetría y directivas activas a un archivo JSON portable."/>
                    <Button x:Name="btnClearConsole" Content="Limpiar Consola" Margin="0,0,10,0" Height="30" Padding="8,2"/>
                    <Button x:Name="btnCancelProcess" Content="Detener Tarea" Height="30" Padding="8,2" Background="#4A1E1E" BorderBrush="#FF5252" IsEnabled="False"/>
                </StackPanel>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# -----------------------------------------------------------------------------
# 2.1. SISTEMA DE TEMAS VISUALES DINÃMICOS (PLAN-0146)
# -----------------------------------------------------------------------------
try {
    $activeTheme = Get-RomanOSActiveThemeName
    Apply-RomanOSGuiTheme -Window $window -ThemeName $activeTheme

    $cmbTheme = $window.FindName('cmbThemeSelector')
    if ($cmbTheme) {
        foreach ($item in $cmbTheme.Items) {
            if ($item.Tag -eq $activeTheme) {
                $item.IsSelected = $true
                break
            }
        }
        $cmbTheme.Add_SelectionChanged({
            if ($this.SelectedItem -and $this.SelectedItem.Tag) {
                $selectedTheme = $this.SelectedItem.Tag
                Apply-RomanOSGuiTheme -Window $window -ThemeName $selectedTheme
                if (Get-Command 'Update-DesktopHelpersGUIState' -ErrorAction SilentlyContinue) {
                    Update-DesktopHelpersGUIState
                }
                Write-CCLog "Tema visual cambiado dinÃ¡micamente a: $selectedTheme"
            }
        })
    }
} catch {
    Write-CCLog "Aviso al inicializar tema visual: $($_.Exception.Message)" "WARN"
}

# -----------------------------------------------------------------------------
# 3. LÓGICA DE TELEMETRÍA Y POBLADO EN VIVO
# -----------------------------------------------------------------------------
try {
    if (Get-Command Get-SystemHardwareProfile -ErrorAction SilentlyContinue) {
        $hw = Get-SystemHardwareProfile -ForceRefresh
        $freeC = try { [math]::Round(((Get-PSDrive C -ErrorAction SilentlyContinue).Free / 1GB), 1) } catch { 0 }
        
        $cpuName   = if ($hw.CPU.Name) { $hw.CPU.Name } else { (Get-CimInstance Win32_Processor).Name }
        $coresText = if ($hw.CPU.Cores -and $hw.CPU.Threads) { "$($hw.CPU.Cores) Nucleos / $($hw.CPU.Threads) Hilos" } else { "$((Get-CimInstance Win32_Processor).NumberOfCores) Nucleos" }
        $ramGib    = if ($hw.RAM.TotalGiB) { $hw.RAM.TotalGiB } else { [math]::Round(((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1MB), 1) }
        $ramText   = "$ramGib GiB $(if ($hw.RAM.MemoryType) { $hw.RAM.MemoryType }) $(if ($hw.RAM.SpeedMHz) { "@ $($hw.RAM.SpeedMHz)MHz" }) $(if ($hw.RAM.ChannelMode) { "($($hw.RAM.ChannelMode))" })".Trim()
        $diskText  = "$($hw.Disk.DiskLabel) (C: $freeC GB Libres)"
        
        $badge = $window.FindName('lblHwBadge')
        if ($badge) {
            $badge.Text = "$($hw.Profile.DisplayName) | $ramGib GB RAM"
            $badge.Foreground = [System.Windows.Media.Brushes]::LightGreen
        }
        
        $window.FindName('lblCpuInfo').Text   = $cpuName
        $window.FindName('lblCoresInfo').Text = $coresText
        $window.FindName('lblRamInfo').Text   = $ramText
        $window.FindName('lblDiskInfo').Text  = $diskText
        
        $primaryGpu = if ($hw.GPU.Devices -and @($hw.GPU.Devices).Count -gt 0) { @($hw.GPU.Devices)[0] } else { $null }
        if ($primaryGpu) {
            $window.FindName('lblGpuInfo').Text = "$($primaryGpu.Name) ($($primaryGpu.VendorName))"
            $msiLabel = if ($primaryGpu.MsiStatus -eq 1) { "Habilitado [1]" } elseif ($primaryGpu.MsiStatus -eq 0) { "Deshabilitado [0]" } else { "No config" }
            $window.FindName('lblMsiInfo').Text  = $msiLabel
            $window.FindName('lblHagsInfo').Text = if ($primaryGpu.SupportsHAGS) { "Soportado" } else { "No disponible" }
        } else {
            $window.FindName('lblGpuInfo').Text  = "GPU Estandar"
            $window.FindName('lblMsiInfo').Text  = "No config"
            $window.FindName('lblHagsInfo').Text = "No disponible"
        }
        
        $aiPcText = if ($hw.NPU.IsAiPc) { "Si ($($hw.NPU.DeviceName))" } else { "No detectada" }
        $window.FindName('lblAiPcInfo').Text = $aiPcText

        # BypassIO & DirectStorage (PLAN-0123)
        try {
            $lblBypass = $window.FindName('lblBypassIoInfo')
            if (Get-Command "Get-RomanOSBypassIOStatus" -ErrorAction SilentlyContinue) {
                $bioStatus = Get-RomanOSBypassIOStatus
                if ($lblBypass) {
                    $lblBypass.Text = "$($bioStatus.DirectStorageStatus)"
                    $lblBypass.Foreground = if ($bioStatus.SupportedVolumes -gt 0 -and -not $bioStatus.HasVetoedFilters) { [System.Windows.Media.Brushes]::LightGreen } else { [System.Windows.Media.Brushes]::Orange }
                }
            } elseif (Get-Command "Test-RomanOSBypassIoState" -ErrorAction SilentlyContinue) {
                $bio = Test-RomanOSBypassIoState
                if ($lblBypass) {
                    $lblBypass.Text = if ($bio.IsSupported) { "Activo (Ruta Rapida)" } else { "$($bio.StatusReason)" }
                    $lblBypass.Foreground = if ($bio.IsSupported) { [System.Windows.Media.Brushes]::LightGreen } else { [System.Windows.Media.Brushes]::Orange }
                }
            } else {
                if ($lblBypass) { $lblBypass.Text = "$($hw.Disk.DirectStorageStatus)" }
            }
        } catch {
            Write-CCLog "No se pudo consultar BypassIO: $($_.Exception.Message)" -Level "WARN"
        }

        # Red NDIS & UDP RSC
        try {
            if (Get-Command "Get-RomanOSNetworkOffloadCaps" -ErrorAction SilentlyContinue) {
                $nics = Get-RomanOSNetworkOffloadCaps
                $lblNet = $window.FindName('lblNetOffloadInfo')
                if ($lblNet) {
                    $pNic = if ($nics -and @($nics).Count -gt 0) { @($nics)[0] } else { $null }
                    if ($pNic) {
                        $lblNet.Text = "$($pNic.Name) (UDP RSC: $($pNic.UdpRscState))"
                    } else {
                        $lblNet.Text = "Sin adaptadores"
                    }
                }
            }
        } catch {
            Write-CCLog "No se pudo consultar UDP RSC: $($_.Exception.Message)" -Level "WARN"
        }
        
        Write-CCLog "Telemetria de hardware cargada exitosamente: $cpuName | $ramGib GB RAM"
    } else {
        $badge = $window.FindName('lblHwBadge')
        if ($badge) {
            $badge.Text = "Hardware-Engine no disponible"
            $badge.Foreground = [System.Windows.Media.Brushes]::Orange
        }
        Write-CCLog "Get-SystemHardwareProfile no disponible en el entorno" -Level "WARN"
    }
} catch {
    Write-CCLog "Error al poblar telemetria de hardware: $($_.Exception.Message)" -Level "WARN"
}

# --- Asistentes Modulares de Escritorio (Desktop Helpers & Invariantes) ---
function Update-DesktopHelpersGUIState {
    $helperMap = @(
        @{ Id = "WindowsUpdate"; Btn = 'btnHelperWU'; Name = "Windows Update" },
        @{ Id = "Defender";      Btn = 'btnHelperDefender'; Name = "Defender" },
        @{ Id = "Bluetooth";     Btn = 'btnHelperBluetooth'; Name = "Bluetooth" },
        @{ Id = "Printing";      Btn = 'btnHelperPrinting'; Name = "Impresion" },
        @{ Id = "FileSharing";   Btn = 'btnHelperSharing'; Name = "Compartir Red" },
        @{ Id = "VBS";           Btn = 'btnHelperVBS'; Name = "VBS / HVCI" },
        @{ Id = "Recall";        Btn = 'btnHelperRecall'; Name = "Windows Recall" }
    )
    foreach ($item in $helperMap) {
        $btn = $window.FindName($item.Btn)
        if ($btn -and (Get-Command "Get-RomanOSDesktopHelperState" -ErrorAction SilentlyContinue)) {
            try {
                $st = Get-RomanOSDesktopHelperState -HelperId $item.Id
                $statusText = if ($st.Status -eq "Enabled") { "Activo" } elseif ($st.Status -eq "Disabled") { "Pausado" } else { "Desconocido" }
                $btn.Content = "$($item.Name): $statusText"
                if ($st.Status -eq "Enabled") {
                    $btn.Background = $window.Resources['AccentSuccessBgBrush']
                    $btn.BorderBrush = $window.Resources['AccentSecondaryBrush']
                } else {
                    $btn.Background = $window.Resources['AccentWarningBgBrush']
                    $btn.BorderBrush = $window.Resources['AccentWarningBrush']
                }
            } catch {
                Write-CCLog "Error al consultar estado de $($item.Id): $($_.Exception.Message)" "WARN"
            }
        }
    }
}

# Inicializar estados de los Desktop Helpers en la UI
try {
    Update-DesktopHelpersGUIState
} catch {
    Write-CCLog "Aviso al inicializar botones Desktop Helpers: $($_.Exception.Message)" -Level "WARN"
}

# Auto-refresco periódico de Asistentes Modulares (cada 5s) para mantener paridad en vivo con el sistema
$script:helperRefreshTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:helperRefreshTimer.Interval = [TimeSpan]::FromSeconds(5)
$script:helperRefreshTimer.Add_Tick({
    try {
        Update-DesktopHelpersGUIState
    } catch { }
})
$script:helperRefreshTimer.Start()


# Inicializar estado de DNS en la UI
function Update-ControlCenterDnsState {
    try {
        $lbl = $window.FindName('lblCurrentDns')
        if ($lbl) {
            # Determinar adaptador activo con ruta por defecto (0.0.0.0/0)
            $defRoute = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1
            $active = $null

            if (Get-Command 'Get-RomanOSCurrentDns' -ErrorAction SilentlyContinue) {
                $curr = @(Get-RomanOSCurrentDns)
                if ($curr -and $curr.Count -gt 0) {
                    $active = if ($defRoute) { $curr | Where-Object { $_.InterfaceIndex -eq $defRoute.InterfaceIndex } | Select-Object -First 1 } else { $null }
                    if (-not $active) { $active = $curr | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1 }
                    if (-not $active) { $active = $curr[0] }
                }
            }

            if ($active) {
                $serverStr = if ($active.DnsServers) { $active.DnsServers } else { "DHCP / Sin asignar" }
                $lbl.Text = "$($active.DetectedProfile) ($serverStr) en $($active.InterfaceAlias)"
            } else {
                # Fallback nativo directo mediante Get-NetAdapter y Get-DnsClientServerAddress
                $natAdapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })
                if ($natAdapters.Count -gt 0) {
                    $natActive = if ($defRoute) { $natAdapters | Where-Object { $_.ifIndex -eq $defRoute.InterfaceIndex } | Select-Object -First 1 } else { $null }
                    if (-not $natActive) { $natActive = $natAdapters[0] }
                    $natDns = Get-DnsClientServerAddress -InterfaceIndex $natActive.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
                    $dnsStr = if ($natDns -and $natDns.ServerAddresses) { $natDns.ServerAddresses -join ', ' } else { "DHCP Automatico" }
                    $lbl.Text = "Activo ($dnsStr) en $($natActive.Name)"
                } else {
                    $lbl.Text = "No se detectaron adaptadores activos"
                }
            }
        }
    } catch {
        Write-CCLog "Aviso al consultar estado DNS: $($_.Exception.Message)" -Level "WARN"
    }
}
Update-ControlCenterDnsState

# -----------------------------------------------------------------------------
# 4. MOTOR DE EJECUCIÓN ASÍNCRONA DESACOPLADA (60 FPS)
# -----------------------------------------------------------------------------
$script:activeSubProcessState = $null

function Start-ControlCenterTask {
    param(
        [string]$CommandLine,
        [string]$TaskTitle
    )
    
    $btnCancel = $window.FindName('btnCancelProcess')
    $lblStatus = $window.FindName('lblStatus')
    $indicator = $window.FindName('statusIndicator')
    $progBar   = $window.FindName('taskProgressBar')
    $tabControl = $window.FindName('tabControlMain')
    $tabLogs = $window.FindName('tabItemLogs')
    $txtConsole = $window.FindName('txtConsole')

    $btnCancel.IsEnabled = $true
    $indicator.Fill = [System.Windows.Media.Brushes]::Yellow
    $lblStatus.Text = "Ejecutando: $TaskTitle..."
    if ($txtConsole) {
        $txtConsole.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#333333")
    }

    if ($progBar) {
        $progBar.Visibility = [System.Windows.Visibility]::Visible
        $progBar.IsIndeterminate = $true
        $progBar.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00E5FF")
        $progBar.Value = 0
    }

    if ($tabLogs -and $tabControl) {
        $tabControl.SelectedItem = $tabLogs
    }

    $txtConsole.AppendText("`r`n════════════════════════════════════════════════════════════════`r`n")
    $txtConsole.AppendText("[INICIO] $TaskTitle ($(Get-Date -Format 'HH:mm:ss'))`r`n")
    $txtConsole.AppendText("════════════════════════════════════════════════════════════════`r`n")
    $txtConsole.ScrollToEnd()

    $queue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
    $state = [hashtable]::Synchronized(@{
        Process   = $null
        ExitCode  = -1
        IsRunning = $true
        TaskTitle = $TaskTitle
    })

    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $rs.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs

    [void]$ps.AddScript({
        param($cmdArgs, $outQueue, $procState)
        try {
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = "cmd.exe"
            $pinfo.Arguments = "/c powershell.exe -NonInteractive $cmdArgs 2>&1"
            $pinfo.UseShellExecute = $false
            $pinfo.CreateNoWindow = $true
            $pinfo.RedirectStandardOutput = $true
            $pinfo.RedirectStandardInput = $true

            $proc = New-Object System.Diagnostics.Process
            $proc.StartInfo = $pinfo
            $proc.Start() | Out-Null
            $procState.Process = $proc
            try { $proc.StandardInput.Close() } catch { Write-Warning "No se pudo cerrar StandardInput: $($_.Exception.Message)" }

            while (-not $proc.StandardOutput.EndOfStream) {
                $line = $proc.StandardOutput.ReadLine()
                if ($null -ne $line) {
                    $outQueue.Enqueue($line)
                }
            }
            $proc.WaitForExit()
            $procState.ExitCode = $proc.ExitCode
        } catch {
            $outQueue.Enqueue("[ERROR CRITICO] $($_.Exception.Message)")
            $procState.ExitCode = -1
        } finally {
            $procState.IsRunning = $false
        }
    })

    [void]$ps.AddArgument($CommandLine)
    [void]$ps.AddArgument($queue)
    [void]$ps.AddArgument($state)

    $handle = $ps.BeginInvoke()
    $script:activeSubProcessState = $state

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(100)
    $timer.Tag = @{
        Queue     = $queue
        State     = $state
        Txt       = $txtConsole
        PS        = $ps
        RS        = $rs
        Handle    = $handle
        TaskTitle = $TaskTitle
        BtnCancel = $btnCancel
        StatusLbl = $lblStatus
        Indicator = $indicator
        ProgBar   = $progBar
    }

    $timer.Add_Tick({
        $t = $This.Tag
        $line = ""
        while ($t.Queue.TryDequeue([ref]$line)) {
            $t.Txt.AppendText("$line`r`n")
            $t.Txt.ScrollToEnd()
            Write-CCLog $line

            # Telemetría heurística de progreso porcentual
            if ($t.ProgBar -and $line) {
                if ($line -match '(\d{1,3}(?:\.\d+)?)\s*%') {
                    $pctVal = [double]$matches[1]
                    if ($pctVal -ge 0 -and $pctVal -le 100) {
                        $t.ProgBar.IsIndeterminate = $false
                        $t.ProgBar.Value = $pctVal
                    }
                } elseif ($line -match '\[(\d{1,2})/(\d{1,2})\]') {
                    $cur = [double]$matches[1]
                    $tot = [double]$matches[2]
                    if ($tot -gt 0) {
                        $t.ProgBar.IsIndeterminate = $false
                        $t.ProgBar.Value = [math]::Round(($cur / $tot) * 100, 1)
                    }
                }
            }
        }

        if (-not $t.State.IsRunning) {
            $This.Stop()
            try {
                $t.PS.EndInvoke($t.Handle)
                $t.RS.Close()
                $t.PS.Dispose()
                $t.RS.Dispose()
            } catch {
                Write-CCLog "Aviso al liberar recursos de PowerShell RunSpace: $($_.Exception.Message)" "WARN"
            }

            $exitCode = $t.State.ExitCode
            Write-CCLog "Tarea finalizada: $($t.TaskTitle) con codigo de salida $exitCode"
            if ($exitCode -eq 0) {
                $t.Txt.AppendText("`r`n[EXITO] $($t.TaskTitle) finalizado satisfactoriamente.`r`n")
                $t.Indicator.Fill = [System.Windows.Media.Brushes]::LightGreen
                $t.StatusLbl.Text = "$($t.TaskTitle) completado con exito"
                if ($t.ProgBar) {
                    $t.ProgBar.IsIndeterminate = $false
                    $t.ProgBar.Value = 100
                }
            } else {
                $t.Txt.AppendText("`r`n[FALLO DE SUBPROCESO] $($t.TaskTitle) concluyo con codigo de salida $exitCode.`r`n")
                $t.Indicator.Fill = [System.Windows.Media.Brushes]::Red
                if ($t.Txt) {
                    $t.Txt.BorderBrush = [System.Windows.Media.Brushes]::Red
                }
                $t.StatusLbl.Text = "[ERROR $exitCode] $($t.TaskTitle) finalizo con incidencias"
                if ($t.ProgBar) {
                    $t.ProgBar.IsIndeterminate = $false
                    $t.ProgBar.Foreground = [System.Windows.Media.Brushes]::Red
                }
            }
            $t.BtnCancel.IsEnabled = $false

            # Refrescar estados de Desktop Helpers tras concluir la tarea
            try {
                if (Get-Command 'Update-DesktopHelpersGUIState' -ErrorAction SilentlyContinue) {
                    $window.Dispatcher.Invoke({ Update-DesktopHelpersGUIState })
                }
            } catch {
                Write-CCLog "Aviso al refrescar estado de Desktop Helpers: $($_.Exception.Message)" -Level "WARN"
            }

            # Refrescar estado de DNS tras concluir la tarea
            try {
                if (Get-Command 'Update-ControlCenterDnsState' -ErrorAction SilentlyContinue) {
                    $window.Dispatcher.Invoke({ Update-ControlCenterDnsState })
                }
            } catch {
                Write-CCLog "Aviso al refrescar estado de DNS: $($_.Exception.Message)" -Level "WARN"
            }

            # Re-verificación diferida (1.5s) para permitir el asentamiento de servicios asíncronos
            try {
                $delayedTimer = New-Object System.Windows.Threading.DispatcherTimer
                $delayedTimer.Interval = [TimeSpan]::FromMilliseconds(1500)
                $delayedTimer.Add_Tick({
                    $This.Stop()
                    try {
                        if (Get-Command 'Update-DesktopHelpersGUIState' -ErrorAction SilentlyContinue) {
                            $window.Dispatcher.Invoke({ Update-DesktopHelpersGUIState })
                        }
                    } catch { }
                    try {
                        if (Get-Command 'Update-ControlCenterDnsState' -ErrorAction SilentlyContinue) {
                            $window.Dispatcher.Invoke({ Update-ControlCenterDnsState })
                        }
                    } catch { }
                })
                $delayedTimer.Start()
            } catch { }
        }
    })

    $timer.Start()
}

# -----------------------------------------------------------------------------
# 5. ENLACE DE EVENTOS UI Y ACCIONES
# -----------------------------------------------------------------------------

# Boton Cancelar
$window.FindName('btnCancelProcess').Add_Click({
    if ($script:activeSubProcessState -and $script:activeSubProcessState.IsRunning) {
        $res = [System.Windows.MessageBox]::Show(
            "¿Desea detener la tarea en segundo plano?",
            "romanOS Control Center - Cancelar Tarea",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )
        if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
            try {
                $proc = $script:activeSubProcessState.Process
                if ($proc -and -not $proc.HasExited) {
                    & taskkill.exe /F /T /PID $proc.Id | Out-Null
                    $window.FindName('txtConsole').AppendText("`r`n[!] Tarea detenida por el usuario.`r`n")
                }
            } catch {
                Write-CCLog "Error al terminar subproceso con taskkill: $($_.Exception.Message)" "WARN"
            }
        }
    }
})

# Boton Limpiar Consola
$window.FindName('btnClearConsole').Add_Click({
    $window.FindName('txtConsole').Clear()
})

# Boton Exportar Perfil JSON
$btnExportProf = $window.FindName('btnExportProfile')
if ($btnExportProf) {
    $btnExportProf.Add_Click({
        try {
            $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
            $saveDialog.Filter = "Perfil romanOS (*.json)|*.json"
            $saveDialog.FileName = "romanOS-Profile-$env:COMPUTERNAME-$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            $saveDialog.InitialDirectory = "C:\OptimizedISO"
            if ($saveDialog.ShowDialog() -eq $true) {
                $targetJson = $saveDialog.FileName
                $osInfo = Get-CimInstance Win32_OperatingSystem
                $cpuInfo = Get-CimInstance Win32_Processor
                $csInfo = Get-CimInstance Win32_ComputerSystem
                $profileData = [ordered]@{
                    Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                    Host      = $env:COMPUTERNAME
                    OS        = $osInfo.Caption
                    Build     = $osInfo.BuildNumber
                    CPU       = $cpuInfo.Name
                    RAM_GB    = [math]::Round($csInfo.TotalPhysicalMemory / 1GB, 1)
                    Policies  = @()
                }
                if (Get-Command 'Get-RomanOSPolicies' -ErrorAction SilentlyContinue) {
                    $profileData.Policies = Get-RomanOSPolicies
                }
                $jsonContent = $profileData | ConvertTo-Json -Depth 5
                [System.IO.File]::WriteAllText($targetJson, $jsonContent, (New-Object System.Text.UTF8Encoding($true)))
                [System.Windows.MessageBox]::Show(
                    "Perfil de optimización exportado exitosamente en:`n$targetJson",
                    "romanOS Control Center — Exportar Perfil",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                )
                Write-CCLog "Perfil de sistema exportado a: $targetJson"
            }
        } catch {
            Write-CCLog "Error al exportar perfil: $($_.Exception.Message)" "WARN"
            [System.Windows.MessageBox]::Show(
                "Error al exportar perfil: $($_.Exception.Message)",
                "romanOS Control Center — Error",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
        }
    })
}

# --- Pestaña 1: Acciones Rapidas ---
$window.FindName('btnQuickTrim').Add_Click({
    $tool = Resolve-ToolScript "Optimize-ProcessMemory.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Unattended" -TaskTitle "Poda de Memoria RAM (Working Set)" }
})

$window.FindName('btnQuickFlushDns').Add_Click({
    Start-ControlCenterTask -CommandLine "-NoProfile -Command `"ipconfig /flushdns`"" -TaskTitle "Vaciado de Cache DNS"
})

$window.FindName('btnQuickRestartExplorer').Add_Click({
    $res = [System.Windows.MessageBox]::Show(
        "Se cerrará y reiniciará el explorador de Windows (explorer.exe).`n`nLas ventanas abiertas de carpetas y la barra de tareas parpadearán y se recargarán momentáneamente.`n`n¿Deseas reiniciar explorer.exe ahora?",
        "romanOS Control Center — Reinicio de Shell",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
        Start-ControlCenterTask -CommandLine "-NoProfile -Command `"Stop-Process -Name explorer -Force; Start-Sleep -Milliseconds 500; Start-Process explorer.exe; Write-Host '[OK] Explorador reiniciado.'`"" -TaskTitle "Reinicio de Explorer"
    }
})

$window.FindName('btnQuickGodMode').Add_Click({
    Start-Process "explorer.exe" -ArgumentList "shell:::{ED7BA470-8E54-465E-825C-99712043E01C}"
})

$window.FindName('btnQuickSfc').Add_Click({
    Start-ControlCenterTask -CommandLine "-NoProfile -Command `"DISM /Online /Cleanup-Image /RestoreHealth; sfc /scannow`"" -TaskTitle "Reparacion de Imagen y SFC"
})

$window.FindName('btnQuickShaders').Add_Click({
    $tool = Resolve-ToolScript "Invoke-WindowsMaintenance.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" -ShadersOnly -Unattended" -TaskTitle "Purga de Shaders GPU" }
})

$window.FindName('btnQuickTrimSSD').Add_Click({
    $tool = Resolve-ToolScript "Invoke-WindowsMaintenance.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" -TrimOnly -Unattended" -TaskTitle "SSD TRIM en Unidades" }
})

$window.FindName('btnQuickAudit').Add_Click({
    $tool = Resolve-ToolScript "Audit-SystemOptimization.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`"" -TaskTitle "Auditoria Universal de Optimizacion" }
})

$window.FindName('btnQuickLatency').Add_Click({
    $tool = Resolve-ToolScript "Trace-SystemLatency.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -DurationSeconds 5" -TaskTitle "Test Forense de Latencia DPC/ISR (5 segundos)" }
})

$window.FindName('btnQuickStorageAudit').Add_Click({
    $tool = Resolve-ToolScript "Test-StorageStackBypassIO.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`"" -TaskTitle "Auditoria Forense de Storage y BypassIO" }
})

$window.FindName('btnQuickNetAudit').Add_Click({
    $tool = Resolve-ToolScript "Test-NetworkOffloadsAndRSS.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`"" -TaskTitle "Auditoria Forense de Red NDIS y UDP RSC" }
})

$window.FindName('btnQuickAffinity').Add_Click({
    $tool = Resolve-ToolScript "Optimize-InterruptAffinity.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action Status -Unattended" -TaskTitle "Auditoria de Topologia PCIe y Afinidad IRQ" }
})

$window.FindName('btnQuickFootprint').Add_Click({
    $tool = Resolve-ToolScript "Audit-FreshInstallFootprint.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`"" -TaskTitle "Auditoria Forense de Huella en Reposo (RAM / Procesos)" }
})

$window.FindName('btnQuickRestoreServices').Add_Click({
    Start-ControlCenterTask -CommandLine "-NoProfile -Command `"try { Set-Service -Name WlanSvc -StartupType Automatic -ErrorAction SilentlyContinue; sc.exe config WlanSvc start= auto | Out-Null; Start-Service WlanSvc -ErrorAction SilentlyContinue; Set-Service -Name bthserv -StartupType Automatic -ErrorAction SilentlyContinue; sc.exe config bthserv start= auto | Out-Null; Start-Service bthserv -ErrorAction SilentlyContinue; Set-Service -Name Spooler -StartupType Automatic -ErrorAction SilentlyContinue; sc.exe config Spooler start= auto | Out-Null; Start-Service Spooler -ErrorAction SilentlyContinue; Set-Service -Name WSearch -StartupType Automatic -ErrorAction SilentlyContinue; sc.exe config WSearch start= delayed-auto | Out-Null; Start-Service WSearch -ErrorAction SilentlyContinue; Write-Host '[OK] Servicios basicos restaurados a inicio automatico (Wi-Fi, Bluetooth, Spooler, WSearch).' } catch { Write-Error `$_.Exception.Message }`"" -TaskTitle "Restaurar Servicios Basicos de Sistema"
})

# --- Conexión de Clics de Desktop Helpers ---

# Conexión de Clics de Desktop Helpers
$window.FindName('btnHelperWU').Add_Click({
    $st = if (Get-Command 'Get-RomanOSDesktopHelperState' -ErrorAction SilentlyContinue) { Get-RomanOSDesktopHelperState -HelperId "WindowsUpdate" } else { $null }
    $action = if ($st -and $st.Status -eq "Enabled") { "Disable" } else { "Enable" }
    $tool = Resolve-ToolScript "Toggle-WindowsUpdate.ps1"
    if ($tool) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action $action" -TaskTitle "Conmutador: Windows Update ($action)"
    } else {
        Write-CCLog "Error: No se pudo localizar Toggle-WindowsUpdate.ps1 en ninguna ruta de búsqueda." "ERROR"
        [System.Windows.MessageBox]::Show("No se pudo localizar el script Toggle-WindowsUpdate.ps1.", "romanOS Control Center — Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$window.FindName('btnHelperDefender').Add_Click({
    $st = if (Get-Command 'Get-RomanOSDesktopHelperState' -ErrorAction SilentlyContinue) { Get-RomanOSDesktopHelperState -HelperId "Defender" } else { $null }
    $action = if ($st -and $st.Status -eq "Enabled") { "Disable" } else { "Enable" }
    $tool = Resolve-ToolScript "Toggle-Defender.ps1"
    if ($tool) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action $action" -TaskTitle "Conmutador: Microsoft Defender ($action)"
    } else {
        Write-CCLog "Error: No se pudo localizar Toggle-Defender.ps1 en ninguna ruta de búsqueda." "ERROR"
        [System.Windows.MessageBox]::Show("No se pudo localizar el script Toggle-Defender.ps1.", "romanOS Control Center — Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$window.FindName('btnHelperBluetooth').Add_Click({
    $st = if (Get-Command 'Get-RomanOSDesktopHelperState' -ErrorAction SilentlyContinue) { Get-RomanOSDesktopHelperState -HelperId "Bluetooth" } else { $null }
    $action = if ($st -and $st.Status -eq "Enabled") { "Disable" } else { "Enable" }
    $tool = Resolve-ToolScript "Toggle-Bluetooth.ps1"
    if ($tool) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action $action" -TaskTitle "Conmutador: Bluetooth ($action)"
    } else {
        Write-CCLog "Error: No se pudo localizar Toggle-Bluetooth.ps1 en ninguna ruta de búsqueda." "ERROR"
        [System.Windows.MessageBox]::Show("No se pudo localizar el script Toggle-Bluetooth.ps1.", "romanOS Control Center — Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$window.FindName('btnHelperPrinting').Add_Click({
    $st = if (Get-Command 'Get-RomanOSDesktopHelperState' -ErrorAction SilentlyContinue) { Get-RomanOSDesktopHelperState -HelperId "Printing" } else { $null }
    $action = if ($st -and $st.Status -eq "Enabled") { "Disable" } else { "Enable" }
    $tool = Resolve-ToolScript "Toggle-Printing.ps1"
    if ($tool) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action $action" -TaskTitle "Conmutador: Impresion / Spooler ($action)"
    } else {
        Write-CCLog "Error: No se pudo localizar Toggle-Printing.ps1 en ninguna ruta de búsqueda." "ERROR"
        [System.Windows.MessageBox]::Show("No se pudo localizar el script Toggle-Printing.ps1.", "romanOS Control Center — Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$window.FindName('btnHelperSharing').Add_Click({
    $st = if (Get-Command 'Get-RomanOSDesktopHelperState' -ErrorAction SilentlyContinue) { Get-RomanOSDesktopHelperState -HelperId "FileSharing" } else { $null }
    $action = if ($st -and $st.Status -eq "Enabled") { "Disable" } else { "Enable" }
    $tool = Resolve-ToolScript "Toggle-FileSharing.ps1"
    if ($tool) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action $action" -TaskTitle "Conmutador: Compartir Archivos ($action)"
    } else {
        Write-CCLog "Error: No se pudo localizar Toggle-FileSharing.ps1 en ninguna ruta de búsqueda." "ERROR"
        [System.Windows.MessageBox]::Show("No se pudo localizar el script Toggle-FileSharing.ps1.", "romanOS Control Center — Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$window.FindName('btnHelperVBS').Add_Click({
    $st = if (Get-Command 'Get-RomanOSDesktopHelperState' -ErrorAction SilentlyContinue) { Get-RomanOSDesktopHelperState -HelperId "VBS" } else { $null }
    $action = if ($st -and $st.Status -eq "Enabled") { "Disable" } else { "Enable" }
    $tool = Resolve-ToolScript "Toggle-VBS-CoreIsolation.ps1"
    if ($tool) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action $action" -TaskTitle "Conmutador: VBS / Aislamiento de Nucleo ($action)"
    } else {
        Write-CCLog "Error: No se pudo localizar Toggle-VBS-CoreIsolation.ps1 en ninguna ruta de búsqueda." "ERROR"
        [System.Windows.MessageBox]::Show("No se pudo localizar el script Toggle-VBS-CoreIsolation.ps1.", "romanOS Control Center — Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$window.FindName('btnHelperRecall').Add_Click({
    $st = if (Get-Command 'Get-RomanOSDesktopHelperState' -ErrorAction SilentlyContinue) { Get-RomanOSDesktopHelperState -HelperId "Recall" } else { $null }
    $action = if ($st -and $st.Status -eq "Enabled") { "Disable" } else { "Enable" }
    $tool = Resolve-ToolScript "Toggle-Recall.ps1"
    if ($tool) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action $action" -TaskTitle "Conmutador: Windows Recall e IA ($action)"
    } else {
        Write-CCLog "Error: No se pudo localizar Toggle-Recall.ps1 en ninguna ruta de búsqueda." "ERROR"
        [System.Windows.MessageBox]::Show("No se pudo localizar el script Toggle-Recall.ps1.", "romanOS Control Center — Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$window.FindName('btnAuditInvariants').Add_Click({
    $pEng = Resolve-CoreModule "Policy-Engine.ps1"
    if ($pEng) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -Command `"& { . '$pEng'; `$res = Assert-RomanOSInvariants -AutoRemediate; `$res | Format-List; Write-Host ''; Write-Host '[OK] Verificacion de Invariantes Finalizada.' }`"" -TaskTitle "Auditoria de Invariantes del Sistema"
    } else {
        Write-CCLog "Error: No se pudo localizar Policy-Engine.ps1 en ninguna ruta de búsqueda." "ERROR"
        [System.Windows.MessageBox]::Show("No se pudo localizar el motor canónico Policy-Engine.ps1.", "romanOS Control Center — Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$window.FindName('btnOpenHelpersFolder').Add_Click({
    $helpersDir = Join-Path $repoScriptsRoot "Desktop-Helpers"
    if (-not (Test-Path $helpersDir)) {
        $helpersDir = "C:\Users\Public\Desktop\romanOS Helpers"
    }
    if (Test-Path $helpersDir) {
        Start-Process "explorer.exe" -ArgumentList "`"$helpersDir`""
    } else {
        [System.Windows.MessageBox]::Show("Carpeta de Helpers no encontrada en el sistema.", "romanOS Control Center", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

# --- Pestaña 2: Gaming & Bimodal ---
$window.FindName('btnGameAggressive').Add_Click({
    $tool = Resolve-ToolScript "Switch-GameDevMode.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Mode Game -Profile Aggressive -Unattended -SkipElevation" -TaskTitle "Conmutador: Modo Juego Agresivo (Poda RAM APU)" }
})

$window.FindName('btnGameLight').Add_Click({
    $tool = Resolve-ToolScript "Switch-GameDevMode.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Mode Game -Profile Light -Unattended -SkipElevation" -TaskTitle "Conmutador: Modo Juego Ligero" }
})

$window.FindName('btnDevMode').Add_Click({
    $tool = Resolve-ToolScript "Switch-GameDevMode.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Mode Dev -Unattended -SkipElevation" -TaskTitle "Conmutador: Modo Desarrollo (Hyper-V / Docker)" }
})

$window.FindName('btnToggleHypervisor').Add_Click({
    $res = [System.Windows.MessageBox]::Show(
        "Esta acción modificará la directiva del cargador de arranque de Windows (BCD - hypervisorlaunchtype) para alternar el estado del hipervisor de virtualización.`n`nPara que los cambios surtan efecto será indispensable reiniciar el equipo.`n`n¿Deseas continuar?",
        "romanOS Control Center — Alternar Hipervisor",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
        Start-ControlCenterTask -CommandLine "-NoProfile -Command `"try { `$c = & bcdedit /enum '{current}'; if (`$c -match 'hypervisorlaunchtype\s+off') { & bcdedit /set hypervisorlaunchtype auto; Write-Host '[OK] Hipervisor activado (auto). Reinicie el PC.' } else { & bcdedit /set hypervisorlaunchtype off; Write-Host '[OK] Hipervisor desactivado (off / Ring 0). Reinicie el PC.' } } catch { Write-Error `$_.Exception.Message }`"" -TaskTitle "Alternar Estado del Hipervisor"
    }
})

$window.FindName('btnAuditDebloat').Add_Click({
    $tool = Resolve-ToolScript "Win11-Debloat-v3-Adaptive.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -AuditOnly" -TaskTitle "Auditoría de Bloatware (Solo Lectura - Cero Modificaciones)" }
})

$window.FindName('btnRunDebloatInteractive').Add_Click({
    $tool = Resolve-ToolScript "Win11-Debloat-v3-Adaptive.ps1"
    if ($tool) {
        $res = [System.Windows.MessageBox]::Show(
            "Se abrirá el asistente interactivo de Debloat en una ventana independiente.`n`nPodrás revisar el hardware y se te presentarán ventanas de selección visual (Out-GridView) para marcar y desmarcar qué aplicaciones y servicios deseas desinstalar.`n`nNingún componente será modificado o desinstalado sin tu selección explícita.`n`n¿Deseas abrir el asistente ahora?",
            "romanOS Control Center — Debloat Interactivo Guiado",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )
        if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
            Write-CCLog "Iniciando Debloat Adaptativo en ventana interactiva con selección visual..."
            Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`""
        }
    }
})

$window.FindName('btnRunGamingApps').Add_Click({
    $tool = Resolve-ToolScript "Optimize-GamingAndApps.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Unattended -SkipElevation" -TaskTitle "Optimizacion de Juegos, Apps Electron y VRAM" }
})

$window.FindName('btnRunLatencyProfiler').Add_Click({
    $tool = Resolve-ToolScript "Trace-SystemLatency.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -DurationSeconds 5" -TaskTitle "Profiler Forense de Latencia DPC/ISR en Vivo" }
})

# Thermal & Energy Profiler Handlers
$window.FindName('btnAuditThermal').Add_Click({
    $tool = Resolve-ToolScript "Monitor-ThermalEnergy.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action Status -SkipElevation" -TaskTitle "Auditoria Termica y de Throttling" }
})

$window.FindName('btnLiveThermalMonitor').Add_Click({
    $tool = Resolve-ToolScript "Monitor-ThermalEnergy.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action Monitor -SampleDurationSec 5 -SkipElevation" -TaskTitle "Monitoreo Termico en Vivo (5s)" }
})

$window.FindName('btnCalibrateUltimateEnergy').Add_Click({
    $tool = Resolve-ToolScript "Monitor-ThermalEnergy.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action CalibrateEnergy -EnergyProfile Ultimate -Unattended" -TaskTitle "Calibracion Energetica & Core Unparking" }
})

$btnAudWake = $window.FindName('btnAuditWakeTimers')
if ($btnAudWake) {
    $btnAudWake.Add_Click({
        $tool = Resolve-ToolScript "Monitor-ThermalEnergy.ps1"
        if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action AuditWakeTimers -SkipElevation" -TaskTitle "Auditoria de Wake Timers y Reposo S0ix" }
    })
}

$btnDisWake = $window.FindName('btnDisableWakeTimers')
if ($btnDisWake) {
    $btnDisWake.Add_Click({
        $tool = Resolve-ToolScript "Monitor-ThermalEnergy.ps1"
        if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action DisableWakeTimers -Unattended" -TaskTitle "Neutralizacion de Wake Timers Parasitos & Blindaje S0ix" }
    })
}

# PCIe Interrupt Affinity & IRQ Priority Handlers
$window.FindName('btnAuditAffinityGUI').Add_Click({
    $tool = Resolve-ToolScript "Optimize-InterruptAffinity.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action Status -Unattended" -TaskTitle "Auditoria de Topologia PCIe y Afinidad IRQ" }
})

$window.FindName('btnOptimizeAffinityGUI').Add_Click({
    $tool = Resolve-ToolScript "Optimize-InterruptAffinity.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action Optimize -Unattended" -TaskTitle "Calibracion de Afinidad PCIe y DPC Steering" }
})

$window.FindName('btnResetAffinityGUI').Add_Click({
    $tool = Resolve-ToolScript "Optimize-InterruptAffinity.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action Reset -Unattended" -TaskTitle "Restauracion de Politicas IRQ de Hardware" }
})

# Handlers: Menus Contextuales Optimizados
$window.FindName('btnEnableClassicMenu').Add_Click({
    $tool = Resolve-ToolScript "Add-OptimizedContextMenus.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -EnableClassicMenu -RestartExplorer" -TaskTitle "Habilitar Menu Contextual Clasico (1-Clic)" }
})

$window.FindName('btnApplyFullContextMenu').Add_Click({
    $tool = Resolve-ToolScript "Add-OptimizedContextMenus.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Apply -RestartExplorer" -TaskTitle "Aplicar Suite Completa Gamer & Power-User" }
})

$window.FindName('btnRestoreModernMenu').Add_Click({
    $tool = Resolve-ToolScript "Add-OptimizedContextMenus.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -RestoreModernMenu -RestartExplorer" -TaskTitle "Restaurar Menu Moderno Windows 11" }
})

# --- Pestaña 3: Mantenimiento ---
$window.FindName('btnRunMaintenanceBatch').Add_Click({
    $tool = Resolve-ToolScript "Invoke-WindowsMaintenance.ps1"
    if ($tool) {
        $argsList = @()
        if ($window.FindName('chkMaintWinSxS').IsChecked) { $argsList += "-DeepClean -ResetBase" }
        if ($window.FindName('chkMaintShaders').IsChecked) { $argsList += "-ShadersOnly" }
        if ($window.FindName('chkMaintTrim').IsChecked) { $argsList += "-TrimOnly" }
        if ($window.FindName('chkMaintSfc').IsChecked) { $argsList += "-RepairOnly" }
        $argsStr = if ($argsList.Count -gt 0) { $argsList -join " " } else { "-Full" }
        Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" $argsStr -Unattended" -TaskTitle "Saneamiento de Sistema y WinSxS"
    }
})

$btnDism = $window.FindName('btnInspectDismCatalog')
if ($btnDism) {
    $window.FindName('btnInspectDismCatalog').Add_Click({
        $peScript = Resolve-ToolScript "Policy-Engine.ps1"
        if (-not $peScript) { $peScript = "C:\OptimizedISO\scripts\Core\Policy-Engine.ps1" }
        $cmd = "-NoProfile -ExecutionPolicy Bypass -Command `". '$peScript'; Get-RomanOSDismComponentsCatalog | Format-Table -AutoSize Id, Name, Category, Type, SafeForGaming`""
        Start-ControlCenterTask -CommandLine $cmd -TaskTitle "Catalogo Canónico de Componentes DISM (SSOT)"
    })
}

# Manejadores de Eventos: romanOS Snapshot & Rollback Engine
function Refresh-CCSnapshotsComboBox {
    $cbx = $window.FindName('cbxSnapshotsList')
    if ($cbx) {
        $cbx.Items.Clear()
        $snapDir = "$env:SystemDrive\romanOS-Snapshots"
        if (Test-Path $snapDir) {
            $snaps = Get-ChildItem -Path $snapDir -Directory -Filter "SNAP-*" | Sort-Object Name -Descending
            foreach ($s in $snaps) {
                $cbx.Items.Add($s.Name) | Out-Null
            }
            if ($cbx.Items.Count -gt 0) { $cbx.SelectedIndex = 0 }
            else { $cbx.Items.Add("(Sin snapshots creados)") | Out-Null; $cbx.SelectedIndex = 0 }
        } else {
            $cbx.Items.Add("(Directorio de snapshots no inicializado)") | Out-Null
            $cbx.SelectedIndex = 0
        }
    }
}

$window.FindName('btnQuickSnapshot').Add_Click({
    $tool = Resolve-ToolScript "Manage-SystemSnapshots.ps1"
    if ($tool) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action Create -Name `"QuickSnapshot`" -Unattended" -TaskTitle "Creacion de Instantanea de Seguridad"
    }
})

$window.FindName('btnCreateSnapshotGUI').Add_Click({
    $tool = Resolve-ToolScript "Manage-SystemSnapshots.ps1"
    if ($tool) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action Create -Name `"ControlCenterSnapshot`" -Unattended" -TaskTitle "Creacion de Instantanea de Seguridad"
    }
})

$window.FindName('btnCreateVssPoint').Add_Click({
    $tool = Resolve-ToolScript "Manage-SystemSnapshots.ps1"
    if ($tool) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action CreateVSS -Name `"ControlCenterVSS`" -Unattended" -TaskTitle "Creacion de Punto de Restauracion VSS"
    }
})

$window.FindName('btnRestoreSnapshotGUI').Add_Click({
    $cbx = $window.FindName('cbxSnapshotsList')
    $selectedSnap = if ($cbx) { $cbx.SelectedItem } else { $null }
    if (-not $selectedSnap -or $selectedSnap -match '^\(') {
        [System.Windows.MessageBox]::Show("Por favor seleccione un snapshot valido de la lista.", "romanOS Control Center", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    $res = [System.Windows.MessageBox]::Show("¿Esta seguro de que desea restaurar la configuracion del snapshot '$selectedSnap'?`r`n`r`nEsto revertira el estado del registro, servicios y red.", "romanOS Control Center - Confirmar Reversion", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
        $tool = Resolve-ToolScript "Manage-SystemSnapshots.ps1"
        if ($tool) {
            Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action Restore -SnapshotId `"$selectedSnap`" -Force" -TaskTitle "Restauracion Atomica de Snapshot"
        }
    }
})

$window.FindName('btnRefreshSnapshots').Add_Click({
    Refresh-CCSnapshotsComboBox
})

$window.FindName('btnListSnapshotsCLI').Add_Click({
    $tool = Resolve-ToolScript "Manage-SystemSnapshots.ps1"
    if ($tool) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action List" -TaskTitle "Catalogo de Snapshots romanOS"
    }
})

# Inicializar combo de snapshots
Refresh-CCSnapshotsComboBox

# Manejadores de Eventos: romanOS Service Drift Watchdog
$window.FindName('btnAuditDriftGUI').Add_Click({
    $tool = Resolve-ToolScript "Watchdog-ServiceDrift.ps1"
    if ($tool) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action Audit -SkipElevation" -TaskTitle "Auditoria de Desvio Anti-Drift"
    }
})

$window.FindName('btnRemediateDriftGUI').Add_Click({
    $tool = Resolve-ToolScript "Watchdog-ServiceDrift.ps1"
    if ($tool) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action Remediate -SkipElevation" -TaskTitle "Remediacion de Desvio Anti-Drift"
    }
})

$window.FindName('btnInstallDriftTaskGUI').Add_Click({
    $tool = Resolve-ToolScript "Watchdog-ServiceDrift.ps1"
    if ($tool) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action InstallTask -SkipElevation" -TaskTitle "Instalacion de Tarea Programada Watchdog"
    }
})

# --- Pestaña 4: Red ---
$btnRefDns = $window.FindName('btnRefreshDns')
if ($btnRefDns) {
    $btnRefDns.Add_Click({
        Update-ControlCenterDnsState
    })
}

$window.FindName('btnRunDnsBench').Add_Click({
    $txtDns = $window.FindName('txtDnsResults')
    $txtDns.Text = "Ejecutando medicion de latencia RTT contra servidores globales SSOT...`r`nPor favor espere unos segundos...`r`n"
    
    try {
        if (Get-Command 'Test-RomanOSDnsLatency' -ErrorAction SilentlyContinue) {
            $results = Test-RomanOSDnsLatency
            $sb = [System.Text.StringBuilder]::new()
            $sb.AppendLine(("{0,-20} {1,-16} {2,-14} {3,-12} {4}" -f "PROVEEDOR", "IP PRIMARIA", "LATENCIA RTT", "PERDIDA", "ESTADO")) | Out-Null
            $sb.AppendLine("-" * 75) | Out-Null
            $best = $null
            foreach ($r in $results) {
                $recTag = if ($r.Recommended) { " [RECOMENDADO / MAS RAPIDO]" } else { "" }
                if ($r.Recommended) { $best = $r }
                $latStr = if ($r.AverageMs -ge 0) { "$($r.AverageMs) ms" } else { "Tiempo agotado" }
                $lossStr = "$($r.PacketLoss)%"
                $sb.AppendLine(("{0,-20} {1,-16} {2,-14} {3,-12} {4}{5}" -f $r.Name, $r.PrimaryIPv4, $latStr, $lossStr, $r.Status, $recTag)) | Out-Null
            }
            if ($best) {
                $sb.AppendLine("") | Out-Null
                $sb.AppendLine(">> Servidor optimo detectado: $($best.Name) ($($best.AverageMs) ms)") | Out-Null
            }
            $txtDns.Text = $sb.ToString()
        } else {
            $netTool = Resolve-ToolScript "Win11-Network-Diagnostics-Optimizer.ps1"
            if ($netTool) {
                Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$netTool`" -TestDNS -Unattended" -TaskTitle "Benchmark DNS en Tiempo Real"
            }
        }
    } catch {
        $txtDns.Text = "Error al ejecutar benchmark: $($_.Exception.Message)"
    }
})

function Invoke-ControlCenterSetDns {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfileId,
        [Parameter(Mandatory = $true)]
        [string]$ProfileName,
        [bool]$EnableDoH = $false
    )

    $lblDns = $window.FindName('lblCurrentDns')
    if ($lblDns) {
        $lblDns.Text = "Aplicando configuración DNS: $ProfileName..."
    }

    $applied = $false
    if (Get-Command 'Set-RomanOSDnsServer' -ErrorAction SilentlyContinue) {
        try {
            $defRoute = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1
            $targetAlias = if ($defRoute) {
                $a = Get-NetAdapter -InterfaceIndex $defRoute.InterfaceIndex -ErrorAction SilentlyContinue
                if ($a) { $a.Name } else { $null }
            } else { $null }

            $params = @{
                ProfileId = $ProfileId
                EnableDoH = $EnableDoH
                Quiet     = $true
            }
            if ($targetAlias) { $params['InterfaceAlias'] = $targetAlias }

            $applied = Set-RomanOSDnsServer @params
            if ($applied) {
                Write-CCLog "DNS actualizado a $ProfileName exitosamente (DoH: $EnableDoH)."
                Update-ControlCenterDnsState
                return
            }
        } catch {
            Write-CCLog "Llamada directa Set-RomanOSDnsServer requirio fallback: $($_.Exception.Message)" -Level "WARN"
        }
    }

    $netTool = Resolve-ToolScript "Win11-Network-Diagnostics-Optimizer.ps1"
    $dohFlag = if ($EnableDoH) { " -EnableDoH" } else { "" }
    if ($netTool) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$netTool`" -SetDNS $ProfileId$dohFlag -Unattended" -TaskTitle "Asignar DNS $ProfileName"
    } else {
        $cmdDns = if ($ProfileId -eq "DHCP") {
            "Set-DnsClientServerAddress -InterfaceIndex `$w.ifIndex -ResetServerAddresses"
        } else {
            $p = if (Get-Command 'Get-RomanOSDnsProfileById' -ErrorAction SilentlyContinue) { Get-RomanOSDnsProfileById -Id $ProfileId } else { $null }
            $ip1 = if ($p) { $p.PrimaryIPv4 } else { '8.8.8.8' }
            $ip2 = if ($p) { $p.SecondaryIPv4 } else { '8.8.4.4' }
            "Set-DnsClientServerAddress -InterfaceIndex `$w.ifIndex -ServerAddresses @('$ip1','$ip2')"
        }
        Start-ControlCenterTask -CommandLine "-NoProfile -Command `"try { `$r = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1; `$w = if (`$r) { Get-NetAdapter -InterfaceIndex `$r.InterfaceIndex -ErrorAction SilentlyContinue } else { `$null }; if (-not `$w) { `$w = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { `$_.Status -eq 'Up' } | Select-Object -First 1 }; $cmdDns; Clear-DnsClientCache -ErrorAction SilentlyContinue; Write-Host ('[OK] DNS actualizado a $ProfileName en ' + `$w.Name) } catch { Write-Error `$_.Exception.Message }`"" -TaskTitle "Asignar DNS $ProfileName"
    }
}

$window.FindName('btnSetCloudflareDns').Add_Click({
    $doh = $window.FindName('chkEnableDoH').IsChecked -eq $true
    Invoke-ControlCenterSetDns -ProfileId "Cloudflare" -ProfileName "Cloudflare (1.1.1.1)" -EnableDoH $doh
})

$window.FindName('btnSetQuad9Dns').Add_Click({
    $doh = $window.FindName('chkEnableDoH').IsChecked -eq $true
    Invoke-ControlCenterSetDns -ProfileId "Quad9" -ProfileName "Quad9 (9.9.9.9)" -EnableDoH $doh
})

$window.FindName('btnSetGoogleDns').Add_Click({
    $doh = $window.FindName('chkEnableDoH').IsChecked -eq $true
    Invoke-ControlCenterSetDns -ProfileId "Google" -ProfileName "Google (8.8.8.8)" -EnableDoH $doh
})

$window.FindName('btnSetAdGuardDns').Add_Click({
    $doh = $window.FindName('chkEnableDoH').IsChecked -eq $true
    Invoke-ControlCenterSetDns -ProfileId "AdGuard" -ProfileName "AdGuard (94.140.14.14)" -EnableDoH $doh
})

$window.FindName('btnResetDnsDhcp').Add_Click({
    Invoke-ControlCenterSetDns -ProfileId "DHCP" -ProfileName "DHCP Dinámico" -EnableDoH $false
})

# Handlers: Optimizacion de Pila de Red y Latencia TCP
$window.FindName('btnOptimizeNetworkNagle').Add_Click({
    $tool = Resolve-ToolScript "Win11-Network-Diagnostics-Optimizer.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -NagleOnly -Unattended" -TaskTitle "Optimizacion de Latencia TCP / Nagle (TCP No-Delay)" }
})

$window.FindName('btnFullNetworkDiag').Add_Click({
    $tool = Resolve-ToolScript "Win11-Network-Diagnostics-Optimizer.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Unattended" -TaskTitle "Diagnostico Completo de Red y Latencia" }
})

# --- Pestaña 5: Seguridad & Navegadores ---
$window.FindName('btnOptAllBrowsers').Add_Click({
    $tool = Resolve-ToolScript "Optimize-WebBrowsers.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Browser All -Unattended" -TaskTitle "Optimizacion Oficial de Navegadores" }
})

$window.FindName('btnOptEdge').Add_Click({
    $tool = Resolve-ToolScript "Optimize-WebBrowsers.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Browser Edge -Unattended" -TaskTitle "Optimizar Microsoft Edge" }
})

$window.FindName('btnOptChrome').Add_Click({
    $tool = Resolve-ToolScript "Optimize-WebBrowsers.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Browser Chrome -Unattended" -TaskTitle "Optimizar Google Chrome" }
})

$window.FindName('btnOptBrave').Add_Click({
    $tool = Resolve-ToolScript "Optimize-WebBrowsers.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Browser Brave -Unattended" -TaskTitle "Optimizar Brave Browser" }
})

$window.FindName('btnOptFirefox').Add_Click({
    $tool = Resolve-ToolScript "Optimize-WebBrowsers.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Browser Firefox -Unattended" -TaskTitle "Optimizar Mozilla Firefox" }
})

$window.FindName('btnSecurityAudit').Add_Click({
    $tool = Resolve-ToolScript "Invoke-WindowsSecurityHardening.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" -ShowReport -NonInteractive" -TaskTitle "Auditoria de Seguridad y Hardening" }
})

$window.FindName('btnApplySafeHardening').Add_Click({
    $tool = Resolve-ToolScript "Invoke-WindowsSecurityHardening.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" -ApplySafeHardening -NonInteractive" -TaskTitle "Hardening de Seguridad Seguro (Gaming-Safe)" }
})

$window.FindName('btnGenerateDiagReport').Add_Click({
    $tool = Resolve-ToolScript "PostInstall-Diagnostics.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -DesktopOutput" -TaskTitle "Generar Informe Post-Instalacion (HTML)" }
})

$window.FindName('btnOpenHtmlDashboards').Add_Click({
    $desktopPath = [Environment]::GetFolderPath('CommonDesktopDirectory')
    if (-not $desktopPath -or -not (Test-Path $desktopPath)) {
        $desktopPath = if ($env:PUBLIC) { "$env:PUBLIC\Desktop" } else { "C:\Users\Public\Desktop" }
    }
    $diagHtml = Join-Path $desktopPath "INFORME_INSTALACION.html"
    $secHtml  = Join-Path $desktopPath "INFORME_SEGURIDAD.html"
    if (Test-Path $diagHtml) { Start-Process -FilePath $diagHtml }
    if (Test-Path $secHtml)  { Start-Process -FilePath $secHtml }
})

$window.FindName('btnCheckSandbox').Add_Click({
    $tool = Resolve-ToolScript "Invoke-LiveSandbox.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action Status" -TaskTitle "Diagnostico romanOS Live Sandbox" }
})

$window.FindName('btnLaunchSandbox').Add_Click({
    $tool = Resolve-ToolScript "Invoke-LiveSandbox.ps1"
    if ($tool) {
        $presetIdx = $window.FindName('cmbSandboxPreset').SelectedIndex
        $preset = switch ($presetIdx) { 1 { "GameModding" } 2 { "DisposableBrowser" } default { "SafeAnalysis" } }
        Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action Launch -Preset $preset" -TaskTitle "Lanzar Live Sandbox ($preset)"
    }
})

$window.FindName('btnGenerateSandboxWsb').Add_Click({
    $tool = Resolve-ToolScript "Invoke-LiveSandbox.ps1"
    if ($tool) {
        $presetIdx = $window.FindName('cmbSandboxPreset').SelectedIndex
        $preset = switch ($presetIdx) { 1 { "GameModding" } 2 { "DisposableBrowser" } default { "SafeAnalysis" } }
        Start-ControlCenterTask -CommandLine "-NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Action GenerateConfig -Preset $preset" -TaskTitle "Generar Perfil WSB ($preset)"
    }
})

# --- Pestaña 6: Drivers & Herramientas ---
$window.FindName('btnBackupDrivers').Add_Click({
    $tool = Resolve-ToolScript "Backup-HardwareDrivers.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`"" -TaskTitle "Respaldo de Controladores del Host" }
})

$window.FindName('btnAuditDriverStore').Add_Click({
    $tool = Resolve-ToolScript "Clean-DriverStore.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -WhatIf" -TaskTitle "Auditoría de DriverStore (Solo Lectura - WhatIf)" }
})

$window.FindName('btnCleanDriverStore').Add_Click({
    $tool = Resolve-ToolScript "Clean-DriverStore.ps1"
    if ($tool) {
        $res = [System.Windows.MessageBox]::Show(
            "Se abrirá la consola de mantenimiento de controladores con solicitud de confirmación explícita [S/N] antes de borrar cualquier controlador obsoleto.`n`n¿Deseas continuar?",
            "romanOS Control Center — Mantenimiento DriverStore",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )
        if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
            Write-CCLog "Iniciando depuración interactiva de DriverStore..."
            Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`""
        }
    }
})

$window.FindName('btnGetCriticalDrivers').Add_Click({
    $tool = Resolve-ToolScript "Get-CriticalDrivers.ps1"
    if ($tool) { Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`"" -TaskTitle "Descarga de Drivers Criticos (VMD / VirtIO)" }
})

$window.FindName('btnMigrateUser').Add_Click({
    $tool = Resolve-ToolScript "Migrar-Usuario-W11.ps1"
    if ($tool) {
        Write-CCLog "Iniciando Asistente de Migracion de Usuario en ventana interactiva..."
        Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`""
    }
})

# App & AI Runtimes Manager Handlers
$window.FindName('btnDeployProfileGUI').Add_Click({
    $cbx = $window.FindName('cbxAppProfiles')
    $selectedItem = if ($cbx) { $cbx.SelectedItem } else { $null }
    $profileTag = if ($selectedItem -and $selectedItem.Tag) { $selectedItem.Tag } else { 'EsportsGamer' }
    $autoHw = $window.FindName('chkAutoDetectHw').IsChecked
    $incRt = $window.FindName('chkIncludeRuntimes').IsChecked

    $tool = Resolve-ToolScript "Deploy-AppProfiles.ps1"
    if ($tool) {
        $cmd = "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Profile $profileTag -Unattended"
        if ($autoHw) { $cmd += " -AutoDetectHardware" }
        if (-not $incRt) { $cmd += " -IncludeRuntimes:`$false" }
        Start-ControlCenterTask -CommandLine $cmd -TaskTitle "Despliegue de Perfil: $profileTag"
    }
})

$btnDeployCat = $window.FindName('btnDeployCategoryGUI')
if ($btnDeployCat) {
    $btnDeployCat.Add_Click({
        $cbxCat = $window.FindName('cbxAppCategories')
        $selectedCat = if ($cbxCat) { $cbxCat.SelectedItem } else { $null }
        $catTag = if ($selectedCat -and $selectedCat.Tag) { $selectedCat.Tag } else { 'Browsers' }
        $incRt = $window.FindName('chkIncludeRuntimes').IsChecked

        $tool = Resolve-ToolScript "Deploy-AppProfiles.ps1"
        if ($tool) {
            $catsArg = if ($catTag -eq 'All') { "Browsers,Gaming,Development,Utilities" } else { $catTag }
            $cmd = "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Categories $catsArg -Unattended"
            if (-not $incRt) { $cmd += " -IncludeRuntimes:`$false" }
            Start-ControlCenterTask -CommandLine $cmd -TaskTitle "Despliegue WinGet: Categoria $catTag"
        }
    })
}

$btnListCat = $window.FindName('btnListCatalogGUI')
if ($btnListCat) {
    $btnListCat.Add_Click({
        $tool = Resolve-ToolScript "Deploy-AppProfiles.ps1"
        if ($tool) {
            Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -ListCatalog -SkipElevation" -TaskTitle "Explorar Catalogo Curado de Software WinGet"
        }
    })
}

$window.FindName('btnSimulateProfileGUI').Add_Click({
    $cbx = $window.FindName('cbxAppProfiles')
    $cbxCat = $window.FindName('cbxAppCategories')
    $selectedItem = if ($cbx) { $cbx.SelectedItem } else { $null }
    $profileTag = if ($selectedItem -and $selectedItem.Tag) { $selectedItem.Tag } else { 'EsportsGamer' }
    $selectedCat = if ($cbxCat) { $cbxCat.SelectedItem } else { $null }
    $catTag = if ($selectedCat -and $selectedCat.Tag) { $selectedCat.Tag } else { 'Browsers' }
    $autoHw = $window.FindName('chkAutoDetectHw').IsChecked

    $tool = Resolve-ToolScript "Deploy-AppProfiles.ps1"
    if ($tool) {
        $catsArg = if ($catTag -eq 'All') { "Browsers,Gaming,Development,Utilities" } else { $catTag }
        $cmd = "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -Profile $profileTag -Categories $catsArg -WhatIf -SkipElevation"
        if ($autoHw) { $cmd += " -AutoDetectHardware" }
        Start-ControlCenterTask -CommandLine $cmd -TaskTitle "Simulacion de Perfil y Categoria: $profileTag / $catTag"
    }
})

$window.FindName('btnInstallRuntimesGUI').Add_Click({
    $tool = Resolve-ToolScript "Deploy-AppProfiles.ps1"
    if ($tool) {
        Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tool`" -InstallRuntimesOnly -Unattended" -TaskTitle "Instalacion de Runtimes del Sistema"
    }
})

# -----------------------------------------------------------------------------
# Unattend Builder Mode Handlers (PLAN-0124)
# -----------------------------------------------------------------------------
function Get-UnattendFormParameters {
    $profTag = "1"
    $cbxProf = $window.FindName('cbxUnattendProfile')
    if ($cbxProf -and $cbxProf.SelectedItem -and $cbxProf.SelectedItem.Tag) {
        $profTag = [string]$cbxProf.SelectedItem.Tag
    }

    $diskTag = "Manual"
    $cbxDisk = $window.FindName('cbxUnattendDiskLayout')
    if ($cbxDisk -and $cbxDisk.SelectedItem -and $cbxDisk.SelectedItem.Tag) {
        $diskTag = [string]$cbxDisk.SelectedItem.Tag
    }

    $locTag = "es-ES"
    $cbxLoc = $window.FindName('cbxUnattendLocale')
    if ($cbxLoc -and $cbxLoc.SelectedItem -and $cbxLoc.SelectedItem.Tag) {
        $locTag = [string]$cbxLoc.SelectedItem.Tag
    }

    $kb = "040a:0000040a"
    $tz = "Romance Standard Time"
    if ($locTag -eq "es-MX") {
        $kb = "080a:0000080a"
        $tz = "Central Standard Time (Mexico)"
    } elseif ($locTag -eq "en-US") {
        $kb = "0409:00000409"
        $tz = "Pacific Standard Time"
    }

    return @{
        Profile              = $profTag
        LocalUser            = $window.FindName('txtUnattendUser').Text
        LocalPassword        = $window.FindName('txtUnattendPassword').Text
        BypassTPM            = [bool]$window.FindName('chkUnattendBypassTPM').IsChecked
        BypassSecureBoot     = [bool]$window.FindName('chkUnattendBypassSecureBoot').IsChecked
        BypassRAM            = [bool]$window.FindName('chkUnattendBypassRAM').IsChecked
        BypassCPU            = [bool]$window.FindName('chkUnattendBypassCPU').IsChecked
        BypassStorage        = [bool]$window.FindName('chkUnattendBypassStorage').IsChecked
        BypassDisk           = [bool]$window.FindName('chkUnattendBypassStorage').IsChecked
        AllowMoSetupUpgrade  = [bool]$window.FindName('chkUnattendMoSetup').IsChecked
        BypassNRO            = [bool]$window.FindName('chkUnattendBypassNRO').IsChecked
        AutoLogon            = [bool]$window.FindName('chkUnattendAutoLogon').IsChecked
        ForceDarkMode        = [bool]$window.FindName('chkUnattendDarkMode').IsChecked
        BlockOneDrive        = [bool]$window.FindName('chkUnattendBlockOneDrive').IsChecked
        DiskLayout           = $diskTag
        Language             = $locTag
        SystemLocale         = $locTag
        UserLocale           = $locTag
        Keyboard             = $kb
        TimeZone             = $tz
    }
}

$btnGenPrev = $window.FindName('btnGenerateUnattendPreview')
if ($btnGenPrev) {
    $btnGenPrev.Add_Click({
        try {
            $params = Get-UnattendFormParameters
            $xmlContent = New-RomanOSUnattendXml @params
            $window.FindName('txtUnattendPreview').Text = $xmlContent
            Write-CCLog "autounattend.xml generado en memoria (Tamano: $($xmlContent.Length) caracteres, Perfil: $($params.Profile), Layout: $($params.DiskLayout))"
            Update-Status "autounattend.xml generado exitosamente" "SUCCESS"
        } catch {
            Write-CCLog "Error al generar autounattend.xml: $($_.Exception.Message)" -Level "WARN"
            Update-Status "Error generando XML: $($_.Exception.Message)" "ERROR"
        }
    })
}

$btnExportXml = $window.FindName('btnExportUnattendFile')
if ($btnExportXml) {
    $btnExportXml.Add_Click({
        try {
            $sfd = New-Object Microsoft.Win32.SaveFileDialog
            $sfd.FileName = "autounattend.xml"
            $sfd.DefaultExt = ".xml"
            $sfd.Filter = "Archivo Unattend XML (*.xml)|*.xml|Todos los archivos (*.*)|*.*"
            $sfd.Title = "Guardar autounattend.xml de romanOS"

            if ($sfd.ShowDialog() -eq $true) {
                $params = Get-UnattendFormParameters
                $params['OutputPath'] = $sfd.FileName
                $savedPath = New-RomanOSUnattendXml @params
                $previewTxt = [System.IO.File]::ReadAllText($savedPath, [System.Text.Encoding]::UTF8)
                $window.FindName('txtUnattendPreview').Text = $previewTxt
                Write-CCLog "autounattend.xml exportado exitosamente a: $savedPath"
                Update-Status "Exportado a: $savedPath" "SUCCESS"

                [System.Windows.MessageBox]::Show(
                    "El archivo autounattend.xml ha sido exportado exitosamente a:`n`n$savedPath`n`nPuede copiar este archivo a la raíz de cualquier memoria USB de instalación de Windows 11 para aplicar automáticamente esta configuración.",
                    "romanOS Builder Mode — Exportación Completada",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                )
            }
        } catch {
            Write-CCLog "Error al exportar autounattend.xml: $($_.Exception.Message)" -Level "WARN"
            Update-Status "Fallo de exportacion: $($_.Exception.Message)" "ERROR"
        }
    })
}

$btnValGui = $window.FindName('btnValidateUnattendGUI')
if ($btnValGui) {
    $btnValGui.Add_Click({
        try {
            $params = Get-UnattendFormParameters
            $tempXml = Join-Path $env:TEMP "validate_unattend_$(Get-Date -Format 'HHmmss').xml"
            $params['OutputPath'] = $tempXml
            New-RomanOSUnattendXml @params | Out-Null

            $validator = Resolve-ToolScript "Test-UnattendXml.ps1"
            if ($validator) {
                Start-ControlCenterTask -CommandLine "-STA -NoProfile -ExecutionPolicy Bypass -File `"$validator`" -Path `"$tempXml`"" -TaskTitle "Validación y Certificación de autounattend.xml"
            }
        } catch {
            Write-CCLog "Error en validacion de autounattend.xml: $($_.Exception.Message)" -Level "WARN"
            Update-Status "Error en validación: $($_.Exception.Message)" "ERROR"
        }
    })
}

$btnRstDef = $window.FindName('btnResetUnattendDefaults')
if ($btnRstDef) {
    $btnRstDef.Add_Click({
        $window.FindName('chkUnattendBypassTPM').IsChecked = $true
        $window.FindName('chkUnattendBypassSecureBoot').IsChecked = $true
        $window.FindName('chkUnattendBypassRAM').IsChecked = $true
        $window.FindName('chkUnattendBypassCPU').IsChecked = $true
        $window.FindName('chkUnattendBypassStorage').IsChecked = $true
        $window.FindName('chkUnattendBypassNRO').IsChecked = $true
        $window.FindName('chkUnattendMoSetup').IsChecked = $true
        $window.FindName('txtUnattendUser').Text = "Usuario"
        $window.FindName('txtUnattendPassword').Text = ""
        $window.FindName('chkUnattendAutoLogon').IsChecked = $true
        $window.FindName('chkUnattendDarkMode').IsChecked = $true
        $window.FindName('chkUnattendBlockOneDrive').IsChecked = $true
        $window.FindName('cbxUnattendProfile').SelectedIndex = 0
        $window.FindName('cbxUnattendDiskLayout').SelectedIndex = 0
        $window.FindName('cbxUnattendLocale').SelectedIndex = 0
        Update-Status "Valores por defecto de Builder restablecidos" "INFO"
    })
}

# -----------------------------------------------------------------------------
# 6. MODO WHATIF Y LANZAMIENTO
# -----------------------------------------------------------------------------
if ($WhatIfPreference -or $PSBoundParameters.ContainsKey('WhatIf')) {
    Write-Host "[WhatIf] romanOS Control Center validado correctamente: XAML cargado y eventos enlazados." -ForegroundColor Green
    exit 0
}

$window.Add_Closing({
    if ($script:helperRefreshTimer) {
        $script:helperRefreshTimer.Stop()
    }
})

Write-CCLog "Mostrando ventana principal de romanOS Control Center"
[void]$window.ShowDialog()
Write-CCLog "Sesion de romanOS Control Center finalizada"
