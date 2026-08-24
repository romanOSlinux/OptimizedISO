<#
.SYNOPSIS
    Validador rapido de codificacion UTF-8 con BOM y analisis sintactico AST en PowerShell 5.1
    Helper para skill powershell-windows
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath
)

if (-not (Test-Path $FilePath)) {
    Write-Host "[ERROR] El archivo '$FilePath' no existe." -ForegroundColor Red
    exit 1
}

$resolved = (Resolve-Path $FilePath).Path
$bytes = [System.IO.File]::ReadAllBytes($resolved)

# 1. Validar UTF-8 BOM (0xEF, 0xBB, 0xBF)
$hasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)

# 2. Validar AST Parser
$content = [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors)

Write-Host ""
Write-Host "=== VALIDACION DE SCRIPT POWERSHELL ===" -ForegroundColor Cyan
Write-Host "Archivo    : $resolved"

if ($hasBOM) {
    Write-Host "BOM UTF-8  : [OK] Presente (0xEF, 0xBB, 0xBF)" -ForegroundColor Green
} else {
    Write-Host "BOM UTF-8  : [FAIL] Falta BOM (Peligro en PS 5.1)" -ForegroundColor Red
}

if ($errors.Count -eq 0) {
    Write-Host "Errores AST: 0 errores [OK]" -ForegroundColor Green
} else {
    Write-Host "Errores AST: $($errors.Count) errores [FAIL]" -ForegroundColor Red
    Write-Host "`nDetalle de Errores AST:" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "  - Linea $($err.Extent.StartLineNumber): $($err.Message)" -ForegroundColor Red
    }
    exit 1
}

if (-not $hasBOM) {
    Write-Host "`n[WARN] El archivo carece de BOM. Guardelo en formato UTF-8 con BOM." -ForegroundColor Yellow
    exit 2
}

Write-Host "`n>> VALIDACION EXITOSA: Script 100% compatible con Windows PowerShell 5.1." -ForegroundColor Green
exit 0
