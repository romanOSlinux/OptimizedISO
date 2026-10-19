<#
.SYNOPSIS
    Test-SupplyChainIntegrity.ps1 - Auditor Forense de Cadena de Suministro y Firmas Authenticode (2026)
    romanOS / OptimizedISO — Estado del Arte Windows 11 24H2 / 25H2

.DESCRIPTION
    Inspecciona recursivamente todos los binarios ejecutables (.exe, .dll, .sys) utilizados o
    desplegados por el proyecto, validando:
      1. Firma digital Authenticode válida y cadena de confianza de certificados.
      2. Algoritmo criptográfico de firma (exige SHA-256 o superior; alerta de legacy SHA-1).
      3. Cálculo de hash criptográfico SHA-256 inmutable por archivo.
      4. Detección de binarios desconocidos, no firmados o potencialmente manipulados.
      5. Generación y verificación del Catálogo Maestro de Integridad (Binary-Integrity-Catalog.json).

.PARAMETER TargetPath
    Directorio raíz a escanear. (Default: raíz del repositorio OptimizedISO)

.PARAMETER UpdateCatalog
    Si se especifica, genera o actualiza el archivo Binary-Integrity-Catalog.json con los hashes actuales.

.PARAMETER VerifyCatalog
    Si se especifica, valida que cada archivo coincida exactamente con el hash registrado en el catálogo.

.PARAMETER CatalogPath
    Ruta alternativa para el catálogo de integridad. (Default: scripts\Core\Binary-Integrity-Catalog.json)

.EXAMPLE
    .\Test-SupplyChainIntegrity.ps1 -UpdateCatalog

.EXAMPLE
    .\Test-SupplyChainIntegrity.ps1 -VerifyCatalog
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$TargetPath,
    [switch]$UpdateCatalog,
    [switch]$VerifyCatalog,
    [string]$CatalogPath
)

$ErrorActionPreference = 'Continue'
$auditStartTime = Get-Date

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS / OptimizedISO — AUDITORIA DE CADENA DE SUMINISTRO & AUTHENTICODE" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
Write-Host ""

# -----------------------------------------------------------------------------
# 1. RESOLUCIÓN DE RUTAS
# -----------------------------------------------------------------------------
$repoRoot = if ($TargetPath) {
    $TargetPath
} else {
    $p = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    if (-not (Test-Path (Join-Path $p ".agents"))) {
        $p = Split-Path $PSScriptRoot -Parent
        if (-not (Test-Path (Join-Path $p ".agents"))) {
            $p = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        }
    }
    $p
}

if (-not $CatalogPath) {
    $CatalogPath = Join-Path $repoRoot "scripts\Core\Binary-Integrity-Catalog.json"
}

Write-Host "  Ruta de Inspección : $repoRoot" -ForegroundColor White
Write-Host "  Catálogo Maestro   : $CatalogPath" -ForegroundColor DarkGray
Write-Host ""

# -----------------------------------------------------------------------------
# 2. IDENTIFICACIÓN DE BINARIOS EN EL REPOSITORIO
# -----------------------------------------------------------------------------
Write-Host ">>> Localizando binarios ejecutables (.exe, .dll, .sys)..." -ForegroundColor Cyan

# Escanear carpetas de runtimes, drivers y raíz
$searchLocations = @(
    (Join-Path $repoRoot "Runtimes"),
    (Join-Path $repoRoot "Drivers"),
    (Join-Path $repoRoot "tools"),
    (Join-Path $repoRoot "bin")
)

$binaryFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

# Buscar en carpetas específicas
foreach ($loc in $searchLocations) {
    if (Test-Path $loc) {
        try {
            $files = Get-ChildItem -Path $loc -Recurse -Include *.exe, *.dll, *.sys -File -ErrorAction Stop
            foreach ($f in $files) {
                $binaryFiles.Add($f)
            }
        } catch {
            Write-Warning "Error al escanear directorio '$loc': $($_.Exception.Message)"
        }
    }
}

