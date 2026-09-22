# PLAN-0096: Auditoría Forense de Ciberseguridad, Compatibilidad con Anti-Cheats y Persistencia Dinámica de Registro (Zero-Trust & Hive Drift 2026)

**Fecha:** 2026-09-21  
**Estado:** COMPLETADO  
**Autor:** Antigravity (Google DeepMind)  
**Rama:** `feature/offline-ui-tweaks`  
**Prerrequisitos:** PLAN-0094 (Auditoría Técnica Exhaustiva), PLAN-0095 (Resolución Integral de Hallazgos y Certificación Ecosistema)

---

## 1. Contexto y Justificación de Ingeniería

El proyecto **romanOS / OptimizedISO** completó con éxito su auditoría estática, sintáctica y arquitectónica en el PLAN-0094 y PLAN-0095:
- 100% de los 83 scripts auditados y corregidos (cero fallos silenciosos CWE-390, compatibilidad verificada en Windows PowerShell 5.1 con UTF-8 BOM, modernización de lanzadores `.cmd` sin BOM y desacople de supuestos de hardware).
- 576 pruebas unitarias e integradas superadas con 100% PASS.

Habiendo garantizado la **calidad estática del código**, la siguiente frontera de confiabilidad radica en la **integridad en tiempo de ejecución**:
1. **Supervivencia del Entorno Gaming frente a Anti-Cheats de Kernel (2026)**:
   En Windows 11 (24H2/25H2), los motores anti-cheat a nivel Ring-0 (*Riot Vanguard, Easy Anti-Cheat, BattlEye, Ricochet, FACEIT*) imponen requisitos mandatorios sobre la integridad del kernel, el aprovisionamiento de certificados, la estructura de servicios PnP, y características de seguridad como VBS/TPM. Un debloat o ajuste de registro mal dimensionado (por ejemplo, deshabilitar `CryptSvc`, desproteger LSASS o alterar directivas de drivers de kernel) puede provocar bloqueos de arranque del juego, falsos positivos de trampa o prohibiciones de cuenta (*bans*).
2. **Seguridad de la Cadena de Suministro y Permisos ACL (Zero-Trust)**:
   Los scripts del generador de ISO y del Toolkit inyectan o descargan binarios redistribuibles (Visual C++, runtimes de DirectX, utilitarios Sysinternals, `wimlib-imagex`). Es mandatorio certificar la procedencia oficial, la validez de las firmas digitales Authenticode (con algoritmos SHA-256+), la ausencia de binarios sin firma y la protección contra ataques de escalamiento de privilegios local (LPE) y secuestro de DLLs (*DLL Hijacking*) en directorios `$OEM$`.
3. **Desviación de Estado del Registro (Registry Hive Drift & OOBE Overwrite)**:
   Windows 11 implementa mecanismos automáticos durante OOBE (*Out Of Box Experience*) y el aprovisionamiento de usuario que reescriben ciertas ramas de registro si no están blindadas a nivel de políticas de grupo (`HKLM\SOFTWARE\Policies`) o en la colmena `Default User`. Se requiere una auditoría diferencial de registro para garantizar que el 100% de los tweaks definidos en `Policy-Engine.ps1` permanezcan activos y no sean descartados por el sistema operativo.

---

## 2. Objetivos Principales

1. **Desarrollar la Suite Forense de Compatibilidad Anti-Cheat (`Test-AntiCheatCompatibility.ps1`)**:
   - Auditar cada servicio, controlador, política y configuración de memoria de `Policy-Engine.ps1` frente a los requisitos técnicos oficiales de:
     - *Riot Vanguard* (Valorant, LoL)
     - *Easy Anti-Cheat* (Fortnite, Apex Legends, Battlefield)
     - *BattlEye* (Rainbow Six Siege, Destiny 2)
     - *Ricochet* (Call of Duty: Warzone / Modern Warfare)
     - *FACEIT Anti-Cheat* (Counter-Strike 2)
