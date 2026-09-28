# PLAN-0142: Auditoría Forense Exhaustiva Zero-Mount de la ISO Generada

**Fecha:** 2026-09-28  
**Estado:** COMPLETADO  
**Severidad:** ALTA / AUDITORÍA DE CALIDAD INDUSTRIAL  
**Rama:** `feature/offline-ui-tweaks`  
**Objetivo de Inspección:** `C:\Users\Thiago\Desktop\WinISO_Optimizado\Windows_11_Pro_for_Workstations_25H2_x64_Spanish.iso`

---

## 1. Contexto y Alcance

El usuario ha generado una imagen ISO personalizada de Windows 11 (`Windows_11_Pro_for_Workstations_25H2_x64_Spanish.iso`, ~10.19 GB) y solicita una auditoría forense completa. Para certificar que la ISO es 100% funcional, bootable y conforme con los estándares de ingeniería de romanOS sin alterar el host ni la imagen, se implementa una auditoría forense en 5 niveles de profundidad utilizando la metodología Zero-Mount.

---

## 2. Metodología de Inspección en 5 Niveles

1. **Nivel 1: Anatomía y Estructura El Torito (ISO Dual-Boot BIOS/UEFI):**
   - SHA-256 de la imagen.
   - Integridad del catálogo El Torito (boot BIOS `boot/etfsboot.com` + UEFI `efi/microsoft/boot/efisys.bin`).
   - Verificación de `sources/ei.cfg` (canal `_Default`, `VL 0`).

2. **Nivel 2: Introspección del Archivo Desatendido (`autounattend.xml`):**
   - Extracción zero-mount del XML en la raíz.
   - Verificación de bypasses de hardware (TPM, SecureBoot, RAM, Storage, CPU).
   - Verificación de bypass de cuenta Microsoft (`BypassNRO = 1`).
   - Esquema de particionamiento UEFI GPT (System, MSR, OS).
   - Comandos síncronos `FirstLogonCommands` y llamadas protegidas a `SetupComplete.cmd`.

3. **Nivel 3: Auditoría de Inyección `$OEM$`:**
   - Inspección de `sources/$OEM$/$$/Setup/Scripts/SetupComplete.cmd` (codificación ANSI / Sin BOM, mutex `.setup_completed`).
   - Verificación de motores canónicos inyectados (`Policy-Engine.ps1`, `Hardware-Engine.ps1`).
   - Presencia de scripts consumidores y herramientas (`romanOS-ControlCenter`, `romanOS-Toolkit`, etc.).

4. **Nivel 4: Radiografía de Metadatos WIM (`install.wim` / `boot.wim`):**
   - Lectura de descriptores XML de `install.wim` con `wimlib-imagex info` y 7-Zip.
   - Edición reportada, Índice, Arquitectura (x64), Idioma (`es-ES`), Versión del SO y Build/UBR.
   - Algoritmo de compresión y tamaño de la imagen.

5. **Nivel 5: Inspección Quirúrgica de Colmenas del Registro Offline:**
   - Extracción selectiva de colmenas (`SOFTWARE` y `SYSTEM`) de `install.wim` hacia `scratch/`.
   - Validación física de integridad y tamaño de colmenas (85.25 MB y 10 MB).
   - Descarga y limpieza total obligatoria.

---

## 3. Matriz de Cambios y Artefactos

| Componente | Archivo / Destino | Acción |
|---|---|---|
| Plan de Trabajo | `docs/plans/PLAN-0142-20260928-auditoria-forense-zero-mount-iso-generada.md` | Registro de plan formal |
| Índice de Planes | `docs/plans/README.md` | Actualización de tabla de planes |
| Script Forense | `scratch/Audit-GeneratedISO.ps1` | Script ejecutor de la batería en 5 niveles |
| Reporte Forense | `scratch/iso_audit/Audit_Report.json` | Matriz de conformidad con veredictos PASS/FAIL/WARN |

---

## 4. Criterios de Aceptación

- [x] La ISO posee estructura válida y doble sector de arranque El Torito.
- [x] `autounattend.xml` contiene todos los bypasses requeridos y sintaxis XML válida.
- [x] `SetupComplete.cmd` existe, no tiene BOM y tiene el cerrojo mutex de finalización.
- [x] Los motores `Policy-Engine.ps1` y `Hardware-Engine.ps1` están presentes en `$OEM$`.
- [x] `install.wim` tiene metadata válida correspondiente a Windows 11 Pro for Workstations 25H2 x64 (Build 26200, UBR 9457).
- [x] Colmenas de registro extraídas e íntegras físicamente desde WIM.
- [x] Cero daños, cero montajes permanentes DISM y limpieza total de archivos efímeros en `scratch/`.
