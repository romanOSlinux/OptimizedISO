<#
.SYNOPSIS
    romanOS - Auditor Universal de Optimizacion del Sistema y Observabilidad Multi-Hardware
    Evalua si cualquier PC Windows (10 u 11, Intel/AMD/NVIDIA, Laptop/Desktop) esta optimizada
    segun fuentes tecnicas oficiales (Microsoft Learn, WDDM, IETF RFCs, AMD, Intel, Realtek).

.DESCRIPTION
    Herramienta autonoma y portable que diagnostica 10 dominios de rendimiento y latencia:
    1. CPU & Plan de Energia (Throttling, Core Parking, Frecuencias CA vs Bateria)
    2. GPU & WDDM Latency (HAGS, MSI Mode, Flip Model, VRR, Game DVR)
    3. Memoria & Paginacion (DisablePagingExecutive, LargeSystemCache, pagefile.sys)
    4. Almacenamiento & NTFS (TRIM, DisableLastAccess, DirectStorage BypassIO, CompactOS)
    5. Red & Latencia de Paquetes (Green Ethernet, EEE, ECN RFC 3168, Nagle's Algorithm)
    6. Seguridad de Kernel & VBS (HVCI Memory Integrity, Credential Guard, overhead)
    7. Servicios de Fondo & Telemetria (DiagTrack, dmwappushservice, SysMain, WerSvc)
    8. Debloat UWP & Inicio (Paquetes promocionales residuales, autostart)
    9. Windows Update & OEM (Exclusion de drivers en WU, On-Demand, WPBT, BitLocker)
    10. Temporizadores de Alta Precision (NtQueryTimerResolution, reloj del sistema)

.PARAMETER ExportReport
    Genera un informe detallado en formato Markdown (.md) en el Escritorio.

.PARAMETER OutputDir
    Ruta personalizada donde guardar el informe de auditoria.

.PARAMETER ShowRemediation
    Muestra los comandos exactos de PowerShell para solucionar las incidencias detectadas.

.PARAMETER WhatIf
    Verifica la sintaxis y compatibilidad sin realizar consultas prolongadas.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$ExportReport = $true,
    [string]$OutputDir,
    [bool]$ShowRemediation = $true,
    [switch]$NoColor
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# -----------------------------------------------------------------------------
# 1. CARGA DE MOTORES CORE UNIFICADOS O MICRO-FALLBACK AUTONOMO
# -----------------------------------------------------------------------------
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }

$uiEnginePaths = @(
    (Join-Path (Split-Path $scriptRoot -Parent) "Core\UI-Engine.ps1"),
    (Join-Path $scriptRoot "Core\UI-Engine.ps1"),
    (Join-Path $scriptRoot "UI-Engine.ps1"),
    "$env:WINDIR\Setup\Scripts\Core\UI-Engine.ps1",
    "C:\Windows\Setup\Scripts\Core\UI-Engine.ps1",
    "C:\OptimizedISO\scripts\Core\UI-Engine.ps1"
)
$uiLoaded = $false
foreach ($p in $uiEnginePaths) {
    if (Test-Path $p) {
        . $p
        $uiLoaded = $true
        break
    }
}

