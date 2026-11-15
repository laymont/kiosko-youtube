#!/bin/bash
# tv-primary-setup.sh - Configura HDMI-1 como monitor secundario (no principal)
# Uso:  sudo ./tv-primary-setup.sh
set -e

MONITOR_PRIMARY="HDMI-1"
MONITOR_SECONDARY="eDP-1"

echo "Configurando monitores..."

# Verificar que ambos monitores existen
if ! xrandr --listmonitors | grep -q "$MONITOR_PRIMARY"; then
    echo "ERROR: $MONITOR_PRIMARY no detectado"
    exit 1
fi

if ! xrandr --listmonitors | grep -q "$MONITOR_SECONDARY"; then
    echo "ERROR: $MONITOR_SECONDARY no detectado"
    exit 1
fi

# Configurar HDMI-1 a la derecha del eDP-1 (HDMI-1 como secundario)
xrandr --output "$MONITOR_PRIMARY" --right-of "$MONITOR_SECONDARY"

echo "✅ Configuración completada"
echo ""
echo "Configuración actual:"
xrandr --output "$MONITOR_PRIMARY" --pos 1920,0 \
       --output "$MONITOR_SECONDARY" --pos 0,0

echo ""
echo "Para aplicar inmediatamente (sin reiniciar):"
echo "  xrandr --output HDMI-1 --right-of eDP-1"
echo ""
echo "Nota: Para que la configuración persista al inicio de sesión en Ubuntu:"
echo "  - Edita /etc/gdm3/custom.conf y agrega: Wayland=yes"
echo "  - O usa gdm-configurator para configurar manualmente los monitores"
