# PLAN-0082: Reparación de Instalación Zero-Touch en romanOS Studio (Escape de Entidades XML y Paridad Multi-Edición)

**Fecha:** 2026-09-14  
**Estado:** COMPLETADO  
**Autor:** Antigravity / romanOS Software Engineering  
**Hito:** romanOS Studio / Despliegue Desatendido (Zero-Touch)  

---

## 1. Contexto y Diagnóstico Forense

### 1.1 Síntoma Reportado por el Usuario
Al compilar una ISO desde **romanOS Studio** con la opción `Habilitar Instalación 100% Zero-Touch (Automatización Total sin Intervención)` activada, la instalación de Windows booteada desde el medio resultante continúa solicitando:
1. Aceptación interactiva de Términos y Condiciones de Licencia (EULA).
2. Selección y particionado manual de disco.

### 1.2 Análisis Forense de Logs y Causa Raíz Matemática
La inspección física del log de compilación más reciente (`ISO_Build_20260914_160718.log`) reveló el siguiente registro crítico en la línea 91:
```
[2026-09-14 16:16:52] [WARN ] Error inyectando configuración en autounattend.xml: No se puede convertir el valor "..." al tipo "System.Xml.XmlDocument". Error: "Error al analizar EntityName. línea 101, posición 127."
[2026-09-14 16:16:52] [WARN ] No se pudo inyectar configuración en autounattend.xml.
```

Al cruzar la posición 127 de la línea 101 del XML generado con el código fuente del generador de `autounattend.xml`, se aisló el problema exacto:
- En el commit `717c41b` (*PLAN-0078: Purga profunda y bloqueo de OneDrive*), se añadió el siguiente comando síncrono al bloque `$oneDriveXml`:
  ```xml
  <Path>cmd.exe /c "reg delete HKU\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Run /v OneDriveSetup /f >nul 2>&1 || exit 0"</Path>
  ```
- En XML, el carácter ampersand (`&`) es un delimitador de entidad reservado. La secuencia `&1` (de `2>&1`) y los operadores de redirección `>` provocan que el parser `[xml]` de .NET falle inmediatamente con `XmlException: Error al analizar EntityName`.
- Como consecuencia, cuando `Add-ImageInstallToAutounattend` intentó cargar el archivo `autounattend.xml` para inyectar el modo Zero-Touch:
  1. El archivo falló en `[xml]$xmlDoc = Get-Content -Path $AutounattendPath -Raw -Encoding UTF8`.
  2. El bloque `catch` capturó el error y retornó `$false`.
  3. **NUNCA** se inyectó el bloque `<DiskConfiguration>` (particionado UEFI/GPT automático con WinRE 500 MB).
  4. **NUNCA** se inyectó el bloque `<UserData><AcceptEula>true</AcceptEula></UserData>`.
  5. **NUNCA** se inyectó el bloque `<ImageInstall>` con `/IMAGE/INDEX`.
  6. La ISO se compiló con un archivo `autounattend.xml` sintácticamente corrupto, provocando que el instalador de Windows cayera por completo en el asistente manual tradicional.

### 1.3 Causa Secundaria de UX / Arquitectura en romanOS Studio
- En `scripts/GUI/romanOS-Studio.ps1`, el análisis de ISO (`Invoke-WimDiscoveryAsync`) marca todas las ediciones por defecto en `lbxWimEditions` (`$cb.IsChecked = $true`).
- Si un usuario activa Zero-Touch en la Pestaña 2 pero no desmarca ediciones en la Pestaña 1, `Get-StudioBuildConfig` envía `TargetWimIndex = 'all'`.
- En el motor de compilación (`New-OptimizedWindowsISO-GUI-Engine.ps1`), si hay más de una edición (`$indexesToProcess.Count -gt 1`), `$selectedSingleIndex` es `$null`, lo que provoca que la condición `if ($selectedSingleIndex -and $wimInjected)` omita Zero-Touch silenciosamente sin advertir al usuario.
- Además, exigir estrictamente `$wimInjected` para inyectar Zero-Touch bloquea la automatización en ISOs que usan `install.esd` o en casos donde no se requiere modificar el WIM offline.

---

## 2. Objetivos de la Implementación

1. **Corrección de Entidades XML (Causa Raíz Crítica):**
   Escapar de forma estricta los caracteres especiales XML (`&gt;`, `&amp;`, `&quot;`) en la directiva de eliminación de OneDrive en `scripts/Builder/New-OptimizedWindowsISO-GUI-Engine.ps1` y `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`.
2. **Robustez y Desacoplamiento de Zero-Touch:**
   Permitir que la inyección de `Add-ImageInstallToAutounattend` proceda para un índice seleccionado independientemente de `$wimInjected` (ej. medios con `install.esd` o compilaciones sin servicing offline).
