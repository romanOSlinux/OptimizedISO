# Reporte de Auditoria y Diagnostico Post-Instalacion

- **Fecha de Analisis:** 2026-09-06 18:52:57
- **Edicion:** Microsoft Windows 11 Pro for Workstations
## Resumen Ejecutivo de Instalacion

- **Estado General:** **SUCCESS WITH WARNINGS**
- **Verificaciones Aprobadas:** 15
- **Advertencias:** 2
- **Errores Criticos:** 0

- **Compilacion:** 10.0.26200.8037 (64 bits)
- **Entorno:** Maquina Virtual (Virtual Machine)
- **Procesador:** AMD Ryzen 5 8600G w/ Radeon 760M Graphics      
- **Memoria RAM:** 4 GB
- **Nombre de Equipo:** USEROPT-A5I97EH
- **Usuario Actual:** SYSTEM
- **Perfil Esperado:** Perfil 3

## 1. Almacenamiento y Huella del Sistema

- **Particion C:** 11.57 GB usados / 58.43 GB totales (19.8% ocupado, 46.85 GB libres)
- **Compresion CompactOS:** Deshabilitado (Estandar)

## 2. Auditoria de Logs Oficiales de Windows Setup

### [WARN] Windows Setup Base: Panther\setuperr.log (84 eventos)
```text
2026-09-06 18:49:49, Error                 SP         BFSVC: BfspCopyFile(F:\$WINDOWS.~BT\Sources\Boot\EFI_EX\bootmgfw_EX.efi, \\?\GLOBALROOT\Device\HarddiskVolume1\EFI\Microsoft\Boot\bootmgfw.efi) failed! (Attempt 60 of 60) Last Error = 0x3[gle=0x00000003]
2026-09-06 18:49:49, Error                 IBSLIB     BCD: Failed to add system store from file. File: \Device\HarddiskVolume1\EFI\Microsoft\Boot\BCD Status: c000000f[gle=0x00000002]
2026-09-06 18:49:49, Error                 SP         BFSVC: AddBootmgrLast and PreserveBootOrder options are ignored when custom volume is specified
2026-09-06 18:49:49, Error                 SP         BFSVC: AddBootmgrLast and PreserveBootOrder options are ignored when custom volume is specified
2026-09-06 18:49:50, Error                        Service DiagTrack is not available
2026-09-06 18:50:22, Error                            [SetupPlatform.exe] System disks found
2026-09-06 23:51:05, Error                        [setup.exe] System disks found
2026-09-06 23:51:30, Error                 SP     SPRestoreBootTimeout: Failed to read the boot manager timeout from file: C:\$WINDOWS.~BT\Sources\SetupPlatform.ini. Error: 0x80070002[gle=0x00000002]
2026-09-06 23:51:30, Error                        SppDeleteSnapshots failed. hr = 0x800401f0
2026-09-06 18:51:41, Error                 MOUPG  CSetupManager::GetWuIdFromRegistry(13254): Result = 0x80070002[gle=0x00000003]
```
- **UnattendGC\setuperr.log:** Limpio (0 errores en autounattend.xml) [OK]

## 3. Auditoria de SetupComplete.cmd y Runtimes

- **Estado de SetupComplete.cmd:** Incompleto o no finalizado [WARN]
- **Visual C++ Redistributables:** 18 paquetes detectados [OK]
- **Esquema de Energia Activo:** GUID de plan de energía: e9a42b02-d5df-448d-aa00-03f14749eb61  (Máximo rendimiento)

## 4. Estado de Tweaks, Registro y Bypasses

- **Bypass Cuenta Microsoft (BypassNRO):** Activo (1) [OK]
- **Bloqueo de OneDrive:** Activo (1) [OK]
- **Exclusion Drivers Windows Update:** Activa (1) [OK]
- **Busqueda de Drivers (Local-Only):** Activa (0) [OK]
- **Bloqueo Metadata y Apps OEM:** Activo (1) [OK]
- **Bloqueo ACPI WPBT (OEM Bloatware):** Activo (1) [OK]
- **Prevencion Cifrado BitLocker:** Activa (1 - DirectStorage/BypassIO Habilitado) [OK]
- **Menu Contextual [PSAdmin (Terminal Administrador)]:** Registrado [OK]
- **Menu Contextual [RestartExplorer (Reiniciar Explorer)]:** Registrado [OK]
- **Menu Contextual [GamerTools (Submenu Gamer en Cascada)]:** Registrado [OK]
- **Menu Contextual [SystemTools (Submenu Sistema en Cascada)]:** Registrado [OK]
- **Menu Contextual [PowerOptions (Submenu Energia/UEFI)]:** Registrado [OK]
- **Menu Contextual [TakeOwnership (Tomar Posesion)]:** Registrado [OK]
- **Menu Contextual [OpenWithNotepad (Abrir con Notepad)]:** Registrado [OK]
- **Navegadores (GPO Edge/Chrome):** Optimizado (GPU: 1, SleepingTabs: 1, Background: 0) [OK]
- **Tema Visual:** Modo Estandar / Claro (Apps: , Sistema: )

## 5. Auditoria de Paquetes AppX / UWP Aprovisionados

- **Total Paquetes Aprovisionados:** 7 paquete(s) registrados en la imagen.
- **Estado de Debloat AppX:** Limpio (0 paquetes promocionales/telemetria detectados) [OK]

## 6. Estado de Licenciamiento y Activacion

- **Producto:** Windows(R), ProfessionalWorkstation edition
- **Estado:** Notificacion (Notification) 
- **Clave Parcial:** 2YV77

## 7. Seguridad del Kernel y Virtualization-Based Security (VBS)

- **Virtualization-Based Security (VBS):** Deshabilitado (0)
- **Servicios de Seguridad Activos:** Ninguno (Maximo rendimiento)

## 8. Estado de Servicios de Rendimiento

- **Servicio DiagTrack:** Estado: Running | Inicio: Disabled
- **Servicio dmwappushservice:** Estado: Stopped | Inicio: Disabled
- **Servicio WerSvc:** Estado: Stopped | Inicio: Disabled
- **Servicio TroubleshootingSvc:** Estado: Stopped | Inicio: Disabled
- **Servicio BDESVC:** Estado: Stopped | Inicio: Disabled
- **Servicio Fax:** No instalado en esta edicion.
- **Servicio SCardSvr:** Estado: Stopped | Inicio: Disabled
- **Servicio RemoteRegistry:** Estado: Stopped | Inicio: Disabled
- **Servicio RetailDemo:** Estado: Stopped | Inicio: Disabled
- **Servicio MapsBroker:** Estado: Stopped | Inicio: Disabled
- **Servicio lfsvc:** Estado: Running | Inicio: Disabled
- **Servicio WSearch:** Estado: Running | Inicio: Disabled
- **Servicio Spooler:** Estado: Running | Inicio: Disabled
- **Servicio WlanSvc:** Estado: Stopped | Inicio: Disabled
- **Servicio bthserv:** Estado: Stopped | Inicio: Disabled
- **Servicio SensorService:** Estado: Stopped | Inicio: Disabled
- **Servicio SysMain:** Estado: Running | Inicio: Disabled

## 9. Auditoria de Hardware y Controladores (PnP)

- **Estado de Dispositivos:** Todos los dispositivos PnP inicializados correctamente (0 errores) [OK]