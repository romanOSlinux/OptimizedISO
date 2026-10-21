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

$global:RomanOS_UI_Engine_Loaded = $true

# Configurar ancho estandar de consola
$script:UI_BoxWidth = 74

# Telemetria y Observabilidad Global (PLAN-0054 SSOT)
if ($null -eq $global:RomanOS_LogErrors) {
    $global:RomanOS_LogErrors = New-Object System.Collections.ArrayList
}
if ($null -eq $global:RomanOS_LogWarns) {
    $global:RomanOS_LogWarns = New-Object System.Collections.ArrayList
}
if ($null -eq $global:RomanOS_LogFile) {
    $global:RomanOS_LogFile = ""
}

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
        try { Clear-Host -ErrorAction Stop } catch {
            Write-Verbose "[UI-Engine] Clear-Host omitido en entorno no interactivo."
        }
    }

    $w = if ($script:UI_BoxWidth -and $script:UI_BoxWidth -gt 10) { $script:UI_BoxWidth } else { 74 }
    $border = "═" * [math]::Max(1, ($w - 2))

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

    # Telemetria de sistema opcional o por defecto (SSOT via Get-HostTelemetry.ps1)
    if ($ShowSystemInfo) {
        try {
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            $adminBadge = if ($isAdmin) { " (Admin)" } else { " (Standard)" }
            
            $telemetryScript = Join-Path $PSScriptRoot "Get-HostTelemetry.ps1"
            $hostData = $null
            if (Test-Path $telemetryScript) {
                if (-not $global:RomanOS_CachedHostTelemetry) {
                    $global:RomanOS_CachedHostTelemetry = & $telemetryScript -Quiet -ErrorAction SilentlyContinue
                }
                $hostData = $global:RomanOS_CachedHostTelemetry
            }

            $sysLetter = if ($env:SystemDrive) { $env:SystemDrive } else { "C:" }
            $sysDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sysLetter'" -ErrorAction SilentlyContinue
            $freeGB = if ($sysDrive) { [math]::Round($sysDrive.FreeSpace / 1GB, 1) } else { "N/A" }

            Write-Host "  Host: $env:COMPUTERNAME | Usuario: $env:USERNAME$adminBadge" -ForegroundColor Gray
            if ($hostData) {
                Write-Host "  SO  : $($hostData.Caption) $($hostData.DisplayVersion) (Build $($hostData.FullBuild)) | $sysLetter $freeGB GB libres | RAM: $($hostData.UsedPhysicalRAM) GB / $($hostData.TotalVisibleRAM) GB" -ForegroundColor Gray
            } else {
                $osFallback = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
                if ($osFallback) {
                    Write-Host "  SO  : $($osFallback.Caption) ($($osFallback.OSArchitecture)) | $sysLetter $freeGB GB libres" -ForegroundColor Gray
                }
            }
        } catch {
            Write-Warning "[UI-Engine] No se pudo adquirir telemetría de sistema: $($_.Exception.Message)"
        }
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

function Initialize-UnifiedLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter()]
        [switch]$Append
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force -ErrorAction SilentlyContinue | Out-Null
    }

    $global:RomanOS_LogFile = $Path
    if (-not $Append) {
        $header = "=== romanOS Unified Log Session Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
        [System.IO.File]::WriteAllLines($Path, @($header), [System.Text.Encoding]::UTF8)
    }
}

function Write-UnifiedLogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter()]
        [ValidateSet("INFO", "OK", "WARN", "ERROR", "DEBUG", "TRACE")]
        [string]$Level = "INFO",
        [Parameter()]
        [string]$TargetLogFile = $global:RomanOS_LogFile
    )

    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logLine = "[$ts] [$Level] $Message"

    if ($TargetLogFile) {
        try {
            [System.IO.File]::AppendAllText($TargetLogFile, ($logLine + "`r`n"), [System.Text.Encoding]::UTF8)
        } catch {
            $null = $_.Exception # Fallback para evitar recursión infinita si el archivo de log está bloqueado
        }
    }
    return $logLine
}

function Write-OK {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
    Write-UnifiedLogEntry -Message $Message -Level "OK" | Out-Null
    try {
        if ($script:CurrentStepObj) {
            if ($script:CurrentStepObj.Status -eq "IN_PROGRESS") {
                $script:CurrentStepObj.Status = "OK"
            }
            if (-not $script:CurrentStepObj.Note) {
                $script:CurrentStepObj.Note = $Message
            }
        }
    } catch {
        Write-Verbose "[UI-Engine] No se pudo actualizar CurrentStepObj: $($_.Exception.Message)"
    }
}

