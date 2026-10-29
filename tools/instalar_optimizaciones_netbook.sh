#!/bin/bash
# Instala las optimizaciones de rendimiento para esta netbook como host de
# Klipper. Todo reversible - ver tools/README_optimizaciones.md para como
# deshacer cada cambio. Requiere sudo.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "1) Prioridad de Moonraker (ya existe para Klipper, falta Moonraker)"
sudo mkdir -p /etc/systemd/system/moonraker.service.d
sudo cp "$DIR/moonraker-priority.conf" /etc/systemd/system/moonraker.service.d/priority.conf

echo "2) Governor de CPU en 'performance' (persistente, se activa en cada boot)"
sudo cp "$DIR/cpu-performance.service" /etc/systemd/system/cpu-performance.service
sudo systemctl daemon-reload
sudo systemctl enable --now cpu-performance.service

echo "3) Swappiness mas bajo (menos uso de swap/disco, menos latencia)"
sudo cp "$DIR/99-klipper-swappiness.conf" /etc/sysctl.d/99-klipper-swappiness.conf
sudo sysctl --system

echo "4) Regla udev de autosuspend USB (preparada hace rato, instalando ahora tambien)"
sudo cp "$DIR/99-usb-no-autosuspend-ch340.rules" /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "5) Reiniciar Moonraker para que tome la nueva prioridad"
sudo systemctl daemon-reload
sudo systemctl restart moonraker

echo ""
echo "=== Listo. Verificacion: ==="
echo "Governor actual: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
echo "Swappiness actual: $(cat /proc/sys/vm/swappiness)"
ionice -p "$(pgrep -f moonraker.py)" 2>/dev/null || echo "(no se pudo leer ionice de moonraker)"
