<#
.SYNOPSIS
    Migra un usuario local de Windows 11 a una cuenta nueva de forma segura y por etapas.
.DESCRIPTION
    Herramienta interactiva para reemplazar una cuenta de usuario local (por perfil corrupto
    o necesidad de partir de cero) sin perder acceso a los datos. Cada etapa se ejecuta por
    separado para poder validar la cuenta nueva unos dias antes de borrar la vieja.
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$ListOnly,
    [switch]$SkipElevation,
    [switch]$PassThru,
    [switch]$NonInteractive,
    [switch]$Unattended,
    [string]$OldUser,
    [string]$NewUser,
    [System.Security.SecureString]$Password,
    [string]$FullName,
    [ValidateSet('List', 'Create', 'Migrate', 'Disable', 'Delete', 'Checklist')]
    [string]$Action
)

# ============================================================
#  Migrar-Usuario-W11.ps1
#  Migracion segura de cuenta de usuario local en Windows 11
# ============================================================

$isSimulated = ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf') -or $WhatIfPreference)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# --- Auto-elevacion (solo requerida para mutaciones del sistema) ---
if (-not $isAdmin -and -not $SkipElevation -and -not $isSimulated -and -not $ListOnly -and ($Action -ne 'List' -and $Action -ne 'Checklist')) {
    Write-Host "Se requieren permisos de administrador. Reiniciando con elevacion..." -ForegroundColor Yellow
    try {
        Start-Process powershell.exe -ArgumentList "-STA -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    } catch {
        Write-Warning "No se pudo iniciar proceso elevado automáticamente: $($_.Exception.Message)"
    }
}

try {
    $Host.UI.RawUI.WindowTitle = "Migrar-Usuario-W11"
} catch {
    Write-Verbose "No se pudo ajustar WindowTitle en consola no interactiva: $($_.Exception.Message)"
}
$script:OldUserName = if ($OldUser) { $OldUser } else { $null }
$script:NewUserName = if ($NewUser) { $NewUser } else { $null }

function Get-ProfilesBasePath {
    $profilesDir = try {
        $regProfiles = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -ErrorAction Stop).ProfilesDirectory
        if ($regProfiles) {
            [System.Environment]::ExpandEnvironmentVariables($regProfiles)
        } else {
            $null
        }
    } catch {
        Write-Warning "No se pudo consultar ProfilesDirectory en el registro: $($_.Exception.Message). Usando ruta fallback."
        $null
    }
    if (-not $profilesDir -or -not (Test-Path $profilesDir)) {
        $profilesDir = if ($env:SystemDrive) { "$($env:SystemDrive)\Users" } else { "C:\Users" }
    }
    return $profilesDir
}

function Write-Titulo {
    param([string]$Texto)
    if (-not [Console]::IsInputRedirected -and -not $isSimulated -and -not $NonInteractive -and -not $Unattended) {
        Clear-Host
    }
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  $Texto" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Pausar {
    if (-not [Console]::IsInputRedirected -and -not $isSimulated -and -not $NonInteractive -and -not $Unattended) {
        Write-Host ""
        Read-Host "Presione Enter para volver al menu"
    }
}

function Confirmar-NombresUsuario {
    if (-not $script:OldUserName) {
        if ($NonInteractive -or $Unattended) {
            Write-Warning "No se especifico parametro -OldUser en ejecucion desatendida."
            return
        }
        $script:OldUserName = Read-Host "Nombre de la cuenta ACTUAL (a reemplazar)"
    }
    if (-not $script:NewUserName) {
        if ($NonInteractive -or $Unattended) {
            Write-Warning "No se especifico parametro -NewUser en ejecucion desatendida."
            return
        }
        $script:NewUserName = Read-Host "Nombre de la cuenta NUEVA"
    }
}

function Mostrar-EstadoCuentas {
    Write-Titulo "Estado de cuentas locales"
    $cuentas = Get-LocalUser | Select-Object Name, Enabled, LastLogon
    $cuentas | Format-Table -AutoSize
    Pausar
    if ($PassThru) { return $cuentas }
}

