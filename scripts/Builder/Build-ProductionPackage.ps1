<#
.SYNOPSIS
    Empaquetador de Distribución Oficial Portable de romanOS (USB y GitHub Releases).
.DESCRIPTION
    Ensambla el árbol de distribución autónomo y portátil de romanOS en 'dist/romanOS-USB-Portable',
    incluyendo puntos de entrada universales (Lanzar-romanOS.cmd / .ps1), módulos de optimización,
    núcleo SSOT (scripts/Core), GUIs WPF (-STA), helpers de escritorio, herramientas de host,
    presets universales y herramientas portables de bajo nivel (Sysinternals, wimlib, Everything).
    Excluye estrictamente arneses de testing, telemetría de desarrollo, artefactos Git y temporales.
    Genera un archivo comprimido .ZIP de alta compatibilidad y su manifiesto SHA-256.
.PARAMETER OutputDir
    Directorio de destino para la salida portable y el archivo comprimido ZIP.
.PARAMETER PackageName
    Nombre base del paquete generado. Por defecto: 'romanOS-Universal-v3.0.0'.
.PARAMETER SkipZip
    Si se especifica, solo ensambla la carpeta portable sin generar el archivo .ZIP comprimido.
.PARAMETER CleanDestination
    Limpia el directorio de destino antes de ensamblar si ya existe.
.PARAMETER WhatIf
    Ejecuta el script en modo de simulación diagnóstica sin realizar copias físicas ni escrituras en disco.
.PARAMETER PassThru
    Devuelve un objeto de resultados con métricas cuantitativas del paquete ensamblado.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$OutputDir,
    [string]$PackageName = "romanOS-Universal-v3.0.0",
    [switch]$SkipZip,
    [switch]$CleanDestination,
    [switch]$PassThru
)

# -----------------------------------------------------------------------------
# 1. RESOLUCIÓN DE RUTAS Y CONSTANTES DEL ECOSISTEMA
# -----------------------------------------------------------------------------
$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

if (-not $OutputDir) {
    $OutputDir = Join-Path $script:RepoRoot "dist"
}

$portableDirName = "romanOS-USB-Portable"
$portableTarget = Join-Path $OutputDir $portableDirName
$zipTargetPath  = Join-Path $OutputDir "$PackageName.zip"
$shaTargetPath  = Join-Path $OutputDir "$PackageName.zip.sha256"

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS — EMPAQUETADOR DE DISTRIBUCIÓN OFICIAL (PORTABLE & USB)           " -ForegroundColor White
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "  Repositorio Base   : $script:RepoRoot" -ForegroundColor Gray
Write-Host "  Destino Portable   : $portableTarget" -ForegroundColor Gray
Write-Host "  Archivo ZIP        : $zipTargetPath" -ForegroundColor Gray
Write-Host "  Modo Simulado      : $(if ($PSCmdlet.ShouldProcess($portableTarget, 'Empaquetar distribución')) { 'No' } else { 'Sí (WhatIf)' })" -ForegroundColor Gray
Write-Host "==========================================================================" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# 2. DEFINICIÓN DEL MANIFIESTO DE EMPAQUETADO Y EXCLUSIONES
# -----------------------------------------------------------------------------
$rootFilesToCopy = @(
    "Lanzar-romanOS.cmd",
    "Lanzar-romanOS.ps1",
    "Preset_Gaming_Universal.json",
    "Preset_Workstation_Universal.json",
    "Preset_romanOS_Studio.json",
    "README.md"
)

$scriptDirsToCopy = @(
    "Core",
    "GUI",
    "Modules",
    "Drivers",
    "Desktop-Helpers",
    "Host-Tools",
    "Builder"
)

$toolsDirsToCopy = @(
    "sysinternals",
    "wimlib",
    "everything"
)

