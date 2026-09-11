# PLAN-0076: Optimización Integral del Tiempo de Instalación de la ISO (Zero-Touch a Escritorio)

**Estado:** COMPLETADO  
**Fecha:** 2026-09-11  
**Autor:** Antigravity AI  
**Componentes:**  
- `scripts/Core/Policy-Engine.ps1`  
- `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`  
- `scripts/Builder/New-OptimizedWindowsISO-GUI-Engine.ps1`  
- `scripts/Testing/Test-OptimizedISO-v2.ps1`  
- `docs/plans/README.md`

---

## 1. Contexto y Diagnóstico Forense

El usuario reportó que el tiempo de instalación de la ISO es excesivamente elevado, y que a pesar de que el proceso es Zero-Touch (desatendido), la máquina tarda demasiado tiempo en llegar al escritorio con la sesión de Windows completamente instalada y operativa.

### Análisis Forense de los Cuellos de Botella Reales:

1. **CPU Throttling en Windows PE (`boot.wim`):**
   - WinPE arranca por defecto bajo el esquema de energía "Equilibrado" (`381b4222-f694-41f0-9685-ff5bb260df2e`).
   - Sin servicios de escalado de frecuencia dinámico, los procesadores modernos (Intel con P/E cores, AMD Ryzen y vCPUs de Hyper-V/VMware) permanecen fijados a frecuencias mínimas (800 MHz - 1.4 GHz).
   - Como la descompresión LZX de `install.wim` es intensiva en CPU, expandir 15-20 GB de archivos toma entre 5 y 8 minutos en vez de ~1.5 minutos.

2. **Dynamic Update (DU) por Red en `setup.exe`:**
   - En `autounattend.xml`, el nodo `Microsoft-Windows-Setup` no especifica `<DynamicUpdate><Enable>false</Enable></DynamicUpdate>`.
   - Si la máquina o VM tiene conexión a internet (cable o conmutador virtual de Hyper-V), Windows Setup detiene la instalación para contactar con Windows Update y descargar parches de instalación, WinRE y controladores, añadiendo entre 2 y 10 minutos de retraso o timeouts.

3. **Ejecución Síncrona y Bloqueante en `SetupComplete.cmd`:**
   - Según las especificaciones de Microsoft, Windows Setup congela la pantalla en *"Espera un momento..." / "Just a moment..."* hasta que `SetupComplete.cmd` finalice completamente.
   - En nuestro código actual:
     - Se ejecutan **hasta 17 arranques en frío de `powershell.exe`** para tareas individuales y accesos directos. En un sistema recién instalado sin caché en RAM, esto añade 45-60 segundos solo en arranque y cierre de procesos.
     - Se ejecuta `PostInstall-Diagnostics.ps1` de forma síncrona, demorando otros 30-60 segundos analizando WMI/CIM antes del inicio de sesión.
     - Si hay runtimes en la carpeta `Runtimes/`, se ejecutan secuencialmente en el bucle `for`, demorando varios minutos.

4. **Animación Obligatoria de Primer Inicio (`EnableFirstLogonAnimation`):**
   - Windows 11 ejecuta por defecto la presentación animada ("Hola... Preparando todo para ti..."). Esta pantalla tiene retardos temporizados artificiales por Microsoft que retienen al usuario durante 1.5 a 2 minutos adicionales antes de soltar el escritorio.

---

## 2. Decisión y Solución Técnica Fundamentada (Regla 11)

### A. Desbloqueo de CPU en WinPE (Alto Rendimiento)
- Inyectar en `autounattend.xml` bajo `windowsPE` -> `Microsoft-Windows-Setup` -> `RunSynchronous`:
  ```xml
  <RunSynchronousCommand wcm:action="add">
    <Order>1</Order>
    <Description>Set WinPE High Performance Power Scheme</Description>
    <Path>powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c</Path>
  </RunSynchronousCommand>
  ```
