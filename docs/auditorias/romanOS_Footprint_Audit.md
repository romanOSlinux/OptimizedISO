# Reporte Forense de Huella en Reposo (romanOS Footprint Audit)

- **Fecha de Auditoría:** 2026-09-07 20:45:54
- **Sistema Operativo:** Microsoft Windows 11 Pro for Workstations (10.0.26200 Build 26200)
- **Hardware:** Microsoft Corporation - Virtual Machine | RAM Total: 4 GB
- **Uptime:** 0h 1m 59s
- **Estado Global de RAM:** 2.42 GB en uso (60.5%) / 1.58 GB libres

---

## 1. Procesos en Segundo Plano y Huella de Memoria

| Proceso Auditado | Instancias | RAM (Working Set) | PIDs | Veredicto Técnico |
| :--- | :--- | :--- | :--- | :--- |
| **Edge WebView2 Runtime** (msedgewebview2.exe) | 6 | 315.21 MB | 5084, 5316, 6436, 6516, 7116, 7124 | ❌ VAMPIRO ACTIVO |
| **SearchHost (Búsqueda de Windows)** (SearchHost.exe) | 1 | 119.59 MB | 5652 | ⚠️ ACTIVO (>35MB) |
| **Microsoft Edge (Navegador)** (msedge.exe) | 0 | 0.0 MB | - | ✅ LIMPIO (0 procesos) |
| **Microsoft OneDrive** (OneDrive.exe) | 0 | 0.0 MB | - | ✅ LIMPIO (0 procesos) |
| **OneDrive Setup Worker** (OneDriveSetup.exe) | 0 | 0.0 MB | - | ✅ LIMPIO (0 procesos) |
| **Microsoft Teams (Consumer)** (msteams.exe) | 0 | 0.0 MB | - | ✅ LIMPIO (0 procesos) |
| **Microsoft Teams (New WASDK)** (Teams.exe) | 0 | 0.0 MB | - | ✅ LIMPIO (0 procesos) |
| **Windows Widgets / Dashboard** (Widgets.exe) | 0 | 0.0 MB | - | ✅ LIMPIO (0 procesos) |
| **Xbox GameDVR Replay Buffering** (bcastdvr.exe) | 0 | 0.0 MB | - | ✅ LIMPIO (0 procesos) |
| **Xbox Game Bar Shell** (GameBar.exe) | 0 | 0.0 MB | - | ✅ LIMPIO (0 procesos) |
| **Windows Error Reporting (WER)** (werfault.exe) | 0 | 0.0 MB | - | ✅ LIMPIO (0 procesos) |

---

## 2. Claves de Auto-Arranque (Registry Startup Run)

| Ámbito | Nombre del Valor | Contenido / Comando Ejecutado | Estado |
| :--- | :--- | :--- | :--- |
| Equipo Local (HKLM) | SecurityHealth | C:\WINDOWS\system32\SecurityHealthSystray.exe | ℹ️ Común / Sistema |

---

## 3. Estado de Políticas de Optimización en el Registro

| Identificador | Clave de Registro | Valor Evaluado | Estado Actual | Veredicto |
| :--- | :--- | :--- | :--- | :--- |
| LimitBlankPasswordUse | HKLM:\SYSTEM\CurrentControlSet\Control\Lsa | LimitBlankPasswordUse | 1 (Esperado: 1) | ✅ APLICADA |
| EnableDynamicContentInWSB | HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search | EnableDynamicContentInWSB | 0 (Esperado: 0) | ✅ APLICADA |
| DisableWebSearch | HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search | DisableWebSearch | 1 (Esperado: 1) | ✅ APLICADA |
| StartupBoostEnabled | HKLM:\SOFTWARE\Policies\Microsoft\Edge | StartupBoostEnabled | 0 (Esperado: 0) | ✅ APLICADA |
| BackgroundModeEnabled | HKLM:\SOFTWARE\Policies\Microsoft\Edge | BackgroundModeEnabled | 0 (Esperado: 0) | ✅ APLICADA |
| AllowGameDVR | HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR | AllowGameDVR | No configurada | ⚪ POR DEFECTO WINDOWS |
| AppCaptureEnabled | HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR | AppCaptureEnabled | No configurada | ⚪ POR DEFECTO WINDOWS |
| TaskbarMn (Chat) | HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced | TaskbarMn | 0 (Esperado: 0) | ✅ APLICADA |
| TaskbarDa (Widgets) | HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced | TaskbarDa | No configurada | ⚪ POR DEFECTO WINDOWS |
| ShowCopilotButton | HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced | ShowCopilotButton | 0 (Esperado: 0) | ✅ APLICADA |
| AllowWidgets (GPO) | HKLM:\SOFTWARE\Policies\Microsoft\Widgets | AllowWidgets | 0 (Esperado: 0) | ✅ APLICADA |
| AllowNewsAndInterests | HKLM:\SOFTWARE\Policies\Microsoft\Dsh | AllowNewsAndInterests | 0 (Esperado: 0) | ✅ APLICADA |
| ChatIcon (GPO) | HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat | ChatIcon | 3 (Esperado: 3) | ✅ APLICADA |

---

## 4. Métricas Globales del Sistema Operativo en Reposo

- **Procesos en Ejecución:** 127 procesos
- **Hilos de Ejecución:** 1813 hilos
- **RAM en Reposo:** 2.42 GB / 4 GB (60.5%)
- **Vampiros Detectados:** 2 procesos en segundo plano consumiendo recursos

### Conclusión Técnica:
🟡 **Optimizable:** Se detectaron 2 procesos/servicios parásitos activos en segundo plano que pueden ser neutralizados quirúrgicamente a nivel de ISO o Toolkit.