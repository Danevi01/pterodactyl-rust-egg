#!/bin/bash
# Installations-Script (läuft einmalig im Pterodactyl-Installer-Container, Serverdateien: /mnt/server)
# Lädt SteamCMD und die Rust-Serverdateien. Framework-Installation und Updates übernimmt /entrypoint.sh im Image.
set -euo pipefail

SRCDS_APPID=258550

VERSION_LC="$(echo "${VERSION:-public}" | tr '[:upper:]' '[:lower:]')"
case "$VERSION_LC" in
    aux01|aux01-staging) BRANCH="aux01" ;;
    aux02)               BRANCH="aux02" ;;
    staging)             BRANCH="staging" ;;
    release)             BRANCH="release" ;;
    *)                   BRANCH="public" ;;
esac
echo "Steam-Branch: ${BRANCH}"

BETA=()
if [ "$BRANCH" != "public" ]; then
    BETA=(-beta "$BRANCH")
fi

cd /tmp
mkdir -p /mnt/server/steamcmd /mnt/server/steamapps
curl -sSL -o steamcmd.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
tar -xzf steamcmd.tar.gz -C /mnt/server/steamcmd
cd /mnt/server/steamcmd

# SteamCMD scheitert sonst teilweise an Besitzer/HOME, auch als root
chown -R root:root /mnt
export HOME=/mnt/server

./steamcmd.sh +force_install_dir /mnt/server +login anonymous +app_update "${SRCDS_APPID}" ${BETA[@]+"${BETA[@]}"} validate +quit

mkdir -p /mnt/server/.steam/sdk32 /mnt/server/.steam/sdk64
cp -v linux32/steamclient.so /mnt/server/.steam/sdk32/steamclient.so
cp -v linux64/steamclient.so /mnt/server/.steam/sdk64/steamclient.so

echo "Installation abgeschlossen."