- Desplaza los bypasses de hardware preexistentes de Order 1..7 a Order 2..8.
- Permite que `setup.exe` descomprima `install.wim` a la frecuencia máxima de la CPU (Turbo Clock: 4.5 - 5.0 GHz).

### B. Desactivación Explícita de Dynamic Update
- Inyectar en `autounattend.xml` bajo `windowsPE` -> `Microsoft-Windows-Setup`:
  ```xml
  <DynamicUpdate>
    <Enable>false</Enable>
    <WillShowUI>Never</WillShowUI>
  </DynamicUpdate>
  ```
- Garantiza que Windows Setup nunca se detenga a negociar descargas en servidores de Windows Update durante la fase de instalación.

### C. Supresión de la Animación de Primer Inicio (GPO Oficial)
- Registrar en `scripts/Core/Policy-Engine.ps1` la directiva SSOT:
  - `POL_FIRST_LOGON_ANIMATION`:
    - `RegistryKey`: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System` y `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`
    - `ValueName`: `EnableFirstLogonAnimation`
    - `Type`: `REG_DWORD`
    - `ExpectedValue`: `0`
    - `Profiles`: `@(1, 2, 3)` (Universal)
- Al exportarse dinámicamente mediante `Export-RomanOSUnattendCommands`, se aplica en la fase `specialize`, eliminando 1.5 a 2 minutos de espera al iniciar sesión.

### D. Consolidación de Procesos en `SetupComplete.cmd`
- **Erradicar los 17 arranques individuales de PowerShell:** Crear un script unificado de inicialización post-instalación (`Initialize-PostInstall.ps1`) en `$OEMScriptsDir` que configure los accesos directos, las tareas programadas y los menús contextuales en **un solo proceso de PowerShell**.
- **Desacoplar la auditoría diagnóstica:** Invocar `PostInstall-Diagnostics.ps1` de manera asíncrona o no bloqueante (`start "" /b ...`) para que Windows Setup libere de inmediato la sesión y el usuario entre al escritorio sin esperas.

---

## 3. Plan de Cambios Específicos

1. **`scripts/Core/Policy-Engine.ps1`:**
   - Agregar directiva oficial `POL_FIRST_LOGON_ANIMATION` (`EnableFirstLogonAnimation = 0`).
2. **`scripts/Builder/New-OptimizedWindowsISO-v2.ps1` y `scripts/Builder/New-OptimizedWindowsISO-GUI-Engine.ps1`:**
   - Inyectar `powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c` como Order 1 en `windowsPE`.
   - Inyectar bloque `<DynamicUpdate><Enable>false</Enable><WillShowUI>Never</WillShowUI></DynamicUpdate>` en `Microsoft-Windows-Setup`.
   - Refactorizar `SetupComplete.cmd` para generar y ejecutar el script unificado `Initialize-PostInstall.ps1` (reduciendo de 17 llamadas a 1 sola).
   - Lanzar `PostInstall-Diagnostics.ps1` en segundo plano desacoplado (`start "" /b ...`).
3. **`scripts/Testing/Test-OptimizedISO-v2.ps1`:**
   - Añadir asserts para verificar `EnableFirstLogonAnimation`, `DynamicUpdate` en autounattend, `powercfg` en WinPE y reducción de procesos en SetupComplete.
4. **`docs/plans/README.md`:**
   - Registrar `PLAN-0076`.

---

## 4. Plan de Verificación

- **Prueba 1:** Ejecutar suite de pruebas de esquema XML y desatendido:
  `& powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'scripts/Testing/Test-OptimizedISO-v2.ps1' }"`
- **Prueba 2:** Verificar sintaxis y validación en frío de scripts en PowerShell 5.1:
  `& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'scripts/Core/Policy-Engine.ps1' }"`
- **Prueba 3:** `grep_search` físico de logs en busca de `FAIL`, `ERROR` o `Exception` (Regla 12).
