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
