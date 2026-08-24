---
name: debug-strategy
description: >-
  Activate this skill when diagnosing script errors, PowerShell runtime exceptions,
  DISM failure exit codes, test harness failures, or unexpected build issues,
  to follow a systematic reproduce-isolate-fix-verify cycle.
---

# Metodología de Debugging Sistemático

Protocolo para aislar y resolver fallos rápidamente sin caer en bucles de prueba y error.

## Protocolo de 5 Pasos

1. **Lectura Completa del Error:** Identificar el número de línea exacto, el mensaje de excepción y el código de salida (ej. DISM `0x800f081f`, `3010`, `ParserError`).
2. **Reproducción Aislada:** Replicar el error con un comando mínimo en frío directamente contra el ejecutable de destino (`powershell.exe`).
3. **Aislamiento de Causa Raíz:** Usar `git diff` contra el último commit funcional para identificar el cambio que introdujo la regresión.
4. **Corrección Focalizada:** Aplicar **un solo cambio fundamentado** a la vez.
5. **Verificación Empírica:** Ejecutar la prueba nuevamente y confirmar 0 errores antes de dar la tarea por concluida.

---

## Códigos de Retorno Frecuentes en DISM

| Código | Significado | Solución Técnica |
| :--- | :--- | :--- |
| `0` | Éxito | Continuar proceso. |
| `3010` | Éxito con reinicio requerido | Tratar como éxito (`Success = True`). |
| `0x800f081f` | Archivos de origen no encontrados | Verificar ruta de imagen o paquete MSU/CAB. |
| `0x80070005` | Acceso denegado | Verificar elevación de Administrador. |
| `0x80070020` | Proceso bloqueado por otro handle | Forzar garbage collection y liberar colmenas con `reg.exe unload`. |
