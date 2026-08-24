# Cheatsheet: Comandos y Convenciones de Git

## 1. Inspección Inicial (Paso Cero Obligatorio)

```powershell
# 1. Estado de archivos modificados y untracked
git status

# 2. Historial reciente
git log -n 5 --oneline

# 3. Inspección de cambios activos
git diff
```

---

## 2. Diagnóstico de Regresiones y Diffs

```powershell
# Comparar un archivo contra el último commit funcional
git diff HEAD -- scripts/New-OptimizedWindowsISO-v2.ps1

# Comparar con un commit específico
git diff <commit_hash>..HEAD
```

---

## 3. Rollback Seguro ante Fallos

```powershell
# Descartar cambios en un archivo específico
git restore scripts/New-OptimizedWindowsISO-v2.ps1

# Descartar todos los cambios no guardados
git restore .

# Limpiar archivos no rastreados
git clean -fd
```

---

## 4. Commits Atómicos y Convencionales

Estructura: `<tipo>(<alcance>): <descripción corta>`

- `feat(updates)`: Nuevas características o módulos.
- `fix(debloat)`: Correcciones de errores o bugs.
- `docs(plans)`: Documentación, manuales o planes.
- `refactor(core)`: Refactorización sin alterar el comportamiento externo.
