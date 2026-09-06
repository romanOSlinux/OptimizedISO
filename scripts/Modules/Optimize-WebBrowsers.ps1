<#
.SYNOPSIS
    Optimize-WebBrowsers.ps1 - Módulo Dedicado de Optimización de Navegadores (PLAN-0033)
.DESCRIPTION
    Aplica directivas GPO oficiales de rendimiento, debloat y telemetría para 
    Microsoft Edge, Google Chrome, Mozilla Firefox y Brave Browser.
    
    Depende de Core\Policy-Engine.ps1 como Fuente Única de Verdad (SSOT).
    Guarda codificación UTF-8 con BOM y es 100% compatible con Windows PowerShell 5.1.
#>
[CmdletBinding()]
param (
    [ValidateSet("All", "Edge", "Chrome", "Firefox", "Brave")]
    [string]$Browser = "All",
    
    [switch]$Audit
)

$ErrorActionPreference = "Stop"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$policyEnginePath = Join-Path $scriptPath "Core\Policy-Engine.ps1"

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host "  OPTIMIZACIÓN Y DEBLOAT OFICIAL DE NAVEGADORES (GPO)                     " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

if (-not (Test-Path $policyEnginePath)) {
    Write-Host "  [ERROR] No se encuentra Policy-Engine.ps1 en $policyEnginePath." -ForegroundColor Red
    Write-Host "  Este script requiere el motor centralizado (SSOT) para funcionar." -ForegroundColor Red
    exit 1
}

# Importar el motor
. $policyEnginePath

if ($Audit) {
    Write-Host "  [AUDITORÍA] Verificando estado de las directivas de navegadores ($Browser)..." -ForegroundColor Yellow
    $policies = Get-RomanOSBrowserPolicies -Browser $Browser
    $appliedCount = 0
    foreach ($p in $policies) {
        $val = Get-ItemPropertyValue -Path $p.PSPath -Name $p.ValueName -ErrorAction SilentlyContinue
        # Para REG_SZ, si ExpectedValue es "", $val también debe ser null o ""
        if ($p.Type -eq "REG_SZ" -and [string]::IsNullOrEmpty($p.ExpectedValue)) {
            if ([string]::IsNullOrEmpty($val)) { $appliedCount++ }
        } elseif ($null -ne $val -and $val -eq $p.ExpectedValue) {
            $appliedCount++
        }
    }
    
    Write-Host "  -> Políticas activas: $appliedCount de $($policies.Count)" -ForegroundColor Cyan
    if ($appliedCount -eq $policies.Count -and $policies.Count -gt 0) {
        Write-Host "  [ESTADO] COMPLETO: Todas las optimizaciones están aplicadas." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "  [ESTADO] INCOMPLETO: Faltan optimizaciones por aplicar." -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "  [INFO] Aplicando directivas oficiales centralizadas desde Core\Policy-Engine.ps1..." -ForegroundColor Cyan

try {
    $result = Apply-RomanOSBrowserPolicies -Browser $Browser -VerboseOutput:$true
    
    # También desactivamos Copilot a nivel de sistema por paridad con el comportamiento legacy
    $hkcuCopilot = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
    if (-not (Test-Path $hkcuCopilot)) { New-Item -Path $hkcuCopilot -Force | Out-Null }
    Set-ItemProperty -Path $hkcuCopilot -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    
    $hklmCopilot = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
    if (-not (Test-Path $hklmCopilot)) { New-Item -Path $hklmCopilot -Force | Out-Null }
    Set-ItemProperty -Path $hklmCopilot -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    
    $hklmAI = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows AI"
    if (-not (Test-Path $hklmAI)) { New-Item -Path $hklmAI -Force | Out-Null }
    Set-ItemProperty -Path $hklmAI -Name "DisableAIDataAnalysis" -Value 1 -Type DWord -ErrorAction SilentlyContinue

    Write-Host "  [OK] Políticas de Copilot e IA a nivel de sistema aplicadas." -ForegroundColor Green

    Write-Host "`n  [RESUMEN] Directivas de $Browser procesadas." -ForegroundColor Cyan
    Write-Host "  -> Aplicadas con éxito: $($result.Applied) / $($result.Total)" -ForegroundColor Green
    if ($result.Failed -gt 0) {
        Write-Host "  -> Fallidas/Ignoradas: $($result.Failed)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [ERROR] Excepción crítica durante la aplicación de directivas: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
