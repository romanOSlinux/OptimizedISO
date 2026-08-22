---
name: git-workflow
description: "Protocolo obligatorio de control de versiones con Git: inspección inicial como paso cero, trazabilidad de cambios, aislamiento de regresiones, commits atómicos y rollback seguro."
---

# Flujo de Trabajo y Control de Versiones con Git

Este protocolo define el uso obligatorio de Git como fuente de verdad técnica principal y herramienta de trazabilidad en el repositorio.

---

## 1. Paso Cero: Inspección Previa Obligatoria

Antes de proponer soluciones o modificar archivos, el agente **siempre** debe inspeccionar el estado actual de Git:

```powershell
# 1. Verificar estado del árbol de trabajo y archivos no rastreados
git status

# 2. Conocer los últimos commits y el punto base funcional
git log -n 5 --oneline

# 3. Inspeccionar diffs de trabajo antes de editar
git diff
```

---

## 2. Detección y Diagnóstico de Regresiones

Si una prueba falla (en Hyper-V, DISM, oscdimg o Setup), **no adivinar ni reconstruir desde cero**:

```powershell
# Ver cambios exactos contra el último commit funcional
git diff HEAD

# Ver cambios específicos en un archivo
git diff HEAD -- scripts/New-OptimizedWindowsISO-v2.ps1

# Comparar con un commit anterior específico
git diff <commit_hash>..HEAD
```

---

## 3. Rollback Seguro ante Fallos Irrecuperables

Si un experimento o cambio masivo introduce errores y se desea volver al último estado funcional:

```powershell
# Descartar cambios en un archivo específico
git restore scripts/New-OptimizedWindowsISO-v2.ps1

# Descartar todos los cambios no guardados en el árbol de trabajo
git restore .

# Limpiar archivos nuevos no rastreados temporales
git clean -fd
```

---

## 4. Commits Atómicos tras Validación

Cada hito o corrección comprobada empíricamente debe registrarse en Git:

```powershell
# Añadir cambios validados
git add scripts/New-OptimizedWindowsISO-v2.ps1 scripts/Win11-Debloat-v3-Adaptive.ps1 MEMORY.md

# Crear commit con mensaje descriptivo y convencional
git commit -m "fix(ui): revertir menus contextuales y restaurar interfaz estandar"
```
