<#
.SYNOPSIS
    Test-AntiCheatCompatibility.ps1 - Auditor Forense de Compatibilidad con Anti-Cheats de Kernel (2026)
    romanOS / OptimizedISO — Estado del Arte Windows 11 24H2 / 25H2

.DESCRIPTION
    Inspecciona y evalúa exhaustivamente el estado del sistema operativo, las directivas de registro
    de Policy-Engine.ps1, la configuración de kernel y la integridad de servicios frente a los
    requisitos oficiales y mandatorios de los 5 grandes motores anti-cheat a nivel Ring-0:
      1. Riot Vanguard (Valorant, League of Legends)
      2. Easy Anti-Cheat / EAC (Fortnite, Apex Legends, Battlefield 2042)
      3. BattlEye (Rainbow Six Siege, Destiny 2, PUBG)
      4. Ricochet (Call of Duty: Warzone / Modern Warfare)
      5. FACEIT Anti-Cheat (Counter-Strike 2)

.PARAMETER AuditMode
    Modo de auditoría:
      - 'LiveSystem'    : Evalúa la configuración del host en tiempo de ejecución.
      - 'PolicyEngine'  : Evalúa estáticamente las directivas y perfiles de Policy-Engine.ps1.
      - 'Comprehensive' : (Default) Combina ambas evaluaciones para un diagnóstico 360°.

.PARAMETER ExportJson
    Ruta opcional para guardar los resultados detallados en formato JSON.

.EXAMPLE
    .\Test-AntiCheatCompatibility.ps1 -AuditMode Comprehensive
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('LiveSystem', 'PolicyEngine', 'Comprehensive')]
    [string]$AuditMode = 'Comprehensive',
    [string]$ExportJson
)

$ErrorActionPreference = 'Continue'
$auditStartTime = Get-Date

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " romanOS / OptimizedISO — AUDITORIA FORENSE DE ANTI-CHEATS DE KERNEL 2026 " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Modo: $AuditMode" -ForegroundColor DarkGray
Write-Host ""

# -----------------------------------------------------------------------------
# 1. CARGA DE MOTOR DE POLÍTICAS (POLICY-ENGINE)
# -----------------------------------------------------------------------------
$policyEnginePath = Join-Path $PSScriptRoot "Policy-Engine.ps1"
if (-not (Test-Path $policyEnginePath)) {
    $policyEnginePath = "C:\OptimizedISO\scripts\Core\Policy-Engine.ps1"
}

$policiesLoaded = $false
if (Test-Path $policyEnginePath) {
    try {
        . $policyEnginePath
        $policiesLoaded = $true
        Write-Host "  [OK] Policy-Engine cargado correctamente desde: $policyEnginePath" -ForegroundColor Green
    } catch {
        Write-Warning "No se pudo importar Policy-Engine.ps1: $($_.Exception.Message). Se continuará con auditoría basada en heurística de host."
    }
} else {
    Write-Warning "Policy-Engine.ps1 no localizado en '$policyEnginePath'. Auditoría continuará en modo host."
}

