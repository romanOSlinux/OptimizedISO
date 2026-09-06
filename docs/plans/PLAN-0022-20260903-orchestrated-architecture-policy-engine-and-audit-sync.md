# PLAN-0022: Arquitectura Orquestada Unificada, Catálogo Maestro de Políticas (`Policy-Engine`) y Sincronización Transversal de Auditoría

- **Número:** PLAN-0022
- **Fecha:** 2026-09-03
- **Título:** Arquitectura Orquestada Unificada, Catálogo Maestro de Políticas (`Policy-Engine`) y Sincronización Transversal de Auditoría
- **Estado:** COMPLETADO
- **Autor:** Antigravity / romanOS Team
- **Rama:** `feature/offline-ui-tweaks`

---

## 1. Contexto y Diagnóstico Arquitectónico

El proyecto `romanOS / OptimizedISO` ha evolucionado sumando directivas oficiales y optimizaciones avanzadas (tales como los Módulos A–H del PLAN-0019). Sin embargo, se ha identificado una brecha estructural de sincronización (*code drift*):

1. **Definiciones redundantes y desfasadas:**
   - Las claves de registro y políticas de grupo (GPO/MDM) se definen de forma manual y aislada en `New-OptimizedWindowsISO-v2.ps1` (bloque `$optimizeXml` de `autounattend.xml`).
   - El script de post-instalación (`Auditar-Instalacion.cmd` / `PostInstall-Diagnostics.ps1`) posee su propio inventario de claves que no contemplaba las incorporaciones recientes (Widgets `AllowWidgets`, Bing Search `DisableWebSearch`, Copilot `TurnOffWindowsCopilot`, Recall `DisableAIDataAnalysis`, Delivery Optimization `DODownloadMode`, Reserved Storage `ShippedWithReserves`, etc.).
   - Los scripts bajo demanda (`romanOS-Toolkit.ps1`, `Win11-Debloat-v3-Adaptive.ps1`) mantienen catálogos paralelos.
