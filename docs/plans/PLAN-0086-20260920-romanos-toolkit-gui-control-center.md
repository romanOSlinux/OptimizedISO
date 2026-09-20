# PLAN-0086: romanOS Control Center: Interfaz Gráfica Nativa (WPF / XAML) para el Hub Maestro y Ecosistema de Herramientas

**Fecha:** 2026-09-20  
**Estado:** PENDIENTE  
**Autor:** romanOS Engineering / Antigravity  

---

## 1. Contexto y Justificación Técnica

Actualmente, [romanOS-Toolkit.ps1](file:///c:/OptimizedISO/scripts/Modules/romanOS-Toolkit.ps1) opera mediante una interfaz de texto en consola (TUI / CLI). Aunque es rápida, funcional y de huella nula (*zero-resident footprint*), el usuario requiere una **experiencia gráfica moderna, fluida y visualmente unificada** con [romanOS Studio](file:///c:/OptimizedISO/scripts/GUI/romanOS-Studio.ps1).

### Objetivos de Diseño y Ergonomía:
1. **Paridad de Identidad Visual:** Mismo lenguaje de diseño Dark Mode (`#202020` / `#282828` con acentos Neón `#00E5FF` y `#00E676`), tarjetas modulares y tipografía oficial `Segoe UI Variable`.
2. **Plataforma Nativa de Alto Rendimiento:** WPF XAML alojado en PowerShell 5.1 (`-STA`) sin runtime pesados (Node, Electron o WebView2 como base), garantizando bajo consumo de RAM (<40 MB activo, 0 MB en reposo).
3. **Lanzador Win32 GUI JIT (Zero Console Flash):** Compilación nativa al instante mediante `csc.exe` (`IMAGE_SUBSYSTEM_WINDOWS_GUI`, 0x0002) para ejecutar la interfaz gráfica con **cero parpadeo de ventana de consola**.
4. **Ejecución Asíncrona sin Congelamiento (60 FPS):** Empleo del motor asíncrono probado en romanOS Studio (`RunspaceFactory` + `ConcurrentQueue[string]` + `DispatcherTimer`), permitiendo que tareas intensivas (DISM, SFC, vaciado DNS, debloat) muestren streaming en vivo en una terminal embebida sin colgar la interfaz.
5. **Reutilización Canónica (SSOT):** Consumo directo de los motores [Hardware-Engine.ps1](file:///c:/OptimizedISO/scripts/Core/Hardware-Engine.ps1), [Policy-Engine.ps1](file:///c:/OptimizedISO/scripts/Core/Policy-Engine.ps1) y [UI-Engine.ps1](file:///c:/OptimizedISO/scripts/Core/UI-Engine.ps1).

---

## 2. Arquitectura de la Interfaz Gráfica (`romanOS Control Center`)

La aplicación (`scripts/GUI/romanOS-ControlCenter.ps1`) se estructura en un `TabControl` de **6 pestañas funcionales** más una consola de telemetría inferior:

### 📑 Pestaña 1: Dashboard & Telemetría en Tiempo Real
* **Widget de Hardware en Vivo:** Tarjeta conectada a `Get-SystemHardwareProfile` mostrando CPU, número de núcleos/hilos, memoria RAM instalada/en uso, tipo de almacenamiento (NVMe/SSD) y adaptadores gráficos activos.
* **Badges de Estado de Optimización:**
  * Estado de **HAGS** (Hardware-Accelerated GPU Scheduling).
  * Estado de **Modo MSI / MSI-X** en adaptadores gráficos PCI-SIG.
  * Estado de **Hipervisor / VBS** (Ring 0 Latencia Mínima vs. Virtualización Activa).
  * Estado de **Poda de Memoria RAM** (Working Set actual de procesos clave).
* **Acciones Express de 1 Clic:**
  * ⚡ *Podar Memoria RAM en Reposo* (`Optimize-ProcessMemory.ps1`).
  * 🔄 *Reiniciar Explorador de Windows* (`Stop-Process -Name explorer`).
  * 🛠️ *Abrir God Mode Maestro*.

### 🎮 Pestaña 2: Gaming & Conmutador Bimodal (Switch Game/Dev)
* **Selector Visual de Modo de Recursos:**
  * 🕹️ **Modo Juego Agresivo:** Poda profunda de RAM para APU Radeon, suspensión de Hyper-V/WSL2/Docker y corte de devoradores.
  * 🎮 **Modo Juego Ligero:** Optimización para gaming sin desconectar servicios de desarrollo.
  * 💻 **Modo Dev / Trabajo:** Restauración instantánea de virtualización, contenedores y servicios del sistema.
* **Ajustes de Latencia Gráfica y Sistema:**
  * Toggle directo de **Hipervisor BCDEDIT** (`hypervisorlaunchtype off / auto`).
  * Lanzamiento del optimizador adaptativo [Win11-Debloat-v3-Adaptive.ps1](file:///c:/OptimizedISO/scripts/Modules/Win11-Debloat-v3-Adaptive.ps1).

### 🧹 Pestaña 3: Mantenimiento & Saneamiento Profundo
* **Matriz de Tareas de Mantenimiento:**
  * Limpieza profunda de **WinSxS con DISM** (`/StartComponentCleanup /ResetBase`).
  * Purga de **Caché de Shaders GPU** (DirectX, NVIDIA, AMD Radeon Cache).
  * Ejecución de **SSD TRIM** en todas las unidades NVMe/SATA detectadas.
  * Comprobación y reparación de archivos de sistema (**DISM RestoreHealth + SFC Scannow**).
* Botón de ejecución individual o por lote con barra de progreso.

### 🌐 Pestaña 4: Red & Benchmarks de Latencia
* **Benchmark DNS Interactivo:** Medición en vivo contra Cloudflare (1.1.1.1), Google (8.8.8.8), Quad9 (9.9.9.9) y OpenDNS.
* **Resultados en Tabla Dinámica:** Codificación por colores según latencia (<15 ms Verde, <40 ms Amarillo, >40 ms Rojo).
* **Asignación en 1 Clic:** Configura el DNS más rápido en el adaptador de red principal.
* **Tweaks TCP/IP:** Vaciar caché DNS (`ipconfig /flushdns`), restablecer catálogo Winsock y optimizar parámetros TCP/IP.

### 🛡️ Pestaña 5: Seguridad, Hardening & Navegadores
* **Auditoría de Seguridad Desacoplada:** Postura de reglas ASR, LSA Protection y VBS/HVCI.
* **Optimizador Oficial de Navegadores:** Checkboxes para Edge, Chrome, Firefox y Brave (aceleración GPU, Sleeping Tabs, desactivación de telemetría y Copilot IA).
* **Visualizador de Dashboards HTML:** Apertura directa de `INFORME_INSTALACION.html` e `INFORME_SEGURIDAD.html`.

### 💻 Pestaña 6: Drivers & Herramientas Avanzadas
* **Ecosistema de Controladores:**
  * Respaldo automático de controladores del host (`Export-WindowsDriver`) a `Drivers/`.
  * Limpieza del DriverStore (`pnputil /delete-driver`) para recuperar espacio.
* **Migración de Usuario:** Asistente visual para `Migrar-Usuario-W11.ps1`.

---

### 🖥️ Consola de Streaming y Barra de Estado Inferior
* **Terminal Embebida:** Caja de texto oscura con `Consolas` y scroll automático para streaming de logs en tiempo real.
* **Barra de Progreso y Estado:** Indicador visual de tarea activa, tiempo transcurrido y errores.
* **Botón de Cancelación Segura:** Aborto limpio del subproceso en segundo plano sin colapsar el sistema.

---

## 3. Plan de Cambios Detallado

### Componente 1: Aplicación Gráfica WPF
* **[NUEVO] [scripts/GUI/romanOS-ControlCenter.ps1](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter.ps1):**
  * Script maestro de la interfaz WPF en PowerShell 5.1 con codificación **UTF-8 con BOM**.
  * Auto-elevación UAC con ventana de diálogo nativa.
  * Carga e integración con `Hardware-Engine.ps1` y `Policy-Engine.ps1`.
  * Definición XAML completa de la ventana, pestañas, tarjetas y consola.
  * Motor de ejecución asíncrona mediante `RunspaceFactory` y `DispatcherTimer`.

### Componente 2: Lanzador Win32 JIT y Batch Raíz
* **[NUEVO] `scripts/GUI/romanOS-ControlCenter-Launcher.cs`:**
  * Código fuente C# compilable a `Lanzar-romanOS-ControlCenter.exe` con Subsystem 2 (`IMAGE_SUBSYSTEM_WINDOWS_GUI`) y `CREATE_NO_WINDOW` para cero parpadeo de consola.
* **[NUEVO] [Lanzar-romanOS-ControlCenter.cmd](file:///c:/OptimizedISO/Lanzar-romanOS-ControlCenter.cmd):**
  * Lanzador por lotes en la raíz del repositorio con auto-elevación UAC, auto-compilación JIT vía `csc.exe` y codificación **UTF-8 No-BOM / ANSI** (Regla 4).

### Componente 3: Integración Ecosistémica y Toolkit CLI
* **[MODIFICAR] [scripts/Modules/romanOS-Toolkit.ps1](file:///c:/OptimizedISO/scripts/Modules/romanOS-Toolkit.ps1):**
  * Agregar parámetro `-GUI` / `-ControlCenter` para abrir la interfaz gráfica desde el CLI.
  * Agregar opción en el menú interactivo para lanzar `romanOS Control Center`.
* **[MODIFICAR] [scripts/Builder/New-OptimizedWindowsISO-v2.ps1](file:///c:/OptimizedISO/scripts/Builder/New-OptimizedWindowsISO-v2.ps1):**
  * Inyectar `romanOS-ControlCenter.ps1`, `romanOS-ControlCenter-Launcher.cs` y su lanzador en `$OEM$` y WIM montado.
  * Crear acceso directo en el Menú Inicio (`romanOS Control Center.lnk`).

### Componente 4: Documentación y Cascada Ecosistémica
* **[MODIFICAR] [docs/MANUAL_DE_USO.md](file:///c:/OptimizedISO/docs/MANUAL_DE_USO.md):** Documentar la nueva GUI, atajos y casos de uso.
* **[MODIFICAR] [docs/GUIA_DE_EJECUCION_Y_COMANDOS.md](file:///c:/OptimizedISO/docs/GUIA_DE_EJECUCION_Y_COMANDOS.md):** Actualizar tabla de herramientas y comandos.
* **[MODIFICAR] [README.md](file:///c:/OptimizedISO/README.md):** Registrar el nuevo lanzador gráfico en la raíz.

### Componente 5: Arnés de Pruebas Unitarias
* **[MODIFICAR] [scripts/Testing/Test-OptimizedISO-v2.ps1](file:///c:/OptimizedISO/scripts/Testing/Test-OptimizedISO-v2.ps1):**
  * Agregar Fase 2.17 con validaciones para:
    * Existencia, sintaxis AST (0 errores) y UTF-8 BOM en `romanOS-ControlCenter.ps1`.
    * Existencia de `romanOS-ControlCenter-Launcher.cs`.
    * Existencia y codificación No-BOM de `Lanzar-romanOS-ControlCenter.cmd`.
    * Soporte del parámetro `-GUI` en `romanOS-Toolkit.ps1`.
    * Inyección en `$OEM$` y WIM dentro del Builder.

---

## 4. Plan de Verificación Empírica

1. **Auditoría AST y Encoding (Fase Rápida):**
   ```powershell
   & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -File "c:\OptimizedISO\scripts\Testing\Invoke-TestSuite.ps1" -Quick
   ```
   * Criterio: 100% PASS en scripts (BOM verificado, 0 errores AST).
2. **Arnés Completo de Pruebas:**
   ```powershell
   & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -File "c:\OptimizedISO\scripts\Testing\Test-OptimizedISO-v2.ps1"
   ```
   * Criterio: 550+ pruebas aprobadas, `FAIL : 0`.
3. **Prueba en Frío de la GUI en Windows PowerShell 5.1:**
   ```powershell
   & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & 'c:\OptimizedISO\scripts\GUI\romanOS-ControlCenter.ps1' -WhatIf }"
   ```
   * Criterio: Carga de XAML sin excepciones y compilación de cabecera Win32 verificada.
