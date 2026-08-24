# PLAN-0005 — Auditoría Previa del WIM y Slipstreaming Inteligente

**Fecha:** 2026-08-24  
**Estado:** PENDIENTE  
**Autor:** Antigravity (par de programación IA)  
**Rama objetivo:** `feat/wim-preaudit-smart-slipstream`

---

## Descripción del Problema

El pipeline actual de `New-OptimizedWindowsISO-v2.ps1` aplica slipstreaming de forma **ciega**: inyecta todos los paquetes `.msu`/`.cab` presentes en la carpeta `Updates/` sin verificar si el WIM base ya los contiene. Esto genera tres problemas concretos:

1. **Paquetes redundantes:** Si la ISO de Microsoft ya incluye una LCU reciente, DISM fallará silenciosamente (`0x800f0823` / "ya instalado") sin que el usuario sepa por qué.
2. **Paquetes más antiguos que la ISO:** Si el usuario descargó updates antes de que saliera una ISO más nueva, DISM los rechazará sin diagnóstico claro.
3. **Sin diagnóstico de nivel de parche:** No existe forma de saber a qué UBR (Update Build Revision) está el WIM antes de procesar.

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

| Archivo | Tipo de cambio |
|---------|---------------|
| `scripts/New-OptimizedWindowsISO-v2.ps1` | MODIFY — función Get-WimPatchLevel + slipstreaming inteligente (L.4957–5128) |
| `scripts/Get-WindowsUpdates.ps1` | MODIFY — parámetro -SourceWIM + descarga de Checkpoint KB5043080 |
| `.agents/skills/windows-updates-servicing/references/servicing-kb-matrix.md` | MODIFY — tabla Checkpoint KB por versión |
| `docs/plans/README.md` | MODIFY — registro de este plan |

---

## Orden de Implementación

```
1. Implementar Get-WimPatchLevel (función aislada, testeable)
2. Integrar en el bucle de slipstreaming de New-OptimizedWindowsISO-v2.ps1
3. Agregar -SourceWIM + auditoría a Get-WindowsUpdates.ps1
4. Agregar descarga de Checkpoint KB5043080 a Get-WindowsUpdates.ps1
5. Actualizar servicing-kb-matrix.md con tabla de Checkpoints
6. Validar con Test-OptimizedISO-v2.ps1 + Invoke-TestSuite.ps1
7. Commit atómico + actualizar estado del plan a COMPLETADO
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
| `DISM /Get-Packages` lento en imágenes grandes | Ejecutar solo 1 vez por índice WIM; cachear resultado en `$wimPatchLevel` |
| Nombre de archivo KB no estándar → no se detecta | Parsear también `Package_for_RollupFix` del output de DISM, no solo el nombre del archivo |
| WIM en formato ESD (no montable con DISM) | Ya manejado: el script actual omite inyección en ESD; la auditoría también se omite |
| Checkpoint KB5043080 no disponible en catálogo | Fallback: advertir pero no bloquear el pipeline; el Checkpoint puede ya estar en la ISO |

---

*Plan generado el 2026-08-24. Estado inicial: PENDIENTE.*
