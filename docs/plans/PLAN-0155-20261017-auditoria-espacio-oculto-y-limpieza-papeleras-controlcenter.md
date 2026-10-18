# PLAN-0155: Auditoría Forense de Espacio Oculto en Disco y Limpieza Segura de Papeleras en romanOS Control Center

**Número Correlativo:** 0155  
**Fecha:** 2026-10-17  
**Estado:** COMPLETADO  
**Módulos Afectados:**
- `scripts/Modules/Invoke-WindowsMaintenance.ps1`
- `scripts/GUI/romanOS-ControlCenter.ps1`
- `scripts/Testing/Test-GuiIntegrityAndFunctionality.ps1`
- `Auditoria-GUIs-romanOS.html`
- `docs/plans/README.md`

---

## 1. Contexto y Diagnóstico del Problema

Tras la instalación de actualizaciones de Windows (acumulativas de seguridad como KB5127648/KB5127647), el espacio en disco en la unidad del sistema (`C:\`) experimenta una reducción drástica (en este caso de ~131 GB a 113.27 GB, perdiendo ~17.73 GB).  
El usuario común no tiene visibilidad de cómo o en qué se ocupó dicho espacio porque se divide en "zonas ciegas" del sistema de archivos y almacenes de Windows:
1. `C:\Windows\SoftwareDistribution\Download`: Paquetes de instalación descargados y extraídos (`RollupFix` de más de 5.2 GB).
2. `C:\Windows\WinSxS`: Almacén de componentes con copias de respaldo de archivos anteriores reemplazados (~6 a 8 GB).
3. `System Volume Information`: Instantáneas VSS / Puntos de restauración automáticos creados por Windows Update (~3 a 5 GB).
4. `pagefile.sys` / `swapfile.sys`: Archivos de memoria virtual reajustados tras reinicio.
5. Papeleras ocultas y desatendidas:
   - `C:\$Recycle.Bin`: Papelera de reciclaje de Windows con archivos masivos eliminados (ej. imágenes ISO de ~24 GB).
   - `C:\.Trash-*`: Papeleras creadas por sistemas externos POSIX/Linux/WSL en volúmenes NTFS que Windows no audita ni expone en la interfaz gráfica (en este host: **33.4 GB** en `C:\.Trash-1000`).

Actualmente, `romanOS Control Center` cuenta con herramientas de saneamiento pero carece de:
- Un botón de **auditoría forense de almacenamiento oculto** con un solo clic que desglose todas estas categorías sin modificar nada.
- Una opción de saneamiento segura para vaciar la **Papelera de Reciclaje** (`$Recycle.Bin`) y purgar carpetas residuales `.Trash-*` de subsistemas o dual-boot.

---

## 2. Fundamento Técnico y Fuentes Oficiales

1. **Cmdlet Oficial `Clear-RecycleBin` (Microsoft Learn):**
   - Microsoft PowerShell 5.1/7+ implementa el cmdlet oficial `Clear-RecycleBin -Force` que invoca la API `SHEmptyRecycleBinW` de Windows Shell para limpiar la papelera en todos los volúmenes sin riesgo de corrupción de metadata NTFS.
2. **DISM Component Store APIs (Microsoft Learn: *Clean Up the WinSxS Folder*):**
   - `DISM.exe /Online /Cleanup-Image /AnalyzeComponentStore` para auditar la necesidad real de limpieza.
   - `DISM.exe /Online /Cleanup-Image /StartComponentCleanup [/ResetBase]` para purgar versiones obsoletas de componentes de Windows Update.
3. **Delivery Optimization y Cache de Actualizaciones:**
   - Detención transitoria y controlada de servicios (`wuauserv`, `bits`, `dosvc`) para vaciado de `SoftwareDistribution\Download` y caché de Delivery Optimization.
4. **Inspección Segura de Papeleras POSIX en NTFS:**
   - Detección precisa de carpetas `.Trash-*` en unidades locales NTFS con verificación de pertenencia a directorios ajenos al sistema Windows, garantizando cero falsos positivos y preservando la integridad de las particiones.

---

## 3. Objetivos del Plan

1. **Motor de Auditoría Forense (`Invoke-WindowsMaintenance.ps1`):**
   - Implementar la función canónica `Get-RomanOSStorageFootprint` y el switch `-AuditStorage` que mida en segundos:
     - Caché de descargas de Windows Update (`SoftwareDistribution\Download`).
     - Almacén WinSxS (análisis de componentes).
     - Papelera de Reciclaje de Windows (`$Recycle.Bin`).
     - Papeleras POSIX / Linux (`.Trash-*`).
     - Residuos de instalación / rollback (`$WINDOWS.~BT`, `$WinREAgent`).
     - Temporales y volcados (`Temp`, `MEMORY.DMP`, minidumps).
     - Archivos de hibernación y paginación (`hiberfil.sys`, `pagefile.sys`).
   - Implementar el switch `-IncludeRecycleBin` para vaciar de forma segura `$Recycle.Bin` y purgar carpetas `.Trash-*`.
2. **Interfaz Gráfica (`romanOS-ControlCenter.ps1`):**
   - En Tarjeta 1 (Telemetría de Almacenamiento): Añadir el botón `btnAuditInvisibleSpace` (**"🔍 Auditar Espacio Oculto y Residuos"**) con tooltip detallado y streaming en vivo de métricas en consola.
   - En Tarjeta 2 (Higiene y Limpieza Profunda): Añadir el checkbox `chkMaintRecycleBin` (**"Papelera de reciclaje y residuos externos (.Trash-*)"**) conectado a `-IncludeRecycleBin`.
3. **Garantía de Calidad y Cascada:**
   - Codificación UTF-8 con BOM en todos los scripts modificados.
   - Validación en frío contra `powershell.exe` (Windows PowerShell 5.1).
   - Verificación de contratos y actualización del arnés `Test-GuiIntegrityAndFunctionality.ps1`.
   - Actualización de la documentación en `Auditoria-GUIs-romanOS.html` y registro en `docs/plans/README.md`.

---

## 4. Fases de Ejecución

- [x] **Fase 1: Motor de Mantenimiento (`Invoke-WindowsMaintenance.ps1`)**
  - Implementar `Get-RomanOSStorageFootprint`.
  - Añadir soporte a `-AuditStorage` e `-IncludeRecycleBin`.
- [x] **Fase 2: Interfaz Gráfica (`romanOS-ControlCenter.ps1`)**
  - Incorporar XAML: `btnAuditInvisibleSpace` y `chkMaintRecycleBin`.
  - Cablear eventos de clic y despacho asíncrono con streaming a consola.
- [x] **Fase 3: Verificación y Certificación**
  - Ejecutar auditoría en vivo para validar métricas reales contra el disco.
  - Certificar contratos en `Test-GuiIntegrityAndFunctionality.ps1`.
  - Probar ejecución bajo Windows PowerShell 5.1.
- [x] **Fase 4: Sincronización Documental y Commit Atómico**
  - Actualizar `Auditoria-GUIs-romanOS.html` y `docs/plans/README.md`.
  - Commit atómico con trazabilidad completa.
