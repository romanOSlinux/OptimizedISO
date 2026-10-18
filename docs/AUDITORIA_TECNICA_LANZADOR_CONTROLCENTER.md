# INFORME FORENSE DE AUDITORÍA TÉCNICA Y MATRIZ DE RESILIENCIA
## Componente: Lanzador Oficial Win32 romanOS Control Center (`Lanzar-romanOS-ControlCenter`)
**Fecha:** 14 de Octubre de 2026  
**Destinatario:** Equipo de Ingeniería / IA de Autoría de Scripts de romanOS  
**Estado de la Auditoría:** FINALIZADA — EVIDENCIA EMPÍRICA CONCLUYENTE (100% REPRODUCIBLE)  
**Entorno de Validación:** Windows 11 Pro for Workstations (Build 26300), PowerShell 5.1 Desktop (`5.1.26100.9444`), Token no elevado (Nivel de Integridad Medio: `S-1-16-8192`), Compilador `csc.exe` v4.8.9221.0.  
**Artefactos de Prueba Físicos:** `scratch/launcher-evidence/Invoke-LauncherEvidence.ps1`, `scratch/launcher-evidence/out/evidence.log`, `scratch/launcher-evidence/out/verdicts.json`.

---

## 1. RESUMEN EJECUTIVO Y ANÁLISIS DE IMPACTO

