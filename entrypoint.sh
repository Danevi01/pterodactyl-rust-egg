#!/bin/bash
# =============================================================================
# Rust Egg – Entrypoint
#
# Ablauf:
#   1. Einstellungen aus den Egg-Variablen lesen und prüfen
#   2. Spieldateien per SteamCMD installieren/aktualisieren
#   3. Framework (Oxide oder Carbon) installieren/aktualisieren
#   4. Startkommando bauen und über den RCON-Wrapper starten
#
# Das Modding-Root-Verzeichnis folgt automatisch dem Framework
# (oxide -> "oxide", carbon -> "carbon"), die Kombination aus dem
# ursprünglichen AIO-Egg ("Oxide" + Root "carbon") kann nicht mehr entstehen.
# =============================================================================
set -o pipefail

cd /home/container || { echo "[egg] /home/container fehlt"; exit 1; }
export HOME=/home/container
export TERM="${TERM:-xterm}"

c_info=$'\033[1;36m'; c_warn=$'\033[1;33m'; c_err=$'\033[1;31m'; c_off=$'\033[0m'
log()  { printf '%s[egg]%s %s\n' "$c_info" "$c_off" "$*"; }
warn() { printf '%s[egg][WARNUNG]%s %s\n' "$c_warn" "$c_off" "$*"; }
die()  { printf '%s[egg][FEHLER]%s %s\n' "$c_err" "$c_off" "$*"; exit 1; }
is_on() { case "${1:-0}" in 1|true|TRUE|True|yes|on) return 0 ;; *) return 1 ;; esac; }
lc()   { printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'; }

APPID=258550
TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# -----------------------------------------------------------------------------
# 1. Einstellungen
# -----------------------------------------------------------------------------
[ -n "${SERVER_PORT:-}" ] || die "SERVER_PORT ist nicht gesetzt (Allocation im Panel prüfen)."

# Version = Steam-Branch
BRANCH="$(lc "${VERSION:-public}")"
case "$BRANCH" in
    public|release|staging|aux01|aux02) ;;
    aux01-staging) BRANCH="aux01" ;;
    *) die "Unbekannte Version '${VERSION}'. Erlaubt: public, release, staging, aux01, aux02." ;;
esac

# Framework (Groß-/Kleinschreibung egal)
FW_RAW="$(lc "${FRAMEWORK:-carbon}")"
CARBON_FLAVOR=""
case "$FW_RAW" in
    vanilla)                   FW="vanilla"; ROOT="" ;;
    oxide)                     FW="oxide";   ROOT="oxide" ;;
    carbon)                    FW="carbon";  ROOT="carbon"; CARBON_FLAVOR="Release" ;;
    carbon-minimal|carbonminimal) FW="carbon"; ROOT="carbon"; CARBON_FLAVOR="Minimal" ;;
    *) die "Unbekanntes Framework '${FRAMEWORK}'. Erlaubt: Vanilla, Oxide, Carbon, Carbon-Minimal." ;;
esac

# Optionaler Override des Root-Ordners – nur wenn er zum Framework passt
if [ -n "${MODDING_ROOT:-}" ] && [ "$FW" != "vanilla" ]; then
    root_lc="$(lc "$MODDING_ROOT")"
    if [[ ! "$MODDING_ROOT" =~ ^[A-Za-z0-9._/-]+$ ]] || [[ "$MODDING_ROOT" == *..* ]]; then
        warn "Modding Root '${MODDING_ROOT}' enthält ungültige Zeichen – verwende '${ROOT}'."
    elif [ "$FW" = "oxide" ] && [[ "$root_lc" == *carbon* ]]; then
        warn "Modding Root '${MODDING_ROOT}' passt nicht zu Oxide – verwende '${ROOT}'."
    elif [ "$FW" = "carbon" ] && [[ "$root_lc" == *oxide* ]]; then
        warn "Modding Root '${MODDING_ROOT}' passt nicht zu Carbon – verwende '${ROOT}'."
    else
        ROOT="$MODDING_ROOT"
    fi
fi

RCON_PASS="${RCON_PASS:-}"
if [ -z "$RCON_PASS" ] || [ "$RCON_PASS" = "CHANGEME" ] || [ "${#RCON_PASS}" -lt 8 ]; then
    die "RCON-Passwort ist leer, 'CHANGEME' oder kürzer als 8 Zeichen. Bitte im Panel ein sicheres Passwort setzen (erlaubt: Buchstaben, Zahlen, . _ -)."
fi

