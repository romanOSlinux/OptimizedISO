---
name: memory-protocol
description: "Protocolo detallado para gestionar el archivo MEMORY.md de bitácora de proyecto: formato, rotación, archivado, y reglas de escritura para agentes de IA."
---

# Protocolo de Memoria Activa (MEMORY.md)

Instrucciones detalladas para gestionar la bitácora `MEMORY.md` en el proyecto.

## Propósito

`MEMORY.md` es el mecanismo de continuidad entre sesiones de trabajo con agentes de IA. Permite que un agente nuevo entienda rápidamente qué se hizo, qué decisiones se tomaron, y qué quedó pendiente.

## Reglas de escritura

1. **Cronología inversa:** El bloque más nuevo siempre va arriba (después del header).
2. **Timestamp obligatorio:** Usar formato ISO 8601 con zona horaria del usuario (`-03:00`).
3. **Brevedad:** Máximo 5-8 viñetas por bloque.
4. **No duplicar:** Referenciar archivos en lugar de copiar código extenso.
5. **Registrar antes de terminar:** Nunca finalizar una sesión de trabajo sin agregar un bloque.

## Cuándo leer MEMORY.md

- **Siempre** al iniciar cualquier tarea en un proyecto.
- Es la primera acción antes de investigar código o hacer cambios.
