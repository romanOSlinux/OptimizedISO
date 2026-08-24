# PLAN-0009 — Logging de Auditoría Integral del Build ISO

## Estado: PENDIENTE
## Fecha: 2026-08-24

---

## Descripción del Problema

El sistema de log actual de `New-OptimizedWindowsISO-v2.ps1` produce reportes
(`ISO_Build_*.log` y `AI_SUMMARY.md`) útiles para el flujo feliz, pero **silencian
fallos parciales y omisiones** en operaciones críticas de build.

En el intento del 2026-08-24 los Runtimes **no se inyectaron en el WIM offline** y el
reporte final no lo mencionó en absoluto — apareciendo como un build exitoso sin contexto
de qué recursos realmente quedaron dentro de la imagen.

### Operaciones actualmente sin cobertura de auditoría

| Área | Situación Actual | Riesgo |
|---|---|---|
| Runtimes ($OEM$ + WIM) | `Write-OK` genérico si OK, silencio si falla | ISO sin Runtimes sin saberlo |
| AppX Debloat offline | Errores solo en `Write-Host` amarillo (fuera de `$script:LogWarns`) | Apps protegidas parecen eliminadas |
| Drivers INF inyectados | Sin auditoría de firma digital post-inyección | BSOD 0xc0000428 al bootear |
| UBR antes vs. después | `Get-WimPatchLevel` existe pero no va al resumen final | El parche puede no haberse integrado |
| Metadatos de ISO final | Sin SHA-256 ni tipo de bootloader UEFI en el resumen | No se puede verificar integridad |
| SetupComplete.cmd | Solo se logea que se generó, no que tiene flags silenciosos | Runtime congelado en Sesión 0 |

---

## Fuentes Oficiales de Respaldo

