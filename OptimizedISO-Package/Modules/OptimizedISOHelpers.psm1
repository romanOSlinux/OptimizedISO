function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet('INFO','WARN','ERROR')][string]$Level,
        [Parameter(Mandatory)][string]$Message
    )
    $entry = [pscustomobject]@{
        timestamp = (Get-Date).ToString('o')
        level     = $Level
        message   = $Message
    }
    $json = $entry | ConvertTo-Json -Compress
    Add-Content -Path $Path -Value $json
}

function Set-Reg {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [ValidateSet('String','DWORD','ExpandString','MultiString','Binary')][string]$Type = 'DWORD'
    )
    # Ensure key exists
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Sign-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][string]$CertPfxPath,
        [Parameter(Mandatory)][securestring]$Password
    )
    $cert = Get-PfxCertificate -FilePath $CertPfxPath -Password $Password
    Set-AuthenticodeSignature -FilePath $ScriptPath -Certificate $cert | Out-Null
}
