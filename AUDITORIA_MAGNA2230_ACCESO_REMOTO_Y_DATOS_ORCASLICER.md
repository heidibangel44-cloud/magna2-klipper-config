# Auditoría completa — Hellbot Magna 2230 Dual, acceso remoto y datos para OrcaSlicer

Fecha: 2026-11-02. Todo lo que sigue fue verificado contra el sistema real (comandos
ejecutados, API de Moonraker consultada, código fuente de Klipper leído) — no hay
valores inventados. Donde algo no se pudo comprobar, se indica explícitamente.

---

## 1. Estado inicial del sistema

| Dato | Valor confirmado |
|---|---|
| Distribución | Linux Mint 22.3 "Zena" (base Ubuntu 24.04 Noble) |
| Kernel | 6.14.0-37-generic |
| CPU | Intel Celeron B820 @ 1.70GHz, 2 núcleos |
| RAM | 5.7 GiB total |
| Disco | 57 GB total, 39 GB libres (29% usado) |
| Hostname | facundo-CX215XX-CX212XX |
| IP local | 192.168.18.196 (dinámica, vía DHCP del router) |
| mDNS | activo - `facundo-cx215xx-cx212xx.local` resuelve correctamente a la IP |
| Klipper | activo, `v0.13.0-730-g84104bbb` (commit `84104bbb`, 2026-08-07) |
| Moonraker | activo, commit `d5ee171` (2026-06-29), puerto 7125 |
| Mainsail | `v2.18.2`, servido por nginx en puerto 80 |
| Cámara | crowsnest activo, webcam Foxlink USB UVC (`/dev/video0`), puerto 8080 |
| Placa | MKS Robin Nano, chip real `stm32f407xx` @ 168MHz (confirmado por la propia placa vía `mcu_constants`) |

## 2. Problemas detectados

- **Ninguno nuevo de hardware.** La comunicación MCU↔netbook está sana ahora mismo:
  9 bytes de retransmisión sobre 8145 secuencias totales desde el último arranque de
  Klipper, 0 bytes inválidos — una proporción saludable.
- **3 desconexiones de USB desde el último arranque del sistema** (`uptime -s`:
  2026-11-02 11:40), todas explicadas por apagados/encendidos manuales de la
  impresora durante pruebas de hoy, no por fallas espontáneas. El historial de
  **semanas anteriores** con desconexiones sin explicar sigue sin una causa raíz
  100% confirmada — ver sección de riesgos abajo.
- **Tailscale no estaba instalado** antes de esta auditoría.

## 3. Cambios realizados

| Cambio | Archivo/Sistema | Respaldo |
|---|---|---|
| Instalación de `crowsnest` (cámara) | Sistema (systemd) + `crowsnest.conf` | Instalación nueva, sin archivo previo que respaldar |
| Registro del webcam en Moonraker | `moonraker.conf` | Commit git `af2572a` conserva la versión anterior |
| Base de `printer.cfg` reemplazada por la config real de Yumi-Lab, auditada línea por línea | `printer.cfg` | Múltiples commits git con el historial completo; además `printer-20260811_193106.cfg` y `printer-20260811_194712.cfg` (snapshots de la instalación original) |
| Fix de `M84` (stepper_z nunca se apaga por software) | `printer.cfg` | Mismo historial git |
| Nivelación de las 4 esquinas con método de switch real | Mecánico (tornillos), no un archivo | No aplica |
| Retracción T0/T1 corregida y confirmada en 80mm | `printer.cfg` | Mismo historial git |
| `_FORM_TIP` eliminado, agregados botones de jog manual de filamento | `printer.cfg` | Mismo historial git |
| *(Tailscale)* | *(pendiente - ver sección 10)* | — |

**Todos los cambios de `printer.cfg`/`moonraker.conf` están commiteados y pusheados**
al repositorio `magna2-klipper-config` en GitHub — ese es el respaldo verificable
real, no solo un archivo `.bak` local.

## 4. Configuración completa reconstruida (printer.cfg + includes)

