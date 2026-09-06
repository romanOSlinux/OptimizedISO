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
        ExpectedValue = 10
        Profiles      = @(1, 2, 3)
        Description   = "Optimizar receptividad del sistema en MMCSS (10% reservado para background)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service"
        UnattendDesc  = "Optimize System Responsiveness in MMCSS"
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
