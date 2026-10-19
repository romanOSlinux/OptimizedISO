# Referencia Rápida de Comandos — New-OptimizedWindowsISO.ps1

> 💡 **Guía Completa de la Suite romanOS:** Para consultar todas las opciones de ejecución, menús interactivos y parámetros CLI de **todos los scripts del repositorio** (Toolkit Maestro, Debloat, Mantenimiento, Red, Seguridad, Diagnósticos y Compilación de ISOs), consulta la **[Guía Maestra de Lanzamiento y Comandos](GUIA_DE_EJECUCION_Y_COMANDOS.md)**.

> Todos los comandos deben ejecutarse en **PowerShell como Administrador** desde la carpeta raíz del proyecto.
>
> ⚠️ La ISO resultante es **Zero-Touch**: formatea el Disco 0 sin preguntar.

---

## Modo Interactivo (Sin Parámetros)

El script pedirá la ISO origen, el script optimizador y mostrará menús de selección.

```powershell
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1
```

---

## Uso Básico con Usuario Local

```powershell
# Usuario "Usuario" sin contraseña
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 -LocalUser "Usuario"

# Usuario "Usuario" con contraseña
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 -LocalUser "Usuario" -LocalPassword "MiClave123"
```

---

## Especificar ISO de Origen

```powershell
# ISO de Windows 11 descargada manualmente
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Users\Usuario\Downloads\Win11_24H2_Spanish_x64.iso" `
  -LocalUser "Usuario"

# ISO de Windows 11 IoT Enterprise LTSC 2024
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "D:\ISOs\Win11_LTSC_2024.iso" `
  -LocalUser "Usuario"
```

---

## Idioma y Zona Horaria

```powershell
# España (por defecto)
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Usuario" `
  -Language "es-ES" `
  -Timezone "Romance Standard Time"

# Argentina
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Usuario" `
  -Language "es-AR" `
  -Timezone "Argentina Standard Time"

# México
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Usuario" `
  -Language "es-MX" `
  -Timezone "Central Standard Time (Mexico)"

# Estados Unidos (Inglés)
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Usuario" `
  -Language "en-US" `
  -Timezone "Eastern Standard Time"

# Brasil (Portugués)
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Usuario" `
  -Language "pt-BR" `
  -Timezone "E. South America Standard Time"
```

---

## Teclado Distinto al Idioma

```powershell
# Idioma español de España, pero teclado latinoamericano
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Usuario" `
  -Language "es-ES" `
  -KeyboardOverride "es-419"

# Idioma español, teclado US International
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Usuario" `
  -Language "es-ES" `
  -KeyboardOverride "en-US"
```

---

## Selección de Edición del WIM (Índice)

```powershell
# Solo inyectar en Windows 11 Pro (índice 3, verificar con el menú)
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Usuario" `
  -TargetWimIndex "3"

# Inyectar en dos ediciones específicas (ej. Home e Pro)
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Usuario" `
  -TargetWimIndex "1,3"

# Inyectar en TODAS las ediciones (mismo efecto que omitirlo y elegir "A")
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Usuario" `
  -TargetWimIndex "all"
```

---

## Carpeta de Salida Personalizada

```powershell
# Guardar la ISO en otra carpeta
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Usuario" `
  -OutputDir "D:\ISOs_Modificadas"

# Guardar directamente en un pendrive (letra E:)
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Usuario" `
  -OutputDir "E:\"
```

---

## Instalar Dependencias Automáticamente

```powershell
# El script instalará 7-Zip y oscdimg via winget si no están presentes
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Usuario" `
  -AutoInstallDeps
```

---

## Auto-Logon Repetido

```powershell
# Iniciar sesión automáticamente 3 veces (útil para scripts que necesitan reiniciar)
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Usuario" `
  -AutoLogonCount 3
```

---

## Solo Preparar Archivos (Sin Crear ISO)

```powershell
# Extrae, inyecta y prepara todo, pero NO empaqueta la ISO final
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Win11.iso" `
  -LocalUser "Usuario" `
  -SkipISOCreation
```

---

## Sin Archivo Unattend (Instalación Manual)

```powershell
# Crea la ISO con los scripts inyectados, pero SIN autounattend.xml
# La instalación será manual (seleccionar disco, usuario, etc.)
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Win11.iso" `
  -SkipAutoUnattend
```

---

## Comando Completo (Todos los Parámetros)

```powershell
.\scripts\Builder\New-OptimizedWindowsISO-v2.ps1 `
  -SourceISO "C:\Users\Usuario\Downloads\Win11_24H2_Spanish_x64.iso" `
  -OutputDir "D:\ISOs_Modificadas" `
  -WindowsVersion "11" `
  -LocalUser "Usuario" `
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
