# Bitácora del proyecto — Hellbot Magna 2 230 Dual / Klipper

Registro cronológico de pruebas, errores, soluciones y pendientes. Objetivo: que
cualquier sesión futura (de Claude o de otra persona) pueda continuar sin repetir
trabajo ni re-derivar conclusiones ya probadas. Para contexto de hardware/software y
procedimientos de referencia, ver `SETUP_MAGNA_2230_KLIPPER.md` — este archivo es el
*registro de eventos*, ese otro es la *referencia*.

Formato de cada entrada: fecha, qué se hizo/encontró, evidencia concreta, estado final.

---

## 2026-08-11 — Instalación inicial

- Klipper/Moonraker/Mainsail instalados vía KIAUH.
- Firmware compilado (`~/klipper/out/Robin_nano35.bin`, md5 `8773aace5f6cc1b5b1c2d16d923261f1`).
- **Bug crítico encontrado y corregido:** `scripts/update_mks_robin.py` corrompe el
  firmware en esta placa (V1.3 real, no V1.2) por una conversión XOR pensada para otro
  bootloader. Fix: usar `klipper.bin` renombrado directo, sin conversión. Corregido en
  el repo `heidibangel44-cloud/magna-klipper` (commit `3f9c9c9`).
- PID calibrado (hotend y cama), rotation_distance medido para T0 (7.474) y T1 (7.848,
  distinto de T0 - no asumir que son iguales).
- Nivelación manual de 4 esquinas + centro, confirmada por el usuario.
- **Sensor "3D Touch" (BLTouch clon):** no completa touch_mode. Primer diagnóstico
  (incompleto en este momento): se asume posible falla o limitación del clon, queda
  desactivado, se usa switch mecánico de Z.

## 2026-08-13 — Primera hipótesis de Z (backlash, no confirmada)

- Problema reportado: altura de Z inconsistente entre homings, que NO ocurría con
  Marlin en el mismo hardware.
- Hipótesis probada: el doble-paso de homing de Klipper (retrocede 5mm + segunda pasada
  lenta) mete backlash de la varilla. Se desactivó (`homing_retract_dist: 0`,
  `homing_speed: 3`).
- **Resultado:** sin confirmación clara, quedó pendiente de más pruebas.

## 2026-08-18 — Causa real encontrada: pull-up faltante + sonda con falla de hardware

- **Fix real #1:** `[stepper_z] endstop_pin` no tenía pull-up (`^`). Marlin en esta
  placa tiene `ENDSTOPPULLUPS` activado por defecto; nuestra config no, dejando el pin
  flotando (vulnerable a ruido del motor de Z al lado). Corregido: `endstop_pin: ^!PA11`.
  Confirmado con test diferencial (switch solo, en reposo da `open`, apretado da
  `TRIGGERED` - correcto en ambos estados).
- **Sonda "3D Touch" diagnosticada a fondo, con evidencia, no suposición:** servo/pin
  físico confirmado funcional (se mueve, LED responde). Sensor de contacto
  **permanentemente en TRIGGERED sin importar el estado real del pin** - probado con:
  reset (`BLTOUCH_DEBUG COMMAND=reset`), sonda sola (switch mecánico desconectado,
  confirmado dos veces), pin arriba y abajo. Pin de la placa descartado como causa
  (sano, probado con el switch mecánico en el mismo pin PA11). **Conclusión: falla real
  de hardware en el circuito del sensor de esa unidad.** Desconectada/comentada hasta
  reparar o reemplazar.
- **Hallazgo grande: inestabilidad física de USB.** `journalctl -k` mostró
  desconexiones reales del USB del CH340 (vendor 1a86), correlacionadas exacto con
  "Lost communication with MCU" y shutdown total de Klipper en `klippy.log`/
  `moonraker.log`, varias veces ese día. Esto explica gran parte de "la altura cambia
  sola": en realidad la impresora se caía y se perdía el homing sin que siempre quedara
  obvio. Pendiente en ese momento: probar cable/puerto distinto.

