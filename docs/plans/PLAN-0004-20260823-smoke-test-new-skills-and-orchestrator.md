# Plan PLAN-0004: Prueba de Humo y Verificación Funcional de Nuevas Skills y Orquestador

| Campo | Valor |
|---|---|
| **ID** | PLAN-0004 |
| **Fecha** | 2026-08-23 |
| **Estado** | COMPLETADO |
| **Autor** | Antigravity (agente IA) |
| **Conversación origen** | 4238aead-ce25-4f5e-a592-77c15229c8a5 |

---

## 1. Contexto y Objetivos

Este plan define una **prueba de humo (*Smoke Test*) funcional, 100% no destructiva y de corta duración (< 1 minuto)** para verificar empíricamente el comportamiento en vivo de los componentes desarrollados en el PLAN-0003:

1. **Validación del Orquestador Maestro:** Verificar la ejecución coordinada y la generación de reportes consolidados en `Log/` mediante [`Invoke-TestSuite.ps1`](file:///c:/OptimizedISO/scripts/Invoke-TestSuite.ps1).
2. **Validación de Helpers de Skills Especializadas:** Comprobar la respuesta en tiempo real de los scripts de soporte:
   - Validador XML de despliegue desatendido (`Test-UnattendXml.ps1`).
   - Auditor de seguridad gaming-safe y anti-cheats (`Test-HardeningSafety.ps1`).
   - Validador de árbol de servicing de actualizaciones (`Test-UpdatesTree.ps1`).

---

## 2. Metodología y Entorno de Ejecución

- **Runtime de Destino:** Windows PowerShell 5.1 nativo (`$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe`).
- **Seguridad:** Todas las pruebas son de **solo lectura / diagnóstico simulado**. No alteran configuraciones del sistema, no compilan ISOs ni modifican el registro.
- **Salida:** Reportes estructurados en consola con colores ANSI y generación automática de logs Markdown.

---

## 3. Matriz de Pruebas a Realizar

### Prueba 1: Orquestador Maestro de Pruebas (Modo Rápido)
- **Comando:**
  ```powershell
  & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -File "scripts/Invoke-TestSuite.ps1" -Quick
  ```
- **Qué valida:**
  - Carga del motor visual [`scripts/Core/UI-Engine.ps1`](file:///c:/OptimizedISO/scripts/Core/UI-Engine.ps1) (banners, box-drawing, summary).
  - Ejecución en serie de 4 fases de auditoría (AST/BOM de 23 scripts, XML, ADK/DISM y Git).
  - Creación del archivo consolidado `Log/TestSuite_Consolidated_YYYYMMDD_HHmmss.md`.

### Prueba 2: Auditor de Despliegue Desatendido XML
- **Comando:**
  ```powershell
  & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -File ".agents/skills/unattended-deployment/scripts/Test-UnattendXml.ps1"
  ```
- **Qué valida:**
  - Parseo con `[System.Xml.XmlDocument]` de la plantilla embebida en `New-OptimizedWindowsISO-v2.ps1`.
  - Verificación de pases `windowsPE`, `specialize` y `oobeSystem`.
  - Verificación de ausencia de etiquetas deprecadas (como `<WillContinueOnFailure>`).

### Prueba 3: Auditor de Seguridad Gaming-Safe y Anti-Cheats
- **Comando:**
  ```powershell
  & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -File ".agents/skills/iso-security-hardening/scripts/Test-HardeningSafety.ps1"
  ```
- **Qué valida:**
  - Consulta en tiempo real de directivas de seguridad del host (LSA RunAsPPL, SMBv1, LLMNR).
  - Evaluación contra la matriz de compatibilidad de EasyAntiCheat, BattlEye, Vanguard y FACEIT.

### Prueba 4: Validador de Árbol de Windows Updates (Servicing)
- **Comando:**
  ```powershell
  & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -File ".agents/skills/windows-updates-servicing/scripts/Test-UpdatesTree.ps1" -UpdatesPath "C:\OptimizedISO\Updates"
  ```
- **Qué valida:**
  - Manejo seguro de directorios y ordenamiento de paquetes DISM (SSU -> Checkpoint -> LCU -> .NET -> SafeOS).

---

## 4. Criterios de Éxito

| Criterio | Métrica Esperada |
| :--- | :---: |
| **Tiempo de Ejecución Total** | **< 15 segundos** |
| **Errores Sintácticos / Excepciones** | **0 Errores** |
| **Estado Global del Orquestador** | **SUCCESS ✅ (100% PASS)** |
| **Generación de Reportes** | **Archivo Markdown creado en `Log/`** |
