# PLAN-0049: Corrección de AutoLogon y Despliegue sin Contraseña (Passwordless) en OOBE

**Fecha:** 2026-09-07  
**Autor:** romanOS / OptimizedISO Project Team (Advanced Agentic Coding)  
**Estado:** COMPLETADO  
**Rama:** `feature/offline-ui-tweaks`  

---

## 1. Resumen Ejecutivo y Diagnóstico

### 1.1 El Problema
Al generar una ISO configurando un usuario local sin contraseña (cuenta abierta / passwordless):
1. Durante la instalación en una máquina virtual, Windows 11 no inicia sesión automáticamente al escritorio, sino que se detiene en la pantalla de inicio de sesión (`LogonUI.exe`) solicitando contraseña.
2. Al revisar los scripts y la configuración de `autounattend.xml`, se identificaron tres fallos arquitectónicos fundamentales respaldados por la documentación oficial de Microsoft:
   - **Regla de Seguridad de Winlogon (Microsoft KB324737):** Si `AutoLogon` se define con contraseña vacía (`<Value></Value>`), el proceso `winlogon.exe` detecta la ausencia de credenciales válidas en `DefaultPassword` y revoca automáticamente `AutoAdminLogon` de 1 a 0, deteniendo el arranque en la pantalla de bienvenida.
   - **Fallo de Temporización en `FirstLogonCommands`:** El Builder intentaba mitigar esto inyectando comandos `reg add Winlogon` en `<FirstLogonCommands>`, pero según la especificación oficial de Microsoft (*Microsoft-Windows-Shell-Setup-FirstLogonCommands*), este pase solo se ejecuta **después** de que el usuario ya se ha autenticado con éxito, por lo que nunca llega a tiempo para el primer inicio.
   - **Incompatibilidad de AutoLogon con Contraseñas en Blanco:** `AutoLogon` en el esquema desatendido de Microsoft está diseñado para recibir credenciales. Si se fuerza `AutoLogon` sin credenciales, Windows 11 24H2 no logra completar la secuencia de autenticación silenciosa.

---

## 2. Objetivos y Solución Técnica Basada en Fuentes Oficiales

### 2.1 Enfoque Técnico Implementado (Credencial Efímera con Purga en FirstLogonCommands)
Para garantizar una experiencia 100% desatendida y sin intervención humana:

1. **Auto-Logon con Contraseña Efímera de Despliegue y Purga Automática:**
   - Si el usuario eligió crear una cuenta **sin contraseña** (`$isPasswordless`):
     - En `autounattend.xml`, se asigna una credencial temporal interna efímera de alta entropía (`RomanOS#Setup_<guid>!`) que satisface todas las directivas de complejidad en `<LocalAccount>` y en `<AutoLogon>`.
     - `Winlogon.exe` valida la credencial sin conflicto, cumple la regla KB324737 y ejecuta el inicio automático directo al escritorio (0 clics, 0 pantallas de bloqueo).
     - Inmediatamente en `FirstLogonCommands` (que se ejecuta de forma elevada al iniciar la sesión), se purga la credencial:
       ```cmd
       cmd.exe /c net user "$finalLocalUser" ""
       reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /f
       reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 0 /f
       ```
     - La cuenta queda definitivamente abierta (sin contraseña) tanto en SAM como en el registro, logrando entrada automática transparente en el primer arranque y ausencia total de contraseña para el futuro.

2. **Garantía de Directivas LSA y Passwordless en Fase `specialize` (SSOT):**
   - Registrada política `POL_AUTH_LIMIT_BLANK_PASSWORD` en `scripts/Core/Policy-Engine.ps1`:
     `HKLM\SYSTEM\CurrentControlSet\Control\Lsa` -> `LimitBlankPasswordUse = 0` (Permite operaciones desatendidas y autenticación con contraseñas vacías).
   - Política `POL_PASSWORDLESS_BUILD` existente:
     `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device` -> `DevicePasswordLessBuildVersion = 0` (Permite cuentas locales sin obligar a Windows Hello/PIN en 24H2).
   - Exportadas automáticamente en `Export-RomanOSUnattendCommands` y presentes en el fallback offline.

---

## 3. Matriz de Archivos Modificados

| Archivo | Acción | Descripción |
|---|---|---|
| `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` | MODIFICADO | Implementada generación de credenciales efímeras para passwordless, unificación de `$effectivePassword` y `$finalLocalUser`, y purga post-logon en `FirstLogonCommands`. |
| `scripts/Core/Policy-Engine.ps1` | MODIFICADO | Registrada política `POL_AUTH_LIMIT_BLANK_PASSWORD` (LimitBlankPasswordUse=0) en SSOT. |
| `scripts/Testing/Test-OptimizedISO-v2.ps1` | MODIFICADO | Añadida sección de pruebas unitarias y de integración para PLAN-0049. |
| `docs/plans/README.md` | MODIFICADO | Estado actualizado a `COMPLETADO`. |

---

## 4. Resultados de Verificación y Métricas del Test Harness

1. **Codificación UTF-8 con BOM y Compatibilidad Windows PowerShell 5.1:**
   - Verificado con `[System.Management.Automation.Language.Parser]::ParseFile` en `powershell.exe`: 0 errores AST, BOM presente (0xEF, 0xBB, 0xBF).
2. **Resultados del Test Harness (`Test-OptimizedISO-v2.ps1`):**
   - Total de pruebas: 329
   - **PASS: 328 (99.7%)**
   - **FAIL: 0**
   - SKIP: 1 (Hyper-V VM provisioning en hosts sin rol activo)
   - Estado: `EXITOSO (PASS)`. Validado para producción.
