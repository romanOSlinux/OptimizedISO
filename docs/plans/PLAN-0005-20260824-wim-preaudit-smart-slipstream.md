# PLAN-0005 — Auditoría Previa del WIM y Slipstreaming Inteligente

**Fecha:** 2026-08-24  
**Estado:** COMPLETADO  
**Autor:** Antigravity (par de programación IA)  
**Rama objetivo:** `feat/wim-preaudit-smart-slipstream`

---

## Descripción del Problema

El pipeline actual de `New-OptimizedWindowsISO-v2.ps1` aplica slipstreaming de forma **ciega**: inyecta todos los paquetes `.msu`/`.cab` presentes en la carpeta `Updates/` sin verificar si el WIM base ya los contiene. Esto genera cuatro problemas concretos:

1. **Paquetes redundantes:** Si la ISO de Microsoft ya incluye una LCU reciente, DISM fallará silenciosamente (`0x800f0823` / "ya instalado") sin que el usuario sepa por qué.
2. **Paquetes más antiguos que la ISO:** Si el usuario descargó updates antes de que saliera una ISO más nueva, DISM los rechazará sin diagnóstico claro.
3. **Sin diagnóstico de nivel de parche:** No existe forma de saber a qué UBR (Update Build Revision) está el WIM antes de procesar.
4. **Bug de formato PSF confirmado empíricamente (2026-08-24):** El fallback de extracción `.cab` del script rompe con los **Checkpoint Cumulative Updates** (KB5043080). Estos paquetes usan formato PSF (*Patch Storage Format*) + WIM interno, no un `.cab` extraíble con `expand.exe`. El script actualmente reporta `ERROR: no se encontró .cab válido` y descarta el paquete silenciosamente, dejando el WIM sin el prerequisito obligatorio para la LCU.

Adicionalmente, `Get-WindowsUpdates.ps1` siempre descarga el paquete **más reciente del catálogo** sin conocer el nivel real de la ISO de destino.

---

## Objetivo

Implementar un paso de **auditoría previa del WIM** que:

1. Consulta los paquetes ya instalados en la imagen montada (`DISM /Get-Packages`).
2. Extrae el nivel de parche actual (KB + UBR) del WIM base.
3. Compara contra los paquetes presentes en la carpeta `Updates/`.
4. Filtra el slipstreaming: solo aplica paquetes que el WIM no tiene o que son más nuevos.
5. Emite un informe de diagnóstico claro antes de aplicar cambios.

---

## Cambios Propuestos

### Componente 1 — `New-OptimizedWindowsISO-v2.ps1`

#### Función nueva: `Get-WimPatchLevel`

Insertar antes del bloque de slipstreaming (actual línea ~4990).

```powershell
function Get-WimPatchLevel {
    param([string]$MountDir)
    # Llama a dism.exe /Image:$MountDir /Get-Packages /Format:Table
    # Parsea líneas con "Package_for_RollupFix" para extraer KBs instalados
    # Devuelve: @{ InstalledKBs = @("KB5058411","KB5043080",...); HighestUBR = 3374 }
}
```

#### Modificar: bloque SLIPSTREAMING (L.4990–5128)

Sustituir el filtrado simple `Get-ChildItem *.msu,*.cab` por:

```
1. Llamar Get-WimPatchLevel → obtener $wimPatchLevel
2. Mostrar nivel actual: "WIM base: Windows 11 24H2 - KB5058411 (UBR 3374)"
3. Para cada paquete en $orderedPackages:
   a. Extraer número KB del nombre del archivo
   b. Si ese KB ya está en $wimPatchLevel.InstalledKBs → Write-Info "YA INSTALADO, omitiendo" + skip
   c. Si no → aplicar con DISM /Add-Package (flujo actual)
4. Mostrar tabla resumen: [KB] [Tipo] [Acción: Aplicado / Omitido / Error]
```