## 2026-10-25 — Reflasheo de Klipper (la placa había vuelto a tener Marlin) y USB sigue fallando con cable Y puerto nuevos

- La placa tenía **Marlin** cargado (el usuario volvió a Marlin en algún momento entre
  sesiones, por confiabilidad, mientras este proyecto estaba pausado).
- Se preparó la microSD: **sin formatear, sin borrar nada** (se hizo backup completo de
  gcodes y archivos viejos antes). Se copió el mismo `Robin_nano35.bin` ya verificado
  (mismo md5 que el 11/08 - no se recompiló nada, no hacía falta). Usuario flasheó
  físicamente. Klipper conectó correctamente: `MCU: stm32f407xx`, `CLOCK_FREQ: 168MHz`,
  comunicación limpia al principio.
- Software: revertido el homing de una sola pasada a las 2 pasadas default (la
  hipótesis de backlash de 08-13 no se pudo confirmar, y la doc oficial de Klipper dice
  que la segunda pasada MEJORA precisión, compensa sobre-recorrido del switch a
  velocidad alta - no la empeora). Agregado `[firmware_retraction]` (valores de
  partida, sin calibrar todavía). Documentado Prime Tower de OrcaSlicer para purga de
  doble color, y procedimiento de Pressure Advance (T0/T1 por separado, con la
  salvedad de que `[extruder_stepper]` no acepta `pressure_advance` fijo - necesita
  `delayed_gcode`). Commits `2d975a5` y previos, pusheados.
- **Usuario cambió cable USB Y puerto de la netbook. El problema de desconexión
  SIGUIÓ pasando** - confirmado con `journalctl -k`: flicker de conexión/desconexión
  en los primeros segundos tras conectar, y una caída nueva ~5 minutos después
  (18:19:54, puerto `2-1.2`, reconectó solo en ~9s). **Esto descarta que sea
  simplemente "el cable" o "el puerto"** - sube de probabilidad que sea el chip
  USB-serie de la placa (CH340) o un problema de alimentación USB general de esta
  netbook (controlador `ehci-pci`, antiguo/débil). Ver sección de hipótesis pendientes
  en `SETUP_MAGNA_2230_KLIPPER.md`.
- Auditoría de sensores sin movimiento: endstops X/Y/Z en `open` coherente, temperaturas
  a ambiente coherentes, sensores de filamento sin filamento cargado (esperado, sin
  filamento puesto). Nada inconsistente encontrado.
- Mientras se trabajaba (sin tocar nada del lado del software), **el USB se desconectó
  solo otras 2 veces más** (18:19:54 y 18:28:07-18:28:25, confirmado en `journalctl -k`,
  device number subiendo hasta 20 - o sea, veinte reconexiones desde el boot). Sigue
  pasando con cable Y puerto ya cambiados por el usuario.
- **Pista concreta y de costo cero encontrada para el USB:** la MKS Robin Nano tiene un
  jumper de alimentación USB (documentado en el foro de Klipper para esta familia de
  placas) que debe estar en 12V/24V, nunca en "USB power", y nunca alimentando por los
  dos lados a la vez - si está mal puesto causa exactamente "unstable voltage
  conditions or ground loops", síntoma indistinguible de lo que estamos viendo.
  **Pendiente de que el usuario lo revise físicamente - no se puede ver por software.**
  Fuente: https://klipper.discourse.group/t/weird-usb-jumper-on-a-znp-mks-robin-nano-v1-2-3-board/22475
- **Hallazgo grande:** existe un repo de GitHub (`FacuM/hellbot-wanhao-300-dual-klipper`)
  con una config real para la MISMA impresora (Hellbot Magna 2, misma placa, mismos
  pines de `extruder1`: PA6/PA1/PA3 - confirma que es el mismo hardware). Tiene un macro
  `_FORM_TIP` (ramming + vaivenes de enfriamiento antes de retraer) pensado para evitar
  que la punta de filamento se atasque en el splitter en Y donde se juntan los dos
  caminos - un problema mecánico real y documentado de este diseño que nosotros no
  habíamos visto todavía. Se adaptó (no copiado a ciegas - las coordenadas de purga de
  ese repo son de SU cama de 300mm, no sirven para nuestra cama de 230mm) e incorporado
  como macro `_FORM_TIP` nuevo en printer.cfg, **preparado pero NO conectado todavía a
  T0/T1** - falta probarlo con el hotend caliente de verdad, que necesita supervisión.
