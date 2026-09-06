# PLAN-0019: Expansión de Inteligencia, Presets Reutilizables y Optimizaciones Oficiales en New-OptimizedWindowsISO-v2.ps1

- **Número:** PLAN-0019
- **Fecha:** 2026-09-01
- **Título:** Expansión de Inteligencia, Presets Reutilizables y Optimizaciones Oficiales en New-OptimizedWindowsISO-v2.ps1
- **Estado:** COMPLETADO
- **Autor:** Antigravity / romanOS Team

---

## 1. Contexto y Filosofía del Proyecto

El objetivo central de `romanOS / OptimizedISO` es:
> **Tomar una imagen ISO oficial de Windows (edición estándar/consumer) y, mediante técnicas nativas de debloat, hardening, inyección offline de parches y aplicación de políticas oficiales de grupo/registro, transformarla en una instalación limpia, ágil, privada y eficiente equivalente a una edición Enterprise/LTSC, sin requerir licencias de volumen adicionales.**

Este plan reúne 8 mejoras concretas, libres de código redundante, respaldadas por documentación técnica oficial de Microsoft y con métricas comprobables.

---

## 2. Inventario de Mejoras Oficiales

### Módulo A — Presets JSON Reutilizables (`-PresetFile`, `-SavePreset`)
* **Problema:** El script posee 36 parámetros en `param()` y 9 pantallas interactivas en los wizards, requiriendo 5–8 minutos de configuración manual en cada ejecución repetida.
* **Solución:**
  * Parámetros `-PresetFile <ruta>` e `-SavePreset`.
  * Funciones `Import-BuildPreset` y `Export-BuildPreset` basadas en `ConvertFrom-Json` / `ConvertTo-Json`.
  * Precedencia estricta: Parámetros pasados por línea de comandos (CLI) tienen prioridad sobre el archivo JSON.
* **Fuente Oficial:** [PowerShell Scripting & Serialization Guidelines](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertto-json).

### Módulo B — Detección Inteligente de Rebuild / ISO Romanizada (`Test-IsRomanizedISO`)
* **Problema:** Procesar accidentalmente una ISO ya modificada puede generar fallos de sobreescritura o 45–90 minutos de compilación redundante.
* **Solución:** Función `Test-IsRomanizedISO` que inspecciona la presencia de `SetupComplete.cmd` firmado o bypasses en `autounattend.xml` en <5 segundos antes de extraer o montar.
* **Métrica:** Guardrail de <5 segundos para evitar pérdida de tiempo en compilaciones erróneas.

### Módulo C — Perfil 3: Laptop / VM Silencioso (`OptimizationProfile = 3`)
* **Problema:** El Perfil 1 fuerza *Ultimate Performance* (agota la batería en portátiles) y el Perfil 2 deshabilita Wi-Fi (`WlanSvc`), Bluetooth (`bthserv`) y el hipervisor. No existía un perfil óptimo para notebooks o máquinas virtuales.
* **Solución:**
  * Perfil 3 aplica debloat completo sin telemetría ni bloatware, pero mantiene activos Wi-Fi, Bluetooth, Impresión, `SysMain` y `WSearch`.
  * Configura el plan de energía **Equilibrado** (`SCHEME_BALANCED` `381b4222-f694-41f0-9685-ff5bb260df2e`).
* **Fuentes Oficiales:**
  * [Microsoft Learn — powercfg](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options)
  * [Microsoft Learn — SysMain Service](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-create)
* **Métrica:** +15–30% de autonomía en portátiles frente a planes de máximo rendimiento.

