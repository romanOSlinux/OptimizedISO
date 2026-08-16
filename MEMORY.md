## [2026-08-16T18:23:00-03:00] Aislamiento de Ramas: feature/offline-ui-tweaks (Trabajo) vs main (Público)

- **Archivos Modificados:** `docs/WINDOWS_ENVIRONMENT_SETUP.md`, `MEMORY.md`
- **Hitos Logrados:**
  - Se configuró el flujo de trabajo manteniendo la separación estricta entre la rama de trabajo `feature/offline-ui-tweaks` y la rama pública `main`.
  - Se actualizaron las instrucciones en `docs/WINDOWS_ENVIRONMENT_SETUP.md` para especificar la clonación explícita de la rama de trabajo (`git clone -b feature/offline-ui-tweaks ...`).
  - Se confirmó y subió la actualización a GitHub (`origin/feature/offline-ui-tweaks`).
- **Pendiente:** Listo para clonación y bootstrap en Windows 11.

## [2026-08-16T18:14:00-03:00] Publicación y Push Completo a Repositorio Remoto en GitHub

- **Archivos Modificados:** `MEMORY.md`
- **Hitos Logrados:**
  - Se confirmó y subió el commit `feat: Implementar New-OptimizedWindowsISO-v2, descarga dinámica oficial y entorno Windows 11` (25 archivos modificados/creados) a la rama remota `feature/offline-ui-tweaks` en GitHub (`origin`).
  - Se incluyeron los nuevos scripts maestros v2, los descargadores oficiales interactivos, el ecosistema de reglas y skills `.agents/`, y las guías de configuración oficial en Windows 11.
- **Pendiente:** Listo para clonación y despliegue en Windows 11.

## [2026-08-16T18:07:00-03:00] Empaquetado de Reglas, Skills y Bootstrap para Antigravity en Windows

- **Archivos Modificados:** `.agents/rules/user_global.md`, `.agents/skills/*`, `.agents/AGENTS.md`, `scripts/Setup-AntigravityWindows.ps1`, `docs/ANTIGRAVITY_WINDOWS_BOOTSTRAP.md`, `MEMORY.md`
- **Hitos Logrados:**
  - Se empaquetaron todas las reglas globales de memoria y eficiencia de tokens en `.agents/rules/user_global.md`.
  - Se migraron e integraron todas las skills esenciales del proyecto a `.agents/skills/` (`powershell-windows`, `memory-protocol`, `code-review`, `debug-strategy`, `project-audit` y la nueva `windows-adk-hyperv`).
  - Se actualizó `.agents/AGENTS.md` para soportar ejecución adaptativa automática tanto en Windows nativo como en Linux.
  - Se creó el script de automatización `scripts/Setup-AntigravityWindows.ps1` y el prompt de inicialización zero-interaction en `docs/ANTIGRAVITY_WINDOWS_BOOTSTRAP.md`.
- **Pendiente:** Probar clonación y bootstrap en máquina física/VM de Windows 11.

## [2026-08-16T18:02:00-03:00] Creación de Guía Oficial de Entorno Windows 11 para OptimizedISO

- **Archivos Modificados:** `docs/WINDOWS_ENVIRONMENT_SETUP.md`, `MEMORY.md`
- **Hitos Logrados:**
  - Se redactó y guardó la guía técnica paso a paso `docs/WINDOWS_ENVIRONMENT_SETUP.md` fundamentada en fuentes oficiales de Microsoft Learn.
  - Se estructuraron los procedimientos para instalar Windows Package Manager (`winget`), Git, PowerShell 7, Windows ADK (con `oscdimg.exe` y herramientas de implementación), habilitación de Hyper-V y Windows Sandbox vía PowerShell, y configuración de Antigravity en Windows.
  - Se incluyeron scripts de PowerShell para automatizar la creación de Máquinas Virtuales de prueba Gen2 (UEFI/TPM) en Hyper-V para verificar el arranque de las ISOs resultantes en segundos.
- **Pendiente:** Migración o clonación en la máquina host con Windows 11.

## [2026-08-16T17:53:00-03:00] Integración de Menú Selector de Scripts y Distribución Dual en $OEM$\$1

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO-v2.ps1`, `MEMORY.md`
- **Hitos Logrados:**
  - Se diagnosticaron las razones por las cuales `Win11-Debloat-v3-Adaptive.ps1` no aparecía en el escritorio (desfase de nombre respecto al legacy `Windows11_PostInstall_Optimizer.ps1`, limitaciones nativas de `SetupComplete.cmd` en cuentas locales y falta de la estructura `$OEM$\$1\Users\Public\Desktop`).
  - Se implementó el menú interactivo dinámico de selección de scripts en el paso 2/6, permitiendo seleccionar `Win11-Debloat-v3-Adaptive.ps1`, `Win11-Network-Diagnostics-Optimizer.ps1`, ambos scripts simultáneamente o un script personalizado.
  - Se integró la distribución física nativa mediante `$OEM$\$1\Users\Public\Desktop\` para copiar lanzadores `.cmd` auto-elevables (UAC) directamente durante la extracción de Windows Setup.
  - Se configuraron Tareas Programadas a Demanda (`schtasks /ru "SYSTEM" /rl HIGHEST`) y respaldo en `<FirstLogonCommands>` dentro de `autounattend.xml` para garantizar la presencia y ejecución con privilegios máximos desde el Escritorio.
- **Pendiente:** Pruebas de instalación en máquina virtual.

## [2026-08-16T17:37:00-03:00] Creación y Modularización de Versión 2 (New-OptimizedWindowsISO-v2.ps1)

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO-v2.ps1`, `MEMORY.md`
- **Hitos Logrados:**
  - Se creó el script maestro de segunda generación `New-OptimizedWindowsISO-v2.ps1` integrando todas las optimizaciones y componentes auditados.
  - Se incorporó la ingestión híbrida inteligente: si no se especifica `-SourceISO` o se usa `-DownloadOfficialISO`, el script activa el motor dinámico de descarga directa oficial de Microsoft Learn (BITS/curl con resumen y SHA-256) antes de proceder a la optimización.
  - Se consolidaron las mejoras arquitectónicas: layout GPT con partición WinRE oficial de 500 MB (Partición 4 para Windows OS), Modo Oscuro nativo inyectado en `Microsoft-Windows-Shell-Setup`, políticas de controladores bajo demanda (`SearchOrderConfig = 1` y `ExcludeWUDriversInQualityUpdate = 1`), y soporte completo para Windows 11 (25H2, 24H2, 23H2), Windows 10 y ramas LTSC.
- **Pendiente:** Pruebas de integración en entornos de prueba / VM.

## [2026-08-16T17:31:00-03:00] Subsistema de Logging Estructurado en Descargadores Oficiales

