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
        Profiles      = @()
        IsDeprecated  = $true
        Description   = "[OBSOLETA - Win11] Desactivar Noticias e Intereses en barra de tareas (Sustituido en Windows 11 por POL_WIDGETS_ALLOW)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-widgets"
        UnattendDesc  = "Disable News and Interests on Taskbar (Deprecated in Win11 - Use AllowWidgets)"
    },
    @{
        Id            = "POL_CHAT_ICON"
        Module        = "Modulo F - Widgets"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Chat"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat"
        ValueName     = "ChatIcon"
        Type          = "REG_DWORD"
        ExpectedValue = 3
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar icono y precarga de Chat / Teams consumidor en barra de tareas"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience"
        UnattendDesc  = "Disable Chat / Teams Taskbar Icon and Background Preload"
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
    @{
        Id            = "POL_SEARCH_DYNAMIC_CONTENT_WSB"
        Module        = "Modulo F - Bing Web Search"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        ValueName     = "EnableDynamicContentInWSB"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar Search Highlights (contenido dinamico en cuadro de busqueda de Windows)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-search"
        UnattendDesc  = "Disable Search Highlights Dynamic Content in Search Box (EnableDynamicContentInWSB=0)"
    },
    @{
        Id            = "POL_SEARCH_CONNECTED_METERED"
        Module        = "Modulo F - Bing Web Search"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        ValueName     = "ConnectedSearchUseWebOverMeteredConnections"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar busqueda web conectada sobre conexiones medidas"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-search"
        UnattendDesc  = "Disable Connected Search Web Over Metered Connections"
    },
    @{
        Id            = "POL_SEARCH_CORTANA_ALLOW"
        Module        = "Modulo F - Bing Web Search"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        ValueName     = "AllowCortana"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @()
        IsDeprecated  = $true
        Description   = "[OBSOLETA - Win11] Desactivar asistente Cortana (Descontinuado y eliminado en Windows 11 por Microsoft)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-search"
        UnattendDesc  = "Disable Cortana Assistant (Deprecated in Win11 - Discontinued by Microsoft)"
    },
    @{
        Id            = "POL_SEARCH_ALLOW_CLOUD"
        Module        = "Modulo F - Bing Web Search"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        ValueName     = "AllowCloudSearch"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar busqueda en la nube (OneDrive, SharePoint) en Windows Search"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-search"
        UnattendDesc  = "Disable Cloud Search in Windows Search"
    },
    @{
        Id            = "POL_SEARCH_ALLOW_LOCATION"
        Module        = "Modulo F - Bing Web Search"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        ValueName     = "AllowSearchToUseLocation"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar uso de geolocalizacion en busqueda de Windows"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-search"
        UnattendDesc  = "Disable Search from Using Device Location"
    },

    # --- MÓDULO ONEDRIVE: BLOQUEO INTEGRAL (PLAN-0078) ---
    @{
        Id            = "POL_ONEDRIVE_BLOCK"
        Module        = "Modulo OneDrive - Bloqueo de Sincronizacion"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        ValueName     = "DisableFileSyncNGSC"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Bloquear sincronizacion del cliente OneDrive (NextGen Sync Client)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/sharepoint/use-group-policy#prevent-users-from-syncing-personal-onedrive-accounts"
        UnattendDesc  = "Prevent OneDrive File Sync System-Wide"
    },
    @{
        Id            = "POL_ONEDRIVE_DISABLE_FILE_SYNC"
        Module        = "Modulo OneDrive - Bloqueo de Sincronizacion"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        ValueName     = "DisableFileSync"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar completamente la sincronizacion de archivos de OneDrive"
        OfficialDoc   = "https://learn.microsoft.com/en-us/sharepoint/use-group-policy#prevent-users-from-syncing-personal-onedrive-accounts"
        UnattendDesc  = "Disable OneDrive File Sync"
    },
    @{
        Id            = "POL_ONEDRIVE_METERED_SYNC"
        Module        = "Modulo OneDrive - Redes Medidas"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        ValueName     = "DisableMeteredNetworkFileSync"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Bloquear sincronizacion de OneDrive en redes de uso medido"
        OfficialDoc   = "https://learn.microsoft.com/en-us/sharepoint/use-group-policy"
        UnattendDesc  = "Disable OneDrive Metered Network Sync"
    },
    @{
        Id            = "POL_ONEDRIVE_LIBRARIES_PIN"
        Module        = "Modulo OneDrive - Bibliotecas"
        Category      = "Privacidad & Shell"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        ValueName     = "DisableLibrariesStylePin"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Desvincular OneDrive del anclaje de carpetas y bibliotecas del sistema"
        OfficialDoc   = "https://learn.microsoft.com/en-us/sharepoint/use-group-policy"
        UnattendDesc  = "Disable OneDrive Libraries Style Pin"
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
        Id            = "POL_FIRST_LOGON_ANIMATION"
        Module        = "Base - OOBE Performance"
        Category      = "Rendimiento & OOBE"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        ValueName     = "EnableFirstLogonAnimation"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar animacion de primer inicio de sesion (Hola... Preparando todo para ti)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience"
        UnattendDesc  = "Disable First Logon Animation (OOBE Speedup)"
    },
    @{
        Id            = "POL_FIRST_LOGON_ANIM_WINLOGON"
        Module        = "Base - OOBE Performance"
        Category      = "Rendimiento & OOBE"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        ValueName     = "EnableFirstLogonAnimation"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar animacion de primer inicio de sesion en Winlogon"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience"
        UnattendDesc  = "Disable First Logon Animation in Winlogon (OOBE Speedup)"
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
        Id            = "POL_AUTH_LIMIT_BLANK_PASSWORD"
        Module        = "Base - OOBE & AutoLogon"
        Category      = "Autenticacion & Shell"
        RegistryKey   = "HKLM\SYSTEM\CurrentControlSet\Control\Lsa"
        PSPath        = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        ValueName     = "LimitBlankPasswordUse"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Restringir uso de cuentas con contrasena en blanco exclusivamente a inicio de sesion en consola local (Seguridad de Red)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/troubleshoot/windows-server/identity/blank-password-restriction-policy"
        UnattendDesc  = "Restrict Blank Password Usage to Console Logon Only (LimitBlankPasswordUse=1)"
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
        Id            = "POL_WU_NO_AUTO_UPDATE"
        Module        = "Base - Windows Update"
        Category      = "Windows Update & Rendimiento"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        ValueName     = "NoAutoUpdate"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(2, 3)
        Description   = "Desactivar busqueda y descarga automatica de Windows Update en segundo plano (Modo Bajo Demanda)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/deployment/update/waas-wu-policies#configure-automatic-updates"
        UnattendDesc  = "Disable Automatic Background Updates (Manual On-Demand Scan and Download Only)"
    },
    @{
        Id            = "POL_WU_AU_OPTIONS"
        Module        = "Base - Windows Update"
        Category      = "Windows Update & Rendimiento"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        ValueName     = "AUOptions"
        Type          = "REG_DWORD"
        ExpectedValue = 2
        Profiles      = @(2, 3)
        Description   = "Configurar actualizaciones para notificar antes de descargar y antes de instalar"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update"
        UnattendDesc  = "Configure AUOptions to 2 (Notify Before Download and Install)"
    },
    @{
        Id            = "POL_WU_NO_AUTO_REBOOT"
        Module        = "Base - Windows Update"
        Category      = "Windows Update & Rendimiento"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        ValueName     = "NoAutoRebootWithLoggedOnUsers"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(2, 3)
        Description   = "Evitar reinicios automaticos mientras haya usuarios con sesion iniciada"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/deployment/update/waas-wu-policies#no-auto-reboot-with-logged-on-users-for-scheduled-automatic-updates-installations"
        UnattendDesc  = "Prevent Automatic Reboots While Users Are Logged On"
    },
    @{
        Id            = "POL_WU_ALWAYS_AUTO_REBOOT"
        Module        = "Base - Windows Update"
        Category      = "Windows Update & Rendimiento"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        ValueName     = "AlwaysAutoRebootAtScheduledTime"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Deshabilitar reinicios automaticos forzados en horario programado (PLAN-0115)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/deployment/update/waas-wu-policies"
        UnattendDesc  = "Disable Always Auto Reboot At Scheduled Time (AlwaysAutoRebootAtScheduledTime=0)"
    },
    @{
        Id            = "POL_WU_POWER_MANAGEMENT"
        Module        = "Base - Windows Update"
        Category      = "Windows Update & Rendimiento"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        ValueName     = "AUPowerManagement"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Impedir que Windows Update despierte el equipo o reactive energia para reiniciar de noche (PLAN-0115)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/deployment/update/waas-wu-policies"
        UnattendDesc  = "Disable Windows Update Power Management Wake Timers (AUPowerManagement=0)"
    },
    @{
        Id            = "POL_WU_RESTART_NOTIF_CONFIG"
        Module        = "Base - Windows Update"
        Category      = "Windows Update & Rendimiento"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        ValueName     = "SetAutoRestartNotificationConfig"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Forzar notificaciones modales persistentes antes de cualquier reinicio requerido (PLAN-0115)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update"
        UnattendDesc  = "Turn On Auto-Restart Notifications (SetAutoRestartNotificationConfig=1)"
    },
    @{
        Id            = "POL_WU_RESTART_DISMISSAL"
        Module        = "Base - Windows Update"
        Category      = "Windows Update & Rendimiento"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        ValueName     = "SetAutoRestartRequiredNotificationDismissal"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Exigir descarte manual del usuario en notificaciones de reinicio requerido (PLAN-0115)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update"
        UnattendDesc  = "Require User Action to Dismiss Restart Notification (SetAutoRestartRequiredNotificationDismissal=1)"
    },
    @{
        Id            = "POL_WU_ENGAGED_TRANSITION"
        Module        = "Base - Windows Update"
        Category      = "Windows Update & Rendimiento"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        ValueName     = "SetEngagedRestartTransitionSchedule"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar transicion automatica a reinicio forzado desatendido (PLAN-0115)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update"
        UnattendDesc  = "Disable Engaged Restart Transition Schedule (SetEngagedRestartTransitionSchedule=0)"
    },
    @{
        Id            = "POL_WU_ALLOW_OPTIONAL_CONTENT"
        Module        = "Base - Windows Update"
        Category      = "Windows Update & Rendimiento"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        ValueName     = "AllowOptionalContent"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar entrega de actualizaciones acumulativas opcionales de vista previa (Previews C/D) y CFR beta"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update#allowoptionalcontent"
        UnattendDesc  = "Disable Optional Preview Updates and CFR Beta Content (AllowOptionalContent=0)"
    },
    @{
        Id            = "POL_WU_CONTINUOUS_INNOVATION"
        Module        = "Base - Windows Update"
        Category      = "Windows Update & Rendimiento"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
        ValueName     = "IsContinuousInnovationOptedIn"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar adopcion acelerada de novedades sin probar (Get latest updates as soon as available = Off)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/deployment/update/waas-wu-policies"
        UnattendDesc  = "Disable Continuous Innovation Opt-In (Off)"
    },
    @{
        Id            = "POL_WU_DEFER_QUALITY"
        Module        = "Base - Windows Update"
        Category      = "Windows Update & Rendimiento"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        ValueName     = "DeferQualityUpdates"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Habilitar periodo de diferimiento y cuarentena para actualizaciones de calidad acumulativas"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update#deferqualityupdatesperiodindays"
        UnattendDesc  = "Enable Quality Updates Deferral and Quarantine Period"
    },
    @{
        Id            = "POL_WU_DEFER_QUALITY_DAYS"
        Module        = "Base - Windows Update"
        Category      = "Windows Update & Rendimiento"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        ValueName     = "DeferQualityUpdatesPeriodInDays"
        Type          = "REG_DWORD"
        ExpectedValue = 7
        Profiles      = @(1, 2, 3)
        Description   = "Periodo de cuarentena de 7 dias para actualizaciones acumulativas (ventana de maduracion y aplicacion de KIR)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update#deferqualityupdatesperiodindays"
        UnattendDesc  = "Defer Quality Updates by 7 Days (KIR Maturation Window)"
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
        ExpectedValue = 38 # 0x26: Cuantos fijos, cortos y boost 3:1 a primer plano en CPUs simetricas (en hibridas/X3D Hardware-Engine preserva default 2)
        Profiles      = @(1, 2, 3)
        TopologyAware = $true
        Description   = "Optimizar separacion de prioridades del planificador en CPUs simetricas (38). En topologias asimetricas (Intel Hybrid / AMD Dual-CCD X3D), Hardware-Engine preserva 2 para proteger Thread Director y AMD CPPC"
        OfficialDoc   = "https://learn.microsoft.com/sysinternals/resources/windows-internals"
        UnattendDesc  = "Optimize Win32PrioritySeparation for Symmetric CPUs (Preserve Default on Hybrid/X3D)"
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
    @{
        Id            = "POL_FS_DISABLE_LASTACCESS"
        Module        = "Almacenamiento - NTFS"
        Category      = "Rendimiento & Almacenamiento"
        RegistryKey   = "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem"
        PSPath        = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
        ValueName     = "NtfsDisableLastAccessUpdate"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Deshabilitar actualizacion de marcas de tiempo de acceso NTFS para reducir escrituras innecesarias en NVMe/SSDs"
        OfficialDoc   = "https://learn.microsoft.com/windows-server/administration/windows-commands/fsutil-behavior"
        UnattendDesc  = "Disable NTFS Last Access Time Updates"
    },
    # --- MÓDULO F1.1: GESTIÓN DE MEMORIA Y SUBSISTEMA DE KERNEL ---
    @{
        Id            = "POL_MEM_DISABLE_PAGING_EXECUTIVE"
        Module        = "Memoria - Kernel Management"
        Category      = "Rendimiento & Latencia"
        RegistryKey   = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        PSPath        = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        ValueName     = "DisablePagingExecutive"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Forzar que el codigo del kernel y controladores residan en RAM fisica sin paginar a disco, eliminando micro-congelamientos"
        OfficialDoc   = "https://learn.microsoft.com/windows-hardware/drivers/kernel/memory-management-registry-keys"
        UnattendDesc  = "Disable Paging Executive (Lock Kernel Drivers in Physical RAM)"
    },
    @{
        Id            = "POL_MEM_LARGE_SYSTEM_CACHE"
        Module        = "Memoria - Kernel Management"
        Category      = "Rendimiento & Latencia"
        RegistryKey   = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        PSPath        = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        ValueName     = "LargeSystemCache"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Priorizar memoria de trabajo para programas y gaming (LargeSystemCache=0 seguro para APU/UMA y dGPU, previene asfixia de VRAM y memory leaks)"
        OfficialDoc   = "https://learn.microsoft.com/windows-hardware/drivers/kernel/memory-management-registry-keys"
        UnattendDesc  = "Set LargeSystemCache to 0 (Prioritize Process Working Set and Protect UMA VRAM)"
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
        IsDeprecated  = $true
        Description   = "[OBSOLETA - Win11] ActivityFeed (Timeline fue descontinuado y eliminado en Windows 10 21H2)"
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
    },
    # --- MÓDULO G: CIBERSEGURIDAD ZERO-IMPACT & KERNEL HARDENING ---
    @{
        Id            = "POL_SEC_LSA_RUNASPPL"
        Module        = "Modulo G - Hardening Seguro"
        Category      = "Seguridad y Kernel"
        RegistryKey   = "HKLM\SYSTEM\CurrentControlSet\Control\Lsa"
        PSPath        = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        ValueName     = "RunAsPPL"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Proteccion LSA RunAsPPL contra volcado de credenciales en memoria (lsass.exe)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows-server/security/credentials-protection-and-management/configuring-additional-lsa-protection"
        UnattendDesc  = "Enable LSA Protection RunAsPPL"
    },
    @{
        Id            = "POL_SEC_LSA_RUNASPPL_BOOT"
        Module        = "Modulo G - Hardening Seguro"
        Category      = "Seguridad y Kernel"
        RegistryKey   = "HKLM\SYSTEM\CurrentControlSet\Control\Lsa"
        PSPath        = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        ValueName     = "RunAsPPLBoot"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 2
        Profiles      = @(1, 2, 3)
        Description   = "Configurar RunAsPPLBoot con variable UEFI persistente"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows-server/security/credentials-protection-and-management/configuring-additional-lsa-protection"
        UnattendDesc  = "Enable RunAsPPLBoot with UEFI Variable"
    },
    @{
        Id            = "POL_SEC_DRIVER_BLOCKLIST"
        Module        = "Modulo G - Hardening Seguro"
        Category      = "Seguridad y Kernel"
        RegistryKey   = "HKLM\SYSTEM\CurrentControlSet\Control\CI\Config"
        PSPath        = "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Config"
        ValueName     = "VulnerableDriverBlocklistEnable"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 1
        Profiles      = @(1, 2, 3)
        Description   = "Lista negra recomendada de Microsoft para bloquear drivers vulnerables (BYOVD)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows/security/application-security/application-control/windows-defender-application-control/design/microsoft-recommended-driver-block-rules"
        UnattendDesc  = "Enable Microsoft Recommended Vulnerable Driver Blocklist"
    },
    @{
        Id            = "POL_SEC_DISABLE_SMB1"
        Module        = "Modulo G - Hardening Seguro"
        Category      = "Seguridad y Kernel"
        RegistryKey   = "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
        PSPath        = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
        ValueName     = "SMB1"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar protocolo legado vulnerable SMBv1 (Mitigacion EternalBlue / WannaCry)"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows-server/storage/file-server/troubleshoot/detect-enable-and-disable-smbv1-v2-v3"
        UnattendDesc  = "Disable Insecure Legacy SMBv1 Protocol"
    },
    @{
        Id            = "POL_SEC_DISABLE_LLMNR"
        Module        = "Modulo G - Hardening Seguro"
        Category      = "Seguridad y Red"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
        ValueName     = "EnableMulticast"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 0
        Profiles      = @(1, 2, 3)
        Description   = "Desactivar LLMNR Multicast para prevenir envenenamiento de credenciales NTLM en LAN"
        OfficialDoc   = "https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/reducing-the-active-directory-attack-surface"
        UnattendDesc  = "Disable LLMNR Multicast Protocol"
    },
    # --- MÓDULO H: GAMING WDDM 3.x Y FLIP MODEL ---
    @{
        Id            = "POL_GAME_WINDOWED_OPTIMIZATION"
        Module        = "Modulo H - Gaming WDDM 3.x"
        Category      = "Rendimiento y Gaming"
        RegistryKey   = "HKCU\Software\Microsoft\DirectX\UserGpuPreferences"
        PSPath        = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
        ValueName     = "DirectXUserGlobalSettings"
        Type          = "REG_SZ"
        PSType        = "String"
        ExpectedValue = "SwapEffectUpgradeEnable=1;AutoHDREnable=1;VRROptimizeEnable=1;"
        Profiles      = @(1, 2, 3)
        Description   = "Forzar Flip Model y optimizaciones de juegos en ventana (AutoHDR, VRR, SwapEffect)"
        OfficialDoc   = "https://devblogs.microsoft.com/directx/demystifying-full-screen-optimizations/"
        UnattendDesc  = "Enable Windowed Game Optimizations and Flip Model"
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
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "WebRtcIPHandlingPolicy"
        Type          = "REG_SZ"
        PSType        = "String"
        ExpectedValue = "disable_non_proxied_udp"
        Description   = "Prevenir fuga de direccion IP local mediante WebRTC"
    },
    @{
        Browser       = "Edge"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        ValueName     = "IdleDetectionAllowed"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 2
        Description   = "Bloquear deteccion de inactividad del usuario por sitios web"
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
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "WebRtcIPHandlingPolicy"
        Type          = "REG_SZ"
        PSType        = "String"
        ExpectedValue = "disable_non_proxied_udp"
        Description   = "Prevenir fuga de direccion IP local mediante WebRTC"
    },
    @{
        Browser       = "Chrome"
        Category      = "Debloat y Privacidad"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Google\Chrome"
        PSPath        = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        ValueName     = "IdleDetectionAllowed"
        Type          = "REG_DWORD"
        PSType        = "DWord"
        ExpectedValue = 2
        Description   = "Bloquear deteccion de inactividad del usuario por sitios web"
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
        Description   = "Algoritmo de Nagle deshabilitado en interfaces activas (TcpNoDelay=1, preservando ACK diferido estandar RFC 1122)."
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
        DisplayMatch    = "Energy Efficient Ethernet|Green|ecol[oó]gico|Ahorro de energ[ií]a"
        DisplayValue    = "Disabled"
        Description   = "EEE / Green Ethernet deshabilitado para reducir micro-cortes y latencia."
    },
    @{
        Id            = "NET_NIC_POWER_SAVING"
        Category      = "Hardware NIC"
        ActionType    = "NetAdapter_AdvancedProp"
        RegistryKeyword = "*PowerSavingMode"
        RegistryValue   = "0"
        DisplayMatch    = "Power Saving Mode|Modo de ahorro de energ[ií]a"
        DisplayValue    = "Disabled"
        Description   = "Power Saving Mode de NIC deshabilitado para eliminar latencias PHY."
    },
    @{
        Id            = "NET_NIC_DISABLE_RSC"
        Category      = "Hardware NIC"
        ActionType    = "NetAdapter_Disable"
        Command       = "Disable-NetAdapterRsc"
        Description   = "Desactivar RSC (Receive Segment Coalescing) para menor jitter."
    },
    @{
        Id            = "NET_NIC_ENABLE_UDPRSC"
        Category      = "Hardware NIC"
        ActionType    = "NetAdapter_AdvancedProp"
        RegistryKeyword = "*UdpRsc"
        RegistryValue   = "1"
        DisplayMatch    = "UDP RSC|UDP Receive Segment Coalescing|URO"
        DisplayValue    = "Enabled"
        Description   = "UDP RSC / URO (Receive Segment Coalescing Offload) habilitado por hardware para reducir la sobrecarga de CPU en juegos competitivos y streaming (NDIS 6.85+)."
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
        [int]$StartOrder = 2,
        [switch]$SkipOneDrive
    )

    $policies = Get-RomanOSPolicies -Profile $Profile
    $xmlLines = [System.Collections.Generic.List[string]]::new()
    $curOrder = $StartOrder

    foreach ($p in $policies) {
        # Omitir BypassNRO ya que suele ser el comando Order 1 en la fase specialize
        if ($p.Id -eq "POL_OOBE_BYPASS_NRO") { continue }

        # Omitir politicas de bloqueo de OneDrive si se especifico conservarlo (-SkipOneDrive)
        if ($SkipOneDrive -and $p.Id -like "POL_ONEDRIVE_*") { continue }

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
                $val = if ($p.Type -eq "REG_SZ" -and [string]::IsNullOrEmpty($p.ExpectedValue)) { "" } else { $p.ExpectedValue }
                $psType = if ($p.PSType) { $p.PSType } elseif ($p.Type -eq "REG_DWORD") { "DWord" } else { "String" }

                # Asegurar ruta intermedia en HKLM
                if (-not (Test-Path $p.PSPath)) {
                    New-Item -Path $p.PSPath -Force -ErrorAction SilentlyContinue | Out-Null
                }

                $applied = $false
                try {
                    Set-ItemProperty -Path $p.PSPath -Name $p.ValueName -Value $val -Type $psType -Force -ErrorAction Stop
                    $applied = $true
                } catch {
                    # Fallback a reg.exe add nativo
                    $regKey = $p.RegistryKey
                    $valName = $p.ValueName
                    $type = $p.Type
                    & reg.exe add "$regKey" /v "$valName" /t $type /d "$val" /f 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        $applied = $true
                    }
                }

                if ($applied) {
                    $appliedCount++
                    if ($VerboseOutput) { Write-Host "  [OK] $($p.Browser): $($p.ValueName) = $val" -ForegroundColor Green }
                } else {
                    $failCount++
                    if ($VerboseOutput) { Write-Host "  [FAIL] $($p.Browser): $($p.ValueName)" -ForegroundColor Red }
                }
            } catch {
                $failCount++
                if ($VerboseOutput) { Write-Host "  [FAIL] $($p.Browser): $($p.ValueName)" -ForegroundColor Red }
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

function Get-RomanOSStoragePolicies {
    <#
    .SYNOPSIS
        Retorna las directivas de almacenamiento del sistema (NTFS, TRIM, BypassIO).
    #>
    [CmdletBinding()]
    param()

    return @($global:RomanOS_Policies | Where-Object { 
        $_.Module -like "*Almacenamiento*" -or $_.Category -like "*Almacenamiento*" 
    })
}

function Get-RomanOSNetworkPolicies {
    <#
    .SYNOPSIS
        Retorna las directivas oficiales de red, TCP y hardware NIC.
    #>
    [CmdletBinding()]
    param()

    return @($global:RomanOS_NetworkPolicies)
}

function Get-RomanOSMemoryPolicies {
    <#
    .SYNOPSIS
        Retorna las directivas de memoria física, paginado de kernel y MMAgent.
    #>
    [CmdletBinding()]
    param()

    return @($global:RomanOS_Policies | Where-Object { 
        $_.Module -like "*Memoria*" -or $_.Id -like "POL_MEM_*" 
    })
}

function Get-RomanOSProcessorPolicies {
    <#
    .SYNOPSIS
        Retorna las directivas de programación de procesador y separación Win32.
    #>
    [CmdletBinding()]
    param()

    return @($global:RomanOS_Policies | Where-Object { 
        $_.Id -like "*SCHED*" -or $_.Id -like "*CPU*" -or $_.Id -like "*PRIORITY*" 
    })
}

function Apply-RomanOSTieredMemoryPolicy {
    <#
    .SYNOPSIS
        Aplica la directiva de memoria escalonada adaptativa según el nivel de RAM física.
    .PARAMETER RamGigabytes
        Cantidad de memoria RAM en GB. Si se omite, se detecta automáticamente.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [double]$RamGigabytes = 0,
        [switch]$VerboseOutput
    )

    if ($RamGigabytes -le 0) {
        try {
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
            $totalBytes = $cs.TotalPhysicalMemory
            $RamGigabytes = [math]::Round($totalBytes / 1GB, 1)
        } catch {
            Write-Warning "No se pudo consultar Win32_ComputerSystem: $($_.Exception.Message). Asumiendo 16 GB."
            $RamGigabytes = 16.0
        }
    }

    $tier = if ($RamGigabytes -lt 8.0) { "Low" } elseif ($RamGigabytes -le 16.0) { "Balanced" } else { "Enthusiast" }
    
    if ($VerboseOutput) {
        Write-Host "  [INFO] romanOS Memory Tiering: $tier ($RamGigabytes GB RAM)" -ForegroundColor Cyan
    }

    $applied = 0
    $failed = 0

    if ($PSCmdlet.ShouldProcess("Sistema (RAM: $RamGigabytes GB, Tier: $tier)", "Aplicar directiva escalonada de memoria")) {
        try {
            # 1. Paging Executive: Bloquear kernel en RAM para Balanced y Enthusiast
            $disablePaging = if ($tier -eq "Low") { 0 } else { 1 }
            & reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "DisablePagingExecutive" /t REG_DWORD /d $disablePaging /f 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { $applied++ } else { $failed++ }

            # 2. LargeSystemCache: Mantener en 0 estricto para Workstation/Gaming y APU/UMA
            $largeCache = 0
            & reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "LargeSystemCache" /t REG_DWORD /d 0 /f 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { $applied++ } else { $failed++ }

            # 3. MMAgent: Memory Compression & Page Combining
            if (Get-Command -Name "Get-MMAgent" -ErrorAction SilentlyContinue) {
                try {
                    if ($tier -eq "Low") {
                        Enable-MMAgent -MemoryCompression -PageCombining -ErrorAction Stop | Out-Null
                    } elseif ($tier -eq "Balanced") {
                        Enable-MMAgent -MemoryCompression -ErrorAction Stop | Out-Null
                    } else {
                        Disable-MMAgent -MemoryCompression -PageCombining -ErrorAction Stop | Out-Null
                    }
                    $applied++
                } catch {
                    Write-Warning "Fallo al configurar MMAgent: $($_.Exception.Message)"
                    $failed++
                }
            }
        } catch {
            Write-Warning "Fallo al aplicar política escalonada de memoria: $($_.Exception.Message)"
            $failed++
        }
    }

    return [PSCustomObject]@{
        Tier         = $tier
        RamGigabytes = $RamGigabytes
        Applied      = $applied
        Failed       = $failed
    }
}

# -----------------------------------------------------------------------------
# 10. MATRIZ DE INVARIANTES INMUTABLES DEL SISTEMA (SSOT)
# -----------------------------------------------------------------------------

$global:RomanOS_SystemInvariants = @(
    @{
        Id            = "INV_DRIVERS_NO_WU_OVERWRITE"
        Category      = "Controladores"
        Name          = "ExcludeWUDriversInQualityUpdate"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        ValueName     = "ExcludeWUDriversInQualityUpdate"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Description   = "Protección inmutable de drivers calibrados: prohíbe a Windows Update sobreescribir controladores con genéricos"
    },
    @{
        Id            = "INV_WU_NO_PREVIEWS"
        Category      = "Windows Update"
        Name          = "AllowOptionalContent"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        ValueName     = "AllowOptionalContent"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Description   = "Bloqueo inmutable de parches preview, betas y continuous feature releases (CFR)"
    },
    @{
        Id            = "INV_WU_NO_CONTINUOUS_INNOVATION"
        Category      = "Windows Update"
        Name          = "IsContinuousInnovationOptedIn"
        RegistryKey   = "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
        PSPath        = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
        ValueName     = "IsContinuousInnovationOptedIn"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Description   = "Desactivación inmutable de novedades tempranas inestables de Windows"
    },
    @{
        Id            = "INV_WU_QUALITY_DEFERRAL_7D"
        Category      = "Windows Update"
        Name          = "DeferQualityUpdatesPeriodInDays"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        ValueName     = "DeferQualityUpdatesPeriodInDays"
        Type          = "REG_DWORD"
        ExpectedValue = 7
        Description   = "Cuarentena inmutable de 7 días de maduración para parches acumulativos (KIR)"
    },
    @{
        Id            = "INV_ANTI_BLOAT_CONTENT_DELIVERY"
        Category      = "Anti-Bloatware"
        Name          = "ContentDeliveryManager"
        RegistryKey   = "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        PSPath        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        ValueName     = "SilentInstalledAppsEnabled"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Description   = "Prohibición inmutable de instalación automática y silenciosa de aplicaciones patrocinadas"
    },
    @{
        Id            = "INV_SECURITY_DRIVER_BLOCKLIST"
        Category      = "Seguridad Kernel"
        Name          = "VulnerableDriverBlocklistEnable"
        RegistryKey   = "HKLM\SYSTEM\CurrentControlSet\Control\CI\Config"
        PSPath        = "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Config"
        ValueName     = "VulnerableDriverBlocklistEnable"
        Type          = "REG_DWORD"
        ExpectedValue = 1
        Description   = "Bloqueo inmutable de drivers vulnerables para compatibilidad obligatoria con Anti-Cheats (Vanguard/EAC/BattlEye)"
    },
    @{
        Id            = "INV_STORE_AUTH_ROOT"
        Category      = "Microsoft Store"
        Name          = "DisableRootAutoUpdate"
        RegistryKey   = "HKLM\SOFTWARE\Policies\Microsoft\SystemCertificates\AuthRoot"
        PSPath        = "HKLM:\SOFTWARE\Policies\Microsoft\SystemCertificates\AuthRoot"
        ValueName     = "DisableRootAutoUpdate"
        Type          = "REG_DWORD"
        ExpectedValue = 0
        Description   = "Preservación inmutable de certificados raíz para funcionamiento continuo de la Microsoft Store"
    }
)

function Get-RomanOSSystemInvariants {
    <#
    .SYNOPSIS
        Retorna la matriz de invariantes inmutables del sistema.
    #>
    [CmdletBinding()]
    param()
    return $global:RomanOS_SystemInvariants
}

function Assert-RomanOSInvariants {
    <#
    .SYNOPSIS
        Audita los invariantes del sistema y opcionalmente los autorepara si detecta desviaciones.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [switch]$AutoRemediate,
        [switch]$Quiet
    )

    $violations = [System.Collections.Generic.List[PSObject]]::new()
    $invariants = Get-RomanOSSystemInvariants

    foreach ($inv in $invariants) {
        $actualValue = $null
        $keyExists = Test-Path -Path $inv.PSPath -ErrorAction SilentlyContinue

        if ($keyExists) {
            try {
                $prop = Get-ItemProperty -Path $inv.PSPath -Name $inv.ValueName -ErrorAction SilentlyContinue
                if ($null -ne $prop -and $null -ne $prop.$($inv.ValueName)) {
                    $actualValue = $prop.$($inv.ValueName)
                }
            } catch {
                Write-Warning "Fallo al consultar invariante '$($inv.Id)': $($_.Exception.Message)"
            }
        }

        $isCompliant = ($null -ne $actualValue) -and ($actualValue -eq $inv.ExpectedValue)

        if (-not $isCompliant) {
            $violation = [PSCustomObject]@{
                Id            = $inv.Id
                Category      = $inv.Category
                Name          = $inv.Name
                PSPath        = $inv.PSPath
                ExpectedValue = $inv.ExpectedValue
                ActualValue   = $actualValue
                Remediated    = $false
            }

            if ($AutoRemediate -and $PSCmdlet.ShouldProcess("$($inv.PSPath)\$($inv.ValueName)", "Autoreparar invariante del sistema")) {
                try {
                    if (-not (Test-Path -Path $inv.PSPath -ErrorAction SilentlyContinue)) {
                        New-Item -Path $inv.PSPath -Force -ErrorAction Stop | Out-Null
                    }
                    Set-ItemProperty -Path $inv.PSPath -Name $inv.ValueName -Value $inv.ExpectedValue -Type DWord -Force -ErrorAction Stop | Out-Null
                    $violation.Remediated = $true
                    if (-not $Quiet) {
                        Write-Host "  [AUTOREPAIR] Invariante '$($inv.Id)' restaurado a $($inv.ExpectedValue)." -ForegroundColor Green
                    }
                } catch {
                    Write-Error "CRITICAL: No se pudo autoreparar el invariante '$($inv.Id)': $($_.Exception.Message)"
                }
            }

            $violations.Add($violation)
        }
    }

    $allPassed = ($violations.Count -eq 0)
    return [PSCustomObject]@{
        Passed          = $allPassed
        TotalInvariants = $invariants.Count
        ViolationsCount = $violations.Count
        Violations      = $violations.ToArray()
    }
}

