# CONSTRAINTS.md — Contrato Inmutable de Calidad de romanOS / OptimizedISO

Este documento establece el **estándar de calidad no negociable** para el desarrollo, compilación y optimización del ecosistema romanOS. Queda estrictamente prohibido para cualquier agente humano o de inteligencia artificial debilitar, evadir o silenciar los umbrales aquí descritos.

El cumplimiento de este contrato se evalúa automáticamente mediante el arnés determinista [`scripts/Testing/Invoke-RomanOSHarness.ps1`](scripts/Testing/Invoke-RomanOSHarness.ps1).

---

## 1. Integridad Estática y Seguridad de Código (Cero Tolerancia)

| Restricción | Umbral Exigido | Método de Verificación |
| :--- | :--- | :--- |
| **Codificación de Scripts PowerShell** | **100% UTF-8 con BOM** (`0xEF, 0xBB, 0xBF`) en `.ps1`, `.psm1`, `.psd1`. | Análisis binario de bytes de cabecera. |
| **Codificación de Scripts por Lotes** | **100% Sin BOM (No-BOM)** en archivos `.cmd` y `.bat`. | Análisis binario de bytes de cabecera. |
| **Compatibilidad de Runtime** | **0 errores AST** ejecutado en **Windows PowerShell 5.1** (`powershell.exe`). | `[System.Management.Automation.Language.Parser]::ParseFile`. |
| **Erradicación de Fallos Silenciosos** | **0 bloques `catch { }` vacíos** en todo el repositorio (CWE-390 / Fail-Visible). | Inspección AST de `CatchClauseAst`. |
| **Uso de `-ErrorAction SilentlyContinue`** | **Restringido exclusivamente a comprobaciones de lectura** (`Test-Path`, `Get-Command`). Prohibido en modificaciones. | Auditoría estática AST y Grep. |

---

## 2. Arquitectura de Fuente Única de Verdad (SSOT)

| Restricción | Umbral Exigido | Método de Verificación |
| :--- | :--- | :--- |
| **Catálogo Maestro de Directivas** | **100% de políticas residen en `scripts/Core/Policy-Engine.ps1`**. | Inspección de catálogo mediante `Get-RomanOSPolicies`. |
| **Prohibición de Directivas Huérfanas** | **0 cadenas hardcodeadas** en scripts consumidores (`SetupComplete.cmd`, `autounattend.xml`, debloat). | Auditoría de referencias en cascada (Regla 10). |
| **Completitud de Metadatos** | Cada política debe tener `RegistryKey`, `ValueName`, `Type` y `ExpectedValue` válidos. | Tier 2 del Evaluation Harness. |
| **Validación de Esquema XML** | `autounattend.xml` debe validar contra el namespace oficial `urn:schemas-microsoft-com:unattend` con pases `windowsPE`, `specialize` y `oobeSystem`. | Parseo XML formal .NET. |

---

## 3. Invariantes Multi-Hardware (Agnosticismo de Entorno)

| Restricción | Umbral Exigido | Justificación Técnica |
| :--- | :--- | :--- |
| **Topología APU / iGPU (Memoria UMA)** | `LargeSystemCache = 0` estricto. | Evita que el caché de archivos bloquee RAM necesaria para texturas compartidas de la GPU integrada. |
| **Topología de CPUs Heterogéneas** | `Win32PrioritySeparation` **dinámico**. Prohibido valor estático `38 (0x26)` en Intel 12th-14th Gen (P/E cores) o AMD 3D V-Cache. | Preserva el funcionamiento de Intel Thread Director y AMD CPPC. |
| **Topología de Almacenamiento** | Detección **volumen por volumen**. Prohibido desactivar indexación globalmente si conviven SSDs con HDDs mecánicos. | Previene colapso de búsquedas en almacenamiento magnético SATA. |
| **Lógica Adaptativa Multi-Perfil** | El código debe superar la matriz de mocks en memoria sin lanzar excepciones no controladas. | Certificación en `Test-HardwareTopologyMocks.ps1`. |

---

## 4. Ciberseguridad, Cadena de Suministro y Ring-0

| Restricción | Umbral Exigido | Justificación Técnica |
| :--- | :--- | :--- |
| **Driver Blocklist de Microsoft** | `VulnerableDriverBlocklistEnable = 1` en `HKLM\SYSTEM\CurrentControlSet\Control\CI\Config`. | Requisito innegociable de Riot Vanguard, Easy Anti-Cheat y BattlEye contra vectores BYOVD. |
| **Protección LSA** | `RunAsPPL = 1` y `RunAsPPLBoot = 2` en `HKLM\SYSTEM\CurrentControlSet\Control\Lsa`. | Blindaje de credenciales en memoria contra ataques LSASS. |
| **Firmas Digitales de Binarios** | 100% de binarios externos ejecutables en `bin/` deben poseer firma Authenticode válida. | Inspección criptográfica SHA-256 / Sigcheck. |
| **Resiliencia de Registro** | Las políticas aplicadas en WIM offline deben sobrevivir a la fase OOBE (*Hive Drift Resilience*). | Certificación en `Test-RegistryHiveDrift.ps1`. |

---

## 5. Gobernanza del Agente y Certeza Empírica (Anti-Racionalización)

1. **Veredicto Determinista Obligatorio:** Ninguna tarea, plan o commit se declarará completado sin ejecutar `Invoke-RomanOSHarness.ps1` y obtener `Exit Code 0` con un cumplimiento del 100%.
2. **Cero Complacencia y Cero Suposiciones:** Si un archivo binario (`.iso`, `.wim`) no existe en disco, se reportará estrictamente como `PENDIENTE (No generado en disco)`.
3. **Manejo de Privilegios del Host:** Ante operaciones que requieran privilegios de Administrador (DISM, Hyper-V), el agente declarará el estado `BLOQUEADO POR FALTA DE ELEVACIÓN`, especificando el script `.cmd` con elevación UAC que el usuario debe ejecutar en el host.
4. **Protocolo Stop-the-Line:** Ante un fallo del arnés, se prohíbe añadir código nuevo; la prioridad absoluta es reparar la causa raíz mediante el triaje en 5 pasos.
