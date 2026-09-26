# PLAN-0117: Fase 2 - Inspiración Chris Titus Tech WinUtil: Gestor de Software Desatendido, Conmutador y Optimizador de DNS Inteligente (DoH + RTT) y Micro-Mejoras de Servicing en ISO Builder

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0117 |
| **Fecha** | 2026-09-26 |
| **Componentes** | `scripts/Core/Policy-Engine.ps1`, `scripts/Modules/Deploy-AppProfiles.ps1`, `scripts/Modules/Win11-Network-Diagnostics-Optimizer.ps1`, `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`, `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/Modules/romanOS-Toolkit.ps1`, `scripts/Testing/Test-WinUtilIntegration.ps1`, `docs/plans/README.md` |
| **Estado** | `EN PROGRESO` |
| **Prioridad** | Alta (Ampliación de Capacidades de Red/DNS en Tiempo Real, Aprovisionamiento de Software y Robustez de Servicing) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM / PS 5.1), Regla 5 (Planes), Regla 7 (Watchdogs), Regla 8 (Modo Autónomo Continuo), Regla 9 (SSOT Policy-Engine), Regla 10 (Cascada Docs-as-Code), Regla 11 (Ingeniero Autónomo), Regla 13 (Auditoría Holística / CWE-390), Regla 14 (Salvaguarda de Almacenamiento y Mocks Multi-Hardware), Regla 15 (Memoria Jerárquica Map-Reduce) |

---

## 1. Contexto, Objetivos y Principio de Soberanía Arquitectónica

### A. Principio Fundamental: Soberanía del Motor de ISO de romanOS
El proyecto `romanOS / OptimizedISO` cuenta con un motor de creación y servicing de imágenes ISO (`New-OptimizedWindowsISO-v2.ps1`) que es **técnicamente superior y mucho más exhaustivo que MicroWin de Chris Titus Tech**. Nuestro pipeline ya incluye:
* Generación dinámica de `autounattend.xml` con esquema UEFI GPT completo, bypass TPM/SecureBoot/RAM/Disk/CPU y modo oscuro de sistema.
* Doble inyección de runtimes esenciales (en WIM offline y en `$OEM$` para ejecución post-instalación).
* Servicing estructurado de actualizaciones acumulativas (.msu/.cab), drivers x64 certificados y validación con `wimlib-imagex`.
* Logging auditable forense con generación automática de `AI_SUMMARY.md`.

**Mandato Incondicional:** MicroWin se utiliza **única y exclusivamente como marco referencial comparativo**. No se reemplaza ni se subordina nuestro motor de compilación; únicamente se extraen quirúrgicamente aquellas micro-optimizaciones puntuales de alto valor comprobado (`sources\ei.cfg` y verificación de integridad de metadatos `Assert-WimMetadata`), descartando de plano todo lo redundante, rígido o inferior.

---

### B. Objetivos Centrales de la Fase 2 (Inspiración WinUtil)

1. **Conmutador y Optimizador Inteligente de DNS (DoH + Latencia RTT en Vivo):**
   * Incorporar perfiles canónicos de proveedores DNS líderes mundiales (Cloudflare, Quad9, Google, AdGuard) en `Policy-Engine.ps1`.
   * Proporcionar medición activa de RTT en milisegundos en tiempo real hacia cada resolver DNS desde `Win11-Network-Diagnostics-Optimizer.ps1` y la GUI, permitiendo al usuario o al sistema seleccionar automáticamente el DNS más rápido y privado.
   * Configurar DNS-over-HTTPS (DoH) nativo en Windows 11 para los resolvers compatibles.
2. **Gestor de Software Desatendido y Catálogo Curado (WinGet Engine):**
   * Expandir `Deploy-AppProfiles.ps1` con un catálogo organizado por categorías (Navegadores, Gaming, Desarrollo, Utilidades del Sistema, Multimedia/Productividad).
   * Automatización desatendida mediante `winget.exe` con parámetros no interactivos (`--silent --accept-package-agreements --accept-source-agreements`) y fallback para descargas directas cuando WinGet no esté disponible o se opere offline.
3. **Micro-Mejoras de Servicing en `New-OptimizedWindowsISO-v2.ps1`:**
   * **Inyección Canónica de `sources\ei.cfg`:** Evitar que Windows Setup detenga la instalación desatendida pidiendo clave de producto o selección manual de edición si el medio contiene múltiples índices.
   * **Validación de Integridad de Metadatos WIM (`Assert-RomanOSWimMetadata`):** Validar que atributos críticos (`Languages`, `Edition`, `ProductType`) no sufran alteración o corrupción en DISM tras la inyección de paquetes.
4. **Integración en Cascada (SSOT y Paridad Total en GUI / Toolkit):**
   * Reflejar el selector de DNS y el gestor de software en `romanOS-ControlCenter.ps1` y `romanOS-Toolkit.ps1`.
   * Desarrollar suite de pruebas unitarias (`Test-WinUtilIntegration.ps1`) en Windows PowerShell 5.1 con UTF-8 BOM estricto.

---