**Punto de inserción exacto:** línea **4957** (inmediatamente después de `Write-OK "WIM índice X montado."` y antes del bloque `#== HABILITACIÓN OFFLINE DE .NET ==`).

---

### Componente 2 — `Get-WindowsUpdates.ps1`

#### Parámetro nuevo: `-SourceWIM`

```powershell
[Parameter()]
[string]$SourceWIM = ""   # Ruta a install.wim para auditoría previa
```

#### Lógica nueva: Auditoría WIM opcional antes de descargar

```
Si -SourceWIM se especifica:
  1. Montar WIM en carpeta temporal (solo lectura)
  2. Ejecutar dism.exe /Get-Packages → extraer KBs instalados
  3. Consultar catálogo → comparar KB más reciente vs. KB instalado
  4. Solo descargar si el catálogo tiene algo más nuevo
  5. Desmontar WIM (Discard)
  6. Informar: "ISO ya en nivel KB5058411. El catálogo tiene KB5061977 → descargando delta"
```

> **Nota:** Este parámetro es completamente opcional. Sin él, el comportamiento actual se preserva íntegramente.

---

### Componente 3 — `Get-WindowsUpdates.ps1` — Descarga de Checkpoint KB5043080

El Checkpoint `KB5043080` es **obligatorio** para Windows 11 24H2/25H2/LTSC 2024 antes de la LCU, pero actualmente **nadie lo descarga automáticamente**. El script de slipstreaming lo espera en la carpeta `Updates/` pero nunca llega.

#### Cambio: Agregar búsqueda de Checkpoint al `$searchMatrix`

```powershell
"11_24H2" {
    @{
        LCU         = "Cumulative Update Windows 11 24H2 $archTag"
        Checkpoint  = "Windows11.0-KB5043080-$archTag"   # NUEVO
        DotNet      = "Cumulative Update for .NET Framework 3.5 and 4.8.1 ..."
        SafeOS      = "Safe OS Dynamic Update ..."
    }
}
```

Y agregar al `$PackageType` el valor `"CheckpointOnly"` para descarga aislada.

---

### Componente 4 — Skill `windows-updates-servicing`

#### Actualizar `references/servicing-kb-matrix.md`

Agregar sección con el KB exacto del Checkpoint por versión:

| Versión | Checkpoint KB | Obligatorio |
|---------|--------------|-------------|
| Win 11 24H2 | KB5043080 | Sí |
| Win 11 25H2 | KB5043080 (mismo) | Sí |
| Win 11 LTSC 2024 | KB5043080 | Sí |
| Win 11 23H2 | No requerido | No |
| Win 10 22H2 | No requerido | No |

---

### Componente 5 — Fix Bug PSF: Fallback de extracción `.cab` en Checkpoint Updates ⚠️ URGENTE

> **Causa raíz verificada empíricamente el 2026-08-24.**  
> Archivo afectado: `New-OptimizedWindowsISO-v2.ps1` líneas **5080–5111**.

#### Análisis del MSU KB5043080 (confirmado con 7-Zip)

```
windows11.0-kb5043080-x64.msu  (510 MB, contenedor formato WIM)
├── DesktopDeployment.cab           ← metadatos deployment
├── DesktopDeployment_x86.cab       ← metadatos x86
├── SSU-26100.1738-x64.cab         ← SSU empaquetado DENTRO del MSU
├── Windows11.0-KB5043080-x64.psf  ← PAYLOAD REAL (PSF, no .cab)
├── Windows11.0-KB5043080-x64.wim  ← WIM auxiliar del parche
├── onepackage.AggregatedMetadata.cab
└── wsusscan.cab                    ← excluido correctamente
```

**El problema:** `expand.exe -F:*` no entiende el formato WIM del contenedor MSU.  
El `Get-ChildItem *.cab` posterior no encuentra ningún `.cab` de payload útil.  
Resultado: el paquete se descarta con `ERROR: no se encontró .cab válido`.  

