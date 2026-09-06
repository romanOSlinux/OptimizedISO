# 📋 Guía de Auditorías Técnicas — OptimizedISO

Estas plantillas están diseñadas para obtener auditorías **concretas y verificadas** de los scripts del proyecto.
Cópialas y pégalas directamente en el chat cuando necesites auditar un dominio.

---

> **Regla de oro para todas las auditorías:**
> La IA debe decir explícitamente "**NO VERIFICADO**" en cada punto que no pueda cruzar contra
> una fuente oficial. Si no lo dice, pedile que lo haga. Una revisión que dice "parece correcto"
> sin citar fuentes **no tiene valor**.

---

## 🔷 DOMINIO 1 — Schema de `autounattend.xml`

```
Necesito una auditoría del autounattend.xml que genera New-OptimizedWindowsISO.ps1.

Tu tarea concreta:
1. Lee el bloque de generación de XML en el script
   (busca las variables $unattendXml, $optimizeXml, $firstLogonXml, $oobeXml)
2. Consulta el schema oficial de Windows Answer Files en:
   https://learn.microsoft.com/windows-hardware/customize/desktop/wsim/answer-files-overview
   https://learn.microsoft.com/windows-hardware/customize/desktop/unattend/
3. Verifica CADA setting XML:
   - ¿El setting existe en el schema oficial de Windows 11?
   - ¿Está en el configuration pass CORRECTO? (windowsPE / specialize / oobeSystem)
   - ¿El valor asignado es del tipo correcto (boolean, string, integer)?
   - ¿El componente padre es el correcto?

Reporta ÚNICAMENTE errores con este formato:
| Línea | Setting | Problema | Fuente oficial |
|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
NO me digas que algo "parece correcto". Solo reporta discrepancias reales.
```

---

## 🔷 DOMINIO 2 — Comandos DISM.exe

```
Necesito una auditoría de todos los comandos DISM.exe en New-OptimizedWindowsISO.ps1.

Tu tarea concreta:
1. Extrae TODOS los comandos que invocan dism.exe o DISM.exe del script
2. Consulta la documentación oficial:
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/dism-image-management-command-line-options-s14
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/deployment-image-servicing-and-management--dism--technical-reference
3. Verifica para CADA invocación:
   - ¿Existen todos los flags usados en la versión actual del ADK?
   - ¿El orden de los parámetros es correcto?
   - ¿Se manejan correctamente los exit codes (0, 1641, 3010)?
   - ¿Se hace Unmount con /Commit después de cada Mount?
   - ¿Las operaciones sobre el WIM se hacen en el índice correcto?

Reporta con formato:
| Línea | Comando usado | Problema | Fuente |
|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🔷 DOMINIO 3 — Manipulación de archivos WIM

```
Necesito una auditoría de toda la lógica de manipulación de archivos WIM
en New-OptimizedWindowsISO.ps1.

Tu tarea concreta:
1. Lee todas las secciones del script que montan, modifican o desmontan install.wim / boot.wim
2. Consulta la documentación oficial:
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/work-with-windows-images
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/mount-and-modify-a-windows-image-using-dism
3. Verifica:
   - ¿Se montan las imágenes en rutas temporales correctas?
   - ¿Cada Mount tiene su Unmount /Commit o /Discard correspondiente?
   - ¿El script tiene manejo de error si el mount falla (directorio ya en uso)?
   - ¿Los índices WIM seleccionados corresponden a los esperados?
   - ¿Se limpian los puntos de montaje huérfanos con DISM /Cleanup-Mountpoints?

Reporta con formato:
| Línea | Operación | Problema | Fuente |
|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🔷 DOMINIO 4 — Construcción de ISO (oscdimg / xorriso)

