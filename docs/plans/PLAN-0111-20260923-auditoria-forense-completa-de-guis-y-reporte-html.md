# PLAN-0111: Auditoría Forense Exhaustiva de GUIs (romanOS Control Center y romanOS Studio) y Generación de Reporte HTML

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0111 |
| **Fecha** | 2026-09-23 |
| **Componentes** | `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/GUI/romanOS-Studio.ps1`, `scripts/Testing/Test-GuiIntegrityAndFunctionality.ps1`, `Auditoria-GUIs-romanOS.html`, `docs/plans/README.md` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Alta (Verificación Empírica de Interfaces Gráficas, Detección de Botones Muertos y Certificación de Backend) |
| **Reglas Relevantes** | Regla 0 (Git), Regla 4 (Windows PowerShell 5.1 / UTF-8 BOM), Regla 5 (Planes), Regla 6 (Cero Binarios en Git), Regla 7 (Aviso de Pruebas), Regla 8 (No Auto-Run), Regla 11 (Ingeniero Autónomo), Regla 12 (Análisis Forense Anti-Sesgo), Regla 13 (Auditoría Holística), Web Application Development (Rich Aesthetics) |

---

## 1. Contexto y Objetivos

El usuario ha ordenado realizar una auditoría forense rigurosa y sin concesiones sobre las dos interfaces gráficas de usuario (WPF) del ecosistema romanOS:
1. **romanOS Control Center** (`scripts/GUI/romanOS-ControlCenter.ps1` — 70 botones)
2. **romanOS Studio** (`scripts/GUI/romanOS-Studio.ps1` — 10 botones)

### Exigencias Técnicas Clave:
* **Detección de Botones Muertos:** Analizar si algún control en el XAML carece de manejador de eventos `Add_Click` o si su bloque de código está vacío/inoperativo.
* **Comprobación de Veracidad de Backend:** Auditar si cada botón realmente hace lo que declara su interfaz (resolución física de scripts invocados, coincidencia de parámetros en `param(...)`, comandos externos de sistema).
* **Clasificación de Viabilidad y Seguridad de Ejecución:** Para cada función que no pueda ser disparada de manera desatendida en una prueba en frío (acciones destructivas, reinicio de shell/kernel, despliegue de VM en vivo o interacción modal humana como `Out-GridView` / `MessageBox`), especificar con precisión técnica el motivo de la exención.
* **Prueba Empírica en Frío:** Ejecutar pruebas de las acciones seguras de auditoría y simulación para certificar su respuesta en tiempo real.
* **Puntos Funcionales y Acciones de Mejora:** Documentar las capacidades operativas verificadas y proponer optimizaciones de arquitectura y UX.
* **Reporte HTML Ejecutivo:** Generar `Auditoria-GUIs-romanOS.html` con diseño Dark Mode de alta fidelidad, tablas interactivas y métricas cuantitativas completas.

---

## 2. Plan de Implementación por Fases

### Fase 1: Creación del Script de Auditoría Forense (`Test-GuiIntegrityAndFunctionality.ps1`)
* Crear `scripts/Testing/Test-GuiIntegrityAndFunctionality.ps1` (UTF-8 con BOM, compatible con Windows PowerShell 5.1).
* Utilizar el parser AST nativo de PowerShell (`[System.Management.Automation.Language.Parser]`) para inspeccionar la totalidad del código y los bloques de evento.
* Validar:
  1. XAML Button Names vs AST `Add_Click` Handlers.
  2. Scripts destino invocados (`Resolve-ToolScript`, rutas relativas) y su existencia en disco.
  3. Ejecución de comandos del sistema (`ipconfig`, `DISM`, `explorer`).
  4. Categorización de riesgo (Auditoría Segura, Simulable con WhatIf, Exento por Modal, Exento por Riesgo de Kernel/Destructivo).

### Fase 2: Ejecución de Pruebas Empíricas en Frío
* Disparar en frío las funciones de lectura/auditoría backend asociadas a los botones seguros para verificar que retornen sin excepciones:
  - `Audit-SystemOptimization.ps1` (Auditoría Universal)
  - `Trace-SystemLatency.ps1` (Latencia DPC)
  - `Test-StorageStackBypassIO.ps1` (Storage)
  - `Audit-DriverStore.ps1` (DriverStore WhatIf)
  - `Win11-Debloat-v3-Adaptive.ps1 -AuditOnly` (Debloat Auditoría)

### Fase 3: Maquetación y Generación del Dashboard HTML (`Auditoria-GUIs-romanOS.html`)
* Dashboard autónomo con estética Dark Mode (`slate-950`):
  - KPIs: Total de botones, botones conectados, botones muertos (0), scripts resueltos (100%), acciones seguras probadas.
  - Pestañas interactivas: romanOS Control Center (70 botones) y romanOS Studio (10 botones).
  - Tabla forense exhaustiva con columnas: `#`, `Control XAML`, `Etiqueta UI`, `Handler AST`, `Destino Backend`, `Existencia`, `Clasificación / Motivo Exención`, `Veredicto`.
  - Sección detallada de **Puntos Funcionales Validados**.
  - Sección detallada de **Acciones de Mejora Arquitectónica y UX**.

### Fase 4: Validación y Commit Atómico
* Validar el script de auditoría con `Test-CodeQuality.ps1`.
* Ejecutar la prueba y certificar la creación de `Auditoria-GUIs-romanOS.html`.
* Registrar commit atómico de Git.
