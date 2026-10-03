<#
.SYNOPSIS
    Invoke-WindowsSecurityHardening.ps1 - Auditoria de Seguridad y Hardening Desacoplado (On-Demand)
    Toolkit de SysAdmin y Alto Rendimiento romanOS

.DESCRIPTION
    Audita la postura de seguridad del sistema operativo Windows 11 bajo demanda (sin servicios
    ni procesos residentes en segundo plano). Inspecciona reglas ASR de Microsoft Defender,
    Virtualization-Based Security (VBS/HVCI), protocolos obsoletos (SMBv1, LLMNR, NetBIOS),
    seguridad de credenciales (LSA Protection, NTLM) y configuraciones de superficie de ataque.
    Opcionalmente permite aplicar directivas de hardening seguras que preservan la compatibilidad
    con juegos, streaming y anti-cheats (Vanguard, EAC, BattleEye).

.PARAMETER AuditOnly
    Ejecuta unicamente la auditoria de seguridad (solo lectura) y genera el informe detallado (Default: $true).

.PARAMETER ApplySafeHardening
    Aplica directivas de proteccion de bajo impacto compatibles con gaming (desactiva SMBv1, LLMNR,
    habilita LSA Protection, bloquea WPBT y restringe contrasenas en blanco).

.PARAMETER ApplyStrictHardening
    Aplica directivas avanzadas de seguridad corporativa (CIS/ASR en modo bloqueo, NTLMv2 forzado).

.PARAMETER OutputDir
    Directorio donde se guardaran los informes Markdown y HTML generados.

.PARAMETER ShowReport
    Abre el informe HTML generado automaticamente en el navegador web local.

.PARAMETER NonInteractive
    Ejecuta el script sin pausas ni solicitud de confirmacion en consola.

.EXAMPLE
    .\Invoke-WindowsSecurityHardening.ps1 -AuditOnly -ShowReport

.EXAMPLE
    .\Invoke-WindowsSecurityHardening.ps1 -ApplySafeHardening
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$AuditOnly,
    [switch]$ApplySafeHardening,
    [switch]$ApplyStrictHardening,
    [string]$OutputDir,
    [switch]$ShowReport,
    [switch]$NonInteractive,
    [switch]$PassThru,
    [switch]$SkipElevation
)

# -----------------------------------------------------------------------------
# 0. CONFIGURACION DE ENTORNO, BYPASS Y AUTO-ELEVACION UAC
# -----------------------------------------------------------------------------
$ErrorActionPreference = 'Continue'
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop } catch {
    Write-Warning "[Invoke-WindowsSecurityHardening] No se pudo fijar ExecutionPolicy en Scope Process: $($_.Exception.Message)"
}

# Comprobar privilegios de Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and ($ApplySafeHardening -or $ApplyStrictHardening) -and -not $SkipElevation) {
    if ($PSCmdlet.ShouldProcess("powershell.exe", "Auto-elevar privilegios de Administrador UAC")) {
        Write-Host "[!] Elevando privilegios de Administrador para aplicar directivas (UAC)..." -ForegroundColor Yellow
        $scriptPath = $MyInvocation.MyCommand.Definition
        if (-not $scriptPath) { $scriptPath = $PSCommandPath }
        
        $argList = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath)
        if ($AuditOnly) { $argList += '-AuditOnly' }
        if ($ApplySafeHardening) { $argList += '-ApplySafeHardening' }
        if ($ApplyStrictHardening) { $argList += '-ApplyStrictHardening' }
        if ($OutputDir) { $argList += @('-OutputDir', $OutputDir) }
        if ($ShowReport) { $argList += '-ShowReport' }
        if ($NonInteractive) { $argList += '-NonInteractive' }
        
        try {
            Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs -ErrorAction Stop
            exit
        } catch {
            Write-Warning "Fallo al solicitar elevacion UAC ($($_.Exception.Message)). Continuando en modo estandar..."
        }
    }
}

