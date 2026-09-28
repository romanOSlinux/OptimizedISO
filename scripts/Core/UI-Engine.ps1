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

    # Telemetria de sistema opcional o por defecto
    if ($ShowSystemInfo) {
        try {
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            $adminBadge = if ($isAdmin) { " (Admin)" } else { " (Standard)" }
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
            $sysLetter = if ($env:SystemDrive) { $env:SystemDrive } else { "C:" }
            $sysDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sysLetter'" -ErrorAction SilentlyContinue
            $freeGB = if ($sysDrive) { [math]::Round($sysDrive.FreeSpace / 1GB, 1) } else { "N/A" }

            Write-Host "  Host: $env:COMPUTERNAME | Usuario: $env:USERNAME$adminBadge" -ForegroundColor Gray
            if ($os) {
                Write-Host "  SO  : $($os.Caption) ($($os.OSArchitecture)) | $sysLetter $freeGB GB libres" -ForegroundColor Gray
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
            [System.IO.File]::AppendAllLines($TargetLogFile, @($logLine), [System.Text.Encoding]::UTF8)
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
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Record,
        [Parameter()]
        [string]$Context = "",
        [Parameter()]
        [string]$SuggestedAction = ""
    )

    $msg = ""
    $scriptName = "Desconocido"
    $lineNum = 0
    $lineCode = ""
    $stackTrace = ""

    if ($Record -is [System.Management.Automation.ErrorRecord]) {
        $msg = $Record.Exception.Message
        if ($Record.InvocationInfo) {
            $scriptName = if ($Record.InvocationInfo.ScriptName) { Split-Path -Leaf $Record.InvocationInfo.ScriptName } else { $Record.InvocationInfo.MyCommand.Name }
            $lineNum = $Record.InvocationInfo.ScriptLineNumber
            $lineCode = if ($Record.InvocationInfo.Line) { $Record.InvocationInfo.Line.Trim() } else { "" }
        }
        $stackTrace = $Record.ScriptStackTrace
    } elseif ($Record -is [System.Exception]) {
        $msg = $Record.Message
        $stackTrace = $Record.StackTrace
    } else {
        $msg = "$Record"
    }

    $ctxPrefix = if ($Context) { "[$Context] " } else { "" }
    $locStr = if ($lineNum -gt 0) { " en ${scriptName}:${lineNum}" } else { " en $scriptName" }
    
    $forensicHeader = "$($ctxPrefix)Excepcion$($locStr): $msg"
    Write-Host "  [ERROR FORENSE] $forensicHeader" -ForegroundColor Red

    if ($lineCode) {
        Write-Host "    -> Linea de codigo : $lineCode" -ForegroundColor DarkYellow
    }
    if ($SuggestedAction) {
        Write-Host "    -> Accion sugerida : $SuggestedAction" -ForegroundColor Cyan
    }
    if ($stackTrace) {
        $cleanStack = ($stackTrace -split "`r?`n" | Select-Object -First 3) -join " <- "
        Write-Host "    -> Pila de llamadas: $cleanStack" -ForegroundColor DarkGray
    }

    $logPayload = "$forensicHeader | Linea: [$lineCode] | Stack: [$stackTrace]"
    if ($SuggestedAction) { $logPayload += " | Accion: [$SuggestedAction]" }

    Write-UnifiedLogEntry -Message $logPayload -Level "ERROR" | Out-Null
    if ($null -ne $global:RomanOS_LogErrors) {
        [void]$global:RomanOS_LogErrors.Add($forensicHeader)
    }
    try {
        if ($null -ne $script:LogErrors -and -not [object]::ReferenceEquals($script:LogErrors, $global:RomanOS_LogErrors)) {
            [void]$script:LogErrors.Add($forensicHeader)
        }
    } catch {
        Write-Verbose "[UI-Engine] No se pudo registrar error forense en script:LogErrors: $($_.Exception.Message)"
    }
    try {
        if ($script:CurrentStepObj) {
            $script:CurrentStepObj.Status = "ERROR"
            $script:CurrentStepObj.Note = $forensicHeader
        }
    } catch {
        Write-Verbose "[UI-Engine] No se pudo actualizar CurrentStepObj con error forense: $($_.Exception.Message)"
    }

    return [PSCustomObject]@{
        Header          = $forensicHeader
        LineNumber      = $lineNum
        LineCode        = $lineCode
        ScriptName      = $scriptName
        SuggestedAction = $SuggestedAction
    }
}

function Get-RomanOSErrorCodeDetails {
    <#
    .SYNOPSIS
        Traduce códigos de error numéricos (Win32 y HRESULT CBS/DISM) a diagnósticos semánticos.
    .DESCRIPTION
        Soporta enteros de 32 bits con signo o sin signo y códigos de salida nativos de procesos Windows.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [long]$ExitCode
    )

    # Normalizar a representación hexadecimal de 32 bits sin signo
    $intVal = try { [int32]$ExitCode } catch { [int32]($ExitCode -band 0xFFFFFFFFL) }
    $hexStr  = "0x{0:X8}" -f $intVal

    $knownErrors = @{
        # --- CBS / DISM / Servicing HRESULTS ---
        "0x800F0806" = @{ Name = "CBS_E_PENDING"; Meaning = "Operaciones de actualización pendientes. DISM /ResetBase requiere que el sistema arranque primero (first boot) tras inyectar actualizaciones acumulativas." }
        "0x800F081F" = @{ Name = "CBS_E_SOURCE_NOT_FOUND"; Meaning = "No se encontraron los archivos de origen de la característica o paquete (falta payload en el WIM o fuentes SxS)." }
        "0x800F080C" = @{ Name = "CBS_E_UNKNOWN_UPDATE"; Meaning = "El paquete, capability o funcionalidad especificada no existe en el catálogo de componentes de esta imagen." }
        "0x800F0906" = @{ Name = "CBS_E_DOWNLOAD_FAILURE"; Meaning = "No se pudieron descargar los archivos de origen para habilitar la característica." }
        "0x800F0954" = @{ Name = "CBS_E_INVALID_WINDOWS_UPDATE_TIMESTAMP"; Meaning = "DISM no puede reparar componentes usando WSUS/WU corporativo sin acceso a Microsoft Update directo." }
        "0x800F0905" = @{ Name = "CBS_E_NO_ACTIVE_EDITION"; Meaning = "No hay una edición de Windows activa o compatible con la operación solicitada." }

        # --- Win32 Standard Error Codes ---
        "0x00000057" = @{ Name = "ERROR_INVALID_PARAMETER"; Meaning = "Parámetro o nombre de capacidad/funcionalidad no válido en esta versión de Windows (ej. componente retirado en 24H2/25H2 como WordPad o sintaxis modificada)." } # 87
        "0x00000228" = @{ Name = "ERROR_PACKAGE_ALREADY_EXISTS"; Meaning = "El paquete de actualización ya está integrado en la imagen o un baseline superior ya está aplicado (Checkpoint redundante)." } # 552
        "0x00000002" = @{ Name = "ERROR_FILE_NOT_FOUND"; Meaning = "El sistema no puede encontrar el archivo especificado." } # 2
        "0x00000003" = @{ Name = "ERROR_PATH_NOT_FOUND"; Meaning = "El sistema no puede encontrar la ruta especificada." } # 3
        "0x00000005" = @{ Name = "ERROR_ACCESS_DENIED"; Meaning = "Acceso denegado o privilegios insuficientes en el recurso/colmena." } # 5
        "0x00000020" = @{ Name = "ERROR_SHARING_VIOLATION"; Meaning = "El proceso no tiene acceso al archivo porque está siendo utilizado por otro proceso." } # 32
        "0x00000070" = @{ Name = "ERROR_DISK_FULL"; Meaning = "Espacio en disco insuficiente para completar la operación." } # 112
        "0x00000BC2" = @{ Name = "ERROR_SUCCESS_REBOOT_REQUIRED"; Meaning = "Operación completada exitosamente pero requiere reinicio del sistema para surtir efecto." } # 3010
        "0x80070002" = @{ Name = "HRESULT_FILE_NOT_FOUND"; Meaning = "El archivo especificado no existe o no pudo ser localizado por el subsistema Win32." }
        "0x80070005" = @{ Name = "E_ACCESSDENIED"; Meaning = "Acceso denegado en la llamada COM / Win32." }
        "0x80004005" = @{ Name = "E_FAIL"; Meaning = "Fallo no especificado en el componente COM / Win32." }
    }

    if ($knownErrors.ContainsKey($hexStr)) {
        $entry = $knownErrors[$hexStr]
        return [PSCustomObject]@{
            ExitCodeDecimal = $ExitCode
            ExitCodeHex     = $hexStr
            SymbolicName    = $entry.Name
            Meaning         = $entry.Meaning
            IsKnown         = $true
        }
    }

    # Intentar lookup nativo vía Win32Exception si está en rango Win32 clásico (0 - 65535)
    $sysMsg = ""
    if ($ExitCode -gt 0 -and $ExitCode -lt 65536) {
        try {
            $ex = New-Object System.ComponentModel.Win32Exception([int]$ExitCode)
            $sysMsg = $ex.Message
        } catch {
            Write-Verbose "[UI-Engine] No se pudo obtener mensaje de Win32Exception: $($_.Exception.Message)"
        }
    }

    return [PSCustomObject]@{
        ExitCodeDecimal = $ExitCode
        ExitCodeHex     = $hexStr
        SymbolicName    = if ($sysMsg) { "WIN32_ERROR_$ExitCode" } else { "ERROR_$hexStr" }
        Meaning         = if ($sysMsg) { $sysMsg } else { "Código de salida no estándar de Windows ($hexStr)." }
        IsKnown         = [bool]$sysMsg
    }
}