**La raíz:** Los Checkpoint CU usan formato **PSF + WIM**, no el `.cab` monolítico de las LCU estándar. DISM debe procesar el `.msu` completo directamente — jamás puede extraerse el payload manualmente.

#### Lógica del fix: función `Test-MsuIsPsfFormat`

Antes de ejecutar el fallback `expand.exe`, detectar si el `.msu` es de tipo PSF:

```powershell
function Test-MsuIsPsfFormat {
    param([string]$MsuPath)
    # Estrategia 1: buscar la firma WIM en los primeros bytes del .msu
    # Un MSU de tipo PSF/Checkpoint tiene header WIM (MSWIM\x00\x00\x00)
    $header = [System.IO.File]::ReadAllBytes($MsuPath) | Select-Object -First 8
    $wimMagic = [byte[]]@(0x4D,0x53,0x57,0x49,0x4D,0x00,0x00,0x00)  # "MSWIM\0\0\0"
    $isPsf = ($header[0..7] -join ',') -eq ($wimMagic -join ',')
    return $isPsf
}
```

#### Nuevo flujo del fallback en el bucle de slipstreaming

```
Para cada $pkg en $orderedPackages:

  1. Intentar DISM /Add-Package con el .msu directo
     → Exit 0 o 3010: OK
     → Falla: continuar con fallback

  2. Si es .msu → Test-MsuIsPsfFormat

     a. Es PSF (Checkpoint CU):
        → Reintentar DISM /Add-Package /IgnoreCheck /NoRestart
        → Si falla igual: Write-Warn "Checkpoint PSF requiere WIM base compatible"
          + registrar en log de errores con código DISM exacto
          + NO intentar extract .cab (no existe)

     b. Es MSU estándar:
        → expand.exe -F:* → buscar .cab → DISM /Add-Package con .cab
        → (flujo actual, sin cambios)
```

#### Cambio de código — ubicación exacta (L.5080–5111)

**Antes (código actual):**
```powershell
if ($pkg.Extension -eq ".msu") {
    Write-Host " WARN"
    Write-Host "      Intentando extraer .cab interno..."
    $cabExtractDir = Join-Path $ScratchDir "Extracted_$($pkg.Name)"
    New-Item -ItemType Directory -Path $cabExtractDir -Force | Out-Null
    & expand.exe -F:* "$($pkg.FullName)" "$cabExtractDir" 2>&1 | Out-Null
    $cabFile = Get-ChildItem -Path $cabExtractDir -Filter "*.cab" |
        Where-Object { $_.Name -notmatch 'WSUSSCAN' } |
        Select-Object -First 1
    if ($cabFile) { ... } else {
        $failCount++
        Write-Host "      ERROR: no se encontró .cab válido dentro del .msu."
    }
}
```

