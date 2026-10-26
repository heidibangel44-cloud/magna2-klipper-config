# Setup Klipper — Hellbot Magna 2 230 Dual

Documento de referencia de la instalación de Klipper en esta netbook para controlar
la Hellbot Magna 2 230 Dual. Última actualización: 2026-08-11.

## Hardware confirmado

- **Impresora:** Hellbot Magna 2 230 Dual (2 motores extrusores → 1 hotend compartido)
- **Volumen de impresión:** 230×230×250mm
- **Placa:** Makerbase MKS Robin Nano, vendida por Hellbot como "V1.2" pero con chip real
  **STM32F407VET6** (confirmado por foto directa del chip — es efectivamente una V1.3)
- **Drivers:** 2× TMC2209 (X/Y, modo standalone sin UART) + 3× A4988 (Z/E0/E1)
- **Extrusor:** Bowden Dual Drive, "hotend 2 en 1" (T0/T1 comparten el mismo bloque
  calefactor y termistor)
- **Conexión host↔placa:** USB → chip CH340 integrado en la placa → USART3 (PB10/PB11)
  del STM32, a 250000 baudios (default de Klipper)
- **Sensor de nivelación:** "3D Touch" (clon de BLTouch) — **actualmente dañado/no
  funcional** en el modo touch_mode que necesita Klipper (ver sección de problemas
  conocidos). Se usa el switch mecánico de Z como respaldo.
- **Sensores de filamento:** 2 unidades (T0=PA4, T1=PE6), confirmados funcionando.
- **Módulo WiFi:** ESP-12S integrado en la placa (no configurado/usado por Klipper).

## Software instalado

- **Host:** Linux Mint 22.3 "Zena" (verificado 2026-10-26, no asumido), kernel
  `6.14.0-37-generic`, Python 3.12.3, en esta netbook (Intel Celeron B820, 5.7GB RAM)
- **Klipper:** `v0.13.0-730-g84104bbb` (verificado vía `/printer/info`)
- **Moonraker:** `v0.10.0-31-gd5ee171` (verificado vía `/server/info`)
- **Mainsail:** `v2.18.2` (verificado)
- **Firmware del MCU:** compilado con el defconfig del repo
  `~/klipper-magna/magna-klipper/config/robin_nano_v13_f4.config`
  (USART3, cristal 8MHz, bootloader 32KiB, baud 250000)

## ⚠️ Hallazgo crítico: bug del script `update_mks_robin.py`

El script de conversión de firmware `scripts/update_mks_robin.py` del propio repo de
Klipper aplica una transformación XOR pensada para el bootloader de la **V1.2**. En esta
placa (V1.3 real), esa transformación **corrompe el firmware** — el bootloader lo flashea
"exitosamente" (llega a 100%, renombra a `.CUR`) pero el código resultante nunca arranca
correctamente (silencio total en el puerto serie, sin importar USART/baudrate probado).

**Solución:** compilar con `make`, y usar `out/klipper.bin` **directamente**, renombrado
a `Robin_nano35.bin`, **sin pasar por `update_mks_robin.py`**. Confirmado documentado en
el foro oficial de Klipper: https://klipper.discourse.group/t/klipper-on-mks-robin-nano-v1-3/2967

**Pendiente:** corregir esto en el repo de GitHub (`heidibangel44-cloud/magna-klipper`) —
el workflow de GitHub Actions todavía usa el script viejo. Falta actualizar
`.github/workflows/build-firmware.yml` y documentarlo en el README.

## Acceso

- **Mainsail:** `http://192.168.18.196` (puerto 80) — accesible desde la red local
  (192.168.18.0/24). Firewall (ufw) configurado anteriormente en el proyecto para
  bloquear desde fuera de esa red - **no reverificado en esta sesión** (necesita sudo
  interactivo), asumir que sigue como se dejó salvo que se confirme lo contrario.
- **Moonraker API:** `http://192.168.18.196:7125`
- **API key de Moonraker:** ver con `curl http://localhost:7125/access/api_key`
  (no compartir públicamente, da control de la impresora)
- **Puerto serie:** `/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0` (ruta estable,
  no usar `/dev/ttyUSB0` que puede cambiar de número)

### Red: WiFi, IP cambiante y acceso remoto (auditado 2026-10-26)

- **Conexión actual:** WiFi (`wlp2s0`, red "FTTH_Wruck"), IP `192.168.18.196/24` por
  **DHCP** (no estática - técnicamente puede cambiar si el router reasigna la
  dirección, aunque en la práctica viene siendo la misma desde agosto). Ethernet
  (`enp3s0`) existe en la netbook pero no está conectado por cable ahora.
- **Para no depender de la IP (ya funciona, confirmado, sin instalar nada nuevo):**
  `avahi-daemon` ya está activo en este sistema. Se puede acceder como
  `http://facundo-cx215xx-cx212xx.local` desde cualquier dispositivo de la red que
  soporte mDNS (Windows 10+, macOS, Linux, la mayoría de Android) - **confirmado que
  resuelve** (`avahi-resolve -n facundo-cx215xx-cx212xx.local`). Más simple y sin
  configurar nada en el router.
