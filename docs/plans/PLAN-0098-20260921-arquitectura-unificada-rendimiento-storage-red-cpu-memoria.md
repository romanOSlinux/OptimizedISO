# PLAN-0098: romanOS Unified Performance Architecture (RUPA 2026)

**Fecha:** 2026-09-21  
**Estado:** COMPLETADO  
**Autor:** Antigravity / romanOS Software Engineering  
**Alcance:** Ecosistema Completo (SSOT, Hardware-Engine, ISO Builder, $OEM$, Control Center, Test Harness, Dashboards)

---

## 1. Contexto y Objetivos

Para llevar **OptimizedISO / romanOS** a un nivel institucional y de estado del arte (Windows 11 24H2 / 25H2), el sistema debe concebirse como un **organismo unificado** donde la Fuente Única de Verdad (SSOT), la detección de hardware, la compilación de la ISO, el despliegue desatendido (`$OEM$`), el Centro de Control (`romanOS-ControlCenter`) y el arnés de pruebas validen e implementen las mismas directivas con paridad matemática.

Basándonos en investigación rigurosa en documentación técnica oficial de Microsoft (Microsoft Learn, Windows Hardware Dev, WDDM, NDIS 6.85+, Kernel Memory Management y ACPI CPPC v2), se identifican **cinco pilares de ingeniería de bajo nivel** unificados:

1. **Almacenamiento & DirectStorage 1.2+ (BypassIO):** Auditoría de compatibilidad `fsutil bypassIo`, detección de minifiltros de terceros incompatibles (`fltmc filters`), erradicación global de 8.3 (`fsutil 8dot3name set 1`) y marcas de acceso (`disablelastaccess 1`), y garantía de TRIM activo.
2. **Red NDIS 6.85+ y Descargas por Hardware (UDP RSC / URO):** Habilitación canónica de `*UdpRsc` para optimizar paquetes multijugador y streaming en silicio, afinidad de colas RSS dinámicas evitando Core 0 (reservado para kernel/GPU), y TCP CUBIC + ECN.
3. **Programación de CPU Heterogénea y CPPC2:** Control de `SUB_PROCESSOR` (`93b8b6dc-0698-4d1c-9ee4-0644e900c85d`, `bae08b81-2d5e-4688-ad6a-13243356654b`), core unparking determinista y gestión de 3D V-Cache en AMD Dual-CCD.
4. **Arquitectura de Memoria Escalonada (RAM Tiering):** Gestión adaptativa con `MMAgent` y `DisablePagingExecutive` según la RAM física detectada (Low <8GB, Balanced 8-16GB, Enthusiast >16GB).
5. **Servicing de Componentes 24H2 / 25H2:** Arquitectura Checkpoint Cumulative Updates (KB5043080) y soporte Dev Drive (`fsutil devdrive`).

---

## 2. Componentes Implementados

1. `scripts/Core/Policy-Engine.ps1` (SSOT: almacenamiento, red, memoria, cpu con funciones exportadas).
2. `scripts/Core/Hardware-Engine.ps1` (Introspección de BypassIO, UDP RSC, RSS, RAM Tiering).
3. `scripts/Core/Test-StorageStackBypassIO.ps1` (Auditoría forense de almacenamiento y BypassIO).
4. `scripts/Core/Test-NetworkOffloadsAndRSS.ps1` (Auditoría forense de red NDIS y RSS).
5. `scripts/Testing/Test-StorageAndNetworkArchitecture.ps1` y `.cmd` (Suite de pruebas automatizada, 9/9 PASS).
6. `scripts/Testing/Invoke-TestSuite.ps1` (Integración de Fase 8 en arnés maestro).
7. `scripts/GUI/romanOS-ControlCenter.ps1` (Nuevos monitores de BypassIO, Red y Memoria con botones de auditoría).
8. `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` (Inyección offline y en `$OEM$`).
9. `AUDITORIA_RENDIMIENTO_GLOBAL_2026.html` (Dashboard consolidado interactivo).

---

## 3. Criterios de Aceptación y Validación

- [x] Codificación estricta UTF-8 con BOM en todos los `.ps1` y ANSI sin BOM en `.cmd`.
- [x] Validación fría contra Windows PowerShell 5.1 (`powershell.exe -STA`).
- [x] Cero fallos silenciosos (CWE-390: telemetría visible en todos los bloques `catch`).
- [x] 100% de aserciones aprobadas en la nueva suite de Almacenamiento, Red y Memoria (9/9 PASS).
- [x] `Invoke-TestSuite.ps1` pasando todas las 8 fases consecutivas en 31.4s.
- [x] Trazabilidad Git limpia sin binarios pesados.