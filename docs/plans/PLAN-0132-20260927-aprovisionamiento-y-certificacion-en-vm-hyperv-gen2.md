# PLAN-0132: Aprovisionamiento, Instalación Desatendida Zero-Touch y Certificación en VM Hyper-V Gen2

| Metadato | Detalle |
|---|---|
| **ID de Plan** | PLAN-0132 |
| **Fecha** | 2026-09-27 |
| **Componentes** | `scripts/Testing/New-TestVM-HyperV.ps1`, `scripts/Testing/New-TestVM-HyperV.cmd`, `scripts/GUI/romanOS-Studio.ps1` |
| **Estado** | `PENDIENTE` |
| **Prioridad** | Crítica (Validación Funcional End-to-End del Ciclo de Vida del SO) |
| **Reglas Relevantes** | Regla 0 (Git SSOT), Regla 1 (Windows Host / Hyper-V), Regla 2 (Cero Suposiciones), Regla 7 (Watchdogs), Regla 14 (Salvaguarda de Medios de Almacenamiento) |

---

## 1. Visión y Justificación Técnica

La validación en una Máquina Virtual Hyper-V de 2ª Generación (Gen2) permite certificar empíricamente el comportamiento en tiempo de ejecución del sistema operativo sin riesgo para el host:
- **Ajuste Previo de Hardware:** El usuario reinicia el host y calibra la VRAM de la APU AMD Radeon 760M en el BIOS (reduciendo la reserva UMA de 4GB a 512MB/1GB/2GB), liberando RAM física suficiente para aprovisionar la VM sin provocar contención de memoria en el host.
- **Topología de la VM:**
  - Máquina Virtual Generación 2 (Firmware UEFI nativo).
  - Secure Boot habilitado con plantilla Microsoft UEFI CA.
  - Módulo de Plataforma Segura virtual (vTPM 2.0) habilitado.
  - 4 procesadores virtuales (vCPU) y 6 GB de RAM estática/dinámica.
  - Controlador SCSI con disco virtual VHDX dinámico de 60 GB.
  - Conmutador de red Default Switch o Private Switch.
- **Despliegue Zero-Touch:** La VM arranca desde la ISO compilada en PLAN-0131 y ejecuta la instalación sin interacción humana gracias a `sources/autounattend.xml`.
- **Aterrizaje en Escritorio y Telemetría Post-Install:** Validación del primer inicio de sesión, comprobación de la creación del mutex `.setup_completed`, verificación de ausencia de bloatware y telemetría en cero.

### Respaldo de Fuentes Oficiales
- **Microsoft Learn:** *Generation 2 Virtual Machine Overview (UEFI, Secure Boot, TPM).*
- **Microsoft Learn:** *Hyper-V Module Cmdlets for Windows PowerShell (`New-VM`, `Set-VMFirmware`, `Enable-VMTPM`).*
- **Microsoft Learn:** *Windows Setup Unattend Deployment Automation.*

---

## 2. Fases de Implementación

- [ ] **Fase 1: Verificación de Recursos Post-Reinicio y Calibración BIOS:**
  - Comprobar que la memoria física disponible en el host haya aumentado tras el ajuste de VRAM UMA en el BIOS.
  - Confirmar estado del servicio `vmms` (Hyper-V).
- [ ] **Fase 2: Aprovisionamiento Automatizado de la VM con `New-TestVM-HyperV.ps1`:**
  - Ejecutar la creación de la VM Gen2 enlazada a la ISO `Windows_11_Optimized_Test.iso`.
  - Configurar Secure Boot, vTPM y disco VHDX dinámico en `C:\OptimizedISO\scratch\VM\`.
- [ ] **Fase 3: Ejecución de la Instalación Desatendida (Zero-Touch):**
  - Arrancar la VM y monitorear el progreso del pase `windowsPE`, `specialize` y `oobeSystem`.
  - Notificar eventos clave mediante temporizadores watchdog (Regla 7).
- [ ] **Fase 4: Verificación Forense del Sistema Instalado en la VM:**
  - Comprobar aterrizaje directo en el escritorio sin prompts de cuenta Microsoft.
  - Confirmar ejecución exitosa de `SetupComplete.cmd` (o `FirstLogonCommands` con mutex `.setup_completed`).
  - Verificar presencia de Desktop Helpers, Control Center y ausencia de apps de telemetría y Recall.
- [ ] **Fase 5: Certificación y Reporte de Métricas del Plan 0132:**
  - Actualizar estado a `COMPLETADO`.
