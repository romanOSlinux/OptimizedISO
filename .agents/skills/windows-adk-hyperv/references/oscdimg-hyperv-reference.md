# Referencia Técnica: oscdimg y Automatización Hyper-V

## 1. Flags Oficiales de oscdimg para Arranque Dual (BIOS + UEFI)

```powershell
$bootEtfs = "$isoSourceDir\boot\etfsboot.com"
$bootEfis = "$isoSourceDir\efi\microsoft\boot\efisys.bin"

$oscdimgArgs = @(
    "-m",              # Ignora el límite de tamaño de imagen de 700 MB
    "-o",              # Optimiza el almacenamiento codificando archivos duplicados una sola vez
    "-u2",             # Produce un sistema de archivos UDF exclusivamente
    "-udfver102",      # Especifica la versión 1.02 de UDF (máxima compatibilidad)
    "-bootdata:2#p0,e,b`"$bootEtfs`"#pEF,e,b`"$bootEfis`"", # Configuración multi-boot El Torito
    "`"$isoSourceDir`"",
    "`"$destinationIso`""
)
& $oscdimg $oscdimgArgs
```

---

## 2. Creación y Configuración de VM UEFI Gen2 con TPM en Hyper-V

```powershell
$vmName = "TestVM_Optimized"
$vhdPath = "$HOME\Virtual Machines\$vmName.vhdx"

# Crear VM Gen2 con disco de 60 GB
New-VM -Name $vmName -MemoryStartupBytes 4GB -Generation 2 -NewVHDPath $vhdPath -NewVHDSizeBytes 60GB
Set-VMProcessor -VMName $vmName -Count 4

# Habilitar TPM y Secure Boot para Windows 11
Set-VMKeyProtector -VMName $vmName -NewLocalKeyProtector
Enable-VMTPM -VMName $vmName
Set-VMFirmware -VMName $vmName -EnableSecureBoot On -SecureBootTemplate "MicrosoftWindows"

# Asignar ISO y configurar arranque prioritario
Add-VMDvdDrive -VMName $vmName -Path $isoPath
$dvd = Get-VMDvdDrive -VMName $vmName
Set-VMFirmware -VMName $vmName -FirstBootDevice $dvd

# Iniciar VM
Start-VM -Name $vmName
```
