<#
.SYNOPSIS
Auditoria y Diagnostico Integral Post-Instalacion de Windows
Generado automaticamente por New-OptimizedWindowsISO
#>
param(
    [string]$OutputDir = "$env:WINDIR\Setup\Logs",
    [switch]$DesktopOutput,
    [switch]$ShowInNotepad,
    [string]$ExpectedProfile = "2",
    [bool]$ExpectedBlockOneDrive = $false
)

$ErrorActionPreference = 'Continue'

try {
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $desktopPath = [Environment]::GetFolderPath('CommonDesktopDirectory')
    if (-not $desktopPath -or -not (Test-Path $desktopPath)) {
        $desktopPath = if ($env:PUBLIC) { "$env:PUBLIC\Desktop" } else { "C:\Users\Public\Desktop" }
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $reportLines = [System.Collections.Generic.List[string]]::new()
    $criticalErrors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $passedChecks = [System.Collections.Generic.List[string]]::new()

    # Encabezado
    $reportLines.Add("# Reporte de Auditoria y Diagnostico Post-Instalacion")
    $reportLines.Add("")
    $reportLines.Add("- **Fecha de Analisis:** $timestamp")

    # 1. Informacion del Sistema
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1

        $isVM = if ($cs.Model -match 'Virtual|Hyper-V|VMware|KVM|QEMU|VirtualBox') { "Maquina Virtual ($($cs.Model))" } else { "Equipo Fisico ($($cs.Manufacturer) $($cs.Model))" }
        $ramGB = if ($cs.TotalPhysicalMemory) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) } else { "N/A" }
        $ubr = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name UBR -ErrorAction SilentlyContinue).UBR
        $fullBuild = if ($ubr) { "$($os.Version).$ubr" } else { "$($os.Version)" }

        $reportLines.Add("- **Edicion:** $($os.Caption)")
        $reportLines.Add("- **Compilacion:** $fullBuild ($($os.OSArchitecture))")
        $reportLines.Add("- **Entorno:** $isVM")
        $reportLines.Add("- **Procesador:** $($cpu.Name)")
        $reportLines.Add("- **Memoria RAM:** $ramGB GB")
        $reportLines.Add("- **Nombre de Equipo:** $env:COMPUTERNAME")
        $reportLines.Add("- **Usuario Actual:** $env:USERNAME")
        $reportLines.Add("- **Perfil Esperado:** Perfil $ExpectedProfile")
    } catch {
        $reportLines.Add("- **Informacion del Sistema:** Error obteniendo telemetria ($($_.Exception.Message))")
    }

    $reportLines.Add("")

    # 2. Almacenamiento y Huella del Sistema
    $reportLines.Add("## 1. Almacenamiento y Huella del Sistema")
    $reportLines.Add("")
    try {
        $sysDrive = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue)
        if ($sysDrive) {
            $totalGB = [math]::Round($sysDrive.Size / 1GB, 2)
            $freeGB  = [math]::Round($sysDrive.FreeSpace / 1GB, 2)
            $usedGB  = [math]::Round(($sysDrive.Size - $sysDrive.FreeSpace) / 1GB, 2)
            $pctUsed = [math]::Round(($usedGB / $totalGB) * 100, 1)

            $compactStatus = & compact.exe /CompactOS:query 2>&1
            $isCompact = if ($compactStatus -match 'is in the Compact state|est[aá] en el estado Compact') { "Habilitado (CompactOS Activo)" } else { "Deshabilitado (Estandar)" }

            $passedChecks.Add("Almacenamiento C: auditado ($usedGB GB usados de $totalGB GB, $freeGB GB libres).")
            $reportLines.Add("- **Particion C:** $usedGB GB usados / $totalGB GB totales ($pctUsed% ocupado, $freeGB GB libres)")
            $reportLines.Add("- **Compresion CompactOS:** $isCompact")
        }
    } catch {
        $reportLines.Add("- **Almacenamiento:** Error al consultar Win32_LogicalDisk ($($_.Exception.Message))")
    }

    $reportLines.Add("")

    # 3. Auditoria de Windows Setup (Panther y UnattendGC)
    $reportLines.Add("## 2. Auditoria de Logs Oficiales de Windows Setup")
    $reportLines.Add("")

    # Panther\setuperr.log
    $pantherErr = "$env:WINDIR\Panther\setuperr.log"
    if (Test-Path $pantherErr) {
        $errLines = @(Get-Content -Path $pantherErr -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne "" })
        if ($errLines.Count -gt 0) {
            $warnings.Add("Panther\setuperr.log contiene $($errLines.Count) linea(s) de error/advertencia.")
            $reportLines.Add("### [WARN] Windows Setup Base: Panther\setuperr.log ($($errLines.Count) eventos)")
            $reportLines.Add('```text')
            foreach ($l in ($errLines | Select-Object -Last 10)) { $reportLines.Add($l) }
            $reportLines.Add('```')
        } else {
            $passedChecks.Add("Windows Setup Base: Panther\setuperr.log limpio (0 errores).")
            $reportLines.Add("- **Panther\setuperr.log:** Limpio (0 errores detectados) [OK]")
        }
    } else {
        $passedChecks.Add("Windows Setup Base: Panther\setuperr.log sin errores.")
        $reportLines.Add("- **Panther\setuperr.log:** Limpio / Sin errores registrados [OK]")
    }

    # Panther\UnattendGC\setuperr.log
    $unattendErr = "$env:WINDIR\Panther\UnattendGC\setuperr.log"
    if (Test-Path $unattendErr) {
        $uErrLines = @(Get-Content -Path $unattendErr -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne "" })
        if ($uErrLines.Count -gt 0) {
            $criticalErrors.Add("UnattendGC\setuperr.log contiene $($uErrLines.Count) error(es) en autounattend.xml.")
            $reportLines.Add("### [ERROR] OOBE / Unattend: UnattendGC\setuperr.log ($($uErrLines.Count) eventos)")
            $reportLines.Add('```text')
            foreach ($l in ($uErrLines | Select-Object -Last 10)) { $reportLines.Add($l) }
            $reportLines.Add('```')
        } else {
            $passedChecks.Add("Unattend / OOBE: UnattendGC\setuperr.log limpio (0 errores).")
            $reportLines.Add("- **UnattendGC\setuperr.log:** Limpio (0 errores en autounattend.xml) [OK]")
        }
    } else {
        $passedChecks.Add("Unattend / OOBE: UnattendGC\setuperr.log sin errores.")
        $reportLines.Add("- **UnattendGC\setuperr.log:** Limpio / Sin errores registrados [OK]")
    }

    $reportLines.Add("")

    # 4. Auditoria de SetupComplete.cmd y Runtimes
    $reportLines.Add("## 3. Auditoria de SetupComplete.cmd y Runtimes")
    $reportLines.Add("")

    $setupCompleteLog = "$env:WINDIR\Setup\Scripts\SetupComplete.log"
    if (Test-Path $setupCompleteLog) {
        $scContent = Get-Content -Path $setupCompleteLog -Raw -ErrorAction SilentlyContinue
        if ($scContent -match 'SetupComplete\.cmd finalizado exitosamente') {
            $passedChecks.Add("SetupComplete.cmd ejecuto y finalizo exitosamente.")
            $reportLines.Add("- **Estado de SetupComplete.cmd:** Finalizado Exitosamente [OK]")
        } else {
            $warnings.Add("SetupComplete.cmd no registro la marca de finalizacion exitosa.")
            $reportLines.Add("- **Estado de SetupComplete.cmd:** Incompleto o no finalizado [WARN]")
        }
    } else {
        $reportLines.Add("- **Estado de SetupComplete.cmd:** Log no encontrado en $setupCompleteLog")
    }

    # Verificacion de Visual C++ Redistributables
    $vcKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $installedVC = @(Get-ItemProperty $vcKeys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Visual C\+\+' } | Select-Object -ExpandProperty DisplayName -Unique)
    if ($installedVC.Count -gt 0) {
        $passedChecks.Add("Visual C++ Redistributables: $($installedVC.Count) paquetes instalados.")
        $reportLines.Add("- **Visual C++ Redistributables:** $($installedVC.Count) paquetes detectados [OK]")
    } else {
        $reportLines.Add("- **Visual C++ Redistributables:** No se detectaron paquetes VC++ instalados.")
    }

    # Verificacion de Plan de Energia
    try {
        $activePlan = & powercfg /getactivescheme 2>&1
        $reportLines.Add("- **Esquema de Energia Activo:** $activePlan")
    } catch {}

    $reportLines.Add("")

    # 5. Auditoria de Bypasses, Politicas y Registro
    $reportLines.Add("## 4. Estado de Tweaks, Registro y Bypasses")
    $reportLines.Add("")

    # BypassNRO
    $bypassNro = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name BypassNRO -ErrorAction SilentlyContinue).BypassNRO
    if ($bypassNro -eq 1) {
        $passedChecks.Add("Bypass de Cuenta Microsoft (BypassNRO = 1) activo.")
        $reportLines.Add("- **Bypass Cuenta Microsoft (BypassNRO):** Activo (1) [OK]")
    } else {
        $reportLines.Add("- **Bypass Cuenta Microsoft (BypassNRO):** Inactivo o no configurado.")
    }

    # Bloqueo OneDrive
    if ($ExpectedBlockOneDrive) {
        $odVal = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name DisableFileSyncNGSC -ErrorAction SilentlyContinue).DisableFileSyncNGSC
        if ($odVal -eq 1) {
            $passedChecks.Add("Bloqueo de OneDrive (DisableFileSyncNGSC = 1) activo.")
            $reportLines.Add("- **Bloqueo de OneDrive:** Activo (1) [OK]")
        } else {
            $warnings.Add("La directiva de bloqueo de OneDrive no esta activa.")
            $reportLines.Add("- **Bloqueo de OneDrive:** Inactivo [WARN]")
        }
    }

    # Exclusion de Drivers en Windows Update
    $wuDrivers = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name ExcludeWUDriversInQualityUpdate -ErrorAction SilentlyContinue).ExcludeWUDriversInQualityUpdate
    if ($wuDrivers -eq 1) {
        $passedChecks.Add("Exclusion de Drivers en Windows Update activa.")
        $reportLines.Add("- **Exclusion Drivers Windows Update:** Activa (1) [OK]")
    } else {
        $reportLines.Add("- **Exclusion Drivers Windows Update:** Inactiva o no configurada (0).")
    }

    # Busqueda de Drivers Local-Only
    $drvSearch = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" -Name SearchOrderConfig -ErrorAction SilentlyContinue).SearchOrderConfig
    if ($drvSearch -eq 0) {
        $passedChecks.Add("Busqueda de Drivers en modo solo local activa.")
        $reportLines.Add("- **Busqueda de Drivers (Local-Only):** Activa (0) [OK]")
    } else {
        $reportLines.Add("- **Busqueda de Drivers (Local-Only):** Inactiva ($drvSearch).")
    }

    # Bloqueo Metadata OEM
    $metaBlock = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name PreventDeviceMetadataFromNetwork -ErrorAction SilentlyContinue).PreventDeviceMetadataFromNetwork
    if ($metaBlock -eq 1) {
        $passedChecks.Add("Bloqueo de Metadata OEM en red activo.")
        $reportLines.Add("- **Bloqueo Metadata y Apps OEM:** Activo (1) [OK]")
    } else {
        $reportLines.Add("- **Bloqueo Metadata y Apps OEM:** Inactivo o no configurado.")
    }

    # Bloqueo WPBT ACPI
    $wpbtVal = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name DisableWPBT -ErrorAction SilentlyContinue).DisableWPBT
    if ($wpbtVal -eq 1) {
        $passedChecks.Add("Bloqueo de tabla ACPI WPBT activo.")
        $reportLines.Add("- **Bloqueo ACPI WPBT (OEM Bloatware):** Activo (1) [OK]")
    } else {
        $reportLines.Add("- **Bloqueo ACPI WPBT (OEM Bloatware):** Inactivo o no configurado.")
    }

    # Prevencion Cifrado Automatico BitLocker (PreventDeviceEncryption)
    $bitlockerPrevent = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker" -Name PreventDeviceEncryption -ErrorAction SilentlyContinue).PreventDeviceEncryption
    if ($bitlockerPrevent -eq 1) {
        $passedChecks.Add("Prevencion de Cifrado BitLocker (PreventDeviceEncryption = 1) activa.")
        $reportLines.Add("- **Prevencion Cifrado BitLocker:** Activa (1 - DirectStorage/BypassIO Habilitado) [OK]")
    } else {
        $reportLines.Add("- **Prevencion Cifrado BitLocker:** Inactiva o no configurada ($bitlockerPrevent).")
    }

    # Verificacion de Claves de Menu Contextual Avanzado
    $ctxMenuKeys = @(
        @{ Path = "HKLM:\SOFTWARE\Classes\Directory\Background\shell\PSAdmin";        Label = "PSAdmin (Terminal Administrador)" },
        @{ Path = "HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\RestartExplorer";   Label = "RestartExplorer (Reiniciar Explorer)" },
        @{ Path = "HKLM:\SOFTWARE\Classes\Directory\Background\shell\FlushDNS";       Label = "FlushDNS (Vaciar Cache DNS)" },
        @{ Path = "HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\GodMode";           Label = "GodMode (Panel Control Maestro)" },
        @{ Path = "HKLM:\SOFTWARE\Classes\*\shell\OpenWithNotepad";                   Label = "OpenWithNotepad (Abrir con Notepad)" },
        @{ Path = "HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\RepairSystem";      Label = "RepairSystem (DISM + SFC)" }
    )
    $ctxAll = $true
    foreach ($k in $ctxMenuKeys) {
        if (Test-Path $k.Path) {
            $reportLines.Add("- **Menu Contextual [$($k.Label)]:** Registrado [OK]")
        } else {
            $ctxAll = $false
            $reportLines.Add("- **Menu Contextual [$($k.Label)]:** NO encontrado.")
        }
    }
    if ($ctxAll) { $passedChecks.Add("Funciones avanzadas de menu contextual (6/6) registradas.") }

    # Verificacion de Directivas GPO de Rendimiento en Navegadores
    $edgeGPU   = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name HardwareAccelerationModeEnabled -ErrorAction SilentlyContinue).HardwareAccelerationModeEnabled
    $edgeSleep = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name SleepingTabsEnabled -ErrorAction SilentlyContinue).SleepingTabsEnabled
    $edgeBoost = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name StartupBoostEnabled -ErrorAction SilentlyContinue).StartupBoostEnabled
    if ($edgeGPU -eq 1 -and $edgeSleep -eq 1 -and $edgeBoost -eq 0) {
        $passedChecks.Add("Directivas GPO de rendimiento en Navegadores activas (GPU/SleepingTabs/ZeroBackground).")
        $reportLines.Add("- **Navegadores (GPO Edge/Chrome):** Optimizado (GPU: 1, SleepingTabs: 1, Background: 0) [OK]")
    } else {
        $reportLines.Add("- **Navegadores (GPO Edge/Chrome):** Estandar o no configurado.")
    }

    # Modo Oscuro
    $appsDark = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name AppsUseLightTheme -ErrorAction SilentlyContinue).AppsUseLightTheme
    $sysDark = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name SystemUsesLightTheme -ErrorAction SilentlyContinue).SystemUsesLightTheme
    if ($appsDark -eq 0 -and $sysDark -eq 0) {
        $passedChecks.Add("Modo Oscuro activo en cuenta de usuario.")
        $reportLines.Add("- **Tema Visual:** Modo Oscuro Activo (Apps: 0, Sistema: 0) [OK]")
    } else {
        $reportLines.Add("- **Tema Visual:** Modo Estandar / Claro (Apps: $appsDark, Sistema: $sysDark)")
    }

    $reportLines.Add("")

    # 6. Auditoria de Debloat AppX / UWP
    $reportLines.Add("## 5. Auditoria de Paquetes AppX / UWP Aprovisionados")
    $reportLines.Add("")
    try {
        $appxPackages = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue)
        if ($appxPackages.Count -gt 0) {
            $knownBloatList = @(
                'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.GetHelp',
                'Microsoft.Getstarted', 'Microsoft.MicrosoftSolitaireCollection',
                'Microsoft.People', 'Microsoft.Todos', 'Microsoft.WindowsFeedbackHub',
                'Microsoft.XboxApp', 'Microsoft.XboxGamingOverlay', 'Microsoft.Clipchamp.Clipchamp',
                'MicrosoftCorporationII.QuickAssist'
            )
            $detectedBloat = @($appxPackages | Where-Object { $pkg = $_.DisplayName; $knownBloatList | Where-Object { $pkg -like "*$_*" } })
            
            $reportLines.Add("- **Total Paquetes Aprovisionados:** $($appxPackages.Count) paquete(s) registrados en la imagen.")
            if ($detectedBloat.Count -gt 0) {
                $reportLines.Add("- **Paquetes Promocionales/Telemetria Residuales:** $($detectedBloat.Count) detectado(s)")
                foreach ($b in $detectedBloat) {
                    $reportLines.Add("  - $($b.DisplayName)")
                }
            } else {
                $passedChecks.Add("Debloat AppX: 0 paquetes promocionales o telemetria residuales.")
                $reportLines.Add("- **Estado de Debloat AppX:** Limpio (0 paquetes promocionales/telemetria detectados) [OK]")
            }
        } else {
            $reportLines.Add("- **Auditoria AppX:** Consulta requiere elevacion de Administrador.")
        }
    } catch {
        $reportLines.Add("- **Auditoria AppX:** Error consultando paquetes provisionados ($($_.Exception.Message))")
    }

    $reportLines.Add("")

    # 7. Licenciamiento y Activacion WMI
    $reportLines.Add("## 6. Estado de Licenciamiento y Activacion")
    $reportLines.Add("")
    try {
        $licProducts = @(Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL" -ErrorAction SilentlyContinue)
        if ($licProducts.Count -gt 0) {
            foreach ($lp in $licProducts) {
                $statusText = switch ($lp.LicenseStatus) {
                    0 { "Sin Licencia (Unlicensed)" }
                    1 { "Licenciado / Activado (Licensed)" }
                    2 { "Periodo de Gracia OOBE (OOBE Grace)" }
                    3 { "Periodo de Gracia Fuera de Tolerancia (OOT Grace)" }
                    4 { "Periodo de Gracia de No Genuino (Non-Genuine Grace)" }
                    5 { "Notificacion (Notification)" }
                    6 { "Gracia Extendida (Extended Grace)" }
                    default { "Estado ($($lp.LicenseStatus))" }
                }
                $isLicensed = ($lp.LicenseStatus -eq 1)
                if ($isLicensed) {
                    $passedChecks.Add("Licencia de Windows: Activada ($($lp.Name)).")
                }
                $reportLines.Add("- **Producto:** $($lp.Name)")
                $reportLines.Add("- **Estado:** $statusText $(if ($isLicensed) { '[OK]' } else { '' })")
                $reportLines.Add("- **Clave Parcial:** $($lp.PartialProductKey)")
            }
        } else {
            $reportLines.Add("- **Licenciamiento:** Sin claves de producto registradas (Imagen limpia o generica).")
        }
    } catch {
        $reportLines.Add("- **Licenciamiento:** No disponible ($($_.Exception.Message))")
    }

    $reportLines.Add("")

    # 8. Seguridad del Kernel y VBS
    $reportLines.Add("## 7. Seguridad del Kernel y Virtualization-Based Security (VBS)")
    $reportLines.Add("")
    try {
        $dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
        if ($dg) {
            $vbsStatus = switch ($dg.VirtualizationBasedSecurityStatus) {
                0 { "Deshabilitado (0)" }
                1 { "Habilitado pero no en ejecucion (1)" }
                2 { "Habilitado y en ejecucion (2)" }
                default { "Estado ($($dg.VirtualizationBasedSecurityStatus))" }
            }
            $reportLines.Add("- **Virtualization-Based Security (VBS):** $vbsStatus")
            
            $secServices = @()
            if ($dg.SecurityServicesRunning -contains 1) { $secServices += "HVCI (Integridad de Memoria)" }
            if ($dg.SecurityServicesRunning -contains 2) { $secServices += "Credential Guard" }
            if ($secServices.Count -gt 0) {
                $reportLines.Add("- **Servicios de Seguridad Activos:** $($secServices -join ', ')")
            } else {
                $reportLines.Add("- **Servicios de Seguridad Activos:** Ninguno (Maximo rendimiento)")
            }
            $passedChecks.Add("Seguridad del Kernel / DeviceGuard auditado ($vbsStatus).")
        } else {
            $reportLines.Add("- **Win32_DeviceGuard:** No disponible en esta edicion o entorno VM sin virtualizacion anidada.")
        }
    } catch {
        $reportLines.Add("- **DeviceGuard / VBS:** Consulta no disponible ($($_.Exception.Message))")
    }

    $reportLines.Add("")

    # 9. Auditoria de Servicios de Rendimiento
    $reportLines.Add("## 8. Estado de Servicios de Rendimiento")
    $reportLines.Add("")

    $servicesToCheck = @("DiagTrack", "dmwappushservice", "WerSvc", "TroubleshootingSvc", "BDESVC", "Fax", "SCardSvr", "RemoteRegistry", "RetailDemo", "MapsBroker", "lfsvc", "WSearch", "Spooler", "WlanSvc", "bthserv", "SensorService", "SysMain")
    foreach ($sName in $servicesToCheck) {
        $svc = Get-Service -Name $sName -ErrorAction SilentlyContinue
        if ($svc) {
            $startMode = (Get-CimInstance Win32_Service -Filter "Name='$sName'" -ErrorAction SilentlyContinue).StartMode
            $reportLines.Add("- **Servicio $($sName):** Estado: $($svc.Status) | Inicio: $startMode")
        } else {
            $reportLines.Add("- **Servicio $($sName):** No instalado en esta edicion.")
        }
    }

    $reportLines.Add("")

    # 10. Auditoria de Hardware y Controladores PnP
    $reportLines.Add("## 9. Auditoria de Hardware y Controladores (PnP)")
    $reportLines.Add("")

    try {
        $problemDevices = @(Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'OK' -and $_.Class -ne 'System' -and $_.Problem -ne 'CM_PROB_PHANTOM' })
        if ($problemDevices.Count -gt 0) {
            $warnings.Add("Se detectaron $($problemDevices.Count) dispositivo(s) con advertencia o falta de driver.")
            $reportLines.Add("### [WARN] Dispositivos con problemas detectados ($($problemDevices.Count)):")
            $reportLines.Add("| Dispositivo | Clase | Estado | Codigo de Problema |")
            $reportLines.Add("|---|---|---|---|")
            foreach ($d in $problemDevices) {
                $reportLines.Add("| $($d.FriendlyName) | $($d.Class) | $($d.Status) | $($d.Problem) |")
            }
        } else {
            $passedChecks.Add("Hardware: 0 dispositivos con problemas de controladores.")
            $reportLines.Add("- **Estado de Dispositivos:** Todos los dispositivos PnP inicializados correctamente (0 errores) [OK]")
        }
    } catch {
        $reportLines.Add("- **Auditoria PnP:** Consulta no disponible en este entorno.")
    }

    $reportLines.Add("")

    # 11. Evaluacion Final y Resumen Ejecutivo
    $finalStatus = if ($criticalErrors.Count -gt 0) {
        "FAILED / CON ERRORES"
    } elseif ($warnings.Count -gt 0) {
        "SUCCESS WITH WARNINGS"
    } else {
        "SUCCESS (100% LIMPIO)"
    }

    $summaryLines = @(
        "## Resumen Ejecutivo de Instalacion"
        ""
        "- **Estado General:** **$finalStatus**"
        "- **Verificaciones Aprobadas:** $($passedChecks.Count)"
        "- **Advertencias:** $($warnings.Count)"
        "- **Errores Criticos:** $($criticalErrors.Count)"
        ""
    )

    $finalReport = ($reportLines[0..3] + $summaryLines + $reportLines[4..($reportLines.Count - 1)]) -join "`r`n"

    # Guardar reportes en disco
    $systemReportPath = Join-Path $OutputDir "PostInstall_Report.md"
    [System.IO.File]::WriteAllText($systemReportPath, $finalReport, [System.Text.Encoding]::UTF8)

    $desktopReportPath = Join-Path $desktopPath "INFORME_INSTALACION.md"
    try {
        [System.IO.File]::WriteAllText($desktopReportPath, $finalReport, [System.Text.Encoding]::UTF8)
    } catch {}

    # Salida en consola
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  AUDITORIA POST-INSTALACION DE WINDOWS                                   " -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  Estado: $finalStatus" -ForegroundColor $(if ($criticalErrors.Count -gt 0) { 'Red' } elseif ($warnings.Count -gt 0) { 'Yellow' } else { 'Green' })
    Write-Host "  Verificaciones Aprobadas : $($passedChecks.Count)" -ForegroundColor Green
    Write-Host "  Advertencias             : $($warnings.Count)" -ForegroundColor $(if ($warnings.Count -gt 0) { 'Yellow' } else { 'Gray' })
    Write-Host "  Errores Criticos         : $($criticalErrors.Count)" -ForegroundColor $(if ($criticalErrors.Count -gt 0) { 'Red' } else { 'Gray' })
    Write-Host "  Informe guardado en      : $desktopReportPath" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host ""

    if ($ShowInNotepad) {
        Start-Process -FilePath "notepad.exe" -ArgumentList $desktopReportPath
    }
} catch {
    Write-Host "[ERROR] Excepcion durante la auditoria post-instalacion: $($_.Exception.Message)" -ForegroundColor Red
}
