# Plan PLAN-0001: Integración Opcional de Activación HWID en la ISO

| Campo | Valor |
|---|---|
| **ID** | PLAN-0001 |
| **Fecha** | 2026-08-23 |
| **Estado** | PENDIENTE |
| **Autor** | Antigravity (agente IA) |
| **Conversación origen** | babd15fe-6a78-448b-a692-93d33d4d76a0 |

---

## Contexto

`HWID_Activation.cmd` (MAS v3.12, massgrave.dev) existe actualmente como herramienta suelta en `scripts/`. El objetivo es diseñar su integración **completamente opcional** en el proceso de compilación de la ISO, sin forzarla ni ejecutarla automáticamente. El usuario decidirá si incluirla al momento de compilar.

---

## Decisiones de Diseño

> [!IMPORTANT]
> La activación **NUNCA se ejecuta automáticamente** en `SetupComplete.cmd`. Se copia a la ISO como herramienta accesible, con acceso directo en el Menú Inicio. El usuario final la activa manualmente con doble clic cuando lo desee.

> [!WARNING]
> El script requiere **conexión a internet** y **privilegios de Administrador** para funcionar. Si se ejecuta en un entorno de prueba (Hyper-V sin acceso WU) o en Sandbox, fallará con mensajes claros.

---

## Componentes a Modificar / Crear

---

### New-OptimizedWindowsISO-v2.ps1

#### [MODIFY] Bloque `param()`
Añadir parámetro:
```powershell
[switch]$IncludeHWIDActivation
```

#### [MODIFY] Wizard interactivo (`Invoke-WizardConfig` o sección de pasos)
Añadir **Paso 7/7 — Activación HWID (Opcional)**:
```
¿Incluir herramienta de Activación HWID (MAS) en la ISO?
  [1] Sí (se copia como herramienta, NO se ejecuta automáticamente)
  [2] No (omitir)
```
Solo se muestra en modo interactivo. En `-ZeroTouch` queda en `$false` salvo que se pase `-IncludeHWIDActivation` explícitamente.

#### [MODIFY] Paso de copia de archivos a la imagen (sección `$scriptsToInject`)
Si `$IncludeHWIDActivation` es `$true`:
- Copiar `HWID_Activation.cmd` a `$OEM$\$$\Setup\Scripts\HWID_Activation.cmd`
- Copiar `HWID_Activation.cmd` también a `sources\$OEM$\$$\Setup\Scripts\`

#### [MODIFY] Generación de `$tasksBlock` dentro de `SetupComplete.cmd`
Si `$IncludeHWIDActivation`, agregar al bloque de accesos directos del Menú Inicio:
```batch
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "..." >> "%LOG%"
```
Crea `Activar Windows (HWID).lnk` en:
`%ProgramData%\Microsoft\Windows\Start Menu\Programs\Herramientas del Sistema\`

El acceso directo apunta a:
```
%WINDIR%\Setup\Scripts\HWID_Activation.cmd /HWID
```
Con icono: `%SystemRoot%\System32\imageres.dll,97` (icono de seguridad/clave)

#### [MODIFY] Árbol de archivos del resumen final
Si `$IncludeHWIDActivation`:
```
│   ├── HWID_Activation.cmd     ← Activador MAS (ejecutar manualmente)
```

---

### romanOS-Toolkit.ps1

#### [MODIFY] Menú Principal
Añadir opción `[8] 🔑 Activar Windows con Licencia Digital (HWID/MAS)` que:
- Detecta si `HWID_Activation.cmd` existe en `$PSScriptRoot`
- Si existe: lo lanza con `Start-Process ... -Verb RunAs`
- Si no existe: muestra mensaje con URL de descarga oficial (massgrave.dev)

#### [MODIFY] `ValidateSet` del parámetro `-Module`
Añadir `"Activation"` a la lista.

#### [MODIFY] Función `Invoke-ActivationModule`
```powershell
function Invoke-ActivationModule {
    $hwid = Join-Path $PSScriptRoot "HWID_Activation.cmd"
    if (Test-Path $hwid) {
        Start-Process -FilePath $hwid -ArgumentList "/HWID" -Verb RunAs
    } else {
        Write-Warn "HWID_Activation.cmd no encontrado. Descárgalo desde massgrave.dev"
    }
}
```

---

### docs/GUIA_DE_EJECUCION_Y_COMANDOS.md

#### [MODIFY] Tabla de herramientas
| `HWID_Activation.cmd` | `HWID_Activation.cmd` | Activación permanente de Windows 10/11 con licencia digital | `/HWID`, `/HWID-NoEditionChange` |

#### [MODIFY] Sección Nueva — `## 13. Activación Windows HWID (Opcional)`
Documenta:
- Qué es, cuándo usarlo
- Cómo incluirlo en la ISO con `-IncludeHWIDActivation`
- Cómo lanzarlo manualmente desde el Menú Inicio post-instalación
- Disclaimer legal