# -----------------------------------------------------------------------------
# CARGA DE MOTOR VISUAL UNIFICADO O MICRO-FALLBACK STANDALONE
# -----------------------------------------------------------------------------
$uiEnginePaths = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) "Core\UI-Engine.ps1"),
    (Join-Path $PSScriptRoot "Core\UI-Engine.ps1"),
    (Join-Path $PSScriptRoot "UI-Engine.ps1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\UI-Engine.ps1"),
    "$env:WINDIR\Setup\Scripts\Core\UI-Engine.ps1",
    "C:\Windows\Setup\Scripts\Core\UI-Engine.ps1"
)
$uiLoaded = $false
foreach ($p in $uiEnginePaths) {
    if (Test-Path $p) {
        . $p
        $uiLoaded = $true
        break
    }
}
if (-not $uiLoaded) {
    function Show-UnifiedBanner { param($Title,$Subtitle,[switch]$ShowSystemInfo,[switch]$NoClear) Write-Host "`n=== $Title ($Subtitle) ===`n" -ForegroundColor Cyan }
    function Write-StepHeader   { param($StepNumber,$TotalSteps,$Message) Write-Host "`n>>> [$StepNumber/$TotalSteps] $Message" -ForegroundColor Cyan }
    function Write-SubStep      { param($Message) Write-Host "  -> $Message" -ForegroundColor Gray }
    function Write-OK           { param([string]$Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
    function Write-Warn         { param([string]$Message, [string]$Cause = "", [string]$Action = "") Write-Host "  [WARN] $Message $(if($Cause){"(Causa: $Cause)"})" -ForegroundColor Yellow }
    function Write-ErrorMsg     { param([string]$Message, [string]$Cause = "", [string]$Action = "") Write-Host "  [ERROR] $Message $(if($Cause){"(Causa: $Cause)"})" -ForegroundColor Red }
    function Write-Info         { param([string]$Message) Write-Host "  [i] $Message" -ForegroundColor DarkGray }
    function Prompt-UnifiedYesNo { param($Prompt,[bool]$Default=$true) $d=if($Default){"S"}else{"N"}; $r=Read-Host "  [?] $Prompt [S/N] (Default: $d)"; if([string]::IsNullOrWhiteSpace($r)){return $Default}; return ($r -match '^(s|si|y|yes)$') }
    function Show-UnifiedMenu   { param($Title,$Options,[int]$DefaultChoice=1,[switch]$AllowCancel,[string]$CancelText="Salir") for($i=0;$i -lt $Options.Count;$i++){ Write-Host "  [$($i+1)] $($Options[$i])" }; if($AllowCancel){ Write-Host "  [0] $CancelText" }; $r=Read-Host "  Opcion"; if(-not $r){return $DefaultChoice}; return [int]$r }
    function Show-UnifiedSummary { param($Title,$Status,$DurationSeconds,$ErrorsCount,$WarnsCount,$Logs) Write-Host "`n=== $($Title): $Status (${DurationSeconds}s) ===`n" -ForegroundColor Cyan }
    function Get-RomanOSErrorCodeDetails {
        param([long]$ExitCode)
        $intVal = try { [int32]$ExitCode } catch { [int32]($ExitCode -band 0xFFFFFFFFL) }
        return [PSCustomObject]@{ ExitCodeDecimal = $ExitCode; ExitCodeHex = ("0x{0:X8}" -f $intVal) }
    }
    function Write-ForensicProcessFailure {
        param($TaskDescription, $FilePath, [long]$ExitCode, [string]$CommandLine = "", [string]$StdOut = "", [string]$StdErr = "", [string]$LogFilePath = "", [switch]$IsWarningOnly)
        $level = if ($IsWarningOnly) { "WARN" } else { "ERROR" }
        $hexStr = "0x{0:X8}" -f ([int32]$ExitCode)
        $header = "[$level] Fallo en proceso '$TaskDescription' | ExitCode: $ExitCode ($hexStr)"
        Write-Host "  $header" -ForegroundColor $(if($IsWarningOnly){"Yellow"}else{"Red"})
        return [PSCustomObject]@{ Header = $header; ExitCode = $ExitCode; ExitCodeHex = $hexStr; CommandLine = $CommandLine; StdOut = $StdOut; StdErr = $StdErr; FullPlainReport = "$header`n$StdOut`n$StdErr".Trim() }
    }
    function Write-ForensicException {
        param($Record, [string]$Context = "")
        $msg = if ($Record -is [System.Management.Automation.ErrorRecord]) { $Record.Exception.Message } else { "$Record" }
        $header = "[ERROR] $(if($Context){"[$Context] "})$msg"
        Write-Host "  $header" -ForegroundColor Red
        return [PSCustomObject]@{ Header = $header; FullPlainReport = $header }
    }
}

# Determinar directorio de salida
if (-not $OutputDir) {
    if ($env:WINDIR -and (Test-Path "$env:WINDIR\Setup\Logs")) {
        $OutputDir = "$env:WINDIR\Setup\Logs"
    } else {
        $OutputDir = Join-Path $PSScriptRoot "Logs"
    }
}
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$desktopPath = [Environment]::GetFolderPath('Desktop')
if (-not $desktopPath -or -not (Test-Path $desktopPath)) {
    $desktopPath = [Environment]::GetFolderPath('CommonDesktopDirectory')
    if (-not $desktopPath -or -not (Test-Path $desktopPath)) {
        $desktopPath = if ($env:PUBLIC) { "$env:PUBLIC\Desktop" } else { "C:\Users\Public\Desktop" }
    }
}

# -----------------------------------------------------------------------------
# 1. CATALOGO DE REGLAS Y DEFINICIONES DE AUDITORIA
# -----------------------------------------------------------------------------
$asrRulesCatalog = @{
    "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2" = "Bloquear robo de credenciales del subsistema LSASS"
    "01443614-cd74-433a-b99e-2ecdc07bfc25" = "Bloquear ejecutables que no cumplan criterios de prevalencia/antiguedad"
    "e6db77e5-3df2-4cf1-b95a-636979351e5b" = "Bloquear persistencia mediante eventos WMI"
    "d4f940ab-401b-4efc-aadc-ad5f3c50688a" = "Bloquear llamadas Win32 API desde macros de Office"
    "3b5764c1-7a2e-4423-8677-40089f2a934e" = "Bloquear creacion de procesos secundarios desde aplicaciones Office"
    "7563e870-76f3-455b-8007-543e3fc140b9" = "Bloquear inyeccion de codigo en otros procesos desde Office"
    "d3e037e1-3eb8-44c8-a917-57927947596d" = "Bloquear creacion de contenido ejecutable por JavaScript/VBScript"
    "5beb7efe-7951-45c7-9f11-0e6985324b09" = "Bloquear ejecucion de scripts ofuscados potencialmente maliciosos"
    "be9ba2d9-53ea-44a7-8f61-b54c30c9a73e" = "Bloquear llamadas API de Windows sospechosas desde macros VBA"
    "92e97fa1-2edf-4476-bdd6-9dd0b4dddc7b" = "Bloquear creacion de ejecutables desde clientes de correo"
    "c1db55ab-c21a-4637-bb3f-a12568109d35" = "Bloquear ejecucion de procesos desde software Adobe Reader"
    "b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4" = "Bloquear aplicaciones no confiables ejecutandose desde USB"
    "26190899-7702-4c27-a9c7-d0104f9d08b1" = "Bloquear comunicaciones RPC no autenticadas"
}

# Variables de recoleccion de resultados
$auditResults = [System.Collections.Generic.List[PSCustomObject]]::new()
$passedCount = 0
$warningCount = 0
$dangerCount = 0

function Add-AuditItem {
    param(
        [string]$Category,
        [string]$Name,
        [string]$CurrentValue,
        [string]$RecommendedValue,
        [string]$Status, # OK, WARN, DANGER, INFO
        [string]$Description,
        [string]$GamingImpact
    )
    
    $obj = [PSCustomObject]@{
        Category         = $Category
        Name             = $Name
        CurrentValue     = $CurrentValue
        RecommendedValue = $RecommendedValue
        Status           = $Status
        Description      = $Description
        GamingImpact     = $GamingImpact
    }
    $script:auditResults.Add($obj)
    
    switch ($Status) {
        'OK'     { $script:passedCount++ }
        'WARN'   { $script:warningCount++ }
        'DANGER' { $script:dangerCount++ }
    }
}

# -----------------------------------------------------------------------------
# 2. MOTOR DE AUDITORIA DE SEGURIDAD
# -----------------------------------------------------------------------------
function Invoke-SecurityAuditEngine {
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  AUDITORIA DE SEGURIDAD Y HARDENING DESACOPLADO (ON-DEMAND)              " -ForegroundColor Cyan
    Write-Host "  Toolkit romanOS - Analisis de Postura de Seguridad y Superficie         " -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host ""

    # 1. Kernel, Virtualizacion y Firmware
    Write-Host "  [1/5] Auditando Seguridad del Kernel, VBS y Firmware..." -ForegroundColor Yellow
    
    # SecureBoot
    try {
        $sb = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
        if ($sb -eq $true) {
            Add-AuditItem -Category "Kernel & Firmware" -Name "Secure Boot (UEFI)" -CurrentValue "Habilitado" -RecommendedValue "Habilitado" -Status "OK" -Description "Protege la secuencia de arranque contra bootkits." -GamingImpact "Cero impacto en FPS. Requerido por anti-cheats modernos (Vanguard / FaceIT)."
        } else {
            Add-AuditItem -Category "Kernel & Firmware" -Name "Secure Boot (UEFI)" -CurrentValue "Deshabilitado o Legacy" -RecommendedValue "Habilitado" -Status "WARN" -Description "El arranque seguro no esta activo en firmware UEFI." -GamingImpact "Puede impedir jugar titulos con Vanguard (Valorant) en Windows 11."
        }
    } catch {
        $sbReg = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" -Name UEFISecureBootEnabled -ErrorAction SilentlyContinue).UEFISecureBootEnabled
        $status = if ($sbReg -eq 1) { "OK" } else { "WARN" }
        Add-AuditItem -Category "Kernel & Firmware" -Name "Secure Boot (UEFI)" -CurrentValue $(if ($sbReg -eq 1) { "Habilitado" } else { "Deshabilitado/No UEFI" }) -RecommendedValue "Habilitado" -Status $status -Description "Estado de Secure Boot en registro." -GamingImpact "Requerido por anti-cheats."
    }

    # TPM 2.0
    try {
        $tpm = Get-Tpm -ErrorAction SilentlyContinue
        if ($tpm -and $tpm.TpmPresent) {
            $tpmReady = if ($tpm.TpmReady) { "Presente y Listo" } else { "Presente (No inicializado)" }
            $status = if ($tpm.TpmReady) { "OK" } else { "WARN" }
            Add-AuditItem -Category "Kernel & Firmware" -Name "Modulo TPM 2.0" -CurrentValue $tpmReady -RecommendedValue "Presente y Listo" -Status $status -Description "Procesador criptografico para aislamiento de claves." -GamingImpact "Cero impacto en FPS. Requerido para Windows 11 y anti-cheats."
        } else {
            Add-AuditItem -Category "Kernel & Firmware" -Name "Modulo TPM 2.0" -CurrentValue "No detectado" -RecommendedValue "Presente" -Status "WARN" -Description "TPM 2.0 no disponible o deshabilitado en BIOS." -GamingImpact "Requerido por ciertos juegos competitivos."
        }
    } catch {
        Add-AuditItem -Category "Kernel & Firmware" -Name "Modulo TPM 2.0" -CurrentValue "No consultable" -RecommendedValue "Presente" -Status "INFO" -Description "No se pudo consultar estado de TPM." -GamingImpact "Informativo."
    }

    # VBS / DeviceGuard
    try {
        $dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
        if ($dg) {
            $vbsVal = switch ($dg.VirtualizationBasedSecurityStatus) {
                0 { "Deshabilitado (0)" }
                1 { "Habilitado / No en ejecucion (1)" }
                2 { "Habilitado y en ejecucion (2)" }
                default { "Estado $($_)" }
            }
            $vbsStatus = if ($dg.VirtualizationBasedSecurityStatus -eq 2) { "OK" } else { "INFO" }
            Add-AuditItem -Category "Kernel & Firmware" -Name "Virtualization-Based Security (VBS)" -CurrentValue $vbsVal -RecommendedValue "Opcional segun Perfil" -Status $vbsStatus -Description "Aislamiento de procesos sensibles en hipervisor seguro." -GamingImpact "En Perfiles 2 y 3 se desactiva para reducir micro-stuttering y latencia de CPU."
            
            $hvci = if ($dg.SecurityServicesRunning -contains 1) { "En ejecucion" } else { "Deshabilitado" }
            Add-AuditItem -Category "Kernel & Firmware" -Name "Integridad de Memoria (HVCI)" -CurrentValue $hvci -RecommendedValue "Opcional segun Perfil" -Status $(if ($hvci -eq 'En ejecucion') { 'OK' } else { 'INFO' }) -Description "Protege el kernel contra inyeccion de codigo arbitrario." -GamingImpact "Deshabilitado en configuraciones de latencia ultrabaja (Perfil 3)."
        } else {
            Add-AuditItem -Category "Kernel & Firmware" -Name "DeviceGuard / VBS" -CurrentValue "No disponible" -RecommendedValue "N/A" -Status "INFO" -Description "DeviceGuard no soportado en esta edicion o hardware." -GamingImpact "Neutro."
        }
    } catch {
        Add-AuditItem -Category "Kernel & Firmware" -Name "DeviceGuard / VBS" -CurrentValue "Error en consulta" -RecommendedValue "N/A" -Status "INFO" -Description "No se pudo consultar DeviceGuard." -GamingImpact "Neutro."
    }

    # Bloqueo WPBT (Windows Platform Binary Table)
    $wpbtVal = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name DisableWPBT -ErrorAction SilentlyContinue).DisableWPBT
    if ($wpbtVal -eq 1) {
        Add-AuditItem -Category "Kernel & Firmware" -Name "Bloqueo de Inyeccion OEM WPBT" -CurrentValue "Bloqueado (DisableWPBT=1)" -RecommendedValue "Bloqueado (1)" -Status "OK" -Description "Evita que la BIOS/UEFI inyecte bloatware o utilidades OEM en Windows." -GamingImpact "Beneficio puro: evita servicios OEM pesados en segundo plano."
    } else {
        Add-AuditItem -Category "Kernel & Firmware" -Name "Bloqueo de Inyeccion OEM WPBT" -CurrentValue "No configurado (0)" -RecommendedValue "Bloqueado (1)" -Status "WARN" -Description "La tabla ACPI WPBT de la placa base podria inyectar ejecutables OEM." -GamingImpact "Recomendado aplicar para mantener el sistema 100% limpio."
    }

    # 2. Protocolos de Red y Superficie Lateral
    Write-Host "  [2/5] Auditando Protocolos de Red y Superficie Lateral..." -ForegroundColor Yellow
    
    # SMBv1
    $smb1Server = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name SMB1 -ErrorAction SilentlyContinue).SMB1
    if ($smb1Server -eq 0) {
        Add-AuditItem -Category "Red & Protocolos" -Name "Protocolo SMBv1 (WannaCry Vector)" -CurrentValue "Deshabilitado (Seguro)" -RecommendedValue "Deshabilitado (0)" -Status "OK" -Description "Protocolo de comparticion obsoleto e inseguro." -GamingImpact "Cero impacto. Los juegos modernos no usan SMBv1."
    } else {
        Add-AuditItem -Category "Red & Protocolos" -Name "Protocolo SMBv1 (WannaCry Vector)" -CurrentValue "Habilitado o No restringido" -RecommendedValue "Deshabilitado (0)" -Status "DANGER" -Description "Vulnerabilidad critica ante ataques de tipo ransomware lateral." -GamingImpact "Debe desactivarse de inmediato."
    }

    # LLMNR (Link-Local Multicast Name Resolution)
    $llmnr = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name EnableMulticast -ErrorAction SilentlyContinue).EnableMulticast
    if ($llmnr -eq 0) {
        Add-AuditItem -Category "Red & Protocolos" -Name "Resolucion LLMNR (MitM / Responder)" -CurrentValue "Deshabilitado (Seguro)" -RecommendedValue "Deshabilitado (0)" -Status "OK" -Description "Evita ataques de envenenamiento LLMNR y robo de hashes NetNTLM." -GamingImpact "Beneficio de red: reduce trafico de difusion multicast en LAN."
    } else {
        Add-AuditItem -Category "Red & Protocolos" -Name "Resolucion LLMNR (MitM / Responder)" -CurrentValue "Habilitado por defecto" -RecommendedValue "Deshabilitado (0)" -Status "WARN" -Description "Permite a atacantes en la misma red LAN capturar hashes NTLM." -GamingImpact "Recomendado desactivar para seguridad en redes compartidas/WiFi."
    }

    # Autenticacion NTLM / LmCompatibilityLevel
    $lmLevel = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name LmCompatibilityLevel -ErrorAction SilentlyContinue).LmCompatibilityLevel
    if ($lmLevel -ge 5) {
        Add-AuditItem -Category "Red & Protocolos" -Name "Nivel de Autenticacion NTLM" -CurrentValue "NTLMv2 Forzado (Nivel $lmLevel)" -RecommendedValue "NTLMv2 (Nivel 5)" -Status "OK" -Description "Rechaza hashes LM y NTLMv1 debiles." -GamingImpact "Cero impacto en juegos."
    } else {
        Add-AuditItem -Category "Red & Protocolos" -Name "Nivel de Autenticacion NTLM" -CurrentValue "Hibrido / NTLMv1 permitido ($lmLevel)" -RecommendedValue "NTLMv2 (Nivel 5)" -Status "WARN" -Description "Permite negociar versiones debiles de NTLM." -GamingImpact "Se puede forzar NTLMv2 sin afectar juegos."
    }

    # Escritorio Remoto NLA
    $rdpNLA = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name UserAuthentication -ErrorAction SilentlyContinue).UserAuthentication
    if ($rdpNLA -eq 1) {
        Add-AuditItem -Category "Red & Protocolos" -Name "Escritorio Remoto (RDP NLA)" -CurrentValue "NLA Requerido (1)" -RecommendedValue "NLA Requerido (1)" -Status "OK" -Description "Exige autenticacion a nivel de red previa a la sesion RDP." -GamingImpact "Cero impacto."
    } else {
        Add-AuditItem -Category "Red & Protocolos" -Name "Escritorio Remoto (RDP NLA)" -CurrentValue "NLA No forzado ($rdpNLA)" -RecommendedValue "NLA Requerido (1)" -Status "WARN" -Description "RDP expone pantalla de login sin autenticacion de red." -GamingImpact "Recomendado habilitar NLA."
    }

    # 3. Credenciales, Cuentas y Privilegios
    Write-Host "  [3/5] Auditando Credenciales, LSA y Cuentas Locales..." -ForegroundColor Yellow
    
    # LSA Protection (RunAsPPL)
    $lsaPPL = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name RunAsPPL -ErrorAction SilentlyContinue).RunAsPPL
    if ($lsaPPL -ge 1) {
        Add-AuditItem -Category "Cuentas & Credenciales" -Name "Proteccion LSA (RunAsPPL)" -CurrentValue "Habilitado (PPL=$lsaPPL)" -RecommendedValue "Habilitado (1)" -Status "OK" -Description "Protege el proceso lsass.exe contra lectura de memoria por malware (Mimikatz)." -GamingImpact "Cero impacto en FPS. Blindaje critico de credenciales."
    } else {
        Add-AuditItem -Category "Cuentas & Credenciales" -Name "Proteccion LSA (RunAsPPL)" -CurrentValue "Deshabilitado (0)" -RecommendedValue "Habilitado (1)" -Status "WARN" -Description "lsass.exe puede ser dumpeado por procesos con permisos elevados." -GamingImpact "Altamente recomendado habilitar."
    }

    # Control de Cuentas de Usuario (UAC)
    $uacLua = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name EnableLUA -ErrorAction SilentlyContinue).EnableLUA
    if ($uacLua -eq 1) {
        Add-AuditItem -Category "Cuentas & Credenciales" -Name "Control de Cuentas de Usuario (UAC)" -CurrentValue "Habilitado (Seguro)" -RecommendedValue "Habilitado (1)" -Status "OK" -Description "Evita la ejecucion silenciosa de malware con permisos administrativos." -GamingImpact "Protege contra modificaciones no autorizadas del sistema."
    } else {
        Add-AuditItem -Category "Cuentas & Credenciales" -Name "Control de Cuentas de Usuario (UAC)" -CurrentValue "Deshabilitado (Inseguro)" -RecommendedValue "Habilitado (1)" -Status "DANGER" -Description "UAC deshabilitado: cualquier proceso puede tomar control total del SO." -GamingImpact "Peligro de infeccion silenciosa."
    }

    # Limite de Contraseñas en Blanco (LimitBlankPasswordUse)
    $blankPass = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name LimitBlankPasswordUse -ErrorAction SilentlyContinue).LimitBlankPasswordUse
    if ($blankPass -eq 1 -or $null -eq $blankPass) {
        Add-AuditItem -Category "Cuentas & Credenciales" -Name "Restriccion de Cuentas sin Clave" -CurrentValue "Restringido solo a consola local (1)" -RecommendedValue "Restringido (1)" -Status "OK" -Description "Impide inicio de sesion por red en cuentas locales sin contrasena." -GamingImpact "Cero impacto."
    } else {
        Add-AuditItem -Category "Cuentas & Credenciales" -Name "Restriccion de Cuentas sin Clave" -CurrentValue "Permitido por red (0)" -RecommendedValue "Restringido (1)" -Status "DANGER" -Description "Cuentas sin clave pueden ser accedidas remotamente via red." -GamingImpact "Debe restringirse."
    }

    # Servicio RemoteRegistry
    $rrSvc = Get-Service -Name RemoteRegistry -ErrorAction SilentlyContinue
    if (-not $rrSvc -or $rrSvc.StartType -eq 'Disabled') {
        Add-AuditItem -Category "Cuentas & Credenciales" -Name "Servicio Registro Remoto (RemoteRegistry)" -CurrentValue "Deshabilitado / No disponible" -RecommendedValue "Deshabilitado" -Status "OK" -Description "Cierra la via de modificacion remota del registro de Windows." -GamingImpact "Ahorro de recursos y eliminacion de superficie de ataque."
    } else {
        Add-AuditItem -Category "Cuentas & Credenciales" -Name "Servicio Registro Remoto (RemoteRegistry)" -CurrentValue "Estado: $($rrSvc.Status) ($($rrSvc.StartType))" -RecommendedValue "Deshabilitado" -Status "WARN" -Description "Permite la consulta y edicion remota del registro de Windows." -GamingImpact "Recomendado deshabilitar."
    }

    # 4. Reglas ASR de Microsoft Defender
    Write-Host "  [4/5] Auditando Reglas de Reduccion de Superficie de Ataque (ASR)..." -ForegroundColor Yellow
    
    try {
        $mpPref = Get-MpPreference -ErrorAction SilentlyContinue
        $activeAsrIds = @($mpPref.AttackSurfaceReductionRules_Ids)
        $activeAsrActions = @($mpPref.AttackSurfaceReductionRules_Actions)
        
        $asrMap = @{}
        for ($i = 0; $i -lt $activeAsrIds.Count; $i++) {
            $asrMap[$activeAsrIds[$i]] = $activeAsrActions[$i]
        }
        
        $configuredAsr = 0
        foreach ($ruleId in $asrRulesCatalog.Keys) {
            $ruleName = $asrRulesCatalog[$ruleId]
            if ($asrMap.ContainsKey($ruleId)) {
                $actionCode = $asrMap[$ruleId]
                $actionStr = switch ($actionCode) {
                    0 { "Deshabilitada (0)" }
                    1 { "Bloqueo Activo (1)" }
                    2 { "Modo Auditoria (2)" }
                    6 { "Modo Advertencia (6)" }
                    default { "Codigo ($actionCode)" }
                }
                $status = if ($actionCode -eq 1) { "OK" } elseif ($actionCode -in 2,6) { "INFO" } else { "WARN" }
                if ($actionCode -eq 1) { $configuredAsr++ }
                Add-AuditItem -Category "Reglas ASR (Defender)" -Name $ruleName -CurrentValue $actionStr -RecommendedValue "Bloqueo (1) u Opcional" -Status $status -Description "Regla ASR: $ruleId" -GamingImpact "Cero impacto en juegos legitimos. Bloquea tecnicas de malware comunes."
            } else {
                Add-AuditItem -Category "Reglas ASR (Defender)" -Name $ruleName -CurrentValue "No configurada (Default)" -RecommendedValue "Bloqueo (1)" -Status "INFO" -Description "Regla ASR: $ruleId" -GamingImpact "Configurable bajo demanda."
            }
        }
    } catch {
        Add-AuditItem -Category "Reglas ASR (Defender)" -Name "Motor Microsoft Defender ASR" -CurrentValue "No consultable o Defender inactivo" -RecommendedValue "Activo" -Status "INFO" -Description "No se pudo consultar Get-MpPreference." -GamingImpact "Neutro."
    }

    # 5. Privacidad y Telemetria Residual
    Write-Host "  [5/5] Auditando Privacidad del Sistema y Telemetria..." -ForegroundColor Yellow
    
    $diagData = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name AllowTelemetry -ErrorAction SilentlyContinue).AllowTelemetry
    if ($null -eq $diagData) {
        $diagData = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name MaxTelemetryAllowed -ErrorAction SilentlyContinue).MaxTelemetryAllowed
    }
    $diagStr = switch ($diagData) {
        0 { "Deshabilitada / Seguridad (0)" }
        1 { "Basica / Minima (1)" }
        3 { "Completa / Diagnosticos extendidos (3)" }
        default { "Nivel ($diagData)" }
    }
    $status = if ($diagData -le 1) { "OK" } else { "WARN" }
    Add-AuditItem -Category "Privacidad & Telemetria" -Name "Nivel de Recoleccion de Telemetria" -CurrentValue $diagStr -RecommendedValue "Minima o Deshabilitada (0 o 1)" -Status $status -Description "Nivel de envio de telemetria hacia servidores de Microsoft." -GamingImpact "Minimizar telemetria ahorra ancho de banda e interrupciones de CPU."

    $advId = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name Enabled -ErrorAction SilentlyContinue).Enabled
    if ($advId -eq 0) {
        Add-AuditItem -Category "Privacidad & Telemetria" -Name "ID de Publicidad Personalizada" -CurrentValue "Deshabilitado (0)" -RecommendedValue "Deshabilitado (0)" -Status "OK" -Description "Evita el rastreo publicitario entre aplicaciones." -GamingImpact "Beneficio de privacidad puro."
    } else {
        Add-AuditItem -Category "Privacidad & Telemetria" -Name "ID de Publicidad Personalizada" -CurrentValue "Habilitado (1)" -RecommendedValue "Deshabilitado (0)" -Status "WARN" -Description "ID de publicidad activo para anuncios en apps." -GamingImpact "Recomendado deshabilitar."
    }
}

