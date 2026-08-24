# PLAN-0006 — Detección Inteligente y Doble Inyección de Runtimes (OEM + WIM Offline)

**Fecha:** 2026-08-24  
**Estado:** COMPLETADO  
**Autor:** Antigravity (par de programación IA)  
**Rama objetivo:** `feat/runtimes-discovery-and-dual-injection`

---

## 1. Descripción del Problema

Cuando el usuario descarga los paquetes redistribuibles de Visual C++ y DirectX mediante `Get-EssentialRuntimes.ps1` (o los coloca manualmente en una carpeta `Runtimes/`), el generador de imágenes `New-OptimizedWindowsISO-v2.ps1` presenta tres limitaciones críticas:

1. **Falta de Diagnóstico y Visibilidad en Pre-vuelo (Paso 0):**  
   El script comienza inmediatamente la extracción de la ISO sin mostrar un reporte inicial que confirme si los Runtimes, Actualizaciones (`Updates/`) o Drivers (`Drivers/`) fueron detectados y están listos para integrarse.
2. **Rutas Candidatas de Búsqueda Insuficientes:**  
   La búsqueda se limita a `$PSScriptRoot\Runtimes` y `..\Runtimes`. Si el script es invocado desde otra ruta de consola o las carpetas están en la raíz del espacio de trabajo (`C:\OptimizedISO\scripts\Runtimes`, `C:\scripts\Runtimes`, `.\Runtimes`), la detección puede fallar o pasar inadvertida con un mensaje tenue en gris.
3. **Inyección Unilateral (Solo en `$OEM$`, Nunca en el WIM Offline):**  
   En el Paso 2/6 los archivos se copian a `sources\$OEM$`, pero en el Paso 5/6 (inyección offline en `install.wim`), **se omitía la copia de la carpeta `Runtimes/` a `Windows\Setup\Scripts\Runtimes`**. Si una instalación desatendida o manual no procesa `$OEM$`, `SetupComplete.cmd` no encuentra los instaladores al primer arranque del escritorio.

---

## 2. Objetivos de la Implementación

1. Crear la función especializada **`Resolve-RuntimesDirectory`** con exploración exhaustiva de rutas absolutas, relativas y del workspace.
2. Incorporar un **Panel de Pre-vuelo de Recursos** antes del Paso 1/6 que informe visualmente con badges `[OK]` / `[INFO]` el estado de:
   - Runtimes (VC++ 2005-2022 y DirectX End-User)
   - Actualizaciones (.msu / .cab en `Updates/`)
   - Controladores (.inf en `Drivers/`)
3. Implementar la **Doble Inyección Garantizada**:
   - Inyección en `$OEM$` (`sources\$OEM$\$$\Setup\Scripts\Runtimes`)
   - Inyección directa en el WIM montado (`$WimMountDir\Windows\Setup\Scripts\Runtimes`)
4. Actualizar el arnés de pruebas unitarias (`Test-OptimizedISO-v2.ps1`) para registrar `Resolve-RuntimesDirectory` y certificar 100% PASS.

---

## 3. Cambios Propuestos

### Componente 1 — `New-OptimizedWindowsISO-v2.ps1`: Función `Resolve-RuntimesDirectory`

Insertar en la sección de funciones auxiliares:

```powershell
function Resolve-RuntimesDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ExplicitPath = ""
    )

    $candidates = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        $candidates.Add($ExplicitPath)
    } else {
        $candidates.Add((Join-Path (Get-Location) "Runtimes"))
        $candidates.Add((Join-Path (Get-Location) "scripts\Runtimes"))
        if ($ScriptsDir) {
            $candidates.Add((Join-Path $ScriptsDir "Runtimes"))
            $candidates.Add((Join-Path (Split-Path -Parent $ScriptsDir) "Runtimes"))
        }
        if ($PSScriptRoot) {
            $candidates.Add((Join-Path $PSScriptRoot "Runtimes"))
            $candidates.Add((Join-Path (Split-Path -Parent $PSScriptRoot) "Runtimes"))
        }
        $candidates.Add("C:\OptimizedISO\scripts\Runtimes")
        $candidates.Add("C:\OptimizedISO\Runtimes")
        $candidates.Add("C:\scripts\Runtimes")
        $candidates.Add("C:\Runtimes")
    }

    foreach ($cand in $candidates) {
        if ($cand -and (Test-Path $cand)) {
            $files = Get-ChildItem -Path $cand -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -in '.exe', '.msi', '.cab' }

            if ($files -and $files.Count -gt 0) {
                $hasVc = ($files | Where-Object { $_.Name -match 'vc_redist' }).Count -gt 0
                $hasDx = ($files | Where-Object { $_.Name -match 'dxsetup|d3dx' }).Count -gt 0
                return [PSCustomObject]@{
                    Path        = (Resolve-Path $cand).Path
                    Found       = $true
                    FileCount   = $files.Count
                    HasVcRedist = $hasVc
                    HasDirectX  = $hasDx
                    Files       = $files
                }
            }
        }
    }

    return [PSCustomObject]@{
        Path        = $null
        Found       = $false
        FileCount   = 0
        HasVcRedist = $false
        HasDirectX  = $false
        Files       = @()
    }
}
```