function Write-Warn {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter()][string]$Cause = "",
        [Parameter()][string]$Action = ""
    )

    $fullMsg = $Message
    if ($Cause -or $Action) {
        $details = @()
        if ($Cause) { $details += "Causa: $Cause" }
        if ($Action) { $details += "Accion: $Action" }
        $fullMsg = "$Message (" + ($details -join " | ") + ")"
    }

    Write-Host "  [WARN] $fullMsg" -ForegroundColor Yellow
    Write-UnifiedLogEntry -Message $fullMsg -Level "WARN" | Out-Null
    if ($null -ne $global:RomanOS_LogWarns) {
        [void]$global:RomanOS_LogWarns.Add($fullMsg)
    }
    try {
        if ($null -ne $script:LogWarns -and -not [object]::ReferenceEquals($script:LogWarns, $global:RomanOS_LogWarns)) {
            [void]$script:LogWarns.Add($fullMsg)
        }
    } catch {
        Write-Verbose "[UI-Engine] No se pudo agregar advertencia a script:LogWarns: $($_.Exception.Message)"
    }
    try {
        if ($script:CurrentStepObj -and $script:CurrentStepObj.Status -ne "ERROR") {
            $script:CurrentStepObj.Status = "WARN"
            $script:CurrentStepObj.Note = $fullMsg
        }
    } catch {
        Write-Verbose "[UI-Engine] No se pudo actualizar CurrentStepObj con advertencia: $($_.Exception.Message)"
    }
}

function Write-ErrorMsg {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter()][string]$Cause = "",
        [Parameter()][string]$Action = ""
    )

    $fullMsg = $Message
    if ($Cause -or $Action) {
        $details = @()
        if ($Cause) { $details += "Causa: $Cause" }
        if ($Action) { $details += "Accion: $Action" }
        $fullMsg = "$Message (" + ($details -join " | ") + ")"
    }

    Write-Host "  [ERROR] $fullMsg" -ForegroundColor Red
    Write-UnifiedLogEntry -Message $fullMsg -Level "ERROR" | Out-Null
    if ($null -ne $global:RomanOS_LogErrors) {
        [void]$global:RomanOS_LogErrors.Add($fullMsg)
    }
    try {
        if ($null -ne $script:LogErrors -and -not [object]::ReferenceEquals($script:LogErrors, $global:RomanOS_LogErrors)) {
            [void]$script:LogErrors.Add($fullMsg)
        }
    } catch {
        Write-Verbose "[UI-Engine] No se pudo agregar error a script:LogErrors: $($_.Exception.Message)"
    }
    try {
        if ($script:CurrentStepObj) {
            $script:CurrentStepObj.Status = "ERROR"
            $script:CurrentStepObj.Note = $fullMsg
        }
    } catch {
        Write-Verbose "[UI-Engine] No se pudo actualizar CurrentStepObj con error: $($_.Exception.Message)"
    }
}

function Write-Info {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "  [i] $Message" -ForegroundColor DarkGray
    Write-UnifiedLogEntry -Message $Message -Level "INFO" | Out-Null
}

function Write-ForensicException {
    <#
    .SYNOPSIS
        Registra el volcado completo de una excepción en texto plano crudo sin sesgos.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Record,

        [Parameter()]
        [string]$Context = ""
    )

    $msg = ""
    $excType = ""
    $hresultHex = "0x00000000"
    $hresultDec = 0
    $scriptName = "Desconocido"
    $lineNum = 0
    $lineCode = ""
    $stackTrace = ""
    $innerMsg = ""

    if ($Record -is [System.Management.Automation.ErrorRecord]) {
        $msg = $Record.Exception.Message
        if ($Record.Exception) {
            $excType = $Record.Exception.GetType().FullName
            $hresultDec = $Record.Exception.HResult
            $hresultHex = "0x{0:X8}" -f $hresultDec
            if ($Record.Exception.InnerException) {
                $innerMsg = "$($Record.Exception.InnerException.GetType().FullName): $($Record.Exception.InnerException.Message)"
            }
        }
        if ($Record.InvocationInfo) {
            $scriptName = if ($Record.InvocationInfo.ScriptName) { Split-Path -Leaf $Record.InvocationInfo.ScriptName } else { $Record.InvocationInfo.MyCommand.Name }
            $lineNum = $Record.InvocationInfo.ScriptLineNumber
            $lineCode = if ($Record.InvocationInfo.Line) { $Record.InvocationInfo.Line.Trim() } else { "" }
        }
        $stackTrace = if ($Record.ScriptStackTrace) { $Record.ScriptStackTrace } else { $Record.Exception.StackTrace }
    } elseif ($Record -is [System.Exception]) {
        $msg = $Record.Message
        $excType = $Record.GetType().FullName
        $hresultDec = $Record.HResult
        $hresultHex = "0x{0:X8}" -f $hresultDec
        $stackTrace = $Record.StackTrace
        if ($Record.InnerException) {
            $innerMsg = "$($Record.InnerException.GetType().FullName): $($Record.InnerException.Message)"
        }
    } else {
        $msg = "$Record"
    }

    $ctxPrefix = if ($Context) { "[$Context] " } else { "" }
    $locStr = if ($lineNum -gt 0) { " en ${scriptName}:${lineNum}" } else { " en $scriptName" }
    $forensicHeader = "$($ctxPrefix)Excepción$($locStr): $msg"

    $sbPlain = [System.Text.StringBuilder]::new()
    [void]$sbPlain.AppendLine("══════════════════════════════════════════════════════════════════════════")
    [void]$sbPlain.AppendLine("[ERROR] $forensicHeader")
    if ($excType)    { [void]$sbPlain.AppendLine("  Tipo de Excepción : $excType") }
    if ($hresultDec) { [void]$sbPlain.AppendLine("  HResult           : $hresultDec ($hresultHex)") }
    if ($lineCode)   { [void]$sbPlain.AppendLine("  Línea de Código   : $lineCode") }
    if ($innerMsg)   { [void]$sbPlain.AppendLine("  Excepción Interna : $innerMsg") }
    if ($stackTrace) {
        [void]$sbPlain.AppendLine("  --- PILA DE EJECUCIÓN (STACK TRACE) ---")
        foreach ($sLine in ($stackTrace -split "`r?`n")) {
            if ($sLine.Trim()) { [void]$sbPlain.AppendLine("  | $sLine") }
        }
    }
    [void]$sbPlain.AppendLine("══════════════════════════════════════════════════════════════════════════")

    $fullReport = $sbPlain.ToString().TrimEnd()

    Write-Host ""
    Write-Host $fullReport -ForegroundColor Red
    Write-Host ""

    Write-UnifiedLogEntry -Message $fullReport -Level "ERROR" | Out-Null
    if ($null -ne $global:RomanOS_LogErrors) {
        [void]$global:RomanOS_LogErrors.Add($forensicHeader)
    }
    try {
        if ($null -ne $script:LogErrors -and -not [object]::ReferenceEquals($script:LogErrors, $global:RomanOS_LogErrors)) {
            [void]$script:LogErrors.Add($forensicHeader)
        }
    } catch {
        Write-Verbose "[UI-Engine] No se pudo registrar error en script:LogErrors: $($_.Exception.Message)"
    }
    try {
        if ($script:CurrentStepObj) {
            $script:CurrentStepObj.Status = "ERROR"
            $script:CurrentStepObj.Note = $forensicHeader
        }
    } catch {
        Write-Verbose "[UI-Engine] No se pudo actualizar CurrentStepObj: $($_.Exception.Message)"
    }

    return [PSCustomObject]@{
        Header          = $forensicHeader
        ExceptionType   = $excType
        HResult         = $hresultHex
        LineNumber      = $lineNum
        LineCode        = $lineCode
        ScriptName      = $scriptName
        StackTrace      = $stackTrace
        FullPlainReport = $fullReport
    }
}

