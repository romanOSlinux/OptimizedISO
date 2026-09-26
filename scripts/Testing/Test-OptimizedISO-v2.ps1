<#
.SYNOPSIS
    Test Harness integral y automatizado para New-OptimizedWindowsISO-v2.ps1

.DESCRIPTION
    Carga las 26 funciones del script mediante extraccion de AST en memoria sin ejecutar el flujo principal.
    Ejecuta una suite de pruebas unitarias e integracion simulada con stubs y mocks seguros (Pester pattern).
    NO compila ISOs, NO altera configuraciones del sistema, NO requiere conexion de red activa.

    Fundamentos y fuentes oficiales:
    - Microsoft Learn: AST & FunctionDefinitionAst
      https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.language.functiondefinitionast
    - Pester Documentation: Mocking Native Applications & Cmdlets
      https://pester.dev/docs/usage/mocking#mocking-a-native-application
    - Microsoft Learn: Script Scope & Dot-Sourcing
      https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_scripts

.PARAMETER LogDir
    Ruta del directorio donde se guardara el reporte Markdown de resultados. (Default: C:\OptimizedISO\Log)

.PARAMETER TargetScript
    Ruta del script New-OptimizedWindowsISO-v2.ps1 a evaluar.

.EXAMPLE
    .\Test-OptimizedISO-v2.ps1
    .\Test-OptimizedISO-v2.ps1 -LogDir "C:\OptimizedISO\Log"
#>

[CmdletBinding()]
param(
    [string]$LogDir       = "C:\OptimizedISO\Log",
    [string]$TargetScript = "C:\OptimizedISO\New-OptimizedWindowsISO-v2.ps1"
)

if (-not (Test-Path $TargetScript)) {
    $candidates = @(
        (Join-Path (Split-Path $PSScriptRoot -Parent) "Builder\New-OptimizedWindowsISO-v2.ps1"),
        (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "scripts\Builder\New-OptimizedWindowsISO-v2.ps1"),
        "C:\OptimizedISO\scripts\Builder\New-OptimizedWindowsISO-v2.ps1"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $TargetScript = $c; break }
    }
}

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$HARNESS_VERSION = "2.0"
$EXPECTED_FUNCS  = 67
$TEMP_ROOT       = Join-Path $env:TEMP "TestHarness_$(Get-Random)"

$script:HPass    = 0
$script:HFail    = 0
$script:HSkip    = 0
$script:HResults = [System.Collections.Generic.List[PSCustomObject]]::new()

# Variables de estado requeridas por el contexto del script analizado
$script:LogFile           = $null
$script:TranscriptFile    = $null
$script:AiSummaryFile     = $null
$script:LogErrors         = [System.Collections.Generic.List[string]]::new()
$script:LogWarns          = [System.Collections.Generic.List[string]]::new()
$script:LogSteps          = [System.Collections.Generic.List[PSObject]]::new()
$script:CurrentStepObj    = $null
$script:AuditResources    = [System.Collections.Generic.List[PSObject]]::new()
$script:WimUbrBefore      = $null
$script:WimUbrAfter       = $null
$script:IsoSha256         = $null
$script:IsoSizeBytes      = $null
$script:UefiBoot          = $null
$script:DownloadStartTime = Get-Date
$script:StartTime         = Get-Date
$script:IsoMountPath      = $null
$script:TempBuildDir      = $null

$global:MockVolumeSmall      = $false
$global:MockReadHostResponse = "0"

