# PLAN-0075: Alineación de Detección Automática de ISO Optimizada en Hyper-V (romanOS Studio & CLI)

**Estado:** COMPLETADO  
**Fecha:** 2026-09-10  
**Autor:** Antigravity AI  
**Componentes:**  
- `scripts/GUI/romanOS-Studio.ps1`  
- `scripts/Testing/New-TestVM-HyperV.ps1`  
- `docs/plans/README.md`

---

## 1. Contexto y Diagnóstico Causa Raíz

El usuario reportó la siguiente discrepancia en el flujo de trabajo de prueba de ISOs:
> *"el script de creacion de ISO cuando termina la ISO apunta a esta carpeta: C:\Users\Thiago\Desktop\WinISO_Optimizado, pero el de levantar la VM y ejecutar la ISO creada apunta a otra carpeta, por lo tanto ejecuta una ISO, pero la ISO que utiliza es la que descargue de internet, lo puede revisar, para que siempre apunte a la carpeta que corresponde, antes lo hacia, es mas, el script de lanzar ISO no GUI, apunta siempre a la carpeta correcta y levanta la ultima ISO creada sin preguntar nada, y asi debe funcionar"*

### Análisis Forense:
1. **Comportamiento Erróneo en la GUI (`romanOS-Studio.ps1`):**
   - En la pestaña "Herramientas del Host", el evento del botón `btnTestVM` fue implementado en PLAN-0072 capturando:
     `$isoPath = $window.FindName('txtSourceISO').Text`
   - `txtSourceISO` corresponde a la ISO base/original descargada de Internet (ej. `C:\OptimizedISO\Win11_25H2_Spanish_x64_v2.iso`) seleccionada en la pestaña "Construcción Base" como insumo de compilación.
   - Al invocar `New-TestVM-HyperV.ps1 -ISOPath '$escapedIso'`, la GUI **forzaba** a Hyper-V a arrancar con la ISO virgen de Microsoft en lugar de la ISO optimizada recién generada en `WinISO_Optimizado`.
   - Si `txtSourceISO` no estaba seteada, arrojaba un cuadro de diálogo bloqueante exigiendo seleccionar una ISO base.

2. **Vulnerabilidad de Prioridad en CLI (`New-TestVM-HyperV.ps1`):**
   - En la sección 3 del script ("Resolver Ruta de la ISO"), cuando `-ISOPath` está vacío, el script consultaba `$searchDirs`:
     ```powershell
     $foundIsos = foreach ($d in $searchDirs) {
         if (Test-Path $d) { Get-ChildItem -Path $d -Filter "*.iso" -File }
     }
     $latestIso = $foundIsos | Sort-Object LastWriteTime -Descending | Select-Object -First 1
     ```
   - Agrupaba todos los archivos `.iso` de todas las carpetas en un único arreglo plano y ordenaba únicamente por `LastWriteTime`.
   - Si el usuario descargaba una ISO a `Downloads` o tocaba la ISO de `C:\OptimizedISO`, dicha ISO base pasaba a tener un `LastWriteTime` más reciente, haciendo que el script de VM pudiera seleccionar la ISO de Internet en vez de la ISO optimizada en `WinISO_Optimizado`.

---

## 2. Decisión y Solución Técnica Fundamentada (Regla 11)

1. **Resolución Universal Dinámica del Escritorio (Agnóstica al Usuario y Máquina):**
   - **Cero Rutas Hardcodeadas:** Está estrictamente prohibido codificar nombres de usuario específicos (como `Thiago`). El sistema debe funcionar en cualquier máquina y bajo cualquier cuenta de usuario.
   - Para resolver la carpeta de escritorio de manera 100% confiable, incluso en entornos con OneDrive, escritorios redirigidos, cuentas con elevación UAC o Windows en otros idiomas (ej. `Escritorio`), se utiliza:
     ```powershell
     $desktopPath = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
     if (-not $desktopPath) { $desktopPath = Join-Path $HOME 'Desktop' }
     ```
   - Las rutas a evaluar para `WinISO_Optimizado` se derivan dinámicamente:
     1. `Join-Path $desktopPath 'WinISO_Optimizado'`
     2. `Join-Path $HOME 'Desktop\WinISO_Optimizado'`
     3. `Join-Path $env:USERPROFILE 'Desktop\WinISO_Optimizado'`

