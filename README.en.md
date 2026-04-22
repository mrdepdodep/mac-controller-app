# Mac Control — App (English)

Native macOS SwiftUI app with a dark chat interface for controlling your system via typed commands.

## Requirements

- macOS 12.0 or later
- Xcode CLI tools / Swift compiler (`xcode-select --install`)

## Build

```bash
cd app
bash build_app.sh
```

Produces `MacControl.app` inside the `app/` directory. Open with:

```bash
open MacControl.app
```

## Structure

```
app/
├── Sources/MacControl/
│   ├── MacControlApp.swift   — app entry point
│   ├── ContentView.swift     — root layout, header, input bar, suggestions
│   ├── MessageBubble.swift   — chat bubble components
│   ├── CommandEngine.swift   — command parsing, execution, app indexing
│   ├── Models.swift          — Message model
│   └── Theme.swift           — colour palette
├── build_app.sh              — single-file build script (no Xcode needed)
└── run.sh                    — quick dev run via `swift run`
```

## UI

- **Header** — terminal icon, pulsing status dot (green = ready, amber = running)
- **Chat** — user messages with a purple gradient bubble; system replies with a left accent border
- **Input bar** — monospaced field with focus glow; circular send button with accent shadow
- **Suggestions** — horizontal chip row with autocomplete based on current input

## Commands

| Command | Description |
|---|---|
| `open <app>` | Open application |
| `close <app>` | Close application |
| `volume <0-100>` | Set volume |
| `volume up\|down [step]` | Adjust volume |
| `brightness <0-100>` | Set display brightness |
| `brightness up\|down [step]` | Adjust brightness |
| `mute` / `unmute` | Toggle audio output |
| `lock` | Lock screen |
| `sleep` | Sleep display |
| `list` | List all indexed apps |
| `refresh` | Rebuild app index |
| `permissions` | Check / request macOS permissions |
| `help` | Show all commands |
| `exit` | Quit the app |

## Permissions

Some commands require macOS system permissions:

- **Accessibility** — needed for simulated key events (volume/brightness keys, lock screen fallback)
- **Automation → System Events** — needed for AppleScript-based actions

Type `permissions` in the chat to trigger the permission request flow.