function Get-RomanOSErrorCodeDetails {
    <#
    .SYNOPSIS
        Normaliza el código de salida a formato decimal y hexadecimal unsigned (0x{0:X8}) sin preconcepciones.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [long]$ExitCode
    )

    $intVal = try { [int32]$ExitCode } catch { [int32]($ExitCode -band 0xFFFFFFFFL) }
    $hexStr = "0x{0:X8}" -f $intVal

    return [PSCustomObject]@{
        ExitCodeDecimal = $ExitCode
        ExitCodeHex     = $hexStr
    }
}

function Write-ForensicProcessFailure {
    <#
    .SYNOPSIS
        Registra el fallo crudo y completo de un subproceso nativo en texto plano sin pre-filtros.
    .DESCRIPTION
        Vuelca la orden completa, el ExitCode en decimal y hexadecimal, y el contenido íntegro
        de STDOUT, STDERR y logs físicos asociados, sin clasificaciones previas ni sesgos.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TaskDescription,

        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [long]$ExitCode,

        [Parameter()]
        [string]$CommandLine = "",

        [Parameter()]
        [string]$StdOut = "",

        [Parameter()]
        [string]$StdErr = "",

        [Parameter()]
        [string]$LogFilePath = "",

        [Parameter()]
        [switch]$IsWarningOnly
    )

    $errInfo = Get-RomanOSErrorCodeDetails -ExitCode $ExitCode
    $level = if ($IsWarningOnly) { "WARN" } else { "ERROR" }
    $cmdDisplay = if ($CommandLine) { "$FilePath $CommandLine" } else { $FilePath }

    $headerText = "[$level] Fallo en proceso '$TaskDescription' | ExitCode: $ExitCode ($($errInfo.ExitCodeHex))"

    # Construir bloque de texto plano íntegro (Raw Plain-Text)
    $sbPlain = [System.Text.StringBuilder]::new()
    [void]$sbPlain.AppendLine("══════════════════════════════════════════════════════════════════════════")
    [void]$sbPlain.AppendLine($headerText)
    [void]$sbPlain.AppendLine("  Comando ejecutado : $cmdDisplay")
    [void]$sbPlain.AppendLine("  Código de salida  : $ExitCode ($($errInfo.ExitCodeHex))")

    if ($StdOut -and $StdOut.Trim()) {
        [void]$sbPlain.AppendLine("  --- SALIDA ESTÁNDAR CRUDA (STDOUT) ---")
        foreach ($line in ($StdOut -split "`r?`n")) {
            if ($line.Trim()) { [void]$sbPlain.AppendLine("  | $line") }
        }
    }

    if ($StdErr -and $StdErr.Trim()) {
        [void]$sbPlain.AppendLine("  --- FLUJO DE ERROR CRUDO (STDERR) ---")
        foreach ($line in ($StdErr -split "`r?`n")) {
            if ($line.Trim()) { [void]$sbPlain.AppendLine("  | $line") }
        }
    }

    if ($LogFilePath -and (Test-Path $LogFilePath)) {
        try {
            $logContent = Get-Content -Path $LogFilePath -Tail 50 -ErrorAction SilentlyContinue
            if ($logContent) {
                $logLeaf = [System.IO.Path]::GetFileName($LogFilePath)
                [void]$sbPlain.AppendLine("  --- REGISTRO FÍSICO ASOCIADO ($logLeaf - últimas líneas) ---")
                foreach ($ll in $logContent) {
                    if ($ll.Trim()) { [void]$sbPlain.AppendLine("  | $ll") }
                }
            }
        } catch {
            Write-Verbose "[UI-Engine] No se pudo leer log físico asociado: $($_.Exception.Message)"
        }
    }
    [void]$sbPlain.AppendLine("══════════════════════════════════════════════════════════════════════════")

    $fullReport = $sbPlain.ToString().TrimEnd()

    # Salida visual destacada en consola
    $color = if ($IsWarningOnly) { "Yellow" } else { "Red" }
    Write-Host ""
    Write-Host $fullReport -ForegroundColor $color
    Write-Host ""

    # Volcar el bloque plano íntegro al archivo de log estructurado
    Write-UnifiedLogEntry -Message $fullReport -Level $level | Out-Null

    # Acumular para reportes de cierre
    if ($IsWarningOnly) {
        if ($null -ne $global:RomanOS_LogWarns) { [void]$global:RomanOS_LogWarns.Add($headerText) }
        try {
            if ($null -ne $script:LogWarns -and -not [object]::ReferenceEquals($script:LogWarns, $global:RomanOS_LogWarns)) {
                [void]$script:LogWarns.Add($headerText)
            }
        } catch {
            Write-Verbose "[UI-Engine] No se pudo agregar advertencia a script:LogWarns: $($_.Exception.Message)"
        }
    } else {
        if ($null -ne $global:RomanOS_LogErrors) { [void]$global:RomanOS_LogErrors.Add($headerText) }
        try {
            if ($null -ne $script:LogErrors -and -not [object]::ReferenceEquals($script:LogErrors, $global:RomanOS_LogErrors)) {
                [void]$script:LogErrors.Add($headerText)
            }
        } catch {
            Write-Verbose "[UI-Engine] No se pudo agregar error a script:LogErrors: $($_.Exception.Message)"
        }
        try {
            if ($script:CurrentStepObj) {
                $script:CurrentStepObj.Status = "ERROR"
                $script:CurrentStepObj.Note = $headerText
            }
        } catch {
            Write-Verbose "[UI-Engine] No se pudo actualizar CurrentStepObj: $($_.Exception.Message)"
        }
    }

    return [PSCustomObject]@{
        Header          = $headerText
        ExitCode        = $ExitCode
        ExitCodeHex     = $errInfo.ExitCodeHex
        CommandLine     = $cmdDisplay
        StdOut          = $StdOut
        StdErr          = $StdErr
        FullPlainReport = $fullReport
    }
}

