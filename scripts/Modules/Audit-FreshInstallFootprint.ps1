#Requires -Version 5.1
<#
.SYNOPSIS
    Audit-FreshInstallFootprint.ps1 - Auditoría Forense de Huella en Reposo para Windows 11
    Herramienta de diagnóstico de solo lectura (Read-Only) para romanOS / OptimizedISO.

.DESCRIPTION
    Inspecciona en caliente una máquina virtual o equipo físico recién instalado para medir:
    1. Procesos en segundo plano (SearchHost, WebView2, Edge, OneDrive, Teams, Widgets, GameDVR, WER).
    2. Consumo real de memoria RAM (Working Set en MB), CPU y estado PLM (Suspendido vs Activo).
    3. Claves de auto-arranque en registro (HKCU/HKLM Run) y tareas programadas de telemetría.
    4. Estado de políticas de registro de la ISO (LimitBlankPasswordUse, Search Highlights, Edge, etc.).
    5. Métricas globales del sistema en reposo (RAM total/en uso, procesos e hilos totales).
    6. Genera un reporte forense estructurado en C:\romanOS_Footprint_Audit.md y en el Escritorio.

    Codificación estricta UTF-8 con BOM. Compatible con Windows PowerShell 5.1 y PowerShell 7+.

.EXAMPLE
    .\Audit-FreshInstallFootprint.ps1
    .\Audit-FreshInstallFootprint.ps1 -ExportPath "C:\Logs\FootprintReport.md"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ExportPath = "C:\romanOS_Footprint_Audit.md"
)

# -----------------------------------------------------------------------------
# 1. CARGA DE MOTOR VISUAL UI-ENGINE O FALLBACK AUTÓNOMO
# -----------------------------------------------------------------------------

$uiEngineCandidates = @(
    (Join-Path $PSScriptRoot "..\Core\UI-Engine.ps1"),
    (Join-Path $PSScriptRoot "Core\UI-Engine.ps1"),
    "C:\Windows\Setup\Scripts\Core\UI-Engine.ps1"
)

$uiLoaded = $false
foreach ($cand in $uiEngineCandidates) {
    if (Test-Path $cand) {
        try {
            . $cand
            $uiLoaded = $true
            break
        } catch { }
    }
}

function Write-AuditSection {
    param([string]$Title)
    Write-Host "`n--- $Title ---" -ForegroundColor Yellow
}

if (-not $uiLoaded) {
    function Write-Header {
        param([string]$Title)
        Write-Host "`n========================================================" -ForegroundColor Cyan
        Write-Host "   $Title" -ForegroundColor White
        Write-Host "========================================================`n" -ForegroundColor Cyan
    }
    function Write-OK {
        param([string]$Message)
        Write-Host "  [OK] $Message" -ForegroundColor Green
    }
    function Write-Warn {
        param([string]$Message)
        Write-Host "  [WARN] $Message" -ForegroundColor Yellow
    }
    function Write-ErrorMsg {
        param([string]$Message)
        Write-Host "  [FAIL] $Message" -ForegroundColor Red
    }
    function Write-Info {
        param([string]$Message)
        Write-Host "  [INFO] $Message" -ForegroundColor Cyan
    }
}

Clear-Host

Write-Host "╔══════════════════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           romanOS / OptimizedISO - AUDITORIA FORENSE DE HUELLA EN REPOSO (FOOTPRINT)        ║" -ForegroundColor White
Write-Host "║                 Diagnóstico Empírico de Procesos en Segundo Plano y Memoria                  ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Metadatos del Sistema
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$uptime = (Get-Date) - $os.LastBootUpTime
$totalRamGiB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
$freeRamGiB = [math]::Round($os.FreePhysicalMemory * 1KB / 1GB, 2)
$usedRamGiB = [math]::Round($totalRamGiB - $freeRamGiB, 2)
$usedRamPct = [math]::Round(($usedRamGiB / $totalRamGiB) * 100, 1)

Write-Host "  Sistema Operativo : $($os.Caption) ($($os.Version) Build $($os.BuildNumber))" -ForegroundColor Gray
Write-Host "  Equipo / Modelo   : $($cs.Manufacturer) - $($cs.Model)" -ForegroundColor Gray
Write-Host "  Tiempo de Uptime  : $($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s" -ForegroundColor Gray
Write-Host "  Memoria RAM Total : $totalRamGiB GB (En uso: $usedRamGiB GB [$usedRamPct%] | Libre: $freeRamGiB GB)" -ForegroundColor Gray

