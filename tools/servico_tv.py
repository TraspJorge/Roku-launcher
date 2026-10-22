#!/usr/bin/env python3
"""Servico do Meu Menu (roda no PC).

- Abre o Meu Menu sempre que a TV liga na tela inicial da Roku.
- Detecta apps instalados/removidos na TV, atualiza a lista e os icones do
  Meu Menu e reinstala o app. A reinstalacao so acontece quando o Meu Menu
  esta na tela (ou ao ligar a TV), para nunca interromper outro app.
"""
import hashlib
import http.server
import io
import json
import re
import socket
import threading
import time
import urllib.request
import uuid
import zipfile
from pathlib import Path

PROJETO = Path(__file__).resolve().parent.parent
APP = PROJETO / "app"
APPS_JSON = APP / "source" / "apps.json"
ICONES = APP / "images" / "apps"
ZIP = PROJETO / "meu-menu.zip"
CONFIG = json.loads((Path(__file__).resolve().parent / "config.json").read_text())

TV = f"http://{CONFIG['tv_ip']}:8060"
DEV = f"http://{CONFIG['tv_ip']}"
INTERVALO = 3               # segundos entre verificacoes de liga/desliga
INTERVALO_APPS = 60         # segundos entre verificacoes da lista de apps
ESPERA_TELA_INICIAL = 30
PORTA_PONTE = 8787          # o Meu Menu chama esta porta para trocar de entrada HDMI
LEITURAS_DESLIGADA = 3      # evita falso "desligou" por falha momentanea de rede


def log(*args):
    print(time.strftime("%H:%M:%S"), *args, flush=True)


def get(path, timeout=3):
    return urllib.request.urlopen(TV + path, timeout=timeout).read()


def post(path):
    urllib.request.urlopen(urllib.request.Request(TV + path, data=b"", method="POST"), timeout=5)


def tv_ligada():
    try:
        return b"<power-mode>PowerOn</power-mode>" in get("/query/device-info")
    except Exception:
        return False


def app_ativo():
    """'home', 'dev' (Meu Menu), id de outro app, ou None."""
    try:
        xml = get("/query/active-app").decode()
    except Exception:
        return None
    if re.search(r'<app[^>]*type="home"', xml):
        return "home"
    m = re.search(r'<app id="([^"]+)"', xml)
    return m.group(1) if m else None


# ---------- Lista de apps ----------

def apps_na_tv():
    xml = get("/query/apps", timeout=5).decode()
    apps = re.findall(r'<app id="([^"]+)" type="appl"[^>]*>([^<]*)</app>', xml)
    return [(i, n.strip()) for i, n in apps if i != "dev"]


def sincronizar_apps():
    """Atualiza apps.json e icones. Retorna True se algo mudou.

    Mantem a ordem atual do menu; apps novos entram no final.
    """
    try:
        na_tv = apps_na_tv()
    except Exception as e:
        log("Nao foi possivel ler os apps da TV:", e)
        return False

    atuais = json.loads(APPS_JSON.read_text()) if APPS_JSON.exists() else []
    nomes_tv = dict(na_tv)
    novos = [a for a in atuais if a["id"] in nomes_tv]
    for a in novos:
        a["title"] = nomes_tv[a["id"]]
    ids = {a["id"] for a in novos}
    adicionados = [(i, n) for i, n in na_tv if i not in ids]
    removidos = [a["title"] for a in atuais if a["id"] not in nomes_tv]

    for app_id, nome in adicionados:
        try:
            r = urllib.request.urlopen(f"{TV}/query/icon/{app_id}", timeout=10)
        except Exception as e:
            log("Falha ao baixar icone de", nome, e)
            continue
        ext = "png" if "png" in r.headers.get("Content-Type", "") else "jpg"
        (ICONES / f"{app_id}.{ext}").write_bytes(r.read())
        novos.append({"id": app_id, "title": nome, "icon": f"pkg:/images/apps/{app_id}.{ext}"})

    if novos == atuais:
        return False

    usados = {Path(a["icon"]).name for a in novos}
    for icone in ICONES.iterdir():
        if icone.name not in usados:
            icone.unlink()
    APPS_JSON.write_text(json.dumps(novos, ensure_ascii=False, indent=1))
    log("Lista atualizada. Adicionados:", [n for _, n in adicionados] or "-", "| Removidos:", removidos or "-")
    return True


# ---------- Instalacao ----------

def ip_do_pc():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect((CONFIG["tv_ip"], 8060))
    return s.getsockname()[0]


def empacotar():
    # Endereco da ponte gravado no app (a Roku nao deixa o app trocar de entrada sozinho)
    (APP / "source" / "pc.json").write_text(json.dumps({"bridge": f"http://{ip_do_pc()}:{PORTA_PONTE}"}))
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        for arq in sorted(APP.rglob("*")):
            if arq.is_file():
                z.write(arq, arq.relative_to(APP).as_posix())
    ZIP.write_bytes(buf.getvalue())
    return buf.getvalue()


