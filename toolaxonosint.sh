#!/usr/bin/env bash

# ===== AXONDEVUI RGB =====

RESET='\033[0m'
BOLD='\033[1m'

CYAN='\033[38;2;0;245;255m'
GREEN='\033[38;2;56;232;166m'
YELLOW='\033[38;2;255;209;102m'
PURPLE='\033[38;2;167;139;250m'
PINK='\033[38;2;255;77;157m'
ORANGE='\033[38;2;255;140;66m'
RED='\033[38;2;251;113;133m'
GRAY='\033[38;2;163;163;163m'

UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"
TIMEOUT=20

BASE_URL=""
DOMAIN=""
OUT_DIR=""
LOGFILE=""

banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "    █████╗ ██╗  ██╗ ██████╗ ███╗   ██╗"
    echo "   ██╔══██╗╚██╗██╔╝██╔═══██╗████╗  ██║"
    echo "   ███████║ ╚███╔╝ ██║   ██║██╔██╗ ██║"
    echo "   ██╔══██║ ██╔██╗ ██║   ██║██║╚██╗██║"
    echo "   ██║  ██║██╔╝ ██╗╚██████╔╝██║ ╚████║"
    echo "   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝"
    echo -e "${RESET}"
    echo -e "${PINK}       AXONDEVUI :: OSINT TOOLKIT${RESET}"
    echo -e "${GRAY}       KALI LINUX / TERMUX${RESET}"
    echo
}

