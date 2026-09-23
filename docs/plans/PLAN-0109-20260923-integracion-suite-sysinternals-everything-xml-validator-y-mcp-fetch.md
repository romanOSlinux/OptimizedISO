# PLAN-0109: Integración de Sysinternals CLI, Everything CLI, Validador XSD Unattend y Servidor MCP Fetch

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0109 |
| **Fecha** | 2026-09-23 |
| **Componentes** | `tools/sysinternals/`, `tools/everything/`, `scripts/Core/Sysinternals-Helper.ps1`, `scripts/Testing/Test-UnattendXml.ps1`, `.agents/plugins/romanos-core/mcp_config.json` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Alta (Calidad de Drivers, Auditoría Forense de Inicio, Prevención de Fallos Unattend y Búsqueda MFT Ultrarrápida) |
| **Reglas Relevantes** | Regla 0 (Git), Regla 4 (Windows PowerShell 5.1 / UTF-8 BOM), Regla 5 (Planes), Regla 6 (Cero Binarios en Git / Higiene .gitignore), Regla 7 (Aviso de Pruebas), Regla 8 (No Auto-Run), Regla 11 (Ingeniero Autónomo), Regla 13 (No Silent Failures) |

---

## 1. Contexto y Justificación Técnica

Para consolidar a **romanOS / OptimizedISO** con estándares industriales de observabilidad, prevención de fallos críticos e inspección forense de bajo nivel, se integran 4 herramientas especializadas de máxima categoría técnica:

1. **Sysinternals CLI Suite (`sigcheck64.exe`, `autorunsc64.exe`, `Coreinfo64.exe`):**
   * *sigcheck64:* Certifica firmas Authenticode y WHQL de drivers `.sys` antes de inyectarlos en WIMs, previniendo pantallazos azules (*Inaccessible Boot Device* / Driver Enforcement BSOD).
   * *autorunsc64:* Audita en 1 segundo todos los puntos de autoinicio (servicios, tareas programadas, drivers, run keys) para certificar matemáticamente el 100% de erradicación de telemetría tras el debloat.
   * *Coreinfo64:* Vuelca la topología real de núcleos (P-Cores vs E-Cores, afinidades, máscaras, caché L1/L2/L3 y extensiones AVX2/AVX-512) para alimentar `Hardware-Engine.ps1`.
2. **Validador Sintáctico y de Esquema para `autounattend.xml` (`Test-UnattendXml.ps1`):**
   * *Problema:* Un error tipográfico en un componente o pase (`specialize`, `oobeSystem`) hace fallar la instalación de Windows a los 15 minutos con un error irrecuperable.
   * *Solución:* Validador nativo .NET/PowerShell que verifica la validez estructural del XML, los 4 bypasses críticos (`BypassTPMCheck`, `BypassSecureBootCheck`, `BypassRAMCheck`, `BypassNRO`), la partición UEFI GPT y la sintaxis de componentes en 100 milisegundos.
3. **`es.exe` (Everything CLI de Voidtools):**
   * *Problema:* Búsquedas recursivas de archivos (`Get-ChildItem -Recurse`) en carpetas masivas de ADK o montajes WIM tardan hasta 1 minuto.
   * *Solución:* Consulta directa en memoria a la Master File Table (MFT) de NTFS en milisegundos.
4. **Servidor MCP Fetch (`@jnohlgard/fetch-mcp`):**
   * *Problema:* Necesidad de extraer documentación técnica limpia en Markdown desde Microsoft Learn, repositorios o especificaciones web sin consumir tokens en HTML ruidoso ni requerir API keys.
   * *Solución:* Servidor MCP stdio configurado en `romanos-core`.

---

## 2. Plan de Implementación por Fases

### Fase 1: Descarga e Integración de Binarios Portables
* Descargar ejecutables oficiales de Sysinternals (`sigcheck64.exe`, `autorunsc64.exe`, `Coreinfo64.exe`) desde `https://live.sysinternals.com/` a `tools/sysinternals/`.
* Descargar `es.zip` oficial de Voidtools y extraer `es.exe` en `tools/everything/`.
* Confirmar que `tools/` permanece 100% ignorado en Git (Regla 6).

### Fase 2: Módulo Helper de Sysinternals (`Sysinternals-Helper.ps1`)
* Crear `scripts/Core/Sysinternals-Helper.ps1` (UTF-8 con BOM):
  * `Test-DriverSignature`: Valida firmas digitales de archivos `.sys`, `.cat`, `.dll`.
  * `Get-SysinternalsAutoruns`: Vuelca auditoría de tareas y servicios a objetos de PowerShell.
  * `Get-CpuCoreTopology`: Extrae información de núcleos e instrucciones de CPU.

### Fase 3: Validador de Unattend XML (`Test-UnattendXml.ps1`)
* Crear `scripts/Testing/Test-UnattendXml.ps1` (UTF-8 con BOM):
  * Carga y parseo con `System.Xml.XmlDocument`.
  * Validación de estructura de pases (`windowsPE`, `offlineServicing`, `specialize`, `oobeSystem`).
  * Validación de presencia y valores de los bypasses de Windows 11.
  * Certificación de particionado UEFI GPT (System, MSR, Windows, Recovery).

### Fase 4: Servidor MCP Fetch en `romanos-core`
* Actualizar `.agents/plugins/romanos-core/mcp_config.json` agregando:
  ```json
  "fetch": {
    "command": "cmd.exe",
    "args": [
      "/c",
      "npx",
      "-y",
      "@jnohlgard/fetch-mcp",
      "serve"
    ]
  }
  ```

### Fase 5: Pruebas y Validación en Windows PowerShell 5.1
* Probar en frío todos los scripts en `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass`.
* Auditar con `Test-CodeQuality.ps1` (cero errores de codificación, cero CWE-390).
* Validar `git status` y ejecutar commit atómico.
