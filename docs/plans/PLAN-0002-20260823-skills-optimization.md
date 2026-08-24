# Plan PLAN-0002: Optimización Integral de Skills y Agentes del Proyecto

| Campo | Valor |
|---|---|
| **ID** | PLAN-0002 |
| **Fecha** | 2026-08-23 |
| **Estado** | COMPLETADO |
| **Autor** | Antigravity (agente IA) |
| **Conversación origen** | babd15fe-6a78-448b-a692-93d33d4d76a0 |

---

## 1. Contexto y Objetivos

Actualmente el proyecto cuenta con 7 skills en `.agents/skills/`. Si bien contienen información técnica válida, su estructura no aprovecha plenamente los estándares oficiales de **Antigravity Customizations**:
- Los frontmatters (`description`) no contienen frases de activación explícitas (*trigger conditions*).
- No cuentan con subdirectorios de scripts ejecutables (`scripts/`) para que el agente valide en un solo paso.
- La documentación densa no está separada mediante divulgación progresiva (`references/`).

**Objetivo:** Transformar las 7 skills en paquetes modulares, precisos y de alto rendimiento que reduzcan drásticamente el consumo de tokens y maximicen la precisión del agente.

---

## 2. Decisiones de Arquitectura y Estándares Oficiales

Conforme a las especificaciones oficiales de `agy-customizations`:
1. **Frontmatter con Triggers de Tercera Persona:** Cada `description` indicará qué hace la skill y bajo qué solicitudes del usuario debe activarse.
2. **Helpers Ejecutables (`scripts/`):** Automatizar validaciones frecuentes en scripts `.ps1` reutilizables (verificador AST + UTF-8 BOM, chequeo de higiene Git, validación XML).
3. **Divulgación Progresiva (`references/`):** El `SKILL.md` principal contendrá hojas de ruta concisas (<80 líneas), mientras que tablas y matrices técnicas extensas se alojarán en archivos `.md` complementarios dentro de `references/`.
4. **Verificación Empírica:** Integrar comandos concretos de validación con salida booleana/estructurada.

---

## 3. Matriz de Cambios por Skill

### 1. `powershell-windows`
- **Frontmatter:** Trigger para scripting de Windows, manipulación de registro, DISM, debloat y validación en PS 5.1.
- **Helper `scripts/Test-ScriptAstAndBom.ps1`:** Valida automáticamente que cualquier script `.ps1` tenga 0 errores AST en PS 5.1 y codificación `UTF-8 con BOM`.
- **Referencia `references/registry-dism-matrix.md`:** Guía rápida de claves de registro para telemetría, gaming y comandos DISM servicing.

### 2. `windows-adk-hyperv`
- **Frontmatter:** Trigger para compilación con `oscdimg`, montaje/desmontaje WIM con DISM y aprovisionamiento de VMs en Hyper-V.
- **Helper `scripts/Test-AdkEnvironment.ps1`:** Chequea la presencia de ADK (`oscdimg.exe`), estado del servicio Hyper-V y espacio en disco.
- **Referencia `references/oscdimg-hyperv-reference.md`:** Flags El Torito dual boot UEFI/BIOS y comandos PowerShell para Hyper-V Gen2 con TPM.

### 3. `git-workflow`
- **Frontmatter:** Trigger para operaciones Git, inspección inicial paso cero, resolución de conflictos y commits atómicos.
- **Helper `scripts/Test-GitWorkspaceHygiene.ps1`:** Valida que no existan binarios pesados rastreados o en staging (`.iso`, `.wim`, `.exe`, `.msu`).
- **Referencia `references/git-commands-cheatsheet.md`:** Comandos rápidos para diffs, rollbacks y commits convencionales.

### 4. `code-review`
- **Frontmatter:** Trigger para auditoría previa a entrega de código, checklist de calidad y seguridad.
- **Checklist Refinado:** Integración de verificación de codificación UTF-8 BOM, pruebas en frío en PS 5.1 y validación de auto-elevación `-STA`.

### 5. `debug-strategy`
- **Frontmatter:** Trigger para diagnóstico de errores, excepciones de DISM/PowerShell y bugs de compilación.
- **Protocolo Refinado:** Matriz de códigos de salida comunes de DISM (0x800f081f, 3010, etc.) y técnicas de aislamiento.

### 6. `project-audit`
- **Frontmatter:** Trigger para auditoría integral de la estructura de la ISO, `$OEM$` y `autounattend.xml`.
- **Referencia `references/autounattend-schema.md`:** Esquema XML de referencia para particionado UEFI/GPT y bypasses oficiales de Windows 11.

### 7. `memory-protocol`
- **Frontmatter:** Trigger para actualización de `MEMORY.md` y bitácoras de proyecto.
- **Estandarización:** Plantilla fija y reglas de rotación.

---

## 4. Plan de Verificación

1. **Validación Sintáctica:** Probar que todos los scripts auxiliares `.ps1` en las carpetas `scripts/` de las skills pasen el analizador AST de PowerShell 5.1 con 0 errores y codificación UTF-8 BOM.
2. **Validación de Enlaces Relativos:** Confirmar que todos los archivos referenciados en `references/` y `scripts/` existan en disco.
3. **Commit Atómico:** Registrar los cambios en Git y actualizar `MEMORY.md` y `docs/plans/README.md`.
