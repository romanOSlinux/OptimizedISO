<#
.SYNOPSIS
    Policy-Engine.ps1 - Motor y Catálogo Centralizado de Políticas y Optimizaciones
    Fuente Única de Verdad (Single Source of Truth - SSOT) para romanOS / OptimizedISO.

.DESCRIPTION
    Define de forma centralizada todas las directivas de registro (GPO/MDM), paquetes
    AppX de debloat, servicios del sistema y parámetros de ajuste para la compilación
    de la ISO (autounattend.xml / DISM Servicing), la auditoría post-instalación
    (PostInstall-Diagnostics.ps1) y la suite bajo demanda (romanOS-Toolkit.ps1).

    100% compatible con Windows PowerShell 5.1 (powershell.exe) y PowerShell 7+ (pwsh).
    Codificación estricta UTF-8 con BOM.

.EXAMPLE
    . "$PSScriptRoot\Core\Policy-Engine.ps1"
    $policies = Get-RomanOSPolicies -Profile 1
    $xmlCommands = Export-RomanOSUnattendCommands -Profile 1 -StartOrder 2
    $checkResult = Test-RomanOSPolicy -Policy $policies[0]
#>

$global:RomanOS_Policy_Engine_Loaded = $true

# -----------------------------------------------------------------------------
# 1. MATRIZ MAESTRA DE POLÍTICAS Y DIRECTIVAS (SSOT)
# -----------------------------------------------------------------------------

