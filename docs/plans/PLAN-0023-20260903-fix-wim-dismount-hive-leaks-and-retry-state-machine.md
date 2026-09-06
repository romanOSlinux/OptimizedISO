# PLAN-0023: Corrección de Fuga de Handles en Colmenas Offline y Máquina de Estados de Desmontaje WIM en DISM

## Estado
`COMPLETADO`

## Fecha
2026-09-03

## Contexto y Problema Detectado
Durante el ciclo de construcción de una ISO personalizada en `New-OptimizedWindowsISO-v2.ps1`, al llegar al desmontaje y guardado de los cambios del índice WIM (`Invoke-SafeWimDismount -Action Save`), el proceso falló con los siguientes mensajes de advertencia:

```text
Desmontando imagen WIM en 'C:\WimMount_20260903_201909' (Acción: Save)...
  [WARN] Intento 1/3 de desmontaje falló (El directorio no se pudo desmontar completamente. Esto suele deberse a que algunas aplicaciones aún tienen archivos abiertos en el directorio de montaje. Cierre estos archivos e intente de nuevo el desmontaje para completar el proceso.
).
    Esperando 3 segundos y liberando identificadores antes de reintentar...
  [WARN] Intento 2/3 de desmontaje falló (No se puede confirmar en el archivo WIM la imagen montada especificada. Esto ocurre cuando se desmontó una imagen parcialmente o cuando aún se está desmontando una imagen. Si esta imagen se desmontó antes con confirmación, probablemente la confirmación se realizó correctamente. Compruebe que sea así y desmonte la imagen sin confirmación.
).
    Esperando 3 segundos y liberando identificadores antes de reintentar...
  [WARN] Intento 3/3 de desmontaje falló (No se puede confirmar en el archivo WIM la imagen montada especificada. Esto ocurre cuando se desmontó una imagen parcialmente o cuando aún se está desmontando una imagen. Si esta imagen se desmontó antes con confirmación, probablemente la confirmación se realizó correctamente. Compruebe que sea así y desmonte la imagen sin confirmación.
).
  [WARN] No se pudo desmontar con 'Save'. Intentando desmontaje forzado (/Discard)...
  [WARN] No se pudo guardar cambios en WIM índice 10.
```

### Análisis Causa Raíz
Existen dos fallas arquitectónicas concatenadas:

1. **Retención de Handles en el Registro Offline por el Proveedor de PowerShell (`powershell.exe`):**
   - En `Get-WimPatchLevel`, la colmena `Windows\System32\config\SOFTWARE` se monta mediante `reg.exe load "HKLM\_WIMPATCH_TMP"`. Posteriormente se consulta el valor `UBR` usando `Get-ItemProperty "HKLM:\_WIMPATCH_TMP\..."`.
   - En `Invoke-WimAiHardening`, la colmena `SOFTWARE` se monta bajo `HKLM\_ROMANOS_SW`. Cuando `$DetectedBuild -le 0`, se consulta la compilación usando `Get-ItemProperty "HKLM:\_ROMANOS_SW\..."`.
   - El proveedor de registro de PowerShell (`HKLM:`) en el proceso `powershell.exe` almacena en caché e incrementa el contador de referencias de las subclaves abiertas.
   - Cuando el bloque `finally` ejecuta `reg.exe unload`, el kernel de Windows (`ntoskrnl.exe`) rechaza la descarga arrojando `ERROR_SHARING_VIOLATION` o `ERROR_ACCESS_DENIED`, error que queda silenciado por `2>&1 | Out-Null`.
   - La colmena queda mapeada en el registro del host, bloqueando el archivo `Windows\System32\config\SOFTWARE` en el directorio de montaje (`WimMountDir`). Al llegar a `Invoke-SafeWimDismount`, DISM confirma el WIM pero no puede liberar el directorio.

