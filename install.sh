#!/bin/bash
# install.sh - instala el sistema "YouTube en los TVs" en esta maquina
# uso:  ./install.sh
set -e

SRC="$(cd "$(dirname "$0")" && pwd)/scripts"
DEST="${1:-$HOME/.local/bin}"
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Escritorio")"

# Función para ejecutar comandos con retries y backoff exponencial
run_with_retry() {
    local cmd="$1"
    shift
    local max_retries=${1:-3}
    local base_delay=${2:-5}
    # 0 significa "un solo intento"; el bucle debe ejecutarse al menos una vez
    [ "$max_retries" -lt 1 ] && max_retries=1
    
    local attempt=0
    local delay=$base_delay
    
    while [ $attempt -lt $max_retries ]; do
        echo "Intento $((attempt + 1))/$max_retries: $cmd"
        if eval "$cmd"; then
            return 0
        fi
        attempt=$((attempt + 1))
        if [ $attempt -lt $max_retries ]; then
            sleep $delay
            delay=$((delay * 2))
            echo "Reintentando en ${delay}s..."
        fi
    done
    return 1
}

echo "== dependencias =="

# Función para verificar una dependencia y detener la instalación si falta
check_dep() {
    local name="$1"
    local check_cmd="$2"
    local install_hint="$3"

    if eval "$check_cmd" >/dev/null 2>&1; then
        echo "  ✓ $name"
        return 0
    else
        echo ""
        echo "ERROR: falta la dependencia '$name'."
        echo ""
        echo "Para instalarla ejecuta:"
        echo "  $install_hint"
        echo ""
        echo "Después vuelve a ejecutar ./install.sh"
        exit 1
    fi
}

# Python 3 (imprescindible)
check_dep "python3" "command -v python3" \
    "sudo apt install python3 python3-pip"

# Chrome/Chromium (imprescindible para el kiosko)
CHROME=$(command -v google-chrome || command -v chromium || command -v chromium-browser || true)
if [ -z "$CHROME" ]; then
    echo ""
    echo "ERROR: no se encontró Chrome/Chromium."
    echo ""
    echo "El kiosko necesita un navegador real de Google. Instala uno con:"
    echo "  sudo apt install google-chrome-stable"
    echo "  # o"
    echo "  sudo apt install chromium-browser"
    echo ""
    echo "Después vuelve a ejecutar ./install.sh"
    exit 1
fi
echo "  ✓ Chrome/Chromium ($CHROME)"

# curl (usado por tvkiosk para detectar el puerto CDP)
check_dep "curl" "command -v curl" \
    "sudo apt install curl"

# xrandr (usado por tvkiosk para detectar la pantalla HDMI-1)
check_dep "xrandr" "command -v xrandr" \
    "sudo apt install x11-xserver-utils"

# Paquetes Python necesarios
echo ""
echo "Verificando paquetes Python..."

# pip3 / python3 -m pip (necesario para instalar los módulos)
if ! python3 -m pip --version >/dev/null 2>&1; then
    echo ""
    echo "ERROR: falta pip para Python 3."
    echo ""
    echo "Instálalo con:"
    echo "  sudo apt install python3-pip"
    echo ""
    echo "Después vuelve a ejecutar ./install.sh"
    exit 1
fi
echo "  ✓ pip"

if ! python3 -c "import yt_dlp" 2>/dev/null; then
    echo ""
    echo "ERROR: falta el módulo Python 'yt-dlp'."
    echo ""
    echo "Instálalo con:"
    echo "  pip3 install --user --break-system-packages yt-dlp"
    echo ""
    echo "Después vuelve a ejecutar ./install.sh"
    exit 1
fi
echo "  ✓ yt-dlp"

if ! python3 -c "import websocket" 2>/dev/null; then
    echo ""
    echo "ERROR: falta el módulo Python 'websocket-client'."
    echo ""
    echo "Instálalo con:"
    echo "  pip3 install --user --break-system-packages websocket-client"
    echo ""
    echo "Después vuelve a ejecutar ./install.sh"
    exit 1
fi
echo "  ✓ websocket-client"

echo "== copiando scripts a $DEST =="
mkdir -p "$DEST"
for f in tvkiosk tvcdp.py tvplay tvs tvadd tvctl tvpanel tvfull; do
  cp "$SRC/$f" "$DEST/$f"
  chmod +x "$DEST/$f"
done
chmod +x "$DEST/tvcdp.py" "$DEST/tvpanel"

echo "== wrapper yt-dlp =="
cat > "$DEST/yt-dlp" <<'EOF'
#!/bin/bash
exec python3 -m yt_dlp "$@"
EOF
chmod +x "$DEST/yt-dlp"

echo "== accesos en el escritorio ($DESKTOP_DIR) =="
mkdir -p "$DESKTOP_DIR"
# Limpiar iconos antiguos para evitar duplicados
rm -f "$DESKTOP_DIR/tvkiosk.desktop"
rm -f "$DESKTOP_DIR/panel-tvs.desktop"
install -m 755 "$SRC/../launchers/panel-tvs.desktop" "$DESKTOP_DIR/panel-tvs.desktop"
gtk-launch panel-tvs.desktop 2>/dev/null || true

echo ""
echo "Listo. Comandos: tvs \"busqueda\", tvplay \"busqueda\", tvadd, tvctl (pause|play N|full|next|prev|list|quit)"
echo "Y el panel web:  http://127.0.0.1:8765   (accion directo o boton 'Panel TVs')"