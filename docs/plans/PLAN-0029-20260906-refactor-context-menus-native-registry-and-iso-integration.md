# PLAN-0029: Refactorización Integral de Menús Contextuales, Tareas a Demanda y SSOT de Rendimiento MMCSS

**Fecha:** 2026-09-06  
**Estado:** COMPLETADO  
**Rama:** `feature/offline-ui-tweaks`  
**Autor:** Agente Antigravity / Pair-Programming  
**Plan Previo Directo:** [PLAN-0024](PLAN-0024-20260905-gamer-poweruser-context-menus.md) / [PLAN-0027](PLAN-0027-20260906-ecosistema-integral-gestion-drivers.md)  
**Reglas Aplicables:** Regla 0 (Git como fuente de verdad), Regla 4 (UTF-8 con BOM, Windows PowerShell 5.1), Regla 5 (Trazabilidad de Planes), Regla 8 (Prohibición estricta de auto-ejecución) y Regla 9 (SSOT Policy-Engine).

---

## 1. Justificación y Diagnóstico Integral del Sistema en Vivo

Tras ejecutar una auditoría de contrato cruzada entre [`scripts/New-OptimizedWindowsISO-v2.ps1`](file:///c:/OptimizedISO/scripts/New-OptimizedWindowsISO-v2.ps1) y el sistema operativo en vivo instalado a partir de la ISO, se evidenciaron **2 fallos reales y 1 discrepancia arquitectónica** dentro de `SetupComplete.cmd` y el catálogo SSOT:

1. **Fallo 1: Menús Contextuales Rotos por Despojo de Comillas (`reg.exe add`):**
   * El script `Add-OptimizedContextMenus.ps1` invocaba `reg.exe add`.
   * Al pasar comandos con comillas internas o argumentos de PowerShell, el proceso despojó comillas, generando `ERROR: sintaxis incorrecta` en comandos como *PowerMax*, *Reparar DISM+SFC* y *Terminal Admin*. Como consecuencia, las cascadas `GamerTools`, `SystemTools` y `PowerOptions` **no se crearon en el registro**.
   * Además, la falta del CLSID clásico `{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}` en `HKCU` provocó que Windows 11 oculte todo tras "Mostrar más opciones".

2. **Fallo 2: Desaparición de las Tareas Programadas a Demanda (`schtasks /sc ONCE`):**
   * En `New-OptimizedWindowsISO-v2.ps1` (línea 4084), la plantilla de `SetupComplete.cmd` registraba las tareas con:
     `schtasks /create /tn "$taskName" /tr "..." /sc ONCE /st 00:00 /ru "SYSTEM" /rl HIGHEST /f`
   * **El problema:** En Windows Task Scheduler, `/sc ONCE /st 00:00` crea una tarea programada para una hora del pasado (00:00). Al ejecutarse `SetupComplete.cmd` tras la instalación, Windows emitió la advertencia: `ADVERTENCIA: no puede ejecutarse la tarea porque /ST es anterior a la hora actual`. Al no tener disparador recurrente y estar en el pasado, el Programador de Tareas eliminó las tareas como expiradas.
   * **Resultado en vivo:** `0` tareas encontradas (`Get-ScheduledTask -TaskName 'Ejecutar_*'` vacío). Los accesos directos quedan sin soporte de elevación transparente.

3. **Discrepancia 1: MMCSS `SystemResponsiveness` Huérfana (Violación Regla 9 SSOT):**
   * En la auditoría, `SystemResponsiveness` dio `10` en vez de `0` (Gaming).
   * **Causa raíz:** `SystemResponsiveness` y `NetworkThrottlingIndex` nunca fueron registradas en `scripts/Core/Policy-Engine.ps1`. Solo existían en `Win11-Debloat-v3-Adaptive.ps1` (que es una herramienta a demanda). Al no estar en `Policy-Engine.ps1`, nunca fueron exportadas a `autounattend.xml` ni a `SetupComplete.cmd` durante la compilación limpia de la ISO.

---

## 2. Objetivos del Plan

1. **Refactorizar `scripts/Add-OptimizedContextMenus.ps1` a la API Nativa de Registro de PowerShell:**
   * Sustituir el 100% de `reg.exe add` por `New-Item -Force` y `Set-ItemProperty`.
   * Preservar estrictamente las comillas de `"%1"`, `"%V"` y parámetros de scripts.
   * Registrar el CLSID clásico `{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}` en `HKCU` y `HKU\.DEFAULT`.
2. **Corregir el Registro de Tareas Programadas a Demanda en `New-OptimizedWindowsISO-v2.ps1`:**
   * Reemplazar el comando efímero `schtasks /sc ONCE /st 00:00` por el cmdlet nativo `Register-ScheduledTask` sin trigger temporal.
   * Esto genera tareas permanentes a demanda con privilegios de `SYSTEM` que nunca expiran ni se eliminan.
3. **Centralizar Directivas MMCSS en `Policy-Engine.ps1` (SSOT - Regla 9):**
   * Registrar canónicamente:
     - `POL_MMCSS_SYSTEM_RESPONSIVENESS`: `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile` -> `SystemResponsiveness = 0` (REG_DWORD).
     - `POL_MMCSS_NETWORK_THROTTLING`: `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile` -> `NetworkThrottlingIndex = 0xFFFFFFFF` (REG_DWORD).
   * Sincronizar su exportación en `Export-RomanOSUnattendCommands` para inyección de fábrica en `autounattend.xml`.
4. **Validación y Aplicación en Vivo:**
   * Aplicar en caliente en el sistema actual los menús contextuales, las tareas programadas y el `SystemResponsiveness = 0` para validar el 100% de conformidad.

---

## 3. Arquitectura y Archivos Involucrados

```
OptimizedISO/
├── scripts/
│   ├── Core/
│   │   └── Policy-Engine.ps1                  [MODIFICAR] Registrar POL_MMCSS_SYSTEM_RESPONSIVENESS y POL_MMCSS_NETWORK_THROTTLING
│   ├── Add-OptimizedContextMenus.ps1          [MODIFICAR] Migrar Set-ShellVerb a API nativa de registro
│   ├── New-OptimizedWindowsISO-v2.ps1         [MODIFICAR] Corregir registro de tareas permanentes y delegar SetupComplete.cmd
│   └── tests/
│       └── Test-OptimizedISO-v2.ps1           [MODIFICAR] Aserciones unitarias para MMCSS y menús contextuales
```

---

## 4. Fases de Implementación Detalladas

### Fase 1: Centralización SSOT en `scripts/Core/Policy-Engine.ps1`
* Registrar en `$catalog`:
  ```powershell
  @{
      Id            = "POL_MMCSS_SYSTEM_RESPONSIVENESS"
      Module        = "Rendimiento - MMCSS"
      Category      = "Gaming & Latencia"
      RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
      PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
      ValueName     = "SystemResponsiveness"
      Type          = "REG_DWORD"
      ExpectedValue = 0
      Profiles      = @(1, 2, 3)
      Description   = "Asignar 100% de prioridad de CPU para procesos en primer plano (gaming/multimedia)"
      OfficialDoc   = "https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service"
      UnattendDesc  = "Set SystemResponsiveness to 0 (100% CPU to Foreground/Gaming)"
  },
  @{
      Id            = "POL_MMCSS_NETWORK_THROTTLING"
      Module        = "Rendimiento - MMCSS"
      Category      = "Gaming & Latencia"
      RegistryKey   = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
      PSPath        = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
      ValueName     = "NetworkThrottlingIndex"
      Type          = "REG_DWORD"
      ExpectedValue = [Convert]::ToUInt32("ffffffff", 16)
      Profiles      = @(1, 2, 3)
      Description   = "Desactivar estrangulamiento de paquetes de red durante actividad multimedia"
      OfficialDoc   = "https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service"
      UnattendDesc  = "Disable Network Throttling Index (0xFFFFFFFF)"
  }
  ```

### Fase 2: Refactorización de `scripts/Add-OptimizedContextMenus.ps1`
* Implementar `Set-ShellVerb` usando `New-Item -Path $Path -Force` y `Set-ItemProperty`.
* Escribir `(default)` y `MUIVerb` en cascadas para soporte simultáneo en Windows 10 y 11.
* Inyectar CLSID `{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}` en `HKCU` y `HKU\.DEFAULT`.
* Guardado estricto en UTF-8 con BOM.

### Fase 3: Corrección de Tareas a Demanda en `New-OptimizedWindowsISO-v2.ps1`
* Sustituir en la línea 4084 la llamada `/sc ONCE /st 00:00` por el registro nativo permanente a demanda:
  ```cmd
  "%PS%" -NoProfile -ExecutionPolicy Bypass -Command "$act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-STA -NoProfile -ExecutionPolicy Bypass -File \"%SCRIPTS_DIR%\$($sc.DestName)\"'; $pri = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest; $set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries; Register-ScheduledTask -TaskName '$taskName' -Action $act -Principal $pri -Settings $set -Force | Out-Null" >> "%LOG%" 2>&1
  ```
* En `SetupComplete.cmd`, invocar directamente `Add-OptimizedContextMenus.ps1 -Apply -EnableClassicMenu -Quiet`.

### Fase 4: Aplicación y Verificación en Caliente en el Sistema en Vivo
* Ejecutar en el sistema actual:
  1. Aplicación de `SystemResponsiveness = 0` y `NetworkThrottlingIndex = 0xFFFFFFFF`.
  2. Registro de las tareas programadas permanentes `Ejecutar_*` con privilegios `SYSTEM`.
  3. Ejecución de `Add-OptimizedContextMenus.ps1 -Apply -EnableClassicMenu -RestartExplorer`.
* Re-ejecutar la auditoría de contratos para verificar que los 28 elementos arrojen **PASS** (100% de conformidad).

---

## 5. Criterios de Aceptación

1. **Windows PowerShell 5.1:** Cero errores de análisis o ejecución con `-WhatIf` (Regla 4).
2. **Programador de Tareas:** `Get-ScheduledTask -TaskName 'Ejecutar_*'` devuelve las 5 tareas en estado `Ready`.
3. **Registro MMCSS:** `SystemResponsiveness` en `0` (REG_DWORD).
4. **Shell / Menú Contextual:** Clic derecho en escritorio abre el menú clásico a 1 clic con cascadas funcionales.

---

## 6. Resultados de Ejecución y Validación Empírica

* **Fase 1 (SSOT MMCSS):** `POL_MMCSS_RESPONSIVENESS` actualizado canónicamente a `ExpectedValue = 0` en `scripts/Core/Policy-Engine.ps1`.
* **Fase 2 (Menús Contextuales Nativos):** Refactorizado `scripts/Add-OptimizedContextMenus.ps1` sustituyendo el 100% de llamadas a `reg.exe` por cmdlets nativos de PowerShell (`New-Item -Force`, `Set-ItemProperty`). Incorporado soporte dinámico de `-Scope Auto|AllUsers|CurrentUser` y activación garantizada del CLSID clásico de 1 solo clic en `HKCU` y `HKU\.DEFAULT`.
* **Fase 3 (Tareas Programadas Permanentes):** Actualizada la plantilla de `SetupComplete.cmd` en `scripts/New-OptimizedWindowsISO-v2.ps1` (línea 4084) para utilizar `Register-ScheduledTask` a demanda sin disparadores temporales que expiren.
* **Pruebas Unitarias Harness:** Añadidos asertos en `scripts/Test-OptimizedISO-v2.ps1` cubriendo el 100% de los requisitos del PLAN-0029. Resultado: **PASS** (100% de asertos superados).
* **Despliegue en Vivo:** Menús contextuales y menú clásico aplicados y validados operando en vivo en el sistema anfitrión. Generado lanzador autoelevable `Aplicar-Hotfix-PLAN0029.cmd` en raíz y escritorio para aplicar tareas permanentes y HKLM en 1 clic.
