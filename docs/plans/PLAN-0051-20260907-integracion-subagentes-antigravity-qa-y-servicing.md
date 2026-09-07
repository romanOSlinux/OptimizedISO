# PLAN-0051: Integración de Subagentes Especializados de Antigravity para Control de Calidad y Servicing

**Fecha:** 2026-09-07  
**Estado:** COMPLETADO  
**Objetivo:** Crear y estandarizar subagentes especializados dentro de `.agents/agents/` para delegar tareas críticas (auditoría estática AST/BOM, pruebas dinámicas en Hyper-V y servicing de parches Windows), aislando la ventana de contexto y previniendo regresiones semánticas y de código en el proyecto romanOS / OptimizedISO.

---

## 1. Justificación Técnica

Tras el análisis de las regresiones recientes y las limitaciones inherentes a los tests estáticos en tiempo de diseño:
1. **Agotamiento de Ventana de Contexto (Context Bleeding):** Las sesiones largas que involucran análisis de logs extensos de DISM, volcados de registro y comparaciones masivas de código saturan la memoria del agente principal, degradando la precisión de sus respuestas.
2. **Falsos Positivos en Tests Estáticos:** Los tests AST o comprobaciones de strings no pueden evaluar el comportamiento semántico del OOBE de Windows ni la interacción real con colmenas de registro montadas.
3. **Especialización y Paralelismo:** Google Antigravity soporta subagentes aislados definidos en `.agents/agents/*.md` con `inheritCustomizations: true`. Al desacoplar tareas a agentes con *system prompts* hiper-enfocados, se garantiza máxima fidelidad a las reglas y directivas del proyecto.

---

## 2. Alcance y Arquitectura de Subagentes a Implementar

### A. Subagente 1: `pre-commit-auditor` (`.agents/agents/pre-commit-auditor.md`)
- **Propósito:** Control de Calidad Estático y Guardián de Git.
- **Responsabilidades:**
  - Auditar `git status` y `git diff` contra `HEAD`.
  - Validar que cada script modificado posea cabecera UTF-8 con BOM (`0xEF, 0xBB, 0xBF`).
  - Validar compatibilidad y ausencia de excepciones AST en el runtime de Windows PowerShell 5.1 (`powershell.exe`).
  - Auditar que no existan variables huérfanas, rutas rotas ni binarios pesados en el stage de Git.
  - Generar veredicto estructurado (PASS / FAIL con línea y archivo exactos).

### B. Subagente 2: `vm-qa-runner` (`.agents/agents/vm-qa-runner.md`)
- **Propósito:** Aseguramiento de Calidad Dinámico en Entorno Virtualizado (Hyper-V).
- **Responsabilidades:**
  - Orquestar la validación funcional del ISO compilado en Hyper-V.
  - Verificar la transición desatendida del Setup, pasadas de `specialize`, `oobeSystem` y AutoLogon.
  - Supervisar la ejecución de `SetupComplete.cmd`, `FirstLogonCommands` y la integridad del arranque de `romanOS-Toolkit.ps1`.
  - Reportar tiempos de arranque, consumo de RAM en primer inicio y detección de errores de Windows Setup.

### C. Subagente 3: `servicing-researcher` (`.agents/agents/servicing-researcher.md`)
- **Propósito:** Inteligencia y Validación de Paquetes de Actualización y Controladores.
- **Responsabilidades:**
  - Investigar dependencias de parches Windows 11 (SSU, Checkpoint KB5043080, LCU acumulativo).
  - Extraer y validar metadatos de paquetes `.msu` y `.cab` en `scripts/Updates/`.
  - Auditar compatibilidad de firmas y arquitectura en `scripts/Drivers/`.

---

## 3. Plan de Acción Detallado

1. **Creación del Directorio Canónico:**
   - Inicializar `.agents/agents/`.
2. **Autoría de Subagentes:**
   - Crear `.agents/agents/pre-commit-auditor.md` con frontmatter YAML (`name`, `description`, `inheritCustomizations: true`) e instrucciones deterministas.
   - Crear `.agents/agents/vm-qa-runner.md` con directivas seguras para Hyper-V y verificación OOBE.
   - Crear `.agents/agents/servicing-researcher.md` con protocolo de verificación de parches y dependencias.
3. **Registro y Trazabilidad:**
   - Actualizar índice en `docs/plans/README.md`.
   - Documentar guía de invocación y buenas prácticas en `.agents/AGENTS.md` o documentación del equipo.

---

## 4. Plan de Verificación

1. **Verificación de Estructura y Markdown:**
   - Comprobar que los archivos se ubiquen en el root de descubrimiento estándar `.agents/agents/`.
   - Validar sintaxis YAML frontmatter de cada archivo.
2. **Validación de Cumplimiento de Reglas:**
   - Asegurar que no se añadan archivos pesados al repositorio.
   - Guardar todos los archivos en UTF-8 BOM si son scripts o UTF-8 estándar para Markdown.
