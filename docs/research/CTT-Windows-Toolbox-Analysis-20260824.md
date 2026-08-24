# Investigación Técnica: CTT Windows Toolbox / WinUtil — MicroWin e ISO Builder

**Fecha:** 2026-08-24  
**Autor:** Antigravity (par de programación IA)  
**Propósito:** Evaluar si la arquitectura de CTT Windows Toolbox puede aportar mejoras al proyecto OptimizedISO y su pipeline de creación de ISOs.

---

## 1. Qué es "Windows Toolbox" de Chris Titus Tech

| Campo | Detalle |
|---|---|
| **URL Oficial** | https://cttstore.com/windows-toolbox |
| **Precio** | USD 20 (compra única) |
| **Código Fuente Libre** | https://github.com/ChrisTitusTech/winutil (MIT License) |
| **Invocación Libre** | `irm https://christitus.com/win \| iex` |
| **Estrellas GitHub** | ~32.000+ · 3.600+ forks |

El **Windows Toolbox** de cttstore.com **NO es una herramienta distinta** del proyecto open-source `winutil`. Es exactamente el mismo código, empaquetado como un ejecutable `.exe` offline firmado digitalmente. Su propuesta de valor es:

- Uso en máquinas **air-gapped** (sin acceso a internet).
- Evitar restricciones de políticas de ejecución de PowerShell.
- Versión portátil en USB.
- Soporte al desarrollo del proyecto.

> **La frase "implementación nativa .NET más rápida"** que aparece en la descripción del producto se refiere a que el ejecutable empaquetado es un binario .NET compilado (wrapper), no a que el motor de creación de ISOs sea diferente.

---

## 2. Arquitectura Técnica Real de WinUtil

### 2.1 Stack Tecnológico

| Componente | Tecnología |
|---|---|
| **Lenguaje principal** | PowerShell 5.1 / 7+ |
| **GUI** | WPF (Windows Presentation Foundation) + XAML puro |
| **Renderizado** | `Add-Type -AssemblyName PresentationFramework` (WPF dentro de PowerShell) |
| **Concurrencia** | Runspaces de PowerShell (`Invoke-WPFRunspace`) |
| **Ejecutable .exe** | Compilador de PowerShell a .NET nativo (PS2EXE o similar) |
| **Distribución libre** | Script `.ps1` descargado en caliente via `irm | iex` |

WinUtil **no está escrito en C# ni en un framework .NET moderno** como WinUI 3 o MAUI. Es PowerShell + WPF (que es .NET Framework 4.x). El "ejecutable .NET nativo" vendido en la tienda es el mismo script empaquetado.

### 2.2 Pipeline de Creación de ISOs — MicroWin

