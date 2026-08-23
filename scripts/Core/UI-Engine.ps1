<#
.SYNOPSIS
    UI-Engine.ps1 - Motor de Interfaz de Consola y Formato Visual Unificado para romanOS
    Estandar de diseño e interaccion para toda la suite de scripts de PowerShell.

.DESCRIPTION
    Proporciona un conjunto coherente, sobrio y de alto rendimiento de componentes visuales
    para la consola de Windows (Banners, Pasos de Ejecucion, Marcadores de Estado, Menus
    Interactivos y Cajas de Resumen de Logs).
    Disenado para 0 ms de overhead, 100% compatible con Windows PowerShell 5.1 y PowerShell 7+.

.EXAMPLE
    . "$PSScriptRoot\Core\UI-Engine.ps1"
    Show-UnifiedBanner -Title "romanOS TOOLKIT" -Subtitle "v3.2"
    Write-StepHeader -StepNumber 1 -TotalSteps 3 -Message "Optimizando Sistema"
    Write-OK "Ajuste aplicado correctamente."
#>

# Prevenir re-definicion redundante si ya fue importado
if ($global:RomanOS_UI_Engine_Loaded) { return }
$global:RomanOS_UI_Engine_Loaded = $true

# Configurar ancho estandar de consola
$script:UI_BoxWidth = 74

function Show-UnifiedBanner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter()]
        [string]$Subtitle = "",
        [Parameter()]
        [switch]$ShowSystemInfo,
        [Parameter()]
        [switch]$NoClear
    )

    if (-not $NoClear) {
        try { Clear-Host -ErrorAction SilentlyContinue } catch {}
    }

    $w = $script:UI_BoxWidth
    $border = "═" * ($w - 2)

    Write-Host ""
    Write-Host "  ╔$border╗" -ForegroundColor DarkCyan

    # Centrado de Titulo
    $titlePadded = $Title.Trim()
    if ($titlePadded.Length -gt ($w - 4)) {
        $titlePadded = $titlePadded.Substring(0, $w - 4)
    }
    $padLeft = [math]::Max(0, [int](($w - 4 - $titlePadded.Length) / 2))
    $padRight = [math]::Max(0, $w - 4 - $titlePadded.Length - $padLeft)
    $titleLine = (" " * $padLeft) + $titlePadded + (" " * $padRight)
    Write-Host "  ║ $titleLine ║" -ForegroundColor Cyan

    # Centrado de Subtitulo
    if ($Subtitle) {
        $subPadded = $Subtitle.Trim()
        if ($subPadded.Length -gt ($w - 4)) {
            $subPadded = $subPadded.Substring(0, $w - 4)
        }
        $subPadLeft = [math]::Max(0, [int](($w - 4 - $subPadded.Length) / 2))
        $subPadRight = [math]::Max(0, $w - 4 - $subPadded.Length - $subPadLeft)
        $subLine = (" " * $subPadLeft) + $subPadded + (" " * $subPadRight)
        Write-Host "  ║ $subLine ║" -ForegroundColor DarkCyan
    }

    Write-Host "  ╚$border╝" -ForegroundColor DarkCyan

    # Telemetria de sistema opcional o por defecto
    if ($ShowSystemInfo) {
        try {
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            $adminBadge = if ($isAdmin) { " (Admin)" } else { " (Standard)" }
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
            $sysDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
            $freeGB = if ($sysDrive) { [math]::Round($sysDrive.FreeSpace / 1GB, 1) } else { "N/A" }

            Write-Host "  Host: $env:COMPUTERNAME | Usuario: $env:USERNAME$adminBadge" -ForegroundColor Gray
            if ($os) {
                Write-Host "  SO  : $($os.Caption) ($($os.OSArchitecture)) | C: $freeGB GB libres" -ForegroundColor Gray
            }
        } catch {}
        Write-Host "  $('─' * ($w - 2))" -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Write-StepHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$StepNumber,
        [Parameter(Mandatory = $true)]
        [int]$TotalSteps,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    Write-Host ""
    Write-Host ">>> [$StepNumber/$TotalSteps] $Message" -ForegroundColor Cyan
}

function Write-SubStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    Write-Host "  -> $Message" -ForegroundColor Gray
}

function Write-OK {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "  [WARN] $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "  [ERROR] $Message" -ForegroundColor Red
}

function Write-Info {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "  [i] $Message" -ForegroundColor DarkGray
}

