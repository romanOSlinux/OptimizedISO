<#
.SYNOPSIS
    Optimize-WebBrowsers.ps1 - Modulo Dedicado de Optimizacion y Debloat de Navegadores (PLAN-0033 / PLAN-0047)
.DESCRIPTION
    Aplica directivas GPO oficiales de rendimiento, debloat y telemetria para 
    Microsoft Edge, Google Chrome, Mozilla Firefox y Brave Browser.
    
    Depende de Core\Policy-Engine.ps1 como Fuente Unica de Verdad (SSOT) y Core\UI-Engine.ps1.
    Auto-eleva privilegios de Administrador automaticamente si es necesario.
    Guarda codificacion UTF-8 con BOM y es 100% compatible con Windows PowerShell 5.1.
#>
[CmdletBinding()]
param (
    [ValidateSet("All", "Edge", "Chrome", "Firefox", "Brave")]
    [string]$Browser,
    
    [switch]$Audit,
    [switch]$Unattended,
    [switch]$Quiet
)

$ErrorActionPreference = "Continue"

function Ensure-Elevation {
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
        Write-Warning "Este script requiere privilegios de Administrador. Reiniciando de forma elevada..."
        try {
            Start-Process -FilePath $ps51 -ArgumentList $argArray -Verb RunAs
        } catch {
            Write-Error "No se pudo obtener privilegios de Administrador: $($_.Exception.Message)"
        }
        exit
    }
}

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

# -----------------------------------------------------------------------------
# 1. CARGA DE MOTORES CENTRALIZADOS (Core\Policy-Engine.ps1 y Core\UI-Engine.ps1)
# -----------------------------------------------------------------------------
$policyEnginePaths = @(
    (Join-Path (Split-Path $scriptPath -Parent) "Core\Policy-Engine.ps1"),
    (Join-Path $scriptPath "Core\Policy-Engine.ps1"),
    (Join-Path $scriptPath "Policy-Engine.ps1"),
    (Join-Path (Split-Path $scriptPath -Parent) "scripts\Core\Policy-Engine.ps1"),
    "$env:WINDIR\Setup\Scripts\Core\Policy-Engine.ps1",
    "C:\Windows\Setup\Scripts\Core\Policy-Engine.ps1"
)
$policyLoaded = $false
foreach ($p in $policyEnginePaths) {
    if (Test-Path $p) {
        . $p
        $policyLoaded = $true
        break
    }
}

if (-not $policyLoaded) {
    Write-Host "  [ERROR] No se encuentra Policy-Engine.ps1 en ninguna ruta conocida:" -ForegroundColor Red
    $policyEnginePaths | ForEach-Object { Write-Host "    - $_" -ForegroundColor DarkRed }
    Write-Host "  Este script requiere el motor centralizado (SSOT) para funcionar." -ForegroundColor Red
    exit 1
}

$uiEnginePaths = @(
    (Join-Path (Split-Path $scriptPath -Parent) "Core\UI-Engine.ps1"),
    (Join-Path $scriptPath "Core\UI-Engine.ps1"),
    (Join-Path $scriptPath "UI-Engine.ps1"),
    (Join-Path (Split-Path $scriptPath -Parent) "scripts\Core\UI-Engine.ps1"),
    "$env:WINDIR\Setup\Scripts\Core\UI-Engine.ps1",
    "C:\Windows\Setup\Scripts\Core\UI-Engine.ps1"
)
$uiLoaded = $false
foreach ($u in $uiEnginePaths) {
    if (Test-Path $u) {
        . $u
        $uiLoaded = $true
        break
    }
}

