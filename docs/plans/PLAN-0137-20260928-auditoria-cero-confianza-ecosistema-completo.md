# PLAN-0137: Auditoría Integral Cero-Confianza del Ecosistema romanOS: Inquisición de Código, Contraste con Fuentes Oficiales, Telemetría en Hardware Real y Matriz de Pruebas No Realizables

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0137 |
| **Fecha** | 2026-09-28 |
| **Componentes** | `scripts/Core/`, `scripts/Modules/`, `scripts/Builder/`, `scripts/GUI/`, `scripts/Testing/`, `autounattend.xml`, `SetupComplete.cmd`, `tools/` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Máxima / Crítica (Certificación Empírica Absoluta del Ecosistema bajo Regla 19) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (Codificación), Regla 7 (Watchdog), Regla 8 (Autonomía Continua), Regla 9 (SSOT), Regla 11 (Autonomía Técnica), Regla 13 (CWE-390 / Fail-Visible), Regla 14 (Multi-Hardware y Salvaguarda de Host), Regla 15 (Map-Reduce), Regla 18 (Tool-Gating), Regla 19 (Protocolo Zero-Trust / Anti-Circular Fallacy) |

---

## 1. Visión y Justificación Técnica

Bajo la **Regla 19 (Protocolo de Inquisición Cero-Confianza)** y la **Dimensión F de CONSTRAINTS.md**, este plan ejecuta una auditoría exhaustiva de extremo a extremo en todo el repositorio romanOS.

Se asume como premisa que ningún script o ajuste es correcto por el mero hecho de que su prueba pase con `ExitCode 0`. Toda directiva, comando y clave de registro debe ser sometida al **Tribunal de Fuentes Oficiales** (Microsoft Learn, Intel, AMD, RFCs), categorizada (Placebo, Obsoleto, Peligroso, Oficial/Efectivo) y contrastada empíricamente contra el hardware real del host mediante herramientas canónicas (`Coreinfo64`, `Test-KernelTimerResolution`, `fsutil bypassIo`, sensores de interrupciones PCIe y contadores de rendimiento).

Asimismo, este plan documentará de forma transparente y matemática qué pruebas no pueden ejecutarse en el entorno de desarrollo actual (por restricción de privilegios UAC/Admin en el host o requisitos de virtualización anidada) y cómo el sistema mitiga dicha limitación mediante la matriz de mocks sintéticos en memoria.

---

## 2. Fases de Implementación (Map-Reduce en 7 Lotes)

- [x] **Lote 1: Motores Core — `Hardware-Engine.ps1` y `Policy-Engine.ps1`:**
  - Inquisición de afirmaciones de detección de topología y contraste con telemetría real de `Coreinfo64.exe` en el host.
  - Auditoría de políticas de registro contra especificaciones de Microsoft Learn, Intel Optimization Manual y AMD PPR.
- [x] **Lote 2: Telemetría de Kernel, Almacenamiento NVMe/BypassIO, Interrupciones PCIe y Seguridad Ring-0:**
  - Ejecución en vivo de `Test-StorageStackBypassIO.ps1` y diagnóstico con `fsutil bypassIo`.
  - Ejecución de `Test-MsiInterruptTopology.ps1` para inspeccionar vectores MSI-X de GPU, NVMe y NIC.
  - Ejecución de `Test-KernelTimerResolution.ps1` para medir resolución real de timer y jitter.
  - Ejecución de `Test-SecurityAndAntiCheat.ps1` para validar `VulnerableDriverBlocklistEnable` y LSA PPL.
- [x] **Lote 3: Módulos Operativos y Debloat Adaptativo:**
  - Inquisición de `Win11-Debloat-v3-Adaptive.ps1` (Principio de Chesterton: validar árbol de dependencias de AppX y servicios).
  - Inquisición de `Optimize-InterruptAffinity.ps1`, `Optimize-WebBrowsers.ps1`, `Optimize-GamingAndApps.ps1` y `Watchdog-ServiceDrift.ps1`.
- [x] **Lote 4: Desatendido (`autounattend.xml`, `SetupComplete.cmd`) y Pipeline del Builder:**
  - Validación de esquema XSD formal de `autounattend.xml` contra especificación oficial de Windows Setup.
  - Inquisición de `SetupComplete.cmd` (orden determinista, No-BOM, mutex de bloqueo OEM).
  - Inquisición de `WimLib-Helper.ps1` y `New-OptimizedWindowsISO-v2.ps1` (arquitectura Zero-Mount, bootloaders El Torito).
- [x] **Lote 5: Interfaces Gráficas y Experiencia de Usuario (`Control Center`, `Studio`, `Toolkit`):**
  - Auditoría de hilos STA, desvinculación de bloqueos interactivos de `StandardInput`, y enlace funcional con motores Core.
- [x] **Lote 6: Matriz Forense de Pruebas No Realizables y Mitigación por Mocks:**
  - Documentar exhaustivamente las pruebas que requieren elevación UAC/Admin (`New-TestVM-HyperV.cmd`, montaje WIM en vivo, particionamiento de disco).
  - Justificación de la mitigación obligatoria mediante Mocks Sintéticos en memoria (`Test-HardwareTopologyMocks.ps1`).
- [x] **Lote 7: Consolidación de Artefacto Maestro, Registro en MCP `memory` y Commit Atómico:**
  - Generar el informe ejecutivo integral con todas las evidencias empíricas, fuentes oficiales y veredictos técnicos.