**Después (con detección PSF):**
```powershell
if ($pkg.Extension -eq ".msu") {
    Write-Host " WARN" -ForegroundColor Yellow
    $isPsf = Test-MsuIsPsfFormat -MsuPath $pkg.FullName

    if ($isPsf) {
        # Checkpoint/PSF: DISM debe recibir el .msu completo con /IgnoreCheck
        Write-Host "      Formato PSF detectado (Checkpoint CU). Reintentando con /IgnoreCheck..." -ForegroundColor DarkYellow
        $dismRetryRes = Invoke-MonitoredProcess -FilePath "dism.exe" `
            -ArgumentList @("/Image:$WimMountDir", "/Add-Package",
                            "/PackagePath:$($pkg.FullName)",
                            "/IgnoreCheck", "/NoRestart",
                            "/ScratchDir:$ScratchDir", "/LogPath:$dismLog") `
            -AllowExitCodes @(0, 3010) `
            -TaskDescription "Slipstreaming PSF Checkpoint $($pkg.Name)" `
            -TimeoutSeconds 1800 `
            -HeartbeatIntervalSeconds $HeartbeatIntervalSeconds
        if ($dismRetryRes.Success) {
            $successCount++
            Write-Host "      OK (PSF Checkpoint aplicado)." -ForegroundColor Green
        } else {
            $failCount++
            Write-Host "      ERROR PSF. ExitCode: $($dismRetryRes.ExitCode). Ver: $dismLog" -ForegroundColor Red
        }
    } else {
        # MSU estándar: extraer .cab interno con expand.exe (flujo original)
        Write-Host "      Intentando extraer .cab interno..." -ForegroundColor Gray
        $cabExtractDir = Join-Path $ScratchDir "Extracted_$($pkg.Name)"
        New-Item -ItemType Directory -Path $cabExtractDir -Force | Out-Null
        & expand.exe -F:* "$($pkg.FullName)" "$cabExtractDir" 2>&1 | Out-Null
        $cabFile = Get-ChildItem -Path $cabExtractDir -Filter "*.cab" |
            Where-Object { $_.Name -notmatch 'WSUSSCAN' } |
            Select-Object -First 1
        if ($cabFile) { <# DISM /Add-Package con .cab — igual que antes #> }
        else {
            $failCount++
            Write-Host "      ERROR: no se encontró .cab válido dentro del .msu." -ForegroundColor Red
        }
    }
}
```

> **Nota sobre `/IgnoreCheck`:** Este flag indica a DISM que omita la validación de pre-requisitos en el paquete y confíe en que el entorno es compatible. Es seguro para Checkpoint CU porque el MSU ya lleva el SSU empaquetado (`SSU-26100.1738-x64.cab`) en su interior y DISM lo aplica automáticamente antes del payload principal.

---

## Diagrama del Nuevo Flujo

```
New-OptimizedWindowsISO-v2.ps1
│
├── PASO 5/6: mount install.wim → $WimMountDir
│
│   ┌─────────────────────────────────────────────┐
│   │  NUEVO: Get-WimPatchLevel                   │
│   │  dism /Get-Packages → extraer KBs           │
│   │  Mostrar: "WIM base: KB5058411 (UBR 3374)"  │
│   └───────────────────┬─────────────────────────┘
│                       │
│   ┌───────────────────▼─────────────────────────┐
│   │  SLIPSTREAMING INTELIGENTE (mejorado)        │
│   │  Para cada .msu/.cab en Updates/:           │
│   │    KB ya en WIM? → Omitir                   │
│   │    KB nuevo?     → Aplicar con DISM          │
│   │    KB inválido?  → Advertir                  │
│   └─────────────────────────────────────────────┘
│
└── ... (resto del pipeline sin cambios)


Get-WindowsUpdates.ps1  (con -SourceWIM opcional)
│
├── Montar WIM (read-only) → auditar KBs instalados
├── Consultar catálogo → solo si hay algo más nuevo
└── Descargar delta → desmontar WIM
```

---

## Archivos Afectados

| Archivo | Tipo de cambio | Prioridad |
|---------|---------------|----------|
| `scripts/New-OptimizedWindowsISO-v2.ps1` | MODIFY — función `Test-MsuIsPsfFormat` + fix fallback PSF (L.5080–5111) | 🔴 URGENTE |
| `scripts/New-OptimizedWindowsISO-v2.ps1` | MODIFY — función `Get-WimPatchLevel` + slipstreaming inteligente (L.4957) | 🟡 NORMAL |
| `scripts/Get-WindowsUpdates.ps1` | MODIFY — parámetro `-SourceWIM` + descarga de Checkpoint KB5043080 | 🟡 NORMAL |
| `.agents/skills/windows-updates-servicing/references/servicing-kb-matrix.md` | MODIFY — tabla Checkpoint KB por versión + nota PSF | 🟢 DOC |
| `docs/plans/README.md` | MODIFY — registro de este plan | 🟢 DOC |

---

## Orden de Implementación

> Los pasos marcados con 🔴 son bloqueantes y deben ir primero.

```
── FASE 1: Fix urgente (bloquea el slipstreaming de KB5043080) ─────────────
🔴 1. Agregar función Test-MsuIsPsfFormat a New-OptimizedWindowsISO-v2.ps1
🔴 2. Refactorizar fallback de extracción .cab (L.5080–5111) con detección PSF
🔴 3. Validar empíricamente con el MSU real:
       C:\scripts\Updates\11_24H2_amd64\windows11.0-kb5043080-x64_*.msu
