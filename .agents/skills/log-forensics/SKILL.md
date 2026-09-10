---
name: log-forensics
description: Subagente metodológico para la lectura y análisis de logs, evitando el sesgo de confirmación y garantizando un diagnóstico basado en parámetros.
---

# Metodología de Análisis Forense de Logs

Esta skill es de uso obligatorio al inspeccionar archivos .log, reportes de CI, o salidas de consola largas para resolver bugs, cambios de tamaño de imagen o regresiones.

## El Problema del "Sesgo de Confirmación"
Al leer logs largos, los agentes de IA tienden a aferrarse a la primera línea que parece explicar el problema (ej. "¡Ah, inyectó 2 GB de drivers, por eso la ISO es más grande!"), ignorando el contexto paramétrico y si esa inyección era el comportamiento estándar previo.

## Pasos Obligatorios para Analizar Logs

### 1. Extracción de Parámetros de Configuración
Antes de mirar los resultados (OK/WARN/ERROR), el agente DEBE localizar la cabecera o bloque de inicio donde se imprime con qué configuración se ejecutó el proceso.
- **¿Cuál es la versión base?**
- **¿Qué nivel de compresión se utilizó?** (/Compress:max vs /Compress:fast)
- **¿Qué checkboxes o variables de entorno estaban activas?**

### 2. Triangulación con el Estado Anterior
Nunca analices un log de regresión en el vacío. Si la ISO aumentó 500 MB hoy, el agente DEBE:
- Preguntarse: *¿Esto que estoy viendo (ej. inyección de drivers) se hacía ayer también?*
- Si la respuesta es sí, entonces **ese no es el problema**. Se debe seguir buscando.

### 3. Cerrojo Anti-Truncamiento (Filtro Físico Obligatorio)
Está terminantemente prohibido auditar reportes o salidas leyendo la consola de la herramienta, debido al riesgo de truncamiento de datos (`<truncated X lines>`).
El agente **DEBE OBLIGATORIAMENTE** usar la herramienta `grep_search` apuntando al archivo físico (`.log`, `.txt`) para buscar `WARN`, `ERROR` o `FAIL` (Ej. `grep_search 'FAIL' C:\OptimizedISO\Log\TestSuite_*.log`). Saltar este paso constituye una falta grave.

### 4. Prohibición de Diagnósticos Prematuros
El agente tiene terminantemente prohibido decirle al usuario "Encontré el problema" basándose en una corazonada visual. Debe construir una cadena de evidencia sólida cruzando el tamaño de archivos reales (ej. ejecutando un Measure-Object en disco) contra los parámetros descubiertos en el log.
