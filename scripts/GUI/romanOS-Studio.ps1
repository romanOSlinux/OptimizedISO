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
    # CRITICO: usar -Command con *>&1 para que Write-Host (Stream 6) llegue al stdout redirigido.
    # Con -File, Write-Host va al InformationStream y BeginOutputReadLine() nunca lo captura.
    $escapedBuilder = $builderPath -replace "'", "''"
    $escapedJson    = $tempJsonPath -replace "'", "''"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$escapedBuilder' -PresetFile '$escapedJson' *>&1 }`""


    Write-StudioLog "Preparando proceso de compilacion en segundo plano (Oculto)."
    
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "powershell.exe"
    $pinfo.Arguments = $arguments
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    $pinfo.RedirectStandardInput = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    
    $script:workerProcess = New-Object System.Diagnostics.Process
    $script:workerProcess.StartInfo = $pinfo
    $script:workerProcess.EnableRaisingEvents = $true
    
    # Update UI to running state
    $tabControl = $window.FindName('tabControlMain')
    $tabControl.SelectedIndex = 3
    
    $txtConsole = $window.FindName('txtConsole')
    $txtConsole.Text = "Iniciando compilacion de romanOS...`r`n"
    
    $btnBuild.IsEnabled = $false
    $btnCancel = $window.FindName('btnCancel')
    $btnCancel.IsEnabled = $true
    
    $txtStatus = $window.FindName('txtStatus')
    $txtStatus.Text = "Estado: Ejecutando DISM y políticas..."
    $txtStatus.Foreground = "#0078D4"
    $progBar = $window.FindName('progBar')
    $progBar.Visibility = "Visible"
    
    $msgData = @{ Window = $window; TextBox = $txtConsole; BtnBuild = $btnBuild; BtnCancel = $btnCancel; Status = $txtStatus; Prog = $progBar }
    
    $outputAction = {
        $line = $Event.SourceEventArgs.Data
        if ($line -ne $null) {
            $win = $Event.MessageData.Window
            $txt = $Event.MessageData.TextBox
            $win.Dispatcher.Invoke([action]{
                $txt.AppendText("$line`r`n")
                $txt.ScrollToEnd()
            })
        }
    }
    
    $exitAction = {
        $win = $Event.MessageData.Window
        $txt = $Event.MessageData.TextBox
        $btnB = $Event.MessageData.BtnBuild
        $btnC = $Event.MessageData.BtnCancel
        $stat = $Event.MessageData.Status
        $prog = $Event.MessageData.Prog
        
        Write-StudioLog "El proceso de compilacion en segundo plano (PID: $($script:workerProcess.Id)) ha finalizado."
        
        $win.Dispatcher.Invoke([action]{
            $txt.AppendText("`r`n[SISTEMA] Proceso finalizado.`r`n")
            $txt.ScrollToEnd()
            $btnB.IsEnabled = $true
            $btnC.IsEnabled = $false
            $stat.Text = "Estado: Tarea completada"
            $stat.Foreground = "#A0A0A0"
            $prog.Visibility = "Hidden"
        })
    }
    
    Get-EventSubscriber -SourceIdentifier "StdOut_romanOS" -ErrorAction SilentlyContinue | Unregister-Event
    Get-EventSubscriber -SourceIdentifier "StdErr_romanOS" -ErrorAction SilentlyContinue | Unregister-Event
    Get-EventSubscriber -SourceIdentifier "Exit_romanOS" -ErrorAction SilentlyContinue | Unregister-Event
    
    Register-ObjectEvent -InputObject $script:workerProcess -EventName OutputDataReceived -SourceIdentifier "StdOut_romanOS" -MessageData $msgData -Action $outputAction | Out-Null
    Register-ObjectEvent -InputObject $script:workerProcess -EventName ErrorDataReceived -SourceIdentifier "StdErr_romanOS" -MessageData $msgData -Action $outputAction | Out-Null
    Register-ObjectEvent -InputObject $script:workerProcess -EventName Exited -SourceIdentifier "Exit_romanOS" -MessageData $msgData -Action $exitAction | Out-Null
    
    try {
        $script:workerProcess.Start() | Out-Null
        $script:workerProcess.BeginOutputReadLine()
        $script:workerProcess.BeginErrorReadLine()
        Write-StudioLog "Proceso iniciado exitosamente con PID: $($script:workerProcess.Id)"
    } catch {
        Write-StudioLog "Error critico al iniciar el proceso: $($_.Exception.Message)" -Level "FATAL"
    }
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

$window.ShowDialog() | Out-Null
