<#
.SYNOPSIS
    Verificador de higiene y trazabilidad del repositorio Git (Cero Binarios Pesados)
    Helper para skill git-workflow
#>

Write-Host ""
Write-Host "=== AUDITORÃA DE HIGIENE Y TRAZABILIDAD GIT ===" -ForegroundColor Cyan

# 1. Verificar binarios pesados no deseados
$forbiddenExtensions = @("*.iso", "*.wim", "*.esd", "*.vhd", "*.vhdx", "*.msu", "*.cab")
$trackedForbidden = @()

foreach ($ext in $forbiddenExtensions) {
    $files = git ls-files $ext
    if ($files) { $trackedForbidden += $files }
}

if ($trackedForbidden.Count -gt 0) {
    Write-Host "[FAIL] Se detectaron binarios pesados rastreados en Git:" -ForegroundColor Red
    foreach ($f in $trackedForbidden) { Write-Host "  - $f" -ForegroundColor Red }
} else {
    Write-Host "[OK] Cero binarios pesados rastreados en el arbol de Git." -ForegroundColor Green
}

# 2. Estado del Working Tree
$statusShort = git status --short
if ($statusShort) {
    Write-Host "`n[INFO] Cambios pendientes en el arbol de trabajo:" -ForegroundColor Yellow
    $statusShort | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
} else {
    Write-Host "[OK] Working tree limpio (0 cambios pendientes)." -ForegroundColor Green
}

# 3. Commits pendientes de Push
$ahead = git log "@{u}..HEAD" --oneline 2>$null
if ($ahead) {
    Write-Host "`n[INFO] Commits locales listos para push a remoto:" -ForegroundColor Cyan
    $ahead | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkCyan }
} else {
    Write-Host "[OK] Repositorio 100% sincronizado con el remoto." -ForegroundColor Green
}

Write-Host ""