function Crear-CuentaNueva {
    Write-Titulo "Crear cuenta nueva"
    Confirmar-NombresUsuario
    if (-not $script:NewUserName) { return }

    if (Get-LocalUser -Name $script:NewUserName -ErrorAction SilentlyContinue) {
        Write-Host "La cuenta '$($script:NewUserName)' ya existe. No se crea de nuevo." -ForegroundColor Yellow
        Pausar
        return
    }

    $passToUse = $Password
    if (-not $passToUse) {
        if ($NonInteractive -or $Unattended) {
            Write-Warning "No se proporciono -Password para crear la cuenta '$($script:NewUserName)' en modo no interactivo."
            return
        }
        $passToUse = Read-Host "Contrasena para $($script:NewUserName)" -AsSecureString
    }

    $nomComp = $FullName
    if (-not $nomComp -and -not ($NonInteractive -or $Unattended)) {
        $nomComp = Read-Host "Nombre completo (opcional, Enter para omitir)"
    }

    try {
        $params = @{
            Name     = $script:NewUserName
            Password = $passToUse
        }
        if ($nomComp) { $params["FullName"] = $nomComp }
        New-LocalUser @params -ErrorAction Stop
        Write-Host "Cuenta '$($script:NewUserName)' creada correctamente." -ForegroundColor Green
    } catch {
        Write-Warning "Error al crear la cuenta '$($script:NewUserName)': $($_.Exception.Message)"
        Pausar
        return
    }

    Write-Host ""
    Write-Host "Grupos locales a los que pertenece '$($script:OldUserName)':" -ForegroundColor Cyan
    $GruposViejo = if ($script:OldUserName) {
        Get-LocalGroup | Where-Object {
            (Get-LocalGroupMember -Group $_.Name -ErrorAction SilentlyContinue) |
                Where-Object { $_.Name -like "*\$($script:OldUserName)" }
        }
    } else { $null }

    if ($GruposViejo) {
        $GruposViejo | ForEach-Object { Write-Host " - $($_.Name)" }
        $Replicar = if ($NonInteractive -or $Unattended) { "S" } else { Read-Host "`nAgregar '$($script:NewUserName)' a estos mismos grupos? (S/N)" }
        if ($Replicar -eq "S" -or $Replicar -eq "s") {
            foreach ($Grupo in $GruposViejo) {
                try {
                    Add-LocalGroupMember -Group $Grupo.Name -Member $script:NewUserName -ErrorAction Stop
                    Write-Host "Agregado a '$($Grupo.Name)'." -ForegroundColor Green
                } catch {
                    Write-Warning "No se pudo agregar '$($script:NewUserName)' a '$($Grupo.Name)': $($_.Exception.Message)"
                }
            }
        }
    } else {
        Write-Host "No se encontraron grupos, o no se pudo verificar. Se agrega a Administradores por defecto."
        try {
            Add-LocalGroupMember -Group "Administradores" -Member $script:NewUserName -ErrorAction Stop
            Write-Host "Agregado a Administradores." -ForegroundColor Green
        } catch {
            Write-Warning "No se pudo agregar a Administradores: $($_.Exception.Message)"
        }
    }

    Write-Host "`nIMPORTANTE: inicie sesion una vez con '$($script:NewUserName)' antes de migrar datos," -ForegroundColor Yellow
    Write-Host "asi Windows genera la carpeta de perfil $(Join-Path (Get-ProfilesBasePath) $script:NewUserName)." -ForegroundColor Yellow
    Pausar
}