- Confirmado por código fuente real de Marlin (no suposición): el pin **PB0** de esta
  placa queda libre como segundo ventilador/heater cuando hay 1 solo hotend (nuestro
  caso) - sale físicamente al terminal rotulado "HE1". Agregado como `[heater_fan]`
  comentado/preparado en printer.cfg, con la advertencia de verificar el jumper de
  voltaje de ese terminal antes de activarlo (podría estar en 12V o 24V, nunca conectar
  un fan de 5V ahí sin chequear).
- Moonraker: `update_manager channel` estaba en `dev` (inestable) - cambiado a `stable`.
  Falta reiniciar el servicio de moonraker (necesita sudo, pendiente del usuario).

## 2026-10-25 (continuación) — Autorización de pruebas físicas, primer homing exitoso post-reflasheo

El usuario autorizó expresamente G28 y pruebas de movimiento sin pedir confirmación en
cada paso, con condiciones de seguridad explícitas (parar si algo es incoherente, no
repetir movimientos riesgosos a ciegas, no imprimir ni calentar sin supervisión).

- **G28 X Y: exitoso.** `homed_axes: xy`, posición [0,0], sin error. Endstops tras home:
  `stepper_x:TRIGGERED stepper_y:TRIGGERED` (coherente - están físicamente apretados en
  el punto de home, no se movieron después).
- **G28 Z: exitoso.** Primera vez con el firmware reflasheado el 2026-10-25. `homed_axes:
  xyz`, sin shutdown, `bytes_invalid: 0`. Tras home, XY se movió al centro (115,115) y Z
  subió a 10 (comportamiento esperado de `[safe_z_home]`). Endstops después: los tres en
  `open` (coherente con las posiciones resultantes).
- **5 ciclos de home completo repetido (viajar + G28), solo software:** los 5 dieron
  `estado=ready`, `homed_axes=xyz`, mismos stats de MCU (`9,0` - sin cambio, sin
  retransmisiones nuevas) cada vez. **Esto prueba que la comunicación y el software se
  comportan de forma estable y repetible en 5 ciclos consecutivos de homing. NO prueba
  que la altura física real sea consistente** - esa medición requiere al usuario con
  papel en mano, que es justo la parte que el script `test_z_repeatability.sh` pide por
  `read -p` y que no se puede completar sin una persona presente. Esa prueba física con
  papel sigue pendiente.
- Resultados guardados en
  `tools/z_repeatability_results_20261025_193922_SOLO_SOFTWARE.csv`.
- **El USB se desconectó 2 veces más durante este bloque de trabajo** (antes de empezar
  el homing), recuperado con `firmware_restart`/`restart`. Sigue sin resolverse de fondo,
  pero no impidió completar los 5 ciclos de homing sin incidentes una vez reconectado.

### Inventario de sensores (estado real, no inferido)

| Sensor | Identificado | Consultado | Funcional por software | Probado físicamente | Nota |
|---|---|---|---|---|---|
| Endstop X (`!PA15`) | sí | sí | sí | sí | `open`/`TRIGGERED` coherente con posición conocida, hoy |
| Endstop Y (`!PA12`) | sí | sí | sí | sí | idem |
| Endstop Z (`^!PA11`, switch mecánico) | sí | sí | sí | sí (parcial) | Coherente en reposo/home hoy. Repetibilidad física (papel) NO probada hoy - pendiente |
| Sonda "3D Touch" (BLTouch clon) | sí | sí | **no** | sí | Diagnóstico de hardware roto confirmado 2026-08-18, desconectada |
| Sensor filamento T0 (`^PA4`) | sí | sí | sí | no | Lee `filament_detected: false` coherente (sin filamento cargado) - falta probar que SÍ detecte al cargar |
| Sensor filamento T1 (`^PE6`) | sí | sí | sí | no | idem |
| Termistor extruder (`PC1`) | sí | sí | sí | parcial | Lectura ambiente coherente (~23°C). Falta validar en caliente con protección térmica |
| Termistor cama (`PC0`) | sí | sí | sí | parcial | idem, ~22°C ambiente |

