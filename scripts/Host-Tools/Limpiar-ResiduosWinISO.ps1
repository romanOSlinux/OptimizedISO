<#
.SYNOPSIS
Detecta y limpia los residuos que puede dejar New-OptimizedWindowsISO-v2.ps1 en el sistema
cuando el proceso de creación de ISO se interrumpe o falla a mitad de camino.

.DESCRIPTION
New-OptimizedWindowsISO-v2.ps1 limpia sus propios directorios temporales al final de su
ejecución (ScratchDir, WimMountDir, ExtractDir), pero ese bloque de limpieza está al final
del script y no está protegido por un try/finally global. Si el proceso se corta antes de
llegar ahí (error no controlado, Ctrl+C, cierre de la consola, timeout, corte de energía),
esos directorios —y en algunos casos la imagen WIM montada o la colmena de registro
temporal— quedan abandonados en el sistema.

Este script busca y limpia, de forma segura (solo huellas con el patrón de nombre exacto
que usa New-OptimizedWindowsISO-v2.ps1), lo siguiente:

  1. Carpetas de extracción de ISO abandonadas   (%TEMP%\WinISO_Extract_*)
  2. Carpetas de montaje de WIM abandonadas       (<UnidadSistema>\WimMount_*)
  3. Carpetas scratch de DISM abandonadas         (<UnidadSistema>\WinISO_Scratch_*)
  4. Restos de descarga de ISO oficial            (%TEMP%\Fido_*.ps1, %TEMP%\MCT_*)
  5. Imágenes WIM que quedaron montadas a nivel DISM aunque la carpeta ya no exista
  6. La colmena de registro HKLM\OfflineDefaultUser si quedó cargada

También permite (opción aparte, con confirmación explícita) desinstalar 7-Zip y/o
Microsoft.OSCDIMG si fueron instalados por winget para ese script y ya no los necesitás.
Estos NO se tocan por defecto: no son residuos temporales, son dependencias que el
generador de ISOs reinstalaría solo si hacen falta de nuevo.

.NOTES
No ejecutar mientras New-OptimizedWindowsISO-v2.ps1 esté corriendo en otra ventana:
podría estar usando esas mismas carpetas o esa misma imagen montada.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [switch]$Unattended,

    [Parameter()]
    [switch]$Quiet,

    [Parameter()]
    [switch]$SkipElevation
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    if (-not $SkipElevation -and -not [Console]::IsInputRedirected -and -not $Unattended) {
        Write-Host "  [AVISO] Este script requiere privilegios de Administrador para desmontar WIMs y descargar colmenas." -ForegroundColor Yellow
        $relaunch = Read-Host "  ¿Desea relanzar este asistente con privilegios elevados? (S/N) [Por defecto: S]"
        if ([string]::IsNullOrWhiteSpace($relaunch) -or $relaunch -match '^[sSyY]') {
            Start-Process powershell.exe -ArgumentList "-STA -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
            return
        }
    } else {
        Write-Host "  [AVISO] Ejecutando en modo limitado sin elevación de Administrador. Algunas operaciones de DISM/Registro requerirán elevación." -ForegroundColor Yellow
    }
}

#------------------------------------------------------------------------------
# SALIDA CON COLOR
#------------------------------------------------------------------------------

function Write-OK       { param([string]$Msg) Write-Host "  [OK] $Msg" -ForegroundColor Green }
function Write-Warn     { param([string]$Msg) Write-Host "  [AVISO] $Msg" -ForegroundColor Yellow }
function Write-ErrorMsg { param([string]$Msg) Write-Host "  [ERROR] $Msg" -ForegroundColor Red }
function Write-Info     { param([string]$Msg) Write-Host "  $Msg" -ForegroundColor Gray }
function Write-Titulo   {
    param([string]$Msg)
    Write-Host ""
    Write-Host "  == $Msg ==" -ForegroundColor Cyan
}

#------------------------------------------------------------------------------
# UTILIDADES DE TAMAÑO
#------------------------------------------------------------------------------

function Format-Tamano {
    param([long]$Bytes)
    if     ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    else                    { return "$Bytes B" }
}

function Get-TamanoCarpeta {
    param([string]$Path)
    try {
        $suma = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                 Where-Object { -not $_.PSIsContainer } |
                 Measure-Object -Property Length -Sum).Sum
        if (-not $suma) { return 0 }
        return [long]$suma
    } catch {
        return 0
    }
}

