#!/usr/bin/env python3
# tvcdp.py - control Chrome kiosko via Chrome DevTools Protocol
#   use: tvcdp navigate <url> | key <Space|ArrowUp|ArrowDown|f|k> | close | status
import sys, json, time, urllib.request
from websocket import create_connection
import os

PORT = 9222
BASE = f'http://127.0.0.1:{PORT}'


def safe_cmd(sock, req_id, method, params=None):
    """Ejecutar comando CDP con manejo de errores robusto"""
    try:
        sock.send(json.dumps({'id': req_id, 'method': method, 'params': params or {}}))
        while True:
            m = json.loads(sock.recv())
            if m.get('id') == req_id:
                if 'error' in m:
                    print(f'ERROR CDP {method}: {m["error"]}')
                    return None
                return m.get('result')
    except Exception as e:
        print(f'CRÍTICO: conexión CDP rota ({e})')
        return None


def cmd(sock, req_id, method, params=None):
    """Enviar comando CDP y devolver el resultado (alias de safe_cmd)."""
    return safe_cmd(sock, req_id, method, params)


def ws():
    """Conectar con Chrome DevTools Protocol con retries y fallbacks"""
    max_retries = 3
    for i in range(max_retries):
        try:
            tabs = json.load(urllib.request.urlopen(f'{BASE}/json/list', timeout=4))
            pages = [t for t in tabs if t.get('type') == 'page']
            if not pages:
                if i == max_retries - 1:
                    sys.exit(f'ERROR: el kiosko no tiene pestañas abiertas (intentos {i+1}/{max_retries})')
                else:
                    time.sleep(2 ** i)  # backoff exponencial
                    continue
            return create_connection(pages[0]['webSocketDebuggerUrl'], timeout=10)
        except Exception as e:
            if i == max_retries - 1:
                sys.exit(f'ERROR: no se pudo conectar a CDP en {PORT} ({e})')
            time.sleep(2 ** i)  # backoff exponencial
    return None


KEYMAP = {
    'Space':      (' ',   'Space',   32, ' '),
    'f':          ('f',   'KeyF',    70, 'f'),
    'k':          ('k',   'KeyK',    75, 'k'),
    'ArrowUp':    ('ArrowUp', 'ArrowUp', 38, ''),
    'ArrowDown':  ('ArrowDown', 'ArrowDown', 40, ''),
    'Home':       ('Home', 'Home',   36, ''),
    'End':        ('End',  'End',    35, ''),
}


def press(sock, key, code, vk, text, rid):
    for i, typ in enumerate(('keyDown', 'keyUp')):
        params = {'type': typ, 'key': key, 'code': code,
                  'windowsVirtualKeyCode': vk}
        if text:
            params['text'] = text
        cmd(sock, rid + i, 'Input.dispatchKeyEvent', params)


def main():
    """Main function con manejo de errores global"""
    a = sys.argv[1:]
    if not a:
        sys.exit('uso: tvcdp navigate <url> | key <Space|ArrowUp|ArrowDown|f|k> | close | status')
    
    # Verificar conexión CDP antes de continuar
    sock = ws()
    if not sock:
        sys.exit(1)
    
    rid = 1
    if a[0] == 'status':
        try:
            urllib.request.urlopen(f'{BASE}/json/version', timeout=3)
            print('kiosko: OK')
        except Exception:
            print('kiosko: apagado')
        return
    elif a[0] == 'navigate':
        if len(a) < 2:
            sys.exit('tvcdp navigate <url>')
        cmd(sock, rid, 'Page.enable'); rid += 1
        cmd(sock, rid, 'Page.navigate', {'url': a[1]}); rid += 1
        print('navegando ->', a[1])
    elif a[0] == 'key':
        key = a[1]
        if key not in KEYMAP:
            sys.exit(f'tecla no soportada: {key}')
        k, code, vk, text = KEYMAP[key]
        # Usar press() que envía keyDown + keyUp (necesario para YouTube)
        press(sock, k, code, vk, text, rid); rid += 1
        print(f'tecla presionada: {key}')
    elif a[0] == 'mouse':
        if len(a) < 3:
            sys.exit('tvcdp mouse <x> <y>')
        x, y = float(a[1]), float(a[2])
        for ev in ('mousePressed', 'mouseReleased'):
            cmd(sock, rid, 'Input.dispatchMouseEvent',
                {'type': ev, 'x': x, 'y': y,
                 'button': 'left', 'clickCount': 1}); rid += 1
        print(f'clic en {int(x)},{int(y)}')
    elif a[0] == 'eval':
        if len(a) < 2:
            sys.exit('tvcdp eval <expresion>')
        r = cmd(sock, rid, 'Runtime.evaluate',
                {'expression': a[1], 'returnByValue': True})
        if r is None:
            sys.exit('ERROR: evaluacion sin respuesta')
        v = r.get('result', {}).get('value')
        print(v if v is not None else '')
    elif a[0] == 'shot':
        cmd(sock, rid, 'Page.enable'); rid += 1
        r = cmd(sock, rid, 'Page.captureScreenshot',
                {'format': 'png', 'scale': 0.4, 'fromSurface': True})
        data = (r or {}).get('data', '')
        if not data:
            sys.exit('ERROR: captura vacia')
        sys.stdout.write(data)
    elif a[0] == 'close':
        # Verificar conexión antes de cerrar
        try:
            urllib.request.urlopen(f'{BASE}/json/version', timeout=3)
        except Exception:
            print('kiosko: apagado')
            sys.exit(1)
        
        cmd(sock, rid, 'Page.enable'); rid += 1
        t = json.load(urllib.request.urlopen(f'{BASE}/json/list', timeout=4))
        pages = [x for x in t if x.get('type') == 'page']
        for p in pages:
            cmd(sock, rid, 'Target.closeTarget', {'targetId': p['id']}); rid += 1
        print('pestañas del kiosko cerradas')
    else:
        sys.exit(f'comando desconocido: {a[0]}')
    sock.close()
    
    # Limpiar archivos de estado solo al cerrar el kiosko
    if a[0] == 'close':
        for f in ['/tmp/tvqueue.txt', '/tmp/tvcur', '/tmp/tvfull', '/tmp/tvkiosk.log', '/tmp/tvmeta.json', '/tmp/tvkeypad.log']:
            try:
                os.remove(f)
            except:
                pass


if __name__ == '__main__':
    main()
