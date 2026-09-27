<#
.SYNOPSIS
Configura automáticamente el entorno completo de desarrollo, directivas, reglas, hooks y skills de Antigravity en Windows.

.DESCRIPTION
Prepara una máquina Windows recién instalada (o existente) para trabajar al 100% con Antigravity y el proyecto OptimizedISO:
1. Copia e inicializa reglas globales, skills y hooks en ($HOME\.gemini\config).
2. Audita dependencias esenciales (Git, Windows ADK / oscdimg, Hyper-V, PowerShell 7).
3. Opcionalmente instala herramientas faltantes vía Windows Package Manager (winget).
4. Configura ExecutionPolicy para ejecución sin trabas de scripts.
5. Ejecuta las verificaciones de sanidad de ADK y PowerShell.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [switch]$CheckOnly,

    [Parameter(Mandatory = $false)]
    [switch]$InstallPrerequisites,

    [Parameter(Mandatory = $false)]
    [switch]$EnableHyperV,

    [Parameter(Mandatory = $false)]
    [switch]$SetExecutionPolicy
)

$ErrorActionPreference = 'Stop'

function Write-StepHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "   $Title" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-StatusItem {
    param(
        [string]$Name,
        [bool]$Status,
        [string]$Detail = ""
    )
    if ($Status) {
        Write-Host "  [OK] " -ForegroundColor Green -NoNewline
        Write-Host "$Name" -ForegroundColor White -NoNewline
        if ($Detail) { Write-Host " ($Detail)" -ForegroundColor Gray } else { Write-Host "" }
    } else {
        Write-Host "  [FALTA] " -ForegroundColor Yellow -NoNewline
        Write-Host "$Name" -ForegroundColor Yellow -NoNewline
        if ($Detail) { Write-Host " - $Detail" -ForegroundColor DarkYellow } else { Write-Host "" }
    }
}

Write-StepHeader "INICIALIZADOR DE ENTORNO ANTIGRAVITY & OPTIMIZEDISO (WINDOWS)"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$AgentsDir = Join-Path $ProjectRoot ".agents"
$GlobalConfigDir = Join-Path $HOME ".gemini\config"

# -------------------------------------------------------------------------
# FASE 1: AUDITORIA DE REQUISITOS DEL SISTEMA
# -------------------------------------------------------------------------
Write-Host "--- 1. Auditoria de Prerrequisitos de Software ---" -ForegroundColor Yellow

$gitCmd = Get-Command "git.exe" -ErrorAction SilentlyContinue
$gitInstalled = ($null -ne $gitCmd)

$pwshCmd = Get-Command "pwsh.exe" -ErrorAction SilentlyContinue
$pwshInstalled = ($null -ne $pwshCmd)

# Comprobar oscdimg en PATH o rutas estandar de ADK
$oscdimgPaths = @(
    "oscdimg.exe",
    "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
    "${env:ProgramFiles}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
)
$oscdimgPath = $null
foreach ($p in $oscdimgPaths) {
    $found = Get-Command $p -ErrorAction SilentlyContinue
    if ($null -ne $found) {
        $oscdimgPath = $found.Source
        break
    } elseif (Test-Path $p) {
        $oscdimgPath = $p
        break
    }
}
$adkInstalled = ($null -ne $oscdimgPath)

# Comprobar Hyper-V
$hyperVEnabled = $false
try {
    $hvFeature = Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -ErrorAction SilentlyContinue
    if ($hvFeature -and $hvFeature.State -eq 'Enabled') {
        $hyperVEnabled = $true
    }
} catch {
    Write-Debug "Característica Hyper-V requiere elevación o no está disponible: $($_.Exception.Message)"
}

# Comprobar Antigravity CLI o IDE
$agyCmd = Get-Command "agy.exe" -ErrorAction SilentlyContinue
$antigravityAppData = Test-Path (Join-Path $HOME ".gemini\antigravity-ide")
$antigravityPresent = ($null -ne $agyCmd) -or $antigravityAppData

$gitDetail = if ($gitInstalled) { (git --version) } else { "Requerido para control de versiones y trazabilidad" }
$adkDetail = if ($adkInstalled) { $oscdimgPath } else { "Requerido para compilar ISOs de arranque BIOS/UEFI" }
$pwshDetail = if ($pwshInstalled) {
    try {
        $verOut = (& $pwshCmd.Source --version 2>&1) | Out-String
        if ($verOut -match 'PowerShell\s+([\d\.]+)') { $matches[1] } else { $verOut.Trim() }
    } catch {
        "Instalado"
    }
} else { "Opcional / Recomendado (PowerShell 5.1 nativo soportado)" }
$hvDetail = if ($hyperVEnabled) { "Habilitado" } else { "Necesario para New-TestVM-HyperV.ps1" }
$agyDetail = if ($antigravityPresent) { "Instalado / Carpeta .gemini activa" } else { "Instalar Antigravity IDE" }

Write-StatusItem -Name "Git for Windows" -Status $gitInstalled -Detail $gitDetail
Write-StatusItem -Name "Windows ADK (oscdimg.exe)" -Status $adkInstalled -Detail $adkDetail
Write-StatusItem -Name "PowerShell 7 (pwsh)" -Status $pwshInstalled -Detail $pwshDetail
Write-StatusItem -Name "Hyper-V Virtualization" -Status $hyperVEnabled -Detail $hvDetail
Write-StatusItem -Name "Antigravity IDE / Config" -Status $antigravityPresent -Detail $agyDetail

