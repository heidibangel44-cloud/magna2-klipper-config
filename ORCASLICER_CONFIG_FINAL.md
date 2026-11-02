# Configuración final de OrcaSlicer — Hellbot Magna 2230 Dual

Guía práctica, solo lo necesario para configurar OrcaSlicer 2.4.2 en la Dell. No
repite el historial del proyecto — para eso ver `AUDITORIA_MAGNA2230_...md`.

## Perfil de impresora

| Campo | Valor |
|---|---|
| Tipo de firmware / G-code flavor | **Klipper** (no "Marlin") |
| Cantidad de extrusores a declarar | **1** (ver nota de arquitectura abajo - no declarar 2) |
| Cama | 230 × 230 mm |
| Altura máxima (Z) | 250 mm |
| Diámetro de boquilla | 0.4 mm |
| Diámetro de filamento | 1.75 mm |
| Retracción por firmware | **Activar** (usa G10/G11 de Klipper) |
| Conexión Moonraker (misma red) | `http://192.168.18.196:7125` o `http://facundo-cx215xx-cx212xx.local:7125` |
| Conexión Moonraker (por Internet, con Tailscale en la Dell) | `http://facundo-cx215xx-cx212xx.tailf92613.ts.net:7125` |

### Nota de arquitectura - leer antes de tocar nada más

Esta impresora tiene **dos motores de extrusión (T0/T1) que comparten UN SOLO
hotend y UNA SOLA boquilla** - no es IDEX, no es multi-extrusor de verdad. Declarar
Orca con **1 solo extrusor**. El cambio de color se maneja con la función de
"cambio de color manual" de Orca (pausa + G-code personalizado en la altura
deseada), insertando como G-code personalizado la palabra `T0` o `T1` sola. No usar
la función nativa de multi-extrusor/torre de purga de Orca - asume offsets de
segunda boquilla física que esta impresora no tiene.

## G-code

**Start G-code** (reemplaza TODO el de inicio por defecto):
```
PRINT_START EXTRUDER_TEMP=[nozzle_temperature_initial_layer] BED_TEMP=[bed_temperature_initial_layer]
```

**End G-code** (reemplaza todo el de fin):
```
PRINT_END
```

**G-code de cambio de color** (insertar manualmente en la altura deseada, vía
"cambio de color" de Orca): la palabra `T0` o `T1` sola, en su propia línea.

**No usar:** M104/M140/G28 sueltos al inicio, M84 suelto al final, retracción o
torre de purga extra configurada específicamente "para el cambio de herramienta"
(el macro T0/T1 ya hace su propio retract/reprime de 80mm - una retracción
adicional de Orca ahí se sumaría a esa, no la reemplaza).

## Perfil de filamento (PLA)

| Parámetro | Valor | Tipo |
|---|---|---|
| Temperatura hotend | 210°C | **Confirmado**, probado hoy con filamento real |
| Temperatura cama | 60°C | **Confirmado**, usado en pruebas de hoy |
| Retracción - distancia | 3mm | **Confirmado** (viene de Klipper, con firmware retraction activada el valor de Klipper es el que manda - poner este número en Orca solo para que la vista previa no mienta) |
| Retracción - velocidad | 40mm/s | **Confirmado**, idem |
| Flow ratio inicial | 1.0 (100%) | Valor inicial recomendado - **necesita calibración física** |
| Pressure Advance | 0.0 actual | **Necesita calibración física** (torre real) - esperable que termine más alto que en una impresora de un solo extrusor, por el volumen del splitter compartido |
| Caudal volumétrico máximo inicial prudente | 6-8 mm³/s | Valor inicial prudente - **necesita calibración física** (prueba de flow rate) para confirmar el límite real de este hotend |

## Velocidades y aceleraciones

| Parámetro | Valor recomendado | Máximo prudente |
|---|---|---|
| Primera capa | 20 mm/s | 25 mm/s |
| Pared exterior | 40 mm/s | 60 mm/s |
| Pared interior | 50 mm/s | 70 mm/s |
| Relleno | 60 mm/s | 80 mm/s |
| Superficie superior | 40 mm/s | 50 mm/s |
| Soportes | 60 mm/s | 80 mm/s |
| Puentes | 25 mm/s | 30 mm/s |
| Desplazamientos (travel) | 150 mm/s | 200 mm/s |
| Aceleración general | 500 mm/s² | 500 mm/s² (techo real de Klipper - no superar) |
| Aceleración pared exterior | 300 mm/s² | 500 mm/s² |

Estas velocidades de impresión son **recomendaciones de configuración**, ya
contrastadas contra los límites reales de Klipper y contra el caudal volumétrico que
necesitan (el motor nunca gira a más de ~0.35 rev/s en este rango - no es el cuello
de botella). Están separadas del techo de seguridad de Klipper (500mm/s, 500mm/s²),
que es un límite de firmware, no una velocidad de impresión real.

## Ventiladores

Ventilador de piezas al 100% desde la segunda capa - confirmado funcionando hoy en
las 3 velocidades probadas.

## Funciones que NO hay que habilitar

- **Nivelación automática de cama (bed mesh)** - no hay sonda funcional instalada.
- **Input Shaper / compensación de vibración** - no hay acelerómetro instalado.
- **Multi-extrusor nativo / IDEX** de Orca - ver nota de arquitectura arriba.

## Limitaciones conocidas

- El cambio de color es manual (pausa + G-code), no automático con torre de purga -
  por la arquitectura de un solo hotend compartido.
- Historial de desconexiones USB sin causa 100% confirmada - primera impresión real
  recomendada: corta (cubo de 20mm, 15-20 min), no una pieza larga.
- El comportamiento exacto de Orca 2.4.2 generando G-code alrededor del cambio de
  herramienta manual (si envuelve el bloque con retracción propia) no se puede
  confirmar desde esta netbook - verificar mirando la vista previa de G-code en Orca
  antes de la primera impresión con cambio de color.

## Acceso remoto (ya configurado y funcionando)

Ver el mensaje de chat para los datos completos de acceso por Tailscale a Mainsail,
Moonraker y la cámara - no se repiten acá para no duplicar información.
