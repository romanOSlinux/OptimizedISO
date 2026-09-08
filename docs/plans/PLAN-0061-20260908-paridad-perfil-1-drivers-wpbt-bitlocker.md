# PLAN-0061: Paridad en Perfil 1: Protección de Drivers GPU, Bloqueo Bloatware BIOS (WPBT), Prevención de BitLocker Automático y Matriz de Servicios (DiagTrack / SysMain / WSearch)

**Estado:** COMPLETADO  
**Fecha:** 2026-09-08  
**Autor:** Antigravity AI Pair Programmer & Ingeniero de Software  
**Área:** Arquitectura de Perfiles, Fallback Unattend, Servicing Offline WIM, SetupComplete y Auditoría  
**Dependencias:** PLAN-0027 (Gestión de Drivers), PLAN-0055 (Poda Search Highlights), PLAN-0058 (Optimización SearchHost Working Set), PLAN-0059 (Windows Update On-Demand), PLAN-0060 (Estabilidad de Actualizaciones Acumulativas)

---

## 1. Contexto y Justificación Técnica

En la arquitectura de RomanOS existen 3 perfiles de optimización seleccionables durante la generación de la ISO:
- **Perfil 1 (Conservador / Estándar):** Mantiene todas las funciones de conectividad básica, telemetría estándar de Windows y búsqueda/descarga automática de Windows Update.
- **Perfil 2 (Gaming / Rendimiento):** Modo bajo demanda para Windows Update, telemetría reducida a nivel de seguridad, baja latencia y servicios corporativos deshabilitados.
- **Perfil 3 (Hardcore / Latencia Mínima):** Servicios secundarios deshabilitados, hipervisor apagado, diseñado para benchmarking y competición.

Tras el análisis arquitectónico, se identificaron puntos críticos que debían unificarse y calibrarse entre los perfiles:
1. **Protección de Drivers GPU (AMD/NVIDIA/Intel Arc):** `ExcludeWUDriversInQualityUpdate = 1`, `SearchOrderConfig = 0` y `PreventDeviceMetadataFromNetwork = 1`. Deben ser idénticos en Perfil 1 para impedir que Windows Update degrade controladores gráficos certificados.
2. **Bloqueo Bloatware BIOS (WPBT):** `DisableWPBT = 1`. Debe aplicarse en Perfil 1 para evitar la inyección automática de binarios OEM persistentes desde la tabla ACPI de la placa base.
3. **Prevención BitLocker (SSD):** `PreventDeviceEncryption = 1`. Debe aplicarse en Perfil 1 para evitar el cifrado silencioso automático del SSD durante la instalación limpia de Windows 11 (24H2).
4. **Telemetría y Diagnósticos (`DiagTrack` / `dmwappushservice`):** Debe deshabilitarse también en Perfil 1 en `SetupComplete.cmd`. Ninguna aplicación depende de este servicio y su desactivación ahorra memoria (~30 MB) y ciclos de CPU sin efectos colaterales.
5. **Superfetch / Prefetch (`SysMain`):** Se promueve la deshabilitación a Perfil 2+ (Gaming y Hardcore) para eliminar picos de I/O en SSDs durante el juego. Se mantiene activo en Perfil 1 para preservar el algoritmo de compresión de memoria RAM en equipos modestos o con HDD.
6. **Indexador de Búsqueda (`WSearch`):** Se mantiene **activo y optimizado quirúrgicamente** (con la poda de Working Set a 18 MB de PLAN-0058) en Perfiles 1 y 2 para preservar la búsqueda instantánea del Menú Inicio y Explorador. Su desactivación completa queda reservada **exclusivamente al Perfil 3 (Hardcore)**.

---

## 2. Matriz Técnica Oficial de Perfiles

| Característica / Servicio | Perfil 1 (Conservador) | Perfil 2 (Gaming) | Perfil 3 (Hardcore) | Fundamento Técnico |
| :--- | :---: | :---: | :---: | :--- |
| **Protección Drivers GPU (AMD/NVIDIA)** | ✅ **Activo** | ✅ **Activo** | ✅ **Activo** | Drivers retenidos como opcionales, sin sobreescrituras de WU. |
| **Bloqueo Bloatware BIOS (WPBT)** | ✅ **Activo** | ✅ **Activo** | ✅ **Activo** | Tabla ACPI bloqueada para evitar binarios OEM persistentes. |
| **Prevención BitLocker (SSD)** | ✅ **Activo** | ✅ **Activo** | ✅ **Activo** | Sin cifrado automático en instalación limpia 24H2. |
| **Telemetría y Diagnósticos (`DiagTrack`)** | ❌ **Deshabilitado** | ❌ **Deshabilitado** | ❌ **Deshabilitado** | Cero telemetría invasiva en toda la ISO (sin impacto en apps). |
| **Superfetch / Prefetch (`SysMain`)** | 🟢 Habilitado | ❌ **Deshabilitado** | ❌ **Deshabilitado** | Deshabilitado en Gaming para cero I/O; activo en P1 para compresión de RAM. |
| **Indexador de Búsqueda (`WSearch`)** | 🟢 Activo (Podado 18MB) | 🟢 Activo (Podado 18MB) | ❌ **Deshabilitado** | Preserva búsqueda instantánea del Menú Inicio; apagado solo en Hardcore. |