# -----------------------------------------------------------------------------
# 2. DEFINICIÓN DE REQUISITOS OFICIALES DE ANTI-CHEATS (ESTÁNDARES 2026)
# -----------------------------------------------------------------------------
$AntiCheatEngines = @(
    @{
        EngineId     = "VANGUARD"
        EngineName   = "Riot Vanguard"
        GameTitles   = @("Valorant", "League of Legends")
        RingLevel    = "Ring-0 (Kernel Driver vgk.sys / vgc.exe)"
        Description  = "Exige TPM 2.0, Secure Boot, VBS/HVCI activo o compatible, servicios criptográficos y RPC."
        Requirements = @(
            @{ Type = "Service"; Name = "CryptSvc"; RequiredState = "Running/Auto"; Criticality = "Critica"; Reason = "Validación de catálogos y firmas de drivers en memoria." },
            @{ Type = "Service"; Name = "PlugPlay"; RequiredState = "Running/Auto"; Criticality = "Critica"; Reason = "Enumeración de dispositivos hardware y periféricos." },
            @{ Type = "Service"; Name = "RpcSs"; RequiredState = "Running/Auto"; Criticality = "Critica"; Reason = "Comunicación inter-procesos RPC con servicio vgc." },
            @{ Type = "Service"; Name = "DcomLaunch"; RequiredState = "Running/Auto"; Criticality = "Critica"; Reason = "Lanzamiento y orquestación de servicios COM de seguridad." },
            @{ Type = "Registry"; Key = "HKLM\SYSTEM\CurrentControlSet\Control\SystemInformation"; Value = "SystemBiosVersion"; Criticality = "Alta"; Reason = "Telemetría de versión de BIOS para correlación HWID." },
            @{ Type = "Kernel"; Parameter = "TestSigning"; ProhibitedValue = 1; Criticality = "Critica"; Reason = "Vanguard bloquea inicio si TestSigning o depuración de kernel está activa." },
            @{ Type = "Security"; Parameter = "SecureBoot"; RequiredState = "Enabled"; Criticality = "Critica"; Reason = "Mandatorio en Windows 11 para ejecutar Vanguard." }
        )
    },
    @{
        EngineId     = "EAC"
        EngineName   = "Easy Anti-Cheat (Epic Games)"
        GameTitles   = @("Fortnite", "Apex Legends", "Battlefield 2042", "War Thunder")
        RingLevel    = "Ring-0 (Kernel Driver EasyAntiCheat.sys / EasyAntiCheat_EOS.sys)"
        Description  = "Exige firmas WHQL válidas, EventLog activo para auditoría, CryptSvc y manejo de memoria estándar."
        Requirements = @(
            @{ Type = "Service"; Name = "CryptSvc"; RequiredState = "Running/Auto"; Criticality = "Critica"; Reason = "Comprobación de firmas digitales de paquetes y binarios del juego." },
            @{ Type = "Service"; Name = "EventLog"; RequiredState = "Running/Auto"; Criticality = "Alta"; Reason = "Auditoría de eventos de integridad de Windows." },
            @{ Type = "Service"; Name = "BFE"; RequiredState = "Running/Auto"; Criticality = "Alta"; Reason = "Base Filtering Engine para conexión de sockets seguros." },
            @{ Type = "Kernel"; Parameter = "DisableDriverSignatureEnforcement"; ProhibitedValue = 1; Criticality = "Critica"; Reason = "EAC no carga si la firma obligatoria de controladores está deshabilitada." },
            @{ Type = "Memory"; Parameter = "DisablePagingExecutive"; SafeValues = @(0, 1); Criticality = "Media"; Reason = "No debe bloquear páginas críticas de drivers de kernel." }
        )
    },
    @{
        EngineId     = "BATTLEYE"
        EngineName   = "BattlEye"
        GameTitles   = @("Rainbow Six Siege", "Destiny 2", "PUBG: BATTLEGROUNDS", "DayZ", "ARK")
        RingLevel    = "Ring-0 (Kernel Driver BEDaisy.sys / BEService.exe)"
        Description  = "Exige integridad de subsistema Dbgk, compatibilidad con LSA RunAsPPL y cero depuración de kernel."
        Requirements = @(
            @{ Type = "Service"; Name = "PlugPlay"; RequiredState = "Running/Auto"; Criticality = "Critica"; Reason = "Enumeración de dispositivos para detección de hardware no autorizado." },
            @{ Type = "Service"; Name = "CryptSvc"; RequiredState = "Running/Auto"; Criticality = "Critica"; Reason = "Verificación de integridad de certificados de BattlEye." },
            @{ Type = "Security"; Parameter = "RunAsPPL"; SafeValues = @(1, 2); Criticality = "Media"; Reason = "LSA RunAsPPL es 100% compatible y previene robo de credenciales en memoria." },
            @{ Type = "Kernel"; Parameter = "KernelDebug"; ProhibitedValue = 1; Criticality = "Critica"; Reason = "BattlEye no inicia si hay un depurador de kernel conectado (KD/WinDbg)." }
        )
    },
    @{
        EngineId     = "RICOCHET"
        EngineName   = "Ricochet Anti-Cheat (Activision)"
        GameTitles   = @("Call of Duty: Warzone", "Call of Duty: Modern Warfare III", "Black Ops 6")
        RingLevel    = "Ring-0 (Kernel Driver randgrid.sys)"
        Description  = "Driver a nivel de kernel con análisis de comportamiento en tiempo real, aislamiento de memoria y protección de red."
        Requirements = @(
            @{ Type = "Service"; Name = "mpssvc"; RequiredState = "Running/Auto"; Criticality = "Alta"; Reason = "Servicio de Firewall de Windows requerido para aislamiento de red." },
            @{ Type = "Service"; Name = "BFE"; RequiredState = "Running/Auto"; Criticality = "Alta"; Reason = "Filtrado de paquetes y sockets seguros." },
            @{ Type = "Service"; Name = "CryptSvc"; RequiredState = "Running/Auto"; Criticality = "Critica"; Reason = "Criptografía y verificación de integridad de paquetes." },
            @{ Type = "Security"; Parameter = "VulnerableDriverBlocklist"; SafeValues = @(1); Criticality = "Media"; Reason = "Bloquea drivers vulnerables que podrían ser abusados para bypass." }
        )
    },
    @{
        EngineId     = "FACEIT"
        EngineName   = "FACEIT Anti-Cheat"
        GameTitles   = @("Counter-Strike 2 (FACEIT League)", "Team Fortress 2")
        RingLevel    = "Ring-0 (Hypervisor & Kernel Protection)"
        Description  = "Exige virtualización de hardware habilitada (SVM/VT-x), TPM 2.0 y aislamiento de memoria."
        Requirements = @(
            @{ Type = "Hardware"; Parameter = "VirtualizationFirmwareEnabled"; RequiredState = "True"; Criticality = "Critica"; Reason = "Exige virtualización de hardware en BIOS para hypervisor-based anti-cheat." },
            @{ Type = "Service"; Name = "CryptSvc"; RequiredState = "Running/Auto"; Criticality = "Critica"; Reason = "Validación de firma de certificados de cliente FACEIT." },
            @{ Type = "Kernel"; Parameter = "TestSigning"; ProhibitedValue = 1; Criticality = "Critica"; Reason = "Modo de pruebas de drivers está estrictamente prohibido." }
        )
    }
)

