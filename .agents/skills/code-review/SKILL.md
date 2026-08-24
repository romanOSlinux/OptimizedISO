---
name: code-review
description: >-
  Activate this skill before finalizing changes, making a commit, or presenting code
  to the user, to audit correctness, UTF-8 BOM encoding, Windows PowerShell 5.1 compatibility,
  security, edge cases, and GUI STA threading.
---

# Revisión de Código y Control de Calidad

Checklist obligatorio antes de commitear o reportar tareas como completadas.

## Checklist de Auditoría

### 1. Codificación y Compatibilidad de Runtime
- [ ] ¿El archivo `.ps1` / `.psm1` está guardado estrictamente en formato **UTF-8 con BOM** (`0xEF, 0xBB, 0xBF`)?
- [ ] ¿Se validó el archivo contra el AST de **Windows PowerShell 5.1** (`powershell.exe`) con 0 errores?
- [ ] ¿Los comandos o scripts con interfaz gráfica (`Out-GridView`, Forms) incluyen el flag `-STA`?

### 2. Correctitud y Lógica
- [ ] ¿Se manejan rutas con espacios o caracteres especiales usando entrecomillado adecuado?
- [ ] ¿Se controlan valores nulos (`$null -eq $var`) y colecciones vacías?
- [ ] ¿Se liberan handles y colmenas de registro (`reg.exe unload`, `[GC]::Collect()`) tras operaciones DISM/Registry?

### 3. Seguridad y Buenas Prácticas
- [ ] ¿Cero credenciales o datos sensibles hardcodeados?
- [ ] ¿Las operaciones destructivas cuentan con validación de existencia previa?
- [ ] ¿No se modificó código funcional existente sin justificación técnica?

---

## Verificación Rápida
Ejecutar el validador AST sobre el archivo objetivo:
```powershell
& ".agents/skills/powershell-windows/scripts/Test-ScriptAstAndBom.ps1" -FilePath "ruta/al/script.ps1"
```
