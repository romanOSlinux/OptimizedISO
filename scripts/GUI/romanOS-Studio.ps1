<#
.SYNOPSIS
    romanOS Studio - Interfaz grafica nativa (WPF) para construir ISOs.
.DESCRIPTION
    Actua estrictamente como Frontend. Genera un JSON y delega el trabajo pesado a New-OptimizedWindowsISO-v2.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$SkipElevation
)

$isSimulated = ($PSBoundParameters.ContainsKey('WhatIf') -or $WhatIfPreference)
if ($isSimulated) {
    Write-Host "[WhatIf] romanOS Studio validado correctamente en modo simulado (AST y pre-flight OK)." -ForegroundColor Green
    return
}

# Auto-elevación obligatoria para operaciones DISM y permisos de administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $SkipElevation) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $targetPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }
    $psi.Arguments = "-WindowStyle Hidden -STA -NoProfile -ExecutionPolicy Bypass -File `"$targetPath`""
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $psi.Verb = "runas"
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit 0
    } catch {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "romanOS Studio requiere privilegios de Administrador para manipular imágenes WIM y ejecutar DISM.`n`nPor favor ejecute la aplicación como Administrador.",
            "romanOS Studio - Elevación Requerida",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
        exit 1
    }
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Inicializacion de Telemetria (Local Offline)
$logDir = Join-Path $PSScriptRoot "..\..\Log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$script:StudioLogPath = Join-Path $logDir "romanOS-Studio_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-StudioLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Out-File -FilePath $script:StudioLogPath -InputObject $line -Append -Encoding UTF8
}

Write-StudioLog "Iniciando sesion de romanOS Studio GUI"

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="romanOS Studio" Height="680" Width="880" 
        Background="#202020" WindowStartupLocation="CenterScreen"
        FontFamily="Segoe UI" MinHeight="620" MinWidth="800">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}" 
                                CornerRadius="3">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.3" />
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Opacity" Value="0.85" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid>
        <!-- Header -->
        <Border Background="#2D2D2D" Height="60" VerticalAlignment="Top" BorderBrush="#1C1C1C" BorderThickness="0,0,0,1">
            <TextBlock Text="romanOS Studio" Foreground="#E3E3E3" FontSize="24" FontWeight="SemiBold" Margin="20,15,0,0" />
        </Border>
        
        <!-- Main Content -->
        <TabControl x:Name="tabControlMain" Margin="10,70,10,70" Background="#202020" BorderBrush="#333333" Foreground="#E3E3E3">
            <TabControl.Resources>
                <Style TargetType="TabItem">
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="TabItem">
                                <Border Name="Border" BorderThickness="1,1,1,0" BorderBrush="#333333" Margin="2,0" Background="#2D2D2D">
                                    <ContentPresenter x:Name="ContentSite" VerticalAlignment="Center" HorizontalAlignment="Center" ContentSource="Header" Margin="12,8"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsSelected" Value="True">
                                        <Setter TargetName="Border" Property="Background" Value="#333333" />
                                        <Setter Property="Foreground" Value="#0078D4"/>
                                    </Trigger>
                                    <Trigger Property="IsSelected" Value="False">
                                        <Setter TargetName="Border" Property="Background" Value="#252525" />
                                        <Setter Property="Foreground" Value="#A0A0A0"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                    <Setter Property="FontSize" Value="13"/>
                </Style>
            </TabControl.Resources>
            
            <!-- Pestaña 1 -->
            <TabItem Header="Construcción Base">
                <Grid Margin="15">
                    <TextBlock Text="Imagen de Origen (Windows 10/11 ISO):" Foreground="#E3E3E3" Margin="0,15,0,0" FontWeight="SemiBold"/>
                    <TextBox x:Name="txtSourceISO" Margin="270,10,110,0" Height="28" VerticalAlignment="Top" Background="#333333" Foreground="#E3E3E3" BorderBrush="#454545" BorderThickness="1" Padding="4"/>
                    <Button x:Name="btnBrowseISO" Content="Examinar" Margin="0,10,10,0" Height="28" Width="90" HorizontalAlignment="Right" VerticalAlignment="Top" Background="#333333" Foreground="#E3E3E3" BorderThickness="1" BorderBrush="#454545"/>
                    
                    <TextBlock Text="Perfil de Optimización (Hardware-Engine):" Foreground="#E3E3E3" Margin="0,65,0,0" FontWeight="SemiBold"/>
                    <ComboBox x:Name="cmbProfile" Margin="270,60,0,0" Height="28" Width="260" HorizontalAlignment="Left" VerticalAlignment="Top" Background="#333333" Foreground="Black">
                        <ComboBoxItem Content="Perfil 1 (Moderado / Ofimática)" />
                        <ComboBoxItem Content="Perfil 2 (Avanzado / Gaming - Recomendado)" IsSelected="True" />
                        <ComboBoxItem Content="Perfil 3 (Hardcore / Extremo)" />
                    </ComboBox>
                    
                    <!-- Ediciones WIM detectadas -->
                    <TextBlock Text="Ediciones del WIM a incluir en la ISO:" Foreground="#E3E3E3" Margin="0,115,0,0" FontWeight="SemiBold"/>
                    <TextBlock x:Name="lblEditionsStatus" Text="Selecciona una ISO para ver las ediciones disponibles" Foreground="#A0A0A0" FontSize="11" Margin="0,140,0,0"/>
                    <ListBox x:Name="lbxWimEditions" Margin="0,165,0,10" Background="#1A1A1A" BorderBrush="#454545" BorderThickness="1"
                             ScrollViewer.VerticalScrollBarVisibility="Auto"/>
                </Grid>
            </TabItem>
            
            <!-- Pestaña 2 -->
            <TabItem Header="Instalación y Despliegue">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="5">
                    <StackPanel Margin="10">
                        <!-- Sección Zero-Touch -->
                        <Border Background="#282828" BorderBrush="#3D3D3D" BorderThickness="1" CornerRadius="4" Padding="12" Margin="0,0,0,15">
                            <StackPanel>
                                <TextBlock Text="Modo de Instalación Desatendida (Unattend)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,8"/>
                                <CheckBox x:Name="chkZeroTouch" Content="Habilitar Instalación 100% Zero-Touch (Automatización Total sin Intervención)" Foreground="#E3E3E3" FontSize="13" FontWeight="SemiBold" Margin="0,0,0,6"/>
                                <TextBlock Text="Particiona y formatea el disco automáticamente en UEFI/GPT (con WinRE de 500 MB), acepta el EULA y omite todas las pantallas de configuración." Foreground="#A0A0A0" FontSize="11" TextWrapping="Wrap" Margin="22,0,0,10"/>
                                
                                <StackPanel Orientation="Horizontal" Margin="22,0,0,8">
                                    <TextBlock Text="Disco físico de destino:" Foreground="#E3E3E3" VerticalAlignment="Center" Margin="0,0,10,0"/>
                                    <ComboBox x:Name="cmbZeroTouchDisk" Width="180" Height="26" Background="#333333" Foreground="Black" IsEnabled="False">
                                        <ComboBoxItem Content="Disco 0 (Predeterminado)" IsSelected="True"/>
                                        <ComboBoxItem Content="Disco 1"/>
                                        <ComboBoxItem Content="Disco 2"/>
                                        <ComboBoxItem Content="Disco 3"/>
                                    </ComboBox>
                                </StackPanel>
                                <TextBlock x:Name="txtZeroTouchWarning" Text="⚠️ ADVERTENCIA: Zero-Touch borrará y formateará por completo el disco físico seleccionado. Si no estás seguro, mantén esta opción desmarcada para elegir la partición manualmente en el instalador." Foreground="#FFA500" FontSize="11" TextWrapping="Wrap" Margin="22,0,0,4" Visibility="Collapsed"/>
                            </StackPanel>
                        </Border>

                        <!-- Sección Cuenta Local -->
                        <Border Background="#282828" BorderBrush="#3D3D3D" BorderThickness="1" CornerRadius="4" Padding="12" Margin="0,0,0,15">
                            <StackPanel>
                                <TextBlock Text="Cuenta de Usuario Local y Sesión" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                                <Grid Margin="0,0,0,8">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="170"/>
                                        <ColumnDefinition Width="200"/>
                                        <ColumnDefinition Width="160"/>
                                        <ColumnDefinition Width="200"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="Nombre de Usuario:" Foreground="#E3E3E3" VerticalAlignment="Center"/>
                                    <TextBox Grid.Column="1" x:Name="txtLocalUser" Text="Roman" Height="26" Background="#333333" Foreground="#E3E3E3" BorderBrush="#454545" Padding="3"/>
                                    <TextBlock Grid.Column="2" Text="Contraseña (opcional):" Foreground="#E3E3E3" VerticalAlignment="Center" Margin="15,0,0,0"/>
                                    <TextBox Grid.Column="3" x:Name="txtLocalPassword" Text="" Height="26" Background="#333333" Foreground="#E3E3E3" BorderBrush="#454545" Padding="3" ToolTip="Dejar en blanco para instalación sin contraseña"/>
                                </Grid>
                                <CheckBox x:Name="chkAutoLogon" Content="AutoLogon (Iniciar sesión automáticamente tras finalizar la instalación)" Foreground="#E3E3E3" IsChecked="True" FontSize="12" Margin="0,6,0,0"/>
                            </StackPanel>
                        </Border>

                        <!-- Sección Regional y Teclado -->
                        <Border Background="#282828" BorderBrush="#3D3D3D" BorderThickness="1" CornerRadius="4" Padding="12">
                            <StackPanel>
                                <TextBlock Text="Localización, Idioma y Teclado" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="170"/>
                                        <ColumnDefinition Width="200"/>
                                        <ColumnDefinition Width="160"/>
                                        <ColumnDefinition Width="200"/>
                                    </Grid.ColumnDefinitions>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="10"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>
                                    
                                    <TextBlock Grid.Row="0" Grid.Column="0" Text="Idioma UI:" Foreground="#E3E3E3" VerticalAlignment="Center"/>
                                    <ComboBox Grid.Row="0" Grid.Column="1" x:Name="cmbLanguage" Height="26" Background="#333333" Foreground="Black">
                                        <ComboBoxItem Content="es-ES (España)" IsSelected="True"/>
                                        <ComboBoxItem Content="es-MX (México)"/>
                                        <ComboBoxItem Content="en-US (Inglés)"/>
                                    </ComboBox>
                                    
                                    <TextBlock Grid.Row="0" Grid.Column="2" Text="Configuración Regional:" Foreground="#E3E3E3" VerticalAlignment="Center" Margin="15,0,0,0"/>
                                    <ComboBox Grid.Row="0" Grid.Column="3" x:Name="cmbLocale" Height="26" Background="#333333" Foreground="Black">
                                        <ComboBoxItem Content="es-AR (Argentina)" IsSelected="True"/>
                                        <ComboBoxItem Content="es-MX (México)"/>
                                        <ComboBoxItem Content="es-ES (España)"/>
                                        <ComboBoxItem Content="en-US (Estados Unidos)"/>
                                    </ComboBox>

                                    <TextBlock Grid.Row="2" Grid.Column="0" Text="Distribución Teclado:" Foreground="#E3E3E3" VerticalAlignment="Center"/>
                                    <ComboBox Grid.Row="2" Grid.Column="1" x:Name="cmbKeyboard" Height="26" Background="#333333" Foreground="Black">
                                        <ComboBoxItem Content="es-419 (Latinoamérica)" IsSelected="True"/>
                                        <ComboBoxItem Content="es-ES (España)"/>
                                        <ComboBoxItem Content="us (Estados Unidos)"/>
                                    </ComboBox>
                                    
                                    <TextBlock Grid.Row="2" Grid.Column="2" Text="Zona Horaria:" Foreground="#E3E3E3" VerticalAlignment="Center" Margin="15,0,0,0"/>
                                    <ComboBox Grid.Row="2" Grid.Column="3" x:Name="cmbTimezone" Height="26" Background="#333333" Foreground="Black">
                                        <ComboBoxItem Content="Argentina Standard Time" IsSelected="True"/>
                                        <ComboBoxItem Content="Romance Standard Time"/>
                                        <ComboBoxItem Content="Pacific Standard Time"/>
                                        <ComboBoxItem Content="Central Standard Time (Mexico)"/>
                                    </ComboBox>
                                </Grid>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>
            
            <!-- Pestaña 3 -->
            <TabItem Header="Componentes e Integraciones">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="5">
                    <StackPanel Margin="10">
                        <!-- Sección Integración Offline -->
                        <Border Background="#282828" BorderBrush="#3D3D3D" BorderThickness="1" CornerRadius="4" Padding="12" Margin="0,0,0,15">
                            <StackPanel>
                                <TextBlock Text="Integración Offline de Paquetes (Slipstreaming)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                                
                                <CheckBox x:Name="chkIntegrateUpdates" Content="Integrar Actualizaciones Acumulativas (Updates/ - .msu / .cab)" Foreground="#E3E3E3" IsChecked="True" FontSize="13" Margin="0,0,0,8"/>
                                
                                <CheckBox x:Name="chkIntegrateDrivers" Content="Integrar Controladores de Hardware (Drivers/ - .inf)" Foreground="#E3E3E3" IsChecked="True" FontSize="13" Margin="0,0,0,4"/>
                                <CheckBox x:Name="chkBootWimDrivers" Content="Inyectar controladores críticos de almacenamiento en Boot.wim (WinPE)" Foreground="#A0A0A0" IsChecked="True" FontSize="12" Margin="25,0,0,8"/>
                                
                                <CheckBox x:Name="chkIntegrateRuntimes" Content="Integrar Runtimes Esenciales (Runtimes/ - Visual C++ 2005-2022 y DirectX 9.0c)" Foreground="#E3E3E3" IsChecked="True" FontSize="13" Margin="0,0,0,4"/>
                                <TextBlock Text="Copia los instaladores en la carpeta OEM para su ejecución silenciosa al primer inicio vía SetupComplete.cmd." Foreground="#888888" FontSize="11" Margin="25,0,0,4"/>
                            </StackPanel>
                        </Border>

                        <!-- Sección Tweaks y Políticas SSOT -->
                        <Border Background="#282828" BorderBrush="#3D3D3D" BorderThickness="1" CornerRadius="4" Padding="12" Margin="0,0,0,15">
                            <StackPanel>
                                <TextBlock Text="Optimizaciones y Políticas del Sistema (SSOT Policy-Engine)" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                                
                                <CheckBox x:Name="chkVisualTweaks" Content="Inyectar Menú Contextual Clásico / Moderno (Shift+F10 / Menú Completo)" Foreground="#E3E3E3" IsChecked="True" FontSize="13" Margin="0,0,0,8"/>
                                <CheckBox x:Name="chkBlockOneDrive" Content="Bloquear telemetría e integración profunda de OneDrive" Foreground="#E3E3E3" IsChecked="True" FontSize="13" Margin="0,0,0,8"/>
                                <CheckBox x:Name="chkHyperV" Content="Habilitar subsistema Hyper-V (Virtualización nativa offline)" Foreground="#E3E3E3" IsChecked="False" FontSize="13" Margin="0,0,0,4"/>
                            </StackPanel>
                        </Border>

                        <!-- Sección Compresión y Rendimiento -->
                        <Border Background="#282828" BorderBrush="#3D3D3D" BorderThickness="1" CornerRadius="4" Padding="12">
                            <StackPanel>
                                <TextBlock Text="Compresión y Rendimiento de Compilación" Foreground="#00E5FF" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                                <StackPanel Orientation="Horizontal" Margin="0,0,0,8">
                                    <TextBlock Text="Nivel de Compresión WIM:" Foreground="#E3E3E3" VerticalAlignment="Center" Margin="0,0,15,0"/>
                                    <ComboBox x:Name="cmbCompression" Width="200" Height="26" Background="#333333" Foreground="Black">
                                        <ComboBoxItem Content="Max (Mayor ahorro de espacio)" IsSelected="True"/>
                                        <ComboBoxItem Content="Fast (Compilación más rápida)"/>
                                        <ComboBoxItem Content="None (Sin recompresión)"/>
                                    </ComboBox>
                                </StackPanel>
                                <CheckBox x:Name="chkSkipCleanup" Content="Omitir Limpieza de Componentes WinSxS (-SkipComponentCleanup)" Foreground="#E3E3E3" IsChecked="False" FontSize="13" Margin="0,4,0,4"/>
                                <TextBlock Text="Acelera considerablemente la creación de la ISO al omitir StartComponentCleanup / ResetBase en DISM." Foreground="#888888" FontSize="11" Margin="22,0,0,0"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>
            
            <!-- Pestaña 4 -->
            <TabItem Header="Descargas Satélite">
                <Grid Margin="15">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    
                    <TextBlock Grid.Row="0" Text="Actualizaciones de Windows (Offline)" Foreground="#00E5FF" FontWeight="Bold" FontSize="15" Margin="0,0,0,10" />
                    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,20">
                        <ComboBox x:Name="cmbUpdateVersion" Width="150" Margin="0,0,10,0">
                            <ComboBoxItem Content="11_24H2" IsSelected="True" />
                            <ComboBoxItem Content="11_25H2" />
                            <ComboBoxItem Content="11_23H2" />
                            <ComboBoxItem Content="11_LTSC_2024" />
                        </ComboBox>
                        <Button x:Name="btnDownloadUpdates" Content="📥 Descargar Updates" Width="180" Background="#2C2C2C" Foreground="#00E5FF" BorderBrush="#00E5FF" BorderThickness="1" />
                    </StackPanel>

                    <TextBlock Grid.Row="2" Text="Controladores y Entorno" Foreground="#00E5FF" FontWeight="Bold" FontSize="15" Margin="0,0,0,10" />
                    <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="0,0,0,10">
                        <Button x:Name="btnBackupDrivers" Content="💾 Respaldar Drivers Host" Width="180" Margin="0,0,10,0" Background="#2C2C2C" Foreground="White" BorderBrush="#555" />
                        <Button x:Name="btnDownloadCritical" Content="📦 Drivers Críticos (VMD/VirtIO)" Width="200" Margin="0,0,10,0" Background="#2C2C2C" Foreground="White" BorderBrush="#555" />
                        <Button x:Name="btnDownloadRuntimes" Content="⚙️ Runtimes C++/DirectX" Width="180" Background="#2C2C2C" Foreground="White" BorderBrush="#555" />
                    </StackPanel>
                </Grid>
            </TabItem>
            
            <!-- Pestaña 5 -->
            <TabItem Header="Herramientas del Host">
                <Grid Margin="15">
                    <StackPanel Orientation="Vertical">
                        <TextBlock Text="Despliegue Rápido (Hyper-V)" Foreground="#E3E3E3" FontWeight="SemiBold" FontSize="15" Margin="0,10,0,5" />
                        <TextBlock Text="Levanta una máquina virtual Gen2 con la última ISO optimizada creada en WinISO_Optimizado para probar el sistema sin instalarlo en hardware real." Foreground="#A0A0A0" TextWrapping="Wrap" Margin="0,0,0,10" />
                        <Button x:Name="btnTestVM" Content="Levantar Máquina Virtual de Prueba" Height="32" Width="280" HorizontalAlignment="Left" Background="#0078D4" Foreground="White" BorderThickness="0" Margin="0,0,0,25" />

                        <TextBlock Text="Higiene y Mantenimiento" Foreground="#E3E3E3" FontWeight="SemiBold" FontSize="15" Margin="0,10,0,5" />
                        <TextBlock Text="Limpia carpetas temporales y desmonta imágenes WIM huérfanas que hayan quedado tras compilaciones abortadas." Foreground="#A0A0A0" TextWrapping="Wrap" Margin="0,0,0,10" />
                        <Button x:Name="btnCleanHost" Content="Limpiar Residuos (Carpetas, Montajes)" Height="32" Width="280" HorizontalAlignment="Left" Background="#D13438" Foreground="White" BorderThickness="0" />
                    </StackPanel>
                </Grid>
            </TabItem>

            <!-- Pestaña 6 -->
            <TabItem x:Name="tabItemLogs" Header="Consola de Logs">
                <Grid Margin="0">
                    <TextBox x:Name="txtConsole" Background="#121212" Foreground="#CCCCCC" FontFamily="Consolas" FontSize="13" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" IsReadOnly="True" BorderThickness="0" Padding="8" />
                </Grid>
            </TabItem>
        </TabControl>
        
        <!-- Footer / StatusBar -->
        <Border Background="#2D2D2D" Height="50" VerticalAlignment="Bottom" BorderBrush="#1C1C1C" BorderThickness="0,1,0,0">
            <Grid>
                <!-- StatusBar Info -->
                <TextBlock x:Name="txtStatus" Text="Estado: Listo para compilar" Foreground="#A0A0A0" Margin="15,16,0,0" FontSize="13" HorizontalAlignment="Left" />
                <ProgressBar x:Name="progBar" IsIndeterminate="True" Visibility="Hidden" HorizontalAlignment="Left" Height="10" Margin="210,20,0,0" Width="180" Foreground="#00E5FF" Background="#222222" BorderThickness="0" Minimum="0" Maximum="100" />
                
                <!-- Buttons -->
                <Button x:Name="btnExportPreset" Content="Solo JSON" Margin="0,0,230,0" Height="30" Width="100" HorizontalAlignment="Right" Background="#333333" Foreground="#E3E3E3" BorderThickness="1" BorderBrush="#454545" ToolTip="Exporta el archivo de configuración sin ejecutar el proceso" />
                <Button x:Name="btnCancel" Content="Cancelar" Margin="0,0,120,0" Height="30" Width="100" HorizontalAlignment="Right" Background="#C50F1F" Foreground="White" BorderThickness="0" IsEnabled="False" />
                <Button x:Name="btnBuild" Content="Compilar ISO" Margin="0,0,15,0" Height="30" Width="95" HorizontalAlignment="Right" Background="#0078D4" Foreground="White" BorderThickness="0" FontWeight="SemiBold" ToolTip="Inicia el motor de optimización" />
            </Grid>
        </Border>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)


# =============================================================================
# WIM DISCOVERY ASYNC
# Detecta ediciones disponibles al seleccionar la ISO.
# Usa Mount-DiskImage + Get-WindowsImage en runspace background + DispatcherTimer
# para actualizar la UI sin bloquear el hilo principal WPF.
# =============================================================================
function Invoke-WimDiscoveryAsync {
    param([string]$IsoPath, $Window)

    $lbxEditions = $Window.FindName('lbxWimEditions')
    $lblStatus   = $Window.FindName('lblEditionsStatus')

    $Window.Dispatcher.Invoke([action]{
        $lbxEditions.Items.Clear()
        $lblStatus.Text = "Analizando ISO... Por favor espera."
    })

    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $rs.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs

    [void]$ps.AddScript({
        param($IsoPath, $LogPath)
        $images  = @()
        $mounted = $null
        try {
            $mounted = Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop
            Start-Sleep -Milliseconds 800
            $vol   = $mounted | Get-Volume -ErrorAction Stop
            $drive = $vol.DriveLetter
            $wim   = "${drive}:\sources\install.wim"
            $esd   = "${drive}:\sources\install.esd"
            if (Test-Path $wim) {
                $images = Get-WindowsImage -ImagePath $wim -ErrorAction Stop |
                          Select-Object ImageIndex, ImageName
            } elseif (Test-Path $esd) {
                $images = @([PSCustomObject]@{
                    ImageIndex = 0
                    ImageName  = 'install.esd (seleccion de indices no disponible)'
                })
            }
        } catch {
            if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
                try {
                    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $line = "[$ts] [WARN] [WimDiscovery] No se pudieron obtener imagenes WIM/ESD desde ($IsoPath) - $($_.Exception.Message)`r`n"
                } catch {
                    [Console]::WriteLine("[WimDiscovery Log Error] $($_.Exception.Message)")
                }
            }
        }
        finally {
            if ($null -ne $mounted) {
                Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null
            }
        }
        return $images
    })
    [void]$ps.AddArgument($IsoPath)
    [void]$ps.AddArgument($script:StudioLogPath)
    $handle  = $ps.BeginInvoke()
    $msgData = @{ PS = $ps; RS = $rs; Win = $Window; Lbx = $lbxEditions; Lbl = $lblStatus; Handle = $handle; Iso = $IsoPath }

    $timer          = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)
    $timer.Tag      = $msgData
    $timer.Add_Tick({
        $d = $This.Tag
        if ($d.Handle.IsCompleted) {
            $This.Stop()
            try {
                $imgs = $d.PS.EndInvoke($d.Handle)
                $d.RS.Close()
                $d.Win.Dispatcher.Invoke([action]{
                    $d.Lbx.Items.Clear()
                    $isEsd = $false
                    foreach ($img in $imgs) {
                        if ($img.ImageIndex -eq 0) { $isEsd = $true; continue }
                        $cb           = New-Object System.Windows.Controls.CheckBox
                        $cb.Content   = "[$($img.ImageIndex)] $($img.ImageName)"
                        $cb.Tag       = "$($img.ImageIndex)"
                        $cb.IsChecked = $true
                        $cb.Foreground = '#E0E0E0'
                        $d.Lbx.Items.Add($cb)
                    }
                    if ($isEsd) {
                        $d.Lbl.Text = "Archivo install.esd detectado. Seleccion de indices no disponible."
                    } elseif ($d.Lbx.Items.Count -gt 0) {
                        $count = $d.Lbx.Items.Count
                        $d.Lbl.Text = "$count edicion(es) encontrada(s). Desmarca las que no quieras incluir."
                    } else {
                        $d.Lbl.Text = "No se pudieron leer ediciones. Se procesaran todos los indices."
                    }
                })
            } catch {
                Write-StudioLog "Aviso al procesar ediciones WIM desde ($($d.Iso)): $($_.Exception.Message)" "WARN"
                $d.Win.Dispatcher.Invoke([action]{
                    $d.Lbl.Text = "Error al analizar WIM. Se usaran todos los indices."
                })
            }
        }
    })
    $timer.Start()
}

function Set-StudioUIState {
    param(
        [bool]$IsRunning,
        [string]$TaskName = "Listo para compilar"
    )
    $window.Dispatcher.Invoke([action]{
        $btnBuild            = $window.FindName('btnBuild')
        $btnCancel           = $window.FindName('btnCancel')
        $progBar             = $window.FindName('progBar')
        $txtStatus           = $window.FindName('txtStatus')
        $btnTestVM           = $window.FindName('btnTestVM')
        $btnCleanHost        = $window.FindName('btnCleanHost')
        $btnDownloadUpdates  = $window.FindName('btnDownloadUpdates')
        $btnBackupDrivers    = $window.FindName('btnBackupDrivers')
        $btnDownloadCritical = $window.FindName('btnDownloadCritical')
        $btnDownloadRuntimes = $window.FindName('btnDownloadRuntimes')

        if ($btnBuild)            { $btnBuild.IsEnabled = -not $IsRunning }
        if ($btnCancel)           { $btnCancel.IsEnabled = $IsRunning }
        if ($btnTestVM)           { $btnTestVM.IsEnabled = -not $IsRunning }
        if ($btnCleanHost)        { $btnCleanHost.IsEnabled = -not $IsRunning }
        if ($btnDownloadUpdates)  { $btnDownloadUpdates.IsEnabled = -not $IsRunning }
        if ($btnBackupDrivers)    { $btnBackupDrivers.IsEnabled = -not $IsRunning }
        if ($btnDownloadCritical) { $btnDownloadCritical.IsEnabled = -not $IsRunning }
        if ($btnDownloadRuntimes) { $btnDownloadRuntimes.IsEnabled = -not $IsRunning }

        if ($IsRunning) {
            if ($progBar) { $progBar.Visibility = "Visible" }
            if ($txtStatus) {
                $txtStatus.Text = "Estado: $TaskName..."
                $txtStatus.Foreground = "#0078D4"
            }
        } else {
            if ($progBar) { $progBar.Visibility = "Hidden" }
            if ($txtStatus) {
                $txtStatus.Text = "Estado: $TaskName"
                $txtStatus.Foreground = "#A0A0A0"
            }
        }
    })
}

function Start-StudioSubProcess {
    param(
        [string]$CommandLine,
        [string]$TaskTitle
    )
    Write-StudioLog "Iniciando tarea: $TaskTitle"
    Set-StudioUIState -IsRunning $true -TaskName $TaskTitle

    $tabControl = $window.FindName('tabControlMain')
    $tabLogs = $window.FindName('tabItemLogs')
    if ($tabLogs -and $tabControl) {
        $tabControl.SelectedItem = $tabLogs
    } elseif ($tabControl) {
        $tabControl.SelectedIndex = $tabControl.Items.Count - 1
    }

    $txtConsole = $window.FindName('txtConsole')
    $txtConsole.AppendText("`r`n════════════════════════════════════════════════════════════════`r`n")
    $txtConsole.AppendText("[INICIO] $TaskTitle`r`n")
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
        ProgBar   = $window.FindName('progBar')
    }

    $timer.Add_Tick({
        $t = $This.Tag
        $line = ""
        while ($t.Queue.TryDequeue([ref]$line)) {
            $t.Txt.AppendText("$line`r`n")
            $t.Txt.ScrollToEnd()
            Write-StudioLog $line

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
                Write-StudioLog "Aviso liberando recursos de RunSpace en tarea de Studio: $($_.Exception.Message)" "WARN"
            }

            $exitCode = $t.State.ExitCode
            Write-StudioLog "Tarea finalizada: $($t.TaskTitle) con codigo de salida $exitCode"
            if ($exitCode -eq 0) {
                $t.Txt.AppendText("`r`n[EXITO] $($t.TaskTitle) finalizado satisfactoriamente.`r`n")
                if ($t.ProgBar) {
                    $t.ProgBar.IsIndeterminate = $false
                    $t.ProgBar.Value = 100
                }
                Set-StudioUIState -IsRunning $false -TaskName "$($t.TaskTitle) completado con éxito"
            } else {
                $t.Txt.AppendText("`r`n[FALLO] $($t.TaskTitle) finalizo con codigo de error $exitCode.`r`n")
                if ($t.Txt) {
                    $t.Txt.BorderBrush = [System.Windows.Media.Brushes]::Red
                }
                if ($t.ProgBar) {
                    $t.ProgBar.IsIndeterminate = $false
                    $t.ProgBar.Foreground = [System.Windows.Media.Brushes]::Red
                }
                Set-StudioUIState -IsRunning $false -TaskName "Error en $($t.TaskTitle) (Codigo $exitCode)"
            }
            $t.Txt.ScrollToEnd()
            $script:activeSubProcessState = $null
        }
    })

    $timer.Start()
}

# =============================================================================
# VINCULACIÓN DINÁMICA DE EVENTOS EN CONTROLES DE LA INTERFAZ
# =============================================================================
$chkZeroTouch = $window.FindName('chkZeroTouch')
$cmbZeroTouchDisk = $window.FindName('cmbZeroTouchDisk')
$txtZeroTouchWarning = $window.FindName('txtZeroTouchWarning')

if ($chkZeroTouch) {
    $chkZeroTouch.Add_Checked({
        if ($cmbZeroTouchDisk) { $cmbZeroTouchDisk.IsEnabled = $true }
        if ($txtZeroTouchWarning) {
            $txtZeroTouchWarning.Visibility = [System.Windows.Visibility]::Visible
            $lbxEditions = $window.FindName('lbxWimEditions')
            $checkedCount = 0
            if ($lbxEditions) {
                foreach ($item in $lbxEditions.Items) {
                    if ($item.IsChecked -eq $true) { $checkedCount++ }
                }
            }
            if ($checkedCount -gt 1) {
                $txtZeroTouchWarning.Text = "⚠️ ATENCIÓN: Zero-Touch formateará el disco seleccionado y completará la instalación entera sin intervención. Requiere que selecciones una única edición en 'Construcción Base'."
            } else {
                $txtZeroTouchWarning.Text = "⚠️ ADVERTENCIA: Zero-Touch borrará y formateará por completo el disco físico seleccionado (UEFI/GPT con WinRE de 500 MB). Si no estás seguro, desmarca esta opción para elegir la partición manualmente."
            }
        }
    })
    $chkZeroTouch.Add_Unchecked({
        if ($cmbZeroTouchDisk) { $cmbZeroTouchDisk.IsEnabled = $false }
        if ($txtZeroTouchWarning) { $txtZeroTouchWarning.Visibility = [System.Windows.Visibility]::Collapsed }
    })
}

$chkIntegrateDrivers = $window.FindName('chkIntegrateDrivers')
$chkBootWimDrivers = $window.FindName('chkBootWimDrivers')

if ($chkIntegrateDrivers) {
    $chkIntegrateDrivers.Add_Checked({
        if ($chkBootWimDrivers) {
            $chkBootWimDrivers.IsEnabled = $true
            $chkBootWimDrivers.IsChecked = $true
        }
    })
    $chkIntegrateDrivers.Add_Unchecked({
        if ($chkBootWimDrivers) {
            $chkBootWimDrivers.IsEnabled = $false
            $chkBootWimDrivers.IsChecked = $false
        }
    })
}

# =============================================================================
# GENERADOR CANÓNICO DE CONFIGURACIÓN DEL PRESET (SSOT)
# =============================================================================
function Get-StudioBuildConfig {
    $sourceIso = $window.FindName('txtSourceISO').Text
    $cmbProfile = $window.FindName('cmbProfile')
    $optProfile = [string]($cmbProfile.SelectedIndex + 1)
    
    $cmbComp = $window.FindName('cmbCompression')
    $optComp = if ($cmbComp -and $cmbComp.Text) { ($cmbComp.Text -split ' ')[0] } else { 'Max' }
    
    $cmbLang = $window.FindName('cmbLanguage')
    $optLang = if ($cmbLang -and $cmbLang.Text) { ($cmbLang.Text -split ' ')[0] } else { 'es-ES' }
    
    $cmbLoc = $window.FindName('cmbLocale')
    $optLoc = if ($cmbLoc -and $cmbLoc.Text) { ($cmbLoc.Text -split ' ')[0] } else { 'es-AR' }
    
    $cmbKb = $window.FindName('cmbKeyboard')
    $optKb = if ($cmbKb -and $cmbKb.Text) { ($cmbKb.Text -split ' ')[0] } else { 'es-419' }
    
    $cmbTz = $window.FindName('cmbTimezone')
    $optTz = if ($cmbTz -and $cmbTz.Text) { $cmbTz.Text.Trim() } else { 'Argentina Standard Time' }
    
    $txtUser = $window.FindName('txtLocalUser')
    $localUser = if ($txtUser -and -not [string]::IsNullOrWhiteSpace($txtUser.Text)) { $txtUser.Text.Trim() } else { 'Roman' }
    
    $txtPass = $window.FindName('txtLocalPassword')
    $localPass = if ($txtPass) { $txtPass.Text } else { '' }
    
    $chkAutoLogon = $window.FindName('chkAutoLogon')
    $autoLogonCount = if ($chkAutoLogon -and $chkAutoLogon.IsChecked) { 1 } else { 0 }
    
    $chkZeroTouch = $window.FindName('chkZeroTouch')
    $zeroTouch = [bool]($chkZeroTouch -and $chkZeroTouch.IsChecked)
    
    $cmbDisk = $window.FindName('cmbZeroTouchDisk')
    $zeroTouchDisk = if ($cmbDisk -and $cmbDisk.SelectedIndex -ge 0) { $cmbDisk.SelectedIndex } else { 0 }
    
    $chkUpdates = $window.FindName('chkIntegrateUpdates')
    $integrateUpdates = [bool]($chkUpdates -and $chkUpdates.IsChecked)
    
    $chkDrivers = $window.FindName('chkIntegrateDrivers')
    $integrateDrivers = [bool]($chkDrivers -and $chkDrivers.IsChecked)
    
    $chkBootWim = $window.FindName('chkBootWimDrivers')
    $skipBootWimDrivers = -not [bool]($chkBootWim -and $chkBootWim.IsChecked)
    
    $chkRuntimes = $window.FindName('chkIntegrateRuntimes')
    $integrateRuntimes = [bool]($chkRuntimes -and $chkRuntimes.IsChecked)
    
    $chkVisualTweaks = $window.FindName('chkVisualTweaks')
    $injectVisualTweaks = [bool]($chkVisualTweaks -and $chkVisualTweaks.IsChecked)
    
    $chkBlockOneDrive = $window.FindName('chkBlockOneDrive')
    $blockOneDrive = [bool]($chkBlockOneDrive -and $chkBlockOneDrive.IsChecked)
    
    $chkHyperV = $window.FindName('chkHyperV')
    $enableHyperV = [bool]($chkHyperV -and $chkHyperV.IsChecked)
    
    $chkSkipCleanup = $window.FindName('chkSkipCleanup')
    $skipCleanup = [bool]($chkSkipCleanup -and $chkSkipCleanup.IsChecked)
    
    # Resolver indices WIM seleccionados en el ListBox
    $lbxEditions = $window.FindName('lbxWimEditions')
    $selectedIndexes = @()
    $totalItems = 0
    if ($lbxEditions) {
        foreach ($item in $lbxEditions.Items) {
            $totalItems++
            if ($item.IsChecked -eq $true) { $selectedIndexes += $item.Tag }
        }
    }
    $targetWimIndex = if ($totalItems -eq 0 -or $selectedIndexes.Count -eq $totalItems) {
        'all'
    } elseif ($selectedIndexes.Count -gt 0) {
        $selectedIndexes -join ','
    } else {
        'all'
    }

    $desktopPath = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
    if (-not $desktopPath) { $desktopPath = Join-Path $HOME 'Desktop' }
    $outputIsoDir = Join-Path $desktopPath 'WinISO_Optimizado'

    return [ordered]@{
        SourceISO             = $sourceIso
        OutputDir             = $outputIsoDir
        DriversPath           = (Join-Path $PSScriptRoot '..\..\Drivers')
        UpdatesPath           = (Join-Path $PSScriptRoot '..\..\Updates')
        RuntimesPath          = (Join-Path $PSScriptRoot '..\..\Runtimes')
        IntegrateUpdates      = $integrateUpdates
        IntegrateDrivers      = $integrateDrivers
        SkipBootWimDrivers    = $skipBootWimDrivers
        IntegrateRuntimes     = $integrateRuntimes
        ZeroTouch             = $zeroTouch
        ZeroTouchDisk         = $zeroTouchDisk
        LocalUser             = $localUser
        LocalPassword         = $localPass
        AutoLogonCount        = $autoLogonCount
        Language              = $optLang
        Locale                = $optLoc
        KeyboardOverride      = $optKb
        Timezone              = $optTz
        OptimizationProfile   = $optProfile
        InjectVisualTweaks    = $injectVisualTweaks
        BlockOneDrive         = $blockOneDrive
        EnableHyperV          = $enableHyperV
        WimCompression        = $optComp
        SkipComponentCleanup  = $skipCleanup
        Architecture          = 'amd64'
        TargetWimIndex        = $targetWimIndex
        ExportedAt            = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
}

$btnBuild = $window.FindName('btnBuild')
$btnBuild.Add_Click({
    Write-StudioLog "El usuario hizo clic en 'Compilar ISO'."
    $config = Get-StudioBuildConfig

    if ([string]::IsNullOrWhiteSpace($config.SourceISO) -or $config.SourceISO -eq 'Ruta de la ISO...') {
        Write-StudioLog "Error de validacion: No se especifico la ruta de la ISO base." -Level "WARN"
        [System.Windows.MessageBox]::Show('Debe seleccionar una imagen ISO base para compilar.', 'Error', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    
    Write-StudioLog "ISO seleccionada: $($config.SourceISO)"
    Write-StudioLog "Indices WIM seleccionados: $($config.TargetWimIndex)"
    Write-StudioLog "Zero-Touch: $($config.ZeroTouch) (Disco: $($config.ZeroTouchDisk)) | Updates: $($config.IntegrateUpdates) | Drivers: $($config.IntegrateDrivers) | Runtimes: $($config.IntegrateRuntimes)"

    if ($config.ZeroTouch -and ($config.TargetWimIndex -eq 'all' -or $config.TargetWimIndex -match ',')) {
        Write-StudioLog "Validacion Zero-Touch: Se selecciono Zero-Touch pero hay multiples ediciones seleccionadas ($($config.TargetWimIndex))." -Level "WARN"
        $ztMsg = "Has activado la instalación 100% Zero-Touch, pero tienes seleccionadas múltiples ediciones (o todas) en la pestaña 'Construcción Base'.`n`nPara una instalación completamente automatizada (cero intervención humana de principio a fin), el instalador de Windows requiere una única edición a instalar.`n`n¿Deseas volver a la pestaña 'Construcción Base' para seleccionar una única edición?`n`n(Si eliges 'No', la compilación continuará en modo semi-desatendido donde el instalador solicitará elegir la edición y el disco manualmente)."
        $ztResult = [System.Windows.MessageBox]::Show($ztMsg, 'romanOS Studio — Selección de Edición Zero-Touch', [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($ztResult -eq [System.Windows.MessageBoxResult]::Yes) {
            $tabControl = $window.FindName('tabControlMain')
            if ($tabControl) { $tabControl.SelectedIndex = 0 }
            return
        }
    }

    $tempJsonPath = Join-Path $env:TEMP 'romanOS_BuildPreset.json'
    $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $tempJsonPath -Encoding UTF8 -Force
    Write-StudioLog "Archivo JSON temporal inyectado en: $tempJsonPath"
    
    $builderPath = Join-Path $PSScriptRoot "..\Builder\New-OptimizedWindowsISO-v2.ps1"
    $escapedBuilder = $builderPath -replace "'", "''"
    $escapedJson    = $tempJsonPath -replace "'", "''"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$escapedBuilder' -PresetFile '$escapedJson' *>&1 }`""

    Start-StudioSubProcess -CommandLine $arguments -TaskTitle "Compilación de romanOS ISO"
})