- **Alternativa más universal (si algún dispositivo no soporta mDNS):** reserva DHCP
  en el router, asignando siempre la misma IP a la MAC de esta netbook:
  `dc:85:de:93:60:0e` (interfaz WiFi). Esto se configura DESDE el router, no desde
  acá - páginas de administración varían según el modelo.
- **Acceso remoto fuera de la red local: NO expongas Mainsail/Moonraker directo a
  Internet** (ni con port-forwarding en el router). La alternativa segura es una VPN
  tipo mesh, ej. **Tailscale**: requiere crear una cuenta (gratis para uso personal,
  hasta cierto número de dispositivos), instalar el cliente en esta netbook
  (`curl -fsSL https://tailscale.com/install.sh | sh` + `tailscale up`, requiere login
  una vez) y el cliente en cada dispositivo desde el que quieras controlar la
  impresora (celular, otra PC). Una vez conectados ambos a la misma "tailnet", se
  accede por la IP privada que asigna Tailscale (ej. `100.x.x.x`) como si estuvieran
  en la misma red, sin abrir ningún puerto al público. **No instalado todavía** - es
  una decisión del usuario, no algo que se instale solo.

## Calibraciones realizadas (2026-08-11)

- **PID hotend:** Kp=24.563, Ki=0.963, Kd=156.589
- **PID cama:** Kp=65.585, Ki=0.951, Kd=1131.340
- **rotation_distance T0:** 7.474 (medido físicamente, 2 pasadas de verificación)
- **rotation_distance T1:** 7.848 (medido por separado, distinto a T0 — no asumir que
  son iguales)
- **Nivelación de cama:** manual, 4 esquinas + centro con papel, 2 pasadas, confirmada OK
  por el usuario. Cama caliente a 60°C, hotend a 208°C durante la nivelación.
- **Dirección de motores X/Y/Z:** verificada correcta, sin necesidad de invertir nada.
- **Switch mecánico de Z (pin PA11):** confirmado funcionando (pin y polaridad OK).

## Problemas conocidos

1. **Sensor "3D Touch" no funcional en Klipper.** Despliega/repliega bien mecánicamente
   y la señal cruda del pin funciona, pero el modo `touch_mode` que Klipper necesita para
   `QUERY_PROBE` queda permanentemente en `TRIGGERED`. Se probó el procedimiento oficial
   completo de troubleshooting de Klipper (`pin_up_reports_not_triggered`,
   `pin_up_touch_mode_reports_triggered`, ambos valores, ciclos de reset, power-cycle
   completo) sin éxito. Posible daño puntual (se forzó el pin hacia arriba durante una
   prueba) o incompatibilidad del clon. **Mientras tanto:** Z usa el switch mecánico
   (`endstop_pin: !PA11` en `[stepper_z]`), sin bed_mesh automático.
   - `[bltouch]` queda comentado en `printer.cfg`.
   - `[bed_mesh]` y `[screws_tilt_adjust]` quedan definidos pero no usables sin un probe
     funcional.
2. **Límite de temperatura del hotend en 245°C.** No es arbitrario: el tubo de PTFE
   (teflón) se degrada por encima de ~250°C. El usuario planea modificar/reemplazar el
   PTFE para poder subir el límite con seguridad — **no subir `max_temp` hasta confirmar
   que esa modificación esté hecha**.
3. **Idle timeout apaga motores y heaters a los 10 minutos de inactividad** (default de
   Klipper). Normal, pero hay que recordar rehomear y recalentar si se pasa mucho tiempo
   entre pasos durante calibración manual.

## Pendiente

- [ ] **USB: conseguir un hub USB con alimentación propia** (~10-15 USD, preferir tipo
      MTT sobre STT) - la hipótesis del jumper de alimentación se investigó a fondo y
      quedó DEBILITADA (el esquemático oficial del chip F407 no tiene jumper, es un
      circuito pasivo - el jumper real es de la variante V1.2/F103, otro chip). Revisar
      visualmente la zona del USB es gratis y rápido pero ya no es la pista más fuerte.
      Ver nota técnica de estabilidad USB abajo.
- [ ] Primera impresión de prueba estable (requiere confirmar que el USB ya no se
      desconecta - ver "Nota técnica: estabilidad USB" abajo)
- [ ] Probar `_FORM_TIP` (agregado 2026-10-25, preparado pero no conectado a T0/T1) con
      el hotend caliente de verdad - necesita supervisión, no se puede probar en frío.
- [ ] Si se activa el segundo fan en PB0 (preparado/comentado): verificar a mano el
      jumper de voltaje de ese terminal ("HE1") antes de conectar cualquier ventilador.
- [ ] Pressure advance - procedimiento listo, ver nota técnica abajo (necesita impresión
      de prueba, por separado para T0 y T1)
- [ ] Configurar el Prime Tower en OrcaSlicer para el cambio de color - ver nota técnica
      "Doble color / purga" abajo
- [ ] Afinar velocidad/aceleración con Klipper (partiendo de los valores conservadores
      del fabricante: 45mm/s impresión, 30mm/s paredes)
- [ ] Calibrar `retract_length` de `[firmware_retraction]` (agregado 2026-10-25 con
      valor de partida conservador, falta afinar con una torre de retracción real)