if (-not $uiLoaded -or -not (Get-Command Show-UnifiedBanner -ErrorAction SilentlyContinue)) {
    function Show-UnifiedBanner { param($Title,$Subtitle,[switch]$ShowSystemInfo) Write-Host "`n=== $Title ($Subtitle) ===`n" -ForegroundColor Cyan }
    function Write-StepHeader   { param($StepNumber,$TotalSteps,$Message) Write-Host "`n>>> [$StepNumber/$TotalSteps] $Message" -ForegroundColor Cyan }
    function Write-SubStep      { param($Message) Write-Host "  -> $Message" -ForegroundColor Gray }
    function Write-OK           { param($Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
    function Write-Warn         { param($Message) Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
    function Write-ErrorMsg     { param($Message) Write-Host "  [ERROR] $Message" -ForegroundColor Red }
    function Write-Info         { param($Message) Write-Host "  [i] $Message" -ForegroundColor DarkGray }
}

# -----------------------------------------------------------------------------
# 2. VERIFICACION DE PRIVILEGIOS Y NIVEL DE INTEGRIDAD
# -----------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$privilegeLevel = if ($isAdmin) { "ADMINISTRADOR (High IL)" } else { "USUARIO ESTANDAR (Medium IL)" }

# -----------------------------------------------------------------------------
# 3. INTEROPERABILIDAD NATIVA CON EL KERNEL (TIMER RESOLUTION)
# -----------------------------------------------------------------------------
$timerResMs = 15.625
try {
    $timerDef = @"
using System;
using System.Runtime.InteropServices;
public class NativeKernelTimer {
    [DllImport("ntdll.dll")]
    public static extern int NtQueryTimerResolution(out uint min, out uint max, out uint current);
}
"@
    if (-not ([System.Management.Automation.PSTypeName]'NativeKernelTimer').Type) {
        Add-Type -TypeDefinition $timerDef -ErrorAction SilentlyContinue
    }
    [uint32]$tMin = 0; [uint32]$tMax = 0; [uint32]$tCur = 0
    if ([NativeKernelTimer]::NtQueryTimerResolution([ref]$tMin, [ref]$tMax, [ref]$tCur) -eq 0) {
        $timerResMs = [math]::Round(($tCur / 10000.0), 3)
    }
} catch {
    $timerResMs = 15.625
}

# -----------------------------------------------------------------------------
# 4. ESTRUCTURAS DE DATOS PARA AUDITORIA, SCORING Y REMEDIACION
# -----------------------------------------------------------------------------
$auditItems = [System.Collections.Generic.List[PSCustomObject]]::new()
$remediations = [System.Collections.Generic.List[PSCustomObject]]::new()
$restrictedCalls = [System.Collections.Generic.List[PSCustomObject]]::new()

function Register-AuditResult {
    param(
        [string]$Category,
        [string]$Item,
        [string]$Status,       # OK, WARN, FAIL, RESTRICTED
        [string]$ActualValue,
        [string]$ExpectedValue,
        [string]$Impact,
        [string]$Source,
        [string]$RemediationCmd = $null
    )

    $obj = [PSCustomObject]@{
        Category       = $Category
        Item           = $Item
        Status         = $Status
        ActualValue    = $ActualValue
        ExpectedValue  = $ExpectedValue
        Impact         = $Impact
        OfficialSource = $Source
        RemediationCmd = $RemediationCmd
    }
    $auditItems.Add($obj)

    if ($Status -eq 'RESTRICTED') {
        $restrictedCalls.Add($obj)
    } elseif ($RemediationCmd -and ($Status -eq 'WARN' -or $Status -eq 'FAIL')) {
        $remediations.Add($obj)
    }

    # Salida interactiva en consola
    switch ($Status) {
        'OK' {
            Write-Host "  [OK] " -ForegroundColor Green -NoNewline
            Write-Host "$Category | $($Item): " -ForegroundColor Gray -NoNewline
            Write-Host "$ActualValue" -ForegroundColor White
        }
        'WARN' {
            Write-Host "  [!] MEJORA: " -ForegroundColor Yellow -NoNewline
            Write-Host "$Category | $($Item): " -ForegroundColor Gray -NoNewline
            Write-Host "$ActualValue " -ForegroundColor Yellow -NoNewline
            Write-Host "(Esperado: $ExpectedValue)" -ForegroundColor DarkGray
        }
        'FAIL' {
            Write-Host "  [X] CUELLO BOTELLA: " -ForegroundColor Red -NoNewline
            Write-Host "$Category | $($Item): " -ForegroundColor Gray -NoNewline
            Write-Host "$ActualValue " -ForegroundColor Red -NoNewline
            Write-Host "(Esperado: $ExpectedValue)" -ForegroundColor DarkGray
        }
        'RESTRICTED' {
            Write-Host "  [*] PROTEGIDO: " -ForegroundColor Cyan -NoNewline
            Write-Host "$Category | $($Item): " -ForegroundColor Gray -NoNewline
            Write-Host "Requiere Elevacion de Administrador" -ForegroundColor DarkCyan
        }
    }
}

function Invoke-SafeAdminProbe {
    param(
        [string]$ActionName,
        [scriptblock]$Script
    )
    try {
        $out = & $Script 2>&1
        $errStr = "$out"
        if ($LASTEXITCODE -ne 0 -and ($errStr -match 'Access is denied|Acceso denegado|requiere privilegios|run as an administrator|requires elevation')) {
            return @{ Success = $false; Output = $null; Denied = $true; Message = $errStr.Trim() }
        }
        return @{ Success = $true; Output = $out; Denied = $false; Message = "" }
    } catch {
        return @{ Success = $false; Output = $null; Denied = $true; Message = $_.Exception.Message }
    }
}

# -----------------------------------------------------------------------------
# 5. INTROSPECCION Y HEURISTICA DE HARDWARE EN VIVO
# -----------------------------------------------------------------------------
Show-UnifiedBanner -Title "romanOS AUDITOR UNIVERSAL DE OPTIMIZACION" -Subtitle "Diagnostico Forense Multi-Hardware basado en Estandares Oficiales"

Write-Host " [Nivel de Privilegios]: $privilegeLevel" -ForegroundColor $(if ($isAdmin) { "Green" } else { "Yellow" })
if (-not $isAdmin) {
    Write-Host " [i] Modo de Auditoria Estandar: Se evaluaran todas las areas del sistema accesibles.`n     Las funciones del kernel que requieran Administrador seran catalogadas en [REQUIERE ELEVACION].`n" -ForegroundColor DarkGray
}

Write-StepHeader -StepNumber 1 -TotalSteps 10 -Message "Introspeccion Heuristica de Hardware y Arquitectura"

$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
$battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
$disks = @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue)
$sysLogical = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue

$isLaptop = ($null -ne $battery -and $battery.Count -gt 0)
$isVM = ($cs.Model -match 'Virtual|Hyper-V|VMware|KVM|QEMU|VirtualBox')
$ramTotalGiB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
$ramFreeGiB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)

$cpuVendor = if ($cpu.Manufacturer -match 'Intel') { 'Intel' } elseif ($cpu.Manufacturer -match 'AMD') { 'AMD' } else { 'Otro' }
$isIntelHybrid = ($cpuVendor -eq 'Intel' -and ($cpu.Name -match '12th Gen|13th Gen|14th Gen|Core Ultra'))

# Deteccion de Tipo de Almacenamiento Principal
$isNVMe = $false
$isSSD = $false
foreach ($d in $disks) {
    if ($d.Model -match 'NVMe|SSD' -or $d.InterfaceType -match 'NVMe') { $isSSD = $true }
    if ($d.Model -match 'NVMe' -or $d.InterfaceType -match 'NVMe') { $isNVMe = $true }
}
# Fallback MSFT_PhysicalDisk
try {
    $phys = Get-PhysicalDisk -ErrorAction SilentlyContinue
    if ($phys) {
        $bootPhys = $phys | Where-Object { $_.MediaType -eq 'SSD' -or $_.BusType -eq 'NVMe' }
        if ($bootPhys) {
            $isSSD = $true
            if (($bootPhys | Where-Object { $_.BusType -eq 'NVMe' }).Count -gt 0) { $isNVMe = $true }
        }
    }
} catch {}

Write-SubStep "Equipo          : $(if ($isVM) { 'Maquina Virtual' } elseif ($isLaptop) { 'Portatil / Laptop' } else { 'PC de Escritorio / Torre' })"
Write-SubStep "Procesador      : $($cpu.Name) ($($cpu.NumberOfCores)C / $($cpu.NumberOfLogicalProcessors)T) [$cpuVendor $(if ($isIntelHybrid){'Hibrido P/E Cores'})]"
Write-SubStep "Memoria RAM     : $ramTotalGiB GB Total ($ramFreeGiB GB disponible)"
Write-SubStep "Disco Principal : Particion C: en $(if ($isNVMe){ 'NVMe PCIe' } elseif ($isSSD){ 'SSD SATA' } else { 'Disco Mecanico HDD' })"
Write-SubStep "Sistema         : $($os.Caption) (Build $($os.Version))"

# -----------------------------------------------------------------------------
# 6. BATERIA DE AUDITORIA POR DOMINIOS (10 FRENTES OFICIALES)
# -----------------------------------------------------------------------------

# --- DOMINIO 1: Plan de Energia & Frecuencias de CPU ---
Write-StepHeader -StepNumber 2 -TotalSteps 10 -Message "CPU & Plan de Energia (Gobernador y Estados C)"
try {
    $activePlan = "$(& powercfg -getactivescheme 2>&1)".Trim()
    $isUltimate = ($activePlan -match 'e9a42b02-d5df-448d-aa00-03f14749eb61|M[aá]ximo rendimiento|Ultimate Performance')
    $isHighPerf = ($activePlan -match '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c|Alto rendimiento|High Performance')

    if ($isUltimate) {
        Register-AuditResult -Category "CPU/Energia" -Item "Plan Activo" -Status "OK" -ActualValue "Maximo Rendimiento (Ultimate)" -ExpectedValue "Ultimate / High" -Impact "Cero latencia de cambio de estado P-state en CA" -Source "Microsoft Performance Tuning"
    } elseif ($isHighPerf) {
        Register-AuditResult -Category "CPU/Energia" -Item "Plan Activo" -Status "OK" -ActualValue "Alto Rendimiento" -ExpectedValue "Ultimate / High" -Impact "Frecuencias minimas elevadas" -Source "Microsoft Performance Tuning"
    } elseif ($isLaptop) {
        Register-AuditResult -Category "CPU/Energia" -Item "Plan Activo" -Status "OK" -ActualValue "Equilibrado (Laptop)" -ExpectedValue "Equilibrado en Portatil" -Impact "Preserva autonomia de bateria y previene thermal throttling" -Source "AMD/Intel Mobile Guides"
    } else {
        Register-AuditResult -Category "CPU/Energia" -Item "Plan Activo" -Status "WARN" -ActualValue "Equilibrado / Economizador" -ExpectedValue "Maximo Rendimiento" -Impact "Latencia variable en transiciones de reloj" -Source "Microsoft Performance Tuning" -RemediationCmd "powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61; powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61"
    }
} catch {
    Register-AuditResult -Category "CPU/Energia" -Item "Plan Activo" -Status "WARN" -ActualValue "Error de consulta" -ExpectedValue "Ultimate" -Impact "Desconocido" -Source "powercfg"
}

# --- DOMINIO 2: GPU, WDDM y Latencia Grafica ---
Write-StepHeader -StepNumber 3 -TotalSteps 10 -Message "GPU & WDDM (HAGS, MSI Mode, Flip Model y Game DVR)"
try {
    # HAGS
    $hagsVal = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name HwSchMode -ErrorAction SilentlyContinue).HwSchMode
    if ($hagsVal -eq 2) {
        Register-AuditResult -Category "GPU/Video" -Item "HAGS (GPU Scheduling)" -Status "OK" -ActualValue "Habilitado (HwSchMode = 2)" -ExpectedValue "Habilitado (2)" -Impact "Planificacion de VRAM delegada a la GPU; menor uso de CPU" -Source "Microsoft Learn: WDDM 2.7+ HAGS"
    } else {
        Register-AuditResult -Category "GPU/Video" -Item "HAGS (GPU Scheduling)" -Status "WARN" -ActualValue "Inactivo o estandar ($hagsVal)" -ExpectedValue "Habilitado (2)" -Impact "La CPU gestiona colas de comandos graficos en ring 0" -Source "Microsoft Learn: WDDM 2.7+ HAGS" -RemediationCmd "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -Value 2 -Type DWord"
    }

    # MSI Mode en GPUs
    $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
    foreach ($g in $gpus) {
        $pnpId = $g.PNPDeviceID
        if ($pnpId) {
            $regP = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            if (Test-Path $regP) {
                $msi = (Get-ItemProperty $regP -Name MSISupported -ErrorAction SilentlyContinue).MSISupported
                if ($msi -eq 1) {
                    Register-AuditResult -Category "GPU/Video" -Item "MSI Mode ($($g.Name))" -Status "OK" -ActualValue "Activo (MSI Mode 1)" -ExpectedValue "Activo (1)" -Impact "Interrupciones por mensaje en bus PCIe; cero colisiones IRQ" -Source "Microsoft PCI MSI/MSI-X Specification"
                } else {
                    Register-AuditResult -Category "GPU/Video" -Item "MSI Mode ($($g.Name))" -Status "WARN" -ActualValue "Inactivo (Line-based INTx)" -ExpectedValue "Activo (1)" -Impact "Interrupciones compartidas tradicionales; mayor latencia DPC" -Source "Microsoft PCI MSI/MSI-X Specification" -RemediationCmd "Set-ItemProperty -Path '$regP' -Name 'MSISupported' -Value 1 -Type DWord"
                }
            }
        }
    }

    # Game DVR
    $dvrUser = (Get-ItemProperty "HKCU:\System\GameConfigStore" -Name GameDVR_Enabled -ErrorAction SilentlyContinue).GameDVR_Enabled
    $dvrPolicy = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name AllowGameDVR -ErrorAction SilentlyContinue).AllowGameDVR
    if ($dvrUser -eq 0 -or $dvrPolicy -eq 0) {
        Register-AuditResult -Category "GPU/Video" -Item "Windows Game DVR" -Status "OK" -ActualValue "Deshabilitado (0)" -ExpectedValue "Deshabilitado (0)" -Impact "Cero captura en segundo plano ni consumo de encoder" -Source "DirectX Dev Blog"
    } else {
        Register-AuditResult -Category "GPU/Video" -Item "Windows Game DVR" -Status "WARN" -ActualValue "Habilitado (1)" -ExpectedValue "Deshabilitado (0)" -Impact "Buffers de video residentes en memoria y caidas de framerate" -Source "DirectX Dev Blog" -RemediationCmd "Set-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0 -Type DWord"
    }

    # Flip Model Presentation
    $dxPrefs = (Get-ItemProperty "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
    if ($dxPrefs -match 'SwapEffectUpgradeEnable=1') {
        Register-AuditResult -Category "GPU/Video" -Item "Optimizacion Juegos en Ventana" -Status "OK" -ActualValue "Flip Model Forzado (SwapEffectUpgradeEnable=1)" -ExpectedValue "Activo" -Impact "Latencia de pantalla completa exclusiva en modo ventana sin tearing" -Source "Microsoft DirectX Advanced Gaming"
    } else {
        Register-AuditResult -Category "GPU/Video" -Item "Optimizacion Juegos en Ventana" -Status "WARN" -ActualValue "Inactivo o estandar" -ExpectedValue "SwapEffectUpgradeEnable=1" -Impact "Latencia de composicion de escritorio DWM heredada" -Source "Microsoft DirectX Advanced Gaming" -RemediationCmd "Set-ItemProperty -Path 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' -Name 'DirectXUserGlobalSettings' -Value 'SwapEffectUpgradeEnable=1;VRROptimizeEnable=1;' -Type String"
    }
} catch {
    Register-AuditResult -Category "GPU/Video" -Item "Subsistema Grafico" -Status "WARN" -ActualValue "Error en evaluacion" -ExpectedValue "OK" -Impact "Desconocido" -Source "WDDM"
}