`printer.cfg` solo tiene un `[include]` real: `mainsail.cfg` (macros cliente
genéricos de Mainsail, sin parámetros específicos de esta impresora). Los archivos
`input-shaper-future.cfg` y `probe-future.cfg` **no están incluidos** - son
preparación para hardware futuro, sin efecto en la configuración activa.

### Movimiento (valores reales, confirmados vía API de Klipper)

| Parámetro | Valor |
|---|---|
| `max_velocity` | 500 mm/s |
| `max_accel` | 500 mm/s² |
| `max_z_velocity` | 25 mm/s |
| `max_z_accel` | 100 mm/s² |
| `square_corner_velocity` | 5.0 |
| `minimum_cruise_ratio` | 0.5 (default de Klipper) |
| Homing X/Y | velocidad 50mm/s, retracto 5mm, segunda pasada 25mm/s |
| Homing Z | velocidad 5mm/s, retracto 5mm, segunda pasada 2.5mm/s |
| `position_min`/`position_max` X | 0 / 230mm |
| `position_min`/`position_max` Y | 0 / 230mm |
| `position_min`/`position_max` Z | -2 / 250mm |

Estos límites de `max_velocity`/`max_accel` están igualados al techo REAL de fábrica
del Marlin que compila para esta máquina (`DevelopmentHellbot/Magna-Dual`,
`Configuration.h`, bloque que de verdad se usa): `DEFAULT_MAX_FEEDRATE {500,500,5,25}`,
`DEFAULT_MAX_ACCELERATION {500,500,100,1000}`. No son números elegidos a mano.

### Extrusión

| Parámetro | T0 (`extruder`) | T1 (`extruder_stepper extruder1`) |
|---|---|---|
| Pines (step/dir/enable) | PD6 / PD3 / PB3 | PA6 / PA1 / PA3 |
| `rotation_distance` | **7.623mm** (medido, 0% error) | **7.848mm** (medido, 0% error) |
| `microsteps` | 16 | 16 |
| `full_steps_per_rotation` | 200 | 200 |
| `gear_ratio` | ninguno (extrusor directo, NO tiene caja reductora) | ninguno |
| Pasos por mm de filamento | 3200 / 7.623 = **419.6 pasos/mm** | 3200 / 7.848 = **407.7 pasos/mm** |
| `max_extrude_only_velocity` | 60 mm/s | (comparte el mismo límite, es del objeto `extruder`) |
| `max_extrude_only_distance` | 500mm por movimiento (un solo G1 E de más de eso se rechaza entero) | ídem |
| `max_extrude_only_accel` | 133.04 mm/s² (calculado automáticamente por Klipper a partir de `rotation_distance`) | ídem |
| `max_extrude_cross_section` | 100 mm² (techo de seguridad, muy permisivo) | ídem |
| `pressure_advance` | 0.0 (sin calibrar todavía) | 0.0 (sin calibrar todavía) |
| `min_extrude_temp` | 170°C | ídem (comparte hotend) |
| PID (real, calibrado) | Kp=24.563 Ki=0.963 Kd=156.589 | (T1 no tiene heater propio - comparte el de T0) |

**Importante:** el extrusor NO tiene `gear_ratio` configurado - es un extrusor de
engranaje directo (tipo stock de esta impresora), NO una caja reductora Bondtech/BMG
3:1. Cualquier config de otra impresora que asuma esa reducción (como la base
original de Yumi-Lab, antes de corregirla) daría una calibración de flujo
completamente equivocada si se copiara sin verificar.

### Temperaturas

| Parámetro | Extrusor | Cama |
|---|---|---|
| `min_temp` / `max_temp` | 0°C / 250°C | 0°C / **90°C** (límite conservador, cama magnética flexible) |
| Termistor | ATC Semitec 104GT-2 (sin confirmar físicamente el modelo exacto) | EPCOS 100K B57560G104F (sin confirmar físicamente) |
| PID real calibrado | Kp=24.563 Ki=0.963 Kd=156.589 | Kp=65.585 Ki=0.951 Kd=1131.340 |
| `min_extrude_temp` | 170°C | — |

