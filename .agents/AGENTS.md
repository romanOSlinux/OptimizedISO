# Reglas Estrictas del Agente (.agents/AGENTS.md)

Las siguientes reglas son de cumplimiento obligatorio e incondicional para cualquier agente que trabaje en este proyecto.

## 1. Verificación e Investigación Rigurosa (Cero Suposiciones)
- **Prohibido afirmar certeza absoluta sin prueba:** Nunca declarar que un script, archivo XML o configuración está "100% verificado", "sin errores" o "listo para producción" basándose únicamente en una inspección estática o lectura visual.
- **Investigación activa requerida:** Antes de asegurar que una clave de registro, un flag de línea de comandos (ej. oscdimg, dism) o un parámetro XML funciona en una versión específica de Windows (ej. Windows 11 24H2/25H2), se debe investigar en fuentes oficiales de Microsoft o documentación técnica de la comunidad.
- **Transparencia en las limitaciones:** Indicar siempre de forma transparente qué partes del código han sido comprobadas empíricamente y cuáles son análisis teóricos sujetos a validación en tiempo de ejecución.

## 2. Conciencia Estricta del Entorno (Arch Linux vs. Target Windows)
- **Host vs. Target:** El entorno actual de trabajo es **Arch Linux** (Linux local). El entorno de destino de los scripts de generación e instalación es **Windows**.
- **No sugerir comandos cruzados:** Nunca sugerir la ejecución de cmdlets nativos de Windows (`Mount-WindowsImage`, `dism.exe`, `oscdimg.exe`) directamente en la consola de Linux sin aclarar explícitamente que requieren un entorno Windows o Máquina Virtual.
- **Alternativas Nativas de Linux:** Si el usuario solicita trabajar o compilar artefactos de Windows desde Arch Linux, ofrecer y evaluar las herramientas nativas equivalentes de Linux (`wimlib-imagex`, `xorriso`, `chntpw`, etc.).

## 3. Protocolo de Auditoría y Corrección de Código
- **Un intento informado y fundamentado:** Entender el contexto completo y las fuentes antes de realizar cambios de código.
- **Explicidad de cambios:** Al realizar correcciones, detallar exactamente qué problema técnico resuelve cada modificación y en qué documento/fuente oficial se fundamenta.
