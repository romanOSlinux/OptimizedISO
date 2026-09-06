# PLAN-0026: Refactorización y Desacoplamiento de Redundancias Transversales e Integración Canónica ISO vs. Toolkit

**Fecha:** 2026-09-05  
**Estado:** COMPLETADO  
**Rama:** `feature/offline-ui-tweaks`  
**Autor:** Agente Antigravity / Pair-Programming  
**Plan Previo Directo:** [PLAN-0025](PLAN-0025-20260905-deep-audit-script-redundancy-and-iso-vs-toolkit-matrix.md)  
**Informe de Auditoría Base:** [AUDITORIA_REDUNDANCIA_SCRIPTS_Y_MATRIZ_ISO_VS_TOOLKIT.md](../auditorias/AUDITORIA_REDUNDANCIA_SCRIPTS_Y_MATRIZ_ISO_VS_TOOLKIT.md)  
**Regla de Ejecución:** Cumplimiento estricto de Regla 8 (espera de confirmación del usuario) y Regla 4 (UTF-8 con BOM, Windows PowerShell 5.1).  

---

## 1. Justificación y Alcance

Tras completar y aprobar la auditoría técnica transversal ([AUDITORIA_REDUNDANCIA_SCRIPTS_Y_MATRIZ_ISO_VS_TOOLKIT.md](../auditorias/AUDITORIA_REDUNDANCIA_SCRIPTS_Y_MATRIZ_ISO_VS_TOOLKIT.md)), se estableció la necesidad imperiosa de ejecutar una refactorización quirúrgica que resuelva las redundancias patológicas, divergencias e inconsistencias entre la ISO y el Toolkit, respetando el **Paradigma Dual de Arquitectura**:

1. **Escenario A (ISO Optimizada):** La instalación arranca con la suite de rendimiento completa, menús contextuales en cascada a 1 clic, políticas de navegadores activadas de forma desatendida, y la **carpeta `Core/` (Policy-Engine, Hardware-Engine, UI-Engine) completamente inyectada en la ISO** para que el Toolkit opere con el 100% de sus motores activos en el sistema instalado.
2. **Escenario B (Toolkit Standalone en Windows Genérico/Stock):** El usuario que no usó la ISO puede ejecutar el Toolkit y sus módulos auxiliares de manera autónoma con todas las opciones disponibles.


---

## 2. Objetivos Principales

1. **Sincronización Canónica del Menú Contextual:**
   - Eliminar las 6 claves de registro planas y obsoletas en la plantilla de `SetupComplete.cmd` dentro de `New-OptimizedWindowsISO-v2.ps1` (L3956-3985), las cuales quedan ocultas en Windows 11 24H2 bajo *Shift+F10*.
   - Reemplazarlas por la invocación canónica a `Add-OptimizedContextMenus.ps1 -Apply -EnableClassicMenu` durante el proceso de instalación (`SetupComplete.cmd` o primer logon), garantizando que la ISO tenga exactamente la misma suite de menús en cascada y menú clásico que el Toolkit.
2. **Centralización del Catálogo GPO de Navegadores Web (SSOT):**
   - Incorporar en `scripts/Core/Policy-Engine.ps1` el catálogo oficial `$global:RomanOS_BrowserPolicies` (Edge, Chrome, Firefox, Brave) con sus 60+ directivas respaldadas en Microsoft Learn y Chrome Enterprise.
   - Proveer funciones de exportación `Export-RomanOSBrowserCommands` y aplicación en vivo.
   - Eliminar las cadenas de texto hardcodeadas duplicadas entre `SetupComplete.cmd` y `Win11-Debloat-v3-Adaptive.ps1` (Sección 16).
3. **Desacoplamiento de Acciones Rápidas en `romanOS-Toolkit.ps1`:**
   - Refactorizar las `QuickActions` de mantenimiento (Shaders GPU y SSD TRIM) para que deleguen en `Invoke-WindowsMaintenance.ps1` con parámetros específicos (`-ShadersOnly`, `-TrimOnly`), eliminando el código inline repetido con `Get-ChildItem`.
   - Refactorizar la acción rápida de vaciado de DNS / red para delegar en `Win11-Network-Diagnostics-Optimizer.ps1`.
4. **Desacoplamiento de Red en `Win11-Debloat-v3-Adaptive.ps1`:**
   - Reemplazar la búsqueda duplicada de interfaces de red para Nagle en las Secciones 11/12 por una delegación limpia a `Win11-Network-Diagnostics-Optimizer.ps1`.
5. **Garantía de Idempotencia y Respeto al Runtime de Destino:**
   - Asegurar que todo script guarde formato estricto UTF-8 con BOM y sea validado en Windows PowerShell 5.1 (`powershell.exe`).

---

## 3. Fases de Ejecución

### Fase 1: Centralización de Navegadores en `Policy-Engine.ps1`
- Agregar `$global:RomanOS_BrowserPolicies` y función `Export-RomanOSBrowserCommands` a `scripts/Core/Policy-Engine.ps1`.
- Validación sintáctica y de exportación en PowerShell 5.1.

### Fase 2: Sincronización Canónica en `New-OptimizedWindowsISO-v2.ps1`
- Retirar las 6 claves planas de `SetupComplete.cmd`.
- Inyectar la invocación desatendida a `Add-OptimizedContextMenus.ps1 -Apply -EnableClassicMenu`.
- Consumir el bloque de políticas de navegadores desde `Policy-Engine.ps1`.

### Fase 3: Refactorización Modular de `romanOS-Toolkit.ps1`
- Actualizar `Invoke-WindowsMaintenance.ps1` con switches dedicados `-ShadersOnly` y `-TrimOnly` si no existieran.
- Conectar `QuickActions` a los scripts modulares correspondientes.

### Fase 4: Desacoplamiento de `Win11-Debloat-v3-Adaptive.ps1`
- Adaptar la Sección 16 (Navegadores) para consumir `Policy-Engine.ps1`.
- Conectar el tuning de adaptadores Nagle a `Win11-Network-Diagnostics-Optimizer.ps1`.

### Fase 5: Validación Rigurosa y Pruebas de Regresión
- Verificación UTF-8 con BOM en todos los scripts modificados.
- Prueba AST en Windows PowerShell 5.1 (`powershell.exe -STA -NoProfile ... -WhatIf`).
- Ejecución de `Test-OptimizedISO-v2.ps1` y actualización de asserts si corresponde.

---

## 4. Criterios de Éxito
- Cero claves duplicadas u obsoletas entre la ISO y el Toolkit.
- Menús contextuales 100% idénticos y modernos tanto si se instala la ISO como si se ejecuta el Toolkit en Windows genérico.
- Navegadores centralizados en una sola fuente de verdad (`Policy-Engine.ps1`).
- Tests unitarios y suite pasando con 0 errores en PowerShell 5.1.