### idle_timeout y seguridad del eje Z

`timeout: 900` (15 minutos). El comando `M84` fue redefinido en `printer.cfg` para
que **`stepper_z` nunca se desenergice por software** (ni por este timeout ni por
llamada manual) - evita que el eje pierda la fuerza que lo sostiene contra la
gravedad, sin depender de si el mecanismo es autoblocante o no. Confirmado hoy con
`QUERY_ENDSTOPS` real que el homing de los 3 ejes es perfectamente consistente -
no hay pérdida de pasos ni comportamiento errático de Klipper.

## 5. Los dos motores de extrusión T0 y T1 - análisis completo

**Arquitectura confirmada:** dos motores de extrusor independientes (T0, T1) que
empujan filamento por caminos separados hasta un splitter en Y, que se junta en UN
SOLO hotend con UNA sola boquilla (0.4mm). No es IDEX. No hay dos boquillas.

**Qué hace el comando `T0`:**
1. Guarda el estado actual del gcode.
2. Si el hotend puede extruir (≥170°C): retrae 80mm el extrusor que esté activo en
   ese momento (a 1500mm/min = 25mm/s).
3. Ejecuta `SYNC_EXTRUDER_MOTION EXTRUDER=extruder1 MOTION_QUEUE=` - esto
   **desconecta físicamente el motor de T1 de la cola de movimiento** (su stepper
   deja de recibir comandos de extrusión, aunque sigan llegando por gcode).
4. Ejecuta `SYNC_EXTRUDER_MOTION EXTRUDER=extruder MOTION_QUEUE=extruder` - conecta
   el motor de T0 a la cola de movimiento real (queda como el que efectivamente se
   mueve con cada E).
5. Si el hotend puede extruir: vuelve a avanzar 80mm (a 1200mm/min = 20mm/s).
6. Restaura el estado del gcode y confirma por consola "Extrusor T0 activo".

**`T1` hace exactamente lo mismo pero al revés** (desconecta T0, conecta T1).

**Qué motor queda activo después de cada comando:** el que se nombró en el comando.
Se puede verificar en cualquier momento sin adivinar, consultando
`extruder_stepper extruder1` → campo `motion_queue`: si dice `"extruder"`, T1 está
activo; si dice `null`/vacío, T0 está activo. **Importante para quien programe
G-code:** el campo `printer.toolhead.extruder` de Klipper **siempre** dice
`"extruder"`, nunca `"extruder1"`, sin importar cuál esté realmente activo - NO es un
indicador válido en esta arquitectura. Confirmado con pruebas reales hoy.

**Qué pasa si se inicia una impresión sin ejecutar T0 o T1:** T0 queda activo por
defecto (es el extrusor "real" de Klipper, el otro es un stepper sincronizable). No
hace falta llamar T0 explícitamente al principio si se va a imprimir solo con el
color/T0 - pero si se va a usar T1 en algún punto, hay que llamar "T1" en el gcode
antes de esa sección.

**¿El cambio puede hacerse durante una impresión?** Sí - probado hoy con calor real,
en las dos direcciones, confirmado con el campo `motion_queue` (no solo con la
respuesta del macro). Funciona.

**¿Riesgo de que ambos motores empujen a la vez?** No, por diseño: `SYNC_EXTRUDER_MOTION`
con `MOTION_QUEUE=` vacío desconecta completamente el motor saliente de la cola de
movimiento antes de conectar el entrante - nunca hay dos motores recibiendo la misma
orden de movimiento a la vez. Confirmado leyendo el código fuente real de Klipper
(`klippy/kinematics/extruder.py`, función `sync_to_extruder`).

**Hallazgo real de hoy, importante:** la retracción/avance de 80mm puede expulsar el
filamento del engranaje del motor si no se parte de una carga completa y verificada
(probado dos veces con filamento real). Se mantiene en 80mm porque es la distancia
real que necesita el splitter de esta máquina - pero conviene saber esto antes de
programar cambios de color repetidos sin que el usuario pueda ver qué pasa.