2. **Desarrollar el Auditor de Cadena de Suministro y Firmas Digitales (`Test-SupplyChainIntegrity.ps1`)**:
   - Inspeccionar el 100% de binarios externos (`.exe`, `.dll`, `.sys`) en el repositorio y en los flujos de descarga/inyección.
   - Validar firmas Authenticode contra raíces de confianza de Microsoft/Sysinternals/fabricantes oficiales.
   - Construir el **Catálogo Maestro de Hashes SHA-256** (`scripts/Core/Binary-Integrity-Catalog.json`).
3. **Desarrollar el Motor de Detección de Desviación de Registro (`Test-RegistryHiveDrift.ps1`)**:
   - Implementar el protocolo de la skill `registry-forensics` para analizar colmenas de registro y contrastar el estado esperado de las directivas de `Policy-Engine.ps1` vs. el estado real de colmenas offline/online, detectando directivas sobreescritas o huérfanas.
4. **Auditoría de Permisos NTFS y Blindaje contra DLL Hijacking**:
   - Verificar que las carpetas creadas por `$OEM$` (`C:\Setup`, carpetas del Toolkit) restrinjan los permisos de escritura a `NT AUTHORITY\SYSTEM` y `BUILTIN\Administrators`, previniendo modificaciones maliciosas por usuarios estándar.
5. **Generación del Reporte Interactivo HTML (`AUDITORIA_SEGURIDAD_ANTICHEAT_2026.html`)**:
   - Documentar los resultados en un dashboard interactivo de última generación, con métricas cuantitativas, matriz de compatibilidad por juego/anti-cheat y recomendaciones técnicas de ingeniería.
6. **Integración en el Test Harness (`Invoke-TestSuite.ps1`)**:
   - Incorporar pruebas automatizadas de seguridad e integridad dentro del pipeline de testing del repositorio.

---

## 3. Arquitectura y Metodología de las Fases

### Fase 1: Auditoría de Compatibilidad con Anti-Cheats (Kernel Integrity)
- **Matriz de Servicios y Dependencias Críticas**:
  - `CryptSvc` (Servicios criptográficos y validación de firmas de catálogo en memoria).
  - `PlugPlay` (Enumeración de dispositivos y controladores).
  - `RpcSs` y `DcomLaunch` (Comunicación interprocesos RPC requerida por servicios anti-cheat como `vgc`).
  - `EventLog` (Registro de eventos de auditoría de Windows, requerido por EAC y BattlEye).
  - `BFE` (Base Filtering Engine, requerido para comunicación segura y aislamiento de red).
- **Parámetros de Kernel y Mitigaciones**:
  - Verificación de que no se deshabilite `TestSigning` ni se fuerce `DisableDriverSignatureEnforcement`.
  - Verificación de que `RunAsPPL` (LSA Protection) esté en `1` (Audit/Enforce seguro) y no en configuraciones que bloqueen la inyección de drivers legítimos de anti-cheat.
  - Verificación de que la gestión de memoria (`DisablePagingExecutive`, `LargePageDrivers`) no genere conflictos de acceso a memoria paginable en controladores de Ring-0.

### Fase 2: Auditoría Forense de Cadena de Suministro y Permisos (Zero-Trust)
- **Inspección Authenticode**:
  - Script automatizado que analiza recursivamente:
    - Binarios en `scripts/`, `tools/`, o carpetas de soporte.
    - Scripts que descargan herramientas (ej. Visual C++ Redistributable All-In-One, DirectX Web Setup, herramientas de red).
  - Criterio de aceptación:
    - Firma digital de Microsoft u OEM reconocido: `Válida`.
    - Algoritmo de hash de firma: `SHA-256` o `SHA-384` (cero SHA-1).
    - Hashes SHA-256 calculados y serializados en `Binary-Integrity-Catalog.json`.
- **Auditoría de Permisos ACL NTFS**:
  - Inspección de scripts de despliegue (`SetupComplete.cmd`, `FirstLogon.cmd`, inyección `$OEM$`):
    - Asegurar que no se asignen permisos `Everyone:F` o `Users:(OI)(CI)M` en carpetas ejecutables.
    - Aplicar el principio de mínimo privilegio: Escritura exclusiva para Administradores/SYSTEM.

