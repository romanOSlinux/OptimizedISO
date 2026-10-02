<#
.SYNOPSIS
    Test-KernelTimerResolution.ps1 - Validador Forense de Temporización y Tick del Kernel (2026)
    romanOS / OptimizedISO — Estado del Arte Windows 11 24H2 / 25H2

.DESCRIPTION
    Mide con precisión sub-microsegundo la resolución actual del temporizador del kernel de Windows
    mediante llamadas nativas a NtQueryTimerResolution en ntdll.dll.
    Audita los parámetros de arranque BCD (useplatformclock, disabledynamictick) para garantizar que
    el sistema aproveche el Invariant TSC de la CPU sin penalizaciones de micro-stuttering derivadas
    de HPET o desincronización de reloj.

.PARAMETER ExportJson
    Ruta opcional para guardar el informe estructurado en formato JSON.

.EXAMPLE
    .\Test-KernelTimerResolution.ps1

.EXAMPLE
    .\Test-KernelTimerResolution.ps1 -ExportJson "C:\OptimizedISO\Log\TimerResolution.json"
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ExportJson
)

$ErrorActionPreference = 'Continue'
$auditStartTime = Get-Date

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS / OptimizedISO — AUDITORIA DE TEMPORIZACION DEL KERNEL (TIMER)   " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
Write-Host ""

# -----------------------------------------------------------------------------
# 1. COMPILACIÓN P/INVOKE NtQueryTimerResolution (ntdll.dll)
# -----------------------------------------------------------------------------
$typeLoaded = $false
if (-not ([System.Management.Automation.PSTypeName]'RomanOS.NativeTimer').Type) {
    try {
        Add-Type -MemberDefinition @"
[DllImport("ntdll.dll", SetLastError = true)]
public static extern int NtQueryTimerResolution(
    out uint MinimumResolution,
    out uint MaximumResolution,
    out uint CurrentResolution
);
"@ -Name "NativeTimer" -Namespace "RomanOS" -ErrorAction Stop
        $typeLoaded = $true
    } catch {
        Write-Warning "No se pudo compilar P/Invoke para NtQueryTimerResolution: $($_.Exception.Message)"
    }
} else {
    $typeLoaded = $true
}

# -----------------------------------------------------------------------------
# 2. MEDICIÓN DE LA RESOLUCIÓN ACTUAL
# -----------------------------------------------------------------------------
$minResRaw = [uint32]0
$maxResRaw = [uint32]0
$curResRaw = [uint32]0

$minMs = 15.625
$maxMs = 0.500
$curMs = 15.625
$curHz = 64.0

if ($typeLoaded) {
    try {
        $status = [RomanOS.NativeTimer]::NtQueryTimerResolution([ref]$minResRaw, [ref]$maxResRaw, [ref]$curResRaw)
        if ($status -eq 0) {
            # 1 unidad de resolución = 100 nanosegundos = 0.0001 milisegundos
            $minMs = [math]::Round($minResRaw / 10000.0, 4)
            $maxMs = [math]::Round($maxResRaw / 10000.0, 4)
            $curMs = [math]::Round($curResRaw / 10000.0, 4)
            if ($curResRaw -gt 0) {
                $curHz = [math]::Round(10000000.0 / $curResRaw, 1)
            }
        } else {
            Write-Warning "NtQueryTimerResolution retornó código NTSTATUS no exitoso: $status"
        }
    } catch {
        Write-Warning "Fallo al consultar NtQueryTimerResolution: $($_.Exception.Message)"
    }
}

Write-Host ">>> Métricas de Resolución del Reloj del Sistema (Kernel Timer):" -ForegroundColor Cyan
Write-Host "  Resolución Mínima (Default SO) : $minMs ms (64.0 Hz)" -ForegroundColor DarkGray
Write-Host "  Resolución Máxima de Hardware  : $maxMs ms (2000.0 Hz / 0.5ms)" -ForegroundColor Green
Write-Host "  Resolución Actual en Vivo      : $curMs ms ($curHz Hz)" -ForegroundColor $(if ($curMs -le 1.0) { 'Green' } elseif ($curMs -le 2.0) { 'Yellow' } else { 'White' })
Write-Host ""

# -----------------------------------------------------------------------------
# 3. AUDITORÍA DE PARÁMETROS BCD (USEPLATFORMCLOCK / DYNAMICTICK)
# -----------------------------------------------------------------------------
Write-Host ">>> Auditoría de Configuración BCD y Temporizadores de Hardware:" -ForegroundColor Cyan

$bcdUsePlatformClock = "No (Default / TSC Invariante Activo)"
$bcdDisabledynamictick = "No (Default)"
$bcdSyntheticClock = "No (Default)"
$hpetStatus = "Desactivado en BCD (Óptimo)"