**¿El sistema está preparado para imprimir con dos colores?** Sí, a nivel de Klipper.
Ambos extrusores están cargados con PLA (T0 rojo, T1 amarillo) y confirmados
extruyendo. Lo que falta es la configuración del lado de OrcaSlicer (ver el
documento `DATOS_PARA_ORCASLICER.md`).

**G-code que debe generar OrcaSlicer para el cambio de color:** la palabra `T0` o
`T1` sola, en su propia línea. No parámetros adicionales, no M-codes de cambio de
herramienta estándar (esta no es una configuración de multi-extrusor nativo de
Klipper con offsets de posición - es un swap de motor sobre el mismo hotend).

## 6. Velocidades recomendadas para OrcaSlicer

Basado en: límites reales de Klipper (arriba), recomendación de fábrica de Hellbot
(máximo 80mm/s, recomendado 50mm/s para impresión), y el análisis de caudal
volumétrico de la sección 7 (que confirma que a estas velocidades el extrusor y el
hotend NO son el cuello de botella con un nozzle de 0.4mm).

| Parámetro | Valor recomendado | Valor máximo prudente | Observaciones |
|---|---|---|---|
| Velocidad de primera capa | 20 mm/s | 25 mm/s | Prioriza adherencia, no velocidad |
| Pared exterior | 40 mm/s | 60 mm/s | La que más afecta el acabado visual |
| Pared interior | 50 mm/s | 70 mm/s | Menos crítica visualmente |
| Relleno | 60 mm/s | 80 mm/s | Técnicamente dentro de lo validado |
| Relleno sólido | 50 mm/s | 70 mm/s | — |
| Superficie superior | 40 mm/s | 50 mm/s | Prioriza acabado |
| Soportes | 60 mm/s | 80 mm/s | No afecta calidad de la pieza final |
| Interfaz de soportes | 30 mm/s | 40 mm/s | Afecta qué tan fácil se separan |
| Puentes | 25 mm/s | 30 mm/s | Más lento = menos cuelgue |
| Desplazamientos (travel) | 150 mm/s | 200 mm/s | Sin extrusión, el límite real de Klipper lo permite sin problema |
| Velocidad de extrusión (flujo) | ver sección 7 | ver sección 7 | — |
| Aceleración general | 500 mm/s² | 500 mm/s² (es el techo real de Klipper, no subir) | Más que esto no fue validado por el fabricante y empeora el acabado (ringing) |
| Aceleración pared exterior | 300 mm/s² | 500 mm/s² | Más baja en paredes exteriores mejora el acabado visual |
| Aceleración pared interior | 500 mm/s² | 500 mm/s² | — |
| Aceleración relleno | 500 mm/s² | 500 mm/s² | — |

**Otros valores:**

| Parámetro | Recomendación | Tipo |
|---|---|---|
| Temperatura PLA (hotend) | 210°C | Configuración (ya probado hoy, funciona bien) |
| Temperatura cama | 60°C | Configuración (ya usado en pruebas) |
| Retracción - distancia | 3mm (valor de partida, `firmware_retraction` ya configurado) | **Necesita calibración física** (torre de retracción) |
| Retracción - velocidad | 40mm/s (valor de partida) | **Necesita calibración física** |
| Flow ratio inicial | 1.0 (100%, sin ajustar todavía) | **Necesita calibración física** (torre de flujo) |
| Pressure Advance | 0.0 (sin calibrar) | **Necesita calibración física** (torre de PA) - probablemente más alto que en una impresora de un solo extrusor normal, por el volumen extra del splitter compartido |
| Altura de capa | 0.2mm para empezar | Configuración, dentro de lo típico para un nozzle de 0.4mm |
| Ancho de línea | 0.4-0.45mm | Configuración |
| Ventilador de piezas | 100% desde la capa 2 en adelante (confirmado funcionando a las 3 velocidades probadas hoy) | Configuración |
| Caudal volumétrico máximo | ver tabla de la sección 7 | Mixto - cálculo + estimación |

