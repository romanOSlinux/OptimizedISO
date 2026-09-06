# Auditoría Técnica Integral: `New-OptimizedWindowsISO-v2.ps1`
**Fecha:** 2026-09-02  
**Autor:** Antigravity AI  
**Objetivo:** Detección de incompatibilidades en imágenes WIM vírgenes, bloqueos de kernel de Windows 11, acciones redundantes entre capas y fugas de ruido en consola.  
**Estado:** AUDITORÍA COMPLETADA  

---

## 1. Contexto y Premisa Operativa

El generador `New-OptimizedWindowsISO-v2.ps1` opera tomando como entrada imágenes ISO oficiales de Microsoft (medios 100% limpios y vírgenes). En este escenario, cualquier instrucción o comando que asuma un sistema operativo previamente instalado, una imagen capturada con componentes activos, o que ignore los mecanismos de seguridad modernos de Windows 11 (como UCPD), resulta ineficaz, genera advertencias erróneas o produce fallos estériles.

---

## 2. Matriz de Hallazgos Críticos

| # | Componente / Línea | Descripción del Problema | Causa Raíz Técnica | Impacto |
|---|---|---|---|---|
| **1** | L6264–L6291 (`/Set-ReservedStorageState`) | DISM devuelve código 50 (`ERROR_NOT_SUPPORTED`) en el 100% de los casos. | `/Set-ReservedStorageState` solo opera en imágenes capturadas con almacenamiento reservado activo o SO instalado offline. WIM virgen no lo soporta. | Ineficaz. Genera `[WARN]` falso en cada índice del WIM. |
| **2** | L6484–L6489 (`TaskbarDa` en `NTUSER.DAT`) | `[WARN] Error aplicando tweak: ... TaskbarDa`. | Driver UCPD (User Choice Protection Driver) del kernel de Windows 11 bloquea escrituras directas a `TaskbarDa`. | Falso fallo. Widgets ya se deshabilita limpiamente por GPO `AllowWidgets = 0`. |
| **3** | L3276, L3319, L6320 (`reg.exe load/unload`) | Salen líneas `ERROR: El parámetro no es correcto` y `La operación se completó correctamente`. | `Start-Process -NoNewWindow` sin redirección de stdout/stderr. Descarga preventiva de colmena no montada da error 87. | Contaminación visual severa de la consola unificada. |
| **4** | L4371 (`SetupComplete.cmd`) | Reg add a `Policies\Microsoft\Windows\Windows AI` con espacio. | El CSP oficial de Microsoft es `WindowsAI` (sin espacio). | La política de análisis de datos AI queda en una clave huérfana no reconocida. |
| **5** | L5280–L5286 (Menú de Perfiles) | Texto describe Perfil 3 como "Hardcore: EXTREMO. Destruye Wi-Fi...". | Inconsistencia textual heredada tras la refactorización oficial del Perfil 3 a "Laptop/VM". | Confusión para el usuario que visualiza la interfaz. |
| **6** | L6340–L6368 (`Themes\Personalize`) | Modo Oscuro inyectado directo en `Themes\Personalize` y duplicado en `RunOnce`. | Redundancia interna dentro del mismo bloque de tweaks de `NTUSER.DAT`. | Duplicación de operaciones sin beneficio funcional. |

---

## 3. Desglose Técnico Detallado

