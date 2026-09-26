# PLAN-0119: Framework de Pruebas Funcionales de Contrato (Behavioral & State Mutation Testing) para Botones de Control Center, Toolkit y Módulos

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0119 |
| **Fecha** | 2026-09-26 |
| **Componentes** | `scripts/Testing/Test-FunctionalContracts.ps1`, `scripts/GUI/romanOS-ControlCenter.ps1`, `scripts/Modules/romanOS-Toolkit.ps1`, `scripts/Modules/*`, `scripts/Core/Policy-Engine.ps1`, `scripts/Testing/Invoke-EcosystemAudit.ps1`, `Auditoria-Ecosistema.html`, `docs/plans/README.md` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Máxima (Calidad de Software, Detección de Desconexión entre Promesa de UI y Efecto Real en el SO) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 BOM / PS 5.1), Regla 5 (Planes), Regla 7 (Watchdogs), Regla 8 (Modo Autónomo Continuo), Regla 9 (SSOT Policy-Engine), Regla 10 (Cascada Docs-as-Code), Regla 11 (Ingeniero Autónomo), Regla 13 (Auditoría Holística / CWE-390), Regla 14 (Salvaguarda de Almacenamiento y Mocks Aislados), Regla 15 (Memoria Jerárquica Map-Reduce) |

---

## 1. Diagnóstico Forense: La Brecha entre Pruebas Estáticas y Contratos de Comportamiento

### A. El Caso Testigo: Botón "Optimizar Juegos y Apps (VRAM / Electron)"
Durante la auditoría del botón `btnRunGamingApps` ("Optimizar Juegos y Apps (VRAM / Electron)"), se descubrió un defecto crítico de diseño:
* **Promesa funcional de la interfaz:** Desactivar el auto-arranque parásito de aplicaciones pesadas en segundo plano (Discord / Spotify).
* **Implementación real preexistente:** El script subyacente (`Optimize-GamingAndApps.ps1`) únicamente escribía `"OPEN_ON_STARTUP": false` en `%APPDATA%\discord\settings.json`.
* **Falla en el Sistema Operativo:** Windows **no lee archivos JSON** al iniciar sesión; lee `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`. La clave de registro seguía existiendo y Windows ejecutaba Discord al arrancar de todos modos.
* **¿Por qué el Test Harness (598 pruebas) dio 100% PASS?**
  Porque las pruebas existentes eran **estáticas y sintácticas**:
  1. Verificaban que el archivo existiera (`Test-Path`).
  2. Verificaban que no hubiera errores de sintaxis AST (0 ParserErrors).
  3. Verificaban que el archivo estuviera codificado en UTF-8 con BOM.
  4. Verificaban mediante expresiones regulares si el código fuente contenía palabras clave (ej. `match 'Intel\\ShaderCache'`).
  *Ninguna prueba evaluó el **comportamiento ni la mutación de estado real**: ¿Desapareció la clave de registro de Windows? ¿Desapareció el acceso directo de Startup? ¿Cambió el archivo `.vdf`?*

### B. El Peligro del "Efecto Placebo" en la UI
Si un botón dice *"Optimizar X"* o *"Desactivar Y"*, pero el código solo realiza el 50% de la tarea o falla silenciosamente ante un escenario común, el usuario experimenta un "efecto placebo". 
Para erradicar esto de todo el ecosistema romanOS, se requiere una **Metodología de Pruebas de Contrato Funcional y Mutación de Estado (Behavioral & State Mutation Testing)**.

---

## 2. Metodología de Pruebas: Patrón Arrange-Act-Assert con Fixtures Aislados

Para cumplir estrictamente con la **Regla 14** (Cero Daño al Host y Salvaguarda de Almacenamiento), las pruebas funcionales no destruyen la configuración del usuario real, sino que operan mediante **Fixtures de Sandboxing y Mocks Transaccionales**:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   CICLO DE CONTRATO FUNCIONAL                          │
├────────────────────────────────────────────────────────────────────────┤
│  1. ARRANGE (Preparar Estado Pre-Optimizado / "Sucio")                │
│     - Inyectar clave de prueba en HKCU\Run o clave efímera             │
│     - Crear archivo dummy de shader en carpeta de prueba               │
│     - Crear archivo mock de configuración (.vdf / prefs / json)        │
├────────────────────────────────────────────────────────────────────────┤
│  2. ACT (Invocar Acción Real del Botón)                                │
│     - Ejecutar la función o script con los argumentos exactos de la UI │
│       (ej. -Unattended, -Action Optimize)                              │
├────────────────────────────────────────────────────────────────────────┤
│  3. ASSERT (Verificación Matemática de Mutación de Estado)            │
│     - ¿La clave de registro fue eliminada o tomó el valor exacto?     │
│     - ¿El archivo mock fue depurado?                                   │
│     - ¿El archivo de preferencias fue actualizado correctamente?       │
│     - ¿No quedaron errores en variables globales ni bloqueos?          │
├────────────────────────────────────────────────────────────────────────┤
│  4. TEARDOWN (Limpieza Obligatoria)                                    │
│     - Eliminar fixtures efímeros y restaurar estado original           │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Matriz de Contratos Funcionales por Botón (Mapeo UI -> Efecto Real)

