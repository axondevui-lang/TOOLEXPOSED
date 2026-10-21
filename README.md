# TOOLEXPOSED

Toolkit OSINT en **Bash** para enumeración de dominios, descubrimiento de APIs internas,
extracción de claves y detección de phishing. Pensado para **Termux** y **Kali Linux**.

> **Aviso legal:** usa esta herramienta **solo** sobre dominios propios o con
> autorización expresa del propietario. El escaneo no autorizado puede ser ilegal.

---

## Modulos (12)

| # | Modulo | Descripcion |
|---|--------|-------------|
| 01 | DNS Recon | Registros A/AAAA/MX/NS/TXT/SOA/CAA, CNAME y enumeracion de subdominios (CT logs + fuerza bruta) |
| 02 | HTTP Headers | Cabeceras y analisis de seguridad (CSP, HSTS, X-Frame, etc.) |
| 03 | TLS Certificate | Protocolo, cipher, sujeto, emisor, validez, SAN, fingerprint |
| 04 | Robots.txt | Descarga y resumen (User-agent, Allow, Disallow, Sitemap) |
| 05 | Security.txt | Campos de `/.well-known/security.txt` |
| 06 | Sitemap Mapper | Extrae URLs de sitemaps y de `robots.txt` |
| 07 | JavaScript Mapper | Descarga los JS del dominio y extrae endpoints |
| 08 | Source Map Inspector | Extrae fuentes originales de los `.map` |
| 09 | API Discovery | Sondea APIs internas/expuestas en el dominio base **y en los subdominios** |
| 10 | JS <-> API Mapper | Cruza endpoints hallados en los JS con las APIs internas |
| 11 | Key Extractor | JWT, Base64/Hex, client IDs, secretos, deobfuscacion JS y claves en respuestas de API |
| 12 | Phishing Detection | Con dominio de referencia (score de similitud) o heuristico (whois + antiguedad + marcas) |

---

## Requisitos

- `bash`, `curl`, `openssl`, `jq`, `whois`, `dig`
- `python3` con: `requests`, `beautifulsoup4`, `lxml`
- `git` (para clonar)

---

## Instalacion en Termux

Abre Termux y ejecuta:

```bash
# 1. Actualizar el sistema de paquetes
pkg update -y && pkg upgrade -y

# 2. Instalar dependencias del sistema
#    (bind-tools aporta dig/nslookup/host; whois para el modulo de phishing)
pkg install -y curl openssl jq python git whois bind-tools

# 3. Instalar dependencias de Python
pip install --upgrade pip
pip install requests beautifulsoup4 lxml

# 4. Clonar el repositorio
git clone https://github.com/axondevui-lang/TOOLEXPOSED.git
cd TOOLEXPOSED

# 5. Dar permiso de ejecucion y correr
chmod +x toolaxonosint.sh
./toolaxonosint.sh
```

**Todo en una sola linea:**

```bash
pkg update -y && pkg upgrade -y && pkg install -y curl openssl jq python git whois bind-tools && pip install --upgrade pip && pip install requests beautifulsoup4 lxml && git clone https://github.com/axondevui-lang/TOOLEXPOSED.git && cd TOOLEXPOSED && chmod +x toolaxonosint.sh && ./toolaxonosint.sh
```

O usa el instalador incluido:

```bash
chmod +x install-termux.sh && ./install-termux.sh
```

---

## Instalacion en Kali Linux

Abre una terminal y ejecuta:

```bash
# 1. Actualizar el sistema
sudo apt update && sudo apt upgrade -y

# 2. Instalar dependencias del sistema
#    (dnsutils aporta dig/host/nslookup)
sudo apt install -y curl dnsutils openssl jq python3 python3-pip whois git

# 3. Instalar dependencias de Python
pip3 install requests beautifulsoup4 lxml

# 4. Clonar el repositorio
git clone https://github.com/axondevui-lang/TOOLEXPOSED.git
cd TOOLEXPOSED

# 5. Dar permiso de ejecucion y correr
chmod +x toolaxonosint.sh
./toolaxonosint.sh
```

**Todo en una sola linea:**

```bash
sudo apt update && sudo apt upgrade -y && sudo apt install -y curl dnsutils openssl jq python3 python3-pip whois git && pip3 install requests beautifulsoup4 lxml && git clone https://github.com/axondevui-lang/TOOLEXPOSED.git && cd TOOLEXPOSED && chmod +x toolaxonosint.sh && ./toolaxonosint.sh
```

O usa el instalador incluido:

```bash
chmod +x install-kali.sh && sudo ./install-kali.sh
```

---

## Uso

1. Ejecuta `./toolaxonosint.sh`.
2. Elige una opcion del menu (1 al 12).
3. Ingresa el dominio autorizado, por ejemplo: `example.com`
   - Si escribistes `www.example.com`, se normaliza a `example.com`.
4. Los resultados se guardan en `axondevui_<dominio>/` en archivos `.txt`.

Flujo recomendado para encontrar APIs internas:

```
01 DNS Recon          -> enumera subdominios (01_subdomains.txt)
09 API Discovery      -> sondea APIs en base + subdominios
10 JS <-> API Mapper  -> cruza endpoints de los JS con las APIs
11 Key Extractor      -> extrae claves/client IDs/secretos
12 Phishing Detection -> evalua riesgo de phishing
```

---

## Solucion de problemas

| Problema | Solucion |
|----------|----------|
| `dig: command not found` (Termux) | `pkg install bind-tools` |
| `dig: command not found` (Kali) | `sudo apt install dnsutils` |
| `whois: command not found` | `pkg install whois` / `sudo apt install whois` |
| Errores de SSL en Python | `pip install --upgrade requests urllib3` |
| `ModuleNotFoundError: bs4` | `pip install beautifulsoup4 lxml` |
| 403 en todos los endpoints | El objetivo tiene WAF (Cloudflare, Imperva). La herramienta lo detecta como "respuesta dominante/WAF". |

---

## Estructura de salida

```
axondevui_<dominio>/
  01_dns.txt
  01_subdomains.txt
  02_http_headers.txt
  03_tls.txt
  04_robots.txt
  05_security.txt
  06_sitemap_urls.txt
  07_index.html
  07_js/                 (JS descargados)
  07_js_files.txt
  07_js_endpoints.txt
  08_sourcemap_report.txt
  08_sourcemaps/         (fuentes extraidas)
  09_api_discovery.txt
  10_js_api_map.txt
  11_keys.txt
  11_api_keys.txt
  11_decoded/            (bloques Base64 decodificados)
  12_phishing.txt
```
