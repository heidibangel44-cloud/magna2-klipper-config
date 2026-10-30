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
  Fuente: https://klipper.discourse.group/t/weird-usb-jumper-on-a-znp-mks-robin-nano-v1-2-3-board/22475

**[CORRECCIÓN 2026-10-25, tras investigar el esquemático oficial]:** la hipótesis del
jumper queda DEBILITADA, no descartada del todo. Evidencia directa del esquemático
oficial de Makerbase para la variante con chip F407 (la nuestra,
`makerbase-mks/MKS-Robin-Nano-V1.X`, hojas USB.SchDoc/Power.SchDoc de la V1.3_002 y de
la Nano-S V1.3_001): **no hay jumper** - es un circuito pasivo de diodo-OR que mezcla
automáticamente la alimentación USB y la externa, sin selector. El jumper que describe
el foro de Klipper, y el que confirma la propia cuenta oficial de Makerbase en GitHub
issue #87, es específico de la **V1.2 (chip STM32F103, no F407)** - un chip distinto al
nuestro. Como nuestra placa es una combinación no estándar (rotulada "V1.2" por Hellbot
pero con el chip F407 real), no se puede descartar al 100% sin inspección visual directa
- pero la evidencia documental dice que es MENOS probable de lo que parecía al principio.
No es la pista más fuerte que tenemos ahora - ver alternativas abajo.
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

## 2026-10-25 (continuación, MISIÓN MAESTRA) — Fases 1-10, 33 min de USB estable, nuevas herramientas

Trabajo grande bajo autorización explícita del usuario para diagnóstico/pruebas físicas
de rutina sin pedir confirmación en cada paso. Resumen (detalle completo con fuentes en
`SETUP_MAGNA_2230_KLIPPER.md`):

- **USB (Fase 1):** tabla de hipótesis armada. Cable y puerto: descartados (ya
  probados). Jumper: debilitado por esquemático oficial. Autosuspend: **todavía no
  probado** (regla udev preparada, no instalada - necesita sudo del usuario). Hallazgo
  nuevo: correlación de timestamps muestra que 5 ciclos de G28 consecutivos (19:39-19:43)
  tuvieron 0 desconexiones nuevas, mientras que las caídas pasaron en momentos de
  inactividad - descarta que el USO activo dispare las desconexiones. Ventana más larga
  limpia de esta sesión: 33 minutos sin caídas (19:35-20:08), sin declarar el problema
  resuelto.
- **Auditoría final de printer.cfg (Fase 2):** encontrado y corregido un conflicto real
  de pines en la sección `[display]` comentada (usaba PB1/PB0, ya en uso). Limpiado un
  comentario desactualizado en `safe_z_home`.
- **Botones de Mainsail (Fase 3):** investigado qué es automático (las macros ya
  aparecen solas) y qué no (paneles custom no existen en Mainsail). Agregados
  `BED_MESH_CALIBRATE`/`SCREWS_TILT_CALCULATE` con mensaje claro en español cuando
  falta la sonda (en vez del error críptico de Klipper), y macros nuevas `FAN_TEST` y
  `DIAGNOSTICO_SENSORES` - **las tres probadas con ejecución real**, no solo validación
  de sintaxis. `DIAGNOSTICO_SENSORES` tuvo un bug real de comillas en el primer intento,
  encontrado y corregido al probarlo (no asumido).
- **Arquitectura futura de sonda (Fase 4):** `probe-future.cfg` nuevo, separado, NO
  incluido en printer.cfg - placeholders sin inventar offsets, con procedimiento de
  puesta en marcha completo escrito adentro.
- **Arquitectura futura de Input Shaper (Fase 5):** `input-shaper-future.cfg` nuevo,
  mismo criterio - separado, no incluido, sin valores de resonancia inventados.
- **Calibración de extrusor dual (Fase 6):** aclarado que el "~150mm" del repo de
  referencia es específico de SU splitter, no se copia a ciegas - `_FORM_TIP` sigue en
  80mm con advertencia, pendiente de prueba real con calor.