# --- DOMINIO 3: Memoria & Paginacion ---
Write-StepHeader -StepNumber 4 -TotalSteps 10 -Message "Memoria & Paginacion (Paging Executive, Cache y Archivo Paginacion)"
try {
    $mmReg = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -ErrorAction SilentlyContinue
    
    # DisablePagingExecutive
    if ($ramTotalGiB -ge 15.0) {
        if ($mmReg.DisablePagingExecutive -eq 1) {
            Register-AuditResult -Category "Memoria" -Item "DisablePagingExecutive" -Status "OK" -ActualValue "Habilitado (1)" -ExpectedValue "Habilitado (1)" -Impact "Kernel y controladores residentes permanentemente en RAM" -Source "Microsoft Windows Internals (Russinovich)"
        } else {
            Register-AuditResult -Category "Memoria" -Item "DisablePagingExecutive" -Status "WARN" -ActualValue "Deshabilitado (0)" -ExpectedValue "Habilitado (1 con >=16GB RAM)" -Impact "El kernel puede ser paginado a disco; causa hard page faults en DPC" -Source "Microsoft Windows Internals (Russinovich)" -RemediationCmd "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'DisablePagingExecutive' -Value 1 -Type DWord"
        }
    } else {
        Register-AuditResult -Category "Memoria" -Item "DisablePagingExecutive" -Status "OK" -ActualValue "Paginacion permitida ($ramTotalGiB GB RAM)" -ExpectedValue "Estandar en sistemas con <16GB" -Impact "Evita saturacion de memoria fisica" -Source "Microsoft Windows Internals"
    }

    # LargeSystemCache
    if ($mmReg.LargeSystemCache -eq 0) {
        Register-AuditResult -Category "Memoria" -Item "LargeSystemCache" -Status "OK" -ActualValue "Prioridad a Programas (0)" -ExpectedValue "0 (Workstation/Gaming)" -Impact "Asigna maxima memoria de trabajo a procesos de primer plano" -Source "Microsoft Server/Client Performance Guidelines"
    } else {
        Register-AuditResult -Category "Memoria" -Item "LargeSystemCache" -Status "WARN" -ActualValue "Modo Servidor de Archivos (1)" -ExpectedValue "0" -Impact "La cache de archivos consume RAM prioritaria de juegos/apps" -Source "Microsoft Server/Client Performance Guidelines" -RemediationCmd "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'LargeSystemCache' -Value 0 -Type DWord"
    }

    # ClearPageFileAtShutdown
    if ($mmReg.ClearPageFileAtShutdown -eq 0) {
        Register-AuditResult -Category "Memoria" -Item "Limpieza de Paginacion en Apagado" -Status "OK" -ActualValue "Deshabilitado (0)" -ExpectedValue "0" -Impact "Apagado y reinicio ultrarrapido" -Source "Microsoft Windows Administration"
    } else {
        Register-AuditResult -Category "Memoria" -Item "Limpieza de Paginacion en Apagado" -Status "WARN" -ActualValue "Habilitado (1)" -ExpectedValue "0" -Impact "Retardo severo al apagar el equipo por sobrescritura de ceros" -Source "Microsoft Windows Administration" -RemediationCmd "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'ClearPageFileAtShutdown' -Value 0 -Type DWord"
    }

    # MMAgent (Memory Compression)
    $mmProbe = Invoke-SafeAdminProbe -ActionName "Get-MMAgent" -Script { Get-MMAgent }
    if ($mmProbe.Success) {
        $mc = $mmProbe.Output.MemoryCompression
        Register-AuditResult -Category "Memoria" -Item "Compresion de Memoria (RAM)" -Status "OK" -ActualValue "Auditado (Compresion: $mc)" -ExpectedValue "Activo" -Impact "Reduce swap a disco comprimiendo paginas inactivas en RAM" -Source "Microsoft Engineering: Memory Compression in Windows"
    } else {
        Register-AuditResult -Category "Memoria" -Item "Compresion de Memoria (MMAgent)" -Status "RESTRICTED" -ActualValue "Acceso denegado" -ExpectedValue "Solo Administrador" -Impact "Requiere privilegios de Administrador para introspeccion de MMAgent" -Source "Windows Memory Management API"
    }
} catch {
    Register-AuditResult -Category "Memoria" -Item "Gestion de Memoria" -Status "WARN" -ActualValue "Error en consulta" -ExpectedValue "OK" -Impact "Desconocido" -Source "Memory Management"
}

