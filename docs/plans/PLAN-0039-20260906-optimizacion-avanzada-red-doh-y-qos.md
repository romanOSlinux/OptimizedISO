# PLAN-0039: Optimización Avanzada de Red (DoH Nativo, QoS 802.1p, Offloads y AutoTuning Parametrizado)

Implementación de 4 recomendaciones oficiales basadas en la documentación de tuning TCP/IP de Microsoft para redes de baja latencia.

## User Review Required

> [!IMPORTANT]
> **Modificación de Menú Interactivo**:
> El script `Win11-Network-Diagnostics-Optimizer.ps1` ahora solicitará al usuario si desea aplicar un **Servidor DoH (DNS over HTTPS)** global y preguntará el ancho de banda para ajustar dinámicamente el `AutoTuningLevel`. ¿Estás de acuerdo con añadir estos dos *prompts* interactivos antes de inyectar las optimizaciones?

## Open Questions

> [!WARNING]
> Para el DNS DoH, propongo ofrecer **Cloudflare (1.1.1.1)** como predeterminado por ser el más rápido según pruebas de ping globales (Latencia < 15ms), y **Quad9 (9.9.9.9)** como alternativa de alta privacidad. ¿Deseas incluir algún otro (como Google 8.8.8.8 o AdGuard)?

## Proposed Changes

### 1. Extensión del SSOT (`Policy-Engine.ps1`)

Se agregarán las nuevas directivas oficiales al catálogo global `$global:RomanOS_NetworkPolicies`:

#### [MODIFY] [Policy-Engine.ps1](file:///C:/OptimizedISO/scripts/Core/Policy-Engine.ps1)
- **DoH (DNS over HTTPS)**: Agregaremos políticas dinámicas para configurar DoH nativamente usando `Set-DnsClientServerAddress`.
- **QoS 802.1p**: Nueva política para habilitar el etiquetado DSCP por hardware (`*PriorityVLANTag = 3`).
- **Offloads Obsoletos**: Nuevas políticas para deshabilitar explícitamente `TCP Chimney Offload` e `IPsec Task Offload` (tecnologías *deprecated* por Microsoft que causan fugas en drivers OEM).

### 2. Refactorización de la lógica del Módulo de Red (`Win11-Network-Diagnostics-Optimizer.ps1`)

Modificaremos el bucle de ejecución de optimizaciones para aceptar parámetros y nuevas opciones interactivas.

#### [MODIFY] [Win11-Network-Diagnostics-Optimizer.ps1](file:///C:/OptimizedISO/scripts/Modules/Win11-Network-Diagnostics-Optimizer.ps1)
- Añadir prompt: *"Selecciona el proveedor de DNS cifrado (DoH): 1. Cloudflare 2. Quad9 3. Omitir"*.
- Añadir prompt: *"¿Tu conexión de red supera 1 Gbps (Fibra)? [S/N]"*. 
  - Si `Sí`: Modificará al vuelo la política `NET_TCP_AUTOTUNING` de `Normal` a `Experimental`.
  - Si `No`: Mantendrá la recomendación base `Normal`.
- Agregar un nuevo tipo de manejador `ActionType = 'NetAdapter_DNS'` para inyectar DNS mediante el módulo `DnsClient` de Windows.

## Verification Plan

### Automated Tests
- Modificaremos (si es necesario) `Test-OptimizedISO-v2.ps1` para validar que el `Policy-Engine` contenga la política `PriorityVLANTag` (QoS).

### Manual Verification
- Ejecutaremos en frío `Win11-Network-Diagnostics-Optimizer.ps1` usando `powershell -STA -NoProfile` y simularemos una elección interactiva para Cloudflare DoH y un ancho de banda > 1 Gbps.
- Comprobaremos si los adaptadores físicos reflejan el cambio usando `Get-DnsClientServerAddress`.
