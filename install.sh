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
# Verificar y obtener Chrome/Chromium con retries
run_with_retry "CHROME=$(command -v google-chrome || command -v chromium || command -v chromium-browser || true)" 0
[ -z "$CHROME" ] && echo "aviso: no se encontro Chrome/Chromium (instalalo antes de arrancar el kiosko)"

# Verificar python3 con retry
run_with_retry "command -v python3 >/dev/null || { echo 'ERROR: falta python3'; exit 1; }" 0
python3 - <<'PY' || echo "aviso: faltan paquetes de python, instalalos: pip install --user --break-system-packages yt-dlp websocket-client"
import yt_dlp, websocket
PY

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
install -m 644 "$SRC/../launchers/tvkiosk.desktop" "$DESKTOP_DIR/tvkiosk.desktop"
install -m 644 "$SRC/../launchers/panel-tvs.desktop" "$DESKTOP_DIR/panel-tvs.desktop"
gtk-launch tvkiosk.desktop 2>/dev/null || true
gtk-launch panel-tvs.desktop 2>/dev/null || true

echo ""
echo "Listo. Comandos: tvs \"busqueda\", tvplay \"busqueda\", tvadd, tvctl (pause|play N|full|next|prev|list|quit)"
echo "Y el panel web:  http://127.0.0.1:8765   (accion directo o boton 'Panel TVs')"