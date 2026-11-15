#!/bin/bash
# uninstall.sh - desinstala el sistema "YouTube en los TVs"
# uso: ./uninstall.sh
set -e

SRC="$(cd "$(dirname "$0")" && pwd)/scripts"
DEST="${1:-$HOME/.local/bin}"

echo "=== Desinstalación de Kiosko YouTube ==="

# 1. Detener el kiosko si está activo
echo ""
echo "🛑 Intentando detener el kiosko..."
if [ -f "$HOME/.config/tvchrome/tvkiosk.pid" ]; then
    PID=$(cat "$HOME/.config/tvchrome/tvkiosk.pid")
    if kill -0 "$PID" 2>/dev/null; then
        echo "✅ Kiosko detectado (PID: $PID), deteniendo..."
        kill "$PID"
        sleep 1
    fi
fi

# 2. Eliminar archivos de estado en /tmp
echo ""
echo "🗑️ Limpiando archivos de estado temporales..."
rm -f /tmp/tvqueue.txt
rm -f /tmp/tvcur
rm -f /tmp/tvfull
rm -f /tmp/tvkiosk.log
rm -f /tmp/tvmeta.json

# 3. Eliminar configuración en ~/.config/tvchrome
echo ""
echo "🗑️ Limpiando configuración..."
rm -rf "$HOME/.config/tvchrome"

# 4. Eliminar scripts de $DEST
echo ""
echo "🗑️ Eliminando scripts instalados..."
for f in tvkiosk tvcdp.py tvplay tvs tvadd tvctl tvpanel tvfull yt-dlp; do
    if [ -f "$DEST/$f" ]; then
        echo "  - Quitando $f"
        rm -f "$DEST/$f"
    fi
done

# 5. Eliminar archivos .desktop del escritorio
echo ""
echo "🗑️ Limpiando lanzadores..."
rm -f "$DESKTOP_DIR/tvkiosk.desktop"
rm -f "$DESKTOP_DIR/panel-tvs.desktop"

# 6. Limpieza final (opcional)
echo ""
echo "❓ ¿Deseas eliminar también los paquetes de Python?"
read -p "Sí/No: " confirm
if [ "$confirm" = "sí" ] || [ "$confirm" = "si" ]; then
    echo "🧹 Quitando dependencias de Python..."
    pip3 uninstall --user yt-dlp websocket-client 2>/dev/null || true
fi

echo ""
echo "✅ Desinstalación completada."
echo "Para reinstalar: ./install.sh"
