# Referencia Canónica: Invariantes Multi-Hardware (romanOS)

Este documento es una referencia desacoplada consultada bajo demanda por los módulos de optimización y el arnés de evaluación.

## 1. Topología de Procesadores (CPU)
- **Intel Híbrido (12th-14th+ Gen con P-Cores y E-Cores):**
  - Prohibido forzar `Win32PrioritySeparation = 38 (0x26)` estático. Rompe la afinidad dinámica de Intel Thread Director.
  - Valor permitido: Dinámico o fallback por defecto del sistema (`2`).
- **AMD Ryzen con 3D V-Cache (Dual-CCD, ej. 7900X3D, 7950X3D):**
  - Prohibido anular el servicio AMD PPM o forzar afinidades estáticas que impidan el aparcamiento dinámico de núcleos (*Core Parking Driver*) en el CCD con caché 3D apilada.

## 2. Topología de Gráficos y Memoria (GPU / RAM)
- **APU / iGPU con Memoria Compartida (UMA):**
  - Invariante obligatoria: `LargeSystemCache = 0`.
  - Justificación: Un caché de sistema grande bloquea páginas de RAM para E/S de archivos, asfixiando el pool de texturas compartido de la GPU integrada.
- **dGPU con VRAM Dedicada (NVIDIA GeForce / AMD Radeon / Intel Arc):**
  - `LargeSystemCache = 1` permitido condicionado a RAM total >= 16 GB.
  - HAGS (`HwSchMode = 2`) permitido solo en controladores WDDM 2.7+.

## 3. Topología de Almacenamiento
- **Detección Volumen por Volumen:**
  - `Disable8dot3 = 1` e indexación selectiva en NVMe PCIe 4.0/5.0.
  - Prohibido desactivar indexación de búsqueda o búferes de lectura globalmente en volúmenes clasificados como HDD mecánico SATA.
