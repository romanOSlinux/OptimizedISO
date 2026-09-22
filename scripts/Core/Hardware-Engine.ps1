<#
.SYNOPSIS
    Hardware-Engine.ps1 - Motor de IntrospecciÃ³n y DetecciÃ³n Robusta de Hardware
    Estandar de clasificacion y diagnostico para romanOS / OptimizedISO.

.DESCRIPTION
    Proporciona introspeccion determinista y desacoplada del hardware del sistema
    basada en estandares oficiales de la industria:
      - PCI-SIG Vendor IDs (NVIDIA 10DE, AMD 1002/1022, Intel 8086, VirtIO 1AF4, VMware 15AD)
      - DMTF SMBIOS System Enclosure Specification (ChassisTypes)
      - Microsoft Storage WMI/CIM Namespace (MSFT_PhysicalDisk, Get-Disk IsBoot)
      - DMTF SMBIOS Physical Memory (Win32_PhysicalMemory Canales/Frecuencia)
      - Topologia WMI/CIM de CPU (P/E cores hÃ­bridos, AMD 3D V-Cache multi-CCD, timers)
      - WDDM 2.7+ / HAGS y Message Signaled Interrupts (MSI/MSI-X) para GPUs PCIe

    100% compatible con Windows PowerShell 5.1 (powershell.exe) y PowerShell 7+ (pwsh).
    Codificacion estricta UTF-8 con BOM.

.EXAMPLE
    . "$PSScriptRoot\Core\Hardware-Engine.ps1"
    $hw = Get-SystemHardwareProfile
    Format-HardwareSummary -Profile $hw
    Enable-GpuMsiMode -HardwareProfile $hw
#>

$global:RomanOS_Hardware_Engine_Loaded = $true

# Cache de perfil de hardware en la sesion actual
$script:CachedHardwareProfile = $null

# -----------------------------------------------------------------------------
# TABLAS DE REFERENCIA DE ESTANDARES DE LA INDUSTRIA
# -----------------------------------------------------------------------------

# PCI-SIG Vendor IDs Oficiales
$script:PCI_VENDORS = @{
    '10DE' = 'NVIDIA'
    '1002' = 'AMD'
    '1022' = 'AMD'
    '8086' = 'Intel'
    '1AF4' = 'Red Hat / VirtIO'
    '15AD' = 'VMware'
    '1414' = 'Microsoft'
    '80EE' = 'VirtualBox'
    '1013' = 'Cirrus Logic'
    '5333' = 'S3 Graphics'
    '102B' = 'Matrox'
}

# DMTF SMBIOS Chassis Types (DSP0134 Specification Section 7.4.1)
$script:DMTF_LAPTOP_TYPES  = @(8, 9, 10, 11, 12, 14, 30, 31, 32)
$script:DMTF_DESKTOP_TYPES = @(3, 4, 5, 6, 7, 15, 16, 24, 34, 35, 36)
$script:DMTF_SERVER_TYPES  = @(17, 23, 28, 29)

$script:DMTF_CHASSIS_NAMES = @{
    1  = 'Other'
    2  = 'Unknown'
    3  = 'Desktop'
    4  = 'Low Profile Desktop'
    5  = 'Pizza Box'
    6  = 'Mini Tower'
    7  = 'Tower'
    8  = 'Portable'
    9  = 'Laptop'
    10 = 'Notebook'
    11 = 'Hand Held'
    12 = 'Docking Station'
    13 = 'All in One'
    14 = 'Sub Notebook'
    15 = 'Space-saving'
    16 = 'Lunch Box'
    17 = 'Main Server Chassis'
    18 = 'Expansion Chassis'
    19 = 'SubChassis'
    20 = 'Bus Expansion Chassis'
    21 = 'Peripheral Chassis'
    22 = 'Storage Chassis'
    23 = 'Rack Mount Chassis'
    24 = 'Sealed-case PC'
    30 = 'Tablet'
    31 = 'Convertible'
    32 = 'Detachable'
    34 = 'Stick PC'
    35 = 'Mini PC / NUC'
    36 = 'All in One'
}

# SMBIOS Memory Types (DSP0134 Specification Section 7.18.2)
$script:SMBIOS_MEMORY_TYPES = @{
    20 = 'DDR'
    21 = 'DDR2'
    22 = 'DDR2 FB-DIMM'
    24 = 'DDR3'
    26 = 'DDR4'
    27 = 'LPDDR'
    28 = 'LPDDR2'
    29 = 'LPDDR3'
    30 = 'LPDDR4'
    31 = 'Logical non-volatile device'
    32 = 'HBM'
    33 = 'HBM2'
    34 = 'DDR5'
    35 = 'LPDDR5'
}

# -----------------------------------------------------------------------------
# FUNCION PRINCIPAL: Get-SystemHardwareProfile
# -----------------------------------------------------------------------------

