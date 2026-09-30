// =====================================================================
// romanOS Control Center - Lanzador Win32 GUI Nativo (Subsystem 2 / winexe)
// Estandar oficial de Microsoft: sin parpadeo de consola (Zero-Flash)
// Compilado con csc.exe (/target:winexe) - Sin dependencias externas
// =====================================================================

using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;

namespace RomanOS.ControlCenter.Launcher
{
    static class Program
    {
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern int MessageBoxW(IntPtr hWnd, string lpText, string lpCaption, uint uType);

        const uint MB_OK = 0x00000000;
        const uint MB_ICONERROR = 0x00000010;

        [STAThread]
        static void Main(string[] args)
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string winDir = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
            string psPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");

            string[] candidates = new string[]
            {
                Path.Combine(baseDir, @"scripts\GUI\romanOS-ControlCenter.ps1"),
                Path.Combine(baseDir, @"GUI\romanOS-ControlCenter.ps1"),
                Path.Combine(baseDir, @"romanOS-ControlCenter.ps1"),
                Path.Combine(winDir, @"Setup\Scripts\GUI\romanOS-ControlCenter.ps1"),
                Path.Combine(winDir, @"Setup\Scripts\romanOS-ControlCenter.ps1"),
                @"C:\Windows\Setup\Scripts\GUI\romanOS-ControlCenter.ps1",
                @"C:\Windows\Setup\Scripts\romanOS-ControlCenter.ps1",
                Path.Combine(baseDir, @"..\..\scripts\GUI\romanOS-ControlCenter.ps1")
            };

            string scriptPath = null;
            foreach (string cand in candidates)
            {
                if (File.Exists(cand))
                {
                    scriptPath = Path.GetFullPath(cand);
                    break;
                }
            }

            if (scriptPath == null)
            {
                string searched = string.Join("\n - ", candidates);
                MessageBoxW(IntPtr.Zero,
                    "No se pudo encontrar el script 'romanOS-ControlCenter.ps1'.\n\nRutas buscadas:\n - " + searched,
                    "romanOS Control Center - Error de Inicio",
                    MB_OK | MB_ICONERROR);
                return;
            }

            string workDir = Path.GetDirectoryName(scriptPath);
            string parentDir = Path.GetDirectoryName(workDir);
            if (File.Exists(Path.Combine(workDir, @"..\Core\Policy-Engine.ps1")))
            {
                workDir = Path.GetFullPath(Path.Combine(workDir, @".."));
            }
            else if (parentDir != null && File.Exists(Path.Combine(parentDir, @"Core\Policy-Engine.ps1")))
            {
                workDir = parentDir;
            }

            string extraArgs = args != null && args.Length > 0 ? " " + string.Join(" ", args) : "";

            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = psPath,
                Arguments = string.Format("-WindowStyle Hidden -STA -NoProfile -ExecutionPolicy Bypass -File \"{0}\"{1}", scriptPath, extraArgs),
                UseShellExecute = false,
                CreateNoWindow = true,
                WorkingDirectory = workDir
            };

            try
            {
                Process.Start(psi);
            }
            catch (Win32Exception w32ex)
            {
                // Codigo 1223 = ERROR_CANCELLED (El usuario cerro o cancelo el dialogo de elevacion UAC)
                if (w32ex.NativeErrorCode != 1223)
                {
                    MessageBoxW(IntPtr.Zero,
                        "Error al iniciar PowerShell:\n\n" + w32ex.Message,
                        "romanOS Control Center - Error de Ejecución",
                        MB_OK | MB_ICONERROR);
                }
            }
            catch (Exception ex)
            {
                MessageBoxW(IntPtr.Zero,
                    "Error inesperado al iniciar romanOS Control Center:\n\n" + ex.Message,
                    "romanOS Control Center - Error",
                    MB_OK | MB_ICONERROR);
            }
        }
    }
}