## 2. Plan de Implementación por Fases

### Fase 1: Motor y Conmutador de DNS Inteligente (SSOT + RTT en Vivo)
* **`scripts/Core/Policy-Engine.ps1`:**
  * Registrar definiciones canónicas de DNS en tabla inmutable (`Get-RomanOSDnsProfiles`):
    * Cloudflare: `1.1.1.1`, `1.0.0.1` (DoH: `https://cloudflare-dns.com/dns-query`).
    * Quad9 (Seguro/Malware block): `9.9.9.9`, `149.112.112.112` (DoH: `https://dns.quad9.net/dns-query`).
    * Google: `8.8.8.8`, `8.8.4.4` (DoH: `https://dns.google/dns-query`).
    * AdGuard: `94.140.14.14`, `94.140.15.15` (DoH: `https://dns.adguard-dns.com/dns-query`).
* **`scripts/Modules/Win11-Network-Diagnostics-Optimizer.ps1`:**
  * Implementar `Test-RomanOSDnsLatency`: Medición precisa de socket TCP (puerto 53 / 443) o Ping ICMP que reporte latencia media en ms.
  * Implementar `Set-RomanOSDnsServer`: Aplica el proveedor seleccionado al adaptador activo (IPv4 y plantilla DoH de Windows 11 `netsh dns add encryption`).
  * Implementar `Reset-RomanOSDnsServer`: Restablece la configuración a DHCP automático.

### Fase 2: Gestor de Software Desatendido y Catálogo Curado (WinGet Engine)
* **`scripts/Modules/Deploy-AppProfiles.ps1`:**
  * Enriquecer catálogo de software en `Get-SoftwareCatalog` con IDs oficiales de WinGet divididos en categorías claras:
    * *Navegadores:* Brave, Mozilla Firefox, Google Chrome, Librewolf.
    * *Gaming:* Steam, Epic Games, Discord, OBS Studio, Prism Launcher.
    * *Desarrollo:* Git, VS Code, Node.js, Python 3, Windows Terminal.
    * *Utilidades:* 7-Zip, Notepad++, Everything, CPU-Z, FastStone Image Viewer.
  * Implementar `Install-RomanOSAppsBatch`: Orquestador de instalación desatendida vía WinGet con flags silenciosos, barra de progreso y log detallado.
* **`scripts/Modules/romanOS-Toolkit.ps1`:**
  * Agregar opción de menú interactivo CLI para conmutar DNS y seleccionar apps para instalación desatendida.

### Fase 3: Micro-Mejoras de Servicing en ISO Builder (MicroWin Core Evaluado)
* **`scripts/Builder/New-OptimizedWindowsISO-v2.ps1`:**
  * Implementar `Write-RomanOSEiCfg`: Generar `sources\ei.cfg` canónico en la raíz del medio de instalación para fijar el canal por defecto y evitar detenciones en el instalador.
  * Implementar `Assert-RomanOSWimMetadata`: Función de salvaguarda que capture los metadatos WIM pre-servicing y compare tras la inyección de drivers y actualizaciones para asegurar cero corrupción.

### Fase 4: Paridad e Integración Gráfica (romanOS Control Center)
* **`scripts/GUI/romanOS-ControlCenter.ps1`:**
  * Agregar pestaña o tarjeta de "Red & Conmutador DNS":
    * Visualización de DNS actual y botón de prueba rápida de latencia RTT.
    * Selector desplegable o botones de 1-clic para Cloudflare, Quad9, Google, AdGuard o DHCP.
  * Enriquecer sección de "Software y Runtimes" con selector por categorías y botón de despliegue silencioso.

### Fase 5: Suite de Pruebas Unitarias y Certificación (Reglas 4, 13 y 14)
* Crear `scripts/Testing/Test-WinUtilIntegration.ps1`:
  * Mocks sintéticos de adaptadores de red y consultas DNS sin conexión externa obligatoria.
  * Verificación de sintaxis y compatibilidad en frío en Windows PowerShell 5.1 (`powershell.exe -STA`).
  * Validación de codificación UTF-8 con BOM y cero fallos silenciosos CWE-390.

---

## 3. Matriz de Trazabilidad y Verificación

| Componente | Archivo Principal | Aserciones Mínimas | Modo Simulado (`-WhatIf`) |
| :--- | :--- | :---: | :---: |
| **DNS Engine** | `Policy-Engine.ps1` / `Win11-Network-Diagnostics-Optimizer.ps1` | Perfiles válidos, DoH y RTT medible | Soportado |
| **Software Engine** | `Deploy-AppProfiles.ps1` | Catálogo parseable, validación de IDs WinGet | Soportado |
| **ISO Servicing** | `New-OptimizedWindowsISO-v2.ps1` | `ei.cfg` válido, validación de metadatos WIM | Soportado |
| **GUI Control Center** | `romanOS-ControlCenter.ps1` | Handlers enlazados a funciones SSOT | Soportado |
| **Suite QA** | `scripts/Testing/Test-WinUtilIntegration.ps1` | 100% PASS en PS 5.1 | Requerido |
