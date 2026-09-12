# PLAN-0080: Conmutador Bimodal de Recursos para Gaming y Entorno de Desarrollo (romanOS Game & Dev Switch)

**Estado:** COMPLETADO  
**Fecha:** 2026-09-11  
**Autor:** romanOS Dev Team & Antigravity  
**Área:** Host Optimization / Gaming / Hyper-V Virtualization / Memory Management  

---

## 1. Justificación y Fundamento Técnico

### 1.1 Contexto de Hardware y Diagnóstico del Cuello de Botella
El equipo anfitrión opera bajo un perfil de uso dual intensivo:
1. **Estación de Desarrollo e Ingeniería de ISOs:** Ejecución de suites de prueba, compilación de imágenes con DISM, y aprovisionamiento de máquinas virtuales Gen2 en Hyper-V (`New-TestVM-HyperV.ps1`).
2. **Plataforma de Juegos (Gaming):** Títulos modernos competitivos y AAA.

La auditoría forense del sistema reveló las siguientes restricciones críticas de hardware:
- **Procesador & Gráficos:** AMD Ryzen 5 8600G (6C/12T) con gráficos integrados **AMD Radeon 760M (RDNA 3)**.
- **Memoria RAM:** 16 GB DDR5 (15.16 GB visibles en el SO).
- **Consumo en reposo:** ~7.43 GB ocupados, dejando únicamente **~7.73 GB libres**.
- **Impacto de la Arquitectura UMA (Unified Memory Architecture):** Al carecer de VRAM dedicada, la iGPU Radeon 760M reserva dinámicamente entre **2 GB y 4 GB** directamente de la memoria DDR5 del sistema. Al lanzar un juego con alta demanda, la suma de memoria RAM del juego + VRAM de la GPU satura los 15.16 GB físicos, forzando al kernel de Windows a paginar en disco (*pagefile*). Esto se traduce en **stuttering**, microcongelamientos y caídas catastróficas del *1% Low FPS*.
- **Impacto de Red (DPC Latency):** La presencia del adaptador virtual `vEthernet (Default Switch)` activo enruta todo el tráfico local a través del controlador de virtualización `vmswitch.sys`, induciendo latencia de llamada diferida a procedimiento (DPC) e inestabilidad de ping en juegos online.

### 1.2 Catálogo de Componentes Devoradores de Recursos en Segundo Plano
1. **Pila de Virtualización Hyper-V:** Servicios `vmms`, `vmcompute`, `HNS`, `CmService`, `HvHost`, `nvagent` y proceso `vmmemCmZygote`. Consumen memoria, hilos de sondeo continuo y mantienen activo el conmutador virtual de red.
2. **Procesos Navegadores Fantasma:** Microsoft Edge mantiene en segundo plano **13 procesos huérfanos** consumiendo **~1.51 GB a 2.30 GB** de RAM sin interfaz visual activa (por *Startup Boost*, extensiones, wallet y search indexer de Edge).
3. **Servicios de Telemetría, Compatibilidad y Mantenimiento:** `PcaSvc` (interceptor de ejecutables que genera shims y latencia de lanzamiento), `DPS`, `InventorySvc`, `DusmSvc` (contabilidad de paquetes en el stack de red), `UsoSvc` y `wuauserv`.
4. **Procesos UI del Sistema:** `SearchHost.exe`, `StartMenuExperienceHost.exe`, `LockApp.exe` retienen ~350 MB de Working Set en reposo.

---

## 2. Objetivos del Plan

1. **Crear el módulo canónico `Switch-GameDevMode.ps1`:** Un conmutador de dos estados idempotente y seguro que admita los modos `-Mode Game`, `-Mode Dev` y `-Mode Status`.
2. **Persistencia de Estado Transaccional:** Guardar el estado previo de los servicios en `$env:TEMP\romanOS_GameDevState.json` para que al retornar a `-Mode Dev` se reactiven exactamente los servicios que estaban activos.
3. **Poda de Memoria P/Invoke Quirúrgica (`EmptyWorkingSet`):** Integrar la API nativa de `psapi.dll` para reducir la huella física de procesos en reposo (SearchHost, StartMenu y Antigravity IDE) sin terminarlos violentamente.
4. **Protección Estricta de Componentes Inviolables:** Blindar por código los controladores de AMD Adrenalin (`AMDRSServ`, `RadeonSoftware`), software de auriculares (`Patriot Viper V380`), audio Realtek (`Audiosrv`), compositor (`dwm.exe`) y servicios requeridos por motores antitrampa y DRM (`CryptSvc`, `mpssvc`, `BFE`, `AppXSvc`).
5. **Lanzador Desatendido con Elevación UAC:** Crear `Switch-GameDevMode.cmd` con elevación automática de privilegios y compatibilidad estricta con Windows PowerShell 5.1 (`-STA`).
6. **Integración en el Ecosistema romanOS:** Registrar la opción dentro del menú principal de `romanOS-Toolkit.ps1` y `romanOS-Toolkit.cmd`.

---

## 3. Matriz de Componentes y Reglas de Transición

