# Reglas Estrictas del Agente (.agents/AGENTS.md)

> **MARCO DE GOBERNANZA OPERATIVA VINCULANTE (Agentic OS):**  
> Todo flujo de trabajo en este repositorio está subordinado a la **Matriz Maestra de Gobernanza Operativa**: [`.agents/GOVERNANCE-MATRIX.md`](GOVERNANCE-MATRIX.md).  
> El agente debe clasificar cada tarea en su fase del ciclo de vida (`DEFINE` → `PLAN` → `BUILD` → `VERIFY` → `REVIEW` → `SHIP`) y activar los Servidores MCP, Skills y Binarios de `tools/` asignados obligatoriamente.

Las siguientes reglas son de cumplimiento obligatorio e incondicional para cualquier agente que trabaje en este proyecto.

## 0. Git como Fuente de Verdad y Trazabilidad Obligatoria
- **Paso Cero Obligatorio:** Antes de proponer o modificar cualquier archivo, el agente DEBE ejecutar e inspeccionar:
  1. `git status`: Verificar cambios pendientes, archivos modificados o archivos no rastreados (*untracked*).
  2. `git log -n 5 --oneline`: Conocer el historial reciente, el commit funcional base y el estado de la rama actual.
  3. `git diff`: Inspeccionar detalladamente los cambios en curso antes de realizar ediciones adicionales.
- **Trazabilidad y Detección de Regresiones:** Cuando una prueba falle o un script arroje error, utilizar siempre `git diff` o comparar con el último commit estable para aislar la causa raíz con exactitud matemática en lugar de adivinar o rehacer código desde cero.
- **Commits Atómicos tras Validación:** Tras completar y verificar empíricamente cada hito, corrección o refactorización, registrar un commit atómico y descriptivo.
- **Rollback Seguro:** En caso de regresión crítica o fallo irreparable en una prueba, realizar rollback inmediato con herramientas de Git (`git restore`, `git checkout` o `git revert`) para retornar al último estado seguro conocido.
- **Protección Anti-Bucle en Operaciones Git:** Todo comando de Git susceptible de demorar (ej. `git commit` con pre-commit hooks de ~80s, `git clone`, `git fetch`, `git push`) DEBE ejecutarse con aviso previo al usuario, modo estrictamente no interactivo (`GIT_TERMINAL_PROMPT=0`, `--no-pager`) y supervisión mediante Watchdog Timer (`schedule`) cuando se envíe a segundo plano, impidiendo que el agente o la tarea queden atrapados en bucles de espera pasiva o solicitudes interactivas colgadas.

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
- **Codificación Obligatoria en Scripts de PowerShell (`.ps1`, `.psm1`, `.psd1`):** DEBEN ser creados y guardados estrictamente en formato UTF-8 con BOM (`0xEF, 0xBB, 0xBF`). Está estrictamente prohibido guardar scripts de PowerShell en UTF-8 sin BOM (UTF-8 puro), ya que Windows PowerShell 5.1 (`powershell.exe`) cae por defecto en la página de códigos ANSI del sistema (Windows-1252), provocando colapso de comillas y errores fatales de sintaxis ante caracteres especiales, acentos o emojis.
- **Codificación en Scripts Batch / Símbolo del Sistema (`.cmd`, `.bat`):** ESTRICTAMENTE PROHIBIDO el uso de marcas de orden de bytes (BOM). Todo archivo `.cmd` o `.bat` DEBE ser guardado en formato ANSI o UTF-8 puro sin BOM (`UTF-8 No-BOM`). Windows `cmd.exe` no reconoce el BOM e interpreta los bytes `0xEF 0xBB 0xBF` como caracteres literales de la primera orden (`ï»¿@echo`), causando fallos fatales inmediatos de comando no reconocido.
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

## 7. Norma Taxativa: Transparencia, Notificación y Timer Anti-Bloqueo Obligatorio (Watchdog de Tareas)
- **Carácter de Norma Obligatoria:** Este protocolo NO es una sugerencia ni una recomendación opcional; es una **norma taxativa e inquebrantable** para toda operación prolongada (Git hooks, suites de pruebas, montajes DISM, descargas de repositorios, compilaciones oscdimg o comandos en segundo plano).
- **Aviso de Inicio Obligatorio:** Antes de lanzar cualquier operación que tome tiempo o entrañe riesgo de bloqueo/bucle, el agente DEBE emitir un mensaje visible en el chat:
  `⏳ [AVISO DE OPERACIÓN PROLONGADA]: Iniciando [Nombre de la acción / test / comando]... Tiempo estimado: [X]s. Watchdog de supervisión activado.`
- **Timer Anti-Bloqueo Obligatorio (Watchdog del Agente):**
  1. Para toda tarea ejecutada en segundo plano o que demore más de 30 segundos, el agente DEBE obligatoriamente programar un temporizador de supervisión activa (`schedule` con `DurationSeconds` acotado, ej. 60-120 segundos) condicionado al TaskId o liveness.
  2. Si el comando no concluye antes de dicho plazo, el temporizador despertará al agente para forzar la inspección forense (`manage_task status`), evaluar los logs y diagnosticar anomalías, erradicando cualquier congelamiento o espera pasiva infinita.
