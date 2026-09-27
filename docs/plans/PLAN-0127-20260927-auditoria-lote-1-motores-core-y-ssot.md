# PLAN-0127: Auditoría y Validación en Vivo del Lote 1 - Motores Core, SSOT y Helpers

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0127 |
| **Fecha** | 2026-09-27 |
| **Componentes** | `scripts/Core/Policy-Engine.ps1`, `scripts/Core/Hardware-Engine.ps1`, `scripts/Core/WimLib-Helper.ps1`, `scripts/Core/Sysinternals-Helper.ps1`, `scripts/Core/UI-Engine.ps1` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Alta (Cimientos Arquitectónicos y Single Source of Truth) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM), Regla 9 (SSOT), Regla 13 (Cero Fallos Silenciosos CWE-390), Regla 14 (Multi-Hardware), Regla 15 (Map-Reduce Lote 1) |

---

## 1. Visión y Justificación Técnica

Los motores del directorio `scripts/Core/` constituyen el núcleo arquitectónico del ecosistema **romanOS / OptimizedISO**:
- [`Policy-Engine.ps1`](file:///c:/OptimizedISO/scripts/Core/Policy-Engine.ps1) es la Fuente Única de Verdad (SSOT) de todas las políticas de registro, bypasses, directivas de navegadores y configuraciones desatendidas.
- [`Hardware-Engine.ps1`](file:///c:/OptimizedISO/scripts/Core/Hardware-Engine.ps1) gobierna la introspección dinámica de hardware (CPU heterogénea/simétrica, APU UMA vs dGPU, NVMe BypassIO vs SATA HDD).
- [`WimLib-Helper.ps1`](file:///c:/OptimizedISO/scripts/Core/WimLib-Helper.ps1) permite la inspección y manipulación forense de imágenes WIM sin montaje (`Zero-Mount`), previniendo bloqueos de desmontaje en DISM.
- [`Sysinternals-Helper.ps1`](file:///c:/OptimizedISO/scripts/Core/Sysinternals-Helper.ps1) encapsula herramientas oficiales de Microsoft (Coreinfo, Sigcheck, Autoruns) con fallback resiliente CIM.

### Respaldo de Fuentes Oficiales
- **Microsoft Learn:** *BypassIO for Storage Drivers & Filter Developers* (`fsutil bypassio`).
- **Microsoft Learn:** *Memory Management Architecture in WDDM (Unified Memory Architecture - UMA).*
- **Microsoft Learn:** *PowerShell Script Analyzer Rules (`PSAvoidUsingEmptyCatchBlock`, `PSUseBOMForUnicode`).*

---

## 2. Fases de Implementación

- [x] **Fase 1: Auditoría Estática AST y Codificación (Regla 4 y 13):**
  - Validar que el 100% de los scripts de `scripts/Core/` posean marca de orden de bytes UTF-8 BOM (`0xEF, 0xBB, 0xBF`). (Resultado: 12/12 PASS).
  - Inspeccionar el AST de Windows PowerShell 5.1 confirmando 0 errores de sintaxis y 0 bloques `catch` mudos. (Resultado: 0 errores, 0 catch vacíos).
- [x] **Fase 2: Introspección en Vivo del Hardware Host (Ryzen 8600G + APU 760M):**
  - Ejecutar `Get-RomanOSHardwareProfile` e inspeccionar que clasifique con exactitud:
    - GPU como `SharedMemoryArchitecture = $true` (APU UMA). (Detectado: AMD Radeon 760M Graphics, IsIntegrated=$true, HAGS=$true, MSI=$true).
    - Topología de CPU como simétrica (6 núcleos / 12 hilos) sin interferir en Thread Director (`Win32PrioritySeparation=38`, Symmetric_CPU).
    - Volúmenes de almacenamiento diferenciando NVMe ADATA SWORDFISH vs SATA/HDD.
- [x] **Fase 3: Auditoría de BypassIO y DirectStorage 1.2+ en Vivo:**
  - Ejecutar `Get-RomanOSBypassIOStatus -DriveLetter C:` y verificar la detección de compatibilidad y minifiltros. (Corregidas expresiones `.Add((if ...))` para compatibilidad estricta con PS 5.1; soporte de Mocks validado con PASS).
- [x] **Fase 4: Verificación de Helpers WimLib y Sysinternals:**
  - Probar `Get-WimImageInfoFast` contra la ISO base `Win11_25H2_Spanish_x64_v2.iso` (2 imágenes extraídas en <1s sin montaje).
  - Probar `Get-CpuCoreTopology` con Coreinfo64 y validar el fallback CIM (133 flags detectados: POPCNT, AVX2, HYPERVISOR).
- [x] **Fase 5: Certificación y Reporte de Métricas del Lote 1:**
  - Registrar aserciones unitarias en `Test-FunctionalContracts.ps1` (CTR-46) y certificar suite completa (94/94 PASS, 100%). Estado: `COMPLETADO`.
