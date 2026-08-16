---
name: project-audit
description: "Procedimiento para auditar la estructura, seguridad y optimización de proyectos de personalización de Windows e imágenes ISO."
---

# Auditoría de Proyecto OptimizedISO

Procedimiento estándar para auditar la integridad de scripts, archivos XML y configuraciones del proyecto.

## Áreas de Auditoría Críticas
1. **Sintaxis XML de `autounattend.xml`:**
   - Validar namespaces (`wcm:action`, `xmlns:wcm`, `xmlns:xsi`).
   - Validar codificación UTF-8 sin BOM.
   - Layout de particiones UEFI/GPT (WinRE 500 MB TypeID `de94bba4...`, InstallTo PartitionID 4).
2. **Estructura `$OEM$`:**
   - `sources\$OEM$\$$\Setup\Scripts` para scripts de sistema.
   - `sources\$OEM$\$1\Users\Public\Desktop` para accesos directos y lanzadores de usuario.
3. **Servicing de Registro Offline:**
   - Verificar siempre el desmonte seguro de hives con `reg.exe unload` y Garbage Collection `[GC]::Collect()`.
4. **Comprobación de herramientas de compilación:**
   - Detectar presencia de `oscdimg.exe` en Windows ADK (`amd64` y `arm64`).
