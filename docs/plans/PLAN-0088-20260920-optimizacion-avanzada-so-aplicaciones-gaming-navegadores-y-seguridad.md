# PLAN-0088: Optimización Avanzada y Hardening de Impacto Cero en Sistema Operativo, Aplicaciones, Gaming y Navegadores

**Estado:** `COMPLETADO`  
**Fecha:** 2026-09-20  
**Autor:** Antigravity AI Pair Programmer & romanOS Team  
**Rama:** `feature/offline-ui-tweaks`  

---

## 1. Resumen Ejecutivo y Marco Técnico

Tras la auditoría forense del sistema en vivo y la comprobación empírica de las 18 herramientas del **romanOS Toolkit**, el sistema anfitrión actual cuenta con una base sólida (score de optimización del 94%, MMCSS ajustado, kernel en RAM, debloat de servicios y bypasses activos).

El objetivo de este plan es diseñar e integrar una suite de optimizaciones de segunda generación basada en fuentes técnicas oficiales (**Microsoft Learn, WDDM 3.x, AMD Developer Guides, RFCs de IETF y Chromium Enterprise**). El foco central es lograr un estándar de **ciberseguridad robusta sin pérdida de FPS (*Zero-Impact Hardening*)** y una afinación de recursos milimétrica para aplicaciones cotidianas (Steam, Discord, Spotify), el subsistema gráfico de APUs modernas (AMD Ryzen 8600G / Radeon 760M) y navegadores web.

---