function Get-SystemHardwareProfile {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$ForceRefresh
    )

    if (-not $ForceRefresh -and $null -ne $script:CachedHardwareProfile) {
        return $script:CachedHardwareProfile
    }

    # =========================================================================
    # 1. PLATAFORMA Y FACTOR DE FORMA (DMTF SMBIOS + Win32_Battery + PCSystemType)
    # =========================================================================
    $csys    = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $encl    = Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue
    $battery = Get-CimInstance Win32_Battery        -ErrorAction SilentlyContinue

    $compManufacturer = if ($csys -and $csys.Manufacturer) { $csys.Manufacturer.Trim() } else { 'Desconocido' }
    $compModel        = if ($csys -and $csys.Model)        { $csys.Model.Trim() }        else { 'Desconocido' }
    $systemFamily     = if ($csys -and $csys.SystemFamily) { $csys.SystemFamily.Trim() } else { '' }

    # Deteccion de Maquina Virtual
    $isVM   = $false
    $vmType = 'None'
    if ($compModel -match 'Virtual|Hyper-V|VMware|KVM|QEMU|VirtualBox|Bochs|Xen' -or
        $compManufacturer -match 'Microsoft Corporation|VMware|innotek|QEMU|Xen|Red Hat') {
        $isVM = $true
        if     ($compModel -match 'Hyper-V' -or $compManufacturer -match 'Microsoft') { $vmType = 'Hyper-V' }
        elseif ($compModel -match 'VMware'  -or $compManufacturer -match 'VMware')    { $vmType = 'VMware' }
        elseif ($compModel -match 'VirtualBox' -or $compManufacturer -match 'innotek') { $vmType = 'VirtualBox' }
        elseif ($compModel -match 'KVM|QEMU'   -or $compManufacturer -match 'QEMU|Red Hat') { $vmType = 'KVM/QEMU' }
        elseif ($compModel -match 'Xen'        -or $compManufacturer -match 'Xen')     { $vmType = 'Xen' }
        else   { $vmType = 'Virtual Machine' }
    }

    # Extraccion de tipos de chasis DMTF
    $chassisTypes = @()
    if ($encl -and $encl.ChassisTypes) {
        $chassisTypes = @($encl.ChassisTypes)
    }

    $chassisNames = @()
    foreach ($ct in $chassisTypes) {
        if ($script:DMTF_CHASSIS_NAMES.ContainsKey([int]$ct)) {
            $chassisNames += $script:DMTF_CHASSIS_NAMES[[int]$ct]
        } else {
            $chassisNames += "Tipo $ct"
        }
    }
    $chassisDesc = if ($chassisNames.Count -gt 0) { $chassisNames -join ', ' } else { 'Desktop / Estandar' }

    # Clasificacion DMTF
    $isLaptopByChassis  = $false
    $isDesktopByChassis = $false
    $isServerByChassis  = $false

    foreach ($ct in $chassisTypes) {
        $ctInt = [int]$ct
        if ($script:DMTF_LAPTOP_TYPES -contains $ctInt)  { $isLaptopByChassis  = $true }
        if ($script:DMTF_DESKTOP_TYPES -contains $ctInt) { $isDesktopByChassis = $true }
        if ($script:DMTF_SERVER_TYPES -contains $ctInt)  { $isServerByChassis  = $true }
    }

    # PCSystemType (Microsoft Learn)
    $pcType = if ($csys) { [int]$csys.PCSystemType } else { 0 }
    $isLaptopByType = ($pcType -eq 2)
    $hasBattery     = ($null -ne $battery)

    # Resolucion determinista Laptop vs Desktop con filtro de UPS USB
    $isLaptop = $false
    $laptopSrc = ''

    if ($isLaptopByChassis -and $hasBattery) {
        $isLaptop = $true
        $laptopSrc = "SMBIOS ($chassisDesc) + Bateria interna"
    } elseif ($isLaptopByChassis -and -not $hasBattery) {
        $isLaptop = $true
        $laptopSrc = "SMBIOS ($chassisDesc, sin bateria)"
    } elseif ($isLaptopByType -and $hasBattery) {
        $isLaptop = $true
        $laptopSrc = "PCSystemType=Mobile + Bateria"
    } elseif ($isLaptopByType -and -not $hasBattery) {
        $isLaptop = $true
        $laptopSrc = "PCSystemType=Mobile"
    } elseif (-not $isLaptopByChassis -and $hasBattery) {
        # Conflicto tipico: Chasis torre/desktop conectado a un SAI/UPS por USB
        $isLaptop = $false
        $laptopSrc = "Desktop SMBIOS ($chassisDesc) [Bateria detectada: Posible SAI/UPS USB -> Tratado como Desktop]"
    } else {
        $isLaptop = $false
        $laptopSrc = "Desktop / Torre SMBIOS ($chassisDesc)"
    }

    $isDesktop = (-not $isLaptop -and -not $isServerByChassis)
    $isServer  = ($isServerByChassis -or $pcType -in @(4, 5, 7))

    # Modern Standby (S0ix Low Power Idle)
    $hasModernStandby = $false
    if ($isLaptop) {
        try {
            $powerPlatform = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlatform -ErrorAction SilentlyContinue
            if ($powerPlatform -and ($powerPlatform.AoAc -or $powerPlatform.ModernStandby)) {
                $hasModernStandby = $true
            } else {
                $aoacReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "PlatformAoAcOverride" -ErrorAction SilentlyContinue
                if ($aoacReg) { $hasModernStandby = $true }
            }
        } catch {
            Write-Warning "[Hardware-Engine] No se pudo interrogar Win32_PowerPlatform o registro de ModernStandby: $($_.Exception.Message)"
        }
    }

    # =========================================================================
    # 2. PROCESADOR Y TOPOLOGIA DE CPU (Win32_Processor)
    # =========================================================================
    $cpuObj      = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $cpuName     = if ($cpuObj -and $cpuObj.Name) { $cpuObj.Name.Trim() } else { 'Desconocido' }
    $cpuCores    = if ($cpuObj) { [int]$cpuObj.NumberOfCores } else { 0 }
    $cpuThreads  = if ($cpuObj) { [int]$cpuObj.NumberOfLogicalProcessors } else { 0 }
    $cpuMHz      = if ($cpuObj) { [int]$cpuObj.MaxClockSpeed } else { 0 }
    $cpuManuf    = if ($cpuObj -and $cpuObj.Manufacturer) { $cpuObj.Manufacturer } else { '' }

    # Vendor CPU
    $cpuVendor = 'Unknown'
    if     ($cpuManuf -match 'AuthenticAMD' -or $cpuName -match 'AMD|Ryzen|Athlon|Epyc|Threadripper') { $cpuVendor = 'AMD' }
    elseif ($cpuManuf -match 'GenuineIntel' -or $cpuName -match 'Intel|Core|Xeon|Pentium|Celeron')     { $cpuVendor = 'Intel' }
    elseif ($cpuManuf -match 'ARM|Qualcomm'  -or $cpuName -match 'Snapdragon|Ampere|ARM')               { $cpuVendor = 'ARM' }

    # CPU Moderna (Beneficiada por GlobalTimerResolutionRequests y optimizaciones de scheduler)
    # - Intel 12th Gen+ (Alder Lake, Raptor Lake, Meteor Lake, Arrow Lake, Lunar Lake)
    # - Intel Core Ultra (Series 1 & 2)
    # - Intel Core 3/5/7 (Series 1)
    # - Intel Processor N-Series (Alder Lake-N)
    # - AMD Ryzen 5000+ (Zen 3, Zen 4, Zen 5, Ryzen AI 300)
    $isIntel12thPlus = ($cpuName -match 'i[3579]-1[2-9][0-9]{3}') -or
                       ($cpuName -match 'i[3579]-[2-9][0-9]{4}') -or
                       ($cpuName -match 'Core.*Ultra') -or
                       ($cpuName -match 'Core\s+[3579]\s+[0-9]{3}') -or
                       ($cpuName -match '1[2-9]th Gen Intel') -or
                       ($cpuName -match 'Intel.*Processor.*N[0-9]{2,3}')
    $isRyzen5kPlus   = ($cpuName -match 'Ryzen [3579] [5-9][0-9]{3}') -or
                       ($cpuName -match 'Ryzen [3579] [1-9][0-9]{4}') -or
                       ($cpuName -match 'Ryzen.*AI')
    $isModernCPU     = ($isIntel12thPlus -or $isRyzen5kPlus)

    # Clasificacion de Arquitectura Intel
    # 1. Intel Hybrid (P-Cores + E-Cores gestionados por Intel Thread Director)
    #    - Intel Core Ultra Series 1 (Meteor Lake) y Series 2 (Arrow Lake / Lunar Lake sin Hyper-Threading en P-cores)
    #    - Intel 12th-14th Gen (i5/i7/i9 12xxx-14xxx con P+E cores)
    #    - Intel Core 3/5/7 Series 1 (e.g. Core 5 120U, Core 7 150U)
    $isIntelUltra     = ($cpuVendor -eq 'Intel' -and $cpuName -match 'Core.*Ultra')
    $isIntelAlderRap  = ($cpuVendor -eq 'Intel' -and ($cpuName -match 'i[579]-1[2-4][0-9]{3}') -and ($cpuThreads -gt ($cpuCores * 1.2)) -and ($cpuCores -gt 4))
    $isHybridCPU      = ($isIntelUltra -or $isIntelAlderRap)

    # 2. Intel E-Core Only (Alder Lake-N: N95, N100, N200, N300, i3-N305)
    $isEcoreOnly      = ($cpuVendor -eq 'Intel' -and ($cpuName -match 'Processor\s+N[0-9]{2,3}' -or $cpuName -match 'i3-N[0-9]{3}'))

    # 3. Intel Legacy Core (1st - 11th Gen: Nehalem a Rocket Lake)
    $isLegacyIntel    = ($cpuVendor -eq 'Intel' -and ($cpuName -match 'i[3579]-[1-9][0-9]{2,3}' -or $cpuName -match '[1-9]th Gen Intel') -and -not $isIntel12thPlus)

    # 4. Intel Xeon (Workstation & Server con topologia Mesh / Multi-NUMA)
    $isIntelXeon      = ($cpuVendor -eq 'Intel' -and $cpuName -match 'Xeon')

    # 5. AMD 3D V-Cache multi-CCD asimetrico (7900X3D, 7950X3D, 9900X3D, 9950X3D)
    # Requiere que el driver AMD PPM Provisioning gestione el parking del CCD sin V-Cache
    $isDualCcdX3D     = ($cpuName -match 'Ryzen 9 (7900X3D|7950X3D|9900X3D|9950X3D)')

    # 6. CPU de Recursos Limitados / Low-End (Celeron, Atom, Pentium, Ryzen 3 1xxx-3xxx, i3 1st-6th Gen)
    $isLowEndCPU      = ($cpuName -match 'Celeron|Pentium|Atom|J[0-9]{4}' -or ($cpuName -match 'N[0-9]{4}' -and $cpuName -notmatch 'Processor\s+N')) -or
                        ($cpuName -match 'Ryzen 3 [1-4][0-9]{3}') -or
                        ($cpuName -match 'i3-[1-6][0-9]{3}' -and $cpuName -notmatch 'i3-[1-6][0-9]{4}') -or
                        ($cpuCores -le 2 -and $cpuMHz -le 2400)

    # Temperatura CPU en Idle (MSAcpi_ThermalZoneTemperature)
    $cpuTempC    = $null
    $cpuTempWarn = $false
    try {
        $thermalZones = Get-CimInstance -Namespace 'root/WMI' -ClassName 'MSAcpi_ThermalZoneTemperature' -ErrorAction Stop
        if ($thermalZones) {
            $rawTemp = ($thermalZones | Select-Object -First 1).CurrentTemperature
            if ($rawTemp -gt 2732) {
                $cpuTempC = [math]::Round(($rawTemp - 2732) / 10, 1)
                $cpuTempWarn = ($isLaptop -and $cpuTempC -gt 70)
            }
        }
    } catch {
        $cpuTempC = $null
    }

    # =========================================================================
    # 3. MEMORIA RAM Y CANALES (Win32_PhysicalMemory + Win32_ComputerSystem)
    # =========================================================================
    $ramBytes = if ($csys) { [long]$csys.TotalPhysicalMemory } else { 0 }
    $ramGiB   = [math]::Round($ramBytes / 1GB, 1)
    $isLowRAM = ($ramGiB -le 4.0)

    $ramModules    = @()
    $moduleCount   = 0
    $channelCount  = 0
    $isSingleChan  = $false
    $memoryTypeStr = 'Unknown'
    $ramSpeedMHz   = 0

    try {
        $ramModules  = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop)
        $moduleCount = $ramModules.Count

        if ($moduleCount -gt 0) {
            $firstMod = $ramModules[0]
            if ($firstMod.ConfiguredClockSpeed) { $ramSpeedMHz = [int]$firstMod.ConfiguredClockSpeed }
            elseif ($firstMod.Speed)            { $ramSpeedMHz = [int]$firstMod.Speed }

            $smbType = [int]$firstMod.SMBIOSMemoryType
            if ($script:SMBIOS_MEMORY_TYPES.ContainsKey($smbType)) {
                $memoryTypeStr = $script:SMBIOS_MEMORY_TYPES[$smbType]
            }

            # Deteccion de canales por BankLabel o DeviceLocator
            $distinctBanks = @($ramModules | Select-Object -ExpandProperty BankLabel -Unique | Where-Object { $_ })
            if ($distinctBanks.Count -gt 1) {
                $channelCount = $distinctBanks.Count
            } else {
                $distinctLocs = @($ramModules | Select-Object -ExpandProperty DeviceLocator -Unique | Where-Object { $_ })
                $channelCount = $distinctLocs.Count
            }

            if ($moduleCount -eq 1 -or $channelCount -le 1) {
                $isSingleChan = $true
                $channelModeStr = 'Single-Channel'
            } elseif ($channelCount -eq 2 -or $moduleCount -eq 2) {
                $isSingleChan = $false
                $channelModeStr = 'Dual-Channel'
            } elseif ($channelCount -ge 4 -or $moduleCount -ge 4) {
                $isSingleChan = $false
                $channelModeStr = 'Quad/Multi-Channel'
            } else {
                $isSingleChan = $false
                $channelModeStr = "$moduleCount Modulos"
            }
        }
    } catch {
        $moduleCount    = 0
        $channelCount   = 0
        $channelModeStr = 'Desconocido'
    }

    # =========================================================================
    # 4. ALMACENAMIENTO Y DIRECTSTORAGE (Get-Disk + Get-PhysicalDisk)
    # =========================================================================
    $isHDD               = $false
    $isNVMe              = $false
    $isSATA              = $false
    $isSSD               = $false
    $diskBusType         = 'Desconocido'
    $diskMediaType       = 'Desconocido'
    $bootDiskNumber      = -1
    $bootModel           = 'Desconocido'
    $diskLabel           = 'Desconocido'
    $isBypassIOSupported = $false
    $directStorageStatus = 'No evaluado'

    try {
        $bootDisk = Get-Disk -ErrorAction Stop | Where-Object IsBoot -eq $true | Select-Object -First 1
        if ($bootDisk) {
            $bootDiskNumber = $bootDisk.Number
            $sysDisk = Get-PhysicalDisk -ErrorAction Stop | Where-Object DeviceId -eq $bootDiskNumber | Select-Object -First 1
            if (-not $sysDisk) {
                $sysDisk = Get-PhysicalDisk -ErrorAction Stop | Select-Object -First 1
            }
            if ($sysDisk) {
                $diskBusType   = "$($sysDisk.BusType)"
                $diskMediaType = "$($sysDisk.MediaType)"
                $bootModel     = "$($sysDisk.FriendlyName)"

                $isHDD  = ($diskMediaType -eq 'HDD')
                $isNVMe = ($diskBusType  -eq 'NVMe')
                $isSATA = ($diskBusType  -eq 'SATA')
                $isSSD  = ($diskMediaType -eq 'SSD' -or $isNVMe)

                if     ($isNVMe)                  { $diskLabel = 'NVMe SSD' }
                elseif ($isSATA -and -not $isHDD) { $diskLabel = 'SATA SSD' }
                elseif ($isHDD)                   { $diskLabel = 'HDD' }
                else                              { $diskLabel = "$diskBusType / $diskMediaType" }
            }
        }
    } catch {
        # Fallback analÃ­tico mediante Win32_DiskDrive
        try {
            $wmiDisk = Get-CimInstance Win32_DiskDrive -ErrorAction Stop | Sort-Object Index | Select-Object -First 1
            $bootModel = if ($wmiDisk.Model) { $wmiDisk.Model } else { 'Desconocido' }
            if ($bootModel -match 'HDD|WD[^C]|Seagate|Toshiba|Hitachi|HGST|ST[0-9]') {
                $isHDD = $true; $diskLabel = 'HDD (heuristica)'
            } elseif ($bootModel -match 'NVMe|PCIe') {
                $isNVMe = $true; $isSSD = $true; $diskLabel = 'NVMe SSD (heuristica)'
            } else {
                $isSSD = $true; $diskLabel = 'SSD / Desconocido'
            }
        } catch {
            $diskLabel = 'Desconocido'
        }
    }

    # DirectStorage / BypassIO (Solo aplicable y verificable en discos NVMe)
    if ($isNVMe) {
        $targetDrive = if ($env:SystemDrive) { "$($env:SystemDrive)\" } else { "C:\" }
        try {
            $bypassIoOut = & fsutil.exe bypassIO state $targetDrive 2>&1 | Out-String
            if ($bypassIoOut -match 'BypassIo is supported' -or $bypassIoOut -match 'BypassIo is enabled') {
                $isBypassIOSupported = $true
                $directStorageStatus = 'DirectStorage / BypassIO: ACTIVO [OK]'
            } else {
                $isBypassIOSupported = $false
                $directStorageStatus = 'DirectStorage: Estandar (sin BypassIO)'
            }
        } catch {
            Write-Warning "[Hardware-Engine] Error interrogando BypassIO con fsutil en ($targetDrive) - $($_.Exception.Message)"
            $directStorageStatus = 'DirectStorage: NVMe detectado (fsutil no accesible)'
        }
    } else {
        $directStorageStatus = 'DirectStorage: N/A (disco no es NVMe)'
    }

    # =========================================================================
    # 5. MOTOR GRAFICO Y GPUS (PCI-SIG Standard Vendor IDs + PNPDeviceID)
    # =========================================================================
    $rawGpuObjs = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
    $gpuDevices = [System.Collections.Generic.List[PSCustomObject]]::new()

    $hasDedicatedGpu = $false
    $hasIntegratedGpu = $false
    $hasNvidiaGpu    = $false
    $hasAmdGpu       = $false
    $hasIntelArcGpu  = $false
    $hasVirtualGpu   = $false
    $hasRdna3Igpu    = $false  # PLAN-0048: iGPUs RDNA3/3.5 (Radeon 760M/780M/890M/etc.)

    foreach ($g in $rawGpuObjs) {
        $gName    = if ($g.Name) { $g.Name.Trim() } else { 'Controlador de pantalla' }
        $pnpId    = if ($g.PNPDeviceID) { $g.PNPDeviceID.Trim() } else { '' }
        $drvVer   = if ($g.DriverVersion) { $g.DriverVersion.Trim() } else { '' }
        $vram     = if ($g.AdapterRAM) { [long]$g.AdapterRAM } else { 0 }

        # Extraccion de Vendor ID y Device ID del PNPDeviceID (formato PCI\VEN_xxxx&DEV_yyyy...)
        $vendorId = ''
        $deviceId = ''
        if ($pnpId -match 'VEN_([0-9A-Fa-f]{4})') {
            $vendorId = $matches[1].ToUpper()
        }
        if ($pnpId -match 'DEV_([0-9A-Fa-f]{4})') {
            $deviceId = $matches[1].ToUpper()
        }

        # Identificar Fabricante por PCI Vendor ID
        $vendorName = 'Other'
        if ($script:PCI_VENDORS.ContainsKey($vendorId)) {
            $vendorName = $script:PCI_VENDORS[$vendorId]
        } elseif ($gName -match 'NVIDIA') {
            $vendorName = 'NVIDIA'; $vendorId = '10DE'
        } elseif ($gName -match 'Radeon|AMD|ATI') {
            $vendorName = 'AMD'; $vendorId = '1002'
        } elseif ($gName -match 'Intel') {
            $vendorName = 'Intel'; $vendorId = '8086'
        }

        # Clasificacion Dedicada vs Integrada vs Virtual
        $isDedicated  = $false
        $isIntegrated = $false
        $isVirtual    = $false
        $supportsMsi  = $false
        $supportsHags = $false

        # Todo dispositivo sobre bus PCI soporta Message Signaled Interrupts (MSI/MSI-X)
        if ($pnpId -match '^PCI\\') {
            $supportsMsi = $true
        }

        # Clasificacion segun Vendor y Arquitectura
        switch ($vendorId) {
            '10DE' {
                # NVIDIA: Todas las GPUs modernas x86 son dedicadas
                $isDedicated    = $true
                $hasNvidiaGpu   = $true
                $hasDedicatedGpu = $true

                # HAGS en NVIDIA: WDDM 2.7+ (Driver 451.48+ / DriverVersion 27.21.14.5148+) y Pascal (GTX 10xx)+
                if ($drvVer) {
                    if ($drvVer -match '^[2-9][7-9]\.' -or $drvVer -match '^[3-9][0-9]\.') {
                        $supportsHags = $true
                    }
                }
            }

            { $_ -in @('1002', '1022') } {
                # AMD: Diferenciar dGPU (Radeon RX / R9 / Pro) de APU iGPU
                # PLAN-0048: Ampliado para detectar iGPUs RDNA3/RDNA3.5 (760M/780M/890M)
                $hasAmdGpu = $true

                # Detectar iGPUs RDNA3/3.5: patron [6-8][0-9]{2}M (ej: 760M, 780M, 890M, 680M)
                $isRdna3Integrated = ($gName -match 'Radeon.*[6-8][0-9]{2}M') -or
                                     ($gName -match 'Radeon.*[89][0-9]{2}M') -or
                                     ($gName -match 'Radeon.*890M|Radeon.*780M|Radeon.*760M|Radeon.*680M')

                if ($gName -match 'Radeon.*(RX|Pro|Vega 56|Vega 64|VII|R9|R7)|HD [789][0-9]{3}' -or
                    $vram -ge 1500000000 -or
                    ($pnpId -match 'DEV_67DF' -or $pnpId -match 'DEV_7[0-9A-Fa-f]{3}')) {
                    # Excluir iGPUs RDNA3 que tengan VRAM reportada >= 1.5GB (UMA framebuffer)
                    if (-not $isRdna3Integrated) {
                        $isDedicated     = $true
                        $hasDedicatedGpu = $true
                    } else {
                        $isIntegrated     = $true
                        $hasIntegratedGpu = $true
                        $hasRdna3Igpu     = $true
                    }
                } elseif ($isRdna3Integrated) {
                    $isIntegrated     = $true
                    $hasIntegratedGpu = $true
                    $hasRdna3Igpu     = $true
                } else {
                    $isIntegrated     = $true
                    $hasIntegratedGpu = $true
                }

                # HAGS en AMD: WDDM 2.7+ para dGPUs RDNA1+ (RX 5000+)
                # PLAN-0048: Extendido a iGPUs RDNA3 (760M/780M/890M) con driver 24.x+
                if (($gName -match 'RX [5-9][0-9]{3}|RX [1-9][0-9]{4}|Radeon 7[0-9]{3}' -or $isRdna3Integrated) -and
                    ($drvVer -match '^[2-9][7-9]\.' -or $drvVer -match '^[3-9][0-9]\.')) {
                    $supportsHags = $true
                }
            }

            '8086' {
                # Intel: Diferenciar Intel Arc dGPU (DG2/Battlemage: DEV_56xx, DEV_E2xx, DEV_4905) de UHD/Iris iGPU
                if ($gName -match 'Arc|DG1|DG2' -or $deviceId -match '^(56|E2|4905|4906)') {
                    $isDedicated     = $true
                    $hasIntelArcGpu  = $true
                    $hasDedicatedGpu = $true
                    $supportsHags    = $true
                } else {
                    $isIntegrated     = $true
                    $hasIntegratedGpu = $true
                }
            }

            { $_ -in @('1AF4', '15AD', '1414', '80EE') } {
                # Controladores de pantalla virtuales
                $isVirtual      = $true
                $hasVirtualGpu  = $true
                $supportsMsi    = $false
            }

            default {
                if ($vram -gt 1500000000) {
                    $isDedicated     = $true
                    $hasDedicatedGpu = $true
                } else {
                    $isIntegrated     = $true
                    $hasIntegratedGpu = $true
                }
            }
        }

        # Registro y Estado de MSI en el dispositivo
        $devParamsPath = if ($pnpId) { "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters" } else { '' }
        $msiRegPath    = if ($devParamsPath) { "$devParamsPath\Interrupt Management\MessageSignaledInterruptProperties" } else { '' }
        $currentMsiVal = $null

        if ($msiRegPath -and (Test-Path $msiRegPath)) {
            try {
                $currentMsiVal = (Get-ItemProperty -Path $msiRegPath -Name 'MSISupported' -ErrorAction Stop).MSISupported
            } catch {
                Write-Warning "[Hardware-Engine] No se pudo leer MSISupported en ($msiRegPath) - $($_.Exception.Message)"
            }
        }

        $gpuDevices.Add([PSCustomObject]@{
            Name                 = $gName
            PNPDeviceID          = $pnpId
            VendorId             = $vendorId
            VendorName           = $vendorName
            DeviceId             = $deviceId
            DriverVersion        = $drvVer
            AdapterRAM           = $vram
            IsDedicated          = $isDedicated
            IsIntegrated         = $isIntegrated
            IsVirtual            = $isVirtual
            SupportsHAGS         = $supportsHags
            SupportsMSI          = $supportsMsi
            MsiStatus            = $currentMsiVal
            DeviceParametersPath = $devParamsPath
            MsiRegistryPath      = $msiRegPath
        })
    }

    $primaryGpu = if ($gpuDevices.Count -gt 0) {
        # Priorizar GPU dedicada si existe, de lo contrario la primera
        $dg = $gpuDevices | Where-Object { $_.IsDedicated } | Select-Object -First 1
        if ($dg) { $dg } else { $gpuDevices[0] }
    } else {
        $null
    }

    $gpuSummary = if ($gpuDevices.Count -gt 0) {
        ($gpuDevices | Select-Object -ExpandProperty Name) -join ' | '
    } else {
        'No detectada'
    }

    # =========================================================================
    # 5.5 DETECCION DE NPU (Neural Processing Unit) - PLAN-0048
    # Clase PnP oficial: ComputeAccelerator (ACPI\QCOM*XDNA, ACPI\INT*NPU, etc.)
    # Referencia: Microsoft Hardware Dev Center + OEM WHQL catalogs
    # Soportados: AMD XDNA (Ryzen AI), Intel AI Boost (Meteor/Arrow Lake), Qualcomm Hexagon
    # =========================================================================
    $hasNpu          = $false
    $npuDeviceName   = ''
    $npuVendor       = 'None'
    $npuDevices      = [System.Collections.Generic.List[PSCustomObject]]::new()
    $npuTopOps       = 0     # TOPS (Tera Operations per Second) si se puede detectar

    try {
        # Consultar clase ComputeAccelerator via PnP (compatible con Win 11 22H2+)
        $pnpNpus = @(Get-PnpDevice -Class ComputeAccelerator -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'OK' })

        if ($pnpNpus -and $pnpNpus.Count -gt 0) {
            $hasNpu = $true
            foreach ($npuDev in $pnpNpus) {
                $npuName = if ($npuDev.FriendlyName) { $npuDev.FriendlyName } else { $npuDev.Name }
                $npuHwId = if ($npuDev.HardwareID) { $npuDev.HardwareID | Select-Object -First 1 } else { '' }

                # Identificar fabricante y arquitectura de NPU
                $npuMfr = 'Unknown'
                if     ($npuName -match 'AMD|XDNA|Ryzen AI' -or $npuHwId -match 'AMD|XDNA') { $npuMfr = 'AMD' }
                elseif ($npuName -match 'Intel|AI Boost|MTL|ARL'  -or $npuHwId -match '8086') { $npuMfr = 'Intel' }
                elseif ($npuName -match 'Qualcomm|Hexagon|Snapdragon' -or $npuHwId -match 'QCOM') { $npuMfr = 'Qualcomm' }

                if ($npuVendor -eq 'None') { $npuVendor = $npuMfr }
                if ($npuDeviceName -eq '')  { $npuDeviceName = $npuName }

                $npuDevices.Add([PSCustomObject]@{
                    Name       = $npuName
                    Vendor     = $npuMfr
                    HardwareId = $npuHwId
                    Status     = $npuDev.Status
                })
            }
        } else {
            # Fallback: detectar NPU conocidas via Win32_VideoController o CPU naming
            # AMD Ryzen AI (XDNA1/XDNA2): Ryzen 7040/8040/9000 series
            if ($cpuName -match 'Ryzen.*[78][0-9]{2}[0-9]U|Ryzen.*9[0-9]{2}[0-9][A-Z]|Ryzen.*AI' -or
                $cpuName -match 'Ryzen.*[89][0-9]{3}H') {
                $hasNpu       = $true
                $npuVendor    = 'AMD'
                $npuDeviceName = 'AMD XDNA NPU (heuristica por CPU)'  
            }
            # Intel Core Ultra (Meteor Lake = MTL, Arrow Lake = ARL): Intel AI Boost
            elseif ($cpuName -match 'Core.*Ultra [1-9][0-9]{2}') {
                $hasNpu       = $true
                $npuVendor    = 'Intel'
                $npuDeviceName = 'Intel AI Boost NPU (heuristica por CPU)'
            }
            # Qualcomm Snapdragon X Elite / Plus
            elseif ($cpuName -match 'Snapdragon X') {
                $hasNpu       = $true
                $npuVendor    = 'Qualcomm'
                $npuDeviceName = 'Qualcomm Hexagon NPU (heuristica por CPU)'
            }
        }
    } catch {
        # Get-PnpDevice puede no estar disponible en WinPE o entornos minimos
        $hasNpu = $false
    }

    # =========================================================================
    $isIsoOptimized = $false
    try {
        $cloudPol  = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -ErrorAction SilentlyContinue
        $tpmBypass = Get-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassTPMCheck" -ErrorAction SilentlyContinue
        if (($cloudPol -and $cloudPol.DisableWindowsConsumerFeatures -eq 1) -or ($tpmBypass -and $tpmBypass.BypassTPMCheck -eq 1)) {
            $isIsoOptimized = $true
        }
    } catch {
        Write-Warning "[Hardware-Engine] Error comprobando claves de optimización ISO: $($_.Exception.Message)"
    }

    $profileId   = ''
    $profileName = ''

    if ($isLaptop) {
        if     ($isLowRAM -and $isHDD) { $profileId = 'NOTEBOOK_LOWRAM_HDD'; $profileName = 'NOTEBOOK LIMITADA (HDD + <=4GB RAM)' }
        elseif ($isLowRAM)             { $profileId = 'NOTEBOOK_LOWRAM_SSD'; $profileName = 'NOTEBOOK LIMITADA (SSD + <=4GB RAM)' }
        elseif ($isHDD)                { $profileId = 'NOTEBOOK_HDD';        $profileName = 'NOTEBOOK HDD' }
        elseif ($hasDedicatedGpu)      { $profileId = 'NOTEBOOK_GAMING';     $profileName = 'NOTEBOOK GAMING (GPU dedicada)' }
        else                           { $profileId = 'NOTEBOOK';            $profileName = 'NOTEBOOK' }
    } else {
        if     ($isLowRAM -and $isHDD) { $profileId = 'DESKTOP_LOWRAM_HDD'; $profileName = 'PC ESCRITORIO LIMITADA (HDD + <=4GB RAM)' }
        elseif ($isLowRAM)             { $profileId = 'DESKTOP_LOWRAM';     $profileName = 'PC ESCRITORIO CON POCA RAM (<=4GB)' }
        elseif ($isHDD)                { $profileId = 'DESKTOP_HDD';        $profileName = 'PC ESCRITORIO HDD' }
        elseif ($hasDedicatedGpu)      { $profileId = 'DESKTOP_GAMING';     $profileName = 'PC GAMING (GPU dedicada)' }
        else                           { $profileId = 'DESKTOP';            $profileName = 'PC ESCRITORIO' }
    }

    # =========================================================================
    # CONSTRUCCION DEL OBJETO ESTRUCTURADO FINAL
    # =========================================================================
    $profileObj = [PSCustomObject]@{
        Platform = [PSCustomObject]@{
            IsLaptop             = $isLaptop
            IsDesktop            = $isDesktop
            IsServer             = $isServer
            IsVirtualMachine     = $isVM
            VmType               = $vmType
            ChassisTypes         = $chassisTypes
            ChassisDescription   = $chassisDesc
            HasBattery           = $hasBattery
            HasModernStandby     = $hasModernStandby
            PlatformSource       = $laptopSrc
            ComputerManufacturer = $compManufacturer
            ComputerModel        = $compModel
            SystemFamily         = $systemFamily
        }
        CPU = [PSCustomObject]@{
            Name                 = $cpuName
            Vendor               = $cpuVendor
            Cores                = $cpuCores
            Threads              = $cpuThreads
            MaxClockMHz          = $cpuMHz
            IsModern             = $isModernCPU
            IsHybrid             = $isHybridCPU
            IsEcoreOnly          = $isEcoreOnly
            IsLegacyIntel        = $isLegacyIntel
            IsIntelXeon          = $isIntelXeon
            IsDualCcdX3D         = $isDualCcdX3D
            IsLowEnd             = $isLowEndCPU
            IsARM64              = ($cpuVendor -eq 'ARM' -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64')
            IdleTempC            = $cpuTempC
            IdleTempWarn         = $cpuTempWarn
        }
        RAM = [PSCustomObject]@{
            TotalBytes           = $ramBytes
            TotalGiB             = $ramGiB
            IsLowRAM             = $isLowRAM
            ModuleCount          = $moduleCount
            ChannelCount         = $channelCount
            IsSingleChannel      = $isSingleChan
            ChannelMode          = $channelModeStr
            MemoryType           = $memoryTypeStr
            SpeedMHz             = $ramSpeedMHz
        }
        Disk = [PSCustomObject]@{
            BootDiskNumber       = $bootDiskNumber
            BootBusType          = $diskBusType
            BootMediaType        = $diskMediaType
            BootModel            = $bootModel
            IsNVMe               = $isNVMe
            IsSATA               = $isSATA
            IsHDD                = $isHDD
            IsSSD                = $isSSD
            DiskLabel            = $diskLabel
            IsDirectStorageReady = $isBypassIOSupported
            DirectStorageStatus  = $directStorageStatus
        }
        GPU = [PSCustomObject]@{
            Devices              = @($gpuDevices)
            PrimaryGpu           = $primaryGpu
            HasDedicatedGpu      = $hasDedicatedGpu
            HasIntegratedGpu     = $hasIntegratedGpu
            HasNvidia            = $hasNvidiaGpu
            HasAmd               = $hasAmdGpu
            HasIntelArc          = $hasIntelArcGpu
            HasVirtualGpu        = $hasVirtualGpu
            HasRdna3Igpu         = $hasRdna3Igpu
            GpuSummary           = $gpuSummary
        }
        NPU = [PSCustomObject]@{
            HasNpu               = $hasNpu
            Vendor               = $npuVendor
            DeviceName           = $npuDeviceName
            Devices              = @($npuDevices)
            IsAiPc               = $hasNpu
        }
        Profile = [PSCustomObject]@{
            Id                   = $profileId
            DisplayName          = $profileName
            IsIsoOptimized       = $isIsoOptimized
        }
    }

    $script:CachedHardwareProfile = $profileObj
    return $profileObj
}