### Revisión completa del repo de referencia FacuM/hellbot-wanhao-300-dual-klipper

- **Hallazgo importante, ya corregido en nuestro `_FORM_TIP`:** probaron en la práctica
  que retraer 80-90mm dejaba un hilo colgando que atascaba el splitter en Y - subieron a
  ~150mm. Nuestro `_FORM_TIP` tenía 80mm de default (mismo número que ya usábamos en
  T0/T1 para el swap rápido, que SÍ está verificado para eso, pero no necesariamente para
  un ciclo de forming+park prolongado). Se agregó una advertencia explícita en el
  comentario del macro - no conectarlo a T0/T1 sin probar con cuidado si queda hilo
  colgando.
- No usan PB0 para nada (ni fan, ni heater) - su repo no resuelve esa pregunta, queda
  como lo encontramos: confirmado por código fuente de Marlin que el pin existe, no
  confirmado por ningún uso real de otro usuario.
- Tienen `input_shaper` medido a mano (`shaper_type: mzv`, freq_x 22.0, freq_y 19.0) -
  son valores de SU máquina (300mm), no transferibles, pero el método (torre de
  resonancia + TUNING_TOWER de SHAPER_FREQ_Y) es una referencia válida para cuando
  tengamos el acelerómetro.
- Fijan `pressure_advance: 0.66` en `[extruder]`, pero sus macros T0/T1 lo resetean a 0
  en cada cambio de herramienta sin explicación clara en el repo - **no copiar ese
  comportamiento sin entender por qué lo hacen.**
- No tienen `[firmware_retraction]` ni `[probe]`/`[bltouch]` en ningún archivo - manejan
  todo a mano con macros, y no parecen tener nivelación automática tampoco (otro dato
  que sugiere que esta familia de impresoras tiene esta limitación con frecuencia, no
  solo la nuestra - sin confirmar más allá de este único caso).
- README: confirma que esta placa se cuelga en "Updating 100%" al flashear (normal,
  apagar y sacar la SD) y queda en "Booting..." esperando a Klipper (normal) - coincide
  con lo que ya sabíamos. Avisa explícitamente NO correr `sign_mks_robin_nano.sh` en
  esta placa.

---

## Tareas activas (no repetir investigación ya hecha arriba)

Ver TaskList de la sesión en curso / `SETUP_MAGNA_2230_KLIPPER.md` sección "Pendiente"
para el detalle completo. Resumen de lo que sigue abierto al cierre de esta entrada:

- **USB: pendiente identificar el jumper EXACTO para esta revisión de placa** (no asumir
  que el hallazgo genérico de un foro aplica sin confirmar el esquemático real - en
  investigación ahora mismo).
- **Prueba de repetibilidad FÍSICA de Z (con papel): sigue pendiente** - la parte de
  software ya se validó hoy (5/5 ciclos limpios), falta la parte física con el usuario
  presente.
- `_FORM_TIP` preparado pero no conectado a T0/T1 - probar con hotend caliente en
  sesión supervisada antes de integrarlo al flujo real de cambio de color.
- Segundo fan en PB0 preparado pero comentado - el usuario debe verificar el jumper de
  voltaje de ese terminal antes de activarlo.
- Reiniciar el servicio de moonraker para que tome el canal `stable` (pendiente, necesita
  sudo del usuario).
- Pressure Advance, Input Shaper (bloqueado en hardware), ventilador auxiliar, doble
  color: en investigación/preparación de software, sin prueba física de calor/extrusión
  (requiere supervisión, no se hace sin el usuario presente).
