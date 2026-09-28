# PLAN-0134: Soberanía de Herramientas Locales, Regla 18 y Blindaje Mecánico Anti-Desvío del Agente

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0134 |
| **Fecha** | 2026-09-28 |
| **Componentes** | `.agents/AGENTS.md`, `CONSTRAINTS.md`, `scripts/Testing/Invoke-RomanOSHarness.ps1`, `scripts/Core/WimLib-Helper.ps1`, `scratch/Audit-GeneratedISO.ps1` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Crítica (Gobernanza de Comportamiento del Agente y Soberanía Tecnológica del Repositorio) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (Codificación y PS 5.1), Regla 9 (SSOT), Regla 10 (Cascada), Regla 16 (Determinismo), Regla 17 (Gobernanza Industrial), Regla 18 (Soberanía de Herramientas) |

---

## 1. Visión y Justificación Técnica

### Problema Diagnosticado
A pesar de contar con una suite completa de binarios portables herméticos (`tools/wimlib/`, `tools/sysinternals/`, `tools/everything/`), módulos canónicos de alto rendimiento (`scripts/Core/WimLib-Helper.ps1`, `Sysinternals-Helper.ps1`, `Policy-Engine.ps1`), 15 skills y servidores MCP (`memory`, `fetch`, `github`), el modelo tiende por inercia neuronal y sesgo de pre-entrenamiento a ignorar el ecosistema del proyecto y recurrir a soluciones genéricas y frágiles del host (ej. `C:\Program Files\7-Zip\7z.exe`, montajes pesados con DISM, o scripts ad-hoc improvisados).

Esta falta de soberanía tecnológica introduce:
1. **Pérdida de reproducibilidad y portabilidad:** Scripts que fallan en máquinas limpias o CI/CD al depender de software de terceros no versionado.
2. **Degradación del rendimiento del host:** Montajes DISM que saturan la memoria y dejan gigabytes en `%TEMP%` en lugar de utilizar motores Zero-Mount multihilo (`wimlib-imagex`).
3. **Pérdida de semántica:** Herramientas genéricas (7-Zip) que no parsean metadatos oficiales de Windows (Service Pack Build, flags de WIMBoot, integridad criptográfica).
4. **Desconexión arquitectónica:** Desaprovechamiento de la inversión en herramientas locales herméticas.

### Solución Arquitectónica
Implementar un cerrojo en 4 capas:
1. **Normativa Vinculante:** Incorporar la **Regla 18** en `.agents/AGENTS.md` con prohibición expresa de ejecutables del host (`Program Files`, `7z.exe`, DISM para lectura) y tabla de sustitución canónica innegociable.
2. **Paso Cero de Herramientas y Habilidades (Pre-Flight Tool Gate):** Obligación explícita de declarar la skill, el binario de `tools/` o helper de `scripts/Core/`, y el servidor MCP antes de generar o ejecutar código.
3. **Contrato Inmutable (`CONSTRAINTS.md`):** Agregar la **Dimensión E (Soberanía de Herramientas y Hermeticidad)** en el nivel L1 (`check:fast`).
4. **Guardia Mecánica en el Arnés (`Invoke-RomanOSHarness.ps1`):** Linter estático que audite `scripts/` y `scratch/` bloqueando con `ExitCode 1` cualquier llamada no autorizada a `7z.exe` o `Program Files` para utilidades cubiertas en `tools/`.

---

## 2. Fases de Implementación

- [x] **Fase 1: Registro Formal del Plan en Gobernanza:**
  - Registrar PLAN-0134 en `docs/plans/README.md`.
- [x] **Fase 2: Incorporación de la Regla 18 en `.agents/AGENTS.md`:**
  - Codificar la Regla 18 formalmente con tabla de mapeo canónico y protocolo Pre-Flight.
- [x] **Fase 3: Incorporación de la Dimensión E en `CONSTRAINTS.md`:**
  - Registrar la invariante de hermeticidad de herramientas en nivel L1.
- [x] **Fase 4: Actualización del Arnés de Evaluación (`scripts/Testing/Invoke-RomanOSHarness.ps1`):**
  - Implementar Tier 1.5 en L1: Detección estática de llamadas prohibidas a ejecutables externos no versionados y presencia de herramientas.
- [x] **Fase 5: Normalización Canónica de `scratch/Audit-GeneratedISO.ps1`:**
  - Refactorizar el script de auditoría para que consuma exclusivamente `WimLib-Helper.ps1` y `tools/wimlib/wimlib-imagex.exe`.
- [x] **Fase 6: Verificación y Certificación del Arnés:**
  - Ejecutar en frío con Windows PowerShell 5.1 (`powershell.exe`) validando `check:fast` (L1, 5/5 asserts) y arnés completo (L2, 14/14 asserts).
- [x] **Fase 7: Commit Atómico y Sincronización en Cascada.**