# -----------------------------------------------------------------------------
# FUNCION DE FORMATEO: Format-HardwareSummary
# -----------------------------------------------------------------------------

function Format-HardwareSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Profile
    )

    if ($null -eq $Profile) {
        $Profile = Get-SystemHardwareProfile
    }

    $w = 59
    $border = "-" * $w

    Write-Host "  +$border+" -ForegroundColor DarkCyan
    Write-Host "  |           RESUMEN DE HARDWARE DETECTADO                 |" -ForegroundColor Cyan
    Write-Host "  +$border+" -ForegroundColor DarkCyan

    Write-Host ("  | Perfil    : {0,-41} |" -f $Profile.Profile.DisplayName) -ForegroundColor White

    # CPU
    $cpuDisplay = $Profile.CPU.Name
    if ($cpuDisplay.Length -gt 41) { $cpuDisplay = $cpuDisplay.Substring(0, 38) + '...' }
    Write-Host ("  | CPU       : {0,-41} |" -f $cpuDisplay) -ForegroundColor Gray
    Write-Host ("  | Nucleos   : {0,-41} |" -f "$($Profile.CPU.Cores)C / $($Profile.CPU.Threads)T @ $($Profile.CPU.MaxClockMHz) MHz") -ForegroundColor Gray

    # RAM
    $ramDesc = "$($Profile.RAM.TotalGiB) GiB $($Profile.RAM.MemoryType)"
    if ($Profile.RAM.SpeedMHz -gt 0) { $ramDesc += " @ $($Profile.RAM.SpeedMHz)MHz" }
    if ($Profile.RAM.IsLowRAM)       { $ramDesc += " [<=4GB]" }
    Write-Host ("  | RAM       : {0,-41} |" -f $ramDesc) -ForegroundColor $(if($Profile.RAM.IsLowRAM){'Yellow'}else{'Gray'})
    Write-Host ("  | RAM Canal : {0,-41} |" -f "$($Profile.RAM.ChannelMode) ($($Profile.RAM.ModuleCount) modulos)") -ForegroundColor $(if($Profile.RAM.IsSingleChannel){'Yellow'}else{'Gray'})

    # Disco
    $diskDisplay = "$($Profile.Disk.DiskLabel) ($($Profile.Disk.BootBusType))"
    if ($Profile.Disk.IsHDD)  { $diskDisplay += " -- I/O lento" }
    if ($Profile.Disk.IsNVMe) { $diskDisplay += " -- Alta velocidad" }
    if ($diskDisplay.Length -gt 41) { $diskDisplay = $diskDisplay.Substring(0, 38) + '...' }
    Write-Host ("  | Disco     : {0,-41} |" -f $diskDisplay) -ForegroundColor $(if($Profile.Disk.IsHDD){'Yellow'}else{'Gray'})

    # GPU
    $gpuDisplay = $Profile.GPU.GpuSummary
    if ($gpuDisplay.Length -gt 41) { $gpuDisplay = $gpuDisplay.Substring(0, 38) + '...' }
    Write-Host ("  | GPU       : {0,-41} |" -f $gpuDisplay) -ForegroundColor Gray

    # CPU Gen
    $cpuGenStr = if ($Profile.CPU.IsModern) {
        'MODERNA (12th+/Ryzen5k+)'
    } elseif ($Profile.CPU.IsLowEnd) {
        'LOW-END / BASICA'
    } else {
        'GENERACION MEDIA'
    }
    Write-Host ("  | CPU Gen   : {0,-41} |" -f $cpuGenStr) -ForegroundColor Gray

    # Temp CPU
    if ($null -ne $Profile.CPU.IdleTempC) {
        $tempLabel = "$($Profile.CPU.IdleTempC) C$(if($Profile.CPU.IdleTempWarn){' -- ALERTA IDLE'})"
        Write-Host ("  | Temp CPU  : {0,-41} |" -f $tempLabel) -ForegroundColor $(if($Profile.CPU.IdleTempWarn){'Red'}else{'Gray'})
    }

    # Tipo / Chasis
    $platSrc = $Profile.Platform.PlatformSource
    if ($platSrc.Length -gt 41) { $platSrc = $platSrc.Substring(0, 38) + '...' }
    Write-Host ("  | Tipo      : {0,-41} |" -f $platSrc) -ForegroundColor Gray

    # Modern Standby
    if ($Profile.Platform.IsLaptop -and $Profile.Platform.HasModernStandby) {
        Write-Host ("  | Power Arch: {0,-41} |" -f "Modern Standby (S0 Low Power Idle)") -ForegroundColor Cyan
    }

    # DirectStorage
    if ($Profile.Disk.IsNVMe) {
        Write-Host ("  | DirectStor: {0,-41} |" -f $Profile.Disk.DirectStorageStatus) -ForegroundColor $(if($Profile.Disk.IsDirectStorageReady){'Green'}else{'Gray'})
    }

    # NPU / AI PC (PLAN-0048)
    if ($Profile.NPU.HasNpu) {
        $npuDisplay = "$($Profile.NPU.Vendor) NPU"
        if ($Profile.NPU.DeviceName -and $Profile.NPU.DeviceName -ne '') {
            $npuShort = if ($Profile.NPU.DeviceName.Length -gt 30) { $Profile.NPU.DeviceName.Substring(0,27) + '...' } else { $Profile.NPU.DeviceName }
            $npuDisplay = "$npuShort"
        }
        Write-Host ("  | NPU (AI)  : {0,-41} |" -f $npuDisplay) -ForegroundColor Cyan
        Write-Host ("  | AI PC     : {0,-41} |" -f "SI - Plataforma AI PC Certificada") -ForegroundColor Green
    }

    # RDNA3 iGPU
    if ($Profile.GPU.HasRdna3Igpu) {
        Write-Host ("  | iGPU Tipo : {0,-41} |" -f "RDNA3/3.5 (HAGS + MSI Mode aplicable)") -ForegroundColor Cyan
    }

    # Base ISO
    if ($Profile.Profile.IsIsoOptimized) {
        Write-Host ("  | Base ISO  : {0,-41} |" -f "Pre-optimizada por OptimizedISO [OK]") -ForegroundColor Green
    }

    Write-Host "  +$border+" -ForegroundColor DarkCyan
    Write-Host ""
}

