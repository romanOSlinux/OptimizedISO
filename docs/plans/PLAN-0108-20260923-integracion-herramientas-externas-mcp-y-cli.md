# PLAN-0108: Integración de Ecosistema de Herramientas Externas (Servidores MCP, wimlib, regipy y PSScriptAnalyzer)

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0108 |
| **Fecha** | 2026-09-23 |
| **Componentes** | `.agents/plugins/romanos-core/mcp_config.json`, `.gitignore`, `tools/wimlib/`, `scripts/Host-Tools/Test-CodeQuality.ps1`, Entorno Windows Host |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Alta (Infraestructura de Desarrollo, Análisis Estático y Aceleración de Inspección WIM) |
| **Reglas Relevantes** | Regla 0 (Git), Regla 4 (Windows PowerShell 5.1 / UTF-8 BOM), Regla 5 (Planes), Regla 6 (Cero Binarios en Git / Higiene .gitignore), Regla 8 (No Auto-Run), Regla 11 (Ingeniero Autónomo), Regla 13 (No Silent Failures) |

---

## 1. Contexto y Justificación Técnica

Para maximizar la autonomía, la velocidad de desarrollo y la fiabilidad en **romanOS / OptimizedISO**, se requiere incorporar herramientas especializadas que resuelvan cuellos de botella clave del ecosistema:

1. **Memoria Técnica y Grafo de Conocimiento (`@modelcontextprotocol/server-memory`):**
   * *Problema:* Las decisiones técnicas sobre compatibilidad de claves de registro por versión de Windows (23H2 vs. 24H2) o mitigaciones de hardware quedan dispersas en planes históricos o se olvidan entre sesiones.
   * *Solución:* Servidor MCP oficial de memoria persistente para consolidar un grafo de conocimiento técnico que el agente consulte dinámicamente.
2. **Inspección de WIMs Ultrarrápida (`wimlib-imagex`):**
   * *Problema:* `dism.exe` requiere montar la imagen (2 a 4 minutos), permisos elevados y riesgo de montajes huérfanos solo para verificar si un archivo quedó inyectado en `install.wim` o `boot.wim`.
   * *Solución:* Binario portable oficial de `wimlib-imagex` para listar (`dir`) o extraer (`extract`) archivos en 1 segundo sin tocar el kernel ni montar la imagen.
3. **Análisis Forense de Registro Offline (`regipy`):**
   * *Problema:* `reg.exe load` sobre colmenas de Windows (`NTUSER.DAT`, `SOFTWARE`) en imágenes offline sufre de bloqueos de archivo y riesgo de desajustes de permisos.
   * *Solución:* CLI de Python pura para inspeccionar, volcar a JSON y buscar claves en colmenas offline en solo lectura.
4. **Auditoría Estática de Código PowerShell (`PSScriptAnalyzer`):**
   * *Problema:* Garantizar el cumplimiento estricto de la **Regla 4** (compatibilidad obligatoria con Windows PowerShell 5.1) y **Regla 13** (erradicación de `catch` vacíos / CWE-390).
   * *Solución:* Módulo oficial de Microsoft `PSScriptAnalyzer` con un script wrapper en `scripts/Host-Tools/Test-CodeQuality.ps1`.
5. **Servidor MCP de GitHub (`@modelcontextprotocol/server-github`):**
   * *Problema:* Necesidad de consultar repositorios de referencia, investigar commits remotos y gestionar issues del repositorio `romanOSlinux/OptimizedISO`.
   * *Solución:* Servidor MCP oficial de GitHub configurado en el plugin `romanos-core`.

---

## 2. Inventario de Dependencias y Runtimes en el Host

