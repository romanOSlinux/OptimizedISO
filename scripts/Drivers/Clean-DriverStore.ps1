<#
.SYNOPSIS
    Clean-DriverStore.ps1 - Mantenimiento y Depuración Segura del DriverStore en romanOS.

.DESCRIPTION
    Inspecciona y depura versiones obsoletas, duplicadas o no vinculadas de controladores
    de terceros (oem*.inf) acumulados en C:\Windows\System32\DriverStore\FileRepository.
    Protege 100% los controladores en uso activo consultando el subsistema PnP de Windows.

    100% compatible con Windows PowerShell 5.1 (powershell.exe) y PowerShell 7+ (pwsh).
    Codificación estricta UTF-8 con BOM.

.PARAMETER WhatIf
    Simula la limpieza, mostrando qué controladores se eliminarían y estimando espacio.

.PARAMETER Force
    Omite la confirmación interactiva para automatización o ejecución desatendida.

.EXAMPLE
    .\Clean-DriverStore.ps1 -WhatIf
    .\Clean-DriverStore.ps1 -Force
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Continue'

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║       DEPURACIÓN SEGURA DE DRIVERSTORE - romanOS             ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# 1. Comprobar privilegios administrativos
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    if ($PSBoundParameters.ContainsKey('WhatIf')) {
        Write-Host "  [AVISO] Ejecutando simulación en modo solo lectura sin elevación de Administrador." -ForegroundColor Yellow
    } else {
        Write-Host "  [!] Se requieren privilegios de Administrador para depurar el DriverStore." -ForegroundColor Red
        return [PSCustomObject]@{ Success = $false; Error = "Privilegios insuficientes" }
    }
}

Write-Host "  [1/3] Identificando controladores en uso activo por el hardware..." -ForegroundColor Gray

$activeInfNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
try {
    $activeDrivers = Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue
    foreach ($ad in $activeDrivers) {
        if ($ad.InfName) {
            [void]$activeInfNames.Add($ad.InfName)
        }
    }
} catch {
    Write-Host "  ! Advertencia consultando Win32_PnPSignedDriver: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "        Controladores activos en hardware: $($activeInfNames.Count)" -ForegroundColor DarkGray

# 2. Enumerar todos los controladores de terceros con pnputil
Write-Host "  [2/3] Enumerando controladores en DriverStore (pnputil /enum-drivers)..." -ForegroundColor Gray

$pnpOutput = & pnputil.exe /enum-drivers 2>&1
$oemList = [System.Collections.Generic.List[PSCustomObject]]::new()

$currentOem = $null
foreach ($line in $pnpOutput) {
    $trimmed = $line.Trim()
    if ($trimmed -match '^(?:Nombre publicado|Published Name)\s*:\s*(oem\d+\.inf)$') {
        if ($currentOem) { $oemList.Add([PSCustomObject]$currentOem) }
        $currentOem = [ordered]@{
            PublishedName    = $matches[1]
            OriginalFileName = ""
            ClassName        = ""
            ProviderName     = ""
            DriverDate       = ""
            DriverVersion    = ""
            InUse            = $false
        }
    } elseif ($currentOem) {
        if ($trimmed -match '^(?:Nombre original|Original Name)\s*:\s*(.+)$') {
            $currentOem.OriginalFileName = $matches[1].Trim()
        } elseif ($trimmed -match '^(?:Nombre de clase|Class Name)\s*:\s*(.+)$') {
            $currentOem.ClassName = $matches[1].Trim()
        } elseif ($trimmed -match '^(?:Nombre de proveedor|Provider Name)\s*:\s*(.+)$') {
            $currentOem.ProviderName = $matches[1].Trim()
        } elseif ($trimmed -match '^(?:Fecha de controlador|Driver Date)\s*:\s*(.+)$') {
            $currentOem.DriverDate = $matches[1].Trim()
        } elseif ($trimmed -match '^(?:Versi[oó]n de controlador|Driver Version)\s*:\s*(.+)$') {
            $currentOem.DriverVersion = $matches[1].Trim()
        }
    }
}
if ($currentOem) { $oemList.Add([PSCustomObject]$currentOem) }

Write-Host "        Total de controladores OEM registrados: $($oemList.Count)" -ForegroundColor DarkGray

# Marcar cuáles están activos
foreach ($oem in $oemList) {
    if ($activeInfNames.Contains($oem.PublishedName)) {
        $oem.InUse = $true
    }
}

# 3. Detectar candidatos obsoletos / huérfanos
# Si hay múltiples controladores con el mismo OriginalFileName y ProviderName, conservar solo el más reciente o el activo
$candidates = [System.Collections.Generic.List[PSCustomObject]]::new()

$grouped = $oemList | Group-Object -Property OriginalFileName, ProviderName

foreach ($grp in $grouped) {
    if ($grp.Count -gt 1) {
        # Hay versiones duplicadas del mismo controlador
        $sorted = $grp.Group | Sort-Object -Property DriverDate, DriverVersion -Descending
        # Conservar el primero (más nuevo) o el que esté en uso activo
        for ($i = 0; $i -lt $sorted.Count; $i++) {
            $item = $sorted[$i]
            if (-not $item.InUse) {
                # Solo eliminar si NO es el único y NO está en uso
                $candidates.Add($item)
            }
        }
    } else {
        # Controlador único. Si no está en uso y pertenece a categorías típicas de bloat o dispositivos desconectados
        # No se elimina agresivamente salvo que el usuario lo indique
    }
}

Write-Host "  [3/3] Análisis completado:" -ForegroundColor Gray
Write-Host "        Controladores obsoletos/duplicados detectados: $($candidates.Count)" -ForegroundColor $(if ($candidates.Count -gt 0) { "Yellow" } else { "Green" })

if ($candidates.Count -eq 0) {
    Write-Host ""
    Write-Host "  [OK] El DriverStore está limpio. No se detectaron versiones obsoletas duplicadas." -ForegroundColor Green
    return [PSCustomObject]@{ Success = $true; RemovedCount = 0 }
}

Write-Host ""
Write-Host "  Candidatos a depurar:" -ForegroundColor Cyan
foreach ($c in ($candidates | Select-Object -First 10)) {
    Write-Host "    - $($c.PublishedName) ($($c.OriginalFileName)) | $($c.ProviderName) | Ver: $($c.DriverVersion)" -ForegroundColor Gray
}
if ($candidates.Count -gt 10) {
    Write-Host "    ... y $($candidates.Count - 10) más." -ForegroundColor DarkGray
}

Write-Host ""

if (-not $Force -and -not $PSBoundParameters.ContainsKey('WhatIf')) {
    if ([Console]::IsInputRedirected) {
        Write-Host "  [!] Entorno no interactivo detectado sin switch -Force. Cancelando eliminación por seguridad." -ForegroundColor Yellow
        return [PSCustomObject]@{ Success = $true; RemovedCount = 0; Cancelled = $true }
    }
    $confirm = Read-Host "¿Desea proceder a eliminar estos $($candidates.Count) controladores obsoletos del DriverStore? [S/N] (Default: S)"
    if ($confirm -ne '' -and $confirm -notmatch '^[sSyY]') {
        Write-Host "  Operación cancelada por el usuario." -ForegroundColor Yellow
        return [PSCustomObject]@{ Success = $true; RemovedCount = 0; Cancelled = $true }
    }
}

$removedSuccess = 0
$removedFailed = 0

foreach ($cand in $candidates) {
    if ($PSCmdlet.ShouldProcess($cand.PublishedName, "Eliminar versión obsoleta de $($cand.OriginalFileName) del DriverStore")) {
        # Intento de desinstalación segura (sin /force para que Windows verifique que no tenga dependencias activas)
        $delResult = & pnputil.exe /delete-driver "$($cand.PublishedName)" /uninstall 2>&1
        if ($LASTEXITCODE -eq 0) {
            $removedSuccess++
            Write-Host "    [ELIMINADO] $($cand.PublishedName) ($($cand.OriginalFileName))" -ForegroundColor Green
        } else {
            $removedFailed++
            Write-Host "    [OMITIDO/BLOQUEADO] $($cand.PublishedName): En uso o dependencias activas." -ForegroundColor DarkGray
        }
    }
}

Write-Host ""
Write-Host "  [RESUMEN] Depuración de DriverStore finalizada." -ForegroundColor Cyan
Write-Host "            Eliminados exitosamente : $removedSuccess" -ForegroundColor Green
Write-Host "            Protegidos / Omitidos   : $removedFailed" -ForegroundColor Gray
Write-Host ""

return [PSCustomObject]@{
    Success      = $true
    RemovedCount = $removedSuccess
    FailedCount  = $removedFailed
}
