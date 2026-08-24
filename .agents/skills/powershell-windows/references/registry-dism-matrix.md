# Matriz de Referencia: Registry Tweaks & DISM Servicing

## 1. Patrones de Manipulación del Registro (Registry)

### Creación segura y tipado estricto
```powershell
$keyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (-not (Test-Path $keyPath)) {
    New-Item -Path $keyPath -Force | Out-Null
}
Set-ItemProperty -Path $keyPath -Name "AllowTelemetry" -Value 0 -Type DWord
```

### Eliminación segura de claves
```powershell
$targetKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
if (Get-ItemProperty -Path $targetKey -Name "BloatwareApp" -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path $targetKey -Name "BloatwareApp" -Force
}
```

---

## 2. Operaciones Clave de DISM

### Deshabilitar características opcionales sin reinicio
```powershell
DISM /Online /Disable-Feature /FeatureName:"WindowsMediaPlayer" /NoRestart
```

### Inyección Offline de Paquetes en WIM montado
```powershell
DISM /Image:"$mountDir" /Add-Package /PackagePath:"$packagePath" /IgnoreCheck /PreventPending
```

### Limpieza profunda de almacén de componentes (WinSxS)
```powershell
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
```

---

## 3. Eliminación de Paquetes AppX y ProvisionedAppX

```powershell
# Usuario actual y todos los usuarios
Get-AppxPackage -Name "*BingWeather*" -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

# Imagen del sistema (para nuevas cuentas)
Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like "*Xbox*" | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
```
