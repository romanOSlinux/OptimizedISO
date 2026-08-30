# Guía Maestra de Bootstrap y Restauración de Antigravity en Windows 11

Esta guía documenta el procedimiento paso a paso para respaldar tu trabajo antes de formatear y restaurar el entorno completo de **Antigravity** y **OptimizedISO** en una instalación limpia de Windows 11 con **1 solo comando**.

---

## 🛑 FASE 0: Acciones Obligatorias ANTES de Formatear tu PC Actual

Para no perder avances, código ni historial de desarrollo:

### 1. Asegurar y Subir todos los Cambios a Git (GitHub)
Abre PowerShell en tu proyecto actual y ejecuta:

```powershell
cd C:\OptimizedISO

# 1. Verificar estado de ramas y commits
git status

# 2. Agregar archivos nuevos / modificados y commitear
git add .
git commit -m "feat(backup): asegurar todos los cambios antes de formatear"

# 3. Subir la rama actual al repositorio remoto de GitHub
git push origin feature/offline-ui-tweaks
```

### 2. Respaldar Archivos Locales No Rastreados (Opcional)
Si tienes ISOs descargadas en `Windows_ISOs/` o carpetas temporales de descargas que no quieras volver a bajar, cópialas a un disco externo o pendrive.

---

## ⚡ FASE 1: Configuración en la Nueva PC (Post-Formateo)

Una vez que hayas instalado Windows 11 en tu nueva máquina:

### 1. Instalar Git for Windows
Abre **PowerShell como Administrador** y ejecuta:

```powershell
winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
```
*(Cierra y vuelve a abrir PowerShell para que el comando `git` esté disponible en el PATH).*

### 2. Clonar el Repositorio
En PowerShell (como Administrador):

```powershell
# 1. Configurar tu identidad en Git
git config --global user.name "romanOSlinux"
git config --global user.email "tu-email@ejemplo.com"
git config --global core.autocrlf true

# 2. Clonar el proyecto directamente en la raíz C:\
git clone -b feature/offline-ui-tweaks https://github.com/romanOSlinux/OptimizedISO.git C:\OptimizedISO
cd C:\OptimizedISO
```

---

## 🚀 FASE 2: Inicialización Autónoma del Entorno con 1 Clic

Dentro de `C:\OptimizedISO`, ejecuta el inicializador oficial de entorno:

### Opción A: Desde Línea de Comandos (PowerShell Admin)
```powershell
.\scripts\Setup-AntigravityWindows.ps1 -InstallPrerequisites -SetExecutionPolicy
```

### Opción B: Con Doble Clic
Haz doble clic sobre el archivo:
`C:\OptimizedISO\scripts\Setup-AntigravityWindows.cmd`

### ¿Qué hace automáticamente este script?
1. **Auditoría de Herramientas:** Detecta si faltan **Windows ADK (`oscdimg.exe`)**, **PowerShell 7**, **Git** o la característica de virtualización **Hyper-V**.
2. **Auto-Instalación vía Winget:** Si usas `-InstallPrerequisites`, descarga e instala Windows ADK y PowerShell 7 en silencio.
3. **Sincronización Global de Antigravity:** Copia y actualiza en tu perfil de usuario (`$HOME\.gemini\config`):
   - Directivas y reglas de memoria (`rules/user_global.md`).
   - Las **10 Skills especializadas** (`skills/`).
   - Hooks automáticos de higiene Git (`hooks.json`).
4. **Validación de Sanidad:** Ejecuta el diagnóstico de herramientas de compilación (`Test-AdkEnvironment.ps1`).

---

## 🧠 FASE 3: Abrir Antigravity IDE y Comenzar a Trabajar

1. Instala e inicia sesión en **Antigravity IDE**.
2. Abre la carpeta `C:\OptimizedISO`.
3. Pega el siguiente mensaje en el chat para sincronizar el contexto:

```text
Hola Antigravity. He restaurado este proyecto en una instalación limpia de Windows 11.
Por favor realiza las siguientes acciones:
1. Revisa MEMORY.md para cargar el historial y contexto de trabajo.
2. Ejecuta un 'git status' y verifica que el entorno esté 100% operativo.
3. Continúa con los hitos pendientes registrados en el último plan.
```

---

## 📦 Arquitectura de Antigravity en este Proyecto

| Ruta en el Repositorio | Destino Global en Windows | Propósito |
| :--- | :--- | :--- |
| `.agents/AGENTS.md` | Contexto de Workspace | Reglas estrictas de codificación (UTF-8 BOM, PowerShell 5.1, Git source of truth). |
| `.agents/rules/user_global.md` | `$HOME\.gemini\config\rules\` | Reglas de memoria activa y optimización de tokens. |
| `.agents/hooks.json` | `$HOME\.gemini\config\hooks.json` | Hooks post-comando para evitar rastreo accidental de binarios pesados. |
| `.agents/skills/*` | `$HOME\.gemini\config\skills\` | 10 habilidades técnicas con arneses de test, matrices de compatibilidad y referencias. |
| `MEMORY.md` | Raíz del Repositorio | Bitácora viva y continua entre sesiones del agente de IA. |
