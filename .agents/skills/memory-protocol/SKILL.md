---
name: memory-protocol
description: >-
  Activate this skill when recording project milestones, updating MEMORY.md,
  rotating logs, or ensuring cross-session state continuity for AI pair-programming.
---

# Protocolo Maestro de Memoria Jerárquica y Gestión de Contexto Masivo (Regla 15)

Estándar constitucional para mantener la continuidad cognitiva, evitar la saturación de contexto (*lost in the middle*) y asegurar que auditorías extensas (como los 54 scripts del repositorio) se ejecuten con rigor matemático sin alucinaciones.

---

## 1. Los 6 Pilares Obligatorios para Tareas Masivas

```
┌────────────────────────────────────────────────────────────────────────┐
│                   ARQUITECTURA DE MEMORIA JERÁRQUICA                   │
└────────────────────────────────────────────────────────────────────────┘
     │
     ├── 1. Servidor MCP memory (Grafo de Conocimiento Estructurado en Disco)
     ├── 2. Conciencia de Context Compaction (Resumen de Travesía Rollup)
     ├── 3. Docs-as-Code (Planes Formales PLAN-NNNN.md en Git como SSOT)
     ├── 4. Patrón Map-Reduce por Lotes (Chunking: 3 a 5 scripts por turno)
     ├── 5. Delegación a Subagentes Especializados (Aislamiento de Contexto)
     └── 6. Artefactos Vivos y Modo Autónomo Extendido (/goal + Watchdogs)
```

### Pilar 1: Grafo de Conocimiento Estructurado (MCP `memory`)
* **Ubicación:** `C:\Users\Thiago\.gemini\antigravity-ide\mcp\memory`
* **Acción:**
  * Al auditar o modificar componentes, registrar entidades con `create_entities` u observaciones con `add_observations`.
  * Ejemplo de entidad técnica:
    ```json
    {
      "name": "Script_HardwareEngine",
      "entityType": "RepositoryScript",
      "observations": [
        "Unificado LargeSystemCache = 0 en Get-RomanOSMemoryTier.",
        "Implementada Get-RomanOSSchedulerRecommendation para proteger Intel Thread Director y AMD CPPC."
      ]
    }
    ```

### Pilar 2: Conciencia de Compaction y Rollup Progresivo
* Diseñar cada turno sabiendo que el historial largo será resumido por el motor de Antigravity.
* Al concluir cada turno, incluir un bloque estructurado con:
  - **Hito alcanzado:** Qué scripts se completaron con su métrica.
  - **Próximo lote:** Qué 3-5 scripts se procesarán en el siguiente paso.
  - **Invariantes:** Recordar salvaguardas (Regla 14 de hardware, UTF-8 BOM, etc.).

### Pilar 3: Persistencia en Archivos Git (*Docs-as-Code*)
* Antes de iniciar una auditoría repo-wide, crear un plan en `docs/plans/PLAN-NNNN.md`.
* Mantener la matriz de estado: `[ ]` PENDIENTE, `[-]` EN PROGRESO, `[x]` COMPLETADO.
* Registrar en `MEMORY.md` cada hito completado con timestamp ISO 8601 y hash de commit.

### Pilar 4: Patrón Map-Reduce por Lotes (Chunking Metodológico de 3 a 5 Scripts)
* **ESTRICTAMENTE PROHIBIDO** intentar auditar o modificar más de 5 scripts en un solo turno.
* **Ciclo Map-Reduce:**
  1. **Map (Selección):** Extraer del plan los siguientes 3 a 5 scripts del lote.
  2. **Investigación Activa:** Consultar fuentes de vanguardia (`search_web`, Microsoft Learn, AtlasOS v0.5, Sophia Script).
  3. **Ficha Forense:** Analizar reliquias, mitos y dependencias de cada script.
  4. **Refactorización y Prueba:** Modificar código con UTF-8 BOM y validar en frío contra `powershell.exe -STA`.
  5. **Reduce (Consolidación):** Actualizar el plan, guardar métricas en el artefacto vivo y persistir observaciones en MCP `memory`.

### Pilar 5: Delegación a Subagentes Especializados
* Para tareas intensivas de lectura (ej. logs de 10,000 líneas o árboles masivos de registro), invocar subagentes dedicados (`log-forensics`, `registry-forensics`).
* El subagente procesa los datos pesados en su propio contexto aislado y devuelve al hilo maestro una síntesis de menos de 20 líneas.

### Pilar 6: Artefactos Vivos y Modo Autónomo Extendido
* Crear y actualizar un artefacto vivo (`auditoria_forense_scripts.md`) en la carpeta de artefactos de Antigravity para que el usuario pueda inspeccionar la evolución en tiempo real.
* Ejecutar en modo continuo (Regla 8 / comando `/goal`) sin detenerse por confirmaciones innecesarias, con Watchdog Timers activos (Regla 7).

---

## 2. Reglas Canónicas de Bitácora (MEMORY.md)

1. **Cronología Inversa:** El bloque más nuevo siempre va al inicio de `MEMORY.md` (debajo del título).
2. **Timestamp y Formato ISO 8601:** `## [YYYY-MM-DDTHH:mm:ss-03:00] Título del Hito`.
3. **Estructura por Bloque:**
   - **Archivos Creados / Modificados:** Lista exacta de rutas.
   - **Commits:** Hash y mensaje si aplica.
   - **Hitos Logrados:** Viñetas técnicas de lo implementado y validado.
4. **Registro antes de Terminar:** Ninguna sesión debe finalizar sin actualizar `MEMORY.md`.

