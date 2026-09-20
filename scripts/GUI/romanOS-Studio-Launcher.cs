// =====================================================================
// romanOS Studio - Lanzador Win32 GUI Nativo (Subsystem 2 / winexe)
// Estándar oficial de Microsoft: sin parpadeo de consola (Zero-Flash)
// Compilado con csc.exe (/target:winexe) - Sin dependencias externas
// =====================================================================

using System;
using System.Diagnostics;
using System.IO;

namespace RomanOS.Launcher
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string scriptPath = Path.Combine(baseDir, @"scripts\GUI\romanOS-Studio.ps1");
            string psPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");

            if (!File.Exists(scriptPath))
            {
                // Fallback de resolución si se ejecuta desde subcarpetas
                string altPath = Path.Combine(baseDir, @"..\..\scripts\GUI\romanOS-Studio.ps1");
                if (File.Exists(altPath))
                {
                    scriptPath = Path.GetFullPath(altPath);
                    baseDir = Path.GetDirectoryName(Path.GetDirectoryName(scriptPath));
                }
                else
                {
                    return;
                }
            }

            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = psPath,
                Arguments = string.Format("-WindowStyle Hidden -STA -NoProfile -ExecutionPolicy Bypass -File \"{0}\"", scriptPath),
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
                // Silencioso ante cancelaciones
            }
        }
    }
}
