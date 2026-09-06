# PLAN-0024: Suite Modular de Menús Contextuales Optimizados para Gaming y Power-Users

**Fecha:** 2026-09-05  
**Estado:** COMPLETADO  
**Rama:** `feature/offline-ui-tweaks`  
**Autor:** Agente Antigravity / Pair-Programming  
**Fundamentación Técnica:** Documentación oficial de Microsoft Learn (*Creating Shortcut Menu Handlers*, *Customizing a Shortcut Menu Using Static Verbs*, *Advanced Query Syntax*).

---

## 1. Justificación y Objetivos

En sistemas optimizados para gaming y usuarios avanzados (*OptimizedISO* / *romanOS*), el menú contextual moderno de Windows 11 presenta fricción operativa:
1. Oculta herramientas críticas tras la opción "Mostrar más opciones" (`Shift + F10`).
2. Genera latencia adicional al invocar el runtime XAML de `explorer.exe`.
3. Carece de atajos inmediatos requeridos por gamers y modders (tales como *Take Ownership* para modificación de archivos de juegos, bloqueo rápido de ejecutables en firewall, cálculo de hash SHA-256 de mods/parches, alternancia a máxima energía y reinicio directo a UEFI/BIOS).

La sección 15 actual de `scripts/Win11-Debloat-v3-Adaptive.ps1` implementa únicamente 6 entradas básicas sin menús en cascada y sin habilitar el modo clásico de un solo clic, saturando el menú raíz.

### Objetivos Principales:
1. **Crear una utilidad modular y desacoplada:** `scripts/Add-OptimizedContextMenus.ps1` (y su lanzador `.cmd`) que permita aplicar (`-Apply`), revertir (`-Remove`) y alternar el menú clásico (`-ClassicMenu` / `-RestoreModernMenu`) de forma idempotente y segura.
2. **Organización jerárquica en cascada:** Utilizar verbos estáticos nativos de Windows con subclaves `shell` y propiedades oficiales (`MUIVerb`, `Icon`, `HasLUAShield`, `Position`, `AppliesTo`, `SeparatorBefore`) para evitar la saturación visual.
3. **Enfoque 100% Gamer & Zero-Bloat:**
   - Atajos directos de recuperación y rendimiento (Reiniciar Explorer, Vaciar DNS, Ultimate Performance, HAGS / Modo Juego).
   - Herramientas de modding (Tomar posesión con permisos ACL completos, Abrir con Bloc de Notas cualquier archivo, Hash SHA-256, Bloqueo/Desbloqueo en Firewall para ejecutables).
   - Opciones avanzadas de energía (Reinicio directo en Firmware UEFI/BIOS y Menú de Recuperación).
4. **Integración bidireccional en el ecosistema:**
   - Actualizar la Sección 15 de `scripts/Win11-Debloat-v3-Adaptive.ps1` para sincronizar con este catálogo enriquecido.
   - Integrar la opción en `scripts/romanOS-Toolkit.ps1` (en `QuickActions` o módulo de personalización) para gestión interactiva post-instalación.
5. **Cumplimiento estricto de estándares:**
   - Formato UTF-8 con BOM en todos los scripts de PowerShell.
   - Compatibilidad nativa garantizada en Windows PowerShell 5.1 (`powershell.exe`) y PowerShell 7+ (`pwsh`).
   - Cero dependencias binarias pesadas o paquetes externos; 100% nativo mediante el motor del Shell de Windows.

---

## 2. Catálogo de Opciones y Arquitectura de Registro

### A. Fondo de Escritorio y Carpetas (`Directory\Background` y `DesktopBackground`)