- **DISM Troubleshooting:** [learn.microsoft.com — DISM Log Files](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism-troubleshooting)
- **Windows Setup Logs:** [learn.microsoft.com — setupact.log / setuperr.log](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/deployment-troubleshooting-and-log-files)
- **Drivers Offline + ForceUnsigned:** [learn.microsoft.com — Add and Remove Drivers](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/add-and-remove-driver-packages-to-a-windows-image-offline)
- **AppX Provisioned Packages:** [learn.microsoft.com — Remove-AppxProvisionedPackage](https://learn.microsoft.com/en-us/powershell/module/dism/remove-appxprovisionedpackage)
- **UBR y actualización de Windows:** [learn.microsoft.com — How Windows Updates Work](https://learn.microsoft.com/en-us/windows/deployment/update/how-windows-updates-work)
- **SetupComplete.cmd:** [learn.microsoft.com — Add Custom Script to Windows Setup](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/add-a-custom-script-to-windows-setup)
- **oscdimg / El Torito:** [learn.microsoft.com — Oscdimg Command-Line Options](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/oscdimg-command-line-options)

---

## Objetivo

Incorporar un **sistema de Matriz de Auditoría de Recursos** en `New-OptimizedWindowsISO-v2.ps1` que:
1. Se construye incrementalmente durante el build con registros tipados (OK / WARN / SKIP / FAIL).
2. Se vuelca en el resumen final (`AI_SUMMARY.md`, log `.log` y pantalla).
3. Convierte cualquier omisión o fallo parcial en una **ADVERTENCIA explícita e inequívoca**.
4. Se valida con nuevos tests unitarios en `Test-OptimizedISO-v2.ps1`.

---

## Proposed Changes

---

### Componente 1 — Variables de Estado + Función `Add-AuditRecord`

#### [MODIFY] [New-OptimizedWindowsISO-v2.ps1](file:///c:/OptimizedISO/scripts/New-OptimizedWindowsISO-v2.ps1)

**Ubicación: bloque de inicialización de variables de log (~líneas 340–350)**

```powershell
# ---- Matriz de Auditoría de Recursos (PLAN-0009) ----
$script:AuditResources = [System.Collections.Generic.List[PSObject]]::new()
$script:WimUbrBefore   = $null   # UBR del WIM antes del slipstream
$script:WimUbrAfter    = $null   # UBR del WIM después del slipstream
$script:IsoSha256      = $null   # Hash SHA-256 de la ISO final
$script:IsoSizeBytes   = $null   # Tamaño en bytes de la ISO final
$script:UefiBoot       = $null   # Tipo de sector UEFI inyectado
```

**Función `Add-AuditRecord` (nueva, junto a `Write-LogEntry`):**

```powershell
function Add-AuditRecord {
    param(
        [string]$Resource,
        [string]$Target,
        [ValidateSet("OK","WARN","SKIP","FAIL")] [string]$Status,
        [string]$Details = ""
    )
    $script:AuditResources.Add([PSCustomObject]@{
        Resource = $Resource
        Target   = $Target
        Status   = $Status
        Details  = $Details
    })
    # Propagar a acumuladores existentes para que aparezcan en el resumen actual
    if ($Status -eq "FAIL") { $script:LogErrors.Add("[AUDIT] $Resource ($Target): $Details") }
    if ($Status -eq "WARN") { $script:LogWarns.Add("[AUDIT] $Resource ($Target): $Details") }
}
```

---

### Componente 2 — Instrumentación en 8 Puntos del Flujo de Build

#### [MODIFY] [New-OptimizedWindowsISO-v2.ps1](file:///c:/OptimizedISO/scripts/New-OptimizedWindowsISO-v2.ps1)

**2A — Runtimes en $OEM$ (~línea 3821):**
```powershell
if ($runtimesInfo.Found) {
    # ... Copy-Item existente ...
    Add-AuditRecord -Resource "Runtimes (VC++ / DirectX)" -Target '$OEM$' -Status "OK" `
                    -Details "$($runtimesInfo.FileCount) archivos desde '$($runtimesInfo.Path)'"
} else {
    Add-AuditRecord -Resource "Runtimes (VC++ / DirectX)" -Target '$OEM$' -Status "SKIP" `
                    -Details "Carpeta Runtimes/ no detectada. Ejecute Get-EssentialRuntimes.ps1"
}
```

**2B — Runtimes en WIM Offline (~línea 6010):**
```powershell
# En éxito:
Add-AuditRecord -Resource "Runtimes (VC++ / DirectX)" -Target "WIM Idx $currentWimIndex" `
                -Status "OK" -Details "$($runtimesInfo.FileCount) archivos en $wimRuntimesDest"
# En SKIP (no encontrados):
Add-AuditRecord -Resource "Runtimes (VC++ / DirectX)" -Target "WIM Idx $currentWimIndex" `
                -Status "SKIP" -Details "No disponibles para inyección offline"
# En FAIL (dentro del catch del índice WIM):
Add-AuditRecord -Resource "Runtimes (VC++ / DirectX)" -Target "WIM Idx $currentWimIndex" `
                -Status "FAIL" -Details $_.Exception.Message
```

**2C — AppX Debloat offline (~línea 5731):**
Agregar contadores `$appxOk` / `$appxFail`, pasar errores a `Write-LogEntry WARN`, y al final del bucle:
```powershell
$appxStatus = if ($appxFail -gt 0 -and $appxOk -eq 0) { "FAIL" } `
              elseif ($appxFail -gt 0) { "WARN" } else { "OK" }
Add-AuditRecord -Resource "AppX Debloat offline" -Target "WIM Idx $currentWimIndex" `
                -Status $appxStatus `
                -Details "$appxOk eliminados, $appxFail protegidos/fallidos de $(@($selectedToRemove).Count)"
```

**2D — UBR del WIM antes del slipstream:**
```powershell
$wimPatch = Get-WimPatchLevel -MountDir $WimMountDir
$script:WimUbrBefore = $wimPatch.UBR
Write-LogEntry -Level "INFO" -Message "UBR WIM Inicial (Idx $currentWimIndex): $($wimPatch.UBR)"
```

**2E — UBR del WIM después del slipstream:**
```powershell
$wimPatchPost = Get-WimPatchLevel -MountDir $WimMountDir
$script:WimUbrAfter = $wimPatchPost.UBR
Add-AuditRecord -Resource "Windows Updates (UBR)" -Target "WIM Idx $currentWimIndex" `
                -Status (if ($wimPatchPost.UBR -gt $script:WimUbrBefore) { "OK" } else { "WARN" }) `
                -Details "UBR: $($script:WimUbrBefore) → $($wimPatchPost.UBR) | KBs: $($wimPatchPost.InstalledKBs -join ', ')"
```

**2F — Metadata de la ISO final:**
```powershell
if (Test-Path $OutputIsoPath) {
    $isoItem = Get-Item $OutputIsoPath
    $script:IsoSizeBytes = $isoItem.Length
    $script:IsoSha256    = (Get-FileHash -Path $OutputIsoPath -Algorithm SHA256).Hash
    Add-AuditRecord -Resource "ISO Final" -Target $OutputIsoPath -Status "OK" `
                    -Details "$([math]::Round($isoItem.Length / 1GB, 2)) GB | SHA-256: $($script:IsoSha256)"
} else {
    Add-AuditRecord -Resource "ISO Final" -Target $OutputIsoPath -Status "FAIL" `
                    -Details "oscdimg no generó el archivo de salida"
}
```

**2G — UEFI Bootloader type:**
```powershell
$script:UefiBoot = if ($oscdimgArgs -match "efisys_noprompt") {
    "efisys_noprompt.bin (Arranque directo, sin prompt)"
} else {
    "efisys.bin (Con prompt — puede no arrancar en instalaciones desatendidas)"
}
Add-AuditRecord -Resource "UEFI Bootloader" -Target "El Torito" -Status "OK" `
                -Details $script:UefiBoot
```

**2H — Drivers INF inyectados offline (si aplica):**
```powershell
$driversInjected = @(Get-WindowsDriver -Path $WimMountDir -ErrorAction SilentlyContinue)
$unsignedDrivers  = @($driversInjected | Where-Object { -not $_.Signed })
Add-AuditRecord -Resource "Drivers INF offline" -Target "WIM Idx $currentWimIndex" `
                -Status (if ($unsignedDrivers.Count -gt 0) { "WARN" } else { "OK" }) `
                -Details "$($driversInjected.Count) driver(s) | $($unsignedDrivers.Count) sin firma WHQL (riesgo BSOD 0xc0000428)"
```

---

### Componente 3 — Enriquecer `Write-LogSummary`

#### [MODIFY] [New-OptimizedWindowsISO-v2.ps1](file:///c:/OptimizedISO/scripts/New-OptimizedWindowsISO-v2.ps1)

Insertar en `Write-LogSummary`, después de la sección `## Execution Timeline`:

**En el AI_SUMMARY.md:**
```powershell
if ($script:AuditResources.Count -gt 0) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Injected Resources & Build Audit")
    [void]$sb.AppendLine("| Resource | Target | Status | Details |")
    [void]$sb.AppendLine("|---|---|---|---|")
    foreach ($rec in $script:AuditResources) {
        $badge = switch ($rec.Status) { "OK"{"OK"}; "WARN"{"WARN"}; "SKIP"{"SKIP"}; "FAIL"{"FAIL"} }
        [void]$sb.AppendLine("| $($rec.Resource -replace '\|','-') | $($rec.Target -replace '\|','-') | $badge | $($rec.Details -replace '\|','-') |")
    }
}
if ($script:IsoSha256) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## ISO Integrity")
    [void]$sb.AppendLine("| Property | Value |")
    [void]$sb.AppendLine("|---|---|")
    [void]$sb.AppendLine("| Size | $([math]::Round($script:IsoSizeBytes / 1GB, 2)) GB |")
    [void]$sb.AppendLine("| SHA-256 | ``$script:IsoSha256`` |")
    [void]$sb.AppendLine("| UEFI Bootloader | $script:UefiBoot |")
}
```

**En el log estructurado (.log):**
```powershell
Write-LogEntry -Level "INIT" -Message "--- MATRIZ DE AUDITORIA DE RECURSOS ---"
foreach ($rec in $script:AuditResources) {
    $level = switch ($rec.Status) { "OK"{"OK"}; "WARN"{"WARN"}; "FAIL"{"ERROR"}; default{"INFO"} }
    Write-LogEntry -Level $level -NoAccumulate `
                   -Message "[$($rec.Status)] $($rec.Resource) -> $($rec.Target): $($rec.Details)"
}
if ($script:IsoSha256) {
    Write-LogEntry -Level "OK"   -Message "ISO SHA-256: $script:IsoSha256"
    Write-LogEntry -Level "INFO" -Message "ISO Tamano : $([math]::Round($script:IsoSizeBytes / 1GB, 2)) GB"
    Write-LogEntry -Level "INFO" -Message "UEFI Boot  : $script:UefiBoot"
}
```

---

### Componente 4 — Fase 2M en el Arnés de Pruebas

#### [MODIFY] [Test-OptimizedISO-v2.ps1](file:///c:/OptimizedISO/scripts/Test-OptimizedISO-v2.ps1)

Insertar nueva **Fase 2M** entre Fase 2L y Fase 3:

```powershell
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
```

Actualizar también `$EXPECTED_FUNCS` de **52 → 53** (la nueva función `Add-AuditRecord`).

---

## Plan de Ejecución

| Fase | Acción | Archivo |
|---|---|---|
| 1 | Variables de scope + `Add-AuditRecord` | `New-OptimizedWindowsISO-v2.ps1` |
| 2 | Instrumentar 8 puntos (A–H) del flujo | `New-OptimizedWindowsISO-v2.ps1` |
| 3 | Enriquecer `Write-LogSummary` (AI_SUMMARY + .log) | `New-OptimizedWindowsISO-v2.ps1` |
| 4 | Agregar Fase 2M, `EXPECTED_FUNCS = 53` | `Test-OptimizedISO-v2.ps1` |
| 5 | Guardar plan en repo + actualizar `docs/plans/README.md` | `docs/plans/` |
| 6 | Commit atómico | Git |

---

## Verification Plan

### Automated Tests
```powershell
# Arnés de pruebas unitarias en Windows PowerShell 5.1
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -STA -NoProfile -ExecutionPolicy Bypass `
    -Command "& { & 'scripts/Test-OptimizedISO-v2.ps1' }"

# Suite maestra
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -STA -NoProfile -ExecutionPolicy Bypass `
    -Command "& { & 'scripts/Invoke-TestSuite.ps1' -Quick }"
```

### Manual Verification
- Verificar en `AI_SUMMARY.md` generado que existe la sección `## Injected Resources & Build Audit` con estado de cada recurso (Runtimes, AppX, UBR, Drivers, UEFI, ISO).
- Verificar que cualquier SKIP o FAIL aparece como `[AUDIT]` también en la sección de errores/warnings del mismo reporte.
- Verificar que el `.log` contiene la sección `--- MATRIZ DE AUDITORIA DE RECURSOS ---` con cada entrada clasificada por nivel.

---

## Archivos Impactados

| Archivo | Operación |
|---|---|
| [`New-OptimizedWindowsISO-v2.ps1`](file:///c:/OptimizedISO/scripts/New-OptimizedWindowsISO-v2.ps1) | MODIFY — Variables + `Add-AuditRecord` + 8 puntos + `Write-LogSummary` |
| [`Test-OptimizedISO-v2.ps1`](file:///c:/OptimizedISO/scripts/Test-OptimizedISO-v2.ps1) | MODIFY — Fase 2M + `EXPECTED_FUNCS = 53` |
| `docs/plans/PLAN-0009-20260824-comprehensive-build-audit-logging.md` | NEW — Este plan (en repo) |
| [`docs/plans/README.md`](file:///c:/OptimizedISO/docs/plans/README.md) | MODIFY — Registro del PLAN-0009 |