function Migrar-Datos {
    Write-Titulo "Migrar datos de usuario"
    Confirmar-NombresUsuario
    if (-not $script:OldUserName -or -not $script:NewUserName) { return }

    $baseProfiles = Get-ProfilesBasePath
    $OrigenBase = Join-Path $baseProfiles $script:OldUserName
    $DestinoBase = Join-Path $baseProfiles $script:NewUserName

    if (-not (Test-Path $OrigenBase)) {
        Write-Warning "No se encontro el perfil de origen: $OrigenBase"
        Pausar
        return
    }
    if (-not (Test-Path $DestinoBase)) {
        Write-Warning "No se encontro el perfil de destino: $DestinoBase. Inicie sesion al menos una vez con '$($script:NewUserName)' antes de migrar."
        Pausar
        return
    }

    Write-Host "Se migraran: Desktop, Documents, Downloads, Pictures, Videos, Music" -ForegroundColor Cyan
    Write-Host "NO se copia AppData (si el motivo es un perfil corrupto, suele estar ahi la causa)." -ForegroundColor Yellow
    $Confirma = if ($NonInteractive -or $Unattended) { "S" } else { Read-Host "`nContinuar? (S/N)" }
    if ($Confirma -ne "S" -and $Confirma -ne "s") { return }

    $Carpetas = "Desktop", "Documents", "Downloads", "Pictures", "Videos", "Music"
    foreach ($Carpeta in $Carpetas) {
        $Origen = Join-Path $OrigenBase $Carpeta
        $Destino = Join-Path $DestinoBase $Carpeta
        if (Test-Path $Origen) {
            Write-Host "`nCopiando $Carpeta..." -ForegroundColor Cyan
            robocopy $Origen $Destino /E /COPY:DAT /R:1 /W:1 /NFL /NDL | Out-Null
            if ($LASTEXITCODE -lt 8) {
                Write-Host "$Carpeta copiada correctamente (codigo $LASTEXITCODE)." -ForegroundColor Green
            } else {
                Write-Warning "$Carpeta con advertencias o errores durante la copia (codigo robocopy $LASTEXITCODE)."
            }
        } else {
            Write-Host "$Carpeta no existe en el perfil de origen, se omite." -ForegroundColor DarkGray
        }
    }
    Pausar
}

function Mostrar-Checklist {
    Write-Titulo "Checklist de reconfiguracion manual"
    Write-Host "Estos elementos no se migran con archivos y deben rehacerse en la cuenta nueva:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " [ ] Marcadores y contrasenas del navegador (exportar/importar desde el navegador)"
    Write-Host " [ ] Unidades de red mapeadas"
    Write-Host " [ ] Impresoras instaladas"
    Write-Host " [ ] Configuracion de clientes de correo"
    Write-Host " [ ] Conexiones VPN"
    Write-Host " [ ] Licencias de software atadas al perfil anterior"
    Write-Host " [ ] Certificados personales / claves EFS si se usan"
    Pausar
}

function Deshabilitar-CuentaVieja {
    Write-Titulo "Deshabilitar cuenta anterior"
    Confirmar-NombresUsuario
    if (-not $script:OldUserName) { return }

    if (-not (Get-LocalUser -Name $script:OldUserName -ErrorAction SilentlyContinue)) {
        Write-Warning "No se encontro la cuenta '$($script:OldUserName)'."
        Pausar
        return
    }

    Write-Host "Esto deshabilita el inicio de sesion de '$($script:OldUserName)' sin borrar nada." -ForegroundColor Yellow
    Write-Host "Es el paso recomendado antes de eliminar, como red de seguridad." -ForegroundColor Yellow
    $Confirma = if ($NonInteractive -or $Unattended) { "S" } else { Read-Host "`nDeshabilitar '$($script:OldUserName)'? (S/N)" }
    if ($Confirma -eq "S" -or $Confirma -eq "s") {
        try {
            Disable-LocalUser -Name $script:OldUserName -ErrorAction Stop
            Write-Host "Cuenta '$($script:OldUserName)' deshabilitada." -ForegroundColor Green
        } catch {
            Write-Warning "No se pudo deshabilitar la cuenta '$($script:OldUserName)': $($_.Exception.Message)"
        }
    }
    Pausar
}

