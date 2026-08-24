---
name: unattended-deployment
description: >-
  Activate this skill when generating, editing, or validating autounattend.xml answer files,
  configuring UEFI GPT disk partition layouts, setting bypasses (BypassNRO, BypassTPM),
  or troubleshooting Windows PE and OOBE setup errors.
---

# Despliegue Desatendido de Windows (autounattend.xml)

Protocolo para estructurar y validar respuestas desatendidas para Windows 10/11 UEFI y BIOS.

## Reglas Obligatorias de Esquema

1. **Codificación:** Guardar `autounattend.xml` en formato UTF-8 (con o sin BOM válido, evitando caracteres no ASCII sin escapar).
2. **Particionado UEFI GPT:** Utilizar siempre el esquema estándar de 4 particiones (WinRE 500 MB TypeID `de94bba4...`, EFI 100 MB, MSR 16 MB, Windows `PartitionID 4`).
3. **Cero Etiquetas Deprecadas:** No incluir directivas inexistentes en el esquema moderno de Setup como `<WillContinueOnFailure>`.

---

## Verificación Rápida de Esquema XML

Para validar cualquier archivo de respuesta o plantilla en memoria:
```powershell
& ".agents/skills/unattended-deployment/scripts/Test-UnattendXml.ps1" -XmlPath "sources/autounattend.xml"
```

---

## Documentación y Referencias Técnicas

- [Esquema de Particionado UEFI GPT y Nodos de Configuración](./references/uefi-gpt-unattend-schema.md)