- [ ] Recuperación por corte de energía (YUMI_PLR — requiere G-code de slicer configurado
      primero, y ajustar el instalador que asume usuario `pi` en vez de `facundo`)
- [ ] Reemplazar la sonda "3D Touch" (diagnóstico de hardware confirmado roto el
      2026-08-18, no es config) para retomar bed_mesh automático
- [ ] Subir el `max_temp` del hotend una vez confirmada la modificación del PTFE
- [ ] Input Shaper — pendiente de hardware futuro (acelerómetro ADXL345 vía Arduino/Pico
      como MCU adicional). **No hay valores de resonancia inventados acá** — se miden
      recién cuando el sensor físico esté disponible. Ver nota técnica abajo.

**Ya resueltos (no repetir):** backup remoto en GitHub, bug de `update_mks_robin.py` en
el repo de GitHub, pull-up faltante en el switch de Z, Cura/OrcaSlicer con perfiles
básicos.

## Nota técnica: estabilidad USB (hallazgo 2026-10-25, actualizado el mismo día)

Se encontró evidencia real (`journalctl -k`) de desconexiones físicas del USB del CH340
(reconecta solo segundos después, a veces en menos de 1 segundo) que tiran a Klipper a
shutdown y borran el homing - esto explica buena parte de la sensación de "la altura
cambia sola": en realidad la impresora se cayó y el usuario sigue nivelando sobre un
estado inválido. No es (solo) un problema mecánico de Z.

**Ya descartado:** cable USB nuevo y puerto distinto de la netbook - el problema siguió
pasando igual con ambos cambiados, varias veces, incluso el mismo 2026-10-25 durante
pruebas de homing (recuperado sin incidentes cada vez, gracias a que el chequeo de
endstop corre en la propia placa, no depende de la conexión).

**Hipótesis del jumper de alimentación USB: investigada y DEBILITADA.** El esquemático
oficial de Makerbase para la variante con chip STM32F407 (la nuestra) muestra un
circuito pasivo de diodo-OR, sin jumper selector. El jumper que menciona la comunidad es
de la variante V1.2 (chip STM32F103, distinto al nuestro). Como nuestra placa es una
combinación no estándar (rotulada "V1.2" por Hellbot, chip F407 real), no se descarta
del 100% sin mirar la placa, pero ya no es la pista más prometedora.

