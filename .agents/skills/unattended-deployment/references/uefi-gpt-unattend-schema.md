# Esquema de Referencia: autounattend.xml para Windows 10/11 UEFI GPT

Estructura canónica oficial de particionado UEFI GPT según Microsoft Learn:

---

## 1. Esquema de 4 Particiones UEFI GPT (Oficial Microsoft)

```xml
<DiskConfiguration>
  <Disk wcm:action="add">
    <DiskID>0</DiskID>
    <WillWipeDisk>true</WillWipeDisk>
    <CreatePartitions>
      <!-- 1. Partición de Recuperación (WinRE) 500 MB -->
      <CreatePartition wcm:action="add">
        <Order>1</Order>
        <Type>Primary</Type>
        <Size>500</Size>
      </CreatePartition>
      <!-- 2. Partición de Sistema EFI 100 MB -->
      <CreatePartition wcm:action="add">
        <Order>2</Order>
        <Type>EFI</Type>
        <Size>100</Size>
      </CreatePartition>
      <!-- 3. Partición Reservada de Microsoft (MSR) 16 MB -->
      <CreatePartition wcm:action="add">
        <Order>3</Order>
        <Type>MSR</Type>
        <Size>16</Size>
      </CreatePartition>
      <!-- 4. Partición Principal de Windows (Resto del disco) -->
      <CreatePartition wcm:action="add">
        <Order>4</Order>
        <Type>Primary</Type>
        <Extend>true</Extend>
      </CreatePartition>
    </CreatePartitions>
    <ModifyPartitions>
      <!-- Modificar 1: WinRE (TypeID de94bba4-06d1-4d40-a16a-bfd50179d6ac) -->
      <ModifyPartition wcm:action="add">
        <Order>1</Order>
        <PartitionID>1</PartitionID>
        <Format>NTFS</Format>
        <Label>Recovery</Label>
        <TypeID>de94bba4-06d1-4d40-a16a-bfd50179d6ac</TypeID>
      </ModifyPartition>
      <!-- Modificar 2: EFI System (FAT32) -->
      <ModifyPartition wcm:action="add">
        <Order>2</Order>
        <PartitionID>2</PartitionID>
        <Format>FAT32</Format>
        <Label>System</Label>
      </ModifyPartition>
      <!-- Modificar 3: MSR (No se formatea) -->
      <ModifyPartition wcm:action="add">
        <Order>3</Order>
        <PartitionID>3</PartitionID>
      </ModifyPartition>
      <!-- Modificar 4: Windows OS (NTFS) -->
      <ModifyPartition wcm:action="add">
        <Order>4</Order>
        <PartitionID>4</PartitionID>
        <Format>NTFS</Format>
        <Label>Windows</Label>
      </ModifyPartition>
    </ModifyPartitions>
  </Disk>
</DiskConfiguration>
```

---

## 2. Inyección de Destino de Instalación (`InstallTo`)

```xml
<ImageInstall>
  <OSImage>
    <InstallFrom>
      <MetaData wcm:action="add">
        <Key>/IMAGE/INDEX</Key>
        <Value>1</Value>
      </MetaData>
    </InstallFrom>
    <InstallTo>
      <DiskID>0</DiskID>
      <PartitionID>4</PartitionID>
    </InstallTo>
  </OSImage>
</ImageInstall>
```