STATE="$HOME/.egg_state"
state_get() { [ -f "$STATE" ] && sed -n "s/^$1=//p" "$STATE" | head -n1; }
PREV_FW="$(state_get fw)"
PREV_KEY="$(state_get key)"
FW_KEY="${FW}:${CARBON_FLAVOR}:${BRANCH}"

log "Framework: ${FW}${CARBON_FLAVOR:+ (${CARBON_FLAVOR})} | Branch: ${BRANCH} | Root: ${ROOT:-–}"

download() { # download <url> <ziel>
    local i
    for i in 1 2 3; do
        curl -fsSL --connect-timeout 15 --retry 2 -o "$2" "$1" && return 0
        warn "Download fehlgeschlagen (Versuch ${i}/3): $1"
        sleep 3
    done
    return 1
}

# -----------------------------------------------------------------------------
# 2. Spieldateien (SteamCMD)
# -----------------------------------------------------------------------------
ensure_steamcmd() {
    if [ ! -x "$HOME/steamcmd/steamcmd.sh" ]; then
        log "Kopiere SteamCMD nach ${HOME}/steamcmd ..."
        mkdir -p "$HOME/steamcmd" "$HOME/steamapps"
        cp -a /opt/steamcmd/. "$HOME/steamcmd/"
    fi
}

steam_update() { # steam_update <validate 0|1>
    ensure_steamcmd
    local args=(+force_install_dir "$HOME" +login anonymous +app_update "$APPID")
    [ "$BRANCH" != "public" ] && args+=(-beta "$BRANCH")
    [ "$1" = "1" ] && args+=(validate)
    args+=(+quit)
    local i
    for i in 1 2 3; do
        log "SteamCMD (Versuch ${i}/3): app_update ${APPID} branch=${BRANCH} validate=$1"
        "$HOME/steamcmd/steamcmd.sh" "${args[@]}" && return 0
        warn "SteamCMD meldete einen Fehler."
        sleep 5
    done
    return 1
}

GAME_UPDATED=0
RESTORE=0
# Wurde vorher Oxide benutzt (patcht Spiel-DLLs), müssen die Originale wiederhergestellt werden.
if [ "$PREV_FW" = "oxide" ] && [ "$FW" != "oxide" ]; then
    RESTORE=1
    log "Wechsel weg von Oxide erkannt – Spieldateien werden validiert, um Originale wiederherzustellen."
fi

if [ ! -x "$HOME/RustDedicated" ]; then
    log "Erstinstallation der Spieldateien ..."
    steam_update 1 || die "Installation der Spieldateien fehlgeschlagen."
    GAME_UPDATED=1
elif is_on "${AUTO_UPDATE:-1}" || [ "$RESTORE" = "1" ]; then
    if [ "$RESTORE" = "1" ] || is_on "${VALIDATE:-0}"; then V=1; else V=0; fi
    steam_update "$V" || die "Update der Spieldateien fehlgeschlagen."
    GAME_UPDATED=1
else
    log "Auto-Update ist deaktiviert – überspringe SteamCMD."
fi

[ -x "$HOME/RustDedicated" ] || chmod +x "$HOME/RustDedicated" 2>/dev/null
[ -f "$HOME/RustDedicated" ] || die "RustDedicated wurde nicht gefunden."

# steamclient.so für 32/64 Bit bereitstellen
mkdir -p "$HOME/.steam/sdk32" "$HOME/.steam/sdk64"
[ -f "$HOME/steamcmd/linux32/steamclient.so" ] && cp -f "$HOME/steamcmd/linux32/steamclient.so" "$HOME/.steam/sdk32/steamclient.so"
[ -f "$HOME/steamcmd/linux64/steamclient.so" ] && cp -f "$HOME/steamcmd/linux64/steamclient.so" "$HOME/.steam/sdk64/steamclient.so"

# -----------------------------------------------------------------------------
# 3. Framework
# -----------------------------------------------------------------------------
oxide_url() {
    if [ -n "${FRAMEWORK_URL:-}" ]; then printf '%s' "$FRAMEWORK_URL"; return; fi
    case "$BRANCH" in
        public|release) printf '%s' "https://github.com/OxideMod/Oxide.Rust/releases/latest/download/Oxide.Rust-linux.zip" ;;
        *) printf '%s' "https://umod.org/games/rust/download?tag=${BRANCH}" ;;
    esac
}