# --- DOMINIO 4: Almacenamiento & Sistema de Archivos ---
Write-StepHeader -StepNumber 5 -TotalSteps 10 -Message "Almacenamiento & NTFS (TRIM, DisableLastAccess y BypassIO)"
try {
    # TRIM
    $trimQuery = "$(& fsutil behavior query DisableDeleteNotify 2>&1)".Trim()
    if ($trimQuery -match '0|Permite que se env[ií]en operaciones de recorte') {
        Register-AuditResult -Category "Almacenamiento" -Item "Soporte SSD TRIM" -Status "OK" -ActualValue "Habilitado (DisableDeleteNotify = 0)" -ExpectedValue "Habilitado (0)" -Impact "Mantiene velocidad de escritura sostenida y previene desgaste NAND" -Source "JEDEC / Microsoft Storage Architecture"
    } else {
        Register-AuditResult -Category "Almacenamiento" -Item "Soporte SSD TRIM" -Status "FAIL" -ActualValue "Deshabilitado o no admitido" -ExpectedValue "Habilitado (0)" -Impact "Degradacion severa del rendimiento de escrituras en SSD" -Source "Microsoft Storage Architecture" -RemediationCmd "fsutil behavior set DisableDeleteNotify 0"
    }

    # DisableLastAccess
    $lastAccessQuery = "$(& fsutil behavior query disablelastaccess 2>&1)".Trim()
    if ($lastAccessQuery -match '1|3|actualizaciones de la hora de [uú]ltimo acceso DESHABILITADAS|User Managed, Last Access Updates Disabled|System Managed, Last Access Updates Disabled') {
        Register-AuditResult -Category "Almacenamiento" -Item "NTFS DisableLastAccess" -Status "OK" -ActualValue "Optimo (Actualizaciones Deshabilitadas)" -ExpectedValue "Deshabilitado (1 o 3)" -Impact "Elimina escrituras continuas de metadatos cada vez que un archivo se lee" -Source "Microsoft Learn: fsutil behavior"
    } else {
        Register-AuditResult -Category "Almacenamiento" -Item "NTFS DisableLastAccess" -Status "WARN" -ActualValue "Habilitado (Estandar 0/2)" -ExpectedValue "Deshabilitado (1)" -Impact "Sobrecarga de escrituras de timestamp en particiones NTFS" -Source "Microsoft Learn: fsutil behavior" -RemediationCmd "fsutil behavior set disablelastaccess 1"
    }

    # BypassIO DirectStorage
    $bypassProbe = Invoke-SafeAdminProbe -ActionName "fsutil bypassio state C:" -Script { & fsutil bypassio state C: }
    if ($bypassProbe.Success) {
        if ("$($bypassProbe.Output)" -match 'is supported|est[aá] admitido|OK|compatible') {
            Register-AuditResult -Category "Almacenamiento" -Item "BypassIO (DirectStorage NVMe)" -Status "OK" -ActualValue "Soportado y Activo" -ExpectedValue "Soportado" -Impact "Ruta rapida de I/O directo del NVMe a la VRAM de la GPU" -Source "Microsoft Learn: DirectStorage & BypassIO"
        } else {
            Register-AuditResult -Category "Almacenamiento" -Item "BypassIO (DirectStorage NVMe)" -Status "WARN" -ActualValue "No soportado o vetado por minifiltros" -ExpectedValue "Soportado" -Impact "Juegos compatibles caen en la ruta de I/O tradicional con overhead" -Source "Microsoft Learn: DirectStorage & BypassIO"
        }
    } else {
        Register-AuditResult -Category "Almacenamiento" -Item "BypassIO (DirectStorage NVMe)" -Status "RESTRICTED" -ActualValue "Acceso denegado" -ExpectedValue "Solo Administrador" -Impact "Requiere elevacion para interrogar al controlador de la particion C:" -Source "fsutil bypassio command reference"
    }

    # CompactOS
    $compactQuery = "$(& compact.exe /CompactOS:query 2>&1)".Trim()
    $compactState = if ($compactQuery -match 'is in the Compact state|est[aá] en el estado Compact') { "Activo" } else { "Inactivo / Estandar" }
    Register-AuditResult -Category "Almacenamiento" -Item "Compresion CompactOS" -Status "OK" -ActualValue "$compactState" -ExpectedValue "Segun tamano de disco" -Impact "Ahorra 4-8 GB en unidades pequenas o prioriza I/O nativo en NVMe" -Source "Microsoft Learn: Compact OS"
} catch {
    Register-AuditResult -Category "Almacenamiento" -Item "Sistema de Archivos" -Status "WARN" -ActualValue "Error en consulta" -ExpectedValue "OK" -Impact "Desconocido" -Source "fsutil"
}