- **Velocidad/calidad (Fase 7):** números reales de fábrica encontrados (Hellbot:
  máximo 80mm/s, recomendado 50mm/s) - aclarado que esto es la velocidad de impresión
  real (laminador), no el techo de seguridad del firmware (`max_velocity: 250`, no
  tienen que coincidir).
- **Auditoría del repo de referencia completa (Fase 8):** YUMI_PLR confirmado real,
  diagnóstico de la ubicación exacta del problema de "usuario pi" corregido con más
  precisión (son 3 líneas de `plr.cfg`, no el instalador) - NO instalado todavía
  (instalar software nuevo de un repo externo es una decisión más grande que ajustar
  configs ya presentes).
- **Plan de hardware (Fase 9):** lista A/B/C armada en SETUP_MAGNA con fuentes de costo
  orientativas, sin comprar nada.

---

## Tareas activas (no repetir investigación ya hecha arriba)

Ver TaskList de la sesión en curso / `SETUP_MAGNA_2230_KLIPPER.md` sección "Pendiente"
para el detalle completo. Resumen de lo que sigue abierto al cierre de esta entrada:

- **USB: hipótesis del jumper investigada y DEBILITADA** (esquemático oficial del chip
  F407 muestra circuito pasivo, sin jumper - el jumper real es de la V1.2/F103, otro
  chip). Opcional de costo cero: inspección visual rápida de la zona del conector USB
  por si nuestra placa no-estándar tiene algo distinto - pero no es la pista más fuerte
  ya. **Siguiente paso más prometedor:** hub USB con alimentación propia (~10-15 USD,
  preferir tipo MTT sobre STT), según la investigación de causa raíz del 2026-10-25.
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

## 2026-10-25 (continuación) — Aclaración explícita: qué probaron realmente los macros de hoy

El usuario pidió que se distinga, sin ambigüedad, entre macro cargada / macro ejecutada
/ comando original ejecutado / función bloqueada por falta de hardware / resultado
físico comprobado. Por macro, con precisión:

| Macro | Cargada | Ejecutada | ¿Corrió el comando real de nivelación/medición? | ¿Resultado físico comprobado? |
|---|---|---|---|---|
| `BED_MESH_CALIBRATE` (wrapper) | Sí | Sí | **No** - el wrapper detectó que falta la sonda y abortó antes de llamar a `BED_MESH_CALIBRATE_BASE`. Nunca se intentó medir la cama. | No - no aplica, no se intentó nivelar nada |
| `SCREWS_TILT_CALCULATE` (wrapper) | Sí | Sí (probado después, mismo resultado que `BED_MESH_CALIBRATE`: abortó antes de llamar al comando real) | No | No |
| `FAN_TEST` | Sí | Sí | N/A (no es de nivelación) | **Sí, parcialmente** - se confirmó que el macro corrió las 3 etapas y que `fan.speed` volvió a 0.0 al final. No se confirmó con los ojos/oídos que la hélice gire de verdad (eso requiere al usuario presente) |
| `DIAGNOSTICO_SENSORES` | Sí (tras corregir un bug real de comillas) | Sí | N/A | Parcial - los valores reportados (temperatura, homed_axes, sensores) son lecturas reales de Klipper, coherentes con el estado conocido, pero es un reporte de lectura, no una medición nueva |

**Conclusión explícita, para que quede escrita y no se repita la ambigüedad:** ninguna
prueba de hoy niveló la cama, midió una malla, ni confirmó físicamente que un
ventilador gire. Lo que SÍ se confirmó: que el comportamiento de "avisar que falta
hardware en vez de arrancar un movimiento de medición incompatible" funciona
correctamente - que es exactamente lo que tenía que pasar mientras no haya sonda, ni
más ni menos. No se declara la cama nivelada ni la sonda reemplazada por ningún motivo.

## 2026-10-25 (continuación) — Segunda ronda de autonomía: USB corregido con evidencia, macros nuevas, decisiones documentadas

