---
name: windows-updates-servicing
description: >-
  Activate this skill when downloading official Windows Updates (.msu/.cab),
  slipstreaming patches into WIM images with DISM, sorting servicing dependencies
  (SSU, Checkpoint KB5043080, LCU, .NET), or diagnosing DISM exit codes.
---

# Windows Updates Servicing y Slipstreaming

Protocolo oficial para la descarga, ordenamiento e inyección offline de parches de Windows.

## Reglas Obligatorias de Inyección

1. **Orden DISM Estricto:** Siempre inyectar en secuencia: `SSU` -> `Checkpoint KB5043080` (en 24H2/25H2) -> `LCU` -> `.NET Framework` -> `SafeOS WinRE`.
2. **Validación de Integridad:** Verificar firmas Authenticode de Microsoft antes de invocar DISM.
3. **Limpieza WinSxS:** Ejecutar `/StartComponentCleanup /ResetBase` antes de desmontar con `/Commit`.

---

## Verificación Rápida del Árbol de Parches

Para auditar los archivos `.msu` en la carpeta de actualizaciones y obtener el orden exacto:
```powershell
& ".agents/skills/windows-updates-servicing/scripts/Test-UpdatesTree.ps1" -UpdatesPath "C:\OptimizedISO\Updates"
```

---

## Documentación y Referencias Técnicas

- [Matriz Técnica de Inyección y Dependencias DISM](./references/servicing-kb-matrix.md)
