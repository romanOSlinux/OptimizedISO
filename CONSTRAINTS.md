# CONSTRAINTS.md — Contrato Inmutable de Calidad de romanOS / OptimizedISO

> **REGLA DE GOBERNANZA VINCULANTE:**  
> *Read `CONSTRAINTS.md` before writing code. Do not weaken it to make a change pass.*  
> Este contrato define los estándares de calidad inmutables del proyecto. Queda terminantemente prohibido para cualquier agente humano o de IA debilitar, omitir, silenciar o relajar estos umbrales para obtener un estado verde artificial (*lazy green*).

---

## 1. Jerarquía de Verificación por Costo (*Cost-Placed Gates*)

Para optimizar el ciclo de desarrollo sin sacrificar rigor, las restricciones se organizan en 4 niveles según su costo de ejecución:

| Nivel de Verificación | Alcance | Tiempo Estimado | Comando de Ejecución | Cuándo Ejecutar |
| :--- | :--- | :--- | :--- | :--- |
| **L1: `check:fast`** | Codificación (BOM/No-BOM), sintaxis AST de PowerShell 5.1 y erradicación de fallos silenciosos (CWE-390). | < 3 segundos | `& powershell.exe -File scripts/Testing/Invoke-RomanOSHarness.ps1 -Fast` | Tras editar cualquier archivo `.ps1`, `.cmd` o `.xml`. |
| **L2: `check:task`** | L1 + Coherencia SSOT en `Policy-Engine.ps1`, esquema de `autounattend.xml` y matriz de mocks multi-hardware. | < 12 segundos | `& powershell.exe -File scripts/Testing/Invoke-RomanOSHarness.ps1` | Al completar un hito o tarea antes de proceder a la siguiente. |
| **L3: `check:full`** | L2 + Batería completa de regresión (14 suites de `scripts/Testing/` + firmas Authenticode + anti-cheats). | ~75 segundos | `scripts\Testing\Invoke-TestSuite.cmd` (Pre-commit hook) | Antes de realizar cualquier commit atómico a Git. |
| **L4: `check:deploy`** | Montaje WIM offline, inspección de colmenas de registro y despliegue automatizado en VM Hyper-V Gen2. | 15–25 minutos | `scripts\Testing\New-TestVM-HyperV.cmd` (Requiere UAC) | Certificación de release maestro e ISO final. |

---

## 2. Dimensiones de Calidad y Umbrales Estrictos

### Dimensión A: Integridad Estática y Seguridad de Código

| Restricción / Invariante | Umbral No Negociable | Nivel | Verificado Por | Fundamento Técnico y Fuente Oficial |
| :--- | :--- | :--- | :--- | :--- |
| **Codificación PowerShell** | **100% UTF-8 con BOM** (`0xEF, 0xBB, 0xBF`) en `.ps1`, `.psm1`, `.psd1`. | L1 | `Invoke-RomanOSHarness.ps1` (Tier 1.1) | Windows PowerShell 5.1 cae a ANSI (Windows-1252) sin BOM, corrompiendo cadenas y tildes. |
| **Codificación Batch** | **100% Sin BOM (No-BOM / ANSI)** en `.cmd` y `.bat`. | L1 | `Invoke-RomanOSHarness.ps1` (Tier 1.2) | `cmd.exe` no reconoce el BOM e interpreta los bytes como caracteres literales (`ï»¿@echo`), fallando. |
| **Compatibilidad de Runtime** | **0 errores AST** en motor nativo **Windows PowerShell 5.1**. | L1 | `[Parser]::ParseFile` en `powershell.exe` | La ISO y el entorno de destino corren sobre PS 5.1 de fábrica. No asumir compatibilidad por PS 7. |
| **Erradicación de Fallos Silenciosos** | **0 bloques `catch { }` vacíos** en scripts operativos (CWE-390 / Fail-Visible). | L1 | `Invoke-RomanOSHarness.ps1` (Tier 1.4) | Capturar excepciones sin telemetría oculta fallos fatales en tiempo de ejecución. Toda captura debe emitir `Write-Warning` o log. |
| **Restricción de SilentlyContinue** | Prohibido `-ErrorAction SilentlyContinue` en operaciones de modificación o lectura de hardware. | L1 | Auditoría AST / Grep | Oculta fallos en manipulaciones de registro y detección de topología. Solo permitido en `Test-Path`. |

### Dimensión B: Arquitectura de Fuente Única de Verdad (SSOT)

| Restricción / Invariante | Umbral No Negociable | Nivel | Verificado Por | Fundamento Técnico y Fuente Oficial |
| :--- | :--- | :--- | :--- | :--- |
| **Canonicidad de Directivas** | **100% de políticas residen en `scripts/Core/Policy-Engine.ps1`**. | L2 | `Get-RomanOSPolicies` | Principio SSOT (Regla 9). Prohibida duplicación o directivas huérfanas en consumidores. |
| **Completitud de Metadatos** | Cada política debe poseer `RegistryKey`, `ValueName`, `Type` y `ExpectedValue` válidos. | L2 | `Invoke-RomanOSHarness.ps1` (Tier 2.1) | Garantiza exportación determinista a unattend XML, DISM offline y diagnósticos post-install. |
| **Esquema de Instalación Desatendida** | `autounattend.xml` debe validar contra `urn:schemas-microsoft-com:unattend` con pases `windowsPE`, `specialize` y `oobeSystem`. | L2 | `Invoke-RomanOSHarness.ps1` (Tier 2.2) | *Microsoft Learn: Windows Setup Unattend Specification.* Previene el fallo fatal en OOBE. |
| **Bypasses OOBE Obligatorios** | `BypassNRO = 1` y bypass de requisitos de hardware configurados en el XML. | L2 | Parseo XML formal | Permite instalación limpia sin forzar cuenta Microsoft obligatoria ni bloquear hardware modesto. |

