#!/bin/bash
# install.sh - instala el sistema "YouTube en los TVs" en esta maquina
# uso:  ./install.sh
set -e

SRC="$(cd "$(dirname "$0")" && pwd)/scripts"
DEST="${1:-$HOME/.local/bin}"
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Escritorio")"
PROF="$HOME/.config/tvchrome"

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
for f in tvkiosk tvcdp.py tvplay tvs tvadd tvctl tvpanel tvpanel-gui tvfull; do
  cp "$SRC/$f" "$DEST/$f"
  chmod +x "$DEST/$f"
done
chmod +x "$DEST/tvcdp.py" "$DEST/tvpanel" "$DEST/tvpanel-gui"

echo "== wrapper yt-dlp =="
cat > "$DEST/yt-dlp" <<'EOF'
#!/bin/bash
exec python3 -m yt_dlp "$@"
EOF
chmod +x "$DEST/yt-dlp"

# ============================================================
# Extensiones anti-ads (opcional)
# ============================================================
echo ""
echo "== extensiones anti-ads =="
echo ""
echo "YouTube muestra anuncios que interrumpen la reproducción."
echo "Puedes instalar dos extensiones de Chrome para bloquearlos:"
echo ""
echo "  1. uBlock Origin Lite - bloquea anuncios de YouTube (pre-roll, mid-roll, banners)"
echo "  2. SponsorBlock        - salta segmentos de patrocinio marcados por la comunidad"
echo ""
read -p "¿Instalar bloqueo de anuncios? [s/N]: " install_ads

if [ "$install_ads" = "s" ] || [ "$install_ads" = "S" ] || [ "$install_ads" = "sí" ] || [ "$install_ads" = "si" ]; then
    EXT_DIR="$PROF/extensions"
    mkdir -p "$EXT_DIR"

    # uBlock Origin Lite (MV3: uBlock Origin clásico es MV2 y Chrome 139+ no lo carga)
    echo ""
    echo "Descargando uBlock Origin Lite..."
    UBLOCK_ZIP=$(mktemp)
    if curl -sL -m 120 -o "$UBLOCK_ZIP" "https://github.com/uBlockOrigin/uBOL-home/releases/download/2026.1110.1816/uBOLite_2026.1110.1816.chromium.zip"; then
        rm -rf "$EXT_DIR/ublocklite" "$EXT_DIR/ublocklite-tmp" "$EXT_DIR/ublock"
        mkdir -p "$EXT_DIR/ublocklite"
        unzip -q -o "$UBLOCK_ZIP" -d "$EXT_DIR/ublocklite-tmp"
        # El ZIP tiene un subdirectorio uBOLite.chromium/, mover su contenido
        if [ -d "$EXT_DIR/ublocklite-tmp/uBOLite.chromium" ]; then
            cp -r "$EXT_DIR/ublocklite-tmp/uBOLite.chromium"/* "$EXT_DIR/ublocklite/"
        else
            cp -r "$EXT_DIR/ublocklite-tmp"/* "$EXT_DIR/ublocklite/"
        fi
        rm -rf "$EXT_DIR/ublocklite-tmp"
        rm -f "$UBLOCK_ZIP"
        echo "  ✓ uBlock Origin Lite instalado"
    else
        echo "  ✗ Error al descargar uBlock Origin Lite"
        rm -f "$UBLOCK_ZIP"
    fi

    # SponsorBlock
    echo ""
    echo "Descargando SponsorBlock..."
    SB_ZIP=$(mktemp)
    if curl -sL -m 60 -o "$SB_ZIP" "https://github.com/ajayyy/SponsorBlock/releases/download/6.1.7/ChromeExtension.zip"; then
        rm -rf "$EXT_DIR/sponsorblock"
        mkdir -p "$EXT_DIR/sponsorblock"
        unzip -q -o "$SB_ZIP" -d "$EXT_DIR/sponsorblock"
        rm -f "$SB_ZIP"
        echo "  ✓ SponsorBlock instalado"
    else
        echo "  ✗ Error al descargar SponsorBlock"
        rm -f "$SB_ZIP"
    fi

    echo ""
    echo "Las extensiones se cargarán automáticamente al arrancar el kiosko."
else
    echo ""
    echo "Puedes instalarlas más tarde ejecutando: ./install.sh"
    echo "O manualmente desde Chrome Web Store en el perfil del kiosko."
fi

echo "== accesos en el escritorio ($DESKTOP_DIR) =="
# Instalar en el menú de aplicaciones (GNOME/KDE)
APPS_DIR="$HOME/.local/share/applications"
mkdir -p "$APPS_DIR"
install -m 644 "$SRC/../launchers/panel-tvs.desktop" "$APPS_DIR/panel-tvs.desktop"
# Usar ruta absoluta en Exec: algunos entornos no resuelven nombres de PATH
DEST_ESC=$(printf '%s' "$DEST" | sed 's/[&|\\]/\\&/g')
sed -i "s|^Exec=tvpanel-gui$|Exec=$DEST_ESC/tvpanel-gui|" "$APPS_DIR/panel-tvs.desktop"

# En el escritorio: GNOME lo muestra atenuado hasta que el usuario haga
# clic derecho -> "Permitir lanzamiento" (medida de seguridad normal)
install -m 755 "$APPS_DIR/panel-tvs.desktop" "$DESKTOP_DIR/panel-tvs.desktop"

# Limpiar iconos antiguos del escritorio (GNOME los marca como dañados)
rm -f "$DESKTOP_DIR/tvkiosk.desktop"

# Actualizar caché de aplicaciones
update-desktop-database "$APPS_DIR" 2>/dev/null || true

echo ""
echo "== lanzando panel =="
# Arrancar el panel desconectado de la terminal; no abrir el navegador desde el instalador.
if ! curl -fsS -m 2 -o /dev/null http://127.0.0.1:8765/api/state 2>/dev/null; then
  nohup "$DEST/tvpanel" </dev/null >/tmp/tvpanel.log 2>&1 &
fi

echo ""
echo "Listo. Comandos: tvs \"busqueda\", tvplay \"busqueda\", tvadd, tvctl (pause|play N|full|next|prev|list|quit)"
echo "Panel web: http://127.0.0.1:8765 (ábrelo desde el menú 'YouTube en TVs' cuando quieras)"
