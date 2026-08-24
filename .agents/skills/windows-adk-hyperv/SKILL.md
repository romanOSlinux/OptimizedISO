---
name: windows-adk-hyperv
description: >-
  Activate this skill when compiling bootable Windows ISOs with Windows ADK (oscdimg.exe),
  mounting or unmounting WIM/ESD images with DISM, configuring El Torito multi-boot,
  or provisioning and troubleshooting Hyper-V Gen2 virtual machines.
---

# Windows ADK y Automatización Hyper-V

Flujos de trabajo para compilar imágenes ISO de Windows y validar instalaciones en Hyper-V.

## Diagnóstico Rápido del Entorno

Para verificar la presencia de `oscdimg.exe`, DISM y el estado de Hyper-V:
```powershell
& ".agents/skills/windows-adk-hyperv/scripts/Test-AdkEnvironment.ps1"
```

---

## Procedimientos Clave

1. **Montaje WIM Seguro:** Siempre usar `-Action Discard` en caso de error y asegurar que los identificadores de archivo se liberen con Garbage Collection `[GC]::Collect()`.
2. **Flags de Compilación:** Utilizar siempre el formato multi-boot El Torito (`bootdata:2#p0...#pEF...`) para compatibilidad BIOS y UEFI.
3. **VMs de Prueba en Hyper-V:** Generación 2 con TPM habilitado (`Enable-VMTPM`) y plantilla `MicrosoftWindows`.

---

## Documentación y Referencias Técnicas

- [Referencia Técnica de oscdimg y Hyper-V](./references/oscdimg-hyperv-reference.md)
