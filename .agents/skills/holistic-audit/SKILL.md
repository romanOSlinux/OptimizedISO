---
name: holistic-audit
description: >-
  Activate this skill when identifying systematic defects, fragile hardware assumptions,
  silent error handling (empty catch / SilentlyContinue), or when conducting repo-wide audits
  across all scripts in OptimizedISO.
---

# Auditoría Holística y Prohibición de Fallos Silenciosos (Estándar romanOS)

Protocolo de ingeniería para garantizar que ninguna corrección de error se limite a un subconjunto arbitrario de scripts y que ningún fallo sea ocultado o silenciado en el repositorio.

---

## 1. Principio de Alcance Total (Whole-Repository Scope)

Cuando se identifique un defecto conceptual o una suposición errónea en cualquier script:
1. **Identificación del Patrón:** Aislar la causa raíz abstracta (ej. asumir `DeviceID = 0`, asumir letra `C:`, filtrar solo por un proveedor de GPU, asumir NIC única, ignorar código de salida).
2. **Búsqueda Global Exhaustiva:** Escanear la **totalidad de los scripts del proyecto** (`scripts/Core`, `scripts/Builder`, `scripts/Modules`, `scripts/GUI`, `scripts/Drivers`, `scripts/Host-Tools`, `scripts/Testing`) buscando instancias similares.
3. **Prohibición de Parche Local:** Está prohibido cerrar una tarea modificando solo 1 archivo si el patrón se repite en otros scripts.

---

## 2. Política Fail-Visible (Cero Bloques Catch Mudos - CWE-390)

En alineación con el estándar MITRE CWE-390 y las guías oficiales de PowerShell PSScriptAnalyzer (`PSAvoidUsingEmptyCatchBlock`):
1. **Prohibición de `catch { }` Vacío:** Todo bloque `try / catch` que capture una excepción debe registrarla o advertirla.
2. **Formato Canónico de Advertencia en Catch:**
   ```powershell
   try {
       # Operación de sistema o consulta de hardware
   } catch {
       Write-Warning "[$ScriptName] Fallo al ejecutar '$Operacion': $($_.Exception.Message)"
       # Registrar en lista de errores o aplicar fallback explícito
   }
   ```
3. **Uso Restringido de `SilentlyContinue`:**
   - **Permitido:** Exclusivamente en cmdlets de introspección condicional no destructiva (ej. `Test-Path -ErrorAction SilentlyContinue` o `Get-Command ... -ErrorAction SilentlyContinue`).
   - **Prohibido:** En llamadas a APIs de hardware, manipulación de registro (`Set-ItemProperty`), procesos (`Start-Process`, `vssadmin`, `dism`), o particionado.

---

## 3. Comandos de Inspección Automatizada AST

Para auditar instantáneamente todos los scripts del repositorio sin omitir ninguno:

### A. Escaneo de Bloques Catch Vacíos y Silenciosos:
```powershell
& ".agents/skills/holistic-audit/scripts/Test-RepositoryCatchHygiene.ps1"
```

### B. Búsqueda de Suposiciones de Letra de Disco Fija (`C:`):
```powershell
Get-ChildItem -Path scripts -Recurse -Filter "*.ps1" | ForEach-Object {
    $matches = Select-String -Path $_.FullName -Pattern "DeviceID\s*=\s*'C:'|DriveLetter\s*=\s*'C'|/for=C:"
    if ($matches) { [PSCustomObject]@{ File = $_.Name; Matches = $matches.Count } }
}
```

---

## 4. Estándar de Reporte Cuantificado

Toda intervención bajo esta metodología debe culminar con una tabla métrica verificable:
- Scripts totales escaneados.
- Ocurrencias del defecto iniciales vs. finales (debe ser 0).
- Estado de verificación en frío con Windows PowerShell 5.1 AST.

---

## 5. Matriz de Mocks de Topología de Hardware para Pruebas Agnósticas

Para certificar que un script o módulo de optimización funcione en **cualquier hardware** sin depender de una máquina virtual pesada ni requerir permisos elevados de Hyper-V, se debe inyectar la siguiente matriz de objetos simulados (Mocks en memoria) en las pruebas unitarias:

### A. Mock: Topología Híbrida Intel (P-Cores + E-Cores / big.LITTLE)
```powershell
$mockIntelHybrid = [PSCustomObject]@{
    Manufacturer               = "GenuineIntel"
    Name                       = "13th Gen Intel(R) Core(TM) i7-13700K"
    NumberOfCores              = 16
    NumberOfLogicalProcessors  = 24
    ArchitectureType           = "Hybrid_BigLittle"
    HasHeterogeneousCores      = $true
    Has3DVCache                = $false
}
# Aseveración: El script DEBE abstenerse de modificar Win32PrioritySeparation
# para no interferir con Intel Thread Director.
```

### B. Mock: Topología AMD con 3D V-Cache (Dual-CCD Asimétrico)
```powershell
$mockAmdX3D = [PSCustomObject]@{
    Manufacturer               = "AuthenticAMD"
    Name                       = "AMD Ryzen 9 7900X3D 12-Core Processor"
    NumberOfCores              = 12
    NumberOfLogicalProcessors  = 24
    ArchitectureType           = "AMD_DualCCD_3DVCache"
    HasHeterogeneousCores      = $false
    Has3DVCache                = $true
}
# Aseveración: El script DEBE delegar el balanceo de hilos al driver oficial
# de AMD (CPPC / 3D V-Cache Performance Optimizer) sin forzar afinidades estáticas.
```

### C. Mock: Topología Gráfica Discreta (dGPU con VRAM Propia) vs APU/UMA
```powershell
$mockDedicatedGPU = [PSCustomObject]@{
    Name                  = "NVIDIA GeForce RTX 4080"
    DedicatedVRAM_GB      = 16
    IsIntegratedAPU       = $false
    SharedMemoryArchitecture = $false
}

$mockIntegratedAPU = [PSCustomObject]@{
    Name                  = "AMD Radeon 760M Graphics"
    DedicatedVRAM_GB      = 0.5
    IsIntegratedAPU       = $true
    SharedMemoryArchitecture = $true
}
# Aseveración: En APU/UMA, LargeSystemCache DEBE ser forzosamente 0 para no
# estrangular la memoria de vídeo compartida. En dGPU se admiten buffers ampliados.
```

### D. Mock: Topología de Almacenamiento Mixto (NVMe + HDD Mecánico)
```powershell
$mockDrives = @(
    [PSCustomObject]@{ DeviceID = "\\.\PHYSICALDRIVE0"; MediaType = "SSD"; BusType = "NVMe"; Model = "Kingston SNV3S1000G" },
    [PSCustomObject]@{ DeviceID = "\\.\PHYSICALDRIVE1"; MediaType = "HDD"; BusType = "SATA"; Model = "WDC WD10EZEX-08WN4A0" }
)
# Aseveración: Las directivas de I/O se aplican POR VOLUMEN. Prohibido deshabilitar
# la indexación o búferes de lectura de forma global sobre el HDD mecánico.
```