| Opción / Verbo | Tipo / Ubicación | Propiedades Oficiales | Comando / Acción |
|---|---|---|---|
| **Terminal (Administrador)** | Directo (`Directory\Background\shell\PSAdmin`) | `Icon`: `imageres.dll,109`<br>`HasLUAShield`: `""`<br>`Position`: `"Top"` | Lanza PowerShell elevado en la ruta del directorio activo (`%V`). |
| **Reiniciar Explorador** | Directo (`DesktopBackground\Shell\RestartExplorer`) | `Icon`: `imageres.dll,178`<br>`Position`: `"Top"` | `taskkill /f /im explorer.exe & start explorer.exe` |
| **Menú Cascada: Gaming y Rendimiento** | Cascada (`Directory\Background\shell\GamerTools`) | `MUIVerb`: `"Gaming y Rendimiento ⚡"`<br>`Icon`: `imageres.dll,264`<br>`SubCommands`: `""` | Submenú contenedor. |
| ├─ *Plan Máximo Rendimiento* | Hijo en cascada (`...\shell\01_PowerMax`) | `Icon`: `shell32.dll,238` | `powercfg /s e9a42b02-d5df-448d-aa00-03f14749eb61` |
| ├─ *Vaciar Caché DNS (Flush DNS)* | Hijo en cascada (`...\shell\02_FlushDNS`) | `Icon`: `imageres.dll,23` | `ipconfig /flushdns` con notificación limpia. |
| ├─ *Gráficos Avanzados y HAGS* | Hijo en cascada (`...\shell\03_HAGS`) | `Icon`: `shell32.dll,16` | Abre `ms-settings:display-advancedgraphics`. |
| └─ *Modo de Juego de Windows* | Hijo en cascada (`...\shell\04_GameMode`) | `Icon`: `imageres.dll,100` | Abre `ms-settings:gaming-gamemode`. |
| **Menú Cascada: Herramientas del Sistema** | Cascada (`Directory\Background\shell\SystemTools`) | `MUIVerb`: `"Herramientas del Sistema ⚙️"`<br>`Icon`: `imageres.dll,104`<br>`SubCommands`: `""` | Submenú contenedor. |
| ├─ *Administrador de Tareas* | Hijo en cascada (`...\shell\01_TaskMgr`) | `Icon`: `taskmgr.exe` | `taskmgr.exe` |
| ├─ *Administrador de Dispositivos* | Hijo en cascada (`...\shell\02_DevMgmt`) | `Icon`: `devmgmt.msc` | `devmgmt.msc` |
| ├─ *Conexiones de Red* | Hijo en cascada (`...\shell\03_Network`) | `Icon`: `ncpa.cpl` | `ncpa.cpl` |
| ├─ *Servicios de Windows* | Hijo en cascada (`...\shell\04_Services`) | `Icon`: `services.msc` | `services.msc` |
| ├─ *Limpieza de Disco* | Hijo en cascada (`...\shell\05_CleanMgr`) | `Icon`: `cleanmgr.exe` | `cleanmgr.exe /lowdisk` |
| ├─ *Reparar Sistema (DISM + SFC)* | Hijo en cascada (`...\shell\06_Repair`) | `Icon`: `imageres.dll,54`<br>`HasLUAShield`: `""` | `powershell.exe -Command "Start-Process cmd.exe -ArgumentList '/k DISM /Online /Cleanup-Image /RestoreHealth && sfc /scannow' -Verb RunAs"` |
| └─ *Panel Maestro (God Mode)* | Hijo en cascada (`...\shell\07_GodMode`) | `Icon`: `imageres.dll,104` | `explorer.exe shell:::{ED7BA470-8E54-465E-825C-99712043E01C}` |
| **Menú Cascada: Opciones de Energía** | Cascada (`DesktopBackground\Shell\PowerOptions`) | `MUIVerb`: `"Opciones de Energía ⚡"`<br>`Icon`: `shell32.dll,27`<br>`Position`: `"Bottom"` | Submenú contenedor. |
| ├─ *Reiniciar en Firmware UEFI / BIOS* | Hijo en cascada (`...\shell\01_UEFI`) | `Icon`: `shell32.dll,220`<br>`HasLUAShield`: `""` | `shutdown.exe /r /fw /t 0` |
| ├─ *Reiniciar en Menú de Recuperación* | Hijo en cascada (`...\shell\02_Recovery`) | `Icon`: `shell32.dll,27` | `shutdown.exe /r /o /t 0` |
| └─ *Apagado Completo (Cero Fast Startup)* | Hijo en cascada (`...\shell\03_ColdShutdown`) | `Icon`: `shell32.dll,27` | `shutdown.exe /s /f /t 0` |

---

### B. Archivos y Carpetas (`*`, `Directory`, `exefile`)