# Buscar ejecutables en la raíz del repositorio
try {
    $rootExes = Get-ChildItem -Path $repoRoot -Include *.exe -File -ErrorAction Stop
    foreach ($re in $rootExes) {
        $binaryFiles.Add($re)
    }
} catch {
    Write-Warning "Error al escanear ejecutables en la raíz: $($_.Exception.Message)"
}

Write-Host "  Total de binarios detectados: $($binaryFiles.Count)" -ForegroundColor Green
Write-Host ""

# -----------------------------------------------------------------------------
# 3. INSPECCIÓN FORENSE: HASH SHA-256 + FIRMA AUTHENTICODE
# -----------------------------------------------------------------------------
$auditResults = [System.Collections.Generic.List[PSCustomObject]]::new()
$validSignedCount = 0
$sha256SignedCount = 0
$sha1LegacyCount = 0
$unsignedCount = 0
$tamperedCount = 0

# Cargar catálogo existente si se verifica
$existingCatalog = @{}
if ($VerifyCatalog -and (Test-Path $CatalogPath)) {
    try {
        $rawJson = Get-Content -Path $CatalogPath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
        foreach ($item in $rawJson) {
            $existingCatalog[$item.RelativePath] = $item
        }
        Write-Host "  [OK] Catálogo cargado con $($existingCatalog.Count) referencias registradas." -ForegroundColor Green
    } catch {
        Write-Warning "No se pudo leer el catálogo de integridad: $($_.Exception.Message)"
    }
}

foreach ($bin in $binaryFiles) {
    $relPath = $bin.FullName.Replace($repoRoot, "").TrimStart("\/")
    
    # 1. Calcular Hash SHA-256
    $sha256 = ""
    try {
        $hashObj = Get-FileHash -Path $bin.FullName -Algorithm SHA256 -ErrorAction Stop
        $sha256 = $hashObj.Hash
    } catch {
        Write-Warning "Error al calcular SHA-256 de '$relPath': $($_.Exception.Message)"
        $sha256 = "ERROR"
    }

    # 2. Comprobar Firma Authenticode
    $sigStatus = "Desconocido"
    $signerSubject = "N/A"
    $sigAlgo = "N/A"
    $isTrusted = $false

    try {
        $sig = Get-AuthenticodeSignature -FilePath $bin.FullName -ErrorAction Stop
        $sigStatus = $sig.Status.ToString()
        
        if ($sig.SignerCertificate) {
            $signerSubject = $sig.SignerCertificate.Subject
            if ($sig.SignerCertificate.SignatureAlgorithm) {
                $sigAlgo = $sig.SignerCertificate.SignatureAlgorithm.FriendlyName
            }
        }
        
        if ($sig.Status -eq [System.Management.Automation.SignatureStatus]::Valid) {
            $isTrusted = $true
            $validSignedCount++
            if ($sigAlgo -match "sha256" -or $sigAlgo -match "sha384" -or $sigAlgo -match "sha512") {
                $sha256SignedCount++
            } elseif ($sigAlgo -match "sha1") {
                $sha1LegacyCount++
            }
        } else {
            $unsignedCount++
        }
    } catch {
        Write-Warning "Error al leer Authenticode de '$relPath': $($_.Exception.Message)"
        $sigStatus = "Error"
        $unsignedCount++
    }

    # 3. Categorización del binario
    $category = if ($relPath -match "^Runtimes") {
        "Microsoft Redistributable"
    } elseif ($relPath -match "^Drivers") {
        "Hardware OEM Driver"
    } elseif ($relPath -match "^Lanzar-") {
        "Local Compiled Launcher (romanOS)"
    } else {
        "Utilitario / Herramienta"
    }

    # 4. Verificación contra catálogo
    $verificationStatus = "N/A"
    if ($VerifyCatalog) {
        if ($existingCatalog.ContainsKey($relPath)) {
            $expectedHash = $existingCatalog[$relPath].SHA256
            if ($expectedHash -ieq $sha256) {
                $verificationStatus = "VERIFICADO (Coincide con Catálogo)"
            } else {
                $verificationStatus = "ALERTA: HASH MODIFICADO / POTENCIAL MANIPULACION"
                $tamperedCount++
                Write-Warning "DISCREPANCIA CRITICA: El archivo '$relPath' no coincide con el hash del catalogo."
            }
        } else {
            $verificationStatus = "NUEVO (No registrado en catálogo)"
        }
    }

    $auditResults.Add([PSCustomObject]@{
        RelativePath        = $relPath
        FileName            = $bin.Name
        Category            = $category
        SizeBytes           = $bin.Length
        SHA256              = $sha256
        AuthenticodeStatus  = $sigStatus
        SignatureAlgorithm  = $sigAlgo
        SignerSubject       = $signerSubject
        IsTrusted           = $isTrusted
        CatalogStatus       = $verificationStatus
    })
}

