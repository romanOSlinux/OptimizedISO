---
name: architecture-consolidation
description: Skill especializado para auditar redundancias, consolidar módulos hacia el SSOT (Policy-Engine/ControlCenter), gestionar de-escalada segura y decomisionar scripts obsoletos sin romper el arnés ni la documentación.
---

# 🏗️ Consolidación de Arquitectura y Decomisionamiento Seguro (romanOS)

Este skill define el protocolo de ingeniería industrial para auditar el ecosistema, eliminar redundancias y fusionar scripts de las Eras 1 y 2 en la arquitectura moderna de la Era 3 (Agentic OS / romanOS Studio / romanOS Control Center).

## 1. Principio de la Cerca de Chesterton (*Chesterton's Fence*)
> *"No elimines un script ni alteres una política hasta entender con exactitud matemática por qué se creó y quién la consume."*

Antes de modificar o retirar cualquier script:
1. **Rastrear Consumidores:** Ejecutar `grep_search` en todo el repositorio buscando referencias en `.cmd`, `.ps1`, `.xml`, `.cs` y `.md`.
2. **Identificar la Capa:** Determinar si la función pertenece a:
   - *Capa 1 (Invariantes del SO):* Debe vivir en `scripts/Core/Policy-Engine.ps1`.
   - *Capa 2 (Topología Dinámica):* Debe vivir en `scripts/Core/Hardware-Engine.ps1` o en los módulos dinámicos (`Switch-GameDevMode`, `Monitor-ThermalEnergy`).
   - *Capa 3 (UI / Orquestación):* Debe residir en `romanOS-Studio.ps1` (Fábrica) o `romanOS-ControlCenter.ps1` (En vivo).

## 2. Protocolo de Triage en 4 Categorías

Todo script evaluado en el ecosistema se clasifica taxativamente en:

1. **`[VITAL-SSOT]`**: Núcleo soberano e insustituible. Se mantiene y se protege contra desvíos.
   - Ejemplos: `Policy-Engine.ps1`, `Hardware-Engine.ps1`, `romanOS-Studio.ps1`, `romanOS-ControlCenter.ps1`, `Invoke-RomanOSHarness.ps1`.
2. **`[REFACTOR-BUILDER]`**: Scripts de empaquetado que deben ser saneados para eliminar residuos ciegos o interactivos.
   - Ejemplo: `New-OptimizedWindowsISO-v2.ps1` (eliminar menús de consola, eliminar debloat ciego, limpiar `SetupComplete.cmd`).
3. **`[CONSOLIDAR]`**: Scripts que realizan acciones duplicadas o dispersas. Deben ser absorbidos por el módulo moderno y canónico.
   - Ejemplo: `Optimize-GamingAndApps.ps1` absorbido por `Switch-GameDevMode.ps1`.
   - Ejemplo: `Audit-SystemOptimization.ps1` absorbido por `PostInstall-Diagnostics.ps1`.
4. **`[DEPRECAR/PURGAR]`**: Scripts que dañan el SO, aplican placebos o han sido 100% superados por la GUI.
   - Ejemplo: `romanOS-Toolkit.ps1` (CLI legado).
   - Ejemplo: Toggles aislados de `Desktop-Helpers/` que compiten con Control Center.

## 3. Protocolo de Decomisionamiento Seguro (Zero Broken Links)

Cuando un script es marcado para purga o consolidación:
1. **Extracción al SSOT:** Extraer cualquier directiva válida hacia `Policy-Engine.ps1`.
2. **Reemplazo Temporal (Shim de Redirección):** Si el script es invocado por accesos directos o tareas programadas existentes, reemplazar su contenido por una redirección limpia hacia el módulo canónico con advertencia visible.
3. **Sincronización en Cascada (Skill `ecosystem-sync`):** Actualizar `SetupComplete.cmd`, `autounattend.xml`, lanzadores `.cmd`, y manuales de documentación en `docs/`.
4. **Validación Mecánica:** Ejecutar `Invoke-RomanOSHarness.ps1` para asegurar que ningún contrato o prueba de regresión quede roto.
