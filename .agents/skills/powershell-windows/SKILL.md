---
name: powershell-windows
description: >-
  Activate this skill when writing, debugging, or reviewing PowerShell scripts for Windows,
  including registry manipulation, DISM servicing, AppX debloat, WinSxS cleanup, and
  enforcing UTF-8 BOM encoding and Windows PowerShell 5.1 compatibility.
---

# PowerShell para Windows (Estándar romanOS)

Guía de desarrollo y ejecución de scripts PowerShell nativos en Windows 10/11 y PowerShell 5.1.

## Reglas Obligatorias de Codificación y Runtime

1. **UTF-8 con BOM Obligatorio:** Todo script `.ps1`, `.psm1`, `.psd1` DEBE guardarse en formato `UTF-8 con BOM` (`0xEF, 0xBB, 0xBF`).
2. **Compatibilidad PS 5.1:** Probar siempre en frío contra `$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe`.
3. **STA en Lanzadores:** Todo `.cmd` con UI debe usar `-STA -NoProfile -ExecutionPolicy Bypass`.

---

## Verificación Rápida de AST y BOM

Para validar cualquier script sin improvisar comandos, ejecuta el helper de la skill:
```powershell
& ".agents/skills/powershell-windows/scripts/Test-ScriptAstAndBom.ps1" -FilePath "scripts/MiScript.ps1"
```

---

## Documentación y Referencias Técnicas

- [Matriz de Claves de Registro y Comandos DISM](./references/registry-dism-matrix.md)