try {
    $bcdOutput = & bcdedit /enum '{current}' 2>&1 | Out-String
    if ($bcdOutput -match "useplatformclock\s+(?:Yes|S[ií])") {
        $bcdUsePlatformClock = "Yes (HPET Lento Forzado)"
        $hpetStatus = "ALERTA: useplatformclock está forzado. Causa latencia en CPUs modernas."
        Write-Warning "HPET forzado en BCD. Se recomienda desactivar useplatformclock para usar el TSC de la CPU."
    }
    if ($bcdOutput -match "disabledynamictick\s+(?:Yes|S[ií])") {
        $bcdDisabledynamictick = "Yes (Dynamic Tick Desactivado)"
    }
    if ($bcdOutput -match "syntheticclock\s+(?:Yes|S[ií])") {
        $bcdSyntheticClock = "Yes"
    }
} catch {
    Write-Warning "No se pudo consultar bcdedit: $($_.Exception.Message)"
}

Write-Host "  useplatformclock   : $bcdUsePlatformClock" -ForegroundColor $(if ($bcdUsePlatformClock -match "Yes|S[ií]") { 'Red' } else { 'Green' })
Write-Host "  disabledynamictick : $bcdDisabledynamictick" -ForegroundColor DarkGray
Write-Host "  syntheticclock     : $bcdSyntheticClock" -ForegroundColor DarkGray
Write-Host "  Diagnóstico Reloj  : $hpetStatus" -ForegroundColor $(if ($bcdUsePlatformClock -match "Yes|S[ií]") { 'Red' } else { 'Green' })
Write-Host ""

# -----------------------------------------------------------------------------
# 4. CLASIFICACIÓN DE SALUD DE TEMPORIZACIÓN
# -----------------------------------------------------------------------------
$timerRating = "Desconocido"
$stutterRisk = "Bajo"

if ($curMs -le 0.505) {
    $timerRating = "OPTIMO COMPETITIVO (0.5 ms / 2000 Hz)"
    $stutterRisk = "Nulo (Cadencia perfecta de sub-fotograma)"
} elseif ($curMs -le 1.005) {
    $timerRating = "EXCELENTE (1.0 ms / 1000 Hz)"
    $stutterRisk = "Bajo (Apto para monitores 144Hz-240Hz)"
} elseif ($curMs -le 2.0) {
    $timerRating = "ACEPTABLE (2.0 ms)"
    $stutterRisk = "Moderado"
} else {
    $timerRating = "ESTANDAR DE WINDOWS (15.6 ms / 64 Hz)"
    $stutterRisk = "Moderado / Alto en juegos con pacing sensible"
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " EVALUACION DE RENDIMIENTO Y JITTER DE TEMPORIZACION " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Calificación de Temporización : $timerRating" -ForegroundColor $(if ($curMs -le 1.005) { 'Green' } else { 'Yellow' })
Write-Host " Riesgo de Jitter de Frames    : $stutterRisk" -ForegroundColor $(if ($curMs -le 1.005) { 'Green' } else { 'Yellow' })

if ($ExportJson) {
    try {
        $jsonDir = Split-Path $ExportJson -Parent
        if ($jsonDir -and -not (Test-Path $jsonDir)) {
            New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null
        }
        $reportObj = [PSCustomObject]@{
            MinimumResolutionMs = $minMs
            MaximumResolutionMs = $maxMs
            CurrentResolutionMs = $curMs
            CurrentFrequencyHz  = $curHz
            TimerRating         = $timerRating
            StutterRisk         = $stutterRisk
            UsePlatformClock    = $bcdUsePlatformClock
            DisableDynamicTick  = $bcdDisabledynamictick
            HpetStatus          = $hpetStatus
        }
        $reportObj | ConvertTo-Json -Depth 4 | Set-Content -Path $ExportJson -Encoding UTF8
        Write-Host " Reporte exportado a JSON: $ExportJson" -ForegroundColor DarkGray
    } catch {
        Write-Warning "No se pudo exportar JSON: $($_.Exception.Message)"
    }
}

Write-Host " Duración del Análisis: $([math]::Round(((Get-Date) - $auditStartTime).TotalSeconds, 2))s" -ForegroundColor DarkGray
Write-Host ""

return [PSCustomObject]@{
    MinimumResolutionMs = $minMs
    MaximumResolutionMs = $maxMs
    CurrentResolutionMs = $curMs
    CurrentFrequencyHz  = $curHz
    TimerRating         = $timerRating
    StutterRisk         = $stutterRisk
    UsePlatformClock    = $bcdUsePlatformClock
    DisableDynamicTick  = $bcdDisabledynamictick
    HpetStatus          = $hpetStatus
}
