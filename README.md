# Rust Egg (Vanilla / Oxide / Carbon) für Pterodactyl

Eigenes Egg mit eigenem Docker-Image. Die komplette Start-Logik liegt in diesem Repo:

| Datei | Aufgabe |
|---|---|
| `Dockerfile` | Image: Debian + Node 22, 32-Bit-Libs, SteamCMD-Vorlage, RCON-Wrapper |
| `entrypoint.sh` | Variablen prüfen, Spiel per SteamCMD updaten, Oxide/Carbon installieren, Server starten |
| `wrapper.js` | Panel-Konsole: Eingaben per WebRCON an den Server, sauberes `quit` beim Stoppen |
| `egg/install.sh` | Einmalige Erstinstallation (SteamCMD + Rust-Dateien) |
| `egg/build_egg.py` | Erzeugt `egg-rust-custom.json` (Variablen stehen nur hier) |
| `egg-rust-custom.json` | Das Egg zum Import ins Panel |
| `.github/workflows/build-image.yml` | Baut und veröffentlicht `ghcr.io/danevi01/pterodactyl-rust-egg:latest` |

## Einrichtung

1. **Repo** `Danevi01/pterodactyl-rust-egg` (öffentlich) mit allen Dateien auf `main`.
   Heißt Account oder Repo anders, `IMAGE` in `egg/build_egg.py` und die `LABEL ...source` im `Dockerfile` anpassen und `python3 egg/build_egg.py` ausführen.
   Der Image-Name ergibt sich im Workflow automatisch aus dem Repo-Namen (kleingeschrieben).
2. **Image bauen lassen:** Der Workflow läuft beim Push automatisch (Actions-Tab). Falls er an den Rechten scheitert:
   *Settings → Actions → General → Workflow permissions → Read and write*.
3. **Package öffentlich stellen:** GitHub → Profil → *Packages* → `pterodactyl-rust-egg` → *Package settings* → *Change visibility* → *Public*.
   Wings kann das Image sonst nicht ohne Login ziehen.
4. **Egg importieren:** Panel → Admin → *Nests* → *Import Egg* → `egg-rust-custom.json`.
5. **Server anlegen**, im Startup-Tab mindestens ein echtes **RCON-Passwort** setzen (min. 8 Zeichen, `CHANGEME` wird abgelehnt).

## Wie Framework und Version zusammenspielen

- `Modding Framework`: `Vanilla`, `Oxide`, `Carbon`, `Carbon-Minimal` (Groß-/Kleinschreibung egal).
- Der Root-Ordner folgt automatisch (`oxide` / `carbon`). Das Feld *Modding Root Directory* ist optional und wird ignoriert, wenn es nicht zum Framework passt.
- `Version` = Steam-Branch (`public`, `release`, `staging`, `aux01`, `aux02`). Carbon nutzt dazu den passenden Build
  (`production_build`, `rustbeta_staging_build`, `rustbeta_aux01_build`, `rustbeta_aux02_build`).
- Oxide patcht Spiel-DLLs. Nach jedem Spiel-Update wird Oxide deshalb neu eingespielt. Beim Wechsel von Oxide zu Carbon/Vanilla werden die Spieldateien automatisch validiert.
- Carbon wird über `carbon/tools/environment.sh` nur im Server-Prozess eingehängt.

## Hinweise und bekannte Annahmen

Dieses Setup wurde ohne laufendes Docker/Pterodactyl geschrieben und nur syntaktisch geprüft. Beim ersten Start besonders beobachten:

- **Konsole leer?** Das Egg nutzt `-logfile` ohne Pfad als letztes Argument (stdout). Falls die Konsole leer bleibt, in `entrypoint.sh` stattdessen `-logfile /dev/stdout` testen.
- **Oxide für staging/aux:** Es gibt dafür eine uMod-URL (`?tag=staging`), die nicht verifiziert ist. Im Zweifel `Framework URL (optional)` setzen.
- **Discord-/RustEdit-Extension:** Download-URLs stehen im Script (`DISCORD_EXT_URL`, `RUSTEDIT_EXT_URL` als Umgebungsvariablen überschreibbar), ungetestet.
- **Rust+ IP:** Ist `App Public IP` leer, fragt der Start `api.ipify.org` nach der öffentlichen IP.
- **`ADDITIONAL_ARGS`:** Wird an Leerzeichen getrennt, ohne Anführungszeichen-Auswertung.
- **DepotDownloader** aus dem Original-AIO-Egg ist nicht mehr enthalten, es gibt nur SteamCMD.
- `meta.update_url` ist leer, damit das Panel das Egg nicht gegen eine fremde Version aktualisiert.
