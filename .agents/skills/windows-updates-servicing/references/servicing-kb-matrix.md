# Matriz Técnica: Arquitectura de Inyección de Windows Updates (DISM Servicing)

Esta guía documenta los requisitos de Microsoft Learn para el *slipstreaming* e inyección offline de parches `.msu` y `.cab` en imágenes WIM.

---

## 1. Orden de Inyección Estricto de DISM (`/Add-Package`)

Microsoft DISM (`dism.exe`) procesa paquetes en el orden en que se especifican. El orden técnico obligatorio es:

```
┌──────────────────────────────────────────────────────────────────────────┐
│ 1. SSU (Servicing Stack Update)                                          │
│    Actualiza los binarios de mantenimiento del sistema operativo base.   │
├──────────────────────────────────────────────────────────────────────────┤
│ 2. Checkpoint Base Update (KB5043080)                                    │
│    Obligatorio en Windows 11 24H2, 25H2 y LTSC 2024 antes de la LCU.    │
├──────────────────────────────────────────────────────────────────────────┤
│ 3. LCU (Latest Cumulative Update)                                        │
│    Parche acumulativo mensual de seguridad y calidad.                    │
├──────────────────────────────────────────────────────────────────────────┤
│ 4. Cumulative Update for .NET Framework                                  │
│    Parches de seguridad para .NET 3.5 y .NET 4.8.1.                      │
├──────────────────────────────────────────────────────────────────────────┤
│ 5. SafeOS / WinRE Dynamic Updates (.cab)                                 │
│    Actualización opcional del entorno de recuperación en winre.wim.      │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Inyección Offline Paso a Paso vía CLI

```powershell
# 1. Montar imagen WIM
DISM /Mount-Image /ImageFile:"C:\Build\sources\install.wim" /Index:1 /MountDir:"C:\Build\Mount"

# 2. Inyectar SSU (si viene separado)
DISM /Image:"C:\Build\Mount" /Add-Package /PackagePath:"C:\Updates\SSU-Windows11.msu" /IgnoreCheck /PreventPending

# 3. Inyectar Checkpoint Base (Win 11 24H2)
DISM /Image:"C:\Build\Mount" /Add-Package /PackagePath:"C:\Updates\Windows11.0-KB5043080-x64.msu" /IgnoreCheck /PreventPending

# 4. Inyectar LCU Mensual
DISM /Image:"C:\Build\Mount" /Add-Package /PackagePath:"C:\Updates\Windows11.0-KB5044284-x64.msu" /IgnoreCheck /PreventPending

# 5. Inyectar .NET Framework CU
DISM /Image:"C:\Build\Mount" /Add-Package /PackagePath:"C:\Updates\Windows11.0-KB5044033-x64-NDP481.msu" /IgnoreCheck /PreventPending

# 6. Limpieza profunda WinSxS y desmonte con guardado
DISM /Image:"C:\Build\Mount" /Cleanup-Image /StartComponentCleanup /ResetBase
DISM /Unmount-Image /MountDir:"C:\Build\Mount" /Commit
```

---

## 3. Códigos de Salida Relevantes en DISM

| Código | Significado | Tratamiento |
| :--- | :--- | :--- |
| `0` | Éxito | Continuar proceso. |
| `3010` | Éxito con reinicio requerido | Tratar como éxito (`Success = $true`). |
| `0x800f081f` | Archivo de origen no encontrado / Dependencia faltante | Falta SSU o Checkpoint KB5043080 previo. |
| `0x800f0823` | Paquete no aplicable a esta arquitectura/edición | Verificar si la build coincide con la ISO montada. |