### Módulo A: Gaming & Bimodal (Pestaña 2 del Control Center)
| Botón UI | Script Subyacente | Contrato Funcional (Mutaciones que DEBEN ocurrir) |
|---|---|---|
| `btnRunGamingApps` | `Optimize-GamingAndApps.ps1` | **Steam:** `localconfig.vdf` con `EnableGPUAcceleratedWebViews=0` y clave `HKCU\Valve\Steam\EnableGPUAcceleratedWebViews=0`.<br>**Discord:** `settings.json` con `OPEN_ON_STARTUP=false`, clave `HKCU\Run\Discord` eliminada, `.lnk` en Startup eliminado.<br>**Spotify:** `prefs` con `enable-hardware-acceleration=false` y `autostart.mode="off"`, clave `HKCU\Run\Spotify` eliminada.<br>**Shaders:** Archivos de prueba en carpetas de caché son eliminados físicamente.<br>**Flip Model:** `DirectXUserGlobalSettings` contiene `SwapEffectUpgradeEnable=1`. |
| `btnToggleHypervisor` | `romanOS-ControlCenter.ps1` | Contrato BCD: Detecta el estado de `hypervisorlaunchtype` y ejecuta comando de conmutación. |
| `btnAuditAffinityGUI` / `btnOptimizeAffinityGUI` | `Optimize-InterruptAffinity.ps1` | Contrato PCIe: Evalúa dispositivos de alto impacto (GPU/NVMe), aísla Core 0 (máscara `0xFE`) y aplica política `DevicePolicy = 4` (HighPriority). |
| `btnResetAffinityGUI` | `Optimize-InterruptAffinity.ps1` | Contrato Restauración: Elimina las subclaves de `Interrupt Management\Affinity Policy` restaurando la política predeterminada. |
| `btnEnableClassicMenu` / `btnRestoreModernMenu` | `Add-OptimizedContextMenus.ps1` | Contrato Explorer: Crea/elimina CLSID `{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32` con valor nulo para alternar entre menú clásico y moderno. |
| `btnApplyFullContextMenu` | `Add-OptimizedContextMenus.ps1` | Contrato Power-User: Inyecta los comandos de mantenimiento en cascada en `HKCR:\Directory\Background\shell`. |

### Módulo B: Mantenimiento & Saneamiento (Pestaña 3)
| Botón UI | Script Subyacente | Contrato Funcional |
|---|---|---|
| `btnRunMaintenanceBatch` | `Invoke-WindowsMaintenance.ps1` | Purga archivos de shaders respetando exclusión de drivers en uso, ejecuta TRIM solo en unidades SSD/NVMe detectadas por `Get-Partition`, omite HDDs mecánicos. |
| Snapshot & Rollback | `Manage-SystemSnapshot.ps1` | Crea snapshot serializado en JSON íntegro, valida estructura de esquema y prueba reversión atómica sobre una clave de prueba. |

### Módulo C: Red & Latencia (Pestaña 4)
| Botón UI | Script Subyacente | Contrato Funcional |
|---|---|---|
| Conmutador DNS (Cloudflare / Quad9 / Google) | `romanOS-ControlCenter.ps1` | Consulta la ruta predeterminada (`0.0.0.0/0`), detecta la interfaz activa, inyecta las IPs primarias/secundarias y valida `Get-DnsClientServerAddress`. |
| Restaurar DHCP | `romanOS-ControlCenter.ps1` | Restaura la configuración a DHCP automático y limpia servidores estáticos. |
| Calibrador Latencia TCP | `Win11-Network-Diagnostics-Optimizer.ps1` | Modifica `TcpAckFrequency`, `TCPNoDelay` con tipos y valores numéricos exactos en la subclave de la interfaz activa. |

### Módulo D: Seguridad & Navegadores (Pestaña 5)
| Botón UI | Script Subyacente | Contrato Funcional |
|---|---|---|
| Aplicar Políticas Navegadores | `Optimize-WebBrowsers.ps1` | Genera claves en `HKLM\SOFTWARE\Policies\Google\Chrome`, `Microsoft\Edge`, `BraveSoftware\Brave` con directivas antirrastreo (`DNT`, `PasswordManagerEnabled=0` si aplica). |

---

## 4. Arquitectura del Nuevo Test Harness: `Test-FunctionalContracts.ps1`

Se construirá el arnés automatizado `scripts/Testing/Test-FunctionalContracts.ps1`:
1. **Runner Universal en Windows PowerShell 5.1:** Ejecución rápida, sin dependencias externas, integrado al comando de pruebas repo-wide.
2. **Framework de Fixtures:**
   * `New-ContractFixture -Type Registry -Path $path -Name $name -Value $val`: Crea un valor de prueba pre-optimizado.
   * `New-ContractFixture -Type File -Path $path -Content $content`: Crea un archivo de configuración sucio.
   * `Invoke-ContractAction -ActionBlock { ... }`: Dispara la acción exacta.
   * `Assert-ContractState -Condition { ... } -Message "..."`: Evalúa el estado post-ejecución.
   * `Remove-ContractFixture`: Teardown automático de limpieza.
3. **Reporte Cuantitativo:**
   * Muestra matriz clara con Botón, Contrato Evaluado, Estado Esperado, Estado Obtenido y Veredicto (`PASS` / `FAIL`).

---

## 5. Fases de Ejecución

- [x] **Fase 1: Diagnóstico y Registro del Plan (PLAN-0119)**
- [x] **Fase 2: Construcción del Motor de Fixtures y Contratos (`Test-FunctionalContracts.ps1`)**
- [x] **Fase 3: Implementación de Contratos para Gaming & Bimodal (Steam, Discord, Spotify, Shaders, Flip Model, Afinidad)**
- [x] **Fase 4: Implementación de Contratos para Menús Contextuales, Mantenimiento y Red/DNS**
- [x] **Fase 5: Validación Cruzada en Windows PowerShell 5.1, Detección de Desvíos y Corrección en Scripts Afectados**
- [x] **Fase 6: Integración en el Dashboard HTML (`Auditoria-Ecosistema.html`) y Commit Atómico**
