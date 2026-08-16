<#
.SYNOPSIS
Configura automáticamente las directivas, reglas y skills de Antigravity en Windows.

.DESCRIPTION
Copia e inicializa todas las habilidades y reglas del proyecto OptimizedISO en el directorio
global de configuración de Antigravity en Windows ($HOME\.gemini\config).
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   CONFIGURADOR DE REGLAS Y SKILLS DE ANTIGRAVITY PARA WINDOWS        " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$AgentsDir = Join-Path $ProjectRoot ".agents"
$GlobalConfigDir = Join-Path $HOME ".gemini\config"

if (-not (Test-Path $GlobalConfigDir)) {
    New-Item -ItemType Directory -Path $GlobalConfigDir -Force | Out-Null
}

# 1. Copiar Reglas Globales
$targetRulesDir = Join-Path $GlobalConfigDir "rules"
if (-not (Test-Path $targetRulesDir)) { New-Item -ItemType Directory -Path $targetRulesDir -Force | Out-Null }

$projectRules = Join-Path $AgentsDir "rules"
if (Test-Path $projectRules) {
    Copy-Item -Path "$projectRules\*" -Destination $targetRulesDir -Recurse -Force
    Write-Host "[OK] Reglas globales copiadas a $targetRulesDir" -ForegroundColor Green
}

# 2. Copiar Skills Globales
$targetSkillsDir = Join-Path $GlobalConfigDir "skills"
if (-not (Test-Path $targetSkillsDir)) { New-Item -ItemType Directory -Path $targetSkillsDir -Force | Out-Null }

$projectSkills = Join-Path $AgentsDir "skills"
if (Test-Path $projectSkills) {
    Copy-Item -Path "$projectSkills\*" -Destination $targetSkillsDir -Recurse -Force
    Write-Host "[OK] Skills copiadas a $targetSkillsDir" -ForegroundColor Green
}

Write-Host ""
Write-Host ">>> Configuración de Antigravity en Windows completada con éxito." -ForegroundColor Green
Write-Host "    Antigravity cargará automáticamente todas las directivas al abrir el proyecto." -ForegroundColor White