- **Protección contra Bucles e Interactividad Colgada:** Queda estrictamente prohibido ejecutar procesos que esperen confirmación por teclado (stdin interactivo), prompts de credenciales de Git, paginadores que bloqueen la terminal (`PAGER=cat` obligatorio), o herramientas MCP que entren en bucle sin límite de tiempo.
- **Aviso de Finalización Obligatorio:** Tan pronto como la operación concluya, el agente DEBE notificar su finalización y el resultado obtenido:
  `✅ [OPERACIÓN FINALIZADA]: [Nombre de la acción] — Resultado: [PASS / FAIL / Métricas].`
- **Cero Tareas Fantasma y Cero Esperas Pasivas:** Está terminantemente prohibido dejar tareas en segundo plano sin supervisión periódica o cerrar turnos asumiendo que un proceso finalizará por su cuenta sin un perro guardián (watchdog) activo.

## 8. Ejecución Autónoma y Continua de Planes (Modo Autorizado)
- **Autorización de Avance Continuo:** Por instrucción expresa del usuario, el agente queda autorizado para avanzar de forma continua y autónoma en la ejecución completa de las fases de los planes de implementación aprobados (`PLAN-*.md`), sin detenerse a solicitar aprobaciones intermedias paso a paso, hasta completar el hito o hasta que el usuario emita una contraorden en el chat.
- **Preservación Incondicional de Calidad:** La autonomía no exime el cumplimiento estricto de las demás reglas de ingeniería:
  1. Verificación previa de Git y trazabilidad matemática (Regla 0).
  2. Codificación estricta UTF-8 con BOM y pruebas en frío contra Windows PowerShell 5.1 (Regla 4).
  3. Notificación visible y transparente del inicio y fin de cada prueba o tarea relevante (Regla 7).
  4. Sincronización en cascada (SSOT), cero directivas huérfanas y documentación simultánea (Reglas 9 y 10).
  5. Erradicación absoluta de fallos silenciosos y pruebas de pre-commit antes de cada commit atómico (Regla 13).
- **Suspensión de Emergencia:** Ante cualquier fallo irrecuperable en una suite de pruebas o regresión crítica no resuelta, el agente debe detenerse inmediatamente, reportar la anomalía y consultar al usuario.

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

## 12. Protocolo Anti-Sesgo y Análisis Forense de Logs
- **Prohibición de Sesgo de Confirmación:** Al analizar logs para diagnosticar regresiones, cambios de tamaño o errores, está ESTRICTAMENTE PROHIBIDO saltar a la primera conclusión plausible basada en las líneas más llamativas (ej. copias de archivos o inyecciones).
- **Lectura Estructural y Comparativa:** El agente DEBE buscar deliberadamente variables de entorno, banderas de compilación, parámetros de configuración (ej. Compress:fast, TargetVersion) y comparar mentalmente la métrica actual contra los logs históricos.
- **Cerrojo Anti-Truncamiento (Grep Físico Obligatorio):** Está estrictamente prohibido auditar resultados de comandos largos (como `Invoke-TestSuite.ps1`) leyendo la salida de consola, ya que el sistema trunca la salida ocultando errores previos. El agente está OBLIGADO a usar la herramienta `grep_search` apuntando al archivo físico `.log` buscando las palabras `FAIL`, `ERROR` o `Exception`. Emitir un veredicto de éxito sin ejecutar `grep_search` en el log físico constituye una violación directa de las reglas.
- **Activación de Skill:** Para cualquier tarea que implique leer logs extensos, el agente DEBE activar y adherirse a la skill `log-forensics` antes de emitir un diagnóstico al usuario.

## 13. Principio de Auditoría Holística y Prohibición Estricta de Fallos Silenciosos
- **Alcance Obligatorio de Repositorio Completo (Whole-Repository Scope):**
  1. Ante el descubrimiento de una suposición errónea (ej. asumir `DeviceID = 0`, partición `C:`, adaptador de red único, GPU única o proveedor exclusivo), o cualquier defecto sistémico de diseño, está TERMINANTEMENTE PROHIBIDO limitar la corrección a un archivo aislado o a un subconjunto arbitrario de scripts.
  2. El agente DEBE obligatoriamente extender la auditoría y la solución al **100% de los scripts del repositorio** (`scripts/Core`, `scripts/Builder`, `scripts/Modules`, `scripts/GUI`, `scripts/Drivers`, `scripts/Host-Tools`), empleando herramientas de introspección sintáctica (AST de PowerShell / Grep físico) para erradicar el patrón en toda la base de código.