# Texto con degradado RGB (un color por caracter).
rainbow() {
    local text="$*"
    local -a colors=("$CYAN" "$GREEN" "$YELLOW" "$PURPLE" "$PINK" "$ORANGE")
    local i len=${#text} out=""
    for (( i=0; i<len; i++ )); do
        out+="${colors[$((i % 6))]}${text:$i:1}${RESET}"
    done
    printf '%b' "$out"
}

seleccionar_herramienta() {
    rainbow "  SELECCIONA LA ENUMERACION"
    echo
    echo -e "${CYAN}   [01] DNS Recon${RESET}"
    echo -e "${GREEN}   [02] HTTP Headers${RESET}"
    echo -e "${YELLOW}   [03] TLS Certificate${RESET}"
    echo -e "${PURPLE}   [04] Robots.txt${RESET}"
    echo -e "${ORANGE}   [05] Security.txt${RESET}"
    echo -e "${CYAN}   [06] Sitemap Mapper${RESET}"
    echo -e "${PINK}   [07] JavaScript Mapper${RESET}"
    echo -e "${PURPLE}   [08] Source Map Inspector${RESET}"
    echo -e "${GREEN}   [09] API Discovery${RESET}"
    echo -e "${ORANGE}   [10] JS <-> API Mapper${RESET}"
    echo -e "${YELLOW}   [11] Key Extractor${RESET}"
    echo -e "${RED}   [12] Phishing Detection${RESET}"
    echo
    echo -e "${GRAY}   [0] Salir${RESET}"
    echo
    rainbow "Escoje una opcion"
    read -r -p " > " OPCION
}

solicitar_dominio() {
    echo
    printf '%b' "${CYAN}${BOLD}Dominio autorizado: ${RESET}"
    read -r BASE_URL
    BASE_URL="${BASE_URL%/}"

    if [[ ! "$BASE_URL" =~ ^https?:// ]]; then
        BASE_URL="https://$BASE_URL"
    fi

    DOMAIN=$(printf '%s' "$BASE_URL" |
        sed -E 's#^https?://##; s#/.*##; s/:.*//')

    if [[ "$DOMAIN" == www.* ]]; then
        local scheme="https"
        [[ "$BASE_URL" == http://* ]] && scheme="http"
        DOMAIN="${DOMAIN#www.}"
        BASE_URL="$scheme://$DOMAIN"
    fi

    if [[ ! "$DOMAIN" =~ ^([a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?)$ ]] ||
       [[ "$DOMAIN" != *.* ]]; then
        echo -e "${RED}Dominio no valido.${RESET}"
        return 1
    fi

    OUT_DIR="axondevui_${DOMAIN//./_}"
    mkdir -p "$OUT_DIR" || return 1

    local code
    code=$(http_code "$BASE_URL")
    if [[ "$code" == "000" || -z "$code" ]]; then
        local alt="http://$DOMAIN"
        if [[ "$(http_code "$alt")" =~ ^2|^3 ]]; then
            BASE_URL="$alt"
            echo -e "${YELLOW}HTTPS sin respuesta, usando HTTP.${RESET}"
        fi
    fi

    echo -e "${GREEN}Objetivo seleccionado: ${DOMAIN}${RESET}"
}

# ===================== HELPERS =====================

section() {
    local title="$*"
    [[ -n "$LOGFILE" ]] && : > "$LOGFILE"
    printf '%b\n' "${CYAN}${BOLD}===== ${title} =====${RESET}"
    [[ -n "$LOGFILE" ]] && printf '===== %s =====\n' "$title" >> "$LOGFILE"
}

log() {
    local msg="$*"
    printf '%s\n' "$msg"
    [[ -n "$LOGFILE" ]] && printf '%s\n' "$msg" >> "$LOGFILE"
}

note() {
    printf '%b[AXON] %s%b\n' "${CYAN}" "$*" "$RESET"
}

ok() {
    printf '%b[ OK ] %s%b\n' "${GREEN}" "$*" "$RESET"
}

warn() {
    printf '%b[WARN] %s%b\n' "${YELLOW}" "$*" "$RESET"
}

pause() {
    printf '%b' "${GRAY}Enter para volver al menu...${RESET}"
    read -r
}

capture() {
    local out
    out=$("$@" 2>&1) || true
    local line
    while IFS= read -r line; do log "$line"; done <<< "$out"
}

fetch() {
    local url="$1" alt body
    body=$(curl -sL --max-time "$TIMEOUT" -A "$UA" "$url" 2>/dev/null)
    if [[ -z "$body" ]]; then
        if [[ "$url" == https://* ]]; then
            alt="http://${url#https://}"
        elif [[ "$url" == http://* ]]; then
            alt="https://${url#http://}"
        else
            alt="http://$url"
        fi
        body=$(curl -sL --max-time "$TIMEOUT" -A "$UA" "$alt" 2>/dev/null)
    fi
    printf '%s' "$body"
}

http_code() {
    local url="$1" alt code
    code=$(curl -sL -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" -A "$UA" "$url" 2>/dev/null)
    if [[ "$code" == "000" || -z "$code" ]]; then
        if [[ "$url" == https://* ]]; then
            alt="http://${url#https://}"
        elif [[ "$url" == http://* ]]; then
            alt="https://${url#http://}"
        else
            alt="http://$url"
        fi
        code=$(curl -sL -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" -A "$UA" "$alt" 2>/dev/null)
    fi
    printf '%s' "$code"
}

# ===================== SUBDOMINIOS =====================

WORDLIST=(
    www mail api app admin panel dashboard backoffice internal intranet
    nequi mundial ventas saldo recarga soporte staging dev test demo
    cdn static assets files upload media img images js css gateway gw
    auth login oauth service services backend server node express
    portal secure billing pagos pago online tienda shop store
    blog help docs status metrics monitor grafana kibana jenkins git
    gitlab vpn proxy webmail smtp pop imap
    db database mysql postgres mongo redis cache rabbitmq
    mq queue worker cron job jobs task tasks scheduler
    mobile android ios api2 api3 v1 v2 v3
    ws websocket socket push notify notification sms email
    crm erp marketing ads banner
    sandbox qa uat pre prod produccion stage
    old new beta alpha next legacy backup temp tmp
    cdn1 cdn2 img1 static1 assets1 chat contacto info
)

# Enumera subdominios (CT logs + fuerza bruta). Escribe $OUT_DIR/01_subdomains.txt
# y deja el listado en el array global SUBDOMS.
enumerar_subdominios() {
    local outfile="$OUT_DIR/01_subdomains.txt"
    if [[ -s "$outfile" ]]; then
        SUBDOMS=()
        while IFS=$'\t' read -r h ip; do
            [[ -n "$h" ]] && SUBDOMS+=("$h")
        done < "$outfile"
        return 0
    fi

    note "Enumerando subdominios (CT logs + fuerza bruta)..."
    local info
    info=$(python3 - "$DOMAIN" "$outfile" "${WORDLIST[*]}" <<'PY'
import sys, json, socket, concurrent.futures, urllib.request
domain, outfile, wordlist = sys.argv[1], sys.argv[2], sys.argv[3].split()
ua = "Mozilla/5.0 (X11; Linux x86_64) AxonDevUI-OSINT"
names = set()

def get(url):
    try:
        req = urllib.request.Request(url, headers={'User-Agent': ua})
        return urllib.request.urlopen(req, timeout=20).read()
    except Exception:
        return None

# Certificate Transparency: certspotter
data = get('https://api.certspotter.com/v1/issuances?domain=%s&include_subdomains=true&expand=dns_names' % domain)
if data:
    try:
        for iss in json.loads(data):
            for n in (iss.get('dns_names') or []):
                names.add(n.lower().lstrip('*.'))
    except Exception:
        pass

# Certificate Transparency: crt.sh
data = get('https://crt.sh/?q=%%25.%s&output=json' % domain)
if data:
    try:
        for e in json.loads(data):
            for n in (e.get('name_value') or '').split('\n'):
                names.add(n.lower().lstrip('*.'))
    except Exception:
        pass

names = {n for n in names if n.endswith(domain) and '.' in n}

def resolve(host):
    try:
        infos = socket.getaddrinfo(host, None)
        return host, sorted({i[4][0] for i in infos})
    except Exception:
        return None

found = {}
with concurrent.futures.ThreadPoolExecutor(max_workers=30) as ex:
    for r in ex.map(resolve, [w + '.' + domain for w in wordlist]):
        if r:
            found[r[0]] = r[1]
with concurrent.futures.ThreadPoolExecutor(max_workers=20) as ex:
    for r in ex.map(resolve, names):
        if r:
            found[r[0]] = r[1]

with open(outfile, 'w') as f:
    for h in sorted(found):
        f.write('%s\t%s\n' % (h, ','.join(found[h])))
print('subdomains=%d' % len(found))
PY
)
    [[ -n "$info" ]] && note "$info"

    SUBDOMS=()
    while IFS=$'\t' read -r h ip; do
        [[ -n "$h" ]] && SUBDOMS+=("$h")
    done < "$outfile"
}

# ===================== [01] DNS RECON =====================

tool_dns() {
    LOGFILE="$OUT_DIR/01_dns.txt"
    section "DNS RECON :: $DOMAIN"

    if ! command -v dig >/dev/null 2>&1; then
        log "dig no disponible."
        return
    fi

    local t res
    for t in A AAAA MX NS TXT SOA CAA DNSKEY; do
        log ""
        log "----- $t -----"
        res=$(dig +noall +answer +authority "$DOMAIN" "$t" 2>/dev/null)
        if [[ -z "$res" ]]; then
            log "(sin registros $t)"
        else
            log "$res"
        fi
    done

    log ""
    log "----- CNAME -----"
    res=$(dig +noall +answer "$DOMAIN" CNAME 2>/dev/null)
    [[ -z "$res" ]] && res="(sin CNAME)"
    log "$res"

    log ""
    log "----- Subdominios (CT logs + fuerza bruta) -----"
    enumerar_subdominios
    log "Subdominios resueltos: ${#SUBDOMS[@]} (detalle en 01_subdomains.txt)"
    local sd
    for sd in "${SUBDOMS[@]}"; do
        log "  $sd"
    done

    log ""
    log "Guardado en $LOGFILE"
}

# ===================== [02] HTTP HEADERS =====================

tool_http_headers() {
    LOGFILE="$OUT_DIR/02_http_headers.txt"
    section "HTTP HEADERS :: $BASE_URL"

    local hdr code
    hdr=$(curl -sL -I --max-time "$TIMEOUT" -A "$UA" "$BASE_URL" 2>/dev/null)
    code=$(http_code "$BASE_URL")

    if [[ -z "$hdr" ]]; then
        log "Sin respuesta HTTP ($code)."
        return
    fi

    log "Estado: $code"
    log ""
    log "$hdr"

    log ""
    log "----- Analisis de cabeceras de seguridad -----"
    local h
    for h in "strict-transport-security" "content-security-policy" "x-frame-options" \
             "x-content-type-options" "referrer-policy" "permissions-policy" \
             "server" "x-powered-by"; do
        local v
        v=$(printf '%s\n' "$hdr" | grep -i "^$h:" | head -1 | sed -E "s/^$h: //I")
        if [[ -n "$v" ]]; then
            log "  [+] $h: $v"
        else
            log "  [-] $h: AUSENTE"
        fi
    done

    log ""
    log "Guardado en $LOGFILE"
}

# ===================== [03] TLS CERTIFICATE =====================

tool_tls() {
    LOGFILE="$OUT_DIR/03_tls.txt"
    section "TLS CERTIFICATE :: $DOMAIN"

    if ! command -v openssl >/dev/null 2>&1; then
        log "openssl no disponible."
        return
    fi

    local raw pem
    raw=$(timeout "$TIMEOUT" openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" </dev/null 2>/dev/null)
    if [[ -z "$raw" ]]; then
        log "No se pudo conectar por TLS a $DOMAIN:443"
        return
    fi

    pem=$(printf '%s\n' "$raw" | awk '/-----BEGIN CERTIFICATE-----/{f=1} f{print} /-----END CERTIFICATE-----/{f=0}')
    if [[ -z "$pem" ]]; then
        log "No se pudo extraer el certificado."
        return
    fi

    log ""
    log "Protocolo : $(printf '%s\n' "$raw" | awk -F': *' '/Protocol +:/{print $2; exit}')"
    log "Cipher    : $(printf '%s\n' "$raw" | awk -F': *' '/Cipher +:/{print $2; exit}')"
    log ""
    local opt val
    for opt in subject issuer startdate enddate serial fingerprint; do
        val=$(openssl x509 -noout -"$opt" <<< "$pem" 2>/dev/null)
        log "$opt: $val"
    done

    log ""
    log "----- Subject Alternative Names -----"
    capture openssl x509 -noout -ext subjectAltName <<< "$pem"

    log ""
    log "Guardado en $LOGFILE"
}

# ===================== [04] ROBOTS.TXT =====================

tool_robots() {
    LOGFILE="$OUT_DIR/04_robots.txt"
    section "ROBOTS.TXT :: $DOMAIN"

    local body code path
    for path in /robots.txt /robots; do
        code=$(http_code "$BASE_URL$path")
        if [[ "$code" =~ ^2|^3 ]]; then
            body=$(fetch "$BASE_URL$path")
            break
        fi
    done

    if [[ -z "$body" ]]; then
        log "No se encontro robots.txt ($code)."
        return
    fi

    log "Ubicacion: $BASE_URL$path ($code)"
    log ""
    log "$body"

    log ""
    log "----- Resumen -----"
    log "User-agent : $(printf '%s\n' "$body" | grep -ic '^user-agent')"
    log "Disallow   : $(printf '%s\n' "$body" | grep -ic '^disallow')"
    log "Allow      : $(printf '%s\n' "$body" | grep -ic '^allow')"
    log "Sitemap    : $(printf '%s\n' "$body" | grep -ic '^sitemap')"

    log ""
    log "Guardado en $LOGFILE"
}

# ===================== [05] SECURITY.TXT =====================

tool_security_txt() {
    LOGFILE="$OUT_DIR/05_security.txt"
    section "SECURITY.TXT :: $DOMAIN"

    local body code path used=""
    for path in /.well-known/security.txt /security.txt; do
        code=$(http_code "$BASE_URL$path")
        if [[ "$code" =~ ^2 ]]; then
            body=$(fetch "$BASE_URL$path")
            used="$path"
            break
        fi
    done

    if [[ -z "$body" ]]; then
        log "No se encontro security.txt ($code)."
        return
    fi

    log "Ubicacion: $BASE_URL$used ($code)"
    log ""
    log "$body"

    log ""
    log "----- Campos -----"
    local f
    for f in Contact Expires Encryption Acknowledgments Preferred-Languages Canonical Policy Hiring; do
        local v
        v=$(printf '%s\n' "$body" | grep -i "^$f:" | head -1 | sed -E "s/^$f: //I")
        if [[ -n "$v" ]]; then
            log "  [+] $f: $v"
        else
            log "  [-] $f: AUSENTE"
        fi
    done

    log ""
    log "Guardado en $LOGFILE"
}

# ===================== [06] SITEMAP MAPPER =====================

tool_sitemap() {
    LOGFILE="$OUT_DIR/06_sitemap_urls.txt"
    section "SITEMAP MAPPER :: $DOMAIN"

    local urls=()
    local robots
    robots=$(fetch "$BASE_URL/robots.txt")
    if [[ -n "$robots" ]]; then
        while IFS= read -r u; do
            [[ -n "$u" ]] && urls+=("$u")
        done < <(printf '%s\n' "$robots" | grep -i '^sitemap:' | sed -E 's/^[Ss]itemap: //')
    fi

    local candidates=(/sitemap.xml /sitemap_index.xml /sitemap.txt /sitemaps.xml /sitemap-index.xml)
    local c body
    local seen=""
    for c in "${candidates[@]}"; do
        [[ " $seen " == *" $c "* ]] && continue
        seen="$seen $c"
        if [[ "$(http_code "$BASE_URL$c")" =~ ^2 ]]; then
            body=$(fetch "$BASE_URL$c")
            if [[ -z "$body" ]]; then
                continue
            fi
            log "[*] $c -> extrayendo URLs"
            if [[ "$body" == *"<loc>"* ]]; then
                local loc
                while IFS= read -r loc; do
                    [[ -n "$loc" ]] && urls+=("$loc")
                done < <(printf '%s\n' "$body" | grep -oE '<loc>[^<]+</loc>' | sed -E 's#</?loc>##g')
            else
                while IFS= read -r loc; do
                    [[ -n "$loc" && "$loc" == http* ]] && urls+=("$loc")
                done <<< "$body"
            fi
        fi
    done

    local unique=()
    local u
    for u in "${urls[@]}"; do
        local dup=0 known
        for known in "${unique[@]}"; do
            [[ "$known" == "$u" ]] && dup=1 && break
        done
        [[ "$dup" -eq 0 ]] && unique+=("$u")
    done

    if [[ ${#unique[@]} -eq 0 ]]; then
        log "No se encontraron URLs en sitemaps."
        return
    fi

    log ""
    log "URLs unicas: ${#unique[@]}"
    log ""
    for u in "${unique[@]}"; do
        log "$u"
    done

    log ""
    log "Guardado en $LOGFILE"
}

# ===================== [07] JAVASCRIPT MAPPER =====================

tool_js_mapper() {
    local jdir="$OUT_DIR/07_js"
    mkdir -p "$jdir"
    LOGFILE="$OUT_DIR/07_js_files.txt"
    section "JAVASCRIPT MAPPER :: $DOMAIN"

    local html_file="$OUT_DIR/07_index.html"
    local html
    html=$(fetch "$BASE_URL")
    if [[ -z "$html" ]]; then
        log "No se pudo obtener el HTML base."
        return
    fi
    printf '%s' "$html" > "$html_file"
    log "HTML base: $html_file ($(wc -c < "$html_file") bytes)"

    local list_file="$OUT_DIR/07_scripts.list"
    local inline_count
    inline_count=$(python3 - "$html_file" "$list_file" "$BASE_URL" <<'PY'
import sys, re, html
from urllib.parse import urljoin
html_file, out_file, base = sys.argv[1], sys.argv[2], sys.argv[3]
data = open(html_file, encoding='utf-8', errors='ignore').read()
urls = []
for m in re.finditer(r'<script\b[^>]*\bsrc\s*=\s*("([^"]*)"|\'([^\']*)\'|([^\s>]+))', data, re.I):
    raw = (m.group(2) or m.group(3) or m.group(4) or '').strip()
    raw = html.unescape(raw)
    if not raw or raw.startswith('data:'):
        continue
    urls.append(urljoin(base, raw))
seen = []
for u in urls:
    if u not in seen:
        seen.append(u)
with open(out_file, 'w') as f:
    f.write('\n'.join(seen))
inline = len(re.findall(r'<script\b(?![^>]*\bsrc\b)[^>]*>(.*?)</script>', data, re.I | re.S))
print(inline)
PY
)

    local n_scripts
    n_scripts=$(grep -c . "$list_file" 2>/dev/null || true)
    log "Scripts externos: $n_scripts"
    log "Scripts inline  : $inline_count"

    local index_tsv="$jdir/index.tsv"
    : > "$index_tsv"

    local i=0 downloaded=0
    local u base name f
    while IFS= read -r u; do
        [[ -z "$u" ]] && continue
        i=$((i + 1))
        if (( i > 40 )); then
            log "(limite de 40 archivos JS alcanzado)"
            break
        fi
        base=$(printf '%s' "$u" | sed -E 's#^[a-zA-Z]+://##; s#\?.*$##; s#^.*/##; s#[^A-Za-z0-9._-]#_#g' | cut -c1-60)
        [[ -z "$base" ]] && base="script"
        name=$(printf 'js_%03d_%s.js' "$i" "$base")
        f="$jdir/$name"
        if curl -sL --max-time "$TIMEOUT" -A "$UA" "$u" -o "$f" 2>/dev/null && [[ -s "$f" ]]; then
            printf '%s\t%s\n' "$name" "$u" >> "$index_tsv"
            log "  [+] $u -> $name"
            downloaded=$((downloaded + 1))
        else
            rm -f "$f"
        fi
        sleep 0.2
    done < "$list_file"

    log "JS descargados: $downloaded en $jdir"

    if [[ "$downloaded" -gt 0 ]]; then
        local ep_file="$OUT_DIR/07_js_endpoints.txt"
        local ep_info
        ep_info=$(python3 - "$jdir" "$ep_file" "$BASE_URL" <<'PY'
import sys, os, re
jdir, out, base = sys.argv[1], sys.argv[2], sys.argv[3]
patterns = [
    r'https?://[^\s"\'`<>)\\]+',
    r'["\'`](/api/[a-zA-Z0-9_\-./?=&%:#]*)["\'`]',
    r'["\'`](/[a-zA-Z0-9_\-./?=&%:#]{4,})["\'`]',
]
results = {}
for fn in sorted(os.listdir(jdir)):
    if not fn.endswith('.js'):
        continue
    p = os.path.join(jdir, fn)
    try:
        d = open(p, encoding='utf-8', errors='ignore').read()
    except Exception:
        continue
    found = set()
    for pat in patterns:
        for m in re.findall(pat, d):
            v = m.strip().rstrip('.,;)')
            if v and len(v) > 3:
                found.add(v)
    if found:
        results[fn] = sorted(found)
with open(out, 'w') as f:
    for fn, items in results.items():
        f.write('### %s\n' % fn)
        for it in items:
            f.write(it + '\n')
        f.write('\n')
print('files_with_endpoints=%d total=%d' % (len(results), sum(len(v) for v in results.values())))
PY
)
        log "Endpoints: $ep_info"
        log "Endpoints guardados en $ep_file"
    fi

    log ""
    log "Guardado en $LOGFILE"
}

# ===================== [08] SOURCE MAP INSPECTOR =====================

tool_sourcemap() {
    local jdir="$OUT_DIR/07_js"
    local sdir="$OUT_DIR/08_sourcemaps"
    mkdir -p "$sdir/sources"
    LOGFILE="$OUT_DIR/08_sourcemap_report.txt"
    section "SOURCE MAP INSPECTOR :: $DOMAIN"

    if [[ ! -d "$jdir" ]]; then
        log "No hay JS. Ejecuta el modulo 07 primero."
        return
    fi

    local maps_list="$OUT_DIR/08_maps.list"
    local map_info
    map_info=$(python3 - "$jdir" "$BASE_URL" "$maps_list" <<'PY'
import sys, os, re, urllib.parse
jdir, base, outlist = sys.argv[1], sys.argv[2], sys.argv[3]
mapping = {}
idx = os.path.join(jdir, 'index.tsv')
if os.path.exists(idx):
    for line in open(idx, encoding='utf-8', errors='ignore'):
        if '\t' in line:
            name, url = line.rstrip('\n').split('\t', 1)
            mapping[name] = url
maps = []
for fn in sorted(os.listdir(jdir)):
    if not fn.endswith('.js'):
        continue
    p = os.path.join(jdir, fn)
    try:
        d = open(p, encoding='utf-8', errors='ignore').read()
    except Exception:
        continue
    m = re.search(r'sourceMappingURL=([^\s*\'"]+)', d)
    if not m:
        continue
    ref = m.group(1).strip()
    jsurl = mapping.get(fn, '')
    mapurl = urllib.parse.urljoin(jsurl or base, ref)
    maps.append((fn, mapurl))
with open(outlist, 'w') as f:
    for fn, mapurl in maps:
        f.write('%s\t%s\n' % (fn, mapurl))
print('map_refs=%d' % len(maps))
PY
)
    log "$map_info"

    local n=0
    local js mapurl
    while IFS=$'\t' read -r js mapurl; do
        [[ -z "$mapurl" ]] && continue
        local mfile="$sdir/map_$n.json"
        if curl -sL --max-time "$TIMEOUT" -A "$UA" "$mapurl" -o "$mfile" 2>/dev/null && [[ -s "$mfile" ]]; then
            log ""
            log "--- $mapurl ---"
            log "JS origen: $js"
            local ns
            ns=$(jq '.sources | length' "$mfile" 2>/dev/null)
            log "Fuentes: $ns"
            local sname
            while IFS= read -r sname; do
                [[ -n "$sname" ]] && log "  - $sname"
            done < <(jq -r '.sources[]?' "$mfile" 2>/dev/null)
            python3 - "$mfile" "$sdir/sources" <<'PY'
import sys, os, json, re
mfile, outdir = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(mfile, encoding='utf-8', errors='ignore'))
except Exception:
    sys.exit(0)
sources = data.get('sources') or []
contents = data.get('sourcesContent') or []
for i, (name, content) in enumerate(zip(sources, contents)):
    if content is None:
        continue
    safe = re.sub(r'[^A-Za-z0-9_.-]', '_', name)[:80] or ('src_%d' % i)
    with open(os.path.join(outdir, '%03d_%s' % (i, safe)), 'w', encoding='utf-8') as f:
        f.write(content)
PY
            n=$((n + 1))
        fi
    done < "$maps_list"

    log ""
    log "Source maps procesados: $n"
    log "Fuentes extraidas en $sdir/sources"
    log ""
    log "Guardado en $LOGFILE"
}

# ===================== [09] API DISCOVERY =====================

tool_api_discovery() {
    LOGFILE="$OUT_DIR/09_api_discovery.txt"
    section "API DISCOVERY :: $DOMAIN"
    enumerar_subdominios

    local hosts=("$DOMAIN")
    local s
    for s in "${SUBDOMS[@]}"; do
        [[ "$s" == "$DOMAIN" ]] && continue
        hosts+=("$s")
    done

    log "Hosts a analizar: ${#hosts[@]} (base + subdominios)"
    log ""

    local hostlist
    hostlist=$(printf '%s ' "${hosts[@]}")

    python3 - "$hostlist" <<'PY' | while IFS= read -r line; do log "$line"; done
import sys, requests, urllib3, functools
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
urllib3.disable_warnings()
print = functools.partial(print, flush=True)
hosts = sys.argv[1].split()
ua = "Mozilla/5.0 (X11; Linux x86_64) AxonDevUI-OSINT"
paths = [
    "/", "/api", "/api/", "/api/v1", "/api/v2", "/api/v3", "/api/health",
    "/graphql", "/graphql/", "/graphiql", "/api/graphql",
    "/swagger.json", "/swagger.yaml", "/swagger-ui", "/swagger-ui.html",
    "/api-docs", "/v2/api-docs", "/v3/api-docs", "/openapi.json", "/openapi.yaml",
    "/actuator", "/actuator/health", "/actuator/env", "/actuator/info",
    "/actuator/mappings", "/actuator/beans", "/actuator/configprops",
    "/.env", "/.env.local", "/.env.bak", "/.git/config", "/.git/HEAD",
    "/config.json", "/config.js", "/settings.json", "/package.json",
    "/composer.json", "/backup", "/backup.zip", "/db.sql", "/dump.sql",
    "/phpinfo.php", "/info.php", "/server-status", "/server-info", "/metrics",
    "/wp-json", "/wp-json/wp/v2/users", "/rest", "/internal", "/admin",
    "/debug", "/status", "/health", "/healthz", "/ready", "/live", "/version",
]
INTERESTING = (200, 204, 301, 302, 307, 308, 401, 403, 405, 500, 501)

def fetch(task):
    host, p = task
    for scheme in ("https", "http"):
        try:
            r = requests.get(scheme + "://" + host + p, headers={"User-Agent": ua},
                             timeout=4, allow_redirects=True, verify=False, stream=True)
            code = r.status_code
            ct = r.headers.get("content-type", "?").split(";")[0]
            clen = r.headers.get("content-length", "")
            size = int(clen) if clen.isdigit() else 0
            body = r.text[:2000] if (code in INTERESTING and "json" in ct.lower()) else ""
            r.close()
            return host, p, scheme, code, ct, size, body
        except Exception:
            continue
    return None

# Fase 1: alcanzabilidad por host (solo "/")
alive = set()
with ThreadPoolExecutor(max_workers=60) as ex:
    for res in ex.map(fetch, [(h, "/") for h in hosts]):
        if res:
            alive.add(res[0])
dead = [h for h in hosts if h not in alive]

# Fase 2: sondear rutas solo en hosts vivos
byhost = defaultdict(list)
with ThreadPoolExecutor(max_workers=60) as ex:
    for res in ex.map(fetch, [(h, p) for h in sorted(alive) for p in paths]):
        if not res:
            continue
        host, p, scheme, code, ct, size, body = res
        if code in INTERESTING:
            byhost[host].append((p, scheme, code, ct, size, body))

total = 0
for host in hosts:
    results = byhost.get(host, [])
    if not results:
        continue
    sig = Counter((code, ct) for _, _, code, ct, _, _ in results)
    dominant = None
    dom_n = 0
    if sig:
        (dom_code, dom_ct), dom_n = sig.most_common(1)[0]
        if dom_n >= 10 and dom_n >= 0.6 * max(1, len(results)):
            dominant = (dom_code, dom_ct)

    print("=== %s ===" % host)
    count = 0
    for p, scheme, code, ct, size, body in results:
        if dominant and code == dominant[0] and ct == dominant[1]:
            continue
        print("  [%s] %s://%s%s  ct=%s size=%s" % (code, scheme, host, p, ct, size))
        if body.strip():
            print("      %s" % body.strip().replace("\n", " ")[:600])
        count += 1
    if dominant:
        print("  (respuesta dominante/WAF: %d rutas -> %s %s)" % (dom_n, dominant[0], dominant[1]))
    print("  -> %d endpoints distintos" % count)
    total += count
    print("")

if dead:
    print("Hosts sin respuesta (%d): %s" % (len(dead), ", ".join(dead)))
print("")
print("Hosts vivos: %d | endpoints distintos: %d" % (len(alive), total))
PY

    log ""
    log "Guardado en $LOGFILE"
}

# ===================== [10] JS <-> API MAPPER =====================

tool_js_api_mapper() {
    LOGFILE="$OUT_DIR/10_js_api_map.txt"
    section "JS <-> API MAPPER :: $DOMAIN"

    if [[ ! -d "$OUT_DIR/07_js" ]]; then
        log "No hay JS. Ejecuta el modulo 07 primero."
        return
    fi

    python3 - "$OUT_DIR" "$BASE_URL" <<'PY' | while IFS= read -r line; do log "$line"; done
import sys, os, re
from urllib.parse import urljoin, urlparse
outdir, base = sys.argv[1], sys.argv[2]
jdir = os.path.join(outdir, '07_js')
mapping = {}
idx = os.path.join(jdir, 'index.tsv')
if os.path.exists(idx):
    for line in open(idx, encoding='utf-8', errors='ignore'):
        if '\t' in line:
            n, u = line.rstrip('\n').split('\t', 1)
            mapping[n] = u

api_paths = []
api_file = os.path.join(outdir, '09_api_discovery.txt')
if os.path.exists(api_file):
    for line in open(api_file, encoding='utf-8', errors='ignore'):
        m = re.match(r'\s*\[\d+\]\s+(\S+)', line)
        if m:
            api_paths.append(m.group(1))

call_re = re.compile(
    r'(fetch|axios(?:\.\w+)?|XMLHttpRequest|\$\.(?:get|post|ajax|put|delete)|http\.(?:get|post|request)|request)\s*\(\s*([\'"`])([^\'"`\s]+)\2', re.I)
str_re = re.compile(r'([\'"`])((?:https?://|/)[^\'"`\s]{3,})\1')
api_hint = ('api', 'graphql', 'rest', 'v1', 'v2', 'v3', 'json', 'admin', 'internal', 'auth', 'login', 'user', 'data')

rows = []
seen = set()
for fn in sorted(os.listdir(jdir)):
    if not fn.endswith('.js'):
        continue
    try:
        d = open(os.path.join(jdir, fn), encoding='utf-8', errors='ignore').read()
    except Exception:
        continue
    jsurl = mapping.get(fn, base)
    for m in call_re.finditer(d):
        kind, ep = m.group(1), m.group(3)
        resolved = urljoin(jsurl, ep)
        host = urlparse(resolved).netloc or urlparse(base).netloc
        internal = host == urlparse(base).netloc
        if (fn, ep) in seen:
            continue
        seen.add((fn, ep))
        rows.append((fn, kind, ep, resolved, host, 'INTERNO' if internal else 'EXTERNO'))
    for m in str_re.finditer(d):
        ep = m.group(2)
        if not any(k in ep.lower() for k in api_hint):
            continue
        resolved = urljoin(jsurl, ep)
        host = urlparse(resolved).netloc or urlparse(base).netloc
        internal = host == urlparse(base).netloc
        if (fn, ep) in seen:
            continue
        seen.add((fn, ep))
        rows.append((fn, 'string', ep, resolved, host, 'INTERNO' if internal else 'EXTERNO'))

print("Llamadas/endpoints detectados en JS: %d" % len(rows))
print("")
for fn, kind, ep, resolved, host, typ in rows:
    print("[%s] %s :: %s -> %s (%s)" % (typ, fn, kind, ep, host))
print("")
print("=== Cruce con APIs descubiertas (09) ===")
matched = 0
for fn, kind, ep, resolved, host, typ in rows:
    for ap in api_paths:
        if ap.rstrip('/') and ap.rstrip('/') in resolved:
            print("  [MATCH] %s :: %s  <->  %s" % (fn, ep, ap))
            matched += 1
            break
print("Coincidencias: %d" % matched)
PY

    log ""
    log "Guardado en $LOGFILE"
}

# ===================== [11] KEY EXTRACTOR =====================

tool_key_extractor() {
    local ddir="$OUT_DIR/11_decoded"
    mkdir -p "$ddir"
    LOGFILE="$OUT_DIR/11_keys.txt"
    section "KEY EXTRACTOR :: $DOMAIN"

    if [[ ! -d "$OUT_DIR/07_js" && ! -f "$OUT_DIR/07_index.html" ]]; then
        log "No hay JS/HTML. Ejecuta el modulo 07 primero."
        return
    fi

    python3 - "$OUT_DIR" "$ddir" <<'PY' | while IFS= read -r line; do log "$line"; done
import sys, os, re, json, base64
outdir, ddir = sys.argv[1], sys.argv[2]
jdir = os.path.join(outdir, '07_js')
htmlf = os.path.join(outdir, '07_index.html')
sdir = os.path.join(outdir, '08_sourcemaps')
files = []
if os.path.isdir(jdir):
    files += [os.path.join(jdir, f) for f in sorted(os.listdir(jdir)) if f.endswith('.js')]
if os.path.isfile(htmlf):
    files.append(htmlf)
if os.path.isdir(sdir):
    for root, _, fs in os.walk(sdir):
        files += [os.path.join(root, f) for f in fs if f.endswith(('.json', '.txt'))]

def b64url(s):
    s += '=' * (-len(s) % 4)
    return base64.urlsafe_b64decode(s)

def try_b64(s):
    s2 = s + '=' * (-len(s) % 4)
    try:
        return base64.b64decode(s2)
    except Exception:
        return None

jwt_re = re.compile(r'eyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}')
b64_re = re.compile(r'[A-Za-z0-9+/]{24,}={0,2}')
hex_re = re.compile(r'\b[0-9a-fA-F]{32,}\b')
assign_re = re.compile(r'(?i)(client[_-]?id|client[_-]?secret|api[_-]?key|api[_-]?secret|secret[_-]?key|access[_-]?token|auth[_-]?token|public[_-]?key|private[_-]?key|consumer[_-]?key)["\']?\s*[:=]\s*["\']([A-Za-z0-9_\-\.]{8,})["\']')
atob_re = re.compile(r'atob\(\s*["\']([A-Za-z0-9+/=]{12,})["\']\s*\)')
charcode_re = re.compile(r'String\.fromCharCode\(([^)]{4,})\)')

jwt_out, b64_out, hex_out, assign_out, atob_out, charcode_out = [], [], [], [], [], []
seen = set()
saved = []

def add(lst, key, *vals):
    item = (key, vals)
    if item in seen:
        return
    seen.add(item)
    lst.append(item)

for fp in files:
    try:
        d = open(fp, encoding='utf-8', errors='ignore').read()
    except Exception:
        continue
    rel = os.path.relpath(fp, os.getcwd())

    for m in jwt_re.findall(d):
        if m in seen:
            continue
        seen.add(m)
        try:
            h = json.loads(b64url(m.split('.')[0]))
            p = json.loads(b64url(m.split('.')[1]))
        except Exception:
            h = p = None
        jwt_out.append((rel, m, h, p))

    for m in b64_re.findall(d):
        if m in seen:
            continue
        dec = try_b64(m)
        if not dec:
            continue
        try:
            txt = dec.decode('utf-8')
        except Exception:
            continue
        printable = sum(c.isprintable() or c in '\n\r\t' for c in txt) / max(1, len(txt))
        if printable > 0.85 and len(txt) >= 6:
            seen.add(m)
            b64_out.append((rel, m, txt[:200]))
            fn = 'b64_%d.txt' % len(saved)
            try:
                open(os.path.join(ddir, fn), 'w', encoding='utf-8').write(txt)
                saved.append(fn)
            except Exception:
                pass

    for m in hex_re.findall(d):
        if m in seen:
            continue
        try:
            txt = bytes.fromhex(m).decode('utf-8')
        except Exception:
            continue
        printable = sum(c.isprintable() or c in '\n\r\t' for c in txt) / max(1, len(txt))
        if printable > 0.85 and len(txt) >= 8:
            seen.add(m)
            hex_out.append((rel, m, txt[:200]))

    for m in assign_re.finditer(d):
        add(assign_out, m.group(1), rel, m.group(2))

    for m in atob_re.finditer(d):
        dec = try_b64(m.group(1))
        if dec:
            try:
                add(atob_out, m.group(1), rel, dec.decode('utf-8', 'replace')[:200])
            except Exception:
                pass

    for m in charcode_re.finditer(d):
        try:
            nums = [int(x) for x in re.findall(r'\d+', m.group(1))]
            txt = ''.join(chr(n) for n in nums)
        except Exception:
            continue
        if txt.strip():
            add(charcode_out, txt, rel)

def dump(title, items, fmt):
    print("")
    print("===== %s (%d) =====" % (title, len(items)))
    if not items:
        print("  (sin resultados)")
        return
    for it in items:
        print(fmt(it))

dump("JWT", jwt_out, lambda x: "  [%s]\n    token: %s\n    header: %s\n    payload: %s" % (x[0], x[1], json.dumps(x[2]), json.dumps(x[3])))
dump("BASE64", b64_out, lambda x: "  [%s]\n    %s => %s" % (x[0], x[1][:80], x[2]))
dump("HEX", hex_out, lambda x: "  [%s]\n    %s => %s" % (x[0], x[1][:80], x[2]))
dump("ASIGNACIONES (client id / secret / key)", assign_out, lambda x: "  [%s] %s = %s" % (x[1][0], x[0], x[1][1]))
dump("ATOB (deobfuscado)", atob_out, lambda x: "  [%s] %s => %s" % (x[1][0], x[0][:60], x[1][1]))
dump("FROMCHARCODE (deobfuscado)", charcode_out, lambda x: "  [%s] %s" % (x[1], x[0][:200]))

print("")
print("Bloques Base64 guardados en: %s (%d)" % (ddir, len(saved)))
print("Total JWT=%d BASE64=%d HEX=%d ASIG=%d ATOB=%d CHARCODE=%d" % (
    len(jwt_out), len(b64_out), len(hex_out), len(assign_out), len(atob_out), len(charcode_out)))
PY

    # Claves expuestas en respuestas de APIs (base + subdominios)
    enumerar_subdominios
    local rhosts=("$DOMAIN")
    local s
    for s in "${SUBDOMS[@]}"; do
        [[ "$s" == "$DOMAIN" ]] && continue
        rhosts+=("$s")
    done
    local rhostlist
    rhostlist=$(printf '%s ' "${rhosts[@]}")

    log ""
    log "----- Claves en respuestas de API (base + subdominios) -----"
    local api_file="$OUT_DIR/09_api_discovery.txt"
    python3 - "$rhostlist" "$api_file" "$OUT_DIR/11_api_keys.txt" <<'PY' | while IFS= read -r line; do log "$line"; done
import sys, os, re, json, requests, urllib3
urllib3.disable_warnings()
hosts = sys.argv[1].split()
api_file, out = sys.argv[2], sys.argv[3]
ua = "Mozilla/5.0 (X11; Linux x86_64) AxonDevUI-OSINT"
sess = requests.Session()
sess.headers.update({'User-Agent': ua})

urls = []
if os.path.exists(api_file):
    for line in open(api_file, encoding='utf-8', errors='ignore'):
        m = re.search(r'https?://\S+', line)
        if m:
            u = m.group(0).strip()
            if u not in urls:
                urls.append(u)
for h in hosts:
    for sch in ('https', 'http'):
        u = '%s://%s/' % (sch, h)
        if u not in urls:
            urls.append(u)

key_re = re.compile(r'(?i)(client[_-]?id|client[_-]?secret|api[_-]?key|api[_-]?secret|secret|token|appid|app[_-]?id|appkey|access[_-]?key|private[_-]?key|authorization|password)["\']?\s*[:=]\s*["\']?([A-Za-z0-9_\-\.]{4,})')
lines = set()
for url in urls:
    try:
        r = sess.get(url, timeout=6, allow_redirects=True, verify=False)
    except Exception:
        continue
    if r.status_code not in (200, 204):
        continue
    body = r.text
    for m in key_re.finditer(body):
        lines.add('[%s] %s = %s' % (url, m.group(1), m.group(2)[:80]))
    try:
        data = json.loads(body)
        if isinstance(data, dict):
            for k, v in data.items():
                if isinstance(v, (str, int, float)) and re.search(r'(?i)(key|secret|token|client|app|user|id|pass|auth)', k):
                    lines.add('[%s] JSON %s = %s' % (url, k, str(v)[:80]))
    except Exception:
        pass
with open(out, 'w') as f:
    f.write('\n'.join(sorted(lines)))
print('urls_analizadas=%d api_key_findings=%d' % (len(urls), len(lines)))
PY
    log "Detalle en $OUT_DIR/11_api_keys.txt"

    log ""
    log "Nota: verifica siempre manualmente; los patrones genericos pueden dar falsos positivos."
    log "Guardado en $LOGFILE"
}

# ===================== [12] PHISHING DETECTION =====================

tool_phishing() {
    LOGFILE="$OUT_DIR/12_phishing.txt"
    section "PHISHING DETECTION :: $DOMAIN"

    local REF=""
    printf '%b' "${PURPLE}${BOLD}Dominio de referencia (Enter = heuristica sin referencia): ${RESET}"
    read -r REF
    REF="${REF%/}"
    if [[ -n "$REF" && ! "$REF" =~ ^https?:// ]]; then
        REF="https://$REF"
    fi
    local refdomain=""
    if [[ -n "$REF" ]]; then
        refdomain=$(printf '%s' "$REF" | sed -E 's#^https?://##; s#/.*##; s/:.*//')
    fi

    python3 - "$BASE_URL" "$REF" "$DOMAIN" "$refdomain" <<'PY' | while IFS= read -r line; do log "$line"; done
import sys, re, hashlib, subprocess, difflib, datetime
import requests, urllib3
from bs4 import BeautifulSoup
urllib3.disable_warnings()

target_url, ref_url, target, ref = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
ua = "Mozilla/5.0 (X11; Linux x86_64) AxonDevUI-OSINT"

def fetch(url):
    try:
        return requests.get(url, headers={'User-Agent': ua}, timeout=12,
                            verify=False, allow_redirects=True)
    except Exception:
        return None

def analyze(url):
    r = fetch(url)
    if r is None:
        return None
    soup = BeautifulSoup(r.text, 'lxml')
    title = soup.title.get_text(strip=True) if soup.title else ''
    m = soup.find('meta', attrs={'name': 'description'})
    meta = m.get('content', '') if m else ''
    heads = ' '.join(h.get_text(' ', strip=True) for h in soup.find_all(['h1', 'h2', 'h3']))
    forms = [f.get('action', '') for f in soup.find_all('form')]
    hosts = set()
    for tag, attr in [('script', 'src'), ('link', 'href'), ('img', 'src'),
                      ('iframe', 'src'), ('form', 'action')]:
        for t in soup.find_all(tag):
            v = t.get(attr)
            if v and v.startswith('http'):
                hosts.add(v.split('/')[2])
    fav = soup.find('link', rel=lambda x: x and 'icon' in x)
    favhash = ''
    if fav and fav.get('href'):
        fu = fav['href']
        if not fu.startswith('http'):
            fu = url.rstrip('/') + '/' + fu.lstrip('/')
        fr = fetch(fu)
        if fr is not None and fr.content:
            favhash = hashlib.sha256(fr.content).hexdigest()[:16]
    text = soup.get_text(' ', strip=True)
    words = set(re.findall(r'[a-zA-Z]{4,}', text.lower()))
    return {'title': title, 'meta': meta, 'heads': heads, 'forms': forms,
            'hosts': hosts, 'fav': favhash, 'words': words, 'text': text,
            'status': r.status_code, 'url': r.url}

t = analyze(target_url)
if t is None:
    print("No se pudo obtener el sitio objetivo.")
    sys.exit(0)

print("Sitio objetivo : %s (HTTP %s)" % (target_url, t['status']))
print("Titulo         : %s" % (t['title'][:120] or '(sin titulo)'))
print("Meta desc      : %s" % (t['meta'][:120] or '(sin meta)'))
print("Hosts externos : %d" % len(t['hosts']))
print("Favicon sha256 : %s" % (t['fav'] or 'n/a'))
print("Formularios    : %d" % len(t['forms']))
print("")

brands = ['google', 'facebook', 'instagram', 'whatsapp', 'microsoft', 'apple',
          'amazon', 'paypal', 'netflix', 'outlook', 'gmail', 'yahoo', 'dropbox',
          'linkedin', 'twitter', 'tiktok', 'visa', 'mastercard', 'santander',
          'bbva', 'interbank', 'pichincha', 'bcp', 'mercadolibre', 'mercadopago',
          'reniec', 'sunat', 'onpe', 'dni', 'bank', 'banco', 'login', 'iniciar sesion']
content = (t['title'] + ' ' + t['text']).lower()
hits = [b for b in brands if b in content]
print("Marcas detectadas en contenido: %s" % (', '.join(hits) if hits else 'ninguna'))
print("")

if ref:
    r = analyze(ref_url)
    if r is None:
        print("No se pudo obtener el sitio de referencia.")
        sys.exit(0)
    print("=== COMPARACION DIRECTA CON %s ===" % ref)
    print("Titulo ref     : %s" % (r['title'][:120] or '(sin titulo)'))
    def sim(a, b):
        return difflib.SequenceMatcher(None, a.lower(), b.lower()).ratio()
    s_title = sim(t['title'], r['title'])
    s_meta = sim(t['meta'], r['meta'])
    s_text = sim(t['text'][:4000], r['text'][:4000])
    s_words = (len(t['words'] & r['words']) / len(t['words'] | r['words'])) if (t['words'] and r['words']) else 0.0
    fav_match = 1.0 if (t['fav'] and t['fav'] == r['fav']) else 0.0
    s_hosts = (len(t['hosts'] & r['hosts']) / len(t['hosts'] | r['hosts'])) if (t['hosts'] and r['hosts']) else 0.0
    score = s_title * 25 + s_meta * 10 + s_text * 30 + s_words * 15 + fav_match * 10 + s_hosts * 10
    print("Similitud titulo : %.0f%%" % (s_title * 100))
    print("Similitud meta   : %.0f%%" % (s_meta * 100))
    print("Similitud texto  : %.0f%%" % (s_text * 100))
    print("Similitud tokens : %.0f%%" % (s_words * 100))
    print("Favicon identico : %s" % ('SI' if fav_match else 'NO'))
    print("Hosts en comun   : %.0f%%" % (s_hosts * 100))
    print("")
    print("SCORE DE CLONADO : %.0f/100" % score)
    verdict = 'ALTA probabilidad de PHISHING' if score >= 70 else ('MEDIA sospecha' if score >= 45 else 'BAJA sospecha')
    print("VEREDICTO        : %s" % verdict)
else:
    print("=== ANALISIS HEURISTICO (sin referencia) ===")
    points = 0
    created = None
    try:
        w = subprocess.run(['whois', target], capture_output=True, text=True, timeout=20)
        for line in w.stdout.splitlines():
            low = line.lower()
            if any(k in low for k in ['creation date', 'created on', 'created date',
                                      'registered on', 'registration time']):
                m = re.search(r'(\d{4}-\d{2}-\d{2}|\d{2}-[a-z]{3}-\d{4})', line)
                if m:
                    created = m.group(1)
                    break
    except Exception:
        pass
    print("Fecha creacion WHOIS: %s" % (created or 'no disponible'))
    age_days = None
    if created:
        for fmt in ('%Y-%m-%d', '%d-%b-%Y'):
            try:
                cd = datetime.datetime.strptime(created, fmt)
                age_days = (datetime.datetime.now() - cd).days
                break
            except Exception:
                continue
        if age_days is not None:
            print("Antiguedad: %d dias" % age_days)
            if age_days < 180:
                points += 25
                print("  [!] Dominio muy reciente (+25)")
            elif age_days < 365:
                points += 10
                print("  [!] Dominio menor a 1 anio (+10)")
    tlds = ['.tk', '.ml', '.ga', '.cf', '.gq', '.xyz', '.top', '.club', '.work',
            '.date', '.racing', '.win', '.bid', '.loan', '.download']
    if any(target.endswith(x) for x in tlds):
        points += 15
        print("  [!] TLD frecuentemente abusado (+15)")
    if hits:
        points += 15
        print("  [!] Nombre de marca en contenido (+15)")
    print("")
    print("PUNTOS DE RIESGO: %d" % points)
    verdict = 'ALTA probabilidad de PHISHING' if points >= 40 else ('MEDIA sospecha' if points >= 20 else 'BAJA sospecha')
    print("VEREDICTO       : %s" % verdict)

print("")
print("Nota: un score alto indica clonacion/visual muy parecida; verifica siempre de forma manual.")
PY

    log ""
    log "Guardado en $LOGFILE"
}

# ===================== DISPATCHER =====================

ejecutar() {
    case "$OPCION" in
        1)  tool_dns ;;
        2)  tool_http_headers ;;
        3)  tool_tls ;;
        4)  tool_robots ;;
        5)  tool_security_txt ;;
        6)  tool_sitemap ;;
        7)  tool_js_mapper ;;
        8)  tool_sourcemap ;;
        9)  tool_api_discovery ;;
        10) tool_js_api_mapper ;;
        11) tool_key_extractor ;;
        12) tool_phishing ;;
    esac
}

# ===================== MAIN =====================

main() {
    while true; do
        banner
        seleccionar_herramienta

        case "$OPCION" in
            0)
                echo -e "${PINK}Cerrando AxonDevUI.${RESET}"
                break
                ;;

            1|2|3|4|5|6|7|8|9|10|11|12)
                if ! solicitar_dominio; then
                    pause
                    continue
                fi

                ejecutar "$OPCION"

                echo
                pause
                ;;

            *)
                echo -e "${RED}Opcion no valida.${RESET}"
                sleep 1
                ;;
        esac
    done
}

main