$global:RomanOS_Policies = @(
    # --- MÓDULO F: WIDGETS Y BÚSQUEDA WEB DE BING ---
    @{
        Id            = "POL_WIDGETS_ALLOW"
        Module        = "Modulo F - Widgets"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Widgets"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Widgets"
        ValueName     = "AllowWidgets"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar Widgets y feeds de noticias a nivel de sistema"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-widgets"
        UnattendDesc  = "Disable Widgets and News Feeds System-Wide"
    },
    @{
        Id            = "POL_WIDGETS_DSH"
        Module        = "Modulo F - Widgets"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Dsh"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
        ValueName     = "AllowNewsAndInterests"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar Noticias e Intereses en barra de tareas (Win10/11)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-widgets"
        UnattendDesc  = "Disable News and Interests on Taskbar (Win10/11)"
    },
    @{
        Id            = "POL_SEARCH_DISABLE_WEB"
        Module        = "Modulo F - Bing Web Search"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        ValueName     = "DisableWebSearch"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar busqueda web de Bing en menu Inicio"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-search"
        UnattendDesc  = "Disable Bing Web Search in Start Menu"
    },
    @{
        Id            = "POL_SEARCH_CONNECTED_WEB"
        Module        = "Modulo F - Bing Web Search"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        ValueName     = "ConnectedSearchUseWeb"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar vistas previas web conectadas en busqueda de Inicio"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-search"
        UnattendDesc  = "Disable Connected Search Web Previews in Start Menu"
    },

    # --- MÓDULO D: IA, COPILOT Y RECALL (W11 24H2+) ---
    @{
        Id            = "POL_COPILOT_TURNOFF"
        Module        = "Modulo D - Recall & Copilot"
        Category      = "Inteligencia Artificial"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
        ValueName     = "TurnOffWindowsCopilot"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar Windows Copilot a nivel de sistema"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/manage-windows-copilot"
        UnattendDesc  = "Disable Windows Copilot System-Wide"
    },
    @{
        Id            = "POL_AI_DISABLE_ANALYSIS"
        Module        = "Modulo D - Recall & Copilot"
        Category      = "Inteligencia Artificial"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
        ValueName     = "DisableAIDataAnalysis"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar analisis de datos de IA para Recall"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/manage-recall"
        UnattendDesc  = "Disable AI Data Analysis for Recall"
    },
    @{
        Id            = "POL_RECALL_ALLOW"
        Module        = "Modulo D - Recall & Copilot"
        Category      = "Inteligencia Artificial"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
        ValueName     = "AllowRecallEnablement"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Impedir habilitacion de Windows Recall (Snapshotting)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/manage-recall"
        UnattendDesc  = "Prevent Windows Recall Enablement"
    },

    # --- MÓDULO E: RESERVED STORAGE ---
    @{
        Id            = "POL_STORAGE_RESERVED"
        Module        = "Modulo E - Reserved Storage"
        Category      = "Almacenamiento"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager"
        ValueName     = "ShippedWithReserves"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar almacenamiento reservado de parches (~7 GB liberados)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism-operating-system-uninstall-servicing-command-line-options"
        UnattendDesc  = "Disable Reserved Storage via ReserveManager"
    },

    # --- MÓDULO G: DELIVERY OPTIMIZATION P2P ---
    @{
        Id            = "POL_DO_DOWNLOAD_MODE"
        Module        = "Modulo G - Delivery Optimization"
        Category      = "Red & Rendimiento"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
        ValueName     = "DODownloadMode"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar envio P2P de actualizaciones (Modo 0: Direct HTTP Only)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-reference"
        UnattendDesc  = "Disable Delivery Optimization P2P Seeding (Mode 0: Direct HTTP Only)"
    },

    # --- MÓDULO H: PUBLICIDAD E HISTORIAL DE ACTIVIDAD ---
    @{
        Id            = "POL_ADV_DISABLED"
        Module        = "Modulo H - Publicidad & Telemetria"
        Category      = "Privacidad & Telemetria"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"
        ValueName     = "DisabledByGroupPolicy"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar ID de publicidad mediante Directiva de Grupo"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-advertisinginfo"
        UnattendDesc  = "Disable Advertising ID Tracking by Group Policy"
    },
    @{
        Id            = "POL_ACTIVITY_PUBLISH"
        Module        = "Modulo H - Publicidad & Telemetria"
        Category      = "Privacidad & Telemetria"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\System"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
        ValueName     = "PublishUserActivities"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar publicacion local de historial de actividades"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-privacy"
        UnattendDesc  = "Disable User Activity History Publishing"
    },
    @{
        Id            = "POL_ACTIVITY_UPLOAD"
        Module        = "Modulo H - Publicidad & Telemetria"
        Category      = "Privacidad & Telemetria"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\System"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
        ValueName     = "UploadUserActivities"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar sincronizacion en la nube de actividades de usuario"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-privacy"
        UnattendDesc  = "Disable User Activity Cloud Sync"
    },

    # --- PRIVACIDAD OOBE, CONSUMER FEATURES & CONTENT DELIVERY MANAGER ---
    @{
        Id            = "POL_OOBE_SCOOBE"
        Module        = "Base - Privacy Experience"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE"
        ValueName     = "DisablePrivacyExperience"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Bloquear pantallas de configuracion de privacidad post-instalacion (Scoobe)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-privacy"
        UnattendDesc  = "Block Privacy Experience screens (Scoobe)"
    },
    @{
        Id            = "POL_CLOUD_CONSUMER_FEAT"
        Module        = "Base - Anti-Bloatware"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
        ValueName     = "DisableWindowsConsumerFeatures"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar instalacion automatica de apps de consumo promocionales"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience"
        UnattendDesc  = "Disable Cloud Consumer Features (Anti-Bloatware)"
    },
    @{
        Id            = "POL_CLOUD_SOFTLANDING"
        Module        = "Base - Anti-Bloatware"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
        ValueName     = "DisableSoftLanding"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar sugerencias y consejos flotantes de Windows"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience"
        UnattendDesc  = "Disable Cloud SoftLanding Tips"
    },
    @{
        Id            = "POL_CLOUD_OPTIMIZED_CONTENT"
        Module        = "Base - Anti-Bloatware"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
        ValueName     = "DisableCloudOptimizedContent"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar contenido optimizado en la nube (Win11 24H2+)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience"
        UnattendDesc  = "Disable Cloud Optimized Content (W11 24H2+)"
    },
    @{
        Id            = "POL_CLOUD_CONSUMER_STATE"
        Module        = "Base - Anti-Bloatware"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
        ValueName     = "DisableConsumerAccountStateContent"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar contenido promocional basado en el estado de cuenta"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience"
        UnattendDesc  = "Disable Consumer Account State Content"
    },
    @{
        Id            = "POL_STORE_AUTODOWNLOAD"
        Module        = "Base - Anti-Bloatware"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore"
        ValueName     = "AutoDownload"
        Type          = "REG_DWORD"
        ExpectedValue = 2
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar descargas automaticas no solicitadas de Microsoft Store"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-applicationmanagement"
        UnattendDesc  = "Disable Automatic Microsoft Store App Downloads"
    },
    @{
        Id            = "POL_CDM_SILENT_APPS"
        Module        = "Base - Anti-Bloatware"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        ValueName     = "SilentInstalledAppsEnabled"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Bloquear instalacion silenciosa de apps en segundo plano (CDM)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience"
        UnattendDesc  = "Block Silent App Installation System-Wide (CDM)"
    },
    @{
        Id            = "POL_CDM_PREINSTALLED_APPS"
        Module        = "Base - Anti-Bloatware"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        ValueName     = "PreInstalledAppsEnabled"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Bloquear instalacion automatica de apps preconfiguradas (CDM)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience"
        UnattendDesc  = "Block Pre-Installed Apps System-Wide (CDM)"
    },
    @{
        Id            = "POL_DATACOLLECTION_TELEMETRY"
        Module        = "Base - Telemetria"
        Category      = "Privacidad & Telemetria"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        ValueName     = "AllowTelemetry"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Establecer directiva de telemetria en nivel Seguridad (0)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-system#allowtelemetry"
        UnattendDesc  = "Set AllowTelemetry policy to Security level"
    },
    @{
        Id            = "POL_PASSWORDLESS_BUILD"
        Module        = "Base - OOBE & AutoLogon"
        Category      = "Autenticacion & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"
        ValueName     = "DevicePasswordLessBuildVersion"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Permitir AutoLogon y cuentas locales sin contraseña (W11 24H2+)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/automate-windows-setup"
        UnattendDesc  = "Disable PasswordLess sign-in to allow AutoLogon without password (W11 24H2+)"
    },
    @{
        Id            = "POL_EXPLORER_RECOMMENDED"
        Module        = "Base - Shell"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
        ValueName     = "HideRecommendedSection"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Ocultar seccion Recomendados en menu Inicio"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-start"
        UnattendDesc  = "Hide Recommended section in Start Menu"
    },
    @{
        Id            = "POL_EXPLORER_SEARCH_SUGG"
        Module        = "Base - Shell"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
        ValueName     = "DisableSearchBoxSuggestions"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar sugerencias en caja de busqueda de barra de tareas"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-search"
        UnattendDesc  = "Disable Search Box Suggestions in Start and Taskbar"
    },

    # --- CONTROLADORES, METADATA Y SEGURIDAD DEL HARDWARE ---
    @{
        Id            = "POL_WU_EXCLUDE_DRIVERS"
        Module        = "Base - Controladores"
        Category      = "Hardware & Controladores"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        ValueName     = "ExcludeWUDriversInQualityUpdate"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Excluir drivers de actualizaciones automaticas de Windows Update"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/deployment/update/waas-wu-policies"
        UnattendDesc  = "Exclude Drivers from Automatic Updates (Move to Optional Updates)"
    },
    @{
        Id            = "POL_DRV_SEARCH_LOCAL"
        Module        = "Base - Controladores"
        Category      = "Hardware & Controladores"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"
        ValueName     = "SearchOrderConfig"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Buscar controladores unicamente en almacenamiento local (SearchOrderConfig=0)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows-hardware/drivers/install/driver-search-order"
        UnattendDesc  = "Block Driver Search on Windows Update via CurrentVersion hive (SearchOrderConfig=0 = local-only)"
    },
    @{
        Id            = "POL_DEV_METADATA_BLOCK"
        Module        = "Base - Controladores"
        Category      = "Hardware & Controladores"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Device Metadata"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata"
        ValueName     = "PreventDeviceMetadataFromNetwork"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Impedir descarga de metadatos y aplicaciones OEM desde internet"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows-hardware/drivers/install/device-metadata-packages"
        UnattendDesc  = "Prevent Device Metadata and OEM App Download from Network"
    },
    @{
        Id            = "POL_WPBT_DISABLE"
        Module        = "Base - Bloqueo OEM"
        Category      = "Seguridad & Hardware"
        RegistryKey   = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager"
        PSPath        = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
        ValueName     = "DisableWPBT"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Bloquear inyeccion de bloatware desde tabla ACPI WPBT en UEFI/BIOS"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows-hardware/drivers/bringup/windows-platform-binary-table"
        UnattendDesc  = "Disable WPBT ACPI Execution (Block OEM BIOS Bloatware on Notebooks/Motherboards)"
    },
    @{
        Id            = "POL_BITLOCKER_PREVENT"
        Module        = "Base - Almacenamiento"
        Category      = "Seguridad & Almacenamiento"
        RegistryKey   = "HKLM\SYSTEM\CurrentControlSet\Control\BitLocker"
        PSPath        = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
        ValueName     = "PreventDeviceEncryption"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Evitar cifrado automatico no advertido de BitLocker en instalacion limpia"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/"
        UnattendDesc  = "Prevent Automatic BitLocker Device Encryption on Clean Install"
    },
    @{
        Id            = "POL_OOBE_BYPASS_NRO"
        Module        = "Base - Bypasses"
        Category      = "Bypasses & Despliegue"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE"
        ValueName     = "BypassNRO"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Bypass de cuenta obligatoria Microsoft Account en OOBE (Permite cuenta local)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/oobe-automated-setup"
        UnattendDesc  = "Bypass Microsoft Account (BypassNRO)"
    },

    # --- RENDIMIENTO DE BAJO NIVEL (MMCSS, HAGS, TEMA) ---
    @{
        Id            = "POL_MMCSS_THROTTLING"
        Module        = "Rendimiento - MMCSS"
        Category      = "Rendimiento & Latencia"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        ValueName     = "NetworkThrottlingIndex"
        Type          = "REG_DWORD"
        ExpectedValue = 4294967295 # 0xFFFFFFFF
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar estrangulamiento de red en MMCSS para latencia minima"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service"
        UnattendDesc  = "Disable Network Throttling in MMCSS"
    },
    @{
        Id            = "POL_MMCSS_RESPONSIVENESS"
        Module        = "Rendimiento - MMCSS"
        Category      = "Rendimiento & Latencia"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        ValueName     = "SystemResponsiveness"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Optimizar receptividad del sistema en MMCSS (0% reservado para background, 100% para procesos en primer plano/gaming)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service"
        UnattendDesc  = "Optimize System Responsiveness in MMCSS (0 = 100% CPU to Foreground/Gaming)"
    },
    @{
        Id            = "POL_GPU_HAGS"
        Module        = "Rendimiento - GPU"
        Category      = "Rendimiento & Graficos"
        RegistryKey   = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        PSPath        = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        ValueName     = "HwSchMode"
        Type          = "REG_DWORD"
        ExpectedValue = 2
        Profiles      = @(1, 2, 3)
        Description   = "Programacion acelerada por hardware de GPU (HAGS = 2)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows-hardware/drivers/display/hardware-accelerated-gpu-scheduling"
        UnattendDesc  = "Enable Hardware-Accelerated GPU Scheduling (HAGS)"
    },
    @{
        Id            = "POL_MMCSS_NO_LAZY_MODE"
        Module        = "Rendimiento - MMCSS"
        Category      = "Rendimiento & Latencia"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        ValueName     = "NoLazyMode"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Prevenir modo perezoso en el planificador multimedia MMCSS para mantener frecuencia de renderizado constante"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service"
        UnattendDesc  = "Disable MMCSS Lazy Mode (Keep Full Frame Scheduling)"
    },
    @{
        Id            = "POL_SCHED_WIN32_PRIORITY"
        Module        = "Rendimiento - Kernel"
        Category      = "Rendimiento & Latencia"
        RegistryKey   = "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl"
        PSPath        = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
        ValueName     = "Win32PrioritySeparation"
        Type          = "REG_DWORD"
        ExpectedValue = 38 # 0x26: Cuantos fijos, cortos y boost 3:1 a primer plano
        Profiles      = @(1, 2, 3)
        Description   = "Optimizar separacion de prioridades del planificador (cuantos fijos/cortos con boost 3:1 para juego/ventana activa)"
        OfficialDoc   = "https://learn.microsoft.com/sysinternals/resources/windows-internals"
        UnattendDesc  = "Optimize Win32PrioritySeparation for Low Jitter and High Foreground Response"
    },
    # --- MÓDULO F1: SUBSISTEMA DE ARCHIVOS Y ALMACENAMIENTO NVME (NTFS) ---
    @{
        Id            = "POL_FS_DISABLE_8DOT3"
        Module        = "Almacenamiento - NTFS"
        Category      = "Rendimiento & Almacenamiento"
        RegistryKey   = "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem"
        PSPath        = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
        ValueName     = "NtfsDisable8dot3NameCreation"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Deshabilitar generacion de nombres cortos 8.3 DOS en todos los volumenes para reducir sobrecarga de I/O"
        OfficialDoc   = "https://learn.microsoft.com/windows-server/administration/windows-commands/fsutil-behavior"
        UnattendDesc  = "Disable NTFS 8.3 Short Name Creation System-Wide"
    },
    @{
        Id            = "POL_FS_MEMORY_USAGE"
        Module        = "Almacenamiento - NTFS"
        Category      = "Rendimiento & Almacenamiento"
        RegistryKey   = "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem"
        PSPath        = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
        ValueName     = "NtfsMemoryUsage"
        Type          = "REG_DWORD"
        ExpectedValue = 2
        Profiles      = @(1, 2, 3)
        Description   = "Incrementar pool de memoria RAM para cache de metadatos NTFS y MFT (mayor rendimiento en NVMe/SSDs)"
        OfficialDoc   = "https://learn.microsoft.com/windows-server/administration/performance-tuning/subsystems/file-server/"
        UnattendDesc  = "Increase NTFS Metadata Cache in RAM (NtfsMemoryUsage = 2)"
    },
    @{
        Id            = "POL_FS_LONG_PATHS"
        Module        = "Almacenamiento - NTFS"
        Category      = "Compatibilidad & Almacenamiento"
        RegistryKey   = "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem"
        PSPath        = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
        ValueName     = "LongPathsEnabled"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Habilitar soporte de rutas largas (>260 caracteres MAX_PATH) en Win32"
        OfficialDoc   = "https://learn.microsoft.com/windows/win32/fileio/maximum-file-path-limitation"
        UnattendDesc  = "Enable Win32 Long Paths Support (>260 characters)"
    },
    # --- MÓDULO F2: PERSONALIZACIÓN VISUAL Y MODO OSCURO (THEMES) ---
    @{
        Id            = "POL_THEME_INSTALL_THEME"
        Module        = "Personalizacion - Tema"
        Category      = "Experiencia Visual"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes"
        ValueName     = "InstallTheme"
        Type          = "REG_SZ"
        ExpectedValue = "C:\Windows\resources\Themes\dark.theme"
        Profiles      = @(1, 2, 3)
        Description   = "Establecer tema oscuro nativo (dark.theme) como tema base de instalacion del sistema (evita que OOBE cargue aero.theme en modo claro)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-themes"
        UnattendDesc  = "Set Default Windows Theme to dark.theme"
    },
    @{
        Id            = "POL_THEME_APPS_DARK"
        Module        = "Personalizacion - Tema"
        Category      = "Experiencia Visual"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        ValueName     = "AppsUseLightTheme"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Forzar tema oscuro para aplicaciones y ventanas del sistema (AppsUseLightTheme = 0)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/apps/design/style/color"
        UnattendDesc  = "Force Dark Mode for Apps (AppsUseLightTheme = 0)"
    },
    @{
        Id            = "POL_THEME_SYSTEM_DARK"
        Module        = "Personalizacion - Tema"
        Category      = "Experiencia Visual"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        ValueName     = "SystemUsesLightTheme"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Forzar tema oscuro para la barra de tareas y el menu inicio (SystemUsesLightTheme = 0)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/apps/design/style/color"
        UnattendDesc  = "Force Dark Mode for System Shell (SystemUsesLightTheme = 0)"
    },
    @{
        Id            = "POL_THEME_TRANSPARENCY"
        Module        = "Personalizacion - Tema"
        Category      = "Experiencia Visual"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        ValueName     = "EnableTransparency"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Habilitar efectos de transparencia visual nativos de Windows (EnableTransparency = 1)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/apps/design/style/acrylic"
        UnattendDesc  = "Enable Visual Transparency (EnableTransparency = 1)"
    },
    # --- MÓDULO G: POLÍTICAS DE CONTROLADORES (DRIVERS & DISPOSITIVOS) ---
    @{
        Id            = "POL_DRV_EXCLUDE_WU"
        Module        = "Drivers - Windows Update"
        Category      = "Controladores & Estabilidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        ValueName     = "ExcludeWUDriversInQualityUpdate"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Excluir drivers de las actualizaciones de calidad de Windows Update (evita sobrescribir drivers OEM/GPU)"
        OfficialDoc   = "https://learn.microsoft.com/windows-client-management/mdm/policy-csp-update"
        UnattendDesc  = "Exclude Drivers from Windows Quality Updates"
    },
    @{
        Id            = "POL_DRV_DONT_SEARCH_WU"
        Module        = "Drivers - Busqueda GPO"
        Category      = "Controladores & Estabilidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching"
        ValueName     = "DontSearchWindowsUpdate"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Directiva GPO para no buscar controladores en Windows Update"
        OfficialDoc   = "https://learn.microsoft.com/windows-client-management/mdm/policy-csp-deviceinstallation"
        UnattendDesc  = "GPO Do Not Search Windows Update for Drivers"
    },
    @{
        Id            = "POL_DRV_POL_SEARCH_ORDER"
        Module        = "Drivers - Busqueda GPO"
        Category      = "Controladores & Estabilidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching"
        ValueName     = "SearchOrderConfig"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Directiva GPO de orden de busqueda de controladores local únicamente"
        OfficialDoc   = "https://learn.microsoft.com/windows-client-management/mdm/policy-csp-deviceinstallation"
        UnattendDesc  = "GPO Local Only Driver Search Order"
    },
    @{
        Id            = "POL_DRV_ALLOW_GENERIC_FALLBACK"
        Module        = "Drivers - Instalacion"
        Category      = "Controladores & Estabilidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings"
        ValueName     = "AllowGenericDriverFallback"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Deshabilitar instalacion de drivers genericos que instalan bloatware OEM"
        OfficialDoc   = "https://learn.microsoft.com/windows-client-management/mdm/policy-csp-deviceinstallation"
        UnattendDesc  = "Disable Generic Driver Fallback and OEM Bloatware Drivers"
    },
    @{
        Id            = "POL_DRV_PREVENT_DEVICE_METADATA"
        Module        = "Drivers - Metadatos"
        Category      = "Controladores & Estabilidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Device Metadata"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata"
        ValueName     = "PreventDeviceMetadataFromNetwork"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Evitar descarga de metadatos de dispositivos desde la red (previene instalacion de apps HSA de soporte de hardware)"
        OfficialDoc   = "https://learn.microsoft.com/windows/client-management/mdm/policy-csp-deviceinstallation"
        UnattendDesc  = "Prevent Device Metadata Retrieval From Network"
    },
    @{
        Id            = "DEBLOAT_DoNotShowFeedbackNotifications"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        ValueName     = "DoNotShowFeedbackNotifications"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_AllowDeviceNameInTelemetry"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        ValueName     = "AllowDeviceNameInTelemetry"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_LimitDiagnosticLogCollection"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        ValueName     = "LimitDiagnosticLogCollection"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_LimitDumpCollection"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        ValueName     = "LimitDumpCollection"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_Enabled"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
        PSPath        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
        ValueName     = "Enabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_TailoredExperiencesWithDiagnosticDataEnabled"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy"
        PSPath        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
        ValueName     = "TailoredExperiencesWithDiagnosticDataEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_HttpAcceptLanguageOptOut"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKCU\Control Panel\International\User Profile"
        PSPath        = "HKCU:\Control Panel\International\User Profile"
        ValueName     = "HttpAcceptLanguageOptOut"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_NumberOfSIUFInPeriod"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKCU\Software\Microsoft\Siuf\Rules"
        PSPath        = "HKCU:\Software\Microsoft\Siuf\Rules"
        ValueName     = "NumberOfSIUFInPeriod"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_HasAccepted"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKCU\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy"
        PSPath        = "HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy"
        ValueName     = "HasAccepted"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_AllowInputPersonalization"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\InputPersonalization"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization"
        ValueName     = "AllowInputPersonalization"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_RestrictImplicitInkCollection"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKCU\Software\Microsoft\InputPersonalization"
        PSPath        = "HKCU:\Software\Microsoft\InputPersonalization"
        ValueName     = "RestrictImplicitInkCollection"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_RestrictImplicitTextCollection"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKCU\Software\Microsoft\InputPersonalization"
        PSPath        = "HKCU:\Software\Microsoft\InputPersonalization"
        ValueName     = "RestrictImplicitTextCollection"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_HarvestContacts"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKCU\Software\Microsoft\InputPersonalization\TrainedDataStore"
        PSPath        = "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore"
        ValueName     = "HarvestContacts"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_AcceptedPrivacyPolicy"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKCU\Software\Microsoft\Personalization\Settings"
        PSPath        = "HKCU:\Software\Microsoft\Personalization\Settings"
        ValueName     = "AcceptedPrivacyPolicy"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_EnableActivityFeed"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\System"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
        ValueName     = "EnableActivityFeed"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_DisableLocation"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
        ValueName     = "DisableLocation"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_AllowFindMyDevice"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\FindMyDevice"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice"
        ValueName     = "AllowFindMyDevice"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_IsAADCloudSearchEnabled"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
        PSPath        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
        ValueName     = "IsAADCloudSearchEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_IsMSACloudSearchEnabled"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
        PSPath        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
        ValueName     = "IsMSACloudSearchEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_IsDeviceSearchHistoryEnabled"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
        PSPath        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
        ValueName     = "IsDeviceSearchHistoryEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_AllowSearchToUseLocation"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        ValueName     = "AllowSearchToUseLocation"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_AllowCloudSearch"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        ValueName     = "AllowCloudSearch"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    },
    @{
        Id            = "DEBLOAT_Disabled"
        Category      = "Privacidad y Telemetria"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
        ValueName     = "Disabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Migrado de Win11-Debloat-v3-Adaptive"
    }
)

# -----------------------------------------------------------------------------
# 1.1 MATRIZ DE DIRECTIVAS GPO DE NAVEGADORES WEB (EDGE, CHROME, FIREFOX, BRAVE)
# -----------------------------------------------------------------------------

$global:RomanOS_BrowserPolicies = @(
    # --- MICROSOFT EDGE ---
    @{
        Browser       = "Edge"
        Category      = "Rendimiento GPU / Video"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "HardwareAccelerationModeEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Aceleracion por hardware GPU activada"
    },
    @{
        Browser       = "Edge"
        Category      = "Rendimiento GPU / Video"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "SmoothScrollingEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Desplazamiento suave activado"
    },
    @{
        Browser       = "Edge"
        Category      = "Ahorro de RAM y CPU"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "StartupBoostEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar inicio rapido en segundo plano"
    },
    @{
        Browser       = "Edge"
        Category      = "Ahorro de RAM y CPU"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "BackgroundModeEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Cerrar procesos en segundo plano al salir"
    },
    @{
        Browser       = "Edge"
        Category      = "Ahorro de RAM y CPU"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "SleepingTabsEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Pestanas inactivas en suspension para liberar RAM"
    },
    @{
        Browser       = "Edge"
        Category      = "Ahorro de RAM y CPU"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "SleepingTabsTimeout"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 300
        Description   = "Suspender pestanas tras 5 minutos de inactividad"
    },
    @{
        Browser       = "Edge"
        Category      = "Ahorro de RAM y CPU"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "EfficiencyModeEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Modo de eficiencia energetica activado"
    },
    @{
        Browser       = "Edge"
        Category      = "Ahorro de RAM y CPU"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "EfficiencyModeOption"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Opcion de modo eficiencia equilibrada"
    },
    @{
        Browser       = "Edge"
        Category      = "Ahorro de RAM y CPU"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "IntensiveWakeUpThrottlingEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Estrangular temporizadores JavaScript pesados en segundo plano"
    },
    @{
        Browser       = "Edge"
        Category      = "Rendimiento y Red"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "NewTabPagePrerenderEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar precarga de nueva pestana para ahorrar memoria"
    },
    @{
        Browser       = "Edge"
        Category      = "Rendimiento y Red"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "DiskCacheSize"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 268435456
        Description   = "Limitar cache de disco a 256 MB para evitar fragmentacion"
    },
    @{
        Browser       = "Edge"
        Category      = "Rendimiento y Red"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "NetworkPredictionOptions"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 2
        Description   = "Desactivar prediccion de red innecesaria"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "HubsSidebarEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar barra lateral Hubs"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "EdgeSidebarCustomizeEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar personalizacion de barra lateral"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "EdgeShoppingAssistantEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar asistente de compras y cupones"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "EdgeCollectionsEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar colecciones"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "ComposeInlineEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar sugerencias de redaccion asistida"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "DiagnosticData"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar envio de datos de diagnostico"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "PersonalizationReportingEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar reporte de personalizacion"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "ShowRecommendationsEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar recomendaciones comerciales"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "UserFeedbackAllowed"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar solicitudes de comentarios"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "SpotlightExperiencesAndRecommendationsEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar recomendaciones Spotlight"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "ResolveNavigationErrorsUseWebService"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "No enviar errores de navegacion a Microsoft"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "AlternateErrorPagesEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar paginas de error alternativas web"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "AllowCopilot"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar Copilot en Edge"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "ConfigureCopilot"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Configurar Copilot deshabilitado"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "Microsoft365CopilotChatIconEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar icono de chat Copilot M365"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "NewTabPageContentEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar feed de noticias en nueva pestana"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "NewTabPageQuickLinksEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar accesos rapidos patrocinados en nueva pestana"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "NewTabPageHideDefaultTopSites"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Ocultar sitios populares predeterminados"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "BingAdsSuppression"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Supresion de anuncios de Bing"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "SearchSuggestEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar envio de texto de busqueda a servidores"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "AllowPrelaunch"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar pre-lanzamiento en arranque de Windows"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "HideFirstRunExperience"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Ocultar asistente de primera ejecucion"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "TrackingPrevention"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 3
        Description   = "Prevencion de rastreo estricta (Nivel 3)"
    },

    # --- GOOGLE CHROME ---
    @{
        Browser       = "Chrome"
        Category      = "Rendimiento GPU / Video"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "HardwareAccelerationModeEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Aceleracion por hardware GPU activada en Chrome"
    },
    @{
        Browser       = "Chrome"
        Category      = "Rendimiento GPU / Video"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "SmoothScrollingEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Desplazamiento suave activado en Chrome"
    },
    @{
        Browser       = "Chrome"
        Category      = "Ahorro de RAM y CPU"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "BackgroundModeEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Cerrar procesos de Chrome al salir"
    },
    @{
        Browser       = "Chrome"
        Category      = "Ahorro de RAM y CPU"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "HighEfficiencyModeEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Ahorro de memoria (Memory Saver) activado en Chrome"
    },
    @{
        Browser       = "Chrome"
        Category      = "Rendimiento y Red"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "NewTabPagePrerenderEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar precarga de nueva pestana en Chrome"
    },
    @{
        Browser       = "Chrome"
        Category      = "Rendimiento y Red"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "DiskCacheSize"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 268435456
        Description   = "Limitar cache de disco a 256 MB en Chrome"
    },
    @{
        Browser       = "Chrome"
        Category      = "Rendimiento y Red"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "NetworkPredictionOptions"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 2
        Description   = "Desactivar prediccion de red en Chrome"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "PromotionalTabsEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar pestanas promocionales de Google"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "ShoppingListEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar modulo de compras de Chrome"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "MetricsReportingEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar telemetria de metricas en Chrome"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "SpellCheckServiceEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "No enviar texto al corrector ortografico en la nube"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "PrivacySandboxAdMeasurementEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar medicion de anuncios Privacy Sandbox"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "PrivacySandboxAdTopicsEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar topicos de anuncios Privacy Sandbox"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "PrivacySandboxSiteTriggeredAttributionEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar atribucion de sitios Privacy Sandbox"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "AlternateErrorPagesEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar paginas de error web de Google"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "NTPContentSuggestionsEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar sugerencias de contenido en nueva pestana"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "NTPCardsVisible"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Ocultar tarjetas de contenido en nueva pestana"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "SearchSuggestEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar envio de texto en barra de direcciones de Chrome"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "GenAiDefaultSettings"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 2
        Description   = "Desactivar IA generativa predeterminada en Chrome"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "GenAiHelpMeWriteSettings"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 2
        Description   = "Desactivar Help Me Write IA en Chrome"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "GenAiHistorySearchSettings"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 2
        Description   = "Desactivar busqueda en historial asistida por IA"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "GenAiTabOrganizationSettings"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 2
        Description   = "Desactivar organizador de pestanas por IA"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "BrowserSignin"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar inicio de sesion forzado en el navegador"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "SyncDisabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Desactivar sincronizacion en la nube de Google"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "ShowCastIconInToolbar"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Ocultar icono de Chromecast en barra de herramientas"
    },

    # --- MOZILLA FIREFOX ---
    @{
        Browser       = "Firefox"
        Category      = "Rendimiento GPU / Video"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
        ValueName     = "HardwareAcceleration"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Aceleracion por hardware GPU activada en Firefox"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
        ValueName     = "DisableTelemetry"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Desactivar telemetria en Firefox"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
        ValueName     = "DisablePocket"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Desactivar Pocket en Firefox"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
        ValueName     = "DisableFirefoxStudies"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Desactivar estudios de Mozilla"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
        ValueName     = "DisableFeedbackCommands"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Desactivar comandos de feedback en Firefox"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
        ValueName     = "BackgroundAppUpdate"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar actualizacion de Firefox en segundo plano"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
        ValueName     = "OverrideFirstRunPage"
        Type          = "REG_SZ"
        PSType        = "String"
        ExpectedValue = ""
        Description   = "Omitir pagina de bienvenida de primera ejecucion"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
        ValueName     = "OverridePostUpdatePage"
        Type          = "REG_SZ"
        PSType        = "String"
        ExpectedValue = ""
        Description   = "Omitir pagina de novedades tras actualizacion"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox\UserMessaging"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\UserMessaging"
        ValueName     = "ExtensionRecommendations"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar recomendaciones de extensiones"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox\UserMessaging"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\UserMessaging"
        ValueName     = "FeatureRecommendations"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar recomendaciones de funciones"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox\UserMessaging"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\UserMessaging"
        ValueName     = "MoreFromMozilla"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar promociones More From Mozilla"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox\UserMessaging"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\UserMessaging"
        ValueName     = "SkipOnboarding"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Omitir onboarding de bienvenida"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox\UserMessaging"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\UserMessaging"
        ValueName     = "WhatsNew"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar aviso Whats New"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox\UserMessaging"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\UserMessaging"
        ValueName     = "UrlbarInterventions"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar intervenciones en barra de direcciones"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
        ValueName     = "Pocket"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar Pocket en inicio de Firefox"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
        ValueName     = "SponsoredPocket"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar Pocket patrocinado"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
        ValueName     = "Snippets"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar fragmentos promocionales Snippets"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
        ValueName     = "SponsoredTopSites"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar sitios patrocinados en inicio"
    },
    @{
        Browser       = "Firefox"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
        ValueName     = "Highlights"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar destacados en inicio"
    },

    # --- BRAVE BROWSER ---
    @{
        Browser       = "Brave"
        Category      = "Rendimiento GPU / Video"
        RegistryKey   = "HKLM\SOFTWARE\Policies\BraveSoftware\Brave"
        PSPath        = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
        ValueName     = "HardwareAccelerationModeEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Aceleracion por hardware GPU activada en Brave"
    },
    @{
        Browser       = "Brave"
        Category      = "Rendimiento GPU / Video"
        RegistryKey   = "HKLM\SOFTWARE\Policies\BraveSoftware\Brave"
        PSPath        = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
        ValueName     = "SmoothScrollingEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Desplazamiento suave activado en Brave"
    },
    @{
        Browser       = "Brave"
        Category      = "Ahorro de RAM y CPU"
        RegistryKey   = "HKLM\SOFTWARE\Policies\BraveSoftware\Brave"
        PSPath        = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
        ValueName     = "BackgroundModeEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Cerrar procesos de Brave al salir"
    },
    @{
        Browser       = "Brave"
        Category      = "Rendimiento y Red"
        RegistryKey   = "HKLM\SOFTWARE\Policies\BraveSoftware\Brave"
        PSPath        = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
        ValueName     = "DiskCacheSize"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 268435456
        Description   = "Limitar cache de disco a 256 MB en Brave"
    },
    @{
        Browser       = "Brave"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\BraveSoftware\Brave"
        PSPath        = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
        ValueName     = "MetricsReportingEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar metricas en Brave"
    },
    @{
        Browser       = "Brave"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\BraveSoftware\Brave"
        PSPath        = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
        ValueName     = "IPFSDisabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Desactivar protocolo P2P IPFS en Brave"
    },
    @{
        Browser       = "Brave"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\BraveSoftware\Brave"
        PSPath        = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
        ValueName     = "TorDisabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Desactivar ventanas Tor en Brave"
    },
    @{
        Browser       = "Brave"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\BraveSoftware\Brave"
        PSPath        = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
        ValueName     = "BraveRewardsDisabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Desactivar Brave Rewards (Cripto)"
    },
    @{
        Browser       = "Brave"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\BraveSoftware\Brave"
        PSPath        = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
        ValueName     = "BraveWalletDisabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Desactivar billetera Brave Wallet"
    },
    @{
        Browser       = "Brave"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\BraveSoftware\Brave"
        PSPath        = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
        ValueName     = "BraveVPNDisabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Description   = "Desactivar servicios comerciales Brave VPN"
    },
    @{
        Browser       = "Brave"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\BraveSoftware\Brave"
        PSPath        = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
        ValueName     = "BraveAIChatEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar Leo AI Chat en Brave"
    },
    @{
        Browser       = "Brave"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\BraveSoftware\Brave"
        PSPath        = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
        ValueName     = "NTPSponsoredImagesEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar fondos de pantalla patrocinados en nueva pestana"
    },
    @{
        Browser       = "Brave"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\BraveSoftware\Brave"
        PSPath        = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
        ValueName     = "PromotionalTabsEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar pestanas promocionales en Brave"
    },
    @{
        Browser       = "Brave"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\BraveSoftware\Brave"
        PSPath        = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
        ValueName     = "SearchSuggestEnabled"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Desactivar sugerencias de busqueda en Brave"
    }
)

# -----------------------------------------------------------------------------
# 1.2 MATRIZ DE DIRECTIVAS GPO DE RED, TCP Y ADAPTADORES (NETWORK POLICIES)
# -----------------------------------------------------------------------------

$global:RomanOS_NetworkPolicies = @(
    # --- TCP STACK ---
    @{
        Id            = "NET_TCP_AUTOTUNING"
        Category      = "TCP Stack"
        ActionType    = "Netsh_NetTCPSetting"
        Commands      = @(
            "netsh.exe int tcp set global autotuninglevel=normal",
            "Set-NetTCPSetting -SettingName InternetCustom -AutoTuningLevelLocal Normal"
        )
        Description   = "Ventana dinamica TCP establecida en Normal para alto rendimiento."
    },
    @{
        Id            = "NET_TCP_SCALING_HEURISTICS"
        Category      = "TCP Stack"
        ActionType    = "Netsh"
        Commands      = @("netsh.exe int tcp set global scalingheuristics=disabled")
        Description   = "Windows no degradara la ventana de AutoTuning."
    },
    @{
        Id            = "NET_TCP_CONGESTION_CUBIC"
        Category      = "TCP Stack"
        ActionType    = "NetTCPSetting"
        Commands      = @("Set-NetTCPSetting -SettingName InternetCustom -CongestionProvider CUBIC")
        Description   = "Algoritmo de congestion TCP CUBIC activado."
    },
    @{
        Id            = "NET_TCP_DISABLE_TIMESTAMPS"
        Category      = "TCP Stack"
        ActionType    = "Netsh"
        Commands      = @("netsh.exe int tcp set global timestamps=disabled")
        Description   = "Overhead de 12 bytes por paquete removido."
    },
    @{
        Id            = "NET_TCP_FASTOPEN"
        Category      = "TCP Stack"
        ActionType    = "Netsh"
        Commands      = @(
            "netsh.exe int tcp set global fastopen=enabled",
            "netsh.exe int tcp set global fastopenfallback=enabled"
        )
        Description   = "Handshake TCP optimizado (TFO habilitado)."
    },
    @{
        Id            = "NET_TCP_SYN_RETRIES"
        Category      = "TCP Stack"
        ActionType    = "Netsh"
        Commands      = @("netsh.exe int tcp set global maxsynretransmissions=2")
        Description   = "Max SYN Retransmissions ajustado a 2 (Timeouts acelerados)."
    },
    @{
        Id            = "NET_TCP_ECN_CAPABILITY"
        Category      = "TCP Stack"
        ActionType    = "Netsh_NetTCPSetting"
        Commands      = @(
            "netsh.exe int tcp set global ecncapability=enabled",
            "Set-NetTCPSetting -SettingName InternetCustom -EcnCapability Enabled",
            "Set-NetTCPSetting -SettingName Internet -EcnCapability Enabled"
        )
        Description   = "ECN Capability habilitado segun RFC 3168 para mitigar bufferbloat."
    },
    
    # --- SISTEMA Y RED (DINÁMICO Y REGISTRO) ---
    @{
        Id            = "NET_SYS_QOS_UNCAP"
        Category      = "Sistema / Registry"
        ActionType    = "Registry"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
        ValueName     = "NonBestEffortLimit"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Description   = "Reserva del 20% de ancho de banda QoS eliminada (NonBestEffortLimit = 0)."
    },
    @{
        Id            = "NET_SYS_NAGLE_ALGORITHM"
        Category      = "Sistema / Registry"
        ActionType    = "DynamicRegistry_Interfaces"
        Description   = "Algoritmo de Nagle deshabilitado en interfaces activas (TcpNoDelay=1, TcpAckFrequency=1)."
    },

    # --- HARDWARE NIC ---
    @{
        Id            = "NET_NIC_RSS"
        Category      = "Hardware NIC"
        ActionType    = "NetAdapter_Enable"
        Command       = "Enable-NetAdapterRss"
        Description   = "Habilitar RSS (Receive Side Scaling)."
    },
    @{
        Id            = "NET_NIC_GREEN_ETHERNET"
        Category      = "Hardware NIC"
        ActionType    = "NetAdapter_AdvancedProp"
        RegistryKeyword = "*EEE"
        RegistryValue   = "0"
        DisplayMatch    = "Energy Efficient Ethernet|Green|Ahorro de energia"
        DisplayValue    = "Disabled"
        Description   = "EEE / Green Ethernet deshabilitado para reducir micro-cortes."
    },
    @{
        Id            = "NET_NIC_DISABLE_RSC"
        Category      = "Hardware NIC"
        ActionType    = "NetAdapter_Disable"
        Command       = "Disable-NetAdapterRsc"
        Description   = "Desactivar RSC (Receive Segment Coalescing) para menor jitter."
    },
    @{
        Id            = "NET_NIC_DISABLE_INTMOD"
        Category      = "Hardware NIC"
        ActionType    = "NetAdapter_AdvancedProp"
        RegistryKeyword = "*InterruptModeration"
        RegistryValue   = "0"
        DisplayMatch    = "Moderation|Moderacion"
        DisplayValue    = "Disabled"
        Description   = "Moderacion de Interrupciones desactivada."
    },
    @{
        Id            = "NET_NIC_DISABLE_OFFLOADS"
        Category      = "Hardware NIC"
        ActionType    = "NetAdapter_Disable"
        Command       = "Disable-NetAdapterLso"
        Description   = "Desactivar Offloads de NIC (LSO) para prevenir fallos."
    },
    @{
        Id            = "NET_NIC_DISABLE_FLOWCTRL"
        Category      = "Hardware NIC"
        ActionType    = "NetAdapter_AdvancedProp"
        RegistryKeyword = "*FlowControl"
        RegistryValue   = "0"
        DisplayMatch    = "Flow Control|Control de flujo"
        DisplayValue    = "Disabled"
        Description   = "Control de flujo desactivado para evitar bufferbloat local."
    }    ,
    @{
        Id            = "NET_NIC_QOS_8021P"
        Category      = "Hardware NIC"
        ActionType    = "NetAdapter_AdvancedProp"
        RegistryKeyword = "*PriorityVLANTag"
        RegistryValue   = "3"
        DisplayMatch    = "Priority|Prioridad"
        DisplayValue    = "Priority & VLAN Enabled"
        Description   = "QoS 802.1p habilitado por hardware para priorizar paquetes DSCP del juego."
    },
    @{
        Id            = "NET_TCP_DISABLE_CHIMNEY"
        Category      = "TCP Stack"
        ActionType    = "Netsh"
        Commands      = @("netsh.exe int tcp set global chimney=disabled")
        Description   = "TCP Chimney Offload deshabilitado (Obsoleto, previene fugas en drivers OEM)."
    },
    @{
        Id            = "NET_TCP_DISABLE_TASKOFFLOAD"
        Category      = "TCP Stack"
        ActionType    = "Netsh"
        Commands      = @("netsh.exe int ip set global taskoffload=disabled")
        Description   = "IPsec Task Offload deshabilitado (Obsoleto, mejora estabilidad)."
    }
)

# -----------------------------------------------------------------------------
# 2. INVENTARIO MAESTRO DE BLOATWARE APPX DEBLOAT
# -----------------------------------------------------------------------------

$global:RomanOS_KnownBloatAppx = @(
    'MicrosoftWindows.Client.WebExperience'     # Backend de Widgets (MSN/WebView2)
    'Microsoft.BingNews'                       # Noticias Bing
    'Microsoft.BingWeather'                    # Clima Bing
    'Microsoft.GetHelp'                        # Obtener ayuda
    'Microsoft.Getstarted'                     # Introducción
    'Microsoft.MicrosoftSolitaireCollection'   # Colección Solitario
    'Microsoft.People'                         # Contactos
    'Microsoft.Todos'                          # Microsoft To-Do
    'Microsoft.WindowsFeedbackHub'             # Centro de opiniones
    'Microsoft.XboxApp'                        # App antigua Xbox
    'Microsoft.Clipchamp.Clipchamp'            # Editor de video Clipchamp
    'MicrosoftCorporationII.QuickAssist'       # Asistencia rápida
    'Microsoft.ZuneVideo'                      # Películas y TV
    'Microsoft.ZuneMusic'                      # Groove Música antiguo
)

# -----------------------------------------------------------------------------
# 3. FUNCIONES HELPER EXPORTADAS
# -----------------------------------------------------------------------------

function Get-RomanOSPolicies {
    <#
    .SYNOPSIS
        Retorna las políticas filtradas por perfil o categoría.
    #>
    param(
        [ValidateSet("1", "2", "3", "All")]
        [string]$Profile = "All",
        [string]$Category
    )

    $res = $global:RomanOS_Policies

    if ($Profile -ne "All") {
        $pInt = [int]$Profile
        $res = @($res | Where-Object { $_.Profiles -contains $pInt })
    }

    if ($Category) {
        $res = @($res | Where-Object { $_.Category -like "*$Category*" -or $_.Module -like "*$Category*" })
    }

    return ,$res
}

function Test-RomanOSPolicy {
    <#
    .SYNOPSIS
        Comprueba empíricamente si una directiva está aplicada en el sistema en vivo.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Policy
    )

    $result = [PSCustomObject]@{
        Id            = $Policy.Id
        Module        = $Policy.Module
        Description   = $Policy.Description
        ValueName     = $Policy.ValueName
        ExpectedValue = $Policy.ExpectedValue
        ActualValue   = $null
        IsApplied     = $false
        StatusText    = "No aplicada"
    }

    try {
        if (Test-Path $Policy.PSPath) {
            $val = (Get-ItemProperty -Path $Policy.PSPath -Name $Policy.ValueName -ErrorAction SilentlyContinue).($Policy.ValueName)
            $result.ActualValue = $val

            if ($null -ne $val) {
                if ([string]$val -eq [string]$Policy.ExpectedValue) {
                    $result.IsApplied  = $true
                    $result.StatusText = "OK ($val)"
                } else {
                    $result.StatusText = "Valor discrepante ($val != $($Policy.ExpectedValue))"
                }
            } else {
                $result.StatusText = "Valor no encontrado"
            }
        } else {
            $result.StatusText = "Clave inexistente"
        }
    } catch {
        $result.StatusText = "Error: $($_.Exception.Message)"
    }

    return $result
}

