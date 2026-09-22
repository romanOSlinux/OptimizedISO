# PLAN-0099: romanOS State Snapshot & Rollback Engine

**Fecha:** 2026-09-21  
**Estado:** PENDIENTE  
**Autor:** Antigravity / romanOS Software Engineering  
**Alcance:** Ecosistema Completo (Modules, GUI Control Center, Toolkit Maestro, ISO Builder, $OEM$, Testing Harness)

---

## 1. Contexto y Justificación Técnica

En sistemas operativos optimizados y entornos de alto rendimiento (Windows 11 24H2 / 25H2), los usuarios frecuentemente alternan entre perfiles de uso (Gaming, Productividad, Desarrollo, Streaming), aplican scripts de debloat agresivo o reciben actualizaciones acumulativas de Windows Update.

Actualmente, el repositorio cuenta con salvaguardas parciales (como la creación de un punto de restauración aislado en `Win11-Debloat-v3-Adaptive.ps1`), pero **carece de un motor integral y determinista de instantáneas (Snapshots) de configuración y reversión atómica (Rollback)**. 

### Deficiencias Actuales
1. Si un usuario aplica optimizaciones de red o registro y experimenta incompatibilidad con una VPN corporativa, un juego específico o un software de trabajo, el retorno al estado anterior suele requerir formateo o una investigación manual tediosa.
2. Los Puntos de Restauración tradicionales de Windows (`SystemRestore`) ocupan gigabytes de disco en el Shadow Storage de VSS, a menudo están deshabilitados en instalaciones desatendidas ligeras y son lentos de aplicar (~15 a 30 minutos).
3. No existe un registro versionado estructurado con hashes SHA-256 que permita auditar qué claves de registro, directivas de `Policy-Engine.ps1`, servicios o adaptadores cambiaron entre un estado "A" y un estado "B".

---

## 2. Arquitectura de romanOS Snapshot & Rollback Engine

El motor se estructurará bajo un diseño híbrido de **alta velocidad y dos niveles (Tiered Snapshot Architecture)**:

```
                               ┌────────────────────────────────────────┐
                               │     romanOS Snapshot & Rollback        │
                               │      (Manage-SystemSnapshots)          │
                               └──────────────────┬─────────────────────┘
                                                  │
                    ┌─────────────────────────────┴─────────────────────────────┐
                    ▼                                                           ▼
       [Nivel 1: Atómico / Ultraligero]                           [Nivel 2: Sistema Completo]
       • Tiempo de captura: < 3 segundos                          • Tiempo de captura: ~10-20 segundos
       • Huella en disco: ~5 - 15 MB                              • Huella en disco: Depende de VSS
       • Volcado de colmenas activas:                             • Activación y llamada a VSS:
         - HKLM\SYSTEM\CurrentControlSet                            - Checkpoint-Computer (PS 5.1)
         - HKLM\SOFTWARE\Policies & Microsoft                       - WMI root\default:SystemRestore (PS 7+)
         - HKCU (Preferencias de usuario)                         • Punto de restauración completo del SO
       • Telemetría de Servicios (Get-Service JSON)
       • Telemetría de Red y Offloads NDIS
       • Hash SHA-256 y Manifest de Integridad
```

