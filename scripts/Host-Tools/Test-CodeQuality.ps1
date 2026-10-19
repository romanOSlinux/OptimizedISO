<#
.SYNOPSIS
    romanOS Host Tool - Auditoría de Calidad Estática de Código (PSScriptAnalyzer)
.DESCRIPTION
    Audita scripts de PowerShell y Batch en el repositorio OptimizedISO:
    1. Verifica codificación UTF-8 con BOM en .ps1/.psm1/.psd1 y No-BOM en .cmd/.bat (Regla 4).
    2. Ejecuta PSScriptAnalyzer evaluando compatibilidad y buenas prácticas.
    3. Detecta bloques catch silenciosos o vacíos (CWE-390 / Regla 13).
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path = '',

    [Parameter()]
    [string]$ScriptPath,

    [Parameter()]
    [switch]$IncludeWarnings
)

$targetFiles = @()
if ($ScriptPath) {
    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        Write-Error "El archivo especificado no existe: $ScriptPath"
        exit 1
    }
    $targetFiles = @(Get-Item -LiteralPath $ScriptPath)
} else {
    if (-not $Path) {
        $parentScripts = Split-Path -Parent $PSScriptRoot
        if (Test-Path -LiteralPath (Join-Path $parentScripts "Core")) {
            $Path = $parentScripts
        } else {
            $Path = $PSScriptRoot
        }
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Error "La ruta especificada no existe: $Path"
        exit 1
    }
    $targetFiles = Get-ChildItem -Path $Path -Recurse -File -Include *.ps1, *.psm1, *.psd1, *.cmd, *.bat
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " [romanOS] Auditoría Estática de Código y Calidad (Reglas 4 y 13)" -ForegroundColor Cyan
Write-Host " Total de archivos a auditar: $($targetFiles.Count)" -ForegroundColor Gray
Write-Host "======================================================================" -ForegroundColor Cyan

$encodingErrors = 0
$cwe390Errors = 0
$analyzerErrors = 0

$hasAnalyzer = [bool](Get-Module -ListAvailable -Name PSScriptAnalyzer)
if (-not $hasAnalyzer) {
    Write-Warning "PSScriptAnalyzer no está instalado. Solo se auditarán codificaciones y patrones sintácticos."
}

foreach ($file in $targetFiles) {
    $filePath = $file.FullName
    $ext = $file.Extension.ToLower()

    # 1. Auditoría de Codificación (Regla 4)
    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    $hasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)

    if ($ext -in @('.ps1', '.psm1', '.psd1')) {
        if (-not $hasBOM) {
            Write-Host " [FAIL-ENC] $filePath -> Falta UTF-8 BOM (Requerido para PS 5.1)" -ForegroundColor Red
            $encodingErrors++
        }
    } elseif ($ext -in @('.cmd', '.bat')) {
        if ($hasBOM) {
            Write-Host " [FAIL-ENC] $filePath -> Tiene UTF-8 BOM (Prohibido en Batch .cmd/.bat)" -ForegroundColor Red
            $encodingErrors++
        }
    }

    # 2. Auditoría de Fallos Silenciosos (CWE-390 / Regla 13)
    if ($ext -in @('.ps1', '.psm1')) {
        $content = [System.IO.File]::ReadAllText($filePath)
        # Buscar bloques catch vacios o con solo espacios / $null
        if ($content -match 'catch\s*\{\s*(\$null)?\s*\}') {
            Write-Host " [FAIL-CWE390] $filePath -> Bloque catch vacío o silencioso detectado" -ForegroundColor Red
            $cwe390Errors++
        }
    }

    # 3. PSScriptAnalyzer
    if ($hasAnalyzer -and $ext -in @('.ps1', '.psm1')) {
        $results = Invoke-ScriptAnalyzer -Path $filePath -Severity Error
        if ($IncludeWarnings) {
            $results += Invoke-ScriptAnalyzer -Path $filePath -Severity Warning
        }

        foreach ($r in $results) {
            $color = if ($r.Severity -eq 'Error') { 'Red' } else { 'Yellow' }
            Write-Host " [$($r.Severity.ToString().ToUpper())] $($file.Name):L$($r.Line) -> $($r.Message) ($($r.RuleName))" -ForegroundColor $color
            if ($r.Severity -eq 'Error') {
                $analyzerErrors++
            }
        }
    }
}

Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host " Resumen de Auditoría de Código:" -ForegroundColor Cyan
Write-Host "   - Errores de Codificación (Regla 4): $encodingErrors" -ForegroundColor $(if ($encodingErrors -eq 0) { 'Green' } else { 'Red' })
Write-Host "   - Errores de Silenciamiento (CWE-390): $cwe390Errors" -ForegroundColor $(if ($cwe390Errors -eq 0) { 'Green' } else { 'Red' })
Write-Host "   - Errores de ScriptAnalyzer:          $analyzerErrors" -ForegroundColor $(if ($analyzerErrors -eq 0) { 'Green' } else { 'Red' })
Write-Host "======================================================================" -ForegroundColor Cyan

$totalErrors = $encodingErrors + $cwe390Errors + $analyzerErrors
if ($totalErrors -eq 0) {
    Write-Host " [PASS] Todos los archivos auditados cumplen con los estándares de calidad." -ForegroundColor Green
    exit 0
} else {
    Write-Host " [FAIL] Se detectaron $totalErrors inconformidades en el código." -ForegroundColor Red
    exit 1
}
