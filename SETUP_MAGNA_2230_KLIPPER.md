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

- **Host:** Linux Mint 22.3, en esta netbook (Intel Celeron B820, 5.7GB RAM)
- **Klipper:** instalado vía KIAUH, compilado localmente (toolchain ARM instalado)
- **Moonraker + Mainsail:** instalados vía KIAUH
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
  (192.168.18.0/24), bloqueado desde internet por firewall (ufw activo).
- **Moonraker API:** `http://192.168.18.196:7125`
- **API key de Moonraker:** ver con `curl http://localhost:7125/access/api_key`
  (no compartir públicamente, da control de la impresora)
- **Puerto serie:** `/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0` (ruta estable,
  no usar `/dev/ttyUSB0` que puede cambiar de número)

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

- [ ] Primera impresión de prueba estable (requiere confirmar que el USB ya no se
      desconecta - ver "Nota técnica: estabilidad USB" abajo)
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

## Nota técnica: estabilidad USB (hallazgo 2026-10-25)

Se encontró evidencia real (`journalctl -k`) de desconexiones físicas del USB del CH340
(reconecta solo segundos después, a veces en menos de 1 segundo) que tiran a Klipper a
shutdown y borran el homing - esto explica buena parte de la sensación de "la altura
cambia sola": en realidad la impresora se cayó y el usuario sigue nivelando sobre un
estado inválido. No es (solo) un problema mecánico de Z. Pendiente: confirmar con cable/
puerto USB distinto si el problema para. Regla udev preparada para evitar que el sistema
suspenda ese puerto (ver sección de Acceso/Comandos).

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
