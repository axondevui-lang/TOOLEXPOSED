#!/data/data/com.termux/files/usr/bin/bash
#
# TOOLEXPOSED - Instalador para Termux
#
set -e

echo "==> [1/4] Actualizando paquetes de Termux..."
pkg update -y
pkg upgrade -y

echo "==> [2/4] Instalando dependencias del sistema..."
# bind-tools aporta dig/nslookup/host
pkg install -y curl openssl jq python git whois bind-tools

echo "==> [3/4] Instalando dependencias de Python..."
pip install --upgrade pip
pip install requests beautifulsoup4 lxml

echo "==> [4/4] Preparando la herramienta..."
chmod +x toolaxonosint.sh

echo
echo "Instalacion completada."
echo "Ejecuta:  ./toolaxonosint.sh"