🔴 4. Commit atómico: fix(slipstream): detectar formato PSF en Checkpoint CU

── FASE 2: Auditoría previa del WIM ────────────────────────────────────────
🟡 5. Implementar Get-WimPatchLevel (función aislada)
🟡 6. Integrar en el bucle de slipstreaming (insertar en L.4957)
🟡 7. Commit atómico: feat(slipstream): auditoria previa WIM Get-WimPatchLevel

── FASE 3: Mejoras a Get-WindowsUpdates.ps1 ────────────────────────────────
🟡 8. Agregar descarga automática de Checkpoint KB5043080 al $searchMatrix
🟡 9. Agregar parámetro -SourceWIM + lógica de auditoría previa
🟡 10. Commit atómico: feat(updates): descargar Checkpoint y soporte -SourceWIM

── FASE 4: Documentación ───────────────────────────────────────────────────
🟢 11. Actualizar servicing-kb-matrix.md con tabla Checkpoints + nota PSF
🟢 12. Commit atómico + actualizar estado del plan a COMPLETADO
```

---

## Plan de Verificación

### Pruebas Automatizadas

```powershell
# Smoke test del nuevo flujo de slipstreaming
.\scripts\Invoke-TestSuite.ps1 -Scope Updates

# Validar que KB ya instalado es omitido (no produce error DISM)
# Validar que KB nuevo es aplicado correctamente
# Validar orden: SSU → Checkpoint → LCU → .NET
```

### Verificación Manual

- Montar WIM antes y después → confirmar que el KB nuevo aparece en `/Get-Packages`
- Ejecutar con carpeta `Updates/` vacía → confirmar que el pipeline no falla
- Ejecutar con KB más antiguo que la ISO → confirmar advertencia clara sin error DISM fatal

---

## Riesgos y Mitigaciones

| Riesgo | Mitigación |
|--------|-----------|
| Header WIM del .msu difiere en versiones futuras | `Test-MsuIsPsfFormat` usa los primeros 8 bytes (`MSWIM\0\0\0`); estable desde Windows 11 21H2 |
| `/IgnoreCheck` aplica paquete incompatible | DISM igual reportará error si el paquete es realmente incompatible; `/IgnoreCheck` solo omite la validación de prerequisitos declarados, no la de arquitectura |
| `DISM /Get-Packages` lento en imágenes grandes | Ejecutar solo 1 vez por índice WIM; cachear resultado en `$wimPatchLevel` |
| Nombre de archivo KB no estándar → no se detecta | Parsear también `Package_for_RollupFix` del output de DISM, no solo el nombre del archivo |
| WIM en formato ESD (no montable con DISM) | Ya manejado: el script actual omite inyección en ESD; la auditoría también se omite |
| Checkpoint KB5043080 no disponible en catálogo | Fallback: advertir pero no bloquear el pipeline; el Checkpoint puede ya estar en la ISO |

---

## Historial de Revisiones

| Fecha | Cambio |
|-------|-------|
| 2026-08-24 | Creación inicial del plan (Componentes 1–4) |
| 2026-08-24 | Agregado Componente 5: fix bug PSF confirmado empíricamente con KB5043080 (MSU tipo WIM/PSF, `expand.exe` incompatible) |
| 2026-08-24 | **IMPLEMENTADO** — commits: `0817efe` (FASE 1+2), `3a86cd3` (FASE 3+4) |

*Plan generado el 2026-08-24. Estado final: COMPLETADO.*
