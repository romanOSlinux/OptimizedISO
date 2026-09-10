<#
.SYNOPSIS
    romanOS Studio - Interfaz grafica nativa (WPF) para construir ISOs.
.DESCRIPTION
    Actua estrictamente como Frontend. Genera un JSON y delega el trabajo pesado a New-OptimizedWindowsISO-v2.ps1
#>
# Auto-elevación obligatoria para operaciones DISM y permisos de administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $targetPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }
    $psi.Arguments = "-STA -NoProfile -ExecutionPolicy Bypass -File `"$targetPath`""
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
        Title="romanOS Studio" Height="600" Width="850" 
        Background="#202020" WindowStartupLocation="CenterScreen"
        FontFamily="Segoe UI">
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
                                    <ContentPresenter x:Name="ContentSite" VerticalAlignment="Center" HorizontalAlignment="Center" ContentSource="Header" Margin="15,8"/>
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
                    <Setter Property="FontSize" Value="14"/>
                </Style>
            </TabControl.Resources>
            
            <!-- Pestaña 1 -->
            <TabItem Header="Construcción Base">
                <Grid Margin="15">
                    <TextBlock Text="Imagen de Origen (Windows 10/11 ISO):" Foreground="#E3E3E3" Margin="0,15,0,0" FontWeight="SemiBold"/>
                    <TextBox x:Name="txtSourceISO" Margin="260,10,110,0" Height="28" VerticalAlignment="Top" Background="#333333" Foreground="#E3E3E3" BorderBrush="#454545" BorderThickness="1" Padding="4"/>
                    <Button x:Name="btnBrowseISO" Content="Examinar" Margin="0,10,10,0" Height="28" Width="90" HorizontalAlignment="Right" VerticalAlignment="Top" Background="#333333" Foreground="#E3E3E3" BorderThickness="1" BorderBrush="#454545"/>
                    
                    <TextBlock Text="Perfil de Optimización (Hardware-Engine):" Foreground="#E3E3E3" Margin="0,65,0,0" FontWeight="SemiBold"/>
                    <ComboBox x:Name="cmbProfile" Margin="260,60,0,0" Height="28" Width="220" HorizontalAlignment="Left" VerticalAlignment="Top" Background="#333333" Foreground="Black">
                        <ComboBoxItem Content="Perfil 1 (Moderado / Ofimática)" />
                        <ComboBoxItem Content="Perfil 2 (Avanzado / Gaming)" />
                        <ComboBoxItem Content="Perfil 3 (Hardcore / Extremo)" IsSelected="True" />
                    </ComboBox>
                    <!-- Ediciones WIM detectadas -->
                    <TextBlock Text="Ediciones del WIM a incluir:" Foreground="#E3E3E3" Margin="0,115,0,0" FontWeight="SemiBold"/>
                    <TextBlock x:Name="lblEditionsStatus" Text="Selecciona una ISO para ver las ediciones disponibles" Foreground="#606060" FontSize="11" Margin="0,140,0,0"/>
                    <ListBox x:Name="lbxWimEditions" Margin="0,160,0,0" Height="90" Background="#1A1A1A" BorderBrush="#454545" BorderThickness="1"
                             ScrollViewer.VerticalScrollBarVisibility="Auto" VerticalAlignment="Top"/>
                </Grid>
            </TabItem>
            
            <!-- Pestaña 2 -->

            <TabItem Header="Ajustes de Imagen">
                <Grid Margin="15">
                    <TextBlock Text="Nivel de Compresión (WIM):" Foreground="#E3E3E3" Margin="0,15,0,0" FontWeight="SemiBold"/>
                    <ComboBox x:Name="cmbCompression" Margin="200,10,0,0" Height="28" Width="150" HorizontalAlignment="Left" VerticalAlignment="Top" Background="#333333" Foreground="Black">
                        <ComboBoxItem Content="Max" IsSelected="True" />
                        <ComboBoxItem Content="Fast" />
                        <ComboBoxItem Content="None" />
                    </ComboBox>
                    
                    <TextBlock Text="Idioma (Language Pack):" Foreground="#E3E3E3" Margin="0,65,0,0" FontWeight="SemiBold"/>
                    <ComboBox x:Name="cmbLanguage" Margin="200,60,0,0" Height="28" Width="150" HorizontalAlignment="Left" VerticalAlignment="Top" Background="#333333" Foreground="Black">
                        <ComboBoxItem Content="es-ES (España)" IsSelected="True" />
                        <ComboBoxItem Content="es-MX (México)" />
                        <ComboBoxItem Content="en-US (Inglés)" />
                    </ComboBox>
                </Grid>
            </TabItem>
            
            <!-- Pestaña 3 -->
                        <TabItem Header="Descargas y Preparación">
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
                            <ComboBoxItem Content="11_23H2" />
                            <ComboBoxItem Content="10_22H2" />
                            <ComboBoxItem Content="11_LTSC_2024" />
                            <ComboBoxItem Content="10_LTSC_2021" />
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
            <TabItem Header="Módulos Avanzados">
                <Grid Margin="15">
                    <CheckBox x:Name="chkHyperV" Content="Habilitar subsistema Hyper-V (Virtualización)" Foreground="#E3E3E3" IsChecked="True" Margin="10,15,0,0" FontSize="14" />
                    <CheckBox x:Name="chkVisualTweaks" Content="Inyectar Menú Contextual Moderno (Shift+F10)" Foreground="#E3E3E3" IsChecked="True" Margin="10,45,0,0" FontSize="14" />
                    <CheckBox x:Name="chkBlockOneDrive" Content="Bloquear telemetría de OneDrive a nivel host" Foreground="#E3E3E3" IsChecked="True" Margin="10,75,0,0" FontSize="14" />
                </Grid>
            </TabItem>
            
            <!-- Pestaña 4 -->
            <TabItem Header="Consola de Logs">
                <Grid Margin="0">
                    <TextBox x:Name="txtConsole" Background="#121212" Foreground="#CCCCCC" FontFamily="Consolas" FontSize="13" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" IsReadOnly="True" BorderThickness="0" Padding="8" />
                </Grid>
            </TabItem>
            
            <!-- Pestaña 5 -->
            <TabItem Header="Herramientas del Host">
                <Grid Margin="15">
                    <StackPanel Orientation="Vertical">
                        <TextBlock Text="Despliegue Rápido (Hyper-V)" Foreground="#E3E3E3" FontWeight="SemiBold" FontSize="15" Margin="0,10,0,5" />
                        <TextBlock Text="Levanta una máquina virtual Gen2 con la ISO seleccionada para probar el sistema sin instalarlo en hardware real." Foreground="#A0A0A0" TextWrapping="Wrap" Margin="0,0,0,10" />
                        <Button x:Name="btnTestVM" Content="Levantar Máquina Virtual de Prueba" Height="32" Width="280" HorizontalAlignment="Left" Background="#0078D4" Foreground="White" BorderThickness="0" Margin="0,0,0,25" />

                        <TextBlock Text="Higiene y Mantenimiento" Foreground="#E3E3E3" FontWeight="SemiBold" FontSize="15" Margin="0,10,0,5" />
                        <TextBlock Text="Limpia carpetas temporales y desmonta imágenes WIM huérfanas que hayan quedado tras compilaciones abortadas." Foreground="#A0A0A0" TextWrapping="Wrap" Margin="0,0,0,10" />
                        <Button x:Name="btnCleanHost" Content="Limpiar Residuos (Carpetas, Montajes)" Height="32" Width="280" HorizontalAlignment="Left" Background="#D13438" Foreground="White" BorderThickness="0" />
                    </StackPanel>
                </Grid>
            </TabItem>
        </TabControl>
        
        <!-- Footer / StatusBar -->
        <Border Background="#2D2D2D" Height="50" VerticalAlignment="Bottom" BorderBrush="#1C1C1C" BorderThickness="0,1,0,0">
            <Grid>
                <!-- StatusBar Info -->
                <TextBlock x:Name="txtStatus" Text="Estado: Listo para compilar" Foreground="#A0A0A0" Margin="15,16,0,0" FontSize="13" HorizontalAlignment="Left" />
                <ProgressBar x:Name="progBar" IsIndeterminate="True" Visibility="Hidden" HorizontalAlignment="Left" Height="10" Margin="200,20,0,0" Width="100" Foreground="#0078D4" Background="#333333" BorderThickness="0" />
                
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
        param($IsoPath)
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
        } catch { }
        finally {
            if ($null -ne $mounted) {
                Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null
            }
        }
        return $images
    })
    [void]$ps.AddArgument($IsoPath)
    $handle  = $ps.BeginInvoke()
    $msgData = @{ PS = $ps; RS = $rs; Win = $Window; Lbx = $lbxEditions; Lbl = $lblStatus; Handle = $handle }

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
    $tabControl.SelectedIndex = 3

    $txtConsole = $window.FindName('txtConsole')
    $txtConsole.AppendText("`r`n════════════════════════════════════════════════════════════════`r`n")
    $txtConsole.AppendText("[INICIO] $TaskTitle`r`n")
    $txtConsole.AppendText("════════════════════════════════════════════════════════════════`r`n")
    $txtConsole.ScrollToEnd()

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "powershell.exe"
    $pinfo.Arguments = $CommandLine
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    $pinfo.RedirectStandardInput = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true

    $script:workerProcess = New-Object System.Diagnostics.Process
    $script:workerProcess.StartInfo = $pinfo
    $script:workerProcess.EnableRaisingEvents = $true

    $script:workerProcess.add_OutputDataReceived({
        param($sender, $e)
        if ($e.Data) {
            $window.Dispatcher.Invoke([action]{
                $txtConsole.AppendText("$($e.Data)`r`n")
                $txtConsole.ScrollToEnd()
            })
            Write-StudioLog $e.Data
        }
    })

    $script:workerProcess.add_ErrorDataReceived({
        param($sender, $e)
        if ($e.Data) {
            $window.Dispatcher.Invoke([action]{
                $txtConsole.AppendText("[ERROR] $($e.Data)`r`n")
                $txtConsole.ScrollToEnd()
            })
            Write-StudioLog $e.Data -Level "ERROR"
        }
    })

    $script:workerProcess.add_Exited({
        param($sender, $e)
        Write-StudioLog "Tarea finalizada: $TaskTitle (PID: $($script:workerProcess.Id))"
        $window.Dispatcher.Invoke([action]{
            $exitCode = $script:workerProcess.ExitCode
            if ($exitCode -eq 0) {
                $txtConsole.AppendText("`r`n[EXITO] $TaskTitle finalizado satisfactoriamente.`r`n")
                Set-StudioUIState -IsRunning $false -TaskName "$TaskTitle completado con éxito"
            } else {
                $txtConsole.AppendText("`r`n[FALLO] $TaskTitle finalizo con codigo de error $exitCode.`r`n")
                Set-StudioUIState -IsRunning $false -TaskName "Error en $TaskTitle (Codigo $exitCode)"
            }
            $txtConsole.ScrollToEnd()
        })
    })

    try {
        $script:workerProcess.Start() | Out-Null
        $script:workerProcess.BeginOutputReadLine()
        $script:workerProcess.BeginErrorReadLine()
        Write-StudioLog "Proceso iniciado exitosamente con PID: $($script:workerProcess.Id)"
    } catch {
        Write-StudioLog "Error critico al iniciar proceso: $($_.Exception.Message)" -Level "FATAL"
        Set-StudioUIState -IsRunning $false -TaskName "Fallo al iniciar proceso"
    }
}

$btnBuild = $window.FindName('btnBuild')
$btnBuild.Add_Click({

    Write-StudioLog "El usuario hizo clic en 'Compilar ISO'."
    $sourceIso = $window.FindName('txtSourceISO').Text
    if ([string]::IsNullOrWhiteSpace($sourceIso) -or $sourceIso -eq 'Ruta de la ISO...') {
        Write-StudioLog "Error de validacion: No se especifico la ruta de la ISO base." -Level "WARN"
        [System.Windows.MessageBox]::Show('Debe seleccionar una imagen ISO base para compilar.', 'Error', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    
    Write-StudioLog "ISO seleccionada: $sourceIso"

    # Generar JSON temporal
    $cmbProfile = $window.FindName('cmbProfile')
    $optProfile = [string]($cmbProfile.SelectedIndex + 1)
    
    $cmbComp = $window.FindName('cmbCompression')
    $optComp = $cmbComp.Text
    $cmbLang = $window.FindName('cmbLanguage')
    $optLang = $cmbLang.Text.Split(' ')[0]
    
    $chkHyperV = $window.FindName('chkHyperV')
    $chkVisualTweaks = $window.FindName('chkVisualTweaks')
    $chkBlockOneDrive = $window.FindName('chkBlockOneDrive')
    
    # Resolver indices WIM seleccionados en el ListBox
    $lbxEditions = $window.FindName('lbxWimEditions')
    $selectedIndexes = @()
    $totalItems = 0
    foreach ($item in $lbxEditions.Items) {
        $totalItems++
        if ($item.IsChecked -eq $true) { $selectedIndexes += $item.Tag }
    }
    $targetWimIndex = if ($totalItems -eq 0 -or $selectedIndexes.Count -eq $totalItems) {
        'all'
    } elseif ($selectedIndexes.Count -gt 0) {
        $selectedIndexes -join ','
    } else {
        'all'
    }
    Write-StudioLog "Indices WIM seleccionados: $targetWimIndex"

    $config = [ordered]@{
        SourceISO           = $sourceIso
        OutputDir           = (Join-Path $HOME 'Desktop\WinISO_Optimizado')
        DriversPath         = (Join-Path $PSScriptRoot '..\..\Drivers')
        UpdatesPath         = (Join-Path $PSScriptRoot '..\..\Updates')
        RuntimesPath        = (Join-Path $PSScriptRoot '..\..\Runtimes')
        EnableHyperV        = [bool]$chkHyperV.IsChecked
        InjectWin11Script   = $false
        Language            = $optLang
        Locale              = 'es-AR'
        Timezone            = 'Argentina Standard Time'
        KeyboardOverride    = 'es-419'
        LocalUser           = 'Roman'
        LocalPassword       = ''
        AutoLogonCount      = 1
        OptimizationProfile = $optProfile
        BlockOneDrive       = [bool]$chkBlockOneDrive.IsChecked
        InjectVisualTweaks  = [bool]$chkVisualTweaks.IsChecked
        WimCompression      = $optComp
        Architecture        = 'amd64'
        TargetWimIndex      = $targetWimIndex
        SkipComponentCleanup = $false
        ZeroTouch           = $false
        ExportedAt          = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
    
    $tempJsonPath = Join-Path $env:TEMP 'romanOS_BuildPreset.json'
    $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $tempJsonPath -Encoding UTF8 -Force
    Write-StudioLog "Archivo JSON temporal inyectado en: $tempJsonPath"
    
    $builderPath = Join-Path $PSScriptRoot "..\Builder\New-OptimizedWindowsISO-GUI-Engine.ps1"
    $escapedBuilder = $builderPath -replace "'", "''"
    $escapedJson    = $tempJsonPath -replace "'", "''"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$escapedBuilder' -PresetFile '$escapedJson' *>&1 }`""

    Start-StudioSubProcess -CommandLine $arguments -TaskTitle "Compilación de romanOS ISO"
})