- **USB, hallazgo importante que corrige lo dicho antes:** búsqueda exhaustiva de
  `suspend`/`wakeup` en los 24 eventos de desconexión de este arranque: **cero
  resultados**. El patrón real es siempre `urb stopped: -32` + desconexión dura +
  re-enumeración como dispositivo nuevo - no es la firma de una suspensión por
  software. `power/control` ya está en `on` (autosuspend inactivo) y las caídas
  siguen igual. **La regla udev preparada probablemente no resuelve esto** - se deja
  igual (gratis, no hace daño) pero sin prometer que arregle nada.
- Racha estable más larga medida en vivo: 36m49s (19:35:22-20:12:11), se rompió con
  la misma firma de siempre. Total del arranque: 24 desconexiones.
- Montado `tools/usb_monitor_pasivo.sh` corriendo en background (PID activo al cierre
  de esta entrada), logueando cada 15s de forma continua - no son solo chequeos
  puntuales.
- Agregadas y **probadas con ejecución real** (no solo carga): `LOAD_FILAMENT_T0/T1`,
  `UNLOAD_FILAMENT_T0/T1` (precondiciones de herramienta activa + hotend caliente,
  ambas ramas de error confirmadas), `ESTADO_CALIBRACION` (reporte de solo lectura,
  valores coherentes).
- **ESP32 vs Pico, comparación cerrada:** Pico es la única opción válida para medir
  vibraciones (ya sabido). ESP32 SÍ tendría un rol real pero como dispositivo
  independiente, fuera de Klipper (automatizaciones, cámara, enchufe remoto) - sin
  necesidad concreta identificada todavía, no se recomienda comprar uno ahora.
- **YUMI_PLR: decisión documentada de diferir.** No instalar hasta resolver la
  inestabilidad de USB primero - instalar protección contra corte de luz mientras la
  causa real de las interrupciones (USB) sigue sin resolver es priorizar el síntoma
  secundario.

## 2026-10-26 (sesión física interactiva) — 3 cortes en vivo, lección sobre G92 con cola pendiente, optimización de la netbook

Sesión con el usuario presente, siguiendo el procedimiento de calibración de extrusión
preparado. Resultados reales, no inferidos:

- Inspección mecánica visual (correas, poleas, boquilla, ventiladores, cableado):
  confirmación general "todo OK" del usuario - registrado como pase general, no
  punto por punto (el usuario pidió acelerar).
- Identificados 2 ventiladores: uno siempre encendido (hotend/disipador, cableado
  directo, correcto que esté siempre prendido) y uno controlado por Klipper (pieza,
  responde a M106/M107, confirmado).
- **T0, primera medición (válida):** 100mm pedidos → 102mm reales con rotation_distance
  original (7.474). Factor 1.02 → nuevo valor calculado: 7.623.
- **3 cortes de conexión durante la sesión de calibración**, de 2 tipos distintos:
  uno "Lost communication with MCU" (USB real) tras 13 minutos de silencio sin que
  nadie lo notara durante la inspección mecánica; uno "Timer too close" (sobrecarga de
  CPU del host, no la placa); otro más "Lost communication" durante la segunda
  verificación.
- **Lección técnica importante, con evidencia real:** tras el segundo corte, `G92 E0`
  seguido de un nuevo `G1 E100` NO garantiza un test limpio - un movimiento anterior
  que quedó en la cola de la placa (por la interrupción) puede ejecutarse más tarde,
  sumándose al nuevo. Confirmado con `toolhead.position` mostrando E=200 en vez de 100,
  y el usuario reportando "entró mucho más, se perdió la marca". **Las mediciones 2 y 3
  de T0 quedan invalidadas por esto** - solo la primera (102mm) es dato limpio.
  Corrección de proceso: tras cualquier interrupción a mitad de un movimiento, hace
  falta `firmware_restart` completo (no solo reconectar) antes de confiar en la
  próxima medición.