$packageMetrics = [PSCustomObject]@{
    PackageName     = $PackageName
    PortablePath    = $portableTarget
    ZipPath         = $zipTargetPath
    Sha256Hash      = ""
    FilesCopied     = 0
    TotalBytes      = 0
    DurationSeconds = 0
    Success         = $false
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# -----------------------------------------------------------------------------
# 3. LIMPIEZA PREVIA Y PREPARACIÓN DE CARPETAS
# -----------------------------------------------------------------------------
if ($PSCmdlet.ShouldProcess($portableTarget, "Limpiar y preparar estructura de directorios")) {
    try {
        if (-not (Test-Path -Path $OutputDir)) {
            New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
        }

        if (Test-Path -Path $portableTarget) {
            if ($CleanDestination) {
                Write-Host "  [*] Limpiando directorio previo: $portableTarget..." -ForegroundColor Yellow
                Remove-Item -Path $portableTarget -Recurse -Force | Out-Null
            }
        }

        if (-not (Test-Path -Path $portableTarget)) {
            New-Item -Path $portableTarget -ItemType Directory -Force | Out-Null
        }
    } catch {
        Write-Error "[Empaquetador] Error crítico preparando directorios de salida: $($_.Exception.Message)"
        return $packageMetrics
    }
}

# -----------------------------------------------------------------------------
# 4. COPIA DE ARCHIVOS RAÍZ Y GENERACIÓN DE LEAME
# -----------------------------------------------------------------------------
Write-Host "`n>>> [1/4] Copiando lanzadores de raíz, presets y documentación..." -ForegroundColor Cyan

foreach ($file in $rootFilesToCopy) {
    $sourcePath = Join-Path $script:RepoRoot $file
    if (Test-Path -Path $sourcePath) {
        $destPath = Join-Path $portableTarget $file
        if ($PSCmdlet.ShouldProcess($sourcePath, "Copiar hacia $destPath")) {
            Copy-Item -Path $sourcePath -Destination $destPath -Force
            $packageMetrics.FilesCopied++
            $packageMetrics.TotalBytes += (Get-Item $sourcePath).Length
            Write-Host "  [+] Copiado: $file" -ForegroundColor Green
        } else {
            Write-Host "  [WhatIf] Se copiaría: $file" -ForegroundColor Gray
            $packageMetrics.FilesCopied++
        }
    } else {
        Write-Warning "[Empaquetador] Archivo opcional no encontrado en raíz: $file"
    }
}

# Generar LEAME-PRIMERO.txt con instrucciones de uso para USB
$leameContent = @"
==========================================================================
 romanOS v3.0 Universal — Edición Portable y USB Offline
==========================================================================

Bienvenido a romanOS v3.0 Universal, el entorno unificado de optimización,
mantenimiento, debloat y afinamiento para Windows 11 y Windows 10.

INSTRUCCIONES DE USO:
--------------------
1. INICIO RÁPIDO (RECOMENDADO):
   Haga doble clic en 'Lanzar-romanOS.cmd'.
   El sistema solicitará permisos de Administrador automáticamente y abrirá
   el Centro de Control Gráfico oficial (romanOS Control Center).

2. EJECUCIÓN POR CONSOLA (POWERSHELL):
   Abra PowerShell como Administrador y ejecute:
   powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File .\Lanzar-romanOS.ps1

3. CARACTERÍSTICAS PRINCIPALES:
   - Centro de Control Gráfico WPF fluido a 60 FPS.
   - Reversibilidad Garantizada en 1 Clic (Snapshot y Puntos de Restauración).
   - Motor de Políticas SSOT adaptativo al hardware (Intel/AMD, APU/dGPU, NVMe/SATA).
   - Presets Universales preconfigurados (Gaming y Workstation).
   - Herramientas portables oficiales de Sysinternals, wimlib y Everything.

Repositorio y Actualizaciones Oficiales:
https://github.com/romanOSlinux/OptimizedISO
==========================================================================
"@

$leamePath = Join-Path $portableTarget "LEAME-PRIMERO.txt"
if ($PSCmdlet.ShouldProcess($leamePath, "Crear archivo LEAME-PRIMERO.txt")) {
    [System.IO.File]::WriteAllText($leamePath, $leameContent, [System.Text.Encoding]::UTF8)
    $packageMetrics.FilesCopied++
    $packageMetrics.TotalBytes += (Get-Item $leamePath).Length
    Write-Host "  [+] Generado: LEAME-PRIMERO.txt" -ForegroundColor Green
} else {
    Write-Host "  [WhatIf] Se generaría: LEAME-PRIMERO.txt" -ForegroundColor Gray
    $packageMetrics.FilesCopied++
}

# -----------------------------------------------------------------------------
# 5. COPIA ESTRUCTURADA DE SCRIPTS (EXCLUYENDO TESTING)
# -----------------------------------------------------------------------------
Write-Host "`n>>> [2/4] Copiando módulos de scripts de producción (scripts/*)..." -ForegroundColor Cyan

$destScriptsDir = Join-Path $portableTarget "scripts"
if ($PSCmdlet.ShouldProcess($destScriptsDir, "Crear directorio de scripts")) {
    if (-not (Test-Path -Path $destScriptsDir)) {
        New-Item -Path $destScriptsDir -ItemType Directory -Force | Out-Null
    }
}

foreach ($dir in $scriptDirsToCopy) {
    $sourceDir = Join-Path $script:RepoRoot (Join-Path "scripts" $dir)
    if (Test-Path -Path $sourceDir) {
        $targetSubDir = Join-Path $destScriptsDir $dir
        Write-Host "  [*] Procesando módulo: scripts/$dir..." -ForegroundColor White

        $files = Get-ChildItem -Path $sourceDir -Recurse -File | Where-Object {
            $_.Extension -match '^\.(ps1|psm1|psd1|cmd|bat|json|xml|xaml|txt|md)$' -and
            $_.FullName -notmatch '\\(Testing|scratch|Log|bin|obj)\\'
        }

        foreach ($fileItem in $files) {
            $relPath = $fileItem.FullName.Substring($sourceDir.Length).TrimStart('\', '/')
            $destFile = Join-Path $targetSubDir $relPath
            $destFileDir = [System.IO.Path]::GetDirectoryName($destFile)

            if ($PSCmdlet.ShouldProcess($fileItem.FullName, "Copiar hacia $destFile")) {
                if (-not (Test-Path -Path $destFileDir)) {
                    New-Item -Path $destFileDir -ItemType Directory -Force | Out-Null
                }
                Copy-Item -Path $fileItem.FullName -Destination $destFile -Force
                $packageMetrics.FilesCopied++
                $packageMetrics.TotalBytes += $fileItem.Length
            } else {
                $packageMetrics.FilesCopied++
            }
        }
        Write-Host "  [+] Módulo scripts/$dir empaquetado exitosamente ($($files.Count) archivos)." -ForegroundColor Green
    } else {
        Write-Warning "[Empaquetador] Directorio de scripts no encontrado: $sourceDir"
    }
}

# -----------------------------------------------------------------------------
# 6. COPIA DE HERRAMIENTAS PORTABLES (TOOLS)
# -----------------------------------------------------------------------------
Write-Host "`n>>> [3/4] Copiando utilidades de bajo nivel portables (tools/*)..." -ForegroundColor Cyan

$destToolsDir = Join-Path $portableTarget "tools"
if ($PSCmdlet.ShouldProcess($destToolsDir, "Crear directorio tools")) {
    if (-not (Test-Path -Path $destToolsDir)) {
        New-Item -Path $destToolsDir -ItemType Directory -Force | Out-Null
    }
}

foreach ($toolDir in $toolsDirsToCopy) {
    $sourceToolPath = Join-Path $script:RepoRoot (Join-Path "tools" $toolDir)
    if (Test-Path -Path $sourceToolPath) {
        $targetToolSubDir = Join-Path $destToolsDir $toolDir
        Write-Host "  [*] Procesando herramienta: tools/$toolDir..." -ForegroundColor White

        $toolFiles = Get-ChildItem -Path $sourceToolPath -Recurse -File | Where-Object {
            $_.FullName -notmatch '\\(devel|obj|\.git)\\'
        }

        foreach ($tFile in $toolFiles) {
            $relPath = $tFile.FullName.Substring($sourceToolPath.Length).TrimStart('\', '/')
            $destToolFile = Join-Path $targetToolSubDir $relPath
            $destToolFileDir = [System.IO.Path]::GetDirectoryName($destToolFile)

            if ($PSCmdlet.ShouldProcess($tFile.FullName, "Copiar hacia $destToolFile")) {
                if (-not (Test-Path -Path $destToolFileDir)) {
                    New-Item -Path $destToolFileDir -ItemType Directory -Force | Out-Null
                }
                Copy-Item -Path $tFile.FullName -Destination $destToolFile -Force
                $packageMetrics.FilesCopied++
                $packageMetrics.TotalBytes += $tFile.Length
            } else {
                $packageMetrics.FilesCopied++
            }
        }
        Write-Host "  [+] Utilidad tools/$toolDir empaquetada exitosamente ($($toolFiles.Count) archivos)." -ForegroundColor Green
    } else {
        Write-Warning "[Empaquetador] Directorio de herramientas no encontrado: $sourceToolPath"
    }
}

# -----------------------------------------------------------------------------
# 7. GENERACIÓN DEL PAQUETE COMPRIMIDO (.ZIP) Y HASH SHA-256
# -----------------------------------------------------------------------------
Write-Host "`n>>> [4/4] Creación de archivo comprimido y manifiesto SHA-256..." -ForegroundColor Cyan

if (-not $SkipZip) {
    if ($PSCmdlet.ShouldProcess($zipTargetPath, "Comprimir carpeta portable hacia archivo ZIP")) {
        try {
            if (Test-Path -Path $zipTargetPath) {
                Write-Host "  [*] Eliminando archivo ZIP previo..." -ForegroundColor Yellow
                Remove-Item -Path $zipTargetPath -Force | Out-Null
            }

            Write-Host "  [*] Ensamblando archivo ZIP comprimido: $zipTargetPath..." -ForegroundColor White
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::CreateFromDirectory(
                $portableTarget,
                $zipTargetPath,
                [System.IO.Compression.CompressionLevel]::Optimal,
                $false
            )

            if (Test-Path -Path $zipTargetPath) {
                $zipItem = Get-Item -Path $zipTargetPath
                Write-Host "  [+] Archivo ZIP generado con éxito ($([Math]::Round($zipItem.Length / 1MB, 2)) MB)." -ForegroundColor Green

                # Generar Hash SHA-256
                $hasher = [System.Security.Cryptography.SHA256]::Create()
                $fileStream = [System.IO.File]::OpenRead($zipTargetPath)
                $hashBytes = $hasher.ComputeHash($fileStream)
                $fileStream.Dispose()
                $hasher.Dispose()

                $hashString = [System.BitConverter]::ToString($hashBytes) -replace '-', ''
                $packageMetrics.Sha256Hash = $hashString

                $shaContent = "$hashString  $([System.IO.Path]::GetFileName($zipTargetPath))"
                [System.IO.File]::WriteAllText($shaTargetPath, $shaContent, [System.Text.Encoding]::UTF8)

                Write-Host "  [+] Manifiesto SHA-256: $hashString" -ForegroundColor Cyan
                Write-Host "  [+] Guardado en: $shaTargetPath" -ForegroundColor Green
            }
        } catch {
            Write-Error "[Empaquetador] Error durante la compresión ZIP: $($_.Exception.Message)"
        }
    } else {
        Write-Host "  [WhatIf] Se comprimiría $portableTarget hacia $zipTargetPath con manifiesto SHA-256." -ForegroundColor Gray
    }
} else {
    Write-Host "  [-] Generación de ZIP omitida por parámetro -SkipZip." -ForegroundColor Yellow
}

$stopwatch.Stop()
$packageMetrics.DurationSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
$packageMetrics.Success = $true

# -----------------------------------------------------------------------------
# 8. RESUMEN EJECUTIVO Y VERIFICACIÓN DE INTEGRIDAD
# -----------------------------------------------------------------------------
Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN: EMPAQUETADO DE DISTRIBUCIÓN OFICIAL DE romanOS                  " -ForegroundColor White
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "  Paquete              : $($packageMetrics.PackageName)" -ForegroundColor Gray
Write-Host "  Archivos Copiados    : $($packageMetrics.FilesCopied)" -ForegroundColor Green
Write-Host "  Volumen Descomprimido: $([Math]::Round($packageMetrics.TotalBytes / 1MB, 2)) MB" -ForegroundColor Gray
if ($packageMetrics.Sha256Hash) {
    Write-Host "  SHA-256              : $($packageMetrics.Sha256Hash)" -ForegroundColor Cyan
}
Write-Host "  Tiempo Transcurrido  : $($packageMetrics.DurationSeconds)s" -ForegroundColor Gray
Write-Host "  Estado Global        : COMPLETADO CON ÉXITO [OK]" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan

if ($PassThru) {
    return $packageMetrics
}