function Assert-ResourceCommitment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceName,
        [Parameter(Mandatory = $true)]
        [bool]$PreflightFound,
        [Parameter(Mandatory = $true)]
        [bool]$ExecutionApplied,
        [Parameter()]
        [string]$ExpectedPath = "",
        [Parameter()]
        [string]$FailureReason = "",
        [Parameter()]
        [switch]$Fatal
    )

    if ($PreflightFound -and -not $ExecutionApplied) {
        $reason = if ($FailureReason) { $FailureReason } else { "El recurso fue detectado en Preflight pero no se aplico durante la fase de ejecucion." }
        $pathInfo = if ($ExpectedPath) { " (Ruta: '$ExpectedPath')" } else { "" }
        $alertMsg = "DESVIO DE COMPROMISO: Recurso '$ResourceName'$pathInfo detectado en Preflight pero OMITIDO en ejecucion."

        if ($Fatal) {
            Write-ErrorMsg -Message $alertMsg -Cause $reason -Action "Verifique que la ruta de origen no este bloqueada y contenga los artefactos requeridos."
            throw $alertMsg
        } else {
            Write-Warn -Message $alertMsg -Cause $reason -Action "Revise la configuracion y los logs para determinar si fue intencional o un error de ruta."
        }
        return $false
    }
    return $true
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
        [Alias("Title", "Question", "Message")]
        [string]$Prompt,
        [Parameter()]
        [Alias("DefaultYes")]
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

    if (-not $PSBoundParameters.ContainsKey("ErrorsCount") -and ($null -ne $global:RomanOS_LogErrors)) {
        $ErrorsCount = $global:RomanOS_LogErrors.Count
    }
    if (-not $PSBoundParameters.ContainsKey("WarnsCount") -and ($null -ne $global:RomanOS_LogWarns)) {
        $WarnsCount = $global:RomanOS_LogWarns.Count
    }

    $w = if ($script:UI_BoxWidth -and $script:UI_BoxWidth -gt 10) { $script:UI_BoxWidth } else { 74 }
    $border = "═" * [math]::Max(1, ($w - 2))
    $innerW = [math]::Max(1, ($w - 4))

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

