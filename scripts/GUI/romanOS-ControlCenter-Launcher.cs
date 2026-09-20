// =====================================================================
// romanOS Control Center - Lanzador Win32 GUI Nativo (Subsystem 2 / winexe)
// Estandar oficial de Microsoft: sin parpadeo de consola (Zero-Flash)
// Compilado con csc.exe (/target:winexe) - Sin dependencias externas
// =====================================================================

using System;
using System.Diagnostics;
using System.IO;

namespace RomanOS.ControlCenter.Launcher
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string scriptPath = Path.Combine(baseDir, @"scripts\GUI\romanOS-ControlCenter.ps1");
            string psPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");

            if (!File.Exists(scriptPath))
            {
                // Fallback de resolucion si se ejecuta desde subcarpetas o directorio Scripts
                string altPath = Path.Combine(baseDir, @"romanOS-ControlCenter.ps1");
                if (File.Exists(altPath))
                {
                    scriptPath = Path.GetFullPath(altPath);
                }
                else
                {
                    string altPath2 = Path.Combine(baseDir, @"..\..\scripts\GUI\romanOS-ControlCenter.ps1");
                    if (File.Exists(altPath2))
                    {
                        scriptPath = Path.GetFullPath(altPath2);
                    }
                    else
                    {
                        return;
                    }
                }
            }

            string extraArgs = args != null && args.Length > 0 ? " " + string.Join(" ", args) : "";

            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = psPath,
                Arguments = string.Format("-WindowStyle Hidden -STA -NoProfile -ExecutionPolicy Bypass -File \"{0}\"{1}", scriptPath, extraArgs),
                UseShellExecute = false,
                CreateNoWindow = true,
                WorkingDirectory = baseDir
            };

            try
            {
                Process.Start(psi);
            }
            catch
            {
                // Silencioso ante cancelaciones de elevacion UAC
            }
        }
    }
}
