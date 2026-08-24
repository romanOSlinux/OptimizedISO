# Referencia de Esquema XML: `autounattend.xml`

## 1. Layout de Particionamiento UEFI / GPT Estándar

El esquema oficial de Microsoft para Windows 11 requiere 4 particiones en discos GPT:

```xml
<Disk wcm:action="add">
    <DiskID>0</DiskID>
    <WillWipeDisk>true</WillWipeDisk>
    <CreatePartitions>
        <!-- 1. WinRE (Entorno de Recuperación) -->
        <CreatePartition wcm:action="add">
            <Order>1</Order>
            <Type>Primary</Type>
            <Size>500</Size>
        </CreatePartition>
        <!-- 2. EFI System Partition (ESP) -->
        <CreatePartition wcm:action="add">
            <Order>2</Order>
            <Type>EFI</Type>
            <Size>100</Size>
        </CreatePartition>
        <!-- 3. Microsoft Reserved (MSR) -->
        <CreatePartition wcm:action="add">
            <Order>3</Order>
            <Type>MSR</Type>
            <Size>16</Size>
        </CreatePartition>
        <!-- 4. Sistema Operativo Windows -->
        <CreatePartition wcm:action="add">
            <Order>4</Order>
            <Type>Primary</Type>
            <Extend>true</Extend>
        </CreatePartition>
    </CreatePartitions>
    <ModifyPartitions>
        <ModifyPartition wcm:action="add">
            <Order>1</Order>
            <PartitionID>1</PartitionID>
            <Label>WinRE</Label>
            <Format>NTFS</Format>
            <TypeID>de94bba4-06d1-4d40-a16a-bfd50179d6ac</TypeID>
        </ModifyPartition>
        <ModifyPartition wcm:action="add">
            <Order>2</Order>
            <PartitionID>2</PartitionID>
            <Label>System</Label>
            <Format>FAT32</Format>
        </ModifyPartition>
        <ModifyPartition wcm:action="add">
            <Order>3</Order>
            <PartitionID>3</PartitionID>
        </ModifyPartition>
        <ModifyPartition wcm:action="add">
            <Order>4</Order>
            <PartitionID>4</PartitionID>
            <Label>Windows</Label>
            <Format>NTFS</Format>
        </ModifyPartition>
    </ModifyPartitions>
</Disk>
```

---

## 2. Inyección de Instalación en la Partición de Windows

```xml
<InstallTo>
    <DiskID>0</DiskID>
    <PartitionID>4</PartitionID>
</InstallTo>
```