```
Necesito una auditoría del comando de construcción de ISO en New-OptimizedWindowsISO.ps1.

Tu tarea concreta:
1. Encuentra el bloque donde se invoca oscdimg.exe o xorriso
2. Consulta la documentación oficial:
   Para oscdimg: https://learn.microsoft.com/windows-hardware/manufacture/desktop/oscdimg-command-line-options
   Para xorriso: https://www.gnu.org/software/xorriso/man_1_xorriso.html
3. Verifica CADA flag usado:
   - ¿El flag /bootdata o equivalente genera arranque UEFI + Legacy BIOS correctamente?
   - ¿Los archivos de boot (etfsboot.com, efisys.bin) están referenciados correctamente?
   - ¿La estructura de sectores es compatible con medios modernos (4Kn)?
   - ¿El resultado es una ISO válida para USB (compatible con Rufus/Ventoy)?

Reporta con formato:
| Parámetro | Problema | Comportamiento esperado | Fuente |
|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🔷 DOMINIO 5 — Claves de Registro (Bloatware / CDM / Privacy)

```
Necesito una auditoría de todas las claves de registro que escribe
Win11-Debloat-v3-Adaptive.ps1 y el bloque de registro de New-OptimizedWindowsISO.ps1.

Tu tarea concreta:
1. Extrae TODAS las rutas de registro y valores que se escriben en los scripts
2. Para cada clave, consulta:
   https://learn.microsoft.com/windows/privacy/manage-connections-from-windows-operating-system-components-to-microsoft-services
   https://learn.microsoft.com/windows/client-management/mdm/policy-csp-experience
   https://learn.microsoft.com/windows/client-management/group-policy-settings-reference-windows
3. Verifica para CADA clave:
   - ¿Existe realmente en Windows 11 24H2/25H2?
   - ¿El tipo de dato (DWORD, String, etc.) es correcto?
   - ¿El valor asignado produce el efecto documentado?
   - ¿Hay versiones donde esta clave fue eliminada o renombrada?

Reporta con formato:
| Clave de registro | Valor | Problema | Versión afectada | Fuente |
|---|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🔷 DOMINIO 6 — SetupComplete.cmd y contexto de ejecución

```
Necesito una auditoría del SetupComplete.cmd que genera New-OptimizedWindowsISO.ps1.

Tu tarea concreta:
1. Encuentra el bloque $setupCompleteTemplate en el script
2. Consulta la documentación oficial:
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/add-a-custom-script-to-windows-setup
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/windows-setup-command-line-options
3. Verifica:
   - ¿La ubicación $OEM$\$$\Setup\Scripts\SetupComplete.cmd es correcta para Windows 11?
   - ¿Los comandos schtasks usados tienen la sintaxis correcta para Windows 11?
   - ¿Qué variables de entorno están disponibles en el contexto SYSTEM de SetupComplete?
   - ¿Los paths %WINDIR%, %SystemRoot% son confiables en ese contexto?
   - ¿El acceso directo en C:\Users\Public\Desktop funciona para todos los usuarios?
   - ¿Hay comandos que puedan fallar silenciosamente sin que el log lo registre?

Reporta con formato:
| Línea | Comando | Problema | Fuente |
|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🔷 DOMINIO 7 — Particionado y Zero-Touch (DiskConfiguration)

```
Necesito una auditoría del bloque de particionado automático en el autounattend.xml
que genera New-OptimizedWindowsISO.ps1 (función Add-ImageInstallToAutounattend).

Tu tarea concreta:
1. Lee la función que genera el bloque <DiskConfiguration> del XML
2. Consulta la documentación oficial:
   https://learn.microsoft.com/windows-hardware/customize/desktop/unattend/microsoft-windows-setup-diskconfiguration
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/configure-uefigpt-based-hard-drive-partitions
3. Verifica:
   - ¿La partición EFI tiene el tamaño mínimo recomendado para discos 4Kn? (MS recomienda 300MB)
   - ¿La partición MSR tiene el tamaño correcto? (MS recomienda 16MB)
   - ¿El tipo y FileSystem (FAT32/NTFS) de cada partición son los correctos?
   - ¿El orden de las particiones en el XML coincide con el orden físico requerido?
   - ¿<InstallTo> referencia correctamente disco y partición de Windows?
   - ¿<AcceptEula>true</AcceptEula> está en el lugar correcto del XML?

Reporta con formato:
| Partición | Parámetro | Valor actual | Valor correcto | Fuente |
|---|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🔷 DOMINIO 8 — Manejo de Errores y Robustez

