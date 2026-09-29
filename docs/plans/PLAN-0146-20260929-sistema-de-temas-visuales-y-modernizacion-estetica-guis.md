# PLAN-0146: Sistema de Temas Visuales Dinámicos (DynamicResource SSOT) y Modernización Estética de Interfaces Gráficas romanOS

**Fecha:** 2026-09-29  
**Estado:** COMPLETADO  
**Área:** GUIs / UI/UX / Motor Visual SSOT / Ergonomía Visual  
**Repositorio:** romanOS / OptimizedISO  

---

## 1. Contexto y Justificación de Diseño

A partir de la auditoría visual de las interfaces actuales ([`scripts/GUI/romanOS-ControlCenter.ps1`](file:///c:/OptimizedISO/scripts/GUI/romanOS-ControlCenter.ps1) y [`scripts/GUI/romanOS-Studio.ps1`](file:///c:/OptimizedISO/scripts/GUI/romanOS-Studio.ps1)), se determinó que la paleta base de grises planos (`#202020` / `#282828`) y la discrepancia estética entre ambas herramientas (Cyan neón vs. Azul Windows 10) restaban presencia y sofisticación al proyecto.

El usuario aprobó preparar las 3 opciones de diseño propuestas, iniciando de inmediato con la implementación de la **Opción 1 (Cyber-Stealth / Hyper-Precision)** como tema activo predeterminado, habilitando al mismo tiempo la capacidad de alternar dinámicamente entre las tres opciones desde la propia interfaz gráfica en caliente.

---

## 2. Catálogo Maestro de Temas (SSOT en UI-Engine.ps1)

Se implementó en [`scripts/Core/UI-Engine.ps1`](file:///c:/OptimizedISO/scripts/Core/UI-Engine.ps1) el diccionario de tokens visuales canónicos accesibles mediante `Get-RomanOSGuiThemes`, `Get-RomanOSActiveThemeName`, `Set-RomanOSActiveThemeName` y `Apply-RomanOSGuiTheme`:

### Opción 1: Cyber-Stealth / Hyper-Precision (Predeterminado)
- **Fondo Ventana:** `#0D1117` (Negro obsidiana frío)
- **Superficie Tarjetas / Header:** `#161B22` | Borde: `#30363D`
- **Acento Primario (romanOS):** `#00E5FF` (Cyan Eléctrico)
- **Acento Secundario (Salud / Éxito):** `#00E676` (Verde Esmeralda)
- **Acento Pausa / Alerta:** `#F59E0B` (Ámbar)
- **Acento Dev / Hardcore:** `#A855F7` (Púrpura)
- **Botones Neutros:** `#21262D` | Borde: `#363D47` | Hover: `#30363D`
- **Tipografía:** `#F0F6FC` (Texto principal) / `#8B949E` (Secundario)

### Opción 2: Imperial Crimson & Titanium
- **Fondo Ventana:** `#121214` (Titanio oscuro)
- **Superficie Tarjetas / Header:** `#1A1A1E` | Borde: `#2C2C34`
- **Acento Primario:** `#FF334B` (Rojo Carmesí Imperial Neón)
- **Acento Secundario:** `#10B981` (Verde Menta)
- **Acento Pausa:** `#F59E0B`
- **Botones Neutros:** `#27272A` | Borde: `#3F3F46` | Hover: `#3F3F46`
- **Tipografía:** `#F4F4F5` / `#A1A1AA`

### Opción 3: OLED Midnight Pure
- **Fondo Ventana:** `#07080B` (Casi OLED puro)
- **Superficie Tarjetas / Header:** `#0F1117` | Borde: `#1F2433`
- **Acento Primario:** `#00F0FF` (Cyan Láser Puro)
- **Acento Secundario:** `#00FF9D` (Verde Neón Brillante)
- **Acento Pausa:** `#FFB800`
- **Botones Neutros:** `#151821` | Borde: `#252B3B` | Hover: `#202533`
- **Tipografía:** `#FFFFFF` / `#788296`

### Opción 4: Classic Charcoal (Legacy / Original)
- Mantiene los valores históricos (`#202020`, `#282828`, `#00E5FF`, `#00E676`) permitiendo reversibilidad total instantánea.

---

## 3. Arquitectura Técnica de Transición Dinámica (WPF DynamicResource)

1. **Recursos Dinámicos (`DynamicResource`):**  
   Los elementos XAML de fondo, bordes, encabezados y botones se vinculan a 25 claves de recursos dinámicos (`WindowBgBrush`, `CardBgBrush`, `AccentPrimaryBrush`, etc.).  
   Al cambiar el valor en `$window.Resources`, WPF repinta instantáneamente la ventana sin parpadeo ni necesidad de reinicio de la aplicación.
2. **Selector Visual en la Cabecera:**  
   Se integró un selector discreto y elegante en el Header superior (`cmbThemeSelector`), permitiendo al usuario probar los 3 temas y cambiar entre ellos con 1 clic en caliente.
3. **Persistencia Trans-Sesión:**  
   La preferencia de tema se almacena en `HKCU:\Software\romanOS\Theme`, de modo que tanto `romanOS-ControlCenter.ps1` como `romanOS-Studio.ps1` inician siempre con el tema seleccionado.

---

## 4. Fases de Ejecución

- [x] **Fase 1:** Implementación de `Get-RomanOSGuiThemes` y `Apply-RomanOSGuiTheme` en `scripts/Core/UI-Engine.ps1`.
- [x] **Fase 2:** Migración de `romanOS-ControlCenter.ps1` a `DynamicResource`, aplicación de la Opción 1 e integración del selector de temas.
- [x] **Fase 3:** Migración de `romanOS-Studio.ps1` a `DynamicResource` para paridad estética completa.
- [x] **Fase 4:** Verificación de compatibilidad con Windows PowerShell 5.1 (`powershell.exe -STA`) y UTF-8 con BOM.
- [x] **Fase 5:** Ejecución del Test Harness (`Test-GuiIntegrityAndFunctionality.ps1` y `Invoke-TestSuite.ps1`) certificando cero roturas en los 101 botones.
- [x] **Fase 6:** Commit atómico y entrega al usuario para evaluación interactiva.