# PLAN-0153: Modo Juego Hardware-Aware Adaptativo, Desacople de Modo Dev y Purga Repo-Wide de Firmas Individuales para Producto Universal

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0153 |
| **Fecha** | 2026-10-05 |
| **Componentes** | `scripts/Core/Hardware-Engine.ps1`, `scripts/Modules/Switch-GameDevMode.ps1`, `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/Activar-Modo-Juego.cmd`, `scripts/Restaurar-Modo-Normal.cmd`, `docs/plans/README.md` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Crítica / Máxima (Arquitectura de Producto Universal, Multi-Hardware y Experiencia de Usuario) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM y PS 5.1), Regla 9 (SSOT), Regla 10 (Docs-as-Code y Cascada), Regla 11 (Ingeniería Autónoma), Regla 13 (CWE-390 / Fail-Visible), Regla 14 (Multi-Hardware Obligatorio) |

---

## 1. Justificación y Visión Arquitectónica

El proyecto romanOS / OptimizedISO está concebido como un sistema operativo y suite de rendimiento universal para cualquier equipo Windows 11 del mercado, no como un conjunto de scripts adaptados exclusivamente al entorno local de un único desarrollador.

### Defectos Identificados y Objetivos:
1. **Modo Juego No Consciente del Silicio (Hardware-Unaware):**
   - Anteriormente, la activación de perfiles de energía forzaba configuraciones monolíticas estáticas (`EPP = 0`, Core Unparking al 100%, `PowerThrottlingOff = 1`).
   - En procesadores como APUs monolíticas (ej. AMD Ryzen 5 8600G, 8700G, 5600G) que comparten un presupuesto térmico/eléctrico de 65W entre CPU e iGPU, forzar la CPU al 100% de frecuencia constante (`EPP = 0`) estrangula el margen de potencia para la gráfica Radeon integrada y satura los ventiladores sin aportar más FPS.
   - En arquitecturas AMD X3D con Dual-CCD o Intel Híbridas (P-Cores + E-Cores), directivas estáticas ciegas degradan la planificación del scheduler (AMD PPM / Intel Thread Director).
2. **Presencia Innecesaria del "Modo Dev":**
   - El concepto bimodal "Game vs Dev" (gestión de Hyper-V, vEthernet, Docker, WSL2) es confuso y carece de utilidad para un usuario final o gamer.
   - Se desacopló y estandarizó en un flujo natural: **Modo Juego Adaptativo** vs **Modo Normal / Estándar de Windows**.
3. **Persistencia de Firmas Personales y Hardware Específico:**
   - Presencia de marcas hardcodeadas de periféricos particulares (ej. `'Patriot Viper V380'`), menciones a aplicaciones privadas de desarrollo (`Antigravity IDE`), servicios de fabricantes aislados (`AsusUpdateCheck`) o nombres de usuario locales.
   - Se purgó toda firma individual para garantizar un producto neutral, profesional y robusto para distribución pública.

---

## 2. Mapa de Fases de Implementación

- [x] **Fase 1: Calibración Canónica de Silicio en `Hardware-Engine.ps1` (SSOT)**
  - Calibrar la política `AMD_Monolithic_APU_UMA` en `Get-RomanOSCpuArchitecturePolicy`: cambiar `EnergyPerformancePreference` a `33` (óptimo de AMD para no ahogar el TDP de la iGPU) y `Win32PrioritySeparation = 38`.
  - Asegurar consistencia de la matriz polimórfica para Intel Híbrido, AMD X3D, AMD Zen Simétrico e Intel Legacy.
- [x] **Fase 2: Refactorización y Hardware-Aware de `Switch-GameDevMode.ps1`**
  - Acoplar `Get-RomanOSCpuArchitecturePolicy` en la activación del Modo Juego (`-Mode Game`).
  - Configurar en vivo el valor de `EPP` y `Core Parking` según el silicio detectado mediante `powercfg`.
  - Renombrar y migrar `-Mode Dev` a `-Mode Normal` (con alias `-Mode Dev` y `-Mode Restore` para compatibilidad transparente).
  - Purgar la lista blanca inviolable eliminando `'Patriot Viper V380'` y neutralizar menciones a herramientas locales como `Antigravity IDE`.
  - Generalizar la lista de servicios pausables quitando dependencias de fabricantes como `AsusUpdateCheck`.
- [x] **Fase 3: Reacondicionamiento Integral de la GUI en `romanOS-ControlCenter.ps1`**
  - Renombrar la pestaña `Gaming & Bimodal` a `Gaming & Rendimiento Adaptativo`.
  - Reemplazar la tarjeta de "Modo Dev" por "Modo Normal / Estándar (Restaurar Productividad de Windows)".
  - Actualizar la tarjeta de "Modo Juego" resaltando la detección automática de silicio multi-hardware (Intel / AMD / APU / X3D).
  - Purgar tooltips, textos de tarjetas y diálogos de cualquier mención técnica o personal no universal.
- [x] **Fase 4: Sincronización de Lanzadores de Comandos (.cmd)**
  - Actualizar `scripts/Activar-Modo-Juego.cmd` y `scripts/Restaurar-Modo-Normal.cmd` para reflejar la terminología estandarizada y ejecutar en modo desatendido.
  - Asegurar codificación estricta UTF-8 No-BOM en scripts `.cmd`.
- [x] **Fase 5: Auditoría Repo-Wide, Pruebas en Frío PS 5.1 y Verificación Anti-Firmas**
  - Grep exhaustivo en todo el repositorio para verificar cero ocurrencias de cadenas individuales residuales.
  - Pruebas sintácticas y funcionales con Windows PowerShell 5.1 (`powershell.exe -STA`).
  - Registro de actualización en `docs/plans/README.md`.
