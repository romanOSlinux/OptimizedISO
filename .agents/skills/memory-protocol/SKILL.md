---
name: memory-protocol
description: >-
  Activate this skill when recording project milestones, updating MEMORY.md,
  rotating logs, or ensuring cross-session state continuity for AI pair-programming.
---

# Protocolo de Memoria Activa (MEMORY.md)

Estándar para mantener la bitácora técnica y la continuidad de decisiones del proyecto.

## Reglas de Registro Obligatorias

1. **Cronología Inversa:** El bloque más nuevo siempre va al inicio de `MEMORY.md` (debajo del título).
2. **Timestamp y Formato ISO 8601:** `## [YYYY-MM-DDTHH:mm:ss-03:00] Título del Hito`.
3. **Estructura por Bloque:**
   - **Archivos Creados / Modificados:** Lista exacta de rutas.
   - **Commits:** Hash y mensaje si aplica.
   - **Hitos Logrados:** Viñetas técnicas de lo implementado y validado.
4. **Registro antes de Terminar:** Ninguna sesión debe finalizar sin actualizar `MEMORY.md`.

---

## Cuándo Consultar MEMORY.md

- **Paso Inicial Obligatorio:** Al comenzar una nueva conversación, leer el bloque superior de `MEMORY.md` para situar el contexto sin rehacer trabajo previo.