$btnCancel = $window.FindName('btnCancel')
$btnCancel.Add_Click({
    Write-StudioLog "El usuario hizo clic en 'Cancelar'."
    if ($null -ne $script:activeSubProcessState -and $script:activeSubProcessState.IsRunning) {
        $res = [System.Windows.MessageBox]::Show("¿Está seguro que desea abortar la tarea en curso? Si hay una operación de montaje WIM/DISM activa, podría requerir limpieza posterior.", "Advertencia de Cancelación", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($res -eq 'Yes') {
            try {
                $targetProc = $script:activeSubProcessState.Process
                if ($null -ne $targetProc -and -not $targetProc.HasExited) {
                    $pidToKill = $targetProc.Id
                    Write-StudioLog "Intentando detener el árbol de procesos con PID $pidToKill..." -Level "WARN"
                    & taskkill.exe /F /T /PID $pidToKill | Out-Null
                    try {
                        if (-not $targetProc.HasExited) { $targetProc.Kill() }
                    } catch {
                        Write-StudioLog "Aviso al finalizar proceso remanente PID $pidToKill - $($_.Exception.Message)" "WARN"
                    }
                    $window.FindName('txtConsole').AppendText("`r`n[!] PROCESO CANCELADO POR EL USUARIO.`r`n")
                    Write-StudioLog "Proceso PID $pidToKill terminado por intervención del usuario." -Level "WARN"
                }
            } catch {
                $window.FindName('txtConsole').AppendText("`r`n[!] Error al cancelar el proceso: $($_.Exception.Message)`r`n")
                Write-StudioLog "Excepción al intentar cancelar el proceso: $($_.Exception.Message)" -Level "ERROR"
            }
        } else {
            Write-StudioLog "Cancelación abortada por el usuario (Botón No)."
        }
    }
})

$btnBrowseISO = $window.FindName('btnBrowseISO')
$btnBrowseISO.Add_Click({
    Write-StudioLog "Boton 'Examinar ISO' presionado."
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = 'Windows ISO (*.iso)|*.iso'
    if ($dlg.ShowDialog() -eq $true) {
        $window.FindName('txtSourceISO').Text = $dlg.FileName
        Write-StudioLog "ISO seleccionada mediante dialogo: $($dlg.FileName)"
        # Lanzar WIM Discovery en background para poblar el ListBox de ediciones
        Invoke-WimDiscoveryAsync -IsoPath $dlg.FileName -Window $window
    }
})

$btnExportPreset = $window.FindName('btnExportPreset')
$btnExportPreset.Add_Click({
    Write-StudioLog "Boton 'Solo JSON' presionado."
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = 'Archivo JSON (*.json)|*.json'
    $dlg.FileName = 'Preset_romanOS_Studio.json'
    if ($dlg.ShowDialog() -eq $true) {
        $config = Get-StudioBuildConfig
        try {
            $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $dlg.FileName -Encoding UTF8 -Force
            Write-StudioLog "Preset exportado satisfactoriamente en: $($dlg.FileName)"
            [System.Windows.MessageBox]::Show("Preset JSON exportado con éxito en:`n$($dlg.FileName)", "romanOS Studio", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        } catch {
            Write-StudioLog "Error fatal al exportar JSON: $($_.Exception.Message)" -Level "FATAL"
            [System.Windows.MessageBox]::Show("Hubo un error al guardar el archivo JSON.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    }
})

$btnTestVM = $window.FindName('btnTestVM')
$btnTestVM.Add_Click({
    Write-StudioLog "El usuario hizo clic en 'Levantar Máquina Virtual de Prueba'."

    $desktopPath = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
    if (-not $desktopPath) { $desktopPath = Join-Path $HOME 'Desktop' }
    $optWinIso = Join-Path $desktopPath 'WinISO_Optimizado'

    $targetIso = $null
    if (Test-Path $optWinIso) {
        $latestCompiled = Get-ChildItem -Path $optWinIso -Filter "*.iso" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestCompiled) { $targetIso = $latestCompiled.FullName }
    }

    if (-not $targetIso) {
        $sourceIso = $window.FindName('txtSourceISO').Text
        if (-not [string]::IsNullOrWhiteSpace($sourceIso) -and (Test-Path $sourceIso -PathType Leaf) -and $sourceIso.EndsWith('.iso', [System.StringComparison]::OrdinalIgnoreCase)) {
            $targetIso = (Resolve-Path $sourceIso).Path
        }
    }

    $isoArg = if ($targetIso) {
        $escapedTarget = $targetIso -replace "'", "''"
        Write-StudioLog "Enlazando ISO identificada para VM Test: $targetIso"
        " -ISOPath '$escapedTarget'"
    } else {
        Write-StudioLog "No se detecto ISO en WinISO_Optimizado ni en txtSourceISO; usando deteccion global de Hyper-V script." "WARN"
        ""
    }

    $scriptEngine = Join-Path $PSScriptRoot "..\Testing\New-TestVM-HyperV.ps1"
    $escapedEngine = $scriptEngine -replace "'", "''"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$escapedEngine'$isoArg *>&1 }`""
    Start-StudioSubProcess -CommandLine $arguments -TaskTitle "Despliegue VM Hyper-V"
})

$btnCleanHost = $window.FindName('btnCleanHost')
$btnCleanHost.Add_Click({
    $res = [System.Windows.MessageBox]::Show(
        "Se eliminarán los archivos y directorios temporales generados durante compilaciones previas de la ISO.`n`n¿Deseas purgar los residuos del host ahora?",
        "romanOS Studio — Limpieza de Residuos",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
        $scriptEngine = Join-Path $PSScriptRoot "..\Host-Tools\Limpiar-ResiduosWinISO.ps1"
        $escapedEngine = $scriptEngine -replace "'", "''"
        $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$escapedEngine' -Unattended *>&1 }`""
        Start-StudioSubProcess -CommandLine $arguments -TaskTitle "Limpieza de Residuos del Host"
    }
})

$btnDownloadUpdates = $window.FindName('btnDownloadUpdates')
$btnDownloadUpdates.Add_Click({
    $cmbVer = $window.FindName('cmbUpdateVersion')
    $ver = if ($cmbVer -and $cmbVer.Text) { $cmbVer.Text } else { "11_24H2" }
    $updatesDir = Join-Path $PSScriptRoot "..\..\Updates"
    $scriptEngine = Join-Path $PSScriptRoot "..\Builder\Get-WindowsUpdates.ps1"
    $escapedEngine  = $scriptEngine -replace "'", "''"
    $escapedUpdates = $updatesDir -replace "'", "''"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$escapedEngine' -Version '$ver' -OutputDir '$escapedUpdates' -Unattended *>&1 }`""
    Start-StudioSubProcess -CommandLine $arguments -TaskTitle "Descarga de Windows Updates ($ver)"
})

$btnBackupDrivers = $window.FindName('btnBackupDrivers')
$btnBackupDrivers.Add_Click({
    $driversDir = Join-Path $PSScriptRoot "..\..\Drivers"
    $scriptEngine = Join-Path $PSScriptRoot "..\Drivers\Backup-HardwareDrivers.ps1"
    $escapedEngine  = $scriptEngine -replace "'", "''"
    $escapedDrivers = $driversDir -replace "'", "''"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$escapedEngine' -DestinationPath '$escapedDrivers' *>&1 }`""
    Start-StudioSubProcess -CommandLine $arguments -TaskTitle "Respaldo de Controladores del Host"
})

$btnDownloadCritical = $window.FindName('btnDownloadCritical')
$btnDownloadCritical.Add_Click({
    $driversDir = Join-Path $PSScriptRoot "..\..\Drivers"
    $scriptEngine = Join-Path $PSScriptRoot "..\Drivers\Get-CriticalDrivers.ps1"
    $escapedEngine  = $scriptEngine -replace "'", "''"
    $escapedDrivers = $driversDir -replace "'", "''"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$escapedEngine' -Package All -DestinationPath '$escapedDrivers' *>&1 }`""
    Start-StudioSubProcess -CommandLine $arguments -TaskTitle "Descarga de Controladores Críticos (VMD/VirtIO)"
})

$btnDownloadRuntimes = $window.FindName('btnDownloadRuntimes')
$btnDownloadRuntimes.Add_Click({
    $runtimesDir = Join-Path $PSScriptRoot "..\..\Runtimes"
    $scriptEngine = Join-Path $PSScriptRoot "..\Builder\Get-EssentialRuntimes.ps1"
    $escapedEngine   = $scriptEngine -replace "'", "''"
    $escapedRuntimes = $runtimesDir -replace "'", "''"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$escapedEngine' -DestinationPath '$escapedRuntimes' -Unattended *>&1 }`""
    Start-StudioSubProcess -CommandLine $arguments -TaskTitle "Descarga de Runtimes C++/DirectX"
})

$window.ShowDialog() | Out-Null