if (-not $uiLoaded) {
    function Write-StepHeader    { param($StepNumber, $TotalSteps, $Message) Write-Host "`n[$StepNumber/$TotalSteps] $Message" -ForegroundColor Cyan }
    function Write-Success       { param($Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
    function Write-Warn          { param($Message) Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
    function Write-ErrorMsg      { param($Message) Write-Host "  [ERROR] $Message" -ForegroundColor Red }
    function Write-Info          { param($Message) Write-Host "  [i] $Message" -ForegroundColor DarkGray }
    function Show-UnifiedMenu    { param($Title,$Options,[int]$DefaultChoice=1,[switch]$AllowCancel,[string]$CancelText="Salir") for($i=0;$i -lt $Options.Count;$i++){ Write-Host "  [$($i+1)] $($Options[$i])" }; if($AllowCancel){ Write-Host "  [0] $CancelText" }; $r=Read-Host "  Opcion"; if(-not $r){return $DefaultChoice}; return [int]$r }
    function Show-UnifiedSummary { param($Title,$Status,$DurationSeconds,$ErrorsCount,$WarnsCount,$Logs) Write-Host "`n=== $($Title): $Status (${DurationSeconds}s) ===`n" -ForegroundColor Cyan }
}

# -----------------------------------------------------------------------------
# 2. DETERMINACION DE MODO Y NAVEGADOR OBJETIVO
# -----------------------------------------------------------------------------
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$isInteractive = (-not $Unattended -and -not $Audit -and [string]::IsNullOrEmpty($Browser) -and -not [Console]::IsInputRedirected)
$targetBrowser = if (-not [string]::IsNullOrEmpty($Browser)) { $Browser } else { "All" }
$doAudit = [bool]$Audit

if ($isInteractive) {
    Write-Host "`n==========================================================================" -ForegroundColor Cyan
    Write-Host "  OPTIMIZACION Y DEBLOAT OFICIAL DE NAVEGADORES (GPO)                     " -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  Aplica directivas oficiales de rendimiento GPU, ahorro de RAM/CPU," -ForegroundColor Gray
    Write-Host "  privacidad estricta y eliminacion de telemetria e IA publicitaria." -ForegroundColor Gray
    Write-Host ""

    $menuOptions = @(
        "Todos los navegadores (Edge, Chrome, Firefox, Brave) [Recomendado]",
        "Solo Microsoft Edge",
        "Solo Google Chrome",
        "Solo Mozilla Firefox",
        "Solo Brave Browser",
        "Auditar directivas actuales (modo solo lectura)"
    )

    $choice = Show-UnifiedMenu -Title "Selecciona una accion para los navegadores web" -Options $menuOptions -DefaultChoice 1 -AllowCancel -CancelText "Salir sin realizar cambios"

    switch ($choice) {
        1 { $targetBrowser = "All";     $doAudit = $false }
        2 { $targetBrowser = "Edge";    $doAudit = $false }
        3 { $targetBrowser = "Chrome";  $doAudit = $false }
        4 { $targetBrowser = "Firefox"; $doAudit = $false }
        5 { $targetBrowser = "Brave";   $doAudit = $false }
        6 { $targetBrowser = "All";     $doAudit = $true }
        default {
            Write-Host "`n  Operacion cancelada por el usuario. Saliendo..." -ForegroundColor Yellow
            exit 0
        }
    }
}

# La auditoria no requiere privilegios de Administrador (lectura HKLM). La aplicacion si requiere elevacion.
if (-not $doAudit) {
    Ensure-Elevation
}

# -----------------------------------------------------------------------------
# 3. EJECUCION DE AUDITORIA O APLICACION
# -----------------------------------------------------------------------------
$errorsCount = 0
$warnsCount = 0

if ($doAudit) {
    Write-StepHeader -StepNumber 1 -TotalSteps 1 -Message "Auditando estado de directivas de navegadores ($targetBrowser)..."
    $policies = Get-RomanOSBrowserPolicies -Browser $targetBrowser
    $appliedCount = 0

    foreach ($p in $policies) {
        $val = Get-ItemPropertyValue -Path $p.PSPath -Name $p.ValueName -ErrorAction SilentlyContinue
        $isMatch = $false
        if ($p.Type -eq "REG_SZ" -and [string]::IsNullOrEmpty($p.ExpectedValue)) {
            if ([string]::IsNullOrEmpty($val)) { $isMatch = $true }
        } elseif ($null -ne $val -and $val -eq $p.ExpectedValue) {
            $isMatch = $true
        }

        if ($isMatch) {
            $appliedCount++
            if (-not $Quiet) { Write-Host "  [OK] $($p.Browser): $($p.ValueName) = $val" -ForegroundColor Green }
        } else {
            if (-not $Quiet) { Write-Host "  [PENDIENTE] $($p.Browser): $($p.ValueName)" -ForegroundColor DarkGray }
        }
    }

    $sw.Stop()
    $status = if ($appliedCount -eq $policies.Count -and $policies.Count -gt 0) { "SUCCESS" } else { "WARNING" }
    
    $logMap = @{
        "Navegador Evaluado" = $targetBrowser
        "Politicas Activas"  = "$appliedCount de $($policies.Count)"
    }
    Show-UnifiedSummary -Title "Auditoria de Navegadores ($targetBrowser)" -Status $status -DurationSeconds ([int]$sw.Elapsed.TotalSeconds) -ErrorsCount ($policies.Count - $appliedCount) -WarnsCount 0 -Logs $logMap

    Write-Host "  Politicas activas: $appliedCount de $($policies.Count)" -ForegroundColor Cyan
    if ($isInteractive) {
        Write-Host ""
        Read-Host "  Presione ENTER para volver o cerrar..."
    }
    if ($appliedCount -eq $policies.Count) { exit 0 } else { exit 1 }
}

# MODO APLICACION
Write-StepHeader -StepNumber 1 -TotalSteps 2 -Message "Aplicando directivas GPO oficiales para: $targetBrowser..."

$appliedText = "0"
try {
    $result = Apply-RomanOSBrowserPolicies -Browser $targetBrowser -VerboseOutput:(-not $Quiet)
    $errorsCount += $result.Failed
    $appliedText = "$($result.Applied) de $($result.Total)"
} catch {
    $errorsCount++
    Write-ErrorMsg "Error durante la aplicacion de directivas de navegadores: $($_.Exception.Message)"
}

Write-StepHeader -StepNumber 2 -TotalSteps 2 -Message "Aplicando directivas de Copilot e IA a nivel de sistema..."

try {
    # Desactivacion de Copilot e IA publicitaria en Windows
    $copilotPolicies = @(
        @{ Path = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI";      Name = "DisableAIDataAnalysis"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows AI";     Name = "DisableAIDataAnalysis"; Value = 1 }
    )

    foreach ($cp in $copilotPolicies) {
        if (-not (Test-Path $cp.Path)) {
            New-Item -Path $cp.Path -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Set-ItemProperty -Path $cp.Path -Name $cp.Name -Value $cp.Value -Type DWord -Force -ErrorAction SilentlyContinue
    }
    Write-Success "Politicas de Copilot e IA a nivel de sistema aseguradas."
} catch {
    $warnsCount++
    Write-Warn "No se pudieron actualizar algunas claves de Copilot: $($_.Exception.Message)"
}

$sw.Stop()
$finalStatus = if ($errorsCount -eq 0 -and $warnsCount -eq 0) { "SUCCESS" } elseif ($errorsCount -eq 0) { "WARNING" } else { "FAILED" }

$logMap = @{
    "Navegador Objetivo" = $targetBrowser
    "Directivas GPO"     = $appliedText
    "Copilot e IA"       = "Desactivadas en Windows"
}
Show-UnifiedSummary -Title "Optimizacion de Navegadores ($targetBrowser)" -Status $finalStatus -DurationSeconds ([int]$sw.Elapsed.TotalSeconds) -ErrorsCount $errorsCount -WarnsCount $warnsCount -Logs $logMap

if ($isInteractive) {
    Write-Host ""
    Read-Host "  Presione ENTER para salir..."
}

exit 0