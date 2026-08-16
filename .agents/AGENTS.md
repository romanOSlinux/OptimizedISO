# Reglas Estrictas del Agente (.agents/AGENTS.md)

Las siguientes reglas son de cumplimiento obligatorio e incondicional para cualquier agente que trabaje en este proyecto.

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
