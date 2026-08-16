# Reglas Globales de Memoria Activa y Eficiencia de Tokens

1. **Inicialización Automática (`MEMORY.md`):** Siempre que inicies un trabajo en un proyecto y notes que no existe un archivo `MEMORY.md` en la raíz, debes crearlo automáticamente con un formato de bitácora cronológica inversa.
2. **Contexto Obligatorio:** Al iniciar cualquier tarea en cualquier proyecto, busca y lee el archivo `MEMORY.md` local de ese proyecto para entender la arquitectura y el historial aislado.
3. **Registro Automático de Hitos:** Nunca termines una sesión de trabajo sin agregar un bloque de resumen al principio de `MEMORY.md`. Este bloque debe tener un timestamp (fecha/hora) y resumir en viñetas rápidas qué archivos se modificaron, qué hitos se lograron y qué quedó pendiente.
4. **Aislamiento Estricto:** Mantén siempre la memoria dentro del archivo `MEMORY.md` del proyecto actual. No cruces información entre distintos proyectos.

# Reglas de Eficiencia de Tokens

Estas reglas aplican a **toda interacción** para optimizar el uso del tier gratuito de IA:

5. **Lectura mínima:** No leer archivos completos si solo necesitas unas líneas. Usar `head`, `tail`, `grep`, `sed -n` o rangos de líneas específicos.
6. **No repetir contenido:** Nunca reimprimir o resumir el contenido de un archivo que ya leíste en la misma sesión. Referenciarlo por nombre.
7. **Output acotado:** Si un comando produce >50 líneas de output, filtrar o paginar (`| head -30`, `| Select-Object -First 30`, `| grep <patrón>`). Limitar `git log` a `-n 5` o menos.
8. **Búsqueda eficiente:** Preferir `grep -rn` y `find` sobre exploración manual de directorios. No listar directorios recursivamente si puedes buscar directamente.
9. **No reescribir código funcional:** No regenerar ni refactorizar código que ya funciona solo para "mejorar estilo" a menos que el usuario lo pida explícitamente.
10. **Respuestas directas:** Si el usuario hace una pregunta simple, responder directamente sin investigación previa innecesaria. No abrir archivos ni ejecutar comandos si ya tienes la respuesta.
11. **Un intento informado:** Antes de hacer cambios, entender el contexto. Evitar loops de prueba-error. Si algo falla 2 veces, pausar y consultar al usuario en lugar de seguir iterando.
