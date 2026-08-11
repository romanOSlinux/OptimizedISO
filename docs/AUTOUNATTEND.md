# Arquitectura de `autounattend.xml` (Zero-Touch Setup)

El archivo `autounattend.xml` generado dinámicamente por el script `New-OptimizedWindowsISO.ps1` es el cerebro que permite que la instalación de Windows sea **completamente desatendida** y omita las severas restricciones impuestas por Microsoft.

A continuación se documenta exactamente qué acciones realiza en cada una de las fases críticas de la instalación de Windows (Pases de Configuración).

---

## 1. Fase `windowsPE` (Pre-instalación)
Esta es la primera fase que se ejecuta al arrancar desde la ISO.

- **Configuración Regional:** Configura el idioma de la interfaz (UI), teclado y formatos regionales sin preguntarle al usuario.
- **Bypass de Hardware (Elusión de Restricciones):** 
  Inyecta instrucciones al registro (`HKLM\SYSTEM\Setup\LabConfig`) antes de que el instalador verifique tu hardware. Esto permite instalar Windows 11 en cualquier PC vieja, bloqueando los chequeos de:
  - **TPM 2.0** (`BypassTPMCheck`)
  - **Arranque Seguro / Secure Boot** (`BypassSecureBootCheck`)
  - **RAM mínima** (`BypassRAMCheck`)
  - **CPU soportada** (`BypassCPUCheck`)
  - **Almacenamiento y Disco** (`BypassStorageCheck` y `BypassDiskCheck`)
- Habilita las actualizaciones sobre hardware no soportado (`AllowUpgradesWithUnsupportedTPMOrCPU`).

## 2. Fase `specialize` (Configuración del SO base)
Ocurre después del formateo, durante el primer inicio real de Windows.

- **Bypass de Cuenta Microsoft (NRO):** Inyecta la directiva `BypassNRO` en el registro. Esto le dice a Windows que no exija una conexión a internet ni fuerce la creación de una cuenta en la nube de Microsoft.
- **Prevención de Bloatware (OneDrive):** Si el usuario lo eligió, borra los binarios de autoinstalación de OneDrive antes de que el sistema logre iniciar el asistente.
- **Deshabilitación de Hibernación:** Ejecuta `powercfg -h off` para eliminar la creación del archivo `hiberfil.sys`, recuperando entre el 40% y 75% del tamaño de tu RAM en espacio de disco SSD/NVMe.
- **Plan de Alto Rendimiento:** Fuerza el perfil de energía "High Performance" (`powercfg -setactive`) para que la CPU opere al 100% desde el primer arranque, acelerando la descompresión de archivos y la ejecución de los scripts post-instalación.
- **Bloqueo de Privacy Experience (Scoobe):** Inyecta la política `DisablePrivacyExperience` para evitar permanentemente las pantallas a pantalla completa que Windows 11 muestra días después pidiéndote "Terminar de configurar tu dispositivo".
- **Identidad de PC:** Asigna un nombre aleatorio al equipo (`*`), define la organización como "Optimized", y aplica tu Zona Horaria.

## 3. Fase `oobeSystem` (Experiencia de Primer Uso)
Ocurre en la pantalla final donde normalmente Cortana o los menús de privacidad te hacen preguntas.

- **Creación de Cuenta Local:** Crea nativamente la cuenta de usuario con privilegios de Administrador local y tu contraseña (codificada de forma segura).
- **AutoLogon:** Fuerza al sistema a iniciar sesión automáticamente en esta cuenta sin pedir contraseña en el primer reinicio.
- **Ocultamiento Total (Zero-Touch):** Oculta y acepta en silencio todas las pantallas molestas:
  - `HideEULAPage` (Acepta la licencia)
  - `HideOEMRegistrationScreen` (Omite registro del fabricante)
  - `HideOnlineAccountScreens` (Fuerza cuenta local)
  - `HideWirelessSetupInOOBE` (Omite conectarse al Wi-Fi)
  - `ProtectYourPC=3` (Desactiva la telemetría forzada del asistente).

## Conclusión Técnica
El script no utiliza "hacks" destructivos. Utiliza estrictamente la sintaxis oficial documentada en el **Windows ADK (Assessment and Deployment Kit)** para automatizar corporativamente la instalación. Todas las etiquetas y bloqueos implementados se basan en políticas oficiales de despliegue de Microsoft.
