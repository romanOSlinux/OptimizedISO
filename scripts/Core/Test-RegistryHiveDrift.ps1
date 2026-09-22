<#
.SYNOPSIS
    Test-RegistryHiveDrift.ps1 - Auditor Forense de Persistencia de Registro y Desviación de Estado (2026)
    romanOS / OptimizedISO — Estado del Arte Windows 11 24H2 / 25H2

.DESCRIPTION
    Audita la resiliencia arquitectónica de las directivas declaradas en Policy-Engine.ps1
    frente al fenómeno de "Hive Drift" (sobreescritura silenciosa por OOBE, reseteos de usuario
    o actualizaciones de Windows). Clasifica cada directiva según su nivel de inmunidad (GPO forzada
    bajo Policies vs preferencias volátiles de usuario) y permite auditar en vivo o contra colmenas
    offline montadas.

.PARAMETER ProfileId
    Perfil de optimización a auditar: 1 (Gaming), 2 (Hardcore), 3 (Dev/Balanced). Default: 1.

.PARAMETER HivePath
    Ruta opcional a un archivo de colmena offline (ej. NTUSER.DAT o SOFTWARE de imagen WIM) para
    análisis forense aislado.

.PARAMETER ExportJson
    Ruta para guardar el reporte estructurado en formato JSON.

.EXAMPLE
    .\Test-RegistryHiveDrift.ps1 -ProfileId 1

.EXAMPLE
    .\Test-RegistryHiveDrift.ps1 -HivePath "C:\Mount\Users\Default\NTUSER.DAT"
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet(1, 2, 3)]
    [int]$ProfileId = 1,
    [string]$HivePath,
    [string]$ExportJson
)

$ErrorActionPreference = 'Continue'
$auditStartTime = Get-Date

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS / OptimizedISO — AUDITORIA DE RESILIENCIA Y PERSISTENCIA (DRIFT)" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Perfil Auditado: Perfil $ProfileId" -ForegroundColor DarkGray
Write-Host ""

# -----------------------------------------------------------------------------
# 1. CARGA DE MOTOR DE POLÍTICAS CANÓNICO (SSOT)
# -----------------------------------------------------------------------------
$policyEnginePath = Join-Path $PSScriptRoot "Policy-Engine.ps1"
if (-not (Test-Path $policyEnginePath)) {
    $policyEnginePath = "C:\OptimizedISO\scripts\Core\Policy-Engine.ps1"
}

if (-not (Test-Path $policyEnginePath)) {
    Write-Error "No se pudo localizar 'Policy-Engine.ps1' en '$policyEnginePath'. Abortando auditoría."
    return
}

try {
    . $policyEnginePath
    Write-Host "  [OK] Policy-Engine cargado con éxito." -ForegroundColor Green
} catch {
    Write-Error "Fallo crítico al importar Policy-Engine.ps1: $($_.Exception.Message)"
    return
}

# -----------------------------------------------------------------------------
# 2. SELECCIÓN Y CLASIFICACIÓN DE DIRECTIVAS SEGÚN INMUNIDAD A SOBREESCRITURA
# -----------------------------------------------------------------------------
$allPolicies = Get-RomanOSPolicies
$targetPolicies = @($allPolicies | Where-Object { $_.Profiles -contains $ProfileId })

Write-Host "  Directivas Totales en Catálogo   : $($allPolicies.Count)" -ForegroundColor White
Write-Host "  Directivas Asignadas al Perfil   : $($targetPolicies.Count)" -ForegroundColor White
Write-Host ""

$gpoImmuneCount = 0
$kernelProtectedCount = 0
$oobeVolatileCount = 0
$userScopeCount = 0

$detailedReport = [System.Collections.Generic.List[PSCustomObject]]::new()
$liveMatchedCount = 0
$liveDiscrepantCount = 0
$liveMissingCount = 0

