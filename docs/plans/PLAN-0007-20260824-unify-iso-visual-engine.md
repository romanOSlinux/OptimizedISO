# PLAN-0007 — Unificación del Motor Visual y Formato de Consola (UI-Engine) en New-OptimizedWindowsISO-v2.ps1

**Fecha:** 2026-08-24  
**Estado:** EN PROGRESO  
**Autor:** Antigravity (par de programación IA)  
**Rama objetivo:** `feature/offline-ui-tweaks`

---

## 1. Descripción del Problema

Mientras que todos los módulos y herramientas auxiliares del repositorio (`Win11-Debloat-v3-Adaptive.ps1`, `Get-OfficialWindowsISO.ps1`, `Get-EssentialRuntimes.ps1`, `Get-WindowsUpdates.ps1`, `Invoke-WindowsSecurityHardening.ps1`, `Invoke-WindowsMaintenance.ps1`, `PostInstall-Diagnostics.ps1` y `romanOS-Toolkit.ps1`) utilizan el motor visual centralizado [`scripts/Core/UI-Engine.ps1`](file:///c:/OptimizedISO/scripts/Core/UI-Engine.ps1), el generador principal de imágenes [`scripts/New-OptimizedWindowsISO-v2.ps1`](file:///c:/OptimizedISO/scripts/New-OptimizedWindowsISO-v2.ps1) quedó desalineado con las siguientes discrepancias:

1. **Falta de Importación de `UI-Engine.ps1`:**  
   El script no importa el componente visual común ni cuenta con su bloque de resolución multi-ruta.
2. **Encabezado Desconectado (`Write-Banner` Magenta):**  
   Usa un banner rígido multilínea en color Magenta que difiere de la paleta cian, centrado automático y telemetría de sistema de `Show-UnifiedBanner`.
3. **Formato de Pasos No Estandarizado:**  
   `Write-Step` imprime `>>> 1/6 - ...` en texto plano con timestamp en lugar de la estructura estandarizada `Write-StepHeader -StepNumber X -TotalSteps Y`.
4. **Cajas de Resumen y Menús Locales Duplicados:**  
   `Write-LogSummary` dibuja cajas manuales con caracteres Unicode en lugar de aprovechar `Show-UnifiedSummary`.

---

## 2. Objetivos de la Implementación

1. **Importación Dinámica y Resiliente:** Incorporar la carga estándar de `Core\UI-Engine.ps1` con fallback en caso de ejecución standalone aislada.
2. **Adopción de `Show-UnifiedBanner`:** Presentar la identidad visual de romanOS con telemetría del host (Host, Usuario, SO, espacio libre en `C:`).
3. **Unificación de Pasos (`Write-StepHeader` / `Write-Step`):** Mantener intacta la recolección de métricas de tiempo (`$script:LogSteps`, `$script:CurrentStepObj`, `$script:AiSummaryFile`) mientras se adopta el formato estético unificado.
4. **Resumen Final Unificado (`Show-UnifiedSummary`):** Delegar la presentación de resultados, estados de error y enlaces a logs en el componente oficial de `UI-Engine`.
5. **Certificación del 100% en el Arnés de Pruebas:** Validar en Windows PowerShell 5.1 (`powershell.exe`) que `Test-OptimizedISO-v2.ps1` e `Invoke-TestSuite.ps1` superen todas las pruebas sin regresiones.

---

## 3. Plan de Modificaciones

### Componente 1 — Carga de `UI-Engine.ps1` en `New-OptimizedWindowsISO-v2.ps1`
Agregar en la sección de configuración general la carga con búsqueda en rutas candidatas:
```powershell
$uiEnginePaths = @(
    (Join-Path $PSScriptRoot "Core\UI-Engine.ps1"),
    (Join-Path $PSScriptRoot "UI-Engine.ps1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Core\UI-Engine.ps1"),
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
```

### Componente 2 — Sustitución de `Write-Banner` por `Show-UnifiedBanner`
Reemplazar la llamada a `Write-Banner` en el punto de entrada por:
```powershell
Show-UnifiedBanner -Title "GENERADOR DE ISO OPTIMIZADA DE WINDOWS" `
                   -Subtitle "romanOS v2.0 • Descarga Oficial + Layout WinRE + Dark Mode + Debloat" `
                   -ShowSystemInfo
```

### Componente 3 — Armonización de `Write-Step` con `Write-StepHeader` y Telemetría
Actualizar `Write-Step` para que parsee números de paso `[X/Y]` e invoque `Write-StepHeader` si `UI-Engine` está cargado, alimentando simultáneamente el log estructurado.

### Componente 4 — Adopción de `Show-UnifiedSummary` en `Write-LogSummary`
Utilizar `Show-UnifiedSummary` para emitir el bloque de cierre estético con enlaces a logs de AI, estructurado y transcript.

---

## 4. Archivos Afectados

| Archivo | Tipo de cambio | Propósito |
| :--- | :--- | :--- |
| `docs/plans/PLAN-0007-20260824-unify-iso-visual-engine.md` | NEW | Documento formal de planificación de la migración visual. |
| `docs/plans/README.md` | MODIFY | Registro de PLAN-0007 en el índice del repositorio. |
| `scripts/New-OptimizedWindowsISO-v2.ps1` | MODIFY | Integrar UI-Engine, Show-UnifiedBanner, Write-StepHeader y Show-UnifiedSummary. |
| `scripts/Test-OptimizedISO-v2.ps1` | MODIFY | Validar compatibilidad de llamadas y aserciones del harness. |

---

## 5. Plan de Verificación

```powershell
# 1. Ejecutar arnés unitario en Windows PowerShell 5.1
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "scripts/Test-OptimizedISO-v2.ps1"

# 2. Ejecutar suite consolidada completa
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "scripts/Invoke-TestSuite.ps1"
```

---

## 6. Historial de Revisiones

| Fecha | Estado | Detalle |
| :--- | :--- | :--- |
| 2026-08-24 | EN PROGRESO | Creación del plan e inicio de la migración hacia UI-Engine.ps1. |
| 2026-08-24 | COMPLETADO | Migración implementada y validada: carga multi-ruta de UI-Engine, Show-UnifiedBanner, Write-StepHeader, Show-UnifiedSummary con guards defensivos. Test-OptimizedISO-v2.ps1: 154/154 PASS. Invoke-TestSuite.ps1: COMPLETADO CON ÉXITO [OK]. |
