---
name: debug-strategy
description: "Estrategia de debugging sistemático para evitar loops de trial-and-error. Leer error, reproducir, aislar, corregir, verificar. Un cambio a la vez."
---

# Debugging Sistemático

Skill para diagnosticar errores de forma eficiente sin desperdiciar tokens.

## Protocolo de 5 pasos

1. **Leer el error completo:** Identificar archivo, línea, tipo de error y código de retorno de DISM/PowerShell.
2. **Reproducir:** Ejecutar el comando exacto.
3. **Aislar la causa:** Separar problemas de permisos, paths, sintaxis o dependencias de Windows ADK.
4. **Corregir con precisión:** Aplicar un solo cambio fundamentado a la vez.
5. **Verificar:** Confirmar resolución antes de continuar.

## Anti-patrones
- ❌ No realizar cambios especulativos aleatorios.
- ❌ No silenciar errores con try/catch vacíos sin logging.
- ❌ Si un fallo persiste tras 2 intentos, pausar y consultar al usuario.
