# PLAN-0064: Arquitectura Unificada GUI-Engine y Desacoplamiento de romanOS Suite

**Fecha:** 2026-09-09  
**Estado:** COMPLETADO  
**Área:** Arquitectura de Software, Desacoplamiento GUI/CLI, Interfaz Gráfica (WPF), Ecosistema romanOS  
**Fuente de Verdad (SSOT):** `scripts/Core/Policy-Engine.ps1`, `docs/plans/PLAN-0064-20260909-arquitectura-unificada-gui-engine-romanos-suite.md`  

---

## 1. Diagnóstico Forense y Causa Raíz

### 1.1 El Problema Observado
Al presionar **"Compilar ISO"** en la GUI `romanOS-Studio.ps1`, la consola mostraba únicamente `Iniciando compilacion de romanOS...` y el proceso quedaba congelado de forma indefinida con consumo de CPU residual (0.64s en más de 3 minutos). Al pulsar "Cancelar", el subproceso terminaba abruptamente.

### 1.2 Hallazgos Forenses y Pruebas Empíricas
Mediante una inspección profunda del código fuente, tokens de seguridad de Windows y los registros de proceso, se identificaron **cuatro causas estructurales incompatibles con una GUI**:

1. **Invocación No Elevada (Barrera UAC de Windows):**
   - El proceso de la GUI (`PID 6384`) se estaba ejecutando en contexto de usuario estándar (`IsElevated: False`).
   - Al lanzar `System.Diagnostics.Process` con `UseShellExecute = $false`, Windows **no puede solicitar elevación por UAC**.
   - `New-OptimizedWindowsISO-v2.ps1` contiene `#Requires -RunAsAdministrator` en la línea 1 y `Test-Admin` en la línea 3774. Sin elevación, DISM, `Mount-DiskImage` y la inyección offline fallan de inmediato o se bloquean.
2. **Acoplamiento Directo a `Read-Host` en el Flujo Principal:**
   - La auditoría en frío reveló más de 20 llamadas a `Read-Host` y `Out-GridView` dentro de `New-OptimizedWindowsISO-v2.ps1`:
     - **Línea 4098:** `$choice = Read-Host "  Seleccione una opción (Default: 1)"` (Inyección de scripts: Toolkit, Debloat, Security).
     - **Línea 5345:** `$choice = Read-Host "    Seleccione una opción (ENTER = TODAS)"` (Selección de índice WIM).
     - **Línea 6037:** `$consoleChoice = Read-Host "    Selección"` (Selección manual de Debloat).
   - En una sesión de segundo plano oculta y redirigida, `Read-Host` no tiene teclado ni consola conectada; entra en espera de `stdin` de forma perpetua (**Deadlock de E/S**).
3. **Punto Ciego en el Test Harness (`Test-OptimizedISO-v2.ps1`):**
   - Los tests automáticos (523 tests pasados) nunca detectaron este congelamiento porque en la línea 237 de `Test-OptimizedISO-v2.ps1` se definió un mock global:
     `function global:Read-Host { ... }`.
   - En el entorno de pruebas, `Read-Host` estaba anulado artificialmente; en la GUI de producción real, no lo estaba.
4. **Acoplamiento en Todo el Ecosistema romanOS:**
   - `Win11-Debloat-v3-Adaptive.ps1` posee 25 llamadas a `Out-GridView` y `Read-Host`.
   - `romanOS-Toolkit.ps1` posee 26 llamadas a `pause`.
   - Ninguno de estos scripts puede ser orquestado por una GUI moderna si mantienen llamadas interactivas bloqueantes incrustadas en la lógica de negocio.

---

## 2. Investigación en Fuentes Oficiales de Microsoft

De acuerdo con la documentación técnica oficial de **Microsoft Learn** y los estándares de arquitectura para PowerShell y .NET:
- **Separación de Responsabilidades (Three-Tier Architecture en PowerShell):**
  - **Capa de Lógica de Negocio (Engine / Headless):** Debe ser puramente agnóstica de la interfaz. *Nunca debe invocar `Read-Host`, `Write-Host`, `Out-GridView` ni `pause`*. Recibe todos sus parámetros a través de un contrato fuertemente tipado (Objeto / Archivo JSON).
  - **Capa de Presentación CLI (Terminal Wizard):** Un script interactivo ligero que pregunta al usuario por consola cuando faltan parámetros, construye el contrato de configuración y llama al Motor.
  - **Capa de Presentación GUI (romanOS Studio / Suite):** Una interfaz WPF que captura visualmente las opciones del usuario, valida rutas con diálogos de Windows, genera el contrato de configuración idéntico y comanda al Motor.
- **Manejo de Elevación en Aplicaciones de Gestión del Sistema:**
  - Herramientas nativas de Windows que interactúan con DISM y drivers (como Rufus, Ventoy o el instalador de Windows ADK) deben solicitar elevación de privilegios desde el arranque (manifiesto `requireAdministrator` o relanzamiento `-Verb RunAs`).

