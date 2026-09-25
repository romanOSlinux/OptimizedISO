# PLAN-0113: Erradicación Integral de Bloqueos de Consola en GUIs (StandardInput Redirection & Parámetro Unattended)

## Metadatos
- **ID:** PLAN-0113
- **Fecha:** 2026-09-24
- **Título:** Erradicación Integral de Bloqueos de Consola en GUIs (StandardInput Redirection, Cierre Inmediato y Modo Desatendido Transversal)
- **Estado:** COMPLETADO
- **Autor:** romanOS Core Engineering Team / Antigravity
- **Hito Asociado:** Saneamiento UX / Estabilidad de Subprocesos Asíncronos
- **Reglas Aplicables:** Regla 0 (Git), Regla 4 (UTF-8 BOM en PS 5.1), Regla 5 (Trazabilidad Planes), Regla 8 (No Auto-Run), Regla 9 (SSOT), Regla 13 (Auditoría Holística y Fail-Visible)

---

## 1. Contexto y Diagnóstico Forense

### 1.1 El Problema Reportado
Al invocar acciones desde la interfaz gráfica `romanOS Control Center` (específicamente la acción *"Poda de Memoria RAM (Working Set)"* y módulos análogos), la consola de registro en vivo se detiene indefinidamente tras mostrar:
```text
TOTAL MEMORIA PODADA : 629,51 MB recuperados (100% de reduccion)
================================================================
Presione cualquier tecla para continuar...
```
La barra de progreso de la GUI permanece en animación indeterminada infinita, el subproceso secundario no finaliza, y la interfaz queda a la espera de una entrada de teclado imposible de suministrar dado que el proceso hijo se ejecuta en segundo plano sin ventana propia (`CreateNoWindow = $true`).

### 1.2 Análisis Forense de Causa Raíz
Una auditoría estructural en `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/GUI/romanOS-Studio.ps1` y los módulos consumidores reveló una triple vulnerabilidad concurrente:

1. **Deficiencia en el Lanzador de Procesos (`Start-ControlCenterTask` y `Start-StudioSubProcess`):**
   - La propiedad `$pinfo.RedirectStandardInput` se encontraba omitida (por defecto `$false` en .NET).
   - En .NET Framework y Windows PowerShell 5.1, cuando `RedirectStandardInput` es falso, la propiedad `[System.Console]::IsInputRedirected` dentro del proceso hijo retorna `$false`, a pesar de correr sin ventana o consola asignada.
   - En consecuencia, las comprobaciones de guardia en los scripts (`if (-not [System.Console]::IsInputRedirected)`) asumen erróneamente que la sesión es interactiva y ejecutan `[System.Console]::ReadKey($true)` o `pause`.
   - Adicionalmente, el ejecutable `powershell.exe` se invocaba sin el parámetro `-NonInteractive`.

2. **Omisión del Switch `-Unattended` en Handlers de Botones de la GUI:**
   - En `romanOS-ControlCenter.ps1`, el botón `btnQuickTrim` (Línea 1069) invocaba `Optimize-ProcessMemory.ps1` sin el flag `-Unattended`.
   - Handlers de conmutación de juego (`btnGameAggressive`, `btnGameLight`, `btnDevMode`) y de afinidad de interrupciones (`btnQuickAffinity`, `btnAffinityBalanced`, `btnAffinityReset`) tampoco pasaban `-Unattended`.

3. **Inconsistencia de Guardas de Interacción en Scripts:**
   - En `Optimize-ProcessMemory.ps1` (Líneas 251-256) y `Switch-GameDevMode.ps1` (Líneas 413, 617, 733), la condición de pausa evaluaba solo `(-not $Unattended -and -not [System.Console]::IsInputRedirected)`, sin contemplar defensas en profundidad ante handles stdin cerrados o entornos no interactivos.

---

## 2. Solución Arquitectónica (Estrategia en Profundidad)

Para garantizar un aislamiento 100% hermético contra bloqueos sin alterar el comportamiento de los scripts cuando el usuario los invoque manualmente desde un terminal interactivo, se implementa una solución de cuatro capas:

