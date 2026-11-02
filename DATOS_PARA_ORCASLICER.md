# Datos técnicos para configurar OrcaSlicer — Hellbot Magna 2230 Dual

Documento preparado para copiar y pasar directo a la sesión que está terminando
OrcaSlicer en otra PC. Todos los valores están verificados contra el sistema real,
no son genéricos de internet.

## A. Identificación

- Impresora: Hellbot Magna 2 230 Dual (rebrand de Wanhao D12/230 Dual).
- Placa: MKS Robin Nano V1.3, chip real STM32F407VET6 @ 168MHz (confirmado por la
  propia placa).
- Firmware: Klipper v0.13.0-730-g84104bbb.
- Cama: 230 × 230mm. Altura máxima Z: 250mm.
- Boquilla: 0.4mm. Filamento: 1.75mm.
- Extrusión: DOS motores (T0, T1) con splitter en Y hacia UN SOLO hotend/boquilla.
  No es IDEX, no tiene dos boquillas. Ninguno de los dos extrusores tiene caja
  reductora (gear ratio) - son de engranaje directo.

## B. Movimiento (techos reales de Klipper - no superarlos desde el laminador)

| Parámetro | Valor |
|---|---|
| Velocidad máxima X/Y | 500 mm/s (techo de seguridad del firmware, NO velocidad de impresión real) |
| Aceleración máxima X/Y | 500 mm/s² (idem - techo real de fábrica de Marlin para esta máquina) |
| Velocidad máxima Z | 25 mm/s |
| Aceleración máxima Z | 100 mm/s² |

**Velocidades de impresión recomendadas (esto sí es para usar en los perfiles):**
pared exterior 40mm/s, pared interior 50mm/s, relleno 60mm/s, superficie superior
40mm/s, soportes 60mm/s, puentes 25mm/s, desplazamientos 150mm/s, primera capa
20mm/s. Aceleración general 500mm/s² (no subir, pared exterior a 300mm/s² mejora
el acabado). Máximo prudente si se quiere exprimir: 80mm/s (tope real recomendado
por el fabricante Hellbot para esta máquina), nunca el techo de 500.

## C. Extrusión

| | T0 | T1 |
|---|---|---|
| `rotation_distance` | 7.623mm (medido, 0% error) | 7.848mm (medido, 0% error) |
| Pasos por mm | 419.6 | 407.7 |
| Gear ratio | ninguno | ninguno |

- Velocidad máxima de movimiento solo-extrusión: 60mm/s.
- Un solo movimiento de extrusión no puede superar 500mm de longitud (límite de
  seguridad de Klipper) - no debería afectar el laminador normalmente.
- **Pressure Advance: sin calibrar (0.0 actual).** Falta imprimir la torre real.
  Esperable que sea más alto que en una impresora de un solo extrusor normal, por
  el volumen extra del splitter compartido.
- **Retracción: valor de partida 3mm a 40mm/s** (`firmware_retraction` de Klipper,
  aplica a viajes normales sin imprimir). Falta calibrar con torre real.
- **Flow ratio: sin calibrar (1.0 actual).** Falta torre de flujo real.
- Caudal volumétrico: a 80mm/s con 0.4mm de ancho de línea y 0.2mm de capa, se
  necesitan ~6.4mm³/s - dentro del rango típico de un hotend genérico bien
  calibrado (8-12mm³/s), pero sin confirmar con una prueba de flow rate real en
  OrcaSlicer. El motor extrusor NO es un límite a estas velocidades (gira a menos
  de 0.35 rev/s en el peor caso) - si aparece subextrusión, el cuello de botella va
  a ser térmico (el hotend), no el motor.

## D. Materiales (PLA, ya probado)

- Hotend: 210°C (probado hoy, extruye bien).
- Cama: 60°C.
- Altura de capa: 0.2mm para empezar.
- Ancho de línea: 0.4-0.45mm.
- Ventilador de piezas: 100% desde la segunda capa (confirmado funcionando).

