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

