# Matriz de Compatibilidad: Hardening de Windows vs. Motores Anti-Cheat

Esta guía documenta la interacción entre directivas de seguridad de Windows y los principales motores anti-cheat del mercado (EasyAntiCheat, BattlEye, Riot Vanguard, FACEIT, Ricochet).

---

## 1. Directivas 100% Seguras (Cero Impacto en Juegos)

| Directiva | Clave de Registro | Beneficio de Seguridad | Impacto en Juegos |
| :--- | :--- | :--- | :--- |
| **LSA Protection** | `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\RunAsPPL = 1` | Bloquea volcados de contraseñas tipo Mimikatz en LSASS. | **Ninguno**. 100% compatible. |
| **Desactivar SMBv1** | `HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters\SMB1 = 0` | Mitiga exploits tipo EternalBlue / WannaCry. | **Ninguno**. |
| **Desactivar LLMNR** | `HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient\EnableMulticast = 0` | Mitiga ataques de envenenamiento de red (Responder). | **Ninguno**. |
| **Desactivar NetBIOS** | `NetbiosOptions = 2` en adaptadores WMI. | Reduce tráfico de broadcast innecesario. | **Ninguno**. Mejora latencia. |
| **Protección UAC** | `EnableLUA = 1`, `ConsentPromptBehaviorAdmin = 5` | Impide auto-elevaciones de malware. | **Ninguno**. |

---

## 2. Directivas Riesgosas que NUNCA deben Forzarse en Perfiles Gaming

| Directiva / Función | Riesgo para Juegos | Recomendación romanOS |
| :--- | :--- | :--- |
| **Forzar HVCI (Memory Integrity) Estricto** | Puede penalizar 5-15% FPS en CPUs antiguas o bloquear drivers antiguos de periféricos. | **Opcional / Por defecto bajo**. |
| **Bloqueo ASR: "Block executable files from running unless they meet criteria"** | Causa falsos positivos bloqueando lanzadores de juegos independientes o mods. | **No habilitar en modo Gaming**. |
| **Deshabilitar Controladores PnP / BFE** | Rompe la inicialización de drivers de kernel de Vanguard y EasyAntiCheat. | **Mantener siempre intactos**. |
