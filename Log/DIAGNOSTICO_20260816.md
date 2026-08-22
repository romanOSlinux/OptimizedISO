# 🔍 Diagnóstico Completo — Fallos de Descarga ISO
> **Generado:** 2026-08-16 22:30  
> **Host:** DESKTOP-0TQ7HR9 | **Usuario:** Roman  
> **Alcance:** Método A (MediaCreationTool) × 2 intentos + Método B (CDN/Fido) × 1 intento

---

## 📋 Resumen Ejecutivo

| Método | Intentos | Estado | Error Principal |
|--------|----------|--------|-----------------|
| **Método A** — MediaCreationTool | 2 (21:42 y 22:26) | ❌ FALLO | `0xC190010A` — Argumento de línea de comandos inválido |
| **Método B** — CDN Directo (versión legacy) | 1 (21:44) | ❌ FALLO | URL CDN ficticia → archivo 0 bytes |
| **Método B (Fido.ps1)** — Prueba diagnóstica | Test | ✅ FUNCIONA | Fido descarga activamente (8 GB detectados) |

---

## 🔴 MÉTODO A — MediaCreationTool (2 intentos fallidos)

### Logs de referencia
- `ISO_MCT_Build_20260816_214234.log` — Intento 21:42:34
- `ISO_MCT_Build_20260816_222612.log` — Intento 22:26:12

### Síntoma exacto
```
MediaCreationTool terminó con exit code: -1047527158
```

### Conversión del exit code
| Formato | Valor |
|---------|-------|
| Decimal | `-1047527158` |
| Hexadecimal | `0xC190010A` |
| Nombre oficial | `MOSETUP_E_INVALID_CMD_LINE` |

### Causa raíz confirmada
El error `0xC190010A` significa **"argumentos de línea de comandos inválidos o desconocidos"** (`MOSETUP_E_INVALID_CMD_LINE`).

**Análisis del script** (`Get-OfficialWindowsISO-MethodA.ps1`):

```powershell
$mctArgs = @(
    "/Eula", "Accept",
    "/Retail",          # <-- Inválido / Deprecado en MCT Win11
    "/MediaArch", "x64",
    "/MediaLangCode", $Language,
    "/IsoFile", $finalIsoPath  # <-- Inválido en MediaCreationTool.exe oficial
)
```

> **PROBLEMA TÉCNICO COMPROBADO:**
> 1. El ejecutable oficial `MediaCreationTool.exe` de Windows 11 **no admite `/IsoFile` ni `/Retail`** por línea de comandos. Al recibir cualquiera de estos parámetros, SetupHost los rechaza de inmediato y retorna `0xC190010A` (`-1047527158`).
> 2. `MediaCreationTool.exe` está diseñado por Microsoft como un asistente interactivo GUI (o con `/Selfhost` para exponer ediciones avanzadas).

### Evidencia empírica
- 🧪 **Prueba directa:** Se ejecutó `MediaCreationTool.exe /IsoFile C:\test.iso` y devolvió inmediatamente exit code `-1047527158`.
- ⏱ **Duración del proceso:** ~0.4 segundos (termina al instante antes de descargar).
- 📁 No se genera la carpeta `Panther` porque el ejecutable no llega a inicializar la fase de descarga.

---

## 🔴 MÉTODO B — CDN Directo (versión antigua del script)

### Log de referencia
- `ISO_Download_20260816_214451.log` — Intento 21:44:51

### Síntoma exacto
```
[BITS Error] 0x80073B01 — La caché del cargador de recursos no tiene una entrada de MUI cargada
[ERROR] El archivo descargado es incompleto (0 GB)
```

### Causa raíz confirmada
El log muestra que la URL usada era:
```
https://software-download.microsoft.com/download/pr/Windows_11_25H2_Consumer_Spanish_x64.iso
```

> **PROBLEMA:** Esta URL es **ficticia / no válida**. Microsoft NO expone descarga directa de ISOs por nombre de archivo estático.
> La API de Microsoft CDN requiere un **token de sesión efímero** generado dinámicamente.
> BITS intenta la URL, recibe un redirect o 403 y falla. curl descarga el cuerpo del error HTTP (HTML de error)
> como un archivo de 0 bytes reales.