# -----------------------------------------------------------------------------
# FUNCION DE APLICACION: Enable-GpuMsiMode
# -----------------------------------------------------------------------------

function Enable-GpuMsiMode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$HardwareProfile
    )

    if ($null -eq $HardwareProfile) {
        $HardwareProfile = Get-SystemHardwareProfile
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $candidateGpus = $HardwareProfile.GPU.Devices | Where-Object { $_.SupportsMSI }

    if (-not $candidateGpus -or $candidateGpus.Count -eq 0) {
        Write-Host "  [12.H] MSI Mode: omitido (no hay GPU PCIe compatible detectada)." -ForegroundColor Gray
        return $results
    }

    Write-Host "  [12.H] Enabling MSI Mode for PCI Express GPU(s)..." -ForegroundColor Gray

    foreach ($g in $candidateGpus) {
        $pnpId = $g.PNPDeviceID
        if (-not $pnpId) {
            Write-Host "    ! PNPDeviceID no disponible para $($g.Name)." -ForegroundColor Yellow
            $results.Add([PSCustomObject]@{ Device = $g.Name; Status = "NO_PNPID"; Changed = $false })
            continue
        }

        $baseRegPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters"
        $regPath     = "$baseRegPath\Interrupt Management\MessageSignaledInterruptProperties"

        if (Test-Path $baseRegPath) {
            try {
                $existingMSI = $null
                if (Test-Path $regPath) {
                    $existingMSI = (Get-ItemProperty -Path $regPath -Name 'MSISupported' -ErrorAction SilentlyContinue).MSISupported
                }

                if ($null -ne $existingMSI -and $existingMSI -eq 1) {
                    Write-Host "    - MSI Mode ya estaba habilitado para: $($g.Name) [Vendor: $($g.VendorName)] (sin cambios)." -ForegroundColor Gray
                    $results.Add([PSCustomObject]@{ Device = $g.Name; Status = "ALREADY_ENABLED"; Changed = $false })
                } else {
                    if (-not (Test-Path "$baseRegPath\Interrupt Management")) {
                        New-Item -Path "$baseRegPath\Interrupt Management" -ErrorAction SilentlyContinue | Out-Null
                    }
                    if (-not (Test-Path $regPath)) {
                        New-Item -Path $regPath -Force | Out-Null
                    }
                    New-ItemProperty -Path $regPath -Name 'MSISupported' -Value 1 -PropertyType DWord -Force | Out-Null
                    Write-Host "    - MSI Mode habilitado con exito para: $($g.Name) [Vendor: $($g.VendorName)]" -ForegroundColor Green
                    Write-Host "      PNPDeviceID: $pnpId" -ForegroundColor DarkGray
                    $results.Add([PSCustomObject]@{ Device = $g.Name; Status = "ENABLED"; Changed = $true })
                }
            } catch {
                Write-Host "    ! Error al configurar MSI Mode para $($g.Name): $($_.Exception.Message)" -ForegroundColor Yellow
                $results.Add([PSCustomObject]@{ Device = $g.Name; Status = "ERROR"; Detail = $_.Exception.Message; Changed = $false })
            }
        } else {
            Write-Host "    ! Subclave 'Device Parameters' no encontrada para $($g.Name)." -ForegroundColor Yellow
            $results.Add([PSCustomObject]@{ Device = $g.Name; Status = "NO_DEV_PARAMS"; Changed = $false })
        }
    }

    $appliedCount = @($results | Where-Object { $_.Changed }).Count
    if ($appliedCount -gt 0) {
        Write-Host "    MSI Mode requiere reinicio del sistema para activarse en el driver." -ForegroundColor Green
    }

    return $results
}