```
Necesito una auditoría de robustez y manejo de errores en New-OptimizedWindowsISO.ps1.

Tu tarea concreta:
1. Lee el script completo enfocándote SOLO en el flujo de errores
2. Referencia de mejores prácticas:
   https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-exceptions
3. Verifica:
   - ¿Cada operación destructiva (borrar archivos, montar WIM) tiene try/catch?
   - ¿Si falla un paso intermedio, el script limpia archivos temporales y puntos de montaje?
   - ¿Los exit codes de herramientas externas (DISM, oscdimg, reg.exe) se verifican?
   - ¿Hay algún punto donde el script puede quedar colgado sin timeout?
   - ¿Los bloques finally aseguran la limpieza incluso si ocurre una excepción?
   - ¿El log registra suficiente contexto para diagnosticar cualquier fallo?

Reporta con formato:
| Línea | Operación | Riesgo | Corrección sugerida |
|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🔷 DOMINIO 9 — Debloat AppX y Dependencias del Sistema

```
Necesito una auditoría de la lógica de debloat offline de paquetes AppX provisionados
en New-OptimizedWindowsISO.ps1 (Get-AppxProvisionedPackage / Remove-AppxProvisionedPackage).

Tu tarea concreta:
1. Lee el bloque de debloat offline AppX en el script (variables $protectedPatterns, $debloatList, $removablePkgs)
2. Consulta la documentación oficial:
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/dism-app-package-servicing-command-line-options
   https://learn.microsoft.com/windows/application-management/apps-in-windows-10
3. Verifica:
   - ¿Se protegen todas las dependencias críticas compartidas (Microsoft.VCLibs, Microsoft.UI.Xaml, .NET.Native)?
   - ¿Se protegen los componentes obligatorios del sistema en Windows 11 24H2/25H2 (ej. Microsoft.SecHealthUI, WindowsStore, DesktopAppInstaller)?
   - ¿La remoción offline con Remove-AppxProvisionedPackage afecta correctamente a todos los usuarios futuros?
   - ¿Se valida si un paquete es removible antes de ejecutar DISM para evitar errores 0x80070032?
   - ¿La distinción de paquetes por nivel de perfil (1, 2, 3) preserva la estabilidad de la shell (Explorer / Start Menu)?

Reporta con formato:
| Paquete / Lógica | Riesgo / Problema | Impacto en Win 11 24H2/25H2 | Fuente oficial |
|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🔷 DOMINIO 10 — Features on Demand (FOD) y .NET Framework 3.5

```
Necesito una auditoría de la inyección de .NET Framework 3.5 y la eliminación de FODs (Capabilities)
en New-OptimizedWindowsISO.ps1.

Tu tarea concreta:
1. Lee los bloques de habilitación de NetFx3 y eliminación de FOD en el script
2. Consulta la documentación oficial:
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/deploy-net-framework-35-by-using-deployment-image-servicing-and-management--dism
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/dism-capabilities-package-servicing-command-line-options
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/features-on-demand-v2--capabilities
3. Verifica:
   - ¿El comando para NetFx3 incluye /All y /LimitAccess para evitar consultas a Windows Update en entornos offline?
   - ¿La ruta hacia sources\sxs local de la ISO está validada antes de ejecutar el comando DISM?
   - ¿Los nombres de FOD a eliminar coinciden con las firmas exactas de Windows 11 (ej. App.StepsRecorder~~~~0.0.1.0, Browser.InternetExplorer~~~~0.0.11.0)?
   - ¿La eliminación de FODs se hace mediante /Remove-Capability en lugar del comando deprecado /Remove-Package?

Reporta con formato:
| Componente / FOD | Parámetro actual | Parámetro correcto | Fuente oficial |
|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🔷 DOMINIO 11 — Archivos de Configuración de Edición (`ei.cfg` y `PID.txt`)

```
Necesito una auditoría de la generación y sintaxis de ei.cfg y PID.txt en New-OptimizedWindowsISO.ps1.

Tu tarea concreta:
1. Revisa la sección donde se crea/modifica sources\ei.cfg y sources\PID.txt
2. Consulta la documentación oficial:
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/windows-setup-edition-configuration-and-product-id-files-eicfg-and-pidtxt
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/default-product-keys-for-windows-deployment
3. Verifica:
   - ¿La estructura de secciones [EditionID], [Channel] y [VL] cumple con el formato exigido por Windows Setup?
   - ¿Los valores de canal ([Channel]) son estrictamente "OEM", "Retail" o "Volume"?
   - ¿El valor de [VL] es binario ("0" o "1")?
   - ¿Se maneja adecuadamente la interacción entre ei.cfg, autounattend.xml y la tabla MSDM de la placa base (UEFI BIOS)?
   - ¿El formato de codificación del archivo (ASCII / ANSI) es el soportado por el motor de setup en boot?

