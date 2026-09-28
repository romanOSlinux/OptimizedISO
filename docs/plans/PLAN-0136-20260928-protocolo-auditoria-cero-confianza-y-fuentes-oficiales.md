# PLAN-0136: Protocolo de Inquisición Cero-Confianza, Validación Epistemológica contra Fuentes Oficiales y Erradicación de la Falacia de Validación Circular

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0136 |
| **Fecha** | 2026-09-28 |
| **Componentes** | `.agents/AGENTS.md`, `.agents/GOVERNANCE-MATRIX.md`, `CONSTRAINTS.md`, `docs/plans/README.md`, MCP `memory` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Máxima / Crítica (Fundamentación Epistemológica del Sistema y Prevención de Mitos/Placebos) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 11 (Autonomía Técnica), Regla 14 (Agnosticismo de Hardware), Regla 17 (agent-skills / Anti-Racionalización), Regla 18 (Tool-Gating), Regla 19 (Protocolo Zero-Trust / Anti-Circular Fallacy) |

---

## 1. Visión y Justificación Técnica

### Problema Diagnosticado: La Falacia de Validación Circular
En proyectos de ingeniería de sistemas y optimización de Windows, es común caer en la **falacia de validación circular**:
1. Un script establece una clave de registro o ejecuta un comando heredado de optimizadores de internet (ej. Windows XP / Windows 7 / mitos de YouTube).
2. Se escribe una prueba unitaria o funcional que comprueba si la clave de registro fue escrita con éxito o si el script finaliza con `ExitCode 0`.
3. El arnés de evaluación reporta `PASS [100%]`.
4. **El fallo fatal:** El sistema celebra un éxito verde artificial (*lazy green*) validando un código cuyo objetivo técnico es un placebo, está basado en tecnologías deprecadas (ej. `wmic` en Windows 11 24H2), o es activamente dañino para hardware moderno (ej. romper el reparto de núcleos en Intel Thread Director / AMD CPPC o asfixiar la VRAM en APUs con `LargeSystemCache = 1`).

### Principio Rector: Zero-Trust Spec-First (Inquisición de Afirmaciones)
Todo script existente o propuesto es **culpable de ser placebo, obsoleto o defectuoso hasta que la especificación oficial del fabricante (Microsoft Learn, Intel, AMD, RFCs) demuestre lo contrario**. 

No se ejecutan pruebas sin antes haber sometido la intención, diseño y comandos del script al **Tribunal de Fuentes Oficiales**.

---

## 2. Fases de Implementación

- [x] **Fase 1: Codificación en `.agents/AGENTS.md` (Regla 19):**
  - Establecer la Regla 19: *Protocolo de Inquisición Cero-Confianza y Validación Epistemológica contra Fuentes Oficiales (Anti-Circular Validation Fallacy)*.
  - Definir el ciclo de 4 pasos: (1) Extracción de Afirmaciones $\rightarrow$ (2) Interrogatorio Oficial $\rightarrow$ (3) Clasificación Cuatridimensional [Placebo, Obsoleto, Peligroso, Válido] $\rightarrow$ (4) Telemetría Real en Hardware.
- [x] **Fase 2: Incorporación en `CONSTRAINTS.md` (Dimensión F):**
  - Incorporar la *Dimensión F: Validez Epistemológica, Cero Placebos y Respaldo Oficial Obligatorio (Anti-Placebo & Spec-First)*.
  - Establecer los umbrales no negociables de verificación contra fuentes oficiales antes de dar un script por aprobado.
- [x] **Fase 3: Sincronización en `.agents/GOVERNANCE-MATRIX.md`:**
  - Actualizar la FASE 1 (`DEFINE`), FASE 4 (`VERIFY`) y FASE 5 (`REVIEW`).
  - Añadir la cláusula anti-falacia circular en la Matriz Anti-Racionalización.
- [x] **Fase 4: Persistencia en Grafo de Conocimiento MCP `memory`:**
  - Registrar la entidad `ZeroTrustAuditProtocol` con sus observaciones y relaciones para garantizar que sobreviva inter-sesión.
- [x] **Fase 5: Validación Repo-Wide mediante `Invoke-RomanOSHarness.ps1`:**
  - Ejecutar compuerta L1 (`check:fast`) y verificar que toda la documentación mantenga paridad y codificación estricta.
- [x] **Fase 6: Registro en `docs/plans/README.md` y Commit Atómico:**
  - Actualizar el índice maestro de planes y commitear los cambios con trazabilidad Git (Regla 0).