2. **Incrustación de scripts en cadenas de texto:**
   - `New-OptimizedWindowsISO-v2.ps1` genera `PostInstall-Diagnostics.ps1` en la ISO a partir de un string gigantesco (`@" ... "@` de más de 500 líneas) en vez de copiar directamente el archivo físico del repositorio y sus dependencias en `Core\`.
3. **Ausencia de una regla de gobernanza de ecosistema:**
   - No existía una regla estricta en `.agents/AGENTS.md` ni en las skills del agente que obligara a validar que cualquier cambio en la compilación de la ISO tenga paridad inmediata en la auditoría y en las herramientas post-instalación.

---

## 2. Objetivos de la Solución

1. **Establecer una Fuente Única de Verdad (Single Source of Truth - SSOT):**
   Crear `scripts/Core/Policy-Engine.ps1` con una matriz canónica `$Global:romanOS_Policies` que registre cada directiva con su módulo de origen, ruta de registro, valor esperado, paquete AppX asociado y perfiles compatibles (1, 2, 3).
2. **Eliminar la Generación por String Embebido:**
   En `New-OptimizedWindowsISO-v2.ps1`, inyectar en `$OEM$` directamente los archivos físicos del repositorio (`scripts\PostInstall-Diagnostics.ps1` y `scripts\Core\*`), asegurando que cualquier cambio futuro se refleje automáticamente en la ISO sin duplicar código.
3. **Sincronización Total de Auditoría Post-Instalación:**
   Hacer que `PostInstall-Diagnostics.ps1` (y su lanzador `Auditar-Instalacion.cmd`) importe `Core\Policy-Engine.ps1` y audite dinámicamente el 100% de las políticas del catálogo (incluyendo Widgets, Bing, Copilot, Recall, Reserved Storage, etc.), tanto en Markdown como en el Dashboard HTML interactivo.
4. **Gobernanza Estricta para Agentes y Skills:**
   Añadir la **Regla 9: Arquitectura Unificada y Ecosistema Integral (SSOT)** en `.agents/AGENTS.md` y actualizar `skills/code-review` y `skills/project-audit` para impedir la creación de directivas huérfanas en el futuro.

---

## 3. Plan de Modificaciones en Código

### A. Núcleo Compartido: `scripts/Core/Policy-Engine.ps1` [NEW]
- Catálogo `$Global:romanOS_Policies`.
- Funciones:
  - `Get-RomanOSPolicies -Profile <1|2|3> -Category <...>`
  - `Test-RomanOSPolicy -Policy <obj>`
  - `Export-RomanOSUnattendCommands -Profile <1|2|3> -StartOrder <int>`

### B. Módulo de Diagnóstico: `scripts/PostInstall-Diagnostics.ps1` [MODIFY]
- Importar `Core\Policy-Engine.ps1`.
- Sustituir verificaciones estáticas por recorrido dinámico de `$Global:romanOS_Policies`.
- Incorporar auditoría de `MicrosoftWindows.Client.WebExperience` (Widgets).
- Actualizar Dashboard HTML offline para desplegar la tarjeta "Directivas Oficiales de Optimización (Policy-Engine)" con badges dinámicos.

### C. Generador de ISO: `scripts/New-OptimizedWindowsISO-v2.ps1` [MODIFY]
- Carga de `Core\Policy-Engine.ps1`.
- Generación dinámica de `$optimizeXml` en `autounattend.xml` mediante `Export-RomanOSUnattendCommands` (con fallback estático seguro).
- Reemplazo de las más de 500 líneas de string plano embebido por inyección física directa de `scripts\PostInstall-Diagnostics.ps1` y `scripts\Auditar-Instalacion.cmd` hacia `$OEM$\$$\Setup\Scripts` y `$OEM$\$1\Windows\Setup\Scripts`.

### D. Orquestador de la Suite: `scripts/romanOS-Toolkit.ps1` [MODIFY]
- Carga de `Core\Policy-Engine.ps1`.
- Integración de diagnósticos con el catálogo maestro.

### E. Gobernanza y Skills: `.agents/AGENTS.md`, `code-review`, `project-audit` [MODIFY]
- Agregar **Regla 9: Arquitectura Unificada y Ecosistema Integral (SSOT)** en `.agents/AGENTS.md`.
- Actualizar checklist en `.agents/skills/code-review/SKILL.md`.
- Actualizar directrices en `.agents/skills/project-audit/SKILL.md`.

### F. Suite de Pruebas: `scripts/Test-OptimizedISO-v2.ps1` [MODIFY]
- Test 7 de Arquitectura Unificada: comprobación de existencia de `Policy-Engine.ps1`, funciones canónicas, catálogo de políticas, generación XML, paridad en `PostInstall-Diagnostics.ps1`, inyección física en `v2`, integración en Toolkit y gobernanza en `.agents/AGENTS.md`.

---

## 4. Criterios de Aceptación y Validación

1. **AST & Compatibilidad Windows PowerShell 5.1:**
   Validación fría con `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass`.
2. **Codificación Obligatoria:**
   Verificación estricta de UTF-8 con BOM (`0xEF, 0xBB, 0xBF`) en todos los scripts nuevos o modificados.
3. **Auditoría Post-Instalación en Vivo:**
   Ejecución de `PostInstall-Diagnostics.ps1` verificando que genera el reporte Markdown y Dashboard HTML reflejando el estado de Widgets, Bing, Copilot, etc.
4. **Suite Automatizada:**
   Aprobación del 100% de los tests en `scripts/Test-OptimizedISO-v2.ps1` e `Invoke-TestSuite.ps1`.

---

## 5. Resultados de Validación Empírica

- **Codificación y Sintaxis:** 28/28 scripts del proyecto validados en frío contra Windows PowerShell 5.1 (`powershell.exe`) con UTF-8 BOM (`0xEF, 0xBB, 0xBF`) y 0 errores AST.
- **Auditoría Post-Instalación:** Ejecución en vivo de `PostInstall-Diagnostics.ps1` verificada con éxito (salida código 0, generación de `PostInstall_Report.md` y `PostInstall_Report.html` con tabla completa de directivas GPO de `Policy-Engine`).
- **Test Harness `Test-OptimizedISO-v2.ps1`:** 222/222 pruebas superadas (100% PASS, 0 fallos), incluyendo el nuevo Test 7 de contrato y paridad SSOT.
- **Suite Consolidada `Invoke-TestSuite.ps1`:** 6/6 fases aprobadas sin errores ni advertencias (559.9s).
