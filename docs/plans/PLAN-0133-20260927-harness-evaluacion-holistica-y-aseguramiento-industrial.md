# PLAN-0133: Harness Industrial de Evaluación Holística y Aseguramiento E2E del Ecosistema romanOS

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0133 |
| **Fecha** | 2026-09-27 |
| **Componentes** | `scripts/Testing/Invoke-RomanOSHarness.ps1`, `scripts/Testing/Invoke-RomanOSHarness.cmd`, `CONSTRAINTS.md`, `.agents/AGENTS.md`, `scripts/Core/Policy-Engine.ps1`, `autounattend.xml`, `.agents/references/` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Crítica (Aseguramiento determinista repo-wide del 100% de la base de código) |
| **Reglas Relevantes** | Regla 0 (Git), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM en PS1 / No-BOM en CMD / PS 5.1), Regla 7 (Watchdogs), Regla 8 (Ejecución Continua), Regla 9 (SSOT), Regla 13 (CWE-390 / Fail-Visible), Regla 14 (Multi-Hardware), Regla 16 (Certeza Empírica), Regla 17 (Gobernanza Industrial) |

---

## 1. Visión y Fundamento Técnico

Sustituir comprobaciones superficiales de archivos individuales por un **Harness de Evaluación y Aseguramiento Industrial (Repo-Wide Evaluation & Assurance Harness)** estructurado en 5 Tiers deterministas, basado en los estándares de evaluación de software de frontera (SWE-bench, Anthropic Evals y CIS-CAT):

1. **Tier 1 (Estático & AST):** Análisis sintáctico del 100% de scripts PowerShell en Windows PowerShell 5.1, codificación física UTF-8 con BOM en `.ps1` y No-BOM en `.cmd`, y erradicación de bloques `catch` vacíos (CWE-390).
2. **Tier 2 (SSOT & Esquemas):** Integridad del catálogo maestro de más de 100 políticas de `Policy-Engine.ps1` y validación de nodos, pases y bypasses de `autounattend.xml`.
3. **Tier 3 (Matriz Multi-Hardware en Memoria):** Invariantes de hardware simuladas (UMA/APU `LargeSystemCache = 0`, planificador dinámico Intel P/E y AMD X3D, almacenamiento por volumen).
4. **Tier 4 (Seguridad, Cadena de Suministro y Anti-Cheat):** Compatibilidad con 5 motores Anti-Cheat (Ring-0), firmas Authenticode SHA-256 de binarios externos y lista de bloqueo de drivers vulnerables.
5. **Tier 5 (Inspección Offline de Artefactos y Telemetría):** Integridad de la ISO base oficial, paridad de scripts `$OEM$`, diagnóstico de privilegios UAC y exportación de telemetría estructurada en JSON.

---

## 2. Fases de Implementación

- [x] **Fase 1: Autoría del Harness de Evaluación (`Invoke-RomanOSHarness.ps1` y `.cmd`):**
  - Implementación en Windows PowerShell 5.1 con codificación obligatoria UTF-8 con BOM.
  - Implementación del lanzador batch `Invoke-RomanOSHarness.cmd` sin BOM y con flag `-STA`.
- [x] **Fase 2: Incorporación de Regla 17 y CONSTRAINTS.md:**
  - Formalización de Regla 17 en `.agents/AGENTS.md` (Anti-Racionalización, D3, Beyoncé TDD, Stop-the-Line, Cerca de Chesterton).
  - Redacción formal de `CONSTRAINTS.md` en la raíz como contrato inmutable de calidad.
  - Creación de `.agents/references/` para desacoplamiento de contexto.
- [x] **Fase 3: Erradicación de Fallos Silenciosos (CWE-390):**
  - Corrección de 15 bloques `catch` vacíos en 9 scripts del repositorio detectados por el arnés.
- [x] **Fase 4: Ejecución en Frío y Certificación de los 5 Tiers al 100%:**
  - Ejecutar el arnés contra la totalidad del repositorio en `powershell.exe` nativo (13/13 PASS, 100% compliance, ExitCode = 0).
  - Exportado `RomanOS-Harness-Report.json`.
- [x] **Fase 5: Registro en el Índice y Trazabilidad Git:**
  - Actualizado `docs/plans/README.md`.
  - Registrar commit atómico de implementación.
