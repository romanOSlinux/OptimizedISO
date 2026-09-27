# PLAN-0130: Auditoría y Validación en Vivo del Lote 4 - GUIs WPF, Lanzadores y Controladores

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0130 |
| **Fecha** | 2026-09-27 |
| **Componentes** | `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/GUI/romanOS-Toolkit.ps1`, `scripts/GUI/romanOS-Studio.ps1`, `scripts/Modules/Clean-DriverStore.ps1`, `scripts/Drivers/Get-CriticalDrivers.ps1` |
| **Estado** | `PENDIENTE` |
| **Prioridad** | Alta (Experiencia de Usuario, Estabilidad de Hilo STA y Gestión de Controladores) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (STA Threading / UTF-8 BOM), Regla 7 (Anti-Bloqueo de Consola), Regla 13 (CWE-390), Regla 15 (Map-Reduce Lote 4) |

---

## 1. Visión y Justificación Técnica

Las interfaces gráficas y herramientas interactivas conectan al usuario con el ecosistema romanOS:
- [`romanOS-ControlCenter.ps1`](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter.ps1): Centro de control WPF en modo oscuro integral con enlace de eventos, pestañas de telemetría, generador desatendido y despacho seguro de botones.
- [`romanOS-Toolkit.ps1`](file:///c:/OptimizedISO/scripts/GUI/romanOS-Toolkit.ps1): Menú CLI maestro con 24 opciones interactivas y soporte de tubería no interactiva.
- [`romanOS-Studio.ps1`](file:///c:/OptimizedISO/scripts/GUI/romanOS-Studio.ps1): GUI de compilación de ISOs y orquestación de máquinas virtuales de prueba.
- [`Clean-DriverStore.ps1`](file:///c:/OptimizedISO/scripts/Modules/Clean-DriverStore.ps1): Mantenimiento seguro del DriverStore mediante `pnputil.exe` sin eliminar dispositivos activos.
- [`Get-CriticalDrivers.ps1`](file:///c:/OptimizedISO/scripts/Drivers/Get-CriticalDrivers.ps1): Descarga y validación de paquetes de almacenamiento críticos (Intel VMD/RST y Red Hat VirtIO).

### Respaldo de Fuentes Oficiales
- **Microsoft Learn:** *WPF Threading Model & Single-Threaded Apartment (STA) Dispatcher.*
- **Microsoft Learn:** *XAML Reader & WPF Logical/Visual Tree Instantiation.*
- **Microsoft Learn:** *PnPUtil Command-Line Syntax & DriverStore Management.*

---

## 2. Fases de Implementación

- [ ] **Fase 1: Auditoría Estática AST y BOM (Regla 4):**
  - Comprobar que los scripts `.ps1` posean UTF-8 BOM y los lanzadores `.cmd` sean No-BOM con el switch `-STA` explícito.
- [ ] **Fase 2: Compilación Headless del Árbol XAML en STA:**
  - Ejecutar `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & '.\scripts\GUI\romanOS-ControlCenter.ps1' -SkipElevation -WhatIf }"` y verificar enlace de controles sin excepciones.
  - Ejecutar `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & '.\scripts\GUI\romanOS-Studio.ps1' -SkipElevation -WhatIf }"`.
- [ ] **Fase 3: Soporte No-Interactivo y Pipeline en romanOS-Toolkit:**
  - Enviar entrada por pipeline `echo "0"` a `romanOS-Toolkit.ps1 -SkipElevation -WhatIf` validando que finalice limpiamente sin colgar la consola.
- [ ] **Fase 4: Verificación de Limpieza de DriverStore y Descarga de Drivers:**
  - Probar `Clean-DriverStore.ps1 -WhatIf -SkipElevation` validando que identifique los 83+ controladores activos del host sin mutar el almacén OEM.
  - Probar `Get-CriticalDrivers.ps1 -WhatIf -PassThru` validando resolución de paquetes Intel VMD y VirtIO.
- [ ] **Fase 5: Certificación y Reporte de Métricas del Lote 4:**
  - Actualizar estado a `COMPLETADO`.
