# Lokaler PowerShell UDP Chatroom (P2P)

Start per Doppelklick auf `Start-Chat.bat`.

## Features
- UDP-Multicast P2P Chat (kein zentraler Server).
- Administratoren werden in `chat-config.json` über IP gepflegt.
- Admin-Titel + Farbe pro Administrator (`title`, `titleColor`).
- Admin-Befehle im Chat:
  - `/kick <nutzername> [grund]`
  - `/ban <nutzername> [grund]`
- Bei `/ban` trägt sich der betroffene Client **selbst** in `bans` in `chat-config.json` ein (mit eigener IP) und beendet sich.

## Wichtige Befehle im Chat
- `/help`
- `/who`
- `/kick <name> [grund]` (nur wenn eigene IP in `admins`)
- `/ban <name> [grund]` (nur wenn eigene IP in `admins`)
- `/title <text>`
- `/quit`

## Konfiguration
Datei: `chat-config.json`

- `room.multicastAddress`: UDP Multicast Gruppe.
- `room.port`: Port.
- `admins`: Tabelle mit Administratoren (`username`, `ip`, `title`, `titleColor`).
- `bans`: Bannliste.

> Hinweis: Da es ein reiner P2P-Chat ist, gibt es keine zentrale, manipulationssichere Autorität.
