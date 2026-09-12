# PLAN-0079: Auditor Universal de Optimización del Sistema (Multi-Hardware, Heurística Oficial y Observabilidad)

**Fecha:** 2026-09-11  
**Estado:** COMPLETADO  
**Autor:** Antigravity / romanOS Core Team  
**Área:** Diagnóstico Forense, Observabilidad de Hardware y Optimización de Sistema  

---

## 1. Contexto y Justificación
Actualmente, las herramientas de diagnóstico existentes en el proyecto (`PostInstall-Diagnostics.ps1`, `Audit-FreshInstallFootprint.ps1`) están acopladas al flujo de post-instalación de imágenes ISO personalizadas de romanOS (buscando logs de Windows Setup, Panther, UnattendGC y rutas fijas de `$OEM$`).

No existe una herramienta **autónoma, universal y portátil** que un usuario pueda ejecutar en **cualquier equipo con Windows 10 u 11** (sea un equipo recién instalado, una máquina en producción, una laptop con batería, un desktop con Intel Core híbrido, un procesador AMD Ryzen, GPUs dedicadas NVIDIA/AMD o gráficos integrados) para auditar de forma objetiva, empírica y respaldada por fuentes oficiales si el sistema está verdaderamente optimizado.

El objetivo de este plan es crear el script **`Audit-SystemOptimization.ps1`** y su lanzador **`Auditar-Optimizacion-PC.cmd`**: una solución de observabilidad forense capaz de operar con o sin privilegios de administrador, diagnosticando cuellos de botella, calculando un Score de Optimización (0-100%) y generando comandos de remediación instantáneos listos para copiar y pegar.

---

## 2. Requerimientos Técnicos y Arquitectura

### 2.1. Portabilidad y Zero-Dependency
* El script aprovechará las capacidades de `scripts/Core/UI-Engine.ps1`, `scripts/Core/Hardware-Engine.ps1` y `scripts/Core/Policy-Engine.ps1` cuando se encuentre dentro del repositorio de romanOS.
* Si el archivo se copia y ejecuta de manera aislada en una máquina externa sin los motores Core, incluirá micro-rutinas de respaldo autónomas (*fallbacks*) para UI, detección de hardware y evaluación de políticas sin colapsar.

### 2.2. Manejo Dual de Privilegios (Usuario Estándar vs. Administrador)
* **Detección Automática:** Evalúa el token de seguridad del proceso (`WindowsPrincipal.IsInRole([WindowsBuiltInRole]::Administrator)`).
* **Modo Usuario Estándar (Medium Integrity Level):** Audita todas las áreas legibles (CPU, GPU, plan de energía, directivas de registro HKLM/HKCU públicas, adaptadores de red, servicios, paquetes UWP y resolución de temporizador). Las llamadas protegidas que arrojen error de denegación de acceso no lanzan excepciones en consola, sino que se catalogan ordenadamente bajo la sección `[REQUIERE ELEVACIÓN]`.
* **Modo Administrador (High Integrity Level):** Habilita la auditoría de bajo nivel de BCD (`bcdedit`), BypassIO / DirectStorage (`fsutil bypassio`), estado interno del gestor de memoria (`Get-MMAgent`) y políticas de seguridad del kernel.
* **Lanzador Interactivo (`Auditar-Optimizacion-PC.cmd`):** Consulta al usuario si desea elevar privilegios mediante UAC con un solo clic o continuar en modo estándar.

### 2.3. Matriz Heurística Multi-Hardware
1. **Chasis:** Laptop con batería (`Win32_Battery`) vs. Desktop vs. Máquina Virtual.
   * *Ajuste heurístico:* En laptops no se exige 100% de CPU constante en batería para evitar drenaje y *thermal throttling*.
2. **CPU:** AMD Ryzen (Zen 2-5) vs. Intel Core (10ª a 14ª Gen / Core Ultra híbrido P/E Cores).
   * *Ajuste heurístico:* Valida que en Intel híbrido no se rompa la asignación de *Thread Director*.
3. **GPU:** NVIDIA GeForce vs. AMD Radeon vs. Intel Arc vs. Gráficos integrados (APU/iGPU).
   * *Ajuste heurístico:* Valida compatibilidad de HAGS (WDDM 2.7+) y activación de MSI Mode en el bus PCI Express.
4. **Almacenamiento:** NVMe PCIe (Gen3/4/5) vs. SSD SATA vs. HDD mecánico.
   * *Ajuste heurístico:* `SysMain` (Superfetch) solo se califica como cuello de botella si el disco principal es SSD/NVMe; en HDD mecánico se considera aceptable.
