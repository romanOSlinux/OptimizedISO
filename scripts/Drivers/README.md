# 🚗 Inyección Offline de Controladores (Drivers)

Esta carpeta está destinada a la integración automática y desatendida de controladores (`.inf`) en la imagen de Windows (`install.wim`) durante la creación de la ISO mediante `New-OptimizedWindowsISO.ps1`.

---

## 📂 ¿Qué colocar en esta carpeta?

Coloque aquí las carpetas descomprimidas con los controladores de su hardware. DISM buscará recursivamente (`/Recurse`) todos los archivos `.inf` compatibles.

### 💡 Casos de uso típicos recomendados:
1. **Controladores de Almacenamiento NVMe / RAID / Intel RST (VMD):**
   * Esenciales si su instalador no detecta el disco de estado sólido durante la instalación en equipos portátiles modernos (Intel 11va, 12va, 13va y 14va generación).
2. **Controladores de Red (Ethernet / Wi-Fi):**
   * Controladores de tarjetas Intel, Realtek, MediaTek o Qualcomm para contar con conectividad de red inmediata tras la instalación.
3. **Controladores de Touchpad / Teclado (I2C / HID):**
   * Especialmente útiles para laptops donde el teclado o touchpad no responden en la primera configuración.

---

## ⚠️ Requisitos y Reglas de Formato

* **Formato admitido:** Los controladores deben estar **desempaquetados** con sus archivos `.inf`, `.sys`, `.cat` y carpetas correspondientes.
  * ❌ *No coloque instaladores `.exe` o `.msi` aquí (estos pertenecen a `$OEM$` o `Runtimes/`).*
  * ✔️ *Coloque las carpetas extraídas que contienen los archivos `.inf`.*
* **Firma de controladores:** El script ejecuta DISM con el flag `/ForceUnsigned`, permitiendo integrar controladores OEM personalizados.

---

## 🚀 Uso en la línea de comandos

Si prefiere almacenar los controladores en otra ruta o unidad de disco, puede indicarla directamente al ejecutar el script:

```powershell
.\New-OptimizedWindowsISO.ps1 -SourceISO "C:\ISOs\Win11.iso" -DriversPath "D:\MisControladores"
```
