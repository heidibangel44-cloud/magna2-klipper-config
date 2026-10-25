#!/bin/bash
# Prueba de repetibilidad de homing de Z - Hellbot Magna 2 230 Dual
#
# QUÉ HACE: repite N veces el ciclo "home completo -> viajar a otra posición ->
# volver a la esquina 1 a Z=1mm" con límites conservadores, y registra en un CSV
# el estado de Klipper y las estadísticas de comunicación de la MCU después de
# cada ciclo (para detectar shutdowns/desconexiones USB silenciosas).
#
# QUÉ NO HACE (limitación real, no se puede automatizar sin una sonda): no mide
# la altura física real. Klipper siempre reporta la misma posición Z después de
# un G28 porque esa posición ES la definición de "home" (position_endstop) - la
# variación real solo se puede medir con el papel, a mano, por eso el script
# PAUSA entre ciclos y pide al usuario que anote lo que siente con el papel.
#
# SEGURIDAD: velocidad de homing conservadora (la de printer.cfg, sin tocar),
# pausa de confirmación ANTES del primer movimiento, y se puede abortar con
# Ctrl+C en cualquier momento entre ciclos (una vez que un ciclo arrancó, se
# deja terminar ese G28 individual, no se corta a mitad de un movimiento).
#
# Requiere: Klipper en estado "ready", impresora ya revisada en la sesión
# supervisada (dirección de movimiento, switches, parada de emergencia a mano).

set -euo pipefail

MOONRAKER_URL="http://localhost:7125"
N_CICLOS="${1:-5}"
RESULTS_FILE="$HOME/printer_data/config/tools/z_repeatability_results_$(date +%Y%m%d_%H%M%S).csv"

echo "=== Prueba de repetibilidad de homing Z ==="
echo "Ciclos a correr: $N_CICLOS"
echo "Resultados en: $RESULTS_FILE"
echo ""
echo "ANTES DE CONTINUAR: esto es para la SESIÓN SUPERVISADA, no para correr sin"
echo "supervisión. Confirmá que ya se revisó dirección de movimiento, switches"
echo "y que tenés la parada de emergencia a mano."
read -p "¿Confirmás que estás supervisando y listo para empezar? (si/no): " confirmacion
if [ "$confirmacion" != "si" ]; then
    echo "Abortado por el usuario."
    exit 1
fi

check_state() {
    curl -s "$MOONRAKER_URL/printer/info" | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['state'])"
}

estado_inicial=$(check_state)
if [ "$estado_inicial" != "ready" ]; then
    echo "ERROR: Klipper no está en estado 'ready' (está en '$estado_inicial'). Abortando."
    exit 1
fi

echo "ciclo,timestamp,estado_tras_home,bytes_retransmit,bytes_invalid,sysload,nota_papel_usuario" > "$RESULTS_FILE"

for i in $(seq 1 "$N_CICLOS"); do
    echo ""
    echo "--- Ciclo $i/$N_CICLOS ---"

    # Viajar lejos de la esquina 1 (si ya está homeado) antes de rehomear, para
    # que cada home sea un test real y no "ya estaba ahí".
    curl -s -X POST "$MOONRAKER_URL/printer/gcode/script" --data-urlencode "script=NIVELAR_ESQUINA_3" > /dev/null || true
    sleep 3

    # Home completo + ir a la esquina 1 a Z=1mm (approach, sin tocar la cama)
    curl -s -X POST "$MOONRAKER_URL/printer/gcode/script" --data-urlencode "script=NIVELAR"
    sleep 10

    estado=$(check_state)
    if [ "$estado" != "ready" ]; then
        echo "*** ALERTA: Klipper quedó en estado '$estado' tras el home - posible shutdown/desconexión USB. ***"
        echo "$i,$(date -Iseconds),$estado,,,,ABORTADO-ver-log" >> "$RESULTS_FILE"
        echo "Deteniendo la prueba acá. Revisar klippy.log antes de reintentar."
        exit 1
    fi

    stats=$(curl -s "$MOONRAKER_URL/printer/objects/query?mcu" | python3 -c "
import json,sys
d = json.load(sys.stdin)['result']['status']['mcu']['last_stats']
print(f\"{d.get('bytes_retransmit','')},{d.get('bytes_invalid','')},{d.get('sysload','')}\")
")

    echo "Estado: $estado | stats MCU: $stats"
    echo ""
    echo ">>> Ahora: bajá con cuidado y chequeá con el papel en la esquina 1. <<<"
    read -p "Anotá lo que sentiste (ej: 'igual', 'mas alto', 'mas bajo', 'choca'): " nota

    echo "$i,$(date -Iseconds),$estado,$stats,\"$nota\"" >> "$RESULTS_FILE"
done

echo ""
echo "=== Prueba terminada. Resultados en $RESULTS_FILE ==="
cat "$RESULTS_FILE"