**Siguiente paso recomendado, de la investigación de causa raíz:** un hub USB con
alimentación propia entre la netbook y la placa (~10-15 USD, preferir hubs tipo MTT
sobre STT) - mitigación real reportada en la comunidad de Klipper para combinaciones de
host débil + CH340. Fuente:
[MCU lost communication: I'm stumped](https://klipper.discourse.group/t/mcu-lost-communication-im-stumped/21458).

**[CORRECCIÓN IMPORTANTE 2026-10-25, segunda revisión] La hipótesis de autosuspend
queda DEBILITADA con evidencia directa, no solo "sin probar":**

- Se buscó en **todo** el `journalctl -k` de este arranque cualquier mención de
  `suspend`/`autosuspend`/`wakeup` asociada al dispositivo USB de la placa (`2-1.x`):
  **cero resultados**, en ninguno de los 24 eventos de desconexión registrados.
- El patrón real, repetido de forma idéntica en todos los eventos, es: varios
  `usb_serial_generic_read/write_bulk_callback - urb stopped: -32` (falla de
  transferencia USB, código EPIPE) seguidos INMEDIATAMENTE de `USB disconnect,
  device number N` y una re-enumeración completa como dispositivo NUEVO (`device
  number N+1`). Esto es la firma de una **desconexión eléctrica/de protocolo real**,
  no de una suspensión de energía por software (que mostraría mensajes de
  "auto-suspend"/"wakeup" sin cambiar el número de dispositivo).
- Se verificó además que `power/control` de este dispositivo ya está en `on`
  (autosuspend efectivamente desactivado a nivel de runtime) en el momento actual, y
  las desconexiones siguen pasando igual.

**Conclusión honesta:** instalar la regla udev de autosuspend (que sigue preparada,
más abajo) probablemente **no** va a resolver este problema específico - esa regla
ataca la suspensión de energía por software, y la evidencia dice que no es eso lo que
está pasando. Se deja preparada igual (es gratis, no hace daño, y descarta esa vía por
completo una vez instalada), pero **la expectativa realista es que no cambie nada**. La
pista más consistente con la evidencia real (urb stopped + disconnect duro) sigue
siendo: alimentación eléctrica inestable (de la placa o del puerto), o el chip CH340 en
sí. La diferencia entre "falta persistencia de nombre/permisos" (lo que soluciona
`/dev/serial/by-id`, ya en uso) y "una desconexión eléctrica real" (lo que estamos
viendo) importa acá: no es un problema de que el sistema no reconozca el dispositivo,
es que el dispositivo se CAE de verdad.

Comando para instalarla igual, por las dudas (no hace daño, pero no esperar milagros):

```bash
cd ~/printer_data/config && sudo cp tools/99-usb-no-autosuspend-ch340.rules /etc/udev/rules.d/ && sudo udevadm control --reload-rules && sudo udevadm trigger
```

### Tabla de hipótesis (actualizada 2026-10-25, segunda revisión)

| Hipótesis | Evidencia a favor | Evidencia en contra | Prueba realizada | Resultado |
|---|---|---|---|---|
| Cable USB defectuoso | — | Desconexiones iguales con cable nuevo | Usuario cambió el cable | Descartada |
| Puerto USB específico de la netbook | — | Desconexiones iguales con puerto nuevo (`2-1.1` → `2-1.2`) | Usuario cambió el puerto | Descartada |
| Jumper de alimentación USB mal puesto | Síntoma coincide con lo documentado para la V1.2 | Esquemático oficial del chip F407 (el nuestro) no tiene jumper, es diodo-OR pasivo | Investigación de esquemático oficial | Debilitada, no confirmada ni descartada al 100% (placa no estándar) |
| **Autosuspend USB de Linux** | Causa conocida en laptops, en general | **Cero menciones de "suspend" en todo el log de 24 eventos; `power/control` ya en `on`; patrón de log es desconexión dura, no suspensión** | Búsqueda exhaustiva en `journalctl -k`, verificación de `power/control` | **Debilitada con evidencia directa** - probablemente no es esto |
| Las desconexiones las dispara el USO activo (G28, comandos) | — | 5 ciclos de G28 consecutivos con 0 desconexiones nuevas; la de 20:12:11 pasó en inactividad | Correlación de timestamps `journalctl -k` vs `gcode_store` | Descartada - no correlaciona con actividad |
| CH340/controlador EHCI de la netbook, combinación débil de fábrica | Precedente real documentado en la comunidad; patrón de log (urb stopped -32 + disconnect duro) consistente con falla eléctrica/de silicio, no con software | — | Ninguna prueba discriminante propia todavía (necesitaría probar la placa en otra computadora) | **Hipótesis más fuerte actual** |
| Alimentación general de la placa (fuente/cable de 12-24V, no el jumper) | Podría explicar la desconexión dura observada | Sin patrón horario/térmico claro todavía | Ninguna todavía | Sin evaluar, segunda hipótesis más fuerte |

**Datos de estabilidad reales de esta sesión (no se cuentan solo históricos, se midió
en vivo):** racha más larga sin desconexiones: **36 minutos 49 segundos** (19:35:22 a
20:12:11), atravesando varios restarts de Klipper y pruebas de macros - después volvió
a caer, con la misma firma de siempre (urb stopped -32 + disconnect duro). Total de
desconexiones en este arranque: **24**. No se declara el problema resuelto ni mejorado
de forma sostenida - 36 minutos es el hueco más largo visto hoy, pero hubo huecos de
10-15 minutos antes también, así que es dentro del rango de variación normal del
problema, no necesariamente una mejora real.

**Siguiente prueba discriminante recomendada, dado que autosuspend quedó débil:** un
hub USB con alimentación propia sigue siendo el experimento más informativo y de
menor costo (~10-15 USD) - si las desconexiones PARAN con el hub, aísla el problema al
lado de la alimentación/puerto de la netbook; si SIGUEN igual con el hub, aísla el
problema al lado de la placa/cable de la impresora. No se declara esto "la solución"
de antemano - es la prueba que mejor separa las dos hipótesis más fuertes que quedan.

**Siguiente prueba discriminante pendiente:** correr la regla udev (arriba) y medir si cambia la frecuencia de desconexiones en una ventana de observación larga (horas, no minutos) - eso sí distinguiría "es autosuspend" de "no es autosuspend, es otra cosa".

## Nota técnica: doble color / purga (2026-10-25)

Esta impresora es "2 motores -> 1 hotend" (NO es un IDEX de dos boquillas, y NO es el
sistema AMS de Bambu Lab - no hay buffer externo de filamento ni cámara de mezcla con
sensor). Dos consecuencias concretas para copiar ideas de Bambu:

- **No aplica "temperatura de standby" del extrusor inactivo** (eso es de impresoras con
  dos boquillas separadas). Acá ambos extrusores comparten el mismo bloque calefactor -
  investigado y descartado como mejora real para esta arquitectura.
- **Lo que SÍ aplica y es análogo a la "purga" de Bambu:** el macro T0/T1 ya hace lo
  correcto a nivel mecánico (retrae 80mm el que se apaga, sincroniza el nuevo motor,
  ceba 80mm) - eso NO se toca, está medido a la distancia física real del punto de unión
  de los dos caminos de filamento en el hotend. Lo que falta es la purga VISIBLE que
  elimina la mezcla de color en la pieza real, y eso se configura en el laminador, no en
  la placa: **Prime Tower / Wipe Tower de OrcaSlicer** (`Impresora -> Multimaterial ->
  Prime Tower`). Activarlo, empezar con `Prime Volume` en 45mm³ (default) y subir si
  sigue saliendo mezcla de color, bajar si sobra material. `Tool Change on Wipe Tower`
  es para impresoras con múltiples cabezales (Type 2) - NO aplica aquí, dejarlo
  desactivado.
  Fuente: [OrcaSlicer Wiki - Prime Tower](https://www.orcaslicer.com/wiki/print_settings/multimaterial/multimaterial_settings_prime_tower)

### Distancia de `_FORM_TIP` y calibración completa del extrusor dual (2026-10-25)

**A qué corresponde el "~150mm" del repo de referencia:** en `FacuM/hellbot-wanhao-300-dual-klipper`
probaron en la práctica que retraer 80-90mm dejaba un hilo colgando que atascaba el
splitter en Y, y subieron a ~150mm - esa distancia es la que recorre el filamento desde
la punta ya formada (fuera del hotend) hasta un punto de "aparcado" seguro, lejos del
punto de unión de los dos caminos. **No es una distancia universal**: depende de la
geometría exacta de SU splitter/heatbreak, que no es necesariamente igual al nuestro,
aunque la placa y el pinout de `extruder1` coincidan. Nuestro 80mm actual en T0/T1 está
verificado para el swap rápido (confirmado por el usuario con medición física directa
del punto de unión real de esta máquina) - pero eso es distinto de un ciclo de
"formar punta + aparcar por un rato" como hace `_FORM_TIP`, que todavía no se probó.
**No se sube el valor a 150mm a ciegas** - la `distance` de `_FORM_TIP` sigue en 80mm con
la advertencia ya agregada, pendiente de la prueba real con hotend caliente.

### Guía completa de calibración del extrusor dual (preparada, pendiente de ejecución física)

Procedimiento recomendado, en orden, la próxima vez que haya supervisión con hotend
caliente disponible:

1. **Sentido de giro de cada motor** - ya verificado en fases anteriores del proyecto
   (sin necesidad de repetir). Ver BITACORA.md.
2. **Pasos/distancia de extrusión (`rotation_distance`)** - ya medido y calibrado por
   separado para T0 (7.474) y T1 (7.848). No recalibrar sin un motivo concreto (ej. si
   se cambia el motor o el engranaje).
3. **Flujo real vs temperatura** - pendiente: prueba de caudal máximo (aumentar
   `M106`/velocidad de extrusión hasta que se note "clicking" del motor por salto de
   pasos = se llegó al límite de flujo del hotend a esa temperatura). Determina
   `max_extrude_cross_section`/velocidad de impresión realista.
4. **Retracción y recuperación** - `[firmware_retraction]` ya tiene valores de partida
   (`retract_length: 3`), falta la torre de retracción real para afinarlo.
5. **Pressure Advance** - procedimiento ya documentado arriba, por separado para T0 y
   T1 (son motores distintos).
6. **Carga/descarga y selección T0/T1** - macros ya existen y están auditadas (orden de
   retracción/sync/purga correcto, sin riesgo de movimiento simultáneo - ver
   BITACORA.md, auditoría de línea por línea 2026-10-25).
7. **`_FORM_TIP` para prevenir atascos en el splitter** - preparado, con la advertencia
   de distancia de arriba, pendiente de probar con hotend caliente antes de conectarlo
   al flujo real de T0/T1.
8. **Sensores de filamento** - confirmados presentes y leyendo coherente (sin
   filamento = `filament_detected: false`), falta probar que detecten correctamente
   AL CARGAR filamento real (prueba física simple, sin riesgo).

## Nota técnica: Pressure Advance (2026-10-25)

Klipper no tiene un macro de auto-calibración de PA (a diferencia de `PID_CALIBRATE`).
El procedimiento es: imprimir un patrón de prueba (esquinas/línea recta a velocidad
variable) y ajustar a ojo buscando que desaparezca el "bulto" en esquinas sin que
aparezca hueco. Comando para probar un valor en caliente, sin reiniciar:

```
SET_PRESSURE_ADVANCE EXTRUDER=extruder ADVANCE=0.05   # para T0
SET_PRESSURE_ADVANCE EXTRUDER=extruder1 ADVANCE=0.05  # para T1
```

**Importante para esta impresora en particular:** T0 y T1 son motores físicamente
distintos (ya se midió que tienen `rotation_distance` distinto: 7.474 vs 7.848) aunque
comparten hotend - probablemente necesiten un `ADVANCE` distinto cada uno. No asumir que
calibrar uno sirve para el otro.

**Ojo con cómo se guarda:** `[extruder_stepper]` (T1) NO acepta `pressure_advance` como
opción de config fija - esa opción solo existe en `[extruder]` (T0). Para T0 sí se puede
guardar directo:

```
[extruder]
pressure_advance: 0.05        # agregar la línea con el valor medido para T0
```

Para T1, como no hay dónde guardarlo de forma fija, hay que reaplicarlo cada vez que
Klipper arranca, con un `[delayed_gcode]`:

```
[delayed_gcode SET_PA_EXTRUDER1]
initial_duration: 1
gcode:
    SET_PRESSURE_ADVANCE EXTRUDER=extruder1 ADVANCE=0.05   # valor medido para T1
```

## Nota técnica: ¿ESP32 como MCU adicional? (investigado 2026-10-25 - NO recomendado)

Se investigó si un ESP32 podía usarse como MCU adicional de Klipper (para acelerómetro,
sensores extra, etc). **Conclusión: no está soportado oficialmente y no conviene.**

- El código fuente oficial de Klipper (`Klipper3d/klipper/src/`) solo tiene arquitecturas
  para `avr, atsam, atsamd, stm32, lpc176x, hc32f460, pru, ar100, rp2040, linux` - **no
  hay `esp32`**. El pedido de soporte lleva abierto desde 2018
  ([issue #199](https://github.com/Klipper3d/klipper/issues/199)) sin resolverse, porque
  el ESP32 corre FreeRTOS/ESP-IDF, que choca con el timing determinista que Klipper
  necesita para steppers y sensores.
- Existen forks NO oficiales (`nikhil-robinson/klipper_esp32`, `fermino/klipper-esp32-port`)
  que ellos mismos advierten: "no soportado por el proyecto", "no estable", "bajo tu
  propio riesgo". No es apto para esto.
- No hay ninguna integración ESP32 documentada específicamente para MKS Robin Nano (la
  "MKS TinyBee" es una placa DISTINTA que usa ESP32 como MCU principal, no como add-on,
  y tampoco tiene buen soporte real).

**Para todo lo que se quería usar el ESP32 (acelerómetro, sensores extra), la opción
correcta es la Raspberry Pi Pico** - ver sección siguiente.

Fuentes: [Klipper src/](https://github.com/Klipper3d/klipper/tree/master/src),
[issue #199](https://github.com/Klipper3d/klipper/issues/199),
[Discourse: why ESP32 not compatible](https://klipper.discourse.group/t/why-is-klipper-not-compatible-with-esp32/12231)

### Comparación final ESP32 vs Raspberry Pi Pico (2026-10-25)

| | Para medir vibraciones (Input Shaper) | Para automatización independiente (fuera de Klipper) |
|---|---|---|
| **Raspberry Pi Pico** | **Sí, es la opción correcta.** Soporte oficial de Klipper, USB directo, firmware maduro, es literalmente lo que la documentación oficial recomienda para el ADXL345. | No tiene sentido para esto - es un microcontrolador sin WiFi, pensado para ser un MCU de Klipper, no para automatizaciones independientes. |
| **ESP32** | **No.** Ya investigado y confirmado: no hay soporte oficial, solo forks marcados por sus propios autores como "no aptos para producción". Usarlo para algo que necesita muestreo de hasta 3200Hz con jitter mínimo (como mide el acelerómetro) es justamente donde más se nota la falta de timing determinista de FreeRTOS/ESP-IDF. | **Ahí sí tiene sentido real**, pero como dispositivo TOTALMENTE separado de Klipper, no como su MCU. El ESP32 es un microcontrolador WiFi capaz, bueno para cosas que NO necesitan sincronización de reloj con los steppers: por ejemplo, un enchufe/relé inteligente para cortar la alimentación de la impresora a distancia, una cámara de monitoreo de impresión, un sensor ambiental (temperatura/humedad del cuarto) que reporte por MQTT/HTTP. Nada de esto se comunica con Klipper como MCU - sería un proyecto aparte, opcionalmente leído por Moonraker/Mainsail como un servicio externo si se quisiera integrar visualmente. |

**Conclusión:** no se recomienda comprar un ESP32 ahora - no hay una necesidad concreta
identificada para ese rol de automatización independiente en este proyecto (no se pidió
cámara, ni enchufe remoto, ni sensores ambientales). Si en el futuro aparece una de esas
necesidades puntuales, ahí sí un ESP32 barato (~5 USD) sería una compra razonable - pero
no antes de tener ese caso de uso real. Para vibraciones, la única opción es el Pico.

## Nota técnica: Input Shaper y acelerómetro (investigado 2026-10-25, para el futuro)

El Input Shaper de Klipper usa datos de un **acelerómetro**, conectado como "MCU
adicional" corriendo su propio firmware Klipper (NO reemplaza al MCU principal Robin
Nano, se suma). El giroscopio **no** es parte del flujo estándar de Input Shaper - sería
una integración no estándar/DIY para otro propósito, no algo documentado oficialmente.

**Acelerómetros realmente soportados por Klipper** (`Config_Reference.html`): ADXL345
(el más probado por la comunidad), familia MPU-9250/9255/6515/6050/6500, ICM20948,
LIS2DW, LIS3DH, BMI160.

**MCU adicional recomendada: Raspberry Pi Pico** (no ESP32, ver nota arriba). El ADXL345/
LIS2DW/LIS3DH/BMI160 van por SPI al Pico (USB al host); los de la familia MPU/ICM van
por I2C. Costo orientativo de referencia comunitaria (no precio de tienda local):
breakout ADXL345 ≈ 3-8 USD, Pico ≈ 4-5 USD.

**Montaje:** el sensor va en el cabezal (carro X) para medir resonancias de X; para Y, en
una impresora tipo "bed-slinger" (cama que se mueve, como esta Magna 2) se mueve el MISMO
sensor temporalmente a la cama - no hace falta instalarlo por duplicado.

**Carga en este host débil:** el cálculo pesado (FFT) corre en el HOST, no en el Pico -
el Pico solo transmite datos crudos por USB durante el test. Instalar numpy/scipy en un
netbook viejo puede tardar 10-20 minutos y pedir swap, según la doc oficial. El análisis
en sí no es instantáneo en hardware débil - tenerlo en cuenta al planificar la sesión.

Pasos cuando se consiga el hardware:
1. Conseguir un ADXL345 + una Raspberry Pi Pico.
2. Configurar `[mcu pico]` + `[adxl345]` + `[resonance_tester]` en printer.cfg.
3. Montar el acelerómetro en el cabezal (X), y moverlo a la cama para medir Y.
4. Correr `MEASURE_AXES_NOISE`, después `SHAPER_CALIBRATE` - genera CSV y gráficos con
   el shaper/frecuencia recomendados. Los valores se agregan a mano a `[input_shaper]`.
   No copiar valores de otra impresora.

Fuentes: [Measuring Resonances](https://www.klipper3d.org/Measuring_Resonances.html),
[Config Reference](https://www.klipper3d.org/Config_Reference.html),
[Pico + ADXL345 portátil](https://klipper.discourse.group/t/raspberry-pi-pico-adxl345-portable-resonance-measurement/1757)

**Preparado 2026-10-25:** `input-shaper-future.cfg` en la raíz del repo - config
opcional con placeholders, NO incluida en printer.cfg todavía (para que la impresora
siga funcionando sin el Pico). Tiene el procedimiento completo de puesta en marcha
escrito adentro, paso a paso.

## Nota técnica: arquitectura de sonda futura (preparada 2026-10-25)

Investigadas 4 opciones reales (BLTouch genuino, sonda mecánica desmontable tipo
Klicky/Euclid, sonda inductiva genérica, eddy current tipo Cartographer/Beacon) con sus
diferencias de cableado, código (`[bltouch]` vs `[probe]` vs `[probe_eddy_current]`+MCU
propio) y confiabilidad relativa. Detalle completo y fuentes en BITACORA.md.

**Preparado:** `probe-future.cfg` en la raíz del repo - config opcional con placeholders
para `[bltouch]`/`[safe_z_home]`/`[bed_mesh]`/`[screws_tilt_adjust]`, NO incluida en
printer.cfg todavía (mismo pin PA11 que el switch mecánico activo - no pueden coexistir
en la config activa). Tiene el procedimiento completo de puesta en marcha escrito
adentro, paso a paso, incluyendo el cambio exacto que hay que hacer en `[stepper_z]` y
cómo calcular `mesh_min`/`mesh_max` una vez medido el offset real de la sonda que se
compre. Ningún offset ni coordenada está inventado - todos quedan como placeholder.

## Nota técnica: estrategia de velocidad y calidad (2026-10-25)

**Números reales del fabricante (no inventados), fuente:**
[Hellbot - análisis comparativo Magna 2 230/Dual](https://blog.hellbot.xyz/analisis-comparativo-magna-2-230-magna-1-y-magna-dual/):
velocidad máxima documentada 80mm/s, **velocidad recomendada 50mm/s**, altura de capa
0.1-0.4mm.

**Importante, para no confundir dos cosas distintas:** `max_velocity: 250` en
`[printer]` de nuestro printer.cfg es un **techo de seguridad del firmware** (Klipper
nunca lo va a superar, pase lo que pase), NO una velocidad de impresión real. La
velocidad real la define el LAMINADOR (OrcaSlicer/Cura), muy por debajo de ese techo.
No hay conflicto entre el techo de 250mm/s y la recomendación de fábrica de 50mm/s -
simplemente hay mucho margen entre el límite de seguridad y la velocidad real de
impresión, que es como debe ser.

**Estrategia recomendada, en orden, antes de subir velocidades:**
1. Primera impresión de prueba a velocidad conservadora (50mm/s, el valor recomendado
   de fábrica) una vez resuelta la estabilidad de USB.
2. Pressure Advance calibrado (afecta mucho más a la calidad en esquinas/puentes que la
   velocidad en sí).
3. Retracción (`[firmware_retraction]`) calibrada.
4. Solo después de tener una impresión limpia y repetible a 50mm/s, subir
   gradualmente hacia el máximo de fábrica (80mm/s), comparando calidad en cada escalón
   - no saltar directo a un valor alto sin comparar.
5. Input Shaper (cuando haya acelerómetro) permite velocidades/aceleraciones más altas
   sin ringing - hasta entonces, no forzar aceleraciones altas a ciegas.

**No se declara ninguna velocidad "soportada" sin esa prueba escalonada real.**

## Nota técnica: YUMI_PLR - recuperación ante corte de energía (investigado 2026-10-25)

Repo real confirmado: [Yumi-Lab/YUMI_PLR](https://github.com/Yumi-Lab/YUMI_PLR). Guarda
el archivo/altura Z actual (`SAVE_VARIABLE` + macro `LOG_Z` llamada desde el "before
layer change" del laminador) y expone `RESUME_INTERRUPTED` en Mainsail tras un corte.
**Limitación del propio plugin: solo funciona si el eje Z no se movió durante el
corte** (si la cama/cabezal se desplazó mecánicamente sin energía, la recuperación no
es confiable).

**Precisión sobre el problema del usuario "pi" (investigado a fondo, no es exactamente
lo que se pensaba):** el instalador (`install.sh`) en realidad SÍ detecta el usuario
real del sistema correctamente (por `$USER`/`$SUDO_USER`), no está hardcodeado a "pi"
como se creía. El problema real está en el archivo `plr.cfg` que ese instalador copia
tal cual, sin reemplazar rutas: tiene 3 líneas con `/home/pi/...` escritas a mano
(`clear_plr.sh`, `plr.sh`, `variables.cfg`). Hay que editarlas a mano a `/home/facundo/...`
después de instalar - no es necesario parchear el instalador, alcanza con corregir esas
3 líneas en `plr.cfg`. **No instalado todavía** - instalar software nuevo de un repo
externo es una acción más grande que ajustar configs ya presentes, se deja preparado
para decidir conscientemente, no se instala solo.

### Decisión recomendada (2026-10-25): diferir, no instalar todavía

**Recomendación: esperar, no instalar ahora.** Razón concreta: YUMI_PLR protege contra
un corte de luz, pero el problema que está interrumpiendo impresiones en este momento
no es la luz - es la desconexión USB intermitente (24 eventos registrados hoy, causa
todavía sin confirmar). Si una impresión se corta por USB mientras el eje Z sigue
energizado y en su lugar (que es lo más probable en una desconexión de comunicación,
no de corte eléctrico), YUMI_PLR debería poder ayudar en teoría - pero instalar y
confiar en un sistema de recuperación ANTES de resolver la causa que más seguido está
arruinando las impresiones es resolver el síntoma secundario antes que el primario.
Además, agrega superficie nueva (shell commands, variables guardadas, G-code adicional
en cada layer-change) a un sistema que todavía se está estabilizando.

**Cuándo tendría sentido instalarlo:** una vez que la inestabilidad de USB esté
resuelta o mitigada (hub alimentado probado, por ejemplo), y si en ese momento sigue
habiendo cortes de luz reales (de la pared, no de comunicación) que justifiquen la
protección. No es una tarea urgente ni bloqueante para nada más del plan.

## Nota técnica: plan de hardware priorizado (2026-10-25)

**A. Se puede completar ahora sin comprar nada:**
- Afinar Pressure Advance, retracción, velocidad (una vez resuelta la estabilidad USB).
- Probar `_FORM_TIP` y conectarlo a T0/T1 si da buen resultado.
- Instalar la regla udev del USB (gratis, ya preparada).
- Instalar YUMI_PLR (gratis, requiere editar 3 líneas de un archivo tras clonar el repo).

**B. Reparación/verificación de hardware existente:**
- Sonda "3D Touch": diagnóstico de hardware confirmado roto - reparar (abrir y revisar
  cable/sensor interno) o reemplazar.
- Inspección visual rápida de la zona del conector USB en la placa (gratis, para
  descartar del todo la hipótesis del jumper).

**C. Componentes opcionales con mejora real, por prioridad:**
1. **Hub USB con alimentación propia** (~10-15 USD) - mitigación más prometedora para
   la inestabilidad de comunicación, costo bajo.
2. **BLTouch genuino** (reemplazo directo del clon roto, mismo conector) - para
   recuperar nivelación automática real. Costo variable según proveedor, no se
   respalda un precio específico sin cotizar.
3. **Raspberry Pi Pico + ADXL345** (~8-13 USD en conjunto, referencia comunitaria) -
   para Input Shaper, mejora velocidad sin sacrificar calidad.
4. **Sonda mecánica desmontable (Klicky/Euclid)** - alternativa a BLTouch si se busca
   evitar el punto de falla del solenoide, pero necesita imprimir un dock y sumar
   macros propias - más trabajo de puesta en marcha que un BLTouch genuino.

No se recomienda ESP32 para ningún rol dentro de Klipper (ya investigado y descartado).
No se recomienda eddy current (Cartographer/Beacon) para esta máquina - mucho más caro
y complejo de lo que esta impresora necesita.

## Comandos útiles

```bash
# Ver logs de Klipper
tail -f ~/printer_data/logs/klippy.log

# Reiniciar Klipper (recarga printer.cfg)
curl -X POST http://localhost:7125/printer/restart

# Reiniciar el firmware del MCU (tras un shutdown)
curl -X POST http://localhost:7125/printer/firmware_restart

# Reiniciar el servicio completo (si lo anterior no alcanza)
sudo systemctl restart klipper

# Ver estado de la placa
curl -s http://localhost:7125/printer/info

# Historial de git de la config
cd ~/printer_data/config && git log --oneline
```

## Cómo recuperarse de problemas comunes

- **"Lost communication with MCU"**: revisar cable USB, `ls /dev/serial/by-id/`. Si el
  dispositivo desapareció y volvió, correr `firmware_restart` o
  `sudo systemctl restart klipper`.
- **Placa no responde tras reflashear**: verificar que se usó `klipper.bin` directo,
  NO el convertido con `update_mks_robin.py` (ver sección del bug arriba).
- **Motores no se mueven / no homean tras estar mucho tiempo sin actividad**: es el
  idle_timeout (10 min), rehomear con `G28`.
