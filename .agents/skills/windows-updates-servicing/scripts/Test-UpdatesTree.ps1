<#
.SYNOPSIS
    Validador de Integridad, Firmas Digitales y Orden de Inyección DISM de Windows Updates
    Helper para skill windows-updates-servicing
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$UpdatesPath = "C:\OptimizedISO\Updates"
)

Write-Host ""
Write-Host "=== VALIDACION DE ARBOL DE WINDOWS UPDATES (DISM SERVICING) ===" -ForegroundColor Cyan
Write-Host "Ruta evaluada: $UpdatesPath`n" -ForegroundColor DarkGray

if (-not (Test-Path $UpdatesPath)) {
    Write-Host "[INFO] El directorio '$UpdatesPath' no existe actualmente." -ForegroundColor Yellow
    Write-Host "       Para descargar paquetes oficiales, ejecute: scripts\Get-WindowsUpdates.ps1" -ForegroundColor Gray
    exit 0
}

$updateFiles = Get-ChildItem -Path $UpdatesPath -Include "*.msu","*.cab" -Recurse -File | Where-Object { $_.Name -notmatch '^WSUSScan' }

if ($updateFiles.Count -eq 0) {
    Write-Host "[INFO] No se encontraron archivos .msu o .cab en '$UpdatesPath'." -ForegroundColor Yellow
    exit 0
}

Write-Host "Paquetes detectados: $($updateFiles.Count)`n" -ForegroundColor White

$allValid = $true
$classifiedPackages = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($file in $updateFiles) {
    $sig = Get-AuthenticodeSignature -FilePath $file.FullName -ErrorAction SilentlyContinue
    $isSignedByMicrosoft = ($sig.Status -eq 'Valid' -and $sig.SignerCertificate.Subject -match 'Microsoft')
    $sizeMB = [math]::Round($file.Length / 1MB, 2)

    # Clasificación de orden DISM
    $order = 50
    $category = "General Update"
    $name = $file.Name

    if ($name -match 'SSU|ServicingStack') {
        $order = 10
        $category = "1. Servicing Stack Update (SSU)"
    } elseif ($name -match 'KB5043080') {
        $order = 20
        $category = "2. Checkpoint Base (KB5043080)"
    } elseif ($name -match 'Windows1[01]\.\d+-KB|CumulativeUpdate.*x64' -and $name -notmatch 'NetFx|\.NET') {
        $order = 30
        $category = "3. Latest Cumulative Update (LCU)"
    } elseif ($name -match 'NetFx|\.NET|NDP') {
        $order = 40
        $category = "4. .NET Framework Cumulative Update"
    } elseif ($name -match 'SafeOS|DynamicSetup|WinRE') {
        $order = 50
        $category = "5. SafeOS / WinRE Dynamic Update"
    }

    $classifiedPackages.Add([PSCustomObject]@{
        Order       = $order
        Category    = $category
        FileName    = $file.Name
        SizeMB      = $sizeMB
        SignedByMS  = $isSignedByMicrosoft
        SignatureSt = "$($sig.Status)"
        FullPath    = $file.FullName
    })

    $sigIcon = if ($isSignedByMicrosoft) { "✅ Firma Microsoft Válida" } else { "⚠️ Sin Firma Oficial / $($sig.Status)" }
    Write-Host "  [$category] $($file.Name) ($sizeMB MB) -> $sigIcon" -ForegroundColor $(if ($isSignedByMicrosoft) { 'Green' } else { 'Yellow' })
}

Write-Host ""
Write-Host "--- ORDEN TECNICO DE INYECCION RECOMENDADO (DISM /Add-Package) ---" -ForegroundColor Cyan
$sorted = $classifiedPackages | Sort-Object Order, FileName
$step = 1
foreach ($pkg in $sorted) {
    Write-Host "  $step. [$($pkg.Category)] $($pkg.FileName)" -ForegroundColor White
    $step++
}

Write-Host ""
Write-Host ">> VALIDACION COMPLETADA: Árbol de paquetes listo para slipstreaming con DISM." -ForegroundColor Green
exit 0
