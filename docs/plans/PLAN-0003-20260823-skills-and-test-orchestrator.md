# Plan PLAN-0003: Expansión de Skills Especializadas, Orquestador Maestro de Pruebas y Hooks de Ciclo de Vida

| Campo | Valor |
|---|---|
| **ID** | PLAN-0003 |
| **Fecha** | 2026-08-23 |
| **Estado** | COMPLETADO |
| **Autor** | Antigravity (agente IA) |
| **Conversación origen** | 4238aead-ce25-4f5e-a592-77c15229c8a5 |

---

## 1. Contexto y Objetivos

A partir de los resultados empíricos de la batería de pruebas y las directrices de la arquitectura oficial de **Antigravity Customizations** (`agy-customizations`), este plan tiene como objetivo:

1. **Unificar la Ejecución de Pruebas:** Crear un **Orquestador Maestro de Pruebas** (`scripts/Invoke-TestSuite.ps1` / `.cmd`) que ejecute en un solo comando y reporte de forma estructurada todas las suites del proyecto (AST/BOM, Test Harness ISO v2, Diagnóstico ADK/Hyper-V, Higiene Git y Validación XML).
2. **Expandir el Ecosistema de Skills Modulares:** Crear 3 skills especializadas con divulgación progresiva, *triggers* en 3ª persona, scripts helpers ejecutables y referencias técnicas:
   - **`windows-updates-servicing`:** Manejo estricto de dependencias DISM, slipstreaming de parches, SSUs y Checkpoints (KB5043080).
   - **`unattended-deployment`:** Validación de esquemas XML, particionado UEFI GPT con WinRE de 500 MB y personalización OOBE desatendida.
   - **`iso-security-hardening`:** Auditoría de seguridad desacoplada, reglas Defender ASR, LSA RunAsPPL y políticas gaming-safe con compatibilidad certificada para anti-cheats (EasyAntiCheat, BattlEye, Vanguard).
3. **Automatización con Hooks de Ciclo de Vida (`.agents/hooks.json`):** Automatizar revisiones pre-commit y pre-ejecución para evitar errores de codificación y prevenir rastreo de binarios pesados.

---

## 2. Decisiones de Arquitectura y Estándares Técnicos

1. **Codificación Estricta:** Todo script nuevo de PowerShell (`.ps1`) se creará en formato **UTF-8 con BOM** (`0xEF, 0xBB, 0xBF`) y será probado en frío en **Windows PowerShell 5.1** (`powershell.exe`).
2. **Divulgación Progresiva:** Cada `SKILL.md` mantendrá un tamaño compacto (<70 líneas) conteniendo solo el procedimiento clave, mientras que matrices complejas residirán en `references/`.
3. **Helpers Deterministas:** Cada skill incluirá un script `.ps1` en `scripts/` que devuelva resultados booleanos o códigos de salida (`0` / `1`), permitiendo al agente verificar código con consumo mínimo de tokens.

---

## 3. Matriz de Componentes y Archivos

