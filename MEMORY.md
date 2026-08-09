# Registro de Actividad (MEMORY.md)

## [2026-08-09T19:42:00-03:00] Modificaciones a New-OptimizedWindowsISO.ps1
- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - Se eliminó la descarga automática de ISOs y dependencias de `Fido`.
  - Se cambió la selección de archivo de interfaz gráfica a un selector de menú interactivo en consola (busca ISOs en directorios).
  - Se removió la configuración desatendida para `<DiskConfiguration>`, `<ImageInstall>` y clave de producto en `autounattend.xml` (Fase windowsPE).
  - La instalación permite selección de edición y particionamiento manual durante el setup, respetando el resto de bypasses (OOBE, NRO, TPM).
  - **Hotfix:** Se eliminó la etiqueta `<UserData>` vacía y el comando legacy setup (`CmdLine`) que provocaban que el instalador (`setup.exe`) se cerrara automáticamente.
  - **Hotfix:** Se ajustó la expresión regular que detecta los índices del archivo `install.wim` a `(?:Index|Índice)` para inyectar correctamente las configuraciones y scripts en todas las ediciones, incluyendo sistemas base en español.
- **Pendientes:**
  - Validar compatibilidad e integridad en escenarios de despliegue real usando la ISO modificada.
