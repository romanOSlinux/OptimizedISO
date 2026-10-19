<#
.SYNOPSIS
    Test-PreFlightEnvironment.ps1 — Auditoría Pre-Vuelo de Gobernanza y Ecosistema.
    Verifica Servidores MCP, Herramientas Canónicas, Plugins, Git y Contratos del Proyecto.
.DESCRIPTION
    Paso cero obligatorio al iniciar cualquier sesión de desarrollo en romanOS / OptimizedISO.
    Inspecciona en menos de 1 segundo:
      1. Estado y Trazabilidad de Git (Rama, commit y cambios pendientes).
      2. Soberanía de Herramientas (Presencia de binarios en tools/).
      3. Plugins y Agentes (.agents/plugins/romanos-core).
      4. Servidores MCP instalados en el entorno.
      5. Contratos de Gobernanza (CONSTRAINTS.md, AGENTS.md, GOVERNANCE-MATRIX.md, SSOT).
#>

[CmdletBinding()]
param(
    [switch]$Quiet,
    [switch]$PassThru
)

$ErrorActionPreference = 'Continue'
$sw = [System.Diagnostics.Stopwatch]::StartNew()

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $repoRoot "CONSTRAINTS.md"))) {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    if (-not (Test-Path (Join-Path $repoRoot "CONSTRAINTS.md"))) {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    }
}

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

function Add-AuditCheck {
    param(
        [string]$Category,
        [string]$Component,
        [bool]$Status,
        [string]$Details
    )
    $results.Add([PSCustomObject]@{
        Category  = $Category
        Component = $Component
        Status    = if ($Status) { "PASS [OK]" } else { "FAIL [X]" }
        Details   = $Details
    })
}

# 1. Git como Fuente de Verdad (Regla 0)
$gitBranch = "Desconocida"
$gitClean  = $false
$gitCommit = "Desconocido"
try {
    $branchOut = & git -C $repoRoot rev-parse --abbrev-ref HEAD 2>$null
    if ($branchOut) { $gitBranch = $branchOut.Trim() }
    $statusOut = & git -C $repoRoot status --porcelain 2>$null
    $gitClean  = [string]::IsNullOrWhiteSpace($statusOut)
    $logOut    = & git -C $repoRoot log -n 1 --oneline 2>$null
    if ($logOut) { $gitCommit = $logOut.Trim() }
    Add-AuditCheck -Category "Git (Regla 0)" -Component "Branch & Tree" -Status $true -Details "Rama: $gitBranch | Estado: $(if($gitClean){'Limpio'}else{'Cambios pendientes'}) | Base: $gitCommit"
} catch {
    Add-AuditCheck -Category "Git (Regla 0)" -Component "Branch & Tree" -Status $false -Details "Error leyendo repositorio Git: $($_.Exception.Message)"
}

# 2. Herramientas Locales Soberanas (Regla 18 / tools/)
$canonicalTools = @(
    @{ Name = "wimlib-imagex.exe"; Path = "tools\wimlib\wimlib-imagex.exe"; Domain = "Manipulacion WIM Zero-Mount" },
    @{ Name = "sigcheck64.exe";     Path = "tools\sysinternals\sigcheck64.exe"; Domain = "Firmas Authenticode/WHQL" },
    @{ Name = "Coreinfo64.exe";     Path = "tools\sysinternals\Coreinfo64.exe"; Domain = "Topologia CPU/Cache/NUMA" },
    @{ Name = "autorunsc64.exe";    Path = "tools\sysinternals\autorunsc64.exe"; Domain = "Auditoria Autoruns/Servicios" },
    @{ Name = "es.exe";             Path = "tools\everything\es.exe"; Domain = "Busqueda Ultrarrapida de Archivos" }
)

foreach ($t in $canonicalTools) {
    $fullToolPath = Join-Path $repoRoot $t.Path
    $exists = Test-Path $fullToolPath
    $sizeKb = if ($exists) { [math]::Round((Get-Item $fullToolPath).Length / 1KB, 0) } else { 0 }
    Add-AuditCheck -Category "Tools (Regla 18)" -Component $t.Name -Status $exists -Details "$($t.Domain) ($sizeKb KB)"
}