function Invoke-RomanOSMutation {
    <#
    .SYNOPSIS
        Gateway de mutación controlada. Ejecuta una acción asegurando que ningún invariante resulte violado.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetName,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ActionScript,

        [switch]$ValidateInvariants = $true
    )

    if ($PSCmdlet.ShouldProcess($TargetName, "Ejecutar mutación de estado con salvaguarda de invariantes")) {
        # 1. Pre-assert
        if ($ValidateInvariants) {
            Assert-RomanOSInvariants -AutoRemediate -Quiet | Out-Null
        }

        # 2. Ejecución
        $result = $null
        try {
            $result = & $ActionScript
        } catch {
            Write-Error "Fallo en la mutación de estado '$TargetName': $($_.Exception.Message)"
            throw
        }

        # 3. Post-assert y Auto-remediación inmediata
        if ($ValidateInvariants) {
            $postAudit = Assert-RomanOSInvariants -AutoRemediate -Quiet
            if (-not $postAudit.Passed) {
                Write-Warning "La mutación '$TargetName' intentó alterar invariantes protegidos. Se aplicó auto-remediación para $($postAudit.ViolationsCount) directiva(s)."
            }
        }

        return $result
    }
}

# -----------------------------------------------------------------------------
# 11. SUITE DE DESKTOP HELPERS CANÓNICOS (SSOT)
# -----------------------------------------------------------------------------