Reporta con formato:
| Sección / Archivo | Configuración actual | Comportamiento en Windows Setup | Fuente oficial |
|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🔷 DOMINIO 12 — Inyección Offline de Drivers y Actualizaciones (.MSU / .CAB / SSU)

```
Necesito una auditoría del slipstreaming de drivers y paquetes de actualización
en New-OptimizedWindowsISO.ps1.

Tu tarea concreta:
1. Revisa las secciones que inyectan controladores (.inf) y actualizaciones (.msu/.cab) en install.wim / boot.wim
2. Consulta la documentación oficial:
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/add-and-remove-drivers-to-an-offline-windows-image
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/add-or-remove-packages-offline-using-dism
   https://learn.microsoft.com/windows/deployment/update/servicing-stack-updates
3. Verifica:
   - ¿La inyección de drivers usa /Add-Driver con /Recurse y maneja firmas de forma segura (/ForceUnsigned)?
   - ¿Se respeta el orden de precedencia entre Servicing Stack Updates (SSU) y Cumulative Updates (LCU)?
   - ¿Se valida la arquitectura del paquete/driver frente a la arquitectura de la imagen de destino (x64/ARM64)?
   - ¿El script captura códigos de salida especiales de DISM para paquetes ya reemplazados (superseded)?

Reporta con formato:
| Línea | Operación | Riesgo / Deficiencia | Fuente oficial |
|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🔷 DOMINIO 13 — Bypass de Requisitos de Hardware en Windows 11 (WinPE & Setup)

```
Necesito una auditoría de las técnicas de bypass de TPM 2.0, SecureBoot, RAM, CPU y Almacenamiento
generadas en New-OptimizedWindowsISO.ps1 y autounattend.xml.

Tu tarea concreta:
1. Examina todas las claves de registro inyectadas en HKLM\SYSTEM\Setup\LabConfig y HKLM\SYSTEM\Setup\MoSetup
2. Consulta la documentación oficial y notas de compatibilidad:
   https://support.microsoft.com/windows/ways-to-install-windows-11-e0edbbfb-cfc5-4011-868b-2ce77ac7c70e
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/windows-11-minimum-hardware-requirements
3. Verifica:
   - ¿Los nombres de los valores DWORD en LabConfig son exactos (BypassTPMCheck, BypassSecureBootCheck, BypassRAMCheck, BypassStorageCheck, BypassCPUCheck)?
   - ¿Se inyectan en el momento exacto (pass windowsPE previo a la inicialización de Setup.exe)?
   - ¿Se contempla la compatibilidad con Windows 11 24H2/25H2 respecto al set de instrucciones SSE4.2 / POPCNT?
   - ¿La clave AllowUpgradesWithUnsupportedTPMOrCPU está presente si se ejecutan actualizaciones in-place?

Reporta con formato:
| Clave / Valor | Pass / Contexto | Estado en 24H2/25H2 | Fuente oficial |
|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🔷 DOMINIO 14 — Mapeo y Manipulación Offline de Colmenas del Registro

```
Necesito una auditoría de las rutinas de carga, edición y descarga de colmenas de registro offline
(NTUSER.DAT / DEFAULT / SYSTEM / SOFTWARE) en New-OptimizedWindowsISO.ps1.

Tu tarea concreta:
1. Inspecciona las llamadas a reg.exe load, reg.exe unload, y la función Invoke-RegUnloadHive
2. Consulta la documentación técnica:
   https://learn.microsoft.com/windows-server/administration/windows-commands/reg-load
   https://learn.microsoft.com/windows-server/administration/windows-commands/reg-unload
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/customize-the-default-user-profile-by-using-copyprofile
3. Verifica:
   - ¿Se liberan todos los descriptores de archivo (handles) y variables de PowerShell antes de ejecutar reg unload?
   - ¿Se contempla el recolector de basura ([gc]::Collect()) para evitar bloqueos por parte del proceso anfitrión?
   - ¿Las modificaciones en Default User (NTUSER.DAT) se aplican sobre la ruta correcta (HKLM\OfflineDefaultUser\Software\...) sin corromper la colmena?
   - ¿Los tipos de datos (REG_SZ vs REG_DWORD vs REG_EXPAND_SZ) coinciden con lo que espera el subsistema de Windows?

Reporta con formato:
| Línea | Operación Registro | Riesgo de Bloqueo / Corrupción | Mitigación sugerida |
|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🔷 DOMINIO 15 — Consolidación, Compresión y Gestión Multi-Índice de WIM

```
Necesito una auditoría del proceso de exportación y optimización final de install.wim
en New-OptimizedWindowsISO.ps1 (Export-WindowsImage / DISM /Export-Image).