### Dimensión C: Agnosticismo de Hardware y Lógica Adaptativa

| Restricción / Invariante | Umbral No Negociable | Nivel | Verificado Por | Fundamento Técnico y Fuente Oficial |
| :--- | :--- | :--- | :--- | :--- |
| **Invariante Memoria APU/UMA** | `LargeSystemCache = 0` estricto en topologías de memoria compartida (iGPU). | L2 | `Test-HardwareTopologyMocks.ps1` | `LargeSystemCache = 1` bloquea RAM para caché de disco, colapsando el pool de VRAM de la APU. |
| **Planificador Heterogéneo** | `Win32PrioritySeparation` **dinámico**. Prohibido forzar `38 (0x26)` estático en CPUs Intel Híbridas o AMD 3D V-Cache. | L2 | `Test-HardwareTopologyMocks.ps1` | Forzar 38 estático neutraliza Intel Thread Director y el driver de aparcamiento de AMD CPPC. |
| **Almacenamiento Volumen por Volumen** | Prohibido desactivar indexación de búsqueda globalmente si coexisten SSDs y HDDs mecánicos. | L2 | `Test-StorageAndNetworkArchitecture.ps1` | Desactivar indexación en discos mecánicos colapsa las búsquedas en Windows Explorer a minutos. |
| **Cobertura de Mocks Sintéticos** | 100% de éxito en los 4 perfiles simulados (Intel P/E, AMD X3D, APU UMA y SATA HDD). | L2 | `Invoke-RomanOSHarness.ps1` (Tier 3) | Certificación de cero asunciones fijas de hardware (Regla 14). |

### Dimensión D: Ciberseguridad, Cadena de Suministro y Kernel Ring-0

| Restricción / Invariante | Umbral No Negociable | Nivel | Verificado Por | Fundamento Técnico y Fuente Oficial |
| :--- | :--- | :--- | :--- | :--- |
| **Vulnerable Driver Blocklist** | `VulnerableDriverBlocklistEnable = 1` en `HKLM\SYSTEM\CurrentControlSet\Control\CI\Config`. | L2 | `Test-SecurityAndAntiCheat.ps1` | *Microsoft Recommended Driver Block Rules.* Requisito innegociable de Riot Vanguard y Easy Anti-Cheat. |
| **Protección LSA en Kernel** | `RunAsPPL = 1` y `RunAsPPLBoot = 2` en `HKLM\SYSTEM\CurrentControlSet\Control\Lsa`. | L2 | `Test-SecurityAndAntiCheat.ps1` | Blindaje del proceso `lsass.exe` contra volcados de memoria y robo de credenciales en RAM. |
| **Compatibilidad Ring-0** | 100% de compatibilidad garantizada con 5 motores: Vanguard, EAC, BattlEye, Ricochet y FACEIT. | L2 | `Test-AntiCheatCompatibility.ps1` | Una optimización de SO no debe impedir la ejecución de juegos competitivos modernos. |
| **Firmas Authenticode** | 100% de binarios externos en `bin/` con firma digital válida y hash SHA-256 verificado. | L3 | `sigcheck64` / Authenticode | Garantiza integridad absoluta de la cadena de suministro contra binarios modificados. |
| **Resiliencia Hive Drift** | Políticas inyectadas en WIM offline deben sobrevivir sin sobreescritura tras el primer inicio OOBE. | L2 | `Test-RegistryHiveDrift.ps1` | Evita que Windows Setup restablezca configuraciones de fábrica silenciosamente. |

---

## 3. Protocolo de Bloqueo Anti-Regresión y Anti-Supresión (*Anti-Weakening Guard*)

Queda estrictamente prohibido para el agente realizar cualquiera de las siguientes acciones para obtener un estado "verde" en el arnés:

1. **Prohibición de Supresión de Pruebas:**
   - Prohibido comentar, borrar o envolver aserciones en bloques condicionales falsos.
   - Prohibido rebajar umbrales cuantitativos (ej. modificar el arnés para aceptar 90% en lugar de 100%).
2. **Prohibición de Parches Cosméticos:**
   - Si una prueba de compilación de ISO o despliegue de VM falla por falta de elevación (`IsAdmin = False`), está prohibido inventar scripts que solo comprueben si el archivo existe para dar la tarea por completada. El estado debe reportarse como `BLOQUEADO_POR_UAC`.
3. **Política de Trinquete (*Ratcheting Policy*):**
   - Una vez que una métrica de calidad alcanza un nuevo máximo (ej. 0 bloques `catch` vacíos, 100% de políticas tipadas), ese umbral se convierte en el nuevo piso inmutable. Ningún cambio posterior puede degradar la métrica.
4. **Regla Stop-the-Line:**
   - Ante cualquier fallo en `Invoke-RomanOSHarness.ps1`, el agente suspenderá de inmediato cualquier nueva tarea o edición adyacente hasta resolver la causa raíz mediante el triaje en 5 pasos (`Reproduce → Localize → Reduce → Fix → Guard`).

---

## 4. Referencias Canónicas Desacopladas

Para consultas de detalle sin saturación de contexto, consultar los documentos normativos bajo `.agents/references/`:
- Invariantes de Hardware: [`.agents/references/hardware-invariants.md`](.agents/references/hardware-invariants.md)
- Seguridad y Anti-Cheat: [`.agents/references/security-anti-cheat.md`](.agents/references/security-anti-cheat.md)