### Capa 1: Blindaje en los Motores Lanzadores de GUIs (`romanOS-ControlCenter.ps1` y `romanOS-Studio.ps1`)
- Forzar `$pinfo.RedirectStandardInput = $true` en `ProcessStartInfo`.
- Inyectar el argumento `-NonInteractive` en la invocación de `powershell.exe`.
- Inmediatamente tras `proc.Start()`, ejecutar `$proc.StandardInput.Close()`. Esto envía un fin de archivo (EOF) inmediato a cualquier comando que intente leer entrada estándar, evitando bloqueos por `Read-Host`, `ReadKey` o `pause`.

### Capa 2: Paridad de Modos Desatendidos en Handlers de Botones
- Revisar y asegurar que toda invocación a scripts de la suite desde `romanOS-ControlCenter.ps1` suministre explícitamente `-Unattended` (o `-NonInteractive` según la firma del script).
- Botones objetivo:
  - `btnQuickTrim` -> `-Unattended`
  - `btnGameAggressive`, `btnGameLight`, `btnDevMode` -> `-Unattended`
  - `btnQuickAffinity`, `btnAffinityBalanced`, `btnAffinityReset` -> `-Unattended`
  - `btnBrowsersAll`, `btnEdge`, `btnChrome`, `btnBrave`, `btnFirefox` -> `-Unattended`

### Capa 3: Refuerzo en las Guardas de Pausa de los Módulos
- Actualizar `Optimize-ProcessMemory.ps1` y `Switch-GameDevMode.ps1` para requerir explícitamente:
  `if (-not $Unattended -and -not $Quiet -and [System.Environment]::UserInteractive -and -not [System.Console]::IsInputRedirected)`
- Envolver cualquier `ReadKey` en bloque `try/catch` con salida limpia y sin espera en caso de excepción de consola redirigida.

### Capa 4: Verificación Integral en Windows PowerShell 5.1 y Suite de Pruebas
- Probar en frío contra `powershell.exe -STA -NoProfile` la ejecución de `btnQuickTrim` y verificar que el proceso hijo finalice en < 2 segundos con código de salida `0` y liberación inmediata de la GUI.
- Ejecutar `Test-GuiIntegrityAndFunctionality.ps1` para validar que ningún botón resulte afectado negativamente.

---

## 3. Plan de Acción Detallado

| Paso | Archivo(s) | Acción |
|---|---|---|
| **1** | `scripts/GUI/romanOS-ControlCenter.ps1` | Modificar `Start-ControlCenterTask`: agregar `RedirectStandardInput = $true`, `$proc.StandardInput.Close()`, `-NonInteractive`. |
| **2** | `scripts/GUI/romanOS-Studio.ps1` | Modificar `Start-StudioSubProcess`: agregar `RedirectStandardInput = $true`, `$proc.StandardInput.Close()`, `-NonInteractive`. |
| **3** | `scripts/GUI/romanOS-ControlCenter.ps1` | Agregar `-Unattended` en handlers de `btnQuickTrim`, modos de juego (`Switch-GameDevMode.ps1`), optimización de afinidad (`Optimize-InterruptAffinity.ps1`) y navegadores (`Optimize-WebBrowsers.ps1`). |
| **4** | `scripts/Modules/Optimize-ProcessMemory.ps1` | Blindar guarda de pausa final con `[System.Environment]::UserInteractive` y control de redirección. |
| **5** | `scripts/Modules/Switch-GameDevMode.ps1` | Blindar guardas de pausa en modo Status, Game y Dev. |
| **6** | `scripts/Testing/Test-GuiIntegrityAndFunctionality.ps1` | Validar compatibilidad e integridad de todos los botones de ambas GUIs. |
| **7** | UTF-8 BOM Audit | Comprobar codificación UTF-8 con BOM en todos los archivos `.ps1` modificados. |

---

## 4. Criterios de Aceptación y Validación Empírica
1. Al presionar "Poda de Memoria RAM" en `romanOS-ControlCenter.ps1`, el script realiza la poda, reporta la métrica, **no muestra el mensaje de pausa**, y finaliza con éxito en la consola en vivo con retorno del indicador a estado reposo.
2. Al ejecutar scripts desde la consola de Windows PowerShell de manera manual (fuera de la GUI), la experiencia interactiva estándar se mantiene íntegra para el usuario.
3. El test harness `Test-GuiIntegrityAndFunctionality.ps1` aprueba al 100% sin regresiones.
