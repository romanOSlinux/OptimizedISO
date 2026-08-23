<#
.SYNOPSIS
    Crea, configura e inicia una Máquina Virtual de prueba en Hyper-V (Gen 2 UEFI + TPM 2.0).

.DESCRIPTION
    Automatiza el despliegue de una máquina virtual de prueba en Hyper-V para verificar
    el arranque desatendido de imágenes ISO optimizadas de Windows 10 y Windows 11.
    
    Características clave:
    - Validación de privilegios de Administrador y disponibilidad del rol Hyper-V.
    - Detección y resolución automática de la ISO más reciente si no se especifica ruta.
    - Generación 2 (UEFI x64) con soporte completo para Windows 11 (TPM 2.0 virtual y Secure Boot).
    - Asignación inteligente de conmutador de red virtual (Virtual Switch).
    - Limpieza automática de versiones previas de la VM y su disco VHDX.
    - Secuencia de arranque optimizada: abre la consola VMConnect antes del arranque para evitar
      timeouts de detección del teclado ("The boot loader failed").

.PARAMETER ISOPath
    Ruta completa a la imagen ISO a probar. Si se omite, el script busca automáticamente la ISO más reciente
    en el escritorio y en los directorios de salida del proyecto.

.PARAMETER VMName
    Nombre de la máquina virtual en Hyper-V. (Default: "Test_Optimized_Win11")

.PARAMETER VMDir
    Directorio donde se almacenarán los archivos y disco VHDX de la VM. (Default: "$HOME\Virtual Machines")

.PARAMETER MemoryGB
    Memoria RAM asignada en Gigabytes. (Default: 4)

.PARAMETER CPUCount
    Cantidad de núcleos/procesadores virtuales asignados. (Default: 4)

.PARAMETER DiskSizeGB
    Tamaño máximo del disco duro virtual dinámico (VHDX) en Gigabytes. (Default: 60)

.PARAMETER SwitchName
    Nombre del conmutador virtual de Hyper-V. Si no se especifica, usa el primer conmutador disponible o "Default Switch".

.PARAMETER DisableSecureBoot
    Deshabilita el arranque seguro (Secure Boot) si se requiere probar ISOs con gestores de arranque modificados.

.PARAMETER NoAutoStart
    Crea y configura la VM pero no la inicia automáticamente.

.EXAMPLE
    .\New-TestVM-HyperV.ps1
    .\New-TestVM-HyperV.ps1 -ISOPath "C:\Salida\Windows_11_Optimized.iso"
    .\New-TestVM-HyperV.ps1 -VMName "Win11_Test" -MemoryGB 8 -CPUCount 6
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ISOPath = "",

    [Parameter()]
    [string]$VMName = "Test_Optimized_Win11",

    [Parameter()]
    [string]$VMDir = "$HOME\Virtual Machines",

    [Parameter()]
    [int]$MemoryGB = 4,

    [Parameter()]
    [int]$CPUCount = 4,

    [Parameter()]
    [int]$DiskSizeGB = 60,

    [Parameter()]
    [string]$SwitchName = "",

    [Parameter()]
    [switch]$DisableSecureBoot,

    [Parameter()]
    [switch]$NoAutoStart
)

Set-StrictMode -Off
$ErrorActionPreference = 'Stop'

# Funciones de salida visual
function Write-VMInfo  { param([string]$Msg) Write-Host "  [*] $Msg" -ForegroundColor Cyan }
function Write-VMOK    { param([string]$Msg) Write-Host "  [+] $Msg" -ForegroundColor Green }
function Write-VMWarn  { param([string]$Msg) Write-Host "  [!] $Msg" -ForegroundColor Yellow }
function Write-VMFail  { param([string]$Msg) Write-Host "  [-] $Msg" -ForegroundColor Red }

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   DESPLIEGUE AUTOMATIZADO DE VM EN HYPER-V (GEN 2 / UEFI)     " -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 1. Validar Privilegios de Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-VMFail "Este script requiere ejecutarse con privilegios de Administrador para gestionar Hyper-V."
    Write-VMWarn "Por favor, abre PowerShell como Administrador y vuelve a ejecutar el script."
    exit 1
}

