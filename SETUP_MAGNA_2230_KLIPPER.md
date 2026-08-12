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

- [ ] Configurar Cura y OrcaSlicer en la otra PC del usuario (perfiles oficiales de
      Hellbot ya entregados para Cura: PLA/ABS/PETG "Magna 2 230 Dual"; OrcaSlicer
      necesita perfil manual con G-code flavor = Klipper)
- [ ] Primera impresión de prueba
- [ ] Pressure advance (necesita impresión de prueba)
- [ ] Afinar velocidad/aceleración con Klipper (partiendo de los valores conservadores
      del fabricante: 45mm/s impresión, 30mm/s paredes)
- [ ] Recuperación por corte de energía (YUMI_PLR — requiere G-code de slicer configurado
      primero, y ajustar el instalador que asume usuario `pi` en vez de `facundo`)
- [ ] Reemplazar o reparar el sensor "3D Touch", retomar bed_mesh automático
- [ ] Subir el `max_temp` del hotend una vez confirmada la modificación del PTFE
- [ ] Backup remoto en GitHub (opcional, decisión del usuario)
- [ ] Corregir el bug de `update_mks_robin.py` en el repo de GitHub
      (`heidibangel44-cloud/magna-klipper`)
- [ ] Input Shaper — pendiente de hardware futuro (acelerómetro ADXL345 vía Arduino/Pico
      como MCU adicional). **No hay valores de resonancia inventados acá** — se miden
      recién cuando el sensor físico esté disponible. Ver nota técnica abajo.

## Nota técnica: Input Shaper y acelerómetro (para el futuro)

El Input Shaper de Klipper usa datos de un **acelerómetro** (típicamente ADXL345),
conectado como "MCU adicional" corriendo su propio firmware Klipper — puede ser un
Arduino o una Raspberry Pi Pico dedicados a esto, no reemplazan al MCU principal
(Robin Nano), se suman. El giroscopio (si se llegara a agregar) **no** es parte del
flujo estándar de Input Shaper de Klipper — sería una integración no estándar/DIY para
otro propósito (orientación, vibración), no algo documentado oficialmente.

Pasos cuando se consiga el hardware:
1. Conseguir un ADXL345 (u otro acelerómetro soportado por Klipper) + un Arduino/Pico.
2. Compilar Klipper para ese microcontrolador como "MCU adicional" (`[mcu rpi]` o
   similar, con su propio `serial:`).
3. Montar el acelerómetro físicamente en el cabezal (X) y opcionalmente en la cama (Y).
4. Correr `SHAPER_CALIBRATE` — esto mide las resonancias reales de la máquina y genera
   los valores de `[input_shaper]` automáticamente. No copiar valores de otra impresora.

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