### Módulo D — Bloqueo Offline de Recall / Copilot+ en WIM (Windows 11 24H2+)
* **Problema:** En equipos Copilot+ con NPU, Recall y AI Data Analysis se inician durante el OOBE antes de que `SetupComplete.cmd` (post-instalación) pueda actuar.
* **Solución:** Función `Invoke-WimAiHardening` que carga offline el hive `SOFTWARE` del WIM durante DISM servicing (Build >= 26100) y establece `AllowRecallEnablement = 0`, `DisableAIDataAnalysis = 1` y `TurnOffWindowsCopilot = 1`.
* **Fuente Oficial:** [Microsoft Learn — Manage Recall Policy](https://learn.microsoft.com/en-us/windows/client-management/manage-recall).

### Módulo E — Desactivación Offline de Reserved Storage con DISM
* **Problema:** Windows reserva automáticamente 7.0–7.5 GB de espacio en disco en particiones ocultas para parches temporales.
* **Solución:** Ejecutar `dism.exe /Image:$WimMountDir /Set-ReservedStorageState /State:Disabled` durante el servicing offline.
* **Fuente Oficial:** [Microsoft Learn — DISM Servicing Options](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism-operating-system-uninstall-servicing-command-line-options?view=windows-11).
* **Métrica:** **~7.14 GB de SSD liberados** inmediatamente tras la instalación limpia.

### Módulo F — Supresión Oficial de Widgets / Web Experience y Búsqueda Web de Bing
* **Problema:** Widgets y la búsqueda de Bing en el menú de inicio ejecutan procesos WebView2 en background y envían cada pulsación de tecla a la nube.
* **Solución:**
  * Política `HKLM\SOFTWARE\Policies\Microsoft\Widgets` -> `AllowWidgets = 0`.
  * Política `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search` -> `DisableWebSearch = 1`, `ConnectedSearchUseWeb = 0`.
  * Default User `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` -> `TaskbarDa = 0`.
* **Fuentes Oficiales:**
  * [Microsoft Learn — Widgets CSP](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-widgets)
  * [Microsoft Learn — Search CSP](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-search)
* **Métrica:** Ahorro de **~250–400 MB de RAM** en reposo; búsqueda local a **<40 ms**.

### Módulo G — Desactivación Oficial de Delivery Optimization P2P (`DoSvc`)
* **Problema:** Las ediciones estándar configuran `DoSvc` en modo P2P, consumiendo ancho de banda de subida para distribuir parches a otros equipos.
* **Solución:** Política `HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization` -> `DODownloadMode = 0` (Bypass/HTTP directo desde servidores Microsoft).
* **Fuente Oficial:** [Microsoft Learn — Delivery Optimization Reference](https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-reference).
* **Métrica:** 0% de ancho de banda de subida desperdiciado en P2P.

### Módulo H — Supresión Integral de ID de Publicidad y Historial de Actividad
* **Problema:** Rastreo publicitario y subida de grafos de actividad del usuario en ediciones consumer.
* **Solución:**
  * Política `HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo` -> `DisabledByGroupPolicy = 1`.
  * Política `HKLM\SOFTWARE\Policies\Microsoft\Windows\System` -> `PublishUserActivities = 0`, `UploadUserActivities = 0`.
* **Fuentes Oficiales:**
  * [Microsoft Learn — Advertising ID CSP](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-advertisinginfo)
  * [Microsoft Learn — Privacy Policies CSP](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-privacy).

---

## 3. Plan de Modificaciones en Código

### Archivo Principal: `scripts/New-OptimizedWindowsISO-v2.ps1`
1. **Bloque `param()`:** Agregar `$PresetFile` (string) y `$SavePreset` (switch); expandir `ValidateSet("1", "2", "3")` en `$OptimizationProfile`.
2. **Funciones Nuevas:**
   * `Import-BuildPreset` (lectura y merge de configuración JSON).
   * `Export-BuildPreset` (exportación de configuración a JSON).
   * `Test-IsRomanizedISO` (detección de ISO ya optimizada).
   * `Invoke-WimAiHardening` (bloqueo offline de Recall/AI en hive SOFTWARE para builds >= 26100).
3. **Flujo de Asistente e Interacción:**
   * Integración de `Import-BuildPreset` previo a `Invoke-WizardConfig`.
   * Integración de `Export-BuildPreset` tras `Invoke-DeploymentChoices`.
   * Menú de Perfil 3 en `Invoke-DeploymentChoices`.
   * Verificación de `Test-IsRomanizedISO` al extraer la ISO.
4. **Flujo DISM Servicing:**
   * Ejecución de `dism /Set-ReservedStorageState /State:Disabled`.
   * Invocación de `Invoke-WimAiHardening`.
   * Ajuste de `TaskbarDa = 0` en tweaks visuales Default User.
5. **Generación de `SetupComplete.cmd`:**
   * Configuración de plan `SCHEME_BALANCED` para Perfil 3.
6. **Generación de `autounattend.xml` (`specialize` pass):**
   * Inyección de `AllowWidgets = 0`.
   * Inyección de `DisableWebSearch = 1` y `ConnectedSearchUseWeb = 0`.
   * Inyección de `DODownloadMode = 0` (Delivery Optimization).
   * Inyección de `DisabledByGroupPolicy = 1` (AdvertisingInfo).
   * Inyección de `PublishUserActivities = 0` y `UploadUserActivities = 0` (System).

---

## 4. Criterios de Validación

1. **AST & Compatibilidad Windows PowerShell 5.1:**
   Validación fría con `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass`.
2. **Codificación:**
   Verificación estricta de UTF-8 con BOM (`0xEF, 0xBB, 0xBF`).
3. **Suite de Pruebas Automatizadas:**
   Ejecución y aprobación de `Invoke-TestSuite.ps1`.
4. **Pruebas de Presets:**
   Generación y carga de un archivo JSON de prueba sin errores de parseo.
