# Optimizaciones de la netbook para Klipper (2026-10-26)

Hallazgo real que motivó esto: con `ps aux --sort=-%cpu` se vio que Klipper mismo usa
~0.7% de CPU (nada), pero **Claude Desktop (~50% entre sus procesos) y Firefox (~25%)
estaban corriendo al mismo tiempo**, en una netbook de solo 2 núcleos. Eso es lo que
venía causando los "Timer too close" documentados en la bitácora desde hace tiempo.

## La optimización de mayor impacto, gratis, sin instalar nada:

**Cerrar Claude Desktop y Firefox (o cualquier app pesada) mientras calibrás o
imprimís.** Esta netbook solo tiene 2 núcleos - no hay margen para correr navegador +
apps de escritorio pesadas Y mantener la comunicación en tiempo real con la placa al
mismo tiempo.

## Cambios de software instalados (`instalar_optimizaciones_netbook.sh`)

1. **Prioridad de Moonraker** (`moonraker-priority.conf`, `Nice=-5`) - Klipper ya tenía
   esto (`Nice=-10`, hace semanas); Moonraker no tenía nada. Reversible: borrar
   `/etc/systemd/system/moonraker.service.d/priority.conf` y `sudo systemctl daemon-reload`.
2. **Governor de CPU en "performance"** (`cpu-performance.service`) - por defecto el
   sistema usa `schedutil`, que ahorra energía pero mete latencia al cambiar de
   frecuencia bajo carga variable. En una netbook siempre enchufada, no tiene costo
   real usar "performance" (frecuencia fija al máximo). Reversible:
   `sudo systemctl disable --now cpu-performance.service`.
3. **Swappiness bajado a 10** (`99-klipper-swappiness.conf`, default de Linux es 60) -
   menos uso de swap/disco, que mete latencias grandes e impredecibles. Reversible:
   borrar el archivo de `/etc/sysctl.d/` y `sudo sysctl --system`.
4. **Regla udev de autosuspend USB** - ya estaba preparada, se instala en el mismo
   paso. Nota ya documentada en BITACORA: la evidencia sugiere que esto NO es la causa
   principal de las desconexiones, pero no hace daño tenerlo.

## Lo que NO se tocó (y por qué)

- No se instaló `cpupower` ni ningún paquete nuevo - el cambio de governor se hace
  directo contra los archivos del kernel, sin dependencias nuevas.
- No se desactivaron servicios del sistema (bluetooth, impresión, etc.) - no se
  identificó ninguno consumiendo CPU real en la medición.
- No se tocó la prioridad de Klipper (ya estaba bien puesta desde antes).
