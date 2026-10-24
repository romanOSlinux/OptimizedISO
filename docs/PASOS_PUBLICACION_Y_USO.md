# 🚀 Guía de Pasos a Seguir: Publicación y Uso de romanOS v3.0 Universal

> **Documento Operativo de Referencia**  
> **Versión:** 3.0.0-universal | **Fecha:** 2026-10-24  
> **Estado del Código:** 100% Certificado, Merged a `main` y Etiquetado (`v3.0.0`).

---

## 📋 Resumen del Estado Actual

Todo el desarrollo de ingeniería, saneamiento de código, motor de snapshots, lanzadores universales y empaquetador portable fue completado con éxito:

1. **Rama `main`:** Sincronizada y al día en GitHub con 373 commits consolidados.
2. **Tags Oficiales:** Generados y enviados al remoto (`v3.0.0` y `v3.0.0-universal`).
3. **Respaldo Histórico:** Rama `archive/legacy-main-initial` archivada en GitHub.
4. **Higiene de Git:** Cero binarios pesados en el repositorio (100% código limpio).

---

## 🛠️ PASO 1: Habilitar el Repositorio como Público en GitHub

> [!IMPORTANT]
> **¿Por qué es necesario este paso?**  
> El comando Web 1-Liner:
> ```powershell
> irm https://raw.githubusercontent.com/romanOSlinux/OptimizedISO/main/Lanzar-romanOS.ps1 | iex
> ```
> Devuelve **HTTP 404 (No se encontró)** si el repositorio es **privado**, ya que GitHub bloquea el acceso anónimo a archivos raw de repositorios privados para proteger la privacidad del usuario.

### Instrucciones para cambiar la visibilidad:
1. Abre tu navegador e inicia sesión en GitHub.
2. Ve a la página de configuración del repositorio:  
   👉 **https://github.com/romanOSlinux/OptimizedISO/settings**
3. Desplázate hasta el final de la página (zona inferior) a la sección **Danger Zone**.
4. En la opción **Change repository visibility**, haz clic en el botón **Change visibility**.
5. Selecciona la opción **Make public**.
6. GitHub te solicitará escribir `romanOSlinux/OptimizedISO` para confirmar. Escríbelo y presiona **I understand, make this repository public**.

> [!TIP]
> **Efecto Inmediato:** En cuanto confirmes el cambio, el comando `irm ... | iex` comenzará a funcionar al instante en cualquier computadora con Windows sin pedir contraseña ni credenciales.

---

## 📦 PASO 2: Verificar el Release Oficial en GitHub

Al haber enviado los tags `v3.0.0` y `v3.0.0-universal`, el flujo automatizado de GitHub Actions (`release.yml`) se dispara para generar el Release.

1. Ve a la pestaña de Actions para verificar el progreso:  
   👉 **https://github.com/romanOSlinux/OptimizedISO/actions**
2. Una vez completado el workflow, visita la sección de Releases:  
   👉 **https://github.com/romanOSlinux/OptimizedISO/releases**
3. Confirma que el Release **`OptimizedISO v3.0.0`** esté publicado con su descripción oficial y archivos descargables.

---

## 💾 PASO 3: (Opcional) Subir el Paquete Portable USB al Release

Si deseas adjuntar manualmente el archivo ZIP portable generado localmente:

1. El archivo empaquetado portable se encuentra listo en tu PC:
   - **Ruta:** `C:\OptimizedISO\dist\romanOS-Universal-v3.0.0.zip` (2.72 MB)
   - **Manifiesto:** `C:\OptimizedISO\dist\romanOS-Universal-v3.0.0.zip.sha256`
2. En la página del Release en GitHub, haz clic en **Edit release**.
3. Arrastra y suelta el archivo `romanOS-Universal-v3.0.0.zip` y su `.sha256` en el área de **Attach binaries**.
4. Haz clic en **Update release** para guardar.

> [!NOTE]
> Este archivo ZIP contiene el árbol completo de ejecución autónoma offline (Lanzadores, Core, GUI WPF, Módulos, Drivers, Presets y utilidades de bajo nivel como Sysinternals y wimlib), excluyendo suites de prueba y basuras de desarrollo.

---

## 🎮 PASO 4: Métodos de Uso de romanOS v3.0

Una vez publicado, tienes **3 formas de uso** disponibles según la necesidad:

### Método A: Web 1-Liner (Recomendado para PCs ya instaladas)
Abre PowerShell (como Administrador o usuario estándar) y ejecuta:
```powershell
irm https://raw.githubusercontent.com/romanOSlinux/OptimizedISO/main/Lanzar-romanOS.ps1 | iex
```
*El lanzador auto-elevará privilegios si es necesario y abrirá directamente el Centro de Control Gráfico oficial.*

---

### Método B: Memoria USB / Pendrive Offline (Sin Internet)
Ideal para técnicos, técnicos de soporte o computadoras recién formateadas sin conexión a red:
1. Copia el contenido de `dist/romanOS-USB-Portable` (o descomprime el ZIP) en tu pendrive USB.
2. Conecta el pendrive en la PC objetivo.
3. Haz **doble clic en `Lanzar-romanOS.cmd`**.
4. Windows solicitará elevación UAC y se iniciará la interfaz gráfica a 60 FPS con todas las herramientas operativas.

---

### Método C: Compilador de ISOs Desatendidas (Zero-Touch)
Si deseas crear una imagen `.iso` de instalación limpia de Windows 11 o Windows 10 con todo preintegrado:
1. Abre PowerShell como Administrador en la raíz del proyecto.
2. Ejecuta:
```powershell
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Ruta\Tu_Windows11.iso" `
  -LocalUser "Usuario" `
  -LocalPassword "TuClave123" `
  -WindowsEdition "Pro"
```
3. La ISO resultante formateará el Disco 0, omitirá requisitos de TPM/RAM/CPU, saltará la cuenta Microsoft obligatoria y dejará el sistema optimizado desde el primer arranque.

---

## 🛡️ PASO 5: Prueba de Reversibilidad en 1 Clic (Garantía Cero Daño)

Para comprobar el principio de seguridad en cualquier máquina donde uses romanOS:

1. Abre el Centro de Control (`Lanzar-romanOS.cmd`).
2. Aplica cualquier ajuste o preset (ej. Presets Gaming o Tweaks de Red).
   - *El sistema creará automáticamente un snapshot preventivo obligatorio en segundo plano.*
3. Para regresar al estado inicial exactamente como estaba el equipo antes de abrir la aplicación:
   - Haz clic en el botón superior en la cabecera: **`↩ Revertir al Estado Inicial en 1 Clic`**.
   - Confirma la restauración.
   - El sistema restaurará el registro, servicios y configuración original de forma atómica.

---

## 📑 Documentos Relacionados para Consulta

- **Plan Maestro de Transición:** [`docs/plans/PLAN-0161-20261024-transicion-produccion-universal-y-sincronizacion-git.md`](file:///c:/OptimizedISO/docs/plans/PLAN-0161-20261024-transicion-produccion-universal-y-sincronizacion-git.md)
- **Manual de Usuario Completo:** [`docs/USAGE.md`](file:///c:/OptimizedISO/docs/USAGE.md)
- **README Principal:** [`README.md`](file:///c:/OptimizedISO/README.md)
- **Historial de Versiones:** [`docs/CHANGELOG.md`](file:///c:/OptimizedISO/docs/CHANGELOG.md)
