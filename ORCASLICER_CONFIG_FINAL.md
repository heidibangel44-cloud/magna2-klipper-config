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

## Conexión Wi-Fi, subida de archivos y control desde Mainsail

**Conectar Orca a la impresora (una sola vez):**
1. Al lado del selector de impresora (arriba a la izquierda) hay un botón para
   abrir **"Physical Printer"** (impresora física).
2. `Host Type`: elegir **`Octo/Klipper`** (es el tipo que usa Orca para
   Moonraker, aunque la placa no tenga nada de Octoprint).
3. `Hostname/IP/URL`: la URL de Moonraker de la tabla de arriba (misma red:
   `http://192.168.18.196`; con Tailscale activo en la Dell:
   `http://facundo-cx215xx-cx212xx.tailf92613.ts.net`). Sin el puerto `:7125` -
   ese host type ya lo asume.
4. `API Key`: dejar vacío (Moonraker está configurado en `trusted_clients` para
   la red local y para el rango de Tailscale - no pide key).
5. `Device UI` (opcional, para que el botón "ver impresora" de Orca abra
   Mainsail): la misma URL sin puerto, ej. `http://192.168.18.196`.
6. Botón **`Test`** - tiene que confirmar conexión antes de guardar.

**Mandar a imprimir (ya conectado):** el botón de subir/imprimir está arriba a
la derecha de la ventana de Orca (ícono de impresora, al lado de "Slice"/
"Export"). Al tocarlo, Orca sube el .gcode directo a Moonraker.

**Dónde "quedan guardados" los archivos:** no hace falta configurar ninguna
carpeta nueva - Moonraker los guarda en la MISMA carpeta que ya lee Mainsail
(`~/printer_data/gcodes`). Apenas Orca termina de subir uno, aparece solo en la
pestaña **"G-Code Files"** de Mainsail, con nombre y fecha, listo para
seleccionar y tocar **"Print"** desde ahí (sin tener que volver a tocar la
netbook ni Orca).

**Miniatura (thumbnail) de la pieza en Mainsail:** en Orca, ir a
`Printer Settings` → `Basic information` → campo **`G-code thumbnails`** y
poner `32x32, 400x300` (formato PNG). El `G-code flavor` tiene que seguir en
`Klipper` (ya está así). Con eso, cada archivo subido lleva su miniatura
incrustada: Mainsail muestra la chica (32x32) en la lista de archivos y la
grande (400x300) en el cartel de confirmación al tocar "Print" - no hay nada
que configurar del lado de Mainsail, la lee sola del .gcode.

**Cambiar temperatura u otros parámetros desde Mainsail (sin tocar la
netbook):** en el panel principal de Mainsail (Dashboard), las cajitas de
temperatura del hotend y la cama arriba se pueden editar en cualquier momento,
imprimiendo o no - tocar el número, escribir el nuevo valor, Enter. Mientras
hay una impresión corriendo aparece además una pestaña **"Tune"** al lado de
"General"/"Console" en el panel de estado, con control en vivo de velocidad
(speed factor), flujo (flow), ventilador y micro-ajuste de Z (babystepping) -
todo esto se puede hacer desde el celular con Tailscale conectado, igual que
desde cualquier PC en la red.

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
| Retracción - distancia | 3mm | **Confirmado** (viene de Klipper, con firmware retraction activada el valor de Klipper es el que manda - poner este número en Orca solo para que la vista previa no mienta). Ver procedimiento de recalibración abajo |
| Retracción - velocidad | 40mm/s | **Confirmado**, idem |
| Flow ratio inicial | 1.0 (100%) | Valor inicial recomendado - **necesita calibración física** (ver orden de calibración abajo) |
| Pressure Advance | 0.0 actual | **Necesita calibración física** (torre real) - esperable que termine más alto que en una impresora de un solo extrusor, por el volumen del splitter compartido. Ver procedimiento abajo |
| Caudal volumétrico máximo inicial prudente | 6-8 mm³/s | Valor inicial prudente - **necesita calibración física** (prueba de flow rate) para confirmar el límite real de este hotend |

## Calibración de Pressure Advance y retracción (procedimiento real)