#------------------------------------------------------------------------------
# DETECCIÓN DE RESIDUOS
#------------------------------------------------------------------------------

function Find-Residuos {
    $hallazgos = [System.Collections.Generic.List[PSObject]]::new()

    Write-Info "Buscando carpetas de extracción de ISO abandonadas..."
    Get-ChildItem -Path $env:TEMP -Directory -Filter "WinISO_Extract_*" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $hallazgos.Add([PSCustomObject]@{
                Categoria = "Carpeta de extracción de ISO"
                Ruta      = $_.FullName
                Bytes     = (Get-TamanoCarpeta -Path $_.FullName)
                Tipo      = "Carpeta"
            })
        }

    Write-Info "Buscando carpetas de montaje de WIM abandonadas..."
    Get-ChildItem -Path "$($env:SystemDrive)\" -Directory -Filter "WimMount_*" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $hallazgos.Add([PSCustomObject]@{
                Categoria = "Carpeta de montaje WIM"
                Ruta      = $_.FullName
                Bytes     = (Get-TamanoCarpeta -Path $_.FullName)
                Tipo      = "Carpeta"
            })
        }

    Write-Info "Buscando carpetas scratch de DISM abandonadas..."
    Get-ChildItem -Path "$($env:SystemDrive)\" -Directory -Filter "WinISO_Scratch_*" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $hallazgos.Add([PSCustomObject]@{
                Categoria = "Carpeta scratch de DISM"
                Ruta      = $_.FullName
                Bytes     = (Get-TamanoCarpeta -Path $_.FullName)
                Tipo      = "Carpeta"
            })
        }

    Write-Info "Buscando carpetas de trabajo de romanOS (romanOS_Scratch)..."
    Get-ChildItem -Path "$($env:SystemDrive)\" -Directory -Filter "romanOS_Scratch*" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $hallazgos.Add([PSCustomObject]@{
                Categoria = "Carpeta scratch de romanOS (WIM Optimizer)"
                Ruta      = $_.FullName
                Bytes     = (Get-TamanoCarpeta -Path $_.FullName)
                Tipo      = "Carpeta"
            })
        }

    Write-Info "Buscando restos de descarga (Fido / Media Creation Tool)..."
    Get-ChildItem -Path $env:TEMP -File -Filter "Fido_*.ps1" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $hallazgos.Add([PSCustomObject]@{
                Categoria = "Script temporal de descarga (Fido)"
                Ruta      = $_.FullName
                Bytes     = $_.Length
                Tipo      = "Archivo"
            })
        }
    Get-ChildItem -Path $env:TEMP -Directory -Filter "MCT_*" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $hallazgos.Add([PSCustomObject]@{
                Categoria = "Carpeta temporal de Media Creation Tool"
                Ruta      = $_.FullName
                Bytes     = (Get-TamanoCarpeta -Path $_.FullName)
                Tipo      = "Carpeta"
            })
        }

    Write-Info "Buscando imágenes WIM que quedaron montadas a nivel DISM..."
    try {
        $montadas = Get-WindowsImage -Mounted -ErrorAction Stop |
                    Where-Object { $_.Path -like "*WimMount_*" -or $_.Path -like "*romanOS_Scratch*" -or $_.Path -like "*WinISO_*" }
        foreach ($img in $montadas) {
            $hallazgos.Add([PSCustomObject]@{
                Categoria = "Imagen WIM montada (huérfana)"
                Ruta      = $img.Path
                Bytes     = 0
                Tipo      = "MontajeWIM"
            })
        }
    } catch {
        Write-Debug "DISM no disponible o sin imágenes montadas: $($_.Exception.Message)"
    }

    Write-Info "Verificando colmena de registro 'OfflineDefaultUser'..."
    & reg.exe query "HKLM\OfflineDefaultUser" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $hallazgos.Add([PSCustomObject]@{
            Categoria = "Colmena de registro cargada (HKLM\OfflineDefaultUser)"
            Ruta      = "HKLM\OfflineDefaultUser"
            Bytes     = 0
            Tipo      = "ColmenaRegistro"
        })
    }

    return $hallazgos
}

#------------------------------------------------------------------------------
# ELIMINACIÓN DE UN RESIDUO
#------------------------------------------------------------------------------