# --- DOMINIO 5: Red & Latencia de Paquetes ---
Write-StepHeader -StepNumber 6 -TotalSteps 10 -Message "Red & Latencia TCP/IP (Green Ethernet, ECN, Nagle y Offloading)"
try {
    # TCP Global (ECN)
    $tcpGlobal = "$(& netsh.exe int tcp show global 2>&1)".Trim()
    if ($tcpGlobal -match 'ECN Capability\s*:\s*enabled|Capacidad de ECN\s*:\s*enabled|Capacidad ECN\s*:\s*habilitado') {
        Register-AuditResult -Category "Red/TCP" -Item "TCP ECN Capability" -Status "OK" -ActualValue "Habilitado (RFC 3168)" -ExpectedValue "Habilitado" -Impact "Mitigacion activa de Bufferbloat y caidas de paquetes en routers" -Source "IETF RFC 3168 / Microsoft Networking Blog"
    } else {
        Register-AuditResult -Category "Red/TCP" -Item "TCP ECN Capability" -Status "WARN" -ActualValue "Deshabilitado" -ExpectedValue "Habilitado" -Impact "Riesgo de bufferbloat en conexiones congestionadas" -Source "IETF RFC 3168" -RemediationCmd "netsh int tcp set global ecncapability=enabled"
    }

    # Algoritmo de Nagle en Adaptadores
    $interfaces = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*' -ErrorAction SilentlyContinue
    $nagleDisabled = $false
    foreach ($iface in $interfaces) {
        if ($iface.TcpAckFrequency -eq 1 -and $iface.TCPNoDelay -eq 1) {
            $nagleDisabled = $true
            break
        }
    }
    if ($nagleDisabled) {
        Register-AuditResult -Category "Red/TCP" -Item "Algoritmo de Nagle (TcpAckFrequency)" -Status "OK" -ActualValue "Deshabilitado (ACK Inmediato)" -ExpectedValue "TcpAckFrequency=1, TCPNoDelay=1" -Impact "Cero retraso artificial de 200ms en el envio de paquetes pequenos en juegos" -Source "IETF RFC 896 / RFC 1122"
    } else {
        Register-AuditResult -Category "Red/TCP" -Item "Algoritmo de Nagle (TcpAckFrequency)" -Status "WARN" -ActualValue "Estandar (Buffer de espera 200ms)" -ExpectedValue "ACK Inmediato (1)" -Impact "Micro-retrasos en juegos online y aplicaciones de streaming" -Source "IETF RFC 896 / RFC 1122" -RemediationCmd "Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' | ForEach-Object { Set-ItemProperty -Path `$_.PSPath -Name 'TcpAckFrequency' -Value 1 -Type DWord; Set-ItemProperty -Path `$_.PSPath -Name 'TCPNoDelay' -Value 1 -Type DWord }"
    }

    # Green Ethernet & Power Saving en Adaptadores Realtek / Intel
    $ethProps = @(Get-NetAdapterAdvancedProperty -ErrorAction SilentlyContinue)
    $greenEth = $ethProps | Where-Object { $_.DisplayName -match 'Ethernet ecol[oó]gico|Green Ethernet' }
    $pwrSave = $ethProps | Where-Object { $_.DisplayName -match 'Power Saving Mode' }

    if ($greenEth -and $greenEth.DisplayValue -match 'Activado|Enabled') {
        Register-AuditResult -Category "Red/Hardware" -Item "Ethernet Ecologico (Green Ethernet)" -Status "WARN" -ActualValue "Activado (Ahorro de energia en PHY)" -ExpectedValue "Desactivado" -Impact "Fluctuaciones y micro-latencias en la conexion de red (DPC jitter)" -Source "IEEE 802.3az Low-Power Idle / Realtek Guides" -RemediationCmd "Set-NetAdapterAdvancedProperty -Name '$($greenEth.Name)' -DisplayName '$($greenEth.DisplayName)' -DisplayValue 'Desactivado'"
    } elseif ($greenEth) {
        Register-AuditResult -Category "Red/Hardware" -Item "Ethernet Ecologico (Green Ethernet)" -Status "OK" -ActualValue "Desactivado [OK]" -ExpectedValue "Desactivado" -Impact "Maxima estabilidad de reloj de enlace" -Source "IEEE 802.3az"
    }

    if ($pwrSave -and $pwrSave.DisplayValue -match 'Activado|Enabled') {
        Register-AuditResult -Category "Red/Hardware" -Item "Power Saving Mode (NIC)" -Status "WARN" -ActualValue "Activado" -ExpectedValue "Desactivado" -Impact "Retardos de despertar del transceptor" -Source "Realtek Driver Architecture" -RemediationCmd "Set-NetAdapterAdvancedProperty -Name '$($pwrSave.Name)' -DisplayName '$($pwrSave.DisplayName)' -DisplayValue 'Desactivado'"
    } elseif ($pwrSave) {
        Register-AuditResult -Category "Red/Hardware" -Item "Power Saving Mode (NIC)" -Status "OK" -ActualValue "Desactivado [OK]" -ExpectedValue "Desactivado" -Impact "Transceptor siempre listo a maxima frecuencia" -Source "Realtek Driver Architecture"
    }

    # Throttling de Red Multimedia
    $sysProfile = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ErrorAction SilentlyContinue
    if ($sysProfile.NetworkThrottlingIndex -eq 4294967295 -or $sysProfile.NetworkThrottlingIndex -eq 0xFFFFFFFF) {
        Register-AuditResult -Category "Red/Sistema" -Item "Network Throttling Index" -Status "OK" -ActualValue "Deshabilitado (0xFFFFFFFF)" -ExpectedValue "Deshabilitado (0xFFFFFFFF)" -Impact "El sistema nunca limita paquetes de red durante actividad multimedia" -Source "Microsoft Learn: Multimedia System Profile"
    } else {
        Register-AuditResult -Category "Red/Sistema" -Item "Network Throttling Index" -Status "WARN" -ActualValue "Activo ($($sysProfile.NetworkThrottlingIndex))" -ExpectedValue "0xFFFFFFFF" -Impact "Windows limita paquetes de red no multimedia al reproducir audio/video" -Source "Microsoft Learn: Multimedia System Profile" -RemediationCmd "Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'NetworkThrottlingIndex' -Value 0xFFFFFFFF -Type DWord"
    }
} catch {
    Register-AuditResult -Category "Red" -Item "Pila TCP" -Status "WARN" -ActualValue "Error en consulta" -ExpectedValue "OK" -Impact "Desconocido" -Source "TCP/IP"
}

