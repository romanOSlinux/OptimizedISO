# PLAN-0016: Expansión de Optimizaciones Oficiales de Hardware en Win11-Debloat-v3-Adaptive

- **Número:** PLAN-0016
- **Fecha:** 2026-08-31
- **Título:** Expansión de Optimizaciones Oficiales de Hardware (PCIe ASPM, DirectStorage Check, NDIS/NIC Tuning, Core Unparking, MMCSS Pro Audio y Switch MPO) en Win11-Debloat-v3-Adaptive.ps1
- **Estado:** COMPLETADO
- **Autor:** romanOS Dev Team / Antigravity AI

---

## 1. Contexto y Justificación

Tras auditar las capacidades nativas del kernel de Windows 11 (24H2/25H2) y las fuentes oficiales de Microsoft (*Windows Hardware Dev Center, WDDM, NDIS, DirectStorage/BypassIO y Processor Power Management*), se identificaron varias áreas de rendimiento que pueden optimizarse de forma adaptativa y segura:

1. **Almacenamiento / PCIe:** En equipos de escritorio con corriente alterna (AC), el ahorro de energía *PCIe Link State Power Management (ASPM)* provoca micro-congelamientos (*hitching*) de 10 a 50 ms al reactivar enlaces de datos en SSDs NVMe y GPUs.
2. **Diagnóstico DirectStorage:** Los usuarios necesitan conocer si su NVMe y controladores de filtro soportan *BypassIO* para el streaming directo de texturas a VRAM sin sobrecarga de CPU.
3. **Red (NIC):** Los adaptadores de red físicos se benefician de *Receive Side Scaling (RSS)* para repartir el procesamiento de paquetes entre núcleos de CPU, y de desactivar *Energy Efficient Ethernet (EEE)* para prevenir micro-suspensiones del transceptor.
4. **CPU / Planificador:** Las CPUs monolíticas de escritorio se benefician de evitar la latencia de *Core Parking* (`CPMinCores = 100`), excluyendo explícitamente procesadores móviles y arquitecturas multi-CCD con 3D V-Cache (donde el aparcamiento de núcleos es necesario para AMD).
5. **Audio de Baja Latencia:** Ajustar el servicio *MMCSS* para tareas de *Pro Audio* previene chasquidos y pérdida de paquetes de audio cuando el sistema opera bajo carga pesada.
6. **Pantalla / DWM:** Proveer un interruptor seguro para *Multi-Plane Overlay (MPO)* resuelve problemas conocidos de parpadeo de pantalla en escritorios multi-monitor.

---

## 2. Objetivos Específicos

- [x] Incorporar diagnóstico de DirectStorage / BypassIO en el Dashboard pre-flight (`fsutil bypassIO state C:\`).
- [x] Configurar desactivación automática de *PCIe ASPM* en PCs de escritorio (`SUB_PCIEXPRESS -> 0`).
- [x] Implementar afinamiento inteligente de *Core Unparking* para CPUs monolíticas de escritorio.
- [x] Integrar afinamiento de adaptador físico NDIS (*RSS*, desactivación de *Energy Efficient Ethernet*).
- [x] Fortalecer prioridades de audio en tiempo real en *MMCSS* (`Pro Audio`).
- [x] Agregar opción interactiva de diagnóstico y control de *Multi-Plane Overlay (MPO)*.
- [x] Validar compatibilidad total y sintaxis en Windows PowerShell 5.1 con codificación estricta UTF-8 con BOM.

---

## 3. Matriz de Cambios Técnicos

| Optimización | Subsistema | Clave / Comando | Condición de Aplicación |
| :--- | :--- | :--- | :--- |
| **DirectStorage Check** | Almacenamiento | `fsutil bypassIO state C:\` | Informativo si $isNVMe = $true |
| **PCIe ASPM Off** | Bus PCIe / NVMe | `powercfg /setacvalueindex ... SUB_PCIEXPRESS ... 0` | Solo Desktop (No laptop) |
| **Core Unparking** | CPU / PPM | `powercfg /setacvalueindex ... SUB_PROCESSOR CPMINCORES 100` | Solo Desktop, no Low-End, no multi-CCD X3D |
| **NDIS RSS / EEE Off** | Red Física | `Enable-NetAdapterRss`, `Set-NetAdapterAdvancedProperty` | Adaptador físico activo |
| **MMCSS Pro Audio** | Audio / Kernel | `HKLM\...\Multimedia\SystemProfile\Tasks\Pro Audio` | Todas las configuraciones |
| **MPO Switch** | DWM / Pantalla | `HKLM\SOFTWARE\Microsoft\Windows\Dwm\OverlayTestMode` | Menú interactivo (Troubleshooting) |

---

## 4. Plan de Verificación

1. **Test-ScriptAstAndBom.ps1:** Comprobación de que `Win11-Debloat-v3-Adaptive.ps1` mantiene BOM UTF-8 y no tiene errores de sintaxis en PS 5.1.
2. **Cold Run de PowerShell 5.1:** Ejecución con `-WhatIf` contra `powershell.exe` nativo de System32.
3. **Test-GitWorkspaceHygiene.ps1:** Verificación de limpieza del árbol de trabajo de Git.
