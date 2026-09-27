# PLAN-0124: Pilar 4 - Generador Visual de Perfiles Desatendidos (Builder Mode) en romanOS Control Center

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0124 |
| **Fecha** | 2026-09-27 |
| **Componentes** | `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/Core/Policy-Engine.ps1`, `scripts/Testing/Test-FunctionalContracts.ps1` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Media-Alta (Ergonomía, Generación de autounattend.xml a Medida para USBs sin Compilar ISO) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM / PS 5.1), Regla 5 (Planes), Regla 7 (Watchdogs), Regla 8 (Modo Autónomo Continuo), Regla 9 (SSOT), Regla 10 (Cascada Docs-as-Code) |

---

## 1. Visión y Justificación Técnica

### A. Necesidad de un Modo Constructor Visual
Permitir a los administradores y usuarios generar un archivo `autounattend.xml` personalizado seleccionando opciones mediante casillas de verificación (Bypasses, particionado, perfiles de debloat y software Winget) y exportarlo a un directorio o memoria USB, sin necesidad de compilar la imagen ISO completa.

### B. Solución de Ingeniería
1. **Pestaña Builder en `romanOS-ControlCenter.ps1`:** Controles WPF para selección de opciones de despliegue con previsualización en vivo.
2. **Conexión SSOT:** Nueva función canónica `New-RomanOSUnattendXml` en `Policy-Engine.ps1` que unifica los pases `windowsPE`, `specialize` (con `Export-RomanOSUnattendCommands`), `oobeSystem` y esquemas `ZeroTouchGpt`.
3. **Validación Sintáctica:** Integración de exportación a archivo (`SaveFileDialog`) y certificación directa mediante `Test-UnattendXml.ps1`.

---

## 2. Fases de Implementación

- [x] **Fase 1:** Ampliar XAML de `romanOS-ControlCenter.ps1` con la interfaz del Generador Desatendido.
- [x] **Fase 2:** Enlazar eventos de exportación conectando con `Policy-Engine.ps1` y `New-RomanOSUnattendXml`.
- [x] **Fase 3:** Pruebas unitarias de generación y validación de XML exportado en `Test-FunctionalContracts.ps1` (CTR-44).
- [x] **Fase 4:** Validación en frío en Windows PowerShell 5.1 y commit atómico.

