<#
.SYNOPSIS
    romanOS Studio - Interfaz grafica nativa (WPF) para construir ISOs.
.DESCRIPTION
    Actua estrictamente como Frontend. Genera un JSON y delega el trabajo pesado a New-OptimizedWindowsISO-v2.ps1
#>
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
    
    $tempJsonPath = Join-Path $env:TEMP 'romanOS_BuildPreset.json'
    $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $tempJsonPath -Encoding UTF8 -Force
    Write-StudioLog "Archivo JSON temporal inyectado en: $tempJsonPath"
    
    $builderPath = Join-Path $PSScriptRoot "..\Builder\New-OptimizedWindowsISO-v2.ps1"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$builderPath' -BuildPreset '$tempJsonPath' *>&1 }`""
    Write-StudioLog "Preparando proceso de compilacion en segundo plano (Oculto)."
    
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "powershell.exe"
    $pinfo.Arguments = $arguments
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
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