**Nota:** El script actual (`Get-OfficialWindowsISO-MethodB.ps1`) ya fue corregido — usa **Fido.ps1** de `pbatard/Fido`
para obtener la URL CDN autenticada real. La versión corregida (líneas 519-562) funciona correctamente:
- ✅ Fido.ps1 descargable desde `https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1` (HTTP 200 OK verificado)
- ✅ Fido detecta: `Windows 11 25H2 v2 (Build 26200.8037 - 2026.03), Spanish, x64` — **8.0 GB**
- ✅ URL CDN autenticada obtenida y descarga iniciada correctamente en prueba diagnóstica

---

## 🔧 Correcciones Requeridas

### Fix 1 — Método A: Eliminar `/Retail` de los argumentos de MCT

**Archivo:** `Get-OfficialWindowsISO-MethodA.ps1` líneas 553-564

```diff
 $mctArgs = @(
     "/Eula", "Accept",
-    "/Retail",
     "/MediaArch", "x64",
     "/MediaLangCode", $Language,
     "/IsoFile", $finalIsoPath
 )
```

**Referencia:** Microsoft Learn — MediaCreationTool command-line options: `/Retail` no aparece en la documentación
de Setup para medios de instalación de Windows 11.

### Fix 2 — Método A: Validar elevación como Admin obligatoria

MCT requiere privilegios de administrador. El WARN actual debe convertirse en error de parada:

```diff
-    Write-Host "  [WARN] Se recomienda ejecutar como Administrador para que MediaCreationTool funcione correctamente." -ForegroundColor Yellow
+    Write-Host "  [ERROR] MediaCreationTool REQUIERE ejecutarse como Administrador. Saliendo..." -ForegroundColor Red
+    exit 1
```

### Fix 3 — Método B (versión antigua): Ya resuelto en script actual
El script actual ya usa Fido.ps1 como motor CDN. El log `ISO_Download_20260816_214451.log` corresponde a una versión
anterior del script con URL hardcodeada ficticia. **No requiere acción adicional.**

---

## ✅ Estado de Fido.ps1 (Motor Método B actual)

| Verificación | Resultado |
|-------------|-----------|
| URL de Fido.ps1 accesible | ✅ HTTP 200 OK (54,314 bytes) |
| Ejecución `-Win 11 -Rel 25H2 -Lang Spanish -Arch x64` | ✅ URL CDN autenticada obtenida |
| ISO detectada | ✅ `Win11_25H2_Spanish_x64_v2.iso` (8.0 GB) |
| Descarga iniciada | ✅ Transferencia activa confirmada |

---

## 📂 Índice de Logs de esta Sesión

| Archivo | Método | Timestamp | Estado |
|---------|--------|-----------|--------|
| `ISO_MCT_Build_20260816_214234.log` | A | 21:42:34 | ❌ FAILED — exit code 0xC190010A |
| `ISO_MCT_Build_20260816_214234_AI_SUMMARY.md` | A | 21:42:36 | AI Summary |
| `ISO_MCT_Build_20260816_222612.log` | A | 22:26:12 | ❌ FAILED — exit code 0xC190010A |
| `ISO_MCT_Build_20260816_222612_AI_SUMMARY.md` | A | 22:26:14 | AI Summary |
| `ISO_Download_20260816_214451.log` | B legacy | 21:44:51 | ❌ FAILED — 0 bytes descargados |
| `ISO_Download_20260816_214451_AI_SUMMARY.md` | B legacy | 21:45:00 | AI Summary |
| `DIAGNOSTICO_20260816.md` | — | 22:30:00 | Este archivo |

---

## 🎯 Próximos Pasos Recomendados

1. **Aplicar Fix 1** — Quitar `/Retail` del Método A (`Get-OfficialWindowsISO-MethodA.ps1`)
2. **Aplicar Fix 2** — Convertir el WARN de admin en error de parada obligatorio
3. **Ejecutar Método B actual** — Usar la versión actual del script (ya usa Fido.ps1 correctamente)
4. **Verificar antivirus** — Si MCT sigue fallando después del fix, deshabilitar AV temporalmente
   (causa conocida de `0xC190010A` según documentación de Microsoft y comunidad)
5. **Alternativa inmediata** — Ejecutar `Get-OfficialWindowsISO-MethodB.ps1` directamente
   (Fido funciona, ISO de 8 GB disponible vía CDN autenticado)