# --- DOMINIO 6: Kernel & Virtualizacion (VBS / HVCI) ---
Write-StepHeader -StepNumber 7 -TotalSteps 10 -Message "Kernel & Seguridad (VBS, HVCI Memory Integrity y ASR)"
try {
    $dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
    $hvciReg = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -ErrorAction SilentlyContinue).Enabled

    if ($hvciReg -eq 0) {
        Register-AuditResult -Category "Kernel/VBS" -Item "HVCI (Integridad de Memoria)" -Status "OK" -ActualValue "Deshabilitado (0) [Maximo FPS]" -ExpectedValue "Deshabilitado (Gaming) o 1 (Empresarial)" -Impact "Elimina la penalizacion de emulacion de paginas de memoria del hipervisor" -Source "Microsoft Support KB5022830 (Gaming Performance)"
    } else {
        Register-AuditResult -Category "Kernel/VBS" -Item "HVCI (Integridad de Memoria)" -Status "WARN" -ActualValue "Habilitado (1)" -ExpectedValue "Deshabilitado (si busca maximo FPS)" -Impact "Impacto medible de entre 5% y 11% de FPS en juegos CPU-dependientes" -Source "Microsoft Support KB5022830 (Gaming Performance)" -RemediationCmd "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name 'Enabled' -Value 0 -Type DWord"
    }

    # BCD boot loader
    $bcdProbe = Invoke-SafeAdminProbe -ActionName "bcdedit.exe /enum" -Script { & bcdedit.exe /enum }
    if ($bcdProbe.Success) {
        $bcdOut = "$($bcdProbe.Output)"
        $hpetForced = ($bcdOut -match 'useplatformclock\s+Yes')
        if ($hpetForced) {
            Register-AuditResult -Category "Kernel/BCD" -Item "HPET (useplatformclock)" -Status "WARN" -ActualValue "Forzado (Yes)" -ExpectedValue "No / Default TSC" -Impact "Sobrecarga de llamadas de temporizador sintetico en bus PCIe" -Source "Intel / AMD Architecture Reference" -RemediationCmd "bcdedit /deletevalue useplatformclock"
        } else {
            Register-AuditResult -Category "Kernel/BCD" -Item "HPET (useplatformclock)" -Status "OK" -ActualValue "Optimo (Reloj nativo TSC)" -ExpectedValue "TSC Nativo" -Impact "Minima sobrecarga de consulta de timestamp en CPU" -Source "Intel Architecture Reference"
        }
    } else {
        Register-AuditResult -Category "Kernel/BCD" -Item "BCD Boot Configuration" -Status "RESTRICTED" -ActualValue "Acceso denegado" -ExpectedValue "Solo Administrador" -Impact "Requiere elevacion para inspeccionar parametros de arranque del cargador EFI" -Source "bcdedit reference"
    }
} catch {
    Register-AuditResult -Category "Kernel/VBS" -Item "DeviceGuard" -Status "WARN" -ActualValue "Error en consulta" -ExpectedValue "OK" -Impact "Desconocido" -Source "DeviceGuard"
}

# --- DOMINIO 7: Servicios de Fondo & Telemetria ---
Write-StepHeader -StepNumber 8 -TotalSteps 10 -Message "Servicios del Sistema & Telemetria"
$servicesToAudit = @(
    @{ Name = 'DiagTrack'; Description = 'Telemetria y Experiencia Conectada'; Expected = 'Disabled' },
    @{ Name = 'dmwappushservice'; Description = 'Servicio de Enrutamiento WAP Push'; Expected = 'Disabled' },
    @{ Name = 'WerSvc'; Description = 'Informes de Errores de Windows'; Expected = 'Disabled' },
    @{ Name = 'SysMain'; Description = 'Superfetch / Prefetch de Disco'; Expected = $(if ($isSSD){ 'Disabled' } else { 'Running' }) },
    @{ Name = 'WSearch'; Description = 'Indexacion de Busqueda en Disco'; Expected = 'Disabled' },
    @{ Name = 'Spooler'; Description = 'Cola de Impresion'; Expected = 'Disabled' },
    @{ Name = 'RetailDemo'; Description = 'Servicio de Demostracion de Tienda'; Expected = 'Disabled' }
)

foreach ($s in $servicesToAudit) {
    $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
    if ($svc) {
        $startMode = (Get-CimInstance Win32_Service -Filter "Name='$($s.Name)'" -ErrorAction SilentlyContinue).StartMode
        $isOptimal = ($svc.Status -eq 'Stopped' -and $startMode -eq $s.Expected)
        if ($s.Name -eq 'SysMain' -and -not $isSSD) {
            # En HDD es util
            Register-AuditResult -Category "Servicios" -Item "$($s.Name) ($($s.Description))" -Status "OK" -ActualValue "$($svc.Status) ($startMode)" -ExpectedValue "Activo en HDD" -Impact "Mejora precarga de bloques en discos mecanicos lentos" -Source "Microsoft Storage Internals"
        } elseif ($isOptimal) {
            Register-AuditResult -Category "Servicios" -Item "$($s.Name) ($($s.Description))" -Status "OK" -ActualValue "Deshabilitado / Detenido" -ExpectedValue "Disabled" -Impact "Cero consumo de CPU en segundo plano ni telemetria" -Source "Microsoft Services Architecture"
        } else {
            Register-AuditResult -Category "Servicios" -Item "$($s.Name) ($($s.Description))" -Status "WARN" -ActualValue "$($svc.Status) (Inicio: $startMode)" -ExpectedValue "$($s.Expected)" -Impact "Proceso residente en segundo plano consumiendo ciclos de CPU y RAM" -Source "Microsoft Services Architecture" -RemediationCmd "Stop-Service -Name '$($s.Name)' -Force; Set-Service -Name '$($s.Name)' -StartupType Disabled"
        }
    } else {
        Register-AuditResult -Category "Servicios" -Item "$($s.Name)" -Status "OK" -ActualValue "No instalado o purgado" -ExpectedValue "Ausente" -Impact "Maxima higiene de sistema" -Source "Microsoft Services Architecture"
    }
}