function Eliminar-CuentaVieja {
    Write-Titulo "Eliminar cuenta anterior"
    Confirmar-NombresUsuario
    if (-not $script:OldUserName) { return }

    if (-not (Get-LocalUser -Name $script:OldUserName -ErrorAction SilentlyContinue)) {
        Write-Warning "No se encontro la cuenta '$($script:OldUserName)'."
        Pausar
        return
    }

    Write-Host "ADVERTENCIA: esta accion es IRREVERSIBLE." -ForegroundColor Red
    Write-Host "Se eliminara la cuenta '$($script:OldUserName)' y su carpeta de perfil $(Join-Path (Get-ProfilesBasePath) $script:OldUserName)." -ForegroundColor Red
    Write-Host "Verifique antes que '$($script:NewUserName)' funciona correctamente hace al menos varios dias." -ForegroundColor Yellow

    if ($NonInteractive -or $Unattended) {
        Write-Warning "La eliminacion definitiva de cuenta no esta permitida en modo no interactivo por salvaguarda de seguridad."
        Pausar
        return
    }

    $Confirma1 = Read-Host "`nEscriba ELIMINAR (en mayusculas) para continuar"
    if ($Confirma1 -ne "ELIMINAR") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        Pausar
        return
    }

    try {
        Remove-LocalUser -Name $script:OldUserName -ErrorAction Stop
        Write-Host "Cuenta '$($script:OldUserName)' eliminada." -ForegroundColor Green
    } catch {
        Write-Warning "Error al eliminar la cuenta '$($script:OldUserName)': $($_.Exception.Message)"
        Pausar
        return
    }

    $RutaPerfil = Join-Path (Get-ProfilesBasePath) $script:OldUserName
    if (Test-Path $RutaPerfil) {
        $BorrarPerfil = Read-Host "Eliminar tambien la carpeta de perfil $RutaPerfil ? (S/N)"
        if ($BorrarPerfil -eq "S" -or $BorrarPerfil -eq "s") {
            try {
                Remove-Item $RutaPerfil -Recurse -Force -ErrorAction Stop
                Write-Host "Carpeta de perfil eliminada." -ForegroundColor Green
            } catch {
                Write-Warning "No se pudo eliminar la carpeta de perfil '$RutaPerfil': $($_.Exception.Message)"
            }
        }
    }
    Pausar
}

function Mostrar-Menu {
    Write-Titulo "Migrar-Usuario-W11  |  Migracion segura de cuenta local"
    if ($script:OldUserName -or $script:NewUserName) {
        Write-Host "Cuenta actual : $($script:OldUserName)" -ForegroundColor DarkGray
        Write-Host "Cuenta nueva  : $($script:NewUserName)" -ForegroundColor DarkGray
        Write-Host ""
    }
    Write-Host "  1. Ver estado de cuentas locales"
    Write-Host "  2. Crear cuenta nueva y copiar membresias de grupo"
    Write-Host "  3. Migrar datos (Desktop, Documents, Downloads, Pictures, Videos, Music)"
    Write-Host "  4. Ver checklist de reconfiguracion manual"
    Write-Host "  5. Deshabilitar cuenta anterior"
    Write-Host "  6. Eliminar cuenta anterior (irreversible)"
    Write-Host "  0. Salir"
    Write-Host ""
}

if ($ListOnly -or [Console]::IsInputRedirected -or $isSimulated -or $NonInteractive -or $Unattended -or $Action) {
    if ($Action) {
        switch ($Action) {
            'List'      { $res = Mostrar-EstadoCuentas; if ($PassThru) { return $res }; exit 0 }
            'Create'    { Crear-CuentaNueva; exit 0 }
            'Migrate'   { Migrar-Datos; exit 0 }
            'Checklist' { Mostrar-Checklist; exit 0 }
            'Disable'   { Deshabilitar-CuentaVieja; exit 0 }
            'Delete'    { Eliminar-CuentaVieja; exit 0 }
        }
    }
    $res = Mostrar-EstadoCuentas
    if ($PassThru) { return $res }
    exit 0
}

do {
    Mostrar-Menu
    $Opcion = Read-Host "Seleccione una opcion"
    if ($null -eq $Opcion -or [string]::IsNullOrWhiteSpace($Opcion)) { break }
    switch ($Opcion) {
        "1" { Mostrar-EstadoCuentas }
        "2" { Crear-CuentaNueva }
        "3" { Migrar-Datos }
        "4" { Mostrar-Checklist }
        "5" { Deshabilitar-CuentaVieja }
        "6" { Eliminar-CuentaVieja }
        "0" { Write-Host "Saliendo..." -ForegroundColor Cyan }
        default { Write-Host "Opcion invalida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($Opcion -ne "0")
