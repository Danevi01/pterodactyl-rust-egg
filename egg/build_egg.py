#!/usr/bin/env python3
"""Erzeugt egg-rust-custom.json (PTDL_v2) aus dieser Datei und egg/install.sh.

Aufruf (im Repo-Root):  python3 egg/build_egg.py
Die Variablen unten sind die einzige Quelle der Wahrheit – nicht die JSON von Hand ändern.
"""
import datetime
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
IMAGE = "ghcr.io/danevi01/pterodactyl-rust-egg:latest"   # muss zum Workflow (.github/workflows/build-image.yml) passen
OUT = ROOT / "egg-rust-custom.json"


def var(name, description, env, default, rules, editable=True):
    return {
        "name": name,
        "description": description,
        "env_variable": env,
        "default_value": default,
        "user_viewable": True,
        "user_editable": editable,
        "rules": rules,
        "field_type": "text",
    }


VARIABLES = [
    # --- Server-Listing -----------------------------------------------------
    var("Server Name", "Name des Servers in der Serverliste.",
        "SERVER_HOSTNAME", "A Rust Server", "required|string|max:60"),
    var("Description", "Beschreibung unter dem Servernamen. \\n erzeugt einen Zeilenumbruch.",
        "DESCRIPTION", "Rust Server", "required|string"),
    var("URL", "Webseite des Servers (Button \"Visit Website\").",
        "SERVER_URL", "", "nullable|url"),
    var("Server Image", "Header-Bild der Serverliste (direkte Bild-URL).",
        "SERVER_IMG", "", "nullable|url"),
    var("Server Logo", "Rundes Logo für die Rust+-App (direkte Bild-URL).",
        "SERVER_LOGO", "", "nullable|url"),
    var("Server Tags", "Tags, mit Komma getrennt, z. B. weekly,EU,modded. Liste: https://wiki.facepunch.com/rust/server-browser-tags",
        "SERVER_TAGS", "", "nullable|string"),
    var("Max Players", "Maximale Spielerzahl.",
        "MAX_PLAYERS", "40", "required|integer|min:1"),
    var("Gamemode", "none, vanilla, survival, softcore oder hardcore.",
        "GAMEMODE", "vanilla", "nullable|string"),

    # --- Framework / Version -----------------------------------------------
    var("Modding Framework",
        "Vanilla, Oxide, Carbon oder Carbon-Minimal. Der passende Root-Ordner (oxide bzw. carbon) wird automatisch gesetzt.",
        "FRAMEWORK", "Carbon", "required|string|in:Vanilla,Oxide,Carbon,Carbon-Minimal"),
    var("Framework Update", "1 = Framework bei jedem Start neu laden/aktualisieren, 0 = nur wenn nötig.",
        "FRAMEWORK_UPDATE", "1", "required|boolean"),
    var("Framework URL (optional)", "Eigene Download-URL für das Framework-Archiv (Oxide: .zip, Carbon: .tar.gz). Leer = automatisch.",
        "FRAMEWORK_URL", "", "nullable|url"),
    var("Modding Root Directory (optional)", "Normalerweise leer lassen. Nur setzen, wenn der Ordner zum Framework passt (Oxide ohne \"carbon\" im Namen, Carbon ohne \"oxide\").",
        "MODDING_ROOT", "", "nullable|string|max:32"),
    var("Version", "Steam-Branch: public, release, staging, aux01 oder aux02.",
        "VERSION", "public", "required|string|in:public,release,staging,aux01,aux02"),
    var("Auto Update", "1 = Spieldateien bei jedem Start per SteamCMD aktualisieren.",
        "AUTO_UPDATE", "1", "required|boolean"),
    var("Validate Game Files", "1 = Spieldateien beim Update zusätzlich validieren (dauert länger).",
        "VALIDATE", "1", "required|boolean"),
    var("Discord Extension", "Oxide: Discord-Extension laden (ungetestet, nur Oxide).",
        "DISCORD_EXT", "0", "required|boolean"),
    var("RustEdit Extension", "Oxide: RustEdit-Extension laden (ungetestet, nur Oxide).",
        "RUSTEDIT_EXT", "0", "required|boolean"),

    # --- Welt ---------------------------------------------------------------
    var("World Size", "Größe der prozeduralen Karte.",
        "WORLD_SIZE", "3000", "required|integer|between:1000,6000"),
    var("World Seed", "Seed der prozeduralen Karte. Leer = zufällig.",
        "WORLD_SEED", "1234", "nullable|string"),
    var("Custom Map URL", "Direkte Download-URL einer eigenen Karte. Überschreibt Größe/Seed. Eine ungültige URL lässt den Server abstürzen.",
        "MAP_URL", "", "nullable|url"),
    var("Server Identity", "Ordnername der Serverdaten (Standard: rust).",
        "SERVER_IDENTITY", "rust", r"required|string|regex:/^[\w.-]+$/"),
    var("Save Interval", "Automatisches Speichern alle X Sekunden.",
        "SAVEINTERVAL", "60", "required|integer|min:10"),

    # --- Netzwerk / RCON / Rust+ ---------------------------------------------
    var("Query Port", "Steam-Query-Port. Darf nicht dem Spielport entsprechen.",
        "QUERY_PORT", "27017", "required|integer"),
    var("RCON Port", "Port für RCON (wird auch von der Panel-Konsole genutzt).",
        "RCON_PORT", "28016", "required|integer"),
    var("RCON Password", "RCON-Passwort, mindestens 8 Zeichen (Buchstaben, Zahlen, . _ -). \"CHANGEME\" wird abgelehnt.",
        "RCON_PASS", "CHANGEME", r"required|regex:/^[\w.-]+$/|min:8|max:64"),
    var("App Port", "Port der Rust+-App. -1 = deaktiviert.",
        "APP_PORT", "28082", "required|integer"),
    var("App Public IP", "Öffentliche IP für Rust+. Leer = wird beim Start automatisch ermittelt (api.ipify.org).",
        "APP_PUBLIC_IP", "", "nullable|string|max:45"),

    # --- Sonstiges -----------------------------------------------------------
    var("Log File Location", "Zusätzliche Logdatei, strftime-Muster erlaubt (z. B. logs/%Y-%m-%d-%H%M.log). Leer = nur Konsole.",
        "LOG_FILE", "logs/%Y-%m-%d-%H%M.log", "nullable|string"),
    var("Additional Arguments", "Zusätzliche Startparameter, durch Leerzeichen getrennt (keine Anführungszeichen-Auswertung).",
        "ADDITIONAL_ARGS", "", "nullable|string"),
    var("Debug Mode", "1 = Egg gibt das aufgelöste Startkommando aus (Passwort maskiert).",
        "EGG_DEBUG", "0", "required|boolean"),
]

