# Matriz maestra de objetivos — Hellbot Magna 2 230 Dual / Klipper

Construida el 2026-10-26 a partir de todo el historial del proyecto (`BITACORA.md`,
`SETUP_MAGNA_2230_KLIPPER.md`, commits de ambos repos). Sintetiza, no reemplaza, los
documentos de detalle - para el "por qué" y las fuentes completas, ir a esos archivos.

**Leyenda de estado:**
- 🔵 Investigado (hay información, nada implementado todavía)
- 🟡 Implementado (código/config escrito, no probado)
- 🟢 Validado por software (ejecutado, respuesta coherente, sin movimiento/calor crítico)
- ✅ Probado físicamente (confirmado con el hardware real haciendo lo que tiene que hacer)
- ⬜ Pendiente de hardware (no se puede avanzar sin comprar/conseguir algo)
- 👤 Pendiente de intervención humana (física, no por falta de autorización)

## 1. Firmware y MCU

| Objetivo | Estado | Evidencia | Dependencias | Defecto encontrado | Criterio de aceptación |
|---|---|---|---|---|---|
| Identificar revisión real de placa/MCU | ✅ | `mcu_constants.MCU: stm32f407xx`, `CLOCK_FREQ: 168000000` reportado por el propio firmware al conectar | — | Vendida como "V1.2", chip real F407 (efectivamente V1.3) | Cumplido |
| Firmware compatible y correctamente compilado | ✅ | Klippy conecta, `state: ready`, comunicación limpia tras reflasheo del 2026-10-25 | — | Bug de `update_mks_robin.py` (XOR) encontrado y evitado | Cumplido |
| Workflow de GitHub del repo original corregido | ✅ | Commit `3f9c9c9` en `magna-klipper`, pusheado | — | — | Cumplido |

## 2. Estabilidad USB (prioridad crítica, SIN RESOLVER)

| Objetivo | Estado | Evidencia | Dependencias | Defecto encontrado | Criterio de aceptación |
|---|---|---|---|---|---|
| Diagnosticar causa de desconexiones | 🔵 | 21 eventos reales confirmados (filtro corregido por chip, no genérico) el 2026-10-25; patrón `urb stopped -32` + disconnect duro, no suspensión | — | Cable, puerto, autosuspend y jumper: **descartados/debilitados con evidencia**, no por suposición | **NO cumplido** - causa real sin confirmar |
| Monitoreo continuo de estabilidad | 🟢 | `tools/usb_monitor_pasivo.sh` corrió 1h40m (393 lecturas) sin eventos nuevos el 25/10; reiniciado tras reboot el 26/10 con filtro corregido | Netbook encendida y Klipper corriendo | Primera versión del script contaba falsos positivos (WiFi/BT interno) - corregido | Parcial - sigue corriendo, sin racha "definitiva" declarada |
| Probar hub USB alimentado | ⬜ | Identificado como el experimento más discriminante (~10-15 USD) | Comprar el hub | — | Pendiente de hardware |
| Regla udev autosuspend | 🟡 | Archivo listo en `tools/`, **NO instalado**, y evidencia sugiere que no es la causa real | `sudo` del usuario | — | Instalable, expectativa de impacto baja |

## 3. Mecánica, homing y nivelación

| Objetivo | Estado | Evidencia | Dependencias | Defecto encontrado | Criterio de aceptación |
|---|---|---|---|---|---|
| Pull-up faltante en switch de Z | ✅ | Test diferencial confirmado (switch solo, open/TRIGGERED correctos en ambos estados) | — | `endstop_pin` sin `^` - corregido | Cumplido |
| Homing X/Y/Z funcional | ✅ | G28 completo + 5 ciclos repetidos, direcciones/endstops coherentes, sin shutdown (2026-10-25, post-reflasheo) | — | — | Cumplido para lo que se puede validar sin papel |
| Precisión de movimiento X/Y/Z (regla real) | ✅ | **2026-10-26:** X 50mm pedidos→50mm medidos; Y 50→50mm; Z 20→20mm. Los 3 ejes, 0% de error, medidos con regla real por el usuario | — | — | Cumplido |
| Repetibilidad FÍSICA de altura Z (con papel) | ✅ | **2026-11-02:** confirmado con `QUERY_ENDSTOPS` real (no cálculo) que X/Y/Z disparan su switch exactamente en la posición 0, repetido muchos ciclos - sin pérdida de pasos ni "memoria" fallando. Confirmado también con papel por el usuario | — | Teoría de velocidad de Z y de "Klipper se olvida" descartadas con evidencia dura | Cumplido |
| Sonda "3D Touch" diagnosticada | ✅ | 4 pruebas independientes (sonda sola, switch sano de control, reset, pin_up/down) - sensor con falla de hardware confirmada | — | Circuito de sensor muerto, servo/pin funcionan bien | Cumplido (diagnóstico, no repuesto) |
| Nivelación manual (4 esquinas + centro) | ✅ | **2026-11-02:** nivelada con método nuevo más preciso - ajuste de tornillo guiado por el switch real (`QUERY_ENDSTOPS`), no solo la hoja. 3 de 4 esquinas necesitaron ajuste (cama desnivelada, no un bug); confirmado parejo después con papel | — | — | Cumplido |
| `bed_mesh`/`screws_tilt_adjust` con sonda real | ⬜ | Wrappers con mensaje claro agregados y probados (abortan antes de medir nada) | Sonda funcional nueva | — | Pendiente de hardware |
| Inspección mecánica (correas, holguras, estructura) | 👤 | Nunca se hizo una revisión sistemática documentada | Usuario presente | — | Pendiente - procedimiento preparado en esta ronda |

