# PLAN-0055: Neutralización Quirúrgica de Search Highlights, Bing y WebView2 en Segundo Plano y Corrección de Política de Contraseña en Blanco

- **ID del Plan:** PLAN-0055
- **Fecha:** 2026-09-07
- **Autor:** romanOS Engineering & Antigravity Agent
- **Estado:** COMPLETADO
- **Área:** Arquitectura Global (SSOT Policy-Engine), `Builder\New-OptimizedWindowsISO-v2.ps1`, `sources\autounattend.xml`, `Modules\Win11-Debloat-v3-Adaptive.ps1`, `Modules\PostInstall-Diagnostics.ps1`, `Testing\Test-OptimizedISO-v2.ps1`

---

## 1. Contexto y Diagnóstico del Problema

### 1.1 El Problema de `SearchHost.exe` y `msedgewebview2.exe` en Segundo Plano
En instalaciones estándar de Windows 11 (22H2, 23H2 y 24H2), los usuarios observan que procesos como `SearchHost.exe` y múltiples instancias de `msedgewebview2.exe` (Microsoft Edge WebView2 Runtime) permanecen constantemente activos en memoria, consumiendo entre **200 MB y 450 MB de RAM**, realizando peticiones de red en segundo plano a servidores de Bing/MSN y generando picos periódicos de CPU.

La investigación en fuentes oficiales de Microsoft (Policy CSP - Search, Group Policy Administrative Templates) reveló que:
1. **Search Highlights (Contenido Dinámico en el Cuadro de Búsqueda):** Windows 11 separa la búsqueda web tradicional del contenido dinámico de la caja de búsqueda. Incluso si la búsqueda web clásica está desactivada, el parámetro `EnableDynamicContentInWSB` permanece activo por defecto.
2. **Invocación Forzada de WebView2:** `SearchHost.exe` instancia forzosamente entre 3 y 6 subprocesos de `msedgewebview2.exe` (Browser process, GPU process, Network service y Renderers) para precargar los doodles, noticias y tendencias web de Bing dentro de la interfaz XAML.
3. **Peligro del Debloat Destructivo:** 
   - Forzar la eliminación de `SearchHost.exe` (renombrado de binarios o matado por watchdog) **rompe al 100% el menú Inicio** (no permite teclear para buscar aplicaciones locales y genera bucles de error COM RPC `0x800706BA`).
   - Desinstalar forzosamente `msedgewebview2.exe` provoca **caídas críticas (`0x80070002`) en aplicaciones modernas** (Xbox App, Game Bar, Discord, EA App, WhatsApp Desktop, Teams) y Windows Update (LCU) vuelve a descargarlo e instalarlo en la siguiente actualización acumulativa.

### 1.2 Discrepancia en la Directiva `LimitBlankPasswordUse` (Falso Positivo de Diagnóstico)
En el informe de post-instalación de `PostInstall-Diagnostics.ps1`, se reportaba la siguiente advertencia:
```text
Base - OOBE & AutoLogon | Permitir uso y autenticacion con contrasena en blanco en cuentas locales | LimitBlankPasswordUse | 0 | Valor discrepante (1 != 0)
```
- **Causa:** En PLAN-0049, la directiva `POL_AUTH_LIMIT_BLANK_PASSWORD` en `Policy-Engine.ps1` se definió erróneamente con `ExpectedValue = 0`.
- **Realidad de Seguridad:** En Windows 11, `LimitBlankPasswordUse = 1` (*Accounts: Limit local account use of blank passwords to console logon only*) es la directiva recomendada por Microsoft: permite el inicio de sesión local (pantalla/teclado físico) sin contraseña o con AutoLogon, pero **bloquea el acceso remoto no autenticado por red** (RDP, SMB, WinRM). `Invoke-WindowsSecurityHardening.ps1` lo fija en `1` por seguridad, produciendo la discrepancia con el motor de políticas.

---

## 2. Objetivos Técnicos

1. **Neutralización Quirúrgica de Cero Overhead (Zero-Overhead Search):**
   - Eliminar el 100% de los disparadores web que levantan `msedgewebview2.exe` en segundo plano sin eliminar los binarios de WebView2 del sistema.
   - Forzar a `SearchHost.exe` a operar exclusivamente en modo indexador local, permitiendo que el Process Lifecycle Manager (PLM) de Windows lo suspenda de inmediato (0.0% CPU y ~15 MB de RAM).
   - Mantener la búsqueda de aplicaciones locales instantánea (<10 ms).
2. **Registro de Directivas Canónicas en `Policy-Engine.ps1` (SSOT):**
   - `POL_SEARCH_DYNAMIC_CONTENT_WSB`: `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search` -> `EnableDynamicContentInWSB = 0`.
   - `POL_SEARCH_CONNECTED_METERED`: `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search` -> `ConnectedSearchUseWebOverMeteredConnections = 0`.
   - `POL_SEARCH_CORTANA_ALLOW`: `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search` -> `AllowCortana = 0`.
   - Directivas de perfil predeterminado de usuario (Default User Hive):
     - `HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings` -> `IsDynamicSearchBoxEnabled = 0`.
     - `HKCU\Software\Microsoft\Windows\CurrentVersion\Search` -> `BingSearchEnabled = 0`, `CortanaConsent = 0`, `SearchboxTaskbarMode = 1`.