---

## 3. Decisión Técnica de Arquitectura (Ingeniería de Software)

En cumplimiento de la **Regla 11 (Autonomía y Autoridad en Decisiones Técnicas Base)**, se adopta la siguiente arquitectura canónica:

```
                  ┌──────────────────────────────────────────────┐
                  │           romanOS Studio (GUI WPF)           │
                  │   (Elevado como Admin desde el arranque)     │
                  └──────────────────────┬───────────────────────┘
                                         │ Genera
                                         ▼
                  ┌──────────────────────────────────────────────┐
                  │         BuildPreset Contract (.json)         │
                  │   (Esquema SSOT de configuración completa)   │
                  └──────────────────────┬───────────────────────┘
                                         │ Pasa como argumento
                                         ▼
                  ┌──────────────────────────────────────────────┐
                  │       Motor Headless (Engine Desacoplado)    │
                  │  - PresetFile como fuente primaria           │
                  │  - Bypasses garantizados (cero Read-Host)    │
                  │  - Telemetría por streams hacia la GUI       │
                  └──────────────────────┬───────────────────────┘
                                         │ Despliega
                                         ▼
            ┌────────────────────────────┼───────────────────────────┐
            ▼                            ▼                           ▼
   New-OptimizedWindowsISO     Win11-Debloat-v3-Adaptive     romanOS-Toolkit
      (Modo Headless)               (Modo Headless)           (Modo Headless)
```

### Componentes de la Solución:

1. **Auto-Elevación Mandatoria en `romanOS-Studio.ps1`:**
   - La GUI verificará si corre con privilegios de Administrador al abrirse. Si no lo está, se relanzará a sí misma con elevación (`Start-Process powershell -Verb RunAs`). Así se garantiza que cualquier subproceso o comando DISM tenga los permisos necesarios.
2. **Saneamiento Headless Total en `New-OptimizedWindowsISO-v2.ps1`:**
   - Implementar un interceptor condicional o resolución en los puntos críticos identificados (líneas 4098, 5345, 6037):
     - Si `$Headless` o `$PresetFile` está activo, **nunca ejecutar `Read-Host` ni `Out-GridView`**.
     - Tomar el valor inyectado en el JSON o el default automático predeterminado.
3. **Contrato de Ecosistema Headless para Debloat y Toolkit:**
   - Estandarizar el parámetro `[switch]$Headless` y soporte de presets en los scripts satélite (`Win11-Debloat-v3-Adaptive.ps1`, `romanOS-Toolkit.ps1`), permitiendo que la GUI ejecute optimizaciones directas sin diálogos bloqueantes.
4. **Canal de Telemetría Seguro entre GUI y Motor:**
   - El proceso de compilación enviará los eventos de progreso mediante flujos de salida procesados en tiempo real, evitando saturación de búfer de Windows.

---

## 4. Plan de Implementación por Fases

### Fase 1: Garantía de Elevación en la GUI
- Modificar el punto de entrada de `scripts/GUI/romanOS-Studio.ps1` para requerir y forzar elevación automática si el usuario hace doble clic sin privilegios administrativos.

### Fase 2: Erradicación de Bloqueos en `New-OptimizedWindowsISO-v2.ps1`
- Auditar y proteger todas las llamadas a `Read-Host` y `Out-GridView` en el flujo principal:
  - Paso de selección de scripts a inyectar (Línea 4098): si `$Headless`, inyectar la Suite Completa (opción 1) o la configuración declarada en el Preset JSON.
  - Paso de selección de índice WIM (Línea 5345): si `$Headless`, respetar `$TargetWimIndex` o procesar todos los índices por defecto.
  - Paso de selección de Debloat offline (Línea 6037): si `$Headless`, aplicar el perfil seleccionado (Conservador, Gaming, Hardcore) sin abrir `Out-GridView` ni pedir consola.

### Fase 3: Paridad del Ecosistema (Debloat y Toolkit)
- Asegurar que cuando el instalador inyecte `Win11-Debloat-v3-Adaptive.ps1` en OOBE o post-instalación, opere con el switch `-Unattended` o `-Headless` sin esperar teclas del usuario.

### Fase 4: Pruebas de Verificación y Validación Empírica
- Ejecutar una prueba controlada desde `romanOS-Studio.ps1` con la ISO `Win11_25H2_Spanish_x64_v2.iso`.
- Verificar en vivo que la consola de la GUI reciba los logs de DISM y las políticas de `Policy-Engine.ps1` sin ningún congelamiento.
- Ejecutar la suite completa de pruebas unitarias (`Invoke-TestSuite.ps1`) asegurando 0 regresiones.

---

## 5. Trazabilidad y Cumplimiento de Reglas
- **Regla 4:** Todo script nuevo o editado mantendrá codificación UTF-8 con BOM y compatibilidad con Windows PowerShell 5.1.
- **Regla 8:** No se realizarán cambios destructivos ni modificaciones de código hasta recibir la aprobación expresa del usuario.