$global:RomanOS_DesktopHelpers = @(
    @{
        Id                  = "HELP_WU"
        Name                = "WindowsUpdate"
        Title               = "Windows Update (Carril Seguro)"
        Description         = "Conmutador de actualizaciones oficiales sin alterar candados de drivers ni previews"
        TargetServices      = @("wuauserv", "UsoSvc")
        TargetTasks         = @("Microsoft\Windows\WindowsUpdate\sih", "Microsoft\Windows\WindowsUpdate\sihboot")
        RegistryBranch      = "HKLM\SOFTWARE\RomanOS\DesktopHelpers\WindowsUpdate"
        PSRegistryBranch    = "HKLM:\SOFTWARE\RomanOS\DesktopHelpers\WindowsUpdate"
        ProtectedInvariants = @("INV_DRIVERS_NO_WU_OVERWRITE", "INV_WU_NO_PREVIEWS", "INV_WU_QUALITY_DEFERRAL_7D", "INV_ANTI_BLOAT_CONTENT_DELIVERY")
        DefaultState        = 1
    },
    @{
        Id                  = "HELP_DEFENDER"
        Name                = "Defender"
        Title               = "Microsoft Defender & SmartScreen"
        Description         = "Conmutador de protección en tiempo real y SmartScreen"
        TargetServices      = @("WinDefend", "Sense", "WdNisSvc")
        TargetTasks         = @("Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan")
        RegistryBranch      = "HKLM\SOFTWARE\RomanOS\DesktopHelpers\Defender"
        PSRegistryBranch    = "HKLM:\SOFTWARE\RomanOS\DesktopHelpers\Defender"
        ProtectedInvariants = @("INV_SECURITY_DRIVER_BLOCKLIST")
        DefaultState        = 1
    },
    @{
        Id                  = "HELP_BLUETOOTH"
        Name                = "Bluetooth"
        Title               = "Servicios y Pila Bluetooth"
        Description         = "Conmutador de conectividad inalámbrica para mandos y auriculares"
        TargetServices      = @("bthserv", "BluetoothUserService")
        TargetTasks         = @()
        RegistryBranch      = "HKLM\SOFTWARE\RomanOS\DesktopHelpers\Bluetooth"
        PSRegistryBranch    = "HKLM:\SOFTWARE\RomanOS\DesktopHelpers\Bluetooth"
        ProtectedInvariants = @()
        DefaultState        = 1
    },
    @{
        Id                  = "HELP_PRINTING"
        Name                = "Printing"
        Title               = "Servicio de Impresión (Spooler)"
        Description         = "Conmutador del subsistema de cola de impresión"
        TargetServices      = @("Spooler")
        TargetTasks         = @()
        RegistryBranch      = "HKLM\SOFTWARE\RomanOS\DesktopHelpers\Printing"
        PSRegistryBranch    = "HKLM:\SOFTWARE\RomanOS\DesktopHelpers\Printing"
        ProtectedInvariants = @()
        DefaultState        = 0
    },
    @{
        Id                  = "HELP_FILESHARING"
        Name                = "FileSharing"
        Title               = "Uso Compartido de Red (SMB)"
        Description         = "Conmutador de LanmanServer, LanmanWorkstation y Network Discovery"
        TargetServices      = @("LanmanServer", "LanmanWorkstation")
        TargetTasks         = @()
        RegistryBranch      = "HKLM\SOFTWARE\RomanOS\DesktopHelpers\FileSharing"
        PSRegistryBranch    = "HKLM:\SOFTWARE\RomanOS\DesktopHelpers\FileSharing"
        ProtectedInvariants = @()
        DefaultState        = 0
    },
    @{
        Id                  = "HELP_VBS"
        Name                = "VBS"
        Title               = "Seguridad Basada en Virtualización (VBS / HVCI)"
        Description         = "Conmutador de integridad de memoria del hipervisor (Esports vs Seguridad)"
        TargetServices      = @()
        TargetTasks         = @()
        RegistryBranch      = "HKLM\SOFTWARE\RomanOS\DesktopHelpers\VBS"
        PSRegistryBranch    = "HKLM:\SOFTWARE\RomanOS\DesktopHelpers\VBS"
        ProtectedInvariants = @("INV_SECURITY_DRIVER_BLOCKLIST")
        DefaultState        = 1
    }
)