# -----------------------------------------------------------------------------
# 3. MOTOR DE APLICACION DE HARDENING SEGURO (ON-DEMAND)
# -----------------------------------------------------------------------------
function Invoke-ApplySafeHardeningEngine {
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "  APLICANDO HARDENING SEGURO PARA GAMING & ALTO RENDIMIENTO (ON-DEMAND)   " -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host ""

    # 1. Bloqueo de WPBT en Registro
    Write-Host "  [+] Bloqueando inyeccion de binarios OEM (DisableWPBT = 1)..." -ForegroundColor White
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v "DisableWPBT" /t REG_DWORD /d 1 /f | Out-Null

    # 2. Deshabilitar SMBv1 de forma definitiva
    Write-Host "  [+] Deshabilitando protocolo inseguro SMBv1..." -ForegroundColor White
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "SMB1" /t REG_DWORD /d 0 /f | Out-Null
    try {
        Disable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -NoRestart -ErrorAction Stop | Out-Null
    } catch {
        Write-Warn "No se pudo deshabilitar la característica SMB1Protocol: $($_.Exception.Message)"
    }

    # 3. Deshabilitar LLMNR para evitar ataques MitM en red local
    Write-Host "  [+] Deshabilitando resolucion LLMNR en DNS Client..." -ForegroundColor White
    if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Force | Out-Null
    }
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v "EnableMulticast" /t REG_DWORD /d 0 /f | Out-Null

    # 4. Habilitar Proteccion LSA (RunAsPPL)
    Write-Host "  [+] Habilitando proteccion LSA contra dumpeo de credenciales (RunAsPPL = 1)..." -ForegroundColor White
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "RunAsPPL" /t REG_DWORD /d 1 /f | Out-Null

    # 5. Restringir Contraseñas en Blanco para Acceso Remoto
    Write-Host "  [+] Restringiendo uso de contrasenas en blanco por red..." -ForegroundColor White
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "LimitBlankPasswordUse" /t REG_DWORD /d 1 /f | Out-Null

    # 6. Deshabilitar Servicio RemoteRegistry
    Write-Host "  [+] Deshabilitando servicio de Registro Remoto (RemoteRegistry)..." -ForegroundColor White
    try {
        Set-Service -Name RemoteRegistry -StartupType Disabled -ErrorAction Stop
        Stop-Service -Name RemoteRegistry -Force -ErrorAction Stop
    } catch {
        Write-Warn "No se pudo deshabilitar o detener RemoteRegistry: $($_.Exception.Message)"
    }

    # 7. Forzar Autenticacion NTLMv2 (LmCompatibilityLevel = 5)
    Write-Host "  [+] Forzando autenticacion segura NTLMv2 (LmCompatibilityLevel = 5)..." -ForegroundColor White
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "LmCompatibilityLevel" /t REG_DWORD /d 5 /f | Out-Null

    # 8. Exigir NLA en Escritorio Remoto (RDP)
    Write-Host "  [+] Exigiendo autenticacion a nivel de red (NLA) en RDP..." -ForegroundColor White
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "UserAuthentication" /t REG_DWORD /d 1 /f | Out-Null

    # 9. Desactivar ID de Publicidad y Telemetria Residual
    Write-Host "  [+] Desactivando ID de Publicidad y minimizando telemetria..." -ForegroundColor White
    if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Force | Out-Null
    }
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d 0 /f | Out-Null

    Write-Host ""
    Write-Host "  [OK] Hardening seguro aplicado exitosamente sin servicios residentes." -ForegroundColor Green
    Write-Host ""
}

