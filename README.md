# Claude Code Notifier

> Beautiful macOS popup + iPhone push notifications for Claude Code. Never miss when your AI finishes thinking.

[![macOS](https://img.shields.io/badge/macOS-11.0%2B-blue)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

When Claude Code stops responding — task complete, waiting for input, or session ended — this notifier delivers a sleek native macOS popup right on your active monitor. Pair it with [Bark](https://github.com/Finb/Bark) and the same alert lands on your iPhone instantly.

---

## ✨ Features

- **Native macOS Popup** — Frosted glass panel with continuous rounded corners, auto dark/light mode, and system Glass sound
- **Multi-Monitor Aware** — Appears on whichever screen your cursor is currently on
- **Click to Focus** — Click the notification to jump straight back to the terminal app you were using (Ghostty, iTerm2, Terminal.app, etc.)
- **Hover to Dismiss** — Elegant close button fades in on hover
- **iPhone Sync** — Push to iPhone via [Bark](https://apps.apple.com/app/bark-customed-notifications/id1403753865) using APNs
- **Claude Branding** — Official Claude Code mascot icon, not the generic desktop app icon

---

## 📸 Preview

```
┌─────────────────────────────┐
│  [🟠]  Claude Code           │
│         Wait for Input        │
│         ~/projects/my-app     │
└─────────────────────────────┘
```

*Frosted glass panel matching your macOS theme, sliding in on the active desktop.*

---

## 🚀 Quick Start

### Recommended: Plugin Install

Register this repository as a marketplace in your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "extraKnownMarketplaces": {
    "zeppelinpp": {
      "source": {
        "source": "github",
        "repo": "Zeppelinpp/claude-code-notifier"
      }
    }
  }
}
```

Then install the plugin inside Claude Code:

```
/plugin install claude-code-notifier@zeppelinpp
```

That's it — the Stop hook is active immediately. No manual script or settings editing required.

### Configure Bark (Optional)

To enable iPhone push notifications, run the built-in setup skill inside Claude Code:

```
/bark-setup
```

Claude will ask for your Bark device key and save it automatically. No manual file editing needed.

Or set the environment variable:

```bash
export BARK_KEY="your-bark-key-here"
```

1. Install [Bark](https://apps.apple.com/app/bark-customed-notifications/id1403753865) on your iPhone
2. Open the app and copy your device key
3. Run `/bark-setup` in Claude Code and paste your key

For more Bark features, visit the [Bark GitHub repository](https://github.com/Finb/Bark).

---

## 🔧 Manual Install (Legacy)

If you prefer not to use the plugin system, use the standalone installer:

```bash
cd claude-code-notifier
./install.sh          # interactive: asks before overwriting
./install.sh --force  # non-interactive: auto-overwrite for updates
```

This copies the app to `~/Applications/`, creates `~/.claude/tools/notify.sh`, and adds a hook to `settings.json`.

To migrate from legacy hook to plugin mode:

```bash
./install.sh --uninstall   # removes legacy settings.json hook
# then use /plugin install inside Claude Code
```

---

## 📁 Repository Structure

```
claude-code-notifier/
├── .claude-plugin/
│   ├── plugin.json          # Plugin manifest
│   └── marketplace.json     # Marketplace manifest
├── hooks/
│   └── hooks.json           # Claude Code Stop hook
├── skills/
│   └── bark-setup/
│       └── SKILL.md         # Interactive Bark configuration skill
├── scripts/
│   ├── notify.sh            # Plugin notification script
│   └── setup-bark.sh        # Bark key configuration
├── ClaudeCodeNotifier.app/  # Compiled macOS notifier app
├── src/
│   └── popup.swift          # Swift source (customizable)
├── assets/
│   └── claudecode-color.png # Claude Code mascot icon
├── install.sh               # Standalone installer (legacy)
├── README.md
└── README.zh.md
```

---

## 🔨 Build from Source

The precompiled `ClaudeCodeNotifier.app` works out of the box, but you can customize the popup and rebuild:

```bash
cd src
swiftc popup.swift -o ClaudeCodeNotifier
```

Then replace the binary in the app bundle:

```bash
cp ClaudeCodeNotifier ../ClaudeCodeNotifier.app/Contents/MacOS/
```

Requires macOS 11.0+ and Swift toolchain. Key things you might customize in `popup.swift`:

- Window size, corner radius, padding
- Icon size or image source
- Auto-dismiss timeout (currently 8 seconds)
- Sound effect (currently "Glass")
- Click behavior (focuses the originating terminal app, falls back to frontmost app)

---

## 🙏 Credits

- [Bark](https://github.com/Finb/Bark) — Finb's open-source iOS push notification tool
- Claude Code — Anthropic's AI coding assistant

---

## License

MIT
