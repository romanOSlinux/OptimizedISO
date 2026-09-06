# PLAN-0020 — Fix: `reg.exe add` falla por sub-claves intermedias inexistentes en hives offline

**Fecha:** 2026-09-02  
**Estado:** CANCELADO  
**Motivo de Cancelación:** Descartado formalmente tras auditoría empírica. Las premisas de que `reg.exe add` no crea sub-claves intermedias y de que originaba los errores `ERROR: El parámetro no es correcto` eran un falso diagnóstico. La causa real residía en la invocación de `reg.exe unload` preventivo sin redirección de salida estándar/error en `Invoke-RegUnloadHive`, y el bloqueo de `TaskbarDa` por el driver de protección UCPD del kernel de Windows 11.  
**Rama:** `feature/offline-ui-tweaks`  
**Script afectado:** [`New-OptimizedWindowsISO-v2.ps1`](../../scripts/New-OptimizedWindowsISO-v2.ps1)

---

## Descripción del Problema

Durante el build offline de la ISO se producen tres clases de errores distintos al intentar
escribir valores en hives de registro montados (`_ROMANOS_SW`, `OfflineDefaultUser`).
Todos comparten la misma causa raíz: **`reg.exe add` no crea sub-claves intermedias de forma
recursiva cuando la ruta de destino no existe en el hive virgen**.

---

## Errores Detectados

### Error 1 — DISM `/Set-ReservedStorageState` → Exit code 50

| Campo | Valor |
|---|---|
| **Sección** | `══ Desactivar Reserved Storage Offline (DISM) ══` |
| **Código DISM** | `50` = `ERROR_NOT_SUPPORTED` |
| **Causa** | `/Set-ReservedStorageState` solo opera en imágenes WIM que fueron originalmente capturadas con Reserved Storage activo. En WIM virgen de media oficial esto no es modificable offline. |
| **Impacto** | Ninguno funcional. El `[WARN] Continuando` es el comportamiento correcto. |
| **Acción** | ✅ **Ninguna** — el manejo actual es suficiente. Se añade solo comentario documental. |

---

### Error 2 — `reg.exe add` en `Invoke-WimAiHardening` → `ERROR: El parámetro no es correcto.` (x2)

| Campo | Valor |
|---|---|
| **Sección** | `══ Hardening de Recall / Windows AI Offline (WIM) ══` |
| **Línea** | L3354–L3356 |
| **Causa** | El hive `HKLM\_ROMANOS_SW` virgen no contiene `Policies\Microsoft\Windows\WindowsAI`. `reg.exe add` no crea rutas intermedias automáticamente. |
| **Impacto** | Las políticas `AllowRecallEnablement=0` y `DisableAIDataAnalysis=1` **no se aplican**. El `[OK]` final es engañoso porque no se verifica `$LASTEXITCODE` por política. |

**Fix:** Pre-crear la ruta con `reg.exe add <ruta> /f` antes de escribir el valor.

```powershell
# ANTES (buggy):
foreach ($pol in $policies) {
    & reg.exe add $pol.Key /v $pol.Name /t $pol.Type /d $pol.Data /f 2>&1 | Out-Null
}

# DESPUÉS (fix):
foreach ($pol in $policies) {
    & reg.exe add $pol.Key /f 2>&1 | Out-Null   # <-- crea ruta intermedia
    & reg.exe add $pol.Key /v $pol.Name /t $pol.Type /d $pol.Data /f 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "No se pudo aplicar politica: $($pol.Key) /v $($pol.Name)"
    }
}
```

---

### Error 3 — `reg.exe add` en tweaks visuales → `[WARN] TaskbarDa`

| Campo | Valor |
|---|---|
| **Sección** | `══ Tweaks visuales offline ══` |
| **Línea** | L6510–L6514 |
| **Causa** | El NTUSER.DAT virgen del usuario Default no contiene `Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`. Windows la crea en el primer login. `reg.exe add` no crea la ruta intermedia. |
| **Impacto** | `TaskbarDa`, `TaskbarAl`, `ShowTaskViewButton` y `HideFileExt` **no se aplican**. El usuario verá la barra de tareas con configuración por defecto de Microsoft en el primer inicio. |

**Fix:** Pre-crear todas las rutas únicas antes del bucle de valores.

```powershell
# DESPUÉS (fix):
$tweaks | Select-Object -ExpandProperty Path -Unique | ForEach-Object {
    & reg.exe add $_ /f 2>&1 | Out-Null   # <-- crea rutas intermedias
}

foreach ($tweak in $tweaks) {
    & reg.exe add $tweak.Path /v $tweak.Name /t $tweak.Type /d $tweak.Data /f 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Error aplicando tweak: $($tweak.Path) /v $($tweak.Name)"
    }
}
```

---

## Cambios Propuestos

### [MODIFY] `New-OptimizedWindowsISO-v2.ps1`

| Cambio | Línea aprox. | Descripción |
|---|---|---|
| Pre-crear sub-claves en `Invoke-WimAiHardening` | L3354 | `reg.exe add <key> /f` antes de cada política |
| Verificar `$LASTEXITCODE` por política en Recall | L3355 | Agregar `if ($LASTEXITCODE -ne 0) { Write-Warn ... }` |
| Pre-crear rutas únicas en tweaks visuales | L6510 | `Select -Unique | ForEach { reg add /f }` |
| Comentario documental DISM exit 50 | L6270 | Explicar que exit 50 es esperado en WIM virgen |

---

## Plan de Verificación

### Prueba automatizada

```powershell
& "C:\OptimizedISO\scripts\Invoke-TestSuite.ps1"
```

### Verificación manual post-build

```powershell
# Montar WIM resultante y verificar claves de Recall:
reg query "HKLM\_ROMANOS_SW\Policies\Microsoft\Windows\WindowsAI"
# Esperado: AllowRecallEnablement = 0x0, DisableAIDataAnalysis = 0x1

# Verificar NTUSER.DAT Default User:
reg query "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa
# Esperado: TaskbarDa = 0x0
```

Confirmar que **no aparecen** líneas `ERROR: El parametro no es correcto.` en la salida del build.

---

## Notas

> [!IMPORTANT]
> El error 1 (DISM exit 50) no requiere corrección de código. Es una limitación documentada:
> `/Set-ReservedStorageState` no opera en WIM virgen extraído del media oficial. El `[WARN]` actual es correcto.

> [!NOTE]
> Todos los `.ps1` modificados deben guardarse con **UTF-8 con BOM** (Regla 4, AGENTS.md).

---

*Plan generado el 2026-09-02. Autor: Antigravity AI.*