#------------------------------------------------------------------------------
# FUNCIONES DE PRESET JSON (PLAN-0046 / PLAN-0143)
#------------------------------------------------------------------------------
function Import-BuildPreset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("Path")]
        [string]$PresetPath,

        [Parameter(Mandatory = $false)]
        [System.Collections.IDictionary]$ScriptBoundParameters = @{}
    )

    if (-not (Test-Path $PresetPath -ErrorAction SilentlyContinue)) {
        throw [System.IO.FileNotFoundException] "ERROR FATAL (Fail-Fast / Regla 13): El archivo Preset especificado en -PresetFile no existe: '$PresetPath'. Abortando compilación para prevenir ejecución con parámetros degradados o no deseados."
    }

    try {
        $json   = Get-Content -Path $PresetPath -Raw -Encoding UTF8
        $preset = $json | ConvertFrom-Json
        if ($null -eq $preset) {
            throw "El archivo Preset '$PresetPath' está vacío o no contiene una estructura JSON válida."
        }
    } catch {
        throw "ERROR FATAL (Fail-Fast / Regla 13): No se pudo leer o deserializar el archivo Preset '$PresetPath': $($_.Exception.Message)"
    }

    try {
        # Aplicar solo los valores del preset que NO hayan sido especificados en CLI
        # Los ScriptBoundParameters tienen prioridad sobre el preset (CLI > Preset)
        $mappings = @{
            SourceISO           = 'SourceISO'
            OutputDir           = 'OutputDir'
            DriversPath         = 'DriversPath'
            EnableHyperV        = 'EnableHyperV'
            InjectWin11Script   = 'InjectWin11Script'
            Language            = 'Language'
            Locale              = 'Locale'
            Timezone            = 'Timezone'
            KeyboardOverride    = 'KeyboardOverride'
            LocalUser           = 'LocalUser'
            LocalPassword       = 'LocalPassword'
            OptimizationProfile = 'OptProfile'
            BlockOneDrive       = 'BlockOneDrive'
            InjectVisualTweaks  = 'InjectVisualTweaks'
            WimCompression      = 'WimCompression'
            Architecture        = 'Architecture'
            TargetWimIndex      = 'TargetWimIndex'
        }

        foreach ($key in $mappings.Keys) {
            $scriptVar = $mappings[$key]
            # CLI tiene prioridad: si el parametro fue pasado explicitamente, no sobreescribir
            if ($ScriptBoundParameters.ContainsKey($key)) { continue }
            $val = $preset.$key
            if ($null -ne $val) {
                Set-Variable -Name $scriptVar -Value $val -Scope Script -Force -ErrorAction SilentlyContinue
                Set-Variable -Name $key -Value $val -Scope Script -Force -ErrorAction SilentlyContinue
                Set-Variable -Name $key -Value $val -Scope 1 -Force -ErrorAction SilentlyContinue
                $ScriptBoundParameters[$key] = $val
            }
        }

        # Integraciones y omisiones de componentes
        if ($null -ne $preset.IntegrateUpdates -and -not [bool]$preset.IntegrateUpdates) {
            $script:SkipUpdates = $true
            $ScriptBoundParameters['SkipUpdates'] = $true
        }
        if ($null -ne $preset.IntegrateDrivers -and -not [bool]$preset.IntegrateDrivers) {
            $script:SkipDrivers = $true
            $ScriptBoundParameters['SkipDrivers'] = $true
        }
        if ($null -ne $preset.IntegrateRuntimes -and -not [bool]$preset.IntegrateRuntimes) {
            $script:SkipRuntimes = $true
            $ScriptBoundParameters['SkipRuntimes'] = $true
        }
        if ($null -ne $preset.SkipUpdates -and [bool]$preset.SkipUpdates) {
            $script:SkipUpdates = $true
            $ScriptBoundParameters['SkipUpdates'] = $true
        }
        if ($null -ne $preset.SkipDrivers -and [bool]$preset.SkipDrivers) {
            $script:SkipDrivers = $true
            $ScriptBoundParameters['SkipDrivers'] = $true
        }
        if ($null -ne $preset.SkipRuntimes -and [bool]$preset.SkipRuntimes) {
            $script:SkipRuntimes = $true
            $ScriptBoundParameters['SkipRuntimes'] = $true
        }
        if ($null -ne $preset.SkipBootWimDrivers -and [bool]$preset.SkipBootWimDrivers) {
            $script:SkipBootWimDrivers = $true
            $ScriptBoundParameters['SkipBootWimDrivers'] = $true
        }
        if ($null -ne $preset.ZeroTouch) {
            $script:ZeroTouch = [bool]$preset.ZeroTouch
            $ScriptBoundParameters['ZeroTouch'] = [bool]$preset.ZeroTouch
        }
        if ($null -ne $preset.ZeroTouchDisk) {
            $script:ZeroTouchDisk = [int]$preset.ZeroTouchDisk
            $ScriptBoundParameters['ZeroTouchDisk'] = [int]$preset.ZeroTouchDisk
        }
        if ($null -ne $preset.TargetWimIndex) {
            $script:TargetWimIndex = [string]$preset.TargetWimIndex
            $ScriptBoundParameters['TargetWimIndex'] = [string]$preset.TargetWimIndex
        }

        if (Get-Command "Write-OK" -ErrorAction SilentlyContinue) {
            Write-OK "Preset importado exitosamente desde: $PresetPath (ZeroTouch=$($ScriptBoundParameters['ZeroTouch']), Disk=$($ScriptBoundParameters['ZeroTouchDisk']), TargetIndex=$($ScriptBoundParameters['TargetWimIndex']))"
        } else {
            Write-Host "  [OK] Preset importado exitosamente desde: $PresetPath" -ForegroundColor Green
        }
    } catch {
        throw "ERROR FATAL (Fail-Fast / Regla 13): Error aplicando parámetros desde el preset '$PresetPath': $($_.Exception.Message)"
    }
}