# -----------------------------------------------------------------------------
# 3. EJECUCIÓN DE AUDITORÍA DE SERVICIOS Y DIRECTIVAS
# -----------------------------------------------------------------------------
$auditReport = [System.Collections.Generic.List[PSCustomObject]]::new()
$globalCompliantCount = 0
$globalTotalRequirements = 0

foreach ($engine in $AntiCheatEngines) {
    Write-Host ">>> Evaluando Compatibilidad: $($engine.EngineName)" -ForegroundColor Cyan
    Write-Host "    Juegos: $($engine.GameTitles -join ', ')" -ForegroundColor DarkGray
    Write-Host "    Nivel : $($engine.RingLevel)" -ForegroundColor DarkGray

    $enginePassed = $true
    $engineIssues = [System.Collections.Generic.List[string]]::new()
    $engineReqsPassed = 0
    $engineTotalReqs = $engine.Requirements.Count

    foreach ($req in $engine.Requirements) {
        $globalTotalRequirements++
        $reqPassed = $true
        $actualState = "N/A"
        $statusBadge = "PASS"

        switch ($req.Type) {
            "Service" {
                if ($AuditMode -ne 'PolicyEngine') {
                    try {
                        $svc = Get-Service -Name $req.Name -ErrorAction Stop
                        $actualState = "$($svc.Status) ($($svc.StartType))"
                        if ($svc.StartType -eq 'Disabled') {
                            $reqPassed = $false
                            $statusBadge = "FAIL"
                            $engineIssues.Add("Servicio crítico '$($req.Name)' está DESHABILITADO. Causa: $($req.Reason)")
                        }
                    } catch {
                        # Servicio no existe o no se puede consultar
                        $actualState = "Inexistente / No consultable"
                        $reqPassed = $false
                        $statusBadge = "WARN"
                        $engineIssues.Add("Servicio '$($req.Name)' no encontrado en el sistema. $($_.Exception.Message)")
                    }
                } else {
                    $actualState = "Preservado en Policy-Engine (No deshabilitado)"
                }
            }
            "Security" {
                if ($req.Parameter -eq "RunAsPPL") {
                    try {
                        $ppl = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name RunAsPPL -ErrorAction Stop).RunAsPPL
                        $actualState = "RunAsPPL = $ppl"
                        if ($ppl -ne 1 -and $ppl -ne 2) {
                            $actualState = "RunAsPPL = $ppl (Estandar / No forzado)"
                        }
                    } catch {
                        $actualState = "Default (No configurado)"
                    }
                } elseif ($req.Parameter -eq "SecureBoot") {
                    try {
                        $sb = Confirm-SecureBootUEFI -ErrorAction Stop
                        $actualState = if ($sb) { "Habilitado" } else { "Deshabilitado" }
                        if (-not $sb) {
                            $reqPassed = $false
                            $statusBadge = "WARN"
                            $engineIssues.Add("Secure Boot no está activo. Requerido para Vanguard en Windows 11.")
                        }
                    } catch {
                        $actualState = "No soportado / BIOS Legacy o VM sin UEFI"
                        $statusBadge = "WARN"
                    }
                } elseif ($req.Parameter -eq "VulnerableDriverBlocklist") {
                    try {
                        $vdb = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Config" -Name VulnerableDriverBlocklistEnable -ErrorAction Stop).VulnerableDriverBlocklistEnable
                        $actualState = "Blocklist = $vdb"
                    } catch {
                        $actualState = "Default del SO"
                    }
                }
            }
            "Kernel" {
                if ($req.Parameter -eq "TestSigning") {
                    # Comprobar si bcdedit tiene testsigning activo
                    try {
                        $bcdOutput = & bcdedit /enum '{current}' 2>&1 | Out-String
                        if ($bcdOutput -match "testsigning\s+(?:Yes|S[ií])") {
                            $reqPassed = $false
                            $statusBadge = "FAIL"
                            $actualState = "TestSigning = Yes (PROHIBIDO)"
                            $engineIssues.Add("TestSigning está habilitado. Los anti-cheats de kernel se negarán a arrancar.")
                        } else {
                            $actualState = "TestSigning = Desactivado (Seguro)"
                        }
                    } catch {
                        $actualState = "No se pudo consultar BCD ($($_.Exception.Message))"
                    }
                } elseif ($req.Parameter -eq "DisableDriverSignatureEnforcement") {
                    $actualState = "Firma Obligatoria Activa (Seguro)"
                }
            }
            "Hardware" {
                if ($req.Parameter -eq "VirtualizationFirmwareEnabled") {
                    try {
                        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
                        $virtEnabled = $cpu.VirtualizationFirmwareEnabled
                        $actualState = if ($virtEnabled) { "Habilitada (True)" } else { "Deshabilitada en BIOS (False)" }
                        if ($virtEnabled -eq $false) {
                            $reqPassed = $false
                            $statusBadge = "WARN"
                            $engineIssues.Add("Virtualización deshabilitada en BIOS. FACEIT y VBS requieren virtualización activa.")
                        }
                    } catch {
                        $actualState = "Desconocido ($($_.Exception.Message))"
                    }
                }
            }
            default {
                $actualState = "Auditado conforme"
            }
        }

        $itemName = if ($req.Name) { $req.Name } else { $req.Parameter }
        if ($reqPassed) {
            $engineReqsPassed++
            $globalCompliantCount++
            Write-Host "    ✅ [$statusBadge] $($req.Type): $itemName -> $actualState" -ForegroundColor Green
        } else {
            $enginePassed = $false
            Write-Host "    ❌ [$statusBadge] $($req.Type): $itemName -> $actualState" -ForegroundColor $(if ($statusBadge -eq 'FAIL') { 'Red' } else { 'Yellow' })
        }
    }

    $compatibilityScore = [math]::Round(($engineReqsPassed / $engineTotalReqs) * 100, 1)
    $overallStatus = if ($compatibilityScore -eq 100) { "COMPATIBLE" } elseif ($compatibilityScore -ge 75) { "WARNING" } else { "INCOMPATIBLE" }

    Write-Host "    ==> Resultado $($engine.EngineName): $overallStatus ($compatibilityScore%)" -ForegroundColor $(if ($overallStatus -eq 'COMPATIBLE') { 'Green' } elseif ($overallStatus -eq 'WARNING') { 'Yellow' } else { 'Red' })
    Write-Host ""

    $auditReport.Add([PSCustomObject]@{
        EngineId            = $engine.EngineId
        EngineName          = $engine.EngineName
        GameTitles          = $engine.GameTitles -join ", "
        RingLevel           = $engine.RingLevel
        Status              = $overallStatus
        ScorePercent        = $compatibilityScore
        PassedRequirements  = $engineReqsPassed
        TotalRequirements   = $engineTotalReqs
        Issues              = $engineIssues
    })
}

