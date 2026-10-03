# PLAN-0152: Purga Repo-Wide de Residuos de Windows 10 y Sincronización Canónica Exclusiva de Windows 11

## Metadatos
- **Fecha:** 2026-10-02
- **Estado:** COMPLETADO
- **Prioridad:** Normal
- **Tipo:** Refactorización / Calidad / Sincronización en Cascada (Docs-as-Code)
- **Alcance:** Repositorio Completo (`scripts/Builder`, `scripts/Host-Tools`, `scripts/GUI`, `scripts/Modules`, `scripts/Testing`, `docs/`)

---

## 1. Contexto y Justificación Técnica

En el hito histórico **PLAN-0090** (commit `01eeeb1`), el ecosistema romanOS desacopló formalmente a Windows 10 (22H2, LTSC 2021) y la arquitectura x86 para concentrar el motor de políticas (`Policy-Engine.ps1`), la inteligencia de silicio (`Hardware-Engine.ps1`) y el debloat en las versiones modernas de **Windows 11** (22H2, 23H2, 24H2, 25H2 y Windows 11 IoT Enterprise LTSC 2024).

Sin embargo, una auditoría forense repo-wide detectó la presencia residual de:
1. Parámetros obsoletos en `New-OptimizedWindowsISO-v2.ps1` (`-InjectWin10Script`, `-Win10ScriptPath`).
2. Opciones muertas en menús interactivos (`[2] Windows 10` en `Detect-WindowsVersion`).
3. Ramas `else` muertas y URLs de descarga hacia portales de Windows 10 en `Get-OfficialWindowsISO.ps1` y `New-OptimizedWindowsISO-v2.ps1`.
4. Etiquetas de interfaz gráfica desactualizadas en `romanOS-Studio.ps1` que aún mencionaban "Windows 10/11".
5. Comentarios de cabecera `.SYNOPSIS` y `.DESCRIPTION` en scripts modulares y de pruebas que aún aludían a Windows 10.
6. Guías de documentación (`README.md`, `docs/USAGE.md`, `docs/COMMANDS.md`, `docs/MANUAL_DE_USO.md`) con desvío de configuración (*configuration drift*).

El objetivo de este plan es purgar todos los residuos de forma quirúrgica y sincronizada, manteniendo inalterada la salvaguarda *Fail-Fast* que detecta y rechaza activamente imágenes obsoletas de Windows 10 si un usuario intentara utilizarlas.

---

## 2. Matriz de Cambios por Componente

| # | Archivo | Modificación |
|---|---|---|
| 1 | `scripts/Builder/New-OptimizedWindowsISO-v2.ps1` | Purgar `.PARAMETER InjectWin10Script`, `.PARAMETER Win10ScriptPath`, `$InjectWin10Script`, `$Win10ScriptPath`, opción `[2] Windows 10` en menú, URL fallback de Win10, rama 19045 en branchTag, y actualizar `.SYNOPSIS`. Preservar guardián *Fail-Fast* en línea 4793 y reconocimiento en `Convert-BuildToWindowsVersion`. |
| 2 | `scripts/Host-Tools/Get-OfficialWindowsISO.ps1` | Eliminar rama muerta `else { 'Windows 10' }` y URL de fallback hacia Windows 10. |
| 3 | `scripts/GUI/romanOS-Studio.ps1` | Actualizar etiqueta XAML a `"Imagen de Origen (Windows 11 ISO):"`. |
| 4 | `scripts/Modules/Invoke-WindowsSecurityHardening.ps1` | Actualizar comentario `.SYNOPSIS` a Windows 11. |
| 5 | `scripts/Modules/Optimize-InterruptAffinity.ps1` | Actualizar comentario `.SYNOPSIS` a Windows 11. |
| 6 | `scripts/Testing/New-TestVM-HyperV.ps1` | Actualizar comentario `.SYNOPSIS` a Windows 11. |
| 7 | `README.md` | Sincronizar compatibilidad declarada exclusivamente para Windows 11. |
| 8 | `docs/USAGE.md` | Actualizar ejemplos y referencias hacia Windows 11. |
| 9 | `docs/COMMANDS.md` | Purgar parámetros `-InjectWin10Script` y `-Win10ScriptPath` de la documentación de comandos. |
| 10 | `docs/MANUAL_DE_USO.md` | Sincronizar especificaciones de versiones soportadas. |

---

## 3. Protocolo de Verificación y Criterios de Éxito

1. **Codificación:** Todo script `.ps1` modificado debe mantener estrictamente **UTF-8 con BOM** (`0xEF, 0xBB, 0xBF`).
2. **Compilación en Frío:** 0 errores de sintaxis AST en `System32\WindowsPowerShell\v1.0\powershell.exe -STA`.
3. **Test Harness:** Ejecutar `scripts/Testing/Test-OptimizedISO-v2.ps1` y verificar 100% PASS en las pruebas del builder.
4. **Git:** Inspección exhaustiva con `git diff` y commit atómico.
