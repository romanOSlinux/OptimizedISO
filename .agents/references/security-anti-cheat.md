# Referencia Canónica: Seguridad de Kernel y Compatibilidad Anti-Cheat (romanOS)

Este documento define las directivas de seguridad obligatorias para garantizar la compatibilidad con los 5 motores Anti-Cheat Ring-0 del mercado (Vanguard, Easy Anti-Cheat, BattlEye, Ricochet, FACEIT).

## 1. Mitigaciones de Kernel Obligatorias
- **Microsoft Recommended Driver Blocklist:**
  - Clave: `HKLM\SYSTEM\CurrentControlSet\Control\CI\Config`
  - Valor: `VulnerableDriverBlocklistEnable = 1 (DWord)`
  - Justificación: Bloquea vectores BYOVD (*Bring Your Own Vulnerable Driver*). Requisito innegociable de Riot Vanguard y EAC.
- **LSA Protection (RunAsPPL):**
  - Clave: `HKLM\SYSTEM\CurrentControlSet\Control\Lsa`
  - Valor: `RunAsPPL = 1 (DWord)`, `RunAsPPLBoot = 2 (DWord)`
  - Justificación: Protege el proceso `lsass.exe` de inyecciones de memoria por malware o loaders.

## 2. Servicios del Sistema Inviolables
- **Servicio BAM (Background Activity Moderator):**
  - Clave: `HKLM\SYSTEM\CurrentControlSet\Services\bam`
  - Estado: `Start = 2` o `3` (Nunca `4` / Deshabilitado).
  - Justificación: Los motores anti-cheat lo utilizan para monitoreo de integridad de procesos.
- **Servicios Criptográficos y de Confianza (CryptSvc, WinVerifyTrust):**
  - Prohibido purgar o deshabilitar. Rompe la validación de certificados de drivers WHQL.