## E. G-code - exacto, no modificar

**Start G-code** (reemplaza TODO el G-code de inicio por defecto del laminador):
```
PRINT_START EXTRUDER_TEMP=[nozzle_temperature_initial_layer] BED_TEMP=[bed_temperature_initial_layer]
```

**End G-code** (reemplaza todo el de fin):
```
PRINT_END
```

**Cambio de extrusor/color:** la palabra `T0` o `T1` sola en su propia línea, nada
más. Así cambia físicamente cuál motor empuja filamento (retrae 80mm el que estaba,
sincroniza el nuevo, avanza 80mm) - probado hoy con calor real en las dos
direcciones.

**Comandos que NO hay que usar:** M104/M140/G28 sueltos al inicio (ya los hace
PRINT_START), M84 suelto al final (ya lo hace PRINT_END), cualquier M-code estándar
de cambio de herramienta multi-extrusor (T0/T1 acá son comandos directos, no
necesitan protocolo de offset de posición porque comparten la misma boquilla).

**Particularidad de Klipper a tener en cuenta:** el campo que normalmente reportaría
"qué extrusor está activo" (`toolhead.extruder`) siempre devuelve el mismo valor en
esta máquina sin importar cuál esté realmente activo - si el laminador o algún
plugin intenta leer eso para decidir algo, va a estar mal. No debería ser relevante
para generar G-code, solo para diagnóstico.

## F. Conexión

- IP local actual: `192.168.18.196`
- Nombre local (mDNS): `facundo-cx215xx-cx212xx.local`
- Puerto Moonraker: `7125`
- Puerto Mainsail: `80`
- URL para conectar OrcaSlicer en la misma red: `http://192.168.18.196:7125` (o con
  el nombre `.local`)
- Dirección Tailscale: `100.64.6.13`
- Nombre MagicDNS (fijo, no cambia): `facundo-cx215xx-cx212xx.tailf92613.ts.net`
- URL remota para OrcaSlicer (fuera de la red local, con Tailscale activo en esta PC
  también): `http://facundo-cx215xx-cx212xx.tailf92613.ts.net:7125`
- Estado real probado hoy: confirmado funcionando - Moonraker, Mainsail y la cámara
  responden 200 por la IP de Tailscale y por el nombre MagicDNS. Para que esta PC
  del laminador también pueda usarlo, necesita tener Tailscale instalado y logueado
  con la misma cuenta.

## G. Cámara

- Software: crowsnest (oficial de mainsail-crew).
- URL local del stream: `http://192.168.18.196:8080/?action=stream` (también
  integrada directamente en la interfaz de Mainsail).
- URL de acceso remoto (vía Tailscale, pasando por el proxy de Mainsail, no el
  puerto 8080 directo): `http://facundo-cx215xx-cx212xx.tailf92613.ts.net/webcam/?action=stream`
- Estado: confirmado funcionando, tanto en la red local como por Tailscale, hoy.

## H. Pendientes

- **Necesita prueba física (no se puede hacer desde el chat):** Pressure Advance,
  retracción fina, flow rate real - las tres se calibran imprimiendo una pieza de
  prueba real y mirando el resultado. Usar los asistentes integrados de OrcaSlicer
  para esto (Calibración → Pressure Advance / Retracción / Flow Rate).
- **Para usar la URL remota de Tailscale desde esta PC:** instalar Tailscale en esta
  PC también (app oficial de Windows) y loguearse con la MISMA cuenta que se usó en
  la netbook. Sin eso, desde esta PC solo se puede usar la IP local
  (`192.168.18.196`), que únicamente funciona si las dos máquinas están en la misma
  red WiFi.
- **Primera impresión de prueba:** algo chico (cubo de 20mm, un solo color),
  15-20 minutos, antes de intentar algo largo - hay un historial de desconexiones
  USB sin causa 100% confirmada, mejor confirmar estabilidad con algo corto primero.