carbon_url() {
    if [ -n "${FRAMEWORK_URL:-}" ]; then printf '%s' "$FRAMEWORK_URL"; return; fi
    local build
    case "$BRANCH" in
        public|release) build="production_build" ;;
        staging)        build="rustbeta_staging_build" ;;
        aux01)          build="rustbeta_aux01_build" ;;
        aux02)          build="rustbeta_aux02_build" ;;
    esac
    printf '%s' "https://github.com/CarbonCommunity/Carbon/releases/download/${build}/Carbon.Linux.${CARBON_FLAVOR}.tar.gz"
}

install_oxide() {
    local url; url="$(oxide_url)"
    case "$BRANCH" in
        public|release) ;;
        *) [ -z "${FRAMEWORK_URL:-}" ] && warn "Für ${BRANCH} wird ein uMod-Download genutzt. Falls das scheitert, FRAMEWORK_URL setzen." ;;
    esac
    log "Lade Oxide: ${url}"
    download "$url" "$TMP/oxide.zip" || die "Oxide-Download fehlgeschlagen."
    unzip -oq "$TMP/oxide.zip" -d "$HOME" || die "Oxide-Archiv konnte nicht entpackt werden."
    [ -f "$HOME/RustDedicated_Data/Managed/Oxide.Core.dll" ] || warn "Oxide.Core.dll nicht gefunden – Installation prüfen (oxide.version in der Konsole)."
}

install_carbon() {
    local url; url="$(carbon_url)"
    log "Lade Carbon: ${url}"
    download "$url" "$TMP/carbon.tar.gz" || die "Carbon-Download fehlgeschlagen."
    tar -xzf "$TMP/carbon.tar.gz" -C "$HOME" || die "Carbon-Archiv konnte nicht entpackt werden."
    [ -f "$HOME/carbon/tools/environment.sh" ] || die "carbon/tools/environment.sh fehlt nach dem Entpacken – das Carbon-Archiv hat eine unerwartete Struktur."
}

install_extension() { # install_extension <name> <url> <ziel>
    if [ -f "$3" ] && ! is_on "${FRAMEWORK_UPDATE:-1}"; then return 0; fi
    log "Lade Extension ${1}: ${2}"
    if download "$2" "$TMP/ext.dll"; then
        mkdir -p "$(dirname "$3")"
        cp -f "$TMP/ext.dll" "$3"
    else
        warn "Extension ${1} konnte nicht geladen werden."
    fi
}

if [ "$FW" != "vanilla" ]; then
    FW_PRESENT=0
    [ "$FW" = "oxide" ]  && [ -f "$HOME/RustDedicated_Data/Managed/Oxide.Core.dll" ] && FW_PRESENT=1
    [ "$FW" = "carbon" ] && [ -f "$HOME/carbon/tools/environment.sh" ] && FW_PRESENT=1

    NEED_FW=0
    is_on "${FRAMEWORK_UPDATE:-1}" && NEED_FW=1
    [ "$FW_PRESENT" = "0" ] && NEED_FW=1
    [ "$PREV_KEY" != "$FW_KEY" ] && NEED_FW=1
    # Oxide patcht Spiel-DLLs: nach jedem Spiel-Update/Validate neu einspielen
    [ "$FW" = "oxide" ] && [ "$GAME_UPDATED" = "1" ] && NEED_FW=1

    if [ "$NEED_FW" = "1" ]; then
        case "$FW" in
            oxide)  install_oxide ;;
            carbon) install_carbon ;;
        esac
    else
        log "Framework ist aktuell – überspringe Installation."
    fi
fi

# Oxide-Extensions (optional)
if [ "$FW" = "oxide" ]; then
    is_on "${DISCORD_EXT:-0}" && install_extension "Discord" \
        "${DISCORD_EXT_URL:-https://umod.org/extensions/discord/download}" \
        "$HOME/RustDedicated_Data/Managed/Oxide.Ext.Discord.dll"
    is_on "${RUSTEDIT_EXT:-0}" && install_extension "RustEdit" \
        "${RUSTEDIT_EXT_URL:-https://github.com/k1lly0u/Oxide.Ext.RustEdit/raw/master/Oxide.Ext.RustEdit.dll}" \
        "$HOME/RustDedicated_Data/Managed/Oxide.Ext.RustEdit.dll"
elif is_on "${DISCORD_EXT:-0}" || is_on "${RUSTEDIT_EXT:-0}"; then
    warn "Discord-/RustEdit-Extension sind nur für Oxide vorgesehen und werden ignoriert."
fi

printf 'fw=%s\nkey=%s\n' "$FW" "$FW_KEY" > "$STATE"

