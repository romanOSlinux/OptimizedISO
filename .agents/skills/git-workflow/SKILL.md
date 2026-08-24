---
name: git-workflow
description: >-
  Activate this skill when inspecting Git repository status, reviewing diffs,
  isolating regressions, performing safe rollbacks, staging atomic commits,
  or ensuring development workspace hygiene (zero heavy binaries).
---

# Flujo de Trabajo y Control de Versiones con Git

Protocolo de trazabilidad y gobernanza de código para el proyecto romanOS.

## Verificación Rápida de Higiene del Repositorio

Para auditar el working tree y asegurar que no haya binarios pesados rastreados:
```powershell
& ".agents/skills/git-workflow/scripts/Test-GitWorkspaceHygiene.ps1"
```

---

## Reglas Obligatorias de Trabajo

1. **Paso Cero Obligatorio:** Ejecutar siempre `git status` y `git log -n 5 --oneline` antes de editar archivos.
2. **Aislamiento de Regresiones:** Usar `git diff` antes de rehacer código desde cero.
3. **Commits Atómicos:** Registrar un commit descriptivo por cada hito verificado.
4. **Cero Binarios Pesados:** Prohibido hacer `git add` a `.iso`, `.wim`, `.esd`, `.msu`, `.cab` o `.exe`.

---

## Documentación y Referencias Técnicas

- [Cheatsheet de Comandos y Convenciones de Git](./references/git-commands-cheatsheet.md)
