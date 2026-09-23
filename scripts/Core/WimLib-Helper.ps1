<#
.SYNOPSIS
    romanOS Core - WimLib Acceleration Helper (Cero Montaje)
.DESCRIPTION
    Funciones de alto rendimiento para inspección, lectura de metadata y extracción
    quirúrgica de archivos en imágenes WIM/ESD sin requerir montaje de DISM (Zero-Mount).
    Cumple con la arquitectura unificada y compatibilidad Windows PowerShell 5.1 / 7+.
#>

function Get-WimLibPath {
    [CmdletBinding()]
    param()

    # 1. Ruta canónica local en herramientas del proyecto
    $projectToolsPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'tools\wimlib\wimlib-imagex.exe'
    if (Test-Path -LiteralPath $projectToolsPath) {
        return (Resolve-Path -LiteralPath $projectToolsPath).Path
    }

    # 2. Ruta estándar fija de contingencia
    $fixedPath = 'c:\OptimizedISO\tools\wimlib\wimlib-imagex.exe'
    if (Test-Path -LiteralPath $fixedPath) {
        return $fixedPath
    }

    # 3. PATH del sistema
    $cmd = Get-Command 'wimlib-imagex.exe' -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    return $null
}

function Test-WimLibAvailable {
    [CmdletBinding()]
    param()
    $exe = Get-WimLibPath
    return ($null -ne $exe -and (Test-Path -LiteralPath $exe))
}

function Get-WimImageInfoFast {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WimPath,
        [int]$ImageIndex = 0
    )

    $exe = Get-WimLibPath
    if (-not $exe) {
        throw "wimlib-imagex.exe no está disponible en el entorno."
    }

    if (-not (Test-Path -LiteralPath $WimPath)) {
        throw "El archivo WIM especificado no existe: $WimPath"
    }

    $argsList = @('info', "`"$WimPath`"")
    if ($ImageIndex -gt 0) {
        $argsList += $ImageIndex.ToString()
    }

    $process = Start-Process -FilePath $exe -ArgumentList ($argsList -join ' ') -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\wimlib_info.txt" -RedirectStandardError "$env:TEMP\wimlib_info_err.txt"
    $stdout = Get-Content "$env:TEMP\wimlib_info.txt" -Raw -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\wimlib_info.txt", "$env:TEMP\wimlib_info_err.txt" -Force -ErrorAction SilentlyContinue

    return $stdout
}

function Get-WimContentFast {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WimPath,
        [int]$ImageIndex = 1,
        [string]$PathFilter = ''
    )

    $exe = Get-WimLibPath
    if (-not $exe) {
        throw "wimlib-imagex.exe no está disponible en el entorno."
    }

    if (-not (Test-Path -LiteralPath $WimPath)) {
        throw "El archivo WIM especificado no existe: $WimPath"
    }

    $outFile = "$env:TEMP\wimlib_dir.txt"
    $argsList = "dir `"$WimPath`" $ImageIndex"
    if ($PathFilter) {
        $argsList += " --path=`"$PathFilter`""
    }

    $process = Start-Process -FilePath $exe -ArgumentList $argsList -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outFile
    if (Test-Path -LiteralPath $outFile) {
        $lines = Get-Content -LiteralPath $outFile
        Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
        return $lines
    }

    return @()
}

function Extract-WimFileFast {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WimPath,
        [int]$ImageIndex = 1,
        [Parameter(Mandatory = $true)]
        [string]$FilePathInWim,
        [Parameter(Mandatory = $true)]
        [string]$DestinationDir
    )

    $exe = Get-WimLibPath
    if (-not $exe) {
        throw "wimlib-imagex.exe no está disponible en el entorno."
    }

    if (-not (Test-Path -LiteralPath $DestinationDir)) {
        New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
    }

    $argsList = "extract `"$WimPath`" $ImageIndex `"$FilePathInWim`" --dest-dir=`"$DestinationDir`" --no-acls"
    $process = Start-Process -FilePath $exe -ArgumentList $argsList -NoNewWindow -Wait -PassThru
    return ($process.ExitCode -eq 0)
}

if ($ExecutionContext.SessionState.Module) {
    Export-ModuleMember -Function Get-WimLibPath, Test-WimLibAvailable, Get-WimImageInfoFast, Get-WimContentFast, Extract-WimFileFast -ErrorAction SilentlyContinue
}
