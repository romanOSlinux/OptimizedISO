# PLAN-0135: Formalización del Marco Maestro de Gobernanza Operativa Total (Agentic OS & Lifecycle Matrix)

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0135 |
| **Fecha** | 2026-09-28 |
| **Componentes** | `.agents/GOVERNANCE-MATRIX.md`, `.agents/AGENTS.md`, `CONSTRAINTS.md`, `docs/plans/README.md` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Crítica (Arquitectura de Control del Agente y Soberanía Operativa del Ecosistema) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (Codificación), Regla 5 (Planes), Regla 9 (SSOT), Regla 10 (Cascada), Regla 15 (Map-Reduce), Regla 16 (Determinismo), Regla 17 (Estándar agent-skills), Regla 18 (Tool-Gating) |

---

## 1. Visión y Justificación Técnica

### Problema Diagnosticado
Contar con herramientas portables (`tools/`), motores canónicos (`scripts/Core/`), 15 skills especializadas, servidores MCP (`memory`, `fetch`, `github`) y reglas estrictas no es suficiente si operan como silos desconectados. Sin un mapa de navegación determinista que rija cada interacción del agente con el entorno, los modelos de lenguaje tienden por gravedad pre-entrenada a improvisar scripts ad-hoc, desatender las habilidades y eludir los servidores MCP.

Inspirado en el estándar de ingeniería de software para agentes de **Addy Osmani (`agent-skills`)**, este plan formaliza la **Matriz Maestra de Gobernanza Operativa (`.agents/GOVERNANCE-MATRIX.md`)**, estableciendo el contrato operativo exacto que conecta:
1. **Las 6 Fases del Ciclo de Desarrollo:** `DEFINE` $\rightarrow$ `PLAN` $\rightarrow$ `BUILD` $\rightarrow$ `VERIFY` $\rightarrow$ `REVIEW` $\rightarrow$ `SHIP`.
2. **Servidores MCP:** Asignación específica de cuándo y cómo invocar `memory`, `fetch` y `github`.
3. **Catálogo de 15 Skills:** Activación automática y obligatoria por fase.
4. **Herramientas Locales Herméticas:** Uso compulsivo de `tools/` y `scripts/Core/` bajo la Regla 18.
5. **Niveles de Calidad de CONSTRAINTS.md:** Compuertas L1 (`check:fast`), L2 (`check:task`), L3 (`check:full`) y L4 (`check:deploy`).
6. **Reglas Vinculantes de AGENTS.md:** Aplicación transversal de las Reglas 0 a 18.

---

## 2. Fases de Implementación

- [x] **Fase 1: Registro Formal del Plan en Gobernanza:**
  - Registrar PLAN-0135 en `docs/plans/README.md`.
- [x] **Fase 2: Creación de `.agents/GOVERNANCE-MATRIX.md`:**
  - Redactar y formalizar la matriz exhaustiva de 6 fases con tablas de mapeo operacional, disparadores de skills, integración MCP y matriz anti-racionalización.
- [x] **Fase 3: Sincronización en Cascada en `.agents/AGENTS.md`:**
  - Incorporar referencia canónica en la cabecera y en la Regla 17 de `AGENTS.md` vinculando formalmente la matriz de gobernanza.
- [x] **Fase 4: Sincronización en `CONSTRAINTS.md`:**
  - Vincular la matriz como contrato de navegación operativa en la sección de gobernanza.
- [x] **Fase 5: Validación del Arnés de Regresión Repo-Wide:**
  - Ejecutar `Invoke-RomanOSHarness.ps1 -Fast` y arnés completo para certificar paridad 100%.
- [x] **Fase 6: Persistencia en Grafo MCP `memory` y Commit Atómico:**
  - Registrar el hito en el servidor de grafos y emitir commit atómico trazable.
