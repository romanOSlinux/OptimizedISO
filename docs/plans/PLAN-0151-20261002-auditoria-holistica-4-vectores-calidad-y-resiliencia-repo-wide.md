# PLAN-0151: Auditoría Holística y Blindaje Repo-Wide en 4 Vectores de Calidad y Resiliencia

## Metadatos
- **ID:** PLAN-0151
- **Fecha:** 2026-10-02
- **Título:** Auditoría Holística y Blindaje Repo-Wide en 4 Vectores de Calidad y Resiliencia (Null-Safety, ExitCode Nativo, Finally-Guards y Rutas Dinámicas)
- **Estado:** COMPLETADO
- **Fase:** SHIP
- **Autor:** romanOS Agent (Advanced Agentic OS)
- **Marco de Referencia:** Regla 13 (Principio de Auditoría Holística y Fail-Visible), Regla 4 (Codificación UTF-8 con BOM y PowerShell 5.1), Regla 14 (Multi-Hardware y Cero Daño)

---

## 1. Contexto y Justificación Técnica

Tras la resolución y certificación de los falsos positivos y fallos de fallback en propiedades de red (PLAN previo), se identificó la necesidad de extender una inspección forense repo-wide sobre 4 vectores sistémicos de vulnerabilidad y fragilidad en PowerShell:

1. **Vector 1: Comparaciones con `$null` seguras (Null-Safety):**  
   En PowerShell, si el operando izquierdo de `-eq` es una colección/array, actúa como un filtro (`$array -eq $null` extrae elementos nulos) en vez de evaluar si la variable es `$null`. La única sintaxis determinista según las directivas oficiales de Microsoft y PSScriptAnalyzer (`PSPossibleIncorrectComparisonWithNull`) es situar `$null` en el lado izquierdo: `$null -eq $variable` y `$null -ne $variable`.

2. **Vector 2: Manejo Fail-Visible de Procesos Nativos (`$LASTEXITCODE`):**  
   Los binarios nativos del sistema (`dism.exe`, `oscdimg.exe`, `fsutil.exe`, `reg.exe`, `pnputil.exe`, `bcdedit.exe`) no lanzan excepciones capturables por bloques `try / catch` a menos que falle la creación del proceso. Toda invocación crítica debe verificar `$LASTEXITCODE -eq 0` o gestionar el código de salida forense para no continuar la ejecución a ciegas.

3. **Vector 3: Higiene de Montaje y Descarga Garantizada (`try / finally`):**  
   Toda manipulación de colmenas fuera de línea (`reg load` / `reg unload`) y montajes de imágenes WIM con DISM debe estar blindada con bloques `finally` que aseguren la liberación incondicional de los identificadores de archivo ante cualquier error o interrupción del usuario.

4. **Vector 4: Erradicación de Rutas Fijas Hardcodeadas (`C:\`, `Desktop`):**  
   Eliminar suposiciones de letra de disco única (`C:`) o nombres fijos de carpetas de usuario, garantizando el uso de variables dinámicas (`$env:SystemDrive`, `[Environment]::GetFolderPath('Desktop')`) aptas para entornos multi-boot, WinPE y perfiles con roaming.

---

## 2. Fases de Ejecución

### Fase 1: Escaneo y Corrección del Vector 1 (Comparaciones `$null` a la Izquierda)
- [x] Escanear el 100% de los scripts de `scripts/` buscando operadores binarios con `$null` a la derecha.
- [x] Refactorizar quirúrgicamente las instancias a `$null -eq $var` y `$null -ne $var`.
- [x] Validar compatibilidad AST.

### Fase 2: Escaneo y Blindaje del Vector 2 (`$LASTEXITCODE` y Procesos Nativos)
- [x] Identificar llamadas mutantes a ejecutables nativos (`dism.exe`, `oscdimg.exe`, `reg.exe`, `fsutil.exe`, `pnputil.exe`).
- [x] Asegurar comprobación de `$LASTEXITCODE -eq 0` y emisión de telemetría de advertencia/error ante códigos distintos de cero.

### Fase 3: Escaneo y Blindaje del Vector 3 (`try / finally` en Hives y WIMs)
- [x] Auditar pares de `reg load` vs `reg unload` en módulos de Builder, Servicing y Snapshots.
- [x] Garantizar que las descargas de registro residan en bloques `finally` deterministas.

### Fase 4: Escaneo y Saneamiento del Vector 4 (Rutas Dinámicas)
- [x] Detectar ocurrencias de rutas rígidas `C:\` en contextos mutantes y sustituir por `$env:SystemDrive`.
- [x] Resolver carpetas de usuario dinámicamente mediante APIs de entorno.

### Fase 5: Certificación Holística y Commit Atómico
- [x] Certificar codificación UTF-8 con BOM en el 100% de los archivos modificados.
- [x] Ejecutar comprobación en frío de análisis sintáctico AST con Windows PowerShell 5.1 (`powershell.exe`).
- [x] Ejecutar la suite completa de contratos funcionales (`Test-FunctionalContracts.ps1`) y arnés de pruebas (109/109 PASS).
- [x] Registrar commit atómico con pre-commit gateway activo.