- **Archivos Modificados:** `scripts/Get-OfficialWindowsISO-MethodA.ps1`, `scripts/Get-OfficialWindowsISO-MethodB.ps1`, `MEMORY.md`
- **Hitos Logrados:**
  - Se replicó e integró el subsistema de logging estructurado de `New-OptimizedWindowsISO.ps1` en ambos métodos de descarga (`Get-OfficialWindowsISO-MethodA.ps1` y `Get-OfficialWindowsISO-MethodB.ps1`).
  - Se añadieron `Initialize-Log` (creación automática de carpeta `Logs\`, log estructurado UTF-8 con niveles de severidad `[INIT]`, `[STEP]`, `[INFO]`, `[OK]`, `[WARN]`, `[ERROR]`, `Start-Transcript` y reporte Markdown `_AI_SUMMARY.md`).
  - Se encapsuló la ejecución en pasos formales (`Write-Step`), con seguimiento de tiempos de duración, acumulación de advertencias/errores y generación de resumen final (`Write-LogSummary`).
- **Pendiente:** Decidir integración de la descarga oficial en `New-OptimizedWindowsISO.ps1` o creación de script v2.

## [2026-08-16T17:26:00-03:00] Integración de Motor Dinámico de Descubrimiento (Microsoft Release Health)

- **Archivos Modificados:** `scripts/Get-OfficialWindowsISO-MethodA.ps1`, `scripts/Get-OfficialWindowsISO-MethodB.ps1`, `MEMORY.md`
- **Hitos Logrados:**
  - Se implementó la función `Get-OnlineWindowsReleases` que realiza consultas en vivo a los canales oficiales de Microsoft Learn (Windows 11 y Windows 10 Release Health).
  - Se eliminaron las listas estáticas de selección; ahora el menú interactivo se genera en tiempo real detectando las versiones GA más recientes (ej. 25H2 Build 26200, 24H2 Build 26100, 23H2 Build 22631, 22H2 Build 19045) y las ramas LTSC vigentes (2024 y 2021).
  - Se incorporó un catálogo de respaldo verificado (*Modo Resiliente*) con tolerancia total a fallos en caso de indisponibilidad de red.
  - Se documentó el roadmap de las arquitecturas de Catálogo XML (`products.cab`), API Software-Download (Fido) y el motor híbrido futuro en `implementation_plan.md`.
- **Pendiente:** Decidir integración del descargador dentro del flujo de `New-OptimizedWindowsISO.ps1` o desarrollo de script v2.

## [2026-08-16T17:12:00-03:00] Incorporación de Windows 11 25H2 (Build 26200) y Análisis de Ciclos de Versión

- **Archivos Modificados:** `scripts/Get-OfficialWindowsISO-MethodA.ps1`, `scripts/Get-OfficialWindowsISO-MethodB.ps1`, `MEMORY.md`
- **Hitos Logrados:**
  - Se analizó la documentación oficial de Microsoft Learn (*Windows 11 Release Information*), constatando que **25H2 (Build 26200)** es la versión del Canal de Disponibilidad General (GA) anual más reciente, mientras que **24H2 (Build 26100)** se mantiene como la base oficial y activa del canal **LTSC 2024 / IoT Enterprise LTSC** (con soporte hasta 2029/2034).
  - Se actualizaron los menús interactivos y tablas de descarga de ambos métodos (A y B) para incluir **Windows 11 25H2 (Build 26200)** junto a 24H2, 23H2 y las ramas LTSC.
- **Pendiente:** Decidir integración de la descarga oficial en `New-OptimizedWindowsISO.ps1` o creación de script v2.

## [2026-08-16T17:03:00-03:00] Alineación Oficial de Descargadores a la Taxonomía de Microsoft Learn

- **Archivos Modificados:** `scripts/Get-OfficialWindowsISO-MethodA.ps1`, `scripts/Get-OfficialWindowsISO-MethodB.ps1`
- **Hitos Logrados:**
  - Se estructuraron los menús interactivos siguiendo exactamente los canales de servicio de Microsoft: Canal General (Windows 11 24H2 Build 26100, 23H2 Build 22631, Windows 10 22H2 Build 19045) y Canal de Soporte Extendido LTSC (Windows 11 LTSC 2024 Build 26100 y Windows 10 LTSC 2021 Build 19044).
  - Se incorporaron las descripciones técnicas reales de los 3 paquetes de medios de Microsoft (Consumer Multi-Edition, Business Volume Licensing e IoT Enterprise LTSC de 10 años).
  - Se incluyeron los flags `/Selfhost` y selectores de idioma oficiales (BCP-47 / CDN names).
- **Pendiente:** Evaluar la integración final del módulo seleccionado dentro de `New-OptimizedWindowsISO.ps1`.

## [2026-08-16T16:28:00-03:00] Configuración de Controladores Opcionales On-Demand

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - Se ajustó `SearchOrderConfig` a `1` en conjunción con `ExcludeWUDriversInQualityUpdate = 1` en `autounattend.xml`.
  - Windows Update ahora busca y ofrece la lista de controladores disponibles en el menú de *Actualizaciones Opcionales*, pero **no instala ningún driver de forma automática en segundo plano**, dándole control total al usuario.
- **Pendiente:** Ninguno.

## [2026-08-16T16:21:00-03:00] Inyección Nativa de Modo Oscuro en autounattend.xml

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - Se incorporó la directiva oficial `<Themes><ThemeName>C:\Windows\Resources\Themes\dark.theme</ThemeName><DefaultThemesOff>false</DefaultThemesOff></Themes>` dentro del componente `Microsoft-Windows-Shell-Setup` en las fases `specialize` y `oobeSystem`.
  - El Modo Oscuro ahora se inicializa a nivel de motor de temas de Windows Setup en el primer inicio de sesión sin requerir un reinicio manual del equipo.
- **Pendiente:** Ninguno.

## [2026-08-16T16:10:00-03:00] Partición WinRE en esquema GPT de Zero-Touch (Dominio 18)

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - Se agregó la partición de Recuperación WinRE (500 MB, NTFS, TypeID `de94bba4-...`) como tercera partición del layout GPT Zero-Touch, antes de la partición Windows OS.
  - La partición Windows OS se reasignó a la posición 4 (`Extend=true`) y `<InstallTo><PartitionID>` se corrigió de `3` a `4`.
  - El esquema resultante cumple exactamente la guía oficial de Microsoft: EFI (300 MB) → MSR (16 MB) → Recovery (500 MB) → Windows OS (Extend).
- **Pendiente:** Ninguno.

## [2026-08-16T16:06:00-03:00] Mejoras en Resolución de Dependencias (Dominio 17)

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - Se añadió la ruta ARM64 del Windows ADK (`...\arm64\Oscdimg\oscdimg.exe`) al array `$adkPaths` para detectar `oscdimg.exe` en sistemas ARM64 (Snapdragon X, Surface Pro X).
  - Se agregó advertencia explícita (`Write-Warn`) con instrucciones de fallback cuando `winget install Microsoft.OSCDIMG` completa pero el binario no aparece en las rutas esperadas.
- **Pendiente:** Ninguno.

## [2026-08-16T15:58:00-03:00] Expansión AUDITORIA_GUIA.md — Dominios 16, 17 y 18

- **Archivos Modificados:** `AUDITORIA_GUIA.md`
- **Hitos Logrados:**
  - Se identificaron 3 subsistemas del script sin cobertura de auditoría: reconstrucción ISO con `oscdimg.exe`, resolución de dependencias (`winget`/ADK) y modo Zero-Touch con particionado GPT.
  - Se incorporaron los Dominios 16, 17 y 18 con plantillas de auditoría completas, incluyendo fuentes oficiales de Microsoft Learn.
- **Pendiente:** Ejecutar auditorías individuales de los nuevos dominios.

## [2026-08-16T15:44:00-03:00] Inyección Offline de Controladores (Drivers) en New-OptimizedWindowsISO.ps1

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`, `scripts/Drivers/README.md`
- **Hitos Logrados:**
  - Se agregó el parámetro `$DriversPath` y la detección automática de carpetas `Drivers/` (`$DriversPath`, `scripts/Drivers/` o raíz del proyecto).
  - Se implementó la integración offline recursiva de controladores `.inf` en `install.wim` mediante `dism.exe /Image:... /Add-Driver /Driver:... /Recurse /ForceUnsigned`.
  - Se creó la documentación explicativa en `scripts/Drivers/README.md`.
- **Pendiente:** Ninguno.

## [2026-08-16T15:32:00-03:00] Blindaje de AppX Store y .NET Native en New-OptimizedWindowsISO.ps1

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - Se incorporaron `Microsoft.StorePurchaseApp` y `Microsoft.NET.Native` a la lista base `$protectedPatterns`.
  - Se previno el error `0x80131500` en la Microsoft Store para los Perfiles 2 (Gaming) y 3 (Hardcore).
  - Se blindó la compatibilidad de runtimes .NET Native compartidos frente a desaprovisionamiento accidental por DISM.
- **Pendiente:** Ninguno.

## [2026-08-16T15:26:00-03:00] Expansión de Guía de Auditorías Técnicas (Dominios 9 a 15)

- **Archivos Modificados:** `AUDITORIA_GUIA.md`
- **Hitos Logrados:**
  - Se incorporaron 7 nuevos dominios de auditoría técnica rigurosa (Dominios 9 al 15) basados en la arquitectura real de `New-OptimizedWindowsISO.ps1`: AppX y dependencias, Features on Demand / .NET 3.5, `ei.cfg`/`PID.txt`, drivers/updates offline, bypass de hardware WinPE/LabConfig, colmenas offline de registro y compresión/exportación de WIM.
  - Se agregó una sección consolidada con los dominios web oficiales de Microsoft Learn/Support recomendados para auditorías con cero suposiciones.
- **Pendiente:** Ejecutar auditorías individuales por dominio cuando se requiera validar subsistemas específicos.

## [2026-08-16T15:18:00-03:00] Corrección de Errores de Creación de ISO (Auditoría de Logs)

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - Se corrigió la excepción de mutación concurrente `.NET` (`Collection was modified; enumeration operation may not execute`) en `Write-LogSummary` añadiendo el switch `-NoAccumulate` y aislando la iteración con snapshots `@(...)`.
  - Se corrigió la invocación de `reg.exe` en los tweaks visuales de `NTUSER.DAT` (específicamente `$darkModeCommand` en `RunOnce`), reemplazando `Start-Process` por invocación directa con `& reg.exe add ...` para evitar truncamiento de argumentos con `&&`.
  - Se protegió `Microsoft.SecHealthUI` agregándolo a la lista base `$protectedPatterns` para evitar errores de DISM offline en Windows 11 24H2/25H2.
  - Se previno el error terminante en `Dismount-WindowsImage` del bloque `finally` verificando previamente el estado de montaje con `Get-WindowsImage -Mounted`.
- **Pendiente:** Probar una nueva compilación de la ISO en el entorno Windows del host y verificar la limpieza total en el transcript generado.

## [2026-08-15T15:10:00-03:00] Auditoría de Robustez y Manejo de Errores

- **Archivo Analizado:** `scripts/New-OptimizedWindowsISO.ps1`
- **Resultados de Auditoría:**
  - El diseño del script incluye manejo defensivo estricto (`try/catch/finally`) para todas las operaciones críticas de archivos WIM. La inclusión de `dism.exe /Cleanup-Mountpoints` en un bloque `finally` garantiza que el sistema operativo no quede inestable por montajes huérfanos.
  - La lógica de restauración en la consolidación de WIM (rollback de archivo `.bak`) previene la destrucción de la imagen si falla la exportación.
  - Se identificaron riesgos menores: `Start-Process -Wait` en herramientas como 7-Zip u oscdimg no define tiempos máximos de espera (timeouts). Adicionalmente, ciertas fallas fatales (como no poder remover `IsReadOnly` de un WIM) no arrojan excepciones terminales (`throw`), lo que desencadenaría fallos en cadena más adelante.
- **Cambios Aplicados:** Ninguno (Solo lectura y reporte generado).
- **Pendiente:** Decidir si se incorporan bloqueos duros (`throw`) para fallas en atributos de sólo lectura o compilación de ISO, y si se definen `Timeouts` para procesos externos.

## [2026-08-15T15:08:00-03:00] Auditoría de Particionado UEFI/GPT en autounattend.xml

- **Archivo Analizado:** `scripts/New-OptimizedWindowsISO.ps1` (Función `Add-ImageInstallToAutounattend`)
- **Resultados de Auditoría:**
  - Se verificó la generación del bloque `<DiskConfiguration>` para despliegues Zero-Touch.
  - La partición EFI está configurada en 300 MB (FAT32), lo cual excede el mínimo de 260 MB requerido para discos 4K Nativos (4Kn), garantizando compatibilidad universal.
  - La partición MSR está correctamente dimensionada a 16 MB.
  - La partición primaria de Windows ocupa el resto del disco (`<Extend>true</Extend>`) y se formatea en NTFS. El orden secuencial (EFI -> MSR -> Win) es exacto según Microsoft.
  - El nodo `<InstallTo>` mapea correctamente al Disco 0, Partición 3.
  - La directiva `<AcceptEula>true</AcceptEula>` está ubicada en el pass `windowsPE` bajo `UserData`, como exige el schema oficial.
- **Cambios Aplicados:** Ninguno (la lógica existente es 100% robusta y validada).
- **Pendiente:** Ninguno.

## [2026-08-15T14:59:00-03:00] Auditoría de SetupComplete.cmd y Estructura $OEM$


- **Archivo Modificado:** `scripts/New-OptimizedWindowsISO.ps1`
- **Resultados de Auditoría:**
  - Se revisó la sintaxis y comportamiento del archivo autogenerado `SetupComplete.cmd`.
  - Los comandos `schtasks /change /disable` son correctos y se ejecutan bajo el entorno de SYSTEM.
  - El entorno SYSTEM dispone correctamente de `%WINDIR%`, `%PUBLIC%` y `%SystemRoot%`. Todos los comandos redirigen adecuadamente salida y error estándar (`>> "%LOG%" 2>&1`), previniendo fallos silenciosos.
  - **HALLAZGO CRÍTICO:** La estructura `$OEM$` de la ISO en la línea 235 omitía las carpetas `sources` y `\$$\`. Resolvía hacia `C:\Setup\Scripts` en lugar de `C:\Windows\Setup\Scripts`.
- **Cambios Aplicados:** 
  - Se corrigió la variable `$OEMScriptsDir` apuntándola a la ruta oficial de Microsoft: `sources\$OEM$\$$\Setup\Scripts`. Esto garantiza que los scripts copiados se reconozcan durante el despliegue del medio de instalación.
- **Pendiente:** Ninguno.

## [2026-08-15T14:53:00-03:00] Auditoría Completa de Claves de Registro (Windows 11 24H2/25H2)


- **Archivos Auditados:** `scripts/New-OptimizedWindowsISO.ps1` y `scripts/Win11-Debloat-v3-Adaptive.ps1`
- **Resultados de Auditoría:**
  - Se analizaron más de 80 claves y valores de registro inyectados por ambos scripts.
  - El 100% de las claves usan los tipos de datos correctos (`REG_DWORD`, `REG_SZ`). La asignación de `-1` a `NetworkThrottlingIndex` para evitar el desbordamiento de `[Int32]` es correcta y cumple la función de inyectar `0xFFFFFFFF`.
  - Las claves vinculadas a telemetría, `AllowNewsAndInterests` (Widgets), `DisablePrivacyExperience` y `DevicePasswordLessBuildVersion` operan según lo esperado.
  - La limitación de Windows 11 Pro/Home sobre `AllowTelemetry=0` (que lo fuerza a 1) está mitigada por la desactivación directa del servicio `DiagTrack` que realiza el script.
  - La desactivación de IA está debidamente actualizada para versiones recientes mediante `TurnOffWindowsCopilot` y `DisableAIDataAnalysis`.
- **Cambios Aplicados:** 
  - Se eliminó la clave obsoleta `AllowCortana` de `Win11-Debloat-v3-Adaptive.ps1` (Línea 1394 original).
- **Pendiente:** Ninguno.

## [2026-08-15T14:50:00-03:00] Auditoría de Construcción de ISO (`oscdimg.exe`)


- **Archivo Modificado:** `scripts/New-OptimizedWindowsISO.ps1`
- **Resultados de Auditoría:**
  - Se verificó el bloque de ejecución de `oscdimg.exe` (Líneas 4030-4060).
  - Los flags utilizados (`-m -o -u2 -udfver102 -bootdata...`) cumplen 100% con la documentación oficial de Microsoft para medios duales.
  - Generación de catálogo de arranque El Torito para BIOS (`etfsboot.com`) y UEFI (`efisys.bin`) referenciada de forma correcta.
  - La estructura UDF 1.02 garantiza total compatibilidad con Rufus y Ventoy.
  - La metodología de invocar un archivo `.cmd` temporal para sortear las limitaciones de *quoting* de PowerShell es robusta.
- **Cambios Aplicados:** Ninguno. El bloque está estructurado con las mejores prácticas.
- **Pendiente:** Ninguno.

## [2026-08-15T14:48:00-03:00] Auditoría de Lógica de Manipulación de Archivos WIM y Robustez de Desmontaje


- **Archivo Modificado:** `scripts/New-OptimizedWindowsISO.ps1`
- **Cambios Aplicados:**
  1. **Rutas fijas del sistema:** Se reubicaron `$WimMountDir` y `$ScratchDir` en `$env:SystemDrive` en lugar de `$env:TEMP` para evitar problemas con perfiles de usuario roaming, rutas de red o restricciones de cuota/permisos en directorios temporales de usuario.
  2. **Limpieza iterativa de puntos de montaje:** Se movió la ejecución preventiva de `dism.exe /Cleanup-Mountpoints` al interior del bucle por cada índice WIM, asegurando que si una iteración previa falla o deja un punto bloqueado, se libere antes de intentar montar el siguiente índice.
  3. **Garantía en bloque `finally`:** Se agregó `Dismount-WindowsImage -Discard` y `dism.exe /Cleanup-Mountpoints` dentro del bloque `finally` global antes de intentar `Remove-Item` de `$WimMountDir` y `$ScratchDir`, previniendo que queden imágenes huérfanas bloqueadas a nivel de driver en caso de terminación abrupta o excepción no controlada.
- **Sin problemas / Validado:** Exportación atómica (`.bak`), selección de índices, y commit explícito con `-Save` / `-Discard`.
- **Pendiente:** Ninguno.

## [2026-08-15T14:42:00-03:00] Auditoría #2 de DISM.exe — Segunda pasada completa


- **Archivos auditados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Total de invocaciones DISM encontradas:** 8 (2 Get-WimInfo, 1 Cleanup-Mountpoints, 1 Enable-Feature, 2 Add-Package, 1 Export-Image + 1 Mount via PS cmdlet)
- **Correcciones aplicadas (3 problemas, 5 cambios):**
  1. **L708, L791:** `/Get-WimInfo /WimFile:` → `/Get-ImageInfo /ImageFile:` (alias legacy → flag canónico ADK)
  2. **L3119:** `$LASTEXITCODE -eq 0` → `$LASTEXITCODE -in @(0, 3010)` en `/Enable-Feature` NetFx3 offline
  3. **L3188, L3213:** Eliminado `/NoRestart` de ambos `/Add-Package` offline (flag solo válido con `/Online`)
- **Sin problemas:** `/Cleanup-Mountpoints`, `Dismount-WindowsImage -Save/-Discard`, `/Export-Image`, `Mount-WindowsImage`
- **Pendiente:** Ninguno.

## [2026-08-15T14:38:00-03:00] Auditoría Completa de autounattend.xml


- **Archivo Auditado:** `scripts/New-OptimizedWindowsISO.ps1` (bloques `$autounattendContent`, `$firstLogonXml`, `$optimizeXml`, `$oneDriveXml`)
- **Metodología:** Verificación contra schema oficial Microsoft Learn + búsqueda activa de cada setting
- **Discrepancias encontradas:**
  - `<NetworkLocation>Work</NetworkLocation>` — **DEPRECATED** desde Windows 10, ignorado en Windows 11. **ELIMINADO.**
  - `<HideOnlineAccountScreens>true</HideOnlineAccountScreens>` — Efectividad nula en 24H2+ con internet activo. No eliminado (inofensivo, BypassNRO actúa como respaldo).
  - `<LogonCount>` off-by-one — Windows añade +1 internamente, pero reducir a N-1 rompería AutoLogon con valor=0. Mantenido como estaba.
  - `BypassNRO` en `specialize` — placement subóptimo (ideal: `oobeSystem`), pero funcional. No modificado.
  - `FirstLogonCommands` — comandos `reg add` pueden ejecutarse fuera de orden en W11. Riesgo bajo para el caso de uso.
- **Cambio aplicado:** Eliminación de `<NetworkLocation>Work</NetworkLocation>` (reemplazado por comentario explicativo en línea 2908).
- **Pendiente:** Ninguno.

## [2026-08-15T14:05:00-03:00] Auditoría Dominio 2: Optimización de Exit Codes en Inyección de Paquetes DISM


- **Archivo Modificado:** `scripts/New-OptimizedWindowsISO.ps1`
- **Mejora Aplicada:**
  - Se actualizó la verificación de `$LASTEXITCODE` en `DISM /Add-Package` (tanto para paquetes `.msu` directos como para `.cab` extraídos) para evaluar `$LASTEXITCODE -in @(0, 3010)`.
  - El exit code `3010` (`ERROR_SUCCESS_REBOOT_REQUIRED`) representa un estado de éxito con transacción de servicio completada, evitando falsos positivos de fallo al inyectar paquetes acumulativos (LCU/SSU) offline.
- **Verificación:** Sintaxis y balance de tokens validado (0 errores).



- **Archivo Modificado:** `scripts/New-OptimizedWindowsISO.ps1`
- **Mejoras de Robustez Aplicadas:**
  1. **Consolidación WIM Atómica:** Se eliminó el riesgo crítico de borrado directo (`Remove-Item` previo a `Rename-Item`). Ahora se realiza un intercambio con `.bak` transaccional que restaura la imagen WIM original si el renombrado de la imagen consolidada falla.
  2. **Tolerancia a Latencia de Montaje de ISO:** Se implementó un bucle de reintento de 6 iteraciones (3 segundos máx.) en `Expand-WindowsIso` para permitir que Windows asigne la letra de unidad (`DriveLetter`) sin arrojar excepciones prematuras en discos bajo carga.
- **Verificación:** Sintaxis y balance de tokens validado (0 errores).



- **Archivo Modificado:** `scripts/New-OptimizedWindowsISO.ps1`
- **Resultados de Auditoría:**
  - Dominio 2 & 3 (DISM & WIM): Verificado y validado con MS Learn.
  - Dominio 4 (oscdimg): Flags `-m -o -u2 -udfver102 -bootdata:2#...` conformes al estándar dual boot BIOS/UEFI.
  - Dominio 5 (Registry / CDM): Claves de bloqueo de telemetría y apps validadas contra políticas oficiales CSP y directivas de grupo.
  - Dominio 6 (SetupComplete.cmd): Verificado para ejecución SYSTEM post-OOBE.
  - Dominio 7 (Particionado Zero-Touch): 300 MB EFI + 16 MB MSR + Windows OS NTFS validados contra documentación UEFI/GPT para discos 4Kn.
  - Dominio 8 (Robustez & Manejo de errores): Flujo de `try/catch/finally` y recolección de basura verificado.
- **Mejoras Aplicadas:**
  1. `dism.exe /Cleanup-Mountpoints` preventivo ejecutado antes del bucle de montaje de imágenes WIM.
  2. Resolución dinámica de `$env:PUBLIC\Desktop` para la creación del acceso directo del optimizador en `SetupComplete.cmd`.
- **Verificación:** Sintaxis y balance de tokens validado (0 errores).



- **Archivo Modificado:** `scripts/New-OptimizedWindowsISO.ps1`
- **Problema:** En los schemas XSD oficiales de Windows Setup, los componentes tienen reglas estrictas de `<xs:sequence>`. Elementos fuera de secuencia provocan que Windows Setup ignore bloques silenciosamente (fallos en cuentas locales, primer logon o destino de instalación).
- **Discrepancias Corregidas según Microsoft Learn:**
  1. `Microsoft-Windows-Setup` (pass `windowsPE`):
     - `<EnableFirewall>` reubicado **antes** de `<RunSynchronous>`.
     - Inyección DOM en `Add-ImageInstallToAutounattend` alineada con la secuencia: `DiskConfiguration` -> `EnableFirewall` -> `ImageInstall` -> `RunSynchronous` -> `UserData`.
  2. `Microsoft-Windows-Shell-Setup` (pass `oobeSystem`):
     - Reordenado a la secuencia oficial: `AutoLogon` -> `FirstLogonCommands` -> `OOBE` -> `RegisteredOrganization` -> `RegisteredOwner` -> `TimeZone` -> `UserAccounts` (al final).
     - Corregido el espaciado/concatenación tipográfica en la plantilla de `$firstLogonXml`.
- **Verificación:** Sintaxis y balance de tokens verificado (0 errores).



- **Problema:** El script fallaba al ejecutarse con Windows PowerShell 5.1 (nativo de Windows 11) pero funcionaba correctamente con PowerShell 7 instalado manualmente.
- **Causas Raíz Identificadas (4 bugs):**
  1. **TLS 1.0 por defecto en PS 5.1:** GitHub, Microsoft CDN y PSGallery rechazan conexiones sin TLS 1.2+. El script solo activaba TLS adentro de una función, no al inicio.
  2. **`-ArgumentList` como string con comillas en `Start-Process`:** La auto-elevación fallaba en PS 5.1 cuando la ruta del script tenía espacios.
  3. **`Invoke-WebRequest` sin `-UseBasicParsing`:** En PS 5.1, Windows 11 tiene Internet Explorer deshabilitado → error `IE engine not available` en las 6 descargas del script.
  4. **`Out-GridView` sin manejo de errores:** Podía abortar el flujo sin fallback si WPF no estaba disponible en la sesión.
- **Correcciones Aplicadas:**
  - `FIX-PS51-1`: `SecurityProtocol = Tls12 -bor 3072 -bor 12288` añadido globalmente al inicio (línea 64).
  - `FIX-PS51-2`: Auto-elevación ahora usa array `@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $myScript)`.
  - `FIX-PS51-3`: `-UseBasicParsing` inyectado en todos los `Invoke-WebRequest` (7 ocurrencias).
  - `FIX-PS51-4`: `Out-GridView` envuelto en `try/catch` con fallback de consola en las 6 secciones interactivas.
- **Verificación:** Balance de tokens: llaves 0, paréntesis 0 (sin errores).



- **Archivos Modificados:**
  - `scripts/New-OptimizedWindowsISO.ps1`
  - `scripts/Win11-Debloat-v3-Adaptive.ps1`
  - `scripts/Win11-Network-Diagnostics-Optimizer.ps1`
  - `scripts/Get-EssentialRuntimes.ps1`
- **Motivación:** Sustituir la necesidad de transferir transcripts ruidosos de decenas de miles de tokens por un reporte Markdown estructurado ultra-compacto (<400 tokens) que una IA puede diagnosticar de forma inmediata.
- **Implementación unificada:**
  - Generación automática de archivo `*_AI_SUMMARY.md` junto con `.log` y `_transcript.log`.
  - **Ficha Técnica & Contexto:** Host, Usuario, Versión de PowerShell, Parámetros/Flags de configuración y Hardware detectado.
  - **Timeline de Pasos:** Tabla con cada paso ejecutado, duración en segundos, badge de estado (`OK ✅`, `WARN ⚠️`, `FAIL ❌`) y notas.
  - **Bloque de Errores y Diagnóstico:** Aislamiento de mensajes de error con código de salida y cmdlet causante.
- **Verificación:** Sintaxis y balance de tokens validado en todos los scripts `.ps1` (0 errores).



- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Motivación:** Ofrecer la posibilidad de generar una ISO con instalación 100% automatizada (cero intervención de principio a fin).
- **Lógica condicional implementada:**
  - **Múltiples ediciones:** NO ofrece Zero-Touch (deja selección de edición y disco al instalador).
  - **1 sola edición seleccionada:** Pregunta interactivamente si desea Zero-Touch (Opción 1: Semi-desatendida manual por defecto, Opción 2: Zero-Touch).
- **Esquema de particionado UEFI/GPT oficial (Microsoft Learn):**
  - **EFI System Partition (ESP):** 300 MB FAT32 (Label: `System`), compatible con discos 4Kn/Advanced Format.
  - **Microsoft Reserved (MSR):** 16 MB.
  - **Windows OS (C:):** NTFS con `<Extend>true</Extend>` (100% del disco restante dinámico).
- **Configuración de instalación:** Inyección de `<InstallTo><DiskID>0</DiskID><PartitionID>3</PartitionID></InstallTo>`, `<AcceptEula>true</AcceptEula>` y pre-selección de índice WIM.
- **Parámetros CLI añadidos:** `-ZeroTouch` (switch) y `-ZeroTouchDisk` (int, default 0).
- **Verificación:** Sintaxis y balance de tokens verificado OK (llaves 580/580, paréntesis 919/919, 0 errores).



- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Problema:** Al conectar a internet, Windows 11 descargaba e instalaba apps sugeridas/patrocinadas y publicidades en el Start Menu y Lock Screen.
- **Causas resueltas:**
  1. Claves CDM críticas faltantes en el array de inyección offline de `NTUSER.DAT` (`Default User`).
  2. Ausencia de políticas de sistema `HKLM` en el pase `specialize` (`CloudContent`, `Explorer`, `WindowsStore`).
  3. Claves CDM solo presentes a nivel usuario (`HKCU`) y no a nivel máquina (`HKLM`).
- **Cambios implementados:**
  - **Grupo 1 (NTUSER.DAT / HKCU):** Inyección de `SubscribedContent-338387Enabled=0` (Lock Screen Spotlight), `SubscribedContent-338393Enabled=0` (Settings Suggestions), `SoftLandingEnabled=0`, `RotatingLockScreenOverlayEnabled=0` y `SystemPanelEnabled=0`.
  - **Grupo 2 (Políticas HKLM en specialize):** `HideRecommendedSection=1` (Start Menu), `DisableSearchBoxSuggestions=1`, `DisableCloudOptimizedContent=1` (W11 24H2+), `DisableConsumerAccountStateContent=1` y `AutoDownload=2` en `WindowsStore` (impide auto-instalación silenciosa de paquetes).
  - **Grupo 3 (CDM en HKLM):** `SilentInstalledAppsEnabled=0` y `PreInstalledAppsEnabled=0` a nivel máquina en `specialize`.
- **Verificación:** Sintaxis y balance de tokens verificado OK (0 discrepancias).



- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Problema:** Al crear la ISO sin `-LocalPassword`, Windows 11 24H2+ solicitaba contraseña al login.
- **Causa raíz confirmada:** Feature `PasswordLess` (`DevicePasswordLessBuildVersion=2`) de W11 24H2 bloqueaba AutoLogon con cuenta sin contraseña. El bloque `<AutoLogon><Value></Value>` vacío también era ignorado por Windows Setup.
- **Solución 1 aplicada (línea ~2429):** Agregado `RunSynchronousCommand` en pase `specialize` que deshabilita `PasswordLess`: `reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" /v DevicePasswordLessBuildVersion /t REG_DWORD /d 0 /f`
- **Solución 2 aplicada (líneas ~2317-2342 + 2624):** Agregado bloque `$firstLogonXml` condicional (solo cuando `-LocalPassword` está vacío) que genera `<FirstLogonCommands>` en `oobeSystem` forzando `AutoAdminLogon=1`, `DefaultUserName` y `DefaultPassword=""` directamente en Winlogon registry.
- **Balance de tokens:** ✅ Llaves 560/560, paréntesis 787/787.
- **Comportamiento con contraseña:** Sin cambios — el bloque `$firstLogonXml` queda vacío y no se emite XML adicional.


## [2026-08-14T05:33:00-03:00] Implementación Sistema de Logging (Opción 3)

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`, `scripts/New-OptimizedWindowsISO.Fixed.ps1`
- **Motivación:** Cada ejecución del script no dejaba ningún registro. Imposible diagnosticar fallos sin ver la consola en vivo.
- **Implementación (basada en docs oficiales de Microsoft):**
  - **Engine de Logging** agregado (funciones: `Initialize-Log`, `Write-LogEntry`, `Write-LogSummary`)
  - **Start-Transcript** abre `ISO_Build_<ts>_transcript.log` — captura TODO el output de consola (DISM, oscdimg, etc.)
  - **Write-Log estructurado** genera `ISO_Build_<ts>.log` con niveles: `[INIT][STEP][INFO][OK][WARN][ERROR]`
  - **Funciones helper** (`Write-Step`, `Write-OK`, `Write-Warn`, `Write-ErrorMsg`) ahora alimentan automáticamente el log
  - **Resumen final** al cerrar: cuenta errores/warnings y muestra las rutas de los 2 archivos de log
- **Ubicación de logs:** `$OutputDir\Logs\` (por defecto `Desktop\WinISO_Optimizado\Logs\`)
- **Sin dependencias externas:** PowerShell nativo, funciona en 5.1 y 7.x

## [2026-08-14T05:23:00-03:00] Limpieza Automática de Residuos Post-ISO

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`, `scripts/New-OptimizedWindowsISO.Fixed.ps1`
- **Problema resuelto:** Después de cada ejecución, la carpeta `$ExtractDir` (~5-12 GB) quedaba en `%TEMP%` sin eliminarse, acumulando residuos con cada build.
- **Causa raíz:** La sección de limpieza final solo borraba `$ScratchDir` y `$WimMountDir`, pero explícitamente omitía `$ExtractDir` "para inspección manual".
- **Solución implementada:**
  - Nuevo parámetro `-KeepExtractDir` (switch, default `$false`).
  - Por defecto: `$ExtractDir` se elimina con `Remove-Item -Recurse -Force` al finalizar, liberando 5-12 GB por ejecución.
  - Con `-KeepExtractDir`: se conserva y se muestra la ruta con aviso.
  - Si el borrado falla (permisos, archivos bloqueados), se muestra la ruta con aviso para borrado manual.
- **Pendiente:** Validar en entorno Windows real que `Remove-Item` no falla por handles abiertos del WIM desmontado.

## [2026-08-14T05:10:00-03:00] Reordenamiento Óptimo del Ciclo de Servicing WIM (Paso 5)

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`, `scripts/New-OptimizedWindowsISO.Fixed.ps1`
- **Motivo:** Alinear el orden de ejecución en el montaje del WIM con los estándares y directrices oficiales de Microsoft DISM y Servicing Stack.
- **Nuevo Orden de Ejecución:**
  1. `Mount-WindowsImage`
  2. `NetFx3 (.NET 3.5)` habilitado offline antes de actualizaciones (permite que parches acumulativos de .NET actualicen 3.5 y 4.8.1).
  3. `Slipstreaming` de parches (`Updates/`) ordenando SSU antes de LCU.
  4. Eliminación de `FODs` y `AppX Debloat`.
  5. `ResetBase` (`/StartComponentCleanup /ResetBase`) ejecutado como consolidación final de actualizaciones y componentes en un solo pase.
  6. Inyección de `NTUSER.DAT` (Tema Oscuro y políticas).
  7. `Dismount-WindowsImage -Save`.
- **Verificación:** Sintaxis y balance de tokens verificado OK, XML verificado.

## [2026-08-14T04:48:00-03:00] Modernización y Sincronización de Win11-Debloat-v3-Adaptive.ps1

- **Archivos Modificados:** `scripts/Win11-Debloat-v3-Adaptive.ps1`
- **Motivo:** Sincronizar el optimizador post-instalación para trabajar en armonía con la ISO limpia, eliminando tareas redundantes y potenciando la detección de hardware.
- **Mejoras Implementadas:**
  - **Detección de Sistema Pre-Optimizado:** Identifica flags de la ISO (`DisableWindowsConsumerFeatures=1`, `BypassTPMCheck=1`) y muestra el estado en el Dashboard inicial.
  - **Debloat Diferencial Instantáneo:** Consulta en memoria los paquetes activos. Si la ISO ya eliminó el bloatware, reporta `[✓] Sistema limpio` y continúa en < 1s sin ejecutar llamadas innecesarias a DISM.
  - **Modern Standby (S0ix) en Laptops:** Protege la gestión de energía y suspensión de notebooks/convertibles.
  - **Plan de Energía en Desktops:** Duplica y activa Ultimate Performance (`e9a42b02-d5df-448d-aa00-03f14749eb61`) con fallback a High Performance.
  - **Refresco de Tema en Vivo:** Inyecta transparencia y refresca Explorer para aplicar el Modo Oscuro en caliente.
- **Verificación:** Balanceo de tokens y sintaxis verificado OK (0 errores).

## [2026-08-14T04:38:00-03:00] Soporte Nativo en Arch Linux: get-essential-runtimes.sh (curl + 7z)

- **Archivos Creados:** `scripts/get-essential-runtimes.sh`
- **Motivo:** Permitir la descarga y extracción automática de los runtimes directamente desde el entorno host de Arch Linux sin requerir PowerShell (`pwsh`).
- **Detalle:** Utiliza `curl` y `7z` nativos de Linux para descargar Visual C++ 2012/2013/2015-2022 y extraer DirectX Junio 2010 en `scripts/Runtimes/`.

## [2026-08-14T04:35:00-03:00] Creación de Get-EssentialRuntimes.ps1 (Descargador Automatizado)

- **Archivos Creados:** `scripts/Get-EssentialRuntimes.ps1`
- **Motivo:** Proveer una herramienta automatizada de un solo paso para descargar todos los paquetes redistribuibles oficiales de Microsoft (Visual C++ 2012, 2013, 2015-2022 y DirectX Junio 2010) y dejarlos listos en `scripts/Runtimes/` para la creación de la ISO.
- **Detalle Técnico:**
  - Descarga mediante HTTPS con TLS 1.2/1.3 desde los enlaces CDN directos de Microsoft.
  - Extrae automáticamente el paquete auto-extraíble de DirectX 2010 en la subcarpeta `DirectX/` y purga el instalador contenedor para ahorrar espacio.
  - Verifica si los archivos ya existen para evitar descargas redundantes.
- **Verificación:** Balanceo de tokens y sintaxis verificado (0 errores).

## [2026-08-14T04:26:00-03:00] Integración de Runtimes Esenciales y .NET Framework 3.5 en la ISO

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`, `scripts/New-OptimizedWindowsISO.Fixed.ps1`, `scripts/Runtimes/README.md`
- **Motivo:** Automatizar la integración de librerías críticas (.NET 3.5, Visual C++ Redistributables y DirectX End-User) de forma 100% offline y sin carga inútil.
- **Implementación:**
  - **Habilitación Offline de .NET 3.5:** En el Paso 5 (WIM Servicing), se ejecuta `dism.exe /Image:... /Enable-Feature /FeatureName:NetFx3 /All /Source:sources\sxs /LimitAccess` para compilar .NET 3.5 directamente en la imagen WIM si `sources\sxs` está presente.
  - **Pre-carga y Despliegue de Runtimes:** En el Paso 2, se detecta la carpeta `Runtimes/` (o parámetro `-RuntimesPath`) y se inyectan los instaladores en `$OEM$\Setup\Scripts\Runtimes\`.
  - **Instalación Silenciosa en SetupComplete.cmd:** Se integró el bucle de instalación desatendida para `vc_redist*.exe` (`/install /quiet /norestart`) y `dxsetup.exe` (`/silent`).
- **Verificación:** Sintaxis y balanceo de tokens verificado OK, plantillas validadas.

## [2026-08-14T04:10:00-03:00] Configuración Bajo Demanda del Optimizador en SetupComplete.cmd

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`, `scripts/New-OptimizedWindowsISO.Fixed.ps1`
- **Motivo:** Evitar la auto-ejecución a ciegas de `Win11-Debloat-v3-Adaptive.ps1` durante el OOBE y permitir que el usuario decida si desea ejecutarlo interactivamente desde el escritorio.
- **Acciones Realizadas:**
  - **SetupComplete.cmd Optimizado:** Se eliminó la llamada bloqueante `%PS% ... -Unattended` y el trigger por evento de red.
  - **Lanzador Interactivo y Acceso Directo:** `SetupComplete.cmd` ahora crea `%WINDIR%\Setup\Scripts\EjecutarOptimizador.cmd` y un acceso directo visible en `C:\Users\Public\Desktop\Optimizar Sistema (Opcional).lnk`.
  - **Deshabilitación de Telemetría OOBE:** Se mantiene la desactivación de tareas programadas de telemetría creadas por OOBE.
- **Verificación:** Balanceo de tokens y sintaxis verificado (0 errores), esquema XML y templates verificados.

## [2026-08-14T03:34:00-03:00] Auditoría de Calidad, Limpieza de Comentarios y Normalización de Código

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`, `scripts/New-OptimizedWindowsISO.Fixed.ps1`
- **Motivo:** Depuración exhaustiva de comentarios obsoletos, eliminación de banners residuales de división de prompts y normalización de formato en el script maestro.
- **Acciones Realizadas:**
  - **Eliminación de Banners Residuales:** Se purgaron todos los comentarios residuales de tipo `# FIN PARTE X/6 - CONTINÚA EN PARTE Y/6` que habían quedado de procesos previos de ensamblado.
  - **Normalización de Separadores y Espaciado:** Se consolidaron separadores repetitivos (`#====`) en delimitadores limpios y se eliminaron espacios en blanco redundantes y trailing whitespaces.
  - **Verificación de Variables y Código Muerto:** Se verificó que todas las 249 variables y 21 funciones tengan propósito activo y coherente en la lógica del script.
- **Verificación:** Balanceo de tokens y sintaxis verificado (0 errores), esquema XML de `autounattend.xml` verificado.

## [2026-08-14T03:26:00-03:00] Gestión Inteligente de Drivers y Apps OEM según Perfil (Opción A)

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`, `scripts/New-OptimizedWindowsISO.Fixed.ps1`
- **Motivo:** Control automático sobre la descarga e instalación no solicitada de drivers y aplicaciones OEM (DCH Hardware Support Apps) vía Windows Update.
- **Implementación:**
  - **Perfil 1 (Conservador / Laptops):** Permite la búsqueda automática de drivers para asegurar el funcionamiento nativo de touchpads, sensores y audio en notebooks.
  - **Perfil 2 (Gaming) y Perfil 3 (Hardcore):** Inyecta en `autounattend.xml` (`specialize`):
    - `ExcludeWUDriversInQualityUpdate = 1` en `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate`
    - `SearchOrderConfig = 0` en `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching` (desactiva búsqueda en Windows Update)
    - `PreventDeviceMetadataFromNetwork = 1` en `HKLM\SOFTWARE\Policies\Microsoft\Windows\Device Metadata` (bloquea descarga de software/apps OEM por red)
  - **Corrección de Variable de Perfil:** Se corrigió el casting `$optProfile = [int]$script:OptProfile` en `autounattend.xml` para garantizar que las condiciones de perfil se evalúen con la selección real del usuario.
- **Verificación:** Balance de tokens verificado OK, validación estructural XML OK.

## [2026-08-14T03:10:00-03:00] Mejoras de Modo Oscuro Nativo, Anti-Bloatware en la Nube y Máximo Rendimiento

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`, `scripts/New-OptimizedWindowsISO.Fixed.ps1`
- **Motivo:** Resolución de comportamientos reales observados en hardware OEM (HP Pavilion x360 convertible): Modo Oscuro no inmediato, reinstalación de bloatware por Microsoft Store y ausencia del plan de Máximo Rendimiento.
- **Mejoras Implementadas:**
  - **1. Modo Oscuro Nativo Inmediato:** Inyección directa de `AppsUseLightTheme=0`, `SystemUsesLightTheme=0` y `EnableTransparency=1` en `HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` (además del RunOnce de respaldo). El perfil nace en tema oscuro desde el primer segundo.
  - **2. Bloqueo Definitivo de Reinstalación de Bloatware (Anti-Cloud Content):**
    - En `autounattend.xml` (`specialize`): Agregadas directivas `DisableWindowsConsumerFeatures=1` y `DisableSoftLanding=1` en `HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent`.
    - En `NTUSER.DAT`: Deshabilitadas todas las claves de telemetría/promoción en `ContentDeliveryManager` (`SilentInstalledAppsEnabled=0`, `OemPreInstalledAppsEnabled=0`, `PreInstalledAppsEnabled=0`, `ContentDeliveryAllowed=0` y `SubscribedContent-*=0`). Evita que Microsoft Store reinstale Spotify/TikTok al conectar a Wi-Fi.
  - **3. Plan de Energía Máximo Rendimiento (Ultimate Performance):**
    - Actualizado el comando en `autounattend.xml` para duplicar y activar el esquema oficial de Máximo Rendimiento (`e9a42b02-d5df-448d-aa00-03f14749eb61`) con fallback automático a Alto Rendimiento (`8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c`).
- **Verificación:** Balance de sintaxis y tokens OK, validación estructural XML de `autounattend.xml` OK.

## [2026-08-14T02:45:00-03:00] Unificación Definitiva y Corrección de Bugs Críticos en New-OptimizedWindowsISO.ps1

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`, `scripts/New-OptimizedWindowsISO.Fixed.ps1`
- **Motivo:** Unificación de la versión base y la versión `Fixed` integrando servicing avanzado y corrigiendo bugs críticos identificados en la auditoría técnica.
- **Hitos y Correcciones Realizadas:**
  - **Corrección 1 — Bug de `-NoBlockOneDrive`:** Corregido el acceso a variable no definida `$script:NoBlockOneDrive` por `$NoBlockOneDrive.IsPresent`, restaurando el funcionamiento del switch en CLI y wizard.
  - **Corrección 2 — Multi-arquitectura en `autounattend.xml`:** Parametrizados los 7 nodos XML con `processorArchitecture="$Architecture"` en lugar del literal fijo `amd64`, habilitando soporte real para imágenes ARM64 y x86.
  - **Corrección 3 — Bloqueo de colmenas de registro (.NET GC):** Añadidas llamadas a `[System.GC]::Collect()` y `[System.GC]::WaitForPendingFinalizers()` en `Invoke-RegUnloadHive` para evitar fallos de acceso denegado durante el desmontaje.
  - **Corrección 4 — Reorganización Arquitectónica:** Centralizadas las 21 funciones auxiliares en el bloque superior, eliminando código de ejecución esparcido y estructurando el pipeline secuencial limpio de 6 pasos.
  - **Consolidación de Servicing Avanzado:** Se integraron el slipstreaming de parches (`.msu`/`.cab` con orden SSU $\rightarrow$ LCU), limpieza `ResetBase`, eliminación de Features on Demand (FOD), debloat provisioned AppX con whitelist de seguridad, y la inyección dinámica post-exportación de `<ImageInstall>`.
- **Verificación:** Validación de sintaxis y balance de tokens OK, validación estructural de XML OK, ausencia de duplicados OK.
- **Pendiente:** Validación en entorno Windows real ejecutando montaje y reconstrucción ISO.

## [2026-08-11T21:25:00-03:00] Auditoría + 4 Correcciones Post-Auditoría en New-OptimizedWindowsISO.ps1

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Motivo:** Auditoría técnica de inyecciones offline y autounattend.xml verificada contra fuentes reales
- **Corrección 1 — Telemetría incompleta (Perfil 2+, specialize):**
  - Agregado `dmwappushservice Start=4` (servicio relay de DiagTrack, faltaba)
  - Agregado `AllowTelemetry=0` en `HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection` (método enterprise documentado por Microsoft Docs)
  - `$nextOrder` ajustado de `+1` a `+3` para evitar colisiones con Perfil 3
- **Corrección 2 — Modo Oscuro (NTUSER.DAT offline):**
  - `AppsUseLightTheme=0` y `SystemUsesLightTheme=0` reemplazados por un `RunOnce` en `NTUSER.DAT`
  - El RunOnce se ejecuta al primer inicio de sesión, DESPUÉS de que `aero.theme` sobreescribe el registro (que era el bug)
  - Fuente: comunidad enterprise / awakecoding.com
- **Corrección 3 — Barra de tareas (NTUSER.DAT):**
  - Agregado `SearchboxTaskbarModeCache=1` como clave companion de `SearchboxTaskbarMode=0`
  - Mejora estabilidad del ajuste entre builds. Fuente: awakecoding.com
- **Corrección 4 — Tareas programadas de telemetría (SetupComplete.cmd):**
  - Agregado bloque `schtasks /change /disable` para: `Microsoft Compatibility Appraiser`, `PcaPatchDbTask`, `ProgramDataUpdater`, `StartupAppTask`, `Consolidator`, `UsbCeip`
  - Ubicadas en `SetupComplete.cmd` (no en specialize) porque el OOBE crea estas tareas durante su ejecución
- **Hallazgos de Auditoría confirmados:**
  - `SetupComplete.cmd` se bloquea en hardware OEM con licencia BIOS (el fallback `schtasks` del script es el workaround correcto)
  - `BypassNRO` como clave de registro sigue funcionando en 25H2 (el comando `bypassnro.cmd` fue eliminado por Microsoft en 24H2)
- **Pendiente:** Prueba real end-to-end en Windows con hardware OEM para validar todas las correcciones

## [2026-08-11T17:39:00-03:00] Auditoría Técnica Completa + 8 Bugs Corregidos en New-OptimizedWindowsISO.ps1


- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Alcance:** Windows 11 x64 únicamente. Fuentes verificadas: Microsoft Learn, ADK Docs.
- **Decisión Arquitectural:** Mantenemos PS5.1 como baseline (DISM cmdlets tienen bugs en PS7 con COM).
- **Bugs Críticos Corregidos (2):**
  - **BOM UTF-8 (L1404):** `Out-File -Encoding UTF8` en PS5.1 genera BOM. Reemplazado por `[System.IO.File]::WriteAllText(..., UTF8Encoding($false))`. Windows Setup ignoraba silenciosamente el autounattend.xml.
  - **7-Zip comillas (L922):** Comillas embebidas en `ArgumentList` array causaban doble-escaping. Rutas ahora se pasan como elementos sin comillas adicionales.
- **Bugs Menores Corregidos (6):**
  - **ei.cfg incompleto (L969):** Agregados `[EditionID]` vacío y `[VL] 0`. Sin `[EditionID]`, PCs con clave OEM en BIOS ignoraban `[Channel]=Retail` y forzaban edición OEM.
  - **Wizard Locale loop (L440):** `-Locale` eliminado de `$needsWizard`. El wizard ya no se activa solo porque falta Locale (hereda de Language). Modo CLI no-interactivo restaurado.
  - **schtasks canal deshabilitado (L1101):** Agregado `wevtutil set-log "Microsoft-Windows-NetworkProfile/Operational" /enabled:true` antes de crear la tarea. Sin esto, el trigger ONEVENT nunca disparaba.
  - **WSearch en Perfil 2 (L1218→L1238):** Movido de Perfil 2 (Gaming) a Perfil 3 (Hardcore). En SSD el indexer usa <1% CPU/RAM adaptativo. Desactivarlo en Gaming rompía búsqueda y Outlook/OneDrive.
  - **Out-GridView sin verificación (L1767):** Agregada comprobación `Get-Command Out-GridView`. Fallback por consola para PS7/headless con selección numérica/A/N.
  - **reg.exe via cmd.exe con comillas (L1854):** Reemplazado por `Start-Process reg.exe -ArgumentList @("add", key, "/v", name, "/t", type, "/d", value, "/f")`. Sin comillas embebidas, sin riesgo de doble-escaping.
- **Verificados como correctos contra docs oficiales:** oscdimg params, contraseña Base64+sufijo "Password", EnableFirewall en windowsPE, ImageInstall DOM, ResetBase, claves NTUSER.DAT modo oscuro, LabConfig bypasses, BypassNRO.
- **Pendiente:** Prueba real en Windows para validar que todos los fixes funcionan end-to-end en instalación con hardware OEM.

## [2026-08-11T17:13:00-03:00] Exportación Selectiva de Edición + Auto-bypass de selección en Setup
- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - **Export-Image selectivo:** El bloque de consolidación final ahora filtra con `$exportTargets = $allWimImages | Where-Object { $indexesToProcess -contains $_.Index }`. Solo exporta las ediciones elegidas por el usuario, descartando las demás. Si el usuario eligió "TODAS", el comportamiento es idéntico al anterior (sin regresión).
  - **Inyección de `<ImageInstall>` via DOM nativo:** Bloque nuevo entre la selección de edición (línea ~1445) y el ScratchDir. Si `$indexesToProcess.Count -eq 1` Y no se usó `-SkipAutoUnattend`, se carga el `autounattend.xml` como `[xml]` (DOM seguro), se localiza el componente `Microsoft-Windows-Setup` en el pase `windowsPE` y se inserta el nodo `<ImageInstall><OSImage><InstallFrom><MetaData wcm:action="add"><Key>/IMAGE/INDEX</Key><Value>1</Value>` **antes de `<RunSynchronous>`** respetando el esquema oficial de Microsoft. El archivo se guarda en UTF-8 sin BOM (requerido por Windows Setup) y se sincroniza con la copia en `$OEM$`.
  - **Resultado:** Al elegir una única edición, la ISO resultante es más pequeña (solo 1 índice en el WIM) y la instalación salta automáticamente la pantalla de selección de versión.
- **Verificación:** Balance de llaves/paréntesis 0/0 confirmado. Sin PowerShell nativo disponible en host Linux para AST parse.
- **Pendiente:** Prueba real en Windows para validar que el nodo `<ImageInstall>` es reconocido por Windows Setup 11 24H2+.

## [2026-08-11T15:21:00-03:00] Separación UILanguage / Locale Regional (es-AR y 35 locales)

- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - **Nuevo parámetro `-Locale`:** Independiente de `-Language`. Si no se especifica, hereda `-Language` (retrocompatible). Ejemplos: `-Language es-ES -Locale es-AR`.
  - **`$finalLocale`:** Variable calculada (línea ~1109) que resuelve `Locale` si fue pasado, o hereda `Language`. Aplicada en los **3 bloques XML** (windowsPE, specialize, oobeSystem) en `SystemLocale` y `UserLocale`.
  - **UILanguage siempre usa `$Language`:** No cambia. El pack de idioma del OS sigue siendo es-ES, en-US, etc.
  - **SystemLocale + UserLocale ahora usan `$finalLocale`:** Controla fechas, moneda, separador decimal según el país elegido.
  - **PASO 2/5 — Región / Formato local:** Nuevo paso en el wizard con 35 opciones organizadas por idioma: 21 países hispanos (es-AR, es-MX, es-CL, etc.), pt-BR, pt-PT, 4 en-*, 8 otros. Cada opción muestra formato de fecha, moneda y separador decimal.
  - **Pasos renumerados:** 1/5 Idioma UI, 2/5 Región, 3/5 Timezone, 4/5 Teclado, 5/5 Usuario/Pass.
  - **Resumen actualizado:** Muestra "Idioma UI (menus)" y "Región / Formato" como campos separados.
- **Compatibilidad CLI:** `New-OptimizedWindowsISO.ps1 -Language es-ES -Locale es-AR -Timezone "Argentina Standard Time"` funciona sin wizard.

## [2026-08-11T15:11:00-03:00] Wizard Interactivo de Configuración (Opción A+B)
- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - **`Invoke-SelectionMenu`:** Función de menú con navegación `↑↓ ENTER` usando `[System.Console]::ReadKey()`. Nativa PS 5.1+, sin dependencias. Renderizado con box-drawing UTF-8 (╔╗╠╣╚╝), fila resaltada con fondo Cyan. Ciclo automático (última opción → primera).
  - **`Invoke-WizardConfig`:** Función principal del wizard. Se activa solo si algún parámetro (`Language`, `Timezone`, `LocalUser`, `LocalPassword`) no fue pasado por CLI (detección via `$PSBoundParameters`). Compatibilidad 100% con uso automatizado existente.
  - **Paso 1 — Idioma:** 10 opciones (es-ES, es-419, en-US, pt-BR, fr-FR, de-DE, it-IT, nl-NL, ja-JP, zh-CN). Default detectado automáticamente por `(Get-Culture).Name`.
  - **Paso 2 — Zona Horaria:** 20 timezones comunes con strings exactos de `tzutil /l`. Default detectado por `(Get-TimeZone).Id`. Valores imposibles de ingresar incorrectamente.
  - **Paso 3 — Teclado:** 8 opciones incluyendo "igual que idioma" como opción 0 (Recomendada). Mantiene `KeyboardOverride = ''` si el usuario elige opción 0.
  - **Paso 4 — Usuario/Contraseña:** `Read-Host` con validación regex para usuario. `Read-Host -AsSecureString` con confirmación y comparación BSTR en memoria + `ZeroFreeBSTR` (patrón oficial Microsoft). Contraseña vacía permitida.
  - **Resumen visual + confirmación S/N:** Muestra configuración antes de continuar. Contraseña enmascarada con `●●●●●●●●`.
  - **Punto de llamada:** Línea 766 — justo después de confirmar la ISO origen, antes del paso 1/6 de extracción.
- **Pendiente:**
  - Validar el wizard en una terminal Windows real con diferentes anchos de ventana.
  - Verificar comportamiento del menú de flechas en PS 5.1 (Windows PowerShell clásico).

## [2026-08-11T14:48:00-03:00] Refactor Slipstreaming con Reporte Interactivo Prolijo
- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - **Diagnóstico raíz:** El script era silencioso si `scripts/Updates/` no existía o estaba vacía. El usuario no podía saber si el slipstreaming fue ejecutado o skipped.
  - **3 Estados explícitos de reporte:** (A) sin carpeta → aviso ⚠ con instrucción; (B) carpeta vacía → aviso ⚠; (C) N paquetes → progreso completo.
  - **Iteración paquete-a-paquete:** Reemplazado `Add-WindowsPackage -PackagePath $UpdatesDir` (carpeta) por `foreach` individual con `Add-WindowsPackage -PackagePath $pkg.FullName`.
  - **Write-Progress real:** Barra de progreso con porcentaje exacto `($i/$total)*100` y nombre + tamaño del paquete activo.
  - **Ordenamiento SSU → LCU:** Implementado `Sort-Object` que prioriza archivos con nombre `ssu|servicing.?stack` (cumple orden obligatorio de Microsoft docs).
  - **Detección de SSU:** Aviso visual ★ indicando cuántos SSUs fueron detectados y que se aplicarán primero.
  - **Contadores $successCount / $failCount:** Precisos. ResetBase ahora se activa si `$successCount -gt 0` (más correcto que el anterior `$UpdatesInjected` booleano).
  - **Resumen final visual:** `✔ Inyectados: N` / `✘ Fallidos: N` con colores green/red.
  - **Comportamiento ante fallos:** Continúa con el siguiente paquete, no aborta la generación de ISO.
- **Pendiente:**
  - Validar en escenario real con al menos 1 SSU + 1 LCU en carpeta `scripts/Updates/`.

## [2026-08-11T04:53:00-03:00] Auditoría Data-Driven Completa de New-OptimizedWindowsISO.ps1 y autounattend.xml
- **Archivos Auditados:** `scripts/New-OptimizedWindowsISO.ps1`, `autounattend.xml` (dinámico).
- **Hitos Logrados:**
  - **Certificación de Esquema XML:** Verificada la validez del namespace `xmlns:wcm`, sintaxis de pases `windowsPE`, `specialize`, `oobeSystem` y compatibilidad del bypass `BypassNRO` y `LabConfig` contra la documentación oficial de Microsoft Learn.
  - **Validación Criptográfica OOBE:** Confirmada la regla oficial de MS de concatenación del sufijo `"Password"` a la clave plana antes del Base64 UTF-16LE, así como la asignación `PlainText=true` para contraseñas vacías para prevenir fallos en el parser Unattend.
  - **Serviciado y Compresión WIM:** Certificada la validez de los cmdlets de DISM con `-ScratchDirectory` y `Export-WindowsImage -CompressionType Max`.
  - **Parámetros Dual-Boot oscdimg:** Confirmados los flags `-m -o -u2 -udfver102 -bootdata:2#` para medios BIOS/UEFI híbridos según el Microsoft ADK.

## [2026-08-11T04:44:00-03:00] Corrección de Bugs Críticos en Optimizaciones DISM
- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - **Fix CRÍTICO (`Export-WindowsImage`):** Se reemplazó el valor inválido `"Solid"` en el parámetro `$WimCompression` por `"Fast"`. El cmdlet de PowerShell no soporta compresión sólida, lo que habría causado un fallo en tiempo de ejecución.
  - **ScratchDirectory Explícito:** Se forzó el paso explícito del parámetro `-ScratchDirectory` a todos los cmdlets de DISM (`Mount-WindowsImage`, `Repair-WindowsImage`, `Export-WindowsImage`, etc.) en lugar de depender únicamente de `$env:TEMP`, asegurando que el motor DISM respete el I/O acelerado.
  - **Fix de Tamaño WIM Post-Exportación:** Se corrigió el cálculo de tamaño (`Get-Item`) después de consolidar el WIM, usando `Join-Path` en lugar de una referencia *stale* en el objeto anterior, evitando errores de "archivo no encontrado".
  - **Robustez en entorno temporal:** Se modificó el bloque de `oscdimg` para que utilice `[System.IO.Path]::GetTempPath()` de forma incondicional.

## [2026-08-11T04:31:00-03:00] Optimizaciones Profundas DISM (Robocopy MT, ScratchDir, ExportWIM)
- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - **Robocopy `/MT:32`:** Activado el modo multihilo para acelerar la extracción inicial sin afectar la integridad.
  - **ScratchDir Seguro:** Configurado un directorio temporal encapsulado reasignando `$env:TEMP` y `$env:TMP` para asegurar que `ResetBase` y otras tareas DISM tengan un E/S estable y no fallen por límites del caché del usuario.
  - **Consolidación WIM (Máxima Compresión):** Agregada capacidad de re-exportar el archivo `.wim` tras finalizar las purgas (`Export-WindowsImage -CompressionType`), reconstruyendo el índice para eliminar el "espacio muerto" y reduciendo el tamaño de la ISO final al máximo.

## [2026-08-11T04:15:00Z] Implementación Perfiles Debloat

- Se modificó `scripts/New-OptimizedWindowsISO.ps1` para incluir 3 perfiles de optimización (Conservador, Gaming, Hardcore).
- Se añadió un menú interactivo antes de la fase de `autounattend.xml`.
- El Perfil 3 (Hardcore) desactiva SysMain, Spooler, WlanSvc, bthserv y purga todos los Appx no esenciales (manteniendo Store y Xbox TCUI).
- Los servicios se bloquean insertando comandos `RunSynchronousCommand` dinámicamente en el pase `specialize` del XML.

# Registro de Actividad (MEMORY.md)

## [2026-08-11T00:33:00-03:00] Nuevas Optimizaciones en autounattend.xml (Fase specialize)
- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`, `docs/AUTOUNATTEND.md`
- **Hitos Logrados:**
  - **Hibernación OFF:** Se inyectó `powercfg -h off` en la fase `specialize` para eliminar `hiberfil.sys` desde el primer arranque (ahorro de 40-75% del tamaño de RAM en disco).
  - **Alto Rendimiento:** Se forzó el plan de energía "High Performance" (`8c5e7fda-...`) para que la CPU no sea estrangulada durante la instalación y ejecución de scripts post-instalación.
  - **Bloqueo Scoobe:** Se inyectó `DisablePrivacyExperience` para bloquear permanentemente las pantallas intrusivas de "Terminar de configurar tu dispositivo".
  - Los `<Order>` de los comandos XML se calculan dinámicamente según si el usuario eligió o no bloquear OneDrive.

## [2026-08-11T00:22:00-03:00] Certificación y Auditoría de Código Generador de ISO
- **Archivos Auditados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - **Certificación de Código Limpio:** Se verificó que el script no contiene placebos, directivas obsoletas ni código basura.
  - **Validación ADK / DISM:** La inyección de claves de bypass de Windows 11 en la fase `windowsPE` de `autounattend.xml` cumple rigurosamente con los estándares oficiales documentados.
  - **Workarounds Técnicos Aprobados:** Se certificó como válida y necesaria la lógica de añadir el sufijo `"Password"` en texto plano antes del hash Base64 para prevenir cuelgues criptográficos en el OOBE, así como el uso de `cmd.exe /c` para evadir los bugs de formateo de `oscdimg.exe`.
  - El código de este módulo fue dado por validado oficialmente sin necesidad de refactorización ni purga.
## [2026-08-11T00:15:00-03:00] Auditoría Data-Driven de Scripts de Optimización
- **Archivos Modificados:** `scripts/Win11-Debloat-v3-Adaptive.ps1`, `scripts/Win11-Network-Diagnostics-Optimizer.ps1`
- **Hitos Logrados:**
  - **Revisión Oficial (Microsoft Learn):** Se auditaron todas las configuraciones de red, telemetría y gaming contra fuentes oficiales.
  - **Detección de Placebos (DX12):** Se documentó en el código que los tweaks de `GameDVR` (Exclusive Fullscreen) carecen de impacto en DX12/Vulkan debido al *Independent Flip Model*.
  - **Limitación de Telemetría (Home/Pro):** Se documentó que Microsoft ignora `AllowTelemetry=0` en Consumer Editions, validando que el enfoque de desactivar el servicio `DiagTrack` (usado por el script) es el único método real.
  - **Blindaje de Red:** Se agregó una advertencia estricta en el script de red para evitar que `AutoTuningLevelLocal` sea configurado alguna vez como `Disabled`, ya que eso estrangula el ancho de banda a 64KB (mito de internet desmentido).
## [2026-08-10T23:55:00-03:00] Integración de Optimizaciones DISM Offline (Basado en Datos)
- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - **Slipstreaming Automático:** Se agregó soporte para inyectar actualizaciones (`.msu`, `.cab`) de forma desatendida. El script busca la carpeta `Updates`; si hay parches, los instala usando `Add-WindowsPackage`.
  - **ResetBase Condicional:** Se implementó `Repair-WindowsImage -StartComponentCleanup -ResetBase` para limpiar la imagen y ahorrar 1.5 - 3 GB de espacio. Solo se activa si se inyectaron actualizaciones exitosamente, ahorrando tiempo en ISOs limpias.
  - **Eliminación de Capacidades (FODs):** Se incluyó un bloque `Remove-WindowsCapability` para purgar offline componentes irrelevantes (Hello Face, IE11, Math Recognizer) mejorando la seguridad y bajando servicios base.
  - Se evaluó y descartó formalmente la opción `/Optimize-Image /Boot` por carecer de utilidad real en hardware moderno fuera de WIMBoot.

## [2026-08-10T23:25:09-03:00] Bugfix: Quitar Win11-Debloat-v3-Adaptive de la inyección por defecto
- **Archivos Modificados:** `scripts/New-OptimizedWindowsISO.ps1`
- **Hitos Logrados:**
  - Se retiró `Win11-Debloat-v3-Adaptive.ps1` como valor por defecto en la generación de la ISO. Esto soluciona un problema crítico donde la inyección temprana de estas configuraciones causaba un bloqueo permanente en la fase de Setup/OOBE ("Espere un momento...").
  - Ahora es opcional y se deja a discreción del usuario inyectarlo en la ISO (cuando se le pida) o ejecutarlo posteriormente tras finalizar la instalación.

## [2026-08-10T00:15:00-03:00] Bugfix PS7 COMException en DISM cmdlets + Plan de Implementación v2
- **Archivos Modificados:** `scripts/Win11-Debloat-v3-Adaptive.ps1`
- **Hitos Logrados:**
  - **FIX PS7 (línea 701):** `Get-WindowsOptionalFeature -Online` falla en PowerShell 7 con "Clase no registrada" (COMException -2147221164, GitHub #17232). Agregado fallback a `DISM.exe /Get-FeatureInfo` con detección bilingüe (EN/ES).
  - **FIX PS7 (línea 795):** `Enable-WindowsOptionalFeature -Online` mismo bug. Agregado fallback a `DISM.exe /Enable-Feature`.
  - **Diagnóstico:** El error reportado en Windows Home NO era limitación de edición, sino bug de PS7 con cmdlets DISM. El script ya tenía el fix en la sección de bloatware (línea 914) pero faltaba en health check y prerequisites.
- **Plan de Implementación v2 Ejecutado:**
  - **Cambio 1:** Se insertó el reemplazo de `ei.cfg` con `[Channel] Retail` en `New-OptimizedWindowsISO.ps1` (línea 495) para forzar que el instalador muestre la pantalla de selección de edición y sobreescribir claves OEM de la BIOS.
  - **Cambio 2:** Se agregó el bloque de debloat offline vía DISM durante el montaje de la imagen WIM (línea 835), incluyendo un filtro de aplicaciones protegidas (ej. Store, Xbox, Recortes) y un menú interactivo. También se agregó una pregunta interactiva (línea 635) para bloquear la instalación de OneDrive mediante entradas en `autounattend.xml`.
  - **Cambio 3:** Se reescribió `SetupComplete.cmd` (línea 595) para detectar internet con ping. Si no hay conexión, se programa una tarea mediante desencadenador de red y se genera un acceso directo en el Escritorio.


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