egg = {
    "_comment": "Erzeugt mit egg/build_egg.py – nicht von Hand bearbeiten.",
    "meta": {"version": "PTDL_v2", "update_url": None},
    "exported_at": datetime.datetime.now(datetime.timezone.utc).astimezone().isoformat(timespec="seconds"),
    "name": "Rust - Custom (Vanilla/Oxide/Carbon)",
    "author": "danevi01@users.noreply.github.com",   # das Panel verlangt eine gültige E-Mail-Adresse
    "description": "Rust Dedicated Server mit Vanilla, Oxide oder Carbon. Eigenes Image und Start-Script; Framework-Installation, Updates und Konsole (RCON) übernimmt das Image.",
    "features": ["steam_disk_space"],
    "docker_images": {"Rust (latest)": IMAGE},
    "file_denylist": [],
    "startup": "/entrypoint.sh",
    "config": {
        "files": "{}",
        "startup": json.dumps({"done": "Server startup complete"}, indent=4),
        "logs": "{}",
        "stop": "quit",
    },
    "scripts": {
        "installation": {
            "script": (ROOT / "egg" / "install.sh").read_text(encoding="utf-8"),
            "container": "ghcr.io/pterodactyl/installers:debian",
            "entrypoint": "bash",
        }
    },
    "variables": VARIABLES,
}

OUT.write_text(json.dumps(egg, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"{OUT.name} geschrieben ({len(VARIABLES)} Variablen, Image {IMAGE})")