function Show-UnifiedMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [array]$Options,
        [Parameter()]
        [int]$DefaultChoice = 1,
        [Parameter()]
        [switch]$AllowCancel,
        [Parameter()]
        [string]$CancelText = "Cancelar / Volver"
    )

    # Deteccion de entrada no interactiva / redirigida
    $isRedirected = $false
    try {
        if ([System.Console]::IsInputRedirected) { $isRedirected = $true }
    } catch {
        $isRedirected = $true
    }

    if ($isRedirected) {
        return $DefaultChoice
    }

    $w = $script:UI_BoxWidth
    $innerW = $w - 6

    Write-Host "  ┌─ $Title $('─' * [math]::Max(0, ($w - 7 - $Title.Length)))┐" -ForegroundColor DarkCyan

    for ($i = 0; $i -lt $Options.Count; $i++) {
        $numStr = "[$($i + 1)]"
        $optText = "$numStr $($Options[$i])"
        if ($optText.Length -gt $innerW) {
            $optText = $optText.Substring(0, $innerW)
        } else {
            $optText = $optText.PadRight($innerW)
        }
        Write-Host "  │  $optText│" -ForegroundColor White
    }

    if ($AllowCancel) {
        $cancelLine = "[0] $CancelText"
        if ($cancelLine.Length -gt $innerW) {
            $cancelLine = $cancelLine.Substring(0, $innerW)
        } else {
            $cancelLine = $cancelLine.PadRight($innerW)
        }
        Write-Host "  │  $cancelLine│" -ForegroundColor Gray
    }

    Write-Host "  └$('─' * ($w - 4))┘" -ForegroundColor DarkCyan

    $maxOpt = $Options.Count
    $minOpt = if ($AllowCancel) { 0 } else { 1 }
    $promptMsg = "  Seleccione una opcion [$minOpt-$maxOpt] (Default: $DefaultChoice)"

    $resp = Read-Host $promptMsg
    if ([string]::IsNullOrWhiteSpace($resp)) {
        return $DefaultChoice
    }

    $parsedNum = 0
    if ([int]::TryParse($resp, [ref]$parsedNum)) {
        if ($parsedNum -ge $minOpt -and $parsedNum -le $maxOpt) {
            return $parsedNum
        }
    }

    return $DefaultChoice
}

function Prompt-UnifiedYesNo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [Parameter()]
        [bool]$Default = $true
    )

    $isRedirected = $false
    try {
        if ([System.Console]::IsInputRedirected) { $isRedirected = $true }
    } catch {
        $isRedirected = $true
    }

    if ($isRedirected) {
        return $Default
    }

    $defStr = if ($Default) { "S" } else { "N" }
    $resp = Read-Host "  [?] $Prompt [S/N] (Default: $defStr)"

    if ([string]::IsNullOrWhiteSpace($resp)) {
        return $Default
    }

    if ($resp -match '^(s|si|y|yes)$') {
        return $true
    }
    if ($resp -match '^(n|no)$') {
        return $false
    }

    return $Default
}

function Show-UnifiedSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter()]
        [ValidateSet("SUCCESS", "WARNING", "FAILED")]
        [string]$Status = "SUCCESS",
        [Parameter()]
        [double]$DurationSeconds = 0,
        [Parameter()]
        [int]$ErrorsCount = 0,
        [Parameter()]
        [int]$WarnsCount = 0,
        [Parameter()]
        [hashtable]$Logs = @{}
    )

    $w = $script:UI_BoxWidth
    $border = "═" * ($w - 2)
    $innerW = $w - 4

    Write-Host ""
    Write-Host "  ╔$border╗" -ForegroundColor DarkCyan

    $sumTitle = "RESUMEN DE EJECUCION: $Title"
    if ($sumTitle.Length -gt $innerW) { $sumTitle = $sumTitle.Substring(0, $innerW) }
    $padLeft = [math]::Max(0, [int](($innerW - $sumTitle.Length) / 2))
    $padRight = [math]::Max(0, $innerW - $sumTitle.Length - $padLeft)
    Write-Host "  ║ $(' ' * $padLeft)$sumTitle$(' ' * $padRight) ║" -ForegroundColor Cyan

    Write-Host "  ╠$border╣" -ForegroundColor DarkCyan

    # Estado
    $statusColor = switch ($Status) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "FAILED"  { "Red" }
    }
    $statusText = switch ($Status) {
        "SUCCESS" { "COMPLETADO CON EXITO [OK]" }
        "WARNING" { "COMPLETADO CON ADVERTENCIAS [WARN]" }
        "FAILED"  { "FALLIDO / CON ERRORES [FAIL]" }
    }

    $lineStatus = "  Estado Global        : $statusText".PadRight($innerW)
    Write-Host "  ║" -NoNewline -ForegroundColor DarkCyan
    Write-Host " $lineStatus" -NoNewline -ForegroundColor $statusColor
    Write-Host "║" -ForegroundColor DarkCyan

    if ($DurationSeconds -gt 0) {
        $lineDur = "  Tiempo Transcurrido  : ${DurationSeconds}s".PadRight($innerW)
        Write-Host "  ║ $lineDur ║" -ForegroundColor Gray
    }

    $lineErr = "  Incidencias          : $ErrorsCount error(es) | $WarnsCount advertencia(s)".PadRight($innerW)
    Write-Host "  ║ $lineErr ║" -ForegroundColor Gray

    if ($Logs -and $Logs.Count -gt 0) {
        $logHeader = "  Logs y Reportes IA Generados:".PadRight($innerW)
        Write-Host "  ║ $logHeader ║" -ForegroundColor Cyan
        foreach ($k in $Logs.Keys) {
            $logPath = $Logs[$k]
            if ($logPath) {
                $itemStr = "   - $($k): $logPath"
                if ($itemStr.Length -gt $innerW) {
                    $itemStr = $itemStr.Substring(0, $innerW - 3) + "..."
                } else {
                    $itemStr = $itemStr.PadRight($innerW)
                }
                Write-Host "  ║ $itemStr ║" -ForegroundColor DarkGray
            }
        }
    }

    Write-Host "  ╚$border╝" -ForegroundColor DarkCyan
    Write-Host ""
}