### Componentes Clave:
1. **Directorio Canónico de Almacenamiento:**
   `%SystemDrive%\romanOS-Snapshots\` (o ruta local configurable). Cada snapshot se guarda en una carpeta identificada por ID temporal: `SNAP-<yyyyMMdd-HHmmss>-<Slug>/`.
2. **Estructura del Snapshot:**
   * `manifest.json`: Metadatos del snapshot (ID, Fecha, Nombre, Descripción, Versión OS, UBR, Perfil Activo, Hashes SHA-256 de todos los artefactos).
   * `registry/`: Volcados seguros de colmenas (`reg.exe save` para subárboles críticos de directivas y servicios).
   * `state/services.json`: Snapshot de todos los servicios Win32 (Nombre, DisplayName, Status, StartType).
   * `state/network.json`: Configuración de interfaces de red, IPs, DNS, UDP RSC, RSS y estado de offloads.
   * `state/policies.json`: Evaluación canónica en vivo contra el catálogo SSOT de `Policy-Engine.ps1`.
   * `restore-script.ps1`: Script determinista auto-contenido capaz de restaurar exactamente el estado guardado sin dependencias externas.
3. **Mecanismo de Rollback:**
   * **Modo Diferencial en Caliente (Zero-Reboot):** Restaura directivas de registro, reactiva/desactiva servicios, restablece parámetros de red y reinicia `explorer.exe` sin forzar reinicio del equipo.
   * **Modo Restauración Profunda:** Si se requiere restaurar colmenas completas o el punto de VSS, orquesta la invocación de `Restore-Computer` o programa la sustitución segura de colmenas.

---

## 3. Plan de Archivos y Modificaciones

### Nuevos Archivos
1. `scripts/Modules/Manage-SystemSnapshots.ps1`
   - Script maestro del motor de instantáneas.
   - Soporte para parámetros CLI:
     - `-Action [Create|List|Restore|Remove|Export|Import]`
     - `-Name <string>`
     - `-Description <string>`
     - `-SnapshotId <string>`
     - `-IncludeVSS`
     - `-Unattended`
     - `-ExportZip <path>`
     - `-ImportZip <path>`
2. `scripts/Modules/Manage-SystemSnapshots.cmd`
   - Lanzador ergonómico Win32 para el usuario con auto-elevación UAC, `-STA` y codificación estricta ANSI/No-BOM.
3. `scripts/Testing/Test-SnapshotEngine.ps1` y `Test-SnapshotEngine.cmd`
   - Suite de pruebas unitarias automatizadas para certificar:
     - Creación de snapshot y generación de `manifest.json`.
     - Cálculo y verificación de hashes SHA-256.
     - Detección de servicios y red.
     - Operación de reversión idempotente.
     - Codificación UTF-8 con BOM y compatibilidad nativa en Windows PowerShell 5.1.

### Modificaciones en el Ecosistema Existente
1. `scripts/GUI/romanOS-ControlCenter.ps1`:
   - Integrar controles de Snapshot & Rollback en la interfaz:
     - Visualizador de instantáneas guardadas con fecha, nombre y tamaño.
     - Botón "Crear Instantánea Ahora" (con modal o diálogo rápido).
     - Botón "Revertir a Instantánea Seleccionada".
     - Botón "Exportar / Importar Respaldo".
     - Integración con el motor de streaming asíncrono a 60 FPS.
2. `scripts/Modules/romanOS-Toolkit.ps1`:
   - Añadir la opción de Snapshots al menú interactivo y CLI (`-Action Snapshot`).
   - Opción preventiva recomendada antes de aplicar perfiles de Debloat o Hardening.
3. `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`:
   - Inyección física de `Manage-SystemSnapshots.ps1` y `.cmd` en `$OEM$\$$\Setup\Scripts\Modules` y WIM offline.
4. `scripts/Testing/Invoke-TestSuite.ps1`:
   - Registrar la Fase 9 dedicada a la certificación del arnés de Snapshot & Rollback.
5. `README.md`, `docs/MANUAL_DE_USO.md` y `docs/GUIA_DE_EJECUCION_Y_COMANDOS.md`:
   - Documentar la nueva herramienta, parámetros CLI y flujos de recuperación.

---

## 4. Criterios de Aceptación y Validación

- [ ] Creación de snapshot completa en menos de 5 segundos.
- [ ] Huella de almacenamiento de snapshot ligero menor a 20 MB.
- [ ] Verificación de integridad SHA-256 certificada al 100%.
- [ ] Rollback diferencial exitoso restaurando directivas y servicios modificados.
- [ ] Codificación UTF-8 con BOM estricta en todos los `.ps1` y ANSI No-BOM en `.cmd`.
- [ ] Validación en frío en Windows PowerShell 5.1 (`powershell.exe -STA -NoProfile`).
- [ ] Cero fallos silenciosos (CWE-390): todo bloque `catch` emite telemetría visible detallada.
- [ ] 100% de pruebas aprobadas en `Test-SnapshotEngine.ps1` e integración limpia en `Invoke-TestSuite.ps1`.
