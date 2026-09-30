# PLAN-0149: Optimizador y Purgado Offline de Imágenes WIM/ISO con WinSxS ResetBase, Reconstrucción WimLib y Auto-Aprovisionamiento en romanOS Studio

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0149 |
| **Fecha** | 2026-09-29 |
| **Componentes** | `scripts/Host-Tools/Optimize-OfflineWim.ps1`, `scripts/Host-Tools/Optimize-OfflineWim.cmd`, `scripts/GUI/romanOS-Studio.ps1`, `scripts/Testing/Test-OptimizeOfflineWim.ps1` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Alta / Arquitectura y Usabilidad de Servicing Offline |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 1 (Windows Host), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM y PS 5.1), Regla 7 (Watchdog y Transparencia), Regla 8 (Ejecución Autónoma), Regla 11 (Autonomía Técnica), Regla 13 (CWE-390 / Fail-Visible Repo-Wide), Regla 14 (Salvaguarda de Almacenamiento) |

---

## 1. Contexto, Causa Raíz y Motivación

En la auditoría forense de medios de instalación de Windows 11 (en particular compilaciones comunitarias como `Windows_11_LTSC_26H2.iso` de RG-Adguard), se descubrió que imágenes que deberían pesar ~4.5 GB llegan a pesar casi 12 GB.
La causa raíz matemática y sistémica es el **slipstreaming acumulativo sucesivo sin consolidación de la base de componentes**:
1. Los paquetes acumulativos (LCU) inyectan nuevas versiones de binarios en `\Windows\WinSxS`.
2. Si el compilador no ejecuta `DISM /Cleanup-Image /StartComponentCleanup /ResetBase`, todas las versiones anteriores de los binarios reemplazados permanecen retenidas en disco.
3. Si el WIM resultante no es reconstruido físicamente con `wimlib-imagex export`, el contenedor retiene bloques muertos y fragmentación.

### Objetivos Principales
1. **Crear el motor backend `Optimize-OfflineWim.ps1` (+ lanzador `.cmd`):** Un script CLI autónomo, robusto y seguro que procese tanto archivos `.wim` sueltos como imágenes `.iso` completas.
2. **Auto-Aprovisionamiento y Pre-Flight Self-Healing:** El motor debe auditar la presencia de DISM (elevación de Admin), `wimlib-imagex`, `oscdimg` y espacio libre en disco (mínimo 35-40 GB). Si falta alguna dependencia externa (como `oscdimg`), debe poder instalarla automáticamente vía `winget`.
3. **Integración Nativa en `romanOS-Studio.ps1`:** Incorporar un Card interactivo en la pestaña *Herramientas del Host* con diagnóstico pre-vuelo en tiempo real, selector de formato (WIM / ESD / ISO) y streaming de logs asíncrono sin bloquear el hilo WPF.
4. **Resguardo y Tolerancia a Fallos:** Bloque `finally` con desmontaje seguro y purga de montajes huérfanos para garantizar que ninguna imagen quede bloqueada ante interrupciones.

---

## 2. Mapa Operacional de Implementación

- [x] **Fase 1: Motor Backend de Purga y Pre-Flight (`scripts/Host-Tools/Optimize-OfflineWim.ps1` y `.cmd`)**
  - Implementada función `Test-WimOptimizationPrerequisites` (Admin, DISM, WimLib, Oscdimg, Espacio libre en disco).
  - Implementada función `Install-WimOptimizationDependencies` (Instalación silenciosa con `winget`).
  - Implementado pipeline de saneamiento en 2 fases:
    - Fase 1 (DISM): Montaje temporal y `StartComponentCleanup /ResetBase` con logging forense crudo (PLAN-0140).
    - Fase 2 (WimLib): Exportación y recomprimido multihilo (`--compress=LZX` o `--solid` LZMS).
    - Fase 3 (Opcional): Reempaquetado a ISO con `oscdimg.exe` si la entrada o salida es ISO.
  - Telemetría y cálculo de reducción: Tamaño previo, tamaño final, GB ahorrados y porcentaje de compresión.
  - Creado lanzador batch `Optimize-OfflineWim.cmd` (formato ANSI / UTF-8 sin BOM).
  - Codificación UTF-8 con BOM en `.ps1` y validación en Windows PowerShell 5.1 certificada.

- [x] **Fase 2: Integración Gráfica en `romanOS-Studio.ps1` (WPF)**
  - Agregado el Card "🗜️ Optimización y Purga de Imágenes (WinSxS ResetBase + WimLib)" en la Pestaña *Herramientas del Host*.
  - Añadidos selectores de archivo de entrada (con botón "Copiar de Pestaña 1") y combobox de formato de salida.
  - Implementado panel de estado de pre-vuelo con diagnóstico en tiempo real.
  - Agregado botón "📥 Instalar Herramientas" conectado a `Install-WimOptimizationDependencies`.
  - Conectado el botón de ejecución a `Start-StudioSubProcess` con DispatcherTimer para streaming continuo en `txtConsole`.

- [x] **Fase 3: Pruebas Unitarias, Validación y Documentación**
  - Creada suite de pruebas `scripts/Testing/Test-OptimizeOfflineWim.ps1` con 18 aserciones (18/18 PASS).
  - Validada sintaxis, contratos de salida y ejecución simulada bajo Windows PowerShell 5.1 (`powershell.exe`).
  - Actualizado `docs/plans/README.md`.

