# Registro de Actividad (MEMORY.md)

## [2026-08-09T22:12:00-03:00] Auditoría e Investigación Oficial en Microsoft Learn (Deprecaciones XML)
- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados / Hallazgos Verificados:**
  - **Eliminación de `SkipMachineOOBE` y `SkipUserOOBE`:** Verificado en documentación oficial de Microsoft Learn. Estas directivas fueron marcadas como *deprecated* a partir de Windows 10 build 1511+. Su inclusión en Windows 10/11 produce bloqueos y comportamientos erráticos durante la fase `oobeSystem`.
  - **Eliminación de `ShowWindowsLive`:** Etiqueta obsoleta heredada de Windows 7/8. Ignorada por el motor de despliegue moderno.
  - **Eliminación de `HideLocalAccountScreen`:** En Windows 10/11 Client es ignorada o redundante al declarar `LocalAccounts` y `AutoLogon`.

## [2026-08-09T22:07:00-03:00] Configuración de Reglas del Agente (.agents/AGENTS.md)
- **Archivos Creados:** `.agents/AGENTS.md`
- **Hitos Logrados:**
  - Establecidas reglas de cumplimiento obligatorio para prohibir afirmaciones sin verificación empírica o fuentes oficiales.
  - Configurada la diferenciación estricta de entorno: Host (Arch Linux) vs Target (Windows).
  - Protocolo de auditoría riguroso obligado para todas las interacciones futuras.

## [2026-08-09T21:34:00-03:00] Auditoría y corrección de 9 bugs críticos en New-OptimizedWindowsISO.ps1
- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - **Fix #1 (CRÍTICO):** Agregados `xmlns:wcm` y `xmlns:xsi` al elemento raíz `<unattend>` del XML. Sin estos namespaces el parser de Windows Setup no puede resolver `wcm:action` y descarta o crashea al leer el autounattend.xml completo.
  - **Fix #2 (CRÍTICO):** Agregadas variables `$passwordPlainTextAccount` y `$passwordPlainTextAutologon`. Cuando la contraseña es vacía (caso por defecto), `PlainText` ahora es `"true"` en lugar de `"false"`. `PlainText=false` con valor Base64 vacío es XML inválido según Microsoft → crash en OOBE.
  - **Fix #3 (CRÍTICO):** Eliminado el `RunSynchronousCommand` que escribía en `HKLM\SYSTEM\Setup\FirstBoot\PostOobe`. Esta clave NO está documentada por Microsoft y es ignorada en Windows 11 24H2+. `SetupComplete.cmd` se ejecuta automáticamente si existe en `%WINDIR%\Setup\Scripts\`.
  - **Fix #4 (CRÍTICO):** Reemplazado el uso de `Start-Process -ArgumentList` con un batch file temporal para ejecutar oscdimg. PowerShell corrompe las comillas internas del argumento `-bootdata:2#p0,e,b"..."#pEF,...` al pasarlo como array → ISO sin boot funcional.
  - **Fix #5 (CRÍTICO):** Eliminada la inyección de `autounattend.xml` en `Windows\Panther\Unattend\` dentro del WIM. El autounattend.xml ya está correctamente en la raíz de la ISO. Inyectarlo en el WIM genera conflicto de fases (directivas windowsPE procesadas en momento equivocado → crash).
  - **Fix #6 (MENOR):** `SetupComplete.cmd` reescrito: cambio de `@'...'@` a `@"..."@` para que `$scriptName` se expanda al nombre real del script. Se eliminó la sintaxis `^` dentro de `-Command "..."` que no funciona en CMD. Ahora usa `IF EXIST` directo sobre el script por nombre concreto.
  - **Fix #7 (MENOR):** `<Group>*S-1-5-32-544</Group>` → `<Group>Administrators</Group>`. El SID con prefijo `*` puede no funcionar en todos los builds/locales de Windows.
- **Pendientes:**
  - Validar la ISO generada en instalación real (VM o hardware) para confirmar que todos los fixes resuelven el boot loop.
  - Considerar agregar validación del autounattend.xml con WSIM (Windows System Image Manager) como paso de CI.



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
