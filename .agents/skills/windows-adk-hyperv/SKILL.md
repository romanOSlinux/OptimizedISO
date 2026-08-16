---
name: windows-adk-hyperv
description: "Flujos de trabajo para compilar ISOs con Windows ADK (oscdimg), montar/desmontar imágenes WIM con DISM y automatizar pruebas en Hyper-V."
---

# Windows ADK y Hyper-V Automation

Skill para operar compilaciones y pruebas automatizadas en entornos nativos de Windows 11.

## 1. Localización y Parámetros de `oscdimg.exe`

Ubicaciones estándar en Windows 11:
- `C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe`
- `C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\arm64\Oscdimg\oscdimg.exe`

Flags para arranque dual El Torito (UEFI + BIOS):
```powershell
$oscdimgArgs = @(
    "-m", "-o", "-u2", "-udfver102",
    "-bootdata:2#p0,e,b`"$bootEtfs`"#pEF,e,b`"$bootEfis`"",
    "`"$isoSourceDir`"",
    "`"$destinationIso`""
)
& $oscdimg $oscdimgArgs
```

## 2. Automatización de Pruebas de Arranque en Hyper-V

Creación y arranque de VM UEFI Gen2 con TPM para probar ISOs desatendidas:
```powershell
$vmName = "TestVM_Optimized"
$vhdPath = "$HOME\Virtual Machines\$vmName.vhdx"

New-VM -Name $vmName -MemoryStartupBytes 4GB -Generation 2 -NewVHDPath $vhdPath -NewVHDSizeBytes 60GB
Set-VMProcessor -VMName $vmName -Count 4
Set-VMKeyProtector -VMName $vmName -NewLocalKeyProtector
Enable-VMTPM -VMName $vmName

Add-VMDvdDrive -VMName $vmName -Path $isoPath
$dvd = Get-VMDvdDrive -VMName $vmName
Set-VMFirmware -VMName $vmName -FirstBootDevice $dvd

Start-VM -Name $vmName
```
