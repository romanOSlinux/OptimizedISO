<#
.SYNOPSIS
    romanOS Studio - Interfaz grafica nativa (WPF) para construir ISOs.
.DESCRIPTION
    Actua estrictamente como Frontend. Genera un JSON y delega el trabajo pesado a New-OptimizedWindowsISO-v2.ps1
#>
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="romanOS Studio (Sandbox)" Height="550" Width="800" 
        Background="#1E1E1E" WindowStartupLocation="CenterScreen">
    <Grid>
        <!-- Header -->
        <Border Background="#2D2D30" Height="60" VerticalAlignment="Top">
            <TextBlock Text="romanOS Studio" Foreground="White" FontSize="24" FontWeight="Bold" Margin="20,15,0,0" />
        </Border>
        
        <!-- Main Content -->
        <TabControl Margin="10,70,10,60" Background="#1E1E1E" BorderBrush="#3F3F46" Foreground="White">
            <TabControl.Resources>
                <Style TargetType="TabItem">
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="TabItem">
                                <Border Name="Border" BorderThickness="1,1,1,0" BorderBrush="#3F3F46" Margin="2,0">
                                    <ContentPresenter x:Name="ContentSite" VerticalAlignment="Center" HorizontalAlignment="Center" ContentSource="Header" Margin="10,5"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsSelected" Value="True">
                                        <Setter TargetName="Border" Property="Background" Value="#3F3F46" />
                                    </Trigger>
                                    <Trigger Property="IsSelected" Value="False">
                                        <Setter TargetName="Border" Property="Background" Value="#1E1E1E" />
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                    <Setter Property="Foreground" Value="White"/>
                </Style>
            </TabControl.Resources>
            
            <TabItem Header="Construccion ISO">
                <Grid Margin="10">
                    <TextBlock Text="Ruta ISO Origen:" Foreground="White" Margin="0,20,0,0"/>
                    <TextBox x:Name="txtSourceISO" Margin="120,15,100,0" Height="25" VerticalAlignment="Top" Background="#3F3F46" Foreground="White" BorderThickness="0" Padding="3"/>
                    <Button x:Name="btnBrowseISO" Content="Examinar" Margin="0,15,10,0" Height="25" Width="80" HorizontalAlignment="Right" VerticalAlignment="Top" Background="#007ACC" Foreground="White" BorderThickness="0"/>
                    
                    <TextBlock Text="Perfil de Optimizacion:" Foreground="White" Margin="0,65,0,0"/>
                    <ComboBox x:Name="cmbProfile" Margin="150,60,0,0" Height="25" Width="200" HorizontalAlignment="Left" VerticalAlignment="Top">
                        <ComboBoxItem Content="Perfil 1 (Moderado)" />
                        <ComboBoxItem Content="Perfil 2 (Avanzado)" />
                        <ComboBoxItem Content="Perfil 3 (Hardcore)" IsSelected="True" />
                    </ComboBox>
                </Grid>
            </TabItem>
            
            <TabItem Header="Modulos Avanzados">
                <Grid Margin="10">
                    <CheckBox x:Name="chkHyperV" Content="Habilitar subsistema Hyper-V" Foreground="White" IsChecked="True" Margin="10,15,0,0" />
                    <CheckBox x:Name="chkVisualTweaks" Content="Inyectar Menu Contextual Moderno" Foreground="White" IsChecked="True" Margin="10,45,0,0" />
                    <CheckBox x:Name="chkBlockOneDrive" Content="Bloquear telemetria de OneDrive" Foreground="White" IsChecked="True" Margin="10,75,0,0" />
                </Grid>
            </TabItem>
        </TabControl>
        
        <!-- Footer -->
        <Border Background="#2D2D30" Height="50" VerticalAlignment="Bottom">
            <Grid>
                <Button x:Name="btnExportPreset" Content="Exportar JSON" Margin="0,0,130,0" Height="30" Width="120" HorizontalAlignment="Right" Background="#3F3F46" Foreground="White" BorderThickness="0" />
                <Button x:Name="btnBuild" Content="Compilar" Margin="0,0,20,0" Height="30" Width="100" HorizontalAlignment="Right" Background="#007ACC" Foreground="White" BorderThickness="0" FontWeight="Bold"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$btnBuild = $window.FindName('btnBuild')