function Write-ForensicProcessFailure {
    <#
    .SYNOPSIS
        Emite un diagnóstico estructurado, visible y detallado cuando un subproceso nativo falla.
    .DESCRIPTION
        Extrae las líneas de error de StdOut y StdErr, decodifica el ExitCode y registra la telemetría.
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
        [string]$StdOut = "",

        [Parameter()]
        [string]$StdErr = "",

        [Parameter()]
        [string]$LogFilePath = "",

        [Parameter()]
        [string]$Context = "",

        [Parameter()]
        [string]$SuggestedAction = "",

        [Parameter()]
        [switch]$IsWarningOnly
    )

    $errDetails = Get-RomanOSErrorCodeDetails -ExitCode $ExitCode
    $level = if ($IsWarningOnly) { "WARN" } else { "ERROR" }
    $cmdName = Split-Path -Leaf $FilePath

    # Extraer líneas de error relevantes de StdOut y StdErr
    $extractedLines = New-Object System.Collections.ArrayList

    if ($StdErr) {
        $lines = $StdErr -split "`r?`n" | Where-Object { $_.Trim() }
        foreach ($l in $lines) { [void]$extractedLines.Add($l.Trim()) }
    }

    if ($StdOut) {
        $lines = $StdOut -split "`r?`n" | Where-Object { $_.Trim() }
        $matched = $lines | Where-Object { $_ -match '(?i)(error\s*:|fallo|exception|advertencia|denied|no se puede|0x[0-9a-f]{8}|el par[aá]metro)' }
        if ($matched) {
            foreach ($m in ($matched | Select-Object -Last 5)) { [void]$extractedLines.Add($m.Trim()) }
        } else {
            foreach ($m in ($lines | Select-Object -Last 3)) { [void]$extractedLines.Add($m.Trim()) }
        }
    }

    # Si hay un log de DISM físico disponible, leer las últimas líneas con errores
    if ($LogFilePath -and (Test-Path $LogFilePath)) {
        try {
            $logLines = Get-Content -Path $LogFilePath -Tail 50 -ErrorAction SilentlyContinue |
                        Where-Object { $_ -match '(?i)(error|warning|0x[0-9a-f]{8})' } |
                        Select-Object -Last 5
            if ($logLines) {
                [void]$extractedLines.Add("--- Evidencia de log ($([System.IO.Path]::GetFileName($LogFilePath))) ---")
                foreach ($ll in $logLines) { [void]$extractedLines.Add($ll.Trim()) }
            }
        } catch {
            Write-Verbose "[UI-Engine] No se pudo leer archivo de log: $($_.Exception.Message)"
        }
    }

    $headerText = "[$level] Proceso '$TaskDescription' ($cmdName) finalizó con fallo (ExitCode: $ExitCode | $($errDetails.ExitCodeHex))"
    
    # Formateo visual destacado en consola
    $boxColor = if ($IsWarningOnly) { "Yellow" } else { "Red" }
    Write-Host ""
    Write-Host "  ══════════════════════════════════════════════════════════════════════════" -ForegroundColor $boxColor
    Write-Host "  $headerText" -ForegroundColor $boxColor
    Write-Host "    -> Código / Simbólico : $($errDetails.ExitCodeDecimal) ($($errDetails.ExitCodeHex)) — $($errDetails.SymbolicName)" -ForegroundColor DarkYellow
    Write-Host "    -> Causa Técnica      : $($errDetails.Meaning)" -ForegroundColor Cyan
    
    if ($extractedLines.Count -gt 0) {
        Write-Host "    -> Mensaje del Proceso:" -ForegroundColor Gray
        foreach ($el in ($extractedLines | Select-Object -First 6)) {
            Write-Host "       | $el" -ForegroundColor DarkGray
        }
    }
    
    if ($SuggestedAction) {
        Write-Host "    -> Acción Sugerida    : $SuggestedAction" -ForegroundColor Green
    }
    Write-Host "  ══════════════════════════════════════════════════════════════════════════" -ForegroundColor $boxColor
    Write-Host ""

    # Preparar payload para log estructurado
    $diagText = ($extractedLines -join " // ")
    $logPayload = "$headerText | Simbólico: $($errDetails.SymbolicName) | Causa: $($errDetails.Meaning)"
    if ($diagText) { $logPayload += " | Salida: [$diagText]" }
    if ($SuggestedAction) { $logPayload += " | Accion: [$SuggestedAction]" }

    Write-UnifiedLogEntry -Message $logPayload -Level $level | Out-Null

    if ($IsWarningOnly) {
        if ($null -ne $global:RomanOS_LogWarns) { [void]$global:RomanOS_LogWarns.Add($headerText) }
        try {
            if ($null -ne $script:LogWarns -and -not [object]::ReferenceEquals($script:LogWarns, $global:RomanOS_LogWarns)) {
                [void]$script:LogWarns.Add($headerText)
            }
        } catch {
            Write-Verbose "[UI-Engine] No se pudo agregar advertencia forense a script:LogWarns: $($_.Exception.Message)"
        }
    } else {
        if ($null -ne $global:RomanOS_LogErrors) { [void]$global:RomanOS_LogErrors.Add($headerText) }
        try {
            if ($null -ne $script:LogErrors -and -not [object]::ReferenceEquals($script:LogErrors, $global:RomanOS_LogErrors)) {
                [void]$script:LogErrors.Add($headerText)
            }
        } catch {
            Write-Verbose "[UI-Engine] No se pudo agregar error forense a script:LogErrors: $($_.Exception.Message)"
        }
        try {
            if ($script:CurrentStepObj) {
                $script:CurrentStepObj.Status = "ERROR"
                $script:CurrentStepObj.Note = $headerText
            }
        } catch {
            Write-Verbose "[UI-Engine] No se pudo actualizar CurrentStepObj con error forense: $($_.Exception.Message)"
        }
    }

    return [PSCustomObject]@{
        Header          = $headerText
        ExitCode        = $ExitCode
        ExitCodeHex     = $errDetails.ExitCodeHex
        SymbolicName    = $errDetails.SymbolicName
        Meaning         = $errDetails.Meaning
        DiagnosticLines = @($extractedLines)
        DiagnosticText  = $diagText
        SuggestedAction = $SuggestedAction
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
# FUNCIONES DE PRESET JSON (PLAN-0046)
#------------------------------------------------------------------------------
function Import-BuildPreset {
    param(
        [Parameter(Position = 0)]
        [Alias("Path")]
        [string]$PresetPath,

        [hashtable]$ScriptBoundParameters = @{}
    )

    if (-not $PresetPath -or -not (Test-Path $PresetPath)) {
        Write-Host "  [!] Ruta de Preset no valida o no encontrada: $PresetPath" -ForegroundColor Yellow
        return
    }

    try {
        $rawContent = [System.IO.File]::ReadAllText($PresetPath, [System.Text.Encoding]::UTF8)
        $presetData = $rawContent | ConvertFrom-Json

        foreach ($prop in $presetData.psobject.properties) {
            $key = $prop.Name
            $val = $prop.Value

            # Precedencia CLI
            if ($ScriptBoundParameters.ContainsKey($key)) {
                continue
            }
            if ($key -eq "OptimizationProfile" -and $ScriptBoundParameters.ContainsKey("OptimizationProfile")) {
                continue
            }

            Set-Variable -Name $key -Value $val -Scope Script -Force -ErrorAction SilentlyContinue
            Set-Variable -Name $key -Value $val -Scope 1 -Force -ErrorAction SilentlyContinue

            if ($key -eq "OptimizationProfile") {
                Set-Variable -Name "OptProfile" -Value "$val" -Scope Script -Force -ErrorAction SilentlyContinue
                Set-Variable -Name "OptProfile" -Value "$val" -Scope 1 -Force -ErrorAction SilentlyContinue
            }
            if ($key -eq "BlockOneDrive") {
                Set-Variable -Name "NoBlockOneDrive" -Value (-not [bool]$val) -Scope Script -Force -ErrorAction SilentlyContinue
                Set-Variable -Name "NoBlockOneDrive" -Value (-not [bool]$val) -Scope 1 -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "  [i] Preset JSON cargado exitosamente desde: $PresetPath" -ForegroundColor Cyan
    } catch {
        Write-Host "  [!] Error cargando Preset JSON: $($_.Exception.Message)" -ForegroundColor Red
        throw
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