3. **Validación y UX en romanOS Studio:**
   - Si el usuario marca `Habilitar Instalación 100% Zero-Touch` y tiene múltiples ediciones marcadas en `lbxWimEditions`, advertir claramente en la interfaz y/o seleccionar por defecto una edición única para asegurar que la ISO no caiga en el modo interactivo.
   - En `btnBuild.Add_Click`, validar antes de compilar si `ZeroTouch` está activo con `TargetWimIndex = 'all'`, alertando al usuario para que confirme qué edición desea instalar automáticamente.
4. **Validación Automatizada y Suite de Pruebas:**
   - Incorporar una prueba unitaria de validación XML para `autounattend.xml` generado con `BlockOneDrive = $true` y `ZeroTouch = $true` en `scripts/Testing/Test-OptimizedISO-v2.ps1`.
   - Verificar con `Test-UnattendXml.ps1` que el archivo resultante sea 100% conforme con el esquema de Microsoft Setup.

---

## 3. Plan de Cambios Detallado

### Componente 1: Motores de Compilación de ISO (`New-OptimizedWindowsISO-GUI-Engine.ps1` y `New-OptimizedWindowsISO-v2.ps1`)
- **Escapar Entidades XML:** Modificar la línea 5212 (GUI-Engine) y 5186 (v2) de:
  ```xml
  <Path>cmd.exe /c "reg delete HKU\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Run /v OneDriveSetup /f >nul 2>&1 || exit 0"</Path>
  ```
  a:
  ```xml
  <Path>cmd.exe /c &quot;reg delete HKU\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Run /v OneDriveSetup /f &gt;nul 2&gt;&amp;1 || exit 0&quot;</Path>
  ```
- **Aislamiento y Advertencia en Multi-Edición:**
  Si `$enableZT` es `$true` pero `$selectedSingleIndex` es `$null` debido a que se compilaron múltiples ediciones, emitir un mensaje explícito:
  `Write-Warn "Zero-Touch fue solicitado pero hay múltiples ediciones seleccionadas. Zero-Touch requiere un único índice WIM para automatizar la instalación completa sin preguntar al usuario."`
- **Desacoplamiento de `$wimInjected`:**
  En la evaluación de `$finalImageInstallIndex`:
  ```powershell
  if ($selectedSingleIndex) {
      if ($WimCompression -eq "None" -or -not $wimInjected) {
          $finalImageInstallIndex = [int]$selectedSingleIndex
      } elseif ($exportSucceeded) {
          $finalImageInstallIndex = 1
      } else {
          $finalImageInstallIndex = [int]$selectedSingleIndex
      }
  }
  ```

### Componente 2: Interfaz romanOS Studio (`scripts/GUI/romanOS-Studio.ps1`)
- **Validación Preventiva en `btnBuild.Add_Click`:**
  Si `$config.ZeroTouch` es `$true` y `$config.TargetWimIndex` es `'all'` (o contiene más de un índice):
  Mostrar un diálogo informativo amigable al usuario:
  *"Ha habilitado la instalación 100% Zero-Touch, pero tiene seleccionadas múltiples ediciones en la pestaña 'Construcción Base'. Para una instalación 100% desatendida sin intervención humana, debe seleccionar una única edición a instalar. ¿Desea continuar e instalar la primera edición por defecto o prefiere seleccionar la edición manualmente?"*
- **Soporte Visual:** Mostrar un aviso explicativo en la Pestaña 2 junto al checkbox de Zero-Touch.

### Componente 3: Pruebas y Validación (`Test-OptimizedISO-v2.ps1` y `Test-UnattendXml.ps1`)
- Añadir verificación automatizada en `scripts/Testing/Test-OptimizedISO-v2.ps1` que genere la plantilla `autounattend.xml` con `BlockOneDrive = $true` y verifique que `[xml]` no arroje errores de análisis.
- Comprobar que tras llamar `Add-ImageInstallToAutounattend`, los nodos `<DiskConfiguration>`, `<AcceptEula>true</AcceptEula>` e `<ImageInstall>` estén presentes y bien ubicados.

---

## 4. Matriz de Verificación

| Prueba | Comando / Herramienta | Criterio de Éxito |
|---|---|---|
| Sintaxis XML con OneDrive | `scratch/test_add_imageinstall.ps1` | `Add-ImageInstallToAutounattend: True` |
| Esquema UEFI GPT | `Test-UnattendXml.ps1` | `VALIDACION EXITOSA: 4 particiones GPT y cero etiquetas obsoletas` |
| Parser PowerShell 5.1 | `powershell.exe -STA -NoProfile -Command "..."` | Cero `ParserError` ni excepciones de codificación |
| Suite de Pruebas General | `scripts/Testing/Invoke-TestSuite.ps1` | PASS integral en pruebas unitarias del ecosistema |
