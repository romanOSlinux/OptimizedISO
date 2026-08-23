---
name: powershell-windows
description: "Contexto para scripts PowerShell orientados a Windows: sintaxis PS, manipulación de registry, DISM, debloat, y diferencias clave con bash. El target es Windows."
---

# PowerShell para Windows

Skill para asistir al usuario con scripts PowerShell para sistemas Windows.

## Contexto importante

- **El código PowerShell es para Windows**.
- En Windows, utilizar PowerShell 5.1 o PowerShell 7+.
- Soporta cmdlets de administración de DISM, registro y WMI.

## Sintaxis clave de PowerShell

| Concepto | Bash | PowerShell |
|---|---|---|
| Variables | `$var` | `$var` (igual, pero scope es diferente) |
| Asignación | `var="valor"` | `$var = "valor"` |
| Comparación | `-eq` (numérico), `==` (string) | `-eq`, `-ne`, `-gt`, `-lt` (para todo) |
| String interp. | `"Hola $var"` | `"Hola $var"` (comillas dobles interpolan, simples NO) |
| Arrays | `arr=(a b c)` | `$arr = @("a", "b", "c")` |
| Hashtables | `declare -A` | `@{ key = "val" }` |
| Pipes | Pasan texto | **Pasan objetos** |
| Nulo | `-z "$var"` | `$null -eq $var` |
| Error handling | `set -e` / `trap` | `$ErrorActionPreference` / `try/catch` |
| Elevation | `sudo` | `Start-Process -Verb RunAs` |

## Patrones comunes en los scripts del proyecto

### Manipulación de Registry
```powershell
$path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows"
if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
Set-ItemProperty -Path $path -Name "DisableTelemetry" -Value 1 -Type DWord
```

### Remover Appx (Bloatware)
```powershell
Get-AppxPackage -Name "*BingWeather*" -AllUsers | Remove-AppxPackage -AllUsers
Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like "*Xbox*" | Remove-AppxProvisionedPackage -Online
```

### Operaciones DISM
```powershell
DISM /Online /Disable-Feature /FeatureName:"WindowsMediaPlayer" /NoRestart
```

### Logging pattern
```powershell
$logDir = "C:\Logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$log = "$logDir\Setup-Windows.log"
"Mensaje" | Tee-Object -FilePath $log -Append
```

## Reglas y Buenas Prácticas
- **Codificación:** Todo archivo `.ps1` debe guardarse **siempre en UTF-8 con BOM (`UTF-8-BOM`)**. Sin BOM, Windows PowerShell 5.1 decodifica caracteres multi-byte como ANSI Windows-1252, corrompiendo las comillas y rompiendo el script.
- **Validación en Runtime Real:** Probar siempre los scripts invocando directamente `powershell.exe` (Windows PowerShell 5.1) y no únicamente en el entorno del asistente (PowerShell 7).
- **Lanzadores `.cmd` y GUI:** Al invocar PowerShell desde CMD para scripts con interfaz gráfica (`Out-GridView`, WPF), pasar siempre el flag `-STA` (`powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File ...`).
- **Paths en Windows usan `\`** (backslash).
- **Scripts con `#Requires -RunAsAdministrator`** necesitan PowerShell elevado.
- Mantener `$ErrorActionPreference = 'Continue'` según diseño del proyecto.

