#!/bin/bash
# Monitor pasivo continuo de estabilidad USB/Klipper - NO mueve nada, NO
# calienta nada, solo observa y registra. Pensado para correr en background
# durante horas mientras se hace otro trabajo.
#
# Registra en el CSV: timestamp, estado de Klipper, desconexiones USB nuevas
# desde el arranque, bytes_retransmit/invalid del MCU, y si hubo algun evento
# nuevo desde la ultima lectura.

LOGFILE="$HOME/printer_data/config/tools/usb_monitor_pasivo_$(date +%Y%m%d_%H%M%S).csv"
echo "timestamp,klipper_state,usb_disconnects_total,mcu_retransmit,mcu_invalid,evento_nuevo" > "$LOGFILE"

ultimo_disconnect_count=$(journalctl -k -b 2>/dev/null | grep -c "USB disconnect")

while true; do
    ts=$(date -Iseconds)
    estado=$(curl -s -m 3 http://localhost:7125/printer/info 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['state'])" 2>/dev/null || echo "sin_respuesta")
    disc_count=$(journalctl -k -b 2>/dev/null | grep -c "USB disconnect")
    stats=$(curl -s -m 3 "http://localhost:7125/printer/objects/query?mcu" 2>/dev/null | python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)['result']['status']['mcu']['last_stats']
    print(f\"{d.get('bytes_retransmit','')},{d.get('bytes_invalid','')}\")
except Exception:
    print(',')
" 2>/dev/null)

    evento="no"
    if [ "$disc_count" != "$ultimo_disconnect_count" ]; then
        evento="SI - nueva desconexion detectada"
        ultimo_disconnect_count=$disc_count
    fi

    echo "$ts,$estado,$disc_count,$stats,$evento" >> "$LOGFILE"
    sleep 15
done