### A. Orquestador Maestro de Pruebas
- **[NEW] [`scripts/Invoke-TestSuite.ps1`](file:///c:/OptimizedISO/scripts/Invoke-TestSuite.ps1):** Script que corre en secuencia y consolida:
  1. AST Parser y Codificación UTF-8 BOM en todos los scripts (`Test-ScriptAstAndBom.ps1`).
  2. Test Harness Unitario y de Integración ISO v2 (`Test-OptimizedISO-v2.ps1`).
  3. Diagnóstico de herramientas ADK, DISM, Hyper-V y Espacio (`Test-AdkEnvironment.ps1`).
  4. Auditoría de Higiene y Trazabilidad Git (`Test-GitWorkspaceHygiene.ps1`).
  5. Validador de Esquemas XML (`Test-UnattendXml.ps1`).
- **[NEW] [`scripts/Invoke-TestSuite.cmd`](file:///c:/OptimizedISO/scripts/Invoke-TestSuite.cmd):** Lanzador batch con flag `-STA` para ejecución directa en Windows con doble clic.

### B. Skill: `windows-updates-servicing`
- **[NEW] [`.agents/skills/windows-updates-servicing/SKILL.md`](file:///c:/OptimizedISO/.agents/skills/windows-updates-servicing/SKILL.md):** Frontmatter con triggers de servicing, slipstreaming, parches MSU/CAB y ordenamiento DISM.
- **[NEW] [`.agents/skills/windows-updates-servicing/scripts/Test-UpdatesTree.ps1`](file:///c:/OptimizedISO/.agents/skills/windows-updates-servicing/scripts/Test-UpdatesTree.ps1):** Helper para validar integridad Authenticode y hashes SHA-256 de paquetes `.msu` en el directorio de updates.
- **[NEW] [`.agents/skills/windows-updates-servicing/references/servicing-kb-matrix.md`](file:///c:/OptimizedISO/.agents/skills/windows-updates-servicing/references/servicing-kb-matrix.md):** Matriz oficial de ordenamiento de inyección DISM (SSU -> Checkpoint Base -> LCU -> .NET -> SafeOS).

### C. Skill: `unattended-deployment`
- **[NEW] [`.agents/skills/unattended-deployment/SKILL.md`](file:///c:/OptimizedISO/.agents/skills/unattended-deployment/SKILL.md):** Frontmatter con triggers de autounattend.xml, particionado UEFI GPT y OOBE.
- **[NEW] [`.agents/skills/unattended-deployment/scripts/Test-UnattendXml.ps1`](file:///c:/OptimizedISO/.agents/skills/unattended-deployment/scripts/Test-UnattendXml.ps1):** Helper para validar sintaxis XML, namespaces `xmlns:wcm` y particionado GPT (WinRE 500 MB TypeID `de94bba4...`).
- **[NEW] [`.agents/skills/unattended-deployment/references/uefi-gpt-unattend-schema.md`](file:///c:/OptimizedISO/.agents/skills/unattended-deployment/references/uefi-gpt-unattend-schema.md):** Plantillas de referencia canónicas de `autounattend.xml` según Microsoft Learn.

### D. Skill: `iso-security-hardening`
- **[NEW] [`.agents/skills/iso-security-hardening/SKILL.md`](file:///c:/OptimizedISO/.agents/skills/iso-security-hardening/SKILL.md):** Frontmatter con triggers de hardening desacoplado, reglas Defender ASR y seguridad de red.
- **[NEW] [`.agents/skills/iso-security-hardening/scripts/Test-HardeningSafety.ps1`](file:///c:/OptimizedISO/.agents/skills/iso-security-hardening/scripts/Test-HardeningSafety.ps1):** Helper que audita claves de registro para verificar compatibilidad con anti-cheats.
- **[NEW] [`.agents/skills/iso-security-hardening/references/anticheat-compatibility-matrix.md`](file:///c:/OptimizedISO/.agents/skills/iso-security-hardening/references/anticheat-compatibility-matrix.md):** Matriz técnica de directivas de seguridad seguras vs. riesgosas para juegos online.

### E. Hooks de Ciclo de Vida
- **[NEW] [`.agents/hooks.json`](file:///c:/OptimizedISO/.agents/hooks.json):** Configuración de hooks para validación automática de scripts e higiene Git.

### F. Documentación y Trazabilidad
- **[MODIFY] [`docs/plans/README.md`](file:///c:/OptimizedISO/docs/plans/README.md):** Registro de PLAN-0003 en el índice.
- **[NEW] [`docs/plans/PLAN-0003-20260823-skills-and-test-orchestrator.md`](file:///c:/OptimizedISO/docs/plans/PLAN-0003-20260823-skills-and-test-orchestrator.md):** Persistencia obligatoria en Git.
- **[MODIFY] [`docs/GUIA_DE_EJECUCION_Y_COMANDOS.md`](file:///c:/OptimizedISO/docs/GUIA_DE_EJECUCION_Y_COMANDOS.md):** Incorporación del nuevo comando `Invoke-TestSuite.ps1` / `.cmd`.

---

## 4. Plan de Verificación Empírica

1. **Auditoría AST y BOM en Windows PowerShell 5.1:**
   ```powershell
   & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -File ".agents/skills/powershell-windows/scripts/Test-ScriptAstAndBom.ps1"
   ```
   *Criterio de éxito:* 100% PASS en todos los scripts nuevos y modificados.

2. **Ejecución del Orquestador Maestro:**
   ```powershell
   & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -File "scripts/Invoke-TestSuite.ps1"
   ```
   *Criterio de éxito:* Ejecución completa de las 5 fases con 0 errores y generación de `Log/TestSuite_Consolidated.md`.

3. **Auditoría de Higiene Git y Trazabilidad:**
   ```powershell
   git status
   & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -File ".agents/skills/git-workflow/scripts/Test-GitWorkspaceHygiene.ps1"
   ```
   *Criterio de éxito:* Cero binarios pesados rastreados y commits atómicos limpios.
