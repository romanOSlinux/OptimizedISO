# PLAN-0143: Erradicación Sistémica de Fallos Silenciosos, Principio Fail-Fast, Logging de Arranque Inmediato y Barrera de Aserción de Contratos en Configuraciones Críticas

**Fecha:** 2026-09-28  
**Autor:** Antigravity (AI Assistant) & romanOS Team  
**Rama:** `feature/offline-ui-tweaks`  
**Estado:** COMPLETADO  
**Subordinado a:** `.agents/GOVERNANCE-MATRIX.md` (Fases DEFINE → BUILD → VERIFY → SHIP) y `.agents/AGENTS.md` (Reglas 0, 4, 7, 8, 10, 11, 13)

---

## 1. Contexto Forense y Problema Sistémico (CWE-390 / Silent Fallback)

Durante la validación en vivo de una imagen ISO generada mediante `romanOS-Studio.ps1`, se detectó que el instalador de Windows solicitó interactivamente la aceptación de términos (EULA) y la selección manual de disco/partición, a pesar de que el usuario había seleccionado explícitamente la casilla `Zero-Touch` en la GUI.

La investigación forense en el código y en los registros de compilación reveló una concatenación de 4 defectos arquitectónicos críticos:

1. **Invocación Prematura de Funciones (Anti-Hoisting en PowerShell):**
   * En `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`, la llamada `Import-BuildPreset -PresetPath $PresetFile` se ejecutaba en la **línea 334**, mientras que la función `function Import-BuildPreset` estaba definida en la **línea 1557**.
   * En PowerShell, las funciones no sufren "hoisting". La llamada arrojó `CommandNotFoundException`.
2. **Zona Ciega de Logging (Pre-Log Blindspot):**
   * El sistema de registro en disco (`Initialize-Log` y `Start-Transcript`) comenzaba en la **línea 4458**.
   * Cualquier excepción, error sintáctico o fallo producido entre las líneas 1 y 4457 se perdió completamente en memoria volátil sin registrarse en `ISO_Build_*.log` ni en `ISO_Build_*_transcript.log`.
3. **Degradación Silenciosa a Valores por Defecto (Silent Fallback):**
   * Al fallar la llamada a `Import-BuildPreset`, el script no abortó ni notificó un error visible. Simplemente continuó la ejecución utilizando valores por defecto (`ZeroTouch = $false`).
   * El log registró falsamente como exitoso: `[OK] Pre-selección de índice inyectada en autounattend.xml (Índice: 1)` con `(selección manual de disco)`.
4. **Ausencia de Barreras de Aserción de Contratos (Post-Condition Assertions):**
   * No existía ninguna validación de coherencia que certificara: *"Si el usuario o el preset requirió ZeroTouch, ¿el XML resultante tiene efectivamente los nodos de particionado automático UEFI/GPT y EULA?"*.

---

## 2. Objetivos del Plan

1. **Pilar 1 — Reorganización y Hoisting Zero:**
   * Reubicar todas las definiciones de funciones de soporte de configuración (`Import-BuildPreset`, `Export-BuildPreset`, logging auxiliar) antes de cualquier bloque de código procedural que las consuma.
   * Ejecutar un escaneo estático exhaustivo mediante AST de PowerShell sobre el 100% de los scripts del repositorio para asegurar que ninguna función sea llamada antes de su definición.
2. **Pilar 2 — Principio Fail-Fast / Fail-Visible en Carga de Configuraciones:**
   * Toda lectura de presets (`-PresetFile`), perfiles o configuraciones debe contar con validación estricta. Si el archivo especificado no existe, no puede ser deserializado o falla al inyectar parámetros, el script DEBE arrojar un error fatal inmediato (`throw` / `exit 1` visible), prohibiendo taxativamente continuar en modo degradado sin autorización explícita.
3. **Pilar 3 — Eliminación de Zonas Ciegas de Logging (Early Boot Logging):**
   * Inicializar el registro de transcripción y log estructurado al inicio inmediato de los scripts constructores y orquestadores (`New-OptimizedWindowsISO-v2.ps1`), asegurando que cada línea desde el segundo 0 quede registrada.
4. **Pilar 4 — Barrera de Aserción y Contratos de Integridad (`Assert-BuildIntegrityContracts`):**
   * Implementar un cerrojo de validación antes de la compilación de la ISO: si los parámetros resueltos indican `ZeroTouch = $true`, certificar empíricamente en el DOM del XML la existencia de `<DiskConfiguration>`, `<WillWipeDisk>true</WillWipeDisk>`, `<AcceptEula>true</AcceptEula>` e `<InstallTo>`. Si hay discrepancia, abortar la compilación de inmediato con alarma crítica.
5. **Pilar 5 — Cobertura de Pruebas Unitarias y Certificación Windows PowerShell 5.1:**
   * Crear pruebas en `scripts/Testing/Test-OptimizedISO-v2.ps1` que validen:
     - Carga exitosa de preset con flags ZeroTouch.
     - Detección y terminación obligatoria ante presets inválidos o corruptos.
     - Verificación del contrato de aserción `Assert-BuildIntegrityContracts`.
   * Certificar en frío contra `powershell.exe -STA -NoProfile 5.1` y codificación UTF-8 con BOM.