Tu tarea concreta:
1. Lee el bloque de consolidación final del WIM en el script
2. Consulta la documentación oficial:
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/dism-image-management-command-line-options-s14
   https://learn.microsoft.com/powershell/module/dism/export-windowsimage
3. Verifica:
   - ¿El tipo de compresión seleccionado (/Compress:max vs /Compress:recovery vs /Compress:fast) es compatible con arranque UEFI estándar?
   - ¿Se eliminan adecuadamente los recursos huérfanos (dead space) generados por la remoción de paquetes y FODs?
   - ¿Se conservan los metadatos obligatorios de la edición (Name, Description, Flags de SKU)?
   - ¿Existe un mecanismo de respaldo/rollback seguro (.bak) que evite la pérdida de la imagen si el disco se llena durante la exportación?

Reporta con formato:
| Parámetro / Paso | Problema detectado | Impacto en tamaño / arranque | Fuente oficial |
|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🔷 DOMINIO 16 — Reconstrucción de ISO con oscdimg.exe (Arranque Dual BIOS+UEFI)

```
Necesito una auditoría del bloque de reconstrucción final de la ISO mediante oscdimg.exe
en New-OptimizedWindowsISO.ps1.

Tu tarea concreta:
1. Lee el bloque "6/6 - Reconstruyendo ISO" (busca oscdimg, etfsboot.com, efisys.bin, -bootdata)
2. Consulta la documentación oficial:
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/oscdimg-command-line-options
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/windows-setup-technical-reference
3. Verifica:
   - ¿El flag -bootdata combina correctamente el sector de arranque BIOS (etfsboot.com) y el
     catálogo de arranque UEFI (efisys.bin) en el mismo comando (-bootdata:2#p0,e,b...#pEF,e,b...)?
   - ¿El flag -u2 -udfver102 produce un sistema de archivos UDF 1.02 + ISO 9660 compatible
     con arranque UEFI Secure Boot en firmware moderno?
   - ¿Se valida la existencia de etfsboot.com y efisys.bin antes de ejecutar oscdimg?
   - ¿El hash SHA256 se calcula y reporta al finalizar para verificación de integridad?
   - ¿Se maneja correctamente el fallo si oscdimg.exe no está instalado o si el disco no
     tiene espacio suficiente?

Reporta con formato:
| Flag / Paso | Problema detectado | Impacto en arranque UEFI/BIOS | Fuente oficial |
|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🔷 DOMINIO 17 — Instalación y Resolución de Dependencias (winget / ADK)

```
Necesito una auditoría de la función Install-Dependencies y la resolución automática de
oscdimg.exe en New-OptimizedWindowsISO.ps1.

Tu tarea concreta:
1. Lee la función Install-Dependencies (busca winget, 7-Zip, oscdimg, ADK, Test-OSCDImgInstalled)
2. Consulta la documentación oficial:
   https://learn.microsoft.com/windows/package-manager/winget/
   https://learn.microsoft.com/windows-hardware/get-started/adk-install
3. Verifica:
   - ¿La instalación de 7-Zip vía winget usa los flags correctos para modo silencioso
     (--silent --accept-package-agreements --accept-source-agreements)?
   - ¿La búsqueda de oscdimg.exe cubre todas las rutas estándar del Windows ADK
     (Program Files\Windows Kits\10\...\amd64\Oscdimg\ y x86)?
   - ¿Se valida adecuadamente que winget está disponible antes de intentar instalaciones,
     con un mensaje de error claro si no lo está?
   - ¿El script falla elegantemente (sin excepción terminante) si las dependencias no
     pueden instalarse automáticamente?
   - ¿Se contempla el caso de ARM64 para la ruta de oscdimg.exe en el ADK?

