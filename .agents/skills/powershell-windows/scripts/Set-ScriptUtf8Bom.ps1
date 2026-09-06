<#
.SYNOPSIS
    Set-ScriptUtf8Bom.ps1 - Aplica codificación UTF-8 con BOM a scripts PowerShell
    Helper para skill powershell-windows
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$Path
)

if (-not (Test-Path $Path)) {
    Write-Error "La ruta '$Path' no existe."
    exit 1
}

$files = @()
if ((Get-Item $Path) -is [System.IO.DirectoryInfo]) {
    $files = Get-ChildItem -Path $Path -Include "*.ps1","*.psm1","*.psd1" -Recurse -File |
        Where-Object { $_.FullName -notmatch '\\(\.git|pruebadeblot|scratch)\\' }
} else {
    $files = @(Get-Item $Path)
}

$utf8Bom = [byte[]]@(0xEF, 0xBB, 0xBF)

foreach ($f in $files) {
    $resolved = $f.FullName
    $bytes = [System.IO.File]::ReadAllBytes($resolved)
    
    $hasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    if (-not $hasBOM) {
        $newBytes = [byte[]]::new($bytes.Length + 3)
        $newBytes[0] = 0xEF
        $newBytes[1] = 0xBB
        $newBytes[2] = 0xBF
        [System.Array]::Copy($bytes, 0, $newBytes, 3, $bytes.Length)
        [System.IO.File]::WriteAllBytes($resolved, $newBytes)
        Write-Host "  [+] BOM agregado a: $($f.Name)" -ForegroundColor Green
    } else {
        Write-Host "  [=] BOM ya presente en: $($f.Name)" -ForegroundColor Gray
    }
}