$btnCancel = $window.FindName('btnCancel')
$btnCancel.Add_Click({
    Write-StudioLog "El usuario hizo clic en 'Cancelar'."
    if ($null -ne $script:workerProcess -and -not $script:workerProcess.HasExited) {
        $res = [System.Windows.MessageBox]::Show("¿Esta seguro que desea abortar la compilacion? DISM podria dejar la imagen temporal montada.", "Advertencia", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($res -eq 'Yes') {
            try {
                Write-StudioLog "Intentando detener el proceso con PID $($script:workerProcess.Id)..." -Level "WARN"
                $script:workerProcess.Kill()
                $window.FindName('txtConsole').AppendText("`r`n[!] PROCESO CANCELADO POR EL USUARIO.`r`n")
                Write-StudioLog "Proceso detenido con exito por intervencion del usuario." -Level "WARN"
            } catch {
                $window.FindName('txtConsole').AppendText("`r`n[!] No se pudo cancelar el proceso.`r`n")
                Write-StudioLog "Excepcion al intentar cancelar el proceso: $($_.Exception.Message)" -Level "ERROR"
            }
        } else {
            Write-StudioLog "Cancelacion abortada por el usuario (Boton No)."
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
        $sourceIso = $window.FindName('txtSourceISO').Text
        $cmbProfile = $window.FindName('cmbProfile')
        $optProfile = [string]($cmbProfile.SelectedIndex + 1)
        
        $cmbComp = $window.FindName('cmbCompression')
        $optComp = $cmbComp.Text
        $cmbLang = $window.FindName('cmbLanguage')
        $optLang = $cmbLang.Text.Split(' ')[0]
        
        $chkHyperV = $window.FindName('chkHyperV')
        $chkVisualTweaks = $window.FindName('chkVisualTweaks')
        $chkBlockOneDrive = $window.FindName('chkBlockOneDrive')
        
        $config = [ordered]@{
            SourceISO           = $sourceIso
            DriversPath         = 'Drivers'
            EnableHyperV        = [bool]$chkHyperV.IsChecked
            InjectWin11Script   = $false
            Language            = $optLang
            Locale              = 'es-AR'
            Timezone            = 'Argentina Standard Time'
            KeyboardOverride    = 'es-419'
            LocalUser           = 'Roman'
            LocalPassword       = ''
            OptimizationProfile = $optProfile
            BlockOneDrive       = [bool]$chkBlockOneDrive.IsChecked
            InjectVisualTweaks  = [bool]$chkVisualTweaks.IsChecked
            WimCompression      = $optComp
            Architecture        = 'amd64'
            ExportedAt          = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        }
        
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
    $isoPath = $window.FindName('txtSourceISO').Text
    if (-not (Test-Path $isoPath)) {
        Write-StudioLog "ERROR: Seleccione una ISO válida para probar en Hyper-V."
        [System.Windows.MessageBox]::Show("Seleccione una ISO válida primero en la pestaña 'Construcción Base'.", "romanOS Studio", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    
    $scriptEngine = Join-Path $PSScriptRoot "..\Testing\New-TestVM-HyperV.ps1"
    $escapedEngine = $scriptEngine -replace "'", "''"
    $escapedIso    = $isoPath -replace "'", "''"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$escapedEngine' -ISOPath '$escapedIso' *>&1 }`""
    Start-StudioSubProcess -CommandLine $arguments -TaskTitle "Despliegue VM Hyper-V"
})

$btnCleanHost = $window.FindName('btnCleanHost')
$btnCleanHost.Add_Click({
    $scriptEngine = Join-Path $PSScriptRoot "..\Host-Tools\Limpiar-ResiduosWinISO-GUI-Engine.ps1"
    $escapedEngine = $scriptEngine -replace "'", "''"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$escapedEngine' *>&1 }`""
    Start-StudioSubProcess -CommandLine $arguments -TaskTitle "Limpieza de Residuos del Host"
})

$btnDownloadUpdates = $window.FindName('btnDownloadUpdates')
$btnDownloadUpdates.Add_Click({
    $cmbVer = $window.FindName('cmbUpdateVersion')
    $ver = if ($cmbVer -and $cmbVer.Text) { $cmbVer.Text } else { "11_24H2" }
    $updatesDir = Join-Path $PSScriptRoot "..\..\Updates"
    $scriptEngine = Join-Path $PSScriptRoot "..\Builder\Get-WindowsUpdates-GUI-Engine.ps1"
    $escapedEngine  = $scriptEngine -replace "'", "''"
    $escapedUpdates = $updatesDir -replace "'", "''"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$escapedEngine' -Version '$ver' -OutputDir '$escapedUpdates' -Unattended *>&1 }`""
    Start-StudioSubProcess -CommandLine $arguments -TaskTitle "Descarga de Windows Updates ($ver)"
})

$btnBackupDrivers = $window.FindName('btnBackupDrivers')
$btnBackupDrivers.Add_Click({
    $driversDir = Join-Path $PSScriptRoot "..\..\Drivers"
    $scriptEngine = Join-Path $PSScriptRoot "..\Drivers\Backup-HardwareDrivers-GUI-Engine.ps1"
    $escapedEngine  = $scriptEngine -replace "'", "''"
    $escapedDrivers = $driversDir -replace "'", "''"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$escapedEngine' -DestinationPath '$escapedDrivers' *>&1 }`""
    Start-StudioSubProcess -CommandLine $arguments -TaskTitle "Respaldo de Controladores del Host"
})

$btnDownloadCritical = $window.FindName('btnDownloadCritical')
$btnDownloadCritical.Add_Click({
    $driversDir = Join-Path $PSScriptRoot "..\..\Drivers"
    $scriptEngine = Join-Path $PSScriptRoot "..\Drivers\Get-CriticalDrivers-GUI-Engine.ps1"
    $escapedEngine  = $scriptEngine -replace "'", "''"
    $escapedDrivers = $driversDir -replace "'", "''"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$escapedEngine' -Package All -DestinationPath '$escapedDrivers' *>&1 }`""
    Start-StudioSubProcess -CommandLine $arguments -TaskTitle "Descarga de Controladores Críticos (VMD/VirtIO)"
})

$btnDownloadRuntimes = $window.FindName('btnDownloadRuntimes')
$btnDownloadRuntimes.Add_Click({
    $runtimesDir = Join-Path $PSScriptRoot "..\..\Runtimes"
    $scriptEngine = Join-Path $PSScriptRoot "..\Builder\Get-EssentialRuntimes-GUI-Engine.ps1"
    $escapedEngine   = $scriptEngine -replace "'", "''"
    $escapedRuntimes = $runtimesDir -replace "'", "''"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$escapedEngine' -DestinationPath '$escapedRuntimes' *>&1 }`""
    Start-StudioSubProcess -CommandLine $arguments -TaskTitle "Descarga de Runtimes C++/DirectX"
})

$window.ShowDialog() | Out-Null





