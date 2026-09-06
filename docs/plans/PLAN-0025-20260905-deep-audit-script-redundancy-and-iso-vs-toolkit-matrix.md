# PLAN-0025: Auditoría Transversal Script por Script, Desmitificación de Redundancias y Matriz de Decisión ISO vs. Toolkit

**Fecha:** 2026-09-05  
**Estado:** PENDIENTE  
**Rama:** `feature/offline-ui-tweaks`  
**Autor:** Agente Antigravity / Pair-Programming  
**Regla de Ejecución:** **PLANIFICACIÓN PURA — NO EJECUTAR CAMBIOS DE CÓDIGO HASTA APROBACIÓN EXPLÍCITA DEL USUARIO**

---

## 1. Justificación y Problemática de Fondo

El proyecto *OptimizedISO* / *romanOS* ha evolucionado incorporando múltiples motores especializados: compilador maestro de ISO (`New-OptimizedWindowsISO-v2.ps1`), optimizador adaptativo (`Win11-Debloat-v3-Adaptive.ps1`), orquestador desacoplado (`romanOS-Toolkit.ps1`), catálogo de directivas (`Policy-Engine.ps1`), motor de hardware (`Hardware-Engine.ps1`) y utilidades individuales de red, seguridad, mantenimiento y menús contextuales.

Sin embargo, esta evolución ha generado una **dispersión y redundancia técnica no planificada**:
- Un mismo ajuste o tweak (como directivas de navegadores, menú contextual, vaciado de DNS o telemetría) se aplica en 2, 3 o hasta 4 capas diferentes (en la imagen offline WIM, en `SetupComplete.cmd`, en el script de debloat y en las opciones rápidas del Toolkit).
- Existen riesgos inherentes de regresión: aplicar ciertos tweaks de forma prematura en la ISO puede provocar bucles de bloqueo en el Setup/OOBE de Windows (*"Espere un momento..."*), mientras que relegar todo al Toolkit priva a la instalación de un estado limpio desde el primer arranque.
- Se requiere una **investigación profunda y respaldada en fuentes oficiales de Microsoft** (Microsoft Learn, Windows Hardware Dev Center, directivas CSP/GPO documentadas) para desmitificar qué optimizaciones son legítimas, cuáles son redundantes o placebo, y cuál es el momento óptimo en el ciclo de vida del sistema operativo para aplicarlas.

---

## 2. Objetivos Principales

1. **Auditoría Exhaustiva Script por Script:**  
   Inspeccionar individualmente cada archivo de script del repositorio (`.ps1` y `.cmd`), catalogando cada función, clave de registro, tarea programada y comando ejecutado.
2. **Detección y Mapeo de Redundancias:**  
   Identificar exactamente qué configuraciones se solapan entre la ISO (`SetupComplete.cmd` / WIM), `Win11-Debloat-v3-Adaptive.ps1`, `romanOS-Toolkit.ps1` y los módulos auxiliares.
3. **Respaldo Riguroso en Fuentes Oficiales de Microsoft:**  
   Verificar cada grupo de optimizaciones contra la documentación oficial de Microsoft (Windows 11 24H2/25H2):
   - Directivas de grupo oficiales (GPO / ADMX) y proveedores de configuración (CSP).
   - Guías de arquitectura de despliegue de Windows (fases *Specialize*, *OOBE*, *Audit Mode*, *SetupComplete*).
   - Estándares del Windows Hardware Dev Center para GPU, DirectStorage, HAGS y NDIS.
4. **Matriz de Decisión Técnica: ¿ISO vs. Toolkit? (Ganancias vs. Pérdidas):**  
   Analizar con fundamento técnico y empírico qué se gana y qué se pierde en cada caso:
   - *¿Qué se gana en la ISO?* Menor interacción del usuario, sistema listo desde el encendido inicial.
   - *¿Qué se pierde en la ISO?* Imposibilidad de detectar hardware específico (en WIM offline no hay drivers de GPU ni monitor activos), riesgo de corrupción en OOBE, rigidez ante el usuario.
   - *¿Qué se gana en el Toolkit?* Adaptabilidad perfecta por hardware en vivo, cero riesgo para el setup de Windows, granularidad de selección, reversibilidad total y limpia.
   - *¿Qué se pierde en el Toolkit?* Requiere acción manual posterior del usuario.
5. **Taxonomía de Clasificación Cuádruple:**
   - **Nivel 1: ISO / WIM Offline** (universales, sin riesgo OOBE, no dependientes de GPU/display).
   - **Nivel 2: SetupComplete.cmd** (configuraciones globales de máquina desatendidas pre-logon).
   - **Nivel 3: Toolkit On-Demand** (dependientes de hardware real, preferencias de gaming y mantenimiento).
   - **Nivel 4: Eliminación / Depuración** (hacks obsoletos, duplicidades innecesarias y tweaks placebo).