- **Prohibición Absoluta de Fallos Silenciosos (CWE-390 / Fail-Visible):**
  1. Queda estrictamente prohibido el uso de bloques `catch { }` vacíos, `catch { $null }`, o capturas que devoren excepciones sin emitir telemetría visible.
  2. Todo bloque `catch` en módulos de hardware, sistema, red, compilación o mantenimiento DEBE emitir un mensaje visible (`Write-Warning`, `Write-Error`, o alerta en UI/terminal con coloración de advertencia) que detalle:
     - El recurso, componente o tarea que se intentaba ejecutar.
     - La causa técnica exacta de la falla (`$_.Exception.Message`).
     - El comportamiento alternativo o fallback adoptado.
  3. El uso de `-ErrorAction SilentlyContinue` queda restringido exclusivamente a comprobaciones de existencia previas no destructivas (ej. `Test-Path` o `Get-Command`), y NUNCA en operaciones que modifiquen el sistema, manipulen el registro, ejecuten procesos externos o consulten la topología del hardware.
- **Validación Cuantificada y Cero Suposiciones:**
  1. Para dar por cerrada cualquier auditoría o corrección sistémica, el agente DEBE presentar al usuario una matriz métrica cuantificada con el 100% de los scripts del proyecto demostrando cero ocurrencias residuales del defecto.
  2. Se debe activar y seguir la skill `holistic-audit` para la ejecución estandarizada de esta metodología.

