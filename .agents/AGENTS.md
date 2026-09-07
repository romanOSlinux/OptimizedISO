# Reglas Estrictas del Agente (.agents/AGENTS.md)

Las siguientes reglas son de cumplimiento obligatorio e incondicional para cualquier agente que trabaje en este proyecto.

## 0. Git como Fuente de Verdad y Trazabilidad Obligatoria
- **Paso Cero Obligatorio:** Antes de proponer o modificar cualquier archivo, el agente DEBE ejecutar e inspeccionar:
  1. `git status`: Verificar cambios pendientes, archivos modificados o archivos no rastreados (*untracked*).
  2. `git log -n 5 --oneline`: Conocer el historial reciente, el commit funcional base y el estado de la rama actual.
  3. `git diff`: Inspeccionar detalladamente los cambios en curso antes de realizar ediciones adicionales.
- **Trazabilidad y Detección de Regresiones:** Cuando una prueba falle o un script arroje error, utilizar siempre `git diff` o comparar con el último commit estable para aislar la causa raíz con exactitud matemática en lugar de adivinar o rehacer código desde cero.
- **Commits Atómicos tras Validación:** Tras completar y verificar empíricamente cada hito, corrección o refactorización, registrar un commit atómico y descriptivo.
- **Rollback Seguro:** En caso de regresión crítica o fallo irreparable en una prueba, realizar rollback inmediato con herramientas de Git (`git restore`, `git checkout` o `git revert`) para retornar al último estado seguro conocido.

## 1. Conciencia Estricta del Entorno (Windows vs. Linux Host)
- **Detección Automática del Host:**
  - **Si el Host es Windows (`$IsWindows = $true` o entorno Windows):** Utilizar PowerShell nativo (5.1 / 7+), DISM (`dism.exe`), Windows ADK (`oscdimg.exe`), y cmdlets nativos de Hyper-V para pruebas de compilación y validación en vivo.
  - **Si el Host es Linux (ej. Arch Linux):** Recordar que el entorno de destino es Windows. No ejecutar comandos nativos de DISM/oscdimg directamente en bash sin aclarar que requieren una máquina virtual o el entorno Windows. Ofrecer alternativas como `wimlib-imagex` o `xorriso` solo si se solicita trabajar desde Linux.

## 2. Verificación e Investigación Rigurosa (Cero Suposiciones)
- **Prohibido afirmar certeza absoluta sin prueba:** Nunca declarar que un script, archivo XML o configuración está "100% verificado", "sin errores" o "listo para producción" basándose únicamente en una inspección estática o lectura visual.
- **Investigación activa requerida:** Antes de asegurar que una clave de registro, un flag de línea de comandos (ej. oscdimg, dism) o un parámetro XML funciona en una versión específica de Windows (ej. Windows 11 24H2/25H2), se debe investigar en fuentes oficiales de Microsoft o documentación técnica de la comunidad.
- **Transparencia en las limitaciones:** Indicar siempre de forma transparente qué partes del código han sido comprobadas empíricamente y cuáles son análisis teóricos sujetos a validación en tiempo de ejecución.

## 3. Protocolo de Auditoría y Corrección de Código
- **Un intento informado y fundamentado:** Entender el contexto completo y las fuentes antes de realizar cambios de código.
- **Explicidad de cambios:** Al realizar correcciones, detallar exactamente qué problema técnico resuelve cada modificación y en qué documento/fuente oficial se fundamenta.

## 4. Estandarización de Codificación y Validación en Windows PowerShell 5.1
- **Codificación Obligatoria UTF-8 con BOM (`UTF-8-BOM`):** Todo script de PowerShell (`.ps1`, `.psm1`, `.psd1`) DEBE ser creado y guardado estrictamente en formato UTF-8 con BOM (`0xEF, 0xBB, 0xBF`). Está estrictamente prohibido guardar scripts en UTF-8 sin BOM (UTF-8 puro), ya que Windows PowerShell 5.1 (`powershell.exe`) cae por defecto en la página de códigos ANSI del sistema (Windows-1252), provocando colapso de comillas y errores fatales de sintaxis ante caracteres especiales, acentos o emojis.
- **Validación Obligatoria en el Runtime de Destino (Windows PowerShell 5.1):**
  1. Está terminantemente prohibido asumir que un script funciona solo porque el parser AST de PowerShell 7 (`pwsh`) no arroja errores.
  2. Todo script nuevo o modificado DEBE ser probado en frío directamente contra el ejecutable de destino de Windows:
     `& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'ruta\script.ps1' -WhatIf }"`
  3. Comprobar explícitamente que la salida no contenga errores de `ParserError`, `ParseException` ni excepciones de caracteres/comillas antes de reportar éxito al usuario.
