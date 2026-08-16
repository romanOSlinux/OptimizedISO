# Instrucción de Bootstrap para Antigravity en Windows 11

Cuando abras por primera vez este repositorio en **Antigravity en Windows 11**, copia y pega el siguiente mensaje inicial en el chat:

---

### Mensaje para el Chat de Antigravity en Windows:

```text
Hola Antigravity. He clonado el repositorio OptimizedISO en Windows 11.
Por favor realiza las siguientes acciones de inicialización automática sin requerir mi intervención:

1. Lee el archivo MEMORY.md para conocer el historial completo y el estado del proyecto.
2. Ejecuta el script de configuración .\scripts\Setup-AntigravityWindows.ps1 para inicializar todas las reglas y skills en mi perfil de usuario de Windows ($HOME\.gemini\config).
3. Verifica la presencia de las herramientas nativas (Git, PowerShell 7, Windows ADK / oscdimg.exe, DISM y estado del servicio Hyper-V).
4. Preséntame un resumen de diagnóstico del entorno indicando si el sistema está 100% listo para compilar y probar ISOs.
```

---

### ¿Por qué este enfoque funciona de forma 100% autónoma?

1. **Auto-Descubrimiento en Git:** Todo el paquete de reglas (`.agents/rules/`), habilidades (`.agents/skills/`), directivas (`.agents/AGENTS.md`) y bitácora (`MEMORY.md`) ya viaja dentro del repositorio de Git.
2. **Carga Automática:** Tan pronto como abres la carpeta en Antigravity en Windows, el motor del agente lee automáticamente `.agents/` y asume todas las directivas de eficiencia de tokens, memoria activa y control de calidad sin que tengas que configurar nada a mano.
3. **Instalación Global Opcional:** El script `.\scripts\Setup-AntigravityWindows.ps1` replica estas reglas en el directorio global de Antigravity en Windows (`%USERPROFILE%\.gemini\config`), asegurando que todos tus futuros proyectos en Windows hereden la misma inteligencia.
