# PLAN-0129: Auditoría y Validación en Vivo del Lote 3 - Optimización, Debloat Adaptativo y Gaming

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0129 |
| **Fecha** | 2026-09-27 |
| **Componentes** | `scripts/Modules/Win11-Debloat-v3-Adaptive.ps1`, `scripts/Modules/Switch-GameDevMode.ps1`, `scripts/Modules/Optimize-InterruptAffinity.ps1`, `scripts/Modules/Optimize-WebBrowsers.ps1`, `scripts/Desktop-Helpers/Toggle-Recall.ps1` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Alta (Modificación de Sistema, Afinamiento de Latencia y Debloat Soberano) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM), Regla 13 (CWE-390 Fail-Visible), Regla 14 (Salvaguarda Host y APU/UMA), Regla 15 (Map-Reduce Lote 3) |

---

## 1. Visión y Justificación Técnica

Los módulos de optimización implementan las directivas activas de afinamiento del sistema operativo:
- [`Win11-Debloat-v3-Adaptive.ps1`](file:///c:/OptimizedISO/scripts/Modules/Win11-Debloat-v3-Adaptive.ps1): Debloat adaptativo e inteligente; preserva componentes del sistema en base a la edición detectada y opciones de usuario.
- [`Switch-GameDevMode.ps1`](file:///c:/OptimizedISO/scripts/Modules/Switch-GameDevMode.ps1): Conmutador bimodal entre Modo Juego (máxima respuesta, descarte de servicios de desarrollo) y Modo Desarrollo (Hyper-V, WSL2, Docker, DISM habilitados).
- [`Optimize-InterruptAffinity.ps1`](file:///c:/OptimizedISO/scripts/Modules/Optimize-InterruptAffinity.ps1): Mapeo de interrupciones PCIe (MSI-X) y descongestión de Core 0 mediante máscaras binarias de afinidad CPU.
- [`Optimize-WebBrowsers.ps1`](file:///c:/OptimizedISO/scripts/Modules/Optimize-WebBrowsers.ps1): Aplicación SSOT de directivas GPO para Edge, Chrome, Brave y Firefox sin tocar perfiles de usuario.
- [`Toggle-Recall.ps1`](file:///c:/OptimizedISO/scripts/Desktop-Helpers/Toggle-Recall.ps1): Conmutador de estado para Windows Recall e IA en Windows 11 24H2.

### Respaldo de Fuentes Oficiales
- **Microsoft Learn:** *Supporting ShouldProcess in PowerShell Functions (`-WhatIf`, `-Confirm`).*
- **Microsoft Learn:** *PCIe Message-Signaled Interrupts (MSI/MSI-X) and Interrupt Steering.*
- **Microsoft Learn:** *Group Policy Administrative Templates for Microsoft Edge & Google Chrome.*
- **AMD Developer Central:** *Ryzen Processor Interrupt Distribution and NUMA/UMA Node Architecture.*

---

## 2. Fases de Implementación

- [x] **Fase 1: Auditoría Estática AST y BOM (Regla 4):**
  - Validar codificación UTF-8 con BOM en los 5 scripts `.ps1` y formato No-BOM en sus lanzadores `.cmd`. (Verificado: 5/5 scripts con BOM OK y 0 errores AST; 5/5 lanzadores .cmd No-BOM confirmados).
  - Auditar que ningún bloque `catch` suprima excepciones críticas sin advertencia. (0 bloques catch vacíos).
- [x] **Fase 2: Validación en Vivo con `-WhatIf -SkipElevation`:**
  - Ejecutar `Win11-Debloat-v3-Adaptive.ps1 -AuditOnly -SkipElevation` (Auditoría limpia en 3.5s, NPU/NVMe/RAM detectados, 0 mutaciones en host).
  - Ejecutar `Switch-GameDevMode.ps1 -Mode Game -WhatIf -SkipElevation` (Poda de memoria simulada, planificador kernel SystemResponsiveness=0, GPU Priority=8, cero mutaciones).
- [x] **Fase 3: Auditoría de Afinidad PCIe e Interrupciones:**
  - Ejecutar `Optimize-InterruptAffinity.ps1 -Action Status -WhatIf -SkipElevation` (GPU 760M, 2 controladoras NVMe en modo MSI activo High con SpreadAcrossCPUs 0x5 en 1.06s).
- [x] **Fase 4: Verificación de Helpers de Navegadores y Recall:**
  - Probar `Toggle-Recall.ps1 -Action Status` (Windows Recall e IA reportado Desactivado: 0).
  - Probar `Optimize-WebBrowsers.ps1 -WhatIf -SkipElevation` (97 de 97 políticas de Edge, Chrome, Firefox y Brave auditadas y alineadas al SSOT).
- [x] **Fase 5: Certificación y Reporte de Métricas del Lote 3:**
  - Registrar CTR-48 en `Test-FunctionalContracts.ps1` y certificar suite completa (102/102 PASS, 100%, 0 errores y 0 excepciones en log físico). Estado: `COMPLETADO`.
