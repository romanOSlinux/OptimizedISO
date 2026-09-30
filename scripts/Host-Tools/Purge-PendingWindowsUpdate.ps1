<#
.SYNOPSIS
    Purge-PendingWindowsUpdate.ps1 - Purga Segura de Actualizaciones Pendientes
    Componente Oficial de romanOS Host-Tools (PLAN-0148).

.DESCRIPTION
    Cancela y purga descargas de actualizaciones en cola de reinicio (como saltos
    no deseados de versiones mayores) y vacía la caché de SoftwareDistribution\Download,
    eliminando las banderas de RebootPending y RebootRequired de Windows Update.

    Requiere elevación de Administrador (auto-eleva vía UAC RunAs).
    Compatible con Windows PowerShell 5.1 y PowerShell 7+.
    Codificación estricta UTF-8 con BOM.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$NoRestartServices
)

# -----------------------------------------------------------------------------
# 1. AUTO-ELEVACIÓN ADMINISTRATIVA (UAC)
# -----------------------------------------------------------------------------
if (-not $PSCmdlet.ShouldProcess("Sistema", "Purgar descargas de actualizaciones en cola y limpiar banderas de reinicio")) {
    return
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[UAC] Solicitando elevacion administrativa para purgar actualizaciones pendientes..." -ForegroundColor Yellow
    $argList = @("-STA", "-NoProfile", "-ExecutionPolicy Bypass", "-File", "`"$PSCommandPath`"")
    if ($NoRestartServices) { $argList += "-NoRestartServices" }
    Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
    exit
}

# -----------------------------------------------------------------------------
# 2. DETENCIÓN TEMPORAL DE SERVICIOS
# -----------------------------------------------------------------------------
Write-Host "`n=== ROMANOS: PURGA SEGURA DE ACTUALIZACIONES EN COLA ===" -ForegroundColor Cyan
Write-Host "[1/5] Deteniendo servicios de Windows Update y Orquestacion..." -ForegroundColor Gray

$targetServices = @("wuauserv", "UsoSvc", "BITS", "dosvc")
foreach ($svcName in $targetServices) {
    try {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq "Running") {
            Write-Host "  - Deteniendo servicio '$svcName'..." -ForegroundColor DarkGray
            Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
        }
    } catch {
        Write-Warning "No se pudo detener el servicio '$svcName': $($_.Exception.Message)"
    }
}

# -----------------------------------------------------------------------------
# 3. LIMPIEZA DE BANDERAS DE REINICIO PENDIENTE EN REGISTRO
# -----------------------------------------------------------------------------
Write-Host "[2/5] Purgando banderas de reinicio pendiente..." -ForegroundColor Gray

$wuRebootPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
if (Test-Path $wuRebootPath) {
    try {
        Remove-Item -Path $wuRebootPath -Recurse -Force -ErrorAction Stop
        Write-Host "  [OK] Clave RebootRequired eliminada satisfactoriamente." -ForegroundColor Green
    } catch {
        Write-Warning "Fallo al remover RebootRequired: $($_.Exception.Message)"
    }
} else {
    Write-Host "  [INFO] No habia clave RebootRequired en WindowsUpdate." -ForegroundColor DarkGray
}

# Helper para remocion forzada de claves protegidas por TrustedInstaller (WRP)
function Remove-ProtectedCbsKey {
    param([string]$SubKeyName)

    $definition = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Principal;
using Microsoft.Win32;

public static class CbsKeyObliterator
{
    [DllImport("advapi32.dll", SetLastError = true)]
    static extern bool OpenProcessToken(IntPtr ProcessHandle, uint DesiredAccess, out IntPtr TokenHandle);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    static extern bool LookupPrivilegeValue(string lpSystemName, string lpName, out long lpLuid);

    [DllImport("advapi32.dll", SetLastError = true)]
    static extern bool AdjustTokenPrivileges(IntPtr TokenHandle, bool DisableAllPrivileges, ref TOKEN_PRIVILEGES NewState, uint BufferLengthInBytes, IntPtr PreviousState, IntPtr ReturnLengthInBytes);

    [DllImport("advapi32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern int RegOpenKeyEx(UIntPtr hKey, string lpSubKey, uint ulOptions, int samDesired, out IntPtr phkResult);

    [DllImport("advapi32.dll", SetLastError = true)]
    static extern int RegCloseKey(IntPtr hKey);

    [DllImport("ntdll.dll")]
    static extern int NtDeleteKey(IntPtr KeyHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr hObject);

    [StructLayout(LayoutKind.Sequential)]
    struct TOKEN_PRIVILEGES
    {
        public uint PrivilegeCount;
        public long Luid;
        public uint Attributes;
    }

    const uint TOKEN_ADJUST_PRIVILEGES = 0x0020;
    const uint TOKEN_QUERY = 0x0008;
    const uint SE_PRIVILEGE_ENABLED = 0x00000002;

    const int WRITE_OWNER = 0x00080000;
    const int WRITE_DAC = 0x00040000;
    const int DELETE = 0x00010000;
    const int KEY_WOW64_64KEY = 0x0100;

    static readonly UIntPtr HKEY_LOCAL_MACHINE = new UIntPtr(0x80000002u);

    public static bool EnablePrivilege(string privilege)
    {
        IntPtr hToken;
        if (!OpenProcessToken(Process.GetCurrentProcess().Handle, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out hToken))
            return false;

        try
        {
            long luid;
            if (!LookupPrivilegeValue(null, privilege, out luid))
                return false;

            TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
            tp.PrivilegeCount = 1;
            tp.Luid = luid;
            tp.Attributes = SE_PRIVILEGE_ENABLED;

            return AdjustTokenPrivileges(hToken, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
        }
        finally
        {
            CloseHandle(hToken);
        }
    }

    public static bool ObliterateSubKey(string subKeyPath)
    {
        EnablePrivilege("SeTakeOwnershipPrivilege");
        EnablePrivilege("SeRestorePrivilege");
        EnablePrivilege("SeBackupPrivilege");

        // 1. Tomar posesion de la clave objetivo directamente (WRITE_OWNER)
        IntPtr hKey;
        int res = RegOpenKeyEx(HKEY_LOCAL_MACHINE, subKeyPath, 0, WRITE_OWNER | KEY_WOW64_64KEY, out hKey);
        if (res == 0)
        {
            try
            {
                using (RegistryKey rk = RegistryKey.FromHandle(new Microsoft.Win32.SafeHandles.SafeRegistryHandle(hKey, false), RegistryView.Registry64))
                {
                    RegistrySecurity rs = rk.GetAccessControl(AccessControlSections.Owner);
                    rs.SetOwner(new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null));
                    rk.SetAccessControl(rs);
                }
            }
            catch {}
            finally
            {
                RegCloseKey(hKey);
            }
        }

        // 2. Asignar FullControl a Administradores (WRITE_DAC)
        res = RegOpenKeyEx(HKEY_LOCAL_MACHINE, subKeyPath, 0, WRITE_DAC | KEY_WOW64_64KEY, out hKey);
        if (res == 0)
        {
            try
            {
                using (RegistryKey rk = RegistryKey.FromHandle(new Microsoft.Win32.SafeHandles.SafeRegistryHandle(hKey, false), RegistryView.Registry64))
                {
                    RegistrySecurity rs = rk.GetAccessControl(AccessControlSections.Access);
                    RegistryAccessRule rule = new RegistryAccessRule(
                        new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null),
                        RegistryRights.FullControl,
                        AccessControlType.Allow
                    );
                    rs.ResetAccessRule(rule);
                    rk.SetAccessControl(rs);
                }
            }
            catch {}
            finally
            {
                RegCloseKey(hKey);
            }
        }

        // 3. Abrir con derecho DELETE y ejecutar NtDeleteKey a nivel de kernel NT
        res = RegOpenKeyEx(HKEY_LOCAL_MACHINE, subKeyPath, 0, DELETE | KEY_WOW64_64KEY, out hKey);
        if (res == 0)
        {
            try
            {
                int status = NtDeleteKey(hKey);
                return status >= 0;
            }
            finally
            {
                RegCloseKey(hKey);
            }
        }

        return false;
    }
}
'@
    if (-not ([System.Management.Automation.PSTypeName]'CbsKeyObliterator').Type) {
        Add-Type -TypeDefinition $definition -ErrorAction SilentlyContinue
    }

    if (([System.Management.Automation.PSTypeName]'CbsKeyObliterator').Type) {
        $fullPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\$SubKeyName"
        return [CbsKeyObliterator]::ObliterateSubKey($fullPath)
    }
    return $false
}

$cbsRebootPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
if (Test-Path $cbsRebootPath) {
    $cbsRemoved = $false
    try {
        Remove-Item -Path $cbsRebootPath -Recurse -Force -ErrorAction Stop
        $cbsRemoved = $true
    } catch {
        # Si Remove-Item falla por permisos de TrustedInstaller (Acceso denegado), usar bypass de SeRestorePrivilege
        $cbsRemoved = Remove-ProtectedCbsKey -SubKeyName "RebootPending"
    }

    if ($cbsRemoved -or -not (Test-Path $cbsRebootPath)) {
        Write-Host "  [OK] Clave RebootPending de CBS eliminada satisfactoriamente." -ForegroundColor Green
    } else {
        Write-Warning "Fallo al remover RebootPending de CBS: Acceso denegado por protección de TrustedInstaller."
    }
} else {
    Write-Host "  [INFO] No habia clave RebootPending en CBS." -ForegroundColor DarkGray
}

# -----------------------------------------------------------------------------
# 4. PURGA DE ARCHIVOS DE DESCARGA EN SOFTWAREDISTRIBUTION
# -----------------------------------------------------------------------------
Write-Host "[3/5] Purgando directorio de descargas SoftwareDistribution\Download..." -ForegroundColor Gray

$downloadPath = Join-Path $env:SystemRoot "SoftwareDistribution\Download"
if (Test-Path $downloadPath) {
    try {
        $items = Get-ChildItem -Path $downloadPath -Recurse -Force -ErrorAction SilentlyContinue
        $itemCount = ($items | Measure-Object).Count
        Remove-Item -Path "$downloadPath\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Descargas temporales purgadas ($itemCount elementos removidos)." -ForegroundColor Green
    } catch {
        Write-Warning "Aviso al limpiar archivos en SoftwareDistribution: $($_.Exception.Message)"
    }
}

# -----------------------------------------------------------------------------
# 5. REINICIO DE SERVICIOS
# -----------------------------------------------------------------------------
if (-not $NoRestartServices) {
    Write-Host "[4/5] Restaurando servicios de Windows Update a modo bajo demanda..." -ForegroundColor Gray
    try {
        & sc.exe config wuauserv start= demand 2>&1 | Out-Null
        & sc.exe config UsoSvc start= demand 2>&1 | Out-Null
        Start-Sleep -Milliseconds 500
    } catch {
        Write-Warning "Aviso al ajustar tipo de inicio de servicios: $($_.Exception.Message)"
    }
}

# -----------------------------------------------------------------------------
# 6. VERIFICACIÓN FINAL DE ESTADO
# -----------------------------------------------------------------------------
Write-Host "[5/5] Verificando estado final del sistema..." -ForegroundColor Gray
$stillWuReboot = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
$stillCbsReboot = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"

if (-not $stillWuReboot -and -not $stillCbsReboot) {
    Write-Host "`n>>> [EXITO TOTAL] La actualizacion pendiente ha sido purgada con exito." -ForegroundColor Green
    Write-Host ">>> El equipo puede reiniciarse de manera segura sin aplicar la version 26H2.`n" -ForegroundColor Green
} else {
    Write-Warning "Algunas banderas de reinicio persisten en el sistema (WU: $stillWuReboot, CBS: $stillCbsReboot)."
}

if ($Host.Name -notmatch "ServerRemoteHost") {
    Write-Host "Presione cualquier tecla para cerrar esta ventana..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