5. **Red:** Controladoras Realtek (2.5GbE / Gigabit), Intel (I219/I225/I226), Wi-Fi 6/6E/7.
   * *Ajuste heurístico:* Detección y recomendación de desactivación de *Green Ethernet* (IEEE 802.3az) y *Power Saving Mode* para eliminar variabilidad en ping.

---

## 3. Dominios de Auditoría y Fuentes Oficiales

| Dominio | Directiva Auditada | Fuente Oficial | Beneficio Técnico Comprobado |
| :--- | :--- | :--- | :--- |
| **CPU & Energía** | Plan de Energía, Throttle Mín/Máx | *Microsoft Power & Performance Tuning Docs* | Frecuencia de respuesta instantánea y mitigación de estados C-States lentos en CA. |
| **GPU / WDDM** | **HAGS** (`HwSchMode = 2`) | *Microsoft Learn: Hardware Accelerated GPU Scheduling* | Planificación de memoria gráfica por hardware; reducción del overhead de CPU. |
| **Interrupciones** | **MSI Mode** en GPU y NIC | *Microsoft Hardware Dev Center: PCI MSI/MSI-X* | Interrupciones por mensaje que eliminan conflictos de líneas IRQ compartidas. |
| **DirectX / Latencia** | Flip Model & VRR en Ventana | *DirectX Developer Blog: Advanced Gaming Optimizations* | Baja la latencia de juegos en modo ventana al nivel de pantalla completa exclusiva. |
| **Memoria** | **DisablePagingExecutive** | *Microsoft Windows Internals (Russinovich et al.)* | En PCs con >= 16 GB RAM, mantiene el kernel y drivers residentes en RAM física. |
| **Paginación** | `pagefile.sys` Fijo vs. Dinámico | *Microsoft Support KB / Performance Tuning Guidelines* | Previene la fragmentación del archivo de paginación y pausas de I/O en SSD. |
| **Almacenamiento** | **TRIM** y **DisableLastAccess** | *Microsoft Learn: fsutil behavior command reference* | Ahorra ciclos de escritura de timestamps y mantiene la salud de celdas NAND. |
| **Pila TCP** | **TCP ECN** (RFC 3168) | *IETF RFC 3168 / Microsoft Networking Blog* | Notificación de congestión activa sin retransmisiones ni pérdidas de paquetes. |
| **Latencia Red** | **Nagle's Algorithm** | *IETF RFC 896 / RFC 1122* | Deshabilita la espera de 200 ms (`TcpAckFrequency = 1`, `TCPNoDelay = 1`) en juegos. |
| **Controlador NIC** | **Green Ethernet / EEE** | *IEEE 802.3az Specification / Realtek Driver Guides* | Desactiva el modo de reposo del transceptor de red, eliminando micro-pausas. |
| **Seguridad Kernel** | **HVCI (Memory Integrity)** | *Microsoft Support KB5022830: Optimize gaming performance* | 5% a 11% de recuperación de FPS al desactivar el hipervisor en gaming. |
| **Servicios & Bloat** | Telemetría, DiagTrack, UWP Bloat | *Microsoft Documentation: Managing Windows Services* | Reduce el consumo de RAM en reposo y ciclos de CPU en segundo plano. |

---

## 4. Archivos Afectados y Estructura de Cambios

### 4.1. Archivos Nuevos
* `scripts/Modules/Audit-SystemOptimization.ps1` (Script principal de auditoría, UTF-8 con BOM).
* `scripts/Auditar-Optimizacion-PC.cmd` (Lanzador interactivo rápido, ANSI / No-BOM).

### 4.2. Archivos a Modificar
* `scripts/Modules/romanOS-Toolkit.ps1` (Integración de la opción en el menú principal).
* `docs/plans/README.md` (Registro del plan en el índice oficial).

---

## 5. Plan de Pruebas y Criterios de Aceptación
1. **Validación AST en Windows PowerShell 5.1:**
   `& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'scripts\Modules\Audit-SystemOptimization.ps1' -WhatIf }"`
   Debe retornar 0 errores de sintaxis o codificación.
2. **Prueba de Modo Estándar:** Ejecutar sin privilegios de administrador; el script debe completar al 100% y catalogar las llamadas restringidas en la sección `[REQUIERE ELEVACIÓN]`.
3. **Prueba de Modo Administrador:** Ejecutar con privilegios elevados; todas las llamadas de bajo nivel (`bcdedit`, `fsutil bypassio`, `Get-MMAgent`) deben evaluarse exitosamente.
4. **Verificación de Salida:** Comprobar la correcta visualización del Score (0-100%), el semáforo de colores ANSI y la generación del bloque de comandos de remediación.