- **Soporte Gráfico STA Obligatorio en Lanzadores:** Todo comando batch (`.cmd`), tarea programada o acceso directo que invoque un script de PowerShell con interfaz gráfica o `Out-GridView` DEBE incluir explícitamente el flag `-STA`.

## 5. Trazabilidad de Planes de Implementación
- **Almacenamiento Obligatorio en el Repositorio:** Todo plan de implementación generado para este proyecto DEBE guardarse en `docs/plans/` con el formato de nombre `PLAN-<NNNN>-<YYYYMMDD>-<slug>.md`.
- **Registro en el Índice:** Cada plan nuevo DEBE ser registrado en `docs/plans/README.md` con su número correlativo, fecha, título y estado.
- **Convención de Estados:** `PENDIENTE` → `EN PROGRESO` → `COMPLETADO` / `CANCELADO`. El estado debe actualizarse cuando cambie.
- **Commit atómico:** Los planes deben commitearse junto con el commit del hito al que pertenecen, o en un commit separado `docs(plans): agregar PLAN-NNNN ...` si son previos a la implementación.
- **Nunca dejar planes solo en artifacts de conversación:** Los artifacts de sesión son efímeros. El repositorio Git es la única fuente de verdad para los planes.

## 6. Naturaleza del Repositorio: Entorno de Desarrollo y Autoría de Código
- **Propósito Exclusivo:** Este repositorio es un espacio de **desarrollo, ingeniería de software, autoría de scripts y documentación**. NO es un entorno de producción masiva ni un almacén de artefactos binarios.
- **Prohibición de Binarios Pesados en Git:** Está terminantemente prohibido añadir al control de versiones de Git (`git add`) archivos binarios pesados, tales como imágenes ISO (`.iso`), imágenes WIM (`.wim`, `.esd`), paquetes de actualización de Windows (`.msu`, `.cab`), instaladores de runtimes redistribuibles (`vc_redist*.exe`, `DirectX/`), discos virtuales (`.vhd`, `.vhdx`) o carpetas temporales de prueba (`pruebadeblot/`).
- **Higiene Automática de `.gitignore`:** Ante cualquier nueva herramienta o script que descargue artefactos pesados en tiempo de ejecución, el agente DEBE asegurar que las rutas de descarga queden explícitamente ignoradas en `.gitignore`.
- **Commits y Push Periódicos:** Mantener sincronizado el repositorio con el remoto (`origin`) mediante commits atómicos y limpios exclusivamente de código fuente (`.ps1`, `.cmd`, `.xml`), documentación (`.md`) y configuración.

## 7. Transparencia y Notificación Obligatoria de Pruebas y Tareas en Segundo Plano
- **Aviso de Inicio Obligatorio:** Antes de lanzar cualquier prueba unitaria, suite de pruebas (`Invoke-TestSuite.ps1`, `Test-OptimizedISO-v2.ps1`), comando de larga duración o tarea en segundo plano, el agente DEBE emitir un mensaje breve y visible al usuario indicando:
  `⏳ Iniciando prueba / tarea: [Nombre del test o script]...`
- **Aviso de Finalización Obligatorio:** Tan pronto como la prueba o comando concluya, el agente DEBE notificar su finalización y el resultado obtenido:
  `✅ Prueba finalizada: [Nombre del test o script] — Resultado: [PASS / FAIL / Métricas].`
- **Cero Tareas Fantasma:** Está prohibido dejar tareas en segundo plano corriendo sin supervisión o sin que el usuario esté informado de su ejecución y término.