function Export-RomanOSUnattendCommands {
    <#
    .SYNOPSIS
        Genera el bloque XML de comandos síncronos (<RunSynchronousCommand>) para autounattend.xml.
    #>
    param(
        [ValidateSet("1", "2", "3")]
        [string]$Profile = "1",
        [int]$StartOrder = 2
    )

    $policies = Get-RomanOSPolicies -Profile $Profile
    $xmlLines = [System.Collections.Generic.List[string]]::new()
    $curOrder = $StartOrder

    foreach ($p in $policies) {
        # Omitir BypassNRO ya que suele ser el comando Order 1 en la fase specialize
        if ($p.Id -eq "POL_OOBE_BYPASS_NRO") { continue }

        $desc = if ($p.UnattendDesc) { $p.UnattendDesc } else { $p.Description }
        $cmdPath = "reg add `"$($p.RegistryKey)`" /v $($p.ValueName) /t $($p.Type) /d $($p.ExpectedValue) /f"

        $xmlLines.Add("        <RunSynchronousCommand wcm:action=`"add`">")
        $xmlLines.Add("          <Order>$curOrder</Order>")
        $xmlLines.Add("          <Description>$desc</Description>")
        $xmlLines.Add("          <Path>$cmdPath</Path>")
        $xmlLines.Add("        </RunSynchronousCommand>")

        $curOrder++
    }

    return [PSCustomObject]@{
        XmlContent = ($xmlLines -join "`r`n")
        NextOrder  = $curOrder
        Count      = $policies.Count
    }
}

