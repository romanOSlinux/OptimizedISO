# PLAN-0043: Modernización del Motor de Inteligencia de Hardware (Soporte AI PC, NPU e iGPUs de Nueva Generación)

**Fecha:** 2026-09-06  
**Autor:** romanOS / OptimizedISO Project Team  
**Estado:** COMPLETADO  
**Rama:** `feature/offline-ui-tweaks`  

---

## 1. Objetivo y Respaldo Técnico
El objetivo de este plan es actualizar la heurística de detección de hardware en `Win11-Debloat-v3-Adaptive.ps1` para que sea capaz de lidiar con arquitecturas "AI PC" modernas sin romper sus funcionalidades base, y para que habilite optimizaciones gaming de baja latencia en APUs potentes de última generación (AMD RDNA3 / RDNA3.5 e Intel Arc).

### Documentación Técnica y Control Funcional
Las modificaciones propuestas no son experimentales; se respaldan en los siguientes estándares de la industria y documentación de Microsoft (MS-Docs):

1. **Detección de NPU (Neural Processing Unit)**:
   - **Estándar Microsoft (PnP Device Class)**: Microsoft clasifica a los procesadores neuronales (NPU) bajo la clase `ComputeAccelerator` y dispositivos híbridos bajo `SoftwareComponent` o `System`. (Fuente: *Windows AI / Windows Studio Effects architecture*).
   - **Implementación segura**: Usaremos `Get-PnpDevice -Class ComputeAccelerator` o un filtro cruzado en `FriendlyName` (`*NPU*`, `*IPU*`, `*Neural*`) para garantizar la detección de chips AMD XDNA (Ryzen AI) e Intel NPU (Core Ultra).
   - **Control Funcional**: Si se detecta una NPU, el script bloqueará internamente la desactivación de servicios críticos asociados a la Inteligencia Artificial de Windows, previniendo la rotura de características aceleradas por hardware del cliente.

2. **Detección de iGPUs Modernas (RDNA3 e Intel Arc)**:
   - **El Problema Actual**: La heurística legacy solo buscaba `AMD Radeon [RX]` o `NVIDIA`.
   - **Estándar de Nomenclatura OEM**: Las APUs de AMD de las series 7040 y 8000G utilizan nomenclatura numérica con sufijo 'M' (ej. Radeon 760M, 780M, 890M).
   - **Implementación segura**: Se actualizará la expresión regular a `'NVIDIA|AMD Radeon (RX|[6-8][0-9]{2}M)|Intel Arc'`.
   - **Control Funcional**: Esto permitirá que el script aplique correctamente los *Gaming Optimizations* (Sección 12), como el *Hardware-Accelerated GPU Scheduling (HAGS)* y el *MSI Mode* en los registros de interrupción (`Message Signaled Interrupts`), lo cual reduce drásticamente la latencia DPC según la documentación del driver WDDM de Microsoft.

## 2. Acciones Propuestas (Código)

### [MODIFY] Win11-Debloat-v3-Adaptive.ps1
- **Sección Pre-flight (Detección de GPU)**: Actualizar la expresión regular en la iteración de `Win32_VideoController`.
- **Sección Pre-flight (Detección de NPU)**: Inyectar el bloque de consulta a `Get-PnpDevice` para buscar hardware con `FriendlyName -match 'NPU|Neural|IPU|AI'` o `Class -eq 'ComputeAccelerator'`.
- **Dashboard de Hardware**: Agregar un campo en la tabla visual (`| NPU       : [Detectada / Ausente] |`) y un aviso de advertencia si la NPU está presente.