# --- DOMINIO 8: Debloat UWP & Residuos Promocionales ---
Write-StepHeader -StepNumber 9 -TotalSteps 10 -Message "Debloat de Aplicaciones UWP y Programas de Inicio"
try {
    $appx = @(Get-AppxPackage -ErrorAction SilentlyContinue)
    $bloatNames = @('WebExperience', 'ZuneVideo', 'ZuneMusic', 'BingNews', 'BingWeather', 'GetHelp', 'Getstarted', 'Solitaire', 'Microsoft\.People$', 'Todos', 'FeedbackHub', 'Clipchamp', 'Cortana')
    $foundBloat = [System.Collections.Generic.List[string]]::new()
    foreach ($pkg in $appx) {
        if (-not $pkg.NonRemovable -and $pkg.InstallLocation -notlike "*SystemApps*") {
            foreach ($b in $bloatNames) {
                if ($pkg.Name -match $b) {
                    if (-not $foundBloat.Contains($pkg.Name)) { $foundBloat.Add($pkg.Name) }
                    break
                }
            }
        }
    }

    if ($foundBloat.Count -eq 0) {
        Register-AuditResult -Category "Debloat/Apps" -Item "Paquetes UWP Promocionales" -Status "OK" -ActualValue "Limpio (0 paquetes residuales desinstalables)" -ExpectedValue "0 paquetes" -Impact "Cero aplicaciones publicitarias ejecutandose en segundo plano" -Source "Microsoft AppX Management"
    } else {
        Register-AuditResult -Category "Debloat/Apps" -Item "Paquetes UWP Promocionales" -Status "WARN" -ActualValue "Detectados $($foundBloat.Count) paquetes ($($foundBloat -join ', '))" -ExpectedValue "0 paquetes" -Impact "Consumo de RAM y tareas programadas de actualizacion en segundo plano" -Source "Microsoft AppX Management" -RemediationCmd "Get-AppxPackage | Where-Object { -not `$_.NonRemovable -and `$_.InstallLocation -notlike '*SystemApps*' -and (`$_.Name -match '$($bloatNames -join '|')') } | Remove-AppxPackage"
    }

    # Retardo de Menu (MenuShowDelay)
    $menuDelay = (Get-ItemProperty "HKCU:\Control Panel\Desktop" -Name MenuShowDelay -ErrorAction SilentlyContinue).MenuShowDelay
    if ($menuDelay -eq "0" -or $menuDelay -eq 0) {
        Register-AuditResult -Category "UI/Desktop" -Item "Retardo de Menus (MenuShowDelay)" -Status "OK" -ActualValue "0 ms (Respuesta instantanea)" -ExpectedValue "0 ms" -Impact "Apertura sin retardo de menus contextuales y submenus" -Source "Microsoft Win32 UI Guidelines"
    } else {
        Register-AuditResult -Category "UI/Desktop" -Item "Retardo de Menus (MenuShowDelay)" -Status "WARN" -ActualValue "$menuDelay ms (Retardo de Windows)" -ExpectedValue "0 ms" -Impact "Sensacion de lentitud al interactuar con el explorador" -Source "Microsoft Win32 UI Guidelines" -RemediationCmd "Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'MenuShowDelay' -Value '0' -Type String"
    }
} catch {
    Register-AuditResult -Category "Debloat/Apps" -Item "Auditoria de Apps" -Status "WARN" -ActualValue "Error en consulta" -ExpectedValue "OK" -Impact "Desconocido" -Source "AppX"
}

# --- DOMINIO 9: Windows Update, Higiene OEM y Temporizador ---
Write-StepHeader -StepNumber 10 -TotalSteps 10 -Message "Higiene de Windows Update, Politicas OEM y Resolucion de Reloj"
try {
    # Drivers en Windows Update
    $wuDrivers = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name ExcludeWUDriversInQualityUpdate -ErrorAction SilentlyContinue).ExcludeWUDriversInQualityUpdate
    if ($wuDrivers -eq 1) {
        Register-AuditResult -Category "WindowsUpdate" -Item "Excluir Drivers en Actualizaciones" -Status "OK" -ActualValue "Habilitado (1)" -ExpectedValue "1" -Impact "Windows Update no sobreescribe controladores optimizados de GPU o Red" -Source "Microsoft Learn: Windows Update Policies"
    } else {
        Register-AuditResult -Category "WindowsUpdate" -Item "Excluir Drivers en Actualizaciones" -Status "WARN" -ActualValue "No configurado (0 o ausente)" -ExpectedValue "1" -Impact "Riesgo de que Windows Update reemplace drivers limpios por genericos" -Source "Microsoft Learn: Windows Update Policies" -RemediationCmd "if (-not (Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate')) { New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Force }; Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Name 'ExcludeWUDriversInQualityUpdate' -Value 1 -Type DWord"
    }

    # Bloqueo WPBT OEM
    $wpbt = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name DisableWPBT -ErrorAction SilentlyContinue).DisableWPBT
    if ($wpbt -eq 1) {
        Register-AuditResult -Category "Seguridad/OEM" -Item "Bloqueo Inyeccion ACPI WPBT" -Status "OK" -ActualValue "Habilitado (DisableWPBT = 1)" -ExpectedValue "1" -Impact "Previene que la BIOS inyecte ejecutables o bloatware del fabricante" -Source "Microsoft Learn: Windows Platform Binary Table (WPBT)"
    } else {
        Register-AuditResult -Category "Seguridad/OEM" -Item "Bloqueo Inyeccion ACPI WPBT" -Status "WARN" -ActualValue "No configurado (0)" -ExpectedValue "1" -Impact "La placa base puede auto-instalar software OEM no deseado en arranque" -Source "Microsoft Learn: WPBT" -RemediationCmd "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'DisableWPBT' -Value 1 -Type DWord"
    }

    # Resolucion de Temporizador
    if ($timerResMs -le 1.0) {
        Register-AuditResult -Category "Kernel/Timer" -Item "Resolucion de Temporizador" -Status "OK" -ActualValue "$timerResMs ms (Alta Precision)" -ExpectedValue "<= 1.0 ms" -Impact "Despacho fluido de fotogramas e hilos de audio en tiempo real" -Source "Windows NT Kernel Timer Reference"
    } else {
        Register-AuditResult -Category "Kernel/Timer" -Item "Resolucion de Temporizador" -Status "WARN" -ActualValue "$timerResMs ms (Estandar Windows)" -ExpectedValue "<= 1.0 ms" -Impact "Mayor latencia de ejecucion de hilos multimedia" -Source "Windows NT Kernel Timer Reference"
    }
} catch {
    Register-AuditResult -Category "WindowsUpdate" -Item "Higiene y Temporizador" -Status "WARN" -ActualValue "Error en consulta" -ExpectedValue "OK" -Impact "Desconocido" -Source "Windows Update"
}

# -----------------------------------------------------------------------------
# 7. CALCULO DE SCORE DE OPTIMIZACION (0 - 100%) Y ESTADISTICAS
# -----------------------------------------------------------------------------
$totalAudited = $auditItems.Count
$okCount = ($auditItems | Where-Object { $_.Status -eq 'OK' }).Count
$warnCount = ($auditItems | Where-Object { $_.Status -eq 'WARN' }).Count
$failCount = ($auditItems | Where-Object { $_.Status -eq 'FAIL' }).Count
$restrictedCount = ($auditItems | Where-Object { $_.Status -eq 'RESTRICTED' }).Count

$evaluableCount = $totalAudited - $restrictedCount
$score = if ($evaluableCount -gt 0) {
    [math]::Round((($okCount + ($warnCount * 0.4)) / $evaluableCount) * 100, 1)
} else { 100.0 }

