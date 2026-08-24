---
name: iso-security-hardening
description: >-
  Activate this skill when reviewing or implementing Windows security policies,
  Defender Attack Surface Reduction (ASR) rules, LSA protection (RunAsPPL),
  or auditing gaming-safe hardening without breaking anti-cheat systems.
---

# Hardening de Seguridad Gaming-Safe para Windows

Protocolo para aplicar directivas de seguridad de alto impacto sin penalizar el rendimiento ni la compatibilidad con juegos.

## Reglas de Seguridad romanOS

1. **Anti-Cheat Safe:** Nunca bloquear llamadas a kernel ni deshabilitar servicios PnP requeridos por EasyAntiCheat, BattlEye o Riot Vanguard.
2. **Hardening de Red de Bajo Impacto:** Deshabilitar siempre protocolos legados vulnerables (`SMBv1`, `LLMNR`, `NetBIOS`).
3. **Protección LSA:** Habilitar `RunAsPPL = 1` para blindar el proceso LSASS.

---

## Verificación Rápida de Políticas de Seguridad

Para auditar el estado de directivas de seguridad locales:
```powershell
& ".agents/skills/iso-security-hardening/scripts/Test-HardeningSafety.ps1"
```

---

## Documentación y Referencias Técnicas

- [Matriz de Compatibilidad con Anti-Cheats](./references/anticheat-compatibility-matrix.md)