3. **Corrección de Seguridad en `LimitBlankPasswordUse`:**
   - Actualizar `POL_AUTH_LIMIT_BLANK_PASSWORD` en `Policy-Engine.ps1` a `ExpectedValue = 1`.
   - Alinear `autounattend.xml` y `New-OptimizedWindowsISO-v2.ps1` para configurar `LimitBlankPasswordUse = 1` (blindaje de red con soporte de inicio local sin clave).
4. **Inyección en Cascada y Paridad del Ecosistema:**
   - Inyectar las claves en el WIM montado (`HKLM` y `Default User NTUSER.DAT`).
   - Sincronizar `Win11-Debloat-v3-Adaptive.ps1` y `PostInstall-Diagnostics.ps1`.
   - Actualizar el Test Harness `Test-OptimizedISO-v2.ps1` para validar la nueva arquitectura al 100%.

---

## 3. Matriz de Cambios Propuestos

### A. SSOT: `scripts/Core/Policy-Engine.ps1`
- Actualizar `POL_AUTH_LIMIT_BLANK_PASSWORD`:
  - `ExpectedValue = 1`
  - `Description = "Restringir uso de cuentas con contrasena en blanco exclusivamente a inicio de sesion en consola local (Seguridad de Red)"`
- Agregar `POL_SEARCH_DYNAMIC_CONTENT_WSB`:
  - Clave: `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search`
  - Valor: `EnableDynamicContentInWSB` = 0 (REG_DWORD)
  - Descripción: "Desactivar contenido dinamico de Search Highlights en cuadro de busqueda (evita msedgewebview2.exe)"
- Agregar `POL_SEARCH_CONNECTED_METERED`:
  - Clave: `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search`
  - Valor: `ConnectedSearchUseWebOverMeteredConnections` = 0 (REG_DWORD)
- Agregar `POL_SEARCH_CORTANA_ALLOW`:
  - Clave: `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search`
  - Valor: `AllowCortana` = 0 (REG_DWORD)
- Exportar en `Export-RomanOSUnattendCommands` y en las colecciones de directivas canónicas.

### B. Builder: `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`
- En Paso 5 (WIM offline registry injection):
  - Inyectar en `HKLM` montado las nuevas políticas de `Windows Search`.
  - Inyectar en `C:\Users\Default\NTUSER.DAT` montado las claves de usuario (`IsDynamicSearchBoxEnabled = 0`, `BingSearchEnabled = 0`, `CortanaConsent = 0`, `SearchboxTaskbarMode = 1`).
- En la generación de `autounattend.xml`:
  - Ajustar el comando de `LimitBlankPasswordUse` a `/d 1`.
  - Incluir `EnableDynamicContentInWSB = 0`.

### C. Módulos Consumidores
- **`scripts/Modules/Win11-Debloat-v3-Adaptive.ps1`:**
  - Sincronizar la aplicación de `EnableDynamicContentInWSB`, `IsDynamicSearchBoxEnabled` y `BingSearchEnabled`.
- **`scripts/Modules/PostInstall-Diagnostics.ps1`:**
  - Auditar las nuevas claves de neutralización y verificar que `LimitBlankPasswordUse` sea evaluado con `1` sin falsas discrepancias.

### D. Test Harness: `scripts/Testing/Test-OptimizedISO-v2.ps1`
- Incrementar `$EXPECTED_FUNCS` o asertos de directivas.
- Incorporar bloque de pruebas para PLAN-0055:
  - Verificación de políticas `POL_SEARCH_DYNAMIC_CONTENT_WSB` y `POL_AUTH_LIMIT_BLANK_PASSWORD` con `ExpectedValue = 1`.
  - Verificación de exportación en `Export-RomanOSUnattendCommands`.
  - Verificación de inyección en el Builder.

---

## 4. Plan de Verificación Empírica

1. **Análisis Estático y Codificación:**
   - Validar codificación UTF-8 con BOM (`0xEF, 0xBB, 0xBF`) en todos los scripts modificados.
   - Ejecutar análisis sintáctico AST en Windows PowerShell 5.1 (`powershell.exe`).
2. **Pruebas del Test Harness:**
   - Ejecutar `Test-OptimizedISO-v2.ps1` en PowerShell 5.1 (`-STA`).
   - Exigir **100% PASS** (0 FAIL).
3. **Suite Completa del Repositorio:**
   - Ejecutar `Invoke-TestSuite.ps1` verificando los 36 scripts del repositorio.
4. **Trazabilidad Git:**
   - Cero binarios pesados rastreados.
   - Commit atómico de cierre.
