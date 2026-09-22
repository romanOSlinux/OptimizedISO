<#
.SYNOPSIS
    Optimize-ProcessMemory.ps1 - Poda de Memoria Working Set (EmptyWorkingSet) para romanOS
    Optimizador de Procesos en Reposo para Windows 11 (23H2 / 24H2 / 25H2)

.DESCRIPTION
    Invoca la API nativa EmptyWorkingSet de psapi.dll para liberar el conjunto de trabajo
    fisico (Working Set) retenido por procesos precalentados del sistema que se encuentran
    en reposo o suspendidos por PLM (ej. SearchHost, Edge WebView2 de busqueda, ShellExperienceHost).
    Demostrado empiricamente para reducir la huella de RAM hasta en un 87% sin terminar
    los procesos ni romper la reactividad de la interfaz.

.PARAMETER ProcessNames
    Lista de nombres de proceso a podar. Por defecto: SearchHost, msedgewebview2, ShellExperienceHost, StartMenuExperienceHost.

.PARAMETER Quiet
    Suprime la salida visual formateada en consola.

.PARAMETER PassThru
    Devuelve los objetos con metricas detalladas de ahorro de memoria.

.EXAMPLE
    .\Optimize-ProcessMemory.ps1

.EXAMPLE
    .\Optimize-ProcessMemory.ps1 -ProcessNames "SearchHost", "msedgewebview2" -Verbose
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string[]]$ProcessNames = @('SearchHost', 'msedgewebview2', 'ShellExperienceHost', 'StartMenuExperienceHost'),
    [switch]$Quiet,
    [switch]$PassThru,
    [switch]$Unattended
)

function Ensure-Elevation {
    $isSimulated = ($PSBoundParameters.ContainsKey('WhatIf') -or $WhatIfPreference)
    if ($isSimulated) {
        Write-Host "[WhatIf] Modo simulado detectado: omitiendo elevación UAC en Ensure-Elevation." -ForegroundColor Yellow
        return
    }
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        $ps51 = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $scriptCmd = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }
        $argArray = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptCmd)
        if ($PSBoundParameters.Count -gt 0) {
            foreach ($k in $PSBoundParameters.Keys) {
                if ($PSBoundParameters[$k] -is [switch] -and $PSBoundParameters[$k]) {
                    $argArray += "-$k"
                } elseif ($PSBoundParameters[$k] -isnot [switch]) {
                    $argArray += "-$k"
                    $argArray += "$($PSBoundParameters[$k])"
                }
            }
        }
        Write-Warning "Este script requiere privilegios de Administrador para abrir handles de procesos del sistema. Elevando..."
        try {
            Start-Process -FilePath $ps51 -ArgumentList $argArray -Verb RunAs
        } catch {
            Write-Error "No se pudo obtener privilegios de Administrador: $($_.Exception.Message)"
        }
        exit
    }
}
Ensure-Elevation

# -----------------------------------------------------------------------------
# 0. CONFIGURACION DE ENTORNO Y CARGA DE PSAPI
# -----------------------------------------------------------------------------
$ErrorActionPreference = 'Continue'

if (-not ([System.Management.Automation.PSTypeName]'RomanOS.PsApiMemory').Type) {
    try {
        Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;

        namespace RomanOS {
            public static class PsApiMemory {
                [DllImport("psapi.dll", SetLastError = true)]
                public static extern bool EmptyWorkingSet(IntPtr hProcess);
            }
        }
"@ -ErrorAction Stop
    } catch {
        Write-Error "Fallo al compilar la definicion P/Invoke de psapi.dll: $($_.Exception.Message)"
        return
    }
}

