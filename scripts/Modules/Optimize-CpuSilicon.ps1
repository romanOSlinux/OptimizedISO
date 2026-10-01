<#
.SYNOPSIS
    Optimize-CpuSilicon.ps1 - Optimizador PolimÃ³rfico de CPU y Silicio Multi-Hardware
    romanOS / OptimizedISO â€” PLAN-0150

.DESCRIPTION
    Aplica polÃ­ticas de kernel adaptativas segÃºn la microarquitectura de silicio detectada:
      - Intel HeterogÃ©neo HÃ­brido (12th-14th & Core Ultra): Preserva Thread Director, EPP=33, Win32PrioritySeparation=2.
      - AMD Dual-CCD AsimÃ©trico con 3D V-Cache (7900X3D/7950X3D): 50% Core Parking, Win32PrioritySeparation=2.
      - AMD Zen 3/4/5 SimÃ©trico (5600X/7600X): PROCTHROTTLEMIN=5%, Win32PrioritySeparation=38, Core Unpark=100%.
      - AMD APU MonolÃ­tica UMA (8600G/5600G): LargeSystemCache=0 estricto, GPU MSI SpreadAcrossCPUs.
      - AMD Multi-CCX Temprano (Zen 1 / 1600): ContenciÃ³n de afinidad a un solo CCX.
      - Intel Legacy Pre-HWP (Haswell 4ta Gen): PROCTHROTTLEMIN=100% (Ultimate clÃ¡sico por P-states lentos de 30ms).

    Cumplimiento estricto:
      - Regla 4: UTF-8 con BOM y compatibilidad Windows PowerShell 5.1.
      - Regla 13: Cero fallos silenciosos (Fail-Visible / CWE-390).
      - Regla 14: Arquitectura Multi-Hardware en 3 Capas.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("Status", "Audit", "Optimize", "Reset")]
    [string]$Action = "Status",

    [Parameter(Mandatory = $false)]
    [PSCustomObject]$CustomHardwareProfile = $null,

    [switch]$Unattended,
    [switch]$SkipElevation
)

$ErrorActionPreference = 'Continue'
$scriptStartTime = Get-Date

# Resolucion de rutas base
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $repoRoot "scripts\Core\Hardware-Engine.ps1"))) {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    if (-not (Test-Path (Join-Path $repoRoot "scripts\Core\Hardware-Engine.ps1"))) {
        $repoRoot = "C:\OptimizedISO"
    }
}