---

## 3. Matriz de Componentes a Intervenir

| Componente | Ruta | Acción Requerida |
|---|---|---|
| Builder Principal | `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` | Reubicar `Import-BuildPreset`/`Export-BuildPreset`, inicializar log temprano, implementar Fail-Fast en `-PresetFile`, agregar `Assert-BuildIntegrityContracts`. |
| romanOS Studio | `scripts/GUI/romanOS-Studio.ps1` | Validar pre-vuelo de JSON generado, capturar salida temprana del subproceso con alerta visual en fallo. |
| Test Harness | `scripts/Testing/Test-OptimizedISO-v2.ps1` | Incorporar pruebas de contrato para carga de preset, Fail-Fast y validación de XML Zero-Touch. |
| Repositorio Completo | `scripts/` (Todos los scripts .ps1) | Auditoría AST de orden de llamadas vs definiciones (Anti-Hoisting). |

---

## 4. Fases de Ejecución

### Fase 1: Auditoría AST Repo-Wide de Orden de Funciones
- Ejecutar script de análisis AST sobre todos los archivos `.ps1` y `.psm1` del repositorio.
- Identificar y documentar todas las instancias de funciones llamadas antes de su definición física.

### Fase 2: Refactorización y Blindaje de `New-OptimizedWindowsISO-v2.ps1`
- Mover `Import-BuildPreset` y `Export-BuildPreset` a la sección superior de funciones de configuración.
- Implementar Fail-Fast: si `-PresetFile` falla o no se puede cargar, abortar con excepción descriptiva visible.
- Mover `Initialize-Log` y `Start-Transcript` al arranque temprano para eliminar la zona ciega.
- Añadir la función de aserción `Assert-BuildIntegrityContracts` antes del paso `[6/6] Reconstruyendo ISO`.

### Fase 3: Blindaje en Cascada de romanOS Studio y GUIs
- Asegurar que `romanOS-Studio.ps1` valide la existencia del archivo JSON antes de invocar el subproceso.
- Comprobar que los errores tempranos del subproceso no sean ignorados.

### Fase 4: Pruebas Unitarias y Certificación en Windows PowerShell 5.1
- Ejecutar la suite de pruebas unitarias (`Test-OptimizedISO-v2.ps1`).
- Validar compatibilidad en frío en PowerShell 5.1.
- Verificar ausencia de regresiones (617+ tests unitarios).

---

## 5. Criterios de Aceptación y Certificación

1. **Cero Invocaciones Prematuras:** El parser AST confirma que no existen llamadas a funciones antes de su declaración en los scripts de construcción.
2. **Fail-Fast Comprobado:** Invocar el builder con un `-PresetFile` erróneo genera un error terminal inmediato con código de salida no-cero.
3. **Cero Zonas Ciegas:** El log transcript registra el inicio del script y la carga de parámetros desde el segundo inicial.
4. **Contrato Zero-Touch Blindado:** Si se pasa un preset con `ZeroTouch: true`, el XML resultante obligatoriamente posee particionado UEFI/GPT y EULA aceptado, validado por aserción cruzada.
5. **100% Tests Pass:** Todos los tests de la suite pasan en Windows PowerShell 5.1 y Git se mantiene limpio y sincronizado.

---

## 6. Resultados y Certificación Empírica

* **Auditoría AST Repo-Wide de Invocaciones Prematuras (Anti-Hoisting):**
  - Scripts analizados: 100% de los archivos `.ps1` y `.psm1` en `scripts/`.
  - Invocaciones inmediatas en nivel raíz (Root Level): **0**
  - Invocaciones internas en funciones no declaradas: **0**
* **Certificación Windows PowerShell 5.1 (`powershell.exe -STA -NoProfile`):**
  - `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`: 0 errores de parser AST (BOM: True)
  - `scripts/Core/UI-Engine.ps1`: 0 errores de parser AST (BOM: True)
  - `scripts/GUI/romanOS-Studio.ps1`: 0 errores de parser AST (BOM: True)
  - `scripts/GUI/romanOS-ControlCenter.ps1`: 0 errores de parser AST (BOM: True)
  - `scripts/Host-Tools/Get-OfficialWindowsISO.ps1`: 0 errores de parser AST (BOM: True)
  - `scripts/Modules/Optimize-InterruptAffinity.ps1`: 0 errores de parser AST (BOM: True)
  - `scripts/Testing/Test-OptimizedISO-v2.ps1`: 0 errores de parser AST (BOM: True)
* **Suite de Pruebas Unitarias e Integración (`Test-OptimizedISO-v2.ps1`):**
  - Total de Pruebas: **630**
  - PASS: **630 (100%)**
  - FAIL: **0**
  - SKIP: **0**
  - Cobertura FASE 2Y: Verificación de Fail-Fast en presets inexistentes y corruptos, inyección de parámetros ZeroTouch y contrato de integridad `Assert-BuildIntegrityContracts`.
