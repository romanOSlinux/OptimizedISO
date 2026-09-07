# PLAN-0044: Resilient Bootloader Discovery (BIOS/UEFI), Auto-Inyección de Arranque y Salvaguarda Anti-Pérdida de Trabajo en Builder ISO

**Fecha:** 2026-09-06  
**Estado:** COMPLETADO  
**Componente:** `scripts/Builder/New-OptimizedWindowsISO-v2.ps1`  
**Objetivo:** Eliminar de forma definitiva los fallos de arranque en el Paso 6/6 del Builder ISO mediante búsqueda simétrica multi-candidato de bootloaders, auto-inyección preventiva y salvaguarda de preservación de archivos ante fallos de empaquetado.

---

## 1. Contexto y Causa Raíz del Problema

Durante la ejecución de compilaciones complejas con slipstreaming de actualizaciones (procesos que demoran entre 25 y 50 minutos debido a la arquitectura transaccional CBS de Microsoft), se detectó que el proceso abortó en el Paso 6/6 (a los 52 minutos de ejecución) emitiendo las siguientes advertencias:

```text
[WARN] Faltan archivos de arranque críticos en la ISO extraída o en el sistema.
[WARN] Ruta BIOS esperada: C:\Users\Thiago\AppData\Local\Temp\WinISO_Extract_20260906_224213\ISO_Files\boot\etfsboot.com
[WARN] Ruta UEFI esperada: C:\Users\Thiago\AppData\Local\Temp\WinISO_Extract_20260906_224213\ISO_Files\efi\microsoft\boot\efisys_noprompt.bin O C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\efisys_noprompt.bin ...
[WARN] No se generará una ISO no arrancable.
```

### Análisis Técnico de la Falla:
1. **Asimetría Arquitectónica:**
   - **UEFI:** Cuenta con un array de candidatos `$candidateUefiBoot` que busca en la ISO y realiza fallback a las rutas oficiales del Windows ADK (`C:\Program Files (x86)\Windows Kits\10\...`). En el sistema host, el archivo `efisys_noprompt.bin` del ADK **SÍ existía** y fue localizado exitosamente (`Test-Path = True`).
   - **BIOS:** Hardcodeado rígidamente a una única ruta: `$biosBootFile = Join-Path $ISOFilesDir "boot\etfsboot.com"`. No disponía de lista de candidatos ni de fallback al Windows ADK ni a la carpeta de `oscdimg.exe`.
2. **Disponibilidad Real en el Host:**
   - El archivo `etfsboot.com` **SÍ estaba presente** en el sistema en `C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\etfsboot.com`, pero el script nunca lo consultó.
3. **Pérdida Catastrófica de Trabajo (Anti-workloss gap):**
   - Al fallar la condición combinada, el script abortó la llamada a `oscdimg.exe` e invocó la rutina de limpieza final, borrando `$ExtractDir` y destruyendo el archivo `install.wim` parcheado y consolidado tras casi una hora de procesamiento continuo.

---

## 2. Especificación Técnica de la Solución

### A. Búsqueda Simétrica Multi-Candidato para Bootloader BIOS
Definir `$candidateBiosBoot` análogo a UEFI, buscando en:
1. `$ISOFilesDir\boot\etfsboot.com` (Ubicación estándar extraída)
2. Búsqueda recursiva en `$ISOFilesDir` por `etfsboot.com`
3. Directorio padre de `oscdimg.exe` resuelto (`Split-Path $oscdimg -Parent`)
4. `${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\etfsboot.com`
5. `$env:ProgramFiles\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\etfsboot.com`
6. `${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg\etfsboot.com`
7. `$env:ProgramFiles\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg\etfsboot.com`
8. `${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\arm64\Oscdimg\etfsboot.com`

### B. Búsqueda Expandida para Bootloader UEFI
Añadir a `$candidateUefiBoot`:
- Carpeta del ejecutable `oscdimg.exe` resuelto (`efisys_noprompt.bin` y `efisys.bin`)
- Búsqueda recursiva en `$ISOFilesDir` por `efisys_noprompt.bin` y `efisys.bin`
- Rutas ADK x86 y ARM64 como fallbacks adicionales

### C. Auto-Inyección y Reparación Preventiva de la Estructura ISO
Si los bootloaders son recuperados desde el ADK o desde la carpeta de `oscdimg`:
- Asegurar la existencia de `$ISOFilesDir\boot\` y copiar físicamente `etfsboot.com` si falta en dicha carpeta.
- Asegurar la existencia de `$ISOFilesDir\efi\microsoft\boot\` y copiar físicamente el archivo `efisys.bin` / `efisys_noprompt.bin` si falta.
- Esto garantiza que tanto la línea de comandos de `oscdimg` como el árbol de directorios de la imagen resultante sean 100% compatibles con herramientas de booteo como Rufus, Ventoy o grabación directa en medios USB/DVD.

### D. Diagnóstico Desacoplado y Preciso
Separar la validación lógica:
- Comprobar independientemente BIOS y registrar mensaje específico si falta `etfsboot.com`.
- Comprobar independientemente UEFI y registrar mensaje específico si falta `efisys.bin`.
- Evitar imprimir avisos de UEFI cuando el bootloader UEFI sí fue resuelto exitosamente.

### E. Salvaguarda Anti-Pérdida de Trabajo (Work-Preservation Guard)
En el bloque de limpieza final:
- Si `$isoCreated` es `$false` y el usuario no especificó `-ForceCleanup`:
  - **NO** eliminar `$ExtractDir`.
  - Notificar de forma visible y destacada:
    `[AVISO DE SEGURIDAD] La ISO no se pudo empaquetar, pero el WIM actualizado y los archivos preparados SE HAN PRESERVADO en: <Ruta>`
  - Imprimir la línea exacta de comando de `oscdimg` para que el usuario pueda compilar manualmente en 15 segundos sin repetir el slipstreaming de actualizaciones.

---

## 3. Plan de Verificación Empírica

1. **Test Sintético en PowerShell 5.1 (Regla 4):**
   - Ejecutar prueba aislada en `powershell.exe -STA -NoProfile` validando la resolución de `candidateBiosBoot` y `candidateUefiBoot` con los archivos existentes en el sistema host.
2. **Validación de Sintaxis y Quoting con oscdimg:**
   - Verificar la construcción de la cadena `-bootdata:2#p0,e,b"..."#pEF,e,b"..."` garantizando que no existan colisiones de comillas ni rutas vacías.
3. **Prueba en Frío con `-WhatIf` / Parámetros Controlados:**
   - Verificar el flujo de ejecución completo en el runtime de destino.
