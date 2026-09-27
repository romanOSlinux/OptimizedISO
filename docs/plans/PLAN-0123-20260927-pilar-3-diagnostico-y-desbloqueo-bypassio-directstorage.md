# PLAN-0123: Pilar 3 - Diagnóstico Forense y Desbloqueo del Stack BypassIO / DirectStorage 1.2+ en Almacenamiento NVMe

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0123 |
| **Fecha** | 2026-09-27 |
| **Componentes** | `scripts/Core/Hardware-Engine.ps1`, `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/Testing/Test-FunctionalContracts.ps1` |
| **Estado** | `PENDIENTE` |
| **Prioridad** | Alta (Maximización de Tasa de Transferencia NVMe para Juegos con DirectStorage) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM / PS 5.1), Regla 5 (Planes), Regla 7 (Watchdogs), Regla 8 (Modo Autónomo Continuo), Regla 9 (SSOT), Regla 11 (Ingeniero Autónomo), Regla 14 (Salvaguarda de Almacenamiento) |

---

## 1. Visión y Justificación Técnica

### A. La Importancia de BypassIO en Windows 11
BypassIO es la ruta de entrada/salida optimizada de Windows 11 que permite transferir datos directamente desde almacenamiento NVMe a la GPU sin la sobrecarga de la pila de filtros de E/S de Windows. Es el componente vital para la descompresión por GPU en DirectStorage 1.2+.
Sin embargo, software con controladores minifilter obsoletos suele causar vetos (Error 506), degradando el ancho de banda.

### B. Solución de Ingeniería
1. **Introspección en `Hardware-Engine.ps1`:** Implementar `Get-RomanOSBypassIOStatus` que audite cada volumen lógico montado mediante `fsutil bypassIo state /v <DriveLetter>` y consulte los filtros cargados mediante `fltmc instances`.
2. **Telemetría en `romanOS-ControlCenter.ps1`:** Mostrar en la tarjeta de Almacenamiento si BypassIO está habilitado o vetado, identificando el controlador causante en caso de incompatibilidad.
3. **Mocks Unitarios:** Validar la detección mediante inyección de mocks sin requerir ejecución destructiva de disco.

---

## 2. Fases de Implementación

- [ ] **Fase 1:** Diseñar función `Get-RomanOSBypassIOStatus` en `Hardware-Engine.ps1` con soporte de modo Mock.
- [ ] **Fase 2:** Integrar telemetría de BypassIO en la pestaña de Hardware de `romanOS-ControlCenter.ps1`.
- [ ] **Fase 3:** Incorporar contrato funcional en `Test-FunctionalContracts.ps1`.
- [ ] **Fase 4:** Validación en Windows PowerShell 5.1 y commit atómico.