| Componente / Servicio | Rol en el Sistema | Acción en `-Mode Game` | Acción en `-Mode Dev` | Razón Técnica |
| :--- | :--- | :--- | :--- | :--- |
| `vmms`, `vmcompute`, `HNS`, `CmService`, `HvHost`, `nvagent` | Pila Hyper-V / VMs de prueba | **Detener** (orden inverso) | **Iniciar** (orden de dependencias) | Libera RAM, hilos de CPU y desmonta el switch virtual `vmswitch.sys`. |
| `vmmemCmZygote` | Proceso huérfano de contenedor | **Terminar** (`taskkill /F`) | Se regenera con Hyper-V | Elimina consumo residual. |
| `msedge.exe` (Background) | Navegador Edge en reposo | **Terminar** (`taskkill /F`) | Inicia por demanda del usuario | Recupera entre 1.5 y 2.3 GB de DDR5 de inmediato para la APU. |
| `MicrosoftEdgeUpdate`, `BraveUpdateCore` | Actualizadores en segundo plano | **Terminar proceso** | Se ejecutan por tarea programada | Evita actividad de I/O en disco durante la partida. |
| `PcaSvc` | Asistente de Compatibilidad | **Detener** | **Iniciar** | Elimina la intercepción de llamadas al iniciar `.exe` de juegos. |
| `DPS`, `InventorySvc`, `whesvc` | Diagnósticos y Telemetría | **Detener** | **Iniciar** | Cancela trazas ETW y sondeo de hardware en segundo plano. |
| `DusmSvc` | Uso de Datos de Red | **Detener** | **Iniciar** | Elimina el filtrado de paquetes en el stack NDIS. |
| `UsoSvc`, `wuauserv` | Windows Update Orchestrator | **Detener** | **Iniciar** | Previene descargas o escaneos automáticos mid-game. |
| `ssh-agent` | Agente SSH OpenSSH | **Detener** | **Iniciar** | No requerido en sesiones de juego. |
| `SearchHost`, `StartMenuExperienceHost` | Shell XAML de Windows | **Podar Working Set** (`EmptyWorkingSet`) | N/A (Se expande por demanda) | Pasa de ~250 MB a ~35 MB sin reiniciar la UI. |
| `Antigravity IDE` | Entorno de Desarrollo | **Podar Working Set** (Opcional -CloseIDE) | N/A | Reduce su huella de ~2.1 GB a ~400 MB sin cerrar el IDE. |
| `AMDRSServ`, `RadeonSoftware` | Driver AMD Adrenalin | **PROTEGIDO (Ignorar)** | **PROTEGIDO** | Esencial para GPU clocks, Anti-Lag y FreeSync en RDNA3. |
| `Patriot Viper V380` | Headset y Periféricos | **PROTEGIDO (Ignorar)** | **PROTEGIDO** | Sonido y micrófono del usuario. |
| `CryptSvc`, `mpssvc`, `BFE` | Criptografía y Firewall | **PROTEGIDO (Ignorar)** | **PROTEGIDO** | Requerido por EasyAntiCheat, BattlEye, Riot Vanguard y Steam. |
| `AppXSvc`, `ClipSVC`, `StateRepository` | Tienda Windows / Xbox | **PROTEGIDO (Ignorar)** | **PROTEGIDO** | Requerido por Xbox Game Pass y juegos UWP/GDK. |

---

## 4. Archivos a Crear y Modificar

### 4.1 Archivos Nuevos
1. `scripts/Modules/Switch-GameDevMode.ps1` (UTF-8 con BOM): Motor principal del conmutador con lógica de guardado de estado, orquestación de servicios y P/Invoke de `psapi.dll`.
2. `scripts/Modules/Switch-GameDevMode.cmd` (ANSI / UTF-8 sin BOM): Lanzador interactivo con menú de consola, auto-elevación UAC y soporte `-STA`.

### 4.2 Archivos a Modificar
1. `scripts/Modules/romanOS-Toolkit.ps1`: Añadir la opción del Conmutador de Modo Juego / Modo Dev en el menú del Toolkit.
2. `scripts/Modules/romanOS-Toolkit.cmd`: Soporte para invocar el nuevo módulo.
3. `docs/plans/README.md`: Registrar `PLAN-0080`.

---

## 5. Plan de Verificación

### 5.1 Pruebas de Sintaxis y Codificación (Windows PowerShell 5.1)
- Validar formato de codificación: UTF-8 con BOM en `.ps1` y ANSI / No-BOM en `.cmd`.
- Validación sintáctica en frío:
  `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command "& { & '.\scripts\Modules\Switch-GameDevMode.ps1' -WhatIf }"`

### 5.2 Verificación Funcional Bimodal
1. **Test Modo Juego:** Ejecutar `Switch-GameDevMode.ps1 -Mode Game`.
   - Comprobar que los servicios de Hyper-V y diagnósticos pasen a estado `Stopped`.
   - Comprobar que los procesos huérfanos de Edge se hayan cerrado.
   - Medir la memoria RAM libre antes y después (verificar liberación >= 3.0 GB).
   - Verificar que los servicios inviolables (`mpssvc`, `CryptSvc`, `Audiosrv`, AMD) permanezcan intactos.
2. **Test Modo Dev:** Ejecutar `Switch-GameDevMode.ps1 -Mode Dev`.
   - Comprobar que los servicios de Hyper-V (`vmms`, `vmcompute`, `HNS`, etc.) vuelvan a `Running`.
   - Comprobar que el adaptador `vEthernet (Default Switch)` se restaure operativamente.
   - Ejecutar un test de validación rápida de Hyper-V.
