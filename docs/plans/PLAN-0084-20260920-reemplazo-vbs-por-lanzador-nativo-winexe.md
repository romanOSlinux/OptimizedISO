# PLAN-0084: Erradicación de VBScript y Reemplazo por Lanzador GUI Nativo Win32 (Subsystem 2 / winexe)

**Fecha:** 2026-09-20  
**Estado:** COMPLETADO  
**Autor:** romanOS Engineering / Antigravity  

---

## 1. Contexto y Justificación Técnica

En el commit `1ffc81a` (PLAN-0083) se incorporó `Lanzar-romanOS-Studio.vbs` para evitar el molesto parpadeo de ventana negra (*console window flash*) que ocurre cuando Windows lanza scripts de PowerShell o archivos batch `.cmd`.

Sin embargo, **Microsoft ha anunciado oficialmente la deprecación de VBScript (Visual Basic Scripting Edition)**:
1. **Fase 1 (Windows 11 24H2 / 25H2):** VBScript fue convertido en una *Feature on Demand* (FOD). Aunque viene activado por defecto, puede ser desinstalado manualmente o por políticas corporativas de hardening.
2. **Fase 2 (~2027):** VBScript vendrá **deshabilitado por defecto** en nuevas instalaciones limpias de Windows.
3. **Fase 3 (Futuras versiones):** Eliminación total y permanente de `vbscript.dll` del sistema operativo.

El usuario ha solicitado que la solución adoptada esté **100% garantizada por Microsoft**, que no utilice tecnologías deprecadas ni flags no documentados (como `conhost.exe --headless`), y que proporcione una solución sólida a largo plazo.

---

## 2. Fundamento Técnico Oficial de Microsoft (PE Subsystem & Win32 API)

### A. La Causa Raíz del Parpadeo (*Console Flash*)
En la arquitectura oficial de Windows (PE/COFF Specification):
* Los ejecutables de consola (`powershell.exe`, `pwsh.exe`, `cmd.exe`) tienen en su cabecera PE el flag `IMAGE_SUBSYSTEM_WINDOWS_CUI` (Subsystem = 3).
* Cuando Windows (`kernel32!CreateProcess` y CSRSS) inicia un proceso Subsystem 3, **el sistema operativo reserva y dibuja una ventana de consola antes de que el código del programa comience a ejecutarse**. Por eso, parámetros como `-WindowStyle Hidden` siempre muestran un destello negro de 100-300 ms mientras el ejecutable arranca y procesa los argumentos.

### B. La Solución Oficial y Garantizada por Microsoft
La única vía documentada y garantizada por Microsoft para lanzar un proceso sin ventana es utilizar un ejecutable con cabecera `IMAGE_SUBSYSTEM_WINDOWS_GUI` (Subsystem = 2):
1. **Subsistema Gráfico (Subsystem 2):** Windows **nunca** crea ni asocia una ventana de consola al iniciar el proceso.
2. **Win32 API `CREATE_NO_WINDOW` (0x08000000):** Documentado oficialmente en Microsoft Learn. Cuando una aplicación GUI inicia un subproceso de consola mediante `ProcessStartInfo` con `CreateNoWindow = true` y `UseShellExecute = false`, el kernel de Windows suprime por completo la creación de la consola para el proceso hijo.
3. **Compilador Nativo de Windows (`csc.exe /target:winexe`):**
   * Windows 10 y 11 incluyen de fábrica el compilador C# de .NET Framework (`%SystemRoot%\Microsoft.NET\Framework64\v4.0.30319\csc.exe`).
   * .NET Framework 4.8.1 es un componente del sistema operativo con soporte permanente durante todo el ciclo de vida de Windows 11.
   * Compilar un archivo fuente de C# de ~25 líneas toma menos de **300 milisegundos**, genera un ejecutable de apenas **~7 KB** y **no requiere instalar ningún software adicional**.

### C. Cumplimiento con las Reglas del Repositorio (Regla 6)
Para cumplir con la **Regla 6 (Cero Binarios en Git)**:
* El repositorio almacena **exclusivamente el código fuente C#** en texto plano (`scripts/GUI/romanOS-Studio-Launcher.cs`).
* El ejecutable `Lanzar-romanOS-Studio.exe` ya está excluido por la regla `*.exe` de [.gitignore](file:///c:/OptimizedISO/.gitignore).
* `Lanzar-romanOS-Studio.cmd` verificará si existe el ejecutable; si no existe, invoca `csc.exe` silenciosamente para compilarlo al instante en el equipo local y ejecutarlo. El usuario también podrá hacer doble clic directamente sobre `Lanzar-romanOS-Studio.exe`.

---

## 3. Plan de Cambios Detallado

### Componente: Lanzador Gráfico Nativo ([scripts/GUI](file:///c:/OptimizedISO/scripts/GUI))

#### 1. [NUEVO] `scripts/GUI/romanOS-Studio-Launcher.cs`
Código fuente C# minimalista que implementa la creación de proceso con `CREATE_NO_WINDOW`:
* Verifica la existencia de `scripts\GUI\romanOS-Studio.ps1`.
* Localiza `powershell.exe` en `System32`.
* Configura `ProcessStartInfo`:
  * `UseShellExecute = false`
  * `CreateNoWindow = true`
  * `Arguments = "-WindowStyle Hidden -STA -NoProfile -ExecutionPolicy Bypass -File \"...\""`
* Inicia el proceso de forma asíncrona y finaliza inmediatamente (consumo 0 MB en reposo).

#### 2. [ELIMINAR] `Lanzar-romanOS-Studio.vbs`
* Eliminar de raíz el archivo VBScript para erradicar cualquier dependencia deprecada del repositorio.

#### 3. [MODIFICAR] `Lanzar-romanOS-Studio.cmd`
* Actualizar el script por lotes para que actúe como compilador JIT/Lanzador:
  1. Si `Lanzar-romanOS-Studio.exe` no existe, lo compila en frío invocando `%SystemRoot%\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe /optimize+ /out:Lanzar-romanOS-Studio.exe scripts\GUI\romanOS-Studio-Launcher.cs`.
  2. Ejecuta `start "" "%~dp0Lanzar-romanOS-Studio.exe"` y sale inmediatamente.

---

## 4. Plan de Verificación

1. **Compilación JIT:** Validar que `csc.exe` compila sin advertencias ni errores con `/target:winexe`.
2. **Ejecución Zero-Flash:**
   * Probar la ejecución directa de `Lanzar-romanOS-Studio.exe`.
   * Probar la ejecución a través de `Lanzar-romanOS-Studio.cmd`.
   * Confirmar que no aparece ningún parpadeo negro de consola y que `romanOS-Studio.ps1` abre su interfaz WPF Fluent Design con fluidez.
3. **Inspección de PE Subsystem:** Verificar con PowerShell que la cabecera PE del binario compilado tiene efectivamente el valor `0x0002` (`IMAGE_SUBSYSTEM_WINDOWS_GUI`).
4. **Verificación de Higiene Git:**
   * Ejecutar `git status` para comprobar que `Lanzar-romanOS-Studio.exe` está ignorado y no entra al índice.
   * Ejecutar `Invoke-TestSuite.ps1` para certificar que no se introducen regresiones de AST o BOM en el ecosistema.