function Get-RomanOSDesktopHelperDef {
    <#
    .SYNOPSIS
        Retorna la definición de un helper o la lista completa de helpers.
    #>
    [CmdletBinding()]
    param(
        [Alias("HelperId")]
        [string]$Name
    )
    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $global:RomanOS_DesktopHelpers
    }
    return $global:RomanOS_DesktopHelpers | Where-Object { $_.Name -ieq $Name -or $_.Id -ieq $Name } | Select-Object -First 1
}

function Get-RomanOSDesktopHelperState {
    <#
    .SYNOPSIS
        Consulta el estado actual de un Desktop Helper en el registro (0=Disabled, 1=Enabled).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Alias("HelperId")]
        [string]$Name
    )

    $helper = Get-RomanOSDesktopHelperDef -Name $Name
    if (-not $helper) {
        Write-Warning "Desktop Helper '$Name' no reconocido en el catálogo SSOT."
        return [PSCustomObject]@{
            Name   = $Name
            State  = -1
            Status = "Unknown"
        }
    }

    $stateVal = $helper.DefaultState

    if (Test-Path -Path $helper.PSRegistryBranch -ErrorAction SilentlyContinue) {
        try {
            $prop = Get-ItemProperty -Path $helper.PSRegistryBranch -Name "State" -ErrorAction SilentlyContinue
            if ($null -ne $prop -and $null -ne $prop.State) {
                $stateVal = [int]$prop.State
                return [PSCustomObject]@{
                    Name   = $helper.Name
                    State  = $stateVal
                    Status = if ($stateVal -eq 1) { "Enabled" } else { "Disabled" }
                }
            }
        } catch {
            Write-Warning "Fallo al consultar estado de '$Name': $($_.Exception.Message)"
        }
    }

    if ($helper.TargetServices.Count -gt 0) {
        $mainSvc = $helper.TargetServices[0]
        $svcObj = Get-Service -Name $mainSvc -ErrorAction SilentlyContinue
        if ($svcObj) {
            $stateVal = if ($svcObj.StartType -eq "Disabled") { 0 } else { 1 }
            return [PSCustomObject]@{
                Name   = $helper.Name
                State  = $stateVal
                Status = if ($stateVal -eq 1) { "Enabled" } else { "Disabled" }
            }
        }
    }

    return [PSCustomObject]@{
        Name   = $helper.Name
        State  = $stateVal
        Status = if ($stateVal -eq 1) { "Enabled" } else { "Disabled" }
    }
}