2. **Falla de la Máquina de Estados de Reintento ante Confirmación Parcial de DISM (`0xc1420117` / `0xc142011c`):**
   - En el Intento 1 con `-Save` (`/Commit`), DISM escribe y consolida con éxito los metadatos en el archivo `.wim`. Sin embargo, al ir a desmontar el directorio de archivos virtuales, encuentra el bloqueo mencionado y falla. La imagen queda en estado *parcialmente desmontada* / *confirmación previa exitosa*.
   - En los Intentos 2 y 3, `Invoke-SafeWimDismount` vuelve a solicitar `Dismount-WindowsImage -Save`. DISM rechaza re-confirmar una imagen que ya fue confirmada.
   - Al agotarse los reintentos, el script ejecuta un desmontaje forzado (`-Discard`), establece `$dismountSuccess = $false`, emite la advertencia `No se pudo guardar cambios en WIM índice 10` y omite la exportación del índice optimizado, a pesar de que el guardado físico en el `.wim` sí ocurrió.

---

## Objetivos del Plan
1. **Eliminar el uso del proveedor de registro de PowerShell en colmenas offline:**
   - Reemplazar consultas `Get-ItemProperty` en `Get-WimPatchLevel` e `Invoke-WimAiHardening` por subprocesos independientes `reg.exe query`. Al ejecutarse en un proceso hijo separado, PowerShell no abre ni retiene handles en su espacio de memoria, garantizando una descarga inmediata y limpia con `reg.exe unload`.
2. **Higiene Preventiva Pre-Dismount:**
   - En `Invoke-SafeWimDismount`, asegurar que el directorio de trabajo del host (`$PWD` y `[Environment]::CurrentDirectory`) no apunte al directorio de montaje.
   - Comprobar y forzar la descarga de cualquier colmena huérfana conocida (`HKLM\_WIMPATCH_TMP`, `HKLM\_ROMANOS_SW`, `HKLM\OfflineDefaultUser`) antes de invocar DISM.
3. **Máquina de Estados de Reintento Inteligente en `Invoke-SafeWimDismount`:**
   - Detectar si el fallo de `-Save` contiene los mensajes o códigos de "imagen parcialmente desmontada", "ya confirmada", "already committed", `0xc1420117` o `0xc142011c`.
   - En dicho caso, registrar que el guardado en el archivo WIM ya tuvo éxito (`$alreadyCommitted = $true`) y continuar desmontando el directorio sin re-confirmar (`-Discard`).
   - Retornar `$dismountSuccess = $true` cuando la confirmación física fue exitosa.
4. **Verificación y Pruebas Unitarias:**
   - Añadir pruebas de regresión en `Test-OptimizedISO-v2.ps1` que simulen la detección de imágenes ya confirmadas y validen la robustez de `Invoke-SafeWimDismount`.
   - Validar ejecución en frío con Windows PowerShell 5.1 (`powershell.exe -STA -NoProfile -ExecutionPolicy Bypass`).

---

## Archivos Afectados
- `scripts/New-OptimizedWindowsISO-v2.ps1`: Funciones `Get-WimPatchLevel`, `Invoke-WimAiHardening`, `Invoke-RegUnloadHive`, `Invoke-SafeWimDismount`.
- `scripts/Test-OptimizedISO-v2.ps1`: Pruebas de unidad para la nueva máquina de estados de `Invoke-SafeWimDismount` y descarga de colmenas.
- `docs/plans/README.md`: Registro del plan.

---

## Resultados Empíricos de Validación
- Ejecución completa de la suite de pruebas en **Windows PowerShell 5.1** (`powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File scripts\Test-OptimizedISO-v2.ps1`):
  - Total de Pruebas: **228**
  - PASS: **228 (100%)**
  - FAIL: **0**
  - SKIP: **0**
- Comprobación de codificación estricta: `UTF-8 con BOM` validado en `scripts/New-OptimizedWindowsISO-v2.ps1` y `scripts/Test-OptimizedISO-v2.ps1`.
- Robustez verificada ante fallos de montaje parcial y rechazos por confirmación previa en DISM.
