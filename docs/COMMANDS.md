# Referencia Rápida de Comandos — New-OptimizedWindowsISO.ps1

> Todos los comandos deben ejecutarse en **PowerShell como Administrador** desde la carpeta raíz del proyecto.
>
> ⚠️ La ISO resultante es **Zero-Touch**: formatea el Disco 0 sin preguntar.

---

## Modo Interactivo (Sin Parámetros)

El script pedirá la ISO origen, el script optimizador y mostrará menús de selección.

```powershell
.\scripts\New-OptimizedWindowsISO.ps1
```

---

## Uso Básico con Usuario Local

```powershell
# Usuario "Roman" sin contraseña
.\scripts\New-OptimizedWindowsISO.ps1 -LocalUser "Roman"

# Usuario "Roman" con contraseña
.\scripts\New-OptimizedWindowsISO.ps1 -LocalUser "Roman" -LocalPassword "MiClave123"
```

---

## Especificar ISO de Origen

```powershell
# ISO de Windows 11 descargada manualmente
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Users\Roman\Downloads\Win11_24H2_Spanish_x64.iso" `
  -LocalUser "Roman"

# ISO de Windows 10
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "D:\ISOs\Win10_22H2.iso" `
  -LocalUser "Roman" `
  -WindowsVersion "10"
```

---

## Idioma y Zona Horaria

```powershell
# España (por defecto)
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Roman" `
  -Language "es-ES" `
  -Timezone "Romance Standard Time"

# Argentina
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Roman" `
  -Language "es-AR" `
  -Timezone "Argentina Standard Time"

# México
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Roman" `
  -Language "es-MX" `
  -Timezone "Central Standard Time (Mexico)"

# Estados Unidos (Inglés)
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Roman" `
  -Language "en-US" `
  -Timezone "Eastern Standard Time"

# Brasil (Portugués)
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Roman" `
  -Language "pt-BR" `
  -Timezone "E. South America Standard Time"
```

---

## Teclado Distinto al Idioma

```powershell
# Idioma español de España, pero teclado latinoamericano
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Roman" `
  -Language "es-ES" `
  -KeyboardOverride "es-419"

# Idioma español, teclado US International
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Roman" `
  -Language "es-ES" `
  -KeyboardOverride "en-US"
```

---

## Selección de Edición del WIM (Índice)

```powershell
# Solo inyectar en Windows 11 Pro (índice 3, verificar con el menú)
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Roman" `
  -TargetWimIndex "3"

# Inyectar en dos ediciones específicas (ej. Home e Pro)
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Roman" `
  -TargetWimIndex "1,3"

# Inyectar en TODAS las ediciones (mismo efecto que omitirlo y elegir "A")
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Roman" `
  -TargetWimIndex "all"
```

---

## Carpeta de Salida Personalizada

```powershell
# Guardar la ISO en otra carpeta
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Roman" `
  -OutputDir "D:\ISOs_Modificadas"

# Guardar directamente en un pendrive (letra E:)
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Roman" `
  -OutputDir "E:\"
```

---

## Instalar Dependencias Automáticamente

```powershell
# El script instalará 7-Zip y oscdimg via winget si no están presentes
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Roman" `
  -AutoInstallDeps
```

---

## Auto-Logon Repetido

```powershell
# Iniciar sesión automáticamente 3 veces (útil para scripts que necesitan reiniciar)
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Roman" `
  -AutoLogonCount 3
```

---

## Solo Preparar Archivos (Sin Crear ISO)

```powershell
# Extrae, inyecta y prepara todo, pero NO empaqueta la ISO final
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Roman" `
  -SkipISOCreation
```

---

## Sin Archivo Unattend (Instalación Manual)

```powershell
# Crea la ISO con los scripts inyectados, pero SIN autounattend.xml
# La instalación será manual (seleccionar disco, usuario, etc.)
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Win11.iso" `
  -SkipAutoUnattend
```

---

## Comando Completo (Todos los Parámetros)

```powershell
.\scripts\New-OptimizedWindowsISO.ps1 `
  -SourceISO "C:\Users\Roman\Downloads\Win11_24H2_Spanish_x64.iso" `
  -OutputDir "D:\ISOs_Modificadas" `
  -WindowsVersion "11" `
  -LocalUser "Roman" `
  -LocalPassword "Secreta123" `
  -AutoLogonCount 1 `
  -Language "es-AR" `
  -Timezone "Argentina Standard Time" `
  -KeyboardOverride "es-419" `
  -TargetWimIndex "3" `
  -AutoInstallDeps
```

---

## Tabla de Zonas Horarias Comunes

| País / Región | Valor de `-Timezone` |
|:---|:---|
| España | `Romance Standard Time` |
| Argentina | `Argentina Standard Time` |
| México (Centro) | `Central Standard Time (Mexico)` |
| Colombia / Perú | `SA Pacific Standard Time` |
| Chile | `Pacific SA Standard Time` |
| Venezuela | `Venezuela Standard Time` |
| USA (Este) | `Eastern Standard Time` |
| USA (Pacífico) | `Pacific Standard Time` |
| Brasil (São Paulo) | `E. South America Standard Time` |
| UK | `GMT Standard Time` |

---

## Tabla de Idiomas Comunes

| Idioma | Valor de `-Language` |
|:---|:---|
| Español (España) | `es-ES` |
| Español (Argentina) | `es-AR` |
| Español (México) | `es-MX` |
| Español (Latinoamérica genérico) | `es-419` |
| Inglés (USA) | `en-US` |
| Inglés (UK) | `en-GB` |
| Portugués (Brasil) | `pt-BR` |
| Francés | `fr-FR` |
| Alemán | `de-DE` |
| Italiano | `it-IT` |
