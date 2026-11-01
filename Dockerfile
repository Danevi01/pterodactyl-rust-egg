# =============================================================================
# Rust Dedicated Server – eigenes Pterodactyl-Image
# Basis: Debian bookworm + Node 22 (Node wird nur für den RCON-Wrapper benötigt)
# =============================================================================
FROM node:22-bookworm-slim

LABEL org.opencontainers.image.source="https://github.com/Danevi01/pterodactyl-rust-egg" \
      org.opencontainers.image.description="Rust Dedicated Server (Vanilla/Oxide/Carbon) für Pterodactyl"

ARG DEBIAN_FRONTEND=noninteractive

# 32-Bit-Bibliotheken für SteamCMD, SDL2 + libgdiplus für den Rust-Server
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip tar gzip iproute2 tzdata locales libgdiplus \
        lib32gcc-s1 lib32stdc++6 libsdl2-2.0-0:i386 \
    && sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

# SteamCMD als schreibgeschützte Vorlage; wird beim ersten Start nach /home/container/steamcmd kopiert
RUN mkdir -p /opt/steamcmd \
    && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
       | tar -xz -C /opt/steamcmd \
    && chmod -R a+rX /opt/steamcmd

# RCON-Wrapper (Konsoleneingabe über WebRCON)
RUN mkdir -p /wrapper \
    && cd /wrapper \
    && npm init -y >/dev/null 2>&1 \
    && npm install --omit=dev --no-audit --no-fund ws@8 \
    && chmod -R a+rX /wrapper

COPY wrapper.js /wrapper/wrapper.js
COPY entrypoint.sh /entrypoint.sh
RUN chmod a+rx /wrapper/wrapper.js /entrypoint.sh

RUN useradd -d /home/container -m container

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    USER=container \
    HOME=/home/container

USER container
WORKDIR /home/container

CMD ["/bin/bash", "/entrypoint.sh"]
