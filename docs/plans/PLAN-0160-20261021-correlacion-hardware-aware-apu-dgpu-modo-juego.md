# PLAN-0160: Correlación Cruzada CPU-GPU Hardware-Aware para APUs AMD con GPU Dedicada PCIe en Modo Juego

**Fecha:** 2026-10-21  
**Estado:** COMPLETADO  
**Tipo:** Corrección Arquitectónica / Mejora de Inteligencia de Hardware  
**Área:** `scripts/Core/Hardware-Engine.ps1`, `scripts/Modules/Switch-GameDevMode.ps1`, `scripts/Testing/Test-CpuSiliconTopologyMocks.ps1`

---

## 1. Contexto y Diagnóstico del Defecto

Durante la auditoría empírica del log de ejecución de **Modo Juego** en un equipo con procesador **AMD Ryzen 5 8600G** y tarjeta gráfica **NVIDIA GeForce RTX 3070**, se identificó un defecto de desacoplamiento de componentes (*siloed subsystem logic*):

1. **Detección Aislada:** El motor detectó correctamente la GPU dedicada (`NVIDIA GeForce RTX 3070`, `$hasDedicatedGpu = $true`) y protegió su servicio `nvagent`.
2. **Defecto de Clasificación de CPU:** En la clasificación polimórfica de silicio ([`Hardware-Engine.ps1`](file:///c:/OptimizedISO/scripts/Core/Hardware-Engine.ps1#L725)), el clasificador evaluó la CPU de forma miope:
   ```powershell
   } elseif ($cpuVendor -eq 'AMD' -and ($hasIntegratedGpu -or $hasRdna3Igpu -or $cpuName -match 'Ryzen.*[0-9]{4}G|Athlon.*[0-9]{3}G')) {
       $archFamily = 'AMD_Monolithic_APU_UMA'
   ```
   Al detectar la subcadena `8600G` mediante regex, asumió automáticamente que todo el sistema opera en modo APU con memoria compartida (UMA) bajo un paquete térmico de 65W compartido con los gráficos integrados.
3. **Impacto Técnico Negativo:**
   - Asignó `EnergyPerformancePreference = 33%` (en vez de `0%`), frenando artificialmente la agresividad del boost mononúcleo/multinúcleo *Precision Boost 2* de los 6 núcleos Zen 4.
   - Mostró diagnósticos anacrónicos de "VRAM APU" y "Memoria UMA" en una máquina que dispone de 8 GB GDDR6 dedicados sobre bus PCIe.

---

## 2. Objetivos de Ingeniería

1. **Correlación Cruzada en SSOT (`Hardware-Engine.ps1`):** Condicionar la familia `AMD_Monolithic_APU_UMA` estrictamente a sistemas donde **NO** haya una GPU dedicada activa (`-not $hasDedicatedGpu`).
2. **Reclasificación Óptima:** Si una APU AMD (serie `G`) cuenta con GPU dedicada activa (`$hasDedicatedGpu = $true`), clasificarla como **`AMD_Zen_Modern_Symmetric`** (`EPP = 0`, `Win32PrioritySeparation = 38`, `CoreParkingPolicy = UnparkAll`, `ProcThrottleMinPercent = 5`), liberando el 100% del TDP para los núcleos de cómputo Zen.
3. **Dinamismo en Diagnósticos y UI (`Switch-GameDevMode.ps1`):** Erradicar cadenas hardcodeadas de "VRAM APU", mostrando información adaptada a GPU dedicada o APU según corresponda.
4. **Validación Multi-Hardware Sintética (`Test-CpuSiliconTopologyMocks.ps1`):** Incorporar el arquetipo Caso 7 (Ryzen 5 8600G + RTX 3070) con certificación 100% PASS en Windows PowerShell 5.1.

---

## 3. Plan de Acción y Tareas

- [x] **Fase 0 — Análisis de Causa Raíz y Validación de Git**
- [x] **Fase 1 — Refactorización del SSOT en `Hardware-Engine.ps1`**
  - Condicionar `AMD_Monolithic_APU_UMA` a `-not $hasDedicatedGpu`.
  - Enrutar APUs con dGPU hacia `AMD_Zen_Modern_Symmetric` con display name y rationale contextual.
  - Sincronizar función `Get-RomanOSCpuArchitecturePolicy`.
- [x] **Fase 2 — Dinamización de Mensajería en `Switch-GameDevMode.ps1`**
  - Ajustar etiquetas de "VRAM APU" y "Memoria UMA" según `$script:IsApuUmaActive`.
- [x] **Fase 3 — Arnés de Pruebas y Certificación Sintética**
  - Actualizar `New-MockHardwareProfile` en `Test-CpuSiliconTopologyMocks.ps1` con parámetro `$HasDedicatedGpu`.
  - Añadir Caso 7 formal: Ryzen 5 8600G + NVIDIA GeForce RTX 3070.
  - Ejecutar suite en `powershell.exe` (Windows PowerShell 5.1): 25/25 aserciones PASS.
- [x] **Fase 4 — Prueba en Vivo en Host y Cierre de Plan**
  - Ejecutar `Switch-GameDevMode.ps1 -Mode Status` en el host real: comprobada reclasificación a Zen Simétrico con EPP=0 y etiquetas de memoria del sistema.
  - Ejecutar `Test-FunctionalContracts.ps1`: 109/109 contratos PASS (100%).
  - Commit atómico y actualización de `README.md`.