---

### docs/MANUAL_DE_USO.md

#### [MODIFY] Sección de Generación de ISO
Añadir sub-sección:
> **Paso 7 (Opcional): Activación HWID**
> Si tu equipo tiene licencia OEM o digital preexistente, puedes incluir la herramienta MAS para facilitar la reactivación post-reinstalación.

---

## Flujo Completo Post-Integración

```
┌─────────────────────────────────────────────────────────────────┐
│  COMPILACIÓN DE LA ISO (New-OptimizedWindowsISO-v2.ps1)         │
│                                                                 │
│  Paso 7: ¿Incluir HWID_Activation.cmd?  [1] Sí  [2] No        │
│                                                                 │
│  SI SÍ:                                                         │
│    → Copia HWID_Activation.cmd a $OEM$\Setup\Scripts\          │
│    → Agrega acceso directo en Menú Inicio (Herramientas)        │
│    → NO ejecuta automáticamente                                 │
└──────────────────────────────────┬──────────────────────────────┘
                                   │
                     Primera vez al escritorio
                                   │
┌──────────────────────────────────▼──────────────────────────────┐
│  MENÚ INICIO → Herramientas del Sistema                         │
│                                                                 │
│  [Acceso Directo] 🔑 Activar Windows (HWID)                    │
│        ↓ (doble clic)                                          │
│  HWID_Activation.cmd /HWID  (se auto-eleva como Admin)         │
│        ↓                                                        │
│  → Instala GenuineTicket.xml via ClipSVC                        │
│  → Comunica con servidores de licencias de Microsoft            │
│  → Windows queda activado permanentemente                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Plan de Verificación

### Automático (sin cambios al test harness existente)
- Verificar que el parámetro `-IncludeHWIDActivation` existe en el bloque `param()`
- Verificar que `HWID_Activation.cmd` se copia correctamente si el flag está activo
- Verificar que `SetupComplete.cmd` **NO invoca** `HWID_Activation.cmd` directamente

### Manual (requiere ejecución real)
1. Compilar ISO con `-IncludeHWIDActivation`
2. Verificar estructura del árbol `$OEM$` en la ISO resultante
3. Iniciar VM en Hyper-V con la ISO
4. Confirmar que el acceso directo aparece en el Menú Inicio post-instalación
5. Ejecutar manualmente el acceso directo y confirmar activación

---

## Notas Importantes

- **MAS se distribuye bajo MIT License** — redistribución permitida
- El script es **self-contained** (un solo `.cmd`, sin dependencias externas)
- Requiere **Internet** activo; sin él muestra error claro y se detiene
- Compatible con **Windows 10 Build 10240+** y **Windows 11** todas las versiones
- **No compatible** con Windows Server (ya lo maneja internamente)
- El flag por defecto en ZeroTouch es `$false` (opt-in explícito)

---

*Plan generado el 2026-08-23 | Estado: PENDIENTE DE APROBACIÓN*