| Herramienta / Componente | Runtime Requerido | Estado Actual en Host | Método de Instalación |
| :--- | :--- | :--- | :--- |
| **`PSScriptAnalyzer`** | PowerShell 5.1 / 7 | No instalado | `Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force` |
| **`wimlib-imagex`** | Nativo x64 (Portable) | No instalado | Descarga oficial `wimlib.net` a `tools/wimlib/` (ignorado en git) |
| **`regipy`** | Python 3.12 + pip | No instalado | `winget install Python.Python.3.12` + `pip install regipy` |
| **`server-memory` (MCP)** | Node.js (npx) | No instalado | `winget install OpenJS.NodeJS.LTS` |
| **`server-github` (MCP)** | Node.js (npx) | No instalado | Provisto por Node.js + Variable `GITHUB_PERSONAL_ACCESS_TOKEN` |

---

## 3. Plan de Implementación por Fases

### Fase 1: Higiene Git y Blindaje de `.gitignore` (Regla 6)
* Asegurar que el directorio de herramientas locales `tools/` y cualquier binario `.exe`, `.dll` o `.zip` esté explícitamente ignorado para garantizar cero fugas de binarios al control de versiones.
* Modificar `.gitignore` agregando:
  ```gitignore
  # Herramientas y utilidades locales portables (wimlib, parsers)
  tools/
  bin/
  ```

### Fase 2: Instalación de Runtimes Base en Windows Host
* Instalar **Node.js LTS** mediante `winget`:
  `winget install --id OpenJS.NodeJS.LTS --exact --silent --accept-package-agreements --accept-source-agreements`
* Instalar **Python 3.12** mediante `winget`:
  `winget install --id Python.Python.3.12 --exact --silent --accept-package-agreements --accept-source-agreements`

### Fase 3: Instalación de Herramientas CLI y Módulos
1. **PSScriptAnalyzer:**
   * Ejecutar en PowerShell:
     `Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck`
   * Crear el script de auditoría rápida `scripts/Host-Tools/Test-CodeQuality.ps1` (UTF-8 con BOM) para escanear scripts del repositorio detectando incompatibilidades con PS 5.1 y bloques `catch` silenciosos.
2. **regipy:**
   * Ejecutar vía pip:
     `pip install regipy`
   * Verificar disponibilidad de `regipy-registry-dump`.

### Fase 4: Descarga e Integración de `wimlib-imagex`
* Descargar el paquete oficial `https://wimlib.net/downloads/wimlib-1.14.5-windows-x86_64-bin.zip`.
* Extraer en `c:\OptimizedISO\tools\wimlib\`.
* Crear `scripts/Core/WimLib-Helper.ps1` (o wrapper en `scripts/Host-Tools/`) con funciones reutilizables:
  * `Get-WimContentFast -WimPath <string> [-ImageIndex <int>]`: Lista en segundos el árbol de archivos.
  * `Extract-WimFileFast -WimPath <string> -FilePathInWim <string> -Destination <string>`: Extrae archivos sin montar el WIM.

### Fase 5: Configuración de Servidores MCP en `romanos-core`
* Crear/Configurar `.agents/plugins/romanos-core/mcp_config.json`:
  ```json
  {
    "mcpServers": {
      "memory": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-memory"]
      },
      "github": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-github"],
        "env": {
          "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}"
        }
      }
    }
  }
  ```

---

## 4. Plan de Verificación

1. **Verificación de Runtimes:**
   * Ejecutar `node -v`, `npm -v`, `python --version`, `pip --version`.
2. **Verificación de PSScriptAnalyzer:**
   * Ejecutar `Get-Module -ListAvailable PSScriptAnalyzer`.
   * Probar `scripts/Host-Tools/Test-CodeQuality.ps1` contra un script del repositorio y verificar salida.
3. **Verificación de regipy:**
   * Ejecutar `regipy-registry-dump --help`.
4. **Verificación de wimlib-imagex:**
   * Ejecutar `& "tools\wimlib\wimlib-imagex.exe" --version`.
   * Probar `Get-WimContentFast` si existe un `.wim` local de prueba.
5. **Verificación de Servidores MCP:**
   * Comprobar que `mcp_config.json` tenga sintaxis JSON válida y que el comando `npx -y @modelcontextprotocol/server-memory` resuelva adecuadamente.
6. **Verificación Git:**
   * Ejecutar `git status` para confirmar que `tools/` y los binarios quedan 100% ignorados sin ensuciar el árbol de Git.