def cabecalho_digest(metodo, caminho):
    try:
        urllib.request.urlopen(DEV + caminho, timeout=10)
        raise RuntimeError("a TV nao pediu autenticacao")
    except urllib.error.HTTPError as e:
        desafio = e.headers.get("WWW-Authenticate", "")
    campos = dict(re.findall(r'(\w+)="?([^",]+)"?', desafio))
    md5 = lambda s: hashlib.md5(s.encode()).hexdigest()
    ha1 = md5(f"{CONFIG['dev_user']}:{campos['realm']}:{CONFIG['dev_password']}")
    ha2 = md5(f"{metodo}:{caminho}")
    cnonce = uuid.uuid4().hex[:16]
    resposta = md5(f"{ha1}:{campos['nonce']}:00000001:{cnonce}:auth:{ha2}")
    return (f'Digest username="{CONFIG["dev_user"]}", realm="{campos["realm"]}", '
            f'nonce="{campos["nonce"]}", uri="{caminho}", qop=auth, nc=00000001, '
            f'cnonce="{cnonce}", response="{resposta}"')


def instalar():
    pacote = empacotar()
    limite = "----meumenu" + uuid.uuid4().hex
    corpo = (
        f"--{limite}\r\nContent-Disposition: form-data; name=\"mysubmit\"\r\n\r\nInstall\r\n"
        f"--{limite}\r\nContent-Disposition: form-data; name=\"archive\"; filename=\"meu-menu.zip\"\r\n"
        "Content-Type: application/zip\r\n\r\n"
    ).encode() + pacote + f"\r\n--{limite}--\r\n".encode()

    # A TV fecha a conexao se o upload chega sem autenticacao, entao a
    # autenticacao Digest e calculada antes de enviar o arquivo
    req = urllib.request.Request(f"{DEV}/plugin_install", data=corpo, method="POST", headers={
        "Content-Type": f"multipart/form-data; boundary={limite}",
        "Authorization": cabecalho_digest("POST", "/plugin_install"),
    })
    resposta = urllib.request.urlopen(req, timeout=90).read().decode(errors="replace")
    ok = "Install Success" in resposta or "Identical" in resposta
    log("Meu Menu reinstalado" if ok else "Falha ao reinstalar o Meu Menu")
    return ok


# ---------- Ponte para entradas HDMI ----------

class Ponte(http.server.BaseHTTPRequestHandler):
    """Recebe GET /launch/tvinput.hdmiN do Meu Menu e repassa para a TV."""

    def do_GET(self):
        m = re.fullmatch(r"/launch/(tvinput\.\w+)", self.path)
        if not m:
            self.send_response(404)
            self.end_headers()
            return
        try:
            post(f"/launch/{m.group(1)}")
            self.send_response(200)
            log("Entrada trocada para", m.group(1))
        except Exception as e:
            self.send_response(502)
            log("Falha ao trocar entrada:", e)
        self.end_headers()

    def log_message(self, *args):
        pass


def iniciar_ponte():
    servidor = http.server.ThreadingHTTPServer(("0.0.0.0", PORTA_PONTE), Ponte)
    threading.Thread(target=servidor.serve_forever, daemon=True).start()


# ---------- Loop principal ----------

def main():
    estava_ligada = tv_ligada()
    leituras_off = 0
    proxima_checagem = 0
    pendente = False
    iniciar_ponte()
    log("Monitorando a TV. Ligada agora:", estava_ligada, "| Ponte HDMI na porta", PORTA_PONTE)

    while True:
        ligada = tv_ligada()
        if not ligada:
            leituras_off += 1
            if leituras_off >= LEITURAS_DESLIGADA:
                estava_ligada = False
            time.sleep(INTERVALO)
            continue
        leituras_off = 0

        if time.time() >= proxima_checagem or not estava_ligada:
            pendente = sincronizar_apps() or pendente
            proxima_checagem = time.time() + INTERVALO_APPS

        if not estava_ligada:
            # So age se a TV ligou na tela inicial da Roku (nao atrapalha HDMI/outro app)
            limite = time.time() + ESPERA_TELA_INICIAL
            while time.time() < limite and app_ativo() != "home":
                time.sleep(1)
            if app_ativo() == "home":
                try:
                    instalado = pendente and instalar()  # instalar ja abre o Meu Menu
                    if instalado:
                        pendente = False
                    else:
                        post("/launch/dev")
                    log("TV ligou -> Meu Menu aberto")
                except Exception as e:
                    log("Falha ao abrir Meu Menu:", e)
        elif pendente and app_ativo() == "dev":
            # Meu Menu na tela: recarrega com a lista nova
            try:
                pendente = not instalar()
            except Exception as e:
                log("Falha ao reinstalar:", e)

        estava_ligada = True
        time.sleep(INTERVALO)


if __name__ == "__main__":
    main()