function Remove-Residuo {
    param($Item)

    switch ($Item.Tipo) {
        "Carpeta" {
            $deleted = $false
            for ($tentativa = 1; $tentativa -le 3; $tentativa++) {
                try {
                    [GC]::Collect()
                    [GC]::WaitForPendingFinalizers()
                    if (Test-Path $Item.Ruta) {
                        & cmd.exe /c "attrib -R `"$($Item.Ruta)\*`" /S /D" 2>&1 | Out-Null
                        Remove-Item -Path $Item.Ruta -Recurse -Force -ErrorAction Stop
                    }
                    Write-OK "Eliminada: $($Item.Ruta)"
                    $deleted = $true
                    break
                } catch {
                    if ($tentativa -lt 3) {
                        Start-Sleep -Milliseconds 800
                    } else {
                        Write-Warn "No se pudo eliminar $($Item.Ruta): $($_.Exception.Message)"
                    }
                }
            }
            return $deleted
        }
        "Archivo" {
            try {
                Remove-Item -Path $Item.Ruta -Force -ErrorAction Stop
                Write-OK "Eliminado: $($Item.Ruta)"
                return $true
            } catch {
                Write-Warn "No se pudo eliminar $($Item.Ruta): $($_.Exception.Message)"
                return $false
            }
        }
        "MontajeWIM" {
            $ok = $false
            try {
                Dismount-WindowsImage -Path $Item.Ruta -Discard -ErrorAction Stop | Out-Null
                $ok = $true
            } catch {
                Write-Warn "Dismount-WindowsImage falló ($($_.Exception.Message)). Intentando desmonte con dism.exe..."
                & dism.exe /Unmount-Wim /MountDir:"$($Item.Ruta)" /Discard 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    & dism.exe /Unmount-Image /MountDir:"$($Item.Ruta)" /Discard 2>&1 | Out-Null
                }
                $ok = ($LASTEXITCODE -eq 0)
            }
            if ($ok) {
                Write-OK "Imagen WIM desmontada (se descartaron los cambios pendientes): $($Item.Ruta)"
                Start-Sleep -Milliseconds 800
                [GC]::Collect()
                [GC]::WaitForPendingFinalizers()
                if (Test-Path $Item.Ruta) {
                    Remove-Item -Path $Item.Ruta -Recurse -Force -ErrorAction SilentlyContinue
                }
            } else {
                $outCl = & dism.exe /Cleanup-Wim 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Warn "dism.exe /Cleanup-Wim retornó código no exitoso ($LASTEXITCODE): $outCl"
                }
                Write-Warn "No se pudo desmontar $($Item.Ruta) automáticamente. Se ejecutó /Cleanup-Wim."
            }
            return $ok
        }
        "ColmenaRegistro" {
            [gc]::Collect()
            [gc]::WaitForPendingFinalizers()
            $ok = $false
            for ($i = 1; $i -le 3; $i++) {
                & reg.exe unload "HKLM\OfflineDefaultUser" 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) { $ok = $true; break }
                [gc]::Collect(); [gc]::WaitForPendingFinalizers()
                Start-Sleep -Seconds 1
            }
            if ($ok) {
                Write-OK "Colmena de registro descargada correctamente."
            } else {
                Write-Warn "No se pudo descargar la colmena. Puede quedar cargada hasta que reinicies Windows."
            }
            return $ok
        }
    }
}

#------------------------------------------------------------------------------
# REPORTE
#------------------------------------------------------------------------------

function Show-Reporte {
    param($Items)

    if ($Items.Count -eq 0) {
        Write-OK "No se detectaron residuos de New-OptimizedWindowsISO en el sistema."
        return
    }

    Write-Host ""
    Write-Host "  Residuos detectados:" -ForegroundColor White
    $i = 1
    foreach ($item in $Items) {
        $tamStr = if ($item.Bytes -gt 0) { "  ($(Format-Tamano $item.Bytes))" } else { "" }
        Write-Host ("  [{0}] {1}{2}" -f $i, $item.Categoria, $tamStr) -ForegroundColor Yellow
        Write-Host ("      $($item.Ruta)") -ForegroundColor DarkGray
        $i++
    }

    $totalBytes = ($Items | Measure-Object -Property Bytes -Sum).Sum
    Write-Host ""
    Write-Host "  Espacio en disco recuperable: $(Format-Tamano $totalBytes)" -ForegroundColor Cyan
}

#------------------------------------------------------------------------------
# GESTIÓN DE DEPENDENCIAS PERMANENTES (7-Zip / OSCDIMG)
#------------------------------------------------------------------------------

function Show-GestionDependencias {
    Write-Titulo "Dependencias instaladas por New-OptimizedWindowsISO vía winget"
    Write-Info "Esto NO son residuos temporales: son programas completos que el generador de"
    Write-Info "ISOs instala una sola vez para reutilizarlos en cada corrida futura."
    Write-Host ""

    $deps = @()

    $7zPaths = @(
        "$env:ProgramFiles\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
        "$env:LOCALAPPDATA\Programs\7-Zip\7z.exe"
    )
    if ($7zPaths | Where-Object { Test-Path $_ }) {
        $deps += [PSCustomObject]@{ Nombre = "7-Zip"; WingetId = "7zip.7zip" }
    }

    $wingetPackages = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    $oscdEncontrado = $false
    if (Test-Path $wingetPackages) {
        $oscdEncontrado = [bool](Get-ChildItem -Path $wingetPackages -Recurse -Filter "oscdimg.exe" -ErrorAction SilentlyContinue |
                                  Where-Object { $_.FullName -match 'Microsoft\.OSCDIMG' })
    }
    if ($oscdEncontrado) {
        $deps += [PSCustomObject]@{ Nombre = "Microsoft OSCDIMG (Windows ADK)"; WingetId = "Microsoft.OSCDIMG" }
    }

    if ($deps.Count -eq 0) {
        Write-OK "No se encontró ninguna de estas dependencias instalada en este equipo."
        return
    }

    $i = 1
    foreach ($d in $deps) {
        Write-Host "  [$i] $($d.Nombre)   (winget id: $($d.WingetId))" -ForegroundColor Yellow
        $i++
    }
    Write-Host "  [0] Volver sin desinstalar nada" -ForegroundColor Gray

    if ([Console]::IsInputRedirected) { return }
    $sel = Read-Host "  Elegí cuál desinstalar"
    if ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $deps.Count) {
        $elegida = $deps[[int]$sel - 1]
        $conf = Read-Host "  Escribí DESINSTALAR para confirmar ($($elegida.Nombre))"
        if ($conf -eq "DESINSTALAR") {
            winget uninstall --id $elegida.WingetId --silent 2>&1 | Out-Null
            Write-OK "$($elegida.Nombre) desinstalado. Si el generador de ISOs lo vuelve a necesitar, lo reinstalará solo."
        } else {
            Write-Info "Cancelado."
        }
    }
}

#------------------------------------------------------------------------------
# LIMPIEZA FINAL DE PUNTOS DE MONTAJE (SIEMPRE INOFENSIVA)
#------------------------------------------------------------------------------

function Invoke-CleanupMountpoints {
    $out1 = & dism.exe /Cleanup-Mountpoints 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "dism.exe /Cleanup-Mountpoints retornó código no exitoso ($LASTEXITCODE): $out1"
    }
    $out2 = & dism.exe /Cleanup-Wim 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "dism.exe /Cleanup-Wim retornó código no exitoso ($LASTEXITCODE): $out2"
    }
}

#------------------------------------------------------------------------------
# EJECUCIÓN HEADLESS / UNATTENDED (romanOS Studio y Automatizaciones)
#------------------------------------------------------------------------------
if ($Unattended) {
    Write-Host "Iniciando motor de limpieza profunda del sistema..." -ForegroundColor Cyan
    Write-Host "Buscando residuos de compilaciones fallidas..." -ForegroundColor Gray
    $hallazgos = Find-Residuos
    if ($hallazgos.Count -eq 0) {
        Write-OK "No se detectaron residuos de New-OptimizedWindowsISO en el sistema."
    } else {
        Write-Host "Se encontraron $($hallazgos.Count) elementos residuales. Procediendo a limpiarlos..." -ForegroundColor Yellow
        $ordenados = $hallazgos | Sort-Object {
            switch ($_.Tipo) {
                "ColmenaRegistro" { 1 }
                "MontajeWIM"      { 2 }
                "Archivo"          { 3 }
                "Carpeta"          { 4 }
                default            { 5 }
            }
        }
        foreach ($item in $ordenados) {
            Remove-Residuo -Item $item | Out-Null
        }
    }
    Write-Host "Limpiando puntos de montaje huérfanos de DISM..." -ForegroundColor Gray
    Invoke-CleanupMountpoints
    Write-OK "Mantenimiento del host completado con éxito."
    return
}

#------------------------------------------------------------------------------
# MENÚ PRINCIPAL
#------------------------------------------------------------------------------

Clear-Host
Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Magenta
Write-Host "     LIMPIEZA DE RESIDUOS - New-OptimizedWindowsISO" -ForegroundColor Magenta
Write-Host "  ================================================================" -ForegroundColor Magenta
Write-Info "Cerrá cualquier ventana donde New-OptimizedWindowsISO-v2.ps1 siga corriendo"
Write-Info "antes de continuar."

Write-Titulo "Analizando el sistema"
$hallazgos = Find-Residuos
Show-Reporte $hallazgos

$salir = $false
do {
    if ([Console]::IsInputRedirected) {
        Write-Warn "Entorno no interactivo detectado o sin entrada. Finalizando ejecucion."
        $salir = $true
        break
    }

    Write-Host ""
    Write-Host "  [1] Analizar de nuevo" -ForegroundColor White
    Write-Host "  [2] Limpiar TODOS los residuos detectados" -ForegroundColor White
    Write-Host "  [3] Elegir qué residuos limpiar" -ForegroundColor White
    Write-Host "  [4] Gestionar dependencias instaladas (7-Zip / OSCDIMG)" -ForegroundColor White
    Write-Host "  [0] Salir" -ForegroundColor White
    $op = Read-Host "  Opción"

    if ([string]::IsNullOrWhiteSpace($op)) {
        Write-Warn "No se recibió entrada. Finalizando ejecucion."
        $salir = $true
        break
    }

    switch ($op) {
        "1" {
            Write-Titulo "Analizando el sistema"
            $hallazgos = Find-Residuos
            Show-Reporte $hallazgos
        }
        "2" {
            if ($hallazgos.Count -eq 0) {
                Write-Warn "No hay residuos detectados para limpiar."
            } else {
                $conf = if ([Console]::IsInputRedirected) { "N" } else { Read-Host "  Se eliminarán $($hallazgos.Count) elementos. ¿Confirmar? (S/N)" }
                if ($conf -match '^[sS]') {
                    $ordenados = $hallazgos | Sort-Object {
                        switch ($_.Tipo) {
                            "ColmenaRegistro" { 1 }
                            "MontajeWIM"      { 2 }
                            "Archivo"          { 3 }
                            "Carpeta"          { 4 }
                            default            { 5 }
                        }
                    }
                    foreach ($item in $ordenados) { Remove-Residuo -Item $item | Out-Null }
                    Invoke-CleanupMountpoints
                    Write-Titulo "Resultado"
                    $hallazgos = Find-Residuos
                    Show-Reporte $hallazgos
                }
            }
        }
        "3" {
            if ($hallazgos.Count -eq 0) {
                Write-Warn "No hay residuos detectados para limpiar."
            } else {
                Show-Reporte $hallazgos
                $sel = if ([Console]::IsInputRedirected) { "" } else { Read-Host "  Números a limpiar separados por coma (Enter = todos)" }
                if ([string]::IsNullOrWhiteSpace($sel)) {
                    $seleccionados = $hallazgos
                } else {
                    $indices = $sel -split ',' | ForEach-Object { $_.Trim() } |
                               Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
                    $seleccionados = @()
                    foreach ($idx in $indices) {
                        if ($idx -ge 1 -and $idx -le $hallazgos.Count) {
                            $seleccionados += $hallazgos[$idx - 1]
                        }
                    }
                }
                foreach ($item in $seleccionados) { Remove-Residuo -Item $item | Out-Null }
                Invoke-CleanupMountpoints
                Write-Titulo "Resultado"
                $hallazgos = Find-Residuos
                Show-Reporte $hallazgos
            }
        }
        "4" {
            Show-GestionDependencias
        }
        "0" {
            $salir = $true
        }
        default {
            Write-Warn "Opción inválida."
        }
    }
} while (-not $salir)

Write-Host ""
Write-Host "  Listo." -ForegroundColor Green
Write-Host ""