---

## 3. Plan de Modificaciones en el Código

### 3.1. `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`
1. **Fallback `autounattend.xml` (Líneas ~4980–5040):**
   - Mover las 5 directivas (`ExcludeWUDriversInQualityUpdate`, `SearchOrderConfig`, `PreventDeviceMetadataFromNetwork`, `DisableWPBT`, `PreventDeviceEncryption`) fuera de `if ($optProfile -ge 2)` hacia el bloque universal base (`specialize`) para todos los perfiles (`Profiles = 1, 2, 3`).
   - Mantener dentro de `if ($optProfile -ge 2)` únicamente:
     - `AllowTelemetry = 0` (Nivel seguridad)
     - `NoAutoUpdate = 1`, `AUOptions = 2`, `NoAutoRebootWithLoggedOnUsers = 1` (Windows Update Bajo Demanda).
2. **Generación de `SetupComplete.cmd` (Líneas ~4620–4675):**
   - Mover la desactivación de `DiagTrack` y `dmwappushservice` al bloque base universal (para todos los perfiles 1, 2 y 3).
   - En `if ($optProfileIntSetup -ge 2)`: Deshabilitar `SysMain` (`sc config SysMain start=disabled`) además de los servicios corporativos/oficina y telemetría secundaria (`WerSvc`, `TroubleshootingSvc`, `BDESVC`).
   - En `if ($optProfileIntSetup -eq 3)`: Mantener `WSearch`, `Spooler`, `WlanSvc`, `bthserv`, hipervisor apagado, etc.
3. **Inyección Offline en SOFTWARE Hive (`$swTweaks`, Líneas ~6435–6460):**
   - Añadir en la lista base de tweaks offline:
     - `ExcludeWUDriversInQualityUpdate = 1` (`HKLM\OfflineSoftware\Policies\Microsoft\Windows\WindowsUpdate`)
     - `SearchOrderConfig = 0` (`HKLM\OfflineSoftware\Microsoft\Windows\CurrentVersion\DriverSearching`)
     - `PreventDeviceMetadataFromNetwork = 1` (`HKLM\OfflineSoftware\Policies\Microsoft\Windows\Device Metadata`)
4. **Inyección Offline en SYSTEM Hive (`$sysTweaks`, Líneas ~6518–6543):**
   - Añadir en la lista base de tweaks offline:
     - `DisableWPBT = 1` (`HKLM\OfflineSystem\ControlSet001\Control\Session Manager`)
     - `PreventDeviceEncryption = 1` (`HKLM\OfflineSystem\ControlSet001\Control\BitLocker`)

### 3.2. `scripts/Modules/Audit-FreshInstallFootprint.ps1`
- Registrar en `$policiesToAudit` las directivas `ExcludeWUDriversInQualityUpdate`, `SearchOrderConfig`, `PreventDeviceMetadataFromNetwork`, `DisableWPBT` y `PreventDeviceEncryption`.

### 3.3. `scripts/Testing/Test-OptimizedISO-v2.ps1`
- Agregar aserciones semánticas dedicadas:
  - Verificar que `Export-RomanOSUnattendCommands -Profile 1` genera comandos para `ExcludeWUDriversInQualityUpdate`, `SearchOrderConfig`, `PreventDeviceMetadataFromNetwork`, `DisableWPBT` y `PreventDeviceEncryption`.
  - Verificar que el fallback autounattend del Builder incluye estas directivas en el bloque base de Perfil 1.
  - Verificar que la inyección offline de SOFTWARE y SYSTEM del Builder incluye estas directivas para todos los perfiles.
  - Verificar que en `SetupComplete.cmd` `DiagTrack` está en el bloque base para todos los perfiles, `SysMain` está deshabilitado en Perfiles 2+, y `WSearch` permanece en Perfil 3.
  - Verificar que `Audit-FreshInstallFootprint.ps1` contiene estas directivas en su catálogo de auditoría.

---

## 4. Plan de Verificación Empírica

1. **Prueba de Codificación y Sintaxis PowerShell 5.1 (Regla 4):**
   - Codificación UTF-8 con BOM en todos los archivos modificados.
   - Validación con AST parser y ejecución en frío con `powershell.exe -NoProfile -Command`.
2. **Ejecución del Test Harness:**
   - Notificar inicio con emoji reglamentario (Regla 7).
   - Ejecutar `Test-OptimizedISO-v2.ps1` esperando 100% PASS.
   - Ejecutar la suite completa `Invoke-TestSuite.ps1` esperando 100% PASS.
   - Notificar finalización con resumen reglamentario (Regla 7).
3. **Verificación de Git y Cierre:**
   - Commit atómico descriptivo y sincronización con `origin/feature/offline-ui-tweaks`.