function Set-RomanOSDesktopHelperState {
    <#
    .SYNOPSIS
        Conmuta el estado de un Desktop Helper (0=Disabled, 1=Enabled) utilizando el Mutation Gateway.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [Alias("HelperId")]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet(0, 1)]
        [int]$State,

        [switch]$Quiet
    )

    $helper = Get-RomanOSDesktopHelperDef -Name $Name
    if (-not $helper) {
        throw "Desktop Helper '$Name' no existe en el catálogo canónico."
    }

    if ($PSCmdlet.ShouldProcess("$($helper.Title) -> Estado: $State", "Conmutar servicio de Desktop Helper")) {
        Invoke-RomanOSMutation -TargetName "DesktopHelper_$Name" -ActionScript {
            # 1. Conmutar servicios
            foreach ($svc in $helper.TargetServices) {
                try {
                    $svcExists = Get-Service -Name $svc -ErrorAction SilentlyContinue
                    if ($svcExists) {
                        if ($State -eq 1) {
                            & sc.exe config $svc start= demand 2>&1 | Out-Null
                            & sc.exe start $svc 2>&1 | Out-Null
                        } else {
                            & sc.exe stop $svc 2>&1 | Out-Null
                            & sc.exe config $svc start= disabled 2>&1 | Out-Null
                        }
                    }
                } catch {
                    Write-Warning "Error al conmutar servicio '$svc': $($_.Exception.Message)"
                }
            }

            # 2. Conmutar tareas programadas si existen
            foreach ($task in $helper.TargetTasks) {
                try {
                    $taskState = if ($State -eq 1) { "/Enable" } else { "/Disable" }
                    & schtasks.exe /Change /TN "$task" $taskState 2>&1 | Out-Null
                } catch {
                    Write-Warning "Error al conmutar tarea '$task': $($_.Exception.Message)"
                }
            }

            # 3. Acciones específicas por Helper
            if ($Name -ieq "VBS") {
                try {
                    $hvciVal = if ($State -eq 1) { 1 } else { 0 }
                    $hypLaunch = if ($State -eq 1) { "Auto" } else { "Off" }
                    $vbsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
                    if (-not (Test-Path $vbsPath)) { New-Item -Path $vbsPath -Force | Out-Null }
                    Set-ItemProperty -Path $vbsPath -Name "Enabled" -Value $hvciVal -Type DWord -Force | Out-Null
                    & bcdedit.exe /set hypervisorlaunchtype $hypLaunch 2>&1 | Out-Null
                } catch {
                    Write-Warning "Fallo al conmutar VBS/HVCI: $($_.Exception.Message)"
                }
            }

            # 4. Actualizar estado persistente en HKLM\SOFTWARE\RomanOS\DesktopHelpers
            try {
                if (-not (Test-Path -Path $helper.PSRegistryBranch)) {
                    New-Item -Path $helper.PSRegistryBranch -Force | Out-Null
                }
                Set-ItemProperty -Path $helper.PSRegistryBranch -Name "State" -Value $State -Type DWord -Force | Out-Null
                Set-ItemProperty -Path $helper.PSRegistryBranch -Name "Title" -Value $helper.Title -Type String -Force | Out-Null
                Set-ItemProperty -Path $helper.PSRegistryBranch -Name "LastUpdated" -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Type String -Force | Out-Null
            } catch {
                Write-Warning "Fallo al registrar estado de Helper en registro: $($_.Exception.Message)"
            }

            if (-not $Quiet) {
                $statusText = if ($State -eq 1) { "ACTIVADO [Demand/Running]" } else { "DESACTIVADO [Disabled/Stopped]" }
                Write-Host "  [OK] $($helper.Title) ha sido conmutado a: $statusText" -ForegroundColor Cyan
            }
        }
    }
}

