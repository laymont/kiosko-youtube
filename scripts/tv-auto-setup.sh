#!/bin/bash
# tv-auto-setup.sh - Configura automáticamente los monitores al iniciar sesión
# Uso:  sudo cp tv-auto-setup.sh ~/.config/autostart/. && xdg-open ~/.config/autostart/tv-auto-setup.desktop
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUTO_START="$HOME/.config/autostart/"
DESKTOP_FILE="$AUTO_START/tv-auto-setup.desktop"

# Crear directorio autostart si no existe
mkdir -p "$AUTO_START"

# Crear script de autostart
cat > "$SCRIPT_DIR/auto-setup.sh" << 'EOF'
#!/bin/bash
# Ejecutado automáticamente al inicio de sesión
MONITOR_PRIMARY="HDMI-1"
MONITOR_SECONDARY="eDP-1"

# Verificar monitores
if ! xrandr --listmonitors | grep -q "$MONITOR_PRIMARY"; then
    echo "Monitoreo: $MONITOR_PRIMARY no detectado"
    exit 0
fi

if ! xrandr --listmonitors | grep -q "$MONITOR_SECONDARY"; then
    echo "Monitoreo: $MONITOR_SECONDARY no detectado"
    exit 0
fi

# Configurar orden de monitores (HDMI-1 como secundario)
xrandr --output "$MONITOR_PRIMARY" --left-of "$MONITOR_SECONDARY" \
       --output "$MONITOR_SECONDARY" --pos 0,0

# Guardar en GDM3
gsettings set org.gnome.desktop.wm.preferences monitor-wm-monitor "$MONITOR_PRIMARY"

echo "✅ Monitores configurados: $MONITOR_PRIMARY (primario), $MONITOR_SECONDARY (secundario)"
EOF

chmod +x "$SCRIPT_DIR/auto-setup.sh"

# Crear archivo .desktop para autostart
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Type=Application
Exec=/home/laymont/PhpstormProjects/kiosko-youtube/scripts/auto-setup.sh
Hidden=no
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=TV Monitores Setup
Comment=Configura HDMI-1 como monitor secundario al inicio
EOF

echo "✅ Script de autostart creado: $DESKTOP_FILE"
echo ""
echo "Instalación opcional (para que se ejecute automáticamente):"
echo "  sudo cp tv-auto-setup.sh ~/.config/autostart/"
echo "  xdg-open ~/.config/autostart/tv-auto-setup.desktop"
