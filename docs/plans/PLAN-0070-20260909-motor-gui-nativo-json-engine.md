# PLAN-0070: Motor GUI-Nativo Dedicado — New-OptimizedWindowsISO-GUI-Engine.ps1

**Fecha:** 2026-09-09
**Estado:** EN PROGRESO
**Area:** Arquitectura GUI/Engine, Motor headless puro, WIM Discovery
**Objetivo:** Crear un motor de compilacion ISO dedicado 100% a la GUI, copiado y refactorizado desde el motor original, que obedezca sin ambiguedad al JSON generado por romanOS-Studio.ps1.

---

## 1. Diagnostico Forense

El PLAN-0064 fue marcado COMPLETADO, pero tres fallas estructurales sobrevivieron:

### Falla A - Doble Import-BuildPreset (ambiguedad de carga)

Hay dos implementaciones de Import-BuildPreset:
- scripts/Core/UI-Engine.ps1 linea 575: usa Set-Variable -Scope 1 (fragil)
- scripts/Builder/New-OptimizedWindowsISO-v2.ps1 linea 1480: usa $mappings hashtable (robusto)

El motor llama a Import-BuildPreset en la linea 322, cuando UI-Engine.ps1 ya esta cargado.
Se ejecuta la version fragil de UI-Engine. Set-Variable -Scope 1 en el scope raiz del script no garantiza propagacion correcta.

### Falla B - Desajuste de nombres: OptimizationProfile vs $script:OptProfile

El JSON de la GUI contiene OptimizationProfile. Invoke-DeploymentChoices verifica .ContainsKey('OptimizationProfile') en $ScriptBoundParameters. La version de UI-Engine que realmente se ejecuta no hace el mapeo a OptProfile. El check falla y se muestra menu interactivo en headless.

### Falla C - Invoke-SelectionMenu intenta Console raw mode

Antes de devolver el default en headless, intenta leer [System.Console]::CursorTop para el modo de flechas. En una consola redirigida de la GUI puede lanzar excepcion silenciosa.

---

## 2. Solucion Adoptada

### Motor GUI-Nativo: New-OptimizedWindowsISO-GUI-Engine.ps1

Copia completa del motor original con 5 modificaciones quirurgicas:

1. Firma simplificada: Solo param([string]$PresetFile) - el JSON es la unica fuente de verdad
2. $script:Headless = $true incondicional - sin condicion booleana
3. Import-GUIPreset unificada - asigna $script:* Y $script:ResolvedParameters con nombres correctos
4. Invoke-DeploymentChoices con resolucion directa - lee $script:* sin depender de .ContainsKey(...)
5. Validacion temprana del JSON - si no hay SourceISO, exit 1 inmediato

### WIM Discovery anticipado en la GUI

Cuando el usuario selecciona una ISO, la GUI monta la ISO en background runspace y llena un ListBox de checkboxes con las ediciones disponibles. El JSON resultante incluye TargetWimIndex ya resuelto. El motor lo respeta sin preguntar.

---

## 3. Archivos Modificados

| Archivo | Tipo | Cambio |
|---------|------|--------|
| scripts/Builder/New-OptimizedWindowsISO-GUI-Engine.ps1 | NUEVO | Motor GUI-nativo |
| scripts/GUI/romanOS-Studio.ps1 | MODIFICADO | WIM Discovery + nuevo builder path |

---

## 4. Trazabilidad

- Regla 4: UTF-8 con BOM, compatibilidad PowerShell 5.1
- Regla 5: Plan guardado en docs/plans/PLAN-0070-...
- Regla 6: Sin binarios en Git
- Regla 9: SSOT en Policy-Engine.ps1 se conserva intacto