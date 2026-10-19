<#
.SYNOPSIS
    romanOS Core - Sysinternals Observability & Driver Verification Helper
.DESCRIPTION
    Integración de alto nivel de las herramientas oficiales de Microsoft Sysinternals:
    - sigcheck64: Certificación de firmas WHQL y arquitectura de controladores y binarios.
    - autorunsc64: Auditoría forense de puntos de inicio, servicios y persistencia de telemetría.
    - Coreinfo64: Introspección de topología de CPU, jerarquía de caché y extensiones de microarquitectura.
    Cumple con la arquitectura unificada y compatibilidad Windows PowerShell 5.1 / 7+.
#>

function Get-SysinternalsToolPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName
    )

    if (-not $ToolName.EndsWith('.exe', [System.StringComparison]::OrdinalIgnoreCase)) {
        $ToolName = "$ToolName.exe"
    }

    # 1. Ruta relativa al script
    $projectToolsPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "tools\sysinternals\$ToolName"
    if (Test-Path -LiteralPath $projectToolsPath) {
        return (Resolve-Path -LiteralPath $projectToolsPath).Path
    }

    # 2. Ruta fija estándar
    $fixedPath = Join-Path $env:SystemRoot "Setup\tools\sysinternals\$ToolName"
    if (Test-Path -LiteralPath $fixedPath) {
        return $fixedPath
    }

    # 3. PATH global
    $cmd = Get-Command $ToolName -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    return $null
}

function Test-DriverSignature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$FilePath
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        Write-Error "El archivo especificado no existe: $FilePath"
        return $null
    }

    $sigcheck = Get-SysinternalsToolPath -ToolName 'sigcheck64.exe'
    if (-not $sigcheck) {
        Write-Warning "sigcheck64.exe no está disponible en tools/sysinternals/."
        return $null
    }

    $tempOut = "$env:TEMP\sigcheck_out_$([guid]::NewGuid().ToString('N')).bin"
    try {
        $argsList = "-accepteula -nobanner -a -c `"$FilePath`""
        $proc = Start-Process -FilePath $sigcheck -ArgumentList $argsList -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempOut
        
        if (Test-Path -LiteralPath $tempOut) {
            $rawBytes = [System.IO.File]::ReadAllBytes($tempOut)
            if ($rawBytes.Length -gt 2) {
                $text = [System.Text.Encoding]::Unicode.GetString($rawBytes)
                $csvData = $text | ConvertFrom-Csv -ErrorAction SilentlyContinue
                if ($csvData) {
                    $item = $csvData[0]
                    $isSigned = ($item.Verified -eq 'Signed')
                    return [PSCustomObject]@{
                        FilePath     = $FilePath
                        Verified     = $item.Verified
                        IsSigned     = $isSigned
                        Publisher    = $item.Publisher
                        Description  = $item.Description
                        Product      = $item.Product
                        Version      = $item.'Product Version'
                        MachineType  = $item.'Machine Type'
                        CatalogFile  = $item.'Catalog file'
                        Signers      = $item.Signers
                    }
                }
            }
        }
    } finally {
        Remove-Item -LiteralPath $tempOut -Force -ErrorAction SilentlyContinue
    }

    return $null
}

function Get-SysinternalsAutoruns {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('*', 's', 't', 'l', 'd', 'b')]
        [string]$Category = '*',

        [Parameter()]
        [switch]$HideMicrosoft
    )

    $autorunsc = Get-SysinternalsToolPath -ToolName 'autorunsc64.exe'
    if (-not $autorunsc) {
        Write-Warning "autorunsc64.exe no está disponible en tools/sysinternals/."
        return @()
    }

    $tempOut = "$env:TEMP\autoruns_out_$([guid]::NewGuid().ToString('N')).bin"
    try {
        $argList = @('-accepteula', '-nobanner', '-c', "-a $Category")
        if ($HideMicrosoft) {
            $argList += '-m'
        }

        $proc = Start-Process -FilePath $autorunsc -ArgumentList ($argList -join ' ') -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempOut
        if (Test-Path -LiteralPath $tempOut) {
            $rawBytes = [System.IO.File]::ReadAllBytes($tempOut)
            if ($rawBytes.Length -gt 2) {
                $text = [System.Text.Encoding]::Unicode.GetString($rawBytes)
                $csv = $text | ConvertFrom-Csv -ErrorAction SilentlyContinue
                return $csv
            }
        }
    } finally {
        Remove-Item -LiteralPath $tempOut -Force -ErrorAction SilentlyContinue
    }

    return @()
}

function Get-CpuCoreTopology {
    [CmdletBinding()]
    param()

    $coreinfo = Get-SysinternalsToolPath -ToolName 'Coreinfo64.exe'
    if (-not $coreinfo) {
        Write-Warning "Coreinfo64.exe no está disponible en tools/sysinternals/."
        return $null
    }

    $tempOut = "$env:TEMP\coreinfo_out_$([guid]::NewGuid().ToString('N')).bin"
    try {
        $proc = Start-Process -FilePath $coreinfo -ArgumentList '-accepteula -nobanner -f' -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempOut
        if (Test-Path -LiteralPath $tempOut) {
            $rawBytes = [System.IO.File]::ReadAllBytes($tempOut)
            if ($rawBytes.Length -gt 2) {
                $text = [System.Text.Encoding]::Unicode.GetString($rawBytes)
                $lines = $text -split "`r?`n"
                $flags = @{}
                foreach ($line in $lines) {
                    if ($line -match '^\s*([A-Za-z0-9_-]+)\s+(\*|-)\s+(.*)$') {
                        $feature = $matches[1].Trim()
                        $supported = ($matches[2] -eq '*')
                        $desc = $matches[3].Trim()
                        $flags[$feature] = [PSCustomObject]@{
                            Feature     = $feature
                            Supported   = $supported
                            Description = $desc
                        }
                    }
                }
                return $flags
            }
        }
    } finally {
        Remove-Item -LiteralPath $tempOut -Force -ErrorAction SilentlyContinue
    }

    return $null
}

if ($ExecutionContext.SessionState.Module) {
    Export-ModuleMember -Function Get-SysinternalsToolPath, Test-DriverSignature, Get-SysinternalsAutoruns, Get-CpuCoreTopology -ErrorAction SilentlyContinue
}
