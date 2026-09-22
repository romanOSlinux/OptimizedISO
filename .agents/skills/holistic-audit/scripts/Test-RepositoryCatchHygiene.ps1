# Test-RepositoryCatchHygiene.ps1 - Auditoría AST de Bloques Catch en el Repositorio
# Codificación estricta: UTF-8 con BOM

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TargetDir = "scripts",

    [Parameter()]
    [switch]$FailOnEmpty
)

$scripts = Get-ChildItem -Path $TargetDir -Recurse -Filter "*.ps1"
$emptyReports = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($s in $scripts) {
    $content = Get-Content -Path $s.FullName -Raw -Encoding UTF8
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors)
    $catches = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CatchClauseAst] }, $true)

    foreach ($c in $catches) {
        $body = $c.Body.Extent.Text.Trim()
        $inner = $body.Trim('{}').Trim()
        if ([string]::IsNullOrWhiteSpace($inner) -or $inner -eq '$null' -or $inner -eq '@()') {
            $emptyReports.Add([PSCustomObject]@{
                File   = (Resolve-Path -Relative $s.FullName)
                Line   = $c.Extent.StartLineNumber
                Status = "EMPTY_CATCH"
                Text   = ($c.Extent.Text -replace '\s+', ' ')
            })
        }
    }
}

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   AUDITORIA AST DE HIGIENE CATCH (CWE-390 / Fail-Visible)    " -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Scripts Evaluados       : $($scripts.Count)" -ForegroundColor Gray
Write-Host " Bloques Catch Vacíos    : $($emptyReports.Count)" -ForegroundColor $(if ($emptyReports.Count -eq 0) { 'Green' } else { 'Red' })
Write-Host ""

if ($emptyReports.Count -gt 0) {
    $emptyReports | Format-Table -AutoSize
    if ($FailOnEmpty) {
        Write-Error "Se detectaron $($emptyReports.Count) bloques catch vacíos que violan la Regla 13 de AGENTS.md."
        exit 1
    }
} else {
    Write-Host "✅ [PASS] Cero bloques catch vacíos detectados en $TargetDir." -ForegroundColor Green
}
exit 0
