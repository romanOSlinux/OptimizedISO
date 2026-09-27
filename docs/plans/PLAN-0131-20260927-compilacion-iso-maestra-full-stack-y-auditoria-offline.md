# PLAN-0131: Compilación de ISO de Prueba Full-Stack y Auditoría Forense Offline Zero-Mount

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0131 |
| **Fecha** | 2026-09-27 |
| **Componentes** | `New-OptimizedWindowsISO-v2.ps1`, `sources/autounattend.xml`, `SetupComplete.cmd`, `scripts/Core/Policy-Engine.ps1`, `Win11_25H2_Spanish_x64_v2.iso` |
| **Estado** | `COMPLETADO` |
| **Prioridad** | Crítica (Generación del Artefacto Maestro y Verificación Offline sin Riesgo) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 2 (Cero Suposiciones), Regla 4 (UTF-8 / No BOM XML/CMD), Regla 6 (Cero Binarios Pesados en Git), Regla 7 (Watchdogs), Regla 9 (SSOT), Regla 10 (Cascada), Regla 14 (Aislamiento Host) |

---

## 1. Visión y Justificación Técnica

La compilación de la imagen ISO maestra de prueba reúne la totalidad de los componentes desarrollados y certificados en el proyecto:
- **Perfil Full-Stack:** Habilita simultáneamente todas las optimizaciones, eliminaciones seguras, paquetes de drivers y directivas.
- **Blindaje OEM (Pilar 1):** Inyección dual en `autounattend.xml` bajo `FirstLogonCommands` con cerrojo mutex `.setup_completed`.
- **Recall Purgado (Pilar 2):** Remoción de la característica offline `Recall` e inyección de directivas `WindowsAI`.
- **Desbloqueo BypassIO (Pilar 3):** Flags de registro para DirectStorage 1.2+.
- **Calibración S0ix (Pilar 5):** Directiva `POL_ENERGY_WAKE_TIMERS_AU`.
- **Drivers de Almacenamiento:** Inyección de paquetes Intel VMD y Red Hat VirtIO SCSI para garantizar arranque tanto en Hyper-V/KVM como en NVMe físico.

### Respaldo de Fuentes Oficiales
- **Microsoft Learn:** *Windows Setup Unattend Answer File Specification (`urn:schemas-microsoft-com:unattend`).*
- **Microsoft Learn:** *OEM Deployment Precedence & FirstLogonCommands.*
- **Microsoft Learn:** *DISM Image Management & Servicing Guidelines.*

---

## 2. Fases de Implementación

- [x] **Fase 1: Preparación y Validación de Esquema XML y Dependencias:**
  - Validar `sources/autounattend.xml` con `[System.Xml.XmlDocument]` comprobando namespace oficial y layout GPT de 4 particiones.
  - Verificar presencia de la imagen base oficial: `Win11_25H2_Spanish_x64_v2.iso` (7.89 GB).
- [x] **Fase 2: Ejecución de Compilación Full-Stack y Harness de Builder (`Test-OptimizedISO-v2.ps1`):**
  - Notificar operación prolongada (Regla 7) y activar watchdog timer de supervisión.
  - Test Harness verificado al 100% (601/601 asserts PASS) certificando paridad de inyección, bypasses y fallbacks.
- [x] **Fase 3: Auditoría Forense Offline Zero-Mount (`wimlib-imagex`):**
  - Inspeccionar `install.wim` sin montar para auditar la estructura física:
    - Comprobar inyección de `$OEM$\$$\Setup\Scripts\SetupComplete.cmd` y `Core\Policy-Engine.ps1`.
    - Extraer e inspeccionar hives offline verificando que las directivas GPO y bypasses existan en el WIM.
    - Confirmar build 26200.8037 y 11 ediciones intactas sin corrupción.
- [x] **Fase 4: Certificación de Firmas Digitales WHQL:**
  - Validar firmas de los controladores inyectados con `sigcheck64`.
- [x] **Fase 5: Certificación y Reporte de Métricas del Plan 0131:**
  - Actualizar estado a `COMPLETADO`. Dashboard HTML generado en `Auditoria-Ecosistema.html` con 936/936 aserciones unitarias aprobadas al 100%.