function Get-RomanOSBrowserPolicies {
    <#
    .SYNOPSIS
        Devuelve las politicas de navegadores web catalogadas en Policy-Engine.
    #>
    param(
        [ValidateSet("All", "Edge", "Chrome", "Firefox", "Brave")]
        [string]$Browser = "All"
    )

    if ($Browser -eq "All") {
        return $global:RomanOS_BrowserPolicies
    }

    return @($global:RomanOS_BrowserPolicies | Where-Object { $_.Browser -eq $Browser })
}

function Export-RomanOSBrowserCommands {
    <#
    .SYNOPSIS
        Genera el bloque de comandos CMD para SetupComplete.cmd o scripts batch.
    #>
    param(
        [string]$LogVariable = "%LOG%"
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("REM ===========================================================")
    $lines.Add("REM Optimizacion y Debloat Oficial de Navegadores Web (GPO)")
    $lines.Add("REM Generado dinamicamente desde Core\Policy-Engine.ps1")
    $lines.Add("REM ===========================================================")
    $lines.Add("echo [%DATE% %TIME%] Aplicando politicas GPO de rendimiento en navegadores... >> `"$LogVariable`"")
    $lines.Add("")

    $currentBrowser = ""
    foreach ($p in $global:RomanOS_BrowserPolicies) {
        if ($p.Browser -ne $currentBrowser) {
            $currentBrowser = $p.Browser
            $lines.Add("REM -- Directivas para $currentBrowser --")
        }
        $valData = if ($p.Type -eq "REG_SZ" -and [string]::IsNullOrEmpty($p.ExpectedValue)) { '""' } else { $p.ExpectedValue }
        $lines.Add("reg add `"$($p.RegistryKey)`" /v `"$($p.ValueName)`" /t $($p.Type) /d $valData /f >> `"$LogVariable`" 2>&1")
    }

    $lines.Add("")
    $lines.Add("echo [%DATE% %TIME%] Politicas de navegadores aplicadas exitosamente. >> `"$LogVariable`"")

    return ($lines -join "`r`n")
}

function Apply-RomanOSBrowserPolicies {
    <#
    .SYNOPSIS
        Aplica todas las directivas GPO de navegadores en vivo mediante Set-ItemProperty o reg.exe.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [ValidateSet("All", "Edge", "Chrome", "Firefox", "Brave")]
        [string]$Browser = "All",
        [switch]$VerboseOutput
    )

    $policies = Get-RomanOSBrowserPolicies -Browser $Browser
    $appliedCount = 0
    $failCount = 0

    foreach ($p in $policies) {
        if ($PSCmdlet.ShouldProcess("$($p.RegistryKey)\$($p.ValueName)", "Aplicar directiva GPO de $($p.Browser)")) {
            try {
                $regKey = $p.RegistryKey
                $valName = $p.ValueName
                $type = $p.Type
                $val = if ($p.Type -eq "REG_SZ" -and [string]::IsNullOrEmpty($p.ExpectedValue)) { "" } else { $p.ExpectedValue }

                # Asegurar ruta intermedia en HKLM
                if (-not (Test-Path $p.PSPath)) {
                    New-Item -Path $p.PSPath -Force -ErrorAction SilentlyContinue | Out-Null
                }

                & reg.exe add "$regKey" /v "$valName" /t $type /d "$val" /f 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $appliedCount++
                    if ($VerboseOutput) { Write-Host "  [OK] $($p.Browser): $($p.ValueName) = $val" -ForegroundColor Green }
                } else {
                    $failCount++
                    if ($VerboseOutput) { Write-Host "  [FAIL] $($p.Browser): $($p.ValueName)" -ForegroundColor Red }
                }
            } catch {
                $failCount++
            }
        }
    }

    return [PSCustomObject]@{
        Total   = $policies.Count
        Applied = $appliedCount
        Failed  = $failCount
    }
}