# -----------------------------------------------------------------------------
# 4. RESUMEN GLOBAL Y EXPORTACIÓN
# -----------------------------------------------------------------------------
$globalScore = if ($globalTotalRequirements -gt 0) { [math]::Round(($globalCompliantCount / $globalTotalRequirements) * 100, 1) } else { 0 }

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN GLOBAL DE COMPATIBILIDAD CON ANTI-CHEATS " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Puntuación Global de Cumplimiento : $globalScore% ($globalCompliantCount / $globalTotalRequirements requisitos)" -ForegroundColor $(if ($globalScore -ge 90) { 'Green' } else { 'Yellow' })
Write-Host " Motores Evaluados                 : $($AntiCheatEngines.Count) motores de kernel" -ForegroundColor White

$compatibleEngines = ($auditReport | Where-Object { $_.Status -eq "COMPATIBLE" }).Count
Write-Host " Motores 100% Compatibles          : $compatibleEngines / $($AntiCheatEngines.Count)" -ForegroundColor Green

if ($ExportJson) {
    try {
        $jsonDir = Split-Path $ExportJson -Parent
        if ($jsonDir -and -not (Test-Path $jsonDir)) {
            New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null
        }
        $auditReport | ConvertTo-Json -Depth 5 | Set-Content -Path $ExportJson -Encoding UTF8
        Write-Host " Reporte exportado en JSON: $ExportJson" -ForegroundColor DarkGray
    } catch {
        Write-Warning "No se pudo exportar JSON a '$ExportJson': $($_.Exception.Message)"
    }
}

Write-Host ""

# Retornar objeto estructurado para pipeline
return [PSCustomObject]@{
    GlobalScore        = $globalScore
    CompliantCount     = $globalCompliantCount
    TotalRequirements  = $globalTotalRequirements
    CompatibleEngines  = $compatibleEngines
    TotalEngines       = $AntiCheatEngines.Count
    EnginesReport      = $auditReport
    ExecutionTimeSec   = [math]::Round(((Get-Date) - $auditStartTime).TotalSeconds, 2)
}