# -----------------------------------------------------------------------------
# FUNCION DE VERIFICACION: Test-HagsSupport
# -----------------------------------------------------------------------------

function Test-HagsSupport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$HardwareProfile
    )

    if ($null -eq $HardwareProfile) {
        $HardwareProfile = Get-SystemHardwareProfile
    }

    # 1. Comprobar si el registro ya tiene HwSchMode configurado o expuesto por el driver
    $hwSchKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
    $currentHwSch = (Get-ItemProperty -Path $hwSchKey -Name 'HwSchMode' -ErrorAction SilentlyContinue).HwSchMode
    if ($null -ne $currentHwSch) {
        return $true
    }

    # 2. Comprobar si alguna GPU dedicada soporta HAGS por driver WDDM 2.7+ y arquitectura
    $hagsGpu = $HardwareProfile.GPU.Devices | Where-Object { $_.SupportsHAGS } | Select-Object -First 1
    if ($null -ne $hagsGpu) {
        return $true
    }

    return $false
}

# -----------------------------------------------------------------------------
# FUNCION AUXILIAR CANONICA: Resolve-SystemBinary
# Resuelve binarios nativos del sistema protegiendo contra redireccion WOW64
# (Sysnative vs System32) en entornos de 32 bits ejecutando sobre SO de 64 bits.
# -----------------------------------------------------------------------------