function Export-BuildPreset {
    param(
        [string]$OutputDirectory = (Get-Location).Path
    )

    $optVal = if ($script:OptProfile) { $script:OptProfile }
              elseif ($script:OptimizationProfile) { $script:OptimizationProfile }
              elseif ($OptimizationProfile) { $OptimizationProfile }
              else { "1" }

    $langVal = if ($script:Language) { $script:Language }
               elseif ($Language) { $Language }
               else { "es-ES" }

    $locVal = if ($script:Locale) { $script:Locale }
              elseif ($Locale) { $Locale }
              else { "" }

    $tzVal = if ($script:Timezone) { $script:Timezone }
             elseif ($Timezone) { $Timezone }
             else { "Romance Standard Time" }

    $userVal = if ($script:LocalUser) { $script:LocalUser }
               elseif ($LocalUser) { $LocalUser }
               else { "Usuario" }

    $passVal = if ($script:LocalPassword) { $script:LocalPassword }
               elseif ($LocalPassword) { $LocalPassword }
               else { "" }

    $wimCompVal = if ($script:WimCompression) { $script:WimCompression }
                  elseif ($WimCompression) { $WimCompression }
                  else { "Max" }

    $blockOneDriveVal = if ($null -ne $script:BlockOneDrive) { [bool]$script:BlockOneDrive }
                        elseif ($null -ne $BlockOneDrive) { [bool]$BlockOneDrive }
                        elseif ($null -ne $script:NoBlockOneDrive) { -not [bool]$script:NoBlockOneDrive }
                        elseif ($null -ne $NoBlockOneDrive) { -not [bool]$NoBlockOneDrive }
                        else { $true }

    $presetObj = [ordered]@{
        SourceISO           = if ($script:SourceISO) { $script:SourceISO } else { $SourceISO }
        DownloadOfficialISO = if ($script:DownloadOfficialISO) { $script:DownloadOfficialISO } else { [bool]$DownloadOfficialISO }
        DownloadVersion     = if ($script:DownloadVersion) { $script:DownloadVersion } else { $DownloadVersion }
        DownloadEdition     = if ($script:DownloadEdition) { $script:DownloadEdition } else { $DownloadEdition }
        DownloadLanguage    = if ($script:DownloadLanguage) { $script:DownloadLanguage } else { $DownloadLanguage }
        TargetWimIndex      = if ($script:TargetWimIndex) { $script:TargetWimIndex } else { $TargetWimIndex }
        OptimizationProfile = "$optVal"
        LocalUser           = "$userVal"
        LocalPassword       = "$passVal"
        ZeroTouch           = if ($script:ZeroTouch) { [bool]$script:ZeroTouch } else { [bool]$ZeroTouch }
        ZeroTouchDisk       = if ($null -ne $script:ZeroTouchDisk) { [int]$script:ZeroTouchDisk } elseif ($null -ne $ZeroTouchDisk) { [int]$ZeroTouchDisk } else { 0 }
        InjectWin11Script   = if ($null -ne $script:InjectWin11Script) { [bool]$script:InjectWin11Script } else { [bool]$InjectWin11Script }
        WimCompression      = "$wimCompVal"
        Language            = "$langVal"
        Locale              = "$locVal"
        Timezone            = "$tzVal"
        KeyboardOverride    = if ($script:KeyboardOverride) { $script:KeyboardOverride } else { $KeyboardOverride }
        BlockOneDrive       = $blockOneDriveVal
        InjectVisualTweaks  = if ($null -ne $script:InjectVisualTweaks) { [bool]$script:InjectVisualTweaks } else { [bool]$InjectVisualTweaks }
        EnableHyperV        = if ($null -ne $script:EnableHyperV) { [bool]$script:EnableHyperV } elseif ($null -ne $EnableHyperV) { [bool]$EnableHyperV } else { $false }
    }

    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    $presetOut = Join-Path $OutputDirectory "Preset_romanOS_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $jsonText = $presetObj | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($presetOut, $jsonText, [System.Text.Encoding]::UTF8)
    Write-Host "  [OK] Preset JSON guardado en: $presetOut" -ForegroundColor Green
    return $presetOut
}

# -----------------------------------------------------------------------------
# 12. MOTOR DE TEMAS VISUALES PARA GUIS romanOS (PLAN-0146 SSOT)
# -----------------------------------------------------------------------------