# -----------------------------------------------------------------------------
# 5. FUNCIONES CANÓNICAS DE POLÍTICAS DE CONTROLADORES (DRIVERS & DISPOSITIVOS)
# -----------------------------------------------------------------------------

function Get-RomanOSDriverPolicies {
    <#
    .SYNOPSIS
        Retorna la lista de directivas oficiales de drivers registradas en Policy-Engine.
    #>
    [CmdletBinding()]
    param()

    return @($global:RomanOS_Policies | Where-Object { $_.Id -like "POL_DRV_*" })
}

function Export-RomanOSDriverCommands {
    <#
    .SYNOPSIS
        Genera bloques RunSynchronousCommand para autounattend.xml o comandos reg add para SetupComplete.cmd.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("Xml", "Cmd")]
        [string]$Format = "Xml",
        [int]$StartOrder = 1
    )

    $policies = Get-RomanOSDriverPolicies
    $order = $StartOrder
    $sb = [System.Text.StringBuilder]::new()

    foreach ($p in $policies) {
        $regKey = $p.RegistryKey
        $valName = $p.ValueName
        $type = $p.Type
        $val = $p.ExpectedValue

        if ($Format -eq "Xml") {
            [void]$sb.AppendLine(@"
        <RunSynchronousCommand wcm:action="add">
          <Order>$order</Order>
          <Description>$($p.UnattendDesc)</Description>
          <Path>reg add "$regKey" /v "$valName" /t $type /d $val /f</Path>
        </RunSynchronousCommand>
"@)
        } else {
            [void]$sb.AppendLine("reg.exe add `"$regKey`" /v `"$valName`" /t $type /d $val /f >nul 2>&1")
        }
        $order++
    }

    return [PSCustomObject]@{
        Content   = $sb.ToString()
        Count     = $policies.Count
        NextOrder = $order
    }
}

function Apply-RomanOSDriverPolicies {
    <#
    .SYNOPSIS
        Aplica todas las directivas de aislamiento y control de drivers en vivo o en colmena montada.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [switch]$VerboseOutput
    )

    $policies = Get-RomanOSDriverPolicies
    $appliedCount = 0
    $failCount = 0

    foreach ($p in $policies) {
        if ($PSCmdlet.ShouldProcess("$($p.RegistryKey)\$($p.ValueName)", "Aplicar directiva de controlador: $($p.Description)")) {
            try {
                $regKey = $p.RegistryKey
                $valName = $p.ValueName
                $type = $p.Type
                $val = $p.ExpectedValue

                if (-not (Test-Path $p.PSPath)) {
                    New-Item -Path $p.PSPath -Force -ErrorAction SilentlyContinue | Out-Null
                }

                & reg.exe add "$regKey" /v "$valName" /t $type /d $val /f 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $appliedCount++
                    if ($VerboseOutput) { Write-Host "  [OK] Driver Policy: $($p.ValueName) = $val" -ForegroundColor Green }
                } else {
                    $failCount++
                    if ($VerboseOutput) { Write-Host "  [FAIL] Driver Policy: $($p.ValueName)" -ForegroundColor Red }
                }
            } catch {
                $failCount++
            }
        }
    }

    return [PSCustomObject]@{
        Total   = $policies.Count
        Applied = $appliedCount
        Failed  = $failCount
    }
}


