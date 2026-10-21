<#
.SYNOPSIS
    romanOS Host Telemetry Single Source of Truth (SSOT) - Get-HostTelemetry.ps1
    Inspector Canónico e Inviolable de Telemetría e Identidad del Sistema Operativo Host (Regla 21)

.DESCRIPTION
    Provee una fuente de verdad única, determinista y matemáticamente verificada sobre el
    sistema operativo host físico, erradicando cualquier inferencia o alucinación basada en
    cadenas de logs (CBS.log, DISM.log, User-Agents).
    Cumple con el estándar de codificación UTF-8 con BOM y compatibilidad nativa con Windows PowerShell 5.1.

.PARAMETER AsJson
    Devuelve los datos estructurados en formato JSON para consumo por herramientas o pipelines.

.PARAMETER Quiet
    Suprime la salida visual formateada y retorna exclusivamente el objeto PSCustomObject.

.EXAMPLE
    .\Get-HostTelemetry.ps1
    Muestra la telemetría formateada en consola con colores e información del host.

.EXAMPLE
    $hostInfo = .\Get-HostTelemetry.ps1 -Quiet
    Obtiene el objeto tipado en memoria.
#>

[CmdletBinding()]
param(
    [switch]$AsJson,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

try {
    # 1. Consulta canónica a CIM (Win32_OperatingSystem y Win32_ComputerSystem)
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop

    # 2. Consulta canónica al Registro de Windows (HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion)
    $cvPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $cv = Get-ItemProperty -Path $cvPath -ErrorAction Stop

    # 3. Cálculo de Uptime y Memoria
    $bootTime = $os.LastBootUpTime
    $uptime = (Get-Date) - $bootTime
    $totalRAM_GB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRAM_GB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRAM_GB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)

    # 4. Construcción del Objeto Canónico Inmutable
    $telemetry = [PSCustomObject]@{
        Caption          = $os.Caption
        EditionID        = $cv.EditionID
        DisplayVersion   = if ($cv.DisplayVersion) { $cv.DisplayVersion } else { "N/A" }
        CurrentBuild     = [int]$cv.CurrentBuild
        UBR              = [int]$cv.UBR
        FullBuild        = "$($cv.CurrentBuild).$($cv.UBR)"
        Architecture     = $os.OSArchitecture
        RegisteredOwner  = $cv.RegisteredOwner
        InstallDate      = $os.InstallDate
        LastBootUpTime   = $bootTime
        UptimeMinutes    = [math]::Round($uptime.TotalMinutes, 1)
        TotalVisibleRAM  = $totalRAM_GB
        FreePhysicalRAM  = $freeRAM_GB
        UsedPhysicalRAM  = $usedRAM_GB
        Manufacturer     = $cs.Manufacturer
        Model            = $cs.Model
        VerifiedSource   = "CIM (Win32_OperatingSystem) + Registry ($cvPath)"
        Timestamp        = Get-Date
    }

    if ($AsJson) {
        return ($telemetry | ConvertTo-Json -Depth 2)
    }

    if (-not $Quiet) {
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host "   romanOS - TELEMETRIA VERIFICADA DEL HOST (SSOT)" -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host "  Sistema Operativo: $($telemetry.Caption)" -ForegroundColor White
        Write-Host "  Edicion (Edition): $($telemetry.EditionID)" -ForegroundColor White
        Write-Host "  Version (Release): $($telemetry.DisplayVersion)" -ForegroundColor Green
        Write-Host "  Compilacion Build: $($telemetry.CurrentBuild)" -ForegroundColor Green
        Write-Host "  Revision (UBR):    $($telemetry.UBR)" -ForegroundColor Green
        Write-Host "  Build Completa:    $($telemetry.FullBuild)" -ForegroundColor Cyan
        Write-Host "  Arquitectura:      $($telemetry.Architecture)" -ForegroundColor White
        Write-Host "  Memoria RAM:       $($telemetry.UsedPhysicalRAM) GB en uso / $($telemetry.TotalVisibleRAM) GB total ($($telemetry.FreePhysicalRAM) GB libres)" -ForegroundColor White
        Write-Host "  Ultimo Arranque:   $($telemetry.LastBootUpTime) (Uptime: $($telemetry.UptimeMinutes) min)" -ForegroundColor White
        Write-Host "  Fuente de Verdad:  $($telemetry.VerifiedSource)" -ForegroundColor DarkGray
        Write-Host "==========================================================" -ForegroundColor Cyan
    }

    return $telemetry

} catch {
    # Guard Fail-Visible (CWE-390)
    Write-Error "[FAIL-VISIBLE] Error critico extrayendo telemetria canonica del host: $($_.Exception.Message)"
    throw
}