- **T1: no se llegó a medir** - la sesión se desvió a diagnosticar los cortes.
- **Causa raíz real de los cortes "Timer too close" encontrada con evidencia directa:**
  `ps aux --sort=-%cpu` mostró Klipper usando ~0.7% de CPU, mientras Claude Desktop
  (~50% entre sus procesos) y Firefox (~25%) corrían a la vez en esta netbook de 2
  núcleos. Decisión del usuario: optimizar la netbook a fondo por software (sin
  hardware nuevo), ya que la van a seguir usando siempre así.
- Preparadas e instalables con un solo script (`tools/instalar_optimizaciones_netbook.sh`,
  necesita sudo, no corrido todavía): prioridad de Moonraker (Klipper ya la tenía),
  governor de CPU en "performance", swappiness bajado de 60 a 10, regla udev de
  autosuspend (ya preparada antes). Documentado como reversible en
  `tools/README_optimizaciones.md`.
- **La optimización de mayor impacto no necesita instalar nada:** cerrar Claude
  Desktop y Firefox mientras se calibra o imprime - en una netbook de 2 núcleos, no
  hay margen para correr eso Y mantener la comunicación en tiempo real con la placa.

## 2026-10-26 (continuación) — Calibración de extrusión T0/T1 completada con éxito

Retomada tras instalar las optimizaciones de la netbook. Esta vez, cada movimiento se
confirmó con `M400` (bloqueante, confirma ejecución física real, no solo la posición
lógica) antes de pedir la medición - sin cortes de conexión en el medio.

- **T0: recalibrado y guardado.** 100mm pedidos → 102mm reales con el valor viejo
  (7.474, de 2026-08-11) → nuevo valor 7.474×1.02=**7.623** → verificado con una
  segunda pasada limpia: 100mm pedidos → **100mm exactos** (0% de error). Guardado en
  `printer.cfg`, confirmado que sobrevive a un restart (`ESTADO_CALIBRACION` lo
  reporta). Commit `2023b9d`.
- **T1: confirmado correcto, SIN cambios.** 100mm pedidos → **100mm exactos** con el
  valor ya existente (7.848, de 2026-08-11) - 0% de error de entrada, no necesitaba
  corrección.
- **Validación cruzada final:** vuelto a T0 después de calibrar T1, extrusión de
  prueba de 20mm - el usuario confirmó que sigue andando normal, sin trabas ni saltos.
  Calibrar T1 no afectó a T0.
- **Nota de arquitectura aprendida en el proceso:** `toolhead.extruder` en esta config
  siempre reporta `"extruder"`, nunca `"extruder1"` - no es un indicador válido de cuál
  tool (T0/T1) está activo en este setup (extruder1 es un `extruder_stepper`
  sincronizado, no un extruder de toolhead real para Klipper). No usar ese campo para
  diagnosticar el tool activo en el futuro - confirmar por comportamiento físico.
- Hotend apagado al terminar (`TURN_OFF_HEATERS`). Sesión de calibración de extrusión
  del día: **cerrada con éxito, ambos extrusores con datos reales y guardados.**

## 2026-10-26 (continuación) — Fan de pieza confirmado, repetibilidad de X/Y/Z con regla real

- **Ventilador de pieza (el "de adelante", controlado por Klipper):** confirmado que
  gira al 100% cuando se comanda por software. El otro (hotend, "de la derecha") ya
  estaba confirmado como siempre encendido, cableado directo.
- **Repetibilidad de movimiento con regla real, los 3 ejes, cada uno confirmado
  exacto (0% de error):**
  - X: 50mm pedidos → 50mm medidos.
  - Y: 50mm pedidos → 50mm medidos (necesitó 2 reintentos - el usuario no llegaba a
    medir a tiempo; se resolvió pidiendo que la regla quede puesta ANTES de mover, no
    después).
  - Z: 20mm pedidos → 20mm medidos.
- Conclusión: el sistema de movimiento (X/Y/Z) es preciso y repetible con medición
  física real, no solo por reporte de software. Sin defectos mecánicos encontrados en
  esta prueba.
- **Nivelación manual completa realizada:** cama y hotend a 60°C/210°C, las 4 esquinas
  ajustadas con papel y después verificado en el centro - usuario confirmó parejo.
  Calentadores apagados al terminar.
