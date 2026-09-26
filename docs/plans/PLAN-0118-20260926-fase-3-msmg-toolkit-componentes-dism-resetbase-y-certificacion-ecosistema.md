# PLAN-0118: Fase 3 - Inspiración MSMG Toolkit: Catálogo Canónico de Componentes Opcionales DISM, Reducción de Huella WIM (/ResetBase Seguro) y Certificación Integral del Ecosistema con Métricas en HTML

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0118 |
| **Fecha** | 2026-09-26 |
| **Componentes** | `scripts/Core/Policy-Engine.ps1`, `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`, `scripts/Modules/romanOS-Toolkit.ps1`, `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/Testing/Test-MSMGIntegration.ps1`, `scripts/Testing/Test-OptimizedISO-v2.ps1`, `scripts/Testing/Invoke-EcosystemAudit.ps1`, `Auditoria-Ecosistema.html`, `docs/plans/README.md` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Alta (Reducción de Huella en Disco, Servicing Limpio de Componentes de Bajo Nivel y Certificación Repo-Wide) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM / PS 5.1), Regla 5 (Planes), Regla 7 (Watchdogs), Regla 8 (Modo Autónomo Continuo), Regla 9 (SSOT Policy-Engine), Regla 10 (Cascada Docs-as-Code), Regla 11 (Ingeniero Autónomo), Regla 13 (Auditoría Holística / CWE-390), Regla 14 (Salvaguarda de Almacenamiento y Mocks Multi-Hardware), Regla 15 (Memoria Jerárquica Map-Reduce) |

---

## 1. Contexto, Objetivos y Principio de Soberanía Arquitectónica

### A. Mandato Incondicional: Soberanía del Motor de romanOS
Siguiendo la instrucción taxativa del usuario (*"MicroWin, NOSOTROS TENEMOS NUESTRO SISTEMA DE CREACION DE iso, MicroWin SOLO DEBE SER UN REFERENCIAL PARA TOMAR LO MEJOR, SI NO LO TIENE SE DESCARTA"*), este mismo principio de ingeniería rige para **MSMG Toolkit**:
* **romanOS ya cuenta con un pipeline nativo superior:** Manejo robusto de permisos, desmontaje seguro en máquina de estados con reintentos y recolección de basura GC, bypasses OOBE de hardware y conectividad, inyección de runtimes dual (WIM offline + `$OEM$`) y logging forense automático.
* **MSMG Toolkit es estrictamente un marco de referencia comparativo:** No subordinamos ni reemplazamos nuestros scripts con los batch monolíticos de MSMG Toolkit. Extraemos exclusivamente su núcleo de mayor valor comprobado en la comunidad internacional:
  1. Identificación canónica de paquetes y características opcionales de Windows para remoción limpia sin romper SFC (`sfc /scannow`) ni impedir la instalación de futuras actualizaciones acumulativas (LCUs).
  2. Procedimiento seguro de consolidación del almacén de componentes de Windows (`WinSxS`) mediante `/ResetBase` offline para reducir el tamaño de la imagen WIM entre 1 y 2 GB.
  3. Descarte de todo componente destructivo, scripts batch rígidos o dependencias obsoletas de Windows 7/8.

---

### B. Objetivos Centrales

1. **Catálogo Canónico de Componentes Opcionales DISM en `Policy-Engine.ps1` (SSOT):**
   * Crear la función canónica `Get-RomanOSDismComponentsCatalog` con componentes de sistema seguros para remover de forma offline sin corromper la imagen (ej. `Cortana`, `Edge Chromium`, `OneDrive Setup`, `Windows Mail`, `GameBar`, `MathRecognizer`, `StepsRecorder`, `QuickAssist`, `VBScript`, etc.).
   * Definir banderas de compatibilidad (`SafeForGaming`, `BreaksWindowsUpdate: $false`, `Category`).
