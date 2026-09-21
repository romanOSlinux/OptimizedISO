# PLAN-0091: Auditoría Integral y Certificación de Preparación para Producción del Ecosistema romanOS / OptimizedISO

**Estado:** COMPLETADO  
**Fecha:** 2026-09-21  
**Autor:** romanOS Engineering Team  
**Área:** Aseguramiento de Calidad (QA), Arquitectura de Despliegue, Servicing, Seguridad y Gobernanza de Código  
**Referencias Oficiales:**
- Microsoft Learn: *Windows 11 Deployment and Servicing Best Practices* (22H2 / 23H2 / 24H2 / 25H2)
- Microsoft Learn: *PSScriptAnalyzer Static Code Analysis Rule Reference* (Rules: Error, Warning, Security)
- Microsoft Learn: *Unattended Windows Setup Reference (autounattend.xml Schema)*
- DMTF Standard: *DSP0134 SMBIOS System Management BIOS Reference Specification v3.7.0*
- PCI-SIG: *PCI-SIG Vendor ID & MSI/MSI-X Bus Specification*
- Microsoft Learn: *Windows PowerShell 5.1 Host Compatibility and AST Engine*

---

## 1. Justificación y Fundamento de Ingeniería

Antes de declarar un ecosistema de generación de sistemas operativos y optimización como "Listo para Producción", la disciplina de ingeniería de software exige una auditoría exhaustiva, reproducible y basada en datos empíricos objetivos, en conformidad con la **Regla 2 (Verificación e Investigación Rigurosa - Cero Suposiciones)** y la **Regla 12 (Análisis Forense de Logs y Anti-Sesgo)** de `.agents/AGENTS.md`.

El ecosistema `OptimizedISO` se compone de:
1. **Motores de Núcleo (SSOT Core):** `Hardware-Engine.ps1`, `Policy-Engine.ps1`, `UI-Engine.ps1`.
2. **Generador y Servicing de Medios:** `New-OptimizedWindowsISO-v2.ps1`, `Get-WindowsUpdates.ps1`.
3. **Módulos de Sistema y Optimización:** `romanOS-Toolkit.ps1`, `Win11-Debloat-v3-Adaptive.ps1`, `Win11-Network-Diagnostics-Optimizer.ps1`, `Optimize-ProcessMemory.ps1`, `Optimize-WebBrowsers.ps1`, `Switch-GameDevMode.ps1`, `Audit-SystemOptimization.ps1`, `Audit-FreshInstallFootprint.ps1`, `PostInstall-Diagnostics.ps1`, `Trace-SystemLatency.ps1`, `Add-OptimizedContextMenus.ps1`, `Migrar-Usuario-W11.ps1`.
4. **Interfaces de Usuario Gráficas (WPF / XAML):** `romanOS-Studio.ps1`, `romanOS-ControlCenter.ps1` y sus compiladores en vuelo C# (`csc.exe /platform:anycpu`).
5. **Herramientas de Mantenimiento del Host:** `Get-OfficialWindowsISO.ps1`, `Desplegar-Setup-Host.ps1`, `Limpiar-ResiduosWinISO.ps1`, `Invoke-WindowsMaintenance.ps1`, `Clean-DriverStore.ps1`, `Backup-HardwareDrivers.ps1`.
6. **Lanzadores de Entrada por Consola:** 10 scripts por lotes `.cmd`.
7. **Arnés de Pruebas y Diagnóstico:** `Invoke-TestSuite.ps1`, `Test-OptimizedISO-v2.ps1`, `Test-HardwareEngine.ps1`, `New-TestVM-HyperV.ps1`.
8. **Plantillas de Despliegue Automatizado:** `sources/autounattend.xml`, `sources/$OEM$/`, presets de configuración JSON.

---

## 2. Dimensiones de la Auditoría Pre-Producción

### Dimensión 1: Codificación y Compatibilidad de Runtime en Frío (Windows PowerShell 5.1 & CMD)
- **Objetivo:** Verificar que el 100% de los scripts `.ps1`, `.psm1` y `.psd1` cuenten estrictamente con BOM UTF-8 (`0xEF, 0xBB, 0xBF`), garantizando que Windows PowerShell 5.1 (`powershell.exe`) no sufra corrupción de caracteres especiales ni colapso de comillas.
- **Objetivo:** Verificar que el 100% de los lanzadores `.cmd` no contengan BOM (`No-BOM` / ANSI), evitando fallos de `cmd.exe` ante `ï»¿@echo`.
- **Métrica:** 0 fallos de encoding, 0 errores sintácticos AST en `[System.Management.Automation.Language.Parser]::ParseFile`.

### Dimensión 2: Análisis Estático de Calidad y Seguridad Oficial (PSScriptAnalyzer)
- **Objetivo:** Ejecutar `Invoke-ScriptAnalyzer` sobre todo el código fuente del proyecto evaluando severidades `Error` y `ParseError`.
- **Métrica:** 0 violaciones de reglas de severidad `Error`.

### Dimensión 3: Integridad de Plantillas de Despliegue y Escape XML (autounattend.xml)
- **Objetivo:** Verificar la validez de `sources/autounattend.xml`, esquema de particionado UEFI GPT (4 particiones estándar: WinRE, ESP, MSR, Windows OS), bypasses de hardware oficial (TPM, RAM, SecureBoot, BypassNRO) y correcto escape de entidades XML (`&amp;&amp;`, `&gt;`, `&lt;`).
- **Métrica:** Parser XML nativo aprueba el documento con 0 excepciones; 0 directivas no soportadas (`<WillContinueOnFailure>`).

### Dimensión 4: Arquitectura Unificada y Paridad de Inyección (SSOT)
- **Objetivo:** Garantizar que no existan directivas de registro duplicadas o aisladas fuera de `Policy-Engine.ps1`, y que las rutas inyectadas en `$OEM$` y montadas en el WIM coincidan exactamente con la estructura del repositorio.
- **Métrica:** 0 scripts huérfanos, 100% de resolución de dependencias jerárquicas `Core/`.

### Dimensión 5: Herramientas de Entorno de Compilación Host
- **Objetivo:** Diagnosticar la disponibilidad y ejecutabilidad de las dependencias nativas del host: `dism.exe`, `oscdimg.exe` (Windows ADK), espacio en disco libre (>= 25 GB) y módulo de virtualización `Hyper-V`.
- **Métrica:** Herramientas resueltas y operativas.

### Dimensión 6: Higiene del Repositorio de Control de Versiones (Git)
- **Objetivo:** Auditar que no existan archivos binarios pesados rastreados en el árbol de Git (`.iso`, `.wim`, `.esd`, `.msu`, `.vhd`, `.vhdx`).
- **Métrica:** Cero binarios pesados rastreados; árbol limpio.

### Dimensión 7: Matriz de Certeza Empírica y Límites de Laboratorio (Regla 2)
- **Objetivo:** Establecer con transparencia absoluta qué aspectos del sistema han sido verificados empíricamente mediante pruebas de laboratorio y qué aspectos requieren validación en tiempo de ejecución en entornos físicos (bare-metal).

---

## 3. Plan de Verificación y Reporte de Salida

1. Ejecución de la batería consolidada de auditoría en frío (`Invoke-TestSuite.ps1`).
2. Escaneo automatizado de PSScriptAnalyzer sobre la totalidad de carpetas de scripts.
3. Validación de esquema XML de `sources/autounattend.xml`.
4. Emisión de informe forense de preparación para producción con checklist de certificación.