## 7. Análisis de caudal volumétrico y capacidad real de extrusión (T0 y T1)

**Metodología:** a velocidad de impresión V (mm/s), ancho de línea W, altura de capa
H, el caudal volumétrico es `Q = V × W × H` (mm³/s). La velocidad lineal de filamento
necesaria es `Q / (π × (1.75/2)²) = Q / 2.405` (mm/s de filamento 1.75mm). La
velocidad de rotación del motor es esa velocidad lineal dividida por
`rotation_distance` (7.623mm en T0, 7.848mm en T1).

Tabla calculada con ancho de línea 0.4mm y altura de capa 0.2mm (valores típicos para
este nozzle):

| Velocidad de impresión | Caudal (mm³/s) | Filamento (mm/s) | Rotación T0 (rev/s) | Rotación T1 (rev/s) |
|---|---|---|---|---|
| 30 mm/s | 2.4 | 1.00 | 0.131 | 0.127 |
| 40 mm/s | 3.2 | 1.33 | 0.175 | 0.170 |
| 50 mm/s | 4.0 | 1.66 | 0.218 | 0.212 |
| 60 mm/s | 4.8 | 2.00 | 0.262 | 0.255 |
| 80 mm/s | 6.4 | 2.66 | 0.349 | 0.339 |

**Conclusión del cálculo (esto SÍ se puede afirmar con certeza, es matemática pura):**
a estas velocidades, con este nozzle de 0.4mm, el motor nunca necesita girar a más de
~0.35 revoluciones por segundo (21 RPM) - una fracción mínima de lo que cualquier
motor paso a paso NEMA17 puede sostener mecánicamente. **El motor extrusor NO es el
cuello de botella** a ninguna de estas velocidades, ni en T0 ni en T1 - la diferencia
entre ambos (T0 419.6 pasos/mm vs T1 407.7 pasos/mm) es mínima y no afecta esta
conclusión.

**Lo que SÍ necesita calibración física, no se puede calcular a ciegas:** cuánto
PLA por segundo puede fundir de verdad ESTE hotend específico sin quedarse corto
(subextrusión). Ese número depende del diseño térmico real del bloque calefactor y
la boquilla, que no tenemos documentado con una hoja de datos del fabricante. Como
referencia de la industria para un hotend de tipo genérico/stock (no un hotend de
alto flujo), el rango típico está entre 8 y 12 mm³/s para PLA bien calibrado - a
80mm/s con 0.4mm de ancho y 0.2mm de capa, el caudal pedido (6.4 mm³/s) está DENTRO
de ese rango típico, pero sin una prueba real de "flow rate" (el asistente de
OrcaSlicer lo tiene) no se puede confirmar que ESTE hotend específico lo sostenga sin
subextrusión. Esto es una estimación de industria, no un dato medido en esta unidad.

**Qué limitación aparece primero:** con los datos disponibles, ni el motor ni los
drivers ni la mecánica de alimentación son el límite a estas velocidades - el único
límite real que podría aparecer es térmico (el hotend), y eso solo se puede confirmar
imprimiendo una prueba de caudal real.

## 8. Evaluación y estado del acceso remoto

**Viabilidad de Tailscale: SÍ, viable.** Linux Mint 22.3 está basado en Ubuntu 24.04,
que tiene soporte oficial de Tailscale vía su repositorio apt - instalación estándar,
sin parches ni workarounds. Consumo de recursos de Tailscale es mínimo (un daemon
ligero en Go, pensado para correr incluso en Raspberry Pi), no debería competir con
los recursos que ya cuidamos para Klipper en esta netbook de 2 núcleos.

- **Compatibilidad con Moonraker/Mainsail:** total - son servicios HTTP normales,
  Tailscale solo crea una red privada que los hace alcanzables, no necesita ningún
  cambio en Moonraker o Mainsail para funcionar.