### Fase 3: Auditoría de Desviación de Estado del Registro (Hive Drift)
- **Protocolo de la Skill `registry-forensics`**:
  - Invocación de análisis sobre colmenas de registro:
    - Carga controlada en memoria vía `reg load HKLM\OfflineAudit <HivePath>` con bloque `try/finally` para garantizar `reg unload`.
  - Comparativa de las directivas declaradas en `Get-RomanOSPolicies`:
    - Detección de claves de registro que requieren la rama `SOFTWARE\Policies` (GPO forzada inmune a reseteos de usuario) en vez de `SOFTWARE\Microsoft\Windows\CurrentVersion` (preferencia vulnerable a sobreescritura de OOBE).
    - Identificación de claves no documentadas o huérfanas.

### Fase 4: Dashboard Interactivo y Certificación
- Creación de `AUDITORIA_SEGURIDAD_ANTICHEAT_2026.html`:
  - Diseño Dark Mode con diseño modular responsivo.
  - Indicadores KPI: % Compatibilidad Anti-Cheat, % Binarios Firmados con SHA-256, % Persistencia de Políticas de Registro, Cantidad de Servicios Protegidos.
  - Matriz interactiva de compatibilidad por motor de juego (Vanguard, EAC, BattlEye, Ricochet, FACEIT).
  - Filtros dinámicos por nivel de severidad y componente auditado.

### Fase 5: Integración en el Test Harness y Validación Ecosistémica
- Adición de suite de pruebas en `tests/Unit/Security-Hardening.Tests.ps1` y `tests/Unit/SupplyChain-Integrity.Tests.ps1`.
- Ejecución completa de `Invoke-TestSuite.ps1` con comprobación física vía `grep_search` en el log de salida.
- Saneamiento y verificación en Windows PowerShell 5.1 con UTF-8 BOM estricto.

---

## 4. Archivos Afectados / Creados

| Tipo | Archivo | Propósito |
| :--- | :--- | :--- |
| **Nuevo** | `scripts/Core/Test-AntiCheatCompatibility.ps1` | Auditor dinámico de compatibilidad con motores anti-cheat de kernel |
| **Nuevo** | `scripts/Core/Test-SupplyChainIntegrity.ps1` | Verificador de firmas digitales Authenticode y generador de catálogo SHA-256 |
| **Nuevo** | `scripts/Core/Binary-Integrity-Catalog.json` | Catálogo maestro de hashes y firmas de dependencias externas |
| **Nuevo** | `scripts/Core/Test-RegistryHiveDrift.ps1` | Motor de análisis diferencial de colmenas de registro (Offline vs. Online) |
| **Nuevo** | `tests/Unit/Security-Hardening.Tests.ps1` | Pruebas Pester de seguridad, integridad y compatibilidad gaming |
| **Nuevo** | `AUDITORIA_SEGURIDAD_ANTICHEAT_2026.html` | Tablero visual interactivo de certificación y auditoría forense |
| **Modificación** | `scripts/Core/Policy-Engine.ps1` | Refuerzo de directivas de seguridad gaming-safe y blindaje de ramas GPO |
| **Modificación** | `tests/Invoke-TestSuite.ps1` | Registro de las nuevas suites de prueba de seguridad y cadena de suministro |
| **Modificación** | `docs/plans/README.md` | Registro de PLAN-0096 en el índice canónico |

---

## 5. Criterios de Aceptación y Validación

1. **Compatibilidad Anti-Cheat**: 100% de compatibilidad garantizada en los 5 motores evaluados (Vanguard, EAC, BattlEye, Ricochet, FACEIT) con 0 servicios esenciales deshabilitados.
2. **Cadena de Suministro**: 100% de binarios auditados con firma digital Authenticode válida o hash SHA-256 verificado en catálogo inmutable.
3. **Resiliencia de Registro**: 0 directivas de alta prioridad vulnerables a sobreescritura silenciosa por OOBE, migrando configuraciones sensibles a ramas de políticas forzadas (`HKLM\SOFTWARE\Policies`).
4. **Calidad de Código**: 100% de los nuevos scripts en codificación UTF-8 BOM, sin bloques `catch` vacíos (CWE-390 resuelto), y 0 errores AST al compilar en Windows PowerShell 5.1.
5. **Test Harness**: 100% de las pruebas unitarias e integradas pasando en verde (cero `FAIL`, comprobado físicamente en el log).