2. **Búsqueda por Prioridad Estricta en `New-TestVM-HyperV.ps1`:**
   - Se modifica la resolución automática para evaluar las carpetas en orden secuencial de prioridad estricta:
     - **Prioridad 1 (Carpetas de Escritorio del Usuario Activo):** Rutas dinámicas de `WinISO_Optimizado` del usuario actual. Si existe y contiene una o más ISOs, se selecciona la más reciente de esa carpeta y se detiene la búsqueda (`break`).
     - **Prioridad 2:** `C:\OptimizedISO\Output`.
     - **Prioridad 3:** Fallbacks (`C:\OptimizedISO`, `$HOME\Downloads`, etc.) solo si no hay ninguna ISO en los directorios de salida.
   - De esta forma, si existe al menos una ISO compilada en `WinISO_Optimizado` del usuario actual, **nunca** se seleccionará una ISO cruda de descargas o de la raíz del proyecto.

3. **Desacoplamiento Total de `btnTestVM` en `romanOS-Studio.ps1`:**
   - Se elimina la dependencia de `txtSourceISO` en `btnTestVM`.
   - Al pulsar "Levantar Máquina Virtual de Prueba", la GUI invoca directamente `New-TestVM-HyperV.ps1` sin el argumento `-ISOPath`.
   - El motor de Hyper-V detecta automáticamente la ISO optimizada más reciente en la carpeta `WinISO_Optimizado` del usuario activo, imprime en la consola de romanOS Studio:
     `[+] ISO detectada automáticamente: <Ruta_Dinamica_Usuario>\Desktop\WinISO_Optimizado\Windows_11_Optimized_....iso`
     y arranca la VM y `vmconnect.exe` sin preguntas ni interrupciones, con paridad absoluta con el lanzador CLI (`New-TestVM-HyperV.cmd`).
   - Se actualiza el texto descriptivo del XAML en la pestaña "Herramientas del Host" para que describa explícitamente que levanta la última ISO optimizada de `WinISO_Optimizado`.
   - Se asegura que en `btnBuild` de `romanOS-Studio.ps1`, `OutputDir` utilice la resolución dinámica del escritorio para cualquier usuario.

---

## 3. Cambios Propuestos

### Módulo de Testing Hyper-V
#### [MODIFY] [New-TestVM-HyperV.ps1](file:///c:/OptimizedISO/scripts/Testing/New-TestVM-HyperV.ps1)
- Reemplazar la acumulación plana de `$foundIsos` por una búsqueda con jerarquía de prioridad estricta utilizando la resolución dinámica del escritorio del usuario actual (`[Environment]::GetFolderPath('Desktop')`, `$HOME`, `$env:USERPROFILE`).
- Mantener compatibilidad con `-ISOPath` explícito si se pasa por línea de comandos.

### Interfaz Gráfica romanOS Studio
#### [MODIFY] [romanOS-Studio.ps1](file:///c:/OptimizedISO/scripts/GUI/romanOS-Studio.ps1)
- Modificar el evento `btnTestVM.Add_Click` para ejecutar `New-TestVM-HyperV.ps1` sin forzar `-ISOPath $txtSourceISO`.
- Actualizar el texto descriptivo en el XAML de la pestaña "Herramientas del Host".

---

## 4. Plan de Verificación

1. **Prueba de Sintaxis AST en Windows PowerShell 5.1:**
   - Validar que ambos scripts modificados (`New-TestVM-HyperV.ps1` y `romanOS-Studio.ps1`) compilen limpiamente sin errores AST bajo `powershell.exe`.
2. **Verificación de Codificación UTF-8 con BOM:**
   - Comprobar la presencia de los bytes `0xEF 0xBB 0xBF` en ambos archivos.
3. **Prueba de Resolución de ISO:**
   - Ejecutar la rutina de resolución en frío y verificar que seleccione `C:\Users\Thiago\Desktop\WinISO_Optimizado\Windows_11_Optimized_20260910_223842.iso` y descarte `C:\OptimizedISO\Win11_25H2_Spanish_x64_v2.iso`.
4. **Prueba en `Invoke-TestSuite.ps1 -Quick`:**
   - Confirmar que las pruebas unitarias y de higiene del repositorio sigan pasando al 100%.