El subsistema del lanzador de **romanOS Control Center** fue concebido bajo el requerimiento arquitectónico *Zero-Flash* (PLAN-0086): permitir al usuario final abrir la interfaz gráfica WPF ([`romanOS-ControlCenter.ps1`](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter.ps1)) sin experimentar el parpadeo de consola característico de `powershell.exe`. Para ello, se diseñó un mecanismo de compilación en el momento (JIT - *Just-In-Time*) mediante `csc.exe` que genera un binario nativo Windows Subsystem 2 ([`romanOS-ControlCenter-Launcher.cs`](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter-Launcher.cs)) ejecutado por un script por lotes ([`Lanzar-romanOS-ControlCenter.cmd`](file:///c:/OptimizedISO/Lanzar-romanOS-ControlCenter.cmd)).

La auditoría técnica forense realizada sobre el 100% del ciclo de vida del componente demuestra que, **en condiciones de despliegue real en una máquina instalada, el modelo JIT falla de manera sistemática y silenciosa en el 100% de las invocaciones realizadas por un usuario estándar**. Esto ocasiona que el sistema caiga permanentemente al mecanismo de *fallback* por consola, penalizando el tiempo de arranque, consumiendo ciclos de CPU en compilaciones abortadas y destruyendo el objetivo de inicio limpio (*Zero-Flash*).

Adicionalmente, se identificaron **defectos críticos de propagación de argumentos, código inalcanzable, divergencia de código entre copias y pérdida de trazabilidad de errores**. A continuación se expone la matriz cuantitativa de fallos con sus pruebas empíricas irrebatibles y las soluciones de ingeniería correspondientes.

---

## 2. MATRIZ DE VEREDICTOS Y EVIDENCIAS EMPÍRICAS

Todos los hallazgos descritos fueron reproducidos empíricamente en un entorno aislado (*sandbox*) mediante el arnés [`Invoke-LauncherEvidence.ps1`](file:///c:/OptimizedISO/scratch/launcher-evidence/Invoke-LauncherEvidence.ps1) y registrados en el log forense [`evidence.log`](file:///c:/OptimizedISO/scratch/launcher-evidence/out/evidence.log).

| ID | Clasificación de Severidad | Defecto Técnico Diagnosticado | Veredicto Empírico | Métrica / Evidencia Forense Clave |
|---|---|---|---|---|
| **H1** | **ALTA** (Obsolescencia) | El binario `.exe` queda perpetuamente congelado ante cambios en el código C# | **CONFIRMADO** | Hash invariable `EC3432733C357265`. No recompila si el `.cs` es más reciente. |
| **H2** | **CRÍTICA** (Arquitectura) | Inviabilidad JIT por permisos NTFS en `C:\Windows\Setup\Scripts` (Token estándar) | **CONFIRMADO** | Error nativo `CS1567: Acceso denegado`. 3/3 ejecuciones abortadas. Sobrecarga de ~134 ms en cada inicio. |
| **H3** | **ALTA** (Silenciamiento) | Errores de compilación totalmente silenciados con `>nul 2>&1` | **CONFIRMADO** | Con código C# corrupto, devuelve `exit 0`, 0 bytes de salida y oculta el fallo fatal. |
| **H4** | **MEDIA** (SSOT / Deriva) | Divergencia de directivas de compilación entre copias del lanzador | **CONFIRMADO** | `git diff` confirma ausencia de `/platform:anycpu` en `scripts\GUI\`. Hashes distintos. |
| **H5** | **ALTA** (Integridad de Datos) | Fragmentación y destrucción de entrecomillado en argumentos con espacios | **CONFIRMADO** | Argumento `alfa "valor con espacios"` (2 tokens) descompuesto en 4 argumentos independientes. |
| **H6** | **CRÍTICA** (Objetivo UX) | El *fallback* ejecuta un binario CUI (consola), anulando el estándar *Zero-Flash* | **CONFIRMADO** | `powershell.exe` es PE Subsystem 3 (CUI). Destello visual inevitable cuando falla el `.exe`. |
| **H7** | **BAJA** (Código Muerto) | Inalcanzabilidad del código Win32 `1223` (UAC cancelado) con `UseShellExecute=false` | **CONFIRMADO** | Windows retorna `Win32Exception` código `740` (`ERROR_ELEVATION_REQUIRED`) sin diálogo UAC. |
| **H8** | **MEDIA** (Portabilidad) | Terminaciones de línea UNIX (LF puro) en archivos Batch (`.cmd`) | **CONFIRMADO** | Inspección binaria: `CR=0, LF=71`. Fragilidad en el motor `cmd.exe`. |
| **H9** | **BAJA** (Calidad de Código) | Redundancia sintáctica en la resolución del directorio de trabajo en C# | **CONFIRMADO** | `if` y `else if` evalúan idéntica ruta física normalizada a `Policy-Engine.ps1`. |

---

## 3. DESGLOSE TÉCNICO DETALLADO, PRUEBAS Y SOLUCIONES

### HALLAZGO H1: Congelamiento y Obsolescencia del Ejecutable Compilado
* **Ubicación:** [`Lanzar-romanOS-ControlCenter.cmd`](file:///c:/OptimizedISO/Lanzar-romanOS-ControlCenter.cmd), Líneas 34–40.
* **Descripción del Defecto:**  
  El script verifica únicamente si el archivo ejecutable no existe físicamente en disco (`if not exist "%EXE%"`). Si un desarrollador o una actualización del sistema modifica el código fuente C# ([`romanOS-ControlCenter-Launcher.cs`](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter-Launcher.cs)), el lanzador omite la compilación y continúa ejecutando el binario compilado antiguo indefinidamente.
* **Prueba Empírica (Test T2 en `evidence.log`):**  
  1. Se compiló el ejecutable inicial obteniendo hash SHA-256 `EC3432733C357265`.
  2. Se modificó el código C# agregando el parámetro `-RO_V2MARKER`. Timestamp del `.cs`: `20:01:06.690`. Timestamp del `.exe`: `20:01:06.197` (fuente más reciente que el binario).
  3. Al ejecutar el lanzador, el hash se mantuvo en `EC3432733C357265` y el parámetro modificado **no fue transmitido**.
  4. Solo tras borrar manualmente el archivo `.exe` se produjo la recompilación (nuevo hash `E8B0AA1D20D9BE2C`).
* **Solución de Ingeniería Recomendada:**  
  En lugar de basarse en un modelo JIT en tiempo de ejecución del usuario, el `.exe` debe ser **precompilado de forma determinista durante la fase de empaquetado de la ISO o en `SetupComplete.cmd`** (donde se cuenta con privilegios de SYSTEM). Si se mantiene la compilación en caliente, se debe comparar la fecha de modificación del `.cs` frente a la del `.exe`.

---

### HALLAZGO H2: Inviabilidad del Modelo JIT por Permisos NTFS en Despliegue Real
* **Ubicación:** [`Lanzar-romanOS-ControlCenter.cmd`](file:///c:/OptimizedISO/Lanzar-romanOS-ControlCenter.cmd), Líneas 25–31 y 35–43; [`New-OptimizedWindowsISO-v2.ps1`](file:///c:/OptimizedISO/scripts/Builder/New-OptimizedWindowsISO-v2.ps1), Líneas 5431–5437 y 5664–5667.
* **Descripción del Defecto:**  
  En una máquina con Windows 11 desplegado, los accesos directos creados por el Builder en el Menú Inicio y en el Escritorio apuntan a:  
  `%WINDIR%\Setup\Scripts\Lanzar-romanOS-ControlCenter.cmd`  
  El código intenta generar el binario en:  
  `C:\Windows\Setup\Scripts\Lanzar-romanOS-ControlCenter.exe`  
  Sin embargo, la lista de control de acceso (ACL) estándar de Windows en `%WINDIR%\Setup\Scripts` restringe a los usuarios no elevados a permisos de solo lectura y ejecución:
  ```text
  BUILTIN\Usuarios:(I)(RX)
  BUILTIN\Usuarios:(I)(OI)(CI)(IO)(GR,GE)
  ```
  Dado que el usuario hace doble clic sin privilegios administrativos (Token con integridad media), el compilador `csc.exe` carece de permisos de escritura para crear el archivo temporal y el binario final en dicha ruta.
* **Prueba Empírica (Test T4 en `evidence.log`):**  
  1. Se simuló la restricción denegando permisos de escritura al usuario (`icacls /deny *(WD)`).
  2. Al ejecutar el lanzador, `csc.exe` fue invocado y arrojó el siguiente error nativo:
     ```text
     CSC4E44F540B30448889B154AA1C16533AA.TMP: error CS1567: Error al generar el recurso Win32: Acceso denegado.
     ```
  3. En 3 de 3 intentos (`T4-denegado-1`, `2` y `3`), el `.exe` nunca llegó a crearse.
  4. En cada arranque, el usuario sufrió un retraso innecesario de compilación fallida (~134 ms en sandbox limpio) y el lanzador cayó invariablemente a la llamada directa de `powershell.exe`.
* **Solución de Ingeniería Recomendada:**  
  1. **Precompilación en `SetupComplete.cmd`:** Dado que `SetupComplete.cmd` se ejecuta bajo el contexto `NT AUTHORITY\SYSTEM`, este debe invocar `csc.exe` para dejar `Lanzar-romanOS-ControlCenter.exe` ya compilado y ubicado en `%WINDIR%\Setup\Scripts\`.
  2. **Accesos directos directos al binario:** Los accesos directos del Menú Inicio y Escritorio deben apuntar directamente a `Lanzar-romanOS-ControlCenter.exe`, eliminando por completo la capa intermedia de `cmd.exe` y suprimiendo cualquier intento de compilación en el espacio de usuario.

---

### HALLAZGO H3: Ocultamiento Ciego de Excepciones y Pérdida de Telemetría
* **Ubicación:** [`Lanzar-romanOS-ControlCenter.cmd`](file:///c:/OptimizedISO/Lanzar-romanOS-ControlCenter.cmd), Línea 37.
* **Descripción del Defecto:**  
  La invocación del compilador C# descarta la salida estándar y la salida de error:
  ```cmd
  "%CSC%" /nologo /target:winexe /platform:anycpu /optimize+ /out:"%EXE%" "%SRC%" >nul 2>&1
  ```
  Si `csc.exe` falla por sintaxis corrupta, incompatibilidad de arquitectura o denegación de permisos, el error desaparece por completo sin dejar rastro en logs y el proceso continúa con código de salida `0`. Esto viola el principio de diseño *Fail-Visible* (CWE-390).
* **Prueba Empírica (Test T3 en `evidence.log`):**  
  1. Se inyectó código C# intencionalmente inválido (`ESTO NO ES CSHARP VALIDO`).
  2. La invocación real de `csc.exe` sin redirección falló con código `1` y arrojó:
     ```text
     error CS0116: Un espacio de nombres no puede contener directamente miembros como campos o métodos
     ```
  3. El lanzador `.cmd` arrojó `exit=0`, `stdout=0B`, `stderr=0B` y procedió al fallback como si nada hubiera ocurrido.
* **Solución de Ingeniería Recomendada:**  
  Si la compilación se mantiene en scripts por lotes, los errores deben ser redirigidos a un archivo de registro técnico en la carpeta `%WINDIR%\Setup\Scripts\Log\romanOS-ControlCenter-Build.log` o mostrar una advertencia visible en caso de fallo cuando no se logre el binario esperado.

---

### HALLAZGO H4: Divergencia y Deriva de Código entre Archivos Duplicados
* **Ubicación:**  
  * Copia 1: [`Lanzar-romanOS-ControlCenter.cmd`](file:///c:/OptimizedISO/Lanzar-romanOS-ControlCenter.cmd) (Raíz)
  * Copia 2: [`scripts\GUI\Lanzar-romanOS-ControlCenter.cmd`](file:///c:/OptimizedISO/scripts/GUI/Lanzar-romanOS-ControlCenter.cmd)
* **Descripción del Defecto:**  
  Existen múltiples copias del script con pequeñas variaciones. La copia de la raíz especifica la directiva de compilación `/platform:anycpu`, mientras que la copia dentro de `scripts\GUI\` la omite.
* **Prueba Empírica (Test T8 en `evidence.log`):**  
  `git diff` directo entre ambos archivos:
  ```diff
  --- a/Lanzar-romanOS-ControlCenter.cmd
  +++ b/scripts/GUI/Lanzar-romanOS-ControlCenter.cmd
  @@ -37,3 +37,3 @@
  -            "%CSC%" /nologo /target:winexe /platform:anycpu /optimize+ /out:"%EXE%" "%SRC%" >nul 2>&1
  +            "%CSC%" /nologo /target:winexe /optimize+ /out:"%EXE%" "%SRC%" >nul 2>&1
  ```
  Hashes SHA-256 resultantes:
  * Raíz: `76068DBD8F04B0CA`
  * `scripts\GUI\`: `E43CCA5520CD56EF`
* **Solución de Ingeniería Recomendada:**  
  Aplicar el principio de **Fuente Única de Verdad (SSOT)**. Conservar un único lanzador canónico en la raíz del proyecto. Si se requiere una referencia en `scripts\GUI\`, este debe ser un redireccionador simbólico o invocar al script raíz sin duplicar lógica de compilación.

---

### HALLAZGO H5: Fragmentación y Pérdida de Quoting en Argumentos
* **Ubicación:** [`romanOS-ControlCenter-Launcher.cs`](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter-Launcher.cs), Línea 73 y 78.
* **Descripción del Defecto:**  
  El código C# concatena los argumentos recibidos utilizando:
  ```csharp
  string extraArgs = args != null && args.Length > 0 ? " " + string.Join(" ", args) : "";
  ...
  Arguments = string.Format("-WindowStyle Hidden -STA -NoProfile -ExecutionPolicy Bypass -File \"{0}\"{1}", scriptPath, extraArgs)
  ```
  Al realizar `string.Join(" ", args)`, cualquier argumento que contenga espacios (rutas de directorios, nombres de perfiles, parámetros entre comillas) pierde las comillas dobles que lo delimitaban, provocando que PowerShell interprete cada palabra como un parámetro independiente.
* **Prueba Empírica (Test T5 en `evidence.log`):**  
  1. Se invocó el lanzador enviando 2 argumentos lógicos:  
     `alfa "valor con espacios"`
  2. **Ruta con el `.exe` (C#):** El script destino en PowerShell recibió **4 argumentos**:
     ```text
     ArgCount=4 Args=[alfa] [valor] [con] [espacios]
     ```
  3. **Ruta con el `.cmd` (Fallback):** Gracias al uso de `%*`, se preservó el agrupamiento correcto:
     ```text
     ArgCount=2 Args=[alfa] [valor con espacios]
     ```
* **Solución de Ingeniería Recomendada:**  
  Implementar una función de escape que envuelva en comillas y escape las comillas internas para cada argumento antes de unir la cadena:
  ```csharp
  static string EscapeArgument(string arg)
  {
      if (string.IsNullOrEmpty(arg)) return "\"\"";
      if (!arg.Contains(" ") && !arg.Contains("\t") && !arg.Contains("\"")) return arg;
      return "\"" + arg.Replace("\"", "\\\"") + "\"";
  }
  // Uso:
  string extraArgs = args != null && args.Length > 0 
      ? " " + string.Join(" ", Array.ConvertAll(args, EscapeArgument)) 
      : "";
  ```

---

### HALLAZGO H6: El Fallback Contradice el Requerimiento "Zero-Flash"
* **Ubicación:** [`Lanzar-romanOS-ControlCenter.cmd`](file:///c:/OptimizedISO/Lanzar-romanOS-ControlCenter.cmd), Líneas 64–67.
* **Descripción del Defecto:**  
  Cuando la compilación falla (lo cual ocurre por diseño en el 100% de los casos en usuario estándar debido a H2), el lanzador recurre a:
  ```cmd
  start "" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -STA -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
  ```
  Aunque se incluye `-WindowStyle Hidden`, el ejecutable de PowerShell pertenece al subsistema de consola de Windows. El sistema operativo inicializa la consola antes de que el intérprete procese el argumento `-WindowStyle Hidden`, produciendo un destello negro visible en la pantalla.
* **Prueba Empírica (Test T6 en `evidence.log`):**  
  Inspección de las cabeceras binarias PE (*Portable Executable*):
  * `powershell.exe`: **Subsystem 3 (`IMAGE_SUBSYSTEM_WINDOWS_CUI`)** → Fuerza la creación de ventana de consola.
  * `Lanzar-romanOS-ControlCenter.exe`: **Subsystem 2 (`IMAGE_SUBSYSTEM_WINDOWS_GUI`)** → Cero ventana de consola por parte del kernel de Windows.
* **Solución de Ingeniería Recomendada:**  
  La única garantía técnica de cero parpadeo es asegurar que el binario con Subsystem 2 (`IMAGE_SUBSYSTEM_WINDOWS_GUI`) esté preinstalado en el sistema antes de que el usuario interactúe con él.

---

### HALLAZGO H7: Código Muerto en el Manejo de Excepciones UAC (Error 1223)
* **Ubicación:** [`romanOS-ControlCenter-Launcher.cs`](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter-Launcher.cs), Líneas 88–98.
* **Descripción del Defecto:**  
  El código C# intenta capturar la cancelación de elevación UAC con el código de error nativo `1223` (`ERROR_CANCELLED`):
  ```csharp
  catch (Win32Exception w32ex)
  {
      // Codigo 1223 = ERROR_CANCELLED (El usuario cerro o cancelo el dialogo de elevacion UAC)
      if (w32ex.NativeErrorCode != 1223) { ... }
  }
  ```
  Sin embargo, el objeto `ProcessStartInfo` tiene establecido explícitamente:
  ```csharp
  UseShellExecute = false;
  CreateNoWindow = true;
  ```
  Bajo la API `CreateProcess` de Windows (`UseShellExecute = false`), el sistema operativo **no es capaz de invocar la interfaz gráfica de elevación UAC**. Si el proceso hijo requiriera elevación obligatoria por manifiesto, `CreateProcess` falla de inmediato con el error nativo `740` (`ERROR_ELEVATION_REQUIRED`), sin mostrar jamás el cuadro de diálogo UAC y haciendo que la evaluación del código `1223` sea inalcanzable.
* **Prueba Empírica (Test T7 en `evidence.log`):**  
  Se lanzó un ejecutable que requiere elevación (`requireAdministrator`) utilizando `UseShellExecute = false`.
  * Excepción producida: `Win32Exception`.
  * `NativeErrorCode`: **`740`** ("La operación solicitada requiere elevación").
  * Diálogo UAC desplegado: **Ninguno**.
* **Solución de Ingeniería Recomendada:**  
  Si el lanzador C# pretende delegar la elevación UAC, debe usar `UseShellExecute = true` y `Verb = "runas"`. Si la auto-elevación se delega al script de PowerShell (como ocurre actualmente en las líneas 35–59 de [`romanOS-ControlCenter.ps1`](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter.ps1)), se debe documentar que el lanzador corre en integridad estándar y simplificar el bloque `catch` para manejar errores reales de proceso como el código `740`.

---

### HALLAZGO H8: Finales de Línea UNIX (LF) en Scripts Batch de Windows
* **Ubicación:**  
  * [`Lanzar-romanOS-ControlCenter.cmd`](file:///c:/OptimizedISO/Lanzar-romanOS-ControlCenter.cmd)
  * [`scripts\GUI\Lanzar-romanOS-ControlCenter.cmd`](file:///c:/OptimizedISO/scripts/GUI/Lanzar-romanOS-ControlCenter.cmd)
  * [`scripts\Lanzar-romanOS-ControlCenter.cmd`](file:///c:/OptimizedISO/scripts/Lanzar-romanOS-ControlCenter.cmd)
* **Descripción del Defecto:**  
  Todos los scripts `.cmd` del lanzador contienen terminaciones de línea LF puro (`\n`) sin retorno de carro (`\r\n`). Aunque los comandos lineales simples pueden ejecutarse, el parser interno de `cmd.exe` de Windows presenta fallos conocidos al procesar bloques de paréntesis, etiquetas de salto (`:label`) o bucles cuando los saltos son LF puro.
* **Prueba Empírica (Test T9 en `evidence.log`):**  
  Inspección byte a byte de los archivos:
  * `Lanzar-romanOS-ControlCenter.cmd`: `CR = 0`, `LF = 71`.
  * `scripts\GUI\Lanzar-romanOS-ControlCenter.cmd`: `CR = 0`, `LF = 71`.
  * `scripts\Lanzar-romanOS-ControlCenter.cmd`: `CR = 0`, `LF = 28`.
  * Salida de `git ls-files --eol`: `i/lf w/lf attr/`.
* **Solución de Ingeniería Recomendada:**  
  Guardar y versionar todos los archivos `.cmd` y `.bat` estrictamente con terminaciones de línea de Windows **CRLF (`\r\n`)** y configurar `.gitattributes` en la raíz del repositorio para garantizar su conservación:
  ```gitattributes
  *.cmd text eol=crlf
  *.bat text eol=crlf
  ```

---

### HALLAZGO H9: Redundancia Sintáctica en la Resolución de Directorio en C#
* **Ubicación:** [`romanOS-ControlCenter-Launcher.cs`](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter-Launcher.cs), Líneas 64–71.
* **Descripción del Defecto:**  
  El código contiene dos bloques condicionales consecutivos:
  ```csharp
  string workDir = Path.GetDirectoryName(scriptPath);
  string parentDir = Path.GetDirectoryName(workDir);
  if (File.Exists(Path.Combine(workDir, @"..\Core\Policy-Engine.ps1")))
  {
      workDir = Path.GetFullPath(Path.Combine(workDir, @".."));
  }
  else if (parentDir != null && File.Exists(Path.Combine(parentDir, @"Core\Policy-Engine.ps1")))
  {
      workDir = parentDir;
  }
  ```
  Matemáticamente, `Path.Combine(workDir, @"..\Core\Policy-Engine.ps1")` y `Path.Combine(parentDir, @"Core\Policy-Engine.ps1")` son idénticos porque `..\` relativo a `workDir` apunta exactamente a `parentDir`. Por lo tanto, si la primera condición es verdadera, se ejecuta el primer bloque; si la primera es falsa, la segunda condición es idéntica y jamás podrá ser evaluada como verdadera.
* **Prueba Empírica (Test T10 en `evidence.log`):**  
  Se evaluaron 4 rutas reales y sintéticas con `[IO.Path]::GetFullPath()`. En el 100% de los casos, la condición 1 y la condición 2 arrojaron el mismo resultado booleano y la misma ruta física.
* **Solución de Ingeniería Recomendada:**  
  Simplificar el bloque a una única comprobación limpia y directa:
  ```csharp
  string workDir = Path.GetDirectoryName(scriptPath);
  string parentDir = Path.GetDirectoryName(workDir);
  if (parentDir != null && File.Exists(Path.Combine(parentDir, @"Core\Policy-Engine.ps1")))
  {
      workDir = parentDir;
  }
  ```

---

## 4. HALLAZGOS ADICIONALES DEL ECOSISTEMA RELACIONADOS

Durante la inspección estática del repositorio vinculada a este lanzador se identificaron tres anomalías adicionales:

1. **Pérdida del parámetro `-Unattended` en la auto-elevación interna (H10):**  
   En [`romanOS-ControlCenter.ps1`](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter.ps1) (Líneas 21–22 y 42), el script define los parámetros `[switch]$SkipElevation` y `[switch]$Unattended`. Cuando un usuario ejecuta el script con `-Unattended` y el proceso se auto-eleva vía `runas`, la línea de comandos reconstruida para el nuevo proceso elevado es:
   ```powershell
   $psi.Arguments = "-WindowStyle Hidden -STA -NoProfile -ExecutionPolicy Bypass -File `"$targetScript`""
   ```
   El modificador `-Unattended` **se pierde en el proceso elevado**. Se debe reconstruir `$psi.Arguments` concatenando `$MyInvocation.BoundParameters` o `$args`.

2. **Existencia de un wrapper intermedio huérfano (H11):**  
   Existe el archivo [`scripts\Lanzar-romanOS-ControlCenter.cmd`](file:///c:/OptimizedISO/scripts/Lanzar-romanOS-ControlCenter.cmd), el cual no es referenciado por ningún componente del Builder ni de la documentación. Además, su fallback invoca a `powershell.exe` de forma síncrona, sin `-WindowStyle Hidden` y sin calificar la ruta absoluta del binario. Se recomienda eliminarlo para evitar confusión y duplicidad.

3. **Mismo patrón de fallo en `Lanzar-romanOS-Studio.cmd`:**  
   El lanzador de romanOS Studio ([`Lanzar-romanOS-Studio.cmd`](file:///c:/OptimizedISO/Lanzar-romanOS-Studio.cmd)) implementa la misma lógica de compilación JIT en caliente con `if not exist "%EXE%"` y silenciamiento con `>nul 2>&1`, por lo que comparte exactamente los mismos defectos H1, H2, H3 y H8.

---

## 5. PLAN MAESTRO DE REMEDIACIÓN PROPUESTO

Para resolver de raíz y de forma definitiva todos los problemas demostrados, se propone el siguiente flujo arquitectónico:

```
[FASE BUILD / SETUPCOMPLETE]
          │
          ▼
Compilar nativamente con csc.exe:
- romanOS-ControlCenter-Launcher.cs ──► Lanzar-romanOS-ControlCenter.exe (Subsystem 2)
- romanOS-Studio-Launcher.cs       ──► Lanzar-romanOS-Studio.exe (Subsystem 2)
          │
          ▼
Inyectar binarios ya compilados en C:\Windows\Setup\Scripts\
          │
          ▼
Crear accesos directos (.lnk) apuntando DIRECTAMENTE a los .exe
          │
          ▼
[RESULTADO]: Cero necesidad de csc.exe en runtime, Cero parpadeo, Cero fallos por permisos NTFS
```

### Acciones concretas a implementar:
1. **Precompilación en el Builder e Imagen WIM:**  
   En [`New-OptimizedWindowsISO-v2.ps1`](file:///c:/OptimizedISO/scripts/Builder/New-OptimizedWindowsISO-v2.ps1), compilar `Lanzar-romanOS-ControlCenter.exe` durante la fase de ensamblado de `$OEM$` utilizando el compilador del host (`csc.exe`). Copiar el ejecutable ya compilado directamente a `$OEM$\$$\Setup\Scripts\`.
2. **Precompilación de respaldo en `SetupComplete.cmd`:**  
   Añadir una verificación en `SetupComplete.cmd` (que corre como SYSTEM antes de que inicie cualquier usuario) para compilar el ejecutable si por alguna razón no existiera.
3. **Actualización de Accesos Directos (.lnk):**  
   Modificar la creación de accesos directos en el Builder para que el `TargetPath` apunte directamente a `%WINDIR%\Setup\Scripts\Lanzar-romanOS-ControlCenter.exe`, eliminando el paso innecesario por `cmd.exe`.
4. **Refactorización del código C# ([`romanOS-ControlCenter-Launcher.cs`](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter-Launcher.cs)):**  
   * Aplicar la función de escape para argumentos con espacios (H5).
   * Simplificar la detección de `workDir` eliminando la rama redundante (H9).
   * Actualizar el manejo de excepciones para registrar el error `740` (H7).
5. **Higiene de Archivos Batch:**  
   * Unificar el script `.cmd` a una sola fuente canónica en la raíz (H4).
   * Eliminar el wrapper obsoleto `scripts\Lanzar-romanOS-ControlCenter.cmd` (H11).
   * Convertir todos los saltos de línea a CRLF nativo de Windows (H8).
6. **Ampliación de Pruebas Unitarias:**  
   Actualizar [`Test-OptimizedISO-v2.ps1`](file:///c:/OptimizedISO/scripts/Testing/Test-OptimizedISO-v2.ps1) para verificar no solo la existencia de cadenas estáticas, sino la presencia del binario precompilado y la correcta preservación de argumentos.

---
*Fin del informe técnico de auditoría.*