# 2. Validar que el módulo y servicio Hyper-V estén disponibles
if (-not (Get-Command "New-VM" -ErrorAction SilentlyContinue)) {
    Write-VMFail "Los cmdlets de Hyper-V no están disponibles en este sistema."
    Write-VMWarn "Asegúrate de tener habilitada la característica de Hyper-V:"
    Write-Host "    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All" -ForegroundColor DarkGray
    exit 1
}

$vmmsService = Get-Service -Name "vmms" -ErrorAction SilentlyContinue
if (-not $vmmsService -or $vmmsService.Status -ne 'Running') {
    Write-VMWarn "El servicio de administración de Hyper-V (vmms) no está iniciado. Intentando iniciar..."
    try {
        Start-Service -Name "vmms" -ErrorAction Stop
        Write-VMOK "Servicio vmms iniciado correctamente."
    } catch {
        Write-VMFail "No se pudo iniciar el servicio vmms: $($_.Exception.Message)"
        exit 1
    }
}

# 3. Resolver Ruta de la ISO
if (-not $ISOPath) {
    Write-VMInfo "Buscando la imagen ISO más reciente en ubicaciones habituales..."
    $searchDirs = @(
        "$HOME\Desktop\WinISO_Optimizado",
        "C:\OptimizedISO\Output",
        "C:\OptimizedISO",
        "$HOME\Downloads\Windows_ISOs",
        "$HOME\Downloads",
        "$HOME\Desktop"
    )

    $foundIsos = foreach ($d in $searchDirs) {
        if (Test-Path $d) {
            Get-ChildItem -Path $d -Filter "*.iso" -File -ErrorAction SilentlyContinue
        }
    }

    $latestIso = $foundIsos | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($latestIso) {
        $ISOPath = $latestIso.FullName
        Write-VMOK "ISO detectada automáticamente: $ISOPath ($([math]::Round($latestIso.Length / 1GB, 2)) GB)"
    } else {
        Write-VMFail "No se especificó -ISOPath y no se encontró ninguna ISO en las carpetas habituales."
        Write-Host "    Uso: .\New-TestVM-HyperV.ps1 -ISOPath 'C:\Ruta\Tu_Imagen.iso'" -ForegroundColor Yellow
        exit 1
    }
}

if (-not (Test-Path $ISOPath)) {
    Write-VMFail "El archivo ISO especificado no existe: $ISOPath"
    exit 1
}

# 4. Asegurar Directorio de la VM y Ruta de Disco VHDX
if (-not (Test-Path $VMDir)) {
    New-Item -ItemType Directory -Path $VMDir -Force | Out-Null
    Write-VMOK "Directorio creado: $VMDir"
}

$vhdPath = Join-Path $VMDir "$VMName.vhdx"

