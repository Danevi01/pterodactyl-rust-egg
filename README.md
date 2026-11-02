# Pterodactyl Rust Egg

Ein Egg für Rust Dedicated Server auf Pterodactyl, wahlweise **Vanilla**, **Oxide** oder **Carbon**.

## Funktionen

- **Framework nach Wahl:** Vanilla, Oxide, Carbon oder Carbon-Minimal, umschaltbar in den Startup-Einstellungen. Das passende Verzeichnis (`oxide` bzw. `carbon`) wird automatisch gesetzt.
- **Automatische Installation und Updates:** Rust-Serverdateien und Framework werden beim Start per SteamCMD bzw. von den offiziellen Quellen geladen und aktuell gehalten (abschaltbar).
- **Alle Rust-Branches:** `public`, `release`, `staging`, `aux01` und `aux02`.
- **Konsole im Panel:** Befehle aus der Panel-Konsole werden per RCON an den Server gesendet, beim Stoppen wird der Server sauber beendet.
- **Rust+ App:** Die öffentliche IP wird automatisch ermittelt, wenn keine gesetzt ist.
- **Eigene Karten:** Procedural Map mit Größe und Seed oder eine eigene Karte per URL.
- **Logdatei:** Optional zusätzlich in eine Datei, der Dateiname darf ein Datum enthalten.
- **Sicherheitsprüfung:** Ein zu schwaches RCON-Passwort verhindert den Start.

## Egg importieren

Im Panel unter *Admin → Nests → Import Egg* die Datei [`egg-rust-custom.json`](egg-rust-custom.json) hochladen.
Das Egg nutzt das Image `ghcr.io/danevi01/pterodactyl-rust-egg:latest`.

## Wichtige Einstellungen

| Variable | Bedeutung |
|---|---|
| Modding Framework | `Vanilla`, `Oxide`, `Carbon` oder `Carbon-Minimal` |
| Version | Steam-Branch: `public`, `release`, `staging`, `aux01`, `aux02` |
| RCON Password | Mindestens 8 Zeichen, `CHANGEME` wird abgelehnt |
| App Port | Port der Rust+ App, `-1` schaltet Rust+ ab |
| Auto Update / Framework Update | Spiel und Framework bei jedem Start aktualisieren |
| Additional Arguments | Zusätzliche Startparameter, durch Leerzeichen getrennt |