Reporta con formato:
| Dependencia / Paso | Problema detectado | Impacto en ejecución | Fuente oficial |
|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🔷 DOMINIO 18 — Modo Zero-Touch y Particionado Automático GPT/UEFI

```
Necesito una auditoría del modo Zero-Touch y la función Add-ImageInstallToAutounattend
en New-OptimizedWindowsISO.ps1.

Tu tarea concreta:
1. Lee la función Add-ImageInstallToAutounattend y el bloque de selección de índice final
   (busca ZeroTouch, CreatePartitions, ModifyPartitions, ImageInstall, finalImageInstallIndex)
2. Consulta la documentación oficial:
   https://learn.microsoft.com/windows-hardware/customize/desktop/unattend/microsoft-windows-setup-imageinstall-dataimage-installto
   https://learn.microsoft.com/windows-hardware/manufacture/desktop/configure-uefigpt-based-hard-drive-partitions
   https://learn.microsoft.com/windows-hardware/customize/desktop/unattend/microsoft-windows-setup-diskconfiguration
3. Verifica:
   - ¿El esquema de particionado GPT generado para Zero-Touch (EFI System Partition, MSR,
     partición de Windows, partición de Recuperación) cumple el orden y tamaños mínimos
     recomendados por Microsoft para Windows 11 (EFI ≥ 100 MB, MSR = 16 MB, Recovery ≥ 500 MB)?
   - ¿El nodo <ImageInstall> apunta al índice correcto tras la exportación WIM (reindexación a 1)?
   - ¿El parámetro $ZeroTouchDisk se inyecta correctamente como DiskID numérico en el XML?
   - ¿Existe una advertencia clara al usuario de que el Disco $ZeroTouchDisk será formateado
     por completo durante el modo Zero-Touch?
   - ¿El modo Zero-Touch solo se activa para índice único (no multi-índice) y falla con
     mensaje claro si se intenta con varios índices?

Reporta con formato:
| Elemento XML / Parámetro | Problema detectado | Riesgo de pérdida de datos / fallo de arranque | Fuente oficial |
|---|---|---|---|

Si no podés verificar algo, escribe "NO VERIFICADO".
```

---

## 🌐 Fuentes y Dominios Oficiales de Microsoft Recomendados


Para garantizar auditorías profesionales con **cero suposiciones**, utilizar exclusivamente estas referencias:

1. **DISM e Imágenes:** [`https://learn.microsoft.com/windows-hardware/manufacture/desktop/`](https://learn.microsoft.com/windows-hardware/manufacture/desktop/)
2. **Esquema de Unattend y WSIM:** [`https://learn.microsoft.com/windows-hardware/customize/desktop/unattend/`](https://learn.microsoft.com/windows-hardware/customize/desktop/unattend/)
3. **GPO, MDM y Privacidad:** [`https://learn.microsoft.com/windows/client-management/`](https://learn.microsoft.com/windows/client-management/)
4. **Comandos de Windows Server:** [`https://learn.microsoft.com/windows-server/administration/windows-commands/`](https://learn.microsoft.com/windows-server/administration/windows-commands/)
5. **PowerShell DISM:** [`https://learn.microsoft.com/powershell/module/dism/`](https://learn.microsoft.com/powershell/module/dism/)
6. **Soporte Oficial de Windows:** [`https://support.microsoft.com/windows/`](https://support.microsoft.com/windows/)

---

## 📌 Instrucciones de uso

1. **Copia el bloque del dominio que necesitás auditar**
2. **Pégalo en el chat**  
3. **Esperá a que el análisis esté completo antes de pedir el siguiente dominio**
4. **Si la IA dice "parece correcto" sin citar fuente → respondele:**
   > *"Marcá ese punto como NO VERIFICADO. No me digas que parece correcto, decime si pudiste o no verificarlo contra la fuente oficial."*

---

## ⚠️ Señales de que la auditoría NO está siendo profunda

- Dice "la sintaxis es válida" sin verificar semántica
- No cita URLs específicas de documentación  
- Dice "esto debería funcionar" sin verificarlo
- No menciona versiones específicas (24H2 vs 25H2)
- No encuentra ningún problema — scripts de esta complejidad siempre tienen algo

