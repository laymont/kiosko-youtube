# YouTube en los TVs — control del kiosko de Chrome en los televisores

Cómo jugar YouTube en pantalla completa en las TVs (HDMI-1), controlado desde
el monitor principal con comandos de terminal y con un panel web con resultados,
listas, pausa, volumen y pantalla completa (que se mantiene al cambiar de vídeo).

## Por qué Chrome (kiosko) y no mpv/yt-dlp

Desde esta IP, Google bloquea (HTTP 403) el acceso de yt-dlp/mpv a los vídeos:
las descargas a datos, los "player clients", la suplantación TLS con `curl_cffi`
e Invidious fallan. Lo único que funciona es un navegador real de Google. Por eso
se usa Chrome en modo *app* fullscreen sobre el espacio de pantalla de los TVs y
se maneja por Chrome DevTools Protocol (CDP).

## la idea

- **Kiosko**: una ventana de Chrome del tamaño exacto del monitor de los TVs
  (HDMI-1), posicionada en sus coordenadas (XWayland respeta `--window-position`;
  el backend nativo Wayland no). Sirve YouTube a pantalla completa.
- **Control**: Chrome ofrece el puerto CDP `9222`; los scripts `tvcdp.py`,
  `tvplay`, `tvs`, `tvadd`, `tvctl` lo manejan desde terminal.
- **Panel web** (`tvpanel`): `http://127.0.0.1:8765` — buscar (Enter o botón),
  lista con thumbnails, reproducir, pausa, +/- volumen, pantalla completa y
  paginación ("+ mas resultados"). Sin vista previa en vivo (cara y lenta).
- **Pantalla completa persistente**: el estado se guarda en `/tmp/tvfull` y al
  cambiar de vídeo se reaplica solo tras cargar el reproductor.

## instalar

```bash
git clone <repo> tv-kiosk && cd tv-kiosk
./install.sh
```

El instalador copia los scripts a `~/.local/bin`, crea el wrapper de `yt-dlp`,
escribe los accesos en el escritorio y arranca el kiosko y el panel.

Dependencias:

- Chrome o Chromium (`google-chrome`, `chromium`, `chromium-browser`)
- Python 3 con (instalar a usuario): `yt-dlp` y `websocket-client`
  ```bash
  pip install --user --break-system-packages yt-dlp websocket-client
  ```
- El monitor de las TVs debe llamarse `HDMI-1` y estar encendido/conectado
  (si no, `tvkiosk` usa por defecto `1680x1050@1600,0`).

## uso

| comando | qué hace |
| --- | --- |
| `tvkiosk` | arranca (o reusa) Chrome kiosko en la pantalla de las TVs |
| `tvs "frase"` | busca y lista resultados SIN tocar lo que suena (máximo 10 desde N) |
| `tvplay "frase" [N]` | busca, lista y reproduce el resultado N (o el 1) ya |
| `tvadd "frase"` | agrega 5 resultados a la cola |
| `tvctl pause` | pausa / reanuda |
| `tvctl play N` | reproduce el N de la lista |
| `tvctl full` | pantalla completa on/off |
| `tvctl next` \| `prev` | salta al final / principio u otro vídeo |
| `tvctl list` | muestra la lista de la cola |
| `tvctl quit` | cierra el kiosko |
| Panel web | `http://127.0.0.1:8765` (o botón "Panel TVs") |

### Teclas del reproductor (se envían por CDP)

Espacio = pausa/reanuda · `f` = pantalla completa · `k` = pausa ·
flechitas ↑↓ = volumen · `Home`/`End` = cambiar de vídeo.
Nota: la tecla virtual se envía con su `windowsVirtualKeyCode` correcto;
enviar el carácter en minúscula hacía que YouTube la leyera como *numpad 6*
y saltaba al ~60% del vídeo (bug ya corregido).

## estado / archivos

- Cola de vídeos: `/tmp/tvqueue.txt` (`vid<TAB>título` por línea)
- Índice actual: `/tmp/tvcur`
- Metadatos (thumb/channel/duration): `/tmp/tvmeta.json`
- Flag de pantalla completa deseada: `/tmp/tvfull`
- Log del kiosko: `/tmp/tvkiosk.log` · del panel: `/tmp/tvpanel.log`
- Puerto CDP: `9222` · Panel: `8765`

## script por script (scripts/)

- `tvkiosk` — abre/reusa Chrome *app* en el rect de HDMI-1 (CDP 9222, perfil
  `~/.config/tvchrome`), detectando chrome/chromium.
- `tvcdp.py` — helper CDP: `navigate | key | eval | mouse | close | status`.
- `tvplay` — "frase" → tvs + reproducir N; URL → navegar directo.
- `tvs` — búsqueda plana con yt-dlp, lista guardada en `/tmp/tvqueue.txt`.
- `tvadd` — agrega a la cola; `tvctl` — control remoto del kiosko.
- `tvpanel` — panel web (ThreadingHTTPServer); endpoints `/api/state`,
  `/api/search`, `/api/more`, `/api/play`, `/api/add`, `/api/nav`, `/api/cmd`.
- `tvfull` — reaplica pantalla completa tras navegar si `/tmp/tvfull` = 1.