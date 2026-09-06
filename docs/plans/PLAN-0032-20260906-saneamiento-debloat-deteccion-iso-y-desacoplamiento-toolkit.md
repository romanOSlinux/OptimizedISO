# PLAN-0032: Saneamiento Integral de Win11-Debloat-v3-Adaptive, Detección Automática de ISO y Desacoplamiento de Tareas en el Toolkit

**Fecha:** 2026-09-06  
**Autor:** romanOS / OptimizedISO Project Team  
**Estado:** COMPLETADO  
**Rama:** `feature/offline-ui-tweaks`  

---

## 1. Resumen Ejecutivo y Diagnóstico

### 1.1 El Problema
Al ejecutar `Win11-Debloat-v3-Adaptive.ps1` (tanto de forma autónoma tras instalar Windows como a través de la **Opción 1 del Toolkit Maestro**), el script presentaba fricciones de ejecución, redundancias y lentitud innecesaria:
1. **Falta de Inicialización de `$isIsoOptimized`:** La variable `$isIsoOptimized` existía como un marcador en el dashboard (línea 798) pero nunca se calculaba en el pre-flight. El script operaba "a ciegas", desconociendo si el sistema ya venía pre-optimizado por la ISO romanOS o si era un Windows virgen.
2. **Bloqueo Síncrono en Limpieza WinSxS (Sección 14):** A pesar de los objetivos de desacoplamiento, la Sección 14 ejecutaba incondicionalmente `DISM.exe /Online /Cleanup-Image /StartComponentCleanup`, congelando la ejecución durante 2 a 5 minutos en un sistema recién instalado para liberar 0 bytes (dado que la ISO ya consolidó el almacén con `/ResetBase` durante el build).
3. **Pregunta Redundante y Código Duplicado en Menús Contextuales (Sección 15):** La Sección 15 volvía a preguntar al usuario si deseaba instalar los menús contextuales (los cuales `SetupComplete.cmd` ya instaló) y mantenía un bloque fallback legacy con `reg.exe add` en lugar de apoyarse canónicamente en `Add-OptimizedContextMenus.ps1`.
4. **Ventanas Interactivas Innecesarias:** Las Secciones 2 (Win32) y 8 (Servicios) abrían ventanas de selección con `Out-GridView` listando apps inexistentes o servicios que ya estaban deshabilitados por la ISO.

---

## 2. Objetivos del Plan

1. **Implementar Detección Multi-Capa de ISO (`$isIsoOptimized`)**:
   - Detectar la presencia de archivos estructurales de romanOS (`C:\Windows\Setup\Scripts\Core\Policy-Engine.ps1`, `SetupComplete.cmd`) o directivas canónicas selladas en el registro (`DisableCloudOptimizedContent`, `AllowTelemetry = 0`).
   - Reflejar con precisión el estado de la base ISO en el Dashboard visual de bienvenida.

2. **Desacoplar la Limpieza de WinSxS (Sección 14)**:
   - Retirar la ejecución directa y bloqueante de `DISM /StartComponentCleanup` de `Win11-Debloat-v3-Adaptive.ps1`.
   - Sustituir por un bloque informativo no bloqueante que confirma la consolidación previa de la ISO y delega el mantenimiento periódico a `romanOS-Toolkit.ps1` / `Invoke-WindowsMaintenance.ps1`.

3. **Idempotencia y Saneamiento en Menús Contextuales (Sección 15)**:
   - Detectar si la suite de menús contextuales ya fue aplicada (`GamerTools` / `CLSID` clásico).
   - Si ya está presente, reportar estado activo y omitir preguntas redundantes.
   - Purgar el bloque fallback de llamadas `reg.exe add` para consolidar SSOT en `Add-OptimizedContextMenus.ps1`.

4. **Filtrado Inteligente en Servicios (Sección 8) y Apps Win32 (Sección 2)**:
   - Filtrar servicios para ofrecer únicamente aquellos cuyo `StartType` no sea `Disabled`. Si todos ya están deshabilitados, saltar automáticamente con reporte limpio.
   - Evaluar la existencia real de OneDrive, Teams y Skype antes de abrir menús de desinstalación.

5. **Alineación con el Toolkit Maestro (`romanOS-Toolkit.ps1`)**:
   - Garantizar que la invocación del módulo de Gaming / Debloat desde el Toolkit opere de forma rápida, inteligente y sin pausas innecesarias.

---

## 3. Matriz de Archivos Afectados

| Archivo | Acción | Descripción |
|---|---|---|
| `scripts/Win11-Debloat-v3-Adaptive.ps1` | MODIFICAR | Inicializar `$isIsoOptimized`, desacoplar Sección 14 (WinSxS), optimizar Sección 15 (Menús), y filtrar Secciones 2 y 8. |
| `scripts/Test-OptimizedISO-v2.ps1` | MODIFICAR | Pruebas unitarias para validar detección de `$isIsoOptimized`, erradicación del bloqueo de DISM y purga de `reg.exe` en la Sección 15. |
| `docs/plans/README.md` | MODIFICAR | Registrar PLAN-0032 en el índice de planes. |

---

## 4. Plan de Verificación

### 4.1 Verificación de Sintaxis y Codificación
- Asegurar formato estricto `UTF-8 con BOM` (`0xEF, 0xBB, 0xBF`).
- Validación en frío AST en Windows PowerShell 5.1 (`powershell.exe -STA -NoProfile -ExecutionPolicy Bypass`).

### 4.2 Verificación de Ejecución en Vivo
- Ejecutar `Win11-Debloat-v3-Adaptive.ps1 -Unattended` y verificar que el tiempo total sea inferior a 30 segundos, sin bloqueos de DISM y con detección transparente de la ISO.
- Ejecutar suite de pruebas unitarias (`Test-OptimizedISO-v2.ps1`) con reporte de métricas.