---

### Componente 2 — Panel de Pre-vuelo de Recursos (Paso 0)

Antes de `Write-Step "1/6 - Extrayendo ISO..."`, agregar el bloque de diagnóstico visual:

```powershell
Write-Host ""
Write-Host "  ══ Diagnóstico Pre-vuelo de Recursos Opcionales ══" -ForegroundColor Cyan

$runtimesInfo = Resolve-RuntimesDirectory -ExplicitPath $RuntimesPath
if ($runtimesInfo.Found) {
    Write-OK "Runtimes Esenciales : Encontrados en '$($runtimesInfo.Path)' ($($runtimesInfo.FileCount) instaladores)"
} else {
    Write-Info "Runtimes Esenciales : No detectados (Opcional - ejecute Get-EssentialRuntimes.ps1 si los requiere)"
}

# Diagnóstico de Updates y Drivers...
```

---

### Componente 3 — Doble Inyección en Paso 2/6 y Paso 5/6

1. **En Paso 2/6 (Estructura `$OEM$`):**
   Utilizar `$runtimesInfo.Path` para copiar a `sources\$OEM$\$$\Setup\Scripts\Runtimes`.

2. **En Paso 5/6 (WIM Montado Offline):**
   Agregar bloque de copia offline:
   ```powershell
   if ($runtimesInfo.Found -and (Test-Path $runtimesInfo.Path)) {
       $wimRuntimesDest = Join-Path $wimScriptsDir "Runtimes"
       if (-not (Test-Path $wimRuntimesDest)) {
           New-Item -ItemType Directory -Path $wimRuntimesDest -Force | Out-Null
       }
       Copy-Item -Path "$($runtimesInfo.Path)\*" -Destination $wimRuntimesDest -Recurse -Force
       Write-OK "Inyectado en WIM índice ${wimIndex}: Runtimes Esenciales ($($runtimesInfo.FileCount) archivos)"
   }
   ```

---

### Componente 4 — Arnés de Pruebas (`Test-OptimizedISO-v2.ps1`)

- Incrementar `$EXPECTED_FUNCS` a `42`.
- Agregar `Resolve-RuntimesDirectory` a la lista `$expectedList`.
- Agregar aserción unitaria probando la resolución de `Runtimes/` con directorio mock y real.

---

## 4. Archivos Afectados

| Archivo | Tipo de cambio | Propósito |
| :--- | :--- | :--- |
| `scripts/New-OptimizedWindowsISO-v2.ps1` | MODIFY | Agregar `Resolve-RuntimesDirectory`, pre-vuelo de recursos y doble inyección (Paso 2 y Paso 5). |
| `scripts/Test-OptimizedISO-v2.ps1` | MODIFY | Actualizar conteo de funciones a 42 y añadir pruebas unitarias. |
| `docs/plans/README.md` | MODIFY | Registrar `PLAN-0006` en el índice de trazabilidad. |

---

## 5. Plan de Verificación

```powershell
# 1. Validación de Sintaxis AST y UTF-8 BOM en PowerShell 5.1
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "scripts/Invoke-TestSuite.ps1" -Quick

# 2. Ejecución Completa del Arnés de Pruebas Unitarias
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "scripts/Test-OptimizedISO-v2.ps1"
```

---

## 6. Historial de Revisiones

| Fecha | Estado | Detalle |
| :--- | :--- | :--- |
| 2026-08-24 | PENDIENTE | Creación formal del plan para resolver detección y doble inyección de Runtimes. |
| 2026-08-24 | COMPLETADO | Implementación de `Resolve-RuntimesDirectory`, pre-vuelo de recursos, doble inyección OEM+WIM y pruebas unitarias (154/154 PASS). |
