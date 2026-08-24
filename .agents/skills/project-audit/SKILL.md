---
name: project-audit
description: >-
  Activate this skill when auditing the architecture and integrity of the ISO generator,
  verifying autounattend.xml syntax and schema, inspecting $OEM$ directory structure,
  or reviewing registry servicing safety protocols.
---

# Auditoría de Proyecto romanOS / OptimizedISO

Procedimiento para auditar la integridad de scripts, plantillas XML y configuraciones de la ISO.

## Áreas de Auditoría Críticas

1. **Esquema `autounattend.xml`:**
   - Validar codificación UTF-8 sin BOM (requerimiento de Windows Setup).
   - Validar layout UEFI/GPT de 4 particiones (WinRE = TypeID `de94bba4...`, InstallTo PartitionID = 4).
   - Validar que no existan directivas inválidas como `<WillContinueOnFailure>`.
2. **Estructura de Inyección `$OEM$`:**
   - `$OEM$\$$\Setup\Scripts` para scripts de sistema y `SetupComplete.cmd`.
   - `$OEM$\$$\Setup\Scripts\Core` para el motor gráfico unificado (`UI-Engine.ps1`).
3. **Servicing de Registro Offline:**
   - Confirmar desmonte estricto de hives temporales con `reg.exe unload` y Garbage Collection.

---

## Documentación y Referencias Técnicas

- [Esquema de Particionado y XML de autounattend](./references/autounattend-schema.md)