Las dos se hacen con el asistente integrado de Orca (menú **`Calibration`** en
la barra superior) - imprimen una pieza de prueba real y vos leés el resultado
a ojo, no hay forma de "calcular" el número sin imprimir. Orden recomendado
(cada paso depende del anterior): **Temperatura → Flow Rate → Pressure
Advance → Max Volumetric Speed → Retracción** (así lo documenta la propia guía
de Orca). Como la temperatura (210°C) y un flow inicial de 1.0 ya están
confirmados con filamento real, se puede arrancar directo por Pressure
Advance.

### 1. Pressure Advance

1. `Calibration` → `Pressure Advance` → método **`PA Pattern`** (el más simple
   de leer; `PA Tower`/`PA Line` son alternativas del mismo asistente).
2. Orca arma sola la pieza de prueba con varios valores de PA uno al lado del
   otro - solo tocar `Slice` y mandarla a imprimir (con el flujo de subida de
   arriba).
3. Mirar la pieza impresa: cada franja tiene al lado el valor de PA que usó.
   Elegir la franja con las esquinas más filosas y sin bulto/hueco en las
   juntas (ni muy redondeada - poco PA -, ni con bulto en la esquina - mucho
   PA).
4. **Aplicar el valor ganador:** en Orca, `Filament Settings` → pestaña
   `Advanced` → activar y escribir el número en **`Pressure advance`**. Orca
   manda automáticamente `SET_PRESSURE_ADVANCE` al principio de cada
   impresión que use ese perfil de filamento - no hay que tocar `printer.cfg`
   para esto.

### 2. Retracción fina

1. `Calibration` → `Retraction Test`. Configurar el rango: inicio 0mm, fin
   3-4mm (ya arrancamos en 3mm), paso 0.2mm - este extrusor es de engranaje
   directo (sin caja reductora) compartiendo un hotend con splitter, así que
   el punto óptimo real puede no coincidir con el típico de un extrusor
   directo "normal".
2. Imprimir la torre. Mirar los hilos/pelos entre las dos columnas en cada
   altura: mucho hilo = falta retracción (subir), huecos o puntos débiles en el
   reinicio = demasiada retracción (bajar). Elegir la altura con menos hilos
   sin huecos.
3. **Aplicar el valor ganador - OJO con esto:** como tenemos
   `firmware_retraction` activada en Klipper, lo que se imprime normalmente
   usa el valor que vive en `printer.cfg` (`[firmware_retraction]`), NO lo que
   esté tipeado en Orca. Escribir el número en Orca después de este test solo
   mantiene la vista previa honesta. **Avisar el número ganador en el chat de
   la netbook** para actualizar `retract_length`/`retract_speed` en
   `printer.cfg` - sin ese paso, el resultado del test no se aplica a
   impresiones reales.

Fuentes: [Guía de calibración oficial de OrcaSlicer](https://www.orcaslicer.com/wiki/guides/calibration_guide),
[Printago - guía de calibración](https://printago.io/guides/orca-slicer-calibration),
[orcaslicers.co - calibración de retracción](https://orcaslicers.co/wiki/calibration/retraction/).

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

Tailscale y la cámara (crowsnest) ya están instalados y probados en la netbook -
esto es para usarlos desde OTRO dispositivo (celular, otra red).

**Ver la cámara/Mainsail desde el celular (datos móviles o cualquier Wi-Fi, no
solo la red de casa):**
1. Instalar la app **Tailscale** (Play Store / App Store).
2. Iniciar sesión con la MISMA cuenta de Tailscale que se usó en la netbook.
3. Activar el switch de conexión de la app (queda conectado en segundo plano).
4. Abrir el navegador del celular y entrar a
   `http://facundo-cx215xx-cx212xx.tailf92613.ts.net` - abre Mainsail entero,
   con la cámara ya integrada en el dashboard. Para solo la imagen de la
   cámara, sin el resto de la interfaz:
   `http://facundo-cx215xx-cx212xx.tailf92613.ts.net/webcam/?action=stream`.

**Ver la netbook desde otra PC/red (no solo el celular):** mismo mecanismo -
instalar Tailscale en esa PC, loguearse con la misma cuenta, usar la misma URL
de arriba. No hace falta abrir puertos en el router ni exponer nada a
Internet - Tailscale crea una red privada entre los dispositivos logueados con
esa cuenta.

No se repiten acá los datos de IP local/puerto Moonraker - están en la tabla
de arriba y en `DATOS_PARA_ORCASLICER.md`.