# 5. Limpieza Segura de VM y VHDX Preexistentes
$existingVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
if ($existingVM) {
    Write-VMWarn "La máquina virtual '$VMName' ya existe. Limpiando instancia previa..."
    if ($existingVM.State -ne 'Off') {
        Stop-VM -Name $VMName -TurnOff -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
    Remove-VM -Name $VMName -Force -ErrorAction SilentlyContinue
    Write-VMOK "VM previa eliminada."
}

if (Test-Path $vhdPath) {
    Remove-Item -Path $vhdPath -Force -ErrorAction SilentlyContinue
    Write-VMOK "Disco VHDX anterior eliminado."
}

# 6. Selección de Conmutador de Red Virtual (Switch)
$resolvedSwitch = $null
if ($SwitchName) {
    $resolvedSwitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
    if (-not $resolvedSwitch) {
        Write-VMWarn "Conmutador '$SwitchName' no encontrado. Buscando alternativa..."
    }
}

if (-not $resolvedSwitch) {
    $allSwitches = Get-VMSwitch -ErrorAction SilentlyContinue
    $resolvedSwitch = $allSwitches | Where-Object { $_.Name -like "*Default*" } | Select-Object -First 1
    if (-not $resolvedSwitch) {
        $resolvedSwitch = $allSwitches | Select-Object -First 1
    }
}

$switchParam = @{}
if ($resolvedSwitch) {
    $switchParam["SwitchName"] = $resolvedSwitch.Name
    Write-VMInfo "Conmutador de red asignado: $($resolvedSwitch.Name)"
} else {
    Write-VMWarn "No se detectaron conmutadores virtuales de Hyper-V. La VM se creará sin conexión de red inicial."
}

# 7. Creación de la Máquina Virtual Generación 2 (UEFI)
Write-VMInfo "Creando VM '$VMName' (Gen 2 UEFI, ${MemoryGB}GB RAM, ${DiskSizeGB}GB Disco)..."
$memBytes = [int64]$MemoryGB * 1GB
$diskBytes = [int64]$DiskSizeGB * 1GB

New-VM -Name $VMName `
       -MemoryStartupBytes $memBytes `
       -Generation 2 `
       -NewVHDPath $vhdPath `
       -NewVHDSizeBytes $diskBytes `
       @switchParam | Out-Null

Write-VMOK "VM base creada exitosamente."

# 8. Configuración de Hardware (CPU, Memoria Fija, TPM 2.0, Secure Boot)
Write-VMInfo "Configurando hardware y seguridad para Windows 11..."
Set-VMProcessor -VMName $VMName -Count $CPUCount
Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false

try {
    Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector -ErrorAction Stop
    Enable-VMTPM -VMName $VMName -ErrorAction Stop
    Write-VMOK "TPM 2.0 virtual habilitado con KeyProtector local."
} catch {
    Write-VMWarn "No se pudo habilitar TPM virtual: $($_.Exception.Message)"
}

if ($DisableSecureBoot) {
    Set-VMFirmware -VMName $VMName -EnableSecureBoot Off
    Write-VMWarn "Secure Boot deshabilitado explícitamente (-DisableSecureBoot)."
} else {
    Set-VMFirmware -VMName $VMName -EnableSecureBoot On -SecureBootTemplate "MicrosoftWindows"
    Write-VMOK "Secure Boot habilitado (Plantilla: MicrosoftWindows)."
}

# 9. Conectar ISO al DVD Virtual y Configurar Primer Dispositivo de Arranque
Write-VMInfo "Montando ISO como unidad de DVD virtual..."
Add-VMDvdDrive -VMName $VMName -Path $ISOPath
$dvdDrive = Get-VMDvdDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -FirstBootDevice $dvdDrive
Write-VMOK "DVD configurado como primer dispositivo de arranque (UEFI Boot)."

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "   MÁQUINA VIRTUAL CONFIGURADA Y LISTA PARA PRUEBAS             " -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Nombre de la VM : $VMName" -ForegroundColor White
Write-Host "  Generación      : Generación 2 (UEFI x64)" -ForegroundColor White
Write-Host "  CPU / RAM       : $CPUCount vCPUs / ${MemoryGB} GB RAM" -ForegroundColor White
Write-Host "  Disco VHDX      : $vhdPath (${DiskSizeGB} GB)" -ForegroundColor White
Write-Host "  Imagen ISO      : $ISOPath" -ForegroundColor White
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

# 10. Lanzamiento de Consola y Arranque
if (-not $NoAutoStart) {
    Write-VMInfo "Abriendo consola VMConnect..."
    Start-Process -FilePath "vmconnect.exe" -ArgumentList @("localhost", $VMName)

    # Pausa breve para permitir que la ventana de conexión capture foco antes del arranque
    Write-VMInfo "Iniciando máquina virtual en 2 segundos..."
    Start-Sleep -Seconds 2

    Start-VM -Name $VMName
    Write-VMOK "Máquina virtual '$VMName' iniciada."
    Write-Host ""
    Write-Host "  [TIP] Si la ISO usa cargador con prompt, presiona ESPACIO o ENTER en la ventana de la VM." -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-VMInfo "Arranque automático omitido (-NoAutoStart)."
    Write-Host "  Para iniciar manualmente:" -ForegroundColor Gray
    Write-Host "    Start-VM -Name `"$VMName`"; vmconnect.exe localhost `"$VMName`"" -ForegroundColor Yellow
}
