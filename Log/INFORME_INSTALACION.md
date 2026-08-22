# Reporte de Auditoria y Diagnostico Post-Instalacion

- **Fecha de Analisis:** 2026-08-22 12:39:04
- **Edicion:** Microsoft Windows 11 Pro for Workstations
## Resumen Ejecutivo de Instalacion

- **Estado General:** **SUCCESS WITH WARNINGS**
- **Verificaciones Aprobadas:** 13
- **Advertencias:** 1
- **Errores Criticos:** 0

- **Compilacion:** 10.0.26200.8037 (64 bits)
- **Entorno:** Maquina Virtual (Virtual Machine)
- **Procesador:** AMD Ryzen 5 5600X 6-Core Processor             
- **Memoria RAM:** 4 GB
- **Nombre de Equipo:** USEROPT-CL5D2U8
- **Usuario Actual:** Roman
- **Perfil Esperado:** Perfil 3

## 1. Almacenamiento y Huella del Sistema

- **Particion C:** 17.61 GB usados / 58.43 GB totales (30.1% ocupado, 40.81 GB libres)
- **Compresion CompactOS:** Deshabilitado (Estandar)

## 2. Auditoria de Logs Oficiales de Windows Setup

### [WARN] Windows Setup Base: Panther\setuperr.log (84 eventos)
```text
2026-08-22 12:30:33, Error                 SP         BFSVC: BfspCopyFile(F:\$WINDOWS.~BT\Sources\Boot\EFI_EX\bootmgfw_EX.efi, \\?\GLOBALROOT\Device\HarddiskVolume1\EFI\Microsoft\Boot\bootmgfw.efi) failed! (Attempt 60 of 60) Last Error = 0x3[gle=0x00000003]
2026-08-22 12:30:34, Error                 IBSLIB     BCD: Failed to add system store from file. File: \Device\HarddiskVolume1\EFI\Microsoft\Boot\BCD Status: c000000f[gle=0x00000002]
2026-08-22 12:30:34, Error                 SP         BFSVC: AddBootmgrLast and PreserveBootOrder options are ignored when custom volume is specified
2026-08-22 12:30:34, Error                 SP         BFSVC: AddBootmgrLast and PreserveBootOrder options are ignored when custom volume is specified
2026-08-22 12:30:35, Error                        Service DiagTrack is not available
2026-08-22 12:31:07, Error                            [SetupPlatform.exe] System disks found
2026-08-22 17:31:51, Error                        [setup.exe] System disks found
2026-08-22 17:32:10, Error                 SP     SPRestoreBootTimeout: Failed to read the boot manager timeout from file: C:\$WINDOWS.~BT\Sources\SetupPlatform.ini. Error: 0x80070002[gle=0x00000002]
2026-08-22 17:32:10, Error                        SppDeleteSnapshots failed. hr = 0x800401f0
2026-08-22 12:32:23, Error                 MOUPG  CSetupManager::GetWuIdFromRegistry(13254): Result = 0x80070002[gle=0x00000003]
```
- **UnattendGC\setuperr.log:** Limpio (0 errores en autounattend.xml) [OK]

## 3. Auditoria de SetupComplete.cmd y Runtimes

- **Estado de SetupComplete.cmd:** Finalizado Exitosamente [OK]
- **Visual C++ Redistributables:** No se detectaron paquetes VC++ instalados.
- **Esquema de Energia Activo:** GUID de plan de energía: e9a42b02-d5df-448d-aa00-03f14749eb61  (Máximo rendimiento)

## 4. Estado de Tweaks, Registro y Bypasses

- **Bypass Cuenta Microsoft (BypassNRO):** Activo (1) [OK]
- **Bloqueo de OneDrive:** Activo (1) [OK]
- **Exclusion Drivers Windows Update:** Activa (1) [OK]
- **Busqueda de Drivers (Local-Only):** Activa (0) [OK]
- **Bloqueo Metadata y Apps OEM:** Activo (1) [OK]
- **Bloqueo ACPI WPBT (OEM Bloatware):** Activo (1) [OK]
- **Tema Visual:** Modo Oscuro Activo (Apps: 0, Sistema: 0) [OK]

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

- **Servicio DiagTrack:** Estado: Stopped | Inicio: Disabled
- **Servicio dmwappushservice:** Estado: Stopped | Inicio: Disabled
- **Servicio WSearch:** Estado: Stopped | Inicio: Disabled
- **Servicio Spooler:** Estado: Stopped | Inicio: Disabled
- **Servicio WlanSvc:** Estado: Stopped | Inicio: Disabled
- **Servicio bthserv:** Estado: Stopped | Inicio: Disabled
- **Servicio SysMain:** Estado: Stopped | Inicio: Disabled

## 9. Auditoria de Hardware y Controladores (PnP)

- **Estado de Dispositivos:** Todos los dispositivos PnP inicializados correctamente (0 errores) [OK]
