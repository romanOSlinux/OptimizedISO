# PLAN-0014: Optimización de Inteligencia, Idempotencia Avanzada y Detección de ISO en Win11-Debloat-v3-Adaptive

## 1. Estado y Metadatos
- **ID:** `PLAN-0014`
- **Fecha:** `2026-08-31`
- **Autor:** Antigravity AI
- **Estado:** `COMPLETADO`
- **Impacto:** Alto (Experiencia de usuario, velocidad de ejecución, cero redundancia post-instalación de ISO).

---

## 2. Contexto y Objetivos
`Win11-Debloat-v3-Adaptive.ps1` se ejecuta como optimizador post-instalación en sistemas recién instalados con la ISO de OptimizedISO. Aunque ya poseía detección inteligente en paquetes AppX (`DISM /Get-ProvisionedAppxPackages`) y Runtimes, existían áreas con re-escrituras redundantes o menús interactivos que mostraban elementos ya deshabilitados por `SetupComplete.cmd` o la ISO.

Objetivos de esta optimización:
1. **Inteligencia en `Set-Reg`:** Comprobar si la clave y valor ya coinciden exactamente antes de realizar operaciones de exportación o re-escritura en el registro.
2. **Filtrado Inteligente de Servicios (Sección 8):** Evaluar el `StartType` en tiempo real de cada servicio. Si todos los servicios seleccionados ya están en estado `Disabled` (por la ISO), omitir la ventana interactiva y reportar `[✓] Todos los servicios innecesarios ya están deshabilitados`. Si quedan servicios activos, mostrar únicamente los que requieren acción.
3. **Detección Inteligente de Apps Win32 (Sección 2):** Comprobar la existencia real de OneDrive, Teams Machine-Wide y Skype en el disco/registro antes de abrir menús o invocar desinstalaciones en Winget.
4. **Optimización de Navegadores (Sección 16):** Detectar si las políticas GPO ya están presentes en `HKLM` (inyectadas por `SetupComplete.cmd`) para evitar llamadas redundantes.
5. **Aprovechamiento Integral de `$isIsoOptimized`:** Integrar la variable en el flujo de ejecución para informar con total transparencia y omitir tareas redundantes.

---

## 3. Plan de Modificaciones

### 3.1. `Set-Reg` con Detección de Valor Existente
- Leer la propiedad antes de escribir. Si el valor actual es idéntico al valor objetivo, retornar inmediatamente sin generar I/O de disco ni tocar el registro.

### 3.2. Sección 2 (Win32 Apps)
- Comprobar ejecutables y claves de desinstalación (`UninstallString` en `HKLM/HKCU`). Si ninguna app está presente, saltar con mensaje limpio.

### 3.3. Sección 8 (Servicios y Tareas)
- Filtrar `$servicesList` con `Where-Object { $svc = Get-Service $_.Name -EA SilentlyContinue; $svc -and $svc.StartType -ne 'Disabled' }`. Si el conteo es 0, saltar la sección automáticamente.

### 3.4. Sección 16 (Debloat de Navegadores)
- Comprobar si `HKLM:\SOFTWARE\Policies\Microsoft\Edge\HardwareAccelerationModeEnabled` ya existe y tiene el valor esperado. Si las directivas ya están inyectadas, reportar éxito inmediato.

---

## 4. Plan de Verificación
- Ejecutar `Test-ScriptAstAndBom.ps1` en Windows PowerShell 5.1.
- Comprobar que no haya errores de sintaxis ni de codificación.
- Registrar commit atómico y actualizar `MEMORY.md`.