# -------------------------------------------------------------------------
# FASE 2: INSTALACION AUTOMATICA DE DEPENDENCIAS (SI SE SOLICITA)
# -------------------------------------------------------------------------
if ($InstallPrerequisites) {
    Write-StepHeader "INSTALANDO DEPENDENCIAS FALTANTES VIA WINGET"
    
    $wingetCmd = Get-Command "winget.exe" -ErrorAction SilentlyContinue
    if ($null -eq $wingetCmd) {
        Write-Warning "winget.exe no esta disponible en este sistema. Por favor instala las herramientas manualmente."
    } else {
        if (-not $gitInstalled) {
            Write-Host ">> Instalando Git for Windows..." -ForegroundColor Cyan
            & winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
        }
        if (-not $adkInstalled) {
            Write-Host ">> Instalando Windows ADK (Deployment Tools)..." -ForegroundColor Cyan
            & winget install --id Microsoft.WindowsADK -e --source winget --accept-package-agreements --accept-source-agreements
        }
        if (-not $pwshInstalled) {
            Write-Host ">> Instalando PowerShell 7..." -ForegroundColor Cyan
            & winget install --id Microsoft.PowerShell -e --source winget --accept-package-agreements --accept-source-agreements
        }
    }
}

if ($EnableHyperV -and -not $hyperVEnabled) {
    Write-Host ">> Habilitando caracteristica Hyper-V..." -ForegroundColor Cyan
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -NoRestart -ErrorAction Stop
        Write-Host "[OK] Hyper-V habilitado (se requerira reinicio al finalizar)." -ForegroundColor Green
    } catch {
        Write-Warning "No se pudo habilitar Hyper-V automaticamente: $($_.Exception.Message). Ejecuta este script como Administrador."
    }
}

if ($SetExecutionPolicy) {
    Write-Host ">> Configurando ExecutionPolicy a RemoteSigned (CurrentUser)..." -ForegroundColor Cyan
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "[OK] ExecutionPolicy configurada." -ForegroundColor Green
}

if ($CheckOnly) {
    Write-Host ""
    Write-Host "Modo -CheckOnly finalizado. No se realizaron cambios en disco." -ForegroundColor Cyan
    return
}

# -------------------------------------------------------------------------
# FASE 3: DESPLIEGUE DE CONFIGURACION GLOBAL DE ANTIGRAVITY
# -------------------------------------------------------------------------
Write-StepHeader "DESPLEGANDO REGLAS, SKILLS Y HOOKS DE ANTIGRAVITY"

if (-not (Test-Path $GlobalConfigDir)) {
    New-Item -ItemType Directory -Path $GlobalConfigDir -Force | Out-Null
}

# 1. Copiar Reglas Globales
$targetRulesDir = Join-Path $GlobalConfigDir "rules"
if (-not (Test-Path $targetRulesDir)) { New-Item -ItemType Directory -Path $targetRulesDir -Force | Out-Null }

$projectRules = Join-Path $AgentsDir "rules"
if (Test-Path $projectRules) {
    Copy-Item -Path "$projectRules\*" -Destination $targetRulesDir -Recurse -Force
    Write-Host "  [OK] Reglas globales sincronizadas en: $targetRulesDir" -ForegroundColor Green
}

# 2. Copiar Skills Globales
$targetSkillsDir = Join-Path $GlobalConfigDir "skills"
if (-not (Test-Path $targetSkillsDir)) { New-Item -ItemType Directory -Path $targetSkillsDir -Force | Out-Null }

$projectSkills = Join-Path $AgentsDir "skills"
if (Test-Path $projectSkills) {
    Copy-Item -Path "$projectSkills\*" -Destination $targetSkillsDir -Recurse -Force
    Write-Host "  [OK] Skills globales sincronizadas en: $targetSkillsDir" -ForegroundColor Green
}

# 3. Copiar Hooks Globales
$projectHooks = Join-Path $AgentsDir "hooks.json"
if (Test-Path $projectHooks) {
    $targetHooks = Join-Path $GlobalConfigDir "hooks.json"
    Copy-Item -Path $projectHooks -Destination $targetHooks -Force
    Write-Host "  [OK] Hooks de higiene Git sincronizados en: $targetHooks" -ForegroundColor Green
}

# -------------------------------------------------------------------------
# FASE 4: VALIDACION FINAL DE SANIDAD
# -------------------------------------------------------------------------
Write-StepHeader "VALIDACION FINAL DEL ENTORNO"

$adkTestScript = Join-Path $AgentsDir "skills\windows-adk-hyperv\scripts\Test-AdkEnvironment.ps1"
if (Test-Path $adkTestScript) {
    Write-Host ">> Verificando entorno ADK e Hyper-V:" -ForegroundColor Cyan
    & $adkTestScript
}

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Green
Write-Host " [EXITO] Entorno Antigravity y OptimizedISO preparado al 100%         " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
Write-Host " * Workspace local (.agents) y configuracion global ($HOME\.gemini\config) activos." -ForegroundColor White
Write-Host " * Puedes abrir este repositorio en Antigravity IDE y empezar a trabajar de inmediato." -ForegroundColor White
Write-Host ""
