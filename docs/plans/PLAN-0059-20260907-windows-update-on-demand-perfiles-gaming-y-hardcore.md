# PLAN-0059: Windows Update Bajo Demanda (Manual On-Demand) en Perfiles Gaming y Hardcore

- **ID del Plan:** PLAN-0059
- **Fecha:** 2026-09-07
- **Estado:** COMPLETADO
- **Autor:** romanOS Engineering / Antigravity Agent
- **Rama:** `feature/offline-ui-tweaks`

---

## 1. Contexto y Justificación Técnica

En sistemas operativos enfocados en rendimiento y videojuegos (como los perfiles **Gaming** y **Hardcore** de romanOS), las tareas automáticas en segundo plano de Windows Update representan una causa primaria de:
1. Picos imprevistos de uso de CPU y contención de hilos.
2. Sobrecarga de I/O en almacenamiento NVMe/SSD durante descargas y descompresiones temporales.
3. Latencia y micro-cortes de red (*ping spikes* / *bufferbloat*) mientras se juega en línea.
4. Reinicios forzados intempestivos provocados por parches acumulativos.

Sin embargo, deshabilitar o eliminar el servicio `wuauserv` (como hacen las ISOs modificadas de foros) es destructivo e inseguro: rompe la Microsoft Store, corrompe componentes de DirectX, impide la validación de licencias HWID y bloquea parches críticos de seguridad.

La solución de ingeniería oficial de Microsoft para estaciones de trabajo y entornos que requieren cero interrupciones es **configurar el cliente de actualización en modo manual bajo demanda**:
- En reposo: Cero escaneos automáticos, cero descargas silenciosas, cero reinicios.
- A petición del usuario: Si el usuario pulsa **"Buscar actualizaciones"** en la aplicación de Configuración, el sistema busca, descarga e instala con total normalidad.
- En el **Perfil 1 (Conservador)**: Se preserva el comportamiento automático original de Windows para usuarios estándar.

---

## 2. Objetivos del Plan

1. **Gobernanza Canónica en SSOT (`Policy-Engine.ps1`):**
   - Registrar para `Profiles = @(2, 3)` las directivas GPO oficiales bajo `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`:
     - `NoAutoUpdate = 1`: Desactiva la búsqueda y descarga automática periódica.
     - `AUOptions = 2`: Configura el modo semántico oficial de notificación previa.
     - `NoAutoRebootWithLoggedOnUsers = 1`: Prohíbe reinicios forzados si hay sesión abierta.
2. **Inyección en la ISO y Despliegue (`New-OptimizedWindowsISO-v2.ps1`):**
   - Inyección en `autounattend.xml` vía `Export-RomanOSUnattendCommands` cuando el perfil resuelto sea 2 o 3.
   - Inyección offline en el registro `SOFTWARE` del WIM montado.
3. **Auditoría Post-Instalación y Forense:**
   - Actualizar `PostInstall-Diagnostics.ps1` y `Audit-FreshInstallFootprint.ps1` para validar la directiva según el perfil seleccionado.
4. **Certificación en Test Harness:**
   - Cobertura 100% en `Test-OptimizedISO-v2.ps1` y `Invoke-TestSuite.ps1`.

---

## 3. Matriz de Cambios por Archivo

| Archivo | Acción | Descripción |
| :--- | :---: | :--- |
| `scripts/Core/Policy-Engine.ps1` | MODIFICAR | Registrar `POL_WU_NO_AUTO_UPDATE`, `POL_WU_AU_OPTIONS` y `POL_WU_NO_AUTO_REBOOT` para perfiles 2 y 3. |
| `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` | MODIFICAR | Añadir inyección en bloque fallback de unattend y en WIM offline para perfil >= 2. |
| `scripts/Modules/PostInstall-Diagnostics.ps1` | MODIFICAR | Auditar estado de `NoAutoUpdate` distinguiendo Perfil 1 (Auto) vs Perfiles 2/3 (Bajo Demanda). |
| `scripts/Modules/Audit-FreshInstallFootprint.ps1` | MODIFICAR | Auditar directiva GPO `NoAutoUpdate` en la sección de políticas del sistema. |
| `scripts/Testing/Test-OptimizedISO-v2.ps1` | MODIFICAR | Incorporar bloque de pruebas unitarias para PLAN-0059. |
| `docs/plans/README.md` | MODIFICAR | Registrar PLAN-0059 en el índice oficial. |

---

## 4. Plan de Verificación Empírica

1. **Inspección de Codificación UTF-8 con BOM y 0 Errores AST:**
   - Verificar cabecera `0xEF, 0xBB, 0xBF` en todos los scripts modificados.
   - Validar con `Parser::ParseFile`.
2. **Pruebas de Exportación y Aislamiento por Perfil:**
   - Verificar que `Export-RomanOSUnattendCommands -Profile 1` **NO** contiene `NoAutoUpdate`.
   - Verificar que `Export-RomanOSUnattendCommands -Profile 2` **SÍ** contiene `NoAutoUpdate = 1`.
   - Verificar que `Export-RomanOSUnattendCommands -Profile 3` **SÍ** contiene `NoAutoUpdate = 1`.
3. **Ejecución Completa de Pruebas:**
   - `Test-OptimizedISO-v2.ps1` (410+ PASS).
   - `Invoke-TestSuite.ps1` (100% PASS).

---

## 5. Resultados Empíricos de Verificación

- **Codificación y AST:** 5/5 archivos certificados con UTF-8 con BOM (`0xEF, 0xBB, 0xBF`) y 0 errores de sintaxis AST en Windows PowerShell 5.1.
- **Aislamiento por Perfiles:**
  - `Export-RomanOSUnattendCommands -Profile 1`: NoAutoUpdate omitido (actualizaciones automáticas preservadas para usuarios estándar).
  - `Export-RomanOSUnattendCommands -Profile 2`: NoAutoUpdate = 1, AUOptions = 2, NoAutoRebootWithLoggedOnUsers = 1 inyectados.
  - `Export-RomanOSUnattendCommands -Profile 3`: NoAutoUpdate = 1, AUOptions = 2, NoAutoRebootWithLoggedOnUsers = 1 inyectados.
- **Test Harness (`Test-OptimizedISO-v2.ps1`):** **427 PASS / 0 FAIL / 1 SKIP** (428 pruebas ejecutadas).
- **Master Test Suite (`Invoke-TestSuite.ps1`):** **SUCCESS (42.5s)** con todas las fases aprobadas.
