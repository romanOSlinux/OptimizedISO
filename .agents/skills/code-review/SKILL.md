---
name: code-review
description: "Checklist de revisión de código antes de entregar: errores lógicos, código muerto, seguridad, y legibilidad. Aplica a cualquier lenguaje."
---

# Revisión de Código

Checklist reutilizable para revisar calidad de código antes de commit o entrega.

## Checklist de revisión

### 1. Correctitud
- [ ] ¿La lógica hace lo que se espera? Trazar mentalmente el flujo.
- [ ] ¿Se manejan los edge cases? (null, vacío, paths con espacios)
- [ ] ¿Los tipos son correctos?

### 2. Código muerto y residuos
- [ ] ¿Hay variables declaradas pero no usadas?
- [ ] ¿Hay código comentado innecesario?

### 3. Seguridad básica
- [ ] ¿Hay contraseñas o tokens hardcodeados?
- [ ] ¿Los paths externos están debidamente entrecomillados?

### 4. Reglas del agente
- **No refactorizar** código que funciona sin confirmación explícita del usuario.
- Presentar hallazgos como tabla antes de actuar.