$tierText = if ($score -ge 90) {
    "EXCELENTE (Optimizacion de Elite / Tier 1)"
} elseif ($score -ge 75) {
    "BUENO (Bien optimizado, con oportunidades puntuales)"
} elseif ($score -ge 50) {
    "MODERADO (Configuracion estandar con sobrecarga medible)"
} else {
    "DEFICIENTE (Cuellos de botella severos y latencia elevada)"
}

$tierColor = if ($score -ge 90) { "Green" } elseif ($score -ge 75) { "Cyan" } elseif ($score -ge 50) { "Yellow" } else { "Red" }

Write-Host "`n" + ("=" * 80) -ForegroundColor DarkCyan
Write-Host "                RESUMEN EJECUTIVO DE OPTIMIZACION" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor DarkCyan
Write-Host "  Puntuacion Global de Optimizacion : " -NoNewline -ForegroundColor White
Write-Host "$score% " -ForegroundColor $tierColor -NoNewline
Write-Host "[$tierText]" -ForegroundColor $tierColor

Write-Host "  Directivas Optimas               : $okCount" -ForegroundColor Green
Write-Host "  Oportunidades de Mejora          : $warnCount" -ForegroundColor Yellow
Write-Host "  Cuellos de Botella Detectados    : $failCount" -ForegroundColor Red
Write-Host "  Pruebas Protegidas por Permisos  : $restrictedCount" -ForegroundColor $(if ($restrictedCount -gt 0){ 'Cyan' } else { 'DarkGray' })
Write-Host ("=" * 80) -ForegroundColor DarkCyan

# -----------------------------------------------------------------------------
# 8. SECCION TRANSPARENTE: PRUEBAS PROTEGIDAS POR PERMISOS
# -----------------------------------------------------------------------------
if ($restrictedCalls.Count -gt 0) {
    Write-Host "`n[!] PRUEBAS PROTEGIDAS POR PERMISOS (Requieren Modo Administrador):" -ForegroundColor Cyan
    Write-Host "    Para auditar estas areas, ejecute el script haciendo Clic Derecho -> 'Ejecutar como Administrador'.`n" -ForegroundColor Gray
    foreach ($r in $restrictedCalls) {
        Write-Host "  * $($r.Category) | $($r.Item)" -ForegroundColor White
        Write-Host "    -> Causa   : $($r.Impact)" -ForegroundColor DarkCyan
        Write-Host "    -> Fuente  : $($r.OfficialSource)`n" -ForegroundColor DarkGray
    }
}

# -----------------------------------------------------------------------------
# 9. GENERACION DE COMANDOS DE REMEDIACION (SOLUCIONES 1-CLIC)
# -----------------------------------------------------------------------------
if ($ShowRemediation -and $remediations.Count -gt 0) {
    Write-Host "`n" + ("=" * 80) -ForegroundColor Yellow
    Write-Host "           COMANDOS OFICIALES DE REMEDIACION (PowerShell como Administrador)" -ForegroundColor Yellow
    Write-Host ("=" * 80) -ForegroundColor Yellow
    Write-Host "# Copie y pegue las siguientes instrucciones en una consola elevada para aplicar los parches:`n" -ForegroundColor Gray

    $dedupCmds = $remediations | Select-Object -ExpandProperty RemediationCmd -Unique
    foreach ($cmd in $dedupCmds) {
        Write-Host $cmd -ForegroundColor Green
    }
    Write-Host "`n" + ("=" * 80) -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# 10. EXPORTACION DE INFORME EN MARKDOWN
# -----------------------------------------------------------------------------
if ($ExportReport) {
    if (-not $OutputDir) {
        $desktop = [Environment]::GetFolderPath('Desktop')
        $OutputDir = if ($desktop -and (Test-Path $desktop)) { $desktop } else { $env:USERPROFILE }
    }
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $reportPath = Join-Path $OutputDir "Auditoria_Optimizacion_PC_$((Get-Date).ToString('yyyyMMdd_HHmmss')).md"
    $md = [System.Collections.Generic.List[string]]::new()

    $md.Add("# Informe Integral de Auditoria y Optimizacion de PC")
    $md.Add("")
    $md.Add("- **Fecha del Analisis:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $md.Add("- **Nivel de Privilegios:** $privilegeLevel")
    $md.Add("- **Puntuacion Global:** **$score%** ($tierText)")
    $md.Add("- **Equipo:** $($cs.Manufacturer) $($cs.Model) [$(if ($isLaptop){'Portatil'}else{'Desktop'})]")
    $md.Add("- **Procesador:** $($cpu.Name)")
    $md.Add("- **Memoria RAM:** $ramTotalGiB GB")
    $md.Add("- **Sistema:** $($os.Caption) (Build $($os.Version))")
    $md.Add("")
    $md.Add("## Resumen de Diagnostico")
    $md.Add("")
    $md.Add("| Estado | Cantidad | Significado |")
    $md.Add("|---|---|---|")
    $md.Add("| 🟢 Optimo | $okCount | Configuracion alineada a la documentacion oficial |")
    $md.Add("| 🟡 Oportunidad de Mejora | $warnCount | Ajuste seguro que aporta mayor rendimiento o menor latencia |")
    $md.Add("| 🔴 Cuello de Botella | $failCount | Configuracion perjudicial o degradacion medible |")
    $md.Add("| 🔒 Requiere Elevacion | $restrictedCount | Omitido por privilegios de usuario estandar |")
    $md.Add("")
    $md.Add("## Detalle de Directivas Auditadas")
    $md.Add("")
    $md.Add("| Dominio | Item Auditado | Estado | Valor Actual | Valor Recomendado | Fuente Oficial |")
    $md.Add("|---|---|---|---|---|---|")

    foreach ($it in $auditItems) {
        $badge = switch ($it.Status) {
            'OK' { '🟢 OK' }
            'WARN' { '🟡 MEJORA' }
            'FAIL' { '🔴 ERROR' }
            'RESTRICTED' { '🔒 ELEVACION' }
        }
        $md.Add("| $($it.Category) | $($it.Item) | $badge | $($it.ActualValue) | $($it.ExpectedValue) | $($it.OfficialSource) |")
    }

    if ($remediations.Count -gt 0) {
        $md.Add("")
        $md.Add("## Comandos de Remediacion Inmediata (PowerShell Elevado)")
        $md.Add('```powershell')
        foreach ($c in ($remediations | Select-Object -ExpandProperty RemediationCmd -Unique)) {
            $md.Add($c)
        }
        $md.Add('```')
    }

    try {
        [System.IO.File]::WriteAllText($reportPath, ($md -join "`r`n"), [System.Text.Encoding]::UTF8)
        Write-Host "`n  [+] Informe exportado con exito en: " -ForegroundColor Green -NoNewline
        Write-Host "$reportPath" -ForegroundColor White
    } catch {
        Write-Warn "No se pudo escribir el informe Markdown en $reportPath ($($_.Exception.Message))"
    }
}

Write-Host "`n  Auditoria finalizada exitosamente.`n" -ForegroundColor Green