# 3. Plugins (.agents/plugins)
$pluginDir = Join-Path $repoRoot ".agents\plugins\romanos-core"
$pluginJson = Join-Path $pluginDir "plugin.json"
$pluginOk = (Test-Path $pluginJson)
Add-AuditCheck -Category "Plugins" -Component "romanos-core" -Status $pluginOk -Details "Manifiesto canónico de plugin: $pluginJson"

# 4. Servidores MCP en Perfil
$mcpBaseDir = "$env:USERPROFILE\.gemini\antigravity-ide\mcp"
$expectedMcps = @("fetch", "github", "memory")
foreach ($m in $expectedMcps) {
    $mcpPath = Join-Path $mcpBaseDir $m
    $mcpExists = Test-Path $mcpPath
    Add-AuditCheck -Category "Servidores MCP" -Component $m -Status $mcpExists -Details "Ubicacion: $mcpPath"
}

# 5. Contratos de Gobernanza Inmutables (CONSTRAINTS.md / AGENTS.md / SSOT)
$governanceDocs = @(
    @{ Name = "CONSTRAINTS.md"; Path = "CONSTRAINTS.md"; Desc = "Contrato Inmutable de Calidad (L1/L2/L3)" },
    @{ Name = "AGENTS.md"; Path = ".agents\AGENTS.md"; Desc = "Reglas Estrictas del Agente (Reglas 0 a 19)" },
    @{ Name = "GOVERNANCE-MATRIX.md"; Path = ".agents\GOVERNANCE-MATRIX.md"; Desc = "Matriz Operativa 6 Fases" },
    @{ Name = "Policy-Engine.ps1"; Path = "scripts\Core\Policy-Engine.ps1"; Desc = "SSOT de Directivas y Registro" }
)

foreach ($g in $governanceDocs) {
    $gPath = Join-Path $repoRoot $g.Path
    $gExists = Test-Path $gPath
    $gLines = if ($gExists) { (Get-Content $gPath).Count } else { 0 }
    Add-AuditCheck -Category "Gobernanza" -Component $g.Name -Status $gExists -Details "$($g.Desc) ($gLines lineas)"
}

$sw.Stop()
$elapsedMs = $sw.ElapsedMilliseconds

$failedCount = @($results | Where-Object { $_.Status -like "*FAIL*" }).Count
$allOk = ($failedCount -eq 0)

if (-not $Quiet) {
    Write-Host "`n==========================================================================" -ForegroundColor Cyan
    Write-Host ' romanOS / OptimizedISO - AUDITORIA PRE-VUELO DE ECOSISTEMA (PRE-FLIGHT)   ' -ForegroundColor White
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  Host         : $env:COMPUTERNAME | Usuario: $env:USERNAME" -ForegroundColor Gray
    Write-Host "  Repositorio  : $repoRoot" -ForegroundColor Gray
    Write-Host "  Duracion     : $elapsedMs ms`n" -ForegroundColor Gray

    $results | Format-Table -Property Category, Component, Status, Details -AutoSize

    Write-Host "==========================================================================" -ForegroundColor Cyan
    if ($allOk) {
        Write-Host '  ESTADO PRE-VUELO: CERTIFICADO Y LISTO [100% PASS - 0 Incidencias]       ' -ForegroundColor Green
    } else {
        Write-Host "  ESTADO PRE-VUELO: FALLAS DETECTADAS ($failedCount componentes no conformes) " -ForegroundColor Red
    }
    Write-Host "==========================================================================`n" -ForegroundColor Cyan
}

if ($PassThru) {
    return [PSCustomObject]@{
        AllOk        = $allOk
        FailedCount  = $failedCount
        ElapsedMs    = $elapsedMs
        AuditResults = $results
    }
}

if ($allOk) { exit 0 } else { exit 1 }
