<#
.SYNOPSIS
    Validador rápido de codificación UTF-8 con BOM y análisis sintáctico AST en PowerShell 5.1
    Helper para skill powershell-windows
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$Path = "c:\OptimizedISO"
)

if (-not (Test-Path $Path)) {
    Write-Host "[ERROR] La ruta '$Path' no existe." -ForegroundColor Red
    exit 1
}

$targetFiles = @()
if ((Get-Item $Path) -is [System.IO.DirectoryInfo]) {
    $targetFiles = Get-ChildItem -Path $Path -Include "*.ps1","*.psm1","*.psd1" -Recurse -File |
        Where-Object { 
            $_.FullName -notmatch '\\(\.git|pruebadeblot|scratch)\\'
        }
} else {
    $targetFiles = @(Get-Item $Path)
}

Write-Host ""
Write-Host "=== VALIDACION AST Y CODIFICACION UTF-8 BOM (PowerShell 5.1) ===" -ForegroundColor Cyan
Write-Host "Total de archivos a evaluar: $($targetFiles.Count)`n" -ForegroundColor DarkGray

$allPassed = $true
$passCount = 0
$failCount = 0

foreach ($file in $targetFiles) {
    $resolved = $file.FullName
    $bytes = [System.IO.File]::ReadAllBytes($resolved)
    
    # 1. Validar UTF-8 BOM (0xEF, 0xBB, 0xBF)
    $hasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    
    # 2. Validar AST Parser
    $content = [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors)
    
    $relPath = $resolved.Replace("c:\OptimizedISO\", "")
    $statusBOM = if ($hasBOM) { "[BOM OK]" } else { "[NO BOM ❌]" }
    $statusAST = if ($errors.Count -eq 0) { "[AST 0 ERR]" } else { "[AST $($errors.Count) ERR ❌]" }
    
    if ($hasBOM -and $errors.Count -eq 0) {
        Write-Host "  ✅ PASS | $statusBOM $statusAST | $relPath" -ForegroundColor Green
        $passCount++
    } else {
        Write-Host "  ❌ FAIL | $statusBOM $statusAST | $relPath" -ForegroundColor Red
        if ($errors.Count -gt 0) {
            foreach ($err in $errors) {
                Write-Host "      -> Linea $($err.Extent.StartLineNumber): $($err.Message)" -ForegroundColor Yellow
            }
        }
        $failCount++
        $allPassed = $false
    }
}

Write-Host ""
Write-Host "=== RESUMEN DE AUDITORIA ===" -ForegroundColor Cyan
Write-Host "  Scripts Evaluados : $($targetFiles.Count)"
Write-Host "  Scripts Aprobados : $passCount" -ForegroundColor Green
Write-Host "  Scripts Fallidos  : $failCount" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Red' })
Write-Host ""

if ($allPassed) {
    Write-Host ">> RESULTADO GLOBAL: 100% PASS - Todos los scripts son plenamente compatibles con Windows PowerShell 5.1." -ForegroundColor Green
    exit 0
} else {
    Write-Host ">> RESULTADO GLOBAL: Se detectaron fallas en la bateria de scripts." -ForegroundColor Red
    exit 1
}
