---
name: ecosystem-sync
description: Skill obligatorio para ejecutar la sincronización en cascada (SSOT) tras cambios arquitectónicos, previniendo la deuda de documentación y el desvío de configuración.
---

# 🌐 Sincronización en Cascada y Paridad del Ecosistema (Ecosystem Sync)

Activa este skill inmediatamente después de realizar cambios arquitectónicos, como renombrar scripts, cambiar rutas lógicas (ej. mover de `scripts/` a `scripts/Builder/`), o añadir nuevas directivas maestras al `Policy-Engine.ps1`.

El objetivo de este skill es garantizar el **Zero Configuration Drift** y mantener el **Single Source of Truth (SSOT)** en todo el repositorio (Docs-as-Code).

## Checklist Forense Obligatorio

1. **🕵️ Búsqueda de Dependencias Rotas (Ripple Effect)**
   - Identifica el nombre del script o la ruta antigua que fue modificada.
   - Ejecuta un escaneo global exhaustivo utilizando `grep_search` en todo el repositorio (incluyendo `.ps1`, `.cmd` y `.xml`) buscando la cadena de texto antigua.
   - Corrige *cada una* de las ocurrencias encontradas.

2. **⚖️ Paridad entre el Orquestador y el Auditor**
   - Si añadiste una nueva política de optimización en `scripts/Core/Policy-Engine.ps1`, recuerda que `scripts/Modules/PostInstall-Diagnostics.ps1` audita dinámicamente este motor. Sin embargo, revisa si hay código *hardcodeado* redundante en el auditor que deba ser eliminado o unificado.
   - Asegúrate de que el Creador de ISO (`New-OptimizedWindowsISO-v2.ps1`) inyecte correctamente el nuevo módulo si es que creaste uno.

3. **📝 Actualización Documental (Docs-as-Code)**
   - La documentación es código. Revisa `README.md`, `optimizediso`, y los manuales en la carpeta `docs/`.
   - Busca instrucciones de instalación, ejemplos de ejecución (`.\scripts\comando...`) y referencias a archivos.
   - Actualiza estas referencias para reflejar la realidad actual del proyecto. Si un usuario copia y pega un comando de la documentación, **DEBE** funcionar sin errores.

## 🛑 Regla de Oro
Ningún cambio arquitectónico se considera "Terminado" hasta que la documentación y las llamadas inter-script hayan sido actualizadas y commiteadas atómicamente.
