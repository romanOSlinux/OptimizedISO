# Integración de Pilares 2 y 3 a romanOS Studio

Este plan detalla la incorporación técnica de las herramientas de despliegue rápido en Máquinas Virtuales (Hyper-V) y la higiene del sistema anfitrión, transformando la GUI en una plataforma integral.

## User Review Required

> [!IMPORTANT]
> **Decisión de Diseño Visual:**
> Dado que ambas herramientas actúan sobre tu PC local (el host), propongo crear una nueva pestaña dedicada llamada **"Herramientas del Host"** en lugar de saturar la pestaña de "Construcción Base".
> - En esta pestaña tendrás un botón para levantar la VM y otro para purgar residuos.
> 
> ¿Estás de acuerdo con agruparlos en una nueva pestaña?

## Proposed Changes

### GUI romanOS Studio (XAML & Lógica)

#### [MODIFY] [romanOS-Studio.ps1](file:///c:/OptimizedISO/scripts/GUI/romanOS-Studio.ps1)
- Inyectar un nuevo `<TabItem Header="Herramientas del Host">`.
- Añadir sección **"Laboratorio de Pruebas (Hyper-V)"** con un botón `btnTestVM`.
- Añadir sección **"Mantenimiento del Sistema"** con un botón `btnCleanHost`.
- Enlazar ambos botones al ecosistema de eventos usando el patrón asíncrono con `add_OutputDataReceived` para que la salida se muestre en tiempo real en la consola de la GUI sin congelarla.

---

### Módulo de Pruebas Rápidas (Pilar 2)

> [!NOTE]
> Tras analizar `New-TestVM-HyperV.ps1`, he verificado que **no necesitamos crearle un clon headless**. El script original ya cuenta con parámetros oficiales y cero interactividad forzada.

#### [NO CHANGES] [New-TestVM-HyperV.ps1](file:///c:/OptimizedISO/scripts/Testing/New-TestVM-HyperV.ps1)
- Se invocará directamente pasándole el parámetro `-ISOPath` enlazado al Combobox o TextBox de ISO de la GUI.

---

### Módulo de Higiene del Host (Pilar 3)

Dado que `Limpiar-ResiduosWinISO.ps1` es altamente interactivo (cuenta con un menú con opciones numéricas, confirmaciones y un bucle while), es obligatorio crear un motor dedicado para que lo pueda controlar la GUI.

#### [NEW] `scripts/Host-Tools/Limpiar-ResiduosWinISO-GUI-Engine.ps1`
- Se clonará desde `Limpiar-ResiduosWinISO.ps1`.
- Se eliminará completamente el bucle de menú interactivo `do { ... } while (-not $salir)`.
- Se reemplazará con una rutina lineal de limpieza total:
  ```powershell
  $hallazgos = Find-Residuos
  foreach ($item in $hallazgos) { Remove-Residuo -Item $item | Out-Null }
  Invoke-CleanupMountpoints
  ```
- Se guardará con codificación **UTF-8 con BOM** para garantizar que pase la auditoría (Fase 1 del TestSuite).

## Verification Plan

### Automated Tests
- Al realizar el commit, el `pre-commit-gateway` correrá la batería de pruebas asegurando que el nuevo clon (`Limpiar-ResiduosWinISO-GUI-Engine.ps1`) y la GUI superen las revisiones de AST y codificación.

### Manual Verification
- Abrir la GUI de romanOS Studio.
- Navegar a la nueva pestaña "Herramientas del Host".
- Pulsar "Limpiar Residuos" y verificar que la consola de logs refleje los borrados correctamente sin prompts.
- Pulsar "Probar ISO en VM" y verificar que levante la interfaz de `vmconnect.exe` lanzando Hyper-V.