foreach ($pol in $targetPolicies) {
    $regKey = $pol.RegistryKey
    $valName = $pol.ValueName
    $expectedVal = $pol.ExpectedValue

    # Clasificación de Resiliencia Arquitectónica
    $immunityTier = "Desconocido"
    $driftRisk = "Bajo"
    $persistenceMechanism = ""

    if ($regKey -match "\\Policies\\") {
        $immunityTier = "GPO Inmune (Forzada)"
        $driftRisk = "Nulo"
        $persistenceMechanism = "Bloqueo por directiva de grupo del sistema. Imposible de revertir por OOBE o interfaz de usuario."
        $gpoImmuneCount++
    } elseif ($regKey -match "^HKLM\\SYSTEM\\CurrentControlSet") {
        $immunityTier = "Kernel / System Level"
        $driftRisk = "Bajo"
        $persistenceMechanism = "Persiste en colmena SYSTEM. Requerida por drivers y subsistemas de bajo nivel."
        $kernelProtectedCount++
    } elseif ($regKey -match "^HKCU" -or $pol.PSPath -match "^HKCU") {
        $immunityTier = "User Profile Volatile"
        $driftRisk = "Medio / Alto"
        $persistenceMechanism = "Requiere inyección en Default User (NTUSER.DAT) o SetupComplete.cmd para propagarse a nuevos usuarios."
        $userScopeCount++
        $oobeVolatileCount++
    } elseif ($regKey -match "^HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion") {
        $immunityTier = "Software Preference"
        $driftRisk = "Medio"
        $persistenceMechanism = "Preferencia del sistema. Windows 11 puede resetearla si una actualización o OOBE aprovisiona la característica."
        $oobeVolatileCount++
    } else {
        $immunityTier = "Global HKLM Standard"
        $driftRisk = "Bajo"
        $persistenceMechanism = "Configuración global de máquina."
        $gpoImmuneCount++
    }

    # Auditoría en Vivo (Live Registry Check) si no se usa colmena offline
    $liveStatus = "N/A"
    $currentVal = $null
    if (-not $HivePath) {
        try {
            $psPath = $pol.PSPath
            if ($psPath -and (Test-Path $psPath)) {
                $prop = Get-ItemProperty -Path $psPath -Name $valName -ErrorAction Stop
                $currentVal = $prop.$valName
                if ($null -ne $currentVal -and "$currentVal" -eq "$expectedVal") {
                    $liveStatus = "MATCH"
                    $liveMatchedCount++
                } else {
                    $liveStatus = "DISCREPANCY"
                    $liveDiscrepantCount++
                }
            } else {
                $liveStatus = "MISSING_KEY"
                $liveMissingCount++
            }
        } catch {
            $liveStatus = "MISSING_VALUE"
            $liveMissingCount++
        }
    }

    $detailedReport.Add([PSCustomObject]@{
        Id                    = $pol.Id
        Category              = $pol.Category
        RegistryKey           = $regKey
        ValueName             = $valName
        ExpectedValue         = $expectedVal
        Type                  = $pol.Type
        ImmunityTier          = $immunityTier
        DriftRisk             = $driftRisk
        PersistenceMechanism  = $persistenceMechanism
        LiveStatus            = $liveStatus
        CurrentValue          = $currentVal
        OfficialDoc           = $pol.OfficialDoc
    })
}

# -----------------------------------------------------------------------------
# 3. AUDITORÍA FORENSE DE COLMENA OFFLINE (SI SE PASA -HivePath)
# -----------------------------------------------------------------------------
$hiveAuditSummary = $null
if ($HivePath) {
    Write-Host ">>> Analizando colmena offline: $HivePath" -ForegroundColor Cyan
    if (-not (Test-Path $HivePath)) {
        Write-Warning "El archivo de colmena indicado no existe: '$HivePath'"
    } else {
        $mountKey = "HKLM\Offline_AuditHive_" + (Get-Random)
        $mounted = $false
        try {
            Write-Host "  -> Montando colmena en '$mountKey'..." -ForegroundColor DarkGray
            & reg.exe load "$mountKey" "$HivePath" 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $mounted = $true
                Write-Host "  [OK] Colmena montada correctamente." -ForegroundColor Green

                # Evaluar directivas que coincidan con la colmena montada
                $matchedOffline = 0
                $missingOffline = 0
                $discrepantOffline = 0

                foreach ($pol in $targetPolicies) {
                    # Truncar la raíz para mapear a la colmena montada
                    $subPath = ""
                    if ($HivePath -match "NTUSER\.DAT" -and $pol.RegistryKey -match "^HKCU\\(.*)") {
                        $subPath = $Matches[1]
                    } elseif ($pol.RegistryKey -match "^HKLM\\SOFTWARE\\(.*)") {
                        $subPath = $Matches[1]
                    } elseif ($pol.RegistryKey -match "^HKLM\\SYSTEM\\(.*)") {
                        $subPath = $Matches[1]
                    }

                    if ($subPath) {
                        $targetRegKey = "$mountKey\$subPath"
                        try {
                            $valQuery = & reg.exe query "$targetRegKey" /v "$($pol.ValueName)" 2>&1
                            if ($LASTEXITCODE -eq 0) {
                                if ($valQuery -match [regex]::Escape("$($pol.ExpectedValue)")) {
                                    $matchedOffline++
                                } else {
                                    $discrepantOffline++
                                }
                            } else {
                                $missingOffline++
                            }
                        } catch {
                            $missingOffline++
                        }
                    }
                }

                $hiveAuditSummary = [PSCustomObject]@{
                    HivePath          = $HivePath
                    MatchedOffline    = $matchedOffline
                    MissingOffline    = $missingOffline
                    DiscrepantOffline = $discrepantOffline
                }
                Write-Host "  Directivas Coincidentes en Colmena : $matchedOffline" -ForegroundColor Green
                Write-Host "  Directivas Faltantes en Colmena     : $missingOffline" -ForegroundColor Yellow
                Write-Host "  Directivas con Valor Discrepante    : $discrepantOffline" -ForegroundColor Red
            } else {
                Write-Warning "reg.exe load retornó código de error $LASTEXITCODE. Verifique permisos de Administrador."
            }
        } catch {
            Write-Warning "Error durante el análisis de la colmena: $($_.Exception.Message)"
        } finally {
            if ($mounted) {
                Write-Host "  -> Desmontando colmena '$mountKey'..." -ForegroundColor DarkGray
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
                & reg.exe unload "$mountKey" 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  [OK] Colmena desmontada limpiamente (cero fugas de handle)." -ForegroundColor Green
                } else {
                    Write-Warning "No se pudo desmontar colmena inmediatamente. Código: $LASTEXITCODE"
                }
            }
        }
    }
}

