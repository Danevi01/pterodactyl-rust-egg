'use strict';
/**
 * RCON-Wrapper für den Rust-Server unter Pterodactyl.
 *
 * Der Rust-Server liest in -batchmode nichts von stdin. Dieser Wrapper
 *  - startet den Server (Argumente = alles nach "wrapper.js"),
 *  - leitet dessen Ausgabe an die Panel-Konsole (und optional in eine Logdatei),
 *  - nimmt Panel-Eingaben (stdin) entgegen und schickt sie per WebRCON an den Server,
 *  - gibt Antworten auf diese Befehle in der Konsole aus,
 *  - beendet den Server sauber bei "quit" bzw. SIGTERM/SIGINT.
 */
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const WebSocket = require('ws');

const cmd = process.argv.slice(2);
if (cmd.length === 0) {
    console.error('[wrapper] Kein Startkommando übergeben.');
    process.exit(1);
}

const rconPort = process.env.RCON_PORT || '28016';
const rconPass = process.env.RCON_PASS || '';
const logFile = process.env.EGG_LOG_FILE || '';

let logStream = null;
if (logFile) {
    try {
        fs.mkdirSync(path.dirname(logFile), { recursive: true });
        logStream = fs.createWriteStream(logFile, { flags: 'a' });
    } catch (err) {
        console.error('[wrapper] Logdatei nicht beschreibbar: ' + err.message);
    }
}

const childEnv = { ...process.env };
if (process.env.EGG_CHILD_LD_LIBRARY_PATH) {
    childEnv.LD_LIBRARY_PATH = process.env.EGG_CHILD_LD_LIBRARY_PATH;
}
delete childEnv.EGG_CHILD_LD_LIBRARY_PATH;

const child = spawn(cmd[0], cmd.slice(1), { stdio: ['ignore', 'pipe', 'pipe'], env: childEnv });

function out(chunk) {
    process.stdout.write(chunk);
    if (logStream) logStream.write(chunk);
}
child.stdout.on('data', out);
child.stderr.on('data', out);
child.on('error', (err) => {
    console.error('[wrapper] Server konnte nicht gestartet werden: ' + err.message);
    process.exit(1);
});

// ---------------------------------------------------------------- RCON
let ws = null;
let connected = false;
let exiting = false;
const FIRST_COMMAND_ID = 1000;
let nextId = FIRST_COMMAND_ID;

function connect() {
    if (exiting) return;
    const url = 'ws://127.0.0.1:' + rconPort + '/' + encodeURIComponent(rconPass);
    ws = new WebSocket(url);
    ws.on('open', () => { connected = true; });
    ws.on('message', (data) => {
        try {
            const msg = JSON.parse(data.toString());
            // Der Server-Log kommt bereits über stdout (-logfile) in die Konsole. RCON schickt ihn
            // zusätzlich als Broadcast (Identifier 0 oder -1) – das würde alles doppelt anzeigen.
            // Ausgegeben werden nur Antworten auf Befehle, die dieser Wrapper selbst gesendet hat (ID >= 1000).
            if (msg && Number.isInteger(msg.Identifier) && msg.Identifier >= FIRST_COMMAND_ID && msg.Message) {
                console.log(msg.Message);
            }
        } catch (_) { /* ignorieren */ }
    });
    ws.on('close', () => {
        connected = false;
        ws = null;
        if (!exiting) setTimeout(connect, 3000);
    });
    ws.on('error', () => { /* 'close' folgt und löst den Reconnect aus */ });
}
setTimeout(connect, 5000);

function sendCommand(line) {
    if (connected && ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ Identifier: nextId++, Message: line, Name: 'WebRcon' }));
        return true;
    }
    return false;
}

function handleInput(line) {
    if (sendCommand(line)) return;
    if (line === 'quit' || line === 'exit') {
        child.kill('SIGTERM');
    } else {
        console.log('[wrapper] RCON noch nicht verbunden – Befehl verworfen: ' + line);
    }
}

let buffer = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (data) => {
    buffer += data;
    let idx;
    while ((idx = buffer.indexOf('\n')) >= 0) {
        const line = buffer.slice(0, idx).replace(/\r$/, '').trim();
        buffer = buffer.slice(idx + 1);
        if (line) handleInput(line);
    }
});

// ---------------------------------------------------------------- Beenden
function shutdown() {
    if (exiting) return;
    exiting = true;
    if (!sendCommand('quit')) child.kill('SIGTERM');
    setTimeout(() => child.kill('SIGKILL'), 25000).unref();
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

child.on('close', (code) => {
    exiting = true;
    if (ws) { try { ws.terminate(); } catch (_) { /* egal */ } }
    const finish = () => process.exit(code === null ? 1 : code);
    if (logStream) logStream.end(finish); else finish();
});