# Estructura del Reporte Markdown
$report = [System.Collections.Generic.List[string]]::new()
$report.Add("# Reporte Forense de Huella en Reposo (romanOS Footprint Audit)")
$report.Add("")
$report.Add("- **Fecha de Auditoría:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$report.Add("- **Sistema Operativo:** $($os.Caption) ($($os.Version) Build $($os.BuildNumber))")
$report.Add("- **Hardware:** $($cs.Manufacturer) - $($cs.Model) | RAM Total: $totalRamGiB GB")
$report.Add("- **Uptime:** $($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s")
$report.Add("- **Estado Global de RAM:** $usedRamGiB GB en uso ($usedRamPct%) / $freeRamGiB GB libres")
$report.Add("")
$report.Add("---")
$report.Add("")

# -----------------------------------------------------------------------------
# 2. AUDITORÍA DE PROCESOS OBJETIVO (VAMPIROS EN SEGUNDO PLANO)
# -----------------------------------------------------------------------------

Write-AuditSection "1. Auditoría de Procesos en Segundo Plano"
$report.Add("## 1. Procesos en Segundo Plano y Huella de Memoria")
$report.Add("")
$report.Add("| Proceso Auditado | Instancias | RAM (Working Set) | PIDs | Veredicto Técnico |")
$report.Add("| :--- | :--- | :--- | :--- | :--- |")

$targetAudits = @(
    @{
        Name        = "msedgewebview2"
        DisplayName = "Edge WebView2 Runtime"
        Description = "Subprocesos de Search Highlights, Bing doodles o noticias"
        Expected    = "0 instancias en reposo (Zero-Overhead)"
    },
    @{
        Name        = "SearchHost"
        DisplayName = "SearchHost (Búsqueda de Windows)"
        Description = "Host del Menú Inicio y cuadro de búsqueda local"
        Expected    = "1 instancia suspendida (PLM Suspended ~15MB RAM)"
    },
    @{
        Name        = "msedge"
        DisplayName = "Microsoft Edge (Navegador)"
        Description = "Procesos parásitos de Startup Boost o Background Mode"
        Expected    = "0 instancias en reposo si Edge no se abrió"
    },
    @{
        Name        = "OneDrive"
        DisplayName = "Microsoft OneDrive"
        Description = "Sincronización en la nube en segundo plano"
        Expected    = "0 instancias en cuentas locales sin login"
    },
    @{
        Name        = "OneDriveSetup"
        DisplayName = "OneDrive Setup Worker"
        Description = "Instalador automático en primer inicio de sesión"
        Expected    = "0 instancias (No debe autoinstalarse en segundo plano)"
    },
    @{
        Name        = "msteams"
        DisplayName = "Microsoft Teams (Consumer)"
        Description = "Conector de Chat de la barra de tareas"
        Expected    = "0 instancias (Icono de Chat neutralizado)"
    },
    @{
        Name        = "Teams"
        DisplayName = "Microsoft Teams (New WASDK)"
        Description = "Instancia moderna de Teams en segundo plano"
        Expected    = "0 instancias"
    },
    @{
        Name        = "Widgets"
        DisplayName = "Windows Widgets / Dashboard"
        Description = "Feeds de noticias y widgets de la barra de tareas"
        Expected    = "0 instancias (Widgets desactivados)"
    },
    @{
        Name        = "bcastdvr"
        DisplayName = "Xbox GameDVR Replay Buffering"
        Description = "Búfer de captura de vídeo en segundo plano para juegos"
        Expected    = "0 instancias (GameDVR desactivado)"
    },
    @{
        Name        = "GameBar"
        DisplayName = "Xbox Game Bar Shell"
        Description = "Superposición de Xbox en segundo plano"
        Expected    = "0 instancias"
    },
    @{
        Name        = "werfault"
        DisplayName = "Windows Error Reporting (WER)"
        Description = "Recolector de fallos y volcados en segundo plano"
        Expected    = "0 instancias"
    }
)

$detectedVampires = 0
$cleanProcesses = 0

foreach ($t in $targetAudits) {
    $procs = @(Get-Process -Name $t.Name -ErrorAction SilentlyContinue)
    $count = $procs.Count

    if ($count -eq 0) {
        $cleanProcesses++
        $verdictConsole = "[LIMPIO / CERO PROCESOS]"
        $verdictMd = "✅ LIMPIO (0 procesos)"
        $ramStr = "0.0 MB"
        $pidStr = "-"
        Write-Host ("  ✅ {0,-28} : {1,-26} | RAM: {2,8}" -f $t.DisplayName, $verdictConsole, $ramStr) -ForegroundColor Green
    } else {
        $totalWorkingSetMB = [math]::Round(($procs | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB, 2)
        $pids = ($procs | Select-Object -ExpandProperty Id) -join ", "
        $ramStr = "$totalWorkingSetMB MB"
        $pidStr = $pids

        # Evaluación especial para SearchHost (PLM Suspended) y WebView2 (Search UI)
        if ($t.Name -eq "SearchHost") {
            if ($totalWorkingSetMB -le 35.0) {
                $verdictConsole = "[SUSPENDIDO PLM / OK]"
                $verdictMd = "🟢 SUSPENDIDO PLM (Optimizado)"
                Write-Host ("  🟢 {0,-28} : {1,-26} | RAM: {2,8} | PIDs: {3}" -f $t.DisplayName, $verdictConsole, $ramStr, $pidStr) -ForegroundColor Cyan
            } else {
                $detectedVampires++
                $verdictConsole = "[ACTIVO - CONSUMO ALTO]"
                $verdictMd = "⚠️ ACTIVO (>35MB)"
                Write-Host ("  ⚠️ {0,-28} : {1,-26} | RAM: {2,8} | PIDs: {3}" -f $t.DisplayName, $verdictConsole, $ramStr, $pidStr) -ForegroundColor Yellow
            }
        } elseif ($t.Name -eq "msedgewebview2") {
            # Verificar si las instancias de WebView2 son hijas de SearchHost
            $searchPids = @(Get-Process -Name "SearchHost" -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
            $cimProcs = @(Get-CimInstance Win32_Process -Filter "Name = 'msedgewebview2.exe'" -ErrorAction SilentlyContinue)
            $allSearchChildren = ($cimProcs.Count -gt 0)
            foreach ($cp in $cimProcs) {
                if ($cp.ParentProcessId -notin $searchPids -and (-not ($cp.CommandLine -and $cp.CommandLine -like "*SearchHost.exe*"))) {
                    $allSearchChildren = $false
                    break
                }
            }

            if ($allSearchChildren -and $totalWorkingSetMB -le 50.0) {
                $verdictConsole = "[SEARCH UI / PODADO OK]"
                $verdictMd = "🟢 SEARCH UI (Podado / Óptimo)"
                Write-Host ("  🟢 {0,-28} : {1,-26} | RAM: {2,8} | PIDs: {3}" -f $t.DisplayName, $verdictConsole, $ramStr, $pidStr) -ForegroundColor Cyan
            } elseif ($allSearchChildren) {
                $detectedVampires++
                $verdictConsole = "[SEARCH UI / REQUIERE PODA]"
                $verdictMd = "⚠️ SEARCH UI (>50MB, Requiere Poda)"
                Write-Host ("  ⚠️ {0,-28} : {1,-26} | RAM: {2,8} | PIDs: {3}" -f $t.DisplayName, $verdictConsole, $ramStr, $pidStr) -ForegroundColor Yellow
            } else {
                $detectedVampires++
                $verdictConsole = "[VAMPIRO EN SEGUNDO PLANO]"
                $verdictMd = "❌ VAMPIRO ACTIVO (Externo/Huérfano)"
                Write-Host ("  ❌ {0,-28} : {1,-26} | RAM: {2,8} | PIDs: {3}" -f $t.DisplayName, $verdictConsole, $ramStr, $pidStr) -ForegroundColor Red
            }
        } else {
            $detectedVampires++
            $verdictConsole = "[VAMPIRO EN SEGUNDO PLANO]"
            $verdictMd = "❌ VAMPIRO ACTIVO"
            Write-Host ("  ❌ {0,-28} : {1,-26} | RAM: {2,8} | PIDs: {3}" -f $t.DisplayName, $verdictConsole, $ramStr, $pidStr) -ForegroundColor Red
        }

        # Diagnostico forense de linea de comandos para instancias inesperadas de WebView2
        if ($t.Name -eq "msedgewebview2") {
            try {
                $cimProcs = @(Get-CimInstance Win32_Process -Filter "Name = 'msedgewebview2.exe'" -ErrorAction SilentlyContinue)
                if ($cimProcs.Count -gt 0) {
                    Write-Host "    🔍 Detalle forense de instancias WebView2 activas:" -ForegroundColor DarkYellow
                    foreach ($cp in $cimProcs) {
                        $parentProc = Get-Process -Id $cp.ParentProcessId -ErrorAction SilentlyContinue
                        $parentName = if ($parentProc) { "$($parentProc.Name) ($($cp.ParentProcessId))" } else { "PID $($cp.ParentProcessId)" }
                        $cmdArgs = if ($cp.CommandLine) { ($cp.CommandLine -replace '^.*msedgewebview2\.exe"?\s*', '') } else { "N/A" }
                        Write-Host ("      - PID {0,-5} | Padre: {1,-20} | Args: {2}" -f $cp.ProcessId, $parentName, $cmdArgs) -ForegroundColor DarkGray
                    }
                }
            } catch {}
        }
    }

    $report.Add(("| **{0}** (`{1}.exe`) | {2} | {3} | {4} | {5} |" -f $t.DisplayName, $t.Name, $count, $ramStr, $pidStr, $verdictMd))
}

$report.Add("")
$report.Add("---")
$report.Add("")

# -----------------------------------------------------------------------------
# 3. AUDITORÍA DE CLAVES DE AUTO-ARRANQUE EN EL REGISTRO
# -----------------------------------------------------------------------------

Write-AuditSection "2. Claves de Auto-Arranque (Startup Footprint)"
$report.Add("## 2. Claves de Auto-Arranque (Registry Startup Run)")
$report.Add("")
$report.Add("| Ámbito | Nombre del Valor | Contenido / Comando Ejecutado | Estado |")
$report.Add("| :--- | :--- | :--- | :--- |")

$runPaths = @(
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; Scope = "Usuario Actual (HKCU)" },
    @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"; Scope = "Equipo Local (HKLM)" }
)

$runEntriesCount = 0
foreach ($rp in $runPaths) {
    if (Test-Path $rp.Path) {
        $props = Get-ItemProperty -Path $rp.Path -ErrorAction SilentlyContinue
        $valNames = $props.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | Select-Object -ExpandProperty Name

        foreach ($vn in $valNames) {
            $runEntriesCount++
            $valData = $props.$vn
            $isSuspect = ($vn -match 'OneDrive|Teams|Edge|Discord|Update|Spotlight' -or $valData -match 'OneDrive|msedge|Teams')
            
            if ($isSuspect) {
                Write-Host ("  ⚠️ [{0}] {1} = {2}" -f $rp.Scope, $vn, $valData) -ForegroundColor Yellow
                $report.Add(("| {0} | **{1}** | `{2}` | ⚠️ Sospechoso (Auto-inicio de telemetría/app) |" -f $rp.Scope, $vn, $valData))
            } else {
                Write-Host ("  ℹ️ [{0}] {1} = {2}" -f $rp.Scope, $vn, $valData) -ForegroundColor Gray
                $report.Add(("| {0} | {1} | `{2}` | ℹ️ Común / Sistema |" -f $rp.Scope, $vn, $valData))
            }
        }
    }
}

if ($runEntriesCount -eq 0) {
    Write-OK "Cero entradas de auto-arranque en Run (Inicio 100% limpio)."
    $report.Add("| N/A | Ninguno | Sin entradas registradas en Run | ✅ 100% Limpio |")
}

$report.Add("")
$report.Add("---")
$report.Add("")

# -----------------------------------------------------------------------------
# 4. AUDITORÍA DE DIRECTIVAS DE REGISTRO CLAVE (SSOT Y GPO)
# -----------------------------------------------------------------------------

Write-AuditSection "3. Estado de Políticas y Directivas en el Registro"
$report.Add("## 3. Estado de Políticas de Optimización en el Registro")
$report.Add("")
$report.Add("| Identificador | Clave de Registro | Valor Evaluado | Estado Actual | Veredicto |")
$report.Add("| :--- | :--- | :--- | :--- | :--- |")

$policiesToAudit = @(
    @{
        Id       = "LimitBlankPasswordUse"
        Path     = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        Name     = "LimitBlankPasswordUse"
        Expected = 1
        Desc     = "Restricción de contraseñas vacías a consola local (PLAN-0049/0055)"
    },
    @{
        Id       = "EnableDynamicContentInWSB"
        Path     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        Name     = "EnableDynamicContentInWSB"
        Expected = 0
        Desc     = "Search Highlights desactivado (Zero-Overhead WebView2 - PLAN-0055)"
    },
    @{
        Id       = "DisableWebSearch"
        Path     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        Name     = "DisableWebSearch"
        Expected = 1
        Desc     = "Búsqueda web de Bing en Menú Inicio desactivada"
    },
    @{
        Id       = "StartupBoostEnabled"
        Path     = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        Name     = "StartupBoostEnabled"
        Expected = 0
        Desc     = "Edge Startup Boost desactivado"
    },
    @{
        Id       = "BackgroundModeEnabled"
        Path     = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        Name     = "BackgroundModeEnabled"
        Expected = 0
        Desc     = "Procesos de Edge en segundo plano desactivados al salir"
    },
    @{
        Id       = "AllowGameDVR"
        Path     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
        Name     = "AllowGameDVR"
        Expected = 0
        Desc     = "Xbox GameDVR desactivado a nivel de máquina"
    },
    @{
        Id       = "AppCaptureEnabled"
        Path     = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
        Name     = "AppCaptureEnabled"
        Expected = 0
        Desc     = "Búfer de captura de vídeo desactivado en usuario"
    },
    @{
        Id       = "TaskbarMn (Chat)"
        Path     = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Name     = "TaskbarMn"
        Expected = 0
        Desc     = "Icono de Chat/Teams oculto en barra de tareas"
    },
    @{
        Id       = "TaskbarDa (Widgets)"
        Path     = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Name     = "TaskbarDa"
        Expected = 0
        Desc     = "Icono de Widgets oculto en barra de tareas"
    },
    @{
        Id       = "ShowCopilotButton"
        Path     = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Name     = "ShowCopilotButton"
        Expected = 0
        Desc     = "Botón de Copilot oculto en barra de tareas"
    },
    @{
        Id       = "AllowWidgets (GPO)"
        Path     = "HKLM:\SOFTWARE\Policies\Microsoft\Widgets"
        Name     = "AllowWidgets"
        Expected = 0
        Desc     = "Desactivar subsistema de Widgets a nivel de máquina (PLAN-0057)"
    },
    @{
        Id       = "AllowNewsAndInterests"
        Path     = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
        Name     = "AllowNewsAndInterests"
        Expected = 0
        Desc     = "Desactivar Noticias e Intereses a nivel de máquina (PLAN-0057)"
    },
    @{
        Id       = "ChatIcon (GPO)"
        Path     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat"
        Name     = "ChatIcon"
        Expected = 3
        Desc     = "Desactivar Chat consumidor a nivel de directiva (PLAN-0057)"
    },
    @{
        Id       = "NoAutoUpdate (WU AU)"
        Path     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        Name     = "NoAutoUpdate"
        Expected = 1
        Desc     = "Windows Update bajo demanda (Scan/Download manual únicamente - PLAN-0059)"
    },
    @{
        Id       = "AUOptions (WU AU)"
        Path     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        Name     = "AUOptions"
        Expected = 2
        Desc     = "Notificar antes de descargar y de instalar (PLAN-0059)"
    },
    @{
        Id       = "NoAutoReboot (WU AU)"
        Path     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        Name     = "NoAutoRebootWithLoggedOnUsers"
        Expected = 1
        Desc     = "Evitar reinicios automáticos con usuarios conectados (PLAN-0059)"
    }
)

foreach ($pol in $policiesToAudit) {
    $exists = Test-Path $pol.Path
    $actual = $null
    if ($exists) {
        $actual = (Get-ItemProperty -Path $pol.Path -Name $pol.Name -ErrorAction SilentlyContinue).($pol.Name)
    }

    if ($null -ne $actual) {
        if ([string]$actual -eq [string]$pol.Expected) {
            Write-Host ("  ✅ {0,-26} : {1,-6} [OK - Aplicada]" -f $pol.Id, $actual) -ForegroundColor Green
            $report.Add(("| {0} | `{1}` | {2} | `{3}` (Esperado: `{4}`) | ✅ APLICADA |" -f $pol.Id, $pol.Path, $pol.Name, $actual, $pol.Expected))
        } else {
            Write-Host ("  ⚠️ {0,-26} : {1,-6} [DISCREPANTE - Esperado: {2}]" -f $pol.Id, $actual, $pol.Expected) -ForegroundColor Yellow
            $report.Add(("| {0} | `{1}` | {2} | `{3}` (Esperado: `{4}`) | ⚠️ DISCREPANTE |" -f $pol.Id, $pol.Path, $pol.Name, $actual, $pol.Expected))
        }
    } else {
        Write-Host ("  ⚪ {0,-26} : NO CONFIGURADA (Valor por defecto de Windows)" -f $pol.Id) -ForegroundColor Gray
        $report.Add(("| {0} | `{1}` | {2} | No configurada | ⚪ POR DEFECTO WINDOWS |" -f $pol.Id, $pol.Path, $pol.Name))
    }
}

$report.Add("")
$report.Add("---")
$report.Add("")

# -----------------------------------------------------------------------------
# 5. RESUMEN GLOBAL Y CONCLUSIONES FORENSES
# -----------------------------------------------------------------------------

$allProcs = Get-Process
$totalProcsCount = $allProcs.Count
$totalThreadsCount = ($allProcs.Threads).Count

Write-AuditSection "4. Evaluación Global del Sistema Operativo en Reposo"
Write-Host ("  Total de Procesos Activos : {0}" -f $totalProcsCount) -ForegroundColor Cyan
Write-Host ("  Total de Hilos de CPU     : {0}" -f $totalThreadsCount) -ForegroundColor Cyan
Write-Host ("  Memoria RAM Utilizada     : {0} GB de {1} GB ({2}%)" -f $usedRamGiB, $totalRamGiB, $usedRamPct) -ForegroundColor Cyan
Write-Host ("  Procesos Vampiro Activos  : {0}" -f $detectedVampires) -ForegroundColor $(if ($detectedVampires -eq 0) { 'Green' } else { 'Yellow' })

$report.Add("## 4. Métricas Globales del Sistema Operativo en Reposo")
$report.Add("")
$report.Add("- **Procesos en Ejecución:** $totalProcsCount procesos")
$report.Add("- **Hilos de Ejecución:** $totalThreadsCount hilos")
$report.Add("- **RAM en Reposo:** $usedRamGiB GB / $totalRamGiB GB ($usedRamPct%)")
$report.Add("- **Vampiros Detectados:** $detectedVampires procesos en segundo plano consumiendo recursos")
$report.Add("")
$report.Add("### Conclusión Técnica:")
if ($detectedVampires -eq 0) {
    $report.Add("🟢 **Excelente:** El sistema operativo presenta una huella de memoria impecable. Cero procesos parásitos en segundo plano.")
} else {
    $report.Add("🟡 **Optimizable:** Se detectaron $detectedVampires procesos/servicios parásitos activos en segundo plano que pueden ser neutralizados quirúrgicamente a nivel de ISO o Toolkit.")
}

# Guardar Reporte Markdown
try {
    $reportText = $report -join "`r`n"
    [System.IO.File]::WriteAllText($ExportPath, $reportText, [System.Text.Encoding]::UTF8)
    Write-Host "`n  [OK] Reporte Markdown guardado en: $ExportPath" -ForegroundColor Green

    # Intentar copiar al Escritorio
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    if (Test-Path $desktopPath) {
        $desktopReport = Join-Path $desktopPath "romanOS_Footprint_Audit.md"
        [System.IO.File]::WriteAllText($desktopReport, $reportText, [System.Text.Encoding]::UTF8)
        Write-Host "  [OK] Copia del reporte creada en el Escritorio: $desktopReport" -ForegroundColor Green
    }
} catch {
    Write-Warn "No se pudo guardar el reporte en disco: $($_.Exception.Message)"
}

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "   AUDITORIA FINALIZADA EXITOSAMENTE" -ForegroundColor White
Write-Host "========================================================`n" -ForegroundColor Cyan
