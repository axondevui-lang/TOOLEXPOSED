#!/usr/bin/env bash
#
# TOOLEXPOSED - Instalador para Kali Linux
#
set -e

if [[ $EUID -ne 0 ]]; then
    echo "Ejecuta este script como root:  sudo ./install-kali.sh"
    exit 1
fi

echo "==> [1/4] Actualizando el sistema..."
apt update
apt upgrade -y

echo "==> [2/4] Instalando dependencias del sistema..."
# dnsutils aporta dig/host/nslookup
apt install -y curl dnsutils openssl jq python3 python3-pip whois git

echo "==> [3/4] Instalando dependencias de Python..."
pip3 install requests beautifulsoup4 lxml

echo "==> [4/4] Preparando la herramienta..."
chmod +x toolaxonosint.sh

echo
echo "Instalacion completada."
echo "Ejecuta:  ./toolaxonosint.sh"
