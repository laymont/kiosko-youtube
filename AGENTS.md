# AGENTS.md

Kiosko de YouTube en los TVs: bash + Python stdlib que maneja un Chrome real por
CDP. No hay build, tests, linter ni CI.

## Verificación

- No existe suite de tests, `requirements.txt`, `package.json` ni workflow. No
  inventes `npm test` / `pytest` / `make`.
- Comprobación real: `bash -n scripts/<script>` y
  `python3 -m py_compile scripts/tvcdp.py scripts/tvpanel`.
- Prueba funcional: `./scripts/tvkiosk` y luego `./scripts/tvctl pause`. Necesita
  Chrome instalado y el monitor `HDMI-1` conectado; sin ellos los fallos son de
  entorno (red/pantalla), no del código. Dilo si no pudiste ejecutarla.
- No cambies a yt-dlp/mpv para reproducir: desde esta IP Google devuelve 403 y
  solo funciona un navegador real (ver README). `yt-dlp` se usa solo para buscar.

## Repo vs instalado

- `install.sh` copia `scripts/*` a `~/.local/bin` y genera allí un wrapper
  `yt-dlp` (`python3 -m yt_dlp`). Editar `scripts/` **no** cambia lo instalado:
  reejecuta `./install.sh` o invoca `./scripts/tvctl` explícitamente.
- `install.sh` instala el lanzador en `~/.local/share/applications/` e inicia
  `tvpanel` desconectado de la terminal. No abre el navegador ni arranca Chrome;
  el usuario abre el panel desde el menú cuando quiera.
- Cada script resuelve sus pares con `BIN="$(cd "$(dirname "$0")" && pwd)"`, no
  por `PATH`. Solo `yt-dlp` cae a `PATH` si no hay wrapper hermano. Mantén ese
  patrón para que funcionen desde el repo y desde `~/.local/bin`.
- `tvpanel` y `tvcdp.py` se ejecutan directamente: requieren bit ejecutable.

## Estado compartido (todo en /tmp, efímero)

- `/tmp/tvqueue.txt` (`vid<TAB>título` por línea), `/tmp/tvcur` (índice 1-based),
  `/tmp/tvmeta.json` (thumb/canal/duración), `/tmp/tvfull` (`1`/`0`).
- El panel lee `tvmeta.json` y solo cae a `tvqueue.txt` si está vacío; `tvs`,
  `tvadd` y `tvctl` escriben únicamente la cola. Al tocar el flujo de búsqueda,
  mantén ambos en sincronía.
- `LAST['q']` del panel vive en memoria: `/api/more` deja de funcionar si se
  reinicia `tvpanel`.

## CDP y kiosko

- CDP en `9222`, perfil `~/.config/tvchrome`; panel en `127.0.0.1:8765`.
- El panel usa OTRO Chrome con perfil `~/.config/tvpanel` y CDP `9223`
  (`tvpanel-gui`): no tocar los perfiles personales del usuario ni crear
  pestañas duplicadas (activa la pestaña existente vía `/json/activate`).
- `--ozone-platform=x11` es obligatorio: el backend Wayland nativo ignora
  `--window-position` y el kiosko no cae en el rect de HDMI-1.
- `tvkiosk` es idempotente (si 9222 responde, sale 0). Para reiniciar de verdad:
  `tvctl quit` y volver a arrancar.
- Al enviar teclas incluye siempre `windowsVirtualKeyCode` (ver `KEYMAP` en
  `tvcdp.py`). Mandar el carácter suelto hace que YouTube lo lea como numpad y
  salte al ~60% del vídeo.
- Pantalla completa: la tecla `f` alterna y el estado deseado se persiste en
  `/tmp/tvfull`; `tvfull` lo reaplica tras cada navegación. `fullscreenElement`
  solo sirve para leer el estado, no como fuente de verdad.
- Tras navegar se espera ~4 s antes de enviar `Space` (`sleep 4` en los scripts,
  `threading.Timer(4.0, autostart)` en el panel). Sin esa espera el vídeo queda
  pausado.

## Trampas de la CLI

- `tvctl play` sin número envía `Space` (pausa/reanuda), no reproduce. Para
  reproducir: `tvctl play N` o `tvctl N`.
- `tvctl next` / `prev` son cíclicos y reescriben `/tmp/tvcur`.
- En `tvctl` la rama `play)` está duplicada; gana la primera, así que el
  `play_idx "${2:-1}"` final es código muerto.
- `tvs` pide `ytsearch(START+9)` y recorta desde `START-1`; `tvadd` añade 5; el
  panel busca 5 sin `--flat-playlist` porque necesita metadata (más lento).

## Convenciones

- Todo en español: comentarios, mensajes al usuario, UI del panel y README. Los
  errores de los scripts se muestran tal cual, así que redáctalos para el usuario.
- Sin dependencias nuevas: stdlib de Python + `websocket-client` + `yt-dlp`.
- La instalación es `install.sh`; no añadas empaquetado ni gestores de tareas.

## Extensiones anti-ads

- `install.sh` pregunta si instalar uBlock Origin y SponsorBlock; si acepta, los
  descarga de GitHub releases y los extrae en `~/.config/tvchrome/extensions/`.
- `tvkiosk` los carga con `--load-extension` si existen `manifest.json` en cada
  subdirectorio (`ublock`, `sponsorblock`).
- Para actualizar: borra el directorio y reejecuta `install.sh` (o descarga la
  nueva versión manualmente).

## Icono .desktop

- `panel-tvs.desktop` se instala en `~/.local/share/applications/` (menú) y
  en el escritorio (`~/Escritorio`). `install.sh` reescribe `Exec=` con la
  ruta absoluta de `DEST`: sin ella GNOME no muestra el lanzador. En el
  escritorio GNOME lo muestra atenuado hasta "Permitir lanzamiento"; es lo
  esperado, no un error.
- `tvpanel-gui` arranca `tvpanel` si no responde y abre el panel en el
  Chrome de perfil dedicado `~/.config/tvpanel` (CDP 9223), no con
  `xdg-open`: así no se ensucian los perfiles del usuario.