## 4. Extrusión dual y cambio de color

| Objetivo | Estado | Evidencia | Dependencias | Defecto encontrado | Criterio de aceptación |
|---|---|---|---|---|---|
| `rotation_distance` T0/T1 | ✅ | **2026-10-26, con M400 bloqueante:** T0 recalibrado 7.474→7.623 (0% error verificado, 2 pasadas); T1 confirmado correcto sin cambio (7.848, 0% error de entrada). Validación cruzada: T0 sigue andando normal después de tocar T1 | — | T0 tenía 2% de error real, corregido | Cumplido |
| Lógica de macros T0/T1 (retracción/sync/purga) | ✅ | Auditoría línea por línea confirmó orden correcto, sin riesgo de movimiento simultáneo | — | — | Cumplido |
| Cambio de herramienta T0↔T1 | ✅ | **2026-11-02, con calor real (210°C):** swap probado en ambas direcciones, confirmado con `motion_queue` (no solo la respuesta del macro) - el bug pendiente de `toolhead.extruder` quedó cerrado | — | Retracción de 80mm puede expulsar el filamento del engranaje si no se parte de una carga completa - documentado, no corregido en la distancia (el usuario confirmó que 80mm es la correcta) | Cumplido |
| `_FORM_TIP` (anti-atasco de splitter) | ✅ | Probado con calor real - funcionó técnicamente, pero descartado a pedido del usuario (nunca hubo atascos sin él) | — | Distancia de 80mm expulsaba el filamento del engranaje en esta máquina | Descartado a propósito, reemplazado por jog manual |
| `LOAD_FILAMENT_T0/T1`, `UNLOAD_FILAMENT_T0/T1` + jog manual | ✅ | **2026-11-02:** T0 y T1 cargados hasta la boquilla con filamento real y confirmados extruyendo. Agregados `FILAMENTO_ADENTRO/AFUERA_LENTO/MEDIO/RAPIDO` (10mm por toque, 3 velocidades) | — | — | Cumplido |
| Sensores de filamento T0/T1 | 🟢 | Lectura coherente sin filamento cargado; todavía no confirmados CON filamento real cargado disparando la alarma al sacarlo | Usuario presente | — | Falta esa prueba específica |
| Prime Tower / purga visible de color | 🔵 | Documentado qué configurar en OrcaSlicer, no configurado todavía (es del lado del laminador, no de la placa) | Usuario configura su laminador | — | Pendiente de que el usuario lo haga en su PC |

## 5. Calidad, velocidad y calibraciones térmicas

| Objetivo | Estado | Evidencia | Dependencias | Defecto encontrado | Criterio de aceptación |
|---|---|---|---|---|---|
| PID hotend y cama | ✅ | Valores guardados en `SAVE_CONFIG` (Kp/Ki/Kd reales, no default) | — | — | Cumplido (hace tiempo, sigue vigente) |
| `firmware_retraction` | 🟡 | Valores de partida conservadores, sin torre de retracción real | Impresión de prueba | — | Falta calibrar |
| Pressure Advance T0/T1 | 🔵 | Procedimiento documentado (con la salvedad de `[extruder_stepper]` + `delayed_gcode` para T1), nunca medido | Impresión de prueba | — | Pendiente |
| Velocidad/aceleración | 🔵 | Estrategia documentada con números reales de fábrica (máx 80mm/s, recomendado 50mm/s) vs techo de firmware (250mm/s, no se tocan) | Impresión de prueba estable (requiere USB resuelto primero) | — | Pendiente, bloqueado por estabilidad USB |
| Caudal volumétrico máximo | 🔵 | No medido todavía | Impresión de prueba | — | Pendiente |
| Input Shaper | ⬜ | Arquitectura preparada (`input-shaper-future.cfg`), sin acelerómetro | Comprar Pico + ADXL345 | — | Pendiente de hardware |
| Ventilador de piezas | ✅ | `FAN_TEST` corrido de verdad; **2026-10-26: usuario confirmó visualmente que gira al 100%** | — | — | Cumplido |
| Segundo ventilador (PB0) | 🟡 | Pin confirmado por código fuente de Marlin, config preparada y comentada | Usuario verifica voltaje del terminal "HE1" antes de conectar nada | — | Pendiente de verificación eléctrica |

