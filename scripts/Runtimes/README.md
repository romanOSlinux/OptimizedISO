# Carpeta de Runtimes Esenciales para la ISO

Coloca en esta carpeta los instaladores oficiales de Microsoft para que el script `New-OptimizedWindowsISO.ps1` los inyecte automáticamente en `$OEM$\Setup\Scripts\Runtimes\` y se instalen en silencio durante la finalización de Windows Setup:

### 1. Visual C++ Redistributables (Recomendados):
* **VC++ 2015-2022 x64:** `vc_redist.x64.exe`  
  *Descarga oficial:* https://aka.ms/vs/17/release/vc_redist.x64.exe
* **VC++ 2015-2022 x86:** `vc_redist.x86.exe`  
  *Descarga oficial:* https://aka.ms/vs/17/release/vc_redist.x86.exe
* **VC++ 2013 x64 & x86:** `vcredist_x64.exe`, `vcredist_x86.exe`  
  *Descarga oficial:* https://download.microsoft.com/download/2/E/6/2E61C7AB-2E19-482F-B0F0-087940B04246/vcredist_x64.exe
* **VC++ 2012 x64 & x86:** `vcredist_x64.exe`, `vcredist_x86.exe`  
  *Descarga oficial:* https://download.microsoft.com/download/1/6/B/16B06F60-3CA2-4533-82F9-F016B074FAA4/vcredist_x64.exe

### 2. DirectX End-User Runtimes (Junio 2010):
* Extrae el paquete redistribuible `directx_Jun2010_redist.exe` en una subcarpeta llamada `DirectX/` de forma que contenga `dxsetup.exe` y los archivos `.cab`.
  *Descarga oficial:* https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe

---
*.NET Framework 3.5 se habilita automáticamente de forma offline en el archivo `install.wim` utilizando los archivos `sources\sxs` de la ISO original.*