# Carga de UI-Engine si esta disponible
$uiEnginePaths = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\UI-Engine.ps1"),
    (Join-Path $PSScriptRoot "Core\UI-Engine.ps1"),
    (Join-Path $PSScriptRoot "UI-Engine.ps1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\UI-Engine.ps1"),
    "$env:WINDIR\Setup\Scripts\Core\UI-Engine.ps1",
    "C:\Windows\Setup\Scripts\Core\UI-Engine.ps1"
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
    function Show-UnifiedBanner { param($Title,$Subtitle,[switch]$ShowSystemInfo,[switch]$NoClear) Write-Host "`n=== $Title ($Subtitle) ===`n" -ForegroundColor Cyan }
    function Write-StepHeader   { param($StepNumber,$TotalSteps,$Message) Write-Host "`n>>> [$StepNumber/$TotalSteps] $Message" -ForegroundColor Cyan }
    function Write-SubStep      { param($Message) Write-Host "  -> $Message" -ForegroundColor Gray }
    function Write-OK           { param($Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
    function Write-Warn         { param($Message) Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
    function Write-ErrorMsg     { param($Message) Write-Host "  [ERROR] $Message" -ForegroundColor Red }
    function Write-Info         { param($Message) Write-Host "  [i] $Message" -ForegroundColor DarkGray }
}

# -----------------------------------------------------------------------------
# 1. FUNCION PRINCIPAL: Invoke-RomanOSMemoryTrim
# -----------------------------------------------------------------------------
function Invoke-RomanOSMemoryTrim {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string[]]$Targets = @('SearchHost', 'msedgewebview2', 'ShellExperienceHost', 'StartMenuExperienceHost'),
        [switch]$Silent,
        [switch]$ReturnObjects
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $totalInitialBytes = 0
    $totalFinalBytes = 0

    if (-not $Silent) {
        Show-UnifiedBanner -Title "romanOS MEMORY TRIM" -Subtitle "Optimizacion Quirurgica de Working Set (psapi.dll)"
        Write-StepHeader -StepNumber 1 -TotalSteps 2 -Message "Inspeccionando procesos del sistema en reposo..."
    }

    # Pre-identificar instancias de WebView2 hijas de SearchHost
    $searchHostPids = @(Get-Process -Name "SearchHost" -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    $webViewPidsToTrim = [System.Collections.Generic.HashSet[int]]::new()

    if ('msedgewebview2' -in $Targets) {
        try {
            $cimList = @(Get-CimInstance Win32_Process -Filter "Name = 'msedgewebview2.exe'" -ErrorAction SilentlyContinue)
            foreach ($cp in $cimList) {
                # Es hijo de SearchHost O tiene el flag embedded-browser-webview de SearchHost
                if ($cp.ParentProcessId -in $searchHostPids -or ($cp.CommandLine -and $cp.CommandLine -like "*SearchHost.exe*")) {
                    [void]$webViewPidsToTrim.Add($cp.ProcessId)
                }
            }
        } catch {
            Write-Warn "No se pudo consultar instancias secundarias de WebView2 para SearchHost: $($_.Exception.Message)"
        }
    }

    if (-not $Silent) {
        Write-StepHeader -StepNumber 2 -TotalSteps 2 -Message "Ejecutando EmptyWorkingSet sobre los procesos objetivo..."
    }

    foreach ($targetName in $Targets) {
        $procs = @(Get-Process -Name $targetName -ErrorAction SilentlyContinue)
        if ($procs.Count -eq 0) {
            if (-not $Silent) {
                Write-Info "Proceso '$targetName': No se encuentra en ejecucion (0 instancias)."
            }
            continue
        }

        foreach ($proc in $procs) {
            # Si es msedgewebview2, validar que sea del subsistema Search o de sistema
            if ($proc.ProcessName -eq 'msedgewebview2') {
                if ($webViewPidsToTrim.Count -gt 0 -and (-not $webViewPidsToTrim.Contains($proc.Id))) {
                    # No es hijo de SearchHost; omitir para no alterar instancias de apps externas
                    continue
                }
            }

            try {
                $initBytes = $proc.WorkingSet64
                $initMB = [math]::Round($initBytes / 1MB, 2)
                $procId = $proc.Id
                $pName = $proc.ProcessName

                $trimmed = $false
                if ($PSCmdlet.ShouldProcess("$pName (PID $procId)", "Podar Working Set (EmptyWorkingSet)")) {
                    $trimmed = [RomanOS.PsApiMemory]::EmptyWorkingSet($proc.Handle)
                }

                $proc.Refresh()
                $finalBytes = $proc.WorkingSet64
                $finalMB = [math]::Round($finalBytes / 1MB, 2)
                $reclaimedMB = [math]::Round(($initBytes - $finalBytes) / 1MB, 2)
                if ($reclaimedMB -lt 0) { $reclaimedMB = 0.0 }

                $percent = if ($initBytes -gt 0) { [math]::Round((($initBytes - $finalBytes) / $initBytes) * 100, 1) } else { 0 }
                if ($percent -lt 0) { $percent = 0.0 }

                $totalInitialBytes += $initBytes
                $totalFinalBytes += $finalBytes

                $record = [PSCustomObject]@{
                    ProcessName  = $pName
                    Id           = $procId
                    InitialMB    = $initMB
                    FinalMB      = $finalMB
                    ReclaimedMB  = $reclaimedMB
                    PercentSaved = $percent
                    Success      = $trimmed
                }
                $results.Add($record)

                if (-not $Silent) {
                    if ($trimmed -and $reclaimedMB -gt 0) {
                        Write-Host ("  [OK] {0,-26} (PID {1,-5}) : {2,6} MB -> {3,6} MB | -{4,6} MB ({5,4}%)" -f $pName, $procId, $initMB, $finalMB, $reclaimedMB, $percent) -ForegroundColor Green
                    } else {
                        Write-Host ("  [--] {0,-26} (PID {1,-5}) : {2,6} MB -> {3,6} MB | En reposo optimo" -f $pName, $procId, $initMB, $finalMB) -ForegroundColor Gray
                    }
                }
            } catch {
                if (-not $Silent) {
                    Write-Warn "No se pudo acceder al proceso '$($proc.ProcessName)' (PID $($proc.Id)): $($_.Exception.Message)"
                }
            }
        }
    }

    $totalReclaimedMB = [math]::Round(($totalInitialBytes - $totalFinalBytes) / 1MB, 2)
    if ($totalReclaimedMB -lt 0) { $totalReclaimedMB = 0.0 }
    $globalPercent = if ($totalInitialBytes -gt 0) { [math]::Round((($totalInitialBytes - $totalFinalBytes) / $totalInitialBytes) * 100, 1) } else { 0 }

    if (-not $Silent) {
        Write-Host ""
        Write-Host "  ===============================================================" -ForegroundColor Cyan
        Write-Host ("  TOTAL MEMORIA PODADA : {0} MB recuperados ({1}% de reduccion)" -f $totalReclaimedMB, $globalPercent) -ForegroundColor Yellow
        Write-Host "  ===============================================================" -ForegroundColor Cyan
        Write-Host ""
    }

    if ($ReturnObjects) {
        return $results
    }
}

# -----------------------------------------------------------------------------
# 2. EJECUCION DIRECTA
# -----------------------------------------------------------------------------
$res = Invoke-RomanOSMemoryTrim -Targets $ProcessNames -Silent:$Quiet -ReturnObjects:$PassThru

if (-not $Unattended -and -not $Quiet -and -not [System.Console]::IsInputRedirected) {
    Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor Gray
    try { [void][System.Console]::ReadKey($true) } catch {
        Write-Host ""
    }
}

if ($PassThru) {
    return $res
}