# -----------------------------------------------------------------------------
# 4. Startkommando
# -----------------------------------------------------------------------------
# Öffentliche IP für die Rust+-App (nur wenn nicht gesetzt und App aktiv)
APP_IP="${APP_PUBLIC_IP:-}"
if [ -z "$APP_IP" ] && [ "${APP_PORT:-28082}" != "-1" ]; then
    APP_IP="$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
    if [[ "$APP_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        log "Rust+ App Public IP automatisch ermittelt: ${APP_IP}"
    else
        APP_IP=""
        warn "Öffentliche IP konnte nicht ermittelt werden – bei Bedarf APP_PUBLIC_IP im Panel setzen."
    fi
fi

ARGS=(./RustDedicated -batchmode -nographics)
case "$FW" in
    oxide)  ARGS+=(+oxide.directory "$ROOT") ;;
    carbon) ARGS+=(-carbon.rootdir "$ROOT") ;;
esac
ARGS+=(
    +server.port "$SERVER_PORT"
    +server.queryport "${QUERY_PORT:-27017}"
    +server.identity "${SERVER_IDENTITY:-rust}"
    +rcon.port "${RCON_PORT:-28016}"
    +rcon.ip 0.0.0.0
    +rcon.web true
    +rcon.password "$RCON_PASS"
    +server.hostname "${SERVER_HOSTNAME:-A Rust Server}"
    +server.description "${DESCRIPTION:-}"
    +server.maxplayers "${MAX_PLAYERS:-40}"
    +server.saveinterval "${SAVEINTERVAL:-60}"
    +app.port "${APP_PORT:-28082}"
)
[ -n "${GAMEMODE:-}" ]     && ARGS+=(+server.gamemode "$GAMEMODE")
[ -n "${SERVER_URL:-}" ]   && ARGS+=(+server.url "$SERVER_URL")
[ -n "${SERVER_IMG:-}" ]   && ARGS+=(+server.headerimage "$SERVER_IMG")
[ -n "${SERVER_LOGO:-}" ]  && ARGS+=(+server.logoimage "$SERVER_LOGO")
[ -n "${SERVER_TAGS:-}" ]  && ARGS+=(+server.tags "$SERVER_TAGS")
[ -n "$APP_IP" ]           && ARGS+=(+app.publicip "$APP_IP")
if [ -n "${MAP_URL:-}" ]; then
    ARGS+=(+server.levelurl "$MAP_URL")
else
    ARGS+=(+server.worldsize "${WORLD_SIZE:-3000}")
    [ -n "${WORLD_SEED:-}" ] && ARGS+=(+server.seed "$WORLD_SEED")
fi
if [ -n "${ADDITIONAL_ARGS:-}" ]; then
    read -r -a EXTRA <<< "$ADDITIONAL_ARGS"   # Trennung an Leerzeichen, keine Anführungszeichen-Auswertung
    ARGS+=("${EXTRA[@]}")
fi
# -logfile ohne Pfad (muss das letzte Argument sein) = Ausgabe auf stdout -> Panel-Konsole
ARGS+=(-logfile)

# Carbon wird über environment.sh eingehängt – nur im Server-Prozess, nicht im Wrapper
if [ "$FW" = "carbon" ]; then
    LAUNCH=(bash -c 'source "$1"; shift; exec "$@"' egg-launch "$HOME/carbon/tools/environment.sh" "${ARGS[@]}")
else
    LAUNCH=("${ARGS[@]}")
fi

export EGG_CHILD_LD_LIBRARY_PATH="$HOME/RustDedicated_Data/Plugins/x86_64:$HOME${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export RCON_PORT="${RCON_PORT:-28016}" RCON_PASS

# Logdatei (strftime-Muster erlaubt, z. B. logs/%Y-%m-%d-%H%M.log)
if [ -n "${LOG_FILE:-}" ]; then
    EGG_LOG_FILE="$(date +"$LOG_FILE")"
    export EGG_LOG_FILE
    log "Server-Log wird zusätzlich nach ${EGG_LOG_FILE} geschrieben."
fi

if is_on "${EGG_DEBUG:-0}"; then
    log "Debug: Startkommando (ohne RCON-Passwort):"
    printf '  %q' "${ARGS[@]}" | sed "s/${RCON_PASS//\//\\/}/********/g"; echo
fi

log "Starte Server ..."
cleanup
trap - EXIT
exec node /wrapper/wrapper.js "${LAUNCH[@]}"