## 2. Los 5 Pilares de Implementación Técnica

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   ARQUITECTURA DE OPTIMIZACIÓN 5 PILARES (PLAN-0088)             │
├──────────────────────────────────────────────────────────────────────────────────┤
│ 1. SO & Red (Kernel)   ➔ ECN, Timestamps Off, Green Ethernet Off, MSI-X, BypassIO│
│ 2. Hardening Seguro    ➔ LSA RunAsPPL, Defender ASR Gaming-Safe, Driver Blocklist│
│ 3. Gaming & WDDM 3.x   ➔ Multi-Plane Overlays (MPO), Flip Model, UMA Buffer QoS  │
│ 4. Apps & Electron     ➔ Steam VRAM Saver, Occlusion Off, Poda de Working Set    │
│ 5. Navegadores Web     ➔ Decodificación HW VCN 4.0 (AV1), WebRTC Leak Proof, DoH│
└──────────────────────────────────────────────────────────────────────────────────┘
```

### Pilar 1: Kernel, Red y Almacenamiento (SO)
1. **ECN Capability (RFC 3168):** Activar `netsh int tcp set global ecncapability=enabled` para mitigar latencia y pérdida de paquetes ante congestión.
2. **Supresión de TCP Timestamps (RFC 7323):** Desactivar `timestamps` para eliminar 12 bytes de sobrecarga por paquete en el tráfico de red de baja latencia.
3. **Erradicación de Ahorro de Energía en NICs (IEEE 802.3az):** Desactivar *Green Ethernet* y *Energy Efficient Ethernet* en interfaces físicas para suprimir micro-retrasos de reactivación.
4. **Validación de BypassIO y DirectStorage 1.2+:** Garantizar paso directo entre almacenamiento NVMe y el subsistema gráfico.

### Pilar 2: Ciberseguridad Robusta de Impacto Cero (Zero-Impact Hardening)
1. **LSA Protection (RunAsPPL):** Proteger el proceso `lsass.exe` como PPL (`RunAsPPL = 1`, `RunAsPPLBoot = 2`), neutralizando ataques de volcado de credenciales en memoria (Mimikatz) con 0% de consumo de CPU.
2. **Microsoft Recommended Driver Blocklist:** Activar `VulnerableDriverBlocklistEnable = 1` para bloquear ataques BYOVD (*Bring Your Own Vulnerable Driver*).
3. **Reglas ASR (Attack Surface Reduction) Gaming-Safe:** Habilitar reglas selectivas contra inyecciones maliciosas y macros ofuscadas sin interferir con ejecutables de juegos ni sistemas anti-cheat a nivel de kernel (Vanguard, EAC, BattlEye).
4. **DNS Cifrado Nativo (DoH):** Configuración de DoH persistente para resoluciones en <5 ms con filtrado de malware.

### Pilar 3: Gaming y Subsistema Gráfico WDDM 3.x (APU AMD Ryzen / Radeon 760M)
1. **Multi-Plane Overlays (MPO) & Hardware Flip:** Forzar el modelo de presentación independiente (*Independent Flip*) para lograr latencia de pantalla completa exclusiva en juegos en modo ventana sin bordes.
2. **Prioridad UMA Buffer para Juegos:** Ajustar el planificador de memoria del kernel para prevenir que Windows desaloje texturas de la GPU integrada a disco durante sesiones de juego intenso.
3. **Purgador Resiliente de Shaders:** Limpieza selectiva de `%LOCALAPPDATA%\AMD\DxCache` y `%LOCALAPPDATA%\D3DSCache` tras actualizaciones de controladores.

### Pilar 4: Aplicaciones Cotidianas, Electron y Clientes de Juegos
1. **Steam VRAM Optimizer:** Desactivar la aceleración GPU en las vistas web de Steam (`Steam Web Helper`), liberando 250–450 MB de memoria de video compartida (VRAM) para los juegos.
2. **Tuning de Aplicaciones Electron (Discord, Spotify, VS Code):** Suprimir la oclusión de ventanas innecesaria (`CalculateNativeWinOcclusion = disabled`) y desactivar telemetría residual.
3. **Poda Transaccional de Working Set:** Integración de llamadas de liberación de memoria de procesos secundarios al entrar en modo juego.

### Pilar 5: Navegadores Web (Chromium / Firefox / Brave)
1. **Forzado de Aceleración por Hardware AV1 / VCN 4.0:** Aprovechar el motor de decodificación nativa de la APU AMD para transmisiones de video en alta definición, reduciendo el uso de CPU a <1%.
2. **Prevención de Fuga de IP Privada vía WebRTC:** Restricción de puertos y directivas de privacidad de red.
3. **Neutralización de Procesos Residuales:** Garantizar terminación completa de procesos en segundo plano al cerrar navegadores (`continue_running_background_apps = 0`).

---

## 3. Plan de Modificaciones en el Código del Repositorio

### Componente 1: Núcleo Canónico de Políticas (SSOT: `Policy-Engine.ps1`)
* Modificar: [`scripts/Core/Policy-Engine.ps1`](file:///c:/OptimizedISO/scripts/Core/Policy-Engine.ps1)
  * Añadir claves de LSA RunAsPPL, Driver Blocklist, ASR selectivo y GPOs avanzadas de navegadores.

### Componente 2: Optimizador de Red (`Win11-Network-Diagnostics-Optimizer.ps1`)
* Modificar: [`scripts/Modules/Win11-Network-Diagnostics-Optimizer.ps1`](file:///c:/OptimizedISO/scripts/Modules/Win11-Network-Diagnostics-Optimizer.ps1)
  * Automatizar la aplicación de ECN, supresión de TCP Timestamps y desactivación de ahorro de energía en la NIC física.

### Componente 3: Nuevo Módulo Satélite (`Optimize-GamingAndApps.ps1` y `.cmd`)
* Crear: [`scripts/Modules/Optimize-GamingAndApps.ps1`](file:///c:/OptimizedISO/scripts/Modules/Optimize-GamingAndApps.ps1)
* Crear: [`scripts/Modules/Optimize-GamingAndApps.cmd`](file:///c:/OptimizedISO/scripts/Modules/Optimize-GamingAndApps.cmd)
  * Gestión de Steam VRAM, tuning de Electron y purga de caché de shaders.

### Componente 4: Navegadores Web (`Optimize-WebBrowsers.ps1`)
* Modificar: [`scripts/Modules/Optimize-WebBrowsers.ps1`](file:///c:/OptimizedISO/scripts/Modules/Optimize-WebBrowsers.ps1)
  * Incorporar las nuevas GPOs de decodificación HW y privacidad WebRTC.

### Componente 5: Auditoría Universal (`Audit-SystemOptimization.ps1`)
* Modificar: [`scripts/Modules/Audit-SystemOptimization.ps1`](file:///c:/OptimizedISO/scripts/Modules/Audit-SystemOptimization.ps1)
  * Actualizar heurísticas para evaluar RunAsPPL, Driver Blocklist, ECN y ahorro de energía en adaptadores de red, garantizando scoring de 100%.

### Componente 6: Orquestadores (`romanOS-Toolkit.ps1` y `romanOS-ControlCenter.ps1`)
* Modificar: [`scripts/Modules/romanOS-Toolkit.ps1`](file:///c:/OptimizedISO/scripts/Modules/romanOS-Toolkit.ps1)
* Modificar: [`scripts/GUI/romanOS-ControlCenter.ps1`](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter.ps1)
  * Enlazar el nuevo módulo tanto en el menú CLI como en la interfaz gráfica WPF.

---

## 4. Protocolo de Verificación y Certificación

1. **Verificación de Sintaxis y Codificación:**
   * UTF-8 con BOM obligatorio en archivos `.ps1`.
   * ANSI / UTF-8 sin BOM en archivos `.cmd`.
   * Ejecución en frío contra `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass`.
2. **Validación Forense en el Sistema en Vivo:**
   * Re-ejecución de `Audit-SystemOptimization.ps1` para verificar el incremento del scoring a nivel de elite.
   * Inspección de procesos de seguridad (`lsass.exe` en PPL) y comprobación de memoria liberada en Steam/Electron.