# ============================================================================
# FASE 2 (PLAN-0117): MOTOR Y PERFILES CANÓNICOS DE DNS INTELIGENTE (SSOT)
# ============================================================================

function Get-RomanOSDnsProfiles {
    <#
    .SYNOPSIS
        Retorna los perfiles canonicos de proveedores DNS de alta velocidad y seguridad para romanOS.
    .DESCRIPTION
        Fuente Unica de Verdad (SSOT) de configuraciones de DNS (IPv4, IPv6, DoH Templates y metadatos)
        inspirada en Chris Titus Tech WinUtil y estandarizada para Windows 11 24H2/25H2.
    #>
    [CmdletBinding()]
    param()

    return @(
        [PSCustomObject]@{
            Id            = "Cloudflare"
            Name          = "Cloudflare DNS (1.1.1.1)"
            Description   = "Maxima velocidad global y privacidad estricta sin registros."
            PrimaryIPv4   = "1.1.1.1"
            SecondaryIPv4 = "1.0.0.1"
            PrimaryIPv6   = "2606:4700:4700::1111"
            SecondaryIPv6 = "2606:4700:4700::1001"
            DoHTemplate   = "https://cloudflare-dns.com/dns-query"
            SupportsDoH   = $true
            Category      = "Rendimiento & Privacidad"
        },
        [PSCustomObject]@{
            Id            = "Quad9"
            Name          = "Quad9 DNS (9.9.9.9 - Seguridad)"
            Description   = "Bloqueo activo de malware, phishing y dominios fraudulentos."
            PrimaryIPv4   = "9.9.9.9"
            SecondaryIPv4 = "149.112.112.112"
            PrimaryIPv6   = "2620:fe::fe"
            SecondaryIPv6 = "2620:fe::9"
            DoHTemplate   = "https://dns.quad9.net/dns-query"
            SupportsDoH   = $true
            Category      = "Seguridad & Anti-Malware"
        },
        [PSCustomObject]@{
            Id            = "Google"
            Name          = "Google Public DNS (8.8.8.8)"
            Description   = "Infraestructura Anycast global de Google de alta disponibilidad."
            PrimaryIPv4   = "8.8.8.8"
            SecondaryIPv4 = "8.8.4.4"
            PrimaryIPv6   = "2001:4860:4860::8888"
            SecondaryIPv6 = "2001:4860:4860::8844"
            DoHTemplate   = "https://dns.google/dns-query"
            SupportsDoH   = $true
            Category      = "Disponibilidad Global"
        },
        [PSCustomObject]@{
            Id            = "AdGuard"
            Name          = "AdGuard DNS (Anti-Publicidad)"
            Description   = "Filtrado de anuncios y rastreadores a nivel de resolucion de red."
            PrimaryIPv4   = "94.140.14.14"
            SecondaryIPv4 = "94.140.15.15"
            PrimaryIPv6   = "2a10:50c0::ad1:ff"
            SecondaryIPv6 = "2a10:50c0::ad2:ff"
            DoHTemplate   = "https://dns.adguard-dns.com/dns-query"
            SupportsDoH   = $true
            Category      = "Ad-Blocking & Privacidad"
        },
        [PSCustomObject]@{
            Id            = "DHCP"
            Name          = "DHCP Automatico (ISP / Router)"
            Description   = "Restablece la asignacion dinamica de DNS otorgada por el enrutador."
            PrimaryIPv4   = $null
            SecondaryIPv4 = $null
            PrimaryIPv6   = $null
            SecondaryIPv6 = $null
            DoHTemplate   = $null
            SupportsDoH   = $false
            Category      = "Por Defecto de Red"
        }
    )
}

function Get-RomanOSDnsProfileById {
    <#
    .SYNOPSIS
        Busca y retorna un perfil de DNS por su identificador unico.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    $profiles = Get-RomanOSDnsProfiles
    return ($profiles | Where-Object { $_.Id -ieq $Id })
}