# -----------------------------------------------------------------------------
# 4. CALCULO DE MÉTRICAS Y SCORE DE RESILIENCIA
# -----------------------------------------------------------------------------
$totalTarget = $targetPolicies.Count
$hardenedCount = $gpoImmuneCount + $kernelProtectedCount
$resilienceScore = if ($totalTarget -gt 0) { [math]::Round(($hardenedCount / $totalTarget) * 100, 1) } else { 0 }

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " METRICAS DE RESILIENCIA Y PREVENCION DE DRIFT " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Directivas Totales Evaluadas   : $totalTarget" -ForegroundColor White
Write-Host " Directivas Inmunes a Drift     : $hardenedCount ($resilienceScore% del Catálogo)" -ForegroundColor Green
Write-Host "   - Blindadas por GPO Policies : $gpoImmuneCount" -ForegroundColor Green
Write-Host "   - Nivel Kernel / SYSTEM      : $kernelProtectedCount" -ForegroundColor Green
Write-Host " Directivas Volátiles / OOBE    : $oobeVolatileCount ($([math]::Round(($oobeVolatileCount/$totalTarget)*100, 1))%)" -ForegroundColor Yellow
Write-Host "   (Requieren doble inyección en Default User y SetupComplete para persistir)" -ForegroundColor DarkGray

if (-not $HivePath) {
    Write-Host ""
    Write-Host "--- ESTADO DE AUDITORIA EN VIVO (HOST ACTUAL) ---" -ForegroundColor Cyan
    Write-Host " Directivas Coincidentes (MATCH)    : $liveMatchedCount" -ForegroundColor Green
    Write-Host " Directivas Discrepantes            : $liveDiscrepantCount" -ForegroundColor $(if ($liveDiscrepantCount -gt 0) { 'Yellow' } else { 'Green' })
    Write-Host " Directivas Faltantes en Host       : $liveMissingCount" -ForegroundColor DarkGray
}

if ($ExportJson) {
    try {
        $jsonDir = Split-Path $ExportJson -Parent
        if ($jsonDir -and -not (Test-Path $jsonDir)) {
            New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null
        }
        $detailedReport | ConvertTo-Json -Depth 4 | Set-Content -Path $ExportJson -Encoding UTF8
        Write-Host " Reporte detallado guardado en: $ExportJson" -ForegroundColor DarkGray
    } catch {
        Write-Warning "No se pudo escribir JSON: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host " Duración del Análisis: $([math]::Round(((Get-Date) - $auditStartTime).TotalSeconds, 2))s" -ForegroundColor DarkGray
Write-Host ""

return [PSCustomObject]@{
    TotalPolicies       = $totalTarget
    ResilienceScore     = $resilienceScore
    GpoImmuneCount      = $gpoImmuneCount
    KernelProtected     = $kernelProtectedCount
    OobeVolatileCount   = $oobeVolatileCount
    LiveMatched         = $liveMatchedCount
    LiveDiscrepant      = $liveDiscrepantCount
    LiveMissing         = $liveMissingCount
    HiveOfflineSummary  = $hiveAuditSummary
    DetailedReport      = $detailedReport
}