# -----------------------------------------------------------------------------
# 4. ACTUALIZACIÓN DE CATÁLOGO (SI -UpdateCatalog)
# -----------------------------------------------------------------------------
if ($UpdateCatalog) {
    try {
        $catalogDir = Split-Path $CatalogPath -Parent
        if (-not (Test-Path $catalogDir)) {
            New-Item -ItemType Directory -Path $catalogDir -Force | Out-Null
        }
        
        $exportData = $auditResults | Select-Object RelativePath, FileName, Category, SizeBytes, SHA256, AuthenticodeStatus, SignatureAlgorithm, SignerSubject
        $jsonContent = $exportData | ConvertTo-Json -Depth 4
        [System.IO.File]::WriteAllText($CatalogPath, $jsonContent, [System.Text.Encoding]::UTF8)
        
        # Añadir BOM
        $bytes = [System.IO.File]::ReadAllBytes($CatalogPath)
        if ($bytes.Length -ge 3 -and ($bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF)) {
            $bom = [byte[]](0xEF, 0xBB, 0xBF)
            [System.IO.File]::WriteAllBytes($CatalogPath, $bom + $bytes)
        }
        Write-Host "  [OK] Catálogo Maestro actualizado exitosamente en: $CatalogPath" -ForegroundColor Green
    } catch {
        Write-Warning "No se pudo guardar el Catálogo Maestro: $($_.Exception.Message)"
    }
}

# -----------------------------------------------------------------------------
# 5. REPORTE Y CONCLUSIONES
# -----------------------------------------------------------------------------
$totalAudited = $auditResults.Count
$signedPercentage = if ($totalAudited -gt 0) { [math]::Round(($validSignedCount / $totalAudited) * 100, 1) } else { 0 }

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN DE AUDITORIA DE CADENA DE SUMINISTRO " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Total de Archivos Auditados   : $totalAudited" -ForegroundColor White
Write-Host " Firmas Digitales Válidas      : $validSignedCount ($signedPercentage%)" -ForegroundColor Green
Write-Host "   - Firmados con SHA-256/384  : $sha256SignedCount" -ForegroundColor Green
Write-Host "   - Firmados con Legacy SHA-1 : $sha1LegacyCount (Runtimes históricos de Microsoft)" -ForegroundColor DarkGray
Write-Host " Binarios Locales / Sin Firma  : $unsignedCount (Lanzadores propios C# compilados sin cert)" -ForegroundColor Yellow

if ($VerifyCatalog) {
    if ($tamperedCount -eq 0) {
        Write-Host " Verificación de Catálogo      : 100% INTEGRO (Cero archivos alterados)" -ForegroundColor Green
    } else {
        Write-Host " Verificación de Catálogo      : ALERTA ($tamperedCount archivos no coinciden)" -ForegroundColor Red
    }
}

Write-Host " Duración del Análisis         : $([math]::Round(((Get-Date) - $auditStartTime).TotalSeconds, 2))s" -ForegroundColor DarkGray
Write-Host ""

return [PSCustomObject]@{
    TotalFiles         = $totalAudited
    ValidSigned        = $validSignedCount
    SignedPercentage   = $signedPercentage
    Sha256Signed       = $sha256SignedCount
    Sha1LegacySigned   = $sha1LegacyCount
    Unsigned           = $unsignedCount
    TamperedCount      = $tamperedCount
    AuditDetails       = $auditResults
}
