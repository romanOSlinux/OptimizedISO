# PLAN-0122: Pilar 2 - Gestión Quirúrgica de Windows Recall y Características IA en Windows 11 24H2 (DISM Offline y GPO SSOT)

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0122 |
| **Fecha** | 2026-09-27 |
| **Componentes** | `scripts/Core/Policy-Engine.ps1`, `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`, `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/Testing/Test-FunctionalContracts.ps1` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Alta (Privacidad Integral, Cero Procesos Zombi IA en 24H2 y Paridad DISM) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM / PS 5.1), Regla 5 (Planes), Regla 7 (Watchdogs), Regla 8 (Modo Autónomo Continuo), Regla 9 (SSOT), Regla 10 (Cascada Docs-as-Code), Regla 13 (Auditoría Holística) |

---

## 1. Visión y Justificación Técnica

### A. La Característica Recall en Windows 11 24H2
A partir de Windows 11 24H2 (Build 26100+), Microsoft catalogó oficialmente a **Windows Recall** como una característica opcional del sistema (`Recall`), gestionable tanto en línea como fuera de línea a través de DISM:
`DISM /Image:<Path> /Disable-Feature /FeatureName:Recall`
Asimismo, Microsoft habilitó la directiva de grupo administrativa:
`Computer Configuration > Administrative Templates > Windows Components > Windows AI > Allow Recall to be enabled` (Valor: `0` para deshabilitar).

### B. Solución de Ingeniería
1. **SSOT en `Policy-Engine.ps1`:** Incorporar directivas de registro canónicas para deshabilitar la captura y telemetría de Recall (`DisableAIDataAnalysis`, políticas de `Windows AI`) y catálogo canónico DISM (`DISM_FEAT_RECALL`).
2. **Servicing WIM Offline en `New-OptimizedWindowsISO-v2.ps1`:** Integración a través de `Invoke-RomanOSDismComponentRemoval` para remoción desatendida de la característica `Recall` en perfiles optimizados.
3. **Conmutador de Interfaz en `romanOS-ControlCenter.ps1` y `Desktop-Helpers`:** Botón interactivo `btnHelperRecall`, script de conmutación `Toggle-Recall.ps1` / `.cmd` y telemetría en tiempo real sin romper Sysprep.

---

## 2. Fases de Implementación

- [x] **Fase 1:** Registrar políticas de Windows Recall e IA en `Policy-Engine.ps1` (GPO SSOT y catálogo canónico DISM).
- [x] **Fase 2:** Integrar desactivación DISM offline de la característica `Recall` en `New-OptimizedWindowsISO-v2.ps1`.
- [x] **Fase 3:** Añadir conmutador y telemetría en `romanOS-ControlCenter.ps1` y suite modular `Desktop-Helpers`.
- [x] **Fase 4:** Pruebas unitarias (CTR-42, Test-DesktopHelpers, Test-MSMGIntegration) y certificación en Windows PowerShell 5.1.