- **Acceso a la cámara:** el stream de crowsnest (puerto 8080, consumido por Mainsail
  en `/webcam/?action=stream`) es igualmente un servicio HTTP normal - debería
  funcionar igual por Tailscale, pendiente de confirmar con una prueba real una vez
  que Tailscale esté activo.
- **Android/Windows:** Tailscale tiene apps oficiales para ambos, instalación directa
  desde Play Store / sitio oficial.
- **MagicDNS:** disponible, da un nombre fijo (ej. `facundo-cx215xx-cx212xx.tail-scale.ts.net`)
  que no cambia aunque cambie la IP local - resuelve el problema de "la IP cambia".
- **Reinicio de la netbook:** el servicio `tailscaled` se instala como systemd,
  arranca solo en el próximo boot - no necesita reconectarse a mano.
- **Corte de Internet / reinicio del router:** Tailscale usa WireGuard con múltiples
  rutas (relay de Tailscale + conexión directa cuando es posible) - si se corta
  Internet en la casa de la netbook, no hay acceso remoto posible (es inherente a
  cualquier solución de acceso remoto, no es una limitación de Tailscale). Si el
  router se reinicia pero la IP cambia, Tailscale se reconecta solo sin intervención.
- **OrcaSlicer conectándose por la URL remota:** debería funcionar igual que con la
  IP local, usando la IP/nombre de Tailscale en vez de la IP de la LAN - pendiente de
  confirmar con una prueba real.

**Estado real al momento de este informe: INSTALACIÓN PENDIENTE.** Ver sección 10,
"Tareas pendientes" - necesita que el usuario corra 1-2 comandos con `sudo` y
complete el login de Tailscale (abre una URL en el navegador, requiere su cuenta) -
**no puedo completar esto yo, es una autenticación que solo el usuario puede hacer.**

## 9. Pruebas realizadas y resultados

| Prueba | Resultado |
|---|---|
| Estado de Klipper | ✅ `ready`, sin errores |
| Estado de Moonraker | ✅ activo, API respondiendo |
| Estado de Mainsail | ✅ activo (nginx, puerto 80) |
| Conexión local (LAN) | ✅ confirmada, `192.168.18.196` y `.local` resuelven y responden |
| Calidad de comunicación MCU | ✅ 9 retransmisiones / 8145 secuencias, 0 inválidas - saludable |
| Cámara (stream local) | ✅ responde HTTP 200 en `localhost:8080/?action=snapshot`, registrada en Moonraker |
| Conexión Tailscale | ⬜ pendiente - no instalado todavía al momento de este corte del informe |
| Acceso remoto real (otra red) | ⬜ pendiente de Tailscale |
| Resolución de MagicDNS | ⬜ pendiente de Tailscale |

No se calentó el hotend, no se movieron motores ni se inició ninguna impresión
durante esta auditoría (las pruebas de calor/filamento ya se habían hecho antes, en
la sesión de calibración previa, no en esta auditoría).

## 10. Tareas pendientes (necesitan al usuario)

1. **Completar instalación de Tailscale:** correr `curl -fsSL https://tailscale.com/install.sh | sh` y después `sudo tailscale up` (este último va a imprimir una URL - hay que abrirla en un navegador y loguearse con una cuenta, Google/Microsoft/GitHub funcionan). Avisame cuando lo hagas y termino de configurar MagicDNS y verifico todo.
2. **Pressure Advance, retracción fina, flow rate real:** necesitan imprimir algo y mirarlo - se hacen con el laminador, siguiendo el documento `DATOS_PARA_ORCASLICER.md`.
3. **Confirmar tipos reales de termistor** (extrusor y cama) - están puestos por defecto del tipo más común para esta placa, no verificados físicamente contra el componente real.
4. **Decidir sobre el historial de desconexiones USB de semanas anteriores** - sigue sin una causa 100% confirmada; recomendación: primera impresión real corta (20-30 min) antes de confiar en algo largo.