function Get-RomanOSGuiThemes {
    <#
    .SYNOPSIS
        Retorna el catálogo canónico de temas visuales para las interfaces romanOS.
    #>
    [CmdletBinding()]
    param()

    return [ordered]@{
        "CyberStealth" = [ordered]@{
            Id              = "CyberStealth"
            DisplayName     = "Cyber-Stealth (Opción 1)"
            Description     = "Estética de hiper-precisión en negro obsidiana y cian eléctrico (Predeterminado)"
            WindowBg        = "#0D1117"
            HeaderBg        = "#161B22"
            HeaderBorder    = "#21262D"
            CardBg          = "#161B22"
            CardBorder      = "#30363D"
            ButtonBg        = "#21262D"
            ButtonBorder    = "#363D47"
            ButtonFg        = "#F0F6FC"
            ButtonHoverBg   = "#30363D"
            TextPrimary     = "#F0F6FC"
            TextSecondary   = "#8B949E"
            TabBg           = "#161B22"
            TabBorder       = "#21262D"
            TabSelectedBg   = "#21262D"
            TabSelectedFg   = "#00E5FF"
            ConsoleBg       = "#0A0D12"
            ConsoleBorder   = "#21262D"
            AccentPrimary   = "#00E5FF"
            AccentSecondary = "#00E676"
            AccentWarning   = "#F59E0B"
            AccentDev       = "#A855F7"
            AccentDanger    = "#FF4444"
            AccentAuditBg   = "#102A38"
            AccentSuccessBg = "#102B1E"
            AccentWarningBg = "#33220A"
        }
        "ImperialCrimson" = [ordered]@{
            Id              = "ImperialCrimson"
            DisplayName     = "Imperial Crimson (Opción 2)"
            Description     = "Titanio oscuro con acento rojo carmesí imperial y verde menta"
            WindowBg        = "#121214"
            HeaderBg        = "#1A1A1E"
            HeaderBorder    = "#2A2A30"
            CardBg          = "#1A1A1E"
            CardBorder      = "#2C2C34"
            ButtonBg        = "#27272A"
            ButtonBorder    = "#3F3F46"
            ButtonFg        = "#F4F4F5"
            ButtonHoverBg   = "#3F3F46"
            TextPrimary     = "#F4F4F5"
            TextSecondary   = "#A1A1AA"
            TabBg           = "#1A1A1E"
            TabBorder       = "#2A2A30"
            TabSelectedBg   = "#27272A"
            TabSelectedFg   = "#FF334B"
            ConsoleBg       = "#0C0C0E"
            ConsoleBorder   = "#2A2A30"
            AccentPrimary   = "#FF334B"
            AccentSecondary = "#10B981"
            AccentWarning   = "#F59E0B"
            AccentDev       = "#8B5CF6"
            AccentDanger    = "#EF4444"
            AccentAuditBg   = "#381018"
            AccentSuccessBg = "#102B1E"
            AccentWarningBg = "#33220A"
        }
        "OLEDMidnight" = [ordered]@{
            Id              = "OLEDMidnight"
            DisplayName     = "OLED Midnight (Opción 3)"
            Description     = "Contraste ultra-profundo OLED con cian láser y verde neón puro"
            WindowBg        = "#07080B"
            HeaderBg        = "#0F1117"
            HeaderBorder    = "#1B1E29"
            CardBg          = "#0F1117"
            CardBorder      = "#1F2433"
            ButtonBg        = "#151821"
            ButtonBorder    = "#252B3B"
            ButtonFg        = "#FFFFFF"
            ButtonHoverBg   = "#202533"
            TextPrimary     = "#FFFFFF"
            TextSecondary   = "#788296"
            TabBg           = "#0F1117"
            TabBorder       = "#1B1E29"
            TabSelectedBg   = "#181C26"
            TabSelectedFg   = "#00F0FF"
            ConsoleBg       = "#040406"
            ConsoleBorder   = "#1B1E29"
            AccentPrimary   = "#00F0FF"
            AccentSecondary = "#00FF9D"
            AccentWarning   = "#FFB800"
            AccentDev       = "#C084FC"
            AccentDanger    = "#FF3366"
            AccentAuditBg   = "#0A2230"
            AccentSuccessBg = "#0A2818"
            AccentWarningBg = "#33220A"
        }
        "ClassicCharcoal" = [ordered]@{
            Id              = "ClassicCharcoal"
            DisplayName     = "Classic Charcoal (Original)"
            Description     = "Paleta clásica de escala de grises oscuros (#202020)"
            WindowBg        = "#202020"
            HeaderBg        = "#282828"
            HeaderBorder    = "#1C1C1C"
            CardBg          = "#282828"
            CardBorder      = "#3D3D3D"
            ButtonBg        = "#2D2D2D"
            ButtonBorder    = "#454545"
            ButtonFg        = "#E3E3E3"
            ButtonHoverBg   = "#383838"
            TextPrimary     = "#FFFFFF"
            TextSecondary   = "#A0A0A0"
            TabBg           = "#252525"
            TabBorder       = "#333333"
            TabSelectedBg   = "#383838"
            TabSelectedFg   = "#00E5FF"
            ConsoleBg       = "#1A1A1A"
            ConsoleBorder   = "#333333"
            AccentPrimary   = "#00E5FF"
            AccentSecondary = "#00E676"
            AccentWarning   = "#FFB300"
            AccentDev       = "#E040FB"
            AccentDanger    = "#FF5252"
            AccentAuditBg   = "#1B3B4D"
            AccentSuccessBg = "#1E3A2F"
            AccentWarningBg = "#3A2E1E"
        }
    }
}