Fuente analizada directamente: 
- [`functions/private/Invoke-WinUtilISO.ps1`](https://github.com/ChrisTitusTech/winutil/blob/main/functions/private/Invoke-WinUtilISO.ps1)
- [`functions/private/Invoke-WinUtilISOScript.ps1`](https://github.com/ChrisTitusTech/winutil/blob/main/functions/private/Invoke-WinUtilISOScript.ps1)

El pipeline MicroWin usa exactamente las **mismas herramientas** que nuestro proyecto:

```
1. Mount-DiskImage      → Montar ISO fuente con la API nativa de Windows
2. Get-WindowsImage     → Enumerar ediciones del WIM
3. DISM.exe             → /Add-Driver, /Get-WimInfo, /Get-MountedImageInfo
4. Copy-Item            → Copiar árbol de contenido ISO
5. autounattend.xml     → Inyectar respuesta automática de instalación
6. sources\ei.cfg       → Forzar edición en Windows Setup
7. oscdimg.exe (ADK)    → Recompilar ISO bootable (igual que nuestro proyecto)
```

> **Conclusión clave:** MicroWin de CTT **usa las mismas herramientas de fondo** (`dism.exe`, `oscdimg.exe`, `Mount-DiskImage`) que nuestro `New-OptimizedWindowsISO-v2.ps1`. No hay ninguna biblioteca .NET propietaria que acelere la creación del ISO en sí.

Lo que **sí es diferente** en WinUtil:

| Aspecto | WinUtil / MicroWin | Nuestro Proyecto |
|---|---|---|
| **Interfaz** | WPF/XAML con barra de progreso visual en tiempo real | Consola PowerShell con UI-Engine |
| **Concurrencia** | Runspaces de PowerShell (operaciones en segundo plano) | Ejecución secuencial en el hilo principal |
| **Distribución** | Script online + exe firmado | Scripts locales |
| **Scope** | General (debloat + iso + tweaks) | Específico para ISO optimizada |
| **autounattend.xml** | Generado dinámicamente en memoria | Plantilla XML en disco con inyección DISM |
| **Inyección de drivers** | Export del sistema actual + inject en WIM | No implementado actualmente |

---

## 3. ¿Qué Aporta CTT y Qué Podemos Adaptar?

### 3.1 Técnicas Directamente Aplicables

#### A. Runspaces para Progreso en Tiempo Real
WinUtil usa runspaces para que las operaciones lentas (montaje, DISM, copia) se ejecuten en segundo plano mientras la UI (o en nuestro caso, el log de consola) se actualiza en tiempo real.

**Beneficio para OptimizedISO:** Podríamos implementar un job de progreso en PowerShell con `Start-Job` o runspaces para mostrar el porcentaje real de completado durante `dism.exe` y `oscdimg.exe`.

```powershell
# Patrón de WinUtil que podemos adaptar
$runspace = [runspacefactory]::CreateRunspace()
$runspace.Open()
$ps = [powershell]::Create().AddScript($scriptBlock)
$ps.Runspace = $runspace
$handle = $ps.BeginInvoke()
```

#### B. Inyección de Drivers del Sistema Actual
`Invoke-WinUtilISOScript.ps1` incluye una función sofisticada para:
1. `dism /online /export-driver` → Exportar todos los drivers del sistema actual
2. Filtrar por tipo (almacenamiento, red, etc.)
3. `dism /Add-Driver` → Inyectarlos en el WIM

**Beneficio para OptimizedISO:** Esto podría implementarse como un paso opcional en nuestro pipeline, permitiendo crear ISOs pre-cargadas con los drivers del hardware actual del usuario.

#### C. Validación de WIM Metadatos Pre/Post Servicing
WinUtil valida que atributos críticos del WIM (`Languages`, `Installation`, `Edition`, `ProductType`) no cambien después de la inyección de drivers, previniendo corrupción silenciosa.

```powershell
# Patrón de Assert-WinUtilISOWimMetadata que podemos adaptar
foreach ($key in 'Languages', 'Installation', 'Edition', 'ProductType') {
    if ($After[$key] -ne $Before[$key]) {
        throw "WIM metadata changed: $key"
    }
}
```

#### D. `sources\ei.cfg` para Forzar Edición
WinUtil escribe `sources\ei.cfg` en la ISO para forzar que Windows Setup instale una edición específica sin mostrar el selector. Esta es una técnica documentada oficialmente por Microsoft.

```ini
[Channel]
_Default
[VL]
0
[EditionID]
Professional
[Pid]
```

### 3.2 Lo Que NO Aporta (Mitos Disipados)

| Mito | Realidad |
|---|---|
| "La versión .NET es más rápida para crear ISOs" | Falso. El cuello de botella es `dism.exe` y `oscdimg.exe`, herramientas externas cuya velocidad no cambia con el lenguaje del wrapper. |
| "Usa una biblioteca .NET nativa para manipular WIM" | Falso. Usa `dism.exe` via `Start-Process` / `&`. |
| "El exe de la tienda tiene capacidades adicionales" | Falso. Es el mismo script PS1 empaquetado como .exe firmado. |
| "MicroWin es más rápido que nuestro pipeline" | Depende del hardware. Ambos están limitados por DISM (I/O intensivo). |

---

## 4. Evaluación de Viabilidad para OptimizedISO

### Prioridad ALTA — Recomendado implementar

| # | Feature | Fuente CTT | Esfuerzo |
|---|---|---|---|
| 1 | **Inyección de Drivers del Sistema Actual** | `Add-WinUtilISOStagedDrivers` | Medio |
| 2 | **`sources\ei.cfg` para bloquear edición** | `Invoke-WinUtilISOScript` | Bajo |
| 3 | **Validación de metadatos WIM pre/post servicing** | `Assert-WinUtilISOWimMetadata` | Bajo |

### Prioridad MEDIA — Evaluar según roadmap

| # | Feature | Fuente CTT | Esfuerzo |
|---|---|---|---|
| 4 | **Progreso en tiempo real via Runspaces** | `Invoke-WPFRunspace` | Alto |
| 5 | **GUI WPF minimal (modo interactivo opcional)** | WinUtil completo | Muy alto |

### Prioridad BAJA — No recomendado actualmente

| # | Feature | Razón |
|---|---|---|
| 6 | Compilar a .exe | Complejidad sin beneficio funcional real |
| 7 | Migrar a WinUI 3 / C# | Fuera del scope del proyecto |

---

## 5. Conclusión

El **CTT Windows Toolbox** es una herramienta excelente y bien mantenida, pero su ventaja real no está en velocidad de creación de ISOs (usa el mismo `dism.exe` + `oscdimg.exe`), sino en su **GUI interactiva WPF** y su capacidad de **inyección de drivers del sistema actual**.

Nuestro proyecto `OptimizedISO` ya es **más avanzado** en varios aspectos críticos:
- **autounattend.xml** con soporte completo UEFI GPT, bypass TPM/NRO, modo oscuro
- **Doble inyección de Runtimes** (OEM + WIM offline)
- **Slipstreaming de actualizaciones** (.msu/.cab via DISM)
- **Sistema de logging estructurado** con AI_SUMMARY.md
- **Motor visual unificado** (UI-Engine.ps1)
- **Suite de pruebas unitarias** (154 tests)

Lo que podemos **tomar de CTT** son las técnicas de inyección de drivers y la validación de metadatos WIM, que complementarían nuestro pipeline existente sin reemplazar nada de lo construido.

---

## 6. Fuentes Oficiales

| Recurso | URL |
|---|---|
| Repositorio GitHub (MIT) | https://github.com/ChrisTitusTech/winutil |
| Documentación Oficial | https://winutil.christitus.com/ |
| Producto cttstore.com | https://www.cttstore.com/windows-toolbox |
| Código Invoke-WinUtilISO | https://github.com/ChrisTitusTech/winutil/blob/main/functions/private/Invoke-WinUtilISO.ps1 |
| Código Invoke-WinUtilISOScript | https://github.com/ChrisTitusTech/winutil/blob/main/functions/private/Invoke-WinUtilISOScript.ps1 |
| Microsoft — `ei.cfg` | https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-setup-edition-configuration-and-product-id-files--eicfg-and-pidtxt |
| Microsoft — DISM Add-Driver | https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/add-and-remove-drivers-to-an-offline-windows-image |