# --- Funciones de Reporte y Asertos ---
function Write-HarnessHeader1 {
    param([string]$Text)
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host "    $Text" -ForegroundColor Cyan
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-HarnessHeader2 {
    param([string]$Text)
    Write-Host ""
    Write-Host "  --- $Text ---" -ForegroundColor Yellow
}

function Invoke-HarnessTest {
    param(
        [string]$Name,
        [scriptblock]$TestBlock,
        [string]$SkipReason = ""
    )

    if ($SkipReason) {
        $script:HSkip++
        $script:HResults.Add([PSCustomObject]@{ Name = $Name; Status = "SKIP"; Detail = $SkipReason })
        Write-Host "    [SKIP] $Name" -ForegroundColor DarkGray
        return
    }

    try {
        & $TestBlock | Out-Null
        $script:HPass++
        $script:HResults.Add([PSCustomObject]@{ Name = $Name; Status = "PASS"; Detail = "" })
        Write-Host "    [PASS] $Name" -ForegroundColor Green
    } catch {
        $script:HFail++
        $errMsg = ($_.Exception.Message -replace "`r`n|`n", " ").Trim()
        if ($errMsg.Length -gt 120) { $errMsg = $errMsg.Substring(0, 120) + "..." }
        $script:HResults.Add([PSCustomObject]@{ Name = $Name; Status = "FAIL"; Detail = $errMsg })
        Write-Host "    [FAIL] $Name" -ForegroundColor Red
        Write-Host "           $errMsg" -ForegroundColor DarkRed
    }
}

function Assert-Equal {
    param([string]$Name, $Actual, $Expected, [string]$SkipReason="")
    Invoke-HarnessTest -Name $Name -SkipReason $SkipReason -TestBlock {
        if ($Actual -ne $Expected) { throw "Esperado='$Expected' | Actual='$Actual'" }
    }
}

function Assert-True {
    param([string]$Name, [bool]$Condition, [string]$SkipReason="")
    Invoke-HarnessTest -Name $Name -SkipReason $SkipReason -TestBlock {
        if (-not $Condition) { throw "La condicion debe ser TRUE" }
    }
}

function Assert-False {
    param([string]$Name, [bool]$Condition, [string]$SkipReason="")
    Invoke-HarnessTest -Name $Name -SkipReason $SkipReason -TestBlock {
        if ($Condition) { throw "La condicion debe ser FALSE" }
    }
}

function Assert-NotNull {
    param([string]$Name, $Value, [string]$SkipReason="")
    Invoke-HarnessTest -Name $Name -SkipReason $SkipReason -TestBlock {
        if ($null -eq $Value) { throw "El valor obtenido no debe ser null" }
    }
}

function Assert-Null {
    param([string]$Name, $Value, [string]$SkipReason="")
    Invoke-HarnessTest -Name $Name -SkipReason $SkipReason -TestBlock {
        if ($null -ne $Value) { throw "El valor deberia ser null, obtenido: '$Value'" }
    }
}

function Assert-FileExists {
    param([string]$Name, [string]$Path, [string]$SkipReason="")
    Invoke-HarnessTest -Name $Name -SkipReason $SkipReason -TestBlock {
        if (-not (Test-Path $Path)) { throw "El archivo o ruta no existe: $Path" }
    }
}

function Assert-NoThrow {
    param([string]$Name, [scriptblock]$Code, [string]$SkipReason="")
    Invoke-HarnessTest -Name $Name -SkipReason $SkipReason -TestBlock $Code
}

function Assert-Skip {
    param([string]$Name, [string]$Reason)
    Invoke-HarnessTest -Name $Name -SkipReason $Reason -TestBlock {}
}

# --- STUBS Y MOCKS GLOBALES (Aislamiento de comandos de sistema) ---
function global:Start-Transcript { param([string]$Path, [switch]$Append, $ErrorAction) }
function global:Stop-Transcript  { }

function global:Get-Volume {
    param([string]$DriveLetter, $ErrorAction)
    $free = if ($global:MockVolumeSmall) { 100MB } else { 50GB }
    return [PSCustomObject]@{ DriveLetter = $DriveLetter; SizeRemaining = $free; Size = 500GB }
}

function global:Mount-DiskImage {
    param([string]$ImagePath, [string]$StorageType, [switch]$PassThru, $ErrorAction)
    return [PSCustomObject]@{ ImagePath = $ImagePath; Attached = $true; DevicePath = "\\.\CDROM99" }
}
function global:Dismount-DiskImage { param([string]$ImagePath, $ErrorAction) }
function global:Get-DiskImage {
    param([string]$ImagePath, $ErrorAction)
    return [PSCustomObject]@{ ImagePath = $ImagePath; DevicePath = "\\.\CDROM99" }
}

function global:Start-BitsTransfer {
    param([string]$Source, [string]$Destination, [string]$Description, [string]$DisplayName, [string]$Priority, $ErrorAction)
    throw "BITS_STUB: simulacion intencional de fallo para verificar fallback a curl"
}

function global:dism {
    if (($args -join ' ') -match '/Get-WimInfo') {
        return @(
            "Deployment Image Servicing and Management tool",
            "Version: 10.0.26100.0",
            "Details for image : C:\stub.wim",
            "",
            "Index : 1",
            "Name : Windows 11 Pro",
            "Description : Windows 11 Pro",
            "Architecture : x64",
            "Version : 10.0.26100.0",
            "Edition : Professional",
            "Size : 18,000,000,000 bytes",
            "",
            "Index : 2",
            "Name : Windows 11 Home",
            "Description : Windows 11 Home",
            "Architecture : x64",
            "Version : 10.0.26100.0",
            "Edition : Core",
            "Size : 17,000,000,000 bytes",
            "",
            "The operation completed successfully."
        )
    }
    return @("The operation completed successfully.")
}

function global:reg     { return @("The operation completed successfully.") }
function global:winget  { Write-Output "Windows Package Manager (STUB)" }
function global:oscdimg { Write-Output "OSCDIMG (STUB)" }
function global:7z      { Write-Output "7-Zip (STUB)" }

function global:Read-Host {
    param(
        [string]$Prompt,
        [switch]$AsSecureString,
        [switch]$MaskInput
    )
    $resp = $global:MockReadHostResponse
    Write-Host "    [MOCK Read-Host] '$Prompt' => '$resp'" -ForegroundColor DarkGray
    if ($AsSecureString) {
        $ss = New-Object System.Security.SecureString
        if ($resp) {
            $resp.ToCharArray() | ForEach-Object { $ss.AppendChar($_) }
        }
        return $ss
    }
    return $resp
}

function global:Start-Process {
    param([string]$FilePath, $ArgumentList, [switch]$Wait, [switch]$PassThru, $ErrorAction)
    Write-Host "    [MOCK Start-Process] $FilePath" -ForegroundColor DarkGray
    if ($PassThru) {
        return [PSCustomObject]@{ ExitCode = 0; HasExited = $true; Id = 99999 }
    }
}

# --- INICIO DE EJECUCION ---
Write-HarnessHeader1 "TEST HARNESS v$HARNESS_VERSION - New-OptimizedWindowsISO-v2.ps1"
Write-Host "  Script Objetivo : $TargetScript" -ForegroundColor White
Write-Host "  PowerShell      : $($PSVersionTable.PSVersion) | Host: $env:COMPUTERNAME" -ForegroundColor White
Write-Host "  Fecha/Hora      : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White

# --- FASE 0: PREREQUISITOS ---
Write-HarnessHeader2 "FASE 0: Prerequisitos y Analisis Estatico"
Assert-True "PowerShell 5.1+" ($PSVersionTable.PSVersion.Major -ge 5)
Assert-True "Script objetivo existe en disco" (Test-Path $TargetScript -PathType Leaf)
Assert-NoThrow "Directorio de log accesible" {
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
}

$parseErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($TargetScript, [ref]$null, [ref]$parseErrors)
$criticalErrors = @($parseErrors)
Assert-Equal "AST Parser: 0 errores criticos de sintaxis" $criticalErrors.Count 0

if (Get-Module -ListAvailable PSScriptAnalyzer -ErrorAction SilentlyContinue) {
    Assert-NoThrow "PSScriptAnalyzer: sin errores severos" {
        $issues = @(Invoke-ScriptAnalyzer -Path $TargetScript -Severity Error -ErrorAction SilentlyContinue)
        if ($issues.Count -gt 0) { throw "$($issues.Count) errores: $($issues[0].RuleName)" }
    }
} else {
    Assert-Skip "PSScriptAnalyzer: sin errores severos" "Modulo PSScriptAnalyzer no instalado en host"
}

# --- FASE 1: CARGA DE FUNCIONES VIA AST ---
Write-HarnessHeader2 "FASE 1: Carga Dinamica via AST (Sin ejecucion del Main Body)"
$loadedCount = 0
$loadErrors  = 0

$uiCandidates = @(
    (Join-Path (Split-Path $TargetScript -Parent) 'Core\UI-Engine.ps1'),
    (Join-Path (Split-Path (Split-Path $TargetScript -Parent) -Parent) 'scripts\Core\UI-Engine.ps1'),
    "C:\OptimizedISO\scripts\Core\UI-Engine.ps1"
)
$UIEngine = $uiCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
$scriptsToLoad = @($UIEngine, $TargetScript)

foreach ($scriptPath in $scriptsToLoad) {
    if (-not (Test-Path $scriptPath -PathType Leaf)) {
        Write-Host "    [SKIP] No encontrado: $scriptPath" -ForegroundColor DarkGray
        continue
    }
    try {
        $rawContent = Get-Content $scriptPath -Raw -ErrorAction Stop
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($rawContent, [ref]$null, [ref]$null)
        $funcDefs = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

        foreach ($fd in $funcDefs) {
            try {
                $sb = [ScriptBlock]::Create($fd.Extent.Text)
                . $sb
                $loadedCount++
            } catch {
                $loadErrors++
                Write-Host "    [CARGA-ERROR] $($fd.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        Write-Host "    $(Split-Path $scriptPath -Leaf): $($funcDefs.Count) funciones cargadas" -ForegroundColor DarkGray
    } catch {
        Write-Host "    [FATAL] Error de parsing en $(Split-Path $scriptPath -Leaf): $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
Write-Host "    Total cargadas OK: $loadedCount (esperado: $EXPECTED_FUNCS)" -ForegroundColor $(if ($loadedCount -eq $EXPECTED_FUNCS) { 'Green' } else { 'Yellow' })

Assert-Equal "67 funciones cargadas via AST (Core + UI Engine + Standalone Fallbacks)" $loadedCount $EXPECTED_FUNCS
Assert-Equal "0 errores durante la carga" $loadErrors 0

Write-HarnessHeader2 "FASE 1B: Verificacion de Funciones en Scope"
# Funciones del UI-Engine (Core)
$expectedList = @(
    "Show-UnifiedBanner", "Write-StepHeader", "Write-SubStep", "Write-OK", "Write-Warn",
    "Write-ErrorMsg", "Write-Info", "Show-UnifiedMenu", "Prompt-UnifiedYesNo", "Show-UnifiedSummary",
    # Funciones de New-OptimizedWindowsISO-v2.ps1
    "Initialize-Log", "Write-LogEntry", "Add-AuditRecord", "Write-LogSummary", "Test-Admin", "Test-7ZipInstalled",
    "Test-OSCDImgInstalled", "Install-Dependencies", "Test-MinimumFreeSpace",
    "Convert-BuildToWindowsVersion", "Get-WimImageList", "Detect-WindowsVersion",
    "Get-OnlineWindowsReleases", "Invoke-OfficialWindowsDownload", "Resolve-SourceISO",
    "Expand-WindowsIso", "Invoke-RegUnloadHive", "Add-ImageInstallToAutounattend",
    "Invoke-FallbackSelectionMenu", "Invoke-SelectionMenu", "Invoke-WizardConfig",
    "Invoke-DeploymentChoices", "Invoke-MonitoredProcess", "Invoke-SafeWimDismount",
    "Test-MsuIsPsfFormat", "Get-WimPatchLevel", "Resolve-RuntimesDirectory",
    "Set-BuildDefenderExclusions", "Import-BuildPreset", "Export-BuildPreset",
    "Test-IsRomanizedISO", "Invoke-WimAiHardening"
)
foreach ($fn in $expectedList) {
    Assert-True "Funcion '$fn' disponible" ($null -ne (Get-Command $fn -ErrorAction SilentlyContinue))
}

# --- SETUP: TestDrive Temporal ---
New-Item -ItemType Directory -Path $TEMP_ROOT -Force | Out-Null
$TEMP_OUTPUT = Join-Path $TEMP_ROOT "Output"
$TEMP_ISO    = Join-Path $TEMP_ROOT "test.iso"
$TEMP_XML    = Join-Path $TEMP_ROOT "autounattend.xml"
New-Item -ItemType Directory -Path $TEMP_OUTPUT -Force | Out-Null
[System.IO.File]::WriteAllBytes($TEMP_ISO, [byte[]](0x4D, 0x5A, 0x00))

# --- FASE 2A: SUBSISTEMA DE LOGGING ---
Write-HarnessHeader2 "FASE 2A: Subsistema de Logging"
$script:LogErrors = [System.Collections.Generic.List[string]]::new()
$script:LogWarns  = [System.Collections.Generic.List[string]]::new()
$script:LogSteps  = [System.Collections.Generic.List[PSObject]]::new()
$script:CurrentStepObj = $null

Initialize-Log -OutputDirectory $TEMP_OUTPUT
Assert-NotNull "Initialize-Log: LogFile asignado" $script:LogFile
Assert-True "Initialize-Log: Archivo .log creado en disco" (Test-Path $script:LogFile)
Assert-NotNull "Initialize-Log: AiSummaryFile asignado" $script:AiSummaryFile

Write-LogEntry -Level "INFO"  -Message "Mensaje de prueba INFO"
Write-LogEntry -Level "WARN"  -Message "Mensaje de prueba WARN"
Write-LogEntry -Level "ERROR" -Message "Mensaje de prueba ERROR"
Write-LogEntry -Level "OK"    -Message "Mensaje de prueba OK"
Write-LogEntry -Level "STEP"  -Message "Mensaje de prueba STEP"

$logContent = Get-Content $script:LogFile -Raw -ErrorAction SilentlyContinue
Assert-True "Write-LogEntry: entrada INFO persistida" ($logContent -match "\[INFO \].*Mensaje de prueba INFO")
Assert-True "Write-LogEntry: entrada WARN persistida" ($logContent -match "\[WARN \].*Mensaje de prueba WARN")
Assert-True "Write-LogEntry: entrada ERROR persistida" ($logContent -match "\[ERROR\].*Mensaje de prueba ERROR")
Assert-True "Write-LogEntry: acumula en script:LogErrors" ($script:LogErrors.Count -ge 1)
Assert-True "Write-LogEntry: acumula en script:LogWarns" ($script:LogWarns.Count -ge 1)

Assert-NoThrow "Write-OK sin excepciones"       { Write-OK "Test OK" }
Assert-NoThrow "Write-Warn sin excepciones"     { Write-Warn "Test Warn" }
Assert-NoThrow "Write-Info sin excepciones"     { Write-Info "Test Info" }
Assert-NoThrow "Write-ErrorMsg sin excepciones" { Write-ErrorMsg "Test Error" }
Assert-NoThrow "Write-Step sin excepciones"     { Write-Step "Test Step" }
Assert-NoThrow "Write-Banner sin excepciones"   { Write-Banner }

Write-LogSummary
Assert-FileExists "Write-LogSummary: AI_SUMMARY.md generado" $script:AiSummaryFile
$mdContent = Get-Content $script:AiSummaryFile -Raw -ErrorAction SilentlyContinue
Assert-True "Write-LogSummary: MD contiene encabezado Status" ($mdContent -match "Status")
Assert-True "Write-LogSummary: MD contiene tabla de pasos" ($mdContent -match '\| Step \|')
Assert-True "Write-LogSummary: MD contiene campo Duration" ($mdContent -match "Duration")

# --- FASE 2B: DIAGNOSTICO Y AMBIENTE ---
Write-HarnessHeader2 "FASE 2B: Diagnostico y Entorno"
$adminCheck = Test-Admin
Assert-True "Test-Admin: Retorna valor booleano" ($adminCheck -is [bool])
Write-Host "    [INFO] Sesion actual ejecutandose como Administrador: $adminCheck" -ForegroundColor DarkGray

$r7z = $null
Assert-NoThrow "Test-7ZipInstalled no genera excepciones" { $r7z = Test-7ZipInstalled }
Assert-True "Test-7ZipInstalled: retorna tipo esperado" ($r7z -is [bool] -or $r7z -is [string] -or $null -eq $r7z)

Assert-NoThrow "Test-OSCDImgInstalled no genera excepciones" { Test-OSCDImgInstalled | Out-Null }

$global:MockVolumeSmall = $false
$spaceOk = Test-MinimumFreeSpace -Path "C:\Temp" -RequiredBytes 8GB
Assert-True "Test-MinimumFreeSpace: 50GB libre, 8GB req => True" ($spaceOk -eq $true)

$global:MockVolumeSmall = $true
$spaceFail = Test-MinimumFreeSpace -Path "C:\Temp" -RequiredBytes 8GB
Assert-False "Test-MinimumFreeSpace: 100MB libre, 8GB req => False" ($spaceFail -eq $true)
$global:MockVolumeSmall = $false

$uncCheck = Test-MinimumFreeSpace -Path "\\server\share" -RequiredBytes 1GB
Assert-True "Test-MinimumFreeSpace: Ruta UNC sin letra => True (safe default)" ($uncCheck -eq $true)

$emptyCheck = Test-MinimumFreeSpace -Path "" -RequiredBytes 1GB
Assert-True "Test-MinimumFreeSpace: Ruta vacia => True" ($emptyCheck -eq $true)

# --- FASE 2C: DETECCION Y CONVERSION DE VERSIONES ---
Write-HarnessHeader2 "FASE 2C: Deteccion y Builds Oficiales"
Assert-Equal "Convert-Build: 10.0.22000 (W11 21H2)      => '11'" (Convert-BuildToWindowsVersion "10.0.22000") "11"
Assert-Equal "Convert-Build: 10.0.22621 (W11 22H2)      => '11'" (Convert-BuildToWindowsVersion "10.0.22621") "11"
Assert-Equal "Convert-Build: 10.0.26100 (W11 24H2/LTSC) => '11'" (Convert-BuildToWindowsVersion "10.0.26100") "11"
Assert-Equal "Convert-Build: 10.0.19045 (W10 22H2)      => '10'" (Convert-BuildToWindowsVersion "10.0.19045") "10"
Assert-Equal "Convert-Build: 10.0.19044 (LTSC 2021)     => '10'" (Convert-BuildToWindowsVersion "10.0.19044") "10"
Assert-Equal "Convert-Build: 10.0.10240 (W10 RTM)       => '10'" (Convert-BuildToWindowsVersion "10.0.10240") "10"
Assert-Equal "Convert-Build: string vacio               => null"  (Convert-BuildToWindowsVersion "")          $null
Assert-Equal "Convert-Build: texto sin build numerico   => null"  (Convert-BuildToWindowsVersion "invalid")   $null
Assert-Equal "Convert-Build: null                       => null"  (Convert-BuildToWindowsVersion $null)       $null

$script:releases = $null
Assert-NoThrow "Get-OnlineWindowsReleases: no crash con timeout=1s" {
    $script:releases = Get-OnlineWindowsReleases -TimeoutSec 1
}
Assert-NotNull "Get-OnlineWindowsReleases: Retorna coleccion no nula" $script:releases
Assert-True "Get-OnlineWindowsReleases: Al menos 4 versiones en catalogo base" ($script:releases.Count -ge 4)
Assert-True "Get-OnlineWindowsReleases: Catalogo incluye ediciones LTSC" ((@($script:releases | Where-Object { $_.Channel -eq "LTSC" })).Count -ge 1)
Assert-True "Get-OnlineWindowsReleases: Catalogo incluye Windows 11 GA" ((@($script:releases | Where-Object { $_.Family -eq "Windows 11" -and $_.Channel -eq "General Availability" })).Count -ge 1)
Assert-True "Get-OnlineWindowsReleases: Catalogo es 100% puro Windows 11 (cero Win10)" ((@($script:releases | Where-Object { $_.Family -eq "Windows 10" })).Count -eq 0)

$sampleRel = if ($script:releases) { $script:releases[0] } else { $null }
if ($sampleRel) {
    Assert-NotNull "Get-OnlineWindowsReleases: propiedad Key presente" $sampleRel.Key
    Assert-NotNull "Get-OnlineWindowsReleases: propiedad DisplayName presente" $sampleRel.DisplayName
    Assert-NotNull "Get-OnlineWindowsReleases: propiedad Channel presente" $sampleRel.Channel
}

# --- FASE 2D: LOGICA DE DESCARGA Y ROUTING (CRITICO) ---
Write-HarnessHeader2 "FASE 2D: Motor de Descarga Oficial y Routing de Ediciones"
$global:MockReadHostResponse = "N"
$script:resLTSC = $null
Assert-NoThrow "Invoke-OfficialWindowsDownload: LTSC 2024 + IoTEnterprise sin crash" {
    $script:resLTSC = Invoke-OfficialWindowsDownload -Version "11_LTSC_2024" -Edition "IoTEnterprise" -Language "Spanish" -OutputDir $TEMP_OUTPUT
}
Assert-Null "Invoke-OfficialWindowsDownload: LTSC 2024 + IoT => null (ruta manual asistida)" $script:resLTSC

$script:resBiz = $null
Assert-NoThrow "Invoke-OfficialWindowsDownload: 25H2 + Business sin crash" {
    $script:resBiz = Invoke-OfficialWindowsDownload -Version "11_25H2" -Edition "Business" -Language "Spanish" -OutputDir $TEMP_OUTPUT
}
Assert-Null "Invoke-OfficialWindowsDownload: 25H2 + Business => null (Business = canal especial)" $script:resBiz

$script:res24HBiz = $null
Assert-NoThrow "Invoke-OfficialWindowsDownload: 24H2 + Business sin crash" {
    $script:res24HBiz = Invoke-OfficialWindowsDownload -Version "11_24H2" -Edition "Business" -Language "Spanish" -OutputDir $TEMP_OUTPUT
}
Assert-Null "Invoke-OfficialWindowsDownload: 24H2 + Business => null (Business = canal especial)" $script:res24HBiz

Assert-NoThrow "Invoke-OfficialWindowsDownload: Consumer 25H2 ejecuta flujo con fallback seguro" {
    Invoke-OfficialWindowsDownload -Version "11_25H2" -Edition "Consumer" -Language "Spanish" -OutputDir $TEMP_OUTPUT
}

Assert-NoThrow "Invoke-OfficialWindowsDownload: Consumer 23H2 ejecuta flujo con fallback seguro" {
    Invoke-OfficialWindowsDownload -Version "11_23H2" -Edition "Consumer" -Language "Spanish" -OutputDir $TEMP_OUTPUT
}

# --- FASE 2E: RESOLUCION DE ISO ---
Write-HarnessHeader2 "FASE 2E: Resolucion de ISO (Resolve-SourceISO)"
$resolvedPath = Resolve-SourceISO -SourceISO $TEMP_ISO
Assert-NotNull "Resolve-SourceISO: ISO existente retorna ruta valida" $resolvedPath
Assert-True "Resolve-SourceISO: Ruta coincide con ruta resuelta del archivo" ($resolvedPath -eq (Resolve-Path $TEMP_ISO).Path)

$global:MockReadHostResponse = "0"
Assert-NoThrow "Resolve-SourceISO: Ruta inexistente cancela limpiamente (opcion 0)" {
    Resolve-SourceISO -SourceISO "C:\RutaFalsa\NoExiste.iso"
}

$global:MockReadHostResponse = "N"
$script:resIsoParam = $null
Assert-NoThrow "Resolve-SourceISO con parametro -DownloadOfficialISO no crashea" {
    $script:resIsoParam = Resolve-SourceISO -DownloadOfficialISO -DownloadVersion "11_LTSC_2024" -DownloadEdition "IoTEnterprise" -DownloadLanguage "Spanish"
}
Assert-Null "Resolve-SourceISO: Descarga de LTSC retorna null" $script:resIsoParam

# --- FASE 2F: INYECCION AUTOUNATTEND.XML ---
Write-HarnessHeader2 "FASE 2F: Inyeccion XML (Add-ImageInstallToAutounattend)"
$xmlInval = Add-ImageInstallToAutounattend -AutounattendPath "C:\NoExiste\autounattend.xml" -ImageIndex 1
Assert-False "Add-ImageInstallToAutounattend: Archivo inexistente => False" ($xmlInval -eq $true)

[System.IO.File]::WriteAllBytes($TEMP_XML, [byte[]](0x3C, 0x3E, 0x00))
Assert-NoThrow "Add-ImageInstallToAutounattend: XML corrupto manejado de forma segura" {
    Add-ImageInstallToAutounattend -AutounattendPath $TEMP_XML -ImageIndex 1
}

$validXmlPath = Join-Path $TEMP_ROOT "valid_autounattend.xml"
$validXmlStr = '<?xml version="1.0" encoding="utf-8"?><unattend xmlns="urn:schemas-microsoft-com:unattend"><settings pass="windowsPE"><component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"></component></settings></unattend>'
[System.IO.File]::WriteAllText($validXmlPath, $validXmlStr, [System.Text.Encoding]::UTF8)
Assert-NoThrow "Add-ImageInstallToAutounattend: XML valido procesado correctamente" {
    Add-ImageInstallToAutounattend -AutounattendPath $validXmlPath -ImageIndex 1
}

# PLAN-0082: Verificación de modo Zero-Touch y escape de entidades XML
$ztXmlPath = Join-Path $TEMP_ROOT "zt_autounattend.xml"
$ztBaseXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <EnableFirewall>true</EnableFirewall>
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Bypass TPM Check</Description>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>
  </settings>
  <settings pass="specialize">
    <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>6</Order>
          <Description>Remove OneDrive from Default User Run key</Description>
          <Path>cmd.exe /c &quot;reg delete HKU\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Run /v OneDriveSetup /f &gt;nul 2&gt;&amp;1 || exit 0&quot;</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>
  </settings>
</unattend>
"@
[System.IO.File]::WriteAllText($ztXmlPath, $ztBaseXml, [System.Text.Encoding]::UTF8)

$ztResult = Add-ImageInstallToAutounattend -AutounattendPath $ztXmlPath -ImageIndex 1 -EnableZeroTouch $true -ZeroTouchDisk 0
Assert-True "Add-ImageInstallToAutounattend (Zero-Touch): Inyeccion exitosa => True (PLAN-0082)" ($ztResult -eq $true)

$ztContent = [System.IO.File]::ReadAllText($ztXmlPath, [System.Text.Encoding]::UTF8)
Assert-True "autounattend.xml Zero-Touch: Contiene DiskConfiguration" ($ztContent -match '<DiskConfiguration>')
Assert-True "autounattend.xml Zero-Touch: Contiene AcceptEula true" ($ztContent -match '<AcceptEula>true</AcceptEula>')
Assert-True "autounattend.xml Zero-Touch: Contiene InstallTo DiskID 0 PartitionID 4" ($ztContent -match '<DiskID>0</DiskID>\s*<PartitionID>4</PartitionID>')
Assert-False "autounattend.xml Zero-Touch: Cero entidades unescaped 2>&1" ($ztContent -match '2>&1')


# --- FASE 2G: DESMONTAJE DE REGISTRO ---
Write-HarnessHeader2 "FASE 2G: Descarga de Colmenas (Invoke-RegUnloadHive)"
Assert-NoThrow "Invoke-RegUnloadHive: Colmena HKLM simulada sin error" {
    Invoke-RegUnloadHive -HiveKey "HKLM\TEST_HARNESS_FAKE_$(Get-Random)"
}
Assert-NoThrow "Invoke-RegUnloadHive: Colmena HKCU simulada sin error" {
    Invoke-RegUnloadHive -HiveKey "HKCU\TEST_HARNESS_FAKE_$(Get-Random)"
}

# --- FASE 2H: DEPENDENCIAS ---
Write-HarnessHeader2 "FASE 2H: Verificacion de Dependencias (Install-Dependencies)"
Assert-NoThrow "Install-Dependencies: Ejecucion segura en entorno con stubs" {
    Install-Dependencies
}

# --- FASE 2I: MENUS E INTERFACES INTERACTIVAS (Mock Read-Host) ---
Write-HarnessHeader2 "FASE 2I: Menus Interactivos (Mock de Read-Host)"
$menuEmpty = Invoke-FallbackSelectionMenu -Title "Test" -Options @() -Descriptions @()
Assert-Equal "Invoke-FallbackSelectionMenu: Opciones vacias => -1" $menuEmpty (-1)

$global:MockReadHostResponse = "1"
Assert-NoThrow "Invoke-FallbackSelectionMenu: Seleccion de opcion valida" {
    Invoke-FallbackSelectionMenu -Title "Menu de Prueba" -Options @("Opcion 1", "Opcion 2") -Descriptions @("Desc 1", "Desc 2")
}

$global:MockReadHostResponse = "0"
Assert-NoThrow "Invoke-DeploymentChoices: Cancelacion con '0' sin crash" { Invoke-DeploymentChoices }
Assert-NoThrow "Invoke-WizardConfig: Cancelacion temprana con '0' sin crash" { Invoke-WizardConfig }
Assert-NoThrow "Invoke-SelectionMenu: Seleccion de menu de consola sin crash" {
    Invoke-SelectionMenu -Title "Menu Test" -Options @("Opcion A", "Opcion B") -Descriptions @("Desc A", "Desc B")
}

# --- FASE 2J: SUBSISTEMA DE SUPERVISION DE PROCESOS (WATCHDOG Y MONITOREO) ---
Write-HarnessHeader2 "FASE 2J: Supervision de Procesos (Invoke-MonitoredProcess & Safe Dismount)"

# Test 1: Ejecucion normal y captura de salida
$resEcho = Invoke-MonitoredProcess -FilePath "cmd.exe" -ArgumentList @("/c", "echo WatchdogOutputTest") -TaskDescription "Test Echo" -TimeoutSeconds 10
Assert-True "Invoke-MonitoredProcess: Comando exitoso retorna Success = True" ($resEcho.Success -eq $true)
Assert-Equal "Invoke-MonitoredProcess: ExitCode es 0" $resEcho.ExitCode 0
Assert-False "Invoke-MonitoredProcess: TimedOut es False" $resEcho.TimedOut
Assert-True "Invoke-MonitoredProcess: StdOut capturado correctamente" ($resEcho.StdOut -match "WatchdogOutputTest")

# Test 2: Codigo de salida permitido personalizado (ej. 3010)
$resCustomExit = Invoke-MonitoredProcess -FilePath "cmd.exe" -ArgumentList @("/c", "exit 3010") -AllowExitCodes @(0, 3010) -TaskDescription "Test Exit 3010" -TimeoutSeconds 10
Assert-True "Invoke-MonitoredProcess: AllowExitCodes respeta codigo 3010" ($resCustomExit.Success -eq $true)
Assert-Equal "Invoke-MonitoredProcess: ExitCode reflejado" $resCustomExit.ExitCode 3010

# Test 3: Deteccion de Timeout y terminacion de proceso (Watchdog kill)
$resTimeout = Invoke-MonitoredProcess -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-Command", "Start-Sleep -Seconds 10") -TaskDescription "Test Timeout Kill" -TimeoutSeconds 2 -HeartbeatIntervalSeconds 1
Assert-True "Invoke-MonitoredProcess: Timeout detectado (TimedOut = True)" ($resTimeout.TimedOut -eq $true)
Assert-False "Invoke-MonitoredProcess: Proceso cancelado por timeout retorna Success = False" ($resTimeout.Success -eq $true)
Assert-True "Invoke-MonitoredProcess: Duracion corta por timeout kill" ($resTimeout.DurationSeconds -ge 1 -and $resTimeout.DurationSeconds -lt 8)

# Test 4: Desmontaje seguro de WIM con ruta inexistente (sin crash)
Assert-NoThrow "Invoke-SafeWimDismount: Manejo seguro de directorio inexistente sin excepciones" {
    Invoke-SafeWimDismount -MountDir "C:\RutaFalsa_NoExiste_Mount_$(Get-Random)" -Action Discard
}

# --- FASE 2J-B: Resiliencia de Desmontaje WIM y Prevención de Fugas de Handles (PLAN-0023) ---
Write-HarnessHeader2 "FASE 2J-B: Resiliencia WIM y Desmontaje Seguro (PLAN-0023)"
$v2AstContent = Get-Content -Path $TargetScript -Raw
Assert-False "PLAN-0023: Get-WimPatchLevel no usa Get-ItemProperty en colmena offline" ($v2AstContent -match 'Get-ItemProperty\s+["'']HKLM:\\_WIMPATCH_TMP')
Assert-False "PLAN-0023: Invoke-WimAiHardening no usa Get-ItemProperty en colmena offline" ($v2AstContent -match 'Get-ItemProperty\s+["'']HKLM:\\_ROMANOS_SW')
Assert-True  "PLAN-0023: Get-WimPatchLevel consulta UBR via reg.exe query nativo" ($v2AstContent -match 'reg(\.exe)?\s+query\s+["'']HKLM\\_WIMPATCH_TMP.*UBR')
Assert-True  "PLAN-0023: Invoke-SafeWimDismount detecta imagen ya confirmada (alreadyCommitted)" ($v2AstContent -match '\$alreadyCommitted')
Assert-True  "PLAN-0023: Invoke-SafeWimDismount realiza higiene preventiva de colmenas huerfanas" ($v2AstContent -match 'PRE-DISMOUNT')
Assert-True  "PLAN-0023: Invoke-RegUnloadHive soporta alias HiveKey" ($v2AstContent -match 'Alias\("HiveKey"\)')


# --- FASE 2K: Subsistema de Diagnóstico Post-Instalación ---
Write-HarnessHeader2 "FASE 2K: Subsistema de Diagnostico Post-Instalacion"
$diagTestDir = Join-Path $TEMP_ROOT "DiagTest"
New-Item -ItemType Directory $diagTestDir -Force | Out-Null

$v2Content = Get-Content -Path $TargetScript -Raw -ErrorAction SilentlyContinue

Assert-True "PLAN-0040: New-OptimizedWindowsISO-v2.ps1 inyecta PostInstall-Diagnostics.ps1 fisico" ($v2Content -match 'diagSourceCandidates' -and $v2Content -match 'physicalDiag')
Assert-True "PostInstall: Lanzador Auditar-Instalacion.cmd presente en v2" ($v2Content -match 'auditarLauncherContent\s*=' -or $v2Content -match 'auditarLauncherTemplate\s*=')
Assert-True "PostInstall: SetupComplete.cmd invoca PostInstall-Diagnostics.ps1" ($v2Content -match 'PostInstall-Diagnostics\.ps1.*-DesktopOutput')
Assert-False "autounattend.xml: Sin directivas invalidas WillContinueOnFailure" ($v2Content -match '<WillContinueOnFailure>')

# Validar y ejecutar sintacticamente el script fisico canonico PostInstall-Diagnostics.ps1 en sandbox
$diagPhysCandidates = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Modules\PostInstall-Diagnostics.ps1"),
    (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "scripts\Modules\PostInstall-Diagnostics.ps1"),
    "C:\OptimizedISO\scripts\Modules\PostInstall-Diagnostics.ps1"
)
$physicalDiagPath = $diagPhysCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
Assert-True "PLAN-0040: Archivo fisico canonico PostInstall-Diagnostics.ps1 existe en disco" ([bool]$physicalDiagPath)

if ($physicalDiagPath) {
    # Validar AST del script de diagnostico
    $diagTokens = $null
    $diagErrors = $null
    $diagAst = [System.Management.Automation.Language.Parser]::ParseFile($physicalDiagPath, [ref]$diagTokens, [ref]$diagErrors)
    Assert-Equal "PostInstall: Script canonico tiene sintaxis valida sin errores AST" $diagErrors.Count 0

    # Ejecutar en sandbox con powershell.exe nativo
    $outReportDir = Join-Path $diagTestDir "Logs"
    Assert-NoThrow "PostInstall: Ejecucion segura en sandbox genera reporte sin excepciones" {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $physicalDiagPath -OutputDir $outReportDir -ExpectedProfile "2"
    }

    $genReport = Join-Path $outReportDir "PostInstall_Report.md"
    Assert-FileExists "PostInstall: Reporte PostInstall_Report.md generado en disco" $genReport
    if (Test-Path $genReport) {
        $repContent = Get-Content -Path $genReport -Raw -Encoding UTF8
        Assert-True "PostInstall: Reporte contiene encabezado de auditoria" ($repContent -match 'Reporte de Auditoria y Diagnostico Post-Instalacion')
        Assert-True "PostInstall: Reporte contiene seccion de logs de Setup" ($repContent -match 'Auditoria de Logs Oficiales de Windows Setup')
        Assert-True "PostInstall: Reporte contiene seccion de SetupComplete" ($repContent -match 'Auditoria de SetupComplete\.cmd')
        Assert-True "PostInstall: Reporte contiene Resumen de Ejecucion o Diagnostico" ($repContent -match 'Resumen|Telemetria|Policy-Engine')
    }
}

# --- FASE 2L: SUBSISTEMA DE RESOLUCION DE RUNTIMES (PLAN-0006) ---
Write-HarnessHeader2 "FASE 2L: Resolucion y Diagnostico de Runtimes (Resolve-RuntimesDirectory)"
$runtimesMockDir = Join-Path $TEMP_ROOT "MockRuntimes"
$runtimesEmptyDir = Join-Path $TEMP_ROOT "EmptyRuntimes"
New-Item -ItemType Directory -Path $runtimesMockDir -Force | Out-Null
New-Item -ItemType Directory -Path $runtimesEmptyDir -Force | Out-Null

# Crear archivos simulados de runtimes
[System.IO.File]::WriteAllBytes((Join-Path $runtimesMockDir "vc_redist.x64.exe"), [byte[]](0x4D, 0x5A))
[System.IO.File]::WriteAllBytes((Join-Path $runtimesMockDir "dxsetup.exe"), [byte[]](0x4D, 0x5A))

# Test 1: Resolucion con carpeta mock con instaladores
$mockRes = Resolve-RuntimesDirectory -ExplicitPath $runtimesMockDir
Assert-True "Resolve-RuntimesDirectory: Detecta carpeta mock con instaladores (Found = True)" ($mockRes.Found -eq $true)
Assert-Equal "Resolve-RuntimesDirectory: Conteo de archivos correcto" $mockRes.FileCount 2
Assert-True "Resolve-RuntimesDirectory: Flag HasVcRedist es True" ($mockRes.HasVcRedist -eq $true)
Assert-True "Resolve-RuntimesDirectory: Flag HasDirectX es True" ($mockRes.HasDirectX -eq $true)
Assert-Equal "Resolve-RuntimesDirectory: Path coincide con carpeta resuelta" $mockRes.Path (Resolve-Path $runtimesMockDir).Path

# Test 2: Resolucion con carpeta vacia
$emptyRes = Resolve-RuntimesDirectory -ExplicitPath $runtimesEmptyDir
Assert-False "Resolve-RuntimesDirectory: Carpeta sin instaladores retorna Found = False" ($emptyRes.Found -eq $true)
Assert-Equal "Resolve-RuntimesDirectory: FileCount es 0 en carpeta vacia" $emptyRes.FileCount 0

# Test 3: Resolucion con ruta invalida/inexistente
$invalidRes = Resolve-RuntimesDirectory -ExplicitPath "C:\Ruta_Inexistente_Fake_$(Get-Random)"
Assert-False "Resolve-RuntimesDirectory: Ruta inexistente retorna Found = False" ($invalidRes.Found -eq $true)
Assert-Equal "Resolve-RuntimesDirectory: FileCount es 0 en ruta inexistente" $invalidRes.FileCount 0

# Test 4: Resolucion automatica sin parametro explicito
$autoRes = Resolve-RuntimesDirectory
Assert-NotNull "Resolve-RuntimesDirectory: Retorna objeto no nulo en exploracion automatica" $autoRes
Assert-True "Resolve-RuntimesDirectory: Objeto contiene propiedad Found" ($null -ne $autoRes.PSObject.Properties['Found'])

# --- FASE 2M: SUBSISTEMA DE AUDITORIA DE RECURSOS (PLAN-0009) ---
Write-HarnessHeader2 "FASE 2M: Sistema de Auditoria de Recursos (Add-AuditRecord)"
$script:AuditResources = [System.Collections.Generic.List[PSObject]]::new()
$script:LogErrors = [System.Collections.Generic.List[string]]::new()
$script:LogWarns  = [System.Collections.Generic.List[string]]::new()
$script:IsoSha256 = $null; $script:IsoSizeBytes = $null
$script:UefiBoot  = $null; $script:WimUbrBefore = $null; $script:WimUbrAfter = $null

Assert-True  "Add-AuditRecord: funcion disponible" ($null -ne (Get-Command Add-AuditRecord -ErrorAction SilentlyContinue))
Add-AuditRecord -Resource "TestRecurso" -Target "WIM Idx 10" -Status "OK" -Details "123 archivos"
Assert-Equal "Add-AuditRecord: registro en AuditResources"        $script:AuditResources.Count 1
Assert-Equal "Add-AuditRecord: Resource correcto"                  $script:AuditResources[0].Resource "TestRecurso"
Assert-Equal "Add-AuditRecord: Status correcto"                    $script:AuditResources[0].Status "OK"
Assert-Equal "Add-AuditRecord: OK no propaga a LogErrors"          $script:LogErrors.Count 0
Assert-Equal "Add-AuditRecord: OK no propaga a LogWarns"           $script:LogWarns.Count 0
Add-AuditRecord -Resource "AppX" -Target "WIM Idx 10" -Status "WARN" -Details "3 protegidos"
Assert-Equal "Add-AuditRecord: WARN propaga a LogWarns"            $script:LogWarns.Count 1
Add-AuditRecord -Resource "ISO Final" -Target "C:\out.iso" -Status "FAIL" -Details "error"
Assert-Equal "Add-AuditRecord: FAIL propaga a LogErrors"           $script:LogErrors.Count 1
$script:IsoSha256 = "ABC123"; $script:IsoSizeBytes = 4500000000; $script:UefiBoot = "efisys_noprompt.bin"
Assert-True  "AuditResources: IsoSha256 configurable"              ($null -ne $script:IsoSha256)
Assert-True  "AuditResources: UefiBoot configurable"               ($null -ne $script:UefiBoot)
Assert-True  "AuditResources: IsoSizeBytes positivo"               ($script:IsoSizeBytes -gt 0)

# --- FASE 2N: MOTOR DISM SERVICING OPTIMIZADO Y EXCLUSIONES DEFENDER (PLAN-0011 / PLAN-0018) ---
Write-HarnessHeader2 "FASE 2N: Motor DISM Servicing Optimizado y Exclusiones Defender (PLAN-0018)"

Assert-NoThrow "Set-BuildDefenderExclusions ejecuta sin excepciones en rutas mock" {
    Set-BuildDefenderExclusions -Paths @("C:\TestMockDir1", "C:\TestMockDir2")
    Set-BuildDefenderExclusions -Paths @("C:\TestMockDir1", "C:\TestMockDir2") -Remove
}

Assert-NoThrow "Validacion de parametro DisableDefenderExclusion en AST" {
    $targetContent = Get-Content $TargetScript -Raw
    if ($targetContent -notmatch '\$DisableDefenderExclusion') {
        throw "Parametro DisableDefenderExclusion no encontrado en el script objetivo."
    }
}

Assert-NoThrow "Validacion de eliminacion de parametros obsoletos (BuildEngine, FastBuild, UseWimlib)" {
    $targetContent = Get-Content $TargetScript -Raw
    if ($targetContent -match '\$BuildEngine' -or $targetContent -match '\$FastBuild' -or $targetContent -match '\$UseWimlib') {
        throw "Parametros obsoletos encontrados en el script objetivo tras saneamiento PLAN-0018."
    }
}

# --- FASE 2O: PRESETS, REBUILD DETECTION, PERFIL 3 Y OPTIMIZACIONES OFICIALES (PLAN-0019) ---
Write-HarnessHeader2 "FASE 2O: Presets, Deteccion Rebuild, Perfil 3 y Optimizaciones Oficiales (PLAN-0019)"

$presetTestDir = Join-Path $TEMP_ROOT "PresetTest"
New-Item -ItemType Directory -Path $presetTestDir -Force | Out-Null

# Test 1: Export-BuildPreset genera un archivo JSON valido
$script:Language            = "es-ES"
$script:Locale              = "es-ES"
$script:Timezone            = "Romance Standard Time"
$script:KeyboardOverride    = "0000040a"
$script:LocalUser           = "AdminTest"
$script:LocalPassword       = "Pass123"
$script:OptProfile          = "3"
$script:BlockOneDrive       = $true
$script:InjectVisualTweaks  = $true
$script:WimCompression      = "Max"
$Architecture               = "x64"

Assert-NoThrow "Export-BuildPreset: Exporta archivo de preset sin excepciones" {
    Export-BuildPreset -OutputDirectory $presetTestDir
}

$presetFiles = @(Get-ChildItem -Path $presetTestDir -Filter "Preset_romanOS_*.json")
Assert-True "Export-BuildPreset: Archivo Preset_romanOS_*.json creado" ($presetFiles.Count -ge 1)

if ($presetFiles.Count -ge 1) {
    $exportedPresetPath = $presetFiles[0].FullName
    $raw = Get-Content -Path $exportedPresetPath -Raw -Encoding UTF8
    $jsonObj = $null
    Assert-NoThrow "Export-BuildPreset: Archivo exportado es JSON valido" {
        $raw | ConvertFrom-Json | Out-Null
    }
    $jsonObj = $raw | ConvertFrom-Json
    Assert-Equal "Export-BuildPreset: Language exportado correctamente" $jsonObj.Language "es-ES"
    Assert-Equal "Export-BuildPreset: OptimizationProfile exportado correctamente" $jsonObj.OptimizationProfile "3"
    Assert-Equal "Export-BuildPreset: BlockOneDrive exportado correctamente" $jsonObj.BlockOneDrive $true
    Assert-Equal "Export-BuildPreset: WimCompression exportado correctamente" $jsonObj.WimCompression "Max"

    # Test 2: Import-BuildPreset carga los valores en un contexto limpio
    $script:Language   = ""
    $script:OptProfile = ""
    Assert-NoThrow "Import-BuildPreset: Importa configuracion desde JSON sin excepciones" {
        Import-BuildPreset -PresetPath $exportedPresetPath -ScriptBoundParameters @{}
    }
    Assert-Equal "Import-BuildPreset: Language cargado en scope" $script:Language "es-ES"
    Assert-Equal "Import-BuildPreset: OptimizationProfile cargado en scope" $script:OptProfile "3"

    # Test 3: Precedencia de CLI (ScriptBoundParameters tiene prioridad)
    $script:Language = "en-US"
    Import-BuildPreset -PresetPath $exportedPresetPath -ScriptBoundParameters @{ Language = "en-US" }
    Assert-Equal "Import-BuildPreset: CLI BoundParameters prevalece sobre preset" $script:Language "en-US"
}

# Test 4: Test-IsRomanizedISO detecta correctamente ISO limpia vs ISO romanizada
$cleanIsoDir = Join-Path $TEMP_ROOT "CleanISO"
$romanIsoDir = Join-Path $TEMP_ROOT "RomanISO"
New-Item -ItemType Directory -Path (Join-Path $cleanIsoDir "sources") -Force | Out-Null
$romanOemDir = Join-Path $romanIsoDir 'sources\$OEM$\$$\Setup\Scripts'
New-Item -ItemType Directory -Path $romanOemDir -Force | Out-Null

# Crear SetupComplete firmado
[System.IO.File]::WriteAllText((Join-Path $romanOemDir "SetupComplete.cmd"), "REM SetupComplete.cmd - Generado por romanOS OptimizedISO`r`necho OK", [System.Text.Encoding]::UTF8)
# Crear autounattend con bypasses
[System.IO.File]::WriteAllText((Join-Path $romanIsoDir "autounattend.xml"), "<unattend><BypassTPMCheck>1</BypassTPMCheck><BypassNRO>1</BypassNRO></unattend>", [System.Text.Encoding]::UTF8)

$cleanCheck = Test-IsRomanizedISO -ExtractedDir $cleanIsoDir
Assert-False "Test-IsRomanizedISO: Carpeta limpia => SetupComplete = False" $cleanCheck.SetupComplete
Assert-False "Test-IsRomanizedISO: Carpeta limpia => Autounattend = False" $cleanCheck.Autounattend

$romanCheck = Test-IsRomanizedISO -ExtractedDir $romanIsoDir
Assert-True "Test-IsRomanizedISO: Carpeta romanizada => SetupComplete = True" $romanCheck.SetupComplete
Assert-True "Test-IsRomanizedISO: Carpeta romanizada => Autounattend = True" $romanCheck.Autounattend

# Test 5: Invoke-WimAiHardening con build mock
Assert-NoThrow "Invoke-WimAiHardening: Manejo seguro de directorio no montado (retorna false sin crash)" {
    $aiRes = Invoke-WimAiHardening -WimMountPath "C:\Ruta_Inexistente_Mount_$(Get-Random)" -DetectedBuild 26100
    if ($aiRes -ne $false) { throw "Debe retornar false para ruta inexistente" }
}

# Test 6: Validacion de directivas oficiales en el script objetivo
$v2ScriptContent = Get-Content -Path $TargetScript -Raw
Assert-True "PLAN-0019: Parametros PresetFile y SavePreset presentes en AST" ($v2ScriptContent -match '\$PresetFile' -and $v2ScriptContent -match '\$SavePreset')
Assert-True "PLAN-0019: Perfil 3 soportado en ValidateSet de OptimizationProfile" ($v2ScriptContent -match 'ValidateSet\("1",\s*"2",\s*"3"\)')
Assert-True "PLAN-0019: Politica Widgets AllowWidgets inyectada en autounattend" ($v2ScriptContent -match 'AllowWidgets')
Assert-True "PLAN-0019: Politica Bing DisableWebSearch inyectada en autounattend" ($v2ScriptContent -match 'DisableWebSearch')
Assert-True "PLAN-0019: Politica Delivery Optimization DODownloadMode inyectada en autounattend" ($v2ScriptContent -match 'DODownloadMode')
Assert-True "PLAN-0019: Politica AdvertisingInfo inyectada en autounattend" ($v2ScriptContent -match 'DisabledByGroupPolicy')
Assert-True "PLAN-0019: Politica Activity History (PublishUserActivities) inyectada en autounattend" ($v2ScriptContent -match 'PublishUserActivities')
Assert-True "PLAN-0021: ReservedStorage ShippedWithReserves presente en WIM servicing" ($v2ScriptContent -match 'ShippedWithReserves')
Assert-True "PLAN-0021: Politica Widgets AllowWidgets presente en autounattend (en reemplazo de TaskbarDa bloqueado por UCPD)" ($v2ScriptContent -match 'AllowWidgets')
Assert-True "PLAN-0019: SetupComplete configura plan Equilibrado para Perfil 3" ($v2ScriptContent -match '381b4222-f694-41f0-9685-ff5bb260df2e')

# Test 7: Arquitectura Unificada y Ecosistema Integral SSOT (PLAN-0022)
Write-HarnessHeader2 "Test 7: Validacion de Arquitectura Unificada (Policy-Engine y Sincronizacion SSOT)"
$policyEnginePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Core\Policy-Engine.ps1"
Assert-FileExists "PLAN-0022: Policy-Engine.ps1 existe en scripts/Core" $policyEnginePath

# Dot-source de Policy-Engine para pruebas de contrato
. $policyEnginePath
Assert-True "PLAN-0022: Get-RomanOSPolicies function registrada" ([bool](Get-Command Get-RomanOSPolicies -ErrorAction SilentlyContinue))
Assert-True "PLAN-0022: Export-RomanOSUnattendCommands function registrada" ([bool](Get-Command Export-RomanOSUnattendCommands -ErrorAction SilentlyContinue))
Assert-True "PLAN-0022: Test-RomanOSPolicy function registrada" ([bool](Get-Command Test-RomanOSPolicy -ErrorAction SilentlyContinue))

$allPols = Get-RomanOSPolicies -Profile '1'
Assert-True "PLAN-0022: Catalogo de politicas contiene al menos 20 directivas maestras" ($allPols.Count -ge 20)

$widgetPol = $allPols | Where-Object { $_.Id -eq 'POL_WIDGETS_ALLOW' }
Assert-NotNull "PLAN-0022: Politica AllowWidgets presente en catalogo maestro" $widgetPol
Assert-Equal "PLAN-0022: Politica AllowWidgets valor esperado es 0" $widgetPol.ExpectedValue 0

$bingPol = $allPols | Where-Object { $_.Id -eq 'POL_SEARCH_DISABLE_WEB' }
Assert-NotNull "PLAN-0022: Politica DisableWebSearch presente en catalogo maestro" $bingPol
Assert-Equal "PLAN-0022: Politica DisableWebSearch valor esperado es 1" $bingPol.ExpectedValue 1

$unattendExport = Export-RomanOSUnattendCommands -Profile '1' -StartOrder 2
Assert-True "PLAN-0022: Export-RomanOSUnattendCommands genera XML con RunSynchronousCommand" ($unattendExport.XmlContent -match '<RunSynchronousCommand')
Assert-True "PLAN-0022: Export-RomanOSUnattendCommands incluye AllowWidgets" ($unattendExport.XmlContent -match 'AllowWidgets')
Assert-True "PLAN-0022: Export-RomanOSUnattendCommands incluye DisableWebSearch" ($unattendExport.XmlContent -match 'DisableWebSearch')
Assert-True "PLAN-0022: Export-RomanOSUnattendCommands devuelve NextOrder consecutivo" ($unattendExport.NextOrder -gt 20)

# Paridad con PostInstall-Diagnostics.ps1
$postDiagPath = Join-Path (Split-Path $PSScriptRoot -Parent) "PostInstall-Diagnostics.ps1"
$postDiagContent = Get-Content -Path $postDiagPath -Raw
Assert-True "PLAN-0022: PostInstall-Diagnostics.ps1 carga Core/Policy-Engine.ps1" ($postDiagContent -match 'Policy-Engine\.ps1')
Assert-True "PLAN-0022: PostInstall-Diagnostics.ps1 audita Get-RomanOSPolicies dinamicamente" ($postDiagContent -match 'Get-RomanOSPolicies')
Assert-True "PLAN-0022: PostInstall-Diagnostics.ps1 audita paquete WebExperience especificamente" ($postDiagContent -match 'WebExperience')
Assert-True "PLAN-0022: PostInstall-Diagnostics.ps1 incluye tabla HTML de Policy-Engine" ($postDiagContent -match 'Directivas Oficiales de Optimizacion \(Policy-Engine\)')

# Paridad con New-OptimizedWindowsISO-v2.ps1 y romanOS-Toolkit.ps1
Assert-True "PLAN-0022: v2 script carga Core/Policy-Engine.ps1" ([bool]($v2ScriptContent -match 'Policy-Engine\.ps1'))
Assert-True "PLAN-0022: v2 script invoca Export-RomanOSUnattendCommands" ([bool]($v2ScriptContent -match 'Export-RomanOSUnattendCommands'))
Assert-True "PLAN-0022: v2 script inyecta PostInstall-Diagnostics.ps1 desde archivo fisico" ([bool]($v2ScriptContent -match 'diagSourceCandidates'))

# Busqueda del toolkit en Modules/ con fallback a Testing/
$toolkitModulesDir = Join-Path (Split-Path $PSScriptRoot -Parent) "Modules"
$toolkitPath = if (Test-Path (Join-Path $toolkitModulesDir "romanOS-Toolkit.ps1")) {
    Join-Path $toolkitModulesDir "romanOS-Toolkit.ps1"
} else {
    Join-Path $PSScriptRoot "romanOS-Toolkit.ps1"
}
$toolkitContent = if (Test-Path $toolkitPath -ErrorAction SilentlyContinue) { Get-Content -Path $toolkitPath -Raw } else { '' }
Assert-True "PLAN-0022: romanOS-Toolkit.ps1 carga Core/Policy-Engine.ps1" ([bool]($toolkitContent -match 'Policy-Engine\.ps1'))

# Paridad de Gobernanza en .agents/AGENTS.md
# El archivo .agents/AGENTS.md esta en la RAIZ del repositorio, dos niveles por encima de scripts\Testing\
$repoRoot          = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$agentsPath1       = Join-Path $repoRoot ".agents\AGENTS.md"
$agentsPath2       = Join-Path (Split-Path $PSScriptRoot -Parent) ".agents\AGENTS.md"
$agentsPath3       = "C:\OptimizedISO\.agents\AGENTS.md"
$agentsRulePath    = @($agentsPath1, $agentsPath2, $agentsPath3) | Where-Object { Test-Path $_ -ErrorAction SilentlyContinue } | Select-Object -First 1
$agentsRuleContent = if ($agentsRulePath) { Get-Content -Path $agentsRulePath -Raw -ErrorAction SilentlyContinue } else { '' }
if (-not $agentsRuleContent) { $agentsRuleContent = '' }
Assert-True "PLAN-0022: .agents/AGENTS.md contiene Regla 9 de Arquitectura Unificada (SSOT)" ([bool]($agentsRuleContent -match 'Regla 9|Arquitectura Unificada'))

# PLAN-0026: Validaciones de Desacoplamiento de Redundancias y SSOT Canonico
Assert-True "PLAN-0026: Get-RomanOSBrowserPolicies function registrada" ([bool](Get-Command Get-RomanOSBrowserPolicies -ErrorAction SilentlyContinue))
Assert-True "PLAN-0026: Apply-RomanOSBrowserPolicies function registrada" ([bool](Get-Command Apply-RomanOSBrowserPolicies -ErrorAction SilentlyContinue))
Assert-True "PLAN-0026: Export-RomanOSBrowserCommands function registrada" ([bool](Get-Command Export-RomanOSBrowserCommands -ErrorAction SilentlyContinue))

$browserPols = Get-RomanOSBrowserPolicies
Assert-True "PLAN-0026: Catalogo de directivas de navegadores contiene al menos 80 directivas" ($browserPols.Count -ge 80)
$browserCmd = Export-RomanOSBrowserCommands
Assert-True "PLAN-0026: Export-RomanOSBrowserCommands genera comandos para Edge, Chrome, Firefox y Brave" ([bool]($browserCmd -match 'Microsoft\\Edge' -and $browserCmd -match 'Google\\Chrome' -and $browserCmd -match 'Mozilla\\Firefox' -and $browserCmd -match 'BraveSoftware\\Brave'))

# Verificacion de inyeccion Core/ en New-OptimizedWindowsISO-v2.ps1
Assert-True "PLAN-0026: v2 script inyecta Core/ en `$OEM`$" ([bool]($v2ScriptContent -match 'scripts\\Core|Core/Policy-Engine\.ps1'))
Assert-True "PLAN-0026: v2 script invoca Add-OptimizedContextMenus.ps1 en SetupComplete.cmd" ([bool]($v2ScriptContent -match 'Add-OptimizedContextMenus\.ps1"\s+-Apply\s+-EnableClassicMenu'))
Assert-False "PLAN-0026: v2 script elimino las 6 claves obsoletas planas de SetupComplete.cmd" ([bool]($v2ScriptContent -match 'shell\\OpenElevatedPowerShell'))

# Verificacion de desacoplamiento modular — buscar scripts en Modules/ con fallback a Testing/
$modulesDir    = Join-Path (Split-Path $PSScriptRoot -Parent) "Modules"
$maintScript   = if (Test-Path (Join-Path $modulesDir "Invoke-WindowsMaintenance.ps1"))           { Join-Path $modulesDir "Invoke-WindowsMaintenance.ps1"           } else { Join-Path $PSScriptRoot "Invoke-WindowsMaintenance.ps1" }
$netOptScript  = if (Test-Path (Join-Path $modulesDir "Win11-Network-Diagnostics-Optimizer.ps1")) { Join-Path $modulesDir "Win11-Network-Diagnostics-Optimizer.ps1" } else { Join-Path $PSScriptRoot "Win11-Network-Diagnostics-Optimizer.ps1" }
$debloatScript = if (Test-Path (Join-Path $modulesDir "Win11-Debloat-v3-Adaptive.ps1"))           { Join-Path $modulesDir "Win11-Debloat-v3-Adaptive.ps1"           } else { Join-Path $PSScriptRoot "Win11-Debloat-v3-Adaptive.ps1" }

$maintContent     = if (Test-Path $maintScript   -ErrorAction SilentlyContinue) { Get-Content -Path $maintScript   -Raw } else { '' }
$netOptContent    = if (Test-Path $netOptScript  -ErrorAction SilentlyContinue) { Get-Content -Path $netOptScript  -Raw } else { '' }
$debloatContent   = if (Test-Path $debloatScript -ErrorAction SilentlyContinue) { Get-Content -Path $debloatScript -Raw } else { '' }

Assert-True "PLAN-0026: Invoke-WindowsMaintenance.ps1 soporta -ShadersOnly" ([bool]($maintContent -match 'ShadersOnly'))
Assert-True "PLAN-0026: Invoke-WindowsMaintenance.ps1 soporta -TrimOnly" ([bool]($maintContent -match 'TrimOnly'))
Assert-True "PLAN-0026: Win11-Network-Diagnostics-Optimizer.ps1 soporta -NagleOnly" ([bool]($netOptContent -match 'NagleOnly'))
Assert-True "PLAN-0026: Win11-Debloat-v3-Adaptive.ps1 carga Core/Policy-Engine.ps1" ([bool]($debloatContent -match 'Policy-Engine\.ps1'))

$optimizeBrowsersContent = Get-Content -Path (Join-Path (Split-Path $PSScriptRoot -Parent) "Modules\Optimize-WebBrowsers.ps1") -Raw -ErrorAction SilentlyContinue
if (-not $optimizeBrowsersContent) { $optimizeBrowsersContent = '' }
Assert-True "PLAN-0026: Optimize-WebBrowsers.ps1 delega en Apply-RomanOSBrowserPolicies" ([bool]($optimizeBrowsersContent -match 'Apply-RomanOSBrowserPolicies'))
Assert-True "PLAN-0026: Win11-Debloat-v3-Adaptive.ps1 delega Nagle en Win11-Network-Diagnostics-Optimizer.ps1" ([bool]($debloatContent -match 'Win11-Network-Diagnostics-Optimizer\.ps1 -NagleOnly'))
Assert-True "PLAN-0026: romanOS-Toolkit.ps1 delega Shaders y TRIM en Invoke-WindowsMaintenance.ps1" ([bool]($toolkitContent -match 'Invoke-WindowsMaintenance\.ps1' -and $toolkitContent -match '-ShadersOnly' -and $toolkitContent -match '-TrimOnly'))

# PLAN-0027: Validaciones del Ecosistema Integral de Controladores (Drivers)
Assert-True "PLAN-0027: Get-RomanOSDriverPolicies function registrada" ([bool](Get-Command Get-RomanOSDriverPolicies -ErrorAction SilentlyContinue))
Assert-True "PLAN-0027: Apply-RomanOSDriverPolicies function registrada" ([bool](Get-Command Apply-RomanOSDriverPolicies -ErrorAction SilentlyContinue))
Assert-True "PLAN-0027: Export-RomanOSDriverCommands function registrada" ([bool](Get-Command Export-RomanOSDriverCommands -ErrorAction SilentlyContinue))

$driverPols = Get-RomanOSDriverPolicies
Assert-True "PLAN-0027: Catalogo de directivas de drivers contiene al menos 6 directivas oficiales" ($driverPols.Count -ge 6)
$driverXml = Export-RomanOSDriverCommands -Format Xml
Assert-True "PLAN-0027: Export-RomanOSDriverCommands genera directivas ExcludeWUDriversInQualityUpdate" ($driverXml.Content -match 'ExcludeWUDriversInQualityUpdate')
Assert-True "PLAN-0027: Export-RomanOSDriverCommands genera directivas PreventDeviceMetadataFromNetwork" ($driverXml.Content -match 'PreventDeviceMetadataFromNetwork')

# Verificacion de Dual-Servicing y PnpCustomizations en New-OptimizedWindowsISO-v2.ps1
Assert-True "PLAN-0027: v2 script implementa dual-servicing en boot.wim (WinPE/Setup)" ($v2ScriptContent -match 'DUAL-SERVICING.*boot\.wim' -and $v2ScriptContent -match 'boot_mount')
Assert-True "PLAN-0027: v2 script inyecta flag oficial /ForceUnsigned en DISM /Add-Driver" ($v2ScriptContent -match '/ForceUnsigned')
Assert-True "PLAN-0027: autounattend.xml contiene componente Microsoft-Windows-PnpCustomizationsWinPE" ($v2ScriptContent -match 'Microsoft-Windows-PnpCustomizationsWinPE')
Assert-True "PLAN-0027: v2 script soporta parametro -SkipBootWimDrivers" ($v2ScriptContent -match 'SkipBootWimDrivers')

# Verificacion de scripts modulares de drivers
$backupDrvScript = Join-Path (Split-Path $PSScriptRoot -Parent) "Drivers\Backup-HardwareDrivers.ps1"
Assert-FileExists "PLAN-0027: Backup-HardwareDrivers.ps1 existe en disco" $backupDrvScript
$cleanDrvScript = Join-Path (Split-Path $PSScriptRoot -Parent) "Drivers\Clean-DriverStore.ps1"
Assert-FileExists "PLAN-0027: Clean-DriverStore.ps1 existe en disco" $cleanDrvScript
$getDrvScript = Join-Path (Split-Path $PSScriptRoot -Parent) "Drivers\Get-CriticalDrivers.ps1"
Assert-FileExists "PLAN-0027: Get-CriticalDrivers.ps1 existe en disco" $getDrvScript

# Verificacion de integracion en Toolkit Maestro y Debloat
Assert-True "PLAN-0027: romanOS-Toolkit.ps1 resuelve e incluye directorio Drivers" ($toolkitContent -match 'Drivers')
Assert-True "PLAN-0027: romanOS-Toolkit.ps1 soporta modulo -Module Drivers" ($toolkitContent -match 'Invoke-DriversModule')
Assert-True "PLAN-0027: Win11-Debloat-v3-Adaptive.ps1 delega en Apply-RomanOSDriverPolicies" ($debloatContent -match 'Apply-RomanOSDriverPolicies')

# PLAN-0029: Validaciones de Menús Contextuales Nativos, Tareas a Demanda y MMCSS SSOT
$mmcssResp = $allPols | Where-Object { $_.Id -eq "POL_MMCSS_RESPONSIVENESS" }
Assert-NotNull "PLAN-0029: POL_MMCSS_RESPONSIVENESS existe en Policy-Engine" $mmcssResp
Assert-Equal "PLAN-0029: POL_MMCSS_RESPONSIVENESS tiene ExpectedValue = 0 (100% Foreground Gaming)" $mmcssResp.ExpectedValue 0

$mmcssNet = $allPols | Where-Object { $_.Id -eq "POL_MMCSS_THROTTLING" }
Assert-NotNull "PLAN-0029: POL_MMCSS_THROTTLING existe en Policy-Engine" $mmcssNet
Assert-Equal "PLAN-0029: POL_MMCSS_THROTTLING tiene ExpectedValue = 4294967295" $mmcssNet.ExpectedValue 4294967295

$ctxMenuContent = Get-Content -Path (Join-Path (Split-Path $PSScriptRoot -Parent) "Modules\Add-OptimizedContextMenus.ps1") -Raw
Assert-True "PLAN-0029: Add-OptimizedContextMenus.ps1 utiliza New-Item para crear claves" (([bool]($ctxMenuContent -match 'New-Item\s+-Path.*-Force')))
Assert-True "PLAN-0029: Add-OptimizedContextMenus.ps1 utiliza Set-ItemProperty para valores" (([bool]($ctxMenuContent -match 'Set-ItemProperty\s+-Path')))
Assert-False "PLAN-0029: Add-OptimizedContextMenus.ps1 no contiene reg.exe add (despojo de comillas erradicado)" (([bool]($ctxMenuContent -match 'reg\.exe\s+add')))
Assert-False "PLAN-0029: Add-OptimizedContextMenus.ps1 no contiene reg.exe delete" (([bool]($ctxMenuContent -match 'reg\.exe\s+delete')))
Assert-True "PLAN-0029: Add-OptimizedContextMenus.ps1 configura CLSID clasico {86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" (([bool]($ctxMenuContent -match '86ca1aa0-34aa-4e8b-a509-50c905bae2a2')))

Assert-True "PLAN-0029: v2 script utiliza Register-ScheduledTask permanente para tareas a demanda" ($v2ScriptContent -match 'Register-ScheduledTask\s+-TaskName')
Assert-False "PLAN-0029: v2 script erradico schtasks efimero /sc ONCE /st 00:00" ($v2ScriptContent -match 'schtasks\s+/create.*/sc\s+ONCE\s+/st\s+00:00\s+/ru\s+["'']SYSTEM["'']\s+/rl\s+HIGHEST')

# PLAN-0031: Validaciones de Erradicacion de SubCommands en Comandos Ejecutables y Cascada Nativa
Assert-True "PLAN-0031: Set-ShellVerb verifica PSBoundParameters para SubCommands" (([bool]($ctxMenuContent -match '\$PSBoundParameters\.ContainsKey\([''"]SubCommands[''"]\)')))
Assert-True "PLAN-0031: Set-ShellVerb auto-sana purgando SubCommands en comandos hoja" (([bool]($ctxMenuContent -match 'Remove-ItemProperty.*SubCommands')))
Assert-True "PLAN-0031: Lanzador de menus contextuales existe en scripts" ([bool](Test-Path (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Aplicar-Hotfix-Menus.cmd") -or (Test-Path (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Modules\Add-OptimizedContextMenus.cmd"))))
Assert-True "PLAN-0031: 01_PowerMax incluye recuperacion/duplicacion automatica de GUID de energia" (([bool]($ctxMenuContent -match 'powercfg\s+-duplicatescheme\s+e9a42b02-d5df-448d-aa00-03f14749eb61')))


# PLAN-0030: Validaciones de Integracion de Modo Oscuro Nativo Multi-Capa
$themeInstall = $allPols | Where-Object { $_.Id -eq "POL_THEME_INSTALL_THEME" }
Assert-NotNull "PLAN-0030: POL_THEME_INSTALL_THEME existe en Policy-Engine" $themeInstall
Assert-Equal "PLAN-0030: POL_THEME_INSTALL_THEME apunta a dark.theme" $themeInstall.ExpectedValue "C:\Windows\resources\Themes\dark.theme"

$themeApps = $allPols | Where-Object { $_.Id -eq "POL_THEME_APPS_DARK" }
Assert-NotNull "PLAN-0030: POL_THEME_APPS_DARK existe en Policy-Engine" $themeApps
Assert-Equal "PLAN-0030: POL_THEME_APPS_DARK tiene ExpectedValue = 0" $themeApps.ExpectedValue 0

$themeSys = $allPols | Where-Object { $_.Id -eq "POL_THEME_SYSTEM_DARK" }
Assert-NotNull "PLAN-0030: POL_THEME_SYSTEM_DARK existe en Policy-Engine" $themeSys
Assert-Equal "PLAN-0030: POL_THEME_SYSTEM_DARK tiene ExpectedValue = 0" $themeSys.ExpectedValue 0

$themeTrans = $allPols | Where-Object { $_.Id -eq "POL_THEME_TRANSPARENCY" }
Assert-NotNull "PLAN-0030: POL_THEME_TRANSPARENCY existe en Policy-Engine" $themeTrans
Assert-Equal "PLAN-0030: POL_THEME_TRANSPARENCY tiene ExpectedValue = 1" $themeTrans.ExpectedValue 1

# Validacion de FirstLogonCommands en autounattend.xml de v2 script
Assert-True "PLAN-0030: v2 script inyecta AppsUseLightTheme en FirstLogonCommands" ($v2ScriptContent -match 'Themes\\Personalize.*AppsUseLightTheme.*0')
Assert-True "PLAN-0030: v2 script inyecta SystemUsesLightTheme en FirstLogonCommands" ($v2ScriptContent -match 'Themes\\Personalize.*SystemUsesLightTheme.*0')
Assert-True "PLAN-0030: v2 script inyecta EnableTransparency en FirstLogonCommands" ($v2ScriptContent -match 'Themes\\Personalize.*EnableTransparency.*1')

# Validacion de SetupComplete.cmd en v2 script
Assert-True "PLAN-0030: SetupComplete.cmd configura InstallTheme dark.theme" ($v2ScriptContent -match 'InstallTheme.*dark\.theme')
Assert-True "PLAN-0030: SetupComplete.cmd configura RunOnce ApplyDarkMode" ($v2ScriptContent -match 'RunOnce.*ApplyDarkMode')

# Validacion de inyeccion en WIM offline SOFTWARE hive
Assert-True "PLAN-0030: v2 script carga SOFTWARE hive offline para dark.theme" ($v2ScriptContent -match 'OfflineSoftware' -and $v2ScriptContent -match 'dark\.theme')

# Validacion de PostInstall-Diagnostics.ps1
$diagContent = Get-Content -Path (Join-Path (Split-Path $PSScriptRoot -Parent) "Modules\PostInstall-Diagnostics.ps1") -Raw
Assert-True "PLAN-0030: PostInstall-Diagnostics.ps1 audita HKCU prioritariamente para temas" ([bool]($diagContent -match 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize'))

# PLAN-0032: Validaciones de Saneamiento Debloat, Deteccion ISO y Desacoplamiento de Toolkit
Assert-True "PLAN-0032: Win11-Debloat-v3-Adaptive.ps1 implementa deteccion multi-capa `$isIsoOptimized" ([bool]($debloatContent -match '\$isIsoOptimized\s*='))
Assert-True "PLAN-0032: Win11-Debloat-v3-Adaptive.ps1 verifica scripts de setup o politicas de nube en preflight" ([bool]($debloatContent -match 'Setup\\Scripts' -and $debloatContent -match 'DisableCloudOptimizedContent'))
Assert-True "PLAN-0032: Win11-Debloat-v3-Adaptive.ps1 verifica apps Win32 instaladas antes de abrir selector" ([bool]($debloatContent -match '\$presentWin32\s*=' -and $debloatContent -match 'Microsoft\.OneDrive'))
Assert-True "PLAN-0032: Win11-Debloat-v3-Adaptive.ps1 filtra servicios activos no deshabilitados antes de abrir selector" ([bool]($debloatContent -match '\$activeServices\s*=' -and $debloatContent -match 'StartType\s+-ne\s+[''"]Disabled[''"]'))
Assert-False "PLAN-0032: Win11-Debloat-v3-Adaptive.ps1 no ejecuta StartComponentCleanup bloqueante en debloat" ([bool]($debloatContent -match 'DISM\.exe\s+/Online\s+/Cleanup-Image\s+/StartComponentCleanup'))
Assert-True "PLAN-0032: Win11-Debloat-v3-Adaptive.ps1 verifica instalacion previa de menus contextuales" ([bool]($debloatContent -match '\$contextAlreadyInstalled\s*=' -and $debloatContent -match 'GamerTools'))
Assert-False "PLAN-0032: Win11-Debloat-v3-Adaptive.ps1 erradico duplicacion de reg.exe add en seccion 15" ([bool]($debloatContent -match 'reg\.exe\s+add.*Directory\\Background\\shell\\GamerTools'))

# PLAN-0034: Validaciones de Optimizaciones Oficiales NTFS, Kernel Scheduler y Red (ECN)
$polFs83 = $allPols | Where-Object { $_.Id -eq "POL_FS_DISABLE_8DOT3" }
Assert-NotNull "PLAN-0034: POL_FS_DISABLE_8DOT3 existe en Policy-Engine" $polFs83
Assert-Equal "PLAN-0034: POL_FS_DISABLE_8DOT3 tiene ExpectedValue = 1" $polFs83.ExpectedValue 1

$polFsMem = $allPols | Where-Object { $_.Id -eq "POL_FS_MEMORY_USAGE" }
Assert-NotNull "PLAN-0034: POL_FS_MEMORY_USAGE existe en Policy-Engine" $polFsMem
Assert-Equal "PLAN-0034: POL_FS_MEMORY_USAGE tiene ExpectedValue = 2" $polFsMem.ExpectedValue 2

$polFsLong = $allPols | Where-Object { $_.Id -eq "POL_FS_LONG_PATHS" }
Assert-NotNull "PLAN-0034: POL_FS_LONG_PATHS existe en Policy-Engine" $polFsLong
Assert-Equal "PLAN-0034: POL_FS_LONG_PATHS tiene ExpectedValue = 1" $polFsLong.ExpectedValue 1

$polSchedPrio = $allPols | Where-Object { $_.Id -eq "POL_SCHED_WIN32_PRIORITY" }
Assert-NotNull "PLAN-0034: POL_SCHED_WIN32_PRIORITY existe en Policy-Engine" $polSchedPrio
Assert-Equal "PLAN-0034: POL_SCHED_WIN32_PRIORITY tiene ExpectedValue = 38 (0x26)" $polSchedPrio.ExpectedValue 38

$polMmcssLazy = $allPols | Where-Object { $_.Id -eq "POL_MMCSS_NO_LAZY_MODE" }
Assert-NotNull "PLAN-0034: POL_MMCSS_NO_LAZY_MODE existe en Policy-Engine" $polMmcssLazy
Assert-Equal "PLAN-0034: POL_MMCSS_NO_LAZY_MODE tiene ExpectedValue = 1" $polMmcssLazy.ExpectedValue 1

Assert-True "PLAN-0034: SetupComplete.cmd contiene comando netsh ecncapability=enabled" ($v2ScriptContent -match 'ecncapability=enabled')
Assert-True "PLAN-0034: SetupComplete.cmd inyecta NtfsDisable8dot3NameCreation" ($v2ScriptContent -match 'NtfsDisable8dot3NameCreation')
Assert-True "PLAN-0034: SetupComplete.cmd inyecta NtfsMemoryUsage" ($v2ScriptContent -match 'NtfsMemoryUsage')
Assert-True "PLAN-0034: SetupComplete.cmd inyecta Win32PrioritySeparation" ($v2ScriptContent -match 'Win32PrioritySeparation')

Assert-True "PLAN-0034: v2 script inyecta NoLazyMode en SOFTWARE hive offline" ($v2ScriptContent -match 'OfflineSoftware' -and $v2ScriptContent -match 'NoLazyMode')
Assert-True "PLAN-0034: v2 script inyecta NtfsMemoryUsage y Win32PrioritySeparation en SYSTEM hive offline" ($v2ScriptContent -match 'OfflineSystem' -and $v2ScriptContent -match 'NtfsMemoryUsage')

$netOptContent = Get-Content -Path (Join-Path (Split-Path $PSScriptRoot -Parent) "Modules\Win11-Network-Diagnostics-Optimizer.ps1") -Raw
Assert-True "PLAN-0034: Win11-Network-Diagnostics-Optimizer.ps1 carga motor de directivas RomanOS_NetworkPolicies" (([bool]($netOptContent -match 'RomanOS_NetworkPolicies' -or $netOptContent -match 'Policy-Engine\.ps1')))
$polEngineRaw = Get-Content -Path $policyEnginePath -Raw
Assert-True "PLAN-0034: Policy-Engine.ps1 define directiva de mitigacion ECN NET_TCP_ECN_CAPABILITY" (([bool]($polEngineRaw -match 'NET_TCP_ECN_CAPABILITY' -and $polEngineRaw -match 'ecncapability=enabled')))

$diagContentAfter = Get-Content -Path (Join-Path (Split-Path $PSScriptRoot -Parent) "Modules\PostInstall-Diagnostics.ps1") -Raw
Assert-True "PLAN-0034: PostInstall-Diagnostics.ps1 audita directivas dinamicamente via Get-RomanOSPolicies" (([bool]($diagContentAfter -match 'Get-RomanOSPolicies')))
Assert-True "PLAN-0034: PostInstall-Diagnostics.ps1 valida directivas con Test-RomanOSPolicy" (([bool]($diagContentAfter -match 'Test-RomanOSPolicy')))
Assert-True "PLAN-0034: PostInstall-Diagnostics.ps1 audita ECN Capability" (([bool]($diagContentAfter -match 'ECN Capability')))

# PLAN-0033: Desacoplamiento del Módulo de Navegadores
$optimizeWebBrowsers = Join-Path (Split-Path $PSScriptRoot -Parent) "Modules\Optimize-WebBrowsers.ps1"
Assert-FileExists "PLAN-0033: Optimize-WebBrowsers.ps1 existe en disco" $optimizeWebBrowsers
Assert-False "PLAN-0033: Win11-Debloat-v3-Adaptive.ps1 ya no contiene Invoke-BrowserDebloat" ($debloatContent -match 'function Invoke-BrowserDebloat')
Assert-False "PLAN-0033: Win11-Debloat-v3-Adaptive.ps1 ya no contiene parametro BrowsersOnly" ($debloatContent -match '\[switch\]\$BrowsersOnly')
Assert-True "PLAN-0033: Win11-Debloat-v3-Adaptive.ps1 invoca a Optimize-WebBrowsers.ps1 en Seccion 16" ($debloatContent -match 'Optimize-WebBrowsers\.ps1')
Assert-True "PLAN-0033: romanOS-Toolkit.ps1 invoca a Optimize-WebBrowsers.ps1" ($toolkitContent -match 'Optimize-WebBrowsers\.ps1')

# PLAN-0049: AutoLogon sin Contraseña y Credenciales Efímeras en OOBE
Write-HarnessHeader2 "PLAN-0049: Validacion de Arquitectura de AutoLogon sin Contrasena en OOBE"
$pols49 = Get-RomanOSPolicies -Profile '1'
$blankPwdPol = $pols49 | Where-Object { $_.Id -eq 'POL_AUTH_LIMIT_BLANK_PASSWORD' }
Assert-NotNull "PLAN-0049: Politica POL_AUTH_LIMIT_BLANK_PASSWORD registrada en Policy-Engine" $blankPwdPol
Assert-Equal "PLAN-0049/0055: Politica LimitBlankPasswordUse valor esperado es 1 (Consola Local Segura)" $blankPwdPol.ExpectedValue 1
Assert-Equal "PLAN-0049: Politica LimitBlankPasswordUse apunta a Lsa" $blankPwdPol.RegistryKey "HKLM\SYSTEM\CurrentControlSet\Control\Lsa"

$pwdLessPol = $pols49 | Where-Object { $_.Id -eq 'POL_PASSWORDLESS_BUILD' }
Assert-NotNull "PLAN-0049: Politica POL_PASSWORDLESS_BUILD registrada en Policy-Engine" $pwdLessPol
Assert-Equal "PLAN-0049: Politica DevicePasswordLessBuildVersion valor esperado es 0" $pwdLessPol.ExpectedValue 0

$unattendExp49 = Export-RomanOSUnattendCommands -Profile '1' -StartOrder 2
Assert-True "PLAN-0049: Export-RomanOSUnattendCommands incluye directiva LimitBlankPasswordUse" ([bool]($unattendExp49.XmlContent -match 'LimitBlankPasswordUse'))
Assert-True "PLAN-0049: Export-RomanOSUnattendCommands incluye directiva DevicePasswordLessBuildVersion" ([bool]($unattendExp49.XmlContent -match 'DevicePasswordLessBuildVersion'))

# Validacion de logica en New-OptimizedWindowsISO-v2.ps1
Assert-True "PLAN-0049: v2 script implementa generacion de credencial efimera para passwordless" ([bool]($v2ScriptContent -match 'RomanOS#Setup_'))
Assert-True "PLAN-0049: v2 script purga contrasena en FirstLogonCommands via net user" ([bool]($v2ScriptContent -match 'net user "\$finalLocalUser" ""'))
Assert-True "PLAN-0049: v2 script elimina DefaultPassword en FirstLogonCommands" ([bool]($v2ScriptContent -match 'reg delete "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon" /v DefaultPassword /f'))
Assert-True "PLAN-0049: v2 script resetea AutoAdminLogon a 0 en FirstLogonCommands" ([bool]($v2ScriptContent -match 'reg add "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon" /v AutoAdminLogon /t REG_SZ /d 0 /f'))
Assert-False "PLAN-0049: v2 script elimino el falso AutoAdminLogon=1 tardio de FirstLogonCommands" ([bool]($v2ScriptContent -match 'Force AutoAdminLogon in Winlogon for passwordless account'))
Assert-True "PLAN-0049: v2 script utiliza finalLocalUser unificado en AutoLogon y LocalAccount" ([bool]($v2ScriptContent -match '<Username>\$finalLocalUser</Username>' -and $v2ScriptContent -match '<Name>\$finalLocalUser</Name>'))

# PLAN-0050: Integracion Total de Modulos del Toolkit Maestro, Controladores y Scripts Faltantes en la ISO
Write-HarnessHeader2 "PLAN-0050: Validacion de Inyeccion Total de Modulos, Drivers y Resiliencia del Toolkit"

# 1. Validar inyeccion de Drivers en OEM y WIM dentro de New-OptimizedWindowsISO-v2.ps1
Assert-True "PLAN-0050: Builder inyecta carpeta Drivers en `$OEMScriptsDir" ([bool]($v2ScriptContent -match 'destDriversDir\s*=\s*Join-Path \$OEMScriptsDir "Drivers"'))
Assert-True "PLAN-0050: Builder inyecta suite de Drivers en WIM offline" ([bool]($v2ScriptContent -match 'wimDriversDest\s*=\s*Join-Path \$wimScriptsDir "Drivers"'))

# 2. Validar inyeccion de modulos complementarios en OEM y WIM
Assert-True "PLAN-0050: Builder inyecta Optimize-WebBrowsers.ps1 en `$OEM`$" ([bool]($v2ScriptContent -match 'Join-Path \$OEMScriptsDir "Optimize-WebBrowsers\.ps1"'))
Assert-True "PLAN-0050: Builder inyecta Optimize-WebBrowsers.ps1 en WIM" ([bool]($v2ScriptContent -match 'Join-Path \$wimScriptsDir "Optimize-WebBrowsers\.ps1"'))
Assert-True "PLAN-0050: Builder inyecta Migrar-Usuario-W11.ps1 en `$OEM`$" ([bool]($v2ScriptContent -match 'Join-Path \$OEMScriptsDir "Migrar-Usuario-W11\.ps1"'))
Assert-True "PLAN-0050: Builder inyecta Migrar-Usuario-W11.ps1 en WIM" ([bool]($v2ScriptContent -match 'Join-Path \$wimScriptsDir "Migrar-Usuario-W11\.ps1"'))
Assert-True "PLAN-0050: Builder inyecta Get-WindowsUpdates.ps1 en `$OEM`$" ([bool]($v2ScriptContent -match 'Join-Path \$OEMScriptsDir "Get-WindowsUpdates\.ps1"'))
Assert-True "PLAN-0050: Builder inyecta Get-WindowsUpdates.ps1 en WIM" ([bool]($v2ScriptContent -match 'Join-Path \$wimScriptsDir "Get-WindowsUpdates\.ps1"'))

# 3. Validar garantia de submodulos para soporte del Toolkit
Assert-True "PLAN-0050: Builder garantiza submodulos de la suite en `$OEM`$" ([bool]($v2ScriptContent -match 'Garantizar Presencia de Submódulos del Toolkit Maestro en \$OEM\$' -or $v2ScriptContent -match 'suiteSubmodules'))
Assert-True "PLAN-0050: Builder garantiza submodulos de la suite en WIM" ([bool]($v2ScriptContent -match 'Inyectar submódulos de la suite para soporte del Toolkit en WIM montado' -or $v2ScriptContent -match 'wimSubmDest'))

# 4. Validar resiliencia y resolucion en romanOS-Toolkit.ps1
$toolkitFreshContent = Get-Content -Path (Join-Path (Split-Path $PSScriptRoot -Parent) "Modules\romanOS-Toolkit.ps1") -Raw
Assert-True "PLAN-0050: romanOS-Toolkit.ps1 expande searchDirs a Modules y Builder" ([bool]($toolkitFreshContent -match 'repoScriptsRoot' -and $toolkitFreshContent -match 'Builder'))
Assert-True "PLAN-0050: romanOS-Toolkit.ps1 usa Resolve-ToolScript en acciones rapidas DNS" ([bool]($toolkitFreshContent -match 'Resolve-ToolScript "Win11-Network-Diagnostics-Optimizer\.ps1"'))
Assert-True "PLAN-0050: romanOS-Toolkit.ps1 usa Resolve-ToolScript en acciones rapidas Mantenimiento" ([bool]($toolkitFreshContent -match 'Resolve-ToolScript "Invoke-WindowsMaintenance\.ps1"'))

# 5. Validar existencia fisica de los scripts del ecosistema en el repositorio
$driversDirDisk = Join-Path (Split-Path $PSScriptRoot -Parent) "Drivers"
$modulesDirDisk = Join-Path (Split-Path $PSScriptRoot -Parent) "Modules"
$builderDirDisk = Join-Path (Split-Path $PSScriptRoot -Parent) "Builder"

Assert-FileExists "PLAN-0050: Clean-DriverStore.ps1 existe en Drivers/" (Join-Path $driversDirDisk "Clean-DriverStore.ps1")
Assert-FileExists "PLAN-0050: Backup-HardwareDrivers.ps1 existe en Drivers/" (Join-Path $driversDirDisk "Backup-HardwareDrivers.ps1")
Assert-FileExists "PLAN-0050: Get-CriticalDrivers.ps1 existe en Drivers/" (Join-Path $driversDirDisk "Get-CriticalDrivers.ps1")
Assert-FileExists "PLAN-0050: Optimize-WebBrowsers.ps1 existe en Modules/" (Join-Path $modulesDirDisk "Optimize-WebBrowsers.ps1")
Assert-FileExists "PLAN-0050: Migrar-Usuario-W11.ps1 existe en Modules/" (Join-Path $modulesDirDisk "Migrar-Usuario-W11.ps1")
Assert-FileExists "PLAN-0050: Get-WindowsUpdates.ps1 existe en Builder/" (Join-Path $builderDirDisk "Get-WindowsUpdates.ps1")

# --- PLAN-0053: PREVENCION DE WIM DISCARD Y RESOLUCION CANONICA DE UPDATES Y DRIVERS ---
Write-HarnessHeader2 "PLAN-0053: Prevencion de WIM Discard y Resolucion Canonica de Updates y Drivers"
$v2FreshContent = Get-Content $TargetScript -Raw

Assert-True "PLAN-0053: Builder define e inicializa wimModulesDest" ([bool]($v2FreshContent -match '\$wimModulesDest\s*=\s*Join-Path \$wimScriptsDir "Modules"'))
Assert-True "PLAN-0053: Builder crea wimModulesDest con New-Item" ([bool]($v2FreshContent -match 'New-Item -ItemType Directory -Path \$wimModulesDest'))
Assert-True "PLAN-0053: Resolucion de Updates en Paso 5 comprueba paquetes reales" ([bool]($v2FreshContent -match 'Get-ChildItem -Path \$resolvedUpdatesDir -Include \*\.msu, \*\.cab'))
Assert-True "PLAN-0053: Resolucion de Drivers en Paso 5 comprueba drivers reales" ([bool]($v2FreshContent -match 'Get-ChildItem -Path \$resolvedDriversDir -Include \*\.inf'))
Assert-True "PLAN-0053: Submodulos de la suite inyectan en wimModulesDest" ([bool]($v2FreshContent -match 'wimSubmModDest\s*=\s*Join-Path \$wimModulesDest \$subm\.Name'))

# --- PLAN-0054: ECOSISTEMA UNIFICADO DE OBSERVABILIDAD Y DIAGNOSTICO FORENSE ---
Write-HarnessHeader2 "PLAN-0054: Observabilidad y Diagnostico Forense"
if ($UIEngine -and (Test-Path $UIEngine)) {
    . $UIEngine
}
$uiEngineContent = if ($UIEngine) { Get-Content $UIEngine -Raw -Encoding UTF8 -ErrorAction SilentlyContinue } else { "" }

Assert-True "PLAN-0054: UI-Engine exporta Write-ForensicException" ([bool]($uiEngineContent -match 'function\s+Write-ForensicException'))
Assert-True "PLAN-0054: UI-Engine exporta Assert-ResourceCommitment" ([bool]($uiEngineContent -match 'function\s+Assert-ResourceCommitment'))
Assert-True "PLAN-0054: UI-Engine declara telemetria global RomanOS_LogErrors" ([bool]($uiEngineContent -match '\$global:RomanOS_LogErrors'))
Assert-True "PLAN-0054: UI-Engine declara telemetria global RomanOS_LogWarns" ([bool]($uiEngineContent -match '\$global:RomanOS_LogWarns'))
Assert-True "PLAN-0054: UI-Engine declara telemetria global RomanOS_LogFile" ([bool]($uiEngineContent -match '\$global:RomanOS_LogFile'))

# Prueba funcional sintética de Write-ForensicException
$forensicTestResult = $null
try {
    $nullObj = $null
    $nullObj.NonExistentMethod()
} catch {
    $forensicTestResult = Write-ForensicException -Record $_ -Context "TestHarness" -SuggestedAction "Accion de prueba"
}
Assert-NotNull "PLAN-0054: Write-ForensicException retorna objeto de diagnostico estructurado" $forensicTestResult
Assert-True "PLAN-0054: Write-ForensicException captura numero de linea (>0)" ([bool]($forensicTestResult.LineNumber -gt 0))
Assert-True "PLAN-0054: Write-ForensicException captura la linea de codigo exacta" ([bool]($forensicTestResult.LineCode -match 'NonExistentMethod'))
Assert-True "PLAN-0054: Write-ForensicException registra mensaje en acumulador global" ([bool]($global:RomanOS_LogErrors -and $global:RomanOS_LogErrors.Count -gt 0))

# Prueba funcional sintética de Assert-ResourceCommitment
$assertPass = Assert-ResourceCommitment -ResourceName "TestRec" -PreflightFound $true -ExecutionApplied $true
Assert-True "PLAN-0054: Assert-ResourceCommitment valida ejecucion correcta" $assertPass

$assertFail = Assert-ResourceCommitment -ResourceName "TestRecDesvio" -PreflightFound $true -ExecutionApplied $false -FailureReason "Simulacion de omision"
Assert-False "PLAN-0054: Assert-ResourceCommitment detecta desvio cuando preflight es true y execution es false" $assertFail

# Verificación en el Builder New-OptimizedWindowsISO-v2.ps1
Assert-True "PLAN-0054: Builder New-OptimizedWindowsISO-v2 invoca Write-ForensicException en WIM servicing" ([bool]($v2FreshContent -match 'Write-ForensicException\s+-Record\s+\$_.*Inyeccion en WIM'))
Assert-True "PLAN-0054: Builder New-OptimizedWindowsISO-v2 invoca Assert-ResourceCommitment en Updates" ([bool]($v2FreshContent -match 'Assert-ResourceCommitment\s+-ResourceName\s+"Windows Updates'))
Assert-True "PLAN-0054: Builder New-OptimizedWindowsISO-v2 invoca Assert-ResourceCommitment en Drivers" ([bool]($v2FreshContent -match 'Assert-ResourceCommitment\s+-ResourceName\s+"Controladores Hardware'))
Assert-True "PLAN-0054: Builder sincroniza variables globales de telemetria en Initialize-Log" ([bool]($v2FreshContent -match '\$global:RomanOS_LogFile\s*=\s*\$script:LogFile'))

# --- PLAN-0055: NEUTRALIZACION QUIRURGICA DE SEARCH HIGHLIGHTS Y BING (ZERO-OVERHEAD WEBVIEW2) ---
Write-HarnessHeader2 "PLAN-0055: Neutralizacion Quirurgica de Search Highlights y WebView2"
$pols55 = Get-RomanOSPolicies -Profile '1'
$dynamicWsbPol = $pols55 | Where-Object { $_.Id -eq 'POL_SEARCH_DYNAMIC_CONTENT_WSB' }
Assert-NotNull "PLAN-0055: Politica POL_SEARCH_DYNAMIC_CONTENT_WSB registrada en Policy-Engine" $dynamicWsbPol
Assert-Equal "PLAN-0055: Politica EnableDynamicContentInWSB valor esperado es 0" $dynamicWsbPol.ExpectedValue 0
Assert-Equal "PLAN-0055: Politica EnableDynamicContentInWSB apunta a Windows Search" $dynamicWsbPol.RegistryKey "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search"

$meteredPol = $pols55 | Where-Object { $_.Id -eq 'POL_SEARCH_CONNECTED_METERED' }
Assert-NotNull "PLAN-0055: Politica POL_SEARCH_CONNECTED_METERED registrada en Policy-Engine" $meteredPol
Assert-Equal "PLAN-0055: Politica ConnectedSearchUseWebOverMeteredConnections valor esperado es 0" $meteredPol.ExpectedValue 0

# PLAN-0055 / PLAN-0115: POL_SEARCH_CORTANA_ALLOW marcada como obsoleta en Win11 y excluida de perfiles activos
$cortanaPol = $global:RomanOS_Policies | Where-Object { $_.Id -eq 'POL_SEARCH_CORTANA_ALLOW' }
Assert-NotNull "PLAN-0055: Politica POL_SEARCH_CORTANA_ALLOW registrada en Policy-Engine" $cortanaPol
Assert-True "PLAN-0115: Politica AllowCortana marcada como obsoleta (IsDeprecated = `$true)" ([bool]$cortanaPol.IsDeprecated)
Assert-True "PLAN-0115: Politica AllowCortana excluida de perfiles activos en Windows 11" ($cortanaPol.Profiles.Count -eq 0)

$unattendExp55 = Export-RomanOSUnattendCommands -Profile '1' -StartOrder 2
Assert-True "PLAN-0055: Export-RomanOSUnattendCommands incluye directiva EnableDynamicContentInWSB" ([bool]($unattendExp55.XmlContent -match 'EnableDynamicContentInWSB'))

# Validacion en el Builder New-OptimizedWindowsISO-v2.ps1
$v2FreshContent55 = Get-Content $TargetScript -Raw
Assert-True "PLAN-0055: Builder inyecta IsDynamicSearchBoxEnabled en NTUSER.DAT" ([bool]($v2FreshContent55 -match 'IsDynamicSearchBoxEnabled'))
Assert-True "PLAN-0055: Builder inyecta BingSearchEnabled en NTUSER.DAT" ([bool]($v2FreshContent55 -match 'BingSearchEnabled'))
Assert-True "PLAN-0055: Builder inyecta EnableDynamicContentInWSB en SOFTWARE hive" ([bool]($v2FreshContent55 -match 'HKLM\\OfflineSoftware\\Policies\\Microsoft\\Windows\\Windows Search' -and $v2FreshContent55 -match 'EnableDynamicContentInWSB'))
Assert-True "PLAN-0055: Builder configura LimitBlankPasswordUse en 1 en autounattend" ([bool]($v2FreshContent55 -match 'LimitBlankPasswordUse\s+/t\s+REG_DWORD\s+/d\s+1\s+/f'))

# --- PLAN-0056: AUDITORIA FORENSE DE HUELLA EN REPOSO E INTEGRACION TOOLKIT/ISO ---
Write-HarnessHeader2 "PLAN-0056: Auditoria Forense de Huella en Reposo (Footprint Audit)"
$auditScriptCandidate = Join-Path $modulesDir "Audit-FreshInstallFootprint.ps1"
Assert-True "PLAN-0056: Audit-FreshInstallFootprint.ps1 existe en Modules/" (Test-Path $auditScriptCandidate)

$auditBytes = [System.IO.File]::ReadAllBytes($auditScriptCandidate)
$auditHasBom = ($auditBytes.Length -ge 3 -and $auditBytes[0] -eq 0xEF -and $auditBytes[1] -eq 0xBB -and $auditBytes[2] -eq 0xBF)
Assert-True "PLAN-0056: Audit-FreshInstallFootprint.ps1 tiene codificacion UTF-8 con BOM" $auditHasBom

$auditTokens = $null; $auditErrs = $null
$auditAst = [System.Management.Automation.Language.Parser]::ParseFile($auditScriptCandidate, [ref]$auditTokens, [ref]$auditErrs)
Assert-Equal "PLAN-0056: Audit-FreshInstallFootprint.ps1 no tiene errores de sintaxis AST" $auditErrs.Count 0

# Validacion en romanOS-Toolkit.ps1
$toolkitScript = Join-Path $modulesDir "romanOS-Toolkit.ps1"
$toolkitContent56 = Get-Content $toolkitScript -Raw
Assert-True "PLAN-0056: romanOS-Toolkit.ps1 acepta parámetro FootprintAudit en ValidateSet" ([bool]($toolkitContent56 -match 'FootprintAudit'))
Assert-True "PLAN-0056: romanOS-Toolkit.ps1 declara funcion Invoke-FootprintAuditModule" ([bool]($toolkitContent56 -match 'function Invoke-FootprintAuditModule'))
Assert-True "PLAN-0056: romanOS-Toolkit.ps1 incluye FootprintAudit en el menu interactivo" ([bool]($toolkitContent56 -match 'Auditoria Forense de Huella en Reposo'))

# Validacion en New-OptimizedWindowsISO-v2.ps1
$v2FreshContent56 = Get-Content $TargetScript -Raw
Assert-True "PLAN-0056: Builder inyecta Audit-FreshInstallFootprint.ps1 en `$OEM`$" ([bool]($v2FreshContent56 -match 'Copy-Item -Path \$auditFootprintSrc -Destination \(Join-Path \$OEMScriptsDir "Audit-FreshInstallFootprint\.ps1"\)'))
Assert-True "PLAN-0056: Builder inyecta Audit-FreshInstallFootprint.ps1 en WIM offline" ([bool]($v2FreshContent56 -match 'Copy-Item -Path \$auditFootprintSrc -Destination \(Join-Path \$wimModulesDest "Audit-FreshInstallFootprint\.ps1"\)'))

# =============================================================================
# PLAN-0057: NEUTRALIZACION DE WIDGETS, TASKBAR Y ZERO-OVERHEAD WEBVIEW2
# =============================================================================
Write-HarnessHeader2 "PLAN-0057: Neutralizacion de Widgets, Taskbar y Zero-Overhead WebView2"

# 1. Validar inyeccion de TaskbarMn y ShowCopilotButton en NTUSER.DAT (TaskbarDa suprimido para evitar bloqueo kernel UCPD PLAN-0021)
$v2FreshContent57 = Get-Content $TargetScript -Raw
Assert-True "PLAN-0057: Builder suprime TaskbarDa en NTUSER.DAT evitando bloqueo de kernel UCPD" (-not ($v2FreshContent57 -match "Name\s*=\s*`"TaskbarDa`""))
Assert-True "PLAN-0057: Builder inyecta TaskbarMn = 0 en NTUSER.DAT" ([bool]($v2FreshContent57 -match "Name\s*=\s*`"TaskbarMn`""))
Assert-True "PLAN-0057: Builder inyecta ShowCopilotButton = 0 en NTUSER.DAT" ([bool]($v2FreshContent57 -match "Name\s*=\s*`"ShowCopilotButton`""))

# 2. Validar inyeccion de AllowWidgets y ChatIcon en SOFTWARE hive del Builder (AllowNewsAndInterests purgado en Win11 por PLAN-0115)
Assert-True "PLAN-0057: Builder inyecta AllowWidgets = 0 en SOFTWARE hive" ([bool]($v2FreshContent57 -match "Name\s*=\s*`"AllowWidgets`""))
Assert-True "PLAN-0057: Builder inyecta ChatIcon = 3 en SOFTWARE hive" ([bool]($v2FreshContent57 -match "Name\s*=\s*`"ChatIcon`""))
Assert-True "PLAN-0115: Builder inyecta AlwaysAutoRebootAtScheduledTime en SOFTWARE hive" ([bool]($v2FreshContent57 -match "Name\s*=\s*`"AlwaysAutoRebootAtScheduledTime`""))
Assert-True "PLAN-0115: Builder inyecta AUPowerManagement en SOFTWARE hive" ([bool]($v2FreshContent57 -match "Name\s*=\s*`"AUPowerManagement`""))
Assert-True "PLAN-0115: Builder inyecta SetAutoRestartNotificationConfig en SOFTWARE hive" ([bool]($v2FreshContent57 -match "Name\s*=\s*`"SetAutoRestartNotificationConfig`""))
Assert-True "PLAN-0115: Builder inyecta SetAutoRestartRequiredNotificationDismissal en SOFTWARE hive" ([bool]($v2FreshContent57 -match "Name\s*=\s*`"SetAutoRestartRequiredNotificationDismissal`""))
Assert-True "PLAN-0115: Builder inyecta SetEngagedRestartTransitionSchedule en SOFTWARE hive" ([bool]($v2FreshContent57 -match "Name\s*=\s*`"SetEngagedRestartTransitionSchedule`""))

# 3. Validar registro de POL_CHAT_ICON en Policy-Engine.ps1
$policyEnginePath57 = Join-Path (Split-Path $PSScriptRoot -Parent) "Core\Policy-Engine.ps1"
$peContent57 = Get-Content $policyEnginePath57 -Raw
Assert-True "PLAN-0057: Policy-Engine registra directiva POL_CHAT_ICON" ([bool]($peContent57 -match 'Id\s*=\s*"POL_CHAT_ICON"'))

# 4. Validar sintaxis y formato limpio en Audit-FreshInstallFootprint.ps1
$auditFootprintPath57 = Join-Path $modulesDir "Audit-FreshInstallFootprint.ps1"
$auditContent57 = Get-Content $auditFootprintPath57 -Raw
Assert-False "PLAN-0057: Audit-FreshInstallFootprint no contiene artefactos rotos de interpolacion" ([bool]($auditContent57 -match '\$\(System\.Collections\.Hashtable'))
Assert-True "PLAN-0057: Audit-FreshInstallFootprint audita AllowWidgets (GPO)" ([bool]($auditContent57 -match 'AllowWidgets \(GPO\)'))
Assert-True "PLAN-0057: Audit-FreshInstallFootprint incluye diagnostico CIM de WebView2" ([bool]($auditContent57 -match 'Get-CimInstance Win32_Process -Filter "Name = ''msedgewebview2\.exe''"'))

# =============================================================================
# PLAN-0058: OPTIMIZACION DE SEARCHHOST, WEBVIEW2 Y WORKING SET TRIM (PSAPI)
# =============================================================================
Write-HarnessHeader2 "PLAN-0058: Optimizacion de SearchHost, WebView2 y Working Set Trim"

# 1. Validar existencia y codificacion UTF-8 con BOM de Optimize-ProcessMemory.ps1 y .cmd
$memTrimScriptCandidate = Join-Path $modulesDir "Optimize-ProcessMemory.ps1"
$memTrimCmdCandidate    = Join-Path $modulesDir "Optimize-ProcessMemory.cmd"
Assert-True "PLAN-0058: Optimize-ProcessMemory.ps1 existe en Modules/" (Test-Path $memTrimScriptCandidate)
Assert-True "PLAN-0058: Optimize-ProcessMemory.cmd existe en Modules/" (Test-Path $memTrimCmdCandidate)

$memTrimBytes = [System.IO.File]::ReadAllBytes($memTrimScriptCandidate)
$memTrimHasBom = ($memTrimBytes.Length -ge 3 -and $memTrimBytes[0] -eq 0xEF -and $memTrimBytes[1] -eq 0xBB -and $memTrimBytes[2] -eq 0xBF)
Assert-True "PLAN-0058: Optimize-ProcessMemory.ps1 tiene codificacion UTF-8 con BOM" $memTrimHasBom

$memTrimTokens = $null; $memTrimErrs = $null
$memTrimAst = [System.Management.Automation.Language.Parser]::ParseFile($memTrimScriptCandidate, [ref]$memTrimTokens, [ref]$memTrimErrs)
Assert-Equal "PLAN-0058: Optimize-ProcessMemory.ps1 no tiene errores de sintaxis AST" $memTrimErrs.Count 0

# 2. Validar registro de POL_SEARCH_ALLOW_CLOUD y POL_SEARCH_ALLOW_LOCATION en Policy-Engine.ps1
$policyEnginePath58 = Join-Path (Split-Path $PSScriptRoot -Parent) "Core\Policy-Engine.ps1"
$peContent58 = Get-Content $policyEnginePath58 -Raw
Assert-True "PLAN-0058: Policy-Engine registra directiva POL_SEARCH_ALLOW_CLOUD" ([bool]($peContent58 -match 'Id\s*=\s*"POL_SEARCH_ALLOW_CLOUD"'))
Assert-True "PLAN-0058: Policy-Engine registra directiva POL_SEARCH_ALLOW_LOCATION" ([bool]($peContent58 -match 'Id\s*=\s*"POL_SEARCH_ALLOW_LOCATION"'))

# 3. Validar integracion en romanOS-Toolkit.ps1
$toolkitScript58 = Join-Path $modulesDir "romanOS-Toolkit.ps1"
$toolkitContent58 = Get-Content $toolkitScript58 -Raw
Assert-True "PLAN-0058: romanOS-Toolkit.ps1 acepta parametro MemoryTrim en ValidateSet" ([bool]($toolkitContent58 -match 'MemoryTrim'))
Assert-True "PLAN-0058: romanOS-Toolkit.ps1 declara funcion Invoke-MemoryTrimModule" ([bool]($toolkitContent58 -match 'function Invoke-MemoryTrimModule'))
Assert-True "PLAN-0058: romanOS-Toolkit.ps1 incluye MemoryTrim en el menu de acciones rapidas" ([bool]($toolkitContent58 -match 'Poda Quirurgica de Memoria RAM en Reposo'))

# 4. Validar inyeccion en el Builder New-OptimizedWindowsISO-v2.ps1
$v2FreshContent58 = Get-Content $TargetScript -Raw
Assert-True "PLAN-0058: Builder inyecta Optimize-ProcessMemory en `$OEM`$" ([bool]($v2FreshContent58 -match 'Optimize-ProcessMemory\.ps1"\) -Force'))
Assert-True "PLAN-0058: Builder inyecta Optimize-ProcessMemory en WIM offline" ([bool]($v2FreshContent58 -match 'wimModulesDest "Optimize-ProcessMemory\.ps1"\) -Force'))
Assert-True "PLAN-0058: Builder configura llamada retardada de poda en FirstLogonCommands" ([bool]($v2FreshContent58 -match 'Optimize-ProcessMemory\.ps1.*-Quiet -Unattended'))

# 5. Validar clasificacion de Search UI en Audit-FreshInstallFootprint.ps1
$auditFootprintPath58 = Join-Path $modulesDir "Audit-FreshInstallFootprint.ps1"
$auditContent58 = Get-Content $auditFootprintPath58 -Raw
Assert-True "PLAN-0058: Audit-FreshInstallFootprint diferencia instancias de WebView2 hijas de SearchHost" ([bool]($auditContent58 -match 'SEARCH UI'))

# =============================================================================
# PLAN-0059: WINDOWS UPDATE ON-DEMAND PARA PERFILES GAMING Y HARDCORE
# =============================================================================
Write-HarnessHeader2 "PLAN-0059: Windows Update On-Demand para Perfiles Gaming y Hardcore"

# 1. Validar registro de politicas AU en Policy-Engine.ps1
$policyEnginePath59 = Join-Path (Split-Path $PSScriptRoot -Parent) "Core\Policy-Engine.ps1"
$peContent59 = Get-Content $policyEnginePath59 -Raw
Assert-True "PLAN-0059: Policy-Engine registra directiva POL_WU_NO_AUTO_UPDATE" ([bool]($peContent59 -match 'Id\s*=\s*"POL_WU_NO_AUTO_UPDATE"'))
Assert-True "PLAN-0059: Policy-Engine registra directiva POL_WU_AU_OPTIONS" ([bool]($peContent59 -match 'Id\s*=\s*"POL_WU_AU_OPTIONS"'))
Assert-True "PLAN-0059: Policy-Engine registra directiva POL_WU_NO_AUTO_REBOOT" ([bool]($peContent59 -match 'Id\s*=\s*"POL_WU_NO_AUTO_REBOOT"'))

# 2. Validar perfiles asignados en Policy-Engine
$pols59 = Get-RomanOSPolicies
$polWuNoAuto = $pols59 | Where-Object { $_.Id -eq "POL_WU_NO_AUTO_UPDATE" }
Assert-NotNull "PLAN-0059: Objeto POL_WU_NO_AUTO_UPDATE obtenido de Policy-Engine" $polWuNoAuto
Assert-True "PLAN-0059: POL_WU_NO_AUTO_UPDATE activo en Perfil 2 (Gaming)" ($polWuNoAuto.Profiles -contains 2)
Assert-True "PLAN-0059: POL_WU_NO_AUTO_UPDATE activo en Perfil 3 (Hardcore)" ($polWuNoAuto.Profiles -contains 3)
Assert-False "PLAN-0059: POL_WU_NO_AUTO_UPDATE inactivo en Perfil 1 (Conservador)" ($polWuNoAuto.Profiles -contains 1)
Assert-Equal "PLAN-0059: POL_WU_NO_AUTO_UPDATE ExpectedValue es 1" $polWuNoAuto.ExpectedValue 1

# 3. Validar exportacion semantica de unattend por perfil
$unattendP1 = Export-RomanOSUnattendCommands -Profile '1' -StartOrder 2
$unattendP2 = Export-RomanOSUnattendCommands -Profile '2' -StartOrder 2
Assert-False "PLAN-0059: Perfil 1 Unattend no incluye NoAutoUpdate" ([bool]($unattendP1.XmlContent -match 'NoAutoUpdate'))
Assert-True "PLAN-0059: Perfil 2 Unattend incluye NoAutoUpdate = 1" ([bool]($unattendP2.XmlContent -match 'NoAutoUpdate'))
Assert-True "PLAN-0059: Perfil 2 Unattend incluye AUOptions = 2" ([bool]($unattendP2.XmlContent -match 'AUOptions'))
Assert-True "PLAN-0059: Perfil 2 Unattend incluye NoAutoRebootWithLoggedOnUsers" ([bool]($unattendP2.XmlContent -match 'NoAutoRebootWithLoggedOnUsers'))

# 4. Validar inyeccion en Builder New-OptimizedWindowsISO-v2.ps1
$v2FreshContent59 = Get-Content $TargetScript -Raw
Assert-True "PLAN-0059: Builder inyecta NoAutoUpdate en SOFTWARE hive offline para Perfiles 2+" ([bool]($v2FreshContent59 -match 'Name\s*=\s*"NoAutoUpdate"'))
Assert-True "PLAN-0059: Builder inyecta AUOptions en SOFTWARE hive offline para Perfiles 2+" ([bool]($v2FreshContent59 -match 'Name\s*=\s*"AUOptions"'))
Assert-True "PLAN-0059: Builder autounattend fallback incluye NoAutoUpdate para Perfil 2+" ([bool]($v2FreshContent59 -match 'Disable Automatic Background Updates \(Manual On-Demand Scan and Download Only\)'))

# 5. Validar integracion en herramientas de diagnostico y auditoria
$diagContent59 = Get-Content (Join-Path $modulesDir "PostInstall-Diagnostics.ps1") -Raw
Assert-True "PLAN-0059: PostInstall-Diagnostics.ps1 audita modo On-Demand de Windows Update" ([bool]($diagContent59 -match 'Modo Bajo Demanda \(On-Demand\) de Windows Update verificado'))

$auditContent59 = Get-Content (Join-Path $modulesDir "Audit-FreshInstallFootprint.ps1") -Raw
Assert-True "PLAN-0059: Audit-FreshInstallFootprint.ps1 incluye NoAutoUpdate en politicas auditadas" ([bool]($auditContent59 -match 'NoAutoUpdate \(WU AU\)'))

# =============================================================================
# PLAN-0060: ESTABILIDAD DE ACTUALIZACIONES ACUMULATIVAS Y BLOQUEO DE PREVIEWS
# =============================================================================
Write-HarnessHeader2 "PLAN-0060: Estabilidad de Actualizaciones Acumulativas y Bloqueo de Previews"

# 1. Validar registro de politicas en Policy-Engine.ps1
$policyEnginePath60 = Join-Path (Split-Path $PSScriptRoot -Parent) "Core\Policy-Engine.ps1"
$peContent60 = Get-Content $policyEnginePath60 -Raw
Assert-True "PLAN-0060: Policy-Engine registra directiva POL_WU_ALLOW_OPTIONAL_CONTENT" ([bool]($peContent60 -match 'Id\s*=\s*"POL_WU_ALLOW_OPTIONAL_CONTENT"'))
Assert-True "PLAN-0060: Policy-Engine registra directiva POL_WU_CONTINUOUS_INNOVATION" ([bool]($peContent60 -match 'Id\s*=\s*"POL_WU_CONTINUOUS_INNOVATION"'))
Assert-True "PLAN-0060: Policy-Engine registra directiva POL_WU_DEFER_QUALITY" ([bool]($peContent60 -match 'Id\s*=\s*"POL_WU_DEFER_QUALITY"'))
Assert-True "PLAN-0060: Policy-Engine registra directiva POL_WU_DEFER_QUALITY_DAYS" ([bool]($peContent60 -match 'Id\s*=\s*"POL_WU_DEFER_QUALITY_DAYS"'))

# 2. Validar perfiles asignados en Policy-Engine (Universal: Perfiles 1, 2 y 3)
$pols60 = Get-RomanOSPolicies
$polAllowOpt = $pols60 | Where-Object { $_.Id -eq "POL_WU_ALLOW_OPTIONAL_CONTENT" }
Assert-NotNull "PLAN-0060: Objeto POL_WU_ALLOW_OPTIONAL_CONTENT obtenido de Policy-Engine" $polAllowOpt
Assert-Equal "PLAN-0060: POL_WU_ALLOW_OPTIONAL_CONTENT ExpectedValue es 0" $polAllowOpt.ExpectedValue 0
Assert-True "PLAN-0060: POL_WU_ALLOW_OPTIONAL_CONTENT activo en Perfil 1" ($polAllowOpt.Profiles -contains 1)
Assert-True "PLAN-0060: POL_WU_ALLOW_OPTIONAL_CONTENT activo en Perfil 2" ($polAllowOpt.Profiles -contains 2)
Assert-True "PLAN-0060: POL_WU_ALLOW_OPTIONAL_CONTENT activo en Perfil 3" ($polAllowOpt.Profiles -contains 3)

$polDeferDays = $pols60 | Where-Object { $_.Id -eq "POL_WU_DEFER_QUALITY_DAYS" }
Assert-NotNull "PLAN-0060: Objeto POL_WU_DEFER_QUALITY_DAYS obtenido de Policy-Engine" $polDeferDays
Assert-Equal "PLAN-0060: POL_WU_DEFER_QUALITY_DAYS ExpectedValue es 7" $polDeferDays.ExpectedValue 7
Assert-True "PLAN-0060: POL_WU_DEFER_QUALITY_DAYS activo en Perfil 1" ($polDeferDays.Profiles -contains 1)
Assert-True "PLAN-0060: POL_WU_DEFER_QUALITY_DAYS activo en Perfil 2" ($polDeferDays.Profiles -contains 2)
Assert-True "PLAN-0060: POL_WU_DEFER_QUALITY_DAYS activo en Perfil 3" ($polDeferDays.Profiles -contains 3)

# 3. Validar exportacion semantica de unattend para Perfiles 1 y 2
$unattendP1_60 = Export-RomanOSUnattendCommands -Profile '1' -StartOrder 2
$unattendP2_60 = Export-RomanOSUnattendCommands -Profile '2' -StartOrder 2
Assert-True "PLAN-0060: Perfil 1 Unattend incluye AllowOptionalContent = 0" ([bool]($unattendP1_60.XmlContent -match 'AllowOptionalContent'))
Assert-True "PLAN-0060: Perfil 1 Unattend incluye DeferQualityUpdates = 1" ([bool]($unattendP1_60.XmlContent -match 'DeferQualityUpdates'))
Assert-True "PLAN-0060: Perfil 1 Unattend incluye DeferQualityUpdatesPeriodInDays = 7" ([bool]($unattendP1_60.XmlContent -match 'DeferQualityUpdatesPeriodInDays'))
Assert-True "PLAN-0060: Perfil 1 Unattend incluye IsContinuousInnovationOptedIn = 0" ([bool]($unattendP1_60.XmlContent -match 'IsContinuousInnovationOptedIn'))

Assert-True "PLAN-0060: Perfil 2 Unattend incluye AllowOptionalContent = 0" ([bool]($unattendP2_60.XmlContent -match 'AllowOptionalContent'))
Assert-True "PLAN-0060: Perfil 2 Unattend incluye DeferQualityUpdatesPeriodInDays = 7" ([bool]($unattendP2_60.XmlContent -match 'DeferQualityUpdatesPeriodInDays'))

# 4. Validar inyeccion en Builder New-OptimizedWindowsISO-v2.ps1
$v2FreshContent60 = Get-Content $TargetScript -Raw
Assert-True "PLAN-0060: Builder inyecta AllowOptionalContent en SOFTWARE hive offline" ([bool]($v2FreshContent60 -match 'Name\s*=\s*"AllowOptionalContent"'))
Assert-True "PLAN-0060: Builder inyecta DeferQualityUpdates en SOFTWARE hive offline" ([bool]($v2FreshContent60 -match 'Name\s*=\s*"DeferQualityUpdates"'))
Assert-True "PLAN-0060: Builder inyecta DeferQualityUpdatesPeriodInDays en SOFTWARE hive offline" ([bool]($v2FreshContent60 -match 'Name\s*=\s*"DeferQualityUpdatesPeriodInDays"'))
Assert-True "PLAN-0060: Builder inyecta IsContinuousInnovationOptedIn en SOFTWARE hive offline" ([bool]($v2FreshContent60 -match 'Name\s*=\s*"IsContinuousInnovationOptedIn"'))
Assert-True "PLAN-0060: Builder autounattend fallback incluye AllowOptionalContent = 0" ([bool]($v2FreshContent60 -match 'Disable Optional Preview Updates and CFR Beta Content'))
Assert-True "PLAN-0060: Builder autounattend fallback incluye DeferQualityUpdatesPeriodInDays = 7" ([bool]($v2FreshContent60 -match 'Defer Quality Updates by 7 Days'))

# 5. Validar integracion en herramientas de diagnostico y auditoria
$diagContent60 = Get-Content (Join-Path $modulesDir "PostInstall-Diagnostics.ps1") -Raw
Assert-True "PLAN-0060: PostInstall-Diagnostics.ps1 audita bloqueo de previews y CFR" ([bool]($diagContent60 -match 'Bloqueo Previews / CFR Beta'))
Assert-True "PLAN-0060: PostInstall-Diagnostics.ps1 audita cuarentena de calidad (KIR Window)" ([bool]($diagContent60 -match 'Cuarentena de Calidad \(KIR Window\)'))

$auditContent60 = Get-Content (Join-Path $modulesDir "Audit-FreshInstallFootprint.ps1") -Raw
Assert-True "PLAN-0060: Audit-FreshInstallFootprint.ps1 incluye AllowOptionalContent en politicas auditadas" ([bool]($auditContent60 -match 'AllowOptionalContent \(WU\)'))
Assert-True "PLAN-0060: Audit-FreshInstallFootprint.ps1 incluye DeferQualityDays en politicas auditadas" ([bool]($auditContent60 -match 'DeferQualityDays \(WU\)'))

# -----------------------------------------------------------------------------
# FASE 2.13: VALIDACIÓN DE PARIDAD EN PERFIL 1 Y MATRIZ DE SERVICIOS (PLAN-0061)
# -----------------------------------------------------------------------------
Write-HarnessHeader2 "FASE 2.13: Paridad en Perfil 1: Drivers GPU, WPBT, BitLocker y Servicios (PLAN-0061)"

# 1. Validar SSOT en Policy-Engine para Perfil 1
$pols61 = Get-RomanOSPolicies
$polWuExclude = $pols61 | Where-Object { $_.Id -eq "POL_WU_EXCLUDE_DRIVERS" }
$polDrvSearch = $pols61 | Where-Object { $_.Id -eq "POL_DRV_SEARCH_LOCAL" }
$polDevMeta   = $pols61 | Where-Object { $_.Id -eq "POL_DEV_METADATA_BLOCK" }
$polWpbt      = $pols61 | Where-Object { $_.Id -eq "POL_WPBT_DISABLE" }
$polBitLocker = $pols61 | Where-Object { $_.Id -eq "POL_BITLOCKER_PREVENT" }

Assert-NotNull "PLAN-0061: Objeto POL_WU_EXCLUDE_DRIVERS obtenido de Policy-Engine" $polWuExclude
Assert-True "PLAN-0061: POL_WU_EXCLUDE_DRIVERS activo en Perfil 1" ($polWuExclude.Profiles -contains 1)
Assert-NotNull "PLAN-0061: Objeto POL_DRV_SEARCH_LOCAL obtenido de Policy-Engine" $polDrvSearch
Assert-True "PLAN-0061: POL_DRV_SEARCH_LOCAL activo en Perfil 1" ($polDrvSearch.Profiles -contains 1)
Assert-NotNull "PLAN-0061: Objeto POL_DEV_METADATA_BLOCK obtenido de Policy-Engine" $polDevMeta
Assert-True "PLAN-0061: POL_DEV_METADATA_BLOCK activo en Perfil 1" ($polDevMeta.Profiles -contains 1)
Assert-NotNull "PLAN-0061: Objeto POL_WPBT_DISABLE obtenido de Policy-Engine" $polWpbt
Assert-True "PLAN-0061: POL_WPBT_DISABLE activo en Perfil 1" ($polWpbt.Profiles -contains 1)
Assert-NotNull "PLAN-0061: Objeto POL_BITLOCKER_PREVENT obtenido de Policy-Engine" $polBitLocker
Assert-True "PLAN-0061: POL_BITLOCKER_PREVENT activo en Perfil 1" ($polBitLocker.Profiles -contains 1)

# 2. Validar exportacion semantica de unattend para Perfil 1 (Export-RomanOSUnattendCommands)
$unattendP1_61 = Export-RomanOSUnattendCommands -Profile '1' -StartOrder 2
Assert-True "PLAN-0061: Perfil 1 Unattend incluye ExcludeWUDriversInQualityUpdate" ([bool]($unattendP1_61.XmlContent -match 'ExcludeWUDriversInQualityUpdate'))
Assert-True "PLAN-0061: Perfil 1 Unattend incluye SearchOrderConfig" ([bool]($unattendP1_61.XmlContent -match 'SearchOrderConfig'))
Assert-True "PLAN-0061: Perfil 1 Unattend incluye PreventDeviceMetadataFromNetwork" ([bool]($unattendP1_61.XmlContent -match 'PreventDeviceMetadataFromNetwork'))
Assert-True "PLAN-0061: Perfil 1 Unattend incluye DisableWPBT" ([bool]($unattendP1_61.XmlContent -match 'DisableWPBT'))
Assert-True "PLAN-0061: Perfil 1 Unattend incluye PreventDeviceEncryption" ([bool]($unattendP1_61.XmlContent -match 'PreventDeviceEncryption'))

# 3. Validar fallback autounattend y servicing offline en Builder New-OptimizedWindowsISO-v2.ps1
$v2FreshContent61 = Get-Content $TargetScript -Raw
Assert-True "PLAN-0061: Builder autounattend fallback incluye Exclude Drivers en bloque base universal" ([bool]($v2FreshContent61 -match 'Exclude Drivers from Automatic Updates \(Move to Optional Updates - PLAN-0061\)'))
Assert-True "PLAN-0061: Builder autounattend fallback incluye SearchOrderConfig en bloque base universal" ([bool]($v2FreshContent61 -match 'SearchOrderConfig=0 = local-only - PLAN-0061'))
Assert-True "PLAN-0061: Builder autounattend fallback incluye PreventDeviceMetadata en bloque base universal" ([bool]($v2FreshContent61 -match 'Prevent Device Metadata and OEM App Download from Network \(PLAN-0061\)'))
Assert-True "PLAN-0061: Builder autounattend fallback incluye DisableWPBT en bloque base universal" ([bool]($v2FreshContent61 -match 'Disable WPBT ACPI Execution \(Block OEM BIOS Bloatware on Notebooks/Motherboards - PLAN-0061\)'))
Assert-True "PLAN-0061: Builder autounattend fallback incluye PreventDeviceEncryption en bloque base universal" ([bool]($v2FreshContent61 -match 'Prevent Automatic BitLocker Device Encryption on Clean Install \(PLAN-0061\)'))

Assert-True "PLAN-0061: Builder inyecta ExcludeWUDriversInQualityUpdate en SOFTWARE hive offline" ([bool]($v2FreshContent61 -match 'ExcludeWUDriversInQualityUpdate'))
Assert-True "PLAN-0061: Builder inyecta DisableWPBT en SYSTEM hive offline" ([bool]($v2FreshContent61 -match 'DisableWPBT'))
Assert-True "PLAN-0061: Builder inyecta PreventDeviceEncryption en SYSTEM hive offline" ([bool]($v2FreshContent61 -match 'PreventDeviceEncryption'))

# 4. Validar matriz de servicios en SetupComplete.cmd
Assert-True "PLAN-0061: SetupComplete deshabilita DiagTrack universalmente en bloque base" ([bool]($v2FreshContent61 -match 'sc config DiagTrack start=disabled'))
Assert-True "PLAN-0061: SetupComplete deshabilita dmwappushservice universalmente en bloque base" ([bool]($v2FreshContent61 -match 'sc config dmwappushservice start=disabled'))
Assert-True "PLAN-0061: SetupComplete deshabilita SysMain en Perfil 2+ (Gaming)" ([bool]($v2FreshContent61 -match 'Deshabilitando SysMain \(SuperFetch\) para optimizar latencia en gaming'))
Assert-True "PLAN-0061: SetupComplete preserva WSearch exclusivo para Perfil 3" ([bool]($v2FreshContent61 -match 'sc config WSearch start=disabled'))

# 5. Validar catalogo de auditoria forense en Audit-FreshInstallFootprint.ps1
$auditContent61 = Get-Content (Join-Path $modulesDir "Audit-FreshInstallFootprint.ps1") -Raw
Assert-True "PLAN-0061: Audit-FreshInstallFootprint.ps1 incluye ExcludeWUDrivers en politicas auditadas" ([bool]($auditContent61 -match 'ExcludeWUDrivers \(WU\)'))
Assert-True "PLAN-0061: Audit-FreshInstallFootprint.ps1 incluye SearchOrderConfig en politicas auditadas" ([bool]($auditContent61 -match 'SearchOrderConfig \(Drv\)'))
Assert-True "PLAN-0061: Audit-FreshInstallFootprint.ps1 incluye PreventDeviceMetadata en politicas auditadas" ([bool]($auditContent61 -match 'PreventDeviceMetadata \(Drv\)'))
Assert-True "PLAN-0061: Audit-FreshInstallFootprint.ps1 incluye DisableWPBT en politicas auditadas" ([bool]($auditContent61 -match 'DisableWPBT \(ACPI\)'))
Assert-True "PLAN-0061: Audit-FreshInstallFootprint.ps1 incluye PreventDeviceEncryption en politicas auditadas" ([bool]($auditContent61 -match 'PreventDeviceEncryption \(BitLocker\)'))

# -----------------------------------------------------------------------------
# FASE 2.14: VALIDACIÓN DE RESOLUCIÓN DE RUTAS CORE Y CATÁLOGO DE RED (PLAN-0062)
# -----------------------------------------------------------------------------
Write-HarnessHeader2 "FASE 2.14: Resolucion Jerarquica de Motores Core y Catalogo de Red (PLAN-0062)"

# 1. Validar catalogo global RomanOS_NetworkPolicies en Policy-Engine
Assert-NotNull "PLAN-0062: Catalogo global RomanOS_NetworkPolicies disponible" $global:RomanOS_NetworkPolicies
Assert-True "PLAN-0062: RomanOS_NetworkPolicies contiene al menos 18 directivas de red" ($global:RomanOS_NetworkPolicies.Count -ge 18)

$netIds = $global:RomanOS_NetworkPolicies | ForEach-Object { $_.Id }
Assert-True "PLAN-0062: RomanOS_NetworkPolicies incluye NET_TCP_AUTOTUNING" ($netIds -contains "NET_TCP_AUTOTUNING")
Assert-True "PLAN-0062: RomanOS_NetworkPolicies incluye NET_TCP_CONGESTION_CUBIC" ($netIds -contains "NET_TCP_CONGESTION_CUBIC")
Assert-True "PLAN-0062: RomanOS_NetworkPolicies incluye NET_TCP_ECN_CAPABILITY" ($netIds -contains "NET_TCP_ECN_CAPABILITY")
Assert-True "PLAN-0062: RomanOS_NetworkPolicies incluye NET_SYS_QOS_UNCAP" ($netIds -contains "NET_SYS_QOS_UNCAP")
Assert-True "PLAN-0062: RomanOS_NetworkPolicies incluye NET_SYS_NAGLE_ALGORITHM" ($netIds -contains "NET_SYS_NAGLE_ALGORITHM")

# 2. Validar resolucion jerarquica en Win11-Network-Diagnostics-Optimizer.ps1
$netOptContent62 = Get-Content (Join-Path $modulesDir "Win11-Network-Diagnostics-Optimizer.ps1") -Raw
Assert-True "PLAN-0062: Network Optimizer incluye resolucion Core jerarquica para UI-Engine" ([bool]($netOptContent62 -match 'Split-Path \$PSScriptRoot -Parent\)\s*"Core\\UI-Engine\.ps1"'))
Assert-True "PLAN-0062: Network Optimizer incluye resolucion Core jerarquica para Policy-Engine" ([bool]($netOptContent62 -match 'Split-Path \$PSScriptRoot -Parent\)\s*"Core\\Policy-Engine\.ps1"'))
Assert-True "PLAN-0062: Network Optimizer soporta ShouldProcess / WhatIf en elevacion" ([bool]($netOptContent62 -match 'CmdletBinding\(SupportsShouldProcess\s*=\s*\$true\)'))

# 3. Validar resolucion jerarquica en romanOS-Toolkit.ps1
$toolkitContent62 = Get-Content (Join-Path $modulesDir "romanOS-Toolkit.ps1") -Raw
Assert-True "PLAN-0062: Toolkit incluye resolucion Core jerarquica para UI-Engine" ([bool]($toolkitContent62 -match 'Split-Path \$PSScriptRoot -Parent\)\s*"Core\\UI-Engine\.ps1"'))
Assert-True "PLAN-0062: Toolkit incluye resolucion Core jerarquica para Hardware-Engine" ([bool]($toolkitContent62 -match 'Split-Path \$PSScriptRoot -Parent\)\s*"Core\\Hardware-Engine\.ps1"'))
Assert-True "PLAN-0062: Toolkit incluye resolucion Core jerarquica para Policy-Engine" ([bool]($toolkitContent62 -match 'Split-Path \$PSScriptRoot -Parent\)\s*"Core\\Policy-Engine\.ps1"'))

# 4. Validar resolucion jerarquica en Win11-Debloat-v3-Adaptive.ps1 y PostInstall-Diagnostics.ps1
$debloatContent62 = Get-Content (Join-Path $modulesDir "Win11-Debloat-v3-Adaptive.ps1") -Raw
Assert-True "PLAN-0062: Debloat incluye resolucion Core jerarquica para UI-Engine" ([bool]($debloatContent62 -match 'Split-Path \$PSScriptRoot -Parent\)\s*"Core\\UI-Engine\.ps1"'))
Assert-True "PLAN-0062: Debloat incluye resolucion Core jerarquica para Policy-Engine" ([bool]($debloatContent62 -match 'Split-Path \$PSScriptRoot -Parent\)\s*"Core\\Policy-Engine\.ps1"'))

$postDiagContent62 = Get-Content (Join-Path $modulesDir "PostInstall-Diagnostics.ps1") -Raw
Assert-True "PLAN-0062: PostInstall-Diagnostics incluye resolucion jerarquica para UI-Engine" ([bool]($postDiagContent62 -match 'Split-Path \$PSScriptRoot -Parent\)\s*"Core\\UI-Engine\.ps1"'))
Assert-True "PLAN-0062: PostInstall-Diagnostics incluye resolucion jerarquica para Hardware-Engine" ([bool]($postDiagContent62 -match 'Split-Path \$PSScriptRoot -Parent\)\s*"Core\\Hardware-Engine\.ps1"'))
Assert-True "PLAN-0062: PostInstall-Diagnostics incluye resolucion jerarquica para Policy-Engine" ([bool]($postDiagContent62 -match 'Split-Path \$PSScriptRoot -Parent\)\s*"Core\\Policy-Engine\.ps1"'))

# 5. Validar suites de testing sin hardcodes absolutos fuera de fallback
$testSuiteContent62 = Get-Content (Join-Path $PSScriptRoot "Invoke-TestSuite.ps1") -Raw
Assert-True "PLAN-0062: Invoke-TestSuite.ps1 incluye resolucion jerarquica de UI-Engine" ([bool]($testSuiteContent62 -match 'Split-Path \$PSScriptRoot -Parent\)\s*"Core\\UI-Engine\.ps1"'))

$testHwContent62 = Get-Content (Join-Path $PSScriptRoot "Test-HardwareEngine.ps1") -Raw
Assert-True "PLAN-0062: Test-HardwareEngine.ps1 incluye resolucion jerarquica de Hardware-Engine" ([bool]($testHwContent62 -match 'Split-Path \$PSScriptRoot -Parent\)\s*"Core\\Hardware-Engine\.ps1"'))

# -----------------------------------------------------------------------------
# FASE 2.15: CERTIFICACIÓN DE ARQUITECTURA HOST (PLAN-0063)
# -----------------------------------------------------------------------------
Write-HarnessHeader2 "FASE 2.15: Certificacion de Arquitectura Host (Ryzen 8600G) (PLAN-0063)"

$projectRootDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# 1. Validar existencia y codificación de Desplegar-Setup-Host.ps1
$desplegarPs1Path = Join-Path $projectRootDir "scripts\Host-Tools\Desplegar-Setup-Host.ps1"
Assert-True "PLAN-0063: Desplegar-Setup-Host.ps1 existe en Host-Tools" (Test-Path $desplegarPs1Path)

if (Test-Path $desplegarPs1Path) {
    $bytes = [System.IO.File]::ReadAllBytes($desplegarPs1Path)
    $hasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    Assert-True "PLAN-0063: Desplegar-Setup-Host.ps1 tiene codificacion UTF-8 con BOM" $hasBOM

    $tokens = $null; $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($desplegarPs1Path, [ref]$tokens, [ref]$errs)
    Assert-Equal "PLAN-0063: Desplegar-Setup-Host.ps1 tiene 0 errores AST de sintaxis" $errs.Count 0
}

# 2. Validar existencia del lanzador Desplegar-Setup-Host.cmd
$desplegarCmdPath = Join-Path $projectRootDir "scripts\Host-Tools\Desplegar-Setup-Host.cmd"
Assert-True "PLAN-0063: Desplegar-Setup-Host.cmd existe en Host-Tools" (Test-Path $desplegarCmdPath)

# 3. Validar Preset_Host_Ryzen8600G.json
$presetHostPath = Join-Path $projectRootDir "Preset_Host_Ryzen8600G.json"
Assert-True "PLAN-0063: Preset_Host_Ryzen8600G.json existe en la raiz" (Test-Path $presetHostPath)

if (Test-Path $presetHostPath) {
    $presetJson = Get-Content $presetHostPath -Raw | ConvertFrom-Json
    Assert-Equal "PLAN-0063: Preset OptimizationProfile es 3 (Hardcore)" $presetJson.OptimizationProfile "3"
    Assert-Equal "PLAN-0063: Preset LocalUser es Roman" $presetJson.LocalUser "Roman"
    Assert-Equal "PLAN-0063: Preset DriversPath apunta a Drivers" $presetJson.DriversPath "Drivers"
    Assert-True "PLAN-0063: Preset EnableHyperV esta activado" ([bool]$presetJson.EnableHyperV)
}

# 4. Validar lanzador 1-clic Compilar-ISO-Host-Ryzen8600G.cmd
$compilarCmdPath = Join-Path $projectRootDir "Compilar-ISO-Host-Ryzen8600G.cmd"
Assert-True "PLAN-0063: Compilar-ISO-Host-Ryzen8600G.cmd existe en la raiz" (Test-Path $compilarCmdPath)

# 5. Validar soporte de EnableHyperV e inyección de Host-Tools en Builder
$builderContent63 = Get-Content $TargetScript -Raw
Assert-True "PLAN-0063: Builder AST incluye parametro EnableHyperV" ([bool]($builderContent63 -match '\[switch\]\$EnableHyperV'))
Assert-True "PLAN-0063: Builder inyecta Desplegar-Setup-Host en OEM y Desktop" ([bool]($builderContent63 -match 'Desplegar-Setup-Host\.cmd'))
Assert-True "PLAN-0063: Builder incluye habilitacion offline de Hyper-V con DISM" ([bool]($builderContent63 -match 'Microsoft-Hyper-V-All'))

# -----------------------------------------------------------------------------
# FASE 2.15: VALIDACIÓN DE OPTIMIZACIÓN DE INSTALACIÓN ZERO-TOUCH (PLAN-0076)
# -----------------------------------------------------------------------------
Write-HarnessHeader2 "FASE 2.15: Optimizacion del Tiempo de Instalacion Zero-Touch (PLAN-0076)"

# 1. Validar directivas de supresion de animacion de primer inicio en Policy-Engine
Assert-NotNull "PLAN-0076: Directiva POL_FIRST_LOGON_ANIMATION en Policy-Engine" ($global:RomanOS_Policies | Where-Object { $_.Id -eq 'POL_FIRST_LOGON_ANIMATION' })
Assert-NotNull "PLAN-0076: Directiva POL_FIRST_LOGON_ANIM_WINLOGON en Policy-Engine" ($global:RomanOS_Policies | Where-Object { $_.Id -eq 'POL_FIRST_LOGON_ANIM_WINLOGON' })

$unattendExp76 = Export-RomanOSUnattendCommands -Profile "1"
Assert-True "PLAN-0076: Export-RomanOSUnattendCommands exporta EnableFirstLogonAnimation" ([bool]($unattendExp76.XmlContent -match 'EnableFirstLogonAnimation'))

# 2. Validar aceleracion en fase windowsPE de autounattend.xml
$v2FreshContent76 = Get-Content $TargetScript -Raw
Assert-True "PLAN-0076: Builder autounattend incluye powercfg High Performance en windowsPE" ([bool]($v2FreshContent76 -match 'powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'))
Assert-True "PLAN-0076: Builder autounattend incluye DynamicUpdate deshabilitado" ([bool]($v2FreshContent76 -match '<DynamicUpdate>\s*<Enable>false</Enable>'))

# 3. Validar consolidacion de tareas en SetupComplete.cmd
Assert-True "PLAN-0076: Builder genera Initialize-SuiteTasks.ps1 para ejecucion consolidada" ([bool]($v2FreshContent76 -match 'Initialize-SuiteTasks\.ps1'))
Assert-True "PLAN-0076: SetupComplete lanza diagnosticos en background de forma desacoplada" ([bool]($v2FreshContent76 -match 'start "" /b.*PostInstall-Diagnostics\.ps1'))

# -----------------------------------------------------------------------------
# FASE 2.16: SINCRONIZACIÓN Y PARIDAD DEL TOOLKIT MAESTRO EN LA ISO (PLAN-0085)
# -----------------------------------------------------------------------------
Write-HarnessHeader2 "FASE 2.16: Sincronizacion y Paridad del Toolkit Maestro (PLAN-0085)"

# 1. Validar parámetros CLI extendidos en romanOS-Toolkit.ps1
$toolkitScriptPath85 = Join-Path $modulesDir "romanOS-Toolkit.ps1"
$toolkitContent85    = Get-Content $toolkitScriptPath85 -Raw
Assert-True "PLAN-0085: romanOS-Toolkit.ps1 acepta UniversalAudit en ValidateSet" ([bool]($toolkitContent85 -match 'UniversalAudit'))
Assert-True "PLAN-0085: romanOS-Toolkit.ps1 acepta GameDevSwitch en ValidateSet" ([bool]($toolkitContent85 -match 'GameDevSwitch'))
Assert-True "PLAN-0085: romanOS-Toolkit.ps1 declara funcion Invoke-UniversalAuditModule" ([bool]($toolkitContent85 -match 'function Invoke-UniversalAuditModule'))
Assert-True "PLAN-0085: romanOS-Toolkit.ps1 declara funcion Invoke-GameDevSwitchModule" ([bool]($toolkitContent85 -match 'function Invoke-GameDevSwitchModule'))
Assert-True "PLAN-0085: romanOS-Toolkit.ps1 incluye Auditor Universal en menu interactivo" ([bool]($toolkitContent85 -match 'Auditor Universal de Optimizacion'))
Assert-True "PLAN-0085: romanOS-Toolkit.ps1 incluye Conmutador Modo Juego/Dev en menu interactivo" ([bool]($toolkitContent85 -match 'Conmutador Modo Juego / Modo Dev'))

# 2. Validar inyección garantizada en Builder New-OptimizedWindowsISO-v2.ps1
$builderContent85 = Get-Content $TargetScript -Raw
Assert-True "PLAN-0085: Builder inyecta Audit-SystemOptimization.ps1 en `$OEM`$" ([bool]($builderContent85 -match '(?s)Audit-SystemOptimization\.ps1.*?destModulesDir'))
Assert-True "PLAN-0085: Builder inyecta Switch-GameDevMode en `$OEM`$" ([bool]($builderContent85 -match '(?s)Switch-GameDevMode\.ps1.*?destModulesDir'))
Assert-True "PLAN-0085: Builder inyecta Audit-SystemOptimization.ps1 en WIM" ([bool]($builderContent85 -match '(?s)Audit-SystemOptimization\.ps1.*?wimModulesDest'))
Assert-True "PLAN-0085: Builder inyecta Switch-GameDevMode en WIM" ([bool]($builderContent85 -match '(?s)Switch-GameDevMode\.ps1.*?wimModulesDest'))

# 3. Validar existencia y codificación No-BOM del lanzador raíz
$rootLauncherPath85 = Join-Path $projectRootDir "Lanzar-romanOS-Toolkit.cmd"
Assert-True "PLAN-0085: Lanzar-romanOS-Toolkit.cmd existe en la raiz" (Test-Path $rootLauncherPath85)
$launcherBytes85 = if (Test-Path $rootLauncherPath85) { [System.IO.File]::ReadAllBytes($rootLauncherPath85) } else { @() }
$launcherHasBom85 = ($launcherBytes85.Length -ge 3 -and $launcherBytes85[0] -eq 0xEF -and $launcherBytes85[1] -eq 0xBB -and $launcherBytes85[2] -eq 0xBF)
Assert-True "PLAN-0085: Lanzar-romanOS-Toolkit.cmd es UTF-8 No-BOM / ANSI" (-not $launcherHasBom85)

# -----------------------------------------------------------------------------
Write-HarnessHeader2 "FASE 2.17: romanOS Control Center (WPF GUI Hub) (PLAN-0086)"

# 1. Validar sintaxis AST y UTF-8 BOM en scripts/GUI/romanOS-ControlCenter.ps1
$ccScriptPath86 = Join-Path $projectRootDir "scripts\GUI\romanOS-ControlCenter.ps1"
Assert-True "PLAN-0086: romanOS-ControlCenter.ps1 existe en scripts\GUI" (Test-Path $ccScriptPath86)
if (Test-Path $ccScriptPath86) {
    $ccBytes86 = [System.IO.File]::ReadAllBytes($ccScriptPath86)
    $ccHasBom86 = ($ccBytes86.Length -ge 3 -and $ccBytes86[0] -eq 0xEF -and $ccBytes86[1] -eq 0xBB -and $ccBytes86[2] -eq 0xBF)
    Assert-True "PLAN-0086: romanOS-ControlCenter.ps1 tiene codificacion UTF-8 con BOM" $ccHasBom86

    $ccContent86 = [System.IO.File]::ReadAllText($ccScriptPath86, [System.Text.Encoding]::UTF8)
    $tokens86 = $null
    $errors86 = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($ccContent86, [ref]$tokens86, [ref]$errors86)
    Assert-True "PLAN-0086: romanOS-ControlCenter.ps1 libre de errores sintacticos AST (0 errores)" ($errors86.Count -eq 0)
    Assert-True "PLAN-0086: romanOS-ControlCenter.ps1 contiene definicion XAML y Dark Mode" ([bool]($ccContent86 -match 'Window' -and $ccContent86 -match '#202020'))
    Assert-True "PLAN-0086: romanOS-ControlCenter.ps1 implementa streaming asincrono con RunspaceFactory" ([bool]($ccContent86 -match 'RunspaceFactory' -and $ccContent86 -match 'ConcurrentQueue'))
}

# 2. Validar Lanzador Win32 JIT C# y Script .cmd
$ccLauncherCsPath86 = Join-Path $projectRootDir "scripts\GUI\romanOS-ControlCenter-Launcher.cs"
Assert-True "PLAN-0086: romanOS-ControlCenter-Launcher.cs existe en scripts\GUI" (Test-Path $ccLauncherCsPath86)
if (Test-Path $ccLauncherCsPath86) {
    $csContent86 = Get-Content $ccLauncherCsPath86 -Raw
    Assert-True "PLAN-0086: Lanzador C# define STAThread y CreateNoWindow" ([bool]($csContent86 -match 'STAThread' -and $csContent86 -match 'CreateNoWindow\s*=\s*true'))
}

$ccCmdPath86 = Join-Path $projectRootDir "Lanzar-romanOS-ControlCenter.cmd"
Assert-True "PLAN-0086: Lanzar-romanOS-ControlCenter.cmd existe en la raiz" (Test-Path $ccCmdPath86)
if (Test-Path $ccCmdPath86) {
    $cmdBytes86 = [System.IO.File]::ReadAllBytes($ccCmdPath86)
    $cmdHasBom86 = ($cmdBytes86.Length -ge 3 -and $cmdBytes86[0] -eq 0xEF -and $cmdBytes86[1] -eq 0xBB -and $cmdBytes86[2] -eq 0xBF)
    Assert-True "PLAN-0086: Lanzar-romanOS-ControlCenter.cmd es UTF-8 No-BOM / ANSI" (-not $cmdHasBom86)
    $cmdContent86 = Get-Content $ccCmdPath86 -Raw
    Assert-True "PLAN-0086: Lanzador CMD invoca autocompilacion con csc.exe" ([bool]($cmdContent86 -match 'csc\.exe' -and $cmdContent86 -match '/target:winexe'))
}

# 3. Validar integración de romanOS Control Center en romanOS-Toolkit.ps1
$toolkitContent86 = Get-Content (Join-Path $modulesDir "romanOS-Toolkit.ps1") -Raw
Assert-True "PLAN-0086: romanOS-Toolkit.ps1 soporta parametro -GUI y switch" ([bool]($toolkitContent86 -match '\[switch\]\$GUI' -and $toolkitContent86 -match '"GUI"'))
Assert-True "PLAN-0086: romanOS-Toolkit.ps1 declara funcion Invoke-ControlCenterGUI" ([bool]($toolkitContent86 -match 'function Invoke-ControlCenterGUI'))
Assert-True "PLAN-0086: romanOS-Toolkit.ps1 incluye Control Center en menu principal" ([bool]($toolkitContent86 -match 'Abrir romanOS Control Center'))

# 4. Validar inyección de romanOS Control Center en New-OptimizedWindowsISO-v2.ps1
$builderContent86 = Get-Content $TargetScript -Raw
Assert-True "PLAN-0086: Builder inyecta romanOS Control Center en `$OEM`$" ([bool]($builderContent86 -match '(?s)romanOS-ControlCenter\.ps1.*?destModulesDir'))
Assert-True "PLAN-0086: Builder inyecta romanOS Control Center en WIM montado" ([bool]($builderContent86 -match '(?s)romanOS-ControlCenter\.ps1.*?wimModulesDest'))

# -----------------------------------------------------------------------------
Write-HarnessHeader2 "FASE 2.18: Universalizacion Multi-Hardware y Resiliencia de Control Center (PLAN-0092)"

# 1. Validar resolucion topologica de almacenamiento y shaders en Invoke-WindowsMaintenance.ps1
$maintPath92 = Join-Path $modulesDir "Invoke-WindowsMaintenance.ps1"
$maintContent92 = Get-Content $maintPath92 -Raw
Assert-True "PLAN-0092: Invoke-WindowsMaintenance.ps1 resuelve disco por Get-Partition para TRIM" ([bool]($maintContent92 -match 'Get-Partition -DriveLetter \$dl'))
Assert-True "PLAN-0092: Invoke-WindowsMaintenance.ps1 no asume DeviceID = 0 rígidamente" (-not [bool]($maintContent92 -match 'DeviceID\s*-eq\s*''0'''))
Assert-True "PLAN-0092: Invoke-WindowsMaintenance.ps1 incluye Intel\ShaderCache" ([bool]($maintContent92 -match 'Intel\\ShaderCache'))
Assert-True "PLAN-0092: Invoke-WindowsMaintenance.ps1 incluye NVIDIA\GLCache" ([bool]($maintContent92 -match 'NVIDIA\\GLCache'))
Assert-True "PLAN-0092: Invoke-WindowsMaintenance.ps1 incluye AMD\GLCache" ([bool]($maintContent92 -match 'AMD\\GLCache'))

# 2. Validar catalogo de shaders ampliado en Optimize-GamingAndApps.ps1
$gamingPath92 = Join-Path $modulesDir "Optimize-GamingAndApps.ps1"
$gamingContent92 = Get-Content $gamingPath92 -Raw
Assert-True "PLAN-0092: Optimize-GamingAndApps.ps1 incluye Intel\ShaderCache" ([bool]($gamingContent92 -match 'Intel\\ShaderCache'))
Assert-True "PLAN-0092: Optimize-GamingAndApps.ps1 incluye NVIDIA\GLCache" ([bool]($gamingContent92 -match 'NVIDIA\\GLCache'))
Assert-True "PLAN-0092: Optimize-GamingAndApps.ps1 incluye AMD\GLCache" ([bool]($gamingContent92 -match 'AMD\\GLCache'))

# 3. Validar DNS por gateway predeterminado y textos XAML universales en Control Center
$ccContent92 = Get-Content $ccScriptPath86 -Raw
Assert-True "PLAN-0092: romanOS-ControlCenter.ps1 consulta Get-NetRoute para configurar DNS" ([bool]($ccContent92 -match 'Get-NetRoute -DestinationPrefix ''0\.0\.0\.0/0'''))
Assert-True "PLAN-0092: romanOS-ControlCenter.ps1 generaliza descripcion XAML de Modo Agresivo" (-not [bool]($ccContent92 -match 'para la APU Radeon\.'))

# 4. Validar integracion SSOT de Hardware-Engine en Audit-SystemOptimization.ps1
$auditPath92 = Join-Path $modulesDir "Audit-SystemOptimization.ps1"
$auditContent92 = Get-Content $auditPath92 -Raw
Assert-True "PLAN-0092: Audit-SystemOptimization.ps1 carga canonicamente Hardware-Engine.ps1" ([bool]($auditContent92 -match 'Core\\Hardware-Engine\.ps1'))
Assert-True "PLAN-0092: Audit-SystemOptimization.ps1 consume Get-SystemHardwareProfile" ([bool]($auditContent92 -match 'Get-SystemHardwareProfile'))
Assert-True "PLAN-0092: Audit-SystemOptimization.ps1 resuelve particion de arranque de forma resiliente" ([bool]($auditContent92 -match 'Get-Partition -DriveLetter'))

# 5. Validar dinamismo de GPU y carga de Hardware-Engine en Switch-GameDevMode.ps1
$switchPath92 = Join-Path $modulesDir "Switch-GameDevMode.ps1"
$switchContent92 = Get-Content $switchPath92 -Raw
Assert-True "PLAN-0092: Switch-GameDevMode.ps1 carga canonicamente Hardware-Engine.ps1" ([bool]($switchContent92 -match 'Core\\Hardware-Engine\.ps1'))
Assert-True "PLAN-0092: Switch-GameDevMode.ps1 no contiene textos hardcodeados de APU Radeon 760M" (-not [bool]($switchContent92 -match 'para la APU Radeon 760M'))

# --- FASE 3: PRUEBA DE INTEGRACION GENERAL ---
Write-HarnessHeader2 "FASE 3: Integracion de Ciclo Completo"
$intDir = Join-Path $TEMP_ROOT "Integration"
New-Item -ItemType Directory $intDir -Force | Out-Null

$script:LogErrors      = [System.Collections.Generic.List[string]]::new()
$script:LogWarns       = [System.Collections.Generic.List[string]]::new()
$script:LogSteps       = [System.Collections.Generic.List[PSObject]]::new()
$script:CurrentStepObj = $null
$script:StartTime      = Get-Date

Assert-NoThrow "Integracion: Inicializacion de log en directorio aislado" {
    Initialize-Log -OutputDirectory $intDir
}
Assert-FileExists "Integracion: Archivo .log creado" $script:LogFile
Assert-NotNull "Integracion: Ruta de AI_SUMMARY.md configurada" $script:AiSummaryFile

Write-Step "Paso 1 - Despliegue de prueba"
Write-OK "Subtarea 1 completada exitosamente"
Write-Step "Paso 2 - Simulacion de diagnosticos"
Write-Warn "Advertencia controlada de prueba"
Write-ErrorMsg "Error controlado de prueba"
Write-LogSummary

Assert-FileExists "Integracion: AI_SUMMARY.md generado en disco" $script:AiSummaryFile
$mdInt = Get-Content $script:AiSummaryFile -Raw -ErrorAction SilentlyContinue
Assert-True "Integracion: Resumen contiene tabla de pasos" ($mdInt -match '\| Step \|')
Assert-True "Integracion: Resumen refleja estado final FAILED al contener error" ($mdInt -match "FAILED")
Assert-True "Integracion: Resumen incluye bloque de errores" ($mdInt -match "Errors")

$resIntIso = Resolve-SourceISO -SourceISO $TEMP_ISO
Assert-Equal "Integracion: Resolve-SourceISO resuelve correctamente la ISO temporal" $resIntIso (Resolve-Path $TEMP_ISO).Path

# --- LIMPIEZA TEMPORAL ---
try {
    if (Test-Path $TEMP_ROOT) { Remove-Item -Path $TEMP_ROOT -Recurse -Force -ErrorAction Stop }
} catch {
    Write-Warning "No se pudo eliminar la carpeta temporal de prueba '$TEMP_ROOT': $($_.Exception.Message)"
}

# --- FASE 4: EVALUACION FINAL Y REPORTE ---
$totalTests = $script:HPass + $script:HFail + $script:HSkip
$pctPass    = if ($totalTests -gt 0) { [math]::Round(($script:HPass / $totalTests) * 100, 1) } else { 0 }
$allPassed  = ($script:HFail -eq 0)
$bannerColor = if ($allPassed) { "Green" } else { "Red" }

Write-Host ""
Write-Host "  ================================================================" -ForegroundColor $bannerColor
Write-Host "    EVALUACION FINAL DEL TEST HARNESS" -ForegroundColor $bannerColor
Write-Host "  ================================================================" -ForegroundColor $bannerColor
Write-Host "    Total de Pruebas : $totalTests" -ForegroundColor White
Write-Host "    PASS             : $($script:HPass) ($pctPass%)" -ForegroundColor Green
Write-Host "    FAIL             : $($script:HFail)" -ForegroundColor $(if ($script:HFail -gt 0) { "Red" } else { "Green" })
Write-Host "    SKIP             : $($script:HSkip)" -ForegroundColor DarkGray
Write-Host ""

if ($script:HFail -gt 0) {
    Write-Host "  DETALLE DE PRUEBAS FALLIDAS:" -ForegroundColor Red
    $script:HResults | Where-Object { $_.Status -eq "FAIL" } | ForEach-Object {
        Write-Host "    * $($_.Name)" -ForegroundColor Red
        if ($_.Detail) { Write-Host "      $($_.Detail)" -ForegroundColor DarkRed }
    }
    Write-Host ""
}

$reportFile = Join-Path $LogDir "TestHarness_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
try {
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Test Harness Report - New-OptimizedWindowsISO-v2.ps1")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Parametro | Valor |")
    [void]$sb.AppendLine("| :--- | :--- |")
    [void]$sb.AppendLine("| Fecha de Ejecucion | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') |")
    [void]$sb.AppendLine("| Version de PowerShell | $($PSVersionTable.PSVersion) |")
    [void]$sb.AppendLine("| Equipo Host | $env:COMPUTERNAME |")
    [void]$sb.AppendLine("| Estado General | $(if ($allPassed) { 'EXITOSO (PASS)' } else { 'FALLIDO (FAIL)' }) |")
    [void]$sb.AppendLine("| Metricas | Total: $totalTests | PASS: $($script:HPass) | FAIL: $($script:HFail) | SKIP: $($script:HSkip) |")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Detalle de Pruebas Unitarias e Integracion")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| # | Prueba | Estado | Detalle / Observacion |")
    [void]$sb.AppendLine("| :-- | :--- | :--- | :--- |")
    $idx = 1
    $script:HResults | ForEach-Object {
        $badge = switch ($_.Status) { "PASS" { "PASS" } "FAIL" { "FAIL" } "SKIP" { "SKIP" } default { "" } }
        [void]$sb.AppendLine("| $idx | $($_.Name) | $badge | $($_.Detail) |")
        $idx++
    }
    [System.IO.File]::WriteAllText($reportFile, $sb.ToString(), [System.Text.Encoding]::UTF8)
    Write-Host "    Reporte Markdown guardado en: $reportFile" -ForegroundColor DarkGray
} catch {
    Write-Host "    [WARN] No se pudo guardar el reporte Markdown: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
if ($allPassed) {
    Write-Host "  >> TODOS LOS TESTS PASARON EXITOSAMENTE. Script verificado para produccion." -ForegroundColor Green
} else {
    Write-Host "  >> ATENCION: Existen pruebas fallidas que requieren correccion." -ForegroundColor Red
}
Write-Host ""

exit $(if ($allPassed) { 0 } else { 1 })