## 8. Prohibición Estricta de Auto-Run / Ejecución Prematura de Planes
- **Consentimiento Explícito e Incondicional:** Está terminantemente prohibido ejecutar acciones modificatorias, ediciones de código o comandos destructivos tras la redacción o actualización de un plan de implementación (`PLAN-*.md` o `implementation_plan.md`), incluso si el sistema de la plataforma emite eventos de aprobación automática de artefactos (`always-proceed`).
- **Parada Obligatoria y Espera de Confirmación:** Tras generar o actualizar un plan, el agente DEBE detenerse inmediatamente, presentar un resumen al usuario y esperar una orden expresa y afirmativa en el chat (ej. *"procede"*, *"adelante"*, *"aprobado"*) antes de ejecutar cualquier cambio en el código fuente.
- **Configuración Preventiva de Metadatos:** Al generar artefactos de tipo plan (`implementation_plan.md`), el agente no debe asumir que el hook del sistema sustituye la decisión del usuario; la confirmación humana en el chat prevalece sobre cualquier política automática de la plataforma.

## 9. Arquitectura Unificada y Ecosistema Integral (SSOT)
- **Fuente Única de Verdad (Single Source of Truth):** Toda directiva de optimización, clave de registro de GPO, bypass o política de sistema compartida entre la ISO, el Debloat, el Toolkit y los diagnósticos DEBE residir canónicamente en `scripts/Core/Policy-Engine.ps1`.
- **Prohibición de Directivas Huérfanas y Duplicadas:** Está estrictamente prohibido introducir strings hardcodeados o listas duplicadas de políticas en scripts consumidores (`SetupComplete.cmd`, `autounattend.xml`, `Win11-Debloat-v3-Adaptive.ps1`, `PostInstall-Diagnostics.ps1`). Cualquier directiva debe registrarse en `Policy-Engine.ps1` y exportarse o consultarse mediante las funciones canónicas (`Get-RomanOSPolicies`, `Export-RomanOSUnattendCommands`, `Get-RomanOSBrowserPolicies`, `Export-RomanOSBrowserCommands`, `Apply-RomanOSBrowserPolicies`).
- **Inyección Física en la ISO:** La carpeta `scripts/Core/` debe ser inyectada físicamente en `$OEM$\$$\Setup\Scripts\Core` y en el WIM montado para que el ecosistema completo opere con paridad total en el sistema de destino.


## 10. Mantenimiento en Cascada y Paridad del Ecosistema (Docs-as-Code)
- **Cero Desvío de Configuración (Configuration Drift):** Ante cualquier cambio arquitectónico, como renombrar un script, cambiar una ruta de directorio, o agregar una nueva directiva de optimización, el agente DEBE obligatoriamente realizar una actualización en cascada de todo el ecosistema.
- **Auditoría de Impacto Obligatoria:** Se debe ejecutar grep_search para buscar referencias obsoletas (hardcodeadas) en otros scripts consumidores y corregirlas en el mismo commit atómico.
- **Actualización Documental Simultánea:** La documentación (README.md, optimizediso, guías de uso, comandos de PowerShell) debe tratarse como código (*Docs-as-Code*). Si una ruta cambia, las instrucciones de la guía de usuario deben ser probadas mentalmente y actualizadas para garantizar que los comandos "copiar y pegar" sigan funcionando perfectamente para el usuario final.

## 11. Autonomía y Autoridad en Decisiones Técnicas Base (Ingeniero de Software)
- **El Agente es un Ingeniero Autónomo:** Ante problemas de arquitectura, ingeniería de hardware, registro del sistema (regedit) o modificaciones de bajo nivel, el agente asume el rol de Ingeniero de Software.
- **Prohibido Delegar Responsabilidad Técnica:** El agente tiene estrictamente prohibido devolver la pregunta al usuario (ej. *"¿Qué prefieres hacer?"*) frente a decisiones técnicas estructurales (como asignación de memoria, offsets, HAGS vs UMA, interrupciones MSI, etc.).
- **Datos Empíricos y Resolución:** El agente debe investigar en documentación oficial (Microsoft, AMD, Intel, WDDM), presentar al usuario los datos objetivos (Pros, Contras, Fundamento Técnico) y **tomar o proponer la decisión técnica base fundamentada**.
- **Excepciones Estéticas:** La delegación de decisiones e interacción con el usuario queda reservada única y exclusivamente para preferencias estéticas, diseño (colores, formas), experiencia de usuario (UI/UX) o selección de paquetes de software opcionales.
