# PLAN-0156: Incorporación de ToolTips Explicativos en Botones Complejos de romanOS Control Center

**Número Correlativo:** 0156  
**Fecha:** 2026-10-17  
**Estado:** COMPLETADO  
**Módulos Afectados:**
- `scripts/GUI/romanOS-ControlCenter.ps1`
- `Auditoria-GUIs-romanOS.html`
- `docs/plans/README.md`

---

## 1. Contexto y Diagnóstico

`romanOS Control Center` reúne más de 100 herramientas y conmutadores de bajo nivel que interactúan directamente con el kernel de Windows, subsistemas de red, registros de mantenimiento DISM, instantáneas VSS, mitigaciones de seguridad y afinidad de interrupciones de hardware.  
Si bien algunos botones son autoexplicativos (como "Examinar", "Limpiar Consola" o "Cancelar"), los botones técnicos más avanzados carecen de contexto inmediato. Esto puede generar incertidumbre en usuarios comunes o jugadores competitivos sobre el impacto real, la reversibilidad o el propósito de cada función.

El usuario ha solicitado formalmente dotar a los **botones complejos y de alto impacto** de mensajes contextuales claros y educativos mediante el atributo nativo de WPF `ToolTip`, **sin saturar** botones triviales.

---

## 2. Criterios de Diseño UX y Selección de Botones

1. **Principio de Cero Ruido (Zero Clutter):**
   - No añadir ToolTips a botones obvios o estándar de interfaz (`btnClearConsole`, `btnCancelProcess`, botones de navegación elemental).
2. **Claridad Técnica y Desmitificación:**
   - Explicar qué hace la función en lenguaje claro pero técnicamente riguroso.
   - Indicar explícitamente si la acción es de Solo Lectura, si es reversible o si preserva compatibilidad con Anti-Cheats y periféricos.
3. **Pestañas y Botones a Enriquecer:**
   - **Pestaña Mantenimiento:**
     - `btnInspectDismCatalog`: Catálogo canónico de componentes DISM (SSOT).
     - `btnCreateVssPoint`: Crear punto de restauración VSS nativo.
     - `btnRestoreSnapshotGUI`: Reversión atómica de instantáneas de configuración.
     - `btnAuditDriftGUI`: Detección de reactivación indebida de telemetría y servicios.
     - `btnRemediateDriftGUI`: Remediación en 1-clic de servicios desviados.
     - `btnInstallDriftTaskGUI`: Instalación del centinela programado anti-desvío.
   - **Pestaña Red & Latencia:**
     - `btnOptimizeLatency`: Optimización de pila NDIS, ECN y buffers para baja latencia.
     - `btnDnsBenchmark`: Comparador en vivo de latencia contra resolvers seguros.
     - `btnRevertNetwork`: Restauración completa de TCP/IP y adaptadores a defaults oficiales.
   - **Pestaña Seguridad & Navegadores:**
     - `btnToggleVBS`: Seguridad basada en virtualización (VBS / HVCI).
     - `btnHardeningASR`: Reglas oficiales de reducción de superficie de ataque (ASR).
     - `btnRunAsPPL`: Blindaje de credenciales LSASS (RunAsPPL).
     - `btnDriverBlocklist`: Lista de bloqueo de controladores vulnerables de Microsoft.
   - **Pestaña Constructor Desatendido:**
     - `btnGenerateUnattendPreview`: Generador dinámico de autounattend.xml.
     - `btnValidateUnattendGUI`: Validador formal de sintaxis y bypasses contra esquema.
     - `btnExportUnattendFile`: Exportador físico a medios de instalación USB/ISO.

---

## 3. Fases de Ejecución

- [x] **Fase 1: Auditoría e Inyección de ToolTips en XAML (`romanOS-ControlCenter.ps1`)**
  - Identificar botones complejos en las secciones de Mantenimiento, Red, Seguridad y Constructor.
  - Insertar cadenas informativas concisas y precisas en el atributo `ToolTip`.
- [x] **Fase 2: Certificación de Integridad y Runtime**
  - Validar compatibilidad contra Windows PowerShell 5.1 (`powershell.exe -WhatIf`).
  - Asegurar codificación estricta UTF-8 con BOM (`0xEF, 0xBB, 0xBF`).
  - Ejecutar el arnés `Test-GuiIntegrityAndFunctionality.ps1` (118 botones).
- [x] **Fase 3: Documentación y Commit Atómico**
  - Actualizar `docs/plans/README.md` y `Auditoria-GUIs-romanOS.html`.
  - Registrar commit atómico descriptivo.
