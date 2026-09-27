# PLAN-0121: Pilar 1 - Blindaje contra Bloqueo OEM de SetupComplete.cmd mediante Dual-Execution en autounattend.xml con FirstLogonCommands y Mutex

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0121 |
| **Fecha** | 2026-09-27 |
| **Componentes** | `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`, `sources/autounattend.xml`, `scripts/Testing/Test-OptimizedISO-v2.ps1`, `scripts/Testing/Test-FunctionalContracts.ps1` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Crítica (Resiliencia de Despliegue Universal en Laptops y PCs con Licencia OEM en BIOS) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM / PS 5.1), Regla 5 (Planes), Regla 7 (Watchdogs), Regla 8 (Modo Autónomo Continuo), Regla 9 (SSOT), Regla 10 (Cascada Docs-as-Code), Regla 13 (Auditoría Holística), Regla 14 (Salvaguarda de Almacenamiento) |

---

## 1. Visión y Justificación Técnica

### A. El Problema Técnico Documentado por Microsoft
Según la documentación oficial de Microsoft Learn (*"Add a custom script to Windows Setup"*):
> *"SetupComplete.cmd is disabled when using an OEM product key, except on Enterprise editions or Windows Server operating systems."*

En cualquier equipo OEM (laptops y equipos premontados Dell, ASUS, Lenovo, HP, etc.) donde exista una clave de producto de Windows inyectada en la tabla ACPI MSDM del BIOS/UEFI, el motor de instalación de Windows desactiva silenciosamente la ejecución de `%WINDIR%\Setup\Scripts\SetupComplete.cmd`.
Esto provoca que las directivas de personalización, instalación de runtimes C++/DirectX y diagnósticos iniciales no se ejecuten de forma desatendida.

### B. Solución de Ingeniería: Dual-Execution con Mutex Transaccional
Para garantizar paridad total sin importar el origen de la licencia:
1. **Archivo Mutex/Testigo:** `%WINDIR%\Setup\Scripts\.setup_completed`.
2. **SetupComplete.cmd:**
   - Al iniciar: comprueba si `.setup_completed` existe. Si existe, sale inmediatamente (`exit /b 0`). Si no, escribe el testigo inicial.
   - Al finalizar: actualiza `.setup_completed` con la marca de tiempo de éxito.
3. **FirstLogonCommands (`autounattend.xml` en `oobeSystem`):**
   - Agrega un comando síncrono condicional: si `%WINDIR%\Setup\Scripts\.setup_completed` no existe (lo que evidencia que `SetupComplete.cmd` fue bloqueado por clave OEM), invoca explícitamente `SetupComplete.cmd` con elevación de Administrador.
4. **Idempotencia Absoluta:**
   - Si `SetupComplete.cmd` corrió normalmente, `FirstLogonCommands` no hace nada.
   - Si `SetupComplete.cmd` fue bloqueado por OEM, se ejecuta al primer inicio de sesión sin perder ninguna optimización.

---

## 2. Fases de Implementación

- [x] **Fase 1:** Actualizar plantilla de `SetupComplete.cmd` en `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` con comprobación y escritura de mutex `.setup_completed`.
- [x] **Fase 2:** Agregar comando de contingencia OEM en `$firstLogonCommands` dentro de `New-OptimizedWindowsISO-v2.ps1` y en la plantilla estática `sources/autounattend.xml`.
- [x] **Fase 3:** Extender la suite de pruebas unitarias (`Test-OptimizedISO-v2.ps1` y `Test-FunctionalContracts.ps1` con CTR-41) para certificar la presencia del cerrojo de mutex y el comando FirstLogon de contingencia.
- [x] **Fase 4:** Validación en frío en Windows PowerShell 5.1 y registro de commit atómico.

---

## 3. Criterios de Aceptación Cuantitativos

1. **Cero Doble Ejecución:** El cerrojo mutex previene cualquier re-ejecución accidental si ambos mecanismos se dispararan.
2. **Cero Suposiciones de Edición:** El sistema funciona idénticamente en ediciones Retail, OEM, KMS y Enterprise.
3. **100% PASS en Test Suites:** Validación completa sin regresiones en el harness de pruebas.
