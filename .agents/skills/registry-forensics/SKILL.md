---
name: registry-forensics
description: >-
  Subagente enfocado en procesar masivamente volcados de registro (NTUSER.DAT)
  en background para detectar discrepancias contra Policy-Engine.ps1, ahorrando tokens.
---

# Registry-Forensics (Subagente)

Este skill define el comportamiento del subagente analizador de registros forenses.

## Objetivo
Analizar archivos `.DAT` (offline registry hives) y compararlos con las directivas canónicas definidas en `Policy-Engine.ps1` (SSOT), devolviendo únicamente un resumen de discrepancias al hilo principal.

## Cuándo invocar
Debe ser invocado explícitamente mediante el tool `run_command` en background o un script de delegación cuando el usuario requiera:
- "Verificar si la política UCPD se aplicó correctamente en la imagen".
- "Auditar el NTUSER.DAT contra el Policy-Engine".
- "Encontrar claves de registro huérfanas".

## Instrucciones para el Subagente
1. Monta el hive indicado usando `reg load HKLM\OfflineRegistry <Ruta>`.
2. Lee las directivas esperadas desde `scripts/Core/Policy-Engine.ps1`.
3. Compara en memoria (PowerShell) las claves existentes vs esperadas.
4. Desmonta el hive inmediatamente con `reg unload HKLM\OfflineRegistry`.
5. Devuelve al agente maestro un JSON estructurado con:
   - Claves faltantes.
   - Valores incorrectos.
   - Recomendaciones de remediación.

## Reglas de Cero Alucinación
- NUNCA realices cambios directamente en el registro (solo lectura).
- SIEMPRE asegúrate de desmontar el hive incluso si ocurre un error (usa `try/finally`).
