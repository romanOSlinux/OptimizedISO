# PLAN-0148: Purga de Actualización 26H2, Blindaje de Versiones Mayores y Selector de Cuarentena (15d - 180d / Anclaje) en romanOS Control Center

**Fecha:** 2026-09-29  
**Estado:** COMPLETADO  
**Autor:** Antigravity (Advanced Agentic Coding)  
**Marco de Gobernanza:** [`.agents/GOVERNANCE-MATRIX.md`](../../.agents/GOVERNANCE-MATRIX.md)  
**Reglas Aplicadas:** Regla 0 (Git y Trazabilidad), Regla 4 (PowerShell 5.1 y UTF-8 BOM), Regla 9 (SSOT Policy-Engine), Regla 10 (Docs-as-Code & Cascada), Regla 11 (Autonomía Técnica), Regla 13 (Cero Fallos Silenciosos)

---

## 1. Contexto y Diagnóstico Forense

Durante una búsqueda interactiva manual en Windows Update ("Seeker"), el sistema operativo descargó automáticamente la actualización de características mayor **Windows 11 26H2** (Build de salto anual), dejando el host en estado crítico de reinicio pendiente:
* `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired` = `True`
* `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending` = `True`

### Causa Raíz
1. Las directivas de romanOS previas configuraban `DeferQualityUpdates` (7 días) para parches acumulativos mensuales (`LCU`), pero **no contemplaban directivas de aplazamiento de actualizaciones de características mayores (`Feature Updates`)**.
2. Al pulsar el botón manual "Buscar actualizaciones", Microsoft elevó al cliente al modo *Seeker*, ignorando las restricciones automáticas de fondo y despachando 26H2 al no encontrar directivas de bloqueo de versión (`TargetReleaseVersion`).

---

## 2. Objetivos de Ingeniería

1. **Purga Segura de la Actualización en Cola:** Proveer una herramienta de host (`Purge-PendingWindowsUpdate.ps1` / `.cmd`) con auto-elevación UAC para detener servicios, vaciar `SoftwareDistribution\Download` y eliminar las claves de `RebootRequired` y `RebootPending`, impidiendo la instalación accidental de 26H2.
2. **SSOT en `Policy-Engine.ps1`:** Incorporar formalmente las directivas oficiales de Microsoft para versiones mayores:
   * `DeferFeatureUpdates` (REG_DWORD = 1)
   * `DeferFeatureUpdatesPeriodInDays` (REG_DWORD: 0 a 365 días)
   * `TargetReleaseVersion` (REG_DWORD = 1)
   * `TargetReleaseVersionInfo` (REG_SZ: ej. "25H2")
   * `ProductVersion` (REG_SZ: "Windows 11")
   * Funciones canónicas exportadas: `Get-RomanOSFeatureUpdatePolicy` y `Set-RomanOSFeatureUpdatePolicy`.
3. **Integración en `romanOS-ControlCenter.ps1`:**
   * Agregar en la tarjeta de Windows Update un selector desplegable (`ComboBox`) con estilos dinámicos de Cyber-Stealth:
     - ⏱️ Sin aplazamiento (Inmediato)
     - 🛡️ Aplazar 15 días (Filtro temprano)
     - 🛡️ Aplazar 1 mes (30 días)
     - 🛡️ Aplazar 2 meses (60 días)
     - 🛡️ Aplazar 3 meses (90 días)
     - 🛡️ Aplazar 6 meses (180 días)
     - 🔒 Anclar a versión actual (Bloqueo Permanente: 25H2)
   * Botón `btnApplyFeatureDeferral` ("Aplicar Política de Versión").
   * Botón `btnPurgePendingWU` ("Purgar Actualizaciones en Cola").
4. **Verificación y Cobertura de Pruebas:**
   * Pruebas sintácticas y funcionales en Windows PowerShell 5.1 (`powershell.exe -STA`).
   * Contratos funcionales actualizados (CTR-21.1 y arnés E2E de 103 botones).

---

## 3. Fases de Ejecución

- [x] **Fase 1: Herramienta de Purga de Host**  
  Crear `scripts/Host-Tools/Purge-PendingWindowsUpdate.ps1` y `Purge-PendingWindowsUpdate.cmd` con auto-elevación UAC y validación en PS 5.1.
- [x] **Fase 2: Expansión de `Policy-Engine.ps1` (SSOT)**  
  Registrar políticas `POL_WU_DEFER_FEATURE`, `POL_WU_DEFER_FEATURE_DAYS`, `POL_WU_TARGET_RELEASE_VERSION`, `POL_WU_TARGET_RELEASE_INFO`, `POL_WU_PRODUCT_VERSION` e implementar `Get-RomanOSFeatureUpdatePolicy` y `Set-RomanOSFeatureUpdatePolicy`.
- [x] **Fase 3: Modernización de la GUI `romanOS-ControlCenter.ps1`**  
  Incorporar el ComboBox de aplazamiento, los botones de acción en XAML y los manejadores de eventos en PowerShell.
- [x] **Fase 4: Verificación Integral y Arnés de Pruebas**  
  Ejecutar arnés de pruebas de GUI (103/103 botones aprobados) y contratos de políticas (CTR-21.1) en frío contra `powershell.exe`.
- [x] **Fase 5: Documentación y Cierre de Plan**  
  Registrar actualización en `docs/plans/README.md` y realizar commit atómico en Git.