2. **Motor de Remoción de Componentes y Consolidación WinSxS en `New-OptimizedWindowsISO-v2.ps1`:**
   * Implementar `Invoke-RomanOSDismComponentRemoval`: Remoción controlada vía `dism.exe` y PowerShell sobre el WIM montado con telemetría visible y manejo CWE-390.
   * Implementar `Invoke-RomanOSComponentStoreCleanup`: Consolidación offline de WinSxS con `/Cleanup-Image /StartComponentCleanup /ResetBase` que registre el ahorro exacto en megabytes.
   * Inyectar estas funciones en el flujo del Builder cuando el perfil de optimización lo solicite (opciones de Preset y CLI).
3. **Paridad en Toolkit y Control Center (Cascada):**
   * Incorporar la consulta y auditoría de componentes DISM en `romanOS-Toolkit.ps1` y `romanOS-ControlCenter.ps1`.
4. **Certificación Integral del Ecosistema y Reporte HTML Ejecutivo:**
   * Desarrollar `scripts/Testing/Test-MSMGIntegration.ps1` para validar los componentes DISM y el motor de servicing.
   * Actualizar el conteo de funciones en `scripts/Testing/Test-OptimizedISO-v2.ps1` ($EXPECTED_FUNCS).
   * Ejecutar la auditoría integral repo-wide mediante `Invoke-EcosystemAudit.ps1` y generar el dashboard HTML `Auditoria-Ecosistema.html` con métricas cuantificadas completas demostrando 100% de operatividad.

---

## 2. Plan de Implementación por Fases

### Fase 1: Catálogo Canónico de Componentes DISM en `Policy-Engine.ps1` (SSOT)
* Registrar `Get-RomanOSDismComponentsCatalog` en `Policy-Engine.ps1`.
* Exportar lista de componentes para su consumo transversal por el Builder, Toolkit y Testing.

### Fase 2: Motor de Servicing de Componentes y `/ResetBase` en `New-OptimizedWindowsISO-v2.ps1`
* Añadir `Invoke-RomanOSDismComponentRemoval` y `Invoke-RomanOSComponentStoreCleanup`.
* Conectar en el flujo de servicing WIM post-LCU y post-debloat.
* Actualizar `$EXPECTED_FUNCS = 72` en `scripts/Testing/Test-OptimizedISO-v2.ps1`.

### Fase 3: Paridad en Toolkit y romanOS Control Center
* Reflejar la limpieza profunda y catálogo de componentes en `romanOS-Toolkit.ps1` y `romanOS-ControlCenter.ps1`.

### Fase 4: Suite de Pruebas Unitarias de Integración MSMG
* Crear `scripts/Testing/Test-MSMGIntegration.ps1` con validación AST, UTF-8 BOM y ejecución en Windows PowerShell 5.1.

### Fase 5: Certificación Repo-Wide y Dashboard HTML de Métricas
* Ejecutar suites de pruebas maestras.
* Actualizar y ejecutar `scripts/Testing/Invoke-EcosystemAudit.ps1` para generar `Auditoria-Ecosistema.html` con las métricas cuantitativas consolidadas del ecosistema.

---

## 3. Matriz de Trazabilidad y Verificación

| Componente | Archivo Principal | Criterio de Aceptación |
| :--- | :--- | :--- |
| **Catálogo SSOT** | `scripts/Core/Policy-Engine.ps1` | `Get-RomanOSDismComponentsCatalog` estructurado y tipado |
| **Servicing WIM** | `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` | `Invoke-RomanOSDismComponentRemoval` y `ResetBase` sin romper WIM |
| **Harness Builder** | `scripts/Testing/Test-OptimizedISO-v2.ps1` | 72 funciones cargadas y 100% PASS en PS 5.1 |
| **Suite MSMG** | `scripts/Testing/Test-MSMGIntegration.ps1` | Mocks y validación de componentes (100% PASS) |
| **Reporte HTML** | `Auditoria-Ecosistema.html` | Generación exitosa con métricas cuantificadas |