# -----------------------------------------------------------------------------
# 4. GENERADOR DE REPORTES (MARKDOWN Y HTML DASHBOARD)
# -----------------------------------------------------------------------------
function Export-SecurityAuditReports {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $totalChecks = $script:auditResults.Count
    $score = if ($totalChecks -gt 0) {
        [math]::Round((($script:passedCount * 100) + ($script:warningCount * 40)) / ($totalChecks * 100) * 100, 0)
    } else { 100 }

    # Generar Reporte Markdown
    $md = [System.Collections.Generic.List[string]]::new()
    $md.Add("# Reporte de Auditoria de Seguridad y Hardening Desacoplado")
    $md.Add("")
    $md.Add("- **Fecha:** $timestamp")
    $md.Add("- **Equipo:** $env:COMPUTERNAME | **Usuario:** $env:USERNAME")
    $md.Add("- **Puntuacion de Seguridad:** **$score / 100**")
    $md.Add("- **Verificaciones Aprobadas:** $($script:passedCount) | **Advertencias:** $($script:warningCount) | **Criticos:** $($script:dangerCount)")
    $md.Add("")
    $md.Add("## Detalle de Auditoria por Componente")
    $md.Add("")
    $md.Add("| Categoria | Parametro Auditado | Valor Actual | Recomendado | Estado | Impacto en Gaming |")
    $md.Add("|---|---|---|---|---|---|")
    
    foreach ($item in $script:auditResults) {
        $badge = switch ($item.Status) {
            'OK'     { '[OK]' }
            'WARN'   { '[WARN]' }
            'DANGER' { '[DANGER]' }
            default  { '[INFO]' }
        }
        $md.Add("| $($item.Category) | $($item.Name) | $($item.CurrentValue) | $($item.RecommendedValue) | $badge | $($item.GamingImpact) |")
    }
    
    $mdText = $md -join "`r`n"
    $mdFilePath = Join-Path $OutputDir "SecurityAudit_Report.md"
    $desktopMdFilePath = Join-Path $desktopPath "INFORME_SEGURIDAD.md"
    $finalMdPath = $mdFilePath
    try {
        [System.IO.File]::WriteAllText($mdFilePath, $mdText, [System.Text.Encoding]::UTF8)
    } catch {
        $mdFilePath = Join-Path $env:TEMP "SecurityAudit_Report.md"
        $finalMdPath = $mdFilePath
        try {
            [System.IO.File]::WriteAllText($mdFilePath, $mdText, [System.Text.Encoding]::UTF8)
        } catch {
            Write-Warn -Message "No se pudo escribir el reporte Markdown en $mdFilePath" -Cause $_.Exception.Message -Action "El archivo Markdown no pudo ser creado"
        }
    }
    try { 
        [System.IO.File]::WriteAllText($desktopMdFilePath, $mdText, [System.Text.Encoding]::UTF8)
        $finalMdPath = $desktopMdFilePath
    } catch {
        Write-Warn -Message "No se pudo copiar el informe de seguridad al escritorio del usuario." -Cause $_.Exception.Message -Action "El informe permanece disponible en $mdFilePath"
    }

    # Generar Reporte HTML Offline Dashboard
    $htmlRows = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $script:auditResults) {
        $badgeClass = switch ($item.Status) {
            'OK'     { 'badge-ok' }
            'WARN'   { 'badge-warn' }
            'DANGER' { 'badge-danger' }
            default  { 'badge-info' }
        }
        $catEsc = [System.Security.SecurityElement]::Escape("$($item.Category)")
        $nameEsc = [System.Security.SecurityElement]::Escape("$($item.Name)")
        $descEsc = [System.Security.SecurityElement]::Escape("$($item.Description)")
        $curEsc = [System.Security.SecurityElement]::Escape("$($item.CurrentValue)")
        $recEsc = [System.Security.SecurityElement]::Escape("$($item.RecommendedValue)")
        $gameEsc = [System.Security.SecurityElement]::Escape("$($item.GamingImpact)")

        $row = @"
        <tr>
            <td><strong>$catEsc</strong></td>
            <td>$nameEsc<br><small class="text-muted">$descEsc</small></td>
            <td><code>$curEsc</code></td>
            <td><code>$recEsc</code></td>
            <td><span class="badge $badgeClass">$($item.Status)</span></td>
            <td><small>$gameEsc</small></td>
        </tr>
"@
        $htmlRows.Add($row)
    }

    $htmlContent = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>romanOS - Auditoria de Seguridad y Hardening</title>
    <style>
        :root {
            --bg-dark: #0f172a;
            --card-bg: #1e293b;
            --border-color: #334155;
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --accent: #38bdf8;
            --ok: #22c55e;
            --warn: #eab308;
            --danger: #ef4444;
            --info: #06b6d4;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif; }
        body { background-color: var(--bg-dark); color: var(--text-main); line-height: 1.6; padding: 30px 20px; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border-color); padding-bottom: 20px; margin-bottom: 25px; flex-wrap: wrap; gap: 15px; }
        .header h1 { font-size: 1.8rem; color: var(--text-main); display: flex; align-items: center; gap: 10px; }
        .header h1 span { color: var(--accent); }
        .header .meta { color: var(--text-muted); font-size: 0.9rem; text-align: right; }
        .score-cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 15px; margin-bottom: 30px; }
        .card { background-color: var(--card-bg); border: 1px solid var(--border-color); border-radius: 10px; padding: 20px; text-align: center; }
        .card-number { font-size: 2.2rem; font-weight: 700; margin-bottom: 5px; }
        .card-label { color: var(--text-muted); font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.5px; }
        .score-val { color: var(--accent); }
        .ok-val { color: var(--ok); }
        .warn-val { color: var(--warn); }
        .danger-val { color: var(--danger); }
        .table-container { background-color: var(--card-bg); border: 1px solid var(--border-color); border-radius: 10px; overflow-x: auto; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.3); }
        table { width: 100%; border-collapse: collapse; text-align: left; font-size: 0.92rem; }
        th { background-color: #182234; color: var(--text-muted); font-weight: 600; padding: 14px 16px; border-bottom: 1px solid var(--border-color); text-transform: uppercase; font-size: 0.8rem; letter-spacing: 0.5px; }
        td { padding: 14px 16px; border-bottom: 1px solid var(--border-color); vertical-align: middle; }
        tr:last-child td { border-bottom: none; }
        tr:hover { background-color: #243248; }
        code { background-color: #0b1120; color: #38bdf8; padding: 3px 6px; border-radius: 4px; font-size: 0.85rem; font-family: Consolas, monospace; }
        .badge { display: inline-block; padding: 4px 8px; border-radius: 6px; font-size: 0.75rem; font-weight: 700; text-transform: uppercase; }
        .badge-ok { background-color: rgba(34, 197, 94, 0.15); color: var(--ok); border: 1px solid var(--ok); }
        .badge-warn { background-color: rgba(234, 179, 8, 0.15); color: var(--warn); border: 1px solid var(--warn); }
        .badge-danger { background-color: rgba(239, 68, 68, 0.15); color: var(--danger); border: 1px solid var(--danger); }
        .badge-info { background-color: rgba(6, 182, 212, 0.15); color: var(--info); border: 1px solid var(--info); }
        .text-muted { color: var(--text-muted); }
        .footer { margin-top: 30px; text-align: center; color: var(--text-muted); font-size: 0.85rem; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div>
                <h1><span>🛡️ romanOS</span> Auditoria de Seguridad & Hardening</h1>
                <div class="text-muted">Postura de Seguridad Desacoplada (On-Demand) | Rendimiento Puro</div>
            </div>
            <div class="meta">
                <div><strong>Equipo:</strong> $env:COMPUTERNAME</div>
                <div><strong>Fecha:</strong> $timestamp</div>
            </div>
        </div>

        <div class="score-cards">
            <div class="card">
                <div class="card-number score-val">$score / 100</div>
                <div class="card-label">Puntuacion de Seguridad</div>
            </div>
            <div class="card">
                <div class="card-number ok-val">$($script:passedCount)</div>
                <div class="card-label">Verificaciones Aprobadas</div>
            </div>
            <div class="card">
                <div class="card-number warn-val">$($script:warningCount)</div>
                <div class="card-label">Advertencias</div>
            </div>
            <div class="card">
                <div class="card-number danger-val">$($script:dangerCount)</div>
                <div class="card-label">Riesgos Criticos</div>
            </div>
        </div>

        <div class="table-container">
            <table>
                <thead>
                    <tr>
                        <th>Categoria</th>
                        <th>Parametro Auditado</th>
                        <th>Valor Actual</th>
                        <th>Recomendado</th>
                        <th>Estado</th>
                        <th>Impacto en Gaming</th>
                    </tr>
                </thead>
                <tbody>
                    $($htmlRows -join "`r`n")
                </tbody>
            </table>
        </div>

        <div class="footer">
            Generado por <strong>romanOS Toolkit Maestro</strong> &bull; Auditoria 100% On-Demand sin servicios en segundo plano.
        </div>
    </div>
</body>
</html>
"@

    $htmlFilePath = Join-Path $OutputDir "SecurityAudit_Report.html"
    $desktopHtmlFilePath = Join-Path $desktopPath "INFORME_SEGURIDAD.html"
    $finalHtmlPath = $htmlFilePath
    try {
        [System.IO.File]::WriteAllText($htmlFilePath, $htmlContent, [System.Text.Encoding]::UTF8)
    } catch {
        $htmlFilePath = Join-Path $env:TEMP "SecurityAudit_Report.html"
        $finalHtmlPath = $htmlFilePath
        try {
            [System.IO.File]::WriteAllText($htmlFilePath, $htmlContent, [System.Text.Encoding]::UTF8)
        } catch {
            Write-Warn -Message "No se pudo escribir el reporte HTML en $htmlFilePath" -Cause $_.Exception.Message -Action "El archivo HTML no pudo ser creado"
        }
    }
    try { 
        [System.IO.File]::WriteAllText($desktopHtmlFilePath, $htmlContent, [System.Text.Encoding]::UTF8)
        $finalHtmlPath = $desktopHtmlFilePath
    } catch {
        Write-Warn -Message "No se pudo copiar el dashboard HTML de seguridad al escritorio del usuario." -Cause $_.Exception.Message -Action "El dashboard permanece disponible en $htmlFilePath"
    }

    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  RESUMEN DE AUDITORIA DE SEGURIDAD                                       " -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  Puntuacion de Seguridad   : $score / 100" -ForegroundColor $(if ($score -ge 80) { 'Green' } elseif ($score -ge 50) { 'Yellow' } else { 'Red' })
    Write-Host "  Verificaciones Aprobadas  : $($script:passedCount)" -ForegroundColor Green
    Write-Host "  Advertencias              : $($script:warningCount)" -ForegroundColor $(if ($script:warningCount -gt 0) { 'Yellow' } else { 'Gray' })
    Write-Host "  Riesgos Criticos          : $($script:dangerCount)" -ForegroundColor $(if ($script:dangerCount -gt 0) { 'Red' } else { 'Gray' })
    Write-Host "  Reporte Markdown guardado : $finalMdPath" -ForegroundColor Cyan
    Write-Host "  Reporte HTML guardado     : $finalHtmlPath" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host ""

    if ($ShowReport -or (Test-Path $finalHtmlPath)) {
        if ($ShowReport) {
            Start-Process -FilePath $finalHtmlPath
        }
    }
}

# -----------------------------------------------------------------------------
# 5. FLUJO PRINCIPAL DE EJECUCION
# -----------------------------------------------------------------------------
Show-UnifiedBanner -Title "AUDITORIA DE SEGURIDAD Y HARDENING" -Subtitle "ASR, VBS/HVCI, Protocolos y Reduccion de Superficie de Ataque" -ShowSystemInfo

if ($ApplySafeHardening) {
    Invoke-ApplySafeHardeningEngine
    Invoke-SecurityAuditEngine
    Export-SecurityAuditReports
} elseif ($ApplyStrictHardening) {
    Invoke-ApplySafeHardeningEngine
    # ASR Enforcement
    try {
        Write-Info "Habilitando reglas ASR de Microsoft Defender en modo bloqueo..."
        foreach ($ruleId in $asrRulesCatalog.Keys) {
            Add-MpPreference -AttackSurfaceReductionRules_Ids $ruleId -AttackSurfaceReductionRules_Actions 1 -ErrorAction Stop
        }
    } catch {
        Write-Warn "No se pudieron habilitar todas las reglas ASR de Defender: $($_.Exception.Message)"
    }
    Invoke-SecurityAuditEngine
    Export-SecurityAuditReports
} else {
    # Modo Auditoria (Default)
    Invoke-SecurityAuditEngine
    Export-SecurityAuditReports
    
    if (-not $NonInteractive -and -not $AuditOnly) {
        $applyChoice = Prompt-UnifiedYesNo -Prompt "¿Desea aplicar el Hardening Seguro para Gaming (Cero impacto en FPS)?" -Default $false
        if ($applyChoice) {
            if (-not $isAdmin) {
                Write-Warn "Se requieren privilegios de Administrador para aplicar directivas en el registro..."
                $scriptPath = $MyInvocation.MyCommand.Definition
                if (-not $scriptPath) { $scriptPath = $PSCommandPath }
                Start-Process -FilePath "powershell.exe" -ArgumentList @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath, '-ApplySafeHardening', '-ShowReport') -Verb RunAs
                exit
            }
            Invoke-ApplySafeHardeningEngine
            # Re-auditar
            $script:auditResults.Clear()
            $script:passedCount = 0
            $script:warningCount = 0
            $script:dangerCount = 0
            Invoke-SecurityAuditEngine
            Export-SecurityAuditReports
        }
    }
}

Write-OK "Proceso de auditoria y hardening finalizado exitosamente."

if ($PassThru) {
    return [PSCustomObject]@{
        TotalAudits  = $script:auditResults.Count
        PassedCount  = $script:passedCount
        WarningCount = $script:warningCount
        DangerCount  = $script:dangerCount
        Results      = $script:auditResults
    }
}
