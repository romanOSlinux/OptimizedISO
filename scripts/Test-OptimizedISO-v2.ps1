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
    [string]$TargetScript = "C:\OptimizedISO\scripts\New-OptimizedWindowsISO-v2.ps1"
)

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$HARNESS_VERSION = "2.0"
$EXPECTED_FUNCS  = 52
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

# Scripts a cargar: motor visual (UI-Engine) + script principal
$UIEngine = Join-Path (Split-Path $TargetScript -Parent) 'Core\UI-Engine.ps1'
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

Assert-Equal "52 funciones cargadas via AST (Core + UI Engine + Standalone Fallbacks)" $loadedCount $EXPECTED_FUNCS
Assert-Equal "0 errores durante la carga" $loadErrors 0

Write-HarnessHeader2 "FASE 1B: Verificacion de Funciones en Scope"
# Funciones del UI-Engine (Core)
$expectedList = @(
    "Show-UnifiedBanner", "Write-StepHeader", "Write-SubStep", "Write-OK", "Write-Warn",
    "Write-ErrorMsg", "Write-Info", "Show-UnifiedMenu", "Prompt-UnifiedYesNo", "Show-UnifiedSummary",
    # Funciones de New-OptimizedWindowsISO-v2.ps1
    "Initialize-Log", "Write-LogEntry", "Write-LogSummary", "Test-Admin", "Test-7ZipInstalled",
    "Test-OSCDImgInstalled", "Install-Dependencies", "Test-MinimumFreeSpace",
    "Convert-BuildToWindowsVersion", "Get-WimImageList", "Detect-WindowsVersion",
    "Get-OnlineWindowsReleases", "Invoke-OfficialWindowsDownload", "Resolve-SourceISO",
    "Expand-WindowsIso", "Invoke-RegUnloadHive", "Add-ImageInstallToAutounattend",
    "Invoke-FallbackSelectionMenu", "Invoke-SelectionMenu", "Invoke-WizardConfig",
    "Invoke-DeploymentChoices", "Invoke-MonitoredProcess", "Invoke-SafeWimDismount",
    "Test-MsuIsPsfFormat", "Get-WimPatchLevel", "Resolve-RuntimesDirectory"
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
Assert-True "Get-OnlineWindowsReleases: Catalogo incluye ediciones LTSC" (($script:releases | Where-Object { $_.Channel -eq "LTSC" }).Count -ge 1)
Assert-True "Get-OnlineWindowsReleases: Catalogo incluye Windows 11 GA" (($script:releases | Where-Object { $_.Family -eq "Windows 11" -and $_.Channel -eq "General Availability" }).Count -ge 1)
Assert-True "Get-OnlineWindowsReleases: Catalogo incluye Windows 10" (($script:releases | Where-Object { $_.Family -eq "Windows 10" }).Count -ge 1)

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
Assert-NoThrow "Invoke-OfficialWindowsDownload: 10 LTSC 2021 + Business sin crash" {
    $script:resBiz = Invoke-OfficialWindowsDownload -Version "10_LTSC_2021" -Edition "Business" -Language "Spanish" -OutputDir $TEMP_OUTPUT
}
Assert-Null "Invoke-OfficialWindowsDownload: LTSC 2021 + Business => null (ruta especial)" $script:resBiz

$script:res24HBiz = $null
Assert-NoThrow "Invoke-OfficialWindowsDownload: 24H2 + Business sin crash" {
    $script:res24HBiz = Invoke-OfficialWindowsDownload -Version "11_24H2" -Edition "Business" -Language "Spanish" -OutputDir $TEMP_OUTPUT
}
Assert-Null "Invoke-OfficialWindowsDownload: 24H2 + Business => null (Business = canal especial)" $script:res24HBiz

Assert-NoThrow "Invoke-OfficialWindowsDownload: Consumer 25H2 ejecuta flujo con fallback seguro" {
    Invoke-OfficialWindowsDownload -Version "11_25H2" -Edition "Consumer" -Language "Spanish" -OutputDir $TEMP_OUTPUT
}

Assert-NoThrow "Invoke-OfficialWindowsDownload: Consumer 10 22H2 ejecuta flujo con fallback seguro" {
    Invoke-OfficialWindowsDownload -Version "10_22H2" -Edition "Consumer" -Language "Spanish" -OutputDir $TEMP_OUTPUT
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

# --- FASE 2K: Subsistema de Diagnóstico Post-Instalación ---
Write-HarnessHeader2 "FASE 2K: Subsistema de Diagnostico Post-Instalacion"
$diagTestDir = Join-Path $TEMP_ROOT "DiagTest"
New-Item -ItemType Directory $diagTestDir -Force | Out-Null

$v2Content = Get-Content -Path (Join-Path $PSScriptRoot "New-OptimizedWindowsISO-v2.ps1") -Raw -ErrorAction SilentlyContinue

Assert-True "PostInstall: Plantilla PostInstall-Diagnostics.ps1 presente en v2" ($v2Content -match 'postInstallDiagTemplate\s*=')
Assert-True "PostInstall: Lanzador Auditar-Instalacion.cmd presente en v2" ($v2Content -match 'auditarLauncherContent\s*=')
Assert-True "PostInstall: SetupComplete.cmd invoca PostInstall-Diagnostics.ps1" ($v2Content -match 'PostInstall-Diagnostics\.ps1.*-DesktopOutput')
Assert-False "autounattend.xml: Sin directivas invalidas WillContinueOnFailure" ($v2Content -match '<WillContinueOnFailure>')

# Extraer y ejecutar sintácticamente PostInstall-Diagnostics.ps1 en sandbox
$diagMatch = [regex]::Match($v2Content, '(?s)\$postInstallDiagTemplate\s*=\s*@''\r?\n(.*?)\r?\n''@')
if ($diagMatch.Success) {
    $extractedDiag = $diagMatch.Groups[1].Value.Replace('__OPT_PROFILE__', '3').Replace('__BLOCK_ONEDRIVE__', '$true')
    $testScriptPath = Join-Path $diagTestDir "PostInstall-Diagnostics.ps1"
    [System.IO.File]::WriteAllText($testScriptPath, $extractedDiag, [System.Text.Encoding]::UTF8)

    # Validar AST del script de diagnóstico
    $diagTokens = $null
    $diagErrors = $null
    $diagAst = [System.Management.Automation.Language.Parser]::ParseInput($extractedDiag, [ref]$diagTokens, [ref]$diagErrors)
    Assert-Equal "PostInstall: Script generado tiene sintaxis valida sin errores AST" $diagErrors.Count 0

    # Ejecutar en sandbox con powershell.exe nativo
    $outReportDir = Join-Path $diagTestDir "Logs"
    Assert-NoThrow "PostInstall: Ejecucion segura en sandbox genera reporte sin excepciones" {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $testScriptPath -OutputDir $outReportDir
    }

    $genReport = Join-Path $outReportDir "PostInstall_Report.md"
    Assert-FileExists "PostInstall: Reporte PostInstall_Report.md generado en disco" $genReport
    if (Test-Path $genReport) {
        $repContent = Get-Content -Path $genReport -Raw -Encoding UTF8
        Assert-True "PostInstall: Reporte contiene encabezado de auditoria" ($repContent -match 'Reporte de Auditoria y Diagnostico Post-Instalacion')
        Assert-True "PostInstall: Reporte contiene seccion de logs de Setup" ($repContent -match 'Auditoria de Logs Oficiales de Windows Setup')
        Assert-True "PostInstall: Reporte contiene seccion de SetupComplete" ($repContent -match 'Auditoria de SetupComplete\.cmd')
        Assert-True "PostInstall: Reporte contiene seccion de Tweaks y Registro" ($repContent -match 'Estado de Tweaks, Registro y Bypasses')
        Assert-True "PostInstall: Reporte contiene seccion de Servicios" ($repContent -match 'Estado de Servicios de Rendimiento')
        Assert-True "PostInstall: Reporte contiene seccion de Controladores PnP" ($repContent -match 'Auditoria de Hardware y Controladores')
        Assert-True "PostInstall: Reporte contiene Resumen Ejecutivo" ($repContent -match 'Resumen Ejecutivo de Instalacion')
    }
} else {
    Assert-True "PostInstall: No se pudo extraer la plantilla para pruebas unitarias" $false
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
    if (Test-Path $TEMP_ROOT) { Remove-Item -Path $TEMP_ROOT -Recurse -Force -ErrorAction SilentlyContinue }
} catch {}

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
