# PLAN-0037: Implementación de Continuous Integration (CI) Local

Este plan responde a tu solicitud de aplicar la misma prevención de errores a **todos los controles de calidad del proyecto**, de manera profesional y automatizada.

Para ello, integraremos el orquestador maestro de pruebas del proyecto (`Invoke-TestSuite.ps1`) directamente en el ciclo de vida de Git mediante un **Pre-Commit Hook**.

## Arquitectura del Hook (El Guardia de Seguridad)
Cuando cualquier desarrollador (tú o yo) escriba un comando para guardar código (`git commit`), Git no guardará los cambios inmediatamente. En su lugar, invocará silenciosamente a nuestro orquestador de pruebas.

Si el orquestador detecta una sola falla, abortará el `commit` automáticamente.

## Alcance de las Pruebas (Modo "Quick")
Para no entorpecer tu flujo de trabajo haciéndote esperar minutos por cada commit, el Hook llamará a `Invoke-TestSuite.ps1` con la bandera `-Quick`. Esta ejecución hiper-rápida (menos de 5 segundos) auditará:
1. **Sintaxis AST y Codificación BOM (Evita el bug que acabamos de tener)**.
2. **Esquema de autounattend.xml**.
3. **Higiene Git (Regla 6): Cero binarios en el repositorio**.
4. **Validación del entorno y variables del Creador de ISO**.

## Implementación Técnica

### [NEW] `C:\OptimizedISO\.git\hooks\pre-commit`
Crearemos un script de Bash (el motor que usa Git internamente para Hooks en Windows) con el siguiente código:

```bash
#!/bin/bash
# romanOS - CI/CD Local Pre-Commit Hook

echo -e "\n⏳ [romanOS CI] Ejecutando Bateria de Pruebas Rapidas (AST, BOM, XML, Higiene)..."

# Invocar el Test Suite de PowerShell en modo -Quick
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "scripts/Testing/Invoke-TestSuite.ps1" -Quick

# Capturar el exit code de PowerShell
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo -e "\n❌ [ERROR] Las pruebas de CI fallaron."
    echo -e "   -> Revisa los logs arriba, corrige los errores y vuelve a intentar el commit.\n"
    exit 1
fi

echo -e "✅ [OK] Todas las pruebas pasaron. Registrando commit...\n"
exit 0
```

> [!TIP]  
> **Aprobación Requerida:**  
> Por favor, revisa este plan. Si estás de acuerdo con que activemos este "Guardia de Seguridad" automatizado para todo el proyecto, dime **"procede"** y yo me encargaré de instalarlo.