### 3.1. Incompatibilidad DISM: `/Set-ReservedStorageState` (Exit Code 50)
* **Código actual:**
  ```powershell
  $resStorage = Invoke-MonitoredProcess -FilePath "dism.exe" `
      -ArgumentList @("/Image:$WimMountDir", "/Set-ReservedStorageState", "/State:Disabled", "/ScratchDir:$ScratchDir")
  ```
* **Diagnóstico:**
  En imágenes oficiales de Microsoft, `Reserved Storage` no se encuentra inicializado en el archivo `install.wim`. Su inicialización ocurre durante el primer arranque en la fase `specialize`. DISM devuelve invariablemente exit code `50` (`ERROR_NOT_SUPPORTED`).
* **Solución técnica recomendada:**
  Desactivar Reserved Storage a través de su directiva de registro nativa en el hive `SOFTWARE` montado (`HKLM\_ROMANOS_SW\Microsoft\Windows\CurrentVersion\ReserveManager\ShippedWithReserves = 0`) o invocar DISM online dentro de `SetupComplete.cmd` (`dism /Online /Set-ReservedStorageState /State:Disabled`), donde sí está 100% soportado.

---

### 3.2. Bloqueo de Kernel: `TaskbarDa` y UCPD
* **Código actual:**
  ```powershell
  @{
      Path = "HKLM\OfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
      Name = "TaskbarDa"
      Type = "REG_DWORD"
      Data = "0"
  }
  ```
* **Diagnóstico:**
  En sistemas host Windows 11 modernos, el driver de kernel `UCPD.sys` (User Choice Protection Driver) intercepta las llamadas a `NtSetValueKey` dirigidas a `TaskbarDa` y responde con `STATUS_ILLEGAL_FUNCTION` / `ERROR_ACCESS_DENIED`.
  Dado que el proyecto ya inyecta en `autounattend.xml` la política oficial:
  `HKLM\SOFTWARE\Policies\Microsoft\Widgets` -> `AllowWidgets = 0`
  los Widgets y su icono en la barra de tareas quedan completamente deshabilitados a nivel de máquina sin necesidad de manipular `TaskbarDa`.
* **Solución técnica recomendada:**
  Remover la entrada `TaskbarDa` de la lista `$tweaks` de `NTUSER.DAT`.

---

### 3.3. Fugas de Ruido en Consola: `Invoke-RegUnloadHive` y `reg.exe load`
* **Código actual:**
  ```powershell
  $proc = Start-Process -FilePath "reg.exe" -ArgumentList @("unload", $HiveName) -Wait -PassThru -NoNewWindow
  ```
* **Diagnóstico:**
  Cuando se realiza una descarga preventiva de seguridad al inicio de `Invoke-WimAiHardening` o en la inyección de `NTUSER.DAT`, la colmena aún no está montada. `RegUnLoadKey` falla con error 87 (`ERROR_INVALID_PARAMETER`), que se imprime en stderr como `ERROR: El parámetro no es correcto.`. Al no haber redirección en `Start-Process`, el mensaje sale directamente a la pantalla del usuario.
* **Solución técnica recomendada:**
  1. Comprobar previamente si la colmena está cargada mediante `& reg.exe query $HiveName 2>&1 | Out-Null`.
  2. Silenciar la salida de `reg.exe` (`2>&1 | Out-Null` o captura en variable/archivo temporal) para garantizar que los procesos preventivos sean invisibles al usuario.

---

### 3.4. Redundancias entre Capas del Sistema

1. **ContentDeliveryManager (Publicidad y Apps Sugeridas):**
   * *Capa 1 (`autounattend.xml`):* Inyecta directiva GPO `DisableWindowsConsumerFeatures = 1` y `SilentInstalledAppsEnabled = 0` a nivel de máquina (`HKLM`).
   * *Capa 2 (WIM `NTUSER.DAT`):* Inyecta 15 claves individuales `SubscribedContent-*`.
   * *Capa 4 (`Win11-Debloat-v3-Adaptive.ps1`):* Re-itera sobre las mismas 15 claves en HKCU.
   * *Dictamen:* La directiva de la Capa 1 es suficiente para suprimir el bloatware en el 100% de las cuentas creadas. Mantener las demás no perjudica, pero evidencia sobre-ingeniería de capas.

2. **Búsqueda Web en Menú Inicio:**
   * La clave `BingSearchEnabled` en `NTUSER.DAT` está obsoleta desde Windows 10 20H2. La directiva moderna y efectiva es `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search\DisableWebSearch = 1` (ya presente en `autounattend.xml`).

3. **Inconsistencia de Sintaxis en Copilot:**
   * `SetupComplete.cmd` (L4371) usa `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows AI` (con espacio). Debe ser `WindowsAI` (sin espacio) para alinearse con el Policy CSP oficial y con `Invoke-WimAiHardening`.

---

## 4. Plan de Acción Recomendado

1. **Refactorización de Servicing WIM:**
   - Retirar la invocación de `dism /Set-ReservedStorageState` del bucle offline.
   - En su lugar, añadir la clave `ShippedWithReserves = 0` en `HKLM\_ROMANOS_SW\Microsoft\Windows\CurrentVersion\ReserveManager`.
2. **Saneamiento de Tweaks de Registro:**
   - Eliminar `TaskbarDa` del array `$tweaks` de `NTUSER.DAT`.
   - Eliminar el valor duplicado `ApplyDarkMode` en `RunOnce`.
3. **Encapsulamiento Silencioso de `Invoke-RegUnloadHive`:**
   - Redirigir la salida de `reg.exe load` y `reg.exe unload`.
   - Condicionar el intento de descarga a `reg.exe query $HiveName`.
4. **Corrección de Textos y Nomenclaturas:**
   - Corregir `"Windows AI"` a `"WindowsAI"` en `SetupComplete.cmd`.
   - Actualizar el banner del Perfil 3 en el menú interactivo a "Laptop / Portátil / VM".