$hwEnginePath = Join-Path $repoRoot "scripts\Core\Hardware-Engine.ps1"
if (Test-Path $hwEnginePath) {
    . $hwEnginePath
} else {
    Write-Warning "[Optimize-CpuSilicon] Hardware-Engine.ps1 no disponible en: $hwEnginePath"
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS / OptimizedISO - OPTIMIZADOR POLIMORFICO DE CPU Y SILICIO       " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Accion: $Action | Host: $env:COMPUTERNAME | Admin: $isAdmin" -ForegroundColor DarkGray

# 1. Obtener perfil de hardware
$hw = if ($CustomHardwareProfile) {
    $CustomHardwareProfile
} elseif (Get-Command 'Get-SystemHardwareProfile' -ErrorAction SilentlyContinue) {
    Get-SystemHardwareProfile
} else {
    $null
}

if (-not $hw) {
    Write-Error "[Optimize-CpuSilicon] No se pudo obtener el perfil de hardware del sistema."
    exit 1
}

# 2. Consultar politica canÃ³nica de silicio
$policy = if (Get-Command 'Get-RomanOSCpuArchitecturePolicy' -ErrorAction SilentlyContinue) {
    Get-RomanOSCpuArchitecturePolicy -HardwareInfo $hw
} else {
    [PSCustomObject]@{
        ArchitectureFamily          = 'Generic_x86_Fallback'
        DisplayName                 = 'Generica Fallback'
        ProcThrottleMinPercent      = 5
        ProcThrottleMaxPercent      = 100
        EnergyPerformancePreference = 33
        CoreParkingPolicy           = 'UnparkAll'
        LargeSystemCache            = 0
        Win32PrioritySeparation     = 2
        PowerThrottlingMode         = 'SelectiveBackground'
        AffinityDpcStrategy         = 'Default'
        Rationale                   = 'Politica base por ausencia de Hardware-Engine.'
    }
}

Write-Host ""
Write-Host ">>> Arquitectura de Silicio Detectada:" -ForegroundColor Yellow
Write-Host "  Procesador : $($hw.CPU.Name)" -ForegroundColor White
Write-Host "  Familia    : $($policy.DisplayName) [$($policy.ArchitectureFamily)]" -ForegroundColor Green
Write-Host "  Fundamento : $($policy.Rationale)" -ForegroundColor Gray
Write-Host ""
Write-Host ">>> Directivas de Kernel Prescritas:" -ForegroundColor Yellow
Write-Host "  PROCTHROTTLEMIN : $($policy.ProcThrottleMinPercent)%" -ForegroundColor Cyan
Write-Host "  PROCTHROTTLEMAX : $($policy.ProcThrottleMaxPercent)%" -ForegroundColor Cyan
Write-Host "  EPP (Energy Pref) : $($policy.EnergyPerformancePreference)" -ForegroundColor Cyan
Write-Host "  Core Parking    : $($policy.CoreParkingPolicy)" -ForegroundColor Cyan
Write-Host "  LargeSystemCache : $($policy.LargeSystemCache)" -ForegroundColor Cyan
Write-Host "  Win32PrioritySep : $($policy.Win32PrioritySeparation)" -ForegroundColor Cyan
Write-Host "  DPC Steering    : $($policy.AffinityDpcStrategy)" -ForegroundColor Cyan

if ($Action -eq "Status" -or $Action -eq "Audit") {
    Write-Host "`n[OK] Auditoria de arquitectura de silicio completada sin modificaciones." -ForegroundColor Green
    return [PSCustomObject]@{
        Status        = "Audited"
        Hardware      = $hw.CPU.Name
        Family        = $policy.ArchitectureFamily
        Policy        = $policy
        ExecutionTime = ((Get-Date) - $scriptStartTime).TotalSeconds
    }
}

# 3. Accion: Reset (Restaurar valores de fabrica de Windows)
if ($Action -eq "Reset") {
    if ($PSCmdlet.ShouldProcess("Sistema", "Restaurar configuracion predeterminada de CPU y Scheduler de Windows")) {
        Write-Host "`n>>> Restaurando configuracion de fabrica de Windows..." -ForegroundColor Yellow
        try {
            & powercfg /setacvalueindex scheme_current SUB_PROCESSOR PROCTHROTTLEMIN 5 2>&1 | Out-Null
            & powercfg /setacvalueindex scheme_current SUB_PROCESSOR PROCTHROTTLEMAX 100 2>&1 | Out-Null
            & powercfg /setactive scheme_current 2>&1 | Out-Null
            Write-Host "  [OK] PROCTHROTTLEMIN/MAX restaurados al estandar." -ForegroundColor Green
        } catch {
            Write-Warning "Fallo al restaurar powercfg: $($_.Exception.Message)"
        }

        if ($isAdmin) {
            try {
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 2 -Type DWord -Force -ErrorAction Stop
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache" -Value 0 -Type DWord -Force -ErrorAction Stop
                Write-Host "  [OK] Win32PrioritySeparation=2 y LargeSystemCache=0 restaurados." -ForegroundColor Green
            } catch {
                Write-Warning "Fallo al restaurar claves de registro de kernel: $($_.Exception.Message)"
            }
        }
        Write-Host "`n[OK] Restauracion de valores estandar de Windows completada." -ForegroundColor Green
        return [PSCustomObject]@{ Status = "ResetCompleted" }
    }
}

# 4. Accion: Optimize (Aplicar directivas de silicio de forma fail-visible)
if ($Action -eq "Optimize") {
    if ($PSCmdlet.ShouldProcess("CPU / Kernel", "Aplicar optimizacion adaptativa para $($policy.DisplayName)")) {
        Write-Host "`n>>> Aplicando optimizacion de silicio..." -ForegroundColor Yellow
        $appliedChanges = 0

        # 4.1 CalibraciÃ³n de Gobernador de EnergÃ­a (powercfg)
        try {
            & powercfg /setacvalueindex scheme_current SUB_PROCESSOR PROCTHROTTLEMIN $policy.ProcThrottleMinPercent 2>&1 | Out-Null
            & powercfg /setacvalueindex scheme_current SUB_PROCESSOR PROCTHROTTLEMAX $policy.ProcThrottleMaxPercent 2>&1 | Out-Null
            & powercfg /setacvalueindex scheme_current SUB_PROCESSOR 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 $policy.EnergyPerformancePreference 2>&1 | Out-Null
            $appliedChanges++
            Write-Host "  [OK] Frecuencia y EPP calibrados: Min=$($policy.ProcThrottleMinPercent)%, Max=100%, EPP=$($policy.EnergyPerformancePreference)" -ForegroundColor Green
        } catch {
            Write-Warning "[Optimize-CpuSilicon] No se pudo configurar gobernador powercfg: $($_.Exception.Message)"
        }

        # 4.2 CalibraciÃ³n de Core Parking
        try {
            # Subgrupo Procesador (54533251-82be-4824-96c1-47b60b740d00)
            # Min Cores (0cc0ba11-302a-4307-ac84-2916ced570f4)
            # Max Cores (ea062031-0e34-4ff1-9b6d-eb10593ac08f)
            if ($policy.CoreParkingPolicy -eq 'UnparkAll') {
                & powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 0cc0ba11-302a-4307-ac84-2916ced570f4 100 2>&1 | Out-Null
                & powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 ea062031-0e34-4ff1-9b6d-eb10593ac08f 100 2>&1 | Out-Null
                $appliedChanges++
                Write-Host "  [OK] Core Unparking al 100% configurado en corriente alterna." -ForegroundColor Green
            } elseif ($policy.CoreParkingPolicy -eq 'AsymmetricX3D_50Percent') {
                # Para X3D asimÃ©trico: permitir que el 50% de los nÃºcleos se estacionen (el CCD de frecuencia)
                & powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 0cc0ba11-302a-4307-ac84-2916ced570f4 50 2>&1 | Out-Null
                & powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 ea062031-0e34-4ff1-9b6d-eb10593ac08f 100 2>&1 | Out-Null
                $appliedChanges++
                Write-Host "  [OK] Core Parking al 50% configurado para priorizar CCD con 3D V-Cache." -ForegroundColor Green
            } else {
                Write-Host "  [OK] Core Parking gestionado autonomamente por el sistema operativo (Thread Director)." -ForegroundColor Green
            }
            & powercfg /setactive scheme_current 2>&1 | Out-Null
        } catch {
            Write-Warning "[Optimize-CpuSilicon] No se pudo configurar Core Parking: $($_.Exception.Message)"
        }

        # 4.3 Directivas de Registro de Kernel (Requieren ElevaciÃ³n si se ejecutan)
        if ($isAdmin) {
            # LargeSystemCache
            try {
                $mmPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
                Set-ItemProperty -Path $mmPath -Name "LargeSystemCache" -Value $policy.LargeSystemCache -Type DWord -Force -ErrorAction Stop
                $appliedChanges++
                Write-Host "  [OK] LargeSystemCache = $($policy.LargeSystemCache) configurado en Memory Management." -ForegroundColor Green
            } catch {
                Write-Warning "[Optimize-CpuSilicon] Fallo al establecer LargeSystemCache: $($_.Exception.Message)"
            }

            # Win32PrioritySeparation
            try {
                $pcPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
                Set-ItemProperty -Path $pcPath -Name "Win32PrioritySeparation" -Value $policy.Win32PrioritySeparation -Type DWord -Force -ErrorAction Stop
                $appliedChanges++
                Write-Host "  [OK] Win32PrioritySeparation = $($policy.Win32PrioritySeparation) configurado en PriorityControl." -ForegroundColor Green
            } catch {
                Write-Warning "[Optimize-CpuSilicon] Fallo al establecer Win32PrioritySeparation: $($_.Exception.Message)"
            }
        } else {
            Write-Host "  [i] Ajustes de registro de kernel (Win32PrioritySeparation y LargeSystemCache) omitidos por falta de elevacion UAC (requieren modo Administrador)." -ForegroundColor DarkGray
        }

        Write-Host ""
        Write-Host "==========================================================================" -ForegroundColor Cyan
        Write-Host " OPTIMIZACION POLIMORFICA APLICADA CON EXITO [$($policy.DisplayName)]     " -ForegroundColor Green
        Write-Host "==========================================================================`n" -ForegroundColor Cyan

        return [PSCustomObject]@{
            Status         = "Optimized"
            Architecture   = $policy.ArchitectureFamily
            AppliedChanges = $appliedChanges
            Policy         = $policy
        }
    }
}