function Get-RomanOSActiveThemeName {
    <#
    .SYNOPSIS
        Obtiene el nombre del tema activo desde el registro o retorna el predeterminado (CyberStealth).
    #>
    [CmdletBinding()]
    param()

    try {
        $regVal = Get-ItemProperty -Path "HKCU:\Software\romanOS" -Name "Theme" -ErrorAction SilentlyContinue
        if ($regVal -and $regVal.Theme) {
            return $regVal.Theme
        }
    } catch {
        Write-Verbose "[UI-Engine] No se pudo leer tema de HKCU: $($_.Exception.Message)"
    }

    return "CyberStealth"
}

function Set-RomanOSActiveThemeName {
    <#
    .SYNOPSIS
        Persiste el nombre del tema activo en el registro del usuario.
    #>
    [CmdletBinding()]
    param([string]$ThemeName)

    try {
        if (-not (Test-Path "HKCU:\Software\romanOS")) {
            New-Item -Path "HKCU:\Software\romanOS" -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Set-ItemProperty -Path "HKCU:\Software\romanOS" -Name "Theme" -Value $ThemeName -Force -ErrorAction SilentlyContinue | Out-Null
    } catch {
        Write-Verbose "[UI-Engine] No se pudo persistir tema en HKCU: $($_.Exception.Message)"
    }
}

function Apply-RomanOSGuiTheme {
    <#
    .SYNOPSIS
        Aplica un tema visual dinámico a una ventana WPF mediante DynamicResource.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Window,
        [Parameter()]
        [string]$ThemeName = "CyberStealth"
    )

    $themes = Get-RomanOSGuiThemes
    if (-not $themes.Contains($ThemeName)) {
        $ThemeName = "CyberStealth"
    }

    $theme = $themes[$ThemeName]
    $bc = New-Object System.Windows.Media.BrushConverter

    $resourceMap = @{
        "WindowBgBrush"         = $theme.WindowBg
        "HeaderBgBrush"         = $theme.HeaderBg
        "HeaderBorderBrush"     = $theme.HeaderBorder
        "CardBgBrush"           = $theme.CardBg
        "CardBorderBrush"       = $theme.CardBorder
        "ButtonBgBrush"         = $theme.ButtonBg
        "ButtonBorderBrush"     = $theme.ButtonBorder
        "ButtonFgBrush"         = $theme.ButtonFg
        "ButtonHoverBgBrush"    = $theme.ButtonHoverBg
        "TextPrimaryBrush"      = $theme.TextPrimary
        "TextSecondaryBrush"    = $theme.TextSecondary
        "TabBgBrush"            = $theme.TabBg
        "TabBorderBrush"        = $theme.TabBorder
        "TabSelectedBgBrush"    = $theme.TabSelectedBg
        "TabSelectedFgBrush"    = $theme.TabSelectedFg
        "ConsoleBgBrush"        = $theme.ConsoleBg
        "ConsoleBorderBrush"    = $theme.ConsoleBorder
        "AccentPrimaryBrush"    = $theme.AccentPrimary
        "AccentSecondaryBrush"  = $theme.AccentSecondary
        "AccentWarningBrush"    = $theme.AccentWarning
        "AccentDevBrush"        = $theme.AccentDev
        "AccentDangerBrush"     = $theme.AccentDanger
        "AccentAuditBgBrush"    = $theme.AccentAuditBg
        "AccentSuccessBgBrush"  = $theme.AccentSuccessBg
        "AccentWarningBgBrush"  = $theme.AccentWarningBg
    }

    foreach ($key in $resourceMap.Keys) {
        try {
            $brush = $bc.ConvertFromString($resourceMap[$key])
            if ($brush.CanFreeze) { $brush.Freeze() }
            $Window.Resources[$key] = $brush
        } catch {
            Write-Warning "[UI-Engine] No se pudo asignar recurso '$key': $($_.Exception.Message)"
        }
    }

    try {
        $wBrush = $bc.ConvertFromString($theme.WindowBg)
        if ($wBrush.CanFreeze) { $wBrush.Freeze() }
        $Window.Background = $wBrush
    } catch {
        Write-Verbose "[UI-Engine] No se pudo aplicar Window.Background: $($_.Exception.Message)"
    }

    try {
        $popupBg = $bc.ConvertFromString($theme.CardBg)
        if ($popupBg.CanFreeze) { $popupBg.Freeze() }
        $Window.Resources[[System.Windows.SystemColors]::WindowBrushKey] = $popupBg

        $popupFg = $bc.ConvertFromString($theme.TextPrimary)
        if ($popupFg.CanFreeze) { $popupFg.Freeze() }
        $Window.Resources[[System.Windows.SystemColors]::WindowTextBrushKey] = $popupFg
    } catch {
        Write-Verbose "[UI-Engine] No se pudo aplicar WindowBrushKey/WindowTextBrushKey: $($_.Exception.Message)"
    }

    Set-RomanOSActiveThemeName -ThemeName $ThemeName
    return $theme
}