## 6. Hardware futuro (todo preparado, nada activado sin hardware real)

| Objetivo | Estado | Evidencia | Dependencias | Criterio de aceptación |
|---|---|---|---|---|
| Sonda de nivelación compatible | 🟡 | `probe-future.cfg` con 4 opciones comparadas, placeholders sin inventar | Comprar sonda | Pendiente de hardware |
| Pico + ADXL345 (Input Shaper) | 🟡 | `input-shaper-future.cfg` con procedimiento completo | Comprar Pico + ADXL345 | Pendiente de hardware |
| ESP32 (YA EN POSESIÓN del usuario) | 🔵 | Confirmado NO viable como MCU de Klipper; viable como dispositivo independiente (automatización fuera de Klipper) - **falta definir qué función concreta cumpliría** | Definir caso de uso real | Pendiente de decisión de uso, no de compra |
| Control de ventiladores de 3 vs 4 cables | 🔵 | Investigación pendiente de esta ronda (en curso) | — | En progreso |

## 7. Red y acceso remoto

| Objetivo | Estado | Evidencia | Criterio de aceptación |
|---|---|---|---|
| Acceso LAN estable sin depender de IP | ✅ | `avahi-daemon` activo, `facundo-cx215xx-cx212xx.local` resuelve de verdad (confirmado con `avahi-resolve`) | Cumplido, ya funciona, nada que instalar |
| Acceso remoto fuera de LAN | 🔵 | Tailscale documentado (requisitos, cómo instalar), NO instalado | Pendiente de decisión del usuario |
| Seguridad de Moonraker | 🟡 | `trusted_clients` restringido a rangos privados, ufw configurado en el pasado - **no reverificado esta sesión** (necesita sudo) | Falta reverificar que el firewall siga activo |

## 8. Interfaz Mainsail

| Objetivo | Estado | Evidencia | Criterio de aceptación |
|---|---|---|---|
| Botones de nivelación manual | ✅ | `NIVELAR*`, `ALTURA_SEGURA` - en uso desde hace semanas | Cumplido |
| Mensajes claros cuando falta hardware | 🟢 | `BED_MESH_CALIBRATE`/`SCREWS_TILT_CALCULATE` probados, abortan con mensaje en español antes de medir nada | Cumplido |
| Diagnóstico de sensores | 🟢 | `DIAGNOSTICO_SENSORES`, `ESTADO_CALIBRACION` probados con ejecución real | Cumplido |
| Prueba de ventilador | 🟢 | `FAN_TEST` probado, falta confirmación visual de que la hélice gire | Falta esa confirmación |
| Carga/descarga de filamento | 🟢 | `LOAD/UNLOAD_FILAMENT_T0/T1` - ramas de error probadas, ruta exitosa necesita calor | Falta prueba en caliente |
| Diagnóstico de USB/recuperación de errores | 🔵 | No existe todavía un macro dedicado - identificado como faltante en esta ronda | En progreso |

## 9. Software, backups y mantenimiento

| Objetivo | Estado | Evidencia | Criterio de aceptación |
|---|---|---|---|
| Backup remoto en GitHub (config) | ✅ | Repo `magna2-klipper-config`, 15+ commits, push confirmado funcionando | Cumplido |
| Bitácora persistente | ✅ | `BITACORA.md`, actualizada en cada sesión | Cumplido |
| Moonraker en canal `stable` | 🟡 | Config cambiada, servicio no reiniciado (necesita sudo) | Falta el reinicio |
| YUMI_PLR | 🔵 | Investigado a fondo, decisión documentada de DIFERIR (USB es prioridad) | Decisión tomada, no instalación |
| Scripts sin procesos duplicados | ✅ | Verificado 2026-10-26: un solo proceso del monitor corriendo, sin huérfanos | Cumplido |

---

## Resumen ejecutivo: qué falta para "estable, calibrada y lista para imprimir"

**Bloqueante real #1:** estabilidad de USB sin resolver - hasta no tener una racha
sostenida de horas (no minutos) o un experimento que aísle la causa (hub alimentado),
no tiene sentido invertir tiempo en calibraciones de velocidad/calidad que una
desconexión puede arruinar a mitad de impresión.

**Bloqueante real #2:** ninguna calibración de extrusión/PA/velocidad se puede
completar sin una sesión del usuario presente con el hotend caliente - son mediciones
físicas que no se pueden inferir ni inventar.

**No bloqueante, ya resuelto en la práctica:** homing, pull-up de Z, acceso de red,
diagnóstico de la sonda rota, arquitectura de software para todo el hardware futuro.