---

## 3. Metodología de Auditoría Script por Script

Se auditará la totalidad de los scripts del proyecto conforme al siguiente inventario estructurado:

| # | Script | Rol Arquitectónico | Foco de Auditoría |
|---|---|---|---|
| 1 | `New-OptimizedWindowsISO-v2.ps1` | Generador Maestro ISO | Tweaks offline en WIM, inyección `$OEM$`, plantilla de `SetupComplete.cmd` y diagnóstico embebido. |
| 2 | `Win11-Debloat-v3-Adaptive.ps1` | Debloat Post-Instalación | 17 regiones de optimización, solapamiento con ISO y dependencias de hardware. |
| 3 | `romanOS-Toolkit.ps1` | Hub Maestro Desacoplado | Menús interactivos, `QuickActions`, re-ejecución de scripts hijos y opciones duplicadas. |
| 4 | `Core/Policy-Engine.ps1` | Catálogo Maestro de Políticas | Definición centralizada de claves GPO y consistencia con los scripts ejecutores. |
| 5 | `Core/Hardware-Engine.ps1` | Motor de Introspección HW | Detección de GPU, HAGS, MSI Mode, PCIe ASPM y perfiles de hardware. |
| 6 | `Core/UI-Engine.ps1` | Motor Visual | Banners, menús unificados y consistencia visual sin lógica de sistema. |
| 7 | `Add-OptimizedContextMenus.ps1` | Menús Contextuales | Verbos estáticos, cascadas, CLSID clásico y redundancia con `SetupComplete.cmd`. |
| 8 | `Invoke-WindowsMaintenance.ps1` | Mantenimiento Profundo | WinSxS, Shaders, SSD TRIM, limpieza de logs y solapamiento con Toolkit. |
| 9 | `Invoke-WindowsSecurityHardening.ps1` | Seguridad y Hardening | ASR, VBS, RunAsPPL, protocolos de red y coexistencia con gaming. |
| 10 | `Win11-Network-Diagnostics-Optimizer.ps1` | Red y Latencia | Nagle (TCP), MTU, DNS, QoS, adapters NIC y duplicación con Debloat/Toolkit. |
| 11 | `Get-EssentialRuntimes.ps1` | Runtimes Redistribuibles | Descarga, verificación SHA-256 e instalación offline/online de VC++ y DirectX. |
| 12 | `Get-WindowsUpdates.ps1` | Servicing de Updates | Descarga y catalogación de SSU/LCU oficiales para slipstream. |
| 13 | `autounattend.xml` | Respuesta Desatendida | Pases `windowsPE`, `specialize` y `oobeSystem` (Bypasses NRO/TPM). |

---

## 4. Fases de Ejecución del Plan

### Fase 1: Extracción de Datos y Mapeo de Redundancias
- Escaneo analítico de los 13 componentes de software.
- Creación de la **Matriz de Solapamientos**: tabla cruzada donde cada tweak mapea a los scripts que lo implementan.

### Fase 2: Investigación en Fuentes Oficiales de Microsoft
- Validación de cada directiva contra Microsoft Learn (Windows 11 24H2/25H2).
- Distinción formal entre:
  - *Directivas GPO oficiales soportadas empresarialmente.*
  - *Ajustes CSP de Windows.*
  - *Comportamientos del Shell de Windows documentados.*
  - *Hacks no documentados o frágiles.*

### Fase 3: Elaboración de la Matriz de Decisión (ISO vs. Toolkit)
- Análisis exhaustivo de riesgos vs. beneficios de cada grupo de opciones.
- Justificación con fundamentos técnicos de por qué cada opción debe ir en la ISO o en el Toolkit.

### Fase 4: Entrega del Informe Técnico y Propuesta de Refactorización
- Generación de un documento de análisis arquitectónico integral.
- **Pausa obligatoria para revisión y aprobación del usuario** antes de modificar cualquier línea de código del repositorio.

---

## 5. Criterios de Validación

1. **Cero supocisiones (Regla 2):** Todo argumento sobre el comportamiento de una clave o directiva debe estar respaldado por la documentación oficial correspondiente.
2. **Trazabilidad estricta (Reglas 0 y 5):** Ningún script será editado hasta que el plan y la matriz de decisión sean revisados y aprobados formalmente por el usuario.
3. **Desacoplamiento higiénico:** La arquitectura resultante debe garantizar que la ISO compile imágenes limpias y estables, y que el Toolkit sea un centro de control modular y autónomo sin redundancias dispersas.