## 14. Salvaguarda de Almacenamiento Físico, Arquitectura Multi-Hardware y Validación por Mocks Sintéticos
- **Inviolabilidad Absoluta de Medios de Almacenamiento (Cero Destrucción de Datos):**
  1. Queda estrictamente prohibido ejecutar comandos destructivos de disco (`Format-Volume`, `Clear-Disk`, `Remove-Partition`, `diskpart clean` o borrado de carpetas de usuario) en cualquiera de las unidades físicas o lógicas del host (`C:`, `D:`, `E:`, SSDs NVMe, HDDs mecánicos o dispositivos USB).
  2. Toda comprobación del sistema en el host físico debe ser de **Solo Lectura** (`Get-*`, `Test-*`) o ejecutarse con el switch `-WhatIf` / `-Simulate`.
  3. Las pruebas que involucren archivos efímeros deben confinarse estrictamente a la carpeta designada del proyecto (`C:\OptimizedISO\scratch\`), sin tocar jamás directorios raíz ni carpetas personales.
- **Principio de Diseño Agnóstico y Adaptativo (Multi-Hardware Obligatorio):**
  1. Está terminantemente prohibido asumir que la máquina de desarrollo o de prueba representa la configuración universal del usuario final.
  2. Todo módulo de optimización, afinamiento de memoria, red, disco, gráficos o CPU DEBE estructurarse en **3 Capas Arquitectónicas**:
     - **Capa 1: Invariantes Universales del SO:** Ajustes que aplican al 100% de los entornos Windows 11 sin importar el hardware (Seguridad Anti-Cheat con `VulnerableDriverBlocklistEnable = 1` y servicio `bam`, blindaje contra reinicios forzados de Windows Update, bypasses OOBE como `BypassNRO` y debloat universal).
     - **Capa 2: Motor de Topología Dinámica (Hardware-Aware):** Detección en tiempo de ejecución de la topología real antes de aplicar cualquier directiva:
       - *CPU:* Heterogénea / Híbrida (Intel 12th-14th Gen P/E Cores) vs Simétrica vs AMD 3D V-Cache (Dual-CCD). Prohibido forzar `Win32PrioritySeparation` estático si se detecta arquitectura híbrida o X3D para no romper Intel Thread Director ni AMD CPPC.
       - *GPU / Memoria:* APU / iGPU con memoria compartida UMA vs GPU Discreta (dGPU con VRAM propia). En APU/UMA, `LargeSystemCache` DEBE ser 0 estricto para no asfixiar el pool de texturas del juego.
       - *Almacenamiento:* Detección **volumen por volumen** (`NVMe` vs `SATA SSD` vs `HDD Mecánico`). Prohibido deshabilitar indexación o búferes de lectura de forma global si conviven discos mecánicos con SSDs.
       - *Red:* Detección dinámica de capacidades de la NIC (RSS, Offloads, ECN). Prohibido forzar `TcpAckFrequency = 1` o tweaks legacy de 2005 que colapsan conexiones de fibra óptica.
     - **Capa 3: Fallback Seguro (Zero-Damage Principle):** Ante cualquier fallo de detección o hardware desconocido/exótico, el script DEBE replegarse automáticamente al estándar seguro y oficial de Microsoft sin aplicar modificaciones agresivas.
- **Validación Multi-Hardware por Mocks Sintéticos en Memoria (Independencia de Hyper-V):**
  1. Dado que el entorno de desarrollo opera sin privilegios de administrador elevado para Hyper-V (`IsAdmin: False`), la certificación de compatibilidad multi-hardware se realizará **obligatoriamente mediante inyección de Mocks de CIM/WMI en memoria**, simulando en pruebas unitarias:
     - Topología Intel Híbrida (P-Cores + E-Cores).
     - Topología AMD con 3D V-Cache (Dual-CCD).
     - Topología con GPU Discreta dedicada (dGPU con VRAM dedicada de alta capacidad).
     - Topología de Almacenamiento Mixta o Mecánica Pura (HDD SATA).
  2. Ningún script con impacto en hardware se dará por validado sin superar la matriz de mocks en `scripts/Testing/`.

## 15. Arquitectura de Memoria Jerárquica, Persistencia Externa y Patrón Map-Reduce para Tareas Masivas
- **Prohibición de Procesamiento Monolítico Ciego (Anti-Context Dilution):** Queda terminantemente prohibido intentar auditar, refactorizar o validar listas extensas de archivos, scripts o políticas (más de 5 componentes) en un único turno o prompt masivo. Dicha práctica satura la ventana de contexto, provoca el fenómeno de "amnesia en el medio" (*lost in the middle*), degrada la atención del modelo y conduce a conclusiones complacientes superficiales sin comprobación empírica.
- **Protocolo Obligatorio de 6 Pilares para Auditorías y Tareas Extensas:** Ante cualquier requerimiento de auditoría repo-wide, modernización integral o procesamiento a gran escala, el agente DEBE ejecutar obligatoriamente los siguientes 6 pasos:
  1. **Pilar 1 — Grafo de Conocimiento Estructurado (MCP `memory`):** Registrar entidades, relaciones y observaciones técnicas de cada componente analizado en la base de datos de grafos persistente en disco (`create_entities`, `add_observations`), garantizando supervivencia inter-sesión con costo cero de contexto.
  2. **Pilar 2 — Conciencia de Compaction y Rollup Progresivo:** Diseñar el flujo de trabajo asumiendo que el historial de chat será compactado automáticamente por el motor de Antigravity. Dejar siempre un resumen estructurado al final de cada turno que alimente directamente el siguiente ciclo de compaction sin pérdida de restricciones.
  3. **Pilar 3 — Persistencia en Archivos Git (*Docs-as-Code*):** Registrar inmediatamente un plan formal en `docs/plans/PLAN-NNNN.md` con la matriz exhaustiva de elementos numerados y estados (`PENDIENTE` / `EN PROGRESO` / `COMPLETADO`). El repositorio Git es la única fuente de verdad inmutable para el avance de tareas.
  4. **Pilar 4 — Patrón Map-Reduce por Lotes (Chunking Metodológico de 3 a 5 Elementos):**
     - *Map:* Seleccionar un lote acotado de 3 a 5 scripts/componentes por iteración.
     - *Audit & Modernize:* Investigar fuentes líderes mundiales (Microsoft Learn, AtlasOS, ReviOS, Sophia Script), contrastar parámetros y corregir código.
     - *Reduce / Checkpoint:* Actualizar las métricas físicas, validar en Windows PowerShell 5.1 y registrar el avance en el plan antes de tomar el siguiente lote.
  5. **Pilar 5 — Delegación a Subagentes Especializados para Aislamiento de Contexto:** Cuando una tarea requiera procesamiento intensivo de datos (análisis de miles de líneas de logs, procesamiento masivo de claves de registro o scraping de documentación técnica), delegar la operación a subagentes dedicados (`log-forensics`, `registry-forensics`, `browser_subagent`) para que devuelvan al hilo principal únicamente una síntesis destilada de alta fidelidad.
  6. **Pilar 6 — Artefactos Vivos y Modo Autónomo Extendido:** Mantener un documento de reporte vivo en la carpeta de artefactos (`auditoria_*.md`) accesible al usuario en tiempo real, e invocar el modo de avance autónomo continuo (Regla 8 / `/goal`) con supervisión por Watchdog Timers (Regla 7).

## 16. Protocolo Mecánico de Certeza Empírica, Prohibición de Alucinación de Artefactos y Modus Operandi Determinista (Anti-Complacencia)
- **Modus Operandi Autómata / Cero Complacencia Humana:**
  1. Queda estrictamente erradicado todo lenguaje persuasivo, adulador, suposiciones optimistas o conclusiones declaradas "completadas" sin evidencia cruda.
  2. El agente opera como un autómata determinista: Solo reporta estados booleanos (`True`/`False`), evidencia binaria en disco (bytes > 0), códigos de salida del sistema operativo (`ExitCode = 0`) y datos crudos capturados por herramientas.
- **Cerrojo Inviolable de Evaluación Repo-Wide:**
  1. Para cualquier tarea o plan que declare la compilación, generación o certificación de componentes, el agente tiene TERMINANTEMENTE PROHIBIDO marcar la tarea como `COMPLETADO` a menos que ejecute `scripts/Testing/Invoke-RomanOSHarness.ps1` y obtenga `ExitCode = 0` con el 100% de cumplimiento.
  2. Si un artefacto binario (`.iso`, `.wim`, `.vhdx`) no existe en el sistema de archivos del host, la tarea DEBE permanecer obligatoriamente como `PENDIENTE (No generado en disco)`.
- **Distinción Taxativa entre "Simulación en Memoria / Mock" vs "Ejecución Real en Vivo":**
  1. Si un script se evalúa mediante `-WhatIf`, `-Simulate`, extracción de AST o inyección de mocks, queda TERMINANTEMENTE PROHIBIDO afirmar o insinuar que se ha "probado la ISO", "probado la VM" o "validado en vivo".
  2. Todo reporte debe etiquetarse explícita y obligatoriamente con el prefijo `[MOCK / SIMULACIÓN SINTÉTICA EN MEMORIA — NO EJECUTADO EN HARDWARE REAL]`.
- **Cerrojo de Privilegios de Seguridad del Sistema Operativo:**
  1. Toda operación que requiera privilegios elevados (DISM para montaje, Hyper-V `New-VM`, `oscdimg`) DEBE verificar primero si `([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(1)` es `$true`.
  2. Si es `$false`, el agente DEBE abstenerse de declarar la tarea como factible o ejecutada por el agente, y declararla inmediatamente como `BLOQUEADO POR FALTA DE ELEVACIÓN (Requiere que el usuario ejecute el lanzador UAC .cmd)`.

## 17. Gobernanza de Ingeniería Industrial y Control de Comportamiento del Agente (Estándar agent-skills)
- **17.1. Matriz Anti-Racionalización (Prohibición de Excusas y Atajos del Agente):**
  Queda formalmente codificada la tabla de rechazo incondicional para evitar el sesgo de complacencia (*lazy green*):

| Racionalización Típica del Agente | Regla de Rechazo Incondicional |
| :--- | :--- |
| *"El archivo no existe, pero la lógica está validada en memoria."* | **RECHAZADO.** Sin artefacto físico verificado con hash y tamaño > 0, el estado es FAIL/PENDIENTE. |
| *"Agregué un catch vacío para evitar que el script se interrumpa."* | **RECHAZADO (CWE-390).** Degrada la resiliencia del software. Debe ser visible y emitir telemetría con `Write-Warning`. |
| *"Creé un script nuevo aislado para probar que el componente compila."* | **RECHAZADO.** La prueba debe correr contra el arnés de regresión repo-wide (`Invoke-RomanOSHarness.ps1`), no en un test aislado. |
| *"Solo cambié un valor en este archivo, no afecta al resto."* | **RECHAZADO.** Obligatorio correr la suite de contratos transversales y paridad SSOT. |
| *"No tengo permisos de Admin, así que doy por completada la fase teóricamente."* | **RECHAZADO.** Reportar estado `BLOQUEADO_POR_UAC` con el comando exacto para que el usuario ejecute el lanzador `.cmd`. |

- **17.2. Protocolo Doubt-Driven Development (D3):**
  Ante cualquier decisión no trivial en kernel, registro o arquitectura, el agente debe seguir el ciclo:
  1. *CLAIM:* Formular la afirmación técnica precisa antes de codificar (ej. *"Modificar parámetro X mejora la latencia de juego"*).
  2. *DOUBT:* Cuestionar adversariamente la afirmación: ¿Qué documenta Microsoft Learn? ¿Cómo impacta en arquitecturas heterogéneas (P/E cores, UMA)? ¿Rompe anti-cheats Ring-0?
  3. *RECONCILE:* Si no existe evidencia oficial concluyente o prueba empírica, la afirmación se descarta o se confina a lógica adaptativa con fallback seguro.
  4. *STOP:* Queda prohibido aplicar modificaciones especulativas al registro.

- **17.3. Test-Driven Development (TDD) y Regla "Beyoncé" (*If you liked it, put a test on it*):**
  1. Para cada nueva directiva, tweak, servicio o eliminación de AppX:
     - **RED:** Definir la aserción en `Invoke-RomanOSHarness.ps1` o en la suite de contratos correspondiente. La prueba DEBE fallar en rojo antes de codificar la solución.
     - **GREEN:** Implementar la política canónica en `scripts/Core/Policy-Engine.ps1` y propagar. La prueba debe pasar a verde legítimamente.
     - **REFACTOR:** Ejecutar el arnés completo repo-wide para certificar cero regresiones colaterales.

- **17.4. Protocolo Stop-the-Line y Triaje en 5 Pasos:**
  1. **Regla Stop-the-Line:** Si el arnés de evaluación (`Invoke-RomanOSHarness.ps1`) o cualquier suite reporta `ExitCode 1`, queda **estrictamente prohibido avanzar en nuevas características o modificar otros módulos**. La línea de producción se detiene hasta reparar la causa raíz.
  2. **Triaje en 5 Pasos:**
     - *Reproduce:* Aislar el comando mínimo reproducible.
     - *Localize:* Aislar el archivo y número de línea exacto mediante AST o grep físico.
     - *Reduce:* Aislar la expresión mínima que detona el error.
     - *Fix:* Corregir la causa raíz sin usar parches superficiales ni silenciar errores.
     - *Guard:* Agregar una aserción permanente en el arnés para garantizar que el defecto no vuelva a ocurrir jamás.

- **17.5. Principio de la Cerca de Chesterton (*Chesterton's Fence*):**
  *"No derribes una cerca hasta que sepas exactamente por qué fue construida."*
  Queda estrictamente prohibido eliminar servicios de Windows, tareas programadas, dependencias de red o paquetes AppX sin documentar previamente su árbol de dependencias oficiales en Microsoft Learn y verificar que subsistemas críticos (RPC, DWM, CryptSvc, WMI, WinVerifyTrust) sigan 100% operativos.

- **17.6. Desacoplamiento de Contexto vía `.agents/references/`:**
  Las listas de verificación extensas, matrices de hardware y tablas de compatibilidad deben residir en archivos desacoplados bajo `.agents/references/`, siendo consultados bajo demanda para prevenir la saturación de contexto (*context dilution*) y la amnesia del modelo.

## 18. Soberanía de Herramientas Locales, Prohibición de Binarios Ajenos y Mapeo Canónico Obligatorio (Tool-Gating)
- **18.1. Prohibición Taxativa de Herramientas Ajenas y Rutas Fuera del Repositorio:**
  1. Queda TERMINANTEMENTE PROHIBIDO para cualquier script del repositorio o script temporal en `scratch/` invocar binarios instalados en el host (`C:\Program Files\*`, `C:\Program Files (x86)\*`, `7z.exe`, `WinRAR`, `dism /Mount-Wim` para meras tareas de lectura o inspección).
  2. Todo comando de diagnóstico, compilación, auditoría o extracción DEBE resolverse exclusivamente mediante los binarios versionados en `tools/` o las funciones canónicas de `scripts/Core/`.
  3. El uso de herramientas genéricas de terceros del host constituye una infracción crítica de portabilidad, reproducibilidad y gobernanza.

- **18.2. Tabla de Mapeo Canónico Obligatorio (Invariable e Inviolable):**
  Ante cualquier necesidad operativa, el agente DEBE utilizar estrictamente el componente canónico asignado:

| Dominio Operativo / Tarea | Herramienta Canónica en `tools/` | Módulo Wrapper en `scripts/Core/` | Prohibición Explícita |
| :--- | :--- | :--- | :--- |
| **Manipulación / Lectura de WIM/ESD/ISO** | `tools\wimlib\wimlib-imagex.exe` | `scripts\Core\WimLib-Helper.ps1` (`Get-WimImageInfoFast`, `Get-WimFileListFast`, `Export-WimFileFast`) | Prohibido `7z.exe`, `dism /mount` para lectura o descompresión manual a disco. |
| **Validación de Firmas Authenticode / WHQL** | `tools\sysinternals\sigcheck64.exe` | `scripts\Core\Sysinternals-Helper.ps1` (`Test-BinarySignatureWHQL`) | Prohibido asumir validez sin hash y firma Authenticode verificada. |
| **Mapeo de Topología CPU / Caché / NUMA** | `tools\sysinternals\Coreinfo64.exe` | `scripts\Core\Hardware-Engine.ps1` / `Sysinternals-Helper.ps1` | Prohibido usar WMI genérico para inferir P/E Cores o 3D V-Cache sin soporte nativo. |
| **Inspección Forense de Servicios e Inicio** | `tools\sysinternals\autorunsc64.exe` | `scripts\Core\Sysinternals-Helper.ps1` | Prohibido listar autoruns con scripts ad-hoc incompletos. |
| **Búsqueda Instantánea de Archivos en Host** | `tools\everything\es.exe` | Invocación CLI directa de `es.exe` | Prohibido ejecutar `Get-ChildItem -Recurse C:\` que bloquee el disco del host. |
| **Persistencia Inter-Sesión de Lecciones** | Servidor MCP `memory` | Entidades y observaciones en grafo persistente | Prohibido almacenar conclusiones exclusivamente en texto de chat efímero. |
| **Consulta Web Oficial de Documentación** | Servidor MCP `fetch` | Extracción markdown limpia de Microsoft Learn | Prohibido alucinar flags de línea de comandos o esquemas sin verificar en fuente oficial. |

- **18.3. Protocolo de Paso Cero de Herramientas y Habilidades (Pre-Flight Tool Gate):**
  Antes de generar o ejecutar cualquier script o comando (incluyendo scripts de prueba en `scratch/`), el agente DEBE declarar internamente en su razonamiento:
  1. *Skill Declarada:* La skill de `.agents/skills/` que rige la operación (ej. `powershell-windows`, `holistic-audit`, `debug-strategy`).
  2. *Componente Asignado:* La ruta exacta del binario en `tools/` o función canónica de `scripts/Core/` que ejecutará la acción.
  3. *Verificación de Aislamiento:* Si la herramienta no existe en `tools/` o `scripts/Core/`, SOLO se permite recurrir a cmdlets nativos del sistema operativo (`Get-Volume`, `Test-Path`, etc.) documentando explícitamente la ausencia de contraparte local.

- **18.4. Erradicación de Scripts Ad-Hoc Huérfanos:**
  Cualquier script temporal en `scratch/` debe ser un consumidor formal de `scripts/Core/` (mediante `. "$PSScriptRoot\..\scripts\Core\*.ps1"` o carga controlada) y nunca un código monolítico que reinvente wrappers o invoque rutas duras del host.

## 19. Protocolo de Inquisición Cero-Confianza y Validación Epistemológica contra Fuentes Oficiales (Anti-Circular Validation Fallacy)
- **19.1. Prohibición Taxativa de la Falacia de Validación Circular:**
  1. Queda TERMINANTEMENTE PROHIBIDO para el agente asumir o afirmar que un script, módulo o política es correcto simplemente porque sus propias pruebas unitarias o de integración finalizan con `ExitCode 0` o arrojan `PASS`.
  2. Una prueba que verifica el resultado de un script defectuoso, obsoleto o placebo no es una prueba: es una convalidación circular de un error.
- **19.2. Principio Rector: Zero-Trust Spec-First (Culpable hasta Prueba Oficial en Contrario):**
  1. Todo script existente, parámetro de registro, política de kernel, directiva de red o modificación del sistema DEBE ser considerado sospechoso de ser un placebo, mito o defecto de diseño hasta que la especificación técnica oficial del fabricante demuestre empíricamente su vigencia en Windows 11 24H2/25H2.
  2. Prohibido ejecutar o certificar pruebas de rendimiento o funcionalidad sin haber contrastado previamente el diseño y la intención del código contra fuentes oficiales primarias: **Microsoft Learn**, **Intel 64 and IA-32 Architectures Optimization Reference Manual**, **AMD Processor Programming Reference (PPR / CPPC)**, estándares **WDDM** y especificaciones de seguridad Ring-0 (**Riot Vanguard, Easy Anti-Cheat, BattlEye**).
- **19.3. Ciclo Obligatorio de Inquisición en 4 Pasos (Spec-First Audit):**
  Ante cualquier auditoría, modernización o revisión de scripts, el agente DEBE ejecutar obligatoriamente las siguientes 4 fases en estricto orden secuencial:
  1. *Fase 1 — Extracción Anatómica de Afirmaciones (Claim Extraction):* Desglosar cada clave de registro modificada, servicio alterado, comando CLI ejecutado y objetivo prometido.
  2. *Fase 2 — Interrogatorio contra Documentación Oficial (Official Inquest):*
     - ¿La clave de registro es leída y respetada por el kernel de Windows 11 24H2/25H2 o es un residuo zombi de Windows XP/7/2000?
     - ¿El comando invocado está deprecado (ej. `wmic`, `vbs`, parámetros arcaicos de `reg.exe`)?
     - ¿El ajuste rompe tecnologías modernas (Intel Thread Director en CPUs híbridas, AMD 3D V-Cache, VRAM compartida UMA en APUs, o el stack BypassIO / DirectStorage)?
     - ¿La política rompe la compatibilidad Ring-0 con anti-cheats o subsistemas multimedia como `MMCSS`?
  3. *Fase 3 — Clasificación Cuatridimensional y Saneamiento:*
     - **PLACEBO / ZOMBI:** No tiene efecto real o el kernel lo ignora. $\rightarrow$ **Erradicar de inmediato del código y del SSOT.**
     - **OBSOLETO:** Depende de herramientas deprecadas. $\rightarrow$ **Modernizar a APIs nativas y cmdlets CIM de Windows 11.**
     - **PELIGROSO / ROMPE-HARDWARE:** Provoca degradación en ciertas arquitecturas o bloquea juegos. $\rightarrow$ **Condicionar con guardas dinámicas o suprimir.**
     - **OFICIAL Y EFECTIVO:** Respaldado con documentación oficial y beneficio técnico comprobado. $\rightarrow$ **Conservar y blindar con pruebas.**
  4. *Fase 4 — Telemetría y Verificación Empírica en Hardware Real:* Solo una vez saneado el diseño y verificada la intención contra fuentes oficiales, se autoriza la ejecución del script en modo de diagnóstico seguro sobre el hardware físico del host, midiendo su impacto con herramientas y sensores canónicos (`Coreinfo64`, `Test-KernelTimerResolution`, `fsutil bypassIo`, contadores de rendimiento).

## 20. Principio de Producto Universal y Prohibición Taxativa de Parches Ad-Hoc / Single-User (Universal Architecture & Public Product Principle)
- **20.1. Filosofía de Producto Universal para el Público General:**
  1. Todo componente, script, interfaz gráfica, tarea programada y política de configuración en este repositorio está concebido para su distribución pública universal (entornos de producción, empresas, gamers y creadores de contenido).
  2. Queda TERMINANTEMENTE PROHIBIDO concebir o implementar soluciones "a medida para el operador actual" (*single-user workarounds* o parches ad-hoc para la máquina local).
  3. Cada línea de código, control visual o módulo de reparación debe responder a la pregunta: *"¿Esta solución es escalable, intuitiva, necesaria y beneficiosa para los millones de usuarios finales del sistema operativo?"*.
- **20.2. Prohibición Absoluta de Botones Ad-Hoc en la Interfaz Gráfica (Anti-Bespoke UI):**
  1. Queda estrictamente prohibido agregar botones, pestañas o controles en las interfaces gráficas (`romanOS-ControlCenter.ps1`, `romanOS-Studio.ps1`, etc.) cuyo único propósito sea parchar un problema puntual experimentado por el operador durante el desarrollo o prueba.
  2. La UI debe mantenerse limpia, minimalista y profesional. La proliferación de botones hiper-específicos para cada subsistema menor degrada la ergonomía y genera una interfaz dispersa e incomprensible para el usuario general.
- **20.3. Canalización Canónica: Diagnóstico y Reparación Sistémica en 3 Capas:**
  Ante cualquier falla o degradación detectada en un subsistema del SO (ej. un servicio deshabilitado que hace colapsar Opciones de Energía, o esquemas de energía duplicados), el agente DEBE canalizar la solución exclusivamente a través del ecosistema canónico:
  1. *Capa Preventiva (Source/Builder):* Corregir el origen del defecto en los scripts de compilación, imágenes WIM o comandos de aprovisionamiento (`SetupComplete.cmd`, `autounattend.xml`, `Policy-Engine.ps1`) para que la ISO genere un sistema libre del defecto desde el primer arranque.
  2. *Capa Diagnóstica (Audit & Telemetry):* Integrar la detección del problema en las suites generales de auditoría (`Audit-SystemOptimization.ps1`, `PostInstall-Diagnostics.ps1`, `Watchdog-ServiceDrift.ps1`) para que cualquier usuario o administrador pueda identificar el síntoma en un reporte unificado.
  3. *Capa de Auto-Reparación Integral (Universal Self-Healing):* Integrar la remediación dentro de los motores de reparación existentes (ej. `Invoke-WindowsMaintenance.ps1 -IncludeRepair` en el Módulo 5: Reparación Integral de Archivos y Subsistemas del SO), al cual el usuario general ya accede mediante el botón canónico de reparación del sistema.
- **20.4. Mentalidad de Ingeniero de Software vs. Operador de Scripts:**
  1. El agente debe actuar siempre como un Ingeniero de Software de Sistemas Operativos, no como un creador de atajos efímeros.
  2. Si el usuario reporta un fallo en su entorno, el agente tiene prohibido proponer o crear botones o atajos personales. Debe investigar la causa raíz en el sistema operativo, clasificarla dentro de la arquitectura universal, erradicarla en el origen e integrarla en el pipeline general de mantenimiento y diagnóstico.

## 21. Protocolo de Inviolabilidad de Identidad del Host y Prohibición Taxativa de Inferencia de Metadatos desde Logs (Host Identity Gate & Anti-Log Anchoring)
- **21.1. Prohibición Absoluta de Inferencia de Metadatos del SO desde Logs (Anti-Log Anchoring):**
  1. Queda TERMINANTEMENTE PROHIBIDO para el agente deducir, inferir o asumir el sistema operativo, la edición, la versión de lanzamiento (`DisplayVersion`), la compilación (`CurrentBuild`), la revisión acumulativa (`UBR`) o la arquitectura del host a partir de nombres de paquetes en archivos de registro (`CBS.log`, `DISM.log`), salidas de instaladores, cadenas de user-agents o texto incidental de consola.
  2. Toda afirmación sobre las especificaciones del entorno host basada en la lectura de logs se considerará una **alucinación por anclaje (Anchoring Bias / Hallucination)** y una infracción directa de la gobernanza del repositorio.
- **21.2. Compuerta de Telemetría Obligatoria (Host Telemetry Gate / SSOT):**
  1. Antes de reportar o citar las especificaciones del entorno host en cualquier mensaje, auditoría o reporte, el agente DEBE ejecutar obligatoriamente el inspector canónico:
     `& "scripts\Core\Get-HostTelemetry.ps1"`
     o los cmdlets de introspección directa contra `Win32_OperatingSystem` y `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion`.
  2. Queda estrictamente prohibido emitir diagnósticos o declarar compatibilidad con una versión de Windows (ej. 24H2, 25H2, 26H2) sin haber ejecutado la compuerta de lectura en el mismo turno o consultado la entidad `HostEnvironment_Physical` en el servidor MCP `memory`.
- **21.3. Certificación Forense en 5 Campos Obligatorios:**
  Todo reporte de entorno host debe desglosar explícitamente los 5 campos canónicos verificados:
  - `Caption` (ej. Microsoft Windows 11 Pro for Workstations)
  - `EditionID` (ej. ProfessionalWorkstation)
  - `DisplayVersion` (ej. 26H2)
  - `CurrentBuild` (ej. 26300)
  - `UBR` (ej. 9711)