$btnBuild.Add_Click({
    $sourceIso = $window.FindName('txtSourceISO').Text
    if ([string]::IsNullOrWhiteSpace($sourceIso) -or $sourceIso -eq 'Ruta de la ISO...') {
        [System.Windows.MessageBox]::Show('Debe seleccionar una imagen ISO base para compilar.', 'Error', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    # Generar JSON temporal
    $cmbProfile = $window.FindName('cmbProfile')
    $optProfile = [string]($cmbProfile.SelectedIndex + 1)
    $chkHyperV = $window.FindName('chkHyperV')
    $chkVisualTweaks = $window.FindName('chkVisualTweaks')
    $chkBlockOneDrive = $window.FindName('chkBlockOneDrive')
    
    $config = [ordered]@{
        SourceISO           = $sourceIso
        DriversPath         = 'Drivers'
        EnableHyperV        = [bool]$chkHyperV.IsChecked
        InjectWin11Script   = $false
        Language            = 'es-ES'
        Locale              = 'es-AR'
        Timezone            = 'Argentina Standard Time'
        KeyboardOverride    = 'es-419'
        LocalUser           = 'Roman'
        LocalPassword       = ''
        OptimizationProfile = $optProfile
        BlockOneDrive       = [bool]$chkBlockOneDrive.IsChecked
        InjectVisualTweaks  = [bool]$chkVisualTweaks.IsChecked
        WimCompression      = 'Max'
        Architecture        = 'amd64'
        ExportedAt          = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
    
    $tempJsonPath = Join-Path $env:TEMP 'romanOS_BuildPreset.json'
    $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $tempJsonPath -Encoding UTF8 -Force
    
    # Lanzar el Builder de forma asincrona en nueva ventana
    $builderPath = Join-Path $PSScriptRoot "..\Builder\New-OptimizedWindowsISO-v2.ps1"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { & '$builderPath' -BuildPreset '$tempJsonPath' }`""
    
    Start-Process -FilePath "powershell.exe" -ArgumentList $arguments
    
    [System.Windows.MessageBox]::Show('El proceso de compilación ha iniciado en una nueva ventana de PowerShell. Puede minimizar esta interfaz.', 'Compilación Iniciada', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

$btnBrowseISO = $window.FindName('btnBrowseISO')
$btnBrowseISO.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = 'Windows ISO (*.iso)|*.iso'
    if ($dlg.ShowDialog() -eq $true) {
        $window.FindName('txtSourceISO').Text = $dlg.FileName
    }
})

$btnExportPreset = $window.FindName('btnExportPreset')
$btnExportPreset.Add_Click({
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = 'Archivo JSON (*.json)|*.json'
    $dlg.FileName = 'Preset_romanOS_Studio.json'
    if ($dlg.ShowDialog() -eq $true) {
        $sourceIso = $window.FindName('txtSourceISO').Text
        $cmbProfile = $window.FindName('cmbProfile')
        $optProfile = [string]($cmbProfile.SelectedIndex + 1)
        $chkHyperV = $window.FindName('chkHyperV')
        $chkVisualTweaks = $window.FindName('chkVisualTweaks')
        $chkBlockOneDrive = $window.FindName('chkBlockOneDrive')
        
        $config = [ordered]@{
            SourceISO           = $sourceIso
            DriversPath         = 'Drivers'
            EnableHyperV        = [bool]$chkHyperV.IsChecked
            InjectWin11Script   = $false
            Language            = 'es-ES'
            Locale              = 'es-AR'
            Timezone            = 'Argentina Standard Time'
            KeyboardOverride    = 'es-419'
            LocalUser           = 'Roman'
            LocalPassword       = ''
            OptimizationProfile = $optProfile
            BlockOneDrive       = [bool]$chkBlockOneDrive.IsChecked
            InjectVisualTweaks  = [bool]$chkVisualTweaks.IsChecked
            WimCompression      = 'Max'
            Architecture        = 'amd64'
            ExportedAt          = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        }
        
        $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $dlg.FileName -Encoding UTF8 -Force
        [System.Windows.MessageBox]::Show("Preset JSON exportado con éxito en:`n$($dlg.FileName)", "romanOS Studio", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

$window.ShowDialog() | Out-Null