function Resolve-SystemBinary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BinaryName
    )

    $sysDir = if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        "$env:SystemRoot\Sysnative"
    } else {
        "$env:SystemRoot\System32"
    }

    $fullPath = Join-Path $sysDir $BinaryName
    if (Test-Path $fullPath) {
        return $fullPath
    }

    $fallbackPath = Join-Path "$env:SystemRoot\System32" $BinaryName
    if (Test-Path $fallbackPath) {
        return $fallbackPath
    }

    return $BinaryName
}

# -----------------------------------------------------------------------------
# FUNCIONES AVANZADAS RUPA 2026: BypassIO, Red NDIS y Memoria Escalonada
# -----------------------------------------------------------------------------

function Test-RomanOSBypassIoState {
    <#
    .SYNOPSIS
        Evalua el estado de BypassIO para DirectStorage 1.2+ en el volumen especificado.
    .PARAMETER VolumePath
        Ruta o letra de unidad a evaluar (ej: "C:\"). Por defecto usa SystemDrive.
    #>
    [CmdletBinding()]
    param(
        [string]$VolumePath
    )

    if (-not $VolumePath) {
        $VolumePath = if ($env:SystemDrive) { "$($env:SystemDrive)\" } else { "C:\" }
    }

    $res = [PSCustomObject]@{
        VolumePath           = $VolumePath
        IsSupported          = $false
        StatusReason         = "No evaluado"
        BlockingMinifilters  = @()
        BitLockerCompatible  = $true
        RawOutput            = ""
    }

    $fsutilPath = Resolve-SystemBinary -BinaryName "fsutil.exe"
    if (Test-Path $fsutilPath) {
        try {
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = $fsutilPath
            $pinfo.Arguments = "bypassIo state /v `"$VolumePath`""
            $pinfo.RedirectStandardOutput = $true
            $pinfo.RedirectStandardError = $true
            $pinfo.UseShellExecute = $false
            $pinfo.CreateNoWindow = $true

            $proc = [System.Diagnostics.Process]::Start($pinfo)
            $stdout = $proc.StandardOutput.ReadToEnd()
            $stderr = $proc.StandardError.ReadToEnd()
            $proc.WaitForExit(5000) | Out-Null

            $combined = ($stdout + "`n" + $stderr).Trim()
            $res.RawOutput = $combined

            if ($combined -match 'BypassIo is supported' -or $combined -match 'BypassIo is enabled') {
                $res.IsSupported = $true
                $res.StatusReason = "BypassIO Soportado y Activo"
            } elseif ($combined -match 'Acceso denegado' -or $combined -match 'Access is denied' -or $proc.ExitCode -eq 5) {
                $res.StatusReason = "Requiere elevacion de Administrador para consultar fsutil"
            } else {
                if ($combined -match 'Reason:\s*(.+)') {
                    $res.StatusReason = $matches[1].Trim()
                } else {
                    $res.StatusReason = "BypassIO no habilitado en el volumen"
                }

                $lines = $combined -split "`r?`n"
                $filtersFound = [System.Collections.Generic.List[string]]::new()
                foreach ($line in $lines) {
                    if ($line -match 'Driver:\s*([a-zA-Z0-9_\-\.]+)') {
                        $filtersFound.Add($matches[1].Trim())
                    }
                }
                $res.BlockingMinifilters = @($filtersFound)
            }
        } catch {
            Write-Warning "[Hardware-Engine] Error ejecutando fsutil bypassIo: $($_.Exception.Message)"
            $res.StatusReason = "Excepcion al invocar fsutil: $($_.Exception.Message)"
        }
    } else {
        $res.StatusReason = "fsutil.exe no encontrado en el sistema"
    }

    return $res
}

function Get-RomanOSNetworkOffloadCaps {
    <#
    .SYNOPSIS
        Audita las capacidades de descarga por hardware (UDP RSC/URO, RSS, Checksums) de los adaptadores de red.
    #>
    [CmdletBinding()]
    param()

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    try {
        $adapters = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.HardwareInterface -eq $true -and $_.Status -ne 'Disabled' }
        foreach ($nic in $adapters) {
            $nicName = $nic.Name
            $desc = $nic.InterfaceDescription
            
            $hasUdpRsc = $false
            $udpRscVal = "N/A"
            $hasRsc = $false
            $hasRss = $false
            $rssQueues = 0
            $intMod = "N/A"
            $flowCtrl = "N/A"

            try {
                $advProps = Get-NetAdapterAdvancedProperty -Name $nicName -ErrorAction SilentlyContinue
                if ($advProps) {
                    foreach ($prop in $advProps) {
                        if ($prop.RegistryKeyword -eq "*UdpRsc") {
                            $hasUdpRsc = $true
                            $udpRscVal = if ($prop.RegistryValue -contains "1") { "Enabled" } else { "Disabled" }
                        }
                        if ($prop.RegistryKeyword -match '\*Rsc') {
                            $hasRsc = $true
                        }
                        if ($prop.RegistryKeyword -eq "*InterruptModeration") {
                            $intMod = if ($prop.RegistryValue -contains "0") { "Disabled" } else { "Enabled" }
                        }
                        if ($prop.RegistryKeyword -eq "*FlowControl") {
                            $flowCtrl = if ($prop.RegistryValue -contains "0") { "Disabled" } else { "Enabled" }
                        }
                    }
                }
            } catch {
                Write-Warning "[Hardware-Engine] No se pudieron leer propiedades avanzadas de '$nicName': $($_.Exception.Message)"
            }

            try {
                $rss = Get-NetAdapterRss -Name $nicName -ErrorAction SilentlyContinue
                if ($rss) {
                    $hasRss = ($rss.Enabled -eq $true)
                    $rssQueues = $rss.NumberOfReceiveQueues
                }
            } catch {
                Write-Warning "[Hardware-Engine] No se pudo leer RSS de '$nicName': $($_.Exception.Message)"
            }

            $results.Add([PSCustomObject]@{
                Name                = $nicName
                InterfaceDesc       = $desc
                Status              = $nic.Status
                LinkSpeed           = $nic.LinkSpeed
                SupportsUdpRsc      = $hasUdpRsc
                UdpRscState         = $udpRscVal
                SupportsRsc         = $hasRsc
                SupportsRss         = $hasRss
                RssQueues           = $rssQueues
                InterruptModeration = $intMod
                FlowControl         = $flowCtrl
            })
        }
    } catch {
        Write-Warning "[Hardware-Engine] Error obteniendo adaptadores de red: $($_.Exception.Message)"
    }

    return ,$results.ToArray()
}

function Get-RomanOSMemoryTier {
    <#
    .SYNOPSIS
        Clasifica la memoria RAM fisica en tiers (Low, Balanced, Enthusiast) y prescribe ajustes optimos.
    #>
    [CmdletBinding()]
    param(
        [double]$RamGiB = 0
    )

    if ($RamGiB -le 0) {
        try {
            $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
            $RamGiB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        } catch {
            Write-Warning "[Hardware-Engine] Error leyendo Win32_ComputerSystem: $($_.Exception.Message)"
            $RamGiB = 16.0
        }
    }

    $tier = if ($RamGiB -lt 8.0) {
        "Low"
    } elseif ($RamGiB -le 16.0) {
        "Balanced"
    } else {
        "Enthusiast"
    }

    $recommended = [PSCustomObject]@{
        Tier                   = $tier
        TotalGiB               = $RamGiB
        DisablePagingExecutive = if ($tier -eq "Low") { 0 } else { 1 }
        LargeSystemCache       = if ($tier -eq "Enthusiast") { 1 } else { 0 }
        MemoryCompression      = if ($tier -eq "Enthusiast") { $false } else { $true }
        PageCombining          = if ($tier -eq "Low") { $true } else { $false }
        Rationale              = if ($tier -eq "Low") {
            "RAM reducida (<8GB): compresion y combinacion activas para prevenir fallos duros de pagina (OOM)"
        } elseif ($tier -eq "Balanced") {
            "RAM equilibrada (8-16GB): kernel bloqueado en RAM fisica sin paginado para eliminar micro-stutters"
        } else {
            "RAM abundante (>16GB): compresion de memoria desactivada para reducir latencia DPC y consumo de ciclos de CPU"
        }
    }

    return $recommended
}


