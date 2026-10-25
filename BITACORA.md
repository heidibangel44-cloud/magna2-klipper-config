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

---

## Tareas activas (no repetir investigación ya hecha arriba)

Ver TaskList de la sesión en curso / `SETUP_MAGNA_2230_KLIPPER.md` sección "Pendiente"
para el detalle completo. Resumen de lo que sigue abierto al cierre de esta entrada:

- **USB: pendiente que el usuario revise el jumper de alimentación de la placa** (ver
  arriba) - es la pista más concreta y de costo cero que hay ahora. Si eso no es, la
  siguiente opción más barata es un hub USB con alimentación propia.
- Prueba de repetibilidad de Z: diseñada pero NO ejecutada (requiere sesión supervisada
  con el usuario presente).
- `_FORM_TIP` preparado pero no conectado a T0/T1 - probar con hotend caliente en la
  sesión supervisada antes de integrarlo al flujo real de cambio de color.
- Segundo fan en PB0 preparado pero comentado - el usuario debe verificar el jumper de
  voltaje de ese terminal antes de activarlo.
- Reiniciar el servicio de moonraker para que tome el canal `stable` (pendiente, necesita
  sudo del usuario).
- Pressure Advance, Input Shaper (bloqueado en hardware), ESP32, ventilador auxiliar,
  doble color: en investigación/preparación de software, sin prueba física.