| Opción / Verbo | Ubicación | Propiedades Oficiales | Comando / Acción |
|---|---|---|---|
| **Tomar Posesión (Take Ownership)** | `*\shell\TakeOwnership`<br>`Directory\shell\TakeOwnership` | `Icon`: `imageres.dll,73`<br>`HasLUAShield`: `""`<br>`Position`: `"Top"` | `cmd.exe /c takeown /f "%1" /r /d y && icacls "%1" /grant *S-1-3-0:(OI)(CI)F /t /c /l /q` |
| **Abrir con Bloc de Notas** | `*\shell\OpenWithNotepad` | `Icon`: `notepad.exe,0` | `notepad.exe "%1"` |
| **Calcular Hash SHA-256** | `*\shell\HashSHA256` | `Icon`: `imageres.dll,102` | `cmd.exe /c certutil -hashfile "%1" SHA256 & pause` |
| **Bloquear en Firewall de Windows** | `exefile\shell\BlockInFirewall` | `Icon`: `imageres.dll,207`<br>`HasLUAShield`: `""`<br>`AppliesTo`: `System.FileExtension:=.exe` | `cmd.exe /c netsh advfirewall firewall add rule name="Block_%~nx1" dir=out program="%1" action=block & pause` |
| **Desbloquear en Firewall** | `exefile\shell\UnblockInFirewall` | `Icon`: `imageres.dll,208`<br>`HasLUAShield`: `""`<br>`AppliesTo`: `System.FileExtension:=.exe` | `cmd.exe /c netsh advfirewall firewall delete rule name="Block_%~nx1" & pause` |

---

### C. Modo Clásico Predeterminado (Un Solo Clic)
- **Activación:** Registro de `InprocServer32` vacío en:
  - `HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32`
  - `HKU\.DEFAULT\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32` (para nuevos usuarios).
- **Desactivación limpia:** Eliminación recursiva de la subclave CLSID para restaurar la vista nativa de Windows 11.

---

## 3. Plan de Modificación de Archivos

### 1. `scripts/Add-OptimizedContextMenus.ps1` [NUEVO]
- Script PowerShell completo, modular, con parámetros `-Apply`, `-Remove`, `-ClassicMenu`, `-RestoreModernMenu`, `-Quiet`.
- Codificación estricta UTF-8 con BOM.
- Auto-elevación UAC si no corre como Administrador.
- Soporte para desinstalación completa e idempotencia.

### 2. `scripts/Add-OptimizedContextMenus.cmd` [NUEVO]
- Lanzador batch estándar de la suite con `-STA -NoProfile -ExecutionPolicy Bypass`.

### 3. `scripts/Win11-Debloat-v3-Adaptive.ps1` [MODIFICACIÓN]
- Actualizar la Sección 15 para integrar este catálogo o invocar `Add-OptimizedContextMenus.ps1` cuando esté presente, manteniendo fallback nativo autónomo.
- Sincronizar el resumen final de ejecución para reflejar las nuevas capacidades.

### 4. `scripts/romanOS-Toolkit.ps1` [MODIFICACIÓN]
- Añadir la opción en el menú interactivo (`QuickActions`) para aplicar/revertir el menú contextual optimizado con un solo número.

### 5. `docs/plans/README.md` [MODIFICACIÓN]
- Registrar `PLAN-0024` en la tabla de planes con estado `PENDIENTE`.

---

## 4. Plan de Verificación

1. **Verificación de Codificación:**
   - Comprobar que los archivos nuevos tengan cabecera BOM (`0xEF, 0xBB, 0xBF`).
2. **Validación de Sintaxis en Windows PowerShell 5.1:**
   - Probar en frío contra `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'scripts\Add-OptimizedContextMenus.ps1' -WhatIf }"`
   - Probar `Win11-Debloat-v3-Adaptive.ps1` y `romanOS-Toolkit.ps1` sin errores de parser AST.
3. **Verificación de Idempotencia:**
   - Ejecutar `-Apply` dos veces consecutivas: debe completarse sin errores de claves duplicadas ni excepciones.
   - Ejecutar `-Remove` y verificar que las claves en `HKLM:\SOFTWARE\Classes` y `HKCU` se limpien completamente.
4. **Verificación de Registro en Git:**
   - Realizar commit atómico de los cambios una vez verificados empíricamente.
