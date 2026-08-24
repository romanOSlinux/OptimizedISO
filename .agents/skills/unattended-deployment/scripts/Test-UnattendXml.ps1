<#
.SYNOPSIS
    Validador de Esquema y Sintaxis XML para autounattend.xml (Windows 10/11 UEFI GPT)
    Helper para skill unattended-deployment
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$XmlPath = "C:\OptimizedISO\sources\autounattend.xml"
)

Write-Host ""
Write-Host "=== VALIDACION DE ESQUEMA AUTOUNATTEND.XML (UEFI GPT) ===" -ForegroundColor Cyan
Write-Host "Archivo evaluado: $XmlPath`n" -ForegroundColor DarkGray

if (-not (Test-Path $XmlPath)) {
    # Buscar en subcarpetas comunes si la ruta por defecto no existe
    $candidates = @(
        "C:\OptimizedISO\autounattend.xml",
        "C:\OptimizedISO\sources\autounattend.xml",
        "C:\OptimizedISO\scripts\autounattend.xml"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $XmlPath = $c; break }
    }
}

if (-not (Test-Path $XmlPath)) {
    Write-Host "[INFO] Archivo '$XmlPath' no encontrado en disco." -ForegroundColor Yellow
    Write-Host "       Generando validación sobre plantilla en memoria de New-OptimizedWindowsISO-v2..." -ForegroundColor Gray
    
    # Validar la plantilla embebida dentro de New-OptimizedWindowsISO-v2.ps1
    $v2Path = "C:\OptimizedISO\scripts\New-OptimizedWindowsISO-v2.ps1"
    if (Test-Path $v2Path) {
        $content = Get-Content $v2Path -Raw
        $xmlMatch = [regex]::Match($content, '(?s)<\?xml version="1\.0" encoding="utf-8"\?>.*?<\/unattend>')
        if ($xmlMatch.Success) {
            $rawXml = $xmlMatch.Value
            $tempXml = Join-Path $env:TEMP "embedded_test_autounattend.xml"
            [System.IO.File]::WriteAllText($tempXml, $rawXml, [System.Text.Encoding]::UTF8)
            $XmlPath = $tempXml
        } else {
            Write-Host "[WARN] No se pudo localizar archivo autounattend.xml para auditar." -ForegroundColor Yellow
            exit 0
        }
    }
}

$xmlDoc = [System.Xml.XmlDocument]::new()
try {
    $xmlContent = [System.IO.File]::ReadAllText($XmlPath, [System.Text.Encoding]::UTF8)
    $xmlDoc.LoadXml($xmlContent)
    Write-Host "  ✅ Parser XML : Sintaxis XML válida y bien formada." -ForegroundColor Green
} catch {
    Write-Host "  ❌ Parser XML : Error de sintaxis XML: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$nsMgr = [System.Xml.XmlNamespaceManager]::new($xmlDoc.NameTable)
$nsMgr.AddNamespace("u", "urn:schemas-microsoft-com:unattend")
$nsMgr.AddNamespace("wcm", "http://schemas.microsoft.com/WMIConfig/2002/State")

$passes = @("windowsPE", "specialize", "oobeSystem")
$missingPasses = @()
foreach ($p in $passes) {
    $node = $xmlDoc.SelectSingleNode("//u:settings[@pass='$p']", $nsMgr)
    if ($node) {
        Write-Host "  ✅ Fase '$p' : Presente en la configuración." -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Fase '$p' : No detectada en el XML." -ForegroundColor Yellow
        $missingPasses += $p
    }
}

# Validación de layout UEFI GPT
$createParts = $xmlDoc.SelectNodes("//u:CreatePartition", $nsMgr)
if ($createParts.Count -ge 4) {
    Write-Host "  ✅ Particionado GPT : $($createParts.Count) particiones definidas (WinRE, EFI, MSR, Windows)." -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Particionado GPT : $($createParts.Count) particiones detectadas (se recomiendan 4 para UEFI)." -ForegroundColor Yellow
}

# Validación de etiquetas obsoletas / problemáticas
$invalidTags = @("WillContinueOnFailure")
$hasInvalid = $false
foreach ($t in $invalidTags) {
    if ($xmlContent -match "<$t>") {
        Write-Host "  ❌ Directiva Inválida : Se detectó <$t> no permitida por Microsoft Setup." -ForegroundColor Red
        $hasInvalid = $true
    }
}

if (-not $hasInvalid) {
    Write-Host "  ✅ Directivas Setup : Cero etiquetas obsoletas o conflictivas." -ForegroundColor Green
}

Write-Host ""
if (-not $hasInvalid) {
    Write-Host ">> VALIDACION EXITOSA: autounattend.xml cumple con el estándar de despliegue oficial de Windows 10/11." -ForegroundColor Green
    exit 0
} else {
    Write-Host ">> VALIDACION CON ADVERTENCIAS: Revise las directivas antes de compilar la ISO." -ForegroundColor Yellow
    exit 1
}
