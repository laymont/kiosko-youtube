#!/bin/bash
# uninstall.sh - desinstala el sistema "YouTube en los TVs"
# uso: ./uninstall.sh
set -e

DEST="${1:-$HOME/.local/bin}"
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Escritorio")"

echo "=== Desinstalación de Kiosko YouTube ==="

# 1. Detener el kiosko y el panel si están activos
echo ""
echo "🛑 Deteniendo procesos..."

# Kiosko (Chrome con perfil tvchrome)
if [ -f "$HOME/.config/tvchrome/tvkiosk.pid" ]; then
    PID=$(cat "$HOME/.config/tvchrome/tvkiosk.pid")
    if kill -0 "$PID" 2>/dev/null; then
        echo "  - Kiosko (PID $PID)"
        kill "$PID" 2>/dev/null || true
        sleep 1
    fi
fi

# Panel web en puerto 8765
PANEL_PID=$(pgrep -f "tvpanel" 2>/dev/null | head -1 || true)
if [ -n "$PANEL_PID" ]; then
    echo "  - Panel web (PID $PANEL_PID)"
    kill "$PANEL_PID" 2>/dev/null || true
fi

# 2. Eliminar archivos de estado en /tmp
echo ""
echo "🗑️ Limpiando archivos de estado temporales..."
rm -f /tmp/tvqueue.txt
rm -f /tmp/tvcur
rm -f /tmp/tvfull
rm -f /tmp/tvkiosk.log
rm -f /tmp/tvkiosk.pid
rm -f /tmp/tvmeta.json
rm -f /tmp/tvlastq.txt
rm -f /tmp/tvkeypad.log

# 3. Backup de favoritos y limpieza de ~/.config/tvchrome
echo ""
echo "🗑️ Respaldando configuración del kiosko..."
BACKUP_DIR="$HOME/.local/share/tvchrome-backup"
if [ -f "$HOME/.config/tvchrome/favorites.json" ]; then
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/favorites-$(date +%Y%m%d-%H%M%S).json"
    cp "$HOME/.config/tvchrome/favorites.json" "$BACKUP_FILE"
    echo "  ✓ Favoritos respaldados en: $BACKUP_FILE"
else
    echo "  - No hay favoritos para respaldar"
fi

echo ""
echo "🗑️ Limpiando configuración del kiosko..."
rm -rf "$HOME/.config/tvchrome"

# 4. Eliminar scripts de $DEST
echo ""
echo "🗑️ Eliminando scripts instalados de $DEST..."
for f in tvkiosk tvcdp.py tvplay tvs tvadd tvctl tvpanel tvpanel-gui tvfull yt-dlp; do
    if [ -f "$DEST/$f" ]; then
        echo "  - $f"
        rm -f "$DEST/$f"
    fi
done

# 5. Eliminar archivos .desktop del escritorio y del menú de aplicaciones
echo ""
echo "🗑️ Limpiando lanzadores..."
rm -f "$DESKTOP_DIR/tvkiosk.desktop"
rm -f "$DESKTOP_DIR/panel-tvs.desktop"
rm -f "$HOME/.local/share/applications/tvkiosk.desktop"
rm -f "$HOME/.local/share/applications/panel-tvs.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

# 6. Limpieza final (opcional)
echo ""
read -p "¿Eliminar también los paquetes de Python (yt-dlp, websocket-client)? [s/N]: " confirm
if [ "$confirm" = "s" ] || [ "$confirm" = "S" ] || [ "$confirm" = "sí" ] || [ "$confirm" = "si" ]; then
    echo "🧹 Quitando dependencias de Python..."
    pip3 uninstall --user yt-dlp websocket-client 2>/dev/null || true
fi

echo ""
echo "✅ Desinstalación completada."
if [ -d "$BACKUP_DIR" ]; then
    echo "📦 Favoritos respaldados en: $BACKUP_DIR"
    echo "   Para restaurarlos después de reinstalar, copia el archivo más reciente"
    echo "   a ~/.config/tvchrome/favorites.json"
fi
echo "Para reinstalar: ./install.sh